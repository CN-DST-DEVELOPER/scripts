require("prefabs/world")

local prefabs =
{
    "forest",
    "cave_network",
    "cave_exit",
    "slurtle",
    "snurtle",
    "slurtlehole",
    "warningshadow",
    "cavelight",
    "cavelight_small",
    "cavelight_tiny",
    "cavelight_atrium",
    "flower_cave",
    "ancient_altar",
    "ancient_altar_broken",
    "stalagmite",
    "stalagmite_tall",
    "bat",
    "mushtree_tall",
    "mushtree_medium",
    "mushtree_small",
    "mushtree_tall_webbed",
    "cave_banana_tree",
    "spiderhole",
    "ground_chunks_breaking",
    "tentacle_pillar",
    "tentacle_pillar_atrium",
    "batcave",
    "rockyherd",
    "cave_fern",
    "monkey",
    "monkeybarrel",
    "rock_light",
    "ruins_plate",
    "ruins_bowl",
    "ruins_chair",
    "ruins_chipbowl",
    "ruins_vase",
    "ruins_table",
    "ruins_rubble_table",
    "ruins_rubble_chair",
    "ruins_rubble_vase",
    "rubble",
    "lichen",
    "cutlichen",
    "rook_nightmare",
    "bishop_nightmare",
    "knight_nightmare",
    "ruins_statue_head",
    "ruins_statue_head_nogem",
    "ruins_statue_mage",
    "ruins_statue_mage_nogem",
    "nightmarelight",
    "pillar_ruins",
    "pillar_algae",
    "pillar_cave",
    "pillar_cave_rock",
    "pillar_cave_flintless",
    "pillar_stalactite",
    "worm",
    "wormlight_plant",
    "fissure",
    "fissure_lower",
    "slurper",
    "minotaur",
    "spider_dropper",
    "caverain",
    "caveacidrain",
    "dropperweb",
    "hutch",
    "toadstool_cap",
    "cavein_boulder",
    "cavein_debris",
    "pillar_atrium",
    "atrium_light",
    "atrium_gate",
    "atrium_statue",
    "atrium_statue_facing",
    "atrium_fence",
    "atrium_rubble",
    "atrium_idol", -- deprecated
    "atrium_overgrowth",
    "cave_hole",
    "chessjunk",
    "pandoraschest",
    "sacred_chest",
    "pond_cave",

    -- GROTTO
    "archive_centipede",
    "archive_chandelier",
    "archive_moon_statue",
    "archive_orchestrina_main",
    "archive_pillar",
    "archive_moon_statue",
    "archive_rune_statue",
    "archive_security_desk",
    "archive_lockbox_dispencer",
    "archive_lockbox_dispencer_temp",
    "archive_switch",
    "archive_portal",
    "archive_cookpot",
    "archive_ambient_sfx",
    "rubble2",
    "rubble1",

    "cavelightmoon",
    "cavelightmoon_small",
    "cavelightmoon_tiny",
    "dustmothden",
    "fissure_grottowar",
    "nightmaregrowth",
    "gestalt_guard",
    "grotto_pool_big",
    "grotto_pool_small",
    "lightflier_flower",
    "molebat",
    "mushgnome_spawner",
    "mushtree_moon",
    "moonglass_stalactite1",
    "moonglass_stalactite2",
    "moonglass_stalactite3",
    "dustmeringue",

	"retrofit_archiveteleporter",
	"retrofitted_grotterwar_spawnpoint",
	"retrofitted_grotterwar_homepoint",
 --   "wall_ruins_2",

    --
    "daywalkerspawningground",
    "gelblobspawningground",
    -- gelblobspawner
    "gelblob",

    -- From riftspawner
    --"lunarrift_portal",
    "shadowrift_portal",
    -- From shadowthrallmanager
    "miasma_cloud",
    --"dreadstone_stack",
	"shadowthrall_hands",
	"shadowthrall_horns",
	"shadowthrall_wings",
	"shadowthrall_mouth",
	"ruins_shadeling",

    "acidsmoke_fx",

    -- ropebridgemanager
	"rope_bridge_fx",

    -- rabbitkingmanager
    "rabbitking_passive",
    "rabbitking_aggressive",
    "rabbitking_lucky",

    "itemmimic_revealed",

    "chest_mimic",

    "worm_boss",

	"shadowthrall_parasite",

    -- Meta 5
    "graveguard_ghost",

	-- Rifts 6
    "shadowthrall_centipede_controller",
    "shadowthrall_centipede_head",
    "shadowthrall_centipede_body",

    "tree_rock1",
    "tree_rock2",
    "cave_vent_rock",
    "retrofit_fumaroleteleporter",

    "flower_cave_withered",

    "cave_vent_mite_spawner",

    --   vault
    "vaultmarker_lobby_center",
    "vaultmarker_lobby_to_vault",
    "vaultmarker_lobby_to_archive",
    "vaultmarker_vault_center",
    "vaultmarker_vault_north",
    "vaultmarker_vault_east",
    "vaultmarker_vault_south",
    "vaultmarker_vault_west",
    "oceanwhirlbigportalexit",
    "vault_lobby_exit",
    "vault_chandelier",
    "vault_teleporter",
}

local monsters =
{
    {"worm", 4},
    {"acidbatwave", 1},
}
for i, v in ipairs(monsters) do
    for level = 1, v[2] do
        table.insert(prefabs, v[1].."warning_lvl"..tostring(level))
    end
end
monsters = nil

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/world.lua"),

    Asset("SOUND", "sound/cave_AMB.fsb"),
    Asset("SOUND", "sound/cave_mem.fsb"),
    Asset("IMAGE", "images/colour_cubes/caves_default.tex"),

    Asset("IMAGE", "images/colour_cubes/ruins_light_cc.tex"),
    Asset("IMAGE", "images/colour_cubes/ruins_dim_cc.tex"),
    Asset("IMAGE", "images/colour_cubes/ruins_dark_cc.tex"),

    Asset("IMAGE", "images/colour_cubes/fungus_cc.tex"),
    Asset("IMAGE", "images/colour_cubes/sinkhole_cc.tex"),

    -- rabbitkingmanager
    Asset("SOUND", "sound/rabbit.fsb"),
}

local wormspawn =
{
    base_prefab = "worm",
    winter_prefab = "worm",
    summer_prefab = "worm",
    upgrade_spawn = "worm_boss",

    attack_levels =
    {
        intro   = { warnduration = function(preupgraded) return 120 end, numspawns = function() return 1 end },                     -- 1
        light   = { warnduration = function(preupgraded) return preupgraded and 90 or 60 end, numspawns = function() return 1 + math.random(0,1) end },   -- 1-2
        med     = { warnduration = function(preupgraded) return preupgraded and 90 or 45 end, numspawns = function() return 1 + math.random(0,1) end },   -- 1-2 
        heavy   = { warnduration = function(preupgraded) return preupgraded and 60 or 30 end, numspawns = function() return 2 + math.random(0,1) end },   -- 2-3
        crazy   = { warnduration = function(preupgraded) return preupgraded and 60 or 30 end, numspawns = function() return 3 + math.random(0,2) end },   -- 3-5
    },

    attack_delays =
    {
        intro       = function() return TUNING.TOTAL_DAY_TIME * 6, math.random() * TUNING.TOTAL_DAY_TIME * 2.5 end,
        rare        = function() return TUNING.TOTAL_DAY_TIME * 7, math.random() * TUNING.TOTAL_DAY_TIME * 2.5 end,
        occasional  = function() return TUNING.TOTAL_DAY_TIME * 8, math.random() * TUNING.TOTAL_DAY_TIME * 2.5 end,
        frequent    = function() return TUNING.TOTAL_DAY_TIME * 9, math.random() * TUNING.TOTAL_DAY_TIME * 2.5 end,
        crazy       = function() return TUNING.TOTAL_DAY_TIME * 10, math.random() * TUNING.TOTAL_DAY_TIME * 2.5 end,
    },

    specialupgradecheck = function(wave_pre_upgraded, wave_override_chance, _wave_override_settings)
        wave_pre_upgraded = nil

        local chance = wave_override_chance * (_wave_override_settings["worm_boss"] or 1)

        if _wave_override_settings["worm_boss"] ~= 0 and (math.random() < chance or _wave_override_settings["worm_boss"] == 9999) then
            wave_pre_upgraded = "available"
        end        

        if wave_pre_upgraded == "available" then
            wave_override_chance = 0
        elseif TheWorld.state.cycles > TUNING.WORM_BOSS_DAYS then
            wave_override_chance = math.min(0.5, wave_override_chance + 0.05)
        end

        return wave_pre_upgraded, wave_override_chance
    end,

    warning_speech = function(wave_pre_upgraded)    
        if wave_pre_upgraded then
            return "ANNOUNCE_WORMS_BOSS"
        else
            return "ANNOUNCE_WORMS"
        end
    end,

    warning_sound_thresholds = function(wave_pre_upgraded, wave_override_chance)    
        if wave_pre_upgraded then
            return {
                { time = 90, sound = "WORM_BOSS", quake = true },
                { time = 90, sound = "WORM_BOSS", quake = true },
                { time = 90, sound = "WORM_BOSS", quake = true },
                { time = 500, sound = "WORM_BOSS", quake = true },
            }
        else
            return {
                { time = 30, sound = "LVL4_WORM" },
                { time = 60, sound = "LVL3_WORM" },
                { time = 90, sound = "LVL2_WORM" },
                { time = 500, sound = "LVL1_WORM" },
            }
        end
    end,

    ShouldUpgrade= function(amount, wave_pre_upgraded)    
        if wave_pre_upgraded == "available" then
            wave_pre_upgraded = "used"   -- We've got one for the wave now, clear this so there aren't more.
            return true, amount, wave_pre_upgraded
        else
            return false, nil, wave_pre_upgraded
        end
    end,
}

local function tile_physics_init(inst)
    inst.Map:AddTileCollisionSet(
        COLLISION.LAND_OCEAN_LIMITS,
        TileGroups.ImpassableTiles, true,
        TileGroups.ImpassableTiles, false,
        0.25, 64
    )
end

local function common_postinit(inst)
    --Initialize lua components
    inst:AddComponent("ambientlighting")

    --Dedicated server does not require these components
    --NOTE: ambient lighting is required by light watchers
    if not TheNet:IsDedicated() then
        inst:AddComponent("dynamicmusic")
        inst:AddComponent("ambientsound")
        inst.components.ambientsound:SetReverbPreset("cave")
        inst.components.ambientsound:SetWavesEnabled(false)
        inst:AddComponent("dsp")
        inst:AddComponent("colourcube")
        inst:AddComponent("hallucinations")

        -- Grotto
        inst:AddComponent("grottowaterfallsoundcontroller")
    end

    TheWorld.Map:SetUndergroundFadeHeight(5)
end

local function AddCaveGelSpawns(inst)
    -- NOTES(JBK): For the ideal case this would be handled in worldgen.
    -- But the generation layout for it is not conducive for algorithmic placement of prefabs on it with custom restrictions with respect to the world as a whole.
    -- So we will generate these spawns here so that they exist according to plan.
    for _, v in pairs(Ents) do
        if v.prefab == "gelblobspawningground" then
            return -- We have gelblobspawningground already back at home.
        end
    end

    --print("Adding gelblobspawningground entities to the world.")
    local map = TheWorld.Map
    local width, height = map:GetSize()
    local accumulated = {}
    local TileGroupManager = TileGroupManager
    local function IsImpassableEdge(tx, ty)
        if TileGroupManager:IsImpassableTile(map:GetTile(tx, ty)) then
            return false
        end
        for i = -1, 1 do
            for j = -1, 1 do
                local tile = map:GetTile(tx + i, ty + j)
                if i ~= 0 and j ~= 0 and (TileGroupManager:IsImpassableTile(tile) or TileGroupManager:IsTemporaryTile(tile) and tile ~= WORLD_TILES.FARMING_SOIL) then
                    return true
                end
            end
        end
        return false
    end
    local BUCKET_SIZE = 8 * TILE_SCALE
    local BUCKET_WIDTH = math.floor(width / BUCKET_SIZE) + 1
    local buckets = {}
    --print("  Finding and putting gelblobspawningground into buckets...")
    for tx = 1, width - 2 do
        for ty = 1, height - 2 do
            if IsImpassableEdge(tx, ty) and IsImpassableEdge(tx, ty + 1) and IsImpassableEdge(tx + 1, ty) and IsImpassableEdge(tx + 1, ty + 1) then
                -- Square check for rectangle.
                local vertical = IsImpassableEdge(tx, ty + 2) and IsImpassableEdge(tx + 1, ty + 2)
                local horizontal = IsImpassableEdge(tx + 2, ty) and IsImpassableEdge(tx + 2, ty + 1)
                if vertical or horizontal then
                    -- Rectangle we have a winner.
                    local x, z
                    if vertical then
                        x = (tx + 0.5 - width / 2) * TILE_SCALE
                        z = (ty + 1 - height / 2) * TILE_SCALE
                    else
                        x = (tx + 1 - width / 2) * TILE_SCALE
                        z = (ty + 0.5 - height / 2) * TILE_SCALE
                    end
                    local id, index = map:GetTopologyIDAtPoint(x, 0, z)
                    if id and not id:find("Archive") and not id:find("Labyrinth") and not id:find("Atrium") then
                        local bucketx, bucketz = math.floor(x / BUCKET_SIZE), math.floor(z / BUCKET_SIZE)
                        local bucketindex = bucketx + bucketz * BUCKET_WIDTH
                        buckets[bucketindex] = buckets[bucketindex] or {
                            points = {},
                            bucketx = bucketx,
                            bucketz = bucketz,
                        }
                        table.insert(buckets[bucketindex].points, Vector3(x, 0, z))
                    end
                end
            end
        end
    end
    --print("  Squishing down gelblobspawningground buckets...")
    local saturatedspawnpoints = {}
    for _, bucket in pairs(buckets) do
        -- Get the average of a 3x3 bucket square and use this for the current bucket.
        local avgx, avgz = 0, 0
        local pointscounted = 0
        for j = -1, 1 do
            for k = -1, 1 do
                local bucketindex = bucket.bucketx + bucket.bucketz * BUCKET_WIDTH
                local bucketpoints = buckets[bucketindex]
                if bucketpoints then
                    local bucketpointscount = #bucketpoints
                    pointscounted = pointscounted + bucketpointscount
                    for i = 1, bucketpointscount do
                        local point = bucketpoints[i]
                        avgx = avgx + point.x
                        avgz = avgz + point.z
                    end
                end
            end
        end
        avgx, avgz = avgx / pointscounted, avgz / pointscounted
        -- Find the closest point in the bucket to the average.
        local closestdsq, closestpoint
        local pointscount = #bucket.points
        for i = 1, pointscount do
            local point = bucket.points[i]
            local dx, dz = point.x - avgx, point.z - avgz
            local dsq = dx * dx + dz * dz
            if closestdsq == nil or closestdsq < dsq then
                closestdsq = dsq
                closestpoint = point
            end
        end
        table.insert(saturatedspawnpoints, closestpoint)
    end
    --print("  Removing too close gelblobspawningground and creating valid ones...")
    local TOO_CLOSE_DIST = 6 * TILE_SCALE
    local TOO_CLOSE_DSQ = TOO_CLOSE_DIST * TOO_CLOSE_DIST
    table.sort(saturatedspawnpoints, function(a, b) -- Sort needed to keep the code deterministic.
        return a.x == b.x and a.z < b.z or a.x < b.x
    end)
    local validspawncount = 0
    local saturatedspawnpointscount = #saturatedspawnpoints
    for i = 1, saturatedspawnpointscount do
        local point1 = saturatedspawnpoints[i]
        for j = 1, saturatedspawnpointscount do -- Not the most efficient loop.
            if i ~= j then
                local point2 = saturatedspawnpoints[j]
                if not point2.badpoint then
                    local dx, dz = point2.x - point1.x, point2.z - point1.z
                    local dsq = dx * dx + dz * dz
                    if dsq < TOO_CLOSE_DSQ then
                        point1.badpoint = true
                        break
                    end
                end
            end
        end
        if not point1.badpoint then
            local spawner = SpawnPrefab("gelblobspawningground")
            spawner.Transform:SetPosition(point1.x, 0, point1.z)
            validspawncount = validspawncount + 1
        end
    end
    --print("Added", validspawncount, "gelblobspawningground entities to the world.")
end

local function master_postinit(inst)
    --Spawners
    inst:AddComponent("shadowcreaturespawner")
    inst:AddComponent("shadowhandspawner")
    inst:AddComponent("brightmarespawner")
    inst:AddComponent("toadstoolspawner")
    inst:AddComponent("grottowarmanager")
    inst:AddComponent("acidbatwavemanager")
    inst:AddComponent("rabbitkingmanager")
    inst:AddComponent("shadowparasitemanager")    

    --gameplay
    inst:AddComponent("caveins")
    inst:AddComponent("kramped")
    inst:AddComponent("chessunlocks")
    inst:AddComponent("townportalregistry")
    inst:AddComponent("linkeditemmanager")

    --world management
    inst:AddComponent("forestresourcespawner") -- a cave version of this would be nice, but it serves it's purpose...
    inst:AddComponent("regrowthmanager")
    inst:AddComponent("desolationspawner")
    inst:AddComponent("mermkingmanager")
    inst:AddComponent("feasts")

    inst:AddComponent("yotd_raceprizemanager")
    inst:AddComponent("yotc_raceprizemanager")
    inst:AddComponent("yotb_stagemanager")

    if METRICS_ENABLED then
        inst:AddComponent("worldoverseer")
    end

    --cave specifics
	inst:AddComponent("daywalkerspawner")
    inst:AddComponent("hounded")
    inst.components.hounded:SetSpawnData(wormspawn)
	inst.components.hounded.max_thieved_spawn_per_thief = 1
    inst:AddComponent("ropebridgemanager")
    inst:AddComponent("gelblobspawner")
    inst:DoTaskInTime(0, AddCaveGelSpawns)

    --anr update retrofitting
    inst:AddComponent("retrofitcavemap_anr")

    -- Archive
    inst:AddComponent("archivemanager")

    -- Rift
    inst:AddComponent("riftspawner")
    inst:AddComponent("miasmamanager")
    inst:AddComponent("shadowthrallmanager")
	inst:AddComponent("ruinsshadelingspawner")
    inst:AddComponent("shadowthrall_mimics")

    -- Meta 5
    inst:AddComponent("decoratedgrave_ghostmanager")

    -- Rifts 6
    inst:AddComponent("vaultroommanager")

    return inst
end

return MakeWorld("cave", prefabs, assets, common_postinit, master_postinit, { "cave" }, {
    tile_physics_init = tile_physics_init,
    cancrossbarriers_flying = true,
})
