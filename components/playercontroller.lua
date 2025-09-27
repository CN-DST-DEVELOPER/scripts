local START_DRAG_TIME = 8 * FRAMES
local BUTTON_REPEAT_COOLDOWN = .5
local ACTION_REPEAT_COOLDOWN = 0.2
local INVENTORY_ACTIONHOLD_REPEAT_COOLDOWN = 0.8
local BUFFERED_CASTAOE_TIME = .5
local BUFFERED_ACTION_NO_CANCEL_TIME = FRAMES + .0001
local CONTROLLER_TARGETING_LOCK_TIME = 1.0
local RUBBER_BAND_PING_TOLERANCE_IN_SECONDS = 0.7
local RUBBER_BAND_DISTANCE = 4
local RUBBER_BAND_DISTANCE_SQ = RUBBER_BAND_DISTANCE * RUBBER_BAND_DISTANCE
local PREDICT_STOP_ERROR_DISTANCE_SQ = 0.25

local function OnPlayerActivated(inst)
    inst.components.playercontroller:Activate()
end

local function OnPlayerDeactivated(inst)
    inst.components.playercontroller:Deactivate()
end

local function GetWorldControllerVector()
    local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
	local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
    if math.abs(xdir) >= deadzone or math.abs(ydir) >= deadzone then
        local dir = TheCamera:GetRightVec() * xdir - TheCamera:GetDownVec() * ydir
        return dir:GetNormalized()
    end
end

local function HasItemSlots(self)
    return self._hasitemslots
end

local function CacheHasItemSlots(self)
    self.HasItemSlots = HasItemSlots
    self._hasitemslots = self.inst.replica.inventory:GetNumSlots() > 0
    return self._hasitemslots
end

local function OnEquipChanged(inst)
    if inst == ThePlayer then
        local self = inst.components.playercontroller
        if self and (self.gridplacer ~= nil) == not inst.replica.inventory:EquipHasTag("turfhat") then
            if self.gridplacer then
                self.gridplacer:SetPlayer(nil)
                self.gridplacer:Remove()
                self.gridplacer = nil
            else
                self.gridplacer = SpawnPrefab("gridplacer_turfhat")
                self.gridplacer:SetPlayer(self.inst)
            end
        end
    end
end

local function OnInit(inst, self)
    inst:ListenForEvent("equip", OnEquipChanged)
    inst:ListenForEvent("unequip", OnEquipChanged)
    if not TheWorld.ismastersim then
        --Client only event, because when inventory is closed, we will stop
        --getting "equip" and "unequip" events, but we can also assume that
        --our inventory is emptied.
        inst:ListenForEvent("inventoryclosed", OnEquipChanged)
        if inst.replica.inventory == nil then
            --V2C: clients c_spawning characters ...grrrr
            return
        end
    end
    OnEquipChanged(inst)
end

local PlayerController = Class(function(self, inst)
    self.inst = inst

    --cache variables
    self.map = TheWorld.Map
    self.ismastersim = TheWorld.ismastersim
    self.locomotor = self.inst.components.locomotor
    self.HasItemSlots = CacheHasItemSlots

    --attack control variables
    self.attack_buffer = nil
    self.controller_attack_override = nil

    --remote control variables
    self.remote_vector = Vector3()
	self.remote_predict_dir = nil
	self.remote_predict_stop_tick = nil
	self.client_last_predict_walk = { tick = nil, direct = false }
    self.remote_controls = {}
	self.remote_predicting = false
	self.remote_authority = IsConsole()
	if not self.remote_authority then
		local client = TheNet:GetClientTableForUser(self.inst.userid)
		self.remote_authority = client and (client.admin or client.moderator or client.friend)
	end

	--locomotor buffered action instant cancelling prevention
	self.recent_bufferedaction = {}

    self.dragwalking = false
    self.directwalking = false
    self.predictwalking = false
	self.predictionsent = false --deprecated, see self.client_last_predict_walk
    self.draggingonground = false
    self.is_hopping = false
    self.startdragtestpos = nil
    self.startdragtime = nil
	self.startdoubleclicktime = nil
	self.startdoubleclickpos = nil
	self.doubletapmem = { down = false }
    self.isclientcontrollerattached = false

    self.mousetimeout = 10
    self.time_direct_walking = 0

    self.controller_target = nil
    self.controller_target_age = math.huge
    self.controller_attack_target = nil
    self.controller_attack_target_ally_cd = nil
    --self.controller_attack_target_age = math.huge

	-- CharlesB: For now this is always off
	--self.controller_targeting_modifier_down = false
	--self.controller_targeting_lock_timer = nil
	self.controller_targeting_lock_available = Profile:GetTargetLockingEnabled() -- can target locking be used at all or is it disabled in the profile
	self.controller_targeting_lock_target = false
	self.controller_targeting_targets = {}
	self.controller_targeting_target_index = nil
	self.command_wheel_allows_gameplay = Profile:GetCommandWheelAllowsGameplay() -- does the command wheel block all other gameplay or can you do other things, like move around, while it is open

    self.reticule = nil
    self.terraformer = nil
    self.deploy_mode = not TheInput:ControllerAttached()
    self.deployplacer = nil
    self.placer = nil
    self.placer_recipe = nil
    self.placer_recipe_skin = nil
    self.placer_cached = nil

    self.LMBaction = nil
    self.RMBaction = nil

    self.handler = nil
    self.actionbuttonoverride = nil

    --self.actionholding = false
    --self.actionholdtime = nil
    --self.lastheldaction = nil
    --self.actionrepeatfunction = nil
    self.heldactioncooldown = 0

	self.remoteinteractionaction = nil
	self.remoteinteractiontarget = nil

    if self.ismastersim then
        self.is_map_enabled = true
        self.can_use_map = true
        self.classified = inst.player_classified
        inst:StartUpdatingComponent(self)
        inst:StartWallUpdatingComponent(self)
	else
		self._clearinteractiontarget = function()
			--V2C: This is used by action Success/Fail callback, which doesn't know if player got removed.
			if self == inst.components.playercontroller and inst:IsValid() then
				self:RemoteInteractionTarget(nil, nil)
			end
		end
		if self.classified == nil and inst.player_classified then
			self:AttachClassified(inst.player_classified)
		end
    end

    inst:ListenForEvent("playeractivated", OnPlayerActivated)
    inst:ListenForEvent("playerdeactivated", OnPlayerDeactivated)

    inst:DoTaskInTime(0, OnInit, self)
end)

--------------------------------------------------------------------------

function PlayerController:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("playeractivated", OnPlayerActivated)
    self.inst:RemoveEventCallback("playerdeactivated", OnPlayerDeactivated)
    self:Deactivate()
    if self.classified ~= nil then
        if self.ismastersim then
            self.classified = nil
        else
            self.inst:RemoveEventCallback("onremove", self.ondetachclassified, self.classified)
            self:DetachClassified()
        end
    end
end

PlayerController.OnRemoveEntity = PlayerController.OnRemoveFromEntity

function PlayerController:AttachClassified(classified)
    self.classified = classified
    self.ondetachclassified = function() self:DetachClassified() end
    self.inst:ListenForEvent("onremove", self.ondetachclassified, classified)
end

function PlayerController:DetachClassified()
    self.classified = nil
    self.ondetachclassified = nil
end

--------------------------------------------------------------------------

local function OnBuild(inst)
    inst.components.playercontroller:CancelPlacement()
end

local function OnEquip(inst, data)
    --Reticule targeting items
    if data.eslot == EQUIPSLOTS.HANDS then
        local self = inst.components.playercontroller
		if self.reticule ~= nil and self.reticule.inst.components.spellbook ~= nil then
			--Ignore when targeting with spellbook
			return
		elseif data.item.components.aoetargeting ~= nil and data.item.components.aoetargeting:IsEnabled() then
            if self.reticule ~= nil then
                self.reticule:DestroyReticule()
                self.reticule = nil
            end
            data.item.components.aoetargeting:StopTargeting()
        else
            local newreticule = data.item.components.reticule or inst.components.reticule
            if newreticule ~= self.reticule then
                if self.reticule ~= nil then
                    self.reticule:DestroyReticule()
                end
                self.reticule = newreticule
                if newreticule ~= nil and newreticule.reticule == nil and (newreticule.mouseenabled or TheInput:ControllerAttached()) then
                    newreticule:CreateReticule()
					if newreticule.reticule ~= nil and (not self:IsEnabled() or newreticule:ShouldHide()) then
						newreticule.reticule:Hide()
					end
                end
            end
        end
    end
end

local function OnUnequip(inst, data)
    --Reticule targeting items
    if data.eslot == EQUIPSLOTS.HANDS then
        local self = inst.components.playercontroller
		if self.reticule ~= nil then
			if self.reticule.inst.components.spellbook ~= nil then
				--Ignore when targeting with spellbook
				return
			elseif self.reticule ~= inst.components.reticule then
				local equip = inst.replica.inventory:GetEquippedItem(data.eslot)
				if equip == nil or self.reticule ~= equip.components.reticule then
					self.reticule:DestroyReticule()
					self.reticule = inst.components.reticule
					if self.reticule ~= nil and self.reticule.reticule == nil and (self.reticule.mouseenabled or TheInput:ControllerAttached()) then
						self.reticule:CreateReticule()
						if self.reticule.reticule ~= nil and (not self:IsEnabled() or self.reticule:ShouldHide()) then
							self.reticule.reticule:Hide()
						end
					end
				end
			end
		end
    end
end

local function OnInventoryClosed(inst)
    --Reticule targeting items
    local self = inst.components.playercontroller
	self:CancelAOETargeting()
    if self.reticule ~= nil then
        self.reticule:DestroyReticule()
        self.reticule = nil
    end
end

local function OnZoom(inst, data)
    if data.zoomout then
        TheCamera:ZoomOut(data.zoom or 6)
    else
        TheCamera:ZoomIn(data.zoom or 6)
    end
end

local function OnNewActiveItem(inst, data)
	if data ~= nil and data.item ~= nil then
		inst.components.playercontroller:CancelAOETargeting()
	end
end

local function OnContinueFromPause()
	local self = ThePlayer.components.playercontroller
    self:ToggleController(TheInput:ControllerAttached())

	-- this caches if the camera zooming is using the same physical controls as the scroll bar scrolling
	self.zoomin_same_as_scrollup = TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ZOOM_IN) == TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SCROLLBACK)
	self.zoomout_same_as_scrolldown = TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_ZOOM_OUT) == TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SCROLLFWD)
end

local function OnDeactivateWorld()
    --Essential cleanup when client is notified of
    --pending server c_reset or c_regenerateworld.
    ThePlayer.components.playercontroller:Deactivate()
end

function PlayerController:Activate()
    if self.handler ~= nil then
        if self.inst ~= ThePlayer then
            self:Deactivate()
        end
    elseif self.inst == ThePlayer then
        self.handler = TheInput:AddGeneralControlHandler(function(control, value) self:OnControl(control, value) end)

        --reset the remote controllers just in case there was some old data
        self:ResetRemoteController()
        self.predictionsent = false
        self.isclientcontrollerattached = false

        self:RefreshReticule()

        self.inst:ListenForEvent("buildstructure", OnBuild)
        self.inst:ListenForEvent("equip", OnEquip)
        self.inst:ListenForEvent("unequip", OnUnequip)
        self.inst:ListenForEvent("zoomcamera", OnZoom)
        self.inst:ListenForEvent("newactiveitem", OnNewActiveItem)
        if not self.ismastersim then
            self.inst:ListenForEvent("deactivateworld", OnDeactivateWorld, TheWorld)
            self.inst:StartUpdatingComponent(self)
            self.inst:StartWallUpdatingComponent(self)

            --Client only event, because when inventory is closed, we will stop
            --getting "equip" and "unequip" events, but we can also assume that
            --our inventory is emptied.
            self.inst:ListenForEvent("inventoryclosed", OnInventoryClosed)
        end
        self.inst:ListenForEvent("continuefrompause", OnContinueFromPause, TheWorld)
        OnContinueFromPause()
    end
end

function PlayerController:Deactivate()
    if self.handler ~= nil then
        self:CancelPlacement()
        self:CancelDeployPlacement()
		self:CancelAOETargeting()

        if self.terraformer ~= nil then
            self.terraformer:Remove()
            self.terraformer = nil
        end

        if self.reticule ~= nil then
            self.reticule:DestroyReticule()
            self.reticule = nil
        end

        self.handler:Remove()
        self.handler = nil

        --reset the remote controllers just in case there was some old data
        self:ResetRemoteController()
        self.predictionsent = false
        self.isclientcontrollerattached = false

        self.inst:RemoveEventCallback("buildstructure", OnBuild)
        self.inst:RemoveEventCallback("equip", OnEquip)
        self.inst:RemoveEventCallback("unequip", OnUnequip)
		self.inst:RemoveEventCallback("zoomcamera", OnZoom)
		self.inst:RemoveEventCallback("newactiveitem", OnNewActiveItem)
        self.inst:RemoveEventCallback("continuefrompause", OnContinueFromPause, TheWorld)
        if not self.ismastersim then
            self.inst:RemoveEventCallback("inventoryclosed", OnInventoryClosed)
            self.inst:RemoveEventCallback("deactivateworld", OnDeactivateWorld, TheWorld)
            self.inst:StopUpdatingComponent(self)
            self.inst:StopWallUpdatingComponent(self)
        end
    end
end

--------------------------------------------------------------------------

function PlayerController:Enable(val)
    if self.ismastersim then
        self.classified.iscontrollerenabled:set(val)
    end
end

function PlayerController:ToggleController(val)
    if self.isclientcontrollerattached ~= val then
        self.isclientcontrollerattached = val
        if self.handler ~= nil then
            self:RefreshReticule()
        end
        if not self.ismastersim then
            SendRPCToServer(RPC.ToggleController, val)
        elseif val and self.inst.components.inventory ~= nil then
            self.inst.components.inventory:ReturnActiveItem()
        end
    end
end

function PlayerController:EnableMapControls(val)
    if self.ismastersim then
        self.is_map_enabled = val == true
        self.classified:EnableMapControls(val and self.can_use_map)
    end
end

function PlayerController:SetCanUseMap(val)
    if self.ismastersim then
        self.can_use_map = val == true
        self.classified:EnableMapControls(val and self.is_map_enabled)
    end
end

function PlayerController:GetMapTarget(act)
    if act == nil or act.action.map_action or self.inst.HUD == nil then -- HUD check makes this client sided only but can run on server when no caves.
        return nil
    end

    local maptarget = act.target or act.invobject or nil
    if maptarget == nil then
        return nil
    end

    if not act.maptarget and not maptarget:HasTag("action_pulls_up_map") then
        return nil
    end

    if maptarget.valid_map_actions ~= nil and not maptarget.valid_map_actions[act.action] then
        return nil
    end

    return maptarget
end

function PlayerController:PullUpMap(maptarget, forced_actiondef)
	-- NOTES(JBK): This is assuming inst is the local client on call with a check to self.inst.HUD not being nil.
	if self.inst.HUD:IsCraftingOpen() then
		self.inst.HUD:CloseCrafting()
	end
	if self.inst.HUD:IsSpellWheelOpen() then
		self.inst.HUD:CloseSpellWheel()
	end
	if self.inst.HUD:IsControllerInventoryOpen() then
		self.inst.HUD:CloseControllerInventory()
	end
	-- Pull up map now.
	if not self.inst.HUD:IsMapScreenOpen() then
		self.inst.HUD.controls:ToggleMap()
		if self.inst.HUD:IsMapScreenOpen() then -- Just in case.
			local mapscreen = TheFrontEnd:GetActiveScreen()
			mapscreen._hack_ignore_held_controls = 0.1
			mapscreen._hack_ignore_ups_for = {}
			mapscreen.maptarget = maptarget
            if forced_actiondef and forced_actiondef.map_only then
                mapscreen.forced_actiondef = forced_actiondef
            end
			local min_dist = maptarget.map_remap_min_dist
			if min_dist then
				min_dist = min_dist + 0.1 -- Padding for floating point precision.
				local x, y, z = self.inst.Transform:GetWorldPosition()
				local rotation = self.inst.Transform:GetRotation() * DEGREES
				local wx, wz = x + math.cos(rotation) * min_dist, z - math.sin(rotation) * min_dist -- Z offset is negative to desired from Transform coordinates.
				self.inst.HUD.controls:FocusMapOnWorldPosition(mapscreen, wx, wz)
			end
			-- Do not have to take into account max_dist because the map automatically centers on the player when opened.
			mapscreen:ProcessStaticDecorations()
		end
	end
end

-- returns: enable/disable, "a hud element is up, but still allow for limited gameplay to happen"
function PlayerController:IsEnabled()
    if self.classified == nil or not self.classified.iscontrollerenabled:value() then
        return false
    elseif self.inst.HUD ~= nil and self.inst.HUD:HasInputFocus() then
        return false, self.inst.HUD:IsCraftingOpen() and TheFrontEnd.textProcessorWidget == nil or self.inst.HUD:IsSpellWheelOpen() or (self.command_wheel_allows_gameplay and self.inst.HUD:IsCommandWheelOpen())
    end
    return true
end

function PlayerController:IsMapControlsEnabled()
    return self.classified ~= nil and
        self.classified.iscontrollerenabled:value() and
        self.classified.ismapcontrolsvisible:value() and
        self.inst.HUD ~= nil
end

function PlayerController:IsControlPressed(control)
    if self.handler ~= nil then
        return TheInput:IsControlPressed(control)
    else
        return self.remote_controls[control] ~= nil
    end
end

function PlayerController:IsAnyOfControlsPressed(...)
    if self.handler ~= nil then
        for i, v in ipairs({...}) do
            if TheInput:IsControlPressed(v) then
                return true
            end
        end
    else
        for i, v in ipairs({...}) do
            if self.remote_controls[v] ~= nil then
                return true
            end
        end
    end
end

function PlayerController:CooldownRemoteController(dt)
    for k, v in pairs(self.remote_controls) do
        self.remote_controls[k] = dt ~= nil and math.max(v - dt, 0) or 0
    end
    self:CooldownHeldAction(dt)
end

function PlayerController:CooldownHeldAction(dt)
    self.heldactioncooldown = dt ~= nil and math.max(self.heldactioncooldown - dt, 0) or 0
end

function PlayerController:OnRemoteStopControl(control)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_controls[control] = nil
    end
end

function PlayerController:OnRemoteStopAllControls()
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        if next(self.remote_controls) ~= nil then
            self.remote_controls = {}
        end
    end
end

function PlayerController:RemoteStopControl(control)
    if self.remote_controls[control] ~= nil then
        self.remote_controls[control] = nil
        SendRPCToServer(RPC.StopControl, control)
    end
end

function PlayerController:RemoteStopAllControls()
    if next(self.remote_controls) ~= nil then
        self.remote_controls = {}
        SendRPCToServer(RPC.StopAllControls)
    end
end

function PlayerController:RemotePausePrediction(frames)
    if self.ismastersim then
        self.classified:PushPausePredictionFrames(frames or 0)
    end
end

function PlayerController:ShouldPlayerHUDControlBeIgnored(control, down)
    -- NOTES(JBK): The PlayerHud gets control events before PlayerController which works for most cases.
    -- Some cases are exceptions for priority which are handled here to have PlayerController take over.
    -- This would be good to have a CONTROL_ priority list and SetDigitalControlFromInput creates a table that is sent to game.
    -- Right now priority is lower CONTROL_ id is higher priority.
    -- So this function exists to force a priority based off of function run ordering.

    if self:IsAxisAlignedPlacement() and
        control ~= CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID and
        TheInput:ControlsHaveSameMapping(TheInput:GetControllerID(), control, CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID) then
        return true
    end
    if self:IsControllerTargetLocked() and
        control ~= CONTROL_TARGET_CYCLE and
        TheInput:ControlsHaveSameMapping(TheInput:GetControllerID(), control, CONTROL_TARGET_CYCLE) then
        return true
    end

    return false
end

function PlayerController:OnControl(control, down)

    if IsPaused() then
        return
	end

    local isenabled, ishudblocking = self:IsEnabled()
	if not isenabled and not ishudblocking then
		return
	end

    if down and self._hack_ignore_held_controls then
        self._hack_ignore_ups_for[control] = true
        return true
    end
    if not down and self._hack_ignore_ups_for and self._hack_ignore_ups_for[control] then
        self._hack_ignore_ups_for[control] = nil
        return true
    end

	--V2C: control up happens here now
	if not down and control ~= CONTROL_PRIMARY and control ~= CONTROL_SECONDARY then
		if not self.ismastersim then
			self:RemoteStopControl(control)
		end
		return
	end

	-- actions that can be done while the crafting menu is open go in here
	if isenabled or ishudblocking then
		if control == CONTROL_ACTION then
			self:DoActionButton()
			return
		elseif control == CONTROL_ATTACK then
			if self.ismastersim then
				self.attack_buffer = CONTROL_ATTACK
			else
				self:DoAttackButton()
			end
			return
		elseif control == CONTROL_CHARACTER_COMMAND_WHEEL then
			self:DoCharacterCommandWheelButton()
			return
		end
	end

	if not isenabled then
		return
	end

    if control == CONTROL_PRIMARY then
        self:OnLeftClick(down)
    elseif control == CONTROL_SECONDARY then
        self:OnRightClick(down)
	--V2C: see above for control up handling
	--elseif not down then
	--    if not self.ismastersim then
	--        self:RemoteStopControl(control)
	--    end
    elseif control == CONTROL_CANCEL then
        self:CancelPlacement()
		--self:ControllerTargetLock(false)
    elseif control == CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID and self:IsAxisAlignedPlacement() then
        CycleAxisAlignmentValues()
    elseif control == CONTROL_INSPECT then
        self:DoInspectButton()
    elseif control == CONTROL_CONTROLLER_ALTACTION then
        self:DoControllerAltActionButton()
    elseif control == CONTROL_CONTROLLER_ACTION then
        self:DoControllerActionButton()
    elseif control == CONTROL_CONTROLLER_ATTACK then
        if self.ismastersim then
            self.attack_buffer = CONTROL_CONTROLLER_ATTACK
        else
            self:DoControllerAttackButton()
        end
    elseif self.inst.replica.inventory:IsVisible() then
        local inv_obj = self:GetCursorInventoryObject()
        if inv_obj ~= nil then
			local scheme = TheInput:GetActiveControlScheme(CONTROL_SCHEME_CAM_AND_INV)
			if scheme <= 3 or scheme > 7 then
				--Classic mapping control IDs aren't in the same order as (up/down/left/right), so
				--lets handle it manually here rather than calling ResolveVirtualControls 4 times.
				if control == CONTROL_INVENTORY_DROP then
					self:DoControllerDropItemFromInvTile(inv_obj)
				elseif control == CONTROL_INVENTORY_EXAMINE then
					self:DoControllerInspectItemFromInvTile(inv_obj)
				elseif control == CONTROL_INVENTORY_USEONSELF then
					self:DoControllerUseItemOnSelfFromInvTile(inv_obj)
				elseif control == CONTROL_INVENTORY_USEONSCENE then
					self:DoControllerUseItemOnSceneFromInvTile(inv_obj)
				end
			else
				local vcontrol = TheInput:ResolveVirtualControls(VIRTUAL_CONTROL_INV_ACTION_UP)
				if vcontrol then
					if control == vcontrol + 1 then --VIRTUAL_CONTROL_INV_ACTION_DOWN
						self:DoControllerDropItemFromInvTile(inv_obj)
					elseif control == vcontrol then --VIRTUAL_CONTROL_INV_ACTION_UP
						self:DoControllerInspectItemFromInvTile(inv_obj)
					elseif control == vcontrol + 3 then --VIRTUAL_CONTROL_INV_ACTION_RIGHT
						self:DoControllerUseItemOnSelfFromInvTile(inv_obj)
					elseif control == vcontrol + 2 then --VIRTUAL_CONTROL_INV_ACTION_LEFT
						self:DoControllerUseItemOnSceneFromInvTile(inv_obj)
					end
				end
			end
        end
    end
    
    if down then
	    if control == CONTROL_TARGET_LOCK then		
		    self:ControllerTargetLockToggle()
	    elseif self:IsControllerTargetLockEnabled() and control == CONTROL_TARGET_CYCLE then
		    self:CycleControllerAttackTargetForward()
        end
    end

end

--------------------------------------------------------------------------

local MOD_CONTROLS =
{
    CONTROL_FORCE_INSPECT,
    CONTROL_FORCE_ATTACK,
    CONTROL_FORCE_TRADE,
    CONTROL_FORCE_STACK,
}

function PlayerController:EncodeControlMods()
    local code = 0
    local bit = 1
    for i, v in ipairs(MOD_CONTROLS) do
        code = code + (TheInput:IsControlPressed(v) and bit or 0)
        bit = bit * 2
    end
    return code ~= 0 and code or nil
end

function PlayerController:DecodeControlMods(code)
    code = code or 0
    local bit = 2 ^ (#MOD_CONTROLS - 1)
    for i = #MOD_CONTROLS, 1, -1 do
        if code >= bit then
            self.remote_controls[MOD_CONTROLS[i]] = 0
            code = code - bit
        else
            self.remote_controls[MOD_CONTROLS[i]] = nil
        end
        bit = bit / 2
    end
end

function PlayerController:ClearControlMods()
    for i, v in ipairs(MOD_CONTROLS) do
        self.remote_controls[v] = nil
    end
end

function PlayerController:CanLocomote()
    return self.ismastersim
        or (self.locomotor ~= nil and
            not (self.inst.sg:HasStateTag("busy") or
                self.inst:HasTag("pausepredict") or
                (self.classified ~= nil and self.classified.pausepredictionframes:value() > 0)) and
            self.inst.entity:CanPredictMovement())
end

function PlayerController:IsBusy()
    if self.ismastersim then
        return self.inst.sg:HasStateTag("busy")
    else
        return self.inst:HasTag("busy")
            or (self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy"))
            or (self.classified ~= nil and self.classified.pausepredictionframes:value() > 0)
    end
end

--------------------------------------------------------------------------

function PlayerController:GetCursorInventoryObject()
    if self.inst.HUD ~= nil and TheInput:ControllerAttached() then
        local item = self.inst.HUD.controls.inv:GetCursorItem()
        return item ~= nil and item:IsValid() and item or nil
    end
end

function PlayerController:GetCursorInventorySlotAndContainer()
    if self.inst.HUD ~= nil and TheInput:ControllerAttached() then
        return self.inst.HUD.controls.inv:GetCursorSlot()
    end
end

function PlayerController:DoControllerActionButton()
    if self.placer ~= nil and self.placer_recipe ~= nil then
        --do the placement
        local placer_placer = self.placer.components.placer
        if placer_placer.can_build then
            if self.inst.replica.builder ~= nil and not self.inst.replica.builder:IsBusy() then
                self.inst.replica.builder:MakeRecipeAtPoint(
                    self.placer_recipe,
                    (placer_placer.override_build_point_fn ~= nil and placer_placer.override_build_point_fn(self.placer))
                        or self.placer:GetPosition(),
                    self.placer:GetRotation(),
                    self.placer_recipe_skin
                )
                self:CancelPlacement()
            end
        elseif placer_placer.onfailedplacement ~= nil then
            placer_placer.onfailedplacement(self.inst, self.placer)
        end
        return
    end

	local obj, act, isspecial, spellbook, spell_id
    if self.deployplacer ~= nil then
        if self.deployplacer.components.placer.can_build then
            act = self.deployplacer.components.placer:GetDeployAction()
            if act ~= nil then
                obj = act.invobject
                act.distance = 1
            end
        end
    elseif self:IsAOETargeting() then
		local canrepeatcast = self.reticule.inst.components.aoetargeting:CanRepeatCast()
		if self:IsBusy() and not (canrepeatcast and self.inst:HasTag("canrepeatcast")) then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative", nil, .4)
            self.reticule:Blip()
            return
        end
        obj, act = self:GetGroundUseAction()
        if act == nil or act.action ~= ACTIONS.CASTAOE then
            return
        end
        obj = nil --meh.. reusing obj =P
		spellbook = self:GetActiveSpellBook()
		if spellbook ~= nil then
			spell_id = spellbook.components.spellbook:GetSelectedSpell()
		end
		self.reticule:PingReticuleAt(act:GetDynamicActionPoint())
		if not (canrepeatcast and self.reticule.inst.components.aoetargeting:ShouldRepeatCast(self.inst)) then
			self:CancelAOETargeting()
		end
    else
        obj = self:GetControllerTarget()
        if obj ~= nil then
            act = self:GetSceneItemControllerAction(obj)
            if act ~= nil and act.action == ACTIONS.BOAT_CANNON_SHOOT then
                obj = nil --meh.. reusing obj =P
                local boatcannonuser = self.inst.components.boatcannonuser
                local reticule = boatcannonuser ~= nil and boatcannonuser:GetReticule() or nil
                if reticule ~= nil then
					reticule:PingReticuleAt(act:GetDynamicActionPoint())
                end
            end
        end
        if act == nil then
            act = self:GetGroundUseSpecialAction(nil, false)
            if act ~= nil then
                isspecial = true
            end
        end
    end

    if act == nil then
        return
    end

    local maptarget = self:GetMapTarget(act)
    if maptarget ~= nil then
		self:PullUpMap(maptarget)
        return
    end

    if self.ismastersim then
        self.inst.components.combat:SetTarget(nil)
    elseif self.deployplacer ~= nil then
        if self.locomotor == nil then
			act.non_preview_cb = function()
				self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
				SendRPCToServer(RPC.ControllerActionButtonDeploy, obj, act.pos.local_pt.x, act.pos.local_pt.z, act.rotation ~= 0 and act.rotation or nil, nil, act.pos.walkable_platform, act.pos.walkable_platform ~= nil)
			end
        elseif self:CanLocomote() then
            act.preview_cb = function()
                self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
                local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ACTION)
                SendRPCToServer(RPC.ControllerActionButtonDeploy, obj, act.pos.local_pt.x, act.pos.local_pt.z, act.rotation ~= 0 and act.rotation or nil, isreleased, act.pos.walkable_platform, act.pos.walkable_platform ~= nil)
            end
        end
    elseif obj == nil then
        if self.locomotor == nil then
			act.non_preview_cb = function()
				self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
				SendRPCToServer(RPC.ControllerActionButtonPoint, act.action.code, act.pos.local_pt.x, act.pos.local_pt.z, nil, act.action.canforce, act.action.mod_name, act.pos.walkable_platform, act.pos.walkable_platform ~= nil, isspecial, spellbook, spell_id)
			end
        elseif self:CanLocomote() then
            act.preview_cb = function()
                self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
                local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ACTION)
				SendRPCToServer(RPC.ControllerActionButtonPoint, act.action.code, act.pos.local_pt.x, act.pos.local_pt.z, isreleased, nil, act.action.mod_name, act.pos.walkable_platform, act.pos.walkable_platform ~= nil, isspecial, spellbook, spell_id)
            end
        end
    elseif self.locomotor == nil then
		act.non_preview_cb = function()
			self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
			SendRPCToServer(RPC.ControllerActionButton, act.action.code, obj, nil, act.action.canforce, act.action.mod_name)
		end
    elseif self:CanLocomote() then
        act.preview_cb = function()
            self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
            local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ACTION)
            SendRPCToServer(RPC.ControllerActionButton, act.action.code, obj, isreleased, nil, act.action.mod_name)
        end
    end

	self:DoAction(act, spellbook)
end

function PlayerController:OnRemoteControllerActionButton(actioncode, target, isreleased, noforce, mod_name)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
        self:ClearControlMods()
        SetClientRequestedAction(actioncode, mod_name)
        local lmb, rmb = self:GetSceneItemControllerAction(target)
        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_CONTROLLER_ACTION] = nil
        end

        --Possible for lmb action to switch to rmb after autoequip
        lmb =  (lmb ~= nil and
                lmb.action.code == actioncode and
                lmb.action.mod_name == mod_name and
                lmb)
            or (rmb ~= nil and
                rmb.action.code == actioncode and
                rmb.action.mod_name == mod_name and
                rmb)
            or nil

        if lmb ~= nil then
            if lmb.action.canforce and not noforce then
                lmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                lmb.forced = true
            end
            self:DoAction(lmb)
        --elseif mod_name ~= nil then
            --print("Remote controller action button action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote controller action button action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:OnRemoteControllerActionButtonPoint(actioncode, position, isreleased, noforce, mod_name, isspecial, spellbook, spell_id)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_CONTROLLER_ACTION] = 0
        self:ClearControlMods()
        SetClientRequestedAction(actioncode, mod_name)
        local lmb, rmb
        if isspecial then
			lmb = self:GetGroundUseSpecialAction(position, false)
		elseif spellbook ~= nil then
			if spellbook.components.inventoryitem ~= nil and
				spellbook.components.inventoryitem:GetGrandOwner() == self.inst and
				spellbook.components.spellbook ~= nil and
				spellbook.components.spellbook:SelectSpell(spell_id)
				then
				lmb, rmb = self:GetGroundUseAction(position, spellbook)
			end
		elseif spell_id == nil then
            local cannon = self.inst.components.boatcannonuser ~= nil and self.inst.components.boatcannonuser:GetCannon() or nil
            if cannon ~= nil then
                lmb = self.inst.components.playeractionpicker:GetLeftClickActions(position, cannon)[1]
            else
                lmb, rmb = self:GetGroundUseAction(position)
            end
		end
        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_CONTROLLER_ACTION] = nil
        end

        --Possible for lmb action to switch to rmb after autoequip
        lmb =  (lmb ~= nil and
                lmb.action.code == actioncode and
                lmb.action.mod_name == mod_name and
                lmb)
            or (rmb ~= nil and
                rmb.action.code == actioncode and
                rmb.action.mod_name == mod_name and
                rmb)
            or nil

        if lmb ~= nil then
            if lmb.action.canforce and not noforce then
                lmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                lmb.forced = true
            end
			self:DoAction(lmb, spellbook)
        --elseif mod_name ~= nil then
            --print("Remote controller action button action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote controller action button action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:OnRemoteControllerActionButtonDeploy(invobject, position, rotation, isreleased)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_CONTROLLER_ACTION] = not isreleased and 0 or nil

        if invobject.components.inventoryitem ~= nil and invobject.components.inventoryitem:GetGrandOwner() == self.inst then
            --Must match placer:GetDeployAction(), with an additional distance = 1 parameter
			local action =
				self.inst.components.inventory and
				self.inst.components.inventory:IsFloaterHeld() and
				invobject:HasTag("boatbuilder") and
				ACTIONS.DEPLOY_FLOATING or
				ACTIONS.DEPLOY
			self:DoAction(BufferedAction(self.inst, nil, action, invobject, position, nil, 1, nil, rotation or 0))
        --else
            --print("Remote controller action button deploy failed")
        end
    end
end

function PlayerController:DoControllerAltActionButton()
    self:ClearActionHold()

    if self.placer_recipe ~= nil then
        self:CancelPlacement()
        return
    elseif self.deployplacer ~= nil then
        self:CancelDeployPlacement()
        return
    elseif self:IsAOETargeting() then
        self:CancelAOETargeting()
        return
	--elseif self:IsControllerTargetLockEnabled() then
	--	self:ControllerTargetLock(false)
	--	return
    end

    self.actionholdtime = GetTime()

    local lmb, act = self:GetGroundUseAction()
    local isspecial = nil
	local obj = act ~= nil and act.target or nil
    if act == nil then
        obj = self:GetControllerTarget()
        if obj ~= nil then
            lmb, act = self:GetSceneItemControllerAction(obj)
			if act ~= nil and act.action == ACTIONS.APPLYCONSTRUCTION then
				local container = act.target ~= nil and act.target.replica.container
				if container ~= nil and
					container.widget ~= nil and
					container.widget.overrideactionfn ~= nil and
					container.widget.overrideactionfn(act.target, self.inst)
					then
					--e.g. rift offering has a local confirmation popup
					return
				end
			end
        end
        if act == nil then
			act = self:GetGroundUseSpecialAction(nil, true)
			if act ~= nil then
				obj = nil
				isspecial = true
			elseif self:TryAOETargeting() or self:TryAOECharging(nil, true) then
				return
			else
				local rider = self.inst.replica.rider
				local mount = rider and rider:GetMount() or nil
				local container = mount and mount.replica.container or nil
				if container and container:IsOpenedBy(self.inst) then
					obj = self.inst
					act = BufferedAction(obj, obj, ACTIONS.RUMMAGE)
				elseif self.inst.components.spellbook and self.inst.components.spellbook:CanBeUsedBy(self.inst) then
					obj = self.inst
					act = BufferedAction(obj, obj, ACTIONS.USESPELLBOOK)
				elseif mount then
					obj = self.inst
					act = BufferedAction(obj, obj, ACTIONS.DISMOUNT)
				else
					return
				end
			end
        end
    end

	if self.reticule ~= nil and self.reticule.reticule ~= nil and self.reticule.reticule.entity:IsVisible() then
		self.reticule:PingReticuleAt(act:GetDynamicActionPoint())
    end

    local maptarget = self:GetMapTarget(act)
    if maptarget ~= nil then
		self:PullUpMap(maptarget)
        return
    end

    if self.ismastersim then
        self.inst.components.combat:SetTarget(nil)
    elseif obj ~= nil then
        if self.locomotor == nil then
			act.non_preview_cb = function()
				self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
				SendRPCToServer(RPC.ControllerAltActionButton, act.action.code, obj, nil, act.action.canforce, act.action.mod_name)
			end
        elseif self:CanLocomote() then
            act.preview_cb = function()
                self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
                local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ALTACTION)
                SendRPCToServer(RPC.ControllerAltActionButton, act.action.code, obj, isreleased, nil, act.action.mod_name)
            end
        end
    elseif self.locomotor == nil then
		act.non_preview_cb = function()
			self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
			SendRPCToServer(RPC.ControllerAltActionButtonPoint, act.action.code, act.pos.local_pt.x, act.pos.local_pt.z, nil, act.action.canforce, isspecial, act.action.mod_name, act.pos.walkable_platform, act.pos.walkable_platform ~= nil)
		end
    elseif self:CanLocomote() then
        act.preview_cb = function()
            self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
            local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ALTACTION)
            SendRPCToServer(RPC.ControllerAltActionButtonPoint, act.action.code, act.pos.local_pt.x, act.pos.local_pt.z, isreleased, nil, isspecial, act.action.mod_name, act.pos.walkable_platform, act.pos.walkable_platform ~= nil)
        end
    end

    self:DoAction(act)
end

function PlayerController:OnRemoteControllerAltActionButton(actioncode, target, isreleased, noforce, mod_name)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
        self:ClearControlMods()
        SetClientRequestedAction(actioncode, mod_name)
        local lmb, rmb = self:GetSceneItemControllerAction(target)
        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = nil
        end

        --Possible for rmb action to switch to lmb after autoequip
        --Probably not, but fairly inexpensive to be safe =)
        rmb =  (rmb ~= nil and
                rmb.action.code == actioncode and
                rmb.action.mod_name == mod_name and
                rmb)
            or (lmb ~= nil and
                lmb.action.code == actioncode and
                lmb.action.mod_name == mod_name and
                lmb)
            or nil

        if rmb ~= nil then
            if rmb.action.canforce and not noforce then
                rmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                rmb.forced = true
            end
            self:DoAction(rmb)
        --elseif mod_name ~= nil then
            --print("Remote controller alt action button action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote controller alt action button action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:OnRemoteControllerAltActionButtonPoint(actioncode, position, isreleased, noforce, isspecial, mod_name)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = 0
        self:ClearControlMods()
        local lmb, rmb
        SetClientRequestedAction(actioncode, mod_name)
        if isspecial then
            rmb = self:GetGroundUseSpecialAction(position, true)
        else
            lmb, rmb = self:GetGroundUseAction(position)
        end
        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_CONTROLLER_ALTACTION] = nil
        end

        --Possible for rmb action to switch to lmb after autoequip
        --Probably not, but fairly inexpensive to be safe =)
        rmb =  (rmb ~= nil and
                rmb.action.code == actioncode and
                rmb.action.mod_name == mod_name and
                rmb)
            or (lmb ~= nil and
                lmb.action.code == actioncode and
                lmb.action.mod_name == mod_name and
                lmb)
            or nil

        if rmb ~= nil then
            if rmb.action.canforce and not noforce then
                rmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                rmb.forced = true
            end
            self:DoAction(rmb)
        --elseif mod_name ~= nil then
            --print("Remote controller alt action button point action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote controller alt action button point action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:DoControllerAttackButton(target)
	if target == nil and (self:IsAOETargeting() or self.inst:HasTag("sitting_on_chair")) then
        return
    elseif target ~= nil then
        --Don't want to spam the controller attack button when retargetting
        if not self.ismastersim and (self.remote_controls[CONTROL_CONTROLLER_ATTACK] or 0) > 0 then
            return
        end

        if self.inst.sg ~= nil then
            if self.inst.sg:HasStateTag("attack") then
                return
            end
        elseif self.inst:HasTag("attack") then
            return
        end

        if not self.inst.replica.combat:CanHitTarget(target) or
            IsEntityDead(target, true) or
            not CanEntitySeeTarget(self.inst, target) then
            return
        end
    else
        target = self.controller_attack_target
        if target ~= nil then
            if target == self.inst.replica.combat:GetTarget() then
                --Still need to let the server know our controller attack button is down
                if not self.ismastersim and
                    self.locomotor == nil and
                    self.remote_controls[CONTROL_CONTROLLER_ATTACK] == nil then
                    self.remote_controls[CONTROL_CONTROLLER_ATTACK] = 0
                    SendRPCToServer(RPC.ControllerAttackButton, true)
                end
                return
            elseif not self.inst.replica.combat:CanTarget(target) then
                target = nil
            end
        end
        --V2C: controller attacks still happen even with no valid target
		if target == nil then
			--exceptions:
			if self.directwalking or
				self.inst:HasAnyTag("playerghost", "weregoose") or
				(self.classified and self.classified.inmightygym:value() > 0) or
				GetGameModeProperty("no_air_attack")
			then
				return
			end
			local inventory = self.inst.replica.inventory
			if inventory:IsHeavyLifting() or inventory:IsFloaterHeld() then
				return
			end
		end
    end

    local act = BufferedAction(self.inst, target, ACTIONS.ATTACK)

    if self.ismastersim then
        self.inst.components.combat:SetTarget(nil)
    elseif self.locomotor == nil then
		act.non_preview_cb = function()
			self.remote_controls[CONTROL_CONTROLLER_ATTACK] = BUTTON_REPEAT_COOLDOWN
			SendRPCToServer(RPC.ControllerAttackButton, target, nil, act.action.canforce)
		end
    elseif self:CanLocomote() then
        act.preview_cb = function()
            self.remote_controls[CONTROL_CONTROLLER_ATTACK] = BUTTON_REPEAT_COOLDOWN
            local isreleased = not TheInput:IsControlPressed(CONTROL_CONTROLLER_ATTACK)
            SendRPCToServer(RPC.ControllerAttackButton, target, isreleased)
        end
    end

    self:DoAction(act)
end

function PlayerController:OnRemoteControllerAttackButton(target, isreleased, noforce)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        --Check if target is valid, otherwise make
        --it nil so that we still attack and miss.
		self.remote_controls[CONTROL_CONTROLLER_ATTACK] = 0
        if target == true then
            --Special case, just flagging the button as down
			--self.remote_controls[CONTROL_CONTROLLER_ATTACK] = 0
        elseif not noforce then
			if self.inst.sg:HasStateTag(self.remote_authority and self.remote_predicting and "abouttoattack" or "attack") then
                self.inst.sg.statemem.chainattack_cb = function()
                    self:OnRemoteControllerAttackButton(target)
                end
            else
                target = self.inst.components.combat:CanTarget(target) and target or nil
                self.attack_buffer = BufferedAction(self.inst, target, ACTIONS.ATTACK, nil, nil, nil, nil, true)
                self.attack_buffer._controller = true
                self.attack_buffer._predictpos = true
            end
        else
            if self.inst.components.combat:CanTarget(target) then
                self.attack_buffer = BufferedAction(self.inst, target, ACTIONS.ATTACK)
                self.attack_buffer._controller = true
            else
                self.attack_buffer = BufferedAction(self.inst, nil, ACTIONS.ATTACK, nil, nil, nil, nil, true)
                self.attack_buffer._controller = true
                self.attack_buffer._predictpos = true
                self.attack_buffer.overridedest = self.inst
            end
        end
		if isreleased then
			self.remote_controls[CONTROL_CONTROLLER_ATTACK] = nil
		end
    end
end

function PlayerController:DoControllerDropItemFromInvTile(item, single)
    self.inst.replica.inventory:DropItemFromInvTile(item, single)
end

function PlayerController:DoControllerInspectItemFromInvTile(item)
    self.inst.replica.inventory:InspectItemFromInvTile(item)
end

function PlayerController:DoControllerUseItemOnSelfFromInvTile(item)
    if item ~= nil then
        self.actionholdtime = GetTime()
        self.lastheldaction = nil
        self.actionrepeatfunction = self.DoControllerUseItemOnSelfFromInvTile
    else
        item = self:GetCursorInventoryObject()
        if item == nil then self.actionrepeatfunction = nil return end
    end
    if not self.deploy_mode and
        item.replica.inventoryitem:IsDeployable(self.inst) and
        item.replica.inventoryitem:IsGrandOwner(self.inst) then
		self.deploy_mode = true
		return
    end
    self.inst.replica.inventory:ControllerUseItemOnSelfFromInvTile(item)
end

function PlayerController:DoControllerUseItemOnSceneFromInvTile(item)
    if item ~= nil then
        self.actionholdtime = GetTime()
        self.lastheldaction = nil
        self.actionrepeatfunction = self.DoControllerUseItemOnSceneFromInvTile
    else
        item = self:GetCursorInventoryObject()
        if item == nil then self.actionrepeatfunction = nil return end
    end
    if item.replica.inventoryitem ~= nil and not item.replica.inventoryitem:IsGrandOwner(self.inst) then
        local slot, container = self:GetCursorInventorySlotAndContainer()
        if slot ~= nil and container ~= nil then
            container:MoveItemFromAllOfSlot(slot, self.inst)
        end
    else
        self.inst.replica.inventory:ControllerUseItemOnSceneFromInvTile(item)
    end
end

function PlayerController:RotLeft(speed)
    if not TheCamera:CanControl() then
        return
    end
    local rotamount = 45 ---90-- TheWorld:HasTag("cave") and 22.5 or 45
    if not IsPaused() then
		if speed then
			TheCamera:SetContinuousHeadingTarget((math.ceil((TheCamera:GetHeading() - speed) / rotamount) - 1) * rotamount, -speed)
		else
			TheCamera:SetHeadingTarget(TheCamera:GetHeadingTarget() - rotamount)
		end
        --UpdateCameraHeadings()
    elseif self.inst.HUD ~= nil and self.inst.HUD:IsMapScreenOpen() then
        TheCamera:SetHeadingTarget(TheCamera:GetHeadingTarget() - rotamount)
        TheCamera:Snap()
    end
end

function PlayerController:RotRight(speed)
    if not TheCamera:CanControl() then
        return
    end
    local rotamount = 45 --90--TheWorld:HasTag("cave") and 22.5 or 45
    if not IsPaused() then
		if speed then
			TheCamera:SetContinuousHeadingTarget((math.floor((TheCamera:GetHeading() + speed) / rotamount) + 1) * rotamount, speed)
		else
			TheCamera:SetHeadingTarget(TheCamera:GetHeadingTarget() + rotamount)
		end
        --UpdateCameraHeadings()
    elseif self.inst.HUD ~= nil and self.inst.HUD:IsMapScreenOpen() then
        TheCamera:SetHeadingTarget(TheCamera:GetHeadingTarget() + rotamount)
        TheCamera:Snap()
    end
end

function PlayerController:GetHoverTextOverride()
    return self.placer_recipe ~= nil and (STRINGS.UI.HUD.BUILD.." "..(STRINGS.NAMES[string.upper(self.placer_recipe.name)] or STRINGS.UI.HUD.HERE)) or nil
end

function PlayerController:CancelPlacement(cache)
    if not cache then
        self.placer_cached = nil
    elseif self.placer_recipe ~= nil then
        self.placer_cached = { self.placer_recipe, self.placer_recipe_skin }
        --V2C: Leave cache alone if recipe is already nil
        --     This can get called repeatedly when controls are disabled
    end

    if self.placer ~= nil then
        self.placer:Remove()
        self.placer = nil
    end
    self.placer_recipe = nil
    self.placer_recipe_skin = nil
end

function PlayerController:CancelDeployPlacement()
    self.deploy_mode = not TheInput:ControllerAttached()
    if self.deployplacer ~= nil then
        self.deployplacer:Remove()
        self.deployplacer = nil
    end
end

function PlayerController:StartBuildPlacementMode(recipe, skin)
    self.placer_cached = nil
    self.placer_recipe = recipe
    self.placer_recipe_skin = skin

    if self.placer ~= nil then
        self.placer:Remove()
    end
    self.placer =
        skin ~= nil and
        SpawnPrefab(recipe.placer, skin, nil, self.inst.userid) or
        SpawnPrefab(recipe.placer)

    self.placer.components.placer:SetBuilder(self.inst, recipe)
    self.placer.components.placer.testfn = function(pt, rot)
        local builder = self.inst.replica.builder
        return builder ~= nil and builder:CanBuildAtPoint(pt, recipe, rot)
    end
end

function PlayerController:IsTwinStickAiming()
	return self.reticule ~= nil and self.reticule:IsTwinStickAiming()
end

function PlayerController:GetAOETargetingPos()
    return self.reticule ~= nil and self.reticule.targetpos or nil
end

function PlayerController:IsAOETargeting()
    return self.reticule ~= nil and self.reticule.inst.components.aoetargeting ~= nil
end

function PlayerController:HasAOETargeting()
    local item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if item then
		local isriding
		if item.components.aoetargeting and item.components.aoetargeting:IsEnabled() then
			if item.components.aoetargeting.allowriding then
				return true
			end
			isriding = self.inst.replica.rider
			isriding = isriding ~= nil and isriding:IsRiding()
			if not isriding then
				return true
			end
		end
		if item.components.aoecharging and item.components.aoecharging:IsEnabled() then
			if item.components.aoecharging.allowriding then
				return true
			end
			if isriding == nil then
				isriding = self.inst.replica.rider
				isriding = isriding ~= nil and isriding:IsRiding()
			end
			if not isriding then
				return true
			end
		end
	end
	return false
end

function PlayerController:TryAOETargeting()
    local item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if item ~= nil and item.components.aoetargeting ~= nil and item.components.aoetargeting:IsEnabled() then
		if not item.components.aoetargeting.allowriding then
			local rider = self.inst.replica.rider
			if rider and rider:IsRiding() then
				return false
			end
		end
        item.components.aoetargeting:StartTargeting()
		return true
    end
	return false
end

function PlayerController:StartAOETargetingUsing(item)
	if item ~= nil and item.components.aoetargeting ~= nil and item.components.aoetargeting:IsEnabled() then
		self:ClearActionHold()
		self:CancelPlacement()
		self:CancelDeployPlacement()
		self:CancelAOETargeting()
		self.inst.replica.inventory:ReturnActiveItem()
		item.components.aoetargeting:StartTargeting()
	end
end

function PlayerController:GetActiveSpellBook()
	return self.reticule.inst.components.spellbook ~= nil and self.reticule.inst or nil
end

function PlayerController:CancelAOETargeting()
    if self.reticule ~= nil and self.reticule.inst.components.aoetargeting ~= nil then
        self.reticule.inst.components.aoetargeting:StopTargeting()
    end
end

local function _CalcAOEChargingStartingRotation(self)
	--handler should always exist when we get here
	--nil return only when mouse position unavailable, should not be possible normally
	if self.handler then
		if not TheInput:ControllerAttached() then
			local pos = TheInput:GetWorldPosition()
			return pos and self.inst:GetAngleToPoint(pos) or nil
		else
			local dir = GetWorldControllerVector()
			return dir and math.atan2(-dir.z, dir.x) * RADIANS or self.inst.Transform:GetRotation()
		end
	end
end

function PlayerController:TryAOECharging(force_rotation, iscontroller)
	local item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if item and item.components.aoecharging and item.components.aoecharging:IsEnabled() and not self:IsBusy() then
		if not item.components.aoecharging.allowriding then
			local rider = self.inst.replica.rider
			if rider and rider:IsRiding() then
				return false
			end
		end
		if self.inst.sg then
			if force_rotation then
				--server received remote rpc
				self:OnRemoteBufferedAction()
			else
				--server or prediction client
				force_rotation = _CalcAOEChargingStartingRotation(self)
			end
			if force_rotation then
				self.inst.Transform:SetRotation(force_rotation)
				self.inst.sg:GoToState("slingshot_charge")
			end
		else
			--non-prediction client
			--We still need to know our desired starting angle for the RPC,
			--but we can't set transform rotation on non-prediction clients
			force_rotation = _CalcAOEChargingStartingRotation(self)
		end
		if not self.ismastersim and force_rotation then
			self.remote_controls[iscontroller and CONTROL_CONTROLLER_ALTACTION or CONTROL_SECONDARY] = 0
			SendRPCToServer(RPC.AOECharging, force_rotation, iscontroller and 2 or 1)
		end
		return true
	end
	return false
end

function PlayerController:OnRemoteAOECharging(rotation, startflag)
	if self.ismastersim and self:IsEnabled() and self.handler == nil then
		if startflag then
			local iscontroller = startflag == 2
			self.remote_controls[iscontroller and CONTROL_CONTROLLER_ALTACTION or CONTROL_SECONDARY] = 0
			self:TryAOECharging(rotation, iscontroller)
		elseif self.inst.sg:HasStateTag("aoecharging") then
			self.inst.Transform:SetRotation(rotation)
		end
	end
end

function PlayerController:RemoteAOEChargingDir(rotation)
	SendRPCToServer(RPC.AOECharging, rotation)
end

function PlayerController:EchoReticuleAt(x, y, z)
    local reticule = SpawnPrefab(self.reticule.reticuleprefab)
    if reticule ~= nil then
        reticule.Transform:SetPosition(x, 0, z)
        if reticule.Flash ~= nil then
            reticule:Flash()
        else
            reticule:DoTaskInTime(1, reticule.Remove)
        end
    end
end

function PlayerController:RefreshReticule(item)
    item = item or self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if self.reticule ~= nil then
        self.reticule:DestroyReticule()
    end
    self.reticule = item ~= nil and item.components.reticule or self.inst.components.reticule
    if self.reticule ~= nil and self.reticule.reticule == nil and (self.reticule.mouseenabled or TheInput:ControllerAttached()) then
        self.reticule:CreateReticule()
		if self.reticule.reticule ~= nil and (not self:IsEnabled() or self.reticule:ShouldHide()) then
            self.reticule.reticule:Hide()
        end
    end
end

local function TargetIsHostile(inst, target)
    if inst.HostileTest ~= nil then
        return inst:HostileTest(target)
	elseif target.HostileToPlayerTest ~= nil then
		return target:HostileToPlayerTest(inst)
    else
        return target:HasTag("hostile")
    end
end

local function ValidateAttackTarget(combat, target, force_attack, x, z, has_weapon, reach)
	if not combat:CanTarget(target) or target:HasTag("stealth") then
        return false
    end

    --no combat if light/extinguish target
    local targetcombat = target.replica.combat
    if targetcombat ~= nil then
        if combat:IsAlly(target) then
            return false
		elseif not (force_attack or combat:IsRecentTarget(target)) then
			local inst = combat.inst
			if target.HostileToPlayerTest ~= nil and target:HasTag("shadowsubmissive") and not target:HostileToPlayerTest(inst) then
				--shadowsubmissive needs to ignore GetTarget() test,
				--since they have you targeted even when not hostile
				return false
			elseif targetcombat:GetTarget() ~= inst then
				--must use force attack non-hostile creatures
				if not TargetIsHostile(inst, target) then
					return false
				end
				--must use force attack on players' followers
				local follower = target.replica.follower
				if follower ~= nil then
					local leader = follower:GetLeader()
					if leader ~= nil and
						leader:HasTag("player") and
						leader.replica.combat:GetTarget() ~= inst then
						return false
					end
				end
			end
		end
    end

    --Now we ensure the target is in range
    --light/extinguish targets may not have physics
    reach = reach + target:GetPhysicsRadius(0)
    return target:GetDistanceSqToPoint(x, 0, z) <= reach * reach
end

local REGISTERED_FIND_ATTACK_TARGET_TAGS = TheSim:RegisterFindTags({ "_combat" }, { "INLIMBO" })

function PlayerController:GetAttackTarget(force_attack, force_target, isretarget, use_remote_predict)
	if self.inst:HasAnyTag("playerghost", "weregoose") or
		(self.classified and self.classified.inmightygym:value() > 0)
	then
        return
    end

	local inventory = self.inst.replica.inventory
	if inventory:IsHeavyLifting() or inventory:IsFloaterHeld() then
		return
	end

    local combat = self.inst.replica.combat
    if combat == nil then
        return
    end

    --Don't want to spam the attack button before the server actually starts the buffered action
    if not self.ismastersim and (self.remote_controls[CONTROL_ATTACK] or 0) > 0 then
        return
    end

    if isretarget and force_target and not IsEntityDead(force_target) and CanEntitySeeTarget(self.inst, force_target) then
        return force_target
    end

    if self.inst.sg ~= nil then
		if self.inst.sg:HasStateTag(use_remote_predict and self.remote_authority and self.remote_predicting and "abouttoattack" or "attack") then
            return
        end
    elseif self.inst:HasTag("attack") then
        return
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local attackrange = combat:GetAttackRangeWithWeapon()
    local rad = self.directwalking and attackrange or attackrange + 6
    --"not self.directwalking" is autowalking

    --Beaver teeth counts as having a weapon
    local has_weapon = self.inst:HasTag("beaver")
    if not has_weapon then
		local tool = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if tool ~= nil then
            local inventoryitem = tool.replica.inventoryitem
            has_weapon = inventoryitem ~= nil and inventoryitem:IsWeapon()
            if has_weapon and not force_attack and tool:HasTag("propweapon") then
                --don't require pressing force_attack when using prop weapons
                force_attack = true
            end
        end
    end

    local reach = self.inst:GetPhysicsRadius(0) + rad + .1

    if force_target ~= nil then
        return ValidateAttackTarget(combat, force_target, force_attack, x, z, has_weapon, reach) and force_target or nil
    end

    --To deal with entity collision boxes we need to pad the radius.
    --Only include combat targets for auto-targetting, not light/extinguish
    --See entityreplica.lua (re: "_combat" tag)
    local nearby_ents = TheSim:FindEntities_Registered(x, y, z, rad + 5, REGISTERED_FIND_ATTACK_TARGET_TAGS)

    local nearest_dist = math.huge
    isretarget = false --reusing variable for flagging when we've found recent target
    force_target = nil --reusing variable for our nearest target
    for i, v in ipairs(nearby_ents) do
        if ValidateAttackTarget(combat, v, force_attack, x, z, has_weapon, reach) and
            CanEntitySeeTarget(self.inst, v) then
            local dsq = self.inst:GetDistanceSqToInst(v)
            local dist = dsq <= 0 and 0 or math.max(0, math.sqrt(dsq) - v:GetPhysicsRadius(0))
            if not isretarget and combat:IsRecentTarget(v) then
                if dist < attackrange + .1 then
                    return v
                end
                isretarget = true
            end
            if dist < nearest_dist then
                nearest_dist = dist
                force_target = v
            end
        elseif not isretarget and combat:IsRecentTarget(v) then
            isretarget = true
        end
    end
    return force_target
end

function PlayerController:DoAttackButton(retarget, isleftmouse)
    --if retarget == nil and self:IsAOETargeting() then
    --    return
    --end

	local control = isleftmouse and CONTROL_PRIMARY or CONTROL_ATTACK
	local force_attack = TheInput:IsControlPressed(CONTROL_FORCE_ATTACK)
    local target = self:GetAttackTarget(force_attack, retarget, retarget ~= self:GetCombatTarget())

    if target == nil then
        --Still need to let the server know our attack button is down
        if not self.ismastersim and
            self.locomotor == nil and
			self.remote_controls[control] == nil
		then
			self:RemoteAttackButton(nil, nil, isleftmouse)
        end
        return --no target
    end

    if self.ismastersim then
        self.locomotor:PushAction(BufferedAction(self.inst, target, ACTIONS.ATTACK), true)
    elseif self.locomotor == nil then
		-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
		if ACTIONS.ATTACK.pre_action_cb ~= nil then
			ACTIONS.ATTACK.pre_action_cb(BufferedAction(self.inst, target, ACTIONS.ATTACK))
		end
		self:RemoteAttackButton(target, force_attack, isleftmouse)
    elseif self:CanLocomote() then
        local buffaction = BufferedAction(self.inst, target, ACTIONS.ATTACK)
        buffaction.preview_cb = function()
			local isreleased = not TheInput:IsControlPressed(control)
			self:RemoteAttackButton(target, force_attack, isleftmouse, isreleased)
        end
        self.locomotor:PreviewAction(buffaction, true)
    end
end

--V2C: isreleased at the end because added a lot later
function PlayerController:OnRemoteAttackButton(target, force_attack, noforce, isleftmouse, isreleased)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        --Check if target is valid, otherwise make
        --it nil so that we still attack and miss.
		self.remote_controls[isleftmouse and CONTROL_PRIMARY or CONTROL_ATTACK] = 0
        if target ~= nil and not noforce then
			if self.inst.sg:HasStateTag(self.remote_authority and self.remote_predicting and "abouttoattack" or "attack") then
                self.inst.sg.statemem.chainattack_cb = function()
                    self:OnRemoteAttackButton(target, force_attack)
                end
            else
				target = self:GetAttackTarget(force_attack, target, target ~= self:GetCombatTarget(), true)
                self.attack_buffer = BufferedAction(self.inst, target, ACTIONS.ATTACK, nil, nil, nil, nil, true)
                self.attack_buffer._predictpos = true
            end
        else
            target = target ~= nil and self:GetAttackTarget(force_attack, target) or nil
            if target ~= nil then
                self.attack_buffer = BufferedAction(self.inst, target, ACTIONS.ATTACK)
            end
        end
		if isreleased then
			self.remote_controls[CONTROL_ATTACK] = nil
		end
    end
end

--V2C: isreleased at the end because added a lot later
function PlayerController:RemoteAttackButton(target, force_attack, isleftmouse, isreleased)
	self.remote_controls[isleftmouse and CONTROL_PRIMARY or CONTROL_ATTACK] = target and BUTTON_REPEAT_COOLDOWN or 0
    if self.locomotor ~= nil then
		SendRPCToServer(RPC.AttackButton, target, force_attack, nil, isleftmouse, isreleased)
    elseif target ~= nil then
		SendRPCToServer(RPC.AttackButton, target, force_attack, true, isleftmouse, isreleased)
    else
		SendRPCToServer(RPC.AttackButton, nil, nil, nil, isleftmouse, isreleased)
    end
end

local function ValidateHaunt(target)
    return target:HasActionComponent("hauntable")
end

local function ValidateBugNet(target)
    return not IsEntityDead(target)
end

local function ValidateUnsaddler(target)
    return not IsEntityDead(target)
end

local function ValidateCorpseReviver(target, inst)
    --V2C: revivablecorpse is on clients as well
    return target.components.revivablecorpse:CanBeRevivedBy(inst)
end

local function GetPickupAction(self, target, tool)
    if target:HasTag("smolder") then
        return ACTIONS.SMOTHER
    elseif tool ~= nil then
        if target:HasTag("LunarBuildup") and tool:HasTag("MINE_tool") then
            return ACTIONS.REMOVELUNARBUILDUP
        end
        for k, v in pairs(TOOLACTIONS) do
            if target:HasTag(k.."_workable") then
                if tool:HasTag(k.."_tool") then
                    return ACTIONS[k]
                end
                break
            end
        end
    end

    if target:HasTag("quagmireharvestabletree") and not target:HasTag("fire") then
        return ACTIONS.HARVEST_TREE
    elseif target:HasTag("trapsprung") then
        return ACTIONS.CHECKTRAP
    elseif target:HasTag("minesprung") and not target:HasTag("mine_not_reusable") then
        return ACTIONS.RESETMINE
    elseif target:HasTag("inactive") and not target:HasTag("activatable_forcenopickup") and target.replica.inventoryitem == nil then
		return (not target:HasTag("wall") or self.inst:IsNear(target, 2.5))
			and ACTIONS.ACTIVATE
			or nil
    elseif target.replica.inventoryitem ~= nil and
        target.replica.inventoryitem:CanBePickedUp(self.inst) and
		not (target:HasTag("heavy") or (target:HasTag("fire") and not target:HasTag("lighter")) or target:HasTag("catchable")) and
        not target:HasTag("spider") then
        if self:HasItemSlots() or target.replica.equippable ~= nil then
            return ACTIONS.PICKUP
        end
        return nil
    elseif target:HasTag("pickable") and not target:HasTag("fire") then
        return ACTIONS.PICK
    elseif target:HasTag("harvestable") then
        return ACTIONS.HARVEST
    elseif target:HasTag("readyforharvest") or
        (target:HasTag("notreadyforharvest") and target:HasTag("withered")) then
        return ACTIONS.HARVEST
    elseif target:HasTag("tapped_harvestable") and not target:HasTag("fire") then
        return ACTIONS.HARVEST
    elseif target:HasTag("tendable_farmplant") and not self.inst:HasTag("mime") and not target:HasTag("fire") then
        return ACTIONS.INTERACT_WITH
    elseif target:HasTag("dried") and not target:HasTag("burnt") then
        return ACTIONS.HARVEST
    elseif target:HasTag("donecooking") and not target:HasTag("burnt") then
        return ACTIONS.HARVEST
    elseif target:HasTag("inventoryitemholder_take") and not target:HasTag("fire") then
        return ACTIONS.TAKEITEM
    elseif tool ~= nil and tool:HasTag("unsaddler") and target:HasTag("saddled") and not IsEntityDead(target) then
        return ACTIONS.UNSADDLE
    elseif tool ~= nil and tool:HasTag("brush") and target:HasTag("brushable") and not IsEntityDead(target) then
        return ACTIONS.BRUSH
    elseif self.inst.components.revivablecorpse ~= nil and target:HasTag("corpse") and ValidateCorpseReviver(target, self.inst) then
        return ACTIONS.REVIVE_CORPSE
    end
    --no action found
end

function PlayerController:IsDoingOrWorking()
    if self.inst.sg == nil then
        return self.inst:HasTag("doing")
            or self.inst:HasTag("working")
    elseif not self.ismastersim and self.inst:HasTag("autopredict") then
        return self.inst.sg:HasStateTag("doing")
            or self.inst.sg:HasStateTag("working")
    end
    return self.inst.sg:HasStateTag("doing")
        or self.inst.sg:HasStateTag("working")
        or self.inst:HasTag("doing")
        or self.inst:HasTag("working")
end

local TARGET_EXCLUDE_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "stealth" }
local REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS = TheSim:RegisterFindTags({ "_combat" }, TARGET_EXCLUDE_TAGS)

local PICKUP_TARGET_EXCLUDE_TAGS = { "catchable", "mineactive", "intense", "paired" }
local HAUNT_TARGET_EXCLUDE_TAGS = { "haunted", "catchable" }
for i, v in ipairs(TARGET_EXCLUDE_TAGS) do
    table.insert(PICKUP_TARGET_EXCLUDE_TAGS, v)
    table.insert(HAUNT_TARGET_EXCLUDE_TAGS, v)
end

local CATCHABLE_TAGS = { "catchable" }
local PINNED_TAGS = { "pinned" }
local CORPSE_TAGS = { "corpse" }
local GESTALTCAPTURABLE_TAGS = { "gestaltcapturable" }
local MOONSTORMSTATICCAPTURABLE_TAGS = { "moonstormstaticcapturable" }
function PlayerController:GetActionButtonAction(force_target)
    local isenabled, ishudblocking = self:IsEnabled()

    --Don't want to spam the action button before the server actually starts the buffered action
    --Also check if playercontroller is enabled
    --Also check if force_target is still valid
    if (not self.ismastersim and (self.remote_controls[CONTROL_ACTION] or 0) > 0) or
        (not isenabled and not ishudblocking) or
        self:IsBusy() or
        (force_target ~= nil and (not force_target.entity:IsVisible() or force_target:HasTag("INLIMBO") or force_target:HasTag("NOCLICK"))) then
        --"DECOR" should never change, should be safe to skip that check
        return

    elseif self.actionbuttonoverride ~= nil then
        local buffaction, usedefault = self.actionbuttonoverride(self.inst, force_target)
        if not usedefault or buffaction ~= nil then
            return buffaction
        end
		--(usedefault and buffaction == nil) ==> fallthrough
	end

	local inventory = self.inst.replica.inventory
	if inventory:IsFloaterHeld() then
		--hands are full!
		return
	elseif inventory:IsHeavyLifting() then
		local rider = self.inst.replica.rider
		if not (rider and rider:IsRiding()) then
			--hands are full!
			return
		end
	end

	if not self:IsDoingOrWorking() then
        local force_target_distsq = force_target ~= nil and self.inst:GetDistanceSqToInst(force_target) or nil

        if self.inst:HasTag("playerghost") then
            --haunt
            if force_target == nil then
                local target = FindEntity(self.inst, self.directwalking and 3 or 6, ValidateHaunt, nil, HAUNT_TARGET_EXCLUDE_TAGS)
                if CanEntitySeeTarget(self.inst, target) then
                    return BufferedAction(self.inst, target, ACTIONS.HAUNT)
                end
            elseif force_target_distsq <= (self.directwalking and 9 or 36) and
                not (force_target:HasTag("haunted") or force_target:HasTag("catchable")) and
                ValidateHaunt(force_target) then
                return BufferedAction(self.inst, force_target, ACTIONS.HAUNT)
            end
            return
        end

		local tool = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

        --bug catching (has to go before combat)
        if tool ~= nil and tool:HasTag(ACTIONS.NET.id.."_tool") then
            if force_target == nil then
                local target = FindEntity(self.inst, 5, ValidateBugNet, { "_health", ACTIONS.NET.id.."_workable" }, TARGET_EXCLUDE_TAGS)
                if CanEntitySeeTarget(self.inst, target) then
                    return BufferedAction(self.inst, target, ACTIONS.NET, tool)
                end
            elseif force_target_distsq <= 25 and
                force_target.replica.health ~= nil and
                ValidateBugNet(force_target) and
                force_target:HasTag(ACTIONS.NET.id.."_workable") then
                return BufferedAction(self.inst, force_target, ACTIONS.NET, tool)
            end
        end

		--catch gestalts
		if tool and tool:HasTag("gestalt_cage") then
			if force_target == nil then
				local target = FindEntity(self.inst, 8, nil, GESTALTCAPTURABLE_TAGS, TARGET_EXCLUDE_TAGS)
				if CanEntitySeeTarget(self.inst, target) then
					return BufferedAction(self.inst, target, ACTIONS.POUNCECAPTURE, tool)
				end
			elseif force_target_distsq <= 64 and force_target:HasTag("gestaltcapturable") then
				return BufferedAction(self.inst, force_target, ACTIONS.POUNCECAPTURE, tool)
			end
		end

        --catch moonstorm statics
        if tool and tool:HasTag("moonstormstatic_catcher") then
            if force_target == nil then
                local target = FindEntity(self.inst, 8, nil, MOONSTORMSTATICCAPTURABLE_TAGS, TARGET_EXCLUDE_TAGS)
                if CanEntitySeeTarget(self.inst, target) then
                    return BufferedAction(self.inst, target, ACTIONS.DIVEGRAB, tool)
                end
            elseif force_target_distsq <= 64 and force_target:HasTag("moonstormstaticcapturable") then
                return BufferedAction(self.inst, force_target, ACTIONS.DIVEGRAB, tool)
            end
        end

        --catching
        if self.inst:HasTag("cancatch") then
            if force_target == nil then
                local target = FindEntity(self.inst, 10, nil, CATCHABLE_TAGS, TARGET_EXCLUDE_TAGS)
                if CanEntitySeeTarget(self.inst, target) then
                    return BufferedAction(self.inst, target, ACTIONS.CATCH)
                end
            elseif force_target_distsq <= 100 and
                force_target:HasTag("catchable") then
                return BufferedAction(self.inst, force_target, ACTIONS.CATCH)
            end
        end

        --unstick
        if force_target == nil then
            local target = FindEntity(self.inst, self.directwalking and 3 or 6, nil, PINNED_TAGS, TARGET_EXCLUDE_TAGS)
            if CanEntitySeeTarget(self.inst, target) then
                return BufferedAction(self.inst, target, ACTIONS.UNPIN)
            end
        elseif force_target_distsq <= (self.directwalking and 9 or 36) and
            force_target:HasTag("pinned") then
            return BufferedAction(self.inst, force_target, ACTIONS.UNPIN)
        end

        --revive (only need to do this if i am also revivable)
        if self.inst.components.revivablecorpse ~= nil then
            if force_target == nil then
                local target = FindEntity(self.inst, 3, ValidateCorpseReviver, CORPSE_TAGS, TARGET_EXCLUDE_TAGS)
                if CanEntitySeeTarget(self.inst, target) then
                    return BufferedAction(self.inst, target, ACTIONS.REVIVE_CORPSE)
                end
            elseif force_target_distsq <= 9
                and force_target:HasTag("corpse")
                and ValidateCorpseReviver(force_target, self.inst) then
                return BufferedAction(self.inst, force_target, ACTIONS.REVIVE_CORPSE)
            end
        end

        --misc: pickup, tool work, smother
        if force_target == nil then
            local pickup_tags =
            {
                "_inventoryitem",
                "pickable",
                "donecooking",
                "readyforharvest",
                "notreadyforharvest",
                "harvestable",
                "trapsprung",
                "minesprung",
                "dried",
                "inactive",
                "smolder",
                "saddled",
                "brushable",
                "tapped_harvestable",
                "tendable_farmplant",
                "inventoryitemholder_take",
				"client_forward_action_target",
            }
            if tool ~= nil then
                if tool:HasTag("MINE_tool") then
                    table.insert(pickup_tags, "LunarBuildup")
                end
                for k, v in pairs(TOOLACTIONS) do
                    if tool:HasTag(k.."_tool") then
                        table.insert(pickup_tags, k.."_workable")
                    end
                end
            end
            if self.inst.components.revivablecorpse ~= nil then
                table.insert(pickup_tags, "corpse")
            end
            local x, y, z = self.inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, self.directwalking and 3 or 6, nil, PICKUP_TARGET_EXCLUDE_TAGS, pickup_tags)
            for i, v in ipairs(ents) do
				v = v.client_forward_target or v

                if v ~= self.inst and v.entity:IsVisible() and CanEntitySeeTarget(self.inst, v) then
                    local action = GetPickupAction(self, v, tool)
                    if action ~= nil then
                        return BufferedAction(self.inst, v, action, action ~= ACTIONS.SMOTHER and tool or nil)
                    end
                end
            end
        elseif force_target_distsq <= (self.directwalking and 9 or 36) then
            local action = GetPickupAction(self, force_target, tool)
            if action ~= nil then
                return BufferedAction(self.inst, force_target, action, action ~= ACTIONS.SMOTHER and tool or nil)
            end
        end
    end
end

function PlayerController:DoActionButton()
    --if self:IsAOETargeting() then
    --    return
    --end
    if self.placer == nil then
        local buffaction = self:GetActionButtonAction()
        if buffaction ~= nil then
            if self.ismastersim then
                self.locomotor:PushAction(buffaction, true)
                return
            elseif self.locomotor == nil then
                -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
                if buffaction.action.pre_action_cb ~= nil then
                    buffaction.action.pre_action_cb(buffaction)
                end
                self:RemoteActionButton(buffaction)
                return
            elseif self:CanLocomote() then
                if buffaction.action ~= ACTIONS.WALKTO then
                    buffaction.preview_cb = function()
                        self:RemoteActionButton(buffaction, not TheInput:IsControlPressed(CONTROL_ACTION) or nil)
                    end
                end
                self.locomotor:PreviewAction(buffaction, true)
            end
        end
    elseif self.placer.components.placer.can_build and
        self.inst.replica.builder ~= nil and
        not self.inst.replica.builder:IsBusy() then
        --do the placement
        self.inst.replica.builder:MakeRecipeAtPoint(self.placer_recipe,
            self.placer.components.placer.override_build_point_fn ~= nil and self.placer.components.placer.override_build_point_fn(self.placer) or self.placer:GetPosition(),
            self.placer:GetRotation(), self.placer_recipe_skin)
    elseif self.placer.components.placer.onfailedplacement ~= nil then
        self.placer.components.placer.onfailedplacement(self.inst, self.placer)
    end

    --Still need to let the server know our action button is down
    if not self.ismastersim and self.remote_controls[CONTROL_ACTION] == nil then
        self:RemoteActionButton()
    end
end

function PlayerController:OnRemoteActionButton(actioncode, target, isreleased, noforce, mod_name)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_controls[CONTROL_ACTION] = 0
        if actioncode ~= nil then
            SetClientRequestedAction(actioncode, mod_name)
            local buffaction = self:GetActionButtonAction(target)
            ClearClientRequestedAction()
            if buffaction ~= nil and buffaction.action.code == actioncode and buffaction.action.mod_name == mod_name then
                if buffaction.action.canforce and not noforce then
                    buffaction:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                    buffaction.forced = true
                end
                self.locomotor:PushAction(buffaction, true)
            --elseif mod_name ~= nil then
                --print("Remote action button action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
            --else
                --print("Remote action button action failed: "..tostring(ACTION_IDS[actioncode]))
            end
        end
        if isreleased then
            self.remote_controls[CONTROL_ACTION] = nil
        end
    end
end

function PlayerController:RemoteActionButton(action, isreleased)
    local actioncode = action ~= nil and action.action.code or nil
    local action_mod_name = action ~= nil and action.action.mod_name or nil
    local target = action ~= nil and action.target or nil
    local noforce = self.locomotor == nil and action ~= nil and action.action.canforce or nil
    self.remote_controls[CONTROL_ACTION] = action ~= nil and BUTTON_REPEAT_COOLDOWN or 0
    SendRPCToServer(RPC.ActionButton, actioncode, target, isreleased, noforce, action_mod_name)
end

function PlayerController:GetInspectButtonAction(target)
    return target ~= nil and
        target:HasTag("inspectable") and
        (self.inst.CanExamine == nil or self.inst:CanExamine()) and
        (self.inst.sg == nil or self.inst.sg:HasStateTag("moving") or self.inst.sg:HasStateTag("idle") or self.inst.sg:HasStateTag("channeling")) and
        (self.inst:HasTag("moving") or self.inst:HasTag("idle") or self.inst:HasTag("channeling")) and
        BufferedAction(self.inst, target, ACTIONS.LOOKAT) or
        nil
end

function PlayerController:DoInspectButton()
    if not self:IsEnabled()
        or (self.inst.HUD ~= nil and
            self.inst.HUD:IsPlayerAvatarPopUpOpen()) then
        --V2C: Closing the avatar popup takes priority
        return
    end
    local buffaction = TheInput:ControllerAttached() and self:GetInspectButtonAction(self:GetControllerTarget()) or nil
    if buffaction == nil then
        return
    end

    if buffaction.action == ACTIONS.LOOKAT and buffaction.target ~= nil then
        if buffaction.target.components.playeravatardata ~= nil and self.inst.HUD ~= nil then
            local client_obj = buffaction.target.components.playeravatardata:GetData()
            if client_obj ~= nil then
                client_obj.inst = buffaction.target
                self.inst.HUD:TogglePlayerInfoPopup(client_obj.name, client_obj, true, buffaction.target)
            end
        end
        if self.handler ~= nil then
			--assert(self.inst == ThePlayer)
            TheScrapbookPartitions:SetInspectedByCharacter(buffaction.target, self.inst.prefab)
        end
    end

    if self.ismastersim then
        self.locomotor:PushAction(buffaction, true)
    elseif self.locomotor == nil then
        -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
        if buffaction.action.pre_action_cb ~= nil then
            buffaction.action.pre_action_cb(buffaction)
        end
        self:RemoteInspectButton(buffaction)
    elseif self:CanLocomote() then
        buffaction.preview_cb = function()
            self:RemoteInspectButton(buffaction)
        end
        self.locomotor:PreviewAction(buffaction, true)
    end
end

function PlayerController:OnRemoteInspectButton(target)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        local buffaction = self:GetInspectButtonAction(target)
        if buffaction ~= nil then
            self.locomotor:PushAction(buffaction, true)
        --else
            --print("Remote inspect button action failed")
        end
    end
end

function PlayerController:RemoteInspectButton(action)
    SendRPCToServer(RPC.InspectButton, action.target)
end

function PlayerController:GetResurrectButtonAction()
    return self.inst:HasTag("playerghost") and
        (self.inst.sg == nil or self.inst.sg:HasStateTag("moving") or self.inst.sg:HasStateTag("idle")) and
        (self.inst:HasTag("moving") or self.inst:HasTag("idle")) and
        (self.inst.components.attuner:HasAttunement("remoteresurrector")
            or self.inst.components.attuner:HasAttunement("gravestoneresurrector")) and
        BufferedAction(self.inst, nil, ACTIONS.REMOTERESURRECT) or
        nil
end

function PlayerController:DoResurrectButton()
    if not self:IsEnabled() then
        return
    end
    local buffaction = self:GetResurrectButtonAction()
    if buffaction == nil then
        return
    elseif self.ismastersim then
        self.locomotor:PushAction(buffaction, true)
    elseif self.locomotor == nil then
        -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
        if buffaction.action.pre_action_cb ~= nil then
            buffaction.action.pre_action_cb(buffaction)
        end
        self:RemoteResurrectButton(buffaction)
    elseif self:CanLocomote() then
        buffaction.preview_cb = function()
            self:RemoteResurrectButton(buffaction)
        end
        self.locomotor:PreviewAction(buffaction, true)
    end
end

function PlayerController:OnRemoteResurrectButton()
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        local buffaction = self:GetResurrectButtonAction()
        if buffaction ~= nil then
            self.locomotor:PushAction(buffaction, true)
        --else
            --print("Remote resurrect button action failed")
        end
    end
end

function PlayerController:RemoteResurrectButton()
    SendRPCToServer(RPC.ResurrectButton)
end

function PlayerController:DoCharacterCommandWheelButton()
	local isenabled, ishudblocking = self:IsEnabled()
	if not (isenabled or ishudblocking) then
		return
	end

	local inventory = self.inst.replica.inventory
	if inventory and inventory:IsFloaterHeld() then
		return
	end

	--First, try find a spellbook in our inventory
	local invobject = inventory and inventory:FindItem(function(item)
		if item.components.spellbook and item.components.spellbook:CanBeUsedBy(self.inst) then
			--special case for wendy, just hardcoded here for now
			if item.prefab == "abigail_flower" and self.inst:HasTag("ghostfriend_notsummoned") then
				return false
			end
			return true
		end
		return false
	end)

	local target
	if invobject == nil then
		--Second, try see if we are a spellbook ourself
		if self.inst.components.spellbook and self.inst.components.spellbook:CanBeUsedBy(self.inst) then
			target = self.inst
		elseif self.inst.getlinkedspellbookfn then
			--Third, try see if we have a linked spellbook, like our pet
			target = self.inst:getlinkedspellbookfn()
			if target and not (target:IsValid() and target.components.spellbook and target.components.spellbook:CanBeUsedBy(self.inst)) then
				target = nil
			end
		end

		if target == nil then
			--No invobject or target spellbook found
			return
		end
	end

	local act =
		self.inst.HUD and
		self.inst.HUD:GetCurrentOpenSpellBook() == (invobject or target) and
		ACTIONS.CLOSESPELLBOOK or
		ACTIONS.USESPELLBOOK

	act = BufferedAction(self.inst, target, act, invobject)

	if not self.ismastersim then
		if self.locomotor == nil then
			act.non_preview_cb = function()
				self:RemoteCharacterCommandWheelButton(act)
			end
		elseif self:CanLocomote() then
			act.preview_cb = function()
				self:RemoteCharacterCommandWheelButton(act)
			end
		end
	end
	self:DoAction(act)
end

function PlayerController:OnRemoteCharacterCommandWheelButton(target)
	if self.ismastersim and self:IsEnabled() and self.handler == nil then
		local buffaction
		if target.components.spellbook and target.components.spellbook:CanBeUsedBy(self.inst) then
			if target.components.inventoryitem and target.components.inventoryitem:GetGrandOwner() then
				buffaction = BufferedAction(self.inst, nil, ACTIONS.USESPELLBOOK, target)
			elseif target == self.inst or (self.inst.getlinkedspellbookfn and target == self.inst:getlinkedspellbookfn()) then
				buffaction = BufferedAction(self.inst, target, ACTIONS.USESPELLBOOK)
			end
		end
		if buffaction then
			self:DoAction(buffaction)
		else
			--print("Remote character command wheel button action failed")
		end
	end
end

function PlayerController:RemoteCharacterCommandWheelButton(action)
	--Don't need to send CLOSESPELLBOOK
	if action.action == ACTIONS.USESPELLBOOK then
		SendRPCToServer(RPC.CharacterCommandWheelButton, action.target or action.invobject)
	end
end

function PlayerController:UsingMouse()
    return not TheInput:ControllerAttached()
end

function PlayerController:ClearActionHold()
    self.actionholding = false
    self.actionholdtime = nil
    self.lastheldaction = nil
    self.lastheldactiontime = nil
    self.actionrepeatfunction = nil
    if not self.ismastersim then
        SendRPCToServer(RPC.ClearActionHold)
    end
end

local ACTIONHOLD_CONTROLS = { CONTROL_PRIMARY, CONTROL_SECONDARY, CONTROL_CONTROLLER_ALTACTION, VIRTUAL_CONTROL_INV_ACTION_LEFT, VIRTUAL_CONTROL_INV_ACTION_RIGHT }
local function IsAnyActionHoldButtonHeld()
    for i, v in ipairs(ACTIONHOLD_CONTROLS) do
        if TheInput:IsControlPressed(v) then
            return true
        end
    end
    return false
end

function PlayerController:RepeatHeldAction()
    if not self.ismastersim then
        if self.actionrepeatfunction and (self.lastheldactiontime == nil or GetTime() - self.lastheldactiontime < 1) then
            self.lastheldactiontime = GetTime()
            if self.heldactioncooldown == 0 then
                self.heldactioncooldown = INVENTORY_ACTIONHOLD_REPEAT_COOLDOWN
                self:actionrepeatfunction()
            end
        else
            SendRPCToServer(RPC.RepeatHeldAction)
        end
    else
		if self.lastheldaction and
			self.lastheldaction:IsValid() and
			(self.lastheldactiontime == nil or GetTime() - self.lastheldactiontime < 1) and
			not (self.lastheldaction.target and self.lastheldaction.target:HasTag("NOCLICK"))
		then
            self.lastheldactiontime = GetTime()
            if self.heldactioncooldown == 0 then
                self.heldactioncooldown = ACTION_REPEAT_COOLDOWN
				--No fast-forward when repeating
				self.lastheldaction.options.no_predict_fastforward = true
                self:DoAction(self.lastheldaction)
            end
        elseif self.actionrepeatfunction and (self.lastheldactiontime == nil or GetTime() - self.lastheldactiontime < 1) then
            self.lastheldactiontime = GetTime()
            if self.heldactioncooldown == 0 then
                self.heldactioncooldown = INVENTORY_ACTIONHOLD_REPEAT_COOLDOWN
				--#V2C: #HACK use temp override flag since we don't know where
				--            the bufferedaction may come from, but we know it
				--            will be pushed to locomotor.
				self.locomotor.no_predict_fastforward = true
                self:actionrepeatfunction()
				self.locomotor.no_predict_fastforward = nil
            end
        else
            self:ClearActionHold()
        end
    end
end

function PlayerController:OnWallUpdate(dt)
    if self.handler then
        self:DoCameraControl()
    end
end

function PlayerController:GetCombatRetarget()
    if self.inst.sg then
        return self.inst.sg.statemem.retarget
    elseif self.inst.replica.combat then
        return self.inst.replica.combat:GetTarget()
    end
end

function PlayerController:GetCombatTarget()
    if self.inst.sg then
        return self.inst.sg.statemem.attacktarget
    end
    return nil
end

function PlayerController:OnUpdate(dt)
    if self._hack_ignore_held_controls then
        self._hack_ignore_held_controls = self._hack_ignore_held_controls - dt
        if self._hack_ignore_held_controls < 0 then
            self._hack_ignore_held_controls = nil
        end
    end

    local isenabled, ishudblocking = self:IsEnabled()
    self.predictionsent = false

    if self.actionholding and not (isenabled and IsAnyActionHoldButtonHeld()) then
        self:ClearActionHold()
    end

    if self.draggingonground and not (isenabled and TheInput:IsControlPressed(CONTROL_PRIMARY)) then
		local buffaction
        if self.locomotor ~= nil then
            self.locomotor:Stop()
			if isenabled then
				buffaction = self.locomotor.bufferedaction
			else
				self.locomotor:Clear()
			end
        end
        self.draggingonground = false
        self.startdragtime = nil
        TheFrontEnd:LockFocus(false)

		--restart any buffered actions that may have been pushed at the
		--same time as the user releasing draggingonground
		if buffaction then
			if self.ismastersim then
				self.locomotor:PushAction(buffaction)
			else
				self.locomotor:PreviewAction(buffaction)
			end
		end
    end

    --ishudblocking set to true lets us know that the only reason for isenabled returning false is due to HUD wanting to handle some input.
    if not isenabled then
		local allow_loco = ishudblocking
		if not allow_loco then
			if self.directwalking or self.dragwalking then
				if self.locomotor ~= nil then
					self.locomotor:Stop()
					self.locomotor:Clear()
				end
				self.directwalking = false
				self.dragwalking = false
				self.predictwalking = false
				if not self.ismastersim then
					self:RemoteStopWalking()
				end
			end
		end

        if self.handler ~= nil then
            self:CancelPlacement(true)
            self:CancelDeployPlacement()
            self:CancelAOETargeting()
			if not ishudblocking and self.inst.HUD ~= nil then
				self.inst.HUD:CloseSpellWheel()
			end

            if self.reticule ~= nil and self.reticule.reticule ~= nil then
                self.reticule.reticule:Hide()
            end

            if self.terraformer ~= nil then
                self.terraformer:Remove()
                self.terraformer = nil
            end
            
            self.LMBaction, self.RMBaction = nil, nil
            self.controller_target = nil
            self.controller_attack_target = nil
            self.controller_attack_target_ally_cd = nil
            if self.highlight_guy ~= nil and self.highlight_guy:IsValid() and self.highlight_guy.components.highlight ~= nil then
                self.highlight_guy.components.highlight:UnHighlight()
            end
            self.highlight_guy = nil
        end

        if self.ismastersim then
            self:ResetRemoteController()
        else
            self:RemoteStopAllControls()

            --Other than HUD blocking, we would've been enabled otherwise
            if not self:IsBusy() then
                self:DoPredictWalking(dt)
            end
        end

        self.controller_attack_override = nil
		self.recent_bufferedaction.act = nil

		if not allow_loco then
	        self.attack_buffer = nil
		end
    end

	if self:IsAOETargeting() then
		if not self.reticule.inst:IsValid() or self.reticule.inst:HasTag("fueldepleted") then
			self:CancelAOETargeting()
		else
			local inventoryitem = self.reticule.inst.replica.inventoryitem
			if inventoryitem ~= nil and not inventoryitem:IsGrandOwner(self.inst) then
				self:CancelAOETargeting()
			end
		end
	end

	if self.handler ~= nil and self.inst:HasTag("usingmagiciantool") then
		self:CancelPlacement()
        if not self:UsingMouse() then
            self:CancelDeployPlacement()
        end
		self:CancelAOETargeting()
	end

	--Attack controls are buffered and handled here in the update
	if self.attack_buffer ~= nil then
		if self.attack_buffer == CONTROL_ATTACK then
			self:DoAttackButton()
		elseif self.attack_buffer == CONTROL_CONTROLLER_ATTACK then
			self:DoControllerAttackButton()
		else
			if self.attack_buffer._predictpos then
				self.attack_buffer:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
			end
			if self.attack_buffer._controller then
				if self.attack_buffer.target == nil then
					self.controller_attack_override = self:IsControlPressed(CONTROL_CONTROLLER_ATTACK) and self.attack_buffer or nil
				end
				self:DoAction(self.attack_buffer)
			else
				--Check for duplicate actions
				local currentbuffaction = self.inst:GetBufferedAction()
				if not (currentbuffaction ~= nil and
						currentbuffaction.action == self.attack_buffer.action and
						currentbuffaction.target == self.attack_buffer.target)
				then
					self.locomotor:PushAction(self.attack_buffer, true)
				end
			end
		end
		self.attack_buffer = nil
	end

    if isenabled then
		--Restore cached placer
		if self.placer_cached ~= nil then
			if self.inst.replica.inventory:IsVisible() then
				self:StartBuildPlacementMode(unpack(self.placer_cached))
			end
			self.placer_cached = nil
		end


		if self.handler ~= nil then
			local controller_mode = TheInput:ControllerAttached()
			local new_highlight = nil
			if not self.inst:IsActionsVisible() then
				--Don't highlight when actions are hidden
			elseif controller_mode then
				self.LMBaction, self.RMBaction = nil, nil
				self:UpdateControllerTargets(dt)
				new_highlight = self.controller_target
			else
				self.controller_target = nil
				self.controller_attack_target = nil
				self.controller_attack_target_ally_cd = nil
				self.LMBaction, self.RMBaction = self.inst.components.playeractionpicker:DoGetMouseActions()

				--If an action has a target, highlight the target.
				--If an action has no target and no pos, then it should
				--be an inventory action where doer is ourself and we are
				--targeting ourself, so highlight ourself
				new_highlight =
					(self.LMBaction ~= nil
					and (self.LMBaction.target
						or (self.LMBaction.pos == nil and
							self.LMBaction.doer == self.inst and
							self.inst))) or
					(self.RMBaction ~= nil
					and (self.RMBaction.target
						or (self.RMBaction.pos == nil and
							self.RMBaction.doer == self.inst and
							self.inst))) or
					nil
			end

			local new_highlight_guy = new_highlight ~= nil and new_highlight.highlightforward or new_highlight
			if new_highlight_guy ~= self.highlight_guy then
				if self.highlight_guy ~= nil and self.highlight_guy:IsValid() and self.highlight_guy.components.highlight ~= nil then
					self.highlight_guy.components.highlight:UnHighlight()
				end
				self.highlight_guy = new_highlight_guy
			end

			if new_highlight_guy ~= nil and new_highlight_guy:IsValid() then
				if new_highlight_guy.components.highlight == nil then
					new_highlight_guy:AddComponent("highlight")
				end

				if not self.inst.shownothightlight then
					--V2C: check tags on the original, not the forwarded
					if new_highlight:HasTag("burnt") then
						new_highlight_guy.components.highlight:Highlight(.5, .5, .5)
					else
						new_highlight_guy.components.highlight:Highlight()
					end
				end
			else
				self.highlight_guy = nil
			end

			if self.reticule ~= nil and not (controller_mode or self.reticule.mouseenabled) then
				self.reticule:DestroyReticule()
				self.reticule = nil
			end

			if self.placer ~= nil and self.placer_recipe ~= nil and
				not (self.inst.replica.builder ~= nil and self.inst.replica.builder:IsBuildBuffered(self.placer_recipe.name)) then
				self:CancelPlacement()
			end

			local placer_item = controller_mode and self:GetCursorInventoryObject() or self.inst.replica.inventory:GetActiveItem()
			--show deploy placer
			if self.deploy_mode and
				self.placer == nil and
				placer_item ~= nil and
				placer_item.replica.inventoryitem ~= nil and
				placer_item.replica.inventoryitem:IsDeployable(self.inst) then

				local placer_name = placer_item.replica.inventoryitem:GetDeployPlacerName()
				local placer_skin = placer_item.AnimState:GetSkinBuild() --hack that relies on the build name to match the linked skinname
                if placer_skin == "" then
                    placer_skin = nil
                end
                if self.deployplacer ~= nil and (self.deployplacer.prefab ~= placer_name or self.deployplacer.skinname ~= placer_skin) then
					self:CancelDeployPlacement()
				end
				if self.deployplacer == nil then
					self.deployplacer = SpawnPrefab(placer_name, placer_skin, nil, self.inst.userid )
					if self.deployplacer ~= nil then
                        local placer = self.deployplacer.components.placer
						placer:SetBuilder(self.inst, nil, placer_item)
						placer.testfn = function(pt)
							local mouseover = (not placer:IsAxisAlignedPlacement()) and TheInput:GetWorldEntityUnderMouse() or nil
							return placer_item:IsValid() and
								placer_item.replica.inventoryitem ~= nil and
								placer_item.replica.inventoryitem:CanDeploy(pt, mouseover, self.inst, self.deployplacer.Transform:GetRotation()),
								(mouseover ~= nil and not mouseover:HasTag("walkableplatform") and not mouseover:HasTag("walkableperipheral") and not mouseover:HasTag("ignoremouseover")) or TheInput:GetHUDEntityUnderMouse() ~= nil
						end
						placer:OnUpdate(0) --so that our position is accurate on the first frame
					end
				end
			else
				self:CancelDeployPlacement()
			end

			local terraform = false
			local hideactionreticuleoverride = false
			local terraform_action = nil
			if controller_mode then
				local lmb, rmb = self:GetGroundUseAction()
				if rmb ~= nil then
					terraform = rmb.action.tile_placer ~= nil
					terraform_action = terraform and rmb.action or nil
					--hide reticule if not a point action (ie. STOPUSINGMAGICTOOL)
					hideactionreticuleoverride = rmb.pos == nil
				end
				--If reticule is from special action, hide it when other actions are available
				if not hideactionreticuleoverride and self.reticule ~= nil and self.reticule.inst == self.inst then
					if rmb == nil and self.controller_target ~= nil then
						lmb, rmb = self:GetSceneItemControllerAction(self.controller_target)
					end
					hideactionreticuleoverride = rmb ~= nil or not self:HasGroundUseSpecialAction(true)
				end
			else
				local rmb = self:GetRightMouseAction()
				if rmb ~= nil then
					terraform = rmb.action.tile_placer ~= nil and (rmb.action.show_tile_placer_fn == nil or rmb.action.show_tile_placer_fn(self:GetRightMouseAction()))
					terraform_action = terraform and rmb.action or nil
				end
			end

			--show right action reticule
			if self.placer == nil and self.deployplacer == nil then
				if terraform then
					if self.terraformer == nil then
						self.terraformer = SpawnPrefab(terraform_action.tile_placer)
						if self.terraformer ~= nil and self.terraformer.components.placer ~= nil then
							self.terraformer.components.placer:SetBuilder(self.inst)
							self.terraformer.components.placer:OnUpdate(0)
						end
					end
				elseif self.terraformer ~= nil then
					self.terraformer:Remove()
					self.terraformer = nil
				end

				if self.reticule ~= nil and self.reticule.reticule ~= nil then
					if hideactionreticuleoverride or self.reticule:ShouldHide() then
						self.reticule.reticule:Hide()
					else
						self.reticule.reticule:Show()
					end
				end
			else
				if self.terraformer ~= nil then
					self.terraformer:Remove()
					self.terraformer = nil
				end

				if self.reticule ~= nil and self.reticule.reticule ~= nil then
					self.reticule.reticule:Hide()
				end
			end

			if not self.actionholding and self.actionholdtime and IsAnyActionHoldButtonHeld() then
				if GetTime() - self.actionholdtime > START_DRAG_TIME then
					self.actionholding = true
				end
			end

			if not self.draggingonground and self.startdragtime ~= nil and TheInput:IsControlPressed(CONTROL_PRIMARY) then
				local now = GetTime()
				if now - self.startdragtime > START_DRAG_TIME then
					TheFrontEnd:LockFocus(true)
					self.draggingonground = true
				end
			end

			if TheFrontEnd:GetFocusWidget() ~= self.inst.HUD then
				if self.draggingonground then
					self.draggingonground = false
					self.startdragtime = nil

					TheFrontEnd:LockFocus(false)

					if self:CanLocomote() then
						self.locomotor:Stop()
						self.locomotor:Clear()
					end
				elseif self.actionholding then
					self:ClearActionHold()
				end
			end
		elseif self.ismastersim and self.inst:HasTag("nopredict") and self.remote_vector.y >= 3 then
			self.remote_vector.y = 0
			self.remote_predict_dir = nil
			self.remote_predict_stop_tick = nil
		end

		self:CooldownHeldAction(dt)
		if self.actionholding then
			self:RepeatHeldAction()
		end

		if self.controller_attack_override ~= nil and
			not (self.locomotor.bufferedaction == self.controller_attack_override and
				self:IsControlPressed(CONTROL_CONTROLLER_ATTACK)) then
			self.controller_attack_override = nil
		end
	end

    self:DoPredictHopping(dt)

	if not isenabled and not ishudblocking then
		self:DoClientBusyOverrideLocomote()
		return
	end

    --NOTE: isbusy is used further below as well
    local isbusy = self:IsBusy()

	--#HACK for hopping prediction
	--ignore server "busy" if server still "boathopping" but we're not anymore
	if isbusy and self.inst.sg ~= nil and self.inst:HasTag("boathopping") and not self.inst.sg:HasStateTag("boathopping") then
		isbusy = false
	end

	local allowdoubletapdiraction = false
	if isbusy then
		self:DoClientBusyOverrideLocomote()
		self.recent_bufferedaction.act = nil
	elseif self:DoPredictWalking(dt)
		or self:DoDragWalking(dt)
		then
		self.recent_bufferedaction.act = nil
		allowdoubletapdiraction = true
    else
        local aimingcannon = self.inst.components.boatcannonuser ~= nil and self.inst.components.boatcannonuser:GetCannon() ~= nil
        if not (aimingcannon or self.inst:HasTag("steeringboat") or self.inst:HasTag("rotatingboat")) then
            if self.wassteering then
                -- end reticule
                local boat = self.inst:GetCurrentPlatform()
                if boat then
                    boat:PushEvent("endsteeringreticule",{player=self.inst})
                end
                self.wassteering = nil
            end
			allowdoubletapdiraction = true
            self:DoDirectWalking(dt)
        elseif aimingcannon then

        else
            if not self.wassteering then
                -- start reticule
                local boat = self.inst:GetCurrentPlatform()
                if boat then
                    boat:PushEvent("starsteeringreticule",{player=self.inst})
                end
            end
            self.wassteering = true

            if self.inst:HasTag("steeringboat") then
                self:DoBoatSteering(dt)
            end
        end
    end

    --do automagic control repeats
	if self.handler ~= nil then
		--do double tap first =)
		self:DoDoubleTapDir(allowdoubletapdiraction)

        local isidle = self.inst:HasTag("idle")

        if not self.ismastersim then
            --clear cooldowns if we actually did something on the server
            --otherwise just decrease
            --if the server is still "idle", then it hasn't begun processing the action yet
            --when using movement prediction, the RPC is sent AFTER reaching the destination,
            --so we must also check that the server is not still "moving"
            self:CooldownRemoteController((isidle or (self.inst.sg ~= nil and self.inst:HasTag("moving"))) and dt or nil)
        end

        if self.inst.sg ~= nil then
            isidle = self.inst.sg:HasStateTag("idle") or (isidle and self.inst:HasTag("nopredict"))
        end
        if isidle then
            if TheInput:IsControlPressed(CONTROL_ACTION) then
                self:OnControl(CONTROL_ACTION, true)
            elseif TheInput:IsControlPressed(CONTROL_CONTROLLER_ACTION)
                and not self:IsDoingOrWorking() then
                self:OnControl(CONTROL_CONTROLLER_ACTION, true)
            end
        end
    end

    if self.ismastersim and self.handler == nil and not self.inst.sg.mem.localchainattack then
        if self.inst.sg.statemem.chainattack_cb ~= nil then
            if self.locomotor ~= nil and self.locomotor.bufferedaction ~= nil and self.locomotor.bufferedaction.action == ACTIONS.CASTAOE then
                self.inst.sg.statemem.chainattack_cb = nil
			elseif not self.inst.sg:HasStateTag(self.remote_authority and self.remote_predicting and "abouttoattack" or "attack") then
                --Handles chain attack commands received at irregular intervals
                local fn = self.inst.sg.statemem.chainattack_cb
                self.inst.sg.statemem.chainattack_cb = nil
                fn()
            end
        end
    elseif (self.ismastersim or self.handler ~= nil)
        and not (self.directwalking or isbusy)
        and not (self.locomotor ~= nil and self.locomotor.bufferedaction ~= nil and self.locomotor.bufferedaction.action == ACTIONS.CASTAOE) then
        local attack_control = false
        local currenttarget = self:GetCombatTarget()
        local retarget = self:GetCombatRetarget()
        if self.inst.sg ~= nil then
            attack_control = not self.inst.sg:HasStateTag("attack") or currenttarget ~= retarget
        else
            attack_control = not self.inst:HasTag("attack")
        end
        if attack_control then
			--@V2C: #FIX_LEFT_CLICK_UI_TRIGGERS_AUTO_ATTACK (see frontend.lua)
            attack_control = (self.handler == nil or not IsPaused())
                and ((self:IsControlPressed(CONTROL_ATTACK) and CONTROL_ATTACK) or
                    (self:IsControlPressed(CONTROL_PRIMARY) and CONTROL_PRIMARY) or
                    (self:IsControlPressed(CONTROL_CONTROLLER_ATTACK) and not self:IsAOETargeting() and CONTROL_CONTROLLER_ATTACK))
                or nil
            if attack_control ~= nil then
                if retarget and not IsEntityDead(retarget) and CanEntitySeeTarget(self.inst, retarget) then
                    --Handle chain attacking
                    if self.inst.sg ~= nil then
                        if self.handler == nil then
                            retarget = self:GetAttackTarget(false, retarget, retarget ~= currenttarget)
                            if retarget ~= nil then
                                self.locomotor:PushAction(BufferedAction(self.inst, retarget, ACTIONS.ATTACK), true)
                            end
                        elseif attack_control ~= CONTROL_CONTROLLER_ATTACK then
							self:DoAttackButton(retarget, attack_control == CONTROL_PRIMARY)
                        else
                            self:DoControllerAttackButton(retarget)
                        end
                    end
                elseif attack_control ~= CONTROL_PRIMARY and self.handler ~= nil then
                    --Check for starting a new attack
                    local isidle
                    if self.inst.sg ~= nil then
                        isidle = self.inst.sg:HasStateTag("idle") or (self.inst:HasTag("idle") and self.inst:HasTag("nopredict"))
                    else
                        isidle = self.inst:HasTag("idle")
                    end
                    if isidle then
                        self:OnControl(attack_control, true)
                    end
                end
            end
        end
    end

    if self.handler ~= nil and TheInput:TryRecacheController() then
        --Could also push pause screen, but it won't come up right
        --away if controls were disabled at the time of the switch
        TheWorld:PushEvent("continuefrompause")
        TheInput:EnableMouse(not TheInput:ControllerAttached())
    end
end

local function CheckControllerPriorityTagOrOverride(target, tag, override)
	if override ~= nil then
		return FunctionOrValue(override)
	end
	return target:HasTag(tag)
end

local function UpdateControllerAttackTarget(self, dt, x, y, z, dirx, dirz)
	local inventory = self.inst.replica.inventory
	if inventory:IsHeavyLifting() or inventory:IsFloaterHeld() or self.inst:HasTag("playerghost") then
        self.controller_attack_target = nil
        self.controller_attack_target_ally_cd = nil

		-- we can't target right now; disable target locking
		self.controller_targeting_lock_target = false
        return
    end

    local combat = self.inst.replica.combat

    self.controller_attack_target_ally_cd = math.max(0, (self.controller_attack_target_ally_cd or 1) - dt)

    if self.controller_attack_target ~= nil and
        not (combat:CanTarget(self.controller_attack_target) and
            CanEntitySeeTarget(self.inst, self.controller_attack_target)) then
        self.controller_attack_target = nil

		-- target is no longer valid; disable target locking
		self.controller_targeting_lock_target = false
        --it went invalid, but we're not resetting the age yet
    end

    --self.controller_attack_target_age = self.controller_attack_target_age + dt
    --if self.controller_attack_target_age < .3 then
        --prevent target flickering
    --    return
    --end

	local equipped_item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local forced_rad = equipped_item ~= nil and equipped_item.controller_use_attack_distance or 0

	local min_rad = 3
	local max_rad = math.max(forced_rad, combat:GetAttackRangeWithWeapon()) + 3.5
    local max_rad_sq = max_rad * max_rad

    --see entity_replica.lua for "_combat" tag

	local nearby_ents = TheSim:FindEntities_Registered(x, y, z, max_rad + 3, REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS)
    if self.controller_attack_target ~= nil then
        --Note: it may already contain controller_attack_target,
        --      so make sure to handle it only once later
        table.insert(nearby_ents, 1, self.controller_attack_target)
    end

    local target = nil
    local target_score = 0
    local target_isally = true
    local preferred_target =
        TheInput:IsControlPressed(CONTROL_CONTROLLER_ATTACK) and
        self.controller_attack_target or
        combat:GetTarget() or
        nil

	local current_controller_targeting_targets = {}
	local selected_target_index = 0
    for i, v in ipairs(nearby_ents) do
        if v ~= self.inst and (v ~= self.controller_attack_target or i == 1) then
            local isally = combat:IsAlly(v)
            if not (isally and
                    self.controller_attack_target_ally_cd > 0 and
                    v ~= preferred_target) and
                combat:CanTarget(v) then
                --Check distance including y value
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                local dx, dy, dz = x1 - x, y1 - y, z1 - z
                local dsq = dx * dx + dy * dy + dz * dz

				--include physics radius for max range check since we don't have (dist - phys_rad) yet
				local phys_rad = v:GetPhysicsRadius(0)
				local max_range = max_rad + phys_rad

				if dsq < max_range * max_range and CanEntitySeePoint(self.inst, x1, y1, z1) then
                    local dist = dsq > 0 and math.sqrt(dsq) or 0
                    local dot = dist > 0 and dx / dist * dirx + dz / dist * dirz or 0
					if dot > 0 or dist < min_rad + phys_rad then
						--now calculate score with physics radius subtracted
						dist = math.max(0, dist - phys_rad)
						local score = dot + 1 - 0.5 * dist * dist / max_rad_sq

                        if isally and not v.controller_priority_override_is_ally then
                            score = score * .25
						elseif CheckControllerPriorityTagOrOverride(v, "epic", v.controller_priority_override_is_epic) then
                            score = score * 5
						elseif CheckControllerPriorityTagOrOverride(v, "monster", v.controller_priority_override_is_monster) then
                            score = score * 4
						end

						if v.replica.combat:GetTarget() == self.inst or FunctionOrValue(v.controller_priority_override_is_targeting_player) then
                            score = score * 6
                        end

                        if v == preferred_target then
                            score = score * 10
                        end

						table.insert(current_controller_targeting_targets, v)
                        if score > target_score then
							selected_target_index = #current_controller_targeting_targets
                            target = v
                            target_score = score
                            target_isally = isally
                        end
                    end
                end
            end
        end
    end

	if self.controller_attack_target ~= nil and self.controller_targeting_lock_target then
		-- we have a target and target locking is enabled so only update the list of valid targets, ie. check for targets that have appeared or disappeared

		-- first check if any targets should be removed
		for idx_outer = #self.controller_targeting_targets, 1, -1 do
			local found = false
			local existing_target = self.controller_targeting_targets[idx_outer]
			for idx_inner = #current_controller_targeting_targets, 1, -1 do
				if existing_target == current_controller_targeting_targets[idx_inner] then
					-- we found the existing target in the list of current nearby entities so remove it from the current entity list to
					-- make later addition of new entities more straightforward
					table.remove(current_controller_targeting_targets, idx_inner)
					found = true
					break
				end
			end

			-- if the existing target isn't found in the nearby entities then remove it from the targets
			if not found then
				table.remove(self.controller_targeting_targets, idx_outer)
			end
		end

		-- now add new targets; check everything left in the nearby_ents table as we've been
		-- removing existing targets from it as we checked for targets that were no longer valid
		for i, v in ipairs(current_controller_targeting_targets) do
			table.insert(self.controller_targeting_targets, v)
		end

		-- fin
		return
	end

    if self.controller_target ~= nil and self.controller_target:IsValid() then
        if target ~= nil then
            if target:HasTag("wall") and
                self.classified ~= nil and
                self.classified.hasgift:value() and
                self.classified.hasgiftmachine:value() and
                self.controller_target:HasTag("giftmachine") then
                --if giftmachine has (Y) control priority, then it
                --should also have (X) control priority over walls
                target = nil
                target_isally = true
            end
        elseif self.controller_target:HasTag("wall") and not IsEntityDead(self.controller_target, true) then
            --if we have no (X) control target, then give
            --it to our (Y) control target if it's a wall
            target = self.controller_target
            target_isally = false
        end
    end

    if target ~= self.controller_attack_target then
        self.controller_attack_target = target
		self.controller_targeting_target_index = selected_target_index
        --self.controller_attack_target_age = 0
    end

    if not target_isally then
        --reset ally targeting cooldown
        self.controller_attack_target_ally_cd = nil
    end
end

local function UpdateControllerInteractionTarget(self, dt, x, y, z, dirx, dirz, heading_angle)
	local attack_target = self:GetControllerAttackTarget()
	if self.controller_targeting_lock_target and attack_target then
		self.controller_target = attack_target
		return
	elseif self.placer ~= nil or (self.deployplacer ~= nil and self.deploy_mode) or self.inst:HasTag("usingmagiciantool") then
        self.controller_target = nil
        self.controller_target_age = 0
        return
    elseif self.controller_target ~= nil
        and (not self.controller_target:IsValid() or
            self.controller_target:HasTag("INLIMBO") or
            self.controller_target:HasTag("NOCLICK") or
            not CanEntitySeeTarget(self.inst, self.controller_target)) then
        --"FX" and "DECOR" tag should never change, should be safe to skip that check
        self.controller_target = nil
        --it went invalid, but we're not resetting the age yet
    end

    self.controller_target_age = self.controller_target_age + dt
    if self.controller_target_age < .2 then
        --prevent target flickering
        return
    end

    --catching
    if self.inst:HasTag("cancatch") then
        local target = FindEntity(self.inst, 10, nil, CATCHABLE_TAGS, TARGET_EXCLUDE_TAGS)
        if CanEntitySeeTarget(self.inst, target) then
            if target ~= self.controller_target then
                self.controller_target = target
                self.controller_target_age = 0
            end
            return
        end
    end

    local equiped_item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

    if equiped_item and equiped_item.controller_should_use_attack_target and self.controller_attack_target ~= nil then
        if self.controller_target ~= self.controller_attack_target then
            self.controller_target = self.controller_attack_target
            self.controller_target_age = 0
        end
        return
    end

    --Fishing targets may have large radius, making it hard to target with normal priority
    local fishing = equiped_item ~= nil and equiped_item:HasTag("fishingrod")

    -- we want to never target our fishing hook, but others can
    local ocean_fishing_target = (equiped_item ~= nil and equiped_item.replica.oceanfishingrod ~= nil) and equiped_item.replica.oceanfishingrod:GetTarget() or nil

    local min_rad = 1.5
    local max_rad = 6
    local min_rad_sq = min_rad * min_rad
    local max_rad_sq = max_rad * max_rad

    local rad =
            self.controller_target ~= nil and
            math.max(min_rad, math.min(max_rad, math.sqrt(self.inst:GetDistanceSqToInst(self.controller_target)))) or
            max_rad
    local rad_sq = rad * rad + .1 --allow small error

    local nearby_ents = TheSim:FindEntities(x, y, z, fishing and max_rad or rad, nil, TARGET_EXCLUDE_TAGS)
    if self.controller_target ~= nil then
        --Note: it may already contain controller_target,
        --      so make sure to handle it only once later
        table.insert(nearby_ents, 1, self.controller_target)
    end

    local target = nil
    local target_score = 0
    local canexamine = (self.inst.CanExamine == nil or self.inst:CanExamine())
				and (not self.inst.HUD:IsPlayerAvatarPopUpOpen())
				and (self.inst.sg == nil or self.inst.sg:HasStateTag("moving") or self.inst.sg:HasStateTag("idle") or self.inst.sg:HasStateTag("channeling"))
				and (self.inst:HasTag("moving") or self.inst:HasTag("idle") or self.inst:HasTag("channeling"))

    local currentboat = self.inst:GetCurrentPlatform()
    local anglemax = currentboat and TUNING.CONTROLLER_BOATINTERACT_ANGLE or TUNING.CONTROLLER_INTERACT_ANGLE
    for i, v in ipairs(nearby_ents) do
		v = v.client_forward_target or v

        if v ~= ocean_fishing_target then

            --Only handle controller_target if it's the one we added at the front
            if v ~= self.inst and (v ~= self.controller_target or i == 1) and v.entity:IsVisible() then
                if v.entity:GetParent() == self.inst and v:HasTag("bundle") then
                    --bundling or constructing
                    target = v
                    break
                end

                -- Calculate the dsq to filter out objects, ignoring the y component for now.
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                local dx, dy, dz = x1 - x, y1 - y, z1 - z
                local dsq = dx * dx + dz * dz

                if fishing and v:HasTag("fishable") then
                    local r = v:GetPhysicsRadius(0)
                    if dsq <= r * r then
                        dsq = 0
                    end
                end

                if (dsq < min_rad_sq
                    or (dsq <= rad_sq
                        and (v == self.controller_target or
                            v == self.controller_attack_target or
                            dx * dirx + dz * dirz > 0))) and
                    CanEntitySeePoint(self.inst, x1, y1, z1) then
                    local shouldcheck = dsq < 1 -- Do not skip really close entities.
                    if not shouldcheck then
                        local epos = v:GetPosition()
                        local angletoepos = self.inst:GetAngleToPoint(epos)
                        local angleto = math.abs(anglediff(-heading_angle, angletoepos))
                        shouldcheck = angleto < anglemax
                    end
                    if shouldcheck then
                        -- Incorporate the y component after we've performed the inclusion radius test.
                        -- We wait until now because we might disqualify our controller_target if its transform has a y component,
                        -- but we still want to use the y component as a tiebreaker for objects at the same x,z position.
                        dsq = dsq + (dy * dy)

                        local dist = dsq > 0 and math.sqrt(dsq) or 0
                        local dot = dist > 0 and dx / dist * dirx + dz / dist * dirz or 0

                        --keep the angle component between [0..1]
                        local angle_component = (dot + 1) / 2

                        --distance doesn't matter when you're really close, and then attenuates down from 1 as you get farther away
                        local dist_component = dsq < min_rad_sq and 1 or min_rad_sq / dsq

                        --for stuff that's *really* close - ie, just dropped
                        local add = dsq < .0625 --[[.25 * .25]] and 1 or 0

                        --just a little hysteresis
                        local mult = v == self.controller_target and not v:HasTag("wall") and 1.5 or 1

                        local score = angle_component * dist_component * mult + add

                        --make it easier to target stuff dropped inside the portal when alive
                        --make it easier to haunt the portal for resurrection in endless mode
                        if v:HasTag("portal") then
                            score = score * (self.inst:HasTag("playerghost") and GetPortalRez() and 1.1 or .9)
                        end

                        if v:HasTag("hasfurnituredecoritem") then
                            score = score * 0.5
                        end

                        --print(v, angle_component, dist_component, mult, add, score)

                        if score < target_score or
                            (   score == target_score and
                                (   (target ~= nil and not (target.CanMouseThrough ~= nil and target:CanMouseThrough())) or
                                    (v.CanMouseThrough ~= nil and v:CanMouseThrough())
                                )
                            ) then
                            --skip
                        elseif canexamine and v:HasTag("inspectable") then
                            target = v
                            target_score = score
                        else
                            --this is kind of expensive, so ideally we don't get here for many objects
                            local lmb, rmb
                            if currentboat ~= v or score * 0.75 < target_score then -- Lower priority for scene items on the same boat.
                                lmb, rmb = self:GetSceneItemControllerAction(v)
                            end
                            if lmb ~= nil or rmb ~= nil then
                                target = v
                                target_score = score
                            else
                                local inv_obj = self:GetCursorInventoryObject()
                                if inv_obj ~= nil then
                                    rmb = self:GetItemUseAction(inv_obj, v)
                                    if rmb ~= nil and rmb.target == v then
                                        target = v
                                        target_score = score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if target ~= self.controller_target then
        self.controller_target = target
        self.controller_target_age = 0
    end
end

local function UpdateControllerConflictingTargets(self)
    local target, attacktarget = self.controller_target, self.controller_attack_target
    if target == nil or attacktarget == nil then
        return
    end
    -- NOTES(JBK): This is for handling when there are two targets on a controller but one should take super priority over the other.
    -- Most of this will be workarounds in appearance as there are no sure fire ways to guarantee what two entities should be prioritized by actions alone as they need additional context.
    if target ~= attacktarget then
        if target:HasTag("mermthrone") and attacktarget:HasTag("merm") then
            -- Inspecting a throne but could interact with a Merm, Merm takes priority.
            target = attacktarget
            self.controller_target_age = 0
        elseif target:HasTag("crabking_claw") and attacktarget:HasTag("crabking_claw") then
            -- Two claws let us try targeting the closest one because it will most likely be the one next to a boat.
            if self.inst:GetDistanceSqToInst(target) < self.inst:GetDistanceSqToInst(attacktarget) then
                attacktarget = target
            else
                target = attacktarget
                self.controller_target_age = 0
            end
        end
    end

    self.controller_target, self.controller_attack_target = target, attacktarget
end

function PlayerController:UpdateControllerTargets(dt)
	if self:IsAOETargeting() or
		self.inst:HasTag("sitting_on_chair") or
		(self.inst:HasTag("weregoose") and not self.inst:HasTag("playerghost")) or
		(self.classified and self.classified.inmightygym:value() > 0) then
        self.controller_target = nil
        self.controller_target_age = 0
        self.controller_attack_target = nil
        self.controller_attack_target_ally_cd = nil
        self.controller_targeting_lock_target = nil
        return
    end
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local heading_angle = -self.inst.Transform:GetRotation()
    local dirx = math.cos(heading_angle * DEGREES)
    local dirz = math.sin(heading_angle * DEGREES)
    UpdateControllerInteractionTarget(self, dt, x, y, z, dirx, dirz, heading_angle)
    UpdateControllerAttackTarget(self, dt, x, y, z, dirx, dirz)
    UpdateControllerConflictingTargets(self)
end

function PlayerController:GetControllerTarget()
    return self.controller_target ~= nil and self.controller_target:IsValid() and self.controller_target or nil
end

function PlayerController:GetControllerAttackTarget()
    return self.controller_attack_target ~= nil and self.controller_attack_target:IsValid() and self.controller_attack_target or nil
end

--[[ CharlesB: Disabled for now
function PlayerController:IsControllerTargetingModifierDown()
    return self.controller_targeting_modifier_down
end
]]

function PlayerController:CanLockTargets()
    return self.controller_targeting_lock_available
end

function PlayerController:IsControllerTargetLockEnabled()
	return self.controller_targeting_lock_target
end

function PlayerController:IsControllerTargetLocked()
	return self.controller_targeting_lock_target and self.controller_attack_target
end

function PlayerController:ControllerTargetLock(enable)
	if enable then
		-- only enable locking if there's a target
		if self.controller_targeting_lock_available and self.controller_attack_target then
			self.controller_targeting_lock_target = true
		end
	else
		-- disable locking at any time
		self.controller_targeting_lock_target = false
	end
end

function PlayerController:ControllerTargetLockToggle()
	if self:IsControllerTargetLockEnabled() then
		self:ControllerTargetLock(false)
	else
		self:ControllerTargetLock(true)
	end
end

function PlayerController:CycleControllerAttackTargetForward()
	local num_targets = #self.controller_targeting_targets
	if self.controller_targeting_lock_target and num_targets > 0 then
		self.controller_targeting_target_index = self.controller_targeting_target_index + 1
		if self.controller_targeting_target_index > num_targets then
			self.controller_targeting_target_index = 1
		end
		self.controller_attack_target = self.controller_targeting_targets[self.controller_targeting_target_index]
	end
end

function PlayerController:CycleControllerAttackTargetBack()
	local num_targets = #self.controller_targeting_targets
	if self.controller_targeting_lock_target and num_targets > 0 then
		self.controller_targeting_target_index = self.controller_targeting_target_index - 1
		if self.controller_targeting_target_index < 1 then
			self.controller_targeting_target_index = num_targets
		end
		self.controller_attack_target = self.controller_targeting_targets[self.controller_targeting_target_index]
	end
end


--------------------------------------------------------------------------
--remote_vector.y is used as a flag for stop/direct/drag walking
--since its value is never actually used in the walking function

function PlayerController:ResetRemoteController()
    self.remote_vector.y = 0
    if next(self.remote_controls) ~= nil then
        self.remote_controls = {}
    end
	self.remote_predict_dir = nil
	self.remote_predict_stop_tick = nil
end

local function ConvertPlatformRelativeToAbsoluteXZ(vec, platform)
	if platform == nil then
		return vec.x, vec.z
	elseif platform:IsValid() then
		local x, y, z = platform.entity:LocalToWorldSpace(vec.x, 0, vec.z)
		return x, z
	end
end

function PlayerController:GetRemoteDirectVector()
    return self.remote_vector.y == 1 and self.remote_vector or nil
end

function PlayerController:GetRemoteDragPosition()
    return self.remote_vector.y == 2 and self.remote_vector or nil
end

--V2C: These aren't really meant for use outside of this component XD
function PlayerController:GetRemotePredictPosition()
	if self.remote_vector.y >= 3 then
		if self.remote_vector.platform == nil then
			return self.remote_vector
		elseif self.remote_vector.platform:IsValid() then
			local x, y, z = self.remote_vector.platform.entity:LocalToWorldSpace(self.remote_vector.x, 0, self.remote_vector.z)
			if x then
				return Vector3(x, self.remote_vector.y, z)
			end
		end
	end
end

--V2C; This one can be used externally XD
function PlayerController:GetRemotePredictPositionExternal()
	if self.remote_vector.y >= 3 then
		local x, z = ConvertPlatformRelativeToAbsoluteXZ(self.remote_vector, self.remote_vector.platform)
		if x then
			return Vector3(x, 0, z)
		end
	end
end

function PlayerController:GetRemotePredictStopXZ()
	if self.remote_predict_stop_tick + 1 == GetTick() and self.remote_vector.y == 0 then
		return ConvertPlatformRelativeToAbsoluteXZ(self.remote_vector, self.remote_vector.platform)
	end
end

function PlayerController:OnRemoteDirectWalking(x, z)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_vector.x = x
        self.remote_vector.y = 1
        self.remote_vector.z = z
		self.remote_vector.platform = nil
		self.remote_predict_dir = nil
		self.remote_predict_stop_tick = nil
    end
end

function PlayerController:OnRemoteDragWalking(x, z)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_vector.x = x
        self.remote_vector.y = 2
        self.remote_vector.z = z
		self.remote_vector.platform = nil
		self.remote_predict_dir = nil
		self.remote_predict_stop_tick = nil
    end
end

function PlayerController:OnRemotePredictWalking(x, z, isdirectwalking, isstart, platform, overridemovetime)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_vector.x = x
        self.remote_vector.y = isdirectwalking and 3 or 4
        self.remote_vector.z = z
		self.remote_vector.platform = platform
		self.remote_predict_dir = nil
		self.remote_predict_stop_tick = nil
        if isstart then
            self.locomotor:RestartPredictMoveTimer()
		elseif overridemovetime then
			self.locomotor:OverridePredictTimer(GetTime() - overridemovetime)
        end
    end
end

function PlayerController:OnRemotePredictOverrideLocomote(dir)
	if self.ismastersim and self.handler == nil and self.inst.sg:HasStateTag("overridelocomote") then
		if self:IsEnabled() and not self:IsBusy() or self.classified.busyremoteoverridelocomote:value() then
			if self.inst.sg:HasStateTag("canrotate") then
				self.locomotor:SetMoveDir(dir)
			end
			self.inst:PushEvent("locomote", { dir = dir, remoteoverridelocomote = true })
		end
	end
end

function PlayerController:OnRemoteStartHop(x, z, platform)
    if not self.ismastersim then return end
    if not self:IsEnabled() then return end
    if not self.handler == nil then return end

    local my_x, my_y, my_z = self.inst.Transform:GetWorldPosition()
    local target_x, target_y, target_z = x, 0, z
    local platform_for_velocity_calculation = platform

    if platform ~= nil then
        target_x, target_z = platform.components.walkableplatform:GetEmbarkPosition(my_x, my_z)
    else
        platform_for_velocity_calculation = self.inst:GetCurrentPlatform()
    end

	if platform == nil and (platform_for_velocity_calculation == nil or TheWorld.Map:IsOceanAtPoint(target_x, 0, target_z)) then
        return
	end

    local hop_dir_x, hop_dir_z = target_x - my_x, target_z - my_z
    local hop_distance_sq = hop_dir_x * hop_dir_x + hop_dir_z * hop_dir_z

    local target_velocity_rubber_band_distance = 0
    local platform_velocity_x, platform_velocity_z = 0, 0
    if platform_for_velocity_calculation ~= nil then
        local platform_physics = platform_for_velocity_calculation.Physics
        if platform_physics ~= nil then
            platform_velocity_x, platform_velocity_z = platform_physics:GetVelocity()
            if platform_velocity_x ~= 0 or platform_velocity_z ~= 0 then
                local hop_distance = math.sqrt(hop_distance_sq)
                local normalized_hop_dir_x, normalized_hop_dir_z = hop_dir_x / hop_distance, hop_dir_z / hop_distance
                local velocity = math.sqrt(platform_velocity_x * platform_velocity_x + platform_velocity_z * platform_velocity_z)
                local normalized_platform_velocity_x, normalized_platform_velocity_z = platform_velocity_x / velocity, platform_velocity_z / velocity
                local hop_dir_dot_platform_velocity = normalized_platform_velocity_x * normalized_hop_dir_x + normalized_platform_velocity_z * normalized_hop_dir_z
                if hop_dir_dot_platform_velocity > 0 then
                    target_velocity_rubber_band_distance = RUBBER_BAND_PING_TOLERANCE_IN_SECONDS * velocity * hop_dir_dot_platform_velocity
                end
            end
        end
    end

	local hop_rubber_band_distance = RUBBER_BAND_DISTANCE + target_velocity_rubber_band_distance + self.locomotor:GetHopDistance()
    local hop_rubber_band_distance_sq = hop_rubber_band_distance * hop_rubber_band_distance

    if hop_distance_sq > hop_rubber_band_distance_sq then
        print("Hop discarded:", "\ntarget_velocity_rubber_band_distance", target_velocity_rubber_band_distance, "\nplatform_velocity_x", platform_velocity_x, "\nplatform_velocity_z", platform_velocity_z, "\nhop_distance", math.sqrt(hop_distance_sq), "\nhop_rubber_band_distance", math.sqrt(hop_rubber_band_distance_sq))
        return
    end

    self.remote_vector.y = 6
	self.remote_predict_dir = nil
	self.remote_predict_stop_tick = nil
	self.locomotor:StartHopping(x,z,platform)
end

function PlayerController:OnRemoteStopWalking()
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_vector.y = 0
		self.remote_predict_dir = nil
		self.remote_predict_stop_tick = nil
    end
end

function PlayerController:OnRemoteStopHopping()
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_vector.y = 0
		self.remote_predict_dir = nil
		self.remote_predict_stop_tick = nil
    end
end

function PlayerController:RemoteDirectWalking(x, z)
    if self.remote_vector.x ~= x or self.remote_vector.z ~= z or self.remote_vector.y ~= 1 then
        SendRPCToServer(RPC.DirectWalking, x, z) -- x and z are directions, not positions, so we don't need it to be platform relative
        self.remote_vector.x = x
        self.remote_vector.y = 1
        self.remote_vector.z = z
    end
end

function PlayerController:RemoteDragWalking(x, z)
    if self.remote_vector.x ~= x or self.remote_vector.z ~= z or self.remote_vector.y ~= 2 then
		local platform, pos_x, pos_z = self:GetPlatformRelativePosition(x, z)
        SendRPCToServer(RPC.DragWalking, pos_x, pos_z, platform, platform ~= nil)
        self.remote_vector.x = x
        self.remote_vector.y = 2
        self.remote_vector.z = z
    end
end

function PlayerController:RemotePredictWalking(x, z, isstart, overridemovetime, overridedirect)
	local y = (overridedirect or self.directwalking) and 3 or 4
    if self.remote_vector.x ~= x or self.remote_vector.z ~= z or (self.remote_vector.y ~= y and self.remote_vector.y ~= 0) then
		local platform, pos_x, pos_z = self:GetPlatformRelativePosition(x, z)
		SendRPCToServer(RPC.PredictWalking, pos_x, pos_z, self.directwalking, isstart, platform, platform ~= nil, overridemovetime)
        self.remote_vector.x = x
        self.remote_vector.y = y
        self.remote_vector.z = z
        self.predictionsent = true
    end
end

function PlayerController:RemotePredictOverrideLocomote()
	SendRPCToServer(RPC.PredictOverrideLocomote, self.inst.Transform:GetRotation())
end

function PlayerController:RemoteStopWalking()
    if self.remote_vector.y ~= 0 then
        SendRPCToServer(RPC.StopWalking)
        self.remote_vector.y = 0
    end
end

function PlayerController:DoPredictHopping(dt)
    if ThePlayer == self.inst and not self.ismastersim then
		if self.locomotor then
			if self.locomotor.hopping and not self.is_hopping then
				local embarker = self.inst.components.embarker
                local disembark_x, disembark_z = embarker:GetEmbarkPosition()
                local target_platform = embarker.embarkable
                SendRPCToServer(RPC.StartHop, disembark_x, disembark_z, target_platform, target_platform ~= nil)
            end
			self.is_hopping = self.locomotor.hopping
        else
            self.is_hopping = false
        end
    end
end

function PlayerController:IsLocalOrRemoteHopping()
	return self.remote_vector.y == 6 or (self.locomotor ~= nil and self.locomotor.hopping)
end

function PlayerController:DoClientBusyOverrideLocomote()
	--This is specifically for passing overridelocomote events to the
	--server when we're in a busy state and/or controls are disabled.
	--e.g. Moose tackle can be cancelled using directional input, but
	--     the state itself is still busy.
	if not self.ismastersim and
		self.handler ~= nil and
		self.classified and
		self.classified.busyremoteoverridelocomote:value() and
		GetWorldControllerVector() ~= nil
	then
		self:RemotePredictOverrideLocomote()
	end
end

function PlayerController:DoPredictWalking(dt)
    if self.ismastersim then
		if self:IsLocalOrRemoteHopping() then
			return
		end
		local pt = self:GetRemotePredictPosition()
		if pt then
            local x0, y0, z0 = self.inst.Transform:GetWorldPosition()
            local distancetotargetsq = distsq(pt.x, pt.z, x0, z0)
			local stopdistancesq = self.inst.sg:HasStateTag("floating") and 0.0001 or 0.05

			if pt.y == 5 and (
				self.locomotor.bufferedaction ~= nil or
                self.inst.bufferedaction ~= nil or
				not self.inst.sg:HasAnyStateTag("idle", "moving")
			) then
                --We're performing an action now, so ignore predict walking
                self.directwalking = false
                self.dragwalking = false
                self.predictwalking = false
                if distancetotargetsq <= stopdistancesq then
                    self.remote_vector.y = 0
					self.remote_predict_dir = nil
					self.remote_predict_stop_tick = nil
                end
                return true
            end

            if pt.y < 5 then
                self.inst:ClearBufferedAction()
            end

			local dir = math.atan2(z0 - pt.z, pt.x - x0) * RADIANS
            if distancetotargetsq > stopdistancesq then
				self.locomotor:RunInDirection(dir)
				self.remote_predict_dir = dir
            else
				if self.remote_authority and self.remote_predict_dir and DiffAngle(dir, self.remote_predict_dir) >= 90 then
					--overshot?
					--FIXME(JBK): Boat handling.
					--FIXED(V2C): Remote predict position now resolves platform relative positions from client.
					self.inst.Transform:SetPosition(pt.x, 0, pt.z)
				else
					self.locomotor:SetMoveDir(dir)
				end
                --Destination reached, queued (instead of immediate) stop
                --so that prediction may be resumed before the next frame
                self.locomotor:Stop({ force_idle_state = true }) --force idle state in case this tiny motion was meant to cancel an action
            end

            --Even though we're predict walking, we want the server to behave
            --according to whether the client thinks he's direct/drag walking
            if pt.y == 3 then
                if self.directwalking then
                    self.time_direct_walking = self.time_direct_walking + dt
                else
                    self.time_direct_walking = dt
                    self.directwalking = true
                    self.dragwalking = false
                    self.predictwalking = false
                end

                if self.time_direct_walking > .2 and not self.inst.sg:HasStateTag("attack") then
                    self.inst.components.combat:SetTarget(nil)
                end
            elseif pt.y == 4 then
                self.directwalking = false
                self.dragwalking = true
                self.predictwalking = false
            else
                self.directwalking = false
                self.dragwalking = false
                self.predictwalking = true
            end

            --Detect stop, teleport, or prediction errors
            --Cancel the cached prediction vector and force resync if necessary
            if distancetotargetsq <= stopdistancesq then
                self.remote_vector.y = 0
				self.remote_predict_stop_tick = GetTick()
            elseif distancetotargetsq > RUBBER_BAND_DISTANCE_SQ then
                self.remote_vector.y = 0
				--V2C: don't override rubberband, otherwise server teleports will also get stomped by client prediction
				--if self.remote_authority then
					--FIXME(JBK): Boat handling.
					--FIXED(V2C): Remote predict position now resolves platform relative positions from client.
				--	self.inst.Transform:SetPosition(pt.x, 0, pt.z)
				--else
					self.inst.Physics:Teleport(self.inst.Transform:GetWorldPosition())
				--end
            end

            return true
		elseif self.remote_predict_stop_tick then
			if self.inst.sg:HasAnyStateTag("idle", "floating") then
				local x1, z1 = self:GetRemotePredictStopXZ()
				if x1 and self.inst:GetDistanceSqToPoint(x1, 0, z1) <= PREDICT_STOP_ERROR_DISTANCE_SQ then
					--FIXME(JBK): Boat handling.
					--FIXED(V2C): Remote predict position now resolves platform relative positions from client.
					self.inst.Transform:SetPosition(x1, 0, z1)
				end
			end
			self.remote_predict_stop_tick = nil
        end
	elseif self:CanLocomote() then
		if self.inst.sg:HasAnyStateTag("moving", "floating_predict_move") then
			local x, y, z = self.inst.Transform:GetPredictionPosition()
			self:RemotePredictWalking(x, z, self.locomotor:GetTimeMoving() == 0, self.locomotor:PopOverrideTimeMoving())
			self.client_last_predict_walk.tick = GetTick()
			self.client_last_predict_walk.direct = self.directwalking
		elseif self.client_last_predict_walk.tick then
			if self.inst.sg:HasAnyStateTag("idle", "floating") and
				not (self:IsBusy() or self.inst:HasTag("boathopping")) and
				self.client_last_predict_walk.tick + 1 == GetTick()
			then
				local x, y, z = self.inst.Transform:GetPredictionPosition()
				self:RemotePredictWalking(x, z, self.locomotor:GetTimeMoving() == 0, self.locomotor:PopOverrideTimeMoving(), self.client_last_predict_walk.direct)
			end
			self.client_last_predict_walk.tick = nil
        end
    end
end

function PlayerController:DoDragWalking(dt)
    if self:IsLocalOrRemoteHopping() then return end
    local pt = nil
    if self.locomotor == nil or self:CanLocomote() then
        if self.handler == nil then
            pt = self:GetRemoteDragPosition()
        elseif self.draggingonground then
            pt = TheInput:GetWorldPosition()
        end
    end
    if pt ~= nil then
        local x0, y0, z0 = self.inst.Transform:GetWorldPosition()
        if distsq(pt.x, pt.z, x0, z0) > 1 then
            self.inst:ClearBufferedAction()
            if not self.ismastersim then
                self:CooldownRemoteController()
            end
            if self:CanLocomote() then
                self.locomotor:RunInDirection(self.inst:GetAngleToPoint(pt))
            end
        end
        self.directwalking = false
        self.dragwalking = true
        self.predictwalking = false
        if self.ismastersim then
            self.locomotor:CancelPredictMoveTimer() --remote drag walking, means client is not predicting
        elseif self.locomotor == nil then
            self:RemoteDragWalking(pt.x, pt.z)
        end
        return true
    end
end

function PlayerController:DoBoatSteering(dt)
    local dir = nil

    if self.handler == nil then
        dir = self:GetRemoteDirectVector()
    else
        dir = GetWorldControllerVector()
    end

    if dir ~= nil then
        if self.ismastersim then
            local steeringwheeluser = self.inst.components.steeringwheeluser
            if steeringwheeluser ~= nil then
                steeringwheeluser:SteerInDir(dir.x, dir.z)
            end
        else
            SendRPCToServer(RPC.SteerBoat, dir.x, dir.z)
        end
    end
end

function PlayerController:DoDoubleTapDir(allowaction)
	local mem = self.doubletapmem

	local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
	local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)

	--This is for the GetWorldControllerVector() deadzone
	local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
	local isoverdeadzone = math.abs(xdir) >= deadzone or math.abs(ydir) >= deadzone

	--This is for double tap which uses different thresholds
	local magsq = xdir * xdir + ydir * ydir
	local isovermaxthreshold = magsq >= 0.8 * 0.8
	local isoverminthreshold = magsq >= 0.6 * 0.6

	--NOTE: Intentional overlap in the down vs released handling
	--      below when isoverdeadzone but not isoverminthreshold

	--Handle dir pressed down
	if isoverdeadzone or isoverminthreshold then
		local isnewtap = not mem.down and isovermaxthreshold

		local dir
		if mem.dir then
			dir = TheCamera:GetRightVec() * xdir - TheCamera:GetDownVec() * ydir
			--dir:Normalize() --don't need since we're only testing angle

			local angle = math.atan2(dir.z, -dir.x)
			local lastangle = math.atan2(mem.dir.z, -mem.dir.x)
			local threshold = (isovermaxthreshold and PI / 3) or (isoverminthreshold and PI / 2) or PI
			if DiffAngleRad(angle, lastangle) >= threshold then
				--angle changed too much
				if isnewtap then
					--don't allowaction below, but still track the new tap
					allowaction = false
				else
					--stop tracking until dir is released to start over
					mem.down = true
					mem.t = nil
					mem.dir = nil
				end
			end
		end

		if isnewtap then
			--successfully tapped
			local last_t = mem.t
			mem.down = true
			mem.t = nil
			mem.dir = nil

			if CanEntitySeeTarget(self.inst, self.inst) then
				if dir == nil then
					dir = TheCamera:GetRightVec() * xdir - TheCamera:GetDownVec() * ydir
				end
				dir:Normalize()

				local dblclickact = self.inst.components.playeractionpicker:GetDoubleClickActions(nil, dir, nil)[1]
				if dblclickact then
					local t = GetTime()
					if allowaction and
						(last_t and t < last_t + DOUBLE_CLICK_TIMEOUT)
					then
						if self.ismastersim then
							self.inst.components.combat:SetTarget(nil)
						else
							local platform = dblclickact.pos.walkable_platform
							local pos_x = dblclickact.pos.local_pt.x
							local pos_z = dblclickact.pos.local_pt.z

							if self.locomotor == nil then
								dblclickact.non_preview_cb = function()
									SendRPCToServer(RPC.DoubleTapAction, dblclickact.action.code, pos_x, pos_z, dblclickact.action.canforce, dblclickact.action.mod_name, platform, platform ~= nil)
								end
							elseif self:CanLocomote() then
								dblclickact.preview_cb = function()
									SendRPCToServer(RPC.DoubleTapAction, dblclickact.action.code, pos_x, pos_z, nil, dblclickact.action.mod_name, platform, platform ~= nil)
								end
							end
						end
						self:DoAction(dblclickact)
					else
						mem.t = t
						mem.dir = dir
					end
				end
			end
		end
	end

	--Handle dir released
	if mem.down and not (isoverminthreshold and isoverdeadzone) then
		mem.down = false
	end
end

function PlayerController:OnRemoteDoubleTapAction(actioncode, position, noforce, mod_name)
	if self.ismastersim and self:IsEnabled() and self.handler == nil then
		self.inst.components.combat:SetTarget(nil)

		SetClientRequestedAction(actioncode, mod_name)
		local dblclickact = self.inst.components.playeractionpicker:GetDoubleClickActions(position, nil, nil)[1]
		ClearClientRequestedAction()

		dblclickact = (	dblclickact and
						dblclickact.action.code == actioncode and
						dblclickact.action.mod_name == mod_name and
						dblclickact)
					or nil

		if dblclickact then
			if dblclickact.action.canforce and not noforce then
				dblclickact:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
				dblclickact.forced = true
			end
			self:DoAction(dblclickact)
		--elseif mod_name then
			--print("Remote double tap action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
		--else
			--print("Remote double tap action failed: "..tostring(ACTION_IDS[actioncode]))
		end
	end
end

function PlayerController:DoDirectWalking(dt)
    if self:IsLocalOrRemoteHopping() then return end
    local dir = nil
    if (self.locomotor == nil or self:CanLocomote()) and
        not (self.controller_attack_override ~= nil or
            (self.inst.sg ~= nil and
            self.inst.sg:HasStateTag("attack") and
            self:IsControlPressed(CONTROL_CONTROLLER_ATTACK))) then
        if self.handler == nil then
            dir = self:GetRemoteDirectVector()
        else
            dir = GetWorldControllerVector()
        end
        --Prevent cancelling actions when letting go of direct walking controls late
		local keep_recent_bufferedaction = false
        if dir ~= nil and
			self.recent_bufferedaction.act ~= nil and
			self.recent_bufferedaction.t > dt and
			self.recent_bufferedaction.act == self.inst:GetBufferedAction() then
			--compare our analog dir
			if self.recent_bufferedaction.x == dir.x and self.recent_bufferedaction.z == dir.z then
				keep_recent_bufferedaction = true
			elseif self.isclientcontrollerattached then --works for local player as well
				local angle = math.atan2(-dir.z, dir.x) * RADIANS
				local recent_angle = math.atan2(-self.recent_bufferedaction.z, self.recent_bufferedaction.x) * RADIANS
				if DiffAngle(angle, recent_angle) <= 89 then
					keep_recent_bufferedaction = true
				end
			end
		end
		if keep_recent_bufferedaction then
			self.recent_bufferedaction.t = self.recent_bufferedaction.t - dt
        else
			self.recent_bufferedaction.act = nil
        end
    else
		self.recent_bufferedaction.act = nil
    end
	if self.recent_bufferedaction.act ~= nil then
        self.directwalking = false
        self.dragwalking = false
        self.predictwalking = false
        if not self.ismastersim then
            self:CooldownRemoteController()
        end
    elseif dir ~= nil then
        self.inst:ClearBufferedAction()

        if not self.ismastersim then
            self:CooldownRemoteController()
        end

        if self:CanLocomote() then
            self.locomotor:SetBufferedAction(nil)
            self.locomotor:RunInDirection(-math.atan2(dir.z, dir.x) / DEGREES)
        end

        if self.directwalking then
            self.time_direct_walking = self.time_direct_walking + dt
        else
            self.time_direct_walking = dt
            self.directwalking = true
            self.dragwalking = false
            self.predictwalking = false
        end

        if not self.ismastersim then
            if self.locomotor == nil then
                self:RemoteDirectWalking(dir.x, dir.z)
            end
        else
            self.locomotor:CancelPredictMoveTimer() --remote direct walking, means client is not predicting
            if self.time_direct_walking > .2 and not self.inst.sg:HasStateTag("attack") then
                self.inst.components.combat:SetTarget(nil)
            end
        end
    elseif self.predictwalking then
        if self.locomotor.bufferedaction == nil then
            self.locomotor:Stop()
        end
        self.directwalking = false
        self.dragwalking = false
        self.predictwalking = false
    elseif self.directwalking or self.dragwalking then
		local buffaction
        if self:CanLocomote() and self.controller_attack_override == nil then
            self.locomotor:Stop()
			--instead of self.locomotor:Clear()
			buffaction = self.locomotor.bufferedaction
        end
        self.directwalking = false
        self.dragwalking = false
        self.predictwalking = false
        if not self.ismastersim then
            self:CooldownRemoteController()
            if self.locomotor == nil then
                self:RemoteStopWalking()
            end
        end
		--restart any buffered actions that may have been pushed at the
		--same time as the user letting go of directwalking controls
		if buffaction then
			if self.ismastersim then
				self.locomotor:PushAction(buffaction)
			else
				self.locomotor:PreviewAction(buffaction)
			end
		end
    end
end

--------------------------------------------------------------------------
local ROT_REPEAT = .25
local ZOOM_REPEAT = .1

function PlayerController:DoCameraControl()
    if not TheCamera:CanControl() then
        return
    end

    local isenabled, ishudblocking = self:IsEnabled()
    if not isenabled and not ishudblocking then
		return
    end

    local time = GetStaticTime()
	local invert_rotation = Profile:GetInvertCameraRotation()

	if TheInput:SupportsControllerFreeCamera() then
		local xdir = TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_CAMERA_ROTATE_RIGHT) - TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_CAMERA_ROTATE_LEFT)
		local ydir = TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_CAMERA_ZOOM_IN) - TheInput:GetAnalogControlValue(VIRTUAL_CONTROL_CAMERA_ZOOM_OUT)
		local absxdir = math.abs(xdir)
		local absydir = math.abs(ydir)
		local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
		if absxdir >= deadzone and absxdir > absydir * 1.3 then --favour zoom a bit more at diagonals
			local right = xdir > 0
			if invert_rotation then
				right = not right
			end
			local speed = Remap(math.min(1, absxdir), deadzone, 1, 2, 3)
			if right then
				self:RotRight(speed)
			else
				self:RotLeft(speed)
			end
			self.lastrottime = time
		elseif absydir > deadzone then
			local delta = Remap(math.min(1, absydir), deadzone, 1, 0, 0.65)
			TheCamera:ContinuousZoomDelta(ydir > 0 and -delta or delta)
			self.lastzoomtime = time
		end
		return
	end

	-- CharlesB: Not used right now
    if --[[not self:IsControllerTargetingModifierDown() and ]] (self.lastrottime == nil or time - self.lastrottime > ROT_REPEAT) then
        if TheInput:IsControlPressed(invert_rotation and CONTROL_ROTATE_RIGHT or CONTROL_ROTATE_LEFT) then
            self:RotLeft()
            self.lastrottime = time
        elseif TheInput:IsControlPressed(invert_rotation and CONTROL_ROTATE_LEFT or CONTROL_ROTATE_RIGHT) then
            self:RotRight()
            self.lastrottime = time
        end
    end

	if self.lastzoomtime == nil or time - self.lastzoomtime > ZOOM_REPEAT then
		if TheInput:IsControlPressed(CONTROL_ZOOM_IN) then
			if not self.zoomin_same_as_scrollup or (self.inst.HUD ~= nil and self.inst.HUD.controls ~= nil and not self.inst.HUD.controls.craftingmenu.focus) then
				TheCamera:ZoomIn()
				self.lastzoomtime = time
			end
		elseif TheInput:IsControlPressed(CONTROL_ZOOM_OUT) then
			if not self.zoomout_same_as_scrolldown or (self.inst.HUD ~= nil and self.inst.HUD.controls ~= nil and not self.inst.HUD.controls.craftingmenu.focus) then
				TheCamera:ZoomOut()
				self.lastzoomtime = time
			end
		end
	end
end

local function IsWalkButtonDown()
    return TheInput:IsControlPressed(CONTROL_MOVE_UP) or TheInput:IsControlPressed(CONTROL_MOVE_DOWN) or TheInput:IsControlPressed(CONTROL_MOVE_LEFT) or TheInput:IsControlPressed(CONTROL_MOVE_RIGHT)
end

function PlayerController:OnLeftUp()
    if not self:IsEnabled() then
        return
    end

	local buffaction
    if self.draggingonground then
        if self:CanLocomote() and not IsWalkButtonDown() then
            self.locomotor:Stop()
			--instead of self.locomotor:Clear()
			buffaction = self.locomotor.bufferedaction
        end
        self.draggingonground = false
        self.startdragtime = nil
        TheFrontEnd:LockFocus(false)
    end
    self.startdragtime = nil

    if not self.ismastersim then
        self:RemoteStopControl(CONTROL_PRIMARY)
    end

	--restart any buffered actions that may have been pushed at the
	--same time as the user releasing draggingonground
	if buffaction then
		if self.ismastersim then
			self.locomotor:PushAction(buffaction)
		else
			self.locomotor:PreviewAction(buffaction)
		end
	end
end

function PlayerController:DoAction(buffaction, spellbook)
	--V2C: -New support for "non_preview_cb" on non-predicting clients.
	--     -If there's no pre_action_cb, trigger the cb to send the RPC
	--      right away, matching old behaviour.
	if buffaction and
		buffaction.non_preview_cb and
		buffaction.action.pre_action_cb == nil and
		self.locomotor == nil
	then
		buffaction.non_preview_cb()
	end

    --Check if the action is actually valid.
    --Cached LMB/RMB actions can become invalid.
    --Also check if we're busy.

	local valid = true
    if buffaction == nil or
        (buffaction.invobject ~= nil and not buffaction.invobject:IsValid()) or
        (buffaction.target ~= nil and not buffaction.target:IsValid()) or
		(buffaction.doer ~= nil and not buffaction.doer:IsValid())
		then
		valid = false
	elseif self:IsBusy() then
		if buffaction.action == ACTIONS.CASTAOE then
			--V2C: special case for repeat casting during busy state
			local item = spellbook or buffaction.invobject
			if not (item ~= nil and
					item.components.aoetargeting ~= nil and
					item.components.aoetargeting:CanRepeatCast() and
					self.inst:HasTag("canrepeatcast"))
				then
				valid = false
			end
		else
			valid = false
		end
	end

	if not valid then
		self.actionholdtime = nil
		return
	end

    --Check for duplicate actions
    local currentbuffaction = self.inst:GetBufferedAction()
    if currentbuffaction ~= nil and
        currentbuffaction.action == buffaction.action and
        currentbuffaction.target == buffaction.target and
        (   (currentbuffaction.pos == nil and buffaction.pos == nil) or
            (currentbuffaction.pos == buffaction.pos) -- Note: see overloaded DynamicPosition:__eq function
        ) and
        not (currentbuffaction.ispreviewing and
            self.inst:HasTag("idle") and
            self.inst.sg:HasStateTag("idle")) then
        --The "not" bit is in case we are stuck waiting for server
        --to act but it never does
        return
    end

    if buffaction.action == ACTIONS.ATTACK and self.inst.sg then
        self.inst.sg.statemem.retarget = buffaction.target
    end

    if self.handler ~= nil and buffaction.target ~= nil then
        local highlight_guy = buffaction.target.highlightforward or buffaction.target
        if highlight_guy.components.highlight == nil then
            highlight_guy:AddComponent("highlight")
        end
        highlight_guy.components.highlight:Flash(.2, .125, .1)
    end

    --Clear any buffered attacks since we're starting a new action
    self.attack_buffer = nil

    self:DoActionAutoEquip(buffaction)

    if not buffaction.action.instant and not buffaction.action.invalid_hold_action and buffaction:IsValid() then
        self.lastheldaction = buffaction
    else
        self.actionholdtime = nil
    end

    if self.ismastersim then
        self.locomotor:PushAction(buffaction, true)
	elseif self.locomotor == nil then
		--V2C: -New support for "non_preview_cb" on non-predicting clients.
		--     -If we have a pre_action_cb, only trigger the cb to send the
		--      RPC if we make it to here.
		--Backward compatibility:
		--     -If there is no "non_preview_cb", assume that pre_action_cb
		--      is manually triggered elsewhere.
		if buffaction.non_preview_cb and buffaction.action.pre_action_cb then
			buffaction.action.pre_action_cb(buffaction)
			buffaction.non_preview_cb()
		end
    elseif self:CanLocomote() then
        self.locomotor:PreviewAction(buffaction, true)
    end

    if self.handler ~= nil and buffaction.action == ACTIONS.LOOKAT and buffaction.target then
		--assert(self.inst == ThePlayer)
        TheScrapbookPartitions:SetInspectedByCharacter(buffaction.target, self.inst.prefab)
    end
end

function PlayerController:DoActionAutoEquip(buffaction)
    local equippable = buffaction.invobject ~= nil and buffaction.invobject.replica.equippable or nil
    if equippable ~= nil and
        equippable:EquipSlot() == EQUIPSLOTS.HANDS and
        not equippable:IsRestricted(self.inst) and
        buffaction.action ~= ACTIONS.DROP and
        buffaction.action ~= ACTIONS.COMBINESTACK and
        buffaction.action ~= ACTIONS.STORE and
        buffaction.action ~= ACTIONS.BUNDLESTORE and
        buffaction.action ~= ACTIONS.EQUIP and
        buffaction.action ~= ACTIONS.GIVETOPLAYER and
        buffaction.action ~= ACTIONS.GIVEALLTOPLAYER and
        buffaction.action ~= ACTIONS.GIVE and
        buffaction.action ~= ACTIONS.ADDFUEL and
        buffaction.action ~= ACTIONS.ADDWETFUEL and
        buffaction.action ~= ACTIONS.DEPLOY and
		buffaction.action ~= ACTIONS.DEPLOY_FLOATING and
        buffaction.action ~= ACTIONS.CONSTRUCT and
		buffaction.action ~= ACTIONS.ADDCOMPOSTABLE and
		(buffaction.action ~= ACTIONS.TOSS or not equippable.inst:HasTag("keep_equip_toss")) and
		buffaction.action ~= ACTIONS.DECORATESNOWMAN
	then
        self.inst.replica.inventory:EquipActionItem(buffaction.invobject)
        buffaction.autoequipped = true
    end
end

function PlayerController:OnLeftClick(down)
    if not self:UsingMouse() then
        return
    elseif not down then
        self:OnLeftUp()
        return
    end

    self:ClearActionHold()

    self.startdragtime = nil

	local laststartdoubleclicktime = self.startdoubleclicktime
	local laststartdoubleclickpos = self.startdoubleclickpos
	self.startdoubleclicktime = nil
	self.startdoubleclickpos = nil

    if not self:IsEnabled() then
        return
    elseif TheInput:GetHUDEntityUnderMouse() ~= nil then
        self:CancelPlacement()
        return
    elseif self.placer_recipe ~= nil and self.placer ~= nil then

        --do the placement
        if self.placer.components.placer.can_build then

            if self.inst.replica.builder ~= nil and not self.inst.replica.builder:IsBusy() then
                self.inst.replica.builder:MakeRecipeAtPoint(self.placer_recipe,
                    self.placer.components.placer.override_build_point_fn ~= nil and self.placer.components.placer.override_build_point_fn(self.placer) or self.placer:GetPosition(),
                    self.placer:GetRotation(), self.placer_recipe_skin)
                self:CancelPlacement()
            end

        elseif self.placer.components.placer.onfailedplacement ~= nil then
            self.placer.components.placer.onfailedplacement(self.inst, self.placer)
        end

        return
    end

	local t = GetTime()
	self.actionholdtime = t

	local act, spellbook, spell_id, dblclickact, trypreventdirflicker
    if self:IsAOETargeting() then
		local canrepeatcast = self.reticule.inst.components.aoetargeting:CanRepeatCast()
		if self:IsBusy() and not (canrepeatcast and self.inst:HasTag("canrepeatcast")) then
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative", nil, .4)
            self.reticule:Blip()
            return
        end
        act = self:GetRightMouseAction()
        if act == nil or act.action ~= ACTIONS.CASTAOE then
            return
        end
        spellbook = self:GetActiveSpellBook()
		if spellbook ~= nil then
			spell_id = spellbook.components.spellbook:GetSelectedSpell()
		end
		self.reticule:PingReticuleAt(act:GetDynamicActionPoint())
		if not (canrepeatcast and self.reticule.inst.components.aoetargeting:ShouldRepeatCast(self.inst)) then
			self:CancelAOETargeting()
		end
	else
		local scrnx, scrny = TheSim:GetPosition()
		local x, y, z = TheSim:ProjectScreenPos(scrnx, scrny)
		local position = x and y and z and Vector3(x, y, z) or nil --basically TheInput:GetWorldPosition()

		--first see if we have double click actions
		if position then
			local target = TheInput:GetWorldEntityUnderMouse()
			if target and not CanEntitySeeTarget(self.inst, target) then
				target = nil
			end
			if target or CanEntitySeeTarget(self.inst, self.inst) then
				local dir = GetWorldControllerVector()
				dblclickact = self.inst.components.playeractionpicker:GetDoubleClickActions(position, dir, target)[1]
				if dblclickact then
					if (laststartdoubleclicktime and t < laststartdoubleclicktime + DOUBLE_CLICK_TIMEOUT) and
						(laststartdoubleclickpos and math.abs(laststartdoubleclickpos.x - scrnx) <= DOUBLE_CLICK_POS_THRESHOLD and math.abs(laststartdoubleclickpos.y - scrny) <= DOUBLE_CLICK_POS_THRESHOLD)
					then
						act = dblclickact
					elseif dir then
						--If we're holding a direction key, direct walking will (after one frame) cancel
						--whatever action we are about to buffer to the locomotor (unless it's instant).
						--This flag prevents facing change flicker.
						--Should really do this always, but to avoid bugs with legacy behaviour, we will
						--just do it for players with double click actions for now.
						trypreventdirflicker = true
					end
					if act == nil or self:IsBusy() then
						self.startdoubleclickpos = Vector3(scrnx, scrny, 0)
						self.startdoubleclicktime = t
					end
				end
			end
		end

		if act == nil then
			act = self:GetLeftMouseAction() or BufferedAction(self.inst, nil, ACTIONS.WALKTO, nil, position)
			if act and act.action ~= ACTIONS.WALKTO and act.action ~= ACTIONS.LOOKAT then
				self.startdoubleclicktime = nil
			end
		end
    end

    local maptarget = self:GetMapTarget(act)
    if maptarget ~= nil then
		self:PullUpMap(maptarget)
        return
    end

    if act.action == ACTIONS.WALKTO then
        local entity_under_mouse = TheInput:GetWorldEntityUnderMouse()
        if act.target == nil and (entity_under_mouse == nil or entity_under_mouse:HasTag("walkableplatform")) then
			self.startdragtime = t
        end
	elseif act.action == ACTIONS.DASH then
		self.startdragtime = t
    elseif act.action == ACTIONS.ATTACK then
        if self.inst.sg ~= nil then
            self.inst.sg.statemem.retarget = act.target
            if self.inst.sg:HasStateTag("attack") and act.target == self.inst.replica.combat:GetTarget() then
                return
            end
        elseif self.inst:HasTag("attack") and act.target == self.inst.replica.combat:GetTarget() then
            return
        end
    elseif act.action == ACTIONS.LOOKAT then
        if act.target ~= nil and self.inst.HUD ~= nil then
            if act.target.components.playeravatardata ~= nil then
                local client_obj = act.target.components.playeravatardata:GetData()
                if client_obj ~= nil then
                    client_obj.inst = act.target
                    self.inst.HUD:TogglePlayerInfoPopup(client_obj.name, client_obj, true)
                end
            elseif act.target.quagmire_shoptab ~= nil then
                self.inst:PushEvent("quagmire_shoptab", act.target.quagmire_shoptab)
            end
        end
    elseif act.action == ACTIONS.BOAT_CANNON_SHOOT then
        local boatcannonuser = self.inst.components.boatcannonuser
        local reticule = boatcannonuser ~= nil and boatcannonuser:GetReticule() or nil
        if reticule ~= nil then
			reticule:PingReticuleAt(act:GetDynamicActionPoint())
        end
    end

    if self.ismastersim then
        self.inst.components.combat:SetTarget(nil)
    else
        local mouseover, platform, pos_x, pos_z
        if act.action == ACTIONS.CASTAOE or
			act.action == ACTIONS.BOAT_CANNON_SHOOT or
			act == dblclickact
		then
            --These actions use reticule position
			--dblclickact also may have overridden the position
			platform = act.pos.walkable_platform
			pos_x = act.pos.local_pt.x
			pos_z = act.pos.local_pt.z
        else
            local position = TheInput:GetWorldPosition()
			platform, pos_x, pos_z = self:GetPlatformRelativePosition(position.x, position.z)
            mouseover = act.action ~= ACTIONS.DROP and TheInput:GetWorldEntityUnderMouse() or nil
        end

        local controlmods = self:EncodeControlMods()
        if self.locomotor == nil then
			act.non_preview_cb = function()
				self.remote_controls[CONTROL_PRIMARY] = 0
				SendRPCToServer(RPC.LeftClick, act.action.code, pos_x, pos_z, mouseover, nil, controlmods, act.action.canforce, act.action.mod_name, platform, platform ~= nil, spellbook, spell_id)
			end
        elseif act.action ~= ACTIONS.WALKTO and self:CanLocomote() then
            act.preview_cb = function()
                self.remote_controls[CONTROL_PRIMARY] = 0
                local isreleased = not TheInput:IsControlPressed(CONTROL_PRIMARY)
                SendRPCToServer(RPC.LeftClick, act.action.code, pos_x, pos_z, mouseover, isreleased, controlmods, nil, act.action.mod_name, platform, platform ~= nil, spellbook, spell_id)
            end
        end
    end

	self:DoAction(act, spellbook)

	if trypreventdirflicker and act ~= dblclickact and self.locomotor and self.locomotor.bufferedaction == act then
		self.locomotor:Clear()
	end
end

function PlayerController:OnRemoteLeftClick(actioncode, position, target, isreleased, controlmodscode, noforce, mod_name, spellbook, spell_id)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.inst.components.combat:SetTarget(nil)

        self.remote_controls[CONTROL_PRIMARY] = 0
        self:DecodeControlMods(controlmodscode)
        SetClientRequestedAction(actioncode, mod_name)
		local lmb, rmb
		if spellbook ~= nil then
			if spellbook.components.inventoryitem ~= nil and
				spellbook.components.inventoryitem:GetGrandOwner() == self.inst and
				spellbook.components.spellbook ~= nil and
				spellbook.components.spellbook:SelectSpell(spell_id)
				then
				lmb, rmb = self.inst.components.playeractionpicker:DoGetMouseActions(position, target, spellbook)
			end
		elseif spell_id == nil then
			lmb, rmb = self.inst.components.playeractionpicker:DoGetMouseActions(position, target)
		end
		local dblclickact
		if CanEntitySeeTarget(self.inst, self.inst) then
			dblclickact = self.inst.components.playeractionpicker:GetDoubleClickActions(position)[1]
		end

        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_PRIMARY] = nil
        end
        self:ClearControlMods()

        --Default fallback lmb action is WALKTO
        --Possible for lmb action to switch to rmb after autoequip
		--V2C: LOOKAT was added to support closeinspect
		lmb =  (actioncode == ACTIONS.LOOKAT.code and
				(lmb == nil or lmb.action == ACTIONS.WALKTO) and
				mod_name == nil and
				BufferedAction(self.inst, target, ACTIONS.LOOKAT, nil, position))
			or (lmb == nil and
                actioncode == ACTIONS.WALKTO.code and
                mod_name == nil and
                BufferedAction(self.inst, nil, ACTIONS.WALKTO, nil, position))
            or (lmb ~= nil and
                lmb.action.code == actioncode and
                lmb.action.mod_name == mod_name and
                lmb)
            or (rmb ~= nil and
                rmb.action.code == actioncode and
                rmb.action.mod_name == mod_name and
                rmb)
			or (dblclickact and
				dblclickact.action.code == actioncode and
				dblclickact.action.mod_name == mod_name and
				dblclickact)
            or nil

        if lmb ~= nil then
            if lmb.action.canforce and not noforce then
                lmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                lmb.forced = true
            end
			self:DoAction(lmb, spellbook)
			--see trypreventdirflicker
			if dblclickact and lmb ~= dblclickact and self.locomotor.bufferedaction == lmb and self:GetRemoteDirectVector() then
				self.locomotor:Clear()
			end
        --elseif mod_name ~= nil then
            --print("Remote left click action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote left click action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:GetPlatformRelativePosition(absolute_x,absolute_z)
    local platform = TheWorld.Map:GetPlatformAtPoint(absolute_x,absolute_z)
    if platform ~= nil then
		local y
		absolute_x, y, absolute_z = platform.entity:WorldToLocalSpace(absolute_x, 0, absolute_z)
    end
    return platform, absolute_x, absolute_z
end

function PlayerController:OnRightClick(down)
    if not self:UsingMouse() then
        return
    elseif not down then
        if self:IsEnabled() then
            self:RemoteStopControl(CONTROL_SECONDARY)
        end
        return
    end

    self:ClearActionHold()

    self.startdragtime = nil
	self.startdoubleclicktime = nil

    if self.placer_recipe ~= nil then
        self:CancelPlacement()
        return
    elseif self:IsAOETargeting() then
        self:CancelAOETargeting()
        return
    elseif not self:IsEnabled() or TheInput:GetHUDEntityUnderMouse() ~= nil then
        return
    end

    self.actionholdtime = GetTime()

    local act = self:GetRightMouseAction()
    local maptarget = self:GetMapTarget(act)
    if act == nil then
		local closed = false
		if self.inst.HUD ~= nil then
			if self.inst.HUD:IsCraftingOpen() then
				self.inst.HUD:CloseCrafting()
				closed = true
			end
			if self.inst.HUD:IsSpellWheelOpen() then
				self.inst.HUD:CloseSpellWheel()
				closed = true
			end
		end
		if not closed then
			self.inst.replica.inventory:ReturnActiveItem()
			if self:TryAOETargeting() or self:TryAOECharging(nil, false) then
				return
			end
		end
    elseif maptarget ~= nil then
		self:PullUpMap(maptarget)
        return
    else
        if self.reticule ~= nil and self.reticule.reticule ~= nil then
			self.reticule:PingReticuleAt(act:GetDynamicActionPoint())
        end
		local goingtodeploy = self.deployplacer ~= nil and (act.action == ACTIONS.DEPLOY or act.action == ACTIONS.DEPLOY_FLOATING)
        if goingtodeploy then
            if self.deployplacer.components.placer:IsAxisAlignedPlacement() then
                act:SetActionPoint(self.deployplacer:GetPosition())
            end
            if self.deployplacer.components.placer.override_build_point_fn then
                local override_pt = self.deployplacer.components.placer.override_build_point_fn(self.deployplacer)
                if override_pt then
                    act:SetActionPoint(override_pt)
                end
            end
            act.rotation = self.deployplacer.Transform:GetRotation()
        end
        if not self.ismastersim then
            local position
            local mouseover
            if goingtodeploy then
                position = act:GetActionPoint()
                if not self.deployplacer.components.placer:IsAxisAlignedPlacement() then
                    mouseover = TheInput:GetWorldEntityUnderMouse()
                end
            else
                position = TheInput:GetWorldPosition()
                mouseover = TheInput:GetWorldEntityUnderMouse()
            end
            local controlmods = self:EncodeControlMods()
            local platform, pos_x, pos_z = self:GetPlatformRelativePosition(position.x, position.z)
            if self.locomotor == nil then
				act.non_preview_cb = function()
					self.remote_controls[CONTROL_SECONDARY] = 0
					SendRPCToServer(RPC.RightClick, act.action.code, pos_x, pos_z, mouseover, act.rotation ~= 0 and act.rotation or nil, nil, controlmods, act.action.canforce, act.action.mod_name, platform, platform ~= nil)
				end
            elseif act.action ~= ACTIONS.WALKTO and self:CanLocomote() then
                act.preview_cb = function()
                    self.remote_controls[CONTROL_SECONDARY] = 0
                    local isreleased = not TheInput:IsControlPressed(CONTROL_SECONDARY)
                    SendRPCToServer(RPC.RightClick, act.action.code, pos_x, pos_z, mouseover, act.rotation ~= 0 and act.rotation or nil, isreleased, controlmods, nil, act.action.mod_name, platform, platform ~= nil)
                end
            end
        end
        self:DoAction(act)
    end
end

function PlayerController:OnRemoteRightClick(actioncode, position, target, rotation, isreleased, controlmodscode, noforce, mod_name)
    if self.ismastersim and self:IsEnabled() and self.handler == nil then
        self.remote_controls[CONTROL_SECONDARY] = 0
        self:DecodeControlMods(controlmodscode)
        SetClientRequestedAction(actioncode, mod_name)
        local lmb, rmb = self.inst.components.playeractionpicker:DoGetMouseActions(position, target)
        ClearClientRequestedAction()
        if isreleased then
            self.remote_controls[CONTROL_SECONDARY] = nil
        end
        self:ClearControlMods()

        if rmb ~= nil and rmb.action.code == actioncode and rmb.action.mod_name == mod_name then
            if rmb.action.canforce and not noforce then
                rmb:SetActionPoint(self:GetRemotePredictPosition() or self.inst:GetPosition())
                rmb.forced = true
            end
            rmb.rotation = rotation or rmb.rotation
            self:DoAction(rmb)
        --elseif mod_name ~= nil then
            --print("Remote right click action failed: "..tostring(ACTION_MOD_IDS[mod_name][actioncode]))
        --else
            --print("Remote right click action failed: "..tostring(ACTION_IDS[actioncode]))
        end
    end
end

function PlayerController:RemapMapAction(act, position)
    local act_remap = nil
    if act then
        local px, py, pz = position:Get()
        if act.action.map_only then
            if act.action.maponly_checkvalidpos_fn == nil or act.action.maponly_checkvalidpos_fn(act) then
                if act.action.map_works_on_unexplored or self.inst:CanSeePointOnMiniMap(px, py, pz) then
                    act_remap = act
                end
            end
        elseif ACTIONS_MAP_REMAP[act.action.code] then
            if act.action.map_works_on_unexplored or
                self.inst:CanSeePointOnMiniMap(px, py, pz) or
                act.invobject and act.invobject:HasTag("mapaction_works_on_unexplored") then
                act_remap = ACTIONS_MAP_REMAP[act.action.code](act, Vector3(px, py, pz))
            end
        end
    end
    return act_remap
end

function PlayerController:GetMapActions(position, maptarget, actiondef)
    -- NOTES(JBK): In order to not interface with the playercontroller too harshly and keep that isolated from this system here
    --             it is better to get what the player could do at their location as a quick check to make sure the actions done
    --             here will not interfere with actions done without the map up.
    local LMBaction, RMBaction = nil, nil
    local forced_lmbact, forced_rmbact
    if actiondef and actiondef.map_only then
        -- NOTES(JBK): Unless the action itself is a map_only action then let us say it is fine and force it as highest priority.
        local ba = BufferedAction(self.inst, maptarget, actiondef, nil, position)
        if actiondef.rmb then
            forced_rmbact = ba
        else
            forced_lmbact = ba
        end
    end

    local pos = self.inst:GetPosition()

    self.inst.checkingmapactions = true -- NOTES(JBK): Workaround flag to not add function argument changes for this task and lets things opt-in to special handling.
    self.inst.checkingmapactions_pos = position
    local action_maptarget = maptarget and maptarget:IsValid() and not maptarget:HasTag("INLIMBO") and maptarget or nil -- NOTES(JBK): Workaround passing the maptarget entity if it is out of scope for world actions.

    local lmbact = forced_lmbact or self.inst.components.playeractionpicker:GetLeftClickActions(pos, action_maptarget)[1]
    if lmbact then
        lmbact.maptarget = maptarget
        LMBaction = self:RemapMapAction(lmbact, position)
    end

    local rmbact = forced_rmbact or self.inst.components.playeractionpicker:GetRightClickActions(pos, action_maptarget)[1]
    if rmbact then
        rmbact.maptarget = maptarget
        RMBaction = self:RemapMapAction(rmbact, position)
    end

    if RMBaction and LMBaction and RMBaction.action == LMBaction.action then -- NOTES(JBK): If the actions are the same for the same target remove the LMBaction.
        LMBaction = nil
    end

    self.inst.checkingmapactions = nil
    self.inst.checkingmapactions_pos = nil

    return LMBaction, RMBaction
end

function PlayerController:UpdateActionsToMapActions(position, maptarget, forced_actiondef)
    -- NOTES(JBK): This should be called from a map interface to update the player's current actions to the ones the map has.
    -- Currently used by mapscreen.
    local LMBaction, RMBaction = self:GetMapActions(position, maptarget, forced_actiondef)

    self.LMBaction, self.RMBaction = LMBaction, RMBaction

    return LMBaction, RMBaction
end

function PlayerController:OnMapAction(actioncode, position, maptarget, mod_name)
    local act
    if mod_name then -- Do not shorten to a short circuit logic we do not want base game actions as a fallback this would break everything.
        act = MOD_ACTIONS_BY_ACTION_CODE[mod_name] and MOD_ACTIONS_BY_ACTION_CODE[mod_name][actioncode] or nil
    else
        act = ACTIONS_BY_ACTION_CODE[actioncode]
    end
    if act == nil or not act.map_action then
        return
    end
    act.target = maptarget -- Optional.

	local LMBaction, RMBaction = self:GetMapActions(position, maptarget, act)
    if self.ismastersim then
        if act.rmb then
            if RMBaction then
                self.locomotor:PushAction(RMBaction, true)
            end
        else
            if LMBaction then
                self.locomotor:PushAction(LMBaction, true)
            end
        end
    elseif self.locomotor == nil then
		-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
		if act.rmb then
			if RMBaction and RMBaction.action.pre_action_cb then
				RMBaction.action.pre_action_cb(RMBaction)
			end
		else
			if LMBaction and LMBaction.action.pre_action_cb then
				LMBaction.action.pre_action_cb(LMBaction)
			end
		end
        SendRPCToServer(RPC.DoActionOnMap, actioncode, position.x, position.z, maptarget, mod_name)
    elseif self:CanLocomote() then
        if act.rmb then
            RMBaction.preview_cb = function()
                SendRPCToServer(RPC.DoActionOnMap, actioncode, position.x, position.z, maptarget, mod_name)
            end
            self.locomotor:PreviewAction(RMBaction, true)
        else
            LMBaction.preview_cb = function()
                SendRPCToServer(RPC.DoActionOnMap, actioncode, position.x, position.z, maptarget, mod_name)
            end
            self.locomotor:PreviewAction(LMBaction, true)
        end
    end
end

function PlayerController:GetLeftMouseAction()
    return self.LMBaction
end

function PlayerController:GetRightMouseAction()
    return self.RMBaction
end

function PlayerController:GetItemSelfAction(item)
    if item == nil or (self.handler ~= nil and self.deploy_mode) then
        return
    end
    local act =
        --[[rmb]] self.inst.components.playeractionpicker:GetInventoryActions(item, true)[1] or
        --[[lmb]] self.inst.components.playeractionpicker:GetInventoryActions(item, false)[1]
    return act ~= nil and act.action ~= ACTIONS.LOOKAT and act or nil
end

function PlayerController:GetSceneItemControllerAction(item)
    if item == nil or self:IsAOETargeting() then
        return
    end
    local itempos = item:GetPosition()
    local lmb = self.inst.components.playeractionpicker:GetLeftClickActions(itempos, item)[1]
    local rmb = self.inst.components.playeractionpicker:GetRightClickActions(itempos, item)[1]
    if lmb ~= nil
        and (lmb.action == ACTIONS.LOOKAT or
            (lmb.action == ACTIONS.ATTACK and item.replica.combat ~= nil) or
            lmb.action == ACTIONS.WALKTO) then
        lmb = nil
    end
    if rmb ~= nil
        and (rmb.action == ACTIONS.LOOKAT or
            (rmb.action == ACTIONS.ATTACK and item.replica.combat ~= nil) or
            rmb.action == ACTIONS.WALKTO) then
        rmb = nil
    end
    return lmb, rmb ~= nil and (lmb == nil or lmb.action ~= rmb.action) and rmb or nil
end

function PlayerController:IsAxisAlignedPlacement()
    return (self.placer and self.placer.components.placer and self.placer.components.placer:IsAxisAlignedPlacement()) or
    (self.deployplacer and self.deployplacer.components.placer and self.deployplacer.components.placer:IsAxisAlignedPlacement()) or
    false
end

function PlayerController:GetPlacerPosition()
    return (self.placer ~= nil and self.placer:GetPosition()) or
    (self.deployplacer ~= nil and self.deployplacer:GetPosition()) or
    nil
end

function PlayerController:GetGroundUseAction(position, spellbook)
    if self.inst.components.playeractionpicker:HasContainerWidgetAction() then
        return
	elseif self.inst:HasTag("usingmagiciantool") then
		return nil, BufferedAction(self.inst, self.inst, ACTIONS.STOPUSINGMAGICTOOL)
	end

    local islocal = position == nil
    position = position or
        (self.reticule ~= nil and self.reticule.inst ~= self.inst and self.reticule.targetpos) or
        (self.terraformer ~= nil and self.terraformer:GetPosition()) or
        self:GetPlacerPosition() or
        self.inst:GetPosition()

    if CanEntitySeePoint(self.inst, position:Get()) then
		local isaoetargeting = islocal and self:IsAOETargeting()
		if isaoetargeting and spellbook == nil then
			spellbook = self:GetActiveSpellBook()
		end
        --Check validitiy because FE controls may call this in WallUpdate
		local item = spellbook or self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if item ~= nil and item:IsValid() then
			local alwayspassable, allowwater, deployradius
			local aoetargeting = item.components.aoetargeting
			if aoetargeting ~= nil and aoetargeting:IsEnabled() then
				alwayspassable = aoetargeting.alwaysvalid
				allowwater = aoetargeting.allowwater
				deployradius = aoetargeting.deployradius
			end
			alwayspassable = alwayspassable or item:HasTag("allow_action_on_impassable")
			if self.map:CanCastAtPoint(position, alwayspassable, allowwater, deployradius) then
				local lmb = not isaoetargeting and self.inst.components.playeractionpicker:GetPointActions(position, item, false, nil)[1] or nil
				local rmb = (not islocal or isaoetargeting or item.components.aoetargeting == nil or not item.components.aoetargeting:IsEnabled()) and self.inst.components.playeractionpicker:GetPointActions(position, item, true, nil)[1] or nil
				if lmb ~= nil then
					if lmb.action == ACTIONS.DROP then
						lmb = nil
					elseif lmb.action == ACTIONS.TERRAFORM then
						lmb.distance = 2
					end
				end
				if rmb ~= nil and rmb.action == ACTIONS.TERRAFORM then
					rmb.distance = 2
				end
				return lmb, rmb ~= nil and (lmb == nil or lmb.action ~= rmb.action) and rmb or nil
			end
        end
    end
end

function PlayerController:GetGroundUseSpecialAction(position, right)
    --local islocal = position == nil
    position = position or
        (self.reticule ~= nil and self.reticule.targetpos) or
        (self.terraformer ~= nil and self.terraformer:GetPosition()) or
        self:GetPlacerPosition() or
        self.inst:GetPosition()

    return CanEntitySeePoint(self.inst, position:Get())
        and self.map:IsPassableAtPoint(position:Get())
        and self.inst.components.playeractionpicker:GetPointSpecialActions(position, nil, right)[1]
        or nil
end

function PlayerController:HasGroundUseSpecialAction(right)
	return #self.inst.components.playeractionpicker:GetPointSpecialActions(self.inst:GetPosition(), nil, right, true) > 0
end

local function ValidateItemUseAction(self, act, active_item, target)
    return act ~= nil and
        (active_item.replica.equippable == nil or not active_item:HasTag(act.action.id.."_tool")) and
        ((act.action ~= ACTIONS.STORE and act.action ~= ACTIONS.BUNDLESTORE) or target.replica.inventoryitem == nil or not target.replica.inventoryitem:IsGrandOwner(self.inst)) and
        act.action ~= ACTIONS.COMBINESTACK and
        act.action ~= ACTIONS.ATTACK and
        act or nil
end

--#V2C #Hack to allow controllers to Store in Magician's Top Hat while mounted.
--           This is for DPAD actions, so they don't have to open inventory UI
--           to access the unfiltered UI actions.
local function AllowMountedStoreActionFilter(inst, action)
	return action.mount_valid or action == ACTIONS.STORE
end

function PlayerController:GetItemUseAction(active_item, target)
    if active_item == nil then
        return
    end

	local allow_mounted_store = target ~= nil and target:HasTag("pocketdimension_container")

    target = target or self:GetControllerTarget()

	if target == nil and self.inst:HasTag("usingmagiciantool") then
		local containers = self.inst.replica.inventory:GetOpenContainers()
		if containers ~= nil then
			for k in pairs(containers) do
				if k:HasTag("pocketdimension_container") and (k.replica.container == nil or not k.replica.container:IsReadOnlyContainer()) then
					target = k
					allow_mounted_store = true
					break
				end
			end
		end
	end

	if allow_mounted_store then
		local rider = self.inst.replica.rider
		if rider ~= nil and rider:IsRiding() then
			--See rider_replica MountedActionFilter; match priority
			self.inst.components.playeractionpicker:PushActionFilter(AllowMountedStoreActionFilter, ACTION_FILTER_PRIORITIES.mounted)
		else
			allow_mounted_store = false
		end
	end

    local act = target ~= nil and (
        ValidateItemUseAction(--[[rmb]] self, self.inst.components.playeractionpicker:GetUseItemActions(target, active_item, true)[1], active_item, target) or
        ValidateItemUseAction(--[[lmb]] self, self.inst.components.playeractionpicker:GetUseItemActions(target, active_item, false)[1], active_item, target)
    ) or nil

	if allow_mounted_store then
		self.inst.components.playeractionpicker:PopActionFilter(AllowMountedStoreActionFilter)
	end

	if act == nil and target == nil then
		--V2C: We have no ItemUseAction, try taking another ItemSelfAction (see GetItemSelfAction).
		local rmb = self.inst.components.playeractionpicker:GetInventoryActions(active_item, true)[1]
		if rmb then
			--GetItemSelfAction would've used the rmb one, so lets try the lmb one
			local lmb = self.inst.components.playeractionpicker:GetInventoryActions(active_item, false)[1]
			if lmb and lmb.action ~= rmb.action and lmb.action ~= ACTIONS.LOOKAT then
				act = lmb
			end
		end
	end

	if act ~= nil then
		if act.action == ACTIONS.STORE and act.target ~= nil and act.target:HasTag("pocketdimension_container") then
			act.options.instant = true
		end
	elseif active_item:HasTag("magiciantool") and self.inst:HasTag("magician") then
		act = BufferedAction(self.inst, nil, ACTIONS.USEMAGICTOOL, active_item)
	end

	if act ~= nil then
		return act
	elseif active_item.replica.inventoryitem:IsDeployable(self.inst) and active_item.replica.inventoryitem:IsGrandOwner(self.inst) then
		--Deployable item, no item use action generated yet
		--V2C: When not mounted, use self actions blocked by controller R.Dpad "TOGGLE_DEPLOY_MODE"
		--     So force it onto L.Dpad instead here
		--     e.g. Murder/Plant, Eat/Plant
		act = --[[rmb]] self.inst.components.playeractionpicker:GetInventoryActions(active_item, true)
		act = act[1] ~= nil and act[1].action ~= ACTIONS.TOGGLE_DEPLOY_MODE and act[1] or act[2]
		if act == nil then
			act = --[[lmb]] self.inst.components.playeractionpicker:GetInventoryActions(active_item, false)
			act = act[1] ~= nil and act[1].action ~= ACTIONS.TOGGLE_DEPLOY_MODE and act[1] or act[2]
		end
		return act ~= nil and act.action ~= ACTIONS.LOOKAT and act or nil
	end
end

function PlayerController:RemoteUseItemFromInvTile(buffaction, item)
    if not self.ismastersim then
        local controlmods = self:EncodeControlMods()
        if self.locomotor == nil then
            -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if buffaction.action.pre_action_cb ~= nil then
				if self:IsBusy() then
					return --V2C: Block inv tile actions that have pre_action_cb; otherwise send RPC anyway for better responsiveness.
				end
				buffaction.action.pre_action_cb(buffaction)
			end
            SendRPCToServer(RPC.UseItemFromInvTile, buffaction.action.code, item, controlmods, buffaction.action.mod_name)
        elseif buffaction.action ~= ACTIONS.WALKTO
            and self:CanLocomote()
            and not self:IsBusy() then
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.UseItemFromInvTile, buffaction.action.code, item, controlmods, buffaction.action.mod_name)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteControllerUseItemOnItemFromInvTile(buffaction, item, active_item)
    if not self.ismastersim then
        if self.locomotor == nil then
            -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if buffaction.action.pre_action_cb ~= nil then
				if self:IsBusy() then
					return --V2C: Block inv tile actions that have pre_action_cb; otherwise send RPC anyway for better responsiveness.
				end
				buffaction.action.pre_action_cb(buffaction)
			end
            SendRPCToServer(RPC.ControllerUseItemOnItemFromInvTile, buffaction.action.code, item, active_item, buffaction.action.mod_name)
        elseif buffaction.action ~= ACTIONS.WALKTO
            and self:CanLocomote()
            and not self:IsBusy() then
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.ControllerUseItemOnItemFromInvTile, buffaction.action.code, item, active_item, buffaction.action.mod_name)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteControllerUseItemOnSelfFromInvTile(buffaction, item)
    if not self.ismastersim then
        if self.locomotor == nil then
            -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if buffaction.action.pre_action_cb ~= nil then
				if self:IsBusy() then
					return --V2C: Block inv tile actions that have pre_action_cb; otherwise send RPC anyway for better responsiveness.
				end
				buffaction.action.pre_action_cb(buffaction)
			end
            SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, buffaction.action.code, item, buffaction.action.mod_name)
        elseif buffaction.action ~= ACTIONS.WALKTO
            and self:CanLocomote()
            and not self:IsBusy() then
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, buffaction.action.code, item, buffaction.action.mod_name)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteControllerUseItemOnSceneFromInvTile(buffaction, item)
    if not self.ismastersim then
        if self.locomotor == nil then
            -- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if buffaction.action.pre_action_cb ~= nil then
				if self:IsBusy() then
					return --V2C: Block inv tile actions that have pre_action_cb; otherwise send RPC anyway for better responsiveness.
				end
				buffaction.action.pre_action_cb(buffaction)
			end
            SendRPCToServer(RPC.ControllerUseItemOnSceneFromInvTile, buffaction.action.code, item, buffaction.target, buffaction.action.mod_name)
        elseif buffaction.action ~= ACTIONS.WALKTO
            and self:CanLocomote()
            and not self:IsBusy() then
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.ControllerUseItemOnSceneFromInvTile, buffaction.action.code, item, buffaction.target, buffaction.action.mod_name)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteInspectItemFromInvTile(item)
    if not self.ismastersim then
        if self.locomotor == nil then
			-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if ACTIONS.LOOKAT.pre_action_cb ~= nil then
				ACTIONS.LOOKAT.pre_action_cb(BufferedAction(self.inst, nil, ACTIONS.LOOKAT, item))
			end
            SendRPCToServer(RPC.InspectItemFromInvTile, item)
        elseif self:CanLocomote() then
            local buffaction = BufferedAction(self.inst, nil, ACTIONS.LOOKAT, item)
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.InspectItemFromInvTile, item)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteDropItemFromInvTile(item, single)
    if not self.ismastersim then
        if self.locomotor == nil then
			-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if ACTIONS.DROP.pre_action_cb ~= nil then
				ACTIONS.DROP.pre_action_cb(BufferedAction(self.inst, nil, ACTIONS.DROP, item, self.inst:GetPosition()))
			end
            SendRPCToServer(RPC.DropItemFromInvTile, item, single or nil)
        elseif self:CanLocomote() then
            local buffaction = BufferedAction(self.inst, nil, ACTIONS.DROP, item, self.inst:GetPosition())
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.DropItemFromInvTile, item, single or nil)
            end
			buffaction.options.instant = self.inst.sg:HasStateTag("overridelocomote")
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteCastSpellBookFromInv(item, spell_id, spell_action)
	if not self.ismastersim then
		local target = item == self.inst and item or nil
		local invobject = item ~= self.inst and item or nil
		spell_action = spell_action or ACTIONS.CAST_SPELLBOOK
		if self.locomotor == nil then
			-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if spell_action.pre_action_cb then
				spell_action.pre_action_cb(BufferedAction(self.inst, target, spell_action, invobject))
			end
			SendRPCToServer(RPC.CastSpellBookFromInv, item, spell_id)
		elseif self:CanLocomote() then
			local buffaction = BufferedAction(self.inst, target, spell_action, invobject)
			buffaction.preview_cb = function()
				SendRPCToServer(RPC.CastSpellBookFromInv, item, spell_id)
			end
			self.locomotor:PreviewAction(buffaction, true)
		end
	end
end

function PlayerController:RemoteMakeRecipeFromMenu(recipe, skin)
    if not self.ismastersim then
        local skin_index = skin ~= nil and PREFAB_SKINS_IDS[recipe.product][skin] or nil
        if self.locomotor == nil then
			-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if ACTIONS.BUILD.pre_action_cb ~= nil then
				ACTIONS.BUILD.pre_action_cb(BufferedAction(self.inst, nil, ACTIONS.BUILD, nil, nil, recipe.name, 1))
			end
            SendRPCToServer(RPC.MakeRecipeFromMenu, recipe.rpc_id, skin_index)
        elseif self:CanLocomote() then
            self.locomotor:Stop()
            local buffaction = BufferedAction(self.inst, nil, ACTIONS.BUILD, nil, nil, recipe.name, 1)
            buffaction.preview_cb = function()
                SendRPCToServer(RPC.MakeRecipeFromMenu, recipe.rpc_id, skin_index)
            end
            self.locomotor:PreviewAction(buffaction, true)
        end
    end
end

function PlayerController:RemoteMakeRecipeAtPoint(recipe, pt, rot, skin)
    if not self.ismastersim then
        local skin_index = skin ~= nil and PREFAB_SKINS_IDS[recipe.name][skin] or nil
        if self.locomotor == nil then
			-- NOTES(JBK): Does not call locomotor component functions needed for pre_action_cb, manual call here.
			if ACTIONS.BUILD.pre_action_cb ~= nil then
				ACTIONS.BUILD.pre_action_cb(BufferedAction(self.inst, nil, ACTIONS.BUILD, nil, pt, recipe.name, 1, nil, rot))
			end
	        local platform, pos_x, pos_z = self:GetPlatformRelativePosition(pt.x, pt.z)
            SendRPCToServer(RPC.MakeRecipeAtPoint, recipe.rpc_id, pos_x, pos_z, rot, skin_index, platform, platform ~= nil)
        elseif self:CanLocomote() then
            self.locomotor:Stop()
            local act = BufferedAction(self.inst, nil, ACTIONS.BUILD, nil, pt, recipe.name, 1, nil, rot)
            act.preview_cb = function()
                SendRPCToServer(RPC.MakeRecipeAtPoint, recipe.rpc_id, act.pos.local_pt.x, act.pos.local_pt.z, rot, skin_index, act.pos.walkable_platform, act.pos.walkable_platform ~= nil)
            end
            self.locomotor:PreviewAction(act, true)
        end
    end
end

function PlayerController:RemoteBufferedAction(buffaction)
	if self.classified and self.classified.iscontrollerenabled:value() then
		if self.client_last_predict_walk.tick then
			local x, y, z = self.inst.Transform:GetWorldPosition() --V2C: not GetPredictionPosition()
			--V2C: Physics:Stop() fixed to stop at last sim position; no need to correct local position anymore
			--self.inst.Transform:SetPosition(x, 0, z) --V2C: correcting local position, no need to account for platform
			self:RemotePredictWalking(x, z, self.locomotor:GetTimeMoving() == 0, self.locomotor:PopOverrideTimeMoving(), self.client_last_predict_walk.direct)
			self.client_last_predict_walk.tick = nil
		end
		buffaction.preview_cb()
	else
		self.client_last_predict_walk.tick = nil
	end
end

function PlayerController:OnRemoteBufferedAction()
    if self.ismastersim then
        --If we're starting a remote buffered action, prevent the last
        --movement prediction vector from cancelling us out right away
		local pt = self:GetRemotePredictPosition()
		if pt then
			if pt.y < 5 and not self:IsBusy() then
				--excludes self:IsLocalOrRemoteHopping() as well, ie. y ~= 6
				local x, y, z = self.inst.Transform:GetWorldPosition()
				local dx = pt.x - x
				local dz = pt.z - z
				if (dx ~= 0 or dz ~= 0) and (self.remote_authority or dx * dx + dz * dz <= PREDICT_STOP_ERROR_DISTANCE_SQ) then
					local dir = math.atan2(-dz, dx) * RADIANS
					if self.inst.sg:HasStateTag("canrotate") then
						self.locomotor:SetMoveDir(dir)
					end
					--Force us to interrupt and go to movement state immediately
					self.inst.sg:HandleEvent("locomote", { dir = dir, force_idle_state = true }) --force idle state in case this tiny motion was meant to cancel an action
					--FIXME(JBK): Boat handling.
					--FIXED(V2C): Remote predict position now resolves platform relative positions from client.
					self.locomotor:Stop()
					self.inst.Transform:SetPosition(pt.x, 0, pt.z)
				end
			end
            self.remote_vector.y = 5
        elseif self.remote_vector.y == 0 then
            self.directwalking = false
            self.dragwalking = false
            self.predictwalking = false
        end
    end
end

--This is just for friendly interactions where some brains may have logic to stop and wait for you.
local CREATURE_INTERACTIONS =
{
	[ACTIONS.GIVE] = true,
	[ACTIONS.FEED] = true,
	[ACTIONS.HEAL] = true,
	[ACTIONS.STORE] = true,
	[ACTIONS.RUMMAGE] = true,
	[ACTIONS.MOUNT] = true,
	[ACTIONS.PICKUP] = true,

	--Webber
	[ACTIONS.MUTATE_SPIDER] = true,
}

function PlayerController:OnRemoteInteractionTarget(actioncode, target)
	self.remoteinteractionaction = ACTIONS_BY_ACTION_CODE[actioncode]
	self.remoteinteractiontarget = target
	--print(string.format("[%s] <remote interact>: %s -> [%s]", tostring(self.inst), tostring(self.remoteinteractionaction and self.remoteinteractionaction.id or nil), tostring(target)))
end

function PlayerController:RemoteInteractionTarget(actioncode, target)
	if self.remoteinteractionaction ~= actioncode or self.remoteinteractiontarget ~= target then
		self.remoteinteractionaction = actioncode
		self.remoteinteractiontarget = target
		SendRPCToServer(RPC.InteractionTarget, actioncode, target)
	end
end

function PlayerController:GetRemoteInteraction()
	return self.remoteinteractionaction, self.remoteinteractiontarget
end

function PlayerController:OnLocomotorBufferedAction(act)
	local dir
	if self.handler == nil then
		dir = self:GetRemoteDirectVector()

		--Clear any remote interactions if server takes over
		self.remoteinteractionaction = nil
		self.remoteinteractiontarget = nil
	else
		dir = GetWorldControllerVector()

		local actioncode, target
		if not self.ismastersim and
			CREATURE_INTERACTIONS[act.action] and
			act.target and
			act.target:IsValid() and
			act.target:HasTag("locomotor")
		then
			actioncode = act.action.code
			target = act.target
			act:AddSuccessAction(self._clearinteractiontarget)
			act:AddFailAction(self._clearinteractiontarget)
		end
		self:RemoteInteractionTarget(actioncode, target)
	end
	if dir ~= nil then
		self.recent_bufferedaction.act = act
		self.recent_bufferedaction.t = act.action == ACTIONS.CASTAOE and BUFFERED_CASTAOE_TIME or BUFFERED_ACTION_NO_CANCEL_TIME
		self.recent_bufferedaction.x = dir.x
		self.recent_bufferedaction.z = dir.z
	end
end

local function OnNewState(inst)--, data)
	--V2C: -Don't use data.statename
	--     -"newstate" events are fired off in reverse order when chaining GoToState calls in the state's onenter
	--
	--#V2C #client_prediction
	--force dirty
	--see SGWilson_client -> ClearCachedServerState
	inst.player_classified.currentstate:set_local(0)
	inst.player_classified.currentstate:set(inst.sg ~= nil and inst.sg.currentstate.name or 0)
end

function PlayerController:OnRemoteToggleMovementPrediction(val)
	if self.ismastersim and self.remote_predicting ~= val then
		self.remote_predicting = val
		self.locomotor:Stop()
		self.locomotor:Clear()
		self.locomotor:SetAllowPlatformHopping(not val)
		self:ResetRemoteController()
		if val then
			self.inst:ListenForEvent("newstate", OnNewState)
			self.classified.currentstate:set(self.inst.sg.currentstate ~= nil and self.inst.sg.currentstate.name or 0)
		else
			self.inst:RemoveEventCallback("newstate", OnNewState)
			self.classified.currentstate:set(0)
		end
	end
end

return PlayerController
