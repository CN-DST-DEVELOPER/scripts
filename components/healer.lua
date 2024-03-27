local Healer = Class(function(self, inst)
    self.inst = inst
    self.health = TUNING.HEALING_SMALL
end)

function Healer:SetHealthAmount(health)
    self.health = health
end

function Healer:SetOnHealFn(fn)
    self.onhealfn = fn
end

function Healer:Heal(target)
    local health = target.components.health
    if health ~= nil then
        if health.canheal then -- NOTES(JBK): Tag healerbuffs can make this heal function be invoked but we do not want to apply health to things that can not be healed.
            health:DoDelta(self.health, false, self.inst.prefab)
        end
		if self.onhealfn ~= nil then
			self.onhealfn(self.inst, target)
		end
        if self.inst.components.stackable ~= nil and self.inst.components.stackable:IsStack() then
            self.inst.components.stackable:Get():Remove()
        else
            self.inst:Remove()
        end
        return true
    end
end

return Healer
