require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")
local WobyCommon = require("prefabs/wobycommon")

local RANDOM_IDLES = { "bark_idle", "shake", --[["sit",]] "scratch" }

local actionhandlers =
{
    ActionHandler(ACTIONS.WOBY_PICKUP, "pickup"),
    ActionHandler(ACTIONS.GIVEALLTOPLAYER, "give"),
    ActionHandler(ACTIONS.WOBY_PICK, "dolongaction"),
    ActionHandler(ACTIONS.CHOP, "bash_jump"),
    ActionHandler(ACTIONS.MINE, "bash_jump"),
    ActionHandler(ACTIONS.STORE, "dolongaction"),
}

local LONGACTION_DEFAULT_TIMEOUT = 1.5

local events=
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true,true),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnHop(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),

    EventHandler("transform", function(inst, data)
        if inst.sg.currentstate.name ~= "transform" then
            inst.sg:GoToState("transform")
        end
    end),

	EventHandler("showrack", function(inst)
		if not (inst.components.rideable:IsBeingRidden() or
				inst.sg:HasStateTag("jumping") or
				inst.sg:HasStateTag("nointerrupt") or
				inst.sg.currentstate.name == "transform")
		then
			inst.sg:GoToState("rack_appear")
		end
	end),

	EventHandler("showalignmentchange", function(inst)
		if not (inst.components.rideable:IsBeingRidden() or inst.sg:HasStateTag("busy")) or inst.sg:HasStateTag("sitting") then
			inst.sg:GoToState("bark_idle", true)
		end
	end),

    EventHandler("start_sitting", function(inst, data)
        if inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("sitting") then
            return -- Busy and not in a sitting states.
        end

        if data.iscower and not inst.sg:HasStateTag("cower") then
            inst.sg:GoToState("sitting_cower")

        elseif not inst.sg:HasStateTag("sitting") or inst.sg:HasStateTag("cower") then
            inst.sg:GoToState("sitting")
        end
    end),

    SGCritterEvents.OnEat(),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()

            if pushanim then
                inst.AnimState:PushAnimation("idle_loop", true)
			elseif inst.sg.mem.recentlytransformed and inst.sg.lasttags and inst.sg.lasttags["idle"] then
				inst.AnimState:PlayAnimation("idle_loop_nodir", true)
			else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end

			inst.sg.mem.recentlytransformed = nil
            inst.sg:SetTimeout(2 + math.random())
        end,

        ontimeout=function(inst)
            if not inst.components.sleeper:IsAsleep() then
                local hounded = TheWorld.components.hounded
                if hounded ~= nil and (hounded:GetWarning() or hounded:GetAttacking()) then
                    inst.sg:GoToState("bark_idle")
                else
                    inst.sg:GoToState(RANDOM_IDLES[math.random(1, #RANDOM_IDLES)])
                end
            end
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
        name = "bark_idle",
        tags = { "idle" },
		onenter = function(inst, makebusy)
            inst.components.locomotor:StopMoving()
            if not inst.AnimState:IsCurrentAnimation("bark1_woby") then
                inst.AnimState:PlayAnimation("bark1_woby", false)
                inst.AnimState:PushAnimation("bark1_woby", false)
            end
			if makebusy then
				inst.sg:RemoveStateTag("idle")
				inst.sg:AddStateTag("busy")
			end
        end,

        timeline=
        {
            TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/bark") end),
            TimeEvent(34*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/bark") end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "shake",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("shake_woby")
        end,

        timeline=
        {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(8*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name="eat",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("eat_pre", false)
            inst.AnimState:PushAnimation("eat_loop", false)
            inst.AnimState:PushAnimation("eat_pst", false)
            inst.SoundEmitter:PlaySound("dontstarve/beefalo/chew")
        end,

        timeline =
        {
            TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/chuff") end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "sit",
		tags = { "idle" },
        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if not (inst.AnimState:IsCurrentAnimation("sit_woby") or
               inst.AnimState:IsCurrentAnimation("sit_woby_loop") or
               inst.AnimState:IsCurrentAnimation("sit_woby_pst")) then

                inst.AnimState:PlayAnimation("sit_woby", false)
                inst.AnimState:PushAnimation("sit_woby_loop", false)
                inst.AnimState:PushAnimation("sit_woby_loop", false)
                inst.AnimState:PushAnimation("sit_woby_loop", false)
                inst.AnimState:PushAnimation("sit_woby_pst", false)
            end
        end,

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .8}) end),
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= 1}) end),

        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "cower",
        tags = {"canrotate", "alert"},

        onenter = function(inst)
            inst.sg:GoToState("actual_cower")
        end,
    },

    State{
        name = "actual_cower",
        tags = {"idle", "canrotate", "alert"},
        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if not inst.AnimState:IsCurrentAnimation("cower_woby_loop") then
                inst.AnimState:PlayAnimation("cower_woby_pre", false)
                inst.AnimState:PushAnimation("cower_woby_loop", true)
            end
        end,

        timeline=
        {
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/wimper") end),
        },

        onexit = function(inst)
            inst.AnimState:PlayAnimation("cower_woby_pst", false)
        end,
    },

    State{
        name = "scratch",
        tags = {"idle"},
        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if not (inst.AnimState:IsCurrentAnimation("scratch_woby_pre") or
               inst.AnimState:IsCurrentAnimation("scratch_woby_loop") or
               inst.AnimState:IsCurrentAnimation("scratch_woby_pst")) then

                inst.AnimState:PlayAnimation("scratch_woby_pre", false)
                inst.AnimState:PushAnimation("scratch_woby_loop", false)
                inst.AnimState:PushAnimation("scratch_woby_pst", false)
            end
        end,

        timeline=
        {
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/foley", {intensity= .5}) end),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/foley", {intensity= .7}) end),
            TimeEvent(24*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/foley", {intensity= .9}) end),
        },

        events=
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name="transform",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
			inst:ApplySmallBuildOverrides()
            inst.AnimState:PlayAnimation("transform_big_to_small")
			inst:AddTag("transforming")
			if inst.components.wobyrack then
				inst.SoundEmitter:PlaySound("meta5/woby/small_dryingrack_collapse")
			end
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/transform_big_to_small") end),
            -- TimeEvent(39*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/transform_big_to_small") end),
			FrameEvent(4, function(inst) inst.DynamicShadow:SetSize(4, 1.5)  end),
            TimeEvent(13*FRAMES, function(inst) inst.DynamicShadow:SetSize(3, 1.0)  end),
			FrameEvent(59, function(inst)
				if inst.pet_hunger_classified then
					inst.pet_hunger_classified:SetFlagBit(0, false) --small woby
				end
				--We can now force transform without starving
				--Make sure we don't just transform right back due to >= 95% hunger though
				local cost = TUNING.WOBY_FORCE_TRANSFORM_HUNGER
				if inst:HasEndurance() then
					cost = cost * TUNING.SKILLS.WALTER.WOBY_ENDURANCE_HUNGER_RATE_MOD
				end
				inst.components.hunger:DoDelta(-cost)
			end),
            TimeEvent(60*FRAMES, function(inst) inst.DynamicShadow:SetSize(1.75, 1) end),
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
				inst.pet_hunger_classified:SetFlagBit(0, true) --big woby
			end
			inst:RemoveTag("transforming")
		end,
    },

    -- Used when the player is about to mount
    State{
        name = "alert",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.sg:GoToState("actual_alert")
        end,
    },

    State{
        name = "actual_alert",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if not inst.AnimState:IsCurrentAnimation("alert_woby_loop") then
                inst.AnimState:PlayAnimation("alert_woby_pre")
                inst.AnimState:PushAnimation("alert_woby_loop", true)
            end
        end,
        timeline=
        {
            TimeEvent(2*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/chuff") end),
        },

    },

    State{
        name = "sit_alert_tailwag",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.sg:GoToState("actual_sit_alert_tailwag")
        end,
    },

    State{
        name = "actual_sit_alert_tailwag",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("sit_woby")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("actual_sit_alert_tailwag_loop") end),
        },
    },


    State{
        name = "actual_sit_alert_tailwag_loop",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("sit_woby_tailwag_loop", true)
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline=
        {
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(8*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(12*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(16*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(24*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(31*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
            TimeEvent(35*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/tail") end),
        },

        ontimeout = function(inst) inst.sg:GoToState("actual_sit_alert_tailwag_loop") end,
    },

    State{
        name = "sit_alert",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.sg:GoToState("actual_sit_alert")
        end,
    },

    State{
        name = "actual_sit_alert",
        tags = {"idle", "canrotate", "alert"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            if not inst.AnimState:IsCurrentAnimation("sit_woby_loop") then
                inst.AnimState:PlayAnimation("sit_woby")
                inst.AnimState:PushAnimation("sit_woby_loop", true)
            end
        end,

        timeline=
        {
            TimeEvent(2*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
            TimeEvent(4*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/chuff") end),
        },


    },

    State{
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_woby_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("run")
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_woby_loop", true)
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline=
        {
            TimeEvent(math.random(1,11)*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/run_chuff") end),
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= 1}) end),
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= 1}) end),
            TimeEvent(8*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= 1}) end),
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= 1}) end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = { "idle" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("run_woby_pst")
        end,

        timeline=
        {
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "pickup",
        tags = { "busy", "jumping" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.AnimState:PlayAnimation("fetch")
            inst.AnimState:SetFrame(4)
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
            FrameEvent(6-4, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/run_chuff")
				inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
			end),

            FrameEvent(18-4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),
			FrameEvent(20-4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),

            TimeEvent((19-4)*FRAMES, function(inst)
                local buffaction = inst:GetBufferedAction()
				if buffaction ~= inst.sg.statemem.buffaction then
					buffaction = nil
				end
                local target = buffaction ~= nil and buffaction.target or nil
    
                if target == nil or not target:IsValid() then
                    return -- Fail! No target.
                end

                local distance = math.sqrt(inst:GetDistanceSqToInst(target))

                if distance > .75 then
                    inst:ClearBufferedAction()
                else
                    inst:PerformBufferedAction()
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
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
            FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),

            FrameEvent(7, function(inst)
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
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/chuff")
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
		name = "bash_jump",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("bash_jump")
			if target == nil then
				inst.sg.statemem.buffaction = inst:GetBufferedAction()
				target = inst.sg.statemem.buffaction and inst.sg.statemem.buffaction.target or nil
			end
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target:GetPosition())
			end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.cancollide then
				local target = inst.sg.statemem.target
				if target then
					if not target:IsValid() then
						inst.sg.statemem.target = nil
					elseif inst:IsNear(target, 2 + target:GetPhysicsRadius(0)) and
						target.components.workable and
						target.components.workable:CanBeWorked()
					then
						local work_action = target.components.workable:GetWorkAction()
						if work_action == ACTIONS.MINE or work_action == ACTIONS.CHOP then
							if inst.sg.statemem.buffaction then
								if inst.sg.statemem.buffaction.action == ACTIONS.MINE then
									PlayMiningFX(inst, target)
								end
								inst:PerformBufferedAction()
							else
								if work_action == ACTIONS.MINE then
									PlayMiningFX(inst, target)
								end
								target.components.workable:WorkedBy(inst, 1)
							end
							inst.sg:GoToState("bash_collide")
						end
					end
				end
			end
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/run_chuff")
				inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
			end),
			FrameEvent(7, function(inst)
				inst.sg:AddStateTag("jumping")
				inst.Physics:SetMotorVelOverride(6, 0, 0)
			end),
			FrameEvent(9, function(inst)
				inst.sg.statemem.cancollide = true
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.cancollide = false
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.jumping = true
					inst.sg:GoToState("bash_miss")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.jumping then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			if inst.sg.statemem.buffaction and inst.sg.statemem.buffaction == inst.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
	},

	State{
		name = "bash_collide",
		tags = { "busy", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("bash_collide")

            local cost = TUNING.SKILLS.WALTER.WOBY_TASK_AID_HUNGER * (inst:HasEndurance() and TUNING.SKILLS.WALTER.WOBY_ENDURANCE_HUNGER_RATE_MOD or 1)

            if cost > 0 then
                inst.components.hunger:DoDelta(-cost) -- NOTES(DiogoW): This might change the state to transform!
            end
		end,

		timeline =
		{
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),
			FrameEvent(9, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),

			FrameEvent(2, function(inst) inst.Physics:SetMotorVelOverride(-2.4, 0, 0) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(-1.2, 0, 0) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVelOverride(-0.6, 0, 0) end),
			FrameEvent(10, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "bash_miss",
		tags = { "busy", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("bash_miss")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep") end),

			FrameEvent(0, function(inst) inst.Physics:SetMotorVelOverride(4, 0, 0) end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVelOverride(2, 0, 0) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVelOverride(1, 0, 0) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVelOverride(0.5, 0, 0) end),
			FrameEvent(4, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
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
				if inst.sg.lasttags["running"] then
					inst.AnimState:PlayAnimation("run_woby_pst")
					inst.sg.statemem.fromrunning = true
				else
					inst.AnimState:PlayAnimation("walk_woby_pst")
				end
            elseif inst.sg.lasttags["cower"] then
                inst.AnimState:PlayAnimation("cower_woby_pst")
            else
				inst.sg.statemem.sitting = true
				inst.sg:GoToState("actual_sitting")
            end
        end,

		timeline =
		{
			FrameEvent(1, function(inst)
				if inst.sg.statemem.fromrunning then
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
				end
			end),
			FrameEvent(3, function(inst)
				if inst.sg.statemem.fromrunning then
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
				end
			end),
		},

        events =
        {
			EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					if inst.sg.statemem.stopped then
						inst.sg:GoToState("idle")
					else
						inst.sg.statemem.sitting = true
						inst.sg:GoToState("actual_sitting")
					end
                end
            end),

            EventHandler("stop_sitting", function(inst)
                if inst:IsAsleep() then
                    inst.sg:GoToState("idle")
                else
					inst.sg.statemem.stopped = true
                    inst.AnimState:PlayAnimation("sit_woby_pst")
                end
            end),
        },
    },

	State{
		name = "actual_sitting",
		tags = { "busy", "canrotate", "sitting" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()
			inst.AnimState:PlayAnimation("sit_woby")
			inst.AnimState:PushAnimation("sit_woby_loop")
		end,

		timeline =
		{
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
			FrameEvent(18, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", { intensity = 0.8 }) end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", { intensity = 1 }) end),
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
				end
			end),
		},
	},

    State{
        name = "sitting_cower",
        tags = {"busy", "canrotate", "sitting", "cower"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            if inst.sg.lasttags["moving"] then
				if inst.sg.lasttags["running"] then
					inst.AnimState:PlayAnimation("run_woby_pst")
					inst.sg.statemem.fromrunning = true
				else
					inst.AnimState:PlayAnimation("walk_woby_pst")
				end
            elseif inst.sg.lasttags["sitting"] then
				inst.AnimState:PlayAnimation("sit_to_cower_woby")
				inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley")
				inst.sg.statemem.fromsitting = true
            else
				inst.sg.statemem.cowering = true
				inst.sg:GoToState("actual_sitting_cower_pre")
            end
        end,

		timeline =
		{
			FrameEvent(1, function(inst)
				if inst.sg.statemem.fromrunning then
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
				end
			end),
			FrameEvent(3, function(inst)
				if inst.sg.statemem.fromrunning then
					inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/footstep")
				end
			end),
		},

        events =
        {
			EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					if inst.sg.statemem.stopped then
						inst.sg:GoToState("idle")
					else
						inst.sg.statemem.cowering = true
						inst.sg:GoToState(inst.sg.statemem.fromsitting and "actual_sitting_cower_loop" or "actual_sitting_cower_pre")
					end
                end
            end),
            EventHandler("stop_sitting", function(inst)
				if inst:IsAsleep() or not inst.sg.statemem.fromsitting then
					inst.sg:GoToState("idle")
				else
					inst.sg.statemem.stopped = true
					inst.AnimState:PlayAnimation("cower_woby_pst")
				end
            end),
        },
    },

	State{
		name = "actual_sitting_cower_pre",
		tags = {"busy", "canrotate", "sitting", "cower"},

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()
			inst.AnimState:PlayAnimation("cower_woby_pre")
		end,

		timeline =
		{
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/foley") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.sg.statemem.stopped then
						inst.sg:GoToState("idle")
					else
						inst.sg.statemem.cowering = true
						inst.sg:GoToState("actual_sitting_cower_loop")
					end
				end
			end),
			EventHandler("stop_sitting", function(inst)
				if inst:IsAsleep() then
					inst.sg:GoToState("idle")
				else
					inst.sg.statemem.stopped = true
					inst.AnimState:PlayAnimation("cower_woby_pst")
				end
			end),
		},
	},

	State{
		name = "actual_sitting_cower_loop",
		tags = {"busy", "canrotate", "sitting", "cower"},

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()
			inst.AnimState:PlayAnimation("cower_woby_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/wimper")
		end,

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
					inst.AnimState:PlayAnimation("cower_woby_pst")
				end
			end),
		},
	},

	State{
		name = "rack_appear",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("woby_big_rack_appear")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("meta5/woby/big_dryingrack_deploy") end),
			FrameEvent(46, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},
	},
}

CommonStates.AddWalkStates(
    states,
    {
        walktimeline =
        {

            ---- SNIFF SOUNDS-----
            TimeEvent(4*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                   inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/sniff")-- Sniff walk sounds
                end
            end),

            TimeEvent(15*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                   inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/sniff")-- Sniff walk sounds
                end
            end),

            TimeEvent(31*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                   inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/sniff")-- Sniff walk sounds
                end
            end),

            TimeEvent(43*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                   inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/sniff")-- Sniff walk sounds
                end
            end),

            --FOOTSTEPS SOUNDS----

            TimeEvent(7*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .1})
                else
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .3}) -- Regular walk sounds
                end
            end),


            TimeEvent(30*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .1})
                else
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .3}) -- Regular walk sounds
                end
            end),

            TimeEvent(45*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .1})
                else
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .3}) -- Regular walk sounds
                end
            end),


            TimeEvent(60*FRAMES, function(inst)
                if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_loop") or
                   inst.AnimState:IsCurrentAnimation("sniff_woby_pst") then
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .1}) -- Sniff walk sounds
                else
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve/characters/walter/woby/big/footstep", {intensity= .3}) -- Regular walk sounds
                end
            end),


        }
    },
    {
        startwalk =  function(inst)
            if math.random() < 0.33 then
                return "sniff_woby_pre"
            end

            return "walk_woby_pre"
        end,

        walk = function(inst)
            if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") then
                return "sniff_woby_loop"
            end
            return "walk_woby_loop"
        end,

        stopwalk = function(inst)
            if inst.AnimState:IsCurrentAnimation("sniff_woby_pre") or
               inst.AnimState:IsCurrentAnimation("sniff_woby_loop") then
                return "sniff_woby_pst"
            end

            return "walk_woby_pst"
        end,
    })

CommonStates.AddFrozenStates(states)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)
CommonStates.AddHopStates(states, true, { pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"},
{
    hop_pre =
    {
        TimeEvent(46*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/sleep") end)
    },

    hop_loop =
    {
        TimeEvent(46*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/sleep") end)
    },

    hop_pst =
    {
        TimeEvent(46*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/sleep") end)
    },
})

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(46*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/big/sleep") end)
    },
})

return StateGraph("wobybig", states, events, "idle", actionhandlers)