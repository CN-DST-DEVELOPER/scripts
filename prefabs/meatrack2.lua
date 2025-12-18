require "prefabutil"

local assets =
{
	Asset("ANIM", "anim/ui_meatrack_multi_3x1.zip"),

	Asset("ANIM", "anim/meat_rack_multi.zip"),
	Asset("ANIM", "anim/meat_rack.zip"),
	Asset("ANIM", "anim/meat_rack_food.zip"),
}

local assets_hermit1 =
{
	Asset("ANIM", "anim/ui_hermitcrab_meatrack_1x1.zip"),

	Asset("ANIM", "anim/meatrack_hermit.zip"),
	Asset("ANIM", "anim/meat_rack_food.zip"),
}

local assets_hermit =
{
	Asset("ANIM", "anim/ui_hermitcrab_3x3.zip"),

	Asset("ANIM", "anim/meatrack_hermit_multi.zip"),
	Asset("ANIM", "anim/meat_rack_food.zip"),

	Asset("INV_IMAGE", "salt_dried_overlay"),
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
    "fishmeat",
    "fishmeat_dried",
    "fishmeat_small",
    "fishmeat_small_dried",
	"eel",
	"kelp",
	"kelp_dried",
}

local prefabs_hermit = shallowcopy(prefabs)
table.insert(prefabs_hermit, "saltrock") --drying kelp byproduct

local function OnHit(inst, worker)
	if not inst:HasTag("burnt") then
		if inst.components.container then
			inst.components.container:Close()
		end
		if inst:HasTag("abandoned") then
			inst.AnimState:PlayAnimation("broken_hit")
			inst.AnimState:PushAnimation("broken", false)
		else
			inst.AnimState:PlayAnimation("hit")
			inst.AnimState:PushAnimation("idle")
		end
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
	if not inst:HasTag("abandoned") then
		inst.AnimState:PlayAnimation("place")
		inst.AnimState:PushAnimation("idle")
		inst.SoundEmitter:PlaySound(inst.placesound or "dontstarve/common/meat_rack_craft")
	end
end

local function DoBounce(inst, slot, slotstr)
	local numslots = inst.components.container:GetNumSlots()
	if numslots > 3 then
		inst.AnimState:PlayAnimation("bounce")
		if inst._lastbounceslot ~= slotstr then
			inst.AnimState:Show("small_bounce_"..inst._lastbounceslot)
			inst.AnimState:Hide("big_bounce_"..inst._lastbounceslot)
			inst.AnimState:Show("big_bounce_"..slotstr)
			inst.AnimState:Hide("small_bounce_"..slotstr)
			inst._lastbounceslot = slotstr
		end
	else
		inst.AnimState:PlayAnimation("bounce"..slotstr)
	end
	inst.AnimState:PushAnimation("idle")
	inst.SoundEmitter:PlaySound("dontstarve/common/together/put_meat_rack")
end

local function HideRackItem(inst, slot, name)
	local slotstr = tostring(slot)

	local skin_build = inst:GetSkinBuild()
	if skin_build then
		inst.AnimState:OverrideSkinSymbol("swap_rope"..slotstr, skin_build, "swap_rope_empty")
	else
		inst.AnimState:OverrideSymbol("swap_rope"..slotstr, inst.build, "swap_rope_empty")
	end

	inst.AnimState:ClearOverrideSymbol("swap_dried"..slotstr)

	if not (name == "saltrock" or inst:IsAsleep() or inst:HasTag("burnt") or POPULATING) then
		DoBounce(inst, slot, slotstr)
	end
end

local function ShowRackItem(inst, slot, name, build)
	if name == "saltrock" then
		HideRackItem(inst, slot, name)
		return
	end

	local slotstr = tostring(slot)

	local skin_build = inst:GetSkinBuild()
	if skin_build then
		inst.AnimState:OverrideSkinSymbol("swap_rope"..slotstr, skin_build, "swap_rope")
	else
		inst.AnimState:OverrideSymbol("swap_rope"..slotstr, inst.build, "swap_rope")
	end

	inst.AnimState:OverrideSymbol("swap_dried"..slotstr, build, name)

	if not (inst:IsAsleep() or inst:HasTag("burnt") or POPULATING) then
		DoBounce(inst, slot, slotstr)
	end
end

local function OnMeatRackSkinChanged(inst, skin_build)
	local container = inst.components.dryingrack and inst.components.dryingrack:GetContainer()
	if container == nil then
		return
	elseif skin_build then
		for i = 1, container:GetNumSlots() do
			inst.AnimState:OverrideSkinSymbol("swap_rope"..tostring(i), skin_build, container:GetItemInSlot(i) and "swap_rope" or "swap_rope_empty")
		end
	else
		for i = 1, container:GetNumSlots() do
			inst.AnimState:OverrideSymbol("swap_rope"..tostring(i), inst.build, container:GetItemInSlot(i) and "swap_rope" or "swap_rope_empty")
		end
	end
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

local function GetStatus(inst)--, viewer)
	if inst:HasTag("burnt") then
		return "BURNT"
	end

	local container = inst.components.dryingrack and inst.components.dryingrack:GetContainer()
	if container == nil then
		return "ABANDONED"
	end

	--priority
	--6: done meat
	--5: done not meat
	--4: collected salt
	--3: drying meat
	--2: drying not meat
	--1: rot
	--0: nothing
	local prioritystatus = inst._saltlevel and inst._saltlevel ~= "none" and 4 or 0
	for k, v in pairs(container.slots) do
		local foodtype = v.components.edible and v.components.edible.foodtype
		local ismeat = foodtype == FOODTYPE.MEAT
		if v.components.dryable then
			prioritystatus = math.max(prioritystatus, ismeat and 3 or 2)
		elseif ismeat then
			prioritystatus = 6
			break
		else
			local isrot = foodtype == FOODTYPE.GENERIC
			prioritystatus = math.max(prioritystatus, isrot and 1 or 5)
		end
	end

	if prioritystatus == 0 then
		return
	elseif prioritystatus == 6 then
		return "DONE"
	elseif prioritystatus == 5 then
		return "DONE_NOTMEAT"
	elseif prioritystatus == 4 then
		return "DONE_SALT"
	end

	local hasrain = TheWorld.state.israining and inst.components.rainimmunity == nil
	if prioritystatus == 3 then
		return hasrain and "DRYINGINRAIN" or "DRYING"
	elseif prioritystatus == 2 then
		return hasrain and "DRYINGINRAIN_NOTMEAT" or "DRYING_NOTMEAT"
	elseif prioritystatus == 1 then
		return "DONE_NOTMEAT"
	end
end

local function CHEVO_OnItemGet(inst, data)
    if data and data.item then
        if data.item.components.dryable then
            TheWorld:PushEvent("CHEVO_starteddrying", {target = inst})
        end
    end
end

local function MakeMeatRack(name, bank, build, numslots, common_postinit, master_postinit, _assets, _prefabs)
	local nodestroy = name == "meatrack_hermit"

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddMiniMapEntity()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst.MiniMapEntity:SetIcon(name..".png")

		inst:AddTag("structure")
		if nodestroy then
			inst:AddTag("antlion_sinkhole_blocker")
		end

		inst.AnimState:SetBank(bank)
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation("idle", true)
		inst.AnimState:Hide("mouseover")

		for i = 1, numslots do
			inst.AnimState:OverrideSymbol("swap_rope"..tostring(i), build, "swap_rope_empty")
		end
		if numslots > 3 then
			inst.AnimState:Hide("small_bounce_1")
			for i = 2, numslots do
				inst.AnimState:Hide("big_bounce_"..tostring(i))
			end
			inst._lastbounceslot = TheWorld.ismastersim and "1" or nil
		end

		MakeSnowCoveredPristine(inst)

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst.scrapbook_anim = "placer"
		inst.build = build

		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

		MakeHauntableWork(inst)

		inst:AddComponent("inspectable")
		inst.components.inspectable.getstatus = GetStatus

		inst:AddComponent("container")
		inst.components.container:WidgetSetup(name)

		inst:AddComponent("dryingrack") --must add after container is added
		--dryingrack component will further configure these:
		-- container.isexposed
		-- adding preserver component
		inst.components.dryingrack:EnableDrying()
		inst.components.dryingrack:SetShowItemFn(ShowRackItem)
		inst.components.dryingrack:SetHideItemFn(HideRackItem)

		if not nodestroy then
			inst:AddComponent("lootdropper")
			inst:AddComponent("workable")
			inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
			inst.components.workable:SetWorkLeft(4)
			inst.components.workable:SetOnFinishCallback(OnHammered)
			inst.components.workable:SetOnWorkCallback(OnHit)

			MakeMediumBurnable(inst, nil, nil, true)
			MakeSmallPropagator(inst)
		end

		MakeSnowCovered(inst)

        inst:ListenForEvent("itemget", CHEVO_OnItemGet)

		inst:ListenForEvent("onbuilt", OnBuilt)

		inst.OnMeatRackSkinChanged = OnMeatRackSkinChanged
		inst.OnSave = OnSave
		inst.OnLoad = OnLoad

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end

	return Prefab(name, fn, _assets, _prefabs)
end

--------------------------------------------------------------------------

local function hermit_OnSaltChanged(inst, num)
	if inst.components.container then
		local _, num2 = inst.components.container:Has("saltrock", 1)
		num = num + num2
	end

	local level =
		(num <= 0 and "none") or
		(num <= 3 and "low") or
		(num <= 6 and "medium") or
		"high"

	if inst._saltlevel ~= level then
		inst.AnimState:Hide("salt_"..inst._saltlevel)
		inst.AnimState:Show("salt_"..level)
		inst._saltlevel = level
	end
end

local function hermit_ClearInvSaltDried(item)
	item:RemoveEventCallback("onputininventory", hermit_ClearInvSaltDried)
	item:RemoveEventCallback("ondropped", hermit_ClearInvSaltDried)
	item.components.driedsalticon:HideSaltIcon()
end

local function hermit_OnItemGet(inst, data)
	if data and data.item and inst.components.dryingracksaltcollector then
		if data.item.components.driedsalticon and data.slot then
			if data.item.components.driedsalticon.collects then
				inst.components.dryingracksaltcollector:AddSalt(data.slot)
			end
			if inst.components.dryingracksaltcollector:HasSalt(data.slot) then
				data.item.components.driedsalticon:ShowSaltIcon()
				data.item:ListenForEvent("onputininventory", hermit_ClearInvSaltDried)
				data.item:ListenForEvent("ondropped", hermit_ClearInvSaltDried)
			end
		end
		if data.item.prefab == "saltrock" then
			hermit_OnSaltChanged(inst, inst.components.dryingracksaltcollector:GetNumSalts())
		end
	end
end

local function hermit_DoItemTaken(inst, slot)
	if inst.components.container and inst.components.dryingracksaltcollector then
		local other = inst.components.container:GetItemInSlot(slot)
		if other then
			if other.components.driedsalticon == nil then
				if inst.components.dryingracksaltcollector:RemoveSalt(slot) then
					local salt = SpawnPrefab("saltrock")
					salt.Transform:SetPosition(inst.Transform:GetWorldPosition())
					salt.components.inventoryitem:OnDropped(true)
				end
			end
		elseif inst.components.dryingracksaltcollector:RemoveSalt(slot) then
			inst.components.container:GiveItem(SpawnPrefab("saltrock"), slot)
		end
	end
end

local function hermit_OnItemLose(inst, data)
	if data and inst.components.dryingracksaltcollector then
		if data.slot and inst.components.dryingracksaltcollector:HasSalt(data.slot) then
			if data.prev_item and data.prev_item:IsValid() then
				inst:DoStaticTaskInTime(0, hermit_DoItemTaken, data.slot)
			else
				inst.components.dryingracksaltcollector:RemoveSalt(data.slot)
			end
		end
		if data.prev_item and data.prev_item.prefab == "saltrock" then
			hermit_OnSaltChanged(inst, inst.components.dryingracksaltcollector:GetNumSalts())
		end
	end
end

local function hermit_DumpAndRemoveSaltCollector(inst)
	if inst.components.dryingracksaltcollector then
		local num = inst.components.dryingracksaltcollector:GetNumSalts()
		if num > 0 then
			local salt = inst.components.lootdropper:SpawnLootPrefab("saltrock")
			if num > 1 then
				salt.components.stackable:SetStackSize(num)
			end
		end
		inst:RemoveComponent("dryingracksaltcollector")
	end
end

local function hermit_OnDeconstructed(inst, caster)
	hermit_DumpAndRemoveSaltCollector(inst)
	--drop again, since salt would've been placed back in
	if inst.components.container then
		inst.components.container:DropEverything()
	end
end

local function hermit_OnHammered(inst, worker)
	hermit_DumpAndRemoveSaltCollector(inst)
	OnHammered(inst, worker)
end

local function hermit_OnBurnt(inst)
	hermit_DumpAndRemoveSaltCollector(inst)
	DefaultBurntStructureFn(inst)
end

local function hermit_MakeBroken(inst)
	inst:AddTag("abandoned")
	hermit_DumpAndRemoveSaltCollector(inst)
	inst:RemoveComponent("dryingrack")
	if inst.components.container then
		inst.components.container:DropEverything()
		inst.components.container:Close()
		inst:RemoveComponent("container")
	end
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("broken")
	end
	inst.abandoning_task = nil
end

local VAR_ABANDON_TIME = 30 * FRAMES
local FX_SYNC_TIME = 12 * FRAMES
local function hermit_WithinAreaChanged(inst, iswithin)
	if not iswithin and not inst:HasTag("abandoned") then
		local function hermit_WithinAreaChanged_Delay()
			SpawnPrefab("hermitcrab_fx_med").Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.abandoning_task = inst:DoTaskInTime(FX_SYNC_TIME, hermit_MakeBroken)
		end
		inst.abandoning_task = inst:DoTaskInTime(VAR_ABANDON_TIME * math.random(), hermit_WithinAreaChanged_Delay)
	end
end

local function hermit_OnSave(inst, data)
	OnSave(inst, data)
	if inst:HasTag("abandoned") or inst.abandoning_task ~= nil then
		data.abandoned = true
	end
end

local function hermit_OnLoad(inst, data, ents)
	OnLoad(inst, data, ents)
	if data and data.abandoned then
		hermit_MakeBroken(inst)
	end
end

local function hermit_OnLoadPostPass(inst)--, ents, data)
	if inst.components.container and inst.components.dryingracksaltcollector and inst.components.dryingracksaltcollector:HasSalt() then
		for i = 1, inst.components.container:GetNumSlots() do
			if inst.components.dryingracksaltcollector:HasSalt(i) then
				local item = inst.components.container:GetItemInSlot(i)
				if item then
					if item.components.driedsalticon == nil then
						if inst.components.dryingracksaltcollector:RemoveSalt(i) then
							local salt = SpawnPrefab("saltrock")
							salt.Transform:SetPosition(inst.Transform:GetWorldPosition())
							salt.components.inventoryitem:OnDropped(true)
						end
					end
				elseif inst.components.dryingracksaltcollector:RemoveSalt(i) then
					inst.components.container:GiveItem(SpawnPrefab("saltrock"), i)
				end
			end
		end
	end
end

local function hermit_DisplayNameFn(inst)
	return inst:HasTag("abandoned") and STRINGS.NAMES.MEATRACK_HERMIT_ABANDONED or nil
end

local function hermit_common_postinit(inst)
	inst.AnimState:Hide("salt_low")
	inst.AnimState:Hide("salt_medium")
	inst.AnimState:Hide("salt_high")

	inst.displaynamefn = hermit_DisplayNameFn
end

local function hermit_master_postinit(inst)
	inst._saltlevel = "none"
	inst.placesound = "winter2025/dryingrack_pearl/place"

	inst:AddComponent("dryingracksaltcollector")
	inst.components.dryingracksaltcollector:SetOnSaltChangedFn(hermit_OnSaltChanged)

	inst:ListenForEvent("itemget", hermit_OnItemGet)
	inst:ListenForEvent("itemlose", hermit_OnItemLose)
	inst:ListenForEvent("ondeconstructstructure", hermit_OnDeconstructed)

	inst.components.workable:SetOnFinishCallback(hermit_OnHammered)
	inst.components.burnable:SetOnBurntFn(hermit_OnBurnt)

	MakeHermitCrabAreaListener(inst, hermit_WithinAreaChanged)

	inst.OnSave = hermit_OnSave
	inst.OnLoad = hermit_OnLoad
	inst.OnLoadPostPass = hermit_OnLoadPostPass
end

--------------------------------------------------------------------------

local function hermit1_common_postinit(inst)
	inst.scrapbook_specialinfo = "MEATRACK"
end

local function hermit1_master_postinit(inst)
	inst.scrapbook_anim = "idle_empty"
	TheWorld:PushEvent("ms_register_pearl_entity", inst) -- NOTES(JBK): This function was a stub and now it has a use!
end

--------------------------------------------------------------------------

return MakeMeatRack("meatrack", "meat_rack_multi", "meat_rack", 3, nil, nil, assets, prefabs),
	MakePlacer("meatrack_placer", "meat_rack_multi", "meat_rack", "placer",
		nil, nil, nil, nil, nil, nil,
		function(inst)
			inst.AnimState:Hide("mouseover")
		end),
	MakeMeatRack("meatrack_hermit", "meatrack_hermit", "meatrack_hermit", 1, hermit1_common_postinit, hermit1_master_postinit, assets_hermit1, prefabs),
	MakeMeatRack("meatrack_hermit_multi", "meatrack_hermit_multi", "meatrack_hermit_multi", 9, hermit_common_postinit, hermit_master_postinit, assets_hermit, prefabs_hermit),
	MakePlacer("meatrack_hermit_multi_placer", "meatrack_hermit_multi", "meatrack_hermit_multi", "placer")
