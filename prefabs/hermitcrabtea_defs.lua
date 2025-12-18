local TEA_DEFS =
{
    {
        name = "petals",
        buff = "hermitcrabtea_petals_buff",
        --
        sanityvalue = TUNING.SANITY_SMALL,
    },
    {
        name = "petals_evil",
        buff = "hermitcrabtea_petals_evil_buff",
        --
        sanityvalue = -TUNING.SANITY_MED,
    },
    {
        name = "foliage",
        buff = "hermitcrabtea_foliage_buff",
        --
        sanityvalue = TUNING.SANITY_TINY,
    },
    {
        name = "succulent_picked",
        -- buff = "",
        --
        temperaturedelta = TUNING.HERMITCRABTEA_COLD_BONUS_TEMP,
        temperatureduration = TUNING.HERMITCRABTEA_TEMP_TIME,
        --
        sanityvalue = TUNING.SANITY_TINY,
        healthvalue = TUNING.HEALING_MEDSMALL,
    },
    {
        name = "firenettles",
        -- buff = "",
        --
        temperaturedelta = TUNING.HERMITCRABTEA_HOT_BONUS_TEMP,
        temperatureduration = TUNING.HERMITCRABTEA_TEMP_TIME,
        --
        sanityvalue = TUNING.SANITY_TINY,
    },
    {
        name = "tillweed",
        buff = "hermitcrabtea_tillweed_buff",
        --
        sanityvalue = TUNING.SANITY_TINY,
        healthvalue = TUNING.HEALING_MED,
    },
    {
        name = "moon_tree_blossom",
        buff = "hermitcrabtea_moon_tree_blossom_buff",
        --
        sanityvalue = TUNING.SANITY_SMALL,
    },
    {
        name = "forgetmelots",
        buff = "hermitcrabtea_forgetmelots_buff",
        --
        sanityvalue = TUNING.SANITY_MEDLARGE,
    },
}

---------------------

-- petals

local function Petals_OnTick(inst, target)
    if not IsEntityDead(target) and target.components.sanity ~= nil and not target:HasTag("playerghost") then
        target.components.sanity:DoDelta(TUNING.HERMITCRAB_PETALTEA_SANITY_DELTA)
    else
        inst.components.debuff:Stop()
    end
end

-- petals_evil

local function Petals_Evil_OnTick(inst, target)
    if not IsEntityDead(target) and target.components.sanity ~= nil and not target:HasTag("playerghost") then
        target.components.sanity:DoDelta(TUNING.HERMITCRAB_EVILPETALTEA_SANITY_DELTA)
    else
        inst.components.debuff:Stop()
    end
end

-- tillweed

local function Tillweed_OnTick(inst, target)
    if not IsEntityDead(target, true) and not target:HasTag("playerghost") then
        target.components.health:DoDelta(TUNING.HERMITCRAB_TILLWEEDTEA_HEALTH_DELTA, nil, "hermitcrabtea_tillweed")
    else
        inst.components.debuff:Stop()
    end
end

-- forgetmelots

local function ForgetMeLots_OnTick(inst, target)
    if not IsEntityDead(target) and target.components.sanity ~= nil and not target:HasTag("playerghost") then
        target.components.sanity:DoDelta(TUNING.HERMITCRAB_FORGETMELOTTEA_SANITY_DELTA)
    else
        inst.components.debuff:Stop()
    end
end

-- moon_tree_blossom

local hitsparks_fx_colouroverride = { 0, 0, 1 }
local function SparkLunarOnShadow(inst, attacker)
    local spark = SpawnPrefab("hitsparks_fx")
    spark:Setup(attacker, inst, nil, hitsparks_fx_colouroverride)
end
local function ClearShadowPanic(inst)
    inst._shadow_creature_panic_task = nil
end
local function MoonBlossom_OnAttacked(inst, data)
    local attacker = data ~= nil and data.attacker
    if attacker and attacker:IsValid() and attacker:HasTag("shadowsubmissive") then
        SparkLunarOnShadow(inst, attacker)
        if attacker._detach_from_boat_fn ~= nil then -- Terrorclaw.
            attacker._detach_from_boat_fn(attacker)
        end
        if attacker._shadow_creature_panic_task ~= nil then
            attacker._shadow_creature_panic_task:Cancel()
        end
        attacker._shadow_creature_panic_task = attacker:DoTaskInTime(TUNING.HERMITCRAB_MOONTREEBLOSSOMTEA_PANIC_SHADOWCREATURE_TIME, ClearShadowPanic)
    end
end

local BUFF_DEFS =
{
    {
        name = "petals",
        duration = TUNING.HERMITCRAB_PETALTEA_DURATION,
        --
        onattachedfn = function(inst, target)
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_PETALTEA_TICK_RATE, Petals_OnTick, nil, target)
        end,

        onextendedfn = function(inst, target)
            inst.task:Cancel()
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_PETALTEA_TICK_RATE, Petals_OnTick, nil, target)
        end,
    },

    {
        name = "petals_evil",
        duration = TUNING.HERMITCRAB_EVILPETALTEA_DURATION,
        --
        onattachedfn = function(inst, target)
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_EVILPETALTEA_TICK_RATE, Petals_Evil_OnTick, nil, target)
        end,

        onextendedfn = function(inst, target)
            inst.task:Cancel()
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_EVILPETALTEA_TICK_RATE, Petals_Evil_OnTick, nil, target)
        end,
    },

    {
        name = "foliage",
        duration = TUNING.HERMITCRAB_FOLIAGETEA_DURATION,
        --
        onattachedfn = function(inst, target)
            if target.components.sanity ~= nil then
		        target.components.sanity.neg_aura_modifiers:SetModifier(inst, TUNING.HERMITCRAB_FOLIAGETEA_SANITY_MOD)
	        end
        end,

        onextendedfn = function(inst, target)
            if target.components.sanity ~= nil then
		        target.components.sanity.neg_aura_modifiers:SetModifier(inst, TUNING.HERMITCRAB_FOLIAGETEA_SANITY_MOD)
	        end
        end,

        ondetachedfn = function(inst, target)
            if target.components.sanity ~= nil then
		        target.components.sanity.neg_aura_modifiers:RemoveModifier(inst)
	        end
        end,
    },

    {
        name = "succulent_picked",
        --
        onattachedfn = function(inst)

        end,

        onextendedfn = function(inst)

        end,

        ondetachedfn = function(inst)

        end,
    },

    {
        name = "firenettles",
        --
        onattachedfn = function(inst)

        end,

        onextendedfn = function(inst)

        end,

        ondetachedfn = function(inst)

        end,
    },

    {
        name = "tillweed",
        duration = TUNING.HERMITCRAB_TILLWEEDTEA_DURATION,
        --
        onattachedfn = function(inst, target)
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_TILLWEEDTEA_TICK_RATE, Tillweed_OnTick, nil, target)
        end,

        onextendedfn = function(inst, target)
            inst.task:Cancel()
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_TILLWEEDTEA_TICK_RATE, Tillweed_OnTick, nil, target)
        end,
    },

    {
        name = "moon_tree_blossom",
        duration = TUNING.HERMITCRAB_MOONTREEBLOSSOMTEA_DURATION,
        --
        onattachedfn = function(inst, target)
            target:ListenForEvent("attacked", MoonBlossom_OnAttacked)
        end,

        onextendedfn = function(inst, target)
            target:RemoveEventCallback("attacked", MoonBlossom_OnAttacked)
            target:ListenForEvent("attacked", MoonBlossom_OnAttacked)
        end,

        ondetachedfn = function(inst, target)
            target:RemoveEventCallback("attacked", MoonBlossom_OnAttacked)
        end,
    },

    {
        name = "forgetmelots",
        duration = TUNING.HERMITCRAB_FORGETMELOTTEA_DURATION,
        --
        onattachedfn = function(inst, target)
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_FORGETMELOTTEA_TICK_RATE, ForgetMeLots_OnTick, nil, target)
        end,

        onextendedfn = function(inst, target)
            inst.task:Cancel()
            inst.task = inst:DoPeriodicTask(TUNING.HERMITCRAB_FORGETMELOTTEA_TICK_RATE, ForgetMeLots_OnTick, nil, target)
        end,
    },
}

--[[ Omar: For searching
hermitcrabtea_petals
hermitcrabtea_petals_evil
hermitcrabtea_foliage
hermitcrabtea_succulent_picked
hermitcrabtea_firenettles
hermitcrabtea_tillweed
hermitcrabtea_moon_tree_blossom
hermitcrabtea_forgetmelots

hermitcrabtea_petals_buff
hermitcrabtea_petals_evil_buff
hermitcrabtea_foliage_buff
hermitcrabtea_succulent_picked_buff
hermitcrabtea_firenettles_buff
hermitcrabtea_tillweed_buff
hermitcrabtea_moon_tree_blossom_buff
hermitcrabtea_forgetmelots_buff
]]
return {
    teas = TEA_DEFS,
    buffs = BUFF_DEFS,
}