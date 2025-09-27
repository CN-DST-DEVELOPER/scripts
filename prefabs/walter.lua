local MakePlayerCharacter = require("prefabs/player_common")
local SourceModifierList = require("util/sourcemodifierlist")
local WobyCommon = require("prefabs/wobycommon")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
	Asset("ANIM", "anim/status_woby.zip"),
    Asset("ANIM", "anim/player_idles_walter.zip"),
	Asset("ANIM", "anim/walter_storytelling.zip"),
	Asset("ANIM", "anim/walter_whistle.zip"),
    Asset("SOUND", "sound/walter.fsb"),

    Asset("SCRIPT", "scripts/prefabs/skilltree_walter.lua"),
	Asset("SCRIPT", "scripts/prefabs/wobycommon.lua"),
    Asset("ANIM", "anim/courier_minimap_indicator.zip"), -- Courier skill.
	Asset("ANIM", "anim/wobycourier_marker.zip"),
}

local prefabs =
{
    "wobybig",
    "wobysmall",
	"walter_campfire_story_proxy",
    "portabletent",
    "portabletent_item",
	"slingshot_powerup_fx",
	"slingshot_powerup_mounted_fx",
    "wobycourier_marker",
    "reticuleaoeping_1d2_12",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.WALTER
end

prefabs = FlattenTree({ prefabs, start_inv }, true)

local EMPTY_TABLE = {}

--------------------------------------------------------------------------
--Mounted command wheel

local ICON_SCALE = 0.6
local ICON_RADIUS = 60
local SPELLBOOK_RADIUS = 120
local SPELLBOOK_FOCUS_RADIUS = SPELLBOOK_RADIUS-- + 2

local function DoSpellAction(inst)
	local inventory = ThePlayer.replica.inventory
	if inventory then
		inventory:CastSpellBookFromInv(inst)
	end
end

local BLANK_SPELL =
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
}

local SPACER_SPELL = shallowcopy(BLANK_SPELL)
SPACER_SPELL.spacer = true

local SPELLS_RIGHT =
{
	{
		label = STRINGS.ACTIONS.DISMOUNT,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.ACTIONS.DISMOUNT)
			inst.components.spellbook:SetSpellAction(ACTIONS.DISMOUNT)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = DoSpellAction,
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "dismount" },
			focus = { anim = "dismount_focus" },
			down = { anim = "dismount_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = WobyCommon.SetupMouseOver,
		default_focus = true,
	},
	{
		label = STRINGS.ACTIONS.RUMMAGE.GENERIC,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.ACTIONS.RUMMAGE.GENERIC)
			inst.components.spellbook:SetSpellAction(ACTIONS.RUMMAGE)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = DoSpellAction,
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "opencontainer" },
			focus = { anim = "opencontainer_focus" },
			down = { anim = "opencontainer_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = WobyCommon.SetupMouseOver,
	},
	BLANK_SPELL,
	{
		label = STRINGS.WOBY_COMMANDS.SHRINK,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SHRINK)
			inst.components.spellbook:SetSpellAction(nil)
			inst.components.spellbook.closeonexecute = true
		end,
		execute = WobyCommon.MakeWobyCommand(WobyCommon.COMMANDS.SHRINK),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "forcetransform" },
			focus = { anim = "forcetransform_focus" },
			down = { anim = "forcetransform_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = WobyCommon.SetupMouseOver,
	},
}

local SPELLS_LEFT =
{
	{
		label = STRINGS.WOBY_COMMANDS.SPRINTING,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SPRINTING)
			inst.components.spellbook:SetSpellAction(nil)
			inst.components.spellbook.closeonexecute = false
		end,
		execute = WobyCommon.MakeWobyCommand(WobyCommon.COMMANDS.SPRINTING),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "sprinting" },
			focus = { anim = "sprinting_focus" },
			down = { anim = "sprinting_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = WobyCommon.MakeAutocastToggle("sprinting"),
		skill = "walter_woby_sprint",
	},
	{
		label = STRINGS.WOBY_COMMANDS.SHADOWDASH,
		onselect = function(inst)
			inst.components.spellbook:SetSpellName(STRINGS.WOBY_COMMANDS.SHADOWDASH)
			inst.components.spellbook:SetSpellAction(nil)
			inst.components.spellbook.closeonexecute = false
		end,
		execute = WobyCommon.MakeWobyCommand(WobyCommon.COMMANDS.SHADOWDASH),
		bank = "spell_icons_woby",
		build = "spell_icons_woby",
		anims =
		{
			idle = { anim = "shadowdash" },
			focus = { anim = "shadowdash_focus" },
			down = { anim = "shadowdash_pressed" },
		},
		widget_scale = ICON_SCALE,
		postinit = WobyCommon.MakeAutocastToggle("shadowdash"),
		skill = "walter_woby_shadow",
	},
}

local SPELLBOOK_BG =
{
	bank = "spell_icons_woby",
	build = "spell_icons_woby",
	anim = "bg",
	widget_scale = ICON_SCALE,
}

local function RefreshSpells(inst)
	local skilltreeupdater = inst.components.skilltreeupdater
	local j = 1

	inst._spells[1] = SPACER_SPELL
	j = j + 1

	for i, v in ipairs(SPELLS_RIGHT) do
		if v.skill == nil or skilltreeupdater:IsActivated(v.skill) then
			inst._spells[j] = v
		else
			inst._spells[j] = BLANK_SPELL
		end
		j = j + 1
	end

	for i = j, 5 do
		inst._spells[j] = BLANK_SPELL
		j = j + 1
	end

	inst._spells[j] = SPACER_SPELL
	j = j + 1

	for i, v in ipairs(SPELLS_LEFT) do
		if v.skill == nil or skilltreeupdater:IsActivated(v.skill) then
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
			inst._spells[i] = BLANK_SPELL
		end
	end
end

local function EnableMountedCommands(inst, enable)
	if enable then
		inst.components.spellbook:SetItems(inst._spells)
	else
		if inst.HUD and inst.HUD:GetCurrentOpenSpellBook() == inst then
			inst.HUD:CloseSpellWheel()
		end
		inst.components.spellbook:SetItems(EMPTY_TABLE)
	end
end

local function DoUpdateMountCommandsTask(inst)
	inst._updatemountcommandstask = nil
	local rider = inst.replica.rider
	local mount = rider and rider:GetMount() or nil
	EnableMountedCommands(inst, mount ~= nil and mount:HasTag("woby"))
end

local function OnIsRiding_Client(inst)
	--V2C: mount is classified whereas isriding is not, so they will not sync at the same time
	if inst._updatemountcommandstask then
		inst._updatemountcommandstask:Cancel()
		inst._updatemountcommandstask = nil
	end
	if inst.replica.rider:IsRiding() then
		inst._updatemountcommandstask = inst:DoStaticTaskInTime(0, DoUpdateMountCommandsTask)
	else
		EnableMountedCommands(inst, false)
	end
end

local function ShouldOpenWobyCommands(inst, user)
	return user.woby_commands_classified and not user.woby_commands_classified:IsBusy()
end

local function OnSkillTreeInitialized_RefreshSpells(inst)
	inst:RemoveEventCallback(TheWorld.ismastersim and "ms_skilltreeinitialized" or "skilltreeinitialized_client", OnSkillTreeInitialized_RefreshSpells)
	RefreshSpells(inst)
end

local function SetupMountedCommandWheel(inst)
	inst._spells = {}

	inst:AddComponent("spellbook")
	inst.components.spellbook:SetRadius(SPELLBOOK_RADIUS)
	inst.components.spellbook:SetFocusRadius(SPELLBOOK_FOCUS_RADIUS)
	inst.components.spellbook:SetShouldOpenFn(ShouldOpenWobyCommands)
	inst.components.spellbook:SetItems(EMPTY_TABLE)
	inst.components.spellbook:SetBgData(SPELLBOOK_BG)
	inst.components.spellbook.opensound = "meta5/woby/bigwoby_actionwheel_UI"
	--inst.components.spellbook.closesound = "meta5/woby/bigwoby_actionwheel_UI"
	--inst.components.spellbook.executesound = "meta4/winona_UI/select"	--use .clicksound for item buttons instead
	--inst.components.spellbook.focussound = "meta4/winona_UI/hover"

	if TheWorld.ismastersim then
		inst:ListenForEvent("onactivateskill_server", RefreshSpells)
		inst:ListenForEvent("ondeactivateskill_server", RefreshSpells)
		if inst._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
			RefreshSpells(inst)
		else
			inst:ListenForEvent("ms_skilltreeinitialized", OnSkillTreeInitialized_RefreshSpells)
		end
	else
		inst:ListenForEvent("isridingdirty", OnIsRiding_Client)
		inst:ListenForEvent("onactivateskill_client", RefreshSpells)
		inst:ListenForEvent("ondeactivateskill_client", RefreshSpells)
		if inst._PostActivateHandshakeState_Client == POSTACTIVATEHANDSHAKE.READY then
			RefreshSpells(inst)
		else
			inst:ListenForEvent("skilltreeinitialized_client", OnSkillTreeInitialized_RefreshSpells)
		end
	end
end

local function GetLinkedSpellBook(inst)
	local woby = inst.woby_commands_classified and inst.woby_commands_classified:GetWoby() or nil
	return woby and not woby:HasTag("INLIMBO") and woby or nil
end

--------------------------------------------------------------------------

--pos: double click coords; nil when double tapping direction instead of mouse
--dir: WASD/analog dir; nil if neutral (NOTE: this may be in a different direction than pos!)
--target: double click mouseover target; nil when tapping direction instead of mouse
--remote: only pos2 is sent to server, similar to actions that are aimed toward reticule pos
local function GetDoubleClickActions(inst, pos, dir, target)
	--Assumes we can only ride our own woby!
	if not inst.components.skilltreeupdater:IsActivated("walter_woby_dash") then
		return EMPTY_TABLE
	end
	local rider = inst.replica.rider
	local mount = rider and rider:GetMount() or nil
	if mount and mount:HasTag("woby") then
		local pos2
		if dir then
			pos2 = inst:GetPosition()
			pos2.x = pos2.x + dir.x * 10
			pos2.y = 0
			pos2.z = pos2.z + dir.z * 10
		elseif target then
			pos2 = target:GetPosition()
			pos2.y = 0
		end
		return { ACTIONS.DASH }, pos2
	end
	return EMPTY_TABLE
end

local function HasWhistleAction(inst)
	if inst.woby_commands_classified then
		if inst.woby_commands_classified:IsOutForDelivery() then
			--Going to dest, or putting items into boxes
			--Command wheel is blocked, so no range on recall action
			return true
		end
		local woby = inst.woby_commands_classified:GetWoby()
		if TheWorld.ismastersim then
			if woby and not (inst.HUD and not woby:IsInLimbo() and woby:IsNear(inst, 16)) then
				return true
			end
		elseif inst.HUD and (woby == nil or woby:HasTag("INLIMBO") or not woby:IsNear(inst, 16)) then
			return true
		end
	end
	return false
end

local function GetPointSpecialActions(inst, pos, useitem, right, usereticulepos)
	if right and
		useitem == nil and
		inst.components.playercontroller and
		inst.components.playercontroller.isclientcontrollerattached and
		HasWhistleAction(inst)
	then
		return { ACTIONS.WHISTLE }
	end
	return {}
end

local function OnSetOwner(inst)
	if inst.components.playeractionpicker then
		inst.components.playeractionpicker.doubleclickactionsfn = GetDoubleClickActions
		inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
	end
end

--------------------------------------------------------------------------

local function FadeOutBanner(inst, dt)
	if inst.delay > dt then
		inst.delay = inst.delay - dt
	elseif inst.fadetime > dt then
		if inst.delay >= 0 then
			TheFocalPoint.components.focalpoint:StopFocusSource(inst)
			inst.delay = -1
		end
		inst.fadetime = inst.fadetime - dt
		local k = 1 - inst.fadetime / 0.5
		k = 1 - k * k
		inst.AnimState:SetMultColour(1, 1, 1, k)
	else
		inst:Remove()
	end
end

local function DoBannerSound(inst, sound)
	inst.SoundEmitter:PlaySound(sound)
end

local function CreateWobyCourierBanner()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	inst.AnimState:SetBank("wobycourier_marker")
	inst.AnimState:SetBuild("wobycourier_marker")
	inst.AnimState:PlayAnimation("place")

	return inst
end

local function OnUpdateWobyCourierChestIcon(inst)
    local x, z = GetWobyCourierChestPosition(inst)
    if not x then
        if inst.wobycourier_chesticon_CLIENT then
            if inst.wobycourier_chesticon_CLIENT:IsValid() then
                inst.wobycourier_chesticon_CLIENT:Remove()
            end
            inst.wobycourier_chesticon_CLIENT = nil
        end
        return
    end

    if inst.wobycourier_chesticon_CLIENT == nil or not inst.wobycourier_chesticon_CLIENT:IsValid() then
        inst.wobycourier_chesticon_CLIENT = SpawnPrefab("wobycourier_marker")
        inst.wobycourier_chesticon_CLIENT:ListenForEvent("onremove", function()
            inst.wobycourier_chesticon_CLIENT:Remove()
            inst.wobycourier_chesticon_CLIENT = nil
        end, inst)
    end

    -- Update the icon.
    inst.wobycourier_chesticon_CLIENT.Transform:SetPosition(x, 0, z)

	if inst.showchestbanner then
		inst.showchestbanner = nil
		if inst._tempfocus then
			inst._tempfocus:Remove()
			inst._tempfocus = nil
		end

		-- Ping the location.
		local ping = SpawnPrefab("reticuleaoeping_1d2_12")
		ping.Transform:SetPosition(x, 0, z)

		local banner = CreateWobyCourierBanner()
		banner.Transform:SetPosition(x, 0, z)
		banner.AnimState:SetSortOrder(1)
		banner.AnimState:Hide("shadow")

		local bshadow = CreateWobyCourierBanner()
		bshadow.entity:SetParent(banner.entity)
		bshadow.AnimState:Hide("flag_parts")
		bshadow.AnimState:Hide("smoke")

		DoBannerSound(banner, "dontstarve/common/deathpoof")
		TheFocalPoint.components.focalpoint:StartFocusSource(banner, nil, nil, math.huge, math.huge, 10)
		banner:DoTaskInTime(26 * FRAMES, DoBannerSound, "dontstarve/common/plant")

		banner:AddComponent("updatelooper")
		banner.components.updatelooper:AddOnUpdateFn(FadeOutBanner)
		banner.delay = banner.AnimState:GetCurrentAnimationLength() + 0.25
		banner.fadetime = 0.5
	end
end

local function CancelTempFocusRememberChest(inst)
	inst.showchestbanner = nil
	if inst._tempfocus then
		inst._tempfocus.task:Cancel()
		inst._tempfocus:Remove()
		inst._tempfocus = nil
	end
end

local function TempFocusRememberChest(inst, x, z)
	inst.showchestbanner = true

	if not TheWorld.ismastersim then
		if inst._tempfocus == nil then
			inst._tempfocus = CreateEntity()
			inst._tempfocus:AddTag("CLASSIFIED")
			--[[Non-networked entity]]
			--inst._tempfocus.entity:SetCanSleep(false)
			inst._tempfocus.persists = false
			inst._tempfocus.entity:AddTransform()
			TheFocalPoint.components.focalpoint:StartFocusSource(inst._tempfocus, nil, nil, math.huge, math.huge, 10)
			inst._tempfocus:ListenForEvent("onremove", CancelTempFocusRememberChest, inst)
		else
			inst._tempfocus.task:Cancel()
		end
		inst._tempfocus.Transform:SetPosition(x, 0, z)
		inst._tempfocus.task = inst:DoTaskInTime(2, CancelTempFocusRememberChest)
	end
end

local function StoryTellingDone(inst, story)
	if inst._story_proxy ~= nil and inst._story_proxy:IsValid() then
		inst._story_proxy:Remove()
		inst._story_proxy = nil
	end
    if inst.sg and inst.sg.currentstate.name == "dostorytelling" then -- NOTES(JBK): Workaround for stategraph handling to go to _pst.
        inst.sg.statemem.started = true
    end
end

local function StoryToTellFn(inst, story_prop)
	if not TheWorld.state.isnight then
		return "NOT_NIGHT"
	end

	local fueled = story_prop ~= nil and story_prop.components.fueled or nil
	if fueled ~= nil and story_prop:HasTag("campfire") then
		if fueled:IsEmpty() then
			return "NO_FIRE"
		end

		local campfire_stories = STRINGS.STORYTELLER.WALTER["CAMPFIRE"]
		if campfire_stories ~= nil then
			if inst._story_proxy ~= nil then
				inst._story_proxy:Remove()
				inst._story_proxy = nil
			end
			inst._story_proxy = SpawnPrefab("walter_campfire_story_proxy")
			inst._story_proxy:Setup(inst, story_prop)

			local story_id = GetRandomKey(campfire_stories)
			return { style = "CAMPFIRE", id = story_id, lines = campfire_stories[story_id].lines }
		end
	end

	return nil
end

local function OnHealthDelta(inst, data)
    if data.amount < 0 then
		local overtime = data and data.overtime or nil
		inst.components.sanity:DoDelta(data.amount * (overtime and TUNING.WALTER_SANITY_DAMAGE_OVERTIME_RATE or TUNING.WALTER_SANITY_DAMAGE_RATE) * inst._sanity_damage_protection:Get(), overtime)
    end
end

local function startsong(inst)
	inst:RemoveEventCallback("animqueueover", startsong)
	if inst.AnimState:AnimDone() then
		inst:PushEvent("singsong", {sound = "dontstarve/characters/walter/song", lines = STRINGS.SONGS.WALTER_GLOMMER_GUTS.lines})
	end
end

local function oneat(inst, food)
	if food ~= nil and food:IsValid() and (food.prefab == "glommerfuel" or food:HasTag("tallbirdegg")) then
        inst:ListenForEvent("animqueueover", startsong)
	end
end

local REQUIRED_TREE_TAGS = { "tree" }
local EXCLUDE_TREE_TAGS = { "burnt", "stump", "fire" }

local function UpdateTreeSanityGain(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local num_trees = #TheSim:FindEntities(x, y, z, TUNING.WALTER_TREE_SANITY_RADIUS, REQUIRED_TREE_TAGS, EXCLUDE_TREE_TAGS)
    inst._tree_sanity_gain = num_trees >= TUNING.WALTER_TREE_SANITY_THRESHOLD and TUNING.WALTER_TREE_SANITY_BONUS or 0
end

local function CustomSanityFn(inst, dt)
    local health_drain = (1 - inst.components.health:GetPercentWithPenalty()) * TUNING.WALTER_SANITY_HEALTH_DRAIN * inst._sanity_damage_protection:Get()

    return inst._tree_sanity_gain - health_drain
end

local function SpawnWoby(inst)
    local player_check_distance = 40
    local attempts = 0

    local max_attempts = 30
    local x, y, z = inst.Transform:GetWorldPosition()

    local woby = SpawnPrefab(TUNING.WALTER_STARTING_WOBY)
	inst.woby = woby
	woby:LinkToPlayer(inst)
    inst:ListenForEvent("onremove", inst._woby_onremove, woby)

    while true do
        local offset = FindWalkableOffset(inst:GetPosition(), math.random() * PI, player_check_distance + 1, 10)

        if offset then
            local spawn_x = x + offset.x
            local spawn_z = z + offset.z

            if attempts >= max_attempts then
                woby.Transform:SetPosition(spawn_x, y, spawn_z)
                break
            elseif not IsAnyPlayerInRange(spawn_x, 0, spawn_z, player_check_distance) then
                woby.Transform:SetPosition(spawn_x, y, spawn_z)
                break
            else
                attempts = attempts + 1
            end
        elseif attempts >= max_attempts then
            woby.Transform:SetPosition(x, y, z)
            break
        else
            attempts = attempts + 1
        end
    end

    return woby
end

local function ResetOrStartWobyBuckTimer(inst)
	if inst.components.timer:TimerExists("wobybuck") then
		inst.components.timer:SetTimeLeft("wobybuck", TUNING.WALTER_WOBYBUCK_DECAY_TIME)
	else
		inst.components.timer:StartTimer("wobybuck", TUNING.WALTER_WOBYBUCK_DECAY_TIME)
	end
end

local function OnTimerDone(inst, data)
	if data and data.name == "wobybuck" then
		inst._wobybuck_damage = 0
	end
end

local function OnAttacked(inst, data)
    if not inst.components.rider:IsRiding() then
		return
	end

	local mount = inst.components.rider:GetMount()

	if not mount:HasTag("woby") then
		return
	end

	local damage = data and data.damage or TUNING.WALTER_WOBYBUCK_DAMAGE_MAX * 0.5 -- Fallback in case of mods.

	inst._wobybuck_damage = inst._wobybuck_damage + damage
	if inst._wobybuck_damage >= TUNING.WALTER_WOBYBUCK_DAMAGE_MAX then
		inst.components.timer:StopTimer("wobybuck")
		inst._wobybuck_damage = 0

		mount.components.rideable:Buck()
	else
		ResetOrStartWobyBuckTimer(inst)
	end
end

local function OnMounted(inst, data)
	if data.target == nil or not data.target:HasTag("woby") then
		EnableMountedCommands(inst, false)
		return
	end
	--riding woby!
	inst.components.temperature.inherentinsulation = TUNING.INSULATION_MED_LARGE

	EnableMountedCommands(inst, true)
end

local function OnDismounted(inst, data)
	EnableMountedCommands(inst, false)

	inst.components.temperature.inherentinsulation = 0

	if inst.components.sanity ~= nil then
		inst.components.sanity.externalmodifiers:RemoveModifier(data.target)
	end
end

local function OnWobyTransformed(inst, woby)
	if inst.woby ~= nil then
		inst:RemoveEventCallback("onremove", inst._woby_onremove, inst.woby)
	end

	inst.woby = woby
	inst:ListenForEvent("onremove", inst._woby_onremove, woby)
end

local function OnWobyRemoved(inst)
	inst.woby = nil
	inst._replacewobytask = inst:DoTaskInTime(1, function(i) i._replacewobytask = nil if i.woby == nil then SpawnWoby(i) end end)
end

local function OnRemoveEntity(inst)
	-- hack to remove pets when spawned due to session state reconstruction for autosave snapshots
	if inst.woby ~= nil and inst.woby.spawntime == GetTime() then
		inst:RemoveEventCallback("onremove", inst._woby_onremove, inst.woby)
		inst.woby:Remove()
	end

	if inst._story_proxy ~= nil and inst._story_proxy:IsValid() then
		inst._story_proxy:Remove()
	end
end

local function OnDespawn(inst)
    if inst.woby ~= nil then
		inst.woby:OnPlayerLinkDespawn()
        inst.woby:PushEvent("player_despawn")
    end
end

local function OnReroll(inst)
    if inst.woby ~= nil then
		inst.woby:OnPlayerLinkDespawn(true)
    end
end

local function OnSave(inst, data)
	if inst.woby then
		data.woby = inst.woby:GetSaveRecord()
	else
		data.baglock = inst.baglock
	end
	data.buckdamage = inst._wobybuck_damage > 0 and inst._wobybuck_damage or nil
	data.wobycmd = inst.woby_commands_classified and inst.woby_commands_classified:OnSave() or nil
end

local function OnLoad(inst, data)
	if data ~= nil then
		if data.woby ~= nil then
			inst._woby_spawntask:Cancel()
			inst._woby_spawntask = nil

			local woby = SpawnSaveRecord(data.woby)
			inst.woby = woby
			if woby ~= nil then
				if inst.migrationpets ~= nil then
					table.insert(inst.migrationpets, woby)
					if data.wobycmd then
						data.wobycmd.sit = nil
					end
				end
				woby:LinkToPlayer(inst)
				if inst.woby_commands_classified then
					inst.woby_commands_classified:OnLoad(data.wobycmd)
				end

				woby.AnimState:SetMultColour(0,0,0,1)
				woby.components.colourtweener:StartTween({1,1,1,1}, 19*FRAMES)
				local fx = SpawnPrefab(woby.spawnfx)
				fx.entity:SetParent(woby.entity)

				inst:ListenForEvent("onremove", inst._woby_onremove, woby)
			end
		else
			inst.baglock = data.baglock
		end
		inst._wobybuck_damage = data.buckdamage or 0
	end
end

local function GetEquippableDapperness(owner, equippable)
	if equippable.is_magic_dapperness then
		return equippable:GetDapperness(owner, owner.components.sanity.no_moisture_penalty)
	end

	return 0
end

local UNLOCKABLE_STATION_RECIPES = {
	["walter_ammo_shattershots"] = {
        "slingshotammo_stinger",
        "slingshotammo_moonglass",
    },
	["walter_ammo_lunar"] = {
        "slingshotammo_lunarplanthusk",
        "slingshotammo_purebrilliance",
    },
	["walter_ammo_shadow"] = {
        "slingshotammo_gelblob",
        "slingshotammo_horrorfuel",
    },
	["walter_slingshot_frames"] = {
        "slingshot_frame_gems",
        "slingshot_frame_wagpunk",
    },
	["walter_slingshot_handles"] =	{
        "slingshot_handle_voidcloth",
    },
}

local function OnDeactivateSkill(inst, data)
	if data then
		local recipelist = UNLOCKABLE_STATION_RECIPES[data.skill]
		if recipelist then
			for _, recipename in ipairs(recipelist) do
				inst.components.builder:RemoveRecipe(recipename)
			end
		end
	end
end

local function OnSkillTreeInitialized(inst)
	local skilltreeupdater = inst.components.skilltreeupdater
	for skill, recipelist in pairs(UNLOCKABLE_STATION_RECIPES) do
		if not (skilltreeupdater and skilltreeupdater:IsActivated(skill)) then
			for _, recipename in ipairs(recipelist) do
				inst.components.builder:RemoveRecipe(recipename)
			end
		end
	end
end

--------------------------------------------------------------------------

local SPRINT_TRAIL_SOUND_POOL = {}
local SPRINT_TRAIL_SOUND_COUNT = 0 --live count, excludes ones in pool
local SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK = nil

local function IncSprintTrailSound()
	if SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK then
		SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK:Cancel()
		SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK = nil
	end
	SPRINT_TRAIL_SOUND_COUNT = SPRINT_TRAIL_SOUND_COUNT + 1
end

local function DumpSprintTrailSoundPool()
	for i = 1, #SPRINT_TRAIL_SOUND_POOL do
		SPRINT_TRAIL_SOUND_POOL[i]:Remove()
		SPRINT_TRAIL_SOUND_POOL[i] = nil
	end
end

local function DecSprintTrailSound()
	SPRINT_TRAIL_SOUND_COUNT = SPRINT_TRAIL_SOUND_COUNT - 1
	if SPRINT_TRAIL_SOUND_COUNT <= 0 then
		if SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK == nil then
			SPRINT_TRAIL_SOUND_POOL_CLEANUP_TASK = TheWorld:DoTaskInTime(30, DumpSprintTrailSoundPool)
		else
			assert(false) --sanity check
		end
	end
end

local function CreateSprintTrailSound()
	local fx = CreateEntity()

	fx:AddTag("CLASSIFIED")

	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddSoundEmitter()
	fx:Hide()

	return fx
end

local function GetSprintTrailSound()
	local fx = table.remove(SPRINT_TRAIL_SOUND_POOL)
	if fx then
		fx:ReturnToScene()
	else
		fx = CreateSprintTrailSound()
	end

	fx.OnRemoveEntity = DecSprintTrailSound --This is just in case somehow something else removes us
	IncSprintTrailSound()

	return fx
end

local function RecycleSprintTrailSound(fx)
	fx.SoundEmitter:KillSound("loop")
	fx.entity:SetParent(nil)
	fx.OnRemoveEntity = nil
	fx:RemoveFromScene()
	table.insert(SPRINT_TRAIL_SOUND_POOL, fx)
	DecSprintTrailSound()
end

--------------------------------------------------------------------------

local SPRINT_TRAIL_FX_POOL = {}
local SPRINT_TRAIL_FX_COUNT = 0 --live count, excludes ones in pool
local SPRINT_TRAIL_FX_POOL_CLEANUP_TASK = nil

local function IncSprintTrailFx()
	if SPRINT_TRAIL_FX_POOL_CLEANUP_TASK then
		SPRINT_TRAIL_FX_POOL_CLEANUP_TASK:Cancel()
		SPRINT_TRAIL_FX_POOL_CLEANUP_TASK = nil
	end
	SPRINT_TRAIL_FX_COUNT = SPRINT_TRAIL_FX_COUNT + 1
end

local function DumpSprintTrailFxPool()
	for i = 1, #SPRINT_TRAIL_FX_POOL do
		SPRINT_TRAIL_FX_POOL[i]:Remove()
		SPRINT_TRAIL_FX_POOL[i] = nil
	end
end

local function DecSprintTrailFx()
	SPRINT_TRAIL_FX_COUNT = SPRINT_TRAIL_FX_COUNT - 1
	if SPRINT_TRAIL_FX_COUNT <= 0 then
		if SPRINT_TRAIL_FX_POOL_CLEANUP_TASK == nil then
			SPRINT_TRAIL_FX_POOL_CLEANUP_TASK = TheWorld:DoTaskInTime(30, DumpSprintTrailFxPool)
		else
			assert(false) --sanity check
		end
	end
end

local function CreateSprintTrailFx()
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.Transform:SetSixFaced()

	fx.AnimState:SetBank("wilsonbeefalo")
	fx.AnimState:SetBuild("woby_big_build")
	fx.AnimState:AddOverrideBuild("woby_big_lunar_build")
	fx.AnimState:SetAddColour(1, 1, 1, 0)
	fx.AnimState:UsePointFiltering(true)

	fx:AddComponent("updatelooper")

	return fx
end

local function GetSprintTrailFx()
	local fx = table.remove(SPRINT_TRAIL_FX_POOL)
	if fx then
		fx:ReturnToScene()
	else
		fx = CreateSprintTrailFx()
	end

	--Reset the entity
	fx.a = nil
	fx:Hide()

	fx.OnRemoveEntity = DecSprintTrailFx --This is just in case somehow something else removes us
	IncSprintTrailFx()

	return fx
end

--------------------------------------------------------------------------

--V2C: Keeping it parented is the only way to guarantee the facing matches.
local function SprintTrailFx_PostUpdate(fx)
	local inst = fx.entity:GetParent()
	if inst then
		fx.Transform:SetPosition(inst.entity:WorldToLocalSpace(fx.x, fx.y, fx.z))
		fx.Transform:SetRotation(fx.rot - inst.Transform:GetRotation())
		fx.AnimState:MakeFacingDirty()
	end
end

local TRAIL_LENGTH = 7
local TRAIL_ALPHA = 0.1
local TRAIL_FADE_DELTA = TRAIL_ALPHA / TRAIL_LENGTH
local function SprintTrailFx_OnUpdate(fx)
	if fx.a == nil then
		fx.a = TRAIL_ALPHA
		fx:Show()
	else
		fx.a = fx.a - TRAIL_FADE_DELTA
	end
	if fx.a > 0 then
		fx.AnimState:SetMultColour(1, 1, 1, fx.a)
	else
		--Return to pool
		fx.components.updatelooper:RemovePostUpdateFn(SprintTrailFx_PostUpdate)
		fx.components.updatelooper:RemoveOnUpdateFn(SprintTrailFx_OnUpdate)
		fx.OnRemoveEntity = nil
		fx:RemoveFromScene()
		table.insert(SPRINT_TRAIL_FX_POOL, fx)
		DecSprintTrailFx()
	end
end

--runs on clients too
local function OnUpdateSprintTrail(inst, dt)
	local anim
	if inst.AnimState:IsCurrentAnimation("sprint_woby_loop") then
		anim = "sprint_woby_loop"
	elseif inst.AnimState:IsCurrentAnimation("dash_woby") then
		anim = "dash_woby"
	elseif inst.AnimState:IsCurrentAnimation("sprint_woby_pst") then
		--only trail at end of dash, not on run stop
		if inst:HasTag("force_sprint_woby") then
			anim = "sprint_woby_pst"
		end
	end

	if anim then
		local fx = GetSprintTrailFx()
		fx.entity:SetParent(inst.entity)
		fx.AnimState:PlayAnimation(anim)
		fx.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
		fx.AnimState:Pause()
		fx.x, fx.y, fx.z = inst.Transform:GetWorldPosition()
		fx.rot = inst.Transform:GetRotation()
		fx.components.updatelooper:AddPostUpdateFn(SprintTrailFx_PostUpdate)
		fx.components.updatelooper:AddOnUpdateFn(SprintTrailFx_OnUpdate)

		if inst._sprinttrailsfx == nil then
			inst._sprinttrailsfx = GetSprintTrailSound()
			inst._sprinttrailsfx.entity:SetParent(inst.entity)
			inst._sprinttrailsfx.SoundEmitter:PlaySound("meta5/woby/sprint_wind_lp", "loop")
		end
	elseif inst._sprinttrailsfx then
		RecycleSprintTrailSound(inst._sprinttrailsfx)
		inst._sprinttrailsfx = nil
	end
end

local function SprintTrail_OnEntitySleep(inst)
	if inst._sprinttrail_onudpate then
		inst._sprinttrail_onudpate = nil
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateSprintTrail)
		if inst._sprinttrailsfx then
			RecycleSprintTrailSound(inst._sprinttrailsfx)
			inst._sprinttrailsfx = nil
		end
	end
end

local function SprintTrail_OnEntityWake(inst)
	if not inst._sprinttrail_onudpate then
		inst._sprinttrail_onudpate = true
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateSprintTrail)
	end
end

local function OnHasSprintTrail(inst)
	if inst._predict_sprint_trail or inst.has_sprint_trail:value() then
		if not inst._updatingsprinttrail then
			if inst.components.updatelooper == nil then
				inst:AddComponent("updatelooper")
			end
			if TheWorld.ismastersim then
				inst:ListenForEvent("entitysleep", SprintTrail_OnEntitySleep)
				inst:ListenForEvent("entitywake", SprintTrail_OnEntityWake)
				if not inst:IsAsleep() then
					SprintTrail_OnEntityWake(inst)
				end
			else
				inst.components.updatelooper:AddOnUpdateFn(OnUpdateSprintTrail)
			end
			inst._updatingsprinttrail = true
		end
	elseif inst._updatingsprinttrail then
		if TheWorld.ismastersim then
			inst:RemoveEventCallback("entitysleep", SprintTrail_OnEntitySleep)
			inst:RemoveEventCallback("entitywake", SprintTrail_OnEntityWake)
			SprintTrail_OnEntitySleep(inst)
		else
			inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateSprintTrail)
			if inst._sprinttrailsfx then
				RecycleSprintTrailSound(inst._sprinttrailsfx)
				inst._sprinttrailsfx = nil
			end
		end
		inst._updatingsprinttrail = false
	end
end

local function OnDisableSprintTask_Server(inst)
	inst._disablesprinttrailtask = nil
	inst.has_sprint_trail:set(false)
	if not TheNet:IsDedicated() then
		OnHasSprintTrail(inst)
	end
end

local function EnableWobySprintTrail_Server(inst, enable)
	if enable then
		if inst._disablesprinttrailtask then
			inst._disablesprinttrailtask:Cancel()
			inst._disablesprinttrailtask = nil
		elseif not inst.has_sprint_trail:value() then
			inst.has_sprint_trail:set(true)
			if not TheNet:IsDedicated() then
				OnHasSprintTrail(inst)
			end
		end
	elseif inst.has_sprint_trail:value() and inst._disablesprinttrailtask == nil then
		inst._disablesprinttrailtask = inst:DoStaticTaskInTime(0, OnDisableSprintTask_Server)
	end
end

--------------------------------------------------------------------------
--For prediction

local function OnDisableSprintTask_Client(inst)
	inst._disablesprinttrailtask = nil
	inst._predict_sprint_trail = false
	OnHasSprintTrail(inst)
end

local function EnableWobySprintTrail_Client(inst, enable)
	if enable then
		if inst._disablesprinttrailtask then
			inst._disablesprinttrailtask:Cancel()
			inst._disablesprinttrailtask = nil
		elseif not inst._predict_sprint_trail then
			inst._predict_sprint_trail = true
			OnHasSprintTrail(inst)
		end
	elseif inst._predict_sprint_trail and inst._disablesprinttrailtask == nil then
		inst._disablesprinttrailtask = inst:DoStaticTaskInTime(0, OnDisableSprintTask_Client)
	end
end

local function OnEnableMovementPrediction_Client(inst, enable)
	if not enable and inst._predict_sprint_trail then
		if inst._disablesprinttrailtask then
			inst._disablesprinttrailtask:Cancel()
			inst._disablesprinttrailtask = nil
		end
		inst._predict_sprint_trail = nil
		OnHasSprintTrail(inst)
	end
end

--------------------------------------------------------------------------

local function common_postinit(inst)
    inst:AddTag("expertchef")
    inst:AddTag("pebblemaker")
    inst:AddTag("pinetreepioneer")
    inst:AddTag("allergictobees")
    inst:AddTag("slingshot_sharpshooter")
    inst:AddTag("dogrider")
    inst:AddTag("nowormholesanityloss")
	inst:AddTag("storyteller") -- for storyteller component

    inst.customidleanim = "idle_walter"

    if TheNet:GetServerGameMode() == "lavaarena" then
        --do nothing
    elseif TheNet:GetServerGameMode() == "quagmire" then
        inst:AddTag("quagmire_shopper")
    end

	inst.has_sprint_trail = net_bool(inst.GUID, "walter.has_sprint_trail", "has_sprint_trail_dirty")

	inst.getlinkedspellbookfn = GetLinkedSpellBook

	SetupMountedCommandWheel(inst)

	inst:ListenForEvent("setowner", OnSetOwner)
    inst:ListenForEvent("updatewobycourierchesticon", OnUpdateWobyCourierChestIcon)

	inst.HasWhistleAction = HasWhistleAction
	inst.TempFocusRememberChest = TempFocusRememberChest
	inst.CancelTempFocusRememberChest = CancelTempFocusRememberChest

	if not TheWorld.ismastersim then
		inst:ListenForEvent("has_sprint_trail_dirty", OnHasSprintTrail)
		inst:ListenForEvent("enablemovementprediction", OnEnableMovementPrediction_Client)
		inst.EnableWobySprintTrail = EnableWobySprintTrail_Client
	end
end

local function master_postinit(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.components.health:SetMaxHealth(TUNING.WALTER_HEALTH)
    inst.components.hunger:SetMax(TUNING.WALTER_HUNGER)
    inst.components.sanity:SetMax(TUNING.WALTER_SANITY)

    inst.components.sanity.custom_rate_fn = CustomSanityFn
    inst.components.sanity:SetNegativeAuraImmunity(true)
    inst.components.sanity:SetPlayerGhostImmunity(true)
    inst.components.sanity:SetLightDrainImmune(true)
	inst.components.sanity.get_equippable_dappernessfn = GetEquippableDapperness
	inst.components.sanity.only_magic_dapperness = true

    inst.components.foodaffinity:AddPrefabAffinity("trailmix", TUNING.AFFINITY_15_CALORIES_SMALL)

	inst.components.eater:SetOnEatFn(oneat)

    inst.components.sleepingbaguser:SetHungerBonusMult(TUNING.EFFICIENT_SLEEP_HUNGER_MULT)

	inst.components.petleash:SetMaxPets(0) -- walter can only have Woby as a pet

	inst:AddComponent("storyteller")
	inst.components.storyteller:SetStoryToTellFn(StoryToTellFn)
	inst.components.storyteller:SetOnStoryOverFn(StoryTellingDone)

    inst:AddComponent("wobycourier")

	inst:ListenForEvent("healthdelta", OnHealthDelta)
    inst:ListenForEvent("attacked", OnAttacked)

	inst._sanity_damage_protection = SourceModifierList(inst)

	inst._tree_sanity_gain = 0
	inst._update_tree_sanity_task = inst:DoPeriodicTask(TUNING.WALTER_TREE_SANITY_UPDATE_TIME, UpdateTreeSanityGain)

	inst._wobybuck_damage = 0
	inst:ListenForEvent("timerdone", OnTimerDone)

	inst._woby_spawntask = inst:DoTaskInTime(0, function(i) i._woby_spawntask = nil SpawnWoby(i) end)
	inst._woby_onremove = function(woby) OnWobyRemoved(inst) end

	inst.baglock = nil --V2C: for remembering woby's baglock setting in case she was despawned (e.g. Wonkey!)

	inst.OnWobyTransformed = OnWobyTransformed
	inst.EnableWobySprintTrail = EnableWobySprintTrail_Server

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
    inst.OnDespawn = OnDespawn
    inst:ListenForEvent("ms_playerreroll", OnReroll)
	inst:ListenForEvent("onremove", OnRemoveEntity)

	inst:ListenForEvent("mounted", OnMounted)
    inst:ListenForEvent("dismounted", OnDismounted)

	inst:ListenForEvent("ondeactivateskill_server", OnDeactivateSkill)
	inst:ListenForEvent("ms_skilltreeinitialized", OnSkillTreeInitialized)
end

-------------------------------------------------------------------------------

local function CampfireStory_OnNotNight(inst, isnight)
	if not isnight and inst.storyteller ~= nil and inst.storyteller:IsValid() and inst.storyteller.components.storyteller ~= nil then
		inst.storyteller.components.storyteller:AbortStory(GetString(inst.storyteller, "ANNOUNCE_STORYTELLING_ABORT_NOT_NIGHT"))
	end
end

local function CampfireStory_CheckFire(inst, data)
	if data ~= nil and data.newsection == 0 and inst.storyteller:IsValid() and inst.components.storyteller ~= nil then
		inst.storyteller.components.storyteller:AbortStory(GetString(inst.storyteller, "ANNOUNCE_STORYTELLING_ABORT_FIREWENTOUT"))
	end
end

local function CampfireStory_aurafallofffn(inst, observer, distsq)
	return 1
end

local function CampfireStory_ActiveFn(params, parent, best_dist_sq)
	local pan_gain, heading_gain, distance_gain = TheCamera:GetGains()
	TheCamera:SetGains(1.5, heading_gain, distance_gain)
    TheCamera:SetDistance(18)
end

local function SetupCampfireStory(inst, storyteller, prop)
	inst.entity:SetParent(prop.entity)

	inst.storyteller = storyteller

	inst:ListenForEvent("onfueldsectionchanged", function(i, data) CampfireStory_CheckFire(inst, data) end, prop)
end

local function CampfireAuraFn(inst, observer)
	local val = TUNING.SANITYAURA_SMALL_TINY
	if inst.storyteller then
		if inst.storyteller.components.skilltreeupdater and inst.storyteller.components.skilltreeupdater:IsActivated("walter_camp_fire") then
			val = TUNING.SANITYAURA_SMALL
		end
		if inst.storyteller == observer then
			local x, y, z = inst.Transform:GetWorldPosition()
			local numaudience = 0
			for i, v in ipairs(AllPlayers) do
				if v ~= observer and
					not IsEntityDeadOrGhost(v) and
					v.entity:IsVisible() and
					v:GetDistanceSqToPoint(x, y, z) < 16
				then
					numaudience = numaudience + 1
				end
			end
			if numaudience > 0 then
				local mult = 1.5 + 0.05 * math.min(5, numaudience - 1)
				val = val * mult
			end
		end
	end
	return val
end

local function walter_campfire_story_proxy_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("NOBLOCK")

	if Profile:IsCampfireStoryCameraEnabled() then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 3, 4, -1, { ActiveFn = CampfireStory_ActiveFn })
	end

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.max_distsq = 16 -- radius of 4
	inst.components.sanityaura.aurafn = CampfireAuraFn
	inst.components.sanityaura.fallofffn = CampfireStory_aurafallofffn

	---
	inst:WatchWorldState("isnight", CampfireStory_OnNotNight)

	inst.Setup = SetupCampfireStory

	return inst
end

local prefabs_wobycourier_marker = {
    "wobycourier_marker_close"
}

local function wobycourier_marker_init(inst)
    RegisterGlobalMapIcon(inst)
    local close = SpawnPrefab("wobycourier_marker_close")
    close.entity:SetParent(inst.entity)
end

local function wobycourier_marker_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    --[[Non-networked entity]]

    inst.persists = false
    inst.entity:SetCanSleep(false)

    inst.MiniMapEntity:SetIcon("wobycourier_marker.png")
    inst.MiniMapEntity:SetIsProxy(true)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetPriority(MINIMAP_DECORATION_PRIORITY)

    inst:AddTag("globalmapicon") -- Map action logic.
    inst:AddTag("NOBLOCK")

    inst:DoTaskInTime(0, wobycourier_marker_init)

    return inst
end

local function wobycourier_marker_close_fn() -- Child for wobycourier_marker prefab.
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    --[[Non-networked entity]]

    inst.persists = false
    inst.entity:SetCanSleep(false)

    inst.MiniMapEntity:SetIcon("wobycourier_marker.png")
    inst.MiniMapEntity:SetIsProxy(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetPriority(MINIMAP_DECORATION_PRIORITY)

    inst:AddTag("NOBLOCK")

    return inst
end

return MakePlayerCharacter("walter", prefabs, assets, common_postinit, master_postinit),
	Prefab("walter_campfire_story_proxy", walter_campfire_story_proxy_fn),
    Prefab("wobycourier_marker", wobycourier_marker_fn, nil, prefabs_wobycourier_marker),
    Prefab("wobycourier_marker_close", wobycourier_marker_close_fn)