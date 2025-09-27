return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 27,
  height = 27,
  tilewidth = 64,
  tileheight = 64,
  properties = {},
  tilesets = {
    {
      name = "ground",
      firstgid = 1,
      filename = "../../../../tools/tiled/dont_starve/ground.tsx",
      tilewidth = 64,
      tileheight = 64,
      spacing = 0,
      margin = 0,
      image = "../../../../tools/tiled/dont_starve/tiles.png",
      imagewidth = 512,
      imageheight = 512,
      properties = {},
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "BG_TILES",
      x = 0,
      y = 0,
      width = 27,
      height = 27,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0, 0, 0,
        0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0, 0,
        0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0,
        0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0,
        0, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 0,
        18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 18, 18, 17, 17, 46, 46, 46, 46, 46, 17, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 18, 17, 17, 46, 46, 46, 46, 46, 46, 46, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 17, 46, 46, 46, 46, 46, 46, 46, 46, 46, 17, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 45, 45, 45, 46, 46, 46, 45, 45, 45, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 45, 45, 45, 46, 46, 46, 45, 45, 45, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 45, 45, 45, 46, 46, 46, 45, 45, 45, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 17, 18, 18, 18, 18, 18, 18, 18,
        18, 18, 18, 18, 18, 18, 18, 17, 17, 46, 46, 46, 46, 46, 46, 46, 46, 46, 17, 17, 18, 18, 18, 18, 18, 18, 18,
        0, 18, 18, 18, 18, 18, 18, 18, 18, 17, 46, 46, 46, 46, 46, 46, 46, 17, 18, 18, 18, 18, 18, 18, 18, 18, 0,
        0, 18, 18, 18, 18, 18, 18, 18, 18, 17, 17, 46, 46, 46, 46, 46, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 0,
        0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 17, 45, 46, 45, 46, 45, 17, 18, 18, 18, 18, 18, 18, 18, 18, 0, 0,
        0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 17, 45, 46, 45, 46, 45, 17, 18, 18, 18, 18, 18, 18, 18, 0, 0, 0,
        0, 0, 0, 0, 18, 18, 18, 18, 18, 18, 17, 45, 46, 45, 46, 45, 17, 18, 18, 18, 18, 18, 18, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 18, 18, 18, 18, 18, 17, 45, 17, 45, 17, 45, 17, 18, 18, 18, 18, 18, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 18, 18, 18, 18, 17, 45, 17, 45, 17, 45, 17, 18, 18, 18, 18, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 18, 18, 17, 17, 17, 17, 17, 17, 17, 18, 18, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS_DOCKGEN",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "monkeyisland_center",
          shape = "rectangle",
          x = 856,
          y = 837,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_direction",
          shape = "rectangle",
          x = 859,
          y = 976,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 727,
          y = 1430,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 727,
          y = 1367,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 856,
          y = 1366,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 982,
          y = 1365,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 857,
          y = 1431,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 982,
          y = 1428,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 981,
          y = 1492,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 985,
          y = 1556,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 983,
          y = 1619,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 857,
          y = 1492,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 858,
          y = 1554,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 856,
          y = 1618,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 727,
          y = 1495,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 727,
          y = 1560,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 727,
          y = 1620,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 986,
          y = 852,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 986,
          y = 914,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 986,
          y = 977,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1049,
          y = 852,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1050,
          y = 913,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1046,
          y = 975,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1112,
          y = 849,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1111,
          y = 913,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 1110,
          y = 974,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 599,
          y = 852,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 663,
          y = 853,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 726,
          y = 851,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 728,
          y = 914,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 725,
          y = 977,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 665,
          y = 976,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 667,
          y = 919,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 599,
          y = 978,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "dock_tile_registrator",
          shape = "rectangle",
          x = 600,
          y = 915,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.undertile"] = "OCEAN_COASTAL_SHORE"
          }
        },
        {
          name = "",
          type = "monkeyisland_docksafearea",
          shape = "rectangle",
          x = 64,
          y = 64,
          width = 1600,
          height = 1600,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "monkeyisland_portal",
          shape = "rectangle",
          x = 659,
          y = 913,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyqueen",
          shape = "rectangle",
          x = 864,
          y = 688,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeypillar",
          shape = "rectangle",
          x = 752,
          y = 640,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.pillar_id"] = "3"
          }
        },
        {
          name = "",
          type = "monkeypillar",
          shape = "rectangle",
          x = 912,
          y = 576,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.pillar_id"] = "1"
          }
        },
        {
          name = "",
          type = "monkeypillar",
          shape = "rectangle",
          x = 816,
          y = 800,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.pillar_id"] = "2"
          }
        },
        {
          name = "",
          type = "monkeypillar",
          shape = "rectangle",
          x = 976,
          y = 736,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.pillar_id"] = "4"
          }
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 1018,
          y = 1401,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 1018,
          y = 1516,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 1019,
          y = 1595,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 961,
          y = 1640,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 871,
          y = 1658,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 832,
          y = 1594,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 891,
          y = 1551,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 763,
          y = 1553,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 757,
          y = 1657,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 704,
          y = 1499,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 705,
          y = 1426,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 704,
          y = 1384,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "dock_woodposts",
          shape = "rectangle",
          x = 703,
          y = 1640,
          width = 5,
          height = 5,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "boat_pirate",
          shape = "rectangle",
          x = 1117,
          y = 1635,
          width = 19,
          height = 19,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 1120,
          y = 1639,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "boat_pirate",
          shape = "rectangle",
          x = 1116,
          y = 1384,
          width = 19,
          height = 19,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 1119,
          y = 1388,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "boat_pirate",
          shape = "rectangle",
          x = 593,
          y = 1503,
          width = 19,
          height = 19,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 596,
          y = 1507,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 684,
          y = 1258,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 1192,
          y = 1034,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "pirate_flag_pole",
          shape = "rectangle",
          x = 517,
          y = 949,
          width = 11,
          height = 11,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS_MONKEYHUTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "monkeyhut_area",
          shape = "rectangle",
          x = 721,
          y = 1357,
          width = 286,
          height = 164,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyhut_area",
          shape = "rectangle",
          x = 965,
          y = 838,
          width = 240,
          height = 176,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS_ISLANDPLANTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "monkeyisland_prefabs",
          shape = "rectangle",
          x = 585,
          y = 1031,
          width = 559,
          height = 175,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_prefabs",
          shape = "rectangle",
          x = 707,
          y = 1215,
          width = 312,
          height = 124,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_prefabs",
          shape = "rectangle",
          x = 773,
          y = 836,
          width = 180,
          height = 181,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_prefabs",
          shape = "rectangle",
          x = 586,
          y = 712,
          width = 219,
          height = 113,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS_PORTALDEBRIS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 610,
          y = 872,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.debris_id"] = "1"
          }
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 711,
          y = 917,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.debris_id"] = "2"
          }
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 662,
          y = 977,
          width = 19,
          height = 23,
          visible = true,
          properties = {
            ["data.debris_id"] = "3"
          }
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 737,
          y = 848,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 587,
          y = 952,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 1151,
          y = 1107,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 1029,
          y = 1244,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 919,
          y = 1124,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 978,
          y = 986,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 864,
          y = 1447,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 743,
          y = 1066,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 1125,
          y = 841,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 1016,
          y = 645,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 653,
          y = 690,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 725,
          y = 762,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 533,
          y = 828,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "monkeyisland_portal_debris",
          shape = "rectangle",
          x = 652,
          y = 1236,
          width = 19,
          height = 23,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
