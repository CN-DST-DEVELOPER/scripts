require("stategraphs/commonstates")

local actionhandlers =
{
	ActionHandler(ACTIONS.EAT, "eat"),
	ActionHandler(ACTIONS.PICKUP, "pickup"),
    ActionHandler(ACTIONS.MOLEPEEK, "pickup"),
}

local events =
{
    EventHandler("attacked", function(inst)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") then
            inst.sg:GoToState("hit")
        end
    end),
    EventHandler("death", function(inst)
        inst.sg:GoToState("death", inst.sg.statemem.dead)
    end),
    EventHandler("doattack", function(inst, data)
        if not inst.components.health:IsDead() and
                (inst.sg:HasStateTag("hit") or not inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack", data.target)
        end
    end),

    CommonHandlers.OnSleep(),
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnFreeze(),
}

local states =
{
    State {
        name = "idle",
        tags = { "idle", "canrotate" },
        onenter = function(inst, playanim)
			inst.components.locomotor:StopMoving()

            local next_anim = (math.random() > 0.2 and "idle1") or "idle2"
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation(next_anim, false)
            else
                inst.AnimState:PlayAnimation(next_anim, false)
            end
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "attack",
        tags = { "attack", "busy", "jumping" },

        onenter = function(inst, target)
            if target then
                inst.sg.statemem.target = target
                inst:ForceFacePoint(target:GetPosition())
            end

            inst.components.locomotor:StopMoving()
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("attack")
        end,

        timeline =
        {
            FrameEvent(5, function(inst)
                inst.SoundEmitter:PlaySound(inst.sounds.attack_munch)
            end),
            FrameEvent(17, function(inst)
                inst.SoundEmitter:PlaySound(inst.sounds.attack_hit)
            end),
            FrameEvent(18, function(inst)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState((math.random() < 0.333 and "taunt") or "idle")
            end),
        },
    },

    State {
        name = "taunt",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("taunt_loop")
            end),
        },
    },

    State {
        name = "taunt_loop",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt_loop")
            inst.sg.mem.taunt_loops = (inst.sg.mem.taunt_loops or (2 + math.random(2))) - 1

            inst.SoundEmitter:PlaySound(inst.sounds.taunt)
        end,

        timeline =
        {
           SoundFrameEvent(8, "rifts4/mimic/mimic_chest/taunt_step"),
           SoundFrameEvent(18, "rifts4/mimic/mimic_chest/taunt_step"),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.sg.mem.taunt_loops > 0 then
                    inst.sg:GoToState("taunt_loop")
                else
                    inst.sg.mem.taunt_loops = nil
                    inst.sg:GoToState("taunt_pst")
                end
            end),
        },
    },

    State {
        name = "taunt_pst",
        tags = { "busy" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt_pst")
            inst.SoundEmitter:PlaySound("rifts4/mimic/mimic_chest/taunt_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")

            inst.components.locomotor:StopMoving()
            RemovePhysicsColliders(inst)

            inst.SoundEmitter:PlaySound(inst.sounds.death)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
            inst.components.inventory:DropEverything(true)
        end,
    },

    State {
        name = "pickup",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("attack")
            inst.SoundEmitter:PlaySound(inst.sounds.pickup)

            local buffaction = inst:GetBufferedAction()
            local target = buffaction.target
            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end
        end,

        timeline =
        {
            FrameEvent(18, function(inst)
                inst.sg.statemem.performed = true
                inst:PerformBufferedAction()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.performed then
                inst:ClearBufferedAction()
            end
        end,
    },

    State {
        name = "spawn",
        tags = {"busy"},

        onenter = function(inst, isopen)
            inst.components.locomotor:StopMoving()

            inst.components.combat:StartAttack()

            inst.Transform:SetNoFaced()

            if isopen then
                inst.AnimState:PlayAnimation("spawn")
            else
                inst.sg.statemem.played_open = true
                inst.AnimState:PlayAnimation("open")
                inst.AnimState:PushAnimation("spawn", false)

                inst.SoundEmitter:PlaySound(inst.sounds.open)
            end
        end,

        timeline =
        {
            FrameEvent(0, function(inst)
                if not inst.sg.statemem.played_open then
                    inst.SoundEmitter:PlaySound(inst.sounds.spawn)
                end
            end),
            FrameEvent(4, function(inst)
                if inst.sg.statemem.played_open then
                    inst.SoundEmitter:PlaySound(inst.sounds.spawn)
                end
            end),
            FrameEvent(38, function(inst)
                if not inst.sg.statemem.played_open then
                    inst.SoundEmitter:PlaySound(inst.sounds.attack_hit)
                    inst.components.combat:DoAttack()
                end
            end),
            FrameEvent(42, function(inst)
                if inst.sg.statemem.played_open then
                    inst.SoundEmitter:PlaySound(inst.sounds.attack_hit)
                    inst.components.combat:DoAttack()
                end
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("taunt")
            end),
        },

        onexit = function(inst)
            inst.Transform:SetSixFaced()
        end,
    },

    State {
        name = "eat_loop",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            if not inst.sg.mem.chew_loops or inst.sg.mem.chew_loops == 0 then
                inst.SoundEmitter:PlaySound(inst.sounds.chew, "chew_loop")
                inst.sg.mem.chew_loops = math.random(4, 6)
            end

            inst.sg.mem.chew_loops = inst.sg.mem.chew_loops - 1

            inst.AnimState:PlayAnimation("eat_loop")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                local next_state
                if inst.sg.mem.chew_loops > 0 then
                    next_state = "eat_loop"
                    inst.sg.statemem.keep_sound = true
                else
                    next_state = "eat_pst"
                end

                inst.sg:GoToState(next_state)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.keep_sound then
                inst.SoundEmitter:KillSound("chew_loop")
            end
        end,
    },
}

CommonStates.AddWalkStates(states, {
    walktimeline =
    {
        SoundTimeEvent(0, "rifts4/mimic/mimic_chest/walk"),
        FrameEvent(10, function(inst)
            inst.components.locomotor:WalkForward()
        end),
        FrameEvent(28, function(inst)
            PlayFootstep(inst)
            inst.Physics:Stop()
        end),
    },
}, { walk = "walk" }, true)

CommonStates.AddSimpleState(states, "hit", "hit", {"busy", "hit"}, "idle")
CommonStates.AddSimpleActionState(states, "eat", "attack", nil, {"busy"}, "eat_loop", {
    FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.pickup) end),
    FrameEvent(18, function(inst) inst:PerformBufferedAction() end),
})
CommonStates.AddSimpleState(states, "eat_pst", "eat_pst", {"busy"}, nil, {
    FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.eat_pst) end),
    FrameEvent(4, function(inst) inst.sg:RemoveStateTag("busy") end),
})

CommonStates.AddFrozenStates(states)

return StateGraph("chest_mimic", states, events, "taunt", actionhandlers)
