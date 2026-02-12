local clockwork_common = require "prefabs/clockwork_common"
local RuinsRespawner = require "prefabs/ruinsrespawner"

local assets =
{
    Asset("ANIM", "anim/knight.zip"),
    Asset("ANIM", "anim/knight_build.zip"),
    Asset("SOUND", "sound/chess.fsb"),
    Asset("SCRIPT", "scripts/prefabs/clockwork_common.lua"),
}

local prefabs =
{
    "gears",
}

local assets_nightmare =
{
    Asset("ANIM", "anim/knight.zip"),
    Asset("ANIM", "anim/knight_nightmare.zip"),
    Asset("SCRIPT", "scripts/prefabs/clockwork_common.lua"),
    Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua"),
    Asset("SOUND", "sound/chess.fsb"),
}

local prefabs_nightmare =
{
    "gears",
    "thulecite_pieces",
    "nightmarefuel",
    "knight_nightmare_ruinsrespawner_inst",
}

local assets_yoth =
{
    Asset("ANIM", "anim/knight.zip"),
    Asset("ANIM", "anim/knight_yoth_build.zip"),
    Asset("ANIM", "anim/knight_yoth_conquest_build.zip"),
    Asset("ANIM", "anim/knight_yoth_famine_build.zip"),
    Asset("ANIM", "anim/knight_yoth_death_build.zip"),
    Asset("SOUND", "sound/chess.fsb"),
    Asset("SCRIPT", "scripts/prefabs/clockwork_common.lua"),
}

local prefabs_yoth =
{
    "gears",
    "redpouch_yoth",
    "horseshoe",
    "lucky_goldnugget",

    "yoth_knighthat",
    "armor_yoth_knight",
    "yoth_lance",
}

local brain = require "brains/knightbrain"

SetSharedLootTable("knight",
{
    {"gears",  1.0},
    {"gears",  1.0},
})

SetSharedLootTable("knight_nightmare",
{
    {"gears",             1.0},
    {"nightmarefuel",     0.6},
    {"thulecite_pieces",  0.5},
})

SetSharedLootTable("knight_gilded",
{
    {"gears",               1.0},
    {"gears",               1.0},
    {"redpouch_yoth",       1.0},
    {"horseshoe",           1.0},
    {"horseshoe",           0.10},
    {"yoth_lance",          0.25},
})

local function Retarget(inst)
    return clockwork_common.Retarget(inst, TUNING.KNIGHT_TARGET_DIST)
end

local function MakeKnight(name, common_postinit, master_postinit, _assets, _prefabs)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddDynamicShadow()
		inst.entity:AddNetwork()

		inst:SetPhysicsRadiusOverride(0.5)
		MakeCharacterPhysics(inst, 50, inst.physicsradiusoverride)

		inst.DynamicShadow:SetSize(1.5, .75)
		inst.Transform:SetFourFaced()

		inst.AnimState:SetBank("knight")

		inst:AddTag("chess")
		inst:AddTag("hostile")
		inst:AddTag("knight")
		inst:AddTag("monster")

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.override_combat_fx_height = "high"
		inst.kind = "" --for sound paths

		inst:AddComponent("combat")
		inst.components.combat.hiteffectsymbol = "spring"
		inst.components.combat:SetAttackPeriod(TUNING.KNIGHT_ATTACK_PERIOD)
		inst.components.combat:SetRange(TUNING.KNIGHT_ATTACK_RANGE, TUNING.KNIGHT_HIT_RANGE)
		inst.components.combat:SetDefaultDamage(TUNING.KNIGHT_DAMAGE)
		inst.components.combat:SetRetargetFunction(3, Retarget)
		inst.components.combat:SetKeepTargetFunction(clockwork_common.KeepTarget)

		inst:AddComponent("follower")

		inst:AddComponent("health")
		inst.components.health:SetMaxHealth(TUNING.KNIGHT_HEALTH)

		inst:AddComponent("inspectable")
		inst:AddComponent("knownlocations")

		inst:AddComponent("locomotor")
		inst.components.locomotor.walkspeed = TUNING.KNIGHT_WALK_SPEED
        -- boat hopping setup
        inst.components.locomotor:SetAllowPlatformHopping(true)

        inst:AddComponent("embarker")
		inst:AddComponent("drownable")
		inst:AddComponent("lootdropper")

		inst:AddComponent("sleeper")
		inst.components.sleeper:SetWakeTest(clockwork_common.ShouldWake)
		inst.components.sleeper:SetSleepTest(clockwork_common.ShouldSleep)
		inst.components.sleeper:SetResistance(3)

		MakeMediumBurnableCharacter(inst, "spring")
		MakeMediumFreezableCharacter(inst, "spring")
		MakeHauntablePanic(inst)

		inst:SetStateGraph("SGknight")
		inst:SetBrain(brain)

		inst:ListenForEvent("attacked", clockwork_common.OnAttacked)
		inst:ListenForEvent("newcombattarget", clockwork_common.OnNewCombatTarget)

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end

	return Prefab(name, fn, _assets, _prefabs)
end

--------------------------------------------------------------------------

local function normal_common_postinit(inst)
	inst.AnimState:SetBuild("knight_build")
end

local function normal_master_postinit(inst)
	inst.components.lootdropper:SetChanceLootTable("knight")

	clockwork_common.InitHomePosition(inst)
	clockwork_common.MakeBefriendable(inst)
	clockwork_common.MakeHealthRegen(inst)
end

--------------------------------------------------------------------------

local function nightmare_common_postinit(inst)
	inst.AnimState:SetBuild("knight_nightmare")

	inst:AddTag("cavedweller")
	inst:AddTag("shadow_aligned")
end

local function nightmare_master_postinit(inst)
	inst:AddComponent("acidinfusible")
	inst.components.acidinfusible:SetFXLevel(2)
	inst.components.acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.WEAKER)

	inst.kind = "_nightmare"
	inst.components.lootdropper:SetChanceLootTable("knight_nightmare")

	clockwork_common.InitHomePosition(inst)
	clockwork_common.MakeBefriendable(inst)
end

--------------------------------------------------------------------------

local HORSEMEN =
{
    CONQUEST =
    {
        name = STRINGS.NAMES.KNIGHT_YOTH_CONQUEST,
        overridebuild = "knight_yoth_conquest_build",
    },
    WAR =
    {
        name = STRINGS.NAMES.KNIGHT_YOTH_WAR,
        -- overridebuild = "", -- Default build is already WAR
    },
    FAMINE =
    {
        name = STRINGS.NAMES.KNIGHT_YOTH_FAMINE,
        overridebuild = "knight_yoth_famine_build",
    },
    DEATH =
    {
        name = STRINGS.NAMES.KNIGHT_YOTH_DEATH,
        overridebuild = "knight_yoth_death_build",
    },
}

local function YOTH_SetHorsemanOfTheAporkalypse(inst, type) -- Teehee!
    assert(HORSEMEN[type])
    inst.horseman_type = type

    local data = HORSEMEN[type]

    if data.name then
        inst.components.named:SetName(data.name)
    end

    if data.overridebuild then
        inst.AnimState:AddOverrideBuild(data.overridebuild)
    end
end

local function YOTH_GetStatus(inst, viewer)
    local leader = inst.components.follower and inst.components.follower:GetLeader()
    return ((leader == viewer) and "FOLLOWING")
        or (leader and "FOLLOWING_OTHER")
        or nil
end

local function YOTH_LootSetupFn(lootdropper)
    local inst = lootdropper.inst
    local is_last_horseman = not inst.fled

    if is_last_horseman then
        for i = 1, #YOTH_HORSE_NAMES do
            local knight = inst.components.entitytracker:GetEntity(YOTH_HORSE_NAMES[i])
            if knight ~= nil and not knight.components.health:IsDead() then
                is_last_horseman = false
                break
            end
        end
    end

    -- My brethren are all but gone...
    if is_last_horseman then
        lootdropper:AddChanceLoot("yoth_knighthat", 1.0)
        lootdropper:AddChanceLoot("armor_yoth_knight", 1.0)
        -- Mark the others as fled to prevent duplicate drops when two or more die at the same time.
        for i = 1, #YOTH_HORSE_NAMES do
            local ent = inst.components.entitytracker:GetEntity(YOTH_HORSE_NAMES[i])
            if ent then
                ent.fled = true
            end
        end
    end
end

local function YOTH_OnLootPrefabSpawned(inst, data)
    local loot = data ~= nil and data.loot
    if loot then
        if loot.prefab == "redpouch_yoth" and loot.components.unwrappable then
            local items = {
                SpawnPrefab("lucky_goldnugget"), SpawnPrefab("lucky_goldnugget"),
                SpawnPrefab("lucky_goldnugget"), SpawnPrefab("lucky_goldnugget"),
            }

            loot.components.unwrappable:WrapItems(items)

            for k, item in pairs(items) do
                item:Remove()
            end
            items = nil
        end
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
local function YOTH_OffsetFromFn(inst, x, y, z)
    if not inst.friendly then
        local pos = Vector3(x, y, z)
        for r = 6, 12, 2 do
            local offset = FindWalkableOffset(pos, math.random() * TWOPI, r, 12, false, false, NoHoles)
            if offset then
                return offset.x, offset.y, offset.z
            end
        end
    end
    return 0, 0, 0
end

local function YOTH_MakeFriendly(inst)
    inst.friendly = true
    inst.alwayshostile = nil
    inst:RemoveTag("alwayshostile")
    inst:RemoveTag("hostile")
    if inst.makehostiletask then
        inst.makehostiletask:Cancel()
        inst.makehostiletask = nil
    end
    inst.OnEntityWake = nil
    inst.OnEntitySleep = nil
end

local function YOTH_TryToRemoveGroup(inst)
    if not inst.components.entitytracker then
        inst:Remove()
        return
    end

    local isgroupsleeping = true
    for i = 1, #YOTH_HORSE_NAMES do
        local ent = inst.components.entitytracker:GetEntity(YOTH_HORSE_NAMES[i])
        if ent and not ent:IsAsleep() then
            isgroupsleeping = false
            break
        end
    end
    if isgroupsleeping then
        for i = 1, #YOTH_HORSE_NAMES do
            local ent = inst.components.entitytracker:GetEntity(YOTH_HORSE_NAMES[i])
            if ent then
                ent:Remove()
            end
        end
        inst:Remove()
    end
end

local function YOTH_MakeEntityRemoveOnSleep(inst)
    if inst.makehostiletask then
        inst.makehostiletask:Cancel()
        inst.makehostiletask = nil
    end
    inst.OnEntityWake = nil
    inst.OnEntitySleep = YOTH_TryToRemoveGroup
    if inst:IsAsleep() then
        YOTH_TryToRemoveGroup(inst)
    end
end

local function YOTH_MakeHostile(inst, fromload)
    inst.friendly = nil
    inst.alwayshostile = true
    inst:AddTag("alwayshostile")
    inst:AddTag("hostile")
    if fromload then
        inst.makehostiletask = inst:DoTaskInTime(5 * 60, YOTH_MakeEntityRemoveOnSleep)
        inst.OnEntityWake = YOTH_MakeEntityRemoveOnSleep
    else
        -- This is for a special case with the player loading with a hat it must delay setting the OnEntitySleep because of the player load save load cycle.
        -- Otherwise the player loads the equipped hat which spawns the hostile by default knights and the entity sleeps and deletes itself before the hat can save.
        inst.makehostiletask = inst:DoTaskInTime(0, YOTH_MakeEntityRemoveOnSleep)
        inst.OnEntityWake = YOTH_MakeEntityRemoveOnSleep
    end
end

local function YOTH_GetGroupTarget(inst)
    if inst.components.entitytracker then
        local radius = TUNING.YOTH_KNIGHT_FLEE_RADIUS
        local radius_sq = radius * radius
        for i = 1, #YOTH_HORSE_NAMES do
            local ent = inst.components.entitytracker:GetEntity(YOTH_HORSE_NAMES[i])
            if ent then
                if ent.components.combat then
                    local target = ent.components.combat.target
                    if target and target:IsValid() then
                        if ent:GetDistanceSqToInst(target) < radius_sq then
                            return target
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function YOTH_TryToEngageCombatWithGroup(inst)
    local target = inst:GetGroupTarget()
    if target then
        if inst.components.combat then
            inst.components.combat:SuggestTarget(target)
            return true
        end
    end
    return false
end

local function YOTH_ExtraFilterFn(inst, guy)
    if EntityHasSetBonus(guy, EQUIPMENTSETNAMES.YOTH_PRINCESS) then
        return false
    end
    return nil -- Continue default targeting.
end

local function YOTH_Retarget(inst)
    local target = inst:GetGroupTarget()
    if target then
        return target
    end

    return clockwork_common.Retarget(inst, TUNING.YOTH_KNIGHT_TARGET_DIST, YOTH_ExtraFilterFn)
end

local function YOTH_KeepTarget(inst, target)
    local grouptarget = inst:GetGroupTarget()
    if grouptarget == target then
        return true
	elseif not inst._targetwasally and clockwork_common.IsAlly(inst, target) then
		return false
	end
	return target:IsNear(inst, TUNING.YOTH_KNIGHT_FLEE_RADIUS)
end

local function YOTH_GetDamageTakenMultiplier(inst, attacker, weapon)
    return attacker.isplayer and TUNING.YOTH_KNIGHT_DAMAGE_TAKEN_MULT_PLAYER
        or TUNING.YOTH_KNIGHT_DAMAGE_TAKEN_MULT
end

local function YOTH_OnSave(inst, data)
    data.horseman_type = inst.horseman_type
    data.friendly = inst.friendly
end

local function YOTH_OnLoad(inst, data)
    if data ~= nil then
        if data.horseman_type then
            inst:SetHorsemanOfTheAporkalypse(data.horseman_type)
        end
        if not data.friendly then
            inst:MakeHostile(true)
        else
            inst:MakeFriendly()
        end
    end
end

--V2C: ?HACK? we're letting clients control LANCE_L/R layer visibility based on local facing.
--     A forest only server would network these layers (which we do not want), so we'll use a
--     netvar to let us know when to re-override it locally.
local function YOTH_PostUpdateFacing(inst)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_LEFT or facing == FACING_UPLEFT or facing == FACING_DOWNLEFT then
		if not inst.lanceflip:value() then
			if TheWorld.ismastersim then
				inst.lanceflip:set(true)
			else
				inst.lanceflip:set_local(true)
			end
			inst.AnimState:Show("LANCE_L")
			inst.AnimState:Hide("LANCE_R")
		end
	elseif inst.lanceflip:value() then
		if TheWorld.ismastersim then
			inst.lanceflip:set(false)
		else
			inst.lanceflip:set_local(false)
		end
		inst.AnimState:Show("LANCE_R")
		inst.AnimState:Hide("LANCE_L")
	end
end

local function YOTH_StartTrackingFacing(inst)
	if not inst._trackingfacing then
		inst._trackingfacing = true
		inst.components.updatelooper:AddPostUpdateFn(YOTH_PostUpdateFacing)
	end
end

local function YOTH_StopTrackingFacing(inst)
	if inst._trackingfacing then
		inst._trackingfacing = nil
		inst.components.updatelooper:RemovePostUpdateFn(YOTH_PostUpdateFacing)
	end
end

local function YOTH_OnAttacked(inst, data)
    if data and data.attacker then
        local leader = inst.components.follower:GetLeader()
        if leader == data.attacker then
            local hat = inst.components.follower.leader -- Getting leader directly special case.
            if hat and hat.TryToMakeKnightsHostile then
                hat:TryToMakeKnightsHostile()
            end
        end
    end
end

--------------------------------------------------------------------------

local function YOTH_PushMusic(inst)
    if ThePlayer == nil or not inst:HasTag("hostile") then
        inst._playingmusic = false
    elseif ThePlayer:IsNear(inst, inst._playingmusic and 25 or 15) then
        inst._playingmusic = true
        ThePlayer:PushEvent("triggeredevent", { name = "knight_yoth" })
    elseif inst._playingmusic and not ThePlayer:IsNear(inst, 30) then
        inst._playingmusic = false
    end
end

--------------------------------------------------------------------------

local function YOTH_common_postinit(inst)
	inst.AnimState:SetBuild("knight_yoth_build")

	inst:AddTag("gilded_knight")

	--Sneak these into pristine state for optimization
	inst:AddTag("_named")

	inst.lanceflip = net_bool(inst.GUID, "kngiht_yoth.lanceflip")
	inst.AnimState:Hide("LANCE_L")

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("entitysleep", YOTH_StopTrackingFacing)
		inst:ListenForEvent("entitywake", YOTH_StartTrackingFacing)
        --Dedicated server does not need to trigger music
        inst._playingmusic = false
        inst:DoPeriodicTask(1, YOTH_PushMusic)
	end
end

local function YOTH_master_postinit(inst)
    --Remove these tags so that they can be added properly when replicating components below
    inst:RemoveTag("_named")

    inst.no_spawn_fx = true
	inst.kind = "_gilded"

    inst.components.inspectable.getstatus = YOTH_GetStatus

    inst.components.lootdropper:SetLootSetupFn(YOTH_LootSetupFn)

    inst:AddComponent("named")
    inst:AddComponent("entitytracker")

    inst.components.lootdropper:SetChanceLootTable("knight_gilded")

    inst.components.locomotor.walkspeed = TUNING.YOTH_KNIGHT_WALK_SPEED

    inst.components.health:SetMaxHealth(TUNING.YOTH_KNIGHT_HEALTH)
	clockwork_common.MakeHealthRegen(inst)

    inst.components.combat:SetRetargetFunction(3, YOTH_Retarget)
    inst.components.combat:SetKeepTargetFunction(YOTH_KeepTarget)
    inst.components.combat:SetAttackPeriod(TUNING.YOTH_KNIGHT_ATTACK_PERIOD)
    inst.components.combat:SetDefaultDamage(TUNING.YOTH_KNIGHT_DAMAGE)
    inst.components.combat:AddConditionExternalDamageTakenMultiplier(YOTH_GetDamageTakenMultiplier)

	-- For petleash ownership.
	inst.components.follower.keepdeadleader = true
	inst.components.follower:KeepLeaderOnAttacked()
	inst.components.follower.keepleaderduringminigame = true
	inst.components.follower.neverexpire = true

	inst:AddComponent("migrationpetsoverrider")
	inst.components.migrationpetsoverrider:SetOffsetFromFn(YOTH_OffsetFromFn)

    inst:ListenForEvent("loot_prefab_spawned", YOTH_OnLootPrefabSpawned)
    inst.SetHorsemanOfTheAporkalypse = YOTH_SetHorsemanOfTheAporkalypse -- Teehee!

    inst:ListenForEvent("attacked", YOTH_OnAttacked)

    inst:ListenForEvent("ms_register_yoth_princess", function(_world, data)
        if data and data.owner and data.hat then
            if inst.components.combat and inst.components.combat:TargetIs(data.owner) then
                inst.components.combat:DropTarget()
            end
        end
    end, TheWorld)

	inst.canjoust = true

    inst.MakeFriendly = YOTH_MakeFriendly
    inst.MakeHostile = YOTH_MakeHostile
    inst.GetGroupTarget = YOTH_GetGroupTarget
    inst.TryToEngageCombatWithGroup = YOTH_TryToEngageCombatWithGroup
    inst.OnSave = YOTH_OnSave
    inst.OnLoad = YOTH_OnLoad

    inst:MakeHostile()
end

--------------------------------------------------------------------------

local function onruinsrespawn(inst, respawner)
	if not respawner:IsAsleep() then
		inst.sg:GoToState("ruinsrespawn")
	end
end

return MakeKnight("knight", normal_common_postinit, normal_master_postinit, assets, prefabs),
	MakeKnight("knight_nightmare", nightmare_common_postinit, nightmare_master_postinit, assets_nightmare, prefabs_nightmare),
	MakeKnight("knight_yoth", YOTH_common_postinit, YOTH_master_postinit, assets_yoth, prefabs_yoth),
    RuinsRespawner.Inst("knight_nightmare", onruinsrespawn), RuinsRespawner.WorldGen("knight_nightmare", onruinsrespawn)
