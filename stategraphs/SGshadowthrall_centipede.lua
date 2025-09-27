require("stategraphs/commonstates")

local actionhandlers = {
    ActionHandler(ACTIONS.EAT, "eat"),
}

local function Segment_ClearMovementTasks(body)
    if body.start_moving_task then
        body.start_moving_task:Cancel()
        body.start_moving_task = nil
    end

    if body.stop_moving_task then
        body.stop_moving_task:Cancel()
        body.stop_moving_task = nil
    end
end

local function Segment_WalkForward(body, should_run)
    if should_run then
        body.components.locomotor:RunForward(true)
        body.components.locomotor:SetShouldRun(true)
    else
        body.components.locomotor:WalkForward(true)
        body.components.locomotor:SetShouldRun(false)
    end
end

local LOCOMOTE_VARIANCE = 12 * FRAMES
local function Segment_WalkForward_Delay(body, should_run)
    Segment_ClearMovementTasks(body)
    body.start_moving_task = body:DoTaskInTime(math.random() * LOCOMOTE_VARIANCE, Segment_WalkForward, should_run)
end

local function Segment_Stop(body)
    body.components.locomotor:Stop()
end

local function Segment_Stop_Delay(body)
    Segment_ClearMovementTasks(body)
    body.stop_moving_task = body:DoTaskInTime(math.random() * LOCOMOTE_VARIANCE, Segment_Stop)
end

local events = {

    EventHandler("death", function(inst)
        local centipedebody = inst.controller and inst.controller.components.centipedebody
        local has_control = centipedebody and centipedebody:SegmentHasControl(inst)
        if not inst.sg:HasStateTag("dead") and has_control then
            inst.sg:GoToState("death")
        end
    end),

    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
            local centipedebody = inst.controller and inst.controller.components.centipedebody
            local has_control = centipedebody and centipedebody:SegmentHasControl(inst)

            local is_moving = inst.sg:HasStateTag("moving")
            local is_running = inst.sg:HasStateTag("running")
            local is_idling = inst.sg:HasStateTag("idle")

            local should_move = inst.components.locomotor:WantsToMoveForward()
            local should_run = inst.components.locomotor:WantsToRun()

            if is_moving and not should_move then
                inst.sg:GoToState(is_running and "run_stop" or "walk_stop")

                if has_control then
                    inst.controller.locomoting = false
                    centipedebody:ForEachSegmentControlled(Segment_Stop_Delay)
                end
            elseif (is_idling and should_move) or (is_moving and should_move and is_running ~= should_run) then
                inst.sg:GoToState(should_run and "run_start" or "walk_start")

                if has_control then
                    inst.controller.locomoting = true
                    centipedebody:ForEachSegmentControlled(Segment_WalkForward_Delay, should_run)
                end
            end
        end
    end),

    EventHandler("grow_segment", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("grow")
        end
    end),

    EventHandler("start_struggle", function(inst)
        if not inst.sg:HasStateTag("struggling") then
            inst.sg:GoToState("struggle_pre")
        end
    end),

    CommonHandlers.OnAttacked(),
    CommonHandlers.OnFallInVoid(),
}

local function PlayCentipedeFootstep(inst)
    inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/step")
end

local function PlayHeadSound(inst, sound, soundname)
    if inst:HasTag("centipede_head") then
        inst.SoundEmitter:PlaySound(sound, soundname)
    end
end

local function GoToIdle(inst)
    inst.sg:GoToState("idle")
end

local function GetDirectionAnim(inst, name)
    return (inst:IsBackwardsLocomoting() and "back_" or "front_")..name
end

local function GoToState(body, statename)
    body.sg:GoToState(statename)
end

local DELAY_VARIANCE = 10 * FRAMES
local function SyncSegment(body, state, randomdelay, excludeotherhead)
    if excludeotherhead and body:HasTag("centipede_head") then
        return
    end

    if randomdelay then
        body:DoTaskInTime(math.random() * DELAY_VARIANCE, GoToState, state)
    else
        body.sg:GoToState(state)
    end
end

local function SyncSegmentsToState(inst, randomdelay, excludeotherhead)
    local centipedebody = inst.controller and inst.controller.components.centipedebody
    if centipedebody and centipedebody:SegmentHasControl(inst) then
        centipedebody:ForEachSegmentControlled(SyncSegment, inst.sg.currentstate.name, randomdelay, excludeotherhead)
    end
end

--[[
TODO ANIMATIONS
eat_neutral
]]

local states = {

    State{
        name = "idle",
        tags = { "idle", "canrotate" },
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

            inst.AnimState:PlayAnimation("idle")

            local centipedebody = inst.controller and inst.controller.components.centipedebody
            if centipedebody and centipedebody.head_in_control ~= inst and centipedebody.head_in_control.sg:HasStateTag("moving") then
                Segment_WalkForward(inst)
            end

        end,

        events =
        {
            EventHandler("animover", GoToIdle),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/hit")
            inst.SoundEmitter:KillSound("centipede_idle")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        onexit = function(inst)
            if inst.PlayHeadIdleSound then
                inst:PlayHeadIdleSound()
            end
        end,

        events =
        {
            EventHandler("animover", GoToIdle),
        },
    },

    State{
        name = "eat",
        tags = { "busy" },

        onenter = function(inst)
            SyncSegmentsToState(inst, true)
            inst.components.locomotor:Stop()

            --if head and doesnt have control, use eat_neutral
            local use_neutral = inst:HasTag("centipede_head")
                and inst.controller 
                and not inst.controller.components.centipedebody:SegmentHasControl(inst)
            inst.AnimState:PlayAnimation(use_neutral and "eat_neutral" or "eat")

            if not use_neutral then
                PlayHeadSound(inst, "rifts6/creatures/centipede/eat_LP", "eat_loop")
            end
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("eat_loop")
        end,

        timeline =
        {
            FrameEvent(30, function(inst)
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animover", GoToIdle),
        },
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            SyncSegmentsToState(inst, true)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("death")
            inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/death")
            inst.SoundEmitter:KillSound("centipede_idle")

            --RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,
    },

    --Struggles

    State{
        name = "struggle_pre",
        tags = { "busy" , "struggling" },

        onenter = function(inst)
            SyncSegmentsToState(inst, true)

            local centipedebody = inst.controller and inst.controller.components.centipedebody
            if centipedebody and centipedebody:SegmentHasControl(inst) then
                inst.controller.components.health:SetInvincible(false)
                inst.controller.components.combat:SetRequiresToughCombat(false)
            end
            inst.components.health:SetInvincible(false)
            inst.components.combat:SetRequiresToughCombat(false)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("struggle_pre")
            inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/flip_hit_ground")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("struggle_loop")
            end)
        },
    },

    State{
        name = "struggle_loop",
        tags = { "busy" , "struggling" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("struggle_loop")
            for i = 1, 3 do
                inst.AnimState:PushAnimation("struggle_loop", false)
            end
        end,

        events = {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("struggle_pst")
            end)
        },
    },

    State{
        name = "struggle_pst",
        tags = { "busy" , "struggling" },

        onenter = function(inst)
            local centipedebody = inst.controller and inst.controller.components.centipedebody
            if centipedebody and centipedebody:SegmentHasControl(inst) then
                inst.controller.components.health:SetInvincible(true)
                inst.controller.components.combat:SetRequiresToughCombat(true)
            end
            inst.components.health:SetInvincible(true)
            inst.components.combat:SetRequiresToughCombat(true)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("struggle_pst")
            inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/struggle_pst")
        end,

        events = {
            EventHandler("animover", GoToIdle)
        },
    },

    State{
        name = "grow",
        tags = { "busy" , "nointerrupt", "forming" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("grow_new")
            inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/grow")
        end,

        events = {
            EventHandler("animover", GoToIdle)
        }
    }
}

CommonStates.AddVoidFallStates(states)
CommonStates.AddWalkStates(states, {
    walktimeline = {
        --ShakeAllCameras(CAMERASHAKE.SIDE, 0.2, .01, 1, inst, 40)
        --TheWorld:PushEvent("ms_miniquake", { rad = 30, num = 10, duration = 0.5, target = inst })
        FrameEvent(1, PlayCentipedeFootstep),
        FrameEvent(17, PlayCentipedeFootstep),
        FrameEvent(19, PlayCentipedeFootstep),
    }
},
{
    startwalk = function(inst)
        return GetDirectionAnim(inst, "walk_pre")
    end,

    walk = function(inst)
        return GetDirectionAnim(inst, "walk_loop")
    end,

    stopwalk = function(inst)
        return GetDirectionAnim(inst, "walk_pst")
    end,
})

CommonStates.AddRunStates(states, {
    runtimeline = {
        --ShakeAllCameras(CAMERASHAKE.SIDE, 0.2, .01, 1, inst, 40)
        --TheWorld:PushEvent("ms_miniquake", { rad = 30, num = 10, duration = 0.5, target = inst })
        FrameEvent(1, PlayCentipedeFootstep),
        FrameEvent(17, PlayCentipedeFootstep),
        FrameEvent(19, PlayCentipedeFootstep),
    }
},
{
    --TODO
    startrun = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(3)
        return GetDirectionAnim(inst, "walk_pre")
    end,

    run = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(3)
        return GetDirectionAnim(inst, "walk_loop")
    end,

    stoprun = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
        return GetDirectionAnim(inst, "walk_pst")
    end,
})

return StateGraph("shadowthrall_centipede", states, events, "idle", actionhandlers)