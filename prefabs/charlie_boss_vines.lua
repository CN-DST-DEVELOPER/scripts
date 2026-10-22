local assets =
{
	Asset("ANIM", "anim/tentacle.zip"),
	Asset("ANIM", "anim/charlie_boss_vines.zip"),
	Asset("ANIM", "anim/goo_vines.zip"),
}

local AOEUtil = require("aoeutil")

local splashfxlist =
{
	"goo_vines_break_fx",
}

local DIRT_SCALE = 0.7
local DIRT_OFFSET = -0.3

local function RecylceDirt(dirt)
	if dirt.poolinst and dirt.poolinst:IsValid() then
		dirt:RemoveFromScene()
		table.insert(dirt.poolinst, dirt)
	else
		dirt:Remove()
	end
end

local function CreateDirt()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("charlie_boss_vines")
	inst.AnimState:SetBuild("charlie_boss_vines")
	inst.AnimState:PlayAnimation("dirt")
	inst.AnimState:SetScale(DIRT_SCALE, DIRT_SCALE)

	inst:ListenForEvent("animover", RecylceDirt)

	return inst
end

local function GetDirtFromPool(inst)
	if inst._owner and inst._owner._dirtpool and #inst._owner._dirtpool > 0 then
		local dirt = table.remove(inst._owner._dirtpool)
		dirt:ReturnToScene()
		dirt.AnimState:PlayAnimation("dirt")
		return dirt
	end
	local dirt = CreateDirt()
	dirt.poolinst = inst._owner
	return dirt
end

local function SpawnDirt(inst)
	if inst.moving and not inst.AnimState:IsCurrentAnimation("vine_pst") then
		inst.dirt = GetDirtFromPool(inst)
	end
end

local LIGHT_OVERRIDE = 1

local function CreateVine(anims, t)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("charlie_boss_vines")
	inst.AnimState:SetBuild("charlie_boss_vines")

	if t then
		for i, v in ipairs(anims) do
			inst.AnimState:PlayAnimation(v)
			local len = inst.AnimState:GetCurrentAnimationLength()
			if t < len then
				inst.AnimState:SetTime(t)
				for j = i + 1, #anims do
					inst.AnimState:PushAnimation(anims[j], false)
				end
				break
			elseif i < #anims then
				t = t - len
			else
				inst:Remove()
				return
			end
		end

		inst.dirttask = inst:DoPeriodicTask(0.4, SpawnDirt, t % 0.4)
	end

	inst.AnimState:SetLightOverride(LIGHT_OVERRIDE)
	if LIGHT_OVERRIDE < 1 then
		inst.AnimState:SetSymbolLightOverride("cb_vine_red", 1)
		inst.AnimState:SetSymbolLightOverride("cb_roots_red", 1)
	end

	inst:ListenForEvent("animqueueover", inst.Remove)

	return inst
end

local function SpawnVineAtXZ(inst, xoffs, zoffs, t, emergeframe, emergeflip, emergescale)
	local fx = CreateVine(inst._vine_anims, t)
	if fx then
		table.insert(inst._vines, fx)
		fx._owner = inst
		fx.xoffs, fx.zoffs = xoffs, zoffs
		fx.emergeframe = emergeframe
		fx.emergeflip = emergeflip
		fx.emergescale = emergescale
	end
end

local function OnRemoveEntity(inst)
	for _, v in ipairs(inst._vines) do
		v:Remove()
	end
	for _, v in ipairs(inst._dirtpool) do
		v:Remove()
	end
end

local NUM_VINES = 3
local VINE_DELAY = 4 * FRAMES --between vines, to stagger the fx loops
local VINES_RADIUS = 0.8

local function TrySpawnAllVines(inst)
	if inst._vines == nil and not inst:IsAsleep() then
		inst._vines = {}
		inst._dirtpool = {}
		inst.OnRemoveEntity = OnRemoveEntity

		inst._vine_anims = { "vine_pre" }
		for i = 1, inst._numloops:value() do
			table.insert(inst._vine_anims, "vine_loop")
		end
		table.insert(inst._vine_anims, "vine_pst")

		local prng = PRNG_Uniform(inst._seed:value())
		local theta = prng:Rand() * TWOPI
		local delta = TWOPI / NUM_VINES
		local list = {}
		for i = NUM_VINES, 1, -1 do
			list[i] = i
		end
		local delay = not inst._emerged:value() and -0.1 * inst._synct:value() or nil
		for i = NUM_VINES, 1, -1 do
			local rnd = prng:RandInt(i)
			local v = list[rnd]
			list[rnd] = list[i]
			local theta1 = theta + v * delta
			local r = VINES_RADIUS * (0.85 + 0.1 * prng:Rand())
			local xoffs = r * math.cos(theta1)
			local zoffs = -r * math.sin(theta1)
			local emergeframe = (i == 1 and 0) or (i == 2 and 5) or prng:RandInt(2, 3)
			local emergeflip = prng:Rand() < 0.5
			local emergescale = 0.9 + 0.1 * prng:Rand()
			if delay then
				if delay > 0 then
					inst:DoTaskInTime(delay, SpawnVineAtXZ, xoffs, zoffs, 0, emergeframe, emergeflip, emergescale)
				else
					SpawnVineAtXZ(inst, xoffs, zoffs, -delay, emergeframe, emergeflip, emergescale)
				end
				delay = delay + VINE_DELAY
			else
				SpawnVineAtXZ(inst, xoffs, zoffs, nil, emergeframe, emergeflip, emergescale)
			end
		end
	end
end

local function OnWallUpdate_Vines(inst, dt)
	TrySpawnAllVines(inst)

	if inst._vines then
		local x, _, z = inst.Transform:GetWorldPosition()
		local rot = inst.Transform:GetRotation()
		local theta = rot * DEGREES
		local dirt_xoffs = DIRT_OFFSET * math.cos(theta)
		local dirt_zoffs = -DIRT_OFFSET * math.sin(theta)
		for i = #inst._vines, 1, -1 do
			local v = inst._vines[i]
			if v:IsValid() then
				local x1 = x + v.xoffs
				local z1 = z + v.zoffs
				v.moving = v.lastx ~= x1 or v.lastz ~= z1
				v.lastx, v.lastz = x1, z1
				v.Transform:SetPosition(x1, 0, z1)
				v.Transform:SetRotation(rot)
				if v.dirt then
					if v.dirt.AnimState:GetCurrentAnimationFrame() < 8 then
						v.dirt.Transform:SetPosition(x1 + dirt_xoffs, 0, z1 + dirt_zoffs)
						v.dirt.Transform:SetRotation(rot)
						v.dirt.AnimState:MakeFacingDirty()
					else
						v.dirt = nil
					end
				end
			else
				inst._vines[i] = inst._vines[#inst._vines]
				inst._vines[#inst._vines] = nil
			end
		end
	end
end

local function OnEmerged(inst)
	inst.components.updatelooper:RemoveOnWallUpdateFn(OnWallUpdate_Vines)

	TrySpawnAllVines(inst)

	if inst._vines then
		local x, _, z = inst.Transform:GetWorldPosition()
		local rot = inst.Transform:GetRotation()
		for i = #inst._vines, 1, -1 do
			local v = inst._vines[i]
			if v:IsValid() then
				if v.dirttask then
					v.dirttask:Cancel()
					v.dirttask = nil
				end
				v.Transform:SetPosition(x + v.xoffs, 0, z + v.zoffs)
				v.Transform:SetRotation(rot)
				v.AnimState:PlayAnimation("vine_miss")
				v.AnimState:SetFrame(v.emergeframe + inst._synct:value())
				v.AnimState:SetScale(v.emergeflip and -v.emergescale or v.emergescale, v.emergescale)
			else
				inst._vines[i] = inst._vines[#inst._vines]
				inst._vines[#inst._vines] = nil
			end
		end
	end
end

local DETECT_DELAY = 0.3
local DETECT_RADIUS = 6
local DETECT_RADIUS_HIT_MOUNTED_SQ = 1.7 * 1.7
local DETECT_RADIUS_HIT_SQ = 1.2 * 1.2 --unmounted
local DETECT_TAGSET
local EMERGED_LIFETIME = 1.5

local function EndLockOn(target)
	target._charlie_boss_vines_lockon = nil
end

local function OnUpdate_Server(inst, dt)
	if dt <= 0 then
		return
	end

	inst._t = inst._t + dt

	if inst._emerged:value() then
		if inst._t < EMERGED_LIFETIME then
			inst._synct:set_local(math.floor(inst._t / FRAMES + 0.5))
		else
			inst:Remove()
		end
		return
	end

	local t = inst._t - DETECT_DELAY

	--lifetime is 1s per loop + 1.7s
	if t >= inst._numloops:value() + 1.7 then
		inst:Remove()
		return
	end

	inst._synct:set_local(math.floor(inst._t * 10 + 0.5))

	local x, _, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation()
	local neardir, neartarget

	--detect_duration is 1s per loop
	if t >= 0 and t < inst._numloops:value() and inst.caster and inst.caster:IsValid() and not inst.caster.components.health:IsDead() then
		inst.caster.components.combat.ignorehitrange = true

		local targets = {}
		local xa, za, count = 0, 0, 0
		--NOTE: we want target to be partially inside the radius, so don't add physics radius padding
		for _, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, DETECT_RADIUS, inst.caster:GetAOEAttackTagSet():GetRegistered())) do
			if v ~= inst and not targets[v] and
				v:IsValid() and not v:IsInLimbo() and
				v.components.pinnable and not (
					v.components.pinnable:IsStuck() and
					v.components.pinnable.goo_build == "goo_vines" and
					v.components.pinnable:GetTimeStuck() < 0.65
				) and
				not (IsEntityDeadOrGhost(v) or v:HasTag("flying")) and
				not (v.sg and v.sg:HasStateTag("knockback") and v.sg:HasStateTag("nointerrupt")) and
				inst.caster.components.combat:CanTarget(v)
			then
				local mount = v.components.rider and v.components.rider.mount
				local x1, _, z1 = v.Transform:GetWorldPosition()
				local dx = x1 - x
				local dz = z1 - z
				local dsq = dx * dx + dz * dz
				if dsq < (mount and DETECT_RADIUS_HIT_MOUNTED_SQ or DETECT_RADIUS_HIT_SQ) then
					local wasstuck = v.components.pinnable:IsStuck()
					local knockback
					if wasstuck then
						knockback = true
					else
						v.components.pinnable:Stick("goo_vines", splashfxlist)
						knockback = not v.components.pinnable:IsStuck()
					end

					targets[v] = true
					if mount then
						targets[mount] = true
					end

					inst.caster.components.combat:DoAttack(v, inst, inst)
					if knockback then
						v:PushEvent("knockback", { knocker = inst, radius = VINES_RADIUS + 0.5, strengthmult = 0.5 })
					end

					xa = xa + x1
					za = za + z1
					count = count + 1
				elseif neardir == nil and dsq ~= 0 and (v._charlie_boss_vines_lockon == nil or v._charlie_boss_vines_lockon.vines == inst) then
					local dir1 = math.atan2(-dz, dx) * RADIANS
					local diff = ReduceAngle(dir1 - rot)
					if DiffAngle(rot, dir1) < 90 then
						neardir = dir1
						neartarget = v
					end
				end
			end
		end

		inst.caster.components.combat.ignorehitrange = false

		if count > 0 then
			inst.components.locomotor:Stop()
			xa = (x + xa / count) / 2
			za = (z + za / count) / 2
			inst.Physics:Teleport(xa, 0, za)

			inst.SoundEmitter:KillSound("loop")
			inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_spawn")

			inst._emerged:set(true)
			inst._t = 0
			inst._synct:set(0)
			OnEmerged(inst)

			return
		end
	end

	if inst.dest then
		local delta
		if neartarget and neartarget:IsValid() then
			if neartarget._charlie_boss_vines_lockon then
				neartarget._charlie_boss_vines_lockon:Cancel()
			end
			neartarget._charlie_boss_vines_lockon = neartarget:DoTaskInTime(0.1, EndLockOn)
			neartarget._charlie_boss_vines_lockon.vines = inst

			local diff = ReduceAngle(neardir - rot)
			delta = math.clamp(diff, -5, 5)
		end

		delta = delta or inst.deltadir or 0
		delta = ReduceAngle(delta - inst.lastdelta)
		delta = inst.lastdelta + math.clamp(delta, -1, 1)
		inst.lastdelta = delta

		local theta = (inst.Transform:GetRotation() + delta) * DEGREES
		inst.dest.x = x + math.cos(theta)
		inst.dest.z = z - math.sin(theta)
		local speed = Remap(math.min(2, inst._t), 0, 2, unpack(TUNING.CHARLIE_BOSS_VINE_SPEED))
		inst.components.locomotor.walkspeed = speed
		inst.components.locomotor.runspeed = speed
		inst.components.locomotor:GoToPoint(inst.dest, inst.walkto, false)
	end
end

local function InitVines(inst, caster, numloops, deltadir)
	if caster then
		inst.caster = caster
		inst:ListenForEvent("resetboss", function() inst:Remove() end, caster)
	end
	inst._numloops:set(numloops)
	inst.deltadir = deltadir
	inst.dest = Vector3(0, 0, 0)
	inst.walkto = BufferedAction(inst, nil, ACTIONS.WALKTO, nil, inst.dest, nil, nil, nil, nil, 0)

	inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_move", "loop")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst, 100, VINES_RADIUS + 0.4)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst._seed = net_tinybyte(inst.GUID, "charlie_boss_vines._seed")
	inst._numloops = net_tinybyte(inst.GUID, "charlie_boss_vines._numloops")
	inst._synct = net_smallbyte(inst.GUID, "charlie_boss_vines._synct")
	inst._emerged = net_bool(inst.GUID, "charlie_boss_vines._emerged", "emergeddirty")

	inst._numloops:set(3)

	inst:AddComponent("updatelooper")

	if not TheNet:IsDedicated() then
		inst.components.updatelooper:AddOnWallUpdateFn(OnWallUpdate_Vines)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("emergeddirty", OnEmerged)

		return inst
	end

	inst._seed:set(math.random(0, 7))

	inst.components.updatelooper:AddOnUpdateFn(OnUpdate_Server)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.CHARLIE_BOSS_VINE_DAMAGE)
	--weapon planar damage stacks with boss, so no need to add our own

	inst:AddComponent("projectile")

	inst:AddComponent("locomotor")
	inst.components.locomotor:EnableGroundSpeedMultiplier(false)
	inst.components.locomotor:SetTriggersCreep(false)
	inst.components.locomotor.walkspeed = TUNING.CHARLIE_BOSS_VINE_SPEED[1]
	inst.components.locomotor.runspeed = TUNING.CHARLIE_BOSS_VINE_SPEED[1]
	inst.components.locomotor.directdrive = true

	inst._t = 0
	inst.lastdelta = 0
	inst.persists = false
	inst.InitVines = InitVines

	return inst
end

return Prefab("charlie_boss_vines", fn, assets, splashfxlist)
