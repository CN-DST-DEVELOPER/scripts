local Corruption = Class(function(self, inst)
    self.inst = inst

    self.current = 0
    self.timetodecay = 0
    self.oncurrentchanged = nil
    self.oncorruptedfn = nil
    self.onuncorruptedfn = nil
    self.corruptiontarget = nil
end)

----------------------------------------------------------------------------------------------------

function Corruption:OnRemoveFromEntity()
	self:OnUntargetCorruptable()
    self:MakeUncorrupted()
end
Corruption.OnRemoveEntity = Corruption.OnRemoveFromEntity

----------------------------------------------------------------------------------------------------

function Corruption:IsCorrupted()
    return self.current >= TUNING.KING_CANE_MAX_CORRUPTION
end

function Corruption:GetCurrent()
    return self.current
end

function Corruption:SetOnCurrentFn(fn)
    self.oncurrentchanged = fn
end

function Corruption:SetOnCorruptedFn(fn)
    self.oncorruptedfn = fn
end

function Corruption:SetOnUncorruptedFn(fn)
    self.onuncorruptedfn = fn
end

----------------------------------------------------------------------------------------------------

function Corruption:MakeCorrupted()
    self.inst:AddTag("corrupted")
    self.current = TUNING.KING_CANE_MAX_CORRUPTION
    self.timetodecay = 0
    self.inst:StopUpdatingComponent(self)
    if self.oncorruptedfn then
        self.oncorruptedfn(self.inst)
    end
end

function Corruption:MakeUncorrupted()
    if self:IsCorrupted() then
        self.inst:RemoveTag("corrupted")
        self.current = 0
        self.timetodecay = 0
        if self.onuncorruptedfn then
            self.onuncorruptedfn(self.inst)
        end
    end
end

function Corruption:SetCurrent(current)
    if self:IsCorrupted() then
        return
    end
    local old = self.current
    self.current = math.clamp(current, 0, TUNING.KING_CANE_MAX_CORRUPTION)
    if self.oncurrentchanged and old ~= self.current then
        self.oncurrentchanged(self.inst, self.current)
    end
    if self.current >= TUNING.KING_CANE_MAX_CORRUPTION then
        self:MakeCorrupted()
    elseif self.current > 0 then
        self.inst:StartUpdatingComponent(self)
    else
        self.timetodecay = 0
        self.inst:StopUpdatingComponent(self)
    end
end

function Corruption:DoDelta(delta)
    if self:IsCorrupted() then
        return
    end
    if delta > 0 then
        self.timetodecay = TUNING.KING_CANE_CORRUPTION_DECAY_PERIOD
    end

    self:SetCurrent(self.current + delta)
end

----------------------------------------------------------------------------------------------------

function Corruption:OnTargetCorruptable(target, doer)
    self.corruptiontarget = target
    if IsStalkerCorruptable(target, doer) then
        if target.RedirectStalkerCorruption then -- for batbosscave to bat_boss
            target = target:RedirectStalkerCorruption(doer) or target
        end
        target:PushEventImmediate("stalker_corruption_stun")
    elseif target:HasTag("chess_moonevent") then
        target:PushEvent("forcechessstruggle", true)
    end
end

function Corruption:OnUntargetCorruptable(target, doer)
    if self.corruptiontarget and (target == nil or self.corruptiontarget == target) then
		target = self.corruptiontarget
        self.corruptiontarget = nil
        if target:IsValid() then
            target:PushEventImmediate("interruptcorruption")
            target:PushEvent("forcechessstruggle", false)
        end
    end
end

-- prioritize:
    -- blighted state
    -- nightmare state
local DURATION = 99999 -- really long time because we can't push math.huge :)
function Corruption:CorruptEnt(target, doer)
    if IsStalkerCorruptable(target, doer) then
        if target.RedirectStalkerCorruption then -- for batbosscave to bat_boss
            target = target:RedirectStalkerCorruption(doer) or target
        end

        target:PushEventImmediate("startcorruption")

        if self.inst.components.rechargeable then
            self.inst.components.rechargeable:Discharge(TUNING.KING_CANE_CORRUPT_BLIGHTED_COOLDOWN)
        end
        return true
    elseif target.has_nightmare_state then
        target:PushEvent("ms_forcenightmarestate", { duration = DURATION })
        if self.inst.components.rechargeable then
            self.inst.components.rechargeable:Discharge(TUNING.KING_CANE_CORRUPT_NIGHTMARE_COOLDOWN)
        end
        return true
    elseif TheWorld.components.shadowthrallmanager and TheWorld.components.shadowthrallmanager:IsRegisteredFissure(target) then
        local success = TheWorld.components.shadowthrallmanager:ControlFissure(target)

        if success then
            TheWorld.components.shadowthrallmanager:OnDreadstoneMineCooldown()
            if self.inst.components.rechargeable then
                self.inst.components.rechargeable:Discharge(TUNING.KING_CANE_CORRUPT_FISSURE_COOLDOWN)
            end
        end

        return success
    elseif target:HasTag("chess_moonevent") then
        target:PushEvent("shadowchessroar")
        if self.inst.components.rechargeable then
            self.inst.components.rechargeable:Discharge(TUNING.KING_CANE_CORRUPT_CHESSPIECE_COOLDOWN)
        end
        return true
    elseif target:HasTag("chess") then
        target:PushEvent("ms_becomeshadowchess")
        if self.inst.components.rechargeable then
            self.inst.components.rechargeable:Discharge(TUNING.KING_CANE_CORRUPT_CHESSPIECE_COOLDOWN)
        end
        return true
    end
end

----------------------------------------------------------------------------------------------------

function Corruption:OnUpdate(dt)
    if dt > 0 then
        self.timetodecay = self.timetodecay - dt
        if self.timetodecay <= 0 then
            self.timetodecay = TUNING.KING_CANE_CORRUPTION_DECAY_PERIOD
            self:DoDelta(TUNING.KING_CANE_CORRUPTION_DECAY_AMOUNT)
        end
    end
    if self.current <= 0 then
        self.inst:StopUpdatingComponent(self)
    end
end
Corruption.LongUpdate = Corruption.OnUpdate

----------------------------------------------------------------------------------------------------

function Corruption:OnSave()
    return self.current > 0 and { current = self.current, timetodecay = self.timetodecay } or nil
end

function Corruption:OnLoad(data)
    if self.timetodecay and self.timetodecay > 0 then
        self.timetodecay = data.timetodecay
    end
    self:SetCurrent(data.current)
end

----------------------------------------------------------------------------------------------------

function Corruption:GetDebugString()
    return string.format(
        "%2.1f/%2.1f | decay time: %2.1f",
        self.current, TUNING.KING_CANE_MAX_CORRUPTION,
        self.timetodecay)
end

----------------------------------------------------------------------------------------------------

return Corruption
