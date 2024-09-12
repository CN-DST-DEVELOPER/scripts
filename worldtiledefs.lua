require "constants"

local GROUND_PROPERTIES = {}

--depreciated property sets
local assets = {}
function GroundImage(name)
    return "levels/tiles/"..name..".tex"
end

function GroundAtlas(name)
    return "levels/tiles/"..name..".xml"
end
local function AddAssets(assets, layers)
    for i, data in ipairs(layers) do
        local tile_type, properties = unpack(data)
        table.insert(assets, Asset("IMAGE", properties.noise_texture))
        table.insert(assets, Asset("IMAGE", GroundImage(properties.name)))
        table.insert(assets, Asset("FILE", GroundAtlas(properties.name)))
    end
end

local WALL_PROPERTIES =
{
    { GROUND.UNDERGROUND,   { name = "falloff", noise_texture = "images/square.tex" } },
    { GROUND.WALL_MARSH,    { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_marsh_01.tex" } },
    { GROUND.WALL_ROCKY,    { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_rock_01.tex" } },
    { GROUND.WALL_DIRT,     { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_dirt_01.tex" } },

    { GROUND.WALL_CAVE,     { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_cave_01.tex" } },
    { GROUND.WALL_FUNGUS,   { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_fungus_01.tex" } },
    { GROUND.WALL_SINKHOLE, { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_sinkhole_01.tex" } },
    { GROUND.WALL_MUD,      { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_mud_01.tex" } },
    { GROUND.WALL_TOP,      { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/cave_topper.tex" } },
    { GROUND.WALL_WOOD,     { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/cave_topper.tex" } },

    { GROUND.WALL_HUNESTONE_GLOW, { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_cave_01.tex" } },
    { GROUND.WALL_HUNESTONE,    { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_fungus_01.tex" } },
    { GROUND.WALL_STONEEYE_GLOW, { name = "walls",  noise_texture = "images/square.tex" } },--"levels/textures/wall_sinkhole_01.tex" } },
    { GROUND.WALL_STONEEYE,     { name = "walls",   noise_texture = "images/square.tex" } },--"levels/textures/wall_mud_01.tex" } },
}
AddAssets(assets, WALL_PROPERTIES)
local underground_layers =
{
    { GROUND.UNDERGROUND, { name = "falloff", noise_texture = "images/square.tex" } },
}
AddAssets(assets, underground_layers)

local GROUND_PROPERTIES_CACHE
local function CacheAllTileInfo()
    assert(GROUND_PROPERTIES_CACHE == nil, "Tile info already initialized")
    GROUND_PROPERTIES_CACHE = {}
    for i, data in ipairs(GROUND_PROPERTIES) do
        local tile_type, tile_info = unpack(data)
        assert(tile_type ~= nil and type(tile_info) == "table" and next(tile_info) ~= nil, "Invalid tile info")
        if GROUND_PROPERTIES_CACHE[tile_type] ~= nil then
            print("Ignored duplicate tile info: "..tostring(tile_type))
        else
            GROUND_PROPERTIES_CACHE[tile_type] = tile_info
        end
    end
end

--Valid only after tile info has been cached
--See gamelogic.lua GroundTiles.Initialize()
function GetTileInfo(tile)
    return GROUND_PROPERTIES_CACHE[tile]
end

--Legacy, slow table lookup instead of using cached info
function LookupTileInfo(tile)
    for i, data in ipairs(GROUND_PROPERTIES) do
        local tile_type, tile_info = unpack(data)
        if tile == tile_type then
            return tile_info
        end
    end
    return nil
end

function PlayFootstep(inst, volume, ispredicted)
    local sound = inst.SoundEmitter
    if sound ~= nil then
		--override sounds
		if inst:HasTag("gelblobbed") then
			sound:PlaySound("dontstarve/movement/walk_goop", nil, volume or 1, ispredicted)
			return
		end

        local my_x, my_y, my_z = inst.Transform:GetWorldPosition()
        local map = TheWorld.Map
        local my_platform = inst:GetCurrentPlatform()

        local tile = inst.components.locomotor ~= nil and inst.components.locomotor:TempGroundTile() or nil
        local tileinfo = tile ~= nil and GetTileInfo(tile) or nil

        local size_inst = inst
		local isplayer = inst:HasTag("player")
		if isplayer then
            local rider = inst.components.rider or inst.replica.rider
            if rider ~= nil and rider:IsRiding() then
                size_inst = rider:GetMount() or inst
            end
        end

        if my_platform ~= nil then
            sound:PlaySound(
                (   inst.sg ~= nil and inst.sg:HasStateTag("running") and "dontstarve/movement/run_"..my_platform.walksound or "dontstarve/movement/walk_"..my_platform.walksound
                )..
                (   (size_inst:HasTag("smallcreature") and "_small") or
                    (size_inst:HasTag("largecreature") and "_large" or "")
                ),
                nil,
                volume or 1,
                ispredicted
                )
            if my_platform.second_walk_sound then
                sound:PlaySound(
                    (   inst.sg ~= nil and inst.sg:HasStateTag("running") and "dontstarve/movement/run_"..my_platform.second_walk_sound or "dontstarve/movement/walk_"..my_platform.second_walk_sound
                    )..
                    (   (size_inst:HasTag("smallcreature") and "_small") or
                        (size_inst:HasTag("largecreature") and "_large" or "")
                    ),
                    nil,
                    volume or 1,
                    ispredicted
                    )
            end
		else
			local soundpath

			if tileinfo == nil then
				--no temp ground tile from locomotor
				--see if we're walking on web/snow/mud
				tile, tileinfo = inst:GetCurrentTileType()
				if tile and tileinfo then
					local x, y, z = inst.Transform:GetWorldPosition()
					local oncreep = TheWorld.GroundCreep:OnCreep(x, y, z)
					local onsnow = not tileinfo.nogroundoverlays and TheWorld.state.snowlevel > 0.15
					local onmud = not tileinfo.nogroundoverlays and TheWorld.state.wetness > 15

					if isplayer and not oncreep and RoadManager and RoadManager:IsOnRoad(x, 0, z) then
						--this is only for players for the time being because isonroad is suuuuuuuper slow.
						tile = WORLD_TILES.ROAD
						tileinfo = GetTileInfo(WORLD_TILES.ROAD) or tileinfo
					end

					soundpath =
						(oncreep and "dontstarve/movement/run_web") or
						(onsnow and tileinfo.snowsound) or
						(onmud and tileinfo.mudsound) or
						nil
				end
			end

			local sizesuffix =
				(size_inst:HasTag("smallcreature") and "_small") or
				(size_inst:HasTag("largecreature") and "_large") or
				""

			if soundpath then
				--web/snow/mud sounds
				sound:PlaySound(soundpath..sizesuffix, nil, volume or 1, ispredicted)
			elseif tileinfo then
				--run/walk sounds
				soundpath = inst.sg and inst.sg:HasStateTag("running") and tileinfo.runsound or tileinfo.walksound

				--V2C: rope bridge no longer uses the param
				--     leaving this commented here as example for future custom footstep code
				--for rope bridge, we have a parameter as well
				--[[if tile == WORLD_TILES.ROPE_BRIDGE and inst.sg then
					local t = GetTime()
					if (inst.sg.mem._rope_bridge_step_time or 0) < t - 1 then
						inst.sg.mem._rope_bridge_steps = 1 --too long since last step => reset count
					else
						inst.sg.mem._rope_bridge_steps = (inst.sg.mem._rope_bridge_steps or 0) + 1
					end
					inst.sg.mem._rope_bridge_step_time = t
					sound:PlaySoundWithParams(soundpath..sizesuffix, { param00 = math.min(9, inst.sg.mem._rope_bridge_steps - 1) * 0.1 }, volume or 1, ispredicted)
				else]]
					--default behaviour
					sound:PlaySound(soundpath..sizesuffix, nil, volume or 1, ispredicted)
				--end
			end
		end
    end
end

return
{
    --Internal use
    Initialize = CacheAllTileInfo,

    --Public use
    ground = GROUND_PROPERTIES,
    minimap = {},
    turf = {},
    falloff = {},
    creep = {},
    assets = assets,
    minimapassets = {},
    wall = WALL_PROPERTIES,  --depreciated
    underground = underground_layers, --depreciated
}
