require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")

local actionhandlers = {
}

local events = {
	SGCritterEvents.OnEat(),
    SGCritterEvents.OnAvoidCombat(),
	SGCritterEvents.OnTraitChanged(),

    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnHop(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
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
	{
        anim = "emote_yawn",
        timeline=
		{
            FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/yawn") end),
		},
	},
}

SGCritterStates.AddIdle(states, #emotes)
SGCritterStates.AddRandomEmotes(states, emotes)
SGCritterStates.AddEmote(states, "cute",
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/cute") end),
			FrameEvent(16, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
			FrameEvent(27, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
			FrameEvent(36, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
			FrameEvent(48, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
			FrameEvent(58, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep", nil, 0.3) end),
		})
SGCritterStates.AddEmote(states, "pepper",
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/pepper") end),
		})
SGCritterStates.AddEmote(states, "onion",
	{
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/onion") end),
	})
SGCritterStates.AddEmote(states, "mushroom",
	{
		FrameEvent(7, RaiseFlyingCreature),
		FrameEvent(63, LandFlyingCreature),
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/mushroom") end),
		FrameEvent(65, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
	})

SGCritterStates.AddCombatEmote(states,
		{
			pre =
			{
				FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/combat_pre") end),
			},
			loop =
			{
				FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/combat") end),
			},
			pst =
			{
				FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/combat_pst") end),
			},
		})
SGCritterStates.AddPlayWithOtherCritter(states, events,
	{
		active =
		{
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
		},
		passive =
		{
			-- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("PATH_HERE") end),
		},
	})

local function QueueStateAfterEat(inst, food)
	return food ~= nil and (
		(food.prefab == "pepper" or food.prefab == "pepper_cooked") and "emote_pepper" or
		(food.prefab == "onion" or food.prefab == "onion_cooked") and "emote_onion" or
		(food.prefab == "red_cap" or food.prefab == "red_cap_cooked"
			or food.prefab == "green_cap" or food.prefab == "green_cap_cooked"
			or food.prefab == "blue_cap" or food.prefab == "blue_cap_cooked"
			or food.prefab == "shroomcake" ) and "emote_mushroom"
	) or nil
end
SGCritterStates.AddEat(states,
        {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/eat_pre") end),
        },
	nil, -- fns
	QueueStateAfterEat)
SGCritterStates.AddHungry(states,
        {
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/hungry") end),
        })
SGCritterStates.AddNuzzle(states, actionhandlers,
		{
            FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/nuzzle") end),
			FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/footstep") end),
        })

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

SGCritterStates.AddPetEmote(states,
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/pet") end),
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

CommonStates.AddSleepExStates(states,
		{
			starttimeline =
			{
				FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/yawn") end),
			},
			sleeptimeline =
			{
                FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/sleep") end),
			},
			waketimeline =
			{
                FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/eets/wakeup") end),
			},
		})

return StateGraph("SGcritter_eets", states, events, "idle", actionhandlers)