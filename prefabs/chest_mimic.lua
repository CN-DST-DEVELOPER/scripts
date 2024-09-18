require "prefabutil"

local assets =
{
	Asset("ANIM", "anim/pandoras_chest.zip"),
	Asset("ANIM", "anim/chest_mimic.zip"),
}

local prefabs =
{
    "chest_mimic_revealed",
    "chest_mimic_ruinsspawn_tracker",
    "shadowheart_infused",
}

local CHEST_SOUNDS = {
    open  = "dontstarve/wilson/chest_open",
    close = "dontstarve/wilson/chest_close",
    built = "dontstarve/common/chest_craft",
}

local function transfer_item_to_monster_inventory(item, monster, owner)
    local item_removed_from_container = owner.components.container:RemoveItem(item, true)
    if item_removed_from_container then
        monster.components.inventory:GiveItem(item_removed_from_container)
    end
end

local function do_transform(inst, data)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local open = inst.components.container:IsOpen()

    local chest_monster = SpawnPrefab("chest_mimic_revealed")
    chest_monster.Transform:SetPosition(ix, iy, iz)

    local ruinsspawn_tracker = inst.components.entitytracker:GetEntity("ruinsspawn_tracker")
    chest_monster.components.entitytracker:TrackEntity("ruinsspawn_tracker", ruinsspawn_tracker)

    inst.components.container:ForEachItem(transfer_item_to_monster_inventory, chest_monster, inst)

    if data then
        if data.doer then
            chest_monster.components.combat:SetTarget(data.doer)
        end
    end

    chest_monster.sg:GoToState("spawn", open)

    inst:Remove()
end

local function initiate_transform(inst, data)
    if not inst._transform_task then
        inst._transform_task = inst:DoTaskInTime(2.5, do_transform, data)
    end
end

-- Container
local function onopen(inst, data)
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound(inst.sounds.open)

    initiate_transform(inst, data)
end

local function onclose(inst, doer)
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed", false)
    inst.SoundEmitter:PlaySound(inst.sounds.close)

    initiate_transform(inst, {doer = doer})
end

--
local function create_tracker_at_my_feet(inst)
    -- We might already have a tracker if we're a mimic that transformed back.
    if not inst.components.entitytracker:GetEntity("ruinsspawn_tracker") then
        local tracker = SpawnPrefab("chest_mimic_ruinsspawn_tracker")
        tracker.Transform:SetPosition(inst.Transform:GetWorldPosition())

        inst.components.entitytracker:TrackEntity("ruinsspawn_tracker", tracker)
    end
end

--
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("pandoraschest.png")

    inst.AnimState:SetBank("pandoras_chest")
    inst.AnimState:SetBuild("pandoras_chest")
    inst.AnimState:PlayAnimation("closed")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    inst.sounds = CHEST_SOUNDS

    --
    local container = inst:AddComponent("container")
    container:WidgetSetup("pandoraschest")
    container.onopenfn = onopen
    container.onclosefn = onclose
    container.skipclosesnd = true
    container.skipopensnd = true

    --
    inst:AddComponent("entitytracker")

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable:SetNameOverride("pandoraschest")

    --
    MakeSnowCovered(inst)

    --
    MakeRoseTarget_CreateFuel_IncreasedHorror(inst)

    --
    inst:DoTaskInTime(FRAMES, create_tracker_at_my_feet)

    --
    inst:ListenForEvent("resetruins", function()
        local is_asleep = inst:IsAsleep()
        local was_open = inst.components.container:IsOpen()

        -- We might want to turn back into a non-mimic chest
        local stay_mimic = TheWorld.components.shadowthrall_mimics ~= nil
                and TheWorld.components.shadowthrall_mimics.IsEnabled()
                and math.random() < TUNING.CHEST_MIMIC_CHANCE

        local ruinsspawn_tracker = inst.components.entitytracker:GetEntity("ruinsspawn_tracker")

        if not inst.components.scenariorunner then
            inst.components.container:DropEverythingWithTag("irreplaceable")
            inst.components.container:DestroyContents()
        end

        if not stay_mimic then
            inst = ReplacePrefab(inst, "pandoraschest")
        end

        if not inst.components.scenariorunner then
            inst:AddComponent("scenariorunner")
            inst.components.scenariorunner:SetScript((stay_mimic and "chest_labyrinth_mimic") or "chest_labyrinth")
            inst.components.scenariorunner:Run()
        end

        if not is_asleep then
            if not was_open then
                inst.AnimState:PlayAnimation("hit")
                inst.AnimState:PushAnimation("closed", false)
                inst.SoundEmitter:PlaySound("dontstarve/common/together/chest_retrap")
            end

            SpawnPrefab("pandorachest_reset").Transform:SetPosition(inst.Transform:GetWorldPosition())
        end

        if ruinsspawn_tracker then
            inst.Transform:SetPosition(ruinsspawn_tracker.Transform:GetWorldPosition())
            if not stay_mimic then
                ruinsspawn_tracker:Remove()
            end
        end
    end, TheWorld)

    return inst
end

-- REVEALED STATE --------------------------------------------------------------
local revealed_assets =
{
    Asset("ANIM", "anim/slurper_basic.zip"),
}

local REVEALED_SOUNDS =
{
    spawn = "rifts4/mimic/mimic_chest/spawn",
    open = "dontstarve/wilson/chest_open",
    walk_lp = "rifts4/mimic/mimic_chest/walk_lp",
    attack_munch = "rifts4/mimic/mimic_chest/attack",
    attack_hit = "dontstarve/wilson/chest_close",
    death = "rifts4/mimic/mimic_chest/death",
    taunt = "rifts4/mimic/mimic_chest/taunt",
    pickup = "rifts4/mimic/mimic_chest/eat_pre",
    chew = "rifts4/mimic/mimic_chest/eating_lp",
    eat_pst = "rifts4/mimic/mimic_chest/eat_pst",
}

SetSharedLootTable("chest_mimic",
{
    {"horrorfuel",  1.00},
    {"horrorfuel",  1.00},
    {"horrorfuel",  1.00},
    {"horrorfuel",  0.75},
    {"horrorfuel",  0.50},
    {"horrorfuel",  0.50},
    {"houndstooth", 0.50},
    {"houndstooth", 0.50},
})

local brain = require("brains/chest_mimicbrain")

-- Combat
local RETARGET_CANT_TAGS = { "chess", "chestmonster" }
local function RetargetFn(inst)
    return FindEntity(
        inst,
        TUNING.CHEST_MIMIC_TARGET_DIST,
        function(guy)
            return inst.components.combat:CanTarget(guy)
        end,
        nil,
        RETARGET_CANT_TAGS
    )
end

local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
end

local function OnHitOther(inst, other, damage, stimuli, weapon, damageresolved, spdamage, damageredirecttarget)
    if not damageredirecttarget then
        inst.components.thief:StealItem(other)
    end
end

-- Event listeners
local function OnRevealedAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)

    -- The chest doesn't eat/steal when it's angry.
    -- Punching it makes it angry for a while.
    local timer = inst.components.timer
    if timer:TimerExists("angry") then
        timer:SetTimeLeft("angry", 15)
    else
        timer:StartTimer("angry", 15)
    end
end

local function transfer_item_to_chest_container(item, monster, owner)
    local item_removed_from_inventory = monster.components.inventory:RemoveItem(item, true)
    if item_removed_from_inventory then
        owner.components.container:GiveItem(item_removed_from_inventory)
    end
end

local function TryTransformBack(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()

    local chest = SpawnPrefab("chest_mimic")
    chest.Transform:SetPosition(ix, iy, iz)

    local ruinsspawn_tracker = inst.components.entitytracker:GetEntity("ruinsspawn_tracker")
    chest.components.entitytracker:TrackEntity("ruinsspawn_tracker", ruinsspawn_tracker)

    inst.components.inventory:ForEachItem(transfer_item_to_chest_container, inst, chest)
end

local function OnRevealedDeath(inst, data)
    local ruinsspawn_tracker = inst.components.entitytracker:GetEntity("ruinsspawn_tracker")
    if ruinsspawn_tracker then
        ruinsspawn_tracker:PushEvent("mimic_died", inst)
    end
end

-- Infuse shadow heart on death if we have one.
local function find_shadowheart(item) return item.prefab == "shadowheart" end

local function loot_setup_fn(lootdropper)
    local inst = lootdropper.inst

    local shadowheart = inst.components.inventory:FindItem(find_shadowheart)
    if shadowheart then
        inst.components.inventory:RemoveItem(shadowheart, true, true, false)
        shadowheart:Remove()
        inst.components.lootdropper:SetLoot({"shadowheart_infused"})
    end
end

--
local function revealed_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, .1)

    inst.DynamicShadow:SetSize(2.5, 1.5)
    inst.Transform:SetSixFaced()

    inst:AddTag("canbestartled")
    inst:AddTag("chessfriend")
    inst:AddTag("chestmonster")
    inst:AddTag("hostile")
    inst:AddTag("monster")
    inst:AddTag("scarytooceanprey")
    inst:AddTag("scarytoprey")
    inst:AddTag("shadow_aligned")
    inst:AddTag("wooden")

    inst.AnimState:SetBank("chest_mimic")
    inst.AnimState:SetBuild("chest_mimic")
    inst.AnimState:PlayAnimation("idle1", true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    inst.sounds = REVEALED_SOUNDS

    --
    local combat = inst:AddComponent("combat")
    combat:SetDefaultDamage(TUNING.CHEST_MIMIC_DAMAGE)
    combat:SetAttackPeriod(TUNING.CHEST_MIMIC_ATTACK_PERIOD)
    combat:SetRetargetFunction(3, RetargetFn)
    combat:SetKeepTargetFunction(KeepTargetFn)
    combat.lastwasattackedtime = -math.huge --for brain
    combat.onhitotherfn = OnHitOther

    --
    local eater = inst:AddComponent("eater")
    eater:SetDiet({FOODGROUP.OMNI}, {FOODGROUP.OMNI})
    eater:SetCanEatHorrible()
    eater:SetStrongStomach(true) -- can eat monster meat!

    --
    inst:AddComponent("entitytracker")

    --
    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.CHEST_MIMIC_HEALTH)

    --
    inst:AddComponent("inspectable")

    --
    local inventory = inst:AddComponent("inventory")
    inventory:DisableDropOnDeath()
    inventory.maxslots = 9

    --
    inst:AddComponent("knownlocations")

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor.walkspeed = TUNING.CHEST_MIMIC_WALK_SPEED

    --
    local lootdropper = inst:AddComponent("lootdropper")
    lootdropper:SetChanceLootTable("chest_mimic")
    lootdropper:SetLootSetupFn(loot_setup_fn)

    --
    local planardamage = inst:AddComponent("planardamage")
    planardamage:SetBaseDamage(TUNING.CHEST_MIMIC_PLANAR_DAMAGE)

    --
    inst:AddComponent("planarentity")

    --
    local sanityaura = inst:AddComponent("sanityaura")
    sanityaura.aura = -TUNING.SANITYAURA_MED

    --
    inst:AddComponent("thief")

    --
    local timer = inst:AddComponent("timer")
    timer:StartTimer("angry", 10)

    --
    MakeHauntablePanic(inst)

    MakeMediumFreezableCharacter(inst, "mimicchest")
    MakeMediumBurnableCharacter(inst, "mimicchest")

    --
    inst:ListenForEvent("attacked", OnRevealedAttacked)
    inst:ListenForEvent("peek", TryTransformBack)
    inst:ListenForEvent("death", OnRevealedDeath)

    --
    inst:SetStateGraph("SGchest_mimic")
    inst:SetBrain(brain)

    --
    inst:ListenForEvent("resetruins", function()
        local is_asleep = inst:IsAsleep()

        if not is_asleep then
            -- If we're on screen, don't do anything,
            -- since we're probably getting all antic'd up and stuff
            -- as a creature.
            return
        end

        inst.components.inventory:DropEverythingWithTag("irreplaceable")
        inst.components.inventory:DestroyContents()

        -- We might want to turn back into a non-mimic chest
        local stay_mimic = TheWorld.components.shadowthrall_mimics ~= nil
                and TheWorld.components.shadowthrall_mimics.IsEnabled()
                and math.random() < TUNING.CHEST_MIMIC_CHANCE

        local ruinsspawn_tracker = inst.components.entitytracker:GetEntity("ruinsspawn_tracker")

        if stay_mimic then
            inst = ReplacePrefab(inst, "chest_mimic")
            inst.components.entitytracker:TrackEntity("ruinsspawn_tracker", ruinsspawn_tracker)
        else
            inst = ReplacePrefab(inst, "pandoraschest")
        end

        if not inst.components.scenariorunner then
            inst:AddComponent("scenariorunner")
            inst.components.scenariorunner:SetScript((stay_mimic and "chest_labyrinth_mimic") or "chest_labyrinth")
            inst.components.scenariorunner:Run()
        end

        if ruinsspawn_tracker then
            inst.Transform:SetPosition(ruinsspawn_tracker.Transform:GetWorldPosition())
            if not stay_mimic then
                ruinsspawn_tracker:Remove()
            end
        end
    end, TheWorld)

    --
    return inst
end

-- RUINS TRACKER ---------------------------------------------------
-- This is so we can have something sit at the point that the chest/mimic was spawned,
-- so, on a ruins reset, we can respawn a mimic or chest into that position.
local function ruinstracker_on_mimic_died(inst)
    inst._mimic_dead = true
end

local function TrackerOnSave(inst, data)
    if inst._mimic_dead then
        data.mimic_dead = true
    end
end

local function TrackerOnLoad(inst, data)
    if data and data.mimic_dead then
        inst._mimic_dead = true
    end
end

local function ruinstracker_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")

    inst._mimic_dead = false

    inst:ListenForEvent("mimic_died", ruinstracker_on_mimic_died)

    inst:ListenForEvent("resetruins", function()
        -- If the mimic is alive, it'll handle this.
        if not inst._mimic_dead then return end

        local respawn_mimic = TheWorld.components.shadowthrall_mimics ~= nil
            and TheWorld.components.shadowthrall_mimics.IsEnabled()
            and math.random() < TUNING.CHEST_MIMIC_CHANCE

        local ix, iy, iz = inst.Transform:GetWorldPosition()
        local new_chest = SpawnPrefab((respawn_mimic and "chest_mimic") or "pandoraschest")
        new_chest.Transform:SetPosition(ix, iy, iz)
        if not new_chest.components.scenariorunner then
            if not respawn_mimic then
                new_chest.components.container:Close()
            end
            new_chest.components.container:DropEverythingWithTag("irreplaceable")
            new_chest.components.container:DestroyContents()

            new_chest:AddComponent("scenariorunner")
            new_chest.components.scenariorunner:SetScript((respawn_mimic and "chest_labyrinth_mimic") or "chest_labyrinth")
            new_chest.components.scenariorunner:Run()
        end

        if not inst:IsAsleep() then
            new_chest.AnimState:PlayAnimation("hit")
            new_chest.AnimState:PushAnimation("closed", false)
            new_chest.SoundEmitter:PlaySound("dontstarve/common/together/chest_retrap")

            SpawnPrefab("pandorachest_reset").Transform:SetPosition(ix, iy, iz)
        end

        inst._mimic_dead = false
    end, TheWorld)

    inst.OnSave = TrackerOnSave
    inst.OnLoad = TrackerOnLoad

    return inst
end

return Prefab("chest_mimic", fn, assets, prefabs),
    Prefab("chest_mimic_revealed", revealed_fn, revealed_assets),
    Prefab("chest_mimic_ruinsspawn_tracker", ruinstracker_fn)
