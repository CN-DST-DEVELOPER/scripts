local SourceModifierList = require("util/sourcemodifierlist")

local MoistureAbsorberUser = Class(function(self, inst)
    self.inst = inst

    self._sources = SourceModifierList(inst, false, SourceModifierList.boolean)
end)

function MoistureAbsorberUser:AddSource(src, key)
    self._sources:SetModifier(src, true, key)
end

function MoistureAbsorberUser:RemoveSource(src, key)
    self._sources:RemoveModifier(src, key)
    if not self._sources:Get() then
        self.inst:RemoveComponent("moistureabsorberuser")
    end
end

local function FindBestMoistureAbsorber(item, results, rate)
    if item.components.moistureabsorbersource then
        local itemrate = item.components.moistureabsorbersource:GetDryingRate(rate)
        if itemrate > results.bestrate then
            results.item = item
            results.bestrate = itemrate
        end
    end
end

function MoistureAbsorberUser:GetBestAbsorberRate(rate, dt)
    local inventory = self.inst.components.inventory
    if inventory then
        local results = {
            item = nil,
            bestrate = 0,
        }
        inventory:ForEachItem(FindBestMoistureAbsorber, results, rate)
        if results.item then
            results.item.components.moistureabsorbersource:ApplyDrying(rate, dt)
        end
        return results.bestrate
    end
    return 0
end

return MoistureAbsorberUser
