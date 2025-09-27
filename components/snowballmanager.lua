local SnowballManager = Class(function(self, inst)
    self.inst = inst

    local _world = TheWorld
    assert(_world.ismastersim, "Component SnowballManager should not exist on the client.")
    local _map = _world.Map
    local _worldstate = _world.state

    local SNOWBALL_REGION_SIZE = TUNING.SNOWBALLMANAGER_SPACING * TILE_SCALE
    local SNOWBALL_MAX_DENSITY = TUNING.SNOWBALLMANAGER_DENSITY
    local SNOWBALL_SECONDS_PER_SPAWN = TUNING.SNOWBALLMANAGER_SECONDS_PER_SPAWN
    local SNOWBALL_SECONDS_PER_DESPAWN = TUNING.SNOWBALLMANAGER_SECONDS_PER_DESPAWN
    self.accumulator = 0
    self.enabled = false
    self.snowballs = {}
    self.snowballscount = 0

    --self.snowballgrid = nil
    local WIDTH, HEIGHT
    local function initialize_grids()
        if self.snowballgrid ~= nil then
            return
        end

        WIDTH, HEIGHT = _map:GetSize()
        self.snowballgrid = DataGrid(WIDTH, HEIGHT)
    end
    self.inst:ListenForEvent("worldmapsetsize", initialize_grids, _world)

    function self:GetGridCoordsForSnowball(x, z)
        return math.floor(x / SNOWBALL_REGION_SIZE) * SNOWBALL_REGION_SIZE, math.floor(z / SNOWBALL_REGION_SIZE) * SNOWBALL_REGION_SIZE
    end

    local function UnregisterSnowball_Bridge(snowball)
        self:UnregisterSnowball(snowball)
    end
    function self:UnregisterSnowball(snowball)
        local snowballgriddataindex = self.snowballs[snowball]
        local snowballgriddata = self.snowballgrid:GetDataAtIndex(snowballgriddataindex)
        snowballgriddata.count = snowballgriddata.count - 1
        self.snowballscount = self.snowballscount - 1
        if snowballgriddata.count <= 0 then
            self.snowballgrid:SetDataAtIndex(snowballgriddataindex, nil)
        end
        self.snowballs[snowball] = nil
        if snowball:IsValid() then
            snowball:RemoveEventCallback("onremove", UnregisterSnowball_Bridge)
            snowball:RemoveEventCallback("onputininventory", UnregisterSnowball_Bridge)
            if snowball.components.snowballmelting then
                snowball.components.snowballmelting:AllowMelting()
            end
        end
    end
    function self:RegisterSnowball(snowball)
        local x, y, z = snowball.Transform:GetWorldPosition()
        local gx, gz = self:GetGridCoordsForSnowball(x, z)
        local snowballgriddataindex = self.snowballgrid:GetIndex(gx, gz)
        local snowballgriddata = self.snowballgrid:GetDataAtIndex(snowballgriddataindex)
        if not snowballgriddata then
            snowballgriddata = {
                count = 0,
            }
            self.snowballgrid:SetDataAtIndex(snowballgriddataindex, snowballgriddata)
        end
        self.snowballs[snowball] = snowballgriddataindex
        snowballgriddata.count = snowballgriddata.count + 1
        self.snowballscount = self.snowballscount + 1
        snowball:ListenForEvent("onremove", UnregisterSnowball_Bridge)
        snowball:ListenForEvent("onputininventory", UnregisterSnowball_Bridge)
        if snowball.components.snowballmelting then
            snowball.components.snowballmelting:StopMelting()
        end
    end

    self.NoSnowballTest = function(map, x, y, z)
        local tile = map:GetTileAtPoint(x, y, z)
        if not TileGroupManager:IsLandTile(tile) or GROUND_NOGROUNDOVERLAYS[tile] then
            return false
        end

        if TheSim:CountEntities(x, y, z, MAX_PHYSICS_RADIUS) > 0 then
            return false
        end

        local gx, gz = self:GetGridCoordsForSnowball(x, z)
        local snowballgriddata = self.snowballgrid:GetDataAtPoint(gx, gz)
        if snowballgriddata and snowballgriddata.count >= SNOWBALL_MAX_DENSITY then
            return false
        end

        return true
    end

    function self:TryToCreateSnowballAtPoint(x, y, z, skipsnowballtest)
        if not skipsnowballtest and not self.NoSnowballTest(_map, x, y, z) then
            return false
        end

        local snowball = SpawnPrefab("snowball_item")
        snowball.Transform:SetPosition(x, y, z)
        snowball.AnimState:PlayAnimation("spawn")
        snowball.AnimState:PushAnimation("ground_small")
        self:RegisterSnowball(snowball)
        return true
    end

    function self:TryToCreateSnowballAnywhere()
        local pt = _map:FindRandomPointWithFilter(50, self.NoSnowballTest)
        if pt then
            return self:TryToCreateSnowballAtPoint(pt.x, pt.y, pt.z, true)
        end
        return false
    end

    function self:TryToCreateSnowballForEachPlayer()
        for _, player in ipairs(AllPlayers) do
            if player:GetCurrentPlatform() == nil then
                local x, y, z = player.Transform:GetWorldPosition()
                for i = 1, 10 do
                    local r = math.random() * (PLAYER_CAMERA_SEE_DISTANCE - MAX_PHYSICS_RADIUS) + MAX_PHYSICS_RADIUS
                    local theta = math.random() * TWOPI
                    -- Intentionally skewing density to be closer to the player.
                    local dx, dz = math.cos(theta) * r, math.sin(theta) * r
                    if self:TryToCreateSnowballAtPoint(x + dx, y, z + dz) then
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
        if not IsSpecialEventActive(SPECIAL_EVENTS.WINTERS_FEAST) then
            return false
        end

        return self:SetEnabled(self.issnowing and self.issnowcovered or false)
    end

    function self:OnIsSnowing(issnowing)
        self.issnowing = issnowing
        self:TryToEnable()
    end
    local function OnIsSnowing_Bridge(inst, issnowing)
        self:OnIsSnowing(issnowing)
    end
    self.inst:WatchWorldState("issnowing", OnIsSnowing_Bridge)

    function self:OnIsSnowCovered(issnowcovered)
        self.issnowcovered = issnowcovered
        self:TryToEnable()
    end
    local function OnSnowCovered_Bridge(inst, issnowcovered)
        self:OnIsSnowCovered(issnowcovered)
    end
    self.inst:WatchWorldState("issnowcovered", OnSnowCovered_Bridge)

    function self:OnPostInit()
        self:OnIsSnowing(_worldstate.issnowing)
        self:OnIsSnowCovered(_worldstate.issnowcovered)
    end

    function self:OnUpdate(dt)
        self.accumulator = self.accumulator + dt
        if not self.enabled then
            if self.accumulator > SNOWBALL_SECONDS_PER_DESPAWN then
                self.accumulator = self.accumulator % SNOWBALL_SECONDS_PER_DESPAWN
                if not self.issnowcovered then
                    local snowball = next(self.snowballs)
                    if snowball then
                        if not snowball:IsAsleep() then
                            local x, y, z = snowball.Transform:GetWorldPosition()
                            SpawnPrefab("snowball_shatter_fx").Transform:SetPosition(x, y, z)
                        end
                        snowball:Remove()
                    end
                end
                if self.snowballscount <= 0 then
                    self.inst:StopUpdatingComponent(self)
                    return
                end
            end
        else
            if self.accumulator > SNOWBALL_SECONDS_PER_SPAWN then
                self.accumulator = self.accumulator % SNOWBALL_SECONDS_PER_SPAWN
                self:TryToCreateSnowballAnywhere()
                self:TryToCreateSnowballForEachPlayer()
            end
        end
    end

    function self:OnSave()
        if next(self.snowballs) then
            local data, ents = {}, {}
            data.snowballs = {}
            for snowball, _ in pairs(self.snowballs) do
                table.insert(data.snowballs, snowball.GUID)
                table.insert(ents, snowball.GUID)
            end
            return data, ents
        end
    end

    function self:LoadPostPass(newents, savedata)
        if savedata.snowballs then
            for _, snowballguid in ipairs(savedata.snowballs) do
                if newents[snowballguid] then
                    local snowball = newents[snowballguid].entity
                    self:RegisterSnowball(snowball)
                end
            end
            if self.snowballscount > 0 then
                self.inst:StartUpdatingComponent(self)
            end
        end
    end
end)

return SnowballManager
