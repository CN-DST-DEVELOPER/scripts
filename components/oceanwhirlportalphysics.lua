--------------------------------------------------------------------------
--[[ oceanwhirlportalphysics class definition ]]
--------------------------------------------------------------------------

local DEFAULT_FOCAL_RADIUS = 1
local DEFAULT_RADIUS = 4
local DEFAULT_PULLSTRENGTH = 4
local DEFAULT_RADIALSTRENGTH = 2

local TICK_SLOW_PERIOD = 1.0
local TICK_FAST_PERIOD = 0.1
local TICK_FAST_COOLDOWN = 5.0 -- Time to switch from fast to slow if nothing is interacting with it.

local WHIRLPORTALPHYSICS_CANT_TAGS = {"FX", "DECOR", "INLIMBO", "oceanwhirlportal", "flying", "ghost", "playerghost", "shadow"}

local MIN_PULLSTRENGTH_EXPONENT = math.log(0.1)

local WORK_ACTIONS = {
    CHOP = true,
    DIG = true,
    HAMMER = true,
    MINE = true,
}

return Class(function(self, inst)


local _world = TheWorld
assert(_world.ismastersim, "Wagpunk Arena Manager should not exist on the client!")
local _map = _world.Map

self.inst = inst

function self:RecalculateForceExponent()
    self.forceexponent = MIN_PULLSTRENGTH_EXPONENT / (math.log(self.focalradius / self.radius))
end

self.watchedentities = {}
self.focalradius = DEFAULT_FOCAL_RADIUS
self.radius = DEFAULT_RADIUS
self:RecalculateForceExponent()
self.pullstrength = DEFAULT_PULLSTRENGTH
self.radialstrength = DEFAULT_RADIALSTRENGTH
self.tickaccumulator = 0
self.enabled = false

function self:SetEnabled(enabled)
    if self.enabled ~= enabled then
        if not self.inst:IsAsleep() then
            if enabled then
                self.tickaccumulator = 9999
                self.inst:StartUpdatingComponent(self)
            else
                self.inst:StopUpdatingComponent(self)
                for ent, _ in pairs(self.watchedentities) do
                    self:ForgetEntity(ent)
                end
            end
        end
        self.enabled = enabled
    end
end

function self:SetFocalRadius(focalradius)
    self.focalradius = focalradius
    self:RecalculateForceExponent()
end

function self:GetFocalRadius()
    return self.focalradius
end

function self:SetRadius(radius)
    self.radius = radius
    self:RecalculateForceExponent()
end

function self:GetRadius()
    return self.radius
end

function self:SetPullStrength(pullstrength)
    self.pullstrength = pullstrength
end

function self:GetPullStrength()
    return self.pullstrength
end

function self:SetRadialStrength(radialstrength)
    self.radialstrength = radialstrength
end

function self:GetRadialStrength()
    return self.radialstrength
end

function self:SetOnEntityTouchingFocalFn(fn)
    self.onentitytouchingfocalfn = fn
end

function self:OnEntitySleep()
    if self.enabled then
        self.inst:StopUpdatingComponent(self)
        for ent, _ in pairs(self.watchedentities) do
            self:ForgetEntity(ent)
        end
    end
end

function self:OnEntityWake()
    if self.enabled then
        self.inst:StartUpdatingComponent(self)
    end
end

self.OnRemove_WatchedEntity = function(ent, data)
    self.watchedentities[ent] = nil
end

function self:RememberEntity(ent)
    if not self.watchedentities[ent] then
        self.watchedentities[ent] = true
        ent:ListenForEvent("onremove", self.OnRemove_WatchedEntity)
        if not ent.components.physicsmodifiedexternally then
            ent:AddComponent("physicsmodifiedexternally")
        end
        ent.components.physicsmodifiedexternally:AddSource(self.inst)
    end
end

function self:ForgetEntity(ent)
    if self.watchedentities[ent] then
        self.watchedentities[ent] = nil
        if next(self.watchedentities) == nil then
            self.fastcooldown = TICK_FAST_COOLDOWN
        end
        ent:RemoveEventCallback("onremove", self.OnRemove_WatchedEntity)
        ent.components.physicsmodifiedexternally:RemoveSource(self.inst)
    end
end

function self:TryToBreakStaticObject(ent)
    if ent.components.health then
        if not ent.components.health:IsDead() then
            ent.components.health:SetPercent(math.max(ent.components.health:GetPercent() - TUNING.OCEANWHIRLBIGPORTAL_BOAT_PERCENT_DAMAGE_PER_TICK), 0)
        end
    elseif ent.components.workable and ent.components.workable:CanBeWorked() then
        ent.components.workable:Destroy(self.inst)
    end
end

function self:ShouldRememberEntity(ent)
    if ent:HasTag("bird") then
        ent:PushEvent("flyaway")
        return false
    end

    if ent.Physics:GetMass() == 0 then
        self:TryToBreakStaticObject(ent)
        return false
    end

    return true
end

function self:CheckForEntities()
    local watchedentities = {}

    local radiussq = self.radius * self.radius
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, self.radius + MAX_PHYSICS_RADIUS, nil, WHIRLPORTALPHYSICS_CANT_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsOnOcean() or ent:HasTag("boat") then
            local entradius = ent:GetPhysicsRadius(0)
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            local dx, dz = ex - x, ez - z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist - entradius <= self.radius then
                if ent.Physics and ent.Physics:GetMass() ~= 0 then
                    if self:ShouldRememberEntity(ent) then
                        watchedentities[ent] = true
                        self:RememberEntity(ent)
                    end
                elseif ent:HasTag("winchtarget") then
                    local ex, ey, ez = ent.Transform:GetWorldPosition()
                    local angle = -self.inst:GetAngleToPoint(ex, ey, ez) * DEGREES
                    local radius = self.radius + ent:GetPhysicsRadius(0) + 2 -- Small padding so that this can be winched easier.
                    ex, ez = x + math.cos(angle) * radius, z + math.sin(angle) * radius
                    if _map:IsOceanAtPoint(ex, ey, ez) then
                        ent.Transform:SetPosition(ex, ey, ez)
                        ent:PushEvent("teleported")
                        local fx = SpawnPrefab("splash_sink")
                        fx.Transform:SetPosition(ex, ey, ez)
                    else
                        -- Uproot and move to a nearby shore instead.
                        local salvaged_item = ent.components.winchtarget:Salvage()
                        if salvaged_item then
                            if salvaged_item.components.inventoryitem and salvaged_item.components.inventoryitem:IsHeld() then
                                salvaged_item = salvaged_item.components.inventoryitem:RemoveFromOwner(true)
                            end
                            if salvaged_item then
                                ex, ey, ez = FindRandomPointOnShoreFromOcean(ex, ey, ez)
                                salvaged_item.Transform:SetPosition(ex, ey, ez)
                                print(ex, ez)
                                salvaged_item:PushEvent("on_salvaged")
                            end
                        end
                        ent:Remove()
                    end
                end
            end
        end
    end
    for ent, _ in pairs(self.watchedentities) do
        if not watchedentities[ent] then
            self:ForgetEntity(ent)
        end
    end
end

function self:PullEntities(tickperiod)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    for ent, _ in pairs(self.watchedentities) do
        local ex, ey, ez = ent.Transform:GetWorldPosition()
        local dx, dz = ex - x, ez - z
        local dist = math.sqrt(dx * dx + dz * dz) + 0.001
        local speed = dist * tickperiod

        local px, pz = dx / dist, dz / dist
        local rx, rz = pz, -px -- Clockwise rotation.

        local forcemodifier = (self.focalradius / math.clamp(dist, self.focalradius, self.radius)) ^ self.forceexponent

        local radialforce = self.radialstrength * forcemodifier
        local inwardforce = -self.pullstrength * forcemodifier
        local vx, vz = (radialforce * rx + inwardforce * px) * speed, (radialforce * rz + inwardforce * pz) * speed

        ent.components.physicsmodifiedexternally:SetVelocityForSource(self.inst, vx, vz)

        if self.onentitytouchingfocalfn and (dist - ent:GetPhysicsRadius(0) * 0.5 <= self.focalradius) then
            self.onentitytouchingfocalfn(self.inst, ent)
        end
    end
end

function self:OnUpdate(dt)
    if self.fastcooldown then
        self.fastcooldown = self.fastcooldown - dt
        if self.fastcooldown <= 0 then
            self.fastcooldown = nil
        end
    end

    local tickperiod
    if self.fastcooldown or next(self.watchedentities) then
        tickperiod = TICK_FAST_PERIOD
    else
        tickperiod = TICK_SLOW_PERIOD
    end
    self.tickaccumulator = self.tickaccumulator + dt
    if self.tickaccumulator >= tickperiod then
        self.tickaccumulator = 0
        self:CheckForEntities()
        self:PullEntities(TICK_FAST_PERIOD) -- Always TICK_FAST_PERIOD for when physics simulating.
    end
end


end)