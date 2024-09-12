local SCRAPBOOK_DEPENDENCIES = { "carpentry_station" }

local BANK_NAME = "carpentry_blade_moonglass"

local function MakeBlade(material, tech_level)
    assert(TUNING.PROTOTYPER_TREES[tech_level] ~= nil, string.format("TUNING.PROTOTYPER_TREES.%s is nil", tech_level))

    local name = "carpentry_blade_"..material
    local build_override = "carpentry_station_"..material.."_build"

    local assets = {
        Asset("ANIM", "anim/"..BANK_NAME..".zip"),
        Asset("ANIM", "anim/"..build_override..".zip"),
    }

    if name ~= BANK_NAME then
        table.insert(assets, Asset("ANIM", "anim/"..name..".zip"))
    end

    local function BladeFn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(BANK_NAME)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("carpentry_blade")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.scrapbook_adddeps = SCRAPBOOK_DEPENDENCIES

        inst.blade_tech_tree = TUNING.PROTOTYPER_TREES[tech_level]
        inst.build_override = build_override

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:SetSinks(true)

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name, BladeFn, assets)
end

return MakeBlade("moonglass", "CARPENTRY_STATION_STONE") -- For searching: "carpentry_blade_moonglass"
