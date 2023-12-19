local assets = {
    Asset("ANIM", "anim/icefishing_hole.zip"),
}

local function build_hole_collision_mesh(radius, height, segment_count)
    local triangles = {}
    local y0 = 0
    local y1 = height

    local segment_span = math.pi * 2 / segment_count
    for segment_idx = 0, segment_count do

        local angle = segment_idx * segment_span
        local angle0 = angle - segment_span / 2
        local angle1 = angle + segment_span / 2

        local x0 = math.cos(angle0) * radius
        local z0 = math.sin(angle0) * radius

        local x1 = math.cos(angle1) * radius
        local z1 = math.sin(angle1) * radius

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

	return triangles
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(0)
    inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.ITEMS)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:CollidesWith(COLLISION.GIANTS)
    inst.Physics:SetTriangleMesh(build_hole_collision_mesh(1.7, 6, 16))

    inst.Transform:SetRotation(90)

    inst.AnimState:SetBuild("icefishing_hole")
    inst.AnimState:SetBank("icefishing_hole")
    inst.AnimState:PlayAnimation("working", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    --inst.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
    inst.AnimState:SetSortOrder(3)

    inst.MiniMapEntity:SetIcon("icefishing_hole.png")

    inst:AddTag("pond")
    inst:AddTag("antlion_sinkhole_blocker")
    inst:AddTag("birdblocker")

    inst:AddTag("NOCLICK")
    inst:AddTag("virtualocean")
    inst:AddTag("oceanfishingfocus")

    inst:AddTag("groundhole")
    inst:AddTag("ignorewalkableplatforms") -- Just in case.

    inst:SetDeployExtraSpacing(2)


    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

return Prefab( "icefishing_hole", fn, assets)
