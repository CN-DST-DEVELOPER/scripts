local BALATRO_UTIL = require("prefabs/balatro_util")
local BALATRO_SCORE_UTILS = require("prefabs/balatro_score_utils")

local STRING_REWARDS_TYPES = {}

for k, v in pairs(STRINGS.BALATRO.JIMBO_REWARD_TYPES) do
    table.insert(STRING_REWARDS_TYPES, k)
end

local STRING_REWARDS_TYPES_IDS = table.invert(STRING_REWARDS_TYPES)

-------------------------------------------------------------------------------------------------------------------------------

local assets =
{
    Asset("ANIM", "anim/balatro_jokers.zip"),
    Asset("ANIM", "anim/balatro_machine.zip"),

    Asset("SCRIPT", "scripts/prefabs/balatro_util.lua"),
    Asset("SCRIPT", "scripts/prefabs/balatro_score_utils.lua"),
}

-------------------------------------------------------------------------------------------------------------------------------

local FADE_FRAMES = 5
local FADE_INTENSITY = .8
local FADE_RADIUS = 1.5
local FADE_FALLOFF = .5

local LIGHT_RADIUS = 1.2
local LIGHT_COLOUR = Vector3(235 / 255, 150 / 255, 100 / 255)
local LIGHT_INTENSITY = .8
local LIGHT_FALLOFF = .5

local REWARDS = {

	{
		{ string = "BEES",      loot = {{"killerbee",   4,  "BEEHIVE_ENABLED" }}    },
        { string = "HOUNDS",    loot = {{"hound",   2,      "HOUNDMOUND_ENABLED" }} },
        { string = "SPIDERS",   loot = {{"spider",  3,      "SPIDERDEN_ENABLED" }}  },
    },

	{ string = "RESOURCES", loot = { {"cutgrass",    1}, {"twigs", 1} }		 },
	{ string = "RESOURCES", loot = { {"cutstone",    1}, {"rope",  1} }		 },
	{ string = "BANANAS",   loot = { {"cave_banana", 2}               }		 },
	{ string = "BANANAS",   loot = { {"bananapop",   2}               }		 },
	{ string = "GOLD",      loot = { {"goldnugget",  2}               }		 },
	{ string = "GOLD",      loot = { {"goldnugget",  8}               }		 },
	{ string = "TREASURE",  loot = { {"redgem",      1}, {"bluegem", 1}, {"purplegem", 1}, {"goldnugget", 12} }		 },

    -- Run away prizes, keep at the bottom.
	{
		{ string = "BEES",      loot = {{"killerbee",   2,  "BEEHIVE_ENABLED" }}    },
        { string = "HOUNDS",    loot = {{"hound",   1,      "HOUNDMOUND_ENABLED" }} },
        { string = "SPIDERS",   loot = {{"spider",  1,      "SPIDERDEN_ENABLED" }}  },
    },
}


local function assertreward(reward, i)
   	assert(STRINGS.BALATRO.JIMBO_REWARD_TYPES[reward.string] ~= nil, string.format("Reward #%d doesn't have an entry at STRINGS.BALATRO.JIMBO_REWARD_TYPES, please add one. %s = \"TODO\"", i, reward.string or ""))
end

if BRANCH == "dev" then
    -- Making sure we have everything we need.
    assert((#REWARDS-1) == BALATRO_UTIL.MAX_SCORE, string.format("We need score rewards definitions for all ranks/scores! %d rewards ~= %d ranks", #REWARDS-1, BALATRO_UTIL.MAX_SCORE))

    for i, reward in ipairs(REWARDS) do
        if reward.string then
			assertreward(reward, i)
        else
        	for t,subreward in ipairs(reward)do
        		assertreward(subreward, i)
        	end
    	end
    end
end

-------------------------------------------------------------------------------------------------------------------------------

local function OnUpdateFlicker(inst, starttime)
    local time = (GetTime() - starttime) * 30
    local flicker = (math.sin(time) + math.sin(time + 2) + math.sin(time + 0.7777)) * .5 -- range = [-1 , 1]
    flicker = (1 + flicker) * .5 -- range = 0:1

    inst.Light:SetRadius(FADE_RADIUS + .1 * flicker)
end

-------------------------------------------------------------------------------------------------------------------------------

local function SpawnCardRewards(inst, doer, score, target)
    for i = 1, score do
        local range = 2+math.random()*0.5
        local offset = FindWalkableOffset(target, math.random()*360, range, 16)
        local newx, newy, newz = (target+offset):Get()

        local reward = TheWorld.components.playingcardsmanager:MakePlayingCard(nil, true)
        reward.Transform:SetPosition(newx, newy, newz)

        local fx = SpawnPrefab("die_fx")
        fx.Transform:SetPosition(newx, newy, newz)
        fx.Transform:SetScale(0.5,0.5,0.5)
    end

    if score > 5 then
        local range = 2+math.random()*0.5
        local offset = FindWalkableOffset(target, math.random()*360, range, 16)
        local newx, newy, newz = (target+offset):Get()

        local reward = TheWorld.components.playingcardsmanager:MakePlayingCard(nil, true)
        reward.Transform:SetPosition(newx, newy, newz)

        local range = 2+math.random()*0.5
        local offset = FindWalkableOffset(target, math.random()*360, range, 16)
        local newx, newy, newz = (target+offset):Get()

        local record = SpawnPrefab("record")
        record:SetRecord("balatro")
        record.Transform:SetPosition(newx, newy, newz)

        local fx = SpawnPrefab("die_fx")
        fx.Transform:SetPosition(newx, newy, newz)
        fx.Transform:SetScale(0.5,0.5,0.5)
    end

    BALATRO_UTIL.SetLightMode_Idle(inst)
    inst.components.activatable.inactive = true
    inst.rewarding = false
end

local function SpawnCardRewardSequence(inst, doer, score, target)
    inst.sg:GoToState("talk")
    inst.components.talker:Chatter("JIMBO_CARDS")

    inst:DoTaskInTime(2, SpawnCardRewards, doer, score, target)
end

local function SpawnRewards(inst, doer, score, loot)
    local pos = inst:GetPosition()

    local target = pos

    local pt = Vector3(doer.Transform:GetWorldPosition())

    local theta = inst:GetAngleToPoint(pt.x,pt.y,pt.z) * DEGREES
    local radius = 5

    local offset = FindWalkableOffset(pos, theta, radius, 1, false, true, nil, false, false)

    if offset then
        target = pos + offset
    end

    for t=1,loot[2] do
        local range = 1+math.random()*0,5
        local offset =  FindWalkableOffset(target, math.random()*360, range, 16)
        if offset then
            local reward = SpawnPrefab(loot[1])
            local newpos = target+offset

            reward.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
            if reward.components.combat then
                reward.components.combat:SetTarget(inst.doer)
            end
            local fx = SpawnPrefab("die_fx")
            fx.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
            fx.Transform:SetScale(0.5,0.5,0.5)
        end
    end
end

local function DoDelayedRewards(inst, doer, score)
	inst.sg:GoToState("talk")

 	local rewards = REWARDS[score]

    if rewards.string == nil then
    	rewards = rewards[math.random(1,#rewards)]
    end
    for i=1, #rewards.loot do
    	local loot = rewards.loot[i]

		local enabled = loot[3] and TUNING[loot[3]] or nil
   		if enabled == nil or enabled then
			inst.components.talker:Chatter("JIMBO_REWARD_"..score, STRING_REWARDS_TYPES_IDS[rewards.string] or 0)
			inst:DoTaskInTime(2, SpawnRewards, doer, score, loot)
		else
			inst.components.talker:Chatter("JIMBO_NO_REWARD")
		    BALATRO_UTIL.SetLightMode_Idle(inst)
		    inst.components.activatable.inactive = true
		    inst.rewarding = false
		end
	end

  	local pos = inst:GetPosition()
    local target = pos
    local pt = Vector3(doer.Transform:GetWorldPosition())
    local theta = inst:GetAngleToPoint(pt.x,pt.y,pt.z) * DEGREES
    local radius = 5
    local offset = FindWalkableOffset(pos, theta, radius, 1, false, true, nil, false, false)
    if offset then
        target = pos + offset
    end

  	if score > 3 and score ~= 9 and TheWorld.components.playingcardsmanager then
        inst:DoTaskInTime(3, SpawnCardRewardSequence, doer, score, target)
    else
        BALATRO_UTIL.SetLightMode_Idle(inst)
        inst.components.activatable.inactive = true
        inst.rewarding = false
    end
end

local function StartRewardsSequence(inst, doer, score)
	inst:DoTaskInTime(1, DoDelayedRewards, doer, score)
end

-------------------------------------------------------------------------------------------------------------------------------

local function OnActivated(inst, doer)
	inst.components.talker:ShutUp()

	inst.rewarding = true
	
    inst._currentgame.user = doer
    inst._currentgame.round = 1
    inst._currentgame.joker = nil
    inst._currentgame.jokerchoices = PickSome(BALATRO_UTIL.NUM_JOKER_CHOICES, shallowcopy(BALATRO_UTIL.AVAILABLE_JOKERS)) -- These are strings.
    inst._currentgame.carddeck = shallowcopy(BALATRO_UTIL.AVAILABLE_CARDS) -- These are card IDs, not IDs.
    inst._currentgame.selectedcards = PickSome(BALATRO_UTIL.NUM_SELECTED_CARDS, inst._currentgame.carddeck) -- These are card IDs, not IDs.
    inst._currentgame._lastselectedcards = shallowcopy(inst._currentgame.selectedcards)

    inst:ListenForEvent("onremove", inst.ondoerremoved, doer)
    inst:ListenForEvent("ms_closepopup", inst.onclosepopup, doer)
    inst:ListenForEvent("ms_popupmessage", inst.onpopupmessage, doer)

    doer.sg:GoToState("playingbalatro", { target = inst })

    if BALATRO_UTIL.DEBUG_MODE then
        local cards = {}
        local jokers = {}

        for i=1, #inst._currentgame.jokerchoices do
            jokers[#jokers+1] = BALATRO_UTIL.AVAILABLE_JOKER_IDS[inst._currentgame.jokerchoices[i]]
        end

        for i=1, #inst._currentgame.selectedcards do
            cards[#cards+1] = BALATRO_UTIL.AVAILABLE_CARD_IDS[inst._currentgame.selectedcards[i]]
        end

        BALATRO_UTIL.ServerDebugPrint("Starting game: ", cards, jokers)
    end
end

-------------------------------------------------------------------------------------------------------------------------------

-- Client decorations

local CARD_STATE = {
    DEAL = "DEAL",
    DISCARDING = "DISCARDING",
    NONE = "NONE",
    SHOWING = "SHOWING",
}

local NUM_CARDS = 5

local function CreateDeck(inst)
    local deck = {}

    for s=1, 4 do
        for n=1, 13 do
            table.insert(deck, s*100 + n)
        end
    end

    inst.deck = deck
end

local function DrawCard(inst)
    return table.remove(inst.deck, math.random(1, #inst.deck))
end

local function Card_PlayLocalSound(card, sound)
	if not (card.parent and card.parent.mutelocalcardsounds) then
		card.SoundEmitter:PlaySound(sound)
	end
end

local function Card_DoDrawVisuals(card)
	card.AnimState:OverrideSymbol("swap_card1", "balatro_machine", "swap_card_back")
	card.AnimState:OverrideSymbol("swap_suit1", "balatro_machine", "NULL")
    card.AnimState:OverrideSymbol("swap_number1", "balatro_machine", "NULL")

	card.AnimState:PlayAnimation("card_draw")
	Card_PlayLocalSound(card, "balatro/balatro_cabinet/cards_deal")
end

local function Card_DoDiscardVisuals(card)
    card.AnimState:PlayAnimation("card_discard")
	Card_PlayLocalSound(card, "balatro/balatro_cabinet/discard")
end

local function Card_OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()

	if parent and parent.highlightchildren then
		table.removearrayvalue(parent.highlightchildren, inst)
	end
end

local function Card_OnAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation("card_draw") then
        inst.AnimState:PlayAnimation("card_flip")

		Card_PlayLocalSound(inst, "balatro/balatro_cabinet/cards_flip")

        inst:DoTaskInTime(FRAMES*3, function()
            local suit = math.floor(inst.card/100)
            local num = inst.card - (suit * 100)

            inst.AnimState:OverrideSymbol("swap_card1", "balatro_machine", "swap_card_front")
            inst.AnimState:OverrideSymbol("swap_suit1", "balatro_machine", "suit"..suit)
            inst.AnimState:OverrideSymbol("swap_number1", "balatro_machine", "number"..num)
            inst.AnimState:SetSymbolMultColour("swap_suit1", inst.colors[suit][1], inst.colors[suit][2], inst.colors[suit][3], 1)
            inst.AnimState:SetSymbolMultColour("swap_number1", inst.colors[suit][1], inst.colors[suit][2], inst.colors[suit][3], 1)
        end)

    elseif inst.AnimState:IsCurrentAnimation("card_flip") then
        inst.AnimState:PlayAnimation("card_idle", true)

        if inst.last then
            inst.parent.cardstate = CARD_STATE.SHOWING
        end

    elseif inst.AnimState:IsCurrentAnimation("card_discard") then
        inst.AnimState:PlayAnimation("card_idle")
        inst.AnimState:OverrideSymbol("swap_card1", "balatro_machine", "NULL")
        inst.AnimState:OverrideSymbol("swap_suit1", "balatro_machine", "NULL")
        inst.AnimState:OverrideSymbol("swap_number1", "balatro_machine", "NULL")

        if inst.last then
            inst.parent.cardstate = CARD_STATE.NONE
        end
    end
end

local function Card_UpdateFn(inst)
    if inst.cardstate == CARD_STATE.NONE then
        CreateDeck(inst)

        inst.cardstate = CARD_STATE.DEAL

        for i=1, NUM_CARDS do
            inst.cardfx[i].card = DrawCard(inst)
			inst.cardfx[i]:DoTaskInTime((i-1) * 0.3, Card_DoDrawVisuals)
        end

    elseif inst.cardstate == CARD_STATE.SHOWING then
        inst.cardstate = CARD_STATE.DISCARDING

        for i=1, NUM_CARDS do
			inst.cardfx[i]:DoTaskInTime((i-1) * 0.3, Card_DoDiscardVisuals)
        end
    end
end

local function CreateCardFx(i)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddSoundEmitter()

    inst.AnimState:SetBank("balatro_machine")
    inst.AnimState:SetBuild("balatro_machine")
    inst.AnimState:PlayAnimation("card_idle")

    inst.AnimState:OverrideSymbol("swap_card1", "balatro_machine", "NULL")
    inst.AnimState:OverrideSymbol("swap_suit1", "balatro_machine", "NULL")
    inst.AnimState:OverrideSymbol("swap_number1", "balatro_machine", "NULL")

    if i == NUM_CARDS then
        inst.last = true
    end

    inst.colors = BALATRO_UTIL.COLORS

	inst.OnRemoveEntity = Card_OnRemoveEntity

    inst:ListenForEvent("animover", Card_OnAnimOver)

	return inst
end

local function CLIENT_SpawnFxCards(inst)
	inst.cardfx = {}
	inst.cardstate = CARD_STATE.NONE

	for i=1, NUM_CARDS do
		local fx = CreateCardFx(i)

        inst:AddChild(fx)
    	fx.Follower:FollowSymbol(inst.GUID, "swap_card"..i, 0, 0, 0)
    	fx.parent = inst

        table.insert(inst.cardfx, fx)
        table.insert(inst.highlightchildren, fx)
	end

	inst.cardtask = inst:DoPeriodicTask(3, Card_UpdateFn)
end

local function CLIENT_SpawnFrame(parent)
    local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddSoundEmitter()

    inst.AnimState:SetBank("balatro_machine")
    inst.AnimState:SetBuild("balatro_machine")
    inst.AnimState:PlayAnimation("frame_idle")

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(BALATRO_UTIL.UpdateLoop)

    BALATRO_UTIL.SetLightMode_Idle(inst)

    MakeSnowCovered(inst)

    inst.machine = parent -- Used in balatro_util.lua

    parent:AddChild(inst)
    table.insert(parent.highlightchildren, inst)

    return inst
end

-------------------------------------------------------------------------------------------------------------------------------

local function CLIENT_ResolveChatter(inst, strid, strtbl)
    local strtbl_value = STRINGS.BALATRO[strtbl:value()] -- Table or string.

    local id = strid:value()

    if checkstring(strtbl_value) then
        -- Try to do subfmt for JIMBO_REWARD_X strings using id in a questionable way.
        local type = STRING_REWARDS_TYPES[id]

        if type == nil then
            return strtbl_value
        end

        local reward = STRINGS.BALATRO.JIMBO_REWARD_TYPES[type]

        if reward ~= nil then
            return subfmt(strtbl_value, { reward = reward })
        end

        return strtbl_value
    end

    if strtbl_value ~= nil and strtbl_value[1] ~= nil then
        -- strtbl is an array, just index it.

        return strtbl_value[id]
    end
end

-------------------------------------------------------------------------------------------------------------------------------

-- Popup callbacks

local function MakeMachineActivatable(inst)
    inst.components.activatable.inactive = true
    inst.rewarding = false
end

local function NoRewardCallback(inst, line, delay)
    inst.sg:GoToState("talk")
    inst.components.talker:Chatter(line)

    inst:DoTaskInTime(delay or 2, MakeMachineActivatable)
end

local function EndInteraction(inst, doer)
    if inst._currentgame.user ~= doer then
        return -- Not our current user!
    end

    local score = inst._currentgame.score

    if score == nil and inst._currentgame.joker ~= nil then
        -- Game has started, punish people for running away.
        score = #REWARDS
    end

    BALATRO_UTIL.ServerDebugPrint("Final score: ", nil, nil, score)

    if score ~= nil and REWARDS[score] ~= nil then
        BALATRO_UTIL.SetLightMode_Blink(inst)
        StartRewardsSequence(inst, doer, score)
    else
        inst:DoTaskInTime(1, NoRewardCallback, "JIMBO_CLOSED")
    end

    inst:RemoveEventCallback("onremove", inst.ondoerremoved, doer)
    inst:RemoveEventCallback("ms_closepopup", inst.onclosepopup, doer)
    inst:RemoveEventCallback("ms_popupmessage", inst.onpopupmessage, doer)

    doer:PushEventImmediate("ms_endplayingbalatro")

    inst._currentgame = {}
end

local function OnClosePopup(inst, doer, data)
    if data.popup == POPUPS.BALATRO then
        EndInteraction(inst, doer)
    end
end

local function OnPopupMessage(inst, doer, data)
    if data.popup ~= POPUPS.BALATRO then
        return
    end

    if inst._currentgame.user ~= doer then
        return -- Not our current user!
    end

    local args = data ~= nil and data.args or nil

    if args == nil then
        return -- Invalid data.
    end

    local message_id = args[1]

    if not checkuint(message_id) then
        return -- Invalid data.
    end

    if message_id == BALATRO_UTIL.POPUP_MESSAGE_TYPE.DISCARD_CARDS then
        if inst._currentgame.joker == nil then
            return -- Joker hasn't been choosen yet...
        end

        if inst._currentgame.round >= 3 then
            return -- Game is over, don't accept new discards...
        end

        local byte = args[2]

        if byte == nil or not checkuint(byte) then
            return -- Invalid data.
        end

        inst._currentgame.round = inst._currentgame.round + 1

        local discarddata = BALATRO_UTIL.DecodeDiscardData(byte)

        inst._currentgame.joker:OnCardsDiscarded(discarddata)

        -- NOTES(DiogoW): inst._currentgame.joker.cards is the same table as inst._currentgame.selectedcards

        if byte ~= 0 then -- Not a skip.
            inst._currentgame._lastselectedcards = shallowcopy(inst._currentgame.selectedcards)

            for i=1, #discarddata do
                if discarddata[i] == true then
                    inst._currentgame.selectedcards[i] = table.remove(inst._currentgame.carddeck, math.random(#inst._currentgame.carddeck))
                end
            end

            inst._currentgame.joker:OnNewCards(inst._currentgame._lastselectedcards, discarddata)

            local data = {}

            for i=1, #inst._currentgame.selectedcards do
                data[i] = BALATRO_UTIL.AVAILABLE_CARD_IDS[inst._currentgame.selectedcards[i]]
            end

            BALATRO_UTIL.ServerDebugPrint("Sending selection back: ", data)

            -- Send back the new selection.
            POPUPS.BALATRO:SendMessageToClient(doer, BALATRO_UTIL.POPUP_MESSAGE_TYPE.NEW_CARDS, unpack(data))
        end

        if inst._currentgame.round >= 3 then -- Game is over.
            inst._currentgame.score = inst._currentgame.joker:GetFinalScoreRank()
        end

    elseif message_id == BALATRO_UTIL.POPUP_MESSAGE_TYPE.CHOOSE_JOKER then
        local joker_id = args[2]

        if joker_id == nil or not checkuint(joker_id) then
            return -- Invalid data.
        end

        if inst._currentgame.joker ~= nil then
            return -- Invalid, joker already selected!
        end

        if not table.contains(inst._currentgame.jokerchoices, BALATRO_UTIL.AVAILABLE_JOKERS[joker_id]) then
            return -- Invalid, not one of the given options...
        end

        local JokerClass = BALATRO_SCORE_UTILS.JOKERS[BALATRO_UTIL.AVAILABLE_JOKERS[joker_id]]

        inst._currentgame.joker = JokerClass(inst._currentgame.selectedcards)
        inst._currentgame.joker:OnGameStarted()

        BALATRO_UTIL.ServerDebugPrint("Setting up joker: ", nil, { joker_id })
    end
end

local function GetInitialPopupData(inst, doer)
    local ret = {
        -- joker 1 id
        -- joker 2 id
        -- joker 3 id
        -- card 1 id
        -- card 2 id
        -- card 3 id
        -- card 4 id
        -- card 5 id
    }

    for i=1, #inst._currentgame.jokerchoices do
        ret[#ret+1] = BALATRO_UTIL.AVAILABLE_JOKER_IDS[inst._currentgame.jokerchoices[i]]
    end

    for i=1, #inst._currentgame.selectedcards do
        ret[#ret+1] = BALATRO_UTIL.AVAILABLE_CARD_IDS[inst._currentgame.selectedcards[i]]
    end

    return ret
end

-------------------------------------------------------------------------------------------------------------------------------

function Getactivateverb()
	return "PLAY_WITH"
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .8)

    inst.MiniMapEntity:SetPriority(5)
    inst.MiniMapEntity:SetIcon("balatro_machine.png")

    inst.Light:SetFalloff(LIGHT_FALLOFF)
    inst.Light:SetIntensity(LIGHT_INTENSITY)
    inst.Light:SetRadius(LIGHT_RADIUS)
    inst.Light:SetColour(0.3, 0.45, 0.55)
    inst.Light:EnableClientModulation(true)

    inst._flickertask = inst:DoPeriodicTask(.1, OnUpdateFlicker, 0, GetTime())

    inst.AnimState:SetBank("balatro_machine")
    inst.AnimState:SetBuild("balatro_machine")
    inst.AnimState:PlayAnimation("idle")

    inst.GetActivateVerb = Getactivateverb

    for i=1, NUM_CARDS do
        inst.AnimState:OverrideSymbol("swap_card"..i, "balatro_machine", "NULL")
        inst.AnimState:OverrideSymbol("swap_suit"..i, "balatro_machine", "NULL")
        inst.AnimState:OverrideSymbol("swap_number"..i, "balatro_machine", "NULL")
    end

    inst:AddTag("structure")

    inst:AddComponent("talker")
    inst.components.talker.offset = Vector3(0, -800, 0)
    inst.components.talker.font = TALKINGFONT_TRADEIN
    inst.components.talker.resolvechatterfn = CLIENT_ResolveChatter
    inst.components.talker:MakeChatter()

    inst.light_mode = net_tinybyte(inst.GUID, "balatro_machine.light_mode") -- Used in balatro_utils.lua
    inst.light_mode:set(BALATRO_UTIL.LIGHTMODES.IDLE1)

    if not TheNet:IsDedicated() then
        inst.highlightchildren = {}

        CLIENT_SpawnFxCards(inst)
        CLIENT_SpawnFrame(inst)

        inst:AddComponent("pointofinterest")
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._currentgame = {}

    inst.GetInitialPopupData = GetInitialPopupData

    inst.ondoerremoved = function(doer)       EndInteraction(inst, doer)     end
    inst.onclosepopup  = function(doer, data) OnClosePopup(inst, doer, data) end
    inst.onpopupmessage  = function(doer, data) OnPopupMessage(inst, doer, data) end

	inst.scrapbook_anim = "scrapbook"

    inst:SetStateGraph("SGbalatro_machine")

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    inst:AddComponent("timer")

    inst:AddComponent("activatable")
    inst.components.activatable.OnActivate = OnActivated
    inst.components.activatable.standingaction = true

    return inst
end

return Prefab("balatro_machine", fn, assets)
