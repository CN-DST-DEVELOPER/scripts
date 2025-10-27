require("constants")
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"

local function DoInspected(invitem, tried)
    if ThePlayer then
        TheScrapbookPartitions:SetInspectedByCharacter(invitem, ThePlayer.prefab)
    elseif not tried then
        invitem:DoTaskInTime(0, DoInspected, true) -- Delay a frame in case of load order desync only try once and then giveup.
    end
end

local function SetImageFromItem(im, item)
	if item.layeredinvimagefn then
		local layers = item.layeredinvimagefn(item)
		if layers and #layers > 0 then
			local row = layers[1]
			im:SetTexture(row.atlas or GetInventoryItemAtlas(row.image), row.image)

            local j = 1

			if #layers > 1 then
				im.layers = im.layers or {}

				local usecc = GetGameModeProperty("icons_use_cc")
				for i = 2, #layers do
					row = layers[i]
					local w = im.layers[j]
					if w then
						w:SetTexture(row.atlas or GetInventoryItemAtlas(row.image), row.image)
					else
						im.layers[j] = im:AddChild(Image(row.atlas or GetInventoryItemAtlas(row.image), row.image))
						if usecc then
							im.layers[j]:SetEffect("shaders/ui_cc.ksh")
						end
					end
					if row.offset then
						im.layers[j]:SetPosition(row.offset)
					end
					j = j + 1
				end
            end

            if im.layers ~= nil then
				for i = j, #im.layers do
					im.layers[i]:Kill()
					im.layers[i] = nil
				end
			end

			return im
		end
	end
	local inventoryitem = item.replica.inventoryitem
	if inventoryitem then
		if im.layers then
			for i, v in ipairs(im.layers) do
				v:Kill()
			end
			im.layers = nil
		end
		im:SetTexture(inventoryitem:GetAtlas(), inventoryitem:GetImage())
	end
	return im
end

local ItemTile = Class(Widget, function(self, invitem)
    Widget._ctor(self, "ItemTile")
    self.item = invitem
    self.ismastersim = TheWorld.ismastersim

    --These flags are used by the client to control animation behaviour while
    --stacksize is being tampered with locally to preview inventory actions so
    --that when the next server sync is received, you won't see a double pop
    --on the item tile scaling
    self.isactivetile = false
    self.ispreviewing = false
    self.movinganim = nil
    self.ignore_stacksize_anim = nil
    self.onquantitychangedfn = nil
	self.updatingflags = {}

    -- NOT SURE WAHT YOU WANT HERE
    if invitem.replica.inventoryitem == nil then
        print("NO INVENTORY ITEM COMPONENT"..tostring(invitem.prefab), invitem)
        return
    end

    DoInspected(invitem)

	local show_spoiled_meter = self:HasSpoilage() or self.item:HasTag("show_broken_ui")

	if show_spoiled_meter or self.item:HasTag("show_spoiled") then
		self.bg = self:AddChild(Image(HUD_ATLAS, "inv_slot_spoiled.tex"))
        self.bg:SetClickable(false)
    end

    self.basescale = 1

	if show_spoiled_meter then
        self.spoilage = self:AddChild(UIAnim())
        self.spoilage:GetAnimState():SetBank("spoiled_meter")
        self.spoilage:GetAnimState():SetBuild("spoiled_meter")
        self.spoilage:GetAnimState():AnimateWhilePaused(false)
        self.spoilage:SetClickable(false)
		self.spoilage.inst:ListenForEvent("hide_spoilage",
			function(invitem)
				if self.bg then
					self.bg:Kill()
					self.bg = nil
				end
				if self.spoilage then
					self.spoilage:Kill()
					self.spoilage = nil
				end
			end, invitem)
    end

    self.wetness = self:AddChild(UIAnim())
    self.wetness:GetAnimState():SetBank("wet_meter")
    self.wetness:GetAnimState():SetBuild("wet_meter")
    self.wetness:GetAnimState():PlayAnimation("idle")
    self.wetness:GetAnimState():AnimateWhilePaused(false)
    self.wetness:Hide()
    self.wetness:SetClickable(false)

    if self.item:HasTag("rechargeable") then
        self.rechargepct = 1
        self.rechargetime = math.huge
        self.rechargeframe = self:AddChild(UIAnim())
        self.rechargeframe:GetAnimState():SetBank("recharge_meter")
        self.rechargeframe:GetAnimState():SetBuild("recharge_meter")
        self.rechargeframe:GetAnimState():PlayAnimation("frame")
        self.rechargeframe:GetAnimState():AnimateWhilePaused(false)
        if self.item:HasTag("rechargeable_bonus") then
            self.rechargeframe:GetAnimState():SetMultColour(0, 0.2, 0, 0.7) -- 'Bonus while' with DARK GREEN colour.
        else
            self.rechargeframe:GetAnimState():SetMultColour(0, 0, 0.3, 0.54) -- 'Cooldown until' with DARK BLUE colour.
        end
    end

    if self.item.inv_image_bg ~= nil then
        self.imagebg = self:AddChild(Image(self.item.inv_image_bg.atlas, self.item.inv_image_bg.image, "default.tex"))
        self.imagebg:SetClickable(false)
        if GetGameModeProperty("icons_use_cc") then
            self.imagebg:SetEffect("shaders/ui_cc.ksh")
        end
    end
	self.image = self:AddChild(SetImageFromItem(Image(), invitem))
    if GetGameModeProperty("icons_use_cc") then
        self.image:SetEffect("shaders/ui_cc.ksh")
    end

    --self.image:SetClickable(false)

    -- NOTES(JBK): Apply invitem.itemtile_tagname before other things they are treated to be part of the item instead of an overlay.
    if invitem.itemtile_lightning then
        self.image.itemtile_lightning = self.image:AddChild(Image(GetInventoryItemAtlas("itemtile_lightning.tex"), "itemtile_lightning.tex", "default.tex"))
    end

	self:ToggleShadowFX()
	self:HandleAcidSizzlingFX()
    self:HandleBuffFX(invitem)

    if self.rechargeframe ~= nil then
        self.recharge = self:AddChild(UIAnim())
        self.recharge:GetAnimState():SetBank("recharge_meter")
        self.recharge:GetAnimState():SetBuild("recharge_meter")
        if self.item:HasTag("rechargeable_bonus") then
            self.recharge:GetAnimState():SetMultColour(0, 0.3, 0, 0.8) -- 'Bonus while' with GREEN colour.
        else
            self.recharge:GetAnimState():SetMultColour(0, 0, 0.4, 0.64) -- 'Cooldown until' with BLUE colour.
        end
        self.recharge:GetAnimState():AnimateWhilePaused(false)
        self.recharge:SetClickable(false)
    end

    self.inst:ListenForEvent("imagechange",
        function(invitem)
            if self.imagebg ~= nil then
                if self.item.inv_image_bg ~= nil then
                    self.imagebg:SetTexture(self.item.inv_image_bg.atlas, self.item.inv_image_bg.image)
                    self.imagebg:Show()
                else
                    self.imagebg:Hide()
                end
            end
			SetImageFromItem(self.image, invitem)
        end, invitem)
    if invitem:HasClientSideInventoryImageOverrides() then
        self.inst:ListenForEvent("clientsideinventoryflagschanged",
            function(player)
				if invitem then
					SetImageFromItem(self.image, invitem)
                end
            end, ThePlayer)
    end
	self.inst:ListenForEvent("inventoryitem_updatetooltip",
		function(invitem)
			if self.focus and not TheInput:ControllerAttached() then
				self:UpdateTooltip()
			end
		end, invitem)
    self.inst:ListenForEvent("serverpauseddirty",
        function(invitem)
            if self.focus and not TheInput:ControllerAttached() then
                self.inst:DoTaskInTime(0, function() self:UpdateTooltip() end)
            end
        end,
    TheWorld)
    self.inst:ListenForEvent("refreshcrafting",
        function(invitem)
            if self.focus and not TheInput:ControllerAttached() then
                self:UpdateTooltip()
            end
        end,
    ThePlayer)
        self.inst:ListenForEvent("inventoryitem_updatespecifictooltip",
            function(player, data)
                if self.focus and not TheInput:ControllerAttached() and invitem.prefab == data.prefab then
                    self:UpdateTooltip()
                end
            end, ThePlayer)
    self.inst:ListenForEvent("item_buff_changed",
        function(player)
            self:HandleBuffFX(invitem, true)
        end,
    ThePlayer)
    self.inst:ListenForEvent("stacksizechange",
        function(invitem, data)
            if invitem.replica.stackable ~= nil then
                if self.ignore_stacksize_anim then
                    if self.movinganim ~= nil then
                        self.movinganim.isolddata = true
                    end
                    self:SetQuantity(data.stacksize)
                elseif data.src_pos ~= nil then
                    if self.movinganim ~= nil and not (self.movinganim.inst.components.uianim ~= nil and (self.movinganim.inst.components.uianim.pos_t or 0) > 0) then
                        --cancel previous anim if it hasn't updated even once yet
                        self.movinganim:Kill()
                    end
                    local dest_pos = self:GetWorldPosition()
					local im = SetImageFromItem(Image(), invitem)
                    if GetGameModeProperty("icons_use_cc") then
                        im:SetEffect("shaders/ui_cc.ksh")
                    end
                    im:MoveTo(Vector3(TheSim:GetScreenPos(data.src_pos:Get())), dest_pos, .3, function()
                        --V2C: tile could be killed already if the user picked it
                        --     up with mouse cursor during the move to animation.
                        if self.inst:IsValid() then
                            local iscurrent = not (self.movinganim ~= nil and self.movinganim.isolddata)
                            if self.movinganim == im then
                                self.movinganim = nil
                            end
                            if iscurrent then
                                self:SetQuantity(data.stacksize)
                                self:ScaleTo(self.basescale * 2, self.basescale, .25)
                            end
                        end
                        im:Kill()
                    end)
                    self.movinganim = im
                elseif not self.ispreviewing then
                    if self.movinganim ~= nil then
                        self.movinganim.isolddata = true
                    end
                    self:SetQuantity(data.stacksize)
                    self:ScaleTo(self.basescale * 2, self.basescale, .25)
                end
            end
        end, invitem)

    self.inst:ListenForEvent("percentusedchange",
        function(invitem, data)
            self:SetPercent(data.percent)
        end, invitem)

    self.inst:ListenForEvent("perishchange",
        function(invitem, data)
            if self:HasSpoilage() then
                self:SetPerishPercent(data.percent)
			elseif invitem:HasAnyTag("fresh", "stale", "spoiled") then
                self:SetPercent(data.percent)
            end
        end, invitem)

    if self.rechargeframe ~= nil then
        self.inst:ListenForEvent("rechargechange",
            function(invitem, data)
                self:SetChargePercent(data.percent)
            end, invitem)

        self.inst:ListenForEvent("rechargetimechange",
            function(invitem, data)
                self:SetChargeTime(data.t)
            end, invitem)
    end

    self.inst:ListenForEvent("wetnesschange",
        function(invitem, wet)
            if not self.isactivetile then
                if wet then
                    self.wetness:Show()
                else
                    self.wetness:Hide()
                end
            end
        end, invitem)
        
    self.inst:ListenForEvent("acidsizzlingchange",
        function(invitem, isacidsizzling)
            if not self.isactivetile then
                self:HandleAcidSizzlingFX(isacidsizzling)
            end
        end,
    invitem)

    if not self.ismastersim then
        self.inst:ListenForEvent("stacksizepreview",
            function(invitem, data)
                if data.activecontainer ~= nil and
                    self.parent ~= nil and
                    self.parent.container ~= nil and
                    self.parent.container.inst == data.activecontainer and
                    data.activestacksize ~= nil then
                    self:SetQuantity(data.activestacksize)
                    if data.animateactivestacksize then
                        self:ScaleTo(self.basescale * 2, self.basescale, .25)
                    end
                    self.ispreviewing = true
                elseif self.isactivetile and
                    data.activecontainer == nil and
                    data.activestacksize ~= nil then
                    self:SetQuantity(data.activestacksize)
                    if data.animateactivestacksize then
                        self:ScaleTo(self.basescale * 2, self.basescale, .25)
                    end
                    self.ispreviewing = true
                elseif data.stacksize ~= nil then
                    self:SetQuantity(data.stacksize)
                    if data.animatestacksize then
                        self:ScaleTo(self.basescale * 2, self.basescale, .25)
                    end
                    self.ispreviewing = true
                end
            end, invitem)
    end

    self:Refresh()
end)

--static function so we can share it to other files without making it global
ItemTile.sSetImageFromItem = SetImageFromItem

function ItemTile:Refresh()
    self.ispreviewing = false
    self.ignore_stacksize_anim = nil

    if self.movinganim == nil and self.item.replica.stackable ~= nil then
        self:SetQuantity(self.item.replica.stackable:StackSize())
    end

    if self.ismastersim then
        if self.item.components.armor ~= nil then
            self:SetPercent(self.item.components.armor:GetPercent())
        elseif self.item.components.perishable ~= nil then
            if self:HasSpoilage() then
                self:SetPerishPercent(self.item.components.perishable:GetPercent())
            else
                self:SetPercent(self.item.components.perishable:GetPercent())
            end
        elseif self.item.components.finiteuses ~= nil then
            self:SetPercent(self.item.components.finiteuses:GetPercent())
        elseif self.item.components.fueled ~= nil then
            self:SetPercent(self.item.components.fueled:GetPercent())
        end

        if self.rechargeframe ~= nil and self.item.components.rechargeable ~= nil then
            self:SetChargePercent(self.item.components.rechargeable:GetPercent())
            self:SetChargeTime(self.item.components.rechargeable:GetRechargeTime())
        end
    elseif self.item.replica.inventoryitem ~= nil then
        self.item.replica.inventoryitem:DeserializeUsage()
    end

	if not self.isactivetile and self.wetness then
        if self.item:GetIsWet() then
            self.wetness:Show()
        else
            self.wetness:Hide()
        end
        self:HandleAcidSizzlingFX()
    end
end

function ItemTile:SetBaseScale(sc)
    self.basescale = sc
    self:SetScale(sc)
end

function ItemTile:OnControl(control, down)
    self:UpdateTooltip()
    return false
end

function ItemTile:UpdateTooltip()
    local str = self:GetDescriptionString()
    self:SetTooltip(str)
    if self.item:GetIsWet() then
        self:SetTooltipColour(unpack(WET_TEXT_COLOUR))
    else
        self:SetTooltipColour(unpack(NORMAL_TEXT_COLOUR))
    end
end

function ItemTile:GetDescriptionString()
    local str = ""
    if self.item ~= nil and self.item:IsValid() and self.item.replica.inventoryitem ~= nil then
        local adjective = self.item:GetAdjective()
        if adjective ~= nil then
            str = adjective.." "
        end
        str = str..self.item:GetDisplayName()

        local player = ThePlayer
        local actionpicker = player.components.playeractionpicker
        local active_item = player.replica.inventory:GetActiveItem()
        if not self.readonlycontainer then
            if active_item == nil then
                if not (self.item.replica.equippable ~= nil and self.item.replica.equippable:IsEquipped()) then
                    --self.namedisp:SetHAlign(ANCHOR_LEFT)
                    if TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then
                        str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY)..": "..STRINGS.INSPECTMOD
                    elseif TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
                        local showhint = false
                        local containers = player.replica.inventory:GetOpenContainers()
                        if containers then
                            local canonlygoinpocketorpocketcontainers = self.item.replica.inventoryitem:CanOnlyGoInPocketOrPocketContainers()
                            local cangoinpocket = not self.item.replica.inventoryitem:CanOnlyGoInPocket()
                            for container, _ in pairs(containers) do
                                if container.replica.container == nil or not container.replica.container:IsReadOnlyContainer() then
                                    if canonlygoinpocketorpocketcontainers then
                                        if container.replica.inventoryitem and container.replica.inventoryitem:CanOnlyGoInPocket() then
                                            showhint = true
                                            break
                                        end
                                    elseif cangoinpocket then
                                        showhint = true
                                        break
                                    end
                                end
                            end
                        end
                        if showhint then
                            str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY)..": "..((TheInput:IsControlPressed(CONTROL_FORCE_STACK) and self.item.replica.stackable ~= nil) and (STRINGS.STACKMOD.." "..STRINGS.TRADEMOD) or STRINGS.TRADEMOD)
                        end
                    elseif TheInput:IsControlPressed(CONTROL_FORCE_STACK) and self.item.replica.stackable ~= nil then
                        str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY)..": "..STRINGS.STACKMOD
                    end
                end

                local actions = actionpicker and actionpicker:GetInventoryActions(self.item) or nil
                if actions and actions[1] ~= nil then
                    str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY)..": "..actions[1]:GetActionString()
                end
            elseif active_item:IsValid() then
                if not (self.item.replica.equippable ~= nil and self.item.replica.equippable:IsEquipped()) then
                    if active_item.replica.stackable ~= nil and active_item.prefab == self.item.prefab and self.item:StackableSkinHack(active_item) then
                        str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY)..": "..STRINGS.UI.HUD.PUT
                    else
                        str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY)..": "..STRINGS.UI.HUD.SWAP
                    end
                end

                --no RMB hint for quickdrop while holding an item, as that might be confusing since players would think its the item they are holding.
                --the mod never had the hint, and people discovered it just fine, so this should also be fine -Zachary

                local actions = actionpicker and actionpicker:GetUseItemActions(self.item, active_item, true) or nil
                if actions and actions[1] ~= nil then
                    str = str.."\n"..TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY)..": "..actions[1]:GetActionString()
                end
            end
        end
    end
    return str
end

function ItemTile:OnGainFocus()
    self:UpdateTooltip()
end

--Callback for overriding quantity display handler (used by construction site containers)
--return true to skip default handler code
function ItemTile:SetOnQuantityChangedFn(fn)
    self.onquantitychangedfn = fn
end

function ItemTile:SetQuantity(quantity)
    if self.onquantitychangedfn ~= nil and self:onquantitychangedfn(quantity) then
        if self.quantity ~= nil then
            self.quantity = self.quantity:Kill()
        end
        return
    elseif not self.quantity then
        self.quantity = self:AddChild(Text(NUMBERFONT, 42))
    end
	if quantity > 999 then
		self.quantity:SetSize(36)
		self.quantity:SetPosition(3.5, 16, 0)
		self.quantity:SetString("999+")
	else
		self.quantity:SetSize(42)
		self.quantity:SetPosition(2, 16, 0)
		self.quantity:SetString(tostring(quantity))
	end
end

function ItemTile:SetPerishPercent(percent)
	if self.spoilage then
		--percent is approximated over the network, so check tags to
		--determine the correct color at the 50% and 20% boundaries.
		if percent < 0.51 and percent > 0.49 and self.item:HasTag("fresh") then
			self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_green")
			self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_green")
		elseif percent < 0.21 and percent > 0.19 and self.item:HasTag("stale") then
			self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_yellow")
			self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_yellow")
		else
			self.spoilage:GetAnimState():ClearAllOverrideSymbols()
		end
		--don't use 100% frame, since it should be replace by something like "spoiled_food" then
		self.spoilage:GetAnimState():SetPercent("anim", math.clamp(1 - percent, 0, 0.99))
	end
end

function ItemTile:SetPercent(percent)
	if not self.item:HasTag("hide_percentage") then
		if not self.percent then
			self.percent = self:AddChild(Text(NUMBERFONT, 42))
			if JapaneseOnPS4() then
				self.percent:SetHorizontalSqueeze(0.7)
			end
			self.percent:SetPosition(5,-32+15,0)
		end
		local val_to_show = percent*100
		if val_to_show > 0 and val_to_show < 1 then
			val_to_show = 1
		end
		self.percent:SetString(string.format("%2.0f%%", val_to_show))
		if not self.dragging and self.item:HasTag("show_broken_ui") then
			if percent > 0 then
				if self.bg then
					self.bg:Hide()
				end
				if self.spoilage then
					self.spoilage:Hide()
				end
			else
				if self.bg then
					self.bg:Show()
				end
				self:SetPerishPercent(0)
			end
		end
    end
end

function ItemTile:SetChargePercent(percent)
	local prev_precent = self.rechargepct
    self.rechargepct = percent
	if self.recharge.shown then
		if percent < 1 then
            if self.recharge.ResetColour ~= nil then
                self.recharge.ResetColour()
            end
			self.recharge:GetAnimState():SetPercent("recharge", percent)
			if not self.rechargeframe.shown then
				self.rechargeframe:Show()
			end
			if percent >= 0.9999 then
				self:StopUpdatingCharge()
			elseif self.rechargetime < math.huge then
				self:StartUpdatingCharge()
			end
		else
			if prev_precent < 1 and not self.recharge:GetAnimState():IsCurrentAnimation("frame_pst") then
				self.recharge:GetAnimState():PlayAnimation("frame_pst")
                self.recharge:GetAnimState():SetMultColour(1, 1, 1, 1)
                local isbonus = self.item:HasTag("rechargeable_bonus")
                self.recharge.ResetColour = function()
                    if isbonus then
                        self.recharge:GetAnimState():SetMultColour(0, 0.3, 0, 0.8) -- 'Bonus while' with GREEN colour.
                    else
                        self.recharge:GetAnimState():SetMultColour(0, 0, 0.4, 0.64) -- 'Cooldown until' with BLUE colour.
                    end
                    self.recharge.inst:RemoveEventCallback("animover", self.recharge.ResetColour)
                    self.recharge.ResetColour = nil
                end
                
                self.recharge.inst:ListenForEvent("animover", self.recharge.ResetColour)
			end
			if self.rechargeframe.shown then
				self.rechargeframe:Hide()
			end
			self:StopUpdatingCharge()
		end
	end
end

function ItemTile:SetChargeTime(t)
    self.rechargetime = t
    if self.rechargetime >= math.huge then
		self:StopUpdatingCharge()
    elseif self.rechargepct < .9999 then
		self:StartUpdatingCharge()
    end
end

--[[
function ItemTile:CancelDrag()
    self:StopFollowMouse()

	if self.bg and self.item:HasTag("show_spoiled") or (self.item.components.edible and self.item.components.perishable) then
        self.bg:Show( )
    end

	if self.spoilage and self.item.components.perishable and self.item.components.edible then
        self.spoilage:Show()
    end

    self.image:SetClickable(true)
end
--]]

function ItemTile:StartDrag()
	self.dragging = true
    --self:SetScale(1,1,1)
    if self.item.replica.inventoryitem ~= nil then -- HACK HACK: items without an inventory component won't have any of these
        if self.spoilage ~= nil then
            self.spoilage:Hide()
        end
        self.wetness:Hide()
        self:HandleAcidSizzlingFX(false)
        if self.bg ~= nil then
            self.bg:Hide()
        end
        if self.recharge ~= nil then
            self.recharge:Hide()
			self.rechargeframe:Hide()
			self:StopUpdating()
		end
        self.image:SetClickable(false)
    end
end

function ItemTile:HasSpoilage()
    if self.hasspoilage ~= nil then
        return self.hasspoilage
    elseif not (self.item:HasTag("fresh") or self.item:HasTag("stale") or self.item:HasTag("spoiled")) then
        self.hasspoilage = false
    elseif self.item:HasTag("show_spoilage") then
        self.hasspoilage = true
    else
        for k, v in pairs(FOODTYPE) do
            if self.item:HasTag("edible_"..v) then
                self.hasspoilage = true
                return true
            end
        end
        self.hasspoilage = false
    end
    return self.hasspoilage
end

local function _StartUpdating(self, flag)
	if next(self.updatingflags) == nil then
		self:StartUpdating()
	end
	self.updatingflags[flag] = true
end

local function _StopUpdating(self, flag)
	self.updatingflags[flag] = nil
	if next(self.updatingflags) == nil then
		self:StopUpdating()
	end
end

function ItemTile:StartUpdatingCharge()
	_StartUpdating(self, "charge")
end

function ItemTile:StopUpdatingCharge()
	_StopUpdating(self, "charge")
end

function ItemTile:StartUpdatingShadowFuel()
	self.updateshadowdelay = 0
	_StartUpdating(self, "shadow")
end

function ItemTile:StopUpdatingShadowFuel()
	_StopUpdating(self, "shadow")
	self.updateshadowdelay = nil
end

function ItemTile:OnUpdate(dt)
    if TheNet:IsServerPaused() then return end
	if self.updatingflags.charge then
		self:SetChargePercent(self.rechargetime > 0 and self.rechargepct + dt / self.rechargetime or .9999)
	end
	if self.updatingflags.shadow then
		self.updateshadowdelay = self.updateshadowdelay + dt
		if self.updateshadowdelay > .2 then
			self.updateshadowdelay = 0
			self:CheckShadowFXFuel()
		end
	end
end

function ItemTile:CheckShadowFXFuel()
	if self.item:HasTag("fueldepleted") then
		self.shadowfx:Hide()
	else
		self.shadowfx:Show()
	end
end

function ItemTile:ToggleShadowFX()
	if self.showequipshadowfx or self.item:HasTag("magiciantool") then
		if self.shadowfx == nil then
			self.shadowfx = self.image:AddChild(UIAnim())
			self.shadowfx:GetAnimState():SetBank("inventory_fx_shadow")
			self.shadowfx:GetAnimState():SetBuild("inventory_fx_shadow")
			self.shadowfx:GetAnimState():PlayAnimation("idle", true)
			self.shadowfx:GetAnimState():SetTime(math.random() * self.shadowfx:GetAnimState():GetCurrentAnimationTime())
			self.shadowfx:SetScale(.25)
			self.shadowfx:GetAnimState():AnimateWhilePaused(false)
			self.shadowfx:SetClickable(false)
		end
		if self.item:HasTag("NIGHTMARE_fueled") then
			self:CheckShadowFXFuel()
			self:StartUpdatingShadowFuel()
		else
			self:StopUpdatingShadowFuel()
		end
	elseif self.shadowfx ~= nil then
		self.shadowfx:Kill()
		self.shadowfx = nil
		self:StopUpdatingShadowFuel()
	end
end

function ItemTile:SetIsEquip(isequip)
	local shadowfx = isequip and ThePlayer:HasTag("shadowmagic") and self.item:HasTag("shadowlevel")
	if not self.showequipshadowfx == shadowfx then
		self.showequipshadowfx = shadowfx or nil
		self:ToggleShadowFX()
	end
end

function ItemTile:HandleAcidSizzlingFX(isacidsizzling)
    if isacidsizzling == nil then
        isacidsizzling = self.item:IsAcidSizzling()
    end
    if isacidsizzling then
        if self.acidsizzling == nil then
            self.acidsizzling = self.image:AddChild(UIAnim())
            self.acidsizzling:GetAnimState():SetBank("inventory_fx_acidsizzle")
            self.acidsizzling:GetAnimState():SetBuild("inventory_fx_acidsizzle")
            self.acidsizzling:GetAnimState():PlayAnimation("idle", true)
            self.acidsizzling:GetAnimState():SetMultColour(.65, .62, .17, 0.8)
            self.acidsizzling:GetAnimState():SetTime(math.random())
            self.acidsizzling:SetScale(.25)
            self.acidsizzling:GetAnimState():AnimateWhilePaused(false)
            self.acidsizzling:SetClickable(false)
        end
    else
        if self.acidsizzling ~= nil then
            self.acidsizzling:Kill()
            self.acidsizzling = nil
        end
    end
end

function ItemTile:HandleBuffFX(invitem, fromchanged)
    local player_classified = ThePlayer and ThePlayer.player_classified or nil
    if not player_classified then
        return
    end

    if invitem.prefab == "panflute" then
        if player_classified.wortox_panflute_buff:value() then
            if self.freecastpanflute == nil then
                self.freecastpanflute = self.image:AddChild(UIAnim())
                local ref = self.freecastpanflute
                ref:GetAnimState():SetBank("inventory_fx_buff_panflute")
                ref:GetAnimState():SetBuild("inventory_fx_buff_panflute")
                
                local function RandomizeLoop()
                    ref:GetAnimState():PlayAnimation("notes_loop", true)
                    ref:GetAnimState():SetTime(math.random())
                end
                if fromchanged then
                    ref:GetAnimState():PlayAnimation("notes_pre")
                    local function DoRandomizeLoop()
                        RandomizeLoop()
                        ref.inst:RemoveEventCallback("animover", DoRandomizeLoop)
                    end
                    ref.inst:ListenForEvent("animover", DoRandomizeLoop)
                else
                    RandomizeLoop()
                end
                ref:GetAnimState():SetMultColour(1, 1, 1, 0.9)
                ref:GetAnimState():AnimateWhilePaused(false)
                ref:SetClickable(false)
            end
        else
            if self.freecastpanflute ~= nil then
                local ref = self.freecastpanflute
                self.freecastpanflute = nil
                ref:GetAnimState():PlayAnimation("notes_pst")
                ref.inst:ListenForEvent("animover", function() ref:Kill() end)
            end
        end
    end
end

return ItemTile
