--------------------------------------------------------------------------
--[[ vault_floor_helper class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)
local _world = TheWorld
local _map = _world.Map

self.inst = inst

self.vault_active = net_bool(self.inst.GUID, "vault_floor_helper.vault_active")
self.vault_origin_x = net_float(self.inst.GUID, "vault_floor_helper.vault_origin_x") -- Could probably be a ushort if arenas are tile aligned only.
self.vault_origin_z = net_float(self.inst.GUID, "vault_floor_helper.vault_origin_z")
self.vault_origin_x:set(0)
self.vault_origin_z:set(0)

local scale = TILE_SCALE
local EXTRA_PADDING = 1 * scale -- This is outside of the real area but the setpiece is supposed to have abyss around so it is fine.
local SIZE_WIDE = 5.75 * scale + EXTRA_PADDING
local SIZE_SQUARE = 4.75 * scale + EXTRA_PADDING
local SIZE_SKINNY = 2 * scale + EXTRA_PADDING -- Extra 0.25 to cover internal corners. Makes the outside nubs a bit bigger but fine.

-- Common.

function self:IsPointInVaultRoom_Internal(x, y, z)
    -- NOTES(JBK): This function should not be called directly use Map:IsPointInVaultRoom instead!
    if not self.vault_active:value() then
        return false
    end

    -- The size is fixed and tied to the shape of vault_vault static layout.
    -- The check here is for the center area since the vault can change the tiles there.
    local ax, az = self.vault_origin_x:value(), self.vault_origin_z:value()
    local dx, dz = ax - x, az - z

    -- The first rectangle is the horizontal wide.
    if dx >= -SIZE_WIDE and dx <= SIZE_WIDE then
        if dz >= -SIZE_SKINNY and dz <= SIZE_SKINNY then
            return true
        end
    end
    -- Then the vertical tall.
    if dx >= -SIZE_SKINNY and dx <= SIZE_SKINNY then
        if dz >= -SIZE_WIDE and dz <= SIZE_WIDE then
            return true
        end
    end
    -- Finally the square center.
    if dx >= -SIZE_SQUARE and dx <= SIZE_SQUARE then
        if dz >= -SIZE_SQUARE and dz <= SIZE_SQUARE then
            return true
        end
    end

    return false
end

-- Server.

self.OnRemove_Marker = function(ent, data)
    self.marker = nil
    self.vault_active:set(false)
    self.vault_origin_x:set(0)
    self.vault_origin_z:set(0)
end

function self:TryToSetMarker(inst)
    if self.marker == inst then -- For the world load case where entities are loading twice.
        return
    end

    if self.marker then
        inst:Remove()
        return
    end

    self.marker = inst
    local x, y, z = self.marker.Transform:GetWorldPosition()
    self.vault_active:set(true)
    self.vault_origin_x:set(x)
    self.vault_origin_z:set(z)
    inst:ListenForEvent("onremove", self.OnRemove_Marker)
end

end)