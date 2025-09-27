local function UpdatePosition(inst, target)
    local x, y, z = target.Transform:GetWorldPosition()
    if inst._x ~= x or inst._z ~= z then
        inst._x = x
        inst._z = z
        inst.Transform:SetPosition(x, 0, z)
    end
end

local function TrackEntity(inst, target, restriction, icon)
    -- TODO(JBK): This function is not able to be ran twice without causing issues.
    inst._target = target
    if restriction ~= nil then
        inst.MiniMapEntity:SetRestriction(restriction)
    end
    if icon ~= nil then
        inst.MiniMapEntity:SetIcon(icon)
    elseif target.MiniMapEntity ~= nil then
        inst.MiniMapEntity:CopyIcon(target.MiniMapEntity)
    else
        inst.MiniMapEntity:SetIcon(target.prefab..".png")
    end
    inst:ListenForEvent("onremove", function() inst:Remove() end, target)
    inst:DoPeriodicTask(0, UpdatePosition, nil, target)
    UpdatePosition(inst, target)
end

local function common_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:AddTag("globalmapicon")
    inst:AddTag("CLASSIFIED")

    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetIsProxy(true)

    inst.entity:SetCanSleep(false)

    inst:DoTaskInTime(0, RegisterGlobalMapIcon)

    return inst
end
local function common_server(inst)
    inst._target = nil
    inst.TrackEntity = TrackEntity

    inst.persists = false
end

local function overfog_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function overfog_named_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst._target_displayname = net_string(inst.GUID, "globalmapiconnamed._target_displayname")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function underfog_fn()
    local inst = common_fn()

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

local function overfog_seeable_fn()
    local inst = common_fn()
    inst.MiniMapEntity:SetDrawOverFogOfWar(true, true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    common_server(inst)
    return inst
end

return Prefab("globalmapicon", overfog_fn),
    Prefab("globalmapiconnamed", overfog_named_fn),
    Prefab("globalmapiconunderfog", underfog_fn),
    Prefab("globalmapiconseeable", overfog_seeable_fn)
