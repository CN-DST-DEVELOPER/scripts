local defs = {
    internal = {},
    layouts = {},
}

local TILE_SCALE = TILE_SCALE
local IMPASSABLE = WORLD_TILES.IMPASSABLE

--------------------------------------------------------------------------

if TheSim then -- updateprefabs guard
    AddIsTileInvalidForPathing_VirtualRoomSet(VIRTUALROOMSETS.ATRIUM, function(map, tx, ty)
        return TileGroupManager:IsInvalidTile(map:GetTile(tx, ty))
    end)
end

--------------------------------------------------------------------------

--[[
A short template for layouts.
defs.layouts.roomnamehere = {
    ApplyFloorTiles = function(inst, virtualroomset)
        virtualroomset:SetFloorTileInBatch(dtx, dty, IMPASSABLE)
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()
        -- Spawn entities.
    end,
}
]]

--------------------------------------------------------------------------

local function SetAllImpassable(virtualroomset)
    for y = -10, 10 do
        for x = -10, 10 do
            virtualroomset:SetFloorTileInBatch(x, y, IMPASSABLE)
        end
    end
end

defs.layouts.boss1 = {
    ApplyFloorTiles = function(inst, virtualroomset)
        SetAllImpassable(virtualroomset)

        for y = -3, 3 do
            for x = -3, 3 do
                virtualroomset:SetFloorTileInBatch(x, y, WORLD_TILES.BRICK_GLOW)
            end
        end
    end,
    CreateRoomEntities = function(inst, virtualroomset)
        local x, _, z = virtualroomset:GetOrigin()

        local trial = SpawnPrefab("charlie_boss_trial")
        trial.Transform:SetPosition(x, 0, z)
        trial:InitializeLayout(virtualroomset)
    end,
}

--------------------------------------------------------------------------

local CURRENT_VERSION = 1
defs.InitializeLayout = function(virtualroomset)
    virtualroomset:SetVersion(CURRENT_VERSION) -- Mandatory call for InitializeLayout to have proper versioning control for this file.

    --------------------------------------------------------------------------
    -- NOTES(JBK): Adjusting the virtual room declarations will need a new CURRENT_VERSION number above.
    virtualroomset:DeclareVirtualRoom("boss1")
    virtualroomset:LinkVirtualRooms("boss1", VIRTUALROOMDIRECTIONS.OUT, nil)
    --------------------------------------------------------------------------
end

defs.DeleteLayout = function(virtualroomset)
end

return defs
