local events =
{
    EventHandler("onbuilt", function(inst)
        inst.sg:GoToState("place")
    end),

    EventHandler("worked", function(inst, data)
        if not (inst:HasTag("burnt") or inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("hit", data)
        end
    end),
}

local function GoToIdle(inst)
    inst.sg:GoToState("idle")
end

local states =
{
    State{
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            inst:PlayAnimation(
                inst:HasTag("burnt") and "burnt" or
                inst:HasTag("abandoned") and "broken" or
                "idle"
            )
        end,
    },

    State{
        name = "hit",
        tags = { "hit" },

        onenter = function(inst, data)
            inst:PlayAnimation(inst:HasTag("abandoned") and "broken_hit" or "hit")

            if inst.hermitcrab and inst.hermitcrab:IsValid() then
                inst.hermitcrab.sg:GoToState("hit_teashop")
            end
        end,

        events =
        {
            EventHandler("animover", GoToIdle),
        },
    },

    State{
        name = "place",
        tags = {"busy"},

        onenter = function(inst)
            inst:PlayAnimation("place")
            inst.SoundEmitter:PlaySound("hookline_2/characters/hermit/tea_stand/place")
        end,

        events =
        {
            EventHandler("animover", GoToIdle),
        },
    },
}

return StateGraph("hermitcrab_teashop", states, events, "idle")