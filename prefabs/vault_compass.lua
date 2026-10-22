local assets =
{
    Asset("ANIM", "anim/vault_compass.zip"),
}

local prefabs =
{
    "vault_compass_marker",
    "vault_compass_visual",
}

local CLOSE_TO_ROPE_DIST_SQ = 2.5 * 2.5
local KEY_ROOM_ID = "key1"

local function ChangeToAnim(inst, animname)
    if not inst.marker_pointer.AnimState:IsCurrentAnimation(animname) then
        inst.marker_pointer.AnimState:PlayAnimation(animname, true)
    end
end

local function OnUpdateDirection(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local world = TheWorld
    local map = world.Map
    if map:IsPointInVirtualRoomSet(VIRTUALROOMSETS.VAULT, x, y, z) then
        local virtualroomset = world.components.virtualroommanager:GetVirtualRoomSet(VIRTUALROOMSETS.VAULT)
        local roomname = virtualroomset:GetCurrentRoomName()
        local direction = virtualroomset:GetClosestDirectionFromRoomToRoom(roomname, KEY_ROOM_ID)
        if roomname == KEY_ROOM_ID then
            ChangeToAnim(inst, "idle_marker_success")
        elseif direction then
            local marker
            local teleporters = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.TELEPORTER)
            if teleporters then
                for _, teleporter in ipairs(teleporters) do
                    if teleporter.components.virtualroomteleporter:GetDirection() == direction then
                        marker = teleporter
                        break
                    end
                end
            end

            if marker then
                ChangeToAnim(inst, "idle_marker")
                inst.marker_pointer:FacePoint(marker.Transform:GetWorldPosition())
            else
                ChangeToAnim(inst, "idle_marker_fail")
            end
        end
    elseif map:IsPointInVirtualRoomSet(VIRTUALROOMSETS.LOBBYVAULT, x, y, z) then
        local virtualroomset = world.components.virtualroommanager:GetVirtualRoomSet(VIRTUALROOMSETS.LOBBYVAULT)
        local markers = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.MARKER)
        local marker = FindFirstPrefabInArray(markers, "vaultmarker_lobby_to_vault")
        if marker then
            ChangeToAnim(inst, "idle_marker")
            inst.marker_pointer:FacePoint(marker.Transform:GetWorldPosition())
        else
            ChangeToAnim(inst, "idle_marker_fail")
        end
    else
        local marker
        if world.components.virtualroommanager then
            local virtualroomset = world.components.virtualroommanager:GetVirtualRoomSet(VIRTUALROOMSETS.LOBBYVAULT)
            if virtualroomset then
                local markers = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.MARKER)
                marker = FindFirstPrefabInArray(markers, "archive_portal")
            end
        end
        if marker then
            if inst:GetDistanceSqToInst(marker) < CLOSE_TO_ROPE_DIST_SQ then
                ChangeToAnim(inst, "idle_marker_success")
            else
                ChangeToAnim(inst, "idle_marker")
                inst.marker_pointer:FacePoint(marker.Transform:GetWorldPosition())
            end
        else
            ChangeToAnim(inst, "idle_marker_fail")
        end
    end
end

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "vault_compass", "swap_compass")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst.marker == nil then
        inst.marker = SpawnPrefab("vault_compass_marker")
        inst.marker.entity:SetParent(owner.entity)
        -- inst.marker.Network:SetClassifiedTarget(owner)

        inst.marker_pointer = SpawnPrefab("vault_compass_visual")
        inst.marker_pointer.Follower:FollowSymbol(inst.marker.GUID, "empty", 0, 0, 0)

        inst.update_direction_task = inst:DoPeriodicTask(0, OnUpdateDirection)
        if not POPULATING then
            OnUpdateDirection(inst)
        end
    end
end

local function ClearMarker(inst)
    if inst.marker ~= nil then
        inst.update_direction_task:Cancel()
        inst.marker:Remove()
        inst.marker_pointer:Remove()
        inst.update_direction_task = nil
        inst.marker = nil
        inst.marker_pointer = nil
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    ClearMarker(inst)
end

local function OnEquipToModel(inst, owner, from_ground)
    ClearMarker(inst)
end

local function GetStatus(inst, viewer)
    local x, y, z = inst.Transform:GetWorldPosition()
    local world = TheWorld
    local map = world.Map
    if map:IsPointInVirtualRoomSet(VIRTUALROOMSETS.VAULT, x, y, z) then
        local virtualroomset = world.components.virtualroommanager:GetVirtualRoomSet(VIRTUALROOMSETS.VAULT)
        if virtualroomset:GetCurrentRoomName() == KEY_ROOM_ID then
            return "KEYROOM"
        end
        return nil
    elseif map:IsPointInVirtualRoomSet(VIRTUALROOMSETS.LOBBYVAULT, x, y, z) then
        return nil
    end

    return "NOTVAULT"
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("vault_compass")
    inst.AnimState:SetBuild("vault_compass")
    inst.AnimState:PlayAnimation("idle", true)

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")
    --furnituredecor (from furnituredecor component) added to pristine state for optimization
    inst:AddTag("furnituredecor")

    MakeInventoryFloatable(inst, "med", 0.1, 0.6)

    inst.scrapbook_subcat = "tool"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")
    inst:AddComponent("furnituredecor")

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(OnEquipToModel)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.UNARMED_DAMAGE)

    MakeHauntableLaunch(inst)

    return inst
end

----------------------------------------------

local function markerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("vault_compass")
    inst.AnimState:SetBuild("vault_compass")
    inst.AnimState:PlayAnimation("empty")

    inst:AddTag("staysthroughvirtualrooms")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

----------------------------------------------

local function visualpointerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("vault_compass")
    inst.AnimState:SetBuild("vault_compass")
    inst.AnimState:PlayAnimation("idle_marker", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst:AddTag("staysthroughvirtualrooms")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

----------------------------------------------

return Prefab("vault_compass", fn, assets, prefabs),
    Prefab("vault_compass_marker", markerfn, assets),
    Prefab("vault_compass_visual", visualpointerfn, assets)