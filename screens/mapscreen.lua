local Screen = require "widgets/screen"
local MapWidget = require("widgets/mapwidget")
local Widget = require "widgets/widget"
local MapControls = require "widgets/mapcontrols"
local HudCompass = require "widgets/hudcompass"
local HoverText = require("widgets/hoverer")
local Text = require("widgets/text")

-- NOTES(JBK): These constants are from MiniMapRenderer ZOOM_CLAMP_MIN and ZOOM_CLAMP_MAX
local ZOOM_CLAMP_MIN = 1
local ZOOM_CLAMP_MAX = 20

local MapScreen = Class(Screen, function(self, owner)
    self.owner = owner
    Screen._ctor(self, "MapScreen")
    self.minimap = self:AddChild(MapWidget(self.owner))

    self.bottomright_root = self:AddChild(Widget("br_root"))
    self.bottomright_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.bottomright_root:SetHAnchor(ANCHOR_RIGHT)
    self.bottomright_root:SetVAnchor(ANCHOR_BOTTOM)
    self.bottomright_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.bottomright_root = self.bottomright_root:AddChild(Widget("br_scale_root"))
    self.bottomright_root:SetScale(TheFrontEnd:GetHUDScale())
    self.bottomright_root.inst:ListenForEvent("refreshhudsize", function(hud, scale) self.bottomright_root:SetScale(scale) end, owner.HUD.inst)

    if not TheInput:ControllerAttached() then
        self.mapcontrols = self.bottomright_root:AddChild(MapControls())
        self.mapcontrols:SetPosition(-60,70,0)
        self.mapcontrols.pauseBtn:Hide()
    end

    self.hover = self:AddChild(HoverText(self.owner))
    self.hover:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.hudcompass = self.bottomright_root:AddChild(HudCompass(self.owner, false))
    self.hudcompass:SetPosition(-160,70,0)

    self.zoom_to_cursor = Profile:IsMinimapZoomCursorFollowing()
    self.zoom_target = self.minimap:GetZoom()
    self.zoom_old = self.zoom_target
    self.zoom_target_time = 0
    self.zoomsensitivity = 15
    self.decorationdata = {}
    local decorationroot = self.minimap:AddChild(Widget("decor_root"))
    decorationroot:SetHAnchor(ANCHOR_MIDDLE)
    decorationroot:SetVAnchor(ANCHOR_MIDDLE)
    self.decorationrootlmb = decorationroot:AddChild(Widget("decorlmb_root"))
    self.decorationrootrmb = decorationroot:AddChild(Widget("decorrmb_root"))

    SetAutopaused(true)
end)

function MapScreen:RemoveLMBDecorations()
    self.decorationdata.lmbents = nil
    self.decorationrootlmb:KillAllChildren()
end

function MapScreen:RemoveRMBDecorations()
    self.decorationdata.rmbents = nil
    self.decorationrootrmb:KillAllChildren()
end

function MapScreen:RemoveDecorations()
    self:RemoveLMBDecorations()
    self:RemoveRMBDecorations()
end

function MapScreen:OnBecomeInactive()
    MapScreen._base.OnBecomeInactive(self)

    --NOTE: this could be due to a screen pushed on top of us (e.g. consolescreen)
    --      handle closing the map screen in OnDestroy

    self.hover.forcehide = true
    self.hover:Hide()
    self.minimap.centerreticle:Hide()

    self:RemoveDecorations()
    self.decorationdata.lmb = nil
    self.decorationdata.rmb = nil
end

function MapScreen:OnBecomeActive()
    MapScreen._base.OnBecomeActive(self)

    if not TheWorld.minimap.MiniMap:IsVisible() then
        TheWorld.minimap.MiniMap:ToggleVisibility()
    end
    self.minimap:UpdateTexture()

    if self.owner.HUD and self.owner.HUD.controls and self.owner.HUD.controls.hover then
        self.owner.HUD.controls.hover.forcehide = true
        self.owner.HUD.controls.hover:Hide()
    end
    self.hover.forcehide = nil
    if TheInput:ControllerAttached() then
        self.hover:Hide()
        self.minimap.centerreticle:Show()
    else
        self.minimap.centerreticle:Hide()
        self.hover:Show()
        local scale = TheFrontEnd:GetHUDScale()
        self.hover:SetScale(scale)
    end

    self.zoomsensitivity = Profile:GetMiniMapZoomSensitivity()
    --V2C: Don't set pause in multiplayer, all it does is change the
    --     audio settings, which we don't want to do now
    --SetPause(true)
end

function MapScreen:OnDestroy()
    if TheWorld.minimap.MiniMap:IsVisible() then
        TheWorld.minimap.MiniMap:ToggleVisibility()
    end
    self.hover:Hide()
    if self.owner.HUD and self.owner.HUD.controls and self.owner.HUD.controls.hover then
        self.owner.HUD.controls.hover.forcehide = nil
    end

    self:RemoveDecorations()

    --V2C: Don't set pause in multiplayer, all it does is change the
    --     audio settings, which we don't want to do now
    --SetPause(false)
    if not self.quitting then
        SetAutopaused(false)
    end

	MapScreen._base.OnDestroy(self)
end

function MapScreen:GetZoomOffset(scaler)
    -- NOTES(JBK): The magic constant 9 comes from the scaler in MiniMapRenderer ZOOM_MODIFIER.
    local zoomfactor = 9 * self.minimap:GetZoom() / scaler
    local x, y = self:GetCursorPosition()
    local w, h = TheSim:GetScreenSize()
    x = x * w / zoomfactor
    y = y * h / zoomfactor
    return x, y
end

function MapScreen:DoZoomIn(negativedelta)
    self.decorationdata.dirty = true
    negativedelta = negativedelta or -0.1
    -- Run the function always, conditionally do offset fixup.
    if self.minimap:OnZoomIn(negativedelta) and self.zoom_to_cursor then
        local x, y = self:GetZoomOffset(-negativedelta)
        self.minimap:Offset(-x, -y)
    end
end

function MapScreen:DoZoomOut(positivedelta)
    self.decorationdata.dirty = true
    positivedelta = positivedelta or 0.1
    -- Run the function always, conditionally do offset fixup.
    if self.minimap:OnZoomOut(positivedelta) and self.zoom_to_cursor then
        local x, y = self:GetZoomOffset(positivedelta)
        self.minimap:Offset(x, y)
    end
end

function MapScreen:SetZoom(zoom_target)
    self.zoom_target = zoom_target
    self.zoom_old = zoom_target
    self.zoom_target_time = 0
    -- NOTES(JBK): Do deltas to be more mod compliant that expect deltas in OnZoomIn and OnZoomOut functions.
    local deltazoom = zoom_target - self.minimap:GetZoom()
    if deltazoom < 0 then
    	self.minimap:OnZoomIn(deltazoom)
    elseif deltazoom > 0 then
        self.minimap:OnZoomOut(deltazoom)
    end
end

function MapScreen:UpdateMapActions(x, y, z)
    if ThePlayer and ThePlayer.components.playeractionpicker and ThePlayer.components.playercontroller then
        local pc = ThePlayer.components.playercontroller
        pc.LMBaction, pc.RMBaction = pc:GetMapActions(Vector3(x, y, z))
        return pc.LMBaction, pc.RMBaction
    end
    return nil, nil
end

function MapScreen:ProcessLMBDecorations(lmb, fresh)
    if fresh then
        self.decorationdata.lmbents = {}
    end
    -- Nothing yet!
end

function MapScreen:ProcessRMBDecorations(rmb, fresh)
    if fresh then
        self.decorationdata.rmbents = {}
    end
    if rmb.action == ACTIONS.BLINK_MAP then
        local decor1, decor2, decor3
        if fresh then
            local image = "wortox_soul.tex"
            local atlas = GetInventoryItemAtlas(image)
            decor1 = self.decorationrootrmb:AddChild(Image(atlas, image))
            decor1.text = decor1:AddChild(Text(NUMBERFONT, 42))
            decor2 = self.decorationrootrmb:AddChild(Image(atlas, image))
            decor2.text = decor2:AddChild(Text(NUMBERFONT, 42))
            decor3 = self.decorationrootrmb:AddChild(Image(atlas, image))
            decor3.text = decor3:AddChild(Text(NUMBERFONT, 42))
            self.decorationdata.rmbents[1] = decor1
            self.decorationdata.rmbents[2] = decor2
            self.decorationdata.rmbents[3] = decor3
        else
            decor1 = self.decorationdata.rmbents[1]
            decor2 = self.decorationdata.rmbents[2]
            decor3 = self.decorationdata.rmbents[3]
        end
        local rmb_pos = rmb:GetActionPoint()
        local px, py, pz = 0, 0, 0
        if rmb.doer then
            px, py, pz = rmb.doer.Transform:GetWorldPosition()
        end
        local dx, dz = rmb_pos.x - px, rmb_pos.z - pz
        local dist = math.sqrt(dx * dx + dz * dz)
        local zoomscale = 0.75 / self.minimap:GetZoom()
        local alphascaler = math.clamp(rmb.distancecount - rmb.distancefloat, 0, 1)
        local alphascale1 = alphascaler * 5 - 4
        local alphascale2 = (1 - alphascaler) * 3 - 2
        local w, h = TheSim:GetScreenSize()
        w, h = w * 0.5, h * 0.5
        -- TODO(JBK): Clean this up.
        -- With the math the alphascale# no two icons will be present at any time now so this can simplify further.
        -- Keeping the blob here for now in case this needs to change more.
        if rmb.aimassisted then
            decor3:Show()
            local x, y = self.minimap:WorldPosToMapPos(rmb_pos.x, rmb_pos.z, 0)
            decor3:SetPosition(x * w, y * h)
            decor3:SetScale(zoomscale, zoomscale, 1)
            decor3.text:SetString(tostring(rmb.distancecount))
        else
            decor3:Hide()
        end
        if dist < 0.1 then
            decor1:Hide()
            decor2:Hide()
        elseif dist < rmb.distanceperhop - rmb.distancemod then
            decor1:Hide()
            decor2:Show()
            local r = (rmb.distancecount * rmb.distanceperhop - rmb.distancemod) / dist
            local ndx, ndz = dx * r + px, dz * r + pz
            local x, y = self.minimap:WorldPosToMapPos(ndx, ndz, 0)
            decor2:SetPosition(x * w, y * h)
            decor2:SetTint(alphascale2, alphascale2, alphascale2, alphascale2)
            decor2:SetScale(zoomscale, zoomscale, 1)
            decor2.text:SetString(tostring(rmb.distancecount + 1))
            decor2.text:SetColour(alphascale2, alphascale2, alphascale2, alphascale2)
        elseif dist < (rmb.distanceperhop - rmb.distancemod) * (rmb.maxsouls - 1) then
            decor1:Show()
            decor2:Show()
            local r = ((rmb.distancecount - 1) * rmb.distanceperhop - rmb.distancemod) / dist
            local ndx, ndz = dx * r + px, dz * r + pz
            local x, y = self.minimap:WorldPosToMapPos(ndx, ndz, 0)
            decor1:SetPosition(x * w, y * h)
            decor1:SetTint(alphascale1, alphascale1, alphascale1, alphascale1)
            decor1:SetScale(zoomscale, zoomscale, 1)
            decor1.text:SetString(tostring(rmb.distancecount))
            decor1.text:SetColour(alphascale1, alphascale1, alphascale1, alphascale1)
            r = (rmb.distancecount * rmb.distanceperhop - rmb.distancemod) / dist
            ndx, ndz = dx * r + px, dz * r + pz
            x, y = self.minimap:WorldPosToMapPos(ndx, ndz, 0)
            decor2:SetPosition(x * w, y * h)
            decor2:SetTint(alphascale2, alphascale2, alphascale2, alphascale2)
            decor2:SetScale(zoomscale, zoomscale, 1)
            decor2.text:SetString(tostring(rmb.distancecount + 1))
            decor2.text:SetColour(alphascale2, alphascale2, alphascale2, alphascale2)
        else
            decor1:Show()
            decor2:Hide()
            local r = ((rmb.distancecount - 1) * rmb.distanceperhop - rmb.distancemod) / dist
            local ndx, ndz = dx * r + px, dz * r + pz
            local x, y = self.minimap:WorldPosToMapPos(ndx, ndz, 0)
            decor1:SetPosition(x * w, y * h)
            decor1:SetTint(alphascale1, alphascale1, alphascale1, alphascale1)
            decor1:SetScale(zoomscale, zoomscale, 1)
            decor1.text:SetString(tostring(rmb.distancecount))
            decor1.text:SetColour(alphascale1, alphascale1, alphascale1, alphascale1)
        end
    elseif rmb.action == ACTIONS.TOSS_MAP then
        local equippedhands = self.owner.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if equippedhands == nil then
            return
        end
        
        local does_custom = equippedhands.InitMapDecorations ~= nil and equippedhands.CalculateMapDecorations ~= nil
        if does_custom then
            if fresh then
                local decordatas = equippedhands:InitMapDecorations()
                for i, decordata in ipairs(decordatas) do
                    self.decorationdata.rmbents[i] = self.decorationrootrmb:AddChild(Image(decordata.atlas, decordata.image))
                    self.decorationdata.rmbents[i].scale = decordata.scale
                end
            end

            local zoomscale = 1 / self.minimap:GetZoom()
            local w, h = TheSim:GetScreenSize()
            w, h = w * 0.5, h * 0.5

            local rmb_pos = rmb:GetActionPoint()
            local px, py, pz = 0, 0, 0
            if rmb.doer then
                px, py, pz = rmb.doer.Transform:GetWorldPosition()
            end
            equippedhands:CalculateMapDecorations(self.decorationdata.rmbents, px, pz, rmb_pos.x, rmb_pos.z)
            for _, decor in ipairs(self.decorationdata.rmbents) do
                local scaler = decor.scale or 1
                local x, y = self.minimap:WorldPosToMapPos(decor.worldx, decor.worldz, 0)
                decor:SetPosition(x * w, y * h)
                decor:SetScale(zoomscale * scaler, zoomscale * scaler, 1)
            end
            return
        end


        -- Default behaviour is one default icon to toss towards a point.
        local decor
        if fresh then
            local image = equippedhands.replica.inventoryitem:GetImage()
            decor = self.decorationrootrmb:AddChild(Image(GetInventoryItemAtlas(image), image))
            self.decorationdata.rmbents[1] = decor
        else
            decor = self.decorationdata.rmbents[1]
        end

        if decor == nil then
            return
        end
        
        local rmb_pos = rmb:GetActionPoint()
        local px, py, pz = 0, 0, 0
        if rmb.doer then
            px, py, pz = rmb.doer.Transform:GetWorldPosition()
        end
        local dx, dz = rmb_pos.x - px, rmb_pos.z - pz
        local zoomscale = 1 / self.minimap:GetZoom()
        local w, h = TheSim:GetScreenSize()
        w, h = w * 0.5, h * 0.5
        
        local r = 1
        local ndx, ndz = dx * r + px, dz * r + pz
        local x, y = self.minimap:WorldPosToMapPos(ndx, ndz, 0)
        decor:SetPosition(x * w, y * h)
        decor:SetScale(zoomscale, zoomscale, 1)
    end
end

function MapScreen:UpdateMapActionsDecorations(x, y, z, LMBaction, RMBaction)
    local lmb = LMBaction and LMBaction.action or nil
    local rmb = RMBaction and RMBaction.action or nil
    local dd = self.decorationdata
    if dd.dirty or dd.x ~= x or dd.y ~= y or dd.z ~= z or dd.lmb ~= lmb or dd.rmb ~= rmb then
        dd.dirty = nil
        dd.x, dd.y, dd.z = x, y, z
        local lmbfresh = dd.lmb ~= lmb
        if lmbfresh then
            self:RemoveLMBDecorations()
            dd.lmb = lmb
        end
        if lmb and lmb.map_action then
            self:ProcessLMBDecorations(LMBaction, lmbfresh)
        end
        local rmbfresh = dd.rmb ~= rmb
        if rmbfresh then
            self:RemoveRMBDecorations()
            dd.rmb = rmb
        end
        if rmb and rmb.map_action then
            self:ProcessRMBDecorations(RMBaction, rmbfresh)
        end
    end
end

function MapScreen:OnUpdate(dt)
    if self._hack_ignore_held_controls then
        self._hack_ignore_held_controls = self._hack_ignore_held_controls - dt
        if self._hack_ignore_held_controls < 0 then
            self._hack_ignore_held_controls = nil
        end
    end
    local s = -100 * dt -- now per second, not per repeat

    -- NOTES(JBK): Controllers apply smooth analog input so use it for more precision with joysticks.
    local xdir = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    local ydir = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
    local xmag = xdir * xdir + ydir * ydir
    local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
    if xmag >= deadzone * deadzone then
        self.minimap:Offset(xdir * s, ydir * s)
    end

    -- NOTES(JBK): In order to change digital to analog without causing issues engine side with prior binds we emulate it.
    local indir = TheInput:IsControlPressed(CONTROL_MAP_ZOOM_IN) and -1 or 0
    local outdir = TheInput:IsControlPressed(CONTROL_MAP_ZOOM_OUT) and 1 or 0
    local inoutdir = indir + outdir
    local TIMETOZOOM = 0.1
    if inoutdir ~= 0 then
        self.zoom_target_time = TIMETOZOOM -- How much time remaining to get to the desired target.
        local exponential_factor = 1 / 60
        if not TheInput:ControllerAttached() then -- Controllers don't need this extra speed boosts with how digital inputs are handled.
            exponential_factor = exponential_factor * self.zoom_target
        end
        self.zoom_target = math.clamp(self.zoom_target + self.zoomsensitivity * inoutdir * exponential_factor, ZOOM_CLAMP_MIN, ZOOM_CLAMP_MAX)
        self.zoom_old = self.minimap:GetZoom()
    end
    if self.zoom_target_time > 0 then
        self.zoom_target_time = math.max(0, self.zoom_target_time - dt)
        local zoom_desired = Lerp(self.zoom_old, self.zoom_target, 1.0 - self.zoom_target_time / TIMETOZOOM)
        local zoom_delta = zoom_desired - self.minimap:GetZoom()
        if zoom_delta < 0 then
            self:DoZoomIn(zoom_delta)
        elseif zoom_delta > 0 then
            self:DoZoomOut(zoom_delta)
        end
    end

    local x, y, z = self:GetWorldPositionAtCursor()
    local LMBaction, RMBaction = self:UpdateMapActions(x, y, z)
    self:UpdateMapActionsDecorations(x, y, z, LMBaction, RMBaction)
end

function MapScreen:GetCursorPosition()
    -- This function uses the origin at the center of the screen.
    -- Outputs are normalized from -1 to 1 on both axii.
    local x, y
    if TheInput:ControllerAttached() then
        x, y = 0, 0 -- Controller users do not have a cursor to control so center it.
    else
        x, y = TheSim:GetPosition()
        local w, h = TheSim:GetScreenSize()
        x = 2 * x / w - 1
        y = 2 * y / h - 1
    end
    return x, y
end

function MapScreen:GetWorldPositionAtCursor()
    local x, y = self:GetCursorPosition()
    x, y = self.minimap:MapPosToWorldPos(x, y, 0)
    return x, 0, y -- Coordinate conversion from minimap widget to world.
end

function MapScreen:OnControl(control, down)
    if MapScreen._base.OnControl(self, control, down) then return true end

    if down and self._hack_ignore_held_controls then
        self._hack_ignore_ups_for[control] = true
        return true
    end
    if not down and self._hack_ignore_ups_for and self._hack_ignore_ups_for[control] then
        self._hack_ignore_ups_for[control] = nil
        return true
    end

    if not down and (control == CONTROL_MAP or control == CONTROL_CANCEL) then
        TheFrontEnd:PopScreen()
        return true
    end

    if not (down and self.shown) then
        return false
    end

    local pc = ThePlayer and ThePlayer.components.playercontroller

    if pc and control == CONTROL_ROTATE_LEFT then
        pc:RotLeft()
    elseif pc and control == CONTROL_ROTATE_RIGHT then
        pc:RotRight()
    elseif control == CONTROL_MAP_ZOOM_IN then -- NOTES(JBK): Keep these here for mods but modify their value to do nothing with new code.
        self:DoZoomIn(0)
    elseif control == CONTROL_MAP_ZOOM_OUT then
        self:DoZoomOut(0)
    elseif pc and (control == CONTROL_SECONDARY or control == CONTROL_CONTROLLER_ATTACK) then
        local x, y, z = self:GetWorldPositionAtCursor()
        local _, RMBaction = self:UpdateMapActions(x, y, z)
        if RMBaction then
            if not self.quitting and RMBaction.invobject ~= nil and RMBaction.invobject:HasTag("action_pulls_up_map") then
                SetAutopaused(false)
                self.quitting = true
            end
            pc:OnMapAction(RMBaction.action.code, Vector3(x, y, z))
        end
    else
        return false
    end
    return true
end

function MapScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    local t = {}

    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_ROTATE_LEFT) .. " " .. STRINGS.UI.HELP.ROTATE_LEFT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_ROTATE_RIGHT) .. " " .. STRINGS.UI.HELP.ROTATE_RIGHT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_MAP_ZOOM_IN) .. " " .. STRINGS.UI.HELP.ZOOM_IN)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_MAP_ZOOM_OUT) .. " " .. STRINGS.UI.HELP.ZOOM_OUT)
    table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)
    local pc = ThePlayer and ThePlayer.components.playercontroller or nil
    if pc and pc.RMBaction then
        table.insert(t,  TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ATTACK) .. " " .. pc.RMBaction:GetActionString())
    end

    return table.concat(t, "  ")
end


-- NOTES(JBK): These functions are not accurate and need fixed to do proper scaling calculations relative to window size and not internal render size.

--[[ EXAMPLE of map coordinate functions
function MapScreen:NearestEntToCursor()
    local closestent = nil
    local closest = nil
    for ent,_ in pairs(someentities) do
        local ex,ey,ez = ent.Transform:GetWorldPosition()
        local entpos = self:MapPosToWidgetPos( Vector3(self.minimap:WorldPosToMapPos(ex,ez,0)) )
        local mousepos = self:ScreenPosToWidgetPos( TheInput:GetScreenPosition() )
        local delta = mousepos - entpos

        local length = delta:Length()
        if length < 30 then
            if closest == nil or length < closest then
                closestent = ent
                closest = length
            end
        end
    end

    if closestent ~= nil then
        local ex,ey,ez = closestent.Transform:GetWorldPosition()
        local entpos = self:MapPosToWidgetPos( Vector3(self.minimap:WorldPosToMapPos(ex,ez,0)) )

        self.hovertext:SetPosition(entpos:Get())
        self.hovertext:Show()
    else
        self.hovertext:Hide()
    end
end
]]

function MapScreen:MapPosToWidgetPos(mappos)
    return Vector3(
        mappos.x * RESOLUTION_X/2,
        mappos.y * RESOLUTION_Y/2,
        0
    )
end

function MapScreen:ScreenPosToWidgetPos(screenpos)
    local w, h = TheSim:GetScreenSize()
    return Vector3(
        screenpos.x / w * RESOLUTION_X - RESOLUTION_X/2,
        screenpos.y / h * RESOLUTION_Y - RESOLUTION_Y/2,
        0
    )
end

function MapScreen:WidgetPosToMapPos(widgetpos)
    return Vector3(
        widgetpos.x / (RESOLUTION_X/2),
        widgetpos.y / (RESOLUTION_Y/2),
        0
    )
end

return MapScreen
