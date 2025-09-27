local easing = require("easing")
local WagBossUtil = require("prefabs/wagboss_util")

local assets =
{
	Asset("ANIM", "anim/wagboss_beam.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagboss_util.lua"),
}

local function CreateRing()
	local ring = CreateEntity()

	--[[Non-networked entity]]
	--beam.entity:SetCanSleep(false)
	ring.persists = false

	ring.entity:AddTransform()
	ring.entity:AddAnimState()

	ring:AddTag("FX")
	ring:AddTag("NOCLICK")

	ring.AnimState:SetBank("wagboss_beam")
	ring.AnimState:SetBuild("wagboss_beam")
	ring.AnimState:PlayAnimation("ground_marker_pre")
	ring.AnimState:PushAnimation("ground_marker_loop")
	ring.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	ring.AnimState:SetLightOverride(0.3)
	ring.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	ring.AnimState:SetLayer(LAYER_BACKGROUND)
	ring.AnimState:SetSortOrder(3)

	return ring
end

--------------------------------------------------------------------------

local function DoAnimSync_Client(inst)
	if inst.AnimState:IsCurrentAnimation("beam_pre") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		local len = inst.ring.AnimState:GetCurrentAnimationLength()
		if t < len then
			inst.ring.AnimState:SetTime(t)
		else
			inst.ring.AnimState:PlayAnimation("ground_marker_loop", true)
			inst.ring.AnimState:SetTime(t - len)
		end
	elseif inst.AnimState:IsCurrentAnimation("beam_pst") then
		inst.ring.AnimState:PlayAnimation("ground_marker_pst")
		inst.ring.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
	else
		inst.ring.AnimState:PlayAnimation("ground_marker_loop", true)
		inst.ring.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
	end
end

local function CancelPostUpdate_Client(inst, PostUpdate_Client)
	inst._cancelpostupdatetask = nil
	inst._postupdating = nil
	inst.components.updatelooper:RemovePostUpdateFn(PostUpdate_Client)
end

local function PostUpdate_Client(inst)
	if inst._cancelpostupdatetask then
		return
	end
	inst._cancelpostupdatetask = inst:DoStaticTaskInTime(0, CancelPostUpdate_Client, PostUpdate_Client)
	DoAnimSync_Client(inst)
end

local function OnAnimSync_Client(inst)
	if not inst._postupdating then
		inst._postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(PostUpdate_Client)
	elseif inst._cancelpostupdatetask then
		inst._cancelpostupdatetask:Cancel()
		inst._cancelpostupdatetask = nil
	end
end

--------------------------------------------------------------------------

local function StartPreSound(inst)
	inst._initsoundtask = nil
	inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_up")
end

local function UpdateTracking(inst, dt)
	if not inst.target:IsValid() then
		inst.target = nil
		inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
		return
	end
	dt = dt * TheSim:GetTimeScale()
	if dt > 0 then
		local t = inst.trackingt + dt
		if t >= inst.trackinglen then
			inst.target = nil
			inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
		else
			local x, y, z = inst.Transform:GetWorldPosition()
			local x1, y1, z1 = inst.target.Transform:GetWorldPosition()
			local k = easing.outQuad(t, 0.8, 0.2, inst.trackinglen)
			local k1 = 1 - k
			inst.Transform:SetPosition(x * k + x1 * k1, 0, z * k + z1 * k1)
			inst.trackingt = t
		end
	end
end

local function TrackTarget(inst, target, x0, z0)
	if inst.targets == nil and inst.AnimState:IsCurrentAnimation("beam_pre") then
		if inst.target == nil then
			local x, y, z = target.Transform:GetWorldPosition()
			local dx = x - x0
			local dz = z - z0
			local dist = math.sqrt(dx * dx + dz * dz)
			local k = math.min(dist / 2, 1) / dist
			inst.Transform:SetPosition(x - k * dx, 0, z - k * dz)
			inst.components.updatelooper:AddOnWallUpdateFn(UpdateTracking)
			inst.trackingt = inst.AnimState:GetCurrentAnimationTime()
			inst.trackinglen = inst.AnimState:GetCurrentAnimationLength()
		end
		inst.target = target

		if inst._initsoundtask then
			inst._initsoundtask:Cancel()
			StartPreSound(inst)
		end
	end
end

--------------------------------------------------------------------------

local REGISTERED_AOE_TAGS
local BEAM_WORK_ACTIONS =
{
	CHOP = true,
	DIG = true,
	HAMMER = true,
	MINE = true,
}
local BEAM_RADIUS = 3
local BEAM_RANGE_PADDING = 3

local function TossLaunch(inst, launcher, basespeed, startheight)
	local x0, y0, z0 = launcher.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
	else
		angle = TWOPI * math.random()
	end
	local sina, cosa = math.sin(angle), math.cos(angle)
	local speed = basespeed + math.random()
	inst.Physics:Teleport(x1, startheight, z1)
	inst.Physics:SetVel(cosa * speed, speed * 5 + math.random() * 2, sina * speed)
end

local function UpdateBeamAOE(inst, dt)
	if REGISTERED_AOE_TAGS == nil then
		local tags = { "_combat", "_inventoryitem", "pickable", "NPC_workable" }
		for k in pairs(BEAM_WORK_ACTIONS) do
			table.insert(tags, k.."_workable")
		end
		REGISTERED_AOE_TAGS = TheSim:RegisterFindTags(
			nil,
			{ "FX", "DECOR", "INLIMBO", "flight", "invisible" },
			tags
		)
	end
	local tick = GetTick()
	local prevcoloured = inst.coloured2
	local commander = inst.caster and inst.caster:IsValid() and inst.caster.components.commander or nil
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, BEAM_RADIUS + BEAM_RANGE_PADDING, REGISTERED_AOE_TAGS)) do
		if v ~= inst and v:IsValid() and not v:IsInLimbo() then
			local physrad = v:GetPhysicsRadius(0)
			local range = BEAM_RADIUS + physrad
			local dsq = v:GetDistanceSqToPoint(x, y, z)
			if dsq < range * range then
				if not (commander and commander:IsSoldier(v)) then
					if inst.targets[v] == nil then
						local isworkable = false
						if v.components.workable then
							local work_action = v.components.workable:GetWorkAction()
							--V2C: nil action for NPC_workable (e.g. campfires)
							isworkable =
								(	work_action == nil and v:HasTag("NPC_workable")	) or
								(	v.components.workable:CanBeWorked() and
									work_action and
									BEAM_WORK_ACTIONS[work_action.id] and
									not (	work_action == ACTIONS.DIG and
											(	v.components.spawner or
												v.components.childspawner
											)
										)
								)
						end
						if isworkable then
							v.components.workable:Destroy(inst)
							if v:IsValid() then
								if v:HasTag("stump") then
									v:Remove()
								else
									inst.targets[v] = tick
								end
							end
						elseif v.components.pickable and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
							v.components.pickable:Pick(inst)
							inst.targets[v] = tick
						elseif v.components.combat and inst.components.combat:CanTarget(v) then
							if v:HasAnyTag("brightmare", "brightmareboss") then
								if v.components.health and not v.components.health:IsDead() then
									v.components.health:DoDelta(TUNING.WAGBOSS_BEAM_BRIGHTMARE_HEAL, true, inst.nameoverride, true, inst, true)
									v.components.health.lastlunarburnpulsetick = tick
									v.components.health:RegisterLunarBurnSource(inst, WagBossUtil.LunarBurnFlags.GENERIC)
									inst.targets[v] = tick
								end
							elseif v.components.health then
								if inst.firsthit then
									inst.components.combat:DoAttack(v)
								else
									local mount = v.components.rider and v.components.rider:GetMount() or nil
									if mount and mount.components.health and not mount.components.health:IsDead() then
										local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.WAGBOSS_BEAM_LUNAR_BURN_DPS)
										mount.components.health:DoDelta(-dmg, false, inst.nameoverride, nil, inst)
									end
									local dmg = WagBossUtil.CalcLunarBurnTickDamage(v, TUNING.WAGBOSS_BEAM_LUNAR_BURN_DPS)
									v.components.health:DoDelta(-dmg, false, inst.nameoverride, nil, inst)
								end
								if v.components.grogginess and not v.components.health:IsDead() then
									v.components.grogginess:MaximizeGrogginess()
								end
								v.components.health.lastlunarburnpulsetick = tick
								v.components.health:RegisterLunarBurnSource(inst, WagBossUtil.LunarBurnFlags.GENERIC)
								inst.targets[v] = tick
							else
								inst.components.combat:DoAttack(v)
								inst.targets[v] = tick
							end
						elseif v.components.inventoryitem and v.components.locomotor == nil then
							if v.components.mine then
								v.components.mine:Deactivate()
							end
							if not v.components.inventoryitem.nobounce then
								TossLaunch(v, inst, 1.2, 0.1)
							end
							inst.targets[v] = tick
						end
					elseif v.components.health then
						if v:HasAnyTag("brightmare", "brightmareboss") and not v.components.health:IsDead() then
							v.components.health:DoDelta(TUNING.WAGBOSS_BEAM_BRIGHTMARE_HEAL, true, inst.nameoverride, true, inst, true)
							inst.targets[v] = tick
						elseif v.components.combat and inst.components.combat:CanTarget(v) then
							local pulse = tick >= v.components.health.lastlunarburnpulsetick + 12
							if pulse then
								v.components.health.lastlunarburnpulsetick = tick
							end
							local mount = v.components.rider and v.components.rider:GetMount() or nil
							if mount and mount.components.health and not mount.components.health:IsDead() then
								local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.WAGBOSS_BEAM_LUNAR_BURN_DPS)
								mount.components.health:DoDelta(-dmg, not pulse, inst.nameoverride, nil, inst)
							end
							local dmg = WagBossUtil.CalcLunarBurnTickDamage(v, TUNING.WAGBOSS_BEAM_LUNAR_BURN_DPS)
							v.components.health:DoDelta(-dmg, not pulse, inst.nameoverride, nil, inst)
							if v.components.grogginess and not v.components.health:IsDead() then
								v.components.grogginess:MaximizeGrogginess()
							end
							inst.targets[v] = tick
						else
							v.components.health:UnregisterLunarBurnSource(inst)
							inst.targets[v] = nil
						end
					end
				end
				if v:IsValid() then
					local c = Remap(math.sqrt(dsq), BEAM_RADIUS - physrad, BEAM_RADIUS + physrad, 0, 1)
					if c < 1 then
						c = math.max(0, c)
						c = 1 - c * c
						if v:HasTag("epic") then
							c = c * 0.4
						elseif v:HasTag("largecreature") then
							c = c * 0.6
						end
						if c ~= prevcoloured[v] then
							if v.components.colouradder == nil then
								v:AddComponent("colouradder")
							end
							v.components.colouradder:PushColour(inst, c, c, c, 0)
						end
						prevcoloured[v] = nil
						inst.coloured1[v] = c
					end
				end
			end
		end
	end
	--check if things that have health component were still in lunar beam
	for k, v in pairs(inst.targets) do
		if k:IsValid() then
			if k.components.health and v < tick then
				k.components.health:UnregisterLunarBurnSource(inst)
				inst.targets[k] = nil
			end
		else
			inst.targets[k] = nil
		end
	end
	for k in pairs(prevcoloured) do
		if k:IsValid() and k.components.colouradder then
			k.components.colouradder:PopColour(inst)
		end
		prevcoloured[k] = nil
	end
	inst.coloured2 = inst.coloured1
	inst.coloured1 = prevcoloured
	inst.firsthit = nil
end

local FADE_TIME = 0.75
local function UpdateColouredFade(inst, dt)
	local prevcoloured = inst.coloured2
	local t = inst.fadet + dt
	inst.fadet = t

	if t < FADE_TIME then
		local c = easing.inQuad(t, 1, -1, FADE_TIME)
		for k, v in pairs(prevcoloured) do
			if k:IsValid() and k.components.colouradder then
				v = v * c
				k.components.colouradder:PushColour(inst, v, v, v, 0)
			else
				prevcoloured[k] = nil
				if next(prevcoloured) == nil then
					inst.components.updatelooper:RemoveOnUpdateFn(UpdateColouredFade)
				end
			end
		end
	else
		for k in pairs(prevcoloured) do
			if k:IsValid() and k.components.colouradder then
				k.components.colouradder:PopColour(inst)
			end
			prevcoloured[k] = nil
		end
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateColouredFade)
	end
end

local function StartBeamAOE(inst)
	if inst.target then
		inst.target = nil
		inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
	end
	inst.targets = {}
	inst.coloured1 = {}
	inst.coloured2 = {}
	inst.firsthit = true
	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamAOE)

	inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_down_LP", "loop")
end

local function UpdateBeamLightPre(inst)--, dt)
	if inst.AnimState:IsCurrentAnimation("beam_pre") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame > 28 then
			local len = inst.AnimState:GetCurrentAnimationNumFrames()
			local r = easing.outQuad(frame - 28, 0, 3, len - 28)
			inst.Light:SetRadius(r)
			inst.Light:Enable(true)
		end
	else
		inst.Light:SetRadius(3)
		inst.Light:Enable(true)
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPre)
	end
end

local function UpdateBeamLightPst(inst)--, dt)
	if inst.AnimState:IsCurrentAnimation("beam_pst") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame < 5 then
			inst.Light:SetRadius(3)
			inst.Light:Enable(true)
		elseif frame < 10 then
			local r = easing.inQuad(frame - 4, 3, -3, 10 - 4)
			inst.Light:SetRadius(r)
			inst.Light:Enable(true)
		else
			inst.Light:Enable(false)
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
		end
	else
		inst.Light:Enable(false)
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
	end
end

local function KillFx(inst)
	if inst:IsAsleep() then
		inst:Remove()
		return
	elseif inst.ring then
		inst.ring.AnimState:PlayAnimation("ground_marker_pst")
	end
	inst.AnimState:PlayAnimation("beam_pst")
	inst:ListenForEvent("animover", inst.Remove)
	inst.OnEntitySleep = inst.Remove
	inst.animsync:set_local(true)
	inst.animsync:set(true)
	inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamAOE)
	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPst)
	if next(inst.coloured2) then
		inst.components.updatelooper:AddOnUpdateFn(UpdateColouredFade)
		inst.fadet = 0
	end
	for k in pairs(inst.targets) do
		if k:IsValid() and k.components.health then
			k.components.health:UnregisterLunarBurnSource(inst)
		end
	end

	inst.SoundEmitter:KillSound("loop")
	inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_down_pst")
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.Light:SetIntensity(0.5)
	inst.Light:SetFalloff(0.95)
	inst.Light:SetColour(0.01, 0.35, 1)
	inst.Light:Enable(false)

	inst.AnimState:SetBank("wagboss_beam")
	inst.AnimState:SetBuild("wagboss_beam")
	inst.AnimState:PlayAnimation("beam_pre")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)

	inst.animsync = net_bool(inst.GUID, "wagboss_beam_fx.animsync", "animsyncdirty")
	inst.animsync:set(true)

	inst:SetPrefabNameOverride("wagboss_robot") --for death announce

	inst:AddComponent("updatelooper")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.ring = CreateRing()
		inst.ring.entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("animsyncdirty", OnAnimSync_Client)
		OnAnimSync_Client(inst)

		return inst
	end

	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPre)

	inst.AnimState:PushAnimation("beam_loop")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(0)
	inst.components.combat.ignorehitrange = true

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_BEAM_PLANAR_DAMAGE)

	inst._initsoundtask = inst:DoTaskInTime(0, StartPreSound)
	inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), StartBeamAOE)
	inst:DoTaskInTime(6, KillFx)

	inst.TrackTarget = TrackTarget

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("wagboss_beam_fx", fn, assets)
