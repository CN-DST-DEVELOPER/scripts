require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/wormshrine.zip"),
    Asset("MINIMAP_IMAGE", "yots_snakeshrine"),
}

local prefabs =
{
    "collapse_small",
    "ash",
    "yots_snakeshrine_placer",
}

local function MakePrototyper(inst)
    if inst.components.trader then
        inst:RemoveComponent("trader")
    end

    if not inst.components.prototyper then
        local prototyper = inst:AddComponent("prototyper")
        prototyper.trees = TUNING.PROTOTYPER_TREES.WORMSHRINE
    end
end

local function DropOffering(inst, worker)
    if not inst.offering then return end

    inst:RemoveEventCallback("onremove", inst._onofferingremoved, inst.offering)
    inst:RemoveChild(inst.offering)
    inst.offering:ReturnToScene()
    if worker then
        LaunchAt(inst.offering, inst, worker, 1, 0.6, .6)
    else
        inst.components.lootdropper:FlingItem(inst.offering, inst:GetPosition())
    end
    inst.offering = nil

    inst.AnimState:Hide("offering")

    TheWorld:PushEvent("ms_snakeshrinedeactivated", inst)
end

local function SetOffering(inst, offering, loading)
    if offering == inst.offering then
        return
    end

    DropOffering(inst)

    inst.offering = offering
    inst:ListenForEvent("onremove", inst._onofferingremoved, offering)

    inst:AddChild(offering)
    offering:RemoveFromScene()
    offering.Transform:SetPosition(0, 0, 0)

    inst.AnimState:Show("swap_monstermeat01")

    TheWorld:PushEvent("ms_snakeshrineactivated", inst)

    if not loading then
        inst.SoundEmitter:PlaySound("dontstarve/common/plant")
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle", false)
    end

    MakePrototyper(inst)
end

local function able_to_accept_test(inst, item)
    return item.prefab == "monstermeat"
end

local function on_given_item(inst, giver, item)
    SetOffering(inst, item)
end

local function MakeEmpty(inst)
    if inst.offering then
        inst:RemoveEventCallback("onremove", inst._onofferingremoved, inst.offering)

        inst.offering:Remove()
        inst.offering = nil
    end

    inst.AnimState:Hide("swap_monstermeat01")

    if inst.components.prototyper then
        inst:RemoveComponent("prototyper")
    end

    if not inst.components.trader then
        local trader = inst:AddComponent("trader")
        trader:SetAbleToAcceptTest(able_to_accept_test)
        trader.acceptnontradable = true
        trader.deleteitemonaccept = false
        trader.onaccept = on_given_item
    end
end

-- Burnable callbacks
local function OnBurnt(inst)
    DefaultBurntStructureFn(inst)
    if inst.offering then
        inst:RemoveEventCallback("onremove", inst._onofferingremoved, inst.offering)
        inst.offering:Remove()
        inst.offering = nil
        inst.components.lootdropper:SpawnLootPrefab("ash")
    end

    if inst.components.trader then
        inst:RemoveComponent("trader")
    end
end

local function OnIgnite(inst)
    if inst.offering then
        inst.components.lootdropper:SpawnLootPrefab("ash")
    end
    MakeEmpty(inst)
    inst.components.trader:Disable()
    DefaultBurnFn(inst)
end

local function OnExtinguish(inst)
    if inst.components.trader then
        inst.components.trader:Enable()
    end
    DefaultExtinguishFn(inst)
end

--
local function on_built(inst)
    --Make empty when first built.
    --Pristine state is not empty.
    MakeEmpty(inst)

    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("dontstarve/common/together/town_portal/craft")
    inst.SoundEmitter:PlaySound("yotb_2021/common/shrine/place")
    inst.components.timer:StartTimer("sound1", FRAMES*12)
    inst.components.timer:StartTimer("sound2", FRAMES*17)

end

-- Work callbacks
local function on_work_finished(inst, worker)
    if inst.components.burnable and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end

    inst.components.lootdropper:DropLoot()
    DropOffering(inst, worker)

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function on_worked(inst, worker, workleft)
    DropOffering(inst, worker)
    MakeEmpty(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle", false)
    end
end

-- Save/Load
local function OnSave(inst, data)
    if (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) or inst:HasTag("burnt") then
        data.burnt = true
    elseif inst.offering then
        data.offering = inst.offering:GetSaveRecord()
    end
end

local function OnLoad(inst, data)
    if data and data.burnt then
        inst.components.burnable.onburnt(inst)
    elseif data and data.offering then
        SetOffering(inst, SpawnSaveRecord(data.offering), true)
    else
        MakeEmpty(inst)
    end
end

-- String/Inspectable functions
local function GetStatus(inst)
    return (inst:HasTag("burnt") and "BURNT")
        or (inst.components.trader ~= nil and "EMPTY")
        or nil
end

local function ontimedone(inst, data)
    if data.name == "sound1" and inst.AnimState:IsCurrentAnimation("place") then
        inst.SoundEmitter:PlaySound("rifts4/worm_boss/chomp")
    elseif data.name == "sound2" and inst.AnimState:IsCurrentAnimation("place") then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/put_meat_rack")
    end
end
--
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1.1) --recipe min_spacing/2
    MakeObstaclePhysics(inst, .6)

    inst.MiniMapEntity:SetPriority(5)
    inst.MiniMapEntity:SetIcon("yots_snakeshrine.png")

    inst.AnimState:SetBank("wormshrine")
    inst.AnimState:SetBuild("wormshrine")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("structure")
    inst:AddTag("snakeshrine")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.AnimState:Hide("swap_monstermeat01")

    --inst.offering = nil
    inst._onofferingremoved = function() MakeEmpty(inst) end

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = GetStatus

    --
    MakePrototyper(inst)
    inst:ListenForEvent("onbuilt", on_built)

    --

    inst:AddComponent("timer")

    --
    inst:AddComponent("lootdropper")
    --
    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(4)
    workable:SetOnFinishCallback(on_work_finished)
    workable:SetOnWorkCallback(on_worked)

    --
    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountSmall(inst)

    --
    local burnable = MakeMediumBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)
    burnable:SetOnBurntFn(OnBurnt)
    burnable:SetOnIgniteFn(OnIgnite)
    burnable:SetOnExtinguishFn(OnExtinguish)

    --
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:ListenForEvent("ondeconstructstructure", DropOffering)
    inst:ListenForEvent("timerdone", ontimedone)

    return inst
end

return Prefab("yots_snakeshrine", fn, assets, prefabs),
    MakePlacer("yots_snakeshrine_placer", "wormshrine", "wormshrine", "placer")
