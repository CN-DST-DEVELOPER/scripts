require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/staff_purple_base_ground.zip"),
	Asset("ANIM", "anim/vaultorbdestination.zip"), -- From vaultorbteleportdestination component.
    Asset("MINIMAP_IMAGE", "vaultorbdestination_icon"), -- From vaultorbteleportdestination component.
}

local prefabs =
{
    "gemsocket",
    "collapse_small",
    -- global icons from vaultorbteleportdestination component.
    "globalmapiconnoproxy",
    "globalmapicon",
    -- lootdropper from telebase_gemsocket.lua --don't need? otherwise, exclude from scrapbook?
    --"purplegem",
    --"vault_orb_refined",
}

local function AddVaultOrbRefinedActions(inst)
    if not inst.components.vaultorbteleportdestination then
        inst:AddComponent("vaultorbteleportdestination")
    end
end

local function RemoveVaultOrbRefinedActions(inst)
    if inst.components.vaultorbteleportdestination then
        inst:RemoveComponent("vaultorbteleportdestination")
    end
end

local function validteleporttarget(inst)
    for k, v in pairs(inst.components.objectspawner.objects) do
        if v.components.pickable ~= nil and not v.components.pickable.caninteractwith then
            return false
        end
    end
    return true
end

local function OnGemChange(inst)
    local requiredgem = nil
    for k, v in pairs(inst.components.objectspawner.objects) do
        if v.gemprefab then
            requiredgem = v.gemprefab
            break
        end
    end
    for k, v in pairs(inst.components.objectspawner.objects) do
        v.requiredgem = requiredgem
    end
    inst.gemtype = requiredgem
    if validteleporttarget(inst) then
        for k, v in pairs(inst.components.objectspawner.objects) do
            v.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        end
        if requiredgem == "vault_orb_refined" then
            AddVaultOrbRefinedActions(inst)
        end
    else
        for k, v in pairs(inst.components.objectspawner.objects) do
            v.AnimState:ClearBloomEffectHandle()
        end
        RemoveVaultOrbRefinedActions(inst)
    end
end

local function teleport_target(inst)
    for k, v in pairs(inst.components.objectspawner.objects) do
        if v.DestroyGemFn ~= nil then
            v.DestroyGemFn(v)
        end
    end
    OnGemChange(inst)
end

--------------------------------------------------------------------------

local TELEBASES = {}

--Global
function FindNearestActiveTelebase(x, y, z, range, minrange, prioritizetype)
    range = (range == nil and math.huge) or (range > 0 and range * range) or 0
    minrange = math.min(range, minrange ~= nil and minrange > 0 and minrange * minrange or 0)
    if minrange < range then
        local prioritymindistsq = math.huge
        local prioritynearest = nil
        local mindistsq = math.huge
        local nearest = nil
        for k, v in pairs(TELEBASES) do
            if validteleporttarget(k) then
                local distsq = k:GetDistanceSqToPoint(x, y, z)
                if prioritizetype and k.gemtype == prioritizetype then
                    if distsq < prioritymindistsq and distsq >= minrange and distsq < range then
                        prioritymindistsq = distsq
                        prioritynearest = k
                    end
                elseif distsq < mindistsq and distsq >= minrange and distsq < range then
                    mindistsq = distsq
                    nearest = k
                end
            end
        end
        return prioritynearest or nearest
    end
end

--------------------------------------------------------------------------

local function getstatus(inst)
    return validteleporttarget(inst) and "VALID" or "GEMS"
end

--V2C: Update recipe custom testfn if this ever changes
local telebase_parts =
{
    { part = "gemsocket", x = -1.6, z = -1.6 },
    { part = "gemsocket", x =  2.7, z = -0.8 },
    { part = "gemsocket", x = -0.8, z =  2.7 },
}

local function OnRemove(inst)
    for k, v in pairs(inst.components.objectspawner.objects) do
        v:Remove()
    end
    TELEBASES[inst] = nil
    RemoveVaultOrbRefinedActions(inst)
end

local function dropgems(inst)
    for k, v in pairs(inst.components.objectspawner.objects) do
        if v.components.pickable ~= nil and v.components.pickable.caninteractwith then
            inst.components.lootdropper:SpawnLootPrefab(v.gemprefab)
        end
    end
end

local function ondestroyed(inst)
	dropgems(inst)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst)
    for k, v in pairs(inst.components.objectspawner.objects) do
        if v.components.pickable ~= nil and v.components.pickable.caninteractwith then
            v.AnimState:PlayAnimation("hit_full")
            v.AnimState:PushAnimation("idle_full_loop")
        else
            v.AnimState:PlayAnimation("hit_empty")
            v.AnimState:PushAnimation("idle_empty")
        end
    end
end

local function NewObject(inst, obj)
    local function OnGemChangeProxy()
        OnGemChange(inst)
    end

    inst:ListenForEvent("trade", OnGemChangeProxy, obj)
    inst:ListenForEvent("picked", OnGemChangeProxy, obj)
    OnGemChange(inst)

    obj.proxy_destroy_entity = inst
end

local function RevealPart(v)
    v:Show()
    v.AnimState:PlayAnimation("place")
    v.AnimState:PushAnimation("idle_empty")
end

local function OnBuilt(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = (45 - inst.Transform:GetRotation()) * DEGREES
    local sin_rot = math.sin(rot)
    local cos_rot = math.cos(rot)
    for i, v in ipairs(telebase_parts) do
        local part = inst.components.objectspawner:SpawnObject(v.part, inst.linked_skinname, inst.skin_id)
        part.Transform:SetPosition(x + v.x * cos_rot - v.z * sin_rot, 0, z + v.z * cos_rot + v.x * sin_rot)
    end

    for k, v in pairs(inst.components.objectspawner.objects) do
        v:Hide()
        v:DoTaskInTime(math.random() * 0.5, RevealPart)
    end
end

local function createplacerpart()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("staff_purple_base")
    inst.AnimState:SetBuild("staff_purple_base")
    inst.AnimState:PlayAnimation("idle_empty")

    return inst
end

local function placerdecor(inst)
    local rot = 45 * DEGREES
    local sin_rot = math.sin(rot)
    local cos_rot = math.cos(rot)
    for i, v in ipairs(telebase_parts) do
        local part = createplacerpart()
        part.Transform:SetPosition(v.x * cos_rot - v.z * sin_rot, 0, v.z * cos_rot + v.x * sin_rot)
        part.entity:SetParent(inst.entity)
        inst.components.placer:LinkEntity(part)
    end
end

local function commonfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("telebase.png")

    inst:AddTag("telebase")

    inst.AnimState:SetBuild("staff_purple_base_ground")
    inst.AnimState:SetBank("staff_purple_base_ground")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    --inst.Transform:SetRotation(45)

    inst.scrapbook_anim = "scrapbook"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.scrapbook_speechstatus = "VALID"

    inst.onteleto = teleport_target
    inst.canteleto = validteleporttarget

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnWorkCallback(onhit)
    inst.components.workable:SetOnFinishCallback(ondestroyed)

    MakeHauntableWork(inst)

    inst:AddComponent("lootdropper")

    inst:AddComponent("objectspawner")
    inst.components.objectspawner.onnewobjectfn = NewObject

    inst:AddComponent("savedrotation")

    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("ondeconstructstructure", dropgems)

    inst:ListenForEvent("onremove", OnRemove)

    TELEBASES[inst] = true

    return inst
end

return Prefab("telebase", commonfn, assets, prefabs),
    MakePlacer("telebase_placer", "staff_purple_base_ground", "staff_purple_base_ground", "idle", true, nil, nil, nil, 90, nil, placerdecor)
