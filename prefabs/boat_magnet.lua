local assets =
{
    Asset("ANIM", "anim/boat_magnet.zip"),
}

local item_assets =
{
    Asset("ANIM", "anim/boat_magnet.zip"),
}

local prefabs =
{
    "collapse_small",
}

local function on_hammered(inst, hammerer)
    inst.components.lootdropper:DropLoot()

    local collapse_fx = SpawnPrefab("collapse_small")
    collapse_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    collapse_fx:SetMaterial("wood")

    inst:Remove()
end

local function onignite(inst)
	DefaultBurnFn(inst)
end

local function onburnt(inst)
	DefaultBurntStructureFn(inst)

    local magnet = inst.components.magnet
	if magnet ~= nil and magnet.boat ~= nil then
		magnet.boat.components.boatphysics:RemoveMagnet(magnet)
    end

	inst.sg:GoToState("burnt")
	inst:RemoveComponent("boatmagnet")
end

local function onbuilt(inst)
    inst.SoundEmitter:PlaySound("monkeyisland/autopilot/magnet_place")
    inst.sg:GoToState("place")
end

local function onsave(inst, data)
	if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() or inst:HasTag("burnt") then
		data.burnt = true
	end
end

local function onload(inst, data)
	if data ~= nil and data.burnt == true then
        inst.components.burnable.onburnt(inst)
	end
end

local function getstatus(inst, viewer)
    local magnetcmp = inst.components.boatmagnet
    if magnetcmp and magnetcmp:IsActivated() then
        return "ACTIVATED"
    else
        return "GENERIC"
    end
end



local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("boat_magnet")
    inst.AnimState:SetBuild("boat_magnet")
	inst.AnimState:SetFinalOffset(1)

    inst:AddTag("boatmagnet")
    inst:AddTag("structure")

    MakeObstaclePhysics(inst, .2)
	inst:SetPhysicsRadiusOverride(0.25)
    inst.Transform:SetEightFaced()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("boatmagnet")

    inst:AddComponent("lootdropper")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(on_hammered)

    MakeSmallBurnable(inst, nil, nil, true)
	inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnBurntFn(onburnt)


    MakeSmallPropagator(inst)

    MakeHauntableWork(inst)

    inst:ListenForEvent("onbuilt", onbuilt)

    inst:SetStateGraph("SGboatmagnet")

	inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("boat_magnet", fn, assets, prefabs),
       MakeDeployableKitItem("boat_magnet_kit", "boat_magnet", "boat_magnet", "boat_magnet", "kit", item_assets, {size = "med", scale = 0.77}, {"boat_accessory"}, {fuelvalue = TUNING.LARGE_FUEL}, { deployspacing = DEPLOYSPACING.MEDIUM }),
       MakePlacer("boat_magnet_kit_placer", "boat_magnet", "boat_magnet", "idle")
