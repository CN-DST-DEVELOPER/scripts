--------------------------------------------------------------------------
--[[ RopeBridgeManager class definition ]]
--------------------------------------------------------------------------
return Class(function(self, inst)
assert(TheWorld.ismastersim, "RopeBridgeManager should not exist on client")

self.inst = inst

--self.WIDTH, self.HEIGHT = nil, nil
--self.marked_for_delete_grid = nil
--self.duration_grid = nil
--self.damage_prefabs_grid = nil
--self.bridge_anims_grid = nil

self.DEFAULT_BREAKDATA = {
    fxtime = TUNING.ROPEBRIDGE_EARTHQUAKE_TIMETOBREAK,
}
self.DEFAULT_BREAKDATA.shaketime = self.DEFAULT_BREAKDATA.fxtime - 1
self.DEFAULT_BREAKDATA.destroytime = self.DEFAULT_BREAKDATA.fxtime + 70 * FRAMES

-- Cache for speed.
local _world = TheWorld
local _map = _world.Map

local function initialize_grids()
    if self.marked_for_delete_grid ~= nil and self.duration_grid ~= nil then
        return
    end

    self.WIDTH, self.HEIGHT = _map:GetSize()

    self.marked_for_delete_grid = DataGrid(self.WIDTH, self.HEIGHT)
    self.duration_grid = DataGrid(self.WIDTH, self.HEIGHT)
    self.damage_prefabs_grid = DataGrid(self.WIDTH, self.HEIGHT)
	self.bridge_anims_grid = DataGrid(self.WIDTH, self.HEIGHT)
end
self.inst:ListenForEvent("worldmapsetsize", initialize_grids, _world)

local QUAKE_BLOCKER_MUST_TAGS = {"quake_blocker"}
function self:IsPointProtectedFromQuakes(x, y, z)
    return TheSim:CountEntities(x, y, z, TUNING.QUAKE_BLOCKER_RANGE, QUAKE_BLOCKER_MUST_TAGS) > 0
end
function self:CalculateProtection_Internal(protected, i, tile_data)
    -- Get bridge direction vector.
    local direction = tile_data[2]
    if not direction then
        protected[i] = false
        return
    end

    -- Normalize direction vector from world tile offsets to tile coordinate offsets.
    local dx = (direction.x < 0 and -1) or (direction.x > 0 and 1) or 0
    local dz = (direction.z < 0 and -1) or (direction.z > 0 and 1) or 0

    local maxlength = TUNING.ROPEBRIDGE_LENGTH_TILES
    local tx, tz = self.duration_grid:GetXYFromIndex(i)
    -- Scan for start of bridge.
    for j = 1, maxlength do
        tx, tz = tx - dx, tz - dz
        if self.duration_grid:GetDataAtPoint(tx, tz) == nil then
            break
        end
    end
    -- Try to see if any of the bridge is protected.
    local sx, sz = tx, tz
    local isprotected = false
    for j = 1, maxlength do
        tx, tz = tx + dx, tz + dz
        if self.duration_grid:GetDataAtPoint(tx, tz) == nil then
            break
        end
        local x, y, z = _map:GetTileCenterPoint(tx, tz)
        isprotected = self:IsPointProtectedFromQuakes(x, y, z)
        if isprotected then
            break
        end
    end
    -- Apply protection to whole bridge.
    tx, tz = sx, sz
    for j = 1, maxlength do
        tx, tz = tx + dx, tz + dz
        local index = self.duration_grid:GetIndex(tx, tz)
        if self.duration_grid:GetDataAtIndex(index) == nil then
            break
        end
        protected[index] = isprotected
    end
end
function self:OnQuaked()
    local damage = TUNING.ROPEBRIDGE_EARTHQUAKE_DAMAGE_TAKEN
    local protected = {}
    for i, tile_data in pairs(self.duration_grid.grid) do
        if protected[i] == nil then
            self:CalculateProtection_Internal(protected, i, tile_data)
        end
        if not protected[i] then
            local tile_x, tile_y = self.duration_grid:GetXYFromIndex(i)
            local x, y, z = _map:GetTileCenterPoint(tile_x, tile_y)
            self:DamageRopeBridgeAtPoint(x, y, z, damage)
        end
    end
end
function self:OnStartQuake(data)
    if self.quaketask ~= nil then
        self.quaketask:Cancel()
    end
    --delay till the first camera shake period
    self.quaketask = self.inst:DoTaskInTime(data ~= nil and data.debrisperiod or 0, function() self:OnQuaked() end)
end
function self:OnPostInit()
    self.inst:ListenForEvent("startquake", function(inst, data) self:OnStartQuake(data) end, _world.net)
end



local function destroy_ropebridge_at_point(world, dx, dz, ropebridgemanager, data)
    ropebridgemanager:DestroyRopeBridgeAtPoint(dx, 0, dz, data)
end

local function create_ropebridge_at_point(world, dx, dz, ropebridgemanager, direction, icon_offset)
	ropebridgemanager:CreateRopeBridgeAtPoint(dx, 0, dz, direction, icon_offset)
end

local function start_destroy_for_tile(_, txy, wid, ropebridgemanager)
    local center_x, center_y, center_z = _map:GetTileCenterPoint(txy % wid, math.floor(txy / wid))
    ropebridgemanager:QueueDestroyForRopeBridgeAtPoint(center_x, center_y, center_z)
end

function self:CreateRopeBridgeAtPoint(x, y, z, direction, icon_offset)
    local tile_x, tile_y = _map:GetTileCoordsAtPoint(x, y, z)
	return self:CreateRopeBridgeAtTile(tile_x, tile_y, x, z, direction, icon_offset)
end

function self:CreateRopeBridgeAtTile(tile_x, tile_y, x, z, direction, icon_offset)
    local current_tile = nil
    local undertile = _world.components.undertile
    if undertile then
        current_tile = _map:GetTile(tile_x, tile_y)
    end

    _map:SetTile(tile_x, tile_y, WORLD_TILES.ROPE_BRIDGE)

    -- V2C: Because of a terraforming callback in farming_manager.lua, the undertile gets cleared during SetTile.
    --      We can circumvent this for now by setting the undertile after SetTile.
    if undertile and current_tile then
        undertile:SetTileUnderneath(tile_x, tile_y, current_tile)
    end

	local tile_index = self.duration_grid:GetIndex(tile_x, tile_y)
	local tile_data = self.duration_grid:GetDataAtIndex(tile_index)
	if tile_data then
		tile_data[1] = TUNING.ROPEBRIDGE_HEALTH
		tile_data[2] = direction
	else
		self.duration_grid:SetDataAtIndex(tile_index, { TUNING.ROPEBRIDGE_HEALTH, direction })
	end

    if not x or not z then
        local tx, _, tz = _map:GetTileCenterPoint(tile_x, tile_y)
        x = tx
        z = tz
    end

	self:SpawnBridgeAnim(tile_index, x, z, direction, icon_offset)

    return true
end

function self:QueueCreateRopeBridgeAtPoint(x, y, z, data)
    local tile_x, tile_y = _map:GetTileCoordsAtPoint(x, y, z)
    local data_at_point = self.duration_grid:GetDataAtPoint(tile_x, tile_y)
    if not data_at_point then
        local base_time, random_time = 0.5, 0.3
		local direction, icon_offset
        if data then
            base_time = data.base_time or base_time
            random_time = data.random_time or random_time
            direction = data.direction
			icon_offset = data.icon_offset
        end
		self.duration_grid:SetDataAtPoint(tile_x, tile_y, { TUNING.ROPEBRIDGE_HEALTH, direction, icon_offset })
		_world:DoTaskInTime(base_time + (random_time * math.random()), create_ropebridge_at_point, x, z, self, direction, icon_offset)
    end
end

function self:DestroyRopeBridgeAtPoint(x, y, z, data)
    local tile_x, tile_y = _map:GetTileCoordsAtPoint(x, y, z)
    local tile = _map:GetTile(tile_x, tile_y)
    if tile ~= WORLD_TILES.ROPE_BRIDGE then
        return false
    end

    local index = self.damage_prefabs_grid:GetIndex(tile_x, tile_y)
    local damage_prefab = self.damage_prefabs_grid:GetDataAtIndex(index)
    if damage_prefab then
        self.damage_prefabs_grid:SetDataAtIndex(index, nil)
        damage_prefab:Remove()
    end

    local undertile = _world.components.undertile
    local old_tile = undertile and undertile:GetTileUnderneath(tile_x, tile_y) or nil
    if old_tile ~= nil then
        undertile:ClearTileUnderneath(tile_x, tile_y)
    else
        old_tile = WORLD_TILES.IMPASSABLE
    end

    _map:SetTile(tile_x, tile_y, old_tile)

    local grid_index = self.marked_for_delete_grid:GetIndex(tile_x, tile_y)
    self.marked_for_delete_grid:SetDataAtIndex(grid_index, nil)
    self.duration_grid:SetDataAtIndex(grid_index, nil)

	local fx = self.bridge_anims_grid:GetDataAtIndex(grid_index)
	if fx then
		fx:KillFX()
	end
	self.bridge_anims_grid:SetDataAtIndex(grid_index, nil)

    TempTile_HandleTileChange(x, y, z, old_tile)

    return true
end

function self:QueueDestroyForRopeBridgeAtPoint(x, y, z, data)
    local tile_x, tile_y = _map:GetTileCoordsAtPoint(x, y, z)
    local data_at_point = self.duration_grid:GetDataAtPoint(tile_x, tile_y)
    if data_at_point then
        -- We assign this here because an external force could have manually queued this destroy.
        self.marked_for_delete_grid:SetDataAtPoint(tile_x, tile_y, true)

        local time = data and data.destroytime or 2 + (70 + math.random(0, 10)) * FRAMES
        _world:DoTaskInTime(time, destroy_ropebridge_at_point, x, z, self, data)

        local function DoWarn()
            -- Send a breaking message to all of the prefabs on this point.
            local undertile = _world.components.undertile
            local old_tile = undertile and undertile:GetTileUnderneath(tile_x, tile_y) or WORLD_TILES.IMPASSABLE
            TempTile_HandleTileChange_Warn(x, y, z, old_tile)
        end

        local fxtime = data and data.fxtime
        if fxtime then
            local shaketime = math.max(data.shaketime or 1, 0)
            _world:DoTaskInTime(shaketime, function()
                local fx = self.bridge_anims_grid:GetDataAtPoint(tile_x, tile_y)
                if fx and fx.ShakeIt then
                    fx:ShakeIt()
                end
            end)
            _world:DoTaskInTime(data.fxtime, function()
                DoWarn()
            end)
        else
            DoWarn()
        end
    end
end

function self:DamageRopeBridgeAtPoint(x, y, z, damage)
    local tile_x, tile_y = _map:GetTileCoordsAtPoint(x, y, z)
    return self:DamageRopeBridgeAtTile(tile_x, tile_y, damage)
end

function self:DamageRopeBridgeAtTile(tx, ty, damage)
    local tile_index = self.duration_grid:GetIndex(tx, ty)
	local tile_data = self.duration_grid:GetDataAtIndex(tile_index)
    local dx, dy, dz = _map:GetTileCenterPoint(tx,ty)
	if not tile_data or (tile_data[1] or 0) == 0 then
        -- Exit early if there's no data, or the tile was
        -- already damaged to its breaking point before this.
        return nil
    else
        -- We don't technically need this set here, but if somebody wants to inspect
        -- health and test for 0 elsewhere, it's useful to have an accurate representation.
        local new_health = math.min(math.max(0, tile_data[1] - damage), TUNING.ROPEBRIDGE_HEALTH)
		tile_data[1] = new_health

        self:SpawnDamagePrefab(tile_index, new_health)

        if new_health == 0 then
            self:QueueDestroyForRopeBridgeAtPoint(dx, dy, dz, self.DEFAULT_BREAKDATA)
        end

        return new_health
    end
end

function self:SpawnDamagePrefab(tile_index, health)
    local x, z = self.duration_grid:GetXYFromIndex(tile_index)
    local dx, dy, dz = _map:GetTileCenterPoint(x,z)
    local damage_prefab = self.damage_prefabs_grid:GetDataAtIndex(tile_index)

    if health < TUNING.ROPEBRIDGE_HEALTH then
        if not damage_prefab then
            damage_prefab = SpawnPrefab("dock_damage")
            damage_prefab.Transform:SetPosition(dx, dy, dz)
            self.damage_prefabs_grid:SetDataAtIndex(tile_index, damage_prefab)
        end
        damage_prefab:setdamagepecent( 1 - (health/TUNING.ROPEBRIDGE_HEALTH) )
    else
        if damage_prefab then
            self.damage_prefabs_grid:SetDataAtIndex(tile_index, nil)
            damage_prefab:Remove()
        end
    end
end

function self:SpawnBridgeAnim(tile_index, x, z, direction, icon_offset)
	local fx = self.bridge_anims_grid:GetDataAtIndex(tile_index)
	if fx == nil then
		fx = SpawnPrefab("rope_bridge_fx")
		fx.Transform:SetPosition(x, 0, z)
		fx.Transform:SetRotation(
			(direction.x > 0 and 0) or
			(direction.x < 0 and 180) or
			(direction.z > 0 and -90) or
			90
		)
		fx:SetIconOffset(icon_offset)
		self.bridge_anims_grid:SetDataAtIndex(tile_index, fx)

		if POPULATING then
			fx:SkipPre()
		end
	end
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data = {}

    data.marked_for_delete = self.marked_for_delete_grid:Save()
    data.duration = self.duration_grid:Save()

    return ZipAndEncodeSaveData(data)
end

function self:OnLoad(data)
    data = DecodeAndUnzipSaveData(data)
    if data == nil then
        return
    end

    if data.marked_for_delete ~= nil then
        self.marked_for_delete_grid:Load(data.marked_for_delete)

        local dg_width = self.marked_for_delete_grid:Width()
        for tile_xy, is_marked in pairs(data.marked_for_delete) do
            -- If we loaded tile data that's marked_for_delete, it must have been mid-destructions,
            -- because destruction should nil out the data for that tile.
            -- So, let's restart the destruction task!
            if is_marked then
                _world:DoTaskInTime(math.random(1, 10) * FRAMES, start_destroy_for_tile, tile_xy, dg_width, self)
            end
        end
    end

    if data.duration ~= nil then
        -- We shouldn't need to test for any 0 health values; anything that started
        -- being destroyed should have ended up in marked_for_delete above, and the
        -- health grid should get cleaned up when that destroy resolves.
        self.duration_grid:Load(data.duration)
        for i, health in pairs(self.duration_grid.grid) do
			if type(health) == "table" then
				local tile_x, tile_y = self.duration_grid:GetXYFromIndex(i)
				local x, y, z = _map:GetTileCenterPoint(tile_x, tile_y)
				self:SpawnBridgeAnim(i, x, z, health[2], health[3])
				self:SpawnDamagePrefab(i, health[1])
			else
				--backward compatibility: duration_grid used to be just health value, now is an array { health, duration }
				self:SpawnDamagePrefab(i, health)
			end
        end
    end
end

end)