require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/follow"
require "behaviours/chaseandattack"
require("behaviours/wander")
local BrainCommon = require("brains/braincommon")
local clockwork_common = require("prefabs/clockwork_common")

local START_FACE_DIST = 14
local KEEP_FACE_DIST = 16
local GO_HOME_DIST_SQ = 1
local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 20
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local FOLLOW_MIN_DIST = 5
local FOLLOW_TARGET_DIST = 7
local FOLLOW_MAX_DIST = 12

local GILDED_FORMATION_RANGE = 3

local GILDED_FOLLOW_MIN_DIST = 3
local GILDED_FOLLOW_TARGET_DIST = 4
local GILDED_FOLLOW_MAX_DIST = 6

local KnightBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
	if inst.components.combat:HasTarget() then
        return
    end
	local homePos = clockwork_common.GetHomePosition(inst)
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function GetFaceTargetFn(inst)
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function KeepFaceTargetFn(inst, target)
    return not target:HasTag("notarget") and inst:IsNear(target, KEEP_FACE_DIST)
end

local function GetLeader(inst)
	return inst.components.follower and inst.components.follower:GetLeader()
end

local function GetFaceLeaderFn(inst)
    return GetLeader(inst)
end

local function KeepFaceLeaderFn(inst, target)
    return GetLeader(inst) == target
end

local function ShouldGoHome(inst)
	local homePos = clockwork_common.GetHomePosition(inst)
	return homePos ~= nil and inst:GetDistanceSqToPoint(homePos) > GO_HOME_DIST_SQ
end

local function ShouldDodge(inst)
	if inst.components.combat:HasTarget() and inst.components.combat:InCooldown() then
		inst.hit_recovery = TUNING.KNIGHT_DODGE_HIT_RECOVERY
		return true
	end
	inst.hit_recovery = nil
	return false
end

local function ShouldAttack(inst)
	inst.hit_recovery = nil
	return not ShouldDodge(inst)
end

local function GetRunAwayTarget(inst)
	return inst.components.combat.target
end

local function GetNearestPlayer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    return FindClosestPlayerInRangeSq(x, y, z, ENTITY_POPOUT_RADIUS_SQ)
end

local function AreDifferentPlatforms(inst, target)
    if inst.components.locomotor.allow_platform_hopping then
        return inst:GetCurrentPlatform() ~= target:GetCurrentPlatform()
    end
    return false
end

local function TryJoust(inst)
	if inst.canjoust then
		local target = inst.components.combat.target
		if target then
			local dsq = inst:GetDistanceSqToPoint(target.Transform:GetWorldPosition())
			local range = TUNING.YOTH_KNIGHT_JOUST_RANGE
			if dsq >= range.min * range.min and dsq < range.max * range.max and not AreDifferentPlatforms(inst, target) then
				inst:PushEvent("dojoust", target)
			end
		end
	end
end

local function AnyHorsemenAllies(inst)
	for _, name in ipairs(YOTH_HORSE_NAMES) do
		local knight = inst.components.entitytracker:GetEntity(name)
		if knight and not IsEntityDead(knight) then
			return true
		end
	end
end

local function GetFormationIndexAndCount(inst)
	local count = 1 -- Start at 1, to count ourselves

	local count_only = false
	local nextindex = 1
	for _, name in ipairs(YOTH_HORSE_NAMES) do
		if inst.horseman_type ~= name then
			local knight = inst.components.entitytracker:GetEntity(name)
			if knight and not IsEntityDead(knight) then
				if not count_only then
					nextindex = nextindex + 1
				end
				count = count + 1
			end
		else
			count_only = true
		end
	end

	return nextindex, count
end

local function GetKnightAtFormationIndex(inst, index)
	local nextindex = 1
	for _, name in ipairs(YOTH_HORSE_NAMES) do
		if inst.horseman_type ~= name then
			local knight = inst.components.entitytracker:GetEntity(name)
			if knight and not IsEntityDead(knight) then
				if index == nextindex then
					return knight
				end
				nextindex = nextindex + 1
			end
		else
			if index == nextindex then
				return inst
			end
			nextindex = nextindex + 1
		end
	end
end

local function NoPlayersOrHoles(pt)
    return not (IsAnyPlayerInRange(pt.x, 0, pt.z, 1) or TheWorld.Map:IsPointNearHole(pt))
end

local function _calc_formation_pos(leaderpt, formation_index, count)
	local theta = PI * ((2 * formation_index - 1) / count)
	local leash_pos = Vector3(leaderpt.x + math.cos(theta) * GILDED_FORMATION_RANGE, 0, leaderpt.z - math.sin(theta) * GILDED_FORMATION_RANGE)

	if not TheWorld.Map:IsPassableAtPoint(leash_pos.x, leash_pos.y, leash_pos.z) then
		local land_offset =
			FindWalkableOffset(leash_pos, 0, 3, 6, nil, nil, NoPlayersOrHoles, nil, true) or
			FindWalkableOffset(leash_pos, 0, 6, 8, nil, nil, NoPlayersOrHoles, nil, true) or
			FindWalkableOffset(leash_pos, 0, 8, 8, nil, nil, NoPlayersOrHoles, nil, true)
		if land_offset then
			return leash_pos + land_offset
		end
	end

	return leash_pos
end

local function GetLocationInFormation(inst)
    local leader = GetLeader(inst)
	return leader and _calc_formation_pos(leader:GetPosition(), GetFormationIndexAndCount(inst))
end

--------------------------------------------------------------------------
--Formation wandering: we pick one knight in our formation as our "leader"
--The rest won't start moving until leader moves first, so we periodically
--switch leaders to make it less obvious.
local WANDER_SWITCH_PERIOD = 8
local function GetWanderFormationLeaderIndex(inst, count)
	--deterministic way for all brains to choose the same leader
	--(index 1 GUID guaranteed not nil coz there's always our own inst)
	local seed = GetKnightAtFormationIndex(inst, 1).GUID
	seed = seed + math.floor(GetTime() / WANDER_SWITCH_PERIOD)
	return PRNG_Uniform(seed):RandInt(count)
end

local function IsWanderFormationLeader(inst)
	local formation_index, count = GetFormationIndexAndCount(inst)
	return GetWanderFormationLeaderIndex(inst, count) == formation_index
end

local function GetWanderFormationPos(inst)
	local formation_index, count = GetFormationIndexAndCount(inst)
	local leader_index = GetWanderFormationLeaderIndex(inst, count)
	local leader = GetKnightAtFormationIndex(inst, leader_index)
	if leader then
		if inst == leader then
			--Leader switched, but we haven't got back up to the "WanderFormation" WhileNode yet.
			--NOTE: returning nil in this case will crash the debug string because the Leash node
			--		is still "RUNNING".
			return inst:GetPosition()
		end

		--Reverse find our virtual leaderpt based on leader knight's position.
		local theta = PI * ((2 * leader_index - 1) / count)
		local leaderpt = leader:GetPosition()
		leaderpt.x = leaderpt.x - math.cos(theta) * GILDED_FORMATION_RANGE
		leaderpt.z = leaderpt.z + math.sin(theta) * GILDED_FORMATION_RANGE

		return _calc_formation_pos(leaderpt, formation_index, count)
	end
end

local function MatchWanderLeaderFacing(inst)
	if inst.sg:HasStateTag("idle") then
		local formation_index, count = GetFormationIndexAndCount(inst)
		local leader_index = GetWanderFormationLeaderIndex(inst, count)
		local leader = GetKnightAtFormationIndex(inst, leader_index)
		if leader and leader ~= inst and leader.sg:HasStateTag("idle") then
			inst.Transform:SetRotation(leader.Transform:GetRotation())
		end
	end
end
--------------------------------------------------------------------------

local CHARLIE_SEAT_RANGE = 15
local CHARLIE_SEAT_MUST_TAGS = { "charlie_seat" }

local SEAT_BLOCKER_RANGE = 0.1
local SEAT_BLOCKER_RANGE_PADDING = 3
local SEAT_BLOCKER_CANT_TAGS = { "NOCLICK", "DECOR", "FX" }
local function GetStageSeatPosition(inst)
	local formation_index, count = GetFormationIndexAndCount(inst)

	inst.is_sitting = nil

	local leader = GetLeader(inst)
	local stage = leader ~= nil and leader.components.stageactor:GetStage() or nil
	if stage then
		local x, y, z = stage.Transform:GetWorldPosition()
		local seats = TheSim:FindEntities(x, y, z, CHARLIE_SEAT_RANGE, CHARLIE_SEAT_MUST_TAGS)

		for i, v in ipairs(seats) do
			local continue = false
			while v ~= nil and not continue do
				local vx, vy, vz = v.Transform:GetWorldPosition()
				local ents = TheSim:FindEntities(vx, vy, vz, SEAT_BLOCKER_RANGE + SEAT_BLOCKER_RANGE_PADDING, nil, SEAT_BLOCKER_CANT_TAGS)

				continue = true
				for k, ent in ipairs(ents) do
					if ent ~= inst and ent.Physics and not ent:HasTag("gilded_knight") then
						local range1 = SEAT_BLOCKER_RANGE + ent:GetPhysicsRadius(0)
						if ent:GetDistanceSqToPoint(vx, vy, vz) < range1 * range1 then
							table.remove(seats, i)
            				v = seats[i]
							continue = false
							break
						end
					end
				end
			end
		end

		if seats[formation_index] then
			inst.is_sitting = true
			return seats[formation_index]:GetPosition()
		end
	end
end

local function GetStageFollowMinDist(inst)
	return inst.is_sitting and 0.1 or FOLLOW_MIN_DIST
end

local PRIORITY_NODE_RATE = 0.25
function KnightBrain:OnStart()
    local gilded = self.inst:HasTag("gilded_knight")
    local CHASE_DIST = gilded and ENTITY_POPOUT_RADIUS or MAX_CHASE_DIST -- Gilded must be very far because of the distance they can travel to chase down their target is relative to the group and not the self.
    local CHASE_TIME = gilded and TUNING.YOTH_KNIGHT_MAX_CHASE_TIME or MAX_CHASE_TIME

	local FOLLOWER_MIN_DIST = gilded and GILDED_FOLLOW_MIN_DIST or FOLLOW_MIN_DIST
	local FOLLOWER_TARGET_DIST = gilded and GILDED_FOLLOW_TARGET_DIST or FOLLOW_TARGET_DIST
	local FOLLOWER_MAX_DIST = gilded and GILDED_FOLLOW_MAX_DIST or FOLLOW_MAX_DIST

	--

	local gilded_stage_nodes = WhileNode(function()
			if gilded then
				local leader = GetLeader(self.inst)
				local stageactor = leader ~= nil and leader.components.stageactor or nil
				return stageactor ~= nil and stageactor:GetStage() ~= nil or nil
			end
		end, "GildedStageSeating",
		PriorityNode({
				Leash(self.inst, GetStageSeatPosition, 0.5, 0.25, true),
				Follow(self.inst, GetLeader, GetStageFollowMinDist, FOLLOW_TARGET_DIST, FOLLOW_MAX_DIST),
				FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn),
				StandStill(self.inst),
		}, PRIORITY_NODE_RATE))

	local gilded_formation_nodes = WhileNode(function()
			return gilded and GetLeader(self.inst) ~= nil and AnyHorsemenAllies(self.inst)
		end, "GildedFormation",
		PriorityNode({
			Leash(self.inst, GetLocationInFormation, 0.5, 0.5, true),
			FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn),
			StandStill(self.inst),
		}, PRIORITY_NODE_RATE))

    local root = PriorityNode(
    {
		WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "<jousting state guard>",
			PriorityNode({
				BrainCommon.PanicTrigger(self.inst),
				BrainCommon.ElectricFencePanicTrigger(self.inst),
				clockwork_common.WaitForTrader(self.inst),
				WhileNode(function() return ShouldAttack(self.inst) end, "AttackMomentarily",
					ParallelNodeAny{
						ChaseAndAttack(self.inst, MAX_CHASE_TIME, CHASE_DIST),
						ConditionWaitNode(function()
							TryJoust(self.inst)
							return false
						end, "Joust"),
					}),
				WhileNode(function() return ShouldDodge(self.inst) end, "Dodge",
					RunAway(self.inst, { getfn = GetRunAwayTarget }, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),
				WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
					DoAction(self.inst, GoHomeAction, "Go Home", true)),
				FailIfSuccessDecorator(ActionNode(function()
						if self.inst.TryToEngageCombatWithGroup then
							return self.inst:TryToEngageCombatWithGroup()
						end
					end)),

				-- Gilded behaviours
				gilded_stage_nodes,
				gilded_formation_nodes,
				--
				Follow(self.inst, GetLeader, FOLLOWER_MIN_DIST, FOLLOWER_TARGET_DIST, FOLLOWER_MAX_DIST),

				IfNode(function() return GetLeader(self.inst) end, "has leader",
					FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn )),

				IfNode(function() return gilded end, "GildedWander",
					PriorityNode({
						WhileNode(function() return not IsWanderFormationLeader(self.inst) end, "WanderFormation",
							ParallelNode{
								PriorityNode({
									Leash(self.inst, GetWanderFormationPos, 0, 0, true),
									StandStill(self.inst), --tbh likely never reach here because of 0 dist leash
								}, PRIORITY_NODE_RATE),
								ConditionWaitNode(function()
									MatchWanderLeaderFacing(self.inst)
									return false
								end, "MatchLeaderFacing"),
							}),
						FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
						Wander(self.inst, nil, nil, {
							--fixed times so wander leader switches happen during waiting
							minwalktime = 4,
							randwalktime = 0,
							minwaittime = WANDER_SWITCH_PERIOD - 4 - 1.5,
							randwaittime = 0,
						}),
					}, PRIORITY_NODE_RATE)),

				FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
				StandStill(self.inst),
			}, PRIORITY_NODE_RATE)),
	}, PRIORITY_NODE_RATE)

    self.bt = BT(self.inst, root)
end

return KnightBrain
