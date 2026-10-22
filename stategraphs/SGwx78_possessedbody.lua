require("stategraphs/commonstates")
local SGWX78Common = require("stategraphs/SGwx78_common")
local WX78Common = require("prefabs/wx78_common")

local function GetIceStaffProjectileSound(inst, equip)
    if equip.icestaff_coldness then
        if equip.icestaff_coldness > 2 then
            return "dontstarve/wilson/attack_deepfreezestaff_lvl2"
        elseif equip.icestaff_coldness > 1 then
            return "dontstarve/wilson/attack_deepfreezestaff"
        end
    end
    return "dontstarve/wilson/attack_icestaff"
end

local function GetKingStaffProjectileSound(inst, equip) -- shadowdominance tag means the staff is corrupted
    if equip:HasTag("icestaff") then
        return equip:HasTag("shadowdominance") and "dontstarve/wilson/attack_icestaff_corrupted"
            or "dontstarve/wilson/attack_icestaff_kingcane"
    elseif equip:HasTag("firestaff") then
        return equip:HasTag("shadowdominance") and "dontstarve/wilson/attack_firestaff_corrupted"
            or "dontstarve/wilson/attack_firestaff_kingcane"
    end

    return "dontstarve/wilson/attack_weapon"
end

local function DropAllItemsForDeath(inst)
    inst.components.inventory:DropEverything(true)
    if inst.components.socketholder then
        local items = inst.components.socketholder:UnsocketEverything()
        for _, item in ipairs(items) do
            Launch2(item, inst, 1, 1, 0.2, 0, 4)
        end
    end
end

local function GetLeader(inst)
    return inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
end

local function GetLeaderAction(inst)
	local target
    local act = inst:GetBufferedAction() or inst.sg.statemem.action
	if act then
		return act.action, act.target
	end

	if inst._lastspintime then
		if inst.sg:HasStateTag("spinning") then
			if GetTime() - inst._lastspintime < 1 then
				return inst._lastspinaction, inst._lastspintarget
			end
		elseif inst:HasTag("using_drone_remote") then
			return inst._lastspinaction, inst._lastspintarget
		end
	end

	if inst.components.playercontroller then
		return inst.components.playercontroller:GetRemoteInteraction()
	end
end

local function TryRepeatAction(inst, buffaction, right)
    local leader = GetLeader(inst)
    if not leader then
        return
    end

    local leaderact, leadertarget = GetLeaderAction(leader)
	if buffaction ~= nil and
		buffaction:IsValid() and
		buffaction.target ~= nil and
		buffaction.target.components.workable ~= nil and
		buffaction.target.components.workable:CanBeWorked() and
		buffaction.target:IsActionValid(buffaction.action, right)
		then

        if leaderact == buffaction.action and leadertarget == buffaction.target then
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst:PushBufferedAction(buffaction)
            return true
        end
    end

	return false
end

local function GetUnequipState(inst, data)
    return (inst:HasTag("wereplayer") and "item_in")
        or (data.eslot ~= EQUIPSLOTS.HANDS and "item_hat")
        or (not data.slip and "item_in")
        or (data.item ~= nil and data.item:IsValid() and "tool_slip")
        or "toolbroke"
        , data.item
end

--V2C: This is for cleaning up interrupted states with legacy stuff, like
--     freeze and pinnable, that aren't consistently controlled by either
--     the stategraph or the component.
local function ClearStatusAilments(inst)
    if inst.components.freezable ~= nil and inst.components.freezable:IsFrozen() then
        inst.components.freezable:Unfreeze()
    end
    if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
        inst.components.pinnable:Unstick()
    end
end

local function IsMinigameItem(inst)
    return inst:HasTag("minigameitem")
end

local function ConfigureRunState(inst)
    inst.sg.statemem.normal = true -- stub if we want to change run state
end

local function DoEquipmentFoleySounds(inst)
    for k, v in pairs(inst.components.inventory.equipslots) do
        if v.foleysound ~= nil then
            inst.SoundEmitter:PlaySound(v.foleysound, nil, nil, true)
        end
    end
end

local function DoFoleySounds(inst)
    DoEquipmentFoleySounds(inst)
	if inst.foleyoverridefn and inst:foleyoverridefn(nil, true) then
		return
	elseif inst.foleysound then
        inst.SoundEmitter:PlaySound(inst.foleysound, nil, nil, true)
    end
end

local DoRunSounds = function(inst)
    if inst.sg.mem.footsteps > 3 then
        PlayFootstep(inst, .6, true)
    else
        inst.sg.mem.footsteps = inst.sg.mem.footsteps + 1
        PlayFootstep(inst, 1, true)
    end
end

local function DoHurtSound(inst)
    if inst.hurtsoundoverride ~= nil then
        inst.SoundEmitter:PlaySound(inst.hurtsoundoverride, nil, inst.hurtsoundvolume)
    elseif not inst:HasTag("mime") then
        inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/hurt", nil, inst.hurtsoundvolume)
    end
end

local function DoEatSound(inst, overrideexisting)
    if inst.sg.statemem.doeatingsfx and (overrideexisting or not inst.SoundEmitter:PlayingSound("eating")) then
        inst.SoundEmitter:PlaySound(inst.sg.statemem.isdrink and "dontstarve/wilson/sip" or "dontstarve/wilson/eat", "eating")
    end
end

local function DoEmoteFX(inst, prefab)
    local fx = SpawnPrefab(prefab)
    if fx ~= nil then
        fx.entity:SetParent(inst.entity)
        fx.entity:AddFollower()
        fx.Follower:FollowSymbol(inst.GUID, "emotefx", 0, 0, 0)
    end
end

local function DoForcedEmoteSound(inst, soundpath)
    inst.SoundEmitter:PlaySound(soundpath)
end

local function DoEmoteSound(inst, soundoverride, loop)
    --NOTE: loop only applies to soundoverride
    loop = loop and soundoverride ~= nil and "emotesoundloop" or nil
    local soundname = soundoverride or "emote"
    local emotesoundoverride = soundname.."soundoverride"
    if inst[emotesoundoverride] ~= nil then
        inst.SoundEmitter:PlaySound(inst[emotesoundoverride], loop)
    elseif not inst:HasTag("mime") then
        inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/"..soundname, loop)
    end
end

local function ToggleOffPhysics(inst)
    inst.sg.statemem.isphysicstoggle = true
	inst.Physics:SetCollisionMask(COLLISION.GROUND)
end

local function ToggleOffPhysicsExceptWorld(inst)
	inst.sg.statemem.isphysicstoggle = true
	inst.Physics:SetCollisionMask(COLLISION.WORLD)
end

local function ToggleOnPhysics(inst)
    inst.sg.statemem.isphysicstoggle = nil
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.SMALLOBSTACLES,
		COLLISION.CHARACTERS,
		COLLISION.GIANTS
	)
end

local function TryReturnItemToFeeder(inst)
	local feed = inst.sg.statemem.feed
	if feed and not feed.persists and feed:IsValid() and feed.components.inventoryitem then
		--restore config from ACTIONS.FEEDPLAYER that assumes item is deleted when eaten
		inst:RemoveChild(feed)
		if feed:IsInLimbo() then
			feed:ReturnToScene()
		end
		feed.components.inventoryitem:WakeLivingItem()
		feed.persists = true
		--
		local range = TUNING.RETURN_ITEM_TO_FEEDER_RANGE
		local feeder = inst.sg.statemem.feeder
		local pos = inst:GetPosition()
		if feeder and feeder:IsValid() and
			feeder.components.inventory and
			feeder.components.inventory.isopen and
			feeder:GetDistanceSqToPoint(pos) < range * range
		then
			if inst.sg.statemem.feedwasactiveitem and
				feeder.components.inventory:GetActiveItem() == nil and
				feeder.components.inventory.isvisible
			then
				feeder.components.inventory:GiveActiveItem(feed)
			else
				feeder.components.inventory:GiveItem(feed, nil, pos)
			end
		else
			inst.components.inventory:GiveItem(feed, nil, pos)
		end
	end
end

--------------------------------------------------------------------------

local function SetGooBuild(inst, build)
	if inst.sg.mem.goo_build ~= build then
		if inst.sg.mem.goo_build then
			inst.AnimState:ClearOverrideBuild(inst.sg.mem.goo_build)
			if inst.sg.mem.goo_build == "goo_vines" then
				inst.AnimState:SetSymbolLightOverride("goo_vine_red", 0)
				inst.AnimState:SetSymbolLightOverride("goo_vine_black", 0)
				inst.AnimState:SetSymbolLightOverride("goo_vines", 0)
				inst.SoundEmitter:KillSound("goo_vines_loop")
			end
		end
		inst.sg.mem.goo_build = build
		if build then
			inst.AnimState:AddOverrideBuild(build)
			if build == "goo_vines" then
				inst.AnimState:SetSymbolLightOverride("goo_vine_red", 1)
				inst.AnimState:SetSymbolLightOverride("goo_vine_black", 1)
				inst.AnimState:SetSymbolLightOverride("goo_vines", 1)
				inst.SoundEmitter:PlaySound("rifts/lunarthrall/vine_move", "goo_vines_loop")
			end
		end
	end
end

--------------------------------------------------------------------------

local actionhandlers =
{
    ActionHandler(ACTIONS.CHOP,
        function(inst)
            if inst.GetModuleTypeCount and inst:GetModuleTypeCount("spin") > 0 then
				return not inst.sg:HasStateTag("prespin")
					and (inst.sg:HasStateTag("spinning") and
						"wx_spin" or
						"wx_spin_start")
					or nil
            end
            return not inst.sg:HasStateTag("prechop")
                and (inst.sg:HasStateTag("chopping") and
                    "chop" or
                    "chop_start")
                or nil
        end),
    ActionHandler(ACTIONS.MINE,
        function(inst)
			if inst.GetModuleTypeCount and inst:GetModuleTypeCount("spin") > 0 then
				return not inst.sg:HasStateTag("prespin")
					and (inst.sg:HasStateTag("spinning") and
						"wx_spin" or
						"wx_spin_start")
					or nil
			end
            return not inst.sg:HasStateTag("premine")
                and (inst.sg:HasStateTag("mining") and
                    "mine" or
                    "mine_start")
                or nil
        end),
    ActionHandler(ACTIONS.HAMMER,
        function(inst)
            return not inst.sg:HasStateTag("prehammer")
                and (inst.sg:HasStateTag("hammering") and
                    "hammer" or
                    "hammer_start")
                or nil
        end),
    ActionHandler(ACTIONS.REMOVELUNARBUILDUP, -- Copy of ACTIONS.MINE
        function(inst)
			if inst.GetModuleTypeCount and inst:GetModuleTypeCount("spin") > 0 then
				return not inst.sg:HasStateTag("prespin")
					and (inst.sg:HasStateTag("spinning") and
						"wx_spin" or
						"wx_spin_start")
					or nil
			end
            return not inst.sg:HasStateTag("premine")
                and (inst.sg:HasStateTag("mining") and
                    "mine" or
                    "mine_start")
                or nil
        end),
    ActionHandler(ACTIONS.DIG,
        function(inst)
            return not inst.sg:HasStateTag("predig")
                and (inst.sg:HasStateTag("digging") and
                    "dig" or
                    "dig_start")
                or nil
        end),
    ActionHandler(ACTIONS.TILL, "till_start"),
    ActionHandler(ACTIONS.GIVE, "give"),
    ActionHandler(ACTIONS.GIVEALLTOPLAYER, "give"),
    ActionHandler(ACTIONS.DROP, "give"),
    ActionHandler(ACTIONS.PICKUP, "take"),
    ActionHandler(ACTIONS.CHECKTRAP, "take"),
    ActionHandler(ACTIONS.PICK,
		function(inst, action)
			if action.target:HasTag("noquickpick") then
				return "dolongaction"
			elseif action.target.components.pickable then
				if inst.GetModuleTypeCount and
					inst:GetModuleTypeCount("spin") > 0 and
					not action.target.components.pickable.quickpick and
					action.target:HasAnyTag(HARVESTABLE_PLANT_TARGET_TAGS)
				then
					--wx skill
					local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
					if WX78Common.CanSpinUsingItem(item) then
						return not inst.sg:HasStateTag("prespin")
							and (inst.sg:HasStateTag("spinning") and
								"wx_spin" or
								"wx_spin_start")
							or nil
					end
				end
				return (action.target.components.pickable.jostlepick and "dojostleaction")
					or (action.target.components.pickable.quickpick and "doshortaction")
					or (inst:HasTag("fastpicker") and "doshortaction")
					or (inst:HasTag("quagmire_fasthands") and "domediumaction")
					or "dolongaction"
			elseif action.target.components.searchable then
				return (action.target.components.searchable.jostlesearch and "dojostleaction")
					or (action.target.components.searchable.quicksearch and "doshortaction")
					or "dolongaction"
			end
			--failed if reached here!
        end),
    ActionHandler(ACTIONS.EAT,
        function(inst, action)
            if inst.sg:HasStateTag("busy") then
                return
            end
            local obj = action.target or action.invobject
            if obj == nil then
                return
            elseif obj.components.edible ~= nil then
                if not inst.components.eater:PrefersToEat(obj) then
                    inst:PushEvent("wonteatfood", { food = obj })
                    return
                end
            elseif obj.components.soul ~= nil then
                if inst.components.souleater == nil then
                    inst:PushEvent("wonteatfood", { food = obj })
                    return
                end
            else
                return
            end

			--NOTE: Keep states in sync with ACTIONS.FEEDPLAYER.fn
			local state =
				(obj:HasTag("quickeat") and "quickeat") or
				(obj:HasTag("sloweat") and "eat") or
				((obj.components.edible.foodtype == FOODTYPE.MEAT and not obj:HasTag("fooddrink")) and "eat") or -- #EGGNOG_HACK, eggnog is the one meat drink, we don't have a long drink, so exclude from eat state
				"quickeat"

			return state
        end),
    ActionHandler(ACTIONS.UNPIN, "doshortaction"),
    ActionHandler(ACTIONS.RAISE_ANCHOR, function(inst)
        return not inst.sg:HasStateTag("raising_anchor") and "raiseanchor"
            or nil
    end),
    ActionHandler(ACTIONS.LOWER_SAIL_BOOST, function(inst, action)
        inst.sg.statemem.not_interrupted = true
        return "furl_boost"
    end),
    ActionHandler(ACTIONS.LOWER_SAIL_FAIL, function(inst, action)
        inst.sg.statemem.not_interrupted = true
        return "furl_fail"
    end),
    ActionHandler(ACTIONS.ROW_FAIL, "row_fail"),
    ActionHandler(ACTIONS.ROW, function(inst, action)
        return not inst.sg:HasStateTag("rowing") and "row"
            or nil
    end),

    ActionHandler(ACTIONS.REPAIR, function(inst, action)
        return action.target:HasTag("repairshortaction") and "doshortaction" or "dolongaction"
    end),

    ActionHandler(ACTIONS.TOGGLEWXSCREECH, function(inst)
        return inst:HasTag("wx_screeching") and "wx_screech_pst" or "wx_screech_pre"
    end),

    ActionHandler(ACTIONS.TOGGLEWXSHIELDING, function(inst)
        return inst:HasTag("wx_shielding") and "wx_shield_pst" or "wx_shield_pre"
    end),

	ActionHandler(ACTIONS.USEEQUIPPEDITEM, function(inst, action)
		return action.invobject and (
				(action.invobject:HasTag("wx_remotecontroller") and "wx_start_using_drone")
			) or "dolongaction"
	end),

    ActionHandler(ACTIONS.SOAKIN, function(inst)
        return not inst.sg:HasStateTag("soaking") and "soakin_pre"
            or nil
    end),
}

local BLOWDART_TAGS = {"blowdart", "blowpipe"}
local events =
{
    EventHandler("locomote", function(inst, data)
		--V2C: - "overridelocomote" indidcates state has custom handler.
		--     - This check is not redundant, because events buffered from previous state
		--       won't use current state's handlers, and can still reach here unwantedly.
        if inst.sg:HasAnyStateTag("busy", "overridelocomote") then
            return
        end

        local is_moving = inst.sg:HasStateTag("moving")
        local should_move = inst.components.locomotor:WantsToMoveForward()

        if is_moving and not should_move then
            inst.sg:GoToState("run_stop")
        elseif not is_moving and should_move then
            if data and data.dir then
                inst.components.locomotor:SetMoveDir(data.dir)
            end
            inst.sg:GoToState("run_start")
        end
    end),

    EventHandler("death", function(inst, data)
    	if not inst.sg:HasStateTag("dead") then
            inst.sg:GoToState("death", data)
    	end
    end),

    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnHop(),
	CommonHandlers.OnElectrocute(),

    EventHandler("freeze",
        function(inst)
            if inst.components.health ~= nil and not inst.components.health:IsDead() then
                inst.sg:GoToState("frozen")
            end
        end),

    EventHandler("pinned",
        function(inst, data)
            if inst.components.health ~= nil and not inst.components.health:IsDead() and inst.components.pinnable ~= nil then
                if inst.components.pinnable.canbepinned then
					inst.sg.statemem.isstillpinned = true
                    inst.sg:GoToState("pinned_pre", data)
                elseif inst.components.pinnable:IsStuck() then
                    --V2C: Since sg events are queued, it's possible we're no longer pinnable
                    inst.components.pinnable:Unstick()
                end
            end
        end),

    EventHandler("equip", function(inst, data)
        if data.eslot == EQUIPSLOTS.BEARD then
            return nil
        elseif data.eslot == EQUIPSLOTS.BODY and data.item ~= nil and data.item:HasTag("heavy") then
            inst.sg:GoToState("heavylifting_start")
		elseif inst.components.inventory:IsHeavyLifting() then
            if inst.sg:HasAnyStateTag("idle", "moving") then
                inst.sg:GoToState("heavylifting_item_hat")
            end
        elseif inst.sg:HasAnyStateTag("idle", "channeling") then
            inst.sg:GoToState(
                (data.item ~= nil and data.item.projectileowner ~= nil and "catch_equip") or
                (data.eslot == EQUIPSLOTS.HANDS and "item_out") or
                "item_hat"
            )
        end
    end),
    EventHandler("unequip", function(inst, data)
        if data.eslot == EQUIPSLOTS.BODY and data.item ~= nil and data.item:HasTag("heavy") then
            if not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("heavylifting_stop")
            end
        elseif inst.components.inventory:IsHeavyLifting() then
            if inst.sg:HasAnyStateTag("idle", "moving") then
                inst.sg:GoToState("heavylifting_item_hat")
            end
        elseif inst.sg:HasAnyStateTag("idle", "channeling") then
            inst.sg:GoToState(GetUnequipState(inst, data))
        end
    end),

	EventHandler("attacked", function(inst, data)
        if inst.components.health and not inst.components.health:IsDead() and not inst.sg:HasAnyStateTag("drowning", "falling") then
			if inst.sg:HasAnyStateTag("devoured", "suspended") then
				return --Do nothing
            elseif inst.sg:HasStateTag("nointerrupt") then
				if data.stimuli == "electric" and not inst.components.inventory:IsInsulated() and inst.sg:HasStateTag("canelectrocute") then
					inst.sg:GoToState("electrocute", { attackdata = data })
				else
					inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
					DoHurtSound(inst)
				end
            elseif data.attacker ~= nil
                and data.attacker:HasTag("groundspike") then
                inst.sg:GoToState("hit_spike", data.attacker)
            elseif data.attacker ~= nil
                and data.attacker.sg ~= nil
                and data.attacker.sg:HasStateTag("pushing") then
                inst.sg:GoToState("hit_push")
            elseif inst.sg:HasStateTag("shell") then
                inst.sg:GoToState("shell_hit")
            elseif inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("pinned_hit")
			elseif data.stimuli == "electric" and inst.sg:HasStateTag("electrocute") and inst.sg:GetTimeInState() < 3 * FRAMES then
				return --Do nothing
			elseif data.stimuli == "electric" and not (inst.components.inventory:IsInsulated() or inst.sg:HasStateTag("noelectrocute")) then
				inst.sg:GoToState("electrocute", { attackdata = data })
			elseif inst.sg:HasStateTag("electrocute") then
				--Don't interrupt electrocute with a regular hit
				inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
				DoHurtSound(inst)
			elseif inst.sg:HasStateTag("wxshielding") then
				if not inst.sg:HasStateTag("wxshieldhit") or inst.sg:HasStateTag("caninterrupt") then
					inst.sg.statemem.iswxshielding = true
					inst.sg:GoToState("wx_shield_hit")
				end
			elseif inst.sg:HasStateTag("nostunlock") then
				inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
				DoHurtSound(inst)
            else
                inst.sg:GoToState("hit")
            end
		end
	end),
	EventHandler("doattack", function(inst, data)
		if inst.components.health ~= nil and not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            local weapon = inst.components.combat ~= nil and inst.components.combat:GetWeapon() or nil
            if inst.GetModuleTypeCount and
				inst:GetModuleTypeCount("spin") > 0 and
				WX78Common.CanSpinUsingItem(weapon) and
				data ~= nil and data.target
			then
				if not inst.sg:HasStateTag("prespin") then
                    inst.sg:GoToState(inst.sg:HasStateTag("spinning") and "wx_spin" or "wx_spin_start", {
                        target = data.target,
                    })
                end
            else
                inst.sg:GoToState(
                    (weapon ~= nil
                        and (weapon:HasOneOfTags(BLOWDART_TAGS) and "blowdart"))
                    or "attack", data ~= nil and data.target or nil)
            end
		end
	end),

    EventHandler("possessed", function(inst, data)
        inst.sg:GoToState("spawn", data)
    end),

    EventHandler("become_dormant", function(inst, data)
        inst.sg:GoToState("despawn")
    end),

    EventHandler("toolbroke",
        function(inst, data)
			if not inst.sg:HasStateTag("nointerrupt") then
				inst.sg:GoToState("toolbroke", data.tool)
			end
        end),

    EventHandler("armorbroke",
        function(inst)
			if not inst.sg:HasStateTag("nointerrupt") then
				inst.sg:GoToState("armorbroke")
			end
        end),

    EventHandler("knockback", function(inst, data)
		if not inst.components.health:IsDead() then
            local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
            if inst.sg:HasStateTag("wxshielding")
                and leader ~= nil and leader.components.skilltreeupdater ~= nil and leader.components.skilltreeupdater:IsActivated("wx78_circuitry_gammabuffs_2") then
                if not inst.sg:HasStateTag("wxshieldhit") then
					inst.sg.statemem.iswxshielding = true
					inst.sg:GoToState("wx_shield_hit")
				end
            else
                if inst.components.inventory:EquipHasTag("superheavyarmor") then
                    inst:PushEvent("knockbackblocked")
                    inst.sg:GoToState("hit")
                else
                    inst.sg:GoToState((data.forcelanded or inst.components.inventory:EquipHasTag("heavyarmor") or inst:HasTag("heavybody")) and "knockbacklanded" or "knockback", data)
                end
            end
        end
    end),

	EventHandler("feetslipped", function(inst)
		if inst.sg:HasStateTag("running") and not inst.sg:HasStateTag("noslip") then
			inst.sg:GoToState("slip")
		end
	end),

    EventHandler("repelled", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("repelled", data)
        end
    end),

    EventHandler("snared", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("startle", true)
        end
    end),

    EventHandler("startled", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("startle", false)
        end
    end),

	EventHandler("devoured", function(inst, data)
		if not inst.components.health:IsDead() and data ~= nil and data.attacker ~= nil and data.attacker:IsValid() then
			inst.sg:GoToState("devoured", data)
		end
	end),

	EventHandler("suspended", function(inst, attacker)
		if not inst.components.health:IsDead() and
			attacker and attacker:IsValid() and
			not (attacker.components.health and attacker.components.health:IsDead())
		then
			inst.sg:GoToState("suspended", attacker)
		end
	end),

    EventHandler("recoil_off", function(inst, data)
        if inst.sg.statemem.recoilstate then
            inst.sg:GoToState(inst.sg.statemem.recoilstate, { target = data.target })
        end
    end),

    EventHandler("emote",
        function(inst, data)
			if not inst.sg:HasAnyStateTag("busy", "sleeping", "floating")
                and not inst.components.inventory:IsHeavyLifting()
                and not data.mountonly then
                inst.sg:GoToState("emote", data)
            end
        end),
}

local states =
{
	State{
		name = "spawn",
        tags = { "busy", "notalking", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.Transform:SetNoFaced()
            inst.AnimState:PlayAnimation("wx_chassis_idle", true)
			if not inst.sg.mem.wx_chassis_build then
				inst.sg.mem.wx_chassis_build = true
				inst.AnimState:AddOverrideBuild("wx_chassis")
			end

			if inst.components.talker then
				inst.components.talker:ShutUp()
				inst.components.talker:IgnoreAll("wx_poweroff")
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(15 + 0, function(inst) inst.SoundEmitter:PlaySound("WX_rework/chassis/internal_rumble") end),
			FrameEvent(15 + 24, function(inst) inst.SoundEmitter:PlaySound("WX_rework/chassis/chassis_clunk") end),
            FrameEvent(15 + 27, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
			FrameEvent(15 + 42, function(inst) inst.SoundEmitter:PlaySound("WX_rework/chassis/chassis_clunk") end),
			FrameEvent(15 + 58, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
            FrameEvent(15 + 73, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),

			FrameEvent(15, function(inst)
				inst.AnimState:PlayAnimation("wx_chassis_poweron")
			end),
			FrameEvent(15 + 60, function(inst)
				if inst.components.talker then
					inst.components.talker:StopIgnoringAll("wx_poweroff")
				end
			end),
			FrameEvent(15 + 67, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:RemoveStateTag("noattack")
			end),
			FrameEvent(15 + 76, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("notalking")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() and not inst.sg:HasStateTag("busy") then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Transform:SetFourFaced()
            inst.AnimState:Hide("trapper")
			inst.sg.mem.wx_chassis_build = nil
			inst.AnimState:ClearOverrideBuild("wx_chassis")

			if inst.components.talker then
				inst.components.talker:StopIgnoringAll("wx_poweroff")
			end
		end,
	},

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

            if pushanim then
                inst.AnimState:PushAnimation("idle_loop", true)
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end

            -- player is usually random * 4 + 2. these ones occur even more frequently to be clearer
            inst.sg:SetTimeout(math.random() * 2 + 1)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("funnyidle")
        end,
    },

    State{
        name = "funnyidle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.components.hunger:GetPercent() < TUNING.HUNGRY_THRESH then
                inst.AnimState:PlayAnimation("hungry")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/hungry")
            elseif inst.components.sanity:IsInsanityMode() and inst.components.sanity:GetPercent() < .5 then
                inst.AnimState:PlayAnimation("idle_inaction_sanity")
            elseif inst.customidleanim == nil and inst.customidlestate == nil then
                inst.AnimState:PlayAnimation("idle_inaction")
			else
                local anim = inst.customidleanim ~= nil and (type(inst.customidleanim) == "string" and inst.customidleanim or inst:customidleanim()) or nil
				local state = anim == nil and (inst.customidlestate ~= nil and (type(inst.customidlestate) == "string" and inst.customidlestate or inst:customidlestate())) or nil
                if anim ~= nil or state ~= nil then
                    if inst.sg.mem.idlerepeats == nil then
                        inst.sg.mem.usecustomidle = math.random() < .5
                        inst.sg.mem.idlerepeats = 0
                    end
                    if inst.sg.mem.idlerepeats > 1 then
                        inst.sg.mem.idlerepeats = inst.sg.mem.idlerepeats - 1
                    else
                        inst.sg.mem.usecustomidle = not inst.sg.mem.usecustomidle
                        inst.sg.mem.idlerepeats = inst.sg.mem.usecustomidle and 1 or math.ceil(math.random(2, 5) * .5)
                    end
					if inst.sg.mem.usecustomidle then
						if anim ~= nil then
		                    inst.AnimState:PlayAnimation(anim)
						else
							inst.sg:GoToState(state)
						end
					else
	                    inst.AnimState:PlayAnimation("idle_inaction")
					end
                else
                    inst.AnimState:PlayAnimation("idle_inaction")
                end
            end
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "run_start",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.sg.mem.footsteps = 0
            ConfigureRunState(inst)

            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
			FrameEvent(4, function(inst)
                if inst.sg.statemem.normal then
                    PlayFootstep(inst, nil, true)
                    DoFoleySounds(inst)
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            ConfigureRunState(inst)

            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
            FrameEvent(7, function(inst)
                if inst.sg.statemem.normal then
                    DoRunSounds(inst)
                    DoFoleySounds(inst)
                end
            end),
            FrameEvent(15, function(inst)
                if inst.sg.statemem.normal then
                    DoRunSounds(inst)
                    DoFoleySounds(inst)
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = { "canrotate", "idle" },

        onenter = function(inst)
            ConfigureRunState(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("run_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "item_hat",
		tags = { "idle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_hat")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "item_in",
		tags = { "idle", "nodangle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_in")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.followfx ~= nil then
                for i, v in ipairs(inst.sg.statemem.followfx) do
                    v:Remove()
                end
            end
        end,
    },

    State{
        name = "item_out",
		tags = { "idle", "nodangle", "keepchannelcasting" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("item_out")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },


    State{
        name = "attack",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst, target)
            if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end
            if inst.sg.laststate == inst.sg.currentstate then
                inst.sg.statemem.chained = true
            end
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            local cooldown = inst.components.combat.min_attack_period
            if equip ~= nil and equip:HasTag("toolpunch") then

                -- **** ANIMATION WARNING ****
                -- **** ANIMATION WARNING ****
                -- **** ANIMATION WARNING ****

                --  THIS ANIMATION LAYERS THE LANTERN GLOW UNDER THE ARM IN THE UP POSITION SO CANNOT BE USED IN STANDARD LANTERN GLOW ANIMATIONS.

                inst.AnimState:PlayAnimation("toolpunch")
                inst.sg.statemem.istoolpunch = true
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, inst.sg.statemem.attackvol, true)
                cooldown = math.max(cooldown, 13 * FRAMES)
            elseif equip ~= nil and equip:HasTag("whip") then
                inst.AnimState:PlayAnimation("whip_pre")
                inst.AnimState:PushAnimation("whip", false)
                inst.sg.statemem.iswhip = true
                inst.SoundEmitter:PlaySound("dontstarve/common/whip_pre", nil, nil, true)
                cooldown = math.max(cooldown, 17 * FRAMES)
			elseif equip ~= nil and equip:HasTag("pocketwatch") then
				inst.AnimState:PlayAnimation(inst.sg.statemem.chained and "pocketwatch_atk_pre_2" or "pocketwatch_atk_pre" )
				inst.AnimState:PushAnimation("pocketwatch_atk", false)
				inst.sg.statemem.ispocketwatch = true
				cooldown = math.max(cooldown, 15 * FRAMES)
                if equip:HasTag("shadow_item") then
	                inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/weapon/pre_shadow", nil, nil, true)
					inst.AnimState:Show("pocketwatch_weapon_fx")
					inst.sg.statemem.ispocketwatch_fueled = true
                else
	                inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/weapon/pre", nil, nil, true)
					inst.AnimState:Hide("pocketwatch_weapon_fx")
                end
            elseif equip ~= nil and equip:HasTag("book") then
                inst.AnimState:PlayAnimation("attack_book")
                inst.sg.statemem.isbook = true
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, nil, true)
                cooldown = math.max(cooldown, 19 * FRAMES)
            elseif equip ~= nil and equip:HasTag("chop_attack") and inst:HasTag("woodcutter") then
				inst.AnimState:PlayAnimation(inst.AnimState:IsCurrentAnimation("woodie_chop_loop") and inst.AnimState:GetCurrentAnimationFrame() <= 7 and "woodie_chop_atk_pre" or "woodie_chop_pre")
                inst.AnimState:PushAnimation("woodie_chop_loop", false)
                inst.sg.statemem.ischop = true
                cooldown = math.max(cooldown, 11 * FRAMES)
            elseif equip ~= nil and equip:HasTag("jab") then
                inst.AnimState:PlayAnimation("spearjab_pre")
                inst.AnimState:PushAnimation("spearjab", false)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, nil, true)
                cooldown = math.max(cooldown, 21 * FRAMES)
            elseif equip ~= nil and equip:HasTag("lancejab") then
                inst.sg.statemem.changedfacing = true
                inst.Transform:SetEightFaced()
                inst.AnimState:PlayAnimation("lancejab_pre")
                inst.AnimState:PushAnimation("lancejab", false)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, nil, true)
                cooldown = math.max(cooldown, 21 * FRAMES)
            elseif equip ~= nil and equip.components.weapon ~= nil and not equip:HasTag("punch") then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                if (equip.projectiledelay or 0) > 0 then
                    --V2C: Projectiles don't show in the initial delayed frames so that
                    --     when they do appear, they're already in front of the player.
                    --     Start the attack early to keep animation in sync.
                    inst.sg.statemem.projectiledelay = 8 * FRAMES - equip.projectiledelay
                    if inst.sg.statemem.projectiledelay > FRAMES then
                        inst.sg.statemem.projectilesound =
                            (equip.prefab == "king_cane" and GetKingStaffProjectileSound(inst, equip)) or
                            (equip:HasTag("icestaff") and GetIceStaffProjectileSound(inst, equip)) or
                            (equip:HasTag("firestaff") and "dontstarve/wilson/attack_firestaff") or
                            (equip:HasTag("firepen") and "wickerbottom_rework/firepen/launch") or
                            "dontstarve/wilson/attack_weapon"
                    elseif inst.sg.statemem.projectiledelay <= 0 then
                        inst.sg.statemem.projectiledelay = nil
                    end
                end
                if inst.sg.statemem.projectilesound == nil then
                    inst.SoundEmitter:PlaySound(
                        (equip.prefab == "king_cane" and GetKingStaffProjectileSound(inst, equip)) or
                        (equip:HasTag("icestaff") and GetIceStaffProjectileSound(inst, equip)) or
                        (equip:HasTag("shadow") and "dontstarve/wilson/attack_nightsword") or
                        (equip:HasTag("firestaff") and "dontstarve/wilson/attack_firestaff") or
                        (equip:HasTag("firepen") and "wickerbottom_rework/firepen/launch") or
                        "dontstarve/wilson/attack_weapon",
                        nil, nil, true
                    )
                end
                cooldown = math.max(cooldown, 13 * FRAMES)
            elseif equip ~= nil and (equip:HasTag("light") or equip:HasTag("nopunch")) then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon", nil, nil, true)
                cooldown = math.max(cooldown, 13 * FRAMES)
            else
                inst.AnimState:PlayAnimation("punch")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, nil, true)
                cooldown = math.max(cooldown, 24 * FRAMES)
            end

            inst.sg:SetTimeout(cooldown)

            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end
        end,

        onupdate = function(inst, dt)
            if (inst.sg.statemem.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = inst.sg.statemem.projectiledelay - dt
                if inst.sg.statemem.projectiledelay <= FRAMES then
                    if inst.sg.statemem.projectilesound ~= nil then
                        inst.SoundEmitter:PlaySound(inst.sg.statemem.projectilesound, nil, nil, true)
                        inst.sg.statemem.projectilesound = nil
                    end
                    if inst.sg.statemem.projectiledelay <= 0 then
                        inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                        inst.sg:RemoveStateTag("abouttoattack")
                    end
                end
            end
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                if not (inst.sg.statemem.iswhip or inst.sg.statemem.ispocketwatch or inst.sg.statemem.isbook) and
                    inst.sg.statemem.projectiledelay == nil then
                    inst.sg.statemem.recoilstate = "attack_recoil"
                    inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(10 * FRAMES, function(inst)
                if inst.sg.statemem.iswhip or inst.sg.statemem.isbook or inst.sg.statemem.ispocketwatch then
                    inst.sg.statemem.recoilstate = "attack_recoil"
                    inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            TimeEvent(17*FRAMES, function(inst)
				if inst.sg.statemem.ispocketwatch then
                    inst.SoundEmitter:PlaySound(inst.sg.statemem.ispocketwatch_fueled and "wanda2/characters/wanda/watch/weapon/pst_shadow" or "wanda2/characters/wanda/watch/weapon/pst")
                end
            end),
        },


        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.changedfacing then
                inst.Transform:SetFourFaced()
            end
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    },

    State{
        name = "blowdart",
        tags = { "attack", "notalking", "abouttoattack" },

        onenter = function(inst, target)
            if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("dart_pre")
            if inst.sg.laststate == inst.sg.currentstate then
                inst.sg.statemem.chained = true
				inst.AnimState:SetFrame(5)
            end
            inst.AnimState:PushAnimation("dart", false)

            inst.sg:SetTimeout(math.max((inst.sg.statemem.chained and 14 or 18) * FRAMES, inst.components.combat.min_attack_period))

            if target ~= nil and target:IsValid() then
                inst:FacePoint(target.Transform:GetWorldPosition())
                inst.sg.statemem.attacktarget = target
                inst.sg.statemem.retarget = target
            end

            if (equip ~= nil and equip.projectiledelay or 0) > 0 then
                --V2C: Projectiles don't show in the initial delayed frames so that
                --     when they do appear, they're already in front of the player.
                --     Start the attack early to keep animation in sync.
                inst.sg.statemem.projectiledelay = (inst.sg.statemem.chained and 9 or 14) * FRAMES - equip.projectiledelay
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst.sg.statemem.projectiledelay = nil
                end
            end
        end,

        onupdate = function(inst, dt)
            if (inst.sg.statemem.projectiledelay or 0) > 0 then
                inst.sg.statemem.projectiledelay = inst.sg.statemem.projectiledelay - dt
                if inst.sg.statemem.projectiledelay <= 0 then
                    inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end
        end,

        timeline =
        {
            FrameEvent(8, function(inst)
                if inst.sg.statemem.chained then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/blowdart_shoot", nil, nil, true)
                end
            end),
            FrameEvent(9, function(inst)
                if inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(13, function(inst)
                if not inst.sg.statemem.chained then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/blowdart_shoot", nil, nil, true)
                end
            end),
            FrameEvent(14, function(inst)
                if not inst.sg.statemem.chained and inst.sg.statemem.projectiledelay == nil then
                    inst.components.combat:DoAttack(inst.sg.statemem.attacktarget)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            if inst:IsAsleep() then
                inst:TryToReplaceWithBackupBody()
                return
            end
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            inst.components.burnable:Extinguish()

            if inst.deathsoundoverride ~= nil then
                inst.SoundEmitter:PlaySound(inst.deathsoundoverride)
            elseif not inst:HasTag("mime") then
                inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/death_voice")
            end

            if (inst.components.sanity:GetPercent() == 0) or inst._saved_health_on_sanity_death then
                inst.sg.statemem.gestaltflee = true
                inst.AnimState:Show("gestalt_flee")
            else
                inst.AnimState:Show("gestalt_die")
            end
			inst:SetGestaltFxShown(false)

			inst.Transform:SetNoFaced()
            inst.AnimState:PlayAnimation("wx_chassis_poweroff")
            if not inst.sg.mem.wx_chassis_build then
                inst.sg.mem.wx_chassis_build = true
                inst.AnimState:AddOverrideBuild("wx_chassis")
            end
        end,

		timeline =
		{
            --#SFX
            -- gestalt is fleeing
            FrameEvent(0, function(inst)
                 if inst.sg.statemem.gestaltflee then
                     inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/emerge_vocals")
                 end
             end),

            -- gestalt is dead
             FrameEvent(0, function(inst)
                 if not inst.sg.statemem.gestaltflee then
                     inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
                 end
             end),

            --
            FrameEvent(0, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("WX_rework/chassis/internal_rumble")
                end
            end),
            FrameEvent(16, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet")
                end
            end),
            FrameEvent(22, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk")
                end
            end),
            FrameEvent(28, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("WX_rework/chassis/chassis_clunk")
                end
            end),
		},

        events =
        {
            -- We 'died' from sanity death but we don't actually want to have 1 health on our chassis, since the body wasn't damaged.
            EventHandler("entitysleep", function(inst)
                if inst.sg.statemem.gestaltflee and inst._saved_health_on_sanity_death ~= nil then
                    inst.components.health:SetCurrentHealth(inst._saved_health_on_sanity_death)
                end
                inst:TryToReplaceWithBackupBody()
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.gestaltflee and inst._saved_health_on_sanity_death ~= nil then
                        inst.components.health:SetCurrentHealth(inst._saved_health_on_sanity_death)
                    end
                    inst:TryToReplaceWithBackupBody()
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.mem.wx_chassis_build then
                inst.sg.mem.wx_chassis_build = nil
                inst.AnimState:ClearOverrideBuild("wx_chassis")
            end
			inst.Transform:SetFourFaced()
			inst:SetGestaltFxShown(true)
		end,
    },

    State{
        name = "despawn",
        tags = {"busy"},

        onenter = function(inst)
            if inst:IsAsleep() then
                inst:TryToReplaceWithBackupBody(true)
                return
            end
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            inst.components.burnable:Extinguish()

            if inst.deathsoundoverride ~= nil then
                inst.SoundEmitter:PlaySound(inst.deathsoundoverride)
            elseif not inst:HasTag("mime") then
                inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/death_voice")
            end

			inst.Transform:SetNoFaced()
            inst.AnimState:PlayAnimation("wx_chassis_poweroff")
            if not inst.sg.mem.wx_chassis_build then
                inst.sg.mem.wx_chassis_build = true
                inst.AnimState:AddOverrideBuild("wx_chassis")
            end
        end,

		timeline =
		{
            FrameEvent(0, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("WX_rework/chassis/internal_rumble")
                end
            end),
            FrameEvent(16, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet")
                end
            end),
            FrameEvent(22, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk")
                end
            end),
            FrameEvent(28, function(inst)
                if inst.sg.mem.wx_chassis_build then
                    inst.SoundEmitter:PlaySound("WX_rework/chassis/chassis_clunk")
                end
            end),
		},

        events =
        {
            EventHandler("entitysleep", function(inst)
                inst:TryToReplaceWithBackupBody(true)
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:TryToReplaceWithBackupBody(true)
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.mem.wx_chassis_build then
                inst.sg.mem.wx_chassis_build = nil
                inst.AnimState:ClearOverrideBuild("wx_chassis")
            end
			inst.Transform:SetFourFaced()
		end,
    },


    State{
        name = "take",
        tags = {"busy"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pickup")
            inst.AnimState:PushAnimation("pickup_pst", false)
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "give",
        tags = {"busy"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("give")
            inst.AnimState:PushAnimation("give_pst", false)
        end,

        timeline =
        {
            TimeEvent(14 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy", "keepchannelcasting" },

        onenter = function(inst, frozen)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("hit")

            if frozen == "noimpactsound" then
                frozen = nil
            else
                inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            end
            DoHurtSound(inst)

			local stun_frames = math.min(inst.AnimState:GetCurrentAnimationNumFrames(), frozen and 10 or 6)
            inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        ontimeout = function(inst)
			--V2C: -removing the tag now, since this is actually a supported "channeling_item"
			--      state (i.e. has custom anim)
			--     -the state enters with the tag though, to cheat having to create a separate
			--      hit state for channeling items
			inst.sg:RemoveStateTag("keepchannelcasting")
            inst.sg:GoToState("idle", true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },


    State{
        name = "frozen",
        tags = { "busy", "frozen", "nodangle" },

        onenter = function(inst)
            if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
                inst.components.pinnable:Unstick()
            end

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen")
            inst.SoundEmitter:PlaySound("dontstarve/common/freezecreature")

            --V2C: cuz... freezable component and SG need to match state,
            --     but messages to SG are queued, so it is not great when
            --     when freezable component tries to change state several
            --     times within one frame...
            if inst.components.freezable == nil then
                inst.sg:GoToState("hit", true)
            elseif inst.components.freezable:IsThawing() then
                inst.sg:GoToState("thaw")
            elseif not inst.components.freezable:IsFrozen() then
                inst.sg:GoToState("hit", true)
            end
        end,

        events =
        {
            EventHandler("onthaw", function(inst)
                inst.sg.statemem.isstillfrozen = true
                inst.sg:GoToState("thaw")
            end),
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("hit", true)
            end),
        },

        onexit = function(inst)
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    },

    State{
        name = "thaw",
        tags = { "busy", "thawing", "nodangle" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen_loop_pst", true)
            inst.SoundEmitter:PlaySound("dontstarve/common/freezethaw", "thawing")
        end,

        events =
        {
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("hit", true)
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("thawing")
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    },


    State{
        name = "stunned",
        tags = {"busy", "canrotate"},

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_sanity_pre")
            inst.AnimState:PushAnimation("idle_sanity_loop", true)
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "chop_start",
        tags = {"prechop", "working"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("chop_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("chop")
                end
            end),
        },
    },

    State{
        name = "chop",
        tags = {"prechop", "chopping", "working"},

        onenter = function(inst)
			inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("chop_loop")
        end,

        timeline =
        {
            FrameEvent(2, function(inst)
                inst:PerformBufferedAction()
            end),
			FrameEvent(14, function(inst)
                inst.sg:RemoveStateTag("prechop")
				TryRepeatAction(inst, inst.sg.statemem.action)
            end),
            FrameEvent(16, function(inst)
                inst.sg:RemoveStateTag("chopping")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "mine_start",
        tags = {"premine", "working"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("pickaxe_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("mine")
                end
            end),
        },
    },

    State{
        name = "mine",
        tags = {"premine", "mining", "working"},

        onenter = function(inst)
			inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("pickaxe_loop")
        end,

        timeline =
        {
            FrameEvent(7, function(inst)
				if inst.sg.statemem.action ~= nil then
					PlayMiningFX(inst, inst.sg.statemem.action.target)
					inst.sg.statemem.recoilstate = "mine_recoil"
                    inst:PerformBufferedAction()
                end
            end),
            FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("premine")
				TryRepeatAction(inst, inst.sg.statemem.action)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("pickaxe_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

	State{
		name = "mine_recoil",
		tags = { "busy", "recoil" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("pickaxe_recoil")
			if data ~= nil and data.target ~= nil and data.target:IsValid() then
                local pos = data.target:GetPosition()

                if data.target.recoil_effect_offset then
                    pos = pos + data.target.recoil_effect_offset
                end
                
				SpawnPrefab("impact").Transform:SetPosition(pos:Get())
			end
			inst.Physics:SetMotorVelOverride(-6, 0, 0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
				inst.sg.statemem.speed = inst.sg.statemem.speed * 0.75
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.speed = -3
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.speed = nil
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
			FrameEvent(30, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

    
    State{
        name = "hammer_start",
        tags = { "prehammer", "working" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pickaxe_pre")
        end,

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("hammer")
                end
            end),
        },
    },

    State{
        name = "hammer",
        tags = { "prehammer", "hammering", "working" },

        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("pickaxe_loop")
        end,

        timeline =
        {
            FrameEvent(7, function(inst)
				inst.SoundEmitter:PlaySound(inst.sg.statemem.action ~= nil and inst.sg.statemem.action.invobject ~= nil and inst.sg.statemem.action.invobject.hit_skin_sound or "dontstarve/wilson/hit")
				inst.sg.statemem.recoilstate = "mine_recoil"
				inst:PerformBufferedAction()
            end),

            FrameEvent(14, function(inst)
                inst.sg:RemoveStateTag("prehammer")
				TryRepeatAction(inst, inst.sg.statemem.action, true)
            end),
        },

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("pickaxe_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

	State{
		name = "attack_recoil",
		tags = { "busy", "recoil" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("atk_recoil")
			if data ~= nil and data.target ~= nil and data.target:IsValid() then
                local pos = data.target:GetPosition()

                if data.target.recoil_effect_offset then
                    pos = pos + data.target.recoil_effect_offset
                end
                
				SpawnPrefab("impact").Transform:SetPosition(pos:Get())
			end
			inst.Physics:SetMotorVelOverride(-6, 0, 0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
				inst.sg.statemem.speed = inst.sg.statemem.speed * 0.75
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.speed = -3
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.speed = nil
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
			FrameEvent(30, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

    State{
        name = "dig_start",
        tags = { "predig", "working" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("shovel_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("dig")
                end
            end),
        },
    },

    State{
        name = "dig",
        tags = { "predig", "digging", "working" },

        onenter = function(inst)
			inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("shovel_loop")
        end,

        timeline =
        {
            FrameEvent(15, function(inst)
                inst:PerformBufferedAction()
                inst.SoundEmitter:PlaySound("dontstarve/wilson/dig")
            end),
            FrameEvent(35, function(inst)
                inst.sg:RemoveStateTag("predig")
				TryRepeatAction(inst, inst.sg.statemem.action, true)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("shovel_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

    State{
        name = "till_start",
        tags = { "doing", "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			local equippedTool = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			if equippedTool ~= nil and equippedTool.components.tool ~= nil and equippedTool.components.tool:CanDoAction(ACTIONS.DIG) then
				--upside down tool build
				inst.AnimState:PlayAnimation("till2_pre")
			else
				inst.AnimState:PlayAnimation("till_pre")
			end
        end,

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("till")
                end
            end),
        },
    },

    State{
        name = "till",
        tags = { "doing", "busy", "tilling" },

        onenter = function(inst)
			local equippedTool = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			if equippedTool ~= nil and equippedTool.components.tool ~= nil and equippedTool.components.tool:CanDoAction(ACTIONS.DIG) then
				--upside down tool build
				inst.sg.statemem.fliptool = true
				inst.AnimState:PlayAnimation("till2_loop")
			else
				inst.AnimState:PlayAnimation("till_loop")
			end
        end,

        timeline =
        {
            FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/wilson/dig") end),
            FrameEvent(11, function(inst)
                inst:PerformBufferedAction()
            end),
            FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/emerge") end),
            FrameEvent(22, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.AnimState:PlayAnimation(inst.sg.statemem.fliptool and "till2_pst" or "till_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

    State{
        name = "dolongaction",
        tags = { "doing", "busy", "nodangle" },

        onenter = function(inst, timeout)
            if timeout == nil then
                timeout = 1
            elseif timeout > 1 then
                inst.sg:AddStateTag("slowaction")
            end
            inst.sg:SetTimeout(timeout)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
            if inst.bufferedaction ~= nil then
                inst.sg.statemem.action = inst.bufferedaction
                if inst.bufferedaction.target ~= nil and inst.bufferedaction.target:IsValid() then
					inst.bufferedaction.target:PushEvent("startlongaction", inst)
                end
            end
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        ontimeout = function(inst)
            inst.AnimState:PlayAnimation("build_pst")
            inst:PerformBufferedAction()
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.bufferedaction == inst.sg.statemem.action then
                inst:ClearBufferedAction()
            end
        end,
    },

    State{
        name = "doshortaction",
        tags = { "doing", "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("pickup")
			inst.AnimState:PushAnimation("pickup_pst", false)

            inst.sg.statemem.action = inst.bufferedaction
            inst.sg:SetTimeout(10 * FRAMES)
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
            TimeEvent(6 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        ontimeout = function(inst)
            --pickup_pst should still be playing
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
            if inst.bufferedaction == inst.sg.statemem.action then
                inst:ClearBufferedAction()
            end
        end,
    },

    State{
        name = "eat",
		tags = { "busy", "nodangle", },

        onenter = function(inst, foodinfo)
            inst.components.locomotor:Stop()

            local feed = foodinfo and foodinfo.feed
            if feed ~= nil then
                inst.components.locomotor:Clear()
                inst:ClearBufferedAction()
                inst.sg.statemem.feed = foodinfo.feed
                inst.sg.statemem.feeder = foodinfo.feeder
				inst.sg.statemem.feedwasactiveitem = foodinfo.active
            elseif inst:GetBufferedAction() then
                feed = inst:GetBufferedAction().invobject
            end

			inst.sg.statemem.doeatingsfx =
				feed == nil or
				feed.components.edible == nil or
				feed.components.edible.foodtype ~= FOODTYPE.GEARS

            inst.AnimState:PlayAnimation("eat_pre")
            inst.AnimState:PushAnimation("eat", false)

            inst.components.hunger:Pause()
        end,

        timeline =
        {
			FrameEvent(6, DoEatSound),
            TimeEvent(28 * FRAMES, function(inst)
                if inst.sg.statemem.feed == nil then
                    inst:PerformBufferedAction()
                elseif inst.sg.statemem.feed.components.soul == nil then
                    inst.components.eater:Eat(inst.sg.statemem.feed, inst.sg.statemem.feeder)
                elseif inst.components.souleater ~= nil then
                    inst.components.souleater:EatSoul(inst.sg.statemem.feed)
                end
				--NOTE: "queue_post_eat_state" can be triggered immediately from the eat action
            end),

            TimeEvent(30 * FRAMES, function(inst)
				if inst.sg.statemem.queued_post_eat_state == nil then
					inst.sg:RemoveStateTag("busy")
				end
            end),
			FrameEvent(52, function(inst)
				if inst.sg.statemem.queued_post_eat_state ~= nil then
					inst.sg:GoToState(inst.sg.statemem.queued_post_eat_state)
				end
			end),
            TimeEvent(70 * FRAMES, function(inst)
				if inst.sg.statemem.doeatingsfx then
					inst.sg.statemem.doeatingsfx = nil
					inst.SoundEmitter:KillSound("eating")
				end
            end),
        },

        events =
        {
			EventHandler("queue_post_eat_state", function(inst, data)
				--NOTE: this event can trigger instantly instead of buffered
				if data ~= nil then
					inst.sg.statemem.queued_post_eat_state = data.post_eat_state
					if data.nointerrupt then
						inst.sg:AddStateTag("nointerrupt")
					end
				end
			end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.sg.statemem.queued_post_eat_state or "idle")
                end
            end),
        },

        onexit = function(inst)
			if inst.sg.statemem.doeatingsfx then
				inst.SoundEmitter:KillSound("eating")
			end
            if not GetGameModeProperty("no_hunger") then
                inst.components.hunger:Resume()
            end
			TryReturnItemToFeeder(inst)
        end,
    },

    State{
        name = "quickeat",
		tags = { "busy", },

        onenter = function(inst, foodinfo)
            inst.components.locomotor:Stop()

            local feed = foodinfo and foodinfo.feed
            if feed ~= nil then
                inst.components.locomotor:Clear()
                inst:ClearBufferedAction()
                inst.sg.statemem.feed = foodinfo.feed
                inst.sg.statemem.feeder = foodinfo.feeder
				inst.sg.statemem.feedwasactiveitem = foodinfo.active
            elseif inst:GetBufferedAction() then
                feed = inst:GetBufferedAction().invobject
            end

            local isdrink = feed and feed:HasTag("fooddrink")
            inst.sg.statemem.isdrink = isdrink

			inst.sg.statemem.doeatingsfx =
				feed == nil or
				feed.components.edible == nil or
				feed.components.edible.foodtype ~= FOODTYPE.GEARS

            if inst.components.inventory:IsHeavyLifting() then
				--V2C: don't think this is used anymore?
                inst.AnimState:PlayAnimation("heavy_quick_eat")
				DoEatSound(inst, true)
            else
                inst.AnimState:PlayAnimation(isdrink and "quick_drink_pre" or "quick_eat_pre")
                inst.AnimState:PushAnimation(isdrink and "quick_drink" or "quick_eat", false)
            end

            inst.components.hunger:Pause()
        end,

        timeline =
        {
			FrameEvent(10, DoEatSound),
            TimeEvent(12 * FRAMES, function(inst)
                if inst.sg.statemem.feed ~= nil then
                    inst.components.eater:Eat(inst.sg.statemem.feed, inst.sg.statemem.feeder)
                else
                    inst:PerformBufferedAction()
                end
				--NOTE: "queue_post_eat_state" can be triggered immediately from the eat action
				if inst.sg.statemem.queued_post_eat_state == nil then
					inst.sg:RemoveStateTag("busy")
				end
            end),
			FrameEvent(21, function(inst)
				if inst.sg.statemem.queued_post_eat_state ~= nil then
					inst.sg:GoToState(inst.sg.statemem.queued_post_eat_state)
				end
			end),
        },

        events =
        {
			EventHandler("queue_post_eat_state", function(inst, data)
				--NOTE: this event can trigger instantly instead of buffered
				if data ~= nil then
					inst.sg.statemem.queued_post_eat_state = data.post_eat_state
					if data.nointerrupt then
						inst.sg:AddStateTag("nointerrupt")
					end
				end
			end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.sg.statemem.queued_post_eat_state or "idle")
                end
            end),
        },

        onexit = function(inst)
			if inst.sg.statemem.doeatingsfx then
				inst.SoundEmitter:KillSound("eating")
			end
            if not GetGameModeProperty("no_hunger") then
                inst.components.hunger:Resume()
            end
			TryReturnItemToFeeder(inst)
        end,
    },

    State{
        name = "refuseeat",
		tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            -- DoTalkSound(inst)
            inst.AnimState:PlayAnimation(inst.components.inventory:IsHeavyLifting() and "heavy_refuseeat" or "refuseeat")
			inst.sg:SetTimeout(60 * FRAMES)
        end,

        timeline =
        {
            FrameEvent(22, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "toolbroke",
        tags = { "busy", },

        onenter = function(inst, tool)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/use_break")
            inst.AnimState:Hide("ARM_carry")
            inst.AnimState:Show("ARM_normal")

            if tool == nil or not tool.nobrokentoolfx then
                SpawnPrefab("brokentool").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end

            inst.sg.statemem.toolname = tool ~= nil and tool.prefab or nil

            inst.sg:SetTimeout(10 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
            if inst.sg.statemem.toolname ~= nil then
                local sameTool = inst.components.inventory:FindItem(function(item)
					return item.prefab == inst.sg.statemem.toolname and item.components.equippable ~= nil
                end)
                if sameTool ~= nil then
                    inst.components.inventory:Equip(sameTool)
                end
            end

            if inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
                inst.AnimState:Show("ARM_carry")
                inst.AnimState:Hide("ARM_normal")
            end
        end,
    },

    State{
        name = "armorbroke",
        tags = { "busy", },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/use_armour_break")
            inst.sg:SetTimeout(10 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,
    },

    State{
        name = "repelled",
        tags = { "busy", "nomorph" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

			local stun_frames = 9
            inst.AnimState:PlayAnimation("distress_pre")
            inst.AnimState:PushAnimation("distress_pst", false)

            DoHurtSound(inst)

			if data ~= nil then
				if data.knocker ~= nil then
					inst.sg:AddStateTag("nointerrupt")
				end
				if data.radius ~= nil and data.repeller ~= nil and data.repeller:IsValid() then
					local x, y, z = data.repeller.Transform:GetWorldPosition()
					local distsq = inst:GetDistanceSqToPoint(x, y, z)
					local rangesq = data.radius * data.radius
					if distsq < rangesq then
						if distsq > 0 then
							inst:ForceFacePoint(x, y, z)
						end
						local k = .5 * distsq / rangesq - 1
						inst.sg.statemem.speed = (data.strengthmult or 1) * 25 * k
						inst.sg.statemem.dspeed = 2
						inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
					end
				end
			end

			inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .25
                    inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
        end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
		},

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    },

    State{
        name = "knockback",
		tags = { "knockback", "busy", "nomorph", "nodangle", "nointerrupt", "jumping" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation(data and data.starthigh and "bucked" or "knockback_high")

            if data ~= nil then
                if data.disablecollision then
					ToggleOffPhysicsExceptWorld(inst)
                end
                if data.propsmashed then
                    local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    local pos
                    if item ~= nil then
                        pos = inst:GetPosition()
                        pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_HIGH
                        local dropped = inst.components.inventory:DropItem(item, true, true, pos)
                        if dropped ~= nil then
                            dropped:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_HIGH, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_HIGH })
                        end
                    end
                    if item == nil or not item:HasTag("propweapon") then
                        item = inst.components.inventory:FindItem(IsMinigameItem)
                        if item ~= nil then
                            pos = pos or inst:GetPosition()
                            pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_LOW
                            item = inst.components.inventory:DropItem(item, false, true, pos)
                            if item ~= nil then
                                item:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_LOW, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_LOW })
                            end
                        end
                    end
                end
                if data.radius ~= nil and data.knocker ~= nil and data.knocker:IsValid() then
                    local x, y, z = data.knocker.Transform:GetWorldPosition()
                    local distsq = inst:GetDistanceSqToPoint(x, y, z)
                    local rangesq = data.radius * data.radius
                    local rot = inst.Transform:GetRotation()
                    local rot1 = distsq > 0 and inst:GetAngleToPoint(x, y, z) or data.knocker.Transform:GetRotation() + 180
                    local drot = math.abs(rot - rot1)
                    while drot > 180 do
                        drot = math.abs(drot - 360)
                    end
                    local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
                    inst.sg.statemem.speed = (data.strengthmult or 1) * 12 * k
                    inst.sg.statemem.dspeed = 0
                    if drot > 90 then
                        inst.sg.statemem.reverse = true
                        inst.Transform:SetRotation(rot1 + 180)
                        inst.Physics:SetMotorVel(-inst.sg.statemem.speed, 0, 0)
                    else
                        inst.Transform:SetRotation(rot1)
                        inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                    end
                end
            end
			if not inst.sg.statemem.isphysicstoggle then
				local x, y, z = inst.Transform:GetWorldPosition()
				inst.sg.statemem.ispassableatpt = GetActionPassableTestFnAt(x, y, z)
				if inst.sg.statemem.ispassableatpt(x, y, z, true) then
					inst.sg.statemem.safepos = Vector3(x, y, z)
				elseif data ~= nil and data.knocker ~= nil and data.knocker:IsValid() and data.knocker:IsOnPassablePoint(true) then
					local x1, y1, z1 = data.knocker.Transform:GetWorldPosition()
					local radius = data.knocker:GetPhysicsRadius(0) - inst:GetPhysicsRadius(0)
					if radius > 0 then
						local dx = x - x1
						local dz = z - z1
						local dist = radius / math.sqrt(dx * dx + dz * dz)
						x = x1 + dx * dist
						z = z1 + dz * dist
						if inst.sg.statemem.ispassableatpt(x, 0, z, true) then
							x1, z1 = x, z
						end
					end
					inst.sg.statemem.safepos = Vector3(x1, 0, z1)
				end
			end
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .075
                    inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -inst.sg.statemem.speed or inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
			local safepos = inst.sg.statemem.safepos
			if safepos ~= nil then
				local x, y, z = inst.Transform:GetWorldPosition()
				if inst.sg.statemem.ispassableatpt(x, y, z, true) then
					safepos.x, safepos.y, safepos.z = x, y, z
				elseif inst.sg.statemem.landed then
					local mass = inst.Physics:GetMass()
					if mass > 0 then
						inst.sg.statemem.restoremass = mass
						inst.Physics:SetMass(99999)
					end
					inst.Physics:Teleport(safepos.x, 0, safepos.z)
					inst.sg.statemem.safepos = nil
				end
			end
        end,

        timeline =
        {
            FrameEvent(8, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.landed = true
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:RemoveStateTag("jumping")
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("knockback_pst")
                end
            end),
        },

        onexit = function(inst)
			if inst.sg.statemem.restoremass ~= nil then
				inst.Physics:SetMass(inst.sg.statemem.restoremass)
			end
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    },

    State{
        name = "knockback_pst",
        tags = { "knockback", "busy", "nomorph", "nodangle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("buck_pst")
        end,

        timeline =
        {
            FrameEvent(27 , function(inst)
                inst.sg:RemoveStateTag("knockback")
                inst.sg:RemoveStateTag("busy")
                inst.sg:RemoveStateTag("nomorph")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "knockbacklanded",
		tags = { "knockback", "busy", "nomorph", "nointerrupt", "jumping" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("hit_spike_heavy")

            if data ~= nil then
                if data.propsmashed then
                    local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    local pos
                    if item ~= nil then
                        pos = inst:GetPosition()
                        pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_LOW
                        local dropped = inst.components.inventory:DropItem(item, true, true, pos)
                        if dropped ~= nil then
                            dropped:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_LOW, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_LOW })
                        end
                    end
                    if item == nil or not item:HasTag("propweapon") then
                        item = inst.components.inventory:FindItem(IsMinigameItem)
                        if item ~= nil then
                            if pos == nil then
                                pos = inst:GetPosition()
                                pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_LOW
                            end
                            item = inst.components.inventory:DropItem(item, false, true, pos)
                            if item ~= nil then
                                item:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_LOW, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_LOW })
                            end
                        end
                    end
                end
                if data.radius ~= nil and data.knocker ~= nil and data.knocker:IsValid() then
                    local x, y, z = data.knocker.Transform:GetWorldPosition()
                    local distsq = inst:GetDistanceSqToPoint(x, y, z)
                    local rangesq = data.radius * data.radius
                    local rot = inst.Transform:GetRotation()
                    local rot1 = distsq > 0 and inst:GetAngleToPoint(x, y, z) or data.knocker.Transform:GetRotation() + 180
                    local drot = math.abs(rot - rot1)
                    while drot > 180 do
                        drot = math.abs(drot - 360)
                    end
                    local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
                    inst.sg.statemem.speed = (data.strengthmult or 1) * 8 * k
                    inst.sg.statemem.dspeed = 0
                    if drot > 90 then
                        inst.sg.statemem.reverse = true
                        inst.Transform:SetRotation(rot1 + 180)
                        inst.Physics:SetMotorVel(-inst.sg.statemem.speed, 0, 0)
                    else
                        inst.Transform:SetRotation(rot1)
                        inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                    end
                end
            end

			local x, y, z = inst.Transform:GetWorldPosition()
			inst.sg.statemem.ispassableatpt = GetActionPassableTestFnAt(x, y, z)
			if inst.sg.statemem.ispassableatpt(x, y, z, true) then
				inst.sg.statemem.safepos = Vector3(x, y, z)
			elseif data ~= nil and data.knocker ~= nil and data.knocker:IsValid() and data.knocker:IsOnPassablePoint(true) then
				local x1, y1, z1 = data.knocker.Transform:GetWorldPosition()
				local radius = data.knocker:GetPhysicsRadius(0) - inst:GetPhysicsRadius(0)
				if radius > 0 then
					local dx = x - x1
					local dz = z - z1
					local dist = radius / math.sqrt(dx * dx + dz * dz)
					x = x1 + dx * dist
					z = z1 + dz * dist
					if inst.sg.statemem.ispassableatpt(x, y, z, true) then
						x1, z1 = x, z
					end
				end
				inst.sg.statemem.safepos = Vector3(x1, 0, z1)
			end

            inst.sg:SetTimeout(11 * FRAMES)
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .075
                    inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -inst.sg.statemem.speed or inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
			local safepos = inst.sg.statemem.safepos
			if safepos ~= nil then
				local x, y, z = inst.Transform:GetWorldPosition()
				if inst.sg.statemem.ispassableatpt(x, y, z, true) then
					safepos.x, safepos.y, safepos.z = x, y, z
				elseif inst.sg.statemem.landed then
					local mass = inst.Physics:GetMass()
					if mass > 0 then
						inst.sg.statemem.restoremass = mass
						inst.Physics:SetMass(99999)
					end
					inst.Physics:Teleport(safepos.x, 0, safepos.z)
					inst.sg.statemem.safepos = nil
				end
			end
        end,

        timeline =
        {
            FrameEvent(9, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.landed = true
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:RemoveStateTag("jumping")
			end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
			if inst.sg.statemem.restoremass ~= nil then
				inst.Physics:SetMass(inst.sg.statemem.restoremass)
			end
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    },

    State{
        name = "hit_spike",
        tags = { "busy", "nomorph" },

        onenter = function(inst, spike)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            local anim = "short"

            if spike ~= nil and type(spike) == "table" then
                inst:ForceFacePoint(spike.Transform:GetWorldPosition())
                if spike.spikesize then
                    anim = spike.spikesize
                end
            else
                anim = spike
            end
            inst.AnimState:PlayAnimation("hit_spike_"..anim)

            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            DoHurtSound(inst)

            inst.sg:SetTimeout(15 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,
    },

    State{
        name = "hit_push",
        tags = { "busy", "nomorph" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("hit")

            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            DoHurtSound(inst)

            inst.sg:SetTimeout(6 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,
    },

    State{
        name = "pinned_pre",
        tags = { "busy", "pinned" },

        onenter = function(inst)
            if inst.components.freezable ~= nil and inst.components.freezable:IsFrozen() then
                inst.components.freezable:Unfreeze()
            end

            if inst.components.pinnable == nil or not inst.components.pinnable:IsStuck() then
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("breakfree")
                return
            end

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_goosplat", inst.components.pinnable.goo_build or "goo", "swap_goosplat")

			if inst.components.pinnable.goo_build == "goo_vines" then
				SetGooBuild(inst, "goo_vines")
				inst.AnimState:PlayAnimation("distress_pre")
			else
				inst.AnimState:PlayAnimation("hit")
			end

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
        end,

        events =
        {
            EventHandler("onunpin", function(inst, data)
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("breakfree")
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.isstillpinned = true
                    inst.sg:GoToState("pinned")
                end
            end),
        },

        onexit = function(inst)
			inst.AnimState:ClearOverrideSymbol("swap_goosplat")
            if not inst.sg.statemem.isstillpinned then
				SetGooBuild(inst, nil)
                inst.components.inventory:Show()
				if inst.components.pinnable then
					inst.components.pinnable:Unstick()
				end
            end
        end,
    },

    State{
        name = "pinned",
        tags = { "busy", "pinned", },

        onenter = function(inst)
            if inst.components.pinnable == nil or not inst.components.pinnable:IsStuck() then
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("breakfree")
                return
            end

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

			if inst.components.pinnable.goo_build == "goo_vines" then
				SetGooBuild(inst, "goo_vines")
			end

            inst.AnimState:PlayAnimation("distress_loop", true)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/spat/spit_playerstruggle", "struggling")

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
        end,

        events =
        {
            EventHandler("onunpin", function(inst, data)
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("breakfree")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("struggling")
			if not inst.sg.statemem.isstillpinned then
				SetGooBuild(inst, nil)
				inst.components.inventory:Show()
				if inst.components.pinnable then
					inst.components.pinnable:Unstick()
				end
			end
        end,
    },

    State{
        name = "pinned_hit",
        tags = { "busy", "pinned", },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

			if inst.components.pinnable.goo_build == "goo_vines" then
				SetGooBuild(inst, "goo_vines")
			end

            inst.AnimState:PlayAnimation("hit_goo")

            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            DoHurtSound(inst)

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
        end,

        events =
        {
            EventHandler("onunpin", function(inst, data)
				inst.sg.statemem.isstillpinned = true
                inst.sg:GoToState("breakfree")
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.isstillpinned = true
                    inst.sg:GoToState("pinned")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.isstillpinned then
				SetGooBuild(inst, nil)
                inst.components.inventory:Show()
				if inst.components.pinnable then
					inst.components.pinnable:Unstick()
				end
            end
        end,
    },

    State{
        name = "breakfree",
        tags = { "busy", },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("distress_pst")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/spat/spit_playerunstuck")

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			if not inst.sg.statemem.isstillpinned then
				SetGooBuild(inst, nil)
				inst.components.inventory:Show()
				if inst.components.pinnable then
					inst.components.pinnable:Unstick()
				end
			end
        end,
    },

    State{
        name = "electrocute",
		tags = { "busy", "electrocute", "noelectrocute" },

		onenter = function(inst, data)
            ClearStatusAilments(inst)
			if inst.components.grogginess then
				inst.components.grogginess:ResetGrogginess()
			end

            inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            inst.fx = SpawnPrefab(
                (not inst:HasTag("wereplayer") and "shock_fx") or
                (inst:HasTag("beaver") and "werebeaver_shock_fx") or
                (inst:HasTag("weremoose") and "weremoose_shock_fx") or
                (--[[inst:HasTag("weregoose") and]] "weregoose_shock_fx")
            )

            inst.fx.entity:SetParent(inst.entity)
            inst.fx.entity:AddFollower()
            inst.fx.Follower:FollowSymbol(inst.GUID, "swap_shock_fx", 0, 0, 0)

			local isplant = inst:HasTag("plantkin")
			local isshort = isplant or (data ~= nil and data.duration ~= nil and data.duration <= TUNING.ELECTROCUTE_SHORT_DURATION)

            if not inst:HasTag("electricdamageimmune") then
                inst.components.bloomer:PushBloom("electrocute", "shaders/anim.ksh", -2)
                inst.Light:Enable(true)

				if isplant and not (data and data.noburn) then
					local attackdata = data and data.attackdata or data
					inst.components.burnable:Ignite(nil, attackdata and (attackdata.weapon or attackdata.attacker), attackdata and attackdata.attacker)
				end
            end

			if data then
				data =
					data.attackdata and {
						attackdata = data.attackdata,
						targets = data.targets,
						numforks = data.numforks and data.numforks - 1 or nil,
					} or
					data.stimuli == "electric" and {
						attackdata = data,
					} or
					nil
				if data then
					StartElectrocuteForkOnTarget(inst, data)
				end
			end

            inst.AnimState:PlayAnimation("shock")
            inst.AnimState:PushAnimation("shock_pst", false)
			if isshort then
				inst.AnimState:SetFrame(8)
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + (2 - 8) * FRAMES)
			else
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + 4 * FRAMES)
			end

            DoHurtSound(inst)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.fx ~= nil then
                    if not inst:HasTag("electricdamageimmune") then
                        inst.Light:Enable(false)
                        inst.components.bloomer:PopBloom("electrocute")
                    end
                    inst.fx:Remove()
                    inst.fx = nil
                end
            end),

            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        ontimeout = function(inst)
			inst.sg:RemoveStateTag("busy")
			inst.sg:RemoveStateTag("noelectrocute")
			inst.sg:AddStateTag("idle")
        end,

        onexit = function(inst)
            if inst.fx ~= nil then
                if not inst:HasTag("electricdamageimmune") then
                    inst.Light:Enable(false)
                    inst.components.bloomer:PopBloom("electrocute")
                end
                inst.fx:Remove()
                inst.fx = nil
            end
        end,
    },

    State{
        name = "raiseanchor",
		tags = { "doing", "busy", "nodangle", "raising_anchor" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
            if inst.bufferedaction ~= nil then
                inst.sg.statemem.action = inst.bufferedaction
	            inst.sg.statemem.anchor = inst.bufferedaction.target
                if inst.bufferedaction.target ~= nil and inst.bufferedaction.target:IsValid() then
					inst.bufferedaction.target:PushEvent("startlongaction", inst)
                end
            end
            if not inst:PerformBufferedAction() then
                inst.sg:GoToState("idle")
            end
        end,

        onupdate = function(inst)
            local leader = GetLeader(inst)
            if not leader then
                return
            end

            local valid = false
            local leaderact, leadertarget = GetLeaderAction(leader)
            if (leaderact == ACTIONS.RAISE_ANCHOR and leadertarget == inst.sg.statemem.anchor)
                or (leader.sg.statemem.anchor == inst.sg.statemem.anchor) then
                valid = true
            end

            if not valid then
                inst.AnimState:PlayAnimation("build_pst")
                inst.sg:GoToState("idle", true)
            end
        end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

        events =
        {
            EventHandler("stopraisinganchor", function(inst)
                inst.AnimState:PlayAnimation("build_pst")
                inst.sg:GoToState("idle", true)
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("make")
            if inst.bufferedaction == inst.sg.statemem.action and
            (inst.components.playercontroller == nil or inst.components.playercontroller.lastheldaction ~= inst.bufferedaction) then
                inst:ClearBufferedAction()
            end
			if inst.sg.statemem.anchor ~= nil and inst.sg.statemem.anchor:IsValid() then
	            inst.sg.statemem.anchor.components.anchor:RemoveAnchorRaiser(inst)
			end
        end,
    },

    State{
        name = "furl_boost",
        tags = { "doing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("pull_big_pre")
            inst.AnimState:PushAnimation("pull_big_loop", false)

            if inst:HasTag("is_heaving") then
                inst:RemoveTag("is_heaving")
            else
                inst:AddTag("is_heaving")
            end

            inst:AddTag("is_furling")

            inst.sg.mem.furl_target = inst.bufferedaction.target or inst.sg.mem.furl_target

            local target_x, target_y, target_z = inst.sg.mem.furl_target.Transform:GetWorldPosition()
            inst:ForceFacePoint(target_x, 0, target_z)
        end,

        onupdate = function(inst)
            if not inst:HasTag("is_furling") then
                inst.sg:GoToState("idle")
            end
        end,

        timeline =
        {
            FrameEvent(17, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_down")
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.sg.statemem.stopfurling then
                        inst.AnimState:PlayAnimation("pull_big_pst", false)
						inst.sg:GoToState("idle", true)
					else
						inst.sg.statemem.not_interrupted = true
						inst.sg:GoToState("furl", inst.sg.mem.furl_target) -- _repeat_delay
					end
				end
            end),

            EventHandler("stopfurling", function(inst)
                inst.sg.statemem.stopfurling = true
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.not_interrupted then
                inst:RemoveTag("switchtoho")
				if inst.sg.mem.furl_target:IsValid() and inst.sg.mem.furl_target.components.mast ~= nil then
	                inst.sg.mem.furl_target.components.mast:RemoveSailFurler(inst)
				end
                inst:RemoveTag("is_furling")
                inst:RemoveTag("is_heaving")
                inst.sg.mem.furl_target = nil
            end
        end,
    },

    State{
        name = "furl",
        tags = { "doing" },

        onenter = function(inst)
            inst:AddTag("switchtoho")
            inst.AnimState:PlayAnimation("pull_small_pre")
            inst.AnimState:PushAnimation("pull_small_loop", true)
            inst:PerformBufferedAction() -- this will clear the buffer if it's full, but you don't get here from an action anyway.
            if inst.sg.mem.furl_target:IsValid() and inst.sg.mem.furl_target.components.mast ~= nil then
                inst.sg.mem.furl_target.components.mast:AddSailFurler(inst, 1)
                inst.sg.statemem._onburnt = function()
                    inst.AnimState:PlayAnimation("pull_small_pst")
                    inst.sg:GoToState("idle",true)
                end
                inst:ListenForEvent("onburnt", inst.sg.statemem._onburnt, inst.sg.mem.furl_target)
            end
        end,

        timeline =
        {
            FrameEvent(15, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
            FrameEvent(15 + 17, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
            FrameEvent(15 + 17*2, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
            FrameEvent(15 + 17*3, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
            FrameEvent(15 + 17*4, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
            FrameEvent(15 + 17*5, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/mast/sail_up")
            end),
        },

        events =
        {
            EventHandler("stopfurling", function(inst)
                inst.AnimState:PlayAnimation("pull_small_pst")
                inst.sg:GoToState("idle", true)
            end),
        },

        onexit = function(inst)
			if inst.sg.statemem._onburnt ~= nil and inst.sg.mem.furl_target:IsValid() then
	            inst:RemoveEventCallback("onburnt", inst.sg.statemem._onburnt, inst.sg.mem.furl_target)
			end
            if not inst.sg.statemem.not_interrupted then
                inst:RemoveTag("switchtoho")
                if inst.sg.mem.furl_target:IsValid() and inst.sg.mem.furl_target.components.mast ~= nil then
                    inst.sg.mem.furl_target.components.mast:RemoveSailFurler(inst)
                end
                inst:RemoveTag("is_furling")
                inst:RemoveTag("is_heaving")
                inst.sg.mem.furl_target = nil
            end
        end,
    },

    State{
        name = "furl_fail",
        tags = { "busy", "furl_fail" },

        onenter = function(inst)
            inst:PerformBufferedAction()
			if inst.sg.mem.furl_target:IsValid() and inst.sg.mem.furl_target.components.mast ~= nil then
	            inst.sg.mem.furl_target.components.mast:AddSailFurler(inst, 0)
			end

            inst:RemoveTag("is_heaving")

            inst.AnimState:PlayAnimation("pull_fail")
        end,

        onexit = function(inst)
            if not inst.sg.statemem.not_interrupted then
				if inst.sg.mem.furl_target:IsValid() and inst.sg.mem.furl_target.components.mast ~= nil then
	                inst.sg.mem.furl_target.components.mast:RemoveSailFurler(inst)
				end
                inst:RemoveTag("is_furling")
                inst:RemoveTag("is_heaving")
                inst.sg.mem.furl_target = nil
            end
        end,

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("furl", inst.sg.mem.furl_target)
				end
            end),
            EventHandler("stopfurling", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },


	State{
		name = "slip",
		tags = { "busy", "nomorph", "jumping", "overridelocomote" },

		onenter = function(inst, speed)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			if inst.components.slipperyfeet then
				inst.components.slipperyfeet:SetCurrent(0)
			end

			inst.AnimState:PlayAnimation("slip_pre")
			inst.AnimState:PushAnimation("slip_loop", false)
			inst.SoundEmitter:PlaySound("dontstarve/movement/iceslab_slipping")

			inst.sg.statemem.speed = speed or inst.components.locomotor:GetRunSpeed()
			inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.6, 0, 0)

			inst.sg.statemem.trackcontrol = true
		end,

		timeline =
		{
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.3, 0, 0) end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/iceslab_slipping") end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.25, 0, 0) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.2, 0, 0) end),

			FrameEvent(18, function(inst)
				inst.sg.statemem.checkfall = true
			end),
			FrameEvent(20, function(inst)
				if inst.sg.statemem.controltick then
					inst.sg.statemem.trystoptracking = true
				else
					inst.sg.statemem.trackcontrol = false
				end
				inst.SoundEmitter:PlaySound("dontstarve/movement/iceslab_slipping", nil, 0.5)
			end),
		},

		events =
		{
			EventHandler("locomote", function(inst, data)
				if inst.sg.statemem.trackcontrol and data and data.remoteoverridelocomote or inst.components.locomotor:WantsToMoveForward() then
					if inst.sg.statemem.checkfall then
						inst.sg.statemem.slipping = true
						inst.sg:GoToState("slip_fall", inst.sg.statemem.speed * 0.25)
						return
					end
					inst.sg.statemem.controltick = GetTick()
				end
				return true
			end),
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.slipping = true
					inst.sg:GoToState("slip_pst", inst.sg.statemem.speed)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.slipping then
				inst.Physics:SetMotorVel(0, 0, 0)
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "slip_pst",
		tags = { "busy", "nomorph", "jumping" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("slip_pst")
			inst.sg.statemem.speed = speed or inst.components.locomotor:GetRunSpeed()
			inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.15, 0, 0)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.1, 0, 0) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:SetMotorVel(0, 0, 0)
			inst.Physics:Stop()
		end,
	},

	State{
		name = "slip_fall",
		tags = { "busy", "nomorph", "jumping" },

		onenter = function(inst, speed)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			if inst.components.slipperyfeet then
				inst.components.slipperyfeet:SetCurrent(0)
			end

			inst.AnimState:PlayAnimation("slip_fall_pre")
			inst.SoundEmitter:PlaySound("dontstarve/movement/slip_fall_whoop")

			if speed then
				inst.sg.statemem.speed = speed
				inst.Physics:SetMotorVel(speed * 0.8, 0, 0)
			end
		end,

		timeline =
		{
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/slip_fall_thud") end),
			FrameEvent(11, function(inst)
				DoHurtSound(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.64, 0, 0)
				end
			end),
			--held 2 frames on purpose =P
			FrameEvent(13, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.32, 0, 0)
				end
			end),
			FrameEvent(14, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.16, 0, 0)
				end
			end),
			FrameEvent(15, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.08, 0, 0)
				end
			end),
			FrameEvent(16, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.04, 0, 0)
				end
			end),
			FrameEvent(17, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(0, 0, 0)
					inst.Physics:Stop()
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("slip_fall_loop")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.speed then
				inst.Physics:SetMotorVel(0, 0, 0)
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "slip_fall_loop",
		tags = { "busy", "nomorph", "overridelocomote" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			if inst.components.slipperyfeet then
				inst.components.slipperyfeet:SetCurrent(0)
			end

			inst.AnimState:PlayAnimation("slip_fall_idle")
		end,

		events =
		{
			EventHandler("locomote", function(inst, data)
				if data ~= nil and data.remoteoverridelocomote or inst.components.locomotor:WantsToMoveForward() then
					inst.sg.statemem.keepfacings = true
					inst.sg:GoToState("slip_fall_pst")
				end
				return true
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepfacings = true
					inst.sg:GoToState("slip_fall_pst")
				end
			end),
		},

		onexit = function(inst)
			--V2C: in case we came here from an 8-faced state like joust_collide
			if not inst.sg.statemem.keepfacings then
				inst.Transform:SetFourFaced()
			end
		end,
	},

	State{
		name = "slip_fall_pst",
		tags = { "busy", "nomorph" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slip_fall_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst) PlayFootstep(inst, 0.6) end),
			FrameEvent(12, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			--V2C: in case we went to slip_fall_loop from an 8-faced state like joust_collide
			inst.Transform:SetFourFaced()
		end,
	},

	State{
		name = "soakin_pre",
		tags = { "busy", "canrotate", "soaking" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("jump_pre")
		end,

		events =
		{
			EventHandler("ms_enterbathingpool", function(inst, data)
				if data and data.target and data.dest then
					inst.sg:GoToState("soakin_jump", data)
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem._soakin_pending = inst.sg.currentstate
					inst:PerformBufferedAction()
					if inst.sg.statemem._soakin_pending == inst.sg.currentstate then
						--never left state, action must've failed
						inst.sg:GoToState("idle")
					end
				end
			end),
		},
	},

	State{
		name = "soakin_jump",
		tags = { "busy", "nomorph", "jumping", "soaking" },

		onenter = function(inst, data)
			if not (data and data.dest and data.target and data.target:IsValid() and data.target.components.bathingpool) then
				inst.sg:GoToState("idle")
				return
			end

			inst.sg.statemem.data = data

			--required by bathingpool component
			inst.sg.statemem.occupying_bathingpool = data.target

			inst:ForceFacePoint(data.dest)

			local x, y, z = inst.Transform:GetWorldPosition()
			local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			local item2 = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
			if item or item2 then
				local pos = Vector3(x, y, z)
				if item then
					inst.components.inventory:DropItem(item, true, false, pos)
				end
				if item2 then
					inst.components.inventory:DropItem(item2, true, false, pos)
				end
			end
			ToggleOffPhysics(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hotspring_pre")
			inst.AnimState:AddOverrideBuild("player_hotspring")

			local dsq = distsq(x, z, data.dest.x, data.dest.z)
			if dsq > 0 then
				inst.Physics:SetMotorVel(math.sqrt(dsq) / (10 * FRAMES), 0 , 0)
			end

			inst.components.inventory:Hide()
			inst:PushEvent("ms_closepopups")
		end,

		timeline =
		{
			FrameEvent(9, function(inst) inst.SoundEmitter:PlaySound("hookline_2/common/hotspring/use") end),
			FrameEvent(10, function(inst)
				inst.Physics:SetMotorVel(0, 0, 0)
				inst.Physics:Stop()
				inst.Physics:Teleport(inst.sg.statemem.data.dest:Get())
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.not_interrupted = true
				inst.sg:GoToState("soakin", inst.sg.statemem.data)
			end),
		},

		onexit = function(inst)
			local target = inst.sg.statemem.occupying_bathingpool
			if target then
				if inst.sg:HasStateTag("jumping") then
					inst.Physics:SetMotorVel(0, 0, 0)
					inst.Physics:Stop()
				end
				if not inst.sg.statemem.not_interrupted then
					if inst.sg.statemem.isphysicstoggle then
						ToggleOnPhysics(inst)
					end
					inst.components.inventory:Show()
				end
			end
			if not inst.sg.statemem.not_interrupted then
				inst.AnimState:ClearOverrideBuild("player_hotspring")
			end
		end,
	},

	State{
		name = "soakin",
		tags = { "busy", "nomorph", "overridelocomote", "soaking" },

		onenter = function(inst, data)
			--required by bathingpool component
			inst.sg.statemem.occupying_bathingpool = data and data.target

			if not (data and data.dest and data.target and data.target:IsValid() and data.target.components.bathingpool) then
				inst.sg:GoToState("soakin_cancel")
				return
			end

			--required by bathingpool component
			inst.sg.statemem.occupying_bathingpool = data.target

			inst:ForceFacePoint(data.target.Transform:GetWorldPosition())

			local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			local item2 = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
			if item or item2 then
				local pos = inst:GetPosition()
				if item then
					inst.components.inventory:DropItem(item, true, false, pos)
				end
				if item2 then
					inst.components.inventory:DropItem(item2, true, false, pos)
				end
			end
			ToggleOffPhysics(inst)
			inst.components.locomotor:Stop()
			inst.DynamicShadow:Enable(false)
			if inst.AnimState:IsCurrentAnimation("hotspring_pre") then
				inst.AnimState:PushAnimation("hotspring_loop")
			else
				inst.AnimState:PlayAnimation("hotspring_loop", true)
			end
			--V2C: should already have it
			--inst.AnimState:AddOverrideBuild("player_hotspring")

			inst.sg.statemem.range = math.max(0, data.target.components.bathingpool:GetRadius() - inst:GetPhysicsRadius(0))
			inst.Physics:Teleport(data.dest:Get())

			inst.components.inventory:Hide()
			inst:PushEvent("ms_closepopups")
		end,

		onupdate = function(inst)
			local target = inst.sg.statemem.occupying_bathingpool
			if not (target:IsValid() and
					target.components.bathingpool and
					target.components.bathingpool:IsOccupant(inst) and
					inst:IsNear(target, inst.sg.statemem.range + 0.1))
			then
				inst.sg.statemem.not_interrupted = true
				inst.DynamicShadow:Enable(true)
				inst.sg:GoToState("soakin_cancel", true)
			else
				local dir-- = GetLocalAnalogDir(inst)
				if dir then
					dir = math.atan2(-dir.z, dir.x) * RADIANS
					if inst.sg.statemem.range == 0 then
						inst.sg.statemem.not_interrupted = true
						inst.sg.statemem.jumpout = true
						inst.sg:GoToState("soakin_jumpout", { target = target, dir = dir })
					elseif DiffAngle(inst.Transform:GetRotation(), dir) > 110 then
						inst.sg.statemem.not_interrupted = true
						inst.sg.statemem.jumpout = true
						inst.sg:GoToState("soakin_jumpout", target)
					end
				end
			end
		end,

		events =
		{
			EventHandler("locomote", function(inst, data)
                local leader = GetLeader(inst)
                if leader ~= nil then
                    local leaderact, leadertarget = GetLeaderAction(leader)
                    if (leaderact == ACTIONS.SOAKIN and inst.sg.statemem.occupying_bathingpool == leadertarget)
                        or inst.sg.statemem.occupying_bathingpool == leader.sg.statemem.occupying_bathingpool then
                        return
                    end
                end
				if data and
					(data.remoteoverridelocomote or inst.components.locomotor:WantsToMoveForward())
				then
					inst.sg.statemem.not_interrupted = true
					inst.sg.statemem.jumpout = true
					inst.sg:GoToState("soakin_jumpout", inst.sg.statemem.occupying_bathingpool)
				end
				return true
			end),
			EventHandler("ms_leavebathingpool", function(inst, target)
				if target == inst.sg.statemem.occupying_bathingpool then
					inst.sg.statemem.not_interrupted = true
					inst.sg.statemem.jumpout = true
					inst.sg:GoToState("soakin_jumpout", target)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.jumpout then
				inst.components.inventory:Show()
			end

			local target = inst.sg.statemem.occupying_bathingpool
			if target then
				if not inst.sg.statemem.not_interrupted then
					if inst.sg.statemem.isphysicstoggle then
						ToggleOnPhysics(inst)
					end
					inst.DynamicShadow:Enable(true)

					if target:IsValid() then
						local radius = inst:GetPhysicsRadius(0) + target:GetPhysicsRadius(0)
						if radius > 0 then
							local x, _, z = target.Transform:GetWorldPosition()
							local _ispassableatpoint = GetActionPassableTestFnAt(x, 0, z)
							local dir = inst:GetAngleToPoint(x, 0, z)
							dir = (dir + 180) * DEGREES
							x = x + radius * math.cos(dir)
							z = z - radius * math.sin(dir)
							if _ispassableatpoint(x, 0, z) then
								inst.Physics:Teleport(x, 0, z)
							end
						end
					end
				end
			end

			if not inst.sg.statemem.jumpout then
				inst.AnimState:ClearOverrideBuild("player_hotspring")
			end

			if inst.sg.statemem.soakintalktask then
				inst.sg.statemem.soakintalktask:Cancel()
			end
		end,
	},

	State{
		name = "soakin_jumpout",
		tags = { "busy", "nomorph", "jumping", "soaking" },

		onenter = function(inst, target)
			if target and not EntityScript.is_instance(target) then
				inst.sg.statemem.dir = target.dir
				target = target.target
			end
			if not (target and target:IsValid()) then
				assert(false)
				inst.sg:GoToState("soakin_cancel", target ~= nil)
				return
			end
			inst.sg.statemem.exiting_bathingpool = target
			inst.sg.statemem.isphysicstoggle = true
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hotspring_pst")
			--V2C: should already have it
			--inst.AnimState:AddOverrideBuild("player_hotspring")

			inst.sg.statemem.water = SpawnPrefab("player_hotspring_water_fx")
			inst.sg.statemem.water.entity:SetParent(inst.entity)
			inst.sg.statemem.water.AnimState:MakeFacingDirty() -- Not needed for clients.
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.sg.statemem.water.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
			end),
			FrameEvent(5, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()
				local water = inst.sg.statemem.water
				inst.sg.statemem.water = nil --clear ref so it doesn't get removed onexit
				water.entity:SetParent(nil)
				water.Transform:SetPosition(x, y, z)
				water.Transform:SetRotation(rot)
				water.AnimState:MakeFacingDirty() -- Not needed for clients.

				local target = inst.sg.statemem.exiting_bathingpool
				if target:IsValid() then
					local radius = inst:GetPhysicsRadius(0) + target:GetPhysicsRadius(0)
					if radius > 0 then
						local x1, _, z1 = target.Transform:GetWorldPosition()
						if inst.sg.statemem.dir == nil then
							if x ~= x1 or z ~= z1 then
								inst.sg.statemem.dir = math.atan2(z1 - z, x - x1) * RADIANS
							else
								inst.sg.statemem.dir = rot + 180
							end
						end
						local dist = math.sqrt(distsq(x, z, x1, z1))
						if dist < radius then
							dist = radius - dist
							inst.sg.statemem.speed = dist / (8 * FRAMES)
							local theta = (inst.sg.statemem.dir - rot) * DEGREES
							inst.Physics:SetMotorVel(inst.sg.statemem.speed * math.cos(theta), 0, -inst.sg.statemem.speed * math.sin(theta))
						end
					else
						inst.sg.statemem.dir = nil
					end
				end
				inst.SoundEmitter:PlaySound("hookline_2/common/hotspring/use")
			end),
			FrameEvent(6, function(inst) inst.DynamicShadow:Enable(true) end),
			FrameEvent(8, function(inst)
				if inst.sg.statemem.dir then
					inst.Transform:SetRotation(inst.sg.statemem.dir)
				end
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(12, function(inst)
				if inst.sg.statemem.isphysicstoggle then
					ToggleOnPhysics(inst)
				end
				inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
			end),
			FrameEvent(13, function(inst)
				inst.Physics:SetMotorVel(0, 0, 0)
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
				inst.components.inventory:Show()
			end),
			FrameEvent(15, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.water then
				--interrupted while still parented
				inst.sg.statemem.water:Remove()
			end
			inst.components.inventory:Show()
			inst.AnimState:ClearOverrideBuild("player_hotspring")
			inst.DynamicShadow:Enable(true)
			if inst.sg.statemem.isphysicstoggle then
				ToggleOnPhysics(inst)
			end
			inst.Physics:SetMotorVel(0, 0, 0)
			inst.Physics:Stop()
		end,
	},

	State{
		name = "soakin_cancel",
		tags = { "busy", "nomorph", },

		onenter = function(inst, isphysicstoggle)
			ClearStatusAilments(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("slip_fall_idle")
			inst.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationNumFrames() - 9)
			inst.AnimState:PushAnimation("slip_fall_pst", false)
			inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/bird")
			PlayFootstep(inst, 0.6)

			inst.sg.statemem.isphysicstoggle = isphysicstoggle
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				if inst.sg.statemem.isphysicstoggle then
					ToggleOnPhysics(inst)
				end
			end),
			FrameEvent(9 + 6, function(inst) PlayFootstep(inst, 0.6) end),
			FrameEvent(9 + 12, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.isphysicstoggle then
				ToggleOnPhysics(inst)
			end
		end,
	},

    State{
        name = "startle",
        tags = { "busy" },

        onenter = function(inst, snap)
            local stun_frames = 9

            ClearStatusAilments(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("distress_pre")
            inst.AnimState:PushAnimation("distress_pst", false)

            DoHurtSound(inst)

            inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,
    },


	State{
		name = "devoured",
		tags = { "devoured", "invisible", "noattack", "notalking", "nointerrupt", "busy", "silentmorph" },

		onenter = function(inst, data)
            local attacker = data.attacker
			ClearStatusAilments(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()
			inst.AnimState:PlayAnimation("empty")

			inst:Hide()
			inst.DynamicShadow:Enable(false)
			ToggleOffPhysics(inst)
			if attacker ~= nil and attacker:IsValid() then
				inst.sg.statemem.attacker = attacker
				inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
			end
		end,

		onupdate = function(inst)
			local attacker = inst.sg.statemem.attacker
			if attacker ~= nil and attacker:IsValid() then
				inst.Transform:SetPosition(attacker.Transform:GetWorldPosition())
				inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
			else
				inst.sg:GoToState("idle")
			end
		end,

		events =
		{
			EventHandler("spitout", function(inst, data)
				local attacker = data ~= nil and data.spitter or inst.sg.statemem.attacker
				if attacker ~= nil and attacker:IsValid() then
					local rot = data.rot or attacker.Transform:GetRotation() + 180
					inst.Transform:SetRotation(rot)
					local physradius = attacker:GetPhysicsRadius(0)
					if physradius > 0 then
						local x, y, z = inst.Transform:GetWorldPosition()
						rot = rot * DEGREES
						x = x + math.cos(rot) * physradius
						z = z - math.sin(rot) * physradius
						inst.Physics:Teleport(x, 0, z)
					end
					DoHurtSound(inst)
					inst:PushEventImmediate("knockback", {
						knocker = attacker,
						starthigh = data and data.starthigh or nil,
						radius = data ~= nil and data.radius or physradius + 1,
						strengthmult = data ~= nil and data.strengthmult or nil,
					})
				else
					inst:PushEventImmediate("knockback")
				end
				--NOTE: ignores heavy armor/body
			end),
		},

		onexit = function(inst)
			if inst.components.health:IsDead() then
				local attacker = inst.sg.statemem.attacker
				if attacker ~= nil and attacker:IsValid() then
					local rot = attacker.Transform:GetRotation()
					inst.Transform:SetRotation(rot + 180)
					--use true physics radius if available
					local radius = attacker.Physics ~= nil and attacker.Physics:GetRadius() or attacker:GetPhysicsRadius(0)
					if radius > 0 then
						local x, y, z = inst.Transform:GetWorldPosition()
						rot = rot * DEGREES
						x = x + math.cos(rot) * radius
						z = z - math.sin(rot) * radius
						if TheWorld.Map:IsPassableAtPoint(x, 0, z, true) then
							inst.Physics:Teleport(x, 0, z)
						end
					end
				end
			end
			inst:Show()
			inst.DynamicShadow:Enable(true)
			if inst.sg.statemem.isphysicstoggle then
				ToggleOnPhysics(inst)
			end
			inst.entity:SetParent(nil)
		end,
	},

	State{
		name = "suspended",
		tags = { "suspended", "noattack", "notalking", "nointerrupt", "busy", "nomorph", "nodangle" },

		onenter = function(inst, attacker)
			ClearStatusAilments(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()
			ToggleOffPhysics(inst)
			inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("suspended_pre")
			inst.AnimState:PushAnimation("suspended")
			inst.components.inventory:Hide()
			inst:PushEvent("ms_closepopups")
			if attacker and attacker:IsValid() then
				inst.sg.statemem.attacker = attacker
				attacker:PushEvent("playersuspended", inst)
			end
		end,

		onupdate = function(inst)
			local attacker = inst.sg.statemem.attacker
			if attacker and attacker:IsValid() then
				inst.Transform:SetPosition(attacker.Transform:GetWorldPosition())
			else
				inst.sg:GoToState("idle")
			end
		end,

		events =
		{
			EventHandler("attacked", function(inst)
				inst.AnimState:PlayAnimation("suspended_hit")
				inst.AnimState:PushAnimation("suspended")
				DoHurtSound(inst)
				return true
			end),
			EventHandler("abouttospit", function(inst)
				inst.AnimState:PlayAnimation("suspended_spit")
				inst.AnimState:PushAnimation("suspended")
				DoHurtSound(inst)
			end),
			EventHandler("spitout", function(inst, data)
				local attacker = data ~= nil and data.spitter or inst.sg.statemem.attacker
				if attacker and attacker:IsValid() then
					local rot = data.rot or attacker.Transform:GetRotation() + 180
					inst.Transform:SetRotation(rot)
					local x, y, z = inst.Transform:GetWorldPosition()
					rot = rot * DEGREES
					x = x + math.cos(rot) * 0.1
					z = z - math.sin(rot) * 0.1
					inst.Physics:Teleport(x, 0, z)
					DoHurtSound(inst)
					inst:PushEventImmediate("knockback", {
						knocker = attacker,
						starthigh = data and data.starthigh or nil,
						radius = data and data.radius or attacker:GetPhysicsRadius(0) + 1,
						strengthmult = data ~= nil and data.strengthmult or nil,
					})
				else
					inst:PushEventImmediate("knockback")
				end
				--NOTE: ignores heavy armor/body
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.isphysicstoggle then
				ToggleOnPhysics(inst)
			end
			if inst.components.health:IsDead() then
				local attacker = inst.sg.statemem.attacker
				if attacker and attacker:IsValid() then
					--use true physics radius if available
					local radius = attacker.Physics and attacker.Physics:GetRadius() or attacker:GetPhysicsRadius(0)
					if radius > 0 then
						local x, y, z = inst.Transform:GetWorldPosition()
						local theta = attacker.Transform:GetRotation() * DEGREES
						x = x + math.cos(theta) * radius
						z = z - math.sin(theta) * radius
						if TheWorld.Map:IsPassableAtPoint(x, 0, z, true) then
							inst.Physics:Teleport(x, 0, z)
						end
					end
				end
				attacker:PushEvent("suspendedplayerdied", inst)
			end
			inst.Transform:SetFourFaced()
			inst.components.inventory:Show()
		end,
	},

	State{ --NOTE: If making changes to this state think about if you need to do the same for attack_recoil
		name = "mine_recoil",
		tags = { "busy", "nomorph" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("pickaxe_recoil")
			if data ~= nil and data.target ~= nil and data.target:IsValid() then
                local pos = data.target:GetPosition()

                if data.target.recoil_effect_offset then
                    pos = pos + data.target.recoil_effect_offset
                end

				SpawnPrefab("impact").Transform:SetPosition(pos:Get())
			end
			inst.Physics:SetMotorVel(-6, 0, 0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
				inst.sg.statemem.speed = inst.sg.statemem.speed * 0.75
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.speed = -3
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.speed = nil
				inst.Physics:Stop()
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("nomorph")
			end),
			FrameEvent(30, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	},

    State{ --NOTE: If making changes to this state think about if you need to do the same for mine_recoil
		name = "attack_recoil",
		tags = { "busy", "nomorph" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("atk_recoil")
			if data ~= nil and data.target ~= nil and data.target:IsValid() then
                local pos = data.target:GetPosition()

                if data.target.recoil_effect_offset then
                    pos = pos + data.target.recoil_effect_offset
                end

				SpawnPrefab("impact").Transform:SetPosition(pos:Get())
			end

			inst.Physics:SetMotorVel(-6, 0, 0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
				inst.sg.statemem.speed = inst.sg.statemem.speed * 0.75
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.speed = -3
			end),
			FrameEvent(17, function(inst)
				inst.sg.statemem.speed = nil
				inst.Physics:Stop()
			end),
			FrameEvent(23, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("nomorph")
			end),
			FrameEvent(30, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	},


    State{
        name = "emote",
        tags = { "busy", "emoting" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()

            if data.tags ~= nil then
                for i, v in ipairs(data.tags) do
                    inst.sg:AddStateTag(v)
                    if v == "dancing" then
                        local hat = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                        if hat ~= nil and hat.OnStartDancing ~= nil then
                            local newdata = hat:OnStartDancing(inst, data)
                            if newdata ~= nil then
                                inst.sg.statemem.dancinghat = hat
                                data = newdata
                            end
                        end
                    end
                end
                if inst.sg.statemem.dancinghat ~= nil and data.tags ~= nil then
                    for i, v in ipairs(data.tags) do
                        if not inst.sg:HasStateTag(v) then
                            inst.sg:AddStateTag(v)
                        end
                    end
                end
            end

            local anim = data.anim
            local animtype = type(anim)
            if data.randomanim and animtype == "table" then
                anim = anim[math.random(#anim)]
                animtype = type(anim)
            end
            if animtype == "table" and #anim <= 1 then
                anim = anim[1]
                animtype = type(anim)
            end

            if animtype == "string" then
                inst.AnimState:PlayAnimation(anim, data.loop)
                inst.sg.statemem.loopingemote = data.loop or nil
            elseif animtype == "table" then
                local maxanim = #anim
                inst.AnimState:PlayAnimation(anim[1])
                for i = 2, maxanim - 1 do
                    inst.AnimState:PushAnimation(anim[i])
                end
                inst.AnimState:PushAnimation(anim[maxanim], data.loop == true)
                inst.sg.statemem.loopingemote = data.loop or nil
            end

            if data.fx then --fx might be a boolean, so don't do ~= nil
                if data.fxdelay == nil or data.fxdelay == 0 then
                    DoEmoteFX(inst, data.fx)
                else
                    inst.sg.statemem.emotefxtask = inst:DoTaskInTime(data.fxdelay, DoEmoteFX, data.fx)
                end
            elseif data.fx ~= false then
                DoEmoteFX(inst, "emote_fx")
            end

            if data.sound then --sound might be a boolean, so don't do ~= nil
                if (data.sounddelay or 0) <= 0 then
                    inst.SoundEmitter:PlaySound(data.sound)
                else
                    inst.sg.statemem.emotesoundtask = inst:DoTaskInTime(data.sounddelay, DoForcedEmoteSound, data.sound)
                end
            elseif data.sound ~= false then
                if (data.sounddelay or 0) <= 0 then
                    DoEmoteSound(inst, data.soundoverride, data.soundlooped)
                else
                    inst.sg.statemem.emotesoundtask = inst:DoTaskInTime(data.sounddelay, DoEmoteSound, data.soundoverride, data.soundlooped)
                end
            end
        end,

        onupdate = function(inst)
            if inst.sg.statemem.loopingemote then
                local leader = GetLeader(inst)
                if leader ~= nil and leader.sg.currentstate.name ~= "emote" then
                    inst.sg:GoToState("idle")
                end
            end
        end,

        timeline =
        {
            TimeEvent(.5, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            -- inst._brain_emotedata = nil
            if inst.sg.statemem.emotefxtask ~= nil then
                inst.sg.statemem.emotefxtask:Cancel()
                inst.sg.statemem.emotefxtask = nil
            end
            if inst.sg.statemem.emotesoundtask ~= nil then
                inst.sg.statemem.emotesoundtask:Cancel()
                inst.sg.statemem.emotesoundtask = nil
            end
            if inst.SoundEmitter:PlayingSound("emotesoundloop") then
                inst.SoundEmitter:KillSound("emotesoundloop")
            end
            if inst.sg.statemem.dancinghat ~= nil and
                inst.sg.statemem.dancinghat == inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) and
                inst.sg.statemem.dancinghat.OnStopDancing ~= nil then
                inst.sg.statemem.dancinghat:OnStopDancing(inst)
            end

        end,
    },
}

CommonStates.AddInitState(states, "idle")

CommonStates.AddSinkAndWashAshoreStates(states,
{ -- anims
    sink = "sink",
    washashore = "wakeup",
},
{ -- timelines
    sink =
    {
        FrameEvent(14, function(inst)
            inst.AnimState:Show("float_front")
            inst.AnimState:Show("float_back")
        end),
        FrameEvent(16, function(inst)
            inst.components.drownable:DropInventory()
        end),
    },
},
{ -- fns
    sink_onenter = function(inst)
        inst.AnimState:Hide("plank")
        inst.AnimState:Hide("float_front")
        inst.AnimState:Hide("float_back")
        inst.AnimState:SetFrame(60) -- for fast sink
    end,
    sink_onexit = function(inst)
        inst.AnimState:Show("plank")
        inst.AnimState:Show("float_front")
        inst.AnimState:Show("float_back")
    end,
},
{ -- data
    skip_splash = true,
})
CommonStates.AddVoidFallStates(states,
{ -- anims
    fallinvoid = "abyss_fall",
    voiddrop = "fall_high",
},
{ -- timelines
    voiddrop =
    {
		SoundFrameEvent(12, "dontstarve/movement/bodyfall_dirt"),
		FrameEvent(14, function(inst)
			inst.sg:RemoveStateTag("noattack")
			inst.sg:RemoveStateTag("nointerrupt")
			-- ToggleOnPhysics(inst)
		end),
        FrameEvent(22, function(inst)
            inst.AnimState:SetLayer(LAYER_BELOW_GROUND)
        end),
	},
},
nil, -- fns
{ -- data
    skip_vfx = true,
})

local hop_timelines =
{
    hop_pre =
    {
        TimeEvent(0, function(inst)
            inst.components.embarker.embark_speed = math.clamp(inst.components.locomotor:RunSpeed() * inst.components.locomotor:GetSpeedMultiplier() + TUNING.WILSON_EMBARK_SPEED_BOOST, TUNING.WILSON_EMBARK_SPEED_MIN, TUNING.WILSON_EMBARK_SPEED_MAX)
        end),
    },
    hop_loop =
    {
        TimeEvent(0, function(inst)
            inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
        end),
    },
}

local function landed_in_falling_state(inst)
    if inst.components.drownable == nil then
        return nil
    end

    local fallingreason = inst.components.drownable:GetFallingReason()
    if fallingreason == nil then
        return nil
    end

    if fallingreason == FALLINGREASON.OCEAN then
        return "sink"
    elseif fallingreason == FALLINGREASON.VOID then
        return "abyss_fall"
    end

    return nil -- TODO(JBK): Fallback for unknown falling reason?
end

local hop_anims =
{
	pre = function(inst) return inst.components.inventory:IsHeavyLifting() and "boat_jumpheavy_pre" or "boat_jump_pre" end,
	loop = function(inst) return inst.components.inventory:IsHeavyLifting() and "boat_jumpheavy_loop" or "boat_jump_loop" end,
	pst = function(inst)
		if inst.components.inventory:IsHeavyLifting() then
			return "boat_jumpheavy_pst"
		elseif inst.components.embarker.embarkable and inst.components.embarker.embarkable:HasTag("teeteringplatform") then
			inst.sg:AddStateTag("teetering")
			return "boat_jump_to_teeter"
		end
		return "boat_jump_pst"
	end,
}

local function hop_land_sound(inst)
	return not inst.sg:HasStateTag("teetering") and "turnoftides/common/together/boat/jump_on" or nil
end

CommonStates.AddRowStates(states, false)
CommonStates.AddHopStates(states, true, hop_anims, hop_timelines, hop_land_sound, landed_in_falling_state, {start_embarking_pre_frame = 4*FRAMES})

SGWX78Common.AddWX78SpinStates(states)
SGWX78Common.AddWX78ShieldStates(states)
SGWX78Common.AddWX78ScreechStates(states)
SGWX78Common.AddWX78BakeState(states)
SGWX78Common.AddWX78UseDroneStates(states)

return StateGraph("wx78_possessedbody", states, events, "init", actionhandlers)