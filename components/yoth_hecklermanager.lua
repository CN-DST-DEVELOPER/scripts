--------------------------------------------------------------------------
--[[ yoth_hecklermanager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "Year of the Horse Heckler Manager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local HECKLER_TIMERS =
{
    RETURN = "heckler_return", -- Time until heckler returns to land on a shrine
    LEAVE = "heckler_leave", -- Time until heckler leaves and flys away from a shrine
}

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _world = TheWorld

local _charlie_stage = nil
local _hecklerreservation = nil -- shrine
local _playbillgiven = nil -- Has the heckler helper given the play bill?

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function GetHecklerLeaveTime()
    return TUNING.YOTH_HECKLER_SHRINE_LEAVE_BASE + ( math.random() * TUNING.YOTH_HECKLER_SHRINE_LEAVE_VARIANCE )
end

local function GetHecklerReturnTime()
    if not _playbillgiven then
        return 2.5 + math.random() * 1
    end
    return TUNING.YOTH_HECKLER_SHRINE_RETURN_BASE + ( math.random() * TUNING.YOTH_HECKLER_SHRINE_RETURN_VARIANCE )
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function TryLandHecklerOnRandomKnightShrine()
    if _world.components.yoth_knightmanager and self:CanHecklerLand() then
        local shrines = _world.components.yoth_knightmanager:GetActiveKnightShrines()
        local keys = shuffledKeys(shrines)
        for _, shrine in ipairs(keys) do
            if shrine.components.prototyper and shrine.components.prototyper.on then
                local success = self:TryHecklerLand(shrine)
                if success then
                    break
                end
            end
        end
    end
end

local function OnCharlieStagePlayBegun(stage)
    if _hecklerreservation then
        self:TryHecklerFlyAway(_hecklerreservation, "SHRINE_LEAVE_PLAY")
    end
end

local function OnCharlieStagePlayEnded(stage)
    -- after remove_progress_tags task in stageactingprop.lua
    stage:DoTaskInTime(3, TryLandHecklerOnRandomKnightShrine)
end

local function UnregisterCharlieStage(stage)
    _charlie_stage = nil
    inst:RemoveEventCallback("onremove", UnregisterCharlieStage, stage)
    inst:RemoveEventCallback("play_begun", OnCharlieStagePlayBegun, stage)
    inst:RemoveEventCallback("play_ended", OnCharlieStagePlayEnded, stage)
end

local function OnRegisterCharlieStage(src, stage)
    if _charlie_stage then -- Multiple stages not supported but let's clear the last one in case.
        UnregisterCharlieStage(_charlie_stage)
    end
    --
    _charlie_stage = stage
    inst:ListenForEvent("onremove", UnregisterCharlieStage, stage)
    inst:ListenForEvent("play_begun", OnCharlieStagePlayBegun, stage)
    inst:ListenForEvent("play_ended", OnCharlieStagePlayEnded, stage)
end

local function OnTimerDone(inst, data)
    if data.name == HECKLER_TIMERS.RETURN then
        TryLandHecklerOnRandomKnightShrine()
    elseif data.name == HECKLER_TIMERS.LEAVE then
        if _hecklerreservation then
            self:TryHecklerFlyAway(_hecklerreservation)
        end
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------


--Register events
inst:ListenForEvent("ms_register_charlie_stage", OnRegisterCharlieStage, _world)

inst:ListenForEvent("timerdone", OnTimerDone, _world)

--------------------------------------------------------------------------
--[[ Post initialization ]]
--------------------------------------------------------------------------



--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

-- Simple system for having one heckler available to land on a Knight shrine at a time
function self:IsHecklerAvailable()
    return not _hecklerreservation
end

function self:ShrineHasHeckler(shrine)
    return _hecklerreservation == shrine
end

function self:ReserveHecklerToShrine(shrine)
    _hecklerreservation = shrine
end

function self:UnreserveHecklerFromShrine(shrine)
    _hecklerreservation = nil
end

function self:HecklerReturnTimerExists()
    return _world.components.timer:TimerExists(HECKLER_TIMERS.RETURN)
end

function self:CanHecklerLand()
    if _charlie_stage and _charlie_stage:HasTag("play_in_progress") then
        return false
    end

    if _world.components.yoth_knightmanager ~= nil and not _world.components.yoth_knightmanager:IsKnightShrineActive() then
        return false
    end

    return self:IsHecklerAvailable() and not self:HecklerReturnTimerExists()
end

function self:TryHecklerLand(shrine)
    if self:CanHecklerLand() then
        self:ReserveHecklerToShrine(shrine)
        _world.components.timer:StartTimer(HECKLER_TIMERS.LEAVE, GetHecklerLeaveTime())
        shrine.heckler:PushEventImmediate("arrive")
        return true
    end

    return false
end

function self:TryHecklerFlyAway(shrine, overrideleaveline)
    if _hecklerreservation == shrine then
        local leave_line =
            overrideleaveline or
            (shrine.components.burnable and shrine.components.burnable:IsBurning() and "SHRINE_BURN") or
            (shrine.was_hammered and "SHRINE_HIT") or
            "SHRINE_LEAVE"
        shrine.heckler.components.talker:Say(STRINGS.HECKLERS_YOTH[leave_line][math.random(#STRINGS.HECKLERS_YOTH[leave_line])])
        _world.components.timer:StopTimer(HECKLER_TIMERS.LEAVE)
        _world.components.timer:StartTimer(HECKLER_TIMERS.RETURN, GetHecklerReturnTime())
        shrine.heckler:PushEventImmediate("leave")
        self:UnreserveHecklerFromShrine(shrine)
        return true
    end

    return false
end

function self:HasGivenPlaybill()
    return _playbillgiven
end

function self:SetPlaybillGiven()
    _playbillgiven = true
end

--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data, ents = {}, {}
    --
    data.playbillgiven = _playbillgiven
    --
    return data, ents
end

function self:OnLoad(data)
    if data then
        if data.playbillgiven then
            _playbillgiven = data.playbillgiven
        end
    end
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    return string.format("has given playbill: %s, heckler shrine: %s", tostring(_playbillgiven), tostring(_hecklerreservation))
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
