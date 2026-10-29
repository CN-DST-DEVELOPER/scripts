require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.PICKUP, "pickup"),
}

local events =
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnKnockback(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(nil, TUNING.PIG_MAX_STUN_LOCKS),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnIpecacPoop(),
    EventHandler("transformwere", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("transformWere")
        end
    end),
    EventHandler("giveuptarget", function(inst, data)
		if data.target and (not inst.sg:HasAnyStateTag("electrocute", "knockback") or inst.sg:HasStateTag("caninterrupt")) and not inst.components.health:IsDead() then
            inst.sg:GoToState("howl")
        end
    end),
    EventHandler("newcombattarget", function(inst, data)
        if data.target ~= nil and not inst.sg:HasStateTag("busy") and not inst.components.health:IsDead() then
            if math.random() < .3 then
                inst.sg:GoToState("howl")
            else
                inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/idle")
            end
        end
    end),
}

local states =
{
    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/grunt")
            inst.AnimState:PlayAnimation("death")
            inst.components.locomotor:StopMoving()
            RemovePhysicsColliders(inst)
            inst:DropDeathLoot()
        end,

        events =
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },

    State{
        name = "howl",
        tags = { "busy" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation("howl", false)
            else
                inst.AnimState:PlayAnimation("howl")
            end
        end,

        timeline =
        {
            TimeEvent(20 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/howl") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "transformWere",
		tags = { "transform", "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/transformToWere")
            inst.AnimState:SetBuild(inst.build)
            inst.AnimState:PlayAnimation("transform_pig_were")
            inst:AddTag("hostile")
        end,

        events =
        {
			EventHandler("attacked", function(inst, data)
				if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
					return true
				end
				inst.sg:GoToState("hit")
				return true
            end),
            EventHandler("animover", function(inst)
                inst.components.sleeper:WakeUp()
                inst.sg:GoToState("howl")
            end),
        },

        onexit = function(inst)
            inst.AnimState:SetBuild("werepig_build")
        end,
    },

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation("were_idle_loop", true)
            else
                inst.AnimState:PlayAnimation("were_idle_loop", true)
            end
        end,
    },

    State{
        name = "attack",
		tags = { "attack", "busy", "jumping" },

        onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()
            inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("were_atk_pre") --15 frames
			inst.AnimState:PushAnimation("were_atk") --7 frames
			inst.AnimState:PushAnimation("were_atk_pst", false)

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
			FrameEvent(3, PlayFootstep),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh", nil, 0.7) end),
			FrameEvent(15, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/attack")
				inst.Physics:SetMotorVelOverride(8 * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(16, function(inst)
				PlayFootstep(inst)
				inst.components.combat:DoAttack()
			end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVelOverride(4 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVelOverride(2 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVelOverride(1 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVelOverride(0.5 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(21, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(15 + 7 + 4, function(inst)
				if inst.components.combat:HasTarget() or math.random() < 0.7 then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.sg:HasStateTag("caninterrupt") and "idle" or "howl")
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

    State{
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("were_run_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("run")
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("were_run_loop") then
                inst.AnimState:PlayAnimation("were_run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
            TimeEvent(0, PlayFootstep),
            TimeEvent(10 * FRAMES, PlayFootstep),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = { "canrotate" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("were_run_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "walk_start",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("were_walk_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("walk")
            end),
        },
    },

    State{
        name = "walk",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("were_walk_loop")
        end,

        timeline =
        {
            TimeEvent(0, PlayFootstep),
            TimeEvent(12 * FRAMES, PlayFootstep),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("walk")
            end),
        },
    },

    State{
        name = "walk_stop",
        tags = { "canrotate" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("were_walk_pst")
        end,

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
                inst.sg:GoToState((not inst.components.combat:HasTarget() or math.random() < .3) and "howl" or "idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/hurt")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(35 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/werepig/sleep") end),
    },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddKnockbackStates(states, nil, { knockback = "smacked" })
CommonStates.AddSimpleActionState(states, "eat", "eat", 20 * FRAMES, { "busy" })
CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"})
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)
CommonStates.AddIpecacPoopState(states)

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states, nil, nil, "pigcorpse")

return StateGraph("werepig", states, events, "init", actionhandlers)
