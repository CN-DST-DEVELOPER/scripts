local assets =
{
    Asset("ANIM", "anim/scrapbook_page.zip"),
}

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
        if diduse then
            -- Taught things remove this.
            if inst.components.stackable then
                inst.components.stackable:Get(1):Remove()
            else
                inst:Remove()
            end            
        else
            -- Their book is full.
            if doer.components.talker then
                doer.components.talker:Say(GetString(doer, "ANNOUNCE_SCRAPBOOK_FULL"))
            end            
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

local function GetActivateVerb(inst, doer)
    return "SCRAPBOOK"
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("scrapbook_page")
    inst.AnimState:SetBuild("scrapbook_page")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("cattoy")
    inst:AddTag("scrapbook_page")
    inst:AddTag("scrapbook_data")

    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst.scrapbook_specialinfo = "SCRAPBOOKPAGE"

    inst.entity:SetPristine()

    inst.GetActivateVerb = GetActivateVerb

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnScrapbookDataTaught = OnScrapbookDataTaught

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inspectable")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

    inst:AddComponent("tradable")

    inst:AddComponent("scrapbookable")
    inst.components.scrapbookable.onteach = OnTeach

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunchAndIgnite(inst)

    inst:AddComponent("inventoryitem")

    return inst
end

return Prefab("scrapbook_page", fn, assets)
