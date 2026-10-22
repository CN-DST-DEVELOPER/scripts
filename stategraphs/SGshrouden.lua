require("stategraphs/commonstates")
local AOEUtil = require("aoeutil")
local HitBox = require("util/hitbox")
local easing = require("easing")

local _dbg_draw = BRANCH == "dev"

local RECENT_ATTACKERS_DURATION = 6
local CLEAR_RECENT_ATTACKERS_PERIOD = 10

local function ChooseAttack(inst, target, isfar)
	target = target or inst.components.combat.target
	if target and target:IsValid() then
		local shouldopticblast = inst.canopticblast and not inst.components.timer:TimerExists("opticblastcd")

		if inst.canteleport and inst:IsInArena() then
			local x, _, z = inst.Transform:GetWorldPosition()
			local theta = inst.Transform:GetRotation() * DEGREES
			if not TheWorld.Map:IsValidTileAtPoint(x + 10 * math.cos(theta), 0, z - 10 * math.sin(theta)) then
				--too close to edge

				if shouldopticblast then
					inst.sg:GoToState("optic_blast_pre", target)
					return true
				end

				local home = inst.components.knownlocations:GetLocation("spawnpoint")
				if home and (x ~= home.x or z ~= home.z) then
					theta = math.atan2(z - home.z, home.x - x)
					theta = theta - PI / 12 + math.random() * PI / 6
					local dist = 8 + 2 * math.random()
					inst.sg:GoToState("teleport_pre", Vector3(x + dist * math.cos(theta), 0, z - dist * math.sin(theta)))
					return true
				end
			end
		end

		if not isfar then
			if inst.sg.mem.forcetaunt then
				inst.sg.statemem.keeptwofaced = true
				inst.sg:GoToState("taunt")
				return true
			end

			if inst.sg.mem.exsummon_stocked then
				if inst.canexsummon then
					inst.sg:GoToState("attack", target)
					return true
				end
				inst.sg.mem.exsummon_stocked = nil
			end

			if inst.canexsummon and
				GetTime() > (inst.components.combat.nextbattlecrytime or 0) and
				math.random() < 0.667
			then
				inst.components.combat:ResetBattleCryCooldown()
				inst.sg.statemem.keeptwofaced = true
				inst.sg:GoToState("taunt")
				return true
			end
		end

		if shouldopticblast then
			inst.sg.statemem.keeptwofaced = true
			inst.sg:GoToState("optic_blast_pre", target)
			return true
		end

		if inst.canteleport and not inst.components.timer:TimerExists("teleportcd") then
			inst.sg:GoToState("teleport_pre", target)
			return true
		end

		if not isfar and
			(	inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("hit") or
				not inst.components.timer:TimerExists("portalcd")
			)
		then
			inst.sg:GoToState("attack", target)
			return true
		end
	end
	return false
end

local events =
{
	CommonHandlers.OnLocomote(false, true),
	EventHandler("attacked", function(inst, data)
		if data and data.attacker then
			inst.sg.mem.recent_attackers[data.attacker] = GetTime()
		end
		if not inst.components.health:IsDead() and
			(not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt")) and
			not CommonHandlers.HitRecoveryDelay(inst, TUNING.SHROUDEN_HIT_RECOVERY)
		then
			inst.sg:GoToState("hit")
		end
	end),
	EventHandler("death", function(inst, data)
		if not inst.sg:HasStateTag("nointerrupt") then
			if data and data.cause == "file_load" then
				inst.sg:GoToState("death", true)
			else
				inst.sg:GoToState("hit")
			end
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			ChooseAttack(inst, data and data.target)
		end
	end),
	EventHandler("dofarattack", function(inst)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			ChooseAttack(inst, nil, true)
		end
	end),
}

local function DoRoarShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 2.5, 0.035, 0.14, inst, 40)
end

local function DoRoar2Shake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 1.9, 0.04, 0.15, inst, 40)
end

local function DoTeleportDownShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.7, 0.026, 0.1, inst, 20)
end

local function DoTeleportUpShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.2, 0.03, 0.15, inst, 20)
end

local function DoLiftOffShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.4, 0.03, 0.12, inst, 40)
end

local function DoLandingShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.1, 0.04, 0.15, inst, 40)
end

local function SwitchToNoFaced(inst)
	if inst.sg.mem.facings ~= 0 then
		inst.sg.mem.facings = 0
		inst.Transform:SetNoFaced()
	end
end

--Keep 6-faced in Transform component; anim with no facings will behave like 2-faced.
local function SwitchToTwoFaced(inst)
	if inst.sg.mem.facings ~= 2 then
		if inst.sg.mem.facings ~= 6 then
			inst.Transform:SetSixFaced()
		end
		inst.sg.mem.facings = 2
	end
end

local function SwitchToEightFaced(inst)
	if inst.sg.mem.facings ~= 8 then
		inst.sg.mem.facings = 8
		inst.Transform:SetEightFaced()
	end
end

local function TryRestoreSixFaced(inst)
	if inst.sg.mem.facings == 2 then
		if not inst.sg.statemem.keeptwofaced then
			inst.sg.mem.facings = 6
		end
	elseif inst.sg.mem.facings == 8 then
		if not inst.sg.statemem.keepeightfaced then
			inst.Transform:SetSixFaced()
			inst.sg.mem.facings = 6
		end
	elseif inst.sg.mem.facings == 0 then
		if not inst.sg.statemem.keepnofaced then
			inst.Transform:SetSixFaced()
			inst.sg.mem.facings = 6
		end
	end
end

local function SetClickable(inst, clickable, keeplight)
	if clickable then
		inst:RemoveTag("NOCLICK")
		inst.Light:Enable(true)
	else
		inst:AddTag("NOCLICK")
		inst.Light:Enable(keeplight or false)
	end
end

local function ConfigureFlying(inst, enable)
	if enable then
		inst:AddTag("flying")
		inst:AddTag("notraptrigger")
		inst.components.locomotor:EnableGroundSpeedMultiplier(false)
		inst:PushEvent("ms_escape_rooted")
	else
		inst:RemoveTag("flying")
		inst:RemoveTag("notraptrigger")
		inst.components.locomotor:EnableGroundSpeedMultiplier(true)
	end
end

local function ConfigureUnderground(inst, enable)
	if enable then
		inst:AddTag("notraptrigger")
		inst.components.locomotor:EnableGroundSpeedMultiplier(false)
		inst:SetGelEnabled(true)
		inst:PushEvent("ms_escape_rooted")
	else
		inst:RemoveTag("notraptrigger")
		inst.components.locomotor:EnableGroundSpeedMultiplier(true)
		inst:SetGelEnabled(false)
	end
end

local function SetPuddleLayerEnabled(inst, enable)
	if enable then
		inst.AnimState:SetSortOrder(-1)
		local x, y, z = inst.Transform:GetWorldPosition()
		if y ~= 0 then
			inst.Transform:SetPosition(x, 0, z)
			inst.Physics:Stop()
		end
	else
		inst.AnimState:SetSortOrder(0)
	end
end

local function ShowPuddleEye(inst, anim, loop, frame)
	local eye = inst.sg.mem.eye
	if eye == nil then
		eye = SpawnPrefab("shrouden_eye_fx")
		local x, _, z = inst.Transform:GetWorldPosition()
		eye.Transform:SetPosition(x, 0, z)
		eye.Transform:SetRotation(inst.Transform:GetRotation())
		eye:ListenForEvent("onremove", function(inst) eye:Remove() end, inst)
		inst.sg.mem.eye = eye
	end
	eye:SyncAnim(anim, loop, frame)
end

local function HidePuddleEye(inst)
	if inst.sg.mem.eye then
		inst.sg.mem.eye:Remove()
		inst.sg.mem.eye = nil
	end
	inst.sg.mem.numstomps = nil
	inst.sg.mem.eyelastturn = nil
end

local function OnUpdatePuddle(inst, dt)
	if dt > 0 and not inst.sg.statemem.nostomp then
		local x, _, z = inst.Transform:GetWorldPosition()
		local stomper
		local inarena = inst:IsInArena()
		local mindsq = inarena and math.huge or 144
		local mindx, mindz
		for _, v in ipairs(AllPlayers) do
			if not IsEntityDeadOrGhost(v) and v.sg:HasStateTag("moving") then
				local x1, _, z1 = v.Transform:GetWorldPosition()
				local dx = x - x1
				local dz = z - z1
				local dsq = dx * dx + dz * dz
				if stomper == nil then
					if dsq < 0.75 * 0.75 then
						stomper = v
					elseif dsq < 1.3 * 1.3 then
						local dir = math.atan2(-dz, dx) * RADIANS
						if DiffAngle(dir, v.Transform:GetRotation()) < 45 then
							stomper = v
						end
					end
				end
				if dsq < mindsq and inarena == TheWorld.Map:IsPointInCharlieBossArena(v.Transform:GetWorldPosition()) then
					mindsq = dsq
					mindx, mindz = dx, dz
				end
			end
		end
		if mindx and inst.sg.mem.eye then
			local t = GetTime()
			if (inst.sg.mem.eyelastturn or 0) + 0.2 < t then
				inst.sg.mem.eyelastturn = t
				inst.sg.mem.eye.Transform:SetRotation(math.atan2(mindz, -mindx) * RADIANS)
			end
		end
		if stomper then
			--inst.SoundEmitter:PlaySound(stomper.components.combat:GetImpactSound(inst))
			inst.sg.statemem.keeptwofaced = true
			inst.sg.statemem.death = true
			inst.sg:GoToState("death_hit")
			stomper:PushEvent("ms_stompshrouden", inst)
		end
	end
end

local function MatchesInArena(target, inst)
	return inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(target.Transform:GetWorldPosition())
end

local _temp_aoe_params =
{
	attack_filterfn = MatchesInArena,
	work_filterfn = MatchesInArena,
}
local function GetAOEParams(dist, radius, arc, knockback_str, knockback_heavystr, knockback_forcelanded, hitbox)
	_temp_aoe_params.dist = dist
	_temp_aoe_params.radius = radius
	_temp_aoe_params.arc = arc
	_temp_aoe_params.hitbox = hitbox
	_temp_aoe_params.knockback_str = knockback_str
	_temp_aoe_params.knockback_heavystr = knockback_heavystr
	_temp_aoe_params.knockback_forcelanded = knockback_forcelanded
	return _temp_aoe_params
end

local _temp_toss_params = { startheight = 0.5 }
local function GetTossParams(radius, strmult)
	_temp_toss_params.radius = radius
	_temp_toss_params.basespeed = radius * 0.4 * (strmult or 1)
	_temp_toss_params.verticalspeed = (_temp_toss_params.basespeed + 0.5) * 2.5
	--_temp_toss_params.startradius = radius
	return _temp_toss_params
end

local function SnapTo45s(angle)
	return math.floor(angle / 45 + 0.5) * 45
end

local PORTAL_DIST = 5.7
local PORTAL_RADIUS = 3.5

local function DoPortalSummon(inst, prefab, dir, targets)
	local x, _, z = inst.Transform:GetWorldPosition()
	local minangle = prefab == "shadowthrall_mouth" and 120 or 45
	local target

	local function TryTarget(k)
		if not targets[k] then
			local x1, _, z1 = k.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) then
				local range = PORTAL_DIST + 12
				if dx * dx + dz * dz < range * range then
					local diff = DiffAngle(dir, math.atan2(-dz, dx) * RADIANS)
					if diff < minangle then
						minangle = diff
						target = k
					end
				end
			end
		end
	end

	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		if k:IsValid() and not IsEntityDeadOrGhost(k) then
			inst:ForEachRecentNonPlayerAttacker(TryTarget)
		end
	end

	if target == nil then
		inst:ForEachRecentNonPlayerAttacker(TryTarget)
	end

	if target then
		targets[target] = true
	end

	local theta = dir * DEGREES
	local cos_theta = math.cos(theta)
	local sin_theta = math.sin(theta)
	local minion = SpawnPrefab(prefab)
	minion.Transform:SetPosition(x + PORTAL_DIST * cos_theta, 0, z - PORTAL_DIST * sin_theta)
	minion.Transform:SetRotation(dir)
	minion:OnShroudenSummon(inst, target)

	if prefab ~= "shadowthrall_wings" then
		inst.components.timer:StopTimer("portalcd")
		inst.components.timer:StartTimer("portalcd", TUNING.SHROUDEN_PORTAL_CD[inst.threatlevel])
	end
end

local states =
{
	State{
		name = "init",
		onenter = function(inst)
			inst.sg.mem.facings = 6
			inst.sg.mem.recent_attackers = {}
			inst.sg.mem.next_clear_recent_attackers = GetTime() + CLEAR_RECENT_ATTACKERS_PERIOD
			inst.sg:GoToState("idle")
		end,
	},

	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			if inst.sg.mem.forcetaunt then
				inst.sg.statemem.keeptwofaced = true
				inst.sg:GoToState("taunt")
				return
			end

			inst.components.locomotor:Stop()

			if pushanim and not inst.AnimState:AnimDone() then
				inst.sg.statemem.pushanim = true
			else
				local anim = inst.sg.mem.facings <= 2 and "idle_nofaced" or "idle"
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
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.keepeightfaced = true
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
		name = "spawn",
		tags = { "spawning", "busy", "noattack", "invisible", "temp_invincible", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("puddle_appear")
			SetPuddleLayerEnabled(inst, true)
			inst:SetMusicLevel(4)
			inst:SetCameraFocusEnabled(true)
			SetClickable(inst, false)
			ToggleOffAllObjectCollisions(inst)
			ConfigureUnderground(inst, true)
			inst:SetGelEnabled(false)
			inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")

			inst.sg.mem.changearena = true -- for save/load
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				if inst.sg.mem.changearena then
					inst.sg.mem.changearena = nil
					if inst:IsInArena() then
						inst:PushEvent("ms_charliearena_becomeunstable")
					end
				end
			end),
			FrameEvent(30, function(inst)
				inst:SetGelEnabled(true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.spawning = true
					inst.sg:GoToState("spawn_loop")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.spawning then
				TryRestoreSixFaced(inst)
				SetPuddleLayerEnabled(inst, false)
				inst:SetMusicLevel(
					(inst.components.health:IsDead() and 4) or
					(inst.components.combat:HasTarget() and 3) or
					0)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst.SoundEmitter:KillSound("puddle_loop")
			end
			if inst.sg.mem.changearena then
				inst.sg.mem.changearena = nil
				if inst:IsInArena() then
					inst:PushEvent("ms_charliearena_becomeunstable")
				end
			end
		end,
	},

	State{
		name = "spawn_loop",
		tags = { "spawning", "busy", "noattack", "invisible", "temp_invincible", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("teleport_loop", true)
			SetPuddleLayerEnabled(inst, true)
			inst:SetMusicLevel(1)
			inst:SetCameraFocusEnabled(true)
			SetClickable(inst, false)
			ToggleOffAllObjectCollisions(inst)
			ConfigureUnderground(inst, true)
			if not inst.SoundEmitter:PlayingSound("puddle_loop") then
				inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")
			end
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				if inst.sg.statemem.aggrodelay then
					if inst.sg.statemem.aggrodelay > dt then
						inst.sg.statemem.aggrodelay = inst.sg.statemem.aggrodelay - dt
					else
						inst.sg.statemem.spawning = true
						inst.sg:GoToState("teleport_pst")
					end
				elseif inst.sg.statemem.canaggro then
					local player, dsq = inst:GetNearestPlayer(true)
					if player and dsq < 36 then
						inst.sg.statemem.aggrodelay = 1 + math.random() * 0.25
						inst.components.combat:SetTarget(player)
						inst:SetMusicLevel(2)
					end
				end
			end
		end,

		timeline =
		{
			TimeEvent(5, function(inst)
				inst.sg.statemem.canaggro = true
			end),
			TimeEvent(20, function(inst)
				inst.sg.statemem.spawning = true
				inst.sg:GoToState("teleport_pst")
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.spawning then
				SetPuddleLayerEnabled(inst, false)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst:SetMusicLevel(
					(inst.components.health:IsDead() and 4) or
					(inst.components.combat:HasTarget() and 3) or
					0)
			end
			inst.SoundEmitter:KillSound("puddle_loop")
		end,
	},

	State{
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst, quick)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			local target = inst.components.combat.target
			if target then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			inst.AnimState:PlayAnimation("taunt_pre")

			if inst.sg.mem.forcetaunt then
				inst.sg.mem.forcetaunt = nil
				inst.components.combat:ResetBattleCryCooldown()
			elseif quick then
				inst.sg.statemem.quick = true
			end

			if not inst.canexsummon then
				inst.components.combat.battlecryenabled = false
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/taunt") end),

			FrameEvent(27, function(inst)
				inst.sg.mem.forcetaunt = nil
				DoRoarShake(inst)
				inst.components.epicscare:Scare(10)
				if inst.canexsummon and not inst.sg.statemem.quick then
					inst.sg.mem.exsummon_stocked = true
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg:GoToState(inst.sg.statemem.quick and "taunt_pst" or "taunt_loop")
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "taunt_loop",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			inst.AnimState:PlayAnimation("taunt_loop")
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/hit") end),

			FrameEvent(27, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg:GoToState("taunt_pst")
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "taunt_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			inst.AnimState:PlayAnimation("taunt_pst")

			if inst.sg.lasttags["caninterrupt"] then
				inst.sg:AddStateTag("caninterrupt")
			end
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/hit") end),

			FrameEvent(12, function(inst)
				if inst.sg.mem.exsummon_stocked and
					not inst.components.combat:InCooldown() and
					ChooseAttack(inst)
				then
					return
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(16, function(inst)
				inst.sg:AddStateTag("canrotate")
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.keeptwofaced = true
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "taunt2",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			local target = inst.components.combat.target
			if target then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			inst.AnimState:PlayAnimation("taunt2")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/taunt2") end),

			FrameEvent(21, function(inst)
				DoRoar2Shake(inst)
				inst.components.epicscare:Scare(10)
			end),
			FrameEvent(48, function(inst)
				inst.sg:AddStateTag("canrotate")
			end),
			FrameEvent(58, function(inst)
				if inst.sg.statemem.doattack then
					if inst.sg.statemem.doattack:IsValid() then
						return
					end
					inst.sg.statemem.doattack = nil
				end
				inst.sg:AddStateTag("caninterrupt")
				inst:SetCameraFocusEnabled(false) --in case came from spawning teleport_pst
			end),
			FrameEvent(62, function(inst)
				if inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				end
				inst.sg.statemem.keeptwofaced = true
				inst.sg:GoToState("idle", true)
			end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if data and data.target and data.target:IsValid() then
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

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			inst:SetCameraFocusEnabled(false) --in case came from spawning teleport_pst
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)

			if inst.components.health:IsDead() then
				inst.sg:AddStateTag("dead")
				inst.sg:AddStateTag("nointerrupt")
				inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_lrg_sharp")
				inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_lrg_dull")
				inst.SoundEmitter:PlaySound("terraria1/mini_eyeofterror/egg_crack")
				inst.SoundEmitter:PlaySound("dontstarve/common/lava_arena/spawn", nil, 0.6)
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/hit_react") end),

			FrameEvent(8, function(inst)
				if inst.sg:HasStateTag("dead") then
					inst.sg:GoToState("death", true)
					return
				elseif inst.sg.statemem.doattack then
					if inst.sg.statemem.doattack:IsValid() then
						return
					end
					inst.sg.statemem.doattack = nil
				end
				if not inst.components.combat:InCooldown() then
					local target = inst.components.combat.target
					local lastattacktime = inst.sg.mem.recent_attackers[target]
					if lastattacktime and lastattacktime + RECENT_ATTACKERS_DURATION >= GetTime() then
						local x1, _, z1 = target.Transform:GetWorldPosition()
						local range = TUNING.SHROUDEN_COUNTERATTACK_RANGE + inst:GetPhysicsRadius(0)
						if inst:GetDistanceSqToPoint(x1, 0, z1) < range * range and
							inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1)
						then
							inst.sg.statemem.counterattack = target
							return
						end
					end
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(10, function(inst)
				if inst.sg.mem.forcetaunt then
					inst.sg:GoToState("taunt")
					return
				elseif inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				elseif inst.sg.statemem.counterattack and ChooseAttack(inst, inst.sg.statemem.counterattack) then
					return
				elseif not inst.components.combat:InCooldown() then
					local target = inst.components.combat.target
					if target and target ~= inst.sg.statemem.counterattack then
						local lastattacktime = inst.sg.mem.recent_attackers[target]
						if lastattacktime and lastattacktime + RECENT_ATTACKERS_DURATION >= GetTime() then
							local x1, _, z1 = target.Transform:GetWorldPosition()
							local range = TUNING.SHROUDEN_COUNTERATTACK_RANGE + inst:GetPhysicsRadius(0)
							if inst:GetDistanceSqToPoint(x1, 0, z1) < range * range and
								inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) and
								ChooseAttack(inst, target)
							then
								return
							end
						end
					end
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

	--------------------------------------------------------------------------

	State{
		name = "death",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst, skipsound)
			if inst.looted then
				inst.sg.statemem.keeptwofaced = true
				inst.sg.statemem.death = true
				inst.sg:GoToState("death_fr94")
				return
			end
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			inst.AnimState:PlayAnimation("death")
			ShowPuddleEye(inst, "death")
			inst:SetCameraFocusEnabled(true)

			if not skipsound then
				inst.SoundEmitter:PlaySound("rifts8/shrouden/hit_react")
				inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_lrg_sharp")
				inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_flesh_lrg_dull")
				inst.SoundEmitter:PlaySound("terraria1/mini_eyeofterror/egg_crack")
				inst.SoundEmitter:PlaySound("dontstarve/common/lava_arena/spawn", nil, 0.6)
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/death_a") end),
			FrameEvent(48, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/death_b") end),

			FrameEvent(19, DoLiftOffShake),
			FrameEvent(31, function(inst)
				ShakeAllCameras(CAMERASHAKE.FULL, 3, 0.045, 0.07, inst, 40)
			end),
			FrameEvent(70, function(inst)
				ShakeAllCameras(CAMERASHAKE.FULL, 1.55, 0.04, 0.2, inst, 40)
			end),
			FrameEvent(71, function(inst)
				inst.components.lootdropper:SetChanceLootTable("shrouden")
				inst.components.lootdropper.spawn_loot_inside_prefab = false
				inst.components.lootdropper.y_offset = 4
				inst:DropDeathLoot()
				inst.looted = 1
			end),
			FrameEvent(91, function(inst)
				inst.sg:AddStateTag("noattack")
				ToggleOffAllObjectCollisions(inst)
				ConfigureUnderground(inst, true)
			end),
			FrameEvent(94, function(inst)
				inst.sg.statemem.keeptwofaced = true
				inst.sg.statemem.death = true
				inst.sg:GoToState("death_fr94")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.death then
				TryRestoreSixFaced(inst)
				HidePuddleEye(inst)
				inst:SetCameraFocusEnabled(false)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
			end
		end,
	},

	State{
		name = "death_fr94",
		tags = { "dead", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			if inst.looted == true then
				inst.sg.statemem.death = true
				inst.sg:GoToState("death_loop")
				return
			end
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			if not inst.AnimState:IsCurrentAnimation("death") and inst.sg.lasttags["dead"] then
				inst.AnimState:PlayAnimation("death")
				inst.AnimState:SetFrame(94)
			end
			ShowPuddleEye(inst, "death", nil, 94)
			SetPuddleLayerEnabled(inst, true)
			inst:SetCameraFocusEnabled(true)
			SetClickable(inst, false, true)
			ConfigureUnderground(inst, true)
			ToggleOffAllObjectCollisions(inst)

			local x, y, z = inst.Transform:GetWorldPosition()
			if y ~= 0 then
				inst.Transform:SetPosition(x, 0, z)
				inst.Physics:Stop()
			end

			inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")

			inst.components.lootdropper:SetChanceLootTable("shrouden2")
			inst.components.lootdropper.spawn_loot_inside_prefab = true
			inst.components.lootdropper.y_offset = nil
			inst.components.lootdropper:DropLoot(inst:GetPosition())
			inst.looted = true
		end,

		onupdate = OnUpdatePuddle,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.death = true
					inst.sg:GoToState("death_loop")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.death then
				TryRestoreSixFaced(inst)
				HidePuddleEye(inst)
				SetPuddleLayerEnabled(inst, false)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst.SoundEmitter:KillSound("puddle_loop")
			end
		end,
	},

	State{
		name = "death_loop",
		tags = { "death", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death_puddle_loop", true)
			ShowPuddleEye(inst, "death_puddle_loop", true)
			SetPuddleLayerEnabled(inst, true)
			--inst:SetCameraFocusEnabled(true)
			SetClickable(inst, false, true)
			ConfigureUnderground(inst, true)
			ToggleOffAllObjectCollisions(inst)

			local x, y, z = inst.Transform:GetWorldPosition()
			if y ~= 0 then
				inst.Transform:SetPosition(x, 0, z)
				inst.Physics:Stop()
			end

			if not inst.SoundEmitter:PlayingSound("puddle_loop") then
				inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * math.random(2))
		end,

		onupdate = OnUpdatePuddle,

		timeline =
		{
			TimeEvent(1, function(inst)
				inst:SetCameraFocusEnabled(false)
			end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.keepnofaced = true
			inst.sg.statemem.death = true
			inst.sg:GoToState("death_blink")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.death then
				TryRestoreSixFaced(inst)
				HidePuddleEye(inst)
				SetPuddleLayerEnabled(inst, false)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst.SoundEmitter:KillSound("puddle_loop")
			end
		end,
	},

	State{
		name = "death_blink",
		tags = { "death", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death_puddle_loop2", true)
			ShowPuddleEye(inst, "death_puddle_loop2", true)
			SetPuddleLayerEnabled(inst, true)
			SetClickable(inst, false, true)
			ConfigureUnderground(inst, true)
			ToggleOffAllObjectCollisions(inst)

			local x, y, z = inst.Transform:GetWorldPosition()
			if y ~= 0 then
				inst.Transform:SetPosition(x, 0, z)
				inst.Physics:Stop()
			end

			if not inst.SoundEmitter:PlayingSound("puddle_loop") then
				inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")
			end

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * math.random(2))
		end,

		onupdate = OnUpdatePuddle,

		ontimeout = function(inst)
			inst.sg.statemem.keepnofaced = true
			inst.sg.statemem.death = true
			inst.sg:GoToState("death_loop")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.death then
				TryRestoreSixFaced(inst)
				HidePuddleEye(inst)
				SetPuddleLayerEnabled(inst, false)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst.SoundEmitter:KillSound("puddle_loop")
			end
		end,
	},

	State{
		name = "death_hit",
		tags = { "death", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death_puddle_hit")
			ShowPuddleEye(inst, "death_puddle_hit")
			SetPuddleLayerEnabled(inst, true)
			SetClickable(inst, false, true)
			ConfigureUnderground(inst, true)
			ToggleOffAllObjectCollisions(inst)
			inst.sg.statemem.nostomp = true
			inst.sg.mem.numstomps = (inst.sg.mem.numstomps or 0) + 1

			if not inst.SoundEmitter:PlayingSound("puddle_loop") then
				inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")
			end
		end,

		onupdate = OnUpdatePuddle,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("terraria1/mini_eyeofterror/egg_crack") end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/pathetic_hit_react") end),

			FrameEvent(7, function(inst)
				if inst.sg.mem.numstomps >= 12 then
					inst.SoundEmitter:KillSound("puddle_loop")
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.death = true
					inst.sg:GoToState("death_final")
				end
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.nostomp = nil
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.death = true
					inst.sg:GoToState("death_loop")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.death then
				TryRestoreSixFaced(inst)
				HidePuddleEye(inst)
				SetPuddleLayerEnabled(inst, false)
				inst:SetCameraFocusEnabled(false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				inst.SoundEmitter:KillSound("puddle_loop")
			end
		end,
	},

	State{
		name = "death_final",
		tags = { "death", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("final_blow")
			ShowPuddleEye(inst, "final_blow")
			SetPuddleLayerEnabled(inst, true)
			SetClickable(inst, false)
			ConfigureUnderground(inst, true)
			ToggleOffAllObjectCollisions(inst)

			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + 1)
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/death_a") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts4/goop/spit_out", nil, 0.4) end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/shrouden_death_final") end),

			FrameEvent(1, function(inst)
				local x, _, z = inst.Transform:GetWorldPosition()
				local num = 7
				local theta = math.random() * TWOPI
				inst.sg.statemem.theta = theta
				local delta = TWOPI / num
				for i = 1, num, 2 do
					local angle = theta + delta * (i + math.random() * 0.667)
					local blob = SpawnPrefab("gelblob_small_fx")
					local r = 1 + 0.5 * math.random()
					blob.Transform:SetPosition(x + r * math.cos(angle), 0, z - r * math.sin(angle))
					blob:Toss(2.5 + 2.5 * math.random(), angle, 0.6 * math.random(), true)
				end
			end),
			FrameEvent(3, function(inst)
				local x, _, z = inst.Transform:GetWorldPosition()
				local num = 7
				local theta = inst.sg.statemem.theta
				local delta = TWOPI / num
				for i = 2, num, 2 do
					local angle = theta + delta * (i + math.random() * 0.667)
					local blob = SpawnPrefab("gelblob_small_fx")
					local r = 0.5 + 0.5 * math.random()
					blob.Transform:SetPosition(x + r * math.cos(angle), 0, z - r * math.sin(angle))
					blob:Toss(1 + 2.5 * math.random(), angle, 0.6 * math.random(), true)
				end
			end),
			FrameEvent(7, function(inst)
				inst:SetGelEnabled(false)
			end),
		},

		ontimeout = function(inst)
			if inst:IsInArena() then
				inst:PushEvent("ms_charlie_boss_defeated")
			end
			inst:Remove()
		end,

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			HidePuddleEye(inst)
			SetPuddleLayerEnabled(inst, false)
			inst:SetCameraFocusEnabled(false)
			SetClickable(inst, true)
			ConfigureUnderground(inst, false)
			if inst.sg.mem.isobstaclepassthrough then
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
			end
		end,
	},

	--------------------------------------------------------------------------

	State{
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			SwitchToEightFaced(inst)

			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.rot = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
				inst.Transform:SetRotation(SnapTo45s(inst.sg.statemem.rot))
			else
				inst.Transform:SetRotation(SnapTo45s(inst.Transform:GetRotation()))
			end
			inst.AnimState:PlayAnimation("punch_pre")
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local lastdrot = inst.sg.statemem.drot
						if lastdrot ~= 0 then
							local rot = inst.sg.statemem.rot
							local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
							local drot = ReduceAngle(rot1 - rot) * 0.5
							local maxdrot = 10

							drot = math.clamp(drot, -maxdrot, maxdrot)
							if lastdrot then
								drot = math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot))
							end

							inst.sg.statemem.rot = rot + drot
							inst.sg.statemem.lastdrot = drot

							inst.Transform:SetRotation(SnapTo45s(inst.sg.statemem.rot))
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
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/portal_punch_pre") end),

			FrameEvent(4, function(inst)
				inst.sg.statemem.target = nil --stop tracking
				inst:SetPortalOpen(true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepeightfaced = true
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("attack_loop")
				end
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.attacking then
				inst:SetPortalOpen(false)
			end
		end,
	},

	State{
		name = "attack_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, dbg_summonprefab)
			inst.components.locomotor:Stop()
			inst.components.combat:RestartCooldown()
			SwitchToEightFaced(inst)

			if not inst.AnimState:IsCurrentAnimation("punch_loop") then
				inst.AnimState:PlayAnimation("punch_loop", true)
			end
			inst:SetPortalOpen(true)

			inst.SoundEmitter:PlaySound("rifts8/shrouden/portal_punch_LP", "portal_loop")

			inst.sg:SetTimeout(1)

			local len = PORTAL_DIST + 1
			local outerrad = math.sqrt(len * len + PORTAL_RADIUS * PORTAL_RADIUS)
			local hitbox = inst.sg.mem.attack_hitbox
			if hitbox == nil then
				hitbox = HitBox(inst)
				inst.sg.mem.attack_hitbox = hitbox

				hitbox:AddRectangle(0, -PORTAL_RADIUS, outerrad, PORTAL_RADIUS)

				--outer edge of rect is cut round by outerrad of the search params
				--can use this circle to visualize that in debug (don't checkin!)
				--hitbox:AddCircle(0, 0, outerrad)
			end

			inst.sg.statemem.aoeparams = GetAOEParams(0, outerrad, nil, 1.5, 1.25, true, hitbox)
			inst.sg.statemem.targets = {}
			inst.sg.statemem.workdelay = 0

			inst.sg.statemem.dbg_summonprefab = dbg_summonprefab

			if _dbg_draw then
				hitbox:DebugDraw()
			end

			inst.components.timer:StopTimer("portalcd")
			inst.components.timer:StartTimer("portalcd", TUNING.SHROUDEN_PORTAL_CD[inst.threatlevel])
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				if inst.sg.statemem.workdelay > dt then
					inst.sg.statemem.workdelay = inst.sg.statemem.workdelay - dt
				else
					inst.sg.statemem.workdelay = 1
					AOEUtil.Work(inst, inst.sg.statemem.aoeparams, inst.sg.statemem.targets)
				end
				AOEUtil.Attack(inst, inst.sg.statemem.aoeparams, inst:GetAOEAttackTagSet(), inst.sg.statemem.targets, 0.35)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				if inst.sg.statemem.dbg_summonprefab then
					inst.sg.statemem.summonprefab = inst.sg.statemem.dbg_summonprefab
				elseif inst.sg.mem.exsummon_stocked then
					inst.sg.mem.exsummon_stocked = false
					local summons = inst.sg.mem.exsummons
					if summons == nil then
						summons = {}
						table.insert(summons, math.random(#summons + 1), "shadowthrall_horns")
						table.insert(summons, math.random(#summons + 1), "shadowthrall_horns")
						table.insert(summons, math.random(#summons + 1), "shadowthrall_mouth")
						table.insert(summons, math.random(#summons + 1), "shadowthrall_mouth")
						inst.sg.mem.exsummons = summons
					end
					if inst.threatlevel < 3 then
						if #summons < 4 then
							table.insert(summons, math.random(#summons + 1), "shadowthrall_mouth")
						end
						local rnd = math.random(2) --don't repeat same one more than twice in a row
						inst.sg.statemem.summonprefab = table.remove(summons, rnd)
						table.insert(summons, inst.sg.statemem.summonprefab)
					else
						if #summons > 3 then
							for i = #summons, 1, -1 do
								if summons[i] == "shadowthrall_mouth" then
									table.remove(summons, i)
									break
								end
							end
						end
						inst.sg.statemem.summonprefab = table.remove(summons, 1)
						if inst.sg.statemem.summonprefab == "shadowthrall_mouth" then
							table.insert(summons, math.random(2, 3), "shadowthrall_mouth")
						else
							table.insert(summons, inst.sg.statemem.summonprefab)
						end
					end
				else
					local summons = inst.sg.mem.summons
					if summons == nil then
						summons = {}
						table.insert(summons, math.random(#summons + 1), "shadowthrall_wings")
						table.insert(summons, math.random(#summons + 1), "shadowthrall_hands")
						inst.sg.mem.summons = summons
					end
					local num =
						(inst.threatlevel >= 3 and 4) or
						((	inst.canexsummon or
							inst.threatlevel >= 2 or
							inst.components.grouptargeter:GetNumTargets() > 1	) and 3) or
						2
					if num > #summons then
						for i = #summons + 1, num do
							table.insert(summons, math.random(i), "shadowthrall_mouth")
						end
					elseif num < #summons then
						for i = #summons, 1, -1 do
							if summons[i] == "shadowthrall_mouth" then
								table.remove(summons, i)
								if #summons <= num then
									break
								end
							end
						end
					end
					num = math.min(3, #summons)
					local rnd = math.random(num)
					if rnd == num then
						rnd = 1 --exclude last picked, double chance for oldest
					end
					inst.sg.statemem.summonprefab = table.remove(summons, rnd)
					table.insert(summons, inst.sg.statemem.summonprefab)
				end
				inst.sg.statemem.offsgn = math.random() < 0.5 and -1 or 1
				local offs =
					inst.sg.statemem.summonprefab == "shadowthrall_wings" and
					15 or
					0
				inst.sg.statemem.summontargets = {}
				DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() + inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
			end),
			FrameEvent(5, function(inst)
				if inst.sg.statemem.summonprefab ~= "shadowthrall_wings" then
					local offs =
						inst.sg.statemem.summonprefab == "shadowthrall_mouth" and
						60 + 10 * math.random() or
						25 + 10 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() + inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
				end
			end),
			FrameEvent(8, function(inst)
				if inst.sg.statemem.summonprefab ~= "shadowthrall_wings" then
					local offs =
						inst.sg.statemem.summonprefab == "shadowthrall_mouth" and
						60 + 10 * math.random() or
						25 + 10 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() - inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
				end
			end),
			FrameEvent(14, function(inst)
				if inst.sg.statemem.summonprefab == "shadowthrall_wings" then
					local offs = 30
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() - inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
				end
			end),
			FrameEvent(19, function(inst)
				if inst.sg.statemem.summonprefab == "shadowthrall_hands" then
					if math.random() < 0.5 then
						inst.sg.statemem.offsgn = -inst.sg.statemem.offsgn
					end
					local offs = 12.5 + 5 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() + inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
				elseif inst.sg.statemem.summonprefab == "shadowthrall_mouth" then
					if math.random() < 0.5 then
						inst.sg.statemem.offsgn = -inst.sg.statemem.offsgn
					end
					local offs = 30 + 5 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() + inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
					inst.components.combat:RestartCooldown()
				end
			end),
			FrameEvent(22, function(inst)
				if inst.sg.statemem.summonprefab == "shadowthrall_hands" then
					local offs = 12.5 + 5 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() - inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
				elseif inst.sg.statemem.summonprefab == "shadowthrall_mouth" then
					local offs = 30 + 5 * math.random()
					DoPortalSummon(inst, inst.sg.statemem.summonprefab, inst.Transform:GetRotation() - inst.sg.statemem.offsgn * offs, inst.sg.statemem.summontargets)
					inst.components.combat:RestartCooldown()
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.keepeightfaced = true
			inst.sg.statemem.attacking = true
			inst.sg:GoToState("attack_pst",
				inst.sg.statemem.combo or
				(inst.sg.statemem.summonprefab == "shadowthrall_wings" and "opticblast") or
				nil)
		end,

		events =
		{
			EventHandler("targetdevoured", function(inst)
				inst.sg.statemem.combo = "taunt2"
			end),
			EventHandler("shadowthrall_mouth_shroudenbite", function(inst)
				inst.sg.statemem.combo = "taunt2"
			end),
		},

		onexit = function(inst)
			inst.SoundEmitter:KillSound("portal_loop")
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.attacking then
				inst:SetPortalOpen(false)
			end
		end,
	},

	State{
		name = "attack_pst",
		tags = { "attack", "busy" },

		onenter = function(inst, combo)
			inst.components.locomotor:Stop()
			SwitchToEightFaced(inst)
			inst.AnimState:PlayAnimation("punch_pst")
			inst:SetPortalOpen(true)
			inst.sg.statemem.combo = combo
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/portal_punch_pst") end),

			FrameEvent(5, function(inst)
				if inst.sg.statemem.combo == "opticblast" and
					inst.cancomboblast and
					(inst.components.timer:GetTimeLeft("opticblastcd") or 0) < TUNING.SHROUDEN_OPTIC_BLAST_CD / 3
				then
					local target = inst.components.combat.target
					if target then
						inst.sg:GoToState("optic_blast_pre", target)
					end
				end
			end),
			FrameEvent(10, function(inst)
				if inst.sg.statemem.combo == "taunt2" then
					inst.sg:GoToState("taunt2")
					return
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(21, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		events =
		{
			EventHandler("targetdevoured", function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg:GoToState("taunt2")
				elseif inst.sg.statemem.combo == nil then
					inst.sg.statemem.combo = "taunt2"
				end
			end),
			EventHandler("shadowthrall_mouth_shroudenbite", function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg:GoToState("taunt2")
				elseif inst.sg.statemem.combo == nil then
					inst.sg.statemem.combo = "taunt2"
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepeightfaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst:SetPortalOpen(false)
		end,
	},

	State{
		name = "teleport_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target_or_pos)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()

			if EntityScript.is_instance(target_or_pos) then
				if target_or_pos:IsValid() then
					inst.sg.statemem.target_or_pos = target_or_pos
					inst:ForceFacePoint(target_or_pos.Transform:GetWorldPosition())
				end
			elseif target_or_pos then
				inst.sg.statemem.target_or_pos = target_or_pos
				inst:ForceFacePoint(target_or_pos)
				inst.components.combat:ResetCooldown()
			end
			inst.AnimState:PlayAnimation("teleport_pre")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts2/shrouden/teleport_in") end),

			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(8, DoTeleportDownShake),
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("noattack")
				SetClickable(inst, false)
			end),
			FrameEvent(12, function(inst)
				inst.sg:AddStateTag("invisible")
			end),
			FrameEvent(13, function(inst)
				ToggleOffAllObjectCollisions(inst)
				ConfigureUnderground(inst, true)
			end),
			FrameEvent(16, function(inst)
				--cut to loop and start movement early
				inst.sg.statemem.teleporting = true
				inst.sg:GoToState("teleport_loop", inst.sg.statemem.target_or_pos)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.teleporting then
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
			end
		end,
	},

	State{
		name = "teleport_loop",
		tags = { "attack", "busy", "nointerrupt", "noattack", "invisible", "jumping" },

		onenter = function(inst, target_or_pos)
			--PUSH anim since we cutting early from teleport_pre
			inst.AnimState:PushAnimation("teleport_loop")
			if inst.AnimState:IsCurrentAnimation("teleport_loop") then
				SetPuddleLayerEnabled(inst, true)
			end
			inst.SoundEmitter:PlaySound("rifts4/goop/idle_big", "puddle_loop")

			SetClickable(inst, false)
			ToggleOffAllObjectCollisions(inst)
			ConfigureUnderground(inst, true)

			if not EntityScript.is_instance(target_or_pos) then
				inst.sg.statemem.targetpos = target_or_pos
			elseif target_or_pos:IsValid() then
				inst.sg.statemem.target = target_or_pos
			end

			inst.components.timer:StopTimer("teleportcd")
			inst.components.timer:StartTimer("teleportcd", TUNING.SHROUDEN_TELEPORT_CD)
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local acceltime = 1
				local deceltime = 0.3
				local arrivedist = 1
				local min_t = 1
				local max_t = 3
				local t2 = max_t - deceltime
				local t = (inst.sg.statemem.t or 0) + dt

				local dist = 0
				local physrad1 = 0
				local x1, _, z1
				if inst.sg.statemem.targetpos then
					acceltime = 0.3
					arrivedist = 2
					min_t = 0.6
					x1, _, z1 = inst.sg.statemem.targetpos:Get()
				elseif inst.sg.statemem.target then
					if inst.sg.statemem.target:IsValid() then
						x1, _, z1 = inst.sg.statemem.target.Transform:GetWorldPosition()
						physrad1 = inst.sg.statemem.target:GetPhysicsRadius(0)
					else
						inst.sg.statemem.target = nil
					end
				end
				if x1 then
					local rot = inst.Transform:GetRotation()
					local x, _, z = inst.Transform:GetWorldPosition()
					local dx = x1 - x
					local dz = z1 - z
					if dx ~= 0 or dz ~= 0 then
						local rot1 = math.atan2(-dz, dx) * RADIANS
						local drot = ReduceAngle(rot1 - rot)
						drot = math.clamp(drot / 2, -10, 10)
						inst.Transform:SetRotation(rot + drot)

						dist = math.sqrt(dx * dx + dz * dz)
						if t > min_t and dist < arrivedist + physrad1 or inst.components.health:IsDead() then
							t = math.max(t, t2)
						end
					end
				elseif inst.components.health:IsDead() then
					t = math.max(t, t2)
				else
					t = math.max(t, t2 - min_t)
				end

				inst.sg.statemem.t = t

				local maxspeed = TUNING.SHROUDEN_TELEPORT_SPEED
				if inst.sg.statemem.targetpos == nil and
					inst.sg.statemem.target and
					inst.sg.statemem.target.components.locomotor
				then
					local runspeed = math.max(6, inst.sg.statemem.target.components.locomotor:GetRunSpeed())
					local diff = DiffAngle(inst.Transform:GetRotation(), inst.sg.statemem.target.Transform:GetRotation())
					local dot = runspeed * math.cos(diff * DEGREES)
					local k = math.clamp(Remap(diff, 180, 45, 0, 1), 0, 1)
					k = k * k
					local runspeed1 = runspeed * (1 - k) + dot * k
					if runspeed1 < maxspeed then
						local spacing = math.min(Remap(runspeed, 6, 7.5, 2.5, 3.5), 4)
						maxspeed = math.clamp(Remap(dist, spacing, spacing + 6, runspeed1, maxspeed), runspeed1, maxspeed)
					end
				end

				local speed = inst.sg.statemem.targetpos and maxspeed or math.min(maxspeed, dist * 3)
				if inst.sg.statemem.speed then
					speed = speed * 0.2 + inst.sg.statemem.speed * 0.8
				end
				inst.sg.statemem.speed = speed

				local mult =
					(t < acceltime and easing.inOutQuad(t, 0, 1, acceltime)) or
					(t <= t2 and 1) or
					(t < max_t and easing.inOutQuad(t - t2, 1, -1, deceltime)) or
					0
				speed = speed * mult

				if speed ~= 0 then
					inst.Physics:SetMotorVelOverride(speed, 0, 0)
				else
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
				end

				if t >= max_t - 4 * FRAMES then
					inst.sg.statemem.teleporting = true
					inst.sg:GoToState("teleport_pst", {
						t = t - t2,
						speed = inst.sg.statemem.speed,
						deceltime = deceltime,
						quickattack = inst.sg.statemem.targetpos ~= nil,
					})
				end
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:IsCurrentAnimation("teleport_loop") then
					SetPuddleLayerEnabled(inst, true)
				end
			end),
		},

		onexit = function(inst)
			inst.SoundEmitter:KillSound("puddle_loop")
			if not inst.sg.statemem.teleporting then
				SetPuddleLayerEnabled(inst, false)
				SetClickable(inst, true)
				ConfigureUnderground(inst, false)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
			end
		end,
	},

	State{
		name = "teleport_pst",
		tags = { "attack", "busy", "nointerrupt", "noattack", "invisible", "jumping" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("teleport_pst")

			SetClickable(inst, false)
			ToggleOffAllObjectCollisions(inst)

			if data and data.t and data.speed and data.deceltime then
				inst.sg.statemem.data = data
			else
				inst.sg:RemoveStateTag("jumping")
			end
			inst.sg.statemem.quickattack = data and data.quickattack

			if inst.sg.lasttags["spawning"] then
				inst.sg:AddStateTag("spawning")
				inst:SetMusicLevel(2)
				inst.sg.statemem.nodmg = true
				inst.components.combat:SetDefaultDamage(0)
				inst.components.planardamage:SetBaseDamage(0)
				inst.components.combat:RestartCooldown()
			end
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local data = inst.sg.statemem.data
				if data then
					data.t = data.t + dt
					local speed = data.t < data.deceltime and data.speed * easing.inOutQuad(data.t, 1, -1, data.deceltime) or 0
					if speed ~= 0 then
						inst.Physics:SetMotorVelOverride(speed, 0, 0)
					else
						inst.sg.statemem.data = nil
						inst.Physics:ClearMotorVelOverride()
						inst.Physics:Stop()
						inst.sg:RemoveStateTag("jumping")
					end
				end
				if inst.sg.statemem.targets then
					if inst.components.health:IsDead() and not inst.sg.statemem.nodmg then
						inst.sg.statemem.nodmg = true
						inst.components.combat:SetDefaultDamage(0)
						inst.components.planardamage:SetBaseDamage(0)
					end
					AOEUtil.AttackAndDig(inst, inst.sg.statemem.aoeparams, inst:GetAOEAttackTagSet(), inst.sg.statemem.targets)
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts2/shrouden/teleport_out") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/portal_punch_pst") end),

			FrameEvent(3, function(inst)
				SetPuddleLayerEnabled(inst, false)
			end),
			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("invisible")
				DoTeleportUpShake(inst)
			end),
			FrameEvent(6, function(inst)
				if inst.sg:HasStateTag("jumping") then
					inst.sg.statemem.data = nil
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
					inst.sg:RemoveStateTag("jumping")
				end
				inst.sg:RemoveStateTag("noattack")
				SetClickable(inst, true)

				inst.sg.statemem.targets = {}
				inst.sg.statemem.aoeparams = GetAOEParams(0, 2.4, nil, 0.8, nil, inst.sg:HasStateTag("spawning"))
				AOEUtil.WorkAndDig(inst, inst.sg.statemem.aoeparams)--, inst.sg.statemem.targets)
				AOEUtil.TossItems(inst, GetTossParams(2.4))

				local x, _, z = inst.Transform:GetWorldPosition()
				inst:RemoveSpawningArenaSpikes(x, z, inst:GetPhysicsRadius(0))
			end),
			FrameEvent(26, function(inst)
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)

				inst.sg.statemem.aoeparams.radius = 3.25
			end),
			FrameEvent(27, function(inst)
				inst.sg.statemem.aoeparams.radius = 3.9
			end),
			FrameEvent(28, function(inst)
				if inst.canautoquickattack and next(inst.sg.statemem.targets) == nil then
					inst.sg.statemem.quickattack = true
				end
				inst.sg.statemem.targets = nil
				inst.sg.statemem.aoeparams = nil
				ConfigureUnderground(inst, false)
			end),
			FrameEvent(33, function(inst)
				if inst.components.health:IsDead() then
					inst.sg:GoToState("death")
					return
				elseif inst.sg.statemem.quickattack and ChooseAttack(inst) then
					return
				end
				inst.sg:RemoveStateTag("nointerrupt")
				if not (inst.sg:HasStateTag("spawning") and inst.components.combat:HasTarget()) then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(34, function(inst) if not (inst.sg:HasStateTag("spawning") and inst.components.combat:HasTarget()) then inst.sg:AddStateTag("caninterrupt") end end),
			FrameEvent(35, function(inst) if not (inst.sg:HasStateTag("spawning") and inst.components.combat:HasTarget()) then inst.sg:AddStateTag("caninterrupt") end end),
			FrameEvent(36, function(inst) if not (inst.sg:HasStateTag("spawning") and inst.components.combat:HasTarget()) then inst.sg:AddStateTag("caninterrupt") end end),
			FrameEvent(37, function(inst) if not (inst.sg:HasStateTag("spawning") and inst.components.combat:HasTarget()) then inst.sg:AddStateTag("caninterrupt") end end),
			FrameEvent(38, function(inst)
				if inst.sg:HasStateTag("spawning") then
					if inst.components.combat:HasTarget() then
						inst.sg.mem.forcetaunt = nil
						inst.components.combat:ResetBattleCryCooldown()
						if not inst.canexsummon then
							inst.components.combat.battlecryenabled = false
						end
					end
					inst.sg.statemem.keepcamerafocus = true
					inst.sg:GoToState("taunt2")
					return
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(43, function(inst)
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
			if inst.sg.statemem.nodmg then
				inst.components.combat:SetDefaultDamage(TUNING.SHROUDEN_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.SHROUDEN_PLANAR_DAMAGE)
			end
			if inst.sg:HasStateTag("spawning") then
				inst:SetMusicLevel(
					(inst.components.health:IsDead() and 4) or
					(inst.components.combat:HasTarget() and 3) or
					0)
				if not inst.sg.statemem.keepcamerafocus then
					inst:SetCameraFocusEnabled(false)
				end
			end
			SetPuddleLayerEnabled(inst, false)
			ConfigureUnderground(inst, false)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			if inst.sg.mem.isobstaclepassthrough then
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
			end
		end,
	},

	State{
		name = "optic_blast_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			SwitchToTwoFaced(inst)

			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
			inst.AnimState:PlayAnimation("optic_blast_pre1")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts2/shrouden/teleport_in") end),

			FrameEvent(7, DoLiftOffShake),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(11, function(inst)
				inst.sg:AddStateTag("noattack")
				SetClickable(inst, false)
				ConfigureFlying(inst, true)
				ToggleOffAllObjectCollisions(inst)
			end),
			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("invisible")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.opticblasting = true
					inst.sg:GoToState("optic_blast_appear", inst.sg.statemem.target)
				end
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.opticblasting then
				SetClickable(inst, true)
				ConfigureFlying(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
			end
		end,
	},

	State{
		name = "optic_blast_appear",
		tags = { "attack", "busy", "nointerrupt", "noattack", "invisible" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)

			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.Physics:Teleport(target.Transform:GetWorldPosition())
				inst.Transform:SetRotation(target.Transform:GetRotation())
			end
			inst.AnimState:PlayAnimation("optic_blast_pre2")

			SetClickable(inst, false)
			ConfigureFlying(inst, true)
			ToggleOffAllObjectCollisions(inst)

			local fx = SpawnPrefab("shrouden_optic_blast_fx")
			fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
			fx:InitBlast(inst)
			inst.sg.statemem.fx = fx

			inst:PushEvent("teleported")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/shrouden_blast_teleport_in") end),

			FrameEvent(5, function(inst)
				inst.sg:RemoveStateTag("invisible")
			end),
			FrameEvent(10, function(inst)
				SetClickable(inst, true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.opticblasting = true
					if inst.components.health:IsDead() then
						inst.sg.statemem.fx:Remove()
						inst.sg:GoToState("optic_blast_pst")
					else
						inst.sg:GoToState("optic_blast_loop", {
							target = inst.sg.statemem.target,
							fx = inst.sg.statemem.fx,
						})
					end
				end
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			SetClickable(inst, true)
			if not inst.sg.statemem.opticblasting then
				ConfigureFlying(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				if inst.sg.statemem.fx then
					inst.sg.statemem.fx:Remove()
				end
			end
		end,
	},

	State{
		name = "optic_blast_loop",
		tags = { "attack", "busy", "nointerrupt", "noattack", "jumping" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.components.combat:RestartCooldown()
			SwitchToTwoFaced(inst)
			inst.AnimState:PlayAnimation("optic_blast_loop", true)

			ConfigureFlying(inst, true)
			ToggleOffAllObjectCollisions(inst)

			if data and data.target and data.target:IsValid() then
				inst.sg.statemem.target = data.target
				inst.sg.statemem.speedmult = 1
			else
				inst.sg.statemem.speedmult = 0
			end

			local fx = data and data.fx
			if not (fx and fx:IsValid()) then
				fx = SpawnPrefab("shrouden_optic_blast_fx")
				fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
				fx:InitBlast(inst)
			end
			inst.sg.statemem.fx = fx

			inst.components.timer:StopTimer("opticblastcd")
			inst.components.timer:StartTimer("opticblastcd", TUNING.SHROUDEN_OPTIC_BLAST_CD)
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local dist = 0
				local target = inst.sg.statemem.target
				if target then
					if target:IsValid() then
						local rot = inst.Transform:GetRotation()
						local x, _, z = inst.Transform:GetWorldPosition()
						local x1, _, z1 = target.Transform:GetWorldPosition()
						local dx = x1 - x
						local dz = z1 - z
						if dx ~= 0 or dz ~= 0 then
							local rot1 = math.atan2(-dz, dx) * RADIANS
							local drot = ReduceAngle(rot1 - rot)
							drot = math.clamp(drot / 2, -10, 10)
							inst.Transform:SetRotation(rot + drot)

							dist = math.sqrt(dx * dx + dz * dz)
						end
					else
						inst.sg.statemem.target = nil
						target = nil
					end
				end

				if inst.sg.statemem.speedmult > 0 then
					inst.sg.statemem.speedmult = math.max(0, inst.sg.statemem.speedmult - dt / (inst.sg.statemem.wide and 2 or 6))

					local minspeed, maxspeed = unpack(TUNING.SHROUDEN_OPTIC_BLAST_SPEED)
					if target and target.components.locomotor then
						local runspeed = inst.sg.statemem.target.components.locomotor:GetRunSpeed()
						local diff = DiffAngle(inst.Transform:GetRotation(), target.Transform:GetRotation())
						local dot = runspeed * math.cos(diff * DEGREES)
						local k = math.clamp(Remap(diff, 180, 45, 0, 1), 0, 1)
						k = k * k
						runspeed = runspeed * (1 - k) + dot * k
						maxspeed = math.clamp(Remap(runspeed, 6, 7.5, minspeed, maxspeed), minspeed, maxspeed)
					end
					maxspeed = math.max(maxspeed, inst.sg.statemem.maxspeed or 0)
					inst.sg.statemem.maxspeed = maxspeed

					local speed = math.min(maxspeed, dist * 3)
					if inst.sg.statemem.speed then
						speed = speed * 0.2 + inst.sg.statemem.speed * 0.8
					end
					inst.sg.statemem.speed = speed
					if speed ~= 0 then
						inst.Physics:SetMotorVelOverride(speed * inst.sg.statemem.speedmult, 0, 0)
					else
						inst.Physics:ClearMotorVelOverride()
						inst.Physics:Stop()
					end
				end
			end
		end,

		timeline =
		{
			FrameEvent(45, function(inst)
				inst.components.combat:RestartCooldown()
			end),
			FrameEvent(75, function(inst)
				if not inst.canwideblast then
					local success = inst.sg.statemem.fx.targets ~= nil and inst.sg.statemem.fx.targets[inst.sg.statemem.target] ~= nil
					inst.sg.statemem.fx:KillFx()
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.opticblasting = true
					inst.sg:GoToState("optic_blast_pst", success)
					return
				end
				inst.components.combat:RestartCooldown()
				inst.sg.statemem.fx:MakeWide()
				inst.sg.statemem.wide = true
				inst.AnimState:PlayAnimation("optic_blast_pre3")
				inst.AnimState:PushAnimation("optic_blast_loop")
			end),
			FrameEvent(84, function(inst)
				inst.sg.statemem.speedmult = 1
			end),
			FrameEvent(90, function(inst)
				inst.components.combat:RestartCooldown()
			end),
			FrameEvent(120, function(inst)
				local success = inst.sg.statemem.fx.targets ~= nil and inst.sg.statemem.fx.targets[inst.sg.statemem.target] ~= nil
				inst.sg.statemem.fx:KillFx()
				inst.sg.statemem.keeptwofaced = true
				inst.sg.statemem.opticblasting = true
				inst.sg:GoToState("optic_blast_pst", success)
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			if not inst.sg.statemem.opticblasting then
				ConfigureFlying(inst, false)
				if inst.sg.mem.isobstaclepassthrough then
					local x, _, z = inst.Transform:GetWorldPosition()
					ToggleOnAllObjectCollisionsAt(inst, x, z)
				end
				if inst.sg.statemem.fx then
					inst.sg.statemem.fx:Remove()
				end
			end
		end,
	},

	State{
		name = "optic_blast_pst",
		tags = { "busy", "nointerrupt", "noattack" },

		onenter = function(inst, success)
			inst.components.locomotor:Stop()
			SwitchToTwoFaced(inst)
			inst.AnimState:PlayAnimation("optic_blast_pst")

			ConfigureFlying(inst, true)
			ToggleOffAllObjectCollisions(inst)

			inst.sg.statemem.success = success
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_pst") end),

			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("noattack")
			end),
			FrameEvent(17, function(inst)
				ConfigureFlying(inst, false)
				DoLandingShake(inst)

				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)

				if inst.components.health:IsDead() then
					inst.sg.statemem.nodmg = true
					inst.components.combat:SetDefaultDamage(0)
					inst.components.planardamage:SetBaseDamage(0)
				end

				inst.sg.statemem.targets = {}
				local aoeparams = GetAOEParams(0, 2.6, nil, 0.8)
				AOEUtil.Work(inst, aoeparams, inst.sg.statemem.targets)
				AOEUtil.Attack(inst, aoeparams, inst:GetAOEAttackTagSet(), inst.sg.statemem.targets)
				AOEUtil.TossItems(inst, GetTossParams(2.6))
				inst:RemoveSpawningArenaSpikes(x, z, inst:GetPhysicsRadius(0))
			end),
			FrameEvent(18, function(inst)
				if inst.components.health:IsDead() and not inst.sg.statemem.nodmg then
					inst.sg.statemem.nodmg = true
					inst.components.combat:SetDefaultDamage(0)
					inst.components.planardamage:SetBaseDamage(0)
				end

				local aoeparams = GetAOEParams(0, 3.6, nil, 0.8)
				AOEUtil.Work(inst, aoeparams, inst.sg.statemem.targets)
				AOEUtil.Attack(inst, aoeparams, inst:GetAOEAttackTagSet(), inst.sg.statemem.targets)
				AOEUtil.TossItems(inst, GetTossParams(3.6))
			end),
			FrameEvent(20, function(inst)
				if inst.components.health:IsDead() then
					inst.sg:GoToState("death")
					return
				end
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(24, function(inst)
				if inst.sg.statemem.success then
					inst.sg.statemem.keeptwofaced = true
					inst.sg:GoToState("taunt2")
					return
				end
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(31, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.nodmg then
				inst.components.combat:SetDefaultDamage(TUNING.SHROUDEN_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.SHROUDEN_PLANAR_DAMAGE)
			end
			TryRestoreSixFaced(inst)
			ConfigureFlying(inst, false)
			if inst.sg.mem.isobstaclepassthrough then
				local x, _, z = inst.Transform:GetWorldPosition()
				ToggleOnAllObjectCollisionsAt(inst, x, z)
			end
		end,
	},
}

CommonStates.AddWalkStates(states)

return StateGraph("shrouden", states, events, "init")
