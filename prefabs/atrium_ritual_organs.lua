local assets =
{
    Asset("ANIM", "anim/atrium_ritual_organs.zip"),
}

local function SetItem(inst)
    if inst.marking and inst.marking:IsValid() and inst.marking.RitualItemDetached then
        inst.marking:RitualItemDetached()
        inst:RemoveEventCallback("onremove", inst._onmarkingremoved, inst.marking)
        inst.marking = nil
    end

    if inst.AnimState:IsCurrentAnimation(inst.organname.."_rise_idle") and not (inst.components.inventoryitem:IsHeld() or inst:IsAsleep()) then
        inst.AnimState:PlayAnimation(inst.organname.."_fall")
        inst.AnimState:PushAnimation(inst.organname.."_idle")
    else
        inst.AnimState:PlayAnimation(inst.organname.."_idle")
    end
end

local function SetInRitual(inst, marking)
    inst.marking = marking
    inst:ListenForEvent("onremove", inst._onmarkingremoved, marking)

    if POPULATING or inst:IsAsleep() then
        if not inst.AnimState:IsCurrentAnimation(inst.organname.."_rise_idle") then
            inst.AnimState:PlayAnimation(inst.organname.."_rise_idle", true)
	        inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
        end
    else
        inst.AnimState:PlayAnimation(inst.organname.."_rise")
        inst.AnimState:PushAnimation(inst.organname.."_rise_idle", true)
    end
end

local function Consume(inst)
    inst.marking:RitualItemDetached()
    inst.marking = nil
    inst.persists = false
    inst.components.inventoryitem.canbepickedup = false
    inst.AnimState:PlayAnimation(inst.organname.."_consume")
    inst:ListenForEvent("animover", inst.Remove)
    inst:ListenForEvent("entitysleep", inst.Remove)
end

local function OnDroppedAsLoot(inst, data)
    if TheWorld.components.atriumritualorgantracker then
        local neededwormorgan
        if inst.prefab == "atrium_ritual_organ_worm" then
            neededwormorgan = TheWorld.components.atriumritualorgantracker:NeedsRitualOrgan(inst.prefab)
        end
        TheWorld.components.atriumritualorgantracker:SetRitualOrgan(inst.prefab)
        if neededwormorgan then
            -- we got the worm organ, so lets not do this next one with a worm boss guaranteed
            TheWorld:PushEvent("hounded_forceplannewattack", { choosemintime = true })
        end
    end
end

local function GetStatus(inst)--, viewer)
    return (inst.marking and "IN_RITUAL") or nil
end

local function MakeRitualOrgan(name)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("atrium_ritual_organs")
        inst.AnimState:SetBuild("atrium_ritual_organs")
        inst.AnimState:PlayAnimation(name.."_idle")
    	inst.AnimState:SetSymbolLightOverride("red_"..name, 1)

		MakeInventoryFloatable(inst, "small", 0.12, 1.1)

        inst:AddTag("ritualitem")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.organname = name

        inst:AddComponent("inspectable")
        inst.components.inspectable.getstatus = GetStatus

        inst:AddComponent("inventoryitem")

        inst.SetItem = SetItem
        inst.SetInRitual = SetInRitual
        inst.Consume = Consume

        inst:ListenForEvent("on_loot_dropped", OnDroppedAsLoot)

        inst:ListenForEvent("teleported", inst.SetItem)
        inst:ListenForEvent("onputininventory", inst.SetItem)
        inst:ListenForEvent("ondropped", inst.SetItem)
        inst:ListenForEvent("onremove", inst.SetItem)
        inst._onmarkingremoved = function() inst:SetItem() end

        inst.inventoryitem_DeactivateBeforeLaunch = inst.SetItem

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("atrium_ritual_organ_"..name, fn, assets)
end

return MakeRitualOrgan("rocky"), MakeRitualOrgan("bat"), MakeRitualOrgan("worm")
-- (OMAR): For searching
 -- atrium_ritual_organ_rocky
 -- atrium_ritual_organ_bat
 -- atrium_ritual_organ_worm