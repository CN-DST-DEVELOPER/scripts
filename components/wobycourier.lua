local WobyCourier = Class(function(self, inst)
    self.inst = inst

    self.shardid = TheShard:GetShardId()

    self.positions = {}
end)

function WobyCourier:NetworkLocation()
    if self.inst.woby_commands_classified then
        local xz = self.positions[self.shardid]
        if xz then
            self.inst.woby_commands_classified.chest_posx:set_local(xz.x)
            self.inst.woby_commands_classified.chest_posz:set_local(xz.z)
            self.inst.woby_commands_classified.chest_posx:set(xz.x)
            self.inst.woby_commands_classified.chest_posz:set(xz.z)
        else
            self.inst.woby_commands_classified.chest_posx:set_local(WOBYCOURIER_NO_CHEST_COORD)
            self.inst.woby_commands_classified.chest_posz:set_local(WOBYCOURIER_NO_CHEST_COORD)
            self.inst.woby_commands_classified.chest_posx:set(WOBYCOURIER_NO_CHEST_COORD)
            self.inst.woby_commands_classified.chest_posz:set(WOBYCOURIER_NO_CHEST_COORD)
        end
        if self.inst == ThePlayer then -- Server is client.
            self.inst:PushEvent("updatewobycourierchesticon")
        end
    end
end

function WobyCourier:CanStoreXZ(x, z)
    local map = TheWorld.Map
    local undertile = TheWorld.components.undertile
    local tile_x, tile_y = map:GetTileCoordsAtPoint(x, 0, z)
    local tileid_base = undertile and undertile:GetTileUnderneath(tile_x, tile_y) or map:GetTile(tile_x, tile_y)
    return TileGroupManager:IsLandTile(tileid_base)
end

function WobyCourier:StoreXZ(x, z) -- World coordinates in.
    if not self:CanStoreXZ(x, z) then
        return false
    end
    local xz = self.positions[self.shardid] or {}
    xz.x = x
    xz.z = z
    self.positions[self.shardid] = xz
    self:NetworkLocation()
    return true
end

function WobyCourier:ClearXZ()
    if self.positions[self.shardid] then
        self.positions[self.shardid] = nil
        self:NetworkLocation()
        return true
    end
    return false
end

function WobyCourier:OnSave()
    if next(self.positions) == nil then
        return nil
    end

    return {
        positions = self.positions,
    }
end

function WobyCourier:OnLoad(data)
    if data == nil then
        return
    end

    if data.positions then
        self.positions = data.positions
        self:NetworkLocation()
    end
end

function WobyCourier:GetDebugString()
    local x, z = GetWobyCourierChestPosition(self.inst)
    if not x then
        return "NPOS"
    end
    return string.format("Pos: %.1f %.1f", x, z)
end

return WobyCourier
