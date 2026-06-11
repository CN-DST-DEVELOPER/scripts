require("stategraphs/commonstates")

local events=
{
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    EventHandler("doattack", function(inst)
		if not inst.components.health:IsDead() and ((inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute")) or not inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack")
        end
    end),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    --CommonHandlers.OnAttacked(),
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasAnyStateTag("attack", "electrocute") then
				inst.sg:GoToState("hit")
			end
        end
	end),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst:syncanim("idle_loop", true)
            --inst.AnimState:PlayAnimation("idle_loop", true)
        end,
        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

	State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst:syncanim("death")

            inst.components.lootdropper:DropLoot()

            RemovePhysicsColliders(inst)
        end,

        timeline =
        {
            TimeEvent(17*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeballturret/pop") end)
        },
    },

    State{
        name = "hit",
        tags = {"hit"},

        onenter = function(inst) inst:syncanim("hit") end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "attack",
        tags = {"attack", "canrotate"},
        onenter = function(inst)
            inst:triggerlight()
            inst:syncanim("atk")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeballturret/charge")
        end,
        timeline=
        {
            TimeEvent(22*FRAMES, function(inst)
                inst.components.combat:StartAttack()
                inst.components.combat:DoAttack()
                inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeballturret/shoot")
            end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

return StateGraph("eyeturret", states, events, "idle")
