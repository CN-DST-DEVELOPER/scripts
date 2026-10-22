require("stategraphs/commonstates")

local events =
{
    EventHandler("ontalk", function(inst, data)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("talk", inst.sg:HasStateTag("talking"))
        end
    end),

    EventHandler("spawn", function(inst)
        inst.sg:GoToState("spawn")
    end),

    EventHandler("casting", function(inst)
        inst.sg:GoToState("casting")
    end),

    EventHandler("casting2", function(inst)
        inst.sg:GoToState("casting2")
    end),

    EventHandler("stop_casting", function(inst, data)
        inst.sg:GoToState(inst.sg.currentstate.name == "casting2" and "casting2_pst" or "casting_pst", data)
    end),

    EventHandler("despawn", function(inst, data)
        inst.sg:GoToState((data and data.quick and "quick_despawn") or "despawn")
    end),

    EventHandler("transform", function(inst, data)
        inst.sg:GoToState("transform_pre", data)
    end),
}

local CAST_SOUND_NAME = "castloopsound"

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle", true)
            if inst.components.npc_talker and inst.components.npc_talker:HasLines() then
                inst:EnableCameraFocus(false)
                inst.components.npc_talker:DoNextLine()
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
        name = "spawn",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("spawn")
            inst.SoundEmitter:PlaySound("rifts2/charlie/charlie_arrive")
            inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
            FrameEvent(22, function(inst) inst.DynamicShadow:Enable(true) end)
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
            inst.DynamicShadow:Enable(true)
        end,
    },

    State{
        name = "casting",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("rifts2/charlie/casting_lp", CAST_SOUND_NAME)
            inst.AnimState:PlayAnimation("cast_pre")
            inst.AnimState:PushAnimation("cast_idle", true)
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound(CAST_SOUND_NAME)
        end,
    },

    State{
        name = "casting_pst",
        tags = {"busy"},

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("cast_pst")
            inst.SoundEmitter:PlaySound("rifts2/charlie/casting_pst")
            inst.sg.statemem.despawn = data and data.despawn
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(inst.sg.statemem.despawn and "despawn" or "idle")
                end
            end),
        },
    },

    State{
        name = "casting2",
        tags = { "busy" },

        onenter = function(inst)
            -- inst.SoundEmitter:PlaySound("rifts2/charlie/casting_lp", CAST_SOUND_NAME)
            inst.AnimState:PlayAnimation("cast_circle_pre")
            inst.AnimState:PushAnimation("cast_circle_loop", true)
        end,

        onexit = function(inst)
            -- inst.SoundEmitter:KillSound(CAST_SOUND_NAME)
        end,
    },

    State{
        name = "casting2_pst",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("cast_circle_pst")
            -- inst.SoundEmitter:PlaySound("rifts2/charlie/casting_pst")
            inst.sg.statemem.despawn = data and data.despawn
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(inst.sg.statemem.despawn and "despawn" or "idle")
                end
            end),
        },
    },

	State{
		name = "talk",
		tags = { "talking", "idle", "canrotate" },

		onenter = function(inst, noanim)
			if not noanim then
				inst.AnimState:PlayAnimation("talk_pre") --11
				inst.AnimState:PushAnimation("talk_loop") --21
				inst.sg:SetTimeout((11 + 21) * FRAMES)
			elseif inst.AnimState:IsCurrentAnimation("talk_pre") then
				inst.sg:SetTimeout((11 + 21) * FRAMES - inst.AnimState:GetCurrentAnimationTime())
			else
				inst.sg:SetTimeout(21 * FRAMES - inst.AnimState:GetCurrentAnimationTime())
			end
            inst.sg.mem.skipdonetalking = nil
		end,

        events =
        {
            EventHandler("donetalking", function(inst)
                if not inst.sg.mem.skipdonetalking then
                    if inst.components.npc_talker:HasLines() then
                        inst.components.npc_talker:DoNextLine()
                    else
                        inst.sg:GoToState("talk_pst", inst.socketing_key) -- despawn if we're in socketing key cutscene
                    end
                end
            end),
        },

		ontimeout = function(inst)
            -- inst.sg:GoToState("talk_pst")
            -- if inst.components.npc_talker:HasLines() then
            --     inst.components.npc_talker:DoNextLine()
            -- else
            --     inst.sg:GoToState("talk_pst", true)
            -- end
		end,
	},

	State{
		name = "talk_pst",
		tags = { "idle", "canrotate" },

		onenter = function(inst, wassocketing)
			inst.AnimState:PlayAnimation("talk_pst")
            inst.sg.statemem.wassocketing = wassocketing
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.sg.statemem.wassocketing and "give" or "idle")
				end
			end),
		},
	},

    State{
        name = "despawn",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle")
            inst.AnimState:PushAnimation("spawn_out", false)
        end,

        timeline =
        {
            SoundFrameEvent(60, "rifts2/charlie/charlie_leave"),
            FrameEvent(60 + 45, function(inst) inst.DynamicShadow:Enable(false) end),
            FrameEvent(60 + 46, RemovePhysicsColliders),
        },

        events =
        {
            EventHandler("entitysleep", function(inst)
                inst:Remove()
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
        },

        onexit = function(inst)
            -- ?
        end,
    },

    State{
        name = "quick_despawn",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("spawn_out", false)
            inst.SoundEmitter:PlaySound("rifts2/charlie/charlie_leave")
        end,

        timeline =
        {
            FrameEvent(45, function(inst) inst.DynamicShadow:Enable(false) end),
            FrameEvent(46, RemovePhysicsColliders),
        },

        events =
        {
            EventHandler("entitysleep", function(inst)
                inst:Remove()
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
        },

        onexit = function(inst)
            -- ?
        end,
    },

    State{
        name = "transform_pre",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("lift_pre", false)
            inst.sg.statemem.gate = data ~= nil and data.gate or nil
            inst.sg.statemem.speed = 2

            inst.Physics:SetMass(9999)
            inst.Physics:CollidesWith(COLLISION.GROUND)
            if inst.sg.statemem.gate then
                inst:ForceFacePoint(inst.sg.statemem.gate.Transform:GetWorldPosition())
            end

			inst:TriggerTransformMusic()
        end,

        timeline =
        {
            FrameEvent(70, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.2, 0, 0) end),
            FrameEvent(75, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.3, 0, 0) end),
            FrameEvent(78, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.35, 0, 0) end),
            FrameEvent(82, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.4, 0, 0) end),
            FrameEvent(85, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.5, 0, 0) end),

            FrameEvent(92, function(inst)
                if inst.components.npc_talker:HasLines() then -- last line
                    inst.components.npc_talker:DoNextLine()
                end
            end),

            FrameEvent(93, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.7, 0, 0) end),
            FrameEvent(101, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.8, 0, 0) end),
            FrameEvent(111, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.9, 0, 0) end),
            FrameEvent(113, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 1, 0, 0) end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("transform_loop", { speed = inst.sg.statemem.speed })
                end
            end),
        },
    },

    State{
        name = "transform_loop",
        tags = { "busy" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("lift_loop", true)
            if data and data.speed then
                inst.Physics:SetMotorVelOverride(data.speed, 0, 0)
            end
        end,
    },

    State{
        name = "give",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("giving")
            inst.components.npc_talker:Chatter("CHARLIE_NPC_GIVE_SHADOWHEART_INFUSED")
            inst.components.npc_talker:DoNextLine()
        end,

        timeline =
        {
            FrameEvent(16, function(inst)
                inst.SoundEmitter:PlaySound("rifts8/charlie_ritual/summon_small")
            end),
            FrameEvent(55, function(inst)
                inst.SoundEmitter:PlaySound("rifts2/charlie/charlie_cast")
                local x, y, z = inst.Transform:GetWorldPosition()
                local heart = SpawnPrefab("shadowheart_infused")
                heart.sg:GoToState("stunned", GetRandomWithVariance(10, 1))

                local target = inst.atrium or FindClosestPlayer(x, y, z, true)
                heart.components.inventoryitem:SetLanded(false, true)
                LaunchAt(heart, inst, target, 1, 2.5, 1.5, 0)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("despawn")
                end
            end),
        }
    },
}

return StateGraph("charlie_npc", states, events, "idle")