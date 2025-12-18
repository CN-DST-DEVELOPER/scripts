local assets = {
    Asset("ANIM", "anim/desiccant.zip"),
}

local PLAY_SFX_THRESHOLD = 1

local function IsFull(inst)
    local moisture = inst.components.inventoryitemmoisture and inst.components.inventoryitemmoisture.moisture or 0
    if moisture >= TUNING.MAX_WETNESS then
        return true
    end

    return false
end

local function GetRate(inst, rate)
    if IsFull(inst) then
        return 0
    end

    return TUNING.DESICCANT_DRY_RATE
end

local function ApplyDrying(inst, rate, dt)
    inst.components.inventoryitemmoisture:DoDelta(TUNING.DESICCANT_DRY_RATE * dt)
end

local function GetRate_Boosted(inst, rate)
    if IsFull(inst) then
        return 0
    end

    return TUNING.DESICCANTBOOSTED_DRY_RATE
end

local function ApplyDrying_Boosted(inst, rate, dt)
    inst.components.inventoryitemmoisture:DoDelta(TUNING.DESICCANTBOOSTED_DRY_RATE * dt)
end

local function OnFireMelt(inst)
    inst.components.inventoryitemmoisture:SetExternallyControlled(false)
end

local function OnStopFireMelt(inst)
    inst.components.inventoryitemmoisture:SetExternallyControlled(true)
end

local function OnIsDampDirty(inst)
    local oldprefix = inst.wet_prefix
    if inst._isdamp:value() then
        inst.always_wet_prefix = true
        inst.wet_prefix = STRINGS.WET_PREFIX.DESICCANT
    elseif inst:GetIsWet() then
        inst.always_wet_prefix = true
        inst.wet_prefix = STRINGS.WET_PREFIX.DESICCANT_FULL
    else
        inst.always_wet_prefix = nil
        inst.wet_prefix = STRINGS.WET_PREFIX.GENERIC
    end
    if oldprefix ~= inst.wet_prefix then
        inst:PushEvent("inventoryitem_updatetooltip")
    end
end

local function OnPlaySFX(inst)
    if ThePlayer then
        ThePlayer:PushEvent("item_buff_changed", {inst = inst, effect = "playwaterfx"})
    end
end

local function OnMoistureDeltaCallback(inst, oldmoisture, newmoisture)
    if newmoisture > 0 and newmoisture < TUNING.MAX_WETNESS then
        inst._isdamp:set(true)
    else
        inst._isdamp:set(false)
    end
    OnIsDampDirty(inst)
    local deltasfx = newmoisture - (inst._playsfx_threshold or 0)
    if deltasfx > PLAY_SFX_THRESHOLD or newmoisture == TUNING.MAX_WETNESS then
        inst._playsfx_threshold = newmoisture
        if deltasfx > 0 then
            inst._playsfx:push()
            OnPlaySFX(inst)
        end
    end
end

local function fn_common(boosted)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("desiccant")
    inst.AnimState:SetBuild("desiccant")
    if boosted then
        inst.AnimState:PlayAnimation("idleboosted")
    else
        inst.AnimState:PlayAnimation("idle")
    end

    MakeInventoryFloatable(inst, "small", 0.05, 0.95)

    inst:AddTag("meltable")

    inst._playsfx = net_event(inst.GUID, "desiccant.playsfx")
    inst._isdamp = net_bool(inst.GUID, "desiccant.isdamp", "isdampdirty")
    OnIsDampDirty(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("desiccant.playsfx", OnPlaySFX)
        inst:ListenForEvent("isdampdirty", OnIsDampDirty)
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitemmoisture:SetExternallyControlled(true) -- Must be after inventoryitem.
    inst.components.inventoryitemmoisture:SetOnlyWetWhenSaturated(true)
    inst.components.inventoryitemmoisture:SetOnMoistureDeltaCallback(OnMoistureDeltaCallback)

    local moistureabsorbersource = inst:AddComponent("moistureabsorbersource")
    if boosted then
        moistureabsorbersource:SetGetDryingRateFn(GetRate_Boosted)
        moistureabsorbersource:SetApplyDryingFn(ApplyDrying_Boosted)
    else
        moistureabsorbersource:SetGetDryingRateFn(GetRate)
        moistureabsorbersource:SetApplyDryingFn(ApplyDrying)
    end

    inst:ListenForEvent("firemelt", OnFireMelt)
    inst:ListenForEvent("stopfiremelt", OnStopFireMelt)
    inst:ListenForEvent("onputininventory", OnStopFireMelt)

    MakeHauntableLaunch(inst)

    return inst
end

local function fn()
    return fn_common(false)
end

local function fn_boosted()
    return fn_common(true)
end

return Prefab("desiccant", fn, assets),
    Prefab("desiccantboosted", fn_boosted, assets)
