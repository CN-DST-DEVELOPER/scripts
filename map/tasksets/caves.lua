local taskset_data =
{
    name = STRINGS.UI.CUSTOMIZATIONSCREEN.TASKSETNAMES.CAVE_DEFAULT,
    location = "cave",
    tasks={
        "MudWorld",
        "MudCave",
        "MudLights",
        "MudPit",

        "BigBatCave",
        "RockyLand",
        "RedForest",
        "GreenForest",
        "BlueForest",
        "SpillagmiteCaverns",

        "MoonCaveForest",
        "ArchiveMaze",

        "CaveExitTask1",
        "CaveExitTask2",
        "CaveExitTask3",
        "CaveExitTask4",
        "CaveExitTask5",
        "CaveExitTask6",
        "CaveExitTask7",
        "CaveExitTask8",
        "CaveExitTask9",
        "CaveExitTask10",

        "CentipedeCaveTask",

		"ToadStoolTask1",
		"ToadStoolTask2",
		"ToadStoolTask3",

        -- ruins
        "LichenLand",
        "Residential",
        "Military",
        "Sacred",
        "TheLabyrinth",
        "SacredAltar",
        "AtriumMaze",
    },
    numoptionaltasks = 8,
    optionaltasks = {
        "SwampySinkhole",
        "CaveSwamp",
        "UndergroundForest",
        "PleasantSinkhole",
        "FungalNoiseForest",
        "FungalNoiseMeadow",
        "BatCloister",
        "RabbitTown",
        "RabbitCity",
        "SpiderLand",
        "RabbitSpiderWar",

        --ruins
        "MoreAltars",
        "CaveJungle",
        "SacredDanger",
        "MilitaryPits",
        "MuddySacred",
        "Residential2",
        "Residential3",
    },
    valid_start_tasks = {
        "CaveExitTask1",
        "CaveExitTask2",
        "CaveExitTask3",
        "CaveExitTask4",
        "CaveExitTask5",
        "CaveExitTask6",
        "CaveExitTask7",
        "CaveExitTask8",
        "CaveExitTask9",
        "CaveExitTask10",
    },
    required_prefabs = {
        "tentacle_pillar_atrium",
        "tentacle_pillar_atrium",
    },
    set_pieces = { -- if you add or remove tasks, don't forget to update this list!
        ["TentaclePillar"] = { count = 10, tasks= {
            "MudWorld", "MudCave", "MudLights", "MudPit", "BigBatCave", "RockyLand", "RedForest", "GreenForest", "BlueForest", "SpillagmiteCaverns", "SwampySinkhole", "CaveSwamp", "UndergroundForest", "PleasantSinkhole", "FungalNoiseForest", "FungalNoiseMeadow", "BatCloister", "RabbitTown", "RabbitCity", "SpiderLand", "RabbitSpiderWar", "CentipedeCaveTask",
        } },
        ["ResurrectionStone"] = { count = 2, tasks={
            "MudWorld", "MudCave", "MudLights", "MudPit", "BigBatCave", "RockyLand", "RedForest", "GreenForest", "BlueForest", "SpillagmiteCaverns", "SwampySinkhole", "CaveSwamp", "UndergroundForest", "PleasantSinkhole", "FungalNoiseForest", "FungalNoiseMeadow", "BatCloister", "RabbitTown", "RabbitCity", "SpiderLand", "RabbitSpiderWar", "CentipedeCaveTask",
        } },
        ["skeleton_notplayer"] = { count = 1, tasks={
            "MudWorld", "MudCave", "MudLights", "MudPit", "BigBatCave", "RockyLand", "RedForest", "GreenForest", "BlueForest", "SpillagmiteCaverns", "SwampySinkhole", "CaveSwamp", "UndergroundForest", "PleasantSinkhole", "FungalNoiseForest", "FungalNoiseMeadow", "BatCloister", "RabbitTown", "RabbitCity", "SpiderLand", "RabbitSpiderWar", "CentipedeCaveTask",
        } },
        ["TentaclePillarToAtrium"] = { count = 1, tasks={ "BigBatCave", "GreenForest", "CentipedeCaveTask" } }, -- This set piece data connects it to the atrium_start set piece.
    },
}

AddTaskSet("cave_default", taskset_data)
