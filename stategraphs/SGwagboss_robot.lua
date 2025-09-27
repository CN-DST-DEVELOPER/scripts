require("stategraphs/commonstates")

local MISSILE_TARGET_RANGE = 18
local MISSILE_LOCAL_TARGET_RANGE = 8
local NUM_MISSILES = 3
local REGISTERED_HEAT_TAGS
local HEATER_TEMPERATURE_SCORE_OFFSET = 1000

local function _CollectMissileTargetEntities(x, z, r, tbl)
	local ents = TheSim:FindEntities_Registered(x, 0, z, r, REGISTERED_HEAT_TAGS)
	if tbl then
		for i = 1, #ents do
			tbl[ents[i]] = true
		end
		return tbl
	end
	for i = 1, #ents do
		ents[ents[i]] = true
		ents[i] = nil
	end
	return ents
end

local function _DistSqToNearestMissile(ent, _missiles)
	local x, _, z = ent.Transform:GetWorldPosition()
	local dsq = math.huge
	for k in pairs(_missiles) do
		dsq = math.min(dsq, distsq(x, z, k.targetpos.x, k.targetpos.z))
	end
	return dsq
end

--Returns true if any targets are found
--Pass optional maxtargets(int) and targets(table) to get the actual list of targets
local function _FindMissileTargets(inst, maxtargets, targets, _missiles)
	if REGISTERED_HEAT_TAGS == nil then
		REGISTERED_HEAT_TAGS = TheSim:RegisterFindTags(
			nil,
			{ "INLIMBO", "FX", "flight", "invisible", "notarget", "noattack", "brightmare", "brightmareboss", "ghost", "playerghost", "shadow", "shadowcreature", "shadowminion", "shadowchesspiece" },
			{ "fire", "smolder", "HASHEATER", "engineeringbattery", "spotlight", "_combat" }
		)
	end

	local x, _, z = inst.Transform:GetWorldPosition()
	local ents = _CollectMissileTargetEntities(x, z, MISSILE_TARGET_RANGE)
	if _missiles then
		assert(next(targets) == nil)
		for k in pairs(_missiles) do
			local posid = string.format("%d,%d", k.targetpos.x + 0.5, k.targetpos.z + 0.5)
			if targets[posid] == nil then
				targets[posid] = true
				_CollectMissileTargetEntities(k.targetpos.x, k.targetpos.z, MISSILE_LOCAL_TARGET_RANGE, ents)
			end
		end
		for k in pairs(targets) do
			targets[k] = nil
		end
	end

	local map = TheWorld.Map
	local inarena = map:IsPointInWagPunkArena(x, 0, z)
	for v in pairs(ents) do
		if v ~= inst and
			not inst.components.commander:IsSoldier(v) and
			not (v.components.freezable and v.components.freezable:IsFrozen()) and
			(not inarena or map:IsPointInWagPunkArena(v.Transform:GetWorldPosition()))
		then
			local ambient_temp = GetLocalTemperature(v)
			local temperature = ambient_temp
			local endo

			-- ._lightinst ==> winona_spotlight
			-- .currentTempRange ==> heatrock
			local heater = v._lightinst and v._lightinst.components.heater or v.components.heater
			if heater then
				--NOTE: GetHeat() can be nil!
				--V2C: GetHeat first. Some heaters update thermics in their heatfn.
				local heat = heater:GetHeat(v)
				if heat == nil then
					heater = nil
				elseif heater:IsExothermic() then
					temperature = HEATER_TEMPERATURE_SCORE_OFFSET + heat
				elseif heater:IsEndothermic() then
					endo = true
					temperature = math.min(temperature, heat)
				else
					--thermics not setup; heater is not active
					heater = nil
				end
			end

			if heater == nil then
				if v.components.temperature then
					temperature = v.components.temperature:GetCurrent()
				elseif v.components.fueled and not v.components.fueled:IsEmpty() and v:HasTag("engineeringbattery") then
					temperature = temperature + 10
				elseif v.components.burnable and v.components.burnable:IsSmoldering() then
					--only add smoldering bonus if we don't have an actual temperature
					temperature = temperature + 5
				end
			end

			if v.components.burnable and v.components.burnable:IsBurning() then
				local fire = v.components.burnable.fxchildren[1]
				if fire and fire.components.heater then
					--NOTE: GetHeat() can be nil!
					--V2C: GetHeat first. Some heaters update thermics in their heatfn.
					local heat = fire.components.heater:GetHeat(v)
					if heat then
						if fire.components.heater:IsExothermic() then
							temperature = math.max(temperature, HEATER_TEMPERATURE_SCORE_OFFSET + heat)
						elseif fire.components.heater:IsEndothermic() then
							endo = true
							temperature = math.min(temperature, heat)
						else
							--thermics not setup
							print("Fire missing heat signature on", v)
						end
					end
				else
					print("Fire missing heat signature on", v)
				end
			end

			if endo or temperature <= 0 then
				--skip heaters completely if marked as endothermic
				--skip if freezing temperature
			elseif temperature > ambient_temp or
				(	v.components.combat and
					not (v.components.health and v.components.health:IsDead()) and
					v:HasAnyTag("animal", "largecreature", "monster", "character") and
					not v:HasAnyTag("critter", "smallcreature", "veggie", "fish", "deadcreature") and
					(	v.components.combat:IsRecentTarget(inst) or
						not v:HasTag("companion")
					)
				)
			then
				if targets == nil then
					return true --just want to know if we have any target at all
				end
				local found
				for i1, v1 in ipairs(targets) do
					if temperature >= v1.temp then
						local dsq = _missiles and _DistSqToNearestMissile(v, _missiles)
						if temperature > v1.temp or (temperature == v1.temp and dsq and dsq < v1.dsq) then
							table.insert(targets, i1, { ent = v, temp = temperature, dsq = dsq })
							targets[maxtargets + 1] = nil
							found = true
							break
						end
					end
				end
				if not found and #targets < maxtargets then
					table.insert(targets, { ent = v, temp = temperature, dsq = _missiles and _DistSqToNearestMissile(v, _missiles) })
				end
			end
		end
	end
	if targets == nil then
		return false
	end
	for i = 1, #targets do
		targets[i] = targets[i].ent
	end
	return #targets > 0
end

local CollectMissileTargets = _FindMissileTargets
--local HasAnyMissileTarget = _FindMissileTargets --HasAnyMissileTarget(inst), no extra params

local function TryRetargetMissiles(inst, data)
	if inst.components.combat == nil or (inst.components.health and inst.components.health:IsDead()) then
		--no longer in combat
		for i, v in ipairs(data.missiles) do
			if v:IsValid() then
				v:CancelTargetLock()
			end
		end
		data.task:Cancel()
		return
	end

	assert(next(inst._temptbl1) == nil)
	local toretarget = inst._temptbl1
	local maxnum = 0
	for i, v in ipairs(data.missiles) do
		if v:IsValid() then
			toretarget[v] = true
			maxnum = maxnum + 1
		end
	end

	if maxnum <= 0 then
		data.task:Cancel()
		--assert(next(toretarget) == nil)
		return
	end

	assert(next(inst._temptbl2) == nil)
	local targets = inst._temptbl2
	if not _FindMissileTargets(inst, maxnum, targets, toretarget) then
		for k in pairs(toretarget) do
			toretarget[k] = nil
		end
		--assert(next(targets) == nil and next(toretarget) == nil)
		return
	end
	local num = #targets

	inst.sg:RemoveStateTag("missiles_target_fail")

	--After one missile detonates, don't retarget the remaining missiles
	--if it would just end up redistributing to the same set of targets.
	if next(data.grouptargets) then
		for i, v in ipairs(targets) do
			if data.grouptargets[v] then
				for k in pairs(toretarget) do
					if k.target and table.contains(targets, k.target) then
						toretarget[k] = nil
						if maxnum == 1 then
							for k in pairs(targets) do
								targets[k] = nil
							end
							--assert(next(toretarget) == nil and next(targets) == nil)
							return
						end
						maxnum = maxnum - 1
					end
				end
				break
			end
		end
	end

	for i = num + 1, maxnum do
		targets[i] = targets[((i - 1) % num) + 1]
	end

	for k in pairs(toretarget) do
		if k.target then
			for i, v in ipairs(targets) do
				if k.target == v then
					--matched; no need to retarget
					table.remove(targets, i)
					toretarget[k] = nil
					if #targets == 0 then
						--assert(next(toretarget) == nil and next(targets) == nil)
						return
					end
					break
				end
			end
		end
	end

	for k in pairs(toretarget) do
		local mindsq = math.huge
		local minidx
		local x, y, z = k.Transform:GetWorldPosition()
		for i, v in ipairs(targets) do
			local dsq = v:GetDistanceSqToPoint(x, y, z)
			if dsq < mindsq then
				mindsq = dsq
				minidx = i
			end
		end
		k:Retarget(table.remove(targets, minidx))
		toretarget[k] = nil
	end
	for k in pairs(targets) do
		targets[k] = nil
	end
	--assert(next(toretarget) == nil and next(targets) == nil)
end

--------------------------------------------------------------------------

local ORBITAL_STRIKE_TARGET_RANGE_SQ = 18 * 18 --only used when not in arena

local function GenerateSelections(targets, numtoselect, _out, _seq, _i0, _n)
	_out = _out or {}
	_n = _n or 1
	for i = _i0 or 1, #targets - numtoselect + _n do
		local seq1 = _seq and shallowcopy(_seq) or {}
		table.insert(seq1, targets[i])
		if _n < numtoselect then
			GenerateSelections(targets, numtoselect, _out, seq1, i + 1, _n + 1)
		else
			table.insert(_out, seq1)
		end
	end
	return _out
end

--Returns true if any targets are found
--Pass optional targets(table) to get the actual list of targets
local function _FindOrbitalStrikeTargets(inst, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	local inarena = map:IsPointInWagPunkArena(x, 0, z)
	for k in pairs(inst.components.grouptargeter:GetTargets()) do
		local x1, y1, z1 = k.Transform:GetWorldPosition()
		if (inarena and map:IsPointInWagPunkArena(x1, y1, z1)) or
			(not inarena and distsq(x, z, x1, z1) < ORBITAL_STRIKE_TARGET_RANGE_SQ)
		then
			if targets == nil then
				return true --just want to know if we have any target at all
			end
			table.insert(targets, k)
		end
	end
	if targets == nil or #targets <= 0 then
		local target = inst.components.combat.target
		if target and not (target.components.health and target.components.health:IsDead()) then
			local x1, y1, z1 = target.Transform:GetWorldPosition()
			if (inarena and map:IsPointInWagPunkArena(x1, y1, z)) or
				(not inarena and distsq(x, z, x1, z1) < ORBITAL_STRIKE_TARGET_RANGE_SQ)
			then
				if targets == nil then
					return true --just want to know if we have any target at all
				end
				table.insert(targets, target)
			end
		end
		if targets == nil or #targets <= 0 then
			return false
		end
	end
	local maxtargets = math.min(6, math.floor(#targets / 2) + 1)
	if maxtargets == 1 then
		targets[1] = targets[math.random(maxtargets)]
		for i = 2, #targets do
			targets[i] = nil
		end
	elseif #targets > maxtargets then
		assert(next(inst._temptbl2) == nil)
		local dists = inst._temptbl2
		local selections = GenerateSelections(targets, maxtargets)

		--cache the distances between each pair of targets
		for i1 = 1, #targets - 1 do
			local v1 = targets[i1]
			local x1, y1, z1 = v1.Transform:GetWorldPosition()
			for i2 = i1 + 1, #targets do
				local v2 = targets[i2]
				local id = tostring(math.min(v1.GUID, v2.GUID)).."."..tostring(math.max(v1.GUID, v2.GUID))
				dists[id] = v2:GetDistanceSqToPoint(x1, y1, z1)
			end
		end

		local bestseq = selections[1]
		for i, seq in ipairs(selections) do
			--sort the distances between pairs of targets within each selection
			seq.dists = {}
			for i1 = 1, #seq - 1 do
				local v1 = seq[i1]
				for i2 = i1 + 1, #seq do
					local v2 = seq[i2]
					local id = tostring(math.min(v1.GUID, v2.GUID)).."."..tostring(math.max(v1.GUID, v2.GUID))
					table.insert(seq.dists, dists[id])
				end
			end
			table.sort(seq.dists)

			--then pick the sequence whose smallest gaps are the biggest
			if i > 1 then
				for j = 1, #seq.dists do
					if seq.dists[j] > bestseq.dists[j] then
						bestseq = seq
						break
					end
				end
			end
		end

		for i, v in ipairs(bestseq) do
			targets[i] = v
		end
		for i = maxtargets + 1, #targets do
			targets[i] = nil
		end
		for k in pairs(dists) do
			dists[k] = nil
		end
		--assert(next(dists) == nil)
	end
	return true
end

local function HasAnyOrbitalStrikeTarget(inst)
	return _FindOrbitalStrikeTargets(inst)
end

local function TryOrbitalStrike(inst)
	assert(next(inst._temptbl1) == nil)
	local targets = inst._temptbl1
	if not _FindOrbitalStrikeTargets(inst, targets) then
		assert(next(targets) == nil)
		return false
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	for i = 1, #targets do
		SpawnPrefab("wagboss_beam_fx"):TrackTarget(targets[i], x, z)
		targets[i] = nil
	end
	--assert(next(targets) == nil)
	return true
end

--------------------------------------------------------------------------

local function ChooseAttack(inst, target)
	if (	inst.canhackdrones and
			not inst.components.timer:TimerExists("hackdrones_cd") and
			inst.components.commander:GetNumSoldiers() <= 0
		) or
		(	inst.canorbitalstrike and
			not inst.components.timer:TimerExists("orbitalstrike_cd") and
			HasAnyOrbitalStrikeTarget(inst)
		)
	then
		inst.sg:GoToState("signal_pre")
		return true
	elseif inst.canmissiles and
		(inst.canmissilebarrage or not inst.components.timer:TimerExists("missiles_cd"))
		--and HasAnyMissileTarget(inst)
	then
		inst.sg:GoToState("missiles_pre")
		return true
	end

	target = target or inst.components.combat.target
	if target and not target:IsValid() then
		target = nil
	end

	local inrange = target ~= nil and inst:IsNear(target, TUNING.WAGBOSS_ROBOT_ATTACK_RANGE + target:GetPhysicsRadius(0))

	if inst.canleap and not inrange and not inst.components.timer:TimerExists("leap_cd") then
		inst.sg:GoToState("leap_pre", target)
		return true
	elseif inst.cantantrum and not inst.components.timer:TimerExists("tantrum_cd") and math.random() < 0.5 then
		inst.sg:GoToState("tantrum_pre")
		return true
	elseif inst.canleap and not inst.components.timer:TimerExists("leap_cd") then
		inst.sg:GoToState("leap_pre", target)
		return true
	elseif inrange then
		inst.sg:GoToState("stomp")
		return true
	elseif inst.canleap then
		inst.sg:GoToState("leap_pre", target)
		return true
	end
	return false
end

local events =
{
	EventHandler("locomote", function(inst, data)
		if inst.components.locomotor then
			if inst.components.locomotor:WantsToMoveForward() then
				if inst.sg:HasStateTag("idle") then
					inst.sg:GoToState("walk_start")
				end
			elseif inst.sg:HasStateTag("moving") then
				inst.sg:GoToState("walk_stop")
			end
		end
	end),
	CommonHandlers.OnAttacked(nil, math.huge), --hit delay only for projectiles
	EventHandler("doattack", function(inst, data)
		if not inst.sg:HasStateTag("busy") then
			ChooseAttack(inst, data and data.target or nil)
		end
	end),
	EventHandler("activate", function(inst)
		inst.sg.mem.toturnoff = nil
		if inst.sg:HasStateTag("off") then
			if not inst.sg:HasStateTag("nointerrupt") then
				inst.sg.statemem.activating = true
				inst.sg:GoToState("activate")
			else
				inst.sg.mem.toturnon = true
			end
		end
	end),
	EventHandler("losecontrol", function(inst)
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("losecontrol")
		else
			inst.sg.mem.losecontrol = true
		end
	end),
	EventHandler("deactivate", function(inst)
		inst.sg.mem.toturnon = nil
		if not inst.sg:HasAnyStateTag("off", "dead") then
			if not inst.sg:HasStateTag("nointerrupt") then
				inst.sg:GoToState("turnoff")
			else
				inst.sg.mem.toturnoff = true
			end
		end
	end),
	EventHandler("death", function(inst)
		inst.sg.mem.toturnon = nil
		inst.sg.mem.toturnoff = nil
		if not inst.sg:HasAnyStateTag("dead", "nointerrupt") then
			inst.sg:GoToState("death")
		end
	end),
}

--------------------------------------------------------------------------

local function DoStompShake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.7, 0.025, 1, inst, 40)
end

local function DoFootstepHeavyShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 0.35, 0.02, 0.5, inst, 40)
end

local function DoFootstepMedShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 0.35, 0.02, 0.3, inst, 40)
end

local function DoJumpShake(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 1, 0.035, 0.15, inst, 40)
end

local function GetUpShake1(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 0.85, 0.03, 0.08, inst, 40)
end

local function GetUpShake2(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 0.75, 0.03, 0.1, inst, 40)
end

local function GetUpShakeLong(inst)
	ShakeAllCameras(CAMERASHAKE.FULL, 2, 0.03, 0.15, inst, 40)
end

--------------------------------------------------------------------------

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "brightmare" }

local function _AOEAttack(inst, radius, heavymult, mult, forcelanded, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and targets[v] == nil and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, y, z) < range * range then
				if v:HasTag("wagdrone_rolling") then
					if v.sg and v.sg:HasStateTag("running") then
						v.sg:HandleEvent("forced_spinning_recoil", { target = inst, radius = 2 })
						targets[v] = true
					end
				elseif not inst.components.commander:IsSoldier(v) and inst.components.combat:CanTarget(v) then
					inst.components.combat:DoAttack(v)
					if mult then
						local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
						v:PushEvent("knockback", { knocker = inst, radius = radius, strengthmult = strengthmult, forcelanded = forcelanded })
					end
					targets[v] = true
				end
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
		if targets[v] == nil and
			v:IsValid() and not v:IsInLimbo() and
			v.components.workable and
			not inst.components.commander:IsSoldier(v)
		then
			local work_action = v.components.workable:GetWorkAction()
			--V2C: nil action for NPC_workable (e.g. campfires)
			--     no digging, so don't need to check for spawners (e.g. rabbithole)
			if (work_action == nil and v:HasTag("NPC_workable")) or
				(v.components.workable:CanBeWorked() and work_action and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
			then
				v.components.workable:Destroy(inst)
				targets[v] = true
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

local function _TossItems(inst, radius)
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + WORK_RADIUS_PADDING, TOSSITEM_MUST_TAGS, TOSSITEM_CANT_TAGS)) do
		if v.components.mine then
			v.components.mine:Deactivate()
		end
		if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
			_TossLaunch(v, x, z, 1.2, 0.1)
		end
	end
end

local function DoStompAOE(inst, targets)
	_AOEWork(inst, 3.3, targets)
	_AOEAttack(inst, 3.3, 1, 1, false, targets)
	_TossItems(inst, 3.3)
end

local function DoKickAOE(inst, targets)
	_AOEAttack(inst, 3.3, 1, 1, true, targets)
end

local function SetShadowScale(inst, scale)
	inst.DynamicShadow:SetSize(4.8 * scale, 2.8 * scale)
end

--------------------------------------------------------------------------

local function OnUpdateLeap(inst, dt)
	if inst.sg.statemem.stopped then
		--do nothing
		return
	end

	local speed = inst.Physics:GetMotorVel()
	if inst.sg.statemem.landed then
		inst.Physics:SetMotorVelOverride(speed * 0.5, 0, 0)
	else
		local pt = inst.sg.statemem.targetpos
		if pt then
			local target = inst.sg.statemem.target
			if target then
				if target:IsValid() then
					pt.x, pt.y, pt.z = target.Transform:GetWorldPosition()
					local rot1 = inst.Transform:GetRotation()
					local rot2 = inst:GetAngleToPoint(pt)
					local diff = ReduceAngle(rot2 - rot1)
					local absdiff = math.abs(diff)
					local k = absdiff > 45 and 1 - (absdiff - 45) / 135 or 1
					speed = speed * (0.85 + 0.15 * k * k)
					rot2 = rot1 + diff * 0.15
					inst.Transform:SetRotation(rot2)
				else
					inst.sg.statemem.target = nil
				end
			end

			local t = inst.sg.statemem.t
			if t and dt > 0 then
				local dist = math.sqrt(inst:GetDistanceSqToPoint(pt))
				speed = t > 0 and math.min(speed + 0.15, 16) or 16
				speed = math.min(speed, dist / (math.sqrt(t + 6) * FRAMES))
				inst.Physics:SetMotorVelOverride(speed, 0, 0)
				inst.sg.statemem.t = t + 1
			end
		else
			inst.Physics:SetMotorVelOverride(speed * 0.5, 0, 0)
		end
	end
end

--------------------------------------------------------------------------

local states =
{
	State{
		name = "idle",
		tags = { "idle", "canrotate" },

		onenter = function(inst)
			if inst.hostile and inst.components.health:IsDead() then
				inst.sg:GoToState("death")
				return
			elseif inst.sg.mem.toturnoff then
				inst.sg:GoToState("turnoff")
				return
			elseif inst.sg.mem.losecontrol then
				inst.sg:GoToState("losecontrol")
				return
			end
			inst.components.locomotor:StopMoving()
			if not inst.AnimState:IsCurrentAnimation("idle") then
				inst.AnimState:PlayAnimation("idle", true)
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			--#SFX
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pre_13tohit", nil, 0.4) end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.2) end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.2) end),
			FrameEvent(35, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst", nil, 0.4) end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,
	},

	State{
		name = "off",
		tags = { "off", "busy", "noattack" },

		onenter = function(inst, cleararea)
			inst.sg.mem.toturnoff = nil
			if inst.sg.mem.toturnon then
				inst.sg.statemem.activating = true
				inst.sg:GoToState("activate")
				return
			end
			inst:ConfigureOff()
			inst:MakeObstacle(true)
			inst:SetMusicLevel(0)
			if cleararea then
				local x, y, z = inst.Transform:GetWorldPosition()
                ClearSpotForRequiredPrefabAtXZ(x, z, inst.physicsradiusoverride)
			end
            local iswagbossdefeated = TheWorld.components.wagboss_tracker and TheWorld.components.wagboss_tracker:IsWagbossDefeated()
			if inst.socketed or iswagbossdefeated then
				inst.AnimState:PlayAnimation("idle_off")
                if iswagbossdefeated and not inst.socketed then
                    inst:AddTrader()
                end
			else
				inst.AnimState:PlayAnimation("concealed_idle", true)
			end
			inst.SoundEmitter:KillSound("loop")
			inst.sg.statemem.fixphysics = inst.sg.mem.physicstask ~= nil or nil
			if cleararea then
				TheWorld:PushEvent("ms_wagboss_robot_turnoff")
			end
		end,

		events =
		{
			EventHandler("reveal", function(inst)
				if inst.AnimState:IsCurrentAnimation("concealed_idle") then
					if POPULATING then
						inst.AnimState:PlayAnimation("idle_off")
					else
						inst.AnimState:PlayAnimation("revealed")
						inst.AnimState:PushAnimation("idle_off", false)
						inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/revealed")
					end
				end
			end),
			EventHandler("entitywake", function(inst)
				if inst.sg.statemem.fixphysics and inst.sg.mem.physicstask == nil then
					inst.sg.statemem.fixphysics = nil
					--Very minor thing, but ToggleOnCharacterCollisions uses height of 1
					inst.Physics:SetCapsule(inst.physicsradiusoverride, 2)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.activating then
				inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/active_lp", "loop")
				inst:ConfigureHostile()
			end
			inst:MakeObstacle(false)
			inst:SocketCage()
            inst:RemoveTrader()
		end,
	},

	State{
		name = "activate",
		tags = { "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.sg.mem.toturnon = nil
			if inst.shattered then
				inst:ConfigureHostile()
			else
				inst:ConfigureFriendly()
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("activate1")
			inst.SoundEmitter:KillSound("loop")
			if not inst.hostile then
				inst.AnimState:Hide("fx_activation")
			elseif TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition()) then
				TheWorld:PushEvent("ms_wagboss_robot_losecontrol")
			end
			if POPULATING then
				inst.sg:GoToState("idle")
			end
		end,

		timeline =
		{
			FrameEvent(43, GetUpShake1),
			FrameEvent(92, GetUpShake2),
			FrameEvent(135, GetUpShakeLong),
			FrameEvent(174, function(inst)
				if inst.hostile then
					if inst.components.health:IsDead() then
						inst.sg:GoToState("death")
						return
					elseif inst.sg.mem.turnoff then
						inst.sg.statemem.off = true
						inst.sg:GoToState("turnoff")
						return
					end
					inst.sg:RemoveStateTag("noattack")
					inst.sg:RemoveStateTag("nointerrupt")
					inst.sg:AddStateTag("caninterrupt")
					inst:SetMusicLevel(1)
				end
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/antennae_raise") end),
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(9, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(14, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(28, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(32, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(84, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(108, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(114, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(120, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/activate_light_on") end),
			FrameEvent(130, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long") end),
			FrameEvent(128, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),

			--restore idle loop
			FrameEvent(150, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/active_lp", "loop") end),
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
			inst.AnimState:Show("fx_activation")
			if not inst.SoundEmitter:PlayingSound("loop") then
				inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/active_lp", "loop")
			end
			if inst.hostile and not (inst.sg.statemem.off or inst.components.health:IsDead()) then
				inst:SetMusicLevel(1)
			end
		end,
	},

	State{
		name = "losecontrol",
		tags = { "busy", "nointerrupt", "noattack" },

		onenter = function(inst)
			inst.sg.mem.losecontrol = nil
			inst:ConfigureFriendly()
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("activate2")
			if TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(inst.Transform:GetWorldPosition()) then
				TheWorld:PushEvent("ms_wagboss_robot_losecontrol")
				if not (TheWorld.components.wagboss_tracker and TheWorld.components.wagboss_tracker:IsWagbossDefeated()) then
					inst:EnableCameraFocus(true)
				end
			end
		end,

		timeline =
		{
			FrameEvent(0, GetUpShake2),
			FrameEvent(23, GetUpShake2),
			FrameEvent(43, GetUpShake1),
			FrameEvent(45, function(inst)
				inst:BreakGlass()
			end),
			FrameEvent(74, GetUpShakeLong),
			FrameEvent(78, function(inst)
				inst:ConfigureHostile()
			end),
			FrameEvent(96, function(inst)
				if inst.components.health:IsDead() then
					inst.sg:GoToState("death")
					return
				elseif inst.sg.mem.turnoff then
					inst.sg.statemem.off = true
					inst.sg:GoToState("turnoff")
					return
				end
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
				inst:SetMusicLevel(1)
			end),

			--#SFX
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_losecontrol_1") end),
			FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_losecontrol_2") end),
			FrameEvent(42, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(46, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/glass_break") end),
			FrameEvent(75, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_losecontrol_3") end),
			FrameEvent(75, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst_front") end),
			FrameEvent(75, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(76, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long") end),
			FrameEvent(79, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/gestalt_crown_appear") end),
			FrameEvent(80, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),

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
			if not inst.sg.statemem.off then
				inst:ConfigureHostile()
			end
			if inst.hostile and not (inst.sg.statemem.off or inst.components.health:IsDead()) then
				inst:SetMusicLevel(1)
			end
			inst:EnableCameraFocus(false)
		end,
	},

	State{
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("taunt")
			DoJumpShake(inst)
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				local cd = inst.components.timer:GetTimeLeft("tantrum_cd")
				local newcd = TUNING.WAGBOSS_ROBOT_TANTRUM_CD / 2
				if cd == nil then
					inst.components.timer:StartTimer("tantrum_cd", newcd)
				elseif cd < newcd then
					inst.components.timer:SetTimeLeft("tantrum_cd", newcd)
				end
				inst.sg:AddStateTag("nointerrupt")
				inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_KICK_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_KICK_PLANAR_DAMAGE)
				inst.sg.statemem.targets = {}
				DoKickAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(14, function(inst)
				DoKickAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(15, function(inst)
				DoKickAOE(inst, inst.sg.statemem.targets)
				inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_PLANAR_DAMAGE)
			end),
			FrameEvent(24, DoFootstepMedShake),
			FrameEvent(25, function(inst)
				if inst.components.health:IsDead() then
					inst.sg:GoToState("death")
					return
				elseif inst.sg.mem.toturnoff then
					inst.sg:GoToState("turnoff")
					return
				end
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(30, DoFootstepHeavyShake),
			FrameEvent(34, DoFootstepHeavyShake),
			FrameEvent(58, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(20, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_stomp") end),
			FrameEvent(26, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_taunt") end),
			FrameEvent(58, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(58, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
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
			inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_DAMAGE)
			inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_PLANAR_DAMAGE)
		end,
	},

	State{
		name = "tantrum_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("taunt2_pre")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst_front") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst_front") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_taunt_tantrum_1") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("tantrum_loop", math.random(2, 3))
				end
			end),
		},
	},

	State{
		name = "tantrum_loop",
		tags = { "busy" },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("taunt2_loop")
			inst.sg.statemem.loops = loops or 1
		end,

		timeline =
		{
			FrameEvent(2, DoJumpShake),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.components.timer:StopTimer("tantrum_cd")
				inst.components.timer:StartTimer("tantrum_cd", TUNING.WAGBOSS_ROBOT_TANTRUM_CD)
			end),
			FrameEvent(22, DoFootstepMedShake),
			FrameEvent(23, function(inst)
				if inst.components.health:IsDead() then
					inst.sg:GoToState("death")
					return
				elseif inst.sg.mem.toturnoff then
					inst.sg:GoToState("turnoff")
					return
				end
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(24, function(inst)
				inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_KICK_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_KICK_PLANAR_DAMAGE)
				inst.sg.statemem.targets = {}
				DoKickAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(25, function(inst)
				if inst.sg.statemem.loops > 1 then
					DoFootstepHeavyShake(inst)
				else
					DoStompShake(inst)
				end
				DoKickAOE(inst, inst.sg.statemem.targets)
				inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_DAMAGE)
				inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_PLANAR_DAMAGE)
			end),
			FrameEvent(28, function(inst)
				if inst.sg.statemem.loops > 1 then
					DoFootstepHeavyShake(inst)
				end
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(8, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(9, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_taunt_tantrum_2") end),
			FrameEvent(12, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_taunt_tantrum_2") end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_front") end),
			FrameEvent(26, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_front") end),
			FrameEvent(29, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_front") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.sg.statemem.loops > 1 then
						inst.sg:GoToState("tantrum_loop", inst.sg.statemem.loops - 1)
					else
						inst.sg:GoToState("tantrum_pst")
					end
				end
			end),
		},

		onexit = function(inst)
			inst.components.combat:SetDefaultDamage(TUNING.WAGBOSS_ROBOT_DAMAGE)
			inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_ROBOT_PLANAR_DAMAGE)
		end,
	},

	State{
		name = "tantrum_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("taunt2_pst")
		end,

		timeline =
		{
			FrameEvent(40, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(21, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
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
			local t = GetTime()
			if t > (inst.sg.mem.hitflicker or 0) then
				inst.sg.mem.hitflicker = t + math.random() * 3
				inst.sg.statemem.flicker = true
				inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 0.5)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				if inst.sg.statemem.flicker then
					inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 1)
				end
			end),
			FrameEvent(4, function(inst)
				if inst.sg.statemem.flicker then
					inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 0.5)
				end
			end),
			FrameEvent(5, function(inst)
				if inst.sg.statemem.flicker then
					inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 1)
				end
			end),
			FrameEvent(8, function(inst)
				if inst.sg.statemem.flicker then
					inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 0.5)
				end
			end),
			FrameEvent(10, function(inst)
				if inst.sg.statemem.flicker then
					inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 1)
					inst.sg.statemem.flicker = false
				end
			end),
			FrameEvent(11, function(inst)
				if inst.sg.statemem.doattack == nil then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(19, function(inst)
				if inst.sg.statemem.doattack and ChooseAttack(inst, inst.sg.statemem.doattack) then
					return
				end
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
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
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.flicker then
				inst.AnimState:SetSymbolMultColour("fx_white", 1, 1, 1, 1)
			end
		end,
	},

	State{
		name = "stomp",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_squish")
			if inst.sg.lasttags and inst.sg.lasttags["moving"] then
				DoFootstepMedShake(inst)
			end
			inst.components.combat:StartAttack()
		end,

		timeline =
		{
			FrameEvent(27, function(inst)
				inst.sg.statemem.shakeonexit = true
				inst:StartStompFx()
				inst.components.combat:RestartCooldown()
				inst.sg.statemem.targets = {}
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(27 + 12, function(inst)
				inst:StopStompFx()
			end),
			FrameEvent(28, function(inst)
				inst.sg.statemem.shakeonexit = nil
				DoStompShake(inst)
			end),
			FrameEvent(29, function(inst)
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(30, function(inst)
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(55, GetUpShake1),
			FrameEvent(75, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_taunt_2") end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_stomp") end),
			FrameEvent(56, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
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
			if inst.sg.statemem.shakeonexit then
				DoStompShake(inst)
			end
			inst:StopStompFx(true)
		end,
	},

	State{
		name = "leap_pre",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_leap_pre")
			if inst.sg.lasttags and inst.sg.lasttags["moving"] then
				DoFootstepMedShake(inst)
			end
			inst.components.combat:StartAttack()
			if target and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.targetpos = target:GetPosition()
				inst:ForceFacePoint(inst.sg.statemem.targetpos)
			end
		end,

		onupdate = OnUpdateLeap,

		timeline =
		{
			FrameEvent(7, GetUpShake1),
			FrameEvent(18, GetUpShake1),
			FrameEvent(40, DoJumpShake),
			FrameEvent(41, function(inst)
				inst.sg.statemem.t = 0
				inst.components.combat:RestartCooldown()
				inst.components.timer:StopTimer("leap_cd")
				inst.components.timer:StartTimer("leap_cd", GetRandomMinMax(unpack(TUNING.WAGBOSS_ROBOT_LEAP_CD)))
			end),
			FrameEvent(42, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				SetShadowScale(inst, 0.93)
				inst:SetTempNoCollide(true, "leap")
			end),
			FrameEvent(43, function(inst)
				SetShadowScale(inst, 0.88)
			end),
			FrameEvent(44, function(inst)
				inst.sg:AddStateTag("noattack")
				SetShadowScale(inst, 0.85)
			end),
			FrameEvent(45, function(inst)
				SetShadowScale(inst, 0.84)
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.7) end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.8) end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst_front") end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/spin_jump") end),
			FrameEvent(40, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.leaping = true
					inst.sg:GoToState("leap", {
						target = inst.sg.statemem.target,
						pt = inst.sg.statemem.targetpos,
						t = inst.sg.statemem.t,
					})
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.leaping then
				inst:SetTempNoCollide(false, "leap")
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				SetShadowScale(inst, 1)
			end
		end,
	},

	State{
		name = "leap",
		tags = { "attack", "busy", "nointerrupt", "noattack", "jumping" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("atk_leap")
			if data then
				inst.sg.statemem.target = data.target
				inst.sg.statemem.targetpos = data.pt
				inst.sg.statemem.t = data.t or 20 * FRAMES
			else
				inst.components.locomotor:Stop()
			end
			SetShadowScale(inst, 0.84)
			inst:SetTempNoCollide(true, "leap")
		end,

		onupdate = OnUpdateLeap,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/spin_jump") end),
		
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.components.health:IsDead() then
						inst.sg:GoToState("death")
						return
					elseif inst.sg.mem.toturnoff then
						inst.sg:GoToState("turnoff")
						return
					end
					inst.sg.statemem.leaping = true
					inst.sg:GoToState("leap_pst")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.leaping then
				inst:SetTempNoCollide(false, "leap")
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				SetShadowScale(inst, 1)
			end
		end,
	},

	State{
		name = "leap_pst",
		tags = { "attack", "busy", "jumping" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("atk_leap_pst")
			SetShadowScale(inst, 0.84)
			inst:SetTempNoCollide(true, "leap")
		end,

		onupdate = OnUpdateLeap,

		timeline =
		{
			FrameEvent(1, function(inst) SetShadowScale(inst, 0.85) end),
			FrameEvent(2, function(inst) SetShadowScale(inst, 0.88) end),
			FrameEvent(3, function(inst) SetShadowScale(inst, 0.93) end),
			FrameEvent(4, function(inst)
				SetShadowScale(inst, 1)
				inst:SetTempNoCollide(false, "leap")
				inst.sg.statemem.landed = true
				inst.sg.statemem.shakeonexit = true
				inst:StartStompFx()
				inst.components.combat:RestartCooldown()
				inst.sg.statemem.targets = {}
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(4 + 12, function(inst)
				inst:StopStompFx()
			end),
			FrameEvent(5, function(inst)
				inst.sg.statemem.shakeonexit = nil
				DoStompShake(inst)
			end),
			FrameEvent(6, function(inst)
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(7, function(inst)
				DoStompAOE(inst, inst.sg.statemem.targets)
			end),
			FrameEvent(8, function(inst)
				inst.sg.statemem.stopped = true
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(27, GetUpShake1),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_stomp") end),
			FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
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
			if not inst.sg.statemem.landed then
				inst:SetTempNoCollide(false, "leap")
			end
			if inst.sg.statemem.speed then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
			if inst.sg.statemem.shakeonexit then
				DoStompShake(inst)
			end
			inst:StopStompFx(true)
		end,
	},

	State{
		name = "missiles_pre",
		tags = { "attack", "missiles", "busy", "first_missile" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile_pre1")
			if inst.sg.lasttags and inst.sg.lasttags["moving"] then
				DoFootstepMedShake(inst)
			end
			--inst.components.combat:StartAttack()
		end,

		timeline =
		{
			FrameEvent(35, GetUpShake1),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_missile_1") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(30, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("missiles_pre2")
				end
			end),
		},
	},

	State{
		name = "missiles_pre2",
		tags = { "attack", "missiles", "busy" },

		onenter = function(inst)
			if inst.sg.lasttags and inst.sg.lasttags["missiles_target_fail"] then
				inst.sg:AddStateTag("missiles_target_fail")
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile_pre2")
			GetUpShake2(inst)
		end,

		timeline =
		{
			--#SFX
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk") end),
			FrameEvent(19, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
			FrameEvent(17, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_missile_2") end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/missile_launch") end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/missile_launch") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("missiles")
				end
			end),
		},
	},

	State{
		name = "missiles",
		tags = { "attack", "missiles", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile")
			DoFootstepHeavyShake(inst)

			assert(next(inst._temptbl1) == nil)
			local targets = inst._temptbl1
			if not CollectMissileTargets(inst, NUM_MISSILES, targets) then
				inst.sg:AddStateTag("missiles_target_fail")
			end

			inst.sg.statemem.missiles = {}
			local x, _, z = inst.Transform:GetWorldPosition()
			local dir = math.random() * 360
			local dirdelta = 360 / NUM_MISSILES
			local dirvar = dirdelta / 3
			local grouptargets = {}
			for i = 1, NUM_MISSILES do
				local missile = SpawnPrefab("wagboss_missile")
				local dir1 = dir + math.random() * dirvar
				local targetorpos
				if #targets > 0 then
					targetorpos = targets[((i - 1) % #targets) + 1]
				else
					local theta = dir1 * DEGREES
					local r = 5 + 5 * math.random()
					targetorpos = Vector3(x + r * math.cos(theta), 0, z - r * math.sin(theta))
				end
				missile:Launch(i, inst, targetorpos, dir1, grouptargets)
				inst.sg.statemem.missiles[i] = missile
				dir = dir + dirdelta
			end
			for k in pairs(targets) do
				targets[k] = nil
			end
			--assert(next(targets) == nil)

			local taskdata = { missiles = inst.sg.statemem.missiles, grouptargets = grouptargets }
			taskdata.task = inst:DoPeriodicTask(1, TryRetargetMissiles, nil, taskdata)

			inst.components.epicscare:Scare(5)

			--inst.components.combat:RestartCooldown()
			inst.components.timer:StopTimer("missiles_cd")
			inst.components.timer:StartTimer("missiles_cd", GetRandomMinMax(unpack(TUNING.WAGBOSS_ROBOT_MISSILES_CD)))
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				for i, v in ipairs(inst.sg.statemem.missiles) do
					v:ShowMissile()
				end
			end),
			FrameEvent(15, function(inst)
				if inst.canmissilebarrage then
					inst.AnimState:SetDeltaTimeMultiplier(2)
				end
			end),

			--#SFX
			--FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState(inst.canmissilebarrage and "missiles_idle" or "missiles_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,
	},

	State{
		name = "missiles_idle",
		tags = { "attack", "missiles", "busy" },

		onenter = function(inst, missiles_time)
			if inst.sg.lasttags and inst.sg.lasttags["missiles_target_fail"] then
				inst.sg:AddStateTag("missiles_target_fail")
			end
			local t = GetTime()
			inst.sg.statemem.t = missiles_time or t + TUNING.WAGBOSS_ROBOT_MISSILE_BARRAGE_PERIOD[inst.threatlevel or 1]
			local timeout = inst.sg.statemem.t - t
			if timeout > 0 then
				inst.sg:SetTimeout(timeout)
			elseif inst.canmissilebarrage and inst.sg:HasStateTag("missiles_target_fail") then
				inst:SkipBarragePhase()
				inst.sg:GoToState("missiles_pst")
				return
			else
				inst.sg:GoToState(inst.canmissilebarrage --[[and HasAnyMissileTarget(inst)]] and "missiles_pre2" or "missiles_pst")
				return
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile_idle", true)
		end,

		ontimeout = function(inst)
			if inst.canmissilebarrage and inst.sg:HasStateTag("missiles_target_fail") then
				inst:SkipBarragePhase()
				inst.sg:GoToState("missiles_pst")
			else
				inst.sg:GoToState(inst.canmissilebarrage --[[and HasAnyMissileTarget(inst)]] and "missiles_pre2" or "missiles_pst")
			end
		end,

		events =
		{
			EventHandler("attacked", function(inst)--, data)
				inst.sg:GoToState("missiles_hit", inst.sg.statemem.t)
				return true
			end),
		},	
	},

	State{
		name = "missiles_hit",
		tags = { "hit", "missiles", "busy" },

		onenter = function(inst, missiles_time)
			if inst.sg.lasttags and inst.sg.lasttags["missiles_target_fail"] then
				inst.sg:AddStateTag("missiles_target_fail")
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile_hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
			inst.sg.statemem.t = missiles_time or 0
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				if inst.canmissilebarrage and inst.sg.statemem.t >= GetTime() + (17 - 8) * FRAMES then
					inst.sg:AddStateTag("caninterrupt")
				end
			end),
			FrameEvent(17, function(inst)
				if inst.canmissilebarrage and not inst.sg:HasAnyStateTag("caninterrupt", "missiles_target_fail") --[[and HasAnyMissileTarget(inst)]] then
					inst.sg:GoToState("missiles_pre2")
				end
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/missile_explode") end),
		},

		events =
		{
			EventHandler("attacked", function(inst)--, data)
				if inst.canmissilebarrage and inst.sg:HasStateTag("caninterrupt") then
					inst.sg:GoToState("missiles_hit", inst.sg.statemem.t)
				end
				return true
			end),
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.canmissilebarrage then
						inst.sg:GoToState("missiles_idle", inst.sg.statemem.t)
					else
						inst.sg:GoToState("missiles_pst")
					end
				end
			end),
		},
	},

	State{
		name = "missiles_pst",
		tags = { "attack", "missiles", "busy" },

		onenter = function(inst)
			if inst.sg.lasttags and inst.sg.lasttags["missiles_target_fail"] then
				inst.sg:AddStateTag("missiles_target_fail")
			end
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_missile_pst")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(32, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
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
		name = "signal_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_signal_pre")
		end,

		timeline =
		{
			FrameEvent(18, DoFootstepMedShake),
			FrameEvent(24, GetUpShake2),

			--#SFX
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.6) end),
			FrameEvent(11, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.7) end),
			FrameEvent(15, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pre_13tohit") end),
			FrameEvent(17, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(17, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(23, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
            FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
			FrameEvent(33, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/antennae_raise") end),

			FrameEvent(50, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/signal_LP", "signal") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.signaling = true
					inst.sg:GoToState("signal_loop", 1)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.signaling then
				inst.SoundEmitter:KillSound("signal")
			end
		end,
	},

	State{
		name = "signal_loop",
		tags = { "busy" },

		onenter = function(inst, loops)
			inst.components.locomotor:Stop()
			if not inst.AnimState:IsCurrentAnimation("atk_signal_loop") then
				inst.AnimState:PlayAnimation("atk_signal_loop", true)
			end
			if not inst.SoundEmitter:PlayingSound("signal") then
				inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/signal_LP", "signal")
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
			inst.sg.statemem.loops = loops or 1

			if inst.canhackdrones then
				inst.components.timer:StopTimer("hackdrones_cd")
				inst.components.timer:StartTimer("hackdrones_cd", TUNING.WAGBOSS_ROBOT_HACK_DRONES_CD)
				inst:HackDrones()
			end
			if inst.canorbitalstrike and
				not inst.components.timer:TimerExists("orbitalstrike_cd") and
				TryOrbitalStrike(inst)
			then
				inst.components.timer:StartTimer("orbitalstrike_cd", GetRandomMinMax(unpack(TUNING.WAGBOSS_ROBOT_ORBITAL_STRIKE_CD)))
			elseif inst.canhackdrones then
				local cd = inst.components.timer:GetTimeLeft("orbitalstrike_cd")
				local mincd = TUNING.WAGBOSS_ROBOT_ORBITAL_STRIKE_CD[1] / 3
				if cd == nil then
					inst.components.timer:StartTimer("orbitalstrike_cd", mincd)
				elseif cd < mincd then
					inst.components.timer:SetTimeLeft("orbitalstrike_cd", mincd)
				end
			end
		end,

		ontimeout = function(inst)
			if inst.sg.statemem.loops > 1 then
				inst.sg.statemem.signalling = true
				inst.sg:GoToState("signal_loop", inst.sg.statemem.loops - 1)
			else
				inst.sg:GoToState("signal_pst")
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.signalling then
				inst.SoundEmitter:KillSound("signal")
			end
		end,
	},

	State{
		name = "signal_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_signal_pst")
		end,

		timeline =
		{
			FrameEvent(16, GetUpShake1),
			FrameEvent(22, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(35, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
				inst.sg:AddStateTag("canrotate")
			end),

			--#SFX
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
			FrameEvent(7, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_med") end),
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
			FrameEvent(22, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short", nil, 0.8) end),
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
		name = "death",
		tags = { "dead", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:SetBankAndPlayAnimation("wagboss_lunar", "lunar_spawn_1")
			inst.AnimState:PushAnimation("lunar_spawn_2", false)
			inst.AnimState:Hide("lunar_comp")
			inst.AnimState:Hide("robot_back")
			inst.Physics:SetMass(0)

			inst:StartBackFx()
			inst:AddAlterSymbols()
			inst:EnableCameraFocus(true)

			inst.sg.statemem.alter = SpawnPrefab("alterguardian_phase4_lunarrift")
			inst.sg.statemem.alter.Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.sg.statemem.alter.sg:GoToState("spawn")
			inst.sg.statemem.alter.persists = false
			inst.sg.statemem.alter:AddTag("NOCLICK")
			inst.sg.statemem.alter.Physics:SetActive(false)

			if inst.sg.lasttags and inst.sg.lasttags["moving"] then
				DoFootstepMedShake(inst)
			end
		end,

		timeline =
		{
			FrameEvent(15, function(inst)
				inst:ReleaseDrones(false) --only soldiers
			end),
			FrameEvent(40, function(inst)
				inst.sg:AddStateTag("noattack")
				DoJumpShake(inst)
				inst:SetMusicLevel(2) --silence
			end),
			FrameEvent(54, function(inst) inst.SoundEmitter:KillSound("loop") end),
			FrameEvent(72, GetUpShake1),
			FrameEvent(96, GetUpShake2),
			FrameEvent(130, GetUpShake1),
			FrameEvent(147, function(inst)
				inst.AnimState:ClearSymbolBloom("glass1")
			end),
			FrameEvent(159, DoFootstepHeavyShake),
			FrameEvent(159, function(inst)
				inst.persists = false
				inst:AddTag("NOCLICK")
				inst.DynamicShadow:Enable(false)
				inst.Physics:SetActive(false)
				inst:StopBackFx()
				inst.AnimState:SetFinalOffset(-3) --move to back layer

				inst:ReleaseDrones(true) --include ones that didn't get hacked yet

				--do loot
				inst.components.lootdropper:DropLoot()
				local dir = math.random() * 360
				for i = 1, 3 do
					local dir1 = dir + math.random() * 360 / 6
					local leg = SpawnPrefab("wagboss_robot_leg")
					leg:StartTrackingBoss(inst.sg.statemem.alter)
					Launch2(leg, inst, 7, 4, 3, 2, 15 + math.random() * 4, dir1)
					dir = dir + 360 / 3
				end

                local wagpunk_arena_manager = TheWorld.components.wagpunk_arena_manager
                if wagpunk_arena_manager then
                    -- FIXME(JBK): Refactor this so the manager is not listening for the ondeath event for the wagboss_robot.
                    -- The robot or alter should fire an event to drive the manager's state when it dies.
                    wagpunk_arena_manager:TrackWagboss(inst.sg.statemem.alter)
                end
				inst.sg.statemem.alter.persists = true
				inst.sg.statemem.alter:RemoveTag("NOCLICK")
				inst.sg.statemem.alter.Physics:SetActive(true)
				inst.sg.statemem.alter.AnimState:SetFinalOffset(-1)
			end),
			FrameEvent(171, DoFootstepMedShake),
			FrameEvent(220, ErodeAway),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/spawn_1") end),
			FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(37, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/gears_drop") end),
			FrameEvent(37, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(80, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long") end),
			FrameEvent(93, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/spawn_2") end),
			FrameEvent(97, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
			FrameEvent(127, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/fsbig") end),
			FrameEvent(90, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/spawn_2") end),
			FrameEvent(109, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(129, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(174, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/mech_fall") end),
			FrameEvent(176, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/gears_drop") end),
			FrameEvent(196, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/spawn_3") end),
			FrameEvent(235, function(inst) inst.SoundEmitter:PlaySound("rifts5/lunar_boss/spawn_4") end),	},

		onexit = function(inst)
			--V2C: should not reach here
			inst:StopBackFx()
			inst.DynamicShadow:Enable(true)
			inst.AnimState:SetFinalOffset(-1)
			inst.AnimState:SetSymbolBloom("rb_head_glass")
			inst:ClearAlterSymbols()
			if not inst.SoundEmitter:PlayingSound("loop") then
				inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/active_lp", "loop")
			end
			inst.AnimState:SetBank("wagboss_robot")
			inst.AnimState:Show("lunar_comp")
			inst.AnimState:Show("robot_back")
			inst.Physics:SetMass(1000)
			inst.Physics:SetActive(true)
			inst.sg.statemem.alter:Remove()
			inst:SetMusicLevel(1)
			inst:EnableCameraFocus(false)
		end,
	},

	State{
		name = "turnoff",
		tags = { "off", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.mem.toturnoff = nil
			inst:ConfigureOff()
			inst:SetMusicLevel(0)
			inst.AnimState:PlayAnimation("deactivate")
		end,

		timeline =
		{
			FrameEvent(15, GetUpShake2),
			FrameEvent(54, DoFootstepMedShake),
			FrameEvent(71, DoFootstepMedShake),
			FrameEvent(84, DoJumpShake),

			FrameEvent(37, function(inst) inst.SoundEmitter:KillSound("loop") end),
			FrameEvent(84, function(inst)
				inst:MakeObstacle(true)
				local x, y, z = inst.Transform:GetWorldPosition()
                ClearSpotForRequiredPrefabAtXZ(x, z, inst.physicsradiusoverride)
				ToggleOffCharacterCollisions(inst)
				ToggleOnCharacterCollisions(inst)
			end),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/telemetry_death_1") end),
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(24, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/click_mult_high") end),
			FrameEvent(43, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(55, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_front") end),
			FrameEvent(75, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(86, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_stomp") end),
			FrameEvent(86, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst_front") end),
			FrameEvent(86, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/glass_break") end),
			FrameEvent(61, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long") end),
			FrameEvent(99, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(110, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/ratchet") end),
			FrameEvent(111, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/steam_burst") end),
			FrameEvent(133, function(inst) inst.SoundEmitter:PlaySound("rifts5/generic_metal/clunk_big_single") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					if inst.sg.mem.physicstask == nil then
						--Very minor thing, but ToggleOnCharacterCollisions uses height of 1
						inst.Physics:SetCapsule(inst.physicsradiusoverride, 2)
					end
					inst.sg.statemem.off = true
					inst.sg:GoToState("off", true)
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.off then
				if not inst.SoundEmitter:PlayingSound("loop") then
					inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/active_lp", "loop")
				end
				if inst.shattered then
					inst:ConfigureHostile()
					inst:SetMusicLevel(1)
				else
					inst:ConfigureFriendly()
				end
				inst:MakeObstacle(false)
			end
		end,
	},

	State{
		name = "walk_start",
		tags = { "moving", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:WalkForward()
			inst.Transform:SetFourFaced()
			inst.AnimState:PlayAnimation("walk_pre")
		end,

		timeline =
		{
			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.walking = true
					inst.sg:GoToState("walk")
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.walking then
				inst.Transform:SetNoFaced()
			end
		end,
	},

	State{
		name = "walk",
		tags = { "moving", "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:WalkForward()
			inst.Transform:SetFourFaced()
			if not inst.AnimState:IsCurrentAnimation("walk_loop") then
				inst.AnimState:PlayAnimation("walk_loop", true)
			end
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
		end,

		timeline =
		{
			FrameEvent(0, DoFootstepHeavyShake),
			FrameEvent(40, DoFootstepHeavyShake),
			FrameEvent(60, DoFootstepMedShake),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_front") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_long", nil, 0.5) end),
			FrameEvent(28, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pre_13tohit") end),
			FrameEvent(39, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(42, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
			FrameEvent(48, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pre_13tohit") end),
			FrameEvent(61, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/footstep_back") end),
			FrameEvent(61, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pre_13tohit") end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.walking = true
			inst.sg:GoToState("walk")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.walking then
				inst.Transform:SetNoFaced()
			end
		end,
	},

	State{
		name = "walk_stop",
		tags = { "canrotate" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("walk_pst")
		end,

		timeline =
		{
			FrameEvent(2, DoFootstepHeavyShake),

			--#SFX
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/metal_wronk_short") end),
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/hydraulic_pst") end),
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

return StateGraph("wagboss_robot", states, events, "off")
