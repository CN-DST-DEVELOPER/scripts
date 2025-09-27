require("constants")

local function grass_area()
	local grass = {}

	for i=1,math.random(4) do
		table.insert(grass,"grass")
	end

	for i=1,math.random(3) do
		if math.random() < 0.5 then
			table.insert(grass,"evergreen_stump")
		end
	end

	return grass
end

local function waterlogged_tree_area()
	local stuff = {}

	table.insert(stuff,"oceantree")
	for i=1,6 do
		if math.random() < 0.1 then
			table.insert(stuff,"oceantree")
		end
	end

	table.insert(stuff,"oceanvine")
	table.insert(stuff,"oceanvine_deco")


	if math.random()<0.2 then
		table.insert(stuff,"oceanvine")
	end

	for i=1,3 do
		if math.random()<0.3 then
			table.insert(stuff,"watertree_root")
		end
	end	

	for i=1,3 do
		if math.random()<0.3 then
			table.insert(stuff,"oceanvine_deco")
		end
	end				
	--[[
	for i=1,4 do
		if math.random()<0.3 then
			table.insert(stuff,"lightrays_canopy")
		end
	end
]]
	
	for i=1,2 do
		if math.random()<0.3 then
			table.insert(stuff,"oceanvine_cocoon")
		end
	end


	for i=1,10 do
		if math.random()<0.4 then
			table.insert(stuff, "fireflies")
		end
	end

	return stuff
end

local function monkeyisland_prefabs_area(area, data)
    local prefabs = PickSomeWithDups(math.floor(area/5 + 0.5),
        {   "bananabush",
            "monkeytail",
            "palmconetree_short",
            "palmconetree_normal",
            "palmconetree_tall",
            "pirate_flag_pole",
        }
    )

    -- Make sure we have at least 1 of each plant represented.
    table.insert(prefabs, "bananabush")
    table.insert(prefabs, "palmconetree_normal")
    table.insert(prefabs, "monkeytail")

    table.insert(prefabs, "lightcrab")
    if math.random() > 0.5 then
        table.insert(prefabs, "lightcrab")
    end

    return prefabs
end

local function monkeyhut_area()
    return {"monkeyhut", "monkeyhut"}
end

local monkey_island_add_data =
{
	add_topology = {room_id = "StaticLayoutIsland:MonkeyIsland", tags = {"RoadPoison", "nohunt", "nohasslers", "not_mainland"}},
	areas =
	{
		monkeyisland_prefabs = monkeyisland_prefabs_area,
		monkeyhut_area = monkeyhut_area,

		monkeyisland_docksafearea = function(area, data)
			-- Convert the area we're given into a prefab recording that area,
			-- so dock generation can access the area information while generating.
			return {
				{
					prefab = "monkeyisland_dockgen_safeareacenter",
					x = data.x,
					y = data.y,
					properties = {
						data = {
							width = data.width,
							height = data.height,
						},
					},
				}
			}
		end,
	},
}

local monkey_island_retrofit_topology_data = {
	room_id = "StaticLayoutIsland:MonkeyIsland", 
	tags = {"RoadPoison", "nohunt", "nohasslers", "not_mainland"}
}

local StaticLayout = require("map/static_layout")
local ExampleLayout =
	{
		["Farmplot"] =
						{
							-- Choose layout type
							type = LAYOUT.STATIC,

							-- Add any arguments for the layout function
							args = nil,

							-- Define a choice list for substitution below
							defs =
								{
								 	unknown_plant = { "carrot_planted","flower", "grass", "berrybush2" },
								},

							-- Lay the objects in whatever pattern
							layout =
								{
									unknown_plant = {
													 {x=-1,y=-1}, {x=0,y=-1}, {x=1,y=-1},
													 {x=-1, y=0}, {x=0, y=0}, {x=1, y=0},
													 {x=-1, y=1}, {x=0, y=1}, {x=1, y=1}
													},
								},

							-- Either choose to specify the objects positions or a number of objects
							count = nil,

							-- Choose a scale on which to place everything
							scale = 0.3
						},
		["StoneHenge"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							defs =
								{
								 	unknown_plant = { "rock2", "rock1", "evergreen_tall", "evergreen_normal", "evergreen_short", "sapling"},
								},
							count =
								{
									unknown_plant = 9,
								},
							scale = 1.2
						},
		["CropCircle"] =
						{
							type = LAYOUT.CIRCLE_RANDOM,
							defs =
								{
								 	unknown_plant = { "carrot_planted", "grass", "flower", "berrybush2"},
								},
							count =
								{
									unknown_plant = 15,
								},
							scale = 1.5
						},
		["HalloweenPumpkins"] =
						{
							type = LAYOUT.CIRCLE_RANDOM,
							defs =
								{
								 	unknown_plant = { "pumpkin" },
								},
							count =
								{
									unknown_plant = 15,
								},
							scale = 1.5
						},
		["TreeFarm"] =
						{
							type = LAYOUT.GRID,
							count =
								{
									evergreen_short = 16,
								},
							scale = 0.9
						},
		["MushroomRingSmall"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							defs =
								{
								 	unknown_plant = { "red_mushroom", "green_mushroom", "blue_mushroom"},
								},
							count =
								{
									unknown_plant = 7,
								},
							scale = 1
						},
		["MushroomRingMedium"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							defs =
								{
								 	unknown_plant = { "red_mushroom", "green_mushroom", "blue_mushroom"},
								},
							count =
								{
									unknown_plant = 10,
								},
							scale = 1.2
						},
		["MushroomRingLarge"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							defs =
								{
								 	unknown_plant = { "red_mushroom", "green_mushroom", "blue_mushroom"},
								},
							count =
								{
									unknown_plant = 15,
								},
							scale = 1.5
						},
		["SimpleBase"] = StaticLayout.Get("map/static_layouts/simple_base", {
							areas = {
								construction_area = function() return PickSome(2, { "birdcage", "cookpot", "firepit", "homesign", "beebox", "meatrack", "icebox", "tent" }) end,
							},
						}),
		["RuinedBase"] = StaticLayout.Get("map/static_layouts/ruined_base", {
							areas = {
								construction_area = function() return PickSome(2, { "birdcage", "cookpot", "firepit", "homesign", "beebox", "meatrack", "icebox", "tent" }) end,
							},
						}),

		["ResurrectionStone"] = StaticLayout.Get("map/static_layouts/resurrectionstone"),
		["ResurrectionStoneLit"] = StaticLayout.Get("map/static_layouts/resurrectionstonelit"),
		["ResurrectionStoneWinter"] = StaticLayout.Get("map/static_layouts/resurrectionstone_winter", {
				areas = {
					item_area = function() return nil end,
					resource_area = function()
							local choices = {{"cutgrass","cutgrass","twigs", "twigs"}, {"cutgrass","cutgrass","cutgrass","log", "log"}}
							return choices[math.random(1,#choices)]
						end,
					},
			}),

		["LivingTree"] = StaticLayout.Get("map/static_layouts/livingtree", {}),

		["HalloweenPumpkinCarving"] = StaticLayout.Get("map/static_layouts/pumpkin_carving", {
			areas = {
				pumpkincarver = function() return { "pumpkincarver"..math.random(NUM_HALLOWEEN_PUMPKINCARVERS) } end,
			},
		}),


--------------------------------------------------------------------------------
-- MacTusk
--------------------------------------------------------------------------------
		["MacTuskTown"] = StaticLayout.Get("map/static_layouts/mactusk_village"),
		["MacTuskCity"] = StaticLayout.Get("map/static_layouts/mactusk_city", {
							start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER
						}),

--------------------------------------------------------------------------------
-- Pigs
--------------------------------------------------------------------------------
		["MaxMermShrine"] = StaticLayout.Get("map/static_layouts/maxwell_merm_shrine"),

		["MaxPigShrine"] = StaticLayout.Get("map/static_layouts/maxwell_pig_shrine"),
		["VillageSquare"] =
						{
							type = LAYOUT.RECTANGLE_EDGE,
							count =
								{
									pighouse = 8,
								},
							scale = 0.5
						},
		["PigTown"] = StaticLayout.Get("map/static_layouts/pigtown"),
		["InsanePighouse"] = StaticLayout.Get("map/static_layouts/insane_pig"),
		["DefaultPigking"] = StaticLayout.Get("map/static_layouts/default_pigking", {
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER
        }),
		["TorchPigking"] = StaticLayout.Get("map/static_layouts/torch_pigking"),
		["FisherPig"] =
						{
							type = LAYOUT.STATIC,
							defs =
								{
								 	unknown_hanging = { "drumstick", "smallmeat", "monstermeat", "meat"},
								 	unknown_fruit = { "pumpkin", "eggplant", "durian", "pomegranate", "dragonfruit"},
								},
							ground_types = {WORLD_TILES.IMPASSABLE, WORLD_TILES.WOODFLOOR},
							ground =
								{
									{0, 0, 1, 1, 1, 1, 1, 0},
									{0, 1, 1, 1, 1, 1, 1, 1},
									{0, 1, 1, 1, 1, 1, 1, 1},
									{0, 1, 1, 2, 2, 2, 1, 1},
									{0, 1, 1, 2, 2, 2, 1, 1},
									{0, 1, 1, 2, 2, 2, 1, 1},
									{0, 1, 1, 1, 2, 1, 1, 1},
									{0, 0, 1, 1, 2, 1, 1, 0},
								},
							layout =
								{
									unknown_fruit = 	{ {x=-0.3, y=   0} },
									pighouse = 			{ {x=   0, y=   0} },
									unknown_hanging =  	{ {x= 0.8, y=-0.5} },
									firepit =  			{ {x=   1, y=   1} },
									wall_wood = {
													 {x=-1.5,y=1.5},{x=-1.25,y=1.5}, {x=-1,y=1.5}, {x=-0.75,y=1.5},       {x=0.75,y=1.5}, {x=1,y=1.5}, {x=1.25,y=1.5}, {x=1.5,y=1.5},
																		 		  {x=-0.5,y=1.75}, {x=0.5,y=1.75},
																		 		  {x=-0.5,y=   2}, {x=0.5,y=   2},
																		 		  {x=-0.5,y=2.25}, {x=0.5,y=2.25},
																		 		  {x=-0.5,y= 2.5}, {x=0.5,y= 2.5},
																		 		  {x=-0.5,y=2.75}, {x=0.5,y=2.75},
																		 		  {x=-0.5,y=   3}, {x=0.5,y=   3},
																		 		  {x=-0.5,y=3.25}, {x=0.5,y=3.25},
																		 		  {x=-0.5,y= 3.5}, {x=0.5,y= 3.5},
												},
								},
							scale = 1 -- scale must be 1 if we set grount tiles
						},
		["SwampPig"] =
						{
							type = LAYOUT.STATIC,
							defs =
								{
								 	unknown_bird = { "crow", "robin"},
								 	unknown_fruit = { "pumpkin", "eggplant", "durian", "pomegranate", "dragonfruit"},
								 	unknown_plant = { "carrot_planted","flower", "grass"},
								},
							layout =
								{
									unknown_plant = {
													 {x=-1,y=-1}, {x=0,y=-1}, {x=1,y=-1},
													 {x=-1,y= 0}, {x=0,y= 0}, {x=1,y= 0},
													 {x=-1,y= 1}, {x=0,y= 1}, {x=1,y= 1}
													},
								},
							scale = 0.3
						},

--------------------------------------------------------------------------------
-- Start Nodes
--------------------------------------------------------------------------------
		["DefaultStart"] = StaticLayout.Get("map/static_layouts/default_start", {
            start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
            fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
            layout_position = LAYOUT_POSITION.CENTER,

			defs={
				welcomitem = IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) and {"pumpkin_lantern"} or {"flower"},
			},

        }),
		["CaveStart"] = StaticLayout.Get("map/static_layouts/cave_start", {
            start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
            fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
            layout_position = LAYOUT_POSITION.CENTER,
        }),
		["RuinsStart"] = StaticLayout.Get("map/static_layouts/ruins_start"),
		["RuinsStart2"] = StaticLayout.Get("map/static_layouts/ruins_start2"),
		["CaveTestStart"] = StaticLayout.Get("map/static_layouts/cave_test_start"),
		["DefaultPlusStart"] = StaticLayout.Get("map/static_layouts/default_plus_start"),
		["NightmareStart"] = StaticLayout.Get("map/static_layouts/nightmare"),
		["BargainStart"] = StaticLayout.Get("map/static_layouts/bargain_start"),
		["ThisMeansWarStart"] = StaticLayout.Get("map/static_layouts/thismeanswar_start"),
		["WinterStartEasy"] = StaticLayout.Get("map/static_layouts/winter_start_easy"),
		["WinterStartMedium"] = StaticLayout.Get("map/static_layouts/winter_start_medium"),
		["WinterStartHard"] = StaticLayout.Get("map/static_layouts/winter_start_hard"),
		["PreSummerStart"] = StaticLayout.Get("map/static_layouts/presummer_start"),
		["DarknessStart"] =StaticLayout.Get("map/static_layouts/total_darkness_start"),

--------------------------------------------------------------------------------
-- Chess bits
--------------------------------------------------------------------------------

		["ChessSpot1"] = StaticLayout.Get("map/static_layouts/chess_spot", {
								defs={
									evil_thing={"marblepillar","flower_evil","marbletree"},
								},
							}),
		["ChessSpot2"] = StaticLayout.Get("map/static_layouts/chess_spot2", {
								defs={
									evil_thing={"marblepillar","flower_evil","marbletree"},
								},
							}),
		["ChessSpot3"] = StaticLayout.Get("map/static_layouts/chess_spot3", {
								defs={
									evil_thing={"marblepillar","flower_evil","marbletree"},
								},
							}),
		["Maxwell1"] = StaticLayout.Get("map/static_layouts/maxwell_1"),
		["Maxwell2"] = StaticLayout.Get("map/static_layouts/maxwell_2"),
		["Maxwell3"] = StaticLayout.Get("map/static_layouts/maxwell_3"),
		["Maxwell4"] = StaticLayout.Get("map/static_layouts/maxwell_4"),
		["Maxwell5"] = StaticLayout.Get("map/static_layouts/maxwell_5"),
		["Maxwell6"] = StaticLayout.Get("map/static_layouts/maxwell_6"),
		["Maxwell7"] = StaticLayout.Get("map/static_layouts/maxwell_7"),

----------------------------------------------------------------------------------
-- Charlie's work
----------------------------------------------------------------------------------
		["Charlie1"] = StaticLayout.Get("map/static_layouts/charlie_1"),
		["Charlie2"] = StaticLayout.Get("map/static_layouts/charlie_2"),

----------------------------------------------------------------------------------
-- Balatro
----------------------------------------------------------------------------------
		["Balatro"] = StaticLayout.Get("map/static_layouts/balatro", {
	        areas = {
	            balatro_card_area = function(area) return PickSomeWithDups(math.random(2,4), {"playing_card"}) end,
	        },
		}),

--------------------------------------------------------------------------------
-- Blockers
--------------------------------------------------------------------------------
		["TreeBlocker"] =
						{
							type = LAYOUT.CIRCLE_RANDOM,
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							ground_types = {WORLD_TILES.FOREST},
							ground =
								{
									{1,1},{1,1},
									--{0, 0, 1, 1, 0, 0},
									--{0, 1, 1, 1, 1, 0},
									--{1, 1, 1, 1, 1, 1},
									--{1, 1, 1, 1, 1, 1},
									--{0, 1, 1, 1, 1, 0},
									--{0, 0, 1, 1, 0, 0},
								},
							defs =
								{
								 	trees = { "evergreen_short", "evergreen_normal", "evergreen_tall"},
								},
							count =
								{
									trees = 185,
								},
							scale = 0.9,
						},
		["RockBlocker"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							ground_types = {WORLD_TILES.ROCKY},
							defs =
								{
								 	rocks = { "rock1", "rock2"},
								},
							count =
								{
									rocks = 35,
								},
							scale = 1.9,
						},
		["InsanityBlocker"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							ground_types = {WORLD_TILES.ROCKY},
							defs =
								{
								 	rocks = { "insanityrock"},
								},
							count =
								{
									rocks = 55,
								},
							scale = 4.0,
						},
		["SanityBlocker"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							ground_types = {WORLD_TILES.ROCKY},
							defs =
								{
								 	rocks = { "sanityrock"},
								},
							count =
								{
									rocks = 55,
								},
							scale = 4.0,
						},
		["InsaneFlint"] = StaticLayout.Get("map/static_layouts/insane_flint"),
		["PigGuardsEasy"] = StaticLayout.Get("map/static_layouts/pigguards_easy", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER
						}),
		["PigGuards"] = StaticLayout.Get("map/static_layouts/pigguards", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER
						}),
		["PigGuardsB"] = StaticLayout.Get("map/static_layouts/pigguards_b", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER
						}),
		["TallbirdBlockerSmall"] = StaticLayout.Get("map/static_layouts/tallbird_blocker_small", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["TallbirdBlocker"] = StaticLayout.Get("map/static_layouts/tallbird_blocker", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["TallbirdBlockerB"] = StaticLayout.Get("map/static_layouts/tallbird_blocker_b", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["TentacleBlockerSmall"] = StaticLayout.Get("map/static_layouts/tentacles_blocker_small", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["TentacleBlocker"] = StaticLayout.Get("map/static_layouts/tentacles_blocker", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["SpiderBlockerEasy"] = StaticLayout.Get("map/static_layouts/spider_blocker_easy", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["SpiderBlockerEasyB"] = StaticLayout.Get("map/static_layouts/spider_blocker_easy_b", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["SpiderBlocker"] = StaticLayout.Get("map/static_layouts/spider_blocker", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["SpiderBlockerB"] = StaticLayout.Get("map/static_layouts/spider_blocker_b", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["SpiderBlockerC"] = StaticLayout.Get("map/static_layouts/spider_blocker_c", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["ChessBlocker"] = StaticLayout.Get("map/static_layouts/chess_blocker", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["ChessBlockerB"] = StaticLayout.Get("map/static_layouts/chess_blocker_b", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							areas={
								flower_area = ExtendedArray({}, "flower_evil", 15),
							},
						}),
		["ChessBlockerC"] = StaticLayout.Get("map/static_layouts/chess_blocker_c", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),
		["MaxwellHome"] = StaticLayout.Get("map/static_layouts/maxwellhome", {
							areas =
							{
								barren_area = function(area) return PickSomeWithDups( 0.5 * area
									, {"marsh_tree", "marsh_bush", "rock1", "rock2", "evergreen_burnt", "evergreen_stump"}) end,
								gold_area = function() return PickSomeWithDups(math.random(15,20), {"goldnugget"}) end,
								livinglog_area = function() return PickSomeWithDups(math.random(5, 10), {"livinglog"}) end,
								nightmarefuel_area = function() return PickSomeWithDups(math.random(5, 10), {"nightmarefuel"}) end,
								deadlyfeast_area = function() return PickSomeWithDups(math.random(25,30), {"monstermeat", "green_cap", "red_cap", "spoiled_food", "meat"}) end,
								marblegarden_area = function(area) return PickSomeWithDups(1.5*area, {"marbletree", "flower_evil"}) end,
							},
							start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							disable_transform = true
						}),

		["PermaWinterNight"] = StaticLayout.Get("map/static_layouts/nightmare_begin_blocker", {
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
						}),

--------------------------------------------------------------------------------
-- Wormhole
--------------------------------------------------------------------------------
		-- "Generic" wormholes
		["WormholeGrass"] = StaticLayout.Get("map/static_layouts/wormhole_grass"),

		-- "Fancy" wormholes
		["InsaneEnclosedWormhole"] = StaticLayout.Get("map/static_layouts/insane_wormhole"),
		["InsaneWormhole"] = StaticLayout.Get("map/static_layouts/insanity_wormhole_1"),
		["SaneWormhole"] = StaticLayout.Get("map/static_layouts/sanity_wormhole_1"),
		["SaneWormholeOneShot"] = StaticLayout.Get("map/static_layouts/sanity_wormhole_oneshot"),
		["WormholeOneShot"] = StaticLayout.Get("map/static_layouts/wormhole_oneshot", {
			areas= {
				bones_area = {"houndbone"},
			},
		}),
        ["TentaclePillar"] = StaticLayout.Get("map/static_layouts/tentacle_pillar"),
		["TentaclePillarToAtrium"] = StaticLayout.Get("map/static_layouts/tentacle_pillar_atrium", { disable_transform = true }),
		["TentaclePillarToAtriumOuter"] = StaticLayout.Get("map/static_layouts/tentacle_pillar_atrium_outer"),

--------------------------------------------------------------------------------
-- Eyebone
--------------------------------------------------------------------------------
		["InsaneEyebone"] = StaticLayout.Get("map/static_layouts/insane_eyebone"),

--------------------------------------------------------------------------------
-- TELEPORTATO
--------------------------------------------------------------------------------
		["TeleportatoBoxLayout"] = StaticLayout.Get("map/static_layouts/teleportato_box_layout"),
		["TeleportatoRingLayout"] =
						{
							type = LAYOUT.CIRCLE_EDGE,
							start_mask = PLACE_MASK.NORMAL,
							fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
							layout_position = LAYOUT_POSITION.CENTER,
							ground_types = {WORLD_TILES.GRASS},
							ground = {
									{0, 1, 1, 1, 0},
									{1, 1, 1, 1, 1},
									{1, 1, 1, 1, 1},
									{1, 1, 1, 1, 1},
									{0, 1, 1, 1, 0},
								},
							count = {
									flower_evil = 15,
								},
							layout = {
									teleportato_ring = { {x=0,y=0} },
								},

							scale = 1,
						},
		["TeleportatoPotatoLayout"] = StaticLayout.Get("map/static_layouts/teleportato_potato_layout"),
		["TeleportatoCrankLayout"] = StaticLayout.Get("map/static_layouts/teleportato_crank_layout"),
		["TeleportatoBaseLayout"] = StaticLayout.Get("map/static_layouts/teleportato_base_layout"),
		["TeleportatoBaseAdventureLayout"] = StaticLayout.Get("map/static_layouts/teleportato_base_layout_adv"),
		["AdventurePortalLayout"] = StaticLayout.Get("map/static_layouts/adventure_portal_layout"),

--------------------------------------------------------------------------------
-- MAX PUZZLE
--------------------------------------------------------------------------------
		--["SymmetryTest"] = StaticLayout.Get("map/static_layouts/symmetry_test"),
		--["SymmetryTest2"] = StaticLayout.Get("map/static_layouts/symmetry_test2"),
		["test"] = StaticLayout.Get("map/static_layouts/test", {
			areas = {
				area_1 = {"rocks","log"},
				area_2 = {"grass","berrybush"},
			},
		}),
		["MaxPuzzle1"] = StaticLayout.Get("map/static_layouts/MAX_puzzle1"),
		["MaxPuzzle2"] = StaticLayout.Get("map/static_layouts/MAX_puzzle2"),
		["MaxPuzzle3"] = StaticLayout.Get("map/static_layouts/MAX_puzzle3"),



--------------------------------------------------------------------------------
-- CAVES
--------------------------------------------------------------------------------

    ["CaveEntrance"] = StaticLayout.Get("map/static_layouts/cave_entrance"),
    ["CaveExit"] = StaticLayout.Get("map/static_layouts/cave_exit", {
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        layout_position = LAYOUT_POSITION.CENTER,
    }),
	["CaveBase"] = StaticLayout.Get("map/static_layouts/cave_base_1"),
	["MushBase"] = StaticLayout.Get("map/static_layouts/cave_base_2"),
	["SinkBase"] = StaticLayout.Get("map/static_layouts/cave_base_3"),
	["RabbitTown"] = StaticLayout.Get("map/static_layouts/rabbittown"),
	["RabbitHermit"] = StaticLayout.Get("map/static_layouts/rabbithermit"),
	["CaveArtTest"] = StaticLayout.Get("map/static_layouts/cave_art_test_start"),
	["Mudlights"] = StaticLayout.Get("map/static_layouts/mudlights"),
    ["RabbitCity"] = StaticLayout.Get("map/static_layouts/rabbitcity"),
    ["TorchRabbitking"] = StaticLayout.Get("map/static_layouts/torch_rabbit_cave"),
    ["EvergreenSinkhole"] = StaticLayout.Get("map/static_layouts/evergreensinkhole", {
        areas = {
            lights = {"cavelight", "cavelight"},
            innertrees = function(area) return PickSomeWithDups(area*.5, {"evergreen"}) end,
            outertrees = function(area) return PickSomeWithDups(area*.2, {"evergreen", "sapling"}) end,
        },
    }),
    ["GrassySinkhole"] = StaticLayout.Get("map/static_layouts/grasssinkhole", {
        areas = {
            lights = {"cavelight", "cavelight"},
            grassarea = function(area) return PickSomeWithDups(area*.4, {"grass"}) end,
        },
    }),
    ["PondSinkhole"] = StaticLayout.Get("map/static_layouts/pondsinkhole", {
        areas = {
            lights = {"cavelight", "cavelight"},
            pondarea = { "pond", "grass", "grass", "berrybush", "sapling", "sapling" },
        },
    }),
    ["SlurtleEnclave"] =
    {
        type = LAYOUT.CIRCLE_EDGE,
        ground_types = {WORLD_TILES.CAVE},
        ground =
        {
            {0, 0, 1, 1, 1, 1, 1, 0},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 1, 1, 1, 1, 1, 1},
            {0, 0, 1, 1, 1, 1, 1, 0},
        },
        defs =
        {
            hole = { "slurtlehole" },
        },
        count =
        {
            hole = 5,
        },
        scale = 1.9,
    },
	["ToadstoolArena"] = StaticLayout.Get("map/static_layouts/toadstool_arena", {
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		layout_position = LAYOUT_POSITION.CENTER,
		disable_transform = true
    }),
    ["skeleton_notplayer"] = StaticLayout.Get("map/static_layouts/skeleton_notplayer" ),

--------------------------------------------------------------------------------
-- RUINS
--------------------------------------------------------------------------------


	["WalledGarden"] = StaticLayout.Get("map/static_layouts/walledgarden",
		{
			areas =
			{
				plants = function(area) return PickSomeWithDups(0.3 * area, {"cave_fern", "lichen", "flower_cave", "flower_cave_double", "flower_cave_triple"}) end,
			},
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER
		}),
	["MilitaryEntrance"] = StaticLayout.Get("map/static_layouts/military_entrance", {
			areas =
			{
				cave_hole_area = function(area) return {"cave_hole"} end,
			},
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),

	--SACRED GROUNDS

	["AltarRoom"] = StaticLayout.Get("map/static_layouts/altar",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),
	["SacredBarracks"] = StaticLayout.Get("map/static_layouts/sacred_barracks",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),
	["Barracks"] = StaticLayout.Get("map/static_layouts/barracks",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),
	["Barracks2"] = StaticLayout.Get("map/static_layouts/barracks_two",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),
	["Spiral"] = StaticLayout.Get("map/static_layouts/spiral",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER,
            areas={
                relics = function() return PickSomeWithDups(15, {"ruins_plate", "ruins_bowl", "ruins_chair", "ruins_chipbowl", "ruins_vase", "ruins_table", "ruins_rubble_table", "ruins_rubble_chair", "ruins_rubble_vase", "thulecite_pieces", "rocks"}) end
            },
            }),
	["BrokenAltar"] = StaticLayout.Get("map/static_layouts/brokenaltar",{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER}),

	--

	["CornerWall"] = StaticLayout.Get("map/static_layouts/walls_corner"),
	["StraightWall"] = StaticLayout.Get("map/static_layouts/walls_straight"),

	["CornerWall2"] = StaticLayout.Get("map/static_layouts/walls_corner2"),
	["StraightWall2"] = StaticLayout.Get("map/static_layouts/walls_straight2"),

	["RuinsCamp"] = StaticLayout.Get("map/static_layouts/ruins_camp"),

	["DeciduousPond"] = StaticLayout.Get("map/static_layouts/deciduous_pond", {disable_transform = true}),

	["Chessy_1"] = StaticLayout.Get("map/static_layouts/chessy_1"),
	["Chessy_2"] = StaticLayout.Get("map/static_layouts/chessy_2"),
	["Chessy_3"] = StaticLayout.Get("map/static_layouts/chessy_3"),
	["Chessy_4"] = StaticLayout.Get("map/static_layouts/chessy_4"),
	["Chessy_5"] = StaticLayout.Get("map/static_layouts/chessy_5"),
	["Chessy_6"] = StaticLayout.Get("map/static_layouts/chessy_6"),

	["Warzone_1"] = StaticLayout.Get("map/static_layouts/warzone_1"),
	["Warzone_2"] = StaticLayout.Get("map/static_layouts/warzone_2"),
	["Warzone_3"] = StaticLayout.Get("map/static_layouts/warzone_3"),

	--#DELETEME
	["CentipedeNest"] =
	{
		type = LAYOUT.STATIC,
		layout =
		{
			shadowthrall_centipede_spawner = {{x=2, y=0}},
		},
		ground_types = {WORLD_TILES.VENT, WORLD_TILES.MUD},
		ground =
		{
			{1, 2, 1, 2, 1, 1},
			{1, 1, 1, 2, 1, 2},
			{1, 1, 1, 1, 2, 2},
			{2, 1, 2, 1, 1, 1},
			{1, 1, 1, 1, 2, 2},
			{1, 1, 2, 2, 1, 1},
		},
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		layout_position = LAYOUT_POSITION.CENTER,
		force_rotation = LAYOUT_ROTATION.SOUTH, -- Tiled layouts are flipped vertically.
	},

--------------------------------------------------------------------------------
-- DST
--------------------------------------------------------------------------------

	["MooseNest"] = StaticLayout.Get("map/static_layouts/moose_nest",
	{
		areas =
		{
			randomtree = function(area) return PickSomeWithDups(1, {"evergreen", "deciduoustree"}) end,
		},
	}),

	["DragonflyArena"] = StaticLayout.Get("map/static_layouts/dragonfly_arena",
	{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER,
	}),

	["BlueMushyStart"] = StaticLayout.Get("map.static_layouts/blue_mushy_entrance"),

	["AntlionSpawningGround"] =
	{
		type = LAYOUT.STATIC,
		layout =
		{
			antlion_spawner = {{x=0, y=0}},
		},
		ground_types = {WORLD_TILES.DESERT_DIRT, WORLD_TILES.DIRT},
		ground =
			{
				{1, 2, 1, 2},
				{1, 1, 1, 2},
				{1, 1, 1, 1},
				{2, 1, 2, 1},
			},
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		layout_position = LAYOUT_POSITION.CENTER,
	},

	["Terrarium_Forest_Spiders"] = StaticLayout.Get("map/static_layouts/terrarium_forest_spiders"),
	["Terrarium_Forest_Pigs"] = StaticLayout.Get("map/static_layouts/terrarium_forest_pigs"),
	["Terrarium_Forest_Fire"] = StaticLayout.Get("map/static_layouts/terrarium_forest_fire"),

--------------------------------------------------------------------------------
-- ANR - A New Reign
--------------------------------------------------------------------------------

	["MoonbaseOne"] = StaticLayout.Get("map/static_layouts/moonbaseone",
	{
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER,
			disable_transform = true
	}),

	["StagehandGarden"] = StaticLayout.Get("map/static_layouts/stagehandgarden"),

	["Sculptures_1"] = StaticLayout.Get("map/static_layouts/sculptures_1"),

	["Sculptures_2"] = StaticLayout.Get("map/static_layouts/sculptures_2",
	{
		areas =
		{
			sculpture_random = function(area) return PickSomeWithDups(1, {"statue_marble_muse", "statue_marble_pawn", "sculpture_knight", "sculpture_bishop"}) end,
		},
	}),

	["Sculptures_3"] = StaticLayout.Get("map/static_layouts/sculptures_3"),
	["Sculptures_4"] = StaticLayout.Get("map/static_layouts/sculptures_4"),

	["Sculptures_5"] = StaticLayout.Get("map/static_layouts/sculptures_5",
	{
		areas =
		{
			sculpture_random = function(area) return (math.random(2) == 1) and PickSomeWithDups(1, {"statue_marble", "marblepillar", "sculpture_knight", "sculpture_bishop"}) or {nil} end,
		},
	}),

	["Oasis"] = StaticLayout.Get("map/static_layouts/oasis",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		layout_position = LAYOUT_POSITION.CENTER,
		disable_transform = true
	}),

--------------------------------------------------------------------------------
-- LAVAARENA
--------------------------------------------------------------------------------

	["LavaArenaLayout"] = StaticLayout.Get("map/static_layouts/events/lava_arena",
    {
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        layout_position = LAYOUT_POSITION.CENTER,
		disable_transform = true,
    }),


--------------------------------------------------------------------------------
-- QUAGMIRE
--------------------------------------------------------------------------------

	["Quagmire_Kitchen"] = StaticLayout.Get("map/static_layouts/events/quagmire_kitchen",
    {
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        layout_position = LAYOUT_POSITION.CENTER,
		disable_transform = true,

		areas =
		{
			quagmire_parkspike_row = function(area, data)
				local vert = data.height > data.width
--				local x = vert and (data.x) or (data.x - data.width/2.0)
--				local y = vert and (data.y - data.height/2.0) or (data.y)
				local x = data.x - data.width/2.0
				local y = data.y - data.height/2.0
				local spacing = 0.18
				local num = math.ceil((vert and data.height or data.width) / spacing)

				local prefabs = {}
				for i = 1, num do
					table.insert(prefabs,
					{
						prefab = i % 2 == (vert and 0 or 1) and "quagmire_parkspike_short" or "quagmire_parkspike",
						x = x,
						y = y,
					})
					if vert then
						y = y + spacing
					else
						x = x + spacing
					end
				end
				return prefabs
			end,
		},
    }),


--------------------------------------------------------------------------------
-- METEOR ISLAND
--------------------------------------------------------------------------------

	["moontrees_2"] = StaticLayout.Get("map/static_layouts/moontrees_2", {
		areas =
		{
			tree_area = function() return math.random() < 0.9 and {"moon_tree"} or nil end,
			fissure_area = {"moon_fissure"},
		}
    }),

    ["MoonTreeHiddenAxe"] = StaticLayout.Get("map/static_layouts/moontreehiddenaxe"),

	["MoonAltarRockGlass"] = StaticLayout.Get("map/static_layouts/moonaltarrockglass"),
	["MoonAltarRockIdol"] = StaticLayout.Get("map/static_layouts/moonaltarrockidol"),
	["MoonAltarRockSeed"] = StaticLayout.Get("map/static_layouts/moonaltarrockseed"),

    ["BathbombedHotspring"] = StaticLayout.Get("map/static_layouts/bathbombedhotspring"),

    ["MoonFissures"] = StaticLayout.Get("map/static_layouts/fissures_1"),


--------------------------------------------------------------------------------
-- Ocean
--------------------------------------------------------------------------------
	["AbandonedWarf1"] = StaticLayout.Get("map/static_layouts/abandonedwarf",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
	}),

	["AbandonedWarf2"] = StaticLayout.Get("map/static_layouts/abandonedwarf2",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
	}),

	["AbandonedWarf3"] = StaticLayout.Get("map/static_layouts/abandonedwarf3",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
	}),

	["BullkelpFarmSmall"] = StaticLayout.Get("map/static_layouts/bullkelpfarmsmall", {
		areas =
		{
			kelp_area = function() return math.random() < 0.9 and {"bullkelp_plant"} or nil end,
		}
    }),

	["BullkelpFarmMedium"] = StaticLayout.Get("map/static_layouts/bullkelpfarmmedium", {
		areas =
		{
			kelp_area = function() return math.random() < 0.9 and {"bullkelp_plant"} or nil end,
		}
    }),

	["BrinePool1"] = StaticLayout.Get("map/static_layouts/brinepool1", {
		areas =
		{
			saltstack_area = function() return math.random() < 0.9 and {"saltstack"} or nil end,
		}
    }),

	["BrinePool2"] = StaticLayout.Get("map/static_layouts/brinepool2", {
		areas =
		{
			saltstack_area = function() return math.random() < 0.9 and {"saltstack"} or nil end,
		}
    }),

	["BrinePool3"] = StaticLayout.Get("map/static_layouts/brinepool3", {
		areas =
		{
			saltstack_area = function() return math.random() < 0.9 and {"saltstack"} or nil end,
		}
    }),

	["CrabKing"] = StaticLayout.Get("map/static_layouts/crabking", {
		min_dist_from_land = 0,
		areas =
		{
			stack_area = function() return math.random() < 0.9 and {"seastack"} or nil end,
		}
    }),

	["HermitcrabIsland"] = StaticLayout.Get("map/static_layouts/hermitcrab_01",
	{
		add_topology = {room_id = "StaticLayoutIsland:HermitcrabIsland", tags = {"RoadPoison", "nohunt", "nohasslers", "not_mainland"}},
		min_dist_from_land = 0,
	}),

	["MonkeyIsland"]      = StaticLayout.Get("map/static_layouts/monkeyisland_01", monkey_island_add_data),
	["MonkeyIslandSmall"] = StaticLayout.Get("map/static_layouts/monkeyisland_01_small", monkey_island_add_data),

	["AbandonedBoat1"] = StaticLayout.Get("map/static_layouts/abandonedboat",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		areas = 
		{
			item_area1 = function() return {math.random() >= .5 and "spoiled_fish_small" or "spoiled_fish"} end,
			item_area2 = function() return {math.random() >= .5 and "twigs" or "cutgrass"} end,
			mast_area = {"mast_broken"},
			fishing_item_area = {"chum"},
			seastack_area = function() return math.random() < 0.9 and {"seastack"} or nil end
		},
	}),

	["AbandonedBoat2"] = StaticLayout.Get("map/static_layouts/abandonedboat",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		areas = 
		{
			item_area1 = function() return {math.random() >= .5 and "oar" or "oar_driftwood"} end,
			item_area2 = function() return {math.random() >= .5 and "twigs" or "cutgrass"} end,
			mast_area = {},
			fishing_item_area = function() return {math.random() >= .5 and "oceanfishinglure_hermit_snow" or "oceanfishinglure_hermit_heavy"} end,
			seastack_area = function() return math.random() < 0.9 and {"seastack"} or nil end
		},
	}),

	["OceanMonument"] = StaticLayout.Get("map/static_layouts/oceanmonument",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
	}),

    ["OceanWhirlBigPortal"] = StaticLayout.Get("map/static_layouts/oceanwhirlbigportal",
    {
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
        min_dist_from_land = 5,
        add_topology = {room_id = "StaticLayoutIsland:OceanWhirlBigPortal", tags = {"RoadPoison", "nohunt", "nohasslers", "not_mainland"}},
        areas = {
            mast_area = function()
                local boatgoodies = nil
                if math.random() < 0.75 then
                    local potentialgoodies = {
                        "boards",
                        "twigs",
                        "cutgrass",
                    }
                    boatgoodies = {
                        potentialgoodies[math.random(#potentialgoodies)]
                    }
                    for i = 1, 3 do
                        if math.random() < 0.5 then
                            table.insert(boatgoodies, potentialgoodies[math.random(#potentialgoodies)])
                        end
                    end
                end
                return boatgoodies
            end,
            stack_area = function() return math.random() < 0.30 and {"seastack"} or nil end,
        }
    }),

--------------------------------------------------------------------------------
-- Grotto
--------------------------------------------------------------------------------
    ["GrottoPoolBig"] = StaticLayout.Get("map/static_layouts/grotto_pool_large"),
    ["GrottoPoolSmall"] = StaticLayout.Get("map/static_layouts/grotto_pool_small"),

--------------------------------------------------------------------------------
-- Archive
--------------------------------------------------------------------------------
	["ArchiveDoor"] = StaticLayout.Get("map/static_layouts/archivedoor",{ -- UNUSED
			start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN_RESERVED,
			layout_position = LAYOUT_POSITION.CENTER
    }),

    ["Vault_Lobby"] = StaticLayout.Get("map/static_layouts/vault_lobby", {
        add_topology = {room_id = "Vault:0:Vault_Lobby", tags = {"ForceDisconnected", "RoadPoison", "not_mainland", "nocavein", "noquaker"}},
        SafeFromDisconnect = true,
        force_rotation = LAYOUT_ROTATION.NORTH,
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN,
        layout_position = LAYOUT_POSITION.CENTER,
        areas = {
            archive_sound_area = function()
                if math.random() < 0.5 then
                    return {"archive_ambient_sfx"}
                end
            end,
        },
    }),

    ["Vault_Vault"] = StaticLayout.Get("map/static_layouts/vault_vault", {
        add_topology = {room_id = "Vault:0:Vault_Vault", tags = {"ForceDisconnected", "RoadPoison", "not_mainland", "nocavein", "noquaker"}},
        SafeFromDisconnect = true,
        force_rotation = LAYOUT_ROTATION.NORTH,
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE_BARREN,
        layout_position = LAYOUT_POSITION.CENTER
    }),

--------------------------------------------------------------------------------
-- Return of Them Retrofitting
--------------------------------------------------------------------------------
	["retrofit_moonisland_small"] = StaticLayout.Get("map/static_layouts/retrofit_moonisland_small",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		areas =
		{
			tree_area = function() return math.random() < 0.9 and {"moon_tree"} or nil end,
			fissure_area = {"moon_fissure"},
		},
	}),

	["retrofit_moonisland_medium"] = StaticLayout.Get("map/static_layouts/retrofit_moonisland_medium",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		areas =
		{
			tree_area = function() return math.random() < 0.9 and {"moon_tree"} or nil end,
			fissure_area = {"moon_fissure"},
		},
	}),

	["retrofit_moonisland_large"] = StaticLayout.Get("map/static_layouts/retrofit_moonisland_large",
	{
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		areas =
		{
			tree_area = function() return math.random() < 0.9 and {"moon_tree"} or nil end,
			fissure_area = {"moon_fissure"},
		},
	}),

	["retrofit_brinepool_tiny"] = StaticLayout.Get("map/static_layouts/retrofit_brinepool_tiny", {
		areas =
		{
			saltstack_area = function() return {"saltstack"} end,
		},
    }),

	["retrofit_moonmush"] = StaticLayout.Get("map/static_layouts/retrofit_moonmush", {
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		force_rotation = LAYOUT_ROTATION.NORTH,
		areas =
		{
		},
    }),
    ["retrofit_fumarole"] = StaticLayout.Get("map/static_layouts/retrofit_fumarole", {
        start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        force_rotation = LAYOUT_ROTATION.NORTH,
        areas = {},
    }),

	["Waterlogged1"] = StaticLayout.Get("map/static_layouts/waterlogged1", {
	--	add_topology = {room_id = "StaticLayoutIsland:Waterlogged1", tags = {"Canopy"}},
	--	min_dist_from_land = 0,
		areas =
		{
			treearea = waterlogged_tree_area,
		}
    }),

	["Waterlogged2"] = StaticLayout.Get("map/static_layouts/waterlogged2", {
	--	add_topology = {room_id = "StaticLayoutIsland:Waterlogged2", tags = {"Canopy"}},
	--	min_dist_from_land = 0,
		areas =
		{
			treearea = waterlogged_tree_area,
		}
    }),

	["Waterlogged3"] = StaticLayout.Get("map/static_layouts/waterlogged3", {
	--	add_topology = {room_id = "StaticLayoutIsland:Waterlogged3", tags = {"Canopy"}},
	--	min_dist_from_land = 0,
		areas =
		{
			treearea = waterlogged_tree_area,
		}
    }),

	["Waterlogged4"] = StaticLayout.Get("map/static_layouts/waterlogged4", {
	--	add_topology = {room_id = "StaticLayoutIsland:Waterlogged4", tags = {"Canopy"}},
	--	min_dist_from_land = 0,
		areas =
		{
			treearea = waterlogged_tree_area,
		}
    }),

    ["monkeyisland_retrofitlarge_01"] = StaticLayout.Get("map/static_layouts/monkeyisland_retrofitlarge_01",
	{
		add_topology = monkey_island_retrofit_topology_data,
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        areas =
        {
            monkeyisland_prefabs = monkeyisland_prefabs_area,
            monkeyhut_area = monkeyhut_area,
        },
	}),

    ["monkeyisland_retrofitlarge_02"] = StaticLayout.Get("map/static_layouts/monkeyisland_retrofitlarge_02",
	{
		add_topology = monkey_island_retrofit_topology_data,
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        areas =
        {
            monkeyisland_prefabs = monkeyisland_prefabs_area,
            monkeyhut_area = monkeyhut_area,
        },
	}),

    ["monkeyisland_retrofitsmall_01"] = StaticLayout.Get("map/static_layouts/monkeyisland_retrofitsmall_01",
	{
		add_topology = monkey_island_retrofit_topology_data,
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        areas =
        {
            monkeyisland_prefabs = monkeyisland_prefabs_area,
            monkeyhut_area = monkeyhut_area,
        },
	}),

    ["monkeyisland_retrofitsmall_02"] = StaticLayout.Get("map/static_layouts/monkeyisland_retrofitsmall_02",
	{
		add_topology = monkey_island_retrofit_topology_data,
		start_mask = PLACE_MASK.IGNORE_IMPASSABLE,
		fill_mask = PLACE_MASK.IGNORE_IMPASSABLE,
        areas =
        {
            monkeyisland_prefabs = monkeyisland_prefabs_area,
            monkeyhut_area = monkeyhut_area,
        },
	}),

--------------------------------------------------------------------------------
-- Junk Yard
--------------------------------------------------------------------------------
	["junk_yard"] = StaticLayout.Get("map/static_layouts/junk_yard1", 
	{
		areas =
		{
			wobot_area = { "storage_robot" },
			grass_area = grass_area,
		}
	}),

--------------------------------------------------------------------------------	

}

return {Layouts = ExampleLayout}
