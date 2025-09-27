local assets =
{
	Asset("ANIM", "anim/portable_firepit.zip"),
}

local prefabs =
{
	"portable_campfirefire",
	"charcoal",
	"portablefirepit_item",
}

local prefabs_item =
{
	"portablefirepit",
}

local function ChangeToItem(inst)
	local item = SpawnPrefab("portablefirepit_item")
	item.Transform:SetPosition(inst.Transform:GetWorldPosition())
	item.AnimState:PlayAnimation("collapse")
	item.SoundEmitter:PlaySound("meta5/walter/portable_fireplace_collapse")
	item.fuel = inst.components.fueled:GetPercent() + (inst.deploytask and inst.deploytask.fuel or 0)
	if inst.queued_charcoal and inst.components.fueled:GetCurrentSection() <= 1 then
		inst.components.lootdropper:SpawnLootPrefab("charcoal")
	end
	inst:Remove()
end

local function onpostdeploy(inst, fuel)
	inst.deploytask = nil
	inst:RemoveTag("NOCLICK")
	if fuel and fuel > 0 then
		inst.components.fueled:SetPercent(math.min(1, fuel + inst.components.fueled:GetPercent()))
	end
end

local function onhit(inst, worker)
	inst.AnimState:PlayAnimation("hit")
	inst.AnimState:PushAnimation("idle", false)
	if inst.deploytask then
		inst.deploytask:Cancel()
		onpostdeploy(inst, inst.deploytask.fuel)
	end
end

local function onextinguish(inst)
	inst.components.fueled:InitializeFuelLevel(0)
end

local function ontakefuel(inst)
	inst.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
end

local function updatefuelrate(inst)
	inst.components.fueled.rate = TheWorld.state.israining and inst.components.rainimmunity == nil and 1 + TUNING.SKILLS.WALTER.PORTABLE_FIREPIT_RAIN_RATE * TheWorld.state.precipitationrate or 1
end

local function onupdatefueled(inst)
	updatefuelrate(inst)
	inst.components.burnable:SetFXLevel(inst.components.fueled:GetCurrentSection(), inst.components.fueled:GetSectionPercent())
end

local function onfuelchange(newsection, oldsection, inst, doer)
	if newsection <= 0 then
		inst.components.burnable:Extinguish()
		if inst.queued_charcoal then
			inst.components.lootdropper:SpawnLootPrefab("charcoal")
			inst.queued_charcoal = nil
		end
	else
		if not inst.components.burnable:IsBurning() then
			updatefuelrate(inst)
			inst.components.burnable:Ignite(nil, nil, doer)
		end
		inst.components.burnable:SetFXLevel(newsection, inst.components.fueled:GetSectionPercent())

		if newsection == inst.components.fueled.sections then
			inst.queued_charcoal = true
		end
	end
end

--V2C: 3 stages, but reuse strings written for the 4 stage firepit
local SECTION_STATUS =
{
	[0] = "OUT",
	[1] = "EMBERS",
	[2] = "NORMAL", --skipping LOW, too similar to EMBERS
	--3 is GENERIC
}
local function getstatus(inst, viewer)
	local section = inst.components.fueled:GetCurrentSection()
	if section >= 3 and viewer.components.storyteller and not TheWorld.state.isnight then
		--V2C: for walter, GENERIC is storyteller hint, but we don't want that if it's not night
		--     HIGH is also not suitable, as it hints at danger with stage 4 fires
		return "NORMAL"
	end
	return SECTION_STATUS[section]
end

local function displaynamefn(inst)
	return STRINGS.NAMES.PORTABLEFIREPIT_ITEM
end

local function OnHaunt(inst, haunter)
	if math.random() <= TUNING.HAUNT_CHANCE_RARE and not inst.components.fueled:IsEmpty() then
		inst.components.fueled:DoDelta(TUNING.MED_FUEL)
		inst.components.hauntable.hauntvalue = TUNING.HAUNT_SMALL
		return true
	end
	return false
end

local function OnInit(inst)
	inst.components.burnable:FixFX()
end

local function OnSave(inst, data)
	data.queued_charcoal = inst.queued_charcoal or nil
end

local function OnLoad(inst, data)
	inst.queued_charcoal = data and data.queued_charcoal
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.ONEPOINTFIVE] / 2) --item deployspacing/2
	inst:SetPhysicsRadiusOverride(0.25)
	MakeObstaclePhysics(inst, inst.physicsradiusoverride)

	inst.MiniMapEntity:SetIcon("portablefirepit.png")
	inst.MiniMapEntity:SetPriority(1)

	inst.AnimState:SetBank("portable_firepit")
	inst.AnimState:SetBuild("portable_firepit")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:Hide("mouseover")

	inst:AddTag("campfire")
	inst:AddTag("structure")
	inst:AddTag("wildfireprotected")
	inst:AddTag("portable_campfire")

	--cooker (from cooker component) added to pristine state for optimization
	inst:AddTag("cooker")

	--storytellingprop (from storytellingprop component) added to pristine state for optimization
	inst:AddTag("storytellingprop")

	--Don't use SetPrefabNameOverride because we want to have a different inspectable override
	inst.displaynamefn = displaynamefn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("portablestructure")
	inst.components.portablestructure:SetOnDismantleFn(ChangeToItem)

	inst:AddComponent("inspectable")
	inst.components.inspectable:SetNameOverride("firepit")
	inst.components.inspectable.getstatus = getstatus

	inst:AddComponent("burnable")
	--inst.components.burnable:SetFXLevel(2)
	inst.components.burnable:AddBurnFX("portable_campfirefire", Vector3(0, 0, 0), "firefx", true)
	inst:ListenForEvent("onextinguish", onextinguish)

	inst:AddComponent("lootdropper")
	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(2)
	inst.components.workable:SetOnFinishCallback(ChangeToItem)
	inst.components.workable:SetOnWorkCallback(onhit)

	inst:AddComponent("fueled")
	inst.components.fueled.maxfuel = TUNING.SKILLS.WALTER.PORTABLE_FIREPIT_FUEL_MAX
	inst.components.fueled.accepting = true
	inst.components.fueled:SetSections(3)
	inst.components.fueled.bonusmult = TUNING.SKILLS.WALTER.PORTABLE_FIREPIT_BONUS_MULT
	inst.components.fueled:SetTakeFuelFn(ontakefuel)
	inst.components.fueled:SetUpdateFn(onupdatefueled)
	inst.components.fueled:SetSectionCallback(onfuelchange)

	inst:AddComponent("cooker")
	inst:AddComponent("storytellingprop")

	inst:AddComponent("hauntable")
	inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_HUGE
	inst.components.hauntable:SetOnHauntFn(OnHaunt)

	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	inst:DoTaskInTime(0, OnInit)

	return inst
end

--------------------------------------------------------------------------

local function ondeploy(inst, pt, deployer)
	local firepit = SpawnPrefab("portablefirepit")
	if firepit then
		firepit.Physics:SetCollides(false)
		firepit.Physics:Teleport(pt.x, 0, pt.z)
		firepit.Physics:SetCollides(true)
		firepit.AnimState:PlayAnimation("place")
		firepit.AnimState:PushAnimation("idle", false)
		firepit.SoundEmitter:PlaySound("meta5/walter/portable_fireplace_place")
		firepit:AddTag("NOCLICK")
		firepit.deploytask = firepit:DoTaskInTime(13 * FRAMES, onpostdeploy, inst.fuel)
		firepit.deploytask.fuel = inst.fuel
		inst:Remove()
		PreventCharacterCollisionsWithPlacedObjects(firepit)
	end
end

local function item_OnSave(inst, data)
	data.fuel = (inst.fuel or 0) > 0 and inst.fuel or nil
end

local function item_OnLoad(inst, data)
	inst.fuel = data and data.fuel or nil
end

local FLOATABLE_SCALE = { 1.3, 0.9, 1.3 }

local function itemfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("portable_firepit")
	inst.AnimState:SetBuild("portable_firepit")
	inst.AnimState:PlayAnimation("kit")

	inst:AddTag("portableitem")

	MakeInventoryFloatable(inst, "small", .15, FLOATABLE_SCALE)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")

	inst:AddComponent("deployable")
	inst.components.deployable.restrictedtag = "portable_campfire_user"
	inst.components.deployable.ondeploy = ondeploy
	--inst.components.deployable:SetDeployMode(DEPLOYMODE.ANYWHERE)
	inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.ONEPOINTFIVE)

	inst:AddComponent("hauntable")
	inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

	MakeSmallBurnable(inst, 30)
	MakeSmallPropagator(inst)

	inst.fuel = TUNING.SKILLS.WALTER.PORTABLE_FIREPIT_FUEL_START

	inst.OnSave = item_OnSave
	inst.OnLoad = item_OnLoad

	return inst
end

return Prefab("portablefirepit", fn, assets, prefabs),
	MakePlacer("portablefirepit_item_placer", "portable_firepit", "portable_firepit", "placer"),
	Prefab("portablefirepit_item", itemfn, assets, prefabs_item)
