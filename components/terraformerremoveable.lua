local TerraformerRemoveable = Class(function(self, inst)
    self.inst = inst

    -- Recommended to explicitly add tag to prefab pristine state
    self.inst:AddTag("terraformerremoveable")
end)

function TerraformerRemoveable:OnRemoveFromEntity()
    self.inst:RemoveTag("terraformerremoveable")
end

function TerraformerRemoveable:SetOnRemovedFn(fn)
    self.onremovedfn = fn
end

function TerraformerRemoveable:TryToRemove(doer)
    if self.onremovedfn then
        self.onremovedfn(self.inst, doer)
    end

    return true
end

return TerraformerRemoveable
