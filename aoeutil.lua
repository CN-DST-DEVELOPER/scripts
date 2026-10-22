--[[
NOTES:
- In general, do in this order if an attack does multiple things in the same frame:
	1. Work
	2. Attack
	3. TossItems
]]
--------------------------------------------------------------------------

local ATTACK_MUST_TAGS = { "_combat" }
local ATTACK_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local AttackTagSet = Class(function(self, must, cant, oneof, register)
	if must or cant or oneof then
		self.must, self.cant, self.oneof = must, cant, oneof
	else
		self.must = shallowcopy(ATTACK_MUST_TAGS)
		self.cant = shallowcopy(ATTACK_CANT_TAGS)
	end
	if register then
		self:Register()
	end
end)

local function _append_array(ar, ...)
	if ar == nil then
		return { ... }
	end
	local n = #ar
	for i = 1, select('#', ...) do
		ar[n + i] = select(i, ...)
	end
	return ar
end

function AttackTagSet:AppendMustTags(...) self.must = _append_array(self.must, ...) end
function AttackTagSet:AppendCantTags(...) self.cant = _append_array(self.cant, ...) end
function AttackTagSet:AppendOneOfTags(...) self.oneof = _append_array(self.oneof, ...) end

function AttackTagSet:Get()
	return self.must, self.cant, self.oneof
end

function AttackTagSet:GetRegistered()
	return self.registered
end

function AttackTagSet:IsRegistered()
	return self.registered ~= nil
end

function AttackTagSet:Register()
	assert(self.registered == nil, "AttackTagSet was already registered.")
	self.registered = TheSim:RegisterFindTags(self:Get())
end

--------------------------------------------------------------------------

local ATTACK_RADIUS_PADDING = 3

local function _Attack(inst, dig, radius_or_params, tagset, targets, repeatdelay, attacker, weapon, projectile)
	local dist, radius, arc, hitbox, attack_filterfn, knockback_str, knockback_heavystr, knockback_forcelanded
	if type(radius_or_params) == "table" then
		dist = radius_or_params.dist or 0
		radius = radius_or_params.radius
		arc = radius_or_params.arc
		hitbox = radius_or_params.hitbox
		attack_filterfn = radius_or_params.attack_filterfn
		knockback_str = radius_or_params.knockback_str
		knockback_heavystr = radius_or_params.knockback_heavystr
		knockback_forcelanded = radius_or_params.knockback_forcelanded
	else
		dist = 0
		radius = radius_or_params
	end

	attacker = attacker or inst
	attacker.components.combat.ignorehitrange = true

	local x, _, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	local t = repeatdelay and GetTime()
	local ents = tagset:IsRegistered() and
		TheSim:FindEntities_Registered(x, 0, z, radius + ATTACK_RADIUS_PADDING, tagset:GetRegistered()) or
		TheSim:FindEntities(x, 0, z, radius + ATTACK_RADIUS_PADDING, tagset:Get())
	for _, v in ipairs(ents) do
		if v ~= inst and
			not (	targets and
					targets[v] and
					not (repeatdelay and type(targets[v]) == "number" and targets[v] < t)
				) and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead()) and
			(attack_filterfn == nil or attack_filterfn(v, inst))
		then
			local x1, _, z1 = v.Transform:GetWorldPosition()
			local r1 = v:GetPhysicsRadius(0)
			local range = radius + r1
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				--convert to local space x, and test against arcx
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				(hitbox == nil or hitbox:CollidesWithCircle(x1, z1, r1)) and
				attacker.components.combat:CanTarget(v)
			then
				if targets then
					targets[v] = repeatdelay == nil or t + repeatdelay
				end
				if dig and v.components.locomotor == nil and v.components.health then
					v.components.health:Kill()
				else
					if targets and knockback_str and v.components.rider and v.components.rider.mount then
						targets[v.components.rider.mount] = targets[v]
					end
					attacker.components.combat:DoAttack(v, weapon, projectile)
					if knockback_str then
						local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and knockback_heavystr or knockback_str
						v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = knockback_forcelanded })
					end
				end
			end
		end
	end

	attacker.components.combat.ignorehitrange = false
end

--attacker, weapon, and projectile are optional overrides

local function Attack(inst, radius_or_params, tagset, targets, repeatdelay, attacker, weapon, projectile)
	return _Attack(inst, false, radius_or_params, tagset, targets, repeatdelay, attacker, weapon, projectile)
end

local function AttackAndDig(inst, radius_or_params, tagset, targets, repeatdelay, attacker, weapon, projectile)
	return _Attack(inst, true, radius_or_params, tagset, targets, repeatdelay, attacker, weapon, projectile)
end

--------------------------------------------------------------------------

local WORK_RADIUS_PADDING = 0.5
local WORK_ACTIONS, REGISTERED_WORK_TAGS
local WORK_AND_DIG_ACTIONS, REGISTERED_WORK_AND_DIG_TAGS

local function _Work(inst, dig, radius_or_params, targets, worker)
	local dist, radius, arc, hitbox, work_filterfn
	if type(radius_or_params) == "table" then
		dist = radius_or_params.dist or 0
		radius = radius_or_params.radius
		arc = radius_or_params.arc
		hitbox = radius_or_params.hitbox
		work_filterfn = radius_or_params.work_filterfn
	else
		dist = 0
		radius = radius_or_params
	end

	local actions, tags
	if dig then
		if WORK_AND_DIG_ACTIONS == nil then
			WORK_AND_DIG_ACTIONS =
			{
				CHOP = true,
				HAMMER = true,
				MINE = true,
				DIG = true,
			}
			REGISTERED_WORK_AND_DIG_TAGS = TheSim:RegisterFindTags(
				nil,
				{ "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" },
				{ "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable", "pickable" })
		end
		actions, tags = WORK_AND_DIG_ACTIONS, REGISTERED_WORK_AND_DIG_TAGS
	else
		if WORK_ACTIONS == nil then
			WORK_ACTIONS =
			{
				CHOP = true,
				HAMMER = true,
				MINE = true,
			}
			REGISTERED_WORK_TAGS = TheSim:RegisterFindTags(
				nil,
				{ "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" },
				{ "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable" })
		end
		actions, tags = WORK_ACTIONS, REGISTERED_WORK_TAGS
	end

	worker = worker or inst

	local x, _, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end

	local worked = false
	for _, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, radius + WORK_RADIUS_PADDING, tags)) do
		if v ~= inst and
			not (targets and targets[v]) and
			v:IsValid() and not v:IsInLimbo() and
			(work_filterfn == nil or work_filterfn(v, inst))
		then
			local inrange = true
			if arcx or hitbox then
				--convert to local space x, and test against arcx
				local x1, _, z1 = v.Transform:GetWorldPosition()
				inrange =
					(arcx == nil or x + cos_theta * (x1 - x) - sin_theta * (z1 - z) > arcx) and
					(hitbox == nil or hitbox:CollidesWithCircle(x1, z1, v:GetPhysicsRadius(0)))
			end
			if inrange then
				local isworkable = false
				if v.components.workable then
					local work_action = v.components.workable:GetWorkAction()
					--V2C: nil action for NPC_workable (e.g. campfires)
					isworkable =
						(	work_action == nil and v:HasTag("NPC_workable")	) or
						(	v.components.workable:CanBeWorked() and
							work_action and
							actions[work_action.id] and
							not (dig and (v.components.spawner or v.components.childspawner))
						)
				end
				if isworkable then
					v.components.workable:Destroy(worker)
					if dig and v:IsValid() and v:HasTag("stump") then
						v:Remove()
					end
					if targets then
						targets[v] = true
					end
					worked = true
				elseif dig and
					v.components.pickable and
					v.components.pickable:CanBePicked() and
					not v:HasTag("intense")
				then
					v.components.pickable:Pick(worker)
					if targets then
						targets[v] = true
					end
					worked = true
				end
			end
		end
	end
	return worked
end

--worker is an optional override

local function Work(inst, radius_or_params, targets, worker)
	return _Work(inst, false, radius_or_params, targets, worker)
end

local function WorkAndDig(inst, radius_or_params, targets, worker)
	return _Work(inst, true, radius_or_params, targets, worker)
end

--------------------------------------------------------------------------

local TOSS_RADIUS_PADDING = 0.5
local REGISTERED_TOSS_TAGS

local function _TossLaunch(item, x0, z0, basespeed, verticalspeed, startradius, startheight)
	local x1, y1, z1 = item.Transform:GetWorldPosition()
	local dx, dz = x1 - x0, z1 - z0
	local angle
	if dx ~= 0 or dz ~= 0 then
		angle = math.atan2(-dz, dx) + (math.random() * 20 - 10) * DEGREES
		if startradius then
			startradius = math.max(math.sqrt(dx * dx + dz * dz), startradius)
		end
	else
		angle = TWOPI * math.random()
	end
	y1 = math.max(y1, startheight)
	local sina, cosa = math.sin(angle), math.cos(angle)
	if not (startradius and TryTeleportToLaunchPos(item, x0 + startradius * cosa, y1, z0 - startradius * sina)) then
		item.Physics:Teleport(x1, y1, z1) --safe to just move vertically
	end

	local speed = basespeed + math.random()
	item.Physics:SetVel(cosa * speed, verticalspeed + math.random(), -sina * speed)

	if item.components.inventoryitem then
		item.components.inventoryitem:SetLanded(false, true)
	end
end

local function TossItems(inst, params, targets)
	local dist = params.dist or 0
	local radius = params.radius
	local basespeed = params.basespeed
	local verticalspeed = params.verticalspeed
	local startradius = params.startradius
	local startheight = params.startheight or 0.1

	if REGISTERED_TOSS_TAGS == nil then
		REGISTERED_TOSS_TAGS = TheSim:RegisterFindTags(
			{ "_inventoryitem" },
			{ "locomotor", "INLIMBO" },
			nil)
	end

	local x, _, z = inst.Transform:GetWorldPosition()
	if dist ~= 0 then
		local theta = inst.Transform:GetRotation() * DEGREES
		x = x + dist * math.cos(theta)
		z = z - dist * math.sin(theta)
	end
	for _, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, radius + TOSS_RADIUS_PADDING, REGISTERED_TOSS_TAGS)) do
		if not (targets and targets[v]) then
			DeactivateInventoryItemBeforeLaunch(v)
			if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
				_TossLaunch(v, x, z, basespeed, verticalspeed, startradius, startheight)
			end
			if targets then
				targets[v] = true
			end
		end
	end
end

--------------------------------------------------------------------------

return {
	AttackTagSet = AttackTagSet,
	Attack = Attack,
	AttackAndDig = AttackAndDig,
	Work = Work,
	WorkAndDig = WorkAndDig,
	TossItems = TossItems,
}
