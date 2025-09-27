local Widget = require "widgets/widget"
local Image = require "widgets/image"

local BeefBloodOver =  Class(Widget, function(self, owner)
    self.owner = owner
    Widget._ctor(self, "BeefBloodOver")
    self:UpdateWhilePaused(false)

    self:SetClickable(false)

    self.bg = self:AddChild(Image("images/fx.xml", "beefblood_over.tex"))
    self.bg:SetVRegPoint(ANCHOR_BOTTOM)
    self.bg:SetHRegPoint(ANCHOR_MIDDLE)
    self.bg:SetVAnchor(ANCHOR_BOTTOM)
    self.bg:SetHAnchor(ANCHOR_MIDDLE)
    self.bg:SetScaleMode(SCALEMODE_FIXEDPROPORTIONAL)

    self:Hide()
    self.base_level = 0
    self.level = 0
    self.k = 1
    --self:UpdateState()
    self.time_since_pulse = 0
    self.pulse_period = 1

    local function _UpdateState() self:UpdateState() end

    self.inst:ListenForEvent("attacked", function(owner2, data)
        if data.redirected then
            local rider = owner2.replica.rider
            if rider ~= nil and rider:IsRiding() then
                self:Flash()
            end
        end
    end, owner)
    self.inst:ListenForEvent("mounthurt", _UpdateState, owner) --hp low

    self.inst:DoTaskInTime(0, _UpdateState)
end)

function BeefBloodOver:UpdateState()
    local rider = self.owner.replica.rider
    if rider ~= nil and rider:IsMountHurt() then
        self:TurnOn()
    else
        self:TurnOff()
    end
end

function BeefBloodOver:TurnOn()
    self:StartUpdating()
    self.base_level = .5
    self.k = 5
    self.time_since_pulse = 0
end

function BeefBloodOver:TurnOff()
    self.base_level = 0
    self.k = 5
    --self:OnUpdate(0)
end

function BeefBloodOver:OnUpdate(dt)
    -- ignore 0 interval
    -- ignore abnormally large intervals as they will destabilize the math in here
    if dt <= 0 or dt > 0.1 then
        return
    end

    local delta = self.base_level - self.level

    if math.abs(delta) < .025 then
        self.level = self.base_level
    else
        self.level = self.level + delta * dt * self.k
    end

    --this runs on WallUpdate so the pause check is needed.
    if self.base_level > 0 and not TheNet:IsServerPaused() then
        self.time_since_pulse = self.time_since_pulse + dt
        if self.time_since_pulse > self.pulse_period then
            self.time_since_pulse = 0
        end
    end

    if self.level > 0 then
        self:Show()
        self.bg:SetTint(1, 1, 1, self.level)
    else
        self:StopUpdating()
        self:Hide()
    end
end

function BeefBloodOver:Flash()
    self:StartUpdating()
    self.level = 1
    self.k = 1.33
end

return BeefBloodOver
