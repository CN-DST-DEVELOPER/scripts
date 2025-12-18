local Text = require "widgets/text"
local Image = require "widgets/image"
local Puppet = require "widgets/skinspuppet"
local Widget = require "widgets/widget"
local ClothingExplorerPanel = require "widgets/redux/clothingexplorerpanel"
local Subscreener = require "screens/redux/subscreener"

local TEMPLATES = require "widgets/redux/templates"

require("characterutil")
require("util")
require("networking")
require("stringutil")

local function AllowSkins()
    return TheInventory:HasSupportForOfflineSkins() or TheNet:IsOnlineMode()
end

local LoadoutSelect_hermitcrab = Class(Widget, function(self, user_profile, initial_skins, filter, owner_player)
    Widget._ctor(self, "LoadoutSelect_hermitcrab")
    self.owner_player = owner_player
    self.user_profile = user_profile
    self.filter = filter
    self.currentcharacter = "hermitcrab"

    self.initial_skins = initial_skins

    self.loadout_root = self:AddChild(Widget("LoadoutRoot"))

    self.puppet_root = self:AddChild(Widget("puppet_root"))
    self.puppet_root:SetPosition(-35, -80)

    self.glow = self.puppet_root:AddChild(Image("images/lobbyscreen.xml", "glow.tex"))
    self.glow:SetPosition(-20, 20)
    self.glow:SetScale(2.5)
    self.glow:SetTint(1, 1, 1, .5)
    self.glow:SetClickable(false)

    self.puppet_nameplate = self.puppet_root:AddChild(Image("images/names_gold" .. LOC.GetNamesImageSuffix() .. "_pearl.xml", "pearl.tex"))
    self.puppet_nameplate:SetScale(0.40)
    self.puppet_nameplate:SetPosition(-30, 300)
    self.puppet_nameplate:SetClickable(false)

    self.pearl_mirror = self.puppet_root:AddChild(Image("images/bg_redux_pearl_mirror.xml", "pearl_mirror.tex"))
    self.pearl_mirror:SetScale(0.50)
    self.pearl_mirror:SetPosition(-175, -20)
    self.pearl_mirror:SetClickable(false)

    self.pearl_clothesrack = self.puppet_root:AddChild(Image("images/bg_redux_pearl_clothesrack.xml", "pearl_clothesrack.tex"))
    self.pearl_clothesrack:SetScale(0.50)
    self.pearl_clothesrack:SetPosition(125, 30)
    self.pearl_clothesrack:SetClickable(false)

    self.puppet = self.puppet_root:AddChild(Puppet())
    self.puppet:AddShadow()
	self.puppet_base_offset = { -30, -160 }
	self.puppet:SetPosition(self.puppet_base_offset[1], self.puppet_base_offset[2])
	self.puppet_default_scale = 4
    self.puppet:SetScale(self.puppet_default_scale)
    self.puppet:SetClickable(false)

    self:_LoadSavedSkins()

    if not AllowSkins() then
		self.bg_group = self.loadout_root:AddChild(Widget("bg_group"))
        self.bg_group:SetPosition(370, 10)

        self.frame = self.bg_group:AddChild(Widget("offline frame"))
        self.frame:SetScale(.7)

        self.frame.top = self.frame:AddChild(Image("images/global_redux.xml", "player_list_banner.tex"))
        self.frame.top:SetPosition(0, 150)

        self.frame.bottom = self.frame:AddChild(Image("images/global_redux.xml", "player_list_banner.tex"))
        self.frame.bottom:SetScale(-1)
        self.frame.bottom:SetPosition(0, -150)

		local text1 = self.bg_group:AddChild(Text(CHATFONT, 30, STRINGS.UI.LOBBYSCREEN.CUSTOMIZE))
		text1:SetPosition(0,20)
		text1:SetHAlign(ANCHOR_MIDDLE)
		text1:SetColour(UICOLOURS.GOLD_UNIMPORTANT)

		local text2 = self.bg_group:AddChild(Text(CHATFONT, 30, STRINGS.UI.LOBBYSCREEN.OFFLINE))
		text2:SetPosition(0,-20)
		text2:SetHAlign(ANCHOR_MIDDLE)
		text2:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    else
        self.doodad_count = self:AddChild(TEMPLATES.DoodadCounter(TheInventory:GetCurrencyAmount()))
	    self.doodad_count:SetPosition(580, 320)
	    self.doodad_count:SetScale(0.35)

        local reader = function(item_key)
            return table.contains(self.selected_skins, item_key)
        end
        local writer_builder = function(item_type)
            return function(item_data)
                self:_SelectSkin(item_type, item_data.item_key, item_data.is_active, item_data.is_owned)
            end
        end

        local filter_options = {
            ignore_survivor = true,
            npccharacter = "hermitcrab",
        }

        local explorer_panels = {
            base = self.loadout_root:AddChild(ClothingExplorerPanel(self, self.user_profile, "base", reader, writer_builder("base"), filter_options)),
        }

        self.subscreener = Subscreener(self, self._MakeMenu, explorer_panels)

        self.subscreener.menu:SetPosition(379, 315)


        for k,screen in pairs(self.subscreener.sub_screens) do
            screen:SetScale(0.85)
            screen:SetPosition(130, -10)
        end

        self.subscreener:SetPostMenuSelectionAction( function(selection)
            if selection ~= "base" then
                self:_CycleView(true)
            end
        end )

        self.divider_top = self.loadout_root:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
        self.divider_top:SetScale(0.53, 0.5)
        self.divider_top:SetPosition(405, 282)

        local active_sub = self.subscreener:GetActiveSubscreenFn()
        self.focus_forward = active_sub
    end
end)


function LoadoutSelect_hermitcrab:SetDefaultMenuOption()
    if self.subscreener then
        self.subscreener:OnMenuButtonSelected("base")
    end
end

function LoadoutSelect_hermitcrab:_CycleView(reset)
end

function LoadoutSelect_hermitcrab:_MakeMenu(subscreener)
    self.button_base = subscreener:WardrobeButtonMinimal("base")

    local menu_items = {
        {widget = self.button_base },
    }
    self:_UpdateMenu(self.selected_skins)
    self.menu = self.loadout_root:AddChild(TEMPLATES.StandardMenu(menu_items, 65, true))
    return self.menu
end

function LoadoutSelect_hermitcrab:_SaveLoadout()
    if AllowSkins() then
        self.user_profile:SetSkinsForCharacter(self.currentcharacter, self.selected_skins)
    end
end

function LoadoutSelect_hermitcrab:ApplySkinPresets(skins)
    if skins.base == nil then
        if table.contains(DST_CHARACTERLIST, self.currentcharacter) then --no base option for mod characters
            skins.base = self.currentcharacter.."_none"
        end
    end

    ValidateItemsLocal(self.currentcharacter, skins)
    ValidatePreviewItems(self.currentcharacter, skins, self.filter)

    self.preview_skins = shallowcopy(skins)
    self.selected_skins = { base = self.currentcharacter.."_none" }

    for _,screen in pairs(self.subscreener.sub_screens) do
        screen:ClearSelection() --we need to clear the selection, so that the refresh will apply without re-selection of previously selected items overriding
    end

    self:_RefreshAfterSkinsLoad()
end

function LoadoutSelect_hermitcrab:_LoadSavedSkins()
    if AllowSkins() then
        self.selected_skins = self.user_profile:GetSkinsForCharacter(self.currentcharacter)
    else
        self.selected_skins = { base = self.currentcharacter.."_none" }
    end
    self.preview_skins = shallowcopy(self.initial_skins)
    self.selected_skins = shallowcopy(self.initial_skins)

    self:_RefreshAfterSkinsLoad()
end

function LoadoutSelect_hermitcrab:_RefreshAfterSkinsLoad()
    -- Creating the subscreens requires skins to be loaded, so we might not have subscreener yet.
    if self.subscreener then
        for key,item in pairs(self.preview_skins) do
            if self.subscreener.sub_screens[key] ~= nil then
                self.subscreener.sub_screens[key]:RefreshInventory()
            end
        end
    end
    self:_ApplySkins(self.preview_skins, false)
    self:_UpdateMenu(self.selected_skins)
end

function LoadoutSelect_hermitcrab:_SelectSkin(item_type, item_key, is_selected, is_owned)
    local is_previewing = is_selected or not is_owned
    if is_previewing then
        --selecting the item or previewing an item
        self.preview_skins[item_type] = item_key
    end
    if is_owned and is_selected then
        self.selected_skins[item_type] = item_key
    end

    self:_ApplySkins(self.preview_skins)
    self:_UpdateMenu(self.selected_skins)
end

function LoadoutSelect_hermitcrab:_ApplySkins(skins, skip_change_emote)

    self.preview_skins = shallowcopy(skins)

    ValidateItemsLocal(self.currentcharacter, self.selected_skins)
    ValidatePreviewItems(self.currentcharacter, skins, self.filter)

    local skinname = skins.base
    if skinname == "hermitcrab_none" then
        skinname = "hermitcrab_build"
    end
	self.puppet:SetSkins(skinname, nil, skins, skip_change_emote) -- NOTES(JBK): This is different than other skin puppets and this worked do not copy elsewhere.
end

function LoadoutSelect_hermitcrab:_UpdateMenu(skins)
    if self.button_base then
        if skins["base"] then
            self.button_base:SetItem(skins["base"])
        else
            self.button_base:SetItem(self.currentcharacter.."_none")
        end
    end
end

function LoadoutSelect_hermitcrab:RefreshInventory(animateDoodad)
    self.doodad_count:SetCount(TheInventory:GetCurrencyAmount(),animateDoodad)
end

function LoadoutSelect_hermitcrab:OnUpdate(dt)
    if self.puppet then
        --self.puppet:EmoteUpdate(dt)
    end
end

return LoadoutSelect_hermitcrab
