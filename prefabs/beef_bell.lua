local easing = require("easing")

local regular_assets =
{
    Asset("ANIM", "anim/cowbell.zip"),
    Asset("INV_IMAGE", "beef_bell_linked"),
}

local shadow_assets =
{
    Asset("ANIM", "anim/cowbell_shadow.zip"),
    Asset("INV_IMAGE", "shadow_beef_bell_linked"),
}

local shadow_prefabs =
{
    "shadow_beef_bell_curse",
    "beefalo_reviving_lightning_fx",
}

-----------------------------------------------------------------------------------------------------------------------------------------

local function OnPlayerDesmounted(inst, data)
    local mount = data ~= nil and data.target or nil

    if mount ~= nil and mount:IsValid() then
        mount:PushEvent("despawn")
    end
end

local function OnPlayerDespawned(inst)
    local beefalo = inst:GetBeefalo()

    if beefalo == nil then
        return
    end

    if not beefalo.components.health:IsDead() then
        beefalo._marked_for_despawn = true -- Used inside beefalo prefab.

        local dismounting = false

        if beefalo.components.rideable ~= nil then
            beefalo.components.rideable.canride = false

            local rider = beefalo.components.rideable.rider

            if rider ~= nil and rider.components.rider ~= nil then
                dismounting = true

                rider.components.rider:Dismount()
                rider:ListenForEvent("dismounted", inst._OnPlayerDesmounted)
            end
        end

        if beefalo.components.health ~= nil then
            beefalo.components.health:SetInvincible(true)
        end

        if not dismounting then
            beefalo:PushEvent("despawn")
        end

    elseif inst:HasTag("shadowbell") then
        inst.components.useabletargeteditem:StopUsingItem()
    end
end

local function IsLinkedBell(item, inst)
    return item ~= inst and item:HasTag("bell") and item.HasBeefalo ~= nil and item:HasBeefalo()
end

local function GetOtherPlayerLinkedBell(inst, other)
    local container = other.components.inventory or other.components.container

    if container ~= nil then
        return container:FindItem(inst._IsLinkedBell)
    end
end

local function CleanUpBell(inst)
    inst:RemoveTag("nobundling")

    inst.components.inventoryitem:ChangeImageName(inst:GetSkinName())

    inst.AnimState:PlayAnimation("idle1", false)
    inst.components.inventoryitem.nobounce = false
    inst.components.floater.splash = true

    if inst.isbonded ~= nil then
        inst.isbonded:set(false)

        if not TheNet:IsDedicated() then
            inst:OnIsBondedDirty()
        end
    end
end

local function OnRemoveFollower(inst, beef)
    inst.components.useabletargeteditem:StopUsingItem()

    -- For when the bell is removed.
    if beef ~= nil then
        inst:OnStopUsing(beef)
    end
end

local function HasBeefalo(inst)
    return inst.components.leader ~= nil and inst.components.leader:CountFollowers() > 0
end

local function GetBeefalo(inst)
    for beef, bool in pairs(inst.components.leader.followers) do
        if bool then
            return beef
        end
    end
end

local function GetAliveBeefalo(inst)
    local beefalo = inst:GetBeefalo()

    return beefalo ~= nil and not beefalo.components.health:IsDead() and beefalo or nil
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function OnPutInInventory(inst, owner)
    if owner == nil or not inst:HasBeefalo() then
        return
    end

    owner = owner.components.inventoryitem ~= nil and owner.components.inventoryitem:GetGrandOwner() or owner

    -- If the bell being picked up has a beefalo look for another bell in the picking up player's inventory and drop it.
    local other_bell = GetOtherPlayerLinkedBell(inst, owner)

    if other_bell ~= nil then
        if owner.components.inventory ~= nil then
            if owner:HasTag("player") then
                owner.components.inventory:DropItem(other_bell, true, true)
            end

        elseif owner.components.container ~= nil and owner.components.inventoryitem ~= nil then
            -- Backpacks can be picked up, so don't allow multiple bells.
            owner.components.container:DropItem(other_bell)
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function OnUsedOnBeefalo(inst, target, user)
    if target.SetBeefBellOwner == nil then
        return false, "BEEF_BELL_INVALID_TARGET"
    end

    if user ~= nil and target.components.health:IsDead() then
        return false -- Not loading.
    end

    -- This may run with a nil user on load.
    if user ~= nil and GetOtherPlayerLinkedBell(inst, user) ~= nil then
        return false, "BEEF_BELL_HAS_BEEF_ALREADY"
    end

    local successful, failreason = target:SetBeefBellOwner(inst, user)

    if successful then
        inst:AddTag("nobundling")

        local basename = inst:GetSkinName() or inst.prefab
        inst.components.inventoryitem:ChangeImageName(basename.."_linked")
        inst.AnimState:PlayAnimation("idle2", true)

        if inst.isbonded ~= nil then
            inst.isbonded:set(true)

            inst.components.inventoryitem.nobounce = true
            inst.components.floater.splash = false

            if not TheNet:IsDedicated() then
                inst:OnIsBondedDirty()
            end
        end
    end

    return successful, (failreason ~= nil and "BEEF_BELL_"..failreason or nil)
end

local function OnStopUsing(inst, beefalo)
    beefalo = beefalo or inst:GetBeefalo()
    
    if beefalo ~= nil then
        beefalo:UnSkin() -- Drop skins.
    end

    inst.components.leader:RemoveAllFollowers()
    inst:CleanUpBell()

    if inst:HasTag("shadowbell") and beefalo ~= nil and beefalo.components.health:IsDead() then
        beefalo.persists = false -- Beefalo's ClearBellOwner fn makes it persistent.

        if beefalo:HasTag("NOCLICK") then
            return
        end

        beefalo:AddTag("NOCLICK")

        RemovePhysicsColliders(beefalo)

        if beefalo.DynamicShadow ~= nil then
            beefalo.DynamicShadow:Enable(false)
        end

        local multcolor = beefalo.AnimState:GetMultColour()
        local ticktime = TheSim:GetTickTime()

        local erodetime = 5

        beefalo:StartThread(function()
            local ticks = 0
    
            while beefalo:IsValid() and (ticks * ticktime < erodetime) do
                local n = ticks * ticktime / erodetime
    
                local alpha = easing.inQuad(1 - n, 0, 1, 1)
                local color = 1 - (n * 5)
    
                local color = math.min(multcolor, color)

                beefalo.AnimState:SetErosionParams(n, .05, 1.0)
                beefalo.AnimState:SetMultColour(color, color, color, math.max(.3, alpha))
    
                ticks = ticks + 1
                Yield()
            end

            beefalo:Remove()
        end)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    local beefalo = inst:GetBeefalo()

    if beefalo ~= nil then
        local skinner_beefalo = beefalo.components.skinner_beefalo
    
        data.clothing = skinner_beefalo ~= nil and skinner_beefalo.clothing or nil
        data.beef_record = beefalo:GetSaveRecord()
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.beef_record ~= nil then
        local beef = SpawnSaveRecord(data.beef_record)

        if beef ~= nil then
            inst.components.useabletargeteditem:StartUsingItem(beef)

            if data.clothing ~= nil then
                beef.components.skinner_beefalo:reloadclothing(data.clothing)
            end
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function ShadowBell_CanReviveTarget(inst, target, doer)
    return target.GetBeefBellOwner ~= nil and target:GetBeefBellOwner() == doer
end

local function ShadowBell_ReviveTarget(inst, target, doer)
    target:OnRevived(inst)

    doer:AddDebuff("shadow_beef_bell_curse", "shadow_beef_bell_curse")

    inst.components.rechargeable:Discharge(TUNING.SHADOW_BEEF_BELL_REVIVE_COOLDOWN)
end

local SHADOW_FLOAT_SCALE_BONDED = { 0, 0, 0 }
local FLOAT_SCALE = { 1.2, 1, 1.2 }

local function ShadowBell_OnIsBondedDirty(inst)
    inst.components.floater:SetScale(inst.isbonded:value() and SHADOW_FLOAT_SCALE_BONDED or FLOAT_SCALE)

    if inst.components.floater:IsFloating() then
        inst.components.floater:OnNoLongerLandedClient()
        inst.components.floater:OnLandedClient()
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function CommonFn(data)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.build)
    inst.AnimState:PlayAnimation("idle1", false)

    MakeInventoryFloatable(inst, nil, 0.05, FLOAT_SCALE)

    inst:AddTag("bell")
    inst:AddTag("donotautopick")

    inst._sound = data.sound

    if data.common_postinit ~= nil then
        data.common_postinit(inst, data)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._IsLinkedBell = function(item) return IsLinkedBell(item, inst) end
    inst._OnPlayerDesmounted = OnPlayerDesmounted
    inst.OnPlayerDespawned = OnPlayerDespawned
    inst.CleanUpBell = CleanUpBell
    inst.HasBeefalo = HasBeefalo
    inst.GetBeefalo = GetBeefalo
    inst.OnStopUsing = OnStopUsing

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)

    inst:AddComponent("useabletargeteditem")
    inst.components.useabletargeteditem:SetTargetPrefab("beefalo")
    inst.components.useabletargeteditem:SetOnUseFn(OnUsedOnBeefalo)
    inst.components.useabletargeteditem:SetOnStopUseFn(inst.OnStopUsing)
    inst.components.useabletargeteditem:SetInventoryDisable(true)

    inst:AddComponent("leader")
    inst.components.leader.onremovefollower = OnRemoveFollower

    inst:AddComponent("migrationpetowner")
    inst.components.migrationpetowner:SetPetFn(GetAliveBeefalo)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst:ListenForEvent("player_despawn", inst.OnPlayerDespawned)

    return inst
end

-----------------------------------------------------------------------------------------------------------------------------------------

local function RegularFn()
    return CommonFn({
        bank  = "cowbell",
        build = "cowbell",
        sound = "yotb_2021/common/cow_bell",
    })
end

local function ShadowCommonPostInit(inst, data)
    inst.entity:AddDynamicShadow()
    inst.DynamicShadow:SetSize(1.2, .8)

    inst.AnimState:Hide("shadow")

    inst.AnimState:SetLightOverride(0.1)
    inst.AnimState:SetSymbolLightOverride("red", 0.5)

    -- rechargeable (from rechargeable component) added to pristine state for optimization.
    inst:AddTag("rechargeable")

    inst:AddTag("shadowbell")

    inst.OnIsBondedDirty = ShadowBell_OnIsBondedDirty

    inst.isbonded = net_bool(inst.GUID, "shadow_beef_bell.isbonded", "isbondeddirty")
end

local function ShadowFn()
    local inst = CommonFn({
        bank  = "cowbell_shadow",
        build = "cowbell_shadow",
        sound = "rifts4/beefalo_revive/bell_ring",
        common_postinit = ShadowCommonPostInit,
    })

    if not TheWorld.ismastersim then
        inst:ListenForEvent("isbondeddirty", inst.OnIsBondedDirty)

        return inst
    end

    inst:AddComponent("tradable")
    inst:AddComponent("rechargeable")

    inst.CanReviveTarget = ShadowBell_CanReviveTarget
    inst.ReviveTarget = ShadowBell_ReviveTarget

    return inst
end

-----------------------------------------------------------------------------------------------------------------------------------------

return
    Prefab("beef_bell",        RegularFn, regular_assets                ),
    Prefab("shadow_beef_bell", ShadowFn,  shadow_assets, shadow_prefabs )
