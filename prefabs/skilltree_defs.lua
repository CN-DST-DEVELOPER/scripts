local SKILLTREE_DEFS = {}
local SKILLTREE_METAINFO = {}

-- Wrapper function to help modders with their strange prefab names and tree validation process.
local function PrintFixMe(error_message)
    print(string.format("\n\nFIXME: %s\n\n", error_message))
end
local function CreateSkillTreeFor(characterprefab, skills)
    local RPC_LOOKUP = {}
    local rpc_id = 0
    for skill_name, skill in orderedPairs(skills) do
        if skill.lock_open == nil then -- NOTES(JBK): Only include skills for this.
            skill.rpc_id = rpc_id
            RPC_LOOKUP[rpc_id] = skill_name
            rpc_id = rpc_id + 1
            -- NOTES(JBK): [Searchable "SN_SKILLSELECTION"] The engine will only use the first slot for a maximum of 32 skills at this time. Adding more data will not be shown to other players.
            if rpc_id >= 32 then
                -- NOTES(JBK): If this goes beyond 32 it will not be shown to other players in the inspection panel.
                -- It will not be networked during initial skill selection.
                PrintFixMe(string.format("Skill Tree for %s has TOO MANY skills! This will break networking.", characterprefab))
            end
        end
        if skill.connects then -- NOTES(JBK): These skills unlock as an 'or' gate.
            if skill.connects[1] == nil then
                PrintFixMe(string.format("Skill Tree for %s [skill %s] has NO connections! Remove this or add a connection.", characterprefab, skill_name))
            end
            for _, next_skill_name in ipairs(skill.connects) do
                local next_skill = skills[next_skill_name]
                if next_skill == nil then
                    PrintFixMe(string.format("Skill Tree for %s [skill %s] has a bad 'connects' to unknown skill %s! Remove this or add a good connection.", characterprefab, skill_name, next_skill_name))
                end
                local must_have_one_of = next_skill.must_have_one_of or {}
                next_skill.must_have_one_of = must_have_one_of
                must_have_one_of[skill_name] = true
                if next_skill.root then
                    PrintFixMe(string.format("Skill Tree for %s [skill %s] has a bad 'root'! Remove 'root' because %s 'connects' to it.", characterprefab, next_skill_name, skill_name))
                end
            end
        end
        if skill.locks then -- NOTES(JBK): These skills unlock as an 'and' gate.
            if skill.locks[1] == nil then
                PrintFixMe(string.format("Skill Tree for %s [skill %s] has NO locks! Remove 'locks' table or add lock requirements.", characterprefab, skill_name))
            end
            for _, lock_name in ipairs(skill.locks) do
                local lock = skills[lock_name]
                if lock == nil then
                    PrintFixMe(string.format("Skill Tree for %s [skill %s] has a bad 'locks' name %s!", characterprefab, skill_name, lock_name))
                end
                local must_have_all_of = skill.must_have_all_of or {}
                skill.must_have_all_of = must_have_all_of
                must_have_all_of[lock_name] = true
                if skill.root then
                    PrintFixMe(string.format("Skill Tree for %s [skill %s] has a bad 'root'! Remove 'root' because %s 'locks' to it.", characterprefab, skill_name, lock_name))
                end
            end
        end
    end
    for skill_name, skill in pairs(skills) do
        if not (skill.root or skill.must_have_one_of or skill.must_have_all_of) then
            -- NOTES(JBK): Floating skills are not going to be able to be properly validated because they are out of the tree ordering.
            PrintFixMe(string.format("Skill Tree for %s [skill %s] is FLOATING! Connect the skill as either a 'root' or a connection from 'connects'.", characterprefab, skill_name))
        end
    end
    SKILLTREE_METAINFO[characterprefab] = { -- Must be first for metatable setting.
        RPC_LOOKUP = RPC_LOOKUP,
        TOTAL_SKILLS_COUNT = rpc_id,
    }
    SKILLTREE_DEFS[characterprefab] = skills
end

local function CountTags(prefab, targettag, activatedskills) -- NOTES(JBK): This function is ran on both server and client do not use TheSkillTree inside here.
    if not activatedskills then
        return 0
    end

    local tag_count = 0
    for skill in pairs(activatedskills) do
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

local function CountSkills(prefab, activatedskills) -- NOTES(JBK): This function is ran on both server and client do not use TheSkillTree inside here.
    if not activatedskills then
        return 0
    end

    return GetTableSize(activatedskills)
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
        lock_open = function(prefabname, activatedskills, readonly)
            if readonly then
                return "question"
            end

            return TheGenericKV:GetKV("fuelweaver_killed") == "1"
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
        lock_open = function(prefabname, activatedskills, readonly)
            if CountTags(prefabname, "shadow_favor", activatedskills) == 0 then
                return true
            end

            return nil -- Important to return nil and not false.
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
        lock_open = function(prefabname, activatedskills, readonly)
            if readonly then
                return "question"
            end

            return TheGenericKV:GetKV("celestialchampion_killed") == "1"
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
        lock_open = function(prefabname, activatedskills, readonly)
            if CountTags(prefabname, "lunar_favor", activatedskills) == 0 then
                return true
            end

            return nil -- Important to return nil and not false.
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
