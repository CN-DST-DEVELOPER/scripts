require "events"
local Text = require "widgets/text"

--V2C: WELL! this should've been local... =(
--     TheInput is the correct global to reference
--     At this point, gotta leave it in case MODs are using the wrong one =/

Input = Class(function(self)
    self.onkey = EventProcessor()     -- all keys, down and up, with key param
    self.onkeyup = EventProcessor()   -- specific key up, no parameters
    self.onkeydown = EventProcessor() -- specific key down, no parameters
    self.onmousebutton = EventProcessor()

    self.position = EventProcessor()
    self.oncontrol = EventProcessor()
    self.ontextinput = EventProcessor()
    self.ongesture = EventProcessor()

    self.hoverinst = nil
    self.enabledebugtoggle = true

    self.mouse_enabled = IsNotConsole() and not TheNet:IsDedicated()

    self.overridepos = nil
    self.controllerid_cached = nil

    self:DisableAllControllers()
end)

function Input:DisableAllControllers()
    for i = 1, TheInputProxy:GetInputDeviceCount() - 1 do
        if TheInputProxy:IsInputDeviceEnabled(i) and TheInputProxy:IsInputDeviceConnected(i) then
            TheInputProxy:EnableInputDevice(i, false)
        end
    end
end

function Input:EnableAllControllers()
    for i = 1, TheInputProxy:GetInputDeviceCount() - 1 do
        if TheInputProxy:IsInputDeviceConnected(i) then
            TheInputProxy:EnableInputDevice(i, true)
        end
    end
end

function Input:IsControllerLoggedIn(controller)
    if IsXB1() then
        return TheInputProxy:IsControllerLoggedIn(controller)
    end
    return true
end

function Input:LogUserAsync(controller,cb)
    if IsXB1() then
        TheInputProxy:LogUserAsync(controller,cb)
    else
        cb(true)
    end
end

function Input:LogSecondaryUserAsync(controller,cb)
    if IsXB1() then
        TheInputProxy:LogSecondaryUserAsync(controller,cb)
    else
        cb(true)
    end
end

function Input:EnableMouse(enable)
    self.mouse_enabled = enable and IsNotConsole() and not TheNet:IsDedicated()
end

function Input:ClearCachedController()
    self.controllerid_cached = nil
end

function Input:CacheController()
    self.controllerid_cached = IsNotConsole() and (TheInputProxy:GetLastActiveControllerIndex() or 0) or nil
    return self.controllerid_cached
end

function Input:TryRecacheController()
    return self.controllerid_cached ~= nil and self.controllerid_cached ~= self:CacheController()
end

function Input:GetControllerID()
    return self.controllerid_cached or TheInputProxy:GetLastActiveControllerIndex() or 0
end

function Input:ControllerAttached()
    if self.controllerid_cached ~= nil then
        return self.controllerid_cached > 0
    end
    --Active means connected AND enabled
    return IsConsole() or TheInputProxy:IsAnyControllerActive()
end

function Input:ControllerConnected()
    --V2C: didn't cache this one because it's not used regularly
    return IsConsole() or TheInputProxy:IsAnyControllerConnected()
end

-- Get a list of connected input devices and their ids
function Input:GetInputDevices()
    local devices = {}
    for i = 0, TheInputProxy:GetInputDeviceCount() - 1 do
        if TheInputProxy:IsInputDeviceConnected(i) then
            local device_type = TheInputProxy:GetInputDeviceType(i)
            table.insert(devices, { text = STRINGS.UI.CONTROLSSCREEN.INPUT_NAMES[device_type + 1], data = i })
        end
    end
    return devices
end

function Input:AddTextInputHandler(fn)
    return self.ontextinput:AddEventHandler("text", fn)
end

function Input:AddKeyUpHandler(key, fn)
    return self.onkeyup:AddEventHandler(key, fn)
end

function Input:AddKeyDownHandler(key, fn)
    return self.onkeydown:AddEventHandler(key, fn)
end

function Input:AddKeyHandler(fn)
    return self.onkey:AddEventHandler("onkey", fn)
end

function Input:AddMouseButtonHandler(fn)
    return self.onmousebutton:AddEventHandler("onmousebutton", fn)
end

function Input:AddMoveHandler(fn)
    return self.position:AddEventHandler("move", fn)
end

function Input:AddControlHandler(control, fn)
    return self.oncontrol:AddEventHandler(control, fn)
end

function Input:AddGeneralControlHandler(fn)
    return self.oncontrol:AddEventHandler("oncontrol", fn)
end

function Input:AddControlMappingHandler(fn)
    return self.oncontrol:AddEventHandler("onmap", fn)
end

function Input:AddGestureHandler(gesture, fn)
    return self.ongesture:AddEventHandler(gesture, fn)
end

function Input:UpdatePosition(x, y)
    if self.mouse_enabled then
        self.position:HandleEvent("move", x, y)
    end
end

-- Is for all the button devices (mouse, joystick (even the analog parts), keyboard as well, keyboard
ValidateLineNumber(162)
function Input:OnControl(control, digitalvalue, analogvalue)
    if (self.mouse_enabled or
        (control ~= CONTROL_PRIMARY and control ~= CONTROL_SECONDARY)) and
        not TheFrontEnd:OnControl(control, digitalvalue) then
        self.oncontrol:HandleEvent(control, digitalvalue, analogvalue)
        self.oncontrol:HandleEvent("oncontrol", control, digitalvalue, analogvalue)
    end
end
ValidateLineNumber(171)

function Input:OnMouseMove(x, y)
    if self.mouse_enabled then
        TheFrontEnd:OnMouseMove(x, y)
    end
end

function Input:OnMouseButton(button, down, x, y)
    if self.mouse_enabled then
        TheFrontEnd:OnMouseButton(button, down, x,y)
        self.onmousebutton:HandleEvent("onmousebutton", button, down, x, y)
    end
end

function Input:OnRawKey(key, down)
    self.onkey:HandleEvent("onkey", key, down)
    if down then
        self.onkeydown:HandleEvent(key)
    else
        self.onkeyup:HandleEvent(key)
    end
end

function Input:OnText(text)
    self.ontextinput:HandleEvent("text", text)
end

-- Specifically for floating text input on Steam Deck
function Input:OnFloatingTextInputDismissed()			-- called from C++
	if self.vk_text_widget then
		self.vk_text_widget:OnVirtualKeyboardClosed()
		self.vk_text_widget = nil
	end
end

function Input:AbortVirtualKeyboard(for_text_widget)
	if for_text_widget ~= nil and self.vk_text_widget == for_text_widget then
		self.vk_text_widget = nil
		TheInputProxy:CloseVirtualKeyboard()
	end
end

function Input:OpenVirtualKeyboard(text_widget)
	if not self.vk_text_widget then
		local x, y = text_widget.inst.UITransform:GetWorldPosition()
		local w, h = text_widget:GetRegionSize()

		--local _split = text_widget:GetString():split(",")
		--x = _split[1] ~= nil and tonumber(_split[1]) or 0
		--y = _split[2] ~= nil and tonumber(_split[2]) or 0
		--print("_split", x, y)

		if TheInputProxy:OpenVirtualKeyboard(x, y, w, h, self.allow_newline) then	
			self.vk_text_widget = text_widget
			return true
		end
	end

	return false
end

function Input:OnGesture(gesture)
    self.ongesture:HandleEvent(gesture)
end

function Input:OnControlMapped(deviceId, controlId, inputId, hasChanged)
    self.oncontrol:HandleEvent("onmap", deviceId, controlId, inputId, hasChanged)
end

function Input:OnFrameStart()
    self.hoverinst = nil
    self.hovervalid = false
end

function Input:GetScreenPosition()
    local x, y = TheSim:GetPosition()
    return Vector3(x, y, 0)
end

function Input:GetWorldPosition()
    local x, y, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
    return x ~= nil and y ~= nil and z ~= nil and Vector3(x, y, z) or nil
end

function Input:GetWorldXZWithHeight(height)
	local x, y = TheSim:GetPosition()
	local z
	x, y, z = TheSim:ProjectScreenPos(x, y, height)
	return x, z
end

function Input:GetAllEntitiesUnderMouse()
    return self.mouse_enabled and self.entitiesundermouse or {}
end

function Input:GetWorldEntityUnderMouse()
    return self.mouse_enabled and
        self.hoverinst ~= nil and
        self.hoverinst.entity:IsValid() and
        self.hoverinst.entity:IsVisible() and
        self.hoverinst.Transform ~= nil and
        self.hoverinst or nil
end

function Input:EnableDebugToggle(enable)
    self.enabledebugtoggle = enable
end

function Input:IsDebugToggleEnabled()
    return self.enabledebugtoggle
end

function Input:GetHUDEntityUnderMouse()
    return self.mouse_enabled and
        self.hoverinst ~= nil and
        self.hoverinst.entity:IsValid() and
        self.hoverinst.entity:IsVisible() and
        self.hoverinst.Transform == nil and
        self.hoverinst or nil
end

function Input:IsMouseDown(button)
    return TheSim:GetMouseButtonState(button)
end

function Input:IsKeyDown(key)
    return TheSim:IsKeyDown(key)
end

local RemapTo_CONTROL_INVENTORY =
{
	[0] = CONTROL_INVENTORY_UP,
	[1] = CONTROL_INVENTORY_DOWN,
	[2] = CONTROL_INVENTORY_LEFT,
	[3] = CONTROL_INVENTORY_RIGHT,
}

local RemapTo_CONTROL_INVENTORY_ACTIONS =
{
	[0] = CONTROL_INVENTORY_EXAMINE,
	[1] = CONTROL_INVENTORY_DROP,
	[2] = CONTROL_INVENTORY_USEONSCENE,
	[3] = CONTROL_INVENTORY_USEONSELF,
}

local function IsVCtrlCamera(control)	return control >= VIRTUAL_CONTROL_CAMERA_ZOOM_IN	and control <= VIRTUAL_CONTROL_CAMERA_ROTATE_RIGHT	end
local function IsVCtrlAiming(control)	return control >= VIRTUAL_CONTROL_AIM_UP			and control <= VIRTUAL_CONTROL_AIM_RIGHT			end
local function IsVCtrlInvNav(control)	return control >= VIRTUAL_CONTROL_INV_UP			and control <= VIRTUAL_CONTROL_INV_RIGHT			end
local function IsVCtrlInvAct(control)	return control >= VIRTUAL_CONTROL_INV_ACTION_UP		and control <= VIRTUAL_CONTROL_INV_ACTION_RIGHT		end
local function IsVCtrlStrafe(control)	return control >= VIRTUAL_CONTROL_STRAFE_UP			and control <= VIRTUAL_CONTROL_STRAFE_RIGHT			end

local function IsCamAndInvCtrlScheme1(scheme) return scheme < 2 or scheme > 7 end

local function IsTwinStickAiming(player, scheme)
	if player.components.playercontroller and player.components.playercontroller:IsTwinStickAiming() then
		if scheme < 4 or scheme > 7 then
			return player.components.playercontroller:IsAOETargeting()
		end
		return true
	end
	return false
end

local function IsStrafing(player)
	return player.components.strafer and player.components.strafer:IsAiming()
end

function Input:ResolveVirtualControls(control)
	if control == nil then
		return
	elseif control < VIRTUAL_CONTROL_START then
		if control == CONTROL_CAM_AND_INV_MODIFIER then
			--Modifier button is not used in control scheme 1
			local scheme = self:GetActiveControlScheme(CONTROL_SCHEME_CAM_AND_INV)
			return not IsCamAndInvCtrlScheme1(scheme) and control or nil
		end
		return control
	end

	local player = ThePlayer
	if player and player.HUD and player.HUD:IsSpellWheelOpen() then
		--Spell wheel is treated as "ishudblocking" in playercontroller,
		--which allows some controls to continue working, but we do want
		--to block all virtual directional controls instead.
		return
	end

	local scheme = self:GetActiveControlScheme(CONTROL_SCHEME_CAM_AND_INV)

	--Scheme 1 is classic style, where we have no modifier button, and everyhting is remappable.
	if IsCamAndInvCtrlScheme1(scheme) then
		if IsVCtrlInvNav(control) then
			--Handle CONTROL_INVENTORY priorities
			if player and not (player.HUD and player.HUD:IsCraftingOpen()) then
				if IsTwinStickAiming(player, scheme) or IsStrafing(player) then
					return
				end
			end
			return RemapTo_CONTROL_INVENTORY[control - VIRTUAL_CONTROL_INV_UP]
		elseif IsVCtrlInvAct(control) then
			return RemapTo_CONTROL_INVENTORY_ACTIONS[control - VIRTUAL_CONTROL_INV_ACTION_UP]
		elseif IsVCtrlAiming(control) then
			--Twin stick aiming outside of AOE targeting is only supported by schemes 4 to 7
			if not (player and player.components.playercontroller and player.components.playercontroller:IsAOETargeting()) then
				return
			end
			--Handle CONTROL_INVENTORY priorities
			if player and player.HUD and player.HUD:IsCraftingOpen() then
				return
			end
			return RemapTo_CONTROL_INVENTORY[control - VIRTUAL_CONTROL_AIM_UP]
		elseif IsVCtrlStrafe(control) then
			--Handle CONTROL_INVENTORY priorities
			if player and player.HUD and player.HUD:IsCraftingOpen() then
				return
			end
			return RemapTo_CONTROL_INVENTORY[control - VIRTUAL_CONTROL_STRAFE_UP]
		end
		return
	end

	--Now handle all the new schemes (2 to 7) for each control category

	if IsVCtrlCamera(control) then
		--R.Stick for all schemes, modifier button for even number schemes
		local ismodified = TheSim:GetDigitalControl(CONTROL_CAM_AND_INV_MODIFIER)
		local needsmodifier = bit.band(scheme, 1) == 0
		if ismodified ~= needsmodifier then
			return
		end
		--Handle unmodified R.Stick priorities
		if not needsmodifier and player then
			if scheme ~= 5 and scheme ~= 7 and IsTwinStickAiming(player, scheme) or IsStrafing(player) then
				return
			end
		end
		return control - VIRTUAL_CONTROL_CAMERA_ZOOM_IN + CONTROL_PRESET_RSTICK_UP
	elseif IsVCtrlInvNav(control) then
		--R.Stick for 2 and 3, DPad for 4 to 7, modifier button for 3 to 5
		if scheme <= 3 and player.HUD and player.HUD:IsControllerInventoryOpen() then
			--In controller inventory screen, we can ignore R.stick modifier
			return control - VIRTUAL_CONTROL_INV_UP + CONTROL_PRESET_RSTICK_UP
		end
		local ismodified = TheSim:GetDigitalControl(CONTROL_CAM_AND_INV_MODIFIER)
		local needsmodifier = scheme >= 3 and scheme <= 5
		if ismodified ~= needsmodifier then
			return
		elseif scheme <= 3 then
			--Handle unmodified R.Stick priorities
			if not needsmodifier and player then
				if not (player.HUD and player.HUD:IsCraftingOpen()) then
					if IsTwinStickAiming(player, scheme) or IsStrafing(player) then
						return
					end
				end
			end
			return control - VIRTUAL_CONTROL_INV_UP + CONTROL_PRESET_RSTICK_UP
		else
			return control - VIRTUAL_CONTROL_INV_UP + CONTROL_PRESET_DPAD_UP
		end
	elseif IsVCtrlInvAct(control) then
		--Classic mapping for 2 and 3, DPad for 4 to 7, modifier button for 6 and 7
		if scheme <= 3 then
			return RemapTo_CONTROL_INVENTORY_ACTIONS[control - VIRTUAL_CONTROL_INV_ACTION_UP]
		end
		local ismodified = TheSim:GetDigitalControl(CONTROL_CAM_AND_INV_MODIFIER)
		local needsmodifier = scheme == 6 or scheme == 7
		if ismodified ~= needsmodifier then
			return
		else
			return control - VIRTUAL_CONTROL_INV_ACTION_UP + CONTROL_PRESET_DPAD_UP
		end
	elseif IsVCtrlAiming(control) then
		--R.Stick for all schemes, modifier button for 5 and 7
		local ismodified = TheSim:GetDigitalControl(CONTROL_CAM_AND_INV_MODIFIER)
		local needsmodifier = scheme == 5 or scheme == 7
		if ismodified ~= needsmodifier then
			return
		end
		--Twin stick aiming outside of AOE targeting is only supported by schemes 4 to 7
		if scheme <= 3 and not (player and player.components.playercontroller and player.components.playercontroller:IsAOETargeting()) then
			return
		end
		--Handle unmodified R.Stick priorities
		if not needsmodifier and player then
			if scheme == 2 and player.HUD and player.HUD:IsCraftingOpen() then
				return
			end
		end
		return control - VIRTUAL_CONTROL_AIM_UP + CONTROL_PRESET_RSTICK_UP
	elseif IsVCtrlStrafe(control) then
		--Unmodified R.Stick for all schemes
		local ismodified = TheSim:GetDigitalControl(CONTROL_CAM_AND_INV_MODIFIER)
		local needsmodifier = false
		if ismodified ~= needsmodifier then
			return
		end
		--Handle unmodified R.Stick priorities
		if not needsmodifier and player then
			if scheme == 2 and player.HUD and player.HUD:IsCraftingOpen() then
				return
			end
		end
		return control - VIRTUAL_CONTROL_STRAFE_UP + CONTROL_PRESET_RSTICK_UP
	end
end

function Input:IsControlPressed(control)
	control = self:ResolveVirtualControls(control)
	return control ~= nil and TheSim:GetDigitalControl(control)
end

function Input:GetAnalogControlValue(control)
	control = self:ResolveVirtualControls(control)
	return control and TheSim:GetAnalogControl(control) or 0
end

function Input:GetActiveControlScheme(schemeId)
	--V2C: This check is simplified (assumes all control schemes are for controllers only).
	--     It's also unlikely that we'd ever need to set up control schemes for kybd/mouse.
	return self:ControllerAttached() and Profile:GetControlScheme(schemeId) or 1
end

function Input:SupportsControllerFreeAiming()
	local scheme = self:GetActiveControlScheme(CONTROL_SCHEME_CAM_AND_INV)
	return scheme >= 4 and scheme <= 7
end

function Input:SupportsControllerFreeCamera()
	local scheme = self:GetActiveControlScheme(CONTROL_SCHEME_CAM_AND_INV)
	return scheme >= 2 and scheme <= 7
end

function Input:IsPasteKey(key)
    if key == KEY_V then
        if PLATFORM == "OSX_STEAM" then
            return self:IsKeyDown(KEY_LSUPER) or self:IsKeyDown(KEY_RSUPER)
        end
        return self:IsKeyDown(KEY_CTRL)
    end
    return key == KEY_INSERT and PLATFORM == "LINUX_STEAM" and self:IsKeyDown(KEY_SHIFT)
end

function Input:UpdateEntitiesUnderMouse()
	self.entitiesundermouse = TheSim:GetEntitiesAtScreenPoint(TheSim:GetPosition())
end

function Input:OnUpdate()
    if self.mouse_enabled then
        self.entitiesundermouse = TheSim:GetEntitiesAtScreenPoint(TheSim:GetPosition())

        local inst = self.entitiesundermouse[1]
		inst = inst and inst.client_forward_target or inst

        if inst ~= nil and inst.CanMouseThrough ~= nil then
            local mousethrough, keepnone = inst:CanMouseThrough()
            if mousethrough then
                for i = 2, #self.entitiesundermouse do
                    local nextinst = self.entitiesundermouse[i]
					nextinst = nextinst and nextinst.client_forward_target or nextinst

                    if nextinst == nil or
                        nextinst:HasTag("player") or
                        (nextinst.Transform ~= nil) ~= (inst.Transform ~= nil) then
                        if keepnone then
                            inst = nextinst
                            mousethrough, keepnone = false, false
                        end
                        break
                    end

                    inst = nextinst
                    if nextinst.CanMouseThrough == nil then
                        mousethrough, keepnone = false, false
                    else
                        mousethrough, keepnone = nextinst:CanMouseThrough()
                    end
                    if not mousethrough then
                        break
                    end
                end
                if mousethrough and keepnone then
                    inst = nil
                end
            end
        end

        if inst ~= self.hoverinst then
            if inst ~= nil and inst.Transform ~= nil then
                inst:PushEvent("mouseover")
            end

            if self.hoverinst ~= nil and self.hoverinst.Transform ~= nil then
                self.hoverinst:PushEvent("mouseout")
            end

            self.hoverinst = inst
        end
    end
end

function Input:IsControlMapped(deviceId, controlId)
	local device, numInputs = TheInputProxy:GetLocalizedControl(deviceId, controlId, false, true)
	return device and device ~= 9 and numInputs >= 1
end

function Input:ControlsHaveSameMapping(deviceId, controlId_1, controlId_2)
	local device_1, numInputs_1, input1_1, input2_1, input3_1, input4_1, intParam_1 = TheInputProxy:GetLocalizedControl(deviceId, controlId_1, false, true)
	if device_1 == nil or device_1 == 9 or numInputs_1 < 1 then
		return false --don't match unmapped controls
	end
	local device_2, numInputs_2, input1_2, input2_2, input3_2, input4_2, intParam_2 = TheInputProxy:GetLocalizedControl(deviceId, controlId_2, false, true)
	return device_1 == device_2
		and numInputs_1 == numInputs_2
		and input1_1 == input1_2
		and input2_1 == input2_2
		and input3_1 == input3_2
		and input4_1 == input4_2
		and intParam_1 == intParam_2
end

function Input:GetLocalizedControl(deviceId, controlId, use_default_mapping, use_control_mapper)
	if controlId >= VIRTUAL_CONTROL_START then
		return self:GetLocalizedVirtualControl(deviceId, controlId, use_default_mapping, use_control_mapper)
	end

    local device, numInputs, input1, input2, input3, input4, intParam = TheInputProxy:GetLocalizedControl(deviceId, controlId, use_default_mapping == true, use_control_mapper ~= false)

    if device == nil then
        return STRINGS.UI.CONTROLSSCREEN.INPUTS[9][1]
    elseif numInputs < 1 then
        return ""
    end

    local inputs = { input1, input2, input3, input4 }
    local text = STRINGS.UI.CONTROLSSCREEN.INPUTS[device][input1]
    -- concatenate the inputs
    for idx = 2, numInputs do
        text = text.." + "..STRINGS.UI.CONTROLSSCREEN.INPUTS[device][inputs[idx]]
    end

    -- process string format params if there are any
    return intParam ~= nil and string.format(text, intParam) or text
end

function Input:GetLocalizedVirtualControl(deviceId, controlId, use_default_mapping, use_control_mapper)
	local scheme = Profile:GetControlScheme(CONTROL_SCHEME_CAM_AND_INV) or 1 --ignores controller active or not

	--Scheme 1 is classic style, where we have no modifier button, and everyhting is remappable.
	if IsCamAndInvCtrlScheme1(scheme) then
		if IsVCtrlInvNav(controlId) then
			return self:GetLocalizedControl(deviceId, RemapTo_CONTROL_INVENTORY[controlId - VIRTUAL_CONTROL_INV_UP])
		elseif IsVCtrlInvAct(controlId) then
			return self:GetLocalizedControl(deviceId, RemapTo_CONTROL_INVENTORY_ACTIONS[controlId - VIRTUAL_CONTROL_INV_ACTION_UP])
		elseif IsVCtrlAiming(controlId) then
			return self:GetLocalizedControl(deviceId, RemapTo_CONTROL_INVENTORY[controlId - VIRTUAL_CONTROL_AIM_UP])
		elseif IsVCtrlStrafe(controlId) then
			return self:GetLocalizedControl(deviceId, RemapTo_CONTROL_INVENTORY[controlId - VIRTUAL_CONTROL_STRAFE_UP])
		end
		return ""
	end

	--Now handle all the new schemes (2 to 7) for each control category

	local needsmodifier
	if IsVCtrlCamera(controlId) then
		--R.Stick for all schemes, modifier button for even number schemes
		needsmodifier = bit.band(scheme, 1) == 0
		controlId = controlId - VIRTUAL_CONTROL_CAMERA_ZOOM_IN + CONTROL_PRESET_RSTICK_UP
	elseif IsVCtrlAiming(controlId) then
		--R.Stick for all schemes, modifier button for 5 and 7
		needsmodifier = scheme == 5 or scheme == 7
		controlId = controlId - VIRTUAL_CONTROL_AIM_UP + CONTROL_PRESET_RSTICK_UP
	elseif IsVCtrlInvNav(controlId) then
		--R.Stick for 2 and 3, DPad for 4 to 7, modifier button for 3 to 5
		needsmodifier = scheme >= 3 and scheme <= 5
		if scheme <= 3 then
			if needsmodifier and player.HUD and player.HUD:IsControllerInventoryOpen() then
				--In controller inventory screen, we can ignore R.stick modifier
				needsmodifier = false
			end
			controlId = controlId - VIRTUAL_CONTROL_INV_UP + CONTROL_PRESET_RSTICK_UP
		else
			controlId = controlId - VIRTUAL_CONTROL_INV_UP + CONTROL_PRESET_DPAD_UP
		end
	elseif IsVCtrlInvAct(controlId) then
		--Classic mapping for 2 and 3, DPad for 4 to 7, modifier button for 6 and 7
		needsmodifier = scheme == 6 or scheme == 7
		if scheme <= 3 then
			controlId = RemapTo_CONTROL_INVENTORY_ACTIONS[controlId - VIRTUAL_CONTROL_INV_ACTION_UP]
		else
			controlId = controlId - VIRTUAL_CONTROL_INV_ACTION_UP + CONTROL_PRESET_DPAD_UP
		end
	elseif IsVCtrlStrafe(controlId) then
		--Unmodified R.Stick for all schemes
		needsmodifier = false
		controlId = controlId - VIRTUAL_CONTROL_STRAFE_UP + CONTROL_PRESET_RSTICK_UP
	else
		return ""
	end

	local text = self:GetLocalizedControl(deviceId, controlId, use_default_mapping, use_control_mapper)
	if needsmodifier then
		text = self:GetLocalizedControl(deviceId, CONTROL_CAM_AND_INV_MODIFIER, use_default_mapping, use_control_mapper).." + "..text
	end
	return text
end

--V2C: used for rstick/dpad virtual controls with or without modifier button held
function Input:GetLocalizedVirtualDirectionalControl(deviceId, controlIdStr, modifierId, use_modifier)
	local device, numInputs, input1, input2, input3, input4, intParam = TheInputProxy:GetLocalizedControl(deviceId, modifierId, false, true)
	if device == nil then
		return ""
	elseif numInputs < 1 and use_modifier then
		return ""
	end

	local text = STRINGS.UI.CONTROLSSCREEN.INPUTS[device][controlIdStr]
	if text == nil then
		return ""
	end

	if use_modifier then
		local inputs = { input1, input2, input3, input4 }
		local modifiertext = STRINGS.UI.CONTROLSSCREEN.INPUTS[device][input1]
		-- concatenate the inputs
		for idx = 2, numInputs do
			modifiertext = modifiertext.." + "..STRINGS.UI.CONTROLSSCREEN.INPUTS[device][inputs[idx]]
		end

		-- process string format params if there are any
		if intParam then
			modifiertext = string.format(modifiertext, intParam)
		end

		text = modifiertext.." + "..text
	end
	return text
end

function Input:GetControlIsMouseWheel(controlId)
    if self:ControllerAttached() then
        return false
    end
    local localized = self:GetLocalizedControl(0, controlId)
    local stringtable = STRINGS.UI.CONTROLSSCREEN.INPUTS[1]
    return localized == stringtable[1003] or localized == stringtable[1004]
end

function Input:GetStringIsButtonImage(str)
    return table.contains(STRINGS.UI.CONTROLSSCREEN.INPUTS[2], str)
        or table.contains(STRINGS.UI.CONTROLSSCREEN.INPUTS[4], str)
        or table.contains(STRINGS.UI.CONTROLSSCREEN.INPUTS[5], str)
        or table.contains(STRINGS.UI.CONTROLSSCREEN.INPUTS[7], str)
        or table.contains(STRINGS.UI.CONTROLSSCREEN.INPUTS[8], str)
end

function Input:PlatformUsesVirtualKeyboard()
	if IsConsole() or IsSteamDeck() then
		return true
	end

	return false
end


---------------- Globals

TheInput = Input()

function OnFloatingTextInputDismissed() -- called from C++
    TheInput:OnFloatingTextInputDismissed()
end

function OnPosition(x, y)
    TheInput:UpdatePosition(x, y)
end

ValidateLineNumber(750)
function OnControl(control, digitalvalue, analogvalue)
    TheInput:OnControl(control, digitalvalue, analogvalue)
end
ValidateLineNumber(754)

function OnMouseButton(button, is_up, x, y)
    TheInput:OnMouseButton(button, is_up, x, y)
end

function OnMouseMove(x, y)
    TheInput:OnMouseMove(x, y)
end

function OnInputKey(key, is_up)
    TheInput:OnRawKey(key, is_up)
end

function OnInputText(text)
    TheInput:OnText(text)
end

function OnGesture(gesture)
    TheInput:OnGesture(gesture)
end

function OnControlMapped(deviceId, controlId, inputId, hasChanged)
    TheInput:OnControlMapped(deviceId, controlId, inputId, hasChanged)
end

return Input
