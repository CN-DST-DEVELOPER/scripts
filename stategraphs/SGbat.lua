require("stategraphs/commonstates")

local function IsBoss(inst)
	return inst.components.inventory == nil
end

local function IsShadow(inst)
	return inst:HasTag("shadowthrall")
end

local function PlayBatSound(inst, sound)
	if IsShadow(inst) then
		inst.sg.mem.soundparams = inst.sg.mem.soundparams or { bat_type = 0.95 }
		inst.SoundEmitter:PlaySoundWithParams(sound, inst.sg.mem.soundparams)
	elseif IsBoss(inst) then
		inst.sg.mem.soundparams = inst.sg.mem.soundparams or { bat_type = 0.5 }
		inst.SoundEmitter:PlaySoundWithParams(sound, inst.sg.mem.soundparams)
	else
		inst.SoundEmitter:PlaySound(sound)
	end
end

local actionhandlers =
{
	ActionHandler(ACTIONS.GOHOME, function(inst)
		local ba = inst:GetBufferedAction()
		-- do_not_locomote set by boss bat when it wants to go home after acid wave, so fly away
		return ba and (((ba.target and ba.target:HasTag("sinkhole")) or ba.options.do_not_locomote) and "flyaway")
				or "action"
	end),
	ActionHandler(ACTIONS.EAT, function(inst)
		local ba = inst:GetBufferedAction()
		return (ba and ba.target and ba.target.prefab == "nitre" and "chew_ground")
			or (IsBoss(inst) and "eat_enter")
			or "eat_loop"
	end),
	ActionHandler(ACTIONS.PICKUP, "eat_enter"),
	ActionHandler(ACTIONS.STEAL, "eat_enter"),
}

local function CanHatTarget(inst, target)
	if target.components.inventory and
		(	target.components.inventory:IsOpenedBy(target) or
			target:HasTag("canwearhat")
		)
	then
		local hat = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		if not (hat and hat:HasTag("monsterhat")) then
			return true, hat
		end
	end
	return false
end

local function CanClone(inst)
	return not inst.components.health:IsDead()
		and inst.components.health:GetPercent() < TUNING.BAT_BOSS_SHADOW_CLONE_THRESHOLD
		and inst.components.combat:HasTarget()
		and inst.components.entitytracker:GetEntity("clone") == nil
end

local function TryClone(inst)
	if inst.sg.mem.doclone and GetTime() - inst.sg.mem.doclone > TUNING.BAT_BOSS_SHADOW_CLONE_DELAY then
		inst.sg:GoToState("clone_pre")
		return true
	end
	return false
end

local function TryShareCloneAttackCooldown(inst, target)
	local clone = inst.components.entitytracker and inst.components.entitytracker:GetEntity("clone")
	if clone and clone.components.combat:TargetIs(target) then
		local cd = clone.components.combat:GetCooldown()
		local clonecd = TUNING.BAT_BOSS_ATTACK_PERIOD * 0.75
		if cd < clonecd then
			clone.components.combat:OverrideCooldown(clonecd)
		end
	end
end

local function ChooseAttack(inst, target)
	target = target or inst.components.combat.target
	if target and target:IsValid() then
		if not IsBoss(inst) then
			inst.sg:GoToState("attack", target)
			return true
		end

		if TryClone(inst) then
			return true
		end

		local x, _, z = inst.Transform:GetWorldPosition()
		local x1, _, z1 = target.Transform:GetWorldPosition()
		local dx, dz = x1 - x, z1 - z

		local meleerange = TUNING.BAT_BOSS_ATTACK_DIST + target:GetPhysicsRadius(0)
		local inmeleerange = dx * dx + dz * dz < meleerange * meleerange

		if not inst.components.timer:TimerExists("chompcd") and CanHatTarget(inst, target) then
			if not inmeleerange then
				inst.sg:GoToState("chomp_attack", target)
				return true
			end

			local chompchance = IsShadow(inst) and 0.75 or 0.6
			if target.components.locomotor then
				local vx, _, vz = target.Physics:GetVelocity()
				if (vx ~= 0 or vz ~= 0) and (dx ~= 0 or dz ~= 0) then
					local dir = math.atan2(-dz, dx)
					local dir1 = math.atan2(-vz, vx)
					if DiffAngleRad(dir, dir1) < QUARTERPI then
						--running away? higher chance to chomp
						chompchance = 1
					end
				end
			end
			if chompchance >= 1 or math.random() < chompchance then
				inst.sg:GoToState("chomp_attack", target)
				return true
			end
		end

		if inmeleerange then
			inst.sg:GoToState("attack", target)
			return true
		end
	end
	return false
end

local events =
{
	EventHandler("fly_back", function(inst, data)
		if not inst.components.health:IsDead() then
			inst.sg:GoToState("flyback")
		end
	end),
	EventHandler("fly_away", function(inst, data)
		if not inst.components.health:IsDead() then
			inst.sg:GoToState("flyaway")
		end
	end),
	CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
	CommonHandlers.OnSleepEx(),
	CommonHandlers.OnWakeEx(),

	EventHandler("death", function(inst, data)
		if not inst.sg:HasStateTag("dead") then
    	    local use_corpse_state = CommonHandlers.ShouldUseCorpseStateOnLoad(inst, data.cause)
			if IsBoss(inst) and not IsShadow(inst) then
				inst.sg:GoToState("death_hat", data)
    	    elseif use_corpse_state then
    	        inst.sg:GoToState("corpse", true)
    	    else
    	        inst.sg:GoToState("death", data)
    	    end
		end
	end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),

	EventHandler("dohowl", function(inst)
		if not inst.components.health:IsDead() then
			if not inst.sg:HasStateTag("busy") then
				inst.sg:GoToState("howl")
			else
				inst.sg.mem.dohowl = true
			end
		end
	end),
	EventHandler("doclone", function(inst)
		if CanClone(inst) and inst.sg.mem.doclone == nil then
			inst.sg.mem.doclone = GetTime()
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			ChooseAttack(inst, data and data.target)
		end
	end),
	EventHandler("attacked", function(inst, data)
		if inst.components.health and not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("busy") or inst.sg:HasAnyStateTag("caninterrupt", "frozen") then
				if inst.sg:HasStateTag("stunned") then
					inst.sg.statemem.stunned = true
					inst.sg:GoToState("stun_hit")
				elseif not CommonHandlers.HitRecoveryDelay(inst) then
					inst.sg:GoToState("hit")
				end
			end
		end
	end),

	CommonHandlers.OnStalkerCorrupt(),
}

local function DoChewSound(inst)
	PlayBatSound(inst, "dontstarve/creatures/bat/flap") -- Always flap.

	if inst.sg.statemem.chewsounds then
		if inst.sg.statemem.chewsounds > 1 then
			inst.sg.statemem.chewsounds = inst.sg.statemem.chewsounds - 1
			PlayBatSound(inst, "dontstarve/creatures/bat/chew")
		else
			inst.sg.statemem.chewsounds = nil
		end
	end
end

--Keep 6-faced in Transform component; anim with no facings will behave like 2-faced.
local function SwitchToNoFaced(inst)
	inst.sg.mem.nofaced = true
end

local function TryRestoreSixFaced(inst)
	if not inst.sg.statemem.keepnofaced then
		inst.sg.mem.nofaced = nil
	end
end

local function TryHat(inst, target)
	if inst:IsNear(target, 0.7) then
		local canhat, oldhat = CanHatTarget(inst, target)
		if canhat then
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			if oldhat then
				target.components.inventory:DropItem(oldhat, true, true)
			end
			target.components.inventory:Equip(inst)

			if inst.fx then
				inst.fx:TriggerChompFx()
			end

			--ignorehitrange and damage configured via OnEquip/OnUnequip
			--use instancemult for stronger initial chomp
			inst.components.combat:DoAttack(target, nil, nil, nil, TUNING.BAT_BOSS_CHOMP_INITIAL_MULT)

			return true
		end
	end
	return false
end

local function TryInitStunned(inst)
	if inst.sg.mem.stun_t0 == nil then
		inst.sg.mem.stun_t0 = GetTime()
	end
	if not inst.SoundEmitter:PlayingSound("stun_loop") then
		inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/stun_LP", "stun_loop")
		if IsShadow(inst) then
			inst.SoundEmitter:SetParameter("stun_loop", "bat_type", 0.95)
		end
	end
end

local function TryClearStunned(inst)
	if not inst.sg.statemem.stunned then
		inst.sg.mem.stun_t0 = nil
	end
	inst.SoundEmitter:KillSound("stun_loop")
end

local function StartChompCooldown(inst, mult)
	local cd = (IsShadow(inst) and TUNING.BAT_BOSS_SHADOW_CHOMP_CD or TUNING.BAT_BOSS_CHOMP_CD) * (mult or 1)
	local remaining = inst.components.timer:GetTimeLeft("chompcd")
	if remaining == nil or remaining < cd then
		inst.components.timer:StopTimer("chompcd")
		inst.components.timer:StartTimer("chompcd", cd)
	end
	inst.sg.mem.chompfailcount = 0
end

local function IncChompFails(inst, target)
	local didcooldown = false

	inst.sg.mem.chompfailcount = (inst.sg.mem.chompfailcount or 0) + 1
	if inst.sg.mem.chompfailcount >= 3 then
		StartChompCooldown(inst)
		didcooldown = true
	end

	if target then
		local clone = inst.components.entitytracker and inst.components.entitytracker:GetEntity("clone")
		if clone and
			clone.components.combat:TargetIs(target) and
			not clone.components.equippable:IsEquipped()
		then
			if didcooldown then
				StartChompCooldown(clone, 0.9)
			elseif IncChompFails(clone, nil) then
				StartChompCooldown(inst, 0.9)
				didcooldown = true
			end
		end
	end

	return didcooldown
end

local function DecChompFails(inst)
	if inst.sg.mem.chompfailcount then
		inst.sg.mem.chompfailcount = math.max(0, inst.sg.mem.chompfailcount - 1)
	end
end

local BATCAVE_MUST_TAGS = { "batcave" }
local function TrySummon(inst)
	inst.sg.mem.dohowl = nil
	inst.components.timer:StopTimer("howlcd")
	inst.components.timer:StartTimer("howlcd", TUNING.BAT_BOSS_SUMMON_PERIOD)

	local x, y, z = inst.Transform:GetWorldPosition()
	local target = inst.components.combat.target
	-- spawn bats from the bat caves first

	for i, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.BAT_BOSS_SEE_BATS_DIST, BATCAVE_MUST_TAGS)) do
		if v.components.childspawner then
			v.components.childspawner:ReleaseAllChildren(target)
		end
	end

	-- then we can spawn remainder from ceiling

	local num = inst:NumBatsToSpawn()

	local function SpawnBat()
		local r = 3 + math.random() * 3
		local theta = math.random() * TWOPI

		local bat = SpawnPrefab("bat")
		bat.Transform:SetPosition(x + r * math.cos(theta), 0, z - r * math.sin(theta))
		bat.Transform:SetRotation(math.random() * 360)
		bat:PushEventImmediate("fly_back")

		if target then
			bat.components.combat:SuggestTarget(target)
		end
	end

	for i = 1, num do
		inst:DoTaskInTime(i/num * math.random(), SpawnBat)
	end
end

local function SetBossShadowScale(inst, scale)
    inst.DynamicShadow:SetSize(2.4 * scale, 1.4 * scale)
end

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			if inst.sg.mem.dohowl then
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("howl")
				return
			elseif TryClone(inst) then
				return
			end

			inst.components.locomotor:StopMoving()

			if type(pushanim) == "string" then
				inst.sg.statemem.pushanim = true
				inst.AnimState:PlayAnimation(pushanim)
			elseif pushanim and not inst.AnimState:AnimDone() then
				inst.sg.statemem.pushanim = true
			else
				local anim = inst.sg.mem.nofaced and "fly_loop_nofaced" or "fly_loop"
				if not inst.AnimState:IsCurrentAnimation(anim) or inst.AnimState:AnimDone() then
					inst.AnimState:PlayAnimation(anim, true)
				end
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			end
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				if not inst.sg.statemem.pushanim then
					PlayBatSound(inst, "dontstarve/creatures/bat/flap")
				end
			end),
			FrameEvent(17, function(inst)
				if not inst.sg.statemem.pushanim then
					PlayBatSound(inst, "dontstarve/creatures/bat/flap")
				end
			end),
		},

		events =
		{
			--NOTE: we may be have several anims still queued
			EventHandler("animqueueover", function(inst)
				if inst.sg.statemem.pushanim and inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "action",

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("fly_loop", true)
			inst:PerformBufferedAction()
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
		name = "flyaway",
		tags = { "flight", "busy", "noelectrocute", "noattack", "temp_invincible", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()

			inst.DynamicShadow:Enable(false)

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("fly_away_pre")
			inst.AnimState:PushAnimation("fly_away_loop")

			inst.Physics:SetMotorVel(0, 10 + math.random() * 2, 0)
		end,

		onupdate = function(inst)
			inst.Physics:SetMotorVel(0, 10 + math.random() * 2, 0)
		end,

		timeline =
		{
			FrameEvent(6, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(13, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(23, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(33, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(41, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(51, function(inst)
				inst:PerformBufferedAction()
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			inst.DynamicShadow:Enable(true)
		end,
	},

	State{
		name = "flyback",
		tags = { "flight", "busy", "noelectrocute", "noattack", "temp_invincible", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.DynamicShadow:Enable(false)

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("fly_back_loop", true)

			local x, _, z = inst.Transform:GetWorldPosition()
			inst.Physics:Teleport(x, 15, z)
			inst.Physics:SetMotorVel(0, -10 + math.random() * 2, 0)
		end,

		onupdate = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			if y <= 0.1 or inst:IsAsleep() then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.Physics:Teleport(x, 0, z)
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("flyback_pst")
				return
			end

			inst.Physics:SetMotorVel(0, -10 + math.random() * 2, 0)
		end,

		timeline =
		{
			FrameEvent(3, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(14, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(24, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(34, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(41, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			TryRestoreSixFaced(inst)
			inst.DynamicShadow:Enable(true)
		end,
	},

	State{
		name = "flyback_pst",
		tags = { "busy", "caninterrupt", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("fly_back_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "taunt",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			if inst.sg.mem.dohowl then
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("howl")
				return
			elseif TryClone(inst) then
				return
			end

			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("taunt")
		end,

		timeline =
		{
			FrameEvent(1, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/taunt") end),
			FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(18, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(28, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(43, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),

			FrameEvent(40, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(45, function(inst)
				inst.sg:RemoveStateTag("busy")
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

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "quicktaunt",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("taunt")
			inst.AnimState:SetFrame(14)
		end,

		timeline =
		{
			FrameEvent(0--[[1 - 14]], function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/taunt") end),
			--FrameEvent(7 - 14, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(18 - 14, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(28 - 14, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(43 - 14, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),

			FrameEvent(40 - 14, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(45 - 14, function(inst)
				if not inst.sg.mem.dohowl then
					inst.sg:RemoveStateTag("busy")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.sg.mem.dohowl then
						inst.sg.statemem.keepnofaced = true
						inst.sg:GoToState("howl", 8)
					else
						inst.sg.statemem.keepnofaced = true
						inst.sg:GoToState("idle")
					end
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "eat_enter",
		tags = { "busy", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("eat")
		end,

		timeline =
		{
			FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(8, function(inst)
				PlayBatSound(inst, "dontstarve/creatures/bat/bite")
				--take food
				if inst:PerformBufferedAction() then
					if IsBoss(inst) then
						inst.sg.statemem.quickeat = true
					end
				end
			end),
			FrameEvent(16, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(17, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					if inst.sg.statemem.quickeat then
						inst.sg:GoToState("eat_loop", true)
					else
						inst.sg:GoToState("idle")
					end
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "eat_loop",
		tags = { "busy", "caninterrupt", "canrotate" },

		onenter = function(inst, quick)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("eat_loop", true)
			if quick then
				inst.sg.statemem.quick = true
				inst.sg:SetTimeout(0.75 + math.random() * 0.5)
			else
				inst.sg:SetTimeout(1 + math.random() * 2)
			end
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				PlayBatSound(inst, "dontstarve/creatures/bat/flap")
				PlayBatSound(inst, "dontstarve/creatures/bat/chew")
			end),
			FrameEvent(17, function(inst)
				PlayBatSound(inst, "dontstarve/creatures/bat/flap")
				PlayBatSound(inst, "dontstarve/creatures/bat/chew")
			end),
		},

		ontimeout = function(inst)
			if not inst.sg.statemem.quick then
				inst.lastmeal = GetTime()
				inst:PerformBufferedAction()
			end
			inst.sg.statemem.keepnofaced = true
			inst.sg:GoToState("idle")
		end,

		events =
		{
			EventHandler("attacked", function(inst)
				--drop food
				if inst.components.inventory then
					inst.components.inventory:DropEverything()
				end
				inst.sg:GoToState("hit")
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "chew_ground",
		tags = { "busy", "caninterrupt", "canrotate" },

		onenter = function(inst, data)
			inst.components.locomotor:StopMoving()

			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("chew_pre")

			local chews = math.min(data and data.chews or math.random(14, 18), 18)
			for i = 1, chews do
				inst.AnimState:PushAnimation("chew_loop")
			end

			inst.AnimState:PushAnimation("chew_pst", false)

			inst.sg.statemem.quick = data and data.quick
			inst.sg.statemem.chewsounds = chews
		end,

		timeline =
		{
			FrameEvent(6, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(12 + 9 * 0, DoChewSound),
			FrameEvent(12 + 9 * 1, DoChewSound),
			FrameEvent(12 + 9 * 2, DoChewSound),
			FrameEvent(12 + 9 * 3, DoChewSound),
			FrameEvent(12 + 9 * 4, DoChewSound),
			FrameEvent(12 + 9 * 5, DoChewSound),
			FrameEvent(12 + 9 * 6, DoChewSound),
			FrameEvent(12 + 9 * 7, DoChewSound),
			FrameEvent(12 + 9 * 8, DoChewSound),
			FrameEvent(12 + 9 * 9, DoChewSound),
			FrameEvent(12 + 9 * 10, DoChewSound),
			FrameEvent(12 + 9 * 11, DoChewSound),
			FrameEvent(12 + 9 * 12, DoChewSound),
			FrameEvent(12 + 9 * 13, DoChewSound),
			FrameEvent(12 + 9 * 14, DoChewSound),
			FrameEvent(12 + 9 * 15, DoChewSound),
			FrameEvent(12 + 9 * 16, DoChewSound),
			FrameEvent(12 + 9 * 17, DoChewSound),

			FrameEvent(8, function(inst)
				if inst.sg.statemem.quick then
					if inst:PerformBufferedAction() then
						inst.lastmeal = GetTime()
					else
						inst.AnimState:PlayAnimation("chew_pst")
					end
				end
			end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					if not inst.sg.statemem.quick then
						inst.lastmeal = GetTime()
						inst:PerformBufferedAction()
					end
					inst.sg.statemem.keepnofaced  = true
					inst.sg:GoToState("idle")
				end
			end),
			EventHandler("attacked", function(inst)
				--drop food
				if inst.components.inventory then
					inst.components.inventory:DropEverything()
				end
				inst.sg:GoToState("hit")
			end),
		},

		onexit = TryRestoreSixFaced,
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
			FrameEvent(1, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/hurt") end),
			FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(9, function(inst)
				if not (inst.sg.statemem.doattack and inst.sg.statemem.doattack:IsValid()) then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(10, function(inst)
				if inst.sg.mem.dohowl then
					inst.sg:GoToState("howl")
					return
				elseif TryClone(inst) then
					return
				elseif inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				end
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if inst.sg:HasStateTag("busy") and data and data.target and data.target:IsValid() then
					inst.sg.statemem.doattack = data.target
					inst.sg:RemoveStateTag("caninterrupt")
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
		name = "attack",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("atk")

			inst.components.combat:StartAttack()

			DecChompFails(inst)

			inst.sg.statemem.speedmult = 1

			if target and target:IsValid() then
				TryShareCloneAttackCooldown(inst, target)
				inst.sg.statemem.target = target

				local x, _, z = inst.Transform:GetWorldPosition()
				local x1, _, z1 = target.Transform:GetWorldPosition()
				local dx = x1 - x
				local dz = z1 - z
				if dx ~= 0 or dz ~= 0 then
					inst.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
				end

				if target.components.locomotor == nil then
					if dx ~= 0 or dz ~= 0 then
						local dist = IsBoss(inst) and 1.5333 or 1.025
						local dist1 = math.sqrt(dx * dx + dz * dz) - inst:GetPhysicsRadius(0) - target:GetPhysicsRadius(0)
						inst.sg.statemem.speedmult = math.clamp(dist1, 0, dist) / dist
					else
						inst.sg.statemem.speedmult = 0
					end
				end
			end

			inst.Physics:SetMotorVelOverride(1.5 * inst.sg.statemem.speedmult, 0, 0)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.Physics:SetMotorVelOverride((IsBoss(inst) and 7 or 6)  * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(8, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/bite") end),
			FrameEvent(10, function(inst)
				inst.Physics:SetMotorVelOverride(2 * inst.sg.statemem.speedmult, 0, 0)
				PlayBatSound(inst, "dontstarve/creatures/bat/flap")
				inst.components.combat:DoAttack(inst.sg.statemem.target)
			end),
			FrameEvent(11, function(inst)
				inst.Physics:SetMotorVelOverride(1 * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(12, function(inst)
				inst.Physics:SetMotorVelOverride(0.5 * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(13, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(15, function(inst)
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
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	},

	--bat_boss

	State{
		name = "howl",
		tags = { "busy", "canrotate" },

		onenter = function(inst, skipframes)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("howl_pre")
			inst.sg.mem.dohowl = nil

			if skipframes then
				inst.AnimState:SetFrame(skipframes)
				inst.sg:FastForward(skipframes * FRAMES)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("howl_loop", { count = 2 })
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "howl_loop",
		tags = { "busy", "canrotate" },

		onenter = function(inst, data)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("howl_loop")
			if data ~= nil then
				inst.sg.statemem.count = data.count or nil
				if data.caninterrupt then
					inst.sg:AddStateTag("caninterrupt")
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/wolfbat/howl") end),

			FrameEvent(8, TrySummon),
			FrameEvent(28, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					if inst.sg.statemem.count ~= nil
						and inst.sg.statemem.count > 1
						and inst:NumBatsToSpawn() > 0 then
                	    inst.sg:GoToState("howl_loop", { count=inst.sg.statemem.count - 1, caninterrupt = true })
                	else
                	    inst.sg:GoToState("howl_pst")
                	end
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "howl_pst",
		tags = { "busy", "canrotate", "caninterrupt" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("howl_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
                	inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "chomp_attack",
		tags = { "chomp", "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("hair_attack")

			inst.components.combat:StartAttack()

			if target and target:IsValid() then
				TryShareCloneAttackCooldown(inst, target)
				inst.sg.statemem.target = target
				inst.sg.statemem.trackingstr = 5
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local target = inst.sg.statemem.target
				if target then
					if not target:IsValid() then
						inst.sg.statemem.target = nil
					else
						if inst.sg.statemem.canattach then
							if TryHat(inst, target) then
								return
							end
						end
						local trackingstr = inst.sg.statemem.trackingstr
						if trackingstr then
							local lastdrot = inst.sg.statemem.drot
							if lastdrot ~= 0 then
								local rot = inst.Transform:GetRotation()
								local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
								local drot = ReduceAngle(rot1 - rot) * 0.5

								drot = lastdrot and
									math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot)) or
									math.clamp(drot, -trackingstr, trackingstr)

								inst.Transform:SetRotation(rot + drot)
								inst.sg.statemem.lastdrot = drot
							end
						end
					end
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/wolfbat/headbite") end),

			FrameEvent(6, function(inst)
				inst.sg.statemem.lastdrot = nil --reset tracking
				inst.sg.statemem.trackingstr = 4

				inst.components.locomotor:Stop()
				inst.components.locomotor:Clear()
				inst:ClearBufferedAction()
				inst.sg:AddStateTag("jumping")

				local duration = 12 * FRAMES
				local dist = 4
				local target = inst.sg.statemem.target
				if target and target:IsValid() then
					local x, _, z = inst.Transform:GetWorldPosition()
					local x1, _, z1 = target.Transform:GetWorldPosition()
					local dx = x1 - x
					local dz = z1 - z
					local rot1 = math.atan2(-dz, dx) * RADIANS
					local rot = inst.Transform:GetRotation()
					local diff = DiffAngle(rot, rot1)
					local k = Remap(diff, 0, 90, 0, 1)
					if k < 1 then
						dist = math.sqrt(dx * dx + dz * dz)
						dist = Remap(k * k, 0, 1, dist, 4)

						if target.Physics then
							local vx, _, vz = target.Physics:GetVelocity()
							local theta = rot * DEGREES
							local dot = vx * math.cos(theta) - vz * math.sin(theta)
							if dot > 0 then
								dist = dist + dot * duration
							end
						end

						dist = math.clamp(dist, 2, 6)
					end
				end

				inst.sg.statemem.speed = dist / duration
				inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
				ToggleOffCharacterCollisions(inst)
			end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.canattach = true
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.tracking = nil
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.chomping = true
					inst.sg:GoToState("chomp_fail", {
						target = inst.sg.statemem.target,
						speed = inst.sg.statemem.speed,
					})
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.chomping then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				ToggleOnCharacterCollisions(inst)
				if inst.sg.statemem.target then
					IncChompFails(inst, inst.sg.statemem.target)
				end
			end
		end,
	},

	State{
		name = "chomp_fail",
		tags = { "chomp", "busy" },

		onenter = function(inst, data)
			if not inst.sg.lasttags["jumping"] then
				inst.components.locomotor:Stop()
				inst.components.locomotor:Clear()
				inst:ClearBufferedAction()
			end
			inst.AnimState:PlayAnimation("hair_attack_fail")
			if data then
				if data.speed then
					inst.sg.statemem.speed = data.speed
					inst.sg:AddStateTag("jumping")
				end
				inst.sg.statemem.target = data.target
			end
			ToggleOffCharacterCollisions(inst)
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local target = inst.sg.statemem.target
				if target then
					if not target:IsValid() then
						inst.sg.statemem.target = nil
					else
						TryHat(inst, target)
					end
				end
			end
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) PlayBatSound(inst, "boom") end),

			FrameEvent(0, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(1, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(4, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(0.6 * inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(5, function(inst)
				if inst.sg.statemem.target then
					IncChompFails(inst, inst.sg.statemem.target)
					inst.sg.statemem.target = nil
				end
			end),
			FrameEvent(6, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(0.3 * inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(7, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(0.15 * inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(8, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(0.075 * inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(9, function(inst)
				if inst.sg.statemem.speed then
					inst.Physics:SetMotorVelOverride(0.0375 * inst.sg.statemem.speed, 0, 0)
				end
			end),
			FrameEvent(10, function(inst)
				inst.sg.statemem.speed = nil
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
				ToggleOnCharacterCollisions(inst)
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
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			ToggleOnCharacterCollisions(inst)
			if inst.sg.statemem.target then
				IncChompFails(inst, inst.sg.statemem.target)
			end
		end,
	},

	State{
		name = "stun_pre",
		tags = { "stunned", "busy", "jumping" },

		onenter = function(inst, quickrecover)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("stun_pre") --4 frames
			inst.AnimState:MakeFacingDirty() -- Not needed for clients.

			ToggleOffCharacterCollisions(inst)
			TryInitStunned(inst)

			if quickrecover then
				inst.sg.statemem.quickrecover = true
				inst.sg.statemem.loading = inst:GetTimeAlive() <= 0
			else
				inst.AnimState:PushAnimation("stun_loop") --38 frames
				inst.sg:SetTimeout(42 * FRAMES)
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst)
				if not inst.sg.statemem.loading then
					inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/wolfbat/headbite_detach")
				end
			end),

			FrameEvent(0, function(inst) inst.Physics:SetMotorVelOverride(-12, 0, 0) end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVelOverride(-12, 0, 0) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVelOverride(-4.8, 0, 0) end),
			FrameEvent(4, function(inst)
				if not inst.sg.statemem.quickrecover then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVelOverride(-2.4, 0, 0) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVelOverride(-1.2, 0, 0) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(-0.6, 0, 0) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVelOverride(-0.3, 0, 0) end),
			FrameEvent(10, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
				ToggleOnCharacterCollisions(inst)
			end),
		},

		ontimeout = function(inst)
			--not quickrecover
			inst.sg.statemem.stunned = true
			inst.sg:GoToState("stun_idle")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					--quickrecover
					if inst.sg.statemem.loading then
						inst.sg:GoToState("stun_pst")
					else
						inst.sg:GoToState("stun_hit", true)
					end
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			ToggleOnCharacterCollisions(inst)
			TryClearStunned(inst)
		end,
	},

	State{
		name = "stun_idle",
		tags = { "stunned", "busy", "caninterrupt" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			if not inst.AnimState:IsCurrentAnimation("stun_loop") then
				inst.AnimState:PlayAnimation("stun_loop", true)
			end
			TryInitStunned(inst)
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		ontimeout = function(inst)
			if GetTime() - inst.sg.mem.stun_t0 < TUNING.BAT_BOSS_STAGGER_TIME then
				inst.sg.statemem.stunned = true
				inst.sg:GoToState("stun_idle")
			else
				inst.sg:GoToState("quicktaunt")
			end
		end,

		onexit = TryClearStunned,
	},

	State{
		name = "stun_hit",
		tags = { "stunned", "hit", "busy" },

		onenter = function(inst, quickrecover)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_hit")
			TryInitStunned(inst)
			inst.sg.statemem.quickrecover = quickrecover
		end,

		timeline =
		{
			FrameEvent(1, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/hurt") end),
			FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
			FrameEvent(9, function(inst)
				if not inst.sg.statemem.quickrecover and GetTime() - inst.sg.mem.stun_t0 < TUNING.BAT_BOSS_STAGGER_TIME then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if not inst.sg.statemem.quickrecover and GetTime() - inst.sg.mem.stun_t0 < TUNING.BAT_BOSS_STAGGER_TIME then
						inst.sg.statemem.stunned = true
						inst.sg:GoToState("stun_idle")
					else
						inst.sg:GoToState("quicktaunt")
					end
				end
			end),
		},

		onexit = TryClearStunned,
	},

	State{
		name = "stun_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_pst")
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) PlayBatSound(inst, "???") end),

			FrameEvent(5, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:AddStateTag("canrotate")
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
		name = "death_hat",
		tags = { "busy" },

		onenter = function(inst)
			inst.Transform:SetNoFaced()
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("death_hat")
			RemovePhysicsColliders(inst)
			inst:AddTag("NOCLICK")
		end,

		timeline =
		{
			FrameEvent(1, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/death") end),
			FrameEvent(3, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end ),
			FrameEvent(14, function(inst) SetBossShadowScale(inst, 0.9) end),
			FrameEvent(15, function(inst) SetBossShadowScale(inst, 0.8) end),
			FrameEvent(16, function(inst) SetBossShadowScale(inst, 0.7) end),
			FrameEvent(17, function(inst) SetBossShadowScale(inst, 0.5) end),
			FrameEvent(18, function(inst) SetBossShadowScale(inst, 0.3) end),
			FrameEvent(19, function(inst) SetBossShadowScale(inst, 0.1) end),
			FrameEvent(20, function(inst)
				SetBossShadowScale(inst, 0)
				LandFlyingCreature(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:DropDeathLoot()
					inst.persists = false
					inst:Remove()
				end
			end),
		}
	},

	--bat_boss_shadow

	State{
		name = "clone_pre",
		tags = { "busy" },

		onenter = function(inst, isclone)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.Transform:SetEightFaced()
			inst.Transform:SetRotation(inst.Transform:GetRotation() + 90)
			inst.AnimState:PlayAnimation("split_pre")
		end,

		onupdate = function(inst, dt)
			local fade = inst.sg.statemem.fade
			if fade and fade > 0 then
				fade = math.max(0, fade - 0.1)
				inst.AnimState:SetMultColour(fade, fade, fade, 1)
				inst.sg.statemem.fade = fade
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts4/shadowthrall_mouth/enter_stealth") end),

			FrameEvent(20, function(inst)
				inst.sg.statemem.fade = 1
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.cloning = true
					inst.sg:GoToState("clone")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.cloning then
				inst.AnimState:SetMultColour(1, 1, 1, 1)
				inst.Transform:SetSixFaced()
			end
		end,
	},

	State{
		name = "clone",
		tags = { "busy", "jumping" },

		onenter = function(inst, isclone)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.Transform:SetEightFaced()
			inst.AnimState:PlayAnimation("split")
			inst.AnimState:SetMultColour(0, 0, 0, 1)

			if not isclone then
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()

				local fx = SpawnPrefab("bat_boss_shadow_split_fx")
				fx.Transform:SetPosition(x, y, z)
				fx.Transform:SetRotation(rot)

				local clone = SpawnPrefab("bat_boss_shadow")
				inst:StartTrackingClone(clone)
				clone:StartTrackingClone(inst)

				clone.Transform:SetPosition(x, y, z)
				clone.Transform:SetRotation(rot + 180)
				clone.components.health:SetPercent(inst.components.health:GetPercent())
				clone.components.combat:SetTarget(inst.components.combat.target)
				clone.sg:GoToState("clone", true)

				inst.sg.statemem.clone = clone
			else
				inst.AnimState:MakeFacingDirty() -- Not needed for clients.
				ToggleOffCharacterCollisions(inst)
			end

			inst.Physics:SetMotorVelOverride(-3, 0, 0)

			inst.sg.mem.doclone = nil

			StartChompCooldown(inst, 0.667)
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) PlayBatSound(inst, "???") end),

			FrameEvent(16, function(inst) inst.AnimState:SetMultColour(0.2, 0.2, 0.2, 1) end),
			FrameEvent(17, function(inst) inst.AnimState:SetMultColour(0.4, 0.4, 0.4, 1) end),
			FrameEvent(18, function(inst) inst.AnimState:SetMultColour(0.6, 0.6, 0.6, 1) end),
			FrameEvent(19, function(inst) inst.AnimState:SetMultColour(0.8, 0.8, 0.8, 1) end),
			FrameEvent(20, function(inst) inst.AnimState:SetMultColour(1, 1, 1, 1) end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("jumping")
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				ToggleOnCharacterCollisions(inst)
			end),
			FrameEvent(26, function(inst)
				if inst.sg.statemem.clone and math.random() < 0.5 then
					inst.sg:GoToState("taunt")
					return
				end
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:AddStateTag("canrotate")
			end),
			FrameEvent(27, function(inst)
				if inst.sg.statemem.clone then
					inst.sg:GoToState("taunt")
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("taunt")
				end
			end),
		},

		onexit = function(inst)
			inst.Transform:SetSixFaced()
			inst.AnimState:SetMultColour(1, 1, 1, 1)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			ToggleOnCharacterCollisions(inst)
			inst.sg.mem.doclone = nil
		end,
	},

	State{
		name = "clone_pst",
		tags = { "busy" },

		onenter = function(inst, isclone)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("stun_pst")

			if isclone then
				inst.sg:SetTimeout(math.random(5, 6) * FRAMES)
			end
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("taunt")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("taunt")
				end
			end),
		},
	},
}

local walkanims =
{
	startwalk = "fly_loop",
	walk = "fly_loop",
	stopwalk = "fly_loop",
}
local walktimeline =
{
	FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
	FrameEvent(17, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
}
CommonStates.AddWalkStates(states,
{
	starttimeline = walktimeline,
	walktimeline = walktimeline,
	endtimeline = walktimeline,
}, walkanims, true)

--keep in sync with bat/bat_boss constructor shadoow size
local function ConfigSleepLanded(inst, landed)
	if landed then
		if inst:HasTag("flying") then
			LandFlyingCreature(inst)
		end
		if IsBoss(inst) then
			inst.DynamicShadow:SetSize(3.2, 1.6)
		else
			inst.DynamicShadow:SetSize(2, 1)
		end
	else
		if not inst:HasTag("flying") then
			if inst.components.floater:IsFloating() then
				SpawnPrefab("splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
			end
			RaiseFlyingCreature(inst)
		end
		if IsBoss(inst) then
			inst.DynamicShadow:SetSize(2.4, 1.4)
		else
			inst.DynamicShadow:SetSize(1.5, 0.75)
		end
	end
end

CommonStates.AddSleepExStates(states,
{
	starttimeline =
	{
		FrameEvent(7, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
		FrameEvent(17, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
		FrameEvent(27, function(inst)
			inst.sg:RemoveStateTag("caninterrupt")
		end),
	},
	sleeptimeline =
	{
		FrameEvent(23, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/sleep") end),
	},
	waketimeline =
	{
		CommonHandlers.OnNoSleepFrameEvent(12, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
			inst.sg:AddStateTag("canrotate")
			ConfigSleepLanded(inst, false)
		end),
		FrameEvent(13, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end),
	},
},
{
	onsleep = function(inst)
		inst.sg:AddStateTag("caninterrupt")
		SwitchToNoFaced(inst)
	end,
	onexitsleep = function(inst)
		if not inst.sg.statemem.continuesleeping then
			TryRestoreSixFaced(inst)
		end
	end,
	onsleeping = function(inst)
		SwitchToNoFaced(inst)
		ConfigSleepLanded(inst, true)
	end,
	onexitsleeping = function(inst)
		if not inst.sg.statemem.continuesleeping then
			TryRestoreSixFaced(inst)
			ConfigSleepLanded(inst, false)
		end
	end,
	onwake = function(inst)
		SwitchToNoFaced(inst)
		ConfigSleepLanded(inst, true)
	end,
	onexitwake = function(inst)
		TryRestoreSixFaced(inst)
		ConfigSleepLanded(inst, false)
	end,
})

CommonStates.AddDeathState(states,
{
	FrameEvent(1, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/death") end),
	FrameEvent(4, function(inst) PlayBatSound(inst, "dontstarve/creatures/bat/flap") end ),
	FrameEvent(15, LandFlyingCreature),
},
nil, nil, { has_corpse_handler = true })

CommonStates.AddFrozenStates(states,
	function(inst)
		SwitchToNoFaced(inst)
		LandFlyingCreature(inst)
	end,
	function(inst)
		TryRestoreSixFaced(inst)
		RaiseFlyingCreature(inst)
	end)

CommonStates.AddElectrocuteStates(states, nil, nil,
{
	loop_onenter = SwitchToNoFaced,
	loop_onexit = TryRestoreSixFaced,
	pst_onenter = function(inst)
		inst.sg:AddStateTag("canrotate")
		SwitchToNoFaced(inst)
	end,
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			inst.sg.statemem.keepnofaced = true
			inst.sg:GoToState("idle")
		end
	end,
	pst_onexit = TryRestoreSixFaced,
})

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states)
CommonStates.AddStalkerCorruptionStates(states,
{
	corruption_pre =
	{
		--#SFX
		-- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

		FrameEvent(45, function(inst)
			inst.AnimState:SetMultColour(0, 0, 0, 1)
		end),
	},
	corruption_pst =
	{
		--#SFX
		-- FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("###") end),

		FrameEvent(14, function(inst)
			inst.AnimState:SetMultColour(1, 1, 1, 1)
		end),
	},
},
{
	preonenter = function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_a") end,
	pstonenter = function(inst) inst.SoundEmitter:PlaySound("dontstarve/common/together/shadow_transform_b") end,
})

return StateGraph("bat", states, events, "init", actionhandlers)
