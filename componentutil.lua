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

function GetCombatFxSize(ent)
	local r = ent.override_combat_fx_radius
	local sz = ent.override_combat_fx_size
	local ht = ent.override_combat_fx_height

	local r1 = r or ent:GetPhysicsRadius(0)
	if ent:HasTag("smallcreature") then
		r = r or math.min(0.5, r1)
		sz = sz or "tiny"
	elseif r1 >= 1.5 or ent:HasTag("epic") then
		r = r or math.max(1.5, r1)
		sz = sz or "large"
	elseif r1 >= 0.9 or ent:HasTag("largecreature") then
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
