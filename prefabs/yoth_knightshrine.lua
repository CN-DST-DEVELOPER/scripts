require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/yoth_knightshrine.zip"),
    Asset("MINIMAP_IMAGE", "yoth_knightshrine"),
}

local prefabs =
{
    "collapse_small",
    "ash",
    "yoth_knightshrine_placer",
    "playbill_the_princess_yoth",
    "charlie_heckler",
}

local function SayHecklerLine(inst, line)
    local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
    if yoth_hecklermanager and yoth_hecklermanager:ShrineHasHeckler(inst) then
        inst.heckler.components.talker:Say(STRINGS.HECKLERS_YOTH[line][math.random(#STRINGS.HECKLERS_YOTH[line])])
    end
end

local function TryHecklerFlyAway(inst)
    local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
    if yoth_hecklermanager then
        yoth_hecklermanager:TryHecklerFlyAway(inst)
    end
end

local function TryHecklerLand(inst)
    local yoth_hecklermanager = TheWorld.components.yoth_hecklermanager
    if yoth_hecklermanager then
        yoth_hecklermanager:TryHecklerLand(inst)
    end
end

local function TryHecklerSpawn(inst)
    if inst.components.prototyper and inst.components.prototyper.on then
        TryHecklerLand(inst)
    end
    inst._delay_heckler_spawn = nil
end

local function OnTurnOn(inst)
    if not inst._delay_heckler_spawn then
        TryHecklerLand(inst)
    end
end

local function OnTurnOff(inst)
    TryHecklerFlyAway(inst)
end

local function OnActivate(inst)
    if not inst.heckler.sg:HasAnyStateTag("talking", "busy") then
        SayHecklerLine(inst, "SHRINE_USE")
    end
end

local function MakePrototyper(inst)
    if inst.components.trader then
        inst:RemoveComponent("trader")
    end

    if not inst.components.prototyper then
        local prototyper = inst:AddComponent("prototyper")
        prototyper.trees = TUNING.PROTOTYPER_TREES.KNIGHTSHRINE
        prototyper.onturnon = OnTurnOn
        prototyper.onturnoff = OnTurnOff
        prototyper.onactivate = OnActivate

        inst._delay_heckler_spawn = inst:DoTaskInTime(4 + math.random() * 2, TryHecklerSpawn)
    end
end

local function UnregisterShrine(inst)
    TheWorld:PushEvent("ms_knightshrinedeactivated", inst)
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

    inst.AnimState:Hide("SWAP_GEARS")

    UnregisterShrine(inst)
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

    if offering.prefab == "gears" then
        inst.AnimState:ClearOverrideSymbol("swap_gears")
    elseif offering.prefab == "trinket_6" then
        inst.AnimState:OverrideSymbol("swap_gears", "yoth_knightshrine", "swap_wires")
    elseif offering.prefab == "transistor" then
        inst.AnimState:OverrideSymbol("swap_gears", "yoth_knightshrine", "swap_doodad")
    end
    inst.AnimState:Show("SWAP_GEARS")

    TheWorld:PushEvent("ms_knightshrineactivated", inst)

    if not loading then
        inst.SoundEmitter:PlaySound("yoth_2026/shrine/activate")
        inst.AnimState:PlayAnimation("activate")
        inst.AnimState:PushAnimation("idle_on", true)
    else
        inst.AnimState:PlayAnimation("idle_on", true)
    end

    inst.SoundEmitter:PlaySound("yoth_2026/shrine/idle", "idle_whirring")
    MakePrototyper(inst)
end

local function able_to_accept_test(inst, item)
    return item.prefab == "gears"
        or item.prefab == "trinket_6" -- Frazzled Wires
        or item.prefab == "transistor" -- Electrical Doodad
        -- or item.prefab == "wagpunk_bits"
end

local function on_given_item(inst, giver, item)
    SetOffering(inst, item)
end

local function MakeEmpty(inst, loading)
    if inst.offering then
        inst:RemoveEventCallback("onremove", inst._onofferingremoved, inst.offering)

        if not loading then
            inst.SoundEmitter:PlaySound("yoth_2026/shrine/deactivate")
            inst.AnimState:PlayAnimation("deactivate1")
            inst.AnimState:PushAnimation("idle_off", false)
        else
            inst.AnimState:PlayAnimation("idle_off", false)
        end

        inst.offering:Remove()
        inst.offering = nil
    end

    inst.AnimState:Hide("SWAP_GEARS")
    inst.SoundEmitter:KillSound("idle_whirring")

    if inst.components.prototyper then
        inst:RemoveComponent("prototyper")
        if inst._delay_heckler_spawn ~= nil then
            inst._delay_heckler_spawn:Cancel()
            inst._delay_heckler_spawn = nil
        end
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
    inst.AnimState:PushAnimation("idle_off", false)
    inst.SoundEmitter:PlaySound("yoth_2026/shrine/place")
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
    local had_offering = inst.offering ~= nil
    inst.was_hammered = true
    DropOffering(inst, worker)
    MakeEmpty(inst)
    if not inst:HasTag("burnt") then
        inst.SoundEmitter:PlaySound("yoth_2026/shrine/deactivate")
        inst.AnimState:PlayAnimation(had_offering and "deactivate2" or "hit_off")
        inst.AnimState:PushAnimation("idle_off", false)
    end
    inst.was_hammered = nil
end

local function SpawnHeckler(inst)
    inst.heckler = SpawnPrefab("charlie_heckler")
    inst.heckler.Follower:FollowSymbol(inst.GUID, "bird1", 0, 0, 0, true)
    inst.heckler.sound_set = "a"
    inst.heckler.is_yoth_helper = true
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
        MakeEmpty(inst, true)
    end
end

local function OnLoadPostPass(inst, data)
    if inst.offering then
        TheWorld:PushEvent("ms_knightshrineactivated", inst)
    end
end

-- String/Inspectable functions
local function GetStatus(inst)
    return (inst.components.trader ~= nil and "EMPTY")
        or nil
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
    inst.MiniMapEntity:SetIcon("yoth_knightshrine.png")

    inst.AnimState:SetBank("yoth_knightshrine")
    inst.AnimState:SetBuild("yoth_knightshrine")
    inst.AnimState:PlayAnimation("idle_off")
    inst.AnimState:Hide("SWAP_GEARS")

    inst:AddTag("structure")
    inst:AddTag("knightshrine")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    --inst.offering = nil
    inst._onofferingremoved = function() MakeEmpty(inst) end
    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = GetStatus
    --
    MakePrototyper(inst)
    inst:ListenForEvent("onbuilt", on_built)
    --
    inst:AddComponent("lootdropper")
    inst:AddComponent("timer")
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
    SpawnHeckler(inst)
    --
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:ListenForEvent("ondeconstructstructure", DropOffering)
    inst:ListenForEvent("onremove", UnregisterShrine) -- This case has to be here because we don't use a source modifier list in yoth_knightmanager

    return inst
end

return Prefab("yoth_knightshrine", fn, assets, prefabs),
    MakePlacer("yoth_knightshrine_placer", "yoth_knightshrine", "yoth_knightshrine", "placer")