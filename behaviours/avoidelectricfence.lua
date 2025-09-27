local function onelectrocute(inst)
    inst.brain:ForceUpdate() --TODO Can we move this to shocked_by_field?
end

AvoidElectricFence = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "AvoidElectricFence")
    --
    self.inst = inst
    self.run_angle = nil
    --
    inst._has_electric_fence_panic_trigger = true --used by BrainCommon.HasElectricFencePanicTriggerNode
    --
    self.shocked_by_field = function(_, field)
        self.run_angle = self:GetRunAngle(field)
        inst.brain:ForceUpdate()
    end
    --
    self.inst:ListenForEvent("startelectrocute", onelectrocute)
    self.inst:ListenForEvent("shocked_by_new_field", self.shocked_by_field)
end)

function AvoidElectricFence:OnStop()
	self.inst:RemoveEventCallback("startelectrocute", onelectrocute)
	self.inst:RemoveEventCallback("shocked_by_new_field", self.shocked_by_field)
end

local function GetOtherFields(fences)
    
end

--TODO we can still improve this, in an odd angled corner piece we should get the run away angle a lil differently
function AvoidElectricFence:GetRunAngle(field)
    local xs, zs = 0, 0
    --
	for i = 1, #field.fences do
		local x, y, z = field.fences[i].Transform:GetWorldPosition()
		local angle = self.inst:GetAngleToPoint(x, 0, z) * DEGREES
		xs, zs = xs - math.cos(angle), zs - math.sin(angle)
    end
    --
	return (math.atan2(zs, xs) * RADIANS) % 360 --TODO i think we can get away with some variance?


    --[[
    local rot = inst.Transform:GetRotation() * DEGREES
    local rot1 = math.atan2(-dz, dx)
	local diff = ReduceAngleRad(rot - rot1)
	rot1 = rot1 - diff + math.pi
	if recoilangle then
		diff = ReduceAngleRad(rot1 - recoilangle)
		recoilangle = ReduceAngleRad(recoilangle + diff / 2)
	else
		recoilangle = ReduceAngleRad(rot1)
	end
    ]]

end

function AvoidElectricFence:Visit()
    if self.status == READY and self.run_angle then
        self.status = RUNNING

        if self.inst.components.combat then
            self.inst.components.combat:DropTarget()
        end
    end

    if self.status == RUNNING then
        self.inst.components.locomotor:RunInDirection(self.run_angle)
    end
end

function AvoidElectricFence:__tostring()
    return string.format("AVOIDELECTRICFENCE, %s", self.run_angle)
end