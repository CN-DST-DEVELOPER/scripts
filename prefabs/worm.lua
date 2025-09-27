--[[
    The worm should wander around looking for fights until it finds a "home".
    A good home will look like a place with multiple other items that have the pickable
    component so the worm can set up a lure nearby.

    Once the worm has found a good home it will hang around that area and
    feed off of the plants and creatures that are nearby.

    If the player tries to interact with the worm's lure or
    approaches the worm while it isn't in a lure state it will strike.

    Spawn a dirt mound that must be dug up to get loot?
]]

local RuinsRespawner = require "prefabs/ruinsrespawner"

local assets =
{
    Asset("ANIM", "anim/worm.zip"),
    Asset("SOUND", "sound/worm.fsb"),
    Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua"),
}

local yots_assets =
{
    Asset("ANIM", "anim/worm.zip"),
    Asset("ANIM", "anim/yots_worm_build.zip"),
    Asset("SOUND", "sound/worm.fsb"),
}

local prefabs =
{
    "monstermeat",
    "wormlight",
    "worm_ruinsrespawner_inst",
}

local yots_prefabs =
{
    "monstermeat",
    "wormlight",
    "yots_redlantern",
}

SetSharedLootTable('yots_worm',
{
    {'monstermeat', 1},
    {'monstermeat', 1},
    {'log', 1},
    {'log', 1},
    {'yots_redlantern', 0.5},
    {'lightbulb', 0.5},
})

SetSharedLootTable('worm',
{
    {'monstermeat', 1},
    {'monstermeat', 1},
    {'monstermeat', 1},
    {'monstermeat', 1},
    {'wormlight', 1},
})

local brain = require("brains/wormbrain")

local MAX_LIGHT_FRAME = 20

local function OnUpdateLight(inst, dframes)
    local done
    if inst._islighton:value() then
        local frame = inst._lightframe:value() + dframes
        done = frame >= MAX_LIGHT_FRAME
        inst._lightframe:set_local(done and MAX_LIGHT_FRAME or frame)
    else
        local frame = inst._lightframe:value() - dframes
        done = frame <= 0
        inst._lightframe:set_local(done and 0 or frame)
    end

    inst.Light:SetRadius(1.5 * inst._lightframe:value() / MAX_LIGHT_FRAME)

    if TheWorld.ismastersim then
        inst.Light:Enable(inst._lightframe:value() > 0)
    end

    if done then
        inst._lighttask:Cancel()
        inst._lighttask = nil
    end
end

local function OnLightDirty(inst)
    if inst._lighttask == nil then
        inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, 1)
    end
    OnUpdateLight(inst, 0)
end

local function turnonlight(inst)
    inst._islighton:set(true)
    inst._lightframe:set(inst._lightframe:value())
    OnLightDirty(inst)
end

local function turnofflight(inst)
    inst._islighton:set(false)
    inst._lightframe:set(inst._lightframe:value())
    OnLightDirty(inst)
end

local function IsAlive(guy)
    return guy.components.health ~= nil and not guy.components.health:IsDead()
end

local RETARGET_MUST_TAGS = { "_combat", "_health" }
local RETARGET_CANT_TAGS = { "prey", "worm", "INLIMBO" }
local RETARGET_ONEOF_TAGS = { "character", "monster", "animal" }
local function retargetfn(inst)
    --Don't search for targets when you're luring. Targets will come to you.
    return not inst.sg:HasStateTag("lure")
        and FindEntity(
                inst,
                TUNING.WORM_TARGET_DIST,
                IsAlive,
                RETARGET_MUST_TAGS, -- see entityscript.lua
                RETARGET_CANT_TAGS,
                RETARGET_ONEOF_TAGS
            )
        or nil
end

local function shouldKeepTarget(inst, target)
    if inst.sg:HasStateTag("lure") or
        target == nil or
        not target:IsValid() or
        target.components.health == nil or
        target.components.health:IsDead() then
        return false
    end

    local home = inst.components.knownlocations:GetLocation("home")
    return home ~= nil
        and target:GetDistanceSqToPoint(home) < TUNING.WORM_CHASE_DIST * TUNING.WORM_CHASE_DIST
        or target:IsNear(inst, TUNING.WORM_CHASE_DIST)
end

local function onpickedfn(inst, target)
    --V2C: need to check valid target because this
    --     also gets queued up via a delayed task.
    if target ~= nil and target:IsValid() then
        inst.components.combat:SetTarget(target)
        inst:FacePoint(target:GetPosition())
        inst.components.combat:TryAttack(target)
    end

    if inst.attacktask ~= nil then
        inst.attacktask:Cancel()
        inst.attacktask = nil
    end
end

local function displaynamefn(inst)
    return
        STRINGS.NAMES[
            (inst:HasTag("lure") and "WORM_PLANT") or
            (inst:HasTag("dirt") and "WORM_DIRT") or
            "WORM"
        ]
end

local function getstatus(inst)
    return (inst:HasTag("lure") and "PLANT")
        or (inst:HasTag("dirt") and "DIRT")
        or "WORM"
end

local LUSH_MUST_TAGS = { "pickable" }
local LUSH_CANT_TAGS = { "INLIMBO" }

local function areaislush(x, y, z)
    return #TheSim:FindEntities(x, y, z, 7, LUSH_MUST_TAGS, LUSH_CANT_TAGS) >= 3
end

local WORM_TAGS = { "worm" }
local function notclaimed(x, y, z)
    --(1 because this will always find yourself)
    return #TheSim:FindEntities(x, y, z, 30, WORM_TAGS) <= 1
end

local function LookForHome(inst)
    if inst.components.knownlocations:GetLocation("home") ~= nil then
        inst.HomeTask:Cancel()
        inst.HomeTask = nil
        return
    end

    local map = TheWorld.Map
    local x, y, z = inst.Transform:GetWorldPosition()

    for i = 1, 30 do
        local s = i / 32--(num/2) -- 32.0
        local a = math.sqrt(s * 512)
        local b = math.sqrt(s) * 30
        local x1 = x + math.sin(a) * b
        local z1 = z + math.cos(a) * b

        if map:IsAboveGroundAtPoint(x1, 0, z1) and areaislush(x1, 0, z1) and notclaimed(x1, 0, z1) then
            --Yay! Set this as my home
            inst.components.knownlocations:RememberLocation("home", Vector3(x1, 0, z1))
            return
        end
    end
end

local function playernear(inst, player)
    if inst.attacktask == nil and inst.sg:HasStateTag("lure") then
        inst.attacktask = inst:DoTaskInTime(2 + math.random(), onpickedfn, player)
    end
end

local function playerfar(inst)
    if inst.attacktask ~= nil then
        inst.attacktask:Cancel()
        inst.attacktask = nil
    end
end

local function IsWorm(dude)
    return dude:HasTag("worm") and not dude.components.health:IsDead()
end

local function onattacked(inst, data)
    if data.attacker ~= nil then
        inst.components.combat:SetTarget(data.attacker)
        inst.components.combat:ShareTarget(data.attacker, 40, IsWorm, 3)
    end
end

local function CustomOnHaunt(inst, haunter)
    if inst:HasTag("lure") then
        if math.random() < TUNING.HAUNT_CHANCE_ALWAYS then
            inst.sg:GoToState("lure_exit")
            return true
        end
    else
        if inst.components.sleeper ~= nil then -- Wake up, there's a ghost!
            inst.components.sleeper:WakeUp()
        end

        if math.random() <= TUNING.HAUNT_CHANCE_ALWAYS then
            inst.components.hauntable.panic = true
            inst.components.hauntable.panictimer = TUNING.HAUNT_PANIC_TIME_SMALL
            inst.components.hauntable.hauntvalue = TUNING.HAUNT_SMALL
            return true
        end
    end
    return false
end

local function lootsetfn(lootdropper)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
    lootdropper:AddChanceLoot("lucky_goldnugget", 1)
end

local function fncommon(override_build, extra_tag)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 1000, .5)

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("worm")
    inst.AnimState:SetBuild("worm")
    if override_build then
        inst.AnimState:AddOverrideBuild(override_build)
    end
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.scrapbook_anim = "atk"
    inst.scrapbook_animpercent = 0.37

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("wet")
    inst:AddTag("worm")
    inst:AddTag("cavedweller")

    if extra_tag then inst:AddTag(extra_tag) end

    inst.Light:SetRadius(0)
    inst.Light:SetIntensity(.8)
    inst.Light:SetFalloff(.5)
    inst.Light:SetColour(1, 1, 1)
    inst.Light:Enable(false)
    inst.Light:EnableClientModulation(true)

    inst._lightframe = net_smallbyte(inst.GUID, "worm._lightframe", "lightdirty")
    inst._islighton = net_bool(inst.GUID, "worm._islighton", "lightdirty")
    inst._lighttask = nil

    inst.displaynamefn = displaynamefn  --Handles the changing names.

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("lightdirty", OnLightDirty)

        return inst
    end

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.WORM_HEALTH)

    inst:AddComponent("combat")
    inst.components.combat:SetRange(TUNING.WORM_ATTACK_DIST)
    inst.components.combat:SetDefaultDamage(TUNING.WORM_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.WORM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(GetRandomWithVariance(2, 0.5), retargetfn)
    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_SMALL

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 4
    inst.components.locomotor:SetSlowMultiplier( 1 )
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = { ignorecreep = true, ignorebridges = true, }

    inst:AddComponent("drownable")

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODGROUP.OMNI }, { FOODGROUP.OMNI })

    inst:AddComponent("pickable")
    inst.components.pickable.canbepicked = false
    inst.components.pickable.onpickedfn = onpickedfn

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(2, 5)
    inst.components.playerprox:SetOnPlayerNear(playernear)
    inst.components.playerprox:SetOnPlayerFar(playerfar)

    inst:AddComponent("knownlocations")

    inst:AddComponent("inventory")

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('worm')

    inst:AddComponent("acidinfusible")
    inst.components.acidinfusible:SetFXLevel(1)
    inst.components.acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.BERSERKER)

    --Disable this task for worm attacks
    inst.HomeTask = inst:DoPeriodicTask(3, LookForHome)
    inst.lastluretime = 0
    inst:ListenForEvent("attacked", onattacked)

    AddHauntableCustomReaction(inst, CustomOnHaunt)

    inst.turnonlight = turnonlight
    inst.turnofflight = turnofflight

    inst:SetStateGraph("SGworm")
    inst:SetBrain(brain)


    if IsSpecialEventActive(SPECIAL_EVENTS.YOTS) then
        inst.components.lootdropper:SetLootSetupFn(lootsetfn)
    end

    return inst
end

local function onruinsrespawn(inst)
	inst.sg:GoToState("lure_enter")
end

local function default_fn()
    local inst = fncommon()

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

-- Year of the Snake
local function yots_retargetfn(inst)
    if inst.sg:HasStateTag("lure") then
        return nil
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local potential_targets = TheSim:FindEntities(
        ix, iy, iz, TUNING.WORM_TARGET_DIST,
        RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS
    )
    local nearest_target, nearest_lantern_holder
    for _, target in ipairs(potential_targets) do
        if target ~= inst and target.entity:IsVisible() and IsAlive(target) then
            nearest_target = nearest_target or target
            if target.components.inventory then
                local hand_item = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if hand_item and hand_item:HasTag("redlantern") then
                    nearest_lantern_holder = target
                    break
                end
            end
        end
    end

    if nearest_lantern_holder then
        return nearest_lantern_holder, true
    else
        return nearest_target
    end
end

local function yots_shouldKeepTarget(inst, target)
    if inst.sg:HasStateTag("lure") or
            not target or
            not target:IsValid() or
            not target.components.health or
            target.components.health:IsDead() then
        return false
    end

    local home = inst.components.knownlocations:GetLocation("home")
    if home and target:GetDistanceSqToPoint(home) > (TUNING.WORM_CHASE_DIST * TUNING.WORM_CHASE_DIST) then
        return false
    end

    if target.components.inventory then
        local target_hand_item = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if target_hand_item ~= nil and target_hand_item:HasTag("redlantern") then
            return true
        end
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local potential_targets = TheSim:FindEntities(
        ix, iy, iz, TUNING.WORM_TARGET_DIST,
        RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS
    )
    local lantern_nearby
    for _, potential_target in ipairs(potential_targets) do
        if potential_target ~= inst
                and potential_target.entity:IsVisible()
                and IsAlive(potential_target)
                and potential_target.components.inventory ~= nil then
            local hand_item = potential_target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if hand_item and hand_item:HasTag("redlantern") then
                lantern_nearby = potential_target
                break
            end
        end
    end

    -- If there's a lantern holder nearby, let's drop target and try to target them.
    if lantern_nearby ~= nil and lantern_nearby ~= target then
        return false
    else
        return target:IsNear(inst, TUNING.WORM_CHASE_DIST)
    end
end

local function yots_onnewstate(inst, data)
    local underground = inst.sg:HasStateTag("invisible")

    inst:AddOrRemoveTag("fireimmune", underground)
end

local function yots_fn()
    local inst = fncommon("yots_worm_build", "wooden")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.loop_sound = "rifts4/rope_bridge/shake_lp"

    inst.components.health:SetMaxHealth(TUNING.YOTS_WORM_HEALTH)

    inst.components.lootdropper:SetChanceLootTable('yots_worm')

    inst.components.combat:SetRetargetFunction(GetRandomWithVariance(2, 0.5), yots_retargetfn)
    inst.components.combat:SetKeepTargetFunction(yots_shouldKeepTarget)

    inst:ListenForEvent("newstate", yots_onnewstate)

    MakeLargeBurnableCharacter(inst, "wormmouth")

    return inst
end


return Prefab("worm", default_fn, assets, prefabs),
    Prefab("yots_worm", yots_fn, yots_assets, yots_prefabs),
    RuinsRespawner.Inst("worm", onruinsrespawn), RuinsRespawner.WorldGen("worm", onruinsrespawn)
