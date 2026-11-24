local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"

local GetModuleDefinitionFromNetID = require("wx78_moduledefs").GetModuleDefinitionFromNetID

-------------------------------------------------------------------------------------------------------

-- OMAR: magic numbers to fit the invisible black focus box to the UI :,^)
local FOCUS_BOX_CLOSED_SCALE_X = 1.2
local FOCUS_BOX_CLOSED_SCALE_Y = 3

local FOCUS_BOX_OPEN_SCALE_X = 5.8
local FOCUS_BOX_OPEN_SCALE_Y = 3

local FOCUS_BOX_EXTENDED_SCALE_Y = 7/6 -- applied to the above

local function FocusBox_OnGainFocus(self, ...)
    self._base.OnGainFocus(self, ...)
    self.parent:Open()
end

local function FocusBox_OnLoseFocus(self, ...)
    self._base.OnLoseFocus(self, ...)
    self.parent:Close()
end

local UpgradeModulesDisplay = Class(Widget, function(self, owner, reversed)
    Widget._ctor(self, "UpgradeModulesDisplay")
    self:UpdateWhilePaused(false)
    self.owner = owner

    --self:SetHAnchor(ANCHOR_RIGHT)
    --self:SetVAnchor(ANCHOR_TOP)
    local max_energy = owner:GetMaxEnergy()
    self.max_energy = max_energy
    self.energy_level = max_energy

    local scale = 0.7
    if IsGameInstance(Instances.Player2) then
        -- self.reversed = true
        self:SetScale(-scale, scale, scale)
    else
        -- self.reversed = false
        self:SetScale(scale, scale, scale)
    end

    self.battery_frame = self:AddChild(UIAnim())
    self.battery_frame:GetAnimState():SetBank("status_wx")
    self.battery_frame:GetAnimState():SetBuild("status_wx")
    self.battery_frame:GetAnimState():PlayAnimation("frame")
    self.battery_frame:GetAnimState():AnimateWhilePaused(false)

    self.energy_backing = self:AddChild(UIAnim())
    self.energy_backing:GetAnimState():SetBank("status_wx")
    self.energy_backing:GetAnimState():SetBuild("status_wx")
    self.energy_backing:GetAnimState():PlayAnimation("energy3")
    self.energy_backing:GetAnimState():AnimateWhilePaused(false)

    self.energy_blinking = self:AddChild(UIAnim())
    self.energy_blinking:GetAnimState():SetBank("status_wx")
    self.energy_blinking:GetAnimState():SetBuild("status_wx")
    self.energy_blinking:GetAnimState():PlayAnimation("energy2")
    self.energy_blinking:GetAnimState():AnimateWhilePaused(false)

    self.anim = self:AddChild(UIAnim())
    self.anim:GetAnimState():SetBank("status_wx")
    self.anim:GetAnimState():SetBuild("status_wx")
    self.anim:GetAnimState():PlayAnimation("energy1")
    self.anim:GetAnimState():AnimateWhilePaused(false)

    self.energy_nightmare = self:AddChild(UIAnim()) -- timer bar for the nightmare energy buff
    self.energy_nightmare:GetAnimState():SetBank("status_wx")
    self.energy_nightmare:GetAnimState():SetBuild("status_wx")
    self.energy_nightmare:GetAnimState():PlayAnimation("energy_nightmare")
    self.energy_nightmare:GetAnimState():AnimateWhilePaused(false)
    self.energy_nightmare:Hide()

    self.energy_nightmare_top = self.energy_nightmare:AddChild(UIAnim())
    self.energy_nightmare_top:GetAnimState():SetBank("status_wx")
    self.energy_nightmare_top:GetAnimState():SetBuild("status_wx")
    self.energy_nightmare_top:GetAnimState():PlayAnimation("energy_nightmare_top", true)
    self.energy_nightmare_top:GetAnimState():AnimateWhilePaused(false)

    self.energy_nightmare_glow = self.energy_nightmare:AddChild(UIAnim())
    self.energy_nightmare_glow:GetAnimState():SetBank("status_wx")
    self.energy_nightmare_glow:GetAnimState():SetBuild("status_wx")
    self.energy_nightmare_glow:GetAnimState():PlayAnimation("energy_nightmare_glow", true)
    self.energy_nightmare_glow:GetAnimState():AnimateWhilePaused(false)

    self.module_bars = {}

    self.chip_objectpools = {}
    self.chip_poolindexes = {}
    self.chip_slotsinuse = {}
    for v = GetTableSize(CIRCUIT_BARS), 0, -1 do
        local bar_frame = self:AddChild(UIAnim())
        bar_frame:GetAnimState():SetBank("status_wx")
        bar_frame:GetAnimState():SetBuild("status_wx")
        bar_frame:GetAnimState():PlayAnimation("frame_close")
        bar_frame:GetAnimState():Hide("frame")
        bar_frame:GetAnimState():Hide("frame_extended")
        bar_frame:GetAnimState():Hide("barframe1")
        bar_frame:GetAnimState():Hide("barframe2")
        bar_frame:GetAnimState():Hide("barframe3")
        bar_frame:GetAnimState():Hide("barframe1_extended")
        bar_frame:GetAnimState():Hide("barframe2_extended")
        bar_frame:GetAnimState():Hide("barframe3_extended")
        bar_frame:GetAnimState():Show("barframe"..(v + 1))
        bar_frame:MoveToBack()
        self.module_bars[v] = bar_frame

        self.chip_objectpools[v] = {}
        for i = 1, MAX_CIRCUIT_SLOTS do
            local chip_object = bar_frame:AddChild(UIAnim())
            chip_object:GetAnimState():SetBank("status_wx")
            chip_object:GetAnimState():SetBuild("status_wx")

            chip_object:GetAnimState():Hide("plug_on")
            chip_object:GetAnimState():Hide("glow")
            chip_object._power_hidden = true

            chip_object:Hide()

            chip_object.cooldown = chip_object:AddChild(UIAnim())
            chip_object.cooldown:GetAnimState():SetBank("status_wx")
            chip_object.cooldown:GetAnimState():SetBuild("status_wx")
            chip_object.cooldown:GetAnimState():SetMultColour(0.4, 0.4, 0.4, 0.4)

            table.insert(self.chip_objectpools[v], chip_object)
        end

        self.chip_slotsinuse[v] = 0
        self.chip_poolindexes[v] = 1
    end

    --
    self.focus_box = self:AddChild(Image("images/global.xml", "square.tex"))
	self.focus_box:SetTint(0, 0, 0, 0)
    self.focus_box:SetScale(FOCUS_BOX_CLOSED_SCALE_X, FOCUS_BOX_CLOSED_SCALE_Y)
    self.focus_box:MoveToFront()
    self.focus_box.OnGainFocus = FocusBox_OnGainFocus
    self.focus_box.OnLoseFocus = FocusBox_OnLoseFocus
    --
    self._overrideenergywithshadow = false
    self.inst:ListenForEvent("wx78_abilitycooldowns_update", function(_, data) self:UpdateAbilityCooldowns() end, owner)
    self:UpdateAbilityCooldowns()
    self:StartUpdating()
    self:UpdateMaxEnergy(self.max_energy, self.max_energy)
end)

function UpgradeModulesDisplay:UpdateAbilityCooldowns()
    local old_override = self._overrideenergywithshadow
    self._overrideenergywithshadow = self.owner.components.wx78_abilitycooldowns:IsInCooldown("shadow_energy") or false

    if old_override ~= self._overrideenergywithshadow then
        if self._overrideenergywithshadow then
            self.energy_nightmare_top:Show()
            self.energy_nightmare:Hide()
            self.energy_nightmare_glow:UnhookCallback("animover")
            self.energy_nightmare_glow:GetAnimState():PlayAnimation("energy_nightmare_glow", true)
            self.energy_backing:Hide()
            self.energy_blinking:Hide()
            self.anim:Hide()
            self.energy_nightmare:Show()
            TheFrontEnd:GetSound():PlaySound("WX_rework/charge/shadowgauge_up")
        else
            TheFrontEnd:GetSound():PlaySound("WX_rework/charge/shadowgauge_off")
            self.energy_nightmare_glow:GetAnimState():PlayAnimation("energy_nightmare_glow_pst")
            self.energy_nightmare_glow:UnhookCallback("animover")
            self.energy_nightmare_glow:HookCallback("animover", function()
                self.energy_nightmare_top:Show()
                self.energy_nightmare:Hide()
                self.energy_nightmare_glow:UnhookCallback("animover")
                self.energy_nightmare_glow:GetAnimState():PlayAnimation("energy_nightmare_glow", true)
            end)
            self.energy_backing:Show()
            self.energy_blinking:Show()
            self.anim:Show()
            self.energy_nightmare_top:Hide()
        end
        self:UpdateChipCharges(true)
    end
end

function UpgradeModulesDisplay:IsExtended()
    return self.max_energy >= 7
end

function UpgradeModulesDisplay:UpdateSlotCount()
    self:UpdateFocusBox()
    if self:IsExtended() then
        self.energy_nightmare:SetScale(1, FOCUS_BOX_EXTENDED_SCALE_Y)
        self.energy_nightmare:SetPosition(0, 10)
        self.battery_frame:GetAnimState():Hide("frame")
        self.battery_frame:GetAnimState():Show("frame_extended")

        for k, v in pairs(self.module_bars) do
            local i = k + 1
            v:GetAnimState():Hide("barframe"..i)
            v:GetAnimState():Show("barframe"..i.."_extended")
        end
    else
        self.energy_nightmare:SetScale(1, 1)
        self.energy_nightmare:SetPosition(0, 0)
        self.battery_frame:GetAnimState():Show("frame")
        self.battery_frame:GetAnimState():Hide("frame_extended")

        for k, v in pairs(self.module_bars) do
            local i = k + 1
            v:GetAnimState():Show("barframe"..i)
            v:GetAnimState():Hide("barframe"..i.."_extended")
        end
    end
end

-- Charge Displaying -----------------------------------------------------------

function UpgradeModulesDisplay:UpdateChipCharges(plugging_in)
    for bartype, index in pairs(self.chip_poolindexes) do
        if index > 1 then
            local charge = self._overrideenergywithshadow and self.max_energy or self.energy_level
            local objectpool = self.chip_objectpools[bartype]
            for i = 1, index - 1 do
                local chip = objectpool[i]

                charge = charge - chip._used_modslots
                if charge < 0 and not chip._power_hidden then
                    if not plugging_in then
                        chip:GetAnimState():PlayAnimation("minichip_off")
                        chip:HookCallback("animover", function(chip_ui_inst)
                            chip:GetAnimState():Hide("plug_on")
                            chip:GetAnimState():Hide("glow")
                            chip:GetAnimState():PlayAnimation("minichip_idle")
                            chip:UnhookCallback("animover")
                        end)
                    else
                        chip:GetAnimState():Hide("plug_on")
                        chip:GetAnimState():Hide("glow")
                    end
                    chip._power_hidden = true

                    self:PlayUpgradeModuleSound("WX_rework/tube/HUD_off", true)
                elseif charge >= 0 and chip._power_hidden then
                    -- In case we changed charge before the power off animation finished.
                    chip:UnhookCallback("animover")

                    chip:GetAnimState():Show("plug_on")
                    chip:GetAnimState():Show("glow")
                    if not plugging_in then
                        chip:GetAnimState():PlayAnimation("minichip_on")
                        chip:GetAnimState():PushAnimation("minichip_idle")
                    end
                    chip._power_hidden = false

                    self:PlayUpgradeModuleSound("WX_rework/tube/HUD_on", true)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------

function UpgradeModulesDisplay:UpdateMaxEnergy(new_level, old_level)
    self.max_energy = new_level

    for i = 1, MAX_CIRCUIT_SLOTS do
        local slotn = "slot"..tostring(i)
        if i > new_level then
            self.anim:GetAnimState():Hide(slotn)
            self.energy_blinking:GetAnimState():Hide(slotn)
            self.energy_backing:GetAnimState():Hide(slotn)
        else
            self.anim:GetAnimState():Show(slotn)
            self.energy_blinking:GetAnimState():Show(slotn)
            self.energy_backing:GetAnimState():Show(slotn)
        end
    end

    self:UpdateEnergyLevel(self.energy_level, self.energy_level, true)
    self:UpdateSlotCount()

    -- Pop off extra modules over the new limit
    local first = true
    for k, v in pairs(self.module_bars) do
        local remaining_level = self.max_energy
        for i, chip in ipairs(self.chip_objectpools[k]) do
            while chip ~= nil do
                if chip.chip_pos then
                    remaining_level = remaining_level - chip._used_modslots
                    if remaining_level < 0 then
                        self:PopOneModule(k)
                        chip = self.chip_objectpools[k][i]

                        if first then
                            self:PlayUpgradeModuleSound("WX_rework/tube/HUD_out")
                            first = false
                        end
                    else
                        chip = nil
                    end
                else
                    chip = nil
                end
            end
        end
    end
end

function UpgradeModulesDisplay:UpdateEnergyLevel(new_level, old_level, skipsound)
    self.energy_level = new_level

    for i = 1, self.max_energy do
        local slotn = "slot"..tostring(i)

        if i > new_level then
            self.anim:GetAnimState():Hide(slotn)
        else
            self.anim:GetAnimState():Show(slotn)
        end

        if i == new_level + 1 then
            self.energy_blinking:GetAnimState():Show(slotn)
        else
            self.energy_blinking:GetAnimState():Hide(slotn)
        end
    end

    -- Change which level our yellow "charging" UI is at.
    if self.energy_blinking._flicker_task ~= nil then
        self.energy_blinking._flicker_task:Cancel()
        self.energy_blinking._flicker_task = nil
    end
    if new_level < self.max_energy then
        self.energy_blinking._flicker_alternator = false
        self.energy_blinking._flicker_task = self.inst:DoSimPeriodicTask(
            25*FRAMES,
            function(ui_inst)
                if self.energy_blinking._flicker_alternator then
                    self.energy_blinking:GetAnimState():PlayAnimation("energy2")
                else
                    self.energy_blinking:GetAnimState():PlayAnimation("energy2b")
                end
                self.energy_blinking._flicker_alternator = not self.energy_blinking._flicker_alternator
            end,
            10*FRAMES
        )
    end

    if not skipsound then
        if new_level > old_level then
            self:PlayUpgradeModuleSound("WX_rework/charge/up")
        elseif new_level < old_level then
            self:PlayUpgradeModuleSound("WX_rework/charge/down")
        end
    end

    self:UpdateChipCharges(false)
end

function UpgradeModulesDisplay:GetChipXOffset(chiptypeindex)
    local BASE_X = -92
    for moduletype, moduleindex in pairs(CIRCUIT_BARS) do
        if chiptypeindex == moduleindex then
            return BASE_X + (46 * moduleindex)
        end
    end
end

function UpgradeModulesDisplay:OnModuleAdded(bartype, moduledefinition_index)
    local module_def = GetModuleDefinitionFromNetID(moduledefinition_index)
    if module_def == nil then
        return
    end
    bartype = bartype or module_def.type

    local modname = module_def.name
    local modslots = module_def.slots

    local objectpool = self.chip_objectpools[bartype]
    local new_chip = objectpool[self.chip_poolindexes[bartype]]
    self.chip_poolindexes[bartype] = self.chip_poolindexes[bartype] + 1

    new_chip:GetAnimState():PlayAnimation("minichip_plug")
    new_chip:GetAnimState():PushAnimation("minichip_idle")

    local overridebuild = module_def.overrideminiuibuild or "status_wx"
    new_chip:GetAnimState():OverrideSymbol("movespeed2_chip", overridebuild, modname.."_chip")
    new_chip.cooldown:GetAnimState():OverrideSymbol("movespeed2_chip", overridebuild, modname.."_chip")
    new_chip.modulename = modname
    new_chip.overridebuild = overridebuild

    new_chip._used_modslots = modslots

    local slot_distance_from_bottom = self.chip_slotsinuse[bartype] + (modslots - 1) * 0.5
    local y_pos = (slot_distance_from_bottom * 20) - 51
    new_chip:SetPosition(self:GetChipXOffset(bartype), y_pos)
    new_chip.chip_pos = Vector3(self:GetChipXOffset(bartype), y_pos, 0)
    new_chip.cooldown:SetPosition(0, (modslots - 2) * 11)

    if self.open then
        new_chip:Show()
    else
        new_chip:Hide()
    end

    self.chip_slotsinuse[bartype] = self.chip_slotsinuse[bartype] + modslots
end

function UpgradeModulesDisplay:PopModuleAtIndex(bartype, startindex)
    local objectpool = self.chip_objectpools[bartype]
    local falling_chip = objectpool[startindex]

    self.chip_poolindexes[bartype] = self.chip_poolindexes[bartype] - 1
    self.chip_slotsinuse[bartype] = self.chip_slotsinuse[bartype] - falling_chip._used_modslots
    self:DropChip(falling_chip)

    local slotsinuse = -falling_chip._used_modslots
    for i = 1, #objectpool do
        local lastchip = objectpool[i-1]
        local chip = objectpool[i]
        if i >= startindex + 1 then
            if chip.chip_pos then
                lastchip._used_modslots = chip._used_modslots
                lastchip.modulename = chip.modulename
                lastchip.overridebuild = chip.overridebuild
                lastchip:GetAnimState():PlayAnimation("minichip_idle")
                lastchip:GetAnimState():OverrideSymbol("movespeed2_chip", lastchip.overridebuild, lastchip.modulename.."_chip")

                chip.chip_pos = nil
                chip:CancelMoveTo()
                local slot_distance_from_bottom = slotsinuse + (chip._used_modslots - 1) * 0.5
                local y_pos = (slot_distance_from_bottom * 20) - 51
                lastchip:SetPosition(self:GetChipXOffset(bartype), y_pos)
                lastchip.chip_pos = Vector3(self:GetChipXOffset(bartype), y_pos, 0)
            end
        end
        slotsinuse = slotsinuse + (chip._used_modslots or 0)
    end
end

function UpgradeModulesDisplay:OnModulesDirty(modules_data)
    local first = true
    local function PlayFirstSound(soundpath)
        if first then
            self:PlayUpgradeModuleSound(soundpath)
            first = false
        end
    end

    local module_changed_count = 0
    for bartype, modules in pairs(modules_data) do
        if module_changed_count >= 2 then
            break
        end
        local oldmodules = self._oldmodulesdata ~= nil and self._oldmodulesdata[bartype] or nil
        for i, module_index in ipairs(modules) do
            local oldmodule_index = oldmodules ~= nil and oldmodules[i] or 0
            if module_index ~= oldmodule_index then
                module_changed_count = module_changed_count + 1
                if module_changed_count >= 2 then
                    self._oldmodulesdata = nil
                    self:PopAllModules(true)
                    break
                end
            end
        end
    end

    for bartype, modules in pairs(modules_data) do
        local oldmodules = self._oldmodulesdata ~= nil and self._oldmodulesdata[bartype] or nil
        for i, module_index in ipairs(modules) do
            local oldmodule_index = oldmodules ~= nil and oldmodules[i] or 0

            -- Plugged a circuit
            if module_index ~= 0 and i == self.chip_poolindexes[bartype] then
                self:OnModuleAdded(bartype, module_index)
                PlayFirstSound("WX_rework/tube/HUD_in")
            -- Popped the top module
            elseif module_index == 0 and i == (self.chip_poolindexes[bartype] - 1) then
                self:PopOneModule(bartype)
                PlayFirstSound("WX_rework/tube/HUD_out")
            -- Unplugged a circuit in the middle
            elseif module_index ~= 0 and oldmodule_index ~= 0 and module_index ~= oldmodule_index then
                self:PopModuleAtIndex(bartype, i)
                PlayFirstSound("WX_rework/tube/HUD_out")
                break
            end
        end
    end

    self._oldmodulesdata = modules_data
    self:UpdateChipCharges(true)
end

function UpgradeModulesDisplay:DropChip(falling_chip)
    falling_chip:HookCallback("animover", function(ui_inst)
        falling_chip:GetAnimState():Hide("plug_on")
        falling_chip:GetAnimState():Hide("glow")
        falling_chip._power_hidden = true
        falling_chip:Hide()
        falling_chip:UnhookCallback("animover")
    end)

    falling_chip.chip_pos = nil
    falling_chip:CancelMoveTo()
    falling_chip:GetAnimState():PlayAnimation("minichip_fall")
end

function UpgradeModulesDisplay:PopOneModule(bartype)
    local objectpool = self.chip_objectpools[bartype]
    local falling_chip = objectpool[self.chip_poolindexes[bartype] - 1]

    self.chip_poolindexes[bartype] = self.chip_poolindexes[bartype] - 1
    self.chip_slotsinuse[bartype] = self.chip_slotsinuse[bartype] - falling_chip._used_modslots
    self:DropChip(falling_chip)
end

function UpgradeModulesDisplay:PopAllModules(skip_sound)
    local play_sound = false

    for bartype, pool in pairs(self.chip_objectpools) do
        if self.chip_poolindexes[bartype] > 1 then
            play_sound = true

            while self.chip_poolindexes[bartype] > 1 do
                self.chip_poolindexes[bartype] = self.chip_poolindexes[bartype] - 1
                local chip = pool[self.chip_poolindexes[bartype]]
                self:DropChip(chip)
                chip._power_hidden = true
            end
        end
    end

    if play_sound and not skip_sound then
        self:PlayUpgradeModuleSound("WX_rework/tube/HUD_out")
    end

    for bartype, slots in pairs(self.chip_slotsinuse) do
        self.chip_slotsinuse[bartype] = 0
    end
end

local function GetBarOpenTimings(bartype)
    return bartype == CIRCUIT_BARS.ALPHA and .37
        or bartype == CIRCUIT_BARS.BETA and .36
        or bartype == CIRCUIT_BARS.GAMMA and .32
end

local function GetBarCloseTimings(bartype)
    return bartype == CIRCUIT_BARS.ALPHA and 5 * FRAMES
        or bartype == CIRCUIT_BARS.BETA and 3 * FRAMES
        or bartype == CIRCUIT_BARS.GAMMA and 2 * FRAMES
end

function UpgradeModulesDisplay:Open()
    if not self.open then
        self.open = true
        self:UpdateFocusBox()

        for k, v in pairs(self.module_bars) do
            v:GetAnimState():PlayAnimation("frame_open")
            for _, chip in ipairs(self.chip_objectpools[k]) do
                if chip.chip_pos then
                    local i = k + 1
                    local pos = chip.chip_pos
                    local hidden_pos = Vector3((i * 20) - 20, pos.y, 0)
                    chip:CancelMoveTo()
                    chip:MoveTo(hidden_pos, pos, GetBarOpenTimings(k), function()  end)
                    chip:Show()
                    chip:GetAnimState():PlayAnimation("minichip_barframe"..i.."_open")
                    chip:GetAnimState():PushAnimation("minichip_idle")
                end
            end
        end

        TheFrontEnd:GetSound():PlaySound("WX_rework/module_side/open", nil, UpgradeModuleMouseoverSoundReduction())
    end
end

function UpgradeModulesDisplay:Close()
    if self.open then
        self.open = false
        self:UpdateFocusBox()

        for k, v in pairs(self.module_bars) do
            v:GetAnimState():PlayAnimation("frame_close")
            for _, chip in ipairs(self.chip_objectpools[k]) do
                if chip.chip_pos then
                    local i = k + 1
                    local pos = chip.chip_pos
                    local stretch_pos = Vector3(chip.chip_pos.x - 5, chip.chip_pos.y, 0)
                    chip:MoveTo(pos, stretch_pos, 6 * FRAMES, function()
                        local hidden_pos = Vector3(40, pos.y, 0)
                        chip:MoveTo(pos, hidden_pos, GetBarCloseTimings(k), function() chip:Hide() end)
                        chip:GetAnimState():PlayAnimation("minichip_barframe"..i.."_close")
                    end)
                end
            end
        end

        TheFrontEnd:GetSound():PlaySound("WX_rework/module_side/close", nil, UpgradeModuleMouseoverSoundReduction())
    end
end

function UpgradeModulesDisplay:UpdateFocusBox()
    local extra_y_scale = self:IsExtended() and FOCUS_BOX_EXTENDED_SCALE_Y or 1
    local sx, sy
    if self.open then
        sx, sy = FOCUS_BOX_OPEN_SCALE_X, FOCUS_BOX_OPEN_SCALE_Y
    else
        sx, sy = FOCUS_BOX_CLOSED_SCALE_X, FOCUS_BOX_CLOSED_SCALE_Y
    end
    sy = sy * extra_y_scale
    self.focus_box:SetScale(sx, sy)
end

-- A lot of the sounds here won't actually ever play in gameplay.
-- But in case we can somehow swap circuits outside of the chassis view and this display is open, then it's supported.
function UpgradeModulesDisplay:PlayUpgradeModuleSound(soundpath, onlyifopen)
    if self.is_upgrade_modules_display_hidden then
        return
    end

    if self.owner and self.owner.HUD.upgrademodulewidget ~= nil then
        return
    end

    if onlyifopen and not self.open then
        return
    end

    TheFrontEnd:GetSound():PlaySound(soundpath)
end

local HIDDEN_OFFSET = Vector3(100, 0, 0)
function UpgradeModulesDisplay:HideUpgradeModulesDisplay()
    self.is_upgrade_modules_display_hidden = true
    self:Close()
    self.original_pos = self:GetPosition()
    self:CancelMoveTo()
    self:MoveTo(self.original_pos, self.original_pos + HIDDEN_OFFSET, 0.3, function() self:Hide() end)
end

function UpgradeModulesDisplay:ShowUpgradeModulesDisplay()
    self.is_upgrade_modules_display_hidden = nil
    self:Show()
    self:CancelMoveTo()
    self:MoveTo(self.original_pos + HIDDEN_OFFSET, self.original_pos, 0.3)
end

local ENERGY_NIGHTMARE_TOP_MAX_Y = 55
local ENERGY_NIGHTMARE_TOP_MIN_Y = -60
function UpgradeModulesDisplay:OnUpdate()
    if self.owner.components.wx78_abilitycooldowns ~= nil then
        if self._overrideenergywithshadow then
            local ability_cooldown_percent = self.owner.components.wx78_abilitycooldowns:GetAbilityCooldownPercent("shadow_energy")
            local perc = 1 - (ability_cooldown_percent or 0)
            self.energy_nightmare:GetAnimState():SetPercent("energy_nightmare", perc)
            self.energy_nightmare_top:SetPosition(0, Lerp(ENERGY_NIGHTMARE_TOP_MAX_Y, ENERGY_NIGHTMARE_TOP_MIN_Y, perc))
        end

        if self.open then
            local abilities = {}
            for abilityhash, cd in pairs(self.owner.components.wx78_abilitycooldowns.cooldowns) do
                abilities[abilityhash] = true
            end

            for k, v in pairs(self.module_bars) do
                for _, chip in ipairs(self.chip_objectpools[k]) do
                    if chip.chip_pos then
                        local abilityname = hash(chip.modulename)
                        if abilities[abilityname] then
                            local ability_cooldown_percent = self.owner.components.wx78_abilitycooldowns:GetAbilityCooldownPercent(abilityname)
                            chip.cooldown:GetAnimState():SetPercent("minichip_cooldown", ability_cooldown_percent or 0)
                        end
                    end
                end
            end
        end
    end
end

return UpgradeModulesDisplay