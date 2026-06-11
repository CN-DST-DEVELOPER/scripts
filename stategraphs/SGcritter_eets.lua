require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")

local actionhandlers = {
}

local events = {
	SGCritterEvents.OnEat(),

    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnHop(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
}

local states = {
}

local emotes = {
    {
        anim = "emote_jump",
        timeline = {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/jump") end),
            FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
            FrameEvent(16, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
        }
    },
    {
        anim = "emote_jump_spin",
        timeline = {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/jump") end),
            FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
            FrameEvent(16, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
        }
    },
}

SGCritterStates.AddIdle(states, #emotes)
SGCritterStates.AddRandomEmotes(states, emotes)

SGCritterStates.AddEat(states,
        {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/eat_pre") end),
        },
        nil,
        true) -- don't go to emote_cute

SGCritterStates.AddWalkStates(states,
	{
		walktimeline =
		{
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
			FrameEvent(14, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
		},
		endtimeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
		},
	})

CommonStates.AddHopStates(states, true, nil,
    {
        hop_pre =
        {
            FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
        },
        hop_pst =
        {
            FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
            FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
        },
    })
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("SGcritter_eets", states, events, "idle", actionhandlers)