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

local function ConvertToCrafted(inst)
	inst:SetVariation(1)
	inst.variation = nil

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(1)
	inst.components.workable:SetOnFinishCallback(OnHammered)

	inst:AddComponent("lootdropper")

	MakeHauntableWork(inst)
end

local function OnBuilt(inst, data)
	inst.SoundEmitter:PlaySound("dontstarve/common/repair_stonefurniture")
	ConvertToCrafted(inst)
end

local function AttachToVaultPillar(inst, pillar)
	inst.entity:AddFollower():FollowSymbol(pillar.GUID, "follow_cap", 0, 0, 0, true)
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

local function _makeitem(name, anim, min_spacing)
	local function _fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst:SetDeploySmartRadius(min_spacing / 2)
		--MakeSmallObstaclePhysics(inst, 0.2)

		inst.AnimState:SetBank("statue_vault")
		inst.AnimState:SetBuild("statue_vault")
		inst.AnimState:PlayAnimation(anim)
		inst.AnimState:Hide("moss1")
		inst.AnimState:Hide("moss2")

		inst.broken = net_bool(inst.GUID, "vaultrelic.broken")
		inst.displaynamefn = DisplayNameFn

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.anim = anim

		inst:AddComponent("inspectable")
		inst.components.inspectable:SetNameOverride("relic")

		inst:ListenForEvent("onbuilt", OnBuilt)

		inst.variation = 1
		inst.SetVariation = SetVariation
		inst.AttachToVaultPillar = AttachToVaultPillar
		inst.OnSave = OnSave
		inst.OnLoad = OnLoad
		inst.OnLoadPostPass = OnLoadPostPass

		return inst
	end
	return Prefab(name, _fn, assets, prefabs)
end

local function _placer_postinit(inst)
	inst.AnimState:Hide("moss1")
	inst.AnimState:Hide("moss2")
end

local function _makeplacer(name, anim)
	return MakePlacer(name, "statue_vault", "statue_vault", anim, nil, nil, nil, nil, nil, _placer_postinit)
end

return _makeitem("vaultrelic_bowl", "idle_vase1", 1.2),
	_makeitem("vaultrelic_vase", "idle_vase2", 0.9),
	_makeitem("vaultrelic_planter", "idle_vase3", 1.1),
	_makeplacer("vaultrelic_bowl_placer", "idle_vase1"),
	_makeplacer("vaultrelic_vase_placer", "idle_vase2"),
	_makeplacer("vaultrelic_planter_placer", "idle_vase3")
