local assets =
{
	Asset("ANIM", "anim/support_pillar.zip"),
	Asset("MINIMAP_IMAGE", "support_pillar"),
}

local assets_scaffold =
{
	Asset("ANIM", "anim/support_pillar.zip"),
	Asset("MINIMAP_IMAGE", "support_pillar"),
	Asset("ANIM", "anim/firefighter_placement.zip"),
}

local prefabs =
{
	"collapse_big",
	"cutstone",
	"construction_repair_container",
}

local prefabs_scaffold =
{
	"support_pillar",
	"collapse_big",
	"construction_container",
}

--loot for "support_pillar" is basically the recipe for "support_pillar_scaffold" minus the boards
local LOOT = { "cutstone" }

--------------------------------------------------------------------------

local PF_DIMS = 2 --equal to 2x2 grid of walls

local function UnregisterPathFinding(inst)
	local x = inst._pfpos.x - (PF_DIMS - 1) / 2
	local z = inst._pfpos.z - (PF_DIMS - 1) / 2
	local pathfinder = TheWorld.Pathfinder
	for i = 0, PF_DIMS - 1 do
		for j = 0, PF_DIMS - 1 do
			pathfinder:RemoveWall(x + i, 0, z + j)
		end
	end
end

local function RegisterPathFinding(inst)
	inst._pfpos = inst:GetPosition()
	local x = inst._pfpos.x - (PF_DIMS - 1) / 2
	local z = inst._pfpos.z - (PF_DIMS - 1) / 2
	local pathfinder = TheWorld.Pathfinder
	for i = 0, PF_DIMS - 1 do
		for j = 0, PF_DIMS - 1 do
			pathfinder:AddWall(x + i, 0, z + j)
		end
	end
	inst.OnRemoveEntity = UnregisterPathFinding
end

--------------------------------------------------------------------------

local function OnDebrisFXDirty(inst)
	if inst._debrisfx:value() == 0 then
		return
	end

	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())

	fx.AnimState:SetBank("support_pillar")
	fx.AnimState:SetBuild("support_pillar")
	fx.AnimState:SetFinalOffset(1)

	fx.persists = false

	if inst._debrisfx:value() == 3 then
		fx.AnimState:PlayAnimation("collapse_top")
		ErodeAway(fx, 1)
	else
		fx.entity:AddSoundEmitter()
		fx.SoundEmitter:PlaySound("meta2/pillar/pillar_quake")
		fx.AnimState:PlayAnimation(inst._debrisfx:value() == 2 and "quake_debris" or "hit_debris")
		fx:ListenForEvent("animover", fx.Remove)
	end
end

local DEBRIS_FX =
{
	HIT = 1,
	QUAKE = 2,
	COLLAPSE = 3,
}

local function PushDebrisFX(inst, fxlevel)
	--force dirty
	inst._debrisfx:set_local(fxlevel)
	inst._debrisfx:set(fxlevel)

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		OnDebrisFXDirty(inst)
	end
end

local function OnLevelDirty(inst)
	if inst._level:value() == 4 then
		inst:SetPrefabNameOverride("support_pillar_broken")
	elseif inst._level:value() == 0 then
		inst:SetPrefabNameOverride("support_pillar_complete")
	else
		inst:SetPrefabNameOverride(nil)
	end
end

local Decrement --forward declare

local function DoQuake(inst)
	inst._quaketask = nil
	inst.components.constructionsite:Disable()
	local oldsuffix = inst.suffix
	Decrement(inst, nil)
	if inst.AnimState:IsCurrentAnimation("collapse") then
		return
	elseif inst.suffix ~= "_4" then
		inst.AnimState:PlayAnimation("idle_quake"..inst.suffix)
		PushDebrisFX(inst, DEBRIS_FX.QUAKE)
	elseif oldsuffix ~= "_4" then
		inst.AnimState:PlayAnimation("idle_quake"..oldsuffix)
		PushDebrisFX(inst, DEBRIS_FX.QUAKE)
		inst.components.workable:SetWorkable(false)
	end
end

local function SetEnableWatchQuake(inst, enable, keeptask)
	if enable then
		if inst._onquake == nil then
			inst._onquake = function(_, data)
				if inst._quaketask ~= nil then
					inst._quaketask:Cancel()
				end
				--delay till the first camera shake period
				inst._quaketask = inst:DoTaskInTime(data ~= nil and data.debrisperiod or 0, DoQuake)
			end
			inst:ListenForEvent("startquake", inst._onquake, TheWorld.net)
		end
	else
		if inst._onquake ~= nil then
			inst:RemoveEventCallback("startquake", inst._onquake, TheWorld.net)
			inst._onquake = nil
		end
		if inst._quaketask ~= nil and not keeptask then
			inst._quaketask:Cancel()
			inst._quaketask = nil
		end
	end
end

local function UpdateLevel(inst)
	local num = inst.components.constructionsite:GetMaterialCount("rocks")
	inst._level:set(
		(num >= 40 and 0) or
		(num >= 20 and 1) or
		(num >= 10 and 2) or
		(num > 0 and 3) or
		4
	)
	inst.suffix = inst._level:value() > 0 and "_"..tostring(inst._level:value()) or ""
	OnLevelDirty(inst)

	if inst.suffix == "_4" then
		inst:RemoveTag("quake_blocker")
	else
		inst:AddTag("quake_blocker")
		if inst.suffix == "" then
			inst.components.constructionsite:Disable()
		end
	end
	if not inst:IsAsleep() then
		SetEnableWatchQuake(inst, inst.suffix ~= "_4")
	end
end

local function OnEntitySleep(inst)
	SetEnableWatchQuake(inst, false, true)
end

local function OnEntityWake(inst)
	if inst.suffix ~= "_4" then
		SetEnableWatchQuake(inst, true)
	end
end

local function IsQuakeAnim(inst)
	return inst.AnimState:IsCurrentAnimation("idle_quake")
		or inst.AnimState:IsCurrentAnimation("idle_quake_1")
		or inst.AnimState:IsCurrentAnimation("idle_quake_2")
		or inst.AnimState:IsCurrentAnimation("idle_quake_3")
end

local function IsHitAnim(inst)
	return inst.AnimState:IsCurrentAnimation("idle_hit")
		or inst.AnimState:IsCurrentAnimation("idle_hit_1")
		or inst.AnimState:IsCurrentAnimation("idle_hit_2")
		or inst.AnimState:IsCurrentAnimation("idle_hit_3")
end

--forward declared
Decrement = function(inst, worker)
	if inst.reinforced > 0 then
		inst.reinforced = inst.reinforced - 1
		return true
	elseif inst.components.constructionsite:RemoveMaterial("rocks", 1) > 0 then
		local oldsuffix = inst.suffix
		UpdateLevel(inst)
		if oldsuffix ~= inst.suffix or math.random() < 0.3 then
			if worker ~= nil and worker.components.locomotor ~= nil then
				inst.components.lootdropper:SetFlingTarget(worker:GetPosition(), 45)
			else
				inst.components.lootdropper:SetFlingTarget(nil, nil)
			end
			local loot = inst.components.lootdropper:SpawnLootPrefab("rocks")
			local x, y, z = loot.Transform:GetWorldPosition()
			loot.Physics:Teleport(x, 2 + math.random(), z)
		end
		return true
	end
end

local function OnAnimOver(inst)
	local collapsing = inst.AnimState:IsCurrentAnimation("collapse")
	if not (collapsing or IsHitAnim(inst) or IsQuakeAnim(inst) or inst.AnimState:IsCurrentAnimation("build")) then
		return
	elseif inst.suffix == "_4" and not collapsing then
		inst.AnimState:PlayAnimation("collapse")
		inst.SoundEmitter:PlaySound("meta2/pillar/pillar_collapse")
	else
		if collapsing and inst.suffix == "_4" then
			PushDebrisFX(inst, DEBRIS_FX.COLLAPSE)
		end
		inst.AnimState:PlayAnimation("idle"..inst.suffix)
		if inst.suffix ~= "" then
			inst.components.constructionsite:Enable()
		end
		inst.components.workable:SetWorkable(true)
	end
end

local function onhit(inst, worker, workleft, numworks)
	inst.components.constructionsite:ForceStopConstruction()
	local oldsuffix = inst.suffix
	if Decrement(inst, worker) then
		inst.components.workable:SetWorkLeft(5)
	end
	if IsQuakeAnim(inst) then
		if inst.AnimState:GetCurrentAnimationFrame() < 15 then
			return
		end
	elseif inst.AnimState:IsCurrentAnimation("collapse") then
		return
	elseif inst.suffix ~= "_4" then
		inst.AnimState:PlayAnimation("idle_hit"..inst.suffix)
		if inst.suffix ~= oldsuffix then
			PushDebrisFX(inst, DEBRIS_FX.HIT)
		end
	elseif oldsuffix ~= "_4" then
		inst.AnimState:PlayAnimation("idle_hit"..oldsuffix)
		if inst.suffix ~= oldsuffix then
			PushDebrisFX(inst, DEBRIS_FX.HIT)
		end
		inst.components.workable:SetWorkable(false)
		inst.components.constructionsite:Disable()
	end
end

local function onhammered(inst)
	local pt = inst:GetPosition()
	inst.components.lootdropper.spawn_loot_inside_prefab = true
	inst.components.lootdropper.y_speed = nil
	inst.components.lootdropper:SetFlingTarget(nil, nil)
	inst.components.lootdropper:DropLoot(pt)

	inst.components.constructionsite:DropAllMaterials(pt)

	local fx = SpawnPrefab("collapse_big")
	fx.Transform:SetPosition(pt:Get())
	fx:SetMaterial("rock")
	inst:Remove()
end

local function OnConstructed(inst)
	inst.components.workable:SetWorkLeft(5)
	local oldsuffix = inst.suffix
	UpdateLevel(inst)
	if oldsuffix ~= inst.suffix then
		inst.AnimState:PlayAnimation("idle_repair"..inst.suffix)
		inst.AnimState:PushAnimation("idle"..inst.suffix, false)
		if inst.suffix == "" then
			inst.reinforced = 10
		end
	end
end

local function MakeReinforced(inst, anim)
	inst.components.constructionsite:AddMaterial("rocks", 40)
	inst.components.constructionsite:Disable()
	inst.reinforced = 10
	UpdateLevel(inst)
	if anim == nil then
		inst.AnimState:PlayAnimation("idle"..inst.suffix)
	elseif anim == "build" then
		inst.components.workable:SetWorkable(false)
		inst.AnimState:PlayAnimation("build")
		inst.SoundEmitter:PlaySound("meta2/pillar/pillar_build")
	else
		inst.AnimState:PlayAnimation(anim)
		inst.AnimState:PushAnimation("idle"..inst.suffix, false)
	end
end

local function OnSave(inst, data)
	data.reinforced = inst.reinforced ~= 0 and inst.reinforced or nil
end

local function OnLoad(inst, data, ents)
	inst.reinforced = data ~= nil and data.reinforced or 0
	UpdateLevel(inst)
	inst.AnimState:PlayAnimation("idle"..inst.suffix)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("support_pillar.png")

	MakeObstaclePhysics(inst, 2)

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("support_pillar")
	inst.AnimState:SetBuild("support_pillar")
	inst.AnimState:PlayAnimation("idle_4")

	inst:AddTag("structure")
	inst:AddTag("antlion_sinkhole_blocker")

	--constructionsite (from constructionsite component) added to pristine state for optimization
	inst:AddTag("constructionsite")

	--Repair action strings.
	inst:AddTag("repairconstructionsite")

	inst._level = net_tinybyte(inst.GUID, "support_pillar._level", "leveldirty")
	inst._level:set(4)

	inst._debrisfx = net_tinybyte(inst.GUID, "support_pillar._debrisfx", "debrisfxdirty")

	inst:DoTaskInTime(0, RegisterPathFinding)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("leveldirty", OnLevelDirty)
		inst:DoTaskInTime(0, inst.ListenForEvent, "debrisfxdirty", OnDebrisFXDirty)

		return inst
	end

	inst.suffix = "_4"
	inst.reinforced = 0

	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_repair_container")
	inst.components.constructionsite:SetOnConstructedFn(OnConstructed)

	inst:AddComponent("inspectable")
	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetLoot(LOOT)
	inst.components.lootdropper.y_speed = 4

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(5)
	inst.components.workable:SetOnWorkCallback(onhit)
	inst.components.workable:SetOnFinishCallback(onhammered)

	inst:ListenForEvent("animover", OnAnimOver)
	inst:ListenForEvent("onsink", onhammered)

	inst.MakeReinforced = MakeReinforced
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--------------------------------------------------------------------------

local function onbuilt_scaffold(inst)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("scaffold", false)
	inst.SoundEmitter:PlaySound("meta2/pillar/scaffold_place")
end

local function onconstructed_scaffold(inst, doer)
	if inst.components.constructionsite:IsComplete() then
		ReplacePrefab(inst, "support_pillar"):MakeReinforced("build")
	else
		inst.components.workable:SetWorkLeft(5)
	end
end

local function onhit_scaffold(inst, worker, workleft, numworks)
	inst.AnimState:PlayAnimation("scaffold_hit")
	inst.AnimState:PushAnimation("scaffold", false)
	inst.SoundEmitter:PlaySound("meta2/pillar/scaffold_hit")

	inst.components.constructionsite:ForceStopConstruction()
	if inst.components.constructionsite:RemoveMaterial("rocks", 1) > 0 then
		if workleft <= 0 then
			inst.components.workable:SetWorkLeft(1)
		end
		if math.random() < 0.3 then
			if worker ~= nil and worker.components.locomotor ~= nil then
				inst.components.lootdropper:SetFlingTarget(worker:GetPosition(), 45)
			else
				inst.components.lootdropper:SetFlingTarget(nil, nil)
			end
			local loot = inst.components.lootdropper:SpawnLootPrefab("rocks")
			local x, y, z = loot.Transform:GetWorldPosition()
			loot.Physics:Teleport(x, 2 + math.random(), z)
		end
	end
end

local function onhammered_scaffold(inst)
	local pt = inst:GetPosition()
	inst.components.lootdropper.spawn_loot_inside_prefab = true
	inst.components.lootdropper.y_speed = nil
	inst.components.lootdropper:SetFlingTarget(nil, nil)
	inst.components.lootdropper:DropLoot(pt)

	inst.components.constructionsite:DropAllMaterials(pt)

	local fx = SpawnPrefab("collapse_big")
	fx.Transform:SetPosition(pt:Get())
	fx:SetMaterial("rock")
	inst:Remove()
end

local function scaffoldfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("support_pillar.png")

	MakeObstaclePhysics(inst, 2)

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("support_pillar")
	inst.AnimState:SetBuild("support_pillar")
	inst.AnimState:PlayAnimation("scaffold")

	inst:AddTag("structure")
	inst:AddTag("antlion_sinkhole_blocker")

	--constructionsite (from constructionsite component) added to pristine state for optimization
	inst:AddTag("constructionsite")

	inst:DoTaskInTime(0, RegisterPathFinding)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_container")
	inst.components.constructionsite:SetOnConstructedFn(onconstructed_scaffold)

	inst:AddComponent("inspectable")
	inst:AddComponent("lootdropper")
	inst.components.lootdropper.y_speed = 4

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(5)
	inst.components.workable:SetOnWorkCallback(onhit_scaffold)
	inst.components.workable:SetOnFinishCallback(onhammered_scaffold)

	inst:ListenForEvent("onbuilt", onbuilt_scaffold)
	inst:ListenForEvent("onsink", onhammered_scaffold)

	return inst
end

local function placer_override_build_point(inst)
	--Use placer's snapped position instead of mouse position
	return inst:GetPosition()
end

local function placer_postinit_fn(inst)
	local inner = CreateEntity()

	--[[Non-networked entity]]
	inner.entity:SetCanSleep(false)
	inner.persists = false

	inner.entity:AddTransform()
	inner.entity:AddAnimState()

	inner:AddTag("CLASSIFIED")
	inner:AddTag("NOCLICK")
	inner:AddTag("placer")

	inner.AnimState:SetBank("firefighter_placement")
	inner.AnimState:SetBuild("firefighter_placement")
	inner.AnimState:PlayAnimation("idle")
	inner.AnimState:SetAddColour(0, .2, .5, 0)
	inner.AnimState:SetLightOverride(1)
	inner.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inner.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	inner.AnimState:SetSortOrder(3)

	local scale = 1888 / 150 / 2 --source_art_size / anim_scale / 2 (halved to get radius)
	scale = TUNING.QUAKE_BLOCKER_RANGE / scale --convert to rescaling for our desired range
	inner.AnimState:SetScale(scale, scale)

	inner.entity:SetParent(inst.entity)
	inst.components.placer:LinkEntity(inner)
	inst.components.placer.override_build_point_fn = placer_override_build_point
end

--------------------------------------------------------------------------

return Prefab("support_pillar_scaffold", scaffoldfn, assets_scaffold, prefabs_scaffold),
	MakePlacer("support_pillar_scaffold_placer", "support_pillar", "support_pillar", "idle", nil, true, nil, nil, nil, "eight", placer_postinit_fn),
	Prefab("support_pillar", fn, assets, prefabs)
