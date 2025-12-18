local assets = {
    Asset("ANIM", "anim/polly_rogers.zip"),
}

local prefabs =
{
    "polly_rogerscorpse",
}

local assets_dog = {
    Asset("ANIM", "anim/salty_dog.zip"),
    Asset("ANIM", "anim/pupington_basic.zip"),
    Asset("ANIM", "anim/pupington_emotes.zip"),
    Asset("ANIM", "anim/pupington_traits.zip"),
    Asset("ANIM", "anim/pupington_jump.zip"),
    Asset("ANIM", "anim/pupington_basic_water.zip"),
}

local prefabs_dog = {
    "saltrock",
}

local brain = require("brains/pollyrogerbrain")

local SOUNDS_POLLY_ROGERS = {
    takeoff = "dontstarve/birds/takeoff_crow",
    chirp = "dontstarve/birds/chirp_crow",
    flyin = "dontstarve/birds/flyin",
}

local function fn_common(flying)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    if flying then
        inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
        inst.Physics:SetCollisionMask(COLLISION.GROUND)
        inst.Physics:SetMass(1)
        inst.Physics:SetSphere(1)
    else
        MakeCharacterPhysics(inst, 1, .1)
    end


    inst.DynamicShadow:SetSize(1, .75)
    inst.Transform:SetFourFaced()

    inst:AddTag("animal")
    inst:AddTag("prey")
    inst:AddTag("smallcreature")
    inst:AddTag("untrappable")
    inst:AddTag("companion")
    inst:AddTag("noplayertarget")
    inst:AddTag("ignorewalkableplatformdrowning")
    inst:AddTag("NOBLOCK")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.POLLY_ROGERS_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.POLLY_ROGERS_RUN_SPEED
    inst.components.locomotor.pathcaps = { allowocean = true } -- All polly variations should be able to access ocean.
    inst.components.locomotor:SetTriggersCreep(false)

    inst:AddComponent("eater")
    inst:AddComponent("follower")
    inst:AddComponent("health")
    inst:AddComponent("combat")
    inst:AddComponent("lootdropper")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventory")
    inst.components.inventory.maxslots = 1

    return inst
end

local function fn_polly()
    local inst = fn_common(true)

    inst.AnimState:SetBank("polly_rogers")
    inst.AnimState:SetBuild("polly_rogers")
    inst.AnimState:PlayAnimation("idle_ground")
    
    inst.scrapbook_animoffsety = 5
    inst.scrapbook_animpercent = 0.3
    inst.scrapbook_specialinfo = "POLLYROGERS"

    inst:AddTag("bird")
    inst:AddTag("flying")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = SOUNDS_POLLY_ROGERS

    inst:SetStateGraph("SGpolly_rogers")
    inst:SetBrain(brain)

    inst.components.eater:SetDiet({ FOODTYPE.SEEDS }, { FOODTYPE.SEEDS })

    inst.components.health:SetMaxHealth(TUNING.POLLY_ROGERS_MAX_HEALTH)

    inst.components.combat.hiteffectsymbol = "polly_body"

    MakeSmallBurnableCharacter(inst, "polly_body")
    MakeTinyFreezableCharacter(inst, "polly_body")

    return inst
end

local function ShedSalt(inst)
    local counter = inst.components.counter
    if counter then
        local count = counter:GetCount("salty")
        if count > 0 then
            counter:DecrementToZero("salty")
            inst:UpdateSaltVisuals()
            local item = SpawnPrefab("saltrock")
            item.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
            inst.components.lootdropper:FlingItem(item)
        end
    end
end

local function ShedAllSalt(inst)
    local counter = inst.components.counter
    if counter then
        local count = counter:GetCount("salty")
        if count > 0 then
            counter:Clear("salty")
            inst:UpdateSaltVisuals()
            for i = 1, count do
                local item = SpawnPrefab("saltrock")
                item.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
                inst.components.lootdropper:FlingItem(item)
            end
        end
    end
end

local function UpdateSaltVisuals(inst)
    local count = 0
    local counter = inst.components.counter
    if counter then
        count = math.min(math.floor(((counter:GetCount("salty") - 1) * 2 / TUNING.SALTY_DOG_MAX_SALT_COUNT) + 1.001), 2) -- Remaps salt values to [0, 2] range evenly but makes 0 == 0.
    end
    if count > 0 then
        inst.AnimState:OverrideSymbol("body", "salty_dog", "body_stage" .. count)
        inst.AnimState:OverrideSymbol("body_overlay", "salty_dog", "body_overlay_stage" .. count)
    else
        inst.AnimState:ClearOverrideSymbol("body")
        inst.AnimState:ClearOverrideSymbol("body_overlay")
    end
end

local function OnTimerDone(inst, data)
    if data then
        if data.name == "salty" then
            local counter = inst.components.counter
            if counter and (counter:GetCount("salty") < TUNING.SALTY_DOG_MAX_SALT_COUNT) then
                counter:Increment("salty", 1)
                inst:UpdateSaltVisuals()
            end
            inst.components.timer:StartTimer("salty", TUNING.SALTY_DOG_TIME_TO_SALT)
        end
    end
end

local function OnEnterWater(inst)
    if inst.components.timer:TimerExists("salty") then
        inst.components.timer:ResumeTimer("salty")
    else
        inst.components.timer:StartTimer("salty", TUNING.SALTY_DOG_TIME_TO_SALT)
    end
end

local function OnExitWater(inst)
    if inst.components.timer:TimerExists("salty") then
        inst.components.timer:PauseTimer("salty")
    end
end

local function OnLoad_dog(inst, data, newents)
    inst:UpdateSaltVisuals()
end

local function fn_dog()
    local inst = fn_common(false)

    inst.AnimState:SetBank("pupington")
    inst.AnimState:SetBuild("salty_dog")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.scrapbook_animoffsety = 5
    inst.scrapbook_animpercent = 0.3
    inst.AnimState:OverrideSymbol("water_ripple", "pupington_basic_water", "water_ripple")
    inst.AnimState:OverrideSymbol("water_shadow", "pupington_basic_water", "water_shadow")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.ShedSalt = ShedSalt
    inst.ShedAllSalt = ShedAllSalt
    inst.UpdateSaltVisuals = UpdateSaltVisuals
    inst.OnLoad = OnLoad_dog

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = inst.components.locomotor.runspeed

    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("counter")

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst:AddComponent("amphibiouscreature")
    inst.components.amphibiouscreature:SetBanks("pupington", "pupington_water")
    inst.components.amphibiouscreature:SetEnterWaterFn(OnEnterWater)
    inst.components.amphibiouscreature:SetExitWaterFn(OnExitWater)
    inst.components.amphibiouscreature:SetTransitionDistance(0.5)

    inst:SetStateGraph("SGsalty_dog")
    inst:SetBrain(brain)

    inst.components.eater:SetDiet({ FOODTYPE.MONSTER }, { FOODTYPE.MONSTER })

    inst.components.health:SetMaxHealth(TUNING.POLLY_ROGERS_MAX_HEALTH)

    inst.components.combat.hiteffectsymbol = "body"

    MakeSmallBurnableCharacter(inst, "body")
    MakeTinyFreezableCharacter(inst, "body")

    return inst
end

return Prefab("polly_rogers", fn_polly, assets, prefabs),
    Prefab("salty_dog", fn_dog, assets_dog, prefabs_dog) -- A variation of polly_rogers with shared stats and tuning values.
