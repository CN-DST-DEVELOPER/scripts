require "behaviours/doaction"
require "behaviours/faceentity"
require "behaviours/follow"
require "behaviours/runaway"
local WobyCommon = require("prefabs/wobycommon")

-----------------------------------------------------------------------------------------------------------------------------------

local COMBAT_TOO_CLOSE_DIST = 10 -- From wobybigbrain.lua

---------------------------------------------------------------------------------------------------------------------------------------------

local function OwnerIsClose(inst, distance)
    local owner = inst._playerlink

    return owner ~= nil and owner:IsNear(inst, distance)
end

local function IsWheelOpen(inst)
	return inst.woby_commands_classified and inst.woby_commands_classified:IsClientWheelOpen()
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function FindPickupableItem_ExtraFilter(inst, item, owner)
    if item:HasTag("outofreach") then
        return false -- Don't try to pick up cave_hole objects.
    end

    if not (item.components.inventoryitem ~= nil and item.components.inventoryitem.is_landed) then
        return -- No non items or moving items.
    end

    if item.components.trap ~= nil then
        return false -- Don't interact with traps at all.
    end

    if item.Physics ~= nil and item.Physics:IsActive() and checkbit(item.Physics:GetCollisionMask(), inst.Physics:GetCollisionGroup()) then
        return -- No items with physics and that we collide with, like pickable creatures, moles...
    end

    if not item:IsOnPassablePoint() or item:GetCurrentPlatform() ~= inst:GetCurrentPlatform() then
        return false
    end

    -- Priorize running away, don't try to pick up items where we can't go.
    if inst.brain.runawayfrom ~= nil and inst.brain.runawayfrom:IsValid() and item:IsNear(inst.brain.runawayfrom, COMBAT_TOO_CLOSE_DIST) then
        return false
    end

    return true
end

local function DoPickUpAction(inst)
    local priorityprefabs = {}

    local items = inst.components.container:GetAllItems()

    for i, item in ipairs(items) do
        priorityprefabs[item.prefab] = true
    end

    -- NOTES(DiogoW): furthestfirst on purpose, Woby likes to run a bit before fetching.
    local item =
           FindPickupableItem(inst._playerlink, TUNING.SKILLS.WALTER.FETCH_PRIORITY_MAX_DISTANCE,   true, nil,                nil, priorityprefabs, false, inst, FindPickupableItem_ExtraFilter, inst.components.container)
        or FindPickupableItem(inst._playerlink, TUNING.SKILLS.WALTER.FETCH_DEFAULT_MAX_DISTANCE,    true, nil,                nil, nil,             false, inst, FindPickupableItem_ExtraFilter, inst.components.container)

    if item ~= nil then
        local action = BufferedAction(inst, item, ACTIONS.WOBY_PICKUP)

        action:AddSuccessAction(inst._onsuccessfulpraisableaction)

        return action
    end
end

local function HasPickUpBehavior(inst)
    local skilltreeupdater = inst._playerlink ~= nil and inst._playerlink.components.skilltreeupdater or nil

    return skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_woby_itemfetcher")
end

local function IsAllowedToPickUp(inst)
    return inst.woby_commands_classified ~= nil and inst.woby_commands_classified:ShouldPickup()
end

local function FetchingActionNode(inst)
    return WhileNode(function() return IsAllowedToPickUp(inst) and HasPickUpBehavior(inst) end, "HasFetchSkill", DoAction(inst, DoPickUpAction, "DoPickUpAction", true))
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function IsAllowedToRetrieveAmmo(inst)
    local equip = inst._playerlink.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

    return equip ~= nil and
        equip:HasTag("slingshot") and
        equip.components.container ~= nil and
        equip.components.container:HasItemWithTag("recoverableammo", 1)
end

local function GetRecoverableAmmoPickUpAction(inst)
    local onlytheseprefabs = {}

    local equip = inst._playerlink.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local items = equip.components.container:GetItemsWithTag("recoverableammo")

    for i, item in ipairs(items) do
        onlytheseprefabs[item.prefab] = true
    end

    -- NOTES(DiogoW): furthestfirst on purpose, Woby likes to run a bit before fetching.
    local item = FindPickupableItem(inst._playerlink, TUNING.SKILLS.WALTER.FETCH_PRIORITY_MAX_DISTANCE, true, nil, nil, onlytheseprefabs, false, inst, FindPickupableItem_ExtraFilter, inst.components.container)

    if item == nil then
        item = FindPickupableItem(inst._playerlink, TUNING.SKILLS.WALTER.FETCH_PRIORITY_MAX_DISTANCE/2, true, inst:GetPosition(), nil, onlytheseprefabs, false, inst, FindPickupableItem_ExtraFilter, inst.components.container)
    end

    if item ~= nil then
        local action = BufferedAction(inst, item, ACTIONS.WOBY_PICKUP)

        action:AddSuccessAction(inst._onsuccessfulpraisableaction)

        return action
    end
end

local function IsRecoverableAmmo(item)
    return item:HasTag("recoverableammo")
end

local function ReturnRecoverableAmmoAction(inst)
    local leader = inst._playerlink
    local leaderinv    = leader ~= nil and leader.components.inventory or nil
    local leadertrader = leader ~= nil and leader.components.trader or nil

    local item = inst.components.container:FindItem(IsRecoverableAmmo)

    if leaderinv == nil or leadertrader == nil or item == nil then
        return nil
    end

    if not leaderinv:IsOpenedBy(leader) or leaderinv:CanAcceptCount(item) <= 0 or not leadertrader:AbleToAccept(item, inst) then
        return nil
    end

    local act = BufferedAction(inst, leader, ACTIONS.GIVEALLTOPLAYER, item)

    act.distance = leader:GetPhysicsRadius(0) + .5 + (inst:HasTag("largecreature") and 1 or 0)
    act:AddSuccessAction(inst._onsuccessfulpraisableaction)

    return act
end

local function RetrieveAmmoNode(inst)
    return WhileNode(function() return HasPickUpBehavior(inst) and IsAllowedToRetrieveAmmo(inst) end, "HasPickUpBehavior",
        PriorityNode({
            WhileNode(function() return OwnerIsClose(inst, TUNING.SKILLS.WALTER.PRIORIZE_AMMO_RETURN_ACTION_DIST) end, "PriorizeReturningAmmo", DoAction(inst, ReturnRecoverableAmmoAction, "ReturnRecoverableAmmoAction", true)),
            WhileNode(function() return IsAllowedToPickUp(inst) end, "IsAllowedToPickUp", DoAction(inst, GetRecoverableAmmoPickUpAction, "RetrieveAmmoNode", true)),
            DoAction(inst, ReturnRecoverableAmmoAction, "ReturnRecoverableAmmoAction", true),
        },.25)
    )
end

-- Same as RetrieveAmmoNode, but won't give the ammo back.
local function PickUpAmmoNode(inst)
    return WhileNode(function() return HasPickUpBehavior(inst) and IsAllowedToPickUp(inst) and IsAllowedToRetrieveAmmo(inst) end, "HasFetchSkill",
       DoAction(inst, GetRecoverableAmmoPickUpAction, "PickUpAmmoNode", true)
    )
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function DoForagerAction(inst)
    local target = inst:GetForagerTarget()

    if target ~= nil and target:IsValid() then
        local action = BufferedAction(inst, target, ACTIONS.WOBY_PICK)

        local _onaction = function () inst:RemoveCurrentForagerTarget() end

        action:AddSuccessAction(_onaction)
        action:AddFailAction(_onaction)

        return action
    end
end

local function HasForagingBehavior(inst)
    local skilltreeupdater = inst._playerlink ~= nil and inst._playerlink.components.skilltreeupdater or nil

    return skilltreeupdater ~= nil and skilltreeupdater:IsActivated("walter_woby_foraging")
end

local function IsAllowedToForager(inst)
    return inst.woby_commands_classified ~= nil and inst.woby_commands_classified:ShouldForage()
end

local function ForagerNode(inst)
    return WhileNode(function() return IsAllowedToForager(inst) and HasForagingBehavior(inst) end, "HasForagerSkill", DoAction(inst, DoForagerAction, "DoForagerAction", true))
end

---------------------------------------------------------------------------------------------------------------------------------------------

local COURIER_INTERACT_DISTANCE = TUNING.SKILLS.WALTER.COURIER_CHEST_DETECTION_RADIUS
local COURIER_INTERACT_DISTANCE_SQ = COURIER_INTERACT_DISTANCE * COURIER_INTERACT_DISTANCE
local COURIER_SIT_DISTANCE_MAX = COURIER_INTERACT_DISTANCE
local COURIER_SIT_DISTANCE_MIN = 4

local function GetCourierData(inst)
    return inst.woby_commands_classified ~= nil and inst.woby_commands_classified:GetCourierData() or nil
end

local function ShouldSit(inst)
    local shouldsit = false
    if inst.woby_commands_classified ~= nil then
        shouldsit = inst.woby_commands_classified:ShouldSit()
        if inst.woby_commands_classified.outfordelivery:value() then
            shouldsit = false
        end
    end
    return shouldsit
end

local function StartSitting(inst)
    local shouldsit = ShouldSit(inst)

    if shouldsit then
        inst:PushEvent("start_sitting")
    end

    return shouldsit
end

local function KeepSitting(inst)
    local keepsitting = ShouldSit(inst)
    local iscower = inst.brain ~= nil and inst.brain._hasavoidcombattarget ~= nil and inst.brain:_hasavoidcombattarget()

    if not keepsitting then
        inst:PushEvent("stop_sitting")

    elseif iscower ~= inst.sg:HasStateTag("cower") then
        -- We need to switch states!
        inst:PushEvent("start_sitting", { iscower=iscower })

    elseif not inst.sg:HasStateTag("sitting") then
        -- We left the sitting state somehow! Go back to it...
        inst:PushEvent("start_sitting", { iscower=iscower })

    elseif inst._playerlink ~= nil and inst.sg:HasStateTag("canrotate") then
        inst:ForceFacePoint(inst._playerlink.Transform:GetWorldPosition())
    end

    return keepsitting
end

local function SitStillNode(inst)
    return StandStill(inst, StartSitting, KeepSitting)
end

local function GetCourierHome(inst)
    local courierdata = GetCourierData(inst)
    return courierdata and courierdata.destpos or nil
end

local function StoreItemAction(inst)
    local distance = (inst:GetPosition() - GetCourierHome(inst)):Length()
    local item, container
    for i = 1, inst.components.container:GetNumSlots() do
        item = inst.components.container:GetItemInSlot(i)
        if item then
            container = WobyCommon.WobyCourier_FindValidContainerForItem(inst, item)
            if container then
                break
            end
        end
    end

    if container == nil then
        inst.woby_commands_classified.outfordelivery:set(false)
        return nil
    end

    return BufferedAction(inst, container, ACTIONS.STORE, item)
end

local function CourierNode(inst)
    return WhileNode(function() return GetCourierData(inst) ~= nil end, "HasCourierData",
        PriorityNode({
            Leash(inst, GetCourierHome, COURIER_SIT_DISTANCE_MAX, COURIER_SIT_DISTANCE_MIN, true),
            SequenceNode({
                DoAction(inst, StoreItemAction, "StoreItem", true, 3),
                WaitNode(1),
            }),
        })
    )
end

---------------------------------------------------------------------------------------------------------------------------------------------

local INTERACT_ACTIONS =
{
	[ACTIONS.FEED]		= true,
	[ACTIONS.PET]		= true,
	[ACTIONS.RUMMAGE]	= true,
	[ACTIONS.STORE]		= true,
}

local function GetPerformerActionOnMe(inst, performer)
	local target
	local act = performer:GetBufferedAction()
	if act then
		target = act.target
		act = act.action
	elseif performer.components.playercontroller then
		act, target = performer.components.playercontroller:GetRemoteInteraction()
	end
	return target == inst and act or nil
end

local function IsTryingToPerformAction(inst, performer, action)
	return GetPerformerActionOnMe(inst, performer) == action
end

local function TryingToInteractWithWoby(inst, performer)
	return INTERACT_ACTIONS[GetPerformerActionOnMe(inst, performer)]
		or inst.components.container:IsOpenedBy(performer)
end

local function GetWalterInteractionFn(inst)
   local leader = inst.components.follower ~= nil and inst.components.follower.leader
    if leader ~= nil and TryingToInteractWithWoby(inst, leader) then
        return leader
    end

    return nil
end

local function KeepGenericInteractionFn(inst, target)
    return TryingToInteractWithWoby(inst, target)
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function WatchingMinigame(inst)
    return (inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil) and inst.components.follower.leader.components.minigame_participator:GetMinigame() or nil
end
local function WatchingMinigame_MinDist(inst)
    local minigame = WatchingMinigame(inst)

    return minigame ~= nil and minigame.components.minigame.watchdist_min or 0
end

local function WatchingMinigame_TargetDist(inst)
    local minigame = WatchingMinigame(inst)

    return minigame ~= nil and minigame.components.minigame.watchdist_target or 0
end

local function WatchingMinigame_MaxDist(inst)
    local minigame = WatchingMinigame(inst)

    return minigame ~= nil and minigame.components.minigame.watchdist_max or 0
end

local function WatchingMinigameNode(inst)
    return WhileNode(function() return WatchingMinigame(inst) end, "Watching Game",
        PriorityNode{
			WhileNode(function() return IsWheelOpen(inst) end, "Wheel Open",
				FaceEntity(inst, WatchingMinigame, WatchingMinigame)),
			Follow(inst, WatchingMinigame, WatchingMinigame_MinDist, WatchingMinigame_TargetDist, WatchingMinigame_MaxDist),
			RunAway(inst, "minigame_participator", 5, 7),
			FaceEntity(inst, WatchingMinigame, WatchingMinigame),
        }, 0.1)
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function RecallNode(inst, follownode)
	return WhileNode(function() return inst.woby_commands_classified and inst.woby_commands_classified:IsRecalled() end, "recalled",
		PriorityNode({
			SequenceNode{
				ParallelNodeAny{
					follownode,
					SequenceNode{
						ConditionWaitNode(function()
							local leader = inst.components.follower:GetLeader()
							return leader == nil or leader:IsNear(inst, 8)
						end),
						WaitNode(4),
					},
					WaitNode(10),
				},
				ConditionNode(function()
					if inst.woby_commands_classified then
						inst.woby_commands_classified:CancelRecall()
					end
					return false
				end),
			},
			SequenceNode{
				WaitNode(1.25),
				ConditionNode(function()
					if inst.woby_commands_classified then
						inst.woby_commands_classified:CancelRecall()
					end
					return false
				end),
			},
		}, 0.25))
end

---------------------------------------------------------------------------------------------------------------------------------------------

return {
    HasPickUpBehavior = HasPickUpBehavior,
    DoPickUpAction = DoPickUpAction,

    RetrieveAmmoNode = RetrieveAmmoNode,
    PickUpAmmoNode = PickUpAmmoNode,
    FetchingActionNode = FetchingActionNode,
    ForagerNode = ForagerNode,
    SitStillNode = SitStillNode,
    CourierNode = CourierNode,

    IsTryingToPerformAction  = IsTryingToPerformAction,
    TryingToInteractWithWoby = TryingToInteractWithWoby,
    GetWalterInteractionFn   = GetWalterInteractionFn,
    KeepGenericInteractionFn = KeepGenericInteractionFn,

    WatchingMinigameNode = WatchingMinigameNode,
	RecallNode = RecallNode,

	IsWheelOpen = IsWheelOpen,
}
