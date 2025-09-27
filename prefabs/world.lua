local GroundTiles = require "worldtiledefs"
require "components/map" --extends Map component

local assets =
{
    Asset("SOUND", "sound/music.fsb"),
    Asset("SOUND", "sound/sanity.fsb"),
    Asset("SOUND", "sound/amb_stream.fsb"),
    Asset("SHADER", "shaders/uifade.ksh"),
    Asset("DYNAMIC_ATLAS", "bigportraits/locked.xml"),
    Asset("PKGREF", "bigportraits/locked.tex"),

    Asset("DYNAMIC_ATLAS", "bigportraits/random.xml"),
    Asset("PKGREF", "bigportraits/random.tex"),
    Asset("DYNAMIC_ATLAS", "bigportraits/random_none.xml"),
    Asset("PKGREF", "bigportraits/random_none.tex"),

    Asset("DYNAMIC_ATLAS", "images/names_random.xml"),
    Asset("PKGREF", "images/names_random.tex"),

    Asset("DYNAMIC_ATLAS", "images/names_gold_random.xml"),
    Asset("PKGREF", "images/names_gold_random.tex"),

    Asset("DYNAMIC_ATLAS", "images/names_gold_cn_random.xml"),
    Asset("PKGREF", "images/names_gold_cn_random.tex"),

    -- Asset("ANIM", "anim/portrait_frame.zip"), -- Not currently used, but likely to come back
    
    Asset("ANIM", "anim/frames_comp.zip"),

    Asset("ANIM", "anim/frozen.zip"),
    Asset("ANIM", "anim/floating_items.zip"),

    Asset("DYNAMIC_ATLAS", "images/bg_spiral_anim.xml"),
    Asset("PKGREF", "images/bg_spiral_anim.tex"),
    Asset("DYNAMIC_ATLAS", "images/bg_spiral_anim_overlay.xml"),
    Asset("PKGREF", "images/bg_spiral_anim_overlay.tex"),

	Asset("INV_IMAGE", "equip_slot_body_hud"),
	Asset("INV_IMAGE", "equip_slot_head_hud"),
	Asset("INV_IMAGE", "equip_slot_hud"),

	Asset("IMAGE", "images/waterfall_mask.tex"),

	Asset("IMAGE", "images/waterfall_mask.tex"),
	Asset("IMAGE", "levels/textures/waterfall_noise1.tex"),
	Asset("IMAGE", "levels/textures/waterfall_noise2.tex"),

    Asset("SCRIPT", "scripts/prefabs/rift_portal_defs.lua"),

    Asset("ANIM", "anim/poi_marker.zip"),
    Asset("ANIM", "anim/poi_stand.zip"),    

	Asset("DYNAMIC_ATLAS", "images/pumpkin_carving.xml"),
	Asset("PKGREF", "images/pumpkin_carving.tex"),

	Asset("DYNAMIC_ATLAS", "images/pumpkin_carving2.xml"),
	Asset("PKGREF", "images/pumpkin_carving2.tex"),

	Asset("DYNAMIC_ATLAS", "images/snowman.xml"),
	Asset("PKGREF", "images/snowman.tex"),
}

for k, v in pairs(GroundTiles.assets) do
    table.insert(assets, v)
end

local prefabs =
{
    "sounddebugicon",
    "entityproxy",

    "minimap",
    "evergreen",
    "evergreen_normal",
    "evergreen_short",
    "evergreen_tall",
    "evergreen_sparse",
    "evergreen_sparse_normal",
    "evergreen_sparse_short",
    "evergreen_sparse_tall",
    "evergreen_burnt",
    "evergreen_stump",

    "twiggytree",
    "twiggy_tall",
    "twiggy_short",
    "twiggy_normal",

    "sapling",
    "sapling_moon",
    "berrybush",
    "berrybush2",
    "berrybush_juicy",
    "grass",
    "rock1",
    "rock2",
    "rock_flintless",
    "rock_moon",
    "rock_petrified_tree",
    "rock_petrified_tree_tall",
    "rock_petrified_tree_short",
    "rock_petrified_tree_med",

    "tallbirdnest",
    "hound",
    "firehound",
    "icehound",
    "krampus",
    "mound",

    "pigman",
    "pighouse",
    "pigking",
    "mandrake",
    "rook",
    "bishop",
    "knight",

    "critterlab",

    "goldnugget",
    "crow",
    "robin",
    "robin_winter",
    "canary",
    "butterfly",
    "flint",
    "log",
    "spiderden",
    "fireflies",

    "turf_road",
    "turf_rocky",
    "turf_forest",
    "turf_marsh",
    "turf_grass",
    "turf_savanna",
    "turf_meteor",
    "turf_pebblebeach",
    "turf_shellbeach",
    "turf_cave",
    "turf_fungus",
    "turf_fungus_red",
    "turf_fungus_green",
    "turf_fungus_moon",
    "turf_archive",
    "turf_sinkhole",
    "turf_underrock",
    "turf_mud",
    "turf_deciduous",
    "turf_desertdirt",

    "skeleton",
    "skeleton_notplayer",
    "skeleton_notplayer_1",
    "skeleton_notplayer_2",
    "insanityrock",
    "sanityrock",
    "basalt",
    "basalt_pillar",
    "houndmound",
    "houndbone",
    "pigtorch",
    "red_mushroom",
    "green_mushroom",
    "blue_mushroom",
    "mermhouse",
    "flower_evil",
    "blueprint",
    "wormhole_limited_1",
    "diviningrod",
    "diviningrodbase",
    "maxwell_smoke",
    "chessjunk1",
    "chessjunk2",
    "chessjunk3",
    "statue_transition_2",
    "statue_transition",

    "lightninggoat",
    "smoke_plant",
    "acorn",
    "deciduoustree",
    "deciduoustree_normal",
    "deciduoustree_tall",
    "deciduoustree_short",
    "deciduoustree_burnt",
    "deciduoustree_stump",
    "buzzardspawner",

    "glommer",
    "statueglommer",

    "cactus",

    "spawnlight_multiplayer",
    "spawnpoint_multiplayer",
    --"spawn_fx_huge",
    --"spawn_fx_large",
    "spawn_fx_medium",
    "spawn_fx_small",
    "spawn_fx_tiny",
    "spawn_fx_small_high",

    -- used to be in BACKEND_PREFABS constant
    "hud",
    "fire",
    "character_fire",
    "shatter",
	"electrocute_fx",
    --

    "migration_portal",
    "shard_network",

    "focalpoint",

    -- Common classified prefabs
    "attunable_classified",
    "inventoryitem_classified",
    "writeable_classified",
    "container_classified",
    "container_opener",
    "constructionsite_classified",

    "dummytarget",
    "dummytarget_lunar",
    "dummytarget_shadow",
    "float_fx_front",
    "float_fx_back",

    "puffin",

	-- summer carnival
	"carnival_host",

	-- deprecated bird tacklesketch
	"oceanfishingbobber_malbatross_tacklesketch",
	"oceanfishingbobber_goose_tacklesketch",
	"oceanfishingbobber_crow_tacklesketch",
	"oceanfishingbobber_robin_tacklesketch",
	"oceanfishingbobber_robin_winter_tacklesketch",
	"oceanfishingbobber_canary_tacklesketch",

	-- Farming
	"slow_farmplot", -- deprecated but still used in old worlds and mods
    "fast_farmplot", -- deprecated but still used in old worlds and mods
    "nutrients_overlay",
    "lordfruitfly",

	-- YOT Catcoon
	"kitcoon_forest",
	"kitcoon_savanna",
	"kitcoon_marsh",
	"kitcoon_deciduous",
	"kitcoon_grass",
	"kitcoon_rocky",
	"kitcoon_desert",
	"kitcoon_moon",
	"kitcoon_yot",

	"cookingrecipecard",

    -- Pirates
    "monkeyhut",

	-- Planar
	"planar_hit_fx",
	"planar_resist_fx",

	-- vinebridgemanager
	"vine_bridge_fx",

    "snowball_item",
}

for _, v in pairs(require("prefabs/farm_plant_defs").PLANT_DEFS) do
	table.insert(prefabs, v.prefab)
end
for _, v in pairs(require("prefabs/weed_defs").WEED_DEFS) do
	table.insert(prefabs, v.prefab)
end
for _, v in pairs(require("prefabs/pocketdimensioncontainer_defs").POCKETDIMENSIONCONTAINER_DEFS) do
    table.insert(prefabs, v.prefab)
end

require("ocean_util") -- Only here just in case but it should not be needed.
for _, v in pairs(SINKENTITY_PREFABS) do
    for _, prefab in pairs(v) do
        table.insert(prefabs, prefab)
    end
end

--------------------------------------------------------------------------

local function OnPlayerSpawn(world, inst)
    inst:DoTaskInTime(0, function()
        if TheWorld.auto_teleport_players then
            local teleported = false

            for k,v in pairs(Ents) do
                if v:IsValid() and v:HasTag("player") and v ~= inst and not teleported then
                    inst.Transform:SetPosition(v.Transform:GetWorldPosition())
                    inst:SnapCamera()
                    teleported = true
                end
            end
        end
    end)
end

local function DoGameDataChanged(inst)
    inst.game_data_task = nil

    local game_data =
    {
        day = inst.state.cycles + 1,
        daysleftinseason = inst.state.remainingdaysinseason,
        dayselapsedinseason = inst.state.elapseddaysinseason,
    }
    TheNet:SetGameData(DataDumper(game_data, nil, false))
    TheNet:SetSeason(inst.state.season)
end

local function OnGameDataChanged(inst)
    if inst.game_data_task == nil then
        inst.game_data_task = inst:DoTaskInTime(0, DoGameDataChanged)
    end
end

local function PostInit(inst)
    if inst.net ~= nil then
        inst.net:PostInit()
    end

    inst:LongUpdate(0)

    for k, v in pairs(inst.components) do
        if v.OnPostInit ~= nil then
            v:OnPostInit()
        end
    end

    if inst.ismastersim then
        inst:WatchWorldState("season", OnGameDataChanged)
        inst:WatchWorldState("cycles", OnGameDataChanged)
        inst:WatchWorldState("remainingdaysinseason", OnGameDataChanged)
        inst:WatchWorldState("elapseddaysinseason", OnGameDataChanged)
        DoGameDataChanged(inst)
    end
end

local function OnRemoveEntity(inst)
    inst.minimap:Remove()

    assert(TheWorld == inst)
    TheWorld = nil

    assert(TheFocalPoint ~= nil)
    TheFocalPoint:Remove()
    TheFocalPoint = nil
end

local function CreateTilePhysics(inst)
    if inst.tile_physics_init ~= nil then
        inst:tile_physics_init()
    else
        inst.Map:AddTileCollisionSet(
            COLLISION.LAND_OCEAN_LIMITS,
            TileGroups.LandTiles, false,
            TileGroups.LandTiles, true,
            0.25, 64
        )
        inst.Map:AddTileCollisionSet(
            inst:CanFlyingCrossBarriers() and COLLISION.GROUND or COLLISION.LAND_OCEAN_LIMITS,
            TileGroups.ImpassableTiles, true,
            TileGroups.ImpassableTiles, false,
            0.25, 128
        )
    end
end

local function SetPocketDimensionContainer(world, name, containerinst)
    world.PocketDimensionContainers[name] = containerinst
end

local function GetPocketDimensionContainer(world, name)
    return world.PocketDimensionContainers[name]
end

local function CanFlyingCrossBarriers(world) -- NOTES(JBK): Ghosts are flying in this case and has_ocean is backwards compatability.
    return world.has_ocean or world.cancrossbarriers_flying
end

--------------------------------------------------------------------------

function MakeWorld(name, customprefabs, customassets, common_postinit, master_postinit, tags, custom_data)
	custom_data = custom_data or {}

    local worldprefabs = {}
    if name ~= "world" then
        table.insert(worldprefabs, "world")
    end
    if customprefabs ~= nil then
        for i, v in ipairs(customprefabs) do
            table.insert(worldprefabs, v)
        end
    end

    local function fn()
        local inst = CreateEntity()

		if TheWorld ~= nil then
			print("You cannot spawn multiple worlds!")
			return nil
		end

        TheWorld = inst
        inst.net = nil
        inst.shard = nil

        inst.ismastersim = TheNet:GetIsMasterSimulation()
        inst.ismastershard = inst.ismastersim and not TheShard:IsSecondary()
        --V2C: Masters is hard

        inst:AddTag("NOCLICK")
        inst:AddTag("CLASSIFIED")

        if tags ~= nil then
            for i, v in ipairs(tags) do
                inst:AddTag(v)
            end
        end

        --[[Non-networked entity]]
        inst.entity:SetCanSleep(false)
        inst.persists = false

        --Add core components
        inst.entity:AddTransform()
        inst.entity:AddMap()
        inst.entity:AddPathfinder()
        inst.entity:AddGroundCreep()
        inst.entity:AddSoundEmitter()

        inst.tile_physics_init = custom_data.tile_physics_init

        inst.cancrossbarriers_flying = custom_data.cancrossbarriers_flying -- Intentionally not a table for searchability.
        inst.CanFlyingCrossBarriers = CanFlyingCrossBarriers

        if custom_data.common_preinit ~= nil then
            custom_data.common_preinit(inst)
        end

        --Initialize map
        for i, data in ipairs(GroundTiles.ground) do
            local tile_id, layer_properties = unpack(data)
            if GROUND_NOGROUNDOVERLAYS[tile_id] then
                TileGroupManager:SetNoGroundOverlays(tile_id) -- NOTES(JBK): Do not call this after the map finalizes a crashing race condition may occur!
            end
            if GROUND_INVISIBLETILES[tile_id] then
                TileGroupManager:SetInvisibleTile(tile_id) -- NOTES(JBK): Do not call this after the map finalizes a crashing race condition may occur!
                TileGroupManager:AddValidTile(TileGroups.LandTilesInvisible, tile_id)
                TileGroupManager:AddInvalidTile(TileGroups.LandTilesWithDefaultFalloff, tile_id)
            end
            local handle = MapLayerManager:CreateRenderLayer(
                tile_id, --embedded map array value
                layer_properties.atlas or resolvefilepath(GroundAtlas(layer_properties.name)),
                layer_properties.texture_name or resolvefilepath(GroundImage(layer_properties.name)),
                resolvefilepath(layer_properties.noise_texture)
            )
			layer_properties._render_layer = i

            local colors = layer_properties.colors
            if colors ~= nil then
				local primary_color = colors.primary_color
                MapLayerManager:SetPrimaryColor(handle, primary_color[1] / 255, primary_color[2] / 255, primary_color[3] / 255, primary_color[4] / 255)
				local secondary_color = colors.secondary_color
				MapLayerManager:SetSecondaryColor(handle, secondary_color[1] / 255, secondary_color[2] / 255, secondary_color[3] / 255, secondary_color[4] / 255)
				local secondary_color_dusk = colors.secondary_color_dusk
				MapLayerManager:SetSecondaryColorDusk(handle, secondary_color_dusk[1] / 255, secondary_color_dusk[2] / 255, secondary_color_dusk[3] / 255, secondary_color_dusk[4] / 255)
                local minimap_color = colors.minimap_color
                MapLayerManager:SetMinimapColor(handle, minimap_color[1] / 255, minimap_color[2] / 255, minimap_color[3] / 255, minimap_color[4] / 255)
            end

            inst.Map:AddRenderLayer(handle)
            --TODO: When this object is destroyed, these handles really should be freed. At this time,
            --this is not an issue because the map lifetime matches the game lifetime but if this were
            --to ever change, we would have to clean up properly or we leak memory.
        end

        for i, data in ipairs(GroundTiles.creep) do
            local tile_id, layer_properties = unpack(data)
            local handle = MapLayerManager:CreateRenderLayer(
                tile_id,
                layer_properties.atlas,
                layer_properties.texture_name,
                layer_properties.noise_texture
            )
            inst.GroundCreep:AddRenderLayer(handle)
        end

        for i, data in ipairs(GroundTiles.falloff) do
            local tile_id, layer_properties = unpack(data)
            local handle = MapLayerManager:CreateRenderLayer(
                tile_id,
                layer_properties.atlas,
                layer_properties.texture_name,
                layer_properties.noise_texture
            )

            inst.Map:AddFalloffTexture(
                handle,
                layer_properties.should_have_falloff,
                layer_properties.should_have_falloff_result,
                layer_properties.neighbor_needs_falloff,
                layer_properties.neighbor_needs_falloff_result
            )
        end

        inst:AddComponent("worldsettings")

        --Initialize lua world state
        inst:AddComponent("worldstate")
        inst.state = inst.components.worldstate.data

        --Initialize lua components
        inst:AddComponent("groundcreep")

        --Public member functions
        inst.PostInit = PostInit
        inst.OnRemoveEntity = OnRemoveEntity
        inst.CreateTilePhysics = CreateTilePhysics

        --Initialize minimap
        inst.minimap = SpawnPrefab("minimap")

        --Initialize local focal point
        assert(TheFocalPoint == nil)
        TheFocalPoint = SpawnPrefab("focalpoint")
        TheCamera:SetTarget(TheFocalPoint)

        if common_postinit ~= nil then
            common_postinit(inst)
        end

        inst:SetPrefabName("world") -- the actual prefab to load comes from gamelogic.lua, this is for postinitfns.

        if not TheNet:IsDedicated() then
            inst:AddComponent("oceancolor")
            inst:AddComponent("nutrients_visual_manager")
            inst:AddComponent("hudindicatablemanager")
        end
        --
        inst:AddComponent("walkableplatformmanager")

        inst:AddComponent("waterphysics")
        inst.components.waterphysics.restitution = 0.75

        if not inst.ismastersim then
            return inst
        end

        inst:AddComponent("shardtransactionsteps")

        inst:AddComponent("klaussackloot")

        inst:AddComponent("undertile")

        inst:AddComponent("worldsettingstimer")
        inst:AddComponent("timer")

        inst:AddComponent("farming_manager")

        inst:AddComponent("dockmanager")
        inst:AddComponent("vinebridgemanager")
        inst:AddComponent("worldroutes")

        inst:AddComponent("playerspawner")

        inst:AddComponent("nightlightmanager")
        inst:AddComponent("winonateleportpadmanager")

        --World health management
        inst:AddComponent("skeletonsweeper")

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        --Metrics
        inst:AddComponent("uniqueprefabids")

        --World gen data for server listing
        --Also updated in shardnetworking.lua for multilevel server clusters
        UpdateServerWorldGenDataString()

        inst.game_data_task = nil

        inst:ListenForEvent("ms_playerspawn", OnPlayerSpawn)

        inst.PocketDimensionContainers = {}
        inst.SetPocketDimensionContainer = SetPocketDimensionContainer
        inst.GetPocketDimensionContainer = GetPocketDimensionContainer

        return inst
    end

    return Prefab(name, fn, customassets, worldprefabs)
end

return MakeWorld("world", prefabs, assets)
