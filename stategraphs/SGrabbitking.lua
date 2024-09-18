require("stategraphs/commonstates")

local DROPKICK_MUSTHAVE_TAGS = { "_health", "_combat" }
local DROPKICK_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "playerghost", "shadowthrall", "shadow", "shadowcreature", "shadowchesspiece" }
local DROPKICK_ONEOF_TAGS = { "animal", "character", "monster", "shadowminion" }

local function DoKnockback(inst, target)
    if target:HasAnyTag("epic", "nopush") then
        return false
    end

    target:PushEvent("knockback", {
        knocker = inst,
        radius = inst:GetPhysicsRadius(0) + TUNING.RABBITKING_ABILITY_DROPKICK_KNOCKBACKRADIUS,
    })

    return true
end

local actionhandlers = {
    ActionHandler(ACTIONS.EAT, "eat"),
    ActionHandler(ACTIONS.GOHOME, "action"),
}

local events = {
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
    EventHandler("attacked", function(inst)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("ability") then
            inst.sg:GoToState("hit")
        end
    end),
    EventHandler("death", function(inst, data)
        inst.sg:GoToState("death", data)
    end),
    EventHandler("trapped", function(inst)
        inst.sg:GoToState("trapped")
    end),
    EventHandler("locomote", function(inst)
        if inst.sg:HasStateTag("busy") then
            return
        end

        if not inst.sg:HasStateTag("idle") and not inst.sg:HasStateTag("moving") then
            return
        elseif not inst.components.locomotor:WantsToMoveForward() then
            if not inst.sg:HasStateTag("idle") then
                inst.sg:GoToState("idle")
            end
        elseif inst.components.locomotor:WantsToRun() then
            if not inst.sg:HasStateTag("running") then
                inst.sg:GoToState("run")
            end
        else
            if not inst.sg:HasStateTag("hopping") then
                inst.sg:GoToState("hop")
            end
        end
    end),
    EventHandler("stunbomb", function(inst)
        inst.sg:GoToState("stunned")
    end),
    EventHandler("dotrade", function(inst)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("dotrade")
        end
    end),
    EventHandler("burrowaway", function(inst) -- Delete entity presentation.
        if inst.sg.currentstate.name ~= "burrowaway" then 
            inst.sg:GoToState("burrowaway")
        end
    end),
    EventHandler("burrowto", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("burrowto", data)
        end
    end),
    EventHandler("burrowarrive", function(inst, data)
        inst.sg:GoToState("burrowarrive", data)
    end),
    EventHandler("dropkickarrive", function(inst, data)
        inst.sg:GoToState("dropkickarrive", data)
    end),
    EventHandler("becameaggressive", function(inst, data)
        inst.sg:GoToState("becameaggressive", data)
    end),
    EventHandler("ability_summon", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("ability_summon", data)
        end
    end),
    EventHandler("ability_dropkick", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("ability_dropkick", data)
        end
    end),
}

local states = {
    State{
        name = "ability_summon",
        tags = {"busy", "ability"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("thump")
        end,
        timeline = {
            TimeEvent(18 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/thump")
            end),
            TimeEvent(23 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/thump")
            end),
            TimeEvent(30 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/thump")
            end),
            TimeEvent(37 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/thump")
            end),
        },
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:SummonMinions()
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
    State{
        name = "ability_dropkick",
        tags = {"busy", "moving", "running", "charge", "ability"},
        onenter = function(inst, target)
            if inst.components.leader:CountFollowers("rabbitking_manrabbit") == 0 then
                inst.components.timer:StartTimer("dropkick_cd", TUNING.RABBITKING_ABILITY_DROPKICK_CD_NOSUMMONS)
            else
                inst.components.timer:StartTimer("dropkick_cd", TUNING.RABBITKING_ABILITY_DROPKICK_CD)
            end
            inst.Physics:Stop()
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst:ForceFacePoint(target.Transform:GetWorldPosition())

            inst.Transform:SetSixFaced()
            inst.AnimState:PlayAnimation("dropkick_pre")
            inst.AnimState:PushAnimation("dropkick_loop", true)
        end,
        timeline = {
            TimeEvent(10 * FRAMES, function(inst)
                inst.components.locomotor:EnableGroundSpeedMultiplier(false)
                inst.Physics:SetMotorVelOverride(TUNING.RABBITKING_ABILITY_DROPKICK_SPEED, 0, 0)
                inst.sg:SetTimeout(TUNING.RABBITKING_ABILITY_DROPKICK_MAXAIRTIME)
                inst:AddTag("flying")
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/dropkick_lp", "dropkick_lp")
                inst.sg.statemem.canhitsomething = true
            end),
        },
        onupdate = function(inst, dt)
            if inst.sg.statemem.canhitsomething then
                local x, y, z = inst.Transform:GetWorldPosition()
                local hitradius = inst:GetPhysicsRadius(0) + TUNING.RABBITKING_ABILITY_DROPKICK_HITRADIUS
                local ents = TheSim:FindEntities(x, y, z, hitradius + MAX_PHYSICS_RADIUS, DROPKICK_MUSTHAVE_TAGS, DROPKICK_CANT_TAGS, DROPKICK_ONEOF_TAGS)
                for _, ent in ipairs(ents) do
                    if ent ~= inst and ent:IsValid() and (ent.components.follower == nil or ent.components.follower.leader ~= inst) and not (ent.components.health ~= nil and ent.components.health:IsDead()) then
                        local range = hitradius + ent:GetPhysicsRadius(0)
                        if ent:GetDistanceSqToPoint(x, y, z) < range * range and DoKnockback(inst, ent) then
                            inst.components.combat:DoAttack(ent)
                            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/dropkick_hit")
                            inst.sg.statemem.hitsomething = true
                            inst.sg:SetTimeout(0)
                        end
                    end
                end
            end
        end,
        onexit = function(inst)
            inst:RemoveTag("flying")
            inst.SoundEmitter:KillSound("dropkick_lp")
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Transform:SetFourFaced()
        end,
        ontimeout = function(inst)
            inst.sg:GoToState(inst.sg.statemem.hitsomething and "ability_dropkick_hit_pst" or "ability_dropkick_miss_pst")
        end,
    },
    State{
        name = "ability_dropkick_hit_pst",
        tags = {"busy", "moving", "running", "ability"},
        onenter = function(inst)
            inst.Transform:SetSixFaced()
            inst.AnimState:PlayAnimation("dropkick_hit")
            inst.AnimState:PushAnimation("dropkick_hit_pst", false)
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/dropkick_hit_pst")
        end,
        timeline = {
            TimeEvent(3 * FRAMES, function(inst)
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(false)
                inst.Physics:SetMotorVelOverride(-4, 0, 0)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            end),
        },
        onexit = function(inst)
            inst.Transform:SetFourFaced()
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
        name = "ability_dropkick_miss_pst",
        tags = {"busy", "ability"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(4, 0, 0)
            inst.Transform:SetSixFaced()
            inst.AnimState:PlayAnimation("dropkick_miss_pst")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/dropkick_miss_pst")
        end,
        timeline = {
            TimeEvent(6 * FRAMES, function(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            end),
        },
        onexit = function(inst)
            inst.Transform:SetFourFaced()
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("ability_dropkick_miss_stuck_loop")
                end
            end),
        },
    },
    State{
        name = "ability_dropkick_miss_stuck_loop",
        tags = {"busy", "ability"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("stuck_loop", true)
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/stuck_lp", "stuck_lp")
            inst.sg:SetTimeout(TUNING.RABBITKING_STUN_DURATION)
        end,
        onexit = function(inst)
            inst.SoundEmitter:KillSound("stuck_lp")
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("ability_dropkick_miss_stuck_pst")
        end,
    },
    State{
        name = "ability_dropkick_miss_stuck_pst",
        tags = {"busy", "ability"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("stuck_pst")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/dropkick_miss_pst")
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.components.timer:StopTimer("ability_cd")
                    inst.components.timer:StartTimer("ability_cd", TUNING.RABBITKING_ABILITY_CD_POSTSTUN)
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
    State{
        name = "burrowaway",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = false
                inst.components.inventoryitem.canbepickedupalive = false
            end
            inst.persists = false
            inst.AnimState:PlayAnimation("despawn")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/despawn")
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
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = false
                inst.components.inventoryitem.canbepickedupalive = false
            end
            inst.AnimState:PlayAnimation("despawn")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/despawn")
            inst.sg.statemem.data = data
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
            inst.Physics:Stop()
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = true
                inst.components.inventoryitem.canbepickedupalive = true
            end
            inst.AnimState:PlayAnimation("spawn_pre")
            for i = 1, math.random(3) - 1 do -- Intentionally faster than sgrabbitking_bunnyman. [SGRKSM]
                inst.AnimState:PushAnimation("spawn_loop", false)
            end
            inst.AnimState:PushAnimation("spawn_pst", false)

            if inst.rabbitking_kind == "aggressive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/spawn_lp", "spawn_lp")
            elseif inst.rabbitking_kind == "passive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/spawn_lp", "spawn_lp")
            end
        end,
        onexit = function(inst)
            inst.SoundEmitter:KillSound("spawn_lp")
            if inst.rabbitking_kind == "aggressive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/spawn_pst")
            elseif inst.rabbitking_kind == "passive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/spawn_pst")
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
        name = "dropkickarrive",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            if data and data.jumpfrom then
                inst:ForceFacePoint(data.jumpfrom.Transform:GetWorldPosition())
            else
                inst.Transform:SetRotation(math.random()*360)
            end
            inst.Transform:SetSixFaced()
            inst.AnimState:PlayAnimation("dropkick_hit")
            inst.AnimState:PushAnimation("dropkick_hit_pst", false)

            if inst.rabbitking_kind == "aggressive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/king_reveal_aggressive")
            elseif inst.rabbitking_kind == "passive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/king_reveal_passive")
            end
        end,
        timeline = {
            TimeEvent(3 * FRAMES, function(inst)
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(false)
                inst.Physics:SetMotorVelOverride(-8, 0, 0)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            end),
        },
        onexit = function(inst)
            inst.Transform:SetFourFaced()
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = true
                inst.components.inventoryitem.canbepickedupalive = true
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
        name = "becameaggressive",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            if inst.rabbitking_kind == "aggressive" then
                inst.AnimState:SetBuild("rabbitking_passive_build")
            end
            inst.AnimState:PlayAnimation("transition_pre")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/transition_pre")
        end,
        onexit = function(inst, data)
            if inst.rabbitking_kind == "aggressive" then
                inst.AnimState:SetBuild("rabbitking_aggressive_build")
            end
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("becameaggressive_pst")
                end
            end),
        },
    },
    State{
        name = "becameaggressive_pst",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("transition")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/transition_pst")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/king_reveal_aggressive")
            inst.components.colouradder:PushColour("aggressiveswitch", 1, 1, 1, 0)
        end,
        timeline = {
            TimeEvent(1*FRAMES, function(inst)
                inst.components.colouradder:PopColour("aggressiveswitch")
            end),
        },
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
    State{
        name = "dotrade",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("trade")
            inst.SoundEmitter:PlaySound("rifts4/rabbit_king/trade")
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
        name = "look",
        tags = {"idle", "canrotate" },
        onenter = function(inst)
            if math.random() > .5 then
                inst.AnimState:PlayAnimation("lookup_pre")
                inst.AnimState:PushAnimation("lookup_loop", true)
                inst.sg.statemem.lookingup = true
            else
                inst.AnimState:PlayAnimation("lookdown_pre")
                inst.AnimState:PushAnimation("lookdown_loop", true)
            end
            inst.sg:SetTimeout(1 + math.random())
        end,
        ontimeout = function(inst)
            inst.sg.statemem.donelooking = true
            inst.AnimState:PlayAnimation(inst.sg.statemem.lookingup and "lookup_pst" or "lookdown_pst")
        end,
        events = {
            EventHandler("animover", function (inst, data)
                if inst.sg.statemem.donelooking then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle", true)
            elseif not inst.AnimState:IsCurrentAnimation("idle") then
                inst.AnimState:PlayAnimation("idle", true)
            end
            inst.sg:SetTimeout(1 + math.random()*1)
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("look")
        end,
    },
    State{
        name = "action",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle")
            inst:PerformBufferedAction()
        end,
        events = {
            EventHandler("animover", function (inst, data)
                inst.sg:GoToState("idle")
            end),
        }
    },
    State{
        name = "eat",
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("rabbit_eat_pre", false)
            inst.AnimState:PushAnimation("rabbit_eat_loop", true)
            inst.sg:SetTimeout(2+math.random()*4)
        end,
        ontimeout = function(inst)
            inst:PerformBufferedAction()
            inst.sg:GoToState("idle", "rabbit_eat_pst")
        end,
    },
    State{
        name = "hop",
        tags = {"moving", "canrotate", "hopping"},
        timeline = {
            TimeEvent(5*FRAMES, function(inst)
                inst.Physics:Stop()
                inst.SoundEmitter:PlaySound("dontstarve/rabbit/hop")
            end),
        },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("walk")
            inst.components.locomotor:WalkForward()
            inst.sg:SetTimeout(2*math.random()+.5)
        end,
        onupdate = function(inst)
            if not inst.components.locomotor:WantsToMoveForward() then
                inst.sg:GoToState("idle")
            end
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("hop")
        end,
    },
    State{
        name = "run",
        tags = {"moving", "running", "canrotate"},
        onenter = function(inst)
            if inst.sounds and inst.sounds.run and not (inst.components.inventoryitem ~= nil and inst.components.inventoryitem:IsHeld()) then
                inst.SoundEmitter:PlaySound(inst.sounds.run)
            end
            inst.AnimState:PlayAnimation("run_pre")
            inst.components.locomotor:RunForward()
        end,
        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run_loop")
                end
            end),
        },
    },
    State{
        name = "run_loop",
        tags = { "moving", "running", "canrotate" },
        onenter = function(inst)
            if not inst.AnimState:IsCurrentAnimation("run") then
                inst.AnimState:PlayAnimation("run", true)
            end
            inst.components.locomotor:RunForward()
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("run_loop")
        end,
    },
    State{
        name = "death",
        tags = {"busy"},
        onenter = function(inst, data)
            if inst.sounds and inst.sounds.scream then
                inst.SoundEmitter:PlaySound(inst.sounds.scream)
            else
                if inst.rabbitking_kind == "aggressive" then
                    inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/death")
                elseif inst.rabbitking_kind == "passive" then
                    inst.SoundEmitter:PlaySound("rifts4/rabbit_king/death")
                end
            end
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.causeofdeath = data and data.afflicter or nil
            inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()), data and data.afflicter or nil)
        end,
    },
    State{
        name = "fall",
        tags = {"busy", "stunned"},
        onenter = function(inst)
            inst.Physics:SetDamping(0)
            inst.Physics:SetMotorVel(0,-20+math.random()*10,0)
            inst.AnimState:PlayAnimation("stunned_loop", true)
        end,
        onupdate = function(inst)
            local pt = Point(inst.Transform:GetWorldPosition())
            if pt.y < 2 then
                inst.Physics:SetMotorVel(0,0,0)
            end
            if pt.y <= .1 then
                pt.y = 0

                inst.Physics:Stop()
                inst.Physics:SetDamping(5)
                inst.Physics:Teleport(pt.x,pt.y,pt.z)
                inst.DynamicShadow:Enable(true)
                inst.sg:GoToState("stunned")
            end
        end,
        onexit = function(inst)
            local pt = inst:GetPosition()
            pt.y = 0
            inst.Transform:SetPosition(pt:Get())
        end,
    },
    State{
        name = "stunned",
        tags = {"busy", "stunned"},
        onenter = function(inst)
            inst.Physics:Stop()
            if inst.components.inventoryitem then
                inst.components.inventoryitem.canbepickedup = true
                inst.components.inventoryitem.canbepickedupalive = true
            end
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(TUNING.RABBITKING_STUN_DURATION)
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },
    State{
        name = "trapped",
        tags = {"busy", "trapped"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(1)
        end,
        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },
    State{
        name = "hit",
        tags = {"busy"},
        onenter = function(inst)
            if inst.sounds and inst.sounds.hurt then
                inst.SoundEmitter:PlaySound(inst.sounds.hurt)
            else
                if inst.rabbitking_kind == "aggressive" then
                    inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/hit")
                elseif inst.rabbitking_kind == "passive" then
                    inst.SoundEmitter:PlaySound("rifts4/rabbit_king/hit")
                end
            end
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}
CommonStates.AddSleepStates(states, nil, {
    onsleep = function(inst)
        if not inst.SoundEmitter:PlayingSound("sleep_lp") then
            if inst.rabbitking_kind == "aggressive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/aggressive/sleep_lp", "sleep_lp")
            elseif inst.rabbitking_kind == "passive" then
                inst.SoundEmitter:PlaySound("rifts4/rabbit_king/sleep_lp", "sleep_lp")
            end
        end
    end,
    onwake = function(inst)
        if inst.SoundEmitter:PlayingSound("sleep_lp") then
            inst.SoundEmitter:KillSound("sleep_lp")
        end
    end,
})
CommonStates.AddFrozenStates(states)
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)


return StateGraph("rabbitking", states, events, "idle", actionhandlers)
