
local GHOSTVISION_NIGHTVISION_COLOURCUBES =
{
    day = "images/colour_cubes/ghost_cc.tex",
    dusk = "images/colour_cubes/ghost_cc.tex",
    night = "images/colour_cubes/ghost_cc.tex",
    full_moon = "images/colour_cubes/ghost_cc.tex",
--}
  --  nightvision_fruit = true, -- NOTES(DiogoW): Here for convinience.
}

local assets =
{

}

local prefabs =
{

}


local function buff_OnAttached(inst, target)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)

    if target.components.playervision ~= nil then
        target.components.playervision:PushForcedNightVision(inst, 1, GHOSTVISION_NIGHTVISION_COLOURCUBES, true)
        inst._enabled:set(true)
    end
end

local function buff_OnDetached(inst, target)
    if target ~= nil and target:IsValid() then
        if target.components.playervision ~= nil then
            target.components.playervision:PopForcedNightVision(inst)
            inst._enabled:set(false)
        end

        if target.components.sanity ~= nil then
            target.components.sanity.externalmodifiers:RemoveModifier(inst)
        end
    end

    -- NOTES(DiogoW): Delayed removal to let the client run the dirty event.
    inst:DoTaskInTime(10*FRAMES, inst.Remove)
end

local function buff_Expire(inst)
    if inst.components.debuff ~= nil then
        inst.components.debuff:Stop()
    end
end

local function buff_OnExtended(inst)
    if inst.task ~= nil then
        inst.task:Cancel()
        inst.task = nil
    end
end

local function buff_OnSave(inst, data)
    if inst.task ~= nil then
        data.remaining = GetTaskRemaining(inst.task)
    end
end

local function buff_OnLoad(inst, data)
    if data == nil then
        return
    end

    if data.remaining then
        if inst.task ~= nil then
            inst.task:Cancel()
            inst.task = nil
        end

        inst.task = inst:DoTaskInTime(data.remaining, buff_Expire)
    end
end

local function buff_OnLongUpdate(inst, dt)
    if inst.task == nil then
        return
    end

    local remaining = GetTaskRemaining(inst.task) - dt

    inst.task:Cancel()

    if remaining > 0 then
        inst.task = inst:DoTaskInTime(remaining, buff_Expire)
    else
        buff_Expire(inst)
    end
end

local function buff_OnEnabledDirty(inst)
    if ThePlayer ~= nil and inst.entity:GetParent() == ThePlayer and ThePlayer.components.playervision ~= nil then
        if inst._enabled:value() then
            ThePlayer.components.playervision:PushForcedNightVision(inst, 1, GHOSTVISION_NIGHTVISION_COLOURCUBES, true)
        else
            ThePlayer.components.playervision:PopForcedNightVision(inst)
        end
    end
end

local function fn_ghostvisionbuff()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")

    inst._enabled = net_bool(inst.GUID, "ghostvision_buff._enabled", "enableddirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("enableddirty", buff_OnEnabledDirty)

        return inst
    end

    inst.entity:Hide()

    inst.persists = false

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(buff_OnAttached)
    inst.components.debuff:SetDetachedFn(buff_OnDetached)
    inst.components.debuff:SetExtendedFn(buff_OnExtended)
    inst.components.debuff.keepondespawn = true

    buff_OnExtended(inst)

    inst.OnSave = buff_OnSave
    inst.OnLoad = buff_OnLoad

    inst.OnLongUpdate = buff_OnLongUpdate

    return inst
end

return Prefab("ghostvision_buff", fn_ghostvisionbuff)

