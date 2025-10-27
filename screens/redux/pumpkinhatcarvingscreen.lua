local Image = require("widgets/image")
local Menu = require "widgets/menu"
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")
local UIAnimButton = require("widgets/uianimbutton")
local Widget = require("widgets/widget")

local PumpkinHatCarvable = require("components/pumpkinhatcarvable")

local UI_ATLAS = "images/pumpkin_carving.xml"

local SCREEN_OFFSET = -0.38 * RESOLUTION_X
local DISABLED_TINT = RGB(77, 77, 77)
local LOCKED_TINT = RGB(127, 127, 127)
local BTN_SCALE = 0.4

local PART_SYM =
{
	reye = "r_eye",
	leye = "l_eye",
	--mouth = "mouth",
}

local ROWS_PER_PART = 3
local COLS_PER_TOOL = 3
local VARS_PER_TOOL = ROWS_PER_PART * COLS_PER_TOOL
local NUM_PARTS = 3
local NUM_TOOLS = 3
local NUM_ROWS = ROWS_PER_PART * NUM_PARTS
local NUM_COLS = COLS_PER_TOOL * NUM_TOOLS

local PumpkinHatCarvingScreen = Class(Screen, function(self, owner, target)
	self.owner = owner
	Screen._ctor(self, "PumpkinHatCarvingScreen")

	assert(VARS_PER_TOOL == PumpkinHatCarvable.VARS_PER_TOOL)
	assert(NUM_PARTS == #PumpkinHatCarvable.PARTS)

	self.root = self:AddChild(Widget("root"))
	self.root:SetVAnchor(ANCHOR_MIDDLE)
	self.root:SetHAnchor(ANCHOR_MIDDLE)
	self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

	local bg = self.root:AddChild(Image("images/bg_redux_wardrobe_bg.xml", "wardrobe_bg.tex"))
	bg:SetScale(0.8)
	bg:SetPosition(-200, 0)
	bg:SetTint(1, 1, 1, 0.76)

	local pumpkinbg = self.root:AddChild(Image("images/pumpkin_carving.xml", "pumpkin_400xScale_glow.tex"))
	pumpkinbg:SetScale(0.5)
	pumpkinbg:SetPosition(-400, 0)

	local pumpkin = self.root:AddChild(UIAnim())
	local baseid = target.base and target.base:value() or 1
	if baseid == 1 then
		pumpkin:GetAnimState():SetBuild("hat_pumpkin")
	else
		pumpkin:GetAnimState():SetSkin("pumpkinhat_"..tostring(baseid), "hat_pumpkin")
	end
	pumpkin:GetAnimState():SetBank("pumpkinhat")
	pumpkin:GetAnimState():PlayAnimation("anim")
	pumpkin:SetPosition(-400, -125)
	pumpkin:SetScale(1.25)

	self.face = pumpkin:AddChild(UIAnim())
	self.face:GetAnimState():SetBuild("hat_pumpkin")
	self.face:GetAnimState():SetBank("pumpkinhat")
	self.face:GetAnimState():PlayAnimation("face")

	local buttons =
	{
		{ text = STRINGS.UI.PUMPKIN_CARVING_POPUP.CANCEL, cb = function() self:Cancel() end },
		{ text = STRINGS.UI.PUMPKINHAT_CARVING_POPUP.RANDOMIZE, cb = function() self:RandomizeFace() end },
		{ text = STRINGS.UI.PUMPKIN_CARVING_POPUP.SET, cb = function() self:SaveAndClose() end },
	}
	local spacing = 70
	self.menu = self.root:AddChild(Menu(buttons, spacing, false, "carny_long", nil, 30))
	self.menu:SetMenuIndex(3)
	self.menu:SetPosition(493, -260, 0)

	-- hide the menu if the player is using a controller; we'll control this with button presses that are listed in the helpbar
	if TheInput:ControllerAttached() and not TheFrontEnd.tracking_mouse then
		self.menu:Hide()
		self.menu:Disable()
	end  

	self.shapemenu = self.root:AddChild(Widget("shapemenu"))
	self.shapemenu:SetPosition(-150, 224)

	local btn_size = BTN_SCALE * 100
	local btn_spacing = 5
	local part_spacing = 62
	local tool_spacing = 15

	for partid, part in ipairs(PumpkinHatCarvable.PARTS) do
		local cx = (NUM_COLS * (btn_size + btn_spacing) - btn_spacing + (NUM_TOOLS - 1) * (tool_spacing - btn_spacing)) / 2
		local cy = -((partid - 1) * (ROWS_PER_PART * (btn_size + btn_spacing) - btn_spacing + part_spacing) + (ROWS_PER_PART * (btn_size + btn_spacing) - btn_spacing) / 2)

		local banner = self.shapemenu:AddChild(Image(UI_ATLAS, "pumpkin_ui_banner.tex"))
		banner:SetRotation(-90)
		banner:SetPosition(cx + 6, cy + 6)
		banner:SetScale(0.45, -0.61)

		local label = self.shapemenu:AddChild(Text(HEADERFONT, 20, STRINGS.UI.PUMPKINHAT_CARVING_POPUP[string.upper(part)]))
		local w, h = label:GetRegionSize()
		label:SetPosition(w / 2 - 6, h / 2 + btn_spacing - (partid - 1) * (ROWS_PER_PART * (btn_size + btn_spacing) - btn_spacing + part_spacing))
	end

	local inventory = self.owner and self.owner.replica.inventory or nil

	for toolid = NUM_TOOLS, 1, -1 do
		local tool = "pumpkincarver"..tostring(toolid)
		local enabled = inventory and inventory:Has(tool, 1, true)

		local cx = (COLS_PER_TOOL * (btn_size + btn_spacing) - btn_spacing) / 2 + (toolid - 1) * (COLS_PER_TOOL * (btn_size + btn_spacing) - btn_spacing + tool_spacing)
		local y = 67

		local frame = self.shapemenu:AddChild(Image(UI_ATLAS, "carving_tool_frame.tex"))
		frame:SetPosition(cx, y)
		frame:SetScale(0.2)

		local img = self.shapemenu:AddChild(Image(UI_ATLAS, tool..tostring(".tex")))
		img:SetPosition(cx, y)
		img:SetScale(0.15)

		if not enabled then
			frame:SetTint(unpack(LOCKED_TINT))
			img:SetTint(unpack(LOCKED_TINT))

			local lock = self.shapemenu:AddChild(Image(UI_ATLAS, "btnframe_lock_230x230.tex"))
			lock:SetPosition(cx, y)
			lock:SetScale(0.2)
		end
	end

	self.shapebtns = self.shapemenu:AddChild(Widget("shapebtns"))
	self.buttons = {}
	self.highlights = {}

	for row = 1, NUM_ROWS do
		local partid = math.ceil(row / ROWS_PER_PART)
		local part = PumpkinHatCarvable.PARTS[partid]
		local partrow = row - (partid - 1) * ROWS_PER_PART
		local y = -(btn_size / 2 + (row - 1) * (btn_size + btn_spacing) + (partid - 1) * (part_spacing - btn_spacing))

		local rowarray = {}
		self.buttons[row] = rowarray

		for col = 1, NUM_COLS do
			local toolid = math.ceil(col / COLS_PER_TOOL)
			local tool = "pumpkincarver"..tostring(toolid)
			local enabled = inventory and inventory:Has(tool, 1, true)

			local partcol = col - (toolid - 1) * COLS_PER_TOOL
			local x = btn_size / 2 + (col - 1) * (btn_size + btn_spacing) + (toolid - 1) * (tool_spacing - btn_spacing)

			local variation = (toolid - 1) * VARS_PER_TOOL + (partrow - 1) * COLS_PER_TOOL + partcol
			local sym = PART_SYM[part] or part
			local swap_sym = "swap_"..sym
			sym = sym..tostring(variation)

			local btn = self.shapebtns:AddChild(UIAnimButton("pumpkinhat", "hat_pumpkin", "btn", "btn", "btn", "btn"))
			btn.animstate:OverrideSymbol(swap_sym, "hat_pumpkin", sym)
			btn.animstate:OverrideSymbol(swap_sym.."_outline", "hat_pumpkin", sym.."_outline")
			btn:SetScale(BTN_SCALE)
			btn:SetPosition(x, y)
			if enabled then
				local function _moveforward()
					btn:MoveToFront()
					btn:SetScale(BTN_SCALE * 1.1)
				end
				local function _moveback()
					local cur = self.facedata[part]
					if not (cur and self:GetButtonForPart(part, cur) == btn) then
						btn:MoveToBack()
					end
					btn:SetScale(BTN_SCALE)
				end
				btn:SetOnFocus(_moveforward)
				btn:SetOnLoseFocus(_moveback)
				btn:SetOnDown(_moveback)
				btn:SetOnClick(function()
					self:SetPart(part, variation)
					if btn:IsFocusedState() then
						_moveforward()
					end
				end)
			else
				btn:Disable()
				btn.animstate:SetMultColour(unpack(DISABLED_TINT))
			end
			rowarray[col] = btn
		end
	end

	--component exists on clients
	self.facedata = {}
	if target and target.components.pumpkinhatcarvable then
		local data = target.components.pumpkinhatcarvable:GetFaceData()
		for partid, part in ipairs(PumpkinHatCarvable.PARTS) do
			local variation = data[part]
			if variation then
				self:SetPart(part, variation)
			else
				self:RandomizePart(part)
			end
		end
		self.dirty = false --reset to false for loaded parts
		for part, variation in pairs(self.facedata) do
			if variation ~= data[part] then
				self.dirty = true
				break
			end
		end
	else
		self.dirty = false
	end

	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)

	self:ResetDefaultFocus()
	self:DoFocusHookups()

	self.pausetask = self.inst:DoStaticTaskInTime(0.5, function()
		self.pausetask = nil
		SetAutopaused(true)
	end)
end)

function PumpkinHatCarvingScreen:TrySetFocusChangeDir(movedir, row, col, drow, dcol)
	local btn = self.buttons[row][col]
	while true do
		row = row + drow
		col = col + dcol
		local nextbtn = self.buttons[row] and self.buttons[row][col]
		if nextbtn == nil then
			return false
		elseif nextbtn.enabled then
			btn:SetFocusChangeDir(movedir, nextbtn)
			return true
		end
	end
end

function PumpkinHatCarvingScreen:ResetDefaultFocus()
	for _, v in ipairs(self.buttons[1]) do
		if v.enabled then
			self.default_focus = v
			break
		end
	end
end

function PumpkinHatCarvingScreen:DoFocusHookups()
	for row = 1, NUM_ROWS do
		for col = 1, NUM_COLS do
			self:TrySetFocusChangeDir(MOVE_UP, row, col, -1, 0)
			self:TrySetFocusChangeDir(MOVE_DOWN, row, col, 1, 0)
			self:TrySetFocusChangeDir(MOVE_LEFT, row, col, 0, -1)
			self:TrySetFocusChangeDir(MOVE_RIGHT, row, col, 0, 1)
		end

		local lastbtn
		local rowarray = self.buttons[row]
		for col = NUM_COLS, 1, -1 do
			local btn = rowarray[col]
			if btn.enabled then
				btn:SetFocusChangeDir(MOVE_RIGHT, self.menu)
				btn:SetOnGainFocus(function()
					self.menu:SetFocusChangeDir(MOVE_LEFT, btn)
				end)
				lastbtn = btn
				break
			end
		end

		if lastbtn then
			self.menu:SetFocusChangeDir(MOVE_LEFT, lastbtn)
		end
	end
end

function PumpkinHatCarvingScreen:OnDestroy()
	if self.pausetask == nil then
		SetAutopaused(false)
	end
	POPUPS.PUMPKINHATCARVING:Close(self.owner)
	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)
	self._base.OnDestroy(self)
end

function PumpkinHatCarvingScreen:Cancel()
	POPUPS.PUMPKINHATCARVING:Close(self.owner)
	TheFrontEnd:PopScreen(self)
end

function PumpkinHatCarvingScreen:SaveAndClose()
	if not self.dirty then
		self:Cancel()
		return
	end
	local data = {}
	for _, part in ipairs(PumpkinHatCarvable.PARTS) do
		table.insert(data, self.facedata[part] or 0)
	end
	POPUPS.PUMPKINHATCARVING:Close(self.owner, unpack(data))
	TheFrontEnd:PopScreen(self)
end

function PumpkinHatCarvingScreen:GetButtonForPart(part, variation)
	local toolid = math.ceil(variation / VARS_PER_TOOL)
	local subvar = variation - (toolid - 1) * VARS_PER_TOOL

	local partid = PumpkinHatCarvable.PART_IDS[part]
	local partrow = math.ceil(subvar / COLS_PER_TOOL)
	local row = (partid - 1) * ROWS_PER_PART + partrow

	local partcol = subvar - (partrow - 1) * COLS_PER_TOOL
	local col = (toolid - 1) * COLS_PER_TOOL + partcol
	
	return self.buttons[row][col]
end

function PumpkinHatCarvingScreen:SetPart(part, variation)
	local old = self.facedata[part]
	if old ~= variation then
		self.facedata[part] = variation
		self.dirty = true
		local sym = PART_SYM[part] or part
		local swap_sym = "swap_"..sym
		sym = sym..tostring(variation)
		self.face:GetAnimState():OverrideSymbol(swap_sym, "hat_pumpkin", sym)
		self.face:GetAnimState():OverrideSymbol(swap_sym.."_outline", "hat_pumpkin", sym.."_outline")

		local btn = self:GetButtonForPart(part, variation)
		btn.animstate:Show("BTN_HIGHLIGHT")
		btn:MoveToFront()

		local highlight = self.highlights[part]
		if highlight == nil then
			highlight = UIAnim()
			highlight:GetAnimState():SetBuild("hat_pumpkin")
			highlight:GetAnimState():SetBank("pumpkinhat")
			highlight:GetAnimState():PlayAnimation("btn_highlight")
			self.highlights[part] = highlight
		end
		btn:AddChild(highlight)
	end
end

function PumpkinHatCarvingScreen:RandomizePart(part)
	local partid = PumpkinHatCarvable.PART_IDS[part]
	local choices = {}
	local old = self.facedata[part]
	local partrow0 = (partid - 1) * ROWS_PER_PART
	for partrow = 1, ROWS_PER_PART do
		local rowarray = self.buttons[partrow0 + partrow]
		for toolid = 1, NUM_TOOLS do
			local partcol0 = (toolid - 1) * COLS_PER_TOOL
			for partcol = 1, COLS_PER_TOOL do
				if rowarray[partcol0 + partcol].enabled then
					local variation = (toolid - 1) * VARS_PER_TOOL + (partrow - 1) * COLS_PER_TOOL + partcol
					if variation ~= old then
						table.insert(choices, variation)
					end
				else
					break
				end
			end
		end
	end
	if #choices > 0 then
		self:SetPart(part, choices[math.random(#choices)])
	end
end

function PumpkinHatCarvingScreen:RandomizeFace()
	for _, part in ipairs(PumpkinHatCarvable.PARTS) do
		self:RandomizePart(part)
	end
end

function PumpkinHatCarvingScreen:OnControl(control, down)
	if self._base.OnControl(self, control, down) then return true end

	if not down then
		if control == CONTROL_MENU_BACK or control == CONTROL_CANCEL then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			self:Cancel()
			return true
		elseif control == CONTROL_MENU_MISC_1 then
			self:RandomizeFace()
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			return true
		elseif control == CONTROL_MENU_START then
			self:SaveAndClose()
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			return true
		end
	end
	return false
end

function PumpkinHatCarvingScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL).." "..STRINGS.UI.PUMPKIN_CARVING_POPUP.CANCEL
		.."  "..TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_1).." "..STRINGS.UI.PUMPKINHAT_CARVING_POPUP.RANDOMIZE
		.."  "..TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_START).." "..STRINGS.UI.PUMPKIN_CARVING_POPUP.SET
end

return PumpkinHatCarvingScreen
