--------------------------------------------------------------------------
--[[ PlayingCardsManager class definition ]]
--------------------------------------------------------------------------

return Class(function(self, inst)

assert(TheWorld.ismastersim, "PlayingCardsManager should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

-- Represents the 10s digit that is 1 further left than the pip count,
-- to separate the pip and suit numbers in the card IDs.
-- We could calculate this with a division loop but, why bother.
local PIP_DIGIT_BARRIER = 100

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

self.inst = inst

local available_card_ids = {}
for suit = 1, TUNING.PLAYINGCARDS_NUM_SUITS do
    for pip = 1, TUNING.PLAYINGCARDS_NUM_PIPS do
        table.insert(available_card_ids, (suit * PIP_DIGIT_BARRIER) + pip)
    end
end

local decks = {}

--------------------------------------------------------------------------
--[[ Event listeners ]]
--------------------------------------------------------------------------

local function deck_onremove(deck)
    if not deck then return end

    local deck_deckcontainer = deck.components.deckcontainer
    if not deck_deckcontainer then return end

    for _, card in pairs(deck_deckcontainer.cards) do
        table.insert(available_card_ids, card)
    end

    decks[deck] = nil
end

local function card_onremove(card)
    if not card then return end

    local card_id = card._cardid
    if card_id then
        table.insert(available_card_ids, card_id)
    end

    decks[card] = nil
end

--------------------------------------------------------------------------
--[[ Save / Load ]]
--------------------------------------------------------------------------

function self:OnSave()
    local data = {
        available_ids = available_card_ids,
    }

    if #decks > 0 then
        local ents = {}
        data.living_decks = {}
        for _, deck in pairs(decks) do
            table.insert(data.living_decks, deck.GUID)
            table.insert(ents, deck.GUID)
        end

        return data, ents
    else
        return data
    end
end

function self:OnLoad(data)
	if data and data.available_ids then
        available_card_ids = data.available_ids
	end
end

function self:LoadPostPass(newents, data)
    if data.living_decks then
        for _, deck_GUID in pairs(data.living_decks) do
            local deck = newents[deck_GUID].entity
            decks[deck] = true
            deck:ListenForEvent("onremove", deck_onremove)
        end
    end
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:MakeDeck(size)
    size = math.max(size or 1, 1)

    local deck = SpawnPrefab("deck_of_cards")

    local card_ids = {}
    for _ = 1, size do
        local next_card_id = (#available_card_ids > 0 and table.remove(available_card_ids, math.random(#available_card_ids)))
            or (math.random(TUNING.PLAYINGCARDS_NUM_SUITS) * PIP_DIGIT_BARRIER + math.random(TUNING.PLAYINGCARDS_NUM_PIPS))
        table.insert(card_ids, next_card_id)
    end
    deck.components.deckcontainer:AddCards(card_ids)

    deck:ListenForEvent("onremove", deck_onremove)

    decks[deck] = true

    return deck
end

function self:MakePlayingCard(id, facedown)
    local card = SpawnPrefab("playing_card")

    if facedown then
        card._faceup = false
    end

    card.components.playingcard:SetID(id
        or (#available_card_ids > 0 and table.remove(available_card_ids, math.random(#available_card_ids)))
        or (math.random(TUNING.PLAYINGCARDS_NUM_SUITS) * PIP_DIGIT_BARRIER + math.random(TUNING.PLAYINGCARDS_NUM_PIPS))
    )

    card:ListenForEvent("onremove", card_onremove)

    decks[card] = true

    return card
end

function self:RegisterPlayingCard(card)
    card.components.playingcard:SetID((#available_card_ids > 0 and table.remove(available_card_ids, math.random(#available_card_ids)))
        or (math.random(TUNING.PLAYINGCARDS_NUM_SUITS) * PIP_DIGIT_BARRIER + math.random(TUNING.PLAYINGCARDS_NUM_PIPS))
    )
    card:ListenForEvent("onremove", card_onremove)
    decks[card] = true

    return card
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
    local s = ""

    if available_card_ids then
        s = s .. "Available Cards: "
        for _, card_id in pairs(available_card_ids) do
            s = s .. card_id .. "; "
        end
    end

    return s
end

-- Available IDs is save/loaded; this let's us reset the id table,
-- without needing to regenerate the world, if we want to change suit/pip counts.
function self:Debug_ResetAvailableIDs()
    available_card_ids = {}
    for suit = 1, NUM_SUITS do
        for pip = 1, NUM_PIPS do
            table.insert(available_card_ids, (suit * PIP_DIGIT_BARRIER) + pip)
        end
    end
end

end)