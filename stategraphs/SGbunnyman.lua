require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "gohome"),
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.PICKUP, "pickup"),
    ActionHandler(ACTIONS.EQUIP, "pickup"),
    ActionHandler(ACTIONS.ADDFUEL, "pickup"),
}

local events =
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnKnockback(),
    CommonHandlers.OnAttacked(nil, TUNING.BUNNYMAN_MAX_STUN_LOCKS),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
	EventHandler("doattack", function(inst)
		if inst.components.health and not inst.components.health:IsDead() and
			(	not inst.sg:HasStateTag("busy") or
				(inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute"))
			)
		then
			inst.sg:GoToState(inst.vampire and "hn_attack" or "attack")
		end
	end),
	EventHandler("locomote", function(inst)
		local is_moving = inst.sg:HasStateTag("moving")
		local is_running = inst.sg:HasStateTag("running")
		local is_idling = inst.sg:HasStateTag("idle")

		local should_move = inst.components.locomotor:WantsToMoveForward()
		local should_run = inst.components.locomotor:WantsToRun()

		if is_moving and not should_move then
			inst.sg:GoToState(
				(inst.vampire and (is_running and "hn_run_stop" or "hn_walk_stop")) or
				(is_running and "run_stop" or "walk_stop")
			)
		elseif (is_idling and should_move) or (is_moving and should_move and is_running ~= should_run) then
			inst.sg:GoToState(
				inst.vampire and
				(should_run and "hn_run_start" or "hn_walk_start") or
				(should_run and "run_start" or "walk_start")
			)
		end
	end),
    EventHandler("cheer", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("cheer")
        end
    end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local function DoVampireIdleSound(inst)
	if inst.sg.mem.vampire_idle_sound_delay < GetTime() then
		inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
	end
end

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			inst.components.locomotor:StopMoving()

			local anim = inst.vampire and "halloween_idle_loop" or "idle_loop"

			--pushanim could be bool or string?
			if pushanim then
				if type(pushanim) == "string" then
					inst.AnimState:PlayAnimation(pushanim)
				end
				inst.AnimState:PushAnimation(anim, true)
			else
				if not inst.AnimState:IsCurrentAnimation(anim) then
					inst.AnimState:PlayAnimation(anim, true)
				end
				if inst.vampire then
					DoVampireIdleSound(inst)
				end
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState(not inst.vampire and math.random() < 0.1 and "funnyidle" or "idle")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(not inst.vampire and math.random() < 0.1 and "funnyidle" or "idle")
				end
			end),
		},
	},

    State{
        name = "funnyidle",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()

            local leader = inst.components.follower:GetLeader()
            local is_roll_called = leader ~= nil and leader.components.leader ~= nil and leader.components.leader:IsRollCalling() or nil
            if inst.components.health:GetPercent() < TUNING.BUNNYMAN_PANIC_THRESH then
                inst.AnimState:PlayAnimation("idle_angry")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
            elseif leader ~= nil and inst.components.follower:GetLoyaltyPercent() < .05 and not is_roll_called then
                inst.AnimState:PlayAnimation("hungry")
                inst.SoundEmitter:PlaySound("dontstarve/wilson/hungry")
            elseif inst.components.combat:HasTarget() then
                inst.AnimState:PlayAnimation("idle_angry")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
            elseif leader ~= nil and (inst.components.follower:GetLoyaltyPercent() > .3 or is_roll_called) then
                inst.AnimState:PlayAnimation("idle_happy")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/happy")
            else
                inst.AnimState:PlayAnimation("idle_creepy")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/idle_med")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst, data)
			if inst.vampire then
				inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
			else
				inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/death")
			end
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            inst.causeofdeath = data ~= nil and data.afflicter or nil            

            if not inst.shadowthrall_parasite_hosted_death or not TheWorld.components.shadowparasitemanager then
                RemovePhysicsColliders(inst)
                inst:DropDeathLoot()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.shadowthrall_parasite_hosted_death and TheWorld.components.shadowparasitemanager then
                    TheWorld.components.shadowparasitemanager:ReviveHosted(inst)
                elseif inst.AnimState:AnimDone() then
                    inst.sg:GoToState("corpse")
                end
            end),
        },        
    },

    State{
        name = "abandon",
        tags = { "busy" },

        onenter = function(inst, leader)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("abandon")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
            if leader ~= nil and leader:IsValid() then
                inst:FacePoint(leader:GetPosition())
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/attack")
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/bite")
                inst.components.combat:DoAttack()
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "eat",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/eat")
        end,

        timeline =
        {
            TimeEvent(20 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
			if inst.vampire then
				local t = GetTime()
				if inst.sg.mem.vampire_idle_sound_delay < t + 0.5 then
					inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
					inst.sg.mem.vampire_idle_sound_delay = t + 1.5
				end
			else
				inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hurt")
			end
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    State{
        name = "cheer",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            CommonHandlers.UpdateHitRecoveryDelay(inst)
            inst.AnimState:PlayAnimation("idle_happy")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/happy")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

	-- hallowed nights 2026

	State{
		name = "hn_walk_start",
		tags = { "moving", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:WalkForward()
			inst.AnimState:PlayAnimation("halloween_walk_pre")
		end,

		timeline =
		{
			FrameEvent(6, PlayFootstep),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("hn_walk")
				end
			end),
		},
	},

	State{
		name = "hn_walk",
		tags = { "moving", "canrotate" },

		onenter = function(inst, t0)
			inst.components.locomotor:WalkForward()
			if not inst.AnimState:IsCurrentAnimation("halloween_walk_loop") then
				inst.AnimState:PlayAnimation("halloween_walk_loop", true)
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

			if inst.components.combat:HasTarget() then
				inst.sg.statemem.hn_walk_t0 = t0 or GetTime()
			end
		end,

		timeline =
		{
			FrameEvent(0, DoVampireIdleSound),
			FrameEvent(27, PlayFootstep),
			FrameEvent(55, PlayFootstep),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("hn_walk", inst.sg.statemem.hn_walk_t0)
		end,
	},

	State{
		name = "hn_walk_stop",
		tags = { "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("halloween_walk_pst")
		end,

		timeline =
		{
			FrameEvent(0, PlayFootstep),
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
		name = "hn_run_start",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor.runspeed = TUNING.HN_MONSTER_WALKSPEED
			inst.components.locomotor:RunForward()
			inst.AnimState:PlayAnimation("halloween_run_pre")
			if inst.sg.lasttags["moving"] then
				PlayFootstep(inst)
			end
		end,

		timeline =
		{
			FrameEvent(0, DoVampireIdleSound),
			FrameEvent(11, function(inst)
				inst.components.locomotor.runspeed = inst.components.locomotor.runspeed * 0.75 + TUNING.HN_MONSTER_RUNSPEED * 0.25
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("hn_run", math.random(2, 3))
				end
			end),
		},
	},

	State{
		name = "hn_run",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst, sounddelay)
			inst.components.locomotor.runspeed = (inst.components.locomotor.runspeed + TUNING.HN_MONSTER_RUNSPEED) * 0.5
			inst.components.locomotor:RunForward()
			if not inst.AnimState:IsCurrentAnimation("halloween_run_loop") then
				inst.AnimState:PlayAnimation("halloween_run_loop", true)
			end
			inst.sg.statemem.sounddelay = sounddelay or 0
			if inst.sg.statemem.sounddelay <= 0 then
				DoVampireIdleSound(inst)
				inst.sg.statemem.sounddelay = math.random(3, 4)
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			FrameEvent(0, PlayFootstep),
			FrameEvent(10, PlayFootstep),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("hn_run", inst.sg.statemem.sounddelay - 1)
		end,
	},

	State{
		name = "hn_run_stop",
		tags = { "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("halloween_run_pst")
		end,

		timeline =
		{
			FrameEvent(0, PlayFootstep),
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
		name = "hn_attack",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("halloween_atk_pre") --15 frames
			inst.AnimState:SetFrame(4)
			inst.AnimState:PushAnimation("halloween_atk") --7 frames
			inst.AnimState:PushAnimation("halloween_atk_pst", false)

			local target = inst.components.combat.target
			if target and target.components.locomotor == nil then
				local dist1 = inst:GetDistanceSqToInst(target)
				if dist1 > 0 then
					local dist = 1.883
					inst.sg.statemem.speedmult = math.clamp(dist1, 0, dist) / dist
				else
					inst.sg.statemem.speedmult = 0
				end
			else
				inst.sg.statemem.speedmult = 1
			end
			inst.Physics:SetMotorVelOverride(3 * inst.sg.statemem.speedmult, 0 ,0)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				PlayFootstep(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/angry_idle")
				inst.sg.mem.vampire_idle_sound_delay = GetTime() + 1.5
			end),
			FrameEvent(10 - 4, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh", nil, 0.7) end),
			FrameEvent(15 - 4, function(inst)
				inst.Physics:SetMotorVelOverride(8 * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(16 - 4, function(inst)
				PlayFootstep(inst)
				inst.components.combat:DoAttack()
			end),
			FrameEvent(17 - 4, function(inst) inst.Physics:SetMotorVelOverride(4 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(18 - 4, function(inst) inst.Physics:SetMotorVelOverride(2 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(19 - 4, function(inst) inst.Physics:SetMotorVelOverride(1 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(20 - 4, function(inst) inst.Physics:SetMotorVelOverride(0.5 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(21 - 4, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(15 - 4 + 7 + 4, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	},
}

CommonStates.AddWalkStates(states, {
    walktimeline =
    {
        TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hop") end),
        TimeEvent(4 * FRAMES, function(inst)
            inst.components.locomotor:WalkForward()
        end),
        TimeEvent(12 * FRAMES, function(inst)
            PlayFootstep(inst)
            inst.Physics:Stop()
        end),
    },
}, nil, true)

CommonStates.AddRunStates(states, {
    runtimeline =
    {
        TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hop") end),
        TimeEvent(4 * FRAMES, function(inst)
            inst.components.locomotor:RunForward()
        end),
        TimeEvent(8 * FRAMES, function(inst)
            PlayFootstep(inst)
            inst.Physics:Stop()
        end),
    },
}, nil, true)

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(35 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/sleep") end),
    },
})

CommonStates.AddSimpleState(states, "refuse", "pig_reject", { "busy" })
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddKnockbackStates(states)
CommonStates.AddSimpleActionState(states, "pickup", "pig_pickup", 10 * FRAMES, { "busy" })
CommonStates.AddSimpleActionState(states, "gohome", "pig_pickup", 4 * FRAMES, { "busy" })
CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"})
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)
CommonStates.AddParasiteReviveState(states)

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states)

return StateGraph("bunnyman", states, events, "init", actionhandlers)
