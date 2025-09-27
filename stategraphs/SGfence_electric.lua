local events =
{
    EventHandler("start_linking", function(inst)
        inst.sg:GoToState("linking_pre")
    end),
    
    EventHandler("end_linking", function(inst)
        inst.sg:GoToState("linking_pst")
    end),

    EventHandler("disconnect_links", function(inst)
        inst.sg:GoToState("disconnect")
    end)
}

local states =
{
    State{
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            --inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/firesupressor_on")
            inst.AnimState:PlayAnimation(inst.components.electricconnector:HasConnection() and "idle_on" or "idle", true)

            if POPULATING then --Randomize frame on load
                inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        }
    },

    State{
        name = "linking_pre",
        tags = { "idle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("link_pre")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/electric_fence/click_on_off")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("linking_loop")
            end),
        }
    },

    State{
        name = "linking_loop",
        tags = { "idle", "linking" },

        onenter = function(inst)
            inst.AnimState:PushAnimation("link_loop", true)
            if not inst.SoundEmitter:PlayingSound("link_LP") then
                inst.SoundEmitter:PlaySound("dontstarve/common/together/electric_fence/link_LP", "link_LP")
            end

            local connector = inst.components.electricconnector:FindAndLinkConnector()

            if connector then
                inst.sg.statemem.link_established = true
                connector.sg.statemem.link_established = true

                if inst:HasTag("fully_electrically_linked") then
                    inst.sg:GoToState("linking_pst", true)
                end
                if connector:HasTag("fully_electrically_linked") then
                    connector.sg:GoToState("linking_pst", true)
                end
            end
        end,

        onexit = function(inst, new_state)
            if new_state ~= "linking_loop" then
                inst.SoundEmitter:KillSound("link_LP")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("linking_loop")
            end),
            EventHandler("linked_to", function(inst)
                inst.sg:GoToState("linking_pst", true)
            end),
        }
    },

    State{
        name = "linking_pst",
        tags = { "idle" },

        onenter = function(inst, successful_pairing)
            inst.AnimState:PlayAnimation("link_pst")
            inst.SoundEmitter:PlaySound(successful_pairing and "dontstarve/common/together/electric_fence/link_pst" or "dontstarve/common/together/electric_fence/click_on_off")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        }
    },

    State{
        name = "disconnect",
        tags = { "idle" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("disconnect")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/electric_fence/disconnect")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        }
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

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

return StateGraph("fence_electric", states, events, "idle")
