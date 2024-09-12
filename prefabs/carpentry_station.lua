require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/carpentry_station.zip"),
    Asset("MINIMAP_IMAGE", "carpentry_station"),

    Asset("INV_IMAGE", "boards_bunch"), -- For crafting menu.
    Asset("INV_IMAGE", "cutstone_bunch"), -- For crafting menu.
}

local prefabs =
{
    "ash",
    "collapse_small",
}

local function GetStatus(inst)
    return (inst:HasTag("burnt") and "BURNT") or nil
end

local function OnHammered(inst, worker)
    if inst.components.burnable and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end

    if inst:HasTag("burnt") then
        inst.components.lootdropper:SpawnLootPrefab("ash")
    else
        inst.components.lootdropper:DropLoot()
    end

    if inst.components.inventoryitemholder ~= nil then
        inst.components.inventoryitemholder:TakeItem()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function OnHit(inst, worker)
    if inst:HasTag("burnt") then return end

    inst.AnimState:PlayAnimation("hit_open")
    inst.AnimState:PushAnimation(inst.components.prototyper.on and "proximity_loop" or "idle", inst.components.prototyper.on)
end

local function OnTurnOn(inst)
    if inst:HasTag("burnt") then return end

    if inst.AnimState:IsCurrentAnimation("proximity_loop") or inst.AnimState:IsCurrentAnimation("place") or inst.AnimState:IsCurrentAnimation("use") then
        inst.AnimState:PushAnimation("proximity_loop", true)
    else
        inst.AnimState:PlayAnimation("proximity_loop", true)
    end

    if not inst.SoundEmitter:PlayingSound("loop_sound") then
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/proximity_lp", "loop_sound")
    end
end

local function OnTurnOff(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PushAnimation("idle", false)
        inst.SoundEmitter:KillSound("loop_sound")
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/proximity_lp_pst")
    end
end

local EFFECTS_BUILD_BY_TECH_LEVEL = {
    [2] = "carpentry_station",
    [3] = "carpentry_station_moonglass_build",
}

local function OnActivate(inst, doer, recipe)
    if not inst:HasTag("burnt") then
        if recipe ~= nil and EFFECTS_BUILD_BY_TECH_LEVEL[recipe.level.CARPENTRY] then
            inst.AnimState:OverrideSymbol("woodshaving", EFFECTS_BUILD_BY_TECH_LEVEL[recipe.level.CARPENTRY], "woodshaving")
        end

        inst.AnimState:PlayAnimation("use")
        inst.AnimState:PushAnimation("proximity_loop", true)
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/use")
    end
end

local function OnBuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("rifts3/sawhorse/place")
end

local function OnSave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function OnLoad(inst, data)
    if data == nil then
        return
    end

    if data.burnt then
        inst.components.burnable.onburnt(inst)
    end
end

------------------------------------------------------------------------------------------------------------------------------------

local function OnBladeGiven(inst, item, giver)
    if inst.components.prototyper == nil or item.blade_tech_tree == nil or item.build_override == nil then
        if inst.components.inventoryitemholder ~= nil then
            inst.components.inventoryitemholder:TakeItem(giver)
        end

        return -- Failed!
    end

    inst.components.prototyper.trees = item.blade_tech_tree

    inst.AnimState:AddOverrideBuild(item.build_override)
end

local function OnBladeTaken(inst, item, taker)
    if inst.components.prototyper ~= nil then
        inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.CARPENTRY_STATION
    end

    if item.build_override ~= nil then
        inst.AnimState:ClearOverrideBuild(item.build_override)
    end
end

------------------------------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1.25) --recipe min_spacing/2
    inst:SetPhysicsRadiusOverride(0.5)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.MiniMapEntity:SetIcon("carpentry_station.png")

    inst:AddTag("structure")
    inst:AddTag("carpentry_station")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    inst.AnimState:SetBank("carpentry_station")
    inst.AnimState:SetBuild("carpentry_station")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = GetStatus

    --
    inst:AddComponent("lootdropper")

    --
    local prototyper = inst:AddComponent("prototyper")
    prototyper.onturnon = OnTurnOn
    prototyper.onturnoff = OnTurnOff
    prototyper.onactivate = OnActivate
    prototyper.trees = TUNING.PROTOTYPER_TREES.CARPENTRY_STATION

    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(2)
    workable:SetOnFinishCallback(OnHammered)
    workable:SetOnWorkCallback(OnHit)

    local inventoryitemholder = inst:AddComponent("inventoryitemholder")
    inventoryitemholder:SetAllowedTags({ "carpentry_blade" })
    inventoryitemholder:SetOnItemGivenFn(OnBladeGiven)
    inventoryitemholder:SetOnItemTakenFn(OnBladeTaken)

    --
    MakeMediumBurnable(inst, nil, nil, true, "station_parts")
    MakeSmallPropagator(inst)

    --
    inst:ListenForEvent("onbuilt", OnBuilt)

    --
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("carpentry_station", fn, assets, prefabs),
    MakePlacer("carpentry_station_placer", "carpentry_station", "carpentry_station", "idle")
