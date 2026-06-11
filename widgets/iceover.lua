local Widget = require "widgets/widget"
local Image = require "widgets/image"


local IceOver = Class(Widget, function(self, owner)
    self.owner = owner
    Widget._ctor(self, "IceOver")
	self:SetClickable(false)

	self.img = self:AddChild(Image("images/fx.xml", "ice_over.tex"))
	self.img:SetEffect( "shaders/uifade.ksh" )
    self.img:SetHAnchor(ANCHOR_MIDDLE)
    self.img:SetVAnchor(ANCHOR_MIDDLE)
    self.img:SetScaleMode(SCALEMODE_FILLSCREEN)

    self:Hide()
    self.laststep = 0

    self.alpha_min = 1
    self.alpha_min_target = 1

	local _on_ice_change = function() self:OnIceChange() end
    self.inst:ListenForEvent("temperaturedelta", _on_ice_change, self.owner)
    self.inst:ListenForEvent("updateiceover", _on_ice_change, self.owner) -- from ice overlay block setter
end)

function IceOver:OnIceChange()

	local temp = self.owner.components.temperature ~= nil
        and self.owner.components.temperature:GetCurrent()
        or (self.owner.player_classified ~= nil and
            self.owner.player_classified.currenttemperature or TUNING.STARTING_TEMP)

	local num_steps = 4

	local all_up_thresh = {5, 0, -5, -10}

	local freeze_sounds =
	{
		"dontstarve/winter/freeze_1st",
		"dontstarve/winter/freeze_2nd",
		"dontstarve/winter/freeze_3rd",
		"dontstarve/winter/freeze_4th",
	}

	local is_blocked = self.owner.IsFreezingEffectBlocked and self.owner:IsFreezingEffectBlocked()
	local isup = false

	if not is_blocked then
    	while all_up_thresh[self.laststep + 1] ~= nil and
    	    temp < all_up_thresh[self.laststep + 1] and
    	    self.laststep < num_steps and
    	    (temp < 5 or TheWorld.state.iswinter or GetLocalTemperature(self.owner) < 5) do

    	    self.laststep = self.laststep + 1
    	    isup = true
    	end
	end

    if isup then
        TheFrontEnd:GetSound():PlaySound(freeze_sounds[self.laststep])
    else
        while all_up_thresh[self.laststep] ~= nil and
            (temp > all_up_thresh[self.laststep] or is_blocked) and
            self.laststep > 0 do

            self.laststep = self.laststep - 1
        end
    end

	if self.laststep == 0 then
		self.alpha_min_target = 1
	else
		local alpha_mins = {
			.7, .5, .3, 0
		}
		self.alpha_min_target = alpha_mins[self.laststep]

		self:StartUpdating()
	end
end

function IceOver:OnUpdate(dt)
	local lspeed = dt*2
	self.alpha_min = (1 - lspeed) * self.alpha_min + lspeed *self.alpha_min_target
	self.img:SetAlphaRange(self.alpha_min,1)

	if self.alpha_min >= .99 then
		self:Hide()
		self:StopUpdating()
	else
		self:Show()
	end
end

return IceOver