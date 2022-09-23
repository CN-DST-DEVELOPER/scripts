local events =
{
}

local function PlayHitFX(inst)
    if inst.sg.mem.bumpertype ~= nil then
        local hitfx = SpawnPrefab("boat_bumper_hit_" .. inst.sg.mem.bumpertype)
        hitfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end

local states =
{
    State{
        name = "idle",
        tags = { "idle" },

        onenter = function(inst, data)
            local stateindex = data and data.index or 1
            inst.AnimState:PlayAnimation("idle_" .. stateindex, true)
        end,
    },

    State{
        name = "place",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("place")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst, data)
            local stateindex = data and data.index or 1
            inst.AnimState:PlayAnimation("hit_" .. stateindex)
            PlayHitFX(inst)
            inst.sg.mem.nextstateindex = stateindex
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle", { index = inst.sg.mem.nextstateindex })
            end),
        },
    },

    State{
        name = "changegrade",
        tags = { "busy" },

        onenter = function(inst, data)
            local stateindex = data and data.index or 1
            local animtoplay = data and data.isupgrade and "upgrade_" or "downgrade_"

            inst.AnimState:PlayAnimation(animtoplay .. stateindex)

            if not data.isupgrade then
                PlayHitFX(inst)
            end

            inst.sg.mem.nextstateindex = data and data.newindex or 1
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle", { index = inst.sg.mem.nextstateindex })
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy", "dead" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("downgrade_3")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst:Remove()
            end),
        },
    },
}

return StateGraph("boatbumper", states, events, "idle")
