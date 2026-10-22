require "behaviours/chaseandattack"
require "behaviours/chaseandattackandavoid"
require "behaviours/findclosest"
require "behaviours/leash"
require "behaviours/faceentity"
require "behaviours/wander"

local SKULLACHE_CD = 18
local FALLAPART_CD = 11
local SEE_LURE_DIST = 20
local SAFE_LURE_DIST = 5

local COMBAT_FEAST_DELAY = 3
local CHECK_MINIONS_PERIOD = 2

local RESET_COMBAT_DELAY = 10

local LOITER_GATE_DIST = 5.5
local LOITER_GATE_RANGE = 1.5

local IDLE_GATE_TIME = 10
local IDLE_GATE_MAX_DIST = 4
local IDLE_GATE_DIST = 3

local AVOID_GATE_DIST = 6 --stargate radius + stalker radius + some breathing room

local StalkerBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self.abilityname = nil
    self.abilitydata = nil
    self.snaretargets = nil
    self.hasfeast = nil
    self.hasminions = nil
    self.checkminionstime = nil
    self.wantstospikes = nil
end)

local function GetStargatePos(inst)
    local stargate = inst.components.entitytracker:GetEntity("stargate")
    return stargate ~= nil and stargate:GetPosition() or nil
end

local function GetStargate(inst)
    return inst.components.entitytracker:GetEntity("stargate")
end

local function IsDefensive(self)
    return self.inst.components.health.currenthealth < TUNING.STALKER_ATRIUM_PHASE2_HEALTH
end

local STALKERMINION_TAGS = { "stalkerminion" }
local function CheckMinions(self)
    local t = GetTime()
    if t > (self.checkminionstime or 0) then
        local x, y, z = (GetStargate(self.inst) or self.inst).Transform:GetWorldPosition()
        self.hasminions = TheSim:CountEntities(x, y, z, 8, STALKERMINION_TAGS) > 0
        self.checkminionstime = t + CHECK_MINIONS_PERIOD
    end
end

local function ShouldSnare(self)
    if not self.inst.components.timer:TimerExists("snare_cd") then
        local targets = self.inst:FindSnareTargets()
        if targets ~= nil then
            self.abilitydata = { targets = targets }
            return true
        end
        self.inst.components.timer:StartTimer("snare_cd", TUNING.STALKER_ABILITY_RETRY_CD)
    end
    return false
end

local SPIKE_TARGET_MUST_TAGS = { "_combat", "_health" }
local SPIKE_TARGET_CANT_TAGS = { "fossil", "playerghost", "shadow", "INLIMBO" }
local function ShouldSpikes(self)
    if not (IsDefensive(self) or self.inst.components.timer:TimerExists("spikes_cd")) then
        if not self.hasminions then
            local stargate = GetStargate(self.inst)
            if stargate == nil or self.inst:IsNear(stargate, 8) then
                local x, y, z = (stargate or self.inst).Transform:GetWorldPosition()
                if #TheSim:FindEntities(x, y, z, 8, SPIKE_TARGET_MUST_TAGS, SPIKE_TARGET_CANT_TAGS) > 0 then
                    self.wantstospikes = true
                    return true
                end
            end
        end
        self.inst.components.timer:StartTimer("spikes_cd", TUNING.STALKER_ABILITY_RETRY_CD)
    end
    return false
end

local function ShouldSummonChannelers(self)
    return IsDefensive(self)
        and self.inst.components.commander:GetNumSoldiers() <= 0
        and not self.inst.components.timer:TimerExists("channelers_cd")
end

local function ShouldSummonMinions(self)
    return not self.hasminions
        and IsDefensive(self)
        and not self.inst.components.timer:TimerExists("minions_cd")
end

local function ShouldMindControl(self)
    if IsDefensive(self) and not self.inst.components.timer:TimerExists("mindcontrol_cd") then
        if self.inst:HasMindControlTarget() then
            return true
        end
        self.inst.components.timer:StartTimer("mindcontrol_cd", TUNING.STALKER_ABILITY_RETRY_CD)
    end
    return false
end

local function ShouldFeast(self)
    if self.hasfeast == nil then
        self.hasfeast = self.inst.components.health:IsHurt() and #self.inst:FindMinions(1) > 0
    end
    return self.hasfeast
end

local function ShouldCombatFeast(self)
    if not self.inst.components.combat:InCooldown() then
        local target = self.inst.components.combat.target
        if target ~= nil and target:IsNear(self.inst, TUNING.STALKER_ATTACK_RANGE + target:GetPhysicsRadius(0)) then
            return false
        end
    end
    if not self.inst.hasshield and self.inst.components.combat:GetLastAttackedTime() + COMBAT_FEAST_DELAY >= GetTime() then
        return false
    end
    return ShouldFeast(self)
end

local function ShouldUseAbility(self)
    local wantstospikes = self.wantstospikes
    self.wantstospikes = nil
    self.hasfeast = nil
    self.inst.returntogate = nil
    self.abilityname = self.inst.components.combat:HasTarget() and (
        (ShouldMindControl(self) and "mindcontrol") or
        (not wantstospikes and ShouldSnare(self) and "fossilsnare") or
        (ShouldSummonChannelers(self) and "shadowchannelers") or
        (ShouldCombatFeast(self) and "fossilfeast") or
        CheckMinions(self) or
        (ShouldSummonMinions(self) and "fossilminions") or
        (ShouldSpikes(self) and "fossilspikes")
    ) or nil
    return self.abilityname ~= nil
end

local function GetLoiterStargatePos(inst)
    local stargate = inst.components.entitytracker:GetEntity("stargate")
    if stargate ~= nil then
        local x, y, z = stargate.Transform:GetWorldPosition()
        local x1, y1, z1 = inst.Transform:GetWorldPosition()
        if x == x1 and z == z1 then
            return Vector3(x, 0, z)
        end
        local dx, dz = x1 - x, z1 - z
        local normalize = LOITER_GATE_DIST / math.sqrt(dx * dx + dz * dz)
        return Vector3(x + dx * normalize, 0, z + dz * normalize)
    end
end

local function GetIdleStargate(inst)
    local stargate = inst.components.entitytracker:GetEntity("stargate")
    if stargate ~= nil then
        inst.returntogate = true
        return stargate
    end
end

local function KeepIdleStargate(inst)
    inst.returntogate = true
    return true
end

local SHADOWLURE_TAGS = {"shadowlure"}
local function GetShadowLure(inst)
    return GetClosestInstWithTag(SHADOWLURE_TAGS, inst, SAFE_LURE_DIST)
end

local function KeepShadowLure(inst, target)
    return inst:IsNear(target, SAFE_LURE_DIST)
end

---------------
-- NPC

local areas_to_chatter =
{
    { -- Vault
        id = "vault",
        testfn = function(inst, task_id, room_id) return task_id and task_id:find("Vault") end,
    },
    { -- Atrium
        id = "atrium",
        testfn = function(inst, task_id, room_id) return task_id and task_id:find("Atrium") end,
    },
    { -- Residential Ruins
        id = "ruins_residential",
        testfn = function(inst, task_id, room_id) return task_id and task_id:find("Residential") and (room_id == nil or (not room_id:find("PitRoom") and not room_id:find("BridgeEntrance") and not room_id:find("RuinedCityEntrance"))) end,
    },
    { -- Military Ruins
        id = "ruins_military",
        testfn = function(inst, task_id, room_id) return task_id and task_id:find("Military") and (room_id == nil or (not room_id:find("PitRoom") and not room_id:find("BridgeEntrance"))) end,
    },
    { -- Sacred Ruins
        id = "ruins_sacred",
        testfn = function(inst, task_id, room_id) return task_id and (task_id:find("MoreAltars") or task_id:find("Sacred")) and (room_id == nil or (not room_id:find("PitRoom") and not room_id:find("BridgeEntrance"))) end,
    },
    { -- Labyrinth
        id = "ruins_labyrinth",
        testfn = function(inst, task_id, room_id) return task_id and task_id:find("Labyrinth") and (room_id == nil or (not room_id:find("PitRoom") and not room_id:find("BridgeEntrance") and not room_id:find("LabyrinthEntrance"))) end,
    },
    { -- Archives
        id = "archives",
        -- MoonMush check is here for Retrofitted Archives (Entire Grotto + Archives retrofit is marked with AncientArchivesRetrofit for task name)
        -- ArchiveMazeEntrance is not actually the archive, its a grotto room that acts as a connection.
        testfn = function(inst, task_id, room_id) return task_id and room_id and task_id:find("Archive") and not room_id:find("MoonMush") and not room_id:find("ArchiveMazeEntrance") end,
    },
    { -- Grotto
        id = "lunar_grotto",
        testfn = function(inst, task_id, room_id) return room_id and room_id:find("MoonMush") end,
    },
}

local WANDER_CHATTY_DELAY = 10
local WANDER_CHATTY_DELAY_RAND = 10
local WANDER_CHATTY_ENTERDELAY = 6
local WANDER_CHATTY_ENTERDELAY_RAND = 4

local FOLLOW_CHATTY_DELAY = 12
local FOLLOW_CHATTY_DELAY_RAND = 4
local FOLLOW_CHATTY_ENTERDELAY = 2
local FOLLOW_CHATTY_ENTERDELAY_RAND = 1

local WAIT_AREA_CHATTER = 10

local function GetLeader(inst)
    return inst.components.follower and inst.components.follower:GetLeader()
end

local function GetFaceTargetFn(inst)
    return GetLeader(inst)
end

local function KeepFaceTargetFn(inst, target)
    return GetLeader(inst) == target
end

local FIND_LEADER_RANGE_SQ = SEE_LURE_DIST * SEE_LURE_DIST
local function FindFollowTargetTest(inst, target)
    local item = target.components.inventory ~= nil and target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    return item and item:HasTag("shadowlure")
end

local function FindAndSetLeader(inst) -- players holding thurible
    local x, y, z = inst.Transform:GetWorldPosition()

    local leader = inst.components.follower:GetLeader()
    if leader ~= nil then
        if FindFollowTargetTest(inst, leader) then
            return true
        else
            inst.components.follower:SetLeader(nil)
        end
    end

    for i, v in ipairs(FindPlayersInRangeSq(x, y, z, FIND_LEADER_RANGE_SQ, true)) do
        if FindFollowTargetTest(inst, v) then
            inst.components.follower:SetLeader(v)
            break
        end
    end
end

local function GetWanderLines(inst)
    local lines = {}

    for i, v in ipairs(STRINGS.STALKER_NPC_IDLE) do
        table.insert(lines, v)
    end

    local area_data = inst.components.areaaware:GetCurrentArea()
    local topology_id = area_data ~= nil and area_data.id or nil
    if topology_id then
        local gen_data = ConvertTopologyIdToData(topology_id)
        local task_id = gen_data ~= nil and gen_data.task_id or nil
        local room_id = gen_data ~= nil and gen_data.room_id or nil
        for i, v in ipairs(areas_to_chatter) do
            if v.testfn(inst, task_id, room_id) then
                if inst:GetNPCData("seen_biome_"..v.id) then
                    for k, line in ipairs(STRINGS.STALKER_NPC_BIOMES_IDLE[string.upper(v.id)]) do
                        table.insert(lines, line)
                    end
                end
                break
            end
        end
    end

    return lines[math.random(#lines)]
end

local function GetFollowLines(inst, initialenter)
    local strtbl = initialenter and STRINGS.STALKER_NPC_FOLLOW_THURIBLE or STRINGS.STALKER_NPC_FOLLOWING_THURIBLE
    return strtbl[math.random(#strtbl)]
end

local function GetFaceTargetNearestPlayerFn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	return FindClosestPlayerInRange(x, y, z, 12, true)
end

local function KeepFaceTargetNearestPlayerFn(inst, target)
    return GetFaceTargetNearestPlayerFn(inst) == target
end

local function GetNPCFaceTargetFn(inst)
    return inst.brain.inspectable or GetFaceTargetNearestPlayerFn(inst)
end

local function KeepNPCFaceTargetFn(inst, target)
    return GetNPCFaceTargetFn(inst) == target
end

local function DoAreaChatter(inst)
    local area_data = inst.components.areaaware:GetCurrentArea()
    local topology_id = area_data ~= nil and area_data.id or nil
    if topology_id then
        local gen_data = ConvertTopologyIdToData(topology_id)
        local task_id = gen_data ~= nil and gen_data.task_id or nil
        local room_id = gen_data ~= nil and gen_data.room_id or nil
        for i, v in ipairs(areas_to_chatter) do
            if v.testfn(inst, task_id, room_id) then
                if not inst:GetNPCData("seen_biome_"..v.id) then
                    inst:Chatter("see_biomes."..v.id, function() inst:SetNPCData("seen_biome_"..v.id, true) end)
                end
                break
            end
        end
    end
end

--------------------------------------------------------------------------

local INSPECT_TAGS = { "inspectable", "shadow"--[[for ruins_shadeling]] }
local INSPECT_NO_TAGS = { "NOCLICK" } -- "INLIMBO" no INLIMBO so that equippable can be seen
local SEE_INSPECT_DIST = 16

local function IsObjectInChatteredArea(guy, inst) -- is the object in an area we chattered about?
    local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(guy.Transform:GetWorldPosition())
    local topology_id = node and TheWorld.topology.ids[node_index] or nil
    if topology_id then
        local gen_data = ConvertTopologyIdToData(topology_id)
        local task_id = gen_data ~= nil and gen_data.task_id or nil
        local room_id = gen_data ~= nil and gen_data.room_id or nil
        for i, v in ipairs(areas_to_chatter) do
            if v.testfn(inst, task_id, room_id) then
                return inst:GetNPCData("seen_biome_"..v.id) -- we can talk about the object if we've talked about the biome
            end
        end
    end

    return true -- not in a interesting area, we can talk about the object
end

local function IsObjectInteresting(guy, inst)
    local x, y, z = guy.Transform:GetWorldPosition()
    local stalkerinspectable = guy.components.stalkerinspectable
    return stalkerinspectable
        and not inst:GetNPCData("inspected_"..stalkerinspectable:GetName(inst))
        and FindClosestPlayerInRange(x, y, z, 22, true) ~= nil
        and IsObjectInChatteredArea(guy, inst)
        and ((not guy:HasTag("INLIMBO") and guy.entity:IsVisible()) or (guy.components.equippable and guy.components.equippable:IsEquipped()))
end

function StalkerBrain:SelectInspectable()
    -- Not using FindEntity because we want to skip the visible check for items that are equipped
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SEE_INSPECT_DIST, nil, INSPECT_NO_TAGS, INSPECT_TAGS)
    for i, v in ipairs(ents) do
        if v ~= self.inst and IsObjectInteresting(v, self.inst) then
            self.inspectable = v
            break
        end
    end
	return self.inspectable ~= nil
end

function StalkerBrain:CheckInspectable()
	return (self.inspectable:HasTag("torch") or not (self.inspectable.components.burnable ~= nil and self.inspectable.components.burnable:IsBurning()))
		and self.inspectable:IsValid()
        and IsObjectInteresting(self.inspectable, self.inst)
end

function StalkerBrain:GetInspectablePos()
	return self:CheckInspectable() and self.inspectable:GetPosition() or nil
end

local function OnNewState(inst)
    if inst.brain and not (inst.sg:HasStateTag("talking") and inst.sg:HasStateTag("idle")) then
        local stalkerinspectable = inst.brain.inspectable and inst.brain.inspectable.components.stalkerinspectable
        local inspectname = stalkerinspectable:GetName(inst)
        if inspectname then
            inst:SetNPCData("inspected_"..inspectname, true)
        end
    end
    inst:RemoveEventCallback("newstate", OnNewState)
end

local function FinishTalkingFn(inst)
    -- Set the seen inspect on a new state so that we can continue facing during the last line being said.
    if inst.brain then -- brain might be invalid
        inst:ListenForEvent("newstate", OnNewState)
    end
end

local function OnChangeArea(inst)
    if inst.brain then
        inst.brain.area_chatter_time = GetTime()
    end
end

--------------------------------------------------------------------------

local RITUAL_BOSS_NO_TAGS = { "NOCLICK" }
local RITUAL_BOSS_ONEOF_TAGS = { "_health", "_combat", "worm_boss_piece", "inspectable" }
local function IsRitualBossValid(guy, inst)
    return IsStalkerCorruptable(guy, inst)
end

function StalkerBrain:SelectRitualBoss()
	self.ritualboss = FindEntity(self.inst, SEE_INSPECT_DIST, IsRitualBossValid, nil, RITUAL_BOSS_NO_TAGS, RITUAL_BOSS_ONEOF_TAGS)
	return self.ritualboss ~= nil
end

function StalkerBrain:CheckRitualBoss()
	return self.ritualboss:IsValid()
end

function StalkerBrain:GetRitualBossPos()
	return self:CheckRitualBoss() and self.ritualboss:GetPosition() or nil
end

--------------------------------------------------------------------------

---------------

function StalkerBrain:OnStart()
    local root

    if self.inst.npcstalker then
        local NPC_CHATTYNODE_DATA = { noanim = true, nonpctalker = true }

        self.area_chatter_time = GetTime()
        self.inst:ListenForEvent("changearea", OnChangeArea)

        root = PriorityNode({
            WhileNode(
		    	function()
		    		return not self.inst.sg:HasStateTag("talking")
		    	end,
		    	"<talking state guard>",
                PriorityNode({
                    ParallelNodeAny{
                        ConditionWaitNode(function()
					    	FindAndSetLeader(self.inst)
					    	return false --abusing ConditionWaitNode as perma-running loop
					    end, "Setting Leader"),
                        SequenceNode{
                            ConditionWaitNode(function()
                                if GetTime() - self.area_chatter_time >= WAIT_AREA_CHATTER then
                                    self.area_chatter_time = GetTime()
                                    return true
                                end

                                return false
                            end),
                            ActionNode(function() DoAreaChatter(self.inst) end),
                        },
                        PriorityNode({
                            WhileNode(function() return self.inst.cancorrupt end, "can shadow corrupt",
                                IfNode(function() return self:SelectRitualBoss() end, "find ritual boss",
							        PriorityNode({
							        	FailIfSuccessDecorator(
							        		Leash(self.inst,
							        			function() return self:GetRitualBossPos() end,
							        			function() return self.inst:GetPhysicsRadius(0) + self.ritualboss:GetPhysicsRadius(0) + 5.5 end,
							        			function() return self.inst:GetPhysicsRadius(0) + self.ritualboss:GetPhysicsRadius(0) + 5 end)),
							        	IfNode(function() return self:CheckRitualBoss() end, "do shadow corrupt",
							        		ActionNode(function()
                                                self.inst:PushEventImmediate("perform_corrupt", { target = self.ritualboss })
                                            end)),
							        }, .5))),
                            IfNode(function() return self:SelectInspectable() end, "find inspectable",
							    PriorityNode({
							    	FailIfSuccessDecorator(
							    		Leash(self.inst,
							    			function() return self:GetInspectablePos() end,
							    			function() return self.inst:GetPhysicsRadius(0) + self.inspectable:GetPhysicsRadius(0) + 3.5 end,
							    			function() return self.inst:GetPhysicsRadius(0) + self.inspectable:GetPhysicsRadius(0) + 3 end)),
							    	IfNode(function() return self:CheckInspectable() end, "inspect",
							    		ActionNode(function()
                                            local inspectname = self.inspectable.components.stalkerinspectable:GetName(self.inst)
                                            self.inst:Chatter("inspect."..inspectname, FinishTalkingFn)
                                        end)),
							    }, .5)),

                            -- if its dropped on the ground
                            SequenceNode{
                                FindClosest(self.inst, SEE_LURE_DIST, SAFE_LURE_DIST, { "shadowlure" }, { "INLIMBO" }),
                                FaceEntity(self.inst, GetShadowLure, KeepShadowLure),
                            },
                            ChattyNode(self.inst, GetFollowLines,
			                    Follow(self.inst, GetLeader, 0, SAFE_LURE_DIST * .98, SAFE_LURE_DIST), FOLLOW_CHATTY_DELAY, FOLLOW_CHATTY_DELAY_RAND, FOLLOW_CHATTY_ENTERDELAY, FOLLOW_CHATTY_ENTERDELAY_RAND, NPC_CHATTYNODE_DATA),
                            FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
                            ChattyNode(self.inst, GetWanderLines,
			                    Wander(self.inst), WANDER_CHATTY_DELAY, WANDER_CHATTY_DELAY_RAND, WANDER_CHATTY_ENTERDELAY, WANDER_CHATTY_ENTERDELAY_RAND, NPC_CHATTYNODE_DATA),
                        }, .5)
                    },
                }, .5)),

            -- we get here if we're talking
            FaceEntity(self.inst, GetNPCFaceTargetFn, KeepNPCFaceTargetFn),
        }, .5)
    elseif self.inst.atriumstalker then
        root = PriorityNode({
            WhileNode(function() return not self.inst:IsNearAtrium() end, "LostAtrium",
                ActionNode(function() self.inst:OnLostAtrium() end)),
            WhileNode(function() return ShouldUseAbility(self) end, "Ability",
                ActionNode(function()
                    self.inst:PushEvent(self.abilityname, self.abilitydata)
                    self.abilityname = nil
                    self.abilitydata = nil
                end)),
            WhileNode(function() return ShouldFeast(self) end, "FossilFeast",
                ActionNode(function() self.inst:PushEvent("fossilfeast") end)),
            ChaseAndAttackAndAvoid(self.inst, GetStargate, AVOID_GATE_DIST),
            SequenceNode{
                ParallelNodeAny{
                    SequenceNode{
                        WaitNode(RESET_COMBAT_DELAY),
                        ActionNode(function() self.inst:SetEngaged(false) end),
                    },
                    Wander(self.inst, GetLoiterStargatePos, LOITER_GATE_RANGE),
                },
                Leash(self.inst, GetStargatePos, IDLE_GATE_MAX_DIST, IDLE_GATE_DIST),
                ParallelNode{
                    FaceEntity(self.inst, GetIdleStargate, KeepIdleStargate),
                    SequenceNode{
                        WaitNode(IDLE_GATE_TIME),
                        FailIfSuccessDecorator(ActionNode(function()
                            if (self.inst._lastplayerhittime or 0) + IDLE_GATE_TIME < GetTime() then
                                self.inst:OnLostAtrium()
                            end
                        end)),
                    },
                },
            },
            Wander(self.inst),
        }, .5)
    elseif self.inst.canfight then
        root = PriorityNode({
            WhileNode(function() return self.inst.components.combat:HasTarget() and ShouldSnare(self) end, "FossilSnare",
                ActionNode(function()
                    self.inst:PushEvent("fossilsnare", self.abilitydata)
                    self.abilitydata = nil
                end)),
            ChaseAndAttack(self.inst),
            ParallelNode{
                SequenceNode{
                    WaitNode(RESET_COMBAT_DELAY),
                    ActionNode(function() self.inst:SetEngaged(false) end),
                },
                PriorityNode({
                    SequenceNode{
                        FindClosest(self.inst, SEE_LURE_DIST, SAFE_LURE_DIST, { "shadowlure" }),
                        FaceEntity(self.inst, GetShadowLure, KeepShadowLure),
                    },
                    Wander(self.inst),
                }, .5),
            },
        }, .5)
    else
        local t = GetTime()
        self.skullachetime = t + 8 + math.random() * SKULLACHE_CD
        self.fallaparttime = t + 8 + math.random() * FALLAPART_CD

        root = PriorityNode({
            WhileNode(function() return not TheWorld.state.isnight end, "Daytime",
                ActionNode(function() self.inst:PushEvent("flinch") end)),
            WhileNode(
                function()
                    local t = GetTime()
                    if t > self.skullachetime then
                        self.skullachetime = t + SKULLACHE_CD
                        return true
                    end
                    return false
                end,
                "SkullAche",
                ActionNode(function() self.inst:PushEvent("skullache") end)),
            WhileNode(
                function()
                    local t = GetTime()
                    if t > self.fallaparttime then
                        self.fallaparttime = t + FALLAPART_CD
                        return true
                    end
                    return false
                end,
                "FallApart",
                ActionNode(function() self.inst:PushEvent("fallapart") end)),
            SequenceNode{
                FindClosest(self.inst, SEE_LURE_DIST, SAFE_LURE_DIST, { "shadowlure" }),
                FaceEntity(self.inst, GetShadowLure, KeepShadowLure),
            },
            Wander(self.inst),
        }, .5)
    end

    self.bt = BT(self.inst, root)
end

function StalkerBrain:OnStop()
    if self.inst.npcstalker then
        self.inst:RemoveEventCallback("changearea", OnChangeArea)
    end
end

return StalkerBrain