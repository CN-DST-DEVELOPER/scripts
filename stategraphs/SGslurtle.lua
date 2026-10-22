require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.PICKUP, "eat_pre"),
    ActionHandler(ACTIONS.EAT, "eat_loop"),
    ActionHandler(ACTIONS.STEAL, "steal"),
    ActionHandler(ACTIONS.GOHOME, "action"),
    ActionHandler(ACTIONS.PICK, "steal"),
}

local events=
{
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(),
    EventHandler("entershield", function(inst)
        if inst.components.health and not inst.components.health:IsDead() then
            inst.sg:GoToState("shield")
        end
    end),
    EventHandler("exitshield", function(inst)
        if inst.components.health and not inst.components.health:IsDead() then
            inst.sg:GoToState("shield_end")
        end
    end),

    EventHandler("death", function(inst, data)
        if not inst.sg:HasStateTag("dead") then
            local use_corpse_state = CommonHandlers.ShouldUseCorpseStateOnLoad(inst, data.cause)
            if use_corpse_state then
                inst.sg:GoToState("corpse", true)
            elseif inst.sg.mem.dissolving then
                inst.sg:GoToState("dissolved_death", data)
            else
                inst.sg:GoToState("death", data)
            end
        end
    end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states =
{
     State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            if inst.sg.mem.dissolving then
                inst.sg:GoToState("dissolving_pre")
                return
            end

            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle", true)
            else
                inst.AnimState:PlayAnimation("idle", true)
            end
        end,

        timeline =
        {
		    FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/idle") end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "taunt",

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")
        end,

        timeline =
        {
            FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/taunt") end ),
            FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/taunt") end ),
            FrameEvent(33, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/taunt") end ),
        },


        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "action",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle", true)
            inst:PerformBufferedAction()
        end,
        events=
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("idle")
            end),
        }
    },


    State{
    	name = "shield",
		tags = { "busy", "hiding", "shield" },

    	onenter = function(inst)
            --If taking fire damage, spawn fire effect.

    		inst.components.health:SetAbsorptionAmount(TUNING.SLURTLE_SHELL_ABSORB)
    		inst.Physics:Stop()
    		inst.AnimState:PlayAnimation("hide")
    		inst.AnimState:PushAnimation("hide_loop")
            inst:AddTag("shell")
    	end,

        onexit = function(inst)
            inst:RemoveTag("shell")
            inst.components.health:SetAbsorptionAmount(0)
        end,

        timeline =
        {
            FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/hide") end ),
        },
	},

    State{
        name = "shield_end",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("emerge")
        end,

        timeline =
        {
            FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/emerge") end ),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "eat_pre",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat_pre", false)
        end,

        timeline =
        {
            FrameEvent(9, function(inst)
                inst:PerformBufferedAction() --take food
                inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/bite")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)
        },
    },

    State{
        name = "eat_loop",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat_loop", true)
            inst.sg:SetTimeout(2+math.random()*3)
        end,

        timeline =
        {
            FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/eat") end ),
            FrameEvent(17, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/eat") end ),
        },

        events =
        {
            EventHandler("attacked", function(inst) inst.components.inventory:DropItem(inst:GetBufferedAction().target) inst.sg:GoToState("idle") end) --drop food
        },

        ontimeout= function(inst)
            inst.lastmeal = GetTime()
            inst:PerformBufferedAction()
            inst.sg:GoToState("idle", "eat_pst")
        end,
    },

    State{
        name = "steal", --aquire food aggressively
        tags = {"attack", "busy"},

        onenter = function(inst, target)
            if inst.components.locomotor then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("atk")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline =
        {
            FrameEvent(11, function(inst) inst:PerformBufferedAction() end),
        },
    },

    -- Oh you poor thing...
    State{
        name = "dissolving_pre",
        tags = { "busy", "hiding", "dissolving" },

        onenter = function(inst)
            inst.sg.mem.dissolving = true
            if inst.components.locomotor then
                inst.components.locomotor:StopMoving()
            end

            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("salt_death_pre")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/hide")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("dissolving_loop")
                end
            end),
        },
    },

    State{
        name = "dissolving_loop",
        tags = { "busy", "hiding", "dissolving" },

        onenter = function(inst)
            if inst.components.locomotor then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation("salt_death_loop", true)

            if not inst.SoundEmitter:PlayingSound("salting_loop") then
                inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/death_salty_LP", "salting_loop")
            end
        end,

        onupdate = function(inst, dt)
            inst.components.health:DoDelta(-200 * dt, nil, "salt", nil, nil, true)
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("salting_loop")
        end,
    },

    State{
        name = "dissolved_death",
        tags = { "busy", "dead", "dissolving" },

        onenter = function(inst, data)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            RemovePhysicsColliders(inst)

            inst.AnimState:PlayAnimation("salt_death_pst")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/death_salty_pst")
        end,

        timeline =
        {
            FrameEvent(10, function(inst)
                inst:DropDeathLoot()

                inst:AddTag("NOCLICK")
                inst.persists = false
            end),
            TimeEvent(3, ErodeAway)
        }
    },

}

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
	    FrameEvent(0, function(inst) inst.Physics:Stop() end ),
    },
	walktimeline = {
        FrameEvent(0, function(inst)
		    inst.Physics:Stop()
            if math.random() <= 0.33 then inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/idle") end
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/slide_out")
        end),
        FrameEvent(13, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/slide_in")
            inst.components.locomotor:WalkForward()
        end),
        FrameEvent(21, function(inst)
            inst.Physics:Stop()
        end),
	},
}, nil, true)


local function hitanim(inst)
	local statename = inst.sg.currentstate.name
	if statename == "shield" then
		return "hit_shield"
	else
		return "hit_out"
	end
end

local combatanims =
{
	hit = hitanim,
}

CommonStates.AddCombatStates(states,
{
    attacktimeline =
    {
        FrameEvent(9, function(inst)
            inst.components.combat:DoAttack()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/bite")
        end),
    },
    deathtimeline =
    {
        FrameEvent(1, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/slurtle/death")
        end),
    },
}, 
combatanims,
{
    deathanimfn = function(inst, data)
        return (data ~= nil and data.corpsing and "death_2") or "death"
    end,

    onhitanimover = function(inst)
        if inst.AnimState:AnimDone() then
            inst.sg:GoToState(inst.sg.mem.dissolving and "dissolving_pre" or "idle")
        end
    end,
},
{
    has_corpse_handler = true,
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states,
nil, --timeline
nil, --anims
{   --fns
    onanimover = function(inst)
        if inst.AnimState:AnimDone() then
            inst.sg:GoToState(inst.sg.mem.dissolving and "dissolving_pre" or "idle")
        end
    end,
})

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states)

return StateGraph("slurtle", states, events, "init", actionhandlers)