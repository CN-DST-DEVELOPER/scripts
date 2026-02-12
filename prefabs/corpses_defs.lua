local easing = require("easing")

--------------------------------------------------------------------------------------------------------

-- #HACK_CLIENTSIDE_BUILD_OVERRIDE - This hack is done so we can immediately update the client side build overrides, to avoid a flicker when transitioning to a corpse

-- DEPRECATED. default build and bank is set in defs, with other variations being copied from mob death.
local BUILDS = {}
local BANKS = {}

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

    bunnyman =
    {
        manrabbit_enforcer_build = "rabbitkingminion_bunnyman",
    },

    buzzard =
    {
        buzzard_lunar_build = "mutatedbuzzard_gestalt",
    },

    hound =
    {
        hound_ocean = "hound",
        hound_red_ocean = "firehound",
        hound_ice_ocean = "icehound",
        hound_warglet = "warglet",
    },

    rabbitking =
    {
        rabbitking_aggressive_build = "rabbitking_aggressive",
        rabbitking_lucky_build = "rabbitking_lucky",
        rabbitking_passive_build = "rabbitking_passive",
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
        merm_guard_small_build = "mermguard",
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

-- moosecorpse

local function PickNewName(inst)
    inst.components.named:PickNewName()
end

-- playercorpse

local function Player_SetCorpseDescription(inst, char, playername, cause, pkname, userid)
    inst.char = char
    inst.playername = playername
    inst.userid = userid
    inst.pkname = pkname
    inst.cause = pkname == nil and cause:lower() or nil
    inst.components.inspectable.getspecialdescription = GetPlayerDeathDescription

    inst.displaynameoverride = char
    inst.net_displaynameoverride:set(char)
end

local function Player_SetCorpseAvatarData(inst, client_obj)
    inst.components.playeravatardata:SetData(client_obj)
end

local function Player_CorpseErodeFn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("die_fx").Transform:SetPosition(x, y, z)

    -- If HasPlayerSkeletons is false we shouldn't get here anyways, but just in case...
    local has_skeletons = TheSim:HasPlayerSkeletons()
    local skel = SpawnPrefab(has_skeletons and inst.skeleton_prefab or "shallow_grave_player")
    if skel ~= nil then
        skel.Transform:SetPosition(x, y, z)
        -- Set the description
        skel:SetSkeletonDescription(inst.char, inst.playername, inst.cause or "unknown", inst.pkname, inst.userid)
        skel:SetSkeletonAvatarData(inst.components.playeravatardata:GetData())
    end

    inst:Remove()
end

local function Player_OnDisplayNameOverrideDirty(inst)
    inst.displaynameoverride = inst.net_displaynameoverride:value()
end

--

local CORPSE_DEFS =
{
    { -- For search: deerclopscorpse
        creature = "deerclops",
        bank = "deerclops",
        build = "deerclops_build",
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
            enabled_tuning = "SPAWN_MUTATED_DEERCLOPS",
        },
    },

    { -- For search: wargcorpse
        creature = "warg",
        bank = "warg",
        build = "warg_build",
        sg = "SGwarg",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1,
        shadowsize = {2.5, 1.5},
        tags = { "largecreaturecorpse" },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutatedwarg",
            enabled_tuning = "SPAWN_MUTATED_WARG",
        },
    },

    { -- For search: beargercorpse
        creature = "bearger",
        bank = "bearger",
        build = "bearger_build",
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
        build = "crow_build",
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
        tags = { "birdcorpse", "smallcreaturecorpse" },
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
                local build = inst.AnimState:GetBuild()
                return (build ~= "crow_build") and "bird_mutant_spitter" or "bird_mutant"
            end,
            enabled_tuning = "SPAWN_MUTATED_BIRDS",
            mutation_chance = TUNING.BIRD_PRERIFT_MUTATION_SPAWN_CHANCE,
        },

        has_rift_mutation = true,
        rift_mutant_data =
        {
            overridemutantprefab = "mutatedbird",
            enabled_tuning = "SPAWN_MUTATED_BIRDS_GESTALT",
            mutation_chance = TUNING.BIRD_RIFT_POSSESSION_SPAWN_CHANCE,
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
        build = "buzzard_build",
        sg = "SGbuzzard",
        firesymbol = "buzzard_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_MED,
        tags = { "buzzard" },
        shadowsize = {1.25, .75},
        custom_physicsfn = function(inst)
            MakeInventoryPhysics(inst)
            inst:AddTag("blocker")
            inst.Physics:SetFriction(.5)
            inst.Physics:SetRestitution(0)
        end,

        override_immediate_gestalt_mutate_cb = function(inst, gestalt)
            local migrationmanager = TheWorld.components.migrationmanager
            local buzzard = ReplacePrefab(inst, inst:GetRiftMutantPrefab())

            if migrationmanager then
                migrationmanager:EnterMigration(MIGRATION_TYPES.MUTATED_BUZZARD_GESTALT, buzzard)
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
        build = "hound_ocean",
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
        tags = {},
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,

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
        build = "penguin_build",
        sg = "SGpenguin",
        faces = FACES.FOUR,
        assets =
        {
            Asset("ANIM", "anim/penguin_transformation.zip"),
        },
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,

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
        build = "spider_build",
        sg = "SGspider",
        override_build = "ds_spider_basic_transformation",
        faces = FACES.FOUR,
        --
        tags = { "spider", "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        shadowsize = {1.5, .5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,

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
        build = "spider_water",
        sg = "SGspider_water",
        override_build = "ds_spider_basic_transformation",
        faces = FACES.FOUR,
        --
        tags = { "spider", "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -50, 0),
        shadowsize = {1.5, .5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,

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
        build = "merm_build",
        sg = "SGmerm",
        faces = FACES.FOUR,
        assets =
        {
            Asset("ANIM", "anim/merm_transformation.zip"),
        },
        --
        tags = { "wet" },
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -100, 0), -- x and y are flipped here because of the symbol rotation. so this -100 is on x in-game actually!
        shadowsize = {1.5, .75},
        --
        sanityaurafn = function(inst, observer)
            if observer:HasTag("playermerm") then -- Noo! merm friend!
                return -TUNING.SANITYAURA_LARGE
            end

            return -TUNING.SANITYAURA_MED
        end,
        use_inventory_physics = true,

        has_pre_rift_mutation = true,
        pre_rift_mutant_data =
        {
            overridemutantprefab = function(inst)
                local build = inst.AnimState:GetBuild()
                return (
                    build == "merm_guard_build" or
                    build == "merm_guard_small_build"
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
        build = "spider_queen_build",
        sg = "SGspiderqueen",
        faces = FACES.FOUR,
        --
        firesymbol = "body",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {7, 3},
        tags = { "spider", "largecreaturecorpse", "epiccorpse" },
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

    { -- For search: pigcorpse
        creature = "pig",
        bank = "pigman",
        build = "pig_build",
        sg = "SGpig",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -100, 0), -- x and y are flipped here because of the symbol rotation. so this -100 is on x in-game actually!
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,

        common_postinit = function(inst)
            inst.AnimState:Hide("hat")
        end,
    },

    { -- For search: prime_matecorpse
        creature = "prime_mate",
        bank = "pigman",
        build = "monkeymen_build",
        sg = "SGprimemate",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, -100, 0), -- x and y are flipped here because of the symbol rotation. so this -100 is on x in-game actually!
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: beecorpse
        creature = "bee",
        bank = "bee",
        build = "bee_build",
        sg = "SGbee",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        fireoffset = Vector3(0, -1, 1),
        shadowsize = {.8, .5},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
    },

    { -- For search: tallbirdcorpse
        creature = "tallbird",
        bank = "tallbird",
        build = "ds_tallbird_basic",
        sg = "SGtallbird",
        faces = FACES.FOUR,
        --
        tags = { "largecreaturecorpse" },
        firesymbol = "head",
        makeburnablefn = MakeLargeBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {2.75, 1},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: mosslingcorpse
        creature = "mossling",
        bank = "mossling",
        build = "mossling_build",
        sg = "SGmossling",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "swap_fire",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, 1.25},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: catcooncorpse
        creature = "catcoon",
        bank = "catcoon",
        build = "catcoon_build",
        sg = "SGcatcoon",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "catcoon_torso",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        fireoffset = Vector3(1, 0, 1),
        shadowsize = {2, 0.75},
        --
        sanityaurafn = function(inst, observer)
            if observer:HasTag("bookbuilder") then
                return -TUNING.SANITYAURA_LARGE
            end

            return -TUNING.SANITYAURA_MED
        end,
        use_inventory_physics = true,
    },

    { -- For search: deercorpse
        creature = "deer",
        bank = "deer",
        build = "deer_build",
        sg = "SGdeer",
        faces = FACES.SIX,
        --
        tags = { },
        firesymbol = "deer_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.75, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        physicsradius = .5,

        common_postinit = function(inst)
            inst.AnimState:Hide("swap_antler")
        end,
    },

    { -- For search: rabbitcorpse
        creature = "rabbit",
        bank = "rabbit",
        build = "rabbit_build",
        sg = "SGrabbit",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "chest",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,

        common_postinit = function(inst)
            inst.AnimState:SetClientsideBuildOverride("insane", "rabbit_build", "beard_monster")
            inst.AnimState:SetClientsideBuildOverride("insane", "rabbit_winter_build", "beard_monster")
            inst.AnimState:FastForward(0) -- OMAR: #HACK_CLIENTSIDE_BUILD_OVERRIDE
        end,
    },

    { -- For search: rabbitkingcorpse
        creature = "rabbitking",
        bank = "rabbit",
        build = "rabbitking_passive_build",
        sg = "SGrabbitking",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "chest",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
    },

    { -- For search: frogcorpse
        creature = "frog",
        bank = "frog",
        build = "frog",
        sg = "SGfrog",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        shadowsize = {1.5, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,

        --has_rift_mutation = true,
        --rift_mutant_data =
        --{
        --    overridemutantprefab = "lunarfrog",
        --    enabled_tuning = "SPAWN_MUTATED_FROGS_GESTALT",
        --},
    },

    { -- For search: glommercorpse
        creature = "glommer",
        bank = "glommer",
        build = "glommer",
        sg = "SGglommer",
        faces = FACES.FOUR,
        --
        tags = { },
        shadowsize = {2, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_LARGE, -- He was so cute...
        use_inventory_physics = true,
    },

    { -- For search: gnarwailcorpse
        creature = "gnarwail",
        bank = "gnarwail",
        build = "gnarwail_build",
        sg = "SGgnarwail",
        faces = FACES.SIX,
        --
        tags = { },
        shadowsize = {0, 0},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: grassgatorcorpse
        creature = "grassgator",
        bank = "grass_gator",
        build = "grass_gator",
        sg = "SGgrassgator",
        faces = FACES.SIX,
        --
        tags = { "largecreaturecorpse" },
        firesymbol = "grass_gator_body",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {4.5, 2},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = .75,
    },

    { -- For search: grassgekkocorpse
        creature = "grassgekko",
        bank = "grassgecko",
        build = "grassgecko",
        sg = "SGgrassgekko",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "grassgecko_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        fireoffset = Vector3(1, 0, 1),
        shadowsize = {2, 0.75},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
    },

    { -- For search: moosecorpse
        creature = "moose",
        bank = "goosemoose",
        build = "goosemoose_build",
        sg = "SGmoose",
        faces = FACES.FOUR,
        --
        tags = { "largecreaturecorpse", "epiccorpse" },
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {6, 2.75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1.0,

        -- Unique moose logic
        common_postinit = function(inst)
            --Sneak these into pristine state for optimization
            inst:AddTag("_named")
        end,

        master_postinit = function(inst)
            --Remove these tags so that they can be added properly when replicating components below
            inst:RemoveTag("_named")

            inst:AddComponent("named")
            inst.components.named.possiblenames = {STRINGS.NAMES["MOOSE1"], STRINGS.NAMES["MOOSE2"]}
            PickNewName(inst)
            inst:DoPeriodicTask(5, PickNewName)
        end,
    },

    { -- For search: lightcrabcorpse
        creature = "lightcrab",
        bank = "lightcrab",
        build = "lightcrab",
        sg = "SGlightcrab",
        faces = FACES.SIX,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {0.8, 0.5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: lightninggoatcorpse
        creature = "lightninggoat",
        bank = "lightning_goat",
        build = "lightning_goat_build",
        sg = "SGlightninggoat",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "lightning_goat_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.75, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = .5,
    },

    { -- For search: bunnymancorpse
        creature = "bunnyman",
        bank = "manrabbit",
        build = "manrabbit_build",
        sg = "SGbunnyman",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "manrabbit_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,

        common_postinit = function(inst)
            inst.AnimState:SetClientsideBuildOverride("insane", "manrabbit_build", "manrabbit_beard_build")
            inst.AnimState:FastForward(0) -- OMAR: #HACK_CLIENTSIDE_BUILD_OVERRIDE
        end,
    },

    { -- For search: rabbitkingminion_bunnymancorpse
        creature = "rabbitkingminion_bunnyman",
        bank = "manrabbit",
        build = "manrabbit_build",
        sg = "SGbunnyman",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "manrabbit_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: mermkingcorpse
        creature = "mermking",
        bank = "merm_king",
        build = "merm_king",
        sg = "SGmermking",
        --
        tags = { "wet" },
        firesymbol = "torso",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaurafn = function(inst, observer)
            if observer:HasTag("playermerm") then -- Noo! King merm!
                return -TUNING.SANITYAURA_LARGE
            end

            return -TUNING.SANITYAURA_MED
        end,
        physicsradius = 1,
    },

    { -- For search: molecorpse
        creature = "mole",
        bank = "mole",
        build = "mole_build",
        sg = "SGmole",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        -- TODO moles should be burnable...
        --firesymbol = "mole",
        --makeburnablefn = MakeSmallBurnableCorpse,
        --fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
    },

    { -- For search: molecorpse
        creature = "molebat",
        bank = "molebat",
        build = "molebat",
        sg = "SGmolebat",
        faces = FACES.SIX,
        --
        tags = { },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
    },

    { -- For search: powder_monkeycorpse
        creature = "powder_monkey",
        bank = "monkey_small",
        build = "monkey_small",
        sg = "SGpowdermonkey",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "m_skirt",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {2, 1.25},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: mosquitocorpse
        creature = "mosquito",
        bank = "mosquito",
        build = "mosquito",
        sg = "SGmosquito",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "body",
        makeburnablefn = MakeSmallBurnableCorpse,
        fireoffset = Vector3(0, -1, 1),
        shadowsize = {.8, .5},
        --
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
    },

    { -- For search: ottercorpse
        creature = "otter",
        bank = "otter_basics",
        build = "otter_build",
        sg = "SGotter",
        faces = FACES.SIX,
        --
        tags = { },
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {4.0, 2.5},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: perdcorpse
        creature = "perd",
        bank = "perd",
        build = "perd",
        sg = "SGperd",
        faces = FACES.FOUR,
        --
        tags = { },
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.5, .75},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,

        common_postinit = function(inst)
            inst.AnimState:Hide("hat")
        end,
    },

    { -- For search: polly_rogerscorpse
        creature = "polly_rogers",
        bank = "polly_rogers",
        build = "polly_rogers",
        sg = "SGpolly_rogers",
        faces = FACES.FOUR,
        --
        tags = { "smallcreaturecorpse" },
        firesymbol = "polly_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1, .75},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
    },

    { -- For search: slurtlecorpse
        creature = "slurtle",
        bank = "slurtle",
        build = "slurtle",
        sg = "SGslurtle",
        faces = FACES.FOUR,
        --
        tags = { },
        --firesymbol = "shell", -- No shell, silly!
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {2, 1.5},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
    },

    { -- For search: spatcorpse
        creature = "spat",
        bank = "spat",
        build = "spat_build",
        sg = "SGspat",
        faces = FACES.SIX,
        --
        tags = { "largecreaturecorpse" },
        firesymbol = "spat_body",
        makeburnablefn = MakeLargeBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {6, 2},
        --
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = .5,
    },

    { -- For search: squidcorpse
        creature = "squid",
        bank = "squiderp",
        build = "squid_build",
        sg = "SGsquid",
        faces = FACES.SIX,
        --
        tags = { },
        firesymbol = "squid_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {2.5, 1.5},
        --
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
    },

    { -- For search: dragonflycorpse
        creature = "dragonfly",
        bank = "dragonfly",
        build = "dragonfly_build",
        sg = "SGdragonfly",
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1.4,
        shadowsize = {6, 3.5},
        tags = { "dragonfly", "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: beequeencorpse
        creature = "beequeen",
        bank = "bee_queen",
        build = "bee_queen_build",
        sg = "SGbeequeen",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 1.4,
        shadowsize = {4, 2},
        tags = { "insect", "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: toadstoolcorpse
        creature = "toadstool",
        bank = "toadstool",
        build = "toadstool_build",
        sg = "SGtoadstool",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 2.5,
        shadowsize = {6, 3.5},
        tags = { "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: klauscorpse
        creature = "klaus",
        bank = "klaus",
        build = "klaus_build",
        sg = "SGklaus",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 1.2 * 1,
        shadowsize = {4, 2},
        tags = { "epiccorpse", "largecreaturecorpse" },
        
        common_postinit = function(inst)
            inst.AnimState:Hide("swap_chain")
            inst.AnimState:Hide("swap_chain_lock")
        end,
    },

    { -- For search: eyeofterrorcorpse
        creature = "eyeofterror",
        bank = "eyeofterror",
        build = "eyeofterror_basic",
        sg = "SGeyeofterror",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 1.5,
        shadowsize = {6, 2},
        tags = { "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: malbatrosscorpse
        creature = "malbatross",
        bank = "malbatross",
        build = "malbatross_build",
        sg = "SGmalbatross",
        firesymbol = "body",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1.5,
        shadowsize = {6, 2},
        tags = { "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: krampuscorpse
        creature = "krampus",
        bank = "krampus",
        build = "krampus_build",
        sg = "SGkrampus",
        firesymbol = "krampus_torso",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        physicsradius = .5,
        shadowsize = {3, 1},
        tags = { },
    },

    { -- For search: batcorpse
        creature = "bat",
        bank = "bat",
        build = "bat_basic",
        sg = "SGbat",
        firesymbol = "bat_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
        shadowsize = {1.5, .75},
        tags = { },
    },

    { -- For search: beeguardcorpse
        creature = "beeguard",
        bank = "bee_guard",
        build = "bee_guard_build",
        sg = "SGbeeguard",
        firesymbol = "mane",
        makeburnablefn = MakeSmallBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
        shadowsize = {1.2, .75},
        tags = { "insect", },
    },

    { -- For search: eyeofterror_minicorpse
        creature = "eyeofterror_mini",
        bank = "eyeofterror_mini",
        build = "eyeofterror_mini_mob_build",
        sg = "SGeyeofterror_mini",
        firesymbol = "glomling_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
        shadowsize = {.8, .5},
        tags = { "smallcreaturecorpse", },
    },

    { -- For search: monkeycorpse
        creature = "monkey",
        bank = "kiki",
        build = "kiki_basic",
        sg = "SGmonkey",
        makeburnablefn = MakeMediumBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
        shadowsize = {2, 1.25},
        tags = { },
    },

    { -- For search: rockycorpse
        creature = "rocky",
        bank = "rocky",
        build = "rocky",
        sg = "SGrocky",
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1,
        shadowsize = {1.75, 1.75},
        tags = {  },
    },

    { -- For search: minotaurcorpse
        creature = "minotaur",
        bank = "rook",
        build = "rook_rhino",
        sg = "SGminotaur",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_LARGE,
        physicsradius = 2.2,
        shadowsize = {5, 3},
        tags = { "epiccorpse", },
    },

    { -- For search: sharkcorpse
        creature = "shark",
        bank = "shark",
        build = "shark_build",
        sg = "SGshark",
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
        shadowsize = {2.5, 1.5},
        tags = { "largecreaturecorpse", "wet" },
    },

    { -- For search: smallbirdcorpse
        creature = "smallbird",
        bank = "smallbird",
        build = "smallbird_basic",
        sg = "SGsmallbird",
        firesymbol = "head",
        makeburnablefn = MakeSmallBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_TINY,
        use_inventory_physics = true,
        shadowsize = {1.25, .75},
        tags = { "smallcreaturecorpse" },
    },

    { -- For search: tentaclecorpse
        creature = "tentacle",
        bank = "tentacle",
        build = "tentacle",
        sg = "SGtentacle",
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
        shadowsize = {0, 0},
        tags = { "wet" },
    },

    { -- For search: walruscorpse
        creature = "walrus",
        bank = "walrus",
        build = "walrus_build",
        sg = "SGwalrus",
        firesymbol = "pig_torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
        shadowsize = {2.5, 1.5},
        tags = { },
    },

    { -- For search: antlioncorpse
        creature = "antlion",
        bank = "antlion",
        build = "antlion_build",
        sg = "SGantlion_angry",
        firesymbol = "body",
        makeburnablefn = MakeLargeBurnableCorpse,
        sanityaura = -TUNING.SANITYAURA_MED,
        physicsradius = 1.5,
        shadowsize = {0, 0},
        tags = { "epiccorpse", "largecreaturecorpse" },
    },

    { -- For search: chestercorpse
        creature = "chester",
        bank = "chester",
        build = "chester_build",
        sg = "SGchester",
        firesymbol = "chester_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        faces = FACES.FOUR,
        sanityaura = -TUNING.SANITYAURA_MED,
        use_inventory_physics = true,
        shadowsize = {2, 1.5},
        tags = { },
    },

    { -- For search: dustmothcorpse
        creature = "dustmoth",
        bank = "dustmoth",
        build = "dustmoth",
        sg = "SGdustmoth",
        firesymbol = "dm_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        use_inventory_physics = true,
        shadowsize = {2.8, 2.5},
        tags = { },
    },

    { -- For search: koalefantcorpse
        creature = "koalefant",
        bank = "koalefant",
        build = "koalefant_summer_build",
        nameoverride = "koalefant_carcass",
        displaynameoverride = "koalefant_summer",
        sg = "SGkoalefant",
        firesymbol = "beefalo_body",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        sanityaura = -TUNING.SANITYAURA_SMALL,
        physicsradius = .75,
        shadowsize = {4.5, 2},
        tags = { "largecreaturecorpse" },

        master_postinit = function(inst)
            inst.corpsedeathtime = 10 -- To match original carcass behaviour
        end,
    },

    { -- For search: playercorpse
        creature = "player",
        bank = "wilson",
        build = "wilson",
        sg = "SGwilson",
        faces = FACES.FOUR,
        --
        tags = { "playercorpse" },
        firesymbol = "torso",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        fireoffset = Vector3(0, 0, 0),
        shadowsize = {1.3, .6},
        --
        sanityaura = -TUNING.SANITYAURA_HUGE,
        use_inventory_physics = true,
        -- Unique player logic
        common_postinit = function(inst)
            inst:AddComponent("playeravatardata")
            inst.components.playeravatardata:AddPlayerData(true)

            inst.net_displaynameoverride = net_string(inst.GUID, "playercorpse.displaynameoverride", "displaynameoverridedirty")
            if not TheWorld.ismastersim then
                inst:ListenForEvent("displaynameoverridedirty", Player_OnDisplayNameOverrideDirty)
            end
        end,

        master_postinit = function(inst)
            inst.skeleton_prefab = "skeleton_player"

            inst:AddComponent("skinner")
            inst.components.skinner:SetupNonPlayerData()
            inst.components.skinner.useskintypeonload = true -- Hack.

            inst.components.inspectable:SetNameOverride("skeleton_player")

            inst.SetCorpseDescription = Player_SetCorpseDescription
            inst.SetCorpseAvatarData  = Player_SetCorpseAvatarData

            inst.corpseerodefn = Player_CorpseErodeFn
        end,

        OnSave = function(inst, data)
            data.char = inst.char
            data.playername = inst.playername
            data.userid = inst.userid
            data.pkname = inst.pkname
            data.cause = inst.cause
            data.skeleton_prefab = inst.skeleton_prefab or nil
        end,

        OnLoad = function(inst, data)
            if not data or not data.char or (not data.cause and not data.pkname) then
                return
            end

            inst.char = data.char
            inst.playername = data.playername
            inst.userid = data.userid
            inst.pkname = data.pkname
            inst.cause = data.cause
            inst.skeleton_prefab = data.skeleton_prefab or nil

            inst.displaynameoverride = inst.char
            inst.net_displaynameoverride:set(inst.char)

            inst.components.inspectable.getspecialdescription = GetPlayerDeathDescription
        end,
    },
}

local CORPSE_PROP_DEFS =
{
    { -- For search: koalefantcorpse_prop
        creature = "koalefant",
        bank = "koalefant",
        build = "koalefant_summer_build",
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

--

-- Override these prefabs when we're processing the corpse loot, usually into a "lesser" form
-- Can be table { newprefab, num } or function that returns newprefab and num
local CORPSE_LOOT_OVERRIDES =
{
    ["bearger_fur"] = { "furtuft", 30 }
}

--

-- Util function for getting a corpse entries data.
-- Useful for mods to find a corpse to edit quickly.
local function GetCorpseData(creaturename)
    for i, corpsedata in ipairs(CORPSE_DEFS) do
        if corpsedata.creature == creaturename then
            return corpsedata
        end
    end
end

local function GetCorpsePropData(creaturename)
    for i, propdata in ipairs(CORPSE_PROP_DEFS) do
        if propdata.creature == creaturename then
            return propdata
        end
    end
end

return {
    CORPSE_DEFS = CORPSE_DEFS,
    CORPSE_PROP_DEFS = CORPSE_PROP_DEFS,

    CORPSE_LOOT_OVERRIDES = CORPSE_LOOT_OVERRIDES,

    BUILDS = BUILDS,
    BUILDS_TO_NAMES = BUILDS_TO_NAMES,
    BANKS = BANKS,
    FACES = FACES,

    -- Util
    GetCorpseData = GetCorpseData,
    GetCorpsePropData = GetCorpsePropData,
}