local assets =
{
    Asset("ANIM", "anim/ocean_trawler.zip"),
    Asset("ANIM", "anim/splash_water_rot.zip"),
    Asset("ANIM", "anim/swimming_ripple.zip"),
    Asset("MINIMAP_IMAGE", "ocean_trawler_down")
}

local function onsave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function onload(inst, data)

    if data and data.burnt and inst.components.burnable ~= nil and inst.components.burnable.onburnt ~= nil then
        inst.components.burnable.onburnt(inst)
    end
end

--[[local function OnInit(inst)
    if inst.components.oceantrawler then
        inst.components.oceantrawler:CheckForMalbatross()
    end
end]]

local function onopen(inst)
    inst.SoundEmitter:PlaySound("monkeyisland/trawlingpole/open")
end

local function onclose(inst)
    inst.SoundEmitter:PlaySound("monkeyisland/trawlingpole/close")
end

local function onbuilt(inst)
    inst.sg:GoToState("place")
end

local function ondeath(inst)
    local collapse_fx = SpawnPrefab("collapse_small")
    collapse_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    collapse_fx:SetMaterial("wood")

    if inst.components.container then
        local pt = inst:GetPosition()
        inst.components.container:DropEverything(pt)
    end

    if inst.components.oceantrawler then
        inst.components.oceantrawler:ReleaseOverflowFish()
    end

    inst:Remove()
end

local function onhammered(inst, worker)
    inst.components.lootdropper:DropLoot()
    ondeath(inst)
end

local function onburnt(inst)

    -- Cook fish in the trawler
    local pos = inst:GetPosition()
    for i = 1, inst.components.container:GetNumSlots() do
        local item = inst.components.container:GetItemInSlot(i)
        if item ~= nil and item.components.lootdropper ~= nil then
            local loot = item.components.lootdropper:GenerateLoot()
            for k, v in pairs(loot) do
                local loot = SpawnPrefab(v)
                if loot ~= nil then
                    loot.Transform:SetPosition(pos:Get())
                end
            end
        end
    end

    DefaultBurntStructureFn(inst)
end

local function onhit(inst, hitter)
    inst.sg:GoToState("hit")
end

local function GetStatus(inst, viewer)
    local oceantrawler = inst.components.oceantrawler
    if oceantrawler then
        local escaped = oceantrawler:HasFishEscaped()
        if oceantrawler:IsLowered() and not escaped then
            return "LOWERED"
        elseif escaped then
            return "ESCAPED"
        elseif oceantrawler:HasCaughtItem() then
            return "CAUGHT"
        else
            return "GENERIC"
        end
    else
        return "GENERIC"
    end
end

local function FishPreserverRate(inst, item)
    local oceantrawler = inst.components.oceantrawler
    return oceantrawler and oceantrawler:IsLowered() and (item ~= nil and item:HasTag("fish")) and TUNING.OCEAN_TRAWLER_LOWERED_PERISH_RATE or nil
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity() -- Also set minimap icon in components.oceantrawler:OnLoad() & when raising/lowering
    inst.entity:AddNetwork()

    inst.AnimState:AddOverrideBuild("splash_water_rot")
    inst.AnimState:OverrideSymbol("water_fx_ripple", "swimming_ripple", "water_fx_ripple")
    inst.AnimState:OverrideSymbol("water_fx_blue", "swimming_ripple", "water_fx_blue")
    inst.AnimState:OverrideSymbol("water_fx_shadow", "swimming_ripple", "water_fx_shadow")

    inst.MiniMapEntity:SetIcon("ocean_trawler.png")

    inst:AddTag("oceantrawler")
    inst:AddTag("overriderowaction")

    inst:SetPhysicsRadiusOverride(2.2)
    inst:SetDeployExtraSpacing(1.15)

    MakeInventoryPhysics(inst)
    MakeWaterObstaclePhysics(inst, 1.15, 2, 0.75)

    inst.AnimState:SetBank("ocean_trawler")
    inst.AnimState:SetBuild("ocean_trawler")
    inst.AnimState:PlayAnimation("idle")

    --[[MakeInventoryFloatable(inst, "med", nil, {1.3, 0.9, 1.1})
    inst.components.floater.bob_percent = 0]]

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    --[[local land_time = (POPULATING and math.random()*5*FRAMES) or 0
    inst:DoTaskInTime(land_time, function(inst)
        inst.components.floater:OnLandedServer()
    end)]]

    inst:ListenForEvent("onbuilt", onbuilt)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("ocean_trawler")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("lootdropper")

    inst:ListenForEvent("death", ondeath)

    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(FishPreserverRate)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent("oceantrawler")
    inst:SetStateGraph("SGoceantrawler")

    MakeLargeBurnable(inst)
    MakeLargePropagator(inst)
    inst.components.burnable:SetOnBurntFn(onburnt)

    MakeHauntableWork(inst)

    inst.OnSave = onsave
    inst.OnLoad = onload

    MakeSnowCovered(inst)

    --inst:DoTaskInTime(0, OnInit)

    return inst
end

return Prefab("ocean_trawler", fn, assets),
        MakeDeployableKitItem("ocean_trawler_kit", "ocean_trawler", "ocean_trawler", "ocean_trawler", "kit", assets, {size = "med"}, {"ocean_trawler"}, {fuelvalue = TUNING.LARGE_FUEL}, { deploymode = DEPLOYMODE.WATER, deployspacing = DEPLOYSPACING.MEDIUM, usedeployspacingasoffset = true, }, nil),
        MakePlacer("ocean_trawler_kit_placer", "ocean_trawler", "ocean_trawler", "idle", false, false, false, nil, nil, nil, nil, 2.8)
