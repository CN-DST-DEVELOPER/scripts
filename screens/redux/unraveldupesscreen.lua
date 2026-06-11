local Widget = require "widgets/widget"
local Screen = require "widgets/screen"
local TEMPLATES = require("widgets/redux/templates")
local ImageButton = require "widgets/imagebutton"
local ItemImage = require("widgets/redux/itemimage")
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"

local UnravelDupesScreen = Class(Screen, function(self, dupes, ok_cb, cancel_cb)
	Screen._ctor(self, "UnravelDupesScreen")

	self.ok_cb = ok_cb
	self.cancel_cb = cancel_cb

	self.black = self:AddChild(Image("images/global.xml", "square.tex"))
	self.black:SetVRegPoint(ANCHOR_MIDDLE)
	self.black:SetHRegPoint(ANCHOR_MIDDLE)
	self.black:SetVAnchor(ANCHOR_MIDDLE)
	self.black:SetHAnchor(ANCHOR_MIDDLE)
	self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
	self.black:SetTint(0,0,0,.75)

	self.root = self:AddChild(TEMPLATES.ScreenRoot())

	local PANEL_WIDTH = 1000
	local PANEL_HEIGHT = 530

	self.dialog = self.root:AddChild(TEMPLATES.RectangleWindow(PANEL_WIDTH, PANEL_HEIGHT))
	self.dialog:SetPosition(0, 0)
	local r,g,b = unpack(UICOLOURS.BROWN_DARK)
	self.dialog:SetBackgroundTint(r,g,b,0.95)

	local textwidth = 60
	self.selected_bg = self.root:AddChild(Image("images/frontend_redux.xml", "listitem_thick_normal.tex"))
	self.selected_bg:SetTint(0,0,0,0.2)
	self.selected_bg:SetSize(textwidth + 10, 30)
	self.selected_bg:SetPosition(-477, -240)

	local selected_text = self.root:AddChild(Text(BUTTONFONT, 20,"", UICOLOURS.WHITE))

	selected_text:SetRegionSize(textwidth, 40)
	selected_text:SetPosition(-477, -240)
	selected_text:SetString("999/999")
	self.selected_text = selected_text

	local selected_label = self.root:AddChild(Text(BUTTONFONT, 20,"", UICOLOURS.WHITE))
	selected_label:SetPosition(-420,-240)
	selected_label:SetHAlign( ANCHOR_LEFT )
	selected_label:SetString(STRINGS.UI.UNRAVELDUPESSCREEN.SELECTED)

	local textwidth = 60
	local spool_bg= self.root:AddChild(Image("images/frontend_redux.xml", "listitem_thick_normal.tex"))
	spool_bg:SetTint(0,0,0,0.2)
	spool_bg:SetSize(textwidth + 10, 30)
	spool_bg:SetPosition(-277, -240)

	local spool_text = self.root:AddChild(Text(BUTTONFONT, 20,"", UICOLOURS.WHITE))
	--spool_text:SetRegionSize(textwidth, 40)
	spool_text:SetPosition(-277, -240)
	self.selected_text = selected_text
	self.spool_text = spool_text


	local spool_icon = self.root:AddChild(Image("images/button_icons.xml", "weave_filter_on.tex"))
	spool_icon:SetScale(0.10)
	spool_icon:SetPosition(-235, -240)
	self.spool_icon = spool_icon

	local totalwidth = 1000
	local columns = 4
	local rows = 5;
	local imagesize = 32
	local bigimagesize = 64
	local imagebuffer = 6
	local row_w = totalwidth/columns
	local row_h = 80

	local contained_items = {}
	for i,v in pairs(dupes) do
		local value = TheItems:GetBarterSellPrice(i)
		for count = 1,v do 
			table.insert(contained_items, {item = i, selected = true, value = value})
		end
	end

	local function updatestats()
		local selected = 0
		local totSpool = 0
		for i,v in pairs(contained_items) do
			if v.selected then
				selected = selected + 1
				totSpool = totSpool + v.value
			end
		end
		selected_text:SetString(selected.."/"..#contained_items)
		spool_text:SetString(totSpool)
		if selected == 0 then
			self.ok_button:Disable()
		else
			self.ok_button:Enable()
		end
	end

	local scroll_list = nil
	local list_option = {}
	local unselect_transparancy = 0.3

	local function itemWidgetConstructor(context, index)
		local w = Widget("BarterCell_" .. index)

		w.root = w:AddChild(Widget("Widget_root"))

		w.hidden_button = w:AddChild(ImageButton("images/global.xml", "square.tex"))
		w.hidden_button:SetImageNormalColour(1,1,1,0)
		w.hidden_button:SetImageFocusColour(1,1,1,0.3)
		w.hidden_button.scale_on_focus = false
		w.hidden_button.clickoffset = Vector3(0, 0, 0)
		w.hidden_button:ForceImageSize(row_w, row_h)


		w.bg = w.root:AddChild(Image("images/frontend_redux.xml", "listitem_thick_normal.tex"))
		w.bg:SetSize(row_w, row_h + 2)
		w.bg:SetTint(0,0,0,0.4)

		w.item = w.root:AddChild(
			ItemImage(
				nil,
				self
			)
		)
		local image_padding = 4
		local image_w = row_h - 4
		w.item:SetPosition(-row_w / 2 + image_w / 2 + image_padding / 2 + 8, 2)
		w.item:ScaleToSize(row_h - 8)
		w.item.warn_marker:Hide()

		w.item_name = w.root:AddChild(Text(BUTTONFONT, 24,"", UICOLOURS.WHITE))
		local offx = -40
		local offy = 30
		local textwidth = 150
		local textheight = 50
		w.item_name:SetRegionSize( textwidth, textheight)
		w.item_name:SetPosition(offx + 0.5*textwidth, offy - 0.5*textheight)
		w.item_name:SetHAlign( ANCHOR_LEFT )
		w.item_name:SetVAlign( ANCHOR_TOP )
		w.item_name:EnableWordWrap(true)

		w.spool = w.root:AddChild(Image("images/button_icons.xml", "weave_filter_on.tex"))
		w.spool:SetScale(0.10)
		w.spool:SetPosition(105, -22)

		w.item_cost = w.root:AddChild(Text(BUTTONFONT, 20,"", UICOLOURS.WHITE))
		local offx = 95
		local offy = -14
		local textwidth = 100
		local textheight = 20
		w.item_cost:SetRegionSize( textwidth, 30)
		w.item_cost:SetPosition(offx - 0.5*textwidth, offy - 0.5*textheight)
		w.item_cost:SetHAlign( ANCHOR_RIGHT)

		w.focus_forward = w.hidden_button
		w.hidden_button.ongainfocusfn = function()
			scroll_list:OnWidgetFocus(w)
		end

		w.hidden_button:SetOnClick(function()
			if w.data then
				w.data.selected = not w.data.selected
				scroll_list:RefreshView()
				updatestats()
			end
		end)

		return w
	end

	local function itemWidgetUpdate(context, widget, data, index)
		widget.data = data
		if data then
			widget:Show()

			local item = data.item
			widget.item_name:SetString(GetSkinName(item))
			widget.item_cost:SetString(tostring(data.value))
			widget.item:SetItem(
				GetTypeForItem(item),
				item
			)

			if data.selected then
				widget.item_name:SetAlpha(1)
				widget.item_cost:SetAlpha(1)
				widget.spool:SetTint(1,1,1,1);
			else
				widget.item_name:SetString(GetSkinName(item))
				widget.item_name:SetAlpha(0.3)
				widget.item_cost:SetString(tostring(data.value))
				widget.item_cost:SetAlpha(0.3)

				widget.item.frame:SetUnowned()
				widget.spool:SetTint(0.3,0.3,0.3,1);
			end
		else
			widget:Hide()
		end
	end
	scroll_list = self.root:AddChild(TEMPLATES.ScrollingGrid(
        contained_items,
        {
            widget_width  = row_w,
            widget_height = row_h,
            num_visible_rows = rows,
            num_columns = columns,
            item_ctor_fn = itemWidgetConstructor,
            apply_fn = itemWidgetUpdate,
            scrollbar_offset = 20,
            scrollbar_height_offset = -60
        }))
	scroll_list:SetPosition(-15,0)

	self.title = self.root:AddChild(Text(BUTTONFONT, 40))
	self.title:SetPosition(0, 235, 0)
	self.title:SetColour(UICOLOURS.WHITE)
	self.title:SetString(STRINGS.UI.UNRAVELDUPESSCREEN.TITLE)

	self.scroll_list = scroll_list

	local function full_ok_cb()
		local dupes = {}
		for i,v in pairs(contained_items) do
			if v.selected then
				table.insert(dupes, {item = v.item, value = v.value})
			end
		end
		self.ok_cb(dupes)
	end

	self.ok_button = self.root:AddChild(
		TEMPLATES.StandardButton(
			full_ok_cb,
			STRINGS.UI.UNRAVELDUPESSCREEN.UNRAVEL,
			{200, 50}
		)
	)
	self.ok_button:SetPosition(390, -240)
	self.cancel_button = self.root:AddChild(
		TEMPLATES.StandardButton(
			self.cancel_cb,
			STRINGS.UI.UNRAVELDUPESSCREEN.CANCEL,
			{200, 50}
		)
	)
	self.cancel_button:SetPosition(190, -240)

	updatestats()

	self.ok_button:SetFocusChangeDir(MOVE_LEFT, self.cancel_button)
	self.cancel_button:SetFocusChangeDir(MOVE_RIGHT, self.ok_button)

	self.ok_button:SetFocusChangeDir(MOVE_UP, self.scroll_list)
	self.cancel_button:SetFocusChangeDir(MOVE_UP, self.scroll_list)
	
	self.scroll_list:SetFocusChangeDir(MOVE_DOWN, self.ok_button)
	self.scroll_list:SetFocusChangeDir(MOVE_RIGHT, self.ok_button)

	self.default_focus = self.ok_button
end)

function UnravelDupesScreen:OnControl(control, down)
	if UnravelDupesScreen._base.OnControl(self, control, down) then return true end

	if not down and control == CONTROL_CANCEL then
		TheFrontEnd:PopScreen()
		return true
	end
end

return UnravelDupesScreen
