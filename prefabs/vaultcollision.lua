-- NOTES(JBK): These collision meshes are based off of the Vault_Vault and Vault_Lobby static layouts.
-- The coordinates are in normal units precalculated to go around the normal collision mesh generation between land and impassable.

local MESH_POINTS_VAULT = {
    {-23, 6},
    {-22, 7},
    {-20, 7},
    {-19, 8},
    {-19, 18},
    {-18, 19},
    {-8, 19},
    {-7, 20},
    {-7, 22},
    {-6, 23},
    {6, 23},
    {7, 22},
    {7, 20},
    {8, 19},
    {18, 19},
    {19, 18},
    {19, 8},
    {20, 7},
    {22, 7},
    {23, 6},
    {23, -6},
    {22, -7},
    {20, -7},
    {19, -8},
    {19, -18},
    {18, -19},
    {8, -19},
    {7, -20},
    {7, -22},
    {6, -23},
    {-6, -23},
    {-7, -22},
    {-7, -20},
    {-8, -19},
    {-18, -19},
    {-19, -18},
    {-19, -8},
    {-20, -7},
    {-22, -7},
    {-23, -6},
}
local MESH_POINTS_LOBBY = {
    {-15, 6},
    {-14, 7},
    {-12, 7},
    {-11, 8},
    {-11, 10},
    {-10, 11},
    {-8, 11},
    {-7, 12},
    {-7, 18},
    {-6, 19},
    {6, 19},
    {7, 18},
    {7, 12},
    {8, 11},
    {10, 11},
    {11, 10},
    {11, 8},
    {12, 7},
    {18, 7},
    {19, 6},
    {19, -6},
    {18, -7},
    {12, -7},
    {11, -8},
    {11, -10},
    {10, -11},
    {8, -11},
    {7, -12},
    {7, -14},
    {6, -15},
    {-6, -15},
    {-7, -14},
    {-7, -12},
    {-8, -11},
    {-10, -11},
    {-11, -10},
    {-11, -8},
    {-12, -7},
    {-14, -7},
    {-15, -6},
}
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
local function ApplyOffset(value, offset)
    if value < 0 then
        value = value - offset
    elseif value > 0 then
        value = value + offset
    end
    return value
end
local function BuildPhysicsMesh(points, offset)
    local triangles = {}
    local index_total = #points
    local v0 = points[index_total]
    local index = 1
    for index = 1, index_total do
        local v1 = points[index]
        local x0, z0 = v0[1], v0[2]
        local x1, z1 = v1[1], v1[2]
        if offset then
            x0 = ApplyOffset(x0, offset)
            z0 = ApplyOffset(z0, offset)
            x1 = ApplyOffset(x1, offset)
            z1 = ApplyOffset(z1, offset)
        end
        AddPlane(triangles, x0, 0, z0, x1, 10, z1)

        v0 = v1
    end
    return triangles
end

local function commonfn(points)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:SetCollisionMask(COLLISION.CHARACTERS)
    inst.Physics:SetTriangleMesh(BuildPhysicsMesh(points, 0.1))

    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("staysthroughvirtualrooms")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

local function lobbyfn()
    return commonfn(MESH_POINTS_LOBBY)
end

local function vaultfn()
    return commonfn(MESH_POINTS_VAULT)
end

return Prefab("vaultcollision_lobby", lobbyfn),
Prefab("vaultcollision_vault", vaultfn)
