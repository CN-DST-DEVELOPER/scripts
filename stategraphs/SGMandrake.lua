require("stategraphs/commonstates")

local events =
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	EventHandler("attacked", function(inst, data)
        if inst.components.health and not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/hit")
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
				inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/hit")
			end
        end
    end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
}

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop")
        end,

        timeline =
        {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/walk") end),
            TimeEvent(16*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/walk") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/death")
			inst.Transform:SetNoFaced()
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
			if inst.components.burnable:IsBurning() then
				inst.components.burnable:Extinguish()
				inst.sg:SetTimeout(21 * FRAMES)
			end
        end,

		ontimeout = function(inst)
			inst:oncooked()
		end,

        events =
        {
            EventHandler("animover", function(inst) inst:ondeath() end),
        },

		onexit = function(inst)
			--shouldn't reach here
			inst.Transform:SetFourFaced()
		end,
    },

    State{
        name = "item",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("object")
        end,
    },

    State{
        name = "ground",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("ground", true)
        end,
    },

    State{
        name = "picked",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/pullout")
            inst.AnimState:PlayAnimation("picked")
        end,

        timeline =
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/pop") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst:HasTag("item") and "death" or "idle")
            end),
        },
    },

    State{
        name = "plant",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("plant")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/plant")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/plant_dirt")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("ground") end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/hit")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    walktimeline =
    {
        TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/footstep") end),
        TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/mandrake/footstep") end),
    }
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

return StateGraph("mandrake", states, events, "idle")
