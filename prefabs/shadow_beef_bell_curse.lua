local prefabs =
{
    "beef_bell_shadow_cursefx",
}

------------------------------------------------------------------------------------------------------------------------

local CURSE_FX_TIME = 150*FRAMES
local CURSE_EFFECTS_TIME = CURSE_FX_TIME + 12*FRAMES

------------------------------------------------------------------------------------------------------------------------

local function OnAttached(inst, target)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)

    if inst.loading then
        inst.task = inst:DoTaskInTime(0, inst.TriggerCurse)
    else
        inst.fxtask = inst:DoTaskInTime(CURSE_FX_TIME, inst.SpawnCurseFx, target)
        inst.task   = inst:DoTaskInTime(CURSE_EFFECTS_TIME, inst.TriggerCurse)
    end

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
end

local function OnDetached(inst, target)
    if target ~= nil and target:IsValid() then
        inst:DoCurseEffects(target)
    end

    inst:Remove()
end

------------------------------------------------------------------------------------------------------------------------

local function TriggerCurse(inst)
    if inst.components.debuff ~= nil then
        inst.components.debuff:Stop()
    end
end

local function SpawnCurseFx(inst, target)
    if target == nil or not target:IsValid() then
        return
    end

    local fx = SpawnPrefab("beef_bell_shadow_cursefx")

    if fx ~= nil then
        target:AddChild(fx)
    end
end

local function DoCurseEffects(inst, target)
    target.components.health:DeltaPenalty(TUNING.SHADOW_BEEF_BELL_CURSE_HEALTH_PENALTY)

    if not target.components.health:IsDead() then
        target.components.sanity:DoDelta(TUNING.SHADOW_BEEF_BELL_CURSE_SANITY_DELTA)

        if not inst.loading then
            target:PushEvent("consumehealthcost")
            target:ShakeCamera(CAMERASHAKE.VERTICAL, .5, .025, .15, target, 16)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------

local function OnLoad(inst)
    inst.loading = true -- POPULATING check doesn't work for players, so we need this...
end

------------------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        -- Not meant for clients!
        inst:DoTaskInTime(0, inst.Remove)

        return inst
    end

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    inst.entity:Hide()
    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetached)
    inst.components.debuff.keepondespawn = true

    inst.SpawnCurseFx = SpawnCurseFx
    inst.TriggerCurse = TriggerCurse
    inst.DoCurseEffects = DoCurseEffects

    inst.OnLoad = OnLoad

    return inst
end

return Prefab("shadow_beef_bell_curse", fn, nil, prefabs)