
if not IsConsole() then
	require "splitscreenutils_pc"
end

local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Inv = require "widgets/inventorybar"
local Widget = require "widgets/widget"
local CraftTabs = require "widgets/crafttabs"
local CraftingMenu = require "widgets/redux/craftingmenu_hud"
local HoverText = require "widgets/hoverer"
local MapControls = require "widgets/mapcontrols"
local ContainerWidget = require("widgets/containerwidget")
local DemoTimer = require "widgets/demotimer"
local SavingIndicator = require "widgets/savingindicator"
local UIClock = require "widgets/uiclock"
local MapScreen = require "screens/mapscreen"
local FollowText = require "widgets/followtext"
local StatusDisplays = require "widgets/statusdisplays"
local SecondaryStatusDisplays = require "widgets/secondarystatusdisplays"
local Lavaarena_StatusDisplays = require "widgets/statusdisplays_lavaarena"
local Quagmire_StatusDisplays = require "widgets/statusdisplays_quagmire"
local Quagmire_StatusCravingDisplay = require "widgets/statusdisplays_quagmire_cravings"
local Quagmire_NotificationWidget = require "widgets/quagmire_notificationwidget"
local QuagmireRecipeBookScreen = require "screens/quagmire_recipebookscreen"
local ChatQueue = require "widgets/redux/chatqueue"
local Desync = require "widgets/desync"
local WorldResetTimer = require "widgets/worldresettimer"
local PlayerDeathNotification = require "widgets/playerdeathnotification"
local GiftItemToast = require "widgets/giftitemtoast"
local YotbToast = require "widgets/yotbtoast"
local SkillTreeToast = require "widgets/skilltreetoast"
local ScrapbookToast = require "widgets/scrapbooktoast"
local VoteDialog = require "widgets/votedialog"
local TEMPLATES = require "widgets/templates"
local UserCommandPickerScreen = require "screens/redux/usercommandpickerscreen"
local UserCommands = require "usercommands"
local Wheel = require "widgets/wheel"
local WheelItem = require "widgets/wheelitem"

local easing = require("easing")
local TeamStatusBars = require("widgets/teamstatusbars")

local WHEEL_RADIUS = 175
local WHEEL_FOCUS_RADIUS = 178      
local NESTED_WHEEL_RADIUS_INCREMENT = 10
local NESTED_WHEEL_FOCUS_RADIUS_INCREMENT = 1

local Controls = Class(Widget, function(self, owner)
    Widget._ctor(self, "Controls")
    self.owner = owner

	local is_splitscreen = IsSplitScreen()
	local is_player1 = IsGameInstance(Instances.Player1)

    self._scrnw, self._scrnh = TheSim:GetScreenSize()

    self.playeractionhint = self:AddChild(FollowText(TALKINGFONT, 28))
    self.playeractionhint:SetHUD(owner.HUD.inst)
    self.playeractionhint:SetOffset(Vector3(0, 100, 0))
    self.playeractionhint:Hide()

    self.playeractionhint_itemhighlight = self:AddChild(FollowText(TALKINGFONT, 28))
    self.playeractionhint_itemhighlight:SetHUD(owner.HUD.inst)
    self.playeractionhint_itemhighlight:SetOffset(Vector3(0, 100, 0))
    self.playeractionhint_itemhighlight:Hide()

    self.attackhint = self:AddChild(FollowText(TALKINGFONT, 28))
    self.attackhint:SetHUD(owner.HUD.inst)
    self.attackhint:SetOffset(Vector3(0, 100, 0))
    self.attackhint:Hide()

    self.groundactionhint = self:AddChild(FollowText(TALKINGFONT, 28))
    self.groundactionhint:SetHUD(owner.HUD.inst)
    self.groundactionhint:SetOffset(Vector3(0, 100, 0))
    self.groundactionhint:Hide()

    self.blackoverlay = self:AddChild(Image("images/global.xml", "square.tex"))
    self.blackoverlay:SetVRegPoint(ANCHOR_MIDDLE)
    self.blackoverlay:SetHRegPoint(ANCHOR_MIDDLE)
    self.blackoverlay:SetVAnchor(ANCHOR_MIDDLE)
    self.blackoverlay:SetHAnchor(ANCHOR_MIDDLE)
    self.blackoverlay:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.blackoverlay:SetClickable(false)
    self.blackoverlay:SetTint(0,0,0,.5)
    self.blackoverlay:Hide()

	self.containerroot_under = self:AddChild(Widget(""))
    self.containerroot = self:AddChild(Widget(""))
    self.containerroot_side_behind = self:AddChild(Widget(""))
    self:MakeScalingNodes()

    self.saving = self.topright_over_root:AddChild(SavingIndicator(self.owner))
    self.saving:SetPosition(-440, 0, 0)

    self.toastlocations = {
        {pos=Vector3(115, 150, 0)},
        {pos=Vector3(215, 150, 0)},
        {pos=Vector3(315, 150, 0)},
        {pos=Vector3(415, 150, 0)},        
    }
	self.toastitems = {}

    self.item_notification = self.topleft_root:AddChild(GiftItemToast(self.owner, self))
    self.item_notification:SetPosition(115, 150, 0)
	table.insert(self.toastitems, self.item_notification)

    self.yotb_notification = self.topleft_root:AddChild(YotbToast(self.owner, self))
    self.yotb_notification:SetPosition(215, 150, 0)
	table.insert(self.toastitems, self.yotb_notification)

    self.skilltree_notification = self.topleft_root:AddChild(SkillTreeToast(self.owner, self))
    self.skilltree_notification:SetPosition(315, 150, 0)
	table.insert(self.toastitems, self.skilltree_notification)

    self.scrapbook_notification = self.topleft_root:AddChild(ScrapbookToast(self.owner, self))
    self.scrapbook_notification:SetPosition(415, 0, 0)
	table.insert(self.toastitems, self.scrapbook_notification)

    --self.worldresettimer = self.bottom_root:AddChild(WorldResetTimer(self.owner))
    self.worldresettimer = self.bottom_root:AddChild(PlayerDeathNotification(self.owner))
    self.inv = self.bottom_root:AddChild(Inv(self.owner))
    self.inv.autoanchor = self.worldresettimer
    self.inv:Hide()

    self.sidepanel = self.topright_root:AddChild(Widget("sidepanel"))
    self.sidepanel:SetScale(1,1,1)
    self.sidepanel:SetPosition(-80, -60, 0)

    if is_splitscreen then
        if is_player1 then
            if TheNet:GetServerGameMode() == "lavaarena" then
                self.status = self.bottom_root:AddChild(Lavaarena_StatusDisplays(self.owner))
                self.status:SetPosition(-180,105,0)
                --self.status:SetScale(1.8)
                self.teamstatus = self.topleft_root:AddChild(TeamStatusBars(self.owner))
            elseif TheNet:GetServerGameMode() == "quagmire" then
                self.status = self.bottom_root:AddChild(Quagmire_StatusDisplays(self.owner))
                --self.status:SetScale(1.4)
                self.quagmire_hangriness = self.top_root:AddChild(Quagmire_StatusCravingDisplay(self.owner))
                self.quagmire_hangriness.inst:DoPeriodicTask(.5, function() self.quagmire_hangriness:UpdateStatus() end, 0)
                self.quagmire_notifications = self.right_root:AddChild(Quagmire_NotificationWidget(self.owner))

                self.containerroot:MoveToFront() -- so safes ui opens on top of hangriness meter
            else
                self.status = self.topleft_root:AddChild(StatusDisplays(self.owner))
                self.status:SetPosition(120,-100,0)
                self.status:SetScale(1.4)

                self.secondary_status = self.topright_root:AddChild(SecondaryStatusDisplays(self.owner))
                self.secondary_status:SetPosition(-160,-250,0)
                self.secondary_status:SetScale(2.2)

				self.clock = self.sidepanel:AddChild(UIClock())
				if self.clock:IsCaveClock() then
					self.clock.inst:DoSimPeriodicTask(.5, function() self.clock:UpdateCaveClock(self.owner) end, 0)
				end
            end

            self.votedialog = self.topright_root:AddChild(VoteDialog(self.owner))
            self.votedialog:SetPosition(-350, 0, 0)
        else
            if TheNet:GetServerGameMode() == "lavaarena" then
                self.status = self.bottom_root:AddChild(Lavaarena_StatusDisplays(self.owner))
                self.status:SetPosition(-180,105,0)	
                --self.status:SetScale(1.8)
                self.teamstatus = self.topright_root:AddChild(TeamStatusBars(self.owner))
            elseif TheNet:GetServerGameMode() == "quagmire" then
                self.status = self.bottom_root:AddChild(Quagmire_StatusDisplays(self.owner))
                --self.status:SetScale(1.4)
                self.quagmire_hangriness = self.top_root:AddChild(Quagmire_StatusCravingDisplay(self.owner))
                self.quagmire_notifications = self.right_root:AddChild(Quagmire_NotificationWidget(self.owner))

                self.containerroot:MoveToFront() -- so safes ui opens on top of hangriness meter
            else
                self.status = self.topright_root:AddChild(StatusDisplays(self.owner))
                self.status:SetPosition(-120,-100,0)
                self.status:SetScale(1.4)

                self.secondary_status = self.topleft_root:AddChild(SecondaryStatusDisplays(self.owner))
                self.secondary_status:SetPosition(160,-250,0)
                self.secondary_status:SetScale(2.2)

				self.clock = self.sidepanel:AddChild(UIClock())
				if self.clock:IsCaveClock() then
					self.clock.inst:DoSimPeriodicTask(.5, function() self.clock:UpdateCaveClock(self.owner) end, 0)
				end
            end
            
            self.votedialog = self.topleft_root:AddChild(VoteDialog(self.owner))
            self.votedialog:SetPosition(350, 0, 0)
        end
    else
        if TheNet:GetServerGameMode() == "lavaarena" then
            self.status = self.bottom_root:AddChild(Lavaarena_StatusDisplays(self.owner))
            self.teamstatus = self.topleft_root:AddChild(TeamStatusBars(self.owner))
        elseif TheNet:GetServerGameMode() == "quagmire" then
            self.status = self.bottom_root:AddChild(Quagmire_StatusDisplays(self.owner))
            self.quagmire_hangriness = self.top_root:AddChild(Quagmire_StatusCravingDisplay(self.owner))
            self.quagmire_notifications = self.right_root:AddChild(Quagmire_NotificationWidget(self.owner))
            self.quagmire_notifications:SetPosition(0, 200)
            self.containerroot:MoveToFront() -- so safes ui opens on top of hangriness meter
        else
            self.status = self.sidepanel:AddChild(StatusDisplays(self.owner))
            self.status:SetPosition(0,-110,0)

            self.secondary_status = self.sidepanel:AddChild(SecondaryStatusDisplays(self.owner))
            self.secondary_status:SetPosition(0,-110,0)

            self.clock = self.sidepanel:AddChild(UIClock())
            if self.clock:IsCaveClock() then
                self.clock.inst:DoSimPeriodicTask(.5, function() self.clock:UpdateCaveClock(self.owner) end, 0)
            end
        end

        self.votedialog = self.topright_root:AddChild(VoteDialog(self.owner))
        self.votedialog:SetPosition(-330, 0, 0)
	end
	
    local twitch_options = TheFrontEnd:GetTwitchOptions()
    if twitch_options ~= nil and twitch_options:SupportedByPlatform() then
        if twitch_options:IsInitialized() and twitch_options:GetBroadcastingEnabled() and twitch_options:GetVisibleChatEnabled() then
            self.chatqueue = self.sidepanel:AddChild(ChatQueue(self.owner))
        end
    end

    -- Network global chat queue
    self.chat_queue_root = self:AddChild(Widget("chat_queue_root"))
    self.chat_queue_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.chat_queue_root:SetHAnchor(ANCHOR_MIDDLE)
    self.chat_queue_root:SetVAnchor(ANCHOR_BOTTOM)
    self.chat_queue_root:MoveToBack()
    self.chat_queue_root = self.chat_queue_root:AddChild(Widget(""))
    self.chat_queue_root:SetPosition(-90,765,0)
    self.networkchatqueue = self.chat_queue_root:AddChild(ChatQueue())
    self.networkchatqueue:SetClickable(false)

    self.containers = {}

    self.mapcontrols = self.bottomright_root:AddChild(MapControls())
    self.mapcontrols:SetPosition(-60,70,0)
    if TheNet:GetServerGameMode() == "quagmire" then
		self.mapcontrols.minimapBtn:SetTextures("images/quagmire_hud.xml", "map_button.tex")
		self.mapcontrols.map_tooltip = STRINGS.UI.RECIPE_BOOK.TITLE.."\n"
		self.mapcontrols:RefreshTooltips()
	end

    --set this to true, to enable the PAX demo timer
    if false and not IsGamePurchased() then
        self.demotimer = self.top_root:AddChild(DemoTimer(self.owner))
        self.demotimer:SetPosition(0, 0, 0)
    end

    self.containerroot:SetHAnchor(ANCHOR_MIDDLE)
    self.containerroot:SetVAnchor(ANCHOR_MIDDLE)
    self.containerroot:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.containerroot:SetMaxPropUpscale(MAX_HUD_SCALE)
    self.containerroot = self.containerroot:AddChild(Widget(""))

	self.containerroot_under:SetHAnchor(ANCHOR_MIDDLE)
	self.containerroot_under:SetVAnchor(ANCHOR_MIDDLE)
	self.containerroot_under:SetScaleMode(SCALEMODE_PROPORTIONAL)
	self.containerroot_under:SetMaxPropUpscale(MAX_HUD_SCALE)
	self.containerroot_under = self.containerroot_under:AddChild(Widget("containerroot_under"))

    self.containerroot_side_behind:SetHAnchor(ANCHOR_RIGHT)
    self.containerroot_side_behind:SetVAnchor(ANCHOR_MIDDLE)
    self.containerroot_side_behind:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.containerroot_side_behind:SetMaxPropUpscale(MAX_HUD_SCALE)
    self.containerroot_side_behind = self.containerroot_side_behind:AddChild(Widget("containerroot_side_behind"))

    self.containerroot_side = self:AddChild(Widget(""))
    self.containerroot_side:SetHAnchor(ANCHOR_RIGHT)
    self.containerroot_side:SetVAnchor(ANCHOR_MIDDLE)
    self.containerroot_side:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.containerroot_side:SetMaxPropUpscale(MAX_HUD_SCALE)
    self.containerroot_side = self.containerroot_side:AddChild(Widget("contaierroot_side"))
    self.containerroot_side:Hide()



    if not is_splitscreen then
        -- This assumes that splitscreen means console; consoles are forced to use
        -- the integrated backpack, so the side widget shouldn't cause issues there.
        if owner:HasTag("upgrademoduleowner") then
            --self.containerroot_side:SetPosition(-120, 0, 0)
        end
    end

    self.mousefollow = self:AddChild(Widget("follower"))
    self.mousefollow:FollowMouse(true)
    self.mousefollow:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.hover = self:AddChild(HoverText(self.owner))
    self.hover:SetScaleMode(SCALEMODE_PROPORTIONAL)
	
	if is_player1 then
	    self.craftingmenu = self.left_root:AddChild(CraftingMenu(self.owner, true))
	else
	    self.craftingmenu = self.right_root:AddChild(CraftingMenu(self.owner, false))
	end
	self.crafttabs = self.craftingmenu -- self.crafttabs is deprecated

	self.commandwheelroot = self:AddChild(Widget("CommandWheelRoot"))
    self.commandwheelroot:SetHAnchor(ANCHOR_MIDDLE)
    self.commandwheelroot:SetVAnchor(ANCHOR_MIDDLE)
    self.commandwheelroot:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.spellwheel = self.commandwheelroot:AddChild(Wheel("SpellWheel", owner, {ignoreleftstick = true,}))
	self.spellwheel.selected_label:SetSize(26)
	self.spellwheel.OnCancel = function() owner.HUD:CloseSpellWheel() end
	self.spellwheel.OnExecute = function(spellwheel)
		if not (spellwheel.invobject and spellwheel.invobject.components.spellbook and not spellwheel.invobject.components.spellbook.closeonexecute) then
			owner.HUD:CloseSpellWheel(true)
		end
	end


	self.commandwheel = self.commandwheelroot:AddChild(Wheel("CommandWheel", owner, {ignoreleftstick = Profile:GetCommandWheelAllowsGameplay(),}))
	self.commandwheel.OnCancel = function() owner.HUD:CloseCommandWheel() end
	self.commandwheel.OnExecute = self.commandwheel.OnCancel

	local character_name = self.owner.prefab
    if not kleifileexists("images/emotes_"..character_name..".xml") then -- TODO(JBK): This would be best done as SkinsPuppet and to do this when time permits. [SPCEWI]
        character_name = "generic"
    end
    self.character_name = character_name
    
    local emote_groups_template = {}	
	emote_groups_template[EMOTE_TYPE.EMOTION] = 
	{
        label= STRINGS.UI.EMOTES.EMOTIONS,
        image = "gesture_"..self.character_name.."_wave.tex",
        emotes = 
        {
        },
    }         
	emote_groups_template[EMOTE_TYPE.ACTION] = 
    {
        label= STRINGS.UI.EMOTES.ACTIONS,
        image = "gesture_"..self.character_name.."_pose.tex",
        emotes = 
        {
        },
    }  
	emote_groups_template[EMOTE_TYPE.UNLOCKABLE] = 
    {
        label= STRINGS.UI.EMOTES.UNLOCKABLES,
        image = "gesture_"..self.character_name.."_cheer.tex",
        emotes = 
        {
        },
    }

	local emote_groups_standing = deepcopy(emote_groups_template)
	local emote_groups_mounted = deepcopy(emote_groups_template)
	local common_emotes = GetCommonEmotes()	
	for name, emote in pairs(common_emotes) do
		--print("Emote:" .. name)
		if emote.type then	-- ignore unclassified emotes
			if emote.data.mounted then
				--print("...added to Mounted emote group:" .. tostring(emote.type))
				table.insert(emote_groups_mounted[emote.type].emotes, name)
			end
		
			if not emote.data.mountonly then
				--print("...added to Standing emote group:" .. tostring(emote.type))
				table.insert(emote_groups_standing[emote.type].emotes, name)
			end
		end
	end
        
    -- check and add unlockable emotes
    for item_type, emote in pairs(EMOTE_ITEMS) do
       if TheInventory:CheckOwnership(item_type) then      
	   		--print("Unlockable Emote:" .. emote.cmd_name)
			if emote.data.mounted then
				--print("...added to Mounted emotes")
				table.insert(emote_groups_mounted[EMOTE_TYPE.UNLOCKABLE].emotes, emote.cmd_name)
			end
		
			if not emote.data.mountedonly then
				--print("...added to Standing emotes")				
				table.insert(emote_groups_standing[EMOTE_TYPE.UNLOCKABLE].emotes, emote.cmd_name)
			end
		end
    end
    
	self.emote_wheel_standing = self:BuildEmoteWheel(self.character_name, emote_groups_standing)
	self.emote_wheel_mounted = self:BuildEmoteWheel(self.character_name, emote_groups_mounted)

	self:BuildCommandWheel()     

    if TheNet:GetIsClient() then
        --Not using topleft_root because we need to be on top of containerroot
        self.desync = self:AddChild(Widget("desyncroot"))
        self.desync:SetScaleMode(SCALEMODE_PROPORTIONAL)
        self.desync:SetHAnchor(ANCHOR_LEFT)
        self.desync:SetVAnchor(ANCHOR_TOP)
        self.desync:SetMaxPropUpscale(MAX_HUD_SCALE)
        self.desync = self.desync:AddChild(Desync(owner))
        if PLATFORM == "WIN32_RAIL" then
            self.desync:ShowHostPerf()
        end
    end

    self.dismounthintdelay = 0
    self.craftingandinventoryshown = false
	self.craftingshown = true

    self:SetHUDSize()

    --NOTE: this is triggered on the swap SOURCE. we need to stop updates because
    --      playercontroller component is removed first, entity remove is delayed.
    self.inst:ListenForEvent("seamlessplayerswap", function()
        self:StopUpdating()
    end, self.owner)

    --NOTE: this is triggered on the swap TARGET.
    self.inst:ListenForEvent("finishseamlessplayerswap", function()
        if self.owner.replica.inventory:IsVisible() then
            self:ShowCraftingAndInventory()
        end
    end, self.owner)

    self:StartUpdating()
end)

function Controls:ShowStatusNumbers()
    self.status:ShowStatusNumbers()
    if self.teamstatus ~= nil then
        self.teamstatus:ShowStatusNumbers()
    end
    if self.secondary_status ~= nil then
        self.secondary_status:ShowStatusNumbers()
    end
end

function Controls:ManageToast(toast, remove)
    local collapse = false
    for i,spot in ipairs(self.toastlocations) do
        if remove then
            if spot.toast == toast then
                spot.toast = nil
            end
            collapse = true
        else
            if not spot.toast then                
               spot.toast = toast 
               spot.toast:SetPosition(spot.pos.x,spot.pos.y,spot.pos.z)
               break
            end
        end

        if collapse then
            if self.toastlocations[i+1] and self.toastlocations[i+1].toast then
                spot.toast = self.toastlocations[i+1].toast
                self.toastlocations[i+1].toast = nil
                spot.toast:SetPosition(spot.pos.x,spot.pos.y,spot.pos.z)
            end
        end
    end
end

function Controls:HideStatusNumbers()
    self.status:HideStatusNumbers()
    if self.teamstatus ~= nil then
        self.teamstatus:HideStatusNumbers()
    end
    if self.secondary_status ~= nil then
        self.secondary_status:HideStatusNumbers()
    end
end

function Controls:SetDark(val)
    if val then
        self.blackoverlay:Show()
    else
        self.blackoverlay:Hide()
    end
end

function Controls:SetGhostMode(isghost)
    self.status:SetGhostMode(isghost)
    self.secondary_status:SetGhostMode(isghost)
	self.worldresettimer:SetGhostMode(isghost)
end

function Controls:MakeScalingNodes()

    --these are auto-scaling root nodes
    self.top_root = self:AddChild(Widget("top"))
    self.top_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.top_root:SetHAnchor(ANCHOR_MIDDLE)
    self.top_root:SetVAnchor(ANCHOR_TOP)
    self.top_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.topleft_root = self:AddChild(Widget("topleft"))
    self.topleft_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.topleft_root:SetHAnchor(ANCHOR_LEFT)
    self.topleft_root:SetVAnchor(ANCHOR_TOP)
    self.topleft_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.bottom_root = self:AddChild(Widget("bottom"))
    self.bottom_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.bottom_root:SetHAnchor(ANCHOR_MIDDLE)
    self.bottom_root:SetVAnchor(ANCHOR_BOTTOM)
    self.bottom_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.topright_root = self:AddChild(Widget("side"))
    self.topright_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.topright_root:SetHAnchor(ANCHOR_RIGHT)
    self.topright_root:SetVAnchor(ANCHOR_TOP)
    self.topright_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.right_root = self:AddChild(Widget("right_root"))
    self.right_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.right_root:SetHAnchor(ANCHOR_RIGHT)
    self.right_root:SetVAnchor(ANCHOR_MIDDLE)
    self.right_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.bottomright_root = self:AddChild(Widget("bottomright"))
    self.bottomright_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.bottomright_root:SetHAnchor(ANCHOR_RIGHT)
    self.bottomright_root:SetVAnchor(ANCHOR_BOTTOM)
    self.bottomright_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.left_root = self:AddChild(Widget("left_root"))
    self.left_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.left_root:SetHAnchor(ANCHOR_LEFT)
    self.left_root:SetVAnchor(ANCHOR_MIDDLE)
    self.left_root:SetMaxPropUpscale(MAX_HUD_SCALE)

    self.topright_over_root = self:AddChild(Widget("topright_over"))
    self.topright_over_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.topright_over_root:SetHAnchor(ANCHOR_RIGHT)
    self.topright_over_root:SetVAnchor(ANCHOR_TOP)
    self.topright_over_root:SetMaxPropUpscale(MAX_HUD_SCALE)
	
    --these are for introducing user-configurable hud scale
    self.topleft_root = self.topleft_root:AddChild(Widget("tl_scale_root"))
    self.topright_root = self.topright_root:AddChild(Widget("tr_scale_root"))
    self.bottom_root = self.bottom_root:AddChild(Widget("bottom_scale_root"))
    self.top_root = self.top_root:AddChild(Widget("top_scale_root"))
    self.left_root = self.left_root:AddChild(Widget("left_scale_root"))
    self.right_root = self.right_root:AddChild(Widget("right_scale_root"))
    self.bottomright_root = self.bottomright_root:AddChild(Widget("br_scale_root"))
    self.topright_over_root = self.topright_over_root:AddChild(Widget("tr_over_scale_root"))
end

function Controls:SetHUDSize()
    local scale = TheFrontEnd:GetHUDScale()
	local crafting_scale = TheFrontEnd:GetCraftingMenuScale()

    self.topleft_root:SetScale(scale)
    self.topright_root:SetScale(scale)
    self.bottom_root:SetScale(scale)
    self.top_root:SetScale(scale)
    self.bottomright_root:SetScale(scale)
    self.containerroot:SetScale(scale)
	self.containerroot_under:SetScale(scale)
    self.containerroot_side:SetScale(scale)
    self.containerroot_side_behind:SetScale(scale)

    self.hover:SetScale(scale)
    self.topright_over_root:SetScale(scale)

    self.mousefollow:SetScale(scale)
    
    local consoleScale = 1.0
    if IsPS5() then
        consoleScale = .65
    end
    if not IsConsole() or not TheSim:GetIsSplitScreen() then
		self.commandwheel:SetScale(consoleScale * scale)
	end
    if self.desync ~= nil then
        self.desync:SetScale(scale)
    end

	if IsGameInstance(Instances.Player1) then
		self.left_root:SetScale(crafting_scale)
	    self.right_root:SetScale(scale)
	else
		self.left_root:SetScale(scale)
	    self.right_root:SetScale(crafting_scale)
	end

    self.owner.HUD.inst:PushEvent("refreshhudsize", scale)
end

function Controls:OnUpdate(dt)
    if PerformingRestart then
        self.playeractionhint:SetTarget(nil)
        self.playeractionhint_itemhighlight:SetTarget(nil)
        self.attackhint:SetTarget(nil)
        self.groundactionhint:SetTarget(nil)
        return
    end

    local scrnw, scrnh = TheSim:GetScreenSize()
    if scrnw ~= self._scrnw or scrnh ~= self._scrnh then
        self._scrnw, self._scrnh = scrnw, scrnh
        self:SetHUDSize()
    end

    local controller_mode = TheInput:ControllerAttached()
    local controller_id = TheInput:GetControllerID()

    if controller_mode then
        self.mapcontrols:Hide()
    else
        self.mapcontrols:Show()
    end

    for k,v in pairs(self.containers) do
        if v.should_close_widget then
            self.containers[k] = nil
            v:Kill()
        end
    end

    --[[if false and self.demotimer then
        if IsGamePurchased() then
            self.demotimer:Kill()
            self.demotimer = nil
        end
    end]]

    local shownItemIndex = nil
    local itemInActions = false     -- the item is either shown through the actionhint or the groundaction

    if controller_mode and not (self.inv.open or self.commandwheel.isopen or self.craftingmenu:IsCraftingOpen() or self.spellwheel:IsOpen()) and self.owner:IsActionsVisible() then
        local ground_l, ground_r = self.owner.components.playercontroller:GetGroundUseAction()
        local ground_cmds = {}
        local isplacing = self.owner.components.playercontroller.deployplacer ~= nil or self.owner.components.playercontroller.placer ~= nil
        if isplacing then
            local placer = self.terraformplacer

            if self.owner.components.playercontroller.deployplacer ~= nil then
                self.groundactionhint:Show()
                self.groundactionhint:SetTarget(self.owner.components.playercontroller.deployplacer)

                local strs = {}
                if self.owner.components.playercontroller:IsAxisAlignedPlacement() then
                    table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID).." "..STRINGS.UI.HUD.CYCLE_AXIS_ALIGNED_PLACEMENT)
                end
                if self.owner.components.playercontroller.deployplacer.components.placer.can_build then
                    table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ACTION) .. " " .. self.owner.components.playercontroller.deployplacer.components.placer:GetDeployAction():GetActionString())
                end
                table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..STRINGS.UI.HUD.CANCEL)
                self.groundactionhint.text:SetString(table.concat(strs, "\n"))

            elseif self.owner.components.playercontroller.placer ~= nil then
                self.groundactionhint:Show()
                self.groundactionhint:SetTarget(self.owner)
                local strs = {}
                if self.owner.components.playercontroller:IsAxisAlignedPlacement() then
                    table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID).." "..STRINGS.UI.HUD.CYCLE_AXIS_ALIGNED_PLACEMENT)
                end
                table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ACTION) .. " " .. STRINGS.UI.HUD.BUILD)
                table.insert(strs, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION) .. " " .. STRINGS.UI.HUD.CANCEL)
                self.groundactionhint.text:SetString(table.concat(strs, "\n"))
            end
        else
            local aoetargeting = self.owner.components.playercontroller:IsAOETargeting()
            if ground_r ~= nil then
                if ground_r.action ~= ACTIONS.CASTAOE then
                    table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..ground_r:GetActionString())
                elseif aoetargeting then
                    table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ACTION).." "..ground_r:GetActionString())
                end
            end
            if aoetargeting then
                table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..STRINGS.UI.HUD.CANCEL)
            end
            if #ground_cmds > 0 then
                self.groundactionhint:Show()
                self.groundactionhint:SetTarget(self.owner)
                self.groundactionhint.text:SetString(table.concat(ground_cmds, "\n"))
            else
                self.groundactionhint:Hide()
            end
        end

        local attack_shown = false
        local controller_target = self.owner.components.playercontroller:GetControllerTarget()
        local controller_attack_target = self.owner.components.playercontroller:GetControllerAttackTarget()
        local l, r
        if controller_target ~= nil then
            l, r = self.owner.components.playercontroller:GetSceneItemControllerAction(controller_target)
        end

        if not isplacing and l == nil and ground_l == nil then
            ground_l = self.owner.components.playercontroller:GetGroundUseSpecialAction(nil, false)
            if ground_l ~= nil then
                table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ACTION).." "..ground_l:GetActionString())
                self.groundactionhint:Show()
                self.groundactionhint:SetTarget(self.owner)
                self.groundactionhint.text:SetString(table.concat(ground_cmds, "\n"))
            end
        end
        if not isplacing and r == nil and ground_r == nil then
            ground_r = self.owner.components.playercontroller:GetGroundUseSpecialAction(nil, true)
            if ground_r ~= nil then
                table.insert(ground_cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..ground_r:GetActionString())
                self.groundactionhint:Show()
                self.groundactionhint:SetTarget(self.owner)
                self.groundactionhint.text:SetString(table.concat(ground_cmds, "\n"))
            end
        end

        if controller_target ~= nil then
            local cmds, cmdsoffset
            local textblock = self.playeractionhint.text
            if self.groundactionhint.shown and distsq(self.owner:GetPosition(), controller_target:GetPosition()) < 1.33 then
                --You're close to your target so we should combine the two text blocks.
                cmds = ground_cmds
                cmdsoffset = #cmds
                textblock = self.groundactionhint.text
                self.playeractionhint:Hide()
                itemInActions = false
            else
                cmds = {}
                cmdsoffset = 0
                self.playeractionhint:Show()
                self.playeractionhint:SetTarget(controller_target)
                itemInActions = true
            end

            local adjective = controller_target:GetAdjective()
            table.insert(cmds, adjective ~= nil and (adjective.." "..controller_target:GetDisplayName()) or controller_target:GetDisplayName())
            shownItemIndex = #cmds

            if controller_target == controller_attack_target then
                table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ATTACK) .. " " .. STRINGS.UI.HUD.ATTACK)
                attack_shown = true
                
			    if self.owner.components.playercontroller:CanLockTargets() and not self.owner.components.playercontroller:IsControllerTargetLocked() then
                    table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_TARGET_LOCK) .. " " .. STRINGS.UI.HUD.LOCK_TARGET)
			    end
            end
            if (self.owner.CanExamine == nil or self.owner:CanExamine()) and
                --V2C: Closing the avatar popup takes priority
                not self.owner.HUD:IsPlayerAvatarPopUpOpen() and
                not self.owner.components.playercontroller:IsControllerTargetLocked() and
				(self.owner.sg == nil or self.owner.sg:HasStateTag("moving") or self.owner.sg:HasStateTag("idle") or self.owner.sg:HasStateTag("channeling")) and
				(self.owner:HasTag("moving") or self.owner:HasTag("idle") or self.owner:HasTag("channeling")) and
                controller_target:HasTag("inspectable") then
				local actionstr =
					CLOSEINSPECTORUTIL.CanCloseInspect(self.owner, controller_target) and
					STRINGS.ACTIONS.LOOKAT.CLOSEINSPECT or
					STRINGS.UI.HUD.INSPECT
				table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_INSPECT).." "..actionstr)
            end
            if l ~= nil then
                table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ACTION) .. " " .. l:GetActionString())
            end
            if r ~= nil and ground_r == nil then
                table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION) .. " " .. r:GetActionString())
            end
			if self.owner.components.playercontroller:IsControllerTargetLocked() then
                table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_TARGET_LOCK) .. " " .. STRINGS.UI.HUD.UNLOCK_TARGET)
                table.insert(cmds, TheInput:GetLocalizedControl(controller_id, CONTROL_TARGET_CYCLE) .. " " .. STRINGS.UI.HUD.NEXT_TARGET)
			end
            if controller_target.quagmire_shoptab ~= nil then
                for k, v in pairs(self.craftingmenu.tabs.shown) do
                    if k.filter == controller_target.quagmire_shoptab then
                        if v then
                            table.insert(cmds, TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_OPEN_CRAFTING).." "..STRINGS.UI.CRAFTING.TABACTION[controller_target.quagmire_shoptab.str])
                        end
                        break
                    end
                end
            end

            if #cmds - cmdsoffset <= 1 then
                --New special case that we support:
                -- target is highlighted but with no actions
                -- -> suppress any ground action hints
                -- -> use target's custom display name to show special action hint
                if cmds ~= ground_cmds then
                    self.groundactionhint:Hide()
                    self.groundactionhint:SetTarget(nil)
                end
                textblock:SetString(cmds[#cmds])
            else
                textblock:SetString(table.concat(cmds, "\n"))
            end
		elseif not self.groundactionhint.shown then
				local rider = self.owner.replica.rider
			local mount = rider and rider:GetMount() or nil
			local container = mount and mount.replica.container or nil
			if container and container:IsOpenedBy(self.owner) then
				self.playeractionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..BufferedAction(self.owner, self.owner, ACTIONS.RUMMAGE):GetActionString())
				self.playeractionhint:Show()
				self.playeractionhint:SetTarget(self.owner)
			elseif self.dismounthintdelay <= 0 then
				if self.owner.components.spellbook and self.owner.components.spellbook:CanBeUsedBy(self.owner) then
					self.playeractionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..BufferedAction(self.owner, self.owner, ACTIONS.USESPELLBOOK):GetActionString())
					self.playeractionhint:Show()
					self.playeractionhint:SetTarget(self.owner)
				elseif mount and not (self.owner.components.playercontroller and self.owner.components.playercontroller:HasAOETargeting()) then
					self.playeractionhint.text:SetString(TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ALTACTION).." "..STRINGS.ACTIONS.DISMOUNT)
					self.playeractionhint:Show()
					self.playeractionhint:SetTarget(self.owner)
				else
					self.playeractionhint:Hide()
					self.playeractionhint:SetTarget(nil)
				end
			else
				self.playeractionhint:Hide()
				self.playeractionhint:SetTarget(nil)
			end
		else
			self.playeractionhint:Hide()
			self.playeractionhint:SetTarget(nil)
        end

        if controller_attack_target ~= nil and not attack_shown then
            self.attackhint:Show()
            self.attackhint:SetTarget(controller_attack_target)
            self.attackhint.text:SetString(TheInput:GetLocalizedControl(controller_id, CONTROL_CONTROLLER_ATTACK) .. " " .. STRINGS.UI.HUD.ATTACK)
        else
            self.attackhint:Hide()
            self.attackhint:SetTarget(nil)
        end
    else
        self.attackhint:Hide()
        self.attackhint:SetTarget(nil)

        self.playeractionhint:Hide()
        self.playeractionhint:SetTarget(nil)

        self.groundactionhint:Hide()
        self.groundactionhint:SetTarget(nil)
    end

	if self.owner.sg and not self.owner.sg:HasStateTag("idle") or not self.owner:HasTag("idle") then
        self.dismounthintdelay = .5
    elseif self.dismounthintdelay > 0 then
        self.dismounthintdelay = self.dismounthintdelay - dt
    end

    --default offsets
    self.playeractionhint:SetScreenOffset(0,0)
    self.attackhint:SetScreenOffset(0,0)

    --if we are showing both hints, make sure they don't overlap
    if self.attackhint.shown and self.playeractionhint.shown then

        local w1, h1 = self.attackhint.text:GetRegionSize()
        local x1, y1 = self.attackhint:GetPosition():Get()
        --print (w1, h1, x1, y1)

        local w2, h2 = self.playeractionhint.text:GetRegionSize()
        local x2, y2 = self.playeractionhint:GetPosition():Get()
        --print (w2, h2, x2, y2)

        local sep = (x1 + w1/2) < (x2 - w2/2) or
                    (x1 - w1/2) > (x2 + w2/2) or
                    (y1 + h1/2) < (y2 - h2/2) or
                    (y1 - h1/2) > (y2 + h2/2)

        if not sep then
            local a_l = x1 - w1/2
            local a_r = x1 + w1/2

            local p_l = x2 - w2/2
            local p_r = x2 + w2/2

            if math.abs(p_r - a_l) < math.abs(p_l - a_r) then
                local d = (p_r - a_l) + 20
                self.attackhint:SetScreenOffset(d/2,0)
                self.playeractionhint:SetScreenOffset(-d/2,0)
            else
                local d = (a_r - p_l) + 20
                self.attackhint:SetScreenOffset( -d/2,0)
                self.playeractionhint:SetScreenOffset(d/2,0)
            end
        end
    end

    self:HighlightActionItem(shownItemIndex, itemInActions)
end

function Controls:DelayControllerSpellWheelHint()
	self.dismounthintdelay = 0.5
end

function Controls:HighlightActionItem(itemIndex, itemInActions)
    if itemIndex then
        local followerWidget
        if itemInActions then
            followerWidget = self.playeractionhint
        else
            followerWidget = self.groundactionhint
        end
        self.playeractionhint_itemhighlight:Show()
        local offsetx, offsety = followerWidget:GetScreenOffset()
        self.playeractionhint_itemhighlight:SetScreenOffset(offsetx, offsety)
        self.playeractionhint_itemhighlight:SetTarget(followerWidget.target)

        local str = followerWidget.text.string
        local itemlines = {}
        local commandlines = {}
        local target = self.owner.components.playercontroller.controller_target
        for idx,line in ipairs(string.split(str, "\n")) do
            if idx==itemIndex then
                itemlines[#itemlines+1] = line
                commandlines[#commandlines+1]= " "
            else
                itemlines[#itemlines+1] = " "
                commandlines[#commandlines+1] = line
            end
        end
        followerWidget.text:SetString(table.concat(commandlines,"\n"))

        self.playeractionhint_itemhighlight.text:SetString(table.concat(itemlines,"\n"))
        if target:GetIsWet() then
            self.playeractionhint_itemhighlight.text:SetColour(unpack(WET_TEXT_COLOUR))
        else
            self.playeractionhint_itemhighlight.text:SetColour(unpack(NORMAL_TEXT_COLOUR))
        end
    else
        self.playeractionhint_itemhighlight:Hide()
    end
end

function Controls:ShowMap(world_position)
    if self.owner ~= nil and self.owner.HUD ~= nil and (not self.owner.HUD:IsMapScreenOpen()) then
		if TheNet:GetServerGameMode() == "quagmire" then
			if self.owner.HUD:IsStatusScreenOpen() then
				TheFrontEnd:PopScreen()
			end
			TheFrontEnd:PushScreen(QuagmireRecipeBookScreen(self.owner))
		elseif not GetGameModeProperty("no_minimap") then
			if self.owner.HUD:IsStatusScreenOpen() then
				TheFrontEnd:PopScreen()
			end

			local mapscr = MapScreen(self.owner)
			TheFrontEnd:PushScreen(mapscr)

			if world_position ~= nil and mapscr ~= nil then
				self:FocusMapOnWorldPosition(mapscr, world_position.x, world_position.z)
			end
		end
    end
end

function Controls:FocusMapOnWorldPosition(mapscreen, worldx, worldz)
	if mapscreen == nil or mapscreen.minimap == nil then return nil end

    mapscreen:SetZoom(1)

	local player_x, player_y, player_z = self.owner.Transform:GetWorldPosition()
	local dx, dy = worldx - player_x, worldz - player_z

	local angle_correction = (PI / 4) * (10 - (math.fmod(TheCamera:GetHeadingTarget() / 360, 1) * 8))
	local theta = math.atan2(dy, dx)
	local mag = math.sqrt(dx * dx + dy * dy)

	mapscreen.minimap:Offset(math.cos(theta + angle_correction) * mag, math.sin(theta + angle_correction) * mag)
end

function Controls:HideMap()
    if self.owner ~= nil and self.owner.HUD ~= nil and self.owner.HUD:IsMapScreenOpen() then
        TheFrontEnd:PopScreen()
    end
end

function Controls:ToggleMap()
    if self.owner ~= nil and self.owner.HUD ~= nil then
		if TheNet:GetServerGameMode() == "quagmire" then
			if self.owner.HUD:IsMapScreenOpen() then
				TheFrontEnd:PopScreen()
			elseif self.owner.components.playercontroller ~= nil and self.owner.components.playercontroller:IsMapControlsEnabled() then
				if self.owner.HUD:IsStatusScreenOpen() then
					TheFrontEnd:PopScreen()
				end
				TheFrontEnd:PushScreen(QuagmireRecipeBookScreen(self.owner))
			end
		elseif not GetGameModeProperty("no_minimap") then
			if self.owner.HUD:IsMapScreenOpen() then
				TheFrontEnd:PopScreen()
			elseif self.owner.components.playercontroller ~= nil and self.owner.components.playercontroller:IsMapControlsEnabled() then
				if self.owner.HUD:IsStatusScreenOpen() then
					TheFrontEnd:PopScreen()
				end
				TheFrontEnd:PushScreen(MapScreen(self.owner))
			end
		end
    end
end

function Controls:DoShowCrafting_Internal()
	if not GetGameModeProperty("no_crafting") then
		self.craftingmenu:Show()
	end
end

function Controls:DoHideCrafting_Internal()
	self.owner.HUD:CloseCrafting(true)
	self.craftingmenu:Hide()
end

function Controls:ShowCrafting()
	if not self.craftingshown then
		self.craftingshown = true
		if self.craftingandinventoryshown then
			self:DoShowCrafting_Internal()
		end
	end
end

function Controls:HideCrafting()
	if self.craftingshown then
		self.craftingshown = false
		if self.craftingandinventoryshown then
			self:DoHideCrafting_Internal()
		end
		self.inv:OnCraftingHidden()
	end
end

-- NOTES(JBK): .stay_open_on_hide containers must be hidden and shown in ShowCraftingAndInventory and HideCraftingAndInventory!
function Controls:ShowCraftingAndInventory()
    if not self.craftingandinventoryshown then
        self.craftingandinventoryshown = true
		if self.craftingshown then
			self:DoShowCrafting_Internal()
		end
        self.inv:Show()
        self.containerroot_side:Show()
        self.containerroot_side_behind:Show()
        if self.secondary_status and self.secondary_status.side_inv then
            self.secondary_status.side_inv:Show()
        end
		for i, v in ipairs(self.toastitems) do
			v:ToggleCrafting(false)
		end
        if self.status.ToggleCrafting ~= nil then
            self.status:ToggleCrafting(false)
        end
    end
end

function Controls:HideCraftingAndInventory()
    if self.craftingandinventoryshown then
        self.inv:CloseControllerInventory()
        self.craftingandinventoryshown = false
		if self.craftingshown then
			self:DoHideCrafting_Internal()
		end
        self.inv:Hide()
        self.containerroot_side:Hide()
        self.containerroot_side_behind:Hide()
        if self.secondary_status and self.secondary_status.side_inv then
            self.secondary_status.side_inv:Hide()
        end
		for i, v in ipairs(self.toastitems) do
			v:ToggleCrafting(true)
		end
        if self.status.ToggleCrafting ~= nil then
            self.status:ToggleCrafting(true)
        end
		self.spellwheel:Close()
    end
end

function Controls:BuildEmoteWheel(character_name, emote_groups)
	-- build the emote wheel
	local emote_wheel = {}    
    for name, details in pairs(emote_groups) do
        local nested_wheel_radius = WHEEL_RADIUS -- 0 if auto incrementing
        local nested_wheel_focus_radius = WHEEL_FOCUS_RADIUS -- 0 if auto incrementing
        local nested_wheel_items = {}      
		local num_emotes = 0  
        for i, emote in ipairs(details.emotes) do
            --nested_wheel_radius = nested_wheel_radius + NESTED_WHEEL_RADIUS_INCREMENT
            --nested_wheel_focus_radius = nested_wheel_focus_radius + NESTED_WHEEL_FOCUS_RADIUS_INCREMENT
		    table.insert(nested_wheel_items, WheelItem.EmoteItem(emote, character_name))
			num_emotes = num_emotes + 1
        end

		if 8 < num_emotes then
			local num_over = num_emotes - 8 
			nested_wheel_radius = nested_wheel_radius + (num_over * NESTED_WHEEL_RADIUS_INCREMENT)
			nested_wheel_focus_radius = nested_wheel_radius + (num_over * NESTED_WHEEL_FOCUS_RADIUS_INCREMENT)
		end

		-- don't insert a nested wheel if it's empty
		if 0 < num_emotes then
			local nested_wheel = {name=name, items=nested_wheel_items, r=nested_wheel_radius, f=nested_wheel_focus_radius}
			table.insert(emote_wheel, {label=details.label, atlas="images/emotes_" .. character_name .. ".xml", normal=details.image, nestedwheel=nested_wheel})
		end
    end

	return emote_wheel
end

function Controls:BuildCommandWheel(is_splitscreen)
	self.can_invite = IsConsole() and TheNet:CanSendInvitation() or false
	self.is_mounted = self.owner.replica.rider and self.owner.replica.rider:IsRiding()	

	local emote_wheel = self.is_mounted and self.emote_wheel_mounted or self.emote_wheel_standing
	local base_wheel = {}
    table.insert(base_wheel, {label=STRINGS.UI.COMMANDWHEEL.EMOTES,	checkenabled=function() return not self.owner:HasTag("playerghost") end, nestedwheel={name="emotes", items=emote_wheel, r=WHEEL_RADIUS, f=WHEEL_FOCUS_RADIUS}, atlas="images/emotes_"..self.character_name..".xml", normal="gesture_"..self.character_name.."_kiss.tex"})
	if PLATFORM ~= "SWITCH" and IsConsole() then
		table.insert(base_wheel, WheelItem.TextChatItem( true, "command_whisper.tex" ))		
	end

	table.insert(base_wheel, {label=STRINGS.UI.COMMANDWHEEL.PLAYERLIST,	execute=function() self.owner.HUD:ShowPlayerStatusScreen() end, atlas="images/command_wheel.xml", normal="command_playerlisting.tex"})
    table.insert(base_wheel, {label=STRINGS.UI.COMMANDWHEEL.USERCOMMANDS, execute=function() TheFrontEnd:PushScreen(UserCommandPickerScreen(self.owner, nil)) end, atlas="images/command_wheel.xml", normal="command_usercommands.tex"})

    if self.can_invite then	
		table.insert(base_wheel, {label=STRINGS.UI.COMMANDWHEEL.INVITE,	execute=function() if PLATFORM == "XBONE" then TheNet:StartInvite() else TheNet:SendInvitation() end end, atlas="images/command_wheel.xml", normal="command_playerinvite.tex"})
	end
	if PLATFORM ~= "SWITCH" and IsConsole() then
		table.insert(base_wheel, WheelItem.TextChatItem( false, "command_talk.tex" ))
	end

	
	self.commandwheel:SetItems( base_wheel, WHEEL_RADIUS, WHEEL_FOCUS_RADIUS)
    local consoleScale = 1.0
    if IsPS5() then
        consoleScale = .65
    end
	if is_splitscreen then
		self.commandwheel:SetScale(TheFrontEnd:GetHUDScale() * 1.6 * consoleScale)
	else
        self.commandwheel:SetScale(TheFrontEnd:GetHUDScale() * consoleScale)
	end
end

return Controls
