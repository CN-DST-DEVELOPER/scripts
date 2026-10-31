require("stategraphs/commonstates")

local AOEUtil = require("aoeutil")

local events =
{
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnDeath(),
    EventHandler("doattack", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
			inst.sg:GoToState("pounce", data.target)
        end
    end),
}

local AOE_TAGSET
local function GetAOEAttackTagSet(inst) -- only if not tied to charlie boss (debug)
	if AOE_TAGSET == nil then
		AOE_TAGSET = AOEUtil.AttackTagSet()
		AOE_TAGSET:AppendCantTags("shadowthrall", "shadow", "shadowcreature", "shadowchesspiece", "shadowboss")
		-- AOE_TAGSET:Register() don't register tags for the debug ones
	end
	return AOE_TAGSET
end

local function ShouldAvoidAggroFn(target, inst)
	return false --false means target should not aggro on us - _-""
end

local AOE_RADIUS = 0.6
local function DoAOE(inst)
    local tagset
    if inst.caster and inst.caster:IsValid() then
        tagset = inst.caster:GetAOEAttackTagSet()
    else
        tagset = GetAOEAttackTagSet(inst)
        inst.caster = nil
    end

	inst.components.combat.shouldavoidaggrofn = ShouldAvoidAggroFn
    AOEUtil.Attack(inst, AOE_RADIUS, tagset, nil, nil)
	inst.components.combat.shouldavoidaggrofn = nil
end

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.components.locomotor:Stop()

            if pushanim and not inst.AnimState:AnimDone() then
                inst.sg.statemem.pushanim = true
            else
                local anim = "idle"
				if not inst.AnimState:IsCurrentAnimation(anim) or inst.AnimState:AnimDone() then
					inst.AnimState:PlayAnimation(anim, true)
				end
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
            end
        end,

		events =
		{
			--NOTE: we may be have several anims still queued
			EventHandler("animqueueover", function(inst)
				if inst.sg.statemem.pushanim and inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,
    },

	State{
		name = "walk_start",
		tags = { "moving", "canrotate" },

		onenter = function(inst)
			if inst.sg.lasttags["running"] then
				inst.sg:GoToState("run_stop", true)
				return
			end
			inst.components.locomotor:WalkForward()
			inst.AnimState:PlayAnimation("walk_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("walk")
				end
			end),
		},
	},

	State{
		name = "walk",
		tags = { "moving", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:WalkForward()
			if not inst.AnimState:IsCurrentAnimation("walk_loop") then
				inst.AnimState:PlayAnimation("walk_loop", true)
			end

			local x, _, z = inst.Transform:GetWorldPosition()
			local map = TheWorld.Map
			if map:IsPointInCharlieBossArena(x, 0, z) then
				local theta = inst.Transform:GetRotation() * DEGREES
				if not map:IsValidTileAtPoint(x + math.cos(theta), 0, z - math.sin(theta)) then
					inst.sg:GoToState("fadeout")
					return
				end
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("walk")
		end,
	},

	State{
		name = "walk_stop",
		tags = { "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("walk_pst")
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
		name = "run_start",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor.runspeed = TUNING.CHARLIE_BOSS_RUNNER_WALKSPEED
			inst.components.locomotor:RunForward()
			inst.AnimState:PlayAnimation("run_pre")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.components.locomotor.runspeed = inst.components.locomotor.runspeed * 0.75 + TUNING.CHARLIE_BOSS_RUNNER_RUNSPEED * 0.25
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("run")
				end
			end),
		},
	},

	State{
		name = "run",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor.runspeed = (inst.components.locomotor.runspeed + TUNING.CHARLIE_BOSS_RUNNER_RUNSPEED) * 0.5
			inst.components.locomotor:RunForward()
			if not inst.AnimState:IsCurrentAnimation("run_loop") then
				inst.AnimState:PlayAnimation("run_loop", true)
			end

			local x, _, z = inst.Transform:GetWorldPosition()
			local map = TheWorld.Map
			if map:IsPointInCharlieBossArena(x, 0, z) then
				local theta = inst.Transform:GetRotation() * DEGREES
				if not map:IsValidTileAtPoint(x + math.cos(theta), 0, z - math.sin(theta)) then
					inst.sg:GoToState("fadeout")
					return
				end
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("run")
		end,
	},

	State{
		name = "run_stop",
		tags = { "idle" },

		onenter = function(inst, towalk)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("run_pst")
			if towalk then
				inst.sg:RemoveStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end
		end,

		events =
		{
			EventHandler("locomote", function(inst, data)
				if inst.components.locomotor:WantsToMoveForward() and not inst.components.locomotor:WantsToRun() then
					if inst.sg:HasStateTag("idle") then
						inst.sg:RemoveStateTag("idle")
						inst.sg:AddStateTag("canrotate")
					end
					return true
				elseif not inst.sg:HasStateTag("idle") then
					inst.sg:RemoveStateTag("canrotate")
					inst.sg:AddStateTag("idle")
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.sg:HasStateTag("idle") and "idle" or "walk_start")
				end
			end),
		},
	},

	State{
		name = "fadeout",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.spawnfader:FadeOut()
		end,

		timeline =
		{
			TimeEvent(0.5, function(inst)
				--keep running against wall
				inst.Physics:ClearCollidesWith(COLLISION.SANITY)
			end),
		},

		events =
		{
			EventHandler("spawnfaderout", function(inst)
				inst:Remove()
			end),
		},

		onexit = function(inst)
			inst.components.spawnfader:Cancel()
			inst.Physics:CollidesWith(COLLISION.SANITY)
		end,
	},

    State{
        name = "pounce",
        tags = { "noattack", "attack", "busy", "jumping" },

        onenter = function(inst, target)
            inst.Light:Enable(false)
            inst.components.locomotor:Stop()
            inst.components.combat:StartAttack()
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.tracking = true

				local x, _, z = inst.Transform:GetWorldPosition()
				local tx, _, tz = target.Transform:GetWorldPosition()
				local vx, _, vz = target.Physics:GetVelocity()

				local dt = 16 * FRAMES
				local dx = tx + vx * dt - x
				local dz = tz + vz * dt - z
				local speed = math.min(8, math.sqrt(dx * dx + dz * dz)) / dt
				if speed >= 6 then
					inst.sg.statemem.far = true
				else
					dt = 11 * FRAMES
					dx = tx + vx * dt - x
					dz = tz + vz * dt - z
					speed = math.max(1, math.sqrt(dx * dx + dz * dz)) / dt
				end
				if x ~= tx or z ~= tz then
					inst.Transform:SetRotation(math.atan2(z - tz, tx - x) * RADIANS)
				end
				inst.Physics:SetMotorVelOverride(speed, 0, 0)
			end
			inst.AnimState:PlayAnimation(inst.sg.statemem.far and "attack" or "attack_quick")
            inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/pounce")
        end,

		onupdate = function(inst, dt)
			if dt > 0 and inst.sg.statemem.tracking then
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local lastdrot = inst.sg.statemem.drot
						if lastdrot ~= 0 then
							local tx, _, tz = target.Transform:GetWorldPosition()
							local vx, _, vz = target.Physics:GetVelocity()
							local dt = (inst.sg.statemem.far and 16 or 11) * FRAMES
							tx = tx + vx * dt
							tz = tz + vz * dt

							local rot = inst.Transform:GetRotation()
							local rot1 = inst:GetAngleToPoint(tx, 0, tz)
							local drot = ReduceAngle(rot1 - rot)

							drot = lastdrot and
								math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot)) or
								math.clamp(drot, -6, 6)

							inst.Transform:SetRotation(rot + drot)
							inst.sg.statemem.lastdrot = drot
						end
					else
						inst.sg.statemem.target = nil
					end
				end
			end
		end,

        timeline =
        {
            --#SFX
            -- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("xxx") end),

			FrameEvent(6, function(inst)
				inst.sg.statemem.tracking = false
			end),
			FrameEvent(11, function(inst)
				if not inst.sg.statemem.far then
					inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/death")
					DoAOE(inst)
					RemovePhysicsColliders(inst)
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
				end
			end),
			FrameEvent(16, function(inst)
				if inst.sg.statemem.far then
					inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/death")
					DoAOE(inst)
					RemovePhysicsColliders(inst)
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
				end
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:Remove()
                end
            end),
		},

		onexit = function(inst)
			inst.Light:Enable(true)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.Physics:CollidesWith(COLLISION.SANITY)
		end,
    },

    State{
        name = "spawn",
        tags = { "busy", "noattack", "canrotate" },

        onenter = function(inst)
            inst.Light:Enable(false)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("spawn")
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
        tags = { "busy", "dead" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("disappear")
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
            inst:AddTag("NOCLICK")
            inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/death")
        end,

        events =
        {
            EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
            end),
        },

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
			inst.Physics:CollidesWith(COLLISION.SANITY)
        end,
    },
}

return StateGraph("charlie_boss_runner", states, events, "walk")
