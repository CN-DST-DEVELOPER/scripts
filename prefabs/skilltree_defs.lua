local SKILLTREE_DEFS = {}
local SKILLTREE_METAINFO = {}

-- Wrapper function to help modders with their strange prefab names and tree validation process.
local function CreateSkillTreeFor(characterprefab, skills)
    local RPC_LOOKUP = {}
    local rpc_id = 0
    for k, v in orderedPairs(skills) do
        v.rpc_id = rpc_id
        RPC_LOOKUP[rpc_id] = k
        rpc_id = rpc_id + 1
        -- NOTES(JBK): If this goes beyond 32 it will not be shown to other players in the inspection panel.
    end
    SKILLTREE_METAINFO[characterprefab] = { -- Must be first for metatable setting.
        RPC_LOOKUP = RPC_LOOKUP,
        TOTAL_SKILLS_COUNT = rpc_id,
    }
    SKILLTREE_DEFS[characterprefab] = skills
end

local function CountTags(prefab, targettag, skillselection)
    local tags = {}
    local dataset = TheSkillTree.activatedskills[prefab]
    if skillselection then
        dataset = skillselection
    end
    if dataset then
        for skill, flag in pairs(dataset) do
            local data =  SKILLTREE_DEFS[prefab][skill]
            for i,tag in ipairs(data.tags) do
                if not tags[tag] then
                    tags[tag] = 0
                end
                tags[tag] = tags[tag] +1
            end
        end
    end
    return tags[targettag] or 0
end

local function CountSkills(prefab, skillselection )
    local count = 0
    local dataset = TheSkillTree.activatedskills[prefab]
    if skillselection then
        dataset = skillselection
    end    
    if dataset then
        for skill, flag in pairs(dataset) do
            count = count + 1
        end
    end
    return count or 0
end



CreateSkillTreeFor("wilson", {
    wilson_alchemy_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_1_DESC,
        icon = "wilson_alchemy_1",
        pos = {-62,176},
        --pos = {1,0},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("alchemist")
            end,
        root = true,
        connects = {
            "wilson_alchemy_2",
            "wilson_alchemy_3",
            "wilson_alchemy_4",
        },
    },
    wilson_alchemy_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_2_DESC,
        icon = "wilson_alchemy_gem_1",
        pos = {-62,176-54},        
        --pos = {0,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistI")
            end,        
        connects = {
            "wilson_alchemy_5",
        },
    },
    wilson_alchemy_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_5_DESC,
        icon = "wilson_alchemy_gem_2",
        pos = {-62,176-54-38},        
        --pos = {0,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistII")
            end,
        connects = {
            "wilson_alchemy_6",
        },
    },
    wilson_alchemy_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_6_DESC,
        icon = "wilson_alchemy_gem_3",
        pos = {-62,176-54-38-38},        
        --pos = {0,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("gem_alchemistIII")
            end,
        connects = {
        },
    },

    wilson_alchemy_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_3_DESC,
        icon = "wilson_alchemy_ore_1",
        pos = {-62-38,176-54},
        --pos = {1,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistI")
            end,
        connects = {
            "wilson_alchemy_7",
        },
    },
    wilson_alchemy_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_7_DESC,
        icon = "wilson_alchemy_ore_2",
        pos = {-62-38,176-54-38},
        --pos = {1,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistII")
            end,        
        connects = {
            "wilson_alchemy_8",
        },
    },
    wilson_alchemy_8 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_8_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_8_DESC,
        icon = "wilson_alchemy_ore_3",
        pos = {-62-38,176-54-38-38},
        --pos = {1,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ore_alchemistIII")
            end,         
        connects = {
        },
    },

    wilson_alchemy_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_4_DESC,
        icon = "wilson_alchemy_iky_1",
        pos = {-62+38,176-54},
        --pos = {2,-1},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistI")
            end,         
        connects = {
            "wilson_alchemy_9",
        },
    },
    wilson_alchemy_9 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_9_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_9_DESC,
        icon = "wilson_alchemy_iky_2",
        pos = {-62+38,176-54-38},
        --pos = {2,-2},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistII")
            end,        
        connects = {
            "wilson_alchemy_10",
        },
    },
    wilson_alchemy_10 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_10_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALCHEMY_10_DESC,
        icon = "wilson_alchemy_iky_3",
        pos = {-62+38,176-54-38-38},
        --pos = {2,-3},
        group = "alchemy",
        tags = {"alchemy"},
        onactivate = function(inst, fromload)
                inst:AddTag("ick_alchemistIII")
            end,        
        connects = {
        },
    },

    wilson_torch_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_DESC,
        icon = "wilson_torch_time_1",
        pos = {-214,176},
        --pos = {0,0},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_1", inst)
                    end
                end
            end,
        root = true,
        connects = {
            "wilson_torch_2",
        },
    },
    wilson_torch_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_2_DESC,
        icon = "wilson_torch_time_2",
        pos = {-214,176-38},
        --pos = {0,-1},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_2", inst)
                    end
                end
            end,        
        connects = {
            "wilson_torch_3",
        },
    },
    wilson_torch_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_3_DESC,
        icon = "wilson_torch_time_3",
        pos = {-214,176-38-38},
        --pos = {0,-2},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload) 
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_3", inst)
                    end
                end
            end,
        connects = {
        },
    },
    wilson_torch_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_4_DESC,
        icon = "wilson_torch_brightness_1",
        pos = {-214+38,176},        
        --pos = {1,0},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_4", inst)
                    end
                end
            end,        
        root = true,
        connects = {
            "wilson_torch_5",
        },
    },
    wilson_torch_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_5_DESC,
        icon = "wilson_torch_brightness_2",
        pos = {-214+38,176-38},
        --pos = {1,-1},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_5", inst)
                    end
                end
            end,        
        connects = {
            "wilson_torch_6",
        },
    },
    wilson_torch_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_6_DESC,
        icon = "wilson_torch_brightness_3",
        pos = {-214+38,176-38-38},
        --pos = {1,-2},
        group = "torch",
        tags = {"torch"},
        onactivate = function(inst, fromload)
                if not fromload then
                    local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if equipped and equipped.applyskilleffect then
                        equipped:applyskilleffect("wilson_torch_5", inst)
                    end
                end
            end,        
        connects = {
        },
    }, 

    wilson_torch_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_1_LOCK_DESC,
        pos = {-214+18,58},
        --pos = {2,0},
        group = "torch",
        tags = {"torch","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) return CountTags(prefabname,"torch", skillselection) > 2 end,
        connects = {
            "wilson_torch_7",
        },
    },
    wilson_torch_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_TORCH_7_DESC,
        icon = "wilson_torch_throw",
        pos = {-214+18,58-38},        
        --pos = {2,-1},
        group = "torch",
        tags = {"torch"},
        connects = {
        },
    },    

    wilson_beard_1 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_DESC,
        icon = "wilson_beard_insulation_1",        
        pos = {66,176},
        --pos = {0,0},
        group = "beard",
        tags = {"beard"},
        root = true,
        connects = {
            "wilson_beard_2",
        },
    },
    wilson_beard_2 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_2_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_2_DESC,
        icon = "wilson_beard_insulation_2",
        pos = {66,176-38},
        --pos = {0,-1},
        group = "beard",
        tags = {"beard"},
        connects = {
            "wilson_beard_3",
        },
    },
    wilson_beard_3 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_3_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_3_DESC,
        icon = "wilson_beard_insulation_3",
        pos = {66,176-38-38},
        --pos = {0,-2},
        group = "beard",
        tags = {"beard"},
        connects = {
        },
    },

    wilson_beard_4 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_4_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_4_DESC,
        icon = "wilson_beard_speed_1",
        pos = {66+38,176},
        --pos = {1,0},
        group = "beard",
        tags = {"beard"},
        root = true,
        connects = {
            "wilson_beard_5",
        },
    },
    wilson_beard_5 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_5_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_5_DESC,
        icon = "wilson_beard_speed_2",
        pos = {66+38,176-38},
        --pos = {1,-1},
        group = "beard",
        tags = {"beard"},
        connects = {
            "wilson_beard_6",
        },
    },
    wilson_beard_6 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_6_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_6_DESC,
        icon = "wilson_beard_speed_3",
        pos = {66+38,176-38-38},
        --pos = {1,-2},
        group = "beard",
        tags = {"beard"},
        connects = {
        },
    },

    wilson_beard_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_1_LOCK_DESC,
        pos = {66+18,58},
        --pos = {2,0},
        group = "beard",
        tags = {"beard","lock"},
        root = true,
        lock_open = function(prefabname,skillselection) return CountTags(prefabname,"beard", skillselection) > 2 end,
        connects = {
            "wilson_beard_7",
        },
    },
    wilson_beard_7 = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_7_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_BEARD_7_DESC,
        icon = "wilson_beard_inventory",
        pos = {66+18,58-38},
        --pos = {2,-1},
        onactivate = function(inst, fromload)
                if inst.components.beard then
                    inst.components.beard:UpdateBeardInventory()
                end
            end,
        group = "beard",
        tags = {"beard"},
        connects = {
        },
    },

    wilson_allegiance_lock_1 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_1_DESC,
        pos = {204+2,176},
        --pos = {0.5,0},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) return CountSkills(prefabname, skillselection) >= 12 end,
        connects = {
            "wilson_allegiance_shadow",
        },
    },

    wilson_allegiance_lock_2 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_2_DESC,
        pos = {204-22+2,176-50+2},  
        --pos = {0,-1},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) 
                if skillselection then
                    return "question"
                end
                return TheGenericKV:GetKV("fuelweaver_killed") == "1"
            end,
        connects = {
            "wilson_allegiance_shadow",
        },
    },

    wilson_allegiance_lock_4 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_4_DESC,
        pos = {204-22+2,176-100+8},  
        --pos = {0,-1},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) 
                if skillselection then
                    return "question"
                end
                if CountTags(prefabname, "lunar_favor", skillselection) > 0 then
                    return nil
                else
                    return true
                end 
            end,
        connects = {
            "wilson_allegiance_shadow",
        },
    },    

    wilson_allegiance_shadow = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_SHADOW_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_SHADOW_DESC,
        icon = "wilson_favor_shadow",
        pos = {204-22+2 ,176-110-38+10},  --  -22
        --pos = {0,-2},
        group = "allegiance",
        tags = {"allegiance","shadow","shadow_favor"},
        locks = {"wilson_allegiance_lock_1", "wilson_allegiance_lock_2", "wilson_allegiance_lock_4"},
        onactivate = function(inst, fromload)
            inst:AddTag("skill_wilson_allegiance_shadow")
            local damagetyperesist = inst.components.damagetyperesist
            if damagetyperesist then
                damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SKILLS.WILSON_ALLEGIANCE_SHADOW_RESIST, "wilson_allegiance_shadow")
            end
            local damagetypebonus = inst.components.damagetypebonus
            if damagetypebonus then
                damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SKILLS.WILSON_ALLEGIANCE_VS_LUNAR_BONUS, "wilson_allegiance_shadow")
            end
        end,
        ondeactivate = function(inst, fromload)
            inst:RemoveTag("skill_wilson_allegiance_shadow")
            local damagetyperesist = inst.components.damagetyperesist
            if damagetyperesist then
                damagetyperesist:RemoveResist("shadow_aligned", inst, "wilson_allegiance_shadow")
            end
            local damagetypebonus = inst.components.damagetypebonus
            if damagetypebonus then
                damagetypebonus:RemoveBonus("lunar_aligned", inst, "wilson_allegiance_shadow")
            end
        end,
        connects = {
        },
    },  

    wilson_allegiance_lock_3 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_3_DESC,
        pos = {204+22+2,176-50+2},
        --pos = {0,-1},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) 
                if skillselection then
                    return "question"
                end 
                return TheGenericKV:GetKV("celestialchampion_killed") == "1"
            end,
        connects = {
            "wilson_allegiance_lunar",
        },
    },

    wilson_allegiance_lock_5 = {
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LOCK_5_DESC,
        pos = {204+22+2,176-100+8},  
        --pos = {0,-1},
        group = "allegiance",
        tags = {"allegiance","lock"},
        root = true,
        lock_open = function(prefabname, skillselection) 
                if skillselection then
                    return "question"
                end
                if CountTags(prefabname, "shadow_favor", skillselection) > 0 then
                    return nil
                else 
                    return true
                end
            end,
        connects = {
            "wilson_allegiance_lunar",
        },
    },

    wilson_allegiance_lunar = {
        title = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LUNAR_TITLE,
        desc = STRINGS.SKILLTREE.WILSON.WILSON_ALLEGIANCE_LUNAR_DESC,
        icon = "wilson_favor_lunar",
        pos = {204+22+2 ,176-110-38+10},
        --pos = {0,-2},
        group = "allegiance",
        tags = {"allegiance","lunar","lunar_favor"},
        locks = {"wilson_allegiance_lock_1", "wilson_allegiance_lock_3","wilson_allegiance_lock_5"},
        onactivate = function(inst, fromload)
            inst:AddTag("skill_wilson_allegiance_lunar")
            local damagetyperesist = inst.components.damagetyperesist
            if damagetyperesist then
                damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WILSON_ALLEGIANCE_LUNAR_RESIST, "wilson_allegiance_lunar")
            end
            local damagetypebonus = inst.components.damagetypebonus
            if damagetypebonus then
                damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WILSON_ALLEGIANCE_VS_SHADOW_BONUS, "wilson_allegiance_lunar")
            end
        end,
        ondeactivate = function(inst, fromload)
            inst:RemoveTag("skill_wilson_allegiance_lunar")
            local damagetyperesist = inst.components.damagetyperesist
            if damagetyperesist then
                damagetyperesist:RemoveResist("lunar_aligned", inst, "wilson_allegiance_lunar")
            end
            local damagetypebonus = inst.components.damagetypebonus
            if damagetypebonus then
                damagetypebonus:RemoveBonus("shadow_aligned", inst, "wilson_allegiance_lunar")
            end
        end,
        connects = {
        },
    },    

})

setmetatable(SKILLTREE_DEFS, {
    __newindex = function(t, k, v)
        SKILLTREE_METAINFO[k].modded = true
        rawset(t, k, v)
    end,
})

local function SkillHasTags(skill, tag, prefabname)
    if not SKILLTREE_DEFS[prefabname] or not SKILLTREE_DEFS[prefabname][skill] then
        return nil
    end
   
    for i, stag in pairs(SKILLTREE_DEFS[prefabname][skill].tags) do
        if tag == stag then
            return true
        end
    end
end

local FN = {
    CountSkills = CountSkills,
    CountTags = CountTags,
    SkillHasTags = SkillHasTags,
}



local SKILLTREE_ORDERS = {
    wilson = {
            {"torch",           { -214+18   , 176 + 30 }},
            {"alchemy",         { -62       , 176 + 30 }},
            {"beard",           { 66+18     , 176 + 30 }},
            {"allegiance",      { 204       , 176 + 30 }},
          },
}

return {SKILLTREE_DEFS = SKILLTREE_DEFS, SKILLTREE_METAINFO = SKILLTREE_METAINFO, CreateSkillTreeFor = CreateSkillTreeFor, SKILLTREE_ORDERS = SKILLTREE_ORDERS, FN = FN}
