local MoistureAbsorberSource = Class(function(self, inst)
    self.inst = inst

    --self.getdryingratefn = nil

    MakeComponentAnInventoryItemSource(self)
end)

function MoistureAbsorberSource:OnRemoveFromEntity()
    RemoveComponentInventoryItemSource(self)
end

function MoistureAbsorberSource:OnItemSourceRemoved(owner)
    local moistureabsorberuser = owner.components.moistureabsorberuser
    if moistureabsorberuser then
        moistureabsorberuser:RemoveSource(self.inst)
    end
end

function MoistureAbsorberSource:OnItemSourceNewOwner(owner)
    if owner.components.moisture then
        local moistureabsorberuser = owner.components.moistureabsorberuser or owner:AddComponent("moistureabsorberuser")
        moistureabsorberuser:AddSource(self.inst)
    end
end

function MoistureAbsorberSource:SetGetDryingRateFn(fn)
    self.getdryingratefn = fn
end

function MoistureAbsorberSource:GetDryingRate(rate)
    if not self.getdryingratefn then
        return 0
    end

    local drate = self.getdryingratefn(self.inst, rate)
    if rate > 0 then
        drate = drate * TUNING.MOISTUREABSORBER_RAINED_ON_EFFICIENCY_MULT
    end
    return drate
end

function MoistureAbsorberSource:SetApplyDryingFn(fn)
    self.applydryingfn = fn
end

function MoistureAbsorberSource:ApplyDrying(rate, dt)
    if self.applydryingfn then
        self.applydryingfn(self.inst, rate, dt)
    end
end

return MoistureAbsorberSource
