--------------------------------------------------------------------------

local TILE_SCALE = 2
local HALF_TILE_SCALE = TILE_SCALE * 0.5
local TILE_OFFSET = -1

local function GetTrapCoordsAtPoint(x, y, z)
	local w, h = TheWorld.Map:GetSize()
	w = w * TILE_SCALE
	h = h * TILE_SCALE

    local tx = math.floor(((x - TILE_OFFSET) + w + HALF_TILE_SCALE) / TILE_SCALE)
    local ty = math.floor(((z - TILE_OFFSET) + h + HALF_TILE_SCALE) / TILE_SCALE)
	return tx, ty
end

local function GetTrapCenterPoint(x, y, z)
	if z ~= nil then
		x, y = GetTrapCoordsAtPoint(x, y, z)
	end

	local w, h = TheWorld.Map:GetSize()
	w = w * TILE_SCALE
	h = h * TILE_SCALE

    x = x * TILE_SCALE - w + TILE_OFFSET
    y = y * TILE_SCALE - h + TILE_OFFSET
    return x, 0, y
end

local TRAPS

local function TileCoordsToId(tx, ty)
	return string.format("%d.%d", tx, ty)
end

local function IdToTileCoords(id)
	local sep = string.find(id, "%.")
	return tonumber(string.sub(id, 1, sep - 1)), tonumber(string.sub(id, sep + 1))
end

local function OnRemoveTrap(trap)
	assert(TRAPS[trap._fumaroletrap_id] == trap)
	TRAPS[trap._fumaroletrap_id] = nil
	if next(TRAPS) == nil then
		TRAPS = nil
	end
end

-- set on clients.
local function SetTrap(trap)
	local x, y, z = trap.Transform:GetWorldPosition()
	local id = TileCoordsToId(GetTrapCoordsAtPoint(x, 0, z))
	trap._fumaroletrap_id = id
	if TRAPS then
		assert(TRAPS[id] == nil)
		TRAPS[id] = trap
	else
		TRAPS = { [id] = trap }
	end
	trap:ListenForEvent("onremove", OnRemoveTrap)
end

local function UnsetTrap(trap)
	if trap._fumaroletrap_id then
		trap:RemoveEventCallback("onremove", OnRemoveTrap)
		OnRemoveTrap(trap)
		trap._fumaroletrap_id = nil
	end
end

local function HasTrap(id)
	return (TRAPS and TRAPS[id]) ~= nil
end

local function GetTrap(id)
	return TRAPS and TRAPS[id]
end

local function HasTrapAtXZ(x, z)
	if not TRAPS then
		return false -- early out
	end
	return HasTrap(TileCoordsToId(GetTrapCoordsAtPoint(x, 0, z)))
end

local function GetTrapAtXZ(x, z)
	if not TRAPS then
		return nil -- early out
	end
	return GetTrap(TileCoordsToId(GetTrapCoordsAtPoint(x, 0, z)))
end

--------------------------------------------------------------------------

return
{
	GetTrapCoordsAtPoint = GetTrapCoordsAtPoint,
	GetTrapCenterPoint = GetTrapCenterPoint,
	TileCoordsToId = TileCoordsToId,
	IdToTileCoords = IdToTileCoords,
	SetTrap = SetTrap,
	UnsetTrap = UnsetTrap,
	HasTrap = HasTrap,
	GetTrap = GetTrap,
	HasTrapAtXZ = HasTrapAtXZ,
	GetTrapAtXZ = GetTrapAtXZ,

	TILE_SCALE = TILE_SCALE,
}
