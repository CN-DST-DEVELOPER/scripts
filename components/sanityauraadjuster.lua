local SanityAuraAdjuster = Class(function(self, inst)
    self.inst = inst
   	self.adjustmentfn = nil
   	self.players = {}
end)

function SanityAuraAdjuster:StopTask()
	if self.inst.sanityAuraAdjuster_task then
		self.inst.sanityAuraAdjuster_task:Cancel()
		self.inst.sanityAuraAdjuster_task = nil
	end
end

function SanityAuraAdjuster:StartTask()
	local checkforadjustments = function()	
		if self.adjustmentfn then
			self.players = self.adjustmentfn(self.inst, self.players)
		end		
	end

	if not self.inst.sanityAuraAdjuster_task then
		self.inst.sanityAuraAdjuster_task = self.inst:DoPeriodicTask(1,checkforadjustments)
	end
end

function SanityAuraAdjuster:SetAdjustmentFn(fn)
	self.adjustmentfn = fn
end

return SanityAuraAdjuster
