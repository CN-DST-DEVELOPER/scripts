local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local WagBossUtil = require("prefabs/wagboss_util")

local function OnEffigyDeactivated(inst)
    if inst.AnimState:IsCurrentAnimation("effigy_deactivate") then
        inst.widget:Hide()
    end
end

local HealthBadge = Class(Badge, function(self, owner, art, iconbuild)
    Badge._ctor(self, art, owner, { 174 / 255, 21 / 255, 21 / 255, 1 }, "status_health", nil, nil, true)

    self.OVERRIDE_SYMBOL_BUILD = {} -- modders can add symbols-build pairs to this table by calling SetBuildForSymbol
    self.default_symbol_build = "status_abigail"

    self.topperanim = self.underNumber:AddChild(UIAnim())
    self.topperanim:GetAnimState():SetBank("status_meter")
    self.topperanim:GetAnimState():SetBuild("status_meter")
    self.topperanim:GetAnimState():PlayAnimation("anim")
    self.topperanim:GetAnimState():SetMultColour(0, 0, 0, 1)
    self.topperanim:SetScale(1, -1, 1)
    self.topperanim:SetClickable(false)
    self.topperanim:GetAnimState():AnimateWhilePaused(false)
    self.topperanim:GetAnimState():SetPercent("anim", 1)

    if self.circleframe ~= nil then
        self.circleframe:GetAnimState():Hide("frame")
    else
        self.anim:GetAnimState():Hide("frame")
    end

    self.circleframe2 = self.underNumber:AddChild(UIAnim())
    self.circleframe2:GetAnimState():SetBank("status_meter")
    self.circleframe2:GetAnimState():SetBuild("status_meter")
    self.circleframe2:GetAnimState():PlayAnimation("frame")
    self.circleframe2:GetAnimState():AnimateWhilePaused(false)

    self.sanityarrow = self.underNumber:AddChild(UIAnim())
    self.sanityarrow:GetAnimState():SetBank("sanity_arrow")
    self.sanityarrow:GetAnimState():SetBuild("sanity_arrow")
    self.sanityarrow:GetAnimState():PlayAnimation("neutral")
    self.sanityarrow:SetClickable(false)
    self.sanityarrow:GetAnimState():AnimateWhilePaused(false)

    self.effigyanim = self.underNumber:AddChild(UIAnim())
    self.effigyanim:GetAnimState():SetBank("status_health")
    self.effigyanim:GetAnimState():SetBuild("status_health")
    self.effigyanim:GetAnimState():PlayAnimation("effigy_deactivate")
    self.effigyanim:Hide()
    self.effigyanim:SetClickable(false)
    self.effigyanim:GetAnimState():AnimateWhilePaused(false)
    self.effigyanim.inst:ListenForEvent("animover", OnEffigyDeactivated)

    self.gravestoneeffigyanim = self.underNumber:AddChild(UIAnim())
    self.gravestoneeffigyanim:GetAnimState():SetBank("status_wendy_gravestone")
    self.gravestoneeffigyanim:GetAnimState():SetBuild("status_wendy_gravestone")
    self.gravestoneeffigyanim:GetAnimState():PlayAnimation("effigy_deactivate")
    self.gravestoneeffigyanim:Hide()
    self.gravestoneeffigyanim:SetClickable(false)
    self.gravestoneeffigyanim:GetAnimState():AnimateWhilePaused(false)
    self.gravestoneeffigyanim.inst:ListenForEvent("animover", OnEffigyDeactivated)

    self.effigy = false
    self.effigybreaksound = nil

    self.bufficon = self.underNumber:AddChild(UIAnim())
    self.bufficon:GetAnimState():SetBank("status_abigail")
    self.bufficon:GetAnimState():SetBuild("status_abigail")
    self.bufficon:GetAnimState():PlayAnimation("buff_none")
    self.bufficon:GetAnimState():AnimateWhilePaused(false)
    self.bufficon:SetClickable(false)
    self.bufficon:SetScale(-1,1,1)
    self.buffsymbol = 0

    self.corrosives = {}
    self._onremovecorrosive = function(debuff)
        self.corrosives[debuff] = nil
    end
    self.inst:ListenForEvent("startcorrosivedebuff", function(owner, debuff)
        if self.corrosives[debuff] == nil then
            self.corrosives[debuff] = true
            self.inst:ListenForEvent("onremove", self._onremovecorrosive, debuff)
        end
    end, owner)

    self.hots = {}
    self._onremovehots = function(debuff)
        self.hots[debuff] = nil
    end
    self.inst:ListenForEvent("starthealthregen", function(owner, debuff)
        if self.hots[debuff] == nil then
            self.hots[debuff] = true
            self.inst:ListenForEvent("onremove", self._onremovehots, debuff)
        end
    end, owner)

    self.small_hots = {}
    self._onremovesmallhots = function(debuff)
        self.small_hots[debuff] = nil
    end
    self.inst:ListenForEvent("startsmallhealthregen", function(owner, debuff)
        if self.small_hots[debuff] == nil then
            self.small_hots[debuff] = true
            self.inst:ListenForEvent("onremove", self._onremovesmallhots, debuff)
        end
    end, owner)
    self.inst:ListenForEvent("stopsmallhealthregen", function(owner, debuff)
        if self.small_hots[debuff] ~= nil then
            self._onremovesmallhots(debuff)
            self.inst:RemoveEventCallback("onremove", self._onremovesmallhots, debuff)
        end
    end, owner)

    self.inst:ListenForEvent("isacidsizzling", function(owner, isacidsizzling)
        if isacidsizzling == nil then
            isacidsizzling = owner:IsAcidSizzling()
        end
        if isacidsizzling then
            if self.acidsizzling == nil then
                self.acidsizzling = self.underNumber:AddChild(UIAnim())
                self.acidsizzling:GetAnimState():SetBank("inventory_fx_acidsizzle")
                self.acidsizzling:GetAnimState():SetBuild("inventory_fx_acidsizzle")
                self.acidsizzling:GetAnimState():PlayAnimation("idle", true)
                self.acidsizzling:GetAnimState():SetMultColour(.65, .62, .17, 0.8)
                self.acidsizzling:GetAnimState():SetTime(math.random())
                self.acidsizzling:SetScale(.2)
                self.acidsizzling:GetAnimState():AnimateWhilePaused(false)
                self.acidsizzling:SetClickable(false)
            end
        else
            if self.acidsizzling ~= nil then
                self.acidsizzling:Kill()
                self.acidsizzling = nil
            end
        end
    end, owner)

    self:StartUpdating()
end)


function HealthBadge:SetBuildForSymbol(build, symbol)
    self.OVERRIDE_SYMBOL_BUILD[symbol] = build
end

function HealthBadge:ShowBuff(symbol)
    if symbol == 0 then
        if self.buffsymbol ~= 0 then
            self.bufficon:GetAnimState():PlayAnimation("buff_deactivate")
            self.bufficon:GetAnimState():PushAnimation("buff_none", false)
        end
    elseif symbol ~= self.buffsymbol then
        self.bufficon:GetAnimState():OverrideSymbol("buff_icon", self.OVERRIDE_SYMBOL_BUILD[symbol] or self.default_symbol_build, symbol)

        self.bufficon:GetAnimState():PlayAnimation("buff_activate")
        self.bufficon:GetAnimState():PushAnimation("buff_idle", false)
    end

    self.buffsymbol = symbol
end

function HealthBadge:UpdateBuff(symbol)
    self:ShowBuff(symbol)
end

function HealthBadge:ShowEffigy(effigy_type)
    if effigy_type ~= "grave" and not self.effigyanim.shown then
        self.effigyanim:GetAnimState():PlayAnimation("effigy_activate")
        self.effigyanim:GetAnimState():PushAnimation("effigy_idle", false)
        self.effigyanim:Show()
    elseif effigy_type == "grave" and not self.gravestoneeffigyanim.shown then
        self.gravestoneeffigyanim:GetAnimState():PlayAnimation("effigy_activate")
        self.gravestoneeffigyanim:GetAnimState():PushAnimation("effigy_idle", false)
        self.gravestoneeffigyanim:Show()
    end
    self.effigy = true
end


local function PlayEffigyBreakSound(inst, self)
    inst.task = nil
    if self:IsVisible() and inst.AnimState:IsCurrentAnimation("effigy_deactivate") then
        --Don't use FE sound since it's not a 2D sfx
        TheFocalPoint.SoundEmitter:PlaySound(self.effigybreaksound)
    end
end

function HealthBadge:HideEffigy(effigy_type)
    self.effigy = false
    if effigy_type ~= "grave" and self.effigyanim.shown then
        self.effigyanim:GetAnimState():PlayAnimation("effigy_deactivate")
        if self.effigyanim.inst.task ~= nil then
            self.effigyanim.inst.task:Cancel()
        end
        self.effigyanim.inst.task = self.effigyanim.inst:DoTaskInTime(7 * FRAMES, PlayEffigyBreakSound, self)
    end

    if effigy_type == "grave" and self.gravestoneeffigyanim.shown then
        self.gravestoneeffigyanim:GetAnimState():PlayAnimation("effigy_deactivate")
        if self.gravestoneeffigyanim.inst.task ~= nil then
            self.gravestoneeffigyanim.inst.task:Cancel()
        end
        self.gravestoneeffigyanim.inst.task = self.gravestoneeffigyanim.inst:DoTaskInTime(7 * FRAMES, PlayEffigyBreakSound, self)
    end
end

function HealthBadge:SetPercent(val, max, penaltypercent)
    Badge.SetPercent(self, val, max)

    penaltypercent = penaltypercent or 0
    self.topperanim:GetAnimState():SetPercent("anim", 1 - penaltypercent)
end

function HealthBadge:OnUpdate(dt)
    if TheNet:IsServerPaused() then return end

    local down
    if (self.owner.IsFreezing ~= nil and self.owner:IsFreezing()) or
		(self.owner.replica.health and (
			self.owner.replica.health:IsTakingFireDamageFull() or
			WagBossUtil.HasLunarBurnDamage(self.owner.replica.health:GetLunarBurnFlags())
		)) or
        (self.owner.replica.hunger ~= nil and self.owner.replica.hunger:IsStarving()) or
        self.acidsizzling ~= nil or
        next(self.corrosives) ~= nil then
        down = "_most"
    elseif self.owner.IsOverheating ~= nil and self.owner:IsOverheating() then
        down = self.owner:HasTag("heatresistant") and "_more" or "_most"
    end

    -- Show the up-arrow when we're sleeping (but not in a straw roll: that doesn't heal us)
    local up = down == nil and
        (
            (   (self.owner.player_classified ~= nil and self.owner.player_classified.issleephealing:value()) or
                next(self.hots) ~= nil or next(self.small_hots) ~= nil or
                (self.owner.replica.inventory ~= nil and self.owner.replica.inventory:EquipHasTag("regen"))
            ) or
            (self.owner:HasDebuff("wintersfeastbuff"))
        ) and
        self.owner.replica.health ~= nil and self.owner.replica.health:IsHurt()

    local anim =
        (down ~= nil and ("arrow_loop_decrease"..down)) or
        (not up and "neutral") or
        (next(self.hots) ~= nil and "arrow_loop_increase_most") or
        "arrow_loop_increase"

    if self.arrowdir ~= anim then
        self.arrowdir = anim
        self.sanityarrow:GetAnimState():PlayAnimation(anim, true)
    end
end

return HealthBadge
