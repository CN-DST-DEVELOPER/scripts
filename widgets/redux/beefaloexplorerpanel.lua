local ItemExplorer = require "widgets/redux/itemexplorer"
local FilterBar = require "widgets/redux/filterbar"
local Puppet = require "widgets/skinspuppet_beefalo"
local Widget = require "widgets/widget"
local BeefaloSkinPresetsPopup = require "screens/redux/beefaloskinpresetspopup"

local TEMPLATES = require "widgets/redux/templates"

require("dlcsupport")
require("emote_items")
require("util")
require("skinsutils")

local WIDGET_WIDTH = 90
local WIDGET_HEIGHT = 90

local BeefaloExplorerPanel = Class(Widget, function(self, owner, user_profile)
    Widget._ctor(self, "BeefaloExplorerPanel")
    self.owner = owner
    self.user_profile = user_profile
    self.currentcharacter = "beefalo"

    self.puppet_root = self:AddChild(Widget("puppet_root"))
    self.puppet_root:SetPosition(-160, -210)

    self.puppet = self.puppet_root:AddChild(Puppet())
    self.puppet:SetPosition(0, 100)
    self.puppet:SetScale(4)
    self.puppet:SetClickable(false)
    
    self:_LoadSavedSkins()

    local panel_selector_data = {
        {
            text = STRINGS.SKIN_TAG_CATEGORIES.BEEFCLOTHINGTYPE.BEEFALO_HEAD,
            colour = nil,
            image = nil,
            data = { index = 1 },
        },
        {
            text = STRINGS.SKIN_TAG_CATEGORIES.BEEFCLOTHINGTYPE.BEEFALO_HORN,
            colour = nil,
            image = nil,
            data = { index = 2 },
        },
        {
            text = STRINGS.SKIN_TAG_CATEGORIES.BEEFCLOTHINGTYPE.BEEFALO_BODY,
            colour = nil,
            image = nil,
            data = { index = 3 },
        },
        {
            text = STRINGS.SKIN_TAG_CATEGORIES.BEEFCLOTHINGTYPE.BEEFALO_FEET,
            colour = nil,
            image = nil,
            data = { index = 4 },
        },
        {
            text = STRINGS.SKIN_TAG_CATEGORIES.BEEFCLOTHINGTYPE.BEEFALO_TAIL,
            colour = nil,
            image = nil,
            data = { index = 5 },
        },
    }
    self.panel_selector = self.puppet_root:AddChild(TEMPLATES.StandardSpinner(panel_selector_data, 250))
    self.panel_selector:SetOnChangedFn(function(selected, old)
        self:SetPanelIndex(selected.index)
    end)

    self:SetPanelIndex(1)

    if not TheInput:ControllerAttached() then
        self.presetsbutton = self.puppet_root:AddChild(TEMPLATES.IconButton("images/button_icons.xml", "save.tex", STRINGS.UI.SKIN_PRESETS.TITLE, false, false, function()
                self:_LoadSkinPresetsScreen()
            end
        ))
        self.presetsbutton:SetPosition(-240, 440)
        self.presetsbutton:SetScale(0.77)
        --self.menu:SetFocusChangeDir(MOVE_UP, self.presetsbutton)
        --self.presetsbutton:SetFocusChangeDir(MOVE_DOWN, self.menu)
        --self.presetsbutton:SetFocusChangeDir(MOVE_RIGHT, self.subscreener:GetActiveSubscreenFn())
    end

    self.focus_forward = self.panel_selector

    self:StartUpdating()
end)

local function AllowSkins()
    return TheInventory:HasSupportForOfflineSkins() or TheNet:IsOnlineMode()
end

function BeefaloExplorerPanel:_LoadSavedSkins()
    if AllowSkins() then
        self.selected_skins = self.user_profile:GetSkinsForCharacter(self.currentcharacter)
    else
        self.selected_skins = {beef_head = "beef_head_default1"}
    end

    self:_ApplySkins(self.selected_skins, false)
end
function BeefaloExplorerPanel:SaveLoadout()
    if AllowSkins() then
        self.user_profile:SetSkinsForCharacter(self.currentcharacter, self.selected_skins)
    end
end

function BeefaloExplorerPanel:_ApplySkins(skins, skip_change_emote)
	self.puppet:SetSkins(self.currentcharacter, "beefalo_build", skins, skip_change_emote, nil)
end

function BeefaloExplorerPanel:SetPanelIndex(index)
    if self.picker then
        if self.picker.index == index then
            return
        end
        self.picker:Kill()
    end

    self.picker = self:AddChild(self:_BuildItemExplorer(index))
    self.picker:SetPosition(310, 140)

    self.filter_bar = self:AddChild(FilterBar(self.picker, "collectionscreen"))
    self.picker.header:AddChild(self.filter_bar:AddFilter(STRINGS.UI.WARDROBESCREEN.OWNED_FILTER_FMT, "owned_filter_on.tex", "owned_filter_off.tex", "lockedFilter", GetLockedSkinFilter()))
    self.picker.header:AddChild(self.filter_bar:AddFilter(STRINGS.UI.WARDROBESCREEN.WEAVEABLE_FILTER_FMT, "weave_filter_on.tex", "weave_filter_off.tex", "weaveableFilter", GetWeaveableSkinFilter()))
    self.picker.header:AddChild(self.filter_bar:AddSorter())
    self.picker.header:AddChild(self.filter_bar:AddSearch())

    self:Refresh()

    self:_DoFocusHookups()
end

function BeefaloExplorerPanel:_DoFocusHookups()
    self.panel_selector:SetFocusChangeDir(MOVE_RIGHT, self.filter_bar:BuildFocusFinder())
    self.picker:SetFocusChangeDir(MOVE_LEFT, self.panel_selector)
    self.picker.header.focus_forward = self.filter_bar
end

function BeefaloExplorerPanel:TryToClickSelected()
    local selected_item_key = self.selected_skins[self.picker.primary_item_type]
    if selected_item_key then
        local fallback
        for _, w in ipairs(self.picker.scroll_list:GetListWidgets()) do
            if w.data.item_key == selected_item_key then
                w:onclick()
                fallback = nil
                break
            elseif w.data.item_key and w.data.item_key:find("default1") then
                fallback = w
            end
        end
        if fallback then
            fallback:onclick()
        end
    end
end

function BeefaloExplorerPanel:Refresh()
    self.ignorethisclick = true
    self.filter_bar:RefreshFilterState()
    self.ignorethisclick = nil
    self:TryToClickSelected()
end

function BeefaloExplorerPanel:OnShow()
    BeefaloExplorerPanel._base.OnShow(self)
    self:Refresh()
end

function BeefaloExplorerPanel:OnClickedItem(item_data, is_selected)
    if not self.ignorethisclick then
        self:_SelectSkin(self.beef_itemtype, item_data.item_key, is_selected, item_data.is_owned)
    end
end
function BeefaloExplorerPanel:_SelectSkin(item_type, item_key, is_selected, is_owned)
    self.selected_skins[item_type] = item_key

    self:_ApplySkins(self.selected_skins)
    self:SaveLoadout()
end


function BeefaloExplorerPanel:_BuildItemExplorer(index)
    local list_options = {
        scroll_context = {
            owner = self.owner,
            input_receivers = { self },
            user_profile = self.user_profile,
        },
        widget_width = WIDGET_WIDTH,
        widget_height = WIDGET_HEIGHT,
        num_visible_rows = 3,
        num_columns = 5,
        scrollbar_offset = 20,
    }
    local kind = {
        "beef_head",
        "beef_horn",
        "beef_body",
        "beef_feet",
        "beef_tail",
    }
    self.beef_itemtype = kind[index]
    return ItemExplorer(STRINGS.UI.COLLECTIONSCREEN.BEEFALO, self.beef_itemtype, BEEFALO_CLOTHING, list_options)
end

function BeefaloExplorerPanel:ApplySkinSet(skins)
    self.selected_skins = skins
    self:_ApplySkins(self.selected_skins)
end

function BeefaloExplorerPanel:_LoadSkinPresetsScreen()
    TheFrontEnd:PushScreen(BeefaloSkinPresetsPopup(self.user_profile, self.currentcharacter, self.selected_skins, function(skins) self:ApplySkinSet(skins) self:TryToClickSelected() end))
end

function BeefaloExplorerPanel:OnUpdate(dt)
end

function BeefaloExplorerPanel:GetHelpText()
    if AllowSkins() then
		local controller_id = TheInput:GetControllerID()
		local t = {}

        table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_1) .. " " .. STRINGS.UI.SKIN_PRESETS.TITLE)

		return table.concat(t, "  ")
	else
		return ""
	end
end

function BeefaloExplorerPanel:OnControl(control, down)
    if BeefaloExplorerPanel._base.OnControl(self, control, down) then return true end

    if not down then
        if control == CONTROL_MENU_MISC_1 and AllowSkins() then
            self:_LoadSkinPresetsScreen()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        end
	end

    return false
end

return BeefaloExplorerPanel
