local BrainCommon = require("brains/braincommon")
require("behaviours/chaseandattack")
require("behaviours/doaction")
require("behaviours/wander")

local MAX_CHASE_TIME = 60
local MAX_CHASE_DIST = 40
local SEE_FOOD_DIST = 30
local MAX_WANDER_DIST_FROM_CLONE = 8

local BatBossBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function IsTrackedAcidBat(inst)
    return TheWorld.components.acidbatwavemanager and TheWorld.components.acidbatwavemanager:IsTrackedAcidBat(inst)
end

local function GoHomeAction(inst)
	local home = inst.components.homeseeker and inst.components.homeseeker.home
    local buffaction = home and home.components.childspawner ~= nil and BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
        or nil
    if buffaction then
        if IsTrackedAcidBat(inst) and inst:GetDistanceSqToInst(home) > 30 * 30 then
            buffaction.options.do_not_locomote = true
        end
    end
	return buffaction
end

local function IsValidFood(item, inst)
	return item:GetTimeAlive() >= (inst.components.acidinfusible:IsInfused() and 1 or 8)
		and item:IsOnPassablePoint(true)
		and inst.components.eater:CanEat(item)
end

local EATFOOD_CANT_TAGS = { "INLIMBO", "fire", "catchable", "outofreach" }
local function EatFoodAction(inst)
	if inst.sg:HasAnyStateTag("busy", "doing") then
		return
	end

	local target = FindEntity(inst, SEE_FOOD_DIST, IsValidFood, nil, EATFOOD_CANT_TAGS, inst.components.eater:GetEdibleTags())
	return target and BufferedAction(inst, target, ACTIONS.EAT)
end

-- NOTES(JBK): Similar to slurtlebrain with some changes.
local STEALFOOD_CANT_TAGS = { "playerghost", "fire", "burnt", "INLIMBO", "outofreach" }
local STEALFOOD_ONEOF_TAGS = { "player", "_container" }
local function IsStealActionValid(act)
    local itemtosteal = act.target
    return itemtosteal and (itemtosteal.components.inventoryitem and itemtosteal.components.inventoryitem:IsHeld())
end

local function StealNitreAction(inst)
    if inst.sg:HasStateTag("busy") then
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SEE_FOOD_DIST, nil, STEALFOOD_CANT_TAGS, STEALFOOD_ONEOF_TAGS)

    for i, v in ipairs(ents) do
        --go through player inv and find valid food
        local inv = v.components.inventory
        if inv and v:IsOnValidGround() then
            local pack = inv:GetEquippedItem(EQUIPSLOTS.BODY)
            local validfood = nil
            if pack and pack.components.container then
                for k = 1, pack.components.container.numslots do
                    local item = pack.components.container.slots[k]
                    if item and item.prefab == "nitre" then
                        if validfood == nil then
                            validfood = {}
                        end
                        table.insert(validfood, item)
                    end
                end
            end

            for k = 1, inv.maxslots do
                local item = inv.itemslots[k]
                if item and item.prefab == "nitre" then
                    if validfood == nil then
                        validfood = {}
                    end
                    table.insert(validfood, item)
                end
            end

            if validfood ~= nil then
                local itemtosteal = validfood[math.random(1, #validfood)]
                if itemtosteal and
                itemtosteal.components.inventoryitem and
                itemtosteal.components.inventoryitem.owner then
                    local act = BufferedAction(inst, itemtosteal, ACTIONS.STEAL)
                    act.validfn = IsStealActionValid
                    act.attack = true
                    return act
                end
            end
        end

        local container = v.components.container
        if container then
            local validfood = nil
            for k = 1, container.numslots do
                local item = container.slots[k]
                if item and item.prefab == "nitre" then
                    if validfood == nil then
                        validfood = {}
                    end
                    table.insert(validfood, item)
                end
            end

            if validfood ~= nil then
                local itemtosteal = validfood[math.random(1, #validfood)]
                local act = BufferedAction(inst, itemtosteal, ACTIONS.STEAL)
                act.validfn = IsStealActionValid
                act.attack = true
                return act
            end
        end
    end

    return nil
end

local function AcidBatAction(inst) -- Try eating if available, else steal
    return EatFoodAction(inst) or StealNitreAction(inst)
end

local function ShouldSpawnBat(inst)
	return inst:NumBatsToSpawn() >= TUNING.BAT_BOSS_MIN_SPAWN_TO_HOWL and inst.components.combat:HasTarget()
end

local function GetCloneWanderHome(inst)
	local clone = inst.components.entitytracker:GetEntity("clone")
	return clone and clone:GetPosition()
end

function BatBossBrain:OnStart()
	local root = self.inst:HasTag("shadowthrall") and
		--bat_boss_shadow brain
		PriorityNode({
			WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "<jumping state guard>",
				PriorityNode({
					IfNode(function()
							return self.inst.sg.mem.doclone == nil
								and self.inst.components.combat:HasTarget()
								and self.inst.components.health:GetPercent() < TUNING.BAT_BOSS_SHADOW_CLONE_THRESHOLD
								and self.inst.components.entitytracker:GetEntity("clone") == nil
						end,
						"should clone",
						ActionNode(function()
							self.inst:PushEvent("doclone")
						end, "Kage Bunshin")),
					ParallelNodeAny{
						ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
						ConditionWaitNode(function()
							if not (self.inst.components.combat:InCooldown() or self.inst.sg:HasStateTag("busy") or self.inst.components.timer:TimerExists("chompcd")) then
								local target = self.inst.components.combat.target
								if target and self.inst:IsNear(target, TUNING.BAT_BOSS_CHOMP_RANGE) then
									self.inst:PushEvent("doattack", { target = target })
								end
							end
							return false --never finish
						end),
					},
					Wander(self.inst, GetCloneWanderHome, MAX_WANDER_DIST_FROM_CLONE),
				}, 0.25)),
		}, 0.25) or
		--bat_boss brain
		PriorityNode({
			WhileNode(function() return not self.inst.sg:HasStateTag("jumping") end, "<jumping state guard>",
				PriorityNode({
					BrainCommon.PanicTrigger(self.inst),
					BrainCommon.ElectricFencePanicTrigger(self.inst),

					MinPeriod(self.inst, TUNING.BAT_BOSS_SUMMON_PERIOD, true,
						IfNode(function() return ShouldSpawnBat(self.inst) end, "should spawn bat",
							ActionNode(function()
								self.inst:PushEvent("dohowl")
							end, "Summon Bat"))),
					ParallelNodeAny{
						ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST),
						ConditionWaitNode(function()
							if not (self.inst.components.combat:InCooldown() or self.inst.sg:HasStateTag("busy") or self.inst.components.timer:TimerExists("chompcd")) then
								local target = self.inst.components.combat.target
								if target and self.inst:IsNear(target, TUNING.BAT_BOSS_CHOMP_RANGE) then
									self.inst:PushEvent("doattack", { target = target })
								end
							end
							return false --never finish
						end),
					},
                    IfNode(function() return self.inst.components.acidinfusible:IsInfused() end, "Is Acid Infused",
						DoAction(self.inst, AcidBatAction)),
					DoAction(self.inst, EatFoodAction),
					WhileNode(function()
							-- can't go home if we're infused and part of a bat wave
							if self.inst.components.acidinfusible:IsInfused() and IsTrackedAcidBat(self.inst) then
								return false
							end
							return TheWorld.state.iscaveday
						end, "IsCaveDay",
						DoAction(self.inst, GoHomeAction)),
					IfNode(function() return IsTrackedAcidBat(self.inst) end, "Is tracked acid bat",
						MinPeriod(self.inst, TUNING.BAT_ESCAPE_TIME, false,
							DoAction(self.inst, GoHomeAction))),
					Wander(self.inst),
				}, 0.25)),
		}, 0.25)

	self.bt = BT(self.inst, root)
end

return BatBossBrain
