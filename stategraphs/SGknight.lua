require("stategraphs/commonstates")

local function hit_recovery_skip_cooldown_fn(inst, last_t, delay)
	--no skipping when we're dodging (hit_recovery increased)
	return inst.hit_recovery == nil
		and inst.components.combat:InCooldown()
		and inst.sg:HasStateTag("idle")
end

local events=
{
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnAttack(),
	CommonHandlers.OnAttacked(nil, nil, hit_recovery_skip_cooldown_fn),
    CommonHandlers.OnDeath(),
}

local states=
{
     State{

        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle_loop", true)
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
        end,

        timeline =
        {
		    TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/idle") end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

   State{
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/voice")
        end,

        timeline =
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/pawground") end ),
		    TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/pawground") end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{  name = "ruinsrespawn",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("spawn")
	        inst.components.sleeper.isasleep = true
	        inst.components.sleeper:GoToSleep(.1)
        end,

        timeline =
        {
    		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce") end ),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("sleeping") end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
	    TimeEvent(0*FRAMES, function(inst) inst.Physics:Stop() end ),
    },
	walktimeline = {
		    TimeEvent(0*FRAMES, function(inst) inst.Physics:Stop() end ),
            TimeEvent(7*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce")
                inst.components.locomotor:WalkForward()
            end ),
            TimeEvent(19*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land")
                inst.Physics:Stop()
            end ),
	},
}, nil,true)

CommonStates.AddSleepStates(states,
{
    starttimeline =
    {
		TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/liedown") end ),
    },

	sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/sleep") end),
	},
})

CommonStates.AddCombatStates(states,
{
    attacktimeline =
    {
        TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/attack") end),
        TimeEvent(17*FRAMES, function(inst) inst.components.combat:DoAttack() end),
    },
    hittimeline =
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/hurt") end),
    },
    deathtimeline =
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/death") end),
    },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("knight", states, events, "idle")
