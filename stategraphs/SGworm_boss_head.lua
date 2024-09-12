require("stategraphs/commonstates")
local WORMBOSS_UTILS = require("prefabs/worm_boss_util")


local function IsDevouring(inst, target)
    return target ~= nil
        and target:IsValid()
        and target.sg ~= nil
        and target.sg:HasStateTag("devoured")
        and target.sg.statemem.attacker == inst
end

local function DoChew(inst, target, useimpactsound)
    if not useimpactsound then
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_med_dull")
    end
    if IsDevouring(inst.worm, target) then
        local dmg, spdmg = inst.components.combat:CalcDamage(target)
        local noimpactsound = target.components.combat.noimpactsound
        target.components.combat.noimpactsound = not useimpactsound
        target.components.combat:GetAttacked(inst, dmg, nil, nil, spdmg)
        target.components.combat.noimpactsound = noimpactsound
    end
end

local function ChewAll(inst)
    if inst.worm and inst.worm.devoured then
        for i,ent in ipairs(inst.worm.devoured)do
            DoChew(inst, ent, true)
        end
    end
end

local actionhandlers =
{

}

local events=
{

    EventHandler("death", function(inst, data) -- Pushed by worm_boss, not health component!
        if not inst.sg:HasStateTag("dead") then
            if not data.loop then
                inst.sg:GoToState("death")
            else
                inst.sg:GoToState("death_loop")
            end
        end
    end),

    EventHandler("death_ended", function(inst)
        inst.sg:GoToState("death_ended")
    end),


    EventHandler("deathunderground", function(inst)
        if not inst.sg:HasStateTag("dead") then
            inst.sg:GoToState("death_underground")
        end
    end),

    EventHandler("attacked", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit")
        end
    end),

    EventHandler("worm_boss_move", function(inst)
        if not inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("move") then
            inst.sg:GoToState("move")
        end
    end),

    EventHandler("taunt", function(inst)
        inst.sg:GoToState("taunt")
    end),
}

local states =
{


    State{

        name = "emerge_taunt",
        tags = {"idle", "canrotate", "busy"},
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("emerge_taunt")
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/taunt")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "emerge",
        tags = {"idle", "canrotate", "busy"},
        onenter = function(inst, data)
            inst.sg.statemem.hasfood = data.ate or data.hasfood
            inst.sg.statemem.isdead = data.dead

            if data.loading and inst.sg.statemem.isdead then
                inst.sg:GoToState("death_loop")

            elseif data.ate then
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/chomp")
                inst.AnimState:PlayAnimation("emerge_eat")

            elseif data.hasfood then
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/breach")
                inst.AnimState:PlayAnimation("emerge_full")

            else
                inst.AnimState:PlayAnimation("head_idle_pre")
            end
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.isdead then
                    inst.sg:GoToState("death")

                elseif inst.sg.statemem.hasfood then
                    inst.sg:GoToState("eat", { start = true })

                else
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "eat",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.sg.statemem.has_big_food = inst.worm and inst.worm.devoured and #inst.worm.devoured > 0

            if inst.sg.statemem.has_big_food then
                if data.start then
                    inst.sg.statemem.loops = 3
                else
                    inst.sg.statemem.loops = data.loops
                end
            end

            if inst.sg.statemem.has_big_food then
                inst.AnimState:PlayAnimation("chew_small", false)
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/chew")
            else
                inst.AnimState:PlayAnimation("chew_big", false)
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/chew_big")
            end
        end,

        onexit = function(inst)
            if not inst.sg.statemem.safeexit then
               WORMBOSS_UTILS.SpitAll(inst.worm,true)
            end
        end,

        timeline =
        {
            TimeEvent(12*FRAMES,  function(inst)
                local items = inst.worm.components.inventory:FindItems(function() return true end)
                if items and #items >  0 then
                    for i=#items, 1,-1 do
                        local ent = items[i]

                        if not ent:HasTag("irreplaceable") then
                            inst.worm.components.inventory:RemoveItem(ent,true)
                            ent:Remove()
                        end
                    end
                end
                WORMBOSS_UTILS.ChewAll(inst.worm)
            end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.loops then
                    inst.sg.statemem.loops = inst.sg.statemem.loops -1
                    if inst.sg.statemem.loops > 0 then
                        inst.sg.statemem.safeexit = true
                        inst.worm.chews = nil
                        inst.sg:GoToState("eat",{loops=inst.sg.statemem.loops})
                        return
                    end
                end

                inst.sg.statemem.safeexit = true
                if inst.sg.statemem.has_big_food and inst.worm.tail then
                    inst.worm.chews = nil
                    inst.sg:GoToState("swallow")
                elseif #inst.worm.components.inventory:FindItems(function() return true end) > 0 or inst.sg.statemem.has_big_food then
                    inst.worm.chews = nil
                    inst.sg:GoToState("spit")
                elseif inst.worm.chews and inst.worm.chews > 1 then
                    inst.worm.chews = inst.worm.chews -1
                    inst.sg:GoToState("eat")
                else
                    inst.worm.chews = nil
                    if math.random() > 0.5 then
                        inst.sg:GoToState("taunt")
                    else
                        inst.sg:GoToState("idle")
                    end
                end
            end),
        },
    },

    State{
        name = "spit",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("head_spit", false)

            inst.SoundEmitter:PlaySound("rifts4/worm_boss/spit_head")
        end,

        timeline =
        {
            TimeEvent(22*FRAMES, function(inst) WORMBOSS_UTILS.SpitAll(inst.worm,inst) end),
        },

        events=
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("taunt")
            end),
        },
    },

    State{
        name = "swallow",
        tags = {"busy"},
        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("swallow", false)

            inst.SoundEmitter:PlaySound("rifts4/worm_boss/swallow_other")
        end,

        timeline =
        {
            TimeEvent(13*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
            TimeEvent(16*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
            TimeEvent(18*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
            TimeEvent(20*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
        },

        onexit = function(inst)
            inst.worm:SetState(WORMBOSS_UTILS.STATE.IDLE)
            WORMBOSS_UTILS.Digest(inst.worm)
        end,

        events=
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "taunt",
        tags = {"canrotate", "busy"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/taunt")
        end,

        onexit = function(inst)
            inst.worm:SetState(WORMBOSS_UTILS.STATE.IDLE)
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("head_idle_loop")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "move",
        tags = {"move", "canrotate"},
        onenter = function(inst)
            inst.AnimState:PlayAnimation("head_idle_pst")
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst)
                inst.chunk.head = nil

                local advancetime = 0.3
                inst.worm:SetState(WORMBOSS_UTILS.STATE.MOVING)
                for i, chunk in ipairs(inst.worm.chunks)do
                    chunk.state = WORMBOSS_UTILS.CHUNK_STATE.MOVING
                end
                while advancetime > 0 do
                    local subdt = 1/30
                    WORMBOSS_UTILS.UpdateChunk(inst.worm, inst.chunk, subdt)
                    advancetime = advancetime - subdt
                end
                inst.worm.head = nil
                inst:Remove()
            end),
        },
    },

    State{

        name = "hit",
        tags = {"busy", "canrotate"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("hit")

            if not inst.hits then
                inst.hits = 0
            end
            inst.hits = inst.hits + 1

            inst:DoTaskInTime( 3, function()
                    if inst.hits then
                        inst.hits = inst.hits -1
                        if inst.hits <= 0 then
                            inst.hits = 0
                        end
                    end
                end)

            if inst.hits >= 3 then
                inst.sg:RemoveStateTag("busy")
            end

        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "death",
        tags = {"dead", "canrotate", "busy"},
        onenter = function(inst)
            if inst.worm and inst.worm.devoured then
                WORMBOSS_UTILS.SpitAll(inst.worm, nil, true)
            end
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/death_pst")
            inst.AnimState:PlayAnimation("death_pre")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("death_loop") end),
        },
    },

    State{

        name = "death_loop",
        tags = {"dead", "canrotate", "busy"},

        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("death_loop")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState(#inst.worm.chunks <= 1 and "death_ended" or "death_loop") end),
        },
    },

    State{

        name = "death_ended",
        tags = {"dead", "canrotate", "busy"},

        onenter = function(inst)
            inst.worm:PushEvent("death_ended")

            inst.sg.statemem.looping = inst.AnimState:IsCurrentAnimation("death_loop")

            if not inst.sg.statemem.looping then
                inst.AnimState:PlayAnimation("death_loop", false)
                inst.AnimState:PushAnimation("death_pst", false)
            else
                inst.AnimState:PlayAnimation("death_pst", false)
            end

        end,

        onupdate = function(inst,dt)
           if inst.AnimState:IsCurrentAnimation("death_pst") and not inst.sg.statemem.pst_death_sound_played then
                inst.sg.statemem.pst_death_sound_played = true
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/death_pst")
           end
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if inst.sg.statemem.looping then
                    inst:Remove()
                end
            end),

            EventHandler("animqueueover", function(inst)
                if not inst.sg.statemem.looping then
                    inst:Remove()
                end
            end),
        },
    },

    State{

        name = "death_underground",
        tags = {"dead", "canrotate", "busy"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("death_underground")
        end,

        events=
        {
            EventHandler("animover", function(inst) ErodeAway(inst, 6) end),
        },
    },

}

return StateGraph("worm_boss_head", states, events, "idle", actionhandlers)
