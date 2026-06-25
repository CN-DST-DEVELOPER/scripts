local GolfballSpinner = Class(function(self, inst)
    self.inst = inst

    self.radius = 1
    self.counterclockwise = false
    self.radialstrength = 3
    self.enabled = false
	self.period = 2 --seconds
end)

function GolfballSpinner:OnRemoveFromEntity()

end

--------------------------------------------------------------------------

function GolfballSpinner:SetEnabled(enabled)
    if self.enabled ~= enabled then
        if not self.inst:IsAsleep() then
            if enabled then
                self.inst:StartUpdatingComponent(self)
            else
                self.inst:StopUpdatingComponent(self)
            end
        end
        self.enabled = enabled
    end
end

function GolfballSpinner:SetRadius(radius)
    self.radius = radius
end

function GolfballSpinner:GetRadius()
    return self.radius
end

function GolfballSpinner:SetRadialStrength(radialstrength)
    self.radialstrength = radialstrength
end

function GolfballSpinner:GetRadialStrength()
    return self.radialstrength
end

function GolfballSpinner:SetIsCounterClockwise(ccw)
    self.counterclockwise = ccw or false
end

--------------------------------------------------------------------------

local GROUNDSPINNER_MUST_TAGS = { "golfable" }
function GolfballSpinner:SpinGolfBalls(dt)
	local minaccelradius = math.min(0.1, self.radius)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, self.radius, GROUNDSPINNER_MUST_TAGS)
    for _, ent in ipairs(ents) do
        local ex, ey, ez = ent.Transform:GetWorldPosition()
		if ey < 0.1 then
			local dx, dz = ex - x, ez - z
			local dist, acceldir, accelx, accelz
			if dx == 0 and dz == 0 then
				dist = minaccelradius
				acceldir = 360 * math.random()
				local theta = acceldir * DEGREES
				accelx = dist * math.cos(theta)
				accelz = -dist * math.sin(theta)
			else
				local actualdist = math.sqrt(dx * dx + dz * dz)
				dist = math.max(minaccelradius, actualdist)
				accelx = -dz / actualdist
				accelz = dx / actualdist
				acceldir = math.atan2(-accelz, accelx) * RADIANS
			end
			if self.counterclockwise then
				accelx, accelz = -accelx, -accelz
				acceldir = ReduceAngle(acceldir + 180)
			end

			local accel = TWOPI * dist / self.period * dt

			local vx1, vy1, vz1 = ent.Physics:GetVelocity()
			vx1 = vx1 + accel * accelx
			vz1 = vz1 + accel * accelz
			ent.Physics:SetVel(vx1, vy1, vz1)
			ent.components.golfable:OnExternalPhysics(self.inst, acceldir, accel)
        end
    end
end

function GolfballSpinner:OnUpdate(dt)
    self:SpinGolfBalls(dt)
end

function GolfballSpinner:OnEntitySleep()
    if self.enabled then
        self.inst:StopUpdatingComponent(self)
    end
end

function GolfballSpinner:OnEntityWake()
    if self.enabled then
        self.inst:StartUpdatingComponent(self)
    end
end

return GolfballSpinner