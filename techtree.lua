local TechTree = {}

local AVAILABLE_TECH =
{
    "SCIENCE",
    "MAGIC",
    "ANCIENT",
    "CELESTIAL",
	"MOON_ALTAR", -- deprecated, all recipes have been moved into CELESTIAL
    "SHADOW",
    "CARTOGRAPHY",
	"SEAFARING",
    "SCULPTING",
    "ORPHANAGE", --teehee
    "PERDOFFERING",
    "WARGOFFERING",
    "PIGOFFERING",
    "CARRATOFFERING",
    "BEEFOFFERING",
	"CATCOONOFFERING",
    "RABBITOFFERING",
    "DRAGONOFFERING",
	"MADSCIENCE",
	"CARNIVAL_PRIZESHOP",
	"CARNIVAL_HOSTSHOP",
    "FOODPROCESSING",
	"FISHING",
	"WINTERSFEASTCOOKING",
    "HERMITCRABSHOP",
    "RABBITKINGSHOP",
    "TURFCRAFTING",
	"MASHTURFCRAFTING",
    "SPIDERCRAFT",
    "ROBOTMODULECRAFT",
    "BOOKCRAFT",
	"LUNARFORGING",
	"SHADOWFORGING",
    "CARPENTRY",
}

-- NOTES(JBK): These are a cache for a speedup in builder:KnowsRecipe calculations to reduce a spike in garbage collection from string allocations.
local AVAILABLE_TECH_BONUS = {}
local AVAILABLE_TECH_TEMPBONUS = {}
local AVAILABLE_TECH_BONUS_CLASSIFIED = {} -- Needed because these do not use the underscore the others do and we do not want to break mods assuming its pattern.
local AVAILABLE_TECH_TEMPBONUS_CLASSIFIED = {}
local AVAILABLE_TECH_LEVEL_CLASSIFIED = {}
for _, v in pairs(AVAILABLE_TECH) do
    local thelower = v:lower()
    AVAILABLE_TECH_BONUS[v] = thelower .. "_bonus"
    AVAILABLE_TECH_TEMPBONUS[v] = thelower .. "_tempbonus"
    AVAILABLE_TECH_BONUS_CLASSIFIED[v] = thelower .. "bonus"
    AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[v] = thelower .. "tempbonus"
    AVAILABLE_TECH_LEVEL_CLASSIFIED[v] = thelower .. "level"
end

-- only these tech trees can have tech bonuses added to them
local BONUS_TECH =
{
    "SCIENCE",
    "MAGIC",
	"SEAFARING",
    "ANCIENT",
	"MASHTURFCRAFTING",
}

local function Create(t)
    t = t or {}
    for i, v in ipairs(AVAILABLE_TECH) do
        t[v] = t[v] or 0
    end
    return t
end

return
{
    AVAILABLE_TECH = AVAILABLE_TECH,
	BONUS_TECH = BONUS_TECH,
    Create = Create,
    -- Cached values below and are not guaranteed to exist in the future so mods using them beware.
    AVAILABLE_TECH_BONUS = AVAILABLE_TECH_BONUS,
    AVAILABLE_TECH_TEMPBONUS = AVAILABLE_TECH_TEMPBONUS,
    AVAILABLE_TECH_BONUS_CLASSIFIED = AVAILABLE_TECH_BONUS_CLASSIFIED,
    AVAILABLE_TECH_TEMPBONUS_CLASSIFIED = AVAILABLE_TECH_TEMPBONUS_CLASSIFIED,
    AVAILABLE_TECH_LEVEL_CLASSIFIED = AVAILABLE_TECH_LEVEL_CLASSIFIED,
}
