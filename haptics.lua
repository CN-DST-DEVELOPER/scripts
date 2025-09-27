
HapticEffects =
{						
	-- danger effects start ---------------------------------------------------------------------------------------------------------------------------
	{ event="dontstarve/wilson/hungry", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve/wilson/hit", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	
	-- Charlie
	{ event="dontstarve/charlie/warn", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },		
	{ event="dontstarve/charlie/attack", vibration=true, audio=true, vibration_intensity=1.5, audio_intensity=1.0, category="DANGER" },		
	{ event="dontstarve/charlie/attack_low", vibration=true, audio=true, vibration_intensity=1.5, audio_intensity=1.0, category="DANGER" },		
	
	-- temperature
	{ event="dontstarve/winter/freeze_1st", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve/winter/freeze_2nd", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve/winter/freeze_3rd", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve/winter/freeze_4th", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve_DLC001/common/HUD_hot_level1", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve_DLC001/common/HUD_hot_level2", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve_DLC001/common/HUD_hot_level3", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },	
	{ event="dontstarve_DLC001/common/HUD_hot_level4", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="DANGER" },		
	-- danger effects end ----------------------------------------------------------------------------------------------------------------------------
	
	-- player effects start --------------------------------------------------------------------------------------------------------------------------			
	-- movement
	{ event="dontstarve/movement/run_web", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/movement/run_marble", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/movement/slip_fall_thud", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	--electricity
	{ event="dontstarve_DLC001/common/shocked", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- revive
	{ event="meta5/wendy/revive_emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="meta5/grave_spawn/woody_goose", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="meta5/grave_spawn/woody_moose", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="meta5/grave_spawn/woody_beaver", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda1/wanda/rewindtime_rebirth", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/common/resurrectionstone_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/rebirth", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/rebirth_amulet_raise", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/rebirth_amulet_poof", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	{ event="dontstarve/wilson/chest_open", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/chest_close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- try disabling the pickable.pickup sounds (harvesting) as they conflict with the pickup sounds below
	--{ event="dontstarve/wilson/pickup_lichen", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	--{ event="dontstarve/wilson/pickup_lightbulb", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	--{ event="dontstarve/wilson/pickup_plants", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	--{ event="dontstarve/wilson/pickup_reeds", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	--{ event="dontstarve/wilson/pickup_wood", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	--{ event="dontstarve/wilson/harvest_berries", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/harvest_sticks", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	--{ event="turnoftides/common/together/water/harvest_plant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	--{ event="hookline/common/ocean_flotsam/picked", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	
	-- constants.lua PICKUPSOUNDS table
	{ event="aqol/new_test/wood", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/gem", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/cloth", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/metal", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/rock", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/vegetation_firm", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/vegetation_grassy", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/squidgy", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="aqol/new_test/grainy", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/HUD/collect_resource", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	
	{ event="dontstarve/creatures/chester/open", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/creatures/chester/close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/movement/bodyfall_dirt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/beefalo/saddle/regular_foley", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=0.05, category="PLAYER" },	
	{ event="dontstarve/beefalo/saddle/dismount", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/lighter_on", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/lighter_off", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/lighter_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/torch_swing", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
		
	-- impacts
	{ event="dontstarve/movement/bodyfall_dirt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_clay_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_clay_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_clay_object_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_clay_object_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_clay_wall_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_clay_wall_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="dontstarve/impacts/impact_flesh_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_flesh_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_flesh_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_flesh_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_flesh_sml_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_flesh_sml_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_flesh_wet_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_flesh_wet_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_forcefield_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_forcefield_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_fur_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_fur_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="dontstarve/impacts/impact_ghost_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_ghost_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_hive_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_hive_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_hive_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_hive_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_insect_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_insect_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_insect_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_insect_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_insect_sml_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_insect_sml_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_marble_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_marble_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_marble_wall_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_marble_wall_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_mech_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_mech_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_mech_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_mech_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_metal_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_metal_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_mound_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_mound_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_sanity_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_sanity_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shadow_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shadow_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_shell_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shell_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_shell_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shell_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_stone_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_dreadstone_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_dreadstone_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_stone_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_object_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_object_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_stone_sml_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_sml_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_wall_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_stone_wall_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_straw_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_straw_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_straw_wall_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_straw_wall_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="dontstarve/impacts/impact_tree_lrg_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_tree_lrg_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_tree_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_tree_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_vegetable_med_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_vegetable_med_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_vegetable_sml_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_vegetable_sml_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_wood_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_wood_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_wood_wall_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_wood_wall_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/impacts/impact_lunarplant_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_lunarplant_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shadowcloth_armour_dull", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/impacts/impact_shadowcloth_armour_sharp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
		
	-- food
	{ event="dontstarve/wilson/cook", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="dontstarve/wilson/eat", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- crafting
	{ event="dontstarve/wilson/make_trap", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, player_only=true, category="PLAYER" },	
		
	-- attacking things
	{ event="dontstarve/wilson/attack_whoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, player_only=true, category="PLAYER" },	
	{ event="dontstarve/wilson/attack_weapon", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/attack_icestaff", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/attack_firestaff", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/attack_nightsword", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wickerbottom_rework/firepen/launch", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/wilson/blowdart_shoot", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/boomerang_catch", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },
		
	{ event="dontstarve/wilson/hit_animal", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="dontstarve/wilson/hit_armour", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_marble", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_metal", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_nightarmour", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/wilson/hit_scalemail", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_stone", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_straw", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_unbreakable", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_wood", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/hit_dreadstone", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	{ event="dontstarve/common/whip_pre", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/whip_small", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/whip_large", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- other combat
	{ event="dontstarve/creatures/spat/spit_playerstruggle", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/creatures/spat/spit_playerunstuck", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- using items		
	{ event="dontstarve/common/plant", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/tool_slip", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/dig", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/wilson/equip_item", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/equip_item_gold", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/plant_seeds", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/plant_tree", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/rock_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_armour_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_axe_tree", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_axe_mushroom", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_bugnet", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="dontstarve/wilson/use_gemstaff", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_pick_rock", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_umbrella_down", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/wilson/use_umbrella_up", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },
	{ event="dontstarve/characters/woodie/beaver_chop_tree", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },
	{ event="farming/common/watering_can/use", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/dropGeneric", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },			
	{ event="turnoftides/common/together/moon_glass/mine", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="turnoftides/common/together/moon_glass/break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- fishing
	{ event="dontstarve/common/fishingpole_linebreak", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/fishingpole_sethook", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/fishpole_reel_in1_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/fishpole_strain", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/fishingpole_cast_ocean", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- sailing
	{ event="turnoftides/common/together/boat/mast/sail_up", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="turnoftides/common/together/boat/mast/sail_down", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="turnoftides/common/together/boat/jump_on", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- instruments
	{ event="dontstarve/wilson/flute_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/horn_beefalo", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/common/together/houndwhistle", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve_DLC001/common/glommer_bell", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="hookline_2/characters/trident_attack", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	
	-- character specific effects start ---------------------------------------------------------------------------------------------	
	-- walter
	{ event="dontstarve/characters/walter/slingshot/stretch", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/characters/walter/slingshot/shoot", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta5/walter/finger_whistle", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wanda
	{ event="wanda1/wanda/jump_whoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/younger_transition", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/older_transition", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/watch/heal", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/watch/warp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/watch/recall", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/watch/weapon/pst", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="wanda2/characters/wanda/watch/weapon/pst_shadow", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- webber
	{ event="webber1/spiderwhistle/blow", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="webber2/common/spider_repellent", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wendy
	{ event="dontstarve/characters/wendy/summon", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta5/wendy/pour_elixir_f17", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta5/wendy/player_drink", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- willow
	{ event="meta3/willow/pyrokinetic_activate", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wilson
	{ event="dontstarve/wilson/shave_LP", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- winona
	{ event="meta4/winona_remote/click", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta4/winona_teleumbrella/telaumbrella_out", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wolfgang
	{ event="wolfgang2/characters/wolfgang/grunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- woodie
	{ event="dontstarve/characters/woodie/moose/roar", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/characters/woodie/moose/punch", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/characters/woodie/moose/slide", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta2/woodie/weremoose_groundpound", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta2/woodie/werebeaver_groundpound", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },		
	{ event="meta2/woodie/weregoose_takeoff", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="meta2/woodie/weregoose_land", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wormwood
	{ event="dontstarve/characters/wormwood/living_log_craft", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="dontstarve/characters/wormwood/fertalize_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- wortox
	{ event="dontstarve/characters/wortox/soul/hop_out", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- WX-78
	{ event="WX_rework/module/insert", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	{ event="WX_rework/module/remove", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="PLAYER" },	
	
	-- character specific effects end ----------------------------------------------------------------------------------------------------------------
	-- player effects end ----------------------------------------------------------------------------------------------------------------------------
	
	-- environmental effects start -------------------------------------------------------------------------------------------------------------------
	-- fire
	{ event="dontstarve/common/fireAddFuel", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/forestfire", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/campfire", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/treefire", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/nightmareAddFuel", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/wilson/burned", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve_DLC001/common/coldfire", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/fireOut", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	
	{ event="dontstarve/common/meteor_impact", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/meteor_spawn", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	
	-- weather.lua & caveweather.lua
	{ event="dontstarve/AMB/rain", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=0.5 },	
	{ event="rifts3/lunarhail/lunar_rainAMB", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve_DLC001/common/rain_on_tree", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="rifts3/lunarhail/lunarhail_on_tree", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/AMB/caves/rain", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/cave/cave_rain_on_umbrella", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },
	{ event="dontstarve/rain/rain_on_umbrella", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		
	{ event="rifts3/lunarhail/hail_on_umbrella", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		
	{ event="meta4/winona_teleumbrella/rain_on_teleumbrella", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="meta4/winona_teleumbrella/hail_on_teleumbrella", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/rain/thunder_close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	
	-- rifts
	{ event="rifts/portal/rift_explode", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	-- lunar rift
	{ event="rifts2/shadow_rift/groundcrack_expand", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	-- shadow rift
		
	-- wormhole
	{ event="dontstarve/common/teleportworm/open", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/teleportworm/close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/teleportworm/travel", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		

	-- atrium gate
	{ event="dontstarve/common/together/atrium_gate/shadow_pulse", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/common/together/atrium_gate/explode", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	
	-- creatures
	{ event="dontstarve/creatures/hound/firehound_explo", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },
	{ event="dontstarve/creatures/hound/icehound_explo", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/creatures/hound/distant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		
	{ event="dontstarve/creatures/worm/distant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/creatures/worm/emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/characters/walter/woby/big/footstep", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/beefalo/fart", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		
	{ event="dontstarve/tentacle/tentapiller_emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/tentacle/tentapiller_die", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/tentacle/tentapiller_die_VO", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
		
	-- other	
	{ event="rifts4/rope_bridge/shake_lp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },		
	{ event="dontstarve/cave/earthquake", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },	
	{ event="dontstarve/forest/treeFall", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="ENVIRONMENT" },
	-- environmental effects end -------------------------------------------------------------------------------------------------------------------

	-- Boss effects start --------------------------------------------------------------------------------------------------------------------------
	-- deerclops/mutated deerclops
	{ event="dontstarve/creatures/deerclops/distant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/ice_large", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/laser", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/swipe", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/charge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/taunt_grrr", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/taunt_howl", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/bodyfall_snow", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/deerclops/bodyfall_dirt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/common/iceboulder_smash", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/ice_crackling_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/ice_grow_4f_leadin", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/taunt_grrr", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/taunt_howl", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/ice_throw_f13", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_deerclops/ice_throw_f47", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	--{ event="dontstarve/creatures/deerclops/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	--{ event="rifts3/mutated_deerclops/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- bearger / mutated bearger
	{ event="dontstarve_DLC001/creatures/bearger/distant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/groundpound", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/taunt_short", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/step_stomp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/grrrr", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/attack", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/bearger/swhoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_bearger/mutate", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_bearger/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_bearger/buttslam", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	--{ event="dontstarve_DLC001/creatures/bearger/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- ancient guardian (minotaur)
	{ event="ancientguardian_rework/minotaur2/walk", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="ancientguardian_rework/minotaur2/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="ancientguardian_rework/minotaur2/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="ancientguardian_rework/minotaur2/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="ancientguardian_rework/minotaur2/groundpound", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	
	-- antlion
	{ event="dontstarve/creatures/together/antlion/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="dontstarve/creatures/together/antlion/purr", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="dontstarve/creatures/together/antlion/sfx/break_spike", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="dontstarve/creatures/together/antlion/sfx/ground_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="dontstarve/creatures/together/antlion/bodyfall_death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	
	-- bee queen
	{ event="dontstarve/creatures/together/bee_queen/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	
	-- celestial champion
	{ event="moonstorm/creatures/boss/alterguardian1/onothercollide", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian1/roll", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian1/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian1/tantrum", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian1/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },				
	{ event="moonstorm/creatures/boss/alterguardian2/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/scream", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/ground_hit", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/atk_spike", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/atk_spin_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/spike", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian2/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="moonstorm/creatures/boss/alterguardian3/atk_beam", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian3/atk_sky_beam", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian3/atk_beam", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian3/atk_stab", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="moonstorm/creatures/boss/alterguardian3/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },				

	-- crab king
	{ event="turnoftides/common/together/water/emerge/medium", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta4/mortars/loading", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta4/mortars/shoot", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta4/mortars/breach_thrust", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="hookline_2/creatures/boss/crabking/chatter", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="hookline_2/creatures/boss/crabking/vocal", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="hookline_2/creatures/boss/crabking/magic_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="hookline_2/creatures/boss/crabking/hit", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="hookline_2/creatures/boss/crabking/death2", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- dragonfly
	{ event="dontstarve_DLC001/creatures/dragonfly/angry", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="dontstarve_DLC001/creatures/dragonfly/swipe", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/punchimpact", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/firedup", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/buttstomp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/vomitrumble", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/land", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve_DLC001/creatures/dragonfly/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- eye of terror
	{ event="terraria1/eyeofterror/arrive", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="terraria1/eyeofterror/taunt_roar", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="terraria1/eyeofterror/taunt_epic", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="terraria1/eyeofterror/charge_eye", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="terraria1/eyeofterror/charge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="terraria1/eyeofterror/chomp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="terraria1/eyeofterror/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- frost jaw (sharkboi)
	{ event="turnoftides/common/together/water/emerge/large", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta3/sharkboi/swipe_arm", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta3/sharkboi/swipe_tail", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta3/sharkboi/torpedo_drill", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta3/sharkboi/divedown", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="meta3/sharkboi/attack_big", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- fuel weaver
	{ event="dontstarve/creatures/together/stalker/mindcontrol_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/enter", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/death_pop", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/bone_drop", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/taunt_short", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/attack_swipe", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/stalker/attack1_pbaoe", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- klaus
	{ event="dontstarve/creatures/together/klaus/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/swipe", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	--{ event="dontstarve/creatures/together/klaus/scratch", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/attack_3", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/bite", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/bodyfall", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/lock_break", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/klaus/lol", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- malbatross
	{ event="saltydog/creatures/boss/malbatross/whoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	--{ event="saltydog/creatures/boss/malbatross/flap", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="saltydog/creatures/boss/malbatross/beak", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="saltydog/creatures/boss/malbatross/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="saltydog/creatures/boss/malbatross/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="saltydog/creatures/boss/malbatross/swoop", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="saltydog/creatures/boss/malbatross/attack_swipe_water", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="turnoftides/common/together/water/splash/jump_boss", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="turnoftides/common/together/water/splash/boss", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="turnoftides/common/together/water/splash/large", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	
	-- moose goose
	{ event="dontstarve_DLC001/creatures/moose/attack", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="dontstarve_DLC001/creatures/moose/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="dontstarve_DLC001/creatures/moose/swhoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="dontstarve_DLC001/creatures/moose/honk", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="dontstarve_DLC001/creatures/moose/death", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	
	-- nightmare werepig
	{ event="daywalker/action/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="daywalker/action/attack3", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="daywalker/action/attack_slam_whoosh", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="daywalker/action/attack_slam_down", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="daywalker/voice/hurt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="daywalker/voice/speak_short", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="daywalker/voice/attack_big", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="daywalker/voice/chainbreak_break_2", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	
	-- scrappy werepig
	{ event="qol1/daywalker_scrappy/buried_stagger", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="qol1/daywalker_scrappy/step", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="qol1/daywalker_scrappy/emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="qol1/daywalker_scrappy/objectswing_f15", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="qol1/daywalker_scrappy/bodyswing_f5", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="qol1/daywalker_scrappy/laser_pre", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },
	{ event="qol1/daywalker_scrappy/laser_pst", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- toadstool
	{ event="dontstarve/creatures/together/toad_stool/spawn_appear", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/toad_stool/roar", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/toad_stool/roar_phase", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/toad_stool/death_roar", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="dontstarve/creatures/together/toad_stool/death_fall", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="dontstarve/creatures/together/toad_stool/spore_shoot", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	
	-- varg
	{ event="rifts3/mutated_varg/mutate", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts3/mutated_varg/blast_lp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
		
	--wormboss	
	{ event="rifts4/worm_boss/distant", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/dirt_emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/ground_crack", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/taunt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },			
	{ event="rifts4/worm_boss/chomp", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/breach", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/chew", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/chew_big", vibration=true, audio=true, vibration_intensity=2.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/spit_head", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/spit_butt", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/beingdigested_lp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },		
	{ event="rifts4/worm_boss/death_pst", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
		
	-- celestial champion (rifts5)
	{ event="rifts5/wagstaff_boss/footstep_front", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/wagstaff_boss/footstep_stomp", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/wagstaff_boss/missile_explode", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/wagstaff_boss/foot_land", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/wagstaff_boss/beam_down_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/footstep", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/fsbig", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/spawn_3", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/spawn_4", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/taunt_emerge", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/supernova_burst_LP", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/finale2", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/finale", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	{ event="rifts5/lunar_boss/slam", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="BOSS" },	
	-- Boss effects end ----------------------------------------------------------------------------------------------------------------------------
		
	-- HUD & UI effects start ----------------------------------------------------------------------------------------------------------------------
	{ event="dontstarve/HUD/click_mouseover", vibration=true, audio=false, vibration_intensity=0.5, audio_intensity=0.5, category="UI" },	
	{ event="dontstarve/HUD/click_move", vibration=true, audio=false, vibration_intensity=10.0, audio_intensity=0.5, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/player_receives_gift_animation", vibration=true, audio=false, vibration_intensity=2.5, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/skin_change", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/mysterybox/hit1", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/mysterybox/hit2", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/mysterybox/hit3", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/mysterybox/hit4", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/purchase", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/locked", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/Together_HUD/collectionscreen/weave", vibration=true, audio=false, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },		
	
	{ event="dontstarve/HUD/WorldDeathTick", vibration=true, audio=true, vibration_intensity=3.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/map_open", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/map_close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="dontstarve/HUD/scrapbook_pageflip", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },		
	{ event="dontstarve/HUD/scrapbook_dropdown", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },		
	{ event="dontstarve/HUD/craft_open", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=0.5, category="UI" },	
	{ event="dontstarve/HUD/craft_close", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=0.5, category="UI" },			
	{ event="dontstarve/HUD/collect_newitem", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=0.5 },		
	{ event="dontstarve/HUD/recipe_ready", vibration=true, audio=true, vibration_intensity=0.5, audio_intensity=0.5 },				
	
	{ event="wilson_rework/ui/skill_mastered", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="wilson_rework/ui/shadow_skill", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="wilson_rework/ui/lunar_skill", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },	
	{ event="wilson_rework/ui/respec", vibration=true, audio=true, vibration_intensity=1.0, audio_intensity=1.0, category="UI" },		
	-- HUD & UI effects end ------------------------------------------------------------------------------------------------------------------------
}

return HapticEffects