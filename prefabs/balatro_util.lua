-- NOTES(DiogoW): Up to 7 modes, see light_mode net_tinybyte in balatro_machine.lua
local LIGHTMODES = {
    IDLE1 = 1,
    BLINK = 2,
}

local UI_LIGHTMODE = LIGHTMODES.IDLE1

local COLORS =
{
    {  0/255,   0/255,   0/255}, -- spades
    {171/255,  64/255,  61/255}, -- hearts
    {  0/255,  95/255,  15/255}, -- clubs
    { 25/255, 135/255, 195/255}, -- diamonds
}

----------------------------------------------------------------------------------------------------------------------

local SCORE_RANKS = {
    0,   -- 1
    120, -- 2
    150, -- 3
    200, -- 4
    400, -- 5
    600, -- 6
    1000, -- 7
    1400, -- 8
}

local MAX_SCORE = #SCORE_RANKS

local POPUP_MESSAGE_TYPE = {
    CHOOSE_JOKER = 1,
    DISCARD_CARDS = 2,
    NEW_CARDS = 3,
}

local NUM_JOKER_CHOICES = 3
local NUM_SELECTED_CARDS = 5 -- NOTES(DiogoW): Max 8, see encoding code below.

local AVAILABLE_JOKERS = ExceptionArrays(DST_CHARACTERLIST, SEAMLESSSWAP_CHARACTERLIST)
local AVAILABLE_JOKER_IDS = table.invert(AVAILABLE_JOKERS)

local PIP_DIGIT_BARRIER = 100

local AVAILABLE_CARDS = {}

for suit = 1, TUNING.PLAYINGCARDS_NUM_SUITS do
    for pip = 1, TUNING.PLAYINGCARDS_NUM_PIPS do
        table.insert(AVAILABLE_CARDS, (suit * PIP_DIGIT_BARRIER) + pip)
    end
end

local AVAILABLE_CARD_IDS = table.invert(AVAILABLE_CARDS)

----------------------------------------------------------------------------------------------------------------------

local function EncodeDiscardData(data)
    local byte = 0

    for i = 1, NUM_SELECTED_CARDS do
        if data[i] == true then
            byte = bit.bor(byte, bit.lshift(1, i - 1))
        end
    end

    return byte
end

local function DecodeDiscardData(byte)
    local data = {}

    for i = 1, NUM_SELECTED_CARDS do
        data[i] = bit.band(byte, bit.lshift(1, i - 1)) ~= 0
    end

    return data
end

----------------------------------------------------------------------------------------------------------------------

local NUM_LIGHTS = 18
local SOUND_NAME = "sound_loop"

-- Called be the UI machine.
local function SetAnimState(inst, animstate)
    inst.animstate_lights = animstate
end

----------------------------------------------------------------------------------------------------------------------

-- These are called by the balatro_machine or the UI machine.

local function SERVER_SetLightMode_Idle1(inst)
    if inst.light_mode ~= nil then
        inst.light_mode:set(LIGHTMODES.IDLE1)
    else
        UI_LIGHTMODE = LIGHTMODES.IDLE1
    end

    if inst.SoundEmitter ~= nil and not inst.SoundEmitter:PlayingSound(SOUND_NAME) then
        inst.SoundEmitter:PlaySound("balatro/balatro_cabinet/light_blink_LP", SOUND_NAME)
    end
end

local function SERVER_SetLightMode_Blink(inst)
    if inst.light_mode ~= nil then
        inst.light_mode:set(LIGHTMODES.BLINK)
    else
        UI_LIGHTMODE = LIGHTMODES.BLINK
    end

    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:KillSound(SOUND_NAME)
    end
end

----------------------------------------------------------------------------------------------------------------------

-- These are called by the balatro_machine FRAME or the UI machine FRAME.

local function LightMode_Idle1Loop(inst, dt)
    if inst.lightdelay > 0 then
        inst.lightdelay = inst.lightdelay - dt

        return
    end

    local animstate = inst.animstate_lights or inst.AnimState

    for i=1, NUM_LIGHTS do
        local symbol = "light"..i

        if (i - inst.currentcycle) % 3 == 0 then
            animstate:OverrideSymbol(symbol, "balatro_machine", "swap_light_on")
            animstate:SetSymbolLightOverride(symbol, 1)
        else
            animstate:ClearOverrideSymbol(symbol)
            animstate:SetSymbolLightOverride(symbol, 0)
        end
    
    end

    inst.currentcycle = (inst.currentcycle % 3) + 1

    inst.lightdelay = .7
end

local function LightMode_BlinkLoop(inst, dt)
    if inst.lightdelay > 0 then
        inst.lightdelay = inst.lightdelay - dt

        return
    end

    local animstate = inst.animstate_lights or inst.AnimState

    for i=1, NUM_LIGHTS do
        local symbol = "light"..i

        if inst.currentcycle == 1 then
            animstate:OverrideSymbol(symbol, "balatro_machine", "swap_light_on")
            animstate:SetSymbolLightOverride(symbol, 1)
        else
            animstate:ClearOverrideSymbol(symbol)
            animstate:SetSymbolLightOverride(symbol, 0)
        end
    end

    inst.currentcycle = (inst.currentcycle) % 2 + 1
    inst.lightdelay = .3
end

local function UpdateLoop(inst, dt)
    local mode = inst.machine ~= nil and inst.machine.light_mode ~= nil and inst.machine.light_mode:value() or UI_LIGHTMODE

    if inst.lastmode ~= mode then
        inst.lightdelay = 0
        inst.currentcycle = 1
    end

    if mode == LIGHTMODES.IDLE1 then
        LightMode_Idle1Loop(inst, dt)

        inst.lastmode = LIGHTMODES.IDLE1

    elseif mode == LIGHTMODES.BLINK then
        LightMode_BlinkLoop(inst, dt)

        inst.lastmode = LIGHTMODES.BLINK
    end
end

----------------------------------------------------------------------------------------------------------------------

local DEBUG_MODE = BRANCH == "dev"

local function _MakeIdListReadable(ids, lookup)
    local ret = " "

    if not ids then
        return ret
    end

    local count = #ids

    if count > 1 then
        ret = ret .. "[ "
    end

    for i, id in ipairs(ids) do
        ret = ret .. lookup[id]

        if i ~= count then
            ret = ret .. ", "
        end
    end

    if count > 1 then
        ret = ret .. " ]"
    end

    return ret
end

local function ServerDebugPrint(message, card_ids, joker_ids, ...)
    if not DEBUG_MODE then
        return
    end

    print(
        string.format(
            "[SERVER] Balatro - %s%s%s",
            message,
            _MakeIdListReadable(card_ids, AVAILABLE_CARDS),
            _MakeIdListReadable(joker_ids, AVAILABLE_JOKERS)
        ),
        ...
    )
end

local function ClientDebugPrint(message, card_ids, joker_ids, ...)
    if not DEBUG_MODE then
        return
    end

    print(
        string.format(
            "[CLIENT] Balatro - %s%s%s",
            message,
            _MakeIdListReadable(card_ids, AVAILABLE_CARDS),
            _MakeIdListReadable(joker_ids, AVAILABLE_JOKERS)
        ),
        ...
    )end

----------------------------------------------------------------------------------------------------------------------

return {
    COLORS = COLORS,
    LIGHTMODES = LIGHTMODES,
    UpdateLoop = UpdateLoop,
    SetLightMode_Idle = SERVER_SetLightMode_Idle1,
    SetLightMode_Blink = SERVER_SetLightMode_Blink,
    SetAnimState = SetAnimState,

    SCORE_RANKS = SCORE_RANKS,
    MAX_SCORE = MAX_SCORE,

    AVAILABLE_JOKERS = AVAILABLE_JOKERS,
    AVAILABLE_JOKER_IDS = AVAILABLE_JOKER_IDS,
    NUM_JOKER_CHOICES = NUM_JOKER_CHOICES,
    NUM_SELECTED_CARDS = NUM_SELECTED_CARDS,

    AVAILABLE_CARDS = AVAILABLE_CARDS,
    AVAILABLE_CARD_IDS = AVAILABLE_CARD_IDS,

    POPUP_MESSAGE_TYPE = POPUP_MESSAGE_TYPE,

    EncodeDiscardData = EncodeDiscardData,
    DecodeDiscardData = DecodeDiscardData,

    ServerDebugPrint = ServerDebugPrint,
    ClientDebugPrint = ClientDebugPrint,

    DEBUG_MODE = DEBUG_MODE,
}