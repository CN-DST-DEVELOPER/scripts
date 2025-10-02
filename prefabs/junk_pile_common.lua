local EMPTY = "EMPTY"

local CRITTER_SPAWN_CHANCE = 0.1
local LOOT_PERISHABLE_PERCENT = 0.25

local LOOT = {
    CRITTERS = {
        { weight=4, prefab = "spider",         targetplayer=true, state="warrior_attack", enabled_tuning = "SPIDERDEN_ENABLED" }, -- 57.14%
        { weight=1, prefab = "spider_warrior", targetplayer=true, state="warrior_attack", enabled_tuning = "SPIDERDEN_ENABLED" }, -- 14.29%
        { weight=2, prefab = "catcoon",        targetplayer=true, state="pounceattack"  , enabled_tuning = "CATCOONDEN_ENABLED"}, -- 28.57%
        { weight=2, prefab = "mole",                              state="peek"          , enabled_tuning = "MOLE_ENABLED"      }, -- 28.57%
    },

    ITEMS = {
        { weight=8, prefab = EMPTY          }, -- 25%
        { weight=8, prefab = "wagpunk_bits" }, -- 25%
        { weight=4, prefab = "rocks"        }, -- 12.5%
        { weight=4, prefab = "log"          }, -- 12.5%
        { weight=2, prefab = "boards"       }, -- 6.25%
        { weight=2, prefab = "potato"       }, -- 6.25%
        { weight=1, prefab = "transistor"   }, -- 3.125%
        { weight=1, prefab = "trinket_6"    }, -- 3.125%
        { weight=1, prefab = "blueprint"    }, -- 3.125%
        { weight=1, prefab = "gears"        }, -- 3.125%
    },
}

local WEIGHTED_CRITTER_TABLE = {}
local WEIGHTED_ITEM_TABLE = {}

for _, critter in ipairs(LOOT.CRITTERS) do
    WEIGHTED_CRITTER_TABLE[critter] = critter.weight
end

for _, item in ipairs(LOOT.ITEMS) do
    WEIGHTED_ITEM_TABLE[item] = item.weight
end

local function SpawnJunkLoot(inst, digger, nopickup)
    if math.random() <= CRITTER_SPAWN_CHANCE then
        local choice = weighted_random_choice(WEIGHTED_CRITTER_TABLE)

        local enabled = choice.enabled_tuning and TUNING[choice.enabled_tuning]

        if (enabled == nil or enabled) and choice.prefab ~= nil and choice.prefab ~= EMPTY then
            local critter = SpawnPrefab(choice.prefab)

            local attackplayer = not (critter:HasTag("spider") and digger:HasOneOfTags("spiderwhisperer", "spiderdisguise"))

            inst.components.lootdropper:FlingItem(critter)

            if attackplayer and choice.targetplayer and critter.components.combat ~= nil then
                critter.components.combat:SetTarget(digger)
            end

            SpawnPrefab("junk_break_fx").Transform:SetPosition(critter.Transform:GetWorldPosition())

            if choice.state ~= nil and (not choice.targetplayer or attackplayer) then
                critter.sg:GoToState(choice.state, digger)
            end
        end
    end

    local choice = weighted_random_choice(WEIGHTED_ITEM_TABLE)

    if choice.prefab ~= nil and choice.prefab ~= EMPTY then
        local item = SpawnPrefab(choice.prefab)

        if item.components.perishable ~= nil then
            item.components.perishable:SetPercent(LOOT_PERISHABLE_PERCENT)
        end

		if not nopickup and digger.components.inventory and digger.components.inventory:IsOpenedBy(digger) then
            digger.components.inventory:GiveItem(item, nil, inst:GetPosition())
        else
            inst.components.lootdropper:FlingItem(item)
        end
    end
end

local function AddPrefabDeps(prefabs)
    for _, critter in ipairs(LOOT.CRITTERS) do
        if critter.prefab ~= EMPTY and not table.contains(prefabs, critter.prefab) then
            table.insert(prefabs, critter.prefab)
        end
    end

    for _, item in ipairs(LOOT.ITEMS) do
        if item.prefab ~= EMPTY and not table.contains(prefabs, item.prefab) then
            table.insert(prefabs, item.prefab)
        end
    end
end

return {
    LOOT = LOOT,
    WEIGHTED_ITEM_TABLE = WEIGHTED_ITEM_TABLE,
    WEIGHTED_CRITTER_TABLE = WEIGHTED_CRITTER_TABLE,
    --
    SpawnJunkLoot = SpawnJunkLoot,
    AddPrefabDeps = AddPrefabDeps,
}