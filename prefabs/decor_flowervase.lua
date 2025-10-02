local assets =
{
    Asset("ANIM", "anim/decor_flowervase.zip"),
    Asset("ANIM", "anim/swap_flower.zip"),
    Asset("INV_IMAGE", "decor_flowervase"),
    Asset("INV_IMAGE", "decor_flowervase_flowers"),
    Asset("INV_IMAGE", "decor_flowervase_wilted"),
}

local function DoRefreshImage(inst, hasflower, fresh)
	local skinname = inst:GetSkinName()
	local imagename =
		hasflower and
		((skinname or "decor_flowervase")..(fresh and "_flowers" or "_wilted")) or
		skinname
		--nil if it's default empty and unskinned

	if inst.components.inventoryitem.imagename ~= imagename then
		inst.components.inventoryitem:ChangeImageName(imagename)
	end
end

local function RefreshImage(inst)
	DoRefreshImage(inst, inst.components.vase:HasFlower(), inst.components.vase:HasFreshFlower())
end

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
	if not (POPULATING or inst:IsAsleep()) then
		inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle", false)
	end
	DoRefreshImage(inst, flowerid ~= nil, fresh)
end

--
local function OnDecorate(inst, giver, item, flowerid)
	local sanityboost = TUNING.VASE_FLOWER_SWAPS[flowerid].sanityboost
	if sanityboost ~= 0 and giver and giver.components.sanity and not inst.components.vase:HasFreshFlower() then
		giver.components.sanity:DoDelta(sanityboost)
	end
end

local function flower_vase_lootsetfn(lootdropper)
	if lootdropper.inst.components.vase:HasFlower() then
        lootdropper:SetLoot({"spoiled_food"})
    end
end

local function flower_vase_getstatus(inst)
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

-- BURNABLE
local function onignite(inst)
    inst.components.vase:Disable()
	inst.components.vase:WiltFlower()
    DefaultBurnFn(inst)
end

local function onextinguish(inst)
    inst.components.vase:Enable()
    DefaultExtinguishFn(inst)
end

local function onburnt(inst)
    inst.components.vase:Disable()
	if inst.components.vase:HasFlower() then
		inst.components.vase:ClearFlower()
        inst.components.lootdropper:SpawnLootPrefab("ash")
    end

    -- This will also spawn an ash, so we spawn 2 if there was a flower in the vase.
    DefaultBurntFn(inst)
end

local function OnDeconstruct(inst)
	if inst.components.vase and inst.components.vase:HasFlower() then
		inst.components.lootdropper:SpawnLootPrefab("spoiled_food")
	end
end

-- SAVE/LOAD
local function OnLoad(inst, data)
	--backward compatible savedata
	if data and data.flower_id then
		inst.components.vase:SetFlower(data.flower_id, data.wilt_time or 0)
	end
end

--
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("decor_flowervase")
    inst.AnimState:SetBuild("decor_flowervase")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:HideSymbol("swap_flower")

	--furnituredecor (from furnituredecor component) added to pristine state for optimization
	inst:AddTag("furnituredecor")

	--vase (from vase component) added to pristine state for optimization
	inst:AddTag("vase")

    inst.Light:SetFalloff(0.9)
    inst.Light:SetIntensity(.5)
    inst.Light:SetRadius(1.5)
    inst.Light:SetColour(169/255, 231/255, 245/255)
    inst.Light:Enable(false)

    MakeInventoryFloatable(inst, "small", 0.05, 0.65)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local furnituredecor = inst:AddComponent("furnituredecor")

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = flower_vase_getstatus

    --
    local inventoryitem = inst:AddComponent("inventoryitem")

    --
    local lootdropper = inst:AddComponent("lootdropper")
    lootdropper:SetLootSetupFn(flower_vase_lootsetfn)

    --
    local vase = inst:AddComponent("vase")
	vase:SetOnUpdateFlowerFn(OnUpdateFlower)
	vase:SetOnUpdateLightFn(OnUpdateLight)
	vase:SetOnDecorateFn(OnDecorate)

    --
    MakeHauntable(inst)

    --
    local burnable = MakeSmallBurnable(inst)
    burnable:SetOnIgniteFn(onignite)
    burnable:SetOnExtinguishFn(onextinguish)
    burnable:SetOnBurntFn(onburnt)

    MakeSmallPropagator(inst)

	inst:ListenForEvent("ondeconstructstructure", OnDeconstruct)

    --
    inst.OnLoad = OnLoad

	inst.RefreshImage = RefreshImage --used by prefabskin.lua as well, to support reskin_tool

    return inst
end

return Prefab("decor_flowervase", fn, assets)