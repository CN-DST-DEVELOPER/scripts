local GOLF_SHAPE_HEIGHT = 0.8
local GOLF_SHAPE_POINTYTOP_HEIGHT = 0.1

local GOLF_SQUARE_SHAPE = {
    {-0.5, -0.5},
    {0.5, -0.5},
    {0.5, 0.5},
    {-0.5, 0.5},
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

local function AddSquarePyramid(triangles, x0, z0, x1, z1, x2, z2, x3, z3, baseheight, pointheight)
    local midx, midz = (x0 + x1 + x2 + x3) / 4,  (z0 + z1 + z2 + z3) / 4
    local totalheight = baseheight + pointheight

    -- Triangle 1
    table.insert(triangles, x0)
    table.insert(triangles, baseheight)
    table.insert(triangles, z0)

    table.insert(triangles, x1)
    table.insert(triangles, baseheight)
    table.insert(triangles, z1)

    table.insert(triangles, midx)
    table.insert(triangles, totalheight)
    table.insert(triangles, midz)

    -- Triangle 2
    table.insert(triangles, x1)
    table.insert(triangles, baseheight)
    table.insert(triangles, z1)

    table.insert(triangles, x2)
    table.insert(triangles, baseheight)
    table.insert(triangles, z2)

    table.insert(triangles, midx)
    table.insert(triangles, totalheight)
    table.insert(triangles, midz)

    -- Triangle 3
    table.insert(triangles, x2)
    table.insert(triangles, baseheight)
    table.insert(triangles, z2)

    table.insert(triangles, x3)
    table.insert(triangles, baseheight)
    table.insert(triangles, z3)

    table.insert(triangles, midx)
    table.insert(triangles, totalheight)
    table.insert(triangles, midz)

    -- Triangle 4
    table.insert(triangles, x3)
    table.insert(triangles, baseheight)
    table.insert(triangles, z3)

    table.insert(triangles, x0)
    table.insert(triangles, baseheight)
    table.insert(triangles, z0)

    table.insert(triangles, midx)
    table.insert(triangles, totalheight)
    table.insert(triangles, midz)
end

local function BuildGolfSquareShapeMesh(points)
    -- Vertical walls.
    local triangles = {}
    local index_total = #points
    local v0 = points[index_total]
    for index = 1, index_total do
        local v1 = points[index]
        local x0, z0 = v0[1], v0[2]
        local x1, z1 = v1[1], v1[2]
        AddPlane(triangles, x0, 0, z0, x1, GOLF_SHAPE_HEIGHT, z1)

        v0 = v1
    end

    do -- Scope block.
        -- Add a pointy top to it.
        local v0 = points[1]
        local v1 = points[2]
        local v2 = points[3]
        local v3 = points[4]
        local x0, z0 = v0[1], v0[2]
        local x1, z1 = v1[1], v1[2]
        local x2, z2 = v2[1], v2[2]
        local x3, z3 = v3[1], v3[2]
        AddSquarePyramid(triangles, x0, z0, x1, z1, x2, z2, x3, z3, GOLF_SHAPE_HEIGHT, GOLF_SHAPE_POINTYTOP_HEIGHT)
    end

    return triangles
end



local function OnHammered(inst, worker)
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function OnBuilt(inst)
    if inst.placeanim then
        inst.AnimState:PlayAnimation(inst.placeanim)
        inst.AnimState:PushAnimation(inst.idleanim, false)
    end
    if inst.placesound then
        inst.SoundEmitter:PlaySound(inst.placesound)
    end
end

local function MakeGolfProp(name, data)
    local OnActivateGame = data.OnActivateGame or nil
    local OnStartPlaying = data.OnStartPlaying or nil
    local OnUpdateGame = data.OnUpdateGame or nil
    local OnStopPlaying = data.OnStopPlaying or nil
    local SpawnRewards = data.SpawnRewards or nil
    local OnDeactivateGame = data.OnDeactivateGame or nil

    local assets =
    {
        Asset("ANIM", "anim/"..data.build..".zip"),
    }
    if data.bank ~= data.build then
        table.insert(assets, Asset("ANIM", "anim/"..data.bank..".zip"))
    end
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        if data.phys_rad then
            MakeGolfObstaclePhysics(inst, data.phys_rad)
        end

        if data.deploy_smart_radius then
            inst:SetDeploySmartRadius(data.deploy_smart_radius)
        end

        inst.AnimState:SetBank(data.bank)
        inst.AnimState:SetBuild(data.build)
        inst.AnimState:PlayAnimation(data.idleanim)
        if data.ground_plane then
	        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	        inst.AnimState:SetLayer(LAYER_BACKGROUND)
	        inst.AnimState:SetSortOrder(-1)
        end

        if data.common_postinit then
            data.common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        if not data.no_workable then
	        inst:AddComponent("workable")
	        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	        inst.components.workable:SetWorkLeft(1)
	        inst.components.workable:SetOnFinishCallback(OnHammered)
        end

        inst.placeanim = data.placeanim or nil
        inst.idleanim = data.idleanim
        inst.placesound = data.placesound or "summerevent/decor/place"

        -- called by carnivalgame_golfgame
        inst.OnActivateGame = OnActivateGame
	    inst.OnStartPlaying = OnStartPlaying
	    inst.OnUpdateGame = OnUpdateGame
	    inst.OnStopPlaying = OnStopPlaying
	    inst.SpawnRewards = SpawnRewards
	    inst.OnDeactivateGame = OnDeactivateGame

        inst:ListenForEvent("onbuilt", OnBuilt)

        if data.master_postinit then
            data.master_postinit(inst)
        end

        return inst
    end

	return Prefab(name, fn, assets)
end

------------------------------------------------------

local defs = {
    {
        -- kind of a 'fake' fence
        name = "carnivalgame_golfprop_fence",
        bank = "fence_thin_carnival_golf",
        build = "fence_carnival_golf",
        placeanim = "place",
        idleanim = "idle",
        deploy_smart_radius = 0.5,
        no_workable = true,
        common_postinit = function(inst)
            inst.Transform:SetEightFaced()
        end,
        master_postinit = function(inst)
            inst:AddComponent("savedrotation")
        end,
    },
    {
        -- kind of a 'fake' wall
        name = "carnivalgame_golfprop_wallcorner",
        bank = "carnivalgame_golfprop_wallcorner",
        build = "carnivalgame_golfprop_wallcorner",
        placeanim = "place",
        idleanim = "idle",
        deploy_smart_radius = 0.5,
        no_workable = true,
        common_postinit = function(inst)
            inst:SetPrefabNameOverride("carnivalgame_golfprop_fence")
            inst.Transform:SetEightFaced()
        end,
        master_postinit = function(inst)
            inst:AddComponent("savedrotation")
        end,
    }
}

-- spin plates
-- we could scale spin strength according to animation, but it's really not necessacary
local function spinplate_OnActivate(inst)
    inst.AnimState:PlayAnimation(inst.plate_size.."_"..inst.plate_suffix.."_pre")
    inst.AnimState:PushAnimation(inst.plate_size.."_"..inst.plate_suffix.."_loop", true)
    inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/spinning_plate_LP", "spin_lp")
    inst.components.golfballspinner:SetEnabled(true)
end

local function spinplate_OnStopPlayingOrDeactivate(inst)
    if inst.components.golfballspinner.enabled then
        inst.SoundEmitter:KillSound("spin_lp")
        if inst:IsAsleep() then
            inst.AnimState:PlayAnimation(inst.plate_size.."_"..inst.plate_suffix.."_idle")
        else
            inst.AnimState:PushAnimation(inst.plate_size.."_"..inst.plate_suffix.."_pst", false)
            inst.AnimState:PushAnimation(inst.plate_size.."_"..inst.plate_suffix.."_idle", false)
        end
        inst.components.golfballspinner:SetEnabled(false)
    end
end

local spinplate_sizes = {
    -- { size, radius }
    { "small",  1 },
    { "medium", 5 / 3 }, -- 1.667
}
for i, data in ipairs(spinplate_sizes) do
    local size, radius = data[1], data[2]
    table.insert(defs, {
        name = "carnivalgame_golfprop_"..size.."spinner_cw",
        bank = "carnivalgame_golf_spinplate",
        build = "carnivalgame_golf_spinplate",
        idleanim = size.."_clockwise_idle",
        placeanim = size.."_clockwise_place",
        ground_plane = true,
        deploy_smart_radius = radius,
        OnActivateGame = spinplate_OnActivate,
        OnStopPlaying = spinplate_OnStopPlayingOrDeactivate,
        OnDeactivateGame = spinplate_OnStopPlayingOrDeactivate,
        master_postinit = function(inst)
            inst.plate_size = size
            inst.plate_suffix = "clockwise"
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_SPINNER"

            inst:AddComponent("golfballspinner")
            inst.components.golfballspinner:SetRadius(radius)
            inst.components.golfballspinner:SetRadialStrength(5)
        end,
    })

    table.insert(defs, {
        name = "carnivalgame_golfprop_"..size.."spinner_ccw",
        bank = "carnivalgame_golf_spinplate",
        build = "carnivalgame_golf_spinplate",
        idleanim = size.."_counterclockwise_idle",
        placeanim = size.."_counterclockwise_place",
        ground_plane = true,
        deploy_smart_radius = radius,
        OnActivateGame = spinplate_OnActivate,
        OnStopPlaying = spinplate_OnStopPlayingOrDeactivate,
        OnDeactivateGame = spinplate_OnStopPlayingOrDeactivate,
        master_postinit = function(inst)
            inst.plate_size = size
            inst.plate_suffix = "counterclockwise"
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_SPINNER"

            inst:AddComponent("golfballspinner")
            inst.components.golfballspinner:SetIsCounterClockwise(true)
            inst.components.golfballspinner:SetRadius(radius)
            inst.components.golfballspinner:SetRadialStrength(5)
        end,
    })
end

-- prop wooden cut outs
local CUTOUT_SMART_RADIUS = 0.5 -- NOTES(JBK): Keep in sync with recipes.lua [CGGPCSR]
local CUTOUT_BASE_COLORS =
{
	"red",		-- 1, carrot
	"white",	-- 2, rose
	"blue",		-- 3, hambat
	"purple",	-- 4, corn
	"yellow",	-- 5, red mushroom
	"red",		-- 6, bearger
	"blue",		-- 7, deerclops
	"yellow",	-- 8, spider
	"purple",	-- 9, dragonfly
	"white",	-- 10, tentacle
}

local function cutout_CreateSurface(color, level, sort, followparent, followsymbol, rot)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.Transform:SetRotation(90 - rot)

	inst.AnimState:SetBank("carnivalgame_golf_props")
	inst.AnimState:SetBuild("carnivalgame_golf_props")
	inst.AnimState:PlayAnimation("base_"..level)
	if color ~= "brown" then
		inst.AnimState:OverrideSymbol("base_brown", "carnivalgame_golf_props", "base_"..color)
	end
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
	if sort > 0 then
		inst.AnimState:SetFinalOffset(sort)
	else
		inst.AnimState:SetSortOrder(sort)
	end

	if followparent then
		inst.entity:AddFollower():FollowSymbol(followparent.GUID, followsymbol)
	end

	return inst
end

local function cutout_CreateUpper(color, propid, sort, followparent, followsymbol)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("carnivalgame_golf_props")
	inst.AnimState:SetBuild("carnivalgame_golf_props")
	inst.AnimState:PlayAnimation("idle_upper")
	if color then
		inst.AnimState:OverrideSymbol("props_01", "carnivalgame_golf_props", "base_"..color)
	elseif propid ~= 1 then
		inst.AnimState:OverrideSymbol("props_01", "carnivalgame_golf_props", string.format("props_%02d", propid))
	end
	inst.AnimState:SetFinalOffset(sort)

	inst.Follower:FollowSymbol(followparent.GUID, followsymbol)

	return inst
end

local function cutout_PropPostUpdate(prop)
	prop:RemoveComponent("updatelooper")

	local inst = prop.entity:GetParent()
	if inst.AnimState:IsCurrentAnimation("place") then
		prop.AnimState:PlayAnimation("place_upper")
		prop.AnimState:PushAnimation("idle_upper", false)
		prop.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
	end
end

local function cutout_CreateParts(inst, propid)
	local rot = inst.Transform:GetRotation()
	local color = CUTOUT_BASE_COLORS[propid]
	local parts =
	{
		cutout_CreateUpper(nil, propid, 4, inst, "follow_top"),
		cutout_CreateSurface(color, "top", 3, inst, "follow_top", rot),
		cutout_CreateUpper(color, nil, 2, inst, "follow_mid"),
		cutout_CreateSurface(color, "btm", 1, inst, "follow_mid", rot),
		cutout_CreateSurface("brown", "btm", -1, nil, nil, rot),
	}

	if inst.components.placer then
		for _, v in ipairs(parts) do
			inst.components.placer:LinkEntity(v)
			v.entity:SetParent(inst.entity)
		end
	else
		inst.highlightchildren = inst.highlightchildren or {}

		for _, v in ipairs(parts) do
			table.insert(inst.highlightchildren, v)
			v.entity:SetParent(inst.entity)
		end
	end

	local prop = parts[1]
	prop:AddComponent("updatelooper")
	prop.components.updatelooper:AddPostUpdateFn(cutout_PropPostUpdate)

	return parts
end

local function cutout_OnEntityWake(inst)
	if inst.parts == nil then
		inst.parts = cutout_CreateParts(inst, inst._propid)
	end

	if not TheWorld.ismastersim then
		inst.OnEntityWake = nil
		inst._propid = nil
	end
end

local function cutout_OnEntitySleep(inst)
	if inst.parts then
		for _, v in ipairs(inst.parts) do
			table.removearrayvalue(inst.highlightchildren, v)
			v:Remove()
		end
		inst.parts = nil
		if #inst.highlightchildren <= 0 then
			inst.highlightchildren = nil
		end
	end
end

for i = 1, 10 do
    table.insert(defs, {
        name = "carnivalgame_golfprop_cutout"..i,
        bank = "carnivalgame_golf_props",
        build = "carnivalgame_golf_props",
		idleanim = "height",
        placeanim = "place",
		phys_rad = 0.5,
		deploy_smart_radius = CUTOUT_SMART_RADIUS,
        placer_postinit = function(inst)
			cutout_CreateParts(inst, i)
        end,
        common_postinit = function(inst)
			if not TheNet:IsDedicated() then
				inst._propid = i
				inst.OnEntityWake = cutout_OnEntityWake
				if TheWorld.ismastersim then
					inst.OnEntitySleep = cutout_OnEntitySleep
				end
			end
        end,
        master_postinit = function(inst)
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_CUTOUT"
        end,
    })
end

-- extending and retracting walls walls
local function movingwall_SetSurfaceGroundSort(inst, isground)
	if isground then
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(3)
	else
		inst.AnimState:SetLayer(LAYER_WORLD)
		inst.AnimState:SetSortOrder(0)
	end
end

local function movingwall_CreateSurface(build, parent)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("carnivalgame_golf_wall")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("surface")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetFinalOffset(1)

	inst.SetGroundSort = movingwall_SetSurfaceGroundSort

	inst.Follower:FollowSymbol(parent.GUID, "follow_top")

	return inst
end

local function movingwall_SetBaseGroundSort(inst, isground)
	if isground then
		inst.AnimState:SetLayer(LAYER_BACKGROUND)
		inst.AnimState:SetSortOrder(3)
	else
		inst.AnimState:SetLayer(LAYER_WORLD)
		inst.AnimState:SetSortOrder(-1)
	end
end

local function movingwall_CreateBase(build)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.AnimState:SetBank("carnivalgame_golf_wall")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("base")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetSortOrder(-1)

	inst.SetGroundSort = movingwall_SetBaseGroundSort

	return inst
end

local function movingwall_CreateFace(build, xoffs, zoffs, rot)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.Transform:SetEightFaced()
	inst.Transform:SetRotation(rot)
	inst.Transform:SetPosition(xoffs, 0, zoffs)

	inst.AnimState:SetBank("carnivalgame_golf_wall")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("face_idle")

	inst.AnimState:SetSortWorldOffset(-0.05 * xoffs, 0, -0.05 * zoffs)

	inst.syncanimprefix = "face_"

	return inst
end

local function movingwall_CreateEdgeV(build, xoffs, zoffs, rot)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.Transform:SetEightFaced()
	inst.Transform:SetRotation(rot)
	inst.Transform:SetPosition(xoffs, 0, zoffs)

	inst.AnimState:SetBank("carnivalgame_golf_wall")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("edge_v_idle")

	inst.syncanimprefix = "edge_v_"

	return inst
end

local function movingwall_CreateEdgeH(build, xoffs, zoffs, rot)
	local inst = CreateEntity()
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.Transform:SetRotation(rot)
	inst.Transform:SetPosition(xoffs, 0, zoffs)

	inst.AnimState:SetBank("carnivalgame_golf_wall")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("edge_h")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

	return inst
end

local function movingwall_CreateMid(build, parent)
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.parts =
	{
		movingwall_CreateEdgeH(build, 0.5, 0, 0),
		movingwall_CreateEdgeH(build, -0.5, 0, 180),
		movingwall_CreateEdgeH(build, 0, 0.5, -90),
		movingwall_CreateEdgeH(build, 0, -0.5, 90),
	}

	for _, v in ipairs(inst.parts) do
		v.entity:SetParent(inst.entity)
	end

	inst.Follower:FollowSymbol(parent.GUID, "follow_mid")

	return inst
end

local function movingwall_PartOnAnimOver(part)
	if not part.AnimState:AnimDone() and part.AnimState:IsCurrentAnimation(part.syncanimprefix.."idle_ground") then
		for _, v in ipairs(part.entity:GetParent().parts) do
			if v.SetGroundSort then
				v:SetGroundSort(true)
			end
		end
	end
end

local function movingwall_CreateParts(inst, build)
	if inst.parts == nil then
		inst.parts =
		{
			movingwall_CreateSurface(build, inst),
			movingwall_CreateBase(build),
			movingwall_CreateFace(build, 0.5, 0, 0),
			movingwall_CreateFace(build, -0.5, 0, 180),
			movingwall_CreateFace(build, 0, 0.5, -90),
			movingwall_CreateFace(build, 0, -0.5, 90),
			movingwall_CreateEdgeV(build, 0.5, 0.5, -45),
			movingwall_CreateEdgeV(build, -0.5, 0.5, -135),
			movingwall_CreateEdgeV(build, 0.5, -0.5, 45),
			movingwall_CreateEdgeV(build, -0.5, -0.5, 135),
			movingwall_CreateMid(build, inst),
		}

		if inst.components.placer then
			for _, v in ipairs(inst.parts) do
				if v.parts then
					for _, v1 in ipairs(v.parts) do
						inst.components.placer:LinkEntity(v1)
					end
				else
					inst.components.placer:LinkEntity(v)
				end
				v.entity:SetParent(inst.entity)
			end
		else
			inst.highlightchildren = inst.highlightchildren or {}

			local animated_part
			for _, v in ipairs(inst.parts) do
				if v.parts then
					for _, v1 in ipairs(v.parts) do
						table.insert(inst.highlightchildren, v1)
					end
				else
					table.insert(inst.highlightchildren, v)
				end
				v.entity:SetParent(inst.entity)

				if animated_part == nil and v.syncanimprefix then
					animated_part = v
				end
			end

			if animated_part then
				inst:ListenForEvent("animover", movingwall_PartOnAnimOver, animated_part)
			end
		end
	end
end

local function movingwall_KillParts(inst)
	if inst.parts then
		for _, v in ipairs(inst.parts) do
			if v.parts then
				for _, v1 in ipairs(v.parts) do
					table.removearrayvalue(inst.highlightchildren, v1)
				end
			else
				table.removearrayvalue(inst.highlightchildren, v)
			end
			v:Remove()
		end
		inst.parts = nil
		if #inst.highlightchildren <= 0 then
			inst.highlightchildren = nil
		end
	end
end

local function movingwall_DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("flat") then
		movingwall_KillParts(inst)
	else
		movingwall_CreateParts(inst, inst.build)

		if inst.AnimState:IsCurrentAnimation("emerge") then
			local t = inst.AnimState:GetCurrentAnimationTime()
			for _, v in ipairs(inst.parts) do
				if v.syncanimprefix then
					v.AnimState:PlayAnimation(v.syncanimprefix.."emerge")
					v.AnimState:SetTime(t)
					v.AnimState:PushAnimation(v.syncanimprefix.."idle", false)
				elseif v.SetGroundSort then
					v:SetGroundSort(false)
				end
			end
		elseif inst.AnimState:IsCurrentAnimation("retract") then
			local t = inst.AnimState:GetCurrentAnimationTime()
			for _, v in ipairs(inst.parts) do
				if v.syncanimprefix then
					v.AnimState:PlayAnimation(v.syncanimprefix.."retract")
					v.AnimState:SetTime(t)
					v.AnimState:PushAnimation(v.syncanimprefix.."idle_ground", false)
				elseif v.SetGroundSort then
					v:SetGroundSort(false)
				end
			end
		elseif inst.AnimState:IsCurrentAnimation("idle") then
			for _, v in ipairs(inst.parts) do
				if v.syncanimprefix then
					v.AnimState:PlayAnimation(v.syncanimprefix.."idle")
				elseif v.SetGroundSort then
					v:SetGroundSort(false)
				end
			end
		elseif inst.AnimState:IsCurrentAnimation("idle_ground") then
			for _, v in ipairs(inst.parts) do
				if v.syncanimprefix then
					v.AnimState:PlayAnimation(v.syncanimprefix.."idle_ground")
				elseif v.SetGroundSort then
					v:SetGroundSort(true)
				end
			end
		end
	end

	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(movingwall_DoSyncAnim)
	end
end

local function movingwall_OnSyncAnims(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(movingwall_DoSyncAnim)
	end
end

local function movingwall_PushSyncAnim(inst)
	inst.syncanim:push()
	if not TheNet:IsDedicated() then
		movingwall_DoSyncAnim(inst)
	end
end

local function movingwall_SetFlat(inst, flat)
	--initial value is nil, which is actually flat
	if inst.flat ~= flat then
		if flat then
			inst.flat = true
			inst.Transform:SetNoFaced()
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
			inst.AnimState:SetLayer(LAYER_BACKGROUND)
			inst.AnimState:SetSortOrder(3)
		else
			inst.flat = false
			inst.Transform:SetEightFaced()
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.BillBoard)
			inst.AnimState:SetLayer(LAYER_WORLD)
			inst.AnimState:SetSortOrder(0)
		end
	end
end

local function movingwall_BecomeFlat(inst)
	movingwall_SetFlat(inst, true)
	inst.AnimState:PlayAnimation("flat")
	movingwall_PushSyncAnim(inst)
end

local function movingwall_DisablePhysics(inst)
	if inst.disable_physics.becomeflat then
		movingwall_BecomeFlat(inst)
	end
	inst.disable_physics = nil
    inst.Physics:SetActive(false)
end

local function movingwall_ExtendWall(inst)
    if inst.extended then
        return
    end
    inst.extended = true
    inst.Physics:SetActive(true)

    if inst.disable_physics then
        inst.disable_physics:Cancel()
        inst.disable_physics = nil
    end

	movingwall_SetFlat(inst, false)
    if inst:IsAsleep() then
		inst.AnimState:PlayAnimation("idle")
    else
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/retracting_wall_emerge")
        inst.AnimState:PlayAnimation("emerge")
		inst.AnimState:PushAnimation("idle", false)
    end
	movingwall_PushSyncAnim(inst)
end

local function movingwall_RetractWall(inst)
    if not inst.extended then
        return
    end
    inst.extended = false

	if inst.disable_physics then
		inst.disable_physics:Cancel()
		inst.disable_physics = nil
	end

    if inst:IsAsleep() then
		movingwall_SetFlat(inst, true)
		inst.AnimState:PlayAnimation("flat")
        inst.Physics:SetActive(false)
    else
		movingwall_SetFlat(inst, false)
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/retracting_wall_retract")
        inst.AnimState:PlayAnimation("retract")
		inst.AnimState:PushAnimation("idle_ground", false)
		inst.disable_physics = inst:DoTaskInTime(4 * FRAMES, movingwall_DisablePhysics)
    end
	movingwall_PushSyncAnim(inst)
end

local function movingwall_NextWallState(inst)
    if inst.extended then
        inst:RetractWall()
    else
        inst:ExtendWall()
    end
end

local GOLFABLE_TAGS
local function movingwall_TryPushNearestGolfable(inst)
	if GOLFABLE_TAGS == nil then
		GOLFABLE_TAGS = { "golfable" }
	end
	--V2C: don't bother with { "INLIMBO" } for no tags, since golfballs can't be picked up.
	--     just do v:IsInLimbo() check for future proofing.
    local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, SQRT2 * 0.5, GOLFABLE_TAGS)) do
		if not v:IsInLimbo() then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if y1 < GOLF_SHAPE_HEIGHT and math.abs(dx) < 0.5 and math.abs(dz) < 0.5 then
				local vx, _, vz = v.Physics:GetVelocity()
				local theta = dx == 0 and dz == 0 and v.Transform:GetRotation() * DEGREES or math.atan2(-dz, dx)
				local ay = 8 + math.random()
				local ax, az = math.cos(theta), -math.sin(theta)
				local dot = vx * ax + vz * az
				local speed = 2 + math.random() * 0.5
				if dot > 0 then
					speed = math.max(0, speed - dot)
				end
				ax, az = ax * speed, az * speed

				v.Physics:Teleport(x1, GOLF_SHAPE_HEIGHT + math.max(v:GetPhysicsRadius(0), GOLF_SHAPE_POINTYTOP_HEIGHT), z1)
				v.Physics:SetVel(vx + ax, ay, vz + az)
				v.components.golfable:OnExternalPhysics(inst, theta * RADIANS, speed)
			end
        end
    end
end

local function movingwall_OnUpdateGame(inst, dt)
    inst.timing = inst.timing - dt
    if inst.timing < 0 then
        if not inst.extended then
            movingwall_TryPushNearestGolfable(inst)
        end
        inst:NextWallState()
        inst.timing = 1
    end
end

local function movingwall_OnStartPlaying(inst)
	inst.timing = inst.wall_inital_timing
	if inst.timing == 0 then
		if not inst.extended then
			movingwall_TryPushNearestGolfable(inst)
		end
		inst:NextWallState()
		inst.timing = 1
	end
end

local function movingwall_OnStopPlayingOrDeactivate(inst)
    inst:RetractWall()
	if inst.disable_physics then
		inst.disable_physics.becomeflat = true
	else
		movingwall_BecomeFlat(inst)
	end
end

local movingwall_colors =
{
	-- { color, build, timing }
	{ "red",	"carnivalgame_golf_wall_red",	0 },
	{ "blue",	"carnivalgame_golf_wall",		1 },
}
for i, v in pairs(movingwall_colors) do
	local color, build, inittime = unpack(v)
    table.insert(defs, {
        name = "carnivalgame_golfprop_movingwall_"..color,
        bank = "carnivalgame_golf_wall",
		build = build,
		idleanim = "flat",
        placeranim = "idle",
        placer_facing = "eight",
        metersnap = true,
        OnStartPlaying = movingwall_OnStartPlaying,
        OnUpdateGame = movingwall_OnUpdateGame,
        OnStopPlaying = movingwall_OnStopPlayingOrDeactivate,
        OnDeactivateGame = movingwall_OnStopPlayingOrDeactivate,
		placer_postinit = function(inst)
			movingwall_CreateParts(inst, build)
		end,
        common_postinit = function(inst)
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
			inst.AnimState:SetLayer(LAYER_BACKGROUND)
			inst.AnimState:SetSortOrder(3)

            local phys = inst.entity:AddPhysics()
            phys:SetMass(0)
            phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
            phys:SetCollisionMask(COLLISION.ITEMS)
            phys:SetTriangleMesh(BuildGolfSquareShapeMesh(GOLF_SQUARE_SHAPE))
            phys:SetActive(false)

			inst.syncanim = net_event(inst.GUID, "carnivalgame_golfprop_movingwall.syncanim")

			if not TheNet:IsDedicated() then
				inst.build = build

				if not TheWorld.ismastersim then
					inst:AddComponent("updatelooper")
					inst:ListenForEvent("carnivalgame_golfprop_movingwall.syncanim", movingwall_OnSyncAnims)
					movingwall_OnSyncAnims(inst)
				end
			end
        end,
        master_postinit = function(inst)
            inst.wall_inital_timing = inittime
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_MOVINGWALL"

            inst.extended = false
            inst.ExtendWall = movingwall_ExtendWall
            inst.RetractWall = movingwall_RetractWall
            inst.NextWallState = movingwall_NextWallState
        end,
    })
end

-- wormholes
local DECAL_LAYERS = { "hole_decal", "hole_decal_front", "star_decal" }

local function CreateWormHoleDecal(layername, orientation, layer, sortorder, finaloffset, build)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetRotation(90)

	inst.AnimState:SetBank("carnivalgame_golf_wormhole")
	inst.AnimState:SetBuild(build or "carnivalgame_golf_wormhole")
	inst.AnimState:PlayAnimation("hole_idle")
	for _, v in ipairs(DECAL_LAYERS) do
		if v ~= layername then
			inst.AnimState:Hide(v)
		end
	end
	inst.AnimState:SetOrientation(orientation)
	if layer then
		inst.AnimState:SetLayer(layer)
	end
	if sortorder then
		inst.AnimState:SetSortOrder(sortorder)
	end
	if finaloffset then
		inst.AnimState:SetFinalOffset(finaloffset)
	end

	return inst
end

local function wormhole_DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("hole_place") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.decals) do
			v.AnimState:PlayAnimation("hole_place")
			v.AnimState:PushAnimation("hole_idle", false)
			v.AnimState:SetTime(t)
		end
    elseif inst.AnimState:IsCurrentAnimation("hole_close") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.decals) do
			v.AnimState:PlayAnimation("hole_close")
			v.AnimState:SetTime(t)
		end
    else
		for _, v in ipairs(inst.decals) do
			v.AnimState:PlayAnimation("hole_idle")
		end
	end
    local rot = inst.Transform:GetRotation()
    for i, v in ipairs(inst.decals) do
        if i ~= 1 then
            v.Transform:SetRotation(-rot + 90) -- fix the non-star decals back
        end
    end
    if inst.postupdating then
	    inst.postupdating = nil
	    inst.components.updatelooper:RemovePostUpdateFn(wormhole_DoSyncAnim)
    end
end

local function wormhole_OnSyncAnims(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(wormhole_DoSyncAnim)
	end
end

local function wormhole_PushSyncAnim(inst)
	inst.syncanim:push()
	if inst.decals then
		wormhole_DoSyncAnim(inst)
	end
end

local function wormhole_Close(inst)
    if not inst.closed then
        inst:RemoveTag("golfhole")
        inst.closed = true
        if inst:IsAsleep() then
            inst:Hide()
        else
            inst.AnimState:PlayAnimation("hole_close")
            inst:ListenForEvent("animover", inst.Hide)
            wormhole_PushSyncAnim(inst)
        end
    end
end

local function wormhole_CloseWithDelay(inst, delay)
    inst:RemoveTag("golfhole")
    inst:DoTaskInTime(delay, wormhole_Close)
end

local function wormhole_Open(inst)
    if inst.closed then
        inst:AddTag("golfhole")
        inst:Show()
        inst.closed = false
        inst:RemoveEventCallback("animover", inst.Hide)
        if inst:IsAsleep() then
            inst.AnimState:PlayAnimation("hole_idle")
        else
            inst.AnimState:PlayAnimation("hole_place")
            inst.AnimState:PushAnimation("hole_idle", false)
            inst.SoundEmitter:PlaySound("dontstarve/common/teleportworm/open_golf")
        end
        wormhole_PushSyncAnim(inst)
    end
end

local function wormhole_SpitOutAtWormhole(golfball, starthole, endhole)
    -- starthole and endhole can be the same
    if endhole.islimited then
        if starthole ~= endhole then
            starthole:CloseWithDelay(math.random() * 0.2)
        end
        endhole:CloseWithDelay(0.4 + math.random() * 0.3)
    end
    endhole.SoundEmitter:PlaySound("dontstarve/common/teleportworm/spit_golf")
    golfball:SpitOutAt(endhole.Transform:GetWorldPosition())
end

local function wormhole_SpitOutAtRandomWormhole(golfball, wormhole)
    local golfgame = wormhole.golfgame
    if golfgame then
        for i, v in ipairs(shuffleArray(shallowcopy(golfgame.courseparts))) do
            if v.prefab == wormhole.prefab and v ~= wormhole and v:HasTag("golfhole") then
                wormhole_SpitOutAtWormhole(golfball, wormhole, v)
                return
            end
        end
    end

    -- fallback
    wormhole_SpitOutAtWormhole(golfball, wormhole, wormhole)
end
local function wormhole_OnGolfBallEntered(inst, golfball)
    inst.SoundEmitter:PlaySound("dontstarve/common/teleportworm/swallow_golf")
    golfball:DoTaskInTime(2 + math.random(), wormhole_SpitOutAtRandomWormhole, inst)
end

local function wormhole_limited_OnStopPlayingOrDeactivateGame(inst)
    if inst.closed then
        if inst:IsAsleep() then
            inst:Open()
        else
            inst:DoTaskInTime(0.2 + math.random() * 0.8, inst.Open)
        end
    end
end

local function wormhole_OnBuilt(inst, data)
    if data ~= nil and data.builder ~= nil then -- random rotation only when built by player at first, otherwise onbuilt is also pushed by the golfgame
        inst.Transform:SetRotation(math.random() * 360)
    end
	if inst.decals then
		wormhole_DoSyncAnim(inst)
	end
end

local function wormhole_SpawnedAsGolfProp(inst)
	if inst.decals then
		wormhole_DoSyncAnim(inst) -- to fix up rotations
	end
end

local wormholes =
{
    { "wormhole" },
    { "wormhole_limited", "carnivalgame_golf_sickwormhole", true },
}

for i, holedata in ipairs(wormholes) do
    local name, build, islimited = holedata[1], holedata[2], holedata[3]
    table.insert(defs, {
        name = "carnivalgame_golfprop_"..name,
        bank = "carnivalgame_golf_wormhole",
        build = build or "carnivalgame_golf_wormhole",
        idleanim = "hole_idle",
        placeanim = "hole_place",
        placesound = "dontstarve/common/teleportworm/open_golf",
        ground_plane = true,
        deploy_smart_radius = 0.5,

        OnStopPlaying = islimited and wormhole_limited_OnStopPlayingOrDeactivateGame,
        OnDeactivateGame = islimited and wormhole_limited_OnStopPlayingOrDeactivateGame,

        placer_postinit = function(inst)
        	for _, v in ipairs(DECAL_LAYERS) do
    	    	inst.AnimState:Hide(v)
    	    end
    	    inst.decals =
    	    {
                CreateWormHoleDecal("star_decal", ANIM_ORIENTATION.OnGround, nil, nil, -2, build),
    		    CreateWormHoleDecal("hole_decal", ANIM_ORIENTATION.OnGroundFixed, nil, nil, -1, build),
    		    CreateWormHoleDecal("hole_decal_front", ANIM_ORIENTATION.OnGroundFixed, nil, nil, 1, build),
    	    }
    	    for _, v in ipairs(inst.decals) do
    	    	v.entity:SetParent(inst.entity)
    		    inst.components.placer:LinkEntity(v)
    	    end
        end,
        common_postinit = function(inst)
	        inst.syncanim = net_event(inst.GUID, "golfpropwormhole.syncanim")

            inst:AddTag("golfhole")
    	    for _, v in ipairs(DECAL_LAYERS) do
    	    	inst.AnimState:Hide(v)
    	    end

        	if not TheNet:IsDedicated() then
    	    	inst.decals =
    	    	{
    	    		CreateWormHoleDecal("star_decal", ANIM_ORIENTATION.OnGround, LAYER_BACKGROUND, 3, nil, build),
    	    		CreateWormHoleDecal("hole_decal", ANIM_ORIENTATION.OnGroundFixed, LAYER_BACKGROUND, 3, 1, build),
    	    		CreateWormHoleDecal("hole_decal_front", ANIM_ORIENTATION.OnGroundFixed, nil, nil, 1, build),
    	    	}
                inst.highlightchildren = {}
    	    	for _, v in ipairs(inst.decals) do
                    table.insert(inst.highlightchildren, v)
    	    		v.entity:SetParent(inst.entity)
    	    	end
    	    end

            if not TheWorld.ismastersim then
                inst:AddComponent("updatelooper")
                wormhole_OnSyncAnims(inst)
                inst:ListenForEvent("golfpropwormhole.syncanim", wormhole_OnSyncAnims)
            end
        end,
        master_postinit = function(inst)
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_WORMHOLE"

            inst.islimited = islimited
            inst.Close = wormhole_Close
            inst.CloseWithDelay = wormhole_CloseWithDelay
            inst.Open = wormhole_Open
            inst:ListenForEvent("ms_golfballentered", wormhole_OnGolfBallEntered)
            inst:ListenForEvent("onbuilt", wormhole_OnBuilt)
            inst:ListenForEvent("spawnedasgolfprop", wormhole_SpawnedAsGolfProp)
        end,
    })
end

-- carnivalgame_golf_spring
local function spring_ResolveAnim(inst, anim)
	return inst.nofaced and anim.."_nofaced" or anim
end

local SPRING_DECAL_LAYERS = { "decal_front", "decal_mid", "decal_back" }

local function spring_CreateDecal(build, layer, finaloffset, rotates, nofaced)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("carnivalgame_golf_spring")
	inst.AnimState:SetBuild(build)
	inst.AnimState:Hide("FACE")
	inst.AnimState:Hide("plate_spring")
	for _, v in ipairs(SPRING_DECAL_LAYERS) do
		if v ~= layer then
			inst.AnimState:Hide(v)
		end
	end
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetFinalOffset(finaloffset)

	if rotates then
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:SetScale(1, -1)
	elseif nofaced then
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
		inst.AnimState:SetScale(1, -1)
	else
		inst.AnimState:SetScale(-1, 1)
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
		inst.Transform:SetRotation(90)
		inst.autofixrotate = true
	end

	inst.AnimState:PlayAnimation(nofaced and "idle_nofaced" or "idle")

	return inst
end

local function spring_TrySyncAnim(inst, anim, pushidle, synctime)
	anim = spring_ResolveAnim(inst, anim)
	if inst.AnimState:IsCurrentAnimation(anim) then
		synctime = synctime and inst.AnimState:GetCurrentAnimationTime() or nil
		pushidle = pushidle and spring_ResolveAnim(inst, "idle") or nil
		local rot = 90 - inst.Transform:GetRotation()
		for _, v in ipairs(inst.decals) do
			v.AnimState:PlayAnimation(anim)
			if pushidle then
				v.AnimState:PushAnimation(pushidle, false)
			end
			if synctime then
				v.AnimState:SetTime(synctime)
			end
			if v.autofixrotate then
				v.Transform:SetRotation(rot)
			end
		end
		return true
	end
	return false
end

local function spring_DoSyncAnim(inst)
	local _ =
		spring_TrySyncAnim(inst, "place", true, true) or
		spring_TrySyncAnim(inst, "pop", false, true) or
		spring_TrySyncAnim(inst, "reset", true, true) or
		spring_TrySyncAnim(inst, "idle", false, false)

	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(spring_DoSyncAnim)
	end
end

local function spring_OnSyncAnims(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(spring_DoSyncAnim)
	end
end

local function spring_PushSyncAnim(inst)
	inst.syncanim:push()
	if inst.decals then
		spring_DoSyncAnim(inst)
	end
end

local function spring_OnStartPlaying(inst)
    inst.components.mine:Reset()
end

local function spring_OnStopPlayingOrDeactivateGame(inst)
    inst.components.mine:Reset()
    inst.components.mine:Deactivate()
end

local function spring_OnAnimOver(inst)
	if inst.AnimState:IsCurrentAnimation(spring_ResolveAnim(inst, "pop")) then
        inst.components.mine:Reset()
    end
    inst:RemoveEventCallback("animover", spring_OnAnimOver)
end

local function spring_OnExplode(inst, target)
	local speed, theta
	if inst.nofaced then
		speed = 0.5 + math.random() * 0.5
		theta = math.random() * TWOPI
	else
		speed = 5 + math.random() * 0.5
		theta = inst.Transform:GetRotation() * DEGREES
	end

	local x1, y1, z1 = target.Transform:GetWorldPosition()
	local vx, _, vz = target.Physics:GetVelocity()
	local ay = 8 + math.random()
	local ax, az = math.cos(theta), -math.sin(theta)
	local dot = vx * ax + vz * az
	if dot > 0 then
		speed = math.max(0, speed - dot)
	elseif not inst.nofaced then
		local min = 1 + math.random()
		if speed + dot < min then
			speed = min - dot
		end
	end
	ax, az = ax * speed, az * speed

	target.Physics:Teleport(x1, math.max(y1, 0.65), z1)
	target.Physics:SetVel(vx + ax, ay, vz + az)
	target.components.golfable:OnExternalPhysics(inst, theta * RADIANS, speed)

	inst.AnimState:PlayAnimation(spring_ResolveAnim(inst, "pop"))
	spring_PushSyncAnim(inst)
    if not inst.onetime then
        inst:ListenForEvent("animover", spring_OnAnimOver)
    end
    inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/popup_plate")
end

local function spring_OnReset(inst)
    if inst:IsAsleep() then
		inst.AnimState:PlayAnimation(spring_ResolveAnim(inst, "idle"))
		spring_PushSyncAnim(inst)
	elseif inst.AnimState:IsCurrentAnimation(spring_ResolveAnim(inst, "pop")) then
		inst.AnimState:PlayAnimation(spring_ResolveAnim(inst, "reset"))
		inst.AnimState:PushAnimation(spring_ResolveAnim(inst, "idle"), false)
		spring_PushSyncAnim(inst)
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/popup_plate_reset")
    end
end

local function spring_TestTimeFn() -- we can run constantly, we're only active in an active golf game, so be super simulative
    return 0
end

local function spring_IsTargetValid(golfball, inst)
	local x, y, z = golfball.Transform:GetWorldPosition()
	return y <= 0.2
end

local function spring_OnBuilt(inst)--, data)
	if inst.decals then
		spring_DoSyncAnim(inst)
	end
end

local function spring_SpawnedAsGolfProp(inst)
	if inst.decals then
		spring_DoSyncAnim(inst) -- to fix up rotations
	end
end

local golfsprings =
{
    { "", },
    { "_onetime", true },
    { "_nofaced", false, true },
    { "_nofaced_onetime", true, true },
}
local SPRING_MUST_TAGS = { "golfable" }
for i, springdata in ipairs(golfsprings) do
    local name, onetime, nofaced = springdata[1], springdata[2], springdata[3]
	local build = onetime and "carnivalgame_golf_spring_onetime_build" or "carnivalgame_golf_spring"

    table.insert(defs, {
        name = "carnivalgame_golfprop_spring"..name,
        bank = "carnivalgame_golf_spring",
        build = build,
		placeranim = nofaced and "idle_nofaced" or "idle",
        idleanim = nofaced and "idle_nofaced" or "idle",
        placeanim = nofaced and "place_nofaced" or "place",
        deploy_smart_radius = 0.5,
        placerfixedcameraoffset = not nofaced and -90 or nil,
		placer_facing = nofaced and "eight" or nil,
        OnStartPlaying = spring_OnStartPlaying,
        OnStopPlaying = spring_OnStopPlayingOrDeactivateGame,
        OnDeactivateGame = spring_OnStopPlayingOrDeactivateGame,

		placer_postinit = function(inst)
			inst.AnimState:SetOrientation(nofaced and ANIM_ORIENTATION.OnGroundFixed or ANIM_ORIENTATION.OnGround)
			inst.AnimState:SetScale(1, -1)
		end,
        common_postinit = function(inst)
			for _, v in ipairs(SPRING_DECAL_LAYERS) do
				inst.AnimState:Hide(v)
			end

			inst.nofaced = nofaced
			inst.Transform:SetEightFaced()

			inst.syncanim = net_event(inst.GUID, "carnivalgame_golfprop_spring.syncanim")

			if not TheNet:IsDedicated() then
				inst.decals =
				{
					spring_CreateDecal(build, "decal_front", 2, false, nofaced),
					spring_CreateDecal(build, "decal_mid", 1, true, nofaced),
					spring_CreateDecal(build, "decal_back", 0, false, nofaced),
				}

				inst.highlightchildren = {}
				for _, v in ipairs(inst.decals) do
					v.entity:SetParent(inst.entity)
					table.insert(inst.highlightchildren, v)
				end

				if not TheWorld.ismastersim then
					inst:AddComponent("updatelooper")
					inst:ListenForEvent("carnivalgame_golfprop_spring.syncanim", spring_OnSyncAnims)
					spring_OnSyncAnims(inst)
				end
			end
        end,

        master_postinit = function(inst)
            inst.onetime = onetime

            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_SPRING"

            inst:AddComponent("mine")
            inst.components.mine:SetSearchTags(SPRING_MUST_TAGS)
            inst.components.mine:SetTestTimeFn(spring_TestTimeFn)
            inst.components.mine:SetOnExplodeFn(spring_OnExplode)
            inst.components.mine:SetSearchTestFn(spring_IsTargetValid)
            inst.components.mine:SetAlignment(nil)
            inst.components.mine:SetRadius(0.5)
            inst.components.mine:SetOnResetFn(spring_OnReset)
            inst.components.mine:Reset()
            inst.components.mine:Deactivate()
            -- inst.components.mine:SetOnSprungFn(SetSprung)

			inst:ListenForEvent("onbuilt", spring_OnBuilt)
			inst:ListenForEvent("spawnedasgolfprop", spring_SpawnedAsGolfProp)
        end
    })
end

--

local ret = {}

for i, data in ipairs(defs) do
    table.insert(ret, MakeGolfProp(data.name, data))
    -- table.insert(ret, MakeDeployableKitItem(data.name.."_kit", data.name, data.bank, data.build, "kit_item", nil, {size = "small", scale = 1.1}, { "irreplaceable" }, {fuelvalue = TUNING.SMALL_FUEL}, {master_postinit = kit_master_postinit, deployspacing = DEPLOYSPACING.LESS}, TUNING.STACK_SIZE_LARGEITEM))
    table.insert(ret, MakePlacer(data.name.."_placer", data.bank, data.build, data.placeranim or data.idleanim or "idle", data.ground_plane, nil, data.metersnap, nil, data.placerfixedcameraoffset, data.placer_facing, data.placer_postinit))
end

return unpack(ret)
-- (OMAR): For searching:
 -- carnivalgame_golfprop_spring
 -- carnivalgame_golfprop_spring_onetime
 -- carnivalgame_golfprop_spring_nofaced
 -- carnivalgame_golfprop_spring_nofaced_onetime

 -- carnivalgame_golfprop_wormhole
 -- carnivalgame_golfprop_wormhole_limited

 -- carnivalgame_golf_wall_red
 -- carnivalgame_golf_wall_blue

 -- carnivalgame_golfprop_smallspinner_cw
 -- carnivalgame_golfprop_smallspinner_ccw
 -- carnivalgame_golfprop_mediumspinner_cw
 -- carnivalgame_golfprop_mediumspinner_ccw

 -- carnivalgame_golfprop_cutout1
 -- carnivalgame_golfprop_cutout2
 -- carnivalgame_golfprop_cutout3
 -- carnivalgame_golfprop_cutout4
 -- carnivalgame_golfprop_cutout5
 -- carnivalgame_golfprop_cutout6
 -- carnivalgame_golfprop_cutout7
 -- carnivalgame_golfprop_cutout8
 -- carnivalgame_golfprop_cutout9
 -- carnivalgame_golfprop_cutout10