local SourceModifierList = require("util/sourcemodifierlist")

local TIME_FORGIVENESS_FACTOR = 2 -- Allow this much more time to walk with locomotor than to force one with entity sleep teleports.

local WorldRouteFollower = Class(function(self, inst)
    self.inst = inst

    self.pausedsources = SourceModifierList(inst, false, SourceModifierList.boolean) -- Set via self:SetPaused(paused, reason).

    self.closeenoughdist = 4 -- Override via self:SetCloseEnoughDist(dist).
    self.virtualwalkingspeedmult = 1 -- Override via self:SetVirtualWalkingSpeedMult(mult).

    --self.routename = nil -- Set via self:FollowRoute(routename, routeindexoverride).
    --self.routeindex = nil -- Set via self:SetRouteIndex(routeindex).

    --self.onarrivedfn = nil -- Set via self:SetOnArrivedFn(fn).
    --self.isvalidpointforroutefn = nil -- Set via self:SetIsValidPointForRouteFn(fn).
    --self.preteleportfn = nil -- Set via self:SetPreTeleportFn(fn).
    --self.postteleportfn = nil -- Set via self:SetPostTeleportFn(fn).

    --self.route = nil -- Internal.
    --self.routetimetoarrivemax = nil -- Internal.
    --self.routetimeelapsed = nil -- Internal.
    --self.stuckteleportattempts = nil -- Internal.
end)

function WorldRouteFollower:OnRemoveFromEntity(inst)
    if self.trytoteleporttodestinationtask then
        self.trytoteleporttodestinationtask:Cancel()
        self.trytoteleporttodestinationtask = nil
    end
end

function WorldRouteFollower:SetCloseEnoughDist(dist)
    self.closeenoughdist = dist
end

function WorldRouteFollower:SetVirtualWalkingSpeedMult(mult)
    self.virtualwalkingspeedmult = mult or 1
end

function WorldRouteFollower:SetIsValidPointForRouteFn(fn)
    self.isvalidpointforroutefn = fn
end

function WorldRouteFollower:SetPreTeleportFn(fn)
    self.preteleportfn = fn
end

function WorldRouteFollower:SetPostTeleportFn(fn)
    self.postteleportfn = fn
end

function WorldRouteFollower:SetOnArrivedFn(fn)
    self.onarrivedfn = fn
end

function WorldRouteFollower:GetRouteDestination()
    if not self.route then
        return nil
    end

    return self.route[self.routeindex]
end

function WorldRouteFollower:GetRoute()
    return self.route
end

local CANT_TAGS = {"INLIMBO", "NOCLICK", "FX"}
local function NoEnts(x, y, z)
    local ents = TheSim:FindEntities(x, y, z, MAX_PHYSICS_RADIUS, nil, CANT_TAGS)
    for _, ent in ipairs(ents) do
        local radius = ent:GetPhysicsRadius(0)
        if ent:GetDistanceSqToPoint(x, y, z) < radius * radius then
            return false
        end
    end

    return true
end
local function NoEnts_PtBridge(pt)
    return NoEnts(pt.x, pt.y, pt.z)
end
function WorldRouteFollower:IsValidPoint(x, y, z)
    -- First check custom rules.
    if self.isvalidpointforroutefn and not self.isvalidpointforroutefn(x, y, z) then
        return false
    end

    -- Then check collisions.
    if not NoEnts(x, y, z) then
        return false
    end

    return true
end

function WorldRouteFollower:FindValidPointNear(x, y, z)
    if self:IsValidPoint(x, y, z) then
        return x, y, z
    end

    -- We have things nearby the destination let us try to find a random offset that will make it valid.
    local minradius = self.inst:GetPhysicsRadius(0) + 2 -- Small pad for keeping things visually apart better.
    local pt = Vector3(x, y, z)
    for r = 4, 32, 4 do
        local offset = FindWalkableOffset(pt, math.random() * TWOPI, r + minradius + math.random(), 8, false, false, NoEnts_PtBridge, false, false)
        if offset then
            x, z = offset.x + x, offset.z + z
            return x, y, z
        end
    end

    return nil, nil, nil
end

function WorldRouteFollower:TeleportToDestination()

    local x, y, z = self.teleportdest:Get()
    self.teleportdest = nil
    if self.inst.Physics ~= nil then
        self.inst.Physics:Teleport(x, y, z)
    else
        self.inst.Transform:SetPosition(x, y, z)
    end
    -- Iterate.
    self:IterateRoute(true)
    -- Timer.
    if self.inst:IsAsleep() then
        self:TryToStartVirtualWalk()
    else
        if self.trytoteleporttodestinationtask then
            self.trytoteleporttodestinationtask:Cancel()
            self.trytoteleporttodestinationtask = nil
        end
    end

    -- Post.
    if self.postteleportfn then
        self.postteleportfn(self.inst)
    end
end

function WorldRouteFollower:TryToTeleportToDestination()
    local destination = self:GetRouteDestination()
    if not destination then
        return false
    end

    local x, y, z = self:FindValidPointNear(destination:Get())
    if x == nil then
        return false
    end

    self.teleportdest = Vector3(x, y, z)
    -- Pre.
    if self.preteleportfn then
        if self.preteleportfn(self.inst) then
            -- Caller will handle calling self:TeleportToDestination().
            return true
        end
    end

    self:TeleportToDestination()

    return true
end
local function TryToTeleportToDestination_Bridge(inst)
    local self = inst.components.worldroutefollower
    self:TryToTeleportToDestination()
end

function WorldRouteFollower:ShouldIterate()
    if self.pausedsources:Get() then -- Busy.
        return false
    end

    return true
end

function WorldRouteFollower:IterateRoute(force)
    local destination = self:GetRouteDestination()
    if destination then
        local isgoodtoiterate = force or false
        if not isgoodtoiterate then
            -- NOTES(JBK): If we can not reach the destination point because of obstructions the OnUpdate will skip the node after some attempts.
            local distdq = self.inst:GetDistanceSqToPoint(destination.x, 0, destination.z)
            local closeenoughdist = self.inst:GetPhysicsRadius(0) + self.closeenoughdist
            if distdq < closeenoughdist * closeenoughdist then
                isgoodtoiterate = true
            end
        end
        if isgoodtoiterate then
            local routeindex = self.routeindex + 1
            if routeindex > #self.route then
                routeindex = 1
            end
            self:SetRouteIndex(routeindex)
            return true
        end
    end
    return false
end

function WorldRouteFollower:SetRouteIndex(routeindex)
    self.routeindex = routeindex

    local routept_prior = self.route[self.routeindex == 1 and #self.route or (self.routeindex - 1)]
    local routept_destination = self.route[self.routeindex]
    local dx, dz = routept_destination.x - routept_prior.x, routept_destination.z - routept_prior.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local locomotor = self.inst.components.locomotor
    local speed = locomotor.isrunning and locomotor:GetRunSpeed() or locomotor:GetWalkSpeed()
    self.routetimetoarrivemax = (dist * TIME_FORGIVENESS_FACTOR) / speed
    self.routetimeelapsed = 0
    if not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
    end
end

function WorldRouteFollower:SetPaused(paused, reason)
    if paused then
        self.pausedsources:SetModifier(self.inst, paused, reason)
    else
        self.pausedsources:RemoveModifier(self.inst, reason)
        if self.inst.components.stuckdetection and not self.pausedsources:Get() then
            self.inst.components.stuckdetection:Reset()
        end
    end
end

function WorldRouteFollower:FollowRoute(routename, routeindexoverride)
    if self.routename == routename and (routeindexoverride == nil or (self.routeindex == routeindexoverride)) then
        return true
    end

    local worldroutes = TheWorld.components.worldroutes
    self.route = worldroutes and worldroutes:GetRoute(routename) or nil
    if not self.route then
        if self.updating then
            self.updating = nil
            self.inst:StopUpdatingComponent(self)
        end
        self.routename = nil
        self.routeindex = nil
        self.routetimetoarrivemax = nil
        self.routetimeelapsed = nil
        return false
    end

    self.routename = routename
    local routeindex
    if routeindexoverride then
        routeindex = routeindexoverride
    else
        local smallestdistsq = math.huge
        local x, y, z = self.inst.Transform:GetWorldPosition()
        for index, routept in ipairs(self.route) do
            local dx, dz = routept.x - x, routept.z - z
            local distsq = dx * dx + dz * dz
            if distsq < smallestdistsq then
                smallestdistsq = distsq
                routeindex = index
            end
        end
    end
    self:SetRouteIndex(routeindex)
    return true
end

function WorldRouteFollower:TryToStartVirtualWalk()
    if self.route and not self.trytoteleporttodestinationtask then
        local timelefttoarrive = (self.routetimetoarrivemax - self.routetimeelapsed) / TIME_FORGIVENESS_FACTOR
        if self.virtualwalkingspeedmult > 0 then
            timelefttoarrive = timelefttoarrive / self.virtualwalkingspeedmult
        end
        self.trytoteleporttodestinationtask = self.inst:DoTaskInTime(timelefttoarrive, TryToTeleportToDestination_Bridge)
        return true
    end

    return false
end

function WorldRouteFollower:OnUpdate(dt)
    if not self.route then -- Pending a StopUpdatingComponent.
        return
    end

    if not self:ShouldIterate() then
        return
    end

    local stuckdetection = self.inst.components.stuckdetection
    local ismoving = self.inst.sg and self.inst.sg:HasStateTag("moving")
    if ismoving then
        self.routetimeelapsed = self.routetimeelapsed + dt
    else
        if stuckdetection then
            stuckdetection:Reset()
        end
    end
    local tried = false
    if self:IterateRoute() then
        if self.onarrivedfn then
            self.onarrivedfn(self.inst)
        end
    elseif not self.teleportdest then
        if ismoving then
            local isstuck
            if stuckdetection then
                isstuck = stuckdetection:IsStuck()
            else
                isstuck = self.routetimeelapsed >= self.routetimetoarrivemax
            end
            if isstuck then
                if not self:TryToTeleportToDestination() then
                    tried = true
                    self.stuckteleportattempts = (self.stuckteleportattempts or 0) + 1
                    if self.stuckteleportattempts >= 3 then
                        self.stuckteleportattempts = nil
                        -- We tried some with random points let us skip the current node.
                        self:IterateRoute(true)
                    end
                end
            end
        end
    end
    if not tried then
        self.stuckteleportattempts = nil
    end
end

function WorldRouteFollower:OnEntitySleep()
    if self.updating then
        self.updating = nil
        self.inst:StopUpdatingComponent(self)
    end

    self:TryToStartVirtualWalk()
end

function WorldRouteFollower:OnEntityWake()
    if self.trytoteleporttodestinationtask then
        self.trytoteleporttodestinationtask:Cancel()
        self.trytoteleporttodestinationtask = nil
    end

    if self.route and not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
    end
end

function WorldRouteFollower:OnSave()
    if not self.routename then
        return nil
    end

    return {
        routename = self.routename,
        routeindex = self.routeindex,
    }
end

function WorldRouteFollower:OnLoad(data)
    if not data then
        return
    end

    self:FollowRoute(data.routename, data.routeindex)
end

function WorldRouteFollower:GetDebugString()
    if not self.routename then
        return "No route"
    end

    local teleportreason
    local timetoteleport
    if self.pausedsources:Get() then
        timetoteleport = -1
        teleportreason = " PAUSED"
    elseif self.teleportdest then
        timetoteleport = -1
        teleportreason = " via externally managed"
    elseif self.trytoteleporttodestinationtask then
        timetoteleport = GetTaskRemaining(self.trytoteleporttodestinationtask)
        teleportreason = " via sleep task"
    elseif self.inst.components.stuckdetection then
        timetoteleport = self.inst.components.stuckdetection:GetRemainingTime()
        teleportreason = " via stuckdetection check"
    else
        timetoteleport = self.routetimetoarrivemax - self.routetimeelapsed
        teleportreason = " via internal stuck check"
    end
    return string.format("%s : Index(%d of %d) : TimeToTeleport %.1f%s", self.routename, self.routeindex, #self.route, timetoteleport, teleportreason)
end

return WorldRouteFollower
