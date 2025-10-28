local WEIGHTED_VINE_LOOT = {
    DEFAULT = {
        ["rocks"] = 20,
        ["redgem"] = 0.5,
        ["bluegem"] = 0.5,
        ["purplegem"] = 0.2,
        ["yellowgem"] = 0.02,
        ["orangegem"] = 0.02,
        ["greengem"] = 0.02,
    },

    -- [[Biomes]] --

    -- Forest
    ["FOREST_AREA"] = {
        ["rocks"]               = 15,
        ["goldnugget"]          = 10,
        ["flint"]               = 10,
        ["nitre"]               = 10,
        ["poop"]                = 3,
    },

    ["SAVANNA_AREA"] = {
        ["rocks"]               = 10,
        ["poop"]                = 20,
    },

    ["DECIDUOUS_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 5,
        ["goldnugget"]          = 3,
        ["poop"]                = 5,
    },

    ["MARSH_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 5,
        ["silk"]                = 5,
        ["tentaclespots"]       = 2,
    },

    ["GRASS_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 5,
    },

    ["ROCKY_AREA"] = {
        --["EMPTY"] = 30,
        ["rocks"]               = 20,
        ["nitre"]               = 15,
        ["flint"]               = 15,
        ["goldnugget"]          = 10,
    },

    ["DESERT_AREA"] = {
        ["rocks"]               = 10,
        ["boneshard"]           = 10,
    },

    ["MOON_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 5,
        ["moonglass"]           = 5,
        ["moonrocknugget"]      = 2.5,
        --["rock_avocado_fruit_sprout"] = 0.5,
        --["rock_avocado_fruit"] = 1,
    },

    ["HERMIT_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 5,
        ["moonglass"]           = 3,
        ["moonrocknugget"]      = 1,
        ["slurtle_shellpieces"] = 3,
        --["rock_avocado_fruit_sprout"] = 0.5,
        --["rock_avocado_fruit"] = 1,
    },

    ["GRAVE_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 3,
        --["scrapbook_page"]        = 0.25,
        --["cookingrecipecard"]        = 0.25,
        --["TRINKET"]                   = 1,
    },

    ["MOONQUAY_AREA"] = {
        ["rocks"]               = 5,
        ["poop"]                = 20,
        ["cursed_monkey_token"] = 3,
        ["boneshard"]           = 5,
        -- wires?
    },

    -- Caves
    ["MUD_AREA"] = {
        ["rocks"]               = 20,
        ["fossil_piece"]        = 0.25,
        ["poop"]                = 5,
        ["lightbulb"]           = 3,
        ["slurtle_shellpieces"] = 5,
        ["wormlight"]           = 2,
    },

    ["CAVERN_AREA"] = {
        ["rocks"]               = 35,
        ["goldnugget"]          = 15,
        ["fossil_piece"]        = 2,
        ["guano"]               = 5,
        ["thulecite_pieces"]    = 2.5,
        ["silk"]                = 5,
        ["boneshard"]           = 5,
    },

    ["GUANO_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 10,
        ["goldnugget"]          = 5,
        ["guano"]               = 75,
    },

    ["ROCKYLAND_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 10,
        ["goldnugget"]          = 5,
        ["guano"]               = 30,
        ["slurtle_shellpieces"] = 5,
    },

    ["RUINS_ENTRANCE_AREA"] = { --E.g. lichenland and mud biomes leading to ruins
        ["rocks"]               = 8,
        ["fossil_piece"]        = 0.15,
        ["poop"]                = 5,
        ["flint"]               = 3,
        ["silk"]                = 2,
        ["cutlichen"]           = 10,
        ["thulecite_pieces"]    = 5,
        ["redgem"]              = 0.2,
        ["bluegem"]             = 0.2,
        ["purplegem"]           = 0.1,
        ["yellowgem"]           = 0.02,
        ["orangegem"]           = 0.02,
        ["greengem"]            = 0.02,
        ["wormlight"]           = 0.5,
    },

    ["RUINS_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 3,
        ["thulecite_pieces"]    = 10,
        ["redgem"]              = 0.75,
        ["bluegem"]             = 0.75,
        ["purplegem"]           = 0.5,
        ["yellowgem"]           = 0.2,
        ["orangegem"]           = 0.2,
        ["greengem"]            = 0.2,
        ["wormlight"]           = 0.5,
    },

    ["RUINS_EXTRA_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 3,
        ["thulecite_pieces"]    = 12,
        ["redgem"]              = 1,
        ["bluegem"]             = 1,
        ["purplegem"]           = 0.75,
        ["yellowgem"]           = 0.3,
        ["orangegem"]           = 0.3,
        ["greengem"]            = 0.3,
    },

    ["MOON_GROTTO_AREA"] = {
        ["rocks"]               = 5,
        ["flint"]               = 5,
        ["moonglass"]           = 5,
    },

    ["VENT_AREA"] = { --Aka the default, kinda
        ["rocks"]               = 15,
        ["flint"]               = 6,
        ["goldnugget"]          = 2,
        ["redgem"]              = 0.25,
        ["bluegem"]             = 0.25,
        ["purplegem"]           = 0.1,
        ["yellowgem"]           = 0.02,
        ["orangegem"]           = 0.02,
        ["greengem"]            = 0.02,
    },

    ["VENT_AREA_SHADOW_RIFT"] = {
        ["rocks"]               = 10,
        ["flint"]               = 10,
        ["goldnugget"]          = 40,
        --["dreadstone"]        = 5,
        ["redgem"]              = 10,
        ["bluegem"]             = 10,
        ["purplegem"]           = 8,
        ["yellowgem"]           = 7,
        ["orangegem"]           = 7,
        ["greengem"]            = 7,
    },

    ["MUSHROOM_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 5,
        ["goldnugget"]          = 2,
        --["red_mushroom"]      = 5,
        --["blue_mushroom"]     = 5,
        --["green_mushroom"]    = 5,
    },

    ["SINKHOLE_AREA"] = {
        ["rocks"]               = 12,
        ["flint"]               = 5,
        ["goldnugget"]          = 3,
        ["nitre"]               = 5,
        ["guano"]               = 5,
        ["lightbulb"]           = 5,
    },

    ["MUD_MARSH_AREA"] = {
        ["rocks"]               = 10,
        ["flint"]               = 5,
        ["silk"]                = 5,
        ["tentaclespots"]       = 2,
        ["lightbulb"]           = 5,
    },

    ["EMPTY_AREA"] = {
        ["EMPTY"] = 1,
    }
}

local VINE_LOOT_DATA = {
    ["rocks"]       = {build = "tree_rock_normal", symbols = {"swap_rock1", "swap_rock2", "swap_rock3"}},
    ["redgem"]      = {build = "gems", symbols = {"swap_redgem"}},
    ["bluegem"]     = {build = "gems", symbols = {"swap_bluegem"}},
    ["purplegem"]   = {build = "gems", symbols = {"swap_purplegem"}},
    ["yellowgem"]   = {build = "gems", symbols = {"swap_yellowgem"}},
    ["orangegem"]   = {build = "gems", symbols = {"swap_orangegem"}},
    ["greengem"]    = {build = "gems", symbols = {"swap_greengem"}},

    ["flint"]               = {build = "tree_rock_normal", symbols = {"swap_flint"}},
    ["goldnugget"]          = {build = "tree_rock_normal", symbols = {"swap_goldnugget"}},
    ["nitre"]               = {build = "tree_rock_normal", symbols = {"swap_nitre"}},
    ["thulecite_pieces"]    = {build = "tree_rock_normal", symbols = {"swap_thulecitefragment"}},
    ["fossil_piece"]        = {build = "tree_rock_normal", symbols = {"swap_fossilfragment"}},
    ["moonglass"]           = {build = "tree_rock_normal", symbols = {"swap_moonglass"}},
    ["moonrocknugget"]      = {build = "tree_rock_normal", symbols = {"swap_moonrocknugget"}},
    ["guano"]               = {build = "tree_rock_normal", symbols = {"swap_guano"}},
    ["poop"]                = {build = "tree_rock_normal", symbols = {"swap_poop"}},

    ["boneshard"]           = {build = "tree_rock_normal", symbols = {"swap_bone_shards"}},
    ["silk"]                = {build = "tree_rock_normal", symbols = {"swap_silk"}},
    ["tentaclespots"]       = {build = "tree_rock_normal", symbols = {"swap_tentaclespots"}},
    ["lightbulb"]           = {build = "tree_rock_normal", symbols = {"swap_bulb"}},
    ["wormlight"]           = {build = "tree_rock_normal", symbols = {"swap_worm"}},
    ["cutlichen"]           = {build = "tree_rock_normal", symbols = {"swap_algae"}},
    ["cursed_monkey_token"] = {build = "tree_rock_normal", symbols = {"swap_cursed_beads"}},
    ["slurtle_shellpieces"] = {build = "tree_rock_normal", symbols = {"swap_slurtle_shellpiece"}}

    --dreadstone?
    --scrap?
}

local WORMLIGHT_LOOT_MULTIPLIER = 0.6 / 100
local SILK_LOOT_MULTIPLIER = 25 / 100
local EXTRA_LOOT_MODIFIERS = {
    ["WEB_CREEP"] = {
        test_fn = function(inst)
            return TheWorld.GroundCreep:OnCreep(inst.Transform:GetWorldPosition())
        end,
        loot = function(inst, currenttotalweight)
            return {
                ["silk"] = currenttotalweight * SILK_LOOT_MULTIPLIER,
            }
        end,
    },
    ["CAVE"] = {
        test_fn = function(inst)
            return TheWorld:HasTag("cave")
        end,
        loot = function(inst, currenttotalweight)
            local level = TheWorld.components.hounded:GetWorldEscalationLevel()
            return {
                ["wormlight"] = currenttotalweight * level.numspawns() * WORMLIGHT_LOOT_MULTIPLIER,
            }
        end,
    },
}

local TASKS_TO_LOOT_KEY = {
    -- [[ Forest ]] --

    ["START"]                   = "FOREST_AREA",

    -- FOREST_AREA
    ["Forest hunters"]          = "FOREST_AREA",
    ["Befriend the pigs"]       = "FOREST_AREA",
    ["Magic meadow"]            = "FOREST_AREA",
    ["Hounded magic meadow"]    = "FOREST_AREA",
    ["For a nice walk"]         = "FOREST_AREA",

    -- SAVANNA_AREA
    ["Great Plains"]            = "SAVANNA_AREA",
    ["The hunters"]             = "SAVANNA_AREA",

    -- DECIDUOUS_AREA
    ["Speak to the king"]       = "DECIDUOUS_AREA",
    ["Mole Colony Deciduous"]   = "DECIDUOUS_AREA",

    -- MARSH_AREA
    ["Squeltch"]                = "MARSH_AREA",

    -- GRASS_AREA
    ["Beeeees!"]                = "GRASS_AREA",
    ["Killer bees!"]            = "GRASS_AREA",
    ["Make a Beehat"]           = "GRASS_AREA",
    ["Frogs and bugs"]          = "GRASS_AREA",
    ["MooseBreedingTask"]       = "GRASS_AREA",
    ["Make a pick"]             = "GRASS_AREA",

    -- ROCKY_AREA
    ["Dig that rock"]           = "ROCKY_AREA",
    ["Kill the spiders"]        = "ROCKY_AREA",
    ["Mole Colony Rocks"]       = "ROCKY_AREA",

    -- DESERT_AREA
    ["Lightning Bluff"]         = "DESERT_AREA",
    ["Badlands"]                = "DESERT_AREA",

    -- MOON_AREA
    ["MoonIsland_IslandShards"] = "MOON_AREA",
    ["MoonIsland_Beach"]        = "MOON_AREA",
    ["MoonIsland_Forest"]       = "MOON_AREA",
    ["MoonIsland_Baths"]        = "MOON_AREA",
    ["MoonIsland_Mine"]         = "MOON_AREA",

    ["MoonIslandRetrofit"]      = "MOON_AREA",

    -- [[ Caves ]] --

    -- MUD_AREA
    ["MudWorld"]                = "MUD_AREA",
    ["MudCave"]                 = "MUD_AREA",
    ["MudLights"]               = "MUD_AREA",
    ["MudPit"]                  = "MUD_AREA",
    ["ToadStoolTask1"]          = "MUD_AREA",
    ["ToadStoolTask3"]          = "MUD_AREA",

    -- GUANO_AREA
    ["BigBatCave"]              = "GUANO_AREA",
    ["ToadStoolTask2"]          = "GUANO_AREA",
    ["BatCloister"]             = "GUANO_AREA",

    -- ROCKYLAND_AREA
    ["RockyLand"]               = "ROCKYLAND_AREA",

    -- MUSHROOM_AREA
    ["RedForest"]               = "MUSHROOM_AREA",
    ["GreenForest"]             = "MUSHROOM_AREA",
    ["BlueForest"]              = "MUSHROOM_AREA",
    ["FungalNoiseForest"]       = "MUSHROOM_AREA",
    ["FungalNoiseMeadow"]       = "MUSHROOM_AREA",

    -- CAVERN_AREA
    ["SpillagmiteCaverns"]      = "CAVERN_AREA",

    -- MOON_GROTTO_AREA
    ["MoonCaveForest"]          = "MOON_GROTTO_AREA",

    -- EMPTY_AREA
    ["ArchiveMaze"]             = "EMPTY_AREA",
    ["AncientArchivesRetrofit"] = "EMPTY_AREA",
    ["Vault"]                   = "EMPTY_AREA",

    -- VENT_AREA
    ["CentipedeCaveTask"]       = "VENT_AREA",
    ["CentipedeCaveIslandTask"] = "VENT_AREA",
    ["FumaroleRetrofit"]        = "VENT_AREA",

    -- RUINS_ENTRANCE_AREA
    ["LichenLand"]              = "RUINS_ENTRANCE_AREA",
    ["Residential"]             = "RUINS_ENTRANCE_AREA",

    ["CaveJungle"]              = "RUINS_ENTRANCE_AREA",
    ["Residential2"]            = "RUINS_ENTRANCE_AREA",
    ["Residential3"]            = "RUINS_ENTRANCE_AREA",

    -- RUINS_AREA

    ["Military"]                = "RUINS_AREA",
    ["Sacred"]                  = "RUINS_AREA",
    ["TheLabyrinth"]            = "RUINS_AREA",
    ["SacredAltar"]             = "RUINS_AREA",
    ["AtriumMaze"]              = "RUINS_AREA",

    ["MoreAltars"]              = "RUINS_AREA",

    ["SacredDanger"]            = "RUINS_AREA",
    ["MilitaryPits"]            = "RUINS_AREA",
    ["MuddySacred"]             = "RUINS_AREA",

    -- MARSH_AREA
    ["SwampySinkhole"]          = "MARSH_AREA",
    ["CaveSwamp"]               = "MARSH_AREA",

    -- SINKHOLE_AREA
    ["UndergroundForest"]       = "SINKHOLE_AREA",
    ["PleasantSinkhole"]        = "SINKHOLE_AREA",
    ["RabbitTown"]              = "SINKHOLE_AREA",
    ["RabbitCity"]              = "SINKHOLE_AREA",
    ["SpiderLand"]              = "SINKHOLE_AREA",
    ["RabbitSpiderWar"]         = "SINKHOLE_AREA",

}

for i = 1, 10 do
    -- SINKHOLE_AREA
    TASKS_TO_LOOT_KEY["CaveExitTask"..i] = "SINKHOLE_AREA"
end

local ROOMS_TO_LOOT_KEY = { -- Overrides tasks
    -- [[ Forest ]] --

    -- FOREST_AREA
    ["Forest"]                  = "FOREST_AREA",
    ["Clearing"]                = "FOREST_AREA",
    ["CrappyDeepForest"]        = "FOREST_AREA",
    ["CrappyForest"]            = "FOREST_AREA",

    -- SAVANNA_AREA
    ["BeefalowPlain"]           = "SAVANNA_AREA",
    ["BGSavanna"]               = "SAVANNA_AREA",
    ["WalrusHut_Plains"]        = "SAVANNA_AREA",
    ["BarePlain"]               = "SAVANNA_AREA",
    ["Plain"]                   = "SAVANNA_AREA",

    -- ROCKY_AREA
    ["BGRocky"]                 = "ROCKY_AREA",
    ["Rocky"]                   = "ROCKY_AREA",
    ["WalrusHut_Rocky"]         = "ROCKY_AREA",
    ["PitRoom"]                 = "ROCKY_AREA", -- This room doesn't really have a turf, but world gen ForceConnectivity connects to these rooms with rocky turf

    -- GRASS_AREA
    ["BGGrass"]                 = "GRASS_AREA",
    ["WalrusHut_Grassy"]        = "GRASS_AREA",

    -- [[ Caves ]] --

    -- GUANO_AREA
    ["BGBatCaveRoom"]           = "GUANO_AREA",
    ["BGBatCave"]               = "GUANO_AREA",

    -- CAVERN_AREA
    ["SpidersAndBats"]          = "CAVERN_AREA",

    -- MOON_GROTTO_AREA
    ["MoonMush"]                = "MOON_GROTTO_AREA", --Retrofit
    ["ArchiveMazeEntrance"]     = "MOON_GROTTO_AREA", --Actually the grotto still, despite the name

    -- MARSH_AREA
    ["SpiderSinkholeMarsh"]     = "MARSH_AREA",

    -- RUINS_ENTRANCE_AREA
    ["AtriumMazeEntrance"]      = "RUINS_ENTRANCE_AREA",
    ["LabyrinthEntrance"]       = "RUINS_ENTRANCE_AREA",
    ["BGWildsRoom"]             = "RUINS_ENTRANCE_AREA",
    ["BGWilds"]                 = "RUINS_ENTRANCE_AREA",
    ["WetWilds"]                = "RUINS_ENTRANCE_AREA",
    ["MonkeyMeadow"]            = "RUINS_ENTRANCE_AREA",

    -- RUINS_EXTRA_AREA
    ["RuinedGuarden"]           = "RUINS_EXTRA_AREA",

    -- MUSHROOM_AREA
    ["GreenMushRabbits"]        = "MUSHROOM_AREA",

    -- MUD_MARSH_AREA
    ["TentacleMud"]             = "MUD_MARSH_AREA",
}

local STATIC_LAYOUTS_TO_LOOT_KEY = {
    ["HermitcrabIsland"]        = "HERMIT_AREA",
    ["MonkeyIsland"]            = "MOONQUAY_AREA",
}

local AREA_MODIFIER_FNS = {
    ["VENT_AREA"] = function()
        local riftspawner = TheWorld.components.riftspawner
        if riftspawner and riftspawner:IsShadowPortalActive() then
            return "VENT_AREA_SHADOW_RIFT"
        end
    end,
}

local function CheckModifyLootArea(area)
    if AREA_MODIFIER_FNS[area] then
        return AREA_MODIFIER_FNS[area]() or area
    end

    return area
end

return {
    WEIGHTED_VINE_LOOT = WEIGHTED_VINE_LOOT,
    VINE_LOOT_DATA = VINE_LOOT_DATA,
    TASKS_TO_LOOT_KEY = TASKS_TO_LOOT_KEY,
    ROOMS_TO_LOOT_KEY = ROOMS_TO_LOOT_KEY,
    STATIC_LAYOUTS_TO_LOOT_KEY = STATIC_LAYOUTS_TO_LOOT_KEY,
    EXTRA_LOOT_MODIFIERS = EXTRA_LOOT_MODIFIERS,
    AREA_MODIFIER_FNS = AREA_MODIFIER_FNS,

    CheckModifyLootArea = CheckModifyLootArea,
}