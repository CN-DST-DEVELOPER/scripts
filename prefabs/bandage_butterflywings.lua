local assets =
{
    Asset("ANIM", "anim/bandage_butterfly.zip"),
}

--------------------------------------------------------------------------------------------------------------

local function OnHealFn(inst, target, doer)
    if target.components.sanity == nil then
        return
    end

    if doer.components.skilltreeupdater == nil or not doer.components.skilltreeupdater:IsActivated("walter_camp_firstaid") then
        return
    end

    target.components.sanity:DoDelta(TUNING.SANITY_SMALL)
end

--------------------------------------------------------------------------------------------------------------

local DEFAULT_COST = 3
local INGREDIENT = "butterflywings"

local CACHED_WINGS_RECIPE_COST = nil

local function CacheWingsRecipeCost(default)
    local bandagerecipe = AllRecipes.bandage_butterflywings

    if bandagerecipe == nil or bandagerecipe.ingredients == nil then
        return default
    end

    local neededwings = 0
    for _, ingredient in ipairs(bandagerecipe.ingredients) do
        if ingredient.type ~= INGREDIENT then
            return default
        end
        neededwings = neededwings + ingredient.amount
    end

    return neededwings
end

--------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("bandage_butterfly")
    inst.AnimState:SetBuild("bandage_butterfly")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "vegetation_firm"

    MakeInventoryFloatable(inst, nil, .05, .9)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    if CACHED_WINGS_RECIPE_COST == nil then
        CACHED_WINGS_RECIPE_COST = CacheWingsRecipeCost(DEFAULT_COST)
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("healer")
    inst.components.healer:SetHealthAmount(TUNING.HEALING_MEDSMALL * CACHED_WINGS_RECIPE_COST)
    inst.components.healer:SetOnHealFn(OnHealFn)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("bandage_butterflywings", fn, assets)