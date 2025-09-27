require("stategraphs/commonstates")

local WagdroneCommon = require("prefabs/wagdrone_common")

local events =
{
	EventHandler("locomote", function(inst)
		if inst.sg.mem.todespawn then
			return
		elseif not inst.sg:HasStateTag("off") then
			if inst.components.locomotor:WantsToMoveForward() then
				if inst.sg:HasStateTag("idle") then
					inst.sg:GoToState("run_start")
				end
			elseif inst.sg:HasStateTag("moving") then
				inst.sg.statemem.running = true
				inst.sg:GoToState("run_stop")
			end
		end
	end),
	EventHandler("doattack", function(inst)
		if not inst.sg:HasAnyStateTag("off", "busy") then
			inst.sg:GoToState("attack")
		end
	end),
	EventHandler("activate", function(inst, commander)
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
		if not inst.sg:HasStateTag("off") then
			if not inst.sg:HasStateTag("busy") then
				inst.sg:GoToState("turnoff")
			else
				inst.sg.mem.turnoff = true
			end
		end
	end),
	EventHandler("despawn", function(inst)
		inst.sg.mem.todespawn = true
		inst.sg.mem.turnon = nil
		if not inst.sg:HasStateTag("off") then
			if not inst.sg:HasStateTag("busy") then
				inst.sg:GoToState("turnoff")
			else
				inst.sg.mem.turnoff = true
			end
		end
	end),
}

--------------------------------------------------------------------------

local function IsPaused(inst)
	return inst:IsAsleep()-- or inst:IsInLimbo()
end

local function UpdateIdleHover(inst, dt)
	if IsPaused(inst) then
		return
	end

	local period = 1.2
	local amp = 0.4
	local ht0 = 5
	local liftoff_period = period * 2

	local x, y, z = inst.Transform:GetWorldPosition()
	local t = inst.sg.statemem.t
	if t == nil then
		if y < 0.5 then
			--liftoff: start from bottom of sin wave
			amp = ht0
			period = liftoff_period
			if y <= 0 then
				y = 0.01
				inst.Physics:Teleport(x, y, z)
			end
			t = math.asin((y - ht0) / amp) * period / TWOPI
		elseif y < ht0 - amp - 0.5 then
			t = 0.75 * period
		else
			t = math.random() * period
		end
		t = t + dt
	else
		t = t + dt
		if t < 0 then
			--lifting off
			amp = ht0
			period = liftoff_period
		end
	end

	local ht = ht0 + math.sin(t * TWOPI / period) * amp
	local yspeed = (ht - y) * 15

	inst.Physics:SetMotorVel(0, yspeed, 0)
	inst.sg.statemem.t = t
end

local function UpdateRunHover(inst, dt)
	if IsPaused(inst) then
		return
	end

	local period = 18 * FRAMES
	local amp = 0.2
	local ht0 = 5
	local dip_amp = 0.8
	local dip_ht0 = 5

	local t = inst.sg.statemem.t
	if t == nil then
		--dip a bit at run_start
		amp = dip_amp
		ht0 = dip_ht0
		period = period * 2
		t = -0.5 * period + dt
	else
		t = t + dt
		if t < 0 then
			period = period * 2
			if t < -0.25 * period then
				--dipping at run_start
				amp = dip_amp
				ht0 = dip_ht0
			else
				--bouncing up to running height
				amp = ht0 - (dip_ht0 - dip_amp)
			end
		end
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local ht = ht0 + math.sin(t * TWOPI / period) * amp
	local yspeed = (ht - y) * 15

	inst.components.locomotor:RunForward()
	local vx, vy, vz = inst.Physics:GetMotorVel()
	inst.Physics:SetMotorVel(vx, yspeed, vz)
	inst.sg.statemem.t = t
end

local function UpdateRunStopHover(inst, dt)
	if IsPaused(inst) then
		return
	end

	local period = 1.2
	local amp = 0.4
	local ht0 = 5
	local dip_period = 18 * FRAMES
	local dip_amp = 0.55
	local dip_ht0 = 5

	local t = inst.sg.statemem.t
	if t == nil then
		--dip a bit at run_stop
		amp = dip_amp
		ht0 = dip_ht0
		period = dip_period
		t = -0.5 * period + dt
	else
		t = t + dt
		if t < 0 then
			period = dip_period
			if t < -0.25 * period then
				--dipping at run_stop
				amp = dip_amp
				ht0 = dip_ht0
			else
				--bouncing up to idle height
				amp = ht0 - (dip_ht0 - dip_amp)
			end
		end
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local ht = ht0 + math.sin(t * TWOPI / period) * amp
	local yspeed = (ht - y) * 15

	inst.Physics:SetMotorVel(0, yspeed, 0)
	inst.sg.statemem.t = t
end

local function UpdateLanding(inst, dt)
	if IsPaused(inst) then
		return
	end

	local len = 26 * FRAMES
	local t = inst.sg.statemem.t
	if t ~= math.huge then
		local yspeed, g
		if t == nil then
			local x, y, z = inst.Transform:GetWorldPosition()
			local vx, vy, vz = inst.Physics:GetMotorVel()
			--local vyf = -y * 2 / len - vy
			--g = (vyf - vy) / len
			g = -2 * (y / len + vy) / len
			yspeed = vy
			inst.sg.statemem.g = g
			t = 0
		else
			yspeed = inst.sg.statemem.yspeed
			g = inst.sg.statemem.g
		end

		t = t + dt
		if t < len then
			yspeed = yspeed + g * dt
			inst.Physics:SetMotorVel(0, yspeed, 0)
			inst.sg.statemem.t = t
			inst.sg.statemem.yspeed = yspeed
		else
			local x, y, z = inst.Transform:GetWorldPosition()
			inst.Physics:Stop()
			inst.Transform:SetPosition(x, 0, z)
			inst.sg.statemem.t = math.huge --finished landing
		end
	end
end

local function SetFlicker(inst, c)
	inst.AnimState:SetAddColour(c, c, c, 0)
	if c > 0 then
		inst.Light:SetIntensity(0.6 + c)
		inst.Light:Enable(true)
	else
		inst.Light:Enable(false)
	end
end

local function UpdateAttackHover(inst, dt)
	if IsPaused(inst) then
		return
	end

	local charge_len = 12 * FRAMES
	local charge_period = charge_len * 4
	local charge_amp = 0.6
	local charge_ht0 = 5
	local recoil_len = 3 * FRAMES
	local recoil_period = recoil_len * 4
	local recoil_amp = 1
	local recoil_ht0 = charge_ht0 + charge_amp
	local idle_amp = 0.4 --from UpdateIdleHover
	local idle_ht0 = 5 --from UpdateIdleHover
	local settle_period = 12 * FRAMES * 2
	local settle_amp = ((recoil_ht0 + recoil_amp) - (idle_ht0 - idle_amp)) / 2
	local settle_ht0 = recoil_ht0 + recoil_amp - settle_amp

	local t, period, amp, ht0

	local hoverstate = inst.sg.statemem.hoverstate
	if hoverstate == 0 then --charging
		t = (inst.sg.statemem.t or 0) + dt
		period = t < charge_len and charge_period or nil
		amp = charge_amp
		ht0 = charge_ht0

		local flicker = inst.sg.statemem.flicker
		if flicker then
			if flicker == 0 then
				SetFlicker(inst, 0.2)
			elseif flicker == 2 then
				SetFlicker(inst, 0.15)
			end
			if t > 0 then
				inst.sg.statemem.flicker = (flicker + 1) % 4
			end
		end
	elseif hoverstate == 1 then --recoil from firing
		t = (inst.sg.statemem.t or 0) + dt
		period = t < recoil_len and recoil_period or nil
		amp = recoil_amp
		ht0 = recoil_ht0
	else--if hoverstate == 2 then --settle back to idle
		t = (inst.sg.statemem.t or settle_period / 4) + dt
		period = settle_period
		amp = settle_amp
		ht0 = settle_ht0
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local ht = ht0 + (period and (math.sin(t * TWOPI / period) * amp) or amp)
	local yspeed = (ht - y) * 15

	inst.Physics:SetMotorVel(0, yspeed, 0)
	inst.sg.statemem.t = t
end

local function SetFlyingPhysics(inst, enable)
	if not enable then
		inst.Physics:SetCollisionGroup(COLLISION.FLYERS)
		inst.Physics:ClearCollidesWith(COLLISION.FLYERS)
		inst.Physics:ClearCollidesWith(COLLISION.LAND_OCEAN_LIMITS)
	else--if TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition()) then
		--V2C: assume always in arena with barrier for now
		--     this check doesn't work on load due to the barrier loading after a taskintime(0)
		inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
		inst.Physics:CollidesWith(COLLISION.LAND_OCEAN_LIMITS)
	--else
	--	inst.Physics:CollidesWith(COLLISION.FLYERS)
	end
end

--------------------------------------------------------------------------

local function SetShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(1.5 * scale, math.min(1, scale))
end

local SOUND_LOOPS =
{
	["idle"] = "rifts5/wagdrone_flying/idle",
	["run"] = "rifts5/wagdrone_flying/walk_lp",
}

local function SetSoundLoop(inst, name)
	for k, v in pairs(SOUND_LOOPS) do
		if k ~= name then
			inst.SoundEmitter:KillSound(k)
		elseif not inst.SoundEmitter:PlayingSound(k) then
			inst.SoundEmitter:PlaySound(v, k)
		end
	end
end

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, t)
			if inst.sg.mem.turnoff then
				inst.sg:GoToState("turnoff")
				return
			end
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle", true)
			if POPULATING then
				inst.AnimState:SetTime(math.random() * inst.AnimState:GetCurrentAnimationLength())
			end
			SetSoundLoop(inst, "idle")
			inst.sg.statemem.t = t
		end,

		onupdate = UpdateIdleHover,
	},

	State{
		name = "turnoff",
		tags = { "busy", "off", --[["noattack",]] "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("turn_off")
			SetSoundLoop(inst, nil)
			inst.sg.mem.turnoff = nil
		end,

		onupdate = UpdateLanding,

		timeline =
		{
			FrameEvent(16, function(inst)
				SetFlyingPhysics(inst, false)
				SetShadowScale(inst, 0.04)
				inst.DynamicShadow:Enable(true)
			end),
			FrameEvent(18, function(inst) SetShadowScale(inst, 0.12) end),
			FrameEvent(20, function(inst) SetShadowScale(inst, 0.24) end),
			FrameEvent(22, function(inst) SetShadowScale(inst, 0.4) end),
			FrameEvent(24, function(inst) SetShadowScale(inst, 0.6) end),
			FrameEvent(26, function(inst) SetShadowScale(inst, 0.84) end),
			FrameEvent(27, function(inst) SetShadowScale(inst, 1.1) end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/turn_off") end),
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
				if not inst.SoundEmitter:PlayingSound("idle") then
					inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/idle", "idle")
				end
				SetFlyingPhysics(inst, true)
				inst.DynamicShadow:Enable(false)
			end
		end,
	},

	State{
		name = "off_idle",
		tags = { "idle", "off", --[["noattack",]] "nointerrupt" },

		onenter = function(inst)
			if inst.sg.mem.todespawn then
				inst:AddTag("NOCLICK")
				ErodeAway(inst)
			elseif inst.sg.mem.turnon then
				inst.sg:GoToState("turnon")
				return
			end
			inst.components.locomotor:Stop()
			if inst.components.workable then
				inst.AnimState:PlayAnimation("damaged_idle_loop", true)
			else
				inst.AnimState:PlayAnimation("off_idle")
			end
			SetFlyingPhysics(inst, false)
			if not POPULATING then
				local x, y, z = inst.Transform:GetWorldPosition()
				if y > 0 then
					inst.Transform:SetPosition(x, 0, z)
				elseif y < 0 then
					inst.Physics:Teleport(x, 0, z)
				end
			end
			SetSoundLoop(inst, nil)
			SetShadowScale(inst, 1.1)
			inst.DynamicShadow:Enable(true)
			WagdroneCommon.SetLedEnabled(inst, false)
			if inst.components.workable and not inst.sg.mem.todespawn then
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
			inst.DynamicShadow:Enable(false)
			SetFlyingPhysics(inst, true)
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
			--SetFlyingPhysics(inst, false) --no need to force this if not already
			SetSoundLoop(inst, "idle")
			SetShadowScale(inst, 1.1)
			inst.DynamicShadow:Enable(true)
			inst.sg.mem.turnon = nil
		end,

		onupdate = function(inst, dt)
			if inst.sg.statemem.hover then
				UpdateIdleHover(inst, dt)
			end
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg.statemem.hover = true
			end),
			FrameEvent(10, function(inst) SetShadowScale(inst, 0.84) end),
			FrameEvent(11, function(inst) SetShadowScale(inst, 0.6) end),
			FrameEvent(12, function(inst) SetShadowScale(inst, 0.4) end),
			FrameEvent(13, function(inst) SetShadowScale(inst, 0.24) end),
			FrameEvent(14, function(inst) SetShadowScale(inst, 0.12) end),
			FrameEvent(15, function(inst) SetShadowScale(inst, 0.04) end),
			FrameEvent(16, function(inst)
				SetFlyingPhysics(inst, true)
				inst.DynamicShadow:Enable(false)
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/turn_on") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle", inst.sg.statemem.t)
				end
			end),
		},

		onexit = function(inst)
			SetFlyingPhysics(inst, true)
			inst.DynamicShadow:Enable(false)
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
			for k, v in pairs(SOUND_LOOPS) do
				if k ~= "run" then
					if k ~= "idle" then
						inst.SoundEmitter:KillSound(k)
					end
				elseif not inst.SoundEmitter:PlayingSound(k) then
					inst.SoundEmitter:PlaySound(v, k)
				end
			end
		end,

		onupdate = function(inst, dt)
			local k = inst.sg.statemem.speedk
			if k then
				k = k + 1
				local numaccelframes = 5
				if k < numaccelframes then
					inst.sg.statemem.speedk = k
					k = k / numaccelframes
					inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", k * k)
				else
					inst.sg.statemem.speedk = nil
					inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "run_start")
				end
			end
			UpdateRunHover(inst, dt)
		end,

		timeline =
		{
			FrameEvent(3, function(inst) inst.SoundEmitter:KillSound("idle") end),
			FrameEvent(4, function(inst)
				inst.sg.statemem.speedk = 0
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.running = true
					inst.sg:GoToState("run", inst.sg.statemem.t)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.running then
				inst.Transform:SetNoFaced()
				inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
			end
		end,
	},

	State{
		name = "run",
		tags = { "moving", "running", "canrotate" },

		onenter = function(inst, t)
			inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "run_start")
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("run_loop", true)
			SetSoundLoop(inst, "run")
			inst.sg.statemem.t = t or 0
		end,

		onupdate = UpdateRunHover,

		onexit = function(inst)
			if not inst.sg.statemem.running then
				inst.Transform:SetNoFaced()
				inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
			end
		end,
	},

	State{
		name = "run_stop",
		tags = { "idle" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("run_pst")
		end,

		onupdate = UpdateRunStopHover,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/walk_pst") end),
			FrameEvent(3, SetSoundLoop),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle", 0)
				end
			end),
		},

		onexit = function(inst)
			inst.Transform:SetNoFaced()
		end,
	},

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("atk_pre")
			inst.AnimState:PushAnimation("atk")
			inst.AnimState:PushAnimation("atk_pst", false)
			SetSoundLoop(inst, "idle")
			inst.sg.statemem.hoverstate = 0
		end,

		onupdate = UpdateAttackHover,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst:ShowTargeting(true)
				inst.Light:SetIntensity(0.05)
				inst.Light:Enable(true)
			end),
			FrameEvent(2, function(inst) inst.Light:SetIntensity(0.1) end),
			FrameEvent(3, function(inst) inst.Light:SetIntensity(0.15) end),
			FrameEvent(4, function(inst) inst.Light:SetIntensity(0.2) end),
			FrameEvent(5, function(inst) inst.Light:SetIntensity(0.25) end),
			FrameEvent(6, function(inst) inst.Light:SetIntensity(0.3) end),
			FrameEvent(7, function(inst) inst.Light:SetIntensity(0.35) end),
			FrameEvent(8, function(inst) inst.Light:SetIntensity(0.4) end),
			FrameEvent(9, function(inst) inst.Light:SetIntensity(0.45) end),
			FrameEvent(10, function(inst) inst.Light:SetIntensity(0.5) end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.projectile = SpawnPrefab("wagdrone_projectile_fx")
				inst.sg.statemem.projectile:AttachTo(inst)
				inst.sg.statemem.flicker = 0
			end),
			FrameEvent(33, function(inst)
				inst:ShowTargeting(false, true)
			end),
			FrameEvent(34, function(inst)
				inst.sg.statemem.hoverstate = 1
				inst.sg.statemem.t = nil
				inst.sg.statemem.flicker = nil
				SetFlicker(inst, 0)
				inst.sg.statemem.projectile:Launch(inst.Transform:GetWorldPosition())
				inst.sg.statemem.projectile = nil
			end),
			FrameEvent(37, function(inst)
				inst.sg.statemem.hoverstate = 2
				inst.sg.statemem.t = nil
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagdrone_flying/turn_off") end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					local period = 1.2 --from UpdateIdleHover
					inst.sg:GoToState("idle", period * 0.75)
				end
			end),
		},

		onexit = function(inst)
			inst:ShowTargeting(false)
			SetFlicker(inst, 0)
			if inst.sg.statemem.projectile then
				inst.sg.statemem.projectile:Remove()
			end
		end,
	},
}

return StateGraph("wagdrone_flying", states, events, "off_idle")
