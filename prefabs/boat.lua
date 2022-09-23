local wood_assets =
{
    Asset("ANIM", "anim/boat_test.zip"),
    Asset("MINIMAP_IMAGE", "boat"),
}

local grass_assets =
{
    Asset("ANIM", "anim/boat_grass.zip"),
    Asset("MINIMAP_IMAGE", "boat_grass"),
}

local pirate_assets =
{
    Asset("ANIM", "anim/boat_pirate.zip"),
    Asset("MINIMAP_IMAGE", "boat_pirate"),
}

local item_assets =
{
    Asset("ANIM", "anim/seafarer_boat.zip"),
    Asset("INV_IMAGE", "boat_item"),
}

local grass_item_assets =
{
    Asset("ANIM", "anim/boat_grass_item.zip"),
    Asset("INV_IMAGE", "boat_grass_item"),
}

local prefabs =
{
    "mast",
    "burnable_locator_medium",
    "steeringwheel",
    "rudder",
    "boatlip",
    "boat_water_fx",
    "boat_leak",
    "fx_boat_crackle",
    "boatfragment03",
    "boatfragment04",
    "boatfragment05",
    "fx_boat_pop",
    "boat_player_collision",
    "boat_item_collision",
    "boat_grass_player_collision",
    "boat_grass_item_collision",
    "walkingplank",
    "walkingplank_grass",

    "boat_rotator",
    "boat_cannon",
    "boat_magnet",
    "boat_magnet_beacon",

    "boat_bumper_kelp",
    "boat_bumper_shell",

    "boat_pirate",
}

local grass_prefabs =
{
    "degrade_fx_grass",
    "boatlip_grass",
    "boat_grass_erode",
    "boat_grass_erode_water",
    "fx_grass_boat_fluff",
}

local pirate_prefabs =
{

}

local item_prefabs =
{
    "boat",
}

local grass_item_prefabs =
{
    "boat_grass",
}

local sounds ={
    place = "turnoftides/common/together/boat/place",
    creak = "turnoftides/common/together/boat/creak",
    damage = "turnoftides/common/together/boat/damage",
    sink = "turnoftides/common/together/boat/sink",
    hit = "turnoftides/common/together/boat/hit",
    thunk = "turnoftides/common/together/boat/thunk",
    movement = "turnoftides/common/together/boat/movement",
}

local sounds_grass ={
    place = "monkeyisland/grass_boat/place",
    creak = nil, --"monkeyisland/grass_boat/creak",
    damage = "monkeyisland/grass_boat/damage",
    sink = "monkeyisland/grass_boat/sink",
    hit = "monkeyisland/grass_boat/hit",
    thunk = "monkeyisland/grass_boat/thunk",
    movement = "monkeyisland/grass_boat/movement",
}

local BOATBUMPER_MUST_TAGS = { "boatbumper" }
local BOATCANNON_MUST_TAGS = { "boatcannon" }

local function OnLoadPostPass(inst)
    local boatring = inst.components.boatring
    if boatring == nil then
        return
    end

    -- If cannons and bumpers are on a boat, we need to rotate them to account for the boat's rotation
    local x, y, z = inst:GetPosition():Get()

    -- Bumpers
    local bumpers = TheSim:FindEntities(x, y, z, boatring:GetRadius(), BOATBUMPER_MUST_TAGS)
    for i, bumper in ipairs(bumpers) do
        -- Add to boat bumper list for future reference
        table.insert(boatring.boatbumpers, bumper)

        local bumperpos = bumper:GetPosition()
        local angle = GetAngleFromBoat(inst, bumperpos.x, bumperpos.z) / DEGREES

        -- Need to further rotate the bumpers to account for the boat's rotation
        bumper.Transform:SetRotation(-angle + 90)
    end

    -- Cannons
    --[[local cannons = TheSim:FindEntities(x, y, z, boatring:GetRadius(), BOATCANNON_MUST_TAGS)
    for i, cannon in ipairs(cannons) do
        local cannonpos = cannon:GetPosition()
        local angle = GetAngleFromBoat(inst, cannonpos.x, cannonpos.z) / DEGREES

        cannon.Transform:SetRotation(-angle)
    end]]
end

local function OnRepaired(inst)
    --inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/repair_with_wood")
end

local function OnSpawnNewBoatLeak(inst, data)
	if data ~= nil and data.pt ~= nil then
		local leak = SpawnPrefab("boat_leak")
		leak.Transform:SetPosition(data.pt:Get())
		leak.components.boatleak.isdynamic = true
		leak.components.boatleak:SetBoat(inst)
		leak.components.boatleak:SetState(data.leak_size)

		table.insert(inst.components.hullhealth.leak_indicators_dynamic, leak)

		if inst.components.walkableplatform ~= nil then
			inst.components.walkableplatform:AddEntityToPlatform(leak)
			for k in pairs(inst.components.walkableplatform:GetPlayersOnPlatform()) do
				if k:IsValid() then
					k:PushEvent("on_standing_on_new_leak")
				end
			end
		end

		if data.playsoundfx then
			inst.SoundEmitter:PlaySoundWithParams(inst.sounds.damage, { intensity = 0.8 })
		end
	end
end

local function OnSpawnNewBoatLeak_Grass(inst, data)
	if data ~= nil and data.pt ~= nil then
		local leak_x, leak_y, leak_z = data.pt:Get()

        if inst.material == "grass" then
            SpawnPrefab("fx_grass_boat_fluff").Transform:SetPosition(leak_x, 0, leak_z)
			SpawnPrefab("splash_green_small").Transform:SetPosition(leak_x, 0, leak_z)
        end

		local damage = TUNING.BOAT.GRASSBOAT_LEAK_DAMAGE[data.leak_size]
		if damage ~= nil then
	        inst.components.health:DoDelta(-damage)
		end

		if data.playsoundfx then
			inst.SoundEmitter:PlaySoundWithParams(inst.sounds.damage, { intensity = 0.8 })
		end
	end
end

local function RemoveConstrainedPhysicsObj(physics_obj)
    if physics_obj:IsValid() then
        physics_obj.Physics:ConstrainTo(nil)
        physics_obj:Remove()
    end
end

local function AddConstrainedPhysicsObj(boat, physics_obj)
	physics_obj:ListenForEvent("onremove", function() RemoveConstrainedPhysicsObj(physics_obj) end, boat)

    physics_obj:DoTaskInTime(0, function()
		if boat:IsValid() then
			physics_obj.Transform:SetPosition(boat.Transform:GetWorldPosition())
   			physics_obj.Physics:ConstrainTo(boat.entity)
		end
	end)
end

local function on_start_steering(inst)
    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.isclientcontrollerattached then
        inst.components.reticule:CreateReticule()
    end
end

local function on_stop_steering(inst)
    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.components.playercontroller.isclientcontrollerattached then
        inst.lastreticuleangle = nil
        inst.components.reticule:DestroyReticule()
    end
end

local function ReticuleTargetFn(inst)

    local range = 7
    local pos = Vector3(inst.Transform:GetWorldPosition())

    local dir = Vector3()
    dir.x = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    dir.y = 0
    dir.z = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
    local deadzone = .3

    if math.abs(dir.x) >= deadzone or math.abs(dir.z) >= deadzone then
        dir = dir:GetNormalized()

        inst.lastreticuleangle = dir
    else
        if inst.lastreticuleangle then
            dir = inst.lastreticuleangle
        else
            return nil
        end
    end

    local Camangle = TheCamera:GetHeading()/180
    local theta = -PI *(0.5 - Camangle)

    local newx = dir.x * math.cos(theta) - dir.z *math.sin(theta)
    local newz = dir.x * math.sin(theta) + dir.z *math.cos(theta)

    pos.x = pos.x - (newx * range)
    pos.z = pos.z - (newz * range)

    return pos
end

local function EnableBoatItemCollision(inst)
    if not inst.boat_item_collision then
        inst.boat_item_collision = SpawnPrefab(inst.item_collision_prefab)
        AddConstrainedPhysicsObj(inst, inst.boat_item_collision)
    end
end

local function DisableBoatItemCollision(inst)
    if inst.boat_item_collision then
        RemoveConstrainedPhysicsObj(inst.boat_item_collision) --also :Remove()s object
        inst.boat_item_collision = nil
    end
end

local function OnPhysicsWake(inst)
    EnableBoatItemCollision(inst)
    if inst.stopupdatingtask then
        inst.stopupdatingtask:Cancel()
        inst.stopupdatingtask = nil
    else
        inst.components.walkableplatform:StartUpdating()
    end
    inst.components.boatphysics:StartUpdating()
end

local function OnPhysicsSleep(inst)
    DisableBoatItemCollision(inst)
    inst.stopupdatingtask = inst:DoTaskInTime(1, function()
        inst.components.walkableplatform:StopUpdating()
        inst.stopupdatingtask = nil
    end)
    inst.components.boatphysics:StopUpdating()
end

local function StopBoatPhysics(inst)
    --Boats currently need to not go to sleep because
    --constraints will cause a crash if either the target object or the source object is removed from the physics world
    inst.Physics:SetDontRemoveOnSleep(false)
end

local function StartBoatPhysics(inst)
    inst.Physics:SetDontRemoveOnSleep(true)
end

local function speed(inst)
    if not inst.startpos then

        inst.startpos = Vector3(inst.Transform:GetWorldPosition())
        inst.starttime = GetTime()
        inst.speedtask = inst:DoPeriodicTask(FRAMES, function()
            local pt = Vector3(inst.Transform:GetWorldPosition())
            local dif = distsq(pt.x,pt.z,inst.startpos.x,inst.startpos.z)
            --print("DIST",dif,GetTime() - inst.starttime)
        end)
    else
        inst.startpos = nil
        inst.speedtask:Cancel()
        inst.speedtask = nil
        inst.starttime = nil
    end
end

local function SpawnFragment(lp, prefix, offset_x, offset_y, offset_z, ignite)
    local fragment = SpawnPrefab(prefix)
    fragment.Transform:SetPosition(lp.x + offset_x, lp.y + offset_y, lp.z + offset_z)

    if offset_y > 0 then
        local physics = fragment.Physics
        if physics ~= nil then
            physics:SetVel(0, -0.25, 0)
        end
    end

    if ignite then
        fragment.components.burnable:Ignite()
    end

    return fragment
end

local function OnEntityReplicated(inst)
    --Use this setting because we can rotate, and we are not billboarded with discreet anim facings
    --NOTE: this setting can only be applied after entity replicated
    inst.Transform:SetInterpolateRotation(true)
end

local function create_common_pre(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.MiniMapEntity:SetIcon("boat.png")
    inst.MiniMapEntity:SetPriority(-1)
    inst.entity:AddNetwork()

    inst:AddTag("ignorewalkableplatforms")
	inst:AddTag("antlion_sinkhole_blocker")
	inst:AddTag("boat")
    inst:AddTag("wood")

    local phys = inst.entity:AddPhysics()
    phys:SetMass(TUNING.BOAT.MASS)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.OBSTACLES)
    phys:ClearCollisionMask()
    phys:CollidesWith(COLLISION.WORLD)
    phys:CollidesWith(COLLISION.OBSTACLES)
    phys:SetCylinder(radius, 3)

    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_BOAT)
	inst.AnimState:SetFinalOffset(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)

    if scale then
        inst.AnimState:SetScale(scale,scale,scale)
    end

    inst:AddComponent("walkableplatform")
    inst.components.walkableplatform.platform_radius = radius


    inst:AddComponent("healthsyncer")
    inst.components.healthsyncer.max_health = max_health

    inst:AddComponent("waterphysics")
    inst.components.waterphysics.restitution = 0.75

    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = ReticuleTargetFn
    inst.components.reticule.ispassableatallpoints = true
    inst.on_start_steering = on_start_steering
    inst.on_stop_steering = on_stop_steering

    inst.doplatformcamerazoom = net_bool(inst.GUID, "doplatformcamerazoom", "doplatformcamerazoomdirty")

	if not TheNet:IsDedicated() then
        inst:ListenForEvent("endsteeringreticule", function(inst,data)  if ThePlayer and ThePlayer == data.player then inst:on_stop_steering() end end)
        inst:ListenForEvent("starsteeringreticule", function(inst,data) if ThePlayer and ThePlayer == data.player then inst:on_start_steering() end end)

        inst:AddComponent("boattrail")
	end

    inst:AddComponent("boatringdata")
    inst.components.boatringdata:SetRadius(radius)
    inst.components.boatringdata:SetNumSegments(8)

    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = OnEntityReplicated
    end

    return inst
end

local function create_master_pst(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip, plank_prefab)

    inst.Physics:SetDontRemoveOnSleep(true)
    inst.item_collision_prefab = item_collision_prefab
    EnableBoatItemCollision(inst)

    inst.entity:AddPhysicsWaker() --server only component
    inst.PhysicsWaker:SetTimeBetweenWakeTests(TUNING.BOAT.WAKE_TEST_TIME)

    inst:AddComponent("hull")
    inst.components.hull:SetRadius(radius)
    inst.components.hull:SetBoatLip(SpawnPrefab(boatlip),scale)

    local walking_plank = SpawnPrefab(plank_prefab or "walkingplank")
    local edge_offset = -0.05
    inst.components.hull:AttachEntityToBoat(walking_plank, 0, radius + edge_offset, true)
    inst.components.hull:SetPlank(walking_plank)

    inst:AddComponent("repairable")
    inst.components.repairable.repairmaterial = MATERIALS.WOOD
    inst.components.repairable.onrepaired = OnRepaired

    inst:AddComponent("boatring")

    inst:AddComponent("hullhealth")
    inst:AddComponent("boatphysics")
    inst:AddComponent("boatdrifter")
    inst:AddComponent("savedrotation")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(max_health)
    inst.components.health.nofadeout = true

	inst.activefires = 0

	local burnable_locator = SpawnPrefab("burnable_locator_medium")
	burnable_locator.boat = inst
	inst.components.hull:AttachEntityToBoat(burnable_locator, 0, 0, true)

	burnable_locator = SpawnPrefab("burnable_locator_medium")
	burnable_locator.boat = inst
	inst.components.hull:AttachEntityToBoat(burnable_locator, 2.5, 0, true)

	burnable_locator = SpawnPrefab("burnable_locator_medium")
	burnable_locator.boat = inst
	inst.components.hull:AttachEntityToBoat(burnable_locator, -2.5, 0, true)

	burnable_locator = SpawnPrefab("burnable_locator_medium")
	burnable_locator.boat = inst
	inst.components.hull:AttachEntityToBoat(burnable_locator, 0, 2.5, true)

	burnable_locator = SpawnPrefab("burnable_locator_medium")
	burnable_locator.boat = inst
	inst.components.hull:AttachEntityToBoat(burnable_locator, 0, -2.5, true)

    inst:SetStateGraph("SGboat")

    inst.StopBoatPhysics = StopBoatPhysics
    inst.StartBoatPhysics = StartBoatPhysics

    inst.OnPhysicsWake = OnPhysicsWake
    inst.OnPhysicsSleep = OnPhysicsSleep

    inst.sinkloot = function() end

    inst.speed = speed

    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

local function build_boat_collision_mesh(radius, height)
    local segment_count = 20
    local segment_span = math.pi * 2 / segment_count

    local triangles = {}
    local y0 = 0
    local y1 = height

    for segement_idx = 0, segment_count do

        local angle = segement_idx * segment_span
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

--local PLAYER_COLLISION_MESH = build_boat_collision_mesh(4.1, 3)
--local ITEM_COLLISION_MESH = build_boat_collision_mesh(4.2, 3)

local function boat_player_collision_template(radius)
    local inst = CreateEntity()

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    inst:AddTag("CLASSIFIED")

    local phys = inst.entity:AddPhysics()
    phys:SetMass(0)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
    phys:ClearCollisionMask()
    phys:CollidesWith(COLLISION.CHARACTERS)
    phys:CollidesWith(COLLISION.WORLD)
    phys:SetTriangleMesh(build_boat_collision_mesh(radius + 0.1, 3))

    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

    return inst
end

local function boat_item_collision_template(radius)
    local inst = CreateEntity()

    inst.entity:AddTransform()

    --[[Non-networked entity]]
    inst:AddTag("CLASSIFIED")

    local phys = inst.entity:AddPhysics()
    phys:SetMass(1000)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
    phys:ClearCollisionMask()
    phys:CollidesWith(COLLISION.ITEMS)
    phys:CollidesWith(COLLISION.FLYERS)
    phys:CollidesWith(COLLISION.WORLD)
    phys:SetTriangleMesh(build_boat_collision_mesh(radius + 0.2, 3))
    --Boats currently need to not go to sleep because
    --constraints will cause a crash if either the target object or the source object is removed from the physics world
    --while the above is still true, the constraint is now properly removed before despawning the object, and can be safely ignored for this object, kept for future copy/pasting.
    phys:SetDontRemoveOnSleep(true)

    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

local function ondeploy(inst, pt, deployer)
    local boat = SpawnPrefab(inst.deploy_product, inst.linked_skinname, inst.skin_id )
    if boat ~= nil then
        if boat.skinname ~= nil and boat.components.hull ~= nil then
            if boat.components.hull.plank.prefab == "walkingplank" then
                local plank_skinname = "walkingplank" .. string.sub(boat.skinname, 5)
                TheSim:ReskinEntity( boat.components.hull.plank.GUID, nil, plank_skinname, boat.skin_id )
            end
        end
        
        boat.Physics:SetCollides(false)
        boat.Physics:Teleport(pt.x, 0, pt.z)
        boat.Physics:SetCollides(true)

        boat.sg:GoToState("place")

		boat.components.hull:OnDeployed()

        inst:Remove()
    end
end

local function wood_fn()
    local inst = CreateEntity()

    local bank = "boat_01"
    local build = "boat_test"
    local radius = TUNING.BOAT.RADIUS
    local max_health = TUNING.BOAT.HEALTH
    local item_collision_prefab = "boat_item_collision"
    local scale = nil
    local boatlip = "boatlip"

    inst = create_common_pre(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)

    inst.walksound = "wood"

    inst.components.walkableplatform.player_collision_prefab = "boat_player_collision"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = create_master_pst(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)

	inst:ListenForEvent("spawnnewboatleak", OnSpawnNewBoatLeak)
    inst.boat_crackle = "fx_boat_crackle"

    inst.sinkloot = function()
            local ignitefragments = inst.activefires > 0
            local locus_point = Vector3(inst.Transform:GetWorldPosition())
            local num_loot = 3
            for i = 1, num_loot do
                local r = math.sqrt(math.random())*(TUNING.BOAT.RADIUS-2) + 1.5
                local t = i * PI2/num_loot + math.random() * (PI2/(num_loot * .5))
                SpawnFragment(locus_point, "boards",  math.cos(t) * r,  0, math.sin(t) * r, ignitefragments)
            end
        end

    inst.postsinkfn = function()
            local fx_boat_crackle = SpawnPrefab("fx_boat_pop")
            fx_boat_crackle.Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.SoundEmitter:PlaySoundWithParams(inst.sounds.damage, {intensity= 1})
            inst.SoundEmitter:PlaySoundWithParams(inst.sounds.sink)
        end

    inst.sounds = sounds

    return inst
end

local function grass_fn()
    local inst = CreateEntity()

    local bank = "boat_grass"
    local build = "boat_grass"
    local radius = TUNING.BOAT.GRASS_BOAT.RADIUS
    local max_health = TUNING.BOAT.HEALTH
    local item_collision_prefab = "boat_grass_item_collision"
    local scale = 0.75
    local boatlip = "boatlip_grass"
    local plank_prefab = "walkingplank_grass"

    inst = create_common_pre(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)

    inst.leaky = true
    inst.material = "grass"

    inst.MiniMapEntity:SetIcon("boat_grass.png")

    inst.walksound = "marsh" --"tallgrass"
    inst.second_walk_sound = "tallgrass"

    inst.components.walkableplatform.player_collision_prefab = "boat_grass_player_collision"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = create_master_pst(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip, plank_prefab)

	inst:ListenForEvent("spawnnewboatleak", OnSpawnNewBoatLeak_Grass)

    inst.components.hullhealth:SetSelfDegrading(5)
    inst.components.hullhealth.degradefx = "degrade_fx_grass"
    inst.components.hullhealth.leakproof = true

    inst.components.repairable.repairmaterial = MATERIALS.HAY

    inst.sinkloot = function()
            local ignitefragments = inst.activefires > 0
            local locus_point = Vector3(inst.Transform:GetWorldPosition())
            local num_loot = 6
            for i = 1, num_loot do
                local r = math.sqrt(math.random())*(TUNING.BOAT.RADIUS-2) + 1.5
                local t = i * PI2/num_loot + math.random() * (PI2/(num_loot * .5))
                SpawnFragment(locus_point, "cutgrass",  math.cos(t) * r,  0, math.sin(t) * r, ignitefragments)
            end
        end
    inst.sounds = sounds_grass
    inst.postsinkfn = function(inst)
                local erode = SpawnPrefab("boat_grass_erode")
                erode.Transform:SetPosition(inst.Transform:GetWorldPosition())
                local erode_water = SpawnPrefab("boat_grass_erode_water")
                erode_water.Transform:SetPosition(inst.Transform:GetWorldPosition())
            end

    return inst
end

local function pirate_fn()
    local inst = CreateEntity()

    local bank = "boat_01"
    local build = "boat_pirate"
    local radius = TUNING.BOAT.RADIUS
    local max_health = TUNING.BOAT.HEALTH
    local item_collision_prefab = "boat_item_collision"
    local scale = nil
    local boatlip = "boatlip"

    inst = create_common_pre(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)

    inst.MiniMapEntity:SetIcon("boat_pirate.png")

    inst.walksound = "wood"

    inst.components.walkableplatform.player_collision_prefab = "boat_player_collision"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = create_master_pst(inst, bank, build, radius, max_health, item_collision_prefab, scale, boatlip)

	inst:ListenForEvent("spawnnewboatleak", OnSpawnNewBoatLeak)
    inst.boat_crackle = "fx_boat_crackle"

    inst.sinkloot = function()
            local ignitefragments = inst.activefires > 0
            local locus_point = Vector3(inst.Transform:GetWorldPosition())
            local num_loot = 3
            for i = 1, num_loot do
                local r = math.sqrt(math.random())*(TUNING.BOAT.RADIUS-2) + 1.5
                local t = i * PI2/num_loot + math.random() * (PI2/(num_loot * .5))
                SpawnFragment(locus_point, "boards",  math.cos(t) * r,  0, math.sin(t) * r, ignitefragments)
            end
        end

    inst.postsinkfn = function()
            local fx_boat_crackle = SpawnPrefab("fx_boat_pop")
            fx_boat_crackle.Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.SoundEmitter:PlaySoundWithParams(inst.sounds.damage, {intensity= 1})
            inst.SoundEmitter:PlaySoundWithParams(inst.sounds.sink)
        end

    inst.sounds = sounds
    return inst
end

function CLIENT_CanDeployBoat(inst, pt, mouseover, deployer, rotation)
    return TheWorld.Map:CanDeployBoatAtPointInWater(pt, inst, mouseover,
    {
        boat_radius = inst._boat_radius,
        boat_extra_spacing = 0.2,
        min_distance_from_land = 0.2,
    })
end

local function common_item_fn_pre(inst)
    inst._custom_candeploy_fn = CLIENT_CanDeployBoat
    inst._boat_radius = TUNING.BOAT.RADIUS

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("boatbuilder")
    inst:AddTag("usedeployspacingasoffset")

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("seafarer_boat")
    inst.AnimState:SetBuild("seafarer_boat")
    inst.AnimState:PlayAnimation("IDLE")

    MakeInventoryFloatable(inst, "med", 0.25, 0.83)

    return inst
end

local function common_item_fn_pst(inst)
    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = ondeploy
    inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.LARGE)
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

    MakeLargeBurnable(inst)
    MakeLargePropagator(inst)
    MakeHauntableLaunch(inst)

    return inst
end

local function item_fn()
    local inst = CreateEntity()

    inst = common_item_fn_pre(inst)

    inst.deploy_product = "boat"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = common_item_fn_pst(inst)

    return inst
end

local function grass_item_fn()
    local inst = CreateEntity()

    inst = common_item_fn_pre(inst)
    inst._boat_radius = TUNING.BOAT.GRASS_BOAT.RADIUS

    inst.AnimState:SetBank("seafarer_boat")
    inst.AnimState:SetBuild("boat_grass_item")

    inst.deploy_product = "boat_grass"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst = common_item_fn_pst(inst)
    inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.PLACER_DEFAULT)

    return inst
end

local function boat_player_collision_fn()
    return boat_player_collision_template(TUNING.BOAT.RADIUS)
end

local function boat_item_collision_fn()
    return boat_item_collision_template(TUNING.BOAT.RADIUS)
end

local function boat_grass_player_collision_fn()
    return boat_player_collision_template(TUNING.BOAT.GRASS_BOAT.RADIUS)
end

local function boat_grass_item_collision_fn()
    return boat_item_collision_template(TUNING.BOAT.GRASS_BOAT.RADIUS)
end

return Prefab("boat", wood_fn, wood_assets, prefabs),
       Prefab("boat_grass", grass_fn, grass_assets, grass_prefabs),
       Prefab("boat_player_collision", boat_player_collision_fn),
       Prefab("boat_item_collision", boat_item_collision_fn),

       Prefab("boat_pirate", pirate_fn, pirate_assets, prefabs),

       Prefab("boat_grass_player_collision", boat_grass_player_collision_fn),
       Prefab("boat_grass_item_collision", boat_grass_item_collision_fn),

       Prefab("boat_item", item_fn, item_assets, item_prefabs),
       MakePlacer("boat_item_placer", "boat_01", "boat_test", "idle_full", true, false, false, nil, nil, nil, nil, 6),
       Prefab("boat_grass_item", grass_item_fn, grass_item_assets, grass_item_prefabs),
       MakePlacer("boat_grass_item_placer", "boat_grass", "boat_grass", "idle_full", true, false, false, 0.85, nil, nil, nil, 4.5)
