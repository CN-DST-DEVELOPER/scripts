local BALATRO_UTIL = require("prefabs/balatro_util")

local SUITS =
{
    SPADES = 1,
    HEARTS = 2,
    CLUBS = 3,
    DIAMONDS = 4,
}

local HIGH_STRAIGHT = {1, 10, 11, 12, 13} -- Already sorted.

--------------------------------------------------------------------------------------------------------------------------

local BaseJoker = Class(function(self, cards)
    self._chips = 0
    self._mult = 0

    self.cards = cards
end)

--------------------------------------------------------------------------------------------------------------------------

function BaseJoker:AddMult(amt)
    self._mult = math.max(0, self._mult + amt)
end

function BaseJoker:AddChips(amt)
    self._chips = math.max(0, self._chips + amt)
end

function BaseJoker:EvaluateHand()
    local suit_counts = {}
    local num_counts = {}
    local nums = {}
    local is_flush = true

    local NUM_CARDS = BALATRO_UTIL.NUM_SELECTED_CARDS
    local first_suit = self:GetCardSuitByIndex(1)

    -- Count suits and numbers
    for i = 1, NUM_CARDS do
        local suit = self:GetCardSuitByIndex(i)
        local num = self:GetCardNumberByIndex(i)

        suit_counts[suit] = (suit_counts[suit] or 0) + 1
        num_counts[num] = (num_counts[num] or 0) + 1

        table.insert(nums, num)

        if suit ~= first_suit then
            is_flush = false
        end
    end

    -- Count pairs, trips, quads
    local _pairs, three_of_kind, four_of_kind = 0, 0, 0
    for num, count in pairs(num_counts) do
        if count == 4 then
            four_of_kind = num
        elseif count == 3 then
            three_of_kind = num
        elseif count == 2 then
            _pairs = _pairs + 1
        end
    end

    -- Sort numbers
    table.sort(nums)

    -- Check straight
    local is_straight = true
    for i = 1, NUM_CARDS - 1 do
        if nums[i + 1] - nums[i] ~= 1 then
            is_straight = false
            break
        end
    end

	-- Check high straight
    local is_royal = true
    for i = 1, NUM_CARDS do
		if nums[i] ~= HIGH_STRAIGHT[i] then
            is_royal = false
            break
        end
    end
	if is_royal then
		is_straight = true
	end

    -- Assign score
    local score
    if is_flush and is_royal then
        score = 10 -- Royal Flush
    elseif is_flush and is_straight then
        score = 9 -- Straight Flush
    elseif four_of_kind ~= 0 then
        score = 8
    elseif three_of_kind ~= 0 and _pairs > 0 then
        score = 7 -- Full House
    elseif is_flush then
        score = 6
    elseif is_straight then
        score = 5
    elseif three_of_kind ~= 0 then
        score = 4
    elseif _pairs >= 2 then
        score = 3
    elseif _pairs == 1 then
        score = 2
    else
        score = 1
    end

    return score
end

function BaseJoker:CalculateRank(score)
    for i=#BALATRO_UTIL.SCORE_RANKS, 1, -1 do
        if score >= BALATRO_UTIL.SCORE_RANKS[i] then
            return i
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

function BaseJoker:GetCardSuitByIndex(index, handoverride)
    handoverride = handoverride or self.cards

    return math.floor(handoverride[index]/100)
end

function BaseJoker:GetCardNumberByIndex(index, handoverride)
    handoverride = handoverride or self.cards

    return handoverride[index] % 100
end

function BaseJoker:CountUniqueSuits()
    local suits = {}
    local suitcount = 0

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        suits[self:GetCardSuitByIndex(i)] = true
    end

    return GetTableSize(suits)
end

function BaseJoker:CountUniqueDiscardedSuits(discardeddata)
    local suits = {}
    local suitcount = 0

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            suits[self:GetCardSuitByIndex(i)] = true
        end
    end

    return GetTableSize(suits)
end

--------------------------------------------------------------------------------------------------------------------------

-- These should be implements by the child class, when needed!

function BaseJoker:OnGameStarted()
    -- Pass
end

function BaseJoker:OnCardsDiscarded()
    -- Pass
end

function BaseJoker:OnNewCards(oldcards, discardeddata)
    -- Pass
end

function BaseJoker:OnGameFinished()
    -- Pass
end

--------------------------------------------------------------------------------------------------------------------------

function BaseJoker:GetFinalScoreRank()
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        local num = self:GetCardNumberByIndex(i)

        if num == 1 then
            num = 11
        end

        self:AddChips(num)
    end

    self:OnGameFinished()

    local handscore = self:EvaluateHand()

    self:AddMult(handscore)

    BALATRO_UTIL.ServerDebugPrint("Final numeric score: ", nil, nil, self._chips * self._mult)

    return self:CalculateRank(self._chips * self._mult)
end
--------------------------------------------------------------------------------------------------------------------------

local WalterJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WalterJoker:OnCardsDiscarded(discardeddata)
    local suitcount = self:CountUniqueDiscardedSuits(discardeddata)

    if suitcount > 0 then
        self:AddChips(15 * suitcount)
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WandaJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WandaJoker:OnGameStarted()
    self:AddChips(80)
end

function WandaJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            self:AddChips(-15)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WarlyJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WarlyJoker:OnGameFinished()
    local suitcount = self:CountUniqueSuits()

    if suitcount >= TUNING.PLAYINGCARDS_NUM_SUITS then
        self:AddMult(4)
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WathgrithrJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WathgrithrJoker:OnGameFinished()
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if self:GetCardSuitByIndex(i) == SUITS.SPADES then
            self:AddChips(25)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WaxwellJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WaxwellJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            if self:GetCardSuitByIndex(i) == SUITS.HEARTS then
                self:AddMult(1)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WebberJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)

    self.RED_SUITS   = { [SUITS.HEARTS] = true, [SUITS.DIAMONDS] = true }
    self.BLACK_SUITS = { [SUITS.CLUBS]  = true, [SUITS.SPADES]   = true }
end)

function WebberJoker:OnNewCards(oldcards, discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            local oldsuit = self:GetCardSuitByIndex(i, oldcards)
            local newsuit = self:GetCardSuitByIndex(i)

            if self.RED_SUITS[oldsuit] and self.BLACK_SUITS[newsuit] then
                self:AddMult(2)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WendyJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WendyJoker:OnNewCards(oldcards, discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            local oldsuit = self:GetCardSuitByIndex(i, oldcards)
            local newsuit = self:GetCardSuitByIndex(i)

            if oldsuit == newsuit then
                self:AddChips(5)
                self:AddMult(2)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WesJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)

    self._lasthandscore = nil
end)

function WesJoker:OnCardsDiscarded()
    self._lasthandscore = self:EvaluateHand()
end

function WesJoker:OnNewCards(oldcards)
    if self._lasthandscore > self:EvaluateHand() then
        self:AddChips(30)
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WickerbottomJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WickerbottomJoker:OnGameFinished()
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if self:GetCardNumberByIndex(i) == 12 then
            self:AddMult(1)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WillowJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WillowJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            if self:GetCardNumberByIndex(i) > 10 then
                self:AddChips(20)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WilsonJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WilsonJoker:OnGameFinished()
    local numpairs = 0
    local card_indexes = {}

    local currentindex, currentnum -- Speed ups.

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        table.insert(card_indexes, i)
    end

    while #card_indexes >= 2 do -- While there're at least 2 cards to test.
        currentindex = table.remove(card_indexes, 1)
        currentnum = self:GetCardNumberByIndex(currentindex)

        for _, index in ipairs(card_indexes) do
            if self:GetCardNumberByIndex(index) == currentnum then
                numpairs = numpairs + 1

                table.remove(card_indexes, index)

                break -- Found a pair, break the loop.
            end
        end
    end

    if numpairs > 0 then
        self:AddMult(3 * numpairs)
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WinonaJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WinonaJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do

        local suit = self:GetCardSuitByIndex(i)

        if not discardeddata[i] and suit == SUITS.HEARTS then
            self:AddMult(1)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WolfgangJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WolfgangJoker:OnGameFinished()
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if self:GetCardNumberByIndex(i) == 13 then
            self:AddChips(25)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WoodieJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WoodieJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        if discardeddata[i] then
            self:AddChips(7)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WormwoodJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WormwoodJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        local suit = self:GetCardSuitByIndex(i)

        if not discardeddata[i] and suit == SUITS.CLUBS then
            self:AddChips(15)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WortoxJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WortoxJoker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        local suit = self:GetCardSuitByIndex(i)

        if discardeddata[i] and suit == SUITS.HEARTS then
            self:AddChips(15)
        end
    end
end

function WortoxJoker:OnGameFinished()
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        local suit = self:GetCardSuitByIndex(i)

        if suit == SUITS.HEARTS then
            self:AddChips(-11)
            self:AddMult(1)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------

local WurtJoker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)
end)

function WurtJoker:OnCardsDiscarded(discardeddata)
    local facecards = 0

    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        local num = self:GetCardNumberByIndex(i)

        if not discardeddata[i] and num > 10 then
            facecards = facecards + 1
        end
    end

    if facecards > 0 then
        self:AddChips(facecards * facecards * 10) -- Not a typo, you get 10 chips per face card, for every face card you have.
    end
end

--------------------------------------------------------------------------------------------------------------------------

local Wx78Joker = Class(BaseJoker, function(self, cards)
    BaseJoker._ctor(self, cards)

    self._lastdiscardeddata = nil
end)

function Wx78Joker:OnCardsDiscarded(discardeddata)
    for i=1, BALATRO_UTIL.NUM_SELECTED_CARDS do
        -- If kept for one round and then discarded.
        if self._lastdiscardeddata ~= nil and not self._lastdiscardeddata[i] and discardeddata[i] then
            local suit = self:GetCardSuitByIndex(i)

            if suit == SUITS.HEARTS then
                self:AddMult(2)
            end
        end
    end

    self._lastdiscardeddata = discardeddata
end

--------------------------------------------------------------------------------------------------------------------------

local JOKERS = {
    walter       = WalterJoker,
    wanda        = WandaJoker,
    warly        = WarlyJoker,
    wathgrithr   = WathgrithrJoker,
    waxwell      = WaxwellJoker,
    webber       = WebberJoker,
    wendy        = WendyJoker,
    wes          = WesJoker,
    wickerbottom = WickerbottomJoker,
    willow       = WillowJoker,
    wilson       = WilsonJoker,
    winona       = WinonaJoker,
    wolfgang     = WolfgangJoker,
    woodie       = WoodieJoker,
    wormwood     = WormwoodJoker,
    wortox       = WortoxJoker,
    wurt         = WurtJoker,
    wx78         = Wx78Joker,
}

--------------------------------------------------------------------------------------------------------------------------

return {
    JOKERS = JOKERS,
}
