require("stategraphs/commonstates")

local actionhandlers =
{
	ActionHandler(ACTIONS.PICKUP, "steal"),
	ActionHandler(ACTIONS.HAMMER, "hammer"),
}

local events=
{
	EventHandler("attacked", function(inst, data)
		if inst.components.health and not (inst.components.health:IsDead() or inst.sg:HasStateTag("nointerrupt")) then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not (inst.sg:HasStateTag("attack") or CommonHandlers.HitRecoveryDelay(inst)) then
				inst.sg:GoToState("hit")
			end
		end
	end),
	EventHandler("doattack", function(inst)
		if not inst.components.health:IsDead() and ((inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute")) or not inst.sg:HasStateTag("busy")) then
			inst.sg:GoToState("attack")
		end
	end),
    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
    CommonHandlers.OnLocomote(true,false),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnDeath(),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            if math.random() < .333 then inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/growlshort") end
            inst.Physics:Stop()
			inst.AnimState:PlayAnimation("idle", true)
        end,

        events=
        {
            EventHandler("animover", function(inst) if math.random() < .1 then inst.sg:GoToState("taunt") else inst.sg:GoToState("idle") end end),
        },
    },

    State{
        name = "attack",
        tags = {"attack"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk_pre")
            inst.AnimState:PushAnimation("atk", false)
        end,

        timeline=
        {
            TimeEvent(0*FRAMES, function(inst) inst:PerformBufferedAction() inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/attack") end),
            TimeEvent(14*FRAMES, function(inst) inst:PerformBufferedAction() inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/kick_whoosh") end),
            TimeEvent(18*FRAMES, function(inst) inst.components.combat:DoAttack() end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst)inst.sg:GoToState("idle") end),
        },
    },

   State{
        name = "hammer",
        tags = {"busy"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk_pre")
            inst.AnimState:PushAnimation("atk", false)
        end,

        timeline=
        {

            TimeEvent(0*FRAMES, function(inst)  inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/attack") end),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/kick_whoosh") end),
            TimeEvent(18*FRAMES, function(inst) inst:PerformBufferedAction() inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/kick_impact") end),

        },

        events=
        {
            EventHandler("animqueueover", function(inst)inst.sg:GoToState("idle") end),
        },
    },

	State{
		name = "hit",
        tags = {"busy", "hit"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/hurt")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events=
        {
			EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

	State{
		name = "taunt",
        tags = {"busy"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/taunt")
        end,

        events=
        {
			EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

	State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/death")
            inst.AnimState:PlayAnimation("death")

            inst.components.locomotor:StopMoving()
            inst:DropDeathLoot()

            RemovePhysicsColliders(inst)
        end,

        events =
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },


    State{
        name = "exit",
		tags = { "busy", "nointerrupt", "nosleep", "nofreeze", "noattack", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("exit")

            inst.components.health:SetInvincible(true)
            inst.components.locomotor:StopMoving()

            RemovePhysicsColliders(inst)

			inst:StopBrain("SGkrampus_exit")
        end,

        timeline =
        {
            TimeEvent(11*FRAMES, function(inst) inst:PerformBufferedAction() inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_drop") end),
            TimeEvent(30*FRAMES, function(inst) inst:PerformBufferedAction() inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_jumpinto") end),
            TimeEvent(40*FRAMES, function(inst)
                inst:PerformBufferedAction()
                inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_dissappear")

                inst.DynamicShadow:Enable(false)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
        },

        onexit = function(inst)
            -- Safe guard in case we're not removed!
            inst.components.health:SetInvincible(false)

            ChangeToCharacterPhysics(inst)

			inst:RestartBrain("SGkrampus_exit")
        end,
    },

	State{
        name = "steal",
        tags = {"busy"},

        onenter = function(inst)
			inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/growllong")

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("steal_pre")
            inst.AnimState:PushAnimation("steal", false)
        end,

		timeline=
        {

			TimeEvent(18*FRAMES, function(inst) inst:PerformBufferedAction() end),
			TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_swing") end),
        },

		events=
        {
			EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

CommonStates.AddSleepExStates(states,
{
	sleeptimeline = {
        TimeEvent(30*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/sleep") end),
	},
})

CommonStates.AddRunStates(states,
{
	runtimeline = {
		TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/growlshort")
									PlayFootstep(inst)
								end),
		TimeEvent(2*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_foley") end),
		TimeEvent(4*FRAMES, function(inst) PlayFootstep(inst) end),
		TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/krampus/bag_foley") end),
	},
})
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

CommonStates.AddInitState(states, "taunt")
CommonStates.AddCorpseStates(states)

return StateGraph("krampus", states, events, "init", actionhandlers)
