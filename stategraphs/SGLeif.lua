require("stategraphs/commonstates")

local events=
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(false,true),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not CommonHandlers.HitRecoveryDelay(inst, TUNING.LEIF_HIT_RECOVERY) and
				not inst.sg:HasAnyStateTag("attack", "waking", "sleeping") and
				(not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("frozen"))
			then
				inst.sg:GoToState("hit")
			end
		end
    end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),

	EventHandler("doattack", function(inst, data)
		if not inst.components.health:IsDead() and
			((inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute")) or not inst.sg:HasStateTag("busy"))
		then
			inst.sg:GoToState("attack", data.target)
		end
	end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    EventHandler("gotosleep", function(inst) inst.sg:GoToState("sleeping") end),
    EventHandler("onwakeup", function(inst) inst.sg:GoToState("wake") end),
}

local states=
{
    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            --inst.SoundEmitter:PlaySound("dontstarve/pig/grunt")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.SoundEmitter:PlaySound("dontstarve/forest/treeFall")
            inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()))
        end,
    },

    State{
        name = "tree",
        onenter = function(inst)
            inst.AnimState:PlayAnimation("tree_idle", true)
        end,
    },

    State{
        name = "panic",
        tags = {"busy"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("panic_pre")
            inst.AnimState:PushAnimation("panic_loop", true)
        end,
        onexit = function(inst)
        end,

        onupdate = function(inst)
			if inst.components.burnable and not inst.components.burnable:IsBurning() and inst.sg.timeinstate > .3 then
				inst.sg:GoToState("idle", "panic_post")
			end
        end,
    },

	State{
        name = "attack",
        tags = {"attack", "busy"},

        onenter = function(inst, target)
            inst.Physics:Stop()
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk")
            inst.sg.statemem.target = target
        end,

        timeline=
        {
            TimeEvent(25*FRAMES, function(inst) inst.components.combat:DoAttack(inst.sg.statemem.target) end),
            TimeEvent(26*FRAMES, function(inst) inst.sg:RemoveStateTag("attack") end),

			TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
			TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/attack_VO") end),
			TimeEvent(12*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/swipe") end),
			TimeEvent(22*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

	State{
        name = "hit",
        tags = {"hit", "busy"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/hurt_VO")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline=
        {
            TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },

    },

    State{
        name = "sleeping",
        tags = {"sleeping", "busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("transform_tree", false)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/transform_VO")
        end,
        events=
        {
		    EventHandler("attacked", function(inst) if not inst.components.health:IsDead() then inst.sg:GoToState("wake") end end),
        },

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(25*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },

    },

	State{
		name = "spawn_from_wintertree",
		tags = { "waking", "busy" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("wintertree_transform_ent")
			inst.AnimState:OverrideSymbol("planter", "wintertree_build", "planter")
			inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/transform_VO")
			inst.DynamicShadow:Enable(false)
		end,

		onupdate = function(inst)
			local shadow = inst.sg.statemem.shadow
			if shadow then
				shadow = shadow + 1
				local k = shadow / 10 * (inst._scale or 1)
				inst.DynamicShadow:SetSize(4 * k, 1.5 * k)
				inst.sg.statemem.shadow = shadow < 10 and shadow or nil
			end
		end,

		timeline =
		{
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
			FrameEvent(14, function(inst)
				inst.sg.statemem.shadow = 0
				inst.DynamicShadow:Enable(true)
			end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("idle_nofaced")
				end
			end),
		},

		onexit = function(inst)
			local k = inst._scale or 1
			inst.DynamicShadow:SetSize(4 * k, 1.5 * k)
			inst.DynamicShadow:Enable(true)

			if not inst.sg.statemem.not_interrupted then
				inst.Transform:SetFourFaced()
			end
			inst.AnimState:ClearOverrideSymbol("planter")
		end,
	},

	State{
		name = "idle_nofaced",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			--inst.Transform:SetNoFaced()
			inst.AnimState:PlayAnimation("idle_loop_nofaced", true)
		end,

		onexit = function(inst)
			inst.Transform:SetFourFaced()
		end,
	},

    State{
        name = "spawn",
        tags = {"waking", "busy"},

		onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("transform_ent")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/transform_VO")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },

    },

	State{
        name = "wake",
        tags = {"waking", "busy"},

		onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("transform_ent_mad")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/transform_VO")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },

    },
}

CommonStates.AddWalkStates(
    states,
    {
		starttimeline =
		{
            TimeEvent(0*FRAMES, function(inst) inst.Physics:Stop() end),
            TimeEvent(11*FRAMES, function(inst) inst.components.locomotor:WalkForward() end),
            TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(17*FRAMES, function(inst) inst.Physics:Stop() end),
		},
        walktimeline =
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/walk_vo") end),
            TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(19*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/footstep") end),
            TimeEvent(52*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
            TimeEvent(53*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/footstep") end),
        },
        endtimeline=
        {
            TimeEvent(2*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/foley") end),
        },
    })

CommonStates.AddIdle(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddSinkAndWashAshoreStates(states, {washashore = "transform_ent_mad"})

return StateGraph("leif", states, events, "idle")
