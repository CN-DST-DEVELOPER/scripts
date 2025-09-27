local assets = {
    Asset("ANIM", "anim/wagpunk_lever.zip"),
}

local function OnActivate(inst, doer)
    TheWorld:PushEvent("ms_wagpunk_lever_activated") -- In front of RetractLever for ordering on lever toggled state.
    inst:RetractLever()
    return true
end

local function OnPlayerNear(inst, player)
    if TheWorld.components.wagpunk_arena_manager then
        TheWorld.components.wagpunk_arena_manager:LeverToggled(inst, true)
    end
end

local function OnPlayerFar(inst, player)
    if TheWorld.components.wagpunk_arena_manager then
        TheWorld.components.wagpunk_arena_manager:LeverToggled(inst, false)
    end
end

local function ExtendLever(inst)
    if inst.extended then
        return
    end
    inst.extended = true
    inst:RemoveTag("NOCLICK")
    local playerprox = inst:AddComponent("playerprox")
    playerprox:SetDist(TUNING.RESEARCH_MACHINE_DIST, TUNING.RESEARCH_MACHINE_DIST)
    playerprox:SetOnPlayerNear(inst.OnPlayerNear)
    playerprox:SetOnPlayerFar(inst.OnPlayerFar)
    playerprox:SetPlayerAliveMode(playerprox.AliveModes.AliveOnly)

    inst.components.activatable.inactive = true
    ChangeToObstaclePhysics(inst)
    if inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle")
    else
        inst.AnimState:PlayAnimation("deactivated")
        inst.AnimState:PushAnimation("idle", true)
        inst.SoundEmitter:PlaySound("rifts5/wagpunk_fence/lever_activate")
    end
end

local function RetractLever(inst)
    if not inst.extended then
        return
    end
    inst.extended = false
    inst:AddTag("NOCLICK")
    inst:RemoveComponent("playerprox")
    if TheWorld.components.wagpunk_arena_manager then
        TheWorld.components.wagpunk_arena_manager:LeverToggled(inst, false)
    end

    inst.components.activatable.inactive = false
    RemovePhysicsColliders(inst)
    if inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle_close")
    else
        inst.AnimState:PlayAnimation("activate")
        inst.AnimState:PushAnimation("idle_close", true)
        inst.SoundEmitter:PlaySound("rifts5/wagpunk_fence/lever_deactivate")
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 0.4)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("wagpunk_lever")
    inst.AnimState:SetBuild("wagpunk_lever")
    inst.AnimState:PlayAnimation("idle_close")

    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "idle"

    inst:AddComponent("inspectable")

    local activatable = inst:AddComponent("activatable")
    activatable.OnActivate = OnActivate
    activatable.standingaction = true
    activatable.inactive = false

    inst.extended = false
    inst.ExtendLever = ExtendLever
    inst.RetractLever = RetractLever
    inst.OnPlayerNear = OnPlayerNear
    inst.OnPlayerFar = OnPlayerFar

    return inst
end

return Prefab("wagpunk_lever", fn, assets)