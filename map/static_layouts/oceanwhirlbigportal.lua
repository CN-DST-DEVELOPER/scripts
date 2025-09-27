return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 10,
  height = 10,
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
      width = 10,
      height = 10,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 28, 28, 28, 28, 0, 0, 0,
        0, 0, 28, 28, 28, 28, 28, 28, 0, 0,
        0, 28, 28, 28, 28, 28, 28, 28, 28, 0,
        28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        0, 28, 28, 28, 28, 28, 28, 28, 28, 0,
        0, 0, 28, 28, 28, 28, 28, 28, 0, 0,
        0, 0, 0, 28, 28, 28, 28, 0, 0, 0
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
          type = "oceanwhirlbigportal",
          shape = "rectangle",
          x = 335,
          y = 324,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 141,
          y = 459,
          width = 71,
          height = 100,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 261,
          y = 33,
          width = 158,
          height = 64,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 34,
          y = 233,
          width = 63,
          height = 162,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 387,
          y = 510,
          width = 110,
          height = 53,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 515,
          y = 140,
          width = 45,
          height = 92,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "mast_area",
          shape = "rectangle",
          x = 136,
          y = 77,
          width = 43,
          height = 98,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "mast_area",
          shape = "rectangle",
          x = 561,
          y = 312,
          width = 63,
          height = 104,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
