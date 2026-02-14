require("behaviours/faceentity")

local function ForceSetNewHome(inst)
	inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
end

local function DoInitHomePosition(inst)
	inst:RemoveEventCallback("entitysleep", DoInitHomePosition)
	inst:RemoveEventCallback("entitywake", DoInitHomePosition)
	inst.components.knownlocations:RememberLocation("home", inst:GetPosition(), true)
end

local function InitHomePosition(inst)
	inst:ListenForEvent("entitysleep", DoInitHomePosition)
	inst:ListenForEvent("entitywake", DoInitHomePosition)
end

local function GetHomePosition(inst)
	return not (inst.components.follower and inst.components.follower:GetLeader())
		and inst.components.knownlocations:GetLocation("home")
		or nil
end

local SLEEP_DIST_FROMHOME_SQ = 1 * 1
local SLEEP_DIST_FROMTHREAT = 20
local MAX_CHASEAWAY_DIST_SQ = 40 * 40
local MAX_TARGET_SHARES = 5
local SHARE_TARGET_DIST = 40

local THREAT_TAGS = { "character" }
local THREAT_NO_TAGS = { "INLIMBO" }
local THREAT_NO_TAGS_WITH_LEADERMEM = { "INLIMBO", "player"}

local function ShouldSleep(inst)
	local homePos = GetHomePosition(inst)
	if homePos == nil or
		(inst.components.combat and inst.components.combat:HasTarget()) or
		(inst.components.burnable and inst.components.burnable:IsBurning()) or
		(inst.components.freezable and inst.components.freezable:IsFrozen())
	then
		return false
	end

	local x, _, z = inst.Transform:GetWorldPosition()
	if distsq(x, z, homePos.x, homePos.z) >= SLEEP_DIST_FROMHOME_SQ then
		return false
	end

	--since homePos can't be nil here, we can assume no leader.
	--assert(inst.components.follower:GetLeader() == nil)

	for _, v in ipairs(TheSim:FindEntities(x, 0, z, SLEEP_DIST_FROMTHREAT, THREAT_TAGS, inst.components.followermemory and inst.components.followermemory:HasRememberedLeader() and THREAT_NO_TAGS_WITH_LEADERMEM or THREAT_NO_TAGS)) do
		if v.entity:IsVisible() then
			return false
		end
	end
	return true
end

local function ShouldWake(inst)
	return not ShouldSleep(inst)
end

--"chess" that aren't following players
local function IsWildChess(ent, skipchesstagtest)
	local leader = ent.components.follower and ent.components.follower:GetLeader()
	return not (leader and leader.isplayer) and (skipchesstagtest or ent:HasTag("chess"))
end

local function IsAlly(inst, target)
	return IsWildChess(inst, true) and IsWildChess(target)
		or inst.components.combat:IsAlly(target)
end

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "chess" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }
local CHESSFRIEND_RANGE_PERCENT = 0.5
local function Retarget(inst, range, extrafilterfn)
	local homePos = GetHomePosition(inst)
	if (homePos and inst:GetDistanceSqToPoint(homePos) >= range * range) or
		not IsWildChess(inst, true) or -- Only target things that are directed externally when following players.
		(inst.components.followermemory and inst.components.followermemory:HasRememberedLeader())
	then
		return nil
	end

	local chessfriend_range = range * CHESSFRIEND_RANGE_PERCENT
    return FindEntity(
            inst,
            range,
			function(guy, inst)
                if extrafilterfn then
                    local boolval = extrafilterfn(inst, guy)
                    if boolval ~= nil then
                        return boolval
                    end
                    -- Pass through and continue default behaviour.
                end
                if guy:HasTag("chessfriend") and not guy:IsNear(inst, chessfriend_range) then
                    return false
				--V2C: redundant because we skip retargeting entirely if we have a remembered leader now (see above).
				--elseif inst.components.followermemory and inst.components.followermemory:IsRememberedLeader(guy) then
				--	return false
				end
				return inst.components.combat:CanTarget(guy) and not IsAlly(inst, guy)
            end,
            RETARGET_MUST_TAGS,
            RETARGET_CANT_TAGS,
            RETARGET_ONEOF_TAGS
        )
end

local AOE_TAGS = RETARGET_MUST_TAGS
local AOE_CANT_TAGS = { "INLIMBO", "notarget", "noattack" }
local function FindAOETargetsAtXZ(inst, x, z, radius, fn)
	local myTarget = inst.components.combat.target
	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius, AOE_TAGS, AOE_CANT_TAGS)) do
		if v ~= inst and v.entity:IsVisible() and
			inst.components.combat:CanTarget(v) and
			(	v == myTarget or
				(v.components.combat and v.components.combat:TargetIs(inst)) or
				not IsAlly(inst, v)
			)
		then
			fn(v, inst)
		end
	end
end

local function KeepTarget(inst, target)
	local homePos = GetHomePosition(inst)
	if homePos then
		if target:GetDistanceSqToPoint(homePos) >= MAX_CHASEAWAY_DIST_SQ then
			return false
		end
	elseif target:GetDistanceSqToInst(inst) >= MAX_CHASEAWAY_DIST_SQ then
		return false
    end
	--don't keep target if it became an ally mid-fight
	return inst._targetwasally or not IsAlly(inst, target)
end

local function OnAttacked(inst, data)
	if data and data.attacker then
		local iswild = IsWildChess(inst, true)
		if iswild and IsWildChess(data.attacker) then
			--ignore this accidental hit?
			return
		end
		inst.components.combat:SetTarget(data.attacker)

		if iswild then
			inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST,
				function(dude)--, inst)
					return dude ~= data.attacker and IsWildChess(dude)
				end,
				MAX_TARGET_SHARES)
		end
	end
end

local function OnNewCombatTarget(inst, data)
	inst._targetwasally = data and data.target and IsAlly(inst, data.target) or nil
end

local function TryBefriendChess(inst, doer)
	if not inst.components.health:IsDead() and
		inst.components.follower:GetLeader() == nil and
		inst:HasTag("befriendable_clockwork") and
		doer and doer:IsValid() and not IsEntityDeadOrGhost(doer) and
		doer.components.leader and
		doer.components.minigame_participator == nil
	then
		doer:PushEvent("makefriend")
		inst.components.followermemory:RememberAndSetLeader(doer)

		local target = inst.components.combat.target
		if target and (IsAlly(inst, target) or (target.isplayer and not TheNet:GetPVPEnabled())) then
			if target.components.combat and target.components.combat:TargetIs(inst) then
				target.components.combat:DropTarget()
			end
			inst.components.combat:DropTarget()
		end

		return true
	end
	return false
end

local function MakeBefriendable(inst)
	inst:AddComponent("followermemory")
	inst.components.followermemory:SetOnReuniteLeaderFn(TryBefriendChess)
	inst.components.followermemory:SetOnLeaderLostFn(ForceSetNewHome)

	inst.TryBefriendChess = TryBefriendChess
end

local function sgTrySetBefriendable(inst)
	if inst.TryBefriendChess then
		inst:AddTag("befriendable_clockwork")
	end
end

local function sgTryClearBefriendable(inst)
	if inst.TryBefriendChess and not inst.sg.statemem.keepbefriendable then
		inst:RemoveTag("befriendable_clockwork")
	end
end

--------------------------------------------------------------------------

local function CancelRegen(inst)
	if inst._regen then
		if inst._regen == true then
			inst.components.health:RemoveRegenSource(inst)
		else
			inst._regen:Cancel()
		end
		inst._regen = nil
	end
end

local function DoStartRegen(inst)
	inst._regen = true
	inst.components.health:AddRegenSource(inst, TUNING.CLOCKWORK_HEALTH_REGEN, TUNING.CLOCKWORK_HEALTH_REGEN_PERIOD)
end

local function OnHealthDelta(inst)
	if inst.components.health:IsHurt() and not inst.components.health:IsDead() then
		if inst._regen == nil then
			inst._regen = inst:DoTaskInTime(TUNING.CLOCKWORK_HEALTH_REGEN_DELAY, DoStartRegen)
		end
	else
		CancelRegen(inst)
	end
end

local function StopRegenOnEnterCombat(inst)
	inst:RemoveEventCallback("healthdelta", OnHealthDelta)
	CancelRegen(inst)
end

local function TryRegenOnExitCombat(inst)
	inst:ListenForEvent("healthdelta", OnHealthDelta)
	OnHealthDelta(inst)
end

local function MakeHealthRegen(inst)
	inst:ListenForEvent("newcombattarget", StopRegenOnEnterCombat)
	inst:ListenForEvent("droppedtarget", TryRegenOnExitCombat)
end

--------------------------------------------------------------------------

local SEE_TRADER_DIST = 20
local KEEP_TRADER_DIST = 10

local function CanAcceptTrades(inst)
	if inst.components.follower:GetLeader() then
		return false
	end
	local last_attacked_t = inst.components.combat:GetLastAttackedTime()
	if last_attacked_t and last_attacked_t + 3 >= GetTime() then
		return false
	end
	return true
end

local function IsTradingWithMe(inst, guy)
	local target
	local act = guy:GetBufferedAction()
	if act then
		target = act.target
		act = act.action
	elseif guy.components.playercontroller then
		act, target = guy.components.playercontroller:GetRemoteInteraction()
	end
	return target == inst and act == ACTIONS.USEITEMON
end

local function FindNearestTrader(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local players = FindPlayersInRangeSortedByDistance(x, y, z, SEE_TRADER_DIST, true)
	for _, v in ipairs(players) do
		if IsTradingWithMe(inst, v) then
			return v
		end
	end
end

local function GetTraderFn(inst)
	return CanAcceptTrades(inst) and FindNearestTrader(inst) or nil
end

local function KeepTraderFn(inst, target)
	if not CanAcceptTrades(inst) then
		return false
	elseif IsTradingWithMe(inst, target) and inst:GetDistanceSqToPoint(target.Transform:GetWorldPosition()) < KEEP_TRADER_DIST * KEEP_TRADER_DIST then
		return true
	end
	local trader = FindNearestTrader(inst)
	if trader == target then
		return true
	end
	inst._brain_switchingtrader = trader ~= nil or nil
	return false
end

local function WaitForTrader(inst)
	return PriorityNode({
		FaceEntity(inst, GetTraderFn, KeepTraderFn),
		--IfNode(function() return inst._brain_switchingtrader end, "Switching Trader",
		--	ActionNode(function() inst._brain_switchingtrader = nil end)),
		ConditionNode(function()
			if inst._brain_switchingtrader then
				inst._brain_switchingtrader = nil
				--Purposely failed FaceEntity in order to switch targets.
				--Use SUCCESS to stop the brain here.
				return true
			end
			return false
		end),
	}, 0.25)
end

--------------------------------------------------------------------------

return {
	InitHomePosition = InitHomePosition,
	GetHomePosition = GetHomePosition,
    ShouldWake = ShouldWake,
    ShouldSleep = ShouldSleep,
	IsAlly = IsAlly,
    Retarget = Retarget,
	FindAOETargetsAtXZ = FindAOETargetsAtXZ,
    KeepTarget = KeepTarget,
    OnAttacked = OnAttacked,
	OnNewCombatTarget = OnNewCombatTarget,
	MakeBefriendable = MakeBefriendable,
	sgTrySetBefriendable = sgTrySetBefriendable,
	sgTryClearBefriendable = sgTryClearBefriendable,
	MakeHealthRegen = MakeHealthRegen,
	WaitForTrader = WaitForTrader,
}
