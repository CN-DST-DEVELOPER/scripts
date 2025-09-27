local assets =
{
    Asset("ANIM", "anim/gridplacer.zip"),
}

local function OnCanBuild(inst, mouse_blocked)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst:Show()
end

local function OnCannotBuild(inst, mouse_blocked)
    inst.AnimState:SetMultColour(.75, .25, .25, 1)
    inst:Show()
end

local function fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim", true)
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

    inst:AddComponent("placer")
	inst.components.placer.hide_inv_icon = false
    inst.components.placer.snap_to_tile = true
    inst.components.placer.oncanbuild = OnCanBuild
    inst.components.placer.oncannotbuild = OnCannotBuild

    return inst
end

local function tile_outline_fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim")
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

    return inst
end

local function axisalignedplacement_outline_fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("tileunit")
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetFinalOffset(7)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

    return inst
end

local function turfhat_update(inst)
    local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(inst.player.Transform:GetWorldPosition())
    if not tx then
        return
    end

    inst.Transform:SetPosition(tx, ty, tz)
end

local function SetPlayer(inst, player)
    inst.player = player
    if player then
        inst.components.updatelooper:AddOnWallUpdateFn(turfhat_update)
        inst:ListenForEvent("onremove", inst._onremoveplayer, player)
    else
        inst.components.updatelooper:RemoveOnWallUpdateFn(turfhat_update)
        inst:RemoveEventCallback("onremove", inst._onremoveplayer, player)
    end
end

local function turfhat_fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:SetCanSleep(false)

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim")
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

    inst:AddComponent("updatelooper")

    inst.SetPlayer = SetPlayer
    inst._onremoveplayer = function() inst:SetPlayer() end

    return inst
end

local function farmablesoil_update(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsFarmableSoilAtPoint(x, y, z) then
        inst.AnimState:Show("Layer 3")
    else
        inst.AnimState:Hide("Layer 3")
    end
end

local function farmablesoil_fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim", true)
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:Hide("Layer 3")

    inst:AddComponent("placer")
	inst.components.placer.hide_inv_icon = false
    inst.components.placer.snap_to_tile = true
    inst.components.placer.oncanbuild = OnCanBuild
    inst.components.placer.oncannotbuild = OnCannotBuild
	inst.components.placer.onupdatetransform = farmablesoil_update

    return inst
end

return Prefab("gridplacer", fn, assets),
    Prefab("tile_outline", tile_outline_fn, assets),
    Prefab("axisalignedplacement_outline", axisalignedplacement_outline_fn, assets),
    Prefab("gridplacer_turfhat", turfhat_fn, assets),
    Prefab("gridplacer_farmablesoil", farmablesoil_fn, assets)
