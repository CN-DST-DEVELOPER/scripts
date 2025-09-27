local Widget = require("widgets/widget")
local UIAnim = require("widgets/uianim")
local WagBossUtil = require("prefabs/wagboss_util")

local LunarBurnOver = Class(Widget, function(self, owner)
	self.owner = owner
	Widget._ctor(self, "LunarBurnOver")

	self.anim = self:AddChild(UIAnim())
	self:SetScaleMode(SCALEMODE_FIXEDPROPORTIONAL)

	self:SetClickable(false)
	self:SetHAnchor(ANCHOR_LEFT)
	self:SetVAnchor(ANCHOR_TOP)

	self.anim:GetAnimState():SetBank("wagboss_beam_over")
	self.anim:GetAnimState():SetBuild("wagboss_beam_over")
	self.anim:GetAnimState():PlayAnimation("anim", true)
	self.anim:GetAnimState():SetMultColour(1, 1, 1, 0)
	self.anim:GetAnimState():AnimateWhilePaused(false)

	self.alpha = 0
	self.targetalpha = 0
	self.flags = WagBossUtil.LunarBurnFlags.ALL
	self.supernovamix = false
	self.supernovasoundlevel = 0
	self.supernovaparam = nil
	self.supernovatargetparam = nil
	self.anim:GetAnimState():Hide("supernova_miss")
	self:Hide()

	self.inst:ListenForEvent("startlunarburn", function(owner, flags) self:TurnOn(flags) end, owner)
	self.inst:ListenForEvent("stoplunarburn", function(owner) self:TurnOff() end, owner)
	local health = owner.replica.health
	local flags = health and health:GetLunarBurnFlags() or 0
	if flags ~= 0 then
		self:TurnOn(flags)
	end

	self.inst:ListenForEvent("onremove", function()
		self:SetSupernovaMix(false)
		if TheFocalPoint and TheFocalPoint:IsValid() then
			TheFocalPoint.SoundEmitter:KillSound("lunarburn_hit")
			TheFocalPoint.SoundEmitter:KillSound("lunarburn_supernova")
		end
	end)
end)

function LunarBurnOver:TurnOn(flags)
	if flags ~= self.flags or self.targetalpha ~= 1 then
		self.flags = flags
		if WagBossUtil.HasLunarBurnDamage(flags) then
			self.anim:GetAnimState():Show("lvl0")

			if bit.band(flags, WagBossUtil.LunarBurnFlags.SUPERNOVA) ~= 0 then
				self.anim:GetAnimState():Show("lvl2")
				self.anim:GetAnimState():Show("supernova_hit")
				self.anim:GetAnimState():Hide("supernova_miss")
				self:SetSupernovaSoundLevel(2)
			else
				self.anim:GetAnimState():Hide("lvl2")
				self.anim:GetAnimState():Hide("supernova_hit")
				if bit.band(flags, WagBossUtil.LunarBurnFlags.NEAR_SUPERNOVA) ~= 0 then
					self.anim:GetAnimState():Show("supernova_miss")
					self:SetSupernovaSoundLevel(1)
				else
					self.anim:GetAnimState():Hide("supernova_miss")
					self:SetSupernovaSoundLevel(0)
				end
			end

			if bit.band(flags, WagBossUtil.LunarBurnFlags.GENERIC) ~= 0 then
				self.anim:GetAnimState():Show("lvl1")
				if not TheFocalPoint.SoundEmitter:PlayingSound("lunarburn_hit") then
					TheFocalPoint.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_burning_fx_LP", "lunarburn_hit")
				end
			else
				self.anim:GetAnimState():Hide("lvl1")
				TheFocalPoint.SoundEmitter:KillSound("lunarburn_hit")
			end
		else
			self.anim:GetAnimState():Hide("lvl0")
			self.anim:GetAnimState():Hide("lvl1")
			self.anim:GetAnimState():Hide("lvl2")
			self.anim:GetAnimState():Hide("supernova_hit")
			if bit.band(flags, WagBossUtil.LunarBurnFlags.NEAR_SUPERNOVA) ~= 0 then
				self.anim:GetAnimState():Show("supernova_miss")
				self:SetSupernovaSoundLevel(1)
			else
				self.anim:GetAnimState():Hide("supernova_miss")
				self:SetSupernovaSoundLevel(0)
			end
			TheFocalPoint.SoundEmitter:KillSound("lunarburn_hit")
		end
	end

	self.targetalpha = 1

	if self.alpha ~= 1 then
		self:Show()
		self:StartUpdating()
	else
		self:CheckStopUpdating()
	end
end

function LunarBurnOver:TurnOff()
	if TheFocalPoint.SoundEmitter:PlayingSound("lunarburn_hit") then
		TheFocalPoint.SoundEmitter:KillSound("lunarburn_hit")
		TheFocalPoint.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_burning_fx_pst")
	end
	if self.supernovasoundlevel > 1 then
		TheFocalPoint.SoundEmitter:PlaySound("rifts5/lunar_boss/supernova_pst")
	end
	self:SetSupernovaSoundLevel(0)
	self.targetalpha = 0
	if self.alpha ~= 0 then
		self:StartUpdating()
	else
		self:CheckStopUpdating()
		self:Hide()
	end
end

--0: off
--1: blocked
--2: hit
function LunarBurnOver:SetSupernovaSoundLevel(level)
	if level ~= self.supernovasoundlevel then
		self.supernovasoundlevel = level
		if level > 0 then
			if not TheFocalPoint.SoundEmitter:PlayingSound("lunarburn_supernova") then
				TheFocalPoint.SoundEmitter:PlaySound("rifts5/lunar_boss/supernova_burst_LP", "lunarburn_supernova")
			end
			self.supernovatargetparam = level > 1 and 0.05 or 0.35
			if self.supernovaparam and self.supernovaparam ~= self.supernovatargetparam then
				self:StartUpdating()
			else
				self.supernovaparam = self.supernovatargetparam
				self:CheckStopUpdating()
				TheFocalPoint.SoundEmitter:SetParameter("lunarburn_supernova", "blocked", self.supernovaparam)
			end
			self:SetSupernovaMix(true)
		else
			TheFocalPoint.SoundEmitter:KillSound("lunarburn_supernova")
			self.supernovaparam = nil
			self.supernovatargetparam = nil
			self:CheckStopUpdating()
			self:SetSupernovaMix(false)
		end
	end
end

function LunarBurnOver:SetSupernovaMix(enable)
	if enable then
		if not self.supernovamix then
			self.supernovamix = true
			TheMixer:PushMix("supernova")
		end
	elseif self.supernovamix then
		self.supernovamix = false
		TheMixer:PopMix("supernova")
	end
end

function LunarBurnOver:CheckStopUpdating()
	if self.alpha == self.targetalpha and self.supernovaparam == self.supernovatargetparam then
		self:StopUpdating()
	end
end

function LunarBurnOver:OnUpdate(dt)
	if dt > 0 then
		if self.supernovatargetparam ~= self.supernovaparam then
			local delta = dt * 0.6 --0.5s to fade from 0.05 <-> 0.35
			if self.supernovatargetparam > self.supernovaparam then
				self.supernovaparam = self.supernovaparam + delta
				if self.supernovaparam >= self.supernovatargetparam then
					self.supernovaparam = self.supernovatargetparam
					self:CheckStopUpdating()
				end
			else
				self.supernovaparam = self.supernovaparam - delta
				if self.supernovaparam <= self.supernovatargetparam then
					self.supernovaparam = self.supernovatargetparam
					self:CheckStopUpdating()
				end
			end
			TheFocalPoint.SoundEmitter:SetParameter("lunarburn_supernova", "blocked", self.supernovaparam)
		end

		if self.alpha ~= self.targetalpha then
			local delta = dt * 4
			if self.targetalpha > self.alpha then
				self.alpha = self.alpha + delta
				if self.alpha >= self.targetalpha then
					self.alpha = self.targetalpha
					self:CheckStopUpdating()
				end
			else
				self.alpha = self.alpha - delta
				if self.alpha <= self.targetalpha then
					self.alpha = self.targetalpha
					self:CheckStopUpdating()
				end
			end
			self.anim:GetAnimState():SetMultColour(1, 1, 1, self.alpha)
		else
			self:CheckStopUpdating()
		end
	end
end

return LunarBurnOver
