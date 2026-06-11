local assets = {
    Asset("ANIM", "anim/vault_decon_door.zip"),
}

-- idle_off to activate to idle_on to deactivated to idle_off

local function ExtendWall(inst, instantly)
    if inst.extended then
        return
    end
    inst.extended = true
    inst:RemoveTag("NOCLICK")

    if instantly or inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle", true)
    else
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.6)
        inst.AnimState:PlayAnimation("activate")
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function RetractWall(inst, instantly)
    if not inst.extended then
        return
    end
    inst.extended = false
    inst:AddTag("NOCLICK")

    if instantly or inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle_off", true)
    else
        inst.SoundEmitter:PlaySound("dontstarve/common/together/atrium/retract", nil, 0.6)
        inst.AnimState:PlayAnimation("deactivated")
        inst.AnimState:PushAnimation("idle_off", true)
    end
end

local function OnEntityReplicated(inst)
    local parent = inst.entity:GetParent()
    if parent ~= nil and parent.prefab == "vault_decon_door_collision" then
        inst.highlightchildren = parent.highlightchildren
        table.insert(parent.highlightchildren, inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank("vault_decon_door")
    inst.AnimState:SetBuild("vault_decon_door")
    inst.AnimState:PlayAnimation("idle_off", true)
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = OnEntityReplicated
        return inst
    end

    inst.scrapbook_anim = "scrapbook"

    inst.persists = false -- This is a visual.

    inst:AddComponent("inspectable")

    inst.extended = false
    inst.ExtendWall = ExtendWall
    inst.RetractWall = RetractWall

    return inst
end

---------------------------------------------------
local function AddPlane(triangles, x0, y0, z0, x1, y1, z1)
    table.insert(triangles, x0)
    table.insert(triangles, y0)
    table.insert(triangles, z0)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x1)
    table.insert(triangles, y0)
    table.insert(triangles, z1)

    table.insert(triangles, x0)
    table.insert(triangles, y1)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, y1)
    table.insert(triangles, z1)
end
local HORIZONTAL_WALL_MESH = {}
AddPlane(HORIZONTAL_WALL_MESH, -3, 0, 0, 3, 2, 0)


local function SetClosedPhysics(inst)
    inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
    inst.Physics:SetCollisionMask(
        COLLISION.WORLD,
        COLLISION.ITEMS,
        COLLISION.CHARACTERS,
        COLLISION.GIANTS
    )
end

local function SetOpenedPhysics(inst)
    inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
    inst.Physics:SetCollisionMask(
        COLLISION.WORLD,
        COLLISION.ITEMS
    )
end

local function TryToExtendWall(inst, name, instantly)
    local dooranim = inst.walls[name]
    if dooranim then
        dooranim:ExtendWall(instantly)
    end
end
local function ExtendWall_Collision_part4(inst)
    inst.extendretracttask = nil
    SetClosedPhysics(inst)
end
local function ExtendWall_Collision_part3(inst)
    inst.extendretracttask = inst:DoTaskInTime(0.2, ExtendWall_Collision_part4)
    TryToExtendWall(inst, "dooranim3")
    TryToExtendWall(inst, "dooranim4")
end
local function ExtendWall_Collision_part2(inst)
    inst.extendretracttask = inst:DoTaskInTime(0.1, ExtendWall_Collision_part3)
    TryToExtendWall(inst, "dooranim2")
    TryToExtendWall(inst, "dooranim5")
end
local function ExtendWall_Collision(inst, instantly)
    if inst.extended then
        return
    end
    inst.extended = true
    if inst.extendretracttask then
        inst.extendretracttask:Cancel()
        inst.extendretracttask = nil
    end

    if instantly then
        TryToExtendWall(inst, "dooranim1", true)
        TryToExtendWall(inst, "dooranim2", true)
        TryToExtendWall(inst, "dooranim3", true)
        TryToExtendWall(inst, "dooranim4", true)
        TryToExtendWall(inst, "dooranim5", true)
        TryToExtendWall(inst, "dooranim6", true)
        SetClosedPhysics(inst)
    else
        TryToExtendWall(inst, "dooranim1")
        TryToExtendWall(inst, "dooranim6")
        inst.extendretracttask = inst:DoTaskInTime(0.1, ExtendWall_Collision_part2)
    end
end

local function TryToRetractWall(inst, name, instantly)
    local dooranim = inst.walls[name]
    if dooranim then
        dooranim:RetractWall(instantly)
    end
end
local function RetractWall_Collision_part4(inst)
    inst.extendretracttask = nil
    SetOpenedPhysics(inst)
end
local function RetractWall_Collision_part3(inst)
    inst.extendretracttask = inst:DoTaskInTime(0.2, RetractWall_Collision_part4)
    TryToRetractWall(inst, "dooranim3")
    TryToRetractWall(inst, "dooranim4")
end
local function RetractWall_Collision_part2(inst)
    inst.extendretracttask = inst:DoTaskInTime(0.1, RetractWall_Collision_part3)
    TryToRetractWall(inst, "dooranim2")
    TryToRetractWall(inst, "dooranim5")
end
local function RetractWall_Collision(inst, instantly)
    if not inst.extended then
        return
    end
    inst.extended = false
    if inst.extendretracttask then
        inst.extendretracttask:Cancel()
        inst.extendretracttask = nil
    end

    if instantly then
        TryToRetractWall(inst, "dooranim1", true)
        TryToRetractWall(inst, "dooranim2", true)
        TryToRetractWall(inst, "dooranim3", true)
        TryToRetractWall(inst, "dooranim4", true)
        TryToRetractWall(inst, "dooranim5", true)
        TryToRetractWall(inst, "dooranim6", true)
        SetOpenedPhysics(inst)
    else
        TryToRetractWall(inst, "dooranim1")
        TryToRetractWall(inst, "dooranim6")
        inst.extendretracttask = inst:DoTaskInTime(0.1, RetractWall_Collision_part2)
    end
end

local function AddDoorAnimIfMissing(inst, name, offsetx)
    local dooranim = inst.walls[name]
    if not dooranim then
        dooranim = SpawnPrefab("vault_decon_door")
        inst.walls[name] = dooranim
        dooranim:ListenForEvent("onremove", function(dooranim)
            inst.walls[name] = nil
            table.removearrayvalue(inst.highlightchildren, dooranim)
        end)
        table.insert(inst.highlightchildren, dooranim)
        dooranim.highlightchildren = inst.highlightchildren
        dooranim.entity:SetParent(inst.entity)
        dooranim.Transform:SetPosition(offsetx, 0, 0)
    end
end
local function CreateWalls(inst)
    AddDoorAnimIfMissing(inst, "dooranim1", -3)
    AddDoorAnimIfMissing(inst, "dooranim2", -1.8)
    AddDoorAnimIfMissing(inst, "dooranim3", -0.6)
    AddDoorAnimIfMissing(inst, "dooranim4", 0.6)
    AddDoorAnimIfMissing(inst, "dooranim5", 1.8)
    AddDoorAnimIfMissing(inst, "dooranim6", 3)
end

local function fn_collision()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    SetOpenedPhysics(inst)
    inst.Physics:SetTriangleMesh(HORIZONTAL_WALL_MESH) -- NOTES(JBK): Physics does not rotate to clients so this entity is special and aligned for horizontal walls only to the world!

    inst:AddTag("NOCLICK")
    inst.highlightchildren = {}

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.walls = {}

    inst.extended = false
    inst.ExtendWall = ExtendWall_Collision
    inst.RetractWall = RetractWall_Collision
    inst.CreateWalls = CreateWalls
    inst:CreateWalls()

    return inst
end

return Prefab("vault_decon_door", fn, assets), -- This is created by vault_decon_door_collision for visuals.
    Prefab("vault_decon_door_collision", fn_collision)