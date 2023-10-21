require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.EQUIP, "pickup"),
    ActionHandler(ACTIONS.TAKEITEM, "pickup"),
}


local function DoTalkSound(inst)
    if inst.talksoundoverride ~= nil then
        inst.SoundEmitter:PlaySound(inst.talksoundoverride, "talk")
        return true
    else

        inst.SoundEmitter:PlaySound("moonstorm/characters/wagstaff/talk_LP", "talk")
        return true
    end
end

local function StopTalkSound(inst, instant)
    if not instant and inst.endtalksound ~= nil and inst.SoundEmitter:PlayingSound("talk") then
        inst.SoundEmitter:PlaySound(inst.endtalksound)
    end
    inst.SoundEmitter:KillSound("talk")
end


local events =
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    EventHandler("waitfortool", function(inst)
        inst.sg:GoToState("idle")
    end),
    EventHandler("doexperiment", function(inst)
        inst.sg:GoToState("idle_experiment")
    end),
    EventHandler("doneexperiment", function(inst)
        inst.sg:GoToState("idle")
    end),
    EventHandler("talk", function(inst)
        inst.sg:GoToState("talk")
    end),
    EventHandler("talk_experiment", function(inst)
        inst.sg:GoToState("talk","wait_search")
    end),
    EventHandler("startwork", function(inst, target)
        inst.sg:GoToState("capture_appearandwork", target)
    end),
    EventHandler("continuework", function(inst)
        inst.sg:GoToState("capture_appearandwork", "continuework")
    end),
}

local ERODEOUT_DATA =
{
    time = 4.0,
    erodein = false,
    remove = true,
}

local states =
{

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, anim)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation(anim or "emote_impatient", true)

            if anim then
                inst.sg.statemem.anim = anim
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle", inst.sg.statemem.anim)
                end
            end),
        },
    },

    State{
        name = "talk",
        tags = { "idle", "talking" },

        onenter = function(inst,exitstate)
            if exitstate then
                inst.sg.statemem.exitstate = exitstate
            end
            inst.AnimState:PlayAnimation("dial_loop",true)

            DoTalkSound(inst)
            inst.sg:SetTimeout(1.5 + math.random() * .5)
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.exitstate then
                inst.sg:GoToState(inst.sg.statemem.exitstate)
            else
                inst.sg:GoToState("idle")
            end
        end,

        events =
        {
            EventHandler("donetalking", function(inst)
                if inst.sg.statemem.exitstate then
                    inst.sg:GoToState(inst.sg.statemem.exitstate)
                else
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = StopTalkSound,
    },

    State{
        name = "idle_experiment",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation("build_loop", true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle_experiment")
                end
            end),
        },
    },


    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/pig/grunt")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/pig/oink")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "dropitem",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("pig_pickup")
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "cheer",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("buff")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "win_yotb",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("win")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "wait_search",
        tags = { },

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("emote_impatient")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("wait_search")
            end),
        },
    },

    State{
        name = "capture_appearandwork",
        tags = {},

        onenter = function(inst, target)
            inst.Physics:Stop()

            inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTART)

            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)

            if target ~= nil then 
                if type(target) == "string" then
                    inst.sg.statemem.notimeout = true
                elseif target:IsValid() then
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                    inst.sg.statemem.target = target
                end
            end

            if TUNING.SPAWN_RIFTS == 1 and TheWorld.components.riftspawner and not TheWorld.components.riftspawner:GetLunarRiftsEnabled()  then
                if not inst.sg.statemem.notimeout then
                    inst.sg:SetTimeout(119)
                end

                if TheWorld.components.riftspawner and not TheWorld.components.riftspawner:GetLunarRiftsEnabled() then
                    inst.sg.statemem.request = 1
					if inst.components.trader ~= nil then
						inst.components.trader:Enable()
					end
					if inst.components.constructionsite ~= nil then
						inst.components.constructionsite:Enable()
					end
                    inst.request_task = inst:DoPeriodicTask(10,inst.doplayerrequest)
                end
            else
                inst.sg:SetTimeout(4)
            end
        end,

        onexit = function(inst)
			if inst.components.trader ~= nil then
				inst.components.trader:Disable()
			end
			if inst.components.constructionsite ~= nil then
				inst.components.constructionsite:Disable()
			end
            if inst.request_task then
                inst.request_task:Cancel()
                inst.request_task = nil
            end
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                inst.sg.statemem.target:PushEvent("orbtaken")
            end

            if inst._device ~= nil and inst._device:IsValid() then
                inst._device:PushEvent("docollect")
            end

            inst.sg:GoToState("capture_pst")
        end,
    },

    State{
        name = "capture_pst",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("build_pst")

            inst.sg:SetTimeout(3 + inst.AnimState:GetCurrentAnimationLength())
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.rifts_are_open then
                    inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTOP1)
                    inst.sg:GoToState("talk", "capture_emotebuffer_bonus")
                else
                    inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTOP)
                    inst.sg:GoToState("talk", "capture_emotebuffer")
                end
            end),
        },

        ontimeout = function(inst)
            if inst.rifts_are_open then
                inst.sg:GoToState("capture_emotebuffer_bonus")
            else
                inst.sg:GoToState("capture_emotebuffer")
            end
        end,
    },

    State{
        name = "capture_emotebuffer_bonus",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()

            if not inst.AnimState:IsCurrentAnimation("emote_impatient") then
                inst.AnimState:PlayAnimation("emote_impatient", true)
            end

            inst.sg:SetTimeout(0.3)
        end,

        ontimeout = function(inst)
            inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTOP)
            inst.sg:GoToState("talk", "capture_emotebuffer")
        end,
    },

    State{
        name = "capture_emotebuffer",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()

            if not inst.AnimState:IsCurrentAnimation("emote_impatient") then
                inst.AnimState:PlayAnimation("emote_impatient", true)
            end

            inst.sg:SetTimeout(1.5)
        end,

        ontimeout = function(inst)
            if inst:HasTag("shard_recieved") then
                inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTOP3)
            else
                inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_CAPTURESTOP2)
            end
            inst.sg:GoToState("talk", "capture_emote")
        end,
    },

    State{
        name = "capture_emote",
        tags = {"busy"},

		onenter = function(inst, norelocate)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("dial_loop")
            inst.AnimState:PushAnimation("research", true)

            inst.sg:SetTimeout(15)
			inst.sg.statemem.norelocate = norelocate
        end,

        ontimeout = function(inst)
            inst:Remove()
        end,

        timeline =
        {
            TimeEvent(1.0, function(inst)
				if inst.sg.statemem.norelocate then
					local data = shallowcopy(ERODEOUT_DATA)
					data.norelocate = true
					inst:PushEvent("doerode", data)
				else
					inst:PushEvent("doerode", ERODEOUT_DATA)
				end
            end),
        },
    },

    State{
        name = "analyzing_pre",
        tags = { "busy" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation("notes_pre")
            inst.AnimState:PushAnimation("notes_loop", true)

            inst.sg:SetTimeout(inst.TIME_TAKING_NOTES)
        end,

        ontimeout = function(inst)
            inst.AnimState:PlayAnimation("notes_pst")
            inst.AnimState:PushAnimation("idle_loop", true)
        end,
    },

    State{
        name = "analyzing",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("idle_loop", true)
        end,

        events =
        {
            EventHandler("ontalk", function(inst)
                inst.sg:GoToState("talk", "analyzing")
            end),

            EventHandler("donetalking", function(inst)
                inst.sg:GoToState("analyzing_pst_buffer")
            end),
        },
    },

    State{
        name = "analyzing_pst_buffer",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("idle_loop", true)

            inst.sg:SetTimeout(2.5)
        end,

        ontimeout = function(inst)
            inst.components.talker:Say(STRINGS.WAGSTAFF_NPC_ANALYSIS_OVER[math.random(#STRINGS.WAGSTAFF_NPC_ANALYSIS_OVER)])
            inst.sg:GoToState("talk", "analyzing_pst")
        end,
    },

    State{
        name = "analyzing_pst",
        tags = { "busy" },

        onenter = function(inst, norelocate)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end

            inst.AnimState:PlayAnimation("idle_loop", true)

            inst.sg:SetTimeout(10)
        end,

        ontimeout = function(inst)
            inst:Remove()
        end,

        timeline =
        {
            TimeEvent(1.5, function(inst)
                if inst:IsAsleep() then
                    inst:Remove()
                else
                    local data = shallowcopy(ERODEOUT_DATA)
                    data.norelocate = true
                    inst:PushEvent("doerode", data)
                end
            end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
    walktimeline =
    {
        TimeEvent(0, PlayFootstep),
        TimeEvent(12 * FRAMES, PlayFootstep),
    },
})

CommonStates.AddRunStates(states,
{
    runtimeline =
    {
        TimeEvent(0, PlayFootstep),
        TimeEvent(10 * FRAMES, PlayFootstep),
    },
})

CommonStates.AddSimpleState(states, "refuse", "pig_reject", { "busy" })
CommonStates.AddSimpleActionState(states, "pickup", "pig_pickup", 10 * FRAMES, { "busy" })
CommonStates.AddSimpleActionState(states, "gohome", "pig_pickup", 4 * FRAMES, { "busy" })

return StateGraph("wagstaff_npc", states, events, "idle", actionhandlers)
