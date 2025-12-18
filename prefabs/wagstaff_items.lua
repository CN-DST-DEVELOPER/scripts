local assets =
{
    Asset("ANIM", "anim/wagstaff_personal_items.zip"),
}

local function CloneAsFx(inst)
	local fx = SpawnPrefab("hermithouse_ornament_fx")
	fx.AnimState:SetBank("wagstaff_personal_items")
	fx.AnimState:SetBuild("wagstaff_personal_items")
	return fx
end

local function MakeItem(info)
	local prefabs = info.isornament and
	{
		"hermithouse_ornament_fx",
	} or nil

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("wagstaff_personal_items")
        inst.AnimState:SetBuild("wagstaff_personal_items")
        inst.AnimState:PlayAnimation(info.anim)

        MakeInventoryFloatable(inst)

		if info.isornament then
			inst:AddTag("hermithouse_ornament")
		end
		inst:AddTag("wagstaff_item")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        MakeHauntableLaunch(inst)

		if info.isornament then
			inst.CloneAsFx = CloneAsFx
		end

        return inst
    end

    return Prefab(info.name, fn, assets, prefabs)
end

return MakeItem({ name = "wagstaff_item_1", anim = "glove1", isornament = true }),
	MakeItem({ name = "wagstaff_item_2", anim = "clipboard" })
