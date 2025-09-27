local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")

local BalatroWidget = require("widgets/redux/balatrowidget")
local BALATRO_UTIL = require("prefabs/balatro_util")

local TEMPLATES = require "widgets/redux/templates"

local function UpdateBalatroMusic(_, player)
	player:PushEvent("playbalatromusic")
end

local BalatroScreen = Class(Screen, function(self, owner, target, jokers, cards)
    self.owner = owner
    Screen._ctor(self, "BalatroScreen")

    self.blackoverlay = self:AddChild(Image("images/global.xml", "square.tex"))
    self.blackoverlay:SetVRegPoint(ANCHOR_MIDDLE)
    self.blackoverlay:SetHRegPoint(ANCHOR_MIDDLE)
    self.blackoverlay:SetVAnchor(ANCHOR_MIDDLE)
    self.blackoverlay:SetHAnchor(ANCHOR_MIDDLE)
    self.blackoverlay:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.blackoverlay:SetTint(0, 0, 0, .5)
    self.blackoverlay:SetClickable(false)

    self.root = self:AddChild(TEMPLATES.ScreenRoot())

    self.game = self.root:AddChild(BalatroWidget(owner, self, target, jokers, cards))
    self.default_focus = self.game

	if owner then
		self.inst:DoPeriodicTask(1, UpdateBalatroMusic, nil, owner)
	end

	if target then
		self.target = target
		target.mutelocalcardsounds = true
	end

	--SetAutopaused(true)
	TheMixer:PushMix("minigamescreen")
end)

function BalatroScreen:OnDestroy()
	if self.target then
		self.target.mutelocalcardsounds = nil
	end

	TheMixer:PopMix("minigamescreen")
	--SetAutopaused(false)

	local score
	if self.game then
		score = self.game:GetFinalScore()
		self.game:KillSounds()
	end

    BALATRO_UTIL.ClientDebugPrint("Final score: ", nil, nil, score)

    POPUPS.BALATRO:Close(self.owner)

    BalatroScreen._base.OnDestroy(self)
end

function BalatroScreen:OnBecomeInactive()
    BalatroScreen._base.OnBecomeInactive(self)
end

function BalatroScreen:OnBecomeActive()
    BalatroScreen._base.OnBecomeActive(self)
end

function BalatroScreen:TryToCloseWithAnimations()
    if self.game then
        self.game:CloseWithAnimations()
    else
        TheFrontEnd:PopScreen()
    end
end

function BalatroScreen:OnControl(control, down)
    if BalatroScreen._base.OnControl(self, control, down) then
        return true
    end

    return false
end

function BalatroScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

    return table.concat(t, "  ")
end

return BalatroScreen
