local assets =
{
    Asset("ANIM", "anim/buzzard_build.zip"),
    --Asset("ANIM", "anim/buzzard_shadow.zip"),
    Asset("ANIM", "anim/buzzard_basic.zip"),
    Asset("SOUND", "sound/buzzard.fsb"),        -- Why was that commented ?
}

local prefabs =
{
    "drumstick",
    "smallmeat",
    "feather_crow",
    "buzzardcorpse",
}

local brain = require("brains/buzzardbrain")

SetSharedLootTable('buzzard',
{
    {'drumstick',             1.00},
    {'smallmeat',             0.33},
    {'feather_crow',          0.33},
})

local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
        and inst:IsNear(target, target:HasTag("buzzard") and inst.components.combat:GetAttackRange() + target:GetPhysicsRadius(0) or 7.5)
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
end

local function OnPreLoad(inst, data)
    local x, y, z = inst.Transform:GetWorldPosition()
    if y > 0 then
        inst.Transform:SetPosition(x, 0, z)
    end
end

local function OnEntitySleep(inst)
    inst.components.combat:SetTarget(nil)
end

local function OnHaunt(inst)
    local action = BufferedAction(inst, nil, ACTIONS.GOHOME)
    inst.components.locomotor:PushAction(action)
    inst.components.hauntable.hauntvalue = TUNING.HAUNT_MEDIUM
    return true
end

local sounds =
{
    taunt = "dontstarve_DLC001/creatures/buzzard/taunt",
    squack = "dontstarve_DLC001/creatures/buzzard/squack",
    flap = "dontstarve_DLC001/creatures/buzzard/flap",
    attack = "dontstarve_DLC001/creatures/buzzard/attack",
    flyout = "dontstarve_DLC001/creatures/buzzard/flyout",
    hop = "dontstarve_DLC001/creatures/buzzard/hurt", -- Yes, this is the hop sound.
    death = "dontstarve_DLC001/creatures/buzzard/death",
    --eat = "lunarhail_event/creatures/lunar_buzzard/eating_LP",
    --spit = "lunarhail_event/creatures/lunar_buzzard/spit",
    distant = "dontstarve_DLC001/creatures/buzzard/distant",
}

local NORMAL_DIET = { FOODGROUP.OMNI }
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(1.25, .75)
    inst.Transform:SetFourFaced()

    MakeCharacterPhysics(inst, 15, .25)

    inst.AnimState:SetBank("buzzard")
    inst.AnimState:SetBuild("buzzard_build")
    inst.AnimState:PlayAnimation("idle", true)

    ------------------------------------------

    inst:AddTag("buzzard")
    inst:AddTag("animal")
    inst:AddTag("scarytoprey")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = sounds

    ------------------------------------------

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.BUZZARD_HEALTH)

    ------------------

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.BUZZARD_DAMAGE)
    inst.components.combat:SetRange(TUNING.BUZZARD_ATTACK_RANGE)
    inst.components.combat.hiteffectsymbol = "buzzard_body"
    inst.components.combat:SetAttackPeriod(TUNING.BUZZARD_ATTACK_PERIOD)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat:SetHurtSound("dontstarve_DLC001/creatures/buzzard/hurt")
    ------------------------------------------

    inst:AddComponent("eater")
    inst.components.eater:SetDiet(NORMAL_DIET, NORMAL_DIET)

    ------------------------------------------

    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(4)

    ------------------------------------------

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('buzzard')

    ------------------------------------------

    inst:AddComponent("inspectable")

    ------------------------------------------

    inst:AddComponent("knownlocations")

    ------------------------------------------

    inst:ListenForEvent("attacked", OnAttacked)
    ------------------------------------------

    MakeMediumBurnableCharacter(inst, "buzzard_body")
    MakeMediumFreezableCharacter(inst, "buzzard_body")

    ------------------------------------------

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.BUZZARD_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.BUZZARD_RUN_SPEED

    inst:SetStateGraph("SGbuzzard")
    inst:SetBrain(brain)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetOnHauntFn(OnHaunt)

    inst.spawn_gestalt_mutated_tuning = "SPAWN_MUTATED_BUZZARDS_GESTALT"

    inst.OnPreLoad = OnPreLoad
    inst.OnEntitySleep = OnEntitySleep

    return inst
end

-------------------------------------------------------------

local mutated_assets =
{
    Asset("ANIM", "anim/buzzard_lunar_build.zip"),
    Asset("ANIM", "anim/buzzard_mutated.zip"),
    --Asset("ANIM", "anim/buzzard_shadow.zip"),
    Asset("ANIM", "anim/buzzard_basic.zip"),
    Asset("SOUND", "sound/buzzard.fsb"),

    Asset("ANIM", "anim/warg_mutated_breath_fx.zip"),
}

local mutated_prefabs =
{
    "spoiled_food",
    "smallmeat",
    --"feather_crow", --Unique feather?
    "warg_mutated_breath_fx",
	"warg_mutated_ember_fx",

    -- Not loaded for normal, spawner handles it.
    "circlingbuzzard_lunar",
}

local mutated_scrapbook_adddeps =
{
	"lunarthrall_plant_gestalt",
}

local FX_SIZES = { "tiny", "small", "med", "large" }
local FX_HEIGHTS = { "_low", "", "_high" } -- "med" height has no identifier
for i, size in ipairs(FX_SIZES) do
    for j, height in ipairs(FX_HEIGHTS) do
        table.insert(mutated_prefabs, "lunarflame_puff_"..size..height)
    end
end

local mutated_sounds =
{
    taunt = "lunarhail_event/creatures/lunar_buzzard/taunt",
    squack = "lunarhail_event/creatures/lunar_buzzard/squack",
    flap = "lunarhail_event/creatures/lunar_buzzard/flap",
    attack = "lunarhail_event/creatures/lunar_buzzard/attack",
    flyout = "lunarhail_event/creatures/lunar_buzzard/flyout",
    hop = "lunarhail_event/creatures/lunar_buzzard/hurt", -- Yes, this is the hop sound.
    death = "lunarhail_event/creatures/lunar_buzzard/death",
    --distant = "dontstarve_DLC001/creatures/buzzard/distant",
    flock = "lunarhail_event/creatures/lunar_buzzard/flock",
    eat = "lunarhail_event/creatures/lunar_buzzard/eating_LP",
    spit = "lunarhail_event/creatures/lunar_buzzard/spit",
}

SetSharedLootTable('buzzard_lunar',
{
    {'spoiled_food',    1.00},
    {'moonglass',       0.50},
    --{'feather_crow',    0.33},
})

-- Incase we get any animated symbols stuff
local function Mutated_SwitchToEightFaced(inst)
    --[[
	if not inst.temp8faced:value() then
		inst.temp8faced:set(true)
		if not TheNet:IsDedicated() then
			Mutated_OnTemp8Faced(inst)
		end
		inst.Transform:SetEightFaced()
	end
    ]]
    inst.Transform:SetEightFaced()
end

local function Mutated_SwitchToFourFaced(inst)
    --[[
	if inst.temp8faced:value() then
		inst.temp8faced:set(false)
		if not TheNet:IsDedicated() then
			Mutated_OnTemp8Faced(inst)
		end
		inst.Transform:SetSixFaced()
	end
    ]]
    inst.Transform:SetFourFaced()
end

local function Mutated_SetFlameThrowerOnCd(inst)
    inst.components.timer:StopTimer("flamethrower_cd")
	inst.components.timer:StartTimer("flamethrower_cd", TUNING.MUTATEDBUZZARD_FLAMETHROWER_CD + math.random() * TUNING.MUTATEDBUZZARD_FLAMETHROWER_CD_VARIANCE)
end

local RETARGET_DIST = TUNING.MUTATEDBUZZARD_FIND_TARGET_DIST
local TARGET_MUST_TAGS = { "_combat" }
local TARGET_CANT_TAGS = { "INLIMBO", "buzzard" }
local function Mutated_RetargetFn(inst)
    return FindEntity(inst, RETARGET_DIST, nil, TARGET_MUST_TAGS, TARGET_CANT_TAGS)
end

local function Mutated_KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
        and inst:IsNear(target, 10)
end

-- Tracking targets, so some fight, and some eat!
local BUZZARD_SHARED_TARGETS = {}
local function Mutated_AddSharedTargetRef(inst, target)
    BUZZARD_SHARED_TARGETS[target] = BUZZARD_SHARED_TARGETS[target] or { }
    BUZZARD_SHARED_TARGETS[target][inst] = true
end

local function Mutated_RemoveSharedTargetRef(inst, target)
    if BUZZARD_SHARED_TARGETS[target] ~= nil then
        BUZZARD_SHARED_TARGETS[target][inst] = nil

        if GetTableSize(BUZZARD_SHARED_TARGETS[target]) == 0 then
            BUZZARD_SHARED_TARGETS[target] = nil
        end
    end
end

local function SetOwnCorpse(inst, corpse)
    if inst.brain then
        inst.brain:OwnCorpse(corpse)
    end
end

local function LoseCorpseOwnership(inst)
    if inst.brain then
        inst.brain:LoseCorpseOwnership()
    end
end

local function Mutated_OnDeath(inst)
    inst.AnimState:ClearSymbolBloom("buzzard_gem")
    inst.AnimState:SetSymbolLightOverride("buzzard_gem", 0)
    inst.AnimState:SetSymbolLightOverride("buzzard_beak", 0)

    local combat = inst.components.combat
    if combat and combat.target then
        Mutated_RemoveSharedTargetRef(inst, combat.target)
    end
    LoseCorpseOwnership(inst)
end

local function Mutated_EnterMigration(inst)
    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    if mutatedbirdmanager then
        mutatedbirdmanager:FillMigrationTaskAtInst("mutatedbuzzard_gestalt", inst, 1)
        inst:Remove()
    end
end

local function ClearMigrationTask(inst)
    if inst.enter_migration_task ~= nil then
        inst.enter_migration_task:Cancel()
        inst.enter_migration_task = nil
    end
end

local function Mutated_OnEntitySleep(inst)
    ClearMigrationTask(inst)
    inst.enter_migration_task = inst:DoTaskInTime(TUNING.MUTATEDBUZZARD_ENTER_MIGRATION_ON_SLEEP_TIME, Mutated_EnterMigration)

    OnEntitySleep(inst)
    LoseCorpseOwnership(inst)
end

local function Mutated_OnEntityWake(inst)
    ClearMigrationTask(inst)
end

local MAX_TARGET_SHARES = 10
local SHARE_TARGET_DIST = 15

local function Mutated_IsValidAlly(dude)
    return dude:HasTag("gestaltmutant")
end

local function Mutated_OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
end

local function Mutated_OnNewCombatTarget(inst, data)
    if data.oldtarget ~= nil then
        Mutated_RemoveSharedTargetRef(inst, data.oldtarget)
    end

    if data.target ~= nil then
        Mutated_AddSharedTargetRef(inst, data.target)
    end

    inst.components.combat:ShareTarget(data.target, SHARE_TARGET_DIST, Mutated_IsValidAlly, MAX_TARGET_SHARES)
    LoseCorpseOwnership(inst)
end

local function Mutated_OnDroppedTarget(inst, data)
    Mutated_RemoveSharedTargetRef(inst, data.target)
end

local function Mutated_CanSuggestTargetFn(inst, target)
    return GetTableSize(BUZZARD_SHARED_TARGETS[target]) < TUNING.MUTATEDBUZZARD_MAX_TARGET_COUNT
end

local function Mutated_OnRemoveEntity(inst)
    local combat = inst.components.combat
    if combat and combat.target then
        Mutated_RemoveSharedTargetRef(inst, combat.target)
    end
    LoseCorpseOwnership(inst)
	if inst.flame_pool ~= nil then
		for i, v in ipairs(inst.flame_pool) do
			v:Remove()
		end
		inst.flame_pool = nil
	end
	if inst.ember_pool ~= nil then
		for i, v in ipairs(inst.ember_pool) do
			v:Remove()
		end
		inst.ember_pool = nil
	end
end

local function Mutated_GetStatus(inst)
    return inst.sg:HasStateTag("eating_corpse") and "EATING_CORPSE"
        --or inst.sg:HasStateTag("flamethrower") and "FLAMETHROWER"
        or nil
end

local MUTATED_DIET = { FOODTYPE.LUNAR_SHARDS, FOODTYPE.CORPSE }
local function mutated_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(1.25, .75)
    inst.Transform:SetFourFaced()

    MakeCharacterPhysics(inst, 15, .25)

    inst.AnimState:SetBank("buzzard")
    inst.AnimState:SetBuild("buzzard_lunar_build")
    inst.AnimState:PlayAnimation("idle", true)

    inst.AnimState:SetSymbolBloom("buzzard_gem")
    inst.AnimState:SetSymbolLightOverride("buzzard_gem", 1)
    inst.AnimState:SetSymbolLightOverride("buzzard_beak", 0.3)

    inst.AnimState:AddOverrideBuild("warg_mutated_breath_fx")
    inst.AnimState:SetSymbolBloom("buzzard_breath_fx")
	inst.AnimState:SetSymbolBrightness("buzzard_breath_fx", 1.5)
	inst.AnimState:SetSymbolLightOverride("buzzard_breath_fx", 0.1)

    inst.AnimState:AddOverrideBuild("buzzard_mutated")
    inst.AnimState:SetSymbolBloom("buzzard_spit_fx")
    inst.AnimState:SetSymbolLightOverride("buzzard_spit_fx", 0.3)

    ------------------------------------------
    inst:AddTag("buzzard")
    inst:AddTag("animal")
    inst:AddTag("scarytoprey")
    inst:AddTag("lunar_aligned")
    inst:AddTag("gestaltmutant")
    inst:AddTag("hostile")
    inst:AddTag("mutantdominant") -- Dominant over lunar mutations like horror hounds, permafrost pengulls, etc
    inst:AddTag("soulless")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.scrapbook_adddeps = mutated_scrapbook_adddeps

    ------------------------------------------
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MUTATEDBUZZARD_HEALTH)
    ------------------
    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.MUTATEDBUZZARD_DAMAGE)
    inst.components.combat:SetRange(TUNING.MUTATEDBUZZARD_ATTACK_RANGE, TUNING.MUTATEDBUZZARD_HIT_RANGE)
    inst.components.combat.hiteffectsymbol = "buzzard_body"
    inst.components.combat:SetAttackPeriod(TUNING.MUTATEDBUZZARD_ATTACK_PERIOD)
    --inst.components.combat:SetRetargetFunction(1, Mutated_RetargetFn)
    inst.components.combat:SetKeepTargetFunction(Mutated_KeepTargetFn)
    inst.components.combat:SetCanSuggestTargetFn(Mutated_CanSuggestTargetFn)
    inst.components.combat:SetHurtSound("lunarhail_event/creatures/lunar_buzzard/hurt")
    ------------------------------------------
    inst:AddComponent("eater")
    inst.components.eater:SetDiet(MUTATED_DIET, MUTATED_DIET)
    ------------------------------------------
    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('buzzard_lunar')
    ------------------------------------------
    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = Mutated_GetStatus
    ------------------------------------------
    inst:AddComponent("knownlocations")

    inst:AddComponent("planarentity")

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.MUTATEDBUZZARD_PLANAR_DAMAGE)
    ------------------------------------------
    MakeMediumBurnableCharacter(inst, "buzzard_body")
    MakeMediumFreezableCharacter(inst, "buzzard_body")
    ------------------------------------------
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.MUTATEDBUZZARD_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.MUTATEDBUZZARD_RUN_SPEED

    inst:AddComponent("timer")
    if not POPULATING then
        inst.components.timer:StartTimer("flamethrower_cd", 5 + math.random() * 2)
    end

    inst.sounds = mutated_sounds

    inst.flame_pool = {}
	inst.ember_pool = {}
	inst.canflamethrower = true

    inst.SwitchToEightFaced = Mutated_SwitchToEightFaced
    inst.SwitchToFourFaced = Mutated_SwitchToFourFaced

    inst.SetFlameThrowerOnCd = Mutated_SetFlameThrowerOnCd

    inst.SetOwnCorpse = SetOwnCorpse
    inst.LoseCorpseOwnership = LoseCorpseOwnership

    inst:ListenForEvent("attacked", Mutated_OnAttacked)
    inst:ListenForEvent("death", Mutated_OnDeath)
    inst:ListenForEvent("newcombattarget", Mutated_OnNewCombatTarget)
    inst:ListenForEvent("droppedtarget", Mutated_OnDroppedTarget)

    inst:SetStateGraph("SGbuzzard")
    inst:SetBrain(brain)
    inst.sg.mem.nocorpse = true

    if TheWorld.components.mutatedbirdmanager ~= nil then
        TheWorld:PushEvent("ms_registermutatedbuzzard", inst)
    end

    MakeHauntable(inst)

    inst.OnRemoveEntity = Mutated_OnRemoveEntity
    inst.OnPreLoad = OnPreLoad

    inst.OnEntitySleep = Mutated_OnEntitySleep
    inst.OnEntityWake = Mutated_OnEntityWake

    return inst
end

return Prefab("buzzard", fn, assets, prefabs),
    Prefab("mutatedbuzzard_gestalt", mutated_fn, mutated_assets, mutated_prefabs)
