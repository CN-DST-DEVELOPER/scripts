require("stategraphs/commonstates")

local events =
{
	CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnSink(),
	CommonHandlers.OnFallInVoid(),
	--CommonHandlers.OnFreezeEx(),
	EventHandler("minhealth", function(inst, data)
		if not inst.sg:HasAnyStateTag("hiding", "hide_pre") then
			inst.sg:GoToState("hide_pre")
		end
	end),
	EventHandler("death", function(inst, data)
		if not inst.sg:HasAnyStateTag("hiding", "hide_pre") then
			inst.sg:GoToState("hide_pre")
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not inst.sg:HasStateTag("busy") and data and data.target and data.target:IsValid() then
			inst.sg:GoToState("attack", data.target)
		end
	end),
	EventHandler("attacked", function (inst, data)
		if not inst.sg:HasStateTag("busy") or inst.sg:HasAnyStateTag("caninterrupt", "frozen") then
			if inst.sg:HasStateTag("hiding") then
				inst.sg.statemem.hiding = true
				inst.sg:GoToState("hide_hit")
			elseif not CommonHandlers.HitRecoveryDelay(inst, 1) then
				inst.sg:GoToState("hit")
			end
		end
	end),
}

local function SwitchToNoFaced(inst)
	if inst.sg.mem.facingmodel ~= 0 then
		inst.sg.mem.facingmodel = 0
		inst.Transform:SetNoFaced()
	end
end

local function SwitchToFourFaced(inst)
	if inst.sg.mem.facingmodel then
		inst.sg.mem.facingmodel = nil
		inst.Transform:SetFourFaced()
	end
end

local function SwitchToSixFaced(inst)
	if inst.sg.mem.facingmodel ~= 6 then
		inst.sg.mem.facingmodel = 6
		inst.Transform:SetSixFaced()
	end
end

local function SetHidingRadius(inst, hiding)
	inst.Physics:SetCapsule(hiding and 0.5 or 0.8, 1)
end

local function SetHidingMass(inst, hiding)
	if hiding then
		if not inst:HasTag("blocker") then
			inst:AddTag("blocker")
			inst.Physics:SetMass(0)
		end
	elseif inst:HasTag("blocker") then
		inst:RemoveTag("blocker")
		inst.Physics:SetMass(100)
	end
end

local function OnStartPushing(inst, doer)
	inst.Transform:SetRotation(doer:GetAngleToPoint(inst.Transform:GetWorldPosition()))
	inst.sg.statemem.hiding = true
	inst.sg:GoToState("hide_roll")
end

local function OnStopPushing(inst, doer)
	inst.sg.statemem.hiding = true
	inst.sg.statemem.rolling = true
	inst.sg:GoToState("hide_roll_pst")
end

local function EnablePushing(inst, enable)
	if not enable then
		if inst.components.pushable then
			inst.components.pushable:SetOnStopPushingFn(nil)
			inst:RemoveComponent("pushable")
		end
	elseif inst.components.pushable == nil then
		inst:AddComponent("pushable")
		inst.components.pushable:SetOnStartPushingFn(OnStartPushing)
		inst.components.pushable:SetOnStopPushingFn(OnStopPushing)
		inst.components.pushable:SetPushingSpeed(TUNING.VAULT_CRAWLER_ROLLING_SPEED)
		local anim_r = 0.93
		local phys_r = 0.5
		inst.components.pushable:SetTargetDist(anim_r + 0.2)
		inst.components.pushable:SetMinDist(math.max(anim_r - 0.2, phys_r + 0.05))
		inst.components.pushable:SetMaxDist(anim_r + 1)
	end
end

--------------------------------------------------------------------------

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local function _AOEAttack(inst, radius, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and not targets[v] and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, y, z) < range * range and inst.components.combat:CanTarget(v) then
				inst.components.combat:DoAttack(v)
				targets[v] = true
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

local WORK_RADIUS_PADDING = 0.5
local COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	HAMMER = true,
	MINE = true,
}
local COLLAPSIBLE_TAGS = { "NPC_workable" }
for k, v in pairs(COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(COLLAPSIBLE_TAGS, k.."_workable")
end

local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" }

local function _AOEWork(inst, radius, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + WORK_RADIUS_PADDING, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)) do
		if not targets[v] and v:IsValid() and not v:IsInLimbo() and v.components.workable then
			local work_action = v.components.workable:GetWorkAction()
			--V2C: nil action for NPC_workable (e.g. campfires)
			if (	work_action == nil and v:HasTag("NPC_workable")	) or
				(	v.components.workable:CanBeWorked() and
					work_action and
					COLLAPSIBLE_WORK_ACTIONS[work_action.id]
				)
			then
				v.components.workable:Destroy(inst)
				targets[v] = true
			end
		end
	end
end

local TOSSITEM_MUST_TAGS = { "_inventoryitem" }
local TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" }

local function TossLaunch(inst, launcher, basespeed, startheight, startradius)
	local x0, y0, z0 = launcher.Transform:GetWorldPosition()
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
		startradius = math.max(dist, startradius)
	else
		angle = TWOPI * math.random()
	end
	local sina, cosa = math.sin(angle), math.cos(angle)
	local speed = basespeed + math.random()
	TryTeleportToLaunchPos(inst, x0 + startradius * cosa, startheight, z0 + startradius * sina)
	inst.Physics:SetVel(cosa * speed, speed * 2.5 + math.random(), sina * speed)
end

local function TossItems(inst, radius)
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + WORK_RADIUS_PADDING, TOSSITEM_MUST_TAGS, TOSSITEM_CANT_TAGS)) do
		DeactivateInventoryItemBeforeLaunch(v)
		if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
			TossLaunch(v, inst, radius * 0.4, 0.5, radius)
		end
	end
end

local function DoDropAOE(inst)
	local targets = {}
	_AOEWork(inst, 1, targets)
	_AOEAttack(inst, 1, targets)
	TossItems(inst, 1)
end

--------------------------------------------------------------------------

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			inst.components.locomotor:Stop()
			local anim = inst.sg.mem.facingmodel == 0 and "idle_nofaced" or "idle"
			if pushanim then
				inst.AnimState:PushAnimation(anim)
			else
				inst.AnimState:PlayAnimation(anim, true)
			end
			if inst.sg.mem.facingmodel then
				inst.sg:SetTimeout(1)
			end
		end,

		ontimeout = SwitchToFourFaced,
		onexit = SwitchToFourFaced,
	},

	State{
		name = "spawn",
		tags = { "vault_crawler_dropping", "hiding", "busy", "noattack", "temp_invincible", "nofreeze" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToSixFaced(inst)
			inst.AnimState:PlayAnimation("spawn")
			ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.025, 0.06, inst, 15)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/lava_arena/turtillus/shell_impact") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/movement/foley/thud") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/electricity/light") end),
			FrameEvent(26, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/electricity/electrocute_sml_longer") end),
			FrameEvent(38, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_spawn") end),

			FrameEvent(41, function(inst)
				inst.sg:RemoveStateTag("hiding")
				inst.sg:RemoveStateTag("nofreeze")
			end),
			FrameEvent(42, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("temp_invincible")
			end),
			FrameEvent(45, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			FrameEvent(0, DoDropAOE),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.not_interrupted then
				SwitchToFourFaced(inst)
			end
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/lava_arena/turtillus/shell_impact", nil, 0.6) end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/electricity/light") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_hit") end),

			FrameEvent(14, function(inst)
				if inst.components.health.currenthealth <= inst.components.health.minhealth then
					inst.sg:GoToState("hide_pre")
					return
				end
				inst.sg.statemem.canhide = true
				if inst.sg.statemem.doattack == nil then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(16, function(inst)
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
				if inst.sg:HasStateTag("busy") then
					inst.sg.statemem.doattack = data and data.target
					inst.sg:RemoveStateTag("caninterrupt")
					return true
				end
			end),
			EventHandler("minhealth", function(inst, data)
				if inst.sg.statemem.canhide then
					inst.sg:GoToState("hide_pre")
				end
				return true
			end),
			EventHandler("death", function(inst, data)
				if inst.sg.statemem.canhide then
					inst.sg:GoToState("hide_pre")
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
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("taunt")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_taunt") end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),

			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.not_interrupted = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.not_interrupted then
				SwitchToFourFaced(inst)
			end
		end,
	},

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("attack")
			inst.components.combat:StartAttack()
			if target and target:IsValid() then
				inst.sg.statemem.target = target
			else
				target = inst.components.combat.target
			end
			if target then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			inst.sg.statemem.tracking = true
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local target = inst.sg.statemem.target
				if not (target and target:IsValid()) then
					inst.sg.statemem.target = nil
					target = inst.components.combat.target
				end
				if target then
					if inst.sg.statemem.tracking then
						local rot = inst.Transform:GetRotation()
						local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
						local diff = ReduceAngle(rot1 - rot)
						inst.Transform:SetRotation(rot + math.min(diff / 2, 10))
					else
						if inst.sg.statemem.attacking then
							local function onhit(inst, data)
								if data and data.target == target then
									inst.sg.statemem.attacking = false
								end
							end
							inst:ListenForEvent("onattackother", onhit)
							inst.components.combat:DoAttack(target)
							inst:RemoveEventCallback("onattackother", onhit)
						end
					end
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_attack") end),
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/swipe", nil, 0.5) end),
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/electricity/light") end),

			FrameEvent(7, function(inst)
				inst.sg.statemem.tracking = false
			end),
			FrameEvent(11, function(inst)
				inst.sg:AddStateTag("jumping")
				inst.Physics:SetMotorVelOverride(8, 0, 0)
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.attacking = true
			end),
			FrameEvent(14, function(inst)
				inst.Physics:SetMotorVelOverride(2, 0, 0)
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.attacking = false
				inst.Physics:SetMotorVelOverride(1, 0, 0)
			end),
			FrameEvent(16, function(inst)
				inst.Physics:SetMotorVelOverride(0.5, 0, 0)
			end),
			FrameEvent(17, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
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
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	},

	State{
		name = "hide_pre",
		tags = { "hide_pre", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hide_pre")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_hide_pre") end),

			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("nofreeze")
				inst.sg:AddStateTag("hiding")
				inst.components.locomotor:Stop()
				inst.components.health:SetAbsorptionAmount(1)
				SetHidingMass(inst, true)
				SetHidingRadius(inst, true)
			end),
			FrameEvent(23, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				EnablePushing(inst, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.hiding = true
					inst.sg:GoToState("hide_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
				EnablePushing(inst, false)
			end
		end,
	},

	State{
		name = "hide_idle",
		tags = { "hiding", "busy", "nofreeze", "caninterrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hide_idle")
			inst.components.health:SetAbsorptionAmount(1)
			SetHidingMass(inst, true)
			SetHidingRadius(inst, true)
			EnablePushing(inst, true)
			inst.sg:SetTimeout(6)
		end,

		ontimeout = function(inst)
			inst.sg.statemem.hiding = true
			inst.sg:GoToState("hide_pst")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
				EnablePushing(inst, false)
			end
		end,
	},

	State{
		name = "hide_roll",
		tags = { "rolling", "hiding", "busy", "nofreeze", "noattack", "jumping" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("roll_loop", true)
			inst.components.health:SetAbsorptionAmount(1)
			inst.Physics:SetMass(9999)
			inst.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS)
			inst:AddTag("NOCLICK")
			SetHidingRadius(inst, true)
			EnablePushing(inst, true)
			if not inst.SoundEmitter:PlayingSound("rolling") then
				inst.SoundEmitter:PlaySound("rifts7/vault_crawler/roll_LP", "rolling")
			end
		end,

		onupdate = function(inst)
			local socket = inst:FindSocket(0.7)
			if socket then
				inst.sg:GoToState("socketed", socket) --forces state cleanup b4 removing sg
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
				EnablePushing(inst, false)
			elseif not inst.sg.statemem.rolling then
				inst.Physics:SetMass(inst:HasTag("blocker") and 0 or 100)
			end
			if not inst.sg.statemem.rolling then
				inst.Physics:CollidesWith(COLLISION.BOAT_LIMITS)
			end
			inst:RemoveTag("NOCLICK")
			inst.SoundEmitter:KillSound("rolling")
		end,
	},

	State{
		name = "socketed",
		tags = { "socketed" },

		onenter = function(inst, socket)
			if socket then
				inst:SetSocketed(socket) --this removes stategraph
			else
				inst:SetSocketed(nil)
				inst.sg:GoToState("idle")
			end
		end,
	},

	State{
		name = "hide_roll_pst",
		tags = { "hiding", "busy", "nofreeze", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("roll_pst")
			inst.components.health:SetAbsorptionAmount(1)
			inst.Physics:SetMass(9999)
			inst.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS)
			SetHidingRadius(inst, true)
			EnablePushing(inst, true)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/move", nil, 0.3) end),

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.hiding = true
					inst.sg:GoToState("hide_idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
				EnablePushing(inst, false)
			else
				inst.Physics:SetMass(inst:HasTag("blocker") and 0 or 100)
			end
			inst.Physics:CollidesWith(COLLISION.BOAT_LIMITS)
		end,
	},

	State{
		name = "hide_hit",
		tags = { "hiding", "hit", "busy", "nofreeze" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hide_hit")
			inst.components.health:SetAbsorptionAmount(1)
			SetHidingMass(inst, true)
			SetHidingRadius(inst, true)
			EnablePushing(inst, false)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/lava_arena/turtillus/shell_impactXXXX", nil, 0.8) end),

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				EnablePushing(inst, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.hiding = true
					inst.sg:GoToState("hide_idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
				EnablePushing(inst, false)
			end
		end,
	},

	State{
		name = "hide_pst",
		tags = { "hiding", "busy", "nofreeze" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hide_pst")
			inst.components.health:SetAbsorptionAmount(1)
			SetHidingMass(inst, true)
			SetHidingRadius(inst, true)
			EnablePushing(inst, false)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/voice_hide_pst") end),

			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("hiding")
				inst.components.health:SetPercent(0.5)
				SetHidingMass(inst, false)
				SetHidingRadius(inst, false)
			end),
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("nofreeze")
				inst.components.health:SetAbsorptionAmount(0)
			end),
			FrameEvent(13, function(inst)
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
			if not inst.sg.statemem.hiding then
				inst.components.health:SetAbsorptionAmount(0)
				if inst.sg:HasStateTag("hiding") then
					inst.components.health:SetPercent(0.5)
					SetHidingMass(inst, false)
					SetHidingRadius(inst, false)
				end
			elseif not inst.sg:HasStateTag("hiding") then
				SetHidingMass(inst, true)
				SetHidingRadius(inst, true)
			end
		end,
	},
}

CommonStates.AddWalkStates(states,
{
	starttimeline =
	{
		--#SFX
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
	},
	walktimeline =
	{
		--#SFX
		FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
		FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep", nil, 0.8) end),
		FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
		FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep", nil, 0.6) end),
	},
	endtimeline =
	{
		--#SFX
		FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts7/vault_crawler/footstep") end),
	},
})

CommonStates.AddSinkAndWashAshoreStates(states, { washashore = "hit" })
CommonStates.AddVoidFallStates(states, { voiddrop = "hit" })
--CommonStates.AddFrozenStates(states, SwitchToNoFaced, SwitchToFourFaced)

return StateGraph("vault_crawler", states, events, "idle")
