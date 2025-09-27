local deck_assets =
{
    Asset("ANIM", "anim/deck_of_cards.zip"),

    Asset("ATLAS", "images/playingcards.xml"),
    Asset("IMAGE", "images/playingcards.tex"),

    Asset("INV_IMAGE", "deckofcards0"),
    Asset("INV_IMAGE", "deckofcards1"),
    Asset("INV_IMAGE", "deckofcards2"),
    Asset("INV_IMAGE", "deckofcards3"),
}

if rawget(_G, "RegisterInventoryItemAtlas") then
    for s=1, TUNING.PLAYINGCARDS_NUM_SUITS do
        for n=1, TUNING.PLAYINGCARDS_NUM_PIPS do
            RegisterInventoryItemAtlas("images/playingcards.xml", "playingcardstand".. (s*100 + n) ..".tex")
        end
    end

    RegisterInventoryItemAtlas("images/playingcards.xml", "playingcardstandback.tex")
end

local deck_prefabs =
{
    "playing_card",
}

local MAX_NUM = 9999
local HITS_BEFORE_SCATTER = 10
local SCATTER_TIME = 5.5
local DECK_BUCKET_OFFSETS = {
    Vector3(0, 0, 0),
    Vector3(0, 11, 0),
    Vector3(0, 20, 0),
    Vector3(0, 28, 0),
}
local CARD_IMAGE_PREFIX, DECK_IMAGE_PREFIX = "playingcard", "deckofcards"

local function OnInvImageDirty(inst)
    local deck_size_bucket = inst._deck_size:value()
    inst._layered_inventory_image = {
        {image=DECK_IMAGE_PREFIX..deck_size_bucket..".tex"},
    }

    local id = inst._top_card_id:value()
    if id > 0 then
        local offset = DECK_BUCKET_OFFSETS[deck_size_bucket + 1]
        table.insert(inst._layered_inventory_image, {
            atlas="images/playingcards.xml",
            image=CARD_IMAGE_PREFIX..id..".tex",
            offset=offset
        })
    end

    inst:PushEvent("imagechange")
end

local function CLIENT_LayeredInventoryImageFn(inst)
    return inst._layered_inventory_image
end

local function update_top_card(inst)
    if not inst._revealed then
        inst.AnimState:ClearOverrideSymbol("swap_card")
        inst._top_card_id:set_local(0) -- Force a dirty, b/c we may be loading w/ a starting value of 0.
        inst._top_card_id:set(0)
    else
        local top_card_id = inst.components.deckcontainer:PeekCard()
        inst.AnimState:OverrideSymbol("swap_card", "deck_of_cards", "card"..top_card_id)
        inst._top_card_id:set(top_card_id)
    end

    OnInvImageDirty(inst)
end

local function on_stack_size_change(inst, new_size)
    new_size = new_size or inst.components.deckcontainer:Count()
    if new_size == 1 then
        inst.AnimState:PlayAnimation("single")
        if inst.AnimState:GetLayer() ~= LAYER_BACKGROUND then
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed, 90)
            inst.AnimState:SetLayer(LAYER_BACKGROUND)
            inst.AnimState:SetSortOrder(3)
            inst.AnimState:SetScale(-1, 1.4)
        end

        inst._deck_size:set(0)
    else
        if inst.AnimState:GetLayer() == LAYER_BACKGROUND then
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
            inst.AnimState:SetLayer(LAYER_WORLD)
            inst.AnimState:SetSortOrder(0)
            inst.AnimState:SetScale(1, 1)
        end

        if new_size <= 13 then
            inst.AnimState:PlayAnimation("small")
            inst._deck_size:set(1)
        elseif new_size <= 26 then
            inst.AnimState:PlayAnimation("medium")
            inst._deck_size:set(2)
        else
            inst.AnimState:PlayAnimation("large")
            inst._deck_size:set(3)
        end
    end

    update_top_card(inst)
end

local function on_card_added_or_removed(inst, id)
    local new_size = inst.components.deckcontainer:Count()

    -- If our size is now 0, somebody above us should be handling us.
    if new_size > 0 then
        on_stack_size_change(inst, new_size)
    end
end

local function on_cards_added_bulk(inst, ids)
    local new_size = inst.components.deckcontainer:Count()

    -- If our size is now 0, somebody above us should be handling us.
    if new_size > 0 then
        on_stack_size_change(inst, new_size)
    end
end

local function on_split_deck_spawned(inst, source)
    inst._revealed = source._revealed
    update_top_card(inst)
end

-- Shuffling via punching
local function on_shuffled(inst)
    update_top_card(inst)
    inst.SoundEmitter:PlaySound("balatro/cards/shuffle")

    local deck_size = inst.components.deckcontainer:Count()
    if deck_size > 1 then
        local shuffle_size = (deck_size > 26 and "large")
            or (deck_size > 13 and "medium")
            or "small"
        inst.AnimState:PlayAnimation("shuffle_"..shuffle_size)
        inst.AnimState:PushAnimation(shuffle_size)
    end
end

local function FlipDeck(inst)
    inst._revealed = not inst._revealed

    inst.components.deckcontainer:Reverse()

    on_stack_size_change(inst)
end

local function cleanup_scatter_count(inst)
    inst._hit_recently_count = 0

    if inst._hit_recently_cleanup_task then
        inst._hit_recently_cleanup_task:Cancel()
        inst._hit_recently_cleanup_task = nil
    end
end

local function toss_one_card(inst, id, ix, iy, iz)
    local card = SpawnPrefab("playing_card")
    card._cardid = id
    card.Transform:SetPosition(ix, iy, iz)
    Launch2(card, card, 0.5, 4, 0.5, 0.5)
end
local function do_scatter(inst)
    local deckcontainer = inst.components.deckcontainer
    local deck_size = deckcontainer:Count()
    if deck_size < 2 then return end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    while deck_size > 1 do
        local time_delay = (1 + math.floor(deck_size / 7)) * FRAMES
        local card_id = deckcontainer:RemoveCard()
        inst:DoTaskInTime(time_delay, toss_one_card, card_id, ix, iy, iz)
        deck_size = deck_size - 1
    end
end

local function OnPunched(inst, data)
    inst._hit_recently_count = inst._hit_recently_count + 1
    if inst._hit_recently_count >= HITS_BEFORE_SCATTER then
        do_scatter(inst)
    else
        if not inst._hit_recently_cleanup_task then
            inst._hit_recently_cleanup_task = inst:DoTaskInTime(SCATTER_TIME, cleanup_scatter_count)
        end
        inst.components.deckcontainer:Shuffle()
    end
end

local function Deck_GenerateInitialID(inst)
    inst.generatecardtask = nil
    if inst.components.deckcontainer:Count() <= 0 then
        -- NOTES(JBK): This deck was spawned in we should populate it with one random card.
        inst.components.deckcontainer:AddRandomCard()
    end
end

-- Save/Load
local function OnSave(inst, data)
    data.revealed = inst._revealed
end

local function OnLoad(inst, data)
    if data then
        inst._revealed = data.revealed
        on_stack_size_change(inst)
    end
end

local function deck_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("deck_of_cards")
    inst.AnimState:SetBuild("deck_of_cards")
    inst.AnimState:PlayAnimation("single")

    inst:AddTag("deck_of_cards") -- For NON_LIFEFORM_TARGET_TAGS, could reuse deckcontainer. But, just in case someone wants to mod a living deckcontainer creature, haha.
    inst:AddTag("deckcontainer") -- from deckcontainer component

    MakeInventoryFloatable(inst, "small", 0.1, 1.2)

    inst._top_card_id = net_ushortint(inst.GUID, "deck_of_cards._top_card_id", "invimagechanged")
    -- NOTE: We're assuming that the top card also gets changed when the deck size gets changed,
    -- so it doesn't push an event on its own.
    inst._deck_size = net_tinybyte(inst.GUID, "deck_of_cards._deck_size")

	inst.layeredinvimagefn = CLIENT_LayeredInventoryImageFn

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst:ListenForEvent("invimagechanged", OnInvImageDirty)
        OnInvImageDirty(inst)

        return inst
    end

    -- Scrapbook
    inst.scrapbook_anim = "large"
    inst.scrapbook_hidehealth = true
    inst.scrapbook_tex = "deckofcards3"
    inst.scrapbook_thingtype = "item"

    -- Is our stack revealed or not? a.k.a. can we see the top card.
    inst._revealed = false
    inst._hit_recently_count = 0

    local deckcontainer = inst:AddComponent("deckcontainer")
    deckcontainer.on_split_deck = on_split_deck_spawned
    deckcontainer.on_deck_shuffled = on_shuffled
    deckcontainer.on_cards_added_bulk = on_cards_added_bulk
    deckcontainer.on_card_added = on_card_added_or_removed
    deckcontainer.on_card_removed = on_card_added_or_removed

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:ChangeImageName("deckofcards0")

    inst:AddComponent("inspectable")

    -- Make the deck punchable, for extra fun
    local combat = inst:AddComponent("combat")
    combat.noimpactsound = true

    local health = inst:AddComponent("health")
    health:SetMaxHealth(MAX_NUM + 10)
    health:SetMinHealth(1)
    health:StartRegen(MAX_NUM + 10, 0.1)
    health.canmurder = false
    health.canheal = false

    inst:ListenForEvent("flipdeck", FlipDeck)
    inst:ListenForEvent("attacked", OnPunched)

    inst.FlipDeck = FlipDeck

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.generatecardtask = inst:DoTaskInTime(0, Deck_GenerateInitialID)

    return inst
end

-- Card
local function PlayingCard_DisplayNameFn(inst)
    local id = inst._card_id:value()
    return STRINGS.PLAYING_CARD_NAMES["CARD"..id]
end

local function OnCardIdChanged(inst)
    local inventoryitem_replica = inst.replica.inventoryitem

    if inventoryitem_replica == nil then
        return
    end

    local id = inst._card_id:value()
    local image_suffix = (id > 0 and id) or "back"
    inventoryitem_replica:OverrideImage("playingcardstand"..image_suffix)

    inst:PushEvent("inventoryitem_updatetooltip") -- Update display string.
end

local function set_cardid(inst, id)
    if not id then return end

    if inst._faceup then
        inst.AnimState:OverrideSymbol("swap_card", "deck_of_cards", "card"..id)
        inst._card_id:set(id)
    else
        inst.AnimState:ClearOverrideSymbol("swap_card")
        inst._card_id:set_local(0)
        inst._card_id:set(0)
    end

    OnCardIdChanged(inst)
end

local function FlipSingleCard(inst)
    inst._faceup = not inst._faceup

    set_cardid(inst, inst.components.playingcard:GetID())
end

local function PlayingCard_GenerateInitialID(inst)
    if inst.components.playingcard:GetID() ~= -1 then
        -- We have an ID set from somewhere already.
        return
    end

    if TheWorld.components.playingcardsmanager then
        TheWorld.components.playingcardsmanager:RegisterPlayingCard(inst)
    else
        inst.components.playingcard:SetID(
            math.random(TUNING.PLAYINGCARDS_NUM_SUITS) * inst.components.playingcard.pip_digit_barrier
            + math.random(TUNING.PLAYINGCARDS_NUM_PIPS)
        )
    end

    -- Make spawned cards face down, so we don't get the 1 frame "pop" of them showing up
    FlipSingleCard(inst)
end

local function OnCardSave(inst, data)
    data.faceup = inst._faceup
end

local function OnCardLoad(inst, data)
    if data then
        inst._faceup = data.faceup
        set_cardid(inst, inst.components.playingcard:GetID())
    end
end

local function card_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("deck_of_cards")
    inst.AnimState:SetBuild("deck_of_cards")
    inst.AnimState:PlayAnimation("single")

    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed, 90)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetScale(-1, 1.4)

    MakeInventoryFloatable(inst, "small", 0.1, 1.2)

    inst._card_id = net_ushortint(inst.GUID, "playing_card._card_id", "cardidchanged")

    inst.displaynamefn = PlayingCard_DisplayNameFn
	--inst.layeredinvimagefn = CLIENT_LayeredInventoryImageFn

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst:ListenForEvent("cardidchanged", OnCardIdChanged)

        return inst
    end

    -- Scrapbook
    inst.scrapbook_tex = "playingcardstandback"

    inst._faceup = true

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:ChangeImageName("deckofcardstandback")

    inst:AddComponent("inspectable")

    local playingcard = inst:AddComponent("playingcard")
    playingcard.on_new_id = set_cardid

    inst:ListenForEvent("flipdeck", FlipSingleCard)

    inst:DoTaskInTime(0, PlayingCard_GenerateInitialID)

    inst.OnSave = OnCardSave
    inst.OnLoad = OnCardLoad

    return inst
end

return Prefab("deck_of_cards", deck_fn, deck_assets, deck_prefabs),
    Prefab("playing_card", card_fn, deck_assets)