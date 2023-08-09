function d_spawnlist(list, spacing, fn)
    local created = {}
    spacing = spacing or 2
    local num_wide = math.ceil(math.sqrt(#list))

    local pt = ConsoleWorldPosition()
    pt.x = pt.x - num_wide * 0.5 * spacing
    pt.z = pt.z - num_wide * 0.5 * spacing

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            if list[(y*num_wide + x + 1)] then
                local prefab = list[(y*num_wide + x + 1)]
                local count = 1
                local item_fn = nil
                if type(prefab) == "table" then
                    count = prefab[2]
                    item_fn = prefab[3]
                    prefab = prefab[1]
                end
                local inst = SpawnPrefab(prefab)
                if inst ~= nil then
                    table.insert(created, inst)
                    inst.Transform:SetPosition((pt + Vector3(x*spacing, 0, y*spacing)):Get())
                    if count > 1 then
                        if inst.components.stackable then
                            inst.components.stackable:SetStackSize(count)
                        end
                    end
                    if item_fn ~= nil then
                        item_fn(inst)
                    end
                    if fn ~= nil then
                        fn(inst)
                    end
                end
            end
        end
    end
    return created
end

function d_playeritems()
    local items = {}
    for prefab, recipe in pairs(AllRecipes) do
        if recipe.builder_tag and recipe.placer == nil and prefab:find("_builder") == nil then
            items[recipe.builder_tag] = items[recipe.builder_tag] or {}
            table.insert(items[recipe.builder_tag], prefab)
        end
    end
    local items_sorted = {}
    for tag, prefabs in pairs(items) do
        table.insert(items_sorted, tag)
    end
    table.sort(items_sorted)
    local tospawn = {}
    for _, tag in ipairs(items_sorted) do
        table.sort(items[tag])
        for _, prefab in ipairs(items[tag]) do
            if Prefabs[prefab] ~= nil then
                table.insert(tospawn, prefab)
            end
        end
    end
    d_spawnlist(tospawn, 1.5)
end

function d_allmutators()
    c_give("mutator_warrior")
    c_give("mutator_dropper")
    c_give("mutator_hider")
    c_give("mutator_spitter")
    c_give("mutator_moon")
    c_give("mutator_water")
end

function d_allcircuits()
    local module_defs = require("wx78_moduledefs").module_definitions

    local pt = ConsoleWorldPosition()
    local spacing, num_wide = 2, math.ceil(math.sqrt(#module_defs))

    for y = 0, num_wide - 1 do
        for x = 0, num_wide - 1 do
            local def = module_defs[(y*num_wide) + x + 1]
            local circuit = SpawnPrefab("wx78module_"..def.name)
            if circuit ~= nil then
                local spacing_vec = Vector3(x * spacing, 0, y * spacing)
                circuit.Transform:SetPosition((pt + spacing_vec):Get())
            end
        end
    end
end

function d_allheavy()
    local heavy_objs = {
        "cavein_boulder",
        "sunkenchest",
        "sculpture_knighthead",
        "glassspike",
        "moon_altar_idol",
        "oceantreenut",
        "shell_cluster",
        "potato_oversized",
        "chesspiece_knight_stone",
        "chesspiece_knight_marble",
        "chesspiece_knight_moonglass",
        "potatosack"
    }

    local x,y,z = ConsoleWorldPosition():Get()
    local start_x = x
    for i,v in ipairs(heavy_objs) do
        local obj = SpawnPrefab(v)
        obj.Transform:SetPosition(x,y,z)

        x = x + 2.5
        if i == 6 then
            z = z + 2.5
            x = start_x
        end
    end
end

function d_spiders()
    local spiders = {
        "spider",
        "spider_warrior",
        "spider_dropper",
        "spider_hider",
        "spider_spitter",
        "spider_moon",
        "spider_healer",
    }

    for i,v in ipairs(spiders) do
        local spider = c_spawn(v)
        spider.components.follower:SetLeader(ThePlayer)
    end
    c_give("spider_water")
end

function d_particles()
    local emittingfx = {
        "cane_candy_fx",
        "cane_harlequin_fx",
        "cane_victorian_fx",
        "eyeflame",
        "lighterfire_haunteddoll",
        "lighterfire",
        "lunar_goop_cloud_fx",
        "thurible_smoke",
        "torchfire",
        "torchfire_barber",
        "torchfire_carrat",
        "torchfire_nautical",
        "torchfire_pillar",
        "torchfire_pronged",
        "torchfire_rag",
        "torchfire_shadow",
        "torchfire_spooky",
        "torchfire_yotrpillowfight",
        -- Particles below need special handling to function.
        --"frostbreath",
        --"lunarrift_crystal_spawn_fx",
        --"nightsword_curve_fx",
        --"nightsword_lightsbane_fx",
        --"nightsword_sharp_fx",
        --"nightsword_wizard_fx",
        --"reviver_cupid_beat_fx",
        --"reviver_cupid_glow_fx",
    }
    local overridespeed = { -- Some particles want speed to emit.
        cane_harlequin_fx = PI2 * FRAMES,
        cane_victorian_fx = PI2 * FRAMES,
    }
    local created = d_spawnlist(emittingfx, 6)
    local r = 1.5
    for _, v in ipairs(created) do
        v._d_pos = v:GetPosition()
        v._d_theta = 0
        v.persists = false

        local labeler = c_spawn("razor")
        labeler.Transform:SetPosition(v._d_pos:Get())
        labeler.persists = false
        labeler.AnimState:SetScale(0, 0)

        local label = labeler.entity:AddLabel()
        label:SetFontSize(12)
        label:SetFont(BODYTEXTFONT)
        label:SetWorldOffset(0, 0, 0)
        label:SetText(v.prefab)
        label:SetColour(1, 1, 1)
        label:Enable(true)

        v:DoPeriodicTask(FRAMES, function()
            v._d_theta = v._d_theta + (overridespeed[v.prefab] or PI * 0.5 * FRAMES)
            v.Transform:SetPosition(v._d_pos.x + r * math.cos(v._d_theta), 0, v._d_pos.z + r * math.sin(v._d_theta))
        end)
    end
end

function d_decodedata(path)
    print("DECODING",path)
    TheSim:GetPersistentString(path, function(load_success, str)
        if load_success then
            print("LOADED...")
            TheSim:SetPersistentString(path.."_decoded", str, false, function()
                print("SAVED!")
            end)
        else
            print("ERROR LOADING FILE! (wrong path?)")
        end
    end)
end

function d_riftspawns()
    c_announce("Rift open, 10s for spawning..")
    if TheWorld:HasTag("cave") then
        TheWorld:PushEvent("shadowrift_opened")
    else
        TheWorld:PushEvent("lunarrift_opened")
    end
    TheWorld:DoTaskInTime(10, function()
        c_announce("Rifts Spawning..")
        for i = 1, 200 do
            TheWorld.components.riftspawner:SpawnRift()
        end
        TheWorld.components.riftspawner:DebugHighlightRifts()
    end)
end

function d_lunarrift()
    local riftspawner = TheWorld.components.riftspawner
    riftspawner:EnableLunarRifts()
    local pos = ConsoleWorldPosition()
    local x, y, z = TheWorld.Map:GetTileCenterPoint(pos:Get())
    pos.x, pos.y, pos.z = x, y, z
    riftspawner:SpawnRift(pos)
end

function d_shadowrift()
    local riftspawner = TheWorld.components.riftspawner
    riftspawner:EnableShadowRifts()
    local pos = ConsoleWorldPosition()
    local x, y, z = TheWorld.Map:GetTileCenterPoint(pos:Get())
    pos.x, pos.y, pos.z = x, y, z
    riftspawner:SpawnRift(pos)
end

function d_resetskilltree()
    local player = ConsoleCommandPlayer()

    if not (player and TheWorld.ismastersim) then
        return
    end

    local skilltreeupdater = player.components.skilltreeupdater
    local skilldefs = require("prefabs/skilltree_defs").SKILLTREE_DEFS[player.prefab]
    if skilldefs ~= nil then
        for skill, data in pairs(skilldefs) do
            skilltreeupdater:DeactivateSkill(skill)
        end
    end

    skilltreeupdater:AddSkillXP(9999999)
end

function d_allsongs()
    c_give("battlesong_durability")
    c_give("battlesong_healthgain")
    c_give("battlesong_sanitygain")
    c_give("battlesong_sanityaura")
    c_give("battlesong_fireresistance")

    c_give("battlesong_instant_taunt")
    c_give("battlesong_instant_panic")
end

function d_allstscostumes()
    c_give("mask_dollhat")
    c_give("mask_dollbrokenhat")
    c_give("mask_dollrepairedhat")
    c_give("costume_doll_body")

    c_give("mask_blacksmithhat")
    c_give("costume_blacksmith_body")

    c_give("mask_mirrorhat")
    c_give("costume_mirror_body")

    c_give("mask_queenhat")
    c_give("costume_queen_body")

    c_give("mask_kinghat")
    c_give("costume_king_body")

    c_give("mask_treehat")
    c_give("costume_tree_body")

    c_give("mask_foolhat")
    c_give("costume_fool_body")
end

function d_domesticatedbeefalo(tendency, saddle)
    local beef = c_spawn('beefalo')
    beef.components.domesticatable:DeltaDomestication(1)
    beef.components.domesticatable:DeltaObedience(0.5)
    beef.components.domesticatable:DeltaTendency(TENDENCY[tendency] or TENDENCY.DEFAULT, 1)
    beef:SetTendency()
    beef.components.domesticatable:BecomeDomesticated()
    beef.components.rideable:SetSaddle(nil, SpawnPrefab(saddle or "saddle_basic"))
end

function d_domestication(domestication, obedience)
    if c_sel().components.domesticatable == nil then
        print("Selected ent not domesticatable")
    end
    if domestication ~= nil then
        c_sel().components.domesticatable:DeltaDomestication(domestication - c_sel().components.domesticatable:GetDomestication())
    end
    if obedience ~= nil then
        c_sel().components.domesticatable:DeltaObedience(obedience - c_sel().components.domesticatable:GetObedience())
    end
end

function d_testwalls()
    local walls = {
        "stone",
        "wood",
        "hay",
        "ruins",
        "moonrock",
    }
    local sx,sy,sz = ConsoleCommandPlayer().Transform:GetWorldPosition()
    for i,mat in ipairs(walls) do
        for j = 0,4 do
            local wall = SpawnPrefab("wall_"..mat)
            wall.Transform:SetPosition(sx + (i*6), sy, sz + j)
            wall.components.health:SetPercent(j*0.25)
        end
        for j = 5,15 do
            local wall = SpawnPrefab("wall_"..mat)
            wall.Transform:SetPosition(sx + (i*6), sy, sz + j)
            wall.components.health:SetPercent(j <= 11 and 1 or 0.5)
        end
    end
end


function d_testruins()
    ConsoleCommandPlayer().components.builder:UnlockRecipesForTech({SCIENCE = 2, MAGIC = 2})
    c_give("log", 20)
    c_give("flint", 20)
    c_give("twigs", 20)
    c_give("cutgrass", 20)
    c_give("lightbulb", 5)
    c_give("healingsalve", 5)
    c_give("batbat")
    c_give("icestaff")
    c_give("firestaff")
    c_give("tentaclespike")
    c_give("slurtlehat")
    c_give("armorwood")
    c_give("minerhat")
    c_give("lantern")
    c_give("backpack")
end

function d_combatgear()
    c_give("armorwood")
    c_give("footballhat")
    c_give("spear")
end

function d_teststate(state)
    c_sel().sg:GoToState(state)
end

function d_anim(animname, loop)
    if GetDebugEntity() then
        GetDebugEntity().AnimState:PlayAnimation(animname, loop or false)
    else
        print("No DebugEntity selected")
    end
end

function d_light(c1, c2, c3)
    TheSim:SetAmbientColour(c1, c2 or c1, c3 or c1)
end

local COMBAT_TAGS = {"_combat"}
function d_combatsimulator(prefab, count, force)
    count = count or 1

    local x,y,z = ConsoleWorldPosition():Get()
    local MakeBattle = nil
    MakeBattle = function()
        local creature = DebugSpawn(prefab)
        creature:ListenForEvent("onremove", MakeBattle)
        creature.Transform:SetPosition(x,y,z)
        if creature.components.knownlocations then
            creature.components.knownlocations:RememberLocation("home", {x=x,y=y,z=z})
        end
        if force then
            local target = FindEntity(creature, 20, nil, COMBAT_TAGS)
            if target then
                creature.components.combat:SetTarget(target)
            end
            creature:ListenForEvent("droppedtarget", function()
                local target = FindEntity(creature, 20, nil, COMBAT_TAGS)
                if target then
                    creature.components.combat:SetTarget(target)
                end
            end)
        end
    end

    for i=1,count do
        MakeBattle()
    end
end

function d_spawn_ds(prefab, scenario)
    local inst = c_spawn(prefab)
    if not inst then
        print("Need to select an entity to apply the scenario to.")
        return
    end

    if inst.components.scenariorunner then
        inst.components.scenariorunner:ClearScenario()
    end

    -- force reload the script -- this is for testing after all!
    package.loaded["scenarios/"..scenario] = nil

    inst:AddComponent("scenariorunner")
    inst.components.scenariorunner:SetScript(scenario)
    inst.components.scenariorunner:Run()
end



---------------------------------------------------
------------ skins functions --------------------
---------------------------------------------------

--For testing legacy skin DLC popup
--AddNewSkinDLCEntitlement("pack_oni_gift") MakeSkinDLCPopup()

local TEST_ITEM_NAME = "birdcage_pirate"
function d_test_thank_you(param)
    local ThankYouPopup = require "screens/thankyoupopup"
    local SkinGifts = require("skin_gifts")
    TheFrontEnd:PushScreen(ThankYouPopup({{ item = param or TEST_ITEM_NAME, item_id = 0, gifttype = SkinGifts.types[param or TEST_ITEM_NAME] or "DEFAULT" }}))
end
function d_test_skins_popup(param)
    local SkinsItemPopUp = require "screens/skinsitempopup"
    TheFrontEnd:PushScreen( SkinsItemPopUp(param or TEST_ITEM_NAME, "Peter", {1.0, 0.2, 0.6, 1.0}) )
end
function d_test_skins_announce(param)
    Networking_SkinAnnouncement("Peter", {1.0, 0.2, 0.6, 1.0}, param or TEST_ITEM_NAME)
end
function d_test_skins_gift(param)
    local GiftItemPopUp = require "screens/giftitempopup"
    TheFrontEnd:PushScreen( GiftItemPopUp(ThePlayer, { param or TEST_ITEM_NAME }, { 0 }) )
end

function d_print_skin_info()

    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

    local a = {
        "campfire_cabin",
        "armor_wood_roman",
        "spear_northern",
        "pickaxe_northern"
    }

    for _,v in pairs(a) do
        print( GetSkinName(v), GetSkinUsableOnString(v) )
    end

    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end

function d_skin_mode(mode)
    ConsoleCommandPlayer().components.skinner:SetSkinMode(mode)
end

function d_skin_name(name)
    ConsoleCommandPlayer().components.skinner:SetSkinName(name)
end

function d_clothing(name)
    ConsoleCommandPlayer().components.skinner:SetClothing(name)
end
function d_clothing_clear(type)
    ConsoleCommandPlayer().components.skinner:ClearClothing(type)
end

function d_cycle_clothing()
    local skinslist = TheInventory:GetFullInventory()

    local idx = 1
    local task = nil

    ConsoleCommandPlayer().cycle_clothing_task = ConsoleCommandPlayer():DoPeriodicTask(10,
        function()
            local type, name = GetTypeForItem(skinslist[idx].item_type)
            --print("showing clothing idx ", idx, name, type, #skinslist)
            if (type ~= "base" and type ~= "item") then
                c_clothing(name)
            end

            if idx < #skinslist then
                idx = idx + 1
            else
                print("Ending cycle")
                ConsoleCommandPlayer().cycle_clothing_task:Cancel()
            end
        end)

end

function d_sinkhole()
    c_spawn("antlion_sinkhole"):PushEvent("startcollapse")
end

function d_stalkersetup()
    local mound = c_spawn("fossil_stalker")
    --mound.components.workable:SetWorkLeft(mound.components.workable.maxwork - 1)
    for i = 1, (mound.components.workable.maxwork - 1) do
        mound.form = 1
        mound.components.repairable.onrepaired(mound)
    end

    c_give "shadowheart"
    c_give "atrium_key"
end

function d_resetruins()
    TheWorld:PushEvent("resetruins")
end

-- Get the widget selected by the debug widget editor (WidgetDebug).
-- Try d_getwidget():ScaleTo(3,1,.7)
function d_getwidget()
    return TheFrontEnd.widget_editor.debug_widget_target
end

function d_halloween()
    local spacing = 2
    local num_wide = math.ceil(math.sqrt(NUM_TRINKETS))

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab("trinket_"..(y*num_wide + x + 1))
            if inst ~= nil then
                print(x*spacing,  y*spacing)
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end

    local candy_wide = math.ceil(math.sqrt(NUM_HALLOWEENCANDY))
    for y = 0, candy_wide-1 do
        for x = 0, candy_wide-1 do
            local inst = SpawnPrefab("halloweencandy_"..(y*candy_wide + x + 1))
            if inst ~= nil then
                print(x*spacing,  y*spacing)
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3((x + num_wide)*spacing, 0, (y+num_wide)*spacing)):Get())
            end
        end
    end
end

function d_potions()
    local all_potions = {"halloweenpotion_bravery_small", "halloweenpotion_bravery_large", "halloweenpotion_health_small",  "halloweenpotion_health_large",
                         "halloweenpotion_sanity_small", "halloweenpotion_sanity_large", "halloweenpotion_embers",  "halloweenpotion_sparks",  "livingtree_root"}

    local spacing = 2
    local num_wide = math.ceil(math.sqrt(#all_potions))

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(all_potions[(y*num_wide + x + 1)])
            if inst ~= nil then
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_weirdfloaters()
    local weird_float_items =
    {
        "abigail flower",   "axe",              "batbat",       "blowdart_fire",    "blowdart_pipe",    "blowdart_sleep",
        "blowdart_walrus",  "blowdart_yellow",  "boomerang",    "brush",            "bugnet",           "cane",
        "firestaff",        "fishingrod",       "glasscutter",  "goldenaxe",        "goldenpickaxe",
        "goldenshovel",     "grass_umbrella",   "greenstaff",   "hambat",           "hammer",           "houndstooth",
        "houndwhistle",     "icestaff",         "lucy",         "miniflare",        "moonglassaxe",     "multitool_axe_pickaxe",
        "nightstick",       "nightsword",       "opalstaff",    "orangestaff",      "panflute",         "perdfan",
        "pickaxe",          "pitchfork",        "razor",        "redlantern",       "shovel",           "spear",
        "spear_wathgrithr", "staff_tornado",    "telestaff",    "tentaclespike",    "trap",             "umbrella",
        "yellowstaff",      "yotp_food3",
    }

    local spacing = 2
    local num_wide = math.ceil(math.sqrt(#weird_float_items))

    for y = 0, num_wide - 1 do
        for x = 0, num_wide - 1 do
            local inst = SpawnPrefab(weird_float_items[y*num_wide + x + 1])
            if inst ~= nil then
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_wintersfeast()
    local all_items = GetAllWinterOrnamentPrefabs()
    local spacing = 2
    local num_wide = math.ceil(math.sqrt(#all_items))

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(all_items[(y*num_wide + x + 1)])
            if inst ~= nil then
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_wintersfood()
    local spacing = 2
    local num_wide = math.ceil(math.sqrt(NUM_WINTERFOOD))

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab("winter_food"..(y*num_wide + x + 1))
            if inst ~= nil then
                inst.Transform:SetPosition((ConsoleWorldPosition() + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_madsciencemats()
    c_mat("halloween_experiment_bravery")
    c_mat("halloween_experiment_health")
    c_mat("halloween_experiment_hunger")
    c_mat("halloween_experiment_sanity")
    c_mat("halloween_experiment_volatile")
    c_mat("halloween_experiment_root")
end

function d_showalleventservers()
    TheFrontEnd._showalleventservers = not TheFrontEnd._showalleventservers
end

function d_lavaarena_skip()
    TheWorld:PushEvent("ms_lavaarena_endofstage", {reason="debug triggered"})
end

function d_lavaarena_speech(dialog, banter_line)
    local is_banter = string.find(string.upper(dialog), "BANTER", 1) ~= nil
    dialog = STRINGS[string.upper(dialog)]
    if dialog ~= nil then
        if is_banter then
            dialog = { dialog[banter_line or math.random(#dialog)] }
        end

        local lines = {}
        for i,v in ipairs(dialog) do
            table.insert(lines, {message=v, duration=3.5, noanim=true})
        end

        local target = TheWorld.components.lavaarenaevent:GetBoarlord()
        if target then
            target:PushEvent("lavaarena_talk", {text=lines})
        end
    end
end

function d_unlockallachievements()
    local achievements = {}
    for k, _ in pairs(EventAchievements:GetActiveAchievementsIdList()) do
        table.insert(achievements, k)
    end

    TheItems:ReportEventProgress(json.encode_compliant(
        {
            WorldID = "dev_"..tostring(math.random(9999999))..tostring(math.random(9999999)),
            Teams =
            {
                {
                    Won=true,
                    Points=5,
                    PlayerStats=
                    {
                        {KU = TheNet:GetUserID(), PlaytimeMs = 100000, Custom = { UnlockAchievements = achievements }},
                    }
                },
            }
        }), function(ku_tbl, success) print( "Report event:", success) dumptable(ku_tbl) end )

end

function d_unlockfoodachievements()
    local achievements = {
        "food_001", "food_002", "food_003", "food_004", "food_005", "food_006", "food_007", "food_008", "food_009",
        "food_010", "food_011", "food_012", "food_013", "food_014", "food_015", "food_016", "food_017", "food_018", "food_019",
        "food_020", "food_021", "food_022", "food_023", "food_024", "food_025", "food_026", "food_027", "food_028", "food_029",
        "food_030", "food_031", "food_032", "food_033", "food_034", "food_035", "food_036", "food_037", "food_038", "food_039",
        "food_040", "food_041", "food_042", "food_043", "food_044", "food_045", "food_046", "food_047", "food_048", "food_049",
        "food_050", "food_051", "food_052", "food_053", "food_054", "food_055", "food_056", "food_057", "food_058", "food_059",
        "food_060",	"food_061", "food_062", "food_063", "food_064", "food_065", "food_066", "food_067", "food_068", "food_069",
        "food_syrup",
    }

    TheItems:ReportEventProgress(json.encode_compliant(
        {
            WorldID = "dev_"..tostring(math.random(9999999))..tostring(math.random(9999999)),
            Teams =
            {
                {
                    Won=true,
                    Points=5,
                    PlayerStats=
                    {
                        {KU = TheNet:GetUserID(), PlaytimeMs = 1000, Custom = { UnlockAchievements = achievements }},
                    }
                },
            }
        }), function(ku_tbl, success) print( "Report event:", success) dumptable(ku_tbl) end )

end

function d_reportevent(other_ku)
    TheItems:ReportEventProgress(json.encode_compliant(
        {
            WorldID = "dev_"..tostring(math.random(9999999))..tostring(math.random(9999999)),
            Teams =
            {
                {
                    Won=true,
                    Points=5,
                    PlayerStats=
                    {
                        {KU = TheNet:GetUserID(), PlaytimeMs = 100000, Custom = { UnlockAchievements = {"scotttestdaily_d1", "wintime_30"} }},
                        --{KU = other_ku or "KU_test", PlaytimeMs = 60000}
                    }
                },
                --{
                --	Won=false,
                --	Points=2,
                --	PlayerStats=
                --	{
                --		{KU = "KU_test2", PlaytimeMs = 6000}
                --	}
                --}
            }
        }), function(ku_tbl, success) print( "Report event:", success) dumptable(ku_tbl) end )
end

function d_ground(ground, pt)
    ground = ground == nil and WORLD_TILES.QUAGMIRE_SOIL or
            type(ground) == "string" and WORLD_TILES[string.upper(ground)]
            or ground

    pt = pt or ConsoleWorldPosition()

    local x, y = TheWorld.Map:GetTileCoordsAtPoint(pt:Get())
    TheWorld.Map:SetTile(x, y, ground)
end

function d_portalfx()
    TheWorld:PushEvent("ms_newplayercharacterspawned", { player = ThePlayer})
end

function d_walls(width, height)
    width = math.floor(width or 10)
    height = math.floor(height or width)

    local pt = ConsoleWorldPosition()
    local left = math.floor(pt.x - width/2)
    local top = math.floor(pt.z + height/2)

    for i = 1, height do
        SpawnPrefab("wall_wood").Transform:SetPosition(left + 1, 0, top - i)
        SpawnPrefab("wall_wood").Transform:SetPosition(left + width, 0, top - i)
    end
    for i = 2, width-1 do
        SpawnPrefab("wall_wood").Transform:SetPosition(left + i, 0, top-1)
        SpawnPrefab("wall_wood").Transform:SetPosition(left + i, 0, top - height)
    end
end

-- 	hidingspot = c_select()  kitcoon = SpawnPrefab("kitcoon_deciduous") if not kitcoon.components.hideandseekhider:GoHide(hidingspot, 0) then kitcoon:Remove() end kitcoon = nil hidingspot = nil
function d_hidekitcoon()
    local hidingspot = ConsoleWorldEntityUnderMouse()
    local kitcoon = SpawnPrefab("kitcoon_deciduous")
    if not kitcoon.components.hideandseekhider:GoHide(hidingspot, 0) then
        kitcoon:Remove()
    end
end

function d_hidekitcoons()
    TheWorld.components.specialeventsetup:_SetupYearOfTheCatcoon()
end

function d_allkitcoons()
    local kitcoons =
    {
        "kitcoon_forest",
        "kitcoon_savanna",
        "kitcoon_deciduous",
        "kitcoon_marsh",
        "kitcoon_grass",
        "kitcoon_rocky",
        "kitcoon_desert",
        "kitcoon_moon",
        "kitcoon_yot",
    }

    d_spawnlist(kitcoons, 3, function(inst) inst._first_nuzzle = false end)
end

function d_allcustomhidingspots()
    local items = table.getkeys(TUNING.KITCOON_HIDING_OFFSET)
    d_spawnlist(items, 6, function(hidingspot)
        local kitcoon = SpawnPrefab("kitcoon_rocky")
        if not kitcoon.components.hideandseekhider:GoHide(hidingspot, 0) then
            kitcoon:Remove()
            hidingspot.AnimState:SetMultColour(1, 0, 0)
        end
    end)
end

function d_islandstart()
    c_give("log", 12)
    c_give("rocks", 12)
    c_give("smallmeat", 2)
    c_give("meat", 2)
    c_give("rope", 2)
    c_give("cutgrass", 9)
    c_give("backpack")
    c_give("charcoal", 9)
    c_give("carrot", 3)
    c_give("berries", 12)
    c_give("pickaxe")
    c_give("axe")
    c_give(PickSomeWithDups(1, {"strawhat", "minerhat", "flowerhat"})[1])
    c_give(PickSomeWithDups(1, {"spear", "hambat", "trap"})[1])

    local MainCharacter = ConsoleCommandPlayer()
    if MainCharacter ~= nil and MainCharacter.components.sanity ~= nil then
        MainCharacter.components.sanity:SetPercent(math.random() * 0.4 + 0.2)
    end

end

function d_waxwellworker()
    local player = ConsoleCommandPlayer()
    local x, y, z = player.Transform:GetWorldPosition()

    local pet = player.components.petleash:SpawnPetAt(x, y, z, "shadowworker")
    if pet ~= nil then
        pet.components.knownlocations:RememberLocation("spawn", pet:GetPosition(), true)
    end
end

function d_waxwellprotector()
    local player = ConsoleCommandPlayer()
    local x, y, z = player.Transform:GetWorldPosition()

    local pet = player.components.petleash:SpawnPetAt(x, y, z, "shadowprotector")
    if pet ~= nil then
        pet.components.knownlocations:RememberLocation("spawn", pet:GetPosition(), true)
    end
end

function d_boatitems()
    c_spawn("boat_item")
    c_spawn("mast_item", 3)
    c_spawn("anchor_item")
    c_spawn("steeringwheel_item")
    c_spawn("oar")
end

function d_giveturfs()
    local GroundTiles = require("worldtiledefs")
    for k, v in pairs(GroundTiles.turf) do
        c_give("turf_"..v.name)
    end
end

function d_turfs()
    local GroundTiles = require("worldtiledefs")

    local items = {}
    for k, v in pairs(GroundTiles.turf) do
        table.insert(items, {"turf_"..v.name, 10})
    end

    d_spawnlist(items)
end

function d_spawnlayout(name, offset)
    local obj_layout = require("map/object_layout")
    local entities = {}
    local map_width, map_height = TheWorld.Map:GetSize()
    local add_fn = {
        fn=function(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
        print("adding, ", prefab, points_x[current_pos_idx], points_y[current_pos_idx])
            local x = (points_x[current_pos_idx] - width/2.0)*TILE_SCALE
            local y = (points_y[current_pos_idx] - height/2.0)*TILE_SCALE
            x = math.floor(x*100)/100.0
            y = math.floor(y*100)/100.0
            SpawnPrefab(prefab).Transform:SetPosition(x, 0, y)
        end,
        args={entitiesOut=entities, width=map_width, height=map_height, rand_offset = false, debug_prefab_list=nil}
    }

    local x, y, z = ConsoleWorldPosition():Get()
    x, z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
    offset = offset or 3
    obj_layout.Place({math.floor(x) - 3, math.floor(z) - 3}, name, add_fn, nil, TheWorld.Map)
end

function d_allfish()

    local fish_defs = require("prefabs/oceanfishdef").fish
    local allfish = {"spoiled_fish", "fishmeat", "fishmeat_cooked", "fishmeat_small", "fishmeat_small_cooked"}

    local pt = ConsoleWorldPosition()
    local pst = TheWorld.Map:IsVisualGroundAtPoint(pt:Get()) and "_inv" or ""
    for k, _ in pairs(fish_defs) do
        table.insert(allfish, k .. pst)
    end

    local spacing = 2
    local num_wide = math.ceil(math.sqrt(#allfish))

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(allfish[(y*num_wide + x + 1)])
            if inst ~= nil then
                inst.Transform:SetPosition((pt + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_fishing()
    local items = {"oceanfishingbobber_ball", "oceanfishingbobber_oval",  "twigs", "trinket_8",
                     "oceanfishingbobber_crow", "oceanfishingbobber_robin", "oceanfishingbobber_robin_winter",  "oceanfishingbobber_canary",
                     "oceanfishingbobber_goose", "oceanfishingbobber_malbatross",
                     "oceanfishinglure_spinner_red", "oceanfishinglure_spinner_blue", "oceanfishinglure_spinner_green",
                     "oceanfishinglure_spoon_red", "oceanfishinglure_spoon_blue", "oceanfishinglure_spoon_green",
                    "oceanfishinglure_hermit_snow", "oceanfishinglure_hermit_rain", "oceanfishinglure_hermit_drowsy", "oceanfishinglure_hermit_heavy",
                     "berries", "butterflywings", "oceanfishingrod"}

    local spacing = 2
    local num_wide = math.ceil(math.sqrt(#items))

    local pt = ConsoleWorldPosition()

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(items[(y*num_wide + x + 1)])
            if inst ~= nil then
                inst.Transform:SetPosition((pt + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_tables()
    local items = {"table_winters_feast", "table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast",
                    "table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast",
                    "table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast",
                    "table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast","table_winters_feast",}

    local spacing = 1
    local num_wide = math.ceil(math.sqrt(#items))

    local pt = ConsoleWorldPosition()

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(items[(y*num_wide + x + 1)])
            if inst ~= nil then
                inst.Transform:SetPosition((pt + Vector3(x*spacing, 0, y*spacing)):Get())
            end
        end
    end
end

function d_gofishing()
    c_give("oceanfishingrod", 1)
    c_give("oceanfishingbobber_ball", 5)
    c_give("oceanfishingbobber_robin_winter", 5)
    c_give("oceanfishingbobber_malbatross", 5)
    c_give("oceanfishinglure_spinner_red", 5)
    c_give("oceanfishinglure_spinner_green", 5)
end

function d_radius(radius, num, lifetime)
    radius = radius or 4
    num = num or math.max(5, radius*2)
    lifetime = lifetime or 10
    local delta_theta = PI2 / num

    local pt = ConsoleWorldPosition()

    for i = 1, num do

        local p = SpawnPrefab("flint")
        p.Transform:SetPosition(pt.x + radius * math.cos( i*delta_theta ), 0, pt.z - radius * math.sin( i*delta_theta ))
        p:DoTaskInTime(lifetime, p.Remove)
    end
end

function d_ratracer(speed, stamina, direction, reaction)
    local rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.speed = speed or math.random(TUNING.RACE_STATS.MAX_STAT_VALUE + 1) - 1
    rat.components.yotc_racestats.stamina = stamina or math.random(TUNING.RACE_STATS.MAX_STAT_VALUE + 1) - 1
    rat.components.yotc_racestats.direction = direction or math.random(TUNING.RACE_STATS.MAX_STAT_VALUE + 1) - 1
    rat.components.yotc_racestats.reaction = reaction or math.random(TUNING.RACE_STATS.MAX_STAT_VALUE + 1) - 1
    rat:_setcolorfn("RANDOM")
    c_select(rat)
    ConsoleCommandPlayer().components.inventory:GiveItem(rat)
end

function d_ratracers()
    local MainCharacter = ConsoleCommandPlayer()
    local rat

    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.speed = TUNING.RACE_STATS.MAX_STAT_VALUE
    rat:_setcolorfn("white")
    MainCharacter.components.inventory:GiveItem(rat)
    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.speed = 0
    rat:_setcolorfn("yellow")
    MainCharacter.components.inventory:GiveItem(rat)

    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.stamina = TUNING.RACE_STATS.MAX_STAT_VALUE
    rat:_setcolorfn("green")
    MainCharacter.components.inventory:GiveItem(rat)
    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.stamina = 0
    rat:_setcolorfn("brown")
    MainCharacter.components.inventory:GiveItem(rat)

    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.direction = TUNING.RACE_STATS.MAX_STAT_VALUE
    rat:_setcolorfn("blue")
    MainCharacter.components.inventory:GiveItem(rat)
    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.direction = 0
    rat:_setcolorfn("NEUTRAL")
    MainCharacter.components.inventory:GiveItem(rat)

    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.reaction = TUNING.RACE_STATS.MAX_STAT_VALUE
    rat:_setcolorfn("purple")
    MainCharacter.components.inventory:GiveItem(rat)
    rat = DebugSpawn("carrat")
    rat._spread_stats_task:Cancel() rat._spread_stats_task = nil
    rat.components.yotc_racestats.reaction = 0
    rat:_setcolorfn("pink")
    MainCharacter.components.inventory:GiveItem(rat)
end

-- d_setup_placeholders( STRINGS.CHARACTERS.WARLY, "scripts\\speech_warly.lua" )
function d_setup_placeholders( reuse, out_file_name )
    local use_table = nil
    use_table = function( base_speech, reuse_speech )
        for k,v in pairs( base_speech ) do
            if type(v) == "string" then
                if reuse_speech ~= nil and reuse_speech[k] ~= nil then
                    --do nothing
                else
                    reuse_speech[k] = "TODO"
                end
            else
                --table
                if reuse_speech[k] == nil then
                    reuse_speech[k] = {}
                end
                use_table( base_speech[k], reuse_speech[k])
            end
        end
    end
    use_table( STRINGS.CHARACTERS.GENERIC, reuse )

    local out_file = io.open( out_file_name, "w")

    out_file:write("return {\n")

    local write_table = nil
    write_table = function( tbl, tabs )
        for k,v in orderedPairs(tbl) do
            for i=1,tabs do out_file:write("\t") end

            if type(v) == "string" then
                local out_v = string.gsub(v, "\n", "\\n")
                out_v = string.gsub(out_v, "\"", "\\\"")
                if type(k) == "string" then
                    out_file:write(k .. " = \"" .. out_v .. "\",\n")
                else
                    out_file:write("\"" .. out_v .. "\",\n")
                end
            else
                out_file:write(k .. " =\n")
                for i=1,tabs do out_file:write("\t") end
                out_file:write("{\n")

                write_table( tbl[k], tabs + 1 )

                for i=1,tabs do out_file:write("\t") end
                out_file:write("},\n")
            end
        end
    end

    write_table( reuse, 1 )

    out_file:write("}")
    out_file:close()
end

function d_allshells()
    local x, y, z = TheInput:GetWorldPosition():Get()
    for i=1, 12 do
        local shell=SpawnPrefab("singingshell_large")
        shell.Transform:SetPosition(x + i*2, 0, z)
        shell.components.cyclable:SetStep(i)
        local shell=SpawnPrefab("singingshell_medium")
        shell.Transform:SetPosition(x + i*2, 0, z + 6)
        shell.components.cyclable:SetStep(i)
        local shell=SpawnPrefab("singingshell_small")
        shell.Transform:SetPosition(x + i*2, 0, z + 12)
        shell.components.cyclable:SetStep(i)
    end
end


function d_fish(swim, r,g,b)
    local x, y, z = TheInput:GetWorldPosition():Get()

    local fish
    fish = c_spawn "oceanfish_medium_4"
    if not swim then
        fish:StopBrain()
        fish:SetBrain(nil)
    end
    fish.Transform:SetPosition(x, y, z)
    fish:RemoveTag("NOCLICK")

    fish = c_spawn "oceanfish_medium_3"
    if not swim then
        fish:StopBrain()
        fish:SetBrain(nil)
    end
    fish.Transform:SetPosition(x+2, y, z)
    fish:RemoveTag("NOCLICK")

    fish = c_spawn "oceanfish_medium_8"
    if not swim then
        fish:StopBrain()
        fish:SetBrain(nil)
    end
    fish.Transform:SetPosition(x, y, z+2)
    fish:RemoveTag("NOCLICK")


    fish = c_spawn "oceanfish_medium_3"
    if not swim then
        fish:StopBrain()
        fish:SetBrain(nil)
    end
    fish.Transform:SetPosition(x+2, y, z+2)
    fish:RemoveTag("NOCLICK")
    fish.AnimState:SetAddColour((r or 0)/255, (g or 5)/255, (b or 5)/255, 0)

end

function d_farmplants(grow_stage, oversized)
    local items = {}
    for k, v in pairs(require("prefabs/farm_plant_defs").PLANT_DEFS) do
        if v.product_oversized ~= nil then
            table.insert(items, v.prefab)
        end
    end

    d_spawnlist(items, 2.5,
        function(inst)
            if grow_stage ~= nil then
                for i = 1, grow_stage do
                    inst:DoTaskInTime((i-1) * 1 + math.random() * 0.5, function()
                            inst.components.growable:DoGrowth()
                    end)
                end
            end

            if oversized then
                inst.force_oversized = true
            end
        end)
end
function d_plant(plant, num_wide, grow_stage, spacing)
    spacing = spacing or 1.25

    local pt = ConsoleWorldPosition()
    pt.x = pt.x - num_wide * 0.5 * spacing
    pt.z = pt.z - num_wide * 0.5 * spacing

    for y = 0, num_wide-1 do
        for x = 0, num_wide-1 do
            local inst = SpawnPrefab(plant)
            if inst ~= nil then
                inst.Transform:SetPosition((pt + Vector3(x*spacing, 0, y*spacing)):Get())
                if grow_stage ~= nil then
                    for k = 1, grow_stage do
                        inst:DoTaskInTime(0.1 * k, function()
                            inst.components.growable:DoGrowth()
                        end)
                    end
                end
            end
        end
    end

end

function d_seeds()
    local items = {}
    for k, v in pairs(require("prefabs/farm_plant_defs").PLANT_DEFS) do
        if v.product_oversized ~= nil then
            table.insert(items, v.seed)
        end
    end
    d_spawnlist(items, 2)
end

function d_fertilizers()
    d_spawnlist(require("prefabs/fertilizer_nutrient_defs").SORTED_FERTILIZERS, 2)
end

function d_oversized()
    local items = {}
    for k, v in pairs(require("prefabs/farm_plant_defs").PLANT_DEFS) do
        if v.product_oversized ~= nil then
            table.insert(items, v.product_oversized)
            end
        end
    d_spawnlist(items, 3)
end

function d_startmoonstorm()
    local pt = ConsoleWorldPosition()
    TheWorld.components.moonstormmanager:StartMoonstorm(TheWorld.Map:GetNodeIdAtPoint(pt.x, pt.y, pt.z))
end

function d_stopmoonstorm()
    TheWorld.components.moonstormmanager:StopCurrentMoonstorm()
end

function d_moonaltars()
    local offset = 7
    local pos = TheInput:GetWorldPosition()
    local altar

    altar = SpawnPrefab("moon_altar")
    altar.Transform:SetPosition(pos.x, 0, pos.z - offset)
    altar:set_stage_fn(2)

    SpawnPrefab("moon_altar_idol").Transform:SetPosition(pos.x, 0, pos.z - offset - 2)

    altar = SpawnPrefab("moon_altar_astral")
    altar.Transform:SetPosition(pos.x - offset, 0, pos.z + offset / 3)
    altar:set_stage_fn(2)

    altar = SpawnPrefab("moon_altar_cosmic")
    altar.Transform:SetPosition(pos.x + offset, 0, pos.z + offset / 3)
end

function d_cookbook()
    TheCookbook.save_enabled = false

    local cooking = require("cooking")
    for cat, cookbook_recipes in pairs(cooking.cookbook_recipes) do
        for prefab, recipe_def in pairs(cookbook_recipes) do
            TheCookbook:LearnFoodStats(prefab)
            TheCookbook:AddRecipe(prefab, {"meat", "meat", "meat", "meat"})
            TheCookbook:AddRecipe(prefab, {"twigs", "berries", "ice", "meat"})
        end
    end
end

function d_statues(material)
    local mats =
    {
        "marble",
        "stone",
        "moonglass",
    }

    local items = {
        "pawn",
        "rook",
        "knight",
        "bishop",
        "muse",
        "formal",
        "hornucopia",
        "pipe",
        "deerclops",
        "bearger",
        "moosegoose",
        "dragonfly",
        "clayhound",
        "claywarg",
        "butterfly",
        "anchor",
        "moon",
        "carrat",
        "beefalo",
        "crabking",
        "malbatross",
        "toadstool",
        "stalker",
        "klaus",
        "beequeen",
        "antlion",
        "minotaur",
        "guardianphase3",
        "eyeofterror",
        "twinsofterror",
        "kitcoon",
        "catcoon",
    }

    local material = (type(material) == "string" and table.contains(mats, material)) and material
                    or type(material) == "number" and mats[material]
                    or "marble"

    for i, v in ipairs(items) do
        items[i] = "chesspiece_".. v .."_" .. (material or "marble")
    end
    d_spawnlist(items, 5)
end

function d_craftingstations()
    local prefabs = {}
    for k, _ in pairs(PROTOTYPER_DEFS) do
        table.insert(prefabs, k)
    end
    d_spawnlist(prefabs, 6)
end

function d_removeentitywithnetworkid(networkid, x, y, z)
    local ents = TheSim:FindEntities(x,y,z, 1)
    for i, ent in ipairs(ents) do
        if ent and ent.Network and ent.Network:GetNetworkID() == networkid then
            c_remove(ent)
            return
        end
    end
end


function d_recipecards()
    local items = {}

    local cards = require("cooking").recipe_cards
    for _, card in ipairs(cards) do
        table.insert(items, {"cookingrecipecard", 1, function(inst)
                inst.recipe_name = card.recipe_name
                inst.cooker_name = card.cooker_name
                inst.components.named:SetName(subfmt(STRINGS.NAMES.COOKINGRECIPECARD, { item = STRINGS.NAMES[string.upper(card.recipe_name)] or card.recipe_name }))
            end}
        )
    end

    d_spawnlist(items, 2)
end

function d_spawnfilelist(filename, spacing)
-- the file will need to be located in: \Documents\Klei\DoNotStarveTogether\<steam id>\client_save
-- the fileformat is one prefab per line

    local prefabs = {}

    TheSim:GetPersistentString(filename, function(success, str)
        if success and str ~= nil and #str > 0 then
            for prefab in str:gmatch("[^\r\n]+") do
                table.insert(prefabs, prefab)
            end
        else
            print("d_spawnfilelist failed:", filename, str, success)
        end
    end)

    d_spawnlist(prefabs, spacing)
end

function d_spawnallhats()
    d_spawnlist(ALL_HAT_PREFAB_NAMES)
end

local function spawn_mannequin_and_equip_item(item)
    local ix, iy, iz = item.Transform:GetWorldPosition()
    local stand = SpawnPrefab("sewing_mannequin")
    stand.Transform:SetPosition(ix, iy, iz)
    stand.components.inventory:Equip(item)
end

function d_spawnallhats_onstands()
    local all_hats = {"slurper"}
    for i = 1, #ALL_HAT_PREFAB_NAMES do
        table.insert(all_hats, ALL_HAT_PREFAB_NAMES[i])
    end
    d_spawnlist(all_hats, 3.5, spawn_mannequin_and_equip_item)
end

function d_spawnallarmor_onstands()
    local all_armor =
    {
        "amulet",
        "blueamulet",
        "purpleamulet",
        "orangeamulet",
        "greenamulet",
        "yellowamulet",
        "armor_bramble",
        "armordragonfly",
        "armorgrass",
        "armormarble",
        "armorruins",
        "armor_sanity",
        "armorskeleton",
        "armorslurper",
        "armorsnurtleshell",
        "armorwood",
        "backpack",
        "balloonvest",
        "beargervest",
        "candybag",
        "carnival_vest_a",
        "carnival_vest_b",
        "carnival_vest_c",
        "costume_doll_body",
        "costume_queen_body",
        "costume_king_body",
        "costume_blacksmith_body",
        "costume_mirror_body",
        "costume_tree_body",
        "costume_fool_body",
        "hawaiianshirt",
        "icepack",
        "krampus_sack",
        "onemanband",
        "piggyback",
        "potatosack",
        "raincoat",
        "reflectivevest",
        "seedpouch",
        "spicepack",
        "sweatervest",
        "trunkvest_summer",
        "trunkvest_winter",
    }

    d_spawnlist(all_armor, 3.5, spawn_mannequin_and_equip_item)
end

function d_spawnallhandequipment_onstands()
    local all_hand_equipment =
    {
        "multitool_axe_pickaxe",
        "axe",
        "goldenaxe",
        "balloon",
        "balloonparty",
        "balloonspeed",
        "batbat",
        "bernie_inactive",
        "blowdart_sleep",
        "blowdart_fire",
        "blowdart_pipe",
        "blowdart_yellow",
        "blowdart_walrus",
        "boomerang",
        "brush",
        "bugnet",
        "bullkelp_root",
        "cane",
        "carnivalgame_feedchicks_food",
        "chum",
        "compass",
        "cutless",
        "diviningrod",
        "dumbbell",
        "dumbbell_golden",
        "dumbbell_marble",
        "dumbbell_gem",
        "farm_hoe",
        "golden_farm_hoe",
        "fence_rotator",
        "firepen",
        "fishingnet",
        "fishingrod",
        "glasscutter",
        "gnarwail_horn",
        "hambat",
        "hammer",
        "lighter",
        "lucy",
        "messagebottle_throwable",
        "minifan",
        "lantern",
        "nightstick",
        "nightsword",
        "oar",
        "oar_driftwood",
        "oar_monkey",
        "malbatross_beak",
        "oceanfishingrod",
        "pickaxe",
        "goldenpickaxe",
        "pitchfork",
        "pocketwatch_weapon",
        "propsign",
        "redlantern",
        "reskin_tool",
        "ruins_bat",
        "saddlehorn",
        "shieldofterror",
        "shovel",
        "goldenshovel",
        "sleepbomb",
        "slingshot",
        "spear_wathgrithr",
        "spear",
        "staff_tornado",
        "icestaff",
        "firestaff",
        "telestaff",
        "orangestaff",
        "greenstaff",
        "yellowstaff",
        "opalstaff",
        "tentaclespike",
        "thurible",
        "torch",
        "trident",
        "umbrella",
        "grass_umbrella",
        "wateringcan",
        "premiumwateringcan",
        "waterplant_bomb",
        "waterballoon",
        "whip",
    }

    d_spawnlist(all_hand_equipment, 3.5, spawn_mannequin_and_equip_item)
end

function d_allpillows()
    local all_pillow_equipment = {}
    for material in pairs(require("prefabs/pillow_defs")) do
        table.insert(all_pillow_equipment, "handpillow_"..material)
        table.insert(all_pillow_equipment, "bodypillow_"..material)
    end

    d_spawnlist(all_pillow_equipment, 3.5)
end

function d_allpillows_onstands()
    local all_pillow_equipment = {}
    for material in pairs(require("prefabs/pillow_defs")) do
        table.insert(all_pillow_equipment, "handpillow_"..material)
        table.insert(all_pillow_equipment, "bodypillow_"..material)
    end

    d_spawnlist(all_pillow_equipment, 3.5, spawn_mannequin_and_equip_item)
end

function d_spawnequipment_onstand(...)
    if arg == nil or #arg == 0 then return end

    local stand = SpawnPrefab("sewing_mannequin")
    stand.Transform:SetPosition(ConsoleWorldPosition():Get())

    for _, item in ipairs(arg) do
        stand.components.inventory:Equip(SpawnPrefab(item))
    end
end

--@V2C #TODO: #DELETEME
function d_daywalker(chain)
    local daywalker = c_spawn("daywalker")
    local x, y, z = daywalker.Transform:GetWorldPosition()
    local radius = 6
    local num = 3
    for i = 1, num do
        local theta = i * TWOPI / num + PI * 3 / 4
        local pillar = c_spawn("daywalker_pillar")
        pillar.Transform:SetPosition(
            x + math.cos(theta) * radius,
            0,
            z - math.sin(theta) * radius
        )
        if chain then
            pillar:SetPrisoner(daywalker)
        end
    end

    c_select(daywalker)
end

function d_moonplant()
    if c_sel() then
        TheWorld.components.lunarthrall_plantspawner:SpawnPlant(c_sel())
    end
end

function d_punchingbags()
    local punchingbag_list = {"punchingbag", "punchingbag_lunar", "punchingbag_shadow"}
    d_spawnlist(punchingbag_list, 3.0)
end

local skiplist = {}
skiplist["blossom_hit_fx"] = true
skiplist["quagmire_parkspike"] = true
skiplist["quagmire_spotspice_shrub"] = true
skiplist["lavaarena_elemental"] = true
skiplist["lavaarena"] = true
skiplist["fireball_hit_fx"] = true
skiplist["quagmire_coin_fx"] = true
skiplist["lavaarena_spectator"] = true
skiplist["global"] = true
skiplist["audio_test_prefab"] = true
skiplist["peghook_hitfx"] = true
skiplist["quagmire_coin4"] = true
skiplist["quagmire_food"] = true
skiplist["lavaarena_boarlord"] = true
skiplist["quagmire"] = true
skiplist["world"] = true
skiplist["shard_network"] = true
skiplist["cave_network"] = true
skiplist["cave"] = true
skiplist["gooball_hit_fx"] = true
skiplist["forest_network"] = true
skiplist["peghook_splashfx"] = true
skiplist["quagmire_network"] = true
skiplist["lavaarena_network"] = true
skiplist["quagmire_mushroomstump"] = true
skiplist["forest"] = true
skiplist["quagmire_parkspike_short"] = true
skiplist["reticulearc"] = true
skiplist["reticuleline"] = true
skiplist["reticulelong"] = true
skiplist["reticuleaoe"] = true
skiplist["reticule"] = true

function d_dumpCreatureTXT()

    local f = io.open("creatures.txt", "w")
    local total = 0
    local str = ""
    if f then
       --"PREFAB","NAME", "HEALTH", "DAMAGE"
       str = str .. string.format("%s;%s;%s;%s\n", "PREFAB","NAME", "HEALTH", "DAMAGE")
        for i,data in pairs(Prefabs)do
            print("=====>",i)
           -- dumptable(data,1,1)
            if not data.base_prefab and not skiplist[i] then -- not a skin
                local t = SpawnPrefab(i)
                if t and t.components.health then
                --if t and (t:HasTag("smallcreature") or t:HasTag("monster") or t:HasTag("animal")) then

                    local name = t.name or "---"
                    local health = t.components.health and t.components.health.maxhealth or 0
                    local damage = t.components.combat and t.components.combat.defaultdamage or 0

                    str = str .. string.format("%s;%s;%s;%s\n", i,name, tostring(health), tostring(damage))
                end
                t:Remove()
                total = total + 1
            else
                print("Skipping")
            end
        end

        f:write(str)
    end
end
function d_dumpItemsTXT()

    local f = io.open("items.txt", "w")
    local total = 0
    local str = ""
    if f then
        for i,data in pairs(Prefabs)do
            if not data.base_prefab and not skiplist[i] then -- not a skin
                local t = SpawnPrefab(i)
                if t and t.components.inventoryitem then
                    str = str..'["'..t.prefab..'"]=true,\n'
                end
                t:Remove()
            end
        end
        --[[
        str = str .. string.format("%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n","PREFAB","NAME","STACKSIZE","DURABILITY","SPOILTIME","FOOD-HEALTH","FOOD-HUNGER","FOOD-SANITY","DAMAGE","PLANAR DAMAGE","ARMOR-%","ARMOR-HEALTH")
        for i,data in pairs(Prefabs)do
            print("=====>",i)
           -- dumptable(data,1,1)
            if not data.base_prefab and not skiplist[i] then -- not a skin
                local t = SpawnPrefab(i)
                if t and t.components.inventoryitem then
                --if t and (t:HasTag("smallcreature") or t:HasTag("monster") or t:HasTag("animal")) then

                    local name = t.name or "---"
                    local stack = t.components.stackable and t.components.stackable.maxsize or 1
                    local durability = t.components.finiteuses and t.components.finiteuses.total or 0
                    local spoiltime = t.components.perishable and t.components.perishable.perishtime or 0

                    local food_health = t.components.edible and t.components.edible.healthvalue or "-"
                    local food_hunger = t.components.edible and t.components.edible.hungervalue or "-"
                    local food_sanity = t.components.edible and t.components.edible.sanityvalue or "-"

                    local weapondamage = t.components.weapon and t.components.weapon.damage or "-"
                    local planardamage = t.components.planardamage and t.components.planardamage.basedamage or "-"
                    local absorb_percent = t.components.armor and t.components.armor.absorb_percent or "-"
                    local condition =    t.components.armor and t.components.armor.condition or "-"

                    str = str .. string.format("%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n", i,name, tostring(stack), tostring(durability), tostring(spoiltime),
                        tostring(food_health), tostring(food_hunger), tostring(food_sanity),
                        tostring(weapondamage), tostring(planardamage), tostring(absorb_percent), tostring(condition)
                        )
                end
                t:Remove()
                total = total + 1
            else
                print("Skipping")
            end
        end
    ]]
        f:write(str)
    end
end

function d_structuresTXT()

    local f = io.open("structures.txt", "w")
    local total = 0
    local str = ""
    if f then
        str = str .. string.format("%s;%s\n","PREFAB","NAME")
        for i,data in pairs(Prefabs)do
            print("=====>",i)
           -- dumptable(data,1,1)
            if not data.base_prefab and not skiplist[i] then -- not a skin
                local t = SpawnPrefab(i)
                if t and not t.components.inventoryitem and not t.components.locomotor and not t:HasTag("fx") then

                --if t and (t:HasTag("smallcreature") or t:HasTag("monster") or t:HasTag("animal")) then

                    local name = t.name or "---"

                    str = str .. string.format("%s;%s\n", i,name)
                end
                t:Remove()
                total = total + 1
            else
                print("Skipping")
            end
        end

        f:write(str)
    end
end

--------------------------------------------------------------------------------------------------------------------

local RECIPE_BUILDER_TAG_LOOKUP = {
    alchemist = "wilson",
    balloonomancer = "wes",
    battlesinger = "wathgrithr",
    bookbuilder = "wickerbottom",
    clockmaker = "wanda",
    elixirbrewer = "wendy",
    gem_alchemistI = "wilson",
    gem_alchemistII = "wilson",
    gem_alchemistIII = "wilson",
    ghostlyfriend = "wendy",
    handyperson = "winona",
    ick_alchemistI = "wilson",
    ick_alchemistII = "wilson",
    ick_alchemistIII = "wilson",
    leifidolcrafter = "woodie",
    masterchef = "warly",
    merm_builder = "wurt",
    ore_alchemistI = "wilson",
    ore_alchemistII = "wilson",
    ore_alchemistIII = "wilson",
    pebblemaker = "walter",
    pinetreepioneer = "walter",
    plantkin = "wormwood",
    saplingcrafter = "wormwood",
    berrybushcrafter = "wormwood",
    juicyberrybushcrafter = "wormwood",
    reedscrafter = "wormwood",
    lureplantcrafter = "wormwood",
    syrupcrafter = "wormwood",
    carratcrafter = "wormwood",
    lightfliercrafter = "wormwood",
    fruitdragoncrafter = "wormwood",
    professionalchef = "warly",
    pyromaniac = "willow",
    shadowmagic = "waxwell",
    skill_wilson_allegiance_lunar = "wilson",
    skill_wilson_allegiance_shadow = "wilson",
    spiderwhisperer = "webber",
    strongman = "wolfgang",
    syrupcrafter = "wormwood",
    upgrademoduleowner = "wx78",
    valkyrie = "wathgrithr",
    werehuman = "woodie",
    wolfgang_coach = "wolfgang",
    wolfgang_dumbbell_crafting = "wolfgang",
    woodcarver1 = "woodie",
    woodcarver2 = "woodie",
    woodcarver3 = "woodie",
}


local function WriteScrapBookInfo(file, key, value)
    assert( checkstring(key), string.format("Parameter [key] must be of type string, and it's [%s].", type(key)) )

    file:write(string.format(' %s=%s,', key, checkstring(value) and '"'..value..'"' or tostring(value)))
end


local scrapbookprefabs = require("scrapbook_prefabs")
function d_createscrapbookdata(should_print)
    should_print = should_print == nil and true or should_print

    local function _print(...)
        if should_print then
            print(...)
        end
    end

    local exporter_data_helper = io.open("scripts/scrapbookdata_no_package.lua", "w")
    exporter_data_helper:write("-- AUTOGENERATED FROM d_createscrapbookdata()\n")
    exporter_data_helper:write("return {\n")

    local f = io.open("scripts/screens/redux/scrapbookdata.lua", "w")

    local WriteInfo = function(...) WriteScrapBookInfo(f, ...) end

    if f then
    f:write("local data = {\n")

        for i, data in pairs(scrapbookprefabs) do
            _print("=====>",i)
            local t = SpawnPrefab(i)
            t.Transform:SetRotation(90)
            ---------------------------------------------
            ------------------------------------------NAME
            local name = t.nameoverride or (t.components.inspectable and t.components.inspectable.nameoverride and t.components.inspectable.nameoverride) or t.prefab

            if t:HasTag("farm_plant") then
                name = t.prefab
            end

            if name == "moose" then
                name = "moose1"
            end

            if t.prefab == "mooseegg" then
                name = "mooseegg1"
            end

            if t.prefab == "rock_flintless" then
                name = "rock_flintless"
            end

            if t.prefab == "lunarrift_crystal_big" then
                name = "lunarrift_crystal_big"
            end

            if t.prefab == "lunarrift_crystal_small" then
                name = "lunarrift_crystal_small"
            end

            if t.prefab == "ruins_cavein_obstacle" then
                name = "ruins_cavein_obstacle"
            end

            if t.prefab == "archive_moon_statue" then
                name = "archive_moon_statue"
            end

            if t.prefab == "rock_petrified_tree" then
                name = "rock_petrified_tree"
            end

            if t.prefab == "halloweenpotion_bravery_small" then
                name = "halloweenpotion_bravery_small"
            end
            if t.prefab == "halloweenpotion_sparks" then
                name = "halloweenpotion_sparks"
            end
            if t.prefab == "halloweenpotion_embers" then
                name = "halloweenpotion_embers"
            end
            if t.prefab == "halloweenpotion_sanity_small" then
                name = "halloweenpotion_sanity_small"
            end
            if t.prefab == "halloweenpotion_health_small" then
                name = "halloweenpotion_health_small"
            end
            if t.prefab == "halloweenpotion_sanity_large" then
                name = "halloweenpotion_sanity_large"
            end
            if t.prefab == "halloweenpotion_health_large" then
                name = "halloweenpotion_health_large"
            end
            if t.prefab == "halloweenpotion_bravery_large" then
                name = "halloweenpotion_bravery_large"
            end

            if t.prefab == "multiplayer_portal_moonrock" then
                name = "multiplayer_portal_moonrock"
            end
            if t.prefab == "multiplayer_portal_moonrock_constr_plans" then
                name = "multiplayer_portal_moonrock_constr_plans"
            end

            if t.prefab == "rock1" then
                name = "rock1"
            end

            if name == "wall_stone_2_item" then
                name = "wall_stone_2"
            end

            ---------------------------------------------
            --------------------------------------- SUBCATS
            local subcat = "nil"

            if t:HasTag("insect") then
                subcat = '"insect"'
            end

            if t:HasTag("spider") then
                subcat = '"spider"'
            end
            if t:HasTag("halloween_ornament") then
                subcat = '"HalloweenOrnament"'
            end

            if t.components.upgrademodule then
                subcat = '"UpgradeModule"'
            end

            if string.find(t.prefab,"trinket") then
                subcat = '"Trinket"'
            end

            if t:HasTag("winter_ornament") then
                subcat = '"Ornament"'
            end

            if t:HasTag("book") then
                subcat = '"Book"'
            end

            if t:HasTag("shadow") then
                subcat = '"Shadow"'
            end

            if t.components.oceanfishingtackle then
                subcat = '"Tackle"'
            end

            if t:HasTag("hat") then
                subcat = '"Hat"'
            end

            if t.components.equippable and t.components.equippable.equipslot == EQUIPSLOTS.BODY and not t:HasTag("heavy")then
                subcat = '"Clothing"'
            end

            if t.pieceid then
                subcat = '"Statue"'
            end

            if t.components.armor or t.prefab == "armorskeleton" then
                subcat = '"Armor"'
            end

            if t.components.edible then
                if t.components.edible.foodtype ~= FOODTYPE.GENERIC and
                    t.components.edible.foodtype ~= FOODTYPE.GOODIES and
                    t.components.edible.foodtype ~= FOODTYPE.MEAT and
                    t.components.edible.foodtype ~= FOODTYPE.VEGGIE and
                    t.components.edible.foodtype ~= FOODTYPE.HORRIBLE and
                    t.components.edible.foodtype ~= FOODTYPE.INSECT and
                    t.components.edible.foodtype ~= FOODTYPE.SEEDS and
                    t.components.edible.foodtype ~= FOODTYPE.RAW and
                    t.components.edible.foodtype ~= FOODTYPE.BERRY then
                    subcat = '"Element"'
                end
            end

            if t:HasTag("spidermutator") then
                subcat = '"Mutator"'
            end

            if t.components.weapon or t.scrapbook_subcat == "weapon"  then
                subcat = '"Weapon"'
            end

            if t.components.tool or t.scrapbook_subcat == "tool" then
                subcat = '"Tool"'
            end

            if t:HasTag("farm_plant") then
                subcat = '"FarmPlant"'
            end

            if t:HasTag("ghostlyelixir") then
                subcat = '"Elixer"'
            end

            if t:HasTag("battlesong") then
                subcat = '"Battlesong"'
            end

            if t:HasTag("chest") then
                subcat = '"Container"'
            end

            if t:HasTag("wallbuilder") then
                subcat = '"Wall"'
            end

            if t:HasTag("groundtile") then
                subcat = '"Turf"'
            end

            if t:HasTag("pocketwatch") then
                subcat = '"Pocketwatch"'
            end

            if t:HasTag("wagstafftool") then
                subcat = '"wagstafftool"'
            end

            if t:HasTag("oceanfish") then
                subcat = '"oceanfish"'
            end

            if t:HasTag("chess") then
                subcat = '"clockwork"'
            end

            if t:HasTag("hound") then
                subcat = '"hound"'
            end

            if t:HasTag("merm") then
                subcat = '"merm"'
            end

            if t:HasTag("pig") and not t:HasTag("manrabbit") then
                subcat = '"pig"'
            end

            if t:HasTag("bird") then
                subcat = '"bird"'
            end

            if t:HasTag("singingshell") then
                subcat = '"shell"'
            end

            --------------------------------------------
            ------------------------------------ TYPE
            local thingtype = "thing"
            if t.components.inventoryitem and not t.components.health then
                thingtype = "item"
            end

            if  not t:HasTag("structure") and
                not t:HasTag("farm_plant") and
                not t:HasTag("tree") and
                not t:HasTag("plant") and
                not t:HasTag("moonstorm_static") and
                not t:HasTag("wall") and
                not t:HasTag("boatbumper") and
                not t:HasTag("groundspike") and
                t.prefab ~= "hedgehound_bush" and
                not t:HasTag("smashable") and
                not t:HasTag("boat") and
                t.prefab ~= "eyeturret" and
                t.prefab ~= "spiderhole" and
                t.prefab ~= "slurtlehole" and
                t.components.health then
                thingtype = "creature"
            end

            if t.prefab == "fused_shadeling_bomb" or
               t.prefab == "smallghost" or
               t.prefab == "stagehand" then
                thingtype = "creature"
            end

            if t.prefab == "pumpkin_lantern" then
                thingtype = "thing"
            end

            if i == "balloonvest" or i == "balloonhat"  or i == "balloonspeed" then
                thingtype = "item"
            end

            if t:HasTag("epic") or t:HasTag("crabking") or t.prefab == "shadow_rook" or t.prefab == "shadow_bishop" or t.prefab == "shadow_knight" then
                thingtype = "giant"
            end

            if t.scrapbook_thingtype then
                thingtype = t.scrapbook_thingtype
            end

            if t.components.edible then
                if t.components.edible.foodtype == FOODTYPE.GENERIC or
                    t.components.edible.foodtype == FOODTYPE.GOODIES or
                    t.components.edible.foodtype == FOODTYPE.MEAT or
                    t.components.edible.foodtype == FOODTYPE.VEGGIE or
                    t.components.edible.foodtype == FOODTYPE.HORRIBLE or
                    t.components.edible.foodtype == FOODTYPE.INSECT or
                    t.components.edible.foodtype == FOODTYPE.SEEDS or
                    t.components.edible.foodtype == FOODTYPE.RAW or
                    t.components.edible.foodtype == FOODTYPE.BERRY then
                    thingtype = "food"
                end
            end

            ---------------------------------------
            ---------------------------------- TEX
            local tex = i

            if t.components.inventoryitem and t.components.inventoryitem.imagename then
                tex = t.components.inventoryitem.imagename
            end

            if t.prefab == "balloon" then
                tex = "balloon_8"
            end

           -- NOTES(JBK): The hash is redundant data and is only here to aid the exporter for backend services.
           -- So we will save it to a file that does not get loaded for the game.
           exporter_data_helper:write(string.format("[\"%s\"] = 0x%X,\n", i, hash(i)))
           -- str = str ..
            f:write(string.format('["%s"] = {name="%s", tex="%s.tex", subcat=%s, type="%s", prefab="%s",', i, name, tex, subcat, thingtype, t.prefab))


            ------------------------------------
            ------------------------------- SPEECHNAME

            if t.nameoverride then
                local speechname = t.nameoverride
                WriteInfo( "speechname",   speechname )
            end

            --------------------------------------
            ---------------------------------- SANITY

            local getsanity = function(inst)
                local sanity = inst.components.sanityaura.aura
                if inst.components.sanityaura.aurafn then
                    sanity = inst.components.sanityaura.aurafn(inst,ThePlayer)
                end
                if inst:HasTag("brightmareboss") or inst:HasTag("brightmare_guard") then
                    sanity = sanity *-1
                end
                return sanity
            end

            if t.components.sanityaura and getsanity(t) then
                WriteInfo( "sanityaura", getsanity(t) )
            end

            --------------------------------------
            ---------------------------------- HEALTH
            if t.components.health then
                WriteInfo( "health", (t.scrapbook_maxhealth or t.components.health.maxhealth) )
            end

            --------------------------------------
            ---------------------------------- DAMAGE
            if t.scrapbook_damage then
                WriteInfo( "damage", t.scrapbook_damage )
            elseif  t.components.combat and t.components.combat.defaultdamage then
                WriteInfo( "damage", t.components.combat.defaultdamage )
            end

            --------------------------------------
            ---------------------------------- STACK
            if t.components.stackable  then
                local stacksize = t.components.stackable.maxsize
                if t.prefab == "wortox_soul" then
                    stacksize = TUNING.WORTOX_MAX_SOULS
                end
                WriteInfo( "stacksize", stacksize )
            end

            --------------------------------------
            ---------------------------------- FOOD
            if t.components.edible  then
                local substr = ' hungervalue='..  (t.scrapbook_hungervalue or t.components.edible.hungervalue) ..','
                substr= substr..' healthvalue='.. (t.scrapbook_healthvalue or t.components.edible.healthvalue) ..','
                substr= substr..' sanityvalue='.. (t.scrapbook_sanityvalue or t.components.edible.sanityvalue) ..','
                f:write(substr)
            end

            if t.components.edible and t.components.edible.foodtype  then
                WriteInfo( "foodtype",   t.components.edible.foodtype )
            end

            --------------------------------------
            ---------------------------------- WEAPON
            if t.components.weapon or t.scrapbook_weapondamage then
                if t.prefab == "bomb_lunarplant" then
                    substr=' weapondamage='..  t.components.weapon.damage ..','
                    substr=substr..' planardamage='..  TUNING.BOMB_LUNARPLANT_PLANAR_DAMAGE ..','
                    substr=substr..' weaponrange='..  t.components.weapon.hitrange ..','
                    f:write(substr)
                else
                    if t.scrapbook_weapondamage or t.components.weapon and t.components.weapon.damage then

                        local weapondamage = t.scrapbook_weapondamage

                        if not weapondamage and type(t.components.weapon.damage) == "function" then
                            _print("FUNCTION",t.prefab)
                        else
                            if not weapondamage and t.components.weapon.damage then
                               weapondamage = t.components.weapon.damage
                            end
                            WriteInfo( "weapondamage", weapondamage )
                        end
                    end

                    local planardamage = t.scrapbook_planardamage or  t.components.planardamage and t.components.planardamage.basedamage
                    if planardamage then
                        WriteInfo( "planardamage", planardamage )
                    end

                    if t.components.weapon and t.components.weapon.hitrange then
                        WriteInfo( "weaponrange", t.components.weapon.hitrange )
                    end
                end
            end

            --------------------------------------
            ---------------------------------- ARMOR
            if t.components.armor then
                WriteInfo( "armor", t.components.armor.maxcondition )
                WriteInfo( "absorb_percent", t.components.armor.absorb_percent )

                if t.components.planardefense then
                    WriteInfo( "planardamage", t.components.planardefense.basedefense )
                end
            end

            --------------------------------------
            ---------------------------------- TOOL

            if t.components.finiteuses  then
                -- FIXME(JBK): This is a bad assumption for tools that have multiple uses with different use rates but will fix up most cases.
                local count = 0
                for _ in pairs(t.components.finiteuses.consumption) do
                    count = count + 1
                end
                local rate = 1
                if count == 1 then -- Only apply the modifier for if there is one consumer type.
                    local k, v = next(t.components.finiteuses.consumption)
                    rate = v
                end
                WriteInfo( "finiteuses", (t.components.finiteuses.total / rate) )
            end

            if t.components.tool then
                f:write(' toolactions={')
                for i, data in pairs(t.components.tool.actions) do
                    f:write('"'..i.id..'",')
                end
                f:write('},')
            end

            ---------------------------------------
            ---------------------------------- ANIMATION DATA
            if t.sg then
                t.sg:GoToState("idle")
            end

            local anim = "idle"
            _print("-------------",t.prefab)
            if t.AnimState:IsCurrentAnimation("anim") then
                anim = "anim"
            end

            if t.AnimState:IsCurrentAnimation("fly_loop") then
                anim = "fly_loop"
            end

            if t.AnimState:IsCurrentAnimation("cooked") then
                anim = "cooked"
            end

            if t.AnimState:IsCurrentAnimation("idle1") or
                t.AnimState:IsCurrentAnimation("idle2") or
                t.AnimState:IsCurrentAnimation("idle3")or
                t.AnimState:IsCurrentAnimation("idle4")or
                t.AnimState:IsCurrentAnimation("idle5")or
                t.AnimState:IsCurrentAnimation("idle6")or
                t.AnimState:IsCurrentAnimation("idle7")or
                t.AnimState:IsCurrentAnimation("idle8")or
                t.AnimState:IsCurrentAnimation("idle9")or
                t.AnimState:IsCurrentAnimation("idle10")then
                anim = "idle1"
            end

            if t.prefab =="squid" or t.prefab =="lightcrab" then
                anim = "idle"
            end


            if t.AnimState:IsCurrentAnimation("idle_sit") then
                anim = "idle_sit"
            end

            if t.AnimState:IsCurrentAnimation("idle_med") or t.AnimState:IsCurrentAnimation("idle_tall") or t.AnimState:IsCurrentAnimation("idle_short")then
                anim = "idle_med"
            end

            if t.AnimState:IsCurrentAnimation("idle_loop") then
                anim = "idle_loop"
            end

            if t.AnimState:IsCurrentAnimation("pack_loop") then
                anim = "pack_loop"
            end

            if t.AnimState:IsCurrentAnimation("rotten") then
                anim = "rotten"
            end

            if t.AnimState:IsCurrentAnimation("f1") or
                t.AnimState:IsCurrentAnimation("f2") or
                t.AnimState:IsCurrentAnimation("f3") then
                anim = "f1"
            end

            if t.prefab == "abigail_flower" then
                anim = "level3_loop"
            end

            if t:HasTag("battlesong") then
                anim = t.prefab
            end

            if t.prefab == "dug_bananabush" then
                anim = "idle_big"
            end

            if t.winter_ornamentid then
                anim = t.winter_ornamentid
            end

            if t.winter_ornamentid and t:HasTag("lightbattery") then
               anim = t.winter_ornamentid .. "_on"
            end

            if t:HasTag("tree") and t.prefab ~= "livingtree" and t.prefab ~= "marsh_tree" and t.prefab ~= "oceantree" then
                anim = "idle_tall"
            end

            if t.prefab == "lunar_forge_kit" then
                anim = "kit"
            end

            if t.prefab == "shadow_forge_kit" then
                anim = "kit"
            end

            if t.AnimState:IsCurrentAnimation("idle_cooked") then
                anim = "idle_cooked"
            end
            if t.AnimState:IsCurrentAnimation("idle_dead") then
                anim = "idle_dead"
            end

            if t.scrapbook_anim then
                anim = t.scrapbook_anim
            end

            ----------------------- BUILD

            local build = t.AnimState:GetBuild()
            if t.winter_ornament_build then
                build = t.winter_ornament_build
            end

            if t.scrapbook_scale then
                WriteInfo( "scrapbook_scale", t.scrapbook_scale )
            end

            if t.scrapbook_setanim then
                WriteInfo( "scrapbook_setanim", t.scrapbook_setanim )
            end

            if t.scrapbook_overridebuild then
                WriteInfo( "scrapbook_overridebuild", t.scrapbook_overridebuild )
            end

            if t.scrapbook_hide then
                f:write(' scrapbook_hide={')
                for h,hide in ipairs(t.scrapbook_hide) do
                    f:write('"'.. hide.. '",')
                end
                f:write('},')
            end

            _print("PREFAB:",t.prefab,i)

            WriteInfo( "build", build )
            WriteInfo( "bank",  t.AnimState:GetCurrentBankName() )
            WriteInfo( "anim",  anim )


            if t.scrapbook_overridedata then
                if type(t.scrapbook_overridedata[1]) ~= "table" then
                    f:write(' overridesymbol={"'..t.scrapbook_overridedata[1]..'","'..t.scrapbook_overridedata[2]..'","'..t.scrapbook_overridedata[3]..'"},')
                else
                    f:write(' overridesymbol={')
                    for od,odset in ipairs(t.scrapbook_overridedata) do
                       f:write('{"'.. odset[1] ..'","'.. odset[2] ..'","'.. odset[3] ..'"},')
                    end
                    f:write('},')
                end
            end

            if t.prefab == "robin" then
                WriteInfo( "animoffsety",  -8 )
            end
            if t.prefab == "robin_winter" then
                WriteInfo( "animoffsety",  -15 )
                WriteInfo( "animoffsetbgy",  15 )
            end
            if t.prefab == "friendlyfruitfly" then
                WriteInfo( "animoffsety",  65 )
            end
            if t.prefab == "fruitfly" then
                WriteInfo( "animoffsety",  65 )
            end
            -------------------
            if t.prefab == "minotaur" then
                WriteInfo( "animoffsetx",  5 )
            end
            if t.prefab == "lordfruitfly" then
                WriteInfo( "animoffsety",  70 )
            end
            if t.prefab == "moonbutterfly" then
                WriteInfo( "animoffsetx",  15 )
            end
            if t.prefab == "bee" then
                WriteInfo( "animoffsety",  150 )
            end
            if t.prefab == "killerbee" then
                WriteInfo( "animoffsety",  150 )
            end
            if t.prefab == "lightflier" then
                WriteInfo( "animoffsety",  70 )
            end
            if t.prefab == "beeguard" then
                WriteInfo( "animoffsety",  100 )
            end
            if t.prefab == "mosquito" then
                WriteInfo( "animoffsety",  100 )
                WriteInfo( "animoffsetx",  -20 )
            end
            if t.prefab == "moon_altar_seed" then
                WriteInfo( "animoffsety",  20 )
                WriteInfo( "animoffsetx",  25 )
            end
            if t.prefab == "moon_altar_glass" then
                WriteInfo( "animoffsety",  20 )
                WriteInfo( "animoffsetx",  25 )
            end
            if t.prefab == "moon_altar_icon" then
                WriteInfo( "animoffsety",  25 )
                WriteInfo( "animoffsetx",  25 )
            end
            if t.prefab == "moon_altar_ward" then
                WriteInfo( "animoffsety",  20 )
                WriteInfo( "animoffsetx",  25 )
            end
            if t.prefab == "moon_altar_crown" then
                WriteInfo( "animoffsety",  -20 )
                WriteInfo( "animoffsetx",  25 )
                WriteInfo( "animoffsetbgy",  30 )
            end
            if t.prefab == "shroomcake" then
                WriteInfo( "animoffsety",  -20 )
                WriteInfo( "animoffsetbgy",  25 )
            end
            if t.prefab == "vegstinger" then
                WriteInfo( "animoffsety",  -10 )
            end
            if t.prefab == "watermelon_oversized" then
                WriteInfo( "animoffsety",  -20 )
                WriteInfo( "animoffsetbgy",  30 )
            end
            if t.prefab == "spore_small" then
                WriteInfo( "animoffsety",  50 )
            end
            if t.prefab == "spore_medium" then
                WriteInfo( "animoffsety",  140 )
            end
            if t.prefab == "spore_tall" then
                WriteInfo( "animoffsety",  130 )
                WriteInfo( "animoffsetx",  -5 )
            end
            if t.prefab == "moonstorm_spark" then
                WriteInfo( "animoffsety",  40 )
                WriteInfo( "animoffsetx",  15 )
            end
            if t.prefab == "saddle_war" then
                WriteInfo( "animoffsety",  -20 )
                WriteInfo( "animoffsetbgy",  30 )
            end
            if t.prefab == "bunnyman" then
                WriteInfo( "animoffsetx",  20 )
            end
            if t.prefab == "bernie_active" then
                WriteInfo( "animoffsety",  60 )
                WriteInfo( "animoffsetbgy",  -50 )
            end
            if t.prefab == "lightcrab" then
                WriteInfo( "animoffsety",  60 )
                WriteInfo( "animoffsetbgy",  -50 )
            end
            if t.prefab == "fused_shadeling_bomb" then
                WriteInfo( "animoffsety",  60 )
                WriteInfo( "animoffsetbgy",  -50 )
            end
            if t.prefab == "smallghost" then
                WriteInfo( "animoffsety",  60 )
            end
            if t.prefab == "wx78_scanner_item" then
                WriteInfo( "animoffsety",  90 )
            end
            if t.prefab == "eyeofterror_mini" then
                WriteInfo( "animoffsety",  40 )
            end
            if t.prefab == "dug_trap_starfish" then
                WriteInfo( "animoffsetx",  160 )
                WriteInfo( "animoffsety",  10 )
            end
            if t.prefab == "bananajuice" then
                WriteInfo( "animoffsety",  -20 )
            end
            if t.prefab == "bananajuice" then
                WriteInfo( "animoffsety",  -20 )
            end

            if t.scrapbook_animoffsetx then
                 WriteInfo( "animoffsetx",  t.scrapbook_animoffsetx )
            end
            if t.scrapbook_animoffsety then
                 WriteInfo( "animoffsety",  t.scrapbook_animoffsety )
            end

            -----------------------------------------
            ------------------------------------ WATERPROOFER
            if t.components.waterproofer and t.components.waterproofer:GetEffectiveness() > 0 then
                WriteInfo( "waterproofer",  t.components.waterproofer:GetEffectiveness() )
            end

            -----------------------------------------
            ------------------------------------ INSULATOR
            if t.components.insulator then
                WriteInfo( "insulator", t.components.insulator:GetInsulation() )
                WriteInfo( "insulator_type", t.components.insulator.type )
            end

            -----------------------------------------
            ------------------------------------ DAPPERNESS
            if t.components.equippable and t.components.equippable.dapperness then
                WriteInfo( "dapperness",  t.components.equippable.dapperness )
            end

            -----------------------------------------
            ------------------------------------ FUELED
            if t.components.fueled then
                WriteInfo( "fueledmax",    t.components.fueled.maxfuel  )
                WriteInfo( "fueledrate",   t.components.fueled.rate     )
                WriteInfo( "fueledtype1",  t.components.fueled.fueltype )

                if t.components.fueled.secondaryfueltype then
                    WriteInfo( "fueledtype2",  t.components.fueled.secondaryfueltype )
                end
            end

            local fueled = t.components.fueled
            if fueled ~= nil and (fueled.fueltype == FUELTYPE.USAGE or fueled.secondaryfueltype == FUELTYPE.USAGE) and not fueled.no_sewing then
                WriteInfo( "sewable", true )
            end

            -----------------------------------------
            ----------------------------------- FUEL
            if t.components.fuel then
                WriteInfo( "fueltype",  t.components.fuel.fueltype )
                WriteInfo( "fuelvalue",  t.components.fuel.fuelvalue )
            end

            if t:HasTag("lightbattery") then
                WriteInfo( "lightbattery", true )
            end

            -----------------------------------------
            ------------------------------------ PERISHABLE
            if t.components.perishable then
                WriteInfo( "perishable",  t.components.perishable.perishtime )
            end

            -----------------------------------------
            ------------------------------------ OAR
            if t.components.oar then
                WriteInfo( "oar_force",  t.components.oar.force )
                WriteInfo( "oar_velocity",  t.components.oar.max_velocity )
            end

            -----------------------------------------
            ------------------------------------ TACKLE
            if t.components.oceanfishingtackle then
                if t.components.oceanfishingtackle.casting_data then
                    WriteInfo( "float_range", t.components.oceanfishingtackle.casting_data.dist_max + 5)
                    WriteInfo( "float_accuracy", t.components.oceanfishingtackle.casting_data.dist_min_accuracy)
                end
                if t.components.oceanfishingtackle.lure_data then
                    WriteInfo( "lure_charm", t.components.oceanfishingtackle.lure_data.charm)
                    WriteInfo( "lure_dist", t.components.oceanfishingtackle.lure_data.dist_max)
                    WriteInfo( "lure_radius", t.components.oceanfishingtackle.lure_data.radius)
                end
            end            

            -----------------------------------------
            ------------------------------------- DEPS

            local deps = deepcopy(Prefabs[i].deps)

            if t.scrapbook_deps then
                deps = t.scrapbook_deps

            else
                if t.components.prototyper and t.prefab ~= "bookstation" then
                    deps = {}
                    for recipe,recipedata in pairs(AllRecipes) do
                        local found = false
                        for tech,level in pairs(recipedata.level) do
                            if level > 0 then
                                for tree, num in pairs(t.components.prototyper.trees) do
                                    if tech == tree and num >= level then
                                        table.insert(deps,tostring(recipe))
                                        found = true
                                        break
                                    end
                                end
                                if found then
                                    break
                                end
                            end
                        end
                    end
                end
            end

            local recipe = AllRecipes[t.prefab]

            if recipe ~= nil then
                if recipe.builder_tag then

                    ------  CRAFTING ICON  ------
                    local character = RECIPE_BUILDER_TAG_LOOKUP[recipe.builder_tag]

                    if character ~= nil then
                        WriteInfo( "craftingprefab", character )
                    else
                        print(string.format("[!!!!]  Recipe builder tag [%s] isn't in RECIPE_BUILDER_TAG_LOOKUP...", recipe.builder_tag))
                    end
                end

                for _, data in ipairs(recipe.ingredients) do
                    if not table.contains(deps, data.type) then
                        table.insert(deps, data.type)
                    end
                end
            end

            if t.components.lootdropper then
                deps = ArrayUnion(deps, table.getkeys(t.components.lootdropper:GetAllPossibleLoot()))
            end

            if t.scrapbook_adddeps then
                for i, dep in ipairs(t.scrapbook_adddeps) do
                    if not table.contains(deps, dep) then
                        table.insert(deps, dep)
                    else
                        print(string.format("[!!!!]  Dependency [%s] is duplicated in prefab [%s]...", dep, t.prefab))
                    end
                end
            end

            if t.scrapbook_removedeps then
                for i, dep in ipairs(t.scrapbook_removedeps) do
                    table.removearrayvalue(deps, dep)
                end
            end

            -- Remove itself if it exists.
            table.removearrayvalue(deps, t.prefab)

            if deps then
                f:write(' deps={')
                for i,dep in ipairs(deps)do
                    if scrapbookprefabs[dep] then
                        f:write('"'..dep..'",')
                    end
                end
                f:write('},')
            end

            -----------------------------------------
            ------------------------------------ NOTES
            f:write(' notes={')
            if t:HasTag("shadow_aligned") then
                f:write("shadow_aligned=true,")
            end
            if t:HasTag("lunar_aligned") then
               f:write("lunar_aligned=true,")
            end

            f:write('},')

            ----------------------------------- SPECIAL INFO
            if t.scrapbook_specialinfo then
                WriteInfo( "specialinfo", t.scrapbook_specialinfo)
            end

            -- end ------------------------
            f:write("},\n")

            t:Remove()
        end
        f:write("}\nreturn data")
    end

    f:close()

    exporter_data_helper:write("}\n")
    exporter_data_helper:close()
end

--------------------------------------------------------------------------------------------------------------------

-- Hash distribution checks for collisions.
local function _testhash(word, results)
    local collision = nil
    local hashed = hash(word)
    if results[hashed] then
        print("COLLISION", word, hashed)
        collision = true
    end
    results[hashed] = true
    return collision
end
local function _getbins(bitswanted, results)
    local mask = 2 ^ bitswanted - 1
    local bins = {}
    for i = 0, mask do
        bins[i + 1] = 0
    end
    for hashed, _ in pairs(results) do
        local v = bit.band(mask, hashed) + 1
        bins[v] = bins[v] + 1
    end
    return bins
end
local function _printbins(bins, total, collisions)
    local binsmax = #bins
    local highestdiff = -1
    for i = 1, binsmax do
        local v = bins[i]
        local diff = math.abs(100 - ((v * binsmax * 100) / total))
        if diff > highestdiff then
            highestdiff = diff
        end
        print(string.format("Bitmask %02X has %d words diff %.1f%%", i - 1, v, diff))
    end
    print(string.format("Avg: %.1f, Highest Diff: %.1f%%, Collisions: %d", total / binsmax, highestdiff, collisions))
end

function d_testhashes_random(bitswanted, tests)
    bitswanted = math.min(bitswanted or 4, 8)
    tests = tests or 10000

    local printables = {}
    for i = 0x20, 0x7E do -- ASCII
        printables[i - 0x20 + 1] = string.char(i)
    end
    local printableslen = #printables

    local results = {}
    local collisions = 0
    for test = 1, tests do
        local worddata = {}
        local len = math.random(6, 18)
        for l = 1, len do
            worddata[l] = printables[math.random(1, printableslen)]
        end
        local word = table.concat(worddata, "")
        if _testhash(word, results) then
            collisions = collisions + 1
        end
    end

    local bins = _getbins(bitswanted, results)
    _printbins(bins, tests, collisions)
end

function d_testhashes_prefabs(bitswanted)
    bitswanted = math.min(bitswanted or 4, 8)

    local results = {}
    local total = 0
    local collisions = 0
    for word, _ in pairs(Prefabs) do
        if _testhash(word, results) then
            collisions = collisions + 1
        end
        total = total + 1
    end

    local bins = _getbins(bitswanted, results)
    _printbins(bins, total, collisions)
end

local function _DamageListenerFn(inst, data)
    if data.damage ~= nil then
        inst._damage_count = inst._damage_count + data.damage
    end
end

function d_testdps(time, target)
    target = target or ConsoleWorldEntityUnderMouse()
    time = time or 5

    print(string.format("Starting DPS test for: %s, time: %2.2f", tostring(target), time))

    if target._dpstesttask ~= nil then
        target._dpstesttask:Cancel()
        target._dpstesttask = nil

        target:RemoveEventCallback("attacked", _DamageListenerFn)
    end

    target._damage_count = 0

    target:ListenForEvent("attacked", _DamageListenerFn)

    target._dpstesttask = target:DoTaskInTime(time, function(inst)
        print(string.format("DPS: %2.2f [%2.2f/%2.2f]", inst._damage_count/time, inst._damage_count, time))

        inst:RemoveEventCallback("attacked", _DamageListenerFn)
        inst._damage_count = nil
        inst._dpstesttask = nil
    end)
end
