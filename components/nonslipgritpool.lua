local NonSlipGritPool = Class(function(self, inst)
    self.inst = inst

    --self.isgritatfn = nil

    -- NOTES(JBK): Recommended to explicitly add tag to prefab pristine state
    self.inst:AddTag("nonslipgritpool")
end)

function NonSlipGritPool:OnRemoveFromEntity()
    self.inst:RemoveTag("nonslipgritpool")
end

function NonSlipGritPool:SetIsGritAtPoint(fn)
    self.isgritatfn = fn
end

function NonSlipGritPool:IsGritAtPosition(x, y, z)
    if self.isgritatfn ~= nil then
        return self.isgritatfn(self.inst, x, y, z)
    end

    if self.inst.Physics ~= nil then
        local r = self.inst.Physics:GetRadius()
        local ex, ey, ez = self.inst.Transform:GetWorldPosition()
        local dx, dz = ex - x, ez - z
        return dx * dx + dz * dz < r * r
    end

    return false
end

return NonSlipGritPool
