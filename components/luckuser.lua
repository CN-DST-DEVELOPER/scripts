local SourceModifierList = require("util/sourcemodifierlist")

local LuckUser = Class(function(self, inst)
    self.inst = inst

    --self.luck = 0

    self.luckmodifiers = SourceModifierList(inst, 0, SourceModifierList.additive)
end)

function LuckUser:GetLuck()
    return self.luckmodifiers:Get()
end

local MODIFIER_SOURCE = "misfortune"
function LuckUser:_UpdateLuck_Internal()
    local luck = self:GetLuck()
    --
    if luck < 0 then
        local unlucky_mult = 1 + math.abs(luck)

        local houndedtarget = self.inst.components.houndedtarget or self.inst:AddComponent("houndedtarget")
        houndedtarget.target_weight_mult:SetModifier(self.inst, unlucky_mult, MODIFIER_SOURCE)
        houndedtarget.hound_thief = luck <= -1 and true or nil
    else
        if self.inst.components.houndedtarget then
            self.inst.components.houndedtarget.target_weight_mult:RemoveModifier(self.inst, MODIFIER_SOURCE)
        end
    end
end

function LuckUser:SetLuckSource(luck, source)
    if luck == 0 then
        self:RemoveLuckSource(source)
    else
        self.luckmodifiers:SetModifier(source, luck, source)
        self:_UpdateLuck_Internal()
    end
end

function LuckUser:RemoveLuckSource(source)
    self.luckmodifiers:RemoveModifier(source, source)
    self:_UpdateLuck_Internal()
end

function LuckUser:GetDebugString()
    return string.format("luck: %2.2f", self:GetLuck())
end

return LuckUser