local DefaultOnStrike = function(inst)
    if inst.components.health ~= nil and not (inst.components.health:IsDead() or inst.components.health:IsInvincible()) then
        if not inst.components.inventory:IsInsulated() then
            LightningStrikeAttack(inst)
        else
            inst:PushEvent("lightningdamageavoided")
        end
    end
end

local PlayerLightningTarget = Class(function(self, inst)
    self.inst = inst
    self.hitchance = TUNING.PLAYER_LIGHTNING_TARGET_CHANCE
    self.onstrikefn = DefaultOnStrike
end)

function PlayerLightningTarget:SetHitChance(chance)
    self.hitchance = chance
end

function PlayerLightningTarget:GetHitChance()
    return self.hitchance
end

function PlayerLightningTarget:SetOnStrikeFn(fn)
    self.onstrikefn = fn
end

function PlayerLightningTarget:DoStrike()
    if self.onstrikefn ~= nil then
        self.onstrikefn(self.inst)
    end
	self.inst:PushEvent("playerlightningtargeted")
end

return PlayerLightningTarget