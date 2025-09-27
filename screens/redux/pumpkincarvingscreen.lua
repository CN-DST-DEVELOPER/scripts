local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Menu = require "widgets/menu"
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")
local Widget = require("widgets/widget")

local PumpkinCarvable = require("components/pumpkincarvable")

local SHAPES_ATLAS = "images/pumpkin_carving.xml"
local UI_ATLAS = "images/pumpkin_carving.xml"
local PUMPKIN_ATLAS = "images/pumpkin_carving2.xml"

local SCREEN_OFFSET = -0.38 * RESOLUTION_X
local PUMPKIN_X = -300
local PUMPKIN_Y = 0
local SHAPES_X = 20
local SHAPES_Y = 160
local IMG_SCALE = 1.5
local PUMPKIN_BG_SCALE = IMG_SCALE / 2 --texture is 2x anim
local PUMPKIN_SCALE = IMG_SCALE / 4 --texture is 4x anim
local SHAPE_SCALE = IMG_SCALE / 2 --texture is 2x anim
local FX_SCALE = 0.5
local BUTTON_SCALE = 0.7 / 2 --texture is 2x anim
local INVALID_ALPHA = 0.4
local DISABLED_TINT = { 0.3, 0.3, 0.3, 1 }
local WARNING_BG_TINT = { 0, 0, 0, 0.75 }
local WARNING_DURATION = 1

local function _ScreenToLocal(x, y)
	local w, h = TheSim:GetScreenSize()
	if w > 0 and h > 0 then
		local propscale = math.max(RESOLUTION_X / w, RESOLUTION_Y / h)
		return (x - w / 2) * propscale - PUMPKIN_X, (y - h / 2) * propscale - PUMPKIN_Y
	end
	return 0, 0
end

local BOUNDARY_X1 = -50
local BOUNDARY_X2 = 40
local BOUNDARY_Y = -55
local BOUNDARY_R = 65
--keep in sync @pumpkincarvable.lua
local function _IsOnPumpkin(x, y, padding)
	local x1 = BOUNDARY_X1 * IMG_SCALE
	local x2 = BOUNDARY_X2 * IMG_SCALE
	local y1 = BOUNDARY_Y * IMG_SCALE
	padding = padding or 0
	local r = (BOUNDARY_R + padding) * IMG_SCALE
	padding = padding * IMG_SCALE
	if x > x1 - padding and x < x2 + padding and y > y1 - r and y < y1 + r then
		return true
	end
	r = r * r
	return distsq(x, y, x1, y1) < r
		or distsq(x, y, x2, y1) < r
end

local function _ClampToPumpkin(x, y)
	local x1 = BOUNDARY_X1 * IMG_SCALE
	local x2 = BOUNDARY_X2 * IMG_SCALE
	local y1 = BOUNDARY_Y * IMG_SCALE
	local r = BOUNDARY_R * IMG_SCALE - 0.00001
	if x >= x1 and x <= x2 then
		y = math.clamp(y, y1 - r, y1 + r)
	else
		local dx1 = x - x1
		local dx2 = x - x2
		local dy1 = y - y1
		local dy1sq = dy1 * dy1
		local rsq = r * r
		if math.abs(dx1) < math.abs(dx2) then
			local dsq = dx1 * dx1 + dy1sq
			if dsq > rsq then
				local k = r / math.sqrt(dsq)
				x = x1 + dx1 * k
				y = y1 + dy1 * k
			end
		else
			local dsq = dx2 * dx2 + dy1sq
			if dsq > rsq then
				local k = r / math.sqrt(dsq)
				x = x2 + dx2 * k
				y = y1 + dy1 * k
			end
		end
	end
	return x, y
end

local function _ShapeTexName(shape, rot, isfill)
	return string.format("%s%s%04d.tex", isfill and "fill_" or "cut_", shape, rot)
end

local SHAPE_ROTS =
{
	arc = 8,
	circle = 1,
	crescent = 8,
	diamond = 8,
	heart = 8,
	hexagon = 2,
	square = 2,
	star = 2,
	triangle = 8,
}

local function _IsUsingController()
	return TheInput:ControllerAttached() and not TheFrontEnd.tracking_mouse
end

local PumpkinCarvingScreen = Class(Screen, function(self, owner, target)
    self.owner = owner
    Screen._ctor(self, "PumpkinCarvingScreen")

	self.root = self:AddChild(Widget("root"))
	self.root:SetVAnchor(ANCHOR_MIDDLE)
	self.root:SetHAnchor(ANCHOR_MIDDLE)
	self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

	local bg = self.root:AddChild(Image("images/bg_redux_wardrobe_bg.xml", "wardrobe_bg.tex"))
	bg:SetScale(0.8)
	bg:SetPosition(-200, 0)
	bg:SetTint(1, 1, 1, 0.76)

	local pumpkinbg = self.root:AddChild(Image(UI_ATLAS, "pumpkin_400xScale_glow.tex"))
	pumpkinbg:SetScale(PUMPKIN_BG_SCALE)
	pumpkinbg:SetPosition(PUMPKIN_X, PUMPKIN_Y)

	local buttons =
	{
		{ text = STRINGS.UI.PUMPKIN_CARVING_POPUP.CANCEL, cb = function() self:Cancel() end },
		{ text = STRINGS.UI.PUMPKIN_CARVING_POPUP.RESET, cb = function() self:ClearCuts() end },
		{ text = STRINGS.UI.PUMPKIN_CARVING_POPUP.SET, cb = function() self:SaveAndClose() end },
	}
	local spacing = 70
	self.menu = self.root:AddChild(Menu(buttons, spacing, false, "carny_long", nil, 30))
	self.menu:SetMenuIndex(3)
	self.menu:SetPosition(493, -260, 0)
		
	-- hide the menu if the player is using a controller; we'll control this with button presses that are listed in the helpbar
	if _IsUsingController() then
		self.menu:Hide()
		self.menu:Disable()
	end  

	self.shapemenu = self.root:AddChild(Widget("shapemenu"))
	self.shapemenu:SetPosition(SHAPES_X, SHAPES_Y)

	self.pumpkinroot = self.root:AddChild(Widget("pumpkinroot"))
	self.pumpkinroot:SetPosition(PUMPKIN_X, PUMPKIN_Y)

	local pumpkin = self.pumpkinroot:AddChild(Image(PUMPKIN_ATLAS, "pumpkin_400xScale.tex"))
	pumpkin:SetScale(PUMPKIN_SCALE)

	self.lineroot = self.pumpkinroot:AddChild(Widget("lineroot"))
	self.fillroot = self.pumpkinroot:AddChild(Widget("fillroot"))

	self.warning = self.root:AddChild(Widget("warningroot"))
	self.warning:SetClickable(false)
	self.warning:Hide()
	self.warningtime = 0

	self.warningbg = self.warning:AddChild(Image("images/global.xml", "square.tex"))
	self.warningbg:SetTint(unpack(WARNING_BG_TINT))
	self.warningbg:ScaleToSize(RESOLUTION_X, 80)

	self.warningtext = self.warning:AddChild(Text(HEADERFONT, 30, STRINGS.UI.PUMPKIN_CARVING_POPUP.MAX_CUTS))

	self.cutdata = {}
	self.buttons = { {}, {}, {} }

	local btn_vspacing = 92
	local btn_hspacing = 120
	local inventory = self.owner and self.owner.replica.inventory or nil

	for toolid = 1, 3 do
		local tool = "pumpkincarver"..tostring(toolid)
		local enabled = inventory and inventory:Has(tool, 1, true)
		local x = btn_hspacing * (toolid - 1)

		local toolimg = tool..tostring(".tex")
		local toolicon = self.shapemenu:AddChild(Image(UI_ATLAS, toolimg))
		toolicon:SetPosition(x, 0)
		toolicon:SetScale(0.33)

		for i, v in ipairs(PumpkinCarvable.TOOL_SHAPES[tool]) do
			local btn = self.shapemenu:AddChild(ImageButton(UI_ATLAS, "btnframe_230x230.tex", nil, nil, nil, nil, { BUTTON_SCALE, BUTTON_SCALE }))
			local icon = btn.image:AddChild(Image(SHAPES_ATLAS, _ShapeTexName(v, 1, false)))
			icon:SetScale(1.2)
			btn:SetPosition(x, 8 - btn_vspacing * i)
			btn:SetFocusScale(BUTTON_SCALE * 1.16)
			btn:SetNormalScale(BUTTON_SCALE)
			btn:SetImageDisabledColour(unpack(DISABLED_TINT))
			btn.stopclicksound = true
			btn.ondown = function()
				TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_object")
			end
			btn.onclick = function()
				self.lastclickedbtn = btn
				self:StartDraggingShape(v)
			end
			if not enabled then
				btn:Disable()
				icon:SetTint(unpack(DISABLED_TINT))
			end
			self.buttons[toolid][i] = btn
		end

		local banner = self.shapemenu:AddChild(Image(UI_ATLAS, "pumpkin_ui_banner.tex"))
		banner:SetPosition(x, -150)
		banner:SetScale(BUTTON_SCALE)
		banner:MoveToBack()

		if not enabled then
			local lock = self.shapemenu:AddChild(Image(UI_ATLAS, "btnframe_lock_230x230.tex"))
			lock:SetPosition(x, -10)
			lock:SetScale(BUTTON_SCALE * 1.4)

			banner:SetTint(unpack(DISABLED_TINT))
			toolicon:SetTint(unpack(DISABLED_TINT))
		end
	end

	if target and target.components.pumpkincarvable then --component exists on clients
		local cutdata = target.components.pumpkincarvable:GetCutData()
		cutdata = string.len(cutdata) > 0 and DecodeAndUnzipString(cutdata) or nil
		if type(cutdata) == "table" then
			for i = 1, #cutdata, 4 do
				local shape = PumpkinCarvable.SHAPE_NAMES[cutdata[i] ]
				local rot = cutdata[i + 1]
				local x = cutdata[i + 2]
				local y = cutdata[i + 3]
				if shape and rot and x and y then
					x = x * IMG_SCALE
					y = -y * IMG_SCALE
					if _IsOnPumpkin(x, y, 1) then
						self:DoAddCutAt(x, y, shape, rot)
					end
				end
			end
		end
	end
	self.dirty = false

	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)

	self:ResetDefaultFocus()
	self:DoFocusHookups()

	SetAutopaused(true)
end)

function PumpkinCarvingScreen:TrySetFocusChangeDir(movedir, row, col, drow, dcol)
	local btn = self.buttons[col][row]
	while true do
		col = col + dcol
		row = row + drow
		local nextbtn = self.buttons[col] and self.buttons[col][row]
		if nextbtn == nil then
			return false
		elseif nextbtn.enabled then
			btn:SetFocusChangeDir(movedir, nextbtn)
			return true
		end
	end
end

function PumpkinCarvingScreen:ResetDefaultFocus()
	for col = 1, 3 do
		local btn = self.buttons[col][1]
		if btn.enabled then
			self.default_focus = btn
			break
		end
	end
end

function PumpkinCarvingScreen:DoFocusHookups()
	for col = 1, 3 do
		for row = 1, 3 do
			self:TrySetFocusChangeDir(MOVE_UP, row, col, -1, 0)
			self:TrySetFocusChangeDir(MOVE_DOWN, row, col, 1, 0)
			self:TrySetFocusChangeDir(MOVE_LEFT, row, col, 0, -1)
			self:TrySetFocusChangeDir(MOVE_RIGHT, row, col, 0, 1)
		end
	end

	for col = 3, 1, -1 do
		local btns = self.buttons[col]
		if btns[1].enabled then
			for row, v in ipairs(btns) do
				v:SetFocusChangeDir(MOVE_RIGHT, self.menu)
				v:SetOnGainFocus(function()
					self.menu:SetFocusChangeDir(MOVE_LEFT, v)
				end)
			end
			self.menu:SetFocusChangeDir(MOVE_LEFT, btns[3])
			break
		end
	end
end

function PumpkinCarvingScreen:OnDestroy()
	SetAutopaused(false)

	self:StopDraggingShape()

	POPUPS.PUMPKINCARVING:Close(self.owner)

	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)
	self._base.OnDestroy(self)
end

function PumpkinCarvingScreen:Cancel()
	self:StopDraggingShape()
	POPUPS.PUMPKINCARVING:Close(self.owner)
	TheFrontEnd:PopScreen(self)
end

function PumpkinCarvingScreen:SaveAndClose()
	if not self.dirty then
		self:Cancel()
		return
	end
	self:StopDraggingShape()
	local data = {}
	for i, v in ipairs(self.cutdata) do
		PumpkinCarvable.AddCutData(data, v.shape, v.rot, math.floor(0.5 + v.x / IMG_SCALE), math.floor(0.5 - v.y / IMG_SCALE))
	end
	POPUPS.PUMPKINCARVING:Close(self.owner, ZipAndEncodeString(data))
	TheFrontEnd:PopScreen(self)
end

function PumpkinCarvingScreen:HasMaxCuts()
	return #self.cutdata >= TUNING.HALLOWEEN_PUMPKINCARVER_MAX_CUTS
end

function PumpkinCarvingScreen:MoveDraggingShapeTo(x, y)
	self.dragline:SetPosition(x, y)
	self.dragfill:SetPosition(x, y)

	if not self:HasMaxCuts() and _IsOnPumpkin(x, y) then
		self.dragline:SetTint(1, 1, 1, 1)
		self.dragfill:SetTint(1, 1, 1, 1)
		return true
	end
	self.dragline:SetTint(1, 1, 1, INVALID_ALPHA)
	self.dragfill:SetTint(1, 1, 1, INVALID_ALPHA)
	return false
end

function PumpkinCarvingScreen:StartDraggingShape(shape)
	self:StopDraggingShape()

	self.menu:SetClickable(false)
	self.shapemenu:SetClickable(false)

	self.dragline = self.lineroot:AddChild(Image(SHAPES_ATLAS, _ShapeTexName(shape, 1, false)))
	self.dragline:SetScale(SHAPE_SCALE)

	self.dragfill = self.fillroot:AddChild(Image(SHAPES_ATLAS, _ShapeTexName(shape, 1, true)))
	self.dragfill:SetScale(SHAPE_SCALE)

	--Override so we can convert to local space
	self.dragline.FollowMouse = function()
		if self.dragline.followhandler == nil then
			self.dragline.followhandler = TheInput:AddMoveHandler(function(x, y)
				self:MoveDraggingShapeTo(_ScreenToLocal(x, y))
			end)
			if _IsUsingController() then
				self:MoveDraggingShapeTo((BOUNDARY_X1 + BOUNDARY_X2) / 2 * IMG_SCALE, BOUNDARY_Y * IMG_SCALE)
			else
				self:MoveDraggingShapeTo(_ScreenToLocal(TheSim:GetPosition()))
			end
		end
	end
	self.default_focus = self.dragline
	self.dragline:SetFocus()
	self.dragline:FollowMouse()
	self.dragline.shape = shape
	self.dragline.rot = 1
end

function PumpkinCarvingScreen:StopDraggingShape()
	self.menu:SetClickable(true)
	self.shapemenu:SetClickable(true)

	self:ResetDefaultFocus()

	if self.dragline then
		self.dragline:Kill()
		self.dragline = nil
	end
	if self.dragfill then
		self.dragfill:Kill()
		self.dragfill = nil
	end
end

function PumpkinCarvingScreen:RotateDraggingShape(delta)
	if self.dragline then
		local numrots = SHAPE_ROTS[self.dragline.shape]
		if numrots > 1 then
			self.dragline.rot = self.dragline.rot + delta
			while self.dragline.rot > numrots do
				self.dragline.rot = self.dragline.rot - numrots
			end
			while self.dragline.rot < 1 do
				self.dragline.rot = self.dragline.rot + numrots
			end
			self.dragline:SetTexture(SHAPES_ATLAS, _ShapeTexName(self.dragline.shape, self.dragline.rot, false))
			self.dragfill:SetTexture(SHAPES_ATLAS, _ShapeTexName(self.dragline.shape, self.dragline.rot, true))
		end
	end
end

local function OnFxAnimOver(inst)
	inst.widget:Kill()
end

function PumpkinCarvingScreen:DoAddCutAt(x, y, shape, rot) --pumpkin local space
	local line = self.lineroot:AddChild(Image(SHAPES_ATLAS, _ShapeTexName(shape, rot, false)))
	line:SetScale(SHAPE_SCALE)
	line:SetPosition(x, y)

	local fill = self.fillroot:AddChild(Image(SHAPES_ATLAS, _ShapeTexName(shape, rot, true)))
	fill:SetScale(SHAPE_SCALE)
	fill:SetPosition(x, y)

	table.insert(self.cutdata, { shape = shape, rot = rot, x = x, y = y })
end

function PumpkinCarvingScreen:StampShapeAt(x, y, shape, rot) --pumpkin local space
	self:DoAddCutAt(x, y, shape, rot)
	self.dirty = true

	local fx = self.pumpkinroot:AddChild(UIAnim())
	fx:GetAnimState():SetBank("farm_plant_pumpkin")
	fx:GetAnimState():SetBuild("farm_plant_pumpkin")
	fx:GetAnimState():PlayAnimation("fx_cut")
	fx:SetScale(FX_SCALE)
	fx:SetPosition(x, y)
	fx.inst:ListenForEvent("animover", OnFxAnimOver)

	TheFrontEnd:GetSound():PlaySound("hallowednights2024/pumpkin/hole_punch")

	if self.dragline then
		self.dragline:MoveToFront()
	end
	if self.dragfill then
		self.dragfill:MoveToFront()
	end
end

function PumpkinCarvingScreen:ClearCuts()
	if #self.cutdata > 0 then
		if self.dragline then
			self.lineroot:RemoveChild(self.dragline)
			self.lineroot:KillAllChildren()
			self.lineroot:AddChild(self.dragline)
		else
			self.lineroot:KillAllChildren()
		end

		if self.dragfill then
			self.fillroot:RemoveChild(self.dragfill)
			self.fillroot:KillAllChildren()
			self.fillroot:AddChild(self.dragfill)
		else
			self.fillroot:KillAllChildren()
		end

		self.cutdata = {}
		self.dirty = true
	end
end

function PumpkinCarvingScreen:ShowWarning()
	self.warning:Show()
	self.warningbg:SetTint(unpack(WARNING_BG_TINT))
	self.warningtext:SetAlpha(1)
	self.warningtime = WARNING_DURATION
end

function PumpkinCarvingScreen:OnMouseButton(button, down, x, y) --window screen space
	if down and self.dragline then
		if button == MOUSEBUTTON_LEFT then
			x, y = _ScreenToLocal(x, y)
			if self:MoveDraggingShapeTo(x, y) then
				self:StampShapeAt(x, y, self.dragline.shape, self.dragline.rot)
			else
				TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
				if self:HasMaxCuts() then
					self:ShowWarning()
			end
			end
			return true
		elseif button == MOUSEBUTTON_RIGHT then
			self:StopDraggingShape()
			self.lastclickedbtn = nil
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			return true
		end
	end
	return false
end

function PumpkinCarvingScreen:OnControl(control, down)
	if self._base.OnControl(self, control, down) then return true end

	if down then
		if control == CONTROL_ACCEPT then
			if self.dragline then
				if _IsUsingController() then
					if self:HasMaxCuts() then
						self:ShowWarning()
						TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
					else
					local x, y = self.dragline:GetPositionXYZ()
					if _IsOnPumpkin(x, y) then
						self:StampShapeAt(x, y, self.dragline.shape, self.dragline.rot)
					else
						TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
					end
				end
				end
				return true
			end
		end
	elseif control == CONTROL_MENU_BACK or control == CONTROL_CANCEL then
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
		if self.dragline then
			self:StopDraggingShape()
			self.lastclickedbtn:SetFocus()
			self.lastclickedbtn = nil
		else
			self:Cancel()
		end
		return true
	elseif control == CONTROL_MENU_MISC_1 and not down then  
		self:ClearCuts()
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
		return true
	elseif control == CONTROL_MENU_START and not down then  
		self:SaveAndClose()
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
		return true
	elseif self.dragline then
		if control == CONTROL_SCROLLBACK then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
			self:RotateDraggingShape(-1)
			return true
		elseif control == CONTROL_SCROLLFWD then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
			self:RotateDraggingShape(1)
			return true
		end
	end
	return false
end

function PumpkinCarvingScreen:OnUpdate(dt)
	if self.warningtime > 0 then
		self.warningtime = math.max(0, self.warningtime - dt)
		if self.warningtime > 0 then
			local k = 1 - self.warningtime / WARNING_DURATION
			k = k * k
			k = 1 - k * k
			local r, g, b, a = unpack(WARNING_BG_TINT)
			self.warningbg:SetTint(r, g, b, a * k)
			self.warningtext:SetAlpha(k)
		else
			self.warning:Hide()
		end
	end

	if self.dragline and TheInput:ControllerAttached() then
		local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
		local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
		local xmag = xdir * xdir + ydir * ydir

		local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
		if xmag > deadzone * deadzone then
			local w, h = TheSim:GetScreenSize()
			if w > 0 and h > 0 then
				xmag = math.sqrt(xmag)
				xmag = (xmag - deadzone) / xmag
				xmag = xmag * xmag * TUNING.CONTROLLER_UI_CURSOR_STICK_SPEED
	
				local propscale = math.max(RESOLUTION_X / w, RESOLUTION_Y / h)
				local x, y = self.dragline:GetPositionXYZ()
				self:MoveDraggingShapeTo(_ClampToPumpkin(x + xdir * xmag * propscale, y + ydir * xmag * propscale))
			end
		end
	end
end

function PumpkinCarvingScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
	    
	--controller prompts for when you have a shape on your cursor
	if self.dragline then
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_SCROLLBACK).." "..STRINGS.UI.HELP.ROTATE_LEFT)
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_SCROLLFWD).." "..STRINGS.UI.HELP.ROTATE_RIGHT)
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT).." "..STRINGS.UI.PUMPKIN_CARVING_POPUP.CARVE)
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL).." "..STRINGS.UI.HELP.BACK)
	else
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.PUMPKIN_CARVING_POPUP.CANCEL)
	end

	table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_MISC_1) .. " " .. STRINGS.UI.PUMPKIN_CARVING_POPUP.RESET)
	table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_START) .. " " .. STRINGS.UI.PUMPKIN_CARVING_POPUP.SET)
	
	return table.concat(t, "  ")
end

return PumpkinCarvingScreen
