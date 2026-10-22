require("stategraphs/commonstates")
local WORMBOSS_UTILS = require("prefabs/worm_boss_util")

local function TryInitStunned(inst)
	if inst.sg.mem.stun_t0 == nil then
		inst.sg.mem.stun_t0 = GetTime()
	end
end

local function TryClearStunned(inst)
	if not inst.sg.statemem.stunned then
		inst.sg.mem.stun_t0 = nil
	end
end

local function IsShadow(inst)
	return inst:HasTag("shadowthrall")
end

local function PlayWormSound(inst, sound)
    if IsShadow(inst) then
        inst.sg.mem.soundparams = inst.sg.mem.soundparams or { type = 0.95 }
		inst.SoundEmitter:PlaySoundWithParams(sound, inst.sg.mem.soundparams)
    else
        inst.SoundEmitter:PlaySound(sound)
    end
end

local function GetStaggerTime(inst)
    return (IsShadow(inst) and inst.worm and inst.worm.enraged) and TUNING.WORM_BOSS_SHADOW_ENRAGED_STAGGER_TIME
        or TUNING.WORM_BOSS_STAGGER_TIME
end

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
        if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt") then
            if inst.sg:HasStateTag("stunned") then
				inst.sg.statemem.stunned = true
				inst.sg:GoToState("stun_hit")
            else
                inst.sg:GoToState("hit")
            end
        end
    end),

	EventHandler("sync_electrocute", function(inst, data)
		if not inst.sg:HasStateTag("busy") or (inst.sg:HasAnyStateTag("hit", "canelectrocute") and not inst.sg:HasStateTag("electrocute")) then
			inst.sg:GoToState("sync_electrocute", data)
		end
	end),

    EventHandler("worm_boss_move", function(inst)
		if not inst.sg:HasAnyStateTag("busy", "move") then
            inst.sg:GoToState("move")
        end
    end),

    EventHandler("taunt", function(inst)
		inst.sg:GoToState("taunt")
    end),

	CommonHandlers.OnStalkerCorrupt(),
}

local states =
{
    State{

        name = "emerge_taunt",
		tags = { "idle", "canrotate", "busy", "canelectrocute" },
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("emerge_taunt")
            PlayWormSound(inst, "rifts4/worm_boss/taunt")
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
                inst.sg.statemem.safeexit = true
                inst.sg:GoToState("death_loop")
            elseif data.ate then
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/chomp")
                inst.AnimState:PlayAnimation("emerge_eat")

            elseif data.hasfood then
                inst.SoundEmitter:PlaySound("rifts4/worm_boss/breach")
                inst.AnimState:PlayAnimation("emerge_full")
				inst.sg.statemem.full = true

            else
                inst.AnimState:PlayAnimation("head_idle_pre")
            end
        end,

		timeline =
		{
			FrameEvent(8, function(inst)
				--head_idle_pre
				if not (inst.sg.statemem.hasfood or inst.sg.statemem.isdead) then
					inst.sg:AddStateTag("canelectrocute")
				end
			end),
			FrameEvent(12, function(inst)
				--emerge_full
				if inst.sg.statemem.hasfood and inst.sg.statemem.full then
					inst.sg.statemem.canelectrocute = true
				end
			end),
			FrameEvent(28, function(inst)
				--emerge_eat
				if inst.sg.statemem.hasfood and not inst.sg.statemem.full then
					inst.sg.statemem.canelectrocute = true
				end
			end),
		},

        events=
        {
			EventHandler("sync_electrocute", function(inst, data)
				if inst.sg.statemem.canelectrocute then
					inst.sg.statemem.canelectrocute = false
					inst.AnimState:PlayAnimation("chew_shock_loop", true)
					local duration = CalcEntityElectrocuteDuration(inst, data and data.duration)
					inst.sg.statemem.electrocute_task = inst:DoTaskInTime(duration, function(inst)
						inst.sg.statemem.electrocute_task = nil
						inst.AnimState:PlayAnimation("chew_shock_pst")
					end)
					return true
				end
				return not inst.sg:HasStateTag("canelectrocute")
			end),
			EventHandler("animqueueover", function(inst)
                inst.sg.statemem.safeexit = true
                if inst.sg.statemem.isdead then
                    inst.sg:GoToState("death")

                elseif inst.sg.statemem.hasfood then
                    inst.sg:GoToState("eat", { start = true })

                else
                    inst.sg:GoToState("idle")
                end
            end),
        },

		onexit = function(inst)
            if not inst.sg.statemem.safeexit then
                WORMBOSS_UTILS.SpitAll(inst.worm,true)
            end
			if inst.sg.statemem.electrocute_task then
				inst.sg.statemem.electrocute_task:Cancel()
			end
		end,
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
            if inst.sg.statemem.electrocute_task then
				inst.sg.statemem.electrocute_task:Cancel()
			end
        end,

        timeline =
        {
            TimeEvent(12*FRAMES,  function(inst)
                local explodetarget = inst.chunk and (inst.chunk.dirt_start or inst.chunk.dirt_end) or nil
                local stunned = false
                local exploded = false
                WORMBOSS_UTILS.EnableWeakToExplosive(inst.worm, true)
                -- explosion first, so we can spit out all items if stunned
                inst.worm.components.inventory:ForEachItem(function(item)
                    if item.components.explosive and item.components.burnable and item.components.burnable:IsBurning() then
                        item.components.explosive:OnBurnt(explodetarget)
                        exploded = true
                        stunned = true
                    elseif item.ExplodeOnChew then -- special case for brightshade bomb, because it doesn't have explosive component always
                        item:ExplodeOnChew(explodetarget)
                        exploded = true
                        stunned = true
                    elseif not IsShadow(inst) and
                        (item.prefab == "mandrake" -- special case of substitute stun state for sleep
                        or item.prefab == "cookedmandrake"
                        or item.prefab == "shroombait") then
                        if item.components.stackable then
                            item.components.stackable:Get():Remove()
                        else
                            item:Remove()
                        end
                        stunned = true
                    end
                end)
                WORMBOSS_UTILS.EnableWeakToExplosive(inst.worm, false)

                if exploded then
                    WORMBOSS_UTILS.SpawnExplosiveFX(inst.worm)
                end

                if stunned then
                    inst.sg:GoToState("stun_pre")
                else
                    inst.worm.components.inventory:ForEachItem(function(item)
                        if not item:HasTag("irreplaceable") then
                            inst.worm.components.inventory:RemoveItem(item, true)
                            item:Remove()
                        end
                    end)
                    WORMBOSS_UTILS.ChewAll(inst.worm)
                end
            end),
        },

        events=
        {
			EventHandler("sync_electrocute", function(inst, data)
				if not inst.sg.statemem.noelectrocute then
					inst.sg.statemem.noelectrocute = true
					inst.AnimState:PlayAnimation("chew_shock_loop", true)
					local duration = CalcEntityElectrocuteDuration(inst, data and data.duration)
					inst.sg.statemem.electrocute_task = inst:DoTaskInTime(duration, function(inst)
						inst.sg.statemem.electrocute_task = nil
						inst.AnimState:PlayAnimation("chew_shock_pst")
					end)
				end
				return true
			end),
            EventHandler("animqueueover", function(inst)
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
			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("canelectrocute")
				WORMBOSS_UTILS.SpitAll(inst.worm,inst)
			end),
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
            WORMBOSS_UTILS.SetWormDigestionSound(inst.worm)
            inst.AnimState:PlayAnimation("swallow", false)
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/swallow_other")
        end,

        timeline =
        {
            TimeEvent(13*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
            TimeEvent(16*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
            TimeEvent(18*FRAMES, function(inst) WORMBOSS_UTILS.ChewAll(inst.worm) end),
			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("canelectrocute")
				WORMBOSS_UTILS.ChewAll(inst.worm)
			end),
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
		tags = { "canrotate", "busy", "canelectrocute" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("taunt")
            PlayWormSound(inst, "rifts4/worm_boss/taunt")
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
		tags = { "move", "canrotate", "noelectrocute" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("head_idle_pst")
        end,

        timeline =
        {
            TimeEvent(7*FRAMES, function(inst)
                inst.chunk.head = nil
                if inst.chunk.dirt_start and inst.chunk.dirt_start:IsValid() then
                    inst.chunk.dirt_start:RemoveTag("nightmarecorruptable")
                    inst.chunk.dirt_start.CanStalkerCorrupt = nil
                    inst.chunk.dirt_start.RedirectStalkerCorruption = nil
                end

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
		tags = { "busy", "hit", "canrotate" },
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("hit")

			inst.hits = (inst.hits or 0) + 1
			inst:DoTaskInTime(3, function()
				inst.hits = math.max(0, inst.hits - 1)
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
		name = "sync_electrocute",
		tags = { "electrocute", "hit", "busy", "noelectrocute" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("shock_loop", true)
			inst.sg:SetTimeout(CalcEntityElectrocuteDuration(inst, data and data.duration))

			inst.hits = (inst.hits or 0) + 1
			inst:DoTaskInTime(3, function()
				inst.hits = math.max(0, inst.hits - 1)
			end)
		end,

		ontimeout = function(inst)
			inst.AnimState:PlayAnimation("shock_pst")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

    State{

        name = "death",
        tags = {"dead", "canrotate", "busy"},
        onenter = function(inst)
            if inst.worm and inst.worm.devoured then
                WORMBOSS_UTILS.SpitAll(inst.worm, nil, true)
            end
            PlayWormSound(inst, "rifts4/worm_boss/death_pre")
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
            PlayWormSound(inst, "rifts4/worm_boss/death")
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
                PlayWormSound(inst, "rifts4/worm_boss/death")
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

	State{
		name = "stun_pre",
		tags = { "stunned", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("stun_pre")
			TryInitStunned(inst)
		end,

		timeline =
		{
			--#SFX
			-- FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_pre") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_idle")
				end
			end),
		},

		onexit = function(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_idle",
		tags = { "stunned", "busy", "caninterrupt" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("stun_loop") then
				inst.AnimState:PlayAnimation("stun_loop", true)
			end
			TryInitStunned(inst)
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			--#SFX
			-- FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_idle") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.stunned = true
			inst.sg:GoToState(
				GetTime() - inst.sg.mem.stun_t0 < GetStaggerTime(inst) - 1 and
				"stun_idle" or
				"stun_pst")
		end,

		onexit = function(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "hit", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("stun_hit")
			TryInitStunned(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				-- PlayLobSound(inst, "dontstarve/creatures/rocklobster/hurt")
				-- PlayLobFoley(inst)
			end),

			FrameEvent(6, function(inst)
				if GetTime() - inst.sg.mem.stun_t0 < GetStaggerTime(inst) then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState(
						GetTime() - inst.sg.mem.stun_t0 < GetStaggerTime(inst) - 1 and
						"stun_idle" or
						"stun_pst")
				end
			end),
		},

		onexit = function(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_pst",
		tags = { "stunned", "busy", "canrotate" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("stun_pst")
			TryInitStunned(inst)
			if GetTime() - inst.sg.mem.stun_t0 < GetStaggerTime(inst) then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			--#SFX
			-- FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_pst") end),

			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("stunned")
				inst.sg:AddStateTag("caninterrupt")
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
			TryClearStunned(inst)
		end,
	},

    -- stalker corrupted
    -- For searching: CommonStates.AddStalkerCorruptionStates

    State{
		name = "stalker_corruption_stun",
		tags = { "busy", "nointerrupt", "noattack", "temp_invincible", "stalkercorruptingstun", },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("stun_pre", false)
			inst.AnimState:PushAnimation("stun_loop", true)
            inst.worm.components.health:SetInvincible(true)
		end,

		events =
		{
            EventHandler("interruptcorruption", function(inst)
                inst.AnimState:PlayAnimation("stun_pst")
                inst.sg.statemem.exitstate = true
            end),
			EventHandler("startcorruption", function(inst)
				inst.sg:GoToState("stalker_corruption_pre")
			end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() and inst.sg.statemem.exitstate then
                    inst.sg:GoToState("idle") -- assuming pushanim param (true for rocky and bat)
                end
            end),
		},

        onexit = function(inst)
            inst.worm.components.health:SetInvincible(false)
        end,
	},

    State{
		name = "stalker_corruption_pre",
		tags = { "busy", "nointerrupt", "noattack", "temp_invincible", "stalkercorrupting", },

		onenter = function(inst)
            inst.worm.components.health:SetInvincible(true)
			inst.AnimState:PlayAnimation("stalker_corrupt_pre")
            inst.AnimState:AddOverrideBuild("stalker_corrupt_fx_build")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_a")
		end,

		timeline =
		{
		    --#SFX
		    -- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

            -- 12 frames to tween colour
            FrameEvent(38 - 12, function(inst)
                WORMBOSS_UTILS.TransformToShadowFXPre(inst.worm)
            end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
                    local x, y, z = inst.Transform:GetWorldPosition()
					local rot = inst.Transform:GetRotation()
                    local worm = inst.worm
					local corrupted = SpawnPrefab("worm_boss_shadow")
                    corrupted.Transform:SetPosition(x, y, z)
					corrupted.Transform:SetRotation(rot)

                    local data = {}
                    worm:OnSave(data) -- purposely not GetPersistData/SetPersistData, components shouldnt save
                    corrupted:OnLoad(data)

                    if corrupted.head then
                        corrupted.head.sg:GoToState("stalker_corruption_pst")
                    end

                    worm:Remove()
				end
			end),
		},

		onexit = function(inst)
            inst.worm.components.health:SetInvincible(false)
            inst.AnimState:ClearOverrideBuild("stalker_corrupt_fx_build")
			assert(BRANCH ~= "dev", "We exited stalker_corruption_pre state somehow :(")
		end,
	},

    State{
		name = "stalker_corruption_pst",
		tags = { "busy", "nointerrupt", "noattack", "temp_invincible", "stalkercorrupting", },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("stalker_corrupt_pst")
            inst.AnimState:AddOverrideBuild("stalker_corrupt_fx_build")
            inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_b")
            WORMBOSS_UTILS.SetBlack(inst.worm)
		end,

		timeline =
		{
            --#SFX
		    -- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

            FrameEvent(10, function(inst)
                WORMBOSS_UTILS.TransformToShadowFXPst(inst.worm)
            end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("taunt")
				end
			end),
		},

        onexit = function(inst)
            inst.AnimState:ClearOverrideBuild("stalker_corrupt_fx_build")
        end
	},
}

return StateGraph("worm_boss_head", states, events, "idle")
