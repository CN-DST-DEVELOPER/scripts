require("prefabutil")

local prefabs =
{
    "collapse_small",
}

local function Chair_TrySpawnShadeling(inst)
	TheWorld.components.ruinsshadelingspawner:TrySpawnShadeling(inst)
end

local function Chair_ClearNoShadeling(inst)
	inst.noshadelingtask = nil
end

local function Chair_OnEntityWake(inst)
	if inst.chairtask == nil and inst.noshadelingtask == nil then
		inst.chairtask = inst:DoTaskInTime(0, Chair_TrySpawnShadeling)
	end
end

local function Chair_OnEntitySleep(inst)
	if inst.chairtask ~= nil then
		inst.chairtask:Cancel()
		inst.chairtask = nil
	end
end

local function OnPutOnFurniture(inst)--, furniture)
	inst.components.workable:SetWorkable(false)
end

local function OnTakeOffFurniture(inst)--, furniture)
	inst.components.workable:SetWorkable(true)
end

local function item(name, animated, sound, radius, deploy_smart_radius)
    local build = "ruins_"..name
    local assets =
    {
        Asset("ANIM", "anim/"..build..".zip"),
    }
	local isdecor = deploy_smart_radius == nil

    local function OnHammered(inst, worker)
        local fx = SpawnPrefab("collapse_small")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial(sound)
        inst.components.lootdropper:DropLoot()
        inst:Remove()
    end

	local OnBuilt = not isdecor and function(inst, data)
        if animated then
            inst.AnimState:PlayAnimation("hit")
            inst.AnimState:PushAnimation("idle", false)
        end
        inst.SoundEmitter:PlaySound(sound == "rock" and "dontstarve/common/fixed_stonefurniture" or "dontstarve/common/repair_stonefurniture")
		if inst.OnEntityWake == Chair_OnEntityWake then
			inst.noshadelingtask = inst:DoTaskInTime(0, Chair_ClearNoShadeling)
		end

        if inst.prefab == "ruinsrelic_chair" then
            local builder = (data and data.builder) or nil
            TheWorld:PushEvent("CHEVO_makechair", {target = inst, doer = builder})
        end
	end or nil

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

		if isdecor then
			inst.entity:AddFollower()

			MakeInventoryPhysics(inst)

			--furnituredecor (from furnituredecor component) added to pristine state for optimization
			inst:AddTag("furnituredecor")
		else
			inst:SetDeploySmartRadius(deploy_smart_radius) --recipe min_spacing/2

			if radius > 0 then
				MakeObstaclePhysics(inst, radius)
			else
				MakeInventoryPhysics(inst)
			end

			if name == "chair" then
				inst.AnimState:SetFinalOffset(-1)

				inst:AddTag("structure")
				inst:AddTag("limited_chair")
				inst:AddTag("uncomfortable_chair")
			end
		end

        inst.AnimState:SetBank(build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst.components.inspectable.nameoverride = "relic"

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(1)
        inst.components.workable:SetOnFinishCallback(OnHammered)

        inst:AddComponent("lootdropper")

		if isdecor then
			inst:AddComponent("inventoryitem")

			inst:AddComponent("furnituredecor")
			inst.components.furnituredecor.onputonfurniture = OnPutOnFurniture
			inst.components.furnituredecor.ontakeofffurniture = OnTakeOffFurniture
		else
			if name == "chair" then
				inst:AddComponent("sittable")

				if TheWorld.components.ruinsshadelingspawner then
					inst.OnEntityWake = Chair_OnEntityWake
					inst.OnEntitySleep = Chair_OnEntitySleep
				end
			end

			inst:ListenForEvent("onbuilt", OnBuilt)
		end

		MakeHauntableWork(inst)

        return inst
    end

    return Prefab("ruinsrelic_"..name, fn, assets, prefabs)
end

-- These are the fake/replica versions the players can craft, see smashables.lua for ruins version
return item("plate",	false,	"pot"),--	0,		0.25	),
	item("bowl",		false,	"pot"),--	0.25,	1		),
	item("chipbowl",	false,	"pot"),--	0,		0.25	),
	item("vase",		true,	"pot"),--	0.25,	1		),
	item("chair",		true,	"rock",	0.25,	1		),
	item("table",		true,	"rock",	0.5,	1.6		),
    MakePlacer("ruinsrelic_chair_placer", "ruins_chair", "ruins_chair", "idle"),
    MakePlacer("ruinsrelic_table_placer", "ruins_table", "ruins_table", "idle")
