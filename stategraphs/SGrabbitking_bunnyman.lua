require("stategraphs/commonstates")

local events = {
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(nil, TUNING.BUNNYMAN_MAX_STUN_LOCKS),
    CommonHandlers.OnDeath(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    EventHandler("burrowaway", function(inst) -- Delete entity presentation.
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then 
            inst.sg:GoToState("burrowaway")
        end
    end),
    EventHandler("burrowto", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg.mem.queued_burrowto_data = data
            if not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("burrowto", data)
            end
        end
    end),
    EventHandler("burrowarrive", function(inst, data)
        inst.sg:GoToState("burrowarrive", data)
    end),
}

local states =
{
    State{
        name = "burrowaway",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.persists = false
            inst.AnimState:PlayAnimation("despawn")
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/move", "move")
        end,
        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/emerge")
            end),
        },
        onexit = function(inst)
            inst.SoundEmitter:KillSound("move")
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
        },
    },
    State{
        name = "burrowto",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("despawn")
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/move", "move")
            inst.sg.statemem.data = data or inst.sg.mem.queued_burrowto_data
        end,
        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/emerge")
            end),
        },
        onexit = function(inst)
            inst.SoundEmitter:KillSound("move")
            if inst.sg.mem.forceteleporttask ~= nil then
                inst.sg.mem.forceteleporttask:Cancel()
                inst.sg.mem.forceteleporttask = nil
            end
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.Physics:Teleport(inst.sg.statemem.data.destination:Get())
                    inst.sg:GoToState("burrowarrive")
                end
            end),
        },
    },
    State{
        name = "burrowarrive",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.sg.mem.queued_burrowto_data = nil
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("spawn_pre")
            for i = 0, math.random(3) - 1 do -- Intentionally slower than sgrabbitking_bunnyman. [SGRKSM]
                inst.AnimState:PushAnimation("spawn_loop", false)
            end
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/move", "move")
        end,
        onexit = function(inst)
            if not inst.sg.statemem.donotquietsound then
                inst.SoundEmitter:KillSound("move")
            end
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.donotquietsound = true
                    inst.sg:GoToState("burrowarrive_pst")
                end
            end),
        },
    },
    State{
        name = "burrowarrive_pst",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("spawn_pst")
        end,
        timeline =
        {
            TimeEvent(34 * FRAMES, function(inst)
                inst.sg.statemem.donotquietsound = true
                inst.SoundEmitter:KillSound("move")
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/emerge")
            end),
        },
        onexit = function(inst)
            if not inst.sg.statemem.donotquietsound then
                inst.SoundEmitter:KillSound("move")
            end
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, playanim)
            inst.components.locomotor:StopMoving()
            if inst.sg.mem.queued_burrowto_data then
                inst.sg:GoToState("burrowto")
                return
            end

            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle_loop", false)
            elseif not inst.AnimState:IsCurrentAnimation("idle_loop") then
                inst.AnimState:PlayAnimation("idle_loop", false)
            end
        end,
        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/death")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.causeofdeath = data ~= nil and data.afflicter or nil
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/attack")
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/bite")
                inst.components.combat:DoAttack()
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("busy")
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
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hurt")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

CommonStates.AddWalkStates(states, {
    walktimeline =
    {
        TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hop") end),
        TimeEvent(4 * FRAMES, function(inst)
            inst.components.locomotor:WalkForward()
        end),
        TimeEvent(12 * FRAMES, function(inst)
            PlayFootstep(inst)
            inst.Physics:Stop()
        end),
    },
}, nil, true)

CommonStates.AddRunStates(states, {
    runtimeline =
    {
        TimeEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/hop") end),
        TimeEvent(4 * FRAMES, function(inst)
            inst.components.locomotor:RunForward()
        end),
        TimeEvent(8 * FRAMES, function(inst)
            PlayFootstep(inst)
            inst.Physics:Stop()
        end),
    },
}, nil, true)

CommonStates.AddSleepStates(states,
{
    sleeptimeline =
    {
        TimeEvent(35 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/sleep") end),
    },
})

CommonStates.AddFrozenStates(states)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)

return StateGraph("bunnyman", states, events, "idle")
