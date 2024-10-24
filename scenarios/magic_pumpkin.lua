
local PUMPKIN_CARVER_MUST_TAGS = { "_inventoryitem" }
local PUMPKIN_CARVER_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

local BIRDBLOCKER_MUST_TAGS = { "birdblocker" }

local FIND_PUMPKIN_CARVER_RADIUS = 5

local NUM_CROWS_MIN = 8
local NUM_CROWS_MAX = 14

----------------------------------------------------------------------------------------------------

local function IsPumpkinCarver(carver)
    return carver.components.pumpkincarver ~= nil
end

local function GetCrowSpawnPoint(x, z)
    local function TestSpawnPoint(offset)
        local x, y, z = x + offset.x, 0, z + offset.z

        return
            TheWorld.Map:IsPassableAtPoint(x, 0, z, false) and
            not TheWorld.GroundCreep:OnCreep(x, 0, z) and
            TheSim:CountEntities(x, 0, z, 4, BIRDBLOCKER_MUST_TAGS) == 0
    end

    local theta = math.random() * TWOPI
    local radius = 6 + math.random() * 6
    local resultoffset = FindValidPositionByFan(theta, radius, 12, TestSpawnPoint)

    if resultoffset ~= nil then
        return Vector3(x, 0, z) + resultoffset
    end
end

local function SpawnCrows(x, z)
    local num = math.random(NUM_CROWS_MIN, NUM_CROWS_MAX)
    local delay = 0

    for k = 1, num do
        local pos = GetCrowSpawnPoint(x, z)

        if pos ~= nil then
            local bird = SpawnPrefab("crow")

            if bird ~= nil then
                if math.random() < .5 then
                    bird.Transform:SetRotation(180)
                end

                if bird:HasTag("bird") then
                    pos.y = 15
                end

                bird.Physics:Teleport(pos:Get())
                bird.sg:GoToState("delay_glide", delay)

                delay = delay + .034 + .066 * math.random()
            end
        end
    end
end

local function SpawnShadowEffect(x, z)
    local fx = SpawnPrefab("statue_transition")

    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
    end
end

local function TriggerTrap(inst, scenariorunner)
    scenariorunner:ClearScenario()

    if inst.components.growable == nil then
        return
    end

    inst.force_oversized = true

    inst.components.growable:DoGrowth()

    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("maxwell_rework/shadow_trap/explode")
        inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_haunt")
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    SpawnShadowEffect(x, z)
    SpawnCrows(x, z)
end

----------------------------------------------------------------------------------------------------

local function OnLoad(inst, scenariorunner)
    if inst.components.growable == nil then
        return
    end

    inst._pumpkincarver = FindEntity(inst, FIND_PUMPKIN_CARVER_RADIUS, IsPumpkinCarver, PUMPKIN_CARVER_MUST_TAGS, PUMPKIN_CARVER_CANT_TAGS)

    if inst._pumpkincarver == nil then
        scenariorunner:ClearScenario()

        return
    end

    inst.components.growable:Pause("halloween_magic")

    inst._onpickuppumpkincarverfn = function(carver) TriggerTrap(inst, scenariorunner) end

    inst:ListenForEvent("onputininventory", inst._onpickuppumpkincarverfn, inst._pumpkincarver)
end

local function OnDestroy(inst)
    if inst._onpickuppumpkincarverfn ~= nil and inst._pumpkincarver ~= nil then
        inst:RemoveEventCallback("onputininventory", inst._onpickuppumpkincarverfn, inst._pumpkincarver)

        inst._pumpkincarver = nil
        inst._onpickuppumpkincarverfn = nil
    end
end

----------------------------------------------------------------------------------------------------

return
{
    OnLoad = OnLoad,
    OnDestroy = OnDestroy,
}
