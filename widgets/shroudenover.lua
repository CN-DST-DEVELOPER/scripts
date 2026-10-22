local UIAnim = require "widgets/uianim"
local easing = require "easing"

local ShroudenOver = Class(UIAnim, function(self, owner)
    self.owner = owner
    UIAnim._ctor(self)

    self:SetClickable(false)

    self:SetHAnchor(ANCHOR_LEFT)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetScaleMode(SCALEMODE_FIXEDPROPORTIONAL)

    self:GetAnimState():SetBank("shrouden_overlay")
    self:GetAnimState():SetBuild("shrouden_overlay")
    self:GetAnimState():AnimateWhilePaused(false)
    self:Hide()

    self.inst:ListenForEvent("animover", function()
        if self:GetAnimState():IsCurrentAnimation("shrouden_tentacles_over_pst") and not self:GetAnimState():AnimDone() then
            TheFrontEnd:GetSound():PlaySound("rifts8/shrouden_portal/screen_transition_out")
        end
    end)
    self.inst:ListenForEvent("animqueueover", function()
        TheFrontEnd.overlayroot:RemoveChild(self)
        self:Hide()
    end)
    if owner ~= nil then
        self.inst:ListenForEvent("shroudensummoned", function(owner) self:TriggerShrouden() end, owner)
    end
end)

function ShroudenOver:TriggerShrouden()
    self:Show()

    TheFrontEnd.overlayroot:AddChild(self) -- dont want to be affected by screen fade
    TheFrontEnd:GetSound():PlaySound("rifts8/shrouden_portal/screen_transition_in")
    self:GetAnimState():PlayAnimation("shrouden_tentacles_over_pre")
    self:GetAnimState():PushAnimation("shrouden_tentacles_over_pst", false)
end

return ShroudenOver
