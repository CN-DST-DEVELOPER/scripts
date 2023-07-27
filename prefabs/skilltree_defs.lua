local SKILLTREE_DEFS = {}
local SKILLTREE_METAINFO = {}

-- Wrapper function to help modders with their strange prefab names and tree validation process.
local function CreateSkillTreeFor(characterprefab, skills)
    local RPC_LOOKUP = {}
    local rpc_id = 0
    for k, v in orderedPairs(skills) do
        if v.lock_open == nil then -- NOTES(JBK): Only include skills for this.
            v.rpc_id = rpc_id
            RPC_LOOKUP[rpc_id] = k
            rpc_id = rpc_id + 1
            if rpc_id >= 32 then
                -- NOTES(JBK): If this goes beyond 32 it will not be shown to other players in the inspection panel.
                -- It will not be networked during initial skill selection.
                local err = string.format("Skill Tree for %s has TOO MANY skills! This will break networking.", characterprefab)
                if BRANCH == "dev" then
                    assert(false, err)
                else
                    print(err)
                end
            end
        end
    end
    SKILLTREE_METAINFO[characterprefab] = { -- Must be first for metatable setting.
        RPC_LOOKUP = RPC_LOOKUP,
        TOTAL_SKILLS_COUNT = rpc_id,
    }
    SKILLTREE_DEFS[characterprefab] = skills
end

local function CountTags(prefab, targettag, skillselection)
    local dataset = skillselection or TheSkillTree.activatedskills[prefab]
    if not dataset then
        return 0
    end

    local tag_count = 0
    for skill in pairs(dataset) do
        local data = SKILLTREE_DEFS[prefab][skill]
        if data then
            for _, tag in ipairs(data.tags) do
                if tag == targettag then
                    tag_count = tag_count + 1
                end
            end
        end
    end
    return tag_count
end

local function CountSkills(prefab, skillselection)
    local dataset = skillselection or TheSkillTree.activatedskills[prefab]
    return (dataset and GetTableSize(dataset)) or 0
end

----------------------------------------------------------------------------------------------------------------------------

local function SkillHasTags(skill, tag, prefabname)
    if not SKILLTREE_DEFS[prefabname] or not SKILLTREE_DEFS[prefabname][skill] then
        return nil
    end

    for _, stag in pairs(SKILLTREE_DEFS[prefabname][skill].tags) do
        if tag == stag then
            return true
        end
    end
end

----------------------------------------------------------------------------------------------------------------------------
local function MakeFuelWeaverLock(extra_data, not_root)
    local lock = {
        desc = STRINGS.SKILLTREE.ALLEGIANCE_LOCK_2_DESC,
        root = not not_root,
        group = "allegiance",
        tags = {"allegiance", "lock"},
        lock_open = function(prefabname, skillselection)
            return (skillselection ~= nil and "question")
                or (TheGenericKV:GetKV("fuelweaver_killed") == "1")
        end,
    }

    if extra_data then
        lock.pos = extra_data.pos
        lock.connects = extra_data.connects
        lock.group = extra_data.group or lock.group
    end

    return lock
end

local function MakeNoShadowLock(extra_data, not_root)
    local lock = {
        desc = STRINGS.SKILLTREE.ALLEGIANCE_LOCK_5_DESC,
        root = not not_root,
        group = "allegiance",
        tags = {"allegiance", "lock"},
        lock_open = function(prefabname, skillselection)
            return (skillselection ~= nil and "question")
                or (CountTags(prefabname, "shadow_favor", skillselection) == 0 and true)
                or nil -- It's important that we return nil instead of false
        end,
    }

    if extra_data then
        lock.pos = extra_data.pos
        lock.connects = extra_data.connects
        lock.group = extra_data.group or lock.group
    end

    return lock
end

local function MakeCelestialChampionLock(extra_data, not_root)
    local lock = {
        desc = STRINGS.SKILLTREE.ALLEGIANCE_LOCK_3_DESC,
        root = not not_root,
        group = "allegiance",
        tags = {"allegiance", "lock"},
        lock_open = function(prefabname, skillselection)
            return (skillselection ~= nil and "question")
                or (TheGenericKV:GetKV("celestialchampion_killed") == "1")
        end,
    }

    if extra_data then
        lock.pos = extra_data.pos
        lock.connects = extra_data.connects
        lock.group = extra_data.group or lock.group
    end

    return lock
end

local function MakeNoLunarLock(extra_data, not_root)
    local lock = {
        desc = STRINGS.SKILLTREE.ALLEGIANCE_LOCK_4_DESC,
        root = not not_root,
        group = "allegiance",
        tags = {"allegiance", "lock"},
        lock_open = function(prefabname, skillselection)
            return (skillselection ~= nil and "question")
                or (CountTags(prefabname, "lunar_favor", skillselection) == 0 and true)
                or nil -- It's important that we return nil instead of false
        end,
    }

    if extra_data then
        lock.pos = extra_data.pos
        lock.connects = extra_data.connects
        lock.group = extra_data.group or lock.group
    end

    return lock
end

local FN = {
    CountSkills = CountSkills,
    CountTags = CountTags,
    SkillHasTags = SkillHasTags,

    MakeFuelWeaverLock = MakeFuelWeaverLock,
    MakeNoShadowLock = MakeNoShadowLock,
    MakeCelestialChampionLock = MakeCelestialChampionLock,
    MakeNoLunarLock = MakeNoLunarLock,
}

local SKILLTREE_ORDERS = {}

local SKILLTREE_CHARACTERS = {
    "wilson",
    "woodie",
    "wolfgang",
    "wormwood",
}

for _, character in ipairs(SKILLTREE_CHARACTERS) do
    local BuildSkillsData = require("prefabs/skilltree_"..character)

    if BuildSkillsData then
        local data = BuildSkillsData(FN)

        if data then
            CreateSkillTreeFor(character, data.SKILLS)
            SKILLTREE_ORDERS[character] = data.ORDERS
        end
    end
end

setmetatable(SKILLTREE_DEFS, {
    __newindex = function(t, k, v)
        SKILLTREE_METAINFO[k].modded = true
        rawset(t, k, v)
    end,
})

return {SKILLTREE_DEFS = SKILLTREE_DEFS, SKILLTREE_METAINFO = SKILLTREE_METAINFO, CreateSkillTreeFor = CreateSkillTreeFor, SKILLTREE_ORDERS = SKILLTREE_ORDERS, FN = FN}
