
local ruinsturf_blueprints = {
	"turf_ruinsbrick",
	"turf_ruinstiles",
	"turf_ruinstrim",
}

local ruinsglowturf_blueprints = {
	"turf_ruinsbrick_glow",
	"turf_ruinstiles_glow",
	"turf_ruinstrim_glow",
}

-------------------------------------------------------------------------------
local function builder_onbuilt(inst, builder)
	local x, y, z = builder.Transform:GetWorldPosition()

	for _, v in ipairs(inst.blueprints) do
		local blueprint = SpawnPrefab(v.."_blueprint")
		blueprint.Transform:SetPosition(x, y, z)
		builder.components.inventory:GiveItem(blueprint)
	end

    inst:Remove()
end

local function MakeBlueprintSet(name, blueprints)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()

		inst:AddTag("CLASSIFIED")

		--[[Non-networked entity]]
		inst.persists = false

		--Auto-remove if not spawned by builder
		inst:DoTaskInTime(0, inst.Remove)

		if not TheWorld.ismastersim then
			return inst
		end

		inst.blueprints = blueprints
		inst.OnBuiltFn = builder_onbuilt

		return inst
	end
	return Prefab(name, fn, nil, blueprints)
end

return MakeBlueprintSet("blueprint_craftingset_ruins_builder", ruinsturf_blueprints),
		MakeBlueprintSet("blueprint_craftingset_ruinsglow_builder", ruinsglowturf_blueprints)
