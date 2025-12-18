local prefabs =
{
	"hermithouse_ornament_fx",
}

local function MakeLaundry(name)
	local assets =
	{
		Asset("ANIM", "anim/"..name..".zip"),
	}

	local function CloneAsFx(inst)
		local fx = SpawnPrefab("hermithouse_ornament_fx")
		fx.AnimState:SetBank(name)
		fx.AnimState:SetBuild(name)
		return fx
	end

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()

		MakeInventoryPhysics(inst, 0.1)

		inst:AddTag("hermithouse_ornament")
		inst:AddTag("hermithouse_laundry")

		inst.AnimState:SetBank(name)
		inst.AnimState:SetBuild(name)
		inst.AnimState:PlayAnimation("grounded")

		MakeInventoryFloatable(inst, "small", 0.1, { 1.1, 1, 0.9 })

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("inspectable")
		inst.components.inspectable:SetNameOverride("hermithouse_laundry")

		inst:AddComponent("inventoryitem")

		MakeHauntableLaunch(inst)

		inst.CloneAsFx = CloneAsFx

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

return MakeLaundry("hermithouse_laundry_socks"),
	MakeLaundry("hermithouse_laundry_shorts")
