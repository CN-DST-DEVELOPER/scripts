require "behaviours/standstill"
require "behaviours/wander"
require "behaviours/follow"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/findlight"
require "behaviours/panic"
require "behaviours/chattynode"
require "behaviours/leash"

local BrainCommon = require "brains/braincommon"

local MAX_WANDER_DIST = 20

local TRADE_DIST = 20

local function GetTraderFn(inst)
    if inst.components.trader == nil then
        return nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TRADE_DIST, true)
    for _, player in ipairs(players) do
        if inst.components.trader:IsTryingToTradeWithMe(player) then
            return player
        end
    end
end

local function KeepTraderFn(inst, target)
    return (inst.components.trader ~= nil and inst.components.trader:IsTryingToTradeWithMe(target))
end

local function failexperiment(static)
    if TheWorld.components.moonstormmanager and not static.experimentcomplete then
        TheWorld.components.moonstormmanager:FailExperiment()
    end
end

local function face_final_position(inst, final)
    inst:ForceFacePoint(final:Get())
end

local function initiate_experiment(inst, pos)
    inst.busy = inst.busy and inst.busy > 0 and inst.busy - 1 or nil

    inst.meetingplayer = nil
    inst.Transform:SetPosition(pos.x, pos.y, pos.z)
    if inst.hunt_count and inst.hunt_count == 0 then
        inst.components.timer:StartTimer("wagstaff_movetime", 10 + (math.random()*5))
    end

    local champions_killed = (TheWorld.components.moonstormmanager and TheWorld.components.moonstormmanager:GetCelestialChampionsKilled())
        or 0
    if inst.hunt_count >= (champions_killed > 0 and 1 or TUNING.WAGSTAFF_NPC_HUNTS) then
        inst.hunt_stage = "experiment"

        local static = SpawnPrefab("moonstorm_static")
        local theta = (inst.Transform:GetRotation() + 90)*DEGREES
        local offset = Vector3(math.cos( theta ), 0, -math.sin( theta )) -- Radius is 1, so we've excised the multiplication.
        local final = pos + offset
        static.Transform:SetPosition(final:Get())
        inst:DoTaskInTime(0, face_final_position, final)

        inst.static = static
        inst:ListenForEvent("onremove", failexperiment, static)
        inst:ListenForEvent("death", failexperiment, static)
    end

    inst:erode(1,true)
end

local function ShouldGoToClue(inst)
    local clue_position = inst.components.knownlocations:GetLocation("clue")
    if clue_position then
        if inst.playerwasnear then
            inst.hunt_count = inst.hunt_count +1
        end

        inst.components.knownlocations:ForgetLocation("clue")
        if inst.hunt_count ~= 0 then
            inst:erode(3)
            inst:DoTaskInTime(3, initiate_experiment, clue_position)
        end
        return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, clue_position, nil, .2)
    end
end

local function DoMachineHint(inst)
    inst.components.talker:Chatter("WAGSTAFF_GOTTOHINT", math.random(#STRINGS.WAGSTAFF_GOTTOHINT), nil, nil, CHATPRIORITIES.LOW)
end

local function ShouldGoToMachine(inst)
    local machinepos = inst.components.knownlocations:GetLocation("machine")

    if machinepos then
        inst:DoTaskInTime(1.5, DoMachineHint)
        inst:DoTaskInTime(3.5, inst.erode, 2, nil, true)

        return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, machinepos, nil, .2)
    end
end

local function DoJunkyardHint(inst)
    inst.components.talker:Chatter("WAGSTAFF_JUNK_YARD_OCCUPIED", 1, nil, nil, CHATPRIORITIES.HIGH)
end

local function ShouldGoToJunkYard(inst)
    local junkpos = inst.components.knownlocations:GetLocation("junk")

    if junkpos then
        inst:DoTaskInTime(4, DoJunkyardHint)
        inst:DoTaskInTime(6.5, inst.erode, 2, nil, true)
        return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, junkpos, nil, .2)
    end
end

local function OnFinishExperiment_gestaltcage(inst, item, socketable)
    if item and item:IsValid() and socketable and socketable:IsValid() and item.components.inventoryitem:IsHeldBy(inst) then
        local wagpunk_arena_manager = TheWorld.components.wagpunk_arena_manager
        local didsocket = false
        if socketable.prefab == "wagdrone_spot_marker" then
            local dronecount
            if item.prefab == "gestalt_cage_filled1" then
                local replacementinst = ReplacePrefab(socketable, "wagdrone_rolling")
                if wagpunk_arena_manager then
                    wagpunk_arena_manager:TrackWagdrone(replacementinst)
                    dronecount = wagpunk_arena_manager:GetTotalDronePlacementCount()
                end
                didsocket = true
            elseif item.prefab == "gestalt_cage_filled2" then
                local replacementinst = ReplacePrefab(socketable, "wagdrone_flying")
                if wagpunk_arena_manager then
                    wagpunk_arena_manager:TrackWagdrone(replacementinst)
                    dronecount = wagpunk_arena_manager:GetTotalDronePlacementCount()
                end
                didsocket = true
            end
            if dronecount then
                inst:DropNotesForDroneCount(dronecount)
            end
        elseif socketable.prefab == "wagboss_robot" then
            if item.prefab == "gestalt_cage_filled3" then
                if socketable.AnimState:IsCurrentAnimation("concealed_idle") then
                    socketable:PushEvent("reveal")
                    inst.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_REVEALBOSS")
                else
                    socketable:SocketCage()
                    didsocket = true
                end
            end
        end
        if didsocket then
            item:Remove()
            TheWorld:PushEvent("ms_wagpunk_constructrobot")
            if wagpunk_arena_manager then
                if wagpunk_arena_manager:NeedsMoreWagdrones() then
                    inst.components.npc_talker:Chatter("WAGSTAFF_GET_MORE_GESTALTCAGES", math.random(#STRINGS.WAGSTAFF_GET_MORE_GESTALTCAGES))
                else
                    inst.oneshot = false
                end
            end
        end
    end
end

local FILLED3_TAGS = {"gestalt_cage_filled", "irreplaceable"}
local function DoArenaActions(inst)
    if inst.desiredlocation then
        local location = inst.desiredlocation
        local distance = inst.desiredlocationdistance
        inst.desiredlocation = nil
        inst.desiredlocationdistance = nil
        return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, location, nil, distance)
    end
    if inst.components.npc_talker:haslines() then
        if not inst.sg:HasStateTag("talking") and not inst.sg:HasStateTag("busy") and not inst.components.timer:TimerExists("speak_time") then
            inst:PushEvent("talk")
            inst.components.npc_talker:donextline()
        end
        return
    end

    if inst.wagstaff_experimenttime then
        inst:PushEvent("doexperiment")
        return
    end
    if inst.wagstaff_experimentcallback then
        return
    end

    inst.avoid_erodeout = nil
    local item = inst.components.inventory:GetFirstItemInAnySlot()
    if item and item:HasTag("gestalt_cage_filled") then
        local wagpunk_arena_manager = TheWorld.components.wagpunk_arena_manager
        if wagpunk_arena_manager then
            local socketable = wagpunk_arena_manager:GetArenaSocketingInstFor(inst, item)
            if socketable then
                local distance = inst:GetPhysicsRadius(0) + socketable:GetPhysicsRadius(0) + 1
                inst.avoid_erodeout = true
                if inst.dofadeoutintask then
                    inst.dofadeoutintask:Cancel()
                    inst.dofadeoutintask = nil
                end
                if inst:GetDistanceSqToInst(socketable) <= distance * distance then
                    inst:DoExperiment(nil, OnFinishExperiment_gestaltcage, item, socketable)
                    return
                else
                    return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, socketable:GetPosition(), nil, distance)
                end
            end
        end
    end

    if inst.itemstotoss then
        inst:PushEvent("tossitem")
        return
    end

    if inst.tiedtolever then
        local t = GetTime()
        if inst.levernagcooldowntime == nil or inst.levernagcooldowntime < t then
            inst.levernagcooldowntime = t + TUNING.WAGPUNK_ARENA_WAGSTAFF_NAG_COOLDOWN_TIME
            inst.components.npc_talker:resetqueue()
            inst.components.talker:ShutUp()
            if not inst.erodingout then
                inst.components.npc_talker:Chatter("WAGSTAFF_WAGPUNK_ARENA_LEVER", math.random(#STRINGS.WAGSTAFF_WAGPUNK_ARENA_LEVER))
                inst:PushEvent("talk")
                inst.components.npc_talker:donextline()
            end
        end
        local wagpunk_arena_manager = TheWorld.components.wagpunk_arena_manager
        if wagpunk_arena_manager and wagpunk_arena_manager.lever then
            local distance = inst:GetPhysicsRadius(0) + wagpunk_arena_manager.lever:GetPhysicsRadius(0) + 1
            if inst:GetDistanceSqToInst(wagpunk_arena_manager.lever) > distance * distance then
                return BufferedAction(inst, nil, ACTIONS.WALKTO, nil, wagpunk_arena_manager.lever:GetPosition(), nil, distance)
            end
        end
        return
    end

    if inst.wantingcage then
        local lunaralterguardian = TheWorld.components.lunaralterguardianspawner and TheWorld.components.lunaralterguardianspawner:GetGuardian() or nil
        if not lunaralterguardian then
            local x, y, z = inst.Transform:GetWorldPosition()
            if TheSim:CountEntities(x, y, z, 12, FILLED3_TAGS) > 0 then
                return
            end
        else
            if lunaralterguardian.sg:HasStateTag("temp_invincible") then
                return
            end
        end
        inst.wantingcage = nil
        inst:DoFadeOutIn(0.5)
    end

    if inst.oneshot and inst.sg:HasStateTag("idle") then
        inst:DoFadeOutIn(TUNING.WAGPUNK_ARENA_WAGSTAFF_TALK_TIME)
    end
end

local Wagstaff_NPCBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function Wagstaff_NPCBrain:OnStart()
    local in_arena = WhileNode(function() return self.inst.prefab == "wagstaff_npc_wagpunk_arena" end, "IsWagpunkArenaWagstaff",
        PriorityNode{
            DoAction(self.inst, DoArenaActions, "Arena Actions", true),
            StandStill(self.inst),
        }, .5)

    local in_junk = WhileNode( function() return self.inst.components.knownlocations:GetLocation("junk") end, "IsJunkHintingWagstaff",
        PriorityNode{
            IfNode(function() return self.inst.components.knownlocations:GetLocation("junk") end, "Go To Clue",
                DoAction(self.inst, ShouldGoToJunkYard, "Go to junkyard", true )),
            StandStill(self.inst),
        }, .5)

    local in_hint = WhileNode( function() return self.inst.components.knownlocations:GetLocation("machine") end, "IsHintingWagstaff",
        PriorityNode{
            IfNode(function() return self.inst.components.knownlocations:GetLocation("machine") end, "Go To Clue",
                DoAction(self.inst, ShouldGoToMachine, "Go to machine", true )),
            StandStill(self.inst),
        }, .5)

    local in_hunt = WhileNode( function() return self.inst.hunt_stage == "hunt" end, "IsHuntWagstaff",
        PriorityNode{
            IfNode(function() return self.inst.components.knownlocations:GetLocation("clue") end, "Go To Clue",
                DoAction(self.inst, ShouldGoToClue, "Go to clue", true )),
            WhileNode(function() return not self.inst.busy or self.inst.busy < 1 end, "looking around",
                ChattyNode(self.inst, "WAGSTAFF_NPC_MUMBLE_1",
                    StandStill(self.inst))),
            StandStill(self.inst),
        }, .5)

    local root =
        PriorityNode(
        {
            in_arena,
            in_junk,
            in_hint,
            in_hunt,
            ChattyNode(self.inst, "WAGSTAFF_NPC_ATTEMPT_TRADE",
                FaceEntity(self.inst, GetTraderFn, KeepTraderFn)),
            StandStill(self.inst),
        }, .5)

    self.bt = BT(self.inst, root)
end

return Wagstaff_NPCBrain
