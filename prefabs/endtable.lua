require "prefabutil"

local prefabs =
{
    "collapse_small",
}

local assets =
{
    Asset("ANIM", "anim/stagehand.zip"),
    Asset("ANIM", "anim/swap_flower.zip"),
    Asset("SOUND", "sound/sfx.fsb"),
}

local function OnUpdateLight(inst, radius, intensity, falloff)
	if radius > 0 then
		inst.AnimState:SetLightOverride(0.3)
		inst.Light:SetRadius(radius)
		inst.Light:SetIntensity(intensity)
		inst.Light:SetFalloff(falloff)
		inst.Light:Enable(true)
	else
		inst.AnimState:SetLightOverride(0)
		inst.Light:Enable(false)
	end
end

local function OnUpdateFlower(inst, flowerid, fresh)
	if flowerid then
		inst.AnimState:ShowSymbol("swap_flower")
		inst.AnimState:OverrideSymbol("swap_flower", "swap_flower", string.format("f%d%s", flowerid, fresh and "" or "_wilt"))
	else
		inst.AnimState:HideSymbol("swap_flower")
    end
end

local function ondeconstructstructure(inst)
	if inst.components.vase and inst.components.vase:HasFlower() then
		inst.components.lootdropper:SpawnLootPrefab("spoiled_food") -- because destroying an endtable will spoil any flowers in it
    end
end

local function onhammered(inst)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker, workleft)
    if workleft > 0 and not inst:HasTag("burnt") then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stagehand/hit")
        inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle", false)
    end
end

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stagehand/hit")
end

local function OnDecorate(inst, giver, item, flowerid)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stagehand/hit")
    inst.AnimState:PlayAnimation("hit")
	inst.AnimState:PushAnimation("idle", false)

	local sanityboost = TUNING.VASE_FLOWER_SWAPS[flowerid].sanityboost
	if sanityboost ~= 0 and giver and giver.components.sanity and not inst.components.vase:HasFreshFlower() then
		giver.components.sanity:DoDelta(sanityboost)
	end
end

local function onignite(inst)
    if inst.components.vase ~= nil then
        inst.components.vase:Disable()
		inst.components.vase:WiltFlower()
    end

    DefaultBurnFn(inst)
end

local function onextinguish(inst)
    if inst.components.vase ~= nil then
        inst.components.vase:Enable()
    end
    DefaultExtinguishFn(inst)
end

local function onburnt(inst)
    if inst.components.vase ~= nil then
		if inst.components.vase:HasFlower() then
			inst.components.vase:ClearFlower()
			inst.components.lootdropper:SpawnLootPrefab("ash")
		end
        inst:RemoveComponent("vase")
    end

    DefaultBurntStructureFn(inst)
end

local function lootsetfn(lootdropper)
	if lootdropper.inst.components.vase and lootdropper.inst.components.vase:HasFlower() then
        lootdropper:SetLoot({ "spoiled_food" }) -- because destroying an endtable will spoil any flowers in it
    end
end

local function getstatus(inst)
	if inst:HasTag("burnt") then
		return "BURNT"
	elseif inst.components.vase then
		if not inst.components.vase:HasFlower() then
			return "EMPTY"
		elseif not inst.components.vase:HasFreshFlower() then
			return "WILTED"
		end
		local wilttime = inst.components.vase:GetTimeToWilt()
		if wilttime then
			return wilttime / TUNING.ENDTABLE_FLOWER_WILTTIME < 0.1 and "OLDLIGHT" or "FRESHLIGHT"
		end
	end
end

local function onsave(inst, data)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() or inst:HasTag("burnt") then
        data.burnt = true
    end
end

local function onload(inst, data)
	if data then
		--backward compatible savedata
		if data.flowerid then
			inst.components.vase:SetFlower(data.flowerid, data.wilttime or 0)
		end
		--

		if data.burnt then
			inst.components.burnable.onburnt(inst)
		end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Light:SetFalloff(0.9)
    inst.Light:SetIntensity(.5)
    inst.Light:SetRadius(1.5)
    inst.Light:SetColour(169/255, 231/255, 245/255)
    inst.Light:Enable(false)

	inst:SetDeploySmartRadius(0.75) --recipe min_spacing/2

    MakeObstaclePhysics(inst, .6)

    inst:AddTag("structure")
    inst:AddTag("vase")

    inst.AnimState:SetBank("stagehand")
    inst.AnimState:SetBuild("stagehand")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:HideSymbol("swap_flower")  -- no flowers on placement

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent("vase")
	inst.components.vase:SetOnUpdateFlowerFn(OnUpdateFlower)
	inst.components.vase:SetOnUpdateLightFn(OnUpdateLight)
	inst.components.vase:SetOnDecorateFn(OnDecorate)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLootSetupFn(lootsetfn)

    MakeSmallBurnable(inst, nil, nil, true)
    inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnExtinguishFn(onextinguish)
    inst.components.burnable:SetOnBurntFn(onburnt)

    MakeSmallPropagator(inst)
    MakeHauntableWork(inst)
    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountSmall(inst)

    inst:ListenForEvent("onbuilt", onbuilt)
	inst:ListenForEvent("ondeconstructstructure", ondeconstructstructure)

    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("endtable", fn, assets, prefabs),
       MakePlacer("endtable_placer", "stagehand", "stagehand", "idle", nil, nil, nil, nil, nil, nil, function(inst) inst.AnimState:HideSymbol("swap_flower") end)
