require "behaviours/wander"
require "behaviours/panic"
require "behaviours/runaway"

local BrainCommon = {}
--------------------------------------------------------------------------

local TIME_TO_SEEK_SALT = 16

local function OnSaltlickPlaced(inst)
    inst._brainsaltlick = nil
    inst:RemoveEventCallback("saltlick_placed", OnSaltlickPlaced)
end

local FINDSALTLICK_MUST_TAGS = { "saltlick" }
local FINDSALTLICK_CANT_TAGS = { "INLIMBO", "fire", "burnt" }

local function FindSaltlick(inst)
    if inst._brainsaltlick == nil or
        not inst._brainsaltlick:IsValid() or
        not inst:HasTag("saltlick") or
        inst._brainsaltlick:IsInLimbo() or
        (inst._brainsaltlick.components.burnable ~= nil and inst._brainsaltlick.components.burnable:IsBurning()) or
        inst._brainsaltlick:HasTag("burnt") then
        local hadsaltlick = inst._brainsaltlick ~= nil
        inst._brainsaltlick = FindEntity(inst, TUNING.SALTLICK_CHECK_DIST, nil, FINDSALTLICK_MUST_TAGS, FINDSALTLICK_CANT_TAGS)
        if inst._brainsaltlick ~= nil then
            if not hadsaltlick then
                inst:ListenForEvent("saltlick_placed", OnSaltlickPlaced)
            end
        elseif hadsaltlick then
            inst:RemoveEventCallback("saltlick_placed", OnSaltlickPlaced)
        end
    end
    return inst._brainsaltlick ~= nil
end

local function WanderFromSaltlickDistFn(inst)
    local t = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("salt") or 0) or nil
    return t ~= nil
        and t < TIME_TO_SEEK_SALT
        and Remap(math.max(TIME_TO_SEEK_SALT * .5, t), TIME_TO_SEEK_SALT * .5, TIME_TO_SEEK_SALT, TUNING.SALTLICK_USE_DIST * .75, TUNING.SALTLICK_CHECK_DIST * .75)
        or TUNING.SALTLICK_CHECK_DIST * .75
end

local function ShouldSeekSalt(inst)
    return inst._brainsaltlick ~= nil
        and inst.components.timer ~= nil
        and (inst.components.timer:GetTimeLeft("salt") or 0) < TIME_TO_SEEK_SALT
end

local function AnchorToSaltlick(inst)
    local node = WhileNode(
        function()
            return FindSaltlick(inst)
        end,
        "Stay Near Salt",
        Wander(inst,
            function()
                return inst._brainsaltlick ~= nil
                    and inst._brainsaltlick:IsValid()
                    and inst._brainsaltlick:GetPosition()
                    or inst:GetPosition()
            end,
            WanderFromSaltlickDistFn)
    )

    local _OnStop = node.OnStop
    node.OnStop = function()
        if inst._brainsaltlick ~= nil then
            inst:RemoveEventCallback("saltlick_placed", OnSaltlickPlaced)
            inst._brainsaltlick = nil
        end
        if _OnStop ~= nil then
            _OnStop(node)
        end
    end

    return node
end

BrainCommon.ShouldSeekSalt = ShouldSeekSalt
BrainCommon.AnchorToSaltlick = AnchorToSaltlick

--------------------------------------------------------------------------

local function ShouldTriggerPanic(inst)
	return (inst.components.health and (inst.components.health.takingfiredamage or inst.components.health:GetLunarBurnFlags() ~= 0))
		or (inst.components.hauntable ~= nil and inst.components.hauntable.panic)
end

BrainCommon.ShouldTriggerPanic = ShouldTriggerPanic
BrainCommon.PanicTrigger = function(inst)
    return WhileNode(function() return ShouldTriggerPanic(inst) end, "PanicTrigger", Panic(inst))
end

--------------------------------------------------------------------------

require("behaviours/avoidelectricfence")
local function ShouldAvoidElectricFence(inst)
    return inst.panic_electric_field ~= nil
end

BrainCommon.ShouldAvoidElectricFence = ShouldAvoidElectricFence
BrainCommon.ElectricFencePanicTrigger = function(inst)
    return WhileNode(function() return ShouldAvoidElectricFence(inst) end, "ElectricShock", AvoidElectricFence(inst))
end

BrainCommon.HasElectricFencePanicTriggerNode = function(inst)
    return inst._has_electric_fence_panic_trigger --Set in AvoidElectricFence
end

--------------------------------------------------------------------------

local function ShouldTriggerPanicShadowCreature(inst)
    return inst._shadow_creature_panic_task ~= nil -- Set by hermitcrabtea_moon_tree_blossom_buff. Expand this to a better system if we do more with panicking shadow creatures
end

BrainCommon.ShouldTriggerPanicShadowCreature = ShouldTriggerPanicShadowCreature
BrainCommon.PanicTriggerShadowCreature = function(inst)
    return WhileNode(function() return ShouldTriggerPanicShadowCreature(inst) end, "PanicTriggerShadowCreature", Panic(inst))
end

--------------------------------------------------------------------------

local function PanicWhenScared(inst, loseloyaltychance, chatty)
    local scareendtime = 0
    local function onepicscarefn(inst, data)
        scareendtime = math.max(scareendtime, data.duration + GetTime() + math.random())
    end
    inst:ListenForEvent("epicscare", onepicscarefn)

    local panicscarednode = Panic(inst)

    if chatty ~= nil then
        panicscarednode = ChattyNode(inst, chatty, panicscarednode)
    end

    if loseloyaltychance ~= nil and loseloyaltychance > 0 then
        panicscarednode = ParallelNode{
            panicscarednode,
            LoopNode({
                WaitNode(3),
                ActionNode(function()
                    local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
                    if leader ~= nil and
                        inst.components.follower:GetLoyaltyPercent() > 0 and
                        TryLuckRoll(leader, loseloyaltychance, LuckFormulas.LoseFollowerOnPanic) then
                        inst.components.follower:SetLeader(nil)
                    end
                end),
            }),
        }
    end

    local scared = false
    panicscarednode = WhileNode(
        function()
            if (GetTime() < scareendtime) ~= scared then
                if inst.components.combat ~= nil then
                    inst.components.combat:SetTarget(nil)
                end
                scared = not scared
            end
            return scared
        end,
        "PanicScared",
        panicscarednode
    )

    local _OnStop = panicscarednode.OnStop
    panicscarednode.OnStop = function()
        inst:RemoveEventCallback("epicscare", onepicscarefn)
        if _OnStop ~= nil then
            _OnStop(panicscarednode)
        end
    end

    return panicscarednode
end

BrainCommon.PanicWhenScared = PanicWhenScared

--------------------------------------------------------------------------

local function IsUnderIpecacsyrupEffect(inst)
    return inst:HasDebuff("ipecacsyrup_buff")
end

BrainCommon.IsUnderIpecacsyrupEffect = IsUnderIpecacsyrupEffect
BrainCommon.IpecacsyrupPanicTrigger = function(inst)
    return WhileNode(function() return BrainCommon.IsUnderIpecacsyrupEffect(inst) end, "IpecacsyrupPanicTrigger", Panic(inst))
end

--------------------------------------------------------------------------
-- Actions: MINE, CHOP, DIG, TILL

local MINE_TAGS = { "MINE_workable" }
local MINE_CANT_TAGS = { "carnivalgame_part", "event_trigger", "waxedplant" }
local CHOP_TAGS = { "CHOP_workable" }
local CHOP_CANT_TAGS = { "carnivalgame_part", "event_trigger", "waxedplant" }
local DIG_ONEOF_TAGS = { "farm_debris", "tree" }
local DIG_CANT_TAGS = { "carnivalgame_part", "event_trigger", "waxedplant" }
local SOILMUST = { "soil" }
local SOILMUSTNOT = { "merm_soil_blocker", "farm_debris", "NOBLOCK" }

--------------------------------

local function GetLeader(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

--------------------------------

local function IsDeciduousTreeMonster(guy)
    return guy.monster and guy.prefab == "deciduoustree"
end

local function FindDeciduousTreeMonster(inst, finddist)
    return FindEntity(inst, finddist / 3, IsDeciduousTreeMonster, CHOP_TAGS)
end

--------------------------------

local function IsDigValid(guy, inst) -- we include trees, so make sure it's a diggable tree (i.e. stump)
    return guy.components.workable ~= nil and guy.components.workable:GetWorkAction() == ACTIONS.DIG
end

local function CollectTillSites(inst, digsites, tile)
    local cent = Vector3(TheWorld.Map:GetTileCenterPoint(tile[1], 0, tile[2]))
    local soils = TheSim:FindEntities(cent.x, 0, cent.z, 2, SOILMUST, SOILMUSTNOT)

    if #soils < 9 then
        local dist = 4/3
        for dx=-dist,dist,dist do
            local dobreak = false
            for dz=-dist,dist,dist do
                local localsoils = TheSim:FindEntities(cent.x+dx,0, cent.z+dz, 0.21, SOILMUST, SOILMUSTNOT)
                if #localsoils < 1 and TheWorld.Map:CanTillSoilAtPoint(cent.x+dx,0,cent.z+dz) then
                    table.insert(digsites,{pos = Vector3(cent.x+dx,0,cent.z+dz), tile = tile })
                end
            end
        end
    end

    return digsites
end

local function FindTillPosition(inst)
    local tiles = {}

    if not inst.digtile then
        -- collect garden tiles in a 9x9 grid
        local RANGE = 4
        local pos = Vector3(inst.Transform:GetWorldPosition())

        for x=-RANGE,RANGE,1 do
            for z=-RANGE,RANGE,1 do
                local tx = pos.x + (x*4)
                local tz = pos.z + (z*4)
                local tile = TheWorld.Map:GetTileAtPoint(tx, 0, tz)
                if tile == WORLD_TILES.FARMING_SOIL then
                    table.insert(tiles,{tx,tz})
                end
            end
        end
    else
        table.insert(tiles,inst.digtile)
    end

    -- find diggable places in those tiles.
    local digsites = {}
    for i,tile in ipairs(tiles)do
        digsites = CollectTillSites(inst,digsites, tile)
    end

    if #digsites > 0 then
        local pos = digsites[math.random(1,#digsites)].pos
        inst.digtile = digsites[math.random(1,#digsites)].tile
        return pos
    end

    inst.digtile = nil
end

-----------

local AssistLeaderDefaults = {
    MINE = {
        Starter = function(inst, leaderdist, finddist)
            local leader = GetLeader(inst)
            return leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("mining")
        end,
        KeepGoing = function(inst, leaderdist, finddist)
            local leader = GetLeader(inst)
            return leader ~= nil and inst:IsNear(leader, leaderdist)
        end,
        FindNew = function(inst, leaderdist, finddist)
            local target = FindEntity(inst, finddist, nil, MINE_TAGS, MINE_CANT_TAGS)

            if target == nil then
                local leader = GetLeader(inst)
                if leader then
                    target = FindEntity(leader, finddist, nil, MINE_TAGS, MINE_CANT_TAGS)
                end
            end

            if target ~= nil then
                return BufferedAction(inst, target, ACTIONS.MINE)
            end
        end,
    },
    CHOP = {
        Starter = function(inst, finddist)
            if inst.tree_target ~= nil then
                return true
            end
            local leader = GetLeader(inst)
            return (leader ~= nil and leader.sg ~= nil and leader.sg:HasAnyStateTag("chopping", "spinning"))
                or FindDeciduousTreeMonster(inst, finddist) ~= nil
        end,
        KeepGoing = function(inst, leaderdist, finddist)
            if inst.tree_target ~= nil then
                return true
            end
            local leader = GetLeader(inst)
            return (leader ~= nil and inst:IsNear(leader, leaderdist))
                or FindDeciduousTreeMonster(inst, finddist) ~= nil
        end,
        FindNew = function(inst, leaderdist, finddist)
            local target = FindEntity(inst, finddist, nil, CHOP_TAGS, CHOP_CANT_TAGS)

            if target == nil then
                local leader = GetLeader(inst)
                if leader then
                    target = FindEntity(leader, finddist, nil, CHOP_TAGS, CHOP_CANT_TAGS)
                end
            end

            if target ~= nil then
                if inst.tree_target ~= nil then
                    target = inst.tree_target
                    inst.tree_target = nil
                else
                    target = FindDeciduousTreeMonster(inst, finddist) or target
                end

                return BufferedAction(inst, target, ACTIONS.CHOP)
            end
        end,
    },
    DIG = {
        Starter = function(inst, finddist)
            if inst.stump_target ~= nil then
                return true
            end
            local leader = GetLeader(inst)
            return (leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("digging"))
        end,
        KeepGoing = function(inst, leaderdist, finddist)
            if inst.stump_target then
                return true
            end
            local leader = GetLeader(inst)
            return leader ~= nil and inst:IsNear(leader, leaderdist)
        end,
        FindNew = function(inst, leaderdist, finddist)
            local target = FindEntity(inst, finddist, IsDigValid, nil, DIG_CANT_TAGS, DIG_ONEOF_TAGS)

            if target == nil then
                local leader = GetLeader(inst)
                if leader then
                    target = FindEntity(leader, finddist, IsDigValid, nil, DIG_CANT_TAGS, DIG_ONEOF_TAGS)
                end
            end

            if target ~= nil then
                if inst.stump_target ~= nil then
                    target = inst.stump_target
                    inst.stump_target = nil
                end

                return BufferedAction(inst, target, ACTIONS.DIG)
            end
        end,
    },
    TILL = {
        Starter = function(inst, finddist)
            local leader = GetLeader(inst)
            return (leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("tilling"))
        end,
        KeepGoing = function(inst, leaderdist, finddist)
            local leader = GetLeader(inst)
            return leader ~= nil and inst:IsNear(leader, leaderdist)
        end,
        FindNew = function(inst, leaderdist, finddist)
            local pos = FindTillPosition(inst)
            local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
            if pos then
                pos = Vector3(pos.x -0.02 + math.random()*0.04,0,pos.z -0.02 + math.random()*0.04)

                local marker = SpawnPrefab("merm_soil_marker")
                marker.Transform:SetPosition(pos.x, pos.y, pos.z)
                return BufferedAction(inst, nil, ACTIONS.TILL, tool, pos)
            end
        end,
    },
}
-- Mod support access.
BrainCommon.AssistLeaderDefaults = AssistLeaderDefaults

-- NOTES(JBK): This helps followers do a task once they see the leader is doing an act.
--            Since actions are very context sensitive, there are defaults above to help clarify context.
local function NodeAssistLeaderDoAction(self, parameters)
    local action = parameters.action
    local defaults = AssistLeaderDefaults[action]

    local starter = parameters.starter or defaults.Starter
    local keepgoing = parameters.keepgoing or defaults.KeepGoing
    local finder = parameters.finder or defaults.FindNew

    local keepgoing_leaderdist = parameters.keepgoing_leaderdist or TUNING.FOLLOWER_HELP_LEADERDIST
    local finder_finddist = parameters.finder_finddist or TUNING.FOLLOWER_HELP_FINDDIST

    local function ifnode()
        return starter(self.inst, keepgoing_leaderdist, finder_finddist)
    end
    local function whilenode()
        return keepgoing(self.inst, keepgoing_leaderdist, finder_finddist)
    end
    local function findnode()
        return finder(self.inst, keepgoing_leaderdist, finder_finddist)
    end
    local looper
    if parameters.chatterstring then
        looper = LoopNode{ConditionNode(whilenode), ChattyNode(self.inst, parameters.chatterstring, DoAction(self.inst, findnode, "DoAction_Chatty", parameters.shouldrun, 3))}
    else
        looper = LoopNode{ConditionNode(whilenode), DoAction(self.inst, findnode, "DoAction_NoChatty", parameters.shouldrun, 3)}
    end

    return IfThenDoWhileNode(ifnode, whilenode, action, looper)
end

BrainCommon.NodeAssistLeaderDoAction = NodeAssistLeaderDoAction

--------------------------------------------------------------------------
-- NOTES(JBK): This helps followers pickup items for a PLAYER leader.
--            They pickup if they are able to, then give them to their leader, or drop them onto the ground if unable to.

local function Unignore(inst, sometarget, ignorethese)
    ignorethese[sometarget] = nil
end
local function IgnoreThis(sometarget, ignorethese, leader, worker)
    if ignorethese[sometarget] and ignorethese[sometarget].task ~= nil then
        ignorethese[sometarget].task:Cancel()
        ignorethese[sometarget].task = nil
    else
        ignorethese[sometarget] = {worker = worker,}
    end
    ignorethese[sometarget].task = leader:DoTaskInTime(5, Unignore, sometarget, ignorethese)
end

local function PickUpAction(inst, pickup_range, pickup_range_local, furthestfirst, positionoverride, ignorethese, wholestacks, allowpickables, custom_pickup_filter, itemoverridefn)
    local activeitem = inst.components.inventory:GetActiveItem()
    if activeitem ~= nil then
        inst.components.inventory:DropItem(activeitem, true, true)
        if ignorethese ~= nil then
            if ignorethese[activeitem] and ignorethese[activeitem].task ~= nil then
                ignorethese[activeitem].task:Cancel()
                ignorethese[activeitem].task = nil
            end
            ignorethese[activeitem] = nil
        end
    end
    local onlytheseprefabs
    if wholestacks then
        local item = inst.components.inventory:GetFirstItemInAnySlot()
        if item ~= nil then
            if (item.components.stackable == nil or item.components.stackable:IsFull()) then
                return nil
            end
            onlytheseprefabs = {[item.prefab] = true}
        end
    elseif inst.components.inventory:IsFull() then
        return nil
    end

    local leader = GetLeader(inst)
    if leader == nil then
        return nil
    end

    local container = leader.components.inventory or leader.components.container
    if container == nil or (leader.components.inventory and not container:IsOpenedBy(leader)) then -- Inventory existing and it being opened so the action can work.
        return nil
    end

    local item, pickable
    if itemoverridefn then
        item = itemoverridefn(inst, leader)
        pickable = item and item:HasTag("pickable") or nil
    else
        if pickup_range_local ~= nil then
            item, pickable = FindPickupableItem(leader, pickup_range_local, furthestfirst, inst:GetPosition(), ignorethese, onlytheseprefabs, allowpickables, inst, custom_pickup_filter)
        end
        if item == nil then
            item, pickable = FindPickupableItem(leader, pickup_range, furthestfirst, positionoverride, ignorethese, onlytheseprefabs, allowpickables, inst, custom_pickup_filter)
        end
    end
    if item == nil then
        return nil
    end

    if ignorethese ~= nil then
        IgnoreThis(item, ignorethese, leader, inst)
    end

    return BufferedAction(inst, item, item.components.trap ~= nil and ACTIONS.CHECKTRAP or pickable and ACTIONS.PICK or ACTIONS.PICKUP)
end

local function GiveAction(inst)
    local leader = GetLeader(inst)
    local container = leader and (leader.components.inventory or leader.components.container) or nil
    local item = inst.components.inventory:GetFirstItemInAnySlot() or inst.components.inventory:GetActiveItem() -- This is intentionally backwards to give the bigger stacks first.
    if leader == nil or item == nil then
        return nil
    end

    if container == nil or (leader.components.inventory and not container:IsOpenedBy(leader)) then -- Inventory existing and it being opened so the action can work.
        return nil
    end

    if container:CanAcceptCount(item, 1) <= 0 then
        return nil
    end

    local action
    if leader.isplayer then
        action = ACTIONS.GIVEALLTOPLAYER
    elseif leader.components.trader then
        action = ACTIONS.GIVE
    elseif leader.components.container then
        action = ACTIONS.STORE
    end

    if not action then
        return nil
    end

    return BufferedAction(inst, leader, action, item)
end

local function DropAction(inst)
    local leader = GetLeader(inst)
    local item = inst.components.inventory:GetFirstItemInAnySlot()
    if leader == nil or item == nil then
        return nil
    end

    local ba = BufferedAction(inst, leader, ACTIONS.DROP, item)
    ba.options.wholestack = true
    return ba
end

local function AlwaysTrue() return true end
local function NodeAssistLeaderPickUps(self, parameters)
    local cond = parameters.cond or AlwaysTrue
    local pickup_range = parameters.range
    local pickup_range_local = parameters.range_local
	local give_cond = parameters.give_cond
	local give_range_sq = parameters.give_range ~= nil and parameters.give_range * parameters.give_range or nil
    local furthestfirst = parameters.furthestfirst
	local positionoverridefn = type(parameters.positionoverride) == "function" and parameters.positionoverride or nil
	local positionoverride = positionoverridefn == nil and parameters.positionoverride or nil
    local ignorethese = parameters.ignorethese
    local wholestacks = parameters.wholestacks
    local allowpickables = parameters.allowpickables
    local custom_pickup_filter = parameters.custom_pickup_filter
    local itemoverridefn = parameters.itemoverridefn

    local function CustomPickUpAction(inst)
        local ba = PickUpAction(inst, pickup_range, pickup_range_local, furthestfirst, positionoverridefn ~= nil and positionoverridefn(inst) or positionoverride, ignorethese, wholestacks, allowpickables, custom_pickup_filter, itemoverridefn)
        if ba then
            ba:AddFailAction(function()
                inst:PushEvent("braincommon_pickup_failed", ba)
            end)
            ba:AddSuccessAction(function()
                inst:PushEvent("braincommon_pickup_success", ba)
            end)
        end
        return ba
    end

	local give_cond_fn = give_range_sq ~= nil and
		function()
            if give_cond and not give_cond() then
                return false
            end
            
            local leader = GetLeader(self.inst)
			return leader ~= nil and leader:GetDistanceSqToPoint(positionoverridefn ~= nil and positionoverridefn(self.inst) or positionoverride or self.inst:GetPosition()) < give_range_sq
		end
		or give_cond
		or AlwaysTrue

    return PriorityNode({
        WhileNode(cond, "BC KeepPickup",
            DoAction(self.inst, CustomPickUpAction, "BC CustomPickUpAction", true)),
        WhileNode(give_cond_fn, "BC Should Bring To Leader",
			PriorityNode({
				DoAction(self.inst, GiveAction, "BC GiveAction", true),
				DoAction(self.inst, DropAction, "BC DropAction", true),
			}, .25)),
    },.25)
end
BrainCommon.NodeAssistLeaderPickUps = NodeAssistLeaderPickUps

--------------------------------------------------------------------------

local SEE_POSSESSABLE_CHASSIS_DIST = 10
local POSESSABLE_CHASSIS_TAGS = { "possessable_chassis" }
local NO_POSSESSABLE_CHASSIS_TAGS = { "NOCLICK" }

local function IsPossessableChassisValid(guy, inst)
    return guy.components.linkeditem == nil or guy.components.linkeditem:GetOwnerInst() ~= nil
end

local function SelectPossessableChassis(self)
	self.possessable_chassis = FindEntity(self.inst, SEE_POSSESSABLE_CHASSIS_DIST, IsPossessableChassisValid, POSESSABLE_CHASSIS_TAGS, NO_POSSESSABLE_CHASSIS_TAGS)
	return self.possessable_chassis ~= nil
end

local function CheckPossessableChassis(self)
	return self.possessable_chassis:IsValid() and self.possessable_chassis:HasTag("possessable_chassis")
end

local function GetPossessableChassisPos(inst)
    if not inst.brain then -- Just in case??
        return
    end

	return CheckPossessableChassis(inst.brain) and inst.brain.possessable_chassis:GetPosition() or nil
end

local POSSESS_DIST = .5
local POSSESS_DIST_INNER = POSSESS_DIST - .1
local function PossessChassis(self, update_rate)
    return IfNode(function() return SelectPossessableChassis(self) end, "possess chassis",
			PriorityNode({
                FailIfSuccessDecorator(Leash(self.inst, GetPossessableChassisPos, POSSESS_DIST, POSSESS_DIST_INNER, true)),
				IfNode(function() return CheckPossessableChassis(self) end, "possess",
					ActionNode(function() self.inst:PushEventImmediate("possess_chassis", { target = self.possessable_chassis }) end)),
				FaceEntity(self.inst,
					function() return self.possessable_chassis end,
					function() return CheckPossessableChassis(self) end),
			}, update_rate))
end

BrainCommon.PossessChassisNode = PossessChassis

--------------------------------------------------------------------------

local function GetRunAwayTarget(inst)
    return FindClosestQueenTorch(inst)
end
local RUN_AWAY_QUEEN_TORCH_DATA = { getfn = GetRunAwayTarget }
local RUN_AWAY_QUEEN_TORCH_DIST = 10
local STOP_RUN_AWAY_QUEEN_TORCH_DIST = 15

local function RunAwayFromQueenTorch(inst)
    return RunAway(inst, RUN_AWAY_QUEEN_TORCH_DATA, RUN_AWAY_QUEEN_TORCH_DIST, STOP_RUN_AWAY_QUEEN_TORCH_DIST)
end

BrainCommon.RunAwayFromQueenTorch = RunAwayFromQueenTorch

return BrainCommon
