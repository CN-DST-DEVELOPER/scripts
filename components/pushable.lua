local Pushable = Class(function(self, inst)
	self.inst = inst
	--self.doer = nil
	--self.onstartpushingfn = nil
	--self.onstoppushingfn = nil
	--self.targetdist = nil --speed compensates to try and maintain this distance from pusher
	--self.mindist = nil --stop forward motion of pusher if we're too close
	--self.maxdist = nil --cancel pushing if drifted too far apart
	self.speed = 3 --pusher walk speed
end)

function Pushable:SetTargetDist(dist)
	self.targetdist = dist
end

function Pushable:SetMinDist(dist)
	self.mindist = dist
end

function Pushable:SetMaxDist(dist)
	self.maxdist = dist
end

function Pushable:SetPushingSpeed(speed)
	self.speed = speed
end

function Pushable:SetOnStartPushingFn(fn)
	self.onstartpushingfn = fn
end

function Pushable:SetOnStopPushingFn(fn)
	self.onstoppushingfn = fn
end

function Pushable:IsPushing()
	return self.doer ~= nil
end

function Pushable:GetPushingSpeed()
	return self.speed
end

function Pushable:ShouldStopForwardMotion()
	return self.mindist and self.doer and self.doer:IsValid() and self.doer:IsNear(self.inst, self.doer:GetPhysicsRadius(0) + self.mindist)
end

function Pushable:StartPushing(doer)
	self:StopPushing()
	if doer and doer:IsValid() and doer.sg then
		self.doer = doer
		self.inst:StartUpdatingComponent(self)
		if self.onstartpushingfn then
			self.onstartpushingfn(self.inst, doer)
		end
		self.inst:PushEvent("startpushing", { doer = doer })

		if self.doer == doer then --make sure nothing changed due to callbacks
			self:OnUpdate(0)
		end
	end
end

function Pushable:StopPushing(doer)
	if self.doer and (doer == nil or doer == self.doer) then
		doer = self.doer --since we support nil doer
		self.doer = nil
		self.inst.Physics:Stop()
		self.inst:StopUpdatingComponent(self)
		if self.onstoppushingfn then
			self.onstoppushingfn(self.inst, doer)
		end
		self.inst:PushEvent("stoppushing", { doer = doer })
	end
end

function Pushable:OnUpdate(dt)
	if not (self.doer.sg and
			self.doer.sg:HasStateTag("pushing_walk") and
			self.doer:IsValid()) or
		(self.maxdist and not self.inst:IsNear(self.doer, self.doer:GetPhysicsRadius(0) + self.maxdist))
	then
		self:StopPushing()
	else
		local speed = self.speed
		if self.targetdist then
			local target_dist = self.doer:GetPhysicsRadius(0) + self.targetdist
			local current_dist = math.sqrt(self.inst:GetDistanceSqToInst(self.doer))
			speed = speed + math.clamp((target_dist - current_dist) * 10, -0.5 * speed, 2 * speed)
		end
		self.inst.Physics:SetMotorVel(speed, 0, 0)
	end
end

Pushable.OnRemoveFromEntity = Pushable.StopPushing

return Pushable
