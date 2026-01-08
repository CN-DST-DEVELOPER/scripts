--------------------------------------------------------------------------
--[[ WinterSurpriseSpawner class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "WinterSurpriseSpawner should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local INLIMBO_TAGS = { "INLIMBO" }

local BLOCKER_RADIUS = 2

local WINTER_TREE_TAGS = { "winter_tree" }

local MAX_RADIUS_FROM_SPAWNER = 10
local MAX_RADIUS_FROM_SPAWNER_SQ = MAX_RADIUS_FROM_SPAWNER * MAX_RADIUS_FROM_SPAWNER

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local WINTERSURPRISE_TIMERNAME = "wintersurprise_spawntimer"
local _worldsettingstimer = TheWorld.components.worldsettingstimer
local _spawners = {}
local _spawnsthiswinter = 0

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function GetKlausSack()
    return TheWorld.components.klaussackspawner and TheWorld.components.klaussackspawner:GetKlausSack() or nil
end

local function CanSpawnWinterSurprise()
    return _spawnsthiswinter < TUNING.WINTERSURPRISE_MAX_SPAWNS
end

local function IsValidSpawner(x, y, z)
    x, y, z = TheWorld.Map:GetTileCenterPoint(x, 0, z)

    local klaus_sack = GetKlausSack()
    if klaus_sack then
        -- If we're not in the same biome as the sack, don't spawn here!
        local topology_data = GetTopologyDataAtPoint(x, z)
        local sack_topology_data = GetTopologyDataAtInst(klaus_sack)
        if topology_data.task_id and sack_topology_data.task_id
            and topology_data.task_id ~= sack_topology_data.task_id then
            return false
        end

        -- But not in the same spot as the sack.
        if klaus_sack:GetDistanceSqToPoint(x, 0, z) <= MAX_RADIUS_FROM_SPAWNER_SQ then
            return false
        end
    end

    -- And not if another tree already spawned.
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, 12, WINTER_TREE_TAGS)) do
        if v.is_leif then
            return false
        end
    end

    for _x = -1, 1 do
        for _z = -1, 1 do
            if not TheWorld.Map:IsPassableAtPoint(x + (_x * TILE_SCALE), 0, z + (_z * TILE_SCALE)) then
                return false
            end
        end
    end

    return true
end

local STRUCTURES_ONEOF_TAGS = { "structure", "klaussacklock" }

local MAX_SURPRISE_GIFTS = 8
local GIFT_THETA_VAR = TWOPI / 24
local GIFT_THETA_STEP = TWOPI / 12
local function ConfigureWinterSurprise(tree)
    local x, y, z = tree.Transform:GetWorldPosition()
    tree.is_leif = true
    tree.components.growable:SetStage(5)

    local container = tree.components.container
    if container then
        for i = 1, container:GetNumSlots() do
            container:GiveItem(SpawnPrefab(math.random() <= 0.1 and GetRandomFancyWinterOrnament() or GetRandomBasicWinterOrnament()))
        end
    end

    local hounded = TheWorld.components.hounded
    local escalation_level = hounded and hounded:GetWorldEscalationLevel()
    local num_surprise_gifts = math.clamp(escalation_level and escalation_level.numspawns() or 3, 2, MAX_SURPRISE_GIFTS)
    local num_real_gifts = math.ceil(num_surprise_gifts * 0.25)
    local theta = math.random() * TWOPI

    local gifts = {}
    for i = 1, num_surprise_gifts do
        table.insert(gifts, false)
    end
    for i = 1, num_real_gifts do
        table.insert(gifts, true)
    end
    gifts = shuffleArray(gifts)

    local function SpawnGift(is_real)
        local items = {}
        if is_real then
            local loot = GetNiceWinterTreeGiftLoot(true)

            for i, v in ipairs(loot) do
                local item = SpawnPrefab(v.prefab)
                if item ~= nil then
                    if item.components.stackable ~= nil then
						item.components.stackable:SetStackSize(math.max(1, v.stack or 1))
                    end
                    table.insert(items, item)
                end
            end
        else
            local loot = GetNaughtyWinterTreeGiftLoot()

            for i, v in ipairs(loot) do
                local item = SpawnPrefab(v.prefab)
                if item ~= nil then
                    if item.components.stackable ~= nil then
						item.components.stackable:SetStackSize(math.max(1, v.stack or 1))
                    end
                    table.insert(items, item)
                end
            end

            local surprise = SpawnPrefab("giftsurprise")
			surprise:SetCreatureSurprise(hounded and hounded.GetSpawnPrefab and hounded:GetSpawnPrefab(false) or "hound")
            table.insert(items, surprise)

            for i = 1, 4 - #items do -- Padding
                table.insert(items, SpawnPrefab("giftsurprise"))
            end
        end

        local radius = GetRandomWithVariance(1.5, .2)
        local thetavar = GetRandomWithVariance(theta, GIFT_THETA_VAR)
        local gift = SpawnPrefab("gift")
        gift.Transform:SetPosition(x + math.cos(thetavar) * radius, y, z - math.sin(thetavar) * radius)
        gift.components.unwrappable:WrapItems(items)

        local scenariorunner = gift:AddComponent("scenariorunner")
        scenariorunner:SetScript("gift_surprise")
        scenariorunner:Run()

        for k, item in pairs(items) do
            item:Remove()
        end
        items = nil

        theta = theta + GIFT_THETA_STEP
    end
    for i, is_real in ipairs(gifts) do
        SpawnGift(is_real)
    end
end

local function IsValidSpawnOffset(pos)
    local x, y, z = pos:Get()

    if TheSim:CountEntities(x, 0, z, .75, nil, INLIMBO_TAGS) > 0 then
        return false
    end

    if IsPointCoveredByBlocker(x, 0, z, BLOCKER_RADIUS) then
        return false
    end

    return true
end

local function SpawnWinterSurprise()
    _spawners = shuffleArray(_spawners)

    local x, y, z
    for i, v in ipairs(_spawners) do
        x, y, z = v.Transform:GetWorldPosition()
        if IsValidSpawner(x, y, z) and not IsAnyPlayerInRange(x, y, z, 35) then
            local offset = FindWalkableOffset(Vector3(x, y, z), math.random() * TWOPI, 5 + math.random() * 5, 12, true, nil, IsValidSpawnOffset)
            if offset then
                x, y, z = x + offset.x, y + offset.y, z + offset.z
                -- Valid if there's no structure nearby
                if TheSim:CountEntities(x, y, z, 5, nil, nil, STRUCTURES_ONEOF_TAGS) == 0 then
                    break
                end
            end
        end
        x = nil
    end

    if x ~= nil then
        x, y, z = TheWorld.Map:GetTileCenterPoint(x, y, z)

        local tree = SpawnPrefab("winter_tree")
        tree.Transform:SetPosition(x, y, z)
        ConfigureWinterSurprise(tree)
    end
end

local function StopRespawnTimer()
    _worldsettingstimer:StopTimer(WINTERSURPRISE_TIMERNAME)
end

local function StartRespawnTimer(t)
    if CanSpawnWinterSurprise() then
        StopRespawnTimer()
        _worldsettingstimer:StartTimer(WINTERSURPRISE_TIMERNAME, t)
    end
end

local function StartWinterSurpriseSpawnTimer()
    StartRespawnTimer(TUNING.WINTERSURPRISE_SPAWN_DELAY + math.random() * TUNING.WINTERSURPRISE_SPAWN_DELAY_VARIANCE)
end

local function OnRespawnWinterSurpriseTimer()
    if CanSpawnWinterSurprise() then
        SpawnWinterSurprise()
        _spawnsthiswinter = _spawnsthiswinter + 1

        if CanSpawnWinterSurprise() then
            StartWinterSurpriseSpawnTimer()
        end
    end
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnRemoveSpawner(spawner)
    for i, v in ipairs(_spawners) do
        if v == spawner then
            table.remove(_spawners, i)
            return
        end
    end
end

local function OnRegisterSurpriseSpawningPt(inst, spawner)
    for i, v in ipairs(_spawners) do
        if v == spawner then
            return
        end
    end

    table.insert(_spawners, spawner)
    inst:ListenForEvent("onremove", OnRemoveSpawner, spawner)
end

local function OnIsWinter(self, iswinter)
    if iswinter then
        if CanSpawnWinterSurprise() and not _worldsettingstimer:ActiveTimerExists(WINTERSURPRISE_TIMERNAME) then
            StartWinterSurpriseSpawnTimer()
        end
    else
        StopRespawnTimer()
        _spawnsthiswinter = 0
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Register events
inst:ListenForEvent("ms_registerdeerspawningground", OnRegisterSurpriseSpawningPt)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------

function self:OnPostInit()
    self:WatchWorldState("iswinter", OnIsWinter)
    OnIsWinter(self, TheWorld.state.iswinter)
    _worldsettingstimer:AddTimer(WINTERSURPRISE_TIMERNAME, TUNING.WINTERSURPRISE_SPAWN_DELAY + TUNING.WINTERSURPRISE_SPAWN_DELAY_VARIANCE, TUNING.SPAWN_WINTERSURPRISE, OnRespawnWinterSurpriseTimer)
    -- TODO Spawn one instantly?
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    return
    {
        spawnsthiswinter = _spawnsthiswinter
    }
end

function self:OnLoad(data)
    if data.spawnsthiswinter then
        _spawnsthiswinter = data.spawnsthiswinter
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    return string.format("spawns for this winter:", _spawnsthiswinter)
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)