local MakeWorldNetwork = require("prefabs/world_network")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/world_network.lua"),
}

local prefabs =
{
    "thunder_close",
    "thunder_far",
    "thunder",
    "lightning",
}

local function custom_postinit(inst)
    inst:AddComponent("weather")
    inst:AddComponent("moonstorms")
    inst:AddComponent("sharkboimanagerhelper")
    inst:AddComponent("wagpunk_floor_helper")
    inst:AddComponent("lunarhailbirdsoundmanager")
end

return MakeWorldNetwork("forest_network", prefabs, assets, custom_postinit)