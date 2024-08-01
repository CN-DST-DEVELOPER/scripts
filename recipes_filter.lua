
local function GetCharacterAtlas(owner)
	-- mod character avatars for the crafting menu should be placed in "/images/crafting_menu_avatars/avatar_<name>.xml" with image "avatar_<name>.tex"
	-- if the mod character does not have a specific crafting menu icon, then it will fallback to "/images/avatars/avatar_<name>.xml" with image "avatar_<name>.tex"
	-- these paths will also respect being redirected via MOD_CRAFTING_AVATAR_LOCATIONS or MOD_AVATAR_LOCATIONS

	local atlas_name = nil
	if owner ~= nil and table.contains(MODCHARACTERLIST, owner.prefab) then
        atlas_name = (MOD_CRAFTING_AVATAR_LOCATIONS[owner.prefab] or MOD_CRAFTING_AVATAR_LOCATIONS.Default) .. "avatar_" .. owner.prefab .. ".xml"
	    if softresolvefilepath(atlas_name) == nil then
			atlas_name = (MOD_AVATAR_LOCATIONS[owner.prefab] or MOD_AVATAR_LOCATIONS.Default) .. "avatar_" .. owner.prefab .. ".xml"
		end
	else
		atlas_name = resolvefilepath("images/crafting_menu_avatars.xml")
    end

    return atlas_name
end

local function GetCharacterImage(owner)
	return owner ~= nil and ("avatar_".. owner.prefab ..".tex") or "avatar_mod.tex"
end

local function GetCraftingMenuAtlas()
	return resolvefilepath(CRAFTING_ICONS_ATLAS)
end

CRAFTING_FILTER_DEFS =
{
	{name = "FAVORITES",			atlas = GetCraftingMenuAtlas,	image = "filter_favorites.tex",		custom_pos = true},
	{name = "CRAFTING_STATION",		atlas = GetCraftingMenuAtlas,	image = "filter_none.tex",			custom_pos = true},
	{name = "SPECIAL_EVENT",		atlas = GetCraftingMenuAtlas,	image = "filter_events.tex",		custom_pos = true},
	{name = "MODS",					atlas = GetCraftingMenuAtlas,	image = "filter_modded.tex",		custom_pos = true, recipes = {}},

	{name = "CHARACTER",			atlas = GetCharacterAtlas,		image = GetCharacterImage,			image_size = 80},
	{name = "TOOLS",				atlas = GetCraftingMenuAtlas,	image = "filter_tool.tex",			},
	{name = "LIGHT",				atlas = GetCraftingMenuAtlas,	image = "filter_fire.tex",			},
	{name = "PROTOTYPERS",			atlas = GetCraftingMenuAtlas,	image = "filter_science.tex",		},
	{name = "REFINE",				atlas = GetCraftingMenuAtlas,	image = "filter_refine.tex",		},
	{name = "WEAPONS",				atlas = GetCraftingMenuAtlas,	image = "filter_weapon.tex",		},
	{name = "ARMOUR",				atlas = GetCraftingMenuAtlas,	image = "filter_armour.tex",		},
	{name = "CLOTHING",				atlas = GetCraftingMenuAtlas,	image = "filter_warable.tex",		},
	{name = "RESTORATION",			atlas = GetCraftingMenuAtlas,	image = "filter_health.tex",		},
	{name = "MAGIC",				atlas = GetCraftingMenuAtlas,	image = "filter_skull.tex",			},
	{name = "DECOR",				atlas = GetCraftingMenuAtlas,	image = "filter_cosmetic.tex",		},

	{name = "STRUCTURES",			atlas = GetCraftingMenuAtlas,	image = "filter_structure.tex",		},
	{name = "CONTAINERS",			atlas = GetCraftingMenuAtlas,	image = "filter_containers.tex",	},
	{name = "COOKING",				atlas = GetCraftingMenuAtlas,	image = "filter_cooking.tex",		},
	{name = "GARDENING",			atlas = GetCraftingMenuAtlas,	image = "filter_gardening.tex",		},
	{name = "FISHING",				atlas = GetCraftingMenuAtlas,	image = "filter_fishing.tex",		},
	{name = "SEAFARING",			atlas = GetCraftingMenuAtlas,	image = "filter_sailing.tex",		},
	{name = "RIDING",				atlas = GetCraftingMenuAtlas,	image = "filter_riding.tex",		},
	{name = "WINTER",				atlas = GetCraftingMenuAtlas,	image = "filter_winter.tex",		},
	{name = "SUMMER",				atlas = GetCraftingMenuAtlas,	image = "filter_summer.tex",		},
	{name = "RAIN",					atlas = GetCraftingMenuAtlas,	image = "filter_rain.tex",			},
	{name = "EVERYTHING",			atlas = GetCraftingMenuAtlas,	image = "filter_none.tex",			show_hidden = true},
}

CRAFTING_FILTERS = {}
for i, v in ipairs(CRAFTING_FILTER_DEFS) do
	CRAFTING_FILTERS[v.name] = v
end


CRAFTING_FILTERS.CHARACTER.recipes =
{
	-- Wilson
	"transmute_log",
	"transmute_twigs",
	"transmute_flint",
	"transmute_rocks",

	"transmute_bluegem",
	"transmute_redgem",
	"transmute_purplegem",
	"transmute_orangegem",
	"transmute_yellowgem",
	"transmute_greengem",
	"transmute_opalpreciousgem",

	"transmute_meat",
	"transmute_smallmeat",
	"transmute_goldnugget",
	"transmute_nitre",
	"transmute_marble",
	"transmute_cutstone",
	"transmute_moonrocknugget",

	"transmute_beardhair",
	"transmute_beefalowool",
	"transmute_boneshard",
	"transmute_houndstooth",
	"transmute_poop",

	"transmute_horrorfuel",
	"transmute_dreadstone",
	"transmute_nightmarefuel",

	"transmute_purebrilliance",
	"transmute_moonglass_charged",

	-- Willow
	"lighter",
	"bernie_inactive",

	-- Warly
	"portablecookpot_item",
	"portableblender_item",
	"portablespicer_item",
	"spicepack",

	-- Wurt
	"mermhouse_crafted",
	"mermthrone_construction",
	"mermwatchtower",
	"wurt_turf_marsh",
	"mermhat",

	"mosquitomusk",
	"mosquitobomb",
	"mosquitofertilizer",
	"mosquitomermsalve",
	"offering_pot",
	"offering_pot_upgraded",
	"merm_toolshed",
	"merm_toolshed_upgraded",
	"merm_armory",
	"merm_armory_upgraded",

	"wurt_swampitem_shadow",
	"wurt_swampitem_lunar",

	-- Wendy
	"abigail_flower",
	"sisturn",
	"ghostlyelixir_slowregen",
	"ghostlyelixir_fastregen",
	"ghostlyelixir_shield",
	"ghostlyelixir_retaliation",
	"ghostlyelixir_attack",
	"ghostlyelixir_speed",

	-- Woodie
	"wereitem_goose",
	"wereitem_beaver",
	"wereitem_moose",
	"leif_idol",
	"woodie_boards",
	"woodcarvedhat",
	"walking_stick",

	-- Wathgrithr / Wigfrid
	"spear_wathgrithr",
	"spear_wathgrithr_lightning",
	"wathgrithrhat",
	"wathgrithr_improvedhat",
	"battlesong_durability",
	"battlesong_healthgain",
	"battlesong_sanitygain",
	"battlesong_sanityaura",
	"battlesong_fireresistance",
	"battlesong_instant_taunt",
	"battlesong_instant_panic",
	"battlesong_instant_revive",
	"battlesong_lunaraligned",
	"battlesong_shadowaligned",
	"battlesong_container",
	"saddle_wathgrithr",
	"wathgrithr_shield",

	-- Walter
	"slingshot",
	"walterhat",
	"portabletent_item",
	"slingshotammo_rock",
	"slingshotammo_gold",
	"slingshotammo_marble",
	"slingshotammo_poop",
	"slingshotammo_freeze",
	"slingshotammo_slow",
	"slingshotammo_thulecite",

	-- Wolfgang
	"mighty_gym",
	"dumbbell",
	"dumbbell_golden",
	"dumbbell_marble",
	"dumbbell_gem",

	"dumbbell_heat",
	"dumbbell_redgem",
	"dumbbell_bluegem",
	"wolfgang_whistle",

	-- Wickerbottom
	"bookstation",
	"book_birds",	
	"book_horticulture",
	"book_silviculture",
	"book_sleep",		
	"book_brimstone",	
	"book_tentacles",
	
	"book_fish",
	"book_fire",
	"book_web",
	"book_temperature",
	"book_light",
	"book_rain",
	"book_moon",
	"book_bees",
	"book_research_station",
	
	"book_horticulture_upgraded",
	"book_light_upgraded",

	-- Maxwell
	"tophat_magician",
	"magician_chest",
	"waxwelljournal",

	-- Winona
	"sewing_tape",
	"winona_remote",
	"winona_catapult",
	"winona_catapult_item",
	"winona_spotlight",
	"winona_spotlight_item",
	"winona_battery_low",
	"winona_battery_low_item",
	"winona_battery_high",
	"winona_battery_high_item",
	"winona_storage_robot",
	"winona_telebrella",
	"winona_teleport_pad_item",

    "inspectacleshat",
	"roseglasseshat",

	-- Webber
	"spidereggsack",
	"spiderden_bedazzler",
	"spider_whistle",
	"spider_repellent",
	"spider_healer_item",
	"mutator_warrior",
	"mutator_dropper",
	"mutator_hider",
	"mutator_spitter",
	"mutator_moon",
	"mutator_healer",
	"mutator_water",

	-- Wormwood
	"compostwrap",
	"livinglog",
	"armor_bramble",
	"trap_bramble",
    "wormwood_sapling",
    "wormwood_berrybush",
    "wormwood_berrybush2",
    "wormwood_juicyberrybush",
    "wormwood_reeds",
	"wormwood_lureplant",
	"ipecacsyrup",
	"wormwood_carrat",
	"wormwood_lightflier",
	"wormwood_fruitdragon",
	"armor_lunarplant_husk",

	-- Wanda
	"pocketwatch_dismantler",
	"pocketwatch_parts",
	"pocketwatch_heal",
	"pocketwatch_revive",
	"pocketwatch_warp",
	"pocketwatch_recall",
	"pocketwatch_portal",
	"pocketwatch_weapon",

	-- Wes
	"balloons_empty",
	"balloon",
	"balloonspeed",
	"balloonparty",
	"balloonvest",
	"balloonhat",

	-- WX78
	"wx78module_maxhealth",
    "wx78module_maxhealth2",
    "wx78module_maxsanity1",
	"wx78module_maxsanity",
    "wx78module_bee",
    "wx78module_music",
    "wx78module_maxhunger1",
    "wx78module_maxhunger",
	"wx78module_movespeed",
	"wx78module_movespeed2",
	"wx78module_heat",
    "wx78module_cold",
    "wx78module_taser",
    "wx78module_nightvision",
    "wx78module_light",
    "wx78_moduleremover",
    "wx78_scanner_item",
}

CRAFTING_FILTERS.SPECIAL_EVENT.recipes =
{
	"wintersfeastoven",
	"table_winters_feast",
	"winter_treestand",
	"giftwrap",

	"madscience_lab",
	"candybag",

	"perdshrine",
	"wargshrine",
	"pigshrine",
	"yotc_carratshrine",
	"yotb_beefaloshrine",
	"yot_catcoonshrine",
	"yotr_rabbitshrine",
	"yotd_dragonshrine",

}

CRAFTING_FILTERS.CRAFTING_STATION.recipes =
{
	-- ancients
	"thulecite",
	"wall_ruins_item",
	"nightmare_timepiece",
	"orangeamulet",
	"yellowamulet",
	"greenamulet",
	"orangestaff",
	"yellowstaff",
	"greenstaff",
	"multitool_axe_pickaxe",
	"nutrientsgoggleshat",
	"ruinshat",
	"armorruins",
	"ruins_bat",
	"eyeturret_item",
    "shadow_forge_kit",
	"blueprint_craftingset_ruins_builder",
	"blueprint_craftingset_ruinsglow_builder",

	-- cartography desk
	"mapscroll",

	----CELESTIAL----
	"moonrockidol",
	"multiplayer_portal_moonrock_constr_plans",
	"lunar_forge_kit",
	"moon_mushroomhat",

	----MOON_ALTAR-----
	"moonglassaxe",
	"glasscutter",
	"turf_meteor",
	"turf_fungus_moon",
	"bathbomb",
	"chesspiece_butterfly_sketch",
	"chesspiece_moon_sketch",

	----LUNAR_FORGE----
	"armor_lunarplant",
	"lunarplanthat",
	"bomb_lunarplant",
	"staff_lunarplant",
	"sword_lunarplant",
	"pickaxe_lunarplant",
	"shovel_lunarplant",
	"lunarplant_kit",

	"beargerfur_sack",
	"deerclopseyeball_sentryward_kit",
	"houndstooth_blowpipe",

	----SHADOW_FORGE----
	"armor_voidcloth",
	"voidclothhat",
	"voidcloth_umbrella",
	"voidcloth_scythe",
	"voidcloth_kit",
	"beeswax_spray",

	-- Hermit Crab
	"hermitshop_hermit_bundle_shells",
	"hermitshop_winch_blueprint",
	"hermitshop_turf_shellbeach_blueprint",
	"hermitshop_oceanfishingbobber_crow",
	"hermitshop_oceanfishingbobber_robin",
	"hermitshop_oceanfishingbobber_robin_winter",
	"hermitshop_oceanfishingbobber_canary",
	"hermitshop_tacklecontainer",
	"hermitshop_oceanfishinglure_hermit_rain",
	"hermitshop_oceanfishinglure_hermit_snow",
	"hermitshop_oceanfishinglure_hermit_drowsy",
	"hermitshop_oceanfishinglure_hermit_heavy",
	"hermitshop_oceanfishingbobber_goose",
	"hermitshop_oceanfishingbobber_malbatross",
	"hermitshop_chum",
	"hermitshop_chum_blueprint",
	"hermitshop_supertacklecontainer",
	"hermitshop_winter_ornament_boss_hermithouse",
	"hermitshop_winter_ornament_boss_pearl",

	-- waxwelljournal
	"shadowlumber_builder",
	"shadowminer_builder",
	"shadowdigger_builder",
	"shadowduelist_builder",

	-- portableblender
	"spice_garlic",
	"spice_sugar",
	"spice_chili",
	"spice_salt",

	-- critterlab
	"critter_kitten_builder",
	"critter_puppy_builder",
	"critter_lamb_builder",
	"critter_perdling_builder",
	"critter_dragonling_builder",
	"critter_glomling_builder",
	"critter_lunarmothling_builder",
	"critter_eyeofterror_builder",

	-- Sculpting
	"chesspiece_hornucopia_builder",
	"chesspiece_pipe_builder",
	"chesspiece_anchor_builder",
	"chesspiece_pawn_builder",
	"chesspiece_rook_builder",
	"chesspiece_knight_builder",
	"chesspiece_bishop_builder",
	"chesspiece_muse_builder",
	"chesspiece_formal_builder",
	"chesspiece_deerclops_builder",
	"chesspiece_bearger_builder",
	"chesspiece_moosegoose_builder",
	"chesspiece_dragonfly_builder",
	"chesspiece_minotaur_builder",
	"chesspiece_toadstool_builder",
	"chesspiece_beequeen_builder",
	"chesspiece_klaus_builder",
	"chesspiece_antlion_builder",
	"chesspiece_stalker_builder",
	"chesspiece_malbatross_builder",
	"chesspiece_crabking_builder",
	"chesspiece_butterfly_builder",
	"chesspiece_moon_builder",
	"chesspiece_guardianphase3_builder",
	"chesspiece_eyeofterror_builder",
	"chesspiece_twinsofterror_builder",
	"chesspiece_clayhound_builder",
	"chesspiece_claywarg_builder",
	"chesspiece_carrat_builder",
	"chesspiece_beefalo_builder",
	"chesspiece_kitcoon_builder",
	"chesspiece_catcoon_builder",
	"chesspiece_manrabbit_builder",
	"chesspiece_daywalker_builder",
	"chesspiece_deerclops_mutated_builder",
	"chesspiece_warg_mutated_builder",
	"chesspiece_bearger_mutated_builder",
	"chesspiece_yotd_builder",
	"chesspiece_sharkboi_builder",

	-- wintersfeastoven
	"wintercooking_berrysauce",
	"wintercooking_bibingka",
	"wintercooking_cabbagerolls",
	"wintercooking_festivefish",
	"wintercooking_gravy",
	"wintercooking_latkes",
	"wintercooking_lutefisk",
	"wintercooking_mulleddrink",
	"wintercooking_panettone",
	"wintercooking_pavlova",
	"wintercooking_pickledherring",
	"wintercooking_polishcookie",
	"wintercooking_pumpkinpie",
	"wintercooking_roastturkey",
	"wintercooking_stuffing",
	"wintercooking_sweetpotato",
	"wintercooking_tamales",
	"wintercooking_tourtiere",

	-- mad science
	"halloween_experiment_bravery",
	"halloween_experiment_health",
	"halloween_experiment_sanity",
	"halloween_experiment_volatile",
	"halloween_experiment_moon",
	"halloween_experiment_root",

    -- Year of the Dragon
    "dragonboat_pack",
    "boatrace_start_throwable_deploykit",
    "boatrace_checkpoint_throwable_deploykit",
	"boatrace_seastack_throwable_deploykit",
    "dragonboat_kit",
    "yotd_steeringwheel_item",
    "yotd_oar",
    "yotd_anchor_item",
    "mast_yotd_item",
	"boat_bumper_yotd_kit",
    "mastupgrade_lamp_item_yotd",
    "yotd_boatpatch_proxy",
	"chesspiece_yotd_sketch",

	-- Year of the Rabbit
	"yotr_fightring_kit",
	"yotr_token",

	"handpillow_petals",
	"handpillow_kelp",
	"handpillow_beefalowool",
	"handpillow_steelwool",

	"bodypillow_petals",
	"bodypillow_kelp",
	"bodypillow_beefalowool",
	"bodypillow_steelwool",

	"yotr_food1",
	"yotr_food2",
	"yotr_food3",
	"yotr_food4",

	"yotr_decor_1_item",
	"yotr_decor_2_item",

	"chesspiece_manrabbit_sketch",
	"nightcaphat",

	-- Year of the Kitcoon
	"ticoon_builder",
	"kitcoonden_kit",
	"kitcoon_nametag",
	"cattoy_mouse",
	"kitcoondecor1_kit",
	"kitcoondecor2_kit",
	"chesspiece_catcoon_sketch",
	"chesspiece_kitcoon_sketch",

	-- Year of the Beefalo
	"yotb_stage_item",
	"yotb_post_item",
	"yotb_sewingmachine_item",
	"yotb_pattern_fragment_1",
	"yotb_pattern_fragment_2",
	"yotb_pattern_fragment_3",
	"chesspiece_beefalo_sketch",

	-- Year of the Carrat
	"yotc_carrat_race_start_item",
	"yotc_carrat_race_finish_item",
	"yotc_carrat_race_checkpoint_item",
	"yotc_shrinecarrat",
	"yotc_carrat_gym_speed_item",
	"yotc_carrat_gym_reaction_item",
	"yotc_carrat_gym_stamina_item",
	"yotc_carrat_gym_direction_item",
	"yotc_carrat_scale_item",
	"yotc_seedpacket",
	"yotc_seedpacket_rare",
	"chesspiece_carrat_sketch",

	-- Year of the Pig
	"yotp_food3",
	"yotp_food1",
	"yotp_food2",

	-- Year of the Varg
	"houndwhistle",
	"chesspiece_clayhound_sketch",
	"chesspiece_claywarg_sketch",

	-- Year of the Gobbler
	"perdfan",

	-- Year of the X
	"firecrackers",
	"redlantern",
	"miniboatlantern",
	"dragonheadhat",
	"dragonbodyhat",
	"dragontailhat",

	--- summer carnival prize shop ---
	"carnival_popcorn",
	"carnival_seedpacket",
	"carnivalfood_corntea",
	"carnival_vest_a",
	"carnival_vest_b",
	"carnival_vest_c",
	"carnivaldecor_figure_kit",
	"carnivaldecor_figure_kit_season2",
	"carnivalcannon_confetti_kit",
	"carnivalcannon_sparkle_kit",
	"carnivalcannon_streamer_kit",
	"carnivaldecor_plant_kit",
	"carnivaldecor_banner_kit",
	"carnivaldecor_eggride1_kit",
	"carnivaldecor_eggride2_kit",
	"carnivaldecor_eggride3_kit",
	"carnivaldecor_eggride4_kit",
	"carnivaldecor_lamp_kit",

	--- summer carnival host
	"carnival_plaza_kit",
	"carnival_prizebooth_kit",
	"carnival_gametoken",
	"carnival_gametoken_multiple",
	"carnivalgame_memory_kit",
	"carnivalgame_feedchicks_kit",
	"carnivalgame_herding_kit",
	"carnivalgame_shooting_kit",
	"carnivalgame_wheelspin_kit",
	"carnivalgame_puckdrop_kit",
}


CRAFTING_FILTERS.TOOLS.recipes =
{
	"axe",
	"pickaxe",
	"shovel",
	"hammer",
	"farm_hoe",
	"pitchfork",
	"goldenaxe",
	"goldenpickaxe",
	"goldenshovel",
	"golden_farm_hoe",
	"goldenpitchfork",
	"trap",
	"birdtrap",
	"bugnet",
	"razor",
	"compass",
	"walking_stick",
	"cane",
	"sewing_kit",
	"sewing_tape",
	"winona_remote",
	"wagpunkbits_kit",
	"miniflare",
	"megaflare",
	"wateringcan",
	"premiumwateringcan",
	"fishingrod",
	"oceanfishingrod",
	"pocket_scale",
	"beef_bell",
	"saddlehorn",
	"brush",
	"antlionhat",
	"featherpencil",
	"sentryward",
	"archive_resonator_item",

	"reskin_tool",

	"pocketwatch_dismantler",
	"balloons_empty",
	"spiderden_bedazzler",
	"spider_whistle",
	"spider_repellent",
    "wx78_moduleremover",
    "wx78_scanner_item",
}

CRAFTING_FILTERS.LIGHT.recipes =
{
	"lighter",
	"torch",
	"campfire",
	"firepit",
	"cotl_tabernacle_level1",
	"coldfire",
	"coldfirepit",
	"pumpkin_lantern",
	"minerhat",
	"molehat",
    "wx78module_nightvision",
	"lantern",
    "wx78module_light",
	"nightstick",
	"nightlight",
	"winona_spotlight",
	"winona_spotlight_item",
	"dragonflyfurnace",
	"mushroom_light",
	"mushroom_light2",
	"archive_resonator_item",
}

CRAFTING_FILTERS.PROTOTYPERS.recipes =
{
	"researchlab",
	"researchlab2",
	"seafaring_prototyper",
	"tacklestation",
	"cartographydesk",
	"researchlab4",
	"researchlab3",
	"sculptingtable",
	"turfcraftingstation",
	"carpentry_station",

	"madscience_lab",
	"wintersfeastoven",
	"perdshrine",
	"wargshrine",
	"pigshrine",
	"yotc_carratshrine",
	"yotb_beefaloshrine",
	"yot_catcoonshrine",
	"yotr_rabbitshrine",
	"yotd_dragonshrine",
}

CRAFTING_FILTERS.REFINE.recipes =
{
	"rope",
	"boards",
	"cutstone",
	"papyrus",
	"transistor",
	"livinglog",
	"pocketwatch_parts",
	"waxpaper",
	"beeswax",
	"marblebean",
	"bearger_fur",
	"nightmarefuel",
	"purplegem",
	"moonrockcrater",
	"malbatross_feathered_weave",
	"refined_dust",
}

CRAFTING_FILTERS.WEAPONS.recipes =
{
	"pocketwatch_weapon",
	"slingshot",
	"winona_catapult",
	"winona_catapult_item",
	"spear",
	"spear_wathgrithr",
	"spear_wathgrithr_lightning",
	"boomerang",
	"hambat",
	"batbat",
	"whip",
	"nightstick",
	"nightsword",
	"wathgrithr_shield",
	"sleepbomb",
	"blowdart_pipe",
	"blowdart_fire",
	"blowdart_yellow",
	"blowdart_sleep",
	"staff_tornado",
	"trident",
	"firestaff",
	"icestaff",
	"gunpowder",
	"panflute",
	"trap_teeth",
	"trap_bramble",
	"beemine",
	"waterballoon",
	"boat_cannon_kit",
	"cannonball_rock_item",
	"fence_rotator",
}

CRAFTING_FILTERS.ARMOUR.recipes =
{
	"armorgrass",
	"armorwood",
	"armor_bramble",
	"armordragonfly",
	"armor_sanity",
	"armormarble",
	"woodcarvedhat",
	"footballhat",
	"wathgrithrhat",
	"wathgrithr_improvedhat",
	"cookiecutterhat",
	"beehat",
	"armordreadstone",
	"dreadstonehat",
	"armorwagpunk",
	"wagpunkhat",
	"wathgrithr_shield",
}

CRAFTING_FILTERS.CLOTHING.recipes =
{
	"sewing_kit",
	"sewing_tape",
	"mermhat",
	"walterhat",
	"balloonvest",
	"balloonhat",
	"backpack",
	"seedpouch",
	"piggyback",
	"icepack",
	"onemanband",
	"armorslurper",
	"minifan",
	"grass_umbrella",
	"umbrella",
	"winona_telebrella",
	"featherfan",
	"flowerhat",
	"goggleshat",
	"kelphat",
	"strawhat",
	"tophat",
	"tophat_magician",
	"rainhat",
	"earmuffshat",
	"catcoonhat",
	"winterhat",
	"beefalohat",
	"deserthat",
	"antlionhat",
	"moonstorm_goggleshat",
	"watermelonhat",
	"icehat",
	"beehat",
	"featherhat",
	"bushhat",
	"raincoat",
	"sweatervest",
	"trunkvest_summer",
	"trunkvest_winter",
	"reflectivevest",
	"hawaiianshirt",
	"walking_stick",
	"cane",
	"beargervest",
	"eyebrellahat",
	"red_mushroomhat",
	"green_mushroomhat",
	"blue_mushroomhat",
	"polly_rogershat",
    --
    "inspectacleshat",
	"roseglasseshat",
}

CRAFTING_FILTERS.RESTORATION.recipes =
{
	"pocketwatch_heal",
	"pocketwatch_revive",
	"spider_healer_item",
    "wx78module_bee",

	"healingsalve",
	"healingsalve_acid",
	"bandage",
	"tillweedsalve",
	"compostwrap",
	"reviver",
	"lifeinjector",
	"amulet",
	"bedroll_straw",
	"bedroll_furry",
	"portabletent_item",
	"tent",
	"siestahut",
	"resurrectionstatue",
}

CRAFTING_FILTERS.COOKING.recipes =
{
	"wintersfeastoven",

	"lighter",
	"portablecookpot_item",
	"portableblender_item",
	"portablespicer_item",
	"spicepack",

	"cookbook",
	"cookpot",
	"meatrack",
	"campfire",
	"firepit",
	"cotl_tabernacle_level1",
	"icebox",
	"saltbox",
	"icepack",
	"dragonflyfurnace",

}

CRAFTING_FILTERS.GARDENING.recipes =
{
	"farm_plow_item",
	"farm_hoe",
	"golden_farm_hoe",
	"wateringcan",
	"premiumwateringcan",
	"fertilizer",
	"soil_amender",
	"treegrowthsolution",
	"compostwrap",
	"compostingbin",
	"plantregistryhat",
	"onemanband",
    "wx78module_music",
	"seedpouch",
	"mushroom_farm",
	"beebox",
	"trap",
	"birdtrap",
	"birdcage",
	"ocean_trawler_kit",
	"trophyscale_oversizedveggies",
}

CRAFTING_FILTERS.FISHING.recipes =
{
	"tacklestation",

	"fishingrod",
	"oceanfishingrod",

	"oceanfishingbobber_ball",
	"oceanfishingbobber_oval",
	"oceanfishingbobber_crow",
	"oceanfishingbobber_robin",
	"oceanfishingbobber_robin_winter",
	"oceanfishingbobber_canary",
	"oceanfishingbobber_goose",
	"oceanfishingbobber_malbatross",
	
	"oceanfishinglure_spoon_red",
	"oceanfishinglure_spoon_green",
	"oceanfishinglure_spoon_blue",
	"oceanfishinglure_spinner_red",
	"oceanfishinglure_spinner_green",
	"oceanfishinglure_spinner_blue",
	
	"oceanfishinglure_hermit_rain",
	"oceanfishinglure_hermit_snow",
	"oceanfishinglure_hermit_drowsy",
	"oceanfishinglure_hermit_heavy",

	"chum",
	"pocket_scale",

	"ocean_trawler_kit",
	"fish_box",
	"trophyscale_fish",
}

CRAFTING_FILTERS.SEAFARING.recipes =
{
	"seafaring_prototyper",
	"boat_grass_item",
	"boat_item",
	"boatpatch_kelp",
	"boatpatch",
	"oar",
	"oar_driftwood",
	"balloonvest",
	"anchor_item",
	"steeringwheel_item",
	"boat_rotator_kit",
	"mast_item",
	"mast_malbatross_item",

	"boat_bumper_kelp_kit",
	"boat_bumper_shell_kit",
	"boat_bumper_yotd_kit",

	"boat_cannon_kit",
	"cannonball_rock_item",

	"ocean_trawler_kit",

	"mastupgrade_lamp_item",
	"mastupgrade_lightningrod_item",
    "mastupgrade_lamp_item_yotd",

	"fish_box",
	"winch",
	"waterpump",

	"boat_magnet_kit",
	"boat_magnet_beacon",

    "dock_kit",
    "dock_woodposts_item",

	"chesspiece_anchor_sketch",
}

CRAFTING_FILTERS.CONTAINERS.recipes =
{
	"bundlewrap",
	"giftwrap",
	"backpack",
	"piggyback",
	"icepack",
	"spicepack",
	"seedpouch",
	"candybag",
	"treasurechest",
    "chestupgrade_stacksize",
	"dragonflychest",
	"magician_chest",
	"icebox",
	"saltbox",
	"fish_box",
	"battlesong_container",
}

CRAFTING_FILTERS.STRUCTURES.recipes =
{
	"wintersfeastoven",
	"table_winters_feast",
	"winter_treestand",
	"madscience_lab",
	"perdshrine",
	"wargshrine",
	"pigshrine",
	"yotc_carratshrine",
	"yotb_beefaloshrine",
	"yot_catcoonshrine",
	"yotr_rabbitshrine",
	"yotd_dragonshrine",

	"researchlab",
	"researchlab2",
	"seafaring_prototyper",
	"tacklestation",
	"cartographydesk",
	"researchlab4",
	"researchlab3",
	"sculptingtable",
	"turfcraftingstation",
	"carpentry_station",

	"cookpot",
	"meatrack",
	"ocean_trawler_kit",

	"nightlight",
	"dragonflyfurnace",
	"mushroom_light",
	"mushroom_light2",

	"sisturn",
	"mermhouse_crafted",
	"mermthrone_construction",
	"mermwatchtower",
	"winona_catapult",
	"winona_catapult_item",
	"winona_spotlight",
	"winona_spotlight_item",
	"winona_battery_low",
	"winona_battery_low_item",
	"winona_battery_high",
	"winona_battery_high_item",
	"winona_teleport_pad_item",
	"mighty_gym",
	"spidereggsack",

	"treasurechest",
	"dragonflychest",
	"magician_chest",
	"icebox",
	"saltbox",

	"winterometer",
	"rainometer",
	"lightning_rod",
	"firesuppressor",
	"moondial",
	"archive_resonator_item",
	"punchingbag",
	"punchingbag_lunar",
	"punchingbag_shadow",

	"tent",
	"portabletent_item",
	"siestahut",
	"resurrectionstatue",

	"pighouse",
	"rabbithouse",
	"saltlick",
	"saltlick_improved",
	"townportal",

    "dock_kit",

	"telebase",
	"endtable",

	"moon_device_construction1",

	"scarecrow",
    "sewing_mannequin",

	"fence_gate_item",
	"fence_item",
	"wall_hay_item",
	"wall_wood_item",
	"wall_stone_item",
	"wall_scrap_item",
	"wall_moonrock_item",	
	"wall_dreadstone_item",

	"homesign",
	"arrowsign_post",
	"minisign_item",

	"support_pillar_scaffold",
	"support_pillar_dreadstone_scaffold",
}

CRAFTING_FILTERS.MAGIC.recipes =
{
	"abigail_flower",
	"pocketwatch_weapon",
	"wereitem_goose",
	"wereitem_beaver",
	"wereitem_moose",
	"leif_idol",
	"tophat_magician",
	"magician_chest",
	"waxwelljournal",

	"researchlab4",
	"researchlab3",
	"resurrectionstatue",
	"panflute",
	"onemanband",
	"nightlight",
	"armor_sanity",
	"nightsword",
	"armordreadstone",
	"dreadstonehat",
	"batbat",
	"armorslurper",
	"antlionhat",
	"purplegem",
	"amulet",
	"blueamulet",
	"purpleamulet",
	"firestaff",
	"icestaff",
	"telestaff",
	"telebase",
	"sentryward",
	"moondial",
	"townportal",
	"nightmarefuel",
	"punchingbag_lunar",
	"punchingbag_shadow",
}

CRAFTING_FILTERS.RIDING.recipes =
{
	"beef_bell",
	"saltlick",
	"saltlick_improved",
	"brush",
	"saddlehorn",
	"saddle_basic",
	"saddle_war",
	"saddle_wathgrithr",
	"saddle_race",
	"beefalo_groomer",
}

CRAFTING_FILTERS.WINTER.recipes =
{
	"campfire",
	"firepit",
	"cotl_tabernacle_level1",
	"dragonflyfurnace",
	"heatrock",
    "wx78module_heat",

	"sweatervest",
	"raincoat",
	"trunkvest_summer",
	"trunkvest_winter",
	"beargervest",

	"earmuffshat",
	"catcoonhat",
	"winterhat",
	"beefalohat",

	"tent",

	"winterometer",
}

CRAFTING_FILTERS.SUMMER.recipes =
{
	"coldfire",
	"coldfirepit",
	"heatrock",
    "wx78module_cold",

	"blueamulet",

	"minifan",
	"grass_umbrella",
	"umbrella",
	"featherfan",

	"reflectivevest",
	"hawaiianshirt",

	"strawhat",
	"plantregistryhat",
	"red_mushroomhat",
	"green_mushroomhat",
	"blue_mushroomhat",
	"watermelonhat",
	"deserthat",
	"icehat",
	"eyebrellahat",

	"firesuppressor",
	"turf_dragonfly",

	"siestahut",

	"waterballoon",
	"wateringcan",
	"premiumwateringcan",

	"winterometer",
	"rainometer",
}

CRAFTING_FILTERS.RAIN.recipes =
{
	"grass_umbrella",
	"umbrella",
	"winona_telebrella",
	"raincoat",
	"balloonhat",
	"strawhat",
	"beehat",
	"tophat",
	"tophat_magician",
	"minerhat",
	"cookiecutterhat",
	"rainhat",
	"eyebrellahat",

	"lightning_rod",
	"rainometer",
}

CRAFTING_FILTERS.DECOR.recipes =
{
	"winter_treestand",

	"sculptingtable",
	"turfcraftingstation",
	"featherpencil",
	"reskin_tool",
	"homesign",
	"arrowsign_post",
	"minisign_item",
	"pottedfern",
	"succulent_potted",
	"endtable",
	"wardrobe",
	"beefalo_groomer",
	"trophyscale_fish",
	"trophyscale_oversizedveggies",

	"fence_gate_item",
	"fence_item",
	"wall_hay_item",
	"wall_wood_item",
	"wall_stone_item",
	"wall_scrap_item",
	"wall_moonrock_item",	
	"wall_dreadstone_item",

	"pirate_flag_pole",
    "dock_kit",
	"dock_woodposts_item",

    "sewing_mannequin",

	"turf_road",
	"turf_cotl_brick",
	"turf_woodfloor",
	"turf_cotl_gold",
	"turf_checkerfloor",
	"turf_carpetfloor",
	"turf_carpetfloor2",
	"turf_mosaic_red",
	"turf_mosaic_blue",
	"turf_mosaic_grey",
	"turf_dragonfly",
	"turf_ruinsbrick",
	"turf_ruinsbrick_glow",
	"turf_ruinstiles",
	"turf_ruinstiles_glow",
	"turf_ruinstrim",
	"turf_ruinstrim_glow",
	"turf_archive",

	"turf_pebblebeach",
	"turf_shellbeach",
	"turf_monkey_ground",

	"turf_forest",
	"turf_grass",
	"turf_savanna",
	"turf_deciduous",
	"turf_desertdirt",
	"turf_rocky",
	"turf_cave",
	"turf_underrock",
	"turf_sinkhole",
	"turf_marsh",
	"turf_mud",
	"turf_fungus",
	"turf_fungus_red",
	"turf_fungus_green",
	"turf_beard_rug",	

	"ruinsrelic_plate",
	"ruinsrelic_chipbowl",
	"ruinsrelic_bowl",
	"ruinsrelic_vase",
	"ruinsrelic_chair",
	"ruinsrelic_table",

	"chesspiece_anchor_sketch",

	"phonograph",
	"record",

	"wood_chair",
	"wood_stool",
	"wood_table_round",
	"wood_table_square",
    "decor_centerpiece",
	"decor_lamp",
	"decor_flowervase",
	"decor_pictureframe",
	"decor_portraitframe",
}


------------------------------------------------------------------------
for _, filter in pairs(CRAFTING_FILTERS) do
	if filter.recipes ~= nil then
		filter.default_sort_values = table.invert(filter.recipes)
	end
end

CRAFTING_FILTERS.FAVORITES.recipes = function() return TheCraftingMenuProfile:GetFavorites() end
CRAFTING_FILTERS.FAVORITES.default_sort_values = function() return TheCraftingMenuProfile:GetFavoritesOrder() end
