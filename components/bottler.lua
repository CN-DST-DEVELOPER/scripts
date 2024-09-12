local Bottler = Class(function(self, inst)
	self.inst = inst
	self.onbottlefn = nil
end)

function Bottler:SetOnBottleFn(fn)
	self.onbottlefn = fn
end

function Bottler:Bottle(target, doer)
	if self.onbottlefn and target and target:IsValid() and target:HasTag("canbebottled") then
		return self.onbottlefn(self.inst, target, doer)
	end
	return false
end

return Bottler
