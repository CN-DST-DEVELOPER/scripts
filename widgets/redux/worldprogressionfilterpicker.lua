local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local RadioButtons = require "widgets/radiobuttons"
local TEMPLATES = require "widgets/redux/templates"

local TILE_SCALE = 0.3
local TILE_WIDTH = 256
local TILE_SPACING = 10

local radiobuttons_width = 190
local radiobuttons_options = {
    {data=WORLDPROGRESSIONTAG_CANT},
    {data=WORLDPROGRESSIONTAG_MUST},
    {data=nil},
}
local radiobutton_gold_on_pixels = 38
local RADIOBUTTON_SCALE = 0.8
local radiobuttons_buttonlayout = {
    width = radiobutton_gold_on_pixels,
    height = radiobutton_gold_on_pixels,
    image_scale = RADIOBUTTON_SCALE,
    background_image = "spinner_focus_square.tex",
    atlas = "images/global_redux.xml",
    on_image = "radiobutton_gold_on.tex",
    off_image = "radiobutton_gold_off.tex",
    normal_colour = UICOLOURS.GOLD,
    hover_colour = UICOLOURS.HIGHLIGHT_GOLD,
    selected_colour = UICOLOURS.GOLD,
    disabled_colour = GREY,
}

local WorldProgressionFilterPicker = Class(Widget, function(self, worldprogressionfilters)
    Widget._ctor(self, "WorldProgressionFilterPicker")

    self.worldprogressionfilters = worldprogressionfilters

    local server_list_width = 800
    local dialog_width = server_list_width + (60*2) -- nineslice sides are 60px each
    local row_width, row_height = dialog_width*0.9, 100
    local detail_img_width = 26
    local listings_per_view = math.floor(540 / row_height)
    local font_size_description = 24

    local function UpdateWidget(row)
        local data = row.tagdata
        local settings = self.worldprogressionfilters[data.namespace]
        local setting = settings and settings[data.tag] or nil
        local settingstring
        if setting == WORLDPROGRESSIONTAG_MUST then
            row.icon:SetTexture(data.atlas, data.tag:lower() .. ".tex")
            row.icon_bg:SetTexture("images/worldprogressionfilters.xml", "bg_must.tex")
            row.icon_status:SetTexture("images/worldprogressionfilters.xml", "icon_must.tex")
            settingstring = "MUST"
        elseif setting == WORLDPROGRESSIONTAG_CANT then
            row.icon:SetTexture(data.atlas, data.tag:lower() .. "_bw.tex")
            row.icon_bg:SetTexture("images/worldprogressionfilters.xml", "bg_cant.tex")
            row.icon_status:SetTexture("images/worldprogressionfilters.xml", "icon_cant.tex")
            settingstring = "CANT"
        else
            row.icon:SetTexture(data.atlas, data.tag:lower() .. ".tex")
            row.icon_bg:SetTexture("images/worldprogressionfilters.xml", "bg_any.tex")
            row.icon_status:SetTexture("images/worldprogressionfilters.xml", "icon_any.tex")
            settingstring = "ANY"
        end
        local description = STRINGS.UI.SERVERLISTINGSCREEN.WORLDPROGRESSION_TAGS[data.namespace_nocolon][settingstring][data.tag]
        row.description:SetString(description)
    end
    local function ScrollWidgetsCtor(context, i)
        local row = Widget("filter_row")
        local bg = row:AddChild(TEMPLATES.ListItemBackground_Static(
            row_width,
            row_height
        ))
        row.bg = bg
        bg:SetPosition(-20, 0)

        local textboxheight = (row_height - 20)
        local description = bg:AddChild(Text(CHATFONT, font_size_description))
        row.description = description
        description:SetHAlign(ANCHOR_LEFT)
        description:SetRegionSize(500, textboxheight)
        description:SetPosition(-50, 0)
        description:SetColour(UICOLOURS.GOLD_SELECTED)
        description:EnableWordWrap(true)

        local iconframe = bg:AddChild(Image("images/worldprogressionfilters.xml", "frame.tex"))
        row.iconframe = iconframe
        iconframe:SetScale(TILE_SCALE)
        iconframe:SetPosition(-360, 0)

        local icon = iconframe:AddChild(Image("images/worldprogressionfilters.xml", "bg_any.tex"))
        row.icon = icon
        icon:SetScale(0.9)
        icon:MoveToBack()

        local icon_bg = iconframe:AddChild(Image("images/worldprogressionfilters.xml", "bg_any.tex"))
        row.icon_bg = icon_bg
        icon_bg:MoveToBack()

        local icon_status = iconframe:AddChild(Image("images/worldprogressionfilters.xml", "icon_must.tex"))
        row.icon_status = icon_status
        icon_status:SetScale(2)
        icon_status:SetPosition(TILE_WIDTH*0.4, TILE_WIDTH*0.4)

        local radiobuttons = bg:AddChild(RadioButtons(radiobuttons_options, radiobuttons_width, textboxheight, radiobuttons_buttonlayout, true))
        row.radiobuttons = radiobuttons
        radiobuttons:SetPosition(265, 0)
        radiobuttons:SetOnChangedFn(function(setting)
            if row.tagdata and self.cb ~= nil then
                local settings = self.worldprogressionfilters[row.tagdata.namespace]
                if settings == nil then
                    settings = {}
                    self.worldprogressionfilters[row.tagdata.namespace] = settings
                end
                settings[row.tagdata.tag] = setting
                if next(settings) == nil then
                    self.worldprogressionfilters[row.tagdata.namespace] = nil
                end
                UpdateWidget(row)
                self.cb()
            end
        end)

        row.focus_forward = radiobuttons
        radiobuttons:SetOnGainFocus(function() self.scroll_list:OnWidgetFocus(row) self.last_focused_radiobuttons = radiobuttons end)

        return row
    end

    local function UpdateListWidget(context, row, data, index)
        if not row then return end
        row.tagdata = data
        if not data then
            row:Hide()
            return
        end
        row:Show()
        local settings = self.worldprogressionfilters[data.namespace]
        local setting = settings and settings[data.tag] or nil
        row.radiobuttons:SetSelected(setting)
        UpdateWidget(row)
    end

    local worldstatetags = {}
    ForEachWorldStateTagObject(function(worldstatetagobject)
        worldstatetagobject.ForEachTag(function(tag)
            table.insert(worldstatetags, {
                namespace = worldstatetagobject.namespace,
                namespace_nocolon = worldstatetagobject.namespace_nocolon,
                atlas = worldstatetagobject.atlas,
                tag = tag,
            })
        end)
    end)
    self.scroll_list = self:AddChild(TEMPLATES.ScrollingGrid(
        worldstatetags,
        {
            context = {},
            widget_width = dialog_width,
            widget_height = row_height,
            num_visible_rows = listings_per_view,
            num_columns = 1,
            item_ctor_fn = ScrollWidgetsCtor,
            apply_fn = UpdateListWidget,
            scrollbar_offset = -49,
            scrollbar_height_offset = -45,
            peek_percent = 0.55
        }
    ))
    --for self.scrolls_list.
    local icon_status_bg = self:AddChild(Image("images/frontend_redux.xml", "list_tabs_selected.tex"))
    icon_status_bg:SetPosition(280, 311.5)
    icon_status_bg:SetScale(radiobuttons_width / 256 * 1.1) -- 256 is the pixel width of list_tabs_selected

    local icon_status_cant = icon_status_bg:AddChild(Image("images/worldprogressionfilters.xml", "icon_cant.tex"))
    local icon_status_must = icon_status_bg:AddChild(Image("images/worldprogressionfilters.xml", "icon_must.tex"))
    local icon_status_any = icon_status_bg:AddChild(Image("images/worldprogressionfilters.xml", "icon_any.tex"))
    local icon_offset_y = -5
    icon_status_cant:SetPosition(-80, icon_offset_y)
    icon_status_must:SetPosition(-3, icon_offset_y)
    icon_status_any:SetPosition(73, icon_offset_y)
    local icon_status_scale = 0.8
    icon_status_cant:SetScale(icon_status_scale)
    icon_status_must:SetScale(icon_status_scale)
    icon_status_any:SetScale(icon_status_scale)
end)

function WorldProgressionFilterPicker:SetCallback(cb)
    self.cb = cb
end

return WorldProgressionFilterPicker
