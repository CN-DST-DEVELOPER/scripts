require "prefabutil"

local assets =
{
	Asset("ANIM", "anim/ui_meatrack_multi_3x1.zip"),

	Asset("ANIM", "anim/meat_rack_multi.zip"),
	Asset("ANIM", "anim/meat_rack.zip"),
	Asset("ANIM", "anim/meat_rack_food.zip"),
}

local prefabs =
{
	"collapse_small",

	-- everything it can "produce" and might need symbol swaps from
	"smallmeat",
	"smallmeat_dried",
	"monstermeat",
	"monstermeat_dried",
	"humanmeat",
	"humanmeat_dried",
	"meat",
	"meat_dried",
	"drumstick", -- uses smallmeat_dried
	"batwing", --uses smallmeat_dried
	"fish", -- uses smallmeat_dried
	"froglegs", -- uses smallmeat_dried
	"fishmeat", -- uses smallmeat_dried
	"fishmeat_small", -- uses meat_dried
	"eel",
	"kelp",
	"kelp_dried",
}

local function OnHit(inst, worker)
	if not inst:HasTag("burnt") then
		if inst.components.container then
			inst.components.container:Close()
		end
		inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle")
	end
end

local function OnHammered(inst, worker)
	if inst.components.burnable and inst.components.burnable:IsBurning() then
		inst.components.burnable:Extinguish()
	end
	if inst.components.container then
		inst.components.container:DropEverything()
	end
	inst.components.lootdropper:DropLoot()

	local fx = SpawnPrefab("collapse_small")
	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
	fx:SetMaterial("wood")

	inst:Remove()
end

local function OnBuilt(inst)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("idle")
	inst.SoundEmitter:PlaySound("dontstarve/common/meat_rack_craft")
end

local function ShowRackItem(inst, slot, name, build)
	slot = tostring(slot)

	local skin_build = inst:GetSkinBuild()
	if skin_build then
		inst.AnimState:OverrideSkinSymbol("swap_rope"..slot, skin_build, "swap_rope")
	else
		inst.AnimState:OverrideSymbol("swap_rope"..slot, "meat_rack", "swap_rope")
	end

	inst.AnimState:OverrideSymbol("swap_dried"..slot, build, name)

	if not (inst:IsAsleep() or inst:HasTag("burnt") or POPULATING) then
		inst.AnimState:PlayAnimation("bounce"..slot)
		inst.AnimState:PushAnimation("idle")
		inst.SoundEmitter:PlaySound("dontstarve/common/together/put_meat_rack")
	end
end

local function HideRackItem(inst, slot)
	slot = tostring(slot)

	local skin_build = inst:GetSkinBuild()
	if skin_build then
		inst.AnimState:OverrideSkinSymbol("swap_rope"..slot, skin_build, "swap_rope_empty")
	else
		inst.AnimState:OverrideSymbol("swap_rope"..slot, "meat_rack", "swap_rope_empty")
	end

	inst.AnimState:ClearOverrideSymbol("swap_dried"..slot)

	if not (inst:IsAsleep() or inst:HasTag("burnt") or POPULATING) then
		inst.AnimState:PlayAnimation("bounce"..slot)
		inst.AnimState:PushAnimation("idle")
		inst.SoundEmitter:PlaySound("dontstarve/common/together/put_meat_rack")
	end
end

local function OnMeatRackSkinChanged(inst, skin_build)
	local container = inst.components.dryingrack and inst.components.dryingrack:GetContainer()
	if container == nil then
		return
	elseif skin_build then
		for i = 1, 3 do
			inst.AnimState:OverrideSkinSymbol("swap_rope"..tostring(i), skin_build, container:GetItemInSlot(i) and "swap_rope" or "swap_rope_empty")
		end
	else
		for i = 1, 3 do
			inst.AnimState:OverrideSymbol("swap_rope"..tostring(i), "meat_rack", container:GetItemInSlot(i) and "swap_rope" or "swap_rope_empty")
		end
	end
end

local function OnBurnt(inst)
	DefaultBurntStructureFn(inst)
end

local function OnSave(inst, data)
	if inst:HasTag("burnt") or (inst.components.burnable and inst.components.burnable:IsBurning()) then
		data.burnt = true
	end
end

local function OnLoad(inst, data)--, ents)
	if data then
		if data.burnt then
			inst.components.burnable.onburnt(inst)
		elseif data.dryer then
			--loading old version meatrack data
			if data.dryer.ingredient then
				local item = SpawnPrefab(data.dryer.ingredient)
				if item then
					if data.dryer.ingredientperish and data.dryer.ingredientperish > 0 and item.components.perishable then
						item.components.perishable:SetPercent(math.min(1, data.dryer.ingredientperish))
					end
					item.dryingrack_drytime = data.dryer.remainingtime
					inst.components.container:GiveItem(item, 2)
				end
			elseif data.dryer.product then
				local item = SpawnPrefab(data.dryer.product)
				if item then
					if data.dryer.ingredientperish and data.dryer.ingredientperish > 0 and item.components.perishable then
						item.components.perishable:SetPercent(math.min(1, data.dryer.ingredientperish))
					end
					inst.components.container:GiveItem(item, 2)
					if data.dryer.dried_buildfile then
						inst.components.dryingrack:ApplyDryingInfoSnapshot({ [item] = data.dryer.dried_buildfile })
					end
				end
			end
		end
	end
end

local function GetStatus(inst)
	if inst:HasTag("burnt") then
		return "BURNT"
	end

	local container = inst.components.dryingrack and inst.components.dryingrack:GetContainer()
	if container == nil then
		return
	end

	--priority
	--5: done meat
	--4: done not meat
	--3: drying meat
	--2: drying not meat
	--1: rot
	--0: nothing
	local prioritystatus = 0
	for k, v in pairs(container.slots) do
		local foodtype = v.components.edible and v.components.edible.foodtype
		local ismeat = foodtype == FOODTYPE.MEAT
		if v.components.dryable then
			prioritystatus = math.max(prioritystatus, ismeat and 3 or 2)
		elseif ismeat then
			prioritystatus = 5
			break
		else
			local isrot = foodtype == FOODTYPE.GENERIC
			prioritystatus = math.max(prioritystatus, isrot and 1 or 4)
		end
	end

	if prioritystatus == 0 then
		return
	elseif prioritystatus == 5 then
		return "DONE"
	elseif prioritystatus == 4 or prioritystatus == 1 then
		return "DONE_NOTMEAT"
	end

	local hasrain = TheWorld.state.israining and inst.components.rainimmunity == nil
	if prioritystatus == 3 then
		return hasrain and "DRYINGRAIN" or "DRYING"
	elseif prioritystatus == 2 then
		return hasrain and "DRYINGRAIN_NOTMEAT" or "DRYING_NOTMEAT"
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("meatrack.png")

	inst:AddTag("structure")

	inst.AnimState:SetBank("meat_rack_multi")
	inst.AnimState:SetBuild("meat_rack")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:Hide("mouseover")

	for i = 1, 3 do
		inst.AnimState:OverrideSymbol("swap_rope"..tostring(i), "meat_rack", "swap_rope_empty")
	end

	MakeSnowCoveredPristine(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "placer"

	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	MakeHauntableWork(inst)

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("container")
	inst.components.container:WidgetSetup("meatrack")

	inst:AddComponent("dryingrack") --must add after container is added
	--dryingrack component will further configure these:
	-- container.isexposed
	-- adding preserver component
	inst.components.dryingrack:EnableDrying()
	inst.components.dryingrack:SetShowItemFn(ShowRackItem)
	inst.components.dryingrack:SetHideItemFn(HideRackItem)

	inst:AddComponent("lootdropper")
	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(4)
	inst.components.workable:SetOnFinishCallback(OnHammered)
	inst.components.workable:SetOnWorkCallback(OnHit)

	MakeMediumBurnable(inst, nil, nil, true)
	MakeSmallPropagator(inst)
	inst.components.burnable:SetOnBurntFn(OnBurnt)

	MakeSnowCovered(inst)

	inst:ListenForEvent("onbuilt", OnBuilt)

	inst.OnMeatRackSkinChanged = OnMeatRackSkinChanged
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

return Prefab("meatrack", fn, assets, prefabs),
	MakePlacer("meatrack_placer", "meat_rack_multi", "meat_rack", "placer",
		nil, nil, nil, nil, nil, nil,
		function(inst)
			inst.AnimState:Hide("mouseover")
		end)
