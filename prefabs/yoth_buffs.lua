local function OnAttached(inst, target, followsymbol, followoffset, data)
    local duration = data and data.duration or TUNING.YOTH_PRINCESS_SUMMON_COOLDOWN
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    if not inst.components.timer:TimerExists("buffover") then
        inst.components.timer:StartTimer("buffover", duration)
    end
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
end

local function OnDetached(inst, target)
    inst:Remove()
end

local function OnExtendedBuff(inst, target, followsymbol, followoffset, data)
    local duration = data and data.duration or TUNING.YOTH_PRINCESS_SUMMON_COOLDOWN
    local time_remaining = inst.components.timer:GetTimeLeft("buffover")
    if time_remaining == nil or duration > time_remaining then
        inst.components.timer:SetTimeLeft("buffover", duration)
    end
end

local function OnTimerDone(inst, data)
    if data.name == "buffover" then
        inst.components.debuff:Stop()
    end
end

local function fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetached)
    inst.components.debuff:SetExtendedFn(OnExtendedBuff)
    inst.components.debuff.keepondespawn = true

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    return inst
end

return Prefab("yoth_princesscooldown_buff", fn)