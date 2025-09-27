local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Menu = require "widgets/menu"
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")
local Widget = require("widgets/widget")

local SnowmanDecoratable = require("components/snowmandecoratable")

local SCREEN_OFFSET = -0.38 * RESOLUTION_X
local CANVAS_MAX_X = 470
local IMG_SCALE = 0.75
local FX_SCALE = 0.5
local INVALID_ALPHA = 0.4
local WARNING_BG_TINT = { 0, 0, 0, 0.75 }
local WARNING_DURATION = 1

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

local SnowmanDecoratingScreen = Class(Screen, function(self, owner, target, obj)
    self.owner = owner
    Screen._ctor(self, "SnowmanDecoratingScreen")

	self.root = self:AddChild(Widget("root"))
	self.root:SetVAnchor(ANCHOR_MIDDLE)
	self.root:SetHAnchor(ANCHOR_MIDDLE)
	self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

	local bg = self.root:AddChild(Image("images/snowman.xml", "snowman_bg.tex"))
	bg:SetScale(0.8)
	bg:SetPosition(-200, 0)
	bg:SetTint(1, 1, 1, 0.76)

	local buttons =
	{
		{ text = STRINGS.UI.SNOWMAN_DECORATING_POPUP.CANCEL, cb = function() self:Cancel() end },
		{ text = STRINGS.UI.SNOWMAN_DECORATING_POPUP.SET, cb = function() self:SaveAndClose() end },
	}
	local spacing = 70
	self.menu = self.root:AddChild(Menu(buttons, spacing, false, "carny_long", nil, 30))
	self.menu:SetMenuIndex(2)
	self.menu:SetPosition(493, -260, 0)

	-- hide the menu if the player is using a controller; we'll control this with button presses that are listed in the helpbar
	if _IsUsingController() then
		self.menu:Hide()
		self.menu:Disable()
	end

	self.snowmanroot = self.root:AddChild(Widget("snowmanroot"))
	self.snowmanroot:SetScale(IMG_SCALE)

	self.snowballsroot = self.snowmanroot:AddChild(Widget("snowballsroot"))
	self.decorroot = self.snowmanroot:AddChild(Widget("decorroot"))

	self.warning = self.root:AddChild(Widget("warningroot"))
	self.warning:SetClickable(false)
	self.warning:Hide()
	self.warningtime = 0

	self.warningbg = self.warning:AddChild(Image("images/global.xml", "square.tex"))
	self.warningbg:SetTint(unpack(WARNING_BG_TINT))
	self.warningbg:ScaleToSize(RESOLUTION_X, 80)

	self.warningtext = self.warning:AddChild(Text(HEADERFONT, 30, STRINGS.UI.SNOWMAN_DECORATING_POPUP.MAX_DECOR))

	self.stacks = {}
	self.decordata = {}
	self.dirtyindex = 1
	self.maxdecor = 0
	self.obj = obj

	if target and target.components.snowmandecoratable then --component exists on clients
		local laststackid = SnowmanDecoratable.STACK_IDS[target.components.snowmandecoratable:GetSize()]
		local laststackdata = SnowmanDecoratable.STACK_DATA[laststackid]
		local height = 0

		local snowball = self.snowballsroot:AddChild(UIAnim())
		snowball:GetAnimState():SetBank("snowball")
		snowball:GetAnimState():SetBuild("snowball")
		snowball:GetAnimState():PlayAnimation("ground_"..laststackdata.name)
		snowball.stackdata = laststackdata
		snowball.xpos = 0
		snowball.ypos = 0
		table.insert(self.stacks, snowball)

		self.maxdecor = self.maxdecor + TUNING.SNOWMAN_MAX_DECOR[laststackid] or 0

		local stacks, stackoffsets = target.components.snowmandecoratable:GetStacks()
		for i, v in ipairs(stacks) do
			local stackdata = SnowmanDecoratable.STACK_DATA[v]
			if stackdata then
				height = height + laststackdata.heights[v]

				snowball = self.snowballsroot:AddChild(UIAnim())
				snowball:GetAnimState():SetBank("snowball")
				snowball:GetAnimState():SetBuild("snowball")
				snowball:GetAnimState():PlayAnimation((v > laststackid and "stack_clean_" or "stack_")..stackdata.name)
				snowball.xpos = SnowmanDecoratable.CalculateStackOffset(stackdata.r, stackoffsets[i])
				snowball.ypos = height
				snowball:SetPosition(snowball.xpos, height)
				snowball.stackdata = stackdata
				table.insert(self.stacks, snowball)

				self.maxdecor = self.maxdecor + math.max(5, (TUNING.SNOWMAN_MAX_DECOR[v] or 0) - 5 * i)

				laststackid = v
				laststackdata = stackdata
			end
		end

		height = height + laststackdata.heights[1]
		self.snowmanroot:SetPosition(0, -height / 2 * IMG_SCALE)

		local decordata = target.components.snowmandecoratable:GetDecorData()
		decordata = string.len(decordata) > 0 and DecodeAndUnzipString(decordata) or nil
		if type(decordata) == "table" then
			for i = 1, #decordata, 5 do
				local itemhash = decordata[i]
				local itemdata = SnowmanDecoratable.GetItemData(itemhash)
				local rot = decordata[i + 1]
				local flip = decordata[i + 2] == 1
				local x = decordata[i + 3]
				local y = decordata[i + 4]
				if itemdata and rot and x and y then
					y = -y
					if self:IsOnSnowman(x, y, 1) then
						self:DoAddItemAt(x, y, itemhash, itemdata, rot, flip)
					end
				end
			end
			self.dirtyindex = #self.decordata + 1
		end
	end

	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)

	self.autopausedelay = 0.2
	--SetAutopaused(true)
    TheFrontEnd:PushShowHelpTextForEverything()

	if obj and obj:IsValid() then
		local inventoryitem = obj.replica.inventoryitem
		if inventoryitem and inventoryitem:IsGrandOwner(self.owner) then
			self:StartDraggingItem(obj)
		end
	end
end)

function SnowmanDecoratingScreen:ScreenToLocal(x, y)
	local w, h = TheSim:GetScreenSize()
	if w > 0 and h > 0 then
		local propscale = math.max(RESOLUTION_X / w, RESOLUTION_Y / h)
		local x1, y1 = self.snowmanroot:GetPositionXYZ()
		return ((x - w / 2) * propscale - x1) / IMG_SCALE, ((y - h / 2) * propscale - y1) / IMG_SCALE
	end
	return 0, 0
end

--keep in sync @snowmandecoratable.lua
local function _IsOnSnowball(stackdata, x0, y0, x, y, padding, isbase)
	local x1 = x0
	local y1 = y0 + stackdata.ycenter
	local r = stackdata.r + padding
	local dx = x - x1
	local dy = (y - y1) / stackdata.yscale
	local dsq = dx * dx + dy * dy
	return dsq < r * r and not (isbase and y < 0), dsq
end

--keep in sync @snowmandecoratable.lua
function SnowmanDecoratingScreen:IsOnSnowman(x, y, padding)
	for i, v in ipairs(self.stacks) do
		if _IsOnSnowball(v.stackdata, v.xpos, v.ypos, x, y, padding or 0, i == 1) then
			return true
		end
	end
	return false
end

function SnowmanDecoratingScreen:ClampToSnowman(x, y)
	local closest
	local closestdsq = math.huge
	for i, v in ipairs(self.stacks) do
		local success, dsq = _IsOnSnowball(v.stackdata, v.xpos, v.ypos, x, y, 0, i == 1)
		if success then
			return x, y
		elseif dsq and dsq < closestdsq then
			closestdsq = dsq
			closest = v
		end
	end
	if closest then
		local stackdata = closest.stackdata
		local x1 = closest.xpos
		local y1 = closest.ypos + stackdata.ycenter
		local r = stackdata.r - 0.00001
		local dx = x - x1
		local dy = (y - y1) / stackdata.yscale
		local dsq = dx * dx + dy * dy
		if dsq > r * r then
			local k = r / math.sqrt(dsq)
			x = x1 + dx * k
			y = y1 + dy * k * stackdata.yscale
		end
		if closest == self.stacks[1] and y < 0 then
			y = 0
		end
	end
	return x, y
end

function SnowmanDecoratingScreen:OnDestroy()
	if self.autopausedelay == nil then
		SetAutopaused(false)
	end
    TheFrontEnd:PopShowHelpTextForEverything()

	self:StopDraggingItem()

	POPUPS.SNOWMANDECORATING:Close(self.owner)

	TheCamera:PushScreenHOffset(self, SCREEN_OFFSET)
	self._base.OnDestroy(self)
end

function SnowmanDecoratingScreen:Cancel()
	self:StopDraggingItem()
	POPUPS.SNOWMANDECORATING:Close(self.owner)
	TheFrontEnd:PopScreen(self)
end

function SnowmanDecoratingScreen:SaveAndClose()
	if #self.decordata < self.dirtyindex then
		self:Cancel()
		return
	end
	self:StopDraggingItem()
	local data = {}
	for i = self.dirtyindex, #self.decordata do
		local v = self.decordata[i]
		SnowmanDecoratable.AddDecorData(data, v.itemhash, v.rot, v.flip, math.floor(0.5 + v.x), math.floor(0.5 - v.y))
	end
	POPUPS.SNOWMANDECORATING:Close(self.owner, ZipAndEncodeString(data), self.obj)
	TheFrontEnd:PopScreen(self)
end

function SnowmanDecoratingScreen:AutoClose()
	self.autoclosedelay = 0.5
end

function SnowmanDecoratingScreen:HasMaxDecor()
	return #self.decordata >= self.maxdecor
end

function SnowmanDecoratingScreen:MoveDraggingItemTo(x, y)
	self.dragitem:SetPosition(x, y)

	if not self:HasMaxDecor() and self:IsOnSnowman(x, y) then
		self.dragitem:GetAnimState():SetMultColour(1, 1, 1, 1)
		self.dragitem:Show()
		return true
	end

	self.dragitem:GetAnimState():SetMultColour(1, 1, 1, INVALID_ALPHA)
	if x < CANVAS_MAX_X then
		self.dragitem:Show()
	else
		self.dragitem:Hide()
	end
	return false
end

function SnowmanDecoratingScreen:StartDraggingItem(obj)
	self:StopDraggingItem()

	local itemhash = hash(obj.prefab)
	local itemdata = SnowmanDecoratable.GetItemData(itemhash)
	if itemdata == nil then
		return
	end
	self.dragitem = self.decorroot:AddChild(UIAnim())
	self.dragitem:GetAnimState():SetBank(itemdata.bank)
	self.dragitem:GetAnimState():SetBuild(itemdata.build)
	self.dragitem:GetAnimState():PlayAnimation(itemdata.anim)
	self.dragitem:GetAnimState():Pause()
	self.dragitem:SetClickable(false)

	--Override so we can convert to local space
	self.dragitem.FollowMouse = function()
		if self.dragitem.followhandler == nil then
			self.dragitem.followhandler = TheInput:AddMoveHandler(function(x, y)
				self:MoveDraggingItemTo(self:ScreenToLocal(x, y))
			end)
			if not _IsUsingController() then
				self:MoveDraggingItemTo(self:ScreenToLocal(TheSim:GetPosition()))
			elseif #self.stacks > 0 then
				local stack = self.stacks[math.ceil((#self.stacks + 1) / 2)]
				local stackdata = stack.stackdata
				self:MoveDraggingItemTo(0, stack.ypos + stackdata.ycenter)
			else
				self:MoveDraggingItemTo(0, 0)
			end
		end
	end
	self.dragitem:FollowMouse()
	self.dragitem.obj = obj
	self.dragitem.itemhash = itemhash
	self.dragitem.itemdata = itemdata
	self.dragitem.rot = 1
end

function SnowmanDecoratingScreen:StopDraggingItem()
	if self.dragitem then
		self.dragitem:Kill()
		self.dragitem = nil
	end
end

function SnowmanDecoratingScreen:CanRotateDraggingItem()
	return self.dragitem ~= nil and self.dragitem.shown and self.dragitem:GetAnimState():GetCurrentAnimationNumFrames() > 1
end

function SnowmanDecoratingScreen:RotateDraggingItem(delta)
	if self.dragitem then
		local numrots = self.dragitem:GetAnimState():GetCurrentAnimationNumFrames()
		self.dragitem.rot = self.dragitem.rot + delta
		while self.dragitem.rot > numrots do
			self.dragitem.rot = self.dragitem.rot - numrots
		end
		while self.dragitem.rot < 1 do
			self.dragitem.rot = self.dragitem.rot + numrots
		end
		self.dragitem:GetAnimState():SetFrame(self.dragitem.rot - 1)
	end
end

function SnowmanDecoratingScreen:FlipDraggingItem()
	if self.dragitem then
		self.dragitem.flip = not self.dragitem.flip
		self.dragitem:GetAnimState():PlayAnimation(self.dragitem.itemdata.anim..(self.dragitem.flip and self.dragitem.itemdata.canflip and "_flip" or ""))
		local numframes = self.dragitem:GetAnimState():GetCurrentAnimationNumFrames()
		self.dragitem.rot = ((numframes - self.dragitem.rot + 1) % numframes) + 1
		self.dragitem:GetAnimState():SetFrame(self.dragitem.rot - 1)
		self.dragitem:GetAnimState():Pause()
	end
end

local function OnFxAnimOver(inst)
	inst.widget:Kill()
end

function SnowmanDecoratingScreen:DoAddItemAt(x, y, itemhash, itemdata, rot, flip) --snowball local space
	local decor = self.decorroot:AddChild(UIAnim())
	decor:GetAnimState():SetBank(itemdata.bank)
	decor:GetAnimState():SetBuild(itemdata.build)
	decor:GetAnimState():PlayAnimation(itemdata.anim..(flip and itemdata.canflip and "_flip" or ""))
	decor:GetAnimState():SetFrame(rot - 1)
	decor:GetAnimState():Pause()
	decor:SetPosition(x, y)

	table.insert(self.decordata, { itemhash = itemhash, rot = rot, flip = flip or nil, x = x, y = y })

	return decor
end

function SnowmanDecoratingScreen:PlaceItemAt(x, y, itemhash, itemdata, rot, flip) --snowball local space
	local fx = self:DoAddItemAt(x, y, itemhash, itemdata, rot, flip)
	fx:ScaleTo(1.5, 1, 0.5)

	fx = self.snowmanroot:AddChild(UIAnim())
	fx:GetAnimState():SetBank("snowball")
	fx:GetAnimState():SetBuild("snowball")
	fx:GetAnimState():PlayAnimation("fx_place")
	fx:SetScale(FX_SCALE)
	fx:SetPosition(x, y)
	fx.inst:ListenForEvent("animover", OnFxAnimOver)

	TheFrontEnd:GetSound():PlaySound("meta5/snowman/snowman_decorate_UI")

	if self.dragitem then
		local inventory = self.owner and self.owner.replica.inventory or nil
		if inventory and inventory:Has(self.dragitem.obj.prefab, #self.decordata - self.dirtyindex + 2) then
			self.dragitem:MoveToFront()
		else
			self:StopDraggingItem()
		end
	end
end

function SnowmanDecoratingScreen:ShowWarning()
	self.warning:Show()
	self.warningbg:SetTint(unpack(WARNING_BG_TINT))
	self.warningtext:SetAlpha(1)
	self.warningtime = WARNING_DURATION
end

function SnowmanDecoratingScreen:TryPlacingDecor()
	if self:HasMaxDecor() then
		self:ShowWarning()
		TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
	else
		local x, y = self.dragitem:GetPositionXYZ()
		if self:IsOnSnowman(x, y) then
			self:PlaceItemAt(x, y, self.dragitem.itemhash, self.dragitem.itemdata, self.dragitem.rot, self.dragitem.flip)
		else
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
		end
	end
end

function SnowmanDecoratingScreen:OnControl(control, down)
	if self._base.OnControl(self, control, down) then return true end

	if down then
		if self.dragitem and self.dragitem.shown then
			if control == CONTROL_SECONDARY then
				if self.dragitem.itemdata.canflip then
					TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
					self:FlipDraggingItem()
				else
					TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
				end
				return true
			elseif control == CONTROL_ACCEPT then
				--CONTROL_PRIMARY is also converted to CONTROL_ACCEPT in frontend.lua
				self:TryPlacingDecor()
				return true
			elseif control == CONTROL_MENU_L2 or control == CONTROL_MENU_R2 then
				if self.dragitem.itemdata.canflip then
					TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
					self:FlipDraggingItem()
				else
					TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_negative")
				end
				return true
			elseif control == CONTROL_SCROLLBACK or control == CONTROL_SCROLLFWD then
				if _IsUsingController() and self:CanRotateDraggingItem() then
					local t = GetStaticTime()
					if self.controller_rotate_t == nil or self.controller_rotate_t < t then
						TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
						self:RotateDraggingItem(control == CONTROL_SCROLLBACK and -1 or 1)
						if self.controller_rotate_t == nil or t - self.controller_rotate_t > 0.25 then
							--delay on first press b4 starting to repeat
							self.controller_rotate_t = t + 0.2
						else
							--repeating (just a tiny delay in case we trigger from duplicate control mappings on the same frame)
							self.controller_rotate_t = t + 0.001
						end
					end
					return true
				end
			end
		end
	else
		self.controller_rotate_t = nil

		if control == CONTROL_MENU_BACK or control == CONTROL_CANCEL then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			self:Cancel()
			return true
		elseif control == CONTROL_MENU_START then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
			self:SaveAndClose()
			return true
		elseif control == CONTROL_SCROLLBACK or control == CONTROL_SCROLLFWD then
			if not _IsUsingController() and self:CanRotateDraggingItem() then
				TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
				self:RotateDraggingItem(control == CONTROL_SCROLLBACK and -1 or 1)
				return true
			end
		end
	end
	return false
end

function SnowmanDecoratingScreen:OnUpdate(dt)
	if self.autoclosedelay then
		if self.autoclosedelay > dt then
			self.autoclosedelay = self.autoclosedelay - dt
		else
			self:SaveAndClose()
			return
		end
	end

	if self.autopausedelay then
		if self.autopausedelay > dt then
			self.autopausedelay = self.autopausedelay - dt
		else
			self.autopausedelay = nil
			SetAutopaused(true)
		end
	end

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

	if self.dragitem and TheInput:ControllerAttached() then
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
				local x, y = self.dragitem:GetPositionXYZ()
				self:MoveDraggingItemTo(self:ClampToSnowman(x + xdir * xmag * propscale / IMG_SCALE, y + ydir * xmag * propscale / IMG_SCALE))
			end
		end
	end
end

function SnowmanDecoratingScreen:HasExclusiveHelpText()
    return not _IsUsingController()
end

function SnowmanDecoratingScreen:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}

	--controller prompts for when you have a shape on your cursor
	if self.dragitem and self.dragitem.shown then
		if self:CanRotateDraggingItem() then
			table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_SCROLLBACK).." "..STRINGS.UI.HELP.ROTATE_LEFT)
			table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_SCROLLFWD).." "..STRINGS.UI.HELP.ROTATE_RIGHT)
		end
		if self.dragitem.itemdata.canflip then
            if _IsUsingController() then
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_L2).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.FLIP)
                table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_R2).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.FLIP)
            else
				table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_SECONDARY).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.FLIP)
            end
		end
        if _IsUsingController() then
            table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.PLACE)
		else
			table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_PRIMARY).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.PLACE)
        end
	end
    if _IsUsingController() then
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.CANCEL)
		table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MENU_START).." "..STRINGS.UI.SNOWMAN_DECORATING_POPUP.SET)
    end

	return table.concat(t, "  ")
end

return SnowmanDecoratingScreen
