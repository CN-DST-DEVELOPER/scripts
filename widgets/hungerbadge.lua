local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"

local HungerBadge = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, { 255 / 255, 204 / 255, 51 / 255, 1 }, "status_hunger", nil, nil, true)

    self.hungerarrow = self.underNumber:AddChild(UIAnim())
    self.hungerarrow:GetAnimState():SetBank("sanity_arrow")
    self.hungerarrow:GetAnimState():SetBuild("sanity_arrow")
    self.hungerarrow:GetAnimState():PlayAnimation("neutral")
    self.hungerarrow:SetClickable(false)
    self.hungerarrow:GetAnimState():AnimateWhilePaused(false)

    self:StartUpdating()
end)

function HungerBadge:OnUpdate(dt)
    if TheNet:IsServerPaused() then return end

    local anim = "neutral"
	local hunger = self.owner and self.owner.replica.hunger
	if hunger then
		local gain, drain
		if self.owner:HasTag("wintersfeastbuff") then
			gain = true
			--no drain
		else
			if self.owner:HasTag("hungerregenbuff") then
				gain = true
			end

			if self.owner:HasAnyTag("sleeping", "swimming_floater", "wonkey_run", "gallop_run") or
				(self.owner.sg and self.owner.sg:HasAnyStateTag("floating_predict_move", "monkey_predict_run", "gallop_predict_run"))
			then
				drain = true
			end
		end

		if gain and drain then
			--has both, we don't know the rates, so we'll have to track it
			local tick = GetTick()
			if self.tracking == nil then
				self.tracking =
				{
					i1 = 1,
					i2 = 1,
					t = tick,
					history = { hunger:GetPercent() },
				}
			elseif self.tracking.t ~= tick then
				local maxn = 150
				self.tracking.i2 = (self.tracking.i2 % maxn) + 1
				if self.tracking.i2 == self.tracking.i1 then
					self.tracking.i1 = (self.tracking.i1 % maxn) + 1
				end
				self.tracking.history[self.tracking.i2] = hunger:GetPercent()
				self.tracking.t = tick
			end
			local pct1 = self.tracking.history[self.tracking.i1]
			local pct2 = self.tracking.history[self.tracking.i2]
			if pct1 > pct2 then
				gain = false
			elseif pct1 < pct2 then
				drain = false
			else
				gain, drain = false, false
			end
		else
			self.tracking = nil
		end

		if gain then
			if hunger:GetPercent() < 1 then
				anim = "arrow_loop_increase"
			end
		elseif drain and hunger:GetPercent() > 0 then
			anim = "arrow_loop_decrease"
		end
	end

    if self.arrowdir ~= anim then
        self.arrowdir = anim
        self.hungerarrow:GetAnimState():PlayAnimation(anim, true)
    end
end

return HungerBadge
