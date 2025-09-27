local function onshowoceanaction(self)
    self.inst:AddOrRemoveTag("fillable_showoceanaction", self.showoceanaction)
    self.inst:AddOrRemoveTag("allow_action_on_impassable", self.showoceanaction) -- For point action on the ocean.
end

local Fillable = Class(function(self, inst)
    self.inst = inst

    self.filledprefab = nil
    --self.overrideonfillfn = nil

    self.acceptsoceanwater = false
    self.showoceanaction = false
    --self.oceanwatererrorreason = nil

    self.inst:AddTag("fillable")
end, nil,
{
    showoceanaction = onshowoceanaction,
})

function Fillable:OnRemoveFromEntity()
    self.inst:RemoveTag("fillable")
    self.inst:RemoveTag("fillable_showoceanaction")
    self.inst:RemoveTag("allow_action_on_impassable")
end

function Fillable:Fill(from_object)
    if from_object ~= nil and from_object.components.watersource ~= nil then
        from_object.components.watersource:Use()
    end

    if self.overrideonfillfn ~= nil then
        return self.overrideonfillfn(self.inst, from_object)
    end

    if self.filledprefab == nil then
        return false
    end

    local filleditem = SpawnPrefab(self.filledprefab)
    if filleditem == nil then
        return false
    end

    local owner = self.inst.components.inventoryitem ~= nil and self.inst.components.inventoryitem:GetGrandOwner() or nil
    if owner ~= nil then
        local container = owner.components.inventory or owner.components.container
        local item = container:RemoveItem(self.inst, false) or self.inst
        item:Remove()
        container:GiveItem(filleditem, nil, owner:GetPosition())
    else
        filleditem.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
        local item =
            self.inst.components.stackable ~= nil and
            self.inst.components.stackable:IsStack() and
            self.inst.components.stackable:Get() or
            self.inst
        item:Remove()
    end
    return true
end

return Fillable
