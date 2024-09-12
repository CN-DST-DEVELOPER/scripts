local assets =
{
    Asset("ANIM", "anim/shadow_insanity3_basic.zip"),
}

local prefabs =
{

}

---------------------------------------------------------------------------------------------------------------------

local easing = require("easing")

local AOE_DAMAGE_TARGET_MUST_TAGS = { "_combat", "player" }
local AOE_DAMAGE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

local AOE_DAMAGE_RADIUS = 1.5
local AOE_DAMAGE_RADIUS_PADDING = 3

local DAMAGE_OFFSET_DIST = .5
local COLLIDE_POINT_DIST_SQ = 3

local INITIAL_SPEED = 6.5
local INITIAL_SPEED_RIFTS = 8
local FINAL_SPEED = 13.5
local FINAL_SPEED_RIFTS = 15
local FINAL_SPEED_TIME = .5

local INITIAL_DIST_FROM_TARGET = 10

local OWNER_REAPPEAR_TIME = 1

---------------------------------------------------------------------------------------------------------------------

local function TurnIntoCollisionFx(inst)
    inst.Physics:Teleport(inst.collision_x, 0, inst.collision_z)

    inst.AnimState:PlayAnimation("horn_atk_pst")
    inst.AnimState:SetFinalOffset(1)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_collide")

    inst.components.updatelooper:RemoveOnUpdateFn(inst._OnUpdateFn)

    inst.Physics:SetMotorVelOverride(0, 0, 0)

    inst:AddTag("FX")

    inst:ListenForEvent("animover", inst.Remove)
    inst:ListenForEvent("entitysleep", inst.Remove)
end

local function OnUpdate(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if inst.collision_x ~= nil then
        if distsq(x, z, inst.collision_x, inst.collision_z) < COLLIDE_POINT_DIST_SQ then
            if inst.owner ~= nil then
                inst.owner:DoTaskInTime(OWNER_REAPPEAR_TIME, inst.owner.PushEvent, "reappear")
            end

            if inst.spawnfx then
                TurnIntoCollisionFx(inst)
            else
                inst:Remove()
            end

            return
        end
    end

    local speed = math.min(easing.inCubic(inst:GetTimeAlive(), inst._initial_speed, inst._final_speed-inst._initial_speed, FINAL_SPEED_TIME), inst._final_speed)

    inst.Physics:SetMotorVelOverride(speed, 0, 0)

    local combat = inst.owner ~= nil and inst.owner.components.combat or nil

    if combat == nil then
        return
    end

    combat.ignorehitrange = true

    if DAMAGE_OFFSET_DIST ~= 0 then
        local theta = inst.Transform:GetRotation() * DEGREES
        local cos_theta = math.cos(theta)
        local sin_theta = math.sin(theta)

        x = x + DAMAGE_OFFSET_DIST * cos_theta
        z = z - DAMAGE_OFFSET_DIST * sin_theta
    end

    for i, v in ipairs(TheSim:FindEntities(x, y, z, AOE_DAMAGE_RADIUS + AOE_DAMAGE_RADIUS_PADDING, AOE_DAMAGE_TARGET_MUST_TAGS, AOE_DAMAGE_TARGET_CANT_TAGS)) do
        if v ~= inst and
            not inst.targets[v] and
            v:IsValid() and not v:IsInLimbo() and
            not (v.components.health ~= nil and v.components.health:IsDead())
        then
            local range = AOE_DAMAGE_RADIUS + v:GetPhysicsRadius(0)
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            if (dx * dx + dz * dz) < (range * range) and combat:CanTarget(v) then
                combat:DoAttack(v)

                if inst.owner.components.planarentity ~= nil then
                    v:PushEvent("knockback", { knocker = inst, radius = AOE_DAMAGE_RADIUS, strengthmult = .6, forcelanded = true })
                end

                inst.targets[v] = true
            end
        end
    end

    combat.ignorehitrange = false
end

---------------------------------------------------------------------------------------------------------------------

local function SetUp(inst, owner, target, other)
    local x, y, z = target.Transform:GetWorldPosition()

    local theta = other == nil and (45 * math.random(8) * DEGREES) or other.Transform:GetRotation() * DEGREES

    inst.Transform:SetPosition(x + INITIAL_DIST_FROM_TARGET * math.cos(theta), 0, z - INITIAL_DIST_FROM_TARGET * math.sin(theta))

    inst:FacePoint(x, 0, z)

    inst.collision_x = x
    inst.collision_z = z

    inst.owner = owner
    inst.spawnfx = other == nil

    inst.components.updatelooper:AddOnUpdateFn(inst._OnUpdateFn)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_slice")

    if inst.owner.components.planarentity ~= nil then
        inst.AnimState:ShowSymbol("red")
        inst.AnimState:SetLightOverride(1)
        inst.AnimState:SetMultColour(1, 1, 1, 0.65)

        inst._initial_speed = INITIAL_SPEED_RIFTS
        inst._final_speed = FINAL_SPEED_RIFTS
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddPhysics()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()

    MakeCharacterPhysics(inst, 10, 1.5)
    RemovePhysicsColliders(inst)

    inst.Physics:SetMotorVelOverride(INITIAL_SPEED, 0, 0)

    inst.AnimState:SetBank("shadowcreature3")
    inst.AnimState:SetBuild("shadow_insanity3_basic")
    inst.AnimState:PlayAnimation("horn_atk_pre")
    inst.AnimState:PushAnimation("horn_atk")

    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:HideSymbol("red")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._initial_speed = INITIAL_SPEED
    inst._final_speed = FINAL_SPEED

    inst.targets = {}

    inst.SetUp = SetUp
    inst._OnUpdateFn = OnUpdate

    inst:AddComponent("updatelooper")

    inst.persists = false

    return inst
end

return Prefab("ruinsnightmare_horn_attack", fn, assets, prefabs)