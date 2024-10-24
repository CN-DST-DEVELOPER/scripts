require("stategraphs/commonstates")

local events =
{
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnAttacked(),
}

local states =
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            if not inst.AnimState:IsCurrentAnimation("idle") then
                inst.AnimState:PlayAnimation("idle", true)
            end
        end,

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
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("hit")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    }
}

CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states, nil, { startrun = "walk_pre", run = "walk_loop", stoprun = "walk_pst" })

return StateGraph("shadowthrall_parasite", states, events, "idle")
