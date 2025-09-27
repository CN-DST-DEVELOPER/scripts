local UIAnim = require("widgets/uianim")

--------------------------------------------------------------------------

local FLAGBITS =
{
	BIG = 0,
	SPRINT_DRAIN = 1, --V2C: is sprint hunger drain multiplier active; NOT just "is sprinting". (skills can let you sprint without the drain multiplier.)
	ENDURANCE = 2,
	LUNAR = 3,
	SHADOW = 4,
}

local SMALL_SYMBOLS =
{
	"body",
	"body_overlay",
	"chew",
	"eye",
	"face",
	"foot",
	"mouth",
	"tail",
	"tongue",
}

local BIG_SYMBOLS =
{
	"beefalo_body",
	"beefalo_facebase",
	"beefalo_headbase",
	"beefalo_hoof",
	"beefalo_jowls",
	"beefalo_mouthmouth",
	"beefalo_nose",
	"beefalo_tail",
	"beffalo_lips",
	"woby_fur_slider",
}

--------------------------------------------------------------------------

local COMMAND_NAMES =
{
	"PET",
	"MOUNT",
	"SHRINK",
	"SIT",
	"PICKUP",
	"FORAGING",
	"WORKING",
	"SPRINTING",
	"SHADOWDASH",
	"REMEMBERCHEST",
	"COURIER",

	--These are just for RPC
	"OPENWHEEL",
	"CLOSEWHEEL",
	"LOCKBAG",
	"UNLOCKBAG",
}
local COMMANDS = table.invert(COMMAND_NAMES)

--------------------------------------------------------------------------

local ICON_SCALE = 0.6
local ICON_RADIUS = 60
local SPELLBOOK_RADIUS = 120
local SPELLBOOK_FOCUS_RADIUS = SPELLBOOK_RADIUS-- + 2

local function MakeWobyCommand(cmd)
	return function(inst)
		if not (ThePlayer.woby_commands_classified and ThePlayer.woby_commands_classified:ExecuteCommand(cmd)) then
			TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
		end
	end
end

local function SetupMouseOver(w)
	--V2C: using Image widget for mouseover hitbox, since anim hitbox is not accurate
	w.uianim:SetClickable(false)
	w.mouseover = w:AddChild(Image())
	w.mouseover:SetRadiusForRayTraces(ICON_RADIUS)
	w.mouseover:MoveToBack()
end

local function MakeAutocastToggle(name, noclicksound, overrideanimname)
	return function(w)
		SetupMouseOver(w)
		w.ring = w:AddChild(UIAnim())
		w.ring:GetAnimState():SetBank("spell_icons_woby")
		w.ring:GetAnimState():SetBuild("spell_icons_woby")
		w.ring:GetAnimState():PlayAnimation("autocast_ring", true)
		w.ring.OnUpdate = function(ring, dt)
			if ThePlayer and ThePlayer.woby_commands_classified and ThePlayer.woby_commands_classified:GetValue(name) then
				local anim = overrideanimname or name
				anim =
					(w.animstate:IsCurrentAnimation(anim.."_focus") and "autocast_ring_focus") or
					(w.animstate:IsCurrentAnimation(anim.."_pressed") and "autocast_ring_pressed") or
					"autocast_ring"
				if not ring:GetAnimState():IsCurrentAnimation(anim) then
					local frame = ring:GetAnimState():GetCurrentAnimationFrame()
					ring:GetAnimState():PlayAnimation(anim, true)
					ring:GetAnimState():SetFrame(frame)
				end
				ring:Show()
				if not noclicksound then
					w.overrideclicksound = "dontstarve/HUD/toggle_off"
				end
			else
				ring:Hide()
				if not noclicksound then
					w.overrideclicksound = "dontstarve/HUD/toggle_on"
				end
			end
		end
		w.OnShow = function(w)
			w.ring:StartUpdating()
		end
		w.OnHide = function(w)
			w.ring:StopUpdating()
		end
		if w.shown then
			w.ring:StartUpdating()
			w.ring:OnUpdate(0)
		end
	end
end

local COMMAND_DEFS =
{
	PET =
	{
		label = STRINGS.ACTIONS.PET,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.ACTIONS.PET)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.PET),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "pet" },
			focus = { anim = "pet_focus" },
			down = { anim = "pet_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = SetupMouseOver,
	},

	MOUNT =
	{
		label = STRINGS.ACTIONS.MOUNT,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.ACTIONS.MOUNT)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.MOUNT),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "mount" },
			focus = { anim = "mount_focus" },
			down = { anim = "mount_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = SetupMouseOver,
		default_focus = true,
	},

	SHRINK =
	{
		label = STRINGS.WOBY_COMMANDS.SHRINK,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SHRINK)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.SHRINK),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "forcetransform" },
			focus = { anim = "forcetransform_focus" },
			down = { anim = "forcetransform_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = SetupMouseOver,
	},

	SIT =
	{
		label = STRINGS.WOBY_COMMANDS.SIT,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SIT)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.SIT),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "sit" },
			focus = { anim = "sit_focus" },
			down = { anim = "sit_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = MakeAutocastToggle("sit", true),
	},

	SIT_SMALL =
	{
		label = STRINGS.WOBY_COMMANDS.SIT,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SIT)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.SIT),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "sit_small" },
			focus = { anim = "sit_small_focus" },
			down = { anim = "sit_small_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = MakeAutocastToggle("sit", true, "sit_small"),
	},

	PICKUP =
	{
		label = STRINGS.WOBY_COMMANDS.PICKUP,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.PICKUP)
			inst.components.spellbook.closeonexecute = false
		end,
		execute = MakeWobyCommand(COMMANDS.PICKUP),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "pickup" },
			focus = { anim = "pickup_focus" },
			down = { anim = "pickup_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = MakeAutocastToggle("pickup"),
		skill = "walter_woby_itemfetcher",
	},

	FORAGING =
	{
		label = STRINGS.WOBY_COMMANDS.FORAGING,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.FORAGING)
			inst.components.spellbook.closeonexecute = false
		end,
		execute = MakeWobyCommand(COMMANDS.FORAGING),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "foraging" },
			focus = { anim = "foraging_focus" },
			down = { anim = "foraging_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = MakeAutocastToggle("foraging"),
		skill = "walter_woby_foraging",
	},

	WORKING =
	{
		label = STRINGS.WOBY_COMMANDS.WORKING,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.WORKING)
			inst.components.spellbook.closeonexecute = false
		end,
		execute = MakeWobyCommand(COMMANDS.WORKING),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "working" },
			focus = { anim = "working_focus" },
			down = { anim = "working_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = MakeAutocastToggle("working"),
		skill = "walter_woby_taskaid",
	},

	REMEMBERCHEST =
	{
		label = STRINGS.WOBY_COMMANDS.REMEMBERCHEST,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.REMEMBERCHEST)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = MakeWobyCommand(COMMANDS.REMEMBERCHEST),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "rememberchest" },
			focus = { anim = "rememberchest_focus" },
			down = { anim = "rememberchest_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = SetupMouseOver,
		skill = "walter_camp_wobycourier",
	},

	COURIER =
	{
		label = STRINGS.WOBY_COMMANDS.COURIER,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.COURIER)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = function(inst)
            local playercontroller = ThePlayer.components.playercontroller
			if playercontroller then
				playercontroller:PullUpMap(inst, ACTIONS.DIRECTCOURIER_MAP)
			end
		end,
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "courier" },
			focus = { anim = "courier_focus" },
			down = { anim = "courier_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = SetupMouseOver,
		skill = "walter_camp_wobycourier",
	},

	BLANK =
	{
		label = "",
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			disabled = { anim = "empty" },
		},
		widget_scale = ICON_SCALE,
		checkenabled = function() return false end,
		noselect = true,
	},

	SPACER =
	{
		label = "",
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			disabled = { anim = "empty" },
		},
		widget_scale = ICON_SCALE,
		checkenabled = function() return false end,
		noselect = true,
		spacer = true,
	},
}

local SPELLBOOK_BG =
{
	bank = "spell_icons_woby",
	build = "spell_icons_woby",
	anim = "bg",
	widget_scale = ICON_SCALE,
}

local BIG_SPELLS_LEFT =
{
	COMMAND_DEFS.WORKING,
	COMMAND_DEFS.FORAGING,
	COMMAND_DEFS.PICKUP,
	COMMAND_DEFS.SIT,
}

local BIG_SPELLS_RIGHT =
{
	COMMAND_DEFS.MOUNT,
	COMMAND_DEFS.COURIER,
	COMMAND_DEFS.REMEMBERCHEST,
	COMMAND_DEFS.SHRINK,
}

local SMALL_SPELLS_LEFT =
{
	COMMAND_DEFS.WORKING,
	COMMAND_DEFS.FORAGING,
	COMMAND_DEFS.PICKUP,
	COMMAND_DEFS.SIT_SMALL,
}

local SMALL_SPELLS_RIGHT =
{
	COMMAND_DEFS.PET,
	COMMAND_DEFS.COURIER,
	COMMAND_DEFS.REMEMBERCHEST,
}

local function CanUseWobyCommands(inst, user)
	if user.woby_commands_classified and
		user.woby_commands_classified:GetWoby() == inst and
		not inst:HasTag("transforming")
	then
		if user.HUD then
			local range = user.HUD:GetCurrentOpenSpellBook() == inst and 18 or 15
			return user:IsNear(inst, range)
		end
		return true
	end
	return false
end

local function ShouldOpenWobyCommands(inst, user)
	return user.woby_commands_classified ~= nil and not user.woby_commands_classified:IsBusy()
end

local function OnOpenSpellBook(inst)
	TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, math.huge, math.huge, 10)
	local player = ThePlayer
	if player and player.woby_commands_classified then
		player.woby_commands_classified:NotifyWheelIsOpen(true)
	end
end

local function OnCloseSpellBook(inst)
	TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	local player = ThePlayer
	if player and player.woby_commands_classified then
		player.woby_commands_classified:NotifyWheelIsOpen(false)
	end
end

local function RefreshCommands(inst, player)
	local skilltreeupdater = player and player.components.skilltreeupdater or nil
	local isbig = inst:HasTag("largecreature")
	local j = 1

	inst._spells[1] = COMMAND_DEFS.SPACER
	j = j + 1

	for i, v in ipairs(isbig and BIG_SPELLS_RIGHT or SMALL_SPELLS_RIGHT) do
		if v.skill == nil or (skilltreeupdater and skilltreeupdater:IsActivated(v.skill)) then
			inst._spells[j] = v
		else
			inst._spells[j] = COMMAND_DEFS.BLANK
		end
		j = j + 1
	end

	for i = j, 5 do
		inst._spells[j] = COMMAND_DEFS.BLANK
		j = j + 1
	end

	inst._spells[j] = COMMAND_DEFS.SPACER
	j = j + 1

	for i, v in ipairs(isbig and BIG_SPELLS_LEFT or SMALL_SPELLS_LEFT) do
		if v.skill == nil or (skilltreeupdater and skilltreeupdater:IsActivated(v.skill)) then
			inst._spells[j] = v
			j = j + 1
		end
	end

	if j <= 10 then
		local shift = 11 - j
		for i = j - 1, 7, -1 do
			inst._spells[i + shift] = inst._spells[i]
		end
		for i = 7, 7 + shift - 1 do
			inst._spells[i] = COMMAND_DEFS.BLANK
		end
	end
end

local function SetupClientCommandWheelRefreshers(inst, player)
	if inst._onskillrefreh_wobycommon == nil then
		inst._onskillrefreh_wobycommon = function(player) RefreshCommands(inst, player) end
		inst:ListenForEvent("onactivateskill_client", inst._onskillrefreh_wobycommon, player)
		inst:ListenForEvent("ondeactivateskill_client", inst._onskillrefreh_wobycommon, player)
		if player._PostActivateHandshakeState_Client == POSTACTIVATEHANDSHAKE.READY then
			RefreshCommands(inst, player)
		elseif inst._onskilltreeinitialized_wobycommon == nil then
			inst._onskilltreeinitialized_wobycommon = function(player)
				inst:RemoveEventCallback("skilltreeinitialized_client", inst._onskilltreeinitialized_wobycommon, player)
				inst._onskilltreeinitialized_wobycommon = nil
				RefreshCommands(inst, player)
			end
			inst:ListenForEvent("skilltreeinitialized_client", inst._onskilltreeinitialized_wobycommon, player)
		end
	end
end

local function DelayedSetupClientCommandWheelRefreshers(inst)
	local player = ThePlayer
	if player and player.woby_commands_classified and player.woby_commands_classified:GetWoby() == inst then
		SetupClientCommandWheelRefreshers(inst, player)
	end
end

local function SetupCommandWheel(inst)
	inst._spells = {}

	--V2C: inst.prefab is not available yet
	local sfxpath =
		inst:HasTag("largecreature") and
		"meta5/woby/bigwoby_actionwheel_UI" or
		"meta5/woby/smallwoby_actionwheel_UI"

	inst:AddComponent("spellbook")
	inst.components.spellbook:SetRadius(SPELLBOOK_RADIUS)
	inst.components.spellbook:SetFocusRadius(SPELLBOOK_FOCUS_RADIUS)
	inst.components.spellbook:SetCanUseFn(CanUseWobyCommands)
	inst.components.spellbook:SetShouldOpenFn(ShouldOpenWobyCommands)
	inst.components.spellbook:SetOnOpenFn(OnOpenSpellBook)
	inst.components.spellbook:SetOnCloseFn(OnCloseSpellBook)
	inst.components.spellbook:SetItems(inst._spells)
	inst.components.spellbook:SetBgData(SPELLBOOK_BG)
	inst.components.spellbook.opensound = sfxpath
	--inst.components.spellbook.closesound = sfxpath
	--inst.components.spellbook.executesound = "meta4/winona_UI/select"	--use .clicksound for item buttons instead
	--inst.components.spellbook.focussound = "meta4/winona_UI/hover"

	if not TheWorld.ismastersim then
		--Delayed because woby prefab will call this during construction, which means
		--woby_commands_classified:GetWoby() won't be able to return it properly yet.
		inst:DoStaticTaskInTime(0, DelayedSetupClientCommandWheelRefreshers)
	end
end

--------------------------------------------------------------------------

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
local CONTAINER_MUST_TAGS = { "_container" }
local CONTAINER_CANT_TAGS = { "companion", "portablestorage", "mermonly", "mastercookware", "FX", "NOCLICK", "DECOR", "INLIMBO" }
local ALLOWED_CONTAINER_TYPES = { "chest", "pack" }
local function WobyCourier_ForceDelivery(_pet, itemcountmax)
    local courierdata = _pet.woby_commands_classified.courierdata
    local platform = _pet:GetCurrentPlatform()
    local pt = courierdata.destpos
    local validchests = {}
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, TUNING.SKILLS.WALTER.COURIER_CHEST_DETECTION_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)
    for _, ent in ipairs(ents) do
        if ent.components.container ~= nil and
            table.contains(ALLOWED_CONTAINER_TYPES, ent.components.container.type) and
            (ent.components.container.canbeopened or ent.components.container.canacceptgivenitems) and -- NOTES(JBK): canacceptgivenitems is a mod flag for now.
            ent:IsOnPassablePoint() and
            ent:GetCurrentPlatform() == platform
        then
            table.insert(validchests, ent)
        end
    end
    local itemcount = 0
    -- First loop try to find chests that have items already in Woby to deliver.
    for _, ent in ipairs(validchests) do
        for slot, item in pairs(_pet.components.container.slots) do
            local stacksize = item.components.stackable and item.components.stackable.stacksize or 1
            if item and ent.components.container:Has(item.prefab, 1) and ent.components.container:CanAcceptCount(item) >= stacksize then
                item = _pet.components.container:RemoveItemBySlot(slot)
                ent.components.container:GiveItem(item, nil, pt, true)
                itemcount = itemcount + 1
                if itemcountmax and itemcount >= itemcountmax then
                    return
                end
            end
        end
    end
    -- Second loop try to find chests that have space for anything left.
    for _, ent in ipairs(validchests) do
        for slot, item in pairs(_pet.components.container.slots) do
            local stacksize = item.components.stackable and item.components.stackable.stacksize or 1
            if item and ent.components.container:CanAcceptCount(item) >= stacksize then
                item = _pet.components.container:RemoveItemBySlot(slot)
                ent.components.container:GiveItem(item, nil, pt, true)
                itemcount = itemcount + 1
                if itemcountmax and itemcount >= itemcountmax then
                    return
                end
            end
        end
    end
    -- Flag that we are done.
    _pet.woby_commands_classified.outfordelivery:set(false)
end

local function WobyCourier_FindValidContainerForItem(_pet, item)
    local courierdata = _pet.woby_commands_classified.courierdata
    local platform = _pet:GetCurrentPlatform()
    local pt = courierdata.destpos
    local validchests = {}
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, TUNING.SKILLS.WALTER.COURIER_CHEST_DETECTION_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)
    for _, ent in ipairs(ents) do
        if ent.components.container ~= nil and
            table.contains(ALLOWED_CONTAINER_TYPES, ent.components.container.type) and
            (ent.components.container.canbeopened or ent.components.container.canacceptgivenitems) and -- NOTES(JBK): canacceptgivenitems is a mod flag for now.
            ent:IsOnPassablePoint() and
            ent:GetCurrentPlatform() == platform
        then
            table.insert(validchests, ent)
        end
    end
    -- First loop try to find chests that have items already in Woby to deliver.
    for _, ent in ipairs(validchests) do
        local stacksize = item.components.stackable and item.components.stackable.stacksize or 1
        if item and ent.components.container:Has(item.prefab, 1) and ent.components.container:CanAcceptCount(item) >= stacksize then
            return ent
        end
    end
    -- Second loop try to find chests that have space for anything left.
    for _, ent in ipairs(validchests) do
        local stacksize = item.components.stackable and item.components.stackable.stacksize or 1
        if item and ent.components.container:CanAcceptCount(item) >= stacksize then
            return ent
        end
    end
end

--------------------------------------------------------------------------

local function RestrictContainer(inst, restrict)
	if restrict then
		if inst._playerlink and inst.components.container.restrictedtag == nil then
			local tag = "wobybag"..tostring(inst._playerlink.GUID)
			inst._playerlink:AddTag(tag)
			inst.components.container.restrictedtag = tag
			for k in pairs(inst.components.container.openlist) do
				if not k:HasTag(tag) then
					inst.components.container:Close(k)
				end
			end
		end
	elseif inst.components.container.restrictedtag then
		--valid check because might be calling from player removal
		if inst._playerlink and inst._playerlink:IsValid() then
			inst._playerlink:RemoveTag(inst.components.container.restrictedtag)
		end
		inst.components.container.restrictedtag = nil
	end
end

--------------------------------------------------------------------------

local RESKIN_MUST_HAVE_LUNAR = {"_lunar",}
local RESKIN_MUST_HAVE_SHADOW = {"_shadow",}
local RESKIN_MUST_NOT_HAVE_LUNARSHADOW = {"_lunar", "_shadow",}
local function ReskinToolFilterFn(inst)
    local build = inst.AnimState:GetBuild()
    local must_have, must_not_have
    if build:find("_lunar") then
        return RESKIN_MUST_HAVE_LUNAR, nil
    elseif build:find("_shadow") then
        return RESKIN_MUST_HAVE_SHADOW, nil
    end
    return nil, RESKIN_MUST_NOT_HAVE_LUNARSHADOW
end

--------------------------------------------------------------------------

local function DoAlignSfx(inst, sound)
	local target = inst.components.rideable and inst.components.rideable:GetRider() or inst
	if target.SoundEmitter then
		target.SoundEmitter:PlaySound(sound)
	end
end

local function ApplyLunarAlignAddColour(target, c)
	if target.components.colouradder then
		if c > 0 then
			target.components.colouradder:PushColour("wobylunaralignfade", c, c, c, 0)
		else
			target.components.colouradder:PopColour("wobylunaralignfade")
		end
	else
		target.AnimState:SetAddColour(c, c, c, 0)
	end
end

local function UpdateLunarAlignFade(inst)
	local target = inst.components.rideable and inst.components.rideable:GetRider() or inst
	if target ~= inst._alignfadetask.target then
		ApplyLunarAlignAddColour(inst._alignfadetask.target, 0)
		inst._alignfadetask.target = target
	end
	local fade = inst._alignfadetask.fade + 1
	if fade < 15 then
		inst._alignfadetask.fade = fade
		fade = fade / 15
		ApplyLunarAlignAddColour(target, 1 - fade * fade)
	else
		ApplyLunarAlignAddColour(target, 0)
		inst._alignfadetask:Cancel()
		inst._alignfadetask = nil
	end
end

local function DoLunarAlignFx(inst)
	inst:DoTaskInTime(0, DoAlignSfx, "meta5/woby/woby_transform_lunar")
	if inst._alignfadetask then
		inst._alignfadetask:Cancel()
		inst:RemoveTag("woby_align_fade")
	end
	inst._alignfadetask = inst:DoPeriodicTask(0, UpdateLunarAlignFade)
	inst._alignfadetask.fade = 0
	inst._alignfadetask.target = inst.components.rideable and inst.components.rideable:GetRider() or inst
	ApplyLunarAlignAddColour(inst._alignfadetask.target, 1)
end

local function ApplyShadowAlignMultColour(target, c)
	if c < 1 then
		target:AddTag("woby_align_fade") --syncs multcolour to rack attachment
	else
		target:RemoveTag("woby_align_fade")
	end
	target.AnimState:SetMultColour(c, c, c, 1)
end

local function UpdateShadowAlignFade(inst)
	local target = inst.components.rideable and inst.components.rideable:GetRider() or inst
	if target ~= inst._alignfadetask.target then
		ApplyShadowAlignMultColour(inst._alignfadetask.target, 1)
		inst._alignfadetask.target = target
	end
	local fade = inst._alignfadetask.fade + 1
	if fade < 15 then
		inst._alignfadetask.fade = fade
		fade = fade / 15
		ApplyShadowAlignMultColour(target, fade * fade)
	else
		ApplyShadowAlignMultColour(target, 1)
		inst._alignfadetask:Cancel()
		inst._alignfadetask = nil
	end
end

local function DoShadowAlignFx(inst)
	inst:DoTaskInTime(0, DoAlignSfx, "meta5/woby/woby_transform_shadow")
	if inst._alignfadetask then
		inst._alignfadetask:Cancel()
	end
	inst._alignfadetask = inst:DoPeriodicTask(0, UpdateShadowAlignFade)
	inst._alignfadetask.fade = 0
	inst._alignfadetask.target = inst.components.rideable and inst.components.rideable:GetRider() or inst
	ApplyShadowAlignMultColour(inst._alignfadetask.target, 0)
end

--------------------------------------------------------------------------

return
{
	FLAGBITS = FLAGBITS,
	SMALL_SYMBOLS = SMALL_SYMBOLS,
	BIG_SYMBOLS = BIG_SYMBOLS,
	COMMAND_NAMES = COMMAND_NAMES,
	COMMANDS = COMMANDS,
	SetupCommandWheel = SetupCommandWheel,
	SetupClientCommandWheelRefreshers = SetupClientCommandWheelRefreshers,
	RefreshCommands = RefreshCommands,
	MakeWobyCommand = MakeWobyCommand,
	MakeAutocastToggle = MakeAutocastToggle,
	SetupMouseOver = SetupMouseOver,
    WobyCourier_ForceDelivery = WobyCourier_ForceDelivery,
    WobyCourier_FindValidContainerForItem = WobyCourier_FindValidContainerForItem,
	RestrictContainer = RestrictContainer,
    ReskinToolFilterFn = ReskinToolFilterFn,
	DoLunarAlignFx = DoLunarAlignFx,
	DoShadowAlignFx = DoShadowAlignFx,
}
