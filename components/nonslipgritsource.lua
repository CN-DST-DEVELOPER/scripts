local NonSlipGritSource = Class(function(self, inst)
    self.inst = inst

    --self.ondeltafn = nil

    MakeComponentAnInventoryItemSource(self)
end)

function NonSlipGritSource:OnRemoveFromEntity()
    RemoveComponentInventoryItemSource(self)
end

function NonSlipGritSource:OnItemSourceRemoved(owner)
    local nonslipgrituser = owner.components.nonslipgrituser
    if nonslipgrituser then
        nonslipgrituser:RemoveSource(self.inst)
    end
end

function NonSlipGritSource:OnItemSourceNewOwner(owner)
    if owner.components.slipperyfeet then
        local nonslipgrituser = owner.components.nonslipgrituser or owner:AddComponent("nonslipgrituser")
        nonslipgrituser:AddSource(self.inst)
    end
end

function NonSlipGritSource:SetOnDeltaFn(fn)
    self.ondeltafn = fn
end

function NonSlipGritSource:DoDelta(dt)
    if self.ondeltafn then
        self.ondeltafn(self.inst, dt)
    end
end

return NonSlipGritSource
