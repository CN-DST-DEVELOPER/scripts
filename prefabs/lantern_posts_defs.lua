-- Definitions for lantern posts with string lights

--[[
params
name - prefab name, and default for build, bank, etc
build - build name
bank - bank name
partner_count - maximum number of partner light posts
link_length - length (in anim coords) of links
kit_data -
    floater_data
    burnable_data
    deployable_data

]]

local shell_sounds =
{
    place = "hookline_2/characters/hermit/house/lamppost_shells_place",
    broke = "hookline_2/characters/hermit/house/lamppost_shells_break",
}

local light_sounds =
{
    place = "hookline_2/characters/hermit/house/lamppost_lights_place",
    --broke = "hookline_2/characters/hermit/house/lamppost_shells_break",
}

local CORAL_COLOR_VARIATIONS =
{
    { 189/255, 89/255, 80/255 },
    { 96/255, 139/255, 189/255 },
    { 180/255, 157/255, 78/255 },
    { 138/255, 91/255, 160/255 },
    { 102/255, 136/255, 95/255 },
}

local CORAL_COLOR_NO_VARIATION = { 255/255, 255/255, 255/255 }

local function hermit_DisplayNameFn(inst)
	return inst:HasTag("abandoned") and STRINGS.NAMES.HERMITCRAB_LIGHTPOST_ABANDONED or nil
end

local function hermit_GetStatus(inst)
    return inst:HasTag("abandoned") and "ABANDONED" or nil
end

local function hermit_MakeBroken(inst, on_load)
    inst:RemoveNeighbourLights()
	inst:AddTag("abandoned")
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("broken")
	end
	if inst.components.container then
		inst.components.container:DropEverything()
		inst.components.container:Close()
		inst:RemoveComponent("container")
	end
    inst.abandoning_task = nil
end

local VAR_ABANDON_TIME = 30 * FRAMES
local FX_SYNC_TIME = 12 * FRAMES
local function hermit_WithinAreaChanged(inst, iswithin)
    if not iswithin and not inst:HasTag("abandoned") then
        local function hermit_WithinAreaChanged_Delay()
			SpawnPrefab("hermitcrab_fx_med").Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.abandoning_task = inst:DoTaskInTime(FX_SYNC_TIME, hermit_MakeBroken)
		end
		inst.abandoning_task = inst:DoTaskInTime(VAR_ABANDON_TIME * math.random(), hermit_WithinAreaChanged_Delay)
	end
end

local function hermit_EnableColorVariation(inst, enabled) -- Not saved.
    local colors = enabled and CORAL_COLOR_VARIATIONS[inst.colors_id] or CORAL_COLOR_NO_VARIATION
    inst.AnimState:SetSymbolMultColour("coral", colors[1], colors[2], colors[3], 1)
end

local SKIN_NAMES_NO_TINT =
{
    ["hermitcrab_lightpost_yule"] = true,
}
local function hermit_OnHermitLightPostSkinChanged(inst, skin_name)
    inst:EnableColorVariation(not SKIN_NAMES_NO_TINT[skin_name])
end

local hermit_SCRAPBOOK_SYMBOLCOLOURS = {
	{"coral", CORAL_COLOR_VARIATIONS[1][1], CORAL_COLOR_VARIATIONS[1][2], CORAL_COLOR_VARIATIONS[1][3], 1 },
}

local LANTERN_DEFS =
{
    {
        name = "yots_lantern_post",
        assets = { Asset("ANIM", "anim/ui_chest_1x1.zip"),},
        overridelightchainprefabname = "yots_lantern_light_chain", -- for old worlds.
        --
        material = "wood",
        partner_count = 2,
        link_length = 80,
        has_lantern_link = true,
        spawn_with_light_bulb = true,
        kit_data =
        {
            floater_data = {size = "med", scale = 0.77},
            burnable_data = {fuelvalue = TUNING.LARGE_FUEL},
            deployable_data =
            {
            	deploymode = DEPLOYMODE.CUSTOM,
            	custom_candeploy_fn = function(inst, pt, mouseover, deployer)
            		local x, y, z = pt:Get()
            		return TheWorld.Map:CanDeployAtPoint(pt, inst, mouseover) and TheWorld.Map:IsAboveGroundAtPoint(x, y, z, false)
            	end,
            }
        },
    },

    {
        name = "hermitcrab_lightpost",
        assets = { Asset("ANIM", "anim/ui_hermitcrab_1x1.zip"), },
        --
        sounds =
        {
            place = "hookline_2/characters/hermit/house/lamppost_place",
            variation_sounds = {
                [1] = shell_sounds,
                [2] = shell_sounds,
                [3] = shell_sounds,
                [4] = shell_sounds,
                --
                [5] = light_sounds,
                [6] = light_sounds,
            },
        },
        material = "pot",
        partner_count = 2,
        link_length = 75,
        num_variations = 5,
        no_burn = true,
        has_yule_build = true,
        overridenextvariationfn = function(inst, prng)
            local NUM_LIGHTS = 2
            if inst.variation == nil then
                inst.variation = prng:RandInt(inst.num_variations)
                inst.next_light = prng:RandInt(NUM_LIGHTS)
            else
                if inst.variation > 4 then
                    inst.variation = prng:RandInt(4)
                else
                    inst.variation = 4 + inst.next_light
                    inst.next_light = inst.next_light % NUM_LIGHTS + 1
                end
            end
            return inst.variation
        end,
        --
        common_postinit = function(inst)
            inst:AddTag("hermitcrab_lantern_post")
            inst:SetDeploySmartRadius(1) --recipe min_spacing/2
            inst.displaynamefn = hermit_DisplayNameFn
        end,

        master_postinit = function(inst)
            inst.scrapbook_symbolcolours = hermit_SCRAPBOOK_SYMBOLCOLOURS

            inst.components.inspectable.getstatus = hermit_GetStatus

            local colors_id = math.random(#CORAL_COLOR_VARIATIONS)
            local colors = CORAL_COLOR_VARIATIONS[colors_id]

            inst.colors_id = colors_id
            inst.AnimState:SetSymbolMultColour("coral", colors[1], colors[2], colors[3], 1)

            inst.OnHermitLightPostSkinChanged = hermit_OnHermitLightPostSkinChanged
            inst.EnableColorVariation = hermit_EnableColorVariation

            MakeHermitCrabAreaListener(inst, hermit_WithinAreaChanged)
        end,

        OnSave = function(inst, data)
            if inst.colors_id then
                data.colors_id = inst.colors_id
            end

            if inst:HasTag("abandoned") or inst.abandoning_task ~= nil then
		        data.abandoned = true
	        end
        end,

        OnLoad = function(inst, data)
            if data.colors_id then
                inst.colors_id = data.colors_id
                local colors = CORAL_COLOR_VARIATIONS[inst.colors_id]
                inst.AnimState:SetSymbolMultColour("coral", colors[1], colors[2], colors[3], 1)
                hermit_OnHermitLightPostSkinChanged(inst, inst:GetSkinName())
            end

            if data.abandoned then
		        hermit_MakeBroken(inst, true)
	        end
        end,
    },
}

--[[ (Omar)
For searching:
yots_lantern_post
yots_lantern_light_chain
yots_lantern_post_item
yots_lantern_post_item_placer

hermitcrab_lightpost
hermitcrab_lightpost_light_chain
hermitcrab_lightpost_item
hermitcrab_lightpost_item_placer
]]
return {
    lantern_posts = LANTERN_DEFS
}