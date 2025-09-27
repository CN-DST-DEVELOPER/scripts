--------------------------------------------------------------------------
--[[ wagpunk_floor_helper class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)
local _world = TheWorld
local _map = _world.Map

self.inst = inst

self.barrier_active = net_bool(self.inst.GUID, "wagpunk_floor_helper.barrier_active")
self.arena_active = net_bool(self.inst.GUID, "wagpunk_floor_helper.arena_active")
self.arena_origin_x = net_float(self.inst.GUID, "wagpunk_floor_helper.arena_origin_x") -- Could probably be a ushort if arenas are tile aligned only.
self.arena_origin_z = net_float(self.inst.GUID, "wagpunk_floor_helper.arena_origin_z")
self.barrier_active:set(false)
self.arena_active:set(false)
self.arena_origin_x:set(0)
self.arena_origin_z:set(0)

local scale = TILE_SCALE
local SIZE_WIDE = 7 * scale
local SIZE_SQUARE = 6 * scale
local SIZE_SKINNY = 5 * scale

-- Common.

function self:IsXZWithThicknessInArena_Calculation(x, z, thickness)
    -- NOTES(JBK): This arena is a very square circle.
    -- The size is fixed and tied to the shape of hermitcrab_01 static layout.
    -- We can check if any point is in the arena by checking a total of three rectangles.
    local ax, az = self.arena_origin_x:value(), self.arena_origin_z:value()
    local dx, dz = ax - x, az - z

    local WIDE_WITH_THICKNESS = SIZE_WIDE + thickness
    local SKINNY_WITH_THICKNESS = SIZE_SKINNY + thickness
    local SQUARE_WITH_THICKNESS = SIZE_SQUARE + thickness
    -- The first rectangle is the horizontal wide.
    if dx >= -WIDE_WITH_THICKNESS and dx <= WIDE_WITH_THICKNESS then
        if dz >= -SKINNY_WITH_THICKNESS and dz <= SKINNY_WITH_THICKNESS then
            return true
        end
    end
    -- Then the vertical tall.
    if dx >= -SKINNY_WITH_THICKNESS and dx <= SKINNY_WITH_THICKNESS then
        if dz >= -WIDE_WITH_THICKNESS and dz <= WIDE_WITH_THICKNESS then
            return true
        end
    end
    -- Finally the square center.
    if dx >= -SQUARE_WITH_THICKNESS and dx <= SQUARE_WITH_THICKNESS then
        if dz >= -SQUARE_WITH_THICKNESS and dz <= SQUARE_WITH_THICKNESS then
            return true
        end
    end

    return false
end

function self:IsPointInArena(x, y, z)
    if not self.arena_active:value() then
        return false
    end

    return self:IsXZWithThicknessInArena_Calculation(x, z, 0)
end

function self:IsXZWithThicknessInArena(x, z, thickness)
    if not self.arena_active:value() then
        return false
    end

    -- Along the barrier means a band from the barrier so it should be inside the arena with a positive thickness and outside of it with a negative thickness.
    return self:IsXZWithThicknessInArena_Calculation(x, z, thickness) and not self:IsXZWithThicknessInArena_Calculation(x, z, -thickness)
end

function self:GetArenaOrigin()
    if not self.arena_active:value() then
        return nil, nil
    end

    return self.arena_origin_x:value(), self.arena_origin_z:value()
end

function self:IsBarrierUp()
    return self.barrier_active:value()
end

-- Server.

self.OnRemove_Marker = function(ent, data)
    self.marker = nil
    self.arena_active:set(false)
    self.arena_origin_x:set(0)
    self.arena_origin_z:set(0)
end

function self:TryToSetMarker(inst)
    if self.marker then
        inst:Remove()
        return
    end

    self.marker = inst
    local x, y, z = self.marker.Transform:GetWorldPosition()
    self.arena_active:set(true)
    self.arena_origin_x:set(x)
    self.arena_origin_z:set(z)
    inst:ListenForEvent("onremove", self.OnRemove_Marker)
end

end)