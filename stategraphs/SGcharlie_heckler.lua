require("stategraphs/commonstates")

local events =
{
    EventHandler("ontalk", function(inst, data)
        if not inst.sg:HasAnyStateTag("talking", "busy") then
            inst.sg:GoToState("talkto", data)
        end
    end),

    EventHandler("arrive", function(inst)
        inst.sg:GoToState("arrive")
    end),

    EventHandler("leave", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("leave")
        else
            inst.exited_stage = true
        end
    end),

    EventHandler("give", function(inst, data)
        inst.sg:GoToState("give", data)
    end),
}

local EXCITED_PARAM = "excited"
local DISAPPOINTED_PARAM = "disappointed"
local LAUGH_PARAM = "laugh"

local function SayYOTHHelperLine(inst, line)
    if inst.is_yoth_helper then
        inst.components.talker:Say(STRINGS.HECKLERS_YOTH[line][math.random(#STRINGS.HECKLERS_YOTH[line])])
    end
end

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.exited_stage then
				inst.sg.statemem.keepnoclick = true
                inst.sg:GoToState("leave")
            else
                inst.AnimState:PlayAnimation("idle")
				inst:AddTag("NOCLICK")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnoclick = true
                    inst.sg:GoToState("idle")
                end
            end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.keepnoclick then
				inst:RemoveTag("NOCLICK")
			end
		end,
    },

    State{
        name = "idle_arrived",
        tags = { "idle" },

        onenter = function(inst)
            if inst.exited_stage then
                inst.sg:GoToState("leave")
            else
                inst.AnimState:PlayAnimation((math.random() < 0.2 and "idle2_arrived") or "idle_arrived")
            end

            local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
            if inst.is_yoth_helper and yoth_hecklermanager and yoth_hecklermanager:HasGivenPlaybill() and math.random() < .2 then
                SayYOTHHelperLine(inst, "SHRINE_IDLE")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
                if inst.is_yoth_helper and yoth_hecklermanager and not yoth_hecklermanager:HasGivenPlaybill() then
                    inst.sg:GoToState("give", { give_yoth_playbill = true })
                elseif inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle_arrived")
                end
            end),
        },
    },

    State{
        name = "arrive",
        tags = {"busy"},

        onenter= function(inst)
            local sound_root = "stageplay_set/heckler_"..(inst.sound_set or "a")
            inst.AnimState:PlayAnimation("arrive")
            inst.SoundEmitter:PlaySound(sound_root.."/arrive")
            --
            SayYOTHHelperLine(inst, "SHRINE_ARRIVE")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle_arrived")
                end
            end),
        }, 
    },

    State{
        name = "leave",
        tags = {"busy"},

        onenter = function(inst)
            local sound_root = "stageplay_set/heckler_"..(inst.sound_set or "a")
            inst.AnimState:PlayAnimation("leave")
            inst.SoundEmitter:PlaySound(sound_root.."/leave")

            inst:AddTag("NOCLICK")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.exited_stage = nil
                    inst.sg:GoToState("away")
                end
            end),
        },

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
        end,
    },

    State{
        name = "away",
        tags = {"busy", "away"},

        onenter = function(inst)
            inst:Hide()
        end,

        onexit = function(inst)
            inst:Show()
        end,
    },

    State{
        name = "talkto",
        tags = {"talking"},

        onenter = function(inst, data)
            local sound_root = "stageplay_set/heckler_"..(inst.sound_set or "a")

            if data.sgparam == EXCITED_PARAM then
                inst.AnimState:PlayAnimation("talk_excited_pre", false)
                inst.AnimState:PushAnimation("talk_excited_loop", false)
                inst.AnimState:PushAnimation("talk_excited_pst", false)

                inst.SoundEmitter:PlaySound(sound_root.."/talk_happy")
            elseif data.sgparam == DISAPPOINTED_PARAM then
                inst.AnimState:PlayAnimation("talk_disappointment_pre", false)
                inst.AnimState:PushAnimation("talk_disappointment_loop", false)
                inst.AnimState:PushAnimation("talk_disappointment_pst", false)

                inst.SoundEmitter:PlaySound(sound_root.."/talk_disappointment")
            elseif data.sgparam == LAUGH_PARAM then
                inst.AnimState:PlayAnimation("talk_happy_pre", false)
                inst.AnimState:PushAnimation("talk_happy_loop", false)
                inst.AnimState:PushAnimation("talk_happy_pst", false)

                inst.SoundEmitter:PlaySound(sound_root.."/laugh")
            else
                inst.AnimState:PlayAnimation("talk_happy_pre", false)
                inst.AnimState:PushAnimation("talk_happy_loop", false)
                inst.AnimState:PushAnimation("talk_happy_pst", false)

                inst.SoundEmitter:PlaySound(sound_root.."/talk_happy")
            end
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle_arrived")
                end
            end),
        },
    },

    State{
        name = "give",
        tags = { "give", "busy" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("give")

            if data ~= nil then
                inst.sg.statemem.give_yoth_playbill = data.give_yoth_playbill
            end
        end,

        timeline =
        {
            FrameEvent(8, function(inst) -- TODO TIMING
                local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
                if yoth_hecklermanager and inst.sg.statemem.give_yoth_playbill then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    LaunchAt(SpawnPrefab("playbill_the_princess_yoth"), inst, FindClosestPlayer(x, y, z, true), 1, 2.5, 1)
                    yoth_hecklermanager:SetPlaybillGiven()
                    SayYOTHHelperLine(inst, "SHRINE_GIVE_PLAYBILL")
                end
            end)
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle_arrived")
                end
            end),
        },
    },
}

return StateGraph("charlie_heckler", states, events, "idle")
