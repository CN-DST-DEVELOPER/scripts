local assets = {
    Asset("ANIM", "anim/armor_carrotlure.zip"),
}
local prefabs = {
    "spoiled_food",
}

local UPDATE_TICK_RATE = 1

local LURE_TAG = "regular_bunnyman"
local CARROTLURE_MUST_TAGS = {LURE_TAG}
local function UpdateLure(inst)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if owner and owner.components.leader then
        local maxfollowers = TUNING.ARMOR_CARROTLURE_MAXFOLLOWERS
        local currentfollowers = owner.components.leader:GetFollowersByTag(LURE_TAG)
        local currentfollowerscount = #currentfollowers
        if currentfollowerscount < maxfollowers then
            local x, y, z = owner.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, TUNING.ARMOR_CARROTLURE_RANGE, CARROTLURE_MUST_TAGS)
            for _, v in ipairs(ents) do
                if v.components.follower and not v.components.follower.leader and not owner.components.leader:IsFollower(v) then
                    owner.components.leader:AddFollower(v)
                    currentfollowerscount = currentfollowerscount + 1
                    currentfollowers[currentfollowerscount] = v
                    if currentfollowerscount >= maxfollowers then
                        break
                    end
                end
            end
        end

        for _, v in pairs(currentfollowers) do
            if v.components.follower then
                if v:HasTag(LURE_TAG) then
                    v.components.follower:AddLoyaltyTime(3)
                end
            end
        end
    end
end

local function DisableLure(inst)
    if inst.carrotluretask ~= nil then
        inst.carrotluretask:Cancel()
        inst.carrotluretask = nil
    end
end
local function EnableLure(inst)
    DisableLure(inst)
    inst.carrotluretask = inst:DoPeriodicTask(UPDATE_TICK_RATE, UpdateLure, 1)
end

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_carrotlure")
    else
		owner.AnimState:OverrideSymbol("swap_body", "armor_carrotlure", "swap_body")
    end

    EnableLure(inst)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    DisableLure(inst)

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function onequiptomodel(inst, owner)
    DisableLure(inst)
end

local FLOAT_SCALE = {.9, .9, .9}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_carrotlure")
    inst.AnimState:SetBuild("armor_carrotlure")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("show_spoilage")
    inst:AddTag("hidesmeats")
    inst.foleysound = "dontstarve/movement/foley/cactus_armor"

    MakeInventoryFloatable(inst, nil, 0.2, FLOAT_SCALE)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    local perishable = inst:AddComponent("perishable")
    perishable:SetOnPerishFn(DisableLure)
    perishable:SetPerishTime(TUNING.ARMOR_CARROTLURE_PERISHTIME)
    perishable.onperishreplacement = "spoiled_food"
    perishable:StartPerishing()

    inst:AddComponent("repairable")
    inst.components.repairable.repairmaterial = MATERIALS.CARROT
    inst.components.repairable.announcecanfix = false

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunchAndPerish(inst)

    local equippable = inst:AddComponent("equippable")
    equippable.equipslot = EQUIPSLOTS.BODY
    equippable.dapperness = TUNING.DAPPERNESS_TINY
    equippable:SetOnEquip(onequip)
    equippable:SetOnUnequip(onunequip)
    equippable:SetOnEquipToModel(onequiptomodel)

    inst:AddComponent("leader")

    return inst
end

return Prefab("armor_carrotlure", fn, assets, prefabs)