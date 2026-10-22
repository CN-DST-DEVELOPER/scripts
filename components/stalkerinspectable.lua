local StalkerInspectable = Class(function(self, inst)
    self.inst = inst
    -- inst:AddTag("stalkerinspectable")
end)

function StalkerInspectable:OnRemoveFromEntity()
    -- self.inst:RemoveTag("stalkerinspectable")
end

function StalkerInspectable:SetNameOverride(nameoverride)
    self.nameoverride = nameoverride
end

function StalkerInspectable:GetName(viewer)
    return FunctionOrValue(self.nameoverride, self.inst, viewer)
        or self.inst.prefab
end

return StalkerInspectable
