require("stategraphs/commonstates")

local function ChooseAttack(inst, data)
	if data and inst:TryRegisterBiteTarget(data.target) then
		if inst.sg:HasStateTag("stealth") then
			inst.sg:GoToState("stealth_smile", data.target)
			return true
		elseif not inst.components.timer:TimerExists("leap_cd") then
			inst.sg:GoToState("leap_pre", data.target)
			return true
		else
			inst.sg:GoToState("bite_pre", data.target)
			return true
		end
	end
	return false
end

local events =
{
	EventHandler("doattack", function(inst, data)
		if not inst.sg:HasStateTag("busy") then
			ChooseAttack(inst, data)
		end
	end),
	EventHandler("locomote", function(inst)
		if inst.sg:HasStateTag("stealth") then
			if inst.components.locomotor:WantsToMoveForward() then
				if inst.sg:HasStateTag("idle") then
					inst.sg.statemem.stayhidden = true
					inst.sg:GoToState("stealth_move")
				end
			elseif inst.sg:HasStateTag("moving") then
				inst.sg.statemem.stayhidden = true
				inst.sg:GoToState("stealth_idle")
			end
		elseif inst.components.locomotor:WantsToMoveForward() and inst.sg:HasStateTag("idle") then
			local target = inst.components.combat.target
			if target then
				if not inst.components.combat:InCooldown() then
					inst.sg:GoToState("leap_pre", target)
				end
			else
				local dest = inst.components.locomotor.dest
				if dest and dest:IsValid() then
					inst.sg:GoToState("leap_pre", Vector3(dest:GetPoint()))
				end
			end
		end
	end),
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if inst.sg:HasStateTag("stealth") then
				inst.sg:GoToState("stealth_hit")
			elseif not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt") then
				inst.sg:GoToState("hit")
			end
		end
	end),
	EventHandler("enterstealth", function(inst)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("stealth")) then
			if inst.sg:HasStateTag("busy") then
				inst.sg.mem.enterstealth = true
			else
				inst.sg:GoToState("stealth_on")
			end
		end
	end),
	CommonHandlers.OnDeath(),
}

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "shadowthrall" }

local BITE_DIST = 0.75
local BITE_RADIUS = 1
local MAX_BITES = 5

local function DoBiteAOEAttack(inst)
	local lasttargets = inst.sg.mem.lasttargets
	local nexttargets = inst.sg.mem.nexttargets
	if lasttargets == nil then
		lasttargets, nexttargets = {}, {}
		inst.sg.mem.lasttargets = lasttargets
		inst.sg.mem.nexttargets = nexttargets
	end

	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	x = x + BITE_DIST * math.cos(rot)
	z = z - BITE_DIST * math.sin(rot)
	for i, v in ipairs(TheSim:FindEntities(x, y, z, BITE_RADIUS + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = BITE_RADIUS + v:GetPhysicsRadius(0)
			local dsq = v:GetDistanceSqToPoint(x, y, z)
			if dsq < range * range and inst.components.combat:CanTarget(v) then
				inst.components.combat:DoAttack(v)
				if lasttargets[v] then
					v:PushEvent("knockback", { knocker = inst, radius = BITE_DIST + BITE_RADIUS })
				end
				nexttargets[v] = true
			end
		end
	end
	inst.components.combat.ignorehitrange = false

	for k in pairs(lasttargets) do
		lasttargets[k] = nil
	end
	inst.sg.mem.lasttargets = nexttargets
	inst.sg.mem.nexttargets = lasttargets
end

local function DoAOEAttack(inst, radius, heavymult, mult, forcelanded)
	local lasttargets, nexttargets
	if mult then
		lasttargets = inst.sg.mem.lasttargets
		nexttargets = inst.sg.mem.nexttargets
		if lasttargets == nil then
			lasttargets, nexttargets = {}, {}
			inst.sg.mem.lasttargets = lasttargets
			inst.sg.mem.nexttargets = nexttargets
		end
	end

	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local dsq = v:GetDistanceSqToPoint(x, y, z)
			if dsq < range * range and inst.components.combat:CanTarget(v) then
				inst.components.combat:DoAttack(v)
				if mult then
					local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					v:PushEvent("knockback", { knocker = inst, radius = radius, strengthmult = strengthmult, forcelanded = forcelanded })
					nexttargets[v] = true
				else
					v:PushEvent("bit_by_shadowthrall_stealth", inst)
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false

	if mult then
		for k in pairs(lasttargets) do
			lasttargets[k] = nil
		end
		inst.sg.mem.lasttargets = nexttargets
		inst.sg.mem.nexttargets = lasttargets
	end
end

local function ResetBiteTargets(inst)
	local lasttargets = inst.sg.mem.lasttargets
	if lasttargets then
		for k in pairs(lasttargets) do
			lasttargets[k] = nil
		end
	end
end

local function TryBiteRange(inst, target)
	if target and target:IsValid() then
		local x, y, z = inst.Transform:GetWorldPosition()
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local dx = x1 - x
		local dz = z1 - z
		local dsq = dx * dx + dz * dz
		if dsq < 100 then
			local rot = inst.Transform:GetRotation()
			local rot1 = dsq > 0 and math.atan2(-dz, dx) * RADIANS or rot
			local diff = ReduceAngle(rot1 - rot)
			local absdiff = math.abs(diff)
			if absdiff < 90 then
				inst.Transform:SetRotation(rot + math.clamp(diff, -45, 45))
				return absdiff < 60
			end
		end
	end
	return false
end

local function SetSpawnShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(1.5 * scale, scale)
end

local function StealthOnUpdateTracking(inst)
	local target = inst.sg.statemem.target
	if target then
		if target:IsValid() then
			local x, y, z = inst.Transform:GetWorldPosition()
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			if (x == x1 and z == z1) or inst.sg.statemem.ease <= 0 then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			else
				local dx = x1 - x
				local dz = z1 - z
				local dist = math.sqrt(dx * dx + dz * dz)
				local speed = math.min(9, dist * inst.sg.statemem.ease)
				inst.Physics:SetMotorVelOverride(speed, 0, 0)
				inst.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
			end
			inst.sg.statemem.ease = inst.sg.statemem.ease  * 0.9
		else
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.sg.statemem.target = nil
		end
	end
end

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, looped)
			if inst.sg.mem.enterstealth then
				inst.sg:GoToState("stealth_on")
				return
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation(looped and "idle_2" or "idle")
			for i = 1, math.random(2) - (looped and 0 or 1) do
				inst.AnimState:PushAnimation("idle", false)
			end
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle", true)
				end
			end),
		},
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/hit")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				if inst.sg.statemem.doattack then
					if ChooseAttack(inst, inst.sg.statemem.doattack) then
						return
					end
					inst.sg.statemem.dotattack = nil
				end
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.doattack = data
					return true
				end
			end),
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

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("death")
			inst.SoundEmitter:PlaySound("rifts2/thrall_generic/vocalization_death")
			inst.SoundEmitter:PlaySound("rifts2/thrall_generic/death_cloth")
		end,

		timeline =
		{
			FrameEvent(18, function(inst) inst.DynamicShadow:SetSize(1.7, 1) end),
			FrameEvent(19, RemovePhysicsColliders),
			FrameEvent(20, function(inst) SetSpawnShadowScale(inst, 1) end),
			FrameEvent(46, function(inst)
				SetSpawnShadowScale(inst, .75)
				inst.SoundEmitter:PlaySound("rifts2/thrall_generic/death_pop")
			end),
			FrameEvent(48, function(inst) SetSpawnShadowScale(inst, .5) end),
			FrameEvent(50, function(inst) SetSpawnShadowScale(inst, .25) end),
			FrameEvent(51, function(inst) inst.DynamicShadow:Enable(false) end),
			FrameEvent(53, function(inst)
				local pos = inst:GetPosition()
				pos.y = 3
				inst.components.lootdropper:DropLoot(pos)
				inst:AddTag("NOCLICK")
				inst.persists = false
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
	},

	State{
		name = "taunt",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("taunt")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/taunt")
			local target = inst.components.combat.target
			if target then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			FrameEvent(27, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			FrameEvent(51, function(inst)
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
		name = "leap_pre",
		tags = { "busy" },

		onenter = function(inst, targetorpos)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("leap_pre")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/jump_lp", "loop")
			if targetorpos and targetorpos:is_a(Vector3) then
				inst.sg.statemem.targetpos = targetorpos
				inst:ForceFacePoint(inst.sg.statemem.targetpos)
			elseif targetorpos:IsValid() then
				inst.sg.statemem.target = targetorpos
				inst.sg.statemem.targetpos = targetorpos:GetPosition()
				inst:ForceFacePoint(inst.sg.statemem.targetpos)
			end
		end,

		onupdate = function(inst)
			local target = inst.sg.statemem.target
			if target then
				if target:IsValid() then
					local pos = inst.sg.statemem.targetpos
					pos.x, pos.y, pos.z = target.Transform:GetWorldPosition()
				else
					target = nil
				end
			end
		end,

		timeline =
		{
			FrameEvent(12, ToggleOffAllObjectCollisions),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.leaping = true

					local pos = inst.sg.statemem.targetpos
					if pos then
						local x, y, z = inst.Transform:GetWorldPosition()
						local dx = pos.x - x
						local dz = pos.z - z
						pos.y = 0

						local target = inst.sg.statemem.target
						if target and target:IsValid() then
							local minspacing = inst:GetPhysicsRadius(0) + target:GetPhysicsRadius(0)
							for gap = 2, 0, -1 do
								local spacing = minspacing + gap
								local x1, z1
								if dx ~= 0 or dz ~= 0 then
									local normalizetospacing = spacing / math.sqrt(dx * dx + dz * dz)
									x1 = pos.x + normalizetospacing * dx
									z1 = pos.z + normalizetospacing * dz
								else
									local theta = inst.Transform:GetRotation() * DEGREES
									x1 = pos.x + math.cos(theta) * spacing
									z1 = pos.z - math.sin(theta) * spacing
								end
								if TheWorld.Map:IsAboveGroundAtPoint(x1, 0, z1) and
									TheWorld.Pathfinder:IsClear(x1, 0, z1, pos.x, 0, pos.z, { ignorecreep = true })
								then
									pos.x, pos.z = x1, z1
									break
								end
							end
						end
						if dx ~= 0 or dz ~= 0 then
							inst.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
						end

						inst.sg:GoToState("leap", { target = target, targetpos = pos })
					else
						inst.sg:GoToState("leap")
					end
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.leaping then
				local x, y, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
				inst:ClearBiteTarget()
				inst.SoundEmitter:KillSound("loop")
			end
		end,
	},

	State{
		name = "leap",
		tags = { "busy", "jumping", "temp_invincible" },

		onenter = function(inst, data)
			inst.components.timer:StopTimer("leap_cd")
			inst.components.timer:StartTimer("leap_cd", TUNING.SHADOWTHRALL_MOUTH_LEAP_COOLDOWN)
			inst.components.locomotor:Stop()
			inst:Hide()
			inst.DynamicShadow:Enable(false)
			ToggleOffAllObjectCollisions(inst)

			local x, y, z = inst.Transform:GetWorldPosition()

			inst.dupe.Physics:Teleport(x, y, z)
			inst.dupe.AnimState:PlayAnimation("leap")
			inst.dupe:ReturnToScene()

			local rot
			if data then
				inst.sg.statemem.target = data.target

				local pos = data.targetpos
				if pos then
					local dx = pos.x - x
					local dz = pos.z - z
					if dx ~= 0 or dz ~= 0 then
						rot = math.atan2(-dz, dx) * RADIANS
						inst.Transform:SetRotation(rot)

						local dist = math.sqrt(dx * dx + dz * dz)
						dist = math.min(8, dist)
						inst.dupe.Physics:SetMotorVelOverride(dist / inst.dupe.AnimState:GetCurrentAnimationLength(), 0, 0)
					end
				end
			end

			inst.dupe.Transform:SetRotation(rot or inst.Transform:GetRotation())
		end,

		events =
		{
			EventHandler("dupe_animover", function(inst)
				if inst.dupe.AnimState:AnimDone() then
					inst.sg.statemem.landing = true
					inst.sg:GoToState("land", inst.sg.statemem.target)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.landing then
				inst:ClearBiteTarget()
			end
			inst.dupe.Physics:ClearMotorVelOverride()
			inst.dupe.Physics:Stop()
			inst.dupe:RemoveFromScene()

			inst.SoundEmitter:KillSound("loop")

			local x, y, z = inst.dupe.Transform:GetWorldPosition()
			ToggleOnAllObjectCollisionsAt(inst, x, z)

			inst:Show()
			inst.DynamicShadow:Enable(true)
		end,
	},

	State{
		name = "land",
		tags = { "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("land")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/jump_land")

			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target:GetPosition())
			end
			inst.components.combat:SetDefaultDamage(TUNING.SHADOWTHRALL_MOUTH_LEAP_DAMAGE)
			inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_MOUTH_LEAP_PLANAR_DAMAGE)
			DoAOEAttack(inst, 1.2, 0.6, 0.6, true)
			inst.components.combat:SetDefaultDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_DAMAGE)
			inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_MOUTH_BITE_PLANAR_DAMAGE)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				if not inst.components.combat:InCooldown() then
					local target = inst.sg.statemem.target
					if TryBiteRange(inst, target) and inst:IsNear(target, 6) and inst:TryRegisterBiteTarget(target) then
						inst.sg.statemem.biting = true
						if inst.sg.mem.lasttargets[target] then
							inst.sg:GoToState("bite_final")
						else
							inst.sg:GoToState("bite_loop", { target = target })
						end
					end
				end
			end),
			FrameEvent(11, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(13, function(inst)
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
			if not inst.sg.statemem.biting then
				ResetBiteTargets(inst)
				inst:ClearBiteTarget()
			end
		end,
	},

	State{
		name = "bite_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("bite_pre")
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.Transform:SetRotation(inst:GetAngleToPoint(target.Transform:GetWorldPosition()))
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.biting = true
					if TryBiteRange(inst, inst.sg.statemem.target) then
						inst.sg:GoToState("bite_loop", { target = inst.sg.statemem.target })
						return
					end
					inst.sg:GoToState("bite_final")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.biting then
				inst:ClearBiteTarget()
			end
		end,
	},

	State{
		name = "bite_loop",
		tags =  { "attack", "busy", "jumping" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("bite_loop")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/bite")
			inst.Physics:SetMotorVelOverride(8, 0, 0)
			if data then
				inst.sg.statemem.loops = data.loops
				inst.sg.statemem.target = data.target
			end
		end,

		timeline =
		{
			FrameEvent(6, DoBiteAOEAttack),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVelOverride(6, 0, 0) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(4, 0, 0) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVelOverride(2, 0, 0) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVelOverride(1, 0, 0) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVelOverride(0.5, 0, 0) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVelOverride(0.25, 0, 0) end),
			FrameEvent(13, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.biting = true
					local target = inst.sg.statemem.target
					if target and TryBiteRange(inst, target) and not inst.sg.mem.lasttargets[target] then
						local loops = inst.sg.statemem.loops or 0
						if loops < MAX_BITES - 2 then
							inst.sg:GoToState("bite_loop", {
								loops = loops + 1,
								target = target,
							})
							return
						end
					end
					inst.sg:GoToState("bite_final")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.biting then
				ResetBiteTargets(inst)
				inst:ClearBiteTarget(TUNING.SHADOWTHRALL_MOUTH_BITE_GROUP_PERIOD)
			end
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

	State{
		name = "bite_final",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("bite_final")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/bite")
			inst.Physics:SetMotorVelOverride(8, 0, 0)
		end,

		timeline =
		{
			FrameEvent(6, DoBiteAOEAttack),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVelOverride(6, 0, 0) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(4, 0, 0) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVelOverride(2, 0, 0) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVelOverride(1, 0, 0) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVelOverride(0.5, 0, 0) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVelOverride(0.25, 0, 0) end),
			FrameEvent(13, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("bite_pst")
				end
			end),
		},

		onexit = function(inst)
			ResetBiteTargets(inst)
			inst:ClearBiteTarget(TUNING.SHADOWTHRALL_MOUTH_BITE_GROUP_PERIOD)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

	State{
		name = "bite_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("bite_pst")
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
		name = "spawndelay",
		tags = { "stealth", "busy", "noattack", "temp_invincible", "invisible" },

		onenter = function(inst, delay)
			inst.components.locomotor:Stop()
			inst.Physics:SetActive(false)
			inst:Hide()
			inst:AddTag("NOCLICK")
			inst.sg:SetTimeout(delay or 0)
		end,

		ontimeout = function(inst)
			inst.sg.statemem.spawning = true
			inst.sg:GoToState("stealth_idle")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.spawning then
				inst:Show()
			end
			inst.Physics:SetActive(true)
			inst:RemoveTag("NOCLICK")
		end,
	},

	State{
		name = "stealth_idle",
		tags = { "stealth", "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:Hide()
		end,

		onexit = function(inst)
			if not inst.sg.statemem.stayhidden then
				inst:Show()
			end
		end,
	},

	State{
		name = "stealth_move",
		tags = { "stealth", "moving", "canrotate" },

		onenter = function(inst)
			inst:Hide()
			inst.components.locomotor:WalkForward()
		end,

		onexit = function(inst)
			if not inst.sg.statemem.stayhidden then
				inst:Show()
			end
		end,
	},

	State{
		name = "stealth_smile",
		tags = { "stealth", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("stalk_smile_pre")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/stealth_appear")
			inst.components.combat:StartAttack()

			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.Physics:Teleport(target.Transform:GetWorldPosition())
				inst.sg.statemem.ease = 30
			end
		end,

		onupdate = StealthOnUpdateTracking,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stalking = true
					local target = inst.sg.statemem.target
					if not (target and target:IsValid()) then
						inst.Physics:ClearMotorVelOverride()
						inst.Physics:Stop()
						inst.sg:GoToState("stealth_pst")
					else
						inst.sg:GoToState(
							inst:IsNear(target, 8) and "stealth_bite" or "stealth_pst",
							{ target = target, ease = inst.sg.statemem.ease }
						)
					end
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.stalking then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst:ClearBiteTarget()
			end
		end,
	},

	State{
		name = "stealth_bite",
		tags = { "stealth", "attack", "busy" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("stalk_bite")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/stealth_bite_f0")
			if data then
				inst.sg.statemem.target = data.target
				inst.sg.statemem.ease = data.ease
			end
		end,

		onupdate = StealthOnUpdateTracking,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg.statemem.target = nil
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end),
			FrameEvent(18, function(inst) inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/stealth_bite_f18") end),
			FrameEvent(22, function(inst)
				DoAOEAttack(inst, 1.5)
				inst:ClearBiteTarget(TUNING.SHADOWTHRALL_MOUTH_STEALTH_ATTACK_GROUP_PERIOD)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.stalking = true
					inst.sg:GoToState("stealth_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			if not inst.sg.statemem.stalking then
				inst:ClearBiteTarget()
			end
		end,
	},

	State{
		name = "stealth_pst",
		tags = { "stealth", "busy" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("stalk_smile_pst")
			if data then
				inst.sg.statemem.target = data.target
				inst.sg.statemem.ease = data.ease
			end
		end,

		onupdate = StealthOnUpdateTracking,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stealth_idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst:ClearBiteTarget()
		end,
	},

	State{
		name = "stealth_on",
		tags = { "stealth", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("stealth_on")
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/enter_stealth")
			inst.sg.mem.enterstealth = nil
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stealth_pst")
				end
			end),
		},
	},

	State{
		name = "stealth_hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("stealth_off_pre")
			inst.AnimState:PushAnimation("stealth_off_loop")
			inst.AnimState:PushAnimation("stealth_off_loop")
			inst.AnimState:PushAnimation("stealth_off_loop", false)
			inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/hit")
		end,

		timeline =
		{
			FrameEvent(28, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stealth_hit_pst")
				end
			end),
		},
	},

	State{
		name = "stealth_hit_pst",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("stealth_off_pst")
		end,

		timeline =
		{
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
}

return StateGraph("shadowthrall_mouth", states, events, "idle")
