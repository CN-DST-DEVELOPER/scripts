local WENDY_SKILL_STRINGS = STRINGS.SKILLTREE.WENDY

-- Positions
local TILEGAP = 38
local TILE = 50
local POS_X_1 = -245 -- -211
local POS_Y_1 = 172

local X = -298
local Y = 288

local width = 255+249-50
local height = 142+10

local CURVE_BASE_H = 75
local A_BASE_H = -10 +TILE

local COL1= POS_X_1+math.floor(width/11)
local COL2= POS_X_1+math.floor(width/11) *2
local COL3= POS_X_1+math.floor(width/11) *3
local COL4= POS_X_1+math.floor(width/11) *4
local COL5= POS_X_1+math.floor(width/11) *5

local COL6= POS_X_1+math.floor(width/11) *7
local COL7= POS_X_1+math.floor(width/11) *8
local COL8= POS_X_1+math.floor(width/11) *9
local COL9= POS_X_1+math.floor(width/11) *10
local COL10= POS_X_1+math.floor(width/11) *11

local CURV1 = CURVE_BASE_H + 0
local CURV2 = CURVE_BASE_H + math.floor(TILE/1.5)
local CURV3 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3)
local CURV4 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3+TILE/4)
local CURV5 = CURVE_BASE_H + math.floor(TILE/1.5+TILE/3+TILE/4+TILE/5)

--

local function BuildSkillsData(SkillTreeFns)
    local skills = {}
    local function finalize_skill_group(skill_subset, group_name)
        for skill_name, skill_data in pairs(skill_subset) do
            local skill_name_upper = string.upper(skill_name)
            skill_data.group = group_name
            table.insert(skill_data.tags, group_name)

            skill_data.desc = skill_data.desc or WENDY_SKILL_STRINGS[skill_name_upper.."_DESC"]
            if not skill_data.lock_open then
                skill_data.title = skill_data.title or WENDY_SKILL_STRINGS[skill_name_upper.."_TITLE"]
                skill_data.icon = skill_data.icon or skill_name
            end

            skills[skill_name] = skill_data
        end
    end

    local sisturn_skills =
    {
        wendy_sisturn_1 = {
            pos = {103,173}, --{-193-5,102-2},
            tags = {"sisturn"},
            root = true,
            connects = {
                "wendy_sisturn_2",
            },
            defaultfocus = true,
        },
        wendy_sisturn_2 = {
            pos = {140,154},-- {COL2-2-8, CURV2+ TILEGAP -10},
            tags = {"sisturn"},
            onactivate   = function(inst, fromload)
               inst.components.sanityauraadjuster:StartTask()
            end,
            ondeactivate = function(inst, fromload)
                inst.components.sanityauraadjuster:StopTask()
            end,
            connects = {
                "wendy_sisturn_3",
            },
        },

        wendy_sisturn_3 = {
            pos = {176,133},-- {COL3-4-10, CURV3+ TILEGAP-3},
            tags = {"sisturn"},
            onactivate   = function(inst, fromload)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    local blossoms = TheWorld.components.sisturnregistry and TheWorld.components.sisturnregistry:IsBlossom() or nil
                
                    if blossoms then
                        inst.components.ghostlybond.ghost:AddTag("player_damagescale")
                    end

                    inst.components.ghostlybond.ghost:updatehealingbuffs()
                end
            end,
            ondeactivate = function(inst, fromload)

                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:RemoveTag("player_damagescale")

                    local blossoms = TheWorld.components.sisturnregistry and TheWorld.components.sisturnregistry:IsBlossom() or nil
            
                    inst.components.ghostlybond.ghost:updatehealingbuffs()
                end
            end,
        },
    }
    finalize_skill_group(sisturn_skills, "sisturn_upgrades")

    local potion_skills =
    {
        wendy_potion_container = {
            pos =  {COL4+10+14,CURV5+TILEGAP}, -- {COL1+35, CURV1-16},
            tags = {"potion"},
            root = true,
            connects = {
                "wendy_potion_revive",
            },

            onactivate = function(inst, fromload)
                inst:AddTag("elixircontaineruser")
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("elixircontaineruser")
            end,
        },

        wendy_potion_revive = {
            pos =  {COL4+10+13+TILEGAP,190}, --{X+ 152,Y-192},
            tags = {"potion"},
            connects = {
                "wendy_potion_duration",
            },
        },

        wendy_potion_duration = {
            pos =  {COL4+10+12+TILEGAP+TILEGAP+1,190}, --{X+ 190, Y-170},
            tags = {"potion"},
            connects = {
                "wendy_potion_yield",
            },
        },
        wendy_potion_yield = {
            pos =  {COL6+11+4, CURV5+TILEGAP}, -- {COL4+11, Y-154},
            tags = {"potion"},
        },
    }
    finalize_skill_group(potion_skills, "potion_upgrades")

    local avenging_ghost_skills =
    {
        wendy_avenging_ghost = {
            pos = {-47, CURV5+20-20-3-5 },
            tags = {},
            root = true,
        },
    }
    finalize_skill_group(avenging_ghost_skills, "avengingghost")


    local smallghost_skills =
    {
        wendy_smallghost_1 = {
            pos = {-173,133},--{COL6+11+6, CURV5+TILEGAP},
            tags = {},
            root=true,
            connects = {
                "wendy_smallghost_2",
            },
        },
        wendy_smallghost_2 = {
            pos =  {-138, 154 },-- {X+390+6,Y-115},
            tags = {},
            connects = {
                "wendy_smallghost_3",
            },
        },
        wendy_smallghost_3 = {
            pos =  {-101, 173},-- {X+428+6,Y-137},
            tags = {},
        },
    }
    finalize_skill_group(smallghost_skills, "smallghost")

    local ghostflower_skills =
    {
        wendy_ghostflower_butterfly = {
            pos = {-168, 73}, --{COL4+10+14,CURV5+TILEGAP},
            tags = {},
            root=true,
            connects = {
                "wendy_ghostflower_hat",
            },
        },
        wendy_ghostflower_hat = {
            pos = {-132,100},-- {COL4+10+13+TILEGAP,CURV5+TILEGAP+5},
            tags = {},
            connects = {
                "wendy_ghostflower_grave",
            },
        },
        wendy_ghostflower_grave = {
            pos =  {-96, 118},  --{COL4+10+12+TILEGAP+TILEGAP,CURV5+TILEGAP+ 6},
            tags = {},
        },
    }
    finalize_skill_group(ghostflower_skills, "ghostflower")

    local gravestone_skills =
    {
        wendy_gravestone_1 = {
            pos = {COL6-5+3-20-10, CURV5-2-3+6-5},
            tags = {},
            root=true,

            onactivate = function(inst, fromload)
                inst:AddTag(UPGRADETYPES.GRAVESTONE.."_upgradeuser")
                inst:AddTag("gravedigger_user")
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag(UPGRADETYPES.GRAVESTONE.."_upgradeuser")
                inst:RemoveTag("gravedigger_user")
            end,

            connects = {
                "wendy_makegravemounds",
            },
        },

        wendy_makegravemounds = {
            pos = {X+372+5-20-10,Y-155-4+12-5},
            tags = {},
        },
    }
    finalize_skill_group(gravestone_skills, "gravestone")

    local ghost_command_skills =
    {
        wendy_ghostcommand_1 = {
            pos = {98,118}, --{X+482-5,Y-175+15},
            tags = {},
            connects = {
                "wendy_ghostcommand_2",
            },

            root = true,
        },
        wendy_ghostcommand_2 = {
            pos = {135,100},
            tags = {},
            connects = {
                "wendy_ghostcommand_3",
            },
        },
        wendy_ghostcommand_3 = {
            pos = {171,73},
            tags = {},
        },
    }
    finalize_skill_group(ghost_command_skills, "ghost_command")

    local allegiance_skills =
    {

        wendy_shadow_lock_1 = SkillTreeFns.MakeFuelWeaverLock({ pos = {COL3+TILEGAP/2 +14, A_BASE_H} }),
        wendy_shadow_lock_2 = SkillTreeFns.MakeNoLunarLock({ pos = {COL4+TILEGAP/2 +11, A_BASE_H} }),

        wendy_shadow_1 = {
            pos = {COL5+TILEGAP/2 +12, A_BASE_H },
            tags = {"allegiance","shadow","shadow_favor"},
            connects = {
                "wendy_shadow_2",
            },

            locks = {"wendy_shadow_lock_1", "wendy_shadow_lock_2"},

            onactivate = function(inst, fromload)
                inst:AddTag("player_shadow_aligned")

                local addresists = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:AddResist("shadow_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:AddBonus("lunar_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
                    end
                end

                addresists(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:AddTag("shadow_aligned")
                    addresists(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
                end
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("player_shadow_aligned")

                local removeresist = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:RemoveResist("shadow_aligned", pref, "allegiance_shadow")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:RemoveBonus("lunar_aligned", pref, "allegiance_shadow")
                    end
                end
                removeresist(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:RemoveTag("shadow_aligned")
                    removeresist(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(0)
                end
            end,

        },
        wendy_shadow_2 = {
            pos = {COL5+(width/11)+TILEGAP/2 +12, A_BASE_H},
            tags = {"allegiance","shadow","shadow_favor"},
            connects = {
                "wendy_shadow_3",
            },
        },
        wendy_shadow_3 = {
            pos = {COL6+TILEGAP/2 +12, A_BASE_H},
            tags = {"allegiance","shadow","shadow_favor"},
        },

        wendy_lunar_lock_1 = SkillTreeFns.MakeCelestialChampionLock({ pos = {COL3+TILEGAP/2 +14,A_BASE_H+TILEGAP}}),
        wendy_lunar_lock_2 = SkillTreeFns.MakeNoShadowLock({ pos = {COL4+TILEGAP/2 +11, A_BASE_H+TILEGAP}}), 

        wendy_lunar_1 = {
            pos = {COL5+TILEGAP/2 +12, A_BASE_H+TILEGAP },
            tags = {"allegiance","lunar","lunar_favor"},
            connects = {
                "wendy_lunar_2",
            },

            locks = {"wendy_lunar_lock_1", "wendy_lunar_lock_2"},

            onactivate = function(inst, fromload)
                inst:AddTag("player_lunar_aligned")

                local addresists = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:AddResist("lunar_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:AddBonus("shadow_aligned", pref, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
                    end
                end

                addresists(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:AddTag("lunar_aligned")
                    addresists(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
                end
            end,

            ondeactivate = function(inst, fromload)
                inst:RemoveTag("player_lunar_aligned")

                local removeresist = function(pref)
                    local damagetyperesist = pref.components.damagetyperesist
                    if damagetyperesist then
                        damagetyperesist:RemoveResist("lunar_aligned", pref, "allegiance_lunar")
                    end
                    local damagetypebonus = pref.components.damagetypebonus
                    if damagetypebonus then
                        damagetypebonus:RemoveBonus("shadow_aligned", pref, "allegiance_lunar")
                    end
                end
                removeresist(inst)
                if inst.components.ghostlybond and inst.components.ghostlybond.ghost then
                    inst.components.ghostlybond.ghost:RemoveTag("lunar_aligned")
                    removeresist(inst.components.ghostlybond.ghost)
                    inst.components.ghostlybond.ghost.components.planardefense:SetBaseDefense(0)
                end
            end,

        },
        wendy_lunar_2 = {
            pos = {COL5+(width/11)+TILEGAP/2 +12, A_BASE_H+TILEGAP},
            tags = {"allegiance","lunar","lunar_favor"},
            connects = {
                "wendy_lunar_3",
            },
        },
        wendy_lunar_3 = {
            pos = {COL6+TILEGAP/2 +12, A_BASE_H+TILEGAP},
            tags = {"allegiance","lunar","lunar_favor"},
        }, 

    }
    finalize_skill_group(allegiance_skills, "wendy_alliegience") --allegiance


    return {
        SKILLS = skills,
        ORDERS = {
         --   {"petal",               {POS_X_1, POS_Y_1 + TILEGAP}},
         --   {"ghost_command",       {POS_X_1 + TILEGAP * 2, POS_Y_1 + TILEGAP}  },
         --   {"sisturn_upgrades",    {POS_X_1 + TILEGAP, POS_Y_1 + TILEGAP}      },
          --  {"smallghost",          {POS_X_1 + TILEGAP * 3, POS_Y_1 + TILEGAP}  },
          --  {"gravestone",          {POS_X_1 + TILEGAP * 4, POS_Y_1 + TILEGAP}  },
          --  {"potion_upgrades",     {POS_X_1 + TILEGAP * 5, POS_Y_1 + TILEGAP}  },
          --  {"allegiance",          {COL5+(width/11), (TILEGAP*2.8) }           },
        },
        PUCK = true,
    }
end

return BuildSkillsData