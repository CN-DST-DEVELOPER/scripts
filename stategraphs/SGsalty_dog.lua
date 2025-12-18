require("stategraphs/commonstates")
require("stategraphs/SGcritter_common")

local actionhandlers =
{
    ActionHandler(ACTIONS.GIVE, "give"),
    ActionHandler(ACTIONS.GIVEALLTOPLAYER, "give"),
    ActionHandler(ACTIONS.DROP, "give"),
    ActionHandler(ACTIONS.PICKUP, "pickup"),
    ActionHandler(ACTIONS.CHECKTRAP, "pickup"),
}

local events=
{
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
			end
		end
	end),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),
    CommonHandlers.OnLocomote(false, true),
    EventHandler("summon", function(inst)
        inst.sg:GoToState("summon")
    end),
    EventHandler("desummon", function(inst)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("desummon")
        end
    end),
    EventHandler("saltshake", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("saltshake")
        end
    end),
    EventHandler("despawn", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("despawn")
        end
    end),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,
    },

    State{
        name = "death",
        tags = {"busy"},
        onenter = function(inst, reanimating)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.SoundEmitter:PlaySound("winter2025/saltydog/death")
        end,
    },
    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
            inst.SoundEmitter:PlaySound("winter2025/saltydog/hit")
            inst.Physics:Stop()
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    State{
        name = "saltshake",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("emote_cute")
            inst.Physics:Stop()
        end,

        timeline = {
            FrameEvent(10, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/emote_cute_shake")
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.2 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(13, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/characters/walter/woby/small/emote_cute_shake")
            end),
            FrameEvent(15, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.5 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(19, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.8 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(22, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.6 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(25, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.5 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(30, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                if math.random() < 0.4 then
                    inst:ShedSalt()
                end
            end),
            FrameEvent(34, function(inst)
                inst.SoundEmitter:PlaySound("winter2025/saltydog/salt_shake")
                inst:ShedAllSalt()
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    State{
        name = "summon",
        tags = {"busy"},
        onenter = function(inst, queued)
            if queued and inst.hat then
                if inst.hat.components.spawner then
                    local x, y, z = inst.hat.components.spawner.overridespawnlocation(inst.hat)
                    inst.Transform:SetPosition(x, y, z)
                end
            end
            SpawnPrefab("wave_splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst:Hide()
            inst.Physics:Stop()
        end,
        timeline =
        {
            FrameEvent(3, function(inst)
                inst:Show()
                inst.Physics:SetMotorVel(5, 0, 0)
                inst.AnimState:PlayAnimation("jump_pre")
                inst.AnimState:PushAnimation("jump_pst")
                inst.SoundEmitter:PlaySound("winter2025/saltydog/vocalization")
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
            inst.readytogather = true
            inst.Physics:SetMotorVel(0, 0, 0)
            inst:Show()
        end,
    },
    State{
        name = "desummon",
        tags = {"busy"},
        onenter = function(inst)
            inst.readytogather = nil
            if inst.components.inventory ~= nil then
                inst.components.inventory:DropEverything()
            end
            inst.AnimState:PlayAnimation("jump_pre")
            inst.AnimState:PushAnimation("jump_pst")
            inst.SoundEmitter:PlaySound("winter2025/saltydog/vocalization")
            inst.Physics:SetMotorVel(5, 0, 0)
        end,
        timeline =
        {
            FrameEvent(6, function(inst)
                SpawnPrefab("wave_splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
                if inst.hat then
                    if inst.sg.statemem.queueresummon then -- NOTES(JBK): This will no longer hit from pollyspawndelay existing but keeping it here in case delay is lowered.
                        inst.sg:GoToState("summon", true)
                    else
                        inst.hat.components.spawner:GoHome(inst)
                        inst.sg:GoToState("idle")
                    end
                else
                    inst:Remove()
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
            inst.Physics:SetMotorVel(0, 0, 0)
            if not inst.hat then
                inst:Remove()
            end
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

                if distance > 1.75 then
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

            inst.AnimState:PlayAnimation("fetch_pst_fast")
        end,

        timeline =
        {
            FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/sheepington/bodyfall", nil, .25) end),
            FrameEvent(8,  function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/pant") end),
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
            FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("winter2025/saltydog/footstep") end),
            FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
            FrameEvent(27, function(inst) inst.SoundEmitter:PlaySound("winter2025/saltydog/footstep") end),
            FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/pupington/tail") end),
            FrameEvent(36, function(inst) inst.SoundEmitter:PlaySound("winter2025/saltydog/footstep") end),
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
            FrameEvent(8, function(inst) inst.SoundEmitter:PlaySound("winter2025/saltydog/footstep") end),

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
        name = "despawn",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst)
            inst.readytogather = nil
            inst.persists = false
            inst.OnEntitySleep = inst.Remove
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle_loop", true)
            inst.sg:SetTimeout(0.8)
        end,
        ontimeout = function(inst)
            inst:Remove()
        end,
        onexit = function(inst)
            inst:DoTaskInTime(0, inst.Remove)
        end,
    },
}
CommonStates.AddSleepStates(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

CommonStates.AddAmphibiousCreatureHopStates(states,
{ -- config
	swimming_clear_collision_frame = 3 * FRAMES,
},
{ -- anims
},
{ -- timeline
	hop_pre =
	{
		TimeEvent(0, function(inst)
			if inst:HasTag("swimming") then
				SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
			end
		end),
	},
	hop_pst = {
		FrameEvent(4, function(inst)
			if inst:HasTag("swimming") then
				inst.components.locomotor:Stop()
				SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
			end
		end),
		FrameEvent(6, function(inst)
			if not inst:HasTag("swimming") then
                inst.components.locomotor:StopMoving()
			end
		end),
	}
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

return StateGraph("salty_dog", states, events, "summon", actionhandlers)
