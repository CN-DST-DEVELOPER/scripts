-- Just handle a value, doesn't actually drop the loot here.
-- OK this might become false ^ :)

local DeathLootHandler = Class(function(self, inst)
    self.inst = inst

    self.level = 0
    self.loot = {}
end)

function DeathLootHandler:StoreLoot(prefabs)
    for i, pref in ipairs(prefabs) do
        table.insert(self.loot, pref)
    end
end

function DeathLootHandler:GetLoot()
    return self.loot
end

function DeathLootHandler:SetLevel(num)
    self.level = num
end

function DeathLootHandler:GetLevel()
    return self.level
end

function DeathLootHandler:OnSave()
    return self.level > 0 and { level = self.level, loot = self.loot, add_component_if_missing = true } or nil
end

function DeathLootHandler:OnLoad(data)
    if data ~= nil then
        self.level = data.level or 0
        self.loot = data.loot or {}
    end
end

return DeathLootHandler