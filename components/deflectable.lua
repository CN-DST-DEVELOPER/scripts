local Deflectable = Class(function(self, inst)
	self.inst = inst
	--self.owner = nil
	--self.ondeflect = nil
	--self.keepondeflect = nil

	--V2C: Recommended to explicitly add tag to prefab pristine state
	inst:AddTag("deflectable")
end)

function Deflectable:OnRemoveFromEntity()
	self.inst:RemoveTag("deflectable")
end

function Deflectable:SetOnDeflectFn(fn)
	self.ondeflect = fn
end

function Deflectable:SetKeepOnDeflect(keep)
	self.keepondeflect = keep
end

function Deflectable:SetOwner(owner)
	self.owner = owner
end

function Deflectable:GetOwner()
	return self.owner
end

function Deflectable:Deflect(deflector)
	if self.ondeflect then
		self.ondeflect(self.inst, self.owner, deflector)
	end
	if not self.keepondeflect then
		self.inst:Remove()
	end
end

return Deflectable
