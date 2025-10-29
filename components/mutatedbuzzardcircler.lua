--local easing = require("easing")

local function IsValidToEnterNode(inst)
    return not inst._killed and inst:IsValid()
end

local function OnRemove(inst)
    local mutatedbuzzardcircler = inst.components.mutatedbuzzardcircler
    if mutatedbuzzardcircler then
        mutatedbuzzardcircler:SetCircleTarget(nil)
    end
end

local MutatedBuzzardCircler = Class(function(self, inst)
    self.inst = inst

    self.scale = 1
    self.speed = math.random(3)
    self.circle_target = nil

    self.min_speed = 5
    self.max_speed = 7

    self.min_dist = 8
    self.max_dist = 12

    self.min_scale = 8
    self.max_scale = 12

    self.sine_mod = (10 + math.random() * 20) * .001
    self.sine = 0

    self.update_target_pos_cooldown = 0
    self.last_valid_migration_node = nil

    self.inst:ListenForEvent("onremove", OnRemove)
end)

function MutatedBuzzardCircler:SetMode(mode)
    self.circlerMode = mode
end

function MutatedBuzzardCircler:Start()
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:SetCircleTarget(nil)
        return
    end

    self.speed = math.random(self.min_speed, self.max_speed) * .01
    self.distance = math.random(self.min_dist, self.max_dist)
    self.angleRad = math.random() * TWOPI
    self.offset = Vector3(self.distance * math.cos(self.angleRad), 0, -self.distance * math.sin(self.angleRad))

    self.direction = (math.random() < .5 and .5 or -.5) * PI

    local x, y, z = self.circle_target.Transform:GetWorldPosition()
    self.inst.Transform:SetRotation(self.inst:GetAngleToPoint(self.circle_target:GetPosition()))
    self.inst.Transform:SetPosition(x + self.offset.x, 0, z + self.offset.z)
    self:UpdateMigrationNode()

    self.inst:StartUpdatingComponent(self)
end

function MutatedBuzzardCircler:Stop()
    self.inst:StopUpdatingComponent(self)
end

function MutatedBuzzardCircler:SetCircleTarget(tar)
    if self.circle_target then
        self.circle_target._num_circling_buzzards = self.circle_target._num_circling_buzzards - 1

		self.inst:RemoveEventCallback("onremove", self._ontargetremoved, self.circle_target)
		self.inst:RemoveEventCallback("death", self._ontargetremoved, self.circle_target)
		self._ontargetremoved = nil
	end

    self.circle_target = tar

    if self.circle_target then
        self.circle_target._num_circling_buzzards = (self.circle_target._num_circling_buzzards or 0) + 1

        self._ontargetremoved = function()
            local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
            if mutatedbirdmanager and IsValidToEnterNode(self.inst) then
                mutatedbirdmanager:FillMigrationTaskWithType("mutatedbuzzard_gestalt", self.last_valid_migration_node, 1)
                mutatedbirdmanager:RemoveBuzzardShadow(self.inst)
            end
			self.circle_target = nil
		end
        self.inst:ListenForEvent("onremove", self._ontargetremoved, self.circle_target)
        self.inst:ListenForEvent("death", self._ontargetremoved, self.circle_target)
    end
end

function MutatedBuzzardCircler:GetSpeed()
    local speed = self.speed
    return (self.direction > 0 and -speed) or speed
end

function MutatedBuzzardCircler:GetMinSpeed()
    return self.min_speed
end

function MutatedBuzzardCircler:GetMaxSpeed()
    return self.max_speed
end

function MutatedBuzzardCircler:GetMinScale()
    return self.min_scale * .1
end

function MutatedBuzzardCircler:GetMaxScale()
    return self.max_scale * .1
end

function MutatedBuzzardCircler:GetDebugString()
    return string.format("Sine: %4.4f, Speed: %3.3f/%3.3f", self.sine, self.speed, self:GetMaxSpeed())
end

function MutatedBuzzardCircler:UpdateMigrationNode()
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:SetCircleTarget(nil)
        return
    end

    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    if mutatedbirdmanager then
        local migration_node = mutatedbirdmanager:GetMigrationTaskAtInst(self.circle_target)
        local dist_last_node_to_target = mutatedbirdmanager:GetMigrationDistanceFromTaskToTask(self.last_valid_migration_node, migration_node)
        if migration_node ~= nil and (self.last_valid_migration_node == nil or (dist_last_node_to_target and dist_last_node_to_target <= 1) ) then
            self.last_valid_migration_node = migration_node
        else
            -- Migration node is invalid, either because it doesn't exist, or it's too far away. Return.
            if IsValidToEnterNode(self.inst) then
                mutatedbirdmanager:FillMigrationTaskWithType("mutatedbuzzard_gestalt", self.last_valid_migration_node, 1)
                mutatedbirdmanager:RemoveBuzzardShadow(self.inst)
            end
        end
    end
end

local MIN_DIST_SQ = 10 * 10
local MAX_DIST_SQ = 30 * 30
function MutatedBuzzardCircler:OnUpdate(dt)
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:Stop()
        self:SetCircleTarget(nil)
        return
    end

	if self.target_pos then
		local x, _, z = self.circle_target.Transform:GetWorldPosition()
		local k = math.min(1, dt / 2)
		self.target_pos.x = x * k + self.target_pos.x * (1 - k)
		self.target_pos.z = z * k + self.target_pos.z * (1 - k)
	else
		self.target_pos = self.circle_target:GetPosition()
	end

    if self.update_target_pos_cooldown <= 0 then
        self.update_target_pos_cooldown = 3
        self:UpdateMigrationNode()
    end

    if not self.inst:IsValid() then -- Might become invalid from UpdateMigrationNode
        return
    end

    local reverse = self.direction > 0

    self.sine = GetSineVal(self.sine_mod, true, self.inst)

    self.speed = Lerp(self:GetMinSpeed() - .003, self:GetMaxSpeed() + .003, self.sine)
    self.speed = math.clamp(self.speed, self:GetMinSpeed(), self:GetMaxSpeed())

    self.scale = Lerp(self:GetMaxScale(), self:GetMinScale(), (self.speed - self:GetMinSpeed())/(self:GetMaxSpeed() - self:GetMinSpeed()))
    self.inst.Transform:SetScale(self.scale, self.scale, self.scale)

    local angle = reverse and -180 or 0
    local distsq = self.inst:GetDistanceSqToInst(self.circle_target)
    local accelerator_perc = math.clamp((distsq - MIN_DIST_SQ) / MAX_DIST_SQ, 0, 1)

    angle = reverse and angle - Lerp(0, 35, accelerator_perc)
        or angle + Lerp(0, 35, accelerator_perc)

    local pt = self.target_pos
    local rot1 = self.inst.Transform:GetRotation() + angle
    local rot2 = self.inst:GetAngleToPoint(pt)
    local diff = ReduceAngle(rot2 - rot1)
    rot2 = rot1 + diff * Lerp(.02, .1, self.sine)
    self.inst.Transform:SetRotation(rot2 - angle)

    local extra_speed = Lerp(0, 10, accelerator_perc)

    local vel_x = reverse
        and -Lerp(.5, 1, self.sine) - extra_speed * 0.5
        or Lerp(.5, 1, self.sine) + extra_speed * 0.5
    self.inst.Physics:SetMotorVelOverride(vel_x, 0, -self.speed - extra_speed)

    self.update_target_pos_cooldown = self.update_target_pos_cooldown - dt
end

function MutatedBuzzardCircler:OnEntitySleep()
    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    if mutatedbirdmanager then
        local function StoreInMigrationNode()
            if IsValidToEnterNode(self.inst) then
                mutatedbirdmanager:FillMigrationTaskWithType("mutatedbuzzard_gestalt", self.last_valid_migration_node, 1)
                self.inst:Remove()
            end
        end

        if self.circle_target and self.circle_target:IsValid() then
            local migration_node = mutatedbirdmanager:GetMigrationTaskAtInst(self.circle_target)
            local dist_last_node_to_target = mutatedbirdmanager:GetMigrationDistanceFromTaskToTask(self.last_valid_migration_node, migration_node)
            if migration_node ~= nil and (self.last_valid_migration_node == nil or (dist_last_node_to_target and dist_last_node_to_target <= 1) ) then
                self.last_valid_migration_node = migration_node
            end
            StoreInMigrationNode()
        elseif self.last_valid_migration_node ~= nil then
            StoreInMigrationNode()
        end
    end
end

return MutatedBuzzardCircler
