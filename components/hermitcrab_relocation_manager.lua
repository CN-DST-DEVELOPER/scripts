local TILE_SCALE = TILE_SCALE

local MONKEYISLAND_CENTER_X = 3 * TILE_SCALE
local MONKEYISLAND_CENTER_Z = 0 * TILE_SCALE

local PEARLSETPIECE_CENTER_X = 2 * TILE_SCALE + MONKEYISLAND_CENTER_X
local PEARLSETPIECE_CENTER_Z = -4 * TILE_SCALE + MONKEYISLAND_CENTER_Z

-- NOTES(JBK): This is heavily reliant on monkeyisland_01 static layout for position and hermitcrab_01 for entities.
local PEARLSETPIECE_MONKEYISLAND = { -- x, z, rot
    ["hermitcrab_marker"] = { -- 1
        {MONKEYISLAND_CENTER_X, MONKEYISLAND_CENTER_Z, 0}, -- Place at island center this is an achievement marker for island center point.
    },
    ["hermitcrab_lure_marker"] = { -- 1
        {PEARLSETPIECE_CENTER_X - 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 1 * TILE_SCALE, 0}, -- Place where lureplant bulbs are created.
    },
    ["hermitcrab_marker_fishing"] = { -- 16 in coastal tiles knight's move away max from land
        {PEARLSETPIECE_CENTER_X + 2 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 3 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 3 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 2 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 4 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 1 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z, 0},
        {PEARLSETPIECE_CENTER_X + 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 1 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 2 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 3 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X + 5 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 4 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 6 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 3 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 7 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 2 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 8 * TILE_SCALE, PEARLSETPIECE_CENTER_Z - 1 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 9 * TILE_SCALE, PEARLSETPIECE_CENTER_Z, 0},
        {PEARLSETPIECE_CENTER_X - 9 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 1 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 9 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 2 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 9 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 3 * TILE_SCALE, 0},
        {PEARLSETPIECE_CENTER_X - 9 * TILE_SCALE, PEARLSETPIECE_CENTER_Z + 4 * TILE_SCALE, 0},
    },
    ["hermithouse"] = { -- 1
        {PEARLSETPIECE_CENTER_X, PEARLSETPIECE_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["hermithouse_construction1"] = { -- 1
        {PEARLSETPIECE_CENTER_X, PEARLSETPIECE_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["hermithouse_construction2"] = { -- 1
        {PEARLSETPIECE_CENTER_X, PEARLSETPIECE_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["hermithouse_construction3"] = { -- 1
        {PEARLSETPIECE_CENTER_X, PEARLSETPIECE_CENTER_Z, 0}, -- Center of arena is on a tile corner.
    },
    ["hermitcrab"] = { -- 1 or 0
        {PEARLSETPIECE_CENTER_X + 2.5, PEARLSETPIECE_CENTER_Z, 0},
    },
    ["meatrack_hermit"] = { -- 6
        {PEARLSETPIECE_CENTER_X + 4.4, PEARLSETPIECE_CENTER_Z + 7.3, 0},
        {PEARLSETPIECE_CENTER_X + 7.6, PEARLSETPIECE_CENTER_Z + 4.1, 0},
        {PEARLSETPIECE_CENTER_X + 8.4, PEARLSETPIECE_CENTER_Z + 0.3, 0},
        {PEARLSETPIECE_CENTER_X + 9.3, PEARLSETPIECE_CENTER_Z + 7.7, 0},
        {PEARLSETPIECE_CENTER_X + 11.9, PEARLSETPIECE_CENTER_Z + 2.6, 0},
        {PEARLSETPIECE_CENTER_X + 13.1, PEARLSETPIECE_CENTER_Z + 6.8, 0},
    },
    ["beebox_hermit"] = { -- 1
        {PEARLSETPIECE_CENTER_X - 4 * TILE_SCALE - 2.3, PEARLSETPIECE_CENTER_Z + 2.3, 0},
    },
}

--------------------------------------------------------------------------
--[[ hermitcrab_relocation_manager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

local _world = TheWorld
assert(_world.ismastersim, "Hermitcrab Relocation Manager should not exist on the client!")
local _map = _world.Map

self.inst = inst
self.PEARLSETPIECE_MONKEYISLAND = PEARLSETPIECE_MONKEYISLAND

self.pearlsentities = {}

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
    for prefab, transformdata in pairs(self.PEARLSETPIECE_MONKEYISLAND) do
        self:ApplyRotationTransformation_Monkey(transformdata)
    end
    self:ClearReferencesForRotationTransformation()
end
function self:TryToApplyRotationTransformation()
    if self.failed then
        self:ClearReferencesForRotationTransformation()
        if BRANCH == "staging" then
            c_announce("This world has too many important entities for hermitcrab_relocation_manager please upload the world to the bug tracker.")
        end
        return false
    end
    if self.appliedrotationtransformation then
        return true
    end

    if self.storedangle_monkey then
        self:ApplyAllRotationTransformations()
        return true
    end

    if not self.storedangle_monkey and (not self.monkeyqueen or not self.monkeyportal) then
        print("ERROR: hermitcrab_relocation_manager expected to be able to calculate the set piece angle using monkeyqueen and monkeyportal but found neither of these.")
        if BRANCH == "staging" then
            c_announce("This world is missing important entities for hermitcrab_relocation_manager please upload the world to the bug tracker.")
        end
        return false
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

self.validspotfn_clearthisarea = function(x, z, r)
    ClearSpotForRequiredPrefabAtXZ(x, z, r)
    return true
end

local TELEPORT_TIME_FX_SYNC = 12 * FRAMES
function self:OnFinishedTeleportPearlEntity(ent, deleted)
    if not deleted then
        ent:RemoveEventCallback("onremove", self.OnRemove_TeleportingPearlEntity)
        if ent == self.hermitcrab then
            ent.sg.mem.teleporting = nil
        end
        ent:PushEvent("teleported")
    end
    self.pearlmovingdata[ent] = nil
    if next(self.pearlmovingdata) == nil then
        self.pearlmovingdata = nil
        self.initiatedpearlmove = nil
        _world:PushEvent("ms_hermitcrab_relocated")
    end
end
self.OnRemove_TeleportingPearlEntity = function(ent, data)
    self:OnFinishedTeleportPearlEntity(ent, true)
end
self.TeleportingStep_Arrive = function(ent)
    ent:ReturnToScene()
    self:OnFinishedTeleportPearlEntity(ent)
end
self.TeleportingStep_Appear = function(ent)
    local movingdata = self.pearlmovingdata[ent]
    if movingdata.fxprefab and not ent:IsAsleep() then
        local fx = SpawnPrefab(movingdata.fxprefab)
        fx.Transform:SetPosition(movingdata.x, 0, movingdata.z)
        ent:DoTaskInTime(TELEPORT_TIME_FX_SYNC, self.TeleportingStep_Arrive)
    else
        self.TeleportingStep_Arrive(ent)
    end
end
self.TeleportingStep_Teleport = function(ent)
    local movingdata = self.pearlmovingdata[ent]
    local radius = ent:GetPhysicsRadius(0)
    ent:RemoveFromScene()
    if movingdata.fxprefab then -- We have visuals for everything that is mandatory to move.
        self.validspotfn_clearthisarea(movingdata.x, movingdata.z, radius)
    end
    ent.Transform:SetPosition(movingdata.x, 0, movingdata.z)
    ent.Transform:SetRotation(movingdata.rot)
    if movingdata.fxprefab and not ent:IsAsleep() then
        ent:DoTaskInTime(movingdata.delay, self.TeleportingStep_Appear)
    else
        self.TeleportingStep_Arrive(ent)
    end
end
self.TeleportingStep_Disappear = function(ent)
    local movingdata = self.pearlmovingdata[ent]
    if movingdata.fxprefab and not ent:IsAsleep() then
        local ex, ey, ez = ent.Transform:GetWorldPosition()
        local fx = SpawnPrefab(movingdata.fxprefab)
        fx.Transform:SetPosition(ex, ey, ez)
        ent:DoTaskInTime(TELEPORT_TIME_FX_SYNC, self.TeleportingStep_Teleport)
    else
        self.TeleportingStep_Teleport(ent)
    end
end

function self:InitiatePearlTeleport()
    local pearlmovingdata = self.pearlmovingdata -- NOTES(JBK): This value can be set to nil if it finishes moving before the iterator is done so we get a cache.
    if not self.initiatedpearlmove then
        self.initiatedpearlmove = true
        for ent, _ in pairs(self.pearlsentities) do
            local movingdata = pearlmovingdata[ent]
            if movingdata then -- From load can have partial finish teleports.
                if movingdata.fxprefab and not ent:IsAsleep() then
                    ent:DoTaskInTime(movingdata.delay, self.TeleportingStep_Disappear)
                else
                    self.TeleportingStep_Teleport(ent)
                end
            end
        end
    end
end

function self:CanPearlMove()
    return self.pearlmovingdata == nil
end

function self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, prefab, fxprefab)
    local index = 1
    for ent, _ in pairs(self.pearlsentities) do
        if ent.prefab == prefab then
            local piecedata = setpiecedata[prefab]
            if piecedata then
                local v = piecedata[index]
                if v then
                    ent:ListenForEvent("onremove", self.OnRemove_TeleportingPearlEntity)
                    local x, z, rot = centerx + v[1], centerz + v[2], v[3]
                    local delaycounter = self.pearlmovingcounter
                    self.pearlmovingcounter = delaycounter + 1
                    local delay = delaycounter * 0.25 + math.random() * 0.25
                    local movingdata = {
                        x = x, z = z,
                        rot = rot,
                        delay = delay,
                        fxprefab = fxprefab,
                    }
                    self.pearlmovingdata[ent] = movingdata
                    index = index + 1
                elseif BRANCH == "staging" then
                    c_announce("This world has too many hermitcrab entities for hermitcrab_relocation_manager default teleporting please upload the world to the bug tracker.")
                end
            end
        end
    end
end

function self:SetupTeleportingPearlToSetPieceData(setpiecedata, centerx, centerz)
    -- NOTES(JBK): Argument setpiecedata is expected to be in the format of PEARLSETPIECE_MONKEYISLAND above.
    self.pearlmovingdata = {}
    self.pearlmovingcounter = 0
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermithouse", "hermitcrab_fx_tall")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermithouse_construction1", "hermitcrab_fx_tall")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermithouse_construction2", "hermitcrab_fx_tall")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermithouse_construction3", "hermitcrab_fx_tall")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "beebox_hermit", "hermitcrab_fx_small")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "meatrack_hermit", "hermitcrab_fx_med")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermitcrab", "hermitcrab_fx_small")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermitcrab_marker")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermitcrab_lure_marker")
    self:SetupTeleportingPearlEntityWithSetPieceData(setpiecedata, centerx, centerz, "hermitcrab_marker_fishing")
    self.pearlmovingcounter = nil
    if next(self.pearlmovingdata) == nil then
        self.pearlmovingdata = nil
    else
        if self.hermitcrab then
            self.hermitcrab.sg.mem.teleporting = true
            if self.hermitcrab:IsAsleep() or self.hermitcrab:HasTag("INLIMBO") then
                self:InitiatePearlTeleport()
            else
                local bufferedaction = self.hermitcrab:GetBufferedAction()
                if bufferedaction and bufferedaction.action == ACTIONS.GOHOME then
                    self.hermitcrab.components.locomotor:Stop()
                    self.hermitcrab.components.locomotor:Clear()
                end
            end
        else
            self:InitiatePearlTeleport()
        end
    end
end
function self:SetupMovingPearlToMonkeyIsland()
    self:SetupTeleportingPearlToSetPieceData(self.PEARLSETPIECE_MONKEYISLAND, self.storedx_monkey, self.storedz_monkey)
end

function self:OnInit()
    self:TryToApplyRotationTransformation()
end

function self:OnSave()
    local data, ents = {}, {}

    data.storedangle_monkey = self.storedangle_monkey
    data.storedx_monkey = self.storedx_monkey
    data.storedz_monkey = self.storedz_monkey

    if self.pearlmovingdata then
        data.movingents = {}
        for ent, movingdata in pairs(self.pearlmovingdata) do
            table.insert(data.movingents, {
                guid = ent.GUID,
                data = movingdata,
            })
            table.insert(ents, ent.GUID)
        end
    end

    return data, ents
end

function self:OnLoad(data)
    if not data then
        return
    end

    self.storedangle_monkey = data.storedangle_monkey
    self.storedx_monkey = data.storedx_monkey
    self.storedz_monkey = data.storedz_monkey
end

function self:LoadPostPass(newents, savedata)
    if savedata.movingents then
        self.pearlmovingdata = {}
        for _, entdata in ipairs(savedata.movingents) do
            if newents[entdata.guid] then
                local ent = newents[entdata.guid].entity
                local movingdata = entdata.data
                self.pearlmovingdata[ent] = movingdata
            end
        end
        self:InitiatePearlTeleport()
    end
end

self.OnRemove_MonkeyPortal = function(ent, data)
    self.monkeyportal = nil
end
function self:RegisterMonkeyPortal(ent)
    if self.appliedrotationtransformation then
        return
    end
    if self.monkeyportal then
        print("ERROR: hermitcrab_relocation_manager expected only one monkeyportal in the world but encountered multiple most likely from mods.")
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
        print("ERROR: hermitcrab_relocation_manager expected only one monkeyqueen in the world but encountered multiple most likely from mods.")
        self.failed = true
        return
    end

    self.monkeyqueen = ent
    ent:ListenForEvent("onremove", self.OnRemove_MonkeyQueen)
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

self.inst:ListenForEvent("ms_register_hermitcrab", function(inst, ent) self:RegisterHermitCrab(ent) end, _world)
self.inst:ListenForEvent("ms_register_pearl_entity", function(inst, ent) self:RegisterPearlEntity(ent) end, _world)

self.inst:ListenForEvent("ms_register_monkeyisland_portal", function(inst, ent) self:RegisterMonkeyPortal(ent) end, _world)
self.inst:ListenForEvent("ms_register_monkeyqueen", function(inst, ent) self:RegisterMonkeyQueen(ent) end, _world)

self.inst:DoTaskInTime(0, function() self:OnInit() end)

end)