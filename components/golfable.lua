local function ongolfclub(self, golfclub)
	self.inst:AddOrRemoveTag("golfable_occupied", golfclub ~= nil)
end

local function OnEnterLimbo(inst)
	local self = inst.components.golfable
	if self.golfclub then
		self.golfclub:StopAiming()
	end
end

local Golfable = Class(function(self, inst)
	self.inst = inst
	self.golfclub = nil --ref to golfclub component that is currently aiming us
	self.onoccupiedfn = nil
	self.onunoccupiedfn = nil
	self.onhitfn = nil

	--V2C: Recommended to explicitly add tag to prefab pristine state
	inst:AddTag("golfable")

	inst:ListenForEvent("enterlimbo", OnEnterLimbo)
end,
nil,
{
	golfclub = ongolfclub,
})

function Golfable:SetOnOccupiedFn(fn)
	self.onoccupiedfn = fn
end

function Golfable:SetOnUnoccupiedFn(fn)
	self.onunoccupiedfn = fn
end

function Golfable:SetOnHitFn(fn)
	self.onhitfn = fn
end

function Golfable:IsOccupied()
	return self.golfclub ~= nil
end

--called by golfclub component
function Golfable:OnOccupied(doer, golfclub)
	assert(self.golfclub == nil)
	self.golfclub = golfclub

	if self.onoccupiedfn then
		self.onoccupiedfn(self.inst, doer, golfclub.inst)
	end
end

--called by golfclub component
function Golfable:OnUnoccupied(golfclub)
	assert(self.golfclub == golfclub)
	self.golfclub = nil

	if self.onunoccupiedfn then
		self.onunoccupiedfn(self.inst, golfclub.inst)
	end
end

function Golfable:OnHit(doer, golfclub, dir, speed)
	if self.golfclub == golfclub then
		self.inst.Transform:SetRotation(dir)
		local theta = dir * DEGREES
		self.inst.Physics:SetVel(speed * math.cos(theta), 0, -speed * math.sin(theta))
		if self.onhitfn then
			self.onhitfn(self.inst, doer, golfclub.inst, dir, speed)
		end
	end
end

function Golfable:OnExternalPhysics(doer, dir, speed) -- e.g. pushed by the spinner
	if self.onhitfn then
		self.onhitfn(self.inst, doer, nil, dir, speed)
	end
end

function Golfable:OnRemoveFromEntity()
	if self.golfclub then
		self.golfclub:StopAiming()
	end
	self.inst:RemoveEventCallback("enterlimbo", OnEnterLimbo)
	self.inst:RemoveTag("golfable")
	--self.inst:RemoveTag("golfable_occupied") --StopAiming should've removed it
end

function Golfable:OnRemoveEntity()
	if self.golfclub then
		self.golfclub:StopAiming()
	end
end

return Golfable
