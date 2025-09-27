require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")
local WobyCommon = require("prefabs/wobycommon")

local actionhandlers =
{
    ActionHandler(ACTIONS.WOBY_PICKUP, "pickup"),
    ActionHandler(ACTIONS.GIVEALLTOPLAYER, "give"),
    ActionHandler(ACTIONS.WOBY_PICK, "dolongaction"),
    ActionHandler(ACTIONS.STORE, "dolongaction"),
}

local LONGACTION_DEFAULT_TIMEOUT = 1.5

local events =
{
    SGCritterEvents.OnEat(),
    SGCritterEvents.OnAvoidCombat(),
    SGCritterEvents.OnTraitChanged(),

    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
    CommonHandlers.OnLocomote(false,true),
    CommonHandlers.OnHop(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),

    EventHandler("transform", function(inst, data)
        if inst.sg.currentstate.name ~= "transform" then
            inst.sg:GoToState("transform")
        end
    end),

	EventHandler("showrack", function(inst)
		if not (inst.sg:HasStateTag("jumping") or
				inst.sg:HasStateTag("nointerrupt") or
				inst.sg.currentstate.name == "transform")
		then
			inst.sg:GoToState("rack_appear")
		end
	end),

	EventHandler("showalignmentchange", function(inst)
		if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("sitting") then
			inst.sg:GoToState("emote_cute")
			inst.components.locomotor:StopMoving()
		end
	end),

    EventHandler("start_sitting", function(inst)
        if not inst.sg:HasStateTag("sitting") and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("sitting")
        end
    end),
}

-----------------------------------------------------------------------------------------------------------------------

local states =
{
        State{
        name="transform",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
			inst:ApplyBigBuildOverrides()
            inst.AnimState:PlayAnimation("transform_small_to_big")
			inst:AddTag("transforming")
        end,

        timeline =
        {
            TimeEvent(1*FRAMES,  function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/transform_small_to_big") end),
			FrameEvent(37, function(inst)
				if inst.components.wobyrack then
					inst.SoundEmitter:PlaySound("meta5/woby/big_dryingrack_deploy")
				end
			end),
			FrameEvent(40, function(inst)
				if inst.pet_hunger_classified then
					inst.pet_hunger_classified:SetFlagBit(0, true) --big woby
				end
			end),
            TimeEvent(41*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/roar") end),
            TimeEvent(42*FRAMES, function(inst) inst.DynamicShadow:SetSize(3, 1.5) end),
            TimeEvent(53*FRAMES, function(inst) inst.DynamicShadow:SetSize(5, 2) end),
        },

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:FinishTransformation()
				end
			end),
		},

		onexit = function(inst)
			--Interrupted???
			if inst.pet_hunger_classified then
				inst.pet_hunger_classified:SetFlagBit(0, false) --small woby
			end
			inst:RemoveTag("transforming")
		end,
    },

    State{
        name = "despawn",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,

        onexit = function(inst)
            inst:DoTaskInTime(0, inst.Remove)
        end,
    },

    State{
        name = "pickup",
        tags = {"busy", "jumping"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.AnimState:PlayAnimation("fetch")
            inst.AnimState:SetFrame(6)
			inst.SoundEmitter:PlaySound("meta5/woby/woby_pounce")

			inst.sg.statemem.buffaction = inst:GetBufferedAction()
            local target = inst.sg.statemem.buffaction and inst.sg.statemem.buffaction.target or nil
            if target ~= nil and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end
        end,

        onupdate = function(inst)
            local buffaction = inst:GetBufferedAction()
			if buffaction ~= inst.sg.statemem.buffaction then
				buffaction = nil
			end
            local target = buffaction ~= nil and buffaction.target or nil

            if target == nil or not target:IsValid() then
                inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()

                inst:ClearBufferedAction()

                return
            end

            local distance = math.sqrt(inst:GetDistanceSqToInst(target))

            if distance > .2 then
                inst.Physics:SetMotorVelOverride(math.max(distance, 4), 0, 0)
            else
                inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
            end
        end,

        timeline = {
            TimeEvent((7-6)*FRAMES, function(inst) PlayFootstep(inst, 0.25) end),
    
            TimeEvent((21-6)*FRAMES, function(inst)
                local buffaction = inst:GetBufferedAction()
                local target = buffaction ~= nil and buffaction.target or nil
    
                if target == nil or not target:IsValid() then
                    inst.sg.statemem.missed = true

                    return -- Fail! No target.
                end

                local distance = math.sqrt(inst:GetDistanceSqToInst(target))

                if distance > .75 then
                    inst:ClearBufferedAction()

                    inst.sg.statemem.missed = true
                else
                    inst:PerformBufferedAction()
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(inst.sg.statemem.missed and "pickup_pst_fail" or "pickup_pst_success")
                end
            end)
        },

        onexit = function(inst)
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst.Physics:Stop()
			if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction == inst.bufferedaction then
				inst:ClearBufferedAction()
			end
        end,
    },

    State{
        name = "pickup_pst_success",
        tags = {"busy", "jumping"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("fetch_pst")
        end,

        timeline =
        {
            FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/bodyfall", nil, .25) end),
            FrameEvent(8,  function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
            FrameEvent(16, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end)
        },
    },

    State{
        name = "pickup_pst_fail",
        tags = {"busy", "jumping"},

        onenter = function(inst, missed)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("fetch_fail_pst")
        end,

        timeline =
        {
            FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/bodyfall", nil, .5) end),
            FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
            FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
            FrameEvent(27, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
            FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
            FrameEvent(36, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end)
        },
    },

    State {
        name = "give",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("give")
			inst.sg.statemem.buffaction = inst:GetBufferedAction()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        timeline =
        {
            FrameEvent(8, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),

            FrameEvent(10, function(inst)
                inst:PerformBufferedAction()
            end),
        },

		onexit = function(inst)
			if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction == inst.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
    },

    State{
        name = "dolongaction",
		tags = {"busy"},

        onenter = function(inst, timeout)
            timeout = timeout or LONGACTION_DEFAULT_TIMEOUT

            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("woby_forage_pre")
            inst.AnimState:PushAnimation("woby_forage_loop", true)

            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")

            inst.sg.statemem.buffaction = inst:GetBufferedAction()
            if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction.target and inst.sg.statemem.buffaction.target.components.container then
                inst.sg.statemem.openedchest = inst.sg.statemem.buffaction.target
                inst.sg.statemem.openedchest.components.container:Open(inst)
			else
				inst.sg.statemem.digging = true
				inst.SoundEmitter:PlaySound("meta5/woby/woby_dig_lp", "dig")
            end

            inst.sg:SetTimeout(timeout)
        end,

        ontimeout = function(inst)
            inst.AnimState:PlayAnimation("woby_forage_pst")
            inst.SoundEmitter:KillSound("make")
			inst.SoundEmitter:KillSound("dig")

			if inst:PerformBufferedAction() then
				if inst.sg.statemem.digging then
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark")
				end
			end
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),

            EventHandler("playernewstate", function(inst)
                if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction == inst.bufferedaction then
                    local pickable = inst.bufferedaction.target ~= nil and inst.bufferedaction.target.components.pickable or nil

                    if pickable ~= nil and pickable:CanBePicked() then -- If we can be picked, Walter didn't finish it!
                        inst.AnimState:PlayAnimation("woby_forage_pst")
                        inst.SoundEmitter:KillSound("make")
						inst.SoundEmitter:KillSound("dig")

                        inst:ClearBufferedAction()
                    end
                end
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("make")
			inst.SoundEmitter:KillSound("dig")
            if inst.sg.statemem.openedchest and inst.sg.statemem.openedchest:IsValid() and inst.sg.statemem.openedchest.components.container then
                inst.sg.statemem.openedchest.components.container:Close(inst)
            end
			if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction == inst.bufferedaction then
				inst:ClearBufferedAction()
			end
        end,
    },

    State{
        name = "sitting",
		tags = {"busy", "canrotate", "sitting"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            if inst.sg.lasttags["moving"] then
                inst.AnimState:PlayAnimation("walk_pst")
                inst.AnimState:PushAnimation("sit_woby")

                inst.sg.statemem.fromwalking = true
            else
                inst.AnimState:PlayAnimation("sit_woby")
            end

            inst.AnimState:PushAnimation("sit_woby_loop", true)
        end,

        timeline =
		{
            FrameEvent(8, function(inst)
				if not inst.sg.statemem.fromwalking then
					PlayFootstep(inst, 0.25)
				end
			end),

			FrameEvent(12, function(inst)
				if inst.sg.statemem.fromwalking then
					PlayFootstep(inst, 0.25)
				end
			end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),

            EventHandler("stop_sitting", function(inst)
                if inst:IsAsleep() then
                    inst.sg:GoToState("idle")
                else
                    inst.AnimState:PlayAnimation("sit_woby_pst")

                    PlayFootstep(inst, 0.25)
                end
            end),
        },
    },

	State{
		name = "rack_appear",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("woby_rack_appear")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("meta5/woby/small_dryingrack_deploy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},
}

local emotes =
{
    { anim="emote_scratch",
      timeline=
         {
            TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(26*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(45*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
            TimeEvent(55*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        },
    },
    { anim="emote_play_dead",
      timeline=
         {
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(48*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(76*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
    },
}

SGCritterStates.AddIdle(states, #emotes,
	--[[{
        --TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
	}]]nil,
	function(inst)
		if inst.sg.mem.recentlytransformed then
			inst.sg.mem.recentlytransformed = nil
			if inst.sg.lasttags and inst.sg.lasttags["idle"] then
				return "idle_loop_nodir"
			end
		end
		return "idle_loop"
	end)
SGCritterStates.AddRandomEmotes(states, emotes)
SGCritterStates.AddEmote(states, "cute",
    {
        TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(19*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(22*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(25*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(29*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
        TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/stallion") end),
    })
SGCritterStates.AddPetEmote(states,
    {
		TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        TimeEvent(8*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(12*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(16*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
        TimeEvent(24*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
    })
SGCritterStates.AddCombatEmote(states,
    {
        pre =
        {
            TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
        loop =
        {
            TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
            TimeEvent(26*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(48*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
        },
    })
SGCritterStates.AddPlayWithOtherCritter(states, events,
    {
        active =
        {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
            TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
        },
        passive =
        {
            TimeEvent(5*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
        },
    })
SGCritterStates.AddEat(states,
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/eat") end),
    })


SGCritterStates.AddHungry(states,
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/bark") end),
    })
SGCritterStates.AddNuzzle(states, actionhandlers,
    {
        TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        TimeEvent(13*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
        TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/emote_scratch") end),
        TimeEvent(36*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
    })

SGCritterStates.AddWalkStates(states,
    {
        starttimeline =
        {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
        },
        walktimeline =
        {
            TimeEvent(1*FRAMES, function(inst) PlayFootstep(inst, 0.25) end),
            TimeEvent(4*FRAMES, function(inst) PlayFootstep(inst, 0.25) end),
        },
    }, true)

CommonStates.AddSleepExStates(states,
    {
        starttimeline =
        {
            TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/growl") end),
        },
        sleeptimeline =
        {
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/sleep") end),
        },
    })

CommonStates.AddHopStates(states, true)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("wobysmall", states, events, "idle", actionhandlers)
