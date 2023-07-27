local module_definitions = require("wx78_moduledefs").module_definitions

local assets =
{
    Asset("ANIM", "anim/wx_chips.zip"),

    Asset("SCRIPT", "scripts/wx78_moduledefs.lua"),
}

local function on_module_removed(inst)
    if inst.components.finiteuses ~= nil then
        inst.components.finiteuses:Use()
    end
end

local function MakeModule(data)
    local prefabs = {}
    if data.extra_prefabs ~= nil then
        for _, extra_prefab in ipairs(data.extra_prefabs) do
            table.insert(prefabs, extra_prefab)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("chips")
        inst.AnimState:SetBuild("wx_chips")
        inst.AnimState:PlayAnimation(data.name)
        inst.scrapbook_anim = data.name

        if data.slots > 4 then
            MakeInventoryFloatable(inst, "med", 0.1, 0.75)
        else
            MakeInventoryFloatable(inst, nil, 0.1, (data.slots == 1 and 0.75) or 1.0)
        end

        --------------------------------------------------------------------------
        -- For client-side access to information that should not be mutated
        inst._netid = data.module_netid
        inst._slots = data.slots

        if data.name == "maxhealth" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXHEALTH"
        end
        if data.name == "maxsanity1" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXSANITY1"
        end
        if data.name == "maxsanity" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXSANITY"
        end
        if data.name == "movespeed" then
            inst.scrapbook_specialinfo = "WX78MODULE_MOVESPEED"
        end        
        if data.name == "movespeed2" then
            inst.scrapbook_specialinfo = "WX78MODULE_MOVESPEED2"
        end
        if data.name == "heat" then
            inst.scrapbook_specialinfo = "WX78MODULE_HEAT"
        end
        if data.name == "nightvision" then
            inst.scrapbook_specialinfo = "WX78MODULE_NIGHVISION"
        end
        if data.name == "cold" then
            inst.scrapbook_specialinfo = "WX78MODULE_COLD"
        end
        if data.name == "taser" then
            inst.scrapbook_specialinfo = "WX78MODULE_TASER"
        end
        if data.name == "light" then
            inst.scrapbook_specialinfo = "WX78MODULE_LIGHT"
        end
        if data.name == "maxhunger" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXHUNGER"
        end
        if data.name == "maxhunger1" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXHUNGER1"
        end
        if data.name == "music" then
            inst.scrapbook_specialinfo = "WX78MODULE_MUSIC"
        end
        if data.name == "bee" then
            inst.scrapbook_specialinfo = "WX78MODULE_BEE"
        end
        if data.name == "maxhealth2" then
            inst.scrapbook_specialinfo = "WX78MODULE_MAXHEALTH2"
        end


        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        --------------------------------------------------------------------------
        inst:AddComponent("inspectable")

        --------------------------------------------------------------------------
        inst:AddComponent("inventoryitem")

        --------------------------------------------------------------------------
        inst:AddComponent("upgrademodule")
        inst.components.upgrademodule:SetRequiredSlots(data.slots)
        inst.components.upgrademodule.onactivatedfn = data.activatefn
        inst.components.upgrademodule.ondeactivatedfn = data.deactivatefn
        inst.components.upgrademodule.onremovedfromownerfn = on_module_removed

        --------------------------------------------------------------------------
        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(TUNING.WX78_MODULE_USES)
        inst.components.finiteuses:SetUses(TUNING.WX78_MODULE_USES)
        inst.components.finiteuses:SetOnFinished(inst.Remove)

        return inst
    end

    return Prefab("wx78module_"..data.name, fn, assets, prefabs)
end

local module_prefabs = {}
for _, def in ipairs(module_definitions) do
    table.insert(module_prefabs, MakeModule(def))
end

return unpack(module_prefabs)
