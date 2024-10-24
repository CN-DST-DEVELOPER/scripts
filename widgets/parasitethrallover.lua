local UIAnim = require "widgets/uianim"

--see mindcontroller.lua for constants
local MAX_LEVEL = 135
local IN_TIME = MAX_LEVEL * FRAMES
local OFFSET_LEVEL = 1 / MAX_LEVEL

local ParasiteThrallOver = Class(UIAnim, function(self, owner)
    self.owner = owner
    UIAnim._ctor(self)
    self:UpdateWhilePaused(false)

    self:SetClickable(false)

    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetScaleMode(SCALEMODE_FIXEDSCREEN_NONDYNAMIC)

    self:GetAnimState():SetBank("thrall_parasite_overlay")
    self:GetAnimState():SetBuild("thrall_parasite_overlay")
    self:GetAnimState():PlayAnimation("empty")
    self:GetAnimState():AnimateWhilePaused(false)
    self:Hide()

    if owner ~= nil then
        self.inst:ListenForEvent("parasitethralllevel", function(owner, level) self:UpdateAnim(level) end, owner)
    end

    self.inst:ListenForEvent("animover", function(owner, level) 
            if self:GetAnimState():IsCurrentAnimation("out") then
                self:Hide()
                self:GetAnimState():PlayAnimation("empty")
            end
        end)
end)

function ParasiteThrallOver:UpdateAnim(status)
    print("status", status)
    if status == true then
        if not self:GetAnimState():IsCurrentAnimation("in") and not self:GetAnimState():IsCurrentAnimation("loop") then

            self:Show()
            self:GetAnimState():PlayAnimation("in")
            self:GetAnimState():PushAnimation("loop", true)
        end
    else
        if self:GetAnimState():IsCurrentAnimation("in") or self:GetAnimState():IsCurrentAnimation("loop") then
            self:GetAnimState():PlayAnimation("out")            
        end
    end
end

return ParasiteThrallOver
