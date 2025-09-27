require("stategraphs/commonstates")
local easing = require("easing")
local WagBossUtil = require("prefabs/wagboss_util")

local function ChooseAttack(inst, target)
	target = target or inst.components.combat.target
	if not (target and target:IsValid()) then
		return false
	end

	if inst.cansupernova and not inst.components.timer:TimerExists("supernova_cd") then
		inst.sg:GoToState("supernova")
		return true
	end

	if not (inst.dashcombo and inst.dashcount < inst.dashcombo) and
		not (inst.slamcombo and inst.slamcount < inst.slamcombo)
	then
		inst:ResetCombo()
	end

	if inst.dashcombo and inst.dashcount < inst.dashcombo then
		inst.dashcount = inst.dashcount + (inst.dashrnd and math.random(2) or 1)
		inst.sg:GoToState("dash_pre", target)
		return true
	elseif inst.slamcombo and inst.slamcount < inst.slamcombo then
		inst.slamcount = inst.slamcount + (inst.slamrnd and math.random(2) or 1)
		--V2C: if we ever have a phase where it can only slam, then we should not taunt
		--if inst.dashcombo then
			inst.sg:GoToState("taunt", target)
		--else
		--	inst.sg:GoToState("slam", target)
		--end
		return true
	end
	return false
end

local events =
{
	CommonHandlers.OnLocomote(false, true),
	CommonHandlers.OnAttacked(nil, math.huge), --hit delay only for projectiles
	CommonHandlers.OnDeath(),
	EventHandler("doattack", function(inst, data)
		if not inst.sg:HasStateTag("busy") then
			ChooseAttack(inst, data and data.target or nil)
		end
	end),
}

--------------------------------------------------------------------------

local function DoTauntShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 1.6, 0.05, 0.2, inst, 40)
end

local function DoSlamShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.3, 0.04, 0.2, inst, 40)
end

local function DoSlamShake2(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.7, 0.03, 0.35, inst, 40)
end

local function DoChargingShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 3, 0.03, 0.1, inst, 40)
end

local function DoChargingShakeMild(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 3, 0.04, 0.06, inst, 40)
end

local function DoSupernovaShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 1.55, 0.04, 0.4, inst, 40)
end

local function DoSelfDestructShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 1.2, 0.04, 0.75, inst, 40)
end

--------------------------------------------------------------------------

local DASH_SPEED = 14
local DASH_TRACKING = 0.25
local DASH_TRACKING_MAXDROT_DECAY = 0.75

--------------------------------------------------------------------------

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "brightmare" }

local function _AOEAttack(inst, x, z, radius, heavymult, mult, forcelanded, targets)
	inst.components.combat.ignorehitrange = true
	local t = GetTime()
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and targets[v] == nil and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range and inst.components.combat:CanTarget(v) then
				inst.components.combat:DoAttack(v)
				if mult then
					local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					v:PushEvent("knockback", { knocker = inst, radius = radius, strengthmult = strengthmult, forcelanded = forcelanded })
				end
				targets[v] = t
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
local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO", "wagdrone" }

local function _AOEWork(inst, x, z, radius, targets)
	local t = GetTime()
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + WORK_RADIUS_PADDING, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)) do
		if targets[v] == nil and
			v:IsValid() and not v:IsInLimbo() and
			v.components.workable
		then
			local work_action = v.components.workable:GetWorkAction()
			--V2C: nil action for NPC_workable (e.g. campfires)
			--     no digging, so don't need to check for spawners (e.g. rabbithole)
			if (work_action == nil and v:HasTag("NPC_workable")) or
				(v.components.workable:CanBeWorked() and work_action and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
			then
				v.components.workable:Destroy(inst)
				targets[v] = t
			end
		end
	end
end

local TOSSITEM_MUST_TAGS = { "_inventoryitem" }
local TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" }

local function _TossLaunch(inst, x0, z0, basespeed, startheight)
	local x1, y1, z1 = inst.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local dsq = dx * dx + dz * dz
	local angle
	if dsq > 0 then
		local dist = math.sqrt(dsq)
		angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
	else
		angle = TWOPI * math.random()
	end
	local sina, cosa = math.sin(angle), math.cos(angle)
	local speed = basespeed + math.random()
	inst.Physics:Teleport(x1, startheight, z1)
	inst.Physics:SetVel(cosa * speed, speed * 5 + math.random() * 2, sina * speed)
end

local function _TossItems(inst, x, z, radius)
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + WORK_RADIUS_PADDING, TOSSITEM_MUST_TAGS, TOSSITEM_CANT_TAGS)) do
		if v.components.mine then
			v.components.mine:Deactivate()
		end
		if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
			_TossLaunch(v, x, z, 1.2, 0.1)
		end
	end
end

local function DoSlamAOE(inst, x, z, targets, shouldtoss)
	_AOEWork(inst, x, z, 5, targets)
	_AOEAttack(inst, x, z, 5, 1, 1, false, targets)
	if shouldtoss then
		_TossItems(inst, x, z, 5)
	end
end

local function DoDashAOE(inst, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	_AOEWork(inst, x, z, 3.6, targets)
	_AOEAttack(inst, x, z, 3.6, 1, 1, false, targets)
end

--------------------------------------------------------------------------

local REGISTERED_SUPERNOVA_AOE_TAGS

local function UpdateSupernovaAOE(inst, dt, firsthit)
	if inst.sg.statemem.updatedelay > dt then
		inst.sg.statemem.updatedelay = inst.sg.statemem.updatedelay - dt
		return
	end
	inst.sg.statemem.updatedelay = 0.5

	local map = TheWorld.Map
	local x, _, z = inst.Transform:GetWorldPosition()
	local cx, cz = x, z
	local inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z)
	if inarena then
		cx, cz = map:GetWagPunkArenaCenterXZ()
		--NOTE: center won't be nil if IsPointInWagPunkArena succeeded
	end

	if REGISTERED_SUPERNOVA_AOE_TAGS == nil then
		REGISTERED_SUPERNOVA_AOE_TAGS = TheSim:RegisterFindTags(
			nil,
			{ "FX", "DECOR", "INLIMBO", "flight", "noattack", "notarget", "invisible", "wall", "brightmare", "brightmareboss", "shadowcreature" },
			{ "_health", "lunarsupernovablocker" }
		)
	end
	inst.components.combat.ignorehitrange = true
	for i, v in ipairs(TheSim:FindEntities_Registered(cx, 0, cz, inarena and 40 or WagBossUtil.SupernovaNoArenaRange, REGISTERED_SUPERNOVA_AOE_TAGS)) do
		if v:IsValid() and not v:IsInLimbo() and
			(not inarena or map:IsPointInWagPunkArena(v.Transform:GetWorldPosition()))
		then
			if v.components.lunarsupernovablocker then
				v.components.lunarsupernovablocker:AddSource(inst)
			elseif firsthit or v.components.lunarsupernovaburning == nil then
				if firsthit and v.components.combat and v.components.combat:CanTarget(v) then
					local x1, _, z1 = v.Transform:GetWorldPosition()
					local blockers = WagBossUtil.FindSupernovaBlockersNearXZ(x1, z1)
					if not WagBossUtil.IsSupernovaBlockedAtXZ(x, z, x1, z1, blockers) then
						inst.components.combat:DoAttack(v)
					end
				end
				if v.components.health and not v.components.health:IsDead() then
					if v.components.lunarsupernovaburning == nil then
						v:AddComponent("lunarsupernovaburning")
					end
					v.components.lunarsupernovaburning:AddSource(inst)
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

--------------------------------------------------------------------------

local TILE_SIZE = 4
local DIAG_TILE_SIZE = math.sqrt(2 * TILE_SIZE * TILE_SIZE)

local function SnapTo45s(angle)
	return math.floor(angle / 45 + 0.5) * 45
end

local function DoFissures(inst, offset)
	offset = offset or 1

	local map = TheWorld.Map
	local x, _, z = inst.Transform:GetWorldPosition()
	if map:IsPointInWagPunkArena(x, 0, z) then
		x, _, z = map:GetTileCenterPoint(x, 0, z)

		assert(next(inst._temptbl1) == nil)
		local tospawn = inst._temptbl1
		local numtospawn = 0
		local numvalidrows = 0
		local rot = SnapTo45s(inst.Transform:GetRotation())
		local theta = rot * DEGREES
		if bit.band(math.floor(rot / 45 + 0.5), 1) == 0 then
			--on 90s
			local dx = TILE_SIZE * math.cos(theta)
			local dz = -TILE_SIZE * math.sin(theta)

			--start row offset
			x = x + offset * dx
			z = z + offset * dz

			local w = 1
			while true do
				local x1, z1 = x, z
				x = x + w * dz
				z = z - w * dx
				local inarena = false
				for i = -w, w do
					if map:IsPointInWagPunkArena(x, 0, z) then
						local id = WagBossUtil.TileCoordsToId(map:GetTileCoordsAtPoint(x, 0, z))
						if not WagBossUtil.HasFissure(id) then
							tospawn[id] = true
							numtospawn = numtospawn + 1
						end
						inarena = true
					end
					x = x - dz
					z = z + dx
				end
				if not inarena then
					break
				end
				numvalidrows = numvalidrows + 1
				w = w == 1 and 3 or w + 1
				x = x1 + dx
				z = z1 + dz
			end
		else
			local dx = DIAG_TILE_SIZE * math.cos(theta)
			local dz = -DIAG_TILE_SIZE * math.sin(theta)

			--start row offset
			x = x + dx * offset / 2
			z = z + dz * offset / 2

			local w = bit.band(offset, 1) == 0 and 1 or 0.5
			while true do
				local x1, z1 = x, z
				x = x + w * dz
				z = z - w * dx
				local inarena = false
				for i = -w, w do
					if map:IsPointInWagPunkArena(x, 0, z) then
						local id = WagBossUtil.TileCoordsToId(map:GetTileCoordsAtPoint(x, 0, z))
						if not WagBossUtil.HasFissure(id) then
							tospawn[id] = true
							numtospawn = numtospawn + 1
						end
						inarena = true
					end
					x = x - dz
					z = z + dx
				end
				if not inarena then
					break
				end
				numvalidrows = numvalidrows + 1
				w = w == 0.5 and 2 or w + 0.5
				x = x1 + dx / 2
				z = z1 + dz / 2
			end
		end

		if (numvalidrows < 2 or (numvalidrows < 3 and numtospawn < numvalidrows)) and offset >= 0 then
			for k in pairs(tospawn) do
				tospawn[k] = nil
			end
			--assert(next(tospawn) == nil)
			return DoFissures(inst, offset - 1)
		end

		local fissures = {}
		for id in pairs(tospawn) do
			local tx, ty = WagBossUtil.IdToTileCoords(id)
			x, _, z = map:GetTileCenterPoint(tx, ty)
			tospawn[id] = nil
			local fissure = WagBossUtil.SpawnFissureAtXZ(x, z, id, tx, ty)
			fissure:StartTrackingBoss(inst)
			table.insert(fissures, fissure)
		end
		assert(next(tospawn) == nil)
		return fissures
	end
end

--------------------------------------------------------------------------

local function SetPreventDeath(inst, prevent)
	inst.components.health:SetMinHealth(
		prevent and
		not inst.components.health:IsDead() and
		math.min(1, inst.components.health.currenthealth) or
		nil
	)
end

--------------------------------------------------------------------------

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("idle", true)
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepeightfaced then
				inst:SwitchToFourFaced()
			end
		end,
	},

	State{
		name = "idle_nofaced",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("idle_nofaced", true)
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
		end,
	},

	State{
		name = "spawn",
		tags = { "busy", "nointerrupt", "noattack", "tempinvincible" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			inst:EnableCameraFocus(true)
			inst.AnimState:PlayAnimation("lunar_spawn_1")
			inst.AnimState:PushAnimation("lunar_spawn_2", false)
			--these are part of constructor pristine state now
			if inst.inittask then
				inst.inittask:Cancel()
				inst.inittask = nil
			end
			if inst.sg.mem.hasspawnbuild then
				inst.sg.mem.hasspawnbuild = nil
			else
				inst.AnimState:Hide("robot_front")
				inst.AnimState:Hide("robot_back")
				inst.AnimState:OverrideSymbol("splat_liquid", "wagboss_lunar_spawn", "splat_liquid")
				inst.AnimState:SetFinalOffset(-2)
				inst.SoundEmitter:KillSound("idleb")
			end
		end,

		timeline =
		{
			FrameEvent(159, function(inst)
				inst.SoundEmitter:PlaySound("rifts5/lunar_boss/idle_b_LP", "idleb")
			end),
			FrameEvent(190, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),

			--#SFX
			--DO NOT ADD SOUNDS HERE
			--These go into SGwagboss_robot.lua, "death" state timeline
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.taunt = true
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("taunt", true)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			inst.AnimState:Show("robot_front")
			inst.AnimState:Show("robot_back")
			inst.AnimState:ClearOverrideSymbol("splat_liquid")
			inst.AnimState:SetFinalOffset(-1)
			if not inst.sg.statemem.taunt then
				inst:StartDomainExpansion()
				inst:SetMusicLevel(3)
				inst:EnableCameraFocus(false)
			end
			if not inst.SoundEmitter:PlayingSound("idleb") then
				inst.SoundEmitter:PlaySound("rifts5/lunar_boss/idle_b_LP", "idleb")
			end
		end,
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
			FrameEvent(15, function(inst)
				if inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				end
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/hit") end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/footstep") end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if inst.sg:HasStateTag("busy") then
					if data and data.target then
						inst.sg.statemem.doattack = data.target
					end
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
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst, target_or_triggerlunacy)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("taunt")
			if inst.sg.lasttags and inst.sg.lasttags["noattack"] then
				inst.sg:AddStateTag("noattack")
			end
			if target_or_triggerlunacy == true then
				inst.sg.statemem.triggerlunacy = true
				inst:EnableCameraFocus(true)
			elseif target_or_triggerlunacy and target_or_triggerlunacy:IsValid() then
				inst.sg.statemem.target = target_or_triggerlunacy
				inst:ForceFacePoint(target_or_triggerlunacy.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			FrameEvent(23, function(inst)
				if inst.sg.statemem.triggerlunacy then
					inst.sg.statemem.triggerlunacy = false
					inst:StartDomainExpansion()
					inst.components.epicscare:Scare(5)
				end
			end),
			FrameEvent(28, DoTauntShake),
			FrameEvent(60, function(inst)
				inst.sg:RemoveStateTag("noattack")
			end),
			FrameEvent(67, function(inst)
				if inst.sg.statemem.target == nil and inst.sg.statemem.doattack == nil then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(80, function(inst)
				if inst.sg.statemem.target then
					inst.sg:GoToState("slam", inst.sg.statemem.target)
					return
				elseif inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				end
				inst.sg:RemoveStateTag("busy")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound((inst.sg.statemem.triggerlunacy == false) and "rifts5/lunar_boss/taunt_emerge" or "rifts5/lunar_boss/taunt") end),
		},

		events =
		{
			EventHandler("doattack", function(inst, data)
				if inst.sg:HasStateTag("busy") then
					if data and data.target then
						inst.sg.statemem.doattack = data.target
						inst.sg:RemoveStateTag("caninterrupt")
					end
					return true
				end
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle_nofaced")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			if inst.sg.statemem.triggerlunacy ~= nil then
				if inst.sg.statemem.triggerlunacy then
					inst:StartDomainExpansion()
				end
				inst:SetMusicLevel(3)
				inst:EnableCameraFocus(false)
				if TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition()) then
					TheWorld:PushEvent("ms_wagstaff_arena_oneshot", { strname = "WAGSTAFF_WAGPUNK_ARENA_SCIONREVEAL", monologue = true, focusentity = inst })
				end
			end
		end,
	},

	State{
		name = "slam",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst:SwitchToEightFaced()
			inst.AnimState:PlayAnimation("slam")
			local dir
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				dir = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
			else
				dir = inst.Transform:GetRotation()
			end
			inst.sg.statemem.lastdir = dir
			inst.Transform:SetRotation(SnapTo45s(dir))
		end,

		onupdate = function(inst)
			local target = inst.sg.statemem.target
			if target then
				if target:IsValid() then
					local dir = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
					local drot = ReduceAngle(dir - inst.sg.statemem.lastdir)
					if math.abs(drot) < 90 then
						dir = inst.sg.statemem.lastdir + math.clamp(drot / 2, -2, 2)
						inst.sg.statemem.lastdir = dir
						inst.Transform:SetRotation(SnapTo45s(dir))
					end
				else
					inst.sg.statemem.target = nil
				end
			end
		end,

		timeline =
		{
			FrameEvent(34, function(inst)
				inst.sg.statemem.target = nil --stop tracking
			end),
			FrameEvent(42, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				local dir = inst.Transform:GetRotation()
				local delta = 45
				local r = 3
				local theta = (dir + delta) * DEGREES
				inst.sg.statemem.x1 = x + r * math.cos(theta)
				inst.sg.statemem.z1 = z - r * math.sin(theta)
				theta = (dir - delta) * DEGREES
				inst.sg.statemem.x2 = x + r * math.cos(theta)
				inst.sg.statemem.z2 = z - r * math.sin(theta)

				local fx1 = SpawnPrefab("alterguardian_phase4_lunarrift_slam_fx")
				fx1.Transform:SetPosition(inst.sg.statemem.x1, 0, inst.sg.statemem.z1)

				local fx2 = SpawnPrefab("alterguardian_phase4_lunarrift_slam_fx")
				fx2.Transform:SetPosition(inst.sg.statemem.x2, 0, inst.sg.statemem.z2)

				inst.sg.statemem.fx = { fx1, fx2 }
			end),
			FrameEvent(43, function(inst)
				--hit ground
				DoSlamShake(inst)

				--clear fx refs since they shouldn't be cancellable anymore once we've hit
				inst.sg.statemem.fx[1] = nil
				inst.sg.statemem.fx[2] = nil

				inst.components.combat:RestartCooldown()

				inst.sg.statemem.targets = {}
				DoSlamAOE(inst, inst.sg.statemem.x1, inst.sg.statemem.z1, inst.sg.statemem.targets, true)
				DoSlamAOE(inst, inst.sg.statemem.x2, inst.sg.statemem.z2, inst.sg.statemem.targets, true)
			end),
			FrameEvent(44, function(inst)
				DoSlamAOE(inst, inst.sg.statemem.x1, inst.sg.statemem.z1, inst.sg.statemem.targets, false)
				DoSlamAOE(inst, inst.sg.statemem.x2, inst.sg.statemem.z2, inst.sg.statemem.targets, false)
			end),
			FrameEvent(76 - 17, function(inst)
				inst.sg.statemem.fissures = DoFissures(inst)
			end),
			FrameEvent(74, function(inst)
				local x1, z1 = inst.sg.statemem.x1, inst.sg.statemem.z1
				local x2, z2 = inst.sg.statemem.x2, inst.sg.statemem.z2
				local dir = inst.Transform:GetRotation()
				for i = -9, 171, 60 do
					local theta = (dir + i) * DEGREES
					local offsx = 3.25 * math.cos(theta)
					local offsz = -3.25 * math.sin(theta)
					local fx = SpawnPrefab("alterguardian_phase4_lunarrift_erupt_fx")
					fx.Transform:SetPosition(x1 + offsx, 0, z1 + offsz)
					table.insert(inst.sg.statemem.fx, fx)

					theta = (dir - i) * DEGREES
					offsx = 3.25 * math.cos(theta)
					offsz = -3.25 * math.sin(theta)
					fx = SpawnPrefab("alterguardian_phase4_lunarrift_erupt_fx")
					fx.Transform:SetPosition(x2 + offsx, 0, z2 + offsz)
					table.insert(inst.sg.statemem.fx, fx)
				end
			end),
			FrameEvent(75, function(inst)
				local fx1 = SpawnPrefab("alterguardian_phase4_lunarrift_slam_fx")
				fx1.Transform:SetPosition(inst.sg.statemem.x1, 0, inst.sg.statemem.z1)

				local fx2 = SpawnPrefab("alterguardian_phase4_lunarrift_slam_fx")
				fx2.Transform:SetPosition(inst.sg.statemem.x2, 0, inst.sg.statemem.z2)

				table.insert(inst.sg.statemem.fx, fx1)
				table.insert(inst.sg.statemem.fx, fx2)
			end),
			FrameEvent(76, function(inst)
				DoSlamShake2(inst)

				--clear refs since they shouldn't be cancellable anymore once we've hit
				inst.sg.statemem.fx = nil
				inst.sg.statemem.fissures = nil

				inst.components.combat:RestartCooldown()

				--reset targets for 2nd hit
				inst.sg.statemem.targets = {}
				DoSlamAOE(inst, inst.sg.statemem.x1, inst.sg.statemem.z1, inst.sg.statemem.targets, true)
				DoSlamAOE(inst, inst.sg.statemem.x2, inst.sg.statemem.z2, inst.sg.statemem.targets, true)
			end),
			FrameEvent(77, function(inst)
				DoSlamAOE(inst, inst.sg.statemem.x1, inst.sg.statemem.z1, inst.sg.statemem.targets, false)
				DoSlamAOE(inst, inst.sg.statemem.x2, inst.sg.statemem.z2, inst.sg.statemem.targets, false)
			end),
			FrameEvent(117, function(inst)
				inst.sg:AddStateTag("caninterrupt")
				inst.components.combat:RestartCooldown()
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/slam") end),
			FrameEvent(106, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
			FrameEvent(123, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepeightfaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepeightfaced then
				inst:SwitchToFourFaced()
			end
			if inst.sg.statemem.fx then
				for _, v in ipairs(inst.sg.statemem.fx) do
					v:Remove()
				end
			end
			if inst.sg.statemem.fissures then
				for _, v in ipairs(inst.sg.statemem.fissures) do
					v:Remove()
				end
			end
		end,
	},

	State{
		name = "dash_pre",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst:SwitchToEightFaced()
			inst.AnimState:PlayAnimation("dash_pre")
			inst.SoundEmitter:PlaySound("rifts5/lunar_boss/dash_lp", "dashloop")
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.targetpos = target:GetPosition()

				local x, _, z = inst.Transform:GetWorldPosition()
				local dx = inst.sg.statemem.targetpos.x - x
				local dz = inst.sg.statemem.targetpos.z - z
				local dir, theta
				if dx ~= 0 or dz ~= 0 then
					theta = math.atan2(-dz, dx)
				else
					dir = inst.Transform:GetRotation()
				end
				if inst.dashcenter and inst:IsSlamNext() then
					local map = TheWorld.Map
					if map:IsPointInWagPunkArena(x, 0, z) then
						local cx, cz = map:GetWagPunkArenaCenterXZ()
						--NOTE: center won't be nil if IsPointInWagPunkArena succeeded
						if x ~= cx or z ~= cz then
							theta = theta or dir * RADIANS
							local dist = 22.7
							local x1 = x + math.cos(theta) * dist
							local z1 = z - math.sin(theta) * dist
							if distsq(x1, z1, cx, cz) >= 256 then
								--ends up too far at edge of arena, aim back toward center
								--dist = 13.4
								theta = math.atan2(z - cz, cx - x)
								theta = theta + (math.random() - 0.5) * math.pi / 4
								dir = theta * RADIANS
								inst.sg.statemem.target = nil
								inst.sg.statemem.targetpos = nil
							end
						end
					end
				end
				inst.Transform:SetRotation(dir or theta * RADIANS)
			end
		end,

		onupdate = function(inst, dt)
			if dt > 0 then
				local pt = inst.sg.statemem.targetpos
				if pt then
					local target = inst.sg.statemem.target
					if target then
						if target:IsValid() then
							pt.x, pt.y, pt.z = target.Transform:GetWorldPosition()
						else
							inst.sg.statemem.target = nil
						end
					end
					local rot = inst.Transform:GetRotation()
					local rot1 = inst:GetAngleToPoint(pt)
					local drot = ReduceAngle(rot1 - rot) * DASH_TRACKING
					local maxdrot = inst.sg.statemem.maxdrot
					if maxdrot then
						drot = (inst.sg.statemem.lastdrot + drot) / 2
						drot = math.clamp(drot, -maxdrot, maxdrot)
						inst.sg.statemem.lastdrot = drot
						maxdrot = maxdrot * DASH_TRACKING_MAXDROT_DECAY
						if inst.sg.statemem.finalframe then
							maxdrot = math.min(math.abs(drot), maxdrot)
						end
						inst.sg.statemem.maxdrot = maxdrot
					end
					inst.Transform:SetRotation(rot + drot)
				end

				if inst.sg.statemem.accelt then
					local t = inst.sg.statemem.accelt + dt
					inst.sg.statemem.accelt = t
					local speed = easing.inQuad(t, 0, DASH_SPEED, 10 * FRAMES)
					inst.Physics:SetMotorVelOverride(speed, 0, 0)
				end
			end
		end,

		timeline =
		{
			FrameEvent(37, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				SetPreventDeath(inst, true)
			end),
			FrameEvent(54, function(inst)
				inst.sg.statemem.accelt = 0
				inst.sg.statemem.lastdrot = 0
				inst.sg.statemem.maxdrot = 90
			end),
			FrameEvent(62, function(inst)
				inst.sg.statemem.finalframe = true
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/wagstaff_boss/???") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepeightfaced = true
					inst.sg.statemem.dashing = true
					inst.sg:GoToState("dash_loop",
						inst.sg.statemem.targetpos and {
							target = inst.sg.statemem.target,
							targetpos = inst.sg.statemem.targetpos,
							lastdrot = inst.sg.statemem.lastdrot,
							maxdrot = inst.sg.statemem.maxdrot,
							loops = 2,
						} or nil)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepeightfaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.dashing then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				SetPreventDeath(inst, false)
				inst.SoundEmitter:KillSound("dashloop")
			end
		end,
	},

	State{
		name = "dash_loop",
		tags = { "attack", "busy", "jumping", "nointerrupt" },

		onenter = function(inst, data)
			inst:SwitchToEightFaced()
			if not inst.AnimState:IsCurrentAnimation("dash_loop") then
				inst.AnimState:PlayAnimation("dash_loop", true)
			end
			if not inst.SoundEmitter:PlayingSound("dashloop") then
				inst.SoundEmitter:PlaySound("rifts5/lunar_boss/dash_lp", "dashloop")
			end
			inst.Physics:SetMotorVelOverride(DASH_SPEED, 0, 0)
			SetPreventDeath(inst, true)
			inst:StartDashFx()
			if data == nil then
				data = { targets = {} }
			elseif data.targets == nil then
				data.targets = {}
			end
			inst.sg.statemem.data = data
			inst.components.combat:RestartCooldown()
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		onupdate = function(inst)
			local data = inst.sg.statemem.data
			local pt = data.targetpos
			if pt then
				local target = data.target
				if target then
					if target:IsValid() then
						pt.x, pt.y, pt.z = target.Transform:GetWorldPosition()
					else
						data.target = nil
					end
				end
				local rot = inst.Transform:GetRotation()
				local rot1 = inst:GetAngleToPoint(pt)
				local drot = ReduceAngle(rot1 - rot) * DASH_TRACKING
				local maxdrot = data.maxdrot or 0
				drot = ((data.lastdrot or 0) + drot) / 2
				drot = math.clamp(drot, -maxdrot, maxdrot)
				data.lastdrot = drot
				data.maxdrot = math.min(math.abs(drot), maxdrot * DASH_TRACKING_MAXDROT_DECAY)
				inst.Transform:SetRotation(rot + drot)
			end

			DoDashAOE(inst, data.targets)
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/wagstaff_boss/???") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.keepeightfaced = true
			inst.sg.statemem.dashing = true
			local data = inst.sg.statemem.data
			local loops = data.loops or 1
			if loops > 1 then
				data.loops = loops - 1
				inst.sg.statemem.dashlooping = true
				inst.sg:GoToState("dash_loop", data)
			else
				inst.components.combat:RestartCooldown()
				inst.sg:GoToState("dash_pst", data.targets)
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepeightfaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.dashing then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				SetPreventDeath(inst, false)
			end
			if not inst.sg.statemem.dashlooping then
				inst.SoundEmitter:KillSound("dashloop")
				inst:StopDashFx()
			end
		end,
	},

	State{
		name = "dash_pst",
		tags = { "attack", "busy", "jumping", "nointerrupt" },

		onenter = function(inst, targets)
			inst:SwitchToEightFaced()
			inst.AnimState:PlayAnimation("dash_pst")
			SetPreventDeath(inst, true)
			if targets then
				inst.sg.statemem.targets = targets
				local t = GetTime() - 0.5
				for k, v in pairs(targets) do
					if v < t then
						targets[k] = nil
					end
				end
			end
			inst.sg.statemem.decelt = 0
		end,

		onupdate = function(inst, dt)
			if inst.sg.statemem.decelt and dt > 0 then
				local t = inst.sg.statemem.decelt + dt
				inst.sg.statemem.decelt = t
				local speed = easing.inQuad(t, 10, -10, 11 * FRAMES)
				if speed > 0.01 then
					inst.Physics:SetMotorVelOverride(speed, 0, 0)
				else
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
					inst.sg.statemem.decelt = nil
				end
			end

			if inst.sg.statemem.targets then
				DoDashAOE(inst, inst.sg.statemem.targets)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.sg.statemem.targets = nil
			end),
			FrameEvent(44, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				SetPreventDeath(inst, false)
			end),
			FrameEvent(54, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(64, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/dash_pst") end),
			FrameEvent(43, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
			--FrameEvent(45, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepeightfaced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepeightfaced then
				inst:SwitchToFourFaced()
			end
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			SetPreventDeath(inst, false)
		end,
	},

	State{
		name = "supernova",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.combat:StartAttack()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("atk_burst_pre")
		end,

		timeline =
		{
			FrameEvent(44, function(inst)
				inst:AddTag("supernova")
				inst:SetMusicLevel(3, true) --force music to update supernova mix
			end),
			FrameEvent(51, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.sg:AddStateTag("noattack")
				SetPreventDeath(inst, true)
				if not inst.SoundEmitter:PlayingSound("charging") then
					inst.SoundEmitter:PlaySound("rifts5/lunar_boss/supernova_buildup_LP", "charging")
				end
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/???") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.supernova = true
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("supernova_charging", 4)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.supernova then
				SetPreventDeath(inst, false)
				inst:RemoveTag("supernova")
				inst.SoundEmitter:KillSound("charging")
			end
		end,
	},

	State{
		name = "supernova_charging",
		tags = { "attack", "busy", "nointerrupt", "noattack" },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			if not inst.AnimState:IsCurrentAnimation("atk_burst_charge_loop") then
				inst.AnimState:PlayAnimation("atk_burst_charge_loop", true)
				DoChargingShakeMild(inst)
			else
				DoChargingShake(inst)
			end
			if not inst.SoundEmitter:PlayingSound("charging") then
				inst.SoundEmitter:PlaySound("rifts5/lunar_boss/supernova_buildup_LP", "charging")
			end
			SetPreventDeath(inst, true)
			inst:AddTag("supernova")
			inst.components.timer:StopTimer("supernova_cd")
			inst.components.timer:StartTimer("supernova_cd", TUNING.ALTERGUARDIAN_PHASE4_SUPERNOVA_CD)
			inst:ResetCombo()
			inst.components.epicscare:Scare(5)
			inst.sg.statemem.loops = loops or 1
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/???") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.supernova = true
			inst.sg.statemem.keepnofaced = true
			if inst.sg.statemem.loops > 1 then
				inst.sg:GoToState("supernova_charging", inst.sg.statemem.loops - 1)
			else
				inst.sg:GoToState("supernova_burst_pre")
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.supernova then
				SetPreventDeath(inst, false)
				inst:RemoveTag("supernova")
				inst.SoundEmitter:KillSound("charging")
			end
		end,
	},

	State{
		name = "supernova_burst_pre",
		tags = { "attack", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("atk_burst_charge_to_shoot")
			SetPreventDeath(inst, true)
			inst:AddTag("supernova")
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/wagstaff_boss/???") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.SoundEmitter:PlaySound("rifts5/lunar_boss/supernova_buildup_pst")
					inst.sg.statemem.supernova = true
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("supernova_burst_loop")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.supernova then
				SetPreventDeath(inst, false)
				inst:RemoveTag("supernova")
			end
			inst.SoundEmitter:KillSound("charging")
		end,
	},

	State{
		name = "supernova_burst_loop",
		tags = { "attack", "busy", "nointerrupt", "supernovaburning"--[[used by lunarsupernovaburning component]] },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			inst.components.timer:StopTimer("supernova_cd")
			inst.components.timer:StartTimer("supernova_cd", TUNING.ALTERGUARDIAN_PHASE4_SUPERNOVA_CD)
			inst.components.combat:RestartCooldown()
			inst:SwitchToNoFaced()
			if not inst.AnimState:IsCurrentAnimation("atk_burst_shoot_loop") then
				inst.AnimState:PlayAnimation("atk_burst_shoot_loop", true)
				DoSupernovaShake(inst)
				inst.sg.statemem.skipshake = true
			end
			inst.SoundEmitter:KillSound("idleb")
			SetPreventDeath(inst, true)
			inst:AddTag("supernova")
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

			inst.sg.statemem.updatedelay = 0
			if loops then
				inst.sg.statemem.loops = loops
				inst.sg.statemem.skipshake = loops <= 1 or nil
			else
				inst.sg.statemem.loops = 4
				inst.components.combat:SetDefaultDamage(0)
				inst.components.planardamage:SetBaseDamage(TUNING.ALTERGUARDIAN_LUNAR_SUPERNOVA_PLANAR_DAMAGE)
				UpdateSupernovaAOE(inst, 0, true)
				inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.ALTERGUARDIAN_PHASE4_LUNARRIFT_PLANAR_DAMAGE)
			end
			if not inst.sg.statemem.skipshake then
				DoChargingShake(inst)
			end
		end,

		onupdate = UpdateSupernovaAOE,

		timeline =
		{
			FrameEvent(20, function(inst)
				if not inst.sg.statemem.skipshake then
					DoChargingShake(inst)
				end
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/wagstaff_boss/???") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.supernova = true
			inst.sg.statemem.keepnofaced = true
			if inst.sg.statemem.loops > 1 then
				inst.sg.statemem.bursting = true
				inst.sg:GoToState("supernova_burst_loop", inst.sg.statemem.loops - 1)
			else
				inst.components.combat:RestartCooldown()
				inst.sg:GoToState("supernova_burst_pst")
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.supernova then
				SetPreventDeath(inst, false)
			end
			if not inst.sg.statemem.bursting then
				inst:RemoveTag("supernova")
				inst:SetMusicLevel(3, true) --force music to update supernova mix
				inst.SoundEmitter:PlaySound("rifts5/lunar_boss/idle_b_LP", "idleb")
			end
		end,
	},

	State{
		name = "supernova_burst_pst",
		tags = { "attack", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("atk_burst_pst")
			SetPreventDeath(inst, true)
		end,

		timeline =
		{
			FrameEvent(26, function(inst)
				inst.sg:RemoveStateTag("noattack")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				SetPreventDeath(inst, false)
			end),
			FrameEvent(38, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(68, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/wagstaff_boss/???") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg:GoToState("idle_nofaced")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
			SetPreventDeath(inst, false)
		end,
	},

	State{
		name = "death",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()

			if TheWorld.components.wagboss_tracker and TheWorld.components.wagboss_tracker:IsWagbossDefeated() then
				inst.sg.statemem.nowagstaff = true
				inst:SwitchToNoFaced()
			else
				local map = TheWorld.Map
				local x, _, z = inst.Transform:GetWorldPosition()
				if not map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z) then
					inst.sg.statemem.nowagstaff = true
					inst:SwitchToNoFaced()
				else
					local r = 2.5 + inst:GetPhysicsRadius(0)
					local theta = math.random() * TWOPI
					local delta = TWOPI / (math.random() < 0.5 and 8 or -8)
					local pt = Vector3()
					for i = 1, 8 do
						theta = theta + delta
						pt.x = x + r * math.cos(theta)
						pt.z = z - r * math.sin(theta)
						if map:IsPointInWagPunkArena(pt:Get()) then
							break
						end
					end
					inst:SwitchToTwoFaced()
					inst:EnableCameraFocus(true)
					inst:FaceAwayFromPoint(pt, true)
					inst.sg.statemem.wagstaffspawnpt = pt
				end
				inst:SetMusicLevel(2) --silence
			end
			inst.AnimState:PlayAnimation("defeated_pre")
		end,

		timeline =
		{
			FrameEvent(13, DoTauntShake),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/defeated_pre") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.defeated = true
					if inst.sg.statemem.nowagstaff then
						inst.sg.statemem.keepnofaced = true
						inst.sg:GoToState("quickdefeated")
					else
						inst.sg.statemem.keeptwofaced = true
						inst.sg:GoToState("defeated", inst.sg.statemem.wagstaffspawnpt)
					end
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.nowagstaff then
				if not inst.sg.statemem.keepnofaced then
					inst:SwitchToFourFaced()
				end
			else
				if not inst.sg.statemem.keeptwofaced then
					inst:SwitchToFourFaced()
				end
				if not inst.sg.statemem.defeated then
					inst:EnableCameraFocus(false)
				end
			end
			if not inst.sg.statemem.defeated then
				inst:SetMusicLevel(3)
			end
		end,
	},

	State{
		name = "quickdefeated",
		tags = { "dead", "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst:SwitchToNoFaced()
			inst.AnimState:PlayAnimation("defeated_pst")
			inst.AnimState:OverrideSymbol("wb_steam_parts", "wagboss_lunar_blast", "wb_steam_parts")
			inst.AnimState:OverrideSymbol("wb_lunar_blast_base", "wagboss_lunar_blast", "wb_lunar_blast_base")
			inst.AnimState:OverrideSymbol("lunar_ring", "static_ball_contained", "lunar_ring")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/finale2") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keepnofaced = true
					inst.sg.statemem.selfdestruct = true
					inst.sg:GoToState("selfdestruct", false)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.selfdestruct then
				inst.AnimState:ClearOverrideSymbol("wb_steam_parts")
				inst.AnimState:ClearOverrideSymbol("wb_lunar_blast_base")
				inst.AnimState:ClearOverrideSymbol("lunar_ring")
			end
			if not inst.sg.statemem.keepnofaced then
				inst:SwitchToFourFaced()
			end
		end,
	},

	State{
		name = "defeated",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst, wagstaffspawnpt)
			inst.components.locomotor:Stop()
			inst:SwitchToTwoFaced()
			inst:EnableCameraFocus(true)
			inst.AnimState:PlayAnimation("defeated_loop")

			inst:SetMusicLevel(2) --silence

			local function cb(wagstaff)
				if inst.sg.statemem.cb == cb then
					--anim was made facing left so we have to reverse it XD
					inst:FaceAwayFromPoint(wagstaff:GetPosition(), true)
				end
			end
			inst.sg.statemem.cb = cb

			TheWorld:PushEvent("ms_wagstaff_arena_oneshot", {
				strname = "WAGSTAFF_WAGPUNK_ARENA_SCIONDOWN",
				monologue = true,
				focusentity = inst,
				x = wagstaffspawnpt and wagstaffspawnpt.x,
				z = wagstaffspawnpt and wagstaffspawnpt.z,
				cb = cb,
			})
		end,

		timeline =
		{
			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/finale") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.finale = true
					inst.sg:GoToState("finale", inst.sg.statemem.cb)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.keeptwofaced then
				inst:SwitchToFourFaced()
			end
			if not inst.sg.statemem.finale then
				inst:EnableCameraFocus(false)
				inst:SetMusicLevel(3)
			end
		end,
	},

	State{
		name = "finale",
		tags = { "dead", "busy", "nointerrupt", "noattack" },

		onenter = function(inst, cb)
			inst.components.locomotor:Stop()
			inst:SwitchToTwoFaced()
			inst:EnableCameraFocus(true)
			inst.AnimState:PlayAnimation("finale")
			inst.AnimState:PushAnimation("finale2", false)
			inst.AnimState:OverrideSymbol("wb_steam_parts", "wagboss_lunar_blast", "wb_steam_parts")
			inst.AnimState:OverrideSymbol("wb_lunar_blast_base", "wagboss_lunar_blast", "wb_lunar_blast_base")
			inst.AnimState:OverrideSymbol("lunar_ring", "static_ball_contained", "lunar_ring")

			inst.sg.statemem.cb = cb

			inst.sg.statemem.wagstaff = SpawnPrefab("wagstaff_npc_finale_fx")
			inst.sg.statemem.wagstaff:AttachToAlter(inst)

			inst:SetMusicLevel(2) --silence
		end,

		timeline =
		{
			FrameEvent(61, function(inst)
				inst.sg.statemem.wagstaff.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_SCIONATTACKSWAGSTAFF")
				inst.sg.statemem.wagstaff.components.npc_talker:donextline()
				inst.sg.statemem.wagstaff:DoTalkSound(1)
			end),
			FrameEvent(135, function(inst)
				inst.sg.statemem.wagstaff.components.npc_talker:donextline()
				inst.sg.statemem.wagstaff:DoTalkSound(2)
			end),
			FrameEvent(224, function(inst)
				inst.sg.statemem.wagstaff:Materialize()
			end),
			FrameEvent(244, function(inst)
				inst.sg.statemem.wagstaff.components.npc_talker:donextline()
				inst.sg.statemem.wagstaff:DoTalkSound(1.5)
			end),
			FrameEvent(325, function(inst)
				inst.sg.statemem.wagstaff.components.npc_talker:donextline()
				inst.sg.statemem.wagstaff:DoTalkSound(1.5)
			end),
			FrameEvent(366, function(inst)
				inst.sg.statemem.wagstaff:Brighten()
				DoChargingShake(inst)
			end),
			FrameEvent(392, DoChargingShake),
			FrameEvent(428, DoChargingShake),

			--#SFX
			FrameEvent(50, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/finale") end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keeptwofaced = true
					inst.sg.statemem.selfdestruct = true
					inst.sg:GoToState("selfdestruct", inst.sg.statemem.wagstaff)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.selfdestruct then
				inst.sg.statemem.wagstaff:Remove()
				inst:RemoveTag("NOCLICK")
				inst.AnimState:ClearOverrideSymbol("wb_steam_parts")
				inst.AnimState:ClearOverrideSymbol("wb_lunar_blast_base")
				inst.AnimState:ClearOverrideSymbol("lunar_ring")
				inst:SetMusicLevel(3)
				inst:EnableCameraFocus(false)
			end
			if not inst.sg.statemem.keeptwofaced then
				inst:SwitchToFourFaced()
			end
		end,
	},

	State{
		name = "selfdestruct",
		tags = { "dead", "busy", "nointerrupt", "noattack" },

		onenter = function(inst, wagstaff)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("finale_pst")
			inst.AnimState:OverrideSymbol("fx_bits", "wagboss_robot", "fx_bits")

			if wagstaff then
				inst.sg.statemem.wagstaff = wagstaff
				inst:SwitchToTwoFaced()
				inst:EnableCameraFocus(true)
			else
				if wagstaff == nil then --false if it came from "quickdefeated"
					inst.AnimState:OverrideSymbol("wb_steam_parts", "wagboss_lunar_blast", "wb_steam_parts")
					inst.AnimState:OverrideSymbol("wb_lunar_blast_base", "wagboss_lunar_blast", "wb_lunar_blast_base")
					inst.AnimState:OverrideSymbol("lunar_ring", "static_ball_contained", "lunar_ring")
				end
				inst:SwitchToNoFaced()
			end

			inst:SetMusicLevel(2) --silence
		end,

		timeline =
		{
			FrameEvent(16, function(inst)
				inst:AddTag("NOCLICK")
			end),
			FrameEvent(18, DoSelfDestructShake),
			FrameEvent(23, function(inst)
				local pt = inst:GetPosition()
				inst.components.lootdropper:DropLoot(pt)
				inst.persists = false
				inst:StopDomainExpansion()
				if TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(pt:Get()) then
					TheWorld:PushEvent("ms_wagboss_alter_defeated", inst)
				end
				if inst.sg.statemem.wagstaff then
					TheWorld:PushEvent("wagboss_defeated")
				end
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/finale") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
			end),
		},

		onexit = function(inst)
			--should not reach here
			if inst.sg.statemem.wagstaff then
				inst.sg.statemem.wagstaff:Remove()
				inst:EnableCameraFocus(false)
			end
			inst:RemoveTag("NOCLICK")
			inst.AnimState:ClearOverrideSymbol("fx_bits")
			inst.AnimState:ClearOverrideSymbol("wb_steam_parts")
			inst.AnimState:ClearOverrideSymbol("wb_lunar_blast_base")
			inst.AnimState:ClearOverrideSymbol("lunar_ring")
			inst:SwitchToFourFaced()
			inst:SetMusicLevel(3)
		end,
	},
}

CommonStates.AddWalkStates(states,
{
	starttimeline = --walk_pre
	{
		--#SFX
		--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/???") end),
	},
	walktimeline = --walk_loop
	{
		--#SFX
		FrameEvent(28, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/footstep") end),
		FrameEvent(55, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
		FrameEvent(79, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/footstep") end),
	},
	endtimeline = --walk_pst
	{
		--#SFX
		--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/???") end),
	},
})

return StateGraph("alterguardian_phase4_lunarrift", states, events, "idle")
