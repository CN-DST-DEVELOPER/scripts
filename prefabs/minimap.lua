local shader_filename = "shaders/minimap.ksh"
local fs_shader = "shaders/minimapfs.ksh"
local atlas_filename = "minimap/minimap_atlas.tex"
local atlas_info_filename = "minimap/minimap_data.xml"

local GroundTiles = require("worldtiledefs")

local assets =
{
    Asset("ATLAS", atlas_info_filename),
    Asset("IMAGE", atlas_filename),

    Asset("ATLAS", "images/hud.xml"),
    Asset("IMAGE", "images/hud.tex"),

    Asset("ATLAS", "images/hud2.xml"),
    Asset("IMAGE", "images/hud2.tex"),

    Asset("SHADER", shader_filename),
    Asset("SHADER", fs_shader),

    Asset("IMAGE", "images/minimap_paper.tex"),
}

for k, v in pairs(GroundTiles.minimapassets) do
    table.insert(assets, v)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddUITransform()
    inst.entity:AddMiniMap() --c side renderer

    inst:AddTag("minimap")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)

    inst.MiniMap:SetEffects(shader_filename, fs_shader)

    inst.MiniMap:AddAtlas(resolvefilepath(atlas_info_filename))
    for _, atlases in ipairs(ModManager:GetPostInitData("MinimapAtlases")) do
        for _, path in ipairs(atlases) do
            inst.MiniMap:AddAtlas(resolvefilepath(path))
        end
    end

    for i, data in pairs(GroundTiles.minimap) do
        local tile_id, layer_properties = unpack(data)
        inst.MiniMap:AddRenderLayer(
            MapLayerManager:CreateRenderLayer(
                tile_id,
                layer_properties.atlas or resolvefilepath(GroundAtlas(layer_properties.name)),
                layer_properties.texture_name or resolvefilepath(GroundImage(layer_properties.name)),
                resolvefilepath(layer_properties.noise_texture)
            )
        )
    end

    return inst
end

return Prefab("minimap", fn, assets)
