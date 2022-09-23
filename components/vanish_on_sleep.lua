
local Vanish_on_sleep = Class(function(self, inst)
    self.inst = inst    

    inst:StartUpdatingComponent(self)
end)


function Vanish_on_sleep:vanish()
	if self.vanishfn then
		self.vanishfn(self.inst)
	end
	self.inst:Remove()
end

function Vanish_on_sleep:OnUpdate(dt)

	local outofrange = true

	local x,y,z = self.inst.Transform:GetWorldPosition()
	local player = FindClosestPlayer(x, y, z)
	if player then
		if self.inst:GetDistanceSqToInst(player) < 60*60 then
			outofrange = false
		end
	end

    if outofrange then
    	if not self.vanish_task then
        	self.vanish_task = self.inst:DoTaskInTime(10,function() self:vanish() end)
        end
    else
    	if self.vanish_task then
    		self.vanish_task:Cancel()
    		self.vanish_task = nil
    	end
    end
   
end

return Vanish_on_sleep
