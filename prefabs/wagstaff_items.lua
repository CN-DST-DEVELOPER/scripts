local assets =
{
    Asset("ANIM", "anim/wagstaff_personal_items.zip"),
}

local function MakeItem(info)

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

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(info.name, fn, assets)
end

return MakeItem({name = "wagstaff_item_1", anim = "glove1"}),
    MakeItem({name = "wagstaff_item_2", anim = "clipboard"})