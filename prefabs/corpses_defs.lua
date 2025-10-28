local easing = require("easing")

--------------------------------------------------------------------------------------------------------

local BUILDS =
{
    deerclops =
    {
        default = "deerclops_build",
        yule = "deerclops_yule",
    },

    warg =
    {
        default = "warg_build",
        gingerbread = "warg_gingerbread_build",
    },

    bearger =
    {
        default = "bearger_build",
        yule = "bearger_yule",
    },

    koalefant =
    {
        default = "koalefant_summer_build",
        winter = "koalefant_winter_build",
    },

    bird =
    {
        default = "crow_build",
        robin = "robin_build",
        robin_winter = "robin_winter_build",
        canary = "canary_build",
        quagmire_pigeon = "quagmire_pigeon_build",
        puffin = "puffin_build", --Puffins have a unique bank too
    },

    buzzard =
    {
        default = "buzzard_build",
    },

    hound =
    {
        default = "hound_ocean",
        icehound = "hound_ice_ocean",
        firehound = "hound_red_ocean",
    },

    penguin =
    {
        default = "penguin_build",
    },

    spider =
    {
        default = "spider_build",
        spider_warrior = "spider_warrior_build",
        spider_hider = "DS_spider_caves",
        spider_spitter = "DS_spider2_caves",
        spider_dropper = "spider_white",
        spider_healer = "spider_wolf_build",
    },

    spiderqueen =
    {
        default = "spider_queen_build",
    },

    spider_water =
    {
        default = "spider_water",
    },

    merm =
    {
        default = "merm_build",
        mermguard = "merm_guard_build",
        mermguard_small = "merm_guard_small_build",
    },

    pig =
    {
        default = "pig_build",
        pigspotted_build = "pigspotted_build",
        pig_guard_build = "pig_guard_build",
        pig_elite = "pig_guard_build",
        werepig = "werepig_build",
    },
}

local BUILDS_TO_NAMES =
{
    bird = {
        crow_build = "crow",
        robin_build = "robin",
        robin_winter_build = "robin_winter",
        canary_build = "canary",
        quagmire_pigeon_build = "quagmire_pigeon",
        puffin_build = "puffin",
    },

    hound =
    {
        hound_ocean = "hound",
        hound_red_ocean = "icehound",
        hound_ice_ocean = "firehound",
    },

    spider =
    {
        spider_build = "spider",
        spider_warrior_build = "spider_warrior",
        ds_spider_caves = "spider_hider",
        ds_spider2_caves = "spider_spitter",
        spider_white = "spider_dropper",
        spider_wolf_build = "spider_healer",
    },

    merm =
    {
        merm_build = "merm",
        merm_guard_build = "mermguard",
        merm_guard_small_build = "merm_guard_small_build",
    },

    warg =
    {
        warg_build = "warg",
        warg_gingerbread_build = "gingerbreadwarg",
    },

    pig =
    {
        pig_build = "pigman",
        pigspotted_build = "pigman",
        pig_guard_build = "pigguard",
        pig_elite = "pigelitefighter",
        werepig_build = "pigman",
    },
}

local BANKS = {
    bird =
    {
        default = "crow",
        puffin = "puffin",
    },
    spider =
    {
        default = "spider",
        spider_hider = "spider_hider",
        spider_spitter = "spider_spitter",
    },
}

local FACES =
{
    FOUR = 1,
    SIX  = 2,
    TWO  = 3,
    EIGHT = 4,
}

--[[
data params

creature - name of the creature (string)
bank - bank file (string)
sg - stategraph name (string)
override_build - an override build to add (string)
firesymbol - symbol for fire to follow (string)
makeburnablefn - burnable func def for corpse (function)
faces - facings to use (enum)
physicsradius - radius for physics object (number)
shadowsize - table of two numbers dictating radius and height of shadow (table)
scale - transform scale to apply to all axis (number)
tag - tag to add (string)
tags - table of tags to add (table)
sanityaura - sanity aura to apply (number)
custom_physicsfn - set custom physics instead of the default for corpse (function)

has_rift_mutation - do we have a mutation from a incursive gestalt? (bool)
rift_mutant_data - data for our incursive gestalt mutation state (table)
    -overridemutantprefab - override the default, "mutatedprefab_gestalt" (string)

has_pre_rift_mutation - do we have a mutation from general lunar energy? (bool)
pre_rift_mutant_data - data for our regular lunar mutation state (table)
    -overridemutantprefab - override the default, "mutatedprefab" (string)

]]

--[[
When creating NEW mutations. Make sure to follow this naming scheme

mutated[prefab] - For pre rift lunar mutations.
mutated[prefab]_gestalt - For Incursive Gestalt mutations.
]]

local CORPSE_DEFS =
{
    { -- For search: deerclopscorpse
        creature = "deerclops",
        bank = "deerclops",
        sg = "SGdeerclops",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = .5,
        shadowsize = {6, 3.5},
        scale = 1.65,
        tags = { "deerclops", "epiccorpse", "largecreaturecorpse" },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutateddeerclops",
        },
    },

    { -- For search: wargcorpse
        creature = "warg",
        bank = "warg",
        sg = "SGwarg",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        physicsradius = 1,
        shadowsize = {2.5, 1.5},
        tags = { "largecreaturecorpse" },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutatedwarg",
            enabled_tuning = "SPAWN_MUTATED_DEERCLOPS",
        },
    },

    { -- For search: beargercorpse
        creature = "bearger",
        bank = "bearger",
        sg = "SGbearger",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 1.5,
        shadowsize = {6, 3.5},
        tags = { "bearger_blocker", "epiccorpse", "largecreaturecorpse" },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutatedbearger",
            enabled_tuning = "SPAWN_MUTATED_BEARGER",
        },
    },

    { -- For search: birdcorpse
        creature = "bird",
        bank = "crow",
        sg = "SGbird",
        assets =
        {
            Asset("ANIM", "anim/bird_transformation.zip"),
        },
        --
        firesymbol = "crow_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        faces = FACES.TWO,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        tags = {"small_corpse", "birdcorpse", "smallcreaturecorpse" },
        shadowsize = {1, .75},
        custom_physicsfn = function(inst)
            inst.entity:AddPhysics()
            inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
            inst.Physics:SetCollisionMask(COLLISION.WORLD)
            inst.Physics:SetMass(1)
            inst.Physics:SetSphere(1)
            inst.Physics:SetFriction(.3)
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = function(inst)
                return (
                    inst.build == "robin" or 
                    inst.build == "robin_winter"
                ) and "bird_mutant_spitter"
                or "bird_mutant"
            end,
            enabled_tuning = "SPAWN_MUTATED_BIRDS",
        },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutatedbird",
            enabled_tuning = "SPAWN_MUTATED_BIRDS_GESTALT",
        },

        prefab_deps =
        {
            "bird_mutant_spitter",
            "bird_mutant",
        },
    },

    { -- For search: buzzardcorpse
        creature = "buzzard",
        bank = "buzzard",
        sg = "SGbuzzard",
        firesymbol = "buzzard_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_MED,
        tags = {"small_corpse"},
        shadowsize = {1.25, .75},
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst.Physics:SetFriction(.5)
            inst.Physics:SetRestitution(0)
            inst:AddTag("blocker")
        end,

        override_immediate_gestalt_mutate_cb = function(inst, gestalt)
            local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager

            if mutatedbirdmanager then
                mutatedbirdmanager:FillMigrationTaskAtInst("mutatedbuzzard_gestalt", inst, 1)
                inst:Remove()
            else
                ReplacePrefab(inst, inst:GetRiftMutantPrefab())
            end

            if gestalt then
                gestalt:Remove()
            end
        end,

        has_rift_mutation = true,
        rift_mutant_data =
        {
            enabled_tuning = "SPAWN_MUTATED_BUZZARDS_GESTALT",
        },
    },

    { -- For search: houndcorpse
        creature = "hound",
        bank = "hound",
        sg = "SGhound",
        faces = FACES.FOUR,
        assets =
        {
            Asset("ANIM", "anim/hound_basic_transformation.zip"),
        },
        --
        firesymbol = "hound_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(30, -70, 0),
        shadowsize = {2.5, 1.5},
        --
        tags = {"small_corpse"},
        sanityaura = -TUNING.SANITYAURA_MED,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,
        onloadpostpass = function(inst, newents, data)
            local warg = inst.components.entitytracker:GetEntity("warg")
	        if warg ~= nil then
	        	warg:RememberFollowerCorpse(inst)
	        end
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            enabled_tuning = "SPAWN_MUTATED_HOUNDS",
        },
    },

    { -- For search: penguincorpse
        creature = "penguin",
        bank = "penguin",
        sg = "SGpenguin",
        faces = FACES.FOUR,
        assets =
        {
            Asset("ANIM", "anim/penguin_transformation.zip"),
        },
        --
        tags = { "small_corpse", "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = "mutated_penguin",
            enabled_tuning = "SPAWN_MOON_PENGULLS",
        },
    },

    { -- For search: spidercorpse
        creature = "spider",
        bank = "spider",
        sg = "SGspider",
        override_build = "ds_spider_basic_transformation",
        faces = FACES.FOUR,
        --
        tags = { "small_corpse", "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        shadowsize = {1.5, .5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = "spider_moon",
            enabled_tuning = "MOONSPIDERDEN_ENABLED",
        },
    },

    { -- For search: spider_watercorpse
        creature = "spider_water",
        bank = "spider_water",
        sg = "SGspider_water",
        override_build = "ds_spider_basic_transformation",
        faces = FACES.FOUR,
        --
        tags = { "small_corpse", "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -50, 0),
        shadowsize = {1.5, .5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = "spider_moon",
            enabled_tuning = "MOONSPIDERDEN_ENABLED",
        },
    },

    { -- For search: mermcorpse
        creature = "merm",
        bank = "pigman",
        sg = "SGmerm",
        faces = FACES.FOUR,
        assets =
        {
            Asset("ANIM", "anim/merm_transformation.zip"),
        },
        --
        tags = { "small_corpse", "wet" },
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -100, 0), -- x and y are flipped here because of the symbol rotation. so this -100 is on x in-game actually!
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = function(inst)
                return (
                    inst.build == "mermguard" or
                    inst.build == "mermguard_small"
                ) and "mermguard_lunar"
                or "merm_lunar"
            end,
            enabled_tuning = "SPAWN_MUTATED_MERMS",
        },

        prefab_deps =
        {
            "mermguard_lunar",
            "merm_lunar",
        },
    },

    { -- For search: spiderqueencorpse
        creature = "spiderqueen",
        bank = "spider_queen",
        sg = "SGspiderqueen",
        faces = FACES.FOUR,
        --
        firesymbol = "body",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {7, 3},
        tags = { "largecreaturecorpse", "epiccorpse" },
        --
        sanityaura = -TUNING.SANITYAURA_HUGE,
        physicsradius = 1,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = "moonspiderden",
            enabled_tuning = "SPAWN_MUTATED_SPIDERQUEEN",
        },
    },

    -- TODO NOTE(Omar): HALLOWED_NIGHTS_2025_CORPSES
    --[[
    { -- For search: pigcorpse
        creature = "pig",
        bank = "pigman",
        sg = "SGpig",
        faces = FACES.FOUR,
        --
        tags = {"small_corpse"},
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -100, 0), -- x and y are flipped here because of the symbol rotation. so this -100 is on x in-game actually!
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,
    },
    ]]

    --[[
    { -- For search: playercorpse
        creature = "player",
        bank = "wilson",
        sg = "SGwilson",
        faces = FACES.FOUR,
        --
        tags = {"small_corpse"},
        firesymbol = "torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.3, .6},
        --
        sanityaura = -TUNING.SANITYAURA_HUGE,
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
        end,
    },
    ]]
}

local CORPSE_PROP_DEFS =
{
    { -- For search: koalefantcorpse_prop
        creature = "koalefant",
        bank = "koalefant",
        nameoverride = "koalefant_carcass",
        displaynameoverride = "koalefant_summer",
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        shadowsize = {4.5, 2},
        onrevealfn = function(inst, revealer)
            inst.persists = false
            inst:AddTag("NOCLICK")
            inst:ListenForEvent("animover", inst.Remove)
            inst.AnimState:PlayAnimation("carcass_fake")
        end,
    }
}

return {
    CORPSE_DEFS = CORPSE_DEFS,
    CORPSE_PROP_DEFS = CORPSE_PROP_DEFS,

    BUILDS = BUILDS,
    BUILDS_TO_NAMES = BUILDS_TO_NAMES,
    BANKS = BANKS,
    FACES = FACES,
}