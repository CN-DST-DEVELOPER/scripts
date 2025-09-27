local clockwork_common = require "prefabs/clockwork_common"
local RuinsRespawner = require "prefabs/ruinsrespawner"

local assets =
{
    Asset("ANIM", "anim/rook.zip"),
    Asset("ANIM", "anim/rook_build.zip"),
    Asset("ANIM", "anim/rook_nightmare.zip"),
    Asset("SOUND", "sound/chess.fsb"),
    Asset("SCRIPT", "scripts/prefabs/clockwork_common.lua"),
    Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua"),
}

local prefabs =
{
    "gears",
    "collapse_small",
}

local prefabs_nightmare =
{
    "gears",
    "thulecite_pieces",
    "nightmarefuel",
    "collapse_small",
    "rook_nightmare_ruinsrespawner_inst",
}

local brain = require "brains/rookbrain"

SetSharedLootTable("rook",
{
    {"gears",  1.0},
    {"gears",  1.0},
})

SetSharedLootTable("rook_nightmare",
{
    {"gears",            1.0},
    {"nightmarefuel",    0.6},
    {"thulecite_pieces", 0.5},
})

local function ShouldSleep(inst)
    return clockwork_common.ShouldSleep(inst)
end

local function ShouldWake(inst)
    return clockwork_common.ShouldWake(inst)
end

local function Retarget(inst)
    return clockwork_common.Retarget(inst, TUNING.ROOK_TARGET_DIST)
end

local function KeepTarget(inst, target)
    return (inst.sg ~= nil and inst.sg:HasStateTag("running"))
        or clockwork_common.KeepTarget(inst, target)
end

local function OnAttacked(inst, data)
    clockwork_common.OnAttacked(inst, data)
end

local function ClearRecentlyCharged(inst, other)
    inst.recentlycharged[other] = nil
end

local function onothercollide(inst, other)
    if not other:IsValid() or inst.recentlycharged[other] then
        return
    elseif other:HasTag("smashable") and other.components.health ~= nil then
        other.components.health:Kill()
    elseif other.components.workable ~= nil
            and other.components.workable:CanBeWorked()
            and other.components.workable.action ~= ACTIONS.NET then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)
        if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
            inst.recentlycharged[other] = true
            inst:DoTaskInTime(3, ClearRecentlyCharged, other)
        end
    elseif other.components.health ~= nil and not other.components.health:IsDead() then
        inst.recentlycharged[other] = true
        inst:DoTaskInTime(3, ClearRecentlyCharged, other)
        inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/explo")
        inst.components.combat:DoAttack(other, inst.weapon)
    end
end

local function oncollide(inst, other)
    if not (other ~= nil and other:IsValid() and inst:IsValid())
            or inst.recentlycharged[other]
            or other:HasTag("player")
            or Vector3(inst.Physics:GetVelocity()):LengthSq() < 42 then
        return
    end
    ShakeAllCameras(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
    inst:DoTaskInTime(2 * FRAMES, onothercollide, other)
end

local function CreateWeapon(inst)
    local weapon = CreateEntity()
    --[[Non-networked entity]]
    weapon.entity:AddTransform()
    weapon:AddComponent("weapon")
    weapon.components.weapon:SetDamage(200)
    weapon.components.weapon:SetRange(0)
    weapon:AddComponent("inventoryitem")
    weapon.persists = false
    weapon.components.inventoryitem:SetOnDroppedFn(weapon.Remove)
    weapon:AddComponent("equippable")
    weapon:AddTag("nosteal")
    inst.components.inventory:GiveItem(weapon)
    inst.weapon = weapon
end

local function SetHomePosition(inst)
    inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
end

local function common_fn(build, tag)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 50, 1.5)

    inst.DynamicShadow:SetSize(3, 1.25)
    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(0.66, 0.66, 0.66)

    inst.AnimState:SetBank("rook")
    inst.AnimState:SetBuild(build)

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("chess")
    inst:AddTag("rook")

    if tag then
        inst:AddTag(tag)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst.override_combat_fx_size = "med"

    inst.recentlycharged = {}
    inst.Physics:SetCollisionCallback(oncollide)

    --
    local combat = inst:AddComponent("combat")
    combat.hiteffectsymbol = "spring"
    combat:SetAttackPeriod(TUNING.ROOK_ATTACK_PERIOD)
    combat:SetDefaultDamage(TUNING.ROOK_DAMAGE)
    combat:SetRetargetFunction(3, Retarget)
    combat:SetKeepTargetFunction(KeepTarget)

    --
    inst:AddComponent("follower")

    --
    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.ROOK_HEALTH)

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("inventory")

    --
    inst:AddComponent("knownlocations")

    --
    inst:AddComponent("lootdropper")

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor.walkspeed = TUNING.ROOK_WALK_SPEED
    locomotor.runspeed =  TUNING.ROOK_RUN_SPEED

    inst:AddComponent("drownable")

    --
    local sleeper = inst:AddComponent("sleeper")
    sleeper:SetWakeTest(ShouldWake)
    sleeper:SetSleepTest(ShouldSleep)
    sleeper:SetResistance(3)

    --
    MakeLargeBurnableCharacter(inst, "swap_fire", nil, 1.4)
    MakeMediumFreezableCharacter(inst, "innerds")

    --
    MakeHauntablePanic(inst)

    --
    CreateWeapon(inst)

    --
    inst:SetStateGraph("SGrook")
    inst:SetBrain(brain)

    --
    inst:DoTaskInTime(0, SetHomePosition)

    --
    inst:ListenForEvent("attacked", OnAttacked)

    return inst
end

local function rook_fn()
    local inst = common_fn("rook_build", "largecreature")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.lootdropper:SetChanceLootTable("rook")

    inst.kind = ""
    inst.soundpath = "dontstarve/creatures/rook/"
    inst.effortsound = "dontstarve/creatures/rook/steam"

    return inst
end

local function rook_nightmare_fn()
    local inst = common_fn("rook_nightmare", "cavedweller")

    inst:AddTag("shadow_aligned")

    if not TheWorld.ismastersim then
        return inst
    end

    --
    local acidinfusible = inst:AddComponent("acidinfusible")
    acidinfusible:SetFXLevel(2)
    acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.WEAKER)

    --
    inst.components.lootdropper:SetChanceLootTable("rook_nightmare")

    inst.kind = "_nightmare"
    inst.soundpath = "dontstarve/creatures/rook_nightmare/"
    inst.effortsound = "dontstarve/creatures/rook_nightmare/rattle"

    return inst
end

local function onruinsrespawn(inst, respawner)
	if not respawner:IsAsleep() then
		inst.sg:GoToState("ruinsrespawn")
	end
end

return Prefab("rook", rook_fn, assets, prefabs),
    Prefab("rook_nightmare", rook_nightmare_fn, assets, prefabs_nightmare),
    RuinsRespawner.Inst("rook_nightmare", onruinsrespawn), RuinsRespawner.WorldGen("rook_nightmare", onruinsrespawn)
