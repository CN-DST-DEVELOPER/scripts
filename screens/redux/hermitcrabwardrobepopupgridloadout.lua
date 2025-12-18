local Widget = require "widgets/widget"
local Screen = require "widgets/screen"
local Button = require "widgets/button"
local Menu = require "widgets/menu"
local TEMPLATES = require "widgets/redux/templates"
local LoadoutSelect_hermitcrab = require "widgets/redux/loadoutselect_hermitcrab"

local SCREEN_OFFSET = -.38 * RESOLUTION_X

local function _IsUsingController()
	return TheInput:ControllerAttached() and not TheFrontEnd.tracking_mouse
end

local GridHermitCrabWardrobePopupScreen = Class(Screen, function(self, target, owner_player, profile, recent_item_types, recent_item_ids, filter)
	Screen._ctor(self, "GridHermitCrabWardrobePopupScreen")
    self.target = target
    self.owner_player = owner_player
	self.filter = filter
	self.profile = profile

	self.previous_active_screen = TheFrontEnd:GetActiveScreen()

	--Copied from wardrobepopup.lua:

    --V2C: @liz
    -- recent_item_types and recent_item_ids are both tables of
    -- items that were just opened in the gift item popup.
    --
    -- Both params are nil if we did not come from GiftItemPopup.
    --
    -- They should be both in the same order, so recent_item_types[1]
    -- corresponds to recent_item_ids[1].
    -- (This is the exact same data that is passed into GiftItemPopup.)
    --
    -- Currently, it is safe to assume there will only be 1 item.
    --
    -- recent_item_ids is probably useless if we're only showing one
    -- of each item type in the spinners, and you should just match
    -- by recent_item_types[1].

	self.proot = self:AddChild(Widget("ROOT"))
    self.proot:SetVAnchor(ANCHOR_MIDDLE)
    self.proot:SetHAnchor(ANCHOR_MIDDLE)
    self.proot:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.root = self.proot:AddChild(Widget("root"))
    self.root:SetPosition(-RESOLUTION_X/2, -RESOLUTION_Y/2, 0)

	local bg = self.proot:AddChild(Image("images/bg_redux_wardrobe_bg.xml", "wardrobe_bg.tex"))
	bg:SetScale(.8)
	bg:SetPosition(-200, 0)
	bg:SetTint(1, 1, 1, .76)

	local base_skin = "hermitcrab_none"
    if self.target and self.target.hermitcrab_skin then
        local new_base_skin = self.target.hermitcrab_skin:value()
        if new_base_skin ~= "" then
            base_skin = new_base_skin
        end
    end
	self.initial_skins = { base = base_skin }

	self.loadout = self.proot:AddChild(LoadoutSelect_hermitcrab(profile, self.initial_skins, self.filter, self.owner_player))
	self.loadout:SetDefaultMenuOption()

    local offline = not TheInventory:HasSupportForOfflineSkins() and not TheNet:IsOnlineMode()

	local buttons = {}
	if offline then
		table.insert(buttons, {text = STRINGS.UI.POPUPDIALOG.OK, cb = function() self:Close() end})
	else
		table.insert(buttons, {text = STRINGS.UI.WARDROBE_POPUP.CANCEL, cb=function() self:Cancel() end })
		table.insert(buttons, {text = STRINGS.UI.WARDROBE_POPUP.SET, cb=function() self:Close() end })
	end

	local spacing = 70
	self.menu = self.proot:AddChild(Menu(buttons, spacing, false, "carny_long", nil, 30))

	self.loadout:SetPosition(-306, 0)
	self.menu:SetPosition(493, -260, 0)
		
	-- hide the menu if the player is using a controller; we'll control this with button presses that are listed in the helpbar
	if _IsUsingController() then
		self.menu:Hide()
		self.menu:Disable()
	end  

	self.default_focus = self.loadout

    TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)

    self:DoFocusHookups()

    SetAutopaused(true)
end)

function GridHermitCrabWardrobePopupScreen:OffsetServerPausedWidget(serverpausewidget)
	serverpausewidget:SetOffset(-650,0)
end

function GridHermitCrabWardrobePopupScreen:OnDestroy()
    SetAutopaused(false)

    TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)
    self._base.OnDestroy(self)

	self.profile:SetSkinsForCharacter(self.loadout.currentcharacter, self.previous_default_skins)

	-- All popups that are spawned from the wardrobe should be tagged with owned_by_wardrobe = true
	-- to ensure they are included when all screens are popped, with the exception of the server
	-- contact messages that need to stay up until the server communication is complete.

	local active_screen = TheFrontEnd:GetActiveScreen()
	while active_screen.owned_by_wardrobe do
		TheFrontEnd:PopScreen(active_screen)

		active_screen = TheFrontEnd:GetActiveScreen()
	end
end

function GridHermitCrabWardrobePopupScreen:OnBecomeActive()
	self._base.OnBecomeActive(self)

	if self.loadout and self.loadout.subscreener then
		for key,sub_screen in pairs(self.loadout.subscreener.sub_screens) do
			sub_screen:RefreshInventory()
		end
	end

    if _IsUsingController() then
        self.default_focus:SetFocus()
    end
end

function GridHermitCrabWardrobePopupScreen:GetTimestamp()
	local templist = TheInventory:GetFullInventory()
	local timestamp = 0

	for k,v in ipairs(templist) do
		if v.modified_time > timestamp then
			timestamp = v.modified_time
		end
	end

	return timestamp
end

function GridHermitCrabWardrobePopupScreen:DoFocusHookups()
	self.menu:SetFocusChangeDir(MOVE_LEFT, self.loadout)
    self.loadout:SetFocusChangeDir(MOVE_RIGHT, self.menu)
end

function GridHermitCrabWardrobePopupScreen:OnControl(control, down)
    if GridHermitCrabWardrobePopupScreen._base.OnControl(self,control, down) then return true end

    if control == CONTROL_CANCEL and not down then
        self:Cancel()
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        return true
	elseif control == CONTROL_MENU_START and not down then  
		self:Close()
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
		return true
    end
end

function GridHermitCrabWardrobePopupScreen:Cancel()
	self:Reset()
	self:Close(true)
end

function GridHermitCrabWardrobePopupScreen:Reset()
	self.loadout.selected_skins = self.initial_skins
end

function GridHermitCrabWardrobePopupScreen:Close(cancel)
	local skins = self.loadout.selected_skins

    local data = {}
    if TheInventory:HasSupportForOfflineSkins() or TheNet:IsOnlineMode() then
		data = skins
    end

    if cancel then
    	data.cancel = true
    end

	if not data.base or data.base == self.loadout.currentcharacter or data.base == "" or not TheInventory:CheckOwnership(data["base"]) then data.base = (self.loadout.currentcharacter.."_none") end

	POPUPS.HERMITCRABWARDROBE:Close(self.owner_player, data.base, data.cancel)

	self.timestamp = self:GetTimestamp()
	self.profile:SetCollectionTimestamp(self.timestamp)

    TheFrontEnd:PopScreen(self)
end

function GridHermitCrabWardrobePopupScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.CANCEL)
    table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_START) .. " " .. STRINGS.UI.WARDROBE_POPUP.SET)
	return table.concat(t, "  ")
end

function GridHermitCrabWardrobePopupScreen:OnUpdate(dt)
    self.loadout:OnUpdate(dt)
end

return GridHermitCrabWardrobePopupScreen