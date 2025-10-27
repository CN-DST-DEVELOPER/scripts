local normal_assets =
{
    Asset("ANIM", "anim/buzzard_shadow.zip"),
    Asset("ANIM", "anim/buzzard_build.zip"),
}

local mutated_assets =
{
    Asset("ANIM", "anim/buzzard_shadow.zip"),
    Asset("ANIM", "anim/buzzard_lunar_build.zip"),
}

local MAX_FADE_FRAME = math.floor(3 / FRAMES + .5)

local function OnUpdateFade(inst, dframes)
    local done
    if inst._isfadein:value() then
        local frame = inst._fadeframe:value() + dframes
        done = frame >= MAX_FADE_FRAME
        inst._fadeframe:set_local(done and MAX_FADE_FRAME or frame)
    else
        local frame = inst._fadeframe:value() - dframes
        done = frame <= 0
        inst._fadeframe:set_local(done and 0 or frame)
    end

    local k = inst._fadeframe:value() / MAX_FADE_FRAME
    inst.AnimState:OverrideMultColour(1, 1, 1, k)

    if done then
        inst._fadetask:Cancel()
        inst._fadetask = nil
        if inst._killed then
            --don't need to check ismastersim, _killed will never be set on clients
            inst:Remove()
            return
        end
    end

    if TheWorld.ismastersim then
        if inst._fadeframe:value() > 0 then
            inst:Show()
        else
            inst:Hide()
        end
    end
end

local function OnFadeDirty(inst)
    if inst._fadetask == nil then
        inst._fadetask = inst:DoPeriodicTask(FRAMES, OnUpdateFade, nil, 1)
    end
    OnUpdateFade(inst, 0)
end

local function CircleOnIsNight(inst, isnight)
    inst._isfadein:set(not isnight)
    inst._fadeframe:set(inst._fadeframe:value())
    OnFadeDirty(inst)
end

local function CircleOnIsWinter(inst, iswinter)
    if iswinter then
        inst:StopWatchingWorldState("isnight", CircleOnIsNight)
        CircleOnIsNight(inst, true)
    else
        inst:WatchWorldState("isnight", CircleOnIsNight)
        CircleOnIsNight(inst, TheWorld.state.isnight)
    end
end

local function NormalCircleOnInit(inst)
    inst:WatchWorldState("iswinter", CircleOnIsWinter)
    CircleOnIsWinter(inst, TheWorld.state.iswinter)
end

local function DoFlap(inst)
    if math.random() > 0.66 then
        inst.AnimState:PlayAnimation("shadow_flap_loop")
        for i = 2, math.random(3, 6) do
            inst.AnimState:PushAnimation("shadow_flap_loop")
        end
        inst.AnimState:PushAnimation("shadow")
    end
end

local function KillShadow(inst)
    if inst._fadeframe:value() > 0 and not inst:IsAsleep() then
        inst:StopWatchingWorldState("iswinter", CircleOnIsWinter)
        inst:StopWatchingWorldState("isnight", CircleOnIsNight)
        inst._killed = true
        inst._isfadein:set(false)
        inst._fadeframe:set(inst._fadeframe:value())
        OnFadeDirty(inst)
    else
        inst:Remove()
    end
end

local function commonfn(build, common_postinit)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("buzzard")
    inst.AnimState:SetBuild(build)
    inst.AnimState:PlayAnimation("shadow", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:OverrideMultColour(1, 1, 1, 0)

    inst:AddTag("FX")

    inst._fadeframe = net_byte(inst.GUID, "circlingbuzzard._fadeframe", "fadedirty")
    inst._isfadein = net_bool(inst.GUID, "circlingbuzzard._isfadein", "fadedirty")
    inst._fadetask = nil

    if common_postinit ~= nil then
        common_postinit(inst)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("fadedirty", OnFadeDirty)
        return inst
    end

    inst.KillShadow = KillShadow

    inst.persists = false

    return inst
end

local function normalfn()
    local inst = commonfn("buzzard_build")

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoPeriodicTask(3 + math.random() * 2, DoFlap)
    inst:AddComponent("circler")
    inst:DoTaskInTime(0, NormalCircleOnInit)

    return inst
end

local function MutatedCircleOnInit(inst)
    inst._isfadein:set(true)
    inst._fadeframe:set(inst._fadeframe:value())
    OnFadeDirty(inst)
end

local function mutated_common_postinit(inst)
    inst.entity:AddSoundEmitter()

    inst:AddTag("lunar_aligned")

    MakeFlyingCharacterPhysics(inst, 10, .1)
    inst.Physics:SetCollisionMask(COLLISION.GROUND)
end

local function mutatedfn()
    local inst = commonfn("buzzard_lunar_build", mutated_common_postinit)

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoPeriodicTask(2 + math.random() * 1.5, DoFlap) -- More frantic flapping!
    inst:AddComponent("mutatedbuzzardcircler")
    inst:DoTaskInTime(0, MutatedCircleOnInit)

    return inst
end

return Prefab("circlingbuzzard", normalfn, normal_assets),
    Prefab("circlingbuzzard_lunar", mutatedfn, mutated_assets)