local LeafpileManager = Class(function(self, inst)
    self.inst = inst

    local _world = TheWorld
    assert(_world.ismastersim, "Component LeafpileManager should not exist on the client.")
    local _map = _world.Map
    local _worldstate = _world.state

    local PLACEMENT_REGION_SIZE = TUNING.LEAFPILEMANAGER_SPACING * TILE_SCALE
    local PLACEMENT_MAX_DENSITY = TUNING.LEAFPILEMANAGER_DENSITY
    local PLACEMENT_SECONDS_PER_SPAWN = TUNING.LEAFPILEMANAGER_SECONDS_PER_SPAWN
    local PLACEMENT_SECONDS_PER_DESPAWN = TUNING.LEAFPILEMANAGER_SECONDS_PER_DESPAWN
    self.accumulator = 0
    self.enabled = false
    self.leafpiles = {}
    self.leafpilescount = 0

    --self.leafpilegrid = nil
    local WIDTH, HEIGHT
    local function initialize_grids()
        if self.leafpilegrid ~= nil then
            return
        end

        WIDTH, HEIGHT = _map:GetSize()
        self.leafpilegrid = DataGrid(WIDTH, HEIGHT)
    end
    self.inst:ListenForEvent("worldmapsetsize", initialize_grids, _world)

    function self:GetGridCoordsForPlacement(x, z)
        return math.floor(x / PLACEMENT_REGION_SIZE) * PLACEMENT_REGION_SIZE, math.floor(z / PLACEMENT_REGION_SIZE) * PLACEMENT_REGION_SIZE
    end

    local function UnregisterLeafpile_Bridge(leafpile)
        self:UnregisterLeafpile(leafpile)
    end
    function self:UnregisterLeafpile(leafpile)
        local leafpilegriddataindex = self.leafpiles[leafpile]
        if not leafpilegriddataindex then
            return -- Spawned in leafpile prefabs are not registered.
        end

        local leafpilegriddata = self.leafpilegrid:GetDataAtIndex(leafpilegriddataindex)
        leafpilegriddata.count = leafpilegriddata.count - 1
        self.leafpilescount = self.leafpilescount - 1
        if leafpilegriddata.count <= 0 then
            self.leafpilegrid:SetDataAtIndex(leafpilegriddataindex, nil)
        end
        self.leafpiles[leafpile] = nil
        if leafpile:IsValid() then
            leafpile:RemoveEventCallback("onremove", UnregisterLeafpile_Bridge)
        end
    end
    function self:RegisterLeafpile(leafpile)
        local x, y, z = leafpile.Transform:GetWorldPosition()
        local gx, gz = self:GetGridCoordsForPlacement(x, z)
        local leafpilegriddataindex = self.leafpilegrid:GetIndex(gx, gz)
        local leafpilegriddata = self.leafpilegrid:GetDataAtIndex(leafpilegriddataindex)
        if not leafpilegriddata then
            leafpilegriddata = {
                count = 0,
            }
            self.leafpilegrid:SetDataAtIndex(leafpilegriddataindex, leafpilegriddata)
        end
        self.leafpiles[leafpile] = leafpilegriddataindex
        leafpilegriddata.count = leafpilegriddata.count + 1
        self.leafpilescount = self.leafpilescount + 1
        leafpile:ListenForEvent("onremove", UnregisterLeafpile_Bridge)
    end

    self.NoLeafpileTest = function(map, x, y, z)
        local tile = map:GetTileAtPoint(x, y, z)
        if tile ~= WORLD_TILES.DECIDUOUS then
            return false
        end

        if TheSim:CountEntities(x, y, z, MAX_PHYSICS_RADIUS) > 0 then
            return false
        end

        local gx, gz = self:GetGridCoordsForPlacement(x, z)
        local leafpilegriddata = self.leafpilegrid:GetDataAtPoint(gx, gz)
        if leafpilegriddata and leafpilegriddata.count >= PLACEMENT_MAX_DENSITY then
            return false
        end

        return true
    end

    function self:TryToCreateLeafpileAtPoint(x, y, z, skipleafpiletest)
        if not skipleafpiletest and not self.NoLeafpileTest(_map, x, y, z) then
            return false
        end

        local leafpile = SpawnPrefab("leafpile")
        leafpile.Transform:SetPosition(x, y, z)
        self:RegisterLeafpile(leafpile)
        leafpile:OnPlaced()
        return true
    end

    function self:TryToCreateLeafpileAnywhere()
        local pt = _map:FindRandomPointWithFilter(50, self.NoLeafpileTest)
        if pt then
            return self:TryToCreateLeafpileAtPoint(pt.x, pt.y, pt.z, true)
        end
        return false
    end

    function self:TryToCreateLeafpileForEachPlayer()
        for _, player in ipairs(AllPlayers) do
            if player:GetCurrentPlatform() == nil then
                local x, y, z = player.Transform:GetWorldPosition()
                for i = 1, 10 do
                    local r = math.random() * (PLAYER_CAMERA_SEE_DISTANCE - MAX_PHYSICS_RADIUS) + MAX_PHYSICS_RADIUS
                    local theta = math.random() * TWOPI
                    -- Intentionally skewing density to be closer to the player.
                    local dx, dz = math.cos(theta) * r, math.sin(theta) * r
                    if self:TryToCreateLeafpileAtPoint(x + dx, y, z + dz) then
                        break
                    end
                end
            end
        end
    end

    function self:SetEnabled(enabled)
        if self.enabled ~= enabled then
            self.enabled = enabled
            if enabled then
                self.inst:StartUpdatingComponent(self)
            end
        end
        return enabled
    end
    function self:TryToEnable()
        if not IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) then
            return false
        end

        return self:SetEnabled(self.isautumn or false)
    end

    function self:OnIsAutumnChanged(isautumn)
        self.isautumn = isautumn
        self:TryToEnable()
    end
    local function OnIsAutumnChanged_Bridge(inst, isautumn)
        self:OnIsAutumnChanged(isautumn)
    end
    self.inst:WatchWorldState("isautumn", OnIsAutumnChanged_Bridge)

    function self:OnIsWinterChanged(iswinter)
        self.iswinter = iswinter
    end
    local function OnIsWinterChanged_Bridge(inst, iswinter)
        self:OnIsWinterChanged(iswinter)
    end
    self.inst:WatchWorldState("iswinter", OnIsWinterChanged_Bridge)

    function self:OnPostInit()
        self:OnIsAutumnChanged(_worldstate.isautumn)
        self:OnIsWinterChanged(_worldstate.iswinter)
    end

    function self:OnUpdate(dt)
        self.accumulator = self.accumulator + dt
        if not self.enabled then
            if self.accumulator > PLACEMENT_SECONDS_PER_DESPAWN then
                self.accumulator = self.accumulator % PLACEMENT_SECONDS_PER_DESPAWN
                if not self.iswinter then
                    local leafpile = next(self.leafpiles)
                    if leafpile then
                        leafpile:Decay() -- This component assumes that leafpile will :Remove() itself in this call.
                    end
                end
                if self.leafpilescount <= 0 then
                    self.inst:StopUpdatingComponent(self)
                    return
                end
            end
        else
            if self.accumulator > PLACEMENT_SECONDS_PER_SPAWN then
                self.accumulator = self.accumulator % PLACEMENT_SECONDS_PER_SPAWN
                self:TryToCreateLeafpileAnywhere()
                self:TryToCreateLeafpileForEachPlayer()
            end
        end
    end

    function self:OnSave()
        if next(self.leafpiles) then
            local data, ents = {}, {}
            data.leafpiles = {}
            for leafpile, _ in pairs(self.leafpiles) do
                table.insert(data.leafpiles, leafpile.GUID)
                table.insert(ents, leafpile.GUID)
            end
            return data, ents
        end
    end

    function self:LoadPostPass(newents, savedata)
        if savedata.leafpiles then
            for _, leafpileguid in ipairs(savedata.leafpiles) do
                if newents[leafpileguid] then
                    local leafpile = newents[leafpileguid].entity
                    self:RegisterLeafpile(leafpile)
                end
            end
            if self.leafpilescount > 0 then
                self.inst:StartUpdatingComponent(self)
            end
        end
    end
end)

return LeafpileManager
