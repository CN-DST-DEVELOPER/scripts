local assets = {
    Asset("ANIM", "anim/records.zip"),
    Asset("ANIM", "anim/record_balatro.zip"),
    Asset("INV_IMAGE", "record"),
    Asset("INV_IMAGE", "record_balatro"),
}

local RECORDS = {
    default = {song = "dontstarve/music/gramaphone_ragtime", build = nil, displayname = nil, imageicon = nil,},
    balatro = {song = "dontstarve/music/gramaphone_balatro", build = "record_balatro", displayname = "record_balatro", imageicon = "record_balatro",},
}

local function SetRecord(inst, name)
    if name == nil then
        name = "default"
    end

    local recorddata = RECORDS[name]
    if recorddata == nil then
        print("Error: Bad record name to SetRecord.", inst, name)
        return
    end

    inst.recordname = name
    inst.recorddata = recorddata

    inst.songToPlay = recorddata.song -- Keep for mods.
    if not inst.linked_skinname then
        if inst.recorddata.build then
            inst.AnimState:SetBuild(inst.recorddata.build)
        end
        inst.record_displayname:set(inst.recorddata.displayname or "")
        if inst.components.inspectable then
            inst.components.inspectable:SetNameOverride(inst.recorddata.displayname)
        end
        if inst.components.inventoryitem then
            inst.components.inventoryitem:ChangeImageName(inst.recorddata.imageicon)
        end
    end
end

-- Save/Load
local function OnSave(inst, data)
    if inst.recordname ~= "default" then
        data.name = inst.recordname
    end
end

local function OnLoad(inst, data)
    if data then
        if data.name then
            inst:SetRecord(data.name)
        end
    end
end

local function DisplayNameFn(inst)
    local name = inst.record_displayname:value()
    if name ~= "" then
        name = STRINGS.NAMES[string.upper(name)]
        if name then
            return name
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("records")
    inst.AnimState:SetBuild("records")
    inst.AnimState:PlayAnimation("idle")

    --inst.pickupsound = "vegetation_grassy"

    inst:AddTag("cattoy")
    inst:AddTag("phonograph_record")

    MakeInventoryFloatable(inst, "med", 0.02, 0.7)

    inst.record_displayname = net_string(inst.GUID, "record.record_displayname")
    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_tex = "record"

    inst:AddComponent("inventoryitem")

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    MakeHauntableLaunchAndIgnite(inst)

    inst.SetRecord = SetRecord
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst:SetRecord()

    return inst
end

return Prefab("record", fn, assets)
