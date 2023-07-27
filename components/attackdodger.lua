local function OnCooldownOver(inst)
    inst.components.attackdodger.cooldowntask = nil

    inst.components.attackdodger.oncooldown = false
end

local AttackDodger = Class(function(self, inst)
    self.inst = inst

    self.ondodgefn = nil
    self.candodgefn = nil

    self.cooldowntime = nil
    self.oncooldown = false
end)

function AttackDodger:SetOnDodgeFn(fn)
    self.ondodgefn = fn
end

function AttackDodger:SetCanDodgeFn(fn)
    self.candodgefn = fn
end

function AttackDodger:SetCooldownTime(n)
    self.cooldowntime = n
end

function AttackDodger:CanDodge(attacker)
    local candodge      = self.candodgefn   and self.candodgefn(self.inst, attacker)
    local notincooldown = self.cooldowntime and self.oncooldown == false

    return (candodge ~= nil and notincooldown ~= nil and (candodge and notincooldown)) or (candodge or notincooldown)
end

function AttackDodger:Dodge()
    if self.ondodgefn ~= nil then
        self.ondodgefn(self.inst)
    end

    if self.cooldowntime ~= nil then
        self.oncooldown = true

        self.cooldowntask = self.inst:DoTaskInTime(self.cooldowntime, OnCooldownOver)
    end
end

function AttackDodger:OnRemoveFromEntity()
    if self.cooldowntask ~= nil then
        self.cooldowntask:Cancel()
        self.cooldowntask = nil
    end
end


return AttackDodger
