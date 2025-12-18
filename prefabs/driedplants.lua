--------------------------------------------------------------------------------------------------------

local driedplants_defs = require("prefabs/driedplants_defs")
local DRIED_DEFS = driedplants_defs.plants
driedplants_defs = nil

--------------------------------------------------------------------------------------------------------

local function MakeDriedPetal(data)
    local prefabname = data.name.."_dried"

    local bank = data.bank or data.name
    local build = data.build or data.name

    local assets =
    {
        Asset("SCRIPT", "scripts/prefabs/driedplants_defs.lua"),
        Asset("ANIM", "anim/"..build..".zip"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("dried")

        inst.pickupsound = "vegetation_grassy"

        inst:AddTag("cattoy")

        MakeInventoryFloatable(inst)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst:AddComponent("tradable")
        --inst:AddComponent("snowmandecor")

        inst:AddComponent("edible")
        inst.components.edible.healthvalue = data.healthvalue or TUNING.HEALING_TINY
        inst.components.edible.hungervalue = 0
        inst.components.edible.sanityvalue = data.sanityvalue or 0
        inst.components.edible.foodtype = FOODTYPE.VEGGIE
        if data.oneaten then
            inst.components.edible:SetOnEatenFn(data.oneaten)
        end

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

        MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
        MakeSmallPropagator(inst)
        inst.components.propagator.flashpoint = 2.5 + math.random() * 2.5

        MakeHauntableLaunchAndPerish(inst)

        return inst
    end

    return Prefab(prefabname, fn, assets)
end

local dried_prefabs = {}

for _, data in ipairs(DRIED_DEFS) do
    if not data.data_only then --allow mods to skip our prefab constructor.
        table.insert(dried_prefabs, MakeDriedPetal(data))
    end
end

return unpack(dried_prefabs)