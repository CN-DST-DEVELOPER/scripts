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

local MAX_WANDER_DIST = 40

local START_RUN_DIST = 3
local STOP_RUN_DIST = 5
local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 30
local SEE_LIGHT_DIST = 20
local TRADE_DIST = 20
local SEE_TREE_DIST = 15
local SEE_TARGET_DIST = 20
local SEE_FOOD_DIST = 10

local SEE_BURNING_HOME_DIST_SQ = 20*20

local COMFORT_LIGHT_LEVEL = 0.3

local KEEP_CHOPPING_DIST = 10

local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 8

local START_FACE_DIST = 4
local KEEP_FACE_DIST = 6

local function getstring(inst, stringdata)
    if stringdata["LOW"] then
        local gfl = inst.getgeneralfriendlevel(inst)
        return stringdata[gfl][math.random(1,#stringdata[gfl])]
    else
        return stringdata[math.random(1,#stringdata)]
    end
end

-- UMBRELLA
local function holding_umbrella(inst) --hand slot specifically
	local tool = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	return tool ~= nil and tool:HasTag("umbrella")
end

local function equipped_umbrella(inst) --any slot
	return inst.components.inventory:EquipHasTag("umbrella")
end

local function has_umbrella(inst)
	local ret--[[, num]] = inst.components.inventory:HasItemWithTag("umbrella", 1)
	return ret
end

local function item_is_umbrella(item)
	return item:HasTag("umbrella")
end

local function EquipUmbrella(inst)
	local umbrella = inst.components.inventory:FindItem(item_is_umbrella)
    if umbrella then
        inst.components.inventory:Equip(umbrella)
    end
end

local function try_unequip_umbrella(item, inst)
	if item:HasTag("umbrella") then
		item = inst.components.inventory:Unequip(item.components.equippable.equipslot)
		inst.components.inventory:GiveItem(item)
	end
end

local function UnEquipUmbrella(inst)
	inst.components.inventory:ForEachEquipment(try_unequip_umbrella, inst)
end

-- COAT
local function using_coat(inst)
    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    return equipped and inst.iscoat(equipped) or nil
end

local function has_coat(inst)
    return inst.components.inventory:FindItem(function(testitem) return inst.iscoat(testitem) end)
end

local function getcoat(inst)
    local bodyequipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    return inst.components.inventory:FindItem(function(testitem) return inst.iscoat(testitem) end) or (bodyequipped and  inst.iscoat(bodyequipped) and bodyequipped )
end

local function EquipCoat(inst)
    local coat = getcoat(inst)
    if coat then
        inst.components.inventory:Equip(coat)
    end
end

local function UnEquipBody(inst)
    local item = inst.components.inventory:Unequip(EQUIPSLOTS.BODY)
    inst.components.inventory:GiveItem(item)
end

local function ShouldRunAway(inst, target)
    return not inst.components.trader:IsTryingToTradeWithMe(target)
end

local function GetTraderFn(inst)
    if inst.sg:HasStateTag("talking") then
        return nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TRADE_DIST, true)
    for i, v in ipairs(players) do
        if inst.components.trader:IsTryingToTradeWithMe(v) then

            local gfl = inst.getgeneralfriendlevel(inst)
            local chatter_name = "HERMITCRAB_ATTEMPT_TRADE."..gfl
            inst.components.npc_talker:Chatter(chatter_name, math.random(#(STRINGS["HERMITCRAB_ATTEMPT_TRADE"][gfl])), nil, nil, true)

            if inst.components.timer:TimerExists("speak_time") then
                inst.components.timer:SetTimeLeft("speak_time", TUNING.HERMITCRAB.SPEAKTIME)
            else
                inst.components.timer:StartTimer("speak_time",TUNING.HERMITCRAB.SPEAKTIME)
            end

            if inst.components.timer:TimerExists("complain_time") then
                local time = inst.components.timer:GetTimeLeft("complain_time")
                inst.components.timer:SetTimeLeft("complain_time", time + 10)
            else
                inst.components.timer:StartTimer("complain_time",10 + (math.random()*30))
            end

            return v
        end
    end
end

local function KeepTraderFn(inst, target)
    if inst.sg:HasStateTag("talking") then
        return nil
    end

    return inst.components.trader:IsTryingToTradeWithMe(target)
end

local function HasValidHome(inst)
    local home = inst.components.homeseeker ~= nil and inst.components.homeseeker.home or nil
    return home ~= nil
        and home:IsValid()
        and not (home.components.burnable ~= nil and home.components.burnable:IsBurning())
        and not home:HasTag("burnt")
end

local function GoHomeImmediatelyAction(inst)
    if HasValidHome(inst) then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function GoHomeAction(inst)
    if HasValidHome(inst) and not inst:AllNightTest() then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function GetHomePos(inst)
    return HasValidHome(inst) and inst.components.homeseeker:GetHomePos()
end

local LIGHTS_TAGS = {"lightsource"}

local function GetNearestLightPos(inst)
    local light = GetClosestInstWithTag(LIGHTS_TAGS, inst, SEE_LIGHT_DIST)
    if light then
        return Vector3(light.Transform:GetWorldPosition())
    end
    return nil
end

local function GetNearestLightRadius(inst)
    local light = GetClosestInstWithTag(LIGHTS_TAGS, inst, SEE_LIGHT_DIST)
    if light then
        return light.Light:GetCalculatedRadius()
    end
    return 1
end

local function formatstring(inst,str,target)
    return string.format(str,target:GetDisplayName())
end

local function getfriendlevelspeech(inst, target)
    if not inst.components.timer:TimerExists("speak_time") then

        local level = inst.components.friendlevels.level
        local str = STRINGS.HERMITCRAB_GREETING[level][math.random(#STRINGS.HERMITCRAB_GREETING[level])]

        if type(str) == "table" then
            local new = {}
            for i,sstr in ipairs(str)do
                table.insert(new,formatstring(inst,sstr,target))
            end
            str = new
        else
            str = formatstring(inst,str,target)
        end

        -- override if there are rewards.
        local is_chatter
        local rewardstr = inst.rewardcheck(inst)
        if rewardstr then
            str = rewardstr
            is_chatter = true
            if inst.giverewardstask then
                inst.giverewardstask:Cancel()
                inst.giverewardstask = nil
            end
        else
            --othewise, do some cutsom stuff for fun.
            if target and level == 10 and not inst.components.timer:TimerExists("hermit_grannied"..target.GUID) then
                inst.components.timer:StartTimer("hermit_grannied"..target.GUID,TUNING.TOTAL_DAY_TIME)

                local sanity = target.components.sanity and target.components.sanity:GetPercent() or nil
                local health = target.components.health and target.components.health:GetPercent() or nil
                local hunger = target.components.hunger and target.components.hunger:GetPercent() or nil

                if (not sanity or sanity > 0.5) and
                    (not health or health > 0.5) and
                    (not hunger or hunger > 0.5) then
                    str = STRINGS.HERMITCRAB_LEVEL10_PLAYERGOOD[math.random(1,#STRINGS.HERMITCRAB_LEVEL10_PLAYERGOOD)]
                elseif sanity and (not health or sanity <= health) and (not hunger or sanity <= hunger) then
                    str = STRINGS.HERMITCRAB_LEVEL10_LOWSANITY[math.random(1,#STRINGS.HERMITCRAB_LEVEL10_LOWSANITY)]
                elseif health and (not sanity or health <= sanity) and (not hunger or health <= hunger) then
                    str = STRINGS.HERMITCRAB_LEVEL10_LOWHEALTH[math.random(1,#STRINGS.HERMITCRAB_LEVEL10_LOWHEALTH)]
                elseif hunger and (not sanity or hunger <= sanity) and (not health or hunger <= health) then
                    str = STRINGS.HERMITCRAB_LEVEL10_LOWHUNGER[math.random(1,#STRINGS.HERMITCRAB_LEVEL10_LOWHUNGER)]
                end
            end
        end

        inst.components.timer:StartTimer("speak_time",TUNING.HERMITCRAB.SPEAKTIME)

        if inst.components.timer:TimerExists("complain_time") then
            local time = inst.components.timer:GetTimeLeft("complain_time")
            inst.components.timer:SetTimeLeft("complain_time", time + 10)
        else
            inst.components.timer:StartTimer("complain_time",10 + (math.random()*30))
        end

        return str, is_chatter
    end
end

local function GetFaceTargetFn(inst)
    if inst.sg:HasStateTag("talking") then
        return nil
    end
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    if not target then
        inst.hasgreeted = nil
    end
    local shouldface = target ~= nil and not target:HasTag("notarget") and target or nil

    if shouldface and not inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("alert") and not inst.hasgreeted then
        local str, is_chatter = getfriendlevelspeech(inst, target)
        if str then
            -- TODO (SAM) Leaving this as Say for now, because some of the getfriendspeechlevel options
            -- format in the player's name.
            if is_chatter then
                local sound = nil -- stub
                inst.components.npc_talker:Chatter(str, nil, nil, nil, nil, sound)
            else
                inst.components.npc_talker:Say(str, nil, true)
            end
        end
        inst.hasgreeted = true
    end

    if shouldface and inst.sg:HasStateTag("npc_fishing") then
        inst.sg:RemoveStateTag("canrotate")
        inst:PushEvent("oceanfishing_stoppedfishing",{reason="bothered"})
    end

    if shouldface then
        if target and target._hermit_music then
            target._hermit_music:push()
        end
    end
    return shouldface
end

local function KeepFaceTargetFn(inst, target)
    return inst ~= nil
        and target ~= nil
        and inst:IsValid()
        and target:IsValid()
        and not (target:HasTag("notarget") or
                target:HasTag("playerghost") or
                    target.sg:HasStateTag("talking"))
        and inst:IsNear(target, KEEP_FACE_DIST)
end

local function DoCommentAction(inst)
    if inst.comment_data then
        if inst.comment_data.speech then
            return BufferedAction(inst, nil, ACTIONS.COMMENT, nil, inst.comment_data.pos, nil, inst.comment_data.distance)
        else
            local buffered_action = BufferedAction(inst, nil, ACTIONS.WALKTO, nil, inst.comment_data.pos, nil, inst.comment_data.distance)
            if buffered_action then
                buffered_action:AddSuccessAction(function() inst.comment_data = nil end)
            end
            return buffered_action
        end
    end
end

local function IsItemHarvestableMeat(item)
    return item.components.dryable == nil and item.components.edible and item.components.edible.foodtype == FOODTYPE.MEAT
end

local function DoHarvestMeat(inst)
    local source = inst.CHEVO_marker
    if source then
        local x, y, z = source.Transform:GetWorldPosition()
        local ents = inst:GetAllMeatRacksNear(x, y, z)
        local target = nil
        local targetitem = nil
        for _, ent in ipairs(ents) do
            local container = ent.components.dryingrack and ent.components.dryingrack:GetContainer() or nil
            if container and not container:IsEmpty() then
                targetitem = container:FindItem(IsItemHarvestableMeat)
                if targetitem then
                    target = ent
                    break
                end
            elseif ent.components.dryer and ent.components.dryer:IsDone() then
                target = ent
                targetitem = nil
                break
            end
        end
        if target then
            return BufferedAction(inst, target, ACTIONS.HARVEST, targetitem)
        end
    end
end

local PICKABLE_TAGS = {"pickable","bush"}
local function DoHarvestBerries(inst)
    local source = inst.CHEVO_marker
    if source then
        local x,y,z = source.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x,y,z, inst.island_radius, PICKABLE_TAGS)
        local target = (#ents > 0 and ents[1]) or nil
        if target then
            return BufferedAction(inst, target, ACTIONS.PICK)
        end
    end
end

local FISHING_MARKER_TAGS = {"hermitcrab_marker_fishing"}

local FISH_TAGS = {"oceanfish", "oceanfishable"}
local FISH_NO_TAGS = {"INLIMBO"}

local function DoFishingAction(inst)
	if not holding_umbrella(inst) and not inst:IsInBadLivingArea() then
        local source = inst.CHEVO_marker
        if source then
            local x,y,z = source.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x,y,z, inst.island_radius, FISHING_MARKER_TAGS)
            local mostfish = {total=0,idx=0}
            for i,ent in ipairs(ents)do
                local x1,y1,z1 = ent.Transform:GetWorldPosition()

                local fish = TheSim:FindEntities(x1,y1,z1, 8, FISH_TAGS, FISH_NO_TAGS)
                if #fish > mostfish.total then
                    mostfish = {total=#fish,idx=i}
                end
            end
            if mostfish.idx > 0 then
                local pos = Vector3(ents[mostfish.idx].Transform:GetWorldPosition())
                if pos then
                    inst.startfishing(inst)
                    local rod = inst.components.inventory:FindItem(function(item) return item.prefab == "oceanfishingrod" end) or inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    return BufferedAction(inst, nil, ACTIONS.OCEAN_FISHING_CAST, rod, pos)
                end
            end
        end
    end
end

local function DoReel(inst)
    if inst.hookfish and inst:HasTag("fishing_idle") then
        return BufferedAction(inst, nil, ACTIONS.OCEAN_FISHING_REEL)
    end
end

local function runawaytest(inst)
    if inst.components.friendlevels.level <= TUNING.HERMITCRAB.UNFRIENDLY_LEVEL then
        local player = FindClosestPlayerToInst(inst, STOP_RUN_DIST, true)
        if not player then
            inst.hasgreeted = nil
        end
        if player and not inst.sg:HasStateTag("busy") and not inst.hasgreeted then
            local str, is_chatter = getfriendlevelspeech(inst, player)
            if str then
                -- TODO (SAM) Leaving this as Say for now, because some of the getfriendspeechlevel options
                -- format in the player's name.
                if is_chatter then
                    local sound = nil -- stub
                    inst.components.npc_talker:Chatter(str, nil, nil, nil, nil, sound)
                else
                    inst.components.npc_talker:Say(str, nil, true)
                end
            end
            inst.hasgreeted = true
        end
        return true
    end
end

local RUN_AWAY_FROM_PIG_PARAMS =
{
	tags = { "pig", "_combat" },
	fn = function(guy, inst)
		return guy.components.combat:TargetIs(inst)
	end,
}

local function DoBottleToss(inst)
	if not inst.components.timer:TimerExists("bottledelay") and not holding_umbrella(inst) and not inst:IsInBadLivingArea() then
        local source = inst.CHEVO_marker
        if source then
            local x,y,z = source.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x,y,z, inst.island_radius, FISHING_MARKER_TAGS)
            if #ents > 0 then
                for attempt = 1, 3 do
                    local pos = ents[math.random(1,#ents)]:GetPosition()

                    if pos and TheWorld.Map:IsOceanTileAtPoint(pos.x, 0, pos.z) then
                        local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                        local bottle = inst.components.inventory:FindItem(function(item) return item.prefab == "messagebottle_throwable" end) or (equipped and  equipped.prefab == "messagebottle_throwable" and equipped )
                        if not bottle  then
                            bottle = SpawnPrefab("messagebottle_throwable")
                            inst.components.inventory:GiveItem(bottle)
                        end
                        if not bottle.components.equippable.isequipped then
                            inst.components.inventory:Equip(bottle)
                        end

                        inst.dotalkingtimers(inst)
                        return BufferedAction(inst, nil, ACTIONS.WATER_TOSS, bottle, pos)
                    end
                end
            end
        end
    end
end

local SITTABLE_TAGS = {"cansit"}
local SITTABLE_WONT_TAGS = { "uncomfortable_chair", "fire" }
local function DoChairSit(inst)
    if not inst:HasTag("sitting_on_chair") and not inst.components.timer:TimerExists("sat_on_chair") then
        local source = inst.CHEVO_marker
        if source then
            local x,y,z = source.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x,y,z, inst.island_radius, SITTABLE_TAGS, SITTABLE_WONT_TAGS)
            local target = nil
            if #ents > 0 then
                for _, ent in ipairs(ents)do
                    target = ent
                    break
                end
            end
            if target then
                return BufferedAction(inst, target, ACTIONS.SITON)
            end
        end
    end
end

local HOTSPRING_TAGS = { "hermithotspring" }
local HOTSPRING_NO_TAGS = { "bathbombable" }
local function DoSoakin(inst)
	if not (inst.sg:HasStateTag("soakin")  or inst.components.timer:TimerExists("soaked_in_hotspring")) then
		local x, y, z = inst.Transform:GetWorldPosition()
		for _, v in ipairs(TheSim:FindEntities(x, y, z, 20, HOTSPRING_TAGS, HOTSPRING_NO_TAGS)) do
			if v.components.bathingpool then
				if v.components.timer then
					local remaining = v.components.timer:GetTimeLeft("bathbombed")
					if remaining == nil or remaining < TUNING.HERMITCRAB_HOTSPRING_SOAK_TIME then
						return
					end
				end
				return BufferedAction(inst, v, ACTIONS.SOAKIN)
			end
		end
	end
end

local function ExitHotSpring(inst)
	local target = inst.sg.statemem.occupying_bathingpool
	if target and target.components.bathingpool then
		target.components.bathingpool:LeavePool(inst)
	end
end

local function DoTalkQueue(inst)
    if inst.components.npc_talker:haslines() and not inst.sg:HasStateTag("talking") and not inst.sg:HasStateTag("busy") and not inst.components.timer:TimerExists("speak_time") then
        inst.components.npc_talker:donextline()
    end
end

local function DoThrow(inst)
    if inst.itemstotoss and not inst.sg:HasStateTag("mandatory") then
        inst:PushEvent("tossitem")
    end
end

local CHATTERPARAMS_LOW = {
	echotochatpriority = CHATPRIORITIES.LOW,
}
local CHATTERPARAMS_HIGH = {
	echotochatpriority = CHATPRIORITIES.HIGH,
}

local HermitBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    --
    self.tea_shops = {} -- [ent] = true
    self.selected_tea_shop = nil
end)

---------------------------------------------------------------------

local function IsTeaShopValid(teashop)
    return teashop ~= nil and teashop:IsValid()
        and not (teashop:HasTag("burnt") or (teashop.components.burnable ~= nil and teashop.components.burnable:IsBurning()))
end

function HermitBrain:AddActiveTeaShop(teashop)
    self.tea_shops[teashop] = true
end

function HermitBrain:RemoveActiveTeaShop(teashop)
    self.tea_shops[teashop] = nil

    if teashop == self.selected_tea_shop then
        self.selected_tea_shop = nil
        self.inst.components.locomotor:Stop()
    end
end

function HermitBrain:AnyActiveTeaShop()
    return next(self.tea_shops) ~= nil
end

function HermitBrain:GetFirstTeaShop()
    return next(self.tea_shops)
end

function HermitBrain:ValidateTeaShops()
    for teashop in pairs(self.tea_shops) do
        if not IsTeaShopValid(teashop) then
            self.tea_shops[teashop] = nil

            if self.selected_tea_shop == teashop then
                self.selected_tea_shop = nil
            end
        end
    end
end

function HermitBrain:SelectTeaShop()
    self:ValidateTeaShops()
    self.selected_tea_shop = self:GetFirstTeaShop()

    if self.selected_tea_shop ~= nil then
        self.inst.components.npc_talker:Chatter("HERMITCRAB_ANNOUNCE_GOING_TEASHOP", math.random(#STRINGS.HERMITCRAB_ANNOUNCE_GOING_TEASHOP))
        return true
    end

    return nil
end

function HermitBrain:CheckSelectedTeaShop()
    self:ValidateTeaShops()
    return IsTeaShopValid(self.selected_tea_shop)
end

function HermitBrain:GetSelectedTeaShopPos()
	return self:CheckSelectedTeaShop() and self.selected_tea_shop:GetPosition() or nil
end

function HermitBrain:GetSelectedTeaShop()
    return self:CheckSelectedTeaShop() and self.selected_tea_shop or nil
end

---------------------------------------------------------------------

local function GetFirstHungryPetCritter(inst)
    local pets = inst.components.petleash:GetPets()
    for k, v in pairs(pets) do
        local x, y, z = v.Transform:GetWorldPosition()
        if v:HasTag("critter") and v:IsHungry() and not v:IsOnOcean(true) and not IsPointCoveredByBlocker(x, y, z) then
            return v
        end
    end
end
local function IsPetCritterHungry(inst)
    local pets = inst.components.petleash:GetPets()
    for k, v in pairs(pets) do
        local x, y, z = v.Transform:GetWorldPosition()
        if v:HasTag("critter") and v:IsHungry() and not v:IsOnOcean(true) and not IsPointCoveredByBlocker(x, y, z) then
            return true
        end
    end

    return false
end

local function is_honey(ent)
    return ent.prefab == "honey"
end
local function GetFoodForCritter(inst)
    local honey = inst.components.inventory:FindItem(is_honey)

    if honey == nil then
        honey = SpawnPrefab("honey")
        inst.components.inventory:GiveItem(honey)
    end

    return honey
end

local function DoFeedPetCritterAction(inst)
    if IsPetCritterHungry(inst) then
        local buffered_action = BufferedAction(inst, GetFirstHungryPetCritter(inst), ACTIONS.FEED, GetFoodForCritter(inst))

        buffered_action:AddSuccessAction(function()
            inst.components.npc_talker:Chatter("HERMITCRAB_CRITTER_FEED", math.random(#STRINGS.HERMITCRAB_CRITTER_FEED))
		end)

        return buffered_action
    end
end

---------------------------------------------------------------------

local WANDER_DIST = 12
local LIGHTSOURCE_TAGS = { "lightsource" }
local function CanWanderAtPoint(pos)
    if not TheWorld.state.isday then
        for i, v in ipairs(TheSim:FindEntities(pos.x, pos.y, pos.z, WANDER_DIST, LIGHTSOURCE_TAGS)) do
            local x, y, z = v.Transform:GetWorldPosition()
            local light_radius = v.Light and v.Light:GetCalculatedRadius()
            local light_radius_sq = light_radius and light_radius * light_radius
            if light_radius_sq and distsq(pos.x, pos.z, x, z) < light_radius_sq then
                return true
            end
        end

        return false
    end

    return true
end

function HermitBrain:OnStart()

    local day = WhileNode( function() return TheWorld.state.isday or self.inst:AllNightTest() end, "IsDay",
        PriorityNode{
            WhileNode( function() return not self.inst.sg:HasStateTag("mandatory") end, "unfriendly",
                PriorityNode{
                    WhileNode(function() return not self.inst.sg:HasStateTag("busy") and self.inst.hermitcrab_skinrequest ~= nil and HasValidHome(self.inst) end, "skinrequest",
                        ChattyNode(self.inst, {
                            name = function(inst) return "HERMITCRAB_TALK_ONSKINREQUEST." .. inst:getgeneralfriendlevel() end,
                            chatterparams = CHATTERPARAMS_LOW,
                        }, DoAction(self.inst, GoHomeImmediatelyAction, "go home", true))),
                    IfNode(function() return IsPetCritterHungry(self.inst) end, "Is critter hungry",
                        DoAction(self.inst, DoFeedPetCritterAction, "feed critter", true, 10)),
                    IfNode(function() return self:SelectTeaShop() end, "go to tea shop",
						PriorityNode({
							IfNode(function() return self.inst.sg:HasStateTag("soakin") end, "exit hotspring",
								ActionNode(function() ExitHotSpring(self.inst) end)),
							FailIfSuccessDecorator(
								Leash(self.inst,
									function()
										local pos = self:GetSelectedTeaShopPos()
										if pos then
											return pos
										end
										self.inst.components.locomotor:Stop()
									end,
									function() return self.selected_tea_shop:GetPhysicsRadius(0) + 1.5 end,
									function() return self.selected_tea_shop:GetPhysicsRadius(0) + 1 end,
									true)),
							IfNode(function() return self:CheckSelectedTeaShop() end, "tea shop exists",
								ActionNode(function() self.selected_tea_shop:PushEventImmediate("hermitcrab_entered", { hermitcrab = self.inst }) end)),
						}, .25)),

                    WhileNode( function() return self.inst.comment_data ~= nil end, "comment",
                        DoAction(self.inst, DoCommentAction, "comment", true, 10 )),
                    ChattyNode(self.inst, {
                            name = function(inst) return "HERMITCRAB_ATTEMPT_TRADE."..inst.getgeneralfriendlevel(inst) end,
                            chatterparams = CHATTERPARAMS_LOW,
                        },
                        FaceEntity(self.inst, GetTraderFn, KeepTraderFn)),
                    FaceEntity(self.inst, GetTraderFn, KeepTraderFn),
                    IfNode( function() return runawaytest(self.inst) end, "unfriendly",
                        RunAway(self.inst, "player", START_RUN_DIST, STOP_RUN_DIST)),
                    IfNode( function() return self.inst.components.friendlevels.level > TUNING.HERMITCRAB.UNFRIENDLY_LEVEL end, "friendly",
                        FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn, 7)),
                    DoAction(self.inst, DoReel, "reel", true ),
                    IfNode( function() return not self.inst.sg:HasStateTag("alert")
                                        and not self.inst.sg:HasStateTag("npc_fishing")
                                        and not self.inst.sg:HasStateTag("busy")
                                        and not self.inst.components.locomotor.dest end, "Not Acting",
                        PriorityNode{
                            DoAction(self.inst, DoHarvestMeat, "meat harvest", true ),
                            DoAction(self.inst, DoHarvestBerries, "berry harvest", true ),
                            DoAction(self.inst, DoChairSit, "sit on chairs", true ),
                            DoAction(self.inst, DoFishingAction, "gone fishing", true ),
                            DoAction(self.inst, DoBottleToss, "bottle", true ),
							DoAction(self.inst, DoSoakin, "soak in hotspring", true),
							IfNode( function() return not self.inst.sg:HasAnyStateTag("sitting", "soakin") end, "not sitting or soaking in hotspring",
                                Wander(self.inst, GetHomePos, MAX_WANDER_DIST, nil, nil, nil, CanWanderAtPoint, {should_run = false})
                            ),
                        },0.5),
                },0.5),
        }, 0.5)

    local night = WhileNode( function() return not TheWorld.state.isday and not self.inst:AllNightTest() end, "IsNight",
        PriorityNode{
            RunAway(self.inst, "player", START_RUN_DIST, STOP_RUN_DIST, function(target) return ShouldRunAway(self.inst, target) end ),
            ChattyNode(self.inst, { name = "HERMITCRAB_GO_HOME", chatterparams = CHATTERPARAMS_LOW },
                WhileNode( function() return not TheWorld.state.iscaveday or not self.inst:IsInLight() end, "Cave nightness",
                    DoAction(self.inst, GoHomeAction, "go home", true ))),
            ChattyNode(self.inst, { name = "HERMITCRAB_PANIC", chatterparams = CHATTERPARAMS_LOW },
                Panic(self.inst)),
        }, 1)

    local root =
        PriorityNode(
        {
            WhileNode(function() return self.inst.sg.mem.teleporting end, "Teleporting",
                PriorityNode({
                    DoAction(self.inst, DoTalkQueue, "finish talking", true),
                    WaitNode(1),
                })
            ),
			WhileNode(function() return self.inst.sg:HasStateTag("soakin") end, "soaking in hotspring",
				PriorityNode{
					IfNode(function() return not self.inst.components.timer:TimerExists("soaktime") end, "exit hotspring",
						ActionNode(function() ExitHotSpring(self.inst) end)),
					ActionNode(function()
						if self.inst.components.npc_talker:haslines() and self.inst.sg.statemem.soakintalktask == nil then
							self.inst.components.npc_talker:donextline()
						end
					end),
				}),
            WhileNode( function() return BrainCommon.ShouldTriggerPanic(self.inst) end, "PanicHaunted",
                ChattyNode(self.inst, { name = "HERMITCRAB_PANICHAUNT", chatterparams = CHATTERPARAMS_LOW },
                    Panic(self.inst))),
			RunAway(self.inst, RUN_AWAY_FROM_PIG_PARAMS, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST ),

            IfNode( function() return not self.inst.sg:HasStateTag("busy") and TheWorld.state.israining and has_umbrella(self.inst) and not equipped_umbrella(self.inst) end, "umbrella",
                    DoAction(self.inst, EquipUmbrella, "umbrella", true )),
            IfNode( function() return not self.inst.sg:HasStateTag("busy") and not TheWorld.state.israining and equipped_umbrella(self.inst) end, "stop umbrella",
					DoAction(self.inst, UnEquipUmbrella, "stop umbrella", true )),
            IfNode( function() return not self.inst.sg:HasStateTag("busy") and TheWorld.state.issnowing and has_coat(self.inst) and not using_coat(self.inst) end, "coat",
                    DoAction(self.inst, EquipCoat, "coat", true )),
            IfNode( function() return not self.inst.sg:HasStateTag("busy") and not TheWorld.state.issnowing and using_coat(self.inst) end, "stop coat",
                    DoAction(self.inst, UnEquipBody, "stop coat", true )),

            DoAction(self.inst, DoThrow, "toss item", true ),
            DoAction(self.inst, DoTalkQueue, "finish talking", true ),
            day,
            night,
        }, .5)

    self.bt = BT(self.inst, root)
end

return HermitBrain

