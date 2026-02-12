local clockwork_common = require("prefabs/clockwork_common")
require("stategraphs/commonstates")

local events=
{
    CommonHandlers.OnHop(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
	CommonHandlers.OnSleepEx(),
	CommonHandlers.OnWakeEx(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnAttacked(nil, math.huge), --hit delay only for projectiles
    CommonHandlers.OnDeath(),

	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			if inst.sg:HasStateTag("running") then
				inst.sg:GoToState("runningattack")
			else
				local target = data and data.target or inst.components.combat.target
				if target and target:IsValid() then
					inst:ForceFacePoint(target.Transform:GetWorldPosition())
					inst.sg:GoToState("run", true)
				end
			end
		end
	end),

	EventHandler("locomote", function(inst, data)
		if inst.sg:HasAnyStateTag("runningattack", "busy") then
			return
		end

		local is_moving = inst.sg:HasStateTag("moving")
		local is_running = inst.sg:HasAnyStateTag("running", "runningattack")

		local should_move = inst.components.locomotor:WantsToMoveForward()
		local should_run = inst.components.locomotor:WantsToRun()

		if not should_move then
			if is_moving then
				--stopping
				inst.sg:GoToState(is_running and "run_stop" or "walk_stop")
			end
		elseif not is_moving then
			--starting
			inst.sg:GoToState(should_run and ((inst.sg.mem.runcancels or 0) >= 3 and "run" or "run_start") or "walk_start")
		elseif not is_running then
			if should_run then
				--changing from walk to run
				inst.sg:GoToState("run_start")
			end
		elseif not should_run then
			--changing from run to walk
			inst.sg:GoToState("run_stop", "walk_start")
		elseif data and data.dir and DiffAngle(inst.Transform:GetRotation(), data.dir) > 90 then
			if not inst:HasTag("ChaseAndRam") then
				--hard turn while running away
				inst.sg:GoToState("run_stop")
			elseif inst.components.combat:HasTarget() then
				--range 10 -> 20
				local dsq = inst:GetDistanceSqToInst(inst.components.combat.target)
				if dsq > 100 then
					dsq = (dsq - 100) / (400 - 100)
					if dsq >= 1 or math.random() < dsq * dsq then
						--hard turn back to chase target
						inst.sg:GoToState("run_stop")
					end
				end
			end
		end
	end),
}

local function DoShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.3, 0.02, 0.05, inst, 40)
end

local function DoRamAOE(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation()
	local range = inst.components.combat:GetHitRange()
	local hit = false
	local t = GetTime()

	inst.components.combat.ignorehitrange = true
	clockwork_common.FindAOETargetsAtXZ(inst, x, z, range + 3,
		function(guy, inst)
			if (inst.recentlycharged[guy] or -math.huge) + 3 > t then
				return
			end
			local range1 = range + guy:GetPhysicsRadius(0)
			local x1, y1, z1 = guy.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if (dx == 0 and dz == 0) or
				(	dx * dx + dz * dz < range1 * range1 and
					DiffAngle(rot, math.atan2(-dz, dx) * RADIANS) < 75 --hit in front only
				)
			then
				if not guy:HasTag("smashable") then
					inst.recentlycharged[guy] = t
					inst.components.combat:DoAttack(guy)
					hit = true
				elseif guy.components.health then
					guy.components.health:Kill()
				end
			end
		end)
	inst.components.combat.ignorehitrange = false

	return hit
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
				inst.AnimState:PushAnimation("idle")
            else
                inst.AnimState:PlayAnimation("idle", true)
            end
        end,

        timeline =
        {
		    TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "idle") end ),
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

    State{  name = "run_start",
            tags = {"moving", "running", "busy", "atk_pre", "canrotate"},

            onenter = function(inst)
                -- inst.components.locomotor:RunForward()
				inst.components.locomotor:StopMoving()
                inst.SoundEmitter:PlaySound(inst.soundpath .. "pawground")
                inst.AnimState:PlayAnimation("atk_pre")
				inst.AnimState:PushAnimation("paw_loop")
                inst.sg:SetTimeout(1)
				if (inst.sg.mem.runcancels or 0) < 3 then
					inst.sg:AddStateTag("caninterrupt")
				end

				inst.components.locomotor:SetAllowPlatformHopping(false)
            end,

            ontimeout= function(inst)
				inst.sg:GoToState("run")
            end,

            timeline=
            {
		    TimeEvent(1*FRAMES,  function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end ),
		    TimeEvent(12*FRAMES, function(inst)
				inst.SoundEmitter:PlaySound(inst.soundpath.."pawground")
				--inst:SpawnGroundFx()
			end),
            TimeEvent(15*FRAMES,  function(inst) inst.sg:RemoveStateTag("canrotate") end ),
		    TimeEvent(20*FRAMES,  function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end ),
		    TimeEvent(30*FRAMES, function(inst)
				inst.SoundEmitter:PlaySound(inst.soundpath.."pawground")
				--inst:SpawnGroundFx()
			end ),
		    TimeEvent(35*FRAMES,  function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end ),
            },

			onexit = function(inst)
				inst.components.locomotor:SetAllowPlatformHopping(true)
			end,
        },

    State{  name = "run",
            tags = {"moving", "running"},

			onenter = function(inst, quickattack)
				inst.components.locomotor:SetAllowPlatformHopping(false)
				inst.components.locomotor.pusheventwithdirection = true
                inst.components.locomotor:RunForward()

                if not inst.AnimState:IsCurrentAnimation("atk") then
                    inst.AnimState:PlayAnimation("atk", true)
                end
                inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
				--inst.hit_recovery = TUNING.ROOK_RUN_HIT_RECOVERY

				inst.sg.statemem.quickattack = quickattack

				if not inst.sg:InNewState() then
					--looped
					inst.sg.mem.runcancels = nil
				else
					inst.SoundEmitter:PlaySound(inst.soundpath.."charge_LP", "charge")
					inst.sg:AddStateTag("busy")
					if (inst.sg.mem.runcancels or 0 < 3) then
						inst.sg:AddStateTag("caninterrupt")
					end
					for k in pairs(inst.recentlycharged) do
						inst.recentlycharged[k] = nil
					end
					inst:PushEvent("attackstart")
				end

				if DoRamAOE(inst) then
					inst.SoundEmitter:PlaySound(inst.soundpath.."explo")
				end
            end,

			onupdate = function(inst, dt)
				if inst:IsAsleep() then
					inst.sg:GoToState("idle")
					return
				elseif dt > 0 then
					if DoRamAOE(inst) then
						inst.SoundEmitter:PlaySound(inst.soundpath.."explo")
					end
				end
			end,

            timeline=
            {
				FrameEvent(5, function(inst)
					inst.SoundEmitter:PlaySound(inst.effortsound)
					inst:SpawnGroundFx()
				end),
            },

            ontimeout = function(inst)
				if inst.sg.statemem.quickattack then
					inst.sg:GoToState("runningattack")
					return
				end
				inst.sg.statemem.running = true
				inst.sg:GoToState("run")
            end,

			onexit = function(inst)
				if not inst.sg.statemem.running then
					inst.components.locomotor:SetAllowPlatformHopping(true)
					--inst.hit_recovery = nil
					inst.components.locomotor.pusheventwithdirection = false
					inst.SoundEmitter:KillSound("charge")
				end
			end,
        },

	State{
			name = "run_stop",
			tags = { "busy", "jumping", "caninterrupt" },

			onenter = function(inst, nextstate)
				inst.components.locomotor:SetAllowPlatformHopping(false)
				inst.sg.mem.runcancels = nil
				inst.AnimState:PlayAnimation("atk_skid")
		        inst.SoundEmitter:PlaySound(inst.effortsound)
				inst.components.locomotor:Stop()
				inst.sg.statemem.speed = inst.components.locomotor:GetRunSpeed()
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.8, 0, 0)
				inst.sg.statemem.nextstate = nextstate
            end,

			timeline =
			{
				FrameEvent(2, function(inst) inst:SpawnGroundFx() end),
				FrameEvent(2, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.4, 0, 0) end),
				FrameEvent(4, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.2, 0, 0) end),
				FrameEvent(6, function(inst) inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * 0.1, 0, 0) end),
				FrameEvent(8, function(inst)
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
					inst.sg.statemem.speed = nil
					inst.sg:RemoveStateTag("jumping")
					inst.components.locomotor:SetAllowPlatformHopping(true)
				end),
				FrameEvent(12, function(inst)
					if inst.sg.statemem.nextstate then
						inst.sg:GoToState(inst.sg.statemem.nextstate)
						return
					end
					inst.sg:RemoveStateTag("busy")
					inst.sg:AddStateTag("idle")
					inst.sg:AddStateTag("canrotate")
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
				if inst.sg.statemem.speed then
					inst.components.locomotor:SetAllowPlatformHopping(true)
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
				end
			end,
        },

   State{
        name = "taunt",
        tags = {"busy"},

        onenter = function(inst)
			if inst.sg.lasttags and inst.sg.lasttags["running"] then
				inst.sg:GoToState("run_stop", "taunt")
				return
			end
			inst.components.locomotor:StopMoving()
			local target = inst.components.combat.target
			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
            inst.AnimState:PlayAnimation("taunt")
            inst.SoundEmitter:PlaySound(inst.soundpath .. "voice")
        end,

        timeline =
        {
		    TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "voice") end ),
		    TimeEvent(15*FRAMES,  function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end ),
		    TimeEvent(27*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "voice") end ),
			FrameEvent(32, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
    },

    State{  name = "runningattack",
			tags = { "runningattack", "busy" },

            onenter = function(inst)
				inst.sg.mem.runcancels = nil
				inst.components.locomotor:Stop()
				inst.AnimState:PlayAnimation("atk_collide")

				local forcefacing = inst.components.combat.forcefacing
				inst.components.combat.forcefacing = false
				inst.components.combat:StartAttack()
				inst.components.combat.forcefacing = forcefacing

				local hit = DoRamAOE(inst)
				if hit then
					inst.SoundEmitter:PlaySound(inst.soundpath.."explo")
				else
					local t = GetTime() - 6 * FRAMES
					for k, v in pairs(inst.recentlycharged) do
						if v >= t then
							hit = true
							break
						end
					end
					if not hit then
						inst.sg:GoToState("run_stop")
						return
					end
				end
				if inst.sg.currentstate.name == "runningattack" then
					inst.SoundEmitter:PlaySound(inst.effortsound)
				end
            end,

            timeline =
            {
				FrameEvent(12, function(inst)
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
        		TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "bounce") end ),
        		TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "land") end ),
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
			if inst.sg.lasttags and inst.sg.lasttags["running"] then
				inst.sg.mem.runcancels = (inst.sg.mem.runcancels or 0) + 1
			end
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."hurt") end),
			FrameEvent(7, function(inst)
				local target = inst.sg.statemem.doattack
				if target and target:IsValid() then
					inst:ForceFacePoint(target.Transform:GetWorldPosition())
					inst.sg:GoToState("run", true)
					return
				end
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				local target = data and data.target or inst.components.combat.target
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.doattack = target
				elseif target and target:IsValid() then
					inst:ForceFacePoint(target.Transform:GetWorldPosition())
					inst.sg:GoToState("run", true)
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
		name = "stun_pre",
		tags = { "stunned", "busy", "nosleep", "noelectrocute" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_pre")
			inst.sg.mem.stunhits = 0
		end,

		timeline =
		{
			FrameEvent(9, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
			FrameEvent(10, DoShake),
			FrameEvent(12, function(inst)
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
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."land") end),
			FrameEvent(2, DoShake),
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
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."hurt") end),
			FrameEvent(7, function(inst)
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
			inst.AnimState:SetFrame(35)
			if inst.sg.mem.stunhits < 4 then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.sg:RemoveStateTag("caninterrupt")
			end),
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end),
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("stunned")
				inst.sg.mem.stunhits = nil
			end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound(inst.effortsound) end),
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
			inst.SoundEmitter:PlaySound(inst.effortsound)
			inst.SoundEmitter:PlaySound(inst.soundpath.."land")
			DoShake(inst)
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
		FrameEvent(11, function(inst)
			inst.SoundEmitter:PlaySound(inst.soundpath.."liedown")
			inst.sg:RemoveStateTag("caninterrupt")
		end),
    },
	sleeptimeline = {
        TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath .. "sleep") end),
	},
	waketimeline =
	{
		CommonHandlers.OnNoSleepFrameEvent(12, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(17, function(inst)
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
	FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound(inst.soundpath.."explo") end),
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
		FrameEvent(1, DoShake),
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
			--V2C: can change this back since fx is already spawned at this point
			inst.override_combat_fx_height = nil
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
			inst.SoundEmitter:PlaySound(inst.effortsound)
			inst.SoundEmitter:PlaySound(inst.soundpath.."land")
		end),
        FrameEvent(4, function(inst)
            inst.sg:RemoveStateTag("busy")
        end)
	},
},
nil,
nil,
{
	start_embarking_pre_frame = 10 * FRAMES,
},
{
	pre_onenter = function(inst)
		inst.components.locomotor:StopMoving()
	end,

	pre_ontimeout = function(inst)
		inst.SoundEmitter:PlaySound(inst.soundpath.."bounce")
	end,

    pst_onenter = function(inst)
        inst.sg:AddStateTag("busy") -- So locomote event can't interrupt us.
    end,
})

return StateGraph("rook", states, events, "idle")
