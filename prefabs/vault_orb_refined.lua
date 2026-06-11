local assets = {
	Asset("ANIM", "anim/vault_orb_refined.zip"),
}

local prefabs = {
    "bufferedmapaction", -- From vaultorbteleporter component.
}

local function DoTeleport(inst, doer, target) -- Delayed check all valid.
    local x, y, z
    target = target and target:IsValid() and target or doer
    if target ~= doer then
        x, y, z = target.Transform:GetWorldPosition()
    else
        x, y, z = doer.Transform:GetWorldPosition()
    end
    SpawnPrefab("vault_portal_fx").Transform:SetPosition(x, y, z)
    if doer.Physics then
        doer.Physics:Teleport(x, 0, z)
    else
        doer.Transform:SetPosition(x, 0, z)
    end
    if doer.isplayer then
        if doer.SnapCamera then
            doer:SnapCamera()
        end
    end
    if doer.SoundEmitter then
        doer.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_arrive_FX")
    end
    if inst:IsValid() then
        if inst.components.stackable and inst.components.stackable:IsStack() then
            inst.components.stackable:Get():Remove()
        else
            inst:Remove()
        end
    end
end

local function OnActivate(inst, doer, target)
    doer:PushEventImmediate("vault_teleport", {
        onplayerready = function()
            DoTeleport(inst, doer, target)
        end,
    })
    return true
end

local function OnStartMapAction(inst, doer)
    doer:AddTag("vaultorbteleportdestinationtracker")
    return true
end

local function OnCancelMapAction(inst, doer)
    if doer then
        doer:RemoveTag("vaultorbteleportdestinationtracker")
        doer:PushEvent("interruptcontinuousaction", inst)
    end
end

local function OnStopContinuousAction(inst, doer)
    inst.components.vaultorbteleporter:CancelMapAction()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("vault_orb_refined")
    inst.AnimState:SetBuild("vault_orb_refined")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "small", 0.05, { 0.8, 0.75, 0.8 })

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.swap_build = "vault_orb_refined"
    inst.swap_symbol = "swap_vault_orb_refined_gem"
    inst.crushitemcast_sound = "rifts6/vault_portal/teleport_fx"

    inst:AddComponent("tradable")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM

    local vaultorbteleporter = inst:AddComponent("vaultorbteleporter")
    vaultorbteleporter:SetOnActivateFn(OnActivate)
    vaultorbteleporter:SetOnStartMapActionFn(OnStartMapAction)
    vaultorbteleporter:SetOnCancelMapActionFn(OnCancelMapAction)
    inst:ListenForEvent("stopcontinuousaction", OnStopContinuousAction)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("vault_orb_refined", fn, assets, prefabs)
