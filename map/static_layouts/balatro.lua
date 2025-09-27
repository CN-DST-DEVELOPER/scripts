return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 12,
  height = 12,
  tilewidth = 16,
  tileheight = 16,
  properties = {},
  tilesets = {
    {
      name = "tiles",
      firstgid = 1,
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
      width = 12,
      height = 12,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 0, 0, 0, 9, 0, 0, 0, 2, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0
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
          type = "balatro_machine",
          shape = "rectangle",
          x = 96,
          y = 96,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "balatro_card_area",
          shape = "rectangle",
          x = 32,
          y = 32,
          width = 128,
          height = 128,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = 147,
          y = 43,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.pickable.picked"] = "true",
            ["data.pickable.time"] = "4800"
          }
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = 43,
          y = 46,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.pickable.picked"] = "true",
            ["data.pickable.time"] = "4800"
          }
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = 45,
          y = 150,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.pickable.picked"] = "true",
            ["data.pickable.time"] = "4800"
          }
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = 149,
          y = 146,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.pickable.picked"] = "true",
            ["data.pickable.time"] = "4800"
          }
        },
        {
          name = "",
          type = "flower",
          shape = "rectangle",
          x = 58,
          y = 38,
          width = 8,
          height = 8,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "flower",
          shape = "rectangle",
          x = 156,
          y = 123,
          width = 8,
          height = 8,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "flower",
          shape = "rectangle",
          x = 19,
          y = 169,
          width = 8,
          height = 8,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "flower",
          shape = "rectangle",
          x = 141,
          y = 13,
          width = 8,
          height = 8,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
