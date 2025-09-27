local function oncanbedug(self, canbedug)
    self.inst:AddOrRemoveTag("gravediggable", canbedug)
end

local GraveDiggable = Class(function(self, inst)
    self.inst = inst

    self.canbedug = true
    -- self.ondug = nil

    -- Add at construction time, for optimization.
    self.inst:AddTag("gravediggable") -- for componentactions
end,
nil,
{
    canbedug = oncanbedug,
})

function GraveDiggable:OnRemoveFromEntity()
    self.inst:RemoveTag("gravediggable")
end

function GraveDiggable:DigUp(tool, doer)
    local success, reason = true, nil
    if self.ondug then
        success, reason = self.ondug(self.inst, tool, doer)
    end

    return success, reason
end

-- Save/Load
function GraveDiggable:OnSave()
    return { canbedug = self.canbedug }
end

function GraveDiggable:OnLoad(data)
    if not data.canbedug then
        self.canbedug = false
    end
end

--
return GraveDiggable