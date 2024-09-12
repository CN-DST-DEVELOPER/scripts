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

--------------------------------------------------------------------------
--Tags useful for testing against combat targets that you can hit,
--but aren't really considered "alive".

NON_LIFEFORM_TARGET_TAGS =
{
	"structure",
	"wall",
	"balloon",
	"groundspike",
	"smashable",
	"veggie", --stuff like lureplants... not considered life?
}

--Shadows and Gestalts don't have souls.
--NOTE: -Adding "soulless" tag to entities is preferred over expanding this list.
--      -Gestalts should already be using "soulless" tag.
--Lifedrain (batbat) also uses this list.
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
    local upgraded = skilltreeupdater and skilltreeupdater:IsActivated("winona_charlie_2") and math.random() < odds or nil
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
