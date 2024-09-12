require("stategraphs/commonstates")

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "action"),
}

----------------------------------------------------------------------------------------------------------------------

local events =
{
    EventHandler("attacked", function(inst, data)
        if not (inst.sg:HasAnyStateTag("attack", "hit", "noattack") or inst.components.health:IsDead()) then
            inst.sg:GoToState(math.random() <= TUNING.RUINSNIGHTMARE_HORNATTACK_CHANCE and "horn_attack" or "hit", data.attacker)
        end
    end),

    EventHandler("doattack", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("attack", data.target)
        end
    end),

    EventHandler("reappear", function(inst)
        if inst.sg:HasStateTag("invisible") and not inst.components.health:IsDead() then
            inst:Show()
            inst.sg:GoToState("appear")
        end
    end),

    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnDeath(),
}

----------------------------------------------------------------------------------------------------------------------

local function OnAttackReflected(inst)
    inst.sg.statemem.attackreflected = true
end

local function FinishExtendedSound(inst, soundid)
    inst.SoundEmitter:KillSound("sound_"..tostring(soundid))
    inst.sg.mem.soundcache[soundid] = nil

    if inst.sg.statemem.readytoremove and next(inst.sg.mem.soundcache) == nil then
        inst:Remove()
    end
end

local function PlayExtendedSound(inst, soundname)
    if inst.sg.mem.soundcache == nil then
        inst.sg.mem.soundcache = {}
        inst.sg.mem.soundid = 0
    else
        inst.sg.mem.soundid = inst.sg.mem.soundid + 1
    end

    inst.sg.mem.soundcache[inst.sg.mem.soundid] = true

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/"..soundname, "sound_"..tostring(inst.sg.mem.soundid))

    inst:DoTaskInTime(5, FinishExtendedSound, inst.sg.mem.soundid)
end

local function OnAnimOverRemoveAfterSounds(inst)
    if inst.sg.mem.soundcache == nil or next(inst.sg.mem.soundcache) == nil then
        inst:Remove()
    else
        inst:Hide()
        inst.sg.statemem.readytoremove = true
    end
end

local function TryDropTarget(inst)
    -- Nightmarecreatures don't drop target naturally.
    if inst.ShouldKeepTarget == nil then
        return
    end

    local target = inst.components.combat.target

    if target ~= nil and not inst:ShouldKeepTarget(target) then
        inst.components.combat:DropTarget()

        return true
    end
end

local function TryDespawn(inst)
    if inst.sg.mem.forcedespawn or (inst.wantstodespawn and not inst.components.combat:HasTarget()) then
        inst.sg:GoToState("disappear")

        return true
    end
end

local function TryReappearingTeleport(inst)
    local x0, y0, z0 = inst.Transform:GetWorldPosition()

    for k = 1, 12 do
        local mult = math.random() > .5 and -1 or 1

        local x = x0 + (10 - k + math.random() * 5) * mult
        local z = z0 + (10 - k + math.random() * 5) * mult

        if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
            inst.Physics:Teleport(x, 0, z)

            return
        end
    end
end

----------------------------------------------------------------------------------------------------------------------

local function SpawnDoubleHornAttack(inst, target)
    local left = SpawnPrefab("ruinsnightmare_horn_attack")
    local right = SpawnPrefab("ruinsnightmare_horn_attack")

    left:SetUp(inst, target)
    right:SetUp(inst, target, left)
end

----------------------------------------------------------------------------------------------------------------------

local idle_on_animover_handler =
{
    EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
}

local remove_after_sounds_on_animover_handler =
{
    EventHandler("animover", OnAnimOverRemoveAfterSounds),
}

----------------------------------------------------------------------------------------------------------------------

local function SetEightFaced(inst)
    inst.Transform:SetEightFaced()
end

local function SetFourFaced(inst)
    inst.Transform:SetFourFaced()
end

----------------------------------------------------------------------------------------------------------------------

local function WasMovingFrameEventWrap(time, fn)
    return FrameEvent(time+4, function(inst) if inst.sg.statemem.was_moving then fn(inst) end end)
end

local function WasMovingAndDashFrameEventWrap(time, fn)
    return FrameEvent(time+4, function(inst) if inst.sg.statemem.was_moving and inst.sg.statemem.dash then fn(inst) end end)
end

local function WasNotMovingFrameEventWrap(time, fn)
    return FrameEvent(time, function(inst) if not inst.sg.statemem.was_moving then fn(inst) end end)
end

local function WasNotMovingAndDashFrameEventWrap(time, fn)
    return FrameEvent(time, function(inst) if not inst.sg.statemem.was_moving and inst.sg.statemem.dash then fn(inst) end end)
end

----------------------------------------------------------------------------------------------------------------------

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            local dropped = TryDropTarget(inst)

            if TryDespawn(inst) then
                return

            elseif dropped then
                inst.sg:GoToState("taunt")

                return
            end

            inst.components.locomotor:StopMoving()

            if not inst.AnimState:IsCurrentAnimation("idle_loop") then
                inst.AnimState:PlayAnimation("idle_loop", true)
            end

            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            inst.sg.statemem.was_moving = inst.sg.lasttags["moving"] ~= nil
            inst.sg.statemem.target = target

            inst.Physics:Stop()
            inst.components.combat:StartAttack()

            inst.AnimState:PlayAnimation(inst.sg.statemem.was_moving and "atk_walk_pre" or "atk_pre")
            inst.AnimState:PushAnimation("atk", false)

            PlayExtendedSound(inst, "attack_grunt")

            inst.sg.statemem.dash = inst.components.planarentity ~= nil
        end,

        timeline =
        {
            -- Creature is not moving, time it to atk_pre.
            WasNotMovingFrameEventWrap(14, function(inst) PlayExtendedSound(inst, "attack") end),
            WasNotMovingFrameEventWrap(16, function(inst)
                -- The stategraph event handler is delayed, so it won't be
                -- accurate for detecting attacks due to damage reflection.
                inst:ListenForEvent("attacked", OnAttackReflected)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
                inst:RemoveEventCallback("attacked", OnAttackReflected)
            end),
            FrameEvent(17, function(inst)
                if inst.sg.statemem.attackreflected and not inst.components.health:IsDead() then
                    inst.sg:GoToState("hit")
                end
            end),

            WasNotMovingAndDashFrameEventWrap(9 , function(inst) inst.Physics:SetMotorVelOverride(10, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(10, function(inst) inst.Physics:SetMotorVelOverride(20, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(17, function(inst) inst.Physics:SetMotorVelOverride(10, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(18, function(inst) inst.Physics:SetMotorVelOverride( 5, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(19, function(inst) inst.Physics:SetMotorVelOverride(2.5, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(20, function(inst) inst.Physics:SetMotorVelOverride(1.25, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(21, function(inst) inst.Physics:SetMotorVelOverride(0.67, 0, 0) end),
            WasNotMovingAndDashFrameEventWrap(22, function(inst) inst.Physics:ClearMotorVelOverride() inst.Physics:Stop() end),

            -- Creature is moving, time it to atk_walk_pre (4 frames longer).
            WasMovingFrameEventWrap(14, function(inst) PlayExtendedSound(inst, "attack") end),
            WasMovingFrameEventWrap(16, function(inst)
                -- The stategraph event handler is delayed, so it won't be
                -- accurate for detecting attacks due to damage reflection.
                inst:ListenForEvent("attacked", OnAttackReflected)
                inst.components.combat:DoAttack(inst.sg.statemem.target)
                inst:RemoveEventCallback("attacked", OnAttackReflected)
            end),
            WasMovingFrameEventWrap(17, function(inst)
                if inst.sg.statemem.attackreflected and not inst.components.health:IsDead() then
                    inst.sg:GoToState("hit")
                end
            end),

            WasMovingAndDashFrameEventWrap(9 , function(inst) inst.Physics:SetMotorVelOverride(10, 0, 0) end),
            WasMovingAndDashFrameEventWrap(10, function(inst) inst.Physics:SetMotorVelOverride(20, 0, 0) end),
            WasMovingAndDashFrameEventWrap(17, function(inst) inst.Physics:SetMotorVelOverride(10, 0, 0) end),
            WasMovingAndDashFrameEventWrap(18, function(inst) inst.Physics:SetMotorVelOverride( 5, 0, 0) end),
            WasMovingAndDashFrameEventWrap(19, function(inst) inst.Physics:SetMotorVelOverride(2.5, 0, 0) end),
            WasMovingAndDashFrameEventWrap(20, function(inst) inst.Physics:SetMotorVelOverride(1.25, 0, 0) end),
            WasMovingAndDashFrameEventWrap(21, function(inst) inst.Physics:SetMotorVelOverride(0.67, 0, 0) end),
            WasMovingAndDashFrameEventWrap(22, function(inst) inst.Physics:ClearMotorVelOverride() inst.Physics:Stop() end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if math.random() < .333 then
                    TryDropTarget(inst)
                    inst.forceretarget = true --V2C: try to keep legacy behaviour; it used SetTarget(nil) here, which would always result in a retarget
                    inst.sg:GoToState("taunt")
                else
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("disappear")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                TryReappearingTeleport(inst)

                inst.sg:GoToState("appear")
            end),
        },
    },

    State{
        name = "horn_attack",
        tags = { "busy", "hit" },

        onenter = function(inst, target)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("disappear")

            inst.sg.statemem.target = target
        end,

        events =
        {
            EventHandler("animover", function(inst)
                TryReappearingTeleport(inst)

                if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() and not inst.components.health:IsDead() then
                    SpawnDoubleHornAttack(inst, inst.sg.statemem.target)
                end

                inst:Hide()
                inst.sg:AddStateTag("invisible")
            end),
        },
    },

    State{
        name = "taunt",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt")

            PlayExtendedSound(inst, "taunt")
        end,

        events = idle_on_animover_handler,
    },

    State{
        name = "appear",
        tags = { "busy" },

        onenter = function(inst)
            TryDropTarget(inst)

            inst.AnimState:PlayAnimation("appear")
            inst.Physics:Stop()

            PlayExtendedSound(inst, "appear")
        end,

        events = idle_on_animover_handler,
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot()

            inst.AnimState:PlayAnimation("disappear")
            inst.Physics:Stop()

            PlayExtendedSound(inst, "die")

            inst:AddTag("NOCLICK")
            inst.persists = false
        end,

        events = remove_after_sounds_on_animover_handler,

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
        end
    },

    State{
        name = "disappear",
        tags = { "busy", "noattack" },

        onenter = function(inst)
            PlayExtendedSound(inst, "death")
            inst.AnimState:PlayAnimation("disappear")
            inst.Physics:Stop()
            inst:AddTag("NOCLICK")
            inst.persists = false
        end,

        events = remove_after_sounds_on_animover_handler,

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
        end,
    },

    State{
        name = "action",

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst:PerformBufferedAction()
        end,

        events = idle_on_animover_handler,
    },
}

CommonStates.AddWalkStates(
    states,
    {
        walktimeline =
        {
            FrameEvent(0, function(inst)
                local dropped = TryDropTarget(inst)

                if TryDespawn(inst) then
                    return

                elseif dropped then
                    inst.sg:GoToState("taunt")
                end
            end),
        },
    },
    nil, -- anims
    nil, -- softstop
    nil, -- delaystart
    {
        startonenter = SetEightFaced,
        startonexit  = SetFourFaced,
        walkonenter  = SetEightFaced,
        walkonexit   = SetFourFaced,
        endonenter   = SetEightFaced,
        endonexit    = SetFourFaced,
    }
)

return StateGraph("shadowcreature", states, events, "appear", actionhandlers)
