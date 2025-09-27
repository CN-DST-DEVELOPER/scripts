local GraveDigger = Class(function(self, inst)
    self.inst = inst

    -- self.onused = nil
end)

function GraveDigger:OnUsed(user, target)
    if self.onused then
        self.onused(self.inst, user, target)
    end
end

return GraveDigger