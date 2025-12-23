local DRIED_DEFS =
{
    {
        name = "petals",
        sanityvalue = TUNING.SANITY_SUPERTINY,
        --
        build = "flower_petals",
    },
    {
        name = "petals_evil",
        sanityvalue = -TUNING.SANITY_TINY,
        --
        bank = "flower_petals_evil",
        build = "flower_petals_evil",
    },
    {
        name = "foliage",
    },
    {
        name = "succulent_picked",
        healthvalue = TUNING.HEALING_MEDSMALL,
    },
    {
        name = "firenettles",
        healthvalue = -TUNING.HEALING_SMALL,
        sanityvalue = -TUNING.SANITY_TINY,
        oneaten = function(inst, eater)
        	if not eater:HasTag("plantkin") then
                eater:AddDebuff("firenettle_toxin", "firenettle_toxin")
        	end
        end,
    },
    {
        name = "tillweed",
		healthvalue = TUNING.HEALING_MEDSMALL,
    },
    {
        name = "moon_tree_blossom",
        sanityvalue = TUNING.SANITY_SMALL,
        --
        bank = "moon_tree_petal",
        build = "moon_tree_petal",
    },
    {
        name = "forgetmelots",
        sanityvalue = TUNING.SANITY_TINY,
    },
}

--[[ Omar: For searching
petals_dried
petals_evil_dried
foliage_dried
succulent_picked_dried
firenettles_dried
tillweed_dried
moon_tree_blossom_dried
forgetmelots_dried
]]
return {
    plants = DRIED_DEFS
}