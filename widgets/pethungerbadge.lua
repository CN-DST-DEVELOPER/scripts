local Badge = require("widgets/badge")
local UIAnim = require("widgets/uianim")

local PetHungerBadge = Class(Badge, function(self, owner, colour, iconbuild)
	Badge._ctor(self, nil, owner, colour, iconbuild, nil, nil, true)

	self.circleframe:GetAnimState():SetBank(iconbuild)
	self.circleframe:GetAnimState():SetBuild(iconbuild)

	self.backing:GetAnimState():SetBank(iconbuild)
	self.backing:GetAnimState():SetBuild(iconbuild)

	--self.arrowdir = nil
	--self.arrowanimfn = nil
	--self.hungerarrow = nil
end)

function PetHungerBadge:OnShow(was_hidden)
	self._base.OnShow(self, was_hidden)
	if self.hungerarrow then
		self:StartUpdating()
	end
end

function PetHungerBadge:OnHide(was_visible)
	self._base.OnHide(self, was_visible)
	self:StopUpdating()
end

function PetHungerBadge:OnFlagsChanged(flags, instant)
	--override me
end

function PetHungerBadge:OnBuildChanged(build, instant)
	--override me
end

function PetHungerBadge:SetArrowAnimFn(fn)
	self.arrowanimfn = fn

	if fn then
		if self.hungerarrow == nil then
			self.hungerarrow = self.underNumber:AddChild(UIAnim())
			self.hungerarrow:GetAnimState():SetBank("sanity_arrow")
			self.hungerarrow:GetAnimState():SetBuild("sanity_arrow")
			self.hungerarrow:GetAnimState():PlayAnimation("neutral")
			self.hungerarrow:SetClickable(false)
			self.hungerarrow:GetAnimState():AnimateWhilePaused(false)

			if self.shown then
				self:StartUpdating()
			end
		end
	else
		self:StopUpdating()
		self.arrowdir = nil
		if self.hungerarrow then
			self.hungerarrow:Kill()
			self.hungerarrow = nil
		end
	end
end

function PetHungerBadge:OnUpdate(dt)
	if TheNet:IsServerPaused() then
		return
	end

	local anim = self:arrowanimfn()
	if self.arrowdir ~= anim then
		self.arrowdir = anim
		self.hungerarrow:GetAnimState():PlayAnimation(anim or "neutral", anim ~= nil)
	end
end

return PetHungerBadge
