local assets = {
    Asset("ANIM", "anim/hermitcrab_relocation_kit.zip"),
    Asset("INV_IMAGE", "hermitcrab_relocation_kit"),
    Asset("ANIM", "anim/hermitcrab_home.zip"),
    Asset("ANIM", "anim/meatrack_hermit.zip"),
    Asset("ANIM", "anim/bee_box_hermitcrab.zip"),
}

local PEARLSETPIECE_KIT = {
    ["hermitcrab_marker"] = { -- 1
        {0, 0, 0}, -- Place at island center this is an achievement marker for island center point.
    },
    ["hermitcrab_lure_marker"] = { -- 1
        {-2.4, 5.9, 0}, -- Place where lureplant bulbs are created.
    },
    ["hermitcrab_marker_fishing"] = { -- 16 in coastal tiles knight's move away max from land
        {-7.2, -8.1, 0},
        {-6.6, -11.2, 0},
        {-6.2, -5.5, 0},
        {-5.1, -9.5, 0},
        {-4.1, -7.1, 0},
        {-2.6, -10.1, 0},
        {-1.8, -5.6, 0},
        {-0.9, -7.9, 0},
        {0.4, -10.5, 0},
        {1.1, -5.6, 0},
        {1.7, -8.1, 0},
        {3.5, -6.3, 0},
        {4.3, -8.9, 0},
        {5.8, -10.8, 0},
        {6.4, -5.4, 0},
        {7.3, -7.9, 0},
    },
    ["hermithouse"] = { -- 1
        {0, 0, 0},
    },
    ["hermithouse_construction1"] = { -- 1
        {0, 0, 0},
    },
    ["hermithouse_construction2"] = { -- 1
        {0, 0, 0},
    },
    ["hermithouse_construction3"] = { -- 1
        {0, 0, 0},
    },
    ["hermitcrab"] = { -- 1 or 0
        {2.5, 0, 0},
    },
    ["meatrack_hermit"] = { -- 6
        {2.4, 5.3, 0},
        {5.6, 2.1, 0},
        {6.4, -1.7, 0},
        {7.3, 5.7, 0},
        {4.9, 7.5, 0},
        {0.6, 8.1, 0},
    },
    ["beebox_hermit"] = { -- 1
        {-5.3, 2.3, 0},
    },
}
local PLACER_VISUALS = {
    --["hermitcrab_marker"] = NO_VISUALS,
    ["hermitcrab_lure_marker"] = {"reticuleaoe", "reticuleaoe", "idle_small"},
    ["hermitcrab_marker_fishing"] = {"reticuleaoe", "reticuleaoe", "idle_small"},
    ["hermithouse_construction3"] = {"hermitcrab_home", "hermitcrab_home", "idle_stage4"},
    --["hermitcrab"] = NO_VISUALS,
    ["meatrack_hermit"] = {"meatrack_hermit", "meatrack_hermit", "idle_empty"},
    ["beebox_hermit"] = {"bee_box_hermitcrab", "bee_box_hermitcrab", "idle"},
}
local PLACER_RADIUS = {
    --["hermitcrab_marker"] = NO_RADIUS,
    ["hermitcrab_lure_marker"] = 1,
    ["hermitcrab_marker_fishing"] = 1,
    ["hermithouse_construction3"] = 3,
    --["hermitcrab"] = NO_RADIUS,
    ["meatrack_hermit"] = 1.5,
    ["beebox_hermit"] = 1.5,
}

local function IsPermanentFilterFn(tileid)
    return IsLandTile(tileid) and not (TileGroupManager:IsTemporaryTile(tileid) and tileid ~= WORLD_TILES.FARMING_SOIL)
end
local CHECK_CANT_TAGS = {"FX", "NOCLICK", "DECOR", "INLIMBO", "NOBLOCK", "player"}
local function CLIENT_CanDeployKit(inst, pt, mouseover, deployer, rotation)
    if not TheWorld:HasTag("forest") then
        return false
    end
    local hermitcrab_relocation_manager = TheWorld.components.hermitcrab_relocation_manager
    if hermitcrab_relocation_manager and not hermitcrab_relocation_manager:CanPearlMove() then
        return false, "HERMITCRAB_RELOCATE"
    end

    local map = TheWorld.Map
    local rot = -rotation * DEGREES
    local sin, cos = math.sin(rot), math.cos(rot)
    for prefab, prefabdata in pairs(inst.PEARLSETPIECE_KIT) do
        for _, placementdata in ipairs(prefabdata) do
            local xo, zo = placementdata[1], placementdata[2]
            local r = PLACER_RADIUS[prefab]
            local x = pt.x + xo * cos - zo * sin
            local z = pt.z + xo * sin + zo * cos

            local clear = not map:IsPointInWagPunkArena(x, 0, z)
            if not clear then
                return false
            end

            if r then
                local ents = TheSim:FindEntities(x, 0, z, r, nil, CHECK_CANT_TAGS)
                for _, v in ipairs(ents) do
                    if v ~= deployer then
                        clear = false
                        break
                    end
                end
            end
            if prefab == "hermitcrab_marker_fishing" then
                if not clear or not map:IsOceanAtPoint(x, 0, z, false) then
                    return false
                end
            else
                if not clear or not IsPermanentFilterFn(map:GetTileAtPoint(x, 0, z)) then
                    return false
                end
            end
        end
    end
    return true -- The center placer is handled already as hermithouse_construction3.
end

local function ondeploy(inst, pt, deployer, rotation)
    local hermitcrab_relocation_manager = TheWorld.components.hermitcrab_relocation_manager
    if hermitcrab_relocation_manager then
        local rot = -rotation * DEGREES
        local sin, cos = math.sin(rot), math.cos(rot)
        local orientatedsetpiece = deepcopy(inst.PEARLSETPIECE_KIT)
        for prefab, prefabdata in pairs(orientatedsetpiece) do
            for _, placementdata in ipairs(prefabdata) do
                local xo, zo = placementdata[1], placementdata[2]
                local x = xo * cos - zo * sin
                local z = xo * sin + zo * cos
                placementdata[1], placementdata[2] = x, z
            end
        end
        hermitcrab_relocation_manager:SetupTeleportingPearlToSetPieceData(orientatedsetpiece, pt.x, pt.z)
        inst:Remove()
    else
        inst.Transform:SetPosition(pt:Get())
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("hermitcrab_relocation_kit")
    inst.AnimState:SetBuild("hermitcrab_relocation_kit")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "wood"

    MakeInventoryFloatable(inst, "med", 0.2, 0.75)

    inst:AddTag("deploykititem")
    inst:AddTag("usedeployspacingasoffset")

    inst.PEARLSETPIECE_KIT = PEARLSETPIECE_KIT -- For placers.
    inst._custom_candeploy_fn = CLIENT_CanDeployKit -- for DEPLOYMODE.CUSTOM

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -------------------------------------------------------
    inst:AddComponent("inspectable")

    -------------------------------------------------------
    inst:AddComponent("inventoryitem")

    -------------------------------------------------------
    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
    inst.components.deployable.ondeploy = ondeploy

    return inst
end

-------------------------------------------
-- hermitcrab_relocation_kit_placer


local function OnUpdateTransform(inst)
    local deployer = ThePlayer
    local map = TheWorld.Map
    local pt = inst:GetPosition()
    local rot = -inst.Transform:GetRotation() * DEGREES
    local sin, cos = math.sin(rot), math.cos(rot)
    for prefab, prefabdata in pairs(PEARLSETPIECE_KIT) do -- Not inst.PEARLSETPIECE_KIT because the placer is a visualizer mods should edit it from the kit itself.
        local visuals = inst.placervisuals[prefab]
        if visuals then
            for i, placementdata in ipairs(prefabdata) do
                local xo, zo = placementdata[1], placementdata[2]
                local r = PLACER_RADIUS[prefab]
                local x = pt.x + xo * cos - zo * sin
                local z = pt.z + xo * sin + zo * cos

                local clear = not map:IsPointInWagPunkArena(x, 0, z)
                if clear then
                    if r then
                        local ents = TheSim:FindEntities(x, 0, z, r, nil, CHECK_CANT_TAGS)
                        for _, v in ipairs(ents) do
                            if v ~= deployer then
                                clear = false
                                break
                            end
                        end
                    end
                end

                if prefab == "hermitcrab_marker_fishing" then
                    if not clear or not map:IsOceanAtPoint(x, 0, z, false) then
                        visuals[i].AnimState:PlayAnimation("idle_small_target")
                        visuals[i].AnimState:SetAddColour(.75, .25, .25, 0)
                    else
                        visuals[i].AnimState:PlayAnimation("idle_small")
                        visuals[i].AnimState:SetAddColour(.25, .75, .25, 0)
                    end
                else
                    if not clear or not IsPermanentFilterFn(map:GetTileAtPoint(x, 0, z)) then
                        if prefab == "hermitcrab_lure_marker" then
                            visuals[i].AnimState:PlayAnimation("idle_small_target")
                        end
                        visuals[i].AnimState:SetAddColour(.75, .25, .25, 0)
                    else
                        if prefab == "hermitcrab_lure_marker" then
                            visuals[i].AnimState:PlayAnimation("idle_small")
                        end
                        visuals[i].AnimState:SetAddColour(.25, .75, .25, 0)
                    end
                end
            end
        end
    end
end
local function CreatePlacerVisual(bank, build, anim)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:PlayAnimation(anim)

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    return inst
end
local function OnCanBuild(inst, mouseblocked)
    inst.AnimState:SetAddColour(.25, .75, .25, 0)
    inst:Show()
end

local function OnCannotBuild(inst, mouseblocked)
    inst.AnimState:SetAddColour(.75, .25, .25, 0)
    inst:Show()
end
local function PlacerPostinit(inst)
    inst.components.placer.hide_inv_icon = false

    if not TheWorld:HasTag("forest") then
        return
    end

    inst.placervisuals = {}
    for prefab, prefabdata in pairs(PEARLSETPIECE_KIT) do -- Not inst.PEARLSETPIECE_KIT because the placer is a visualizer mods should edit it from the kit itself.
        local visualsdata = PLACER_VISUALS[prefab]
        if visualsdata then
            inst.placervisuals[prefab] = {}
            for i, placementdata in ipairs(prefabdata) do
                local x, z = placementdata[1], placementdata[2]
                local bank, build, anim = visualsdata[1], visualsdata[2], visualsdata[3]
                local ent = CreatePlacerVisual(bank, build, anim)
                inst.placervisuals[prefab][i] = ent
                if prefab == "hermitcrab_marker_fishing" or prefab == "hermitcrab_lure_marker" then
                    ent.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
                    ent.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
                    ent.AnimState:SetSortOrder(3)
                    ent.AnimState:SetScale(.85, .85)
                end
                ent.entity:SetParent(inst.entity)
                ent.Transform:SetPosition(x, 0, z)
            end
        end
    end

    inst.components.placer.onupdatetransform = OnUpdateTransform
    inst.components.placer.oncanbuild = OnCanBuild
    inst.components.placer.oncannotbuild = OnCannotBuild
end


return Prefab("hermitcrab_relocation_kit", fn, assets),
    MakePlacer("hermitcrab_relocation_kit_placer", nil, nil, nil, nil, nil, nil, nil, 90, nil, PlacerPostinit)