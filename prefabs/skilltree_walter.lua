local SEP = 38
local SEP_Y = SEP + 3
local WOBY_SEP = SEP * 1.15

local AMMO_MIDDLE = -181.5
local SLINGSHOT_MIDDLE = 0-SEP/3
local CAMPING_MIDDLE = SLINGSHOT_MIDDLE - SEP/2.25*2 + SEP/3
local WOBY_MIDDLE = 176

local POS_Y1 =  175.5
local POS_Y2 = POS_Y1 - SEP_Y * 1
local POS_Y3 = POS_Y1 - SEP_Y * 2
local POS_Y4 = POS_Y1 - SEP_Y * 3
local POS_Y5 = POS_Y1 - SEP_Y * 4

local TITLE_Y = POS_Y1 + 28.5

local POSITIONS = {
    walter_ammo_shattershots = { AMMO_MIDDLE-SEP, POS_Y1 },
    walter_ammo_utility      = { AMMO_MIDDLE,     POS_Y1 },
    walter_ammo_lucky        = { AMMO_MIDDLE+SEP, POS_Y1 },

    walter_ammo_shadow_lock = { AMMO_MIDDLE-SEP*.725, POS_Y2-2 },
    walter_ammo_lunar_lock  = { AMMO_MIDDLE+SEP*.825, POS_Y2-2 },

    walter_ammo_shadow = { AMMO_MIDDLE-SEP*.725, POS_Y3 },
    walter_ammo_lunar  = { AMMO_MIDDLE+SEP*.825, POS_Y3 },

    walter_ammo_lock = { AMMO_MIDDLE, POS_Y4+.5},

    walter_ammo_efficiency = { AMMO_MIDDLE-SEP/1.6, POS_Y5+3 },
    walter_ammo_bag        = { AMMO_MIDDLE+SEP/1.7, POS_Y5+3 },

    ----------------------------------------------------------------------------------

    walter_slingshot_modding = { SLINGSHOT_MIDDLE,     POS_Y1 },
    walter_slingshot_handles = { SLINGSHOT_MIDDLE-SEP*1.15, POS_Y2 },
    walter_slingshot_bands   = { SLINGSHOT_MIDDLE,     POS_Y2 },
    walter_slingshot_frames  = { SLINGSHOT_MIDDLE+SEP*1.15, POS_Y2 },

    ----------------------------------------------------------------------------------

    walter_camp_rope       = { CAMPING_MIDDLE-SEP, POS_Y4 },
    walter_camp_walterhat  = { CAMPING_MIDDLE,     POS_Y4 },
    walter_camp_wobytreat  = { CAMPING_MIDDLE+SEP, POS_Y4 },
    walter_camp_firstaid   = { CAMPING_MIDDLE-SEP, POS_Y5 },
    walter_camp_fire       = { CAMPING_MIDDLE,     POS_Y5 },
    walter_camp_wobyholder = { CAMPING_MIDDLE+SEP, POS_Y5 },

    walter_camp_lock        = { CAMPING_MIDDLE+SEP*2.275, POS_Y4 },
    walter_camp_wobycourier = { CAMPING_MIDDLE+SEP*2.275, POS_Y5 },

    ----------------------------------------------------------------------------------

    walter_woby_lock   = { WOBY_MIDDLE+WOBY_SEP/2, POS_Y1+1 },
    walter_woby_sprint = { WOBY_MIDDLE+WOBY_SEP/2, POS_Y2+2 },
    walter_woby_dash   = { WOBY_MIDDLE+WOBY_SEP/2, POS_Y3+2 },
    walter_woby_shadow_lock = { WOBY_MIDDLE,     POS_Y4+2 },
    walter_woby_shadow      = { WOBY_MIDDLE,     POS_Y5+2 },
    walter_woby_lunar_lock  = { WOBY_MIDDLE+WOBY_SEP*1.025, POS_Y4+2 },
    walter_woby_lunar       = { WOBY_MIDDLE+WOBY_SEP*1.025, POS_Y5+2 },

    walter_woby_endurance   = { WOBY_MIDDLE-WOBY_SEP-SEP*.1, POS_Y1-SEP_Y/3 },
    walter_woby_itemfetcher = { WOBY_MIDDLE-WOBY_SEP-SEP*.1, POS_Y2-SEP_Y/3 },
    walter_woby_foraging    = { WOBY_MIDDLE-WOBY_SEP-SEP*.1, POS_Y3-SEP_Y/3 },
    walter_woby_taskaid     = { WOBY_MIDDLE-WOBY_SEP-SEP*.1, POS_Y4-SEP_Y/3 },
}

--------------------------------------------------------------------------------------------------

local WALTER_SKILL_STRINGS = STRINGS.SKILLTREE.WALTER

--------------------------------------------------------------------------------------------------

local function CreateAddTagFn(tag)
    return function(inst) inst:AddTag(tag) end
end

local function CreateRemoveTagFn(tag)
    return function(inst) inst:RemoveTag(tag) end
end

--------------------------------------------------------------------------------------------------

local ONACTIVATE_FNS = {
    AllegianceShadow = function(inst)
        if inst.components.skilltreeupdater:CountSkillTag("shadow_favor") >= 2 then
            return -- We already have an affinity skill (tags are added before running this function).
        end

        inst:AddTag("player_shadow_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
        end
    end,

    AllegianceLunar = function(inst)
        if inst.components.skilltreeupdater:CountSkillTag("lunar_favor") >= 2 then
            return -- We already have an affinity skill (tags are added before running this function).
        end

        inst:AddTag("player_lunar_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WALTER.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
        end
    end,
}

local ONDEACTIVATE_FNS = {
    AllegianceShadow = function(inst)
        if inst.components.skilltreeupdater:HasSkillTag("shadow_favor") then
            return -- We still have an affinity skill.
        end

        inst:RemoveTag("player_shadow_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:RemoveResist("shadow_aligned", inst, "allegiance_shadow")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:RemoveBonus("lunar_aligned", inst, "allegiance_shadow")
        end
    end,

    AllegianceLunar = function(inst)
        if inst.components.skilltreeupdater:HasSkillTag("lunar_favor") then
            return -- We still have an affinity skill.
        end

        inst:RemoveTag("player_lunar_aligned")

        if inst.components.damagetyperesist ~= nil then
            inst.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "allegiance_lunar")
        end

        if inst.components.damagetypebonus ~= nil then
            inst.components.damagetypebonus:RemoveBonus("shadow_aligned", inst, "allegiance_lunar")
        end
    end,
}

--------------------------------------------------------------------------------------------------

-- Title positions.
local ORDERS = {
    {"slingshotammo", { AMMO_MIDDLE,           TITLE_Y         }},
    {"slingshotmods", { SLINGSHOT_MIDDLE,      TITLE_Y         }},
    {"camping",       { SLINGSHOT_MIDDLE,      TITLE_Y-SEP_Y*3 }},
    {"woby",          { WOBY_MIDDLE-SEP/6,     TITLE_Y         }},
}

--------------------------------------------------------------------------------------------------

local function BuildSkillsData(SkillTreeFns)

    -- These are here because of SkillTreeFns.

    local function CreateSkillCountLock(group, count)
        return {
            group = group,
            root = true,
            lock_open = function(prefabname, activatedskills, readonly)
                return SkillTreeFns.CountTags(prefabname, group, activatedskills) >= count
            end,
        }
    end

    local function BasicShadowAllegianceLockFn(prefabname, activatedskills, readonly)
        if SkillTreeFns.CountTags(prefabname, "lunar_favor", activatedskills) > 0 then
            return false
        end

        if readonly then
            return "question"
        end

        return TheGenericKV:GetKV("fuelweaver_killed") == "1"
    end

    local function BasicLunarAllegianceLockFn(prefabname, activatedskills, readonly)
        if SkillTreeFns.CountTags(prefabname, "shadow_favor", activatedskills) > 0 then
            return false
        end

        if readonly then
            return "question"
        end

        return TheGenericKV:GetKV("celestialchampion_killed") == "1"
    end

    local skills =
    {
        -----------------------------------------------------------------------------------------------------------------
        -- SLINGSHOT
        -----------------------------------------------------------------------------------------------------------------

        walter_slingshot_modding = {
            group = "slingshotmods",
            root = true,
            connects = {
                "walter_slingshot_bands",
                "walter_slingshot_handles",
                "walter_slingshot_frames"
            },
        },
        walter_slingshot_handles = {
            group = "slingshotmods",
        },
        walter_slingshot_bands = {
            group = "slingshotmods",
        },
        walter_slingshot_frames = {
            group = "slingshotmods",
        },

        -----------------------------------------------------------------------------------------------------------------
        -- AMMO
        -----------------------------------------------------------------------------------------------------------------

        walter_ammo_shattershots = {
            group = "slingshotammo",
            tags = { "slingshotammo_crafting" },
            root = true,
            defaultfocus = true,
        },
        walter_ammo_lucky = {
            group = "slingshotammo",
            tags = { "slingshotammo_crafting" },
            root = true,
        },
        walter_ammo_utility = {
            group = "slingshotammo",
            tags = { "slingshotammo_crafting" },
            root = true,
        },

        walter_ammo_lock = CreateSkillCountLock("slingshotammo_crafting", 2),

        walter_ammo_efficiency = {
            group = "slingshotammo",
            locks = { "walter_ammo_lock" },
        },
        walter_ammo_bag = {
            group = "slingshotammo",
            locks = {"walter_ammo_lock"},

            onactivate   = CreateAddTagFn("slingshotammocontaineruser"),
            ondeactivate = CreateRemoveTagFn("slingshotammocontaineruser"),
        },

        walter_ammo_shadow_lock = {
            group = "slingshotammo",
            root = true,

            lock_open = BasicShadowAllegianceLockFn,
        },

        walter_ammo_shadow = {
            group = "slingshotammo",
            tags = { "slingshotammo_crafting", "shadow", "shadow_favor" },

            locks = { "walter_ammo_shadow_lock" },

            onactivate   = ONACTIVATE_FNS.AllegianceShadow,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceShadow,
        },

        walter_ammo_lunar_lock = {
            group = "slingshotammo",
            root = true,

            lock_open = BasicLunarAllegianceLockFn,
        },

        walter_ammo_lunar = {
            group = "slingshotammo",
            tags = { "slingshotammo_crafting", "lunar", "lunar_favor" },

            locks = { "walter_ammo_lunar_lock" },

            onactivate   = ONACTIVATE_FNS.AllegianceLunar,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceLunar,
        },

        -----------------------------------------------------------------------------------------------------------------
        -- WOBY
        -----------------------------------------------------------------------------------------------------------------

        walter_woby_lock = CreateSkillCountLock("woby_basics", 2),

        walter_woby_sprint = {
            group = "woby",
            locks = { "walter_woby_lock" },
            connects = {
                "walter_woby_dash",
            },
        },

        walter_woby_dash = {
            group = "woby",
            tags = { "woby_dash" },
        },

        walter_woby_shadow_lock = {
            group = "woby",
            root = true,

            lock_open = function(prefabname, activatedskills, readonly)
                if not SkillTreeFns.HasTag(prefabname, "woby_dash", activatedskills) then
                    return false -- Requires walter_woby_dash.
                end

                return BasicShadowAllegianceLockFn(prefabname, activatedskills, readonly)
            end,
        },

        walter_woby_shadow = {
            group = "woby",
            tags = { "shadow", "shadow_favor" },

            locks = { "walter_woby_lock", "walter_woby_shadow_lock" },

            onactivate   = ONACTIVATE_FNS.AllegianceShadow,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceShadow,
        },

        walter_woby_lunar_lock = {
            group = "woby",
            root = true,

            lock_open = function(prefabname, activatedskills, readonly)
                if not SkillTreeFns.HasTag(prefabname, "woby_dash", activatedskills) then
                    return false -- Requires walter_woby_dash.
                end

                return BasicLunarAllegianceLockFn(prefabname, activatedskills, readonly)
            end,
        },

        walter_woby_lunar = {
            group = "woby",
            tags = { "lunar", "lunar_favor" },

            locks = { "walter_woby_lock", "walter_woby_lunar_lock" },

            onactivate   = ONACTIVATE_FNS.AllegianceLunar,
            ondeactivate = ONDEACTIVATE_FNS.AllegianceLunar,
        },

        walter_woby_endurance = {
            group = "woby",
            tags = { "woby_basics" },
            root = true,
        },

        walter_woby_taskaid = {
            group = "woby",
            tags = { "woby_basics" },
            root = true,
        },

        walter_woby_foraging = {
            group = "woby",
            tags = { "woby_basics" },
            root = true,
        },

        walter_woby_itemfetcher = {
            group = "woby",
            tags = { "woby_basics" },
            root = true,
        },

        -----------------------------------------------------------------------------------------------------------------
        -- CAMPING
        -----------------------------------------------------------------------------------------------------------------

        walter_camp_fire = {
            group = "camping",
            root = true,
            onactivate   = CreateAddTagFn("portable_campfire_user"),
            ondeactivate = CreateRemoveTagFn("portable_campfire_user"),
        },

        walter_camp_rope = {
            group = "camping",
            root = true,
        },

        walter_camp_firstaid = {
            group = "camping",
            root = true,

            onactivate = function(inst)
                inst:AddTag("fasthealer")

                if inst.components.efficientuser == nil then
                    inst:AddComponent("efficientuser")
                end

                inst.components.efficientuser:AddMultiplier(ACTIONS.HEAL, TUNING.SKILLS.WALTER.HEALERS_EFFECTIVENESS_MODIFIER, "walter_camp_firstaid")
            end,

            ondeactivate = function(inst)
                inst:RemoveTag("fasthealer")

                if inst.components.efficientuser ~= nil then
                    inst.components.efficientuser:RemoveMultiplier(ACTIONS.HEAL, "walter_camp_firstaid")
                end
            end,
        },

        walter_camp_walterhat = {
            group = "camping",
            root = true,
        },

        walter_camp_wobytreat = {
            group = "camping",
            root = true,
        },

        walter_camp_wobyholder = {
            group = "camping",
            root = true,
        },

        walter_camp_lock = CreateSkillCountLock("camping", 3),

        walter_camp_wobycourier = {
            group = "camping",
            locks = { "walter_camp_lock" },
        },
    }

    for name, data in pairs(skills) do
        local uppercase_name = string.upper(name)

        data.tags = data.tags or {}

        data.pos = POSITIONS[name] or data.pos

        data.desc = data.desc or WALTER_SKILL_STRINGS[uppercase_name.."_DESC"]

        -- If it's not a lock.
        if not data.lock_open then
            data.title = data.title or WALTER_SKILL_STRINGS[uppercase_name.."_TITLE"]
            data.icon = data.icon or name

            if not table.contains(data.tags, data.group) then
                table.insert(data.tags, data.group)
            end

        elseif not table.contains(data.tags, "lock") then
            table.insert(data.tags, "lock")
        end
    end

    return {
        SKILLS = skills,
        ORDERS = ORDERS,
    }
end

--------------------------------------------------------------------------------------------------

return BuildSkillsData