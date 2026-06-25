local assets = {
	Asset("ANIM", "anim/carnivalgame_golf_shape.zip"),
    Asset("SCRIPT", "scripts/prefabs/carnivalgame_golf_meshdata.lua"),
}
local prefabs = {
    "collapse_small",
}
local SHAPE_MESHES = require("prefabs/carnivalgame_golf_meshdata").SHAPE_MESHES

local GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE = 90 -- NOTES(JBK): Keep in sync with recipes.lua [GSPNA]

--like fwd slash /
local function _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	local dx = scrnx - myscrnx
	local dz = scrnz - myscrnz
	return dx > -dz and 1 or -1
end

--like back slash \
local function _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	local dx = scrnx - myscrnx
	local dz = scrnz - myscrnz
	return dx < dz and 1 or -1
end

local function GolfSortDiagCurve(inst, scrnx, scrnz, myscrnx, myscrnz)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_DOWN or facing == FACING_UP then
		return _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_RIGHT or facing == FACING_LEFT then
		return _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_DOWNRIGHT then
		if scrnx < myscrnx then
			return scrnz > myscrnz and -1 or 1
		end
	elseif facing == FACING_UPLEFT then
		if scrnx > myscrnx then
			return scrnz > myscrnz and -1 or 1
		end
	end
end

local function GolfSortStraightCurveV(inst, scrnx, scrnz, myscrnx, myscrnz)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_RIGHT or facing == FACING_LEFT then
		return scrnx < myscrnx and 1 or -1
	elseif facing == FACING_DOWNRIGHT or facing == FACING_UPLEFT then
		return _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_UPRIGHT or facing == FACING_DOWNLEFT then
		return _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	end
end

local function GolfSortStraightCurveH(inst, scrnx, scrnz, myscrnx, myscrnz)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_UP or facing == FACING_DOWN then
		return scrnx > myscrnx and 1 or -1
	elseif facing == FACING_DOWNRIGHT or facing == FACING_UPLEFT then
		return _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_UPRIGHT or facing == FACING_DOWNLEFT then
		return _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	end
end

local function GolfSortLineV(inst, scrnx, scrnz, myscrnx, myscrnz)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_UPLEFT or facing == FACING_DOWNRIGHT then
		return _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_DOWNLEFT or facing == FACING_UPRIGHT then
		return _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	end
end

local function GolfSortDiagonal(inst, scrnx, scrnz, myscrnx, myscrnz)
	local facing = inst.AnimState:GetCurrentFacing()
	if facing == FACING_UP or facing == FACING_DOWN then
		return _GolfSortDiagUR(scrnx, scrnz, myscrnx, myscrnz)
	elseif facing == FACING_LEFT or facing == FACING_RIGHT then
		return _GolfSortDiagDR(scrnx, scrnz, myscrnx, myscrnz)
	end
end

local function CreateConnector()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("golf_shape_connector")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()

	return inst
end

local GOLF_SHAPES = {
    {
        name = "curve1x1",
		placer = "curve1x1",
		placerangle = 135,
		anims =
		{
			{ anim = "curve1x1", row = 0, col = 0, sort_x = 0.0833, sort_z = 0.0833, golfsortfn = GolfSortDiagCurve },
		},
		connectors =
		{
			{ x = 0.5, z = -0.5, dir = 90 },
			{ x = -0.5, z = 0.5, dir = 180 },
		},
    },
    {
        name = "curve1x2",
		placer = "placercurve1x2",
		placerangle = 135,
		anims =
		{
			{ anim = "curve1x2b", row = 0, col = 0, sort_x = 0.43, sort_z = 0, golfsortfn = GolfSortStraightCurveV },
			{ anim = "curve1x2a", row = 1, col = 0, sort_x = -0.13, sort_z = 0.237, golfsortfn = GolfSortDiagCurve },
		},
		connectors =
		{
			{ x = 0.5, z = -0.5, dir = 90 },
			{ x = -0.5, z = 1.5, dir = 180 },
		},
    },
    {
        name = "curve2x1",
		placer = "placercurve2x1",
		placerangle = 225,
		anims =
		{
			{ anim = "curve2x1b", row = 0, col = 0, sort_x = 0, sort_z = 0.43, golfsortfn = GolfSortStraightCurveH },
			{ anim = "curve2x1a", row = 0, col = 1, sort_x = 0.237, sort_z = -0.13, golfsortfn = GolfSortDiagCurve },
		},
		connectors =
		{
			{ x = 1.5, z = -0.5, dir = 90 },
			{ x = -0.5, z = 0.5, dir = 180 },
		},
    },
    {
        name = "curve2x2",
		placer = "placercurve2x2",
		placerangle = 135,
		anims =
		{
			{ anim = "curve2x2a", row = 0, col = 1, sort_x = 0.36, sort_z = 0, golfsortfn = GolfSortStraightCurveV },
			{ anim = "curve2x2b", row = 1, col = 1, sort_x = -0.1, sort_z = -0.1, golfsortfn = GolfSortDiagCurve },
			{ anim = "curve2x2c", row = 1, col = 0, sort_x = 0, sort_z = 0.36, golfsortfn = GolfSortStraightCurveH },
		},
		connectors =
		{
			{ x = 1.5, z = -0.5, dir = 90 },
			{ x = -0.5, z = 1.5, dir = 180 },
		},
    },
	{
		name = "line1x1",
		placer = "placerline1x1",
		placerangle = 135,
		anims =
		{
			{ anim = "line1x1", row = 0, col = 0.5, golfsortfn = GolfSortLineV },
		},
		connectors =
		{
			{ x = 0.5, z = -0.5, dir = 90 },
			{ x = 0.5, z = 0.5, dir = -90 },
		},
	},
	{
		name = "diagonal1x1",
		placer = "diagonal1x1",
		placerangle = 135,
		anims =
		{
			{ anim = "diagonal1x1", row = 0, col = 0, sort_x = 0.075, sort_z = 0.075, golfsortfn = GolfSortDiagonal },
		},
		connectors =
		{
			{ x = 0.5, z = -0.5, dir = 90 },
			{ x = -0.5, z = 0.5, dir = 180 },
		},
	},
}

local function RotatePoints_Mesh(points, angle)
    -- Rotates and returns the triangle mesh.
    local triangles = {}
    for _, point in ipairs(points) do
        local x, y, z = point[1], point[2], point[3]
        if angle == 90 then
            table.insert(triangles, -z)
            table.insert(triangles, y)
            table.insert(triangles, x)
        elseif angle == 180 then
            table.insert(triangles, -x)
            table.insert(triangles, y)
            table.insert(triangles, -z)
        elseif angle == 270 then
            table.insert(triangles, z)
            table.insert(triangles, y)
            table.insert(triangles, -x)
        else
            table.insert(triangles, x)
            table.insert(triangles, y)
            table.insert(triangles, z)
        end
    end
    return triangles
end

local function CreateGolfPhysics_Internal(shapedata, angle)
    local angle_nearest_angle = math.floor((angle / GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE) + 0.5) * GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE

    local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()

    local phys = inst.entity:AddPhysics()
    phys:SetMass(0)
    phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
    phys:SetCollisionMask(
        COLLISION.ITEMS,
        COLLISION.WORLD
    )
    local mesh = SHAPE_MESHES[shapedata.name]
    local rotated_mesh = RotatePoints_Mesh(mesh, angle_nearest_angle)
    phys:SetTriangleMesh(rotated_mesh)

    return inst
end

local function CreateGolfPhysics_Common(inst)
    local angle_transform = inst.Transform:GetRotation()
    local angle_worldspace = ReduceAngle(-angle_transform)
    if angle_worldspace < 0 then
        angle_worldspace = angle_worldspace + 360
    end
    local golfphysics = CreateGolfPhysics_Internal(inst.shapedata, angle_worldspace)
    local x, y, z = inst.Transform:GetWorldPosition()
    golfphysics.Transform:SetPosition(x, y, z)
    return golfphysics
end

local function RemoveGolfPhysics_Common(inst)
    if inst.golfphysics then
        if inst.golfphysics:IsValid() then
            inst.golfphysics:Remove()
        end
        inst.golfphysics = nil
    end
end

local function OnEntitySleep_Common(inst)
    inst:RemoveGolfPhysics_Common()
end

local function OnEntityWake_Common(inst)
    if not inst.golfphysics then
        inst.golfphysics = inst:CreateGolfPhysics_Common()
    end
end

local function OnBuilt(inst, data)
    local angle = inst.Transform:GetRotation()
    local angle_nearest_angle = math.floor((angle / GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE) + 0.5) * GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE
    inst.Transform:SetRotation(angle)
end

local function OnEntityWake_SetupSorting(inst)
	inst:RemoveEventCallback("entitywake", OnEntityWake_SetupSorting)
	local theta = -(inst.entity:GetParent() or inst).Transform:GetRotation() * DEGREES
	local costheta = math.cos(theta)
	local sintheta = math.sin(theta)

	inst.sortoffs = Vector3(
		inst._sort_x * costheta - inst._sort_z * sintheta,
		0,
		inst._sort_x * sintheta + inst._sort_z * costheta)

	inst.AnimState:SetSortWorldOffset(inst.sortoffs:Get())
	inst._sort_x, inst._sort_z = nil

	--[[local x, y, z = inst.Transform:GetWorldPosition()
	local flint = SpawnPrefab("flint")
	local len = 1 --+ 0.4 / math.sqrt(offsx * offsx + offsz * offsz)
	flint.Transform:SetPosition(x + len * offsx, 0, z + len * offsz)
	flint.persists = false
	flint.Transform:SetScale(0.25, 0.25, 0.25)
	flint.Physics:SetActive(false)]]
end

local function SetupAnim(inst, animdata)
	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddAnimState()

	inst.Transform:SetEightFaced()

	inst:AddTag("golfshape")
	inst:AddTag("blocker")

	inst.AnimState:SetBank("carnivalgame_golf_shape")
	inst.AnimState:SetBuild("carnivalgame_golf_shape")
	inst.AnimState:PlayAnimation(animdata.anim)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

	inst:SetDeploySmartRadius(0.5)

	if animdata.sort_x then
		inst._sort_x = animdata.sort_x
		inst._sort_z = animdata.sort_z
		inst:ListenForEvent("entitywake", OnEntityWake_SetupSorting)
	end
	inst.golfsortfn = animdata.golfsortfn
end

local function CreateAnimPiece(animdata)
	local inst = CreateEntity()

	inst.entity:AddTransform()

	SetupAnim(inst, animdata)

	--inst:AddTag("FX") --can't use this or blocker won't work
	inst:AddTag("childdeployblocker") -- Permit this to be parented and also block.
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	return inst
end

local function OnHammered(inst, worker)
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function MakeGolfShape(name, data, _assets)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

		inst.shapedata = data

		for _, v in ipairs(data.anims) do
			if v.row == 0 and v.col == 0 then
				SetupAnim(inst, v)
			else
				local piece = CreateAnimPiece(v)
				piece.entity:SetParent(inst.entity)
				piece.Transform:SetPosition(v.col, 0, v.row)
				piece.client_forward_target = inst --since we can't use FX tag
				inst.highlightchildren = inst.highlightchildren or {}
				table.insert(inst.highlightchildren, piece)
			end
		end

			inst.connectors = {}
		if data.connectors then
			for _, v in ipairs(data.connectors) do
				local connector = CreateConnector()
				connector.entity:SetParent(inst.entity)
				connector.Transform:SetPosition(v.x, 0, v.z)
				connector.Transform:SetRotation(v.dir)
				table.insert(inst.connectors, connector)
			end
		end

		if inst.AnimState == nil then
			inst:AddTag("NOBLOCK")
		end

		inst:SetPrefabNameOverride("carnivalgame_golf_shape")

        inst.entity:SetPristine()

        inst.RemoveGolfPhysics_Common = RemoveGolfPhysics_Common
        inst.CreateGolfPhysics_Common = CreateGolfPhysics_Common
        inst.OnEntitySleep = OnEntitySleep_Common
        inst.OnEntityWake = OnEntityWake_Common
        inst:ListenForEvent("onremove", inst.RemoveGolfPhysics_Common)

        if not TheWorld.ismastersim then
            return inst
        end

		inst:AddComponent("savedrotation")

        inst:ListenForEvent("onbuilt", OnBuilt)

        local workable = inst:AddComponent("workable")
        workable:SetWorkAction(ACTIONS.HAMMER)
        workable:SetWorkLeft(1)
        workable:SetOnFinishCallback(OnHammered)

        return inst
    end

    return Prefab(name, fn, _assets)
end

-- Search strings:
--[[
carnivalgame_golf_shape_curve1x1
carnivalgame_golf_shape_curve1x2
carnivalgame_golf_shape_curve2x1
carnivalgame_golf_shape_curve2x2
carnivalgame_golf_shape_line1x1
carnivalgame_golf_shape_diagonal1x1
carnivalgame_golf_shape_curve1x1_placer
carnivalgame_golf_shape_curve1x2_placer
carnivalgame_golf_shape_curve2x1_placer
carnivalgame_golf_shape_curve2x2_placer
carnivalgame_golf_shape_line1x1_placer
carnivalgame_golf_shape_diagonal1x1_placer
--]]

local allshapeprefabs = {}
for _, data in ipairs(GOLF_SHAPES) do
	local prefabname = string.format("carnivalgame_golf_shape_%s", data.name)
    table.insert(allshapeprefabs, MakeGolfShape(prefabname, data, assets, prefabs))
	table.insert(allshapeprefabs, MakePlacer(prefabname.."_placer", "carnivalgame_golf_shape", "carnivalgame_golf_shape", data.placer, true, true, nil, nil, { offset = data.placerangle, nearestangle = GOLF_SHAPE_PLACEMENT_NEAREST_ANGLE }, "eight"))
end

return unpack(allshapeprefabs)
