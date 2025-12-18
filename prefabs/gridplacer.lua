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
    inst.entity:SetCanSleep(false)
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
    inst.entity:SetCanSleep(false)
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

local function turfhat_wallupdate(inst)
    local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(inst.player.Transform:GetWorldPosition())
    if not tx then
        return
    end

    inst.Transform:SetPosition(tx, ty, tz)

    TriggerDeployHelpers(tx, ty, tz, 64, nil, inst)
end

local function turfhat_update(inst)
    local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(inst.player.Transform:GetWorldPosition())
    if not tx then
        return
    end

    TriggerDeployHelpers(tx, ty, tz, 64, nil, inst)
end

local function SetPlayer(inst, player)
    inst.player = player
    if player then
        inst.components.updatelooper:AddOnWallUpdateFn(turfhat_wallupdate)
        inst.components.updatelooper:AddOnUpdateFn(turfhat_update)
        inst:ListenForEvent("onremove", inst._onremoveplayer, player)
    else
        inst.components.updatelooper:RemoveOnWallUpdateFn(turfhat_wallupdate)
        inst.components.updatelooper:RemoveOnUpdateFn(turfhat_update)
        inst:RemoveEventCallback("onremove", inst._onremoveplayer, player)
    end
end

local function turfhat_fn()
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
    inst.entity:SetCanSleep(false)
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

----

local DIRS =
{
    N = "n",
    S = "s",
    W = "w",
    E = "e",
}
local OPPOSITE_DIRS =
{
    [DIRS.N] = DIRS.S,
    [DIRS.S] = DIRS.N,
    [DIRS.W] = DIRS.E,
    [DIRS.E] = DIRS.W,
}
local function update_grid_art_at_coords(inst, tx, tz)
    local placer = inst.outline_grid:GetDataAtPoint(tx, tz)
    --
    local function ShowOrHide(nplacer, dir)
        if placer then
            placer.AnimState:Hide(dir)
            nplacer.AnimState:Hide(OPPOSITE_DIRS[dir])
        else
            nplacer.AnimState:Show(OPPOSITE_DIRS[dir])
        end
    end

    local function UpdateCoords(offx, offz)
        local x, z = tx + offx, tz + offz
        local nplacer = inst.outline_grid:GetDataAtPoint(x, z)
        if nplacer then
            if x < tx then
                ShowOrHide(nplacer, DIRS.S)
            elseif x > tx then
                ShowOrHide(nplacer, DIRS.N)
            end

            if z < tz then
                ShowOrHide(nplacer, DIRS.E)
            elseif z > tz then
                ShowOrHide(nplacer, DIRS.W)
            end
        end
    end
    --
    for offx = -1, 1 do
        if offx ~= 0 then
            UpdateCoords(offx, 0)
        end
    end

    for offz = -1, 1 do
        if offz ~= 0 then
            UpdateCoords(0, offz)
        end
    end
end

local function place_grid(inst, tx, tz)
    local index = inst.outline_grid:GetIndex(tx, tz)
    local placer = inst.outline_grid:GetDataAtIndex(index)
    if placer then
        return
    end

    placer = SpawnPrefab("gridplacer")
    placer.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(tx, tz))
    inst.outline_grid:SetDataAtIndex(index, placer)

    update_grid_art_at_coords(inst, tx, tz)
end

local function place_grid_at_point(inst, x, y, z)
    inst:PlaceGrid(TheWorld.Map:GetTileCoordsAtPoint(x, y, z))
end

local function remove_grid(inst, tx, tz)
    local index = inst.outline_grid:GetIndex(tx, tz)
    local placer = inst.outline_grid:GetDataAtIndex(index)
    if not placer then
        return
    end

    placer:Remove()
    inst.outline_grid:SetDataAtIndex(index, nil)

    update_grid_art_at_coords(inst, tx, tz)
end

local function remove_grid_at_point(inst, x, y, z)
    inst:RemoveGrid(TheWorld.Map:GetTileCoordsAtPoint(x, y, z))
end

local function GridGroup_OnCanBuild(inst, mouse_blocked)
    --OnCanBuild(inst, mouse_blocked)
    --
	for index in pairs(inst.outline_grid.grid) do
        local placer = inst.outline_grid:GetDataAtIndex(index)
        placer.AnimState:SetMultColour(1, 1, 1, 1)
        placer:Show()
	end
end

local function GridGroup_OnCannotBuild(inst, mouse_blocked)
    --OnCannotBuild(inst, mouse_blocked)
    --
	for index in pairs(inst.outline_grid.grid) do
        local placer = inst.outline_grid:GetDataAtIndex(index)
        placer.AnimState:SetMultColour(.75, .25, .25, 1)
        placer:Show()
	end
end

local function GridGroup_OnRemove(inst)
    for index in pairs(inst.outline_grid.grid) do
        local placer = inst.outline_grid:GetDataAtIndex(index)
        placer:Remove()
	end
    inst.outline_grid = nil
end

local function grid_group_fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()

    inst:AddComponent("placer")
	inst.components.placer.hide_inv_icon = false
    inst.components.placer.snap_to_tile = true
    inst.components.placer.oncanbuild = GridGroup_OnCanBuild
    inst.components.placer.oncannotbuild = GridGroup_OnCannotBuild

    ----
    inst.outline_grid = DataGrid(TheWorld.Map:GetSize())
    inst:ListenForEvent("onremove", GridGroup_OnRemove)

    inst.PlaceGrid = place_grid
    inst.PlaceGridAtPoint = place_grid_at_point

    inst.RemoveGrid = remove_grid
    inst.RemoveGridAtPoint = remove_grid_at_point
    ----

    return inst
end

return Prefab("gridplacer", fn, assets),
    Prefab("tile_outline", tile_outline_fn, assets),
    Prefab("axisalignedplacement_outline", axisalignedplacement_outline_fn, assets),
    Prefab("gridplacer_turfhat", turfhat_fn, assets),
    Prefab("gridplacer_farmablesoil", farmablesoil_fn, assets),
    Prefab("gridplacer_group_outline", grid_group_fn, assets)
