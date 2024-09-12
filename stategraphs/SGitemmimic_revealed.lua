require("stategraphs/commonstates")

local events =
{
	CommonHandlers.OnLocomote(false, true),
	EventHandler("jump", function(inst)--, target)
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("jump_pre")
		end
	end),

	CommonHandlers.OnDeath(),
}

local actionhandlers =
{
	ActionHandler(ACTIONS.NUZZLE, "try_mimic_pre"),
}

local states =
{
	State {
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
		end,
	},

	State {
		name = "jump_pre",
		tags = { "busy", "jumping", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("jump")

			inst._toggle_tail_event:push()

			inst.SoundEmitter:PlaySound("rifts4/mimic/jump_out")
			local dist = 3
			local theta = PI2 * math.random()
			local jump_position = inst:GetPosition()
			jump_position.x = jump_position.x + math.cos(theta) * dist
			jump_position.z = jump_position.z - math.sin(theta) * dist
			inst:ForceFacePoint(jump_position)

			inst.sg.statemem.speed = math.min(16.5, dist / inst.AnimState:GetCurrentAnimationLength())
			inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
			inst.Physics:ClearCollidesWith(COLLISION.SANITY)
		end,

		timeline =
		{
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * .35, 0, 0)
				inst.Physics:CollidesWith(COLLISION.SANITY)
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
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.Physics:CollidesWith(COLLISION.SANITY)

			inst._toggle_tail_event:push()
		end,
	},

	State {
		name = "try_mimic_pre",
		tags = {"busy", "jumping"},

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("eye_disappear")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("try_mimic")
			end),
		},
	},

	State {
		name = "try_mimic",
		tags = { "busy", "jumping" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("jump")

			inst._toggle_tail_event:push()

			inst.SoundEmitter:PlaySound("rifts4/mimic/jump_in")

			local action = inst:GetBufferedAction()
			local target = (action and action.target)
			local dist
			if not target then
				dist = 3
				local theta = inst.Transform:GetRotation() * DEGREES
				target = inst:GetPosition()
				target.x = target.x + math.cos(theta) * dist
				target.z = target.z - math.sin(theta) * dist
			elseif EntityScript.is_instance(target) and target:IsValid() then
				inst.sg.statemem.target = target
				target = target:GetPosition()
				dist = math.sqrt(inst:GetDistanceSqToPoint(target))
			end
			inst.Physics:ClearCollidesWith(COLLISION.SANITY)
			inst:ForceFacePoint(target)
			inst.sg.statemem.speed = math.min(16.5, dist / inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				-- If we still have a target, and we successfully copy it, we can be removed.
				-- Otherwise, we just land normally and behave like nothing happened.
				local target = inst.sg.statemem.target
				if target and TheWorld.components.shadowthrall_mimics and target:IsValid()
						and TheWorld.components.shadowthrall_mimics.SpawnMimicFor(target) then
					SpawnPrefab("itemmimic_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
					inst:Remove()
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.Physics:CollidesWith(COLLISION.SANITY)

			inst:ClearBufferedAction()

			inst._toggle_tail_event:push()
		end,
	},

	State {
		name = "walk_start",
		tags = {"moving", "canrotate"},

		onenter = function(inst)
			inst.SoundEmitter:PlaySound("rifts4/mimic/movement_lp", "walkloop")
			inst.components.locomotor:StopMoving()
			inst.sg:SetTimeout(6*FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("walk")
		end,

		events =
		{
			EventHandler("death", function(inst)
				inst.SoundEmitter:KillSound("walkloop")
			end),
		},
	},

	State {
		name = "walk",
		tags = {"moving", "canrotate"},

		onenter = function(inst)
			inst.components.locomotor:WalkForward()
		end,

		events =
		{
			EventHandler("death", function(inst)
				inst.SoundEmitter:KillSound("walkloop")
			end),
		},
	},

	State {
		name = "walk_stop",
		tags = {"canrotate"},

		onenter = function(inst)
            inst.components.locomotor:StopMoving()
			inst.sg:SetTimeout(11*FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

		onexit = function(inst)
			inst.SoundEmitter:KillSound("walkloop")
		end,
	},
}

CommonStates.AddDeathState(states, {
	FrameEvent(1, function(inst)
		inst.SoundEmitter:PlaySound("rifts4/mimic/killed")
	end),
})

return StateGraph("itemmimic_revealed", states, events, "idle", actionhandlers)