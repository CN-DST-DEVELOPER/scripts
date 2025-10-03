require("prefabutil")

local assets =
{
	Asset("ANIM", "anim/statue_vault.zip"),
}

local prefabs =
{
	"collapse_small",
}

--variation
--  1: no moss
--  2: moss1
--  3: moss2
--  4: no moss (broken)
--  5: moss1 (broken)
--  6: moss2 (broken)
local function SetVariation(inst, variation)
	if inst.variation ~= variation then
		inst.broken:set(variation > 3)
		local wasbroken = inst.variation > 3
		local moss = inst.broken:value() and variation - 4 or variation - 1
		local oldmoss = wasbroken and inst.variation - 4 or inst.variation - 1

		inst.variation = variation

		if inst.broken:value() ~= wasbroken then
			inst.AnimState:PlayAnimation(inst.anim..(inst.broken:value() and "b" or ""))
		end
		if moss ~= oldmoss then
			if oldmoss > 0 then
				inst.AnimState:Hide("moss"..tostring(oldmoss))
			end
			if moss > 0 then
				inst.AnimState:Show("moss"..tostring(moss))
			end
		end
	end
end

local function OnHammered(inst)
	local fx = SpawnPrefab("collapse_small")
	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
	fx:SetMaterial("pot")
	inst.components.lootdropper:DropLoot()
	inst:Remove()
end

local function OnPutOnFurniture(inst)--, furniture)
	inst.components.workable:SetWorkable(false)
end

local function OnTakeOffFurniture(inst)--, furniture)
	inst.components.workable:SetWorkable(true)
end

local function OnUpdateFlower(inst, flowerid, fresh)
	if flowerid then
		inst.AnimState:ShowSymbol("swap_flower")
		inst.AnimState:OverrideSymbol("swap_flower", "swap_flower", string.format("f%d%s", flowerid, fresh and "" or "_wilt"))
	else
		inst.AnimState:HideSymbol("swap_flower")
	end
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

local function OnDecorate(inst, giver, item, flowerid)
	local sanityboost = TUNING.VASE_FLOWER_SWAPS[flowerid].sanityboost
	if sanityboost ~= 0 and giver and giver.components.sanity and not inst.components.vase:HasFreshFlower() then
		giver.components.sanity:DoDelta(sanityboost)
	end
end

local function OnDeconstruct(inst)
	if inst.components.vase:HasFlower() then
		inst.components.lootdropper:SpawnLootPrefab("spoiled_food")
	end
end

local function ConvertToCrafted(inst)
	inst:SetVariation(1)
	inst.variation = nil
end

local function AttachToVaultPillar(inst, pillar)
	inst:RemoveComponent("inventoryitem")
	inst:RemoveComponent("furnituredecor")
	inst:RemoveComponent("vase")
	inst:RemoveComponent("workable")
	inst:RemoveComponent("lootdropper")
	inst:RemoveComponent("hauntable")

	inst:RemoveEventCallback("ondeconstructstructure", OnDeconstruct)

	inst.components.inspectable.getstatus = nil
	inst.components.inspectable:SetNameOverride("relic")

	inst.Physics:SetActive(false)
	inst.Follower:FollowSymbol(pillar.GUID, "follow_cap", 0, 0, 0, true)
	inst.pillar = pillar
end

local function OnSave(inst, data)
	if inst.variation then
		data.variation = inst.variation
		if inst.pillar then
			data.pillar = inst.pillar.GUID
			return { inst.pillar.GUID }
		end
	end
end

local function OnLoad(inst, data)--, ents)
	if data and data.variation then
		inst:SetVariation(data.variation)
	else
		ConvertToCrafted(inst)
	end
end

local function OnLoadPostPass(inst, ents, data)
	if data and data.pillar and inst.variation then
		local pillar = ents[data.pillar]
		if pillar and pillar.entity:IsValid() then
			inst:AttachToVaultPillar(pillar.entity)
		else
			inst.persists = false
			inst:Hide()
			inst:DoStaticTaskInTime(0, inst.Remove)
		end
	end
end

local function DisplayNameFn(inst)
	return (inst.broken:value() and STRINGS.NAMES.VAULTRELIC_BROKEN)
		or (not inst:HasTag("HAMMER_workable") and STRINGS.NAMES.VAULTRELIC)
		or nil
end

local function GetStatus(inst, viewer)
	if not inst.components.vase:HasFlower() then
		inst.components.inspectable:SetNameOverride("relic")
		return
	end

	inst.components.inspectable:SetNameOverride("decor_flowervase")
	if not inst.components.vase:HasFreshFlower() then
		return "WILTED"
	end
	local wilttime = inst.components.vase:GetTimeToWilt()
	if wilttime then
		return wilttime / TUNING.ENDTABLE_FLOWER_WILTTIME < 0.1 and "OLDLIGHT" or "FRESHLIGHT"
	end
end

local function _makeitem(name, anim, vase)
	local function _fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddFollower()
		inst.entity:AddNetwork()

		if vase then
			inst.entity:AddLight()
			inst.Light:SetFalloff(0.9)
			inst.Light:SetIntensity(.5)
			inst.Light:SetRadius(1.5)
			inst.Light:SetColour(169/255, 231/255, 245/255)
			inst.Light:Enable(false)

			--vase (from vase component) added to pristine state for optimization
			inst:AddTag("vase")
		end

		MakeInventoryPhysics(inst)

		inst.AnimState:SetBank("statue_vault")
		inst.AnimState:SetBuild("statue_vault")
		inst.AnimState:PlayAnimation(anim)
		inst.AnimState:Hide("moss1")
		inst.AnimState:Hide("moss2")

		--furnituredecor (from furnituredecor component) added to pristine state for optimization
		inst:AddTag("furnituredecor")

		inst.broken = net_bool(inst.GUID, "vaultrelic.broken")
		inst.displaynamefn = DisplayNameFn

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.anim = anim

		inst:AddComponent("inspectable")
		inst.components.inspectable:SetNameOverride("relic")

		inst:AddComponent("inventoryitem")

		inst:AddComponent("furnituredecor")
		inst.components.furnituredecor.onputonfurniture = OnPutOnFurniture
		inst.components.furnituredecor.ontakeofffurniture = OnTakeOffFurniture

		if vase then
			inst:AddComponent("vase")
			inst.components.vase:SetOnUpdateFlowerFn(OnUpdateFlower)
			inst.components.vase:SetOnUpdateLightFn(OnUpdateLight)
			inst.components.vase:SetOnDecorateFn(OnDecorate)

			inst.components.inspectable.getstatus = GetStatus

			inst:ListenForEvent("ondeconstructstructure", OnDeconstruct)
		end

		inst:AddComponent("workable")
		inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
		inst.components.workable:SetWorkLeft(1)
		inst.components.workable:SetOnFinishCallback(OnHammered)

		inst:AddComponent("lootdropper")

		MakeHauntableWork(inst)

		inst.variation = 1
		inst.SetVariation = SetVariation
		inst.AttachToVaultPillar = AttachToVaultPillar
		inst.OnBuiltFn = ConvertToCrafted
		inst.OnSave = OnSave
		inst.OnLoad = OnLoad
		inst.OnLoadPostPass = OnLoadPostPass

		return inst
	end
	return Prefab(name, _fn, assets, prefabs)
end

return _makeitem("vaultrelic_bowl", "idle_vase1", false),
	_makeitem("vaultrelic_vase", "idle_vase2", true),
	_makeitem("vaultrelic_planter", "idle_vase3", true)
