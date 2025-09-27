local ComplexProjectile = Class(function(self, inst)
    self.inst = inst

    self.velocity = Vector3(0, 0, 0)
    self.gravity = -9.81

    self.horizontalSpeed = 4
    self.launchoffset = nil
    self.targetoffset = nil

    self.owningweapon = nil
    self.attacker = nil

    self.onlaunchfn = nil
    self.onhitfn = nil
    self.onmissfn = nil
    self.onupdatefn = nil

    self.usehigharc = true

	--self.ismeleeweapon = false -- setting to true allows for melee attacks on left lick and toss on right click

    --NOTE: projectile and complexprojectile components are mutually
    --      exclusive because they share this tag!
    --V2C: Recommended to explicitly add tag to prefab pristine state
    inst:AddTag("projectile")
	inst:AddTag("complexprojectile")
end)

function ComplexProjectile:OnRemoveFromEntity()
	self.inst:RemoveTag("complexprojectile")
	if self.inst.components.projectile == nil then
		self.inst:RemoveTag("projectile")
	end
end

function ComplexProjectile:GetDebugString()
    return tostring(self.velocity)
end

function ComplexProjectile:SetHorizontalSpeed(speed)
    self.horizontalSpeed = speed
end

function ComplexProjectile:SetHorizontalSpeedForDistance(desired_horizontal_distance, fallback)
    local speed = self:CalculateMinimumSpeedForDistance(desired_horizontal_distance) or fallback
    self:SetHorizontalSpeed(speed)
end

function ComplexProjectile:SetGravity(g)
    self.gravity = g
end

function ComplexProjectile:SetLaunchOffset(offset)
    self.launchoffset = offset -- x is facing, y is height, z is ignored
end

function ComplexProjectile:SetTargetOffset(offset)
    self.targetoffset = offset -- x is ignored, y is height, z is ignored
end

function ComplexProjectile:SetOnLaunch(fn)
    self.onlaunchfn = fn
end

function ComplexProjectile:SetOnHit(fn)
    self.onhitfn = fn
end

function ComplexProjectile:SetOnUpdate(fn)
    self.onupdatefn = fn
end

function ComplexProjectile:CalculateMinimumSpeedForDistance(desired_horizontal_distance)
    local g = -self.gravity
    local dy = 0
    if self.launchoffset then
        dy = -self.launchoffset.y
        desired_horizontal_distance = desired_horizontal_distance - self.launchoffset.x
    end
    if self.targetoffset then
        dy = dy + self.targetoffset.y
    end
    local rangeSq = desired_horizontal_distance * desired_horizontal_distance
    local b = -2 * dy * g
    local c = -g * g * rangeSq
    local discriminant = b * b - 4 * c
    if discriminant < 0 then
        return nil
    end

    return math.sqrt((-b + math.sqrt(discriminant)) / 2) + 0.001 -- Add small offset for floating point math.
end

function ComplexProjectile:CalculateTrajectory(startPos, endPos, speed)
    local speedSq = speed * speed
    local g = -self.gravity

    local dx = endPos.x - startPos.x
    local dy = endPos.y - startPos.y
    local dz = endPos.z - startPos.z

    local rangeSq = dx * dx + dz * dz
    local discriminant = speedSq * speedSq - g * (g * rangeSq + 2 * dy * speedSq)
    local angle
    if discriminant >= 0 then
        local discriminantSqrt = math.sqrt(discriminant)
        local gXrange = g * math.sqrt(rangeSq)
        local angleA = math.atan((speedSq - discriminantSqrt) / gXrange)
        local angleB = math.atan((speedSq + discriminantSqrt) / gXrange)
        angle = self.usehigharc and math.max(angleA, angleB) or math.min(angleA, angleB)
    else
        --Not enough speed to reach endPos
        angle = 30 * DEGREES
    end

    local cosangleXspeed = math.cos(angle) * speed
    self.velocity.x = cosangleXspeed
    self.velocity.z = 0.0
    self.velocity.y = math.sin(angle) * speed
end

function ComplexProjectile:Launch(targetPos, attacker, owningweapon)
    local pos = self.inst:GetPosition()
    self.owningweapon = owningweapon or self.inst
    self.attacker = attacker

	self.inst:ForceFacePoint(targetPos:Get())

    local offset = self.launchoffset
    if attacker ~= nil and offset ~= nil then
        local facing_angle = self.inst.Transform:GetRotation() * DEGREES
        pos.x = pos.x + offset.x * math.cos(facing_angle)
        pos.y = pos.y + offset.y
        pos.z = pos.z - offset.x * math.sin(facing_angle)
        -- print("facing", facing_angle)
        -- print("offset", offset)
        if self.inst.Physics ~= nil then
            self.inst.Physics:Teleport(pos:Get())
        else
            self.inst.Transform:SetPosition(pos:Get())
        end
    end

    -- use targetoffset height, otherwise hit when you hit the ground
    targetPos.y = self.targetoffset ~= nil and self.targetoffset.y or 0

    self:CalculateTrajectory(pos, targetPos, self.horizontalSpeed)

	-- if the attacker is standing on a moving platform, then inherit it's velocity too
	local attacker_platform = attacker ~= nil and attacker:GetCurrentPlatform() or nil
	if attacker_platform and attacker_platform.Physics then
		local theta = self.inst.Transform:GetRotation() * DEGREES
		local sintheta = math.sin(theta)
		local costheta = math.cos(theta)
		local vx, vy, vz = attacker_platform.Physics:GetVelocity()
		local vx1 = vx * costheta - vz * sintheta
		local vz1 = vx * sintheta + vz * costheta
		self.velocity.x = self.velocity.x + vx1
		self.velocity.z = self.velocity.z + vz1
	end

    if self.onlaunchfn ~= nil then
        self.onlaunchfn(self.inst, attacker, targetPos)
    end

    self.inst:AddTag("activeprojectile")
    self.inst:StartUpdatingComponent(self)
end


function ComplexProjectile:Cancel()
	self.inst:RemoveTag("activeprojectile")
	self.inst:StopUpdatingComponent(self)
	self.inst.Physics:SetMotorVel(0, 0, 0)
	self.inst.Physics:Stop()
	self.velocity.x, self.velocity.y, self.velocity.z = 0, 0, 0
end

function ComplexProjectile:Hit(target)
	self:Cancel()
    if self.onhitfn ~= nil then
        self.onhitfn(self.inst, self.attacker, target)
    end
end

function ComplexProjectile:OnUpdate(dt)
    if self.onupdatefn ~= nil and self.onupdatefn(self.inst) then
        return
    end

    self.inst.Physics:SetMotorVel(self.velocity:Get())
    self.velocity.y = self.velocity.y + (self.gravity * dt)
    if self.velocity.y < 0 then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        if y <= 0.05 then -- a tiny bit above the ground, to account for collision issues
            self:Hit()
        end
    end
end

return ComplexProjectile
