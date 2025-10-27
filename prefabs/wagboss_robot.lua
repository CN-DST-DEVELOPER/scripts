local assets =
{
	Asset("ANIM", "anim/wagboss_robot.zip"),
	Asset("ANIM", "anim/wagboss_lunar.zip"),
	Asset("ANIM", "anim/wagboss_lunar_spawn.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local prefabs =
{
	"alterguardian_phase4_lunarrift",
	"wagboss_missile",
	"wagboss_beam_fx",
	"wagboss_robot_leg",
	"temp_beta_msg", --#TEMP_BETA

	"gears",
	"transistor",
	"wagpunk_bits",

    "chesspiece_wagboss_robot_sketch",
}

SetSharedLootTable("wagboss_robot",
{
	{ "gears",				0.5 },
	{ "transistor",			0.5 },
	{ "wagpunk_bits",		1.0 },
	{ "wagpunk_bits",		0.5 },
	{"chesspiece_wagboss_robot_sketch", 1.0},
})

local brain = require("brains/wagboss_robotbrain")
local WagdroneCommon = require("prefabs/wagdrone_common")

--------------------------------------------------------------------------

local function OnRemoveHighlightChild(child)
	table.removearrayvalue(child.highlightparent.highlightchildren, child)
end

--------------------------------------------------------------------------

local function UpdateFlyers(inst, dt)
	assert(next(inst._temptbl1) == nil)
	local flyers = inst._temptbl1
	inst.components.commander:CollectSoldiers(flyers, "wagdrone_flying")

	local delay = inst.flyer_atk_delay
	if inst.engaged then
		if delay > dt then
			delay = delay - dt
		else
			for i, v in ipairs(flyers) do
				v:PushEvent("doattack")
			end
			delay = 4 + math.random() * 2
		end
	elseif delay < 4 then
		delay = 4 + math.random() * 2
	end
	inst.flyer_atk_delay = delay

	local busy
	for i, v in ipairs(flyers) do
		if not v.sg:HasAnyStateTag("idle", "moving") then
			busy = true
			break
		end
	end

	local t = inst.flyer_t
	if not busy then
		t = t + dt
		if t > 5 then
			t = t - 5
		end
		inst.flyer_t = t
	end

	local r
	if t >= 1.5 and t <= 3.5 then
		r = 4
	else
		local t1 = t > 3.5 and t - 2 or t
		r = 8 + 4 * math.cos(t1 / 3 * TWOPI)
	end

	local theta = inst.flyer_theta
	if not busy then
		local circ = TWOPI * r
		local stepdist = TUNING.WAGDRONE_FLYING_RUNSPEED * dt
		local stepangle = TWOPI * stepdist / circ
		theta = ReduceAngleRad(theta + stepangle)
		inst.flyer_theta = theta
	end

	local delta = TWOPI / math.max(6, #flyers)
	local x, y, z = inst.Transform:GetWorldPosition()
	for i = 1, #flyers do
		local x1 = x + r * math.cos(theta)
		local z1 = z - r * math.sin(theta)
		flyers[i].components.locomotor:GoToPoint(Vector3(x1, 0, z1), nil, true)
		flyers[i] = nil
		theta = theta + delta
	end
	--assert(next(flyers) == nil)
end

local function UpdateRollers(inst, dt)
	assert(next(inst._temptbl1) == nil)
	local rollers = inst._temptbl1
	inst.components.commander:CollectSoldiers(rollers, "wagdrone_rolling")

	local delay = inst.roller_xform_delay
	if inst.engaged then
		if #rollers > 1 then
			if delay > dt then
				delay = delay - dt
			else
				inst.roller_stationary = not inst.roller_stationary
				delay = inst.roller_stationary and 14 + math.random() * 2 or 19 + math.random() * 5
				local ev = inst.roller_stationary and "transform_to_stationary" or "transform_to_mobile"
				for i, v in ipairs(rollers) do
					v:PushEvent(ev)
				end
			end
			inst.roller_xform_delay = delay
		end
	else
		if delay < 14 then
			delay = 14 + math.random() * 2
		end
		if inst.roller_stationary then
			inst.roller_stationary = false
			for i, v in ipairs(rollers) do
				v:PushEvent("transform_to_mobile")
			end
		end
	end

	local busy = true
	for i, v in ipairs(rollers) do
		if v.sg:HasAnyStateTag("idle", "moving") and not v.sg:HasAnyStateTag("stationary", "broken", "off") then
			busy = false
			break
		end
	end

	local t = inst.roller_t
	if not busy then
		t = t + dt
		if t > 4 then
			t = t - 4
		end
		inst.roller_t = t
	end

	local r
	if delay < 3 and #rollers > 1 then
		r = (#rollers >= 4 and 9) or
			(#rollers >= 3 and 8) or
			7
	else
		r = 9 + 4 * math.cos(t / 4 * TWOPI)
	end

	local theta = inst.roller_theta
	if not busy then
		local circ = TWOPI * r
		local stepdist = TUNING.WAGDRONE_ROLLING_RUNSPEED * dt
		local stepangle = TWOPI * stepdist / circ
		theta = ReduceAngleRad(theta + stepangle)
		inst.roller_theta = theta
	end

	local delta = TWOPI / #rollers
	local x, y, z = inst.Transform:GetWorldPosition()
	for i = 1, #rollers do
		local x1 = x + r * math.cos(theta)
		local z1 = z - r * math.sin(theta)
		rollers[i].dest = Vector3(x1, 0, z1)
		rollers[i] = nil
		theta = theta + delta
	end
	--assert(next(rollers) == nil)
end

local function SetFlyersActive(inst, active)
	if active then
		if inst.flyer_t == nil then
			inst.flyer_t = 0
			inst.flyer_atk_delay = 4 + math.random() * 2
			inst.flyer_theta = math.random() * TWOPI
			inst.flyer_updating = not inst:IsAsleep()
			if inst.flyer_updating then
				inst.components.updatelooper:AddOnUpdateFn(UpdateFlyers)
			end
		end
	elseif inst.flyer_t then
		inst.flyer_t = nil
		inst.flyer_atk_delay = nil
		inst.flyer_theta = nil
		if inst.flyer_updating then
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateFlyers)
		end
		inst.flyer_updating = nil
	end
end

local function SetRollersActive(inst, active)
	if active then
		if inst.roller_t == nil then
			inst.roller_t = 0
			inst.roller_xform_delay = 19 + math.random() * 5
			inst.roller_stationary = false
			inst.roller_theta = math.random() * TWOPI
			inst.roller_updating = not inst:IsAsleep()
			if inst.roller_updating then
				inst.components.updatelooper:AddOnUpdateFn(UpdateRollers)
			end
		end
	elseif inst.roller_t then
		inst.roller_t = nil
		inst.roller_xform_delay = nil
		inst.roller_stationary = nil
		inst.roller_theta = nil
		if inst.roller_updating then
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateRollers)
		end
		inst.roller_updating = nil
	end
end

local function OnSoldiersChanged(inst)
	local numflyers = inst.components.commander:GetNumSoldiers("wagdrone_flying")
	local numrollers = inst.components.commander:GetNumSoldiers("wagdrone_rolling")
	SetFlyersActive(inst, numflyers > 0)
	SetRollersActive(inst, numrollers > 0)
end

local DRONE_TAGS = { "wagdrone" }
local DRONE_NOTAGS = { "INLIMBO", "HAMMER_workable", "usesdepleted", "NOCLICK" }

local function HackDrones(inst)
	local map = TheWorld.Map
	local x, _, z = inst.Transform:GetWorldPosition()
	local inarena = map:IsPointInWagPunkArena(x, 0, z)
	if inarena then
		x, z = TheWorld.Map:GetWagPunkArenaCenterXZ()
		--NOTE: center won't be nil if IsPointInWagPunkArena succeeded
	end

	for i, v in ipairs(TheSim:FindEntities(x, 0, z, 40, DRONE_TAGS, DRONE_NOTAGS)) do
		if not inarena or map:IsPointInWagPunkArena(v.Transform:GetWorldPosition()) then
			local hp = v.components.finiteuses and v.components.finiteuses:GetPercent() or nil
			inst.components.commander:AddSoldier(v)
			if hp then
				v.components.health:SetPercent(hp)
			end
		end
	end
	inst.components.commander:PushEventToAllSoldiers("activate")
end

local function ReleaseDrones(inst, include_non_soldiers)
	if include_non_soldiers then
		local map = TheWorld.Map
		local x, _, z = inst.Transform:GetWorldPosition()
		local inarena = map:IsPointInWagPunkArena(x, 0, z)
		if inarena then
			x, z = TheWorld.Map:GetWagPunkArenaCenterXZ()
			--NOTE: center won't be nil if IsPointInWagPunkArena succeeded
		end

		for i, v in ipairs(TheSim:FindEntities(x, 0, z, 40, DRONE_TAGS, DRONE_NOTAGS)) do
			if not inst.components.commander:IsSoldier(v) and
				(not inarena or map:IsPointInWagPunkArena(v.Transform:GetWorldPosition()))
			then
				WagdroneCommon.ChangeToLoot(v)
			end
		end
	end

	assert(next(inst._temptbl1) == nil)
	local drones = inst._temptbl1
	inst.components.commander:CollectSoldiers(drones)
	for i = 1, #drones do
		local v = drones[i]
		inst.components.commander:RemoveSoldier(v)
		WagdroneCommon.ChangeToLoot(v)
		drones[i] = nil
	end
	--assert(next(drones) == nil)
end

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	assert(next(inst._temptbl1) == nil and next(inst._temptbl2) == nil)
	local toadd = inst._temptbl1
	local toremove = inst._temptbl2
	local x, y, z = inst.Transform:GetWorldPosition()

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end

	local map = TheWorld.Map
	if map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) then
		for i, v in ipairs(AllPlayers) do
			if not (v.components.health:IsDead() or v:HasTag("playerghost")) and
				v.entity:IsVisible() and
				map:IsPointInWagPunkArena(v.Transform:GetWorldPosition())
			then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		for i, v in ipairs(FindPlayersInRange(x, y, z, TUNING.WAGBOSS_ROBOT_DEAGGRO_DIST, true)) do
			if toremove[v] then
				toremove[v] = nil
			else
				table.insert(toadd, v)
			end
		end
	end

	for k in pairs(toremove) do
		inst.components.grouptargeter:RemoveTarget(k)
		toremove[k] = nil
	end
	for i = 1, #toadd do
		inst.components.grouptargeter:AddTarget(toadd[i])
		toadd[i] = nil
	end
	--assert(next(toadd) == nil and next(toremove) == nil)
end

local function RetargetFn(inst)
	UpdatePlayerTargets(inst)

	local x, y, z = inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	local inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z)
	local target = inst.components.combat.target
	local inrange
	if target then
		local range = TUNING.WAGBOSS_ROBOT_ATTACK_RANGE + target:GetPhysicsRadius(0)
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		inrange = distsq(x1, z1, x, z) < range * range and (not inarena or map:IsPointInWagPunkArena(x1, y1, z1))

		if target.isplayer then
			--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
			local newplayer = inst.components.grouptargeter:TryGetNewTarget()
			if newplayer then
				range = inrange and TUNING.WAGBOSS_ROBOT_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.WAGBOSS_ROBOT_KEEP_AGGRO_DIST
				if newplayer:GetDistanceSqToPoint(x, y, z) < range * range then
					return newplayer, true
				end
			end
			return
		end
	end

	--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
	assert(next(inst._temptbl1) == nil)
	local nearplayers = inst._temptbl1
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		local range = inrange and TUNING.WAGBOSS_ROBOT_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.WAGBOSS_ROBOT_AGGRO_DIST
		if k:GetDistanceSqToPoint(x, y, z) < range * range then
			table.insert(nearplayers, k)
		end
	end
	if #nearplayers > 0 then
		local newplayer = nearplayers[math.random(#nearplayers)]
		for k in pairs(nearplayers) do
			nearplayers[k] = nil
		end
		--assert(next(nearplayers) == nil)
		return newplayer, true
	end
	--assert(next(nearplayers) == nil)
end

local function KeepTargetFn(inst, target)
	if not inst.components.combat:CanTarget(target) then
		return false
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local map = TheWorld.Map
	if map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) then
		return map:IsPointInWagPunkArena(x1, y1, z1)
	end
	return distsq(x, z, x1, z1) < TUNING.WAGBOSS_ROBOT_DEAGGRO_DIST * TUNING.WAGBOSS_ROBOT_DEAGGRO_DIST
end

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() then
		local x, y, z = inst.Transform:GetWorldPosition()
		local target = inst.components.combat.target
		if target and target.isplayer then
			local range = TUNING.WAGBOSS_ROBOT_ATTACK_RANGE + target:GetPhysicsRadius(0)
			if target:GetDistanceSqToPoint(x, y, z) < range * range then
				return --don't switch targets
			end
		end
		local map = TheWorld.Map
		if not map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) or map:IsPointInWagPunkArena(data.attacker.Transform:GetWorldPosition()) then
			inst.components.combat:SetTarget(data.attacker)
		end
	end
end

local function ResetCombatTimers(inst)
	--These are to delay certain attacks when re-aggroing a boss.
	inst.components.timer:StopTimer("leap_cd")
	inst.components.timer:StartTimer("leap_cd", GetRandomMinMax(unpack(TUNING.WAGBOSS_ROBOT_LEAP_CD)))
	if not inst.components.timer:TimerExists("missiles_cd") then
		inst.components.timer:StartTimer("missiles_cd", TUNING.WAGBOSS_ROBOT_MISSILES_CD[1] / 2)
	end
	if not inst.components.timer:TimerExists("orbitalstrike_cd") then
		inst.components.timer:StartTimer("orbitalstrike_cd", TUNING.WAGBOSS_ROBOT_ORBITAL_STRIKE_CD[1] / 2)
	end
end

local function ClearCombatTimers(inst)
	inst.components.timer:StopTimer("tantrum_cd")
	inst.components.timer:StopTimer("leap_cd")
	inst.components.timer:StopTimer("hackdrones_cd")
end

local function SetEngaged(inst, engaged, delay)
	if delay then
		if inst._engagetask == nil or inst._engagetask ~= engaged then
			if inst._engagetask then
				inst._engagetask:Cancel()
			end
			inst._engagetask = inst:DoTaskInTime(delay, SetEngaged, engaged)
			inst._engagetask.engaged = engaged
		end
	else
		if inst._engagetask then
			inst._engagetask:Cancel()
			inst._engagetask = nil
		end
		if inst.engaged ~= engaged then
			inst.engaged = engaged
			if engaged then
				ResetCombatTimers(inst)
			else
				ClearCombatTimers(inst)
			end
		end
	end
end

local function OnNewTarget(inst, data)
	if data and data.target then
		SetEngaged(inst, true)
	end
end

local function OnDroppedTarget(inst)--, data)
	SetEngaged(inst, false, 3)
end

local function SetIgnoreWalls(inst, ignore)
	if (inst.components.locomotor.pathcaps ~= nil) == not ignore then
		inst.components.locomotor.pathcaps = ignore and { ignorewalls = true } or nil
		inst.components.locomotor:Stop()
	end
end

local function DoOffScreenReset(inst)
	inst._resettask = nil
	inst.shouldreset = nil
	inst:RemoveTag("notarget")
	inst:SetTempNoCollide(false, "reset")
	SetIgnoreWalls(inst, false)
	if not (inst.components.health and inst.components.health:IsDead()) then
		local x, z = TheWorld.Map:GetWagPunkArenaCenterXZ()
		if x and z then
			inst.Physics:Teleport(x, 0, z)
		end
		inst.sg:GoToState("off", true)
	end
end

local function DoReset(inst)
	if inst.active and TheWorld.Map:IsPointInWagPunkArena(inst.Transform:GetWorldPosition()) then
		if not inst.shouldreset then
			if inst:IsAsleep() then
				DoOffScreenReset(inst)
			else
				inst.shouldreset = true
				inst:AddTag("notarget")
				inst:SetTempNoCollide(true, "reset")
				SetIgnoreWalls(inst, true)
			end
		end
	elseif inst:IsAsleep() and not (inst.components.health and inst.components.health:IsDead()) then
		inst.sg:GoToState("off", true)
	else
		inst:PushEvent("deactivate")
	end
end

local function CancelReset(inst)
	if inst.shouldreset then
		inst.shouldreset = nil
		inst:RemoveTag("notarget")
		inst:SetTempNoCollide(false, "reset")
		SetIgnoreWalls(inst, false)
		if inst._resettask then
			inst._resettask:Cancel()
			inst._resettask = nil
		end
	end
end

local function OnEntitySleep(inst)
	if inst.hostile then
		SetEngaged(inst, false, 3)
		if inst.flyer_updating then
			inst.flyer_updating = false
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateFlyers)
		end
		if inst.roller_updating then
			inst.roller_updating = false
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateRollers)
		end
	end
	if inst.shouldreset and inst._resettask == nil then
		inst._resettask = inst:DoTaskInTime(6, DoOffScreenReset)
	end
	if inst.sg:HasStateTag("jumping") then
		inst.sg:GoToState("idle")
	end
end

local function OnEntityWake(inst)
	if inst.hostile then
		if inst.flyer_updating == false then --but not nil
			inst.flyer_updating = true
			inst.components.updatelooper:AddOnUpdateFn(UpdateFlyers)
		end
		if inst.roller_updating == false then --but not nil
			inst.roller_updating = true
			inst.components.updatelooper:AddOnUpdateFn(UpdateRollers)
		end
	end
	if inst._resettask then
		inst._resettask:Cancel()
		inst._resettask = nil
	end	
end

--------------------------------------------------------------------------

local function teleport_override_fn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsPointInWagPunkArena(x, y, z) then
		return Vector3(x, y, z)
	end
end

--------------------------------------------------------------------------

local ALTER_SYMBOLS =
{
	"splat_cast",
	"splat_fx",
	"splat_ground",
}

local function AddAlterSymbols(ent)
	for i, v in ipairs(ALTER_SYMBOLS) do
		ent.AnimState:OverrideSymbol(v, "wagboss_lunar_spawn", v)
		ent.AnimState:SetSymbolBloom(v)
		ent.AnimState:SetSymbolMultColour(v, 1, 1, 1, 0.2)
		ent.AnimState:SetSymbolLightOverride(v, 0.5)
	end
end

local function ClearAlterSymbols(ent)
	for i, v in ipairs(ALTER_SYMBOLS) do
		ent.AnimState:ClearOverrideSymbol(v)
		ent.AnimState:ClearSymbolBloom(v)
		ent.AnimState:SetSymbolMultColour(v, 1, 1, 1, 1)
		ent.AnimState:SetSymbolLightOverride(v, 0)
	end
end

local function CreateBackFx()
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_robot")
	fx.AnimState:PlayAnimation("lunar_spawn_1")
	fx.AnimState:SetSymbolBloom("fx_white")
	fx.AnimState:SetSymbolLightOverride("fx_white", 0.3)
	fx.AnimState:Hide("robot_front")
	fx.AnimState:Hide("lunar_comp")
	fx.AnimState:SetFinalOffset(-3)

	AddAlterSymbols(fx)

	fx.OnRemoveEntity = OnRemoveHighlightChild

	return fx
end

local function BackFxPostUpdate_Client(inst)
	if inst.AnimState:IsCurrentAnimation("lunar_spawn_1") then
		if inst._backfx == nil then
			inst._backfx = CreateBackFx()
			inst._backfx.entity:SetParent(inst.entity)
			inst._backfx.highlightparent = inst
			table.insert(inst.highlightchildren, inst._backfx)
			inst.components.colouraddersync:ForceRefresh()
		end
		inst._backfx.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationFrame())
	elseif inst._backfx then
		inst._backfx:Remove()
		inst._backfx = nil
	end

	inst._backfxpostupdating = false
	inst.components.updatelooper:RemovePostUpdateFn(BackFxPostUpdate_Client)
end

local function OnShowBackFx_Client(inst)
	if inst.showbackfx:value() then
		if inst._backfx then
			inst._backfx.AnimState:SetFrame(0)
		end
		if not inst._backfxpostupdating then
			inst._backfxpostupdating = true
			inst.components.updatelooper:AddPostUpdateFn(BackFxPostUpdate_Client)
		end
	else
		if inst._backfx then
			inst._backfx:Remove()
			inst._backfx = nil
		end
		if inst._backfxpostupdating then
			inst._backfxpostupdating = false
			inst.components.updatelooper:RemovePostUpdateFn(BackFxPostUpdate_Client)
		end
	end
end

local function StartBackFx(inst)
	inst.showbackfx:set(true)

	if inst._backfx then
		inst._backfx.AnimState:SetTime(0)
	elseif not TheNet:IsDedicated() then
		inst._backfx = CreateBackFx()
		inst._backfx.entity:SetParent(inst.entity)
		inst._backfx.highlightparent = inst
		table.insert(inst.highlightchildren, inst._backfx)
		inst.components.colouraddersync:ForceRefresh()
	end
end

local function StopBackFx(inst)
	inst.showbackfx:set(false)

	if inst._backfx then
		inst._backfx:Remove()
		inst._backfx = nil
	end
end

--------------------------------------------------------------------------

local TRANSPARENCY = 0.2
local LIGHTOVERRIDE = 0.5

local function AddCrownFlameFx(inst, crown, idx)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")

	fx.AnimState:PlayAnimation("flame_loop", true)
	fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
	fx.Follower:FollowSymbol(crown.GUID, "lb_flame_loop_follow_"..tostring(idx), nil, nil, nil, true)

	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	fx.entity:SetParent(crown.entity)

	table.insert(crown.flames, fx)
	table.insert(inst.followfx, fx)
	table.insert(inst.highlightchildren, fx)
	fx.highlightparent = inst
	fx.OnRemoveEntity = OnRemoveHighlightChild

	return fx
end

local function crown_OnEntityWake(crown)
	--V2C: on server host, nested flame followers may not wake properly
	--     when crown follower symbols are hidden (i.e off but broken).
	for i, v in ipairs(crown.flames) do
		if v:IsAsleep() then
			v.Follower:FollowSymbol(crown.GUID, "lb_flame_loop_follow_"..tostring(i), nil, nil, nil, true)
		end
	end
end

local function AddCrownLayer(inst, layer, numflames)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
	fx.AnimState:SetLightOverride(LIGHTOVERRIDE)

	local baseanim = "crown_"..layer
	fx.AnimState:PlayAnimation(baseanim.."_loop")

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, baseanim.."_follow", nil, nil, nil, true, true)

	fx.flames = {}
	for i = 1, numflames do
		AddCrownFlameFx(inst, fx, i)
	end

	if TheWorld.ismastersim then
		fx.OnEntityWake = crown_OnEntityWake
	end

	return fx
end

local function OnShowCrownDirty(inst)
	if inst.showcrown:value() then
		if inst.crownlayers == nil then
			local fr = AddCrownLayer(inst, "fr", 2)
			local bk = AddCrownLayer(inst, "bk", 3)
			fr:ListenForEvent("animover", function()
				fr.AnimState:PlayAnimation("crown_fr_loop")
				bk.AnimState:PlayAnimation("crown_bk_loop")
				local t = bk.flames[#bk.flames].AnimState:GetCurrentAnimationTime()
				for i, v in ipairs(fr.flames) do
					local t1 = v.AnimState:GetCurrentAnimationTime()
					v.AnimState:SetTime(t)
					t = t1
				end
				for i, v in pairs(bk.flames) do
					local t1 = v.AnimState:GetCurrentAnimationTime()
					v.AnimState:SetTime(t)
					t = t1
				end
			end)
			inst.crownlayers = { fr, bk }
		end
	elseif inst.crownlayers then
		for i, v in ipairs(inst.crownlayers) do
			for j, w in ipairs(v.flames) do
				table.removearrayvalue(inst.followfx, w)
			end
			v:Remove()
		end
		inst.crownlayers = nil
	end
end

local function AddFollowFx(inst, anim, symbol)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_robot")
	fx.AnimState:SetBuild("wagboss_robot")
	fx.AnimState:PlayAnimation(anim, true)

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, symbol, 0, 0, 0, true)

	table.insert(inst.followfx, fx)
	table.insert(inst.highlightchildren, fx)
	fx.highlightparent = inst
	fx.OnRemoveEntity = OnRemoveHighlightChild

	return fx
end

local function CreateStompFx()
	local fx = CreateEntity()

	fx:AddTag("DECOR")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.AnimState:SetBank("wagboss_robot")
	fx.AnimState:SetBuild("wagboss_robot")
	fx.AnimState:PlayAnimation("atk_ground_projection")
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)
	fx.AnimState:SetMultColour(1, 1, 1, 0.2)

	return fx
end

local ClearStompFx_Client --forward declare

local function OnStompFxAnimOver(fx)
	local inst = fx.entity:GetParent()
	inst.showstompfx:set_local(false)
	ClearStompFx_Client(inst)
end

local function StompFxPostUpdate_Client(inst)
	local frame =
		(inst.AnimState:IsCurrentAnimation("atk_squish") and inst.AnimState:GetCurrentAnimationFrame() - 27) or
		(inst.AnimState:IsCurrentAnimation("atk_leap_pst") and inst.AnimState:GetCurrentAnimationFrame() - 4) or
		math.huge

	if frame < 12 then
		if inst._stompfx == nil then
			inst._stompfx = CreateStompFx()
			inst._stompfx.entity:SetParent(inst.entity)
			inst:ListenForEvent("animover", OnStompFxAnimOver, inst._stompfx)
		end
		inst._stompfx.AnimState:SetFrame(math.max(0, frame))
	else
		if inst._stompfx then
			inst._stompfx:Remove()
			inst._stompfx = nil
		end
		inst.showstompfx:set_local(false)
	end

	inst._stompfxpostupdating = false
	inst.components.updatelooper:RemovePostUpdateFn(StompFxPostUpdate_Client)
end

ClearStompFx_Client = function(inst)
	if inst._stompfx then
		inst._stompfx:Remove()
		inst._stompfx = nil
	end
	if inst._stompfxpostupdating then
		inst._stompfxpostupdating = false
		inst.components.updatelooper:RemovePostUpdateFn(StompFxPostUpdate_Client)
	end
end

local function OnShowStompFx_Client(inst)
	if inst.showstompfx:value() then
		if inst._stompfx then
			inst._stompfx.AnimState:SetTime(0)
		end
		if not inst._stompfxpostupdating then
			inst._stompfxpostupdating = true
			inst.components.updatelooper:AddPostUpdateFn(StompFxPostUpdate_Client)
		end
	else
		ClearStompFx_Client(inst)
	end
end

local function StartStompFx(inst)
	inst.showstompfx:set(true)

	if inst._stompfx then
		inst._stompfx.AnimState:SetTime(0)
	elseif not TheNet:IsDedicated() then
		inst._stompfx = CreateStompFx()
		inst._stompfx.entity:SetParent(inst.entity)
	end
end

local function StopStompFx(inst, interrupted)
	if not interrupted then
		inst.showstompfx:set_local(false)
	elseif inst.showstompfx:value() then
		inst.showstompfx:set(false)
	end
	if inst._stompfx then
		inst._stompfx:Remove()
		inst._stompfx = nil
	end
end

--------------------------------------------------------------------------

local PHASES =
{
	{
		hp = 1,
		fn = function(inst)
			inst.cantantrum = false
			inst.canleap = false
			inst.canmissiles = false
			inst.canmissilebarrage = false
			inst.canhackdrones = false
			inst.canorbitalstrike = false
		end,
	},
	{
		hp = 0.95,
		fn = function(inst)
			inst.cantantrum = true
			inst.canleap = true
			inst.canmissiles = false
			inst.canmissilebarrage = false
			inst.canhackdrones = false
			inst.canorbitalstrike = false
		end,
	},
	{
		hp = 0.75,
		fn = function(inst)
			inst.cantantrum = false
			inst.canleap = false
			inst.canmissiles = true
			inst.canmissilebarrage = true
			inst.canhackdrones = false
			inst.canorbitalstrike = false
		end,
		isbarragephase = true,
	},
	{
		hp = 0.65,
		fn = function(inst)
			inst.cantantrum = false
			inst.canleap = false
			inst.canmissiles = false
			inst.canmissilebarrage = false
			inst.canhackdrones = true
			inst.canorbitalstrike = false
		end,
	},
	{
		hp = 0.6,
		fn = function(inst)
			inst.cantantrum = true
			inst.canleap = true
			inst.canmissiles = false
			inst.canmissilebarrage = false
			inst.canhackdrones = true
			inst.canorbitalstrike = false
		end,
	},
	{
		hp = 0.4,
		fn = function(inst)
			inst.cantantrum = false
			inst.canleap = false
			inst.canmissiles = true
			inst.canmissilebarrage = true
			inst.canhackdrones = true
			inst.canorbitalstrike = true
		end,
		isbarragephase = true,
	},
	{
		hp = 0.3,
		fn = function(inst)
			inst.cantantrum = true
			inst.canleap = true
			inst.canmissiles = false
			inst.canmissilebarrage = false
			inst.canhackdrones = true
			inst.canorbitalstrike = true
		end,
	},
	{
		hp = 0.25,
		fn = function(inst)
			inst.cantantrum = true
			inst.canleap = true
			inst.canmissiles = true
			inst.canmissilebarrage = false
			inst.canhackdrones = true
			inst.canorbitalstrike = true
		end,
	},
}

local DEESCALATE_TIME = 30

local function CalcThreatLevel(inst, dps)
	local numthreatlevels = #TUNING.WAGBOSS_ROBOT_ATTACK_PERIOD
	local level = math.floor(Remap(dps, 150, 375, 1, numthreatlevels))
	if inst.sg:HasStateTag("missiles_target_fail") then
		--missiles could not find any targets, but still taking damage, so raise threat level
		level = level + 1
	end
	return math.clamp(level, 1, numthreatlevels)
end

local function SetThreatLevel(inst, level)
	if inst._threattask then
		inst._threattask:Cancel()
	end
	inst._threattask = level > 1 and inst:DoTaskInTime(DEESCALATE_TIME, SetThreatLevel, level - 1) or nil

	if level ~= inst.threatlevel then
		if inst.threatlevel then
			print(inst, "threat level "..(level > inst.threatlevel and "raised" or "lowered").." to "..tostring(level))
		end
		inst.threatlevel = level
		inst.components.combat:SetAttackPeriod(TUNING.WAGBOSS_ROBOT_ATTACK_PERIOD[level])
	end
end

local function OnDpsUpdate(inst, dps)
	local threatlevel = CalcThreatLevel(inst, dps)
	if threatlevel >= inst.threatlevel then
		SetThreatLevel(inst, threatlevel)
	end
end

local function SkipBarragePhase(inst)
	if inst.canmissilebarrage and inst.components.health then
		local healthpct = inst.components.health:GetPercent()
		for i = #PHASES - 1, 1, -1 do
			local v = PHASES[i]
			if healthpct <= v.hp and v.isbarragephase then
				PHASES[i + 1].fn(inst)
				break
			end
		end
	end
end

--------------------------------------------------------------------------

local function SetActiveTags(inst, active, hostile)
	if active then
		if not inst:HasTag("lunar_aligned") then
			inst:AddTag("lunar_aligned")
			inst:AddTag("brightmareboss")
			inst:AddTag("largecreature")
			inst:AddTag("scarytoprey")
		end
		if hostile then
			inst:AddTag("hostile")
		else
			inst:RemoveTag("hostile")
		end
	elseif inst:HasTag("lunar_aligned") then
		inst:RemoveTag("lunar_aligned")
		inst:RemoveTag("brightmareboss")
		inst:RemoveTag("largecreature")
		inst:RemoveTag("scarytoprey")
		inst:RemoveTag("hostile")
	end
end

local function SetLocomotorEnabled(inst, enabled)
	if enabled then
		if inst.components.locomotor == nil then
			inst:AddComponent("locomotor")
			inst.components.locomotor.walkspeed = TUNING.WAGBOSS_ROBOT_WALKSPEED
		end
	elseif inst.components.locomotor then
		inst:RemoveComponent("locomotor")
		inst.Physics:Stop()
	end
end

local function SetCombatEnabled(inst, enabled)
	if enabled then
		if inst.components.combat == nil then
			inst:AddComponent("health")
			inst.components.health:SetMaxHealth(TUNING.WAGBOSS_ROBOT_HEALTH)
			inst.components.health.nofadeout = true

			inst:AddComponent("combat")
			inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_DAMAGE)
			--inst.components.combat:SetAttackPeriod(TUNING.WAGBOSS_ROBOT_ATTACK_PERIOD[1])
			inst.components.combat:SetRange(TUNING.WAGBOSS_ROBOT_ATTACK_RANGE)
			inst.components.combat:SetRetargetFunction(1, RetargetFn)
			inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
			inst.components.combat.playerdamagepercent = TUNING.WAGBOSS_ROBOT_PLAYERDAMAGEPERCENT
			inst.components.combat.hiteffectsymbol = "rb_bod"
			inst.components.combat.battlecryinterval = 10
			--inst.hit_recovery = TUNING.WAGBOSS_ROBOT_HIT_RECOVERY

			inst:AddComponent("healthtrigger")
			for i, v in ipairs(PHASES) do
				inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
			end
			PHASES[1].fn(inst)

			inst:AddComponent("dpstracker")
			inst.components.dpstracker:SetOnDpsUpdateFn(OnDpsUpdate)

			inst:AddComponent("planarentity")
			inst:AddComponent("planardamage")
			inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_PLANAR_DAMAGE)

			inst:AddComponent("explosiveresist")

			inst:AddComponent("epicscare")
			inst.components.epicscare:SetRange(18) --missiles target range

			inst:AddComponent("timer")
			inst:AddComponent("grouptargeter")
			inst:AddComponent("commander")

			inst:ListenForEvent("attacked", OnAttacked)
			inst:ListenForEvent("newcombattarget", OnNewTarget)
			inst:ListenForEvent("droppedtarget", OnDroppedTarget)
			inst:ListenForEvent("soldierschanged", OnSoldiersChanged)

			--inst.threatlevel = 1
			SetThreatLevel(inst, 1)

			inst._engagetask = nil
			inst.engaged = false
		end
	elseif inst.components.combat then
		if inst._engagetask then
			inst._engagetask:Cancel()
			inst._engagetask = nil
		end
		inst.engaged = nil

		if inst._threattask then
			inst._threattask:Cancel()
			inst._threattask = nil
		end
		inst.threatlevel = nil

		SetFlyersActive(inst, false)
		SetRollersActive(inst, false)
		inst.components.commander:PushEventToAllSoldiers("deactivate")

		inst:RemoveEventCallback("attacked", OnAttacked)
		inst:RemoveEventCallback("newcombattarget", OnNewTarget)
		inst:RemoveEventCallback("droppedtarget", OnDroppedTarget)
		inst:RemoveEventCallback("soldierschanged", OnSoldiersChanged)

		inst:RemoveComponent("dpstracker")
		inst:RemoveComponent("healthtrigger")
		inst:RemoveComponent("health")
		inst:RemoveComponent("combat")
		inst:RemoveComponent("planarentity")
		inst:RemoveComponent("planardamage")
		inst:RemoveComponent("explosiveresist")
		inst:RemoveComponent("timer")
		inst:RemoveComponent("grouptargeter")
		inst:RemoveComponent("commander")
	end
end

local function SetBrainEnabled(inst, enabled)
	inst:SetBrain(enabled and brain or nil)
end

local function ConfigureOff(inst)
	CancelReset(inst)
	inst.active = false
	inst.hostile = false
	SetActiveTags(inst, false)
	SetLocomotorEnabled(inst, false)
	SetCombatEnabled(inst, false)
	SetBrainEnabled(inst, false)
	if inst.shattered then
		inst.AnimState:Show("rb_wires")
	else
		inst.AnimState:Hide("rb_wires")
	end
end

local function ConfigureFriendly(inst)
	inst.active = true
	inst.hostile = false
	SetActiveTags(inst, true, false)
	SetLocomotorEnabled(inst, true)
	SetCombatEnabled(inst, false)
	SetBrainEnabled(inst, true)
	inst:SocketCage()
	if inst.sg.currentstate.name == "losecontrol" then
		inst.AnimState:Show("rb_wires")
	else
		inst.AnimState:Hide("rb_wires")
	end
end

local function ConfigureHostile(inst)
	inst.active = true
	inst.hostile = true
	SetActiveTags(inst, true, true)
	SetLocomotorEnabled(inst, true)
	SetCombatEnabled(inst, true)
	SetBrainEnabled(inst, true)
	inst:BreakGlass()
end

local function SocketCage(inst)
	if not inst.socketed then
		inst.socketed = true
		if inst.shattered then
			inst.AnimState:OverrideSymbol("glass1", "wagboss_robot", "glass3")
			if not inst.showcrown:value() then
				inst.showcrown:set(true)
				if not TheNet:IsDedicated() then
					OnShowCrownDirty(inst)
				end
			end
		else
			inst.AnimState:OverrideSymbol("glass1", "wagboss_robot", "glass2")
		end
		inst.AnimState:SetSymbolBloom("glass1")
		inst.AnimState:SetSymbolLightOverride("glass1", 0.25)
		inst.AnimState:SetSymbolLightOverride("rb_head_parts", 0.08)
		if not POPULATING then
			inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/gestalt_placed_activate")
		end
		inst:PushEventImmediate("reveal")
	end
end

local function IsSocketed(inst)
    return inst.socketed
end

local function BreakGlass(inst)
	if not inst.shattered then
		inst.shattered = true
		if inst.socketed then
			inst.AnimState:OverrideSymbol("glass1", "wagboss_robot", "glass3")
			if not inst.showcrown:value() then
				inst.showcrown:set(true)
				if not TheNet:IsDedicated() then
					OnShowCrownDirty(inst)
				end
			end
		end
		inst.AnimState:Show("rb_wires")
	end
end

local function OnSave(inst, data)
	if inst.hostile then
		data.hostile = true
		data.threat = inst.threatlevel > 1 and inst.threatlevel or nil
	elseif inst.active then
		data.active = true
	end
	data.socketed = inst.socketed or nil
	data.shattered = inst.shattered or nil
	data.reset = inst.shouldreset or nil
end

local function OnPreLoad(inst, data, ents)
	if data then
		if data.hostile then
			inst.sg:GoToState("idle")
			if data.threat then
				SetThreatLevel(inst, data.threat)
			end
			inst:SetMusicLevel(1)
		elseif data.active then
			inst:PushEventImmediate("activate")
		end
		if data.shattered then
			BreakGlass(inst)
		end
        if data.socketed then
			SocketCage(inst)
        end
	end
end

local function OnLoad(inst, data, ents)
	if inst.components.health then
		local healthpct = inst.components.health:GetPercent()
		for i = #PHASES, 2, -1 do
			local v = PHASES[i]
			if healthpct <= v.hp then
				v.fn(inst)
				break
			end
		end
	end
	if inst.components.timer then
		ClearCombatTimers(inst)
	end
	if data and data.reset and inst.active then
		inst.shouldreset = true
		if inst:IsAsleep() and inst._resettask == nil then
			inst._resettask = inst:DoTaskInTime(6, DoOffScreenReset)
		end
	end
end

local function OnColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.followfx) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
	if inst._backfx then
		inst._backfx.AnimState:SetAddColour(r, g, b, a)
	end
end

--------------------------------------------------------------------------

local OBSTACLE_RADIUS = 3.5 -- NOTES(JBK): Keep in sync with the constructionkit! Search string [WBRPR]
local STANDING_RADIUS = 0.25

local function ForEachInPathfinding(x, z, cb)
	--all walls that would fit inside our radius
	local r = math.floor(OBSTACLE_RADIUS)
	local rangesq = OBSTACLE_RADIUS * OBSTACLE_RADIUS
	for dx = -r, r - 1 do
		local maxdx = dx < 0 and -dx or dx + 1
		for dz = -r, r - 1 do
			local maxdz = dz < 0 and -dz or dz + 1
			if maxdx * maxdx + maxdz * maxdz < rangesq then
				cb(x + dx + 0.5, z + dz + 0.5)
			end
		end
	end
end

local function DoAddWall(x, z)
	TheWorld.Pathfinder:AddWall(x, 0, z)
end

local function DoRemoveWall(x, z)
	TheWorld.Pathfinder:RemoveWall(x, 0, z)
end

local function RegisterPathfinding(inst)
	assert(inst._pfpos == nil)
	local x, y, z = inst.Transform:GetWorldPosition()
	ForEachInPathfinding(x, z, DoAddWall)
	inst._pfpos = Vector3(x, 0, z)	
end

local function UnregisterPathfinding(inst)
	if inst._pfpos then
		local x, y, z = inst._pfpos:Get()
		ForEachInPathfinding(x, z, DoRemoveWall)
		inst._pfpos = nil
	end
end

local function OnIsObstacleDirty(inst)
	if inst.isobstacle:value() then
		inst:SetPhysicsRadiusOverride(OBSTACLE_RADIUS)
		inst:SetDeploySmartRadius(OBSTACLE_RADIUS)
		if inst._pftask == nil then
			--delayed to make sure our position is set
			inst._pftask = inst:DoStaticTaskInTime(0, RegisterPathfinding)
		end
	else
		inst:SetPhysicsRadiusOverride(STANDING_RADIUS)
		inst:SetDeploySmartRadius(nil)
		if inst._pftask then
			inst._pftask:Cancel()
			inst._pftask = nil
		end
		UnregisterPathfinding(inst)
	end
end

local function MakeObstacle(inst, isobstacle)
	if isobstacle then
		if not inst.isobstacle:value() then
			inst.isobstacle:set(true)
			inst:AddTag("blocker")
			ChangeToObstaclePhysics(inst, OBSTACLE_RADIUS)
			OnIsObstacleDirty(inst)
		end
	elseif inst.isobstacle:value() then
		inst.isobstacle:set(false)
		inst:RemoveTag("blocker")
		ChangeToGiantCharacterPhysics(inst, 1000, STANDING_RADIUS)
		if next(inst._nocollide) then
			inst.Physics:SetCollisionMask(COLLISION.WORLD)
		else
			inst.Physics:ClearCollidesWith(COLLISION.CHARACTERS)
		end
		OnIsObstacleDirty(inst)
	end
end

local function SetTempNoCollide(inst, nocollide, reason)
	if nocollide then
		if next(inst._nocollide) == nil and not inst.isobstacle:value() then
			inst.Physics:SetCollisionMask(COLLISION.WORLD)
		end
		inst._nocollide[reason] = true
	elseif inst._nocollide[reason] then
		inst._nocollide[reason] = nil
		if next(inst._nocollide) == nil and not inst.isobstacle:value() then
			inst.Physics:SetCollisionMask(COLLISION.WORLD, COLLISION.OBSTACLES, COLLISION.GIANTS)
		end
	end
end

local OnRemoveEntity = UnregisterPathfinding

--------------------------------------------------------------------------

local function PushMusic(inst)
	if ThePlayer == nil then
		inst._playingmusic = false
	else
		local map = TheWorld.Map
		local x, _, z = inst.Transform:GetWorldPosition()
		if map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z) then
			if map:IsPointInWagPunkArena(ThePlayer.Transform:GetWorldPosition()) then
				inst._playingmusic = true
				ThePlayer:PushEvent("triggeredevent", { name = "wagboss", level = inst.music:value() })
			else
				inst._playingmusic = false
			end
		else
			local dsq = ThePlayer:GetDistanceSqToPoint(x, 0, z)
			local range = inst._playingmusic and 30 or 20
			if dsq < range * range then
				inst._playingmusic = true
				ThePlayer:PushEvent("triggeredevent", { name = "wagboss", level = inst.music:value() })
			elseif inst._playingmusic and dsq >= 40 * 40 then
				inst._playingmusic = false
			end
		end
	end
end

local function OnMusicDirty(inst)
	if inst.music:value() > 0 then
		if inst._musictask == nil then
			inst._musictask = inst:DoPeriodicTask(1, PushMusic)
			PushMusic(inst)
		end
	elseif inst._musictask then
		inst._musictask:Cancel()
		inst._musictask = nil
		inst._playingmusic = false
	end
end

local function SetMusicLevel(inst, level)
	if level ~= inst.music:value() then
		inst.music:set(level)

		--Dedicated server does not need to trigger music
		if not TheNet:IsDedicated() then
			OnMusicDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function OnCameraFocusDirty(inst)
	if inst.camerafocus:value() then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 6, 22, 4)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function EnableCameraFocus(inst, enable)
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function DisplayNameFn(inst)
	return (inst.AnimState:IsCurrentAnimation("concealed_idle") and STRINGS.NAMES.WAGBOSS_ROBOT_SECRET)
		or (inst:HasTag("hostile") and STRINGS.NAMES.WAGBOSS_ROBOT_POSSESSED)
		or nil
end

local function DescriptionFn(inst, viewer) --inpsect string (server)
	inst.components.inspectable:SetNameOverride(
		(inst.AnimState:IsCurrentAnimation("concealed_idle") and "wagboss_robot_secret") or
		(inst.hostile and "wagboss_robot_possessed") or
		nil
	)
end

local function AbleToAcceptTest(inst, item)
    if inst.socketed then
        return false
    end

    return item.prefab == "gestalt_cage_filled3"
end

local function OnGetItemFromPlayer(inst, giver, item)
    inst:SocketCage()
    inst:RemoveTrader()
    item:Remove()
    TheWorld:PushEvent("ms_wagpunk_constructrobot")
end

local function AddTrader(inst)
    if inst.components.trader then
        return
    end

    local trader = inst:AddComponent("trader")
    trader:SetAbleToAcceptTest(AbleToAcceptTest)
    trader.onaccept = OnGetItemFromPlayer
    trader.deleteitemonaccept = false
end

local function RemoveTrader(inst)
    if not inst.components.trader then
        return
    end

    inst:RemoveComponent("trader")
end

local SCRAPBOOK_SYMBOLCOLOURS = {
	{"lb_glow", 1, 1, 1, 0.375},
	--{"lb_flame_loop", 1, 1, 1, 0.75},
}
local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddDynamicShadow()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.DynamicShadow:SetSize(4.8, 2.8)

	--inst.Transform:SetFourFaced() --only use facing model during walk states

	inst.AnimState:SetBuild("wagboss_robot")
	inst.AnimState:SetBank("wagboss_robot")
	inst.AnimState:PlayAnimation("concealed_idle", true)
	inst.AnimState:SetFinalOffset(-1)
	inst.AnimState:SetSymbolBloom("fx_white")
	inst.AnimState:SetSymbolLightOverride("fx_white", 0.3)

	MakeObstaclePhysics(inst, OBSTACLE_RADIUS)

	inst:AddTag("mech")
	inst:AddTag("electricdamageimmune")
	inst:AddTag("soulless")
	inst:AddTag("wagboss")
	inst:AddTag("epic")
	inst:AddTag("noepicmusic")

	--Sneak these into pristine state for optimization
	inst:AddTag("__health")
	inst:AddTag("__combat")

	inst.showstompfx = net_bool(inst.GUID, "wagboss_robot.showstompfx", "showstompfxdirty")
	inst.showbackfx = net_bool(inst.GUID, "wagboss_robot.showbackfx", "showbackfxdirty")
	inst.music = net_tinybyte(inst.GUID, "wagboss_robot.music", "musicdirty")
	inst.camerafocus = net_bool(inst.GUID, "wagboss_robot.camerafocus", "camerafocusdirty")
	inst.isobstacle = net_bool(inst.GUID, "wagboss_robot.isobstacle", "isobstacledirty")
	inst.showcrown = net_bool(inst.GUID, "wagboss_robot.showcrown", "showcrowndirty")
	inst.isobstacle:set(true)
	OnIsObstacleDirty(inst)

	inst:AddComponent("colouraddersync")
	inst:AddComponent("updatelooper")

	--Dedicated server does not need to trigger music
	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.followfx = {}
		inst.highlightchildren = {}

		AddFollowFx(inst, "gear_large_loop_front", "rb_gear_front_follow")
		AddFollowFx(inst, "gear_large_loop_edge", "rb_gear_side_follow")
		AddFollowFx(inst, "gear_small_loop_front", "rb_gear2_front_follow")

		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.OnRemoveEntity = OnRemoveEntity
	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("isobstacledirty", OnIsObstacleDirty)
		inst:ListenForEvent("showstompfxdirty", OnShowStompFx_Client)
		inst:ListenForEvent("showbackfxdirty", OnShowBackFx_Client)
		inst:ListenForEvent("showcrowndirty", OnShowCrownDirty)
		inst:ListenForEvent("musicdirty", OnMusicDirty)
		inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)

		return inst
	end

	inst.scrapbook_overridedata = {
		{ "glass1", "wagboss_robot", "glass2" },

		{ "lb_flame_loop", "wagboss_lunar", "lb_flame_loop" },
		{ "lb_glow", "wagboss_lunar", "lb_glow" },
		--{ "crown_bk_follow", "wagboss_lunar", "crown_bk_comp" },
	}
	inst.scrapbook_symbolcolours = SCRAPBOOK_SYMBOLCOLOURS
	inst.scrapbook_anim = "scrapbook"
	--inst.scrapbook_overridebuild = "wagboss_lunar"

	--Remove these tags so that they can be added properly when replicating components below
	inst:RemoveTag("__health")
	inst:RemoveTag("__combat")

	inst:PrereplicateComponent("health")
	inst:PrereplicateComponent("combat")

	inst:AddComponent("inspectable")
	inst.components.inspectable.getspecialdescription = DescriptionFn

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("wagboss_robot")
	inst.components.lootdropper.min_speed = 4
	inst.components.lootdropper.max_speed = 6
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 2

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:ListenForEvent("doreset", DoReset)
	inst:ListenForEvent("activate", CancelReset)

	inst._temptbl1 = {}
	inst._temptbl2 = {}
	inst._nocollide = {}

	inst.active = false
	inst.hostile = false
    inst.socketed = false
    inst.shattered = false

	inst.HackDrones = HackDrones
	inst.ReleaseDrones = ReleaseDrones
	inst.StartStompFx = StartStompFx
	inst.StopStompFx = StopStompFx
	inst.StartBackFx = StartBackFx
	inst.StopBackFx = StopBackFx
	inst.ConfigureOff = ConfigureOff
	inst.ConfigureFriendly = ConfigureFriendly
	inst.ConfigureHostile = ConfigureHostile
    inst.SocketCage = SocketCage
    inst.IsSocketed = IsSocketed
	inst.BreakGlass = BreakGlass
	inst.MakeObstacle = MakeObstacle
	inst.SetTempNoCollide = SetTempNoCollide
	inst.SkipBarragePhase = SkipBarragePhase
	inst.SetMusicLevel = SetMusicLevel
	inst.EnableCameraFocus = EnableCameraFocus
	inst.AddAlterSymbols = AddAlterSymbols
	inst.ClearAlterSymbols = ClearAlterSymbols
    inst.AddTrader = AddTrader
    inst.RemoveTrader = RemoveTrader

	inst:SetStateGraph("SGwagboss_robot")

	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake
	inst.OnSave = OnSave
	inst.OnPreLoad = OnPreLoad
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("wagboss_robot", fn, assets, prefabs)
