local Widget = require "widgets/widget"
local Text = require "widgets/text"
local TEMPLATES = require "widgets/redux/templates"

local BarterWidget = Class(Widget, function(self)
    Widget._ctor(self, "BarterWidget")

    self.root = self:AddChild(Widget("Root"))
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    
    self.text = self.root:AddChild(Text(BODYTEXTFONT, 20))
    local width = 300
    self.text:SetRegionSize(width, 100)

    local pos_x = RESOLUTION_X * .5
    local pos_y = RESOLUTION_Y * .5
    self.text:SetPosition(pos_x - width / 2 - 10, pos_y - 10)

   local frame_w = width + 20
    local frame_h = 45
    self.frame = self.text:AddChild(Image("images/fepanels_redux.xml", "shop_panel.tex"))
    self.frame:SetPosition(0, -10)
    self.frame:MoveToBack()
    self.frame:SetSize(frame_w,frame_h)

    self.progressbar = self.text:AddChild(TEMPLATES.LargeScissorProgressBar())
    self.progressbar:SetPosition(0,-20)
    self.progressbar:SetScale(0.3, 0.3)

    TheFrontEnd.barter_widget = self
end)

function BarterWidget.Show()
    if not TheFrontEnd.barter_widget then
        local barter_widget = BarterWidget()
        TheFrontEnd.globalwidgetroot:AddChild(barter_widget)
    end
    Widget.Show(TheFrontEnd.globalwidgetroot)
end

function BarterWidget.Hide()
    if TheFrontEnd.barter_widget then
        Widget.Hide(TheFrontEnd.globalwidgetroot)
    end
end

function BarterWidget:UpdateInfo_Internal(command, item_id, index, tot_index)
    if command == "UnravelDupes" then
        local str = subfmt(STRINGS.UI.BARTER_QUEUE.UNRAVEL_COMMAND, {skin_name = STRINGS.SKIN_NAMES[item_id] or item_id} )
        self.text:SetString(str)   
	    local progress = index / tot_index
		self.progressbar:SetPercent(progress)
	elseif command == "Cancel" then
        self.text:SetString(STRINGS.UI.BARTER_QUEUE.CANCEL)   
    end
end

function BarterWidget.UpdateStart(command, item_id, index, tot_index)
    if TheFrontEnd.barter_widget then
        TheFrontEnd.barter_widget:UpdateInfo_Internal(command, item_id, index, tot_index)
    end
end

return BarterWidget