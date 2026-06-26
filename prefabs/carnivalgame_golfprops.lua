local prefabs =
{

}

local GOLF_SHAPE_HEIGHT = 1
local GOLF_SHAPE_POINTYTOP_HEIGHT = 0.5

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

    return Prefab(name, fn, assets, prefabs)

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
local cutout_smart_radii = { -- NOTES(JBK): Keep in sync with recipes.lua [CGGPCSR]
    0.5, -- 1, carrot
    0.5, -- 2, rose
    0.6, -- 3, hambat
    0.6, -- 4, corn
    0.5, -- 5, red mushroom
    0.6, -- 6, bearger
    0.6, -- 7, deerclops
    0.55, -- 8, spider
    0.55, -- 9, dragonfly
    0.55, -- 10, tentacle
}
for i = 1, 10 do
    table.insert(defs, {
        name = "carnivalgame_golfprop_cutout"..i,
        bank = "carnivalgame_golf_props",
        build = "carnivalgame_golf_props",
        idleanim = "idle",
        placeanim = "place",
        phys_rad = .5,
        deploy_smart_radius = cutout_smart_radii[i],
        placer_postinit = function(inst)
            inst.AnimState:OverrideSymbol("carnivalgame_golf_props_swap", "carnivalgame_golf_props", string.format("props_%02d", i))
        end,
        common_postinit = function(inst)
            inst.AnimState:OverrideSymbol("carnivalgame_golf_props_swap", "carnivalgame_golf_props", string.format("props_%02d", i))
        end,
        master_postinit = function(inst)
            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_CUTOUT"
        end,
    })
end

-- extending and retracting walls walls
local function movingwall_DisablePhysics(inst)
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

    if inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle", true)
    else
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/retracting_wall_emerge")
        inst.AnimState:PlayAnimation("emerge")
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function movingwall_RetractWall(inst)
    if not inst.extended then
        return
    end
    inst.extended = false

    if inst:IsAsleep() then
        inst.AnimState:PlayAnimation("idle_ground", true)
        inst.Physics:SetActive(false)
    else
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/retracting_wall_retract")
        inst.AnimState:PlayAnimation("retract")
        inst.AnimState:PushAnimation("idle_ground", true)
        inst.disable_physics = inst:DoTaskInTime(8 * FRAMES, movingwall_DisablePhysics)
    end
end

local function movingwall_NextWallState(inst)
    if inst.extended then
        inst:RetractWall()
    else
        inst:ExtendWall()
    end
end

local function movingwall_OnStartPlaying(inst)
    inst.timing = inst.wall_inital_timing
    if inst.timing == 0 then
        inst.timing = 1
        inst:NextWallState()
    end
end

local function movingwall_TryPushNearestGolfable(inst)
    local golfball = FindEntity(inst, 0.5, nil, { "golfable"}, { "INLIMBO" })
    if golfball then
        local x, y, z = golfball.Transform:GetWorldPosition()
        local vx, vy, vz = golfball.Physics:GetVelocity()
	    local speed = 0.5 + math.random() * 0.5
	    local vspeed = 10 + math.random()
	    local theta = math.random() * TWOPI
        local newvx, newvz = speed * math.cos(theta), -speed * math.sin(theta)

        vx = math.abs(vx) > math.abs(newvx) and vx or newvx
        vz = math.abs(vz) > math.abs(newvz) and vz or newvz
	    golfball.Physics:Teleport(x, y + 0.1, z)
	    golfball.Physics:SetVel(vx, vy+vspeed, vz)
        golfball.components.golfable:OnExternalPhysics(inst, theta * RADIANS, speed)
        TemporarilyRemovePhysics(inst, .5)
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

local function movingwall_OnStopPlayingOrDeactivate(inst)
    inst:RetractWall()
end

local movingwall_colors =
{
    -- { color, timing }
    { "red",    0 },
    { "blue",   1 },
}
for i, v in pairs(movingwall_colors) do
    local color, inittime = v[1], v[2]
    table.insert(defs, {
        name = "carnivalgame_golfprop_movingwall_"..color,
        bank = "carnivalgame_golf_wall",
        build = "carnivalgame_golf_wall_"..color,
        idleanim = "idle_ground",
        placeranim = "idle",
        placer_facing = "eight",
        metersnap = true,
        OnStartPlaying = movingwall_OnStartPlaying,
        OnUpdateGame = movingwall_OnUpdateGame,
        OnStopPlaying = movingwall_OnStopPlayingOrDeactivate,
        OnDeactivateGame = movingwall_OnStopPlayingOrDeactivate,
        common_postinit = function(inst)
            inst.Transform:SetEightFaced()

            local phys = inst.entity:AddPhysics()
            phys:SetMass(0)
            phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
            phys:SetCollisionMask(COLLISION.ITEMS)
            phys:SetTriangleMesh(BuildGolfSquareShapeMesh(GOLF_SQUARE_SHAPE))
            phys:SetActive(false)
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
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
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
        if inst:IsAsleep() then
            inst.AnimState:PlayAnimation("hole_idle")
        else
            inst.AnimState:PlayAnimation("hole_place")
            inst.AnimState:PushAnimation("hole_idle", false)
            inst.SoundEmitter:PlaySound("dontstarve/common/teleportworm/open_golf")
            inst:RemoveEventCallback("animover", inst.Hide)
            wormhole_PushSyncAnim(inst)
        end
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
local function spring_OnStartPlaying(inst)
    inst.components.mine:Reset()
end

local function spring_OnStopPlayingOrDeactivateGame(inst)
    inst.components.mine:Reset()
    inst.components.mine:Deactivate()
end

local function spring_OnAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation(inst.nofaced and "pop_nofaced" or "pop") then
        inst.components.mine:Reset()
    end
    inst:RemoveEventCallback("animover", spring_OnAnimOver)
end

local function spring_OnExplode(inst, target)
    if inst.nofaced then
        local x, y, z = target.Transform:GetWorldPosition()
        local vx, vy, vz = target.Physics:GetVelocity()
	    local speed = 0.5 + math.random() * 0.5
	    local vspeed = 10 + math.random()
	    local theta = math.random() * TWOPI
        local newvx, newvz = speed * math.cos(theta), -speed * math.sin(theta)

        vx = math.abs(vx) > math.abs(newvx) and vx or newvx
        vz = math.abs(vz) > math.abs(newvz) and vz or newvz
	    target.Physics:Teleport(x, y + 0.1, z)
	    target.Physics:SetVel(vx, vy+vspeed, vz)
        target.components.golfable:OnExternalPhysics(inst, theta * RADIANS, speed)
    else
        local x, y, z = target.Transform:GetWorldPosition()
        local rot = inst.Transform:GetRotation()
        local theta = rot * DEGREES
        local vx, vy, vz = target.Physics:GetVelocity()
        local speed = 5 + math.random() * 0.5
        local vspeed = 10 + math.random()

        vx = (vx * 0.4) + speed * math.cos(theta)
        vy = vy + vspeed
        vz = (vz * 0.4) - speed * math.sin(theta)

        target.Physics:Teleport(x, y + 0.1, z)
	    target.Physics:SetVel(vx, vy, vz)
        target.components.golfable:OnExternalPhysics(inst, theta * RADIANS, speed)
    end

	inst.AnimState:SetLayer(LAYER_WORLD)
	inst.AnimState:SetSortOrder(0)
    inst.AnimState:PlayAnimation(inst.nofaced and "pop_nofaced" or "pop")
    if not inst.onetime then
        inst:ListenForEvent("animover", spring_OnAnimOver)
    end
    inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/popup_plate")
end

local function spring_OnReset(inst)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
    if inst:IsAsleep() then
        inst.AnimState:PlayAnimation(inst.nofaced and "idle_nofaced" or "idle")
    elseif inst.AnimState:IsCurrentAnimation(inst.nofaced and "pop_nofaced" or "pop") then
        inst.AnimState:PlayAnimation(inst.nofaced and "reset_nofaced" or "reset")
        inst.AnimState:PushAnimation(inst.nofaced and "idle_nofaced" or "idle", false)
        inst.SoundEmitter:PlaySound("summerevent/golf_minigame/props/popup_plate_reset")
    end
end

local function spring_TestTimeFn() -- we can run constantly, we're only active in an active golf game, so be super simulative
    return 0
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

    table.insert(defs, {
        name = "carnivalgame_golfprop_spring"..name,
        bank = "carnivalgame_golf_spring",
        build = onetime and "carnivalgame_golf_spring_onetime_build" or "carnivalgame_golf_spring",
        idleanim = nofaced and "idle_nofaced" or "idle",
        placeanim = nofaced and "place_nofaced" or "place",
        deploy_smart_radius = 0.5,
        placerfixedcameraoffset = not nofaced and -90 or nil,
        placer_facing = not nofaced and "eight" or nil,
        OnStartPlaying = spring_OnStartPlaying,
        OnStopPlaying = spring_OnStopPlayingOrDeactivateGame,
        OnDeactivateGame = spring_OnStopPlayingOrDeactivateGame,

        common_postinit = function(inst)
        	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	        inst.AnimState:SetSortOrder(3)

            if not nofaced then
                inst.Transform:SetEightFaced()
            end
        end,

        master_postinit = function(inst)
            inst.onetime = onetime
            inst.nofaced = nofaced

            inst.components.inspectable.nameoverride = "CARNIVALGAME_GOLFPROP_SPRING"

            inst:AddComponent("mine")
            inst.components.mine:SetSearchTags(SPRING_MUST_TAGS)
            inst.components.mine:SetTestTimeFn(spring_TestTimeFn)
            inst.components.mine:SetOnExplodeFn(spring_OnExplode)
            inst.components.mine:SetAlignment(nil)
            inst.components.mine:SetRadius(0.5)
            inst.components.mine:SetOnResetFn(spring_OnReset)
            inst.components.mine:Reset()
            inst.components.mine:Deactivate()
            -- inst.components.mine:SetOnSprungFn(SetSprung)
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