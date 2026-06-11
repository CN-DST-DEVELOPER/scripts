local clockwork_common = require("prefabs/clockwork_common")
require("stategraphs/commonstates")

local events=
{
    CommonHandlers.OnHop(),
    CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnSleepEx(),
	CommonHandlers.OnWakeEx(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnAttacked(nil, math.huge), --hit delay only for projectiles
    CommonHandlers.OnDeath(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),

	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			inst.sg:GoToState("attack", data and data.target)
		end
	end),
}

local MIN_TGT_RANGE = 3
local MIN_TGT_RANGE_SQ = MIN_TGT_RANGE * MIN_TGT_RANGE
local MAX_TGT_RANGE = 12
local MAX_TGT_RANGE_SQ = MAX_TGT_RANGE * MAX_TGT_RANGE

local function GetTargetingXZDir(inst, target)
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local dx = x1 - x
	local dz = z1 - z
	local dir
	if dx == 0 and dz == 0 then
		dir = inst.Transform:GetRotation()
		local theta = dir * DEGREES
		x1 = x + MIN_TGT_RANGE * math.cos(theta)
		z1 = z - MIN_TGT_RANGE * math.sin(theta)
	else
		local dsq = dx * dx + dz * dz
		if dsq > MAX_TGT_RANGE_SQ then
			local l = MAX_TGT_RANGE / math.sqrt(dsq)
			x1 = x + dx * l
			z1 = z + dz * l
		elseif dsq < MIN_TGT_RANGE_SQ then
			local l = MIN_TGT_RANGE / math.sqrt(dsq)
			x1 = x + dx * l
			z1 = z + dz * l
		end
		dir = math.atan2(-dz, dx) * RADIANS
	end
	return x1, z1, dir
end

local function LerpTargetingXZDir(inst, xa, za, dira, xb, zb, dirb, k)
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1 = xa * (1 - k) + xb * k
	local z1 = za * (1 - k) + zb * k
	local dx = x1 - x
	local dz = z1 - z
	local dir1
	if dx == 0 and dz == 0 then
		x1, z1, dir1 = xa, za, dira
	else
		dir1 = math.atan2(-dz, dx) * RADIANS
		if DiffAngle(dira, dir1) >= 90 then
			x1, z1, dir1 = xa, za, dira
		else
			local dsq = dx * dx + dz * dz
			if dsq > MAX_TGT_RANGE_SQ then
				local l = MAX_TGT_RANGE / math.sqrt(dsq)
				x1 = x + dx * l
				z1 = z + dz * l
			elseif dsq < MIN_TGT_RANGE_SQ then
				local l = MIN_TGT_RANGE / math.sqrt(dsq)
				x1 = x + dx * l
				z1 = z + dz * l
			end
		end
	end
	return x1, z1, dir1
end

local function SetHeadGlow(inst, glow)
	glow = glow and 1 or 0
	inst.AnimState:SetSymbolLightOverride("bulb", 0.64 * glow)
	inst.AnimState:SetSymbolLightOverride("face", 0.32 * glow)
	inst.AnimState:SetSymbolLightOverride("eye", 0.32 * glow)
	inst.AnimState:SetSymbolLightOverride("eyelid", 0.32 * glow)
	inst.AnimState:SetSymbolLightOverride("neck", 0.16 * glow)
	inst.AnimState:SetSymbolLightOverride("shoulder", 0.08 * glow)
	inst.AnimState:SetSymbolLightOverride("wing", 0.04 * glow)
end

local states=
{
     State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
			inst.components.locomotor:StopMoving()
            if playanim then
				if inst.sg.mem.sixfaced then
					inst.sg.mem.sixfaced = false
					inst.Transform:SetFourFaced()
				end
                inst.AnimState:PlayAnimation(playanim)
				inst.AnimState:PushAnimation("idle_loop")
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "idle") end ),
        },

        events=
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepsixfaced = true
					inst.sg:GoToState("idle")
				end
			end),
        },

		onexit = function(inst)
			if inst.sg.mem.sixfaced and not inst.sg.statemem.keepsixfaced then
				inst.sg.mem.sixfaced = false
				inst.Transform:SetFourFaced()
			end
		end,
    },

   State{
        name = "taunt",
		tags = { "busy", "caninterrupt", "canrotate" },

        onenter = function(inst)
			inst.components.locomotor:StopMoving()
			local target = inst.components.combat.target
			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			if not inst.sg.mem.sixfaced then
				inst.sg.mem.sixfaced = true
				inst.Transform:SetSixFaced() --best model for facing target with an unfaced anim
			end
            inst.AnimState:PlayAnimation("taunt")
        end,

        timeline =
        {
            TimeEvent(19*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "voice") end ),
			FrameEvent(39, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
        },

        events=
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepsixfaced = true
					inst.sg:GoToState("idle")
				end
			end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.keepsixfaced then
				inst.sg.mem.sixfaced = false
				inst.Transform:SetFourFaced()
			end
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
    		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "liedown") end ),
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
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."hurt") end),
			FrameEvent(8, function(inst)
				local target = inst.sg.statemem.doattack
				if target and target:IsValid() then
					inst.sg:GoToState("attack", target)
					return
				end
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				local target = data and data.target or inst.components.combat.target
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.doattack = target
				elseif target and target:IsValid() then
					inst.sg:GoToState("attack", target)
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

	--[[State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("atk")
			inst.components.combat:StartAttack()
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."charge") end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."shoot") end),
			FrameEvent(24, function(inst)
				inst.components.combat:DoAttack()
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(32, function(inst)
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
	},]]

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:StopMoving()

			if inst.targetingfx then
				inst.targetingfx:KillFx()
				inst.targetingfx = nil
			end

			local x, _, z = inst.Transform:GetWorldPosition()
			local x1, z1
			target = target or inst.components.combat.target
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.tgtx, inst.sg.statemem.tgtz, inst.sg.statemem.tgtdir = GetTargetingXZDir(inst, target)
				inst.Transform:SetRotation(inst.sg.statemem.tgtdir)
				inst.sg.statemem.trackingspeed = 0.5
			else
				inst.sg.statemem.tgtdir = inst.Transform:GetRotation()
				local theta = inst.sg.statemem.tgtdir * DEGREES
				inst.sg.statemem.tgtx = x + 6 * math.cos(theta)
				inst.sg.statemem.tgtz = z - 6 * math.sin(theta)
			end

			inst.AnimState:PlayAnimation("atk2_pre")
			inst.AnimState:PushAnimation("atk2_loop")
			inst.components.combat:StartAttack()

			inst.sg:SetTimeout(1)
		end,

		onupdate = function(inst, dt)
			if inst:IsAsleep() then
				inst.sg:GoToState("idle")
				return
			elseif dt > 0 then
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local x1, z1, dir1 = GetTargetingXZDir(inst, target)
						inst.sg.statemem.tgtx, inst.sg.statemem.tgtz, inst.sg.statemem.tgtdir = LerpTargetingXZDir(inst, inst.sg.statemem.tgtx, inst.sg.statemem.tgtz, inst.sg.statemem.tgtdir, x1, z1, dir1, inst.sg.statemem.trackingspeed)
						inst.Transform:SetRotation(inst.sg.statemem.tgtdir)
						if inst.sg.statemem.trackingspeed > 0.02 then
							inst.sg.statemem.trackingspeed = inst.sg.statemem.trackingspeed - 0.02
						else
							inst.sg.statemem.target = nil
							inst.sg.statemem.trackingspeed = nil
						end
					else
						inst.sg.statemem.target = nil
						inst.sg.statemem.trackingspeed = nil
					end
				end
			end

			if inst.sg.statemem.starttargeting then
				inst.sg.statemem.starttargeting = nil
				inst.targetingfx = SpawnPrefab("bishop_targeting_fx")
			end
			if inst.targetingfx then
				inst.targetingfx.Transform:SetPosition(inst.sg.statemem.tgtx, 0, inst.sg.statemem.tgtz)
				inst.targetingfx.Transform:SetRotation(inst.sg.statemem.tgtdir)
				inst.targetingfx:SetDistFromBishop(math.sqrt(inst:GetDistanceSqToPoint(inst.sg.statemem.tgtx, 0, inst.sg.statemem.tgtz)))
			end
		end,

		ontimeout = function(inst)
			if inst.targetingfx then
				inst.targetingfx:KillFx()
				inst.targetingfx = nil
			end
			inst.sg.statemem.shoot = true
			inst.sg:GoToState("attack_shoot", Vector3(inst.sg.statemem.tgtx, 0, inst.sg.statemem.tgtz))
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."charge") end),
			FrameEvent(2, function(inst) SetHeadGlow(inst, true) end),
			FrameEvent(6, function(inst)
				inst.sg.statemem.starttargeting = true
			end),
		},

		onexit = function(inst)
			if inst.targetingfx then
				inst.targetingfx:Remove()
				inst.targetingfx = nil
			end
			if not inst.sg.statemem.shoot then
				SetHeadGlow(inst, false)
			end
		end,
	},

	State{
		name = "attack_shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, pos)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("atk2_pst")
			inst.AnimState:SetSymbolBloom("fx_glow")

			inst.sg.statemem.pos = pos
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."shoot") end),
			FrameEvent(1, function(inst)
				local pos = inst.sg.statemem.pos
				if pos then
					local fx = SpawnPrefab("bishop_charge2_fx")
					fx.Transform:SetPosition(pos:Get())
					fx:SetupCaster(inst)
					inst:StartShotFx(pos)
				end
			end),
			FrameEvent(6, function(inst)
				SetHeadGlow(inst, false)
				inst.AnimState:SetSymbolLightOverride("bulb", 0.32)
				inst.sg.statemem.glowoff = true
				inst.showshot:set_local(false)
			end),
			FrameEvent(7, function(inst) inst.AnimState:SetSymbolLightOverride("bulb", 0.31) end),
			FrameEvent(8, function(inst) inst.AnimState:SetSymbolLightOverride("bulb", 0.3) end),
			FrameEvent(9, function(inst) inst.AnimState:SetSymbolLightOverride("bulb", 0.28) end),
			FrameEvent(10, function(inst) inst.AnimState:SetSymbolLightOverride("bulb", 0.24) end),
			FrameEvent(11, function(inst) inst.AnimState:SetSymbolLightOverride("bulb", 0.16) end),
			FrameEvent(12, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.AnimState:SetSymbolLightOverride("bulb", 0)
			end),
			FrameEvent(14, function(inst)
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
			if not inst.sg.statemem.glowoff then
				SetHeadGlow(inst, false)
			elseif not inst.sg:HasStateTag("caninterrupt") then
				inst.AnimState:SetSymbolLightOverride("bulb", 0)
			end
			inst.AnimState:ClearSymbolBloom("fx_glow")
			inst.showshot:set_local(false)
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
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
				inst.sg:AddStateTag("caninterrupt")
				clockwork_common.sgTrySetBefriendable(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepbefriendable = true
					inst.sg:GoToState("stun_loop")
				end
			end),
		},

		onexit = clockwork_common.sgTryClearBefriendable,
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
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
				inst.sg:AddStateTag("caninterrupt")
				clockwork_common.sgTrySetBefriendable(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepbefriendable = true
					inst.sg:GoToState("stun_loop")
				end
			end),
		},

		onexit = clockwork_common.sgTryClearBefriendable,
	},

	State{
		name = "stun_loop",
		tags = { "stunned", "busy", "caninterrupt", "nosleep" },

		onenter = function(inst, nohit)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_loop")
			clockwork_common.sgTrySetBefriendable(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."liedown") end),
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
					inst.sg.statemem.keepbefriendable = true
					inst.sg:GoToState("stun_pst")
				end
			end),
		},

		onexit = clockwork_common.sgTryClearBefriendable,
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "busy", "hit", "nosleep" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_hit")
			clockwork_common.sgTrySetBefriendable(inst)
			inst.sg.mem.stunhits = inst.sg.mem.stunhits + 1
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."hurt") end),
			FrameEvent(6, function(inst)
				if inst.sg.mem.stunhits >= 4 then
					inst.sg.statemem.keepbefriendable = true
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
					inst.sg.statemem.keepbefriendable = true
					inst.sg:GoToState("stun_loop")
				end
			end),
		},

		onexit = clockwork_common.sgTryClearBefriendable,
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
			clockwork_common.sgTrySetBefriendable(inst)
		end,

		timeline =
		{
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("stunned")
				inst.sg.mem.stunhits = nil
				clockwork_common.sgTryClearBefriendable(inst)
				inst.SoundEmitter:PlaySound(inst.effortsound)
			end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
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

		onexit = clockwork_common.sgTryClearBefriendable,
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
			inst.SoundEmitter:PlaySound(inst.soundpath.."bounce")
			inst.components.locomotor:WalkForward()
		end),
		FrameEvent(19, function(inst)
			inst.SoundEmitter:PlaySound(inst.soundpath.."land")
			inst.SoundEmitter:PlaySound(inst.effortsound)
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
		TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "liedown") end ),
		FrameEvent(23, function(inst) inst.sg:RemoveStateTag("caninterrupt") end),
    },
	sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "sleep") end),
	},
	waketimeline =
	{
		CommonHandlers.OnNoSleepFrameEvent(14, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(20, function(inst)
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
	FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."death") end),
})

CommonStates.AddFrozenStates(states)

CommonStates.AddElectrocuteStates(states,
{	--timeline
	loop =
	{
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."hurt") end),
	},
	pst =
	{
		FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
	},
},
{	--anims
	loop = function(inst)
		if inst.sg.lasttags["stunned"] then
			inst.sg:AddStateTag("stunned")
			inst.override_combat_fx_height = "low"
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
			clockwork_common.sgTrySetBefriendable(inst)

			--V2C: can change this back since fx is already spawned at this point
			inst.override_combat_fx_height = nil
		end
	end,
	loop_onexit = function(inst)
		if inst.sg:HasStateTag("stunned") and not inst.sg.statemem.not_interrupted then
			clockwork_common.sgTryClearBefriendable(inst)
		end
	end,
	pst_onenter = function(inst)
		if inst.sg:HasStateTag("stunned") then
			clockwork_common.sgTrySetBefriendable(inst)
		else
			inst.sg:GoToState("shock_to_stun")
		end
	end,
	pst_onexit = function(inst)
		if inst.sg:HasStateTag("stunned") then
			clockwork_common.sgTryClearBefriendable(inst)
		end
	end,
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			if inst.sg:HasStateTag("stunned") then
				inst.sg.statemem.keepbefriendable = true
				inst.sg:GoToState("stun_loop")
			else
				inst.sg:GoToState("idle")
			end
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
			inst.SoundEmitter:PlaySound(inst.soundpath.."land")
			inst.SoundEmitter:PlaySound(inst.effortsound)
		end)
	},
},
nil,
nil,
{
	start_embarking_pre_frame = 9 * FRAMES,
},
{
	pre_onenter = function(inst)
		inst.components.locomotor:StopMoving()
	end,

	pre_ontimeout = function(inst)
		inst.SoundEmitter:PlaySound(inst.soundpath.."bounce")
	end,
})

return StateGraph("bishop", states, events, "idle")
