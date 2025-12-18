local SourceModifierList = require("util/sourcemodifierlist")

local NonSlipGritUser = Class(function(self, inst)
    self.inst = inst

    self._sources = SourceModifierList(inst, false, SourceModifierList.boolean)
end)

function NonSlipGritUser:AddSource(src, key)
    self._sources:SetModifier(src, true, key)
end

function NonSlipGritUser:RemoveSource(src, key)
    self._sources:RemoveModifier(src, key)
    if not self._sources:Get() then
        self.inst:RemoveComponent("nonslipgrituser")
    end
end

local function IsValidGritSource(item)
    return item.components.nonslipgritsource ~= nil
end

function NonSlipGritUser:DoDelta(dt)
    local inventory = self.inst.components.inventory
    if inventory then
        local item = inventory:FindItem(IsValidGritSource)
        if item then
            item.components.nonslipgritsource:DoDelta(dt)
        end
    end
end

return NonSlipGritUser
