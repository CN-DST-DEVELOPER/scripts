local assets =
{
	Asset("ANIM", "anim/shrouden_build.zip"),
	Asset("ANIM", "anim/shrouden_basic.zip"),
	Asset("ANIM", "anim/shrouden_actions.zip"),
	Asset("ANIM", "anim/shrouden_death.zip"),
	Asset("ANIM", "anim/shrouden_voidcloth.zip"),
}

local prefabs =
{
	"shrouden_eye_fx",
	"shrouden_optic_blast_fx",
	"shadowthrall_hands",
	"shadowthrall_horns",
	"shadowthrall_mouth",
	"shadowthrall_wings",
	"gelblob_attach_fx",
	"honey_trail_shrouden_fx",
	"ocean_splash_ripple1",
	"ocean_splash_ripple2",
	"collapse_small",

	--loot
	"horrorfuel",
	"nightmarefuel",
	"dreadstone",
	"voidcloth",
	"chesspiece_shrouden_sketch",
}

SetSharedLootTable("shrouden",
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
})

SetSharedLootTable("shrouden2",
{
	{ "dreadstone",			1.00 },
	{ "dreadstone",			1.00 },
	{ "dreadstone",			1.00 },
	{ "dreadstone",			1.00 },
	{ "dreadstone",			0.75 },
	{ "dreadstone",			0.50 },

	{ "voidcloth",			1.00 },
	{ "voidcloth",			1.00 },
	{ "voidcloth",			1.00 },
	{ "voidcloth",			1.00 },
	{ "voidcloth",			0.75 },
	{ "voidcloth",			0.50 },

	{ "chesspiece_shrouden_sketch", 1.00 },
})

local brain = require("brains/shroudenbrain")
local AOEUtil = require("aoeutil")

local function _dbg_print(...)
	print("[shrouden]:", ...)
	return true
end

local AOE_TAGSET
local function GetAOEAttackTagSet(inst)
	--Keep in sync with charlie_boss.lua
	if AOE_TAGSET == nil then
		AOE_TAGSET = AOEUtil.AttackTagSet()
		AOE_TAGSET:AppendCantTags("shadowthrall", "shadow", "shadowcreature", "shadowchesspiece", "shadowboss")
		AOE_TAGSET:Register()
	end
	return AOE_TAGSET
end

local function TransferAOEAttackTagSetFrom(inst, charlie_boss)
	if AOE_TAGSET == nil and charlie_boss.prefab == "charlie_boss" then
		AOE_TAGSET = charlie_boss:GetAOEAttackTagSet()
	end
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
		inst.components.epicscare:SetRange(inst._inarena and 30 or TUNING.SHROUDEN_AGGRO_DIST)
	end
	return inst._inarena
end

local function teleport_override_fn(inst)
	return inst:IsInArena() and inst:GetPosition() or nil
end

local function RemoveSpawningArenaSpikes(inst, x, z, r)
	--spike radius 0.8 see charliearena_spike.lua
	for _, v in ipairs(TheSim:FindEntities(x, 0, z, r + 0.8, inst.SPIKE_TAGS)) do
		if v.prefab == "charliearena_spike" then
			if v.components.workable:CanBeWorked() then
				v.components.workable:Destroy(inst)
			elseif v.persists then --don't remove instantly if already destoryed
				v:Remove()
			end
		end
	end
end

--------------------------------------------------------------------------

local MAX_HONEY_VARIATIONS = 7
local MAX_RECENT_HONEY = 4
local HONEY_PERIOD = 0.2
local HONEY_LEVELS =
{
	{
		min_scale = 1.05,
		max_scale = 1.35,
		threshold = 6,
		duration = 24,
	},
	{
		min_scale = 1.05,
		max_scale = 1.35,
		threshold = 3,
		duration = 24,
	},
}

local CONTACT_RADIUS = 3.2
local UNCONCATCT_RADIUS = 3.35
local REGISTERED_GEL_TAGS

local function HoneyFilterFn(v, honey)
	--for the honey_trail, we'll want these tags in addition to the REGISTERED_GEL_TAGS
	return not v:HasAnyTag("flying", "gelblobbed")
end

local function PickHoney(inst)
	local rand = table.remove(inst.availablehoney, math.random(#inst.availablehoney))
	table.insert(inst.usedhoney, rand)
	if #inst.usedhoney > MAX_RECENT_HONEY then
		table.insert(inst.availablehoney, table.remove(inst.usedhoney, 1))
	end
	return rand
end

local function TrySpawnHoney(inst, x, z, min_scale, max_scale, duration)
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local fx = SpawnPrefab("honey_trail_shrouden_fx")
		fx.Transform:SetPosition(x, 0, z) -- NOTES(JBK): This must be before SetVariation is called!
		fx:SetVariation(PickHoney(inst), GetRandomMinMax(min_scale, max_scale), duration + 8 * math.random())
		fx:OverrideSearchParams(REGISTERED_GEL_TAGS, HoneyFilterFn)
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnUpdateGel(inst)
	--gel contact like gelblob
	--swap the tables
	assert(next(inst._temptbl1) == nil)
	local untargets = inst._geltargets
	inst._geltargets, inst._temptbl1 = inst._temptbl1, untargets

	local x, _, z = inst.Transform:GetWorldPosition()
	for _, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, UNCONCATCT_RADIUS + 3, REGISTERED_GEL_TAGS)) do
		local fx = untargets[v]
		local range = (fx and UNCONCATCT_RADIUS or CONTACT_RADIUS) + v:GetPhysicsRadius(0)
		if v:GetDistanceSqToPoint(x, 0, z) < range * range then
			if not (v.sg and v.sg:HasStateTag("suspended")) then
				if fx then
					untargets[v] = nil
				else
					fx = SpawnPrefab("gelblob_attach_fx")
					fx:SetupBlob(inst, v)
					inst:ListenForEvent("onremove", function(fx)
						if inst._geltargets[v] == fx then
							inst._geltargets[v] = nil
						end
					end, fx)
				end
				inst._geltargets[v] = fx
			end
		end
	end

	for k, v in pairs(untargets) do
		v:KillFX()
		untargets[k] = nil
	end

	--honey trail like beequeen (but with black gel build)
	local speed = inst.Physics:GetMotorSpeed()
	if speed < 1 then
		inst.honeycount = 0
	else
		local level = HONEY_LEVELS[speed < 4 and 1 or 2]

		inst.honeycount = inst.honeycount + 1

		if inst.honeythreshold > level.threshold then
			inst.honeythreshold = level.threshold
		end

		if inst.honeycount >= inst.honeythreshold then
			local hx, hy, hz = inst.Transform:GetWorldPosition()
			inst.honeycount = 0
			if inst.honeythreshold < level.threshold then
				inst.honeythreshold = math.ceil((inst.honeythreshold + level.threshold) * 0.5)
			end

			TrySpawnHoney(inst, hx, hz, level.min_scale, level.max_scale, level.duration)
		end
	end
end

local function StartGel(inst)
	if inst._geltask == nil then
		if REGISTERED_GEL_TAGS == nil then
			REGISTERED_GEL_TAGS = TheSim:RegisterFindTags({ "locomotor" }, { "INLIMBO", "flight", "invisible", "notarget", "noattack", "ghost", "playerghost", "shadowthrall", "shadow", "shadowcreature", "shadowminion", "shadowchesspiece", "shadowboss", "stalker", "nogelblob" })
		end

		inst.honeythreshold = HONEY_LEVELS[1].threshold
		inst.honeycount = math.ceil(inst.honeythreshold * 0.5)
		if inst.availablehoney == nil then
			inst.usedhoney = {}
			inst.availablehoney = {}
			for i = 1, MAX_HONEY_VARIATIONS do
				table.insert(inst.availablehoney, i)
			end
		end

		inst._geltask = inst:DoPeriodicTask(0.1, OnUpdateGel, 0)
	end
end

local function StopGel(inst)
	if inst._geltask then
		inst._geltask:Cancel()
		inst._geltask = nil
	end
	for k, v in pairs(inst._geltargets) do
		v:Remove()
		inst._geltargets[k] = nil
	end
end

local function OnEntityWake(inst)
	if inst._gelenabled then
		StartGel(inst)
	end
end

local function OnEntitySleep(inst)
	if inst._gelenabled then
		StopGel(inst)
	end
end

local function SetGelEnabled(inst, enable)
	inst._gelenabled = enable
	if not inst:IsAsleep() then
		if enable then
			StartGel(inst)
		else
			StopGel(inst)
		end
	end
end

local COLLIDE_WORK_ACTIONS =
{
	["CHOP"] = true,
	["MINE"] = true,
	["HAMMER"] = true,
}

local function ClearRecentlyCharged(inst, other)
	inst.recentlycharged[other] = nil
end

local function OnDestroyOther(inst, other)
	local work_action =
		other:IsValid() and
		other.components.workable and
		other.components.workable:CanBeWorked() and
		other.components.workable:GetWorkAction() or
		nil

	if work_action and COLLIDE_WORK_ACTIONS[work_action.id] then
		if other.prefab ~= "charliearena_spike" then
			SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
		end
		other.components.workable:Destroy(inst)
	elseif inst.recentlycharged[other] then
		inst.recentlycharged[other]:Cancel()
		inst.recentlycharged[other] = nil
	end
end

local function OnCollide(inst, other)
	local work_action =
		other and
		not inst.recentlycharged[other] and
		inst:IsValid() and
		inst.sg:HasStateTag("moving") and
		other:IsValid() and
		other.components.workable and
		other.components.workable:CanBeWorked() and
		other.components.workable:GetWorkAction() or
		nil

	if work_action and COLLIDE_WORK_ACTIONS[work_action.id] then
		inst:DoTaskInTime(0, OnDestroyOther, other)
		inst.recentlycharged[other] = inst:DoTaskInTime(2, ClearRecentlyCharged, other)
	end
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
			if not IsEntityDeadOrGhost(v) and
				(v.entity:IsVisible() or v.sg:HasStateTag("devoured")) and
				IsEntInArena(v)
			then
				if toremove[v] then
					toremove[v] = nil
				else
					table.insert(toadd, v)
				end
			end
		end
	else
		local rangesq = TUNING.SHROUDEN_DEAGGRO_DIST * TUNING.SHROUDEN_DEAGGRO_DIST
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and
				(v.entity:IsVisible() or v.sg:HasStateTag("devoured"))
			then
				local x1, _, z1 = v.Transform:GetWorldPosition()
				if math2d.DistSq(x, z, x1, z1) < rangesq and not IsPointInArena(x1, 0, z1) then
					if toremove[v] then
						toremove[v] = nil
					else
						table.insert(toadd, v)
					end
				end
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
		local range = TUNING.SHROUDEN_ATTACK_RANGE + target:GetPhysicsRadius(0)
		local x1, _, z1 = target.Transform:GetWorldPosition()
		inrange =
			not (target.sg and target.sg:HasStateTag("devoured")) and
			math2d.DistSq(x1, z1, x, z) < range * range and
			inst:IsInArena() == IsPointInArena(x1, 0, z1)

		if target.isplayer then
			--NOTE: grouptargets aleady have checked for inarena conditions during UpdatePlayerTargets
			local newplayer = inst.components.grouptargeter:TryGetNewTarget()
			if newplayer and not newplayer.sg:HasStateTag("devoured") then
				range = inrange and TUNING.SHROUDEN_ATTACK_RANGE + newplayer:GetPhysicsRadius(0) or TUNING.SHROUDEN_KEEP_AGGRO_DIST
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
			if not k.sg:HasStateTag("devoured") then
				table.insert(nearplayers, k)
			end
		end
	else
		for k in pairs(inst.components.grouptargeter:GetTargets()) do
			local range = inrange and TUNING.SHROUDEN_ATTACK_RANGE + k:GetPhysicsRadius(0) or TUNING.SHROUDEN_AGGRO_DIST
			if not k.sg:HasStateTag("devoured") and k:GetDistanceSqToPoint(x, 0, z) < range * range then
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
	if not ((target.sg and target.sg:HasStateTag("devoured")) or inst.components.combat:CanTarget(target)) then
		return false
	elseif inst:IsInArena() then
		return IsEntInArena(target)
	end
	return inst:IsNear(target, TUNING.SHROUDEN_DEAGGRO_DIST) and not IsEntInArena(target)
end

local function TryAggro(inst, attacker)
	if inst.components.health:IsDead() or inst.sg:HasStateTag("temp_invincible") then
		return false
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	if target and target.isplayer then
		local range = TUNING.SHROUDEN_ATTACK_RANGE + target:GetPhysicsRadius(0)
		if target:GetDistanceSqToPoint(x, y, z) < range * range then
			return false
		end
	end
	inst.components.combat:SetTarget(attacker)
	return true
end

local RECENT_ATTACKERS_DURATION = 6

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() then
		if not data.attacker.isplayer then
			inst._recent_attackers[data.attacker] = GetTime()
		end
		TryAggro(inst, data.attacker)
	end
end

local function ForEachRecentNonPlayerAttacker(inst, cb)
	local t = GetTime()
	for k, v in pairs(inst._recent_attackers) do
		if v + RECENT_ATTACKERS_DURATION < t or not k:IsValid() or (k.components.health and k.components.health:IsDead()) then
			inst._recent_attackers[k] = nil
		elseif cb(k, inst) then
			return
		end
	end
end

--------------------------------------------------------------------------

local function CalcSanityAura(inst, observer)
	return inst:IsInArena() == IsEntInArena(observer) and -TUNING.SANITYAURA_LARGE or 0
end

local function SanityAuraFalloff(inst, observer, distsq)
	return not inst:IsInArena() and distsq > 40 * 40 and math.huge or 1
end

--------------------------------------------------------------------------

local function SetDreadstoneSpikesSpawnsEnabled(inst, enable)
	if enable then
		if not inst.isspikespawnsenabled and inst:IsInArena() then
			inst.isspikespawnsenabled = true
			inst:PushEvent("ms_charliearena_dreadstonespikes_setenabled", true)
		end
	elseif inst.isspikespawnsenabled then
		inst.isspikespawnsenabled = false
		inst:PushEvent("ms_charliearena_dreadstonespikes_setenabled", false)
	end
end

local PHASES =
{
	{
		hp = 1,
		fn = function(inst)
			inst.canexsummon = false
			inst.canopticblast = false
			inst.cancomboblast = false
			inst.canwideblast = false
			inst.canteleport = false
			inst.canautoquickattack = false
			inst.candreadstonespikes = false
			SetDreadstoneSpikesSpawnsEnabled(inst, false)
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
		end,
	},
	{
		hp = 0.95,
		fn = function(inst)
			inst.canexsummon = false
			inst.canopticblast = false
			inst.cancomboblast = false
			inst.canwideblast = false
			inst.canteleport = true
			inst.canautoquickattack = false
			inst.candreadstonespikes = true
			SetDreadstoneSpikesSpawnsEnabled(inst, inst.components.combat:HasTarget())
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
		end,
	},
	{
		hp = 5 / 6,
		fn = function(inst)
			inst.canexsummon = false
			inst.canopticblast = true
			inst.cancomboblast = false
			inst.canwideblast = false
			inst.canteleport = true
			inst.canautoquickattack = false
			inst.candreadstonespikes = true
			SetDreadstoneSpikesSpawnsEnabled(inst, inst.components.combat:HasTarget())
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
		end,
	},
	{
		hp = 2 / 3,
		fn = function(inst)
			inst.canexsummon = true
			inst.canopticblast = true
			inst.cancomboblast = true
			inst.canwideblast = false
			inst.canteleport = true
			inst.canautoquickattack = true
			inst.candreadstonespikes = true
			SetDreadstoneSpikesSpawnsEnabled(inst, inst.components.combat:HasTarget())
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
		end,
	},
	{
		hp = 1 / 3,
		fn = function(inst)
			inst.canexsummon = true
			inst.canopticblast = true
			inst.cancomboblast = true
			inst.canwideblast = true
			inst.canteleport = true
			inst.canautoquickattack = true
			inst.candreadstonespikes = true
			SetDreadstoneSpikesSpawnsEnabled(inst, inst.components.combat:HasTarget())
			inst.sg.mem.forcetaunt = true
			inst.components.combat.battlecryenabled = true
		end,
	},
}

local DEESCALATE_TIME = 20

local function CalcThreatLevel(inst, dps)
	local numthreatlevels = #TUNING.SHROUDEN_ATTACK_PERIOD
	local level = math.floor(Remap(dps, 150, 375, 1, numthreatlevels))
	if inst.components.grouptargeter:GetNumTargets() <= 1 then
		level = level - 1
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
			_dbg_print("threat level "..(level > inst.threatlevel and "raised" or "lowered").." to "..tostring(level))
		end
		inst.threatlevel = level
		inst.components.combat:SetAttackPeriod(TUNING.SHROUDEN_ATTACK_PERIOD[level])
	end
end

local function OnDpsUpdate(inst, dps)
	local threatlevel = CalcThreatLevel(inst, dps)
	if threatlevel >= inst.threatlevel then
		SetThreatLevel(inst, threatlevel)
	end
end

--------------------------------------------------------------------------

local function TryReset(inst, force)
	if not inst:IsInArena() then
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
	inst:SetLowHPMusic(false)
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
	SetDreadstoneSpikesSpawnsEnabled(inst, inst.candreadstonespikes)

	if not inst.sg:HasStateTag("spawning") then
		inst:SetMusicLevel(3)
	end
end

local function Disengage(inst)
	inst._disengagetask:Cancel()
	inst._disengagetask = nil
	SetDreadstoneSpikesSpawnsEnabled(inst, false)
	inst.components.combat.battlecryenabled = true
	inst.sg.mem.forcetaunt = nil

	if inst._resettask == nil then
		inst._resettask = inst:DoPeriodicTask(3, TryReset, 0)
	end

	if not inst.sg:HasStateTag("spawning") then
		inst:SetMusicLevel(inst.components.health:IsDead() and 4 or 0)
	end
end

local function TryDisengageTick(inst)
	if inst.components.grouptargeter:GetNumTargets() > 0 then
		inst._disengagetask._numticks = 0
	elseif inst._disengagetask._numticks < 9 then
		inst._disengagetask._numticks = inst._disengagetask._numticks + 1
	else
		Disengage(inst)
	end
end

local function OnDroppedTarget(inst)
	if inst._disengagetask == nil then
		inst._disengagetask = inst:DoPeriodicTask(1, TryDisengageTick)
		inst._disengagetask._numticks = 0
	end
end

local function OnDeath(inst)
	inst.components.combat:DropTarget()
	if inst._disengagetask then
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

local function OnHealthDelta(inst, data)
	if data and data.newpercent then
		inst:SetLowHPMusic(data.newpercent < 0.1)
	end
end

local function OnSave(inst, data)
	if inst.sg.mem.changearena then
		data.changearena = true
	end

	--nil: nothing dropped yet
	--1: fuel dropped already
	--true: fuel & mats dropped already
	data.looted = inst.looted
end

local function OnLoad(inst, data)--, ents)
	inst.looted = data and data.looted

	local healthpct = inst.components.health:GetPercent()
	inst:SetLowHPMusic(healthpct < 0.1)
	for i = #PHASES, 2, -1 do
		local v = PHASES[i]
		if healthpct <= v.hp then
			v.fn(inst)
			break
		end
	end

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

local function DoChangeArena(inst)
	if inst.sg.mem.changearena then
		inst.sg.mem.changearena = nil
		if inst:IsInArena() then
			inst:PushEvent("ms_charliearena_becomeunstable")
		end
	end
end

local function OnLoadPostPass(inst, newents, data)
	if data and data.changearena then
		inst.sg.mem.changearena = true
		inst:DoTaskInTime(0, DoChangeArena)
	end
end

--------------------------------------------------------------------------

local function OnCameraFocusDirty(inst)
	if inst.camerafocus:value() then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 5, 21, 4)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function SetCameraFocusEnabled(inst, enable)
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function Portal_Recycle(fx)
	local parent = fx.entity:GetParent()
	if parent and parent.portal == fx then
		parent.portal = nil
		if parent.portalpool == nil then
			parent.portalpool = fx
			fx:RemoveFromScene()
		else
			fx:Remove()
		end
	else
		fx:Remove()
	end
end

local function CreatePortal()
	local fx = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	fx:AddTag("can_offset_sort_pos")

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.Transform:SetEightFaced()

	fx.AnimState:SetBank("shrouden")
	fx.AnimState:SetBuild("shrouden_build")
	fx.AnimState:PlayAnimation("portal_ring_loop", true)
	fx.AnimState:SetSymbolLightOverride("RED_swirl_01", 1)
	fx.AnimState:SetSymbolLightOverride("WHITE_swirl_01", 1)
	fx.AnimState:SetSymbolLightOverride("canter_star", 1)
	fx.AnimState:SetSortWorldOffset(0, 2, 0)
	fx.AnimState:SetFinalOffset(1)

	fx:ListenForEvent("animqueueover", Portal_Recycle)

	return fx
end

local function GetPortal(inst)
	if inst.portalpool then
		local fx = inst.portalpool
		inst.portalpool = nil
		fx:ReturnToScene()
		fx.AnimState:PlayAnimation("portal_ring_loop", true)
		return fx
	end
	local fx = CreatePortal()
	fx.entity:SetParent(inst.entity)
	fx.Transform:SetPosition(5.7, 0, 0)
	table.insert(inst.highlightchildren, fx)
	return fx
end

local function PortalWind_Recycle(fx)
	local parent = fx.entity:GetParent()
	if parent and parent.wind and table.removearrayvalue(parent.wind, fx) == fx then
		if #parent.wind <= 0 then
			parent.wind = nil
		end
		if parent.windpool then
			table.insert(parent.windpool, fx)
			fx:RemoveFromScene()
		else
			fx:Remove()
		end
	else
		fx:Remove()
	end
end

local function CreatePortalWind()
	local fx = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	fx:AddTag("can_offset_sort_pos")

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.Transform:SetEightFaced()

	fx.AnimState:SetBank("shrouden")
	fx.AnimState:SetBuild("shrouden_build")
	fx.AnimState:PlayAnimation("portal_wind_loop", true)
	fx.AnimState:SetLightOverride(0.8)
	fx.AnimState:SetSortWorldOffset(0, 1.99, 0)

	fx:ListenForEvent("animqueueover", PortalWind_Recycle)

	return fx
end

local function GetPortalWind(inst)
	if #inst.windpool > 0 then
		local fx = table.remove(inst.windpool)
		fx:ReturnToScene()
		fx.AnimState:PlayAnimation("portal_wind_loop", true)
		return fx
	end
	local fx = CreatePortalWind()
	fx.entity:SetParent(inst.entity)
	table.insert(inst.highlightchildren, fx)
	return fx
end

local function PostUpdate_PortalAnimSync(inst)
	if inst.portal or inst.wind then
		if inst.AnimState:IsCurrentAnimation("punch_pre") then
			local len = inst.AnimState:GetCurrentAnimationNumFrames()
			local frame = inst.AnimState:GetCurrentAnimationFrame()
			if inst.portal then
				inst.portal.AnimState:PlayAnimation("portal_ring_pre")
				inst.portal.AnimState:PushAnimation("portal_ring_loop")

				local portalprelen = inst.portal.AnimState:GetCurrentAnimationNumFrames()
				local portalframe = frame - (len - portalprelen)
				if portalframe >= 0 then
					inst.portal.AnimState:SetFrame(portalframe)
					inst.portal:Show()
				else
					inst.portal:Hide()
				end
			end
			if inst.wind then
				for _, v in ipairs(inst.wind) do
					v.AnimState:PlayAnimation("portal_wind_pre")
					v.AnimState:PushAnimation("portal_wind_loop")

					local windprelen = v.AnimState:GetCurrentAnimationNumFrames()
					local windframe = frame - (len - windprelen)
					if windframe >= 0 then
						v.AnimState:SetFrame(windframe)
						v:Show()
					else
						v:Hide()
					end
				end
			end
		elseif inst.AnimState:IsCurrentAnimation("punch_loop") then
			local t = inst.AnimState:GetCurrentAnimationTime()
			if inst.portal then
				inst.portal:Show()
				if not inst.portal.AnimState:IsCurrentAnimation("portal_ring_loop") then
					inst.portal.AnimState:PlayAnimation("portal_ring_loop", true)
					inst.portal.AnimState:SetTime(t)
				end
			end
			if inst.wind then
				for _, v in ipairs(inst.wind) do
					v:Show()
					if not v.AnimState:IsCurrentAnimation("portal_wind_loop") then
						v.AnimState:PlayAnimation("portal_wind_loop", true)
						v.AnimState:SetTime(t)
					end
				end
			end
		elseif inst.AnimState:IsCurrentAnimation("punch_pst") then
			if inst.portal then
				inst.portal:Show()
				inst.portal.AnimState:PlayAnimation("portal_ring_pst")
			end
			if inst.wind then
				for _, v in ipairs(inst.wind) do
					v:Show()
					v.AnimState:PlayAnimation("portal_wind_pst")
				end
			end
		else
			if inst.portal then
				Portal_Recycle(inst.portal)
				assert(inst.portal == nil)
			end
			if inst.wind then
				for i = #inst.wind, 1, -1 do
					PortalWind_Recycle(inst, wind[i])
				end
				assert(inst.wind == nil)
			end
		end
	end
	if inst._portalanimsync then
		if inst.portal and not inst.portal.entity:IsVisible() then
			return --pre-state waiting for start frame
		elseif inst.wind then
			for _, v in ipairs(inst.wind) do
				if not v.entity:IsVisible() then
					return --pre-state waiting for start frame
				end
			end
		end
		inst._portalanimsync = false
		inst.components.updatelooper:RemovePostUpdateFn(PostUpdate_PortalAnimSync)
	end
end

local function OnPortalOpenDirty(inst)
	if inst.portalopen:value() then
		if not (inst.portal and inst.wind) then
			if inst.portal == nil then
				inst.portal = GetPortal(inst)
			end
			if inst.wind == nil then
				inst.wind = {}
				local xoffs = 6--5.7
				local scale = 1.25
				local alpha = 0.5
				for i = 1, 3 do
					xoffs = xoffs - 1.25
					scale = scale - 0.125
					alpha = alpha - 0.15
					local wind = GetPortalWind(inst)
					wind.AnimState:SetScale(scale, scale)
					wind.AnimState:SetMultColour(1, 1, 1, alpha)
					wind.Transform:SetPosition(xoffs, 0, 0)
					table.insert(inst.wind, wind)
				end
			end
			inst.components.colouraddersync:ForceRefresh()
		end
		if TheWorld.ismastersim then
			PostUpdate_PortalAnimSync(inst)
		elseif not inst._portalanimsync then
			inst._portalanimsync = true
			inst.components.updatelooper:AddPostUpdateFn(PostUpdate_PortalAnimSync)
		end
	else
		if inst.portal then
			Portal_Recycle(inst.portal)
			assert(inst.portal == nil)
		end
		if inst.wind then
			for i = #inst.wind, 1, -1 do
				PortalWind_Recycle(inst.wind[i])
			end
			assert(inst.wind == nil)
		end
	end
end

local function SetPortalOpen(inst, open)
	inst.portalopen:set_local(open)
	inst.portalopen:set(open)
	if not TheNet:IsDedicated() then
		OnPortalOpenDirty(inst)
	end
end

--------------------------------------------------------------------------

local function OnUpdateStandbyLoop(inst, dt)
	local d = 1
	if inst.AnimState:IsCurrentAnimation("teleport_loop") then
		if ThePlayer then
			d = math.sqrt(inst:GetDistanceSqToPoint(ThePlayer.Transform:GetWorldPosition()))
			d = math.clamp(Remap(d, 5, 14, 1, 0), 0, 1)
		else
			d = 0
		end
	end
	if inst._standby == nil then
		inst._standby = d
	elseif d > inst._standby then
		inst._standby = math.min(d, inst._standby + 0.05)
	elseif d < inst._standby then
		inst._standby = math.max(d, inst._standby - 0.05)
	end
	TheFocalPoint.SoundEmitter:SetParameter("shrouden_standby", "HP", inst._standby)
end

local function EnableStandbyLoop(inst, enable)
	if not enable then
		if inst._standby then
			TheFocalPoint.SoundEmitter:KillSound("shrouden_standby")
			inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateStandbyLoop)
			inst._standby = nil
		end
	elseif inst._standby == nil then
		TheFocalPoint.SoundEmitter:PlaySound("dontstarve/music/music_epicfight_shrouden_lowHP", "shrouden_standby")
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateStandbyLoop)
		OnUpdateStandbyLoop(inst, 0)
		assert(inst._standby)
	end
end

local function EnableLowHPLoop(inst, enable)
	if not enable then
		TheFocalPoint.SoundEmitter:KillSound("shrouden_lowhp")
	elseif not TheFocalPoint.SoundEmitter:PlayingSound("shrouden_lowhp") then
		TheFocalPoint.SoundEmitter:PlaySound("dontstarve/music/music_epicfight_shrouden_lowHP", "shrouden_lowhp")
		TheFocalPoint.SoundEmitter:SetParameter("shrouden_lowhp", "HP", 1)
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
		if instant and level == 2 and TheFocalPoint.SoundEmitter:PlayingSound("shrouden_standby") then
			TheFocalPoint.SoundEmitter:SetParameter("shrouden_standby", "HP", 1)
		end
		EnableStandbyLoop(inst, level == 1)
		EnableLowHPLoop(inst, level == 3 and inst.lowhp:value())
		EnableGatewayDimensionBattleMix(inst, level == 2 or level == 3)
	elseif inst._playingmusic then
		inst._playingmusic = false
		EnableStandbyLoop(inst, false)
		EnableLowHPLoop(inst, false)
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
				ThePlayer:PushEvent("triggeredevent", { name = "shrouden", level = inst.music:value() })
			else
				SetPlayingMusic(inst, false, instant)
			end
		else
			local dsq = ThePlayer:GetDistanceSqToPoint(x, 0, z)
			local range = inst._playingmusic and 30 or 20
			if dsq < range * range then
				SetPlayingMusic(inst, true, instant)
				ThePlayer:PushEvent("triggeredevent", { name = "shrouden", level = inst.music:value() })
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

local function SetLowHPMusic(inst, lowhp)
	if lowhp ~= inst.lowhp:value() then
		inst.lowhp:set(lowhp)

		--Dedicated server does not need to trigger music
		if not TheNet:IsDedicated() then
			OnMusicDirty(inst)
		end
	end
end

local function DisplayNameFn(inst)
	if ThePlayer then
		if ThePlayer:HasTag("shadowthrall_parasite_mask") then
			return STRINGS.NAMES.SHROUDEN_VOIDMASQUE
		elseif ThePlayer.replica.inventory and ThePlayer.replica.inventory:EquipHasTag("ancient_reader") then
			return STRINGS.NAMES.SHROUDEN_OTHER
		elseif ThePlayer:HasTag("player_shadow_aligned") then
			return STRINGS.NAMES.SHROUDEN_ALLEGIANCE
		end
	end

	return nil
end

local function OnRemoveEntity(inst)
	SetPlayingMusic(inst, false)

	if TheWorld.ismastersim then
		for k, v in pairs(inst._geltargets) do
			v:Remove()
			inst._geltargets[k] = nil
		end
		SetDreadstoneSpikesSpawnsEnabled(inst, false)
	end
end

--------------------------------------------------------------------------

local function _AttachFollowSymbol(inst, bank, build, sym, anim, frame)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--fx.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank(bank)
	fx.AnimState:SetBuild(build)

	fx.entity:SetParent(inst.entity)

	if anim then
		fx.AnimState:PlayAnimation(anim, true)
		fx.Follower:FollowSymbol(inst.GUID, sym, nil, nil, nil, true)
	else
		fx.AnimState:PlayAnimation(sym..tostring(frame))
		fx.Follower:FollowSymbol(inst.GUID, sym.."_follow", nil, nil, nil, true, false, frame - 1)
	end

	table.insert(inst.highlightchildren, fx)

	return fx
end

local function AttachDreadstonePart(inst, sym, frame)
	local fx = _AttachFollowSymbol(inst, "shrouden", "shrouden_build", sym, nil, frame)
	fx.AnimState:SetSymbolLightOverride(sym.."_red", 1)
	return fx
end

local function AttachVoidclothPart(inst, sym, frame)
	return _AttachFollowSymbol(inst, "shrouden", "shrouden_build", sym, nil, frame)
end

local function AttachVoidclothLoop(inst, sym, anim, sync)
	local fx = _AttachFollowSymbol(inst, "shrouden_voidcloth", "shrouden_voidcloth", sym, anim)
	if sync then
		inst._loopsync = inst._loopsync or math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
		fx.AnimState:SetFrame(inst._loopsync)
	else
		inst._loopsync = nil
		fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
	end
	return fx
end

local function OnColourChanged(inst, r, g, b, a)
	for _, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local HIGHLIGHT_OVERRIDE = { 0.1, 0.1, 0.1 }

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

	inst:SetPhysicsRadiusOverride(3)
	MakeGiantCharacterPhysics(inst, 1000, inst.physicsradiusoverride)

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("shrouden")
	inst.AnimState:SetBuild("shrouden_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:Hide("PUDDLE_EYEBALL")
	inst.AnimState:SetLightOverride(1)

	inst:AddTag("largecreature")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("soulless")
	inst:AddTag("shadow_aligned")
	inst:AddTag("shadowboss")
	inst:AddTag("epic")
	inst:AddTag("noepicmusic")
	inst:AddTag("toughworker")

	--rainimmunity (from rainimmunity component) added to pristine state for optimization
	inst:AddTag("rainimmunity")

	inst.portalopen = net_bool(inst.GUID, "shrouden.portalopen", "portalopendirty")
	inst.music = net_tinybyte(inst.GUID, "shrouden.music", "musicdirty")
	inst.lowhp = net_bool(inst.GUID, "shrouden.lowhp", "musicdirty")
	inst.camerafocus = net_bool(inst.GUID, "shrouden.camerafocus", "camerafocusdirty")

	inst.highlightoverride = HIGHLIGHT_OVERRIDE
	inst.highlightflashaddoverride = 0.1

	inst:AddComponent("colouraddersync")

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst.highlightchildren = {}
		inst.windpool = {}

		for i = 1, 2 do AttachDreadstonePart(inst, "sh_brow", i) end
		for i = 1, 2 do AttachDreadstonePart(inst, "sh_horn", i) end
		for i = 1, 3 do AttachDreadstonePart(inst, "sh_jaw", i) end

		for i = 1, 1 do AttachVoidclothPart(inst, "sh_void_wrap_fabric", i) end
		for i = 1, 2 do AttachVoidclothPart(inst, "sh_shoulder_fabric", i) end
		for i = 1, 1 do AttachVoidclothPart(inst, "sh_pelvis_fabric", i) end
		for i = 1, 2 do AttachVoidclothPart(inst, "fabric_swirl", i) end

		AttachVoidclothLoop(inst, "void_arc_fr_follow", "void_arc_fr", true)
		AttachVoidclothLoop(inst, "void_arc_bk_follow", "void_arc_bk", true)
		AttachVoidclothLoop(inst, "void_fabric_followL", "void_fabric", false)
		AttachVoidclothLoop(inst, "void_fabric_followR", "void_fabric", false)

		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.displaynamefn = DisplayNameFn
	inst.OnRemoveEntity = OnRemoveEntity

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("portalopendirty", OnPortalOpenDirty)
		inst:ListenForEvent("musicdirty", OnMusicDirty)
		inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)

		return inst
	end

	inst.scrapbook_anim = "scrapbook"
	inst.scrapbook_overridebuild = "shrouden_voidcloth"

	inst.recentlycharged = {}
	inst.Physics:SetCollisionCallback(OnCollide)

	inst:AddComponent("inspectable")
	inst:AddComponent("colouradder")
	inst:AddComponent("knownlocations")

	inst:AddComponent("rainimmunity")
	inst.components.rainimmunity:AddSource(inst)

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.SHROUDEN_HEALTH)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.SHROUDEN_DAMAGE)
	--inst.components.combat:SetAttackPeriod(TUNING.SHROUDEN_ATTACK_PERIOD[1])
	inst.components.combat:SetRange(TUNING.SHROUDEN_ATTACK_RANGE)
	inst.components.combat:SetRetargetFunction(1, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.playerdamagepercent = TUNING.SHROUDEN_PLAYERDAMAGEPERCENT
	inst.components.combat.hiteffectsymbol = "sh_torso"
	inst.components.combat.battlecryinterval = TUNING.CHARLIE_BOSS_TAUNT_INTERVAL

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SHROUDEN_PLANAR_DAMAGE)

	inst:AddComponent("explosiveresist")

	inst:AddComponent("epicscare")
	inst.components.epicscare:SetRange(30)

	inst:AddComponent("timer")
	inst:AddComponent("grouptargeter")

	inst:AddComponent("dpstracker")
	inst.components.dpstracker:SetOnDpsUpdateFn(OnDpsUpdate)

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aurafn = CalcSanityAura
	inst.components.sanityaura.fallofffn = SanityAuraFalloff
	inst.components.sanityaura.max_distsq = 40 * 40

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHROUDEN_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.SHROUDEN_WALKSPEED
	inst.components.locomotor.pathcaps = { ignorewalls = true }

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable("shrouden")
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 4
	inst.components.lootdropper.y_offset = 4
	inst.components.lootdropper.y_speed = 14
	inst.components.lootdropper.y_speed_variance = 4

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:SetStateGraph("SGshrouden")
	inst:SetBrain(brain)

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)
	inst:ListenForEvent("death", OnDeath)
	inst:ListenForEvent("healthdelta", OnHealthDelta)

	inst._temptbl1 = {}
	inst._temptbl2 = {}
	inst._geltargets = {}
	inst._recent_attackers = {}

	inst.SPIKE_TAGS = { "groundspike" }

	inst.IsInArena = IsInArena
	inst.GetAOEAttackTagSet = GetAOEAttackTagSet
	inst.ForEachRecentNonPlayerAttacker = ForEachRecentNonPlayerAttacker
	inst.RemoveSpawningArenaSpikes = RemoveSpawningArenaSpikes
	inst.TransferAOEAttackTagSetFrom = TransferAOEAttackTagSetFrom
	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnLoadPostPass = OnLoadPostPass
	inst.SetMusicLevel = SetMusicLevel
	inst.SetLowHPMusic = SetLowHPMusic
	inst.SetCameraFocusEnabled = SetCameraFocusEnabled
	inst.SetPortalOpen = SetPortalOpen
	inst.SetGelEnabled = SetGelEnabled

	inst:AddComponent("healthtrigger")
	for _, v in ipairs(PHASES) do
		inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
	end
	PHASES[1].fn(inst)

	--inst.threatlevel = 1
	SetThreatLevel(inst, 1)

	return inst
end

--------------------------------------------------------------------------

local function CreateEyeGoopLayer()
	local goop = CreateEntity()

	goop:AddTag("DECOR")
	goop:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--goop.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	goop.persists = false

	goop.entity:AddTransform()
	goop.entity:AddAnimState()

	goop.Transform:SetSixFaced()

	goop.AnimState:SetBank("shrouden")
	goop.AnimState:SetBuild("shrouden_voidcloth") --wrong build on purpose so symbols are blank
	goop.AnimState:OverrideSymbol("puddle_eye_lip", "shrouden_build", "puddle_eye_lip")
	goop.AnimState:PlayAnimation("death")
	goop.AnimState:SetFinalOffset(1)
	goop.AnimState:SetLightOverride(1)

	return goop
end

local function eye_DoAnimSync(inst)
	if inst._animsyncing then
		inst._animsyncing = nil
		inst.components.updatelooper:RemovePostUpdateFn(eye_DoAnimSync)
	end
	if inst.AnimState:IsCurrentAnimation("final_blow") then
		inst.goop.AnimState:PlayAnimation("final_blow")
		inst.goop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
		inst:AddTag("NOCLICK")
	else
		inst:RemoveTag("NOCLICK")
		if inst.AnimState:IsCurrentAnimation("death") then
			inst.goop.AnimState:PlayAnimation("death")
			inst.goop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
			inst.goop.AnimState:PushAnimation("death_puddle_loop")
		elseif inst.AnimState:IsCurrentAnimation("death_puddle_loop") then
			inst.goop.AnimState:PlayAnimation("death_puddle_loop", true)
			inst.goop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
		elseif inst.AnimState:IsCurrentAnimation("death_puddle_loop2") then
			inst.goop.AnimState:PlayAnimation("death_puddle_loop2", true)
			inst.goop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
		elseif inst.AnimState:IsCurrentAnimation("death_puddle_hit") then
			inst.goop.AnimState:PlayAnimation("death_puddle_hit")
			inst.goop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
			inst.goop.AnimState:PushAnimation("death_puddle_loop")
		end
	end
end

local function eye_OnAnimSync(inst)
	if inst._animsyncing == nil then
		inst._animsyncing = true
		inst.components.updatelooper:AddPostUpdateFn(eye_DoAnimSync)
	end
end

local function eye_SyncAnim(inst, anim, loop, frame)
	inst.AnimState:PlayAnimation(anim, loop)
	if frame then
		inst.AnimState:SetFrame(frame)
	end
	inst.animsync:push()
	if inst.goop then
		eye_DoAnimSync(inst)
	end
end

local function eye_GetStatus(inst)--, viewer)
	return "PUDDLE"
end

local function eyefn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("shrouden")
	inst.AnimState:SetBuild("shrouden_voidcloth") --wrong build on purpose so symbols are blank
	inst.AnimState:Hide("sh_eye")
	inst.AnimState:OverrideSymbol("sh_eye_pupil", "shrouden_build", "sh_eye_pupil")
	inst.AnimState:OverrideSymbol("RED_fx_eye_ball", "shrouden_build", "RED_fx_eye_ball")
	inst.AnimState:OverrideSymbol("RED_fx_eye_flame", "shrouden_build", "RED_fx_eye_flame")
	inst.AnimState:OverrideSymbol("fx_bubble", "shrouden_build", "fx_bubble")
	inst.AnimState:OverrideSymbol("RED_swirl_01", "shrouden_build", "RED_swirl_01")
	inst.AnimState:PlayAnimation("death")
	inst.AnimState:SetLightOverride(1)

	inst.animsync = net_event(inst.GUID, "shrouden_eye_fx.animsync")

	inst.highlightoverride = HIGHLIGHT_OVERRIDE
	inst.highlightflashaddoverride = 0.1

	inst:SetPrefabNameOverride("shrouden")

	if not TheNet:IsDedicated() then
		inst.goop = CreateEyeGoopLayer()
		inst.goop.entity:SetParent(inst.entity)
	end

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("shrouden_eye_fx.animsync", eye_OnAnimSync)

		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = eye_GetStatus

	inst.persists = false

	inst.SyncAnim = eye_SyncAnim

	return inst
end

--------------------------------------------------------------------------

return Prefab("shrouden", fn, assets, prefabs),
	Prefab("shrouden_eye_fx", eyefn, assets)
