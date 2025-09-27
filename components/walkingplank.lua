local WalkingPlank = Class(function(self, inst)
    self.inst = inst

    --self.doer = nil

    self.inst:AddTag("walkingplank")
end)

function WalkingPlank:OnRemoveFromEntity()
    self.inst:RemoveTag("walkingplank")
end

function WalkingPlank:Extend()
	self.inst:PushEventImmediate("start_extending")
end

function WalkingPlank:Retract()
	self.inst:PushEventImmediate("start_retracting")
end

function WalkingPlank:MountPlank(doer)
    if self.doer ~= nil then
        return false
    end

	self.doer = doer
	doer.Physics:Teleport(self.inst.Transform:GetWorldPosition())
	self.inst:PushEventImmediate("start_mounting")
	doer.components.walkingplankuser:SetCurrentPlank(self.inst)

    return true
end

function WalkingPlank:StopMounting()
    self.doer = nil
	self.inst:PushEventImmediate("stop_mounting")
end

function WalkingPlank:AbandonShip(doer)
    if doer == nil or doer ~= self.doer then
        return false
    end

    self.doer.components.walkingplankuser:Dismount()
	self.inst:PushEventImmediate("start_abandoning")

    return true
end

return WalkingPlank
