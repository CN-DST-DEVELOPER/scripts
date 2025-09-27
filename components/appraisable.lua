local Appraisable = Class(function(self, inst)
	self.inst = inst
end)

function Appraisable:CanAppraise(target)
    -- NOTE: don't chain these together in case
    -- the canappraisefn returns a failure reason.
	if self.canappraisefn then
		return self.canappraisefn(self.inst, target)
    else
        return true
    end
end

function Appraisable:Appraise(target)
	if self.appraisefn then
		self.appraisefn(self.inst,target)
	end
end

return Appraisable
