require("stategraphs/commonstates")

local events =
{
    EventHandler("locomote", function(inst)
        local is_moving = inst.sg:HasStateTag("moving")
        local is_idling = inst.sg:HasStateTag("idle")
        local should_move = inst.components.locomotor:WantsToMoveForward()

        if is_moving and not should_move then
            -- Flag our hop state to go to idle the next time it finishes.
            inst.sg.mem.end_hop = true
        elseif is_idling and should_move then
            -- If we hadn't gotten to idle yet, clear that flag.
            if inst.sg.mem.end_hop then
                inst.sg.mem.end_hop = nil
            end

            inst.sg:GoToState("hop")
        end
    end),
}

local function hop_animover(inst)
    if inst.sg.mem.end_hop then
        inst.sg.mem.end_hop = nil
        inst.sg:GoToState("hop_pst")
    else
        inst.sg:GoToState("hop")
    end
end

local states =
{
    State {
        name = "hop",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("hop")
        end,

        timeline =
        {
            FrameEvent(4, function(inst)
                inst.components.locomotor:WalkForward()
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hop")
            end),
            FrameEvent(19, function(inst)
                inst.components.locomotor:StopMoving()
            end),
        },

        events =
        {
            EventHandler("animover", hop_animover),
        },
    },

    State {
        name = "stunned",
        tags = {"busy", "stunned"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("stunned")
            inst.sg:SetTimeout(GetRandomWithVariance(3, 1))
            inst.components.inventoryitem.canbepickedup = true
        end,

        onexit = function(inst)
            inst.components.inventoryitem.canbepickedup = false
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },
}

CommonStates.AddSimpleState(states, "idle", "idle", {"idle", "canrotate"})
CommonStates.AddSimpleState(states, "hop_pst", "hop_pst", {"canrotate"})

return StateGraph("shadowheart_infused", states, events, "idle")