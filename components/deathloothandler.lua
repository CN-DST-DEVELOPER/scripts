-- Just handle a value, doesn't actually drop the loot here.

local DeathLootHandler = Class(function(self, inst)
    self.inst = inst

    self.level = 0
end)

function DeathLootHandler:SetLevel(num)
    self.level = num
end

function DeathLootHandler:GetLevel()
    return self.level
end

function DeathLootHandler:OnSave()
    return self.level > 0 and { level = self.level, add_component_if_missing = true } or nil
end

function DeathLootHandler:OnLoad(data)
    if data ~= nil then
        self.level = data.level or 0
    end
end

return DeathLootHandler