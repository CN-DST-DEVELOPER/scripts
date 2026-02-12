local clockwork_common = require("prefabs/clockwork_common")
require("stategraphs/commonstates")

local function hit_recovery_skip_cooldown_fn(inst, last_t, delay)
	--no skipping when we're dodging (hit_recovery increased)
	return inst.hit_recovery == nil
		and inst.components.combat:InCooldown()
		and inst.sg:HasStateTag("idle")
end

local events=
{
	CommonHandlers.OnHop(),
    CommonHandlers.OnLocomote(false, true),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
	CommonHandlers.OnSleepEx(),
	CommonHandlers.OnWakeEx(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnAttacked(nil, nil, hit_recovery_skip_cooldown_fn),
    CommonHandlers.OnDeath(),

	EventHandler("doattack", function(inst)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			inst.sg:GoToState("attack")
		end
	end),
	EventHandler("dojoust", function(inst, target)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) and
			target and target:IsValid()
		then
			inst.sg:GoToState("joust_pre", target)
		end
	end),
    EventHandler("despawn", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("despawn")
        end
    end),

    EventHandler("spawned", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("spawned")
        end
    end),
}

local function AreDifferentPlatforms(inst, target)
    if inst.components.locomotor.allow_platform_hopping then
        return inst:GetCurrentPlatform() ~= target:GetCurrentPlatform()
    end
    return false
end

local LANCE_PADDING = 0.6
local JOUSTING_TAGS = { "jousting" }

local function should_collide(guy, inst)
	return DiffAngle(inst.Transform:GetRotation(), guy.Transform:GetRotation()) > 44
end

local function DoJoustAoe(inst, targets)
	local x, y, z = inst.Transform:GetWorldPosition()

	--lance start and end points (NOTE: 2d vector using x,y,0)
	local p1 = Vector3(0.05, -0.43, 0) --base of lance
	local p2 = Vector3(2.6 - LANCE_PADDING, -0.06, 0) --tip of lance

	--rotate to match our facing
	local theta = -inst.Transform:GetRotation() * DEGREES
	local cos_theta = math.cos(theta)
	local sin_theta = math.sin(theta)
	local tempx = p1.x
	p1.x = x + tempx * cos_theta - p1.y * sin_theta
	p1.y = z + p1.y * cos_theta + tempx * sin_theta
	tempx = p2.x
	p2.x = x + tempx * cos_theta - p2.y * sin_theta
	p2.y = z + p2.y * cos_theta + tempx * sin_theta

	local cx = (p1.x + p2.x) * 0.5
	local cz = (p1.y + p2.y) * 0.5
	local radius = math.sqrt(distsq(p1.x, p1.y, cx, cz))
	local lsq = Dist2dSq(p1, p2)
	local t = GetTime()

	local function should_hit(guy, inst)
		local last_t = targets[guy]
		if last_t == nil or last_t + 0.75 < t then
			local p3 = guy:GetPosition()
			p3.y, p3.z = p3.z, 0 --convert x,0,z -> x,y,0
			local range = LANCE_PADDING + guy:GetPhysicsRadius(0)
			--if DistPointToSegmentXYSq(p3, p1, p2) < range * range then
			--V2C: modified becasue we don't want to hit anything behind the back point
			local dot = (p3.x - p1.x) * (p2.x - p1.x) + (p3.y - p1.y) * (p2.y - p1.y)
			if dot >= 0 then
				dot = dot / lsq
				local dsq =
					dot >= 1 and
					Dist2dSq(p3, p2) or
					Dist2dSq(p3, Vector3(p1.x + dot * (p2.x - p1.x), p1.y + dot * (p2.y - p1.y), 0))
				if dsq < range * range then
					targets[guy] = t
					return true
				end
			end
		end
		return false
	end

	local collided = false
	inst.components.combat.ignorehitrange = true
	clockwork_common.FindAOETargetsAtXZ(inst, cx, cz, radius + LANCE_PADDING + 3,
		function(guy, inst)
			if should_hit(guy, inst) then
				if guy:HasTag("jousting") and should_collide(guy, inst) then
					guy:PushEventImmediate("joust_collide")
					collided = true
				else
					inst.components.combat:DoAttack(guy)
					guy:PushEvent("knockback", { knocker = inst, radius = 6.5, forcelanded = true })
				end
			end
		end)
	inst.components.combat.ignorehitrange = false

	local knight_rad = inst:GetPhysicsRadius(0)
	for i, v in ipairs(TheSim:FindEntities(cx, 0, cz, radius + LANCE_PADDING + knight_rad, JOUSTING_TAGS)) do
		if v ~= inst and should_hit(v, inst) and should_collide(v, inst) then
			v:PushEventImmediate("joust_collide")
			collided = true
		end
	end

	if collided then
		inst:PushEventImmediate("joust_collide")
	end
end

local states=
{
     State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, playanim)
			inst.components.locomotor:StopMoving()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
				inst.AnimState:PushAnimation("idle_loop")
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
        end,

        timeline =
        {
		    TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/idle") end ),
        },

        events=
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },
    },

   State{
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
			inst.components.locomotor:StopMoving()
			local target = inst.components.combat.target
			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			inst.Transform:SetSixFaced() --best model for facing target with an unfaced anim
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/voice")
        end,

        timeline =
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/pawground") end ),
		    TimeEvent(28*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/pawground") end ),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(48, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
        },

        events=
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },

		onexit = function(inst)
			inst.Transform:SetFourFaced()
		end,
    },

    State{  name = "ruinsrespawn",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("spawn")
	        inst.components.sleeper.isasleep = true
	        inst.components.sleeper:GoToSleep(.1)
        end,

        timeline =
        {
    		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce") end ),
        },

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("sleeping")
				end
			end),
        },
    },

	State{
		name = "hit",
		tags = { "hit", "busy" },
		
		onenter = function(inst)
			if inst.sg.lasttags and inst.sg.lasttags["stunned"] then
				inst.sg:GoToState("stun_hit")
				return
			end
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/hurt") end),
			FrameEvent(11, function(inst)
				if inst.sg.statemem.doattack then
					inst.sg:GoToState("attack")
					return
				elseif inst.sg.statemem.dojoust and inst.sg.statemem.dojoust:IsValid() then
					inst.sg:GoToState("joust_pre", inst.sg.statemem.dojoust)
					return
				end
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst)--, data)
				if not inst.sg:HasStateTag("busy") then
					inst.sg:GoToState("attack")
				else
					inst.sg.statemem.doattack = true
				end
				return true
			end),
			EventHandler("dojoust", function(inst, target)
				if target and target:IsValid() then
					if not inst.sg:HasStateTag("busy") then
						inst.sg:GoToState("joust_pre", target)
					else
						inst.sg.statemem.dojoust = target
					end
				end
				return true
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("atk")
			inst.components.combat:StartAttack()
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/attack")
				inst.components.combat:DoAttack()
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("busy")
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
	},

	State{
		name = "joust_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:StopMoving()
			inst.Transform:SetEightFaced()
			inst.AnimState:PlayAnimation("joust_pre")
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/voice")
			inst.components.combat:StartAttack()
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.maxdelta = 20

				--true dir (for movement)
				inst.sg.statemem.dir = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
			else
				--true dir (for movement)
				inst.sg.statemem.dir = inst.Transform:GetRotation()
			end

			--facing dir snapped to 45s (for hitbox)
			inst.Transform:SetRotation(math.floor(inst.sg.statemem.dir / 45 + 0.5) * 45)
		end,

		onupdate = function(inst, dt)
			if inst:IsAsleep() then
				inst.sg:GoToState("idle")
			elseif dt > 0 then
				if inst.sg:HasStateTag("jumping") then
					inst.Physics:SetMotorVelOverride(TUNING.YOTH_KNIGHT_JOUST_SPEED * inst.components.locomotor:GetSpeedMultiplier(), 0, 0)
				else
					local target = inst.sg.statemem.target
					if target then
						if target:IsValid() then
							local rot = inst.sg.statemem.dir
							local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
							local delta = math.clamp(ReduceAngle(rot1 - rot), -inst.sg.statemem.maxdelta, inst.sg.statemem.maxdelta) * math.min(1, dt / FRAMES)
							inst.sg.statemem.maxdelta = math.max(1, inst.sg.statemem.maxdelta - dt / FRAMES)

							--true dir (for movement)
							inst.sg.statemem.dir = rot + delta

							--facing dir snapped to 45s (for hitbox)
							inst.Transform:SetRotation(math.floor(inst.sg.statemem.dir / 45 + 0.5) * 45)
						else
							inst.sg.statemem.target = nil
						end
					end
				end
			end
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
				inst.sg:AddStateTag("jumping")

				local theta = ReduceAngle(inst.sg.statemem.dir - inst.Transform:GetRotation()) * DEGREES
				local speed = TUNING.YOTH_KNIGHT_JOUST_SPEED * inst.components.locomotor:GetSpeedMultiplier()
				inst.Physics:SetMotorVelOverride(speed * math.cos(theta), 0, -speed * math.sin(theta))
			end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.jousting = true
					inst.sg:GoToState("joust_loop", {
						target = inst.sg.statemem.target,
						dir = inst.sg.statemem.dir,
					})
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.jousting then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.Transform:SetFourFaced()
			end
		end,
	},

	State{
		name = "joust_loop",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, data)
			ToggleOffCharacterCollisions(inst)
			inst.Transform:SetEightFaced()
			if not inst.AnimState:IsCurrentAnimation("joust_loop") then
				inst.AnimState:PlayAnimation("joust_loop", true)
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			if data then
				inst.sg.statemem.target = data.target
				inst.sg.statemem.dir = data.dir --true dir (for movement)
				inst.sg.statemem.loops = data.loops or 1
				inst.sg.statemem.targets = data.targets or {}
			else
				inst.sg.statemem.loops = 1
				inst.sg.statemem.targets = {}
			end
			inst.components.combat:RestartCooldown()
			inst:AddTag("jousting")
		end,

		onupdate = function(inst, dt)
			if inst:IsAsleep() then
				inst.sg:GoToState("idle")
			elseif dt > 0 then
				local rot = inst.sg.statemem.dir
				if rot then
					local target = inst.sg.statemem.target
					if target then
						if target:IsValid() then
							local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
							if math.floor(rot / 45 + 0.5) * 45 == math.floor(rot1 / 45 + 0.5) * 45 then
								local delta = math.clamp(ReduceAngle(rot1 - rot), -1, 1) * math.min(1, dt / FRAMES)
								rot = rot + delta
								inst.sg.statemem.dir = rot
							end
						else
							inst.sg.statemem.target = nil
						end
					end

					local theta = ReduceAngle(rot - inst.Transform:GetRotation()) * DEGREES
					local speed = TUNING.YOTH_KNIGHT_JOUST_SPEED * inst.components.locomotor:GetSpeedMultiplier()
					inst.Physics:SetMotorVelOverride(speed * math.cos(theta), 0, -speed * math.sin(theta))
				end
				DoJoustAoe(inst, inst.sg.statemem.targets)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				if not (inst.sg.laststate and inst.sg.laststate.name == "joust_pre") then
					inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce")
				end
			end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
		},

		ontimeout = function(inst)
			local maxloops = 3
			local loops = inst.sg.statemem.loops
			if loops >= maxloops then
				inst.sg.statemem.stopping = true
				inst.sg:GoToState("joust_pst")
				return
			elseif loops < maxloops - 1 then
				local target = inst.sg.statemem.target
				if target and target:IsValid() and DiffAngle(inst.Transform:GetRotation(), inst:GetAngleToPoint(target.Transform:GetWorldPosition())) < 90 and not AreDifferentPlatforms(inst, target) then
					--target still in front, keep going
					inst.sg.statemem.jousting = true
					inst.sg:GoToState("joust_loop", {
						target = target,
						dir = inst.sg.statemem.dir,
						loops = loops + 1,
						targets = inst.sg.statemem.targets,
					})
					return
				end
			end
			--force end after 1 more loop
			inst.sg.statemem.jousting = true
			inst.sg:GoToState("joust_loop", {
				dir = inst.sg.statemem.dir,
				loops = maxloops,
				targets = inst.sg.statemem.targets,
			})
		end,

		events =
		{
			EventHandler("joust_collide", function(inst)
				inst.sg:GoToState("joust_collide")
			end),
		},

		onexit = function(inst)
			if not (inst.sg.statemem.jousting or inst.sg.statemem.stopping) then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.Transform:SetFourFaced()
			end
			if not inst.sg.statemem.jousting then
				ToggleOnCharacterCollisions(inst)
				inst:RemoveTag("jousting")
			end
		end,
	},

	State{
		name = "joust_pst",
		tags = { "busy", "jumping" },

		onenter = function(inst)
			inst.Transform:SetEightFaced()
			inst.AnimState:PlayAnimation("joust_pst1")
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/attack")
			local _
			inst.sg.statemem.vx, _, inst.sg.statemem.vz = inst.Physics:GetMotorVel()
			inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * 0.64, 0, inst.sg.statemem.vz * 0.64)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * 0.32, 0, inst.sg.statemem.vz * 0.32) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * 0.16, 0, inst.sg.statemem.vz * 0.16) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * 0.08, 0, inst.sg.statemem.vz * 0.08) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * 0.04, 0, inst.sg.statemem.vz * 0.04) end),
			FrameEvent(10, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("busy")
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
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			inst.Transform:SetFourFaced()
		end,
	},

	State{
		name = "joust_collide",
		tags = { "busy", "jumping", "nosleep" },

		onenter = function(inst)
			inst.Transform:SetEightFaced()
			inst.AnimState:PlayAnimation("joust_pst2")
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/attack")
			local _
			inst.sg.statemem.vx, _, inst.sg.statemem.vz = inst.Physics:GetMotorVel()
			inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * -0.6, 0, inst.sg.statemem.vz * -0.5)
		end,

		timeline =
		{
			FrameEvent(16, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/hurt")
				inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land")
			end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * -0.24, 0, inst.sg.statemem.vz * -0.2) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * -0.12, 0, inst.sg.statemem.vz * -0.1) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.vx * -0.06, 0, inst.sg.statemem.vz * -0.05) end),
			FrameEvent(20, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/pawground") end),
            CommonHandlers.OnNoSleepFrameEvent(41, function(inst)
            	inst.sg:RemoveStateTag("nosleep")
				inst.sg:RemoveStateTag("busy")
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
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			inst.Transform:SetFourFaced()
		end,
	},

	State{
		name = "stun_pre",
		tags = { "stunned", "busy", "nosleep", "noelectrocute" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_pre")
			inst.sg.mem.stunhits = 0
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stun_loop")
				end
			end),
		},
	},

	State{
		name = "shock_to_stun",
		tags = { "stunned", "busy", "nosleep", "noelectrocute" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("shock_to_stun")
			inst.sg.mem.stunhits = 0
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stun_loop")
				end
			end),
		},
	},

	State{
		name = "stun_loop",
		tags = { "stunned", "busy", "caninterrupt", "nosleep" },

		onenter = function(inst, nohit)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_loop")
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/liedown") end),
			FrameEvent(12, function(inst)
				inst.sg.mem.stunhits = inst.sg.mem.stunhits + 1
			end),
			FrameEvent(24, function(inst)
				inst.sg.mem.stunhits = inst.sg.mem.stunhits + 1
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stun_pst")
				end
			end),
		},
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "busy", "hit", "nosleep" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_hit")
			inst.sg.mem.stunhits = inst.sg.mem.stunhits + 1
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/hurt") end),
			FrameEvent(6, function(inst)
				if inst.sg.mem.stunhits >= 4 then
					inst.sg:GoToState("stun_pst")
					return
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stun_loop")
				end
			end),
		},
	},

	State{
		name = "stun_pst",
		tags = { "stunned", "busy", "nosleep" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_pst")
			if inst.sg.mem.stunhits < 4 then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
				inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/idle")
			end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("stunned")
				inst.sg.mem.stunhits = nil
			end),
			FrameEvent(18, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
			CommonHandlers.OnNoSleepFrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("nosleep")
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(30, function(inst)
				inst.sg:RemoveStateTag("busy")
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
	},
    State{
        name = "despawn",
        tags = {"busy", "nointerrupt"},

        onenter = function(inst)
            inst.persists = false
            inst.OnEntitySleep = inst.Remove
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle_loop", true)
            inst.sg:SetTimeout(0.8)
        end,
        ontimeout = function(inst)
            inst:Remove()
        end,
        onexit = function(inst)
            inst:DoTaskInTime(0, inst.Remove)
        end,
    },
    State{
        name = "spawned",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("spawn_2")
        end,

        timeline = {
            FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce") end ),
        },

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },
}

CommonStates.AddWalkStates(states,
{
	walktimeline =
	{
		FrameEvent(0, function(inst)
			inst.components.locomotor:StopMoving()
		end),
		FrameEvent(7, function(inst)
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce")
			inst.components.locomotor:WalkForward()
		end),
		FrameEvent(19, function(inst)
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land")
			inst.components.locomotor:StopMoving()
		end),
	},
},
nil, --anims
true, --softstop
true --delaystart
)

CommonStates.AddSleepExStates(states,
{
    starttimeline =
    {
		FrameEvent(8, function(inst) inst.sg:RemoveStateTag("caninterrupt") end),
		TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/liedown") end ),
    },
	sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/sleep") end),
	},
	waketimeline =
	{
		CommonHandlers.OnNoSleepFrameEvent(15, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(21, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
},
{
	onsleep = function(inst)
		inst.sg:AddStateTag("caninterrupt")
	end,
})

CommonStates.AddDeathState(states,
{
	FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/death") end),
})

CommonStates.AddFrozenStates(states)

CommonStates.AddElectrocuteStates(states,
{	--timeline
	loop =
	{
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/hurt") end),
	},
	pst =
	{
		FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land") end),
	},
},
{	--anims
	loop = function(inst)
		if inst.sg.lasttags["stunned"] then
			inst.sg:AddStateTag("stunned")
			inst.override_combat_fx_height = nil
			return "stun_shock_loop"
		end
	end,
	pst = function(inst)
		if inst.sg.lasttags["stunned"] then
			inst.sg:AddStateTag("stunned")
			return "stun_shock_pst"
		end
	end,
},
{	--fns
	loop_onenter = function(inst)
		if inst.sg:HasStateTag("stunned") then
			--V2C: can change this back since fx is already spawned at this point
			inst.override_combat_fx_height = "high"
		end
	end,
	pst_onenter = function(inst)
		if not inst.sg:HasStateTag("stunned") then
			inst.sg:GoToState("shock_to_stun")
		end
	end,
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			inst.sg:GoToState(inst.sg:HasStateTag("stunned") and "stun_loop" or "idle")
		end
	end,
})

CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)
CommonStates.AddHopStates(states, true,
{ pre = "boat_jump_pre", loop = "boat_jump_loop", pst = "boat_jump_pst"},
{
	hop_pst =
	{
		FrameEvent(3, function(inst)
			inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/land")
		end)
	},
},
nil,
nil,
{
	start_embarking_pre_frame = 8 * FRAMES,
},
{
	pre_onenter = function(inst)
		inst.components.locomotor:StopMoving()
	end,

	pre_ontimeout = function(inst)
		inst.SoundEmitter:PlaySound("dontstarve/creatures/knight"..inst.kind.."/bounce")
	end,
})

return StateGraph("knight", states, events, "idle")