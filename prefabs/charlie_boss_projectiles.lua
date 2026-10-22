local easing = require("easing")

local assets =
{
	Asset("ANIM", "anim/charlie_boss_actions.zip"),
}

local prefabs =
{
	"charlie_boss_projectile_hit_fx",
}

local AOEUtil = require("aoeutil")

--copied from "charlie_boss_minions.lua"
local function DoFlash(v, flashparams)
	if #flashparams > 0 then
		local c = table.remove(flashparams, 1)
		v.components.colouradder:PushColour("charlie_boss_minion", c, 0, 0, 0)
	else
		v.components.colouradder:PopColour("charlie_boss_minion")
		v._charlie_boss_minion_flash_task:Cancel()
		v._charlie_boss_minion_flash_task = nil
	end
end

local function OnAttackOther(inst, v)
	if v:IsValid() then
		if v.components.colouradder == nil then
			v:AddComponent("colouradder")
		end
		if v._charlie_boss_minion_flash_task then
			v._charlie_boss_minion_flash_task:Cancel()
		end
		local flashparams = { 0.65, 0.6, 0.5, 0.3 }
		v._charlie_boss_minion_flash_task = v:DoPeriodicTask(0, DoFlash, nil, flashparams)
		DoFlash(v, flashparams)
	end
end

local function SpawnHitFxAtXYZ(x, y, z)
	local fx = SpawnPrefab("charlie_boss_projectile_hit_fx")
	fx.Transform:SetPosition(x, math.max(0, y - 0.2), z)
	fx.AnimState:SetScale(math.random() < 0.5 and -1 or 1, 1)
	fx.SoundEmitter:PlaySound("rifts8/charlie/projectile_impact")
	return fx
end

local function CreateMissileLoop()
	local looper = CreateEntity()

	--[[Non-networked entity]]
	--looper.entity:SetCanSleep(false)
	looper.persists = false

	looper.entity:AddTransform()
	looper.entity:AddAnimState()
	looper.entity:AddFollower()

	looper:AddTag("FX")
	looper:AddTag("NOCLICK")

	looper.AnimState:SetBank("charlie_boss")
	looper.AnimState:SetBuild("charlie_boss_actions")
	looper.AnimState:PlayAnimation("air_ripple_atk_loop", true)
	looper.AnimState:SetSymbolLightOverride("air_ripple_parts_red", 1)

	return looper
end

local function CreateRotator()
	local rotator = CreateEntity()

	--[[Non-networked entity]]
	--rotator.entity:SetCanSleep(false)
	rotator.persists = false

	rotator.entity:AddTransform()
	rotator.entity:AddAnimState()
	rotator.entity:AddDynamicShadow()

	rotator:AddTag("FX")
	rotator:AddTag("NOCLICK")

	rotator.Transform:SetSixFaced()

	rotator.AnimState:SetBank("charlie_boss")
	rotator.AnimState:SetBuild("charlie_boss_actions")
	rotator.AnimState:PlayAnimation("air_ripple_atk_rotation")
	rotator.AnimState:Pause()

	local looper = CreateMissileLoop()
	looper.entity:SetParent(rotator.entity)
	looper.Follower:FollowSymbol(rotator.GUID, "air_ripple_atk_follow", 0, 0, 0, true)

	rotator.scrapbook_inspectonseen = true
	rotator.scrapbook_proxy = "charlie_boss_projectile"

	return rotator
end

local function UpdateShadow(inst)--, dt)
	local x, y, z = inst.rotator.Transform:GetWorldPosition()
	local k = math.clamp(y / 5, 0, 1)
	k = 1 - k * k
	inst.rotator.DynamicShadow:SetSize(1.35 * k, 0.9 * k)

	--V2C: added this here since we already have this update loop
	inst.rotator.AnimState:MakeFacingDirty()
end

local function UpdateAnimTilt(inst)
	inst.rotator.AnimState:SetFrame(inst.tilt:value())
end

local function InitializeVisualFx(inst)
	if inst.rotator == nil then
		inst.rotator = CreateRotator()
		inst.rotator.entity:SetParent(inst.entity)

		inst.components.updatelooper:AddOnUpdateFn(UpdateShadow)
		UpdateShadow(inst)

		if not TheWorld.ismastersim then
			inst:ListenForEvent("tiltdirty", UpdateAnimTilt)
		end
		UpdateAnimTilt(inst)
	end
end

local function Despawn(inst)
	SpawnHitFxAtXYZ(inst.Transform:GetWorldPosition())
	inst:Remove()
end

local function IsEntityInShadow(ent)
	return not (ent.components.playervision == nil or --creatures can all act in the dark
				ent.components.playervision:HasNightVision() or
				ent:IsInLight())
end

local function UpdateFlightPath(inst, dt)
	if not (inst.caster and inst.caster:IsValid()) or inst.caster.components.health:IsDead() then
		Despawn(inst)
		return
	end

	local pt = inst.targetpos
	if inst.target then
		if inst.target:IsValid() then
			pt.x, pt.y, pt.z = inst.target.Transform:GetWorldPosition()
			if IsEntityInShadow(inst.target) then
				--blending into shadows causes losing the target lock
				inst.target_in_shadows = (inst.target_in_shadows or 0) + dt
				if inst.target_in_shadows > 0.3 then
					inst.target = nil
					inst.target_in_shadows = nil
				end
			else
				inst.target_in_shadows = nil
			end
		else
			inst.target = nil
			inst.target_in_shadows = nil
		end
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local dx = pt.x - x
	local dz = pt.z - z
	local dsq = dx * dx + dz * dz
	local physrad

	if inst.target then
		physrad = inst.target:GetPhysicsRadius(0)
		if y < math.max(0.5, physrad) * 2.5 then
			local range = 0.5 + physrad
			if dsq < range * range then
				inst:Detonate()
				return
			end
		end
	end
	if y < 0.5 then
		inst:Detonate()
		return
	end

	inst.t = inst.t + dt
	inst.maxturn = math.min(1, inst.maxturn + dt * 2)
	if dsq ~= 0 then
		local dir = inst.Transform:GetRotation()
		local dir1 = math.atan2(-dz, dx) * RADIANS
		local diff = ReduceAngle(dir1 - dir)
		local maxturn = inst.maxturn * inst.maxturn * 15
		diff = math.clamp(diff * 0.5, -maxturn, maxturn)
		inst.Transform:SetRotation(dir + diff)
	end

	local g = -1

	local dy = pt.y - y + (inst.target and 1 or 0.4) --aim a little above target base (i.e. ground)
	if dsq ~= 0 or dy ~= 0 then
		local dist = math.sqrt(dsq)
		local pct = 0.5 - math.atan2(dist, math.abs(dy)) / TWOPI
		local tilt = math.floor(pct * 60 + 0.5)
		local diff = tilt - inst.tilt:value()
		while diff > 30 do
			diff = diff - 60
		end
		while diff < -30 do
			diff = diff + 60
		end
		if diff ~= 0 then
			tilt = inst.tilt:value() + (diff > 0 and 1 or -1)
			if tilt > 60 then
				tilt = tilt - 60
			elseif tilt < 0 then
				tilt = tilt + 60
			end
			inst.tilt:set(tilt)
			if inst.rotator then
				UpdateAnimTilt(inst)
			end
		end

		local theta = tilt / 60 * TWOPI
		local speed = easing.inQuad(math.min(inst.acceltime, inst.t), TUNING.CHARLIE_BOSS_PROJECTILE_SPEED[1], TUNING.CHARLIE_BOSS_PROJECTILE_SPEED[2], inst.acceltime)
		local vx = math.sin(theta) * speed
		local vy = math.cos(theta) * speed
		inst.Physics:SetMotorVel(vx, vy - g, 0)
	end

	if inst.target then
		inst.target:PushEvent("epicscare", { scarer = inst, duration = 1 })
	end
end

local function Launch(inst, caster, targetorpos, x, y, z, dir)
	inst.Physics:Teleport(x, y, z)
	inst.Transform:SetRotation(dir)
	inst.SoundEmitter:PlaySound("rifts2/thrall_wings/projectile")

	if targetorpos:is_a(EntityScript) then
		inst.target = targetorpos
		inst.targetpos = targetorpos:GetPosition()
	else
		inst.target = nil
		inst.targetpos = targetorpos
	end

	if caster then
		inst.caster = caster
		inst:ListenForEvent("resetboss", function() inst:Remove() end, caster)
	end
	inst.tilt:set(math.random(3, 7))
	inst.maxturn = 0
	inst.t = 0

	local lifetime = GetRandomMinMax(unpack(TUNING.CHARLIE_BOSS_PROJECTILE_LIFETIME))
	inst.acceltime = (0.4 + 0.35 * math.random()) * lifetime

	inst:DoTaskInTime(lifetime, Despawn)

	inst.components.updatelooper:AddOnUpdateFn(UpdateFlightPath)
	UpdateFlightPath(inst, 0)
end

local function Detonate(inst)
	if inst.caster and inst.caster:IsValid() and not inst.caster.components.health:IsDead() then
		inst:ListenForEvent("onattackother", function(caster, data)
			if data and data.target and data.projectile == inst then
				OnAttackOther(inst, data.target)
			end
		end, inst.caster)
		AOEUtil.Attack(inst, 1.2, inst.caster:GetAOEAttackTagSet(), nil, nil, inst.caster, inst, inst)
	end
	Despawn(inst)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.entity:AddPhysics()
	inst.Physics:SetMass(1)
	inst.Physics:SetSphere(0.5)

	inst:AddTag("CLASSIFIED")
	inst:AddTag("pseudoprojectile")

	inst.tilt = net_smallbyte(inst.GUID, "wagboss_missile.tilt", "tiltdirty")
	inst.tilt:set(5)

	inst:AddComponent("updatelooper")

	if not TheNet:IsDedicated() then
		InitializeVisualFx(inst)
	end

	inst.scrapbook_inspectonseen = true

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_bank = "charlie_boss"
	inst.scrapbook_build = "charlie_boss_actions"
	inst.scrapbook_anim = "air_ripple_atk_loop"
	inst.scrapbook_planardamage = TUNING.CHARLIE_BOSS_PLANAR_DAMAGE
	inst.scrapbook_thingtype = "creature"

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.CHARLIE_BOSS_PROJECTILE_DAMAGE)
	--weapon planar damage stacks with boss, so no need to add our own

	inst:AddComponent("projectile")

	inst.Launch = Launch
	inst.Detonate = Detonate
	inst.OnEntitySleep = inst.Remove

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function reflectfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("charlie_boss")
	inst.AnimState:SetBuild("charlie_boss_actions")
	inst.AnimState:PlayAnimation("air_ripple_block")
	inst.AnimState:SetSymbolLightOverride("air_ripple_parts_red", 1)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	--don't use "animover", charlie_boss uses that event to spawn the projectile
	inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function hitfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("charlie_boss")
	inst.AnimState:SetBuild("charlie_boss_actions")
	inst.AnimState:PlayAnimation("air_ripple_atk_impact")
	inst.AnimState:SetFinalOffset(7)
	inst.AnimState:SetSymbolLightOverride("fx_red_particle", 1)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("charlie_boss_projectile", fn, assets, prefabs),
	Prefab("charlie_boss_reflect_projectile_fx", reflectfxfn, assets),
	Prefab("charlie_boss_projectile_hit_fx", hitfxfn, assets)
