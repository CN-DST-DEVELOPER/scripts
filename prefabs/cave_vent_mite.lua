local assets =
{
    Asset("ANIM", "anim/mite_cave.zip"),
    Asset("ANIM", "anim/cave_vent_fx.zip"),
    Asset("SOUND", "sound/rifts6.fsb"),
}

local prefabs = {
    "monstermeat",
}

local brain = require "brains/caveventmitebrain"

local TARGET_MUST_TAGS = { "_combat", "character" }
local TARGET_CANT_TAGS = { "INLIMBO" }
local function IsValidTarget(guy, inst)
    return (not guy:HasTag("monster") or guy:HasTag("player")) and inst.components.combat:CanTarget(guy)
end

local function RetargetFn(inst)
    return FindEntity(inst, TUNING.CAVE_MITE_TARGET_DIST, IsValidTarget, TARGET_MUST_TAGS, TARGET_CANT_TAGS)
end

local function KeepTargetFn(inst, target)
    return target.components.health ~= nil and not target.components.health:IsDead()
end

local function CustomOnHaunt(inst, haunter)
    if math.random() < TUNING.HAUNT_CHANCE_HALF then
        --ForceSpew(inst)
        return true
    end
    return false
end

local function SetVentPhysics(inst)
    if inst.isvent ~= true then
        inst.isvent = true
        inst.Physics:SetMass(0)
        inst.Physics:SetCapsule(0.5, 1)
        inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
		inst.Physics:SetCollisionMask(
            COLLISION.ITEMS,
		    COLLISION.CHARACTERS,
		    COLLISION.GIANTS
		)
    end
end

local function SetCharacterPhysics(inst)
    if inst.isvent ~= false then
        inst.isvent = false
        ChangeToCharacterPhysics(inst, 50, 0.75)
    end
end

local function SetUpChanceLoot(inst)
    inst.components.lootdropper.chanceloot = nil

    inst.components.lootdropper:AddChanceLoot("rocks", inst.shielded and 1.0 or 0.5)

    if inst.components.planarentity ~= nil then
        inst.components.lootdropper:AddChanceLoot("horrorfuel", 0.5)
    end
end

local function SetShield(inst, shielded)
    if shielded then
        inst.components.burnable:Extinguish()
        inst.components.acidinfusible:SetFXLevel(2)
        inst.components.timer:PauseTimer("shield_cooldown")
        inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.CAVE_MITE_SHELL_ABSORB, "shellabsorb")
        inst.override_combat_impact_sound = "stone_"
        inst:AddTag("electricdamageimmune")
        inst.shielded = true
    else
        inst.components.acidinfusible:SetFXLevel(4)
        inst.components.timer:ResumeTimer("shield_cooldown")
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "shellabsorb")
        inst.override_combat_impact_sound = nil
        inst:RemoveTag("electricdamageimmune")
        inst.shielded = nil
    end
    SetUpChanceLoot(inst) -- after inst.shielded is set
end

local function UpdateRift(inst)
    local riftspawner = TheWorld.components.riftspawner
    if riftspawner and riftspawner:IsShadowPortalActive() then
        if inst.components.planarentity == nil then
            inst:AddTag("shadow_aligned")
            inst:AddComponent("planarentity")
            inst:AddComponent("planardamage")
            inst.components.planardamage:SetBaseDamage(TUNING.CAVE_MITE_PLANAR_DAMAGE)
			inst.AnimState:ShowSymbol("red_vent")
        end
    elseif inst.components.planarentity ~= nil then
        inst:RemoveTag("shadow_aligned")
        inst:RemoveComponent("planarentity")
        inst:RemoveComponent("planardamage")
        inst.AnimState:HideSymbol("red_vent")
    end
    SetUpChanceLoot(inst)
end

local function GetStatus(inst)
    return inst.shielded and "VENTING"
        or nil
end

local DIET = { FOODTYPE.MEAT }
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 50, .75)

    inst.DynamicShadow:SetSize(1.5, .5)
    inst.Transform:SetFourFaced()

    --inst:AddTag("cavedweller") -- ALWAYS awake in caves because nocturnal but sleeps above ground during day
    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("scarytoprey")
    --inst:AddTag("canbetrapped")
    inst:AddTag("smallcreature")

    inst.AnimState:SetBank("mite_cave")
    inst.AnimState:SetBuild("mite_cave")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:HideSymbol("red_vent")
    inst.AnimState:SetSymbolLightOverride("red_vent", 1)
    inst.AnimState:AddOverrideBuild("cave_vent_fx")

    --MakeFeedableSmallLivestockPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.override_combat_fx_size = "small"

    local color = 0.5 + math.random() * 0.5
    inst.AnimState:SetSymbolMultColour("mite_vent", color, color, color, 1)
    inst.AnimState:SetSymbolMultColour("rubble", color, color, color, 1)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.CAVE_MITE_HEALTH)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.CAVE_MITE_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.CAVE_MITE_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat.hiteffectsymbol = "body"

    inst:AddComponent("sleeper")
    inst.components.sleeper.watchlight = true
    inst.components.sleeper:SetResistance(2)
    inst.components.sleeper:SetNocturnal(true)

    -- locomotor must be constructed before the stategraph!
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.CAVE_MITE_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.CAVE_MITE_RUN_SPEED

    inst:SetStateGraph("SGcaveventmite")
    inst:SetBrain(brain)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:AddRandomLoot("monstermeat", 1)
    inst.components.lootdropper.numrandomloot = 1

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    inst:AddComponent("drownable")
    inst:AddComponent("knownlocations")
    ------------------
    inst:AddComponent("eater")
    inst.components.eater:SetDiet(DIET, DIET)
    inst.components.eater:SetCanEatHorrible()
    inst.components.eater:SetStrongStomach(true) -- can eat monster meat!
    inst.components.eater:SetCanEatRawMeat(true)

    inst:AddComponent("timer")
    if not POPULATING then
        inst.components.timer:StartTimer("shield_cooldown", 2 + math.random() * 3)
    end

    inst:AddComponent("acidinfusible")
    inst.components.acidinfusible:SetFXLevel(4)
    inst.components.acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.STRONGER)

    inst.SetVentPhysics = SetVentPhysics
    inst.SetCharacterPhysics = SetCharacterPhysics
    inst.SetShield = SetShield

    local function UpdateRift_Bridge(_)
        UpdateRift(inst)
    end

    local riftspawner = TheWorld.components.riftspawner
    if riftspawner then
        inst:ListenForEvent("ms_riftaddedtopool", UpdateRift_Bridge, TheWorld)
	    inst:ListenForEvent("ms_riftremovedfrompool", UpdateRift_Bridge, TheWorld)
    end
    UpdateRift(inst)

    MakeMediumBurnableCharacter(inst, "mite_body")
    MakeMediumFreezableCharacter(inst, "mite_body")

    MakeHauntablePanic(inst)
    AddHauntableCustomReaction(inst, CustomOnHaunt, true)
    --MakeFeedableSmallLivestock(inst, TUNING.SPIDER_PERISH_TIME)

    return inst
end

return Prefab("cave_vent_mite", fn, assets, prefabs)