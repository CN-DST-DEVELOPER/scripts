local DeckContainer = Class(function(self, inst)
    self.inst = inst

    self.cards = {}

    --self.on_card_added = nil
    --self.on_cards_added_bulk = nil
    --self.on_card_removed = nil

    self.inst:AddTag("deckcontainer")
end)

function DeckContainer:OnRemoveEntity()
    self.inst:RemoveTag("deckcontainer")
end
DeckContainer.OnRemoveFromEntity = DeckContainer.OnRemoveEntity

-- Deck combining and splitting
function DeckContainer:MergeDecks(other_deck, moved_count)
    moved_count = moved_count or other_deck:Count()
    local last_index -- Persist the index after the loop, in case we didn't merge the whole deck over.
    for i = 1, moved_count do
        last_index = i
        self:AddCard(other_deck.cards[i])
    end

    for _ = 1, last_index do
        other_deck:RemoveCard(1)
    end
end

function DeckContainer:SplitDeck(source_deck, num_to_get)
    for _ = 1, num_to_get do
        self:AddCard(source_deck:RemoveCard())
    end
    self:Reverse()

    if self.on_split_deck then
        self.on_split_deck(self.inst, source_deck.inst)
    end
end

-- Deck adding and removing
function DeckContainer:AddCard(id, position)
    if position then
        table.insert(self.cards, position, id)
    else
        table.insert(self.cards, id)
    end

    if self.on_card_added then
        self.on_card_added(self.inst, id)
    end
end

function DeckContainer:AddRandomCard()
    local id = (100 * math.random(4)) + math.random(13)
    self:AddCard(id)
end

function DeckContainer:AddCards(ids)
    -- Should we support positional bulk add? We don't need it... hmm.
    for _, id in ipairs(ids) do
        table.insert(self.cards, id)
    end

    if self.on_cards_added_bulk then
        self.on_cards_added_bulk(self.inst, ids)
    end
end

function DeckContainer:RemoveCard(position)
    local removed_id
    if position and position < #self.cards then
        removed_id = table.remove(self.cards, position)
    else
        removed_id = table.remove(self.cards)
    end

    if self.on_card_removed then
        self.on_card_removed(self.inst, removed_id)
    end

    if #self.cards == 0 then
        self.inst:Remove()
    end

    return removed_id
end

function DeckContainer:PeekCard(position)
    local deck_size = #self.cards
    if position ~= nil and position < deck_size then
        return self.cards[position]
    else
        return self.cards[deck_size]
    end
end

function DeckContainer:Shuffle()
    shuffleArray(self.cards)
    if self.on_deck_shuffled then
        self.on_deck_shuffled(self.inst)
    end
end

function DeckContainer:Reverse()
    table.reverse_inplace(self.cards)
end

function DeckContainer:Count()
    return #self.cards
end

-- Save/Load
function DeckContainer:OnSave()
    return {cards = self.cards}
end

function DeckContainer:OnLoad(data)
    if data.cards then
        ConcatArrays(self.cards, data.cards)
    end
end

-- Debug
function DeckContainer:GetDebugString()
    return string.format("%4d", self:Count())
end

return DeckContainer