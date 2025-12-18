local MoonSparkChargeable = Class(function(self, inst)
    self.inst = inst

    self.fueled_percent = TUNING.MOONSTORM_SPARKCHARGE_DEFAULT

    --Recommended to explicitly add tag to prefab pristine state
    self.inst:AddTag("moonsparkchargeable")
end)

function MoonSparkChargeable:OnRemoveFromEntity()
    self.inst:RemoveTag("moonsparkchargeable")
end

function MoonSparkChargeable:SetFueledPercent(amount)
    self.fueled_percent = amount
end

function MoonSparkChargeable:DoSpark(doer)
    if self.fueled_percent ~= 0 and self.inst.components.fueled then
        local newpercent = math.clamp(self.inst.components.fueled:GetPercent() + self.fueled_percent, 0, 1)
        self.inst.components.fueled:SetPercent(newpercent)
    end
end

return MoonSparkChargeable
