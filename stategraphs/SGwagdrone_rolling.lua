require("stategraphs/commonstates")

local easing = require("easing")
local WagdroneCommon = require("prefabs/wagdrone_common")

local function ResetWorkSlowdown(inst)
	inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "work_slowdown")
	inst.sg.mem.work_slowdown_t = nil
end

local function DoForcedSpinningRecoil(inst, target, radius)
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local dx = x1 - x
	local dz = z1 - z

	local recoilangle = (dx ~= 0 or dz ~= 0) and math.atan2(dz, -dx) or math.random() * TWOPI

	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < radius then
		x = x1 + math.cos(recoilangle) * radius
		z = z1 - math.sin(recoilangle) * radius
		inst.Physics:Teleport(x, 0, z)
	end

	SpawnPrefab("wagdrone_rolling_collide_small_fx").Transform:SetPosition(x + dx / dist, 1, z + dz / dist)

	ResetWorkSlowdown(inst)
	inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
	inst:PushEvent("spinning_recoil", recoilangle)
end

local events =
{
	EventHandler("locomote", function(inst)
		if inst.sg.mem.todespawn then
			return
		elseif not inst.sg:HasAnyStateTag("stationary", "broken", "off") then
			if inst.components.locomotor:WantsToMoveForward() then
				if inst.sg:HasStateTag("idle") then
					inst.sg.statemem.keep_idle_loop = true
					inst.sg:GoToState("run_start")
				end
			elseif inst.sg:HasStateTag("moving") then
				inst.sg.statemem.running = true
				inst.sg:GoToState("run_stop", inst.sg.statemem.targets)
			end
		end
	end),
	EventHandler("attacked", function(inst)
		if inst.components.health.currenthealth <= inst.components.health.minhealth then
			if not inst.sg:HasStateTag("broken") then
				inst.sg:GoToState(inst.sg:HasStateTag("stationary") and "stationary_broken" or "broken")
			end
		elseif not inst.sg:HasAnyStateTag("busy", "nointerrupt") or inst.sg:HasStateTag("caninterrupt") then
			inst.sg:GoToState(inst.sg:HasStateTag("stationary") and "stationary_hit" or "hit")
		end
	end),
	EventHandler("minhealth", function(inst)
		if inst.components.health.currenthealth <= inst.components.health.minhealth then
			if not inst.sg:HasStateTag("broken") then
				inst.sg:GoToState(inst.sg:HasStateTag("stationary") and "stationary_broken" or "broken")
			end
		end
	end),
	EventHandler("activate", function(inst)
		if inst.sg.mem.todespawn then
			return
		end
		inst.sg.mem.turnoff = nil
		if inst.sg:HasStateTag("off") then
			if not inst.sg:HasStateTag("busy") then
				inst.sg:GoToState("turnon")
			else
				inst.sg.mem.turnon = true
			end
		end
	end),
	EventHandler("deactivate", function(inst)
		inst.sg.mem.turnon = nil
		inst.sg.mem.tostationary = nil
		inst.sg.mem.tomobile = nil
		if inst.components.floater:IsFloating() then
			if inst.sg.currentstate.name ~= "off_idle" then
				inst.sg:GoToState("off_idle")
			end
		elseif not inst.sg:HasStateTag("off") then
			if not inst.sg:HasAnyStateTag("busy", "broken") then
				if inst.sg:HasStateTag("stationary") then
					inst.sg.mem.turnoff = true
					inst.sg:GoToState("transform_to_mobile")
				else
					inst.sg:GoToState("turnoff")
				end
			else
				inst.sg.mem.turnoff = true
			end
		end
	end),
	EventHandler("despawn", function(inst)
		inst.sg.mem.todespawn = true
		inst.sg.mem.turnon = nil
		inst.sg.mem.tostationary = nil
		inst.sg.mem.tomobile = nil
		if not inst.sg:HasStateTag("off") then
			if not inst.sg:HasAnyStateTag("busy", "broken") then
				if inst.sg:HasStateTag("stationary") then
					inst.sg.mem.turnoff = true
					inst.sg:GoToState("transform_to_mobile")
				else
					inst.sg:GoToState("turnoff")
				end
			else
				inst.sg.mem.turnoff = true
			end
		end
	end),
	EventHandler("transform_to_stationary", function(inst)
		if not (inst.sg.mem.turnoff or inst.sg:HasAnyStateTag("off")) then
			inst.sg.mem.tomobile = nil
			if not inst.sg:HasStateTag("stationary") then
				if not inst.sg:HasAnyStateTag("busy", "broken") then
					inst.sg:GoToState("transform_to_stationary")
				else
					inst.sg.mem.tostationary = true
				end
			end
		end
	end),
	EventHandler("transform_to_mobile", function(inst)
		if not (inst.sg.mem.turnoff and inst.sg:HasStateTag("off")) then
			inst.sg.mem.tostationary = nil
			if inst.sg:HasStateTag("stationary") then
				if not inst.sg:HasAnyStateTag("busy", "broken") then
					inst.sg:GoToState("transform_to_mobile")
				else
					inst.sg.mem.tomobile = true
				end
			end
		end
	end),
	EventHandler("forced_spinning_recoil", function(inst, data)
		if inst.sg:HasStateTag("running") then
			DoForcedSpinningRecoil(inst, data.target, data.radius)
		end
	end),
}

--------------------------------------------------------------------------

local SPIN_RADIUS = 1
local SPIN_RANGE_PADDING = 3
local SPIN_WORK_ACTIONS =
{
	CHOP = true,
	HAMMER = true,
	MINE = true,
}
local REGISTERED_SPIN_TAGS

local function DoSpinningAOE(inst, targets)
	local friendly = WagdroneCommon.IsFriendly(inst)
	if REGISTERED_SPIN_TAGS == nil then
		local tags = { "_combat", "pickable" }
		for k, v in pairs(SPIN_WORK_ACTIONS) do
			table.insert(tags, k.."_workable")
		end
		REGISTERED_SPIN_TAGS = TheSim:RegisterFindTags(
			nil,
			{ "INLIMBO", "flight", "invisible", "notarget", "noattack", "NOCLICK", "wagboss" },
			tags
		)
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	local t = GetTime()
	local speedmult = 1
	local recoilangle
	local bbladecollide
	local numuses = 0
	for i, v in ipairs(TheSim:FindEntities_Registered(x, y, z, SPIN_RADIUS + SPIN_RANGE_PADDING, REGISTERED_SPIN_TAGS)) do
		if v ~= inst and (targets[v] or 0) <= t and v:IsValid() and not v:IsInLimbo() then
			local isbblade = v.prefab == inst.prefab
			local range = SPIN_RADIUS + (isbblade and SPIN_RADIUS or v:GetPhysicsRadius(0))
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			local dsq = dx * dx + dz * dz
			if dsq < range * range then
				local worked, recoil
				if v.components.workable then
					if v.components.workable:CanBeWorked() and not (v.sg and v.sg:HasStateTag("busy")) then
						local work_action = v.components.workable:GetWorkAction()
						local slowdown, spark
						if v:HasAnyTag("waxedplant", "event_trigger") then
							if work_action and SPIN_WORK_ACTIONS[work_action.id] then
								recoil = true
								targets[v] = t + 0.5
								spark = true
								worked = true
							end
						elseif work_action == ACTIONS.CHOP then
							v.components.workable:WorkedBy(inst, 1.5)
							numuses = numuses + 1
							targets[v] = t + 0.2
							worked = true
							if v:IsValid() and
								v.components.workable and
								v.components.workable:GetWorkAction() == ACTIONS.CHOP and
								v.components.workable:CanBeWorked()
							then
								slowdown = true
							end
						elseif work_action == ACTIONS.MINE then
							if v:HasTag("frozen") then
								PlayMiningFX(inst, v)
								v.components.workable:WorkedBy(inst, 0.5)
								numuses = numuses + 1
								if v:IsValid() and v.components.workable:CanBeWorked() then
									slowdown = true
								end
								targets[v] = t + 0.2
							elseif math.random() < 0.5 then
								PlayMiningFX(inst, v)
								v.components.workable:WorkedBy(inst, 0.5)
								numuses = numuses + 1
								if v:IsValid() and v.components.workable:CanBeWorked() then
									recoil = true
								end
								targets[v] = t + 0.5
								spark = true
							else
								recoil = true
								targets[v] = t + 0.5
								spark = true
							end
							worked = true
						elseif work_action == ACTIONS.HAMMER then
							if friendly then
								recoil = true
								targets[v] = t + 0.5
								spark = true
							else
								local mult =
									(v:HasTag("grass") and 2) or
									(v:HasTag("wood") and 1.5) or
									(v:HasTag("wall") and 1) or
									0.5

								v.components.workable:WorkedBy(inst, mult)
								numuses = numuses + 1
								if v:IsValid() and v.components.workable and v.components.workable:CanBeWorked() then
									if mult > 1 then
										slowdown = true
									else
										recoil = true
									end
								end
								spark = mult <= 1
								targets[v] = t + 0.2--(slowdown and 0.2 or 0.5)
							end
							worked = true
						end
						if slowdown then
							if dx == 0 and dz == 0 then
								speedmult = 0.1
							else
								local rot1 = math.atan2(-dz, dx)
								local diff = DiffAngleRad(rot, rot1)
								local mult = easing.inQuad(diff, 0.1, 1, math.pi)
								speedmult = speedmult < 0 and mult or math.min(speedmult, mult)
							end
						end
						if spark then
							local fx = SpawnPrefab("wagdrone_rolling_collide_med_fx")
							if dsq == 0 then
								local theta = math.random() * TWOPI
								local rad = math.random() * SPIN_RADIUS * 0.6
								fx.Transform:SetPosition(x + math.cos(theta) * rad, 0, z - math.sin(theta) * rad)
							else
								local d = SPIN_RADIUS / math.sqrt(dsq)
								fx.Transform:SetPosition(x + dx * d, 0, z + dz * d)
							end
						end
					end
				end

				if not worked then
					if isbblade then
						if v.sg:HasStateTag("running") then
							SpawnPrefab("wagdrone_rolling_collide_small_fx").Transform:SetPosition((x + x1) / 2, 1, (z + z1) / 2)
							recoil = true
							bbladecollide = true
							targets[v] = t + 0.5
						end
					elseif v.components.pickable then
						if v.components.pickable:CanBePicked() and not v:HasTag("intense") then
							local success, loots = v.components.pickable:Pick(inst)
							if success then
								if loots then
									for _, loot in ipairs(loots) do
										if loot.components.inventoryitem and not loot.components.inventoryitem:IsHeld() then
											local x2, y2, z2 = loot.Transform:GetWorldPosition()
											loot.components.inventoryitem:DoDropPhysics(x2, y2, z2, true)
										end
										targets[loot] = t + 0.5
									end
								end
								targets[v] = t + 0.3
							end
						end
					elseif friendly and not v:HasTag("hostile") and
						not (	v.components.combat and v.components.combat.target and
								(	v.components.combat.target.isplayer or
									(	v.components.combat.target.components.follower and
										v.components.combat.target.components.follower:GetLeader() and
										v.components.combat.target.components.follower:GetLeader().isplayer
									)
								)
							)
					then
						--skip these non hostile targets
					elseif v.components.inventory and v.components.inventory:EquipHasTag("hardarmor") then
						local fx = SpawnPrefab("wagdrone_rolling_collide_small_fx")
						if dsq == 0 then
							local theta = math.random() * TWOPI
							local rad = math.random() * SPIN_RADIUS * 0.6
							fx.Transform:SetPosition(x + math.cos(theta) * rad, 0, z - math.sin(theta) * rad)
						else
							local d = SPIN_RADIUS / math.sqrt(dsq)
							fx.Transform:SetPosition(x + dx * d, 0, z + dz * d)
						end
						if v.components.combat and inst.components.combat:CanTarget(v) then
							if not (v.components.health and v.components.health:IsDead()) and
								math.random() < TUNING.WAGDRONE_ROLLING_HARDARMOR_BOUNCE_CHANCE
							then
								inst.components.combat:DoAttack(v)
								numuses = numuses + 1
							elseif v.components.freezable and v.components.freezable:IsFrozen() then
								v:PushEvent("attacked", { attacker = inst, damage = 0 })
								numuses = numuses + 1
							end
						end
						recoil = true
						targets[v] = t + 0.5
					elseif v.components.combat then
						if not (v.components.health and v.components.health:IsDead()) and inst.components.combat:CanTarget(v) then
							inst.components.combat:DoAttack(v)
							numuses = numuses + 1
							targets[v] = t + 0.5
						end
					end
				end

				if recoil and (speedmult == 1 or isbblade) and (dx ~= 0 or dz ~= 0) then
					local rot1 = math.atan2(-dz, dx)
					local diff = ReduceAngleRad(rot - rot1)
					rot1 = rot1 - diff + math.pi
					if recoilangle then
						diff = ReduceAngleRad(rot1 - recoilangle)
						recoilangle = ReduceAngleRad(recoilangle + diff / 2)
					else
						recoilangle = ReduceAngleRad(rot1)
					end
				end
			end
		end
	end

	--Add recoil when work fails.
	--Add a bit of resistance when work succeeds, so we can get more works in b4 passing through.
	if recoilangle and (speedmult == 1 or bbladecollide) then
		ResetWorkSlowdown(inst)
		inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
		inst:PushEvent("spinning_recoil", recoilangle)
	elseif speedmult < 1 then
		if distsq(x, z, inst.sg.mem.lastx, inst.sg.mem.lastz) < 0.25 then
			local k = Remap(speedmult, 0.1, 1, 0.6, 0.1)
			inst.sg.mem.lastx = inst.sg.mem.lastx * k + x * (1 - k)
			inst.sg.mem.lastz = inst.sg.mem.lastz * k + z * (1 - k)
			inst.Transform:SetPosition(inst.sg.mem.lastx, 0, inst.sg.mem.lastz)
			inst.components.locomotor:SetExternalSpeedMultiplier(inst, "work_slowdown", speedmult)
			inst.sg.mem.work_slowdown_t = t + 0.2
		else
			ResetWorkSlowdown(inst)
			inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
		end
	elseif inst.sg.mem.work_slowdown_t then
		if inst.sg.mem.work_slowdown_t < t then
			ResetWorkSlowdown(inst)
			inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
		end
	else
		inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
	end

	if numuses > 0 and inst.components.finiteuses then
		inst.components.finiteuses:Use(numuses)
	end
end

local function ResetWorkSlowdown(inst)
	inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "work_slowdown")
	inst.sg.mem.work_slowdown_t = nil
end

--------------------------------------------------------------------------

local function SetShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(1.05 * scale, 0.7 * scale)
end

local states =
{
	--------------------------------------------------------------------------
	--Mobile mode

	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			if inst.sg.mem.turnoff then
				inst.sg:GoToState("turnoff")
				return
			elseif inst.sg.mem.tostationary then
				inst.sg:GoToState("transform_to_stationary")
				return
			end
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle1", true)
			local loops = math.random(4, 7)
			local len = inst.AnimState:GetCurrentAnimationLength()
			local timeout = len * loops
			if POPULATING then
				local starttime = math.random() * len
				inst.AnimState:SetTime(starttime)
				timeout = timeout - starttime
			end
			inst.sg:SetTimeout(timeout)
			if not inst.SoundEmitter:PlayingSound("idle") then
				inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_LP", "idle")
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.keep_idle_loop = true
			inst.sg:GoToState("idle_wobble")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keep_idle_loop then
				inst.SoundEmitter:KillSound("idle")
			end
		end,
	},

	State{
		name = "idle_wobble",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle_wobble_pre")
			if not inst.SoundEmitter:PlayingSound("idle") then
				inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_LP", "idle")
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keep_idle_loop = true
					inst.sg:GoToState("wobble")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keep_idle_loop then
				inst.SoundEmitter:KillSound("idle")
			end
		end,
	},

	State{
		name = "wobble",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle1_wobble")
			if not inst.SoundEmitter:PlayingSound("idle") then
				inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_LP", "idle")
			end
			if inst.sg.mem.turnoff or inst.sg.mem.tostationary then
				inst.sg:RemoveStateTag("idle")
				inst.sg:AddStateTag("busy")
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/wobble") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keep_idle_loop = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keep_idle_loop then
				inst.SoundEmitter:KillSound("idle")
			end
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("hit1")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(10, function(inst)
				if inst.sg.mem.turnoff then
					inst.sg:GoToState("turnoff")
					return
				elseif inst.sg.mem.tostationary then
					inst.sg:GoToState("transform_to_stationary")
					return
				end
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),

			--#SFX
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_stationary/beep_hurt") end),
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("wobble")
				end
			end),
		},
	},

	State{
		name = "broken",
		tags = { "hit", "busy", "broken", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("broken1")
			ToggleOffAllObjectCollisions(inst)
			inst:SetBrainEnabled(false)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/break") end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/mult_small_misc") end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.broken = true
					inst.sg:GoToState("broken_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.broken then
				local x, y, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
				inst:SetBrainEnabled(true)
			end
		end,
	},

	State{
		name = "broken_idle",
		tags = { "idle", "broken", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("broken_idle1")
			ToggleOffAllObjectCollisions(inst)
			inst:SetBrainEnabled(false)
			if inst.sg.mem.todespawn then
				inst:AddTag("NOCLICK")
				ErodeAway(inst)
			else
				inst.components.health:StartRegen(TUNING.WAGDRONE_ROLLING_REGEN_AMOUNT, TUNING.WAGDRONE_ROLLING_REGEN_PERIOD)
				inst.sg:SetTimeout(TUNING.WAGDRONE_ROLLING_REGEN_PERIOD)
			end
		end,

		ontimeout = function(inst)
			--delayed check for loading
			if not inst.components.health:IsHurt() then
				inst.sg:GoToState("repair")
			end
		end,

		events =
		{
			EventHandler("deactivate", function(inst)
				inst.components.health:SetPercent(1)
			end),
			EventHandler("healthdelta", function(inst, data)
				if data and data.newpercent >= 1 then
					inst.sg:GoToState("repair")
				end
			end),
			EventHandler("despawn", function(inst)
				if not inst.sg.mem.todespawn then
					inst.sg.mem.todespawn = true
					inst.components.health:StopRegen()
					inst:AddTag("NOCLICK")
					ErodeAway(inst)
					return true
				end
			end),
		},

		onexit = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			ToggleOnAllObjectCollisionsAt(inst, x, z)
			inst:SetBrainEnabled(true)
			inst.components.health:StopRegen()
		end,
	},

	State{
		name = "repair",
		tags = { "busy", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("repair1")
		end,

		timeline =
		{
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/repair") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("wobble")
				end
			end),
		},
	},

	State{
		name = "turnoff",
		tags = { "busy", "off", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("turn_off")
			ToggleOffAllObjectCollisions(inst)
			inst:SetBrainEnabled(false)
			inst.sg.mem.turnoff = nil
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/beep_turnoff") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_pst_turnoff") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/wobble") end),
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/wobble") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.off = true
					inst.sg:GoToState("off_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.off then
				local x, y, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
				inst:SetBrainEnabled(true)
			end
		end,
	},

	State{
		name = "off_idle",
		tags = { "idle", "off", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			if inst.components.workable then
				inst.AnimState:PlayAnimation("damaged_idle_loop", true)
			else
				inst.AnimState:PlayAnimation("off_idle")
			end
			ToggleOffAllObjectCollisions(inst)
			if inst.components.inventoryitem and inst.components.inventoryitem:IsHeld() then
				--V2C: -Forced to this state when picked up.
				--     -ToggleOffAllObjectCollisions may teleport to world position, so reset it.
				inst.Transform:SetPosition(0, 0, 0)
			end
			inst:SetBrainEnabled(false)
			WagdroneCommon.SetLedEnabled(inst, false)
			if inst.sg.mem.todespawn then
				inst:AddTag("NOCLICK")
				ErodeAway(inst)
			elseif inst.components.workable then
				inst.components.workable:SetWorkable(true)
			end
		end,

		events =
		{
			EventHandler("despawn", function(inst)
				if not inst.sg.mem.todespawn then
					inst.sg.mem.todespawn = true
					inst:AddTag("NOCLICK")
					ErodeAway(inst)
					return true
				end
			end),
		},

		onexit = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			ToggleOnAllObjectCollisionsAt(inst, x, z)
			inst:SetBrainEnabled(true)
			WagdroneCommon.SetLedEnabled(inst, true)
			if inst.components.workable then
				inst.components.workable:SetWorkable(false)
			end
		end,
	},

	State{
		name = "turnon",
		tags = { "busy", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("turn_on")
			if not inst.SoundEmitter:PlayingSound("idle") then
				inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_LP", "idle")
			end
			inst.sg.mem.turnon = nil
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/idle_pre_turnon") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/beep_turnon") end),
			FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keep_idle_loop = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keep_idle_loop then
				inst.SoundEmitter:KillSound("idle")
			end
		end,
	},

	State{
		name = "transform_to_stationary",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("transform1")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				SetShadowScale(inst, 1.75)
			end),
			FrameEvent(7, function(inst)
				SetShadowScale(inst, 2)
			end),
			FrameEvent(8, function(inst)
				inst.sg.statemem.masszeroed = true
				inst.Physics:SetMass(0)
			end),
			FrameEvent(9, function(inst)
				--inst:AddTag("hostile")
				inst.sg:AddStateTag("stationary")
				inst.sg.mem.tostationary = nil
			end),
			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("canconnect")
				inst:ConnectBeams()
			end),
			FrameEvent(21, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/mult_small_misc") end),
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stationary_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg:HasStateTag("stationary") then
				SetShadowScale(inst, 1)
				if inst.sg.statemem.masszeroed then
					inst.Physics:SetMass(80)
				end
				--inst:RemoveTag("hostile")
			end
		end,
	},

	State{
		name = "run_start",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("run_pre")
			inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/run_LP", "run")
		end,

		onupdate = function(inst)
			local numaccelframes = 8
			local k = inst.sg.statemem.speedk
			if k then
				k = k + 1
				if k < numaccelframes then
					inst.sg.statemem.speedk = k
					k = k / numaccelframes
					inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", k * k)
				else
					inst.sg.statemem.speedk = nil
					inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "run_start")
				end
				inst.components.locomotor:RunForward()
			end
			if inst.sg.statemem.targets then
				DoSpinningAOE(inst, inst.sg.statemem.targets)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst) inst.SoundEmitter:KillSound("idle") end),
			FrameEvent(7, function(inst)
				inst.sg.statemem.speedk = 0
			end),
			FrameEvent(11, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.targets = {}
				ToggleOffCharacterCollisions(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.running = true
					inst.sg:GoToState("run", inst.sg.statemem.targets)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keep_idle_loop then
				inst.SoundEmitter:KillSound("idle")
			end
			if not inst.sg.statemem.running then
				ResetWorkSlowdown(inst)
				ToggleOnCharacterCollisions(inst)
				inst.Transform:SetNoFaced()
				inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
				inst.SoundEmitter:KillSound("run")
			end
		end,
	},

	State{
		name = "run",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst, targets)
			inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "run_start")
			inst.components.locomotor:RunForward()
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("run_loop", true)
			ToggleOffCharacterCollisions(inst)
			if targets then
				inst.sg.statemem.targets = targets
			else
				inst.sg.statemem.targets = {}
				local x, y, z = inst.Transform:GetWorldPosition()
				inst.sg.mem.lastx, inst.sg.mem.lastz = x, z
			end
			if not inst.SoundEmitter:PlayingSound("run") then
				inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/run_LP", "run")
			end
		end,

		onupdate = function(inst)
			DoSpinningAOE(inst, inst.sg.statemem.targets)
		end,

		onexit = function(inst)
			if not inst.sg.statemem.running then
				ResetWorkSlowdown(inst)
				ToggleOnCharacterCollisions(inst)
				inst.Transform:SetNoFaced()
				inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
				inst.SoundEmitter:KillSound("run")
			end
		end,
	},

	State{
		name = "run_stop",
		tags = { "idle" },

		onenter = function(inst, targets)
			inst.components.locomotor:StopMoving()
			inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("run_pst")
			--ToggleOffCharacterCollisions(inst) --don't force it if we reached here without collisions toggled off
			inst.sg.statemem.targets = targets --this can be nil (don't need to force lastx/z in that case)
			inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/run_pst")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.targets then
				DoSpinningAOE(inst, inst.sg.statemem.targets)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.sg.statemem.targets = nil
				inst.SoundEmitter:KillSound("run")
			end),
			FrameEvent(4, ToggleOnCharacterCollisions),
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
			ResetWorkSlowdown(inst)
			ToggleOnCharacterCollisions(inst)
			inst.Transform:SetNoFaced()
			inst.SoundEmitter:KillSound("run")
		end,
	},

	--------------------------------------------------------------------------
	--Stationary mode

	State{
		name = "stationary_idle",
		tags = { "idle", "stationary", "canconnect" },

		onenter = function(inst)
			if inst.sg.mem.turnoff or inst.sg.mem.tomobile then
				inst.sg:GoToState("transform_to_mobile")
				return
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("idle2", true)
			if POPULATING then
				--inst:AddTag("hostile")
				inst.AnimState:SetTime(math.random() * inst.AnimState:GetCurrentAnimationLength())
			end
			if not (inst.sg.lasttags and inst.sg.lasttags["canconnect"]) then
				inst:ConnectBeams()
			end
		end,
	},

	State{
		name = "stationary_hit",
		tags = { "hit", "busy", "stationary", "canconnect" },

		onenter = function(inst)
			if not (inst.sg.lasttags and inst.sg.lasttags["canconnect"]) then
				--interrupted during transform or repair
				inst.sg:RemoveStateTag("canconnect")
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit2")
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				if not inst.sg:HasStateTag("canconnect") then
					inst.sg:AddStateTag("canconnect")
					inst:ConnectBeams()
				end
			end),
			FrameEvent(9, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(11, function(inst)
				if inst.sg.mem.turnoff or inst.sg.mem.tomobile then
					inst.sg:GoToState("transform_to_mobile")
					return
				end
				inst.sg:RemoveStateTag("hit")
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
			end),

			--#SFX
			FrameEvent(0, function (inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_stationary/beep_hurt") end),
			FrameEvent(0, function (inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
			FrameEvent(0, function (inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(0, function (inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(10, function (inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/mult_small_misc") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stationary_idle")
				end
			end),
		},
	},

	State{
		name = "stationary_broken",
		tags = { "hit", "busy", "stationary", "broken", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst:DisconnectBeams()
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("broken2")
			inst:SetBrainEnabled(false)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/mult_small_misc") end),
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/break") end),
			FrameEvent(18, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_stationary/land") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.broken = true
					inst.sg:GoToState("stationary_broken_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.broken then
				inst:SetBrainEnabled(true)
			end
		end,
	},

	State{
		name = "stationary_broken_idle",
		tags = { "idle", "stationary", "broken", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst:DisconnectBeams()
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("broken_idle2")
			--[[if POPULATING then
				inst:AddTag("hostile")
			end]]
			inst:SetBrainEnabled(false)
			if inst.sg.mem.todespawn then
				inst:AddTag("NOCLICK")
				ErodeAway(inst)
			else
				inst.components.health:StartRegen(TUNING.WAGDRONE_ROLLING_REGEN_AMOUNT, TUNING.WAGDRONE_ROLLING_REGEN_PERIOD)
				inst.sg:SetTimeout(TUNING.WAGDRONE_ROLLING_REGEN_PERIOD)
			end
		end,

		ontimeout = function(inst)
			--delayed check for loading
			if not (inst.sg.mem.todespawn or inst.components.health:IsHurt()) then
				inst.sg:GoToState("stationary_repair")
			end
		end,

		events =
		{
			EventHandler("deactivate", function(inst)
				inst.components.health:SetPercent(1)
			end),
			EventHandler("healthdelta", function(inst, data)
				if data and data.newpercent >= 1 then
					inst.sg:GoToState("stationary_repair")
				end
			end),
			EventHandler("despawn", function(inst)
				if not inst.sg.mem.todespawn then
					inst.sg.mem.todespawn = true
					inst.components.health:StopRegen()
					inst:AddTag("NOCLICK")
					ErodeAway(inst)
					return true
				end
			end),
		},

		onexit = function(inst)
			inst:SetBrainEnabled(true)
			inst.components.health:StopRegen()
		end,
	},

	State{
		name = "stationary_repair",
		tags = { "busy", "stationary", "noattack" },

		onenter = function(inst)
			if inst.sg.lasttags and inst.sg.lasttags["canconnect"] then
				inst.sg:AddStateTag("canconnect")
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("repair_2")
		end,

		timeline =
		{
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:AddStateTag("caninterrupt")
				if not inst.sg:HasStateTag("canconnect") then
					inst.sg:AddStateTag("canconnect")
					inst:ConnectBeams()
				end
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_rolling/repair") end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("stationary_idle")
				end
			end),
		},
	},

	State{
		name = "transform_to_mobile",
		tags = { "busy", "stationary" },

		onenter = function(inst)
			inst:DisconnectBeams()
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("transform2")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				SetShadowScale(inst, 1.7)
			end),
			FrameEvent(10, function(inst)
				SetShadowScale(inst, 1.5)
			end),
			FrameEvent(11, function(inst)
				--inst:RemoveTag("hostile")
				inst.sg:RemoveStateTag("stationary")
				inst.sg.mem.tomobile = nil
				SetShadowScale(inst, 1.1)
			end),
			FrameEvent(12, function(inst)
				SetShadowScale(inst, 1)
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.massrestored = true
				inst.Physics:SetMass(80)
			end),
			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("TODO") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("wobble")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("stationary") then
				SetShadowScale(inst, 2)
			else
				SetShadowScale(inst, 1)
				if not inst.sg.statemem.massrestored then
					inst.Physics:SetMass(80)
				end
			end
		end,
	},
}

return StateGraph("wagdrone_rolling", states, events, "off_idle")
