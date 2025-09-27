-----------------------------------------------------------
-- wagboss_robot_constructionsite

local assets_constructionsite = {
    Asset("ANIM", "anim/wagboss_robot.zip"),
    Asset("ANIM", "anim/ui_construction_1x1.zip"),
}
local prefabs_constructionsite = {
    "construction_container_1x1",
    "wagboss_robot",
}

local function OnConstructed_FinalizeReplacement(inst)
    local ent = ReplacePrefab(inst, "wagboss_robot")
    PreventCharacterCollisionsWithPlacedObjects(ent)
    TheWorld:PushEvent("ms_wagboss_robot_constructed", ent)
    ent.SoundEmitter:PlaySound("dontstarve/characters/wurt/merm/throne/build") -- FIXME(JBK): Audio.
end

local function OnConstructed_constructionsite(inst, doer)
    local materialsin, materialsneeded = 0, 0
    for _, v in ipairs(CONSTRUCTION_PLANS[inst.prefab] or {}) do
        materialsneeded = materialsneeded + v.amount
        materialsin = materialsin + inst.components.constructionsite:GetMaterialCount(v.type)
    end

    local percent = materialsin / materialsneeded
    if percent >= 1 then
        if inst.AnimState:IsCurrentAnimation("construction_small_place") or inst.AnimState:IsCurrentAnimation("construction_small") then
            inst.AnimState:PlayAnimation("construction_small_to_med")
            inst.AnimState:PushAnimation("construction_med_to_large", false)
            inst.AnimState:PushAnimation("construction_large", false)
            inst.AnimState:PushAnimation("construction_large_to_off", false)
            inst:ListenForEvent("animqueueover", OnConstructed_FinalizeReplacement)
        elseif inst.AnimState:IsCurrentAnimation("construction_small_to_med") or inst.AnimState:IsCurrentAnimation("construction_med") then
            inst.AnimState:PlayAnimation("construction_med_to_large")
            inst.AnimState:PushAnimation("construction_large", false)
            inst.AnimState:PushAnimation("construction_large_to_off", false)
            inst:ListenForEvent("animqueueover", OnConstructed_FinalizeReplacement)
        elseif not inst.AnimState:IsCurrentAnimation("construction_large_to_off") then
            inst.AnimState:PlayAnimation("construction_large_to_off")
            inst:ListenForEvent("animqueueover", OnConstructed_FinalizeReplacement)
        end
    elseif percent > 0.6 then
        if inst.AnimState:IsCurrentAnimation("construction_small_place") or inst.AnimState:IsCurrentAnimation("construction_small") then
            inst.AnimState:PlayAnimation("construction_small_to_med")
            inst.AnimState:PushAnimation("construction_med_to_large", false)
            inst.AnimState:PushAnimation("construction_large", false)
        elseif inst.AnimState:IsCurrentAnimation("construction_small_to_med") or inst.AnimState:IsCurrentAnimation("construction_med") then
            inst.AnimState:PlayAnimation("construction_med_to_large")
            inst.AnimState:PushAnimation("construction_large", false)
        end
    elseif percent > 0.3 then
        if inst.AnimState:IsCurrentAnimation("construction_small_place") or inst.AnimState:IsCurrentAnimation("construction_small") then
            inst.AnimState:PlayAnimation("construction_small_to_med")
            inst.AnimState:PushAnimation("construction_med", false)
        end
    end
end

local function OnBuilt_constructionsite(inst, data)
    PreventCharacterCollisionsWithPlacedObjects(inst)
    inst.AnimState:PlayAnimation("construction_small_place")
    inst.AnimState:PushAnimation("construction_small")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wurt/merm/throne/place") -- FIXME(JBK): Audio.
end

local function OnLoad_constructionsite(inst, data)
    OnConstructed_constructionsite(inst, nil)
end

local function fn_constructionsite()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("wagboss_robot")
    inst.AnimState:SetBuild("wagboss_robot")
    inst.AnimState:PlayAnimation("construction_small")

    inst:SetPhysicsRadiusOverride(3.5) -- NOTES(JBK): Keep in sync with the wagboss_robot! Search string [WBRPR]
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.MiniMapEntity:SetIcon("wagboss_robot_constructionsite.png")
    inst:AddTag("constructionsite")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    local constructionsite = inst:AddComponent("constructionsite")
    constructionsite:SetConstructionPrefab("construction_container_1x1")
    constructionsite:SetOnConstructedFn(OnConstructed_constructionsite)

    inst:AddComponent("inspectable")

    inst:ListenForEvent("onbuilt", OnBuilt_constructionsite)

    inst.OnLoad = OnLoad_constructionsite

    return inst
end

-----------------------------------------------------------
-- wagboss_robot_constructionsite_kit

local assets_kit = {
    Asset("ANIM", "anim/wagboss_robot.zip"),
    Asset("INV_IMAGE", "wagboss_robot_constructionsite_kit"),
}
local prefabs_kit = {
    "wagboss_robot_constructionsite",
}

local INDICATOR_MUST_TAGS = {"CLASSIFIED", "wagboss_robot_constructionsite_placerindicator"}
local function CLIENT_CanDeployKit(inst, pt, mouseover, deployer, rotation)
    local x, y, z = pt:Get()
    if not TheWorld.Map:IsPointInWagPunkArena(x, y, z) then
        return false
    end

    return TheSim:CountEntities(x, y, z, TUNING.WAGBOSS_ROBOT_CONSTRUCTIONSITE_KIT_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS) > 0
end

local function OnDeploy_kit(inst, pt, deployer)
    if deployer ~= nil and deployer.SoundEmitter ~= nil then
        deployer.SoundEmitter:PlaySoundWithParams("turnoftides/common/together/boat/damage", { intensity = 0.8 }) -- FIXME(JBK): Audio.
    end

    local x, y, z = pt:Get()

    local ents = TheSim:FindEntities(x, y, z, TUNING.WAGBOSS_ROBOT_CONSTRUCTIONSITE_KIT_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS)
    for _, ent in ipairs(ents) do
        ent:Remove()
    end

    local ent = SpawnPrefab("wagboss_robot_constructionsite")
    ent.Transform:SetPosition(x, y, z)
    ent:PushEvent("onbuilt", {builder = deployer, pos = Vector3(x, y, z)})

    inst:Remove()
end

local function fn_kit()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wagboss_robot")
    inst.AnimState:SetBuild("wagboss_robot")
    inst.AnimState:PlayAnimation("construction_kit")

    inst.pickupsound = "wood"

    MakeInventoryFloatable(inst, "med", 0.2, 0.75)

    inst:AddTag("deploykititem")
    inst:AddTag("usedeployspacingasoffset")

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
    inst.components.deployable.ondeploy = OnDeploy_kit

    return inst
end

-------------------------------------------
-- wagboss_robot_constructionsite_kit_placer

local function OnCanBuild(inst, mouse_blocked)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst:Show()
end

local function OnCannotBuild(inst, mouse_blocked)
    inst.AnimState:SetMultColour(.75, .25, .25, 1)
    inst:Show()
end
local function OnUpdateTransform_Placer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, TUNING.WAGBOSS_ROBOT_CONSTRUCTIONSITE_KIT_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS)

    if ents[1] then
        local ex, ey, ez = ents[1].Transform:GetWorldPosition()
        inst.Transform:SetPosition(ex, 0, ez)
    end
end
local function OverrideBuildPoint_Placer(inst)
    -- Gamepad defaults to this behavior, but mouse input normally takes
    -- mouse position over placer position, ignoring the placer snapping
    -- to a nearby location
    return inst:GetPosition()
end
local function PlacerPostinit(inst)
    inst.deployhelper_key = "wagboss_robot_constructionsite_kit"

    inst.components.placer.onupdatetransform = OnUpdateTransform_Placer
    inst.components.placer.override_build_point_fn = OverrideBuildPoint_Placer
end

-----------------------------------------------------------
-- wagboss_robot_constructionsite_placerindicator

local assets_placerindicator = {
    Asset("ANIM", "anim/wagboss_robot.zip"),
}

local function CreateFloorDecal()
    local inst = CreateEntity()

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    inst.AnimState:SetBank("wagboss_robot")
    inst.AnimState:SetBuild("wagboss_robot")
    inst.AnimState:PlayAnimation("construction_small")
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetMultColour(0.4, 0.5, 0.6, 0.6)
    inst.AnimState:SetSortOrder(-1)

    return inst
end

local function OnEnableHelper(inst, enabled, recipename, placerinst)
    if enabled then
        inst.helper = CreateFloorDecal()
        inst.helper.entity:SetParent(inst.entity)

        inst.helper.placerinst = placerinst
    elseif inst.helper ~= nil then
        inst.helper:Remove()
        inst.helper = nil
    end
end

local function fn_placerindicator()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("wagboss_robot_constructionsite_placerindicator")

    --Dedicated server does not need deployhelper
    if not TheNet:IsDedicated() then
        local deployhelper = inst:AddComponent("deployhelper")
        deployhelper:AddKeyFilter("wagboss_robot_constructionsite_kit")
        deployhelper.onenablehelper = OnEnableHelper
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

-----------------------------------------------------------
-- wagboss_robot_creation_parts

local assets_parts = {
    Asset("ANIM", "anim/wagboss_robot_creation_parts.zip"),
    Asset("INV_IMAGE", "wagboss_robot_creation_parts"),
}

local function fn_parts()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wagboss_robot_creation_parts")
    inst.AnimState:SetBuild("wagboss_robot_creation_parts")
    inst.AnimState:PlayAnimation("idle")

    inst.pickupsound = "metal"

    MakeInventoryFloatable(inst, "med", 0.2, 0.75)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -------------------------------------------------------
    inst:AddComponent("inspectable")

    -------------------------------------------------------
    inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    return inst
end

return Prefab("wagboss_robot_constructionsite", fn_constructionsite, assets_constructionsite, prefabs_constructionsite),
    Prefab("wagboss_robot_constructionsite_kit", fn_kit, assets_kit, prefabs_kit),
    MakePlacer("wagboss_robot_constructionsite_kit_placer", "wagboss_robot", "wagboss_robot", "construction_small", nil, nil, nil, nil, nil, nil, PlacerPostinit),
    Prefab("wagboss_robot_constructionsite_placerindicator", fn_placerindicator, assets_placerindicator),
    Prefab("wagboss_robot_creation_parts", fn_parts, assets_parts)