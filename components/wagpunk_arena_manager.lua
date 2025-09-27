local TILE_SCALE = TILE_SCALE

-- NOTES(JBK): This is heavily reliant on hermitcrab_01 static layout.
local TILESPOTS = { -- x, z, rot
    {-10,  -1, 0  },
    {-10,  -2, 270},
    {-10,  -3, 180},
    {-10,  -4, 270},
    {-10,  -5, 180},
    {-10,  -6, 270},
    {-10,  -7, 90 },
    {-10,  -8, 180},
    {-10,  -9, 90 },
    {-10, -10, 180},
    { -9,   0, 0  },
    { -9,  -6, 180},
    { -9,  -7, 270},
    { -9,  -8, 180},
    { -9, -11, 90 },
    { -8,   1, 0  },
    { -8,   0, 270},
    { -8, -12, 90 },
    { -7,   1, 270},
    { -6,   1, 90 },
    { -3,  -3, 270},
    { -3,  -4, 0  },
    { -3,  -5, 180},
    { -3, -12, 270},
    { -2,  -2, 0  },
    { -2,  -3, 180},
    { -2,  -4, 270},
    { -2,  -5, 90 },
    { -2,  -6, 180},
    { -2, -11, 0  },
    { -2, -12, 180},
    { -1,  -2, 270},
    { -1,  -3, 90 },
    { -1,  -4, 0  },
    { -1,  -5, 180},
    { -1,  -6, 270},
    { -1,  -7, 90 },
    { -1,  -8, 180},
    { -1,  -9, 0  },
    { -1, -10,  90},
    { -1, -11, 270},
    { -1, -12, 90 },
    {  0,  -2, 0  },
    {  0,  -3, 90 },
    {  0,  -4, 180},
    {  0,  -5, 90 },
    {  0,  -6, 270},
    {  0,  -7, 180},
    {  0,  -8, 0  },
    {  0,  -9, 180},
    {  0, -10, 0  },
    {  0, -11, 90 },
    {  0, -12, 270},
    {  1,   1, 0  },
    {  1,  -3, 270},
    {  1,  -4, 90 },
    {  1,  -5,   0},
    {  1,  -6, 180},
    {  1,  -7, 0  },
    {  1,  -8, 180},
    {  1,  -9, 270},
    {  1, -10, 0  },
    {  1, -11, 180},
    {  1, -12, 90 },
    {  2,  -5, 180},
    {  2,  -6, 270},
    {  2,  -7, 180},
    {  2,  -8, 270},
    {  2,  -9, 0  },
    {  2, -10, 90 },
    {  2, -11, 0  },
    {  3,  -6, 90 },
    {  3,  -7, 270},
    {  3,  -8, 180},
    {  3,  -9, 270},
    {  3, -10, 0  },
}

local STATES = {
    SPARKARK = 0, -- Waiting for Wagstaff to have given a Spark Ark.
    PEARLMAP = 1, -- Waiting for Pearl to get a map to leave the island.
    PEARLMOVE = 2, -- Waiting for Pearl to finish moving.
    TURF = 3, -- Waiting for the player to place the floor.
    CONSTRUCT = 4, -- Waiting for the player to place arena parts.
    LEVER = 5, -- Waiting for the lever switch.
    BOSS = 6, -- Waiting for boss defeat.
    BOSSCOOLDOWN = 7, -- Boss defeated and will not return until it is over.
}

local ARENA_CENTER_X = -3.5 * TILE_SCALE
local ARENA_CENTER_Z = -5.5 * TILE_SCALE

local WAGSTAFF_CENTER_X = -3 * TILE_SCALE + ARENA_CENTER_X
local WAGSTAFF_CENTER_Z = -5.5 * TILE_SCALE + ARENA_CENTER_Z

local ARENA_ENTITIES = {
    ["wagpunk_floor_marker"] = { -- Only one.
        {ARENA_CENTER_X, ARENA_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["wagpunk_arena_collision"] = { -- Only one.
        {ARENA_CENTER_X, ARENA_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["wagpunk_arena_collision_oneway"] = { -- Only one.
        {ARENA_CENTER_X, ARENA_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["wagpunk_lever"] = { -- Only one.
        {ARENA_CENTER_X, -1.5 * TILE_SCALE + ARENA_CENTER_Z, 0},
    },
    ["wagpunk_workstation"] = { -- Only one.
        {WAGSTAFF_CENTER_X, WAGSTAFF_CENTER_Z, 0},
    },
    ["junk_pile"] = {
        {-1.5 * TILE_SCALE + WAGSTAFF_CENTER_X, 1.0 * TILE_SCALE + WAGSTAFF_CENTER_Z, 0},
        {-1.0 * TILE_SCALE + WAGSTAFF_CENTER_X, -0.5 * TILE_SCALE + WAGSTAFF_CENTER_Z, 0},
        {1.5 * TILE_SCALE + WAGSTAFF_CENTER_X, -0.75 * TILE_SCALE + WAGSTAFF_CENTER_Z, 0},
        {1.25 * TILE_SCALE + WAGSTAFF_CENTER_X, 1.0 * TILE_SCALE + WAGSTAFF_CENTER_Z, 0},
    },
    ["fence_junk"] = {
        {-7.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-6.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-5.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-4.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-3.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-2.5 + WAGSTAFF_CENTER_X, 7.5 + WAGSTAFF_CENTER_Z, 270},
        {-1.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {-0.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {0.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {1.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {2.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {3.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {4.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {5.5 + WAGSTAFF_CENTER_X, 6.5 + WAGSTAFF_CENTER_Z, 270},
        {6.5 + WAGSTAFF_CENTER_X, 5.5 + WAGSTAFF_CENTER_Z, 315},
        {7.5 + WAGSTAFF_CENTER_X, 4.5 + WAGSTAFF_CENTER_Z, 0},
        {7.5 + WAGSTAFF_CENTER_X, 3.5 + WAGSTAFF_CENTER_Z, 0},
        {7.5 + WAGSTAFF_CENTER_X, 2.5 + WAGSTAFF_CENTER_Z, 0},
        {7.5 + WAGSTAFF_CENTER_X, 1.5 + WAGSTAFF_CENTER_Z, 0},
        {7.5 + WAGSTAFF_CENTER_X, 0.5 + WAGSTAFF_CENTER_Z, 0},
    },
    ["wagpunk_floor_placerindicator"] = {},
    ["wagdrone_spot_marker"] = { -- 6.
        {-3.0 * TILE_SCALE + ARENA_CENTER_X, -1.0 * TILE_SCALE + ARENA_CENTER_Z, 0},
        {-2.5 * TILE_SCALE + ARENA_CENTER_X, 2.0 * TILE_SCALE + ARENA_CENTER_Z, 0},
        {-1.0 * TILE_SCALE + ARENA_CENTER_X, -2.0 * TILE_SCALE + ARENA_CENTER_Z, 0},
        {1.0 * TILE_SCALE + ARENA_CENTER_X, 2.5 * TILE_SCALE + ARENA_CENTER_Z, 0},
        {1.5 * TILE_SCALE + ARENA_CENTER_X, -1.5 * TILE_SCALE + ARENA_CENTER_Z, 0},
        {3.0 * TILE_SCALE + ARENA_CENTER_X, 0.5 * TILE_SCALE + ARENA_CENTER_Z, 0},
    },
    ["wagboss_robot"] = { -- Only one.
        {ARENA_CENTER_X, ARENA_CENTER_Z, 0},
    },
    ["wagboss_robot_constructionsite_placerindicator"] = { -- Only one.
        {ARENA_CENTER_X, ARENA_CENTER_Z, 0},
    },
}
ARENA_ENTITIES["gestalt_cage_filled_placerindicator"] = deepcopy(ARENA_ENTITIES["wagdrone_spot_marker"])
for i, v in ipairs(TILESPOTS) do
    ARENA_ENTITIES["wagpunk_floor_placerindicator"][i] = {v[1] * TILE_SCALE, v[2] * TILE_SCALE, v[3]}
end

--------------------------------------------------------------------------
--[[ wagpunk_arena_manager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

local _world = TheWorld
assert(_world.ismastersim, "Wagpunk Arena Manager should not exist on the client!")
local _map = _world.Map
local WAGSTAFF_FLOOR = WORLD_TILES.WAGSTAFF_FLOOR

self.inst = inst
self.TILESPOTS = TILESPOTS
self.WALLSPOTS = deepcopy(WAGPUNK_ARENA_COLLISION_DATA)
for _, v in ipairs(self.WALLSPOTS) do -- Move from center to arena origin.
    v[1], v[2] = v[1] - 14, v[2] - 22 -- Hardcoded offsets.
end
self.ARENA_ENTITIES = ARENA_ENTITIES
self.STATES = STATES

self.pearlsentities = {}
self.arenaentities = {}
self.arenaprefabcounts = {}
self.wagdrones = {}
self.lunacycreators = {}

local function CheckStateForChanges_Bridge(inst)
    self.checktask = nil
    if not self.appliedrotationtransformation then
        if not self.failed then
            -- Reschedule a check later to let this finish loading.
            self.checktask = self.inst:DoTaskInTime(0, CheckStateForChanges_Bridge)
        end
        return
    end
    self:CheckStateForChanges()
end
function self:QueueCheck()
    if not self.checktask then
        self.checktask = self.inst:DoTaskInTime(0, CheckStateForChanges_Bridge)
    end
end

function self:GetStateString()
    if self.state == nil then
        return "SPARKARK"
    end

    for statename, stateid in pairs(self.STATES) do
        if self.state == stateid then
            return statename
        end
    end

    return "SPARKARK"
end

function self:ApplyRotationTransformation_Pearl(data)
    -- NOTES(JBK): This mapping is from the layout of hermitcrab_01 where the angle between the hermitcrab_marker and beebox_hermit is known from setpiece placement.
    -- The static layout default angle is 56.973 degrees.
    local angle = self.storedangle_pearl
    if angle > 0 then
        if angle < 45 then
            --print("Flip diagonal bottomleft to topright")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[2], v[1], 270 - v[3]
            end
        elseif angle < 90 then
            --print("No rotation")
        elseif angle < 135 then
            --print("Flip X")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[1], v[2], 180 - v[3]
            end
        else -- angle < 180
            --print("Rotate 90 left")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[2], v[1], v[3] - 90
            end
        end
    else
        if angle > -45 then
            --print("Rotate 90 right")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[2], -v[1], v[3] + 90
            end
        elseif angle > -90 then
            --print("Flip Y")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[1], -v[2], -v[3]
            end
        elseif angle > -135 then
            --print("Rotate 180 or flip X + Y")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[1], -v[2], 180 + v[3]
            end
        else -- angle > -180
            --print("Flip diagonal topleft to downright")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[2], -v[1], 90 - v[3]
            end
        end
    end
end
function self:ApplyRotationTransformation_Monkey(data)
    -- NOTES(JBK): This mapping is from the layout of monkeyisland_01 where the angle between the monkeyqueen and monkeyisland_portal is known from setpiece placement.
    -- The static layout default angle is -132.31622 degrees.
    local angle = self.storedangle_monkey
    if angle > 0 then
        if angle < 45 then
            --print("Flip diagonal topleft to downright")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[2], -v[1], 90 - v[3]
            end
        elseif angle < 90 then
            --print("Rotate 180 or flip X + Y")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[1], -v[2], 180 + v[3]
            end
        elseif angle < 135 then
            --print("Flip Y")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[1], -v[2], -v[3]
            end
        else -- angle < 180
            --print("Rotate 90 right")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[2], -v[1], v[3] + 90
            end
        end
    else
        if angle > -45 then
            --print("Rotate 90 left")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[2], v[1], v[3] - 90
            end
        elseif angle > -90 then
            --print("Flip X")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = -v[1], v[2], 180 - v[3]
            end
        elseif angle > -135 then
            --print("No rotation")
        else -- angle > -180
            --print("Flip diagonal bottomleft to topright")
            for _, v in ipairs(data) do
                v[1], v[2], v[3] = v[2], v[1], 270 - v[3]
            end
        end
    end
end

function self:ClearReferencesForRotationTransformation()
    if self.hermitcrab_marker then
        self.hermitcrab_marker:RemoveEventCallback("onremove", self.OnRemove_HermitCrabMarker)
        self.hermitcrab_marker = nil
    end
    if self.beebox_hermit then
        self.beebox_hermit:RemoveEventCallback("onremove", self.OnRemove_BeeBoxHermit)
        self.beebox_hermit = nil
    end
    if self.monkeyportal then
        self.monkeyportal:RemoveEventCallback("onremove", self.OnRemove_MonkeyPortal)
        self.monkeyportal = nil
    end
    if self.monkeyqueen then
        self.monkeyqueen:RemoveEventCallback("onremove", self.OnRemove_MonkeyQueen)
        self.monkeyqueen = nil
    end
end
function self:ApplyAllRotationTransformations()
    self.appliedrotationtransformation = true
    self:ApplyRotationTransformation_Pearl(self.TILESPOTS)
    self:ApplyRotationTransformation_Pearl(self.WALLSPOTS)
    for prefab, transformdata in pairs(self.ARENA_ENTITIES) do
        self:ApplyRotationTransformation_Pearl(transformdata)
    end
    self:ClearReferencesForRotationTransformation()
end
function self:TryToApplyRotationTransformation()
    if self.failed then
        self:ClearReferencesForRotationTransformation()
        if BRANCH == "staging" then
            c_announce("This world has too many important entities for wagpunk_arena_manager please upload the world to the bug tracker.")
        end
        return false
    end
    if self.appliedrotationtransformation then
        return true
    end

    if self.storedangle_pearl and self.storedangle_monkey then
        self:ApplyAllRotationTransformations()
        return true
    end

    if not self.storedangle_pearl and (not self.hermitcrab_marker or not self.beebox_hermit) then
        print("ERROR: wagpunk_arena_manager expected to be able to calculate the set piece angle using hermitcrab_marker and beebox_hermit but found neither of these.")
        if BRANCH == "staging" then
            c_announce("This world is missing important entities for wagpunk_arena_manager please upload the world to the bug tracker.")
        end
        return false
    end

    if not self.storedangle_monkey and (not self.monkeyqueen or not self.monkeyportal) then
        print("ERROR: wagpunk_arena_manager expected to be able to calculate the set piece angle using monkeyqueen and monkeyportal but found neither of these.")
        if BRANCH == "staging" then
            c_announce("This world is missing important entities for wagpunk_arena_manager please upload the world to the bug tracker.")
        end
        return false
    end

    if not self.storedangle_pearl then
        local x1, y1, z1 = self.hermitcrab_marker.Transform:GetWorldPosition()
        local x2, y2, z2 = self.beebox_hermit.Transform:GetWorldPosition()
        local tx, ty, tz = _map:GetTileCenterPoint(x2, y2, z2) -- Must use beebox origin because its spawn is not on a tile boundary.
        self.storedx_pearl, self.storedz_pearl = tx, tz
        self.storedangle_pearl = math.atan2(z2 - z1, x2 - x1) * RADIANS
    end

    if not self.storedangle_monkey then
        local x1, y1, z1 = self.monkeyqueen.Transform:GetWorldPosition()
        local x2, y2, z2 = self.monkeyportal.Transform:GetWorldPosition() -- Is in a good spot away from tile boundaries.
        local tx, ty, tz = _map:GetTileCenterPoint(x2, y2, z2)
        self.storedx_monkey, self.storedz_monkey = tx, tz
        self.storedangle_monkey = math.atan2(z2 - z1, x2 - x1) * RADIANS
    end

    self:ApplyAllRotationTransformations()
    return true
end

self.OnRemove_CageWall = function(cagewall, data)
    self.cagewalls[cagewall] = nil
end
function self:TrackCageWall(cagewall)
    self.cagewalls[cagewall] = true
    cagewall:ListenForEvent("onremove", self.OnRemove_CageWall)
end
function self:SpawnCageWalls()
    if self.cagewalls then
        return
    end

    self.cagewalls = {}
    for _, v in ipairs(self.WALLSPOTS) do
        local x, z, rot, sfxlooper = self.storedx_pearl + v[1], self.storedz_pearl + v[2], math.floor(v[3] / 90) * 90, v[4]
        local cagewall = SpawnPrefab("wagpunk_cagewall")
        cagewall.Transform:SetPosition(x, 0, z)
        cagewall.Transform:SetRotation(rot)
        if sfxlooper then
            cagewall.sfxlooper = true
        end
        self:TrackCageWall(cagewall)
    end
end


self.OnRemove_Lever = function(lever, data)
    self.lever = nil
end
function self:TrackLever(lever)
    self.lever = lever
    lever:ListenForEvent("onremove", self.OnRemove_Lever)
end

self.OnRemove_Workstation = function(workstation, data)
    self.workstation = nil
end
function self:TrackWorkstation(workstation)
    self.workstation = workstation
    workstation:ListenForEvent("onremove", self.OnRemove_Workstation)
end

self.OnRemove_Wagdrone = function(wagdrone, data)
    self.wagdrones[wagdrone] = nil
end
function self:TrackWagdrone(wagdrone)
    self.wagdrones[wagdrone] = true
    wagdrone:ListenForEvent("onremove", self.OnRemove_Wagdrone)
end
function self:IsTrackingWagdrone(wagdrone)
    return self.wagdrones[wagdrone] ~= nil
end

self.OnRemove_Wagboss = function(wagboss, data)
    self.wagboss = nil
end
function self:UntrackWagboss()
    if self.wagboss then
        self.wagboss:RemoveEventCallback("onremove", self.OnRemove_Wagboss)
        self.wagboss = nil
    end
end
function self:TrackWagboss(wagboss)
    self:UntrackWagboss()
    self.wagboss = wagboss
    wagboss:ListenForEvent("onremove", self.OnRemove_Wagboss)
end

self.validspotfn_clearthisarea = function(x, z, r)
    ClearSpotForRequiredPrefabAtXZ(x, z, r)
    return true
end
self.validspotfn_junk_pile = function(x, z, r)
    return not _map:IsOceanAtPoint(x, 0, z, false) and TheSim:CountEntities(x, 0, z, r) == 0
end
self.validspotfn_fence_junk = function(x, z, r)
    return not _map:IsOceanAtPoint(x, 0, z, false) and TheSim:CountEntities(x, 0, z, r) == 0
end
self.postinitfn_fence_junk = function(ent)
    ent:SetOrientation(ent.Transform:GetRotation()) -- Fixup fence rotation animations.
end

function self:SpawnWagstaffSetPiece()
    local levers = self:TryToSpawnArenaEntities("wagpunk_lever", self.validspotfn_clearthisarea)
    if levers then
        self:TrackLever(levers[1])
    end
    local workstations = self:TryToSpawnArenaEntities("wagpunk_workstation", self.validspotfn_clearthisarea)
    if workstations then
        self:TrackWorkstation(workstations[1])
    end
    self:TryToSpawnArenaEntities("junk_pile", self.validspotfn_junk_pile)
    self:TryToSpawnArenaEntities("fence_junk", self.validspotfn_fence_junk, self.postinitfn_fence_junk) -- Always last.
end

self.OnRemove_ArenaEntity = function(ent, data)
    self.arenaentities[ent] = nil
    local count = self.arenaprefabcounts[ent.prefab] or 0
    count = count - 1
    if count <= 0 then
        self.arenaprefabcounts[ent.prefab] = nil
    else
        self.arenaprefabcounts[ent.prefab] = count
    end
end
function self:TrackArenaEntity(ent)
    self.arenaentities[ent] = true
    local count = self.arenaprefabcounts[ent.prefab] or 0
    count = count + 1
    self.arenaprefabcounts[ent.prefab] = count
    ent:ListenForEvent("onremove", self.OnRemove_ArenaEntity)
end

function self:HasArenaEntity(prefab)
    return self.arenaprefabcounts[prefab] ~= nil
end

function self:TryToSpawnArenaEntities(prefab, validspotfn, postinitfn)
    local ents
    if not self:HasArenaEntity(prefab) then
        for _, v in ipairs(self.ARENA_ENTITIES[prefab]) do
            local x, z, rot = self.storedx_pearl + v[1], self.storedz_pearl + v[2], v[3]
            local ent = SpawnPrefab(prefab)
            if validspotfn == nil or validspotfn(x, z, ent:GetPhysicsRadius(0)) then
                ent.Transform:SetPosition(x, 0, z)
                ent.Transform:SetRotation(rot)
                if postinitfn then
                    postinitfn(ent)
                end
                self:TrackArenaEntity(ent)
                if ents then
                    table.insert(ents, ent)
                else
                    ents = {ent}
                end
            else
                ent:Remove()
            end
        end
    end
    return ents
end

function self:RemoveArenaEntities(prefab)
    for ent, _ in pairs(self.arenaentities) do
        if ent.prefab == prefab then
            ent:Remove()
        end
    end
end

function self:GetArenaSocketingInstFor(inst, item)
    if (item.prefab == "gestalt_cage_filled1" or item.prefab == "gestalt_cage_filled2") then
        if self:HasArenaEntity("wagdrone_spot_marker") then
            local closestent
            local smallestdsq = math.huge
            for ent, _ in pairs(self.arenaentities) do
                if ent.prefab == "wagdrone_spot_marker" then
                    local dsq = inst:GetDistanceSqToInst(ent)
                    if dsq < smallestdsq then
                        smallestdsq = dsq
                        closestent = ent
                    end
                end
            end
            return closestent
        end
    elseif item.prefab == "gestalt_cage_filled3" then
        if self.wagboss and not self.wagboss:IsSocketed() then
            return self.wagboss
        end
    end

    return nil
end

function self:TeleportWagstaffToWorkstation()
    local x, y, z = self.workstation.Transform:GetWorldPosition()
    local theta = math.random() * TWOPI
    local radius = self.workstation:GetPhysicsRadius(0) + self.wagstaff:GetPhysicsRadius(0) + 0.5
    local x2, z2 = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    self.wagstaff.Transform:SetPosition(x2, y, z2)
    self.wagstaff:ForceFacePoint(x, y, z)
end

function self:TeleportWagstaffToLever()
    local x, y, z = self.lever.Transform:GetWorldPosition()
    local theta = math.random() * TWOPI
    local radius = self.lever:GetPhysicsRadius(0) + self.wagstaff:GetPhysicsRadius(0) + 0.5
    local x2, z2 = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    self.wagstaff.Transform:SetPosition(x2, y, z2)
    self.wagstaff:ForceFacePoint(x, y, z)
end

local function WorkstationToggled_Bridge(workstation, on)
    self:WorkstationToggled(workstation, on)
end
function self:WorkstationToggled(workstation, on) -- Caller assumed to be from self.workstation only.
    if workstation ~= self.workstation then
        return -- Someone spawned this in!
    end

    if self.workstationtoggledtask then
        self.workstationtoggledtask:Cancel()
        self.workstationtoggledtask = nil
    end

    local wagboss_tracker = _world.components.wagboss_tracker
    if wagboss_tracker and wagboss_tracker:IsWagbossDefeated() then
        return -- No need to do anything here.
    end

    if on then
        self.workstationtoggledtask = self.workstation:DoTaskInTime(0.1, WorkstationToggled_Bridge, on) -- Always reschedule to handle Wagstaff state changes when next to the station.
        local wagstaff
        if self.state == self.STATES.SPARKARK then
            -- A player has activated a workstation before the questline is good for it.
            -- Do nothing but still reschedule in case the questline does advance.
        elseif self.state == self.STATES.PEARLMAP then
            -- Wagstaff wants Pearl off of the Island.
            wagstaff = self:TryToSpawnWagstaff()
            if wagstaff then
                wagstaff.arena_state = self.state
                wagstaff.tiedtoworkstation = true
                self:TeleportWagstaffToWorkstation()
                wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_PEARLMAP")
            end
        elseif self.state == self.STATES.PEARLMOVE then
            -- Waiting for Pearl finish moving.
            wagstaff = self:TryToSpawnWagstaff()
            if wagstaff then
                wagstaff.arena_state = self.state
                wagstaff.tiedtoworkstation = true
                self:TeleportWagstaffToWorkstation()
            elseif self.wagstaff and not self.wagstaff.erodingout and self.wagstaff.arena_state ~= self.STATES.PEARLMOVE then
                self.wagstaff.arena_state = self.state
                self.wagstaff.components.npc_talker:resetqueue()
                self.wagstaff.components.talker:ShutUp()
            end
        elseif self.state == self.STATES.TURF then
            -- Wagstaff wants the turf to be placed down to build up a good spot.
            wagstaff = self:TryToSpawnWagstaff()
            if wagstaff then
                wagstaff.arena_state = self.state
                wagstaff.tiedtoworkstation = true
                self:TeleportWagstaffToWorkstation()
                wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_TURF")
            elseif self.wagstaff and not self.wagstaff.erodingout and self.wagstaff.arena_state ~= self.STATES.TURF then
                self.wagstaff.arena_state = self.state
                self.wagstaff.components.npc_talker:resetqueue()
                self.wagstaff.components.talker:ShutUp()
                self.wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_TURF")
            end
        elseif self.state == self.STATES.CONSTRUCT then
            -- Wagstaff wants robots to be placed at set locations in the arena.
            if _world.components.lunaralterguardianspawner == nil or not _world.components.lunaralterguardianspawner:HasGuardianOrIsPending() then
                wagstaff = self:TryToSpawnWagstaff()
                if wagstaff then
                    wagstaff.arena_state = self.state
                    self:TeleportWagstaffToWorkstation()
                    if self:NeedsMoreWagdrones() then
                        wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT", math.random(#STRINGS.WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT))
                    else
                        wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT_BIGONE", math.random(#STRINGS.WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT_BIGONE))
                    end
                elseif self.wagstaff and not self.wagstaff.erodingout and self.wagstaff.arena_state ~= self.STATES.CONSTRUCT then
                    self.wagstaff.tiedtoworkstation = nil
                    self.wagstaff.arena_state = self.state
                    self.wagstaff.components.npc_talker:resetqueue()
                    self.wagstaff.components.talker:ShutUp()
                    if self:NeedsMoreWagdrones() then
                        self.wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT", math.random(#STRINGS.WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT))
                    else
                        self.wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT_BIGONE", math.random(#STRINGS.WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT_BIGONE))
                    end
                end
            end
        elseif self.state == self.STATES.LEVER then
            -- Wagstaff wants the lever to be thrown.
            wagstaff = self:TryToSpawnWagstaff()
            if wagstaff then
                wagstaff.arena_state = self.state
                wagstaff.tiedtolever = true
                self:TeleportWagstaffToWorkstation()
            elseif self.wagstaff then
                self.wagstaff.arena_state = self.state
                self.wagstaff.tiedtoworkstation = nil
                self.wagstaff.tiedtolever = true
            end
            if self.lever and self.lever.components.playerprox and not self.lever.components.playerprox:IsPlayerClose() then
                self:LeverToggled(self.lever, false)
            end
        elseif self.state == self.STATES.BOSS then
            if self.wagstaff then
                self.wagstaff:DoFadeOutIn(0)
            end
        elseif self.state == self.STATES.BOSSCOOLDOWN then
            if self.wagstaff then
                self.wagstaff:DoFadeOutIn(0)
            end
        end
    else
        if self.wagstaff then
            if self.wagstaff.tiedtoworkstation then
                self.wagstaff:DoFadeOutIn(0)
            end
        end
    end

    if self.wagstaff and not self.wagstaff.oneshot and not self.wagstaff.tiedtoworkstation and not self.wagstaff.tiedtolever then
        if not self.wagstaff.avoid_erodeout then
            local distsq = self.wagstaff:GetDistanceSqToClosestPlayer(true)
            if distsq > 64 then -- (2 * TILE_SCALE) ^ 2
                self.wagstaff:DoFadeOutIn(0)
            end
        end
        if self.wagstaff and not self.wagstaff.erodingout and not self.workstationtoggledtask then
            self.workstationtoggledtask = self.workstation:DoTaskInTime(0.1, WorkstationToggled_Bridge, on)
        end
    end
end

local function LeverToggled_Bridge(lever, on)
    self:LeverToggled(lever, on)
end
function self:LeverToggled(lever, on) -- Caller assumed to be from self.lever only.
    if lever ~= self.lever then
        return -- Someone spawned this in!
    end

    if self.levertoggledtask then
        self.levertoggledtask:Cancel()
        self.levertoggledtask = nil
    end

    local wagboss_tracker = _world.components.wagboss_tracker
    if wagboss_tracker and wagboss_tracker:IsWagbossDefeated() then
        return -- No need to do anything here.
    end
    
    if on then
        self.levertoggledtask = self.lever:DoTaskInTime(0.1, LeverToggled_Bridge, on) -- Always reschedule to handle Wagstaff state changes when next to the station.
        local wagstaff
        if self.state == self.STATES.LEVER then
            -- Wagstaff wants the lever to be thrown.
            wagstaff = self:TryToSpawnWagstaff()
            if wagstaff then
                wagstaff.arena_state = self.state
                wagstaff.tiedtolever = true
                self:TeleportWagstaffToLever()
            elseif self.wagstaff then
                self.wagstaff.arena_state = self.state
                self.wagstaff.tiedtoworkstation = nil
                self.wagstaff.tiedtolever = true
            end
        elseif self.state == self.STATES.BOSS then
            -- Lever thrown monologue handled out of here.
        elseif self.state == self.STATES.BOSSCOOLDOWN then
            if self.wagstaff then
                self.wagstaff:DoFadeOutIn(0)
            end
        end
    else
        if self.wagstaff then
            if self.wagstaff.tiedtolever then
                local distance = self.wagstaff:GetPhysicsRadius(0) + self.lever:GetPhysicsRadius(0) + 1
                if self.wagstaff:GetDistanceSqToInst(self.lever) < distance * distance then
                    self.wagstaff:DoFadeOutIn(0)
                else
                    self.levertoggledtask = self.lever:DoTaskInTime(0.1, LeverToggled_Bridge, on)
                end
            end
        end
    end
end

self.OnRemove_Wagstaff = function(wagstaff, data)
    self.wagstaff = nil
end
function self:TrackWagstaff(wagstaff)
    self.wagstaff = wagstaff
    wagstaff:ListenForEvent("onremove", self.OnRemove_Wagstaff)
end
function self:TryToSpawnWagstaff()
    if self.wagstaff then
        return nil -- One already is around, reschedule.
    end

    local wagboss_tracker = _world.components.wagboss_tracker
    if wagboss_tracker and wagboss_tracker:IsWagbossDefeated() then
        return nil -- Nope!
    end

    local wagstaff = SpawnPrefab("wagstaff_npc_wagpunk_arena")
    self:TrackWagstaff(wagstaff)
    wagstaff.sg:GoToState("idle", "idle_loop")
    return wagstaff
end

function self:CheckTurfCompletion()
    -- NOTES(JBK): Must check each time because mods might place the turf out of our area where a count would be optimal for this check.
    for _, v in ipairs(self.TILESPOTS) do
        local dtx, dtz = v[1], v[2]
        local x, z = self.storedx_pearl + dtx * TILE_SCALE, self.storedz_pearl + dtz * TILE_SCALE
        if _map:GetTileAtPoint(x, 0, z) ~= WAGSTAFF_FLOOR then
            return false
        end
    end

    self:TurfCompleted()
    return true
end

function self:CheckConstructCompleted()
    if self:HasArenaEntity("wagdrone_spot_marker") or self:HasArenaEntity("gestalt_cage_filled_placerindicator") then
        return false
    end

    if not self.wagboss then
        return false
    end

    if not self.wagboss:IsSocketed() then
        if not self.spawnedguardian then
            self.spawnedguardian = true
            if self.inst.components.lunaralterguardianspawner then
                self.inst.components.lunaralterguardianspawner:TrySpawnLunarGuardian(self.wagstaff or self.wagboss)
            end
            if self.wagstaff and not self.wagstaff.erodingout then
                self.wagstaff.components.npc_talker:resetqueue()
                self.wagstaff.components.talker:ShutUp()
                self.wagstaff.components.npc_talker:Chatter("WAGSTAFF_NPC_GOT_ENOUGH_GESTALTCAGE")
            end
        end
        return false
    end

    self:ConstructCompleted()
    return true
end

function self:SetState(state)
    self.state = state
    self:UpdateNetvars()
end

function self:SparkArkCompleted()
    if not self.sparkark then
        self.sparkark = true
        self:QueueCheck()
    end
end
function self:IsPearlMapValid(giver, item) -- item has tag "mapscroll"
    if not giver or not item then
        return false
    end

    if not item.components.maprecorder then
        return false
    end

    if not self.storedx_monkey or not self.storedz_monkey then
        return false
    end

    local tx, ty = _map:GetTileCoordsAtPoint(self.storedx_monkey, 0, self.storedz_monkey)
    return item.components.maprecorder:IsTileSeeableInRecordedMap(giver, tx, ty)
end
function self:IsPearlMapValidToPearl(giver, item)
    if item.prefab ~= "mapscroll_tricker" then
        return false
    end
    return self:IsPearlMapValid(giver, item)
end
function self:IsPearlMapValidToWagstaff(giver, item)
    if item.prefab == "mapscroll_tricker" then
        return false
    end
    return self:IsPearlMapValid(giver, item)
end
function self:HasPearlAcceptedAGoodMap()
    return self.pearlmap
end
function self:CanPearlShowRelocationItem()
    return self:HasPearlAcceptedAGoodMap() and self.state > self.STATES.PEARLMOVE
end
function self:ShouldPearlAcceptMaps()
    return self.state == self.STATES.PEARLMAP and not self:HasPearlAcceptedAGoodMap()
end
function self:ShouldWagstaffAcceptItem(inst, item, giver, count)
    inst.trader_chatterreason = nil
    if inst ~= self.wagstaff then
        return false
    end

    if inst.components.inventory:GetFirstItemInAnySlot() ~= nil then
        inst.trader_chatterreason = "WAGSTAFF_TOOMANYITEMS"
        return false
    end

    if self.state == self.STATES.PEARLMAP then
        if not item:HasTag("mapscroll") then
            inst.trader_chatterreason = "WAGSTAFF_GOT_NOT_MAPSCROLL"
            return false
        end

        if self:HasPearlAcceptedAGoodMap() then
            inst.trader_chatterreason = "WAGSTAFF_GOT_MAPSCROLL_NOLONGERNEEDED"
            return false
        end

        local success = self:IsPearlMapValidToWagstaff(giver, item)
        if not success then
            if item.prefab == "mapscroll_tricker" then
                inst.trader_chatterreason = "WAGSTAFF_MAPSCROLL_TRICKER"
            else
                inst.trader_chatterreason = "WAGSTAFF_GOT_MAPSCROLL_BAD"
            end
            return false
        end

        inst.trader_chatterreason = "WAGSTAFF_GOT_MAPSCROLL_GOOD"
        return true
    elseif self.state == self.STATES.CONSTRUCT then
        if item:HasTag("mapscroll") then
            inst.trader_chatterreason = "WAGSTAFF_GOT_MAPSCROLL_NOLONGERNEEDED"
            return false
        end

        if item:HasTag("gestalt_cage") then
            inst.trader_chatterreason = "WAGSTAFF_GOT_EMPTY_GESTALTCAGE"
            return false
        end

        if not item:HasTag("gestalt_cage_filled") then
            inst.trader_chatterreason = "WAGSTAFF_GOT_NOT_GESTALTCAGE"
            return false
        end

        local hasrolling, hasflying = false, false
        local spotsneeded = 0
        for ent, _ in pairs(self.wagdrones) do
            if ent.prefab == "wagdrone_rolling" then
                hasrolling = true
            elseif ent.prefab == "wagdrone_flying" then
                hasflying = true
            end
        end
        for ent, _ in pairs(self.arenaentities) do
            if ent.prefab == "wagdrone_spot_marker" or ent.prefab == "gestalt_cage_filled_placerindicator" then
                spotsneeded = spotsneeded + 1
            end
        end
        if hasrolling ~= hasflying and spotsneeded == 1 then
            if hasflying and item.prefab == "gestalt_cage_filled2" then
                inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_NOLONGERNEEDED"
                return false
            end
            if hasrolling and item.prefab == "gestalt_cage_filled1" then
                inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_NOLONGERNEEDED"
                return false
            end
        end
        if (item.prefab == "gestalt_cage_filled1" or item.prefab == "gestalt_cage_filled2") and (spotsneeded == 0) then
            if self.wagboss and not self.wagboss:IsSocketed() then
                inst.trader_chatterreason = "WAGSTAFF_WAGPUNK_ARENA_CONSTRUCT_BIGONE"
            else
                inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_NOLONGERNEEDED"
            end
            return false
        end
        if item.prefab == "gestalt_cage_filled3" and self.wagboss and self.wagboss:IsSocketed() then
            inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_NOLONGERNEEDED"
            return false
        end

        if item.prefab == "gestalt_cage_filled3" then
            inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_GOOD_BIGONE"
        else
            inst.trader_chatterreason = "WAGSTAFF_GOT_GESTALTCAGE_GOOD"
        end
        return true
    end

    return false
end
function self:NeedsMoreWagdrones()
    return self:HasArenaEntity("wagdrone_spot_marker") or self:HasArenaEntity("gestalt_cage_filled_placerindicator")
end
function self:PearlMapCompleted()
    if not self.pearlmap then
        self.pearlmap = true
        self:QueueCheck()

        local hermitcrab_relocation_manager = _world.components.hermitcrab_relocation_manager
        if hermitcrab_relocation_manager then
            hermitcrab_relocation_manager:SetupMovingPearlToMonkeyIsland()
        end
    end
end
function self:PearlMoveCompleted()
    if not self.pearlmove then
        self.pearlmove = true
        self:QueueCheck()
    end
end
function self:TurfCompleted()
    if not self.turfed then
        self.turfed = true
        self:QueueCheck()
    end
end
function self:ConstructCompleted()
    if not self.constructed then
        self.constructed = true
        self:QueueCheck()
    end
end
function self:IsWagbossRobot()
    return self.wagboss and self.wagboss.prefab == "wagboss_robot"
end
function self:LeverCompleted()
    if not self.levered then
        self.levered = true
        self:QueueCheck()
    end
    
    if not self.lever then
        return
    end

    if self:IsWagbossRobot() then
        local x, y, z = self.lever.Transform:GetWorldPosition()
        local radius = self.lever:GetPhysicsRadius(0) + 1
        if not self.wagstaff then
            local theta = math.random() * PI2
            x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
        end
        self:DoWagstaffOneshotAtXZ(x, z, radius, "WAGSTAFF_WAGPUNK_ARENA_LEVERPULLED", true, nil)
    end
end

function self:OnRobotLoseControl()
    if not self.wagboss then
        return
    end

    local focusent = self.wagboss:GetNearestPlayer(true)
    if focusent == nil or not _map:IsPointInWagPunkArena(focusent.Transform:GetWorldPosition()) then
        focusent = self.wagboss
    end
    local x, y, z = focusent.Transform:GetWorldPosition()
    local radius = focusent:GetPhysicsRadius(0) + 3
    if not self.wagstaff then
        local theta = math.random() * PI2
        x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    end
    self:DoWagstaffOneshotAtXZ(x, z, radius, "WAGSTAFF_WAGPUNK_ARENA_ROBOTLOSTCONTROL", false, nil)
end

function self:BossCompleted()
    if self.despawngraceperiodtask then
        self.despawngraceperiodtask:Cancel()
        self.despawngraceperiodtask = nil
    end
    if not self:IsWagbossRobot() then
        for wagdrone, _ in pairs(self.wagdrones) do
            self.wagdrones[wagdrone] = nil
        end
    end
    if not self.bossed then
        self.bossed = true
        self:QueueCheck()
    end
end

local function BossCooldownFinished_Bridge()
    self:BossCooldownFinished()
end
function self:BossCooldownFinished()
    if self.bosscooldowntask ~= nil then
        self.bosscooldowntask:Cancel()
        self.bosscooldowntask = nil
    end
    self:SetState(self.STATES.CONSTRUCT)
    self:QueueCheck()
end

function self:AddWagbossDefeatedRecipes()
    if self.workstation then
        self.workstation.components.craftingstation:LearnItem("wagboss_robot_constructionsite_kit", "wagboss_robot_constructionsite_kit")
        self.workstation.components.craftingstation:LearnItem("wagboss_robot_creation_parts", "wagboss_robot_creation_parts")
        self.workstation.components.craftingstation:LearnItem("wagpunk_workstation_moonstorm_static_catcher", "wagpunk_workstation_moonstorm_static_catcher")
        self.workstation.components.craftingstation:LearnItem("wagpunk_workstation_security_pulse_cage", "wagpunk_workstation_security_pulse_cage")
    end
end

function self:CheckStateForChanges_Internal()
    if self.state == self.STATES.SPARKARK then
        if self.sparkark then
            self:SetState(self.STATES.PEARLMAP)
            return true
        end
        -- Wait for Spark Ark to be completed.
    elseif self.state == self.STATES.PEARLMAP then
        if self.pearlmap then
            self:SetState(self.STATES.PEARLMOVE)
            return true
        end
        self:SpawnWagstaffSetPiece()
    elseif self.state == self.STATES.PEARLMOVE then
        if self.pearlmove then
            self:SetState(self.STATES.TURF)
            return true
        end
        -- Pearl has been given a map to get off of the island and will move there over time.
        -- Wait for Pearl to finish moving through the event listener.
    elseif self.state == self.STATES.TURF then
        if self.turfed then
            self:SetState(self.STATES.CONSTRUCT)
            return true
        end
        self:TryToSpawnArenaEntities("wagpunk_floor_marker") -- Self managed for setup.
        self:TryToSpawnArenaEntities("wagpunk_floor_placerindicator") -- Floor decal helpers to direct the player.
        if self.workstation then
            self.workstation.components.craftingstation:LearnItem("wagpunk_floor_kit", "wagpunk_floor_kit")
        end

        if self.wagstaff then
            self.wagstaff:RemoveComponent("trader")
        end
    elseif self.state == self.STATES.CONSTRUCT then
        if self.constructed then
            self:SetState(self.STATES.LEVER)
            return true
        end
        self:RemoveArenaEntities("wagpunk_floor_placerindicator") -- Just in case.
        local wagboss_tracker = _world.components.wagboss_tracker
        local wagboss_defeated = wagboss_tracker and wagboss_tracker:IsWagbossDefeated()
        if wagboss_defeated then
            self:TryToSpawnArenaEntities("wagboss_robot_constructionsite_placerindicator", self.validspotfn_clearthisarea)
        else
            if next(self.wagdrones) == nil then
                self:TryToSpawnArenaEntities("wagdrone_spot_marker", self.validspotfn_clearthisarea)
            end
            local wagboss_robots = self:TryToSpawnArenaEntities("wagboss_robot", self.validspotfn_clearthisarea)
            if wagboss_robots then
                self:TrackWagboss(wagboss_robots[1])
            end
        end
        if self.wagstaff then
            self.wagstaff:AddTrader()
        end
        if self.workstation then
            self.workstation.components.craftingstation:LearnItem("gestalt_cage", "gestalt_cage")
        end
    elseif self.state == self.STATES.LEVER then
        if self.levered then
            self:SetState(self.STATES.BOSS)
            return true
        end
        self:RemoveArenaEntities("wagdrone_spot_marker") -- Just in case.
        self:RemoveArenaEntities("gestalt_cage_filled_placerindicator") -- Just in case.
        self:SpawnCageWalls()
        if self.lever then
            self.lever:ExtendLever()
        end
        if self.wagstaff then
            self.wagstaff:RemoveComponent("trader")
        end
    elseif self.state == self.STATES.BOSS then
        if self.bossed then -- Loop back for repeating the fight.
            if self.wagboss == nil or IsEntityDead(self.wagboss) then
                -- Boss is dead go on cooldown and reset task flags back to construct.
                self.levered = nil
                self.bossed = nil
                self.constructed = nil
                self.spawnedguardian = nil
                self.givencage = nil
                local wagboss_tracker = _world.components.wagboss_tracker
                if wagboss_tracker and wagboss_tracker:IsWagbossDefeated() then
                    self:AddWagbossDefeatedRecipes()
                    self:SetState(self.STATES.CONSTRUCT)
                else
                    self:SetState(self.STATES.BOSSCOOLDOWN)
                    if self.bosscooldowntask ~= nil then
                        self.bosscooldowntask:Cancel()
                        self.bosscooldowntask = nil
                    end
                    self.bosscooldowntask = self.inst:DoTaskInTime(TUNING.WAGPUNK_ARENA_WAGBOSS_ROBOT_COOLDOWN_DEFEATED_TIME, BossCooldownFinished_Bridge)
                end
            else
                -- The boss won make it go back to the center and reset the arena.
                self.levered = nil
                self.bossed = nil
                self:SetState(self.STATES.LEVER)
            end

            if self.cagewalls then
                for cagewall, _ in pairs(self.cagewalls) do
                    cagewall:RetractWallWithJitter(0.4)
                end
            end
            if self.collision and self.collision:IsValid() then
                self.collision:Remove()
            end
            self.collision = nil
            if self.collision_oneway and self.collision_oneway:IsValid() then
                self.collision_oneway:Remove()
            end
            self.collision_oneway = nil
            self:UnlockPlayers()
            return true
        end
        -- Do nothing and wait for boss defeated.
        if self.cagewalls then
            for cagewall, _ in pairs(self.cagewalls) do
                cagewall:ExtendWallWithJitter(0.4)
            end
        end
        if not self.collision then
            local collisions = self:TryToSpawnArenaEntities("wagpunk_arena_collision")
            if collisions then
                self.collision = collisions[1]
                self.collision.Transform:SetRotation(0) -- Collision meshes do not get rotation.
                self.collision:DestroyEntitiesInBarrier()
            end
            local collision_oneways = self:TryToSpawnArenaEntities("wagpunk_arena_collision_oneway")
            if collision_oneways then
                self.collision_oneway = collision_oneways[1]
                self.collision_oneway.Transform:SetRotation(0) -- Collision meshes do not get rotation.
            end
        end
        if self.lever then
            self.lever:RetractLever()
        end
        if self.wagboss then
            self.wagboss:PushEvent("activate")
        end
        self:LockPlayersIn()
    elseif self.state == self.STATES.BOSSCOOLDOWN then
        -- We wait.
    end
    return false
end

local function DoWagstaffOneshotAtXZ_Bridge(inst, x, z, radiusopt, lines, oneline, postinitfn)
    self:DoWagstaffOneshotAtXZ(x, z, radiusopt, lines, oneline, postinitfn)
end
function self:DoWagstaffOneshotAtXZ(x, z, radiusopt, lines, oneline, postinitfn)
    local linesindex
    if oneline then
        linesindex = math.random(#STRINGS[lines])
    end
    if self.wagstaff then
        if not self.wagstaff.erodingout then
            self.wagstaff.tiedtoworkstation = nil
            self.wagstaff.tiedtolever = nil
            self.wagstaff.oneshot = true
            self.wagstaff.desiredlocation = Vector3(x, 0, z)
            self.wagstaff.desiredlocationdistance = radiusopt
            self.wagstaff.components.npc_talker:resetqueue()
            self.wagstaff.components.talker:ShutUp()
            self.wagstaff.components.npc_talker:Chatter(lines, linesindex)
            if postinitfn then
                postinitfn(self.wagstaff)
            end
        else
            self.inst:DoTaskInTime(0.1, DoWagstaffOneshotAtXZ_Bridge, x, z, radiusopt, lines, oneline, postinitfn) -- Reschedule until Wagstaff is done fading away.
        end
    else
        local wagstaff = self:TryToSpawnWagstaff()
        if wagstaff then
            wagstaff.oneshot = true
            wagstaff.Transform:SetPosition(x, 0, z)
            wagstaff.components.npc_talker:Chatter(lines, linesindex)
            if postinitfn then
                postinitfn(self.wagstaff)
            end
            -- Do not reschedule here this means Wagstaff cannot be spawned.
        end
    end
end

local function SendResetRobotBossEvent_Bridge()
    self:SendResetRobotBossEvent()
end
function self:SendResetRobotBossEvent()
    if self.wagboss then
        self.wagboss:PushEvent("doreset")
    end
end

function self:ResetRobotBoss()
    if self.despawngraceperiodtask then
        self.despawngraceperiodtask:Cancel()
        self.despawngraceperiodtask = nil
    end
    if self:IsWagbossRobot() then
        if next(self.playersdata.disconnected) and not next(self.playersdata.players) then
            self.despawngraceperiodtask = self.inst:DoTaskInTime(TUNING.WAGPUNK_ARENA_WAGBOSS_ROBOT_DESPAWN_GRACE_TIME, SendResetRobotBossEvent_Bridge)
        else
            self:SendResetRobotBossEvent()
        end
    end
end

function self:DecrementAliveCount()
    local count = self.playersdata.alivecount - 1
    self.playersdata.alivecount = count
    if count <= 0 then
        self:ResetRobotBoss()
    end
end
function self:IncrementAliveCount()
    local count = self.playersdata.alivecount + 1
    self.playersdata.alivecount = count
    if self.despawngraceperiodtask then
        self.despawngraceperiodtask:Cancel()
        self.despawngraceperiodtask = nil
    end
end

self.OnPlayerJoined = function(world, player)
    if self.playersdata.disconnected[player.userid] then
        self.playersdata.disconnected[player.userid] = nil
        self:TrackPlayer(player)
    end
end

self.OnPlayerRemove = function(player, data)
    self.playersdata.disconnected[player.userid] = true
    self:StopTrackingPlayer(player)
end
self.OnPlayerBecameGhost = function(player, data)
    if self.playersdata.players[player] ~= false then
        self.playersdata.players[player] = false
        self:DecrementAliveCount()
    end
end
self.OnPlayerRespawnedFromGhost = function(player, data)
    if self.playersdata.players[player] ~= true then
        self.playersdata.players[player] = true
        self:IncrementAliveCount()
    end
end
function self:StopTrackingPlayer(player)
    local isalive = self.playersdata.players[player]
    self.playersdata.players[player] = nil
    player:RemoveEventCallback("onremove", self.OnPlayerRemove)
    player:RemoveEventCallback("ms_becameghost", self.OnPlayerBecameGhost)
    player:RemoveEventCallback("ms_respawnedfromghost", self.OnPlayerRespawnedFromGhost)
    if isalive then
        self:DecrementAliveCount()
    end
    if player:IsValid() and player.components.sanity then
        player.components.sanity:EnableLunacy(false, "wagpunk_arena")
    end
    _world:PushEvent("ms_wagpunk_barrier_playerleft", player)
end
function self:TrackPlayer(player)
    local isalive = not IsEntityDeadOrGhost(player)
    self.playersdata.players[player] = isalive
    player:ListenForEvent("onremove", self.OnPlayerRemove)
    player:ListenForEvent("ms_becameghost", self.OnPlayerBecameGhost)
    player:ListenForEvent("ms_respawnedfromghost", self.OnPlayerRespawnedFromGhost)
    if isalive then
        self:IncrementAliveCount()
    end
    if self.lunacymode and player.components.sanity then
        player.components.sanity:EnableLunacy(true, "wagpunk_arena")
    end
    _world:PushEvent("ms_wagpunk_barrier_playerentered", player)
end

function self:StartLunacy()
    if self.lunacymode then
        return
    end

    self.lunacymode = true
    if self.playersdata then
        for player, _ in pairs(self.playersdata.players) do
            if player.components.sanity then
                player.components.sanity:EnableLunacy(true, "wagpunk_arena")
            end
        end
    end
end
function self:StopLunacy()
    if not self.lunacymode then
        return
    end

    self.lunacymode = nil
    if self.playersdata then
        for player, _ in pairs(self.playersdata.players) do
            if player.components.sanity then
                player.components.sanity:EnableLunacy(false, "wagpunk_arena")
            end
        end
    end
end
function self:LockPlayersIn()
    if not self.playersdata then
        self.playersdata = {
            players = {}, -- Player instances that are marked for the fight. Format: players[player] = isalive
            alivecount = 0,
            disconnected = {}, -- Player KUs who left when marked for the fight. Format: disconnected[ku] = true
        }
        for _, player in ipairs(AllPlayers) do
            local x, _, z = player.Transform:GetWorldPosition()
            local inarena = _map:IsPointInWagPunkArena(x, 0, z)
            if inarena then
                self:TrackPlayer(player)
            end
        end

        self.inst:ListenForEvent("ms_playerjoined", self.OnPlayerJoined)

        self.inst:StartUpdatingComponent(self)
    end
end
function self:UnlockPlayers()
    if self.playersdata then
        self.inst:StopUpdatingComponent(self)

        self.inst:RemoveEventCallback("ms_playerjoined", self.OnPlayerJoined)

        self:StopLunacy()
        for player, _ in pairs(self.playersdata.players) do
            if player.components.sanity then
                player.components.sanity:EnableLunacy(false, "wagpunk_arena")
            end
            player:RemoveEventCallback("onremove", self.OnPlayerRemove)
            player:RemoveEventCallback("ms_becameghost", self.OnPlayerBecameGhost)
            player:RemoveEventCallback("ms_respawnedfromghost", self.OnPlayerRespawnedFromGhost)
        end
        self.playersdata = nil
    end
end

self.updateaccumulator = 0
self.UPDATE_TICK_TIME = 1
function self:OnUpdate(dt)
    self.updateaccumulator = self.updateaccumulator + dt
    if self.updateaccumulator > self.UPDATE_TICK_TIME then
        self.updateaccumulator = 0
        if self.playersdata then
            for _, player in ipairs(AllPlayers) do
                local x, _, z = player.Transform:GetWorldPosition()
                local inarena = _map:IsPointInWagPunkArena(x, 0, z)
                local shouldbeinarena = self.playersdata.players[player] ~= nil
                -- NOTES(JBK): Some things will cause the player to get into or out of the arena outside of our control like physics bunching.
                -- Intead of trying to find every case for that we will make the player dynamically count for the fight.
                -- FIXME(JBK): WA: Known issue list: Wanda revive, Winona revive, Winona teleport, Meat Effigy.
                if not inarena and shouldbeinarena then
                    self:StopTrackingPlayer(player)
                elseif inarena and not shouldbeinarena then
                    self:TrackPlayer(player)
                end
            end
        end
    end
end

function self:CheckStateForChanges() -- This can only be called if the transformation was applied so we have arena coordinates.
    while self:CheckStateForChanges_Internal() do
        -- Keep going.
    end
end

local function UpdateNetvars_Bridge()
    self:UpdateNetvars()
end
function self:UpdateNetvars()
    if self.updatenetvarstask ~= nil then -- Let this function repeat entry safe.
        self.updatenetvarstask:Cancel()
        self.updatenetvarstask = nil
    end
    local wagpunk_floor_helper = _world.net and _world.net.components.wagpunk_floor_helper
    if not wagpunk_floor_helper then
        self.updatenetvarstask = self.inst:DoTaskInTime(0, UpdateNetvars_Bridge) -- Reschedule.
        return
    end

    local isactive = self.state == self.STATES.BOSS
    if wagpunk_floor_helper.barrier_active:value() ~= isactive then
        wagpunk_floor_helper.barrier_active:set(isactive)
        _world:PushEvent("ms_wagpunk_barrier_isactive", isactive)
    end
end
function self:OnInit()
    self:TryToApplyRotationTransformation()
    if not self.state then
        self:SetState(self.STATES.SPARKARK)
        self:QueueCheck()
    end
    self:UpdateNetvars()
end

function self:OnSave()
    local data, ents = {}, {}

    data.storedangle_pearl = self.storedangle_pearl
    data.storedx_pearl = self.storedx_pearl
    data.storedz_pearl = self.storedz_pearl

    data.storedangle_monkey = self.storedangle_monkey
    data.storedx_monkey = self.storedx_monkey
    data.storedz_monkey = self.storedz_monkey

    data.sparkark = self.sparkark
    data.pearlmap = self.pearlmap
    data.pearlmove = self.pearlmove
    data.turfed = self.turfed
    data.spawnedguardian = self.spawnedguardian
    data.givencage = self.givencage
    data.constructed = self.constructed
    data.levered = self.levered
    data.bossed = self.bossed

    if self.state ~= self.STATES.SPARKARK then
        data.state = self:GetStateString()
    end

    if self.cagewalls then
        data.cagewalls = {}
        for cagewall, _ in pairs(self.cagewalls) do
            table.insert(data.cagewalls, cagewall.GUID)
            table.insert(ents, cagewall.GUID)
        end
    end
    if self.lever then
        data.lever = self.lever.GUID
        table.insert(ents, self.lever.GUID)
    end
    if self.workstation then
        data.workstation = self.workstation.GUID
        table.insert(ents, self.workstation.GUID)
    end
    if self.wagboss then
        data.wagboss = self.wagboss.GUID
        table.insert(ents, self.wagboss.GUID)
    end
    if self.wagstaff then
        data.wagstaff = self.wagstaff.GUID
        table.insert(ents, self.wagstaff.GUID)
        data.w_tiedtoworkstation = self.wagstaff.tiedtoworkstation
        data.w_tiedtolever = self.wagstaff.tiedtolever
        data.w_state = self.wagstaff.arena_state
    end
    if next(self.arenaentities) then
        data.arenaentities = {}
        for ent, _ in pairs(self.arenaentities) do
            if ent.persists then -- For temporary entities like collision.
                table.insert(data.arenaentities, ent.GUID)
                table.insert(ents, ent.GUID)
            end
        end
        if not next(data.arenaentities) then
            data.arenaentities = nil
        end
    end
    if next(self.wagdrones) then
        data.wagdrones = {}
        for ent, _ in pairs(self.wagdrones) do
            table.insert(data.wagdrones, ent.GUID)
            table.insert(ents, ent.GUID)
        end
    end
    if self.playersdata then
        local disconnected = {}
        for playeruserid, _ in pairs(self.playersdata.disconnected) do
            table.insert(disconnected, playeruserid)
        end
        for player, _ in pairs(self.playersdata.players) do
            table.insert(disconnected, player.userid)
        end
        if disconnected[1] then
            data.disconnected = disconnected
        end
    end
    if self.bosscooldowntask then
        data.bosscooldownremaining = GetTaskRemaining(self.bosscooldowntask)
    end
    return data, ents
end

function self:OnLoad(data)
    if not data then
        return
    end

    self.storedangle_pearl = data.storedangle_pearl
    self.storedx_pearl = data.storedx_pearl
    self.storedz_pearl = data.storedz_pearl

    self.storedangle_monkey = data.storedangle_monkey
    self.storedx_monkey = data.storedx_monkey
    self.storedz_monkey = data.storedz_monkey

    self.sparkark = data.sparkark
    self.pearlmap = data.pearlmap
    self.pearlmove = data.pearlmove
    self.turfed = data.turfed
    self.spawnedguardian = data.spawnedguardian
    self.givencage = data.givencage
    self.constructed = data.constructed
    self.levered = data.levered
    self.bossed = data.bossed

    if data.disconnected then
        local disconnected = {}
        for _, playeruserid in ipairs(data.disconnected) do
            disconnected[playeruserid] = true
        end
        if next(disconnected) then
            self.playersdata = {
                players = {},
                alivecount = 0,
                disconnected = disconnected,
            }
        end
    end
    if data.bosscooldownremaining then
        local remainingtime = math.min(1, data.bosscooldownremaining) -- NOTES(JBK): The boss cooldown is no longer a real state when wagstaff is defeated the boss is fresh.
        self.bosscooldowntask = self.inst:DoTaskInTime(remainingtime, BossCooldownFinished_Bridge)
    end

    if data.state then
        self:SetState(self.STATES[data.state] or self.STATES.SPARKARK)
        self:QueueCheck()
    end
end

function self:LoadPostPass(newents, savedata)
    if savedata.cagewalls then
        self.cagewalls = {}
        for _, cagewallguid in ipairs(savedata.cagewalls) do
            if newents[cagewallguid] then
                local cagewall = newents[cagewallguid].entity
                self:TrackCageWall(cagewall)
            end
        end
    end
    if savedata.lever then
        if newents[savedata.lever] then
            local lever = newents[savedata.lever].entity
            self:TrackLever(lever)
        end
    end
    if savedata.workstation then
        if newents[savedata.workstation] then
            local workstation = newents[savedata.workstation].entity
            self:TrackWorkstation(workstation)
        end
    end
    if savedata.wagboss then
        if newents[savedata.wagboss] then
            local wagboss = newents[savedata.wagboss].entity
            self:TrackWagboss(wagboss)
        end
    end
    if savedata.wagstaff then
        if newents[savedata.wagstaff] then
            local wagstaff = newents[savedata.wagstaff].entity
            wagstaff.tiedtoworkstation = savedata.w_tiedtoworkstation
            wagstaff.tiedtolever = savedata.w_tiedtolever
            wagstaff.arena_state = savedata.w_state
            self:TrackWagstaff(wagstaff)
        end
    end
    if savedata.arenaentities then
        for _, entguid in ipairs(savedata.arenaentities) do
            if newents[entguid] then
                local ent = newents[entguid].entity
                self:TrackArenaEntity(ent)
            end
        end
    end
    if savedata.wagdrones then
        for _, entguid in ipairs(savedata.wagdrones) do
            if newents[entguid] then
                local wagdrone = newents[entguid].entity
                self:TrackWagdrone(wagdrone)
            end
        end
    end

    if self.state == self.STATES.CONSTRUCT then
        self:CheckConstructCompleted()
    end
    if self.playersdata then
        self.inst:ListenForEvent("ms_playerjoined", self.OnPlayerJoined)
        self.inst:StartUpdatingComponent(self)
    end

    local wagboss_tracker = _world.components.wagboss_tracker
    if wagboss_tracker and wagboss_tracker:IsWagbossDefeated() then
        self:AddWagbossDefeatedRecipes() -- Retrofit pass.
    end
end

self.OnRemove_HermitCrabMarker = function(ent, data)
    self.hermitcrab_marker = nil
end
function self:RegisterHermitCrabMarker(ent)
    if self.appliedrotationtransformation then
        return
    end
    if self.hermitcrab_marker then
        print("ERROR: wagpunk_arena_manager expected only one hermitcrab_marker in the world but encountered multiple most likely from mods.")
        self.failed = true
        return
    end

    self.hermitcrab_marker = ent
    ent:ListenForEvent("onremove", self.OnRemove_HermitCrabMarker)
end

self.OnRemove_BeeBoxHermit = function(ent, data)
    self.beebox_hermit = nil
end
function self:RegisterBeeBoxHermit(ent)
    if self.appliedrotationtransformation then
        return
    end
    if self.beebox_hermit then
        print("ERROR: wagpunk_arena_manager expected only one beebox_hermit in the world but encountered multiple most likely from mods.")
        self.failed = true
        return
    end

    self.beebox_hermit = ent
    ent:ListenForEvent("onremove", self.OnRemove_BeeBoxHermit)
end

self.OnRemove_PearlEntity = function(ent, data)
    self.pearlsentities[ent] = nil
end
function self:RegisterPearlEntity(ent)
    self.pearlsentities[ent] = true
    ent:ListenForEvent("onremove", self.OnRemove_PearlEntity)
end

self.OnRemove_HermitCrab = function(ent, data)
    self.hermitcrab = nil
end
function self:RegisterHermitCrab(ent)
    self.hermitcrab = ent
    ent:ListenForEvent("onremove", self.OnRemove_HermitCrab)
end


self.OnRemove_MonkeyPortal = function(ent, data)
    self.monkeyportal = nil
end
function self:RegisterMonkeyPortal(ent)
    if self.appliedrotationtransformation then
        return
    end
    if self.monkeyportal then
        print("ERROR: wagpunk_arena_manager expected only one monkeyportal in the world but encountered multiple most likely from mods.")
        self.failed = true
        return
    end

    self.monkeyportal = ent
    ent:ListenForEvent("onremove", self.OnRemove_MonkeyPortal)
end

self.OnRemove_MonkeyQueen = function(ent, data)
    self.monkeyqueen = nil
end
function self:RegisterMonkeyQueen(ent)
    if self.appliedrotationtransformation then
        return
    end
    if self.monkeyqueen then
        print("ERROR: wagpunk_arena_manager expected only one monkeyqueen in the world but encountered multiple most likely from mods.")
        self.failed = true
        return
    end

    self.monkeyqueen = ent
    ent:ListenForEvent("onremove", self.OnRemove_MonkeyQueen)
end

self.OnRemove_LunacyCreator = function(ent, data)
    self.lunacycreators[ent] = nil
    if next(self.lunacycreators) == nil then
        self:StopLunacy()
    end
end
function self:RegisterLunacyCreator(ent)
    self.lunacycreators[ent] = true
    ent:ListenForEvent("onremove", self.OnRemove_LunacyCreator)
    self:StartLunacy()
end

self.OnWagstaffSpawned_GiveGestaltCage = function(wagstaff)
    self.tryingtogivecage = nil
    self.givencage = true
    wagstaff.wantingcage = true
    wagstaff:GiveGestaltCageToToss()
end
function self:DoWagstaffGiveGestaltCage(ent)
    local x, z
    if ent then
        local y
        x, y, z = ent.Transform:GetWorldPosition()
    else
        x, z = _map:GetWagPunkArenaCenterXZ()
    end
    local player = FindClosestPlayer(x, 0, z, true)
    if player then
        local px, py, pz = player.Transform:GetWorldPosition()
        if _map:IsPointInWagPunkArena(px, 0, pz) then
            x, z = px, pz
        end
    end

    local theta = math.random() * TWOPI
    local radius = 3
    local x2, z2 = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    self:DoWagstaffOneshotAtXZ(x2, z2, radius, "WAGSTAFF_WAGPUNK_ARENA_GIVE_GESTALT_CAGE", true, self.OnWagstaffSpawned_GiveGestaltCage)
end
function self:TryWagstaffGiveGestaltCage(ent)
    if self.givencage or self.tryingtogivecage then
        return
    end
    self.tryingtogivecage = true
    self:DoWagstaffGiveGestaltCage(ent)
end
function self:GetTotalDronePlacementCount()
    local dronecount = 0
    for ent, _ in pairs(self.wagdrones) do
        if ent.prefab == "wagdrone_rolling" or ent.prefab == "wagdrone_flying" then
            dronecount = dronecount + 1
        end
    end
    return dronecount
end


self.inst:ListenForEvent("ms_register_hermitcrab_marker", function(inst, ent) self:RegisterHermitCrabMarker(ent) end, _world)
self.inst:ListenForEvent("ms_register_beebox_hermit", function(inst, ent) self:RegisterBeeBoxHermit(ent) end, _world)
self.inst:ListenForEvent("ms_register_hermitcrab", function(inst, ent) self:RegisterHermitCrab(ent) end, _world)
self.inst:ListenForEvent("ms_register_pearl_entity", function(inst, ent) self:RegisterPearlEntity(ent) end, _world)

self.inst:ListenForEvent("ms_register_monkeyisland_portal", function(inst, ent) self:RegisterMonkeyPortal(ent) end, _world)
self.inst:ListenForEvent("ms_register_monkeyqueen", function(inst, ent) self:RegisterMonkeyQueen(ent) end, _world)

self.inst:ListenForEvent("ms_register_wagpunk_arena_lunacycreator", function(inst, ent) self:RegisterLunacyCreator(ent) end, _world)

self.inst:ListenForEvent("ms_lunarriftmutationsmanager_taskcompleted", function(inst) self:SparkArkCompleted() end, _world)
self.inst:ListenForEvent("ms_hermitcrab_relocated", function(inst) self:PearlMoveCompleted() end, _world)
self.inst:ListenForEvent("ms_wagpunk_floor_kit_deployed", function(inst) self:CheckTurfCompletion() end, _world)
self.inst:ListenForEvent("ms_wagpunk_constructrobot", function(inst) self:CheckConstructCompleted() end, _world)
self.inst:ListenForEvent("ms_wagpunk_lever_activated", function(inst) self:LeverCompleted() end, _world)
self.inst:ListenForEvent("ms_wagboss_robot_losecontrol", function(inst) self:OnRobotLoseControl() end, _world)
self.inst:ListenForEvent("ms_wagboss_alter_defeated", function(inst, ent) self:UntrackWagboss() self:BossCompleted() end, _world)
self.inst:ListenForEvent("ms_alterguardian_phase1_lunarrift_capturable", function(inst, ent) self:TryWagstaffGiveGestaltCage(ent) end, _world)
self.inst:ListenForEvent("ms_wagboss_robot_turnoff", function(inst) if self.state == self.STATES.BOSS then self:BossCompleted() end end, _world)
self.inst:ListenForEvent("ms_wagboss_robot_constructed", function(inst, ent)
    self:TrackWagboss(ent)
    if next(self.wagdrones) == nil then
        self:TryToSpawnArenaEntities("gestalt_cage_filled_placerindicator", self.validspotfn_clearthisarea)
    end
end, _world)
self.inst:ListenForEvent("ms_wagstaff_arena_oneshot", function(inst, data)
    if data then
        local strname, monologue, focusentity = data.strname, data.monologue, data.focusentity
        local xoverride, zoverride = data.x, data.z
        local callback = data.cb

        if not strname then
            return
        end

        local x, y, z
        if xoverride then
            x, z = xoverride, zoverride
        elseif focusentity then
            x, y, z = focusentity.Transform:GetWorldPosition()
        else
            x, z = _map:GetWagPunkArenaCenterXZ()
        end
        if not x then
            return
        end

        local radius = 2.5
        if focusentity then
            radius = radius + focusentity:GetPhysicsRadius(0)
        end

        local x2, z2
        if not xoverride then
            local theta = math.random() * TWOPI
            x2, z2 = x + math.cos(theta) * radius, z + math.sin(theta) * radius
        else
            x2, z2 = x, z
        end
        self:DoWagstaffOneshotAtXZ(x2, z2, radius, strname, not monologue, callback)
    end
end, _world)
self.inst:ListenForEvent("ms_wagboss_snatched_wagstaff", function(inst) if self.wagstaff then self.wagstaff:Remove() end end, _world)

self.inst:DoTaskInTime(0, function() self:OnInit() end)


function self:DebugForcePearl()
    -- Pearl's Pearl is needed for CC questline and that means at least 10 tasks and her home has been upgraded.
    local doer = ThePlayer or _world
    local hermithouse
    repeat
        hermithouse = nil
        for ent, _ in pairs(self.pearlsentities) do
            if ent.prefab == "hermithouse_construction1" or ent.prefab == "hermithouse_construction2" or ent.prefab == "hermithouse_construction3" then
                hermithouse = ent
                hermithouse.components.constructionsite:ForceCompletion(doer)
                break
            end
        end
    until hermithouse == nil
    if self.hermitcrab then
        self.hermitcrab.components.friendlevels:CompleteAllTasks(doer)
    end
end
local INDICATOR_MUST_TAGS = {"CLASSIFIED", "wagpunk_floor_placerindicator"}
function self:DebugForceTurf()
    for _, v in ipairs(self.TILESPOTS) do
        local dtx, dtz = v[1], v[2]
        local pt = Vector3(self.storedx_pearl + dtx * TILE_SCALE, 0, self.storedz_pearl + dtz * TILE_SCALE)

        local tile_x, tile_y = _map:GetTileCoordsAtPoint(pt.x, 0, pt.z)

        _map:SetTile(tile_x, tile_y, WORLD_TILES.WAGSTAFF_FLOOR)
    
        local tx, ty, tz = _map:GetTileCenterPoint(pt.x, pt.y, pt.z)
        local ents = TheSim:FindEntities(tx, ty, tz, 1, INDICATOR_MUST_TAGS)
        for _, ent in ipairs(ents) do
            ent:Remove()
        end
    
        ents = _map:GetEntitiesOnTileAtPoint(pt.x, 0, pt.z)
        for _, ent in ipairs(ents) do
            if ent:HasTag("winchtarget") then
                local x, y, z = ent.Transform:GetWorldPosition()
                local failed = false
                local ox, oz = _map:GetNearbyOceanPointFromXZ(x, z, 10)
                if ox then
                    ent.Transform:SetPosition(ox, y, oz)
                    ent:PushEvent("teleported")
                    local fx = SpawnPrefab("splash_sink")
                    fx.Transform:SetPosition(ox, y, oz)
                else -- If the scan fails we will just uproot the salvage this tile is permanent so having things under it would be unobtainable.
                    local salvaged_item = ent.components.winchtarget:Salvage()
                    if salvaged_item then
                        if salvaged_item.components.inventoryitem and salvaged_item.components.inventoryitem:IsHeld() then
                            salvaged_item = salvaged_item.components.inventoryitem:RemoveFromOwner(true)
                        end
                        if salvaged_item then
                            salvaged_item.Transform:SetPosition(x, y, z)
                            salvaged_item:PushEvent("on_salvaged")
                        end
                    end
                    ent:Remove()
                end
            end
        end
    end
end
function self:DebugForceConstruct()
    if self.wagboss then
        self.wagboss:SocketCage()
    end
    if self:HasArenaEntity("wagdrone_spot_marker") or self:HasArenaEntity("gestalt_cage_filled_placerindicator") then
        for ent, _ in pairs(self.arenaentities) do
            if ent.prefab == "wagdrone_spot_marker" or ent.prefab == "gestalt_cage_filled_placerindicator" then
                if math.random() < 0.5 then
                    ReplacePrefab(ent, "wagdrone_rolling")
                else
                    ReplacePrefab(ent, "wagdrone_flying")
                end
            end
        end
    end
end
function self:DebugSkipState()
    print("Completing state:", self:GetStateString())
    if self.state == self.STATES.SPARKARK then
        self:DebugForcePearl()
        self:SparkArkCompleted()
    elseif self.state == self.STATES.PEARLMAP then
        self:PearlMapCompleted()
    elseif self.state == self.STATES.PEARLMOVE then
        self:PearlMoveCompleted()
    elseif self.state == self.STATES.TURF then
        self:DebugForceTurf()
        self:TurfCompleted()
    elseif self.state == self.STATES.CONSTRUCT then
        self:DebugForceConstruct()
        self:ConstructCompleted()
    elseif self.state == self.STATES.LEVER then
        self:LeverCompleted()
    elseif self.state == self.STATES.BOSS then
        if self.wagboss then
            if self.wagboss.prefab == "wagboss_robot" and not self.wagboss.hostile then
                self.wagboss:ConfigureHostile()
            end
            if self.wagboss.components.health then
                print("  By killing the boss.", self.wagboss)
                self.wagboss.components.health:Kill()
            else
                print("  CANNOT PROCEED boss has no health component yet.", self.wagboss)
            end
        else
            print("  By advancing the state with no boss tracked.")
            self:BossCompleted()
        end
    elseif self.state == self.STATES.BOSSCOOLDOWN then
        self:BossCooldownFinished()
    end
end
function self:DebugPrintFlags()
    print("sparkark:", self.sparkark)
    print("pearlmap:", self.pearlmap)
    print("pearlmove:", self.pearlmove)
    print("turfed:", self.turfed)
    print("constructed:", self.constructed)
    print("levered:", self.levered)
    print("bossed:", self.bossed)
end

end)