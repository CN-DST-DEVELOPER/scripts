local DEFAULT_ASSETS =
{
    Asset("ANIM", "anim/blueprint_tackle.zip"),
}

-- Adding scrapbook_notes:
--   1. Add entry in NOTES table below. Note that the prefab will have a "_note" suffix.
--   2. Add scrapbook entry for it and an entry in the SCRAPBOOK.SPECIALINFO string table.

local NOTES =
{
    {
        name = "wagstaff_mutations",
        tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
    {
        name = "wagstaff_materials",
        --tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
    {
        name = "wagstaff_energy",
        --tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
    {
        name = "wagstaff_containment",
        --tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
    {
        name = "wagstaff_thermal",
        --tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
    {
        name = "wagstaff_electricity",
        --tags = { "mutationsnote" },
        build = "wagstaff_notes",
    },
}

-- For searching purposes:
--      wagstaff_mutations_note
--      wagstaff_materials_note
--      wagstaff_energy_note
--      wagstaff_containment_note
--      wagstaff_thermal_note
--      wagstaff_electricity_note

local function CancelReservation(inst)
    inst.reserved_userid = nil
    inst.cancelreservationtask = nil
end

local function OnScrapbookDataTaught(inst, doer, diduse)
    if doer.userid and inst.reserved_userid == doer.userid then
        inst.reserved_userid = nil
        if inst.cancelreservationtask ~= nil then
            inst.cancelreservationtask:Cancel()
            inst.cancelreservationtask = nil
        end
    end
end

local function OnTeach(inst, doer)
    if inst.reserved_userid then -- One player at a time.
        if doer.components.talker then
            doer.components.talker:Say(GetActionFailString(doer, "STORE", "INUSE"))
        end
        return true
    end

    -- We are mastersim here.
    if doer.userid then
        inst.reserved_userid = doer.userid
        if (TheNet:IsDedicated() or doer ~= ThePlayer) then
            -- The doer is a client let them try to learn things on their end.
            inst.cancelreservationtask = inst:DoTaskInTime(10, CancelReservation) -- This is the time period back and forth before the try is cancelled.
            SendRPCToClient(CLIENT_RPC.TryToTeachScrapbookData, doer.userid, inst)
        else
            -- The doer is also server.
            local diduse = TheScrapbookPartitions:TryToTeachScrapbookData(true, inst)
            inst:OnScrapbookDataTaught(doer, diduse)
        end
    end

    return true
end

local function MakeScrapbookNote(data)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(data.build  or "blueprint_tackle")
        inst.AnimState:SetBuild(data.build or "blueprint_tackle")
        inst.AnimState:PlayAnimation("idle")

        MakeInventoryFloatable(inst, "med", nil, 0.75)

        inst:AddTag("scrapbook_note")

        if data.tags ~= nil then
            for _, tag in ipairs(data.tags) do
                inst:AddTag(tag)
            end
        end

        inst:SetPrefabNameOverride("wagstaff_mutations_note")

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst.OnScrapbookDataTaught = OnScrapbookDataTaught

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:ChangeImageName("wagstaff_mutations_note")

        inst:AddComponent("erasablepaper")

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

        inst:AddComponent("scrapbookable")
        inst.components.scrapbookable:SetOnTeachFn(OnTeach)

        MakeHauntableLaunch(inst)

        return inst
    end

    local assets = data.build ~= nil and { Asset("ANIM", "anim/"..data.build..".zip") } or DEFAULT_ASSETS

    return Prefab(data.name.."_note", fn, assets)
end


local ret = {}

for _, data in ipairs(NOTES) do
    table.insert(ret, MakeScrapbookNote(data))
end

return unpack(ret)
