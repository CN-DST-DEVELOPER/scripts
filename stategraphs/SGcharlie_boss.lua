require("stategraphs/commonstates")
local AOEUtil = require("aoeutil")
local easing = require("easing")

local RECENT_ATTACKERS_DURATION = 6
local CLEAR_RECENT_ATTACKERS_PERIOD = 10

local function ChooseAttack(inst, target)
	target = target or inst.components.combat.target
	if target and target:IsValid() then
		if inst.sg.mem.forcetaunt then
			inst.sg:GoToState("taunt")
			return true
		end

		if inst.isreflectingprojectiles and
			GetTime() > (inst.components.combat.nextbattlecrytime or 0) and
			math.random() < 0.5
		then
			inst.components.combat:ResetBattleCryCooldown()
			inst.sg:GoToState("taunt")
			return true
		end

		inst.sg:GoToState("attack", target)
		return true
	end
	return false
end

local function ShouldVineCounter(inst, data) --data from "attacked" event
	return inst.canvinecounter
		and data and data.attacker and data.attacker:IsValid()
		and inst:IsNear(data.attacker, (IsRangedWeapon(data.weapon or data.attacker) and 4 or 5) + data.attacker:GetPhysicsRadius(0))
		and inst.components.combat:CanTarget(data.attacker)
		or false
end

local events =
{
	CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnDeath(),
	EventHandler("attacked", function(inst, data)
		if data and data.attacker then
			inst.sg.mem.recent_attackers[data.attacker] = GetTime()
		end
		if inst.isreflectingprojectiles and data and data.damage == 0 then
			local weapon = data.weapon or data.attacker
			if IsRangedWeapon(weapon) then
				return
			end
		end
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif ShouldVineCounter(inst, data) then
				if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt") or
					(inst.ismodeswitching and inst.sg:HasStateTag("canforcecounter"))
				then
					inst.sg:GoToState("hit", true)
				end
			elseif (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("caninterrupt")) and
				not CommonHandlers.HitRecoveryDelay(inst, TUNING.CHARLIE_BOSS_HIT_RECOVERY)
			then
				inst.sg:GoToState("hit")
			end
		end
	end),
	EventHandler("doattack", function(inst, data)
		if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
			ChooseAttack(inst, data and data.target)
		end
	end),
}

local function DoScreamShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 2, 0.035, 0.1, inst, 40)
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

local function SpawnMinion(inst, dist, offset, speed)
	local x, _, z = inst.Transform:GetWorldPosition()
	local rot = inst.sg.statemem.rot or inst.Transform:GetRotation()
	local theta = rot * DEGREES
	local costheta = math.cos(theta)
	local sintheta = math.sin(theta)
	local x1 = x + dist * costheta
	local z1 = z - dist * sintheta
	if offset ~= 0 then
		x1 = x1 + offset * sintheta
		z1 = z1 + offset * costheta
	end
	local minion = SpawnPrefab(math.random() < 0.5 and "charlie_boss_minion1" or "charlie_boss_minion2")
	minion.Transform:SetPosition(x1, 0, z1)
	minion.Transform:SetRotation(rot)
	minion:InitMinion(speed, inst, inst.sg.statemem.targets)

	SpawnPrefab("charlie_boss_aoe_flame_fx").Transform:SetPosition(x1, 0, z1)
end

local function IsEntityInShadow(ent)
	return not (ent.components.playervision == nil or --creatures can all act in the dark
				ent.components.playervision:HasNightVision() or
				ent:IsInLight())
end

local _temp_aoe_params =
{
	attack_filterfn = function(target, inst)
		return inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(target.Transform:GetWorldPosition())
	end,
}
local function GetAOEParams(dist, radius, arc, knockback_str, knockback_heavystr, knockback_forcelanded)
	_temp_aoe_params.dist = dist
	_temp_aoe_params.radius = radius
	_temp_aoe_params.arc = arc
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

local function SpawnGroundVines(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
	local num = 7
	local theta = TWOPI * math.random()
	local delta = TWOPI / num
	for i = 1, num do
		local sintheta = math.sin(theta)
		local costheta = math.cos(theta)
		local x1 = x + 0.5 * costheta
		local z1 = z - 0.5 * sintheta
		local vines = SpawnPrefab("charlie_boss_vines")
		vines.Transform:SetPosition(x1, 0, z1)
		vines.Transform:SetRotation(theta * RADIANS - 20 + 40 * math.random())
		local deltadir = 1 + math.random() * 3.5
		local numloops = (i == 1 and 5) or math.min(5, math.random(3, 6))
		vines:InitVines(inst, numloops, math.random() < 0.5 and -deltadir or deltadir)
		theta = theta + delta
	end
end

local states =
{
	State{
		name = "init",
		onenter = function(inst)
			inst.sg.mem.recent_attackers = {}
			inst.sg.mem.next_clear_recent_attackers = GetTime() + CLEAR_RECENT_ATTACKERS_PERIOD
			inst.sg:GoToState("idle")
		end,
	},

	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst, pushanim)
			inst.components.locomotor:Stop()

			if pushanim and not inst.AnimState:AnimDone() then
				inst.sg.statemem.pushanim = true
			else
				local anim = inst.sg.mem.nofaced and "idle_nofaced" or "idle"
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
		tags = { "spawning", "busy", "noattack", "temp_invincible", "nointerrupt" },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("swallow")
			inst:SetMusicLevel(1)
			inst:SetCameraFocusLevel(2)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/tentacle_swallow") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.spawning = true
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("spawn_loop", 2)
				end
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.spawning then
				inst:SetMusicLevel(
					(inst.components.health:IsDead() and 4) or
					(inst.components.combat:HasTarget() and 3) or
					0)
				inst:SetCameraFocusLevel(0)
			end
		end,
	},

	State{
		name = "spawn_loop",
		tags = { "spawning", "busy", "noattack", "temp_invincible", "nointerrupt" },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			if not inst.AnimState:IsCurrentAnimation("rise_loop") then
				inst.AnimState:PlayAnimation("rise_loop", true)
			end
			inst:SetMusicLevel(1)
			inst:SetCameraFocusLevel(2)
			inst.sg.statemem.loops = loops or 0
			if inst:IsInArena() then
				local players, numplayers = GetPlayersInfoForVirtualRoomSetName(VIRTUALROOMSETS.ATRIUM)
				local playernear
				for k in pairs(players) do
					if not IsEntityDeadOrGhost(k) then
						playernear = true
						break
					end
				end
				if not playernear then
					inst.sg.statemem.loops = 0
				end
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		onupdate = function(inst, dt)
			if dt > 0 and inst.sg.statemem.loops > 3 and not inst.sg.statemem.aggro then
				local player, dsq = inst:GetNearestPlayer(true)
				if player and dsq < 36 then
					inst.sg.statemem.aggro = true
					inst.components.combat:SetTarget(player)
				end
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.spawning = true
			inst.sg.statemem.keepnofaced = true
			if inst.sg.statemem.loops < 15 and not inst.sg.statemem.aggro then
				inst.sg:GoToState("spawn_loop", inst.sg.statemem.loops + 1)
			else
				inst.sg:GoToState("spawn_pst")
			end
		end,

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.spawning then
				inst:SetMusicLevel(
					(inst.components.health:IsDead() and 4) or
					(inst.components.combat:HasTarget() and 3) or
					0)
				inst:SetCameraFocusLevel(0)
			end
		end,
	},

	State{
		name = "spawn_pst",
		tags = { "spawning", "busy", "noattack", "temp_invincible", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("rise_pst")
			inst:SetMusicLevel(2)
			inst:SetCameraFocusLevel(2)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/rise_pst_1") end),
			FrameEvent(53, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/rise_pst_2") end),

			FrameEvent(10, function(inst)
				local targets = {}
				AOEUtil.Work(inst, 1.5)
				AOEUtil.TossItems(inst, GetTossParams(1.5), targets)
				for k in pairs(targets) do
					if k:IsValid() and k.components.burnable and k.components.burnable:IsBurning() then
						k.components.burnable:Extinguish()
					end
				end
			end),
			FrameEvent(11, function(inst)
				inst:SetCameraFocusLevel(1)
			end),
			FrameEvent(17, function(inst)
				local targets = {}
				AOEUtil.Work(inst, 3.5, targets)

				inst.components.combat:SetDefaultDamage(0)
				inst.components.planardamage:SetBaseDamage(0)
				AOEUtil.Attack(inst, GetAOEParams(0, 3.5, nil, 1, nil, true), inst:GetAOEAttackTagSet(), targets)
				inst.components.combat:SetDefaultDamage(TUNING.CHARLIE_BOSS_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.CHARLIE_BOSS_PLANAR_DAMAGE)

				targets = {}
				AOEUtil.TossItems(inst, GetTossParams(3.5, 2), targets)
				for k in pairs(targets) do
					if k:IsValid() and k.components.burnable and k.components.burnable:IsBurning() then
						k.components.burnable:Extinguish()
					end
				end
			end),
			FrameEvent(62, function(inst)
				DoScreamShake(inst)
				inst.components.epicscare:Scare(10)
			end),
			FrameEvent(108, function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			inst:SetMusicLevel(
				(inst.components.health:IsDead() and 4) or
				(inst.components.combat:HasTarget() and 3) or
				0)
			inst:SetCameraFocusLevel(0)
		end,
	},

	State{
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()

			if inst.sg.mem.forcetaunt then
				inst.sg.mem.forcetaunt = nil
				inst.components.combat:ResetBattleCryCooldown()
			end

			if inst.ismodeswitching then
				inst.components.combat:StartAttack()
				inst.AnimState:PlayAnimation(inst:WantsToReflectProjectiles() and "air_cast" or "vine_cast")
			else
				inst.components.combat.battlecryenabled = false
				SwitchToNoFaced(inst)
				inst.AnimState:PlayAnimation("taunt")
			end
		end,

		onupdate = function(inst, dt)
			if inst.sg.statemem.offsets then
				if inst.sg.statemem.delay > dt then
					inst.sg.statemem.delay = inst.sg.statemem.delay - dt
				else
					inst.sg.statemem.delay = 3 * FRAMES

					local n = #inst.sg.statemem.offsets
					local rnd = math.random(n)
					local offs = inst.sg.statemem.offsets[rnd]
					if n > 1 then
						inst.sg.statemem.offsets[rnd] = inst.sg.statemem.offsets[n]
						inst.sg.statemem.offsets[n] = nil
					else
						inst.sg.statemem.offsets = nil
						inst.components.combat:RestartCooldown()
					end

					local x, y, z = inst.Transform:GetWorldPosition()
					local targetorpos
					if offs.target and offs.target:IsValid() and not IsEntityDeadOrGhost(offs.target) then
						local x1, _, z1 = offs.target.Transform:GetWorldPosition()
						if inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) and
							(inst:IsInArena() or math2d.DistSq(x, z, x1, z1) < 484)
						then
							targetorpos = offs.target
						end
					end
					if targetorpos == nil then
						local minangle = 45
						for k in pairs(inst.components.grouptargeter:GetTargets()) do
							if k:IsValid() and not (IsEntityDeadOrGhost(k) or IsEntityInShadow(k)) then
								local x1, _, z1 = k.Transform:GetWorldPosition()
								local dx = x1 - x
								local dz = z1 - z
								if inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) and
									(inst:IsInArena() or dx * dx + dz * dz < 484)
								then
									local diff = DiffAngle(offs.rot, math.atan2(-dz, dx) * RADIANS)
									if diff < minangle then
										minangle = diff
										targetorpos = k
									end
								end
							end
						end
						if targetorpos == nil then
							targetorpos = Vector3(x + offs.x1, 0, z + offs.z1)
						end
					end
					inst:SpawnReflectProjectileAtXYZ(x + offs.x, y + 2 + math.random() * 2.5, z + offs.z, offs.rot, targetorpos)
				end
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/whoosh", nil, 0.5) end),
			FrameEvent(17, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_shrill", nil, 0.5) end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/ground_hit", nil, 0.7) end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/ground_hit", nil, 0.8) end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/tentacles") end),

			FrameEvent(23, function(inst)
				inst.sg.mem.forcetaunt = nil
				DoScreamShake(inst)
				inst.components.epicscare:Scare(10)
				inst:ToggleReflectingProjectiles()
			end),
			FrameEvent(26, function(inst)
				if inst.ismodeswitching then
					inst.sg:AddStateTag("attack")
					inst.components.combat:RestartCooldown()

					if inst.isreflectingprojectiles then
						inst.sg.statemem.offsets = {}
						local num = 5
						local delta = 360 / num
						local rot = math.random() * 360
						local mindist = 5
						for j = 1, 2 do
							for i = 1, num do
								local rot1 = rot + math.random() * delta / 3
								local theta = rot1 * DEGREES
								local costheta = math.cos(theta)
								local sintheta = math.sin(theta)
								local r = 2.5 + math.random()
								local offs = {}
								offs.x = r * costheta
								offs.z = -r * sintheta
								r = mindist + math.random() * 2.5
								offs.x1 = r * costheta
								offs.z1 = -r * sintheta
								offs.rot = rot1
								table.insert(inst.sg.statemem.offsets, offs)
								rot = rot + delta
							end
							rot = rot + delta / 2
							mindist = mindist + 4
						end
						inst.sg.statemem.delay = 0

						local x, _, z = inst.Transform:GetWorldPosition()
						for k in pairs(inst.components.grouptargeter:GetTargets()) do
							if k:IsValid() and not (IsEntityDeadOrGhost(k) or IsEntityInShadow(k)) then
								local x2, _, z2 = k.Transform:GetWorldPosition()
								if inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x2, 0, z2) then
									local mindsq = inst:IsInArena() and math.huge or 625
									local nearestoffs
									for _, v in ipairs(inst.sg.statemem.offsets) do
										if v.target == nil then
											local dsq = math2d.DistSq(x + v.x, z + v.z, x2, z2)
											if dsq < mindsq then
												mindsq = dsq
												nearestoffs = v
											end
										end
									end
									if nearestoffs then
										nearestoffs.target = k
									end
								end
							end
						end
					else
						SpawnGroundVines(inst)
					end
				end
			end),
			FrameEvent(70, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(75, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("canrotate")
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
			TryRestoreSixFaced(inst)
			inst:ToggleReflectingProjectiles()
		end,
	},

	State{
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst, should_counter)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)

			inst.sg.statemem.should_counter = should_counter
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/hit") end),

			FrameEvent(8, function(inst)
				if inst.canvinecounter and inst.sg.statemem.should_counter and not inst.sg.mem.forcetaunt then
					inst.sg:GoToState("vine_counterattack")
				end
			end),
			FrameEvent(10, function(inst)
				if inst.sg.mem.forcetaunt then
					inst.sg:GoToState("taunt")
					return
				elseif inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				elseif not inst.components.combat:InCooldown() then
					local target = inst.components.combat.target
					local lastattacktime = inst.sg.mem.recent_attackers[target]
					if lastattacktime and lastattacktime + RECENT_ATTACKERS_DURATION >= GetTime() then
						local x1, _, z1 = target.Transform:GetWorldPosition()
						local range = TUNING.CHARLIE_BOSS_COUNTERATTACK_RANGE + target:GetPhysicsRadius(0)
						if inst:GetDistanceSqToPoint(x1, 0, z1) < range * range and
							inst:IsInArena() == TheWorld.Map:IsPointInCharlieBossArena(x1, 0, z1) and
							ChooseAttack(inst, target)
						then
							return
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
					return true
				end
			end),
			EventHandler("attacked", function(inst, data)
				if inst.sg:HasStateTag("busy") and ShouldVineCounter(inst, data) then
					inst.sg.statemem.should_counter = true
				end
				if data and data.attacker then
					inst.sg.mem.recent_attackers[data.attacker] = true
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			local t = GetTime()
			if t >= inst.sg.mem.next_clear_recent_attackers then
				inst.sg.mem.next_clear_recent_attackers = t + CLEAR_RECENT_ATTACKERS_PERIOD

				for k, v in pairs(inst.sg.mem.recent_attackers) do
					if v + RECENT_ATTACKERS_DURATION < t then
						inst.sg.mem.recent_attackers[k] = nil
					end
				end
			end
		end,
	},

	State{
		name = "attack",
		tags = { "attack", "busy", "canforcecounter" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.rot = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
				inst.Transform:SetRotation(inst.sg.statemem.rot)
				inst.sg.statemem.canturn = true
			end
			inst.AnimState:PlayAnimation("castlift")
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
							local maxdrot = inst.sg.statemem.canturn and 5 or 2

							drot = math.clamp(drot, -maxdrot, maxdrot)
							if lastdrot then
								drot = math.clamp(drot, math.min(0, lastdrot), math.max(0, lastdrot))
							end

							inst.sg.statemem.rot = rot + drot
							inst.sg.statemem.lastdrot = drot

							if inst.sg.statemem.canturn then
								inst.Transform:SetRotation(inst.sg.statemem.rot)
							end
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
			--FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_subdued", nil, 0.4) end),
			FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/whoosh", nil, 0.5) end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(29, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature1/attack_grunt", nil, 0.9) end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature2/attack", nil, 0.7) end),

			FrameEvent(8, function(inst)
				inst.sg.statemem.canturn = nil
			end),
			FrameEvent(22, function(inst)
				inst.sg.statemem.target = nil --stop tracking
			end),
			FrameEvent(33, function(inst)
				inst.sg:RemoveStateTag("canforcecounter")
				inst.components.combat:RestartCooldown()
				inst.sg.statemem.targets = {}
				SpawnMinion(inst, 3, 0, 24)
			end),
			FrameEvent(37, function(inst)
				inst.sg.statemem.sideoffs = math.random() < 0.5 and -4 or 4
				SpawnMinion(inst, 2, inst.sg.statemem.sideoffs, 20)
			end),
			FrameEvent(40, function(inst)
				SpawnMinion(inst, 2, -inst.sg.statemem.sideoffs, 20)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(59, function(inst)
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
		name = "vine_counterattack",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("aoe")
		end,

		onupdate = function(inst, dt)
			if dt > 0 and inst.sg.statemem.targets then
				AOEUtil.Attack(inst, inst.sg.statemem.aoeparams, inst:GetAOEAttackTagSet(), inst.sg.statemem.targets, 0.65)
			end
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/attack_aoe") end),
			--FrameEvent(18, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_shrill", nil, 0.5) end),


			FrameEvent(19, function(inst)
				if inst.ismodeswitching and inst.canvinecounter then
					inst.components.combat:ResetBattleCryCooldown()
					SpawnGroundVines(inst)
				end
				inst.sg.statemem.targets = {}
				inst.sg.statemem.aoeparams = GetAOEParams(0, 6, nil, 1)
				AOEUtil.Work(inst, 6, inst.sg.statemem.targets)
				AOEUtil.TossItems(inst, GetTossParams(6))
			end),
			FrameEvent(39, function(inst)
				inst.sg.statemem.targets = nil
				inst.sg.statemem.aoeparams = nil
			end),
			FrameEvent(40, function(inst)
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

	--[[State{
		name = "death_beta",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death_beta")
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden/charlie_death") end),
			
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/whoosh", nil, 0.6) end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_shrill", nil, 0.7) end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_subdued", nil, 0.5) end),
			FrameEvent(41, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(43, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/ground_hit", nil, 0.6) end),
			FrameEvent(41, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(70, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/ground_hit") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/die") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature2/die") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature1/die") end),

			FrameEvent(34, function(inst)
				if inst.sg.mem.killstarttime then
					local msg = SpawnPrefab("temp_beta_msg")
					msg:SetKillTime(GetTime() - inst.sg.mem.killstarttime, inst.prefab)
					Launch2(msg, inst, 3, 1, 6, 0.5, 12, inst.Transform:GetRotation())
					inst.sg.mem.killstarttime = nil
				end
			end),
			FrameEvent(69, function(inst)
				inst:DropDeathLoot()
				inst.persists = false

				inst.Physics:SetActive(false)

				local home = inst.components.knownlocations:GetLocation("spawnpoint")
				local x, _, z
				if home then
					x, _, z = home:Get()
				else
					x, z = TheWorld.Map:GetCharlieBossArenaCenterXZ()
					if x == nil then
						x, _, z = inst.Transform:GetWorldPosition()
					end
				end

				local shrouden = SpawnPrefab("shrouden")
				shrouden:TransferAOEAttackTagSetFrom(inst)
				shrouden.Transform:SetPosition(x, 0, z)
				shrouden.sg:GoToState("spawn")

				inst:PushEvent("track_charlie_boss", shrouden)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:AddTag("NOCLICK")
					inst.Physics:SetActive(false)
					inst.Light:Enable(false)
					ErodeAway(inst)
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},]]

	State{
		name = "death",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst)
			if inst.looted then
				inst.sg:GoToState("death_spawn_shrouden")
				return
			end
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death_beta")
			inst:SetCameraFocusLevel(1)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(6, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/whoosh", nil, 0.6) end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_shrill", nil, 0.7) end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/scream_subdued", nil, 0.5) end),
			FrameEvent(37, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(43, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/ground_hit", nil, 0.6) end),
			FrameEvent(39, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/die") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature2/die") end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature1/die") end),
			FrameEvent(90, function(inst) inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/pounce") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("death2")
				end
			end),
		},

		onexit = TryRestoreSixFaced,
	},

	State{
		name = "death2",
		tags = { "dead", "busy", "nointerrupt", "jumping" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death")
			inst.AnimState:PushAnimation("death2", false)
			inst.AnimState:AddOverrideBuild("charlie_boss_transform_v2")
			inst:SetCameraFocusLevel(3)
			RemovePhysicsColliders(inst)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/death") end),
			FrameEvent(160, function(inst) inst.SoundEmitter:PlaySound("rifts8/shadow_insanity_player/pounce", nil, 0.7) end),
			FrameEvent(169, function(inst) inst.SoundEmitter:PlaySound("rifts8/charlie/claw_swipe") end),
			FrameEvent(173, function(inst) inst.SoundEmitter:PlaySound("rifts2/charlie/charlie_hand_decline", nil, 0.7) end),
			--FrameEvent(176, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowhand_snuff", nil, 0.6) end),

			FrameEvent(0, function(inst)
				local home = inst.components.knownlocations:GetLocation("spawnpoint")
				if home then
					local x, _, z = inst.Transform:GetWorldPosition()
					local dx = home.x - x
					local dz = home.z - z
					local x1, z1
					if dx == 0 and dz == 0 then
						local theta = math.random() * TWOPI
						local tgtdist = 3 + math.random() * 2
						x1 = x + tgtdist * math.cos(theta)
						z1 = z - tgtdist * math.sin(theta)
					else
						local dsq = dx * dx + dz * dz
						if dsq < 36 then
							local dist = math.sqrt(dsq)
							local tgtdist = dist + 2 + math.random() * 2
							local k = tgtdist / dist
							x1 = x + dx * k
							z1 = z + dz * k
							k = (0.15 + math.random() * 0.2) * (math.random() < 0.5 and -1 or 1)
							x1 = x1 + dz * k
							z1 = z1 - dx * k
						else
							local k = 0.4 + math.random() * 0.2
							x1 = x + dx * k
							z1 = z + dz * k
							k = (0.2 + math.random() * 0.2) * (math.random() < 0.5 and -1 or 1)
							x1 = x1 + dz * k
							z1 = z1 - dx * k
						end
					end

					inst.Transform:SetRotation(math.atan2(z1 - z, x - x1) * RADIANS)

					inst.sg.statemem.x0, inst.sg.statemem.z0 = x, z
					inst.sg.statemem.x1, inst.sg.statemem.z1 = x1, z1
					inst.sg.statemem.x2, inst.sg.statemem.z2 = home.x, home.z
					inst.sg.statemem.t = 0
					inst.sg.statemem.len = 14 * FRAMES
					inst.sg.statemem.easefn = easing.outQuad

					inst.sg.statemem.onwallupdate = function(inst, dt)
						local t = inst.sg.statemem.t
						dt = dt * TheSim:GetTimeScale()
						if t and dt > 0 then
							t = t + dt
							local len = inst.sg.statemem.len
							if t < len then
								local k = inst.sg.statemem.easefn(t, 0, 1, len)
								local x3 = inst.sg.statemem.x0 * (1 - k) + inst.sg.statemem.x1 * k
								local z3 = inst.sg.statemem.z0 * (1 - k) + inst.sg.statemem.z1 * k
								inst.Transform:SetPosition(x3, 0, z3)
								inst.sg.statemem.t = t
							else
								inst.Transform:SetPosition(inst.sg.statemem.x1, 0, inst.sg.statemem.z1)
								inst.sg.statemem.t = nil
							end
						end
					end
					inst.components.updatelooper:AddOnWallUpdateFn(inst.sg.statemem.onwallupdate)
				end
			end),
			FrameEvent(23, function(inst)
				if inst.sg.statemem.onwallupdate then
					inst.sg.statemem.x0, inst.sg.statemem.z0 = inst.sg.statemem.x1, inst.sg.statemem.z1
					inst.sg.statemem.x1, inst.sg.statemem.z1 = inst.sg.statemem.x2, inst.sg.statemem.z2
					inst.sg.statemem.t = 0
					inst.sg.statemem.len = 23 * FRAMES
					inst.sg.statemem.easefn = easing.outCubic

					inst.Transform:SetRotation(math.atan2(inst.sg.statemem.z0 - inst.sg.statemem.z1, inst.sg.statemem.x1 - inst.sg.statemem.x0) * RADIANS)
				end
			end),
			FrameEvent(47, function(inst)
				if inst.sg.statemem.onwallupdate then
					inst.components.updatelooper:RemoveOnWallUpdateFn(inst.sg.statemem.onwallupdate)
					inst.sg.statemem.onwallupdate = nil
				end
				if inst.sg.statemem.x2 then
					inst.Transform:SetPosition(inst.sg.statemem.x2, 0, inst.sg.statemem.z2)
				end

				inst:SetCameraFocusLevel(4)
				ChangeToObstaclePhysics(inst, 0.9)

				local targets = {}
				AOEUtil.Work(inst, 1.25)
				AOEUtil.TossItems(inst, GetTossParams(1.25), targets)
				for k in pairs(targets) do
					if k:IsValid() and k.components.burnable and k.components.burnable:IsBurning() then
						k.components.burnable:Extinguish()
					end
				end
			end),
			FrameEvent(52, function(inst)
				local targets = {}
				AOEUtil.Work(inst, 2.6, targets)

				inst.components.combat:SetDefaultDamage(0)
				inst.components.planardamage:SetBaseDamage(0)
				AOEUtil.Attack(inst, GetAOEParams(0, 2.6, nil, 1, nil, true), inst:GetAOEAttackTagSet(), targets)
				inst.components.combat:SetDefaultDamage(TUNING.CHARLIE_BOSS_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.CHARLIE_BOSS_PLANAR_DAMAGE)

				targets = {}
				AOEUtil.TossItems(inst, GetTossParams(2.6, 2), targets)
				for k in pairs(targets) do
					if k:IsValid() and k.components.burnable and k.components.burnable:IsBurning() then
						k.components.burnable:Extinguish()
					end
				end
			end),
			FrameEvent(176, function(inst)
				inst:DropDeathLoot()
				inst.looted = true
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.dead = true
					local charlie_tracker = inst:IsInArena() and TheWorld.components.charlie_tracker or nil
					if charlie_tracker and not charlie_tracker:IsCharlieDefeated() then
						inst.sg:GoToState("death_charlie")
					else
						inst.sg:GoToState("death_no_charlie")
					end
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.onwallupdate then
				inst.components.updatelooper:RemoveOnWallUpdateFn(inst.sg.statemem.onwallupdate)
			end
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.dead then
				inst.AnimState:ClearOverrideBuild("charlie_boss_transform_v2")
				inst:SetCameraFocusLevel(0)
				ChangeToGiantCharacterPhysics(inst, 1000, 0.9)
			end
		end,
	},

	State{
		name = "death_charlie",
		tags = { "dead", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:SetBuild("charlie_basic")
			inst.AnimState:SetBankAndPlayAnimation("charlie_basic", "return_pre") --19 frames
			inst.AnimState:PushAnimation("return", false)
			inst:SetCameraFocusLevel(4)
			inst.Physics:SetActive(false)
			inst.Light:Enable(false)
			inst:AddTag("NOCLICK")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("dontstarve/charlie/ohno", nil, 0.5) end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("rifts2/thrall_generic/death_cloth", nil, 0.8) end),
			FrameEvent(46, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/dissappear", nil, 0.8) end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/movement_pst", nil, 0.8) end),
			FrameEvent(58, function(inst) inst.SoundEmitter:PlaySound("rifts4/mimic/item_become_poof") end),
			FrameEvent(99, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/eye_movement") end),
			FrameEvent(99, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowhand_snuff", nil, 0.4) end),
			FrameEvent(97, function(inst) inst.SoundEmitter:PlaySound("rifts4/goop/absorb") end),

			FrameEvent(19 + 47, function(inst)
				inst.sg:AddStateTag("flight")
			end),
			FrameEvent(19 + 83, function(inst)
				inst.sg:AddStateTag("invisible")
			end),
			FrameEvent(19 + 83, function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg.statemem.dead = true
				inst.sg:GoToState("death_spawn_shrouden", true)
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.dead then
				inst.AnimState:SetBank("charlie_boss")
				inst.AnimState:SetBuild("charlie_boss_basic")
				inst.AnimState:ClearOverrideBuild("charlie_boss_transform_v2")
				inst:SetCameraFocusLevel(0)
				ChangeToGiantCharacterPhysics(inst, 1000, 0.9)
				inst.Physics:SetActive(true)
				inst.Light:Enable(true)
				inst:RemoveTag("NOCLICK")
			end
		end,
	},

	State{
		name = "death_no_charlie",
		tags = { "dead", "busy", "nointerrupt", "noattack", "flight" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			SwitchToNoFaced(inst)
			inst.AnimState:PlayAnimation("death3")
			inst:SetCameraFocusLevel(3)
			inst.Physics:SetActive(false)
			inst.Light:Enable(false)
			inst:AddTag("NOCLICK")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts4/mimic/item_become_poof") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts8/shrouden_portal/eye_movement") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowhand_snuff", nil, 0.4) end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts4/goop/absorb") end),

			FrameEvent(2, function(inst)
				inst.sg.statemem.keepnofaced = true
				inst.sg.statemem.dead = true
				inst.sg:GoToState("death_spawn_shrouden", true)
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			if not inst.sg.statemem.dead then
				inst.AnimState:ClearOverrideBuild("charlie_boss_transform_v2")
				inst:SetCameraFocusLevel(0)
				ChangeToGiantCharacterPhysics(inst, 1000, 0.9)
				inst.Physics:SetActive(true)
				inst.Light:Enable(true)
				inst:RemoveTag("NOCLICK")
			end
		end,
	},

	State{
		name = "death_spawn_shrouden",
		tags = { "dead", "busy", "nointerrupt", "noattack", "invisible", "flight" },

		onenter = function(inst, waitforanim)
			inst.components.locomotor:Stop()
			inst.Physics:SetActive(false)
			inst.Light:Enable(false)
			inst:AddTag("NOCLICK")

			if waitforanim then
				inst:SetCameraFocusLevel(4)
				inst.sg:SetTimeout(0)
			else
				inst:SetCameraFocusLevel(1)
				inst:Hide()
				inst.sg:SetTimeout(FRAMES)
			end
		end,

		ontimeout = function(inst)
			local home = inst.components.knownlocations:GetLocation("spawnpoint")
			local x, _, z
			if home then
				x, _, z = home:Get()
			else
				if inst:IsInArena() then
					x, z = TheWorld.Map:GetCharlieBossArenaCenterXZ()
				end
				if x == nil then
					x, _, z = inst.Transform:GetWorldPosition()
				end
			end

			local shrouden = SpawnPrefab("shrouden")
			shrouden:TransferAOEAttackTagSetFrom(inst)
			shrouden.Transform:SetPosition(x, 0, z)
			shrouden.sg:GoToState("spawn")

			if inst:IsInArena() then
				inst:PushEvent("track_charlie_boss", shrouden)
			end

			if inst.entity:IsVisible() and not inst.AnimState:AnimDone() then
				inst.persists = false
			else
				inst:Remove()
			end
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
			end),
		},

		onexit = function(inst)
			TryRestoreSixFaced(inst)
			inst.AnimState:SetBank("charlie_boss")
			inst.AnimState:SetBuild("charlie_boss_basic")
			inst.AnimState:ClearOverrideBuild("charlie_boss_transform_v2")
			inst:SetCameraFocusLevel(0)
			ChangeToGiantCharacterPhysics(inst, 1000, 0.9)
			inst.Physics:SetActive(true)
			inst.Light:Enable(true)
			inst:RemoveTag("NOCLICK")
		end,
	},
}

CommonStates.AddWalkStates(states)

return StateGraph("charlie_boss", states, events, "init")
