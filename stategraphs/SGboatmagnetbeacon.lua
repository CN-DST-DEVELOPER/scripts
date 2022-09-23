local events =
{
}

local states =
{
    State {
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle", true)
            --inst.AnimState:PlayAnimation("no_target", true)
        end,
    },

    State {
        name = "place",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("placer")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            if inst.components.boatmagnetbeacon and inst.components.boatmagnetbeacon:IsTurnedOff() then
                inst.AnimState:PlayAnimation("hit_inactive")
            else
                inst.AnimState:PlayAnimation("hit_active")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "activate",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("active_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("active")
            end),
        },
    },

    State {
        name = "active",
        tags = { "idle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("active_loop", true)
        end,
    },

    State {
        name = "deactivate",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("active_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

return StateGraph("boatmagnetbeacon", states, events, "idle")
