local ItemMimicConfig = Class(function(self, inst)
    self.inst = inst

    self.forcedrevealactions = {}
end)

function ItemMimicConfig:SetLastAction(action)
    self.lastaction = action
end

function ItemMimicConfig:GetLastAction()
    return self.lastaction
end

function ItemMimicConfig:AddActionForceMimicReveal(action)
    self.forcedrevealactions[action] = true
end

function ItemMimicConfig:RemoveActionForceMimicReveal(action)
    self.forcedrevealactions[action] = nil
end

function ItemMimicConfig:DoesActionForceMimicReveal(action)
    return self.forcedrevealactions[action]
end

return ItemMimicConfig
