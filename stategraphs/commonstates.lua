local easing = require("easing")

CommonStates = {}
CommonHandlers = {}

--------------------------------------------------------------------------
local function ClearStatusAilments(inst)
	if inst.components.freezable and inst.components.freezable:IsFrozen() then
		inst.components.freezable:Unfreeze()
	end
	if inst.components.pinnable and inst.components.pinnable:IsStuck() then
		inst.components.pinnable:Unstick()
	end
end

--------------------------------------------------------------------------
local function onstep(inst)
    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/movement/run_dirt")
        --inst.SoundEmitter:PlaySound("dontstarve/movement/walk_dirt")
    end
end

CommonHandlers.OnStep = function()
    return EventHandler("step", onstep)
end

--------------------------------------------------------------------------
local function onsleep(inst)
	if not (inst.components.health and inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute")) then
        local fallingreason = inst.components.drownable and inst.components.drownable:GetFallingReason() or nil
        if fallingreason ~= nil and inst.sg:HasStateTag("jumping") then
            if fallingreason == FALLINGREASON.OCEAN then
                inst.sg:GoToState("sink")
            elseif fallingreason == FALLINGREASON.VOID then
                inst.sg:GoToState("abyss_fall")
            end
		else
		    inst.sg:GoToState(inst.sg:HasStateTag("sleeping") and "sleeping" or "sleep")
		end
    end
end

CommonHandlers.OnSleep = function()
    return EventHandler("gotosleep", onsleep)
end

--------------------------------------------------------------------------
local function onfreeze(inst)
    if inst.components.health ~= nil and not inst.components.health:IsDead() then
        inst.sg:GoToState("frozen")
    end
end

CommonHandlers.OnFreeze = function()
    return EventHandler("freeze", onfreeze)
end

--------------------------------------------------------------------------
--V2C: DST improved to support freezable entities with no health component

local function onfreezeex(inst)
    if not (inst.components.health ~= nil and inst.components.health:IsDead()) then
        inst.sg:GoToState("frozen")
    end
end

CommonHandlers.OnFreezeEx = function()
    return EventHandler("freeze", onfreezeex)
end

--------------------------------------------------------------------------
local function onfossilize(inst, data)
    if not (inst.components.health ~= nil and inst.components.health:IsDead() or inst.sg:HasStateTag("fossilized")) then
        if inst.sg:HasStateTag("nofreeze") then
            inst.components.fossilizable:OnSpawnFX()
        else
            inst.sg:GoToState("fossilized", data)
        end
    end
end

CommonHandlers.OnFossilize = function()
    return EventHandler("fossilize", onfossilize)
end

--------------------------------------------------------------------------
-- delay: how long before we can play another hit reaction animation, 
-- max_hitreacts: the number of hit reacts before we enter the react cooldown. The creature's AI may still early out of this.
-- skip_cooldown_fn: return true if you want to allow hit reacts while the hit react is in cooldown (allowing stun locking)
local function hit_recovery_delay(inst, delay, max_hitreacts, skip_cooldown_fn)
	local on_cooldown = false
	local was_projectile, was_electric
	local combat = inst.components.combat
	if combat then
		was_projectile = combat.lastattacktype == "projectile"
		was_electric = combat.laststimuli == "electric"
	end

	local delaytime = delay or inst.hit_recovery or TUNING.DEFAULT_HIT_RECOVERY
	if was_projectile then
		if was_electric and not IsEntityElectricImmune(inst) then
			--use melee hit recovery delay for electric projectiles
		else
			delaytime = delaytime * TUNING.DEFAULT_PROJECTILE_HIT_RECOVERY_MULTIPLIER
		end
	end

	if (inst._last_hitreact_time ~= nil and inst._last_hitreact_time + delaytime >= GetTime()) then	-- is hit react is on cooldown?
		max_hitreacts = max_hitreacts or inst._max_hitreacts
		if max_hitreacts then
			if was_projectile then
				local mult = TUNING.DEFAULT_PROJECTILE_MAX_HITREACTS_MULTIPLIER
				max_hitreacts = mult > 0 and max_hitreacts * mult or nil
			end
			if max_hitreacts then
				if inst._hitreact_count == nil then
					inst._hitreact_count = 2
					return false
				elseif inst._hitreact_count < max_hitreacts then
					inst._hitreact_count = inst._hitreact_count + 1
					return false
				end
			end
		end

		skip_cooldown_fn = skip_cooldown_fn or inst._hitreact_skip_cooldown_fn
		if skip_cooldown_fn ~= nil then
			on_cooldown = not skip_cooldown_fn(inst, inst._last_hitreact_time, delay)
		elseif combat then
			on_cooldown = not (combat:InCooldown() and inst.sg:HasStateTag("idle")) -- skip the hit react cooldown if the creature is idle but not ready to attack
		else
			on_cooldown = true
		end
	end

	if inst._hitreact_count ~= nil and not on_cooldown then
		inst._hitreact_count = 1
	end
	return on_cooldown
end

local function electrocute_recovery_delay(inst)
	local delay = inst.electrocute_delay or TUNING.ELECTROCUTE_DEFAULT_DELAY
	local resist = inst._electrocute_resist or 0
	local t = GetTime()
	if inst._last_electrocute_time == nil or inst._last_electrocute_time + math.max(10 * delay.max, delay.max + resist) < t then
		return false --first hit, no delay
	elseif inst._last_electrocute_delay == nil then
		inst._last_electrocute_delay = GetRandomMinMax(delay.min, delay.max) + resist
	end
	return inst._last_electrocute_time + inst._last_electrocute_delay > t
end

CommonHandlers.HitRecoveryDelay = hit_recovery_delay -- returns true if inst is still in a hit reaction cooldown
CommonHandlers.ElectrocuteRecoveryDelay = electrocute_recovery_delay

local function update_hit_recovery_delay(inst)
	inst._last_hitreact_time = GetTime()
end

local function update_electrocute_recovery_delay(inst)
	local t = GetTime()
	if inst._electrocute_resist then
		if inst._last_electrocute_time then
			local delay = inst.electrocute_delay or TUNING.ELECTROCUTE_DEFAULT_DELAY
			local dt = t - inst._last_electrocute_time
			if dt > delay.max then
				inst._electrocute_resist = math.max(0, inst._electrocute_resist - (dt - delay.max) / 10)
			end
		end
		inst._electrocute_resist = inst._electrocute_resist + 1
	elseif inst:HasTag("epic") then
		inst._electrocute_resist = 1
	end
	inst._last_electrocute_time = t
	inst._last_electrocute_delay = nil
end

CommonHandlers.UpdateHitRecoveryDelay = update_hit_recovery_delay
CommonHandlers.UpdateElectrocuteRecoveryDelay = update_electrocute_recovery_delay

CommonHandlers.ResetHitRecoveryDelay = function(inst)
	inst._last_hitreact_time = nil
	inst._last_hitreact_count = nil
end

CommonHandlers.ResetElectrocuteRecoveryDelay = function(inst)
	inst._last_electrocute_time = nil
	inst._last_electrocute_delay = nil
end

local function attack_can_electrocute(inst, data)
	if data and data.stimuli == "electric" then
		if data.weapon then
			local weapon = data.weapon.components.weapon
			if weapon and
				(	weapon.overridestimulifn and
					weapon.overridestimulifn(weapon.inst, data.attacker, inst) or
					weapon.stimuli
				) == "electric"
			then
				return true
			end
		end
		if data.attacker and data.attacker.components.electricattacks then
			return true
		end
	end
	return false
end

local function spawn_electrocute_fx(inst, data, duration)
	duration = duration or CalcEntityElectrocuteDuration(inst, data and data.duration)
	data = data and (
		data.attackdata and {
			attackdata = data.attackdata,
			targets = data.targets,
			numforks = data.numforks and data.numforks - 1 or nil,
			duration = data.duration,
			noburn = data.noburn,
		} or
		data.stimuli == "electric" and {
			attackdata = data,
			duration = data.duration,
			noburn = data.noburn,
		}
	) or nil
	local fx = SpawnPrefab("electrocute_fx")
	fx:SetFxTarget(inst, duration, data)
	return fx
end

--state & statedata are optional overrides if you don't
--want it to use the default electrocute or hit states.
local function try_goto_electrocute_state(inst, data, state, statedata, ongotostatefn)
	if state == nil then
        if inst:HasTag("creaturecorpse") and inst.sg:HasState("corpse_hit") then
            state = "corpse_hit"
		elseif inst.sg:HasState("electrocute") then
			state = "electrocute"
			statedata = data and (
				data.stimuli == "electric" and {
					attackdata = data,
					duration = data.duration,
					noburn = data.noburn,
				}
			) or data
		elseif inst.sg:HasState("hit") then
			state = "hit"
		else
			return false
		end
	end

	if state ~= "electrocute" then
		update_electrocute_recovery_delay(inst)
		spawn_electrocute_fx(inst, data)
		ClearStatusAilments(inst)
		if inst.components.sleeper then
			inst.components.sleeper:WakeUp()
		end
		if inst.sg.mem.burn_on_electrocute and not (data and data.noburn) and
			inst.components.burnable and not inst.components.burnable:IsBurning()
		then
			local attackdata = data and data.attackdata or data
			inst.components.burnable:Ignite(nil, attackdata and (attackdata.weapon or attackdata.attacker), attackdata and attackdata.attacker)
		end
	end
	if ongotostatefn then
		ongotostatefn(inst)
	end
	inst.sg:GoToState(state, statedata)
	return true
end

--state & statedata are optional overrides if you don't
--want it to use the default electrocute or hit states.
local function try_electrocute_onattacked(inst, data, state, statedata, ongotostatefn)
	return CanEntityBeElectrocuted(inst)
		and attack_can_electrocute(inst, data)
		and not (inst.components.inventory and inst.components.inventory:IsInsulated())
		--and not inst:HasTag("electricdamageimmune") --V2C: redundant. either shouldn't have "electrocute" states if immune, or if using a shared SG then set sg.mem.noelectrocute = true
		--NOTE: players (e.g. wx) still goto electrocute state even if "electricdamageimmune"
		--      so we actually CAN'T check the tag here, or it will break players' behaviour.
		and (not inst.sg:HasAnyStateTag("nointerrupt", "noelectrocute") or inst.sg:HasStateTag("canelectrocute"))
		and not electrocute_recovery_delay(inst)
		and try_goto_electrocute_state(inst, data, state, statedata, ongotostatefn)
end

CommonHandlers.AttackCanElectrocute = attack_can_electrocute
CommonHandlers.SpawnElectrocuteFx = spawn_electrocute_fx
CommonHandlers.TryGoToElectrocuteState = try_goto_electrocute_state
CommonHandlers.TryElectrocuteOnAttacked = try_electrocute_onattacked

local function onattacked(inst, data, hitreact_cooldown, max_hitreacts, skip_cooldown_fn)
	if inst.components.health and not inst.components.health:IsDead() then
		if try_electrocute_onattacked(inst, data) then
			return
		elseif not hit_recovery_delay(inst, hitreact_cooldown, max_hitreacts, skip_cooldown_fn) and
			(	not inst.sg:HasStateTag("busy") or
				inst.sg:HasAnyStateTag("caninterrupt", "frozen")
			)
		then
			inst.sg:GoToState("hit")
		end
	end
end

CommonHandlers.OnAttacked = function(hitreact_cooldown, max_hitreacts, skip_cooldown_fn) -- params are optional
	hitreact_cooldown = type(hitreact_cooldown) == "number" and hitreact_cooldown or nil -- validting the data because a lot of poeple were passing in 'true' for no reason

	if hitreact_cooldown ~= nil or max_hitreacts ~= nil or skip_cooldown_fn ~= nil then
		return EventHandler("attacked", function(inst, data) onattacked(inst, data, hitreact_cooldown, max_hitreacts, skip_cooldown_fn) end)
	else
	    return EventHandler("attacked", onattacked)
	end
end

--------------------------------------------------------------------------

--state & statedata are optional overrides if you don't
--want it to use the default electrocute or hit states.
local function try_electrocute_onevent(inst, data, state, statedata, ongotostatefn)
	return not (inst.components.inventory and inst.components.inventory:IsInsulated())
		--and not inst:HasTag("electricdamageimmune") and --V2C: redundant. either shouldn't have "electrocute" states if immune, or if using a shared SG then set sg.mem.noelectrocute = true
		--NOTE: players (e.g. wx) still goto electrocute state even if "electricdamageimmune"
		--      so we actually CAN'T check the tag here, or it will break players' behaviour.
		and not inst.sg.mem.noelectrocute
		and (not inst.sg:HasAnyStateTag("dead", "nointerrupt", "noelectrocute") or inst.sg:HasStateTag("canelectrocute"))
		and try_goto_electrocute_state(inst, data, state, statedata, ongotostatefn)
end

local function onelectrocute(inst, data)
	if not (inst.components.health and inst.components.health:IsDead()) then
		try_electrocute_onevent(inst, data)
	end
end

CommonHandlers.TryElectrocuteOnEvent = try_electrocute_onevent

CommonHandlers.OnElectrocute = function()
	return EventHandler("electrocute", onelectrocute)
end

--------------------------------------------------------------------------
local function onattack(inst)
	if inst.components.health and not inst.components.health:IsDead() and
		(	not inst.sg:HasStateTag("busy") or
			(inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute"))
		)
	then
        inst.sg:GoToState("attack")
    end
end

CommonHandlers.OnAttack = function()
    return EventHandler("doattack", onattack)
end

--------------------------------------------------------------------------

local function should_use_corpse_state_on_load(inst, cause)
    return cause == "file_load" and EntityHasCorpse(inst) and inst:GetDeathLootLevel() > 0
end
CommonHandlers.ShouldUseCorpseStateOnLoad = should_use_corpse_state_on_load

local function ondeath(inst, data)
	if not inst.sg:HasStateTag("dead") then
        local use_corpse_state = should_use_corpse_state_on_load(inst, data.cause)
        if use_corpse_state then
            inst.sg:GoToState("corpse", true)
        else
            inst.sg:GoToState("death", data)
        end
	end
end

CommonHandlers.OnDeath = function()
    return EventHandler("death", ondeath)
end

--------------------------------------------------------------------------
CommonHandlers.OnLocomote = function(can_run, can_walk)
    return EventHandler("locomote", function(inst)
        local is_moving = inst.sg:HasStateTag("moving")
        local is_running = inst.sg:HasStateTag("running")
        local is_idling = inst.sg:HasStateTag("idle")

        local should_move = inst.components.locomotor:WantsToMoveForward()
        local should_run = inst.components.locomotor:WantsToRun()

        if is_moving and not should_move then
            inst.sg:GoToState(is_running and "run_stop" or "walk_stop")
        elseif (is_idling and should_move) or (is_moving and should_move and is_running ~= should_run and can_run and can_walk) then
            if can_run and (should_run or not can_walk) then
                inst.sg:GoToState("run_start")
            elseif can_walk then
                inst.sg:GoToState("walk_start")
            end
        end
    end)
end

--------------------------------------------------------------------------
CommonStates.AddIdle = function(states, funny_idle_state, anim_override, timeline)
    table.insert(states, State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            local anim =
                (anim_override == nil and "idle_loop") or
                (type(anim_override) ~= "function" and anim_override) or
                anim_override(inst)

            --pushanim could be bool or string?
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation(anim, true)
            elseif not inst.AnimState:IsCurrentAnimation(anim) then
                inst.AnimState:PlayAnimation(anim, true)
            end

			if not pushanim then
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			end
        end,

        timeline = timeline,

		ontimeout = function(inst)
			inst.sg:GoToState(funny_idle_state and math.random() < 0.1 and funny_idle_state or "idle")
		end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg:GoToState(funny_idle_state and math.random() < 0.1 and funny_idle_state or "idle")
                end
            end),
        },
    })
end

--------------------------------------------------------------------------
CommonStates.AddSimpleState = function(states, name, anim, tags, finishstate, timeline, fns)
    table.insert(states, State{
        name = name,
        tags = tags or {},

        onenter = function(inst, params)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anim)
			if fns ~= nil and fns.onenter ~= nil then
				fns.onenter(inst, params)
			end
        end,

        timeline = timeline,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(finishstate or "idle")
                end
            end),
        },

		onexit = fns ~= nil and fns.onexit or nil
    })
end

--------------------------------------------------------------------------
local function performbufferedaction(inst)
    inst:PerformBufferedAction()
end

--------------------------------------------------------------------------
CommonStates.AddSimpleActionState = function(states, name, anim, time, tags, finishstate, timeline, fns)
    table.insert(states, State{
        name = name,
        tags = tags or {},

        onenter = function(inst, params)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anim)
			if fns ~= nil and fns.onenter ~= nil then
				fns.onenter(inst, params)
			end
        end,

        timeline = timeline or
        {
            TimeEvent(time, performbufferedaction),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(finishstate or "idle")
                end
            end),
        },

		onexit = fns ~= nil and fns.onexit or nil
    })
end

--------------------------------------------------------------------------
CommonStates.AddShortAction = function(states, name, anim, timeout, finishstate)
    table.insert(states, State{
        name = "name",
        tags = { "doing" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anim)
            inst.sg:SetTimeout(timeout or (6 * FRAMES))
        end,

        ontimeout = performbufferedaction,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(finishstate or "idle")
                end
            end),
        },
    })
end

--------------------------------------------------------------------------
local function idleonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState("idle")
    end
end

--------------------------------------------------------------------------
local function get_loco_anim(inst, override, default)
    return (override == nil and default)
        or (type(override) ~= "function" and override)
        or override(inst)
end

--------------------------------------------------------------------------
local function runonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState("run")
    end
end

local function runontimeout(inst)
    inst.sg:GoToState("run")
end

CommonStates.AddRunStates = function(states, timelines, anims, softstop, delaystart, fns)
    table.insert(states, State{
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
			if fns ~= nil and fns.startonenter ~= nil then -- this has to run before RunForward so that startonenter has a chance to update the run speed
				fns.startonenter(inst)
			end
			if delaystart then
				inst.components.locomotor:StopMoving()
			else
	            inst.components.locomotor:RunForward()
			end
            inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.startrun or nil, "run_pre"))
        end,

        timeline = timelines ~= nil and timelines.starttimeline or nil,

		onupdate = fns ~= nil and fns.startonupdate or nil,

		onexit = fns ~= nil and fns.startonexit or nil,

        events =
        {
            EventHandler("animover", runonanimover),
        },
    })

    table.insert(states, State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
			if fns ~= nil and fns.runonenter ~= nil then
				fns.runonenter(inst)
			end
            inst.components.locomotor:RunForward()
			--V2C: -normally we wouldn't restart an already looping anim
			--     -however, changing this might affect softstop behaviour
			--     -i.e. PushAnimation over a looping anim (first play vs subsequent loops)
			--     -why do we even tell it to loop here then?  for smoother playback on clients
			inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.run or nil, "run_loop"), true)
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline = timelines ~= nil and timelines.runtimeline or nil,

		onupdate = fns ~= nil and fns.runonupdate or nil,

		onexit = fns ~= nil and fns.runonexit or nil,

        ontimeout = runontimeout,
    })

    table.insert(states, State{
        name = "run_stop",
        tags = { "idle" },

        onenter = function(inst)
			if fns ~= nil and fns.endonenter ~= nil then
				fns.endonenter(inst)
			end
            inst.components.locomotor:StopMoving()
            if softstop == true or (type(softstop) == "function" and softstop(inst)) then
                inst.AnimState:PushAnimation(get_loco_anim(inst, anims ~= nil and anims.stoprun or nil, "run_pst"), false)
            else
                inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.stoprun or nil, "run_pst"))
            end
        end,

        timeline = timelines ~= nil and timelines.endtimeline or nil,

		onupdate = fns ~= nil and fns.endonupdate or nil,

		onexit = fns ~= nil and fns.endonexit or nil,

        events =
        {
            EventHandler("animqueueover", idleonanimover),
        },
    })
end

--------------------------------------------------------------------------
CommonStates.AddSimpleRunStates = function(states, anim, timelines)
    CommonStates.AddRunStates(states, timelines, { startrun = anim, run = anim, stoprun = anim } )
end

--------------------------------------------------------------------------
local function walkonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState("walk")
    end
end

local function walkontimeout(inst)
    inst.sg:GoToState("walk")
end

CommonStates.AddWalkStates = function(states, timelines, anims, softstop, delaystart, fns)
    table.insert(states, State{
        name = "walk_start",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
			if fns ~= nil and fns.startonenter ~= nil then -- this has to run before WalkForward so that startonenter has a chance to update the walk speed
				fns.startonenter(inst)
			end
			if delaystart then
				inst.components.locomotor:StopMoving()
			else
	            inst.components.locomotor:WalkForward()
			end
            inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.startwalk or nil, "walk_pre"))
        end,

        timeline = timelines ~= nil and timelines.starttimeline or nil,

		onupdate = fns ~= nil and fns.startonupdate or nil,

		onexit = fns ~= nil and fns.startonexit or nil,

        events =
        {
            EventHandler("animover", walkonanimover),
        },
    })

    table.insert(states, State{
        name = "walk",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
			if fns ~= nil and fns.walkonenter ~= nil then
				fns.walkonenter(inst)
			end
            inst.components.locomotor:WalkForward()
			--V2C: -normally we wouldn't restart an already looping anim
			--     -however, changing this might affect softstop behaviour
			--     -i.e. PushAnimation over a looping anim (first play vs subsequent loops)
			--     -why do we even tell it to loop here then?  for smoother playback on clients
            inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.walk or nil, "walk_loop"), true)
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline = timelines ~= nil and timelines.walktimeline or nil,

		onupdate = fns ~= nil and fns.walkonupdate or nil,

		onexit = fns ~= nil and fns.walkonexit or nil,

        ontimeout = walkontimeout,
    })

    table.insert(states, State{
        name = "walk_stop",
        tags = { "canrotate" },

        onenter = function(inst)
			if fns ~= nil and fns.endonenter ~= nil then
				fns.endonenter(inst)
			end
            inst.components.locomotor:StopMoving()
            if softstop == true or (type(softstop) == "function" and softstop(inst)) then
                inst.AnimState:PushAnimation(get_loco_anim(inst, anims ~= nil and anims.stopwalk or nil, "walk_pst"), false)
            else
                inst.AnimState:PlayAnimation(get_loco_anim(inst, anims ~= nil and anims.stopwalk or nil, "walk_pst"))
            end
        end,

        timeline = timelines ~= nil and timelines.endtimeline or nil,

		onupdate = fns ~= nil and fns.endonupdate or nil,

		onexit = fns ~= nil and fns.endonexit or nil,

        events =
        {
            EventHandler("animqueueover", idleonanimover),
        },
    })
end

--------------------------------------------------------------------------
CommonStates.AddSimpleWalkStates = function(states, anim, timelines)
    CommonStates.AddWalkStates(states, timelines, { startwalk = anim, walk = anim, stopwalk = anim }, true)
end

--------------------------------------------------------------------------
CommonHandlers.OnHop = function()
    return EventHandler("onhop",
        function(inst)
            if (inst.components.health == nil or not inst.components.health:IsDead()) and inst.sg:HasAnyStateTag("moving", "idle") then
                if not inst.sg:HasStateTag("jumping") then
                    if inst.components.embarker and inst.components.embarker.antic and inst:HasTag("swimming") then
                        inst.sg:GoToState("hop_antic")
                    else
                        inst.sg:GoToState("hop_pre")
                    end
                end
            elseif inst.components.embarker then
                inst.components.embarker:Cancel()
            end
        end)
end

local function DoHopLandSound(inst, land_sound)
	if inst:GetCurrentPlatform() ~= nil then
		inst.SoundEmitter:PlaySound(land_sound, nil, nil, true)
	end
end

CommonStates.AddHopStates = function(states, wait_for_pre, anims, timelines, land_sound, landed_in_falling_state, data, fns)
	anims = anims or {}
    timelines = timelines or {}
	data = data or {}

    table.insert(states, State{
        name = "hop_pre",
        tags = { "doing", "nointerrupt", "busy", "boathopping", "jumping", "autopredict", "nomorph", "nosleep" },

        onenter = function(inst)
			if fns and fns.pre_onenter then
				fns.pre_onenter(inst)
			end
            local embark_x, embark_z = inst.components.embarker:GetEmbarkPosition()
            inst:ForceFacePoint(embark_x, 0, embark_z)
            if not wait_for_pre then
				inst.sg.statemem.not_interrupted = true
                inst.sg:GoToState("hop_loop", inst.sg.statemem.queued_post_land_state)
			else
	            inst.AnimState:PlayAnimation(FunctionOrValue(anims.pre, inst) or "jump_pre", false)
				if data.start_embarking_pre_frame ~= nil then
					inst.sg:SetTimeout(data.start_embarking_pre_frame)
				end
            end
        end,

        timeline = timelines.hop_pre or nil,

		ontimeout = function(inst)
			inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
	        inst.Physics:SetCollisionMask(COLLISION.GROUND)
			if not TheWorld.ismastersim then
	            inst.Physics:SetLocalCollisionMask(COLLISION.GROUND)
			end
			inst.components.embarker:StartMoving()
            if fns and fns.pre_ontimeout then
                fns.pre_ontimeout(inst)
            end
		end,

        events =
        {
            EventHandler("animover",
                function(inst)
                    if wait_for_pre then
						inst.sg.statemem.not_interrupted = true
                        inst.sg:GoToState("hop_loop", {queued_post_land_state = inst.sg.statemem.queued_post_land_state, collisionmask = inst.sg.statemem.collisionmask})
                    end
                end),
            EventHandler("cancelhop", function(inst)
                inst.sg:GoToState("hop_cancelhop")
            end),
        },

		onexit = function(inst)
			if fns and fns.pre_onexit then
				fns.pre_onexit(inst)
			end
			if not inst.sg.statemem.not_interrupted then
				if data.start_embarking_pre_frame ~= nil then
					inst.Physics:ClearLocalCollisionMask()
					if inst.sg.statemem.collisionmask ~= nil then
						inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
					end
				end
	            inst.components.embarker:Cancel()
			end
		end,
    })

    table.insert(states, State{
        name = "hop_loop",
        tags = { "doing", "nointerrupt", "busy", "boathopping", "jumping", "autopredict", "nomorph", "nosleep" },

        onenter = function(inst, data)
			if fns and fns.loop_onenter then
				fns.loop_onenter(inst)
			end
			inst.sg.statemem.queued_post_land_state = data ~= nil and data.queued_post_land_state or nil
            inst.AnimState:PlayAnimation(FunctionOrValue(anims.loop, inst) or "jump_loop", true)
			inst.sg.statemem.collisionmask = data ~= nil and data.collisionmask or inst.Physics:GetCollisionMask()
	        inst.Physics:SetCollisionMask(COLLISION.GROUND)
			if not TheWorld.ismastersim then
	            inst.Physics:SetLocalCollisionMask(COLLISION.GROUND)
			end
            inst.components.embarker:StartMoving()
            inst:AddTag("ignorewalkableplatforms")
        end,

        timeline = timelines.hop_loop or nil,

        events =
        {
            EventHandler("done_embark_movement", function(inst)
                local px, _, pz = inst.Transform:GetWorldPosition()
				inst.sg.statemem.not_interrupted = true
                inst.sg:GoToState("hop_pst", {landed_in_water = not TheWorld.Map:IsPassableAtPoint(px, 0, pz), queued_post_land_state = inst.sg.statemem.queued_post_land_state} )
            end),
            EventHandler("cancelhop", function(inst)
                inst.sg:GoToState("hop_cancelhop")
            end),
        },

		onexit = function(inst)
			if fns and fns.loop_onexit then
				fns.loop_onexit(inst)
			end
            inst.Physics:ClearLocalCollisionMask()
			if inst.sg.statemem.collisionmask ~= nil then
                inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
			end
            inst:RemoveTag("ignorewalkableplatforms")
			if not inst.sg.statemem.not_interrupted then
	            inst.components.embarker:Cancel()
			end

			if inst.components.locomotor.isrunning then
                inst:PushEvent("locomote")
			end
		end,
    })

    table.insert(states, State{
        name = "hop_pst",
        tags = { "doing", "nointerrupt", "boathopping", "jumping", "autopredict", "nomorph", "nosleep" },

        onenter = function(inst, data)
			if fns and fns.pst_onenter then
				fns.pst_onenter(inst)
			end
            inst.AnimState:PlayAnimation(FunctionOrValue(anims.pst, inst) or "jump_pst", false)

            inst.components.embarker:Embark()

            local nextstate = "hop_pst_complete"
			if data ~= nil then
				nextstate = (
                                data.landed_in_water and landed_in_falling_state ~= nil and
                                (
                                    type(landed_in_falling_state) ~= "function" and landed_in_falling_state or landed_in_falling_state(inst)
                                )
                            )
							 or data.queued_post_land_state
							 or nextstate
			end
            if wait_for_pre then
                inst.sg.statemem.nextstate = nextstate
            else
                inst.sg:GoToState(nextstate)
            end
        end,

        timeline = timelines.hop_pst or nil,

        events =
        {
            EventHandler("animover", function(inst)
                if wait_for_pre then
                    inst.sg:GoToState(inst.sg.statemem.nextstate)
                end
            end),
        },

		onexit = function(inst)
			if fns and fns.pst_onexit then
				fns.pst_onexit(inst)
			end
			-- here for now, should be moved into timeline
			land_sound = FunctionOrValue(land_sound, inst)
			if land_sound ~= nil then
				--For now we just have the land on boat sound
				--Delay since inst:GetCurrentPlatform() may not be updated yet
				inst:DoTaskInTime(0, DoHopLandSound, land_sound)
            end
		end
    })

    table.insert(states, State{
        name = "hop_pst_complete",
        tags = {"autopredict", "nomorph", "nosleep" },

        onenter = function(inst)
			if fns and fns.pst_complete_onenter then
				fns.pst_complete_onenter(inst)
			end
			if inst.components.locomotor.isrunning then
                inst:DoTaskInTime(0,
                    function()
                        if inst.sg.currentstate.name == "hop_pst_complete" then
                            inst.sg:GoToState("idle")
                        end
                    end)
            else
                inst.sg:GoToState("idle")
            end
        end,

		onexit = fns and fns.pst_complete_onexit,
    })

    table.insert(states, State{
        name = "hop_cancelhop",
        tags = {"nopredict", "nomorph", "nosleep", "busy"},

        onenter = function(inst)
			if fns and fns.cancelhop_onenter then
				fns.cancelhop_onenter(inst)
			end
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(FunctionOrValue(anims.pst, inst) or "jump_pst", false)
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

		onexit = fns and fns.cancelhop_onexit,
    })
end

CommonStates.AddAmphibiousCreatureHopStates = function(states, config, anims, timelines, updates)
	config = config or {}
	anims = anims or {}
	timelines = timelines or {}

	local onenters = (config ~= nil and config.onenters ~= nil) and config.onenters or nil
	local onexits = (config ~= nil and config.onexits ~= nil) and config.onexits or nil

	local base_hop_pre_timeline = {
        TimeEvent(config.swimming_clear_collision_frame or 0, function(inst)
			if inst.sg.statemem.swimming then
				inst.Physics:ClearCollidesWith(COLLISION.LIMITS)
			end
		end),
	}
	timelines.hop_pre = timelines.hop_pre == nil and base_hop_pre_timeline or JoinArrays(timelines.hop_pre, base_hop_pre_timeline)

    table.insert(states, State{
        name = "hop_pre",
        tags = { "doing", "busy", "jumping", "canrotate" },

        onenter = function(inst)
			inst.sg.statemem.swimming = inst:HasTag("swimming")
            inst.AnimState:PlayAnimation(anims.pre or "jump")
			if not inst.sg.statemem.swimming then
				inst.Physics:ClearCollidesWith(COLLISION.LIMITS)
			end
			if inst.components.embarker:HasDestination() then
	            inst.sg:SetTimeout(18 * FRAMES)
                inst.components.embarker:StartMoving()
			else
	            inst.sg:SetTimeout(18 * FRAMES)
                if inst.landspeed then
                    inst.components.locomotor.runspeed = inst.landspeed
                end
                inst.components.locomotor:RunForward()
			end

			if onenters ~= nil and onenters.hop_pre ~= nil then
				onenters.hop_pre(inst)
			end
        end,

	    onupdate = function(inst,dt)
			if inst.components.embarker:HasDestination() then
				if inst.sg.statemem.embarked then
					inst.components.embarker:Embark()
					inst.sg:GoToState("hop_pst", false)
				elseif inst.sg.statemem.timeout then
					inst.components.embarker:Cancel()

					local x, y, z = inst.Transform:GetWorldPosition()
					inst.sg:GoToState("hop_pst", not TheWorld.Map:IsVisualGroundAtPoint(x, y, z) and inst:GetCurrentPlatform() == nil)
				end
            elseif inst.sg.statemem.timeout or
                   (inst.sg.statemem.tryexit and inst.sg.statemem.swimming == TheWorld.Map:IsVisualGroundAtPoint(inst.Transform:GetWorldPosition())) or
                   (not inst.components.locomotor.dest and not inst.components.locomotor.wantstomoveforward) then
				inst.components.embarker:Cancel()
				local x, y, z = inst.Transform:GetWorldPosition()
				inst.sg:GoToState("hop_pst", not TheWorld.Map:IsVisualGroundAtPoint(x, y, z) and inst:GetCurrentPlatform() == nil)
			end
		end,

        timeline = timelines.hop_pre,

		ontimeout = function(inst)
			inst.sg.statemem.timeout = true
		end,

        events =
        {
            EventHandler("done_embark_movement", function(inst)
				if not inst.AnimState:IsCurrentAnimation("jump_loop") then
					inst.AnimState:PlayAnimation(anims.loop or "jump_loop", false)
					inst.components.amphibiouscreature:OnExitOcean()
				end
				inst.sg.statemem.embarked = true
            end),
            EventHandler("animover", function(inst)
				if not inst.AnimState:IsCurrentAnimation("jump_loop") then
					if inst.AnimState:AnimDone() then
						if not inst.components.embarker:HasDestination() then
							inst.sg.statemem.tryexit = true
						end
					end
					inst.AnimState:PlayAnimation(anims.loop or "jump_loop", false)

					inst.components.amphibiouscreature:OnExitOcean()
				end
            end),
        },

		onexit = function(inst)
            inst.Physics:CollidesWith(COLLISION.LIMITS)
			if inst.components.embarker:HasDestination() then
				inst.components.embarker:Cancel()
			end

			if onexits ~= nil and onexits.hop_pre ~= nil then
				onexits.hop_pre(inst)
			end
		end,
    })

    table.insert(states, State{
        name = "hop_pst",
        tags = { "busy", "jumping" },

        onenter = function(inst, land_in_water)
			if land_in_water then
				inst.components.amphibiouscreature:OnEnterOcean()
			else
				inst.components.amphibiouscreature:OnExitOcean()
			end

			if onenters ~= nil and onenters.hop_pst ~= nil then
				onenters.hop_pst(inst)
			end

            inst.AnimState:PlayAnimation(anims.pst or "jump_pst")
        end,

        timeline = timelines.hop_pst,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			if onexits ~= nil and onexits.hop_pst ~= nil then
				onexits.hop_pst(inst)
			end
		end,
    })

    table.insert(states, State{
        name = "hop_antic",
        tags = { "doing", "busy", "jumping", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.sg.statemem.swimming = inst:HasTag("swimming")

            inst.AnimState:PlayAnimation(anims.antic or "jump_antic")

            inst.sg:SetTimeout(30 * FRAMES)

			if onenters ~= nil and onenters.hop_antic ~= nil then
				onenters.hop_antic(inst)
			end
        end,

        timeline = timelines.hop_antic,

        ontimeout = function(inst)
            inst.sg:GoToState("hop_pre")
        end,
        onexit = function(inst)
			if onexits ~= nil and onexits.hop_antic ~= nil then
				onexits.hop_antic(inst)
			end
        end,
    })
end

--------------------------------------------------------------------------
local function sleeponanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState("sleeping")
    end
end

local function onwakeup(inst)
	if not inst.sg:HasStateTag("nowake") then
	    inst.sg:GoToState("wake")
	end
end

local function onentersleeping(inst)
    inst.AnimState:PlayAnimation("sleep_loop")
end

CommonStates.AddSleepStates = function(states, timelines, fns)
    table.insert(states, State{
        name = "sleep",
        tags = { "busy", "sleeping" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("sleep_pre")
            if fns ~= nil and fns.onsleep ~= nil then
                fns.onsleep(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.starttimeline or nil,

        events =
        {
            EventHandler("animover", sleeponanimover),
            EventHandler("onwakeup", onwakeup),
        },
    })

    table.insert(states, State{
        name = "sleeping",
        tags = { "busy", "sleeping" },

        onenter = onentersleeping,

        onexit = fns and fns.onsleepexit or nil,

        timeline = timelines ~= nil and timelines.sleeptimeline or nil,

        events =
        {
            EventHandler("animover", sleeponanimover),
            EventHandler("onwakeup", onwakeup),
        },
    })

    table.insert(states, State{
        name = "wake",
        tags = { "busy", "waking" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("sleep_pst")
            if inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep() then
                inst.components.sleeper:WakeUp()
            end
            if fns ~= nil and fns.onwake ~= nil then
                fns.onwake(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.waketimeline or nil,

        events =
        {
            EventHandler("animover", idleonanimover),
        },
    })
end

--------------------------------------------------------------------------
local function onunfreeze(inst)
    inst.sg:GoToState(inst.sg.sg.states.hit ~= nil and "hit" or "idle")
end

local function onthaw(inst)
	inst.sg.statemem.thawing = true
    inst.sg:GoToState("thaw")
end

local function onenterfrozenpre(inst)
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:StopMoving()
    end
    inst.AnimState:PlayAnimation("frozen", true)
    inst.SoundEmitter:PlaySound("dontstarve/common/freezecreature")
    inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
end

local function onenterfrozenpst(inst)
    --V2C: cuz... freezable component and SG need to match state,
    --     but messages to SG are queued, so it is not great when
    --     when freezable component tries to change state several
    --     times within one frame...
    if inst.components.freezable == nil then
        onunfreeze(inst)
    elseif inst.components.freezable:IsThawing() then
        onthaw(inst)
    elseif not inst.components.freezable:IsFrozen() then
        onunfreeze(inst)
    end
end

local function onenterfrozen(inst)
    onenterfrozenpre(inst)
    onenterfrozenpst(inst)
end

local function onexitfrozen(inst)
	if not inst.sg.statemem.thawing then
		inst.AnimState:ClearOverrideSymbol("swap_frozen")
	end
end

local function onenterthawpre(inst)
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:StopMoving()
    end
    inst.AnimState:PlayAnimation("frozen_loop_pst", true)
    inst.SoundEmitter:PlaySound("dontstarve/common/freezethaw", "thawing")
    inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
end

local function onenterthawpst(inst)
    --V2C: cuz... freezable component and SG need to match state,
    --     but messages to SG are queued, so it is not great when
    --     when freezable component tries to change state several
    --     times within one frame...
    if inst.components.freezable == nil or not inst.components.freezable:IsFrozen() then
        onunfreeze(inst)
    end
end

local function onenterthaw(inst)
    onenterthawpre(inst)
    onenterthawpst(inst)
end

local function onexitthaw(inst)
    inst.SoundEmitter:KillSound("thawing")
    inst.AnimState:ClearOverrideSymbol("swap_frozen")
end

CommonStates.AddFrozenStates = function(states, onoverridesymbols, onclearsymbols)
    table.insert(states, State{
        name = "frozen",
        tags = { "busy", "frozen" },

        onenter = onoverridesymbols ~= nil and function(inst)
            onenterfrozenpre(inst)
            onoverridesymbols(inst)
            onenterfrozenpst(inst)
        end or onenterfrozen,

        events =
        {
            EventHandler("unfreeze", onunfreeze),
            EventHandler("onthaw", onthaw),
        },

        onexit = onclearsymbols ~= nil and function(inst)
            onexitfrozen(inst)
            onclearsymbols(inst)
        end or onexitfrozen,
    })

    table.insert(states, State{
        name = "thaw",
        tags = { "busy", "thawing" },

        onenter = onoverridesymbols ~= nil and function(inst)
            onenterthawpre(inst)
            onoverridesymbols(inst)
            onenterthawpst(inst)
        end or onenterthaw,

        events =
        {
            EventHandler("unfreeze", onunfreeze),
        },

        onexit = onclearsymbols ~= nil and function(inst)
            onexitthaw(inst)
            onclearsymbols(inst)
        end or onexitthaw,
    })
end

--------------------------------------------------------------------------
CommonStates.AddCombatStates = function(states, timelines, anims, fns, data)
    table.insert(states, State{
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation(
                ((anims == nil or anims.hit == nil) and "hit") or
                (type(anims.hit) ~= "function" and anims.hit) or
                anims.hit(inst)
            )

            if inst.SoundEmitter ~= nil and inst.sounds ~= nil and inst.sounds.hit ~= nil then
                inst.SoundEmitter:PlaySound(inst.sounds.hit)
            end

			update_hit_recovery_delay(inst)
        end,

        timeline = timelines ~= nil and timelines.hittimeline or nil,

        events =
        {
            EventHandler("animover", fns ~= nil and fns.onhitanimover or idleonanimover),
        },
    })

    table.insert(states, State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anims ~= nil and anims.attack or (fns and fns.attackanimfn and fns.attackanimfn(inst)) or "atk")
            inst.components.combat:StartAttack()

            --V2C: Cached to force the target to be the same one later in the timeline
            --     e.g. combat:DoAttack(inst.sg.statemem.target)
            inst.sg.statemem.target = target
        end,

        timeline = timelines ~= nil and timelines.attacktimeline or nil,

        events =
        {
            EventHandler("animover", idleonanimover),
        },

		onexit = fns and fns.attackexit,
    })

    table.insert(states, State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst, data)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anims ~= nil and anims.death or (fns and fns.deathanimfn and fns.deathanimfn(inst, data)) or "death")
            RemovePhysicsColliders(inst)
            inst:DropDeathLoot()

            if fns ~= nil and fns.deathenter ~= nil then
                fns.deathenter(inst)
            end
        end,

        events = data ~= nil and data.has_corpse_handler and
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        } or nil,

        timeline = timelines ~= nil and timelines.deathtimeline or nil,

		onexit = fns and fns.deathexit,
    })
end

--------------------------------------------------------------------------
CommonStates.AddHitState = function(states, timeline, anim)
    table.insert(states, State{
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            local hitanim =
                (anim == nil and "hit") or
                (type(anim) ~= "function" and anim) or
                anim(inst)

            inst.AnimState:PlayAnimation(hitanim)

            if inst.SoundEmitter ~= nil and inst.sounds ~= nil and inst.sounds.hit ~= nil then
                inst.SoundEmitter:PlaySound(inst.sounds.hit)
            end

			update_hit_recovery_delay(inst)
        end,

        timeline = timeline,

        events =
        {
            EventHandler("animover", idleonanimover),
        },
    })
end

--------------------------------------------------------------------------
CommonStates.AddElectrocuteStates = function(states, timelines, anims, fns)
	table.insert(states, State{
		name = "electrocute",
		tags = { "electrocute", "hit", "busy", "noelectrocute", "nosleep" },

		onenter = function(inst, data)
			ClearStatusAilments(inst)
			if inst.components.sleeper then
				inst.components.sleeper:WakeUp()
			end
			if inst.components.locomotor then
				inst.components.locomotor:StopMoving()
			end

			inst.sg.statemem.data = data

			local anim = anims and FunctionOrValue(anims.loop, inst) or "shock_loop"
			inst.AnimState:PlayAnimation(anim, true)

			if inst.SoundEmitter and inst.sounds and inst.sounds.hit then
				inst.SoundEmitter:PlaySound(inst.sounds.hit)
			end

			local duration = CalcEntityElectrocuteDuration(inst, data and data.duration)

			update_hit_recovery_delay(inst)
			update_electrocute_recovery_delay(inst)
			inst.sg.statemem.fx = spawn_electrocute_fx(inst, data, duration)

			inst.sg:SetTimeout(duration)

			if fns and fns.loop_onenter then
				fns.loop_onenter(inst)
			end
			inst:PushEvent("startelectrocute")
		end,

		timeline = timelines and timelines.loop,

		ontimeout = function(inst)
			if inst.components.sleeper then
				inst.components.sleeper:WakeUp()
			end
			inst.sg.statemem.not_interrupted = true
			inst.sg:GoToState("electrocute_pst")
		end,

		onexit = function(inst)
			if inst.sg.mem.burn_on_electrocute then
				local data = inst.sg.statemem.data
				if not (data and data.noburn) and inst.components.burnable and not inst.components.burnable:IsBurning() then
					local attackdata = data and data.attackdata or data
					inst.components.burnable:Ignite(nil, attackdata and (attackdata.weapon or attackdata.attacker), attackdata and attackdata.attacker)
				end
			end
			if fns and fns.loop_onexit then
				fns.loop_onexit(inst)
			end
		end,
	})

	table.insert(states, State{
		name = "electrocute_pst",
		tags = { "electrocute", "hit", "busy", "noelectrocute" },

		onenter = function(inst)
			if inst.components.locomotor then
				inst.components.locomotor:StopMoving()
			end

			local anim = anims and FunctionOrValue(anims.pst, inst) or "shock_pst"
			inst.AnimState:PlayAnimation(anim)

			if fns and fns.pst_onenter then
				fns.pst_onenter(inst)
			end
		end,

		timeline = timelines and timelines.pst,

		events =
		{
			EventHandler("animover", fns and fns.onanimover or idleonanimover),
		},

		onexit = fns and fns.pst_onexit,
	})
end

--------------------------------------------------------------------------
CommonStates.AddDeathState = function(states, timeline, anim, fns, data)
    table.insert(states, State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation(anim or "death")
            RemovePhysicsColliders(inst)
            inst:DropDeathLoot()

            if fns ~= nil and fns.deathenter ~= nil then
                fns.deathenter(inst)
            end
        end,

        timeline = timeline,

        events = data ~= nil and data.has_corpse_handler and
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        } or nil,

		onexit = fns and fns.deathexit,
    })
end

--------------------------------------------------------------------------
--V2C: DST improved sleep states that support "nosleep" state tag

local function onsleepex(inst)
    inst.sg.mem.sleeping = true
	if inst.components.health == nil or not inst.components.health:IsDead() then
        local fallingreason = inst.components.drownable and inst.components.drownable:GetFallingReason() or nil
        if fallingreason ~= nil and inst.sg:HasStateTag("jumping") then
            if fallingreason == FALLINGREASON.OCEAN then
                inst.sg:GoToState("sink")
            elseif fallingreason == FALLINGREASON.VOID then
                inst.sg:GoToState("abyss_fall")
            end
		elseif not inst.sg:HasAnyStateTag("nosleep", "sleeping") then
		    inst.sg:GoToState("sleep")
		end
    end
end

local function onwakeex(inst)
    inst.sg.mem.sleeping = false
    if inst.sg:HasStateTag("sleeping") and not inst.sg:HasStateTag("nowake") and
        not (inst.components.health ~= nil and inst.components.health:IsDead()) then
        inst.sg.statemem.continuesleeping = true
        inst.sg:GoToState("wake")
    end
end

CommonHandlers.OnSleepEx = function()
    return EventHandler("gotosleep", onsleepex)
end

CommonHandlers.OnWakeEx = function()
    return EventHandler("onwakeup", onwakeex)
end

CommonHandlers.OnNoSleepAnimOver = function(nextstate)
    return EventHandler("animover", function(inst)
        if inst.AnimState:AnimDone() then
            if inst.sg.mem.sleeping then
                inst.sg:GoToState("sleep")
            elseif type(nextstate) == "string" then
                inst.sg:GoToState(nextstate)
            elseif nextstate ~= nil then
                nextstate(inst)
            end
        end
    end)
end

CommonHandlers.OnNoSleepAnimQueueOver = function(nextstate)
	return EventHandler("animqueueover", function(inst)
		if inst.AnimState:AnimDone() then
			if inst.sg.mem.sleeping then
				inst.sg:GoToState("sleep")
			elseif type(nextstate) == "string" then
				inst.sg:GoToState(nextstate)
			elseif nextstate then
				nextstate(inst)
			end
		end
	end)
end

CommonHandlers.OnNoSleepTimeEvent = function(t, fn)
    return TimeEvent(t, function(inst)
        if inst.sg.mem.sleeping and not (inst.components.health ~= nil and inst.components.health:IsDead()) then
            inst.sg:GoToState("sleep")
        elseif fn ~= nil then
            fn(inst)
        end
    end)
end

CommonHandlers.OnNoSleepFrameEvent = function(frame, fn)
	return CommonHandlers.OnNoSleepTimeEvent(frame * FRAMES, fn)
end

local function sleepexonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg.statemem.continuesleeping = true
        inst.sg:GoToState(inst.sg.mem.sleeping and "sleeping" or "wake")
    end
end

local function sleepingexonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg.statemem.continuesleeping = true
        inst.sg:GoToState("sleeping")
    end
end

local function wakeexonanimover(inst)
    if inst.AnimState:AnimDone() then
        inst.sg:GoToState(inst.sg.mem.sleeping and "sleep" or "idle")
    end
end

CommonStates.AddSleepExStates = function(states, timelines, fns)
    table.insert(states, State{
        name = "sleep",
        tags = { "busy", "sleeping", "nowake" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("sleep_pre")
            if fns ~= nil and fns.onsleep ~= nil then
                fns.onsleep(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.starttimeline or nil,

        events =
        {
            EventHandler("animover", sleepexonanimover),
        },

        onexit = function(inst)
            if not inst.sg.statemem.continuesleeping and inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep() then
                inst.components.sleeper:WakeUp()
            end
            if fns ~= nil and fns.onexitsleep ~= nil then
                fns.onexitsleep(inst)
            end
        end,
    })

    table.insert(states, State{
        name = "sleeping",
        tags = { "busy", "sleeping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("sleep_loop")
            if fns ~= nil and fns.onsleeping ~= nil then
                fns.onsleeping(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.sleeptimeline or nil,

        events =
        {
            EventHandler("animover", sleepingexonanimover),
        },

        onexit = function(inst)
            if not inst.sg.statemem.continuesleeping and inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep() then
                inst.components.sleeper:WakeUp()
            end
            if fns ~= nil and fns.onexitsleeping ~= nil then
                fns.onexitsleeping(inst)
            end
        end,
    })

    table.insert(states, State{
        name = "wake",
        tags = { "busy", "waking", "nosleep" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("sleep_pst")
            if inst.components.sleeper ~= nil and inst.components.sleeper:IsAsleep() then
                inst.components.sleeper:WakeUp()
            end
            if fns ~= nil and fns.onwake ~= nil then
                fns.onwake(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.waketimeline or nil,

        events =
        {
            EventHandler("animover", wakeexonanimover),
        },

        onexit = fns ~= nil and fns.onexitwake or nil,
    })
end

--------------------------------------------------------------------------

CommonStates.AddFossilizedStates = function(states, timelines, fns)
    table.insert(states, State{
        name = "fossilized",
        tags = { "busy", "fossilized", "caninterrupt" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("fossilized")
            inst.components.fossilizable:OnFossilize(data ~= nil and data.duration or nil, data ~= nil and data.doer or nil)
            if fns ~= nil and fns.fossilized_onenter ~= nil then
                fns.fossilized_onenter(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.fossilizedtimeline or nil,

        events =
        {
            EventHandler("fossilize", function(inst, data)
                inst.components.fossilizable:OnExtend(data ~= nil and data.duration or nil, data ~= nil and data.doer or nil)
            end),
            EventHandler("unfossilize", function(inst)
                inst.sg.statemem.unfossilizing = true
                inst.sg:GoToState("unfossilizing")
            end),
        },

        onexit = function(inst)
            inst.components.fossilizable:OnUnfossilize()
            if not inst.sg.statemem.unfossilizing then
                --Interrupted
                inst.components.fossilizable:OnSpawnFX()
            end
            if fns ~= nil and fns.fossilized_onexit ~= nil then
                fns.fossilized_onexit(inst)
            end
        end,
    })

    table.insert(states, State{
        name = "unfossilizing",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("fossilized_shake")
            if fns ~= nil and fns.unfossilizing_onenter ~= nil then
                fns.unfossilizing_onenter(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.unfossilizingtimeline or nil,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.unfossilized = true
                    inst.sg:GoToState("unfossilized")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.unfossilized then
                --Interrupted
                inst.components.fossilizable:OnSpawnFX()
            end
            if fns ~= nil and fns.unfossilizing_onexit ~= nil then
                fns.unfossilizing_onexit(inst)
            end
        end,
    })

    table.insert(states, State{
        name = "unfossilized",
        tags = { "busy", "caninterrupt" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("fossilized_pst")
            inst.components.fossilizable:OnSpawnFX()
            if fns ~= nil and fns.unfossilized_onenter ~= nil then
                fns.unfossilized_onenter(inst)
            end
        end,

        timeline = timelines ~= nil and timelines.unfossilizedtimeline or nil,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = fns ~= nil and fns.unfossilized_onexit or nil,
    })
end

--------------------------------------------------------------------------

local function GetRowHandAndFacing(inst)
	local boat = inst:GetCurrentPlatform()
	if boat then
		local target_x, _, target_z
		local buffaction = inst:GetBufferedAction()
		if buffaction then
			local target_pos = buffaction:GetActionPoint()
			if target_pos then
				target_x, _, target_z = target_pos:Get()
			elseif buffaction.target then
				target_x, _, target_z = buffaction.target.Transform:GetWorldPosition()
				inst:ForceFacePoint(target_x, 0, target_z)
			end
		end
		if target_x == nil then
			target_x, _, target_z = inst.Transform:GetWorldPosition()
		end

		local x, _, z = inst.Transform:GetWorldPosition()
		local dir = boat:GetAngleToPoint(x, 0, z)
		local delta = dir / 45
		local seg = math.floor(delta)
		delta = delta - seg
		local lefthand = delta < 0.5
		seg = (lefthand and seg or seg + 1) * 45
		if not (inst.components.playercontroller and inst.components.playercontroller.isclientcontrollerattached) and
			(x ~= target_x or z ~= target_z)
		then
			local dir2 = math.atan2(z - target_z, target_x - x) * RADIANS
			local diff = ReduceAngle(dir2 - dir)
			if diff > 0 then
				if not lefthand then
					lefthand = true
					dir = seg + 1
				end
			elseif diff < 0 and lefthand then
				lefthand = false
				dir = seg - 1
			end
		end
		if dir == seg then
			dir = seg + (lefthand and 1 or -1)
		end
		return dir, lefthand
	end
end

CommonStates.AddRowStates = function(states, is_client)
    table.insert(states, State{
        name = "row",
        tags = { "rowing", "doing" },

        onenter = function(inst)
			local dir, lefthand = GetRowHandAndFacing(inst)
            inst:AddTag("is_rowing")
            inst.AnimState:PlayAnimation("row_pre")
			inst.components.locomotor:Stop()

            if is_client then
                inst:PerformPreviewBufferedAction()
            end

			if dir then
				inst.Transform:SetRotation(dir)
			end
			inst.AnimState:PushAnimation(lefthand and "row_medium_off" or "row_medium", false)
        end,

        onexit = function(inst)
            inst:RemoveTag("is_rowing")
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst)
                if not is_client then
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/small")
                end
            end),

            TimeEvent(8 * FRAMES, function(inst)
                if not is_client then
                    inst:PerformBufferedAction()
                end
            end),

            TimeEvent(13 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("rowing")
            end),
        },

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("row_idle")
				end
            end),
        },

        ontimeout = function(inst)
            if is_client then
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle")
            end
        end,
    })

    table.insert(states, State{
        name = "row_fail",
        tags = { "busy", "row_fail" },

        onenter = function(inst)
			local dir, lefthand = GetRowHandAndFacing(inst)
            if is_client then
                inst:PerformPreviewBufferedAction()
            else
                inst:PerformBufferedAction()
            end
            inst:AddTag("is_row_failing")
            inst.components.locomotor:Stop()

			if dir then
				inst.Transform:SetRotation(dir)
			end
            inst.AnimState:PlayAnimation("row_fail_pre")
			inst.AnimState:PushAnimation(lefthand and "row_fail_off" or "row_fail", false)
        end,

        onexit = function(inst)
            inst:RemoveTag("is_row_failing")
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst)
                if not is_client then
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/small")
                end
            end),

            TimeEvent(13 * FRAMES, function(inst)
                if not is_client then
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/small")
                end
            end),
        },

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("row_idle")
				end
            end),
        },

        ontimeout = function(inst)
            if is_client then
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle")
            end
        end,
    })


    table.insert(states, State{
        name = "row_idle",

        onenter = function(inst)
            inst.sg:SetTimeout(4 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.AnimState:PlayAnimation("row_idle_pst")
            inst.sg:GoToState("idle", true)
        end,
    })

end

--------------------------------------------------------------------------

local function onsink(inst, data)
    if (inst.components.health == nil or not inst.components.health:IsDead()) and not inst.sg:HasStateTag("drowning") and (inst.components.drownable ~= nil and inst.components.drownable:ShouldDrown()) then
        inst.sg:GoToState("sink", data)
    end
end

CommonHandlers.OnSink = function()
    return EventHandler("onsink", onsink)
end

local function DoWashAshore(inst, skip_splash)
	if not skip_splash then
		SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
	end

	inst.sg.statemem.isteleporting = true
	inst:Hide()
	if inst.components.health ~= nil then
		inst.components.health:SetInvincible(true)
	end
	inst.components.drownable:WashAshore()
end

CommonStates.AddSinkAndWashAshoreStates = function(states, anims, timelines, fns)
	anims = anims or {}
	timelines = timelines or {}
	fns = fns or {}

    table.insert(states, State{
        name = "sink",
		tags = { "busy", "nopredict", "nomorph", "drowning", "nointerrupt", "nosleep" },

        onenter = function(inst, data)
            inst:ClearBufferedAction()

            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

			inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
	        inst.Physics:SetCollisionMask(COLLISION.GROUND)

			if data ~= nil and data.shore_pt ~= nil then
				inst.components.drownable:OnFallInOcean(data.shore_pt:Get())
			else
				inst.components.drownable:OnFallInOcean()
			end

			if inst.DynamicShadow ~= nil then
			    inst.DynamicShadow:Enable(false)
			end

			inst:StopBrain("sinking")

			local skip_anim = data ~= nil and data.noanim
			if anims.sink ~= nil and not skip_anim then
				inst.sg.statemem.has_anim = true
	            inst.AnimState:PlayAnimation(anims.sink)
			else
				DoWashAshore(inst, skip_anim)
			end

        end,

		timeline = timelines.sink,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.has_anim and inst.AnimState:AnimDone() then
					DoWashAshore(inst)
				end
            end),

            EventHandler("on_washed_ashore", function(inst)
				if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
					inst.components.sleeper:WakeUp()
				end
				ClearStatusAilments(inst)
				inst.sg:GoToState("washed_ashore")
			end),
        },

        onexit = function(inst)
			if inst.sg.statemem.collisionmask ~= nil then
				inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
			end

            if inst.sg.statemem.isteleporting then
				if inst.components.health ~= nil then
					inst.components.health:SetInvincible(false)
				end
				inst:Show()
			end

			if inst.DynamicShadow ~= nil then
				inst.DynamicShadow:Enable(true)
			end

			if inst.components.herdmember ~= nil then
				inst.components.herdmember:Leave()
			end

			if inst.components.combat ~= nil then
				inst.components.combat:DropTarget()
			end

			inst:RestartBrain("sinking")
        end,
    })

	table.insert(states, State{
		name = "washed_ashore",
        tags = { "doing", "busy", "nopredict", "silentmorph" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			if type(anims.washashore) == "table" then
				for i, v in ipairs(anims.washashore) do
					if i == 1 then
			            inst.AnimState:PlayAnimation(v)
					else
			            inst.AnimState:PushAnimation(v, false)
					end
				end
			elseif anims.washashore ~= nil then
				inst.AnimState:PlayAnimation(anims.washashore)
			else
				inst.AnimState:PlayAnimation("sleep_loop")
	            inst.AnimState:PushAnimation("sleep_pst", false)
			end

			inst:StopBrain("washed_ashore")

			if inst.components.drownable ~= nil then
				inst.components.drownable:TakeDrowningDamage()
			end

			local x, y, z = inst.Transform:GetWorldPosition()
			SpawnPrefab("washashore_puddle_fx").Transform:SetPosition(x, y, z)
			SpawnPrefab("splash_green").Transform:SetPosition(x, y, z)
        end,

		timeline = timelines.washashore,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			inst:RestartBrain("washed_ashore")
        end,
	})
end

--Backward compatibility for originally mispelt function name
CommonStates.AddSinkAndWashAsoreStates = CommonStates.AddSinkAndWashAshoreStates

------------ Void falling! ------------

local function onfallinvoid(inst, data)
    if (inst.components.health == nil or not inst.components.health:IsDead()) and not inst.sg:HasStateTag("falling") and (inst.components.drownable ~= nil and inst.components.drownable:ShouldFallInVoid()) then
        inst.sg:GoToState("abyss_fall", data)
    end
end

CommonHandlers.OnFallInVoid = function()
    return EventHandler("onfallinvoid", onfallinvoid)
end

local function DoVoidFall(inst, skip_vfx)
    if not skip_vfx then
        local x, y, z = inst.Transform:GetWorldPosition()
        SpawnPrefab("fallingswish_clouds").Transform:SetPosition(x, y, z)
        SpawnPrefab("fallingswish_lines").Transform:SetPosition(x, y, z)
    end
    inst.sg.statemem.isteleporting = true
    inst:Hide()
    if inst.components.health ~= nil then
        inst.components.health:SetInvincible(true)
    end
    if inst.components.drownable ~= nil then
        inst.components.drownable:VoidArrive()
    else
        inst:PutBackOnGround()
    end
end

CommonStates.AddVoidFallStates = function(states, anims, timelines, fns)
	anims = anims or {}
	timelines = timelines or {}
	fns = fns or {}

    table.insert(states, State{
        name = "abyss_fall",
		tags = { "busy", "nopredict", "nomorph", "falling", "nointerrupt", "nosleep" },

        onenter = function(inst, data)
            inst:ClearBufferedAction()

            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

			inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
	        inst.Physics:SetCollisionMask(COLLISION.GROUND)

			if data ~= nil and data.teleport_pt ~= nil then
				inst.components.drownable:OnFallInVoid(data.teleport_pt:Get())
			else
				inst.components.drownable:OnFallInVoid()
			end

			if inst.DynamicShadow ~= nil then
			    inst.DynamicShadow:Enable(false)
			end

			inst:StopBrain("abyss_fall")

			local skip_anim = data ~= nil and data.noanim
			if anims.fallinvoid ~= nil and not skip_anim then
				inst.sg.statemem.has_anim = true
	            inst.AnimState:PlayAnimation(anims.fallinvoid)
                -- TODO(JBK): Add inst.AnimState:SetLayer(LAYER_BELOW_GROUND) and inst.AnimState:SetLayer(LAYER_WORLD) timing if overriding the animation.
			else
				DoVoidFall(inst, skip_anim)
			end

        end,

		timeline = timelines.fallinvoid,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.has_anim and inst.AnimState:AnimDone() then
					DoVoidFall(inst)
				end
            end),

            EventHandler("on_void_arrive", function(inst)
				if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
					inst.components.sleeper:WakeUp()
				end
				ClearStatusAilments(inst)
				inst.sg:GoToState("abyss_drop")
			end),
        },

        onexit = function(inst)
			if inst.sg.statemem.collisionmask ~= nil then
				inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
			end

            if inst.sg.statemem.isteleporting then
				if inst.components.health ~= nil then
					inst.components.health:SetInvincible(false)
				end
				inst:Show()
			end

			if inst.DynamicShadow ~= nil then
				inst.DynamicShadow:Enable(true)
			end

			if inst.components.herdmember ~= nil then
				inst.components.herdmember:Leave()
			end

			if inst.components.combat ~= nil then
				inst.components.combat:DropTarget()
			end

			inst:RestartBrain("abyss_fall")
        end,
    })

    table.insert(states, State{
        name = "abyss_drop",
        tags = { "doing", "busy", "nopredict", "silentmorph" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            if type(anims.voiddrop) == "table" then
                for i, v in ipairs(anims.voiddrop) do
                    if i == 1 then
                        inst.AnimState:PlayAnimation(v)
                    else
                        inst.AnimState:PushAnimation(v, false)
                    end
                end
            elseif anims.voiddrop ~= nil then
                inst.AnimState:PlayAnimation(anims.voiddrop)
            else
                inst.AnimState:PlayAnimation("sleep_loop")
                inst.AnimState:PushAnimation("sleep_pst", false)
            end

			inst:StopBrain("abyss_drop")

            local x, y, z = inst.Transform:GetWorldPosition()
            SpawnPrefab("fallingswish_clouds_fast").Transform:SetPosition(x, y, z)
        end,

		timeline = timelines.fallinvoid,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
			inst:RestartBrain("abyss_drop")
        end,
	})
end

--------------------------------------------------------------------------

function PlayMiningFX(inst, target, nosound)
    if target ~= nil and target:IsValid() then
        local frozen = target:HasTag("frozen")
        local moonglass = target:HasAnyTag("moonglass", "LunarBuildup")
        local crystal = target:HasTag("crystal")
        if target.Transform ~= nil then
            SpawnPrefab(
                (frozen and "mining_ice_fx") or
                (moonglass and "mining_moonglass_fx") or
                (crystal and "mining_crystal_fx") or
                "mining_fx"
            ).Transform:SetPosition(target.Transform:GetWorldPosition())
        end
        if not nosound and inst.SoundEmitter ~= nil then
            inst.SoundEmitter:PlaySound(
                (frozen and "dontstarve_DLC001/common/iceboulder_hit") or
                ((moonglass or crystal) and "turnoftides/common/together/moon_glass/mine") or
                "dontstarve/wilson/use_pick_rock"
            )
        end
    end
end

--------------------------------------------------------------------------

local function IpecacPoop(inst)
    if not (inst.sg:HasStateTag("busy") or (inst.components.health ~= nil and inst.components.health:IsDead())) then
        inst.sg:GoToState("ipecacpoop")
    end
end

CommonHandlers.OnIpecacPoop = function()
    return EventHandler("ipecacpoop", IpecacPoop)
end

CommonStates.AddIpecacPoopState = function(states, anim)
    anim = anim or "hit"

    table.insert(states, State{
        name = "ipecacpoop",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("meta2/wormwood/laxative_poot")
            inst.AnimState:PlayAnimation(anim)
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", idleonanimover),
        },
    })
end

--------------------------------------------------------------------------

CommonStates.AddCorpseStates = function(states, anims, fns, overridecorpseprefab)
    anims = anims or {}
    -- For actual mob
    local function DoCorpseErode(inst)
        ErodeAway(inst)
        --
        if fns and fns.corpseonerode then
            fns.corpseonerode(inst)
        end
    end

    table.insert(states, State{
		name = "corpse",
		tags = { "dead", "busy", "noattack" },

		onenter = function(inst, loading)
            if fns and fns.corpseonenter then
                fns.corpseonenter(inst, loading)
            end

            -- Assuming the death animation is one animation. Is there a case where it's split up?
            inst.sg.statemem.deathtimeelapsed = (inst.AnimState:GetCurrentAnimationNumFrames() + 1) * FRAMES
			
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:Stop()
            end

            if inst.components.health.is_corpsing then
                local anim, loop = FunctionOrValue(anims.corpse, inst)
			    inst.AnimState:PlayAnimation(anim or "corpse", loop)
            end
		end,

		timeline =
		{
            --a 1 frame delay in case we are loading
            FrameEvent(1, function(inst)
                local corpseprefab = overridecorpseprefab or inst.sg.sg.name.."corpse"
                local corpse = TryEntityToCorpse(inst, corpseprefab) or nil
                if corpse == nil then
	        		inst:AddTag("NOCLICK")
	        		inst.persists = false
	        		RemovePhysicsColliders(inst)

	        		-- time since death anim started
	        		local delay = (inst.components.health.destroytime or 2) - inst.sg.statemem.deathtimeelapsed
                    if delay > 0 then
	        			inst.sg:SetTimeout(delay)
	        		else
	        			DoCorpseErode(inst)
	        		end
                elseif fns and fns.corpseoncreate ~= nil then
                    fns.corpseoncreate(inst, corpse)
                end
            end)
		},

		ontimeout = DoCorpseErode,
	})

    -- For corpse prefab
    table.insert(states, State{
        name = "corpse_idle",
        tags = { "corpse" },

        onenter = function(inst, start_anim)
            local anim, loop = FunctionOrValue(anims.corpse, inst)
            anim = anim or "corpse"
            if start_anim then
                inst.AnimState:PlayAnimation(start_anim)
                inst.AnimState:PushAnimation(anim, loop)
            else
                inst.AnimState:PlayAnimation(anim, loop)
            end
        end,
    })

    table.insert(states, State{
        name = "corpse_hit",
        tags = { "corpse", "hit" },

        onenter = function(inst, data)
            data = data or {}
            local weapon_sound_modifier = "dull"
            if data.weapon_sound_modifier ~= nil then
                weapon_sound_modifier = data.weapon_sound_modifier
            end
            local anim, loop = FunctionOrValue(anims.corpse_hit, inst)
            --
            inst.AnimState:PlayAnimation(anim or "corpse_hit", loop)
            inst.SoundEmitter:PlaySound(GetCreatureImpactSound(inst, weapon_sound_modifier))
        end,

        timeline =
        {
            -- Allow being hit again.
            FrameEvent(6, function(inst) inst.sg:RemoveStateTag("hit") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("corpse_idle")
                end
            end),
        },
    })
end

--[[
Notes on the mutations

Pre Rift Mutations:
-Animation is like something is punching inside, a new body appears out of it
-Revival is very cartoony, corpse rips apart like paper
-Mutated mob is quite horrific,
-Mutated mob still has SOME of its instinctual and animalistic behaviours
-Catalyst is general lunar energy


Rift Mutations:
-Gestalt is posessing the body,
-Mutated mob does not have instinctual and animalistic behaviours, Alter is in full control!
-Revival is quite horrific, crackling, glass sounds, corpse is tearing and distorting.
-Mutated mob is a bit more "elegant" and "pretty" looking sporting beautiful crystals,
-Catalyst is a Incursive Gestalt
]]

CommonStates.AddLunarPreRiftMutationStates = function(states, timelines, anims, fns, data)
    data = data or {}
    anims = anims or {}
    -- These states are played on the corpse

    table.insert(states, State{
        name = "corpse_prerift_mutate",
        tags = { "prerift_mutating" },

        onenter = function(inst, mutantprefab)
            if fns and fns.mutate_onenter then
                fns.mutate_onenter(inst)
            end
            local anim_mutate, loop = FunctionOrValue(anims.mutate, inst)
            inst.AnimState:PlayAnimation(anim_mutate or "reviving", loop)
            inst.sg:SetTimeout(data.mutated_spawn_timing)
            inst.sg.statemem.mutantprefab = mutantprefab
        end,

        ontimeout = function(inst)
            local mutant = SpawnPrefab(inst.sg.statemem.mutantprefab)
            mutant.Transform:SetPosition(inst.Transform:GetWorldPosition())
            mutant.Transform:SetRotation(inst.Transform:GetRotation())

            if mutant.sg then
                mutant.sg:GoToState("corpse_prerift_mutate_pst")
            elseif mutant.OnMutatePost ~= nil then -- For special cases like the moon spider den
                mutant:OnMutatePost()
            end

            if mutant.LoadCorpseData ~= nil then
                mutant:LoadCorpseData(inst)
            end

            if fns and fns.mutate_createmutant then
                fns.mutate_createmutant(inst, mutant)
            end

            inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            inst:RemoveTag("creaturecorpse")
            inst:RemoveComponent("inspectable")
	        inst:RemoveComponent("burnable")
	        inst:RemoveComponent("propagator")
            inst:DropCorpseLoot()
            inst.DynamicShadow:Enable(false)

            inst.sg:RemoveStateTag("prerift_mutating")
            inst.OnEntitySleep = inst.Remove
            inst.persists = false
        end,

        events =
		{
			EventHandler("animover", function(inst) inst:Remove() end),
		},

        timeline = timelines ~= nil and timelines.mutate_timeline or nil,
    })

    -- These states are played on the actual mutation mob

    local mutatepst_onanimover = fns ~= nil and fns.mutatepst_onanimover or nil

    table.insert(states, State{
        name = "corpse_prerift_mutate_pst",
        tags = { "prerift_mutating", "busy" },

        onenter = function(inst)
            if fns and fns.mutatepst_onenter then
                fns.mutatepst_onenter(inst)
            end
            local anim_mutate, loop = FunctionOrValue(anims.mutate_pst, inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(anim_mutate or "mutated_spawn", loop)
        end,

        timeline = timelines ~= nil and timelines.mutatepst_timeline or nil,

        events =
		{
			EventHandler("animover", mutatepst_onanimover or function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(data.post_mutate_state or "idle")
				end
			end),
		},
    })
end

CommonStates.AddLunarRiftMutationStates = function(states, timelines, anims, fns, data)
    anims = anims or {}
    data = data or {}

    -- These states are played on the corpse

    table.insert(states, State{
        name = "corpse_lunarrift_mutate_pre",
        tags = { "lunarrift_mutating" },

        onenter = function(inst, mutantprefab)
            if fns and fns.mutatepre_onenter then
                fns.mutatepre_onenter(inst, mutantprefab)
            end
            local anim_mutate_pre, loop = FunctionOrValue(anims.mutate_pre, inst)
            if loop ~= false then
                loop = true
            end
            inst.AnimState:PlayAnimation(anim_mutate_pre or "twitch", loop)
            inst.sg:SetTimeout(3)
            inst.sg.statemem.mutantprefab = mutantprefab
            if data.twitch_lp then
                inst.SoundEmitter:PlaySound(data.twitch_lp, "loop")
            end
        end,

        timeline = timelines ~= nil and timelines.mutatepre_timeline or nil,

        ontimeout = function(inst)
            inst.sg.statemem.ismutating = true
            inst.sg:GoToState("corpse_lunarrift_mutate", inst.sg.statemem.mutantprefab)
        end,

        onexit = function(inst)
            if inst.sg.statemem.ismutating and not data.keep_twitch_lp then
                inst.SoundEmitter:KillSound("loop")
            end
        end,
    })

    table.insert(states, State{
        name = "corpse_lunarrift_mutate",
        tags = { "lunarrift_mutating" },

        onenter = function(inst, mutantprefab)
            if fns and fns.mutate_onenter then
                fns.mutate_onenter(inst, mutantprefab)
            end
            local anim_mutate = FunctionOrValue(anims.mutate, inst)
            inst.AnimState:PlayAnimation(anim_mutate or "mutate_pre", false)
            inst.sg.statemem.mutantprefab = mutantprefab
        end,

        timeline = timelines ~= nil and timelines.mutate_timeline or nil,

        events =
        {
            EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
                    local x, y, z = inst.Transform:GetWorldPosition()
					local rot = inst.Transform:GetRotation()
					local creature = SpawnPrefab(inst.sg.statemem.mutantprefab)
                    creature.Transform:SetPosition(x, y, z)
					creature.Transform:SetRotation(rot)
					creature.AnimState:MakeFacingDirty() --not needed for clients
					creature.sg:GoToState("corpse_lunarrift_mutate_pst")

                    if creature.LoadCorpseData ~= nil then
                        creature:LoadCorpseData(inst)
                    end

                    inst:DropCorpseLoot()
                    inst:Remove()
				end
			end),
        },

        onexit = function(inst)
            -- Shouldn't reach here!
            if BRANCH == "dev" then
                assert(false, "Bad! We somehow exited the corpse_lunarrift_mutate state for: "..inst:GetDisplayName())
            else
                inst.AnimState:ClearAllOverrideSymbols()
			    inst.AnimState:SetAddColour(0, 0, 0, 0)
			    inst.AnimState:SetLightOverride(0)
			    inst.SoundEmitter:KillSound("loop")
			    inst.components.burnable:SetBurnTime(TUNING.MED_BURNTIME)
			    inst.components.burnable.fastextinguish = false
            end
        end,
    })

    -- These states are played on the actual mutation mob

    table.insert(states, State{
        name = "corpse_lunarrift_mutate_pst",
        tags = { "busy", "noattack", "temp_invincible", "noelectrocute" },

        onenter = function(inst)
            if fns and fns.mutatepst_onenter then
                fns.mutatepst_onenter(inst)
            end
            local anim_mutate_pst = FunctionOrValue(anims.mutate_pst, inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(anim_mutate_pst or "mutate", false)
            inst.sg.statemem.flash = data.mutatepst_flashtime or 24
        end,

        timeline = timelines ~= nil and timelines.mutatepst_timeline or nil,

        onupdate = function(inst)
			local c = inst.sg.statemem.flash
			if c >= 0 then
				inst.sg.statemem.flash = c - 1
				c = easing.inOutQuad(math.min(20, c), 0, 1, 20)
				inst.AnimState:SetAddColour(c, c, c, 0)
				inst.AnimState:SetLightOverride(c)
			end
		end,

        events =
		{
			EventHandler("animover", fns.mutatepst_onanimover or function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(data.post_mutate_state or "idle")
				end
			end),
		},

        onexit = function(inst)
			inst.AnimState:SetAddColour(0, 0, 0, 0)
			inst.AnimState:SetLightOverride(0)
		end,
    })
end

local function oncorpsedeathanimover(inst)
    if inst.AnimState:AnimDone() and EntityHasCorpse(inst) then
        inst.sg:GoToState("corpse")
    end
end
CommonHandlers.CorpseDeathAnimOver = oncorpsedeathanimover

CommonHandlers.OnCorpseDeathAnimOver = function(cancorpsefn)
    local custom_handler = cancorpsefn and function(inst)
        if cancorpsefn(inst) then
            oncorpsedeathanimover(inst)
        end
    end or nil
    --
    return EventHandler("animover", custom_handler or oncorpsedeathanimover)
end

local function oncorpsechomped(inst, data)
    if inst.sg:HasStateTag("corpse") and not inst.sg:HasStateTag("hit") then
        inst.sg:GoToState("corpse_hit", data)
    end
end

CommonHandlers.OnCorpseChomped = function()
    return EventHandler("chomped", oncorpsechomped)
end

CommonStates.AddInitState = function(states, default_state)
    default_state = default_state or "idle"

    table.insert(states, State{
		name = "init",
		onenter = function(inst)
			inst.sg:GoToState(inst.is_corpse and "corpse_idle" or default_state)
		end,
	})
end
--------------------------------------------------------

CommonStates.AddParasiteReviveState = function(states)
    table.insert(states, State{
        name = "parasite_revive",
        tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("parasite_death_pst")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    })
end