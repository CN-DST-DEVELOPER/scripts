require("components/raindome") --load some global functions defined for this component
require("components/temperatureoverrider") --load some global functions defined for this component

local GroundTiles = require("worldtiledefs")

--require_health being true means an entity is considered "dead" if it lacks the health replica.
function IsEntityDead(inst, require_health)
	local health = inst.replica.health
	if health == nil then
        return require_health == true
    end
	return health:IsDead()
end

function IsEntityDeadOrGhost(inst, require_health)
    if inst:HasTag("playerghost") then
        return true
    end
    return IsEntityDead(inst, require_health)
end

function IsEntityElectricImmune(inst)
    return inst:HasTag("electricdamageimmune") or (inst.components.inventory and inst.components.inventory:IsInsulated())
end

function GetStackSize(inst)
	local stackable = inst.replica.stackable
	return stackable and stackable:StackSize() or 1
end

function HandleDugGround(dug_ground, x, y, z)
    local spawnturf = GroundTiles.turf[dug_ground] or nil
    if spawnturf ~= nil then
        local loot = SpawnPrefab("turf_"..spawnturf.name)
        if loot.components.inventoryitem ~= nil then
			loot.components.inventoryitem:InheritWorldWetnessAtXZ(x, z)
        end
        loot.Transform:SetPosition(x, y, z)
        if loot.Physics ~= nil then
            local angle = math.random() * TWOPI
            loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))
        end
    else
        SpawnPrefab("sinkhole_spawn_fx_"..tostring(math.random(3))).Transform:SetPosition(x, y, z)
    end
end

local VIRTUALOCEAN_HASTAGS = {"virtualocean"}
local VIRTUALOCEAN_CANTTAGS = {"INLIMBO"}
function FindVirtualOceanEntity(x, y, z, r)
    local ents = TheSim:FindEntities(x, y, z, r or MAX_PHYSICS_RADIUS, VIRTUALOCEAN_HASTAGS, VIRTUALOCEAN_CANTTAGS)
    for _, ent in ipairs(ents) do
        if ent.Physics ~= nil then
            local radius = ent.Physics:GetRadius()
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            local dx, dz = ex - x, ez - z
            if dx * dx + dz * dz <= radius * radius then
                return ent
            end
        end
    end

    return nil
end

-- Use in your boats ondeploy
local ITEM_LAUNCHSPEED = 2
local ITEM_LAUNCHMULT = 1
local ITEM_STARTHEIGHT = 0.1
local ITEM_VERTICALSPEED = 0.1
local TIME_FOR_BOAT = .6
local IGNORE_WALKABLE_PLATFORM_TAGS = { "ignorewalkableplatforms", "activeprojectile", "flying", "FX", "DECOR", "INLIMBO", "herd", "walkableplatform" }
function PushAwayItemsOnBoatPlace(inst)
    local function launch_with_delay(item)
        Launch2(item, inst, ITEM_LAUNCHSPEED, ITEM_LAUNCHMULT, ITEM_STARTHEIGHT, inst.components.walkableplatform.platform_radius + item:GetPhysicsRadius(0.25), ITEM_VERTICALSPEED)

        if item.components.inventoryitem then
            item.components.inventoryitem:SetLanded(false, true)
        end
    end

    local pos = inst:GetPosition()
    local platform_radius_sq = inst.components.walkableplatform.platform_radius * inst.components.walkableplatform.platform_radius
    for i, v in ipairs(TheSim:FindEntities(pos.x, pos.y, pos.z, inst.components.walkableplatform.platform_radius, nil, IGNORE_WALKABLE_PLATFORM_TAGS)) do
        if v ~= inst and v.entity:GetParent() == nil and v.components.amphibiouscreature == nil and v.components.drownable == nil then
            local time = Remap(v:GetDistanceSqToPoint(pos),
                0, platform_radius_sq,
                0, TIME_FOR_BOAT)

            if v.special_item_boat_push_case then --Mods.
                v.special_item_boat_push_case(v, inst, time)
            elseif v:HasTag("bird") then
                v:PushEvent("flyaway")
            else
                v:DoTaskInTime(time, launch_with_delay)
            end
        end
    end
end

--------------------------------------------------------------------------
--Tags useful for testing against combat targets that you can hit,
--but aren't really considered "alive".

-- Lifedrain (Batbat, mauler) uses this list
NON_LIFEFORM_TARGET_TAGS =
{
	"structure",
	"wall",
	"balloon",
	"groundspike",
	"smashable",
	"veggie", --stuff like lureplants... not considered life?
    "deck_of_cards",
}

--Shadows and Gestalts don't have souls.
--NOTE: -Adding "soulless" tag to entities is preferred over expanding this list.
--      -Gestalts should already be using "soulless" tag.
SOULLESS_TARGET_TAGS = ConcatArrays(
	{
		"soulless",
		"chess",
		"shadow",
		"shadowcreature",
		"shadowminion",
		"shadowchesspiece",
	},
	NON_LIFEFORM_TARGET_TAGS
)

--------------------------------------------------------------------------
local IGNORE_DROWNING_ONREMOVE_TAGS = {"ignorewalkableplatforms", "ignorewalkableplatformdrowning", "activeprojectile", "flying", "FX", "DECOR", "INLIMBO"}
function TempTile_HandleTileChange_Ocean(x, y, z)
    local _world = TheWorld
    local _map = _world.Map
    -- If we're swapping to an ocean tile, do like a broken boat would do and deal with everything in our tile bounds
    -- Behaviour pulled from walkableplatform's onremove/DestroyObjectsOnPlatform response.
    local tile_radius_plus_overhang = ((TILE_SCALE / 2) + 1.0) * 1.4142
    local entities_near_tile = TheSim:FindEntities(x, 0, z, tile_radius_plus_overhang, nil, IGNORE_DROWNING_ONREMOVE_TAGS)

    local shore_point = nil
    for _, ent in ipairs(entities_near_tile) do
        local has_drownable = (ent.components.drownable ~= nil)
        if has_drownable and shore_point == nil then
            shore_point = Vector3(FindRandomPointOnShoreFromOcean(x, y, z))
        end
        ent:PushEvent("onsink", {boat = nil, shore_pt = shore_point})

        -- We're testing the overhang, so we need to verify that anything we find isn't
        -- still on some adjacent dock or land tile after we remove ourself.
        if ent:IsValid() and not has_drownable and ent.entity:GetParent() == nil
            and ent.components.amphibiouscreature == nil
            and not _map:IsVisualGroundAtPoint(ent.Transform:GetWorldPosition()) then

            if ent.components.inventoryitem ~= nil then
                ent.components.inventoryitem:SetLanded(false, true)
            else
                DestroyEntity(ent, _world, true, true)
            end
        end
    end
end
function TempTile_HandleTileChange_Ocean_Warn(x, y, z)
    local _map = TheWorld.Map
    -- Behaviour pulled from walkableplatform's onremove/DestroyObjectsOnPlatform response.
    local tile_radius_plus_overhang = ((TILE_SCALE / 2) + 1.0) * 1.4142
    local entities_near_tile = TheSim:FindEntities(x, 0, z, tile_radius_plus_overhang, nil, IGNORE_DROWNING_ONREMOVE_TAGS)

    for _, ent in ipairs(entities_near_tile) do
        -- Only push these events on prefabs that are actually standing on a temp tile.
        -- We use the VisualGround test because we're accounting for tile overhang.
        if _map:IsVisualGroundAtPoint(ent.Transform:GetWorldPosition()) then
            ent:PushEvent("abandon_ship")
            if ent:HasTag("player") then
                ent:PushEvent("onpresink")
            end
        end
    end
end
local IGNORE_FALLING_ONREMOVE_TAGS = {"ignorewalkableplatforms", "ignorewalkableplatformdrowning", "activeprojectile", "flying", "FX", "DECOR", "INLIMBO"}
function TempTile_HandleTileChange_Void(x, y, z)
    local _world = TheWorld
    local _map = _world.Map
    local tile_radius_plus_overhang = ((TILE_SCALE / 2) + 1.0) * 1.4142
    local entities_near_tile = TheSim:FindEntities(x, 0, z, tile_radius_plus_overhang, nil, IGNORE_FALLING_ONREMOVE_TAGS)

    local teleport_point = nil
    for _, ent in ipairs(entities_near_tile) do
        local drownable = ent.components.drownable
        if drownable and teleport_point == nil then
            teleport_point = Vector3(FindRandomPointOnShoreFromOcean(x, y, z))
        end
        ent:PushEvent("onfallinvoid", {teleport_pt = teleport_point})

        -- We're testing the overhang, so we need to verify that anything we find isn't
        -- still on some adjacent dock or land tile after we remove ourself.
        local canfallinvoid = drownable and ent.sg and ent.sg.sg.states.abyss_fall ~= nil -- NOTES(JBK): If things do not support the abyss_fall state we should kill it instead.
        if ent:IsValid() and not canfallinvoid and ent.entity:GetParent() == nil
            and not _map:IsVisualGroundAtPoint(ent.Transform:GetWorldPosition()) then

            if ent.components.inventoryitem ~= nil then
                ent.components.inventoryitem:SetLanded(false, true)
            else
                DestroyEntity(ent, _world, true, true)
            end
        end
    end
end
function TempTile_HandleTileChange_Void_Warn(x, y, z)
    local _map = TheWorld.Map
    local tile_radius_plus_overhang = ((TILE_SCALE / 2) + 1.0) * 1.4142
    local entities_near_tile = TheSim:FindEntities(x, 0, z, tile_radius_plus_overhang, nil, IGNORE_FALLING_ONREMOVE_TAGS)
    for _, ent in ipairs(entities_near_tile) do
        -- Only push these events on prefabs that are actually standing on a temp tile.
        -- We use the VisualGround test because we're accounting for tile overhang.
        if _map:IsVisualGroundAtPoint(ent.Transform:GetWorldPosition()) then
            ent:PushEvent("onprefallinvoid")
        end
    end
end

function TempTile_HandleTileChange(x, y, z, tile)
    if TileGroupManager:IsOceanTile(tile) then
        TempTile_HandleTileChange_Ocean(x, y, z)
    elseif TileGroupManager:IsInvalidTile(tile) then
        TempTile_HandleTileChange_Void(x, y, z)
    end
end
function TempTile_HandleTileChange_Warn(x, y, z, tile)
    if TileGroupManager:IsOceanTile(tile) then
        TempTile_HandleTileChange_Ocean_Warn(x, y, z)
    elseif TileGroupManager:IsInvalidTile(tile) then
        TempTile_HandleTileChange_Void_Warn(x, y, z)
    end
end

--------------------------------------------------------------------------
local function Bridge_DeployCheck_ShouldStopAtTile(tile) -- Internal.
    return TileGroupManager:IsTemporaryTile(tile) and tile ~= WORLD_TILES.FARMING_SOIL
end
local function Bridge_DeployCheck_CanStartAtTile(tile) -- Internal.
    return TileGroupManager:IsLandTile(tile) and not Bridge_DeployCheck_ShouldStopAtTile(tile)
end
local function Bridge_DeployCheck_HandleOverhangs(sx, sz, TILE_SCALE, _map) -- Internal.
    -- If a point lays on an overhang we need to adjust it so that it is not on an overhang by reflecting it over the tile border first.
    local cx, cy, cz = _map:GetTileCenterPoint(sx, 0, sz)
    local dx, dz = cx - sx, cz - sz
    local signdx, signdz = dx < 0 and -1 or 1, dz < 0 and -1 or 1
    local absdx, absdz = math.abs(dx), math.abs(dz)
    local ishorizontal = absdx > absdz
    local rsx, rsz, dirx, dirz
    if ishorizontal then
        rsx = sx + 2 * (absdx - TILE_SCALE * 0.5) * signdx
        rsz = sz
        dirx = signdx * TILE_SCALE
        dirz = 0
    else
        rsx = sx
        rsz = sz + 2 * (absdz - TILE_SCALE * 0.5) * signdz
        dirx = 0
        dirz = signdz * TILE_SCALE
    end
    if _map:IsLandTileAtPoint(rsx, 0, rsz) then
        return rsx, rsz, dirx, dirz
    end

    -- We have reflected from an overhang onto another overhang along a coastline fallback to rectangle direction.
    if not ishorizontal then -- Flip the logic so the reflection happens in the opposite direction.
        rsx = sx + 2 * (absdx - TILE_SCALE * 0.5) * signdx
        rsz = sz
        dirx = signdx * TILE_SCALE
        dirz = 0
    else
        rsx = sx
        rsz = sz + 2 * (absdz - TILE_SCALE * 0.5) * signdz
        dirx = 0
        dirz = signdz * TILE_SCALE
    end
    if _map:IsLandTileAtPoint(rsx, 0, rsz) then
        return rsx, rsz, dirx, dirz
    end

    -- We are on a corner of a tile reflect both points so we are on the solid tile first and then use non-overhang protocols.
    rsx = sx + 2 * (absdx - TILE_SCALE * 0.5) * signdx
    rsz = sz + 2 * (absdz - TILE_SCALE * 0.5) * signdz
    return rsx, rsz, nil, nil
end
local function Bridge_DeployCheck_HandleGround(sx, sz, TILE_SCALE, _map, isvalidtileforbridgeatpointfn) -- Internal.
    -- We are on a ground tile so we will first do a diamond direction check first and then a rectangle fallback.
    local cx, cy, cz = _map:GetTileCenterPoint(sx, 0, sz)
    local dx, dz = cx - sx, cz - sz
    local signdx, signdz = dx < 0 and -1 or 1, dz < 0 and -1 or 1
    local absdx, absdz = math.abs(dx), math.abs(dz)
    local ishorizontal = absdx > absdz
    local rsx, rsz, dirx, dirz
    if ishorizontal then
        rsx = sx + 2 * (absdx - TILE_SCALE * 0.5) * signdx
        rsz = sz
        dirx = -signdx * TILE_SCALE
        dirz = 0
    else
        rsx = sx
        rsz = sz + 2 * (absdz - TILE_SCALE * 0.5) * signdz
        dirx = 0
        dirz = -signdz * TILE_SCALE
    end
    if isvalidtileforbridgeatpointfn(_map, rsx, 0, rsz) then
        return dirx, dirz
    end

    -- Check the other adjacent diagonal path.
    if not ishorizontal then
        rsx = sx + 2 * (absdx - TILE_SCALE * 0.5) * signdx
        rsz = sz
        dirx = -signdx * TILE_SCALE
        dirz = 0
    else
        rsx = sx
        rsz = sz + 2 * (absdz - TILE_SCALE * 0.5) * signdz
        dirx = 0
        dirz = -signdz * TILE_SCALE
    end
    if isvalidtileforbridgeatpointfn(_map, rsx, 0, rsz) then
        return dirx, dirz
    end

    -- We are too far in land for tiles to be able to be chosen.
    return nil, nil
end
local function IsValidTileForBridgeAtPoint_Fallback(_map, x, y, z)
    return _map:IsValidTileForVineBridgeAtPoint(x, y, z)
end
local function CanDeployBridgeAtPoint_Fallback(_map, x, y, z)
    return _map:CanDeployVineBridgeAtPoint(x, y, z)
end
local function Bridge_Deploy_Raytrace(sx, sz, dirx, dirz, maxlength, _map, candeploybridgeatpointfn, inst) -- Internal.
    -- Scan for land.
    local hitland = false
    local spots
    for i = 0, maxlength do -- Intentionally 0 to max to have a + 1 for the end tile cap inclusion.
        sx, sz = sx + dirx, sz + dirz

        local pt_offseted = Point(sx, 0, sz)
        local tile_current = _map:GetTileAtPoint(sx, 0, sz)
        if TileGroupManager:IsLandTile(tile_current) then
            hitland = not Bridge_DeployCheck_ShouldStopAtTile(tile_current)
            break
        end

        -- Check for adjacent tiles to make sure those are not invisible tiles too.
        if GROUND_INVISIBLETILES[_map:GetTileAtPoint(sx + dirz, 0, sz + dirx)] or GROUND_INVISIBLETILES[_map:GetTileAtPoint(sx - dirz, 0, sz - dirx)] then
            return false
        end

        if not candeploybridgeatpointfn(_map, pt_offseted, inst) then
            return false
        end

        if not spots then
            spots = {}
        end
        table.insert(spots, pt_offseted)
    end

    if not hitland or not spots then
        return false
    end

    spots.direction = {x = dirx, z = dirz,}

    return true, spots
end
local function Bridge_Deploy_GetBestRayTrace(sx, sz, maxlength, _map, candeploybridgeatpointfn, inst) -- Internal.
    -- We have a point inside of a tile that we want to calculate out the best ray trace direction for.
    -- There are several cases and we will know what to do after we trace all directions.
    local cx, cy, cz = _map:GetTileCenterPoint(sx, 0, sz)
    local success_N, spots_N
    local success_E, spots_E
    local success_S, spots_S
    local success_W, spots_W
    if Bridge_DeployCheck_CanStartAtTile(_map:GetTileAtPoint(cx, 0, cz - TILE_SCALE)) then
        success_N, spots_N = Bridge_Deploy_Raytrace(cx, cz - TILE_SCALE, 0, TILE_SCALE, maxlength, _map, candeploybridgeatpointfn, inst)
    else
        success_N = false
    end
    if Bridge_DeployCheck_CanStartAtTile(_map:GetTileAtPoint(cx - TILE_SCALE, 0, cz)) then
        success_E, spots_E = Bridge_Deploy_Raytrace(cx - TILE_SCALE, cz, TILE_SCALE, 0, maxlength, _map, candeploybridgeatpointfn, inst)
    else
        success_E = false
    end
    if Bridge_DeployCheck_CanStartAtTile(_map:GetTileAtPoint(cx, 0, cz + TILE_SCALE)) then
        success_S, spots_S = Bridge_Deploy_Raytrace(cx, cz + TILE_SCALE, 0, -TILE_SCALE, maxlength, _map, candeploybridgeatpointfn, inst)
    else
        success_S = false
    end
    if Bridge_DeployCheck_CanStartAtTile(_map:GetTileAtPoint(cx + TILE_SCALE, 0, cz)) then
        success_W, spots_W = Bridge_Deploy_Raytrace(cx + TILE_SCALE, cz, -TILE_SCALE, 0, maxlength, _map, candeploybridgeatpointfn, inst)
    else
        success_W = false
    end
    local success_count = (success_N and 1 or 0) + (success_E and 1 or 0) + (success_S and 1 or 0) + (success_W and 1 or 0)
    if success_count == 0 then -- Nothing valid.
        return false
    elseif success_count == 1 then -- One edge is valid.
        return true, spots_N or spots_E or spots_S or spots_W
    elseif success_count == 2 then -- Two edges are valid check which direction.
        if success_N and success_S or success_E and success_W then -- Opposite sides.
            if success_N then -- N-S
                if cz < sz then
                    return true, spots_N
                else
                    return true, spots_S
                end
            else -- E-W
                if cx < sx then
                    return true, spots_E
                else
                    return true, spots_W
                end
            end
        else -- Corner.
            local ishorizontal = math.abs(cx - sx) > math.abs(cz - sz)
            if success_N and success_E then
                if cx - sx < cz - sz then
                    return true, spots_E
                else
                    return true, spots_N
                end
            elseif success_E and success_S then
                if sx - cx > cz - sz then
                    return true, spots_E
                else
                    return true, spots_S
                end
            elseif success_S and success_W then
                if cx - sx > cz - sz then
                    return true, spots_W
                else
                    return true, spots_S
                end
            else -- W-N
                if sx - cx < cz - sz then
                    return true, spots_W
                else
                    return true, spots_N
                end
            end
        end
    elseif success_count == 3 then -- U shape. We will aim to go out of the U because it will always be longer.
        if not success_N then
            return true, spots_S
        elseif not success_E then
            return true, spots_W
        elseif not success_S then
            return true, spots_N
        else -- not success_W
            return true, spots_E
        end
    else -- Square shape. Do not let it be placed here.
        return false
    end
end
function Bridge_DeployCheck_Helper(inst, pt, options)
    local _world = TheWorld
    if _world.ismastersim then
        local requiredworldcomponent = options and options.requiredworldcomponent or nil
        if requiredworldcomponent and not _world.components[requiredworldcomponent] then
            return false
        end
    end

    local _map = _world.Map
    local TILE_SCALE = TILE_SCALE
    local maxlength = options and options.maxlength or TUNING.ROPEBRIDGE_LENGTH_TILES
    local isvalidtileforbridgeatpointfn = options and options.isvalidtileforbridgeatpointfn or IsValidTileForBridgeAtPoint_Fallback
    local candeploybridgeatpointfn = options and options.candeploybridgeatpointfn or CanDeployBridgeAtPoint_Fallback
    local deployskipfirstlandtile = options and options.deployskipfirstlandtile

    -- NOTES(JBK): We want the player position to not be involved for the bridge construction at all.
    -- So we will need to transform the point into a position that makes the most sense given the geometric nature of tiles.
    local sx, sy, sz = pt:Get()
    local osx, osy, osz = sx, sy, sz
    local dirx, dirz

    if isvalidtileforbridgeatpointfn(_map, sx, 0, sz) then
        if deployskipfirstlandtile then
            return Bridge_Deploy_GetBestRayTrace(sx, sz, maxlength, _map, candeploybridgeatpointfn, inst)
        elseif _map:IsVisualGroundAtPoint(sx, 0, sz) then
            sx, sz, dirx, dirz = Bridge_DeployCheck_HandleOverhangs(sx, sz, TILE_SCALE, _map)
        end
    end
    
    if dirx == nil then
        if deployskipfirstlandtile then
            return false
        end

        if not _map:IsLandTileAtPoint(sx, 0, sz) then
            return false
        end

        dirx, dirz = Bridge_DeployCheck_HandleGround(sx, sz, TILE_SCALE, _map, isvalidtileforbridgeatpointfn)
    end

    if dirx == nil then
        return false
    end

    local tile = _map:GetTileAtPoint(sx, 0, sz)
    if Bridge_DeployCheck_ShouldStopAtTile(tile) then
        return false
    end

    -- We now have a valid direction and starting point align our tile ray trace to tile coordinates finally.
    sx, sy, sz = _map:GetTileCenterPoint(sx, 0, sz)
    local success, spots = Bridge_Deploy_Raytrace(sx, sz, dirx, dirz, maxlength, _map, candeploybridgeatpointfn, inst)
    if success then
        return success, spots
    end

    return false
end

--------------------------------------------------------------------------
function DecayCharlieResidueAndGoOnCooldownIfItExists(inst)
    local roseinspectableuser = inst.components.roseinspectableuser
    if roseinspectableuser == nil then
        return
    end
    roseinspectableuser:ForceDecayResidue()
    roseinspectableuser:GoOnCooldown()
end
function DecayCharlieResidueIfItExists(inst)
    local roseinspectableuser = inst.components.roseinspectableuser
    if roseinspectableuser == nil then
        return
    end
    roseinspectableuser:ForceDecayResidue()
end

local function OnFuelPresentation3(inst)
    inst:ReturnToScene()
    if inst.components.inventoryitem ~= nil then
        inst.components.inventoryitem:OnDropped(true, .5)
    end
end
local function OnFuelPresentation2(inst, x, z, upgraded)
    local fx = SpawnPrefab(upgraded and "shadow_puff_solid" or "shadow_puff")
    fx.Transform:SetPosition(x, 0, z)
    inst:DoTaskInTime(3 * FRAMES, OnFuelPresentation3)
end
local function OnFuelPresentation1(inst, x, z, upgraded)
    local fx = SpawnPrefab((upgraded or TheWorld:HasTag("cave")) and "charlie_snap_solid" or "charlie_snap")
    fx.Transform:SetPosition(x, 2, z)
    inst:DoTaskInTime(25 * FRAMES, OnFuelPresentation2, x, z, upgraded)
end
local function OnResidueActivated_Fuel_Internal(inst, doer, odds)
    local skilltreeupdater = doer.components.skilltreeupdater
    local upgraded = skilltreeupdater and skilltreeupdater:IsActivated("winona_charlie_2") and TryLuckRoll(doer, odds, LuckFormulas.ResidueUpgradeFuel) or nil
    local fuel = SpawnPrefab(upgraded and "horrorfuel" or "nightmarefuel")
    fuel:RemoveFromScene()
    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = inst:GetPhysicsRadius(0)
    if radius > 0 then
        radius = radius + 1.5
    end
    local theta = math.random() * PI2
    x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    fuel.Transform:SetPosition(x, 0, z)
    fuel:DoTaskInTime(0.5, OnFuelPresentation1, x, z, upgraded)
end
local function OnResidueActivated_Fuel(inst, doer)
    OnResidueActivated_Fuel_Internal(inst, doer, TUNING.SKILLS.WINONA.ROSEGLASSES_UPGRADE_CHANCE)
end
local function OnResidueActivated_Fuel_IncreasedHorror(inst, doer)
    OnResidueActivated_Fuel_Internal(inst, doer, TUNING.SKILLS.WINONA.ROSEGLASSES_UPGRADE_CHANCE_INCREASED)
end
function MakeRoseTarget_CreateFuel(inst)
    local roseinspectable = inst:AddComponent("roseinspectable")
    roseinspectable:SetOnResidueActivated(OnResidueActivated_Fuel)
    roseinspectable:SetForcedInduceCooldownOnActivate(true)
end
function MakeRoseTarget_CreateFuel_IncreasedHorror(inst)
    local roseinspectable = inst:AddComponent("roseinspectable")
    roseinspectable:SetOnResidueActivated(OnResidueActivated_Fuel_IncreasedHorror)
    roseinspectable:SetForcedInduceCooldownOnActivate(true)
end
--------------------------------------------------------------------------
local function IsValidTileForVineBridgeAtPoint_Wrapper(_map, x, y, z)
    return _map:IsValidTileForVineBridgeAtPoint(x, y, z)
end
local function CanDeployVineBridgeAtPoint_Wrapper(_map, x, y, z)
    return _map:CanDeployVineBridgeAtPoint(x, y, z)
end
local RosePoint_VineBridge_Options = {
    maxlength = TUNING.SKILLS.WINONA.CHARLIE_VINEBRIDGE_LENGTH_TILES,
    isvalidtileforbridgeatpointfn = IsValidTileForVineBridgeAtPoint_Wrapper,
    candeploybridgeatpointfn = CanDeployVineBridgeAtPoint_Wrapper,
    requiredworldcomponent = "vinebridgemanager",
}
local function RosePoint_VineBridge_Check(inst, pt)
    return Bridge_DeployCheck_Helper(inst, pt, RosePoint_VineBridge_Options)
end
local function RosePoint_VineBridge_Do(inst, pt, spots)
    local vinebridgemanager = TheWorld.components.vinebridgemanager
    local duration = TUNING.VINEBRIDGE_DURATION
    local breakdata = {}
    local spawndata = {
        base_time = 0.5,
        random_time = 0.0,
        direction = spots.direction,
    }
    for i, spot in ipairs(spots) do
        spawndata.base_time = 0.25 * i
        vinebridgemanager:QueueCreateVineBridgeAtPoint(spot.x, spot.y, spot.z, spawndata)
        breakdata.fxtime = duration + 0.25 * i
        breakdata.shaketime = breakdata.fxtime - 1
        breakdata.destroytime = breakdata.fxtime + 70 * FRAMES
        vinebridgemanager:QueueDestroyForVineBridgeAtPoint(spot.x, spot.y, spot.z, breakdata)
    end
    return true
end
-- NOTES(JBK): Functions and names for CLOSEINSPECTORUTIL checks.
-- The order of priority is defined by what is present in this table use the contextname to table.insert new ones.
ROSEPOINT_CONFIGURATIONS = {
    {
        contextname = "Vine Bridge",
        checkfn = RosePoint_VineBridge_Check,
        callbackfn = RosePoint_VineBridge_Do,
        --forcedcooldown = nil,
        --cooldownfn = nil,
    },
}

--------------------------------------------------------------------------
--closeinspector

CLOSEINSPECTORUTIL = {}

CLOSEINSPECTORUTIL.IsValidTarget = function(doer, target)
    if TheWorld.ismastersim then
        return not (
            (target.Physics and target.Physics:GetMass() ~= 0) or
            target.components.locomotor or
            target.components.inventoryitem or
            target:HasTag("character")
        )
    else
        return not (
            (target.Physics and target.Physics:GetMass() ~= 0) or
            target:HasTag("locomotor") or
            target.replica.inventoryitem or
            target:HasTag("character")
        )
    end
end

CLOSEINSPECTORUTIL.IsValidPos = function(doer, pos)
    local is_cooldown_rose = true
    local player_classified = doer.player_classified
    if player_classified then
        is_cooldown_rose = player_classified.roseglasses_cooldown:value()
    end
    for _, config in ipairs(ROSEPOINT_CONFIGURATIONS) do
        local will_cooldown = false
        if config.forcedcooldown ~= nil then
            will_cooldown = config.forcedcooldown
        elseif config.cooldownfn ~= nil then
            will_cooldown = config.cooldownfn(self.inst, self.point, data)
        end
        if not will_cooldown or (will_cooldown and not is_cooldown_rose) then
            if config.checkfn(doer, pos) then
                return true
            end
        end
    end

    return false
end

CLOSEINSPECTORUTIL.CanCloseInspect = function(doer, targetorpos)
	if doer == nil then
		return false
	elseif TheWorld.ismastersim then
		if not (doer.components.inventory and doer.components.inventory:EquipHasTag("closeinspector")) or
			(doer.components.rider and doer.components.rider:IsRiding())
		then
			return false
		end
	else
		local inventory = doer.replica.inventory
		if not (inventory and inventory:EquipHasTag("closeinspector")) then
			return false
		end
		local rider = doer.replica.rider
		if rider and rider:IsRiding() then
			return false
		end
	end

	if targetorpos:is_a(EntityScript) then
		return targetorpos:IsValid() and CLOSEINSPECTORUTIL.IsValidTarget(doer, targetorpos)
	end
	return CLOSEINSPECTORUTIL.IsValidPos(doer, targetorpos)
end

--------------------------------------------------------------------------
-- rabbitkingmanager and rabbit prefabs
function HasMeatInInventoryFor_Checker(item)
    return item.components.edible ~= nil and item.components.edible.foodtype == FOODTYPE.MEAT and not item:HasTag("smallcreature")
end
function HasMeatInInventoryFor(inst)
    local inventory = inst.components.inventory
    if inventory == nil then
        return false
    end
    if inventory:EquipHasTag("hidesmeats") then
        return false
    end
    return inventory:FindItem(HasMeatInInventoryFor_Checker) ~= nil
end

--------------------------------------------------------------------------
-- These may be used on both client and server so have the callbacks acceptable for both uses.
-- Return nil for no count logic and go back to default logic.

-- For items going into a player's inventory.
-- TODO(JBK): Logic for swapping items is not handled.
DesiredMaxTakeCountFunctions = {}
function SetDesiredMaxTakeCountFunction(prefab, callback)
    DesiredMaxTakeCountFunctions[prefab] = callback
end
function GetDesiredMaxTakeCountFunction(prefab)
    return DesiredMaxTakeCountFunctions[prefab]
end

-- For items going out of a player's inventory they need their own support added.
--DesiredMaxPutCountFunctions = {}
--function SetDesiredMaxPutCountFunction(prefab, callback)
--    DesiredMaxPutCountFunctions[prefab] = callback
--end
--function GetDesiredMaxPutCountFunction(prefab)
--    return DesiredMaxPutCountFunctions[prefab]
--end

--------------------------------------------------------------------------

PICKABLE_FOOD_PRODUCTS =
{
    ancientfruit_nightvision = true,
    berries = true,
    berries_juicy = true,
    blue_cap = true,
    cactus_meat = true,
    carrot = true,
    cave_banana = true,
    cutlichen = true,
    green_cap = true,
    red_cap = true,
    wormlight_lesser = true,
}

function IsFoodSourcePickable(inst)
    return inst.components.pickable ~= nil and PICKABLE_FOOD_PRODUCTS[inst.components.pickable.product]
end

--------------------------------------------------------------------------
-- wobycourier

function GetWobyCourierChestPosition(inst)
    if inst.woby_commands_classified then
        local x = inst.woby_commands_classified.chest_posx:value()
        local z = inst.woby_commands_classified.chest_posz:value()
        if x ~= WOBYCOURIER_NO_CHEST_COORD and z ~= WOBYCOURIER_NO_CHEST_COORD then
            return x, z
        end
    end
    return nil, nil
end

--------------------------------------------------------------------------
-- Placer

HAS_AXISALIGNED_MOD_ENABLED = nil
KNOWN_AXISALIGNED_MODS = {
    "workshop-351325790",
}

function UpdateAxisAlignmentValues(intervals)
    TUNING.AXISALIGNEDPLACEMENT_INTERVALS = intervals
    TUNING.AXISALIGNEDPLACEMENT_CIRCLESIZE = math.min(8 / intervals, 4)
    if ThePlayer then
        ThePlayer:PushEvent("refreshaxisalignedplacementintervals")
    end
end

local DEFAULT_AXISALIGNMENT_VALUE = 1
AXISALIGNMENT_VALUES = {
    {text = STRINGS.UI.OPTIONS.AXISALIGNEDPLACEMENT_SIZE_HALFWALL, data = 2},
    {text = STRINGS.UI.OPTIONS.AXISALIGNEDPLACEMENT_SIZE_WALL, data = DEFAULT_AXISALIGNMENT_VALUE},
    {text = STRINGS.UI.OPTIONS.AXISALIGNEDPLACEMENT_SIZE_HALFTILE, data = 0.5},
    {text = STRINGS.UI.OPTIONS.AXISALIGNEDPLACEMENT_SIZE_TILE, data = 0.25},
}
function CycleAxisAlignmentValues() -- Do not save with Profile.
    local closestdiff
    local closestindex
    local intervals = TUNING.AXISALIGNEDPLACEMENT_INTERVALS
    local defaultindex
    for i, v in ipairs(AXISALIGNMENT_VALUES) do
        local diff = math.abs(v.data - intervals)
        if closestdiff == nil or diff < closestdiff then
            closestdiff = diff
            closestindex = i
        end
        if v.data == DEFAULT_AXISALIGNMENT_VALUE then
            defaultindex = i
        end
    end
    if not closestindex then
        closestindex = defaultindex or 1 -- Default got eliminated somewhere.
    end

    closestindex = closestindex + 1
    if closestindex > #AXISALIGNMENT_VALUES then
        closestindex = 1
    end

    UpdateAxisAlignmentValues(AXISALIGNMENT_VALUES[closestindex].data)
end

--------------------------------------------------------------------------
-- wagpunk_arena_manager
WAGPUNK_ARENA_COLLISION_DATA = { -- x, z, rotation, sfxlooper
    {-28, -20, 315, false},
    {-28, -10, 0, false},
    {-28, 0, 0, true},
    {-28, 10, 0, false},
    {-28, 20, 45, false},
    {-24, 20, 45, false},
    {-24, 24, 45, true},
    {-20, 24, 45, false},
    {-20, 28, 45, false},
    {-10, 28, 90, false},
    {0, 28, 90, true},
    {10, 28, 90, false},
    {20, 28, 135, false},
    {20, 24, 135, false},
    {24, 24, 135, true},
    {24, 20, 135, false},
    {28, 20, 135, false},
    {28, 10, 180, false},
    {28, 0, 180, true},
    {28, -10, 180, false},
    {28, -20, 225, false},
    {24, -20, 225, false},
    {24, -24, 225, true},
    {20, -24, 225, false},
    {20, -28, 225, false},
    {10, -28, 270, false},
    {0, -28, 270, true},
    {-10, -28, 270, false},
    {-20, -28, 315, false},
    {-20, -24, 315, false},
    {-24, -24, 315, true},
    {-24, -20, 315, false},
}

--------------------------------------------------------------------------

local CLEARSPOT_CANT_TAGS = {"INLIMBO", "NOCLICK", "FX", "irreplaceable"}
function ClearSpotForRequiredPrefabAtXZ(x, z, r)
    local _world = TheWorld
    local ents = TheSim:FindEntities(x, 0, z, MAX_PHYSICS_RADIUS, nil, CLEARSPOT_CANT_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() then
            local radius = ent:GetPhysicsRadius(0) + r
            if ent:GetDistanceSqToPoint(x, 0, z) < radius * radius then
                DestroyEntity(ent, _world)
            end
        end
    end
end

--------------------------------------------------------------------------
--For visual fx
--e.g. used by electrocute_fx

local function IsSmallCreature(inst)
    return inst:HasAnyTag("smallcreature", "smallcreaturecorpse", "small")
end

local function IsEpicCreature(inst)
    return inst:HasAnyTag("epic", "epiccorpse")
end

local function IsLargeCreature(inst)
    return inst:HasAnyTag("largecreature", "largecreaturecorpse", "large")
end

function GetCombatFxSize(ent)
	local r = ent.override_combat_fx_radius
	local sz = ent.override_combat_fx_size
	local ht = ent.override_combat_fx_height

	local r1 = r or ent:GetPhysicsRadius(0)
	if IsSmallCreature(ent) then
		r = r or math.min(0.5, r1)
		sz = sz or "tiny"
	elseif r1 >= 1.5 or IsEpicCreature(ent) then
		r = r or math.max(1.5, r1)
		sz = sz or "large"
	elseif r1 >= 0.9 or IsLargeCreature(ent) then
		r = r or math.max(1, r1)
		sz = sz or "med"
	else
		r = r or math.max(0.5, r1)
		sz = sz or "small"
	end

	if ht == nil then
		ht = (ent.components.amphibiouscreature and ent.components.amphibiouscreature.in_water and "low") or
			(ent:HasTag("flying") and "high") or
			(not (ent.sg and ent.sg:HasState("electrocute")) and "low") or --ground plants with no electrocute state
            (ent:HasTag("creaturecorpse") and "low") or
			nil
	elseif string.len(ht) == 0 then
		ht = nil
	end

	return r, sz, ht
end

function GetElectrocuteFxAnim(sz, ht)
	return string.format(ht and "shock_%s_%s" or "shock_%s", sz or "small", ht)
end

--Returns true if entity supports electrocution at all, even if it's in a state that currently doesn't allow it
function CanEntityBeElectrocuted(inst)
	return inst.sg
		and (inst.sg:HasState("electrocute") or inst.sg.mem.burn_on_electrocute)
		and not inst.sg.mem.noelectrocute
end

function CalcEntityElectrocuteDuration(inst, override)
	local default = TUNING.ELECTROCUTE_DEFAULT_DURATION
	local duration =
		inst.electrocute_duration or
		(inst.sg and inst.sg.mem.burn_on_electrocute and TUNING.ELECTROCUTE_SHORT_DURATION) or
		default

	if override then
		if override > default then
			return math.max(duration, override)
		elseif override < default then
			return math.min(duration, override)
		end
	end
	return duration
end

--------------------------------------------------------------------------

function SpawnElectricHitSparks(inst, target, flash)
    --target or inst might be removed
    if not inst or not target or not inst:IsValid() or not target:IsValid() then
        return
    end

    local fx_prefab = IsEntityElectricImmune(target) and "electrichitsparks_electricimmune" or "electrichitsparks"
    SpawnPrefab(fx_prefab):AlignToTarget(target, inst, flash)
end

function LightningStrikeAttack(inst)
    if IsEntityElectricImmune(inst) or (inst.sg and inst.sg:HasStateTag("noelectrocute")) then
        return false
    end

    if inst.components.health then
        local wetness_mult = TUNING.ELECTRIC_WET_DAMAGE_MULT * inst:GetWetMultiplier()
        local damage = TUNING.LIGHTNING_DAMAGE + wetness_mult * TUNING.LIGHTNING_DAMAGE
        inst.components.health:DoDelta(-damage, false, "lightning")
    end
	--V2C: -switched to stategraph event instead of GoToState
	--     -use Immediate to preserve legacy timing
	inst:PushEventImmediate("electrocute")

    -- NOTE(Omar): I really wanted to improve lightning damage technicals to use GetAttacked, but weather.lua is set up a bit awkwardly with the spawning of the entity,
    -- and it's prefab is to be determined during logic, so whatever, health:DoDelta and PushEvent, you're here to stay -__-
    --inst.components.combat:GetAttacked(lightning, damage, nil, "electric")
    return true
end

local LIGHTNING_EXCLUDE_TAGS = { "player", "INLIMBO", "lightningblocker", "FX" }
local LIGHTNING_BURNING_ONEOF_TAGS = {"wall", "fence", "plant", "structure", "_inventoryitem", "bush", "pickable"}

for k, v in pairs(FUELTYPE) do
    if v ~= FUELTYPE.USAGE then --Not a real fuel
        table.insert(LIGHTNING_EXCLUDE_TAGS, v.."_fueled")
    end
end

-- If we hit a player, do the aoe burn
-- If we hit just the ground, do a aoe shock and aoe burn.
-- If something is already shocked, it shouldnt burnt!

function StrikeLightningAtPoint(strike_prefab, hit_player, x, y, z)
    if y == nil and z == nil then --support Vector3 passed as x
        x, y, z = x:Get()
    end

    -- NO aoe shock or burn on moon lightning! Maybe a new effect?
    if strike_prefab == "lightning" then
        local data = {hit_player = hit_player, pos = Vector3(x,y,z)}
        local ents = TheSim:FindEntities(x, y, z, TUNING.LIGHTNING_STRIKE_RADIUS, nil, LIGHTNING_EXCLUDE_TAGS)
        for _, ent in pairs(ents) do
            if not IsEntityElectricImmune(ent) then
                if CanEntityBeElectrocuted(ent) then
                    if not hit_player then
                        LightningStrikeAttack(ent)
                    end
                elseif ent.components.burnable and ent:HasAnyTag(LIGHTNING_BURNING_ONEOF_TAGS) then
                    ent.components.burnable:Ignite()
                end

                if ent.lightning_strike_cb then --Mods, if they want any unique behaviour for themselves
                    ent.lightning_strike_cb(ent, data)
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- worldmigrator
local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
function GetMigrationPortalFromMigrationData(migrationdata)
    if migrationdata.worldid ~= nil and migrationdata.portalid ~= nil then
        for i, v in ipairs(ShardPortals) do
            local worldmigrator = v.components.worldmigrator
            if worldmigrator ~= nil and worldmigrator:IsDestinationForPortal(migrationdata.worldid, migrationdata.portalid) then
                return v
            end
        end
    end

    return nil
end
function GetMigrationPortalLocation(ent, migrationdata, portaloverride)
    local isplayer = ent:HasTag("player")
    local portal = portaloverride or GetMigrationPortalFromMigrationData(migrationdata)

    if portal ~= nil then
        if isplayer then
            print("Migrating prefab " .. (ent.prefab or "n/a") .. " will spawn close to portal ID: " .. tostring(portal.components.worldmigrator.id))
        end
        local x, y, z = portal.Transform:GetWorldPosition()
        local offset = FindWalkableOffset(Vector3(x, 0, z), math.random() * TWOPI, portal:GetPhysicsRadius(0) + .5, 8, false, true, NoHoles)

        --V2C: Do this after caching physical values, since it might remove itself
        --     and spawn in a new "opened" version, making "portal" invalid.
        portal.components.worldmigrator:ActivatedByOther()

        if offset ~= nil then
            return x + offset.x, 0, z + offset.z
        end
        return x, 0, z
    elseif migrationdata.dest_x ~= nil and migrationdata.dest_y ~= nil and migrationdata.dest_z ~= nil then
        local pt = Vector3(migrationdata.dest_x, migrationdata.dest_y, migrationdata.dest_z)
        if isplayer then
            print("Migrating prefab " .. (ent.prefab or "n/a") .. " will spawn near " .. tostring(pt))
        end
        pt = pt + (FindWalkableOffset(pt, math.random() * TWOPI, 2, 8, false, true, NoHoles) or Vector3(0,0,0))
        return pt:Get()
    else
        if isplayer then
            print("Migrating prefab " .. (ent.prefab or "n/a") .. " will spawn at default location")
        end
        return TheWorld.components.playerspawner:GetAnySpawnPoint()
    end
end

--------------------------------------------------------------------------
--Custom passable ground tests useful for stategraph actions like dashing etc.

local function _ispassable(x, y, z, allow_water, exclude_boats)
	return TheWorld.Map:IsPassableAtPoint(x, y, z, allow_water, exclude_boats)
end

local function _ispassable_inarena(x, y, z)--, allow_water, exclude_boats)
	return TheWorld.Map:IsPointInWagPunkArena(x, y, z)
end

local function _ispassable_vault(x, y, z)--, allow_water, exclude_boats)
	local map = TheWorld.Map
	return map:IsPointInAnyVault(x, y, z)
		and map:IsPassableAtPoint(x, y, z, false, true)
end

function GetActionPassableTestFnAt(x, y, z)
	local map = TheWorld.Map
	local platform = map:GetPlatformAtPoint(x, y, z)
	if platform and platform:HasTag("teeteringplatform") then
		return function(x1, y1, z1)--, allow_water, exclude_boats)
			return map:GetPlatformAtPoint(x1, y1, z1) == platform
		end, true
	elseif map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z) then
		return _ispassable_inarena, true
	elseif map:IsPointInAnyVault(x, y, z) then
		return _ispassable_vault, true
	end
	return _ispassable--, false --false because it's the default passable check
end

function GetActionPassableTestFn(inst)
	return GetActionPassableTestFnAt(inst.Transform:GetWorldPosition())
end

--------------------------------------------------------------------------

--Mutation stuff

function EntityHasCorpse(inst)
    return inst.sg and inst.sg:HasState("corpse")
        and not inst.sg.mem.nocorpse
end

function CanEntityBeGestaltMutated(inst)
    return inst.sg and inst.sg:HasState("corpse_lunarrift_mutate")
        and not inst.sg.mem.nolunarmutate
        and (inst.spawn_gestalt_mutated_tuning == nil or TUNING[inst.spawn_gestalt_mutated_tuning])
end

function CanEntityBeNonGestaltMutated(inst)
    return inst.sg and inst.sg:HasState("corpse_prerift_mutate")
        and not inst.sg.mem.nolunarmutate
        and (inst.spawn_lunar_mutated_tuning == nil or TUNING[inst.spawn_lunar_mutated_tuning])
end

function GetLunarPreRiftMutationChance(inst)
    return (
        FunctionOrValue(inst.lunar_mutation_chance, inst) or TUNING.PRERIFT_MUTATION_SPAWN_CHANCE
    ) * TheWorld.Map:GetLunacyAreaModifier(inst.Transform:GetWorldPosition())
end

function GetLunarRiftMutationChance(inst)
    return inst.gestalt_possession_chance or 1
end

local function GetCauseOfDeath(inst)
    local health = inst.components.health
    return (health and health.causeofdeath and health.causeofdeath:IsValid() and health.causeofdeath)
        or nil
end

function CanLunarPreRiftMutateFromCorpse(inst)
    if not CanEntityBeNonGestaltMutated(inst) then
        return false
    elseif inst.spawn_lunar_mutated_tuning and not TUNING[inst.spawn_lunar_mutated_tuning] then
        return false
    elseif inst.components.amphibiouscreature ~= nil and inst.components.amphibiouscreature.in_water then
        return false
    elseif inst.forcemutate then
        return true
    elseif inst.components.burnable and inst.components.burnable:IsBurning() then
        return false
    elseif inst._cached_prerift_mutation_result ~= nil then -- We might run this function multiple times.
        return inst._cached_prerift_mutation_result
    end

    local killer = GetCauseOfDeath(inst)
    inst._cached_prerift_mutation_result = TryLuckRoll(killer, GetLunarPreRiftMutationChance(inst), LuckFormulas.PreRiftMutation)
    return inst._cached_prerift_mutation_result
end

function CanLunarRiftMutateFromCorpse(inst)
    local riftspawner = TheWorld.components.riftspawner
    if not CanEntityBeGestaltMutated(inst) then
        return false
    elseif inst.spawn_gestalt_mutated_tuning and not TUNING[inst.spawn_gestalt_mutated_tuning] then
        return false
    elseif riftspawner and not riftspawner:IsLunarPortalActive() then
        return false
    elseif inst:IsOnOcean() then --TODO Support ocean lunar mutations?
        return false
    elseif inst.components.burnable and inst.components.burnable:IsBurning() then
        return false
    elseif inst._cached_rift_mutation_result ~= nil then -- We might run this function multiple times.
        return inst._cached_rift_mutation_result
    end

    local killer = GetCauseOfDeath(inst)
    inst._cached_rift_mutation_result = TryLuckRoll(killer, GetLunarRiftMutationChance(inst), LuckFormulas.RiftPossession)
    return inst._cached_rift_mutation_result
end

function CanEntityBecomeCorpse(inst)
    local corpsepersistmanager = TheWorld.components.corpsepersistmanager
    if not EntityHasCorpse(inst) then
        return false
    elseif inst.forcecorpse then
        return true
    elseif inst.components.burnable and inst.components.burnable:IsBurning() then
        return false
    elseif corpsepersistmanager ~= nil and corpsepersistmanager:ShouldRetainCreatureAsCorpse(inst) then
        return true
    elseif CanLunarPreRiftMutateFromCorpse(inst) then
        return true
    elseif CanLunarRiftMutateFromCorpse(inst) then
        return true
    end
end

function TryEntityToCorpse(inst, corpseprefab)
    local can_corpse = CanEntityBecomeCorpse(inst)

    if can_corpse then
        local x, y, z = inst.Transform:GetWorldPosition()
        local rot = inst.Transform:GetRotation()
        local sx, sy, sz = inst.Transform:GetScale()

        local corpse = SpawnPrefab(corpseprefab)
        corpse.Transform:SetPosition(x, y, z)
        corpse.Transform:SetRotation(rot)
        corpse.Transform:SetScale(sx, sy, sz) -- Corpses will copy scale from the original mob. Mutated will NOT.
        corpse.AnimState:MakeFacingDirty()
        corpse.AnimState:SetBuild(inst.AnimState:GetBuild())
        corpse.AnimState:SetBank(inst.AnimState:GetBankHash())

        corpse.corpse_loot = inst:GetDeathLoot()

        local corpsedata = inst.SaveCorpseData ~= nil and inst:SaveCorpseData(corpse) or nil

        if corpsedata then
            corpse:SetCorpseData(corpsedata)
        end

        corpse.sg.mem.nolunarmutate = inst.sg.mem.nolunarmutate -- This is saved.
        if not inst.components.burnable and corpse.components.burnable then
            corpse:RemoveComponent("burnable")
            corpse.noburn = true
        end

        if CanLunarRiftMutateFromCorpse(inst) then
            corpse:SetGestaltCorpse()
        elseif CanLunarPreRiftMutateFromCorpse(inst) then
            corpse:SetNonGestaltCorpse()
        end

        inst:Remove()

        return corpse
    end
end

--------------------------------------------------------------------------

function CanApplyPlayerDamageMod(target)
    return target ~= nil and (target.isplayer or target:HasTag("player_damagescale"))
end

function PlayerDamageMod(target, damage, mod)
    return CanApplyPlayerDamageMod(target) and damage * mod
        or damage
end

--------------------------------------------------------------------------

local BASE_HIT_SOUND = "dontstarve/impacts/impact_"

--V2C: Considered creating a mapping for tags to strings, but we cannot really
--     rely on these tags being properly mutually exclusive, so it's better to
--     leave it like this as if explicitly ordered by priority.

function GetArmorImpactSound(inventory, weaponmod) -- This can return nil.
    weaponmod = weaponmod or "dull"
    --Order by priority
	local armormod =
		(inventory:ArmorHasTag("forcefield") and "forcefield_armour_") or
		(inventory:ArmorHasTag("sanity") and "sanity_armour_") or
		(inventory:ArmorHasTag("lunarplant") and "lunarplant_armour_") or
		(inventory:ArmorHasTag("dreadstone") and "dreadstone_armour_") or
		(inventory:ArmorHasTag("metal") and "metal_armour_") or
		(inventory:ArmorHasTag("marble") and "marble_armour_") or
		(inventory:ArmorHasTag("shell") and "shell_armour_") or
		(inventory:ArmorHasTag("wood") and "wood_armour_") or
		(inventory:ArmorHasTag("grass") and "straw_armour_") or
		(inventory:ArmorHasTag("fur") and "fur_armour_") or
		(inventory:ArmorHasTag("cloth") and "shadowcloth_armour_") or
		nil

	if armormod ~= nil then
		return BASE_HIT_SOUND..armormod..weaponmod
	end
end

function GetWallImpactSound(inst, weaponmod)
    weaponmod = weaponmod or "dull"

    return
        BASE_HIT_SOUND..(
            (inst:HasTag("grass") and "straw_wall_") or
            (inst:HasTag("stone") and "stone_wall_") or
            (inst:HasTag("marble") and "marble_wall_") or
            (inst:HasTag("fence_electric") and "metal_armour_") or
            "wood_wall_"
        )..weaponmod
end

function GetObjectImpactSound(inst, weaponmod)
    weaponmod = weaponmod or "dull"

    return
        BASE_HIT_SOUND..(
            (inst:HasTag("clay") and "clay_object_") or
            (inst:HasTag("stone") and "stone_object_") or
            "object_"
        )..weaponmod
end

function GetCreatureImpactSound(inst, weaponmod)
    weaponmod = weaponmod or "dull"

    local tgttype =
		(inst:HasAnyTag("hive", "eyeturret", "houndmound") and "hive_") or
        (inst:HasTag("ghost") and "ghost_") or
		(inst:HasAnyTag("insect", "spider") and "insect_") or
		(inst:HasAnyTag("chess", "mech") and "mech_") or
		--V2C: "mech" higher priority over "brightmare(boss)"
		(inst:HasAnyTag("brightmare", "brightmareboss") and "ghost_") or
        (inst:HasTag("mound") and "mound_") or
		(inst:HasAnyTag("shadow", "shadowminion", "shadowchesspiece") and "shadow_") or
		(inst:HasAnyTag("tree", "wooden") and "tree_") or
        (inst:HasAnyTag("veggie", "hedge") and "vegetable_") or
        (inst:HasTag("shell") and "shell_") or
		(inst:HasAnyTag("rocky", "fossil") and "stone_") or
        inst.override_combat_impact_sound or
        nil

    return
        BASE_HIT_SOUND..(
            tgttype or "flesh_"
        )..(
			(IsSmallCreature(inst) and "sml_") or
			((IsLargeCreature(inst) or IsEpicCreature(inst)) and not inst:HasAnyTag("shadowchesspiece", "fossil", "brightmareboss") and "lrg_") or
            (tgttype == nil and inst:GetIsWet() and "wet_") or
            "med_"
        )..weaponmod
end

--------------------------------------------------------------------------

local function SplitTopologyId(s)
	local a = {}
    --
	for word in string.gmatch(s, '[^/:]+') do
		a[#a + 1] = word
	end
    --
	return a
end

-- Useful for splitting a topology id into task, layout, index, and room id's for us to look at.
function ConvertTopologyIdToData(idname)
    if idname == nil then
        return {}
    elseif idname == "START" then -- Special case for the id that the portal spawns in.
        return { task_id = "START" } -- Consider START as a task, for now?
    else
        local split_ids = SplitTopologyId(idname)
        if split_ids[1] == "StaticLayoutIsland" then
            return { layout_id = split_ids[2] }
        else
            return { task_id = split_ids[1], index_id = split_ids[2], room_id = split_ids[3] }
        end
    end
end

--------------------------------------------------------------------------

-- For corpses, graves and skeletons.
-- Set as inspectable.getspecialdescription
function GetPlayerDeathDescription(inst, viewer)
    if inst.char ~= nil and not viewer:HasTag("playerghost") then
        local mod = GetGenderStrings(inst.char)
        local desc = GetDescription(viewer, inst, mod)
        local name = inst.playername or STRINGS.NAMES[string.upper(inst.char)]

        -- No translations for player killer's name.
        if inst.pkname ~= nil then
            return string.format(desc, name, inst.pkname)
        end

        -- Permanent translations for death cause.
        if inst.cause == "unknown" then
            inst.cause = "shenanigans"

        elseif inst.cause == "moose" then
            inst.cause = math.random() < .5 and "moose1" or "moose2"
        end

        -- Viewer based temp translations for death cause.
        local cause =
            inst.cause == "nil"
            and (
                (viewer == "waxwell" or viewer == "winona") and "charlie" or "darkness"
            )
            or inst.cause

        return string.format(desc, name, STRINGS.NAMES[string.upper(cause)] or STRINGS.NAMES.SHENANIGANS)
    end
end

--------------------------------------------------------------------------

function GetTopologyDataAtPoint(x, y, z)
    if y == nil and z == nil then -- Support Vector3
        x, y, z = x:Get()
    elseif z == nil then -- Support (x, z)
        y, z = 0, y
    end

    local id, _ = TheWorld.Map:GetTopologyIDAtPoint(x, y, z)
    return ConvertTopologyIdToData(id)
end

function GetTopologyDataAtInst(inst)
    return GetTopologyDataAtPoint(inst.Transform:GetWorldPosition())
end

--------------------------------------------------------------------------
function MakeComponentAnInventoryItemSource(cmp, owner)
    local self = cmp
    local owner = owner or self.inst

    local function removeowner()
        if self.itemsource_owner then
            if self.OnItemSourceRemoved then
                self:OnItemSourceRemoved(self.itemsource_owner)
            end
            self.itemsource_owner = nil
        end
    end
    local function storeincontainer(inst, container)
        if container ~= nil and container.components.container ~= nil then
            inst:ListenForEvent("onputininventory", self.itemsource_oncontainerownerchanged, container)
            inst:ListenForEvent("ondropped", self.itemsource_oncontainerownerchanged, container)
            inst:ListenForEvent("onremove", self.itemsource_oncontainerremoved, container)
            self.itemsource_container = container
        end
        removeowner()
    end
    local function unstore(inst)
        if self.itemsource_container ~= nil then
            inst:RemoveEventCallback("onputininventory", self.itemsource_oncontainerownerchanged, self.itemsource_container)
            inst:RemoveEventCallback("ondropped", self.itemsource_oncontainerownerchanged, self.itemsource_container)
            inst:RemoveEventCallback("onremove", self.itemsource_oncontainerremoved, self.itemsource_container)
            self.itemsource_container = nil
        end
    end
    self.itemsource_topocket = function(inst, owner)
        if self.itemsource_container ~= owner then
            unstore(inst)
            storeincontainer(inst, owner)
        end
        local newowner = owner.components.inventoryitem ~= nil and owner.components.inventoryitem:GetGrandOwner() or owner
        if self.itemsource_owner ~= newowner then
            removeowner()
            self.itemsource_owner = newowner
            if self.itemsource_owner and self.OnItemSourceNewOwner then
                self:OnItemSourceNewOwner(self.itemsource_owner)
            end
        end
    end
    self.itemsource_toground = function(inst)
        unstore(inst)
        removeowner()
    end

    self.itemsource_oncontainerownerchanged = function(container)
        self.itemsource_topocket(self.inst, container)
    end
    self.itemsource_oncontainerremoved = function()
        unstore(self.inst)
    end
    self.itemsource_onremove = function()
        removeowner()
    end
    local currentowner = owner.components.inventoryitem.owner
    if currentowner then
        self.itemsource_topocket(owner, currentowner)
    end
    self.inst:ListenForEvent("onputininventory", self.itemsource_topocket, owner)
    self.inst:ListenForEvent("ondropped", self.itemsource_toground, owner)
    self.inst:ListenForEvent("onremove", self.itemsource_onremove, owner)
end

function RemoveComponentInventoryItemSource(cmp, owner)
    local self = cmp
    local owner = owner or self.inst

    self.inst:RemoveEventCallback("onputininventory", self.itemsource_topocket, owner)
    self.inst:RemoveEventCallback("ondropped", self.itemsource_toground, owner)
    self.inst:RemoveEventCallback("onremove", self.itemsource_onremove, owner)
    self.itemsource_toground(self.inst)
    self.itemsource_topocket = nil
    self.itemsource_toground = nil
    self.itemsource_onremove = nil
    self.itemsource_oncontainerownerchanged = nil
    self.itemsource_oncontainerremoved = nil
end

--------------------------------------------------------------------------

-- The occupation space pearl takes up to take into account decoration score post-eviction
-- This is an expensive function, consider caching or saving the return value.
-- This is a client and server function. Careful about the logic you implement here.

local function GetAngleTowardsLand(x, y)
    local xs, zs = 0, 0
    --
    for off_x = -1, 1  do
        for off_y = -1, 1 do
            local tx, ty = x + off_x, y + off_y
            if TheWorld.Map:IsTileLandNoDocks(TheWorld.Map:GetTile(tx, ty)) then
                local angle = math.atan2(ty - y, x - tx)
                xs, zs = xs - math.cos(angle), zs - math.sin(angle)
            end
        end
    end
    --
    return math.atan2(zs, xs)
end
local MAX_TILES = TUNING.HERMITCRAB_DECOR_MAX_TILE_SPACE
local MAX_SHORELINE_TILES = 12
function GetHermitCrabOccupiedGrid(x, z)
    local w, h = TheWorld.Map:GetSize()
    local occupied_grid = DataGrid(w, h)
    --
    local searched_shoreline_tiles = DataGrid(w, h)
    local shoreline_tiles = { { x = x, z = z }}
    local i = 1
    while i <= #shoreline_tiles do
        if i > MAX_SHORELINE_TILES then -- enough shoreline tiles
            break
        end

        local data = shoreline_tiles[i]
        local tx, tz = data.x, data.z

        searched_shoreline_tiles:SetDataAtPoint(tx, tz, true)

        local function AddShorelineToQueue(offx, offz)
            local px, pz = tx + offx, tz + offz
            local x, y, z = TheWorld.Map:GetTileCenterPoint(px, pz)
            if TheWorld.Map:IsTileLandNoDocks(TheWorld.Map:GetTile(px, pz))
                and not searched_shoreline_tiles:GetDataAtPoint(px, pz)
                and not TheWorld.Map:IsSurroundedByLandNoDocks(x, y, z, 2)
            then
                table.insert(shoreline_tiles, { x = px, z = pz, angle = GetAngleTowardsLand(px, pz) })
            end
        end

        for offx = -1, 1 do
            if offx ~= 0 then
                AddShorelineToQueue(offx, 0)
            end
        end

        for offz = -1, 1 do
            if offz ~= 0 then
                AddShorelineToQueue(0, offz)
            end
        end

        i = i + 1
    end
    --
    local tiles = { }
    for k, v in pairs(shoreline_tiles) do
        table.insert(tiles, { x = v.x, z = v.z, preferred_angle = v.angle })
    end

    -- If setting any data grid points to nil/false, adjust count logic accordingly.
    i = 1
    local grid_count = 0
    while i <= #tiles do
        if grid_count >= MAX_TILES then
            break
        end

        local data = tiles[i]
        local tx, tz = data.x, data.z
        local index = occupied_grid:GetIndex(tx, tz)
        if not occupied_grid:GetDataAtIndex(index) then
            occupied_grid:SetDataAtIndex(index, true)
            grid_count = grid_count + 1

            local function AddTileToQueue(offx, offz)
                local px, pz = tx + offx, tz + offz
                if not occupied_grid:GetDataAtPoint(px, pz) and TheWorld.Map:IsTileLandNoDocks(TheWorld.Map:GetTile(px, pz)) then
                    table.insert(tiles, { x = px, z = pz })
                end
            end

            for offx = -1, 1 do
                if offx ~= 0 then
                    AddTileToQueue(offx, 0)
                end
            end

            for offz = -1, 1 do
                if offz ~= 0 then
                    AddTileToQueue(0, offz)
                end
            end
        end

        i = i + 1
    end
    --
    return occupied_grid
end

local HERMIT_ISLAND_LAYOUT_ID = "HermitcrabIsland"
local MONKEY_ISLAND_LAYOUT_ID = "MonkeyIsland"
local MOON_ISLAND_TASK_ID = "MoonIsland"

function IsInValidHermitCrabDecorArea(inst)
    local topology_data = GetTopologyDataAtInst(inst)

    -- We haven't moved yet.
    if topology_data.layout_id == HERMIT_ISLAND_LAYOUT_ID then
        return false
    end

    -- Monkey island bad
    if topology_data.layout_id == MONKEY_ISLAND_LAYOUT_ID then
        return false
    end

    -- Moon Island bad, reeks of lunar energy.
    if topology_data.task_id and topology_data.task_id:find(MOON_ISLAND_TASK_ID) then
        return false
    end

    return true
end

--------------------------------------------------------------------------

function IsEntityGestaltProtected(inst)
    local inventory = inst.components.inventory
    return (inventory and inventory:EquipHasTag("gestaltprotection"))
        or inst:HasDebuff("hermitcrabtea_moon_tree_blossom_buff")
end

--------------------------------------------------------------------------

local BLOCKER_TAGS = { "blocker" }

function IsPointCoveredByBlocker(x, y, z, extra_radius)
    extra_radius = extra_radius or 0

    for _, ent in ipairs(TheSim:FindEntities(x, 0, z, extra_radius + MAX_PHYSICS_RADIUS, nil, nil, BLOCKER_TAGS)) do
		local range = extra_radius + ent:GetPhysicsRadius(0)
		if ent:GetDistanceSqToPoint(x, 0, z) < range * range then
			return true
		end
	end

    return nil
end

--------------------------------------------------------------------------

function EntityHasSetBonus(inst, setname)
    local inventory = inst.components.inventory
    if inventory then
        local head, body = inventory.equipslots[EQUIPSLOTS.HEAD], inventory.equipslots[EQUIPSLOTS.BODY]

        if head == nil or body == nil then
            return false
        end

        if head.components.setbonus == nil or body.components.setbonus == nil then
            return false
        end

        if head.components.setbonus.setname ~= setname or body.components.setbonus.setname ~= setname then
            return false
        end

        return true
    end
end

--------------------------------------------------------------------------
-- Jousting.

function CreatingJoustingData(inst)
    local joustdata = {}

    local target, source
    local buffaction = inst:GetBufferedAction()
    if buffaction then
        target, source = buffaction.target, buffaction.invobject
    end

    local dir
    if target and target:IsValid() then
        --true dir (for movement)
        dir = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
    else
        --true dir (for movement)
        dir = inst.Transform:GetRotation()
    end
    joustdata.dir = dir

    if source and source:IsValid() then
        if source.components.joustsource then
            joustdata.source = source
        end
    end

    return joustdata
end

--------------------------------------------------------------------------

local TWOTHIRDS = 2 / 3

local function CommonChanceLuckAdditive(mult)
    return function(inst, chance, luck)
        return luck > 0 and chance + ( luck * mult )
    end
end

local function CommonChanceUnluckMultAndLuckHyperbolic(reciprocal, mult)
    mult = mult or 1
    return function(inst, chance, luck)
        return luck < 0 and chance * (1 + math.abs(luck) * mult)
            or luck > 0 and chance * (reciprocal / (reciprocal + luck) + .5) * TWOTHIRDS
    end
end

local function CommonChanceLuckHyperbolic(mult_max, asymptote, subtract)
    subtract = subtract or 0
    return function(inst, chance, luck)
        return luck > 0 and chance * (mult_max - asymptote / ( asymptote + (luck - subtract) ))
    end
end

local function CommonChanceUnluckHyperbolicAndLuckMult(reciprocal, mult)
    mult = mult or 1
    return function(inst, chance, luck)
        return luck < 0 and chance * (reciprocal / (reciprocal - luck) + .5) * TWOTHIRDS
            or luck > 0 and chance * (1 + math.abs(luck) * mult)
    end
end

local function CommonChanceUnluckHyperbolicAndLuckAdditive(reciprocal, mult)
    mult = mult or 1
    return function(inst, chance, luck)
        return luck < 0 and chance * (reciprocal / (reciprocal - luck) + .5) * TWOTHIRDS
            or luck > 0 and chance + ( luck * mult )
    end
end

local function CommonChanceUnluckHyperbolicAndLuckHyperbolic(mult_max, asymptote, subtract, reciprocal)
    subtract = subtract or 0
    return function(inst, chance, luck)
        return luck < 0 and chance * (mult_max - asymptote / ( asymptote + (luck - subtract) ))
            or luck > 0 and chance * (reciprocal / (reciprocal + luck) + .5) * TWOTHIRDS
    end
end

local function CommonChanceLuckHyperbolicLower(reciprocal)
    return function(inst, chance, luck)
        return luck > 0 and chance * (reciprocal / (reciprocal + luck) + .5) * TWOTHIRDS
    end
end

LuckFormulas =
{
    AcidBatWave = CommonChanceUnluckMultAndLuckHyperbolic(5),
    AncientTreeSeedTreasure = CommonChanceLuckAdditive(0.1),
    BatGraveSpawn = CommonChanceUnluckMultAndLuckHyperbolic(3, .5),
    BirdDropItem = CommonChanceUnluckHyperbolicAndLuckAdditive(2, .25),
    BrightmareSpawn = CommonChanceUnluckMultAndLuckHyperbolic(4),
    ChessJunkSpawnClockwork = CommonChanceUnluckMultAndLuckHyperbolic(5, .5),
    ChildSpawnerOtherChild = CommonChanceUnluckMultAndLuckHyperbolic(6),
    ChildSpawnerRareChild = CommonChanceUnluckMultAndLuckHyperbolic(4),
    CriticalStrike = CommonChanceLuckAdditive(.5),
    CritterNuzzle = CommonChanceUnluckHyperbolicAndLuckMult(0.5),
    DeciduousMonsterSpawn = CommonChanceUnluckMultAndLuckHyperbolic(6),
    DecreaseSanityMonsterPopulation = CommonChanceUnluckHyperbolicAndLuckMult(-2, 1),
    DropWetTool = CommonChanceUnluckMultAndLuckHyperbolic(.5, 1),
    GrassGekkoMorph = CommonChanceUnluckMultAndLuckHyperbolic(4, .5),
    HuntAlternateBeast = CommonChanceUnluckMultAndLuckHyperbolic(3, 0.5),
    IncreaseSanityMonsterPopulation = CommonChanceUnluckMultAndLuckHyperbolic(3),
    InspectablesUpgradedBox = CommonChanceLuckAdditive(0.5),
    LeifChill = CommonChanceUnluckHyperbolicAndLuckMult(1),
    LighterIgniteOnAttack = CommonChanceUnluckMultAndLuckHyperbolic(.5),
    LootDropperChance = CommonChanceLuckHyperbolic(3, 6, 3),
    LoseFollowerOnPanic = CommonChanceUnluckMultAndLuckHyperbolic(1),
    LuckyRabbitSpawn = CommonChanceUnluckHyperbolicAndLuckAdditive(1), -- This will REALLY go high with luck, which makes sense, it's the lucky rabbit! So, special 'syngery'
    LureplantChanceSpawn = CommonChanceUnluckMultAndLuckHyperbolic(3, .5),
    MalbatrossSpawn = CommonChanceUnluckMultAndLuckHyperbolic(4, 1),
    MegaFlareEvent = CommonChanceLuckHyperbolic(1.5, 1, -2), -- This takes into account every player.
    MermTripleAttack = CommonChanceLuckAdditive(0.5),
    MessageBottleContainsNote = CommonChanceLuckAdditive(-.2),
    MonkeyFollowPlayer = CommonChanceUnluckMultAndLuckHyperbolic(2),
    ParasiteOverrideBlob = CommonChanceUnluckMultAndLuckHyperbolic(8),
    PirateRaidsSpawn = CommonChanceUnluckMultAndLuckHyperbolic(5, .5),
    PreRiftMutation = CommonChanceUnluckMultAndLuckHyperbolic(2),
    ResidueUpgradeFuel = CommonChanceLuckHyperbolic(2, 4),
    RuinsHatProc = CommonChanceLuckAdditive(.33),
    RuinsNightmare = CommonChanceUnluckMultAndLuckHyperbolic(2),
    RiftPossession = CommonChanceUnluckMultAndLuckHyperbolic(3),
    SchoolSpawn = CommonChanceLuckAdditive(0.5),
    ShadowRiftQuaker = CommonChanceUnluckMultAndLuckHyperbolic(8),
    ShadowTentacleSpawn = CommonChanceLuckAdditive(0.2),
    SharkBoiSpawn = CommonChanceUnluckMultAndLuckHyperbolic(2),
    StatueSpawnNightmare = CommonChanceUnluckMultAndLuckHyperbolic(1, 1),
    SpawnLeif = CommonChanceUnluckMultAndLuckHyperbolic(6),
    SpecialSchoolSpawn = CommonChanceUnluckMultAndLuckHyperbolic(3),
    SpiderQueenBetterSpider = CommonChanceUnluckMultAndLuckHyperbolic(3, .5),
    SpookedChance = CommonChanceUnluckHyperbolicAndLuckHyperbolic(2, -1, 0, 2),
    SquidHerdSpawn = CommonChanceUnluckMultAndLuckHyperbolic(5),
    TerrorbeakSpawn = CommonChanceUnluckMultAndLuckHyperbolic(2, .5),
    WildFireIgnition = CommonChanceLuckHyperbolicLower(2), -- Don't have unluckiness affect this, it affects other players really badly

    SpawnPerd = function(inst, chance, luck)
        -- Make gobblers spawn more often with luck during their year
        if IsSpecialEventActive(SPECIAL_EVENTS.YOTG) then
            return luck > 0 and chance + ( luck * .5 )
        end

        -- Otherwise, they're not helpful, so being unlucky will spawn them more, being lucky will spawn them less
        local reciprocal = 3
        return luck < 0 and chance * (1 + math.abs(luck))
            or luck > 0 and chance * (reciprocal / (reciprocal + luck))
    end,
}

function GetEntityLuck(inst)
    return inst.components.luckuser and inst.components.luckuser:GetLuck() or 0
end

function GetLuckChance(luck, chance, formula)
    return formula(nil, chance, luck) or chance
end

function GetEntityLuckChance(inst, chance, formula)
    local luck = GetEntityLuck(inst)
    return formula(inst, chance, luck) or chance
end

function GetEntitiesLuckChance(instances, chance, formula)
    local luck = 0
    for k, v in pairs(instances) do
        luck = luck + GetEntityLuck(v)
    end
    return formula(instances, chance, luck) or chance
end

function GetEntityLuckWeightedTable(inst, weighted_table)
    local luck = GetEntityLuck(inst)
    -- return a new weighted table, giving away value from the heaviest weighted items to the lower weighted
end

local function DoLuckyEffect(inst, is_lucky)
    if inst.player_classified ~= nil then
        --Forces a netvar to be dirty regardless of value
        inst.player_classified.playluckeffect:set_local(false)
        inst.player_classified.playluckeffect:set(is_lucky or false)
    end
end

function TryLuckRoll(inst, chance, formula) -- inst can be optional.
    local roll = math.random()
    --
    if inst then
        local new_chance = GetEntityLuckChance(inst, chance, formula)
        local success = roll <= new_chance
        -- Effect CUT to keep it ambigious
        -- if (roll > chance and success) or (roll <= chance and not success) then
        --     DoLuckyEffect(inst, GetEntityLuck(inst) > 0)
        -- end
        return success
    end
    --
    return roll <= chance
end