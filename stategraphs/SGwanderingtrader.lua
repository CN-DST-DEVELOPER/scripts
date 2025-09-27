require("stategraphs/commonstates")

-- NOTES(JBK): The wanderingtrader is very relaxed and slow moving.
-- Any pending state change should happen in a sluggish way.

local events = {
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnHop(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    EventHandler("dotrade", function(inst, data)
        if not inst.sg:HasStateTag("busy") then
			inst.sg.statemem.keeprevealed = true
            inst.sg:GoToState("dotrade", data)
        end
    end),
    EventHandler("arrive", function(inst)
        inst.sg:GoToState("arrive")
    end),
}

local states = {
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle_hooded", true)
        end,

        onupdate = function(inst)
			if not inst:IsAsleep() then
				if inst.sg.mem.trading then
					inst.sg:GoToState("trading_start")
				elseif inst:HasStock() and inst:IsNearPlayer(TUNING.RESEARCH_MACHINE_DIST, true) then
					inst:EnablePrototyper(true)
					inst.sg:GoToState("trading_start")
				end
			end
        end,
    },

    State{
        name = "walk_start",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("walk_pre")
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.sg.mem.trading then
                    inst.sg:GoToState("walk_stop")
                else
                    inst.sg:GoToState("walk")
                end
            end),
        },
    },

    State{
        name = "walk",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("walk_loop")
        end,
        onupdate = function(inst)
            if inst.sg.mem.trading then
                inst.sg:GoToState("walk_stop")
            end
        end,
        onexit = function(inst)
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "dappertrot")
        end,
        timeline = {
            TimeEvent(2*FRAMES, function(inst) PlayFootstep(inst) end),
            TimeEvent(8*FRAMES, function(inst) inst.components.locomotor:SetExternalSpeedMultiplier(inst, "dappertrot", 0.35) end),
            TimeEvent(16*FRAMES, function(inst) inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "dappertrot") end),
            TimeEvent(33*FRAMES, function(inst) PlayFootstep(inst) end),
            TimeEvent(35*FRAMES, function(inst) inst.components.locomotor:SetExternalSpeedMultiplier(inst, "dappertrot", 0.35) end),
            TimeEvent(43*FRAMES, function(inst) inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "dappertrot") end),
        },
        events = {
            EventHandler("animover", function(inst)
                if inst.sg.mem.trading then
                    inst.sg:GoToState("walk_stop")
                else
                    inst.sg:GoToState("walk")
                end
            end),
        },
    },

    State{
        name = "walk_stop",
        tags = {"canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("walk_pst")
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.sg.mem.trading then
                    inst.sg:GoToState("trading_start")
                else
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "trading_start",
		tags = { "canrotate", "revealed" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("reveal")
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/reveal")
			inst:SetRevealed(true)
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:IsCurrentAnimation("reveal") then
                    if inst.sg.mem.trading then
                        inst.AnimState:PlayAnimation("trade_pre")
                        inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/trade_pre")
                    else
                        inst.AnimState:PlayAnimation("conceal")
                        inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/conceal")
                    end
                elseif inst.AnimState:IsCurrentAnimation("trade_pre") then
					inst.sg.statemem.keeprevealed = true
                    if inst.sg.mem.trading then
                        inst.sg:GoToState("trading")
                    else
                        inst.sg:GoToState("trading_stop")
                    end
                else -- conceal
                    inst.sg:GoToState("idle")
                end
            end),
        },
		onexit = function(inst)
			if not inst.sg.statemem.keeprevealed then
				inst:SetRevealed(false)
			end
		end,
    },
    State{
        name = "trading",
		tags = { "canrotate", "revealed" },

        onenter = function(inst, data)
            if data == nil or not data.repeating then
                inst:TryChatter("WANDERINGTRADER_STARTTRADING", math.random(#STRINGS.WANDERINGTRADER_STARTTRADING), 1.5)
            end
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("trade_loop")
			inst:SetRevealed(true)
        end,
        onupdate = function(inst)
            if not inst.sg.mem.trading then
                inst.sg:GoToState("trading_stop")
            end
        end,
        events = {
            EventHandler("animover", function(inst)
				inst.sg.statemem.keeprevealed = true
                if inst.sg.mem.trading then
                    inst.sg:GoToState("trading", {repeating = true,})
                else
                    inst.sg:GoToState("trading_stop")
                end
            end),
        },
		onexit = function(inst)
			if not inst.sg.statemem.keeprevealed then
				inst:SetRevealed(false)
			end
		end,
    },
    State{
        name = "trading_stop",
		tags = { "canrotate", "revealed" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("trade_pst")
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/trade_pst")
            if inst.sg.mem.didtrade then
                inst:TryChatter("WANDERINGTRADER_ENDTRADING_MADETRADE", math.random(#STRINGS.WANDERINGTRADER_ENDTRADING_MADETRADE), 1.5)
                inst.sg.mem.didtrade = nil
            else
                inst:TryChatter("WANDERINGTRADER_ENDTRADING_NOTRADES", math.random(#STRINGS.WANDERINGTRADER_ENDTRADING_NOTRADES), 1.5)
            end
			inst:SetRevealed(true)
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:IsCurrentAnimation("trade_pst") then
                    if inst.sg.mem.trading then
                        inst.AnimState:PlayAnimation("trade_pre")
                        inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/trade_pre")
                    else
                        inst.AnimState:PlayAnimation("conceal")
                        inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/conceal")
                    end
                elseif inst.AnimState:IsCurrentAnimation("trade_pre") then
					inst.sg.statemem.keeprevealed = true
                    if inst.sg.mem.trading then
                        inst.sg:GoToState("trading")
                    else
                        inst.sg:GoToState("trading_stop")
                    end
                else -- conceal
                    inst.sg:GoToState("idle")
                end
            end),
        },
		onexit = function(inst)
			if not inst.sg.statemem.keeprevealed then
				inst:SetRevealed(false)
			end
		end,
    },
    State{
        name = "dotrade",
		tags = { "busy", "revealed" },
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("trade_give")
            if data and data.no_stock then
                inst:DoChatter("WANDERINGTRADER_OUTOFSTOCK_FROMTRADES", math.random(#STRINGS.WANDERINGTRADER_OUTOFSTOCK_FROMTRADES), 15)
            else
                if not inst.sg.mem.didtrade then
                    inst:DoChatter("WANDERINGTRADER_DOTRADE", math.random(#STRINGS.WANDERINGTRADER_DOTRADE), 1.5)
                else
                    inst:TryChatter("WANDERINGTRADER_DOTRADE", math.random(#STRINGS.WANDERINGTRADER_DOTRADE), 1.5)
                end
            end
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/trade") -- FIXME(JBK): WT: Sounds.
			inst:SetRevealed(true)
        end,
        events = {
            EventHandler("animover", function(inst)
				inst.sg.statemem.keeprevealed = true
                inst.sg:GoToState("trading") -- Let this state get out of trading.
            end),
        },
		onexit = function(inst)
			if not inst.sg.statemem.keeprevealed then
				inst:SetRevealed(false)
			end
		end,
    },

    State{
        name = "talking",
		tags = { "canrotate", "revealed" },

        onenter = function(inst, already_talking)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("talk")
            if not already_talking then
                inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/talk_LP", "talk_loop")
            end
			inst:SetRevealed(true)
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg.statemem.keep_talking = true
				inst.sg.statemem.keeprevealed = true
                inst.sg:GoToState("talking", true)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.keep_talking then
                inst.SoundEmitter:KillSound("talk_loop")
            end
			if not inst.sg.statemem.keeprevealed then
				inst:SetRevealed(false)
			end
        end,
    },

    State{
        name = "teleport",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.talker:ShutUp()
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("disappear")
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/disappear")
        end,

        timeline = {
			FrameEvent(24, function(inst)
				inst.DynamicShadow:Enable(false)
				inst.sg:AddStateTag("invisible")
				inst:AddTag("NOCLICK")
			end),
        },

        onexit = function(inst)
            inst.DynamicShadow:Enable(true)
			inst:RemoveTag("NOCLICK")
        end,

        events = {
            EventHandler("animover", function(inst)
				if inst.HiddenActionFn then
					inst:HiddenActionFn()
				else
					inst.sg:GoToState("arrive")
				end
            end),
			EventHandler("arrive", function(inst)
				if inst:IsAsleep() then
					inst.sg:GoToState("idle")
					return true
				end
			end),
        },
    },

    State{
        name = "arrive",
		tags = { "busy", "invisible" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("appear")
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/appear")
            inst.DynamicShadow:Enable(false)
			inst:AddTag("NOCLICK")
        end,

        timeline = {
			FrameEvent(2, function(inst)
				inst.DynamicShadow:Enable(true)
				inst:RemoveTag("NOCLICK")
				inst.sg:RemoveStateTag("invisible")
			end),
        },

        onexit = function(inst)
            inst.DynamicShadow:Enable(true)
			inst:RemoveTag("NOCLICK")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hide",

        onenter = function(inst)
            inst.components.talker:ShutUp()
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("disappear")
            inst.SoundEmitter:PlaySound("dontstarve/characters/skincollector/ingame/conceal")
        end,

        timeline = {
			FrameEvent(24, function(inst)
				inst.DynamicShadow:Enable(false)
				inst.sg:AddStateTag("invisible")
				inst:AddTag("NOCLICK")
			end),
        },

        onexit = function(inst)
            inst.DynamicShadow:Enable(true)
			inst:RemoveTag("NOCLICK")
        end,

        events = {
            EventHandler("animover", function(inst)
				if inst.HiddenActionFn then
					inst:HiddenActionFn()
				end
            end),
        },
    },

    State{ -- Blank state to do absolutely nothing when removed from the scene.
        name = "hiding",
    },
}

CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("wanderingtrader", states, events, "idle")
