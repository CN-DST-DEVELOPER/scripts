require("stategraphs/commonstates")
local HitBox = require("util/hitbox")

local _dbg_draw = BRANCH == "dev"

local function IsBoss(inst)
	return inst.components.inventory == nil
end

local function IsShadow(inst)
	return inst:HasTag("shadowthrall")
end

local function PlayLobSound(inst, sound)
	inst.sg.mem.soundparams = inst.sg.mem.soundparams or {}
	inst.sg.mem.soundparams.size =
		(IsShadow(inst) and 0.95) or
		(IsBoss(inst) and 0.9) or
		(inst.components.scaler and Remap(inst.components.scaler.scale, TUNING.ROCKY_MIN_SCALE, TUNING.ROCKY_MAX_SCALE, 0, 0.85)) or
		0.85

	inst.SoundEmitter:PlaySoundWithParams(sound, inst.sg.mem.soundparams)
end

local function PlayLobIdleSound(inst)
	PlayLobSound(inst, "dontstarve/creatures/rocklobster/idle")
end

local function PlayLobFoley(inst)
	PlayLobSound(inst, "dontstarve/creatures/rocklobster/foley")
end

local function PlayLobFootstep(inst)
	inst.SoundEmitter:PlaySound(IsBoss(inst) and "dontstarve/creatures/rocklobster/rocklobster_boss/footstep" or "dontstarve/creatures/rocklobster/footstep")
end

local function SwitchToNoFaced(inst)
	if inst.sg.mem.facings ~= 0 then
		inst.sg.mem.facings = 0
		inst.Transform:SetNoFaced()
	end
end

local function SwitchToEightFaced(inst)
	if inst.sg.mem.facings ~= 8 then
		inst.sg.mem.facings = 8
		inst.Transform:SetEightFaced()
	end
end

local function TryRestoreFourFaced(inst)
	if inst.sg.mem.facings and
		not (inst.sg.statemem.keepnofaced and inst.sg.mem.facings == 0) and
		not (inst.sg.statemem.keepeightfaced and inst.sg.mem.facings == 8)
	then
		inst.sg.mem.facings = nil
		inst.Transform:SetFourFaced()
	end
end

local function SnapTo45s(angle)
	return math.floor(angle / 45 + 0.5) * 45
end

local function TryInitStunned(inst)
	if inst.sg.mem.stun_t0 == nil then
		inst.sg.mem.stun_t0 = GetTime()
	end
end

local function TryClearStunned(inst)
	if not inst.sg.statemem.stunned then
		inst.sg.mem.stun_t0 = nil
	end
end

local function FlashTargets(inst, c)
	local r, g, b = c, c, c
	if IsShadow(inst) then
		r, g, b = c, 0, 0
	end
	for k in pairs(inst.sg.statemem.flashtargets) do
		if k:IsValid() then
			if k.components.colouradder == nil then
				k:AddComponent("colouradder")
			end
			k.components.colouradder:PushColour(inst, r, g, b, 0)
		end
	end
end

local function ClearFlashTargets(inst)
	for k in pairs(inst.sg.statemem.flashtargets) do
		if k:IsValid() and k.components.colouradder then
			k.components.colouradder:PopColour(inst)
		end
	end
end

local function TryFadeIn(inst)
	return inst.DeltaFade ~= nil and inst:DeltaFade(1)
end

local function DoBoulderCD(inst)
	if inst.components.timer then
		if inst.components.timer:TimerExists("bouldercd") then
		    inst.components.timer:SetTimeLeft("bouldercd", math.max(10 + math.random() * 10, inst.components.timer:GetTimeLeft("bouldercd") or 0))
		else
			local bouldercd = TUNING.ROCKY_SHIELD_COOLDOWN + TUNING.ROCKY_SHIELD_COOLDOWN_VARIANCE * math.random()
		    inst.components.timer:StartTimer("bouldercd", bouldercd)
		end
		if inst.components.combat:HasTarget() then
			inst.components.timer:PauseTimer("bouldercd")
		end
	end
end

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }
local SHADOW_AOE_TARGET_CANT_TAGS = ConcatArrays({ "shadowthrall", "shadowboss", "stalker" }, AOE_TARGET_CANT_TAGS)

local function IsRockyAlly(inst, target)
	if target:HasTag("rocky") then
		local mytarget = inst.components.combat.target
		return mytarget == nil
			or not (mytarget == target or
					target.components.combat:TargetIs(inst) or
					target.components.combat:IsAlly(mytarget))
	end
	return false
end

local function DoAOEAttack(inst, x, z, r, hitbox, targets, flashtargets)
	inst.components.combat.ignorehitrange = true
	for _, v in ipairs(TheSim:FindEntities(x, 0, z, r + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, IsShadow(inst) and SHADOW_AOE_TARGET_CANT_TAGS or AOE_TARGET_CANT_TAGS)) do
		if not (targets and targets[v]) and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead()) and
			not IsRockyAlly(inst, v)
		then
			local x1, _, z1 = v.Transform:GetWorldPosition()
			if hitbox:CollidesWithCircle(x1, z1, v:GetPhysicsRadius(0)) and inst.components.combat:CanTarget(v) then
				if targets then
					targets[v] = true
				end
				if flashtargets then
					flashtargets[v] = true
				end
				inst.components.combat:DoAttack(v)
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

local actionhandlers =
{
	ActionHandler(ACTIONS.TAKEITEM, "rocklick"),
	ActionHandler(ACTIONS.PICKUP, "rocklick"),
	ActionHandler(ACTIONS.EAT, function(inst, action)
		--boss version eats directly off ground (no inventory)
		return IsBoss(inst) and "eat2" or "eat"
	end),
}

local function ChooseAttack(inst, target)
	target = target or inst.components.combat.target
	if target and target:IsValid() then
		if not IsBoss(inst) then
			inst.sg:GoToState("attack", target)
			return true
		elseif inst.sg.mem.dotaunt then
			inst.sg:GoToState("taunt")
			return true
		end

		local x, _, z = inst.Transform:GetWorldPosition()
		local x1, _, z1 = target.Transform:GetWorldPosition()
		local dx, dz = x1 - x, z1 - z

		local meleerange = TUNING.ROCKY_ATTACK_RANGE * TUNING.ROCKY_BOSS_SCALE + target:GetPhysicsRadius(0)
		local inmeleerange = dx * dx + dz * dz < meleerange * meleerange

		if not inst.components.timer:TimerExists("dashcd") then
			if not inmeleerange or inst.enraged then
				inst.sg:GoToState("dash_attack", target)
				return true
			end

			local dashchance = IsShadow(inst) and 0.4 or 0.2
			if target.components.locomotor then
				local vx, _, vz = target.Physics:GetVelocity()
				if (vx ~= 0 or vz ~= 0) and (dx ~= 0 or dz ~= 0) then
					local dir = math.atan2(-dz, dx)
					local dir1 = math.atan2(-vz, vx)
					if DiffAngleRad(dir, dir1) < QUARTERPI then
						--running away? higher chance to dash
						dashchance = 0.8
					end
				end
			end
			if math.random() < dashchance then
				inst.sg:GoToState("dash_attack", target)
				return true
			end
		end

		if inmeleerange then
			inst.sg:GoToState("snip_attack", target)
			return true
		end
	end
	return false
end

local events =
{
	CommonHandlers.OnFreeze(),
	CommonHandlers.OnDeath(),
	CommonHandlers.OnSleepEx(),
	CommonHandlers.OnWakeEx(),
	EventHandler("locomote", function(inst)
		if inst.components.locomotor:WantsToMoveForward() then
			if inst.sg:HasStateTag("idle") then
				inst.sg:GoToState("walk_start")
			end
		elseif inst.sg:HasStateTag("moving") then
			inst.sg:GoToState("walk_stop")
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			ChooseAttack(inst, data and data.target)
		end
	end),
	EventHandler("attacked", function(inst, data)
		if not (inst.components.health:IsDead() or (inst.sg:HasStateTag("busy") and not inst.sg:HasAnyStateTag("caninterrupt", "frozen"))) then
			if inst.sg:HasStateTag("stunned") then
				inst.sg.statemem.keepnofaced = true
				inst.sg.statemem.stunned = true
				inst.sg:GoToState("stun_hit")
			elseif not CommonHandlers.HitRecoveryDelay(inst) then
				inst.sg:GoToState("hit")
			end
		end
	end),
	EventHandler("entershield", function(inst)
		if not inst.components.health:IsDead() then
			inst.sg:GoToState("shield_start")
		end
	end),

	CommonHandlers.OnStalkerCorrupt(),

	--shadow boss
	EventHandler("enraged", function(inst)
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("taunt")
		else
			inst.sg.mem.dotaunt = true
		end
	end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			inst.components.locomotor:StopMoving()

			if type(pushanim) == "string" then
				inst.sg.statemem.pushanim = true
				inst.AnimState:PlayAnimation(pushanim)
			elseif pushanim and not inst.AnimState:AnimDone() then
				inst.sg.statemem.pushanim = true
			else
				local anim = inst.sg.mem.facings == 0 and "idle_loop_nofaced" or "idle_loop"
				if not inst.AnimState:IsCurrentAnimation(anim) then
					inst.AnimState:PlayAnimation(anim, true)
				end
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			end
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				if not inst.sg.statemem.pushanim then
					PlayLobFoley(inst)
				end
			end),
			FrameEvent(30, function(inst)
				if not inst.sg.statemem.pushanim then
					PlayLobFoley(inst)
				end
			end),
		},

		events =
		{
			--NOTE: we may be have several anims still queued
			EventHandler("animqueueover", function(inst)
				if inst.sg.statemem.pushanim and inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState((inst.IsTargetFightingBoss and inst:IsTargetFightingBoss() and math.random() < 0.75 and "taunt") or math.random() < 0.1 and "idle_tendril" or "idle")
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState((inst.IsTargetFightingBoss and inst:IsTargetFightingBoss() and math.random() < 0.75 and "taunt") or math.random() < 0.1 and "idle_tendril" or "idle")
		end,

		onexit = TryRestoreFourFaced,
	},

	State{
		name = "idle_tendril",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation(inst.sg.mem.facings == 0 and "idle_tendrils_nofaced" or "idle_tendrils")
		end,

		timeline =
		{
			FrameEvent(5, PlayLobIdleSound),
			FrameEvent(20, PlayLobIdleSound),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = TryRestoreFourFaced,
	},

	State{
		name = "eat",
		tags = { "idle", "doing", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("eat_rock_pre")
			inst.sg.statemem.bufferedaction = inst.bufferedaction
		end,

		timeline =
		{
			FrameEvent(0, PlayLobFoley),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.eating = true
					inst.sg:GoToState("eat_pst")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if not inst.sg.statemem.eating and inst.bufferedaction == inst.sg.statemem.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
	},

	State{
		name = "eat_pst",
		tags = { "idle", "doing", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("eat_rock_loop")
			inst.AnimState:PushAnimation("eat_rock_pst", false)
			inst.sg.statemem.bufferedaction = inst.bufferedaction
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				PlayLobIdleSound(inst)
				inst:PerformBufferedAction()
			end),
			FrameEvent(13, function(inst)
				PlayLobFoley(inst)
				inst.sg:RemoveStateTag("doing")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if inst.bufferedaction == inst.sg.statemem.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
	},

	State{
		name = "taunt",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("taunt")
			PlayLobFoley(inst)
			PlayLobSound(inst, "dontstarve/creatures/rocklobster/taunt")
			inst.sg.mem.dotaunt = nil
			if IsShadow(inst) then
				inst.components.combat.battlecryenabled = false
			end
		end,

		timeline =
		{
			FrameEvent(10, PlayLobFoley),
			FrameEvent(30, PlayLobFoley),
			FrameEvent(45, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(58, function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = TryRestoreFourFaced,
	},

	State{
		name = "rocklick",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("rocklick_pre")
			inst.AnimState:PushAnimation("rocklick_loop")
			inst.AnimState:PushAnimation("rocklick_pst", false)
			inst.sg.statemem.bufferedaction = inst.bufferedaction
		end,

		timeline =
		{
			FrameEvent(5, PlayLobFoley),
			FrameEvent(10, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/attack") end),
			FrameEvent(20, PlayLobFoley),
			FrameEvent(25, function(inst)
				inst:PerformBufferedAction()
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, PlayLobFoley),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if inst.bufferedaction == inst.sg.statemem.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
	},

	State{
		name = "shield_start",
		tags = { "busy", "hiding", "ignoredamageforshield" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("hide")
			PlayLobFoley(inst)
			PlayLobSound(inst, "dontstarve/creatures/rocklobster/hide")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				if inst.sg.statemem.exitshield then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.unshielding = true
					inst.sg:GoToState("shield_end")
					return
				end
				inst.sg:AddStateTag("shield")
				inst:SetBoulderState(true)
			end),
		},

		events =
		{
			EventHandler("exitshield", function(inst)
				if inst.sg:HasStateTag("shield") then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.unshielding = true
					inst.sg:GoToState("shield_end")
				else
					inst.sg.statemem.exitshield = true
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.shielding = true
					inst.sg:GoToState("shield")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if not (inst.sg.statemem.shielding or inst.sg.statemem.unshielding) then
				inst:SetBoulderState(false)
			end
		end,
	},

	State{
		name = "shield",
		tags = { "busy", "hiding", "shield" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("hide_loop") --it's just a static frame

			inst:SetBoulderState(true)
			inst.components.health:StartRegen(TUNING.ROCKY_REGEN_AMOUNT, TUNING.ROCKY_REGEN_PERIOD)
			inst.sg:SetTimeout(3)
		end,

		timeline =
		{
			FrameEvent(20, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/sleep") end),
		},

		events =
		{
			EventHandler("worked", function(inst, data)
				inst.AnimState:PlayAnimation("hit_shield")
				inst.AnimState:PushAnimation("hide_loop", false)
			end),
			EventHandler("exitshield", function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg.statemem.unshielding = true
				inst.sg:GoToState("shield_end")
			end),
			EventHandler("breakshield", function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("stun_pre")
			end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.keepnofaced = true
			inst.sg.statemem.shielding = true
			inst.sg:GoToState("shield")
		end,

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if not inst.sg.statemem.shielding then
				inst.components.health:StopRegen()
			end
			if not (inst.sg.statemem.shielding or inst.sg.statemem.unshielding) then
				inst:SetBoulderState(false)
				DoBoulderCD(inst)
			end
		end,
	},

	State{
		name = "shield_end",
		tags = { "busy", "hiding", "shield_end", "ignoredamageforshield", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("unhide")
			PlayLobFoley(inst)

			inst:SetBoulderState(true)
		end,

		timeline =
		{
			FrameEvent(10, PlayLobFoley),
			FrameEvent(16, function(inst)
				inst:SetBoulderState(false)
				inst.sg:RemoveStateTag("ignoredamageforshield")
				inst.sg.statemem.setbouldercd = true
				DoBoulderCD(inst)
			end),
			FrameEvent(21, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			inst:SetBoulderState(false)
			if not inst.sg.statemem.setbouldercd then
				DoBoulderCD(inst)
			end
		end,
	},

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("atk")
			inst.components.combat:StartAttack()
			inst.sg.statemem.target = target or inst.components.combat.target
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				PlayLobFoley(inst)
				PlayLobSound(inst, "dontstarve/creatures/rocklobster/attack")
			end),
			FrameEvent(5, PlayLobFoley),
			FrameEvent(8, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/clawsnap_small") end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/clawsnap_small") end),
			FrameEvent(18, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/attack_whoosh") end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/clawsnap") end),
			FrameEvent(25, function(inst)
				PlayLobFoley(inst)
				inst.components.combat:DoAttack(inst.sg.statemem.target)
			end),
			FrameEvent(30, PlayLobFoley),
			FrameEvent(38, function(inst)
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

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				PlayLobSound(inst, "dontstarve/creatures/rocklobster/hurt")
				PlayLobFoley(inst)
			end),
			FrameEvent(8, function(inst)
				if inst.sg.statemem.doattack and
					inst.sg.statemem.doattack:IsValid() and
					ChooseAttack(inst, inst.sg.statemem.doattack)
				then
					return
				end
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				inst.sg.statemem.doattack = data and data.target
			end),
		},
	},

	State{
		name = "death",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death")

			if not (inst.shadowthrall_parasite_hosted_death and TheWorld.components.shadowparasitemanager) then
				RemovePhysicsColliders(inst)
				inst:DropDeathLoot()
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				PlayLobSound(inst, "dontstarve/creatures/rocklobster/death")
				PlayLobSound(inst, "dontstarve/creatures/rocklobster/explode")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					if inst.shadowthrall_parasite_hosted_death and TheWorld.components.shadowparasitemanager then
						TheWorld.components.shadowparasitemanager:ReviveHosted(inst)
					else
						inst.sg:GoToState("corpse")
					end
				end
			end),
		},

		onexit = TryRestoreFourFaced,
	},

	State{
		name = "stun_pre",
		tags = { "stunned", "busy", "ignoredamageforshield" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("stun_pre")

			TryInitStunned(inst)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_pre") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_idle")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_idle",
		tags = { "stunned", "busy", "caninterrupt", "ignoredamageforshield" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			if not inst.AnimState:IsCurrentAnimation("stun_loop") then
				inst.AnimState:PlayAnimation("stun_loop", true)
			end
			TryInitStunned(inst)
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_idle") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.keepnofaced = true
			inst.sg.statemem.stunned = true
			inst.sg:GoToState(
				GetTime() - inst.sg.mem.stun_t0 < TUNING.ROCKY_STAGGER_TIME - 1 and
				"stun_idle" or
				"stun_pst")
		end,

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "hit", "busy", "ignoredamageforshield" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("stun_hit")
			TryInitStunned(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				PlayLobSound(inst, "dontstarve/creatures/rocklobster/hurt")
				PlayLobFoley(inst)
			end),

			FrameEvent(6, function(inst)
				if GetTime() - inst.sg.mem.stun_t0 < TUNING.ROCKY_STAGGER_TIME then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.stunned = true
					inst.sg:GoToState(
						GetTime() - inst.sg.mem.stun_t0 < TUNING.ROCKY_STAGGER_TIME - 1 and
						"stun_idle" or
						"stun_pst")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_pst",
		tags = { "stunned", "busy", "ignoredamageforshield", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("stun_pst")
			TryInitStunned(inst)
			if GetTime() - inst.sg.mem.stun_t0 < TUNING.ROCKY_STAGGER_TIME then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/stun_pst") end),

			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("stunned")
				inst.sg:RemoveStateTag("ignoredamageforshield")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			TryClearStunned(inst)
		end,
	},

	--rocky_boss

	State{
		name = "eat2",
		tags = { "busy", "caninterrupt", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("eat_rock_2_pre")
			inst.sg.statemem.bufferedaction = inst.bufferedaction
		end,

		timeline =
		{
			FrameEvent(6, PlayLobFoley),
			FrameEvent(9, function(inst)
				inst:PerformBufferedAction()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.eating = true
					inst.sg:GoToState("eat_pst")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreFourFaced(inst)
			if not inst.sg.statemem.eating and inst.bufferedaction == inst.sg.statemem.bufferedaction then
				inst:ClearBufferedAction()
			end
		end,
	},

	State{
		name = "snip_attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			SwitchToEightFaced(inst)
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("atk_snip")
			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
				--inst.sg.statemem.target = target
			end
		end,

		--[[onupdate = function(inst, dt)
			if dt > 0 then
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local lastdrot = inst.sg.statemem.drot
						if lastdrot ~= 0 then
							local rot = inst.Transform:GetRotation()
							local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
							local drot = ReduceAngle(rot1 - rot) * 0.5

							drot = lastdrot and
								math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot)) or
								math.clamp(drot, -3, 3)

							inst.Transform:SetRotation(rot + drot)
							inst.sg.statemem.lastdrot = drot
						end
					else
						inst.sg.statemem.target = nil
					end
				end
			end
		end,]]

		timeline =
		{
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/rocklobster_boss/atk_snip") end),

			FrameEvent(10, function(inst)
				--inst.sg.statemem.target = nil --stop tracking
				inst.Transform:SetRotation(SnapTo45s(inst.Transform:GetRotation()))
			end),
			FrameEvent(15, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()
				local theta = rot * DEGREES
				local scale = TUNING.ROCKY_BOSS_SCALE
				local dist = 2.8 * scale
				local x1 = x + math.cos(theta) * dist
				local z1 = z - math.sin(theta) * dist
				local halflen = 7 * scale --(*)
				local fx = SpawnPrefab("rocky_snip_fx")
				if IsShadow(inst) then
					fx.AnimState:SetBuild("rocky_boss_shadow_build")
				end
				fx.Transform:SetPosition(x1, y, z1)
				fx.Transform:SetRotation(rot)

				local hitbox = inst.sg.mem.snip_attack_hitbox
				if hitbox == nil then
					hitbox = HitBox(inst)
					inst.sg.mem.snip_attack_hitbox = hitbox

					hitbox:AddCircle(1.1 * scale, 0, 1.2 * scale)
					hitbox:AddCircle(2.1 * scale, 0, 0.8 * scale)

					local halfwid = 0.3 * scale
					hitbox:AddTriangle(dist, halfwid, dist, -halfwid, dist + halflen, 0)
					hitbox:AddTriangle(dist, halfwid, dist, -halfwid, dist - halflen, 0)
				end

				inst.sg.statemem.flashtargets = {}
				DoAOEAttack(inst, x1, z1, halflen, hitbox, nil, inst.sg.statemem.flashtargets) --(see *)
				FlashTargets(inst, 0.65)

				if _dbg_draw then
					hitbox:DebugDraw()
				end
			end),
			FrameEvent(16, function(inst) FlashTargets(inst, 0.6) end),
			FrameEvent(17, function(inst) FlashTargets(inst, 0.5) end),
			FrameEvent(18, function(inst) FlashTargets(inst, 0.3) end),
			FrameEvent(19, function(inst)
				ClearFlashTargets(inst)
				inst.sg.statemem.flashtargets = nil
			end),
			FrameEvent(28, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			--[[FrameEvent(33, function(inst)
				inst.sg:AddStateTag("canrotate")
			end),]]
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
			TryRestoreFourFaced(inst)
			if inst.sg.statemem.flashtargets then
				ClearFlashTargets(inst)
			end
		end,
	},

	State{
		name = "dash_attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			SwitchToEightFaced(inst)
			inst.components.combat:StartAttack()
			inst.AnimState:PlayAnimation("atk_dash")
			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
				inst.sg.statemem.target = target
				--inst.sg.statemem.tracking = true
			end
			inst:StartMirage()
			if inst.IsFading and inst:IsFading() then
				inst:StartFadeIn()
				inst.sg:AddStateTag("noattack")
				inst.sg:AddStateTag("invisible")
				inst.sg:AddStateTag("temp_invincible")
				inst.sg:AddStateTag("iframeskeepaggro")
			end
			if IsShadow(inst) then
				inst.sg.mem.numchaindashes = (inst.sg.mem.numchaindashes or 0) + 1
			end
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				--[[if inst.sg.statemem.tracking then
					local target = inst.sg.statemem.target
					if target:IsValid() then
						local lastdrot = inst.sg.statemem.drot
						if lastdrot ~= 0 then
							local rot = inst.Transform:GetRotation()
							local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
							local drot = ReduceAngle(rot1 - rot) * 0.5

							drot = lastdrot and
								math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot)) or
								math.clamp(drot, -2, 2)

							inst.Transform:SetRotation(rot + drot)
							inst.sg.statemem.lastdrot = drot
						end
					else
						inst.sg.statemem.tracking = nil
					end
				end]]

				local tpdist = inst.sg.statemem.tpdist
				if tpdist then
					local map = TheWorld.Map
					local tppos = inst.sg.statemem.tppos
					local blocked
					for d = 0.5, tpdist, 0.5 do
						if not map:IsPassableAtPoint(tppos.x + inst.sg.statemem.dx * d, 0, tppos.z + inst.sg.statemem.dz * d) then
							tpdist = d - 0.5
							inst.sg.statemem.tpdist = tpdist
							blocked = true
							break
						end
					end
					if not (blocked or map:IsPassableAtPoint(tppos.x + inst.sg.statemem.dx * tpdist, 0, tppos.z + inst.sg.statemem.dz * tpdist)) then
						tpdist = math.floor(tpdist * 2) * 0.5
						inst.sg.statemem.tpdist = tpdist
						blocked = true
					end

					if tpdist > 0 then
						tppos.x = tppos.x + inst.sg.statemem.dx * tpdist
						tppos.z = tppos.z + inst.sg.statemem.dz * tpdist
						inst.Physics:Teleport(tppos:Get())
					else
						tppos.x, tppos.y, tppos.z = inst.Transform:GetWorldPosition()
					end

					local speed = (blocked and 6 or tpdist * 4) * (inst.sg.statemem.tpspeedmult or 1)
					inst.Physics:SetMotorVelOverride(speed * inst.sg.statemem.vx, 0, speed * inst.sg.statemem.vz)

					local r = 1.2 * TUNING.ROCKY_BOSS_SCALE
					if inst.sg.statemem.tpfirst then
						tpdist = tpdist - 2 * r
					end
					if tpdist > 0 then
						local hitbox = HitBox()
						hitbox:AddCircle(0, 0, r)
						if tpdist > 0 then
							hitbox:AddCircle(-tpdist, 0, r)
							hitbox:AddRectangle(-tpdist, -r, 0, r)
						end
						hitbox:SetWorldXZ(tppos.x, tppos.z)
						hitbox:SetWorldRot(inst.sg.statemem.rot)

						DoAOEAttack(inst, tppos.x - 0.5 * inst.sg.statemem.dx * tpdist, tppos.z - 0.5 * inst.sg.statemem.dz * tpdist, tpdist / 2 + r, hitbox, inst.sg.statemem.targets, inst.sg.statemem.flashtargets)

						if _dbg_draw then
							hitbox:SetOwner(inst)
							local rot = inst.Transform:GetRotation()
							inst.Transform:SetRotation(inst.sg.statemem.rot)
							hitbox:DebugDraw()
							inst.Transform:SetRotation(rot)
							hitbox:SetOwner(nil)
						end
					end
				end

				local decel = inst.sg.statemem.decel
				if decel then
					if decel < 1 then
						inst.Physics:ClearMotorVelOverride()
						inst.Physics:Stop()
						inst.sg.statemem.decel = nil
						inst.sg:RemoveStateTag("jumping")
						ToggleOnCharacterCollisions(inst)
					else
						inst.Physics:SetMotorVelOverride(decel * inst.sg.statemem.vx, 0, decel * inst.sg.statemem.vz)
						inst.sg.statemem.decel = decel / 2
					end
				end

				if inst.sg.statemem.flash then
					FlashTargets(inst, inst.sg.statemem.flash)
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/rocklobster_boss/atk_dash") end),
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/rocklobster_boss/atk_snip", "snip") end),
			FrameEvent(7, function(inst)
				inst.SoundEmitter:KillSound("snip")
				inst.SoundEmitter:PlaySound("dontstarve/creatures/rocklobster/rocklobster_boss/atk_snip")
			end),

			FrameEvent(4, function(inst)
				if inst.sg:HasStateTag("noattack") then
					inst.sg:RemoveStateTag("noattack")
					inst.sg:RemoveStateTag("invisible")
					inst.sg:RemoveStateTag("temp_invincible")
					inst.sg:RemoveStateTag("iframeskeepaggro")
				end
				inst.DynamicShadow:Enable(true)
			end),
			FrameEvent(12, function(inst)
				--inst.sg.statemem.tracking = nil

				inst.sg.statemem.rot = inst.Transform:GetRotation()
				local rot = SnapTo45s(inst.sg.statemem.rot)
				inst.Transform:SetRotation(rot)

				local theta = inst.sg.statemem.rot * DEGREES
				inst.sg.statemem.dx = math.cos(theta)
				inst.sg.statemem.dz = -math.sin(theta)

				theta = ReduceAngle(rot - inst.sg.statemem.rot) * DEGREES
				inst.sg.statemem.vx = math.cos(theta)
				inst.sg.statemem.vz = math.sin(theta)

				inst.sg.statemem.tpfirst = true
				inst.sg.statemem.tpdist = (inst.GetDashRange and inst:GetDashRange() or TUNING.ROCKY_BOSS_DASH_RANGE) * 2 / 3 * TUNING.ROCKY_BOSS_SCALE
				inst.sg.statemem.tppos = inst:GetPosition()
				inst.sg.statemem.targets = {}
				inst.sg.statemem.flashtargets = {}
				inst.sg.statemem.flash = 0.375
				ToggleOffCharacterCollisions(inst)
				inst.sg:AddStateTag("jumping")

				local fx = SpawnPrefab("rocky_dash_fx")
				if IsShadow(inst) then
					fx.AnimState:SetBuild("rocky_boss_shadow_build")
				end
				fx.Transform:SetPosition(inst.sg.statemem.tppos:Get())
				fx.Transform:SetRotation(inst.sg.statemem.rot)
				fx.target:set(inst)
				inst.sg.statemem.dashfx = fx

				inst.components.timer:StopTimer("dashcd")
				inst.components.timer:StartTimer("dashcd", TUNING.ROCKY_BOSS_DASH_CD)
			end),
			FrameEvent(13, function(inst)
				inst.sg.statemem.tpfirst = nil
				inst.sg.statemem.tpdist = inst.sg.statemem.tpdist / 2
				inst.sg.statemem.decel = inst.sg.statemem.tpdist * 4
				inst.sg.statemem.flash = 0.35

				if inst.sg.mem.numchaindashes then
					local maxchain = (inst.enraged and 5) or (inst.endenraged and 3) or 2
					if inst.sg.mem.numchaindashes < maxchain then
						local target = inst.sg.statemem.target
						if target and target:IsValid() and not IsEntityDeadOrGhost(target) then
							inst.sg.statemem.decel = nil
							inst.sg.statemem.tpspeedmult = 2
							inst.sg.statemem.shouldchaindash = true
						end
					end
				end
			end),
			FrameEvent(14, function(inst)
				inst.sg.statemem.tpdist = nil
				inst.sg.statemem.tpspeedmult = nil
				inst.sg.statemem.flash = 0.3
			end),
			FrameEvent(15, function(inst)
				inst.sg.statemem.flash = 0.2
			end),
			FrameEvent(16, function(inst)
				ClearFlashTargets(inst)
				inst.sg.statemem.flashtargets = nil
				inst.sg.statemem.flash = nil
			end),
			FrameEvent(17, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()
				local theta = rot * DEGREES
				local scale = TUNING.ROCKY_BOSS_SCALE
				local dist = 3.6 * scale
				local x1 = x + math.cos(theta) * dist
				local z1 = z - math.sin(theta) * dist
				local halflen = 7 * scale --(*)
				local fx = SpawnPrefab("rocky_snip_fx")
				if IsShadow(inst) then
					fx.AnimState:SetBuild("rocky_boss_shadow_build")
				end
				fx.Transform:SetPosition(x1, y, z1)
				fx.Transform:SetRotation(rot)

				local hitbox = inst.sg.mem.dash_snip_attack_hitbox
				if hitbox == nil then
					hitbox = HitBox(inst)
					inst.sg.mem.dash_snip_attack_hitbox = hitbox

					hitbox:AddCircle(0.5, 0, 1.2 * scale)
					hitbox:AddCircle(1.9 * scale, 0, 1.2 * scale)
					hitbox:AddCircle(2.9 * scale, 0, 0.8 * scale)

					local halfwid = 0.3 * scale
					hitbox:AddTriangle(dist, halfwid, dist, -halfwid, dist + halflen, 0)
					hitbox:AddTriangle(dist, halfwid, dist, -halfwid, dist - halflen, 0)
				end

				inst.sg.statemem.flashtargets = {}
				DoAOEAttack(inst, x1, z1, halflen, hitbox, inst.sg.statemem.targets, inst.sg.statemem.flashtargets) --(see * for halflen)
				FlashTargets(inst, 0.65)

				if _dbg_draw then
					hitbox:DebugDraw()
				end
			end),
			FrameEvent(18, function(inst) FlashTargets(inst, 0.6) end),
			FrameEvent(19, function(inst) FlashTargets(inst, 0.5) end),
			FrameEvent(20, function(inst) FlashTargets(inst, 0.3) end),
			FrameEvent(21, function(inst)
				ClearFlashTargets(inst)
				inst.sg.statemem.flashtargets = nil
				if inst.sg.statemem.shouldchaindash then
					inst:StartFadeOut()
				end
			end),
			FrameEvent(27, function(inst)
				if inst.sg.statemem.shouldchaindash then
					inst.sg:AddStateTag("noattack")
					inst.sg:AddStateTag("invisible")
					inst.sg:AddStateTag("temp_invincible")
					inst.sg:AddStateTag("iframeskeepaggro")
					inst.DynamicShadow:Enable(false)
				end
			end),
			FrameEvent(36, function(inst)
				if inst.sg.statemem.shouldchaindash then
					inst.sg.statemem.keepeightfaced = true
					inst.sg.statemem.chaindashing = true
					local target = inst.sg.statemem.target
					if target and target:IsValid() then
						inst.sg:GoToState("dash_attack", inst.sg.statemem.target)
					else
						inst.Transform:SetRotation(inst.sg.statemem.rot + 180)
						inst.sg:GoToState("dash_attack")
					end
				end
			end),
			FrameEvent(38, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			--[[FrameEvent(44, function(inst)
				inst.sg:AddStateTag("canrotate")
			end),]]
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
			inst.SoundEmitter:KillSound("snip")
			if inst.sg.statemem.dashfx then
				inst.sg.statemem.dashfx:Remove()
			end
			TryRestoreFourFaced(inst)
			if inst.sg.statemem.flashtargets then
				ClearFlashTargets(inst)
			end
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			ToggleOnCharacterCollisions(inst)

			if not inst.sg.statemem.chaindashing then
				if inst.sg.statemem.shouldchaindash then
					inst.DynamicShadow:Enable(true)
					inst:ResetFade()
				end
				if inst.sg.mem.numchaindashes then
					if inst.enraged and inst.sg.mem.numchaindashes >= 3 then
						inst.enraged = nil
						inst.endenraged = true
					end
					inst.sg.mem.numchaindashes = 0
				end
			end
		end,
	},
}

CommonStates.AddWalkStates(states,
{
	starttimeline =
	{
		FrameEvent(0, PlayLobFoley),
	},
	walktimeline =
	{
		FrameEvent(1, PlayLobFootstep),
		FrameEvent(8, PlayLobFootstep),
		FrameEvent(12, PlayLobFootstep),
		FrameEvent(15, PlayLobFoley),
		FrameEvent(26, PlayLobFootstep),
		FrameEvent(30, PlayLobFootstep),
	},
	endtimeline =
	{
		FrameEvent(0, PlayLobFoley),
	},
})

CommonStates.AddSleepExStates(states,
{
	starttimeline =
	{
		FrameEvent(0, PlayLobFoley),
		FrameEvent(9, function(inst)
			inst.sg:RemoveStateTag("caninterrupt")
		end),
	},
	sleeptimeline =
	{
		FrameEvent(0, function(inst) PlayLobSound(inst, "dontstarve/creatures/rocklobster/sleep") end),
		FrameEvent(20, PlayLobFoley),
	},
	waketimeline =
	{
		FrameEvent(0, PlayLobFoley),
		CommonHandlers.OnNoSleepFrameEvent(27, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(37, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
},
{
	onsleep = function(inst)
		inst.sg:AddStateTag("caninterrupt")
		SwitchToNoFaced(inst)
	end,
	onexitsleep = TryRestoreFourFaced,
	onsleeping = SwitchToNoFaced,
	onexitsleeping = TryRestoreFourFaced,
	onwake = function(inst)
		inst.sg:AddStateTag("canrotate")
		SwitchToNoFaced(inst)
	end,
	onexitwake = TryRestoreFourFaced,
})

CommonStates.AddFrozenStates(states,
	function(inst)
		SwitchToNoFaced(inst)
		if inst.sg:HasStateTag("thawing") then
			inst.sg:AddStateTag("canrotate")
		end
	end,
	TryRestoreFourFaced)
CommonStates.AddParasiteReviveState(states, nil, {
	onenter = function(inst)
		SwitchToNoFaced(inst)
		inst.sg:AddStateTag("canrotate")
	end,
	onexit = TryRestoreFourFaced,
})
CommonStates.AddCorpseStates(states, nil, { corpseonenter = SwitchToNoFaced })
CommonStates.AddStalkerCorruptionStates(states,
{
	corruption_pre =
	{
		--#SFX
		-- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

		FrameEvent(43, function(inst)
			inst.AnimState:SetMultColour(0, 0, 0, 1)
		end),
	},
	corruption_pst =
	{
		--#SFX
		-- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

		FrameEvent(11, function(inst)
			inst.AnimState:SetMultColour(1, 1, 1, 1)
		end),
	},
},
{
	preonenter = function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_a") end,
	pstonenter = function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_b") end,
})
CommonStates.AddInitState(states, "idle")

return StateGraph("rocky", states, events, "init", actionhandlers)