local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local Menu = require "widgets/menu"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TextEdit = require "widgets/textedit"
local TEMPLATES = require "widgets/templates"

local STRING_MAX_LENGTH = 254 -- http://tools.ietf.org/html/rfc5321#section-4.5.3.1

local InputDialogString = ""

local InputDialogScreen = Class(Screen, function(self, title, buttons, modal, start_editing)
	Screen._ctor(self, "InputDialogScreen")
	self.buttons = buttons

    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    if modal then
        --darken everything behind the dialog for modals
        self.black:SetTint(0,0,0,.75)
    else
        -- non-modals are still technically modal, they just cancel if the outside is clicked
        self.black:SetTint(0,0,0,0)
        self.black.OnMouseButton = function(wdgt, button, down, x, y)
            if #self.buttons > 1 and self.buttons[1] then
                self.buttons[1].cb()
                print("cancel bg")
                return true
            end
        end
    end

    self.proot = self:AddChild(Widget("ROOT"))
    self.proot:SetScaleMode(SCALEMODE_PROPORTIONAL)
    if modal then
        self.proot:SetVAnchor(ANCHOR_MIDDLE)
        self.proot:SetHAnchor(ANCHOR_MIDDLE)
        self.proot:SetPosition(0,0,0)
    else
        self.proot:SetVAnchor(ANCHOR_BOTTOM)
        self.proot:SetHAnchor(ANCHOR_MIDDLE)
        self.proot:SetPosition(0,120,0)
    end

	--throw up the background
    self.bg = self.proot:AddChild(TEMPLATES.CurlyWindow(130, 100, .8, .8, 54, -32))
    self.bg.fill = self.proot:AddChild(Image("images/fepanel_fills.xml", "panel_fill_tiny.tex"))
    self.bg.fill:SetScale(.78, .48)
    self.bg.fill:SetPosition(8, 12)

	--title
    self.title = self.proot:AddChild(Text(BUTTONFONT, 50))
    self.title:SetPosition(0, 50, 0)
    self.title:SetColour(0,0,0,1)
    self.title:SetString(title)

    local whitebar = self.proot:AddChild(Image("images/ui.xml", "single_option_bg.tex"))
    whitebar:ScaleToSize( 470, 50 )
    whitebar:SetPosition(8, -20, 0)

    self.edit_text_bg = self.proot:AddChild( Image() )
    self.edit_text_bg:SetTexture( "images/textboxes.xml", "textbox2_grey.tex" )
    self.edit_text_bg:SetPosition( 8, -20, 0 )
    self.edit_text_bg:ScaleToSize( 460, 40 )

	self.edit_text = self.proot:AddChild( TextEdit( NEWFONT, 25, "" ) )
	self.edit_text:SetPosition( 10, -20, 0 )
	self.edit_text:SetRegionSize( 430, 40 )
	self.edit_text:SetHAlign(ANCHOR_LEFT)
	self.edit_text:SetFocusedImage( self.edit_text_bg, "images/textboxes.xml", "textbox2_grey.tex", "textbox2_gold.tex", "textbox2_gold_greyfill.tex" )
	self.edit_text:SetTextLengthLimit( STRING_MAX_LENGTH )
    self.edit_text:SetForceEdit(true)

    local spacing = 200

	self.menu = self.proot:AddChild(Menu(buttons, spacing, true))
	self.menu:SetPosition(-(spacing*(#buttons-1))/2, -95, 0)
    for i,v in pairs(self.menu.items) do
        v:SetScale(.7)
        v.image:SetScale(.6, .8)
    end
	self.default_focus = self.edit_text
end)

function InputDialogScreen:GetText()
	return InputDialogString
end

function InputDialogScreen:GetActualString()
	return self.edit_text and self.edit_text:GetLineEditString() or ""
end

function InputDialogScreen:OverrideText(text)
    self.edit_text:SetString(text)
end

function InputDialogScreen:SetValidChars(chars)
	self.edit_text:SetCharacterFilter(chars)
end

function InputDialogScreen:SetTitleTextSize(size)
	self.title:SetSize(size)
end

function InputDialogScreen:SetButtonTextSize(size)
	self.menu:SetTextSize(size)
end

function InputDialogScreen:OnControl(control, down)


	if self.edit_text ~= nil then
		InputDialogString = self.edit_text:GetString()
	end

    if InputDialogScreen._base.OnControl(self,control, down) then return true end

    if self.edit_text and self.edit_text.editing then
        self.edit_text:OnControl(control, down)
       	return true
    end

    -- gjans: This makes it so that if the text box loses focus and you click
    -- on the bg, it presses accept. Kind of weird behaviour. I'm guessing
    -- something like it is needed for controllers, but it's not exaaaactly
    -- this.
    --if control == CONTROL_ACCEPT and not down then
        --if #self.buttons >= 1 and self.buttons[#self.buttons] then
            --self.buttons[#self.buttons].cb()
            --return true
        --end
    --end

    if control == CONTROL_CANCEL and not down then
        if #self.buttons > 1 and self.buttons[2] then
            self.buttons[2].cb()
            return true
        end
    end
end

function InputDialogScreen:Close()
	TheFrontEnd:PopScreen(self)
end

function InputDialogScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
	if #self.buttons > 1 and self.buttons[#self.buttons] then
        table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)
    end
	return table.concat(t, "  ")
end

return InputDialogScreen
