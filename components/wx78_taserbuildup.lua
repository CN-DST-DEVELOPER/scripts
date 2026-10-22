
local Wx78_TaserBuildup = Class(function(self, inst)
    self.inst = inst

    self.max = TUNING.SKILLS.WX78.TASER_MAXBUILDUP
    self.current = 0
    self.drain_rate = TUNING.SKILLS.WX78.TASER_BUILDUP_DRAIN_RATE
    self.gainratemultiplier = 1

    self.blast_damage = TUNING.SKILLS.WX78.TASER_BUILDUP_DAMAGE
    self.blast_radius = TUNING.SKILLS.WX78.TASER_BUILDUP_RADIUS

    self.is_draining = false
    self.last_buildup_time = GetTime()
    self.effect_cooldown = 1

    self._onattackedcb = function(_, data) self:OnAttacked(data) end
    self.inst:ListenForEvent("attacked", self._onattackedcb)
    self.inst:ListenForEvent("blocked", self._onattackedcb)

    self:SpawnFX()
end)

function Wx78_TaserBuildup:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("attacked", self._onattackedcb)
    self.inst:RemoveEventCallback("blocked", self._onattackedcb)
    self._onattackedcb = nil
    if self.fx ~= nil then
        self.fx:Remove()
    end
end

-- Getters and setters

function Wx78_TaserBuildup:SetMaxBuildup(max)
    self.max = max
end

function Wx78_TaserBuildup:GetMaxBuildup()
    return self.max
end

function Wx78_TaserBuildup:SetCurrentBuildup(value)
    local prev = self.current
    self.current = math.clamp(value, 0, self.max)

    if self.current >= self.max and prev < self.max then
        if self.inst.components.talker ~= nil then
            self.inst.components.talker:Say(GetString(self.inst, "ANNOUNCE_WX_TASER_ABOUTTOEXPLODE"))
        end
        self:ReleaseBuildup()
    elseif self.current >= 50 and prev < 50 then
        if self.inst.components.talker ~= nil then
            self.inst.components.talker:Say(GetString(self.inst, "ANNOUNCE_WX_TASER_BUILDUP"))
        end
    end

    if (prev <= 0 and self.current > 0) then
       self.inst:StartUpdatingComponent(self)
    elseif self.current <= 0 and prev > 0 then
       self.inst:StopUpdatingComponent(self)
    end
end

function Wx78_TaserBuildup:GetBuildupPercent()
    return self.current / self.max
end

function Wx78_TaserBuildup:SetBuildupPercent(percent)
    self:SetCurrentBuildup(percent * self.max)
end

function Wx78_TaserBuildup:SetBuildupDrainRate(rate)
    self.drain_rate = rate
end

function Wx78_TaserBuildup:GetBuildupDrainRate()
    return self.drain_rate
end

function Wx78_TaserBuildup:SetBuildupGainRate(rate)
    self.gainratemultiplier = rate
end

function Wx78_TaserBuildup:GetBuildupGainRate()
    return self.gainratemultiplier
end

function Wx78_TaserBuildup:SetBlastDamage(damage)
    self.blast_damage = damage
end

function Wx78_TaserBuildup:GetBlastDamage()
    return self.blast_damage
end

function Wx78_TaserBuildup:SetBlastRadius(radius)
    self.blast_radius = radius
end

function Wx78_TaserBuildup:GetBlastRadius()
    return self.blast_radius
end

function Wx78_TaserBuildup:SetDetonateTimer(time, cb)
    self.detonate_time = time
    if cb ~= nil then
        self.detonate_cb = cb
    end
end

------------------------------------------------------------------

function Wx78_TaserBuildup:DetachFX()
    self.inst:RemoveEventCallback("onremove", self._on_fx_removed, self.fx)
    self.fx = nil
    self._on_fx_removed = nil
end

function Wx78_TaserBuildup:SpawnFX()
    self.fx = SpawnPrefab("wx78_taser_projectile_fx")
    self.fx:SetFXOwner(self.inst)

    self._on_fx_removed = function() self:DetachFX() end
    self.inst:ListenForEvent("onremove", self._on_fx_removed, self.fx)
end

function Wx78_TaserBuildup:ReleaseBuildup(time, cb)
    time = time or 3
    if self:GetBuildupPercent() >= 0.25 then
        if self.detonate_time == nil then
            self.is_draining = false
            self.last_buildup_time = GetTime()

            self.fx:DoFlash(time, 1)
            self:SetDetonateTimer(time, cb)
        else
            self.detonate_cb = cb or nil
        end
        return true
    end
end

local function SayPostExplosionLine(inst)
    inst.components.talker:Say(GetString(inst, "ANNOUNCE_WX_TASER_POSTEXPLOSION"))
end

function Wx78_TaserBuildup:DoShockExplosion()
    local perc = self:GetBuildupPercent()
    self.fx:Explode(self:GetBlastDamage() * perc, self:GetBlastRadius() * perc)

    -- Small workaround, we should bypass insulated stuff because we're just that overloaded.
    if self.inst.sg and not self.inst.sg:HasAnyStateTag("wxshielding", "spinning") then
        self.inst.components.inventory:ForceNoInsulated(true)
    end
    self.inst:PushEventImmediate("electrocute")
    self.inst.components.inventory:ForceNoInsulated(nil)

    self:DetachFX()
    self:SpawnFX()
    self:SetCurrentBuildup(0)

    if self.detonate_cb ~= nil then
        self.detonate_cb(self.inst)
        self.detonate_cb = nil
    end

    if self.inst.components.talker ~= nil then
        self.inst:DoTaskInTime(1 + math.random() * 2, SayPostExplosionLine)
    end
end

function Wx78_TaserBuildup:OnAttacked(data)
	if not IsEquipmentOnAttackedOrBlocked(self.inst, self.inst, data) then
		self.is_draining = false
		self.last_buildup_time = GetTime()
		self.effect_cooldown = self.effect_cooldown * 0.5

		local delta = self:GetBuildupGainRate() * TUNING.SKILLS.WX78.TASER_BUILDUP_GAIN_RATE --* (1 - self:GetPercent())
		self:DoDelta(delta)
	end
end

function Wx78_TaserBuildup:DoDelta(delta)
    if delta > 0 then
        self.last_buildup_time = GetTime()
    end
    self:SetCurrentBuildup(self.current + delta)
end

------------------------------------------------------------------

function Wx78_TaserBuildup:GetEffectCooldown()
    local mult = 1 - math.min(0.85, self:GetBuildupPercent())
    return TUNING.SKILLS.WX78.TASER_EFFECT_BASE_TIME * mult + math.random() * mult * TUNING.SKILLS.WX78.TASER_EFFECT_VAR_TIME
end

function Wx78_TaserBuildup:GetEffectDuration()
    local mult = self:GetBuildupPercent()
    return TUNING.SKILLS.WX78.TASER_EFFECT_DURATION_BASE_TIME * mult + math.random() * mult * TUNING.SKILLS.WX78.TASER_EFFECT_DURATION_VAR_TIME
end

function Wx78_TaserBuildup:FlashEffect()
    local perc = self:GetBuildupPercent()
    if perc >= 0.25 then
        self.fx:DoFlash(self:GetEffectDuration(), 0.75 * perc)
    end
end

function Wx78_TaserBuildup:OnUpdate(dt)
    if self.detonate_time then
        self.detonate_time = self.detonate_time - dt
        if self.detonate_time <= 0 then
            self:DoShockExplosion()
            self.detonate_time = nil
        end
        return
    end

    self.effect_cooldown = self.effect_cooldown - dt
    if self.effect_cooldown <= 0 then
        self:FlashEffect()
        self.effect_cooldown = self:GetEffectCooldown()
    end

    local current_time = GetTime()
    if (current_time - self.last_buildup_time >= TUNING.SKILLS.WX78.TASER_BUILDUP_DRAIN_BUFFER_TIME) then
        self.is_draining = true
        self:DoDelta(self:GetBuildupDrainRate() * dt)
    else
        self.is_draining = false
    end
end

function Wx78_TaserBuildup:OnSave()
    return { current = self.current }
end

function Wx78_TaserBuildup:OnLoad(data)
	self:SetCurrentBuildup(data.current or 0)
end

function Wx78_TaserBuildup:GetDebugString()
	return "current: " .. tostring(self.current)
end

return Wx78_TaserBuildup