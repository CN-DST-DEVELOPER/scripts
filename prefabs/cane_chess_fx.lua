local assets = {
    Asset("ANIM", "anim/cane_chess_fx.zip"),
}

local MIN_TIME_TO_LIVE = 1.5

local DISAPPEAR_DIST_TO_OWNER = 3
local DISAPPEAR_DIST_SQ_TO_OWNER = DISAPPEAR_DIST_TO_OWNER * DISAPPEAR_DIST_TO_OWNER

-- NOTES(JBK): Keep SHAPES + COLOURS sorted alphabetically.
local SHAPES = {"bishop", "king", "knight", "pawn", "queen", "rook", }
local COLOURS = {"b", "w",}
local SHAPEINDEXTOSWAPSYMBOL = {}
local COLOUR_LOOKUP_INDEXES = {}
-- Generate contiguous blocks of shapes by colour.
do -- Scope block.
    local MAXSHAPES = #SHAPES
    local previouscolourindex = 0
    for colourindex, colour in ipairs(COLOURS) do
        COLOUR_LOOKUP_INDEXES[colour] = {
            min = (previouscolourindex + 0) * MAXSHAPES + 1,
            max = (previouscolourindex + 1) * MAXSHAPES + 0,
        }
        previouscolourindex = colourindex
        for _, shape in ipairs(SHAPES) do
            local swapname = string.format("c_%s_%s", shape, colour)
            table.insert(SHAPEINDEXTOSWAPSYMBOL, swapname)
        end
    end
end
local TOTAL_COMBINATIONS = #SHAPEINDEXTOSWAPSYMBOL

local function PlayChessAnim(proxy, swapsymbol, flipped)
    proxy.playchessanimtask = nil

    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.Transform:SetFromProxy(proxy.GUID)

    inst.AnimState:SetBank("cane_chess_fx")
    inst.AnimState:SetBuild("cane_chess_fx")
    inst.AnimState:OverrideSymbol("swap_chess", "cane_chess_fx", swapsymbol)
    inst.AnimState:SetMultColour(0.8, 0.8, 0.8, 1)
    local scale = 1
    inst.AnimState:SetScale(flipped and -scale or scale, scale)
    inst.AnimState:PlayAnimation("chess_pre")
    inst.AnimState:PushAnimation("chess_loop", true)

    proxy.vfx = inst
    proxy:ListenForEvent("onremove", function() proxy.vfx = nil end, inst)
    inst:ListenForEvent("onremove", function() inst:Remove() end, proxy)
end

local function OnAnimDirty(inst)
    if not inst.playchessanimtask and not inst.vfx then
        -- Delay one frame in case we are about to be removed
        local swapsymbol = SHAPEINDEXTOSWAPSYMBOL[inst.shape:value() + 1]
        local flipped = inst.flipped:value()
        inst.playchessanimtask = inst:DoTaskInTime(0, PlayChessAnim, swapsymbol, flipped)
    end
end

local function OnFadeOutDirty(inst)
    if inst.vfx then
        inst.vfx.AnimState:PlayAnimation("chess_pst")
        inst.vfx:ListenForEvent("animover", inst.Remove)
    end
end

local function SetRandomShape(inst, forcedcolour)
    local min, max
    if forcedcolour then
        local lookup = COLOUR_LOOKUP_INDEXES[forcedcolour]
        min, max = lookup.min, lookup.max
    else
        min, max = 1, TOTAL_COMBINATIONS
    end
    local netvarindex = math.random(min, max) - 1
    inst.shape:set(netvarindex)
end

local function SetOwnerAffinity(inst, affinity)
    if affinity == "LUNAR" then
        SetRandomShape(inst, "w")
    elseif affinity == "SHADOW" then
        SetRandomShape(inst, "b")
    else
        SetRandomShape(inst, nil)
    end
end

local function DoFadeOut(inst)
    inst.fadeoutevent:push()
    if not TheNet:IsDedicated() then
        OnFadeOutDirty(inst)
    end
    inst:DoTaskInTime(1.5, inst.Remove)
end

local function FadeOut(inst)
    if inst.fadingout then
        return
    end

    inst.fadingout = true
    local currenttime = GetTime()
    local timeremaining = inst._mintimetofade - currenttime
    if timeremaining < 0 then
        DoFadeOut(inst)
    else
        inst:DoTaskInTime(timeremaining, DoFadeOut)
    end
end

local function TrackingTaskTick(inst, owner, cane)
    if cane:IsValid() and cane.components.equippable:IsEquipped() then
        if owner:IsValid() and owner.entity:IsVisible() then
            local mounted = owner.components.rider and owner.components.rider:IsRiding()
            local radius = (mounted and 1 or .5) + .5 -- NOTES(JBK): Keep in sync with prefabskin.lua. [CSTRC]
            radius = radius * 2 -- These instances stick around so make the padding double for a lingering trail of where the player was.
            if inst:GetDistanceSqToInst(owner) <= radius * radius then
                return
            end
        end
    end

    if inst.trackingtask then
        inst.trackingtask:Cancel()
        inst.trackingtask = nil
    end
    FadeOut(inst)
end

local function TrackOwnerAndCane(inst, owner, cane)
    if inst.fadingout then
        return
    end

    if inst.fadingouttask then
        inst.fadingouttask:Cancel()
        inst.fadingouttask = nil
    end
    if inst.trackingtask then
        inst.trackingtask:Cancel()
        inst.trackingtask = nil
    end
    inst.trackingtask = inst:DoPeriodicTask(0.5, TrackingTaskTick, nil, owner, cane)
end

local function MakeChessFX(name, netvarindex, prefabs)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

        inst:AddTag("FX")
        inst:AddTag("canetrail")

        inst.fadeoutevent = net_event(inst.GUID, "cane_chess_fx.fadeout")
        inst.flipped = net_bool(inst.GUID, "cane_chess_fx.flipped", "flippeddirty")
        local shape_net_enum = GetIdealUnsignedNetVarForCount(TOTAL_COMBINATIONS - 1)
        inst.shape = shape_net_enum(inst.GUID, "cane_chess_fx.shape", "shapedirty")
        if netvarindex then
            inst.shape:set(netvarindex)
        end

        --Dedicated server does not need to spawn the local fx
        if not TheNet:IsDedicated() then
            inst:ListenForEvent("flippeddirty", OnAnimDirty)
            inst:ListenForEvent("shapedirty", OnAnimDirty)
            inst:ListenForEvent("cane_chess_fx.fadeout", OnFadeOutDirty)
            if netvarindex then
                OnAnimDirty(inst)
            end
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        inst.OnEntitySleep = inst.Remove
        inst.SetOwnerAffinity = SetOwnerAffinity
        inst.TrackOwnerAndCane = TrackOwnerAndCane
        inst.fadingouttask = inst:DoTaskInTime(1.5, FadeOut)

        inst.flipped:set(math.random() < 0.5)
        if not netvarindex then
            inst.shape:set_local(0) -- Force a netvar send so the client knows that anything coming in for an event is good.
            SetRandomShape(inst, nil)
        end

        inst._mintimetofade = GetTime() + MIN_TIME_TO_LIVE

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local ret = {}
do -- Scope block.
    local prefabs = {}
    local netvarindex = 0
    for _, colour in ipairs(COLOURS) do
        for _, shape in ipairs(SHAPES) do
            local name = string.format("cane_chess_fx_%s_%s", shape, colour)
            table.insert(prefabs, name)
            table.insert(ret, MakeChessFX(name, netvarindex))
            netvarindex = netvarindex + 1
        end
    end
    table.insert(ret, MakeChessFX("cane_chess_fx", nil, prefabs))
end

-- Search strings:
-- "cane_chess_fx"
-- "cane_chess_fx_bishop_b", "cane_chess_fx_bishop_w"
-- "cane_chess_fx_knight_b", "cane_chess_fx_knight_w"
-- "cane_chess_fx_rook_b", "cane_chess_fx_rook_w"
return unpack(ret)
