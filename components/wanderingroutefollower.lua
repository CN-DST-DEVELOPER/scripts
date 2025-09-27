--------------------------------------------------------------------------
--[[ wanderingroutefollower class definition ]]
--------------------------------------------------------------------------
return Class(function(self, inst)
local _world = TheWorld
local _map = _world.Map
assert(_world.ismastersim, "wanderingroutefollower should not exist on client")
self.inst = inst

-- Constants.
self.PERIODIC_TICK_TIME = 10
self.DISTANCE_PER_INTERPOLATED_POINT = 8
self.CLOSE_ENOUGH_DISTANCE_SQ_TO_POINT = 16
self.STATES = {
    IDLE = 0,
    FOLLOWING = 1,
}

-- Variables.
self.accumulator = 0 -- No save.
self.routes = {}
self.routestate = self.STATES.IDLE
--self.routename = nil
--self.routeindex = nil
self.interpolatedroutes = {} -- No save.

-- Management.

self.IsValidPointFn = function(pt) -- NoHolesNoInvisibleTiles
    local tile = _map:GetTileAtPoint(pt:Get())
    if GROUND_INVISIBLETILES[tile] then
        return false
    end
    return not _map:IsPointNearHole(pt)
end

function self:InterpolateRoute(routename)
    if not routename then
        self.interpolatedroutes[routename] = nil
        return
    end

    -- NOTES(JBK): The input points from self.routes are very loose approximations of a route.
    -- We will interpolate them here to be smooth and more natural for motion.
    -- We will also add in more finer points at a fixed distance in between each point.
    local interpolatedroutes = {}
    self.interpolatedroutes[routename] = interpolatedroutes

    local xzpositions = self.routes[routename]
    local maxindex = #xzpositions
    for i = 1, maxindex do
        local v1 = xzpositions[i]
        local v2
        if i == maxindex then
            v2 = xzposition[1]
        else
            v2 = xzpositions[i + 1]
        end
        local distmod = math.ceil(math.sqrt(distsq(v1.x, v1.z, v2.x, v2.z)) / self.DISTANCE_PER_INTERPOLATED_POINT)
        for j = 0, distmod - 1 do
            local x = Lerp(v1.x, v2.x, j / distmod)
            local z = Lerp(v1.z, v2.z, j / distmod)
            table.insert(interpolatedroutes, {x = x, z = z,})
            local dbg = SpawnPrefab("purplemooneye")
            dbg.Transform:SetPosition(x, 0, z)
        end
    end
end

function self:DefineRoute(routename, xzpositions)
    -- xzpositions should be in the format of:
    -- {
    --     {x = x1, z = z1, },
    --     {x = x2, z = z2, },
    --     ...
    -- }
    -- or nil
    self.routes[routename] = xzpositions
    self:InterpolateRoute(routename)
end

function self:ForgetRoute(routename)
    self.routes[routename] = nil
    self.interpolatedroutes[routename] = nil
end

function self:SetCurrentRoute(routename)
    if routename ~= self.routename then
        self.routename = routename
        self.routestate = self.STATES.IDLE
        local routeindex
        if self.routename then
            local x, y, z = self.inst.Transform:GetWorldPosition()
            local closestdsq = math.huge
            for i, v in ipairs(self.interpolatedroutes[self.routename]) do
                local dsq = distsq(v.x, v.z, x, z)
                if dsq < closestdsq then
                    closestdsq = dsq
                    routeindex = i
                end
            end
        end
        self.routeindex = routeindex
    end
end

function self:SetRoutePickerFn(fn)
    self.routepickerfn = fn
end

function self:GetDesiredPosition()
    if not self.routename then -- No route means we want to be right where we are.
        return self.inst.Transform:GetWorldPosition()
    end

    return 0, 0, 0
end

function self:Tick()
    print("Tick")
    if self.routepickerfn then
        self:SetCurrentRoute(self.routepickerfn(self.inst))
    end
    print("Tick", self:GetDesiredPosition())
end

-- OnUpdate for house cleaning.
function self:OnUpdate(dt)
    local accumulator = self.accumulator + dt
    if accumulator > self.PERIODIC_TICK_TIME then
        accumulator = 0
        self:Tick()
    end
    self.accumulator = accumulator
end
function self:LongUpdate(dt)
    self:OnUpdate(dt)
end

-- Save/Load.
function self:OnSave()
    local data = {
        routes = self.routes,
        routename = self.routename, 
        routeindex = self.routeindex,
    }
    for name, enumvalue in pairs(self.STATES) do
        if self.routestate == enumvalue then
            data.routestate = name -- Enum to string.
            break
        end
    end

    return data
end
function self:OnLoad(data)
    if data == nil then
        return
    end

    self.routes = data.routes or self.routes
    self.routestate = self.STATES[data.routestate] or self.routestate -- String to enum.
    self.routename = data.routename
    self.routeindex = data.routeindex
end

function self:GetDebugString()
    return string.format("Route {Name: %s, Index: %d, State: %d}, Next Tick: %.1f", self.routename or "N/A", self.routeindex or -1, self.routestate, tostring(self.PERIODIC_TICK_TIME - self.accumulator))
end

end)
