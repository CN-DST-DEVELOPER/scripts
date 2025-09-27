local function onpipcount(self, pipcount)
    if self._card_id ~= -1 then
        local current_suit, current_pips = self:GetSuitAndPip()

        local digit_barrier, pip_mod = 1, pipcount
        while pip_mod > 0 do
            pip_mod = math.floor(pip_mod / 10)
            digit_barrier = digit_barrier * 10
        end
        self.pip_digit_barrier = digit_barrier

        self._card_id = (current_suit * digit_barrier) + current_pips
    end
end

local PlayingCard = Class(function(self, inst)
    self.inst = inst

    self._card_id = -1
    self.pip_count = TUNING.PLAYINGCARDS_NUM_PIPS
    self.pip_digit_barrier = 100

    --self.on_new_id

    self.inst:AddTag("playingcard")
end,
nil,
{
    pip_count = onpipcount,
})

function PlayingCard:OnRemoveEntity()
    self.inst:RemoveTag("playingcard")
end
PlayingCard.OnRemoveFromEntity = PlayingCard.OnRemoveEntity

function PlayingCard:SetID(id)
    self._card_id = id

    if self.on_new_id then
        self.on_new_id(self.inst, id)
    end
end

function PlayingCard:GetID()
    return self._card_id
end

function PlayingCard:GetSuit()
    return (self._card_id > 0 and math.floor(self._card_id / self.pip_digit_barrier))
        or 0
end

function PlayingCard:GetPips()
    return (self._card_id > 0 and math.fmod(self._card_id, self.pip_digit_barrier))
        or 0
end

function PlayingCard:GetSuitAndPip()
    return self:GetSuit(), self:GetPips()
end

-- Save/Load
function PlayingCard:OnSave()
    return {card_id = self._card_id}
end

function PlayingCard:OnLoad(data, newents)
    self._card_id = data.card_id
end

return PlayingCard