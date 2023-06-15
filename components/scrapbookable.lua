local Scrapbookable = Class(function(self, inst)
    self.inst = inst
end)

function Scrapbookable:Teach(doer)
    if self.onteach then
        self.onteach(self.inst, doer)
    end
   
    return true
end

return Scrapbookable