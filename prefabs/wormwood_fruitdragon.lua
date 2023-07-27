local brain = require("brains/wormwood_fruitdragonbrain")

local assets =
{
    Asset("ANIM", "anim/fruit_dragon.zip"),
    Asset("ANIM", "anim/fruit_dragon_build.zip"),
}

local prefabs =
{
    "dragonfruit",
    "wormwood_lunar_transformation_finish",
}

local MAX_CHASE_DIST = 12

local function KeepTarget(inst, target)
    return inst:IsNear(target, MAX_CHASE_DIST)
end

local function RetargetFn(inst)
    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        return nil
    end

    return inst.components.combat.target
end

local function GetRemainingTimeAwake(inst)
    local max_awake_time = (TUNING.FRUITDRAGON.AWAKE_TIME_MIN + inst.sleep_variance * TUNING.FRUITDRAGON.AWAKE_TIME_VAR)
    return max_awake_time - (GetTime() - inst._wakeup_time)
end

local function GetRemainingNapTime(inst)
    local max_awake_time = (TUNING.FRUITDRAGON.NAP_TIME_MIN + inst.sleep_variance * TUNING.FRUITDRAGON.NAP_TIME_VAR)
    return max_awake_time - (GetTime() - inst._nap_time)
end

local function StartNextNapTimer(inst)
    inst._wakeup_time = GetTime()
    inst.sleep_variance = math.random()
end

local function StartNappingTimer(inst)
    inst._nap_time = GetTime()
    inst.sleep_variance = math.random()
end

local function Sleeper_SleepTest(inst)
    if (inst.components.combat and inst.components.combat.target) or inst.sg:HasStateTag("busy") then
        return false
    end

    if inst.components.health and inst.components.health:GetPercent() > 0.9 then
        return false
    end

    if TheWorld.state.isnight or GetRemainingTimeAwake(inst) <= 0 then
        return true
    end

    return false
end

local function Sleeper_WakeTest(inst)
    if (inst.components.combat ~= nil and inst.components.combat.target ~= nil) then
        return true
    end

    if TheWorld.state.isnight then
        return false
    end

    if GetRemainingNapTime(inst) <= 0 then
        inst._sleep_interrupted = false
        return true
    end

    return false
end

local function Sleeper_OnSleep(inst)
    StartNappingTimer(inst)
    if not inst.components.health:IsDead() then
        inst.components.health:StartRegen(TUNING.FRUITDRAGON.NAP_REGEN_AMOUNT, TUNING.FRUITDRAGON.NAP_REGEN_INTERVAL)
    end
end

local function Sleeper_OnWakeUp(inst)
    if not inst.components.health:IsDead() then
        inst.components.health:StopRegen()
    end

    StartNextNapTimer(inst)
    inst._sleep_interrupted = true -- reseting it
end

----

local function finish_transformed_life(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()

    local fruit = SpawnPrefab("dragonfruit")
    fruit.Transform:SetPosition(ix, iy, iz)
    inst.components.lootdropper:FlingItem(fruit)

    local fx = SpawnPrefab("wormwood_lunar_transformation_finish")
    fx.Transform:SetPosition(ix, iy, iz)
    inst:Remove()
end

local function OnTimerDone(inst, data)
    if data.name == "finish_transformed_life" then
        finish_transformed_life(inst)
    end
end

local function OnEntitySleep(inst)
    inst.components.health:StopRegen()

    inst._entitysleeptime = GetTime()
end

local function OnEntityWake(inst)
    if inst._entitysleeptime == nil then
        return
    end

    local dt = (GetTime() - inst._entitysleeptime)
    if dt > 1 then
        if not inst.components.health:IsDead() and inst.components.health:IsHurt() then
            local estimated_naps = math.floor(dt / (40 + math.random() * 20))
            inst.components.health:DoDelta(estimated_naps * (TUNING.FRUITDRAGON.NAP_TIME_MIN / TUNING.FRUITDRAGON.NAP_REGEN_INTERVAL)  * TUNING.FRUITDRAGON.NAP_REGEN_AMOUNT) -- fake regen
        end
    end

    if not inst.components.health:IsDead() and inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep() then
        inst.components.health:StartRegen(TUNING.FRUITDRAGON.NAP_REGEN_AMOUNT, TUNING.FRUITDRAGON.NAP_REGEN_INTERVAL, true)
    end
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        if data.attacker.components.petleash and data.attacker.components.petleash:IsPet(inst) then
            local timer = inst.components.timer
            if timer and timer:TimerExists("finish_transformed_life") then
                timer:StopTimer("finish_transformed_life")
				finish_transformed_life(inst)
            end
        elseif data.attacker.components.combat then
            inst.components.combat:SuggestTarget(data.attacker)
        end
    end
end

local fruit_dragon_sounds =
{
    idle = "turnoftides/creatures/together/fruit_dragon/idle",
    death = "turnoftides/creatures/together/fruit_dragon/death",
    eat = "turnoftides/creatures/together/fruit_dragon/eat",
    onhit = "turnoftides/creatures/together/fruit_dragon/hit",
    sleep_loop = "turnoftides/creatures/together/fruit_dragon/sleep",
    stretch = "turnoftides/creatures/together/fruit_dragon/stretch",
    --do_ripen = "turnoftides/creatures/together/fruit_dragon/do_ripen",
    do_unripen = "turnoftides/creatures/together/fruit_dragon/stretch",
    attack = "turnoftides/creatures/together/fruit_dragon/attack",
    attack_fire = "turnoftides/creatures/together/fruit_dragon/attack_fire",
    challenge_pre = "turnoftides/creatures/together/fruit_dragon/challenge_pre",
    challenge = "turnoftides/creatures/together/fruit_dragon/challenge",
    challenge_pst = "turnoftides/creatures/together/fruit_dragon/eat",
    challenge_win = "turnoftides/creatures/together/fruit_dragon/eat",
    challenge_lose = "turnoftides/creatures/together/fruit_dragon/eat",
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(2, 0.75)
    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(2, 2, 2) -- NOTES(JBK): Leave this as it is and only adjust AnimState size because of locomotor scaling.

    MakeCharacterPhysics(inst, 1, 0.5)

    inst.AnimState:SetBank("fruit_dragon")
    inst.AnimState:SetBuild("fruit_dragon_build")
    inst.AnimState:PlayAnimation("idle_loop")
    inst.AnimState:SetScale(.8, .8)
    inst.AnimState:SetSymbolMultColour("gecko_eye", 0.7, 1, 0.7, 1)

    inst:AddTag("smallcreature")
    inst:AddTag("animal")
    inst:AddTag("scarytoprey")
    inst:AddTag("lunar_aligned")
    inst:AddTag("NOBLOCK")
    inst:AddTag("notraptrigger")
    inst:AddTag("wormwood_pet")

    inst:SetPrefabNameOverride("fruitdragon")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = fruit_dragon_sounds
    inst._sleep_interrupted = true
    inst._wakeup_time = GetTime()
    inst._nap_time = -math.huge


    inst:AddComponent("inspectable")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.WORMWOOD_PET_FRUITDRAGON_HEALTH)
    inst.components.health.fire_damage_scale = 0

    inst:AddComponent("combat")
    inst.components.combat:SetHurtSound("turnoftides/creatures/together/fruit_dragon/hit")
    inst.components.combat.hiteffectsymbol = "gecko_torso_middle"
    inst.components.combat:SetAttackPeriod(TUNING.WORMWOOD_PET_FRUITDRAGON_ATTACK_PERIOD)
    inst.components.combat:SetDefaultDamage(TUNING.WORMWOOD_PET_FRUITDRAGON_DAMAGE)
    inst.components.combat:SetRange(TUNING.FRUITDRAGON.ATTACK_RANGE, TUNING.FRUITDRAGON.HIT_RANGE)
    inst.components.combat:SetKeepTargetFunction(KeepTarget)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst:ListenForEvent("attacked", OnAttacked)

    inst:AddComponent("lootdropper")

    inst:AddComponent("sleeper")
    inst.components.sleeper.testperiod = 3
    inst.components.sleeper:SetWakeTest(Sleeper_WakeTest)
    inst.components.sleeper:SetSleepTest(Sleeper_SleepTest)
    inst:ListenForEvent("gotosleep", Sleeper_OnSleep)
    inst:ListenForEvent("onwakeup", Sleeper_OnWakeUp)

    StartNextNapTimer(inst)

    inst:AddComponent("locomotor")
    inst.components.locomotor.runspeed = TUNING.WORMWOOD_PET_FRUITDRAGON_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.WORMWOOD_PET_FRUITDRAGON_WALK_SPEED

    MakeSmallFreezableCharacter(inst)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGwormwood_fruitdragon")

    MakeHauntablePanicAndIgnite(inst)

    local timer = inst:AddComponent("timer")
    timer:StartTimer("finish_transformed_life", TUNING.WORMWOOD_PET_FRUITDRAGON_LIFETIME)
    inst:ListenForEvent("timerdone", OnTimerDone)
    
    inst:AddComponent("follower")
    inst.no_spawn_fx = true
    inst.RemoveWormwoodPet = finish_transformed_life

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake
    if inst:IsAsleep() then
        OnEntitySleep(inst)
    end

    return inst
end

return Prefab("wormwood_fruitdragon", fn, assets, prefabs)
