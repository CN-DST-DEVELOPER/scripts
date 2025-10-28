local assets =
{
    Asset("ANIM", "anim/tree_rock_short.zip"),
    Asset("ANIM", "anim/tree_rock_normal.zip"),

    Asset("ANIM", "anim/tree_rock2_short.zip"),
    Asset("ANIM", "anim/tree_rock2_normal.zip"),

    Asset("MINIMAP_IMAGE", "tree_rock"),

    Asset("SCRIPT", "scripts/prefabs/tree_rock_data.lua"),

    Asset("SOUND", "sound/rifts6.fsb"),
    -- Asset("MINIMAP_IMAGE", "tree_rock_normal"),
}

local prefabs =
{
    "rocks",
    "nitre",
    "flint",
    "goldnugget",
    "moonrocknugget",
    "moonglass",
    "rock_break_fx",
    "tree_rock_chop",
    "tree_rock_fall",
    "collapse_small",
    "tree_rock_seed",

	--halloween
	"spooked_spider_rock_fx",
}

SetSharedLootTable( 'tree_rock1_chop',
{
    {'twigs',  1.00},
})

SetSharedLootTable( 'tree_rock1_mine',
{
    {'rocks',  1.00},
    {'rocks',  1.00},
    {'rocks',  1.00},
    {'nitre',  1.00},
    {'flint',  1.00},
    {'nitre',  0.25},
    {'flint',  0.60},
    --
    {'tree_rock_seed', 1.00},
})

SetSharedLootTable( 'tree_rock1_mine_break',
{
    {'rocks',  1.00},
    {'rocks',  0.50},
    {'rocks',  0.50},
    {'nitre',  0.25},
    {'flint',  1.00},
    {'nitre',  0.10},
    {'flint',  0.20},
    --
    {'tree_rock_seed', 1.00},
})

local NUM_VINE_LOOT = 5

local TREE_ROCK_DATA = require("prefabs/tree_rock_data")
local WEIGHTED_VINE_LOOT = TREE_ROCK_DATA.WEIGHTED_VINE_LOOT
local VINE_LOOT_DATA = TREE_ROCK_DATA.VINE_LOOT_DATA
local TASKS_TO_LOOT_KEY = TREE_ROCK_DATA.TASKS_TO_LOOT_KEY
local ROOMS_TO_LOOT_KEY = TREE_ROCK_DATA.ROOMS_TO_LOOT_KEY
local STATIC_LAYOUTS_TO_LOOT_KEY = TREE_ROCK_DATA.STATIC_LAYOUTS_TO_LOOT_KEY
local EXTRA_LOOT_MODIFIERS = TREE_ROCK_DATA.EXTRA_LOOT_MODIFIERS
local CheckModifyLootArea = TREE_ROCK_DATA.CheckModifyLootArea
TREE_ROCK_DATA = nil

local function GetLootKey(id)
    local gen_data = ConvertTopologyIdToData(id)
    local loot_key

    if gen_data.layout_id and STATIC_LAYOUTS_TO_LOOT_KEY[gen_data.layout_id] then
        loot_key = STATIC_LAYOUTS_TO_LOOT_KEY[gen_data.layout_id]
    elseif gen_data.room_id and ROOMS_TO_LOOT_KEY[gen_data.room_id] then
        loot_key = ROOMS_TO_LOOT_KEY[gen_data.room_id]
    elseif gen_data.task_id and TASKS_TO_LOOT_KEY[gen_data.task_id] then
        loot_key = TASKS_TO_LOOT_KEY[gen_data.task_id]
    end

    return CheckModifyLootArea(loot_key)
end

local function CountWeightedTotal(choices)
    local total = 0
    for _, weight in pairs(choices) do
        total = total + weight
    end
    return total
end

local function GetLootWeightedTable(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local id, index = TheWorld.Map:GetTopologyIDAtPoint(x, y, z) -- NOTE: This doesn't account for overhang, but that's OK because we can't be planted close to shore anyways.
    if id then
        local loot_key = GetLootKey(id)

        if loot_key then
            local weighted_table = WEIGHTED_VINE_LOOT[loot_key]
            local weighted_total = CountWeightedTotal(weighted_table)
            --
            for id, data in pairs(EXTRA_LOOT_MODIFIERS) do
                if data.test_fn(inst) then
                    local EXTRA_LOOT = FunctionOrValue(data.loot, inst, weighted_total)
                    weighted_table = MergeMapsAdditively(weighted_table, EXTRA_LOOT)
                end
            end
            --
            return weighted_table
        end
    end

    return WEIGHTED_VINE_LOOT.DEFAULT
end

local function GetVineLoots(inst)
    return weighted_random_choices(GetLootWeightedTable(inst), NUM_VINE_LOOT)
end

local function SetupVineLoot(inst, loots)
    if inst.vine_loot or inst:HasTag("boulder") then
        return
    end
    --
    inst.vine_loot = loots or GetVineLoots(inst)
    --
    for i = 1, NUM_VINE_LOOT do
        local data = VINE_LOOT_DATA[inst.vine_loot[i]]

        if inst.vine_loot[i] == "EMPTY" then
            inst.AnimState:Hide("gem_vine_"..i)
        else
            local build, symbol = data.build, (#data.symbols == 0 and data.symbols[1]) or data.symbols[math.random(#data.symbols)]
            inst.AnimState:OverrideSymbol("swap_gem_"..i, build, symbol)
        end
    end
end

local function ClearVineLoot(inst)
    inst.vine_loot = nil
end

local builds =
{
    rock1 = {
        build = "tree_rock_normal",
        bank = "tree_rock",
        prefab_name="tree_rock1",
        grow_times=TUNING.TREE_ROCK.GROW_TIME,

        regrowth_product="tree_rock_sapling",
        regrowth_tuning=TUNING.TREE_ROCK_REGROWTH,

        drop_damage_range = TUNING.TREE_ROCK.ROCK1_AOE_RADIUS,
        drop_damage = TUNING.TREE_ROCK.ROCK1_AOE_DAMAGE,
    },
    rock2 = {
        build = "tree_rock_normal",
        bank = "tree_rock2",
        prefab_name = "tree_rock2",
        grow_times=TUNING.TREE_ROCK.GROW_TIME,

        regrowth_product="tree_rock_sapling",
        regrowth_tuning=TUNING.TREE_ROCK_REGROWTH,

        drop_damage_range = TUNING.TREE_ROCK.ROCK2_AOE_RADIUS,
        drop_damage = TUNING.TREE_ROCK.ROCK2_AOE_DAMAGE,
    }
}

local function DropRockCamShake(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, .20, .05,
        inst.components.growable ~= nil and
        inst.components.growable.stage > 2 and 1.0 or .5,
        inst, 20)
end

local function BounceRockCamShake(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, .05, .025,
        inst.components.growable ~= nil and
        inst.components.growable.stage > 2 and 1.0 or .5,
        inst, 20)
end

local function BreakRockCamShake(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, .30, .1,
        inst.components.growable ~= nil and
        inst.components.growable.stage > 2 and 1.0 or .5,
        inst, 20)
end

local function PlaySwaySound(inst)
    if inst.AnimState:IsCurrentAnimation(inst.anims.sway1) then
        inst.SoundEmitter:PlaySound("rifts6/rock_tree/sway_normal")
    end
end

local SWAY1_TIME = 15 * FRAMES
local SWAY2_TIME = 45 * FRAMES
local function ResetSwaySoundTasks(inst)
    if inst.sway1_sound_task then
        inst.sway1_sound_task:Cancel()
        inst.sway2_sound_task:Cancel()
        inst.sway1_sound_task = nil
        inst.sway2_sound_task = nil
    end
    if inst.AnimState:IsCurrentAnimation(inst.anims.sway1) then
        inst.sway1_sound_task = inst:DoTaskInTime(SWAY1_TIME, PlaySwaySound)
        inst.sway2_sound_task = inst:DoTaskInTime(SWAY2_TIME, PlaySwaySound)
        inst.AnimState:PlayAnimation(inst.anims.sway1)
    else
        inst:RemoveEventCallback("animqueueover", ResetSwaySoundTasks)
        inst:RemoveEventCallback("animover", ResetSwaySoundTasks)
    end
end

local function PushSway(inst)
    inst.AnimState:PushAnimation(inst.anims.sway1, true)
    --inst:ListenForEvent("animqueueover", ResetSwaySoundTasks)
end

local function Sway(inst)
    inst.AnimState:PlayAnimation(inst.anims.sway1, true)
    --inst:ListenForEvent("animover", ResetSwaySoundTasks)

    -- Because growable stage is set in growable component so we can't do this in constructor
    if POPULATING then
        inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
    end
end

local function makeanims(stage)
    return {
        idle="idle_"..stage,
        sway1="sway1_loop_"..stage,
        --sway2="sway2_loop_"..stage,
        chop="chop_"..stage,
        fallleft="fallleft_"..stage,
        fallright="fallright_"..stage,
        stump="stump_"..stage,
        burning="burning_loop_"..stage,
        burnt="burnt_"..stage,
        chop_burnt="chop_burnt_"..stage,
        idle_chop_burnt="idle_chop_burnt_"..stage,
        --
        fall_pre="fall_pre_"..stage,
        fall_miss="fall_miss_"..stage,
        fall_pst="fall_pst_"..stage,

        fall_break = "fall_break_"..stage,
        fall_bounce = "fall_bounce_"..stage,

        fall_pre_burnt = "fall_pre_burnt_"..stage,
        fall_miss_burnt = "fall_miss_burnt_"..stage,
        fall_pst_burnt = "fall_pst_burnt_"..stage,

        fall_break_burnt = "fall_break_burnt_"..stage,
        fall_bounce_burnt = "fall_bounce_burnt_"..stage,

        fall_full="fall_full_"..stage,
        fall_med="fall_med_"..stage,
        fall_low="fall_low_"..stage,

        burnt_full="burnt_full_"..stage,
        burnt_med="burnt_med_"..stage,
        burnt_low="burnt_low_"..stage,

        burnt_fall_idle="burnt_fall_idle_"..stage,
    }
end

local short_anims = makeanims("short")
local normal_anims = makeanims("normal")
local tall_anims = makeanims("tall")

local function SetShort(inst)
    inst.anims = short_anims

    SetLunarHailBuildupAmountSmall(inst)

    --inst.components.lootdropper:SetLoot(GetBuild(inst).short_loot)

    Sway(inst)
end

local function GrowShort(inst)
    --inst.AnimState:PlayAnimation("grow_old_to_short")
    inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrowFromWilt")
    PushSway(inst)
end

local function SetNormal(inst)
    inst.anims = normal_anims

    SetLunarHailBuildupAmountMedium(inst)

    --inst.components.lootdropper:SetLoot(GetBuild(inst).normal_loot)

    Sway(inst)
end

local function GrowNormal(inst)
    inst.AnimState:PlayAnimation("grow_short_to_normal")
    inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
    PushSway(inst)
end

local growth_stages = {}
for build, data in pairs(builds) do
    growth_stages[build] =
    {
        {
            name = "short",
            time = function(inst) return GetRandomWithVariance(data.grow_times[1].base, data.grow_times[1].random) end,
            fn = SetShort,
            growfn = GrowShort,
        },
        {
            name = "normal",
            time = function(inst) return GetRandomWithVariance(data.grow_times[2].base, data.grow_times[2].random) end,
            fn = SetNormal,
            growfn = GrowNormal,
        },
        --[[
        {
            name = "tall",
            time = function(inst) return GetRandomWithVariance(data.grow_times[3].base, data.grow_times[3].random) end,
            fn = SetTall,
            growfn = GrowTall,
            leifscale = 1.25,
        },
        {
            name = "old",
            time = function(inst) return GetRandomWithVariance(data.grow_times[4].base, data.grow_times[4].random) end,
            fn = SetOld,
            growfn = GrowOld,
        },
        ]]
    }
end

local function GetGrowthStages(inst)
    return growth_stages[inst.build] or growth_stages["rock1"]
end

local function GetBuild(inst)
    return builds[inst.build] or builds["rock1"]
end

local function PlayRockAnimation(inst, minesleft)
    --All trees use same mine animations
	local anim
    if inst:HasTag("burnt") then
		anim =
            (minesleft < TUNING.TREE_ROCK.MINE / 3 and "burnt_low_normal") or
            (minesleft < TUNING.TREE_ROCK.MINE * 2 / 3 and "burnt_med_normal") or
            "burnt_full_normal"
    else
		anim =
            (minesleft < TUNING.TREE_ROCK.MINE / 3 and "fall_low_normal") or
            (minesleft < TUNING.TREE_ROCK.MINE * 2 / 3 and "fall_med_normal") or
            "fall_full_normal"
    end
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim)
		return anim
	end
end

local function PushRockAnimation(inst, minesleft)
    --All trees use same mine animations
    if inst:HasTag("burnt") then
        inst.AnimState:PushAnimation(
            (minesleft < TUNING.TREE_ROCK.MINE / 3 and "burnt_low_normal") or
            (minesleft < TUNING.TREE_ROCK.MINE * 2 / 3 and "burnt_med_normal") or
            "burnt_full_normal"
        )
    else
        inst.AnimState:PushAnimation(
            (minesleft < TUNING.TREE_ROCK.MINE / 3 and "fall_low_normal") or
            (minesleft < TUNING.TREE_ROCK.MINE * 2 / 3 and "fall_med_normal") or
            "fall_full_normal"
        )
    end
end

local function OnMine(inst, miner, minesleft, nummines)
    if minesleft <= 0 then
        local pt = inst:GetPosition()
        SpawnPrefab("rock_break_fx").Transform:SetPosition(pt.x, pt.y, pt.z)
        inst.components.lootdropper:DropLoot(pt)
        inst:Remove()
    else
        --All trees use same mine animations
		local anim = PlayRockAnimation(inst, minesleft)

		if anim and --nil if no change
			--IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) and
			miner.components.spooked and
			anim ~= "burnt_full_normal" and
			anim ~= "fall_full_normal"
		then
			--higher chance on initial break
			local spookmult = (anim == "burnt_med_normal" or anim == "fall_med_normal") and TUNING.MINE_SPOOKED_MULT_HIGH or TUNING.MINE_SPOOKED_MULT_LOW
			miner.components.spooked:TryCustomSpook(inst, "spooked_spider_rock_fx", spookmult)
		end
    end
end

local function OnWorkableLoadFn(inst, data)
    PlayRockAnimation(inst, data.workleft)
end

local function MakeRock(inst, no_change_physics)
    if inst.components.burnable ~= nil then
        inst.components.burnable:Extinguish()
    end
    inst:RemoveComponent("burnable")
    inst:RemoveComponent("propagator")
    inst:RemoveComponent("workable")
    inst:RemoveTag("shelter")
    inst:RemoveComponent("hauntable")
    MakeHauntableWork(inst)

    if not no_change_physics then
        RemovePhysicsColliders(inst)
        ChangeToObstaclePhysics(inst, 1)
    end

    inst:AddTag("boulder")
    inst:RemoveTag("tree")

    if inst.components.growable ~= nil then
        inst.components.growable:StopGrowing()
    end

    inst.components.lootdropper:SetChanceLootTable("tree_rock1_mine")

    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.MINE)
    workable:SetOnWorkCallback(OnMine)
    workable:SetWorkLeft(TUNING.TREE_ROCK.MINE)
    workable.savestate = true
    --workable:SetOnLoadFn(OnWorkableLoadFn) --Handled in our OnLoad
end

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUST_HAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local function GetAffectedEntities(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local build_data = GetBuild(inst)
    local range = build_data.drop_damage_range
    local ents = TheSim:FindEntities(x, y, z, range + AOE_RANGE_PADDING, AOE_TARGET_MUST_HAVE_TAGS, AOE_TARGET_CANT_TAGS)
    local affected_ents = {}
    --
    for i, v in ipairs(ents) do
        if v ~= inst and
		    v:IsValid() and not v:IsInLimbo()
		    and not IsEntityDead(v)
	    then
            local range1 = range + v:GetPhysicsRadius(0)
            if v:GetDistanceSqToPoint(x, y, z) < range1 * range1 then
                table.insert(affected_ents, v)
            end
        end
    end
    --
    return affected_ents
end

local function CalcDamagePlayerMultiplier(damage, target)
    return (target ~= nil and (target.isplayer or target:HasTag("player_damagescale"))) and damage * TUNING.TREE_ROCK.PLAYERDAMAGEPERCENT
        or damage
end

local function OnRockFall(inst)
    if
        inst.AnimState:IsCurrentAnimation(inst.anims.fall_miss) or
        inst.AnimState:IsCurrentAnimation(inst.anims.fall_miss_burnt) or
        inst.AnimState:IsCurrentAnimation(inst.anims.fall_bounce_burnt) or
        inst.AnimState:IsCurrentAnimation(inst.anims.fall_bounce)
    then
        DropRockCamShake(inst)

        local build_data = GetBuild(inst)
        local damage = build_data.drop_damage
        for i, v in ipairs(GetAffectedEntities(inst)) do
            v.components.combat:GetAttacked(inst, PlayerDamageMod(v, damage, TUNING.TREE_ROCK.PLAYERDAMAGEPERCENT))
            v:PushEvent("knockback", { knocker = inst, radius = 2, strengthmult = 1, forcelanded = true })
        end
    end

    ChangeToObstaclePhysics(inst, 1)
    --inst:RemoveEventCallback("animover", OnRockFall)
end

local function HasHardHat(inst)
    local equipped_hat = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    return equipped_hat and equipped_hat:HasTag("hardarmor")
end

local function ShouldBounce(inst)
    for i, ent in ipairs(GetAffectedEntities(inst)) do
        if ent:HasTag("tree_rock_bouncer") or HasHardHat(ent) then
            return true
        end
    end
    --
    return false
end

local function ShouldBreak(inst)
    for i, ent in ipairs(GetAffectedEntities(inst)) do
        if ent:HasTag("tree_rock_breaker") then
            return true
        end
    end
    --
    return false
end

local function GetAnimationKey(inst, name)
    return inst:HasTag("burnt") and name.."_burnt" or name
end

local BOUNCE_FALL_DELAY = 11 * FRAMES
local FALL_DELAY = 4 * FRAMES
local function OnAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation(inst.anims[GetAnimationKey(inst, "fall_pre")]) then
        if ShouldBreak(inst) then
            BreakRockCamShake(inst)
            inst.AnimState:PlayAnimation(inst.anims[GetAnimationKey(inst, "fall_break")])
            inst.SoundEmitter:PlaySound("rifts6/rock_tree/fall_break")

            for i, ent in ipairs(GetAffectedEntities(inst)) do
                if ent:HasTag("tree_rock_breaker") then
                    ent:PushEvent("broke_tree_rock", { tree_rock = inst })
                end
            end
            --
            inst.components.lootdropper:SetChanceLootTable("tree_rock1_mine_break")
            inst.components.lootdropper:DropLoot(inst:GetPosition())
            --
            inst.persists = false
            inst:ListenForEvent("animover", inst.Remove)
        elseif ShouldBounce(inst) then
            BounceRockCamShake(inst)
            inst.AnimState:PlayAnimation(inst.anims[GetAnimationKey(inst, "fall_bounce")])
            inst.SoundEmitter:PlaySound("rifts6/rock_tree/fall_bounce")
            inst:DoTaskInTime(BOUNCE_FALL_DELAY, OnRockFall)
        else -- keep falling
            inst.AnimState:PlayAnimation(inst.anims[GetAnimationKey(inst, "fall_miss")])
            inst:DoTaskInTime(FALL_DELAY, OnRockFall)
        end

        inst.AnimState:PushAnimation(inst.anims[GetAnimationKey(inst, "fall_pst")])
        PushRockAnimation(inst, inst.components.workable.workleft)
    end

    inst:RemoveEventCallback("animover", OnAnimOver)
end

local function OnBurnt(inst, immediate)
    inst:AddTag("burnt")

    if immediate then
        -- Bit of a hack.
        local _workleft = inst.components.workable.workleft
        MakeRock(inst)
        inst.components.workable.workleft = _workleft
        PlayRockAnimation(inst, inst.components.workable.workleft)
    else
        inst.SoundEmitter:PlaySound("rifts6/rock_tree/fall_pre")
        inst.AnimState:PlayAnimation(inst.anims.fall_pre_burnt)

        inst:ListenForEvent("animover", OnAnimOver)

        inst:DoTaskInTime(.5, MakeRock)
    end
end

local function WakeUpLeif(ent)
    ent.components.sleeper:WakeUp()
end

local LEIF_TAGS = { "leif" }
local function OnChop(inst, chopper, chopsleft, numchops)
    if not (chopper ~= nil and chopper:HasTag("playerghost")) then
        inst.SoundEmitter:PlaySound("rifts6/rock_tree/chop_normal")
    end

    inst.AnimState:PlayAnimation(inst.anims.chop)
    PushSway(inst)

    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("tree_rock_chop").Transform:SetPosition(x, y + math.random() * 1, z)

    --tell any nearby leifs to wake up
    local ents = TheSim:FindEntities(x, y, z, TUNING.LEIF_REAWAKEN_RADIUS, LEIF_TAGS)
    for i, v in ipairs(ents) do
        if v.components.sleeper ~= nil and v.components.sleeper:IsAsleep() then
            v:DoTaskInTime(math.random(), WakeUpLeif)
        end
        v.components.combat:SuggestTarget(chopper)
    end
end

local function SpawnVineLoot(inst)
    inst.components.lootdropper.min_speed = 2
    inst.components.lootdropper.max_speed = 4
    --
    if inst.vine_loot then
        for i = 1, NUM_VINE_LOOT do
            if inst.vine_loot[i] ~= "EMPTY" then
                inst.components.lootdropper:SpawnLootPrefab(inst.vine_loot[i])
            end
        end
    end
    --
    ClearVineLoot(inst) --Not necessacary but saves on save data
    --These will default to values in lootdropper do not worry about setting to nil.
    inst.components.lootdropper.min_speed = nil
    inst.components.lootdropper.max_speed = nil
end

local function OnChopDown(inst, chopper)
    --RemovePhysicsColliders(inst)
    inst.SoundEmitter:PlaySound("rifts6/rock_tree/fall_pre")

    inst.AnimState:PlayAnimation(inst.anims.fall_pre)
    inst:ListenForEvent("animover", OnAnimOver)

    --inst.AnimState:PushAnimation(inst.anims.fall_miss)
    --inst.AnimState:PushAnimation(inst.anims.fall_pst)
    inst.components.lootdropper:DropLoot(inst:GetPosition())

    SpawnVineLoot(inst)

    --inst:DoTaskInTime(12 * FRAMES, OnRockFall)

    --RemovePhysicsColliders(inst)
    MakeRock(inst, true)
end

--[[
Note that save data is set for rock trees in natural generation in prefabdata tables for VentsRoom rooms.
]]
local function OnSave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end

    if inst:HasTag("boulder") then
        data.boulder = true
    end

    if inst.vine_loot then
        data.vine_loot = inst.vine_loot
    end
end

local function OnLoad(inst, data)
    if not data then
        return
    end

    -- These are essentially kinda the same state, burnt and boulder
    if data.burnt and not inst:HasTag("burnt") then
        OnBurnt(inst, true)
    elseif data.boulder then
        -- Bit of a hack.
        local _workleft = inst.components.workable.workleft
        MakeRock(inst)
        inst.components.workable.workleft = _workleft
        PlayRockAnimation(inst, inst.components.workable.workleft)
    elseif data.vine_loot then
        SetupVineLoot(inst, data.vine_loot)
    end
end

local function GetStatus(inst)
    return (inst:HasTag("boulder") and "CHOPPED")
        or nil
end

local function handler_growfromseed(inst)
    inst.components.growable:SetStage(1)
    inst.AnimState:PlayAnimation("grow_seed_to_short")
    inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
    PushSway(inst)
end

local function MakeRockTree(name, build, stage)

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        MakeObstaclePhysics(inst, 0.25)

        inst.MiniMapEntity:SetIcon("tree_rock.png")

        inst.build = build or GetRandomKey(builds)

        inst.AnimState:SetBuild(GetBuild(inst).build)
        inst.AnimState:SetBank(GetBuild(inst).bank)

        inst:SetPrefabName(GetBuild(inst).prefab_name)
        inst:SetPrefabNameOverride("tree_rock")
        inst:AddTag(GetBuild(inst).prefab_name) -- used by regrowth

        MakeSnowCoveredPristine(inst)

        inst:AddTag("tree")
        inst:AddTag("rock_tree")
        inst:AddTag("shelter")
        inst:AddTag("nodangermusic")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        -- NOTE(DiogoW): Only use dependencies generated by lootdroper.
        inst.scrapbook_deps = {}

        local lootdropper = inst:AddComponent("lootdropper")
        lootdropper:SetChanceLootTable('tree_rock1_chop')

        local workable = inst:AddComponent("workable")
        workable:SetWorkAction(ACTIONS.CHOP)
        workable:SetWorkLeft(TUNING.TREE_ROCK.CHOP)
        workable:SetOnWorkCallback(OnChop)
        workable:SetOnFinishCallback(OnChopDown)

        local growable = inst:AddComponent("growable")
        growable.stages = GetGrowthStages(inst)
        growable:SetStage(stage or math.random(1, 2))
        growable.loopstages = false --TODO?
        growable.springgrowth = true
        growable.magicgrowable = true
        growable:StartGrowing()

        inst:AddComponent("plantregrowth")
        inst.components.plantregrowth:SetRegrowthRate(GetBuild(inst).regrowth_tuning.OFFSPRING_TIME)
        inst.components.plantregrowth:SetProduct(GetBuild(inst).regrowth_product)
        inst.components.plantregrowth:SetSearchTag("rock_tree")
        inst.components.plantregrowth:SetSkipCanPlantCheck(true)

        local colour = 0.5 + math.random() * 0.5
        inst.AnimState:SetSymbolMultColour("tree_rock_main", colour, colour, colour, 1)
        inst.AnimState:SetSymbolMultColour("tree_broken_rock", colour, colour, colour, 1)
        inst.AnimState:SetSymbolMultColour("tree_smallrocks", colour, colour, colour, 1)

        local inspectable = inst:AddComponent("inspectable")
        inspectable.getstatus = GetStatus

        inst.growfromseed = handler_growfromseed

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        MakeMediumBurnable(inst, TUNING.TREE_ROCK.BURN_TIME)
        inst.components.burnable:SetFXLevel(5)
        inst.components.burnable:SetOnBurntFn(OnBurnt)
        MakeSmallPropagator(inst)

        MakeSnowCovered(inst)
        SetLunarHailBuildupAmountSmall(inst)

        inst:DoTaskInTime(0, SetupVineLoot)

        MakeHauntableWork(inst)

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

return MakeRockTree("tree_rock1", "rock1"),
    MakeRockTree("tree_rock2", "rock2"),

    MakeRockTree("tree_rock1_short", "rock1", 1),
    MakeRockTree("tree_rock1_normal", "rock1", 2),

    MakeRockTree("tree_rock2_short", "rock2", 1),
    MakeRockTree("tree_rock2_normal", "rock2", 2),

    MakeRockTree("tree_rock") --Random variation

--Prefab("tree_rock1", rock1_fn, assets, prefabs)