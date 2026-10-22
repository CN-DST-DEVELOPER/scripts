local assets =
{
	Asset("ANIM", "anim/charlie_boss_basic.zip"),
	Asset("ANIM", "anim/charlie_boss_actions.zip"),
	Asset("ANIM", "anim/charlie_boss_transform_v2.zip"),
	Asset("ANIM", "anim/charlie_basic.zip"),
	Asset("ANIM", "anim/charlie_transform.zip"),
}

local prefabs =
{
	"charlie_boss_minion1",
	"charlie_boss_minion2",
	"charlie_boss_aoe_flame_fx",
	"charlie_boss_projectile",
	"charlie_boss_reflect_projectile_fx",
	"charlie_boss_vines",
	"shrouden",

	--loot
	"temp_beta_msg", --#TEMP_BETA
	"horrorfuel",
	"nightmarefuel",
	"chesspiece_charlie_boss_sketch",
}

SetSharedLootTable("charlie_boss",
{
	{ "horrorfuel",			1.00 },
	{ "horrorfuel",			1.00 },
	{ "horrorfuel",			1.00 },
	{ "horrorfuel",			1.00 },
	{ "horrorfuel",			1.00 },
	{ "horrorfuel",			0.75 },
	{ "nightmarefuel",		1.00 },
	{ "nightmarefuel",		1.00 },
	{ "nightmarefuel",		0.75 },
	{'chesspiece_charlie_boss_sketch', 1.0 },
})

local brain = require("brains/charlie_bossbrain")
local AOEUtil = require("aoeutil")

local AOE_TAGSET
local function GetAOEAttackTagSet(inst)
	--Keep in sync with shrouden.lua
	if AOE_TAGSET == nil then
		AOE_TAGSET = AOEUtil.AttackTagSet()
		AOE_TAGSET:AppendCantTags("shadowthrall", "shadow", "shadowcreature", "shadowchesspiece", "shadowboss")
		AOE_TAGSET:Register()
	end
	return AOE_TAGSET
end

local function IsPointInArena(x, y, z)
	return TheWorld.Map:IsPointInCharlieBossArena(x, y, z)
end

local function IsEntInArena(ent)
	return TheWorld.Map:IsPointInCharlieBossArena(ent.Transform:GetWorldPosition())
end

local function IsInArena(inst)
	if inst._inarena == nil then
		inst._inarena = IsEntInArena(inst)
		inst.components.epicscare:SetRange(inst._inarena and 30 or TUNING.CHARLIE_BOSS_AGGRO_DIST)
	end
	return inst._inarena
end

local function teleport_override_fn(inst)
	return inst:IsInArena() and inst:GetPosition() or nil
end

--------------------------------------------------------------------------

local function UpdatePlayerTargets(inst)
	assert(next(inst._temptbl1) == nil and next(inst._temptbl2) == nil)
	local toadd = inst._temptbl1
	local toremove = inst._temptbl2
	local x, _, z = inst.Transform:GetWorldPosition()

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		toremove[k] = true
	end

	if inst:IsInArena() then
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() and IsEntInArena(v) then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		for _, v in ipairs(FindPlayersInRange(x, 0, z, TUNING.CHARLIE_BOSS_DEAGGRO_DIST, true)) do
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
	if inst.components.health:IsDead() or inst.sg:HasStateTag("temp_invincible") then
		return
	end

	UpdatePlayerTargets(inst)

	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	local inrange
	if target then
		local range = TUNING.CHARLIE_BOSS_ATTACK_RANGE + target:GetPhysicsRadius(0)
		local x1, _, z1 = target.Transform:GetWorldPosition()
		inrange = math2d.DistSq(x1, z1, x, z) < range * range and inst:IsInArena() == IsPointInArena(x1, 0, z1)

		if target.isplayer then
			--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
			local newplayer = inst.components.grouptargeter:TryGetNewTarget()
			if newplayer then
				range = inrange and TUNING.CHARLIE_BOSS_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.CHARLIE_BOSS_KEEP_AGGRO_DIST
				if newplayer:GetDistanceSqToPoint(x, 0, z) < range * range then
					return newplayer, true
				end
			end
			return
		end
	end

	--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
	assert(next(inst._temptbl1) == nil)
	local nearplayers = inst._temptbl1
	if not inrange and inst._disengagetask then
		--V2C: when pending reset (was in combat but lost aggro), retarget the entire arena until successfully reset
		for k in pairs(inst.components.grouptargeter:GetTargets()) do
			table.insert(nearplayers, k)
		end
	else
		for k in pairs(inst.components.grouptargeter:GetTargets()) do
			local range = inrange and TUNING.CHARLIE_BOSS_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.CHARLIE_BOSS_AGGRO_DIST
			if k:GetDistanceSqToPoint(x, 0, z) < range * range then
				table.insert(nearplayers, k)
			end
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
	elseif inst:IsInArena() then
		return IsEntInArena(target)
	end
	return inst:IsNear(target, TUNING.CHARLIE_BOSS_DEAGGRO_DIST)
end

local function TryAggro(inst, attacker)
	if inst.components.health:IsDead() or inst.sg:HasStateTag("temp_invincible") then
		return false
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	if target and target.isplayer then
		local range = TUNING.CHARLIE_BOSS_ATTACK_RANGE + target:GetPhysicsRadius(0)
		if target:GetDistanceSqToPoint(x, y, z) < range * range then
			return false
		end
	end
	inst.components.combat:SetTarget(attacker)
	return true
end

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() then
		TryAggro(inst, data.attacker)
	end
end

local function SpawnReflectProjectileAtXYZ(inst, x, y, z, rot, targetorpos)
	local fx = SpawnPrefab("charlie_boss_reflect_projectile_fx")
	fx.Transform:SetPosition(x, y, z)
	fx.Transform:SetRotation(rot)
	fx:ListenForEvent("resetboss", function() inst:Remove() end, inst)
	fx:ListenForEvent("animover", function(fx)
		fx:Remove()

		local proj = SpawnPrefab("charlie_boss_projectile")
		if not (Vector3.is_instance(targetorpos) or (targetorpos and targetorpos:IsValid())) then
			local theta = rot * DEGREES
			local len = 6 + math.random() * 2
			targetorpos = Vector3(x + len * math.cos(theta), 0, z - len * math.sin(theta))
		end
		proj:Launch(inst, targetorpos, x, y, z, rot - 60 + math.random() * 120)
	end)
end

local REFLECT_RADIUS = 2

local function TryGenericDeflectable(inst, ent)
	if ent and ent.components.deflectable and ent:IsValid() then
		local attacker = ent.components.deflectable:GetOwner()
		local x1, y1, z1 = ent.Transform:GetWorldPosition()

		ent.components.deflectable:Deflect(inst)

		local x, y, z = inst.Transform:GetWorldPosition()
		local rot, theta
		if x ~= x1 or z ~= z1 then
			theta = math.atan2(z - z1, x1 - x)
			rot = theta * RADIANS
		elseif attacker and attacker:IsValid() then
			rot = attacker:GetAngleToPoint(x, y, z)
			theta = rot * DEGREES
		else
			rot = inst.Transform:GetRotation()
			theta = rot * DEGREES
		end
		x1 = x + REFLECT_RADIUS * math.cos(theta)
		z1 = z - REFLECT_RADIUS * math.sin(theta)
		y1 = math.max(1, y1)
		SpawnReflectProjectileAtXYZ(inst, x1, y1, z1, rot, attacker)
		return true
	end
	return false
end

local function OnBlocked(inst, data)
	if data then
		if data.attacker and data.attacker:IsValid() then
			TryAggro(inst, data.attacker)
		end

		if IsRangedWeapon(data.weapon) then
			local function onweapononattack(weaponinst, data)
				inst:RemoveEventCallback("weapononattack", onweapononattack, weaponinst)

				if data and data.projectile and data.projectile:IsValid() then
					local x1, y1, z1 = data.projectile.Transform:GetWorldPosition()
					if y1 < 0.2 then
						y1 = 1.25
					else
						if data.projectile.prefab == "boomerang" then
							y1 = y1 + 1.25
						end
						y1 = math.max(1, y1)
					end
					local rot = data.projectile.Transform:GetRotation() + 180

					if data.projectile.components.projectile then
						data.projectile.components.projectile:Deflect(inst)
					end

					local x, y, z = inst.Transform:GetWorldPosition()
					local theta = rot * DEGREES
					x1 = x + REFLECT_RADIUS * math.cos(theta)
					z1 = z - REFLECT_RADIUS * math.sin(theta)
					SpawnReflectProjectileAtXYZ(inst, x1, y1, z1, rot, data.attacker)
				else
					TryGenericDeflectable(inst, weaponinst)
				end
			end
			inst:ListenForEvent("weapononattack", onweapononattack, data.weapon)
		else
			TryGenericDeflectable(inst, data.attacker)
		end
	end
end

local REFLECT_COMPLEX_PROJECTILE_TAGS = { "complexprojectile", "activeprojectile" }
local REFLECT_COMPLEX_PROJECTILE_NOTAGS = { "INLIMBO" }
local REFLECT_RADIUS_SQ = REFLECT_RADIUS * REFLECT_RADIUS
local REFLECT_HEIGHT = 5
local REFLECT_COMPLEX_PROJECTILE_SEARCH_RADIUS = math.sqrt(REFLECT_RADIUS_SQ + REFLECT_HEIGHT * REFLECT_HEIGHT)
local _reflect_ignores = {}
local function OnUpdateReflectComplexProjectiles(inst, dt)
	for k in pairs(_reflect_ignores) do
		if not (k:IsValid() and k:HasTag("activeprojectile")) then
			_reflect_ignores[k] = nil
		end
	end

	local x, _, z = inst.Transform:GetWorldPosition()
	for _, v in ipairs(TheSim:FindEntities(x, 0, z, REFLECT_COMPLEX_PROJECTILE_SEARCH_RADIUS, REFLECT_COMPLEX_PROJECTILE_TAGS, REFLECT_COMPLEX_PROJECTILE_NOTAGS)) do
		if not _reflect_ignores[v] then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if y1 < REFLECT_HEIGHT and math2d.DistSq(x, z, x1, z1) < REFLECT_RADIUS_SQ then
				local attacker = v.components.complexprojectile.attacker
				if attacker and attacker:IsValid() then
					TryAggro(inst, attacker)
				end

				local rot = v.Transform:GetRotation() + 180

				v.components.complexprojectile:Deflect(inst)

				if v:IsValid() and v:HasTag("activeprojectile") then
					_reflect_ignores[v] = true
				end

				local theta = rot * DEGREES
				x1 = x + REFLECT_RADIUS * math.cos(theta)
				z1 = z - REFLECT_RADIUS * math.sin(theta)
				SpawnReflectProjectileAtXYZ(inst, x1, y1, z1, rot, attacker)
			end
		end
	end
end

local function SetReflectingProjectiles(inst, enable)
	if enable then
		if not inst.isreflectingprojectiles then
			inst.isreflectingprojectiles = true
			inst.components.damagetyperesist:AddResist("projectile", inst, 0, "rangedcounter")
			inst.components.damagetyperesist:AddResist("rangedweapon", inst, 0, "rangedcounter")
			inst.components.damagetyperesist:AddResist("deflectable", inst, 0, "rangedcounter")
			inst.components.updatelooper:AddOnUpdateFn(OnUpdateReflectComplexProjectiles)
			inst:ListenForEvent("blocked", OnBlocked)
		end
	elseif inst.isreflectingprojectiles then
		inst.isreflectingprojectiles = false
		inst.components.damagetyperesist:RemoveResist("projectile", inst, "rangedcounter")
		inst.components.damagetyperesist:RemoveResist("rangedweapon", inst, "rangedcounter")
		inst.components.damagetyperesist:RemoveResist("deflectable", inst, "rangedcounter")
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateReflectComplexProjectiles)
		inst:RemoveEventCallback("blocked", OnBlocked)
	end
end

local function WantsToReflectProjectiles(inst) --called from sg
	return inst.canreflectprojectiles and (inst.components.combat:HasTarget() or inst._disengagetask ~= nil)
end

local function ToggleReflectingProjectiles(inst) --called from sg
	if inst.components.combat:HasTarget() or inst._disengagetask then
		SetReflectingProjectiles(inst, inst.canreflectprojectiles)
	end
end

local function SwitchMode(inst)
	inst.canvinecounter = not inst.canvinecounter
	inst.canreflectprojectiles = not inst.canreflectprojectiles
	inst.sg.mem.forcetaunt = true
	inst.components.combat.battlecryenabled = true
	inst.components.combat:SetAttackPeriod(inst.canvinecounter and TUNING.CHARLIE_BOSS_ATTACK_PERIOD or TUNING.CHARLIE_BOSS_ATTACK_PERIOD2)
end

local function CalcMinModeTime()
	return GetRandomMinMax(unpack(TUNING.CHARLIE_BOSS_MODE_SWITCH_MINTIME))
end

local function OnModeTask(inst)
	inst._modetask = nil
	local hp = inst.components.health:GetPercent()
	if hp + TUNING.CHARLIE_BOSS_MODE_SWITCH_HP < inst._modehp then
		SwitchMode(inst)
		inst._modehp = hp
		inst._modetask = inst:DoTaskInTime(CalcMinModeTime(), OnModeTask)
	end
end

local function OnHealthDelta(inst, data)
	if inst._modetask == nil and data and data.newpercent and data.newpercent + TUNING.CHARLIE_BOSS_MODE_SWITCH_HP < inst._modehp then
		SwitchMode(inst)
		inst._modehp = data.newpercent
		inst._modetask = inst:DoTaskInTime(CalcMinModeTime(), OnModeTask)
	end
end

local function SetModeSwitching(inst, enable)
	if enable then
		if not inst.ismodeswitching then
			inst.ismodeswitching = true
			inst._modetask = inst:DoTaskInTime(CalcMinModeTime(), OnModeTask)
			inst._modehp = inst.components.health:GetPercent()
			inst:ListenForEvent("healthdelta", OnHealthDelta)
		end
	elseif inst.ismodeswitching then
		inst.ismodeswitching = false
		if inst._modetask then
			inst._modetask:Cancel()
			inst._modetask = nil
		end
		inst._modehp = nil
		inst:RemoveEventCallback("healthdelta", OnHealthDelta)
	end
end

local function SetShadowHandsEnabled(inst, enable)
	if enable then
		if not inst.isshadowhandsenabled and inst:IsInArena() then
			inst.isshadowhandsenabled = true
			inst:PushEvent("ms_charliearena_shadowhands_setenabled", true)
		end
	elseif inst.isshadowhandsenabled then
		inst.isshadowhandsenabled = false
		inst:PushEvent("ms_charliearena_shadowhands_setenabled", false)
	end
end

local function SetRunnerSpawnsEnabled(inst, enable)
	if enable then
		if not inst.isrunnerspawnsenabled and inst:IsInArena() then
			inst.isrunnerspawnsenabled = true
			inst:PushEvent("ms_charliearena_shadowrunners_setenabled", true)
		end
	elseif inst.isrunnerspawnsenabled then
		inst.isrunnerspawnsenabled = false
		inst:PushEvent("ms_charliearena_shadowrunners_setenabled", false)
	end
end

local PHASES --forward declare

local function TryReset(inst, force)
	if inst.sg.currentstate.name == "spawn" or
		inst.sg.currentstate.name == "spawn_loop" or
		not inst:IsInArena()
	then
		inst._resettask:Cancel()
		inst._resettask = nil
		return
	end

	if not force then
		local _, numplayers = GetPlayersInfoForVirtualRoomSetName(VIRTUALROOMSETS.ATRIUM)
		if numplayers > 0 then
			return --reschedule (keep periodic task)
		end
	end

	inst._resettask:Cancel()
	inst._resettask = nil

	local home = inst.components.knownlocations:GetLocation("spawnpoint")
	if home then
		inst.Physics:Teleport(home:Get())
	else
		local x, z = TheWorld.Map:GetCharlieBossArenaCenterXZ()
		if x then
			inst.Physics:Teleport(x, 0, z)
		end
	end
	inst.sg:GoToState("spawn_loop")
	inst.components.health:SetPercent(1)
	PHASES[1].fn(inst)

	inst:PushEvent("resetboss")
end

local function OnNewCombatTarget(inst, data)
	if inst._disengagetask then
		inst._disengagetask:Cancel()
		inst._disengagetask = nil
	end
	if inst._resettask then
		inst._resettask:Cancel()
		inst._resettask = nil
	end
	SetModeSwitching(inst, inst.canmodeswitch)
	SetShadowHandsEnabled(inst, inst.canshadowhands)
	SetRunnerSpawnsEnabled(inst, inst.canspawnrunners)

	if not inst.sg:HasStateTag("spawning") then
		inst:SetMusicLevel(3)
	end

	--#TEMP_BETA
	--[[if inst.sg.mem.killstarttime == nil and inst:IsInArena() then
		inst.sg.mem.killstarttime = GetTime()
	end]]
end

local function Disengage(inst)
	inst._disengagetask = nil
	SetModeSwitching(inst, false)
	SetReflectingProjectiles(inst, false)
	SetShadowHandsEnabled(inst, false)
	SetRunnerSpawnsEnabled(inst, false)
	inst.components.combat.battlecryenabled = true
	inst.sg.mem.forcetaunt = nil

	if inst._resettask == nil then
		inst._resettask = inst:DoPeriodicTask(3, TryReset, 0)
	end

	if not inst.sg:HasStateTag("spawning") then
		inst:SetMusicLevel(inst.components.health:IsDead() and 4 or 0)
	end

	--#TEMP_BETA
	--[[if inst.sg.mem.killstarttime and not inst.components.health:IsHurt() then
		inst.sg.mem.killstarttime = nil
	end]]
end

local function OnDroppedTarget(inst)
	if inst._disengagetask == nil then
		inst._disengagetask = inst:DoTaskInTime(10, Disengage)
	end
end

local function OnDeath(inst)
	inst.components.combat:DropTarget()
	if inst._disengagetask then
		inst._disengagetask:Cancel()
		Disengage(inst)
	end
	if inst._resettask then
		inst._resettask:Cancel()
		inst._resettask = nil
	end

	if not inst.sg:HasStateTag("spawning") then
		inst:SetMusicLevel(4)
	end
end

PHASES = --forward declared
{
	{
		hp = 1,
		fn = function(inst)
			inst.canmodeswitch = false
			inst.canshadowhands = false
			inst.canvinecounter = false
			inst.canreflectprojectiles = false
			inst.canspawnrunners = false
			SetModeSwitching(inst, false)
			SetShadowHandsEnabled(inst, false)
			SetRunnerSpawnsEnabled(inst, false)
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
			inst.components.combat:SetAttackPeriod(TUNING.CHARLIE_BOSS_ATTACK_PERIOD2)
		end,
	},
	{
		hp = 0.95,
		fn = function(inst)
			inst.canmodeswitch = false
			inst.canshadowhands = true
			inst.canvinecounter = true
			inst.canreflectprojectiles = false
			inst.canspawnrunners = false
			SetModeSwitching(inst, false)
			SetShadowHandsEnabled(inst, inst.components.combat:HasTarget())
			SetRunnerSpawnsEnabled(inst, false)
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
			inst.components.combat:SetAttackPeriod(TUNING.CHARLIE_BOSS_ATTACK_PERIOD)
		end,
	},
	{
		hp = 0.85,
		fn = function(inst)
			inst.canmodeswitch = true
			inst.canshadowhands = true
			if not POPULATING or math.random() < 0.5 then
				inst.canvinecounter = false
				inst.canreflectprojectiles = true
			else
				inst.canvinecounter = true
				inst.canreflectprojectiles = false
			end
			inst.canspawnrunners = false
			SetModeSwitching(inst, inst.components.combat:HasTarget())
			SetShadowHandsEnabled(inst, inst.components.combat:HasTarget())
			SetRunnerSpawnsEnabled(inst, false)
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
			inst.components.combat:SetAttackPeriod(inst.canvinecounter and TUNING.CHARLIE_BOSS_ATTACK_PERIOD or TUNING.CHARLIE_BOSS_ATTACK_PERIOD2)
		end,
	},
}

local RUNNER_HP_THRESHOLDS = { 0.2, 0.25, 0.3, 0.35 }

local function RunnerPhaseFn(inst)
	inst.canshadowhands = true
	if not inst.canmodeswitch then
		inst.canmodeswitch = true
		if math.random() < 0.5 then
			inst.canvinecounter = false
			inst.canreflectprojectiles = true
		else
			inst.canvinecounter = true
			inst.canreflectprojectiles = false
		end
		SetModeSwitching(inst, inst.components.combat:HasTarget())
		inst.sg.mem.forcetaunt = true
	end
	SetShadowHandsEnabled(inst, inst.components.combat:HasTarget())
	local n = math.clamp(inst.components.grouptargeter:GetNumTargets(), 1, #RUNNER_HP_THRESHOLDS)
	if inst.components.health:GetPercent() <= RUNNER_HP_THRESHOLDS[n] then
		inst.canspawnrunners = true
		SetRunnerSpawnsEnabled(inst, inst.components.combat:HasTarget())
	else
		inst.canspawnrunners = false
		SetRunnerSpawnsEnabled(inst, false)
	end
	inst.components.combat.battlecryenabled = true
	inst.components.combat:SetAttackPeriod(inst.canvinecounter and TUNING.CHARLIE_BOSS_ATTACK_PERIOD or TUNING.CHARLIE_BOSS_ATTACK_PERIOD2)
end

for i = #RUNNER_HP_THRESHOLDS, 1, -1 do
	table.insert(PHASES, { hp = RUNNER_HP_THRESHOLDS[i], fn = RunnerPhaseFn })
end

local function OnSave(inst, data)
	--[[if inst.sg.mem.killstarttime then
		data.killtime = math.floor(GetTime() - inst.sg.mem.killstarttime)
	end]]
	data.looted = inst.looted
end

local function OnLoad(inst, data)--, ents)
	inst.looted = data and data.looted

	local healthpct = inst.components.health:GetPercent()
	for i = #PHASES, 2, -1 do
		local v = PHASES[i]
		if healthpct <= v.hp then
			v.fn(inst)
			break
		end
	end
	--[[if data and data.killtime then
		inst.sg.mem.killstarttime = GetTime() - data.killtime
	end]]

	if inst._resettask == nil and inst._disengagetask == nil and
		not (inst.components.health:IsDead() or inst.components.combat:HasTarget())
	then
		if healthpct >= 1 then
			--loading to full hp => force reset
			inst._resettask = inst:DoTaskInTime(0, TryReset, true)
		else
			inst._resettask = inst:DoPeriodicTask(3, TryReset, 30)
		end
	end
end

--[[local function OnLongUpdate(inst, dt)
	if inst.sg.mem.killstarttime then
		inst.sg.mem.killstarttime = inst.sg.mem.killstarttime - dt
	end
end]]

--------------------------------------------------------------------------

local function CalcSanityAura(inst, observer)
	return inst:IsInArena() == IsEntInArena(observer) and -TUNING.SANITYAURA_LARGE or 0
end

local function SanityAuraFalloff(inst, observer, distsq)
	return not inst:IsInArena() and distsq > 40 * 40 and math.huge or 1
end

--------------------------------------------------------------------------

local function OnUpdateStandbyLoop(inst, dt)
	local d = 1
	if inst.AnimState:IsCurrentAnimation("rise_loop") or inst.AnimState:IsCurrentAnimation("swallow") then
		if ThePlayer then
			d = math.sqrt(inst:GetDistanceSqToPoint(ThePlayer.Transform:GetWorldPosition()))
			d = math.clamp(Remap(d, 5, 14, 1, 0), 0, 1)
		else
			d = 0
		end
	end

	local old = inst._standby
	if inst._standby == nil then
		inst._standby = d
	elseif d > inst._standby then
		inst._standby = math.min(d, inst._standby + 0.05)
	elseif d < inst._standby then
		inst._standby = math.max(d, inst._standby - 0.05)
	end

	if old ~= inst._standby then
		TheFocalPoint.SoundEmitter:SetParameter("charlie_boss_standby", "proximity", inst._standby)
	end
end

local function EnableStandbyLoop(inst, enable)
	if not enable then
		if inst._standby then
			TheFocalPoint.SoundEmitter:KillSound("charlie_boss_standby")
			inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateStandbyLoop)
			inst._standby = nil
		end
	elseif inst._standby == nil then
		TheFocalPoint.SoundEmitter:PlaySound("dontstarve/music/music_epicfight_charlie_standbyLP", "charlie_boss_standby")
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateStandbyLoop)
		OnUpdateStandbyLoop(inst, 0)
		assert(inst._standby)
	end
end

local function EnableGatewayDimensionBattleMix(inst, enable)
	if enable then
		if not inst._gatewaydimensionbattlemix then
			inst._gatewaydimensionbattlemix = true
			TheMixer:PushMix("gateway_dimension_battle")
		end
	elseif inst._gatewaydimensionbattlemix then
		inst._gatewaydimensionbattlemix = nil
		TheMixer:PopMix("gateway_dimension_battle")
	end
end

local function SetPlayingMusic(inst, playing, instant)
	if playing then
		inst._playingmusic = true
		local level = inst.music:value()
		EnableStandbyLoop(inst, level == 1)
		EnableGatewayDimensionBattleMix(inst, level == 2 or level == 3)
		if instant and level == 2 then
			TheFocalPoint.SoundEmitter:PlaySound("dontstarve/music/music_epicfight_charlie_risepst_stinger")
		end
	elseif inst._playingmusic then
		inst._playingmusic = false
		EnableStandbyLoop(inst, false)
		EnableGatewayDimensionBattleMix(inst, false)
	end
end

local function PushMusic(inst, instant)
	if ThePlayer == nil then
		SetPlayingMusic(inst, false, instant)
	else
		local x, _, z = inst.Transform:GetWorldPosition()
		if IsPointInArena(x, 0, z) then
			if IsEntInArena(ThePlayer) then
				SetPlayingMusic(inst, true, instant)
				ThePlayer:PushEvent("triggeredevent", { name = "charlie_boss", level = inst.music:value() })
			else
				SetPlayingMusic(inst, false, instant)
			end
		else
			local dsq = ThePlayer:GetDistanceSqToPoint(x, 0, z)
			local range = inst._playingmusic and 30 or 20
			if dsq < range * range then
				SetPlayingMusic(inst, true, instant)
				ThePlayer:PushEvent("triggeredevent", { name = "charlie_boss", level = inst.music:value() })
			elseif dsq >= 40 * 40 then
				SetPlayingMusic(inst, false, instant)
			end
		end
	end
end

local function OnMusicDirty(inst)
	if inst._musictask then
		inst._musictask:Cancel()
		inst._musictask = nil
	end

	if inst.music:value() > 0 then
		inst._musictask = inst:DoPeriodicTask(1, PushMusic)
		PushMusic(inst, true)
	else
		SetPlayingMusic(inst, false)
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
	local level = inst.camerafocus:value()
	if level == 4 then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 12, 30, 4)
	elseif level == 3 then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 30, 30, 4, nil, Vector3(0, 3, 0))
	elseif level > 0 then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 5, 21, 4, nil, level > 1 and Vector3(0, 3, 0) or nil)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function SetCameraFocusLevel(inst, level)
	if level ~= inst.camerafocus:value() then
		inst.camerafocus:set(level)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

--------------------------------------------------------------------------
-- NOTE: we'll set these to false for the case of setting our own fields to false, but event callbacks are cleared by this point
-- so disabling these is in actuality handled by charlie_boss_trial, not here.
local function OnRemoveEntity(inst)
	SetPlayingMusic(inst, false)

	if TheWorld.ismastersim then
		SetShadowHandsEnabled(inst, false)
		SetRunnerSpawnsEnabled(inst, false)
	end
end

--------------------------------------------------------------------------

local LIGHT_OVERRIDE = 1
local HIGHLIGHT_OVERRIDE = { 0.1, 0.1, 0.1 }

local function AddFollowSymbol(inst, sym, anim)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("charlie_boss")
	fx.AnimState:SetBuild("charlie_boss_basic")
	fx.AnimState:PlayAnimation(anim, true)
	fx.AnimState:SetLightOverride(LIGHT_OVERRIDE)

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, sym, 0, 0, 0, true)

	return fx
end

local function OnColourChanged(inst, r, g, b, a)
	for _, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Light:SetIntensity(0.3)
	inst.Light:SetRadius(0.4)
	inst.Light:SetFalloff(0.9)
	inst.Light:SetColour(0.5, 0, 0)

	MakeGiantCharacterPhysics(inst, 1000, 0.9)

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("charlie_boss")
	inst.AnimState:SetBuild("charlie_boss_basic")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetLightOverride(LIGHT_OVERRIDE)
	if LIGHT_OVERRIDE < 1 then
		inst.AnimState:SetSymbolLightOverride("cb_hand_red", 1)
		inst.AnimState:SetSymbolLightOverride("cb_torso_red", 1)
	end

	inst:AddTag("character")
	inst:AddTag("charlie_npc")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("soulless") --nobody's soul is dropped upon "defeat" of this phase
	inst:AddTag("shadow_aligned")
	inst:AddTag("shadowboss")
	inst:AddTag("epic")
	inst:AddTag("noepicmusic")
	inst:AddTag("toughworker")

	inst.music = net_tinybyte(inst.GUID, "charlie_boss.music", "musicdirty")
	inst.camerafocus = net_tinybyte(inst.GUID, "charlie_boss.camerafocus", "camerafocusdirty")

	inst.highlightoverride = HIGHLIGHT_OVERRIDE
	inst.highlightflashaddoverride = 0.1

	inst:AddComponent("colouraddersync")
	inst:AddComponent("updatelooper")

	if not TheNet:IsDedicated() then
		inst.highlightchildren =
		{
			AddFollowSymbol(inst, "cb_hair_follow", "hair_loop"),
			AddFollowSymbol(inst, "cb_arm_a_follow", "arm_a_loop"),
			AddFollowSymbol(inst, "cb_arm_b_follow", "arm_b_loop"),
			AddFollowSymbol(inst, "cb_base_follow", "base_loop"),
		}

		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.OnRemoveEntity = OnRemoveEntity

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("musicdirty", OnMusicDirty)
		inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)

		return inst
	end

	inst.scrapbook_anim = "scrapbook"

	inst:AddComponent("colouradder")
	inst:AddComponent("inspectable")
	inst:AddComponent("knownlocations")
	inst:AddComponent("damagetyperesist")
	inst:AddComponent("grouptargeter")

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.CHARLIE_BOSS_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat.hiteffectsymbol = "hit_fx_follow"
	inst.components.combat.battlecryinterval = TUNING.CHARLIE_BOSS_TAUNT_INTERVAL
	inst.components.combat.playerdamagepercent = TUNING.CHARLIE_BOSS_PLAYERDAMAGEPERCENT
	inst.components.combat:SetAttackPeriod(TUNING.CHARLIE_BOSS_ATTACK_PERIOD)
	inst.components.combat:SetRange(TUNING.CHARLIE_BOSS_ATTACK_RANGE)
	inst.components.combat:SetDefaultDamage(TUNING.CHARLIE_BOSS_DAMAGE)
	inst.components.combat:SetRetargetFunction(1, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.CHARLIE_BOSS_PLANAR_DAMAGE)

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.CHARLIE_BOSS_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.CHARLIE_BOSS_WALKSPEED

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aurafn = CalcSanityAura
	inst.components.sanityaura.fallofffn = SanityAuraFalloff
	inst.components.sanityaura.max_distsq = 40 * 40

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:AddComponent("explosiveresist")

	inst:AddComponent("epicscare")
	inst.components.epicscare:SetRange(30)

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("charlie_boss")

	inst:SetStateGraph("SGcharlie_boss")
	inst:SetBrain(brain)

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)
	inst:ListenForEvent("death", OnDeath)

	inst._temptbl1 = {}
	inst._temptbl2 = {}
	inst.isreflectingprojectiles = false
	inst.ismodeswitching = false
	inst.isshadowhandsenabled = false
	inst.isrunnerspawnsenabled = false

	inst.IsInArena = IsInArena
	inst.GetAOEAttackTagSet = GetAOEAttackTagSet
	inst.SpawnReflectProjectileAtXYZ = SpawnReflectProjectileAtXYZ
	inst.WantsToReflectProjectiles = WantsToReflectProjectiles
	inst.ToggleReflectingProjectiles = ToggleReflectingProjectiles
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	--inst.OnLongUpdate = OnLongUpdate
	inst.SetMusicLevel = SetMusicLevel
	inst.SetCameraFocusLevel = SetCameraFocusLevel

	inst:AddComponent("healthtrigger")
	for _, v in ipairs(PHASES) do
		inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
	end
	PHASES[1].fn(inst)

	return inst
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("charlie_boss")
	inst.AnimState:SetBuild("charlie_boss_basic")
	inst.AnimState:PlayAnimation("aoe_flame_fx")
	inst.AnimState:SetFinalOffset(-1)

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

return Prefab("charlie_boss", fn, assets, prefabs),
	Prefab("charlie_boss_aoe_flame_fx", fxfn, assets)
