local function DoWortoxPortalTint(inst, val, tintalpha)
    local alpha = tintalpha and (1 - val) or 1
    if val > 0 then
        inst.components.colouradder:PushColour("portaltint", 154 / 255 * val, 23 / 255 * val, 19 / 255 * val, 0)
        val = 1 - val
        inst.AnimState:SetMultColour(val, val, val, alpha)
    else
        inst.components.colouradder:PopColour("portaltint")
        inst.AnimState:SetMultColour(1, 1, 1, alpha)
    end
end

local events = {
    EventHandler("death", function(inst)
        inst.sg:GoToState("death")
    end),
}

local DECOY_DANCE_ODDS = 0.25
local wortox_decoy_animations = {
    "emoteXL_loop_dance6", -- chicken
    "emoteXL_loop_dance8", -- robot
    "emoteXL_loop_dance7", -- step
    "emoteXL_loop_dance0", -- default
}

local states = {
    State{
        name = "idle",
        tags = { "idle" },
        onenter = function(inst, data)
            inst.sg.statemem.deathtime = data and data.deathtime or TUNING.SKILLS.WORTOX.SOULDECOY_DURATION
            if math.random() < DECOY_DANCE_ODDS then
                inst.AnimState:PlayAnimation(wortox_decoy_animations[math.random(#wortox_decoy_animations)], true)
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
        end,
        onupdate = function(inst)
            if GetTime() > inst.sg.statemem.deathtime then
                inst.decoyexpired = true
                inst.components.health:Kill()
            end
        end,
    },

    State{
        name = "death",
        tags = { "busy" },
        onenter = function(inst)
            inst:OnDeath()

            if inst.decoyexplodes then
                inst.sg:GoToState("startexplosion")
            else
                inst.sg:GoToState("startfizzle", inst.decoyexpired)
            end
        end,
    },

    State{
        name = "startexplosion",
        tags = { "busy" },
        onenter = function(inst)
            inst.Transform:SetNoFaced()
            inst.AnimState:PlayAnimation("emote_laugh")
        end,
        onupdate = function(inst)
            if inst.sg.statemem.tints ~= nil then
                DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints), inst.sg.statemem.tintalpha)
                if #inst.sg.statemem.tints <= 0 then
                    inst.sg.statemem.tints = nil
                end
            end
        end,
        timeline = {
            FrameEvent(18, function(inst)
                inst.sg.statemem.tints = { .9, .7, .4, 0 }
                inst.sg.statemem.tintalpha = nil
                local x, y, z = inst.Transform:GetWorldPosition()
                SpawnPrefab("wortox_decoy_explode_fx").Transform:SetPosition(x, y, z)
            end),
            FrameEvent(22, function(inst)
                inst.sg:GoToState("doexplosion")
            end),
        },
    },

    State{
        name = "doexplosion",
        tags = { "busy" },
        onenter = function(inst)
            inst:DoExplosion()
            inst:Remove()
        end,
    },

    State{
        name = "startfizzle",
        tags = { "busy" },
        onenter = function(inst, expired)
            inst.Transform:SetNoFaced()
            -- NOTES(JBK): The expired flag forces the decoy to always clap otherwise do a low chance for the death animation as a joke.
            inst.sg.statemem.expired = expired or math.random() > 0.05
            inst.AnimState:PlayAnimation(inst.sg.statemem.expired and "emote_slowclap" or "death2")
        end,
        onupdate = function(inst)
            if inst.sg.statemem.tints ~= nil then
                DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints), inst.sg.statemem.tintalpha)
                if #inst.sg.statemem.tints <= 0 then
                    inst.sg.statemem.tints = nil
                    inst.sg.statemem.tintalpha = nil
                end
            end
        end,
        timeline = {
            FrameEvent(18, function(inst)
                inst.sg.statemem.tints = { .9, .7, .4, 0 }
                inst.sg.statemem.tintalpha = true
                local x, y, z = inst.Transform:GetWorldPosition()
                SpawnPrefab(inst.sg.statemem.expired and "wortox_decoy_expire_fx" or "wortox_decoy_fizzle_fx").Transform:SetPosition(x, y, z)
            end),
            FrameEvent(22, function(inst)
                inst.sg:GoToState("dofizzle")
            end),
        },
    },

    State{
        name = "dofizzle",
        tags = { "busy" },
        onenter = function(inst)
            inst:DoFizzle()
            inst:Remove()
        end,
    },
}

return StateGraph("wortox_decoy", states, events, "idle")
