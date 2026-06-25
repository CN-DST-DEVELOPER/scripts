local GolfClub = Class(function(self, inst)
    self.inst = inst
	self.golfable = nil --ref to golfable component that we are currently aiming
	self.onstartaimingfn = nil
	self.onstopaimingfn = nil
end)

function GolfClub:SetOnStartAimingFn(fn)
	self.onstartaimingfn = fn
end

function GolfClub:SetOnStopAimingFn(fn)
	self.onstopaimingfn = fn
end

----------------------

function GolfClub:IsAiming()
	return self.golfable ~= nil
end

function GolfClub:GetTarget()
	return self.golfable and self.golfable.inst
end

function GolfClub:StartAiming(doer, target)
	if self.golfable == nil and
		target and target.components.golfable and
		target:IsValid() and not target:IsInLimbo()
	then
		if target.components.golfable:IsOccupied() then
			return false, "INUSE"
		end

		self.golfable = target.components.golfable
		self.golfable:OnOccupied(doer, self)

		if self.inst.components.golfclub_reticule then
			self.inst.components.golfclub_reticule:SetTarget(target)
		end

		if self.onstartaimingfn then
			self.onstartaimingfn(self.inst, doer, target)
		end
		return true
	end
	return false
end

function GolfClub:StopAiming()
	local golfable = self.golfable
	if golfable then
		self.golfable = nil
		golfable:OnUnoccupied(self)

		if self.inst.components.golfclub_reticule then
			self.inst.components.golfclub_reticule:SetTarget(nil)
		end

		if self.onstopaimingfn then
			self.onstopaimingfn(self.inst, golfable.inst)
		end
	end
end

--called from SGwilson
function GolfClub:OnStartSwing(doer)
	local speedscale = 1
	if self.inst.components.golfclub_reticule then
		speedscale = self.inst.components.golfclub_reticule:CalculateChargingScale()
		self.inst.components.golfclub_reticule:SetTarget(nil)
	end
	return speedscale
end

--called from SGwilson
function GolfClub:OnSwingHit(doer, speed)
	if doer and self.golfable then
		local dir = doer.Transform:GetRotation()
		self.golfable:OnHit(doer, self, dir, speed)
		self.inst:PushEvent("golfclub_onswinghit", { golfable = self.golfable, doer = doer, speed = speed })
	end
	self:StopAiming()
end

GolfClub.OnRemoveFromEntity = GolfClub.StopAiming
GolfClub.OnRemoveEntity = GolfClub.StopAiming

return GolfClub
