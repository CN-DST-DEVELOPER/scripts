local WX78Common = require("prefabs/wx78_common")

local module_definitions = {}
local scandata_definitions = {}
local scandata_special_definitions = {}

-- Add a new creature/module/scandata combination for the scanner.
--      prefab_name -   The prefab name of the object to scan in the world.
--      module_name -   The type name of the module that will be produced by the scan (without the "wx78module_" prefix)
--      maxdata -       The maximum amount of data that will build up on the scannable prefab; see "dataanalyzer.lua"
-- Calling this function using a prefab name that has already been added will overwrite that prefab's prior entry.
local function AddCreatureScanDataDefinition(prefab_name, module_name, maxdata, recipename)
    scandata_definitions[prefab_name] = {
        maxdata = maxdata or 1,
        module = module_name,
        recipename = recipename or nil, -- optional
    }
end

-- A special scan instance that uses a function to check if its this scan. (E.g. scanning a creature with Shadow Parasite mask on)
--      id - unique string identifier for this type of special scan
--      module_name -   The type name of the module that will be produced by the scan (without the "wx78module_" prefix)
--      maxdata -       The maximum amount of data that will build up on the scannable prefab; see "dataanalyzer.lua"
--      checkfn - The function to determine if this is the type of scan we should do on the creature
local function AddSpecialCreatureScanDataDefinition(id, checkfn, module_name, maxdata)
    scandata_definitions[id] = {
        maxdata = maxdata or 1,
        module = module_name,
    }

    table.insert(scandata_special_definitions, {
        id = id,
        checkfn = checkfn,
    })
end

-- Given a creature prefab, return any module/data information for it, if it exists.
local function GetCreatureScanDataDefinition(ent_or_id)
    if type(ent_or_id) == "string" then
        return scandata_definitions[ent_or_id], ent_or_id
    end

    for k, v in ipairs(scandata_special_definitions) do
        if v.checkfn(ent_or_id, v.id) then
            return scandata_definitions[v.id], v.id
        end
    end
    --
    local prefab_name = ent_or_id.prefab
    return scandata_definitions[prefab_name], prefab_name
end
--

local function IsSkillActivated(wx, skill)
    local skilltreeupdater = wx.components.skilltreeupdater
    if skilltreeupdater == nil and wx.components.follower ~= nil then
        local leader = wx.components.follower:GetLeader()
        skilltreeupdater = leader and leader.components.skilltreeupdater
    end
    return skilltreeupdater and skilltreeupdater:IsActivated(skill)
end

local function Circuit_SetUpSkillCb(inst, wx, skillnames, activatecb, deactivatecb, isloading)
    local is_one_skill = type(skillnames) == "string"
    local skilltreeupdater = wx.components.skilltreeupdater
    if skilltreeupdater == nil and wx.components.follower ~= nil then
        local leader = wx.components.follower:GetLeader()
        skilltreeupdater = leader and leader.components.skilltreeupdater
    end

    if skilltreeupdater then
        local do_activate = false
        if is_one_skill then
            do_activate = skilltreeupdater:IsActivated(skillnames)
        else
            for skill in pairs(skillnames) do
                if skilltreeupdater:IsActivated(skill) then
                    do_activate = true
                    break
                end
            end
        end

        if do_activate then
            activatecb(inst, wx, isloading)
            inst._circuit_skill_activated = true
        end
    end

    inst._onactivateskill_handler = function(_, data)
        if (is_one_skill and data.skill == skillnames) or (not is_one_skill and skillnames[data.skill]) then
            activatecb(inst, wx, isloading, true)
            inst._circuit_skill_activated = true
        end
    end
    inst._ondeactivateskill_handler = function(_, data)
        if (is_one_skill and data.skill == skillnames) or (not is_one_skill and skillnames[data.skill]) or data.force then
            deactivatecb(inst, wx, isloading)
            inst._circuit_skill_activated = nil
        end
    end

    if wx.isplayer then
        inst:ListenForEvent("onactivateskill_server", inst._onactivateskill_handler, wx)
        inst:ListenForEvent("ondeactivateskill_server", inst._ondeactivateskill_handler, wx)
    elseif wx.components.follower ~= nil then
        inst._onleaderchanged_handler = function(_, data)
            local oldleader = data.old
            if oldleader ~= nil then
                inst:RemoveEventCallback("onactivateskill_server", inst._onactivateskill_handler, oldleader)
                inst:RemoveEventCallback("ondeactivateskill_server", inst._ondeactivateskill_handler, oldleader)
            end

            local newleader = data.new
            if newleader ~= nil then
                inst:ListenForEvent("onactivateskill_server", inst._onactivateskill_handler, newleader)
                inst:ListenForEvent("ondeactivateskill_server", inst._ondeactivateskill_handler, newleader)
            end
        end
        local leader = wx.components.follower:GetLeader()
        if leader ~= nil then
            inst:ListenForEvent("onactivateskill_server", inst._onactivateskill_handler, leader)
            inst:ListenForEvent("ondeactivateskill_server", inst._ondeactivateskill_handler, leader)
        end
        inst:ListenForEvent("leaderchanged", inst._onleaderchanged_handler, wx)
    end
end

local function Circuit_DestroySkillCb(inst, wx)
    if inst._circuit_skill_activated then
        inst._ondeactivateskill_handler(wx, { force = true })
    end

    if wx.isplayer then
        inst:RemoveEventCallback("onactivateskill_server", inst._onactivateskill_handler, wx)
        inst:RemoveEventCallback("ondeactivateskill_server", inst._ondeactivateskill_handler, wx)
    elseif wx.components.follower ~= nil then
        local leader = wx.components.follower:GetLeader()
        if leader ~= nil then
            inst:RemoveEventCallback("onactivateskill_server", inst._onactivateskill_handler, leader)
            inst:RemoveEventCallback("ondeactivateskill_server", inst._ondeactivateskill_handler, leader)
        end
        inst:RemoveEventCallback("leaderchanged", inst._onleaderchanged_handler, wx)
    end
    inst._onactivateskill_handler = nil
    inst._ondeactivateskill_handler = nil
    inst._onleaderchanged_handler = nil
end

---------------------------------------------------------------

local function GetHealthCircuitArmor(wx)
    local base_armor = TUNING.SKILLS.WX78.MAXHEALTH_ARMOR_ALPHABUFF_2
    local armor = 0
    if IsSkillActivated(wx, "wx78_circuitry_alphabuffs_2") then
        for k, v in ipairs(wx.components.upgrademoduleowner:GetAllModules()) do
            if v._skill_health_armor_mult and v.components.upgrademodule.activated then
                armor = armor + (base_armor * v._skill_health_armor_mult)
            end
        end
    end
    return armor
end

local function maxhealth_skill_updatearmor(inst, wx, isloading)
    if wx.components.combat then
        local damagetakenmult = 1 - GetHealthCircuitArmor(wx)
        wx.components.combat.externaldamagetakenmultipliers:SetModifier(wx, damagetakenmult, "maxhealthmoduleskill")
    end
end

local function maxhealth_skill_activate(inst, wx, isloading)
    maxhealth_skill_updatearmor(inst, wx, isloading)
end

local function maxhealth_skill_deactivate(inst, wx)
    maxhealth_skill_updatearmor(inst, wx)
end

local function maxhealth_change(inst, wx, amount, isloading)
    if wx.components.health then
        local current_health_percent = wx.components.health:GetPercent()

        wx.components.health.maxhealth = wx.components.health.maxhealth + amount

        if not isloading then
            wx.components.health:SetPercent(current_health_percent)
            local up = amount > 0
            wx:PushEvent("forcehealthpulse", { up = up, down = not up })
        end
    end
end

local HEALTH_BUFF_SKILLS =
{
    ["wx78_circuitry_alphabuffs_1"] = true,
    ["wx78_circuitry_alphabuffs_2"] = true,
}
local function maxhealth_activate(inst, wx, isloading)
    inst._skill_health_armor_mult = 1
    maxhealth_change(inst, wx, TUNING.WX78_MAXHEALTH_BOOST, isloading)
    Circuit_SetUpSkillCb(inst, wx, HEALTH_BUFF_SKILLS, maxhealth_skill_activate, maxhealth_skill_deactivate, isloading)
end

local function maxhealth_deactivate(inst, wx)
    maxhealth_change(inst, wx, -TUNING.WX78_MAXHEALTH_BOOST)
    Circuit_DestroySkillCb(inst, wx)
end

local MAXHEALTH_MODULE_DATA =
{
    name = "maxhealth",
    type = CIRCUIT_BARS.ALPHA,
    slots = 1,
    activatefn = maxhealth_activate,
    deactivatefn = maxhealth_deactivate,
}
table.insert(module_definitions, MAXHEALTH_MODULE_DATA)

AddCreatureScanDataDefinition("spider", "maxhealth", 2)

---------------------------------------------------------------

local function GetEquippableDapperness(owner, equippable)
    local dapperness = equippable:GetDapperness(owner, owner.components.sanity.no_moisture_penalty)

    if dapperness > 0 then
        local dapperness_mult = 1

        if IsSkillActivated(owner, "wx78_circuitry_alphabuffs_2") then
            for k, v in ipairs(owner.components.upgrademoduleowner:GetAllModules()) do
                if v._skill_sanity_dapperness_mult and v.components.upgrademodule.activated then
                    dapperness_mult = dapperness_mult + v._skill_sanity_dapperness_mult
                end
            end
        end

        return dapperness * dapperness_mult
    end

    return dapperness
end

local function sanity_skill_activate(inst, wx, isloading, sanitymod)
    if wx.components.sanity then
        wx.components.sanity.get_equippable_dappernessfn = GetEquippableDapperness
        wx.components.sanity.neg_aura_modifiers:SetModifier(inst, sanitymod)
    end
end

local function sanity_skill_deactivate(inst, wx)
    if wx.components.sanity then
        wx.components.sanity.neg_aura_modifiers:RemoveModifier(inst)
    end
end

local function maxsanity1_skill_activate(inst, wx, isloading)
    sanity_skill_activate(inst, wx, isloading, TUNING.SKILLS.WX78.MAXSANITY1_SANITY_MOD_ALPHABUFF)
end

local function maxsanity1_skill_deactivate(inst, wx)
    sanity_skill_deactivate(inst, wx)
end

local SANITY_BUFF_SKILLS =
{
    ["wx78_circuitry_alphabuffs_1"] = true,
    ["wx78_circuitry_alphabuffs_2"] = true,
}
local function maxsanity1_activate(inst, wx, isloading)
    inst._skill_sanity_dapperness_mult = TUNING.SKILLS.WX78.MAXSANITY1_DAPPERNESS_MULT
    if wx.components.sanity then
        local current_sanity_percent = wx.components.sanity:GetPercent()

        wx.components.sanity:SetMax(wx.components.sanity.max + TUNING.WX78_MAXSANITY1_BOOST)

        if not isloading then
            wx.components.sanity:SetPercent(current_sanity_percent, false)
        end
    end
    Circuit_SetUpSkillCb(inst, wx, SANITY_BUFF_SKILLS, maxsanity1_skill_activate, maxsanity1_skill_deactivate, isloading)
end

local function maxsanity1_deactivate(inst, wx)
    if wx.components.sanity then
        local current_sanity_percent = wx.components.sanity:GetPercent()
        wx.components.sanity:SetMax(wx.components.sanity.max - TUNING.WX78_MAXSANITY1_BOOST)
        wx.components.sanity:SetPercent(current_sanity_percent, false)
    end
    Circuit_DestroySkillCb(inst, wx)
end

local MAXSANITY1_MODULE_DATA =
{
    name = "maxsanity1",
    type = CIRCUIT_BARS.ALPHA,
    slots = 1,
    activatefn = maxsanity1_activate,
    deactivatefn = maxsanity1_deactivate,
}
table.insert(module_definitions, MAXSANITY1_MODULE_DATA)

AddCreatureScanDataDefinition("butterfly", "maxsanity1", 1)
AddCreatureScanDataDefinition("moonbutterfly", "maxsanity1", 1)

---------------------------------------------------------------

local function maxsanity_skill_activate(inst, wx, isloading)
    sanity_skill_activate(inst, wx, isloading, TUNING.SKILLS.WX78.MAXSANITY_SANITY_MOD_ALPHABUFF)
end

local function maxsanity_skill_deactivate(inst, wx)
    sanity_skill_deactivate(inst, wx)
end

local function maxsanity_activate(inst, wx, isloading, skipskillcbsetup)
    inst._skill_sanity_dapperness_mult = TUNING.SKILLS.WX78.MAXSANITY_DAPPERNESS_MULT
    if wx.components.sanity then
        local current_sanity_percent = wx.components.sanity:GetPercent()

        wx.components.sanity.dapperness = wx.components.sanity.dapperness + TUNING.WX78_MAXSANITY_DAPPERNESS
        wx.components.sanity:SetMax(wx.components.sanity.max + TUNING.WX78_MAXSANITY_BOOST)

        if not isloading then
            wx.components.sanity:SetPercent(current_sanity_percent, false)
        end
    end
    if not skipskillcbsetup then
        Circuit_SetUpSkillCb(inst, wx, SANITY_BUFF_SKILLS, maxsanity_skill_activate, maxsanity_skill_deactivate, isloading)
    end
end

local function maxsanity_deactivate(inst, wx, skipskillcbdestroy)
    if wx.components.sanity then
        local current_sanity_percent = wx.components.sanity:GetPercent()

        wx.components.sanity.dapperness = wx.components.sanity.dapperness - TUNING.WX78_MAXSANITY_DAPPERNESS
        wx.components.sanity:SetMax(wx.components.sanity.max - TUNING.WX78_MAXSANITY_BOOST)
        wx.components.sanity:SetPercent(current_sanity_percent, false)
    end
    if not skipskillcbdestroy then
        Circuit_DestroySkillCb(inst, wx)
    end
end

local MAXSANITY_MODULE_DATA =
{
    name = "maxsanity",
    type = CIRCUIT_BARS.ALPHA,
    slots = 2,
    activatefn = maxsanity_activate,
    deactivatefn = maxsanity_deactivate,
}
table.insert(module_definitions, MAXSANITY_MODULE_DATA)

AddCreatureScanDataDefinition("crawlinghorror", "maxsanity", 3)
AddCreatureScanDataDefinition("crawlingnightmare", "maxsanity", 6)
AddCreatureScanDataDefinition("terrorbeak", "maxsanity", 3)
AddCreatureScanDataDefinition("nightmarebeak", "maxsanity", 6)
AddCreatureScanDataDefinition("oceanhorror", "maxsanity", 3)
AddCreatureScanDataDefinition("ruinsnightmare", "maxsanity", 8)

---------------------------------------------------------------

local BASE_SLOW_MULTIPLIER = 0.6 -- this is the base slow multiplier of the player
local function movespeed_updaterunspeed(wx)
    local mult = 1 + TUNING.WX78_MOVESPEED_CHIPBOOSTS[wx._movespeed_chips + 1]
    if wx.components.playerspeedmult then
        --V2C: playerspeedmult does not stack with mount speed
        wx.components.playerspeedmult:SetSpeedMult("wx_movespeed_chip", mult)
    elseif wx.components.locomotor then -- for possessed body
        wx.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * mult
    end

    if wx.components.locomotor and wx.ModifySpeedMultiplier then
        wx.components.locomotor:SetSlowMultiplier(wx:ModifySpeedMultiplier(BASE_SLOW_MULTIPLIER))
    end
end

local function movespeed_updateskill(inst, wx, isloading)
    movespeed_updaterunspeed(wx)
end

local function movespeed_activate(inst, wx, isloading)
    wx._movespeed_chips = (wx._movespeed_chips or 0) + 1
    movespeed_updaterunspeed(wx)
    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_2", movespeed_updateskill, movespeed_updateskill, isloading)
end

local function movespeed_deactivate(inst, wx)
    wx._movespeed_chips = math.max(0, wx._movespeed_chips - 1)
    movespeed_updaterunspeed(wx)
    Circuit_DestroySkillCb(inst, wx)
end

local MOVESPEED_MODULE_DATA =
{
    name = "movespeed",
    type = CIRCUIT_BARS.BETA,
    slots = 6,
    activatefn = movespeed_activate,
    deactivatefn = movespeed_deactivate,
}
table.insert(module_definitions, MOVESPEED_MODULE_DATA)

AddCreatureScanDataDefinition("rabbit", "movespeed", 2)

---------------------------------------------------------------

local MOVESPEED2_MODULE_DATA =
{
    name = "movespeed2",
    type = CIRCUIT_BARS.BETA,
    slots = 2,
    activatefn = movespeed_activate,
    deactivatefn = movespeed_deactivate,
}
table.insert(module_definitions, MOVESPEED2_MODULE_DATA)

AddCreatureScanDataDefinition("minotaur", "movespeed2", 6)
AddCreatureScanDataDefinition("rook", "movespeed2", 3)
AddCreatureScanDataDefinition("rook_nightmare", "movespeed2", 3)

---------------------------------------------------------------

-- A higher mintemp means that it's harder to freeze.
-- A lower maxtemp means that it's harder to overheat.
-- we clamp our temps, because we shouldnt get TOO hot or too cold.. keep in mind networking constraints
-- player can go from -105 to 99 temperature before things overflow/underflow
local MIN_TEMP = TUNING.MIN_ENTITY_TEMP
local MAX_TEMP = TUNING.MAX_ENTITY_TEMP
local function update_temperature_temps(inst, wx)
    local heat_count = wx._heat_modcount or 0
    local cold_count = wx._cold_modcount or 0

    if wx.components.temperature then
        local heat_tempchange = heat_count * TUNING.WX78_MINTEMPCHANGEPERMODULE
        local cold_tempchange = cold_count * TUNING.WX78_MINTEMPCHANGEPERMODULE
        wx.components.temperature.mintemp = math.clamp(MIN_TEMP - cold_tempchange + heat_tempchange, MIN_TEMP, MAX_TEMP)
        wx.components.temperature.maxtemp = math.clamp(MAX_TEMP - cold_tempchange + heat_tempchange, MIN_TEMP, MAX_TEMP)
    end
end

local function update_temperature_overlays(wx) -- from both heat and cold circuits
    if wx.SetFreezingEffectBlockModifier ~= nil then
        wx:SetFreezingEffectBlockModifier(wx, wx.components.temperature.mintemp >= 0)
    end

    if wx.SetOverheatingEffectBlockModifier ~= nil then
        wx:SetOverheatingEffectBlockModifier(wx, wx.components.temperature.maxtemp <= TUNING.OVERHEAT_TEMP)
    end
end

local function heat_freezeimmune_redirect()
    return true -- return true to be immune to freezing
end

local BASE_PLAYER_FREEZE_RESISTANCE = 4
local function heat_skill_updatefreezable(inst, wx)
    if wx.components.freezable then
        if wx._heat_modcount >= 2 then
            wx.components.freezable:SetRedirectFn(heat_freezeimmune_redirect)
        else
            local freezeresistance_mult = wx._heat_modcount * TUNING.SKILLS.WX78.HEAT_FREEZE_RESISTANCE
            wx.components.freezable:SetRedirectFn(nil)
            wx.components.freezable:SetResistance(math.max(BASE_PLAYER_FREEZE_RESISTANCE, BASE_PLAYER_FREEZE_RESISTANCE * freezeresistance_mult))
        end
    end
end

local EXTRA_DRYRATE = 0.1
local function heat_activate(inst, wx, isloading)
    wx._heat_modcount = (wx._heat_modcount or 0) + 1

    update_temperature_temps(inst, wx)

    if wx.components.moisture then
        wx.components.moisture.maxDryingRate = wx.components.moisture.maxDryingRate + EXTRA_DRYRATE
        wx.components.moisture.baseDryingRate = wx.components.moisture.baseDryingRate + EXTRA_DRYRATE
    end

    update_temperature_overlays(wx)

    if wx.AddTemperatureModuleLeaning then
        wx:AddTemperatureModuleLeaning(1)
    end

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_1", heat_skill_updatefreezable, heat_skill_updatefreezable, isloading)
end

local function heat_deactivate(inst, wx)
    wx._heat_modcount = math.max(0, wx._heat_modcount - 1)

    update_temperature_temps(inst, wx)

    if wx.components.moisture then
        wx.components.moisture.maxDryingRate = wx.components.moisture.maxDryingRate - EXTRA_DRYRATE
        wx.components.moisture.baseDryingRate = wx.components.moisture.baseDryingRate - EXTRA_DRYRATE
    end

    update_temperature_overlays(wx)

    if wx.AddTemperatureModuleLeaning then
        wx:AddTemperatureModuleLeaning(-1)
    end

    Circuit_DestroySkillCb(inst, wx)
end

local HEAT_MODULE_DATA =
{
    name = "heat",
    type = CIRCUIT_BARS.BETA,
    slots = 3,
    activatefn = heat_activate,
    deactivatefn = heat_deactivate,
}
table.insert(module_definitions, HEAT_MODULE_DATA)

AddCreatureScanDataDefinition("firehound", "heat", 4)
AddCreatureScanDataDefinition("cave_vent_mite", "heat", 8)
AddCreatureScanDataDefinition("dragonfly", "heat", 10)

---------------------------------------------------------------

local function OnNightVisionUpdate(inst)
    local playervision = inst.components.playervision
    if playervision then
        local on = TheWorld.state.isnight and not TheWorld.state.isfullmoon
        if on then
            local nonightvisioncc = inst.components.skilltreeupdater:IsActivated("wx78_circuitry_betabuffs_1")
            playervision:PushForcedNightVision(inst, 0, nil, nil, nil, nonightvisioncc)
        else
            playervision:PopForcedNightVision(inst)
        end
    end
end

-- inst is module inst on server, and wx78 classified on client
local function nightvision_common_activate(inst, wx)
    wx._nightvision_modcount = (wx._nightvision_modcount or 0) + 1

    if wx._nightvision_modcount == 1 then
        wx:WatchWorldState("isnight", OnNightVisionUpdate)
        wx:WatchWorldState("isfullmoon", OnNightVisionUpdate)
        wx:ListenForEvent("onactivateskill_client", OnNightVisionUpdate)
        wx:ListenForEvent("ondeactivateskill_client", OnNightVisionUpdate)
        OnNightVisionUpdate(wx)
    end
end

local function nightvision_common_deactivate(inst, wx)
    wx._nightvision_modcount = math.max(0, (wx._nightvision_modcount or 0) - 1)

    if wx._nightvision_modcount == 0 then
        wx:StopWatchingWorldState("isnight", OnNightVisionUpdate)
        wx:StopWatchingWorldState("isfullmoon", OnNightVisionUpdate)
        wx:RemoveEventCallback("onactivateskill_client", OnNightVisionUpdate)
        wx:RemoveEventCallback("ondeactivateskill_client", OnNightVisionUpdate)
        if wx.components.playervision then
            wx.components.playervision:PopForcedNightVision(wx)
        end
    end
end

local NIGHTVISION_MODULE_DATA =
{
    name = "nightvision",
    type = CIRCUIT_BARS.BETA,
    slots = 4,
    activatefn = nightvision_common_activate,
    deactivatefn = nightvision_common_deactivate,

    client_activatefn = nightvision_common_activate,
    client_deactivatefn = nightvision_common_deactivate,
}
table.insert(module_definitions, NIGHTVISION_MODULE_DATA)

AddCreatureScanDataDefinition("mole", "nightvision", 4)

---------------------------------------------------------------

local function cold_skill_activate(inst, wx, isloading)
    if wx.components.health then
        wx.components.health.fire_damage_scale = wx.components.health.fire_damage_scale - TUNING.SKILLS.WX78.COLD_FIRE_DAMAGE_SCALE
    end
end

local function cold_skill_deactivate(inst, wx, isloading)
    if wx.components.health then
        wx.components.health.fire_damage_scale = wx.components.health.fire_damage_scale + TUNING.SKILLS.WX78.COLD_FIRE_DAMAGE_SCALE
    end
end

local function cold_activate(inst, wx, isloading)
    wx._cold_modcount = (wx._cold_modcount or 0) + 1

    update_temperature_temps(inst, wx)

    if wx.AddTemperatureModuleLeaning then
        wx:AddTemperatureModuleLeaning(-1)
    end

    update_temperature_overlays(wx)

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_1", cold_skill_activate, cold_skill_deactivate, isloading)
end

local function cold_deactivate(inst, wx)
    wx._cold_modcount = math.max(0, wx._cold_modcount - 1)

    update_temperature_temps(inst, wx)

    if wx.AddTemperatureModuleLeaning then
        wx:AddTemperatureModuleLeaning(1)
    end

    update_temperature_overlays(wx)

    Circuit_DestroySkillCb(inst, wx)
end

local COLD_MODULE_DATA =
{
    name = "cold",
    type = CIRCUIT_BARS.BETA,
    slots = 3,
    activatefn = cold_activate,
    deactivatefn = cold_deactivate,
}
table.insert(module_definitions, COLD_MODULE_DATA)

AddCreatureScanDataDefinition("icehound", "cold", 4)
AddCreatureScanDataDefinition("deerclops", "cold", 10)

---------------------------------------------------------------
local function taser_cooldown(inst)
    inst._cdtask = nil
end

local function taser_onblockedorattacked(wx, data, inst)
    if (data ~= nil and data.attacker ~= nil and not data.redirected) and inst._cdtask == nil then
        inst._cdtask = inst:DoTaskInTime(0.1, taser_cooldown)

        if data.attacker.components.combat ~= nil
                and (data.attacker.components.health ~= nil and not data.attacker.components.health:IsDead())
                and (data.attacker.components.inventory == nil or not data.attacker.components.inventory:IsInsulated())
				and not IsRangedWeapon(data.weapon)
		then
            SpawnElectricHitSparks(wx, data.attacker, true)

            local damage_mult = IsEntityElectricImmune(data.attacker) and 1
                    or TUNING.ELECTRIC_DAMAGE_MULT + TUNING.ELECTRIC_WET_DAMAGE_MULT * data.attacker:GetWetMultiplier()

			data.attacker:PushEventImmediate("electrocute", { attacker = wx, stimuli = "electric", noresist = true })
            data.attacker.components.combat:GetAttacked(wx, damage_mult * TUNING.WX78_TASERDAMAGE, nil, "electric")

            local x, y, z = wx.Transform:GetWorldPosition()
            local px, py, pz = data.attacker.Transform:GetWorldPosition()
			local arc = SpawnPrefab("shock_arc_fx")
			arc.Transform:SetPosition((px+x)/2, y, (pz+z)/2)
			arc:ForceFacePoint(data.attacker.Transform:GetWorldPosition())
        end
    end
end

local function taser_skill_updatebuildupstats(wx)
    if wx.components.wx78_taserbuildup then
        local mult_gain_rate = 1 + (wx._taser_modules * TUNING.SKILLS.WX78.TASER_BUILDUP_GAIN_RATE_MULT_PER_MODULE)
        local subtract_drain_rate = wx._taser_modules * TUNING.SKILLS.WX78.TASER_BUILDUP_DRAIN_RATE_ADD_PER_MODULE
        local blast_damage = wx._taser_modules * TUNING.SKILLS.WX78.TASER_BUILDUP_DAMAGE
        local blast_radius = TUNING.SKILLS.WX78.TASER_BUILDUP_RADIUS + (wx._taser_modules * TUNING.SKILLS.WX78.TASER_BUILDUP_RADIUS_PER_MODULE)
        wx.components.wx78_taserbuildup:SetBuildupGainRate(mult_gain_rate)
        wx.components.wx78_taserbuildup:SetBuildupDrainRate(TUNING.SKILLS.WX78.TASER_BUILDUP_DRAIN_RATE_BASE + subtract_drain_rate)
        wx.components.wx78_taserbuildup:SetBlastDamage(blast_damage)
        wx.components.wx78_taserbuildup:SetBlastRadius(blast_radius)
    end
end

local function taser_skill_ondetonate(wx)
    taser_skill_updatebuildupstats(wx)
end

local function taser_skill_removebuildup(wx)
    if wx._taser_modules == 0 then
        wx:RemoveComponent("wx78_taserbuildup")
    end
end

local function taser_skill_activate(inst, wx, isloading)
    if wx._taser_modules > 0 and not wx.components.wx78_taserbuildup then
        wx:AddComponent("wx78_taserbuildup")
    end

    taser_skill_updatebuildupstats(wx)
end

local function taser_skill_deactivate(inst, wx, isloading)
    local success
    if wx.components.wx78_taserbuildup then
        if wx._taser_modules == 0 then
            success = wx.components.wx78_taserbuildup:ReleaseBuildup(1, taser_skill_removebuildup)
        else
            success = wx.components.wx78_taserbuildup:ReleaseBuildup(1, taser_skill_ondetonate)
        end
    end

    if not success then
        taser_skill_updatebuildupstats(wx)
    end
end

local function taser_activate(inst, wx, isloading)
    wx._taser_modules = (wx._taser_modules or 0) + 1
    if inst._onblocked == nil then
        inst._onblocked = function(owner, data)
            taser_onblockedorattacked(owner, data, inst)
        end
    end

    inst:ListenForEvent("blocked", inst._onblocked, wx)
    inst:ListenForEvent("attacked", inst._onblocked, wx)

    if wx.components.inventory then
        wx.components.inventory.isexternallyinsulated:SetModifier(inst, true)
    end

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_2", taser_skill_activate, taser_skill_deactivate, isloading)
end

local function taser_deactivate(inst, wx)
    wx._taser_modules = math.max(0, wx._taser_modules - 1)
    inst:RemoveEventCallback("blocked", inst._onblocked, wx)
    inst:RemoveEventCallback("attacked", inst._onblocked, wx)

    if wx.components.inventory then
        wx.components.inventory.isexternallyinsulated:RemoveModifier(inst)
    end

    Circuit_DestroySkillCb(inst, wx)
end

local TASER_MODULE_DATA =
{
    name = "taser",
    type = CIRCUIT_BARS.BETA,
    slots = 2,
    activatefn = taser_activate,
    deactivatefn = taser_deactivate,

    extra_prefabs = { "electrichitsparks", "electrichitsparks_electricimmune", "wx78_taser_projectile_fx" },
}
table.insert(module_definitions, TASER_MODULE_DATA)

AddCreatureScanDataDefinition("lightninggoat", "taser", 5)

---------------------------------------------------------------

local LIGHT_BUFF_SKILLS =
{
    ["wx78_circuitry_betabuffs_2"] = true,
}

local LIGHT_R, LIGHT_G, LIGHT_B = 235 / 255, 121 / 255, 12 / 255
local function light_change(inst, wx, light_rad)
    wx._lightmodule_radius = (wx._lightmodule_radius or 0) + light_rad
    if wx._lightmodule_radius < 0.001 then -- Floating point precision epsilon with all of these adds and subtracts of floats.
        wx._lightmodule_radius = 0
    end
    if wx.Light then
        if wx._lightmodule_radius == 0 then
            -- Reset properties to the electrocute light properties, since that's the player_common default.
            wx.Light:SetRadius(0.5)
            wx.Light:SetIntensity(0.8)
            wx.Light:SetFalloff(0.65)
            wx.Light:SetColour(255 / 255, 255 / 255, 236 / 255)

            wx.Light:Enable(false)
        else
            wx.Light:SetRadius(math.pow(wx._lightmodule_radius, 0.8))
            -- If we had 0 before, set up the light properties.
            if wx._lightmodule_radius > 0 then
                wx.Light:SetIntensity(0.90)
                wx.Light:SetFalloff(0.50)
                wx.Light:SetColour(LIGHT_R, LIGHT_G, LIGHT_B)

                wx.Light:Enable(true)
            end
        end
    end
end

local function light_skill_update(inst, wx)
    if wx._lightmodule_radius == 0 or not IsSkillActivated(wx, "wx78_circuitry_betabuffs_2") then
        if wx.lightmodule_beam ~= nil then
            wx.lightmodule_beam:Remove()
            wx.lightmodule_beam = nil
        end
    else
        if wx.lightmodule_beam == nil then
            wx.lightmodule_beam = SpawnPrefab("wx78_lightbeam")
            wx.lightmodule_beam:AttachToOwner(wx)
        end
        wx.lightmodule_beam:SetLightRadius(wx._lightmodule_radius)
    end
end

local function light_activate(inst, wx, isloading)
    light_change(inst, wx, TUNING.WX78_LIGHT_RADIUS_PER_MODULE)
    Circuit_SetUpSkillCb(inst, wx, LIGHT_BUFF_SKILLS, light_skill_update, light_skill_update, isloading)
end

local function light_deactivate(inst, wx)
    light_change(inst, wx, -TUNING.WX78_LIGHT_RADIUS_PER_MODULE)
    Circuit_DestroySkillCb(inst, wx)
end

local LIGHT_MODULE_DATA =
{
    name = "light",
    type = CIRCUIT_BARS.BETA,
    slots = 3,
    activatefn = light_activate,
    deactivatefn = light_deactivate,

    extra_prefabs = { "wx78_lightbeam", },
}
table.insert(module_definitions, LIGHT_MODULE_DATA)

AddCreatureScanDataDefinition("fireflies", "light", 2)

---------------------------------------------------------------

local HUNGER_BUFF_SKILLS =
{
    ["wx78_circuitry_alphabuffs_1"] = true,
    ["wx78_circuitry_alphabuffs_2"] = true,
}

local function maxhunger_skill_refresh(inst, wx, isloading)
    if wx.components.hunger then
        if inst._hunger_skill_burnrate_modifiers ~= nil and (IsSkillActivated(wx, "wx78_circuitry_alphabuffs_2") or IsSkillActivated(wx, "wx78_circuitry_alphabuffs_1")) then
            local index =
                IsSkillActivated(wx, "wx78_circuitry_alphabuffs_2") and 2 or
                IsSkillActivated(wx, "wx78_circuitry_alphabuffs_1") and 1
            wx.components.hunger.burnratemodifiers:SetModifier(inst, inst._hunger_skill_burnrate_modifiers[index])
        else
            wx.components.hunger.burnratemodifiers:SetModifier(inst, inst._hunger_module_burnrate or 1)
        end
    end
end

local function maxhunger_change(inst, wx, amount, isloading)
    if wx.components.hunger then
        local current_hunger_percent = wx.components.hunger:GetPercent()

        wx.components.hunger:SetMax(wx.components.hunger.max + amount)

        -- Tie it to the module instance so we don't have to think too much about removing them.
        if inst._hunger_module_burnrate ~= nil then
            wx.components.hunger.burnratemodifiers:SetModifier(inst, inst._hunger_module_burnrate)
        end

        if not isloading then
            wx.components.hunger:SetPercent(current_hunger_percent, false)
        end
    end
end

local MAXHUNGER_SKILL_BURNRATE_MODIFIERS = { TUNING.SKILLS.WX78.MAXHUNGER_SLOWPERCENT_ALPHABUFF, TUNING.SKILLS.WX78.MAXHUNGER_SLOWPERCENT_ALPHABUFF_2 }
local function maxhunger_activate(inst, wx, isloading)
    inst._hunger_module_burnrate = TUNING.WX78_MAXHUNGER_SLOWPERCENT
    inst._hunger_skill_burnrate_modifiers = MAXHUNGER_SKILL_BURNRATE_MODIFIERS
    maxhunger_change(inst, wx, TUNING.WX78_MAXHUNGER_BOOST, isloading)
    Circuit_SetUpSkillCb(inst, wx, HUNGER_BUFF_SKILLS, maxhunger_skill_refresh, maxhunger_skill_refresh, isloading)
end

local function maxhunger_deactivate(inst, wx)
    inst._hunger_module_burnrate = 1
    maxhunger_change(inst, wx, -TUNING.WX78_MAXHUNGER_BOOST)
    Circuit_DestroySkillCb(inst, wx)
end

local MAXHUNGER_MODULE_DATA =
{
    name = "maxhunger",
    type = CIRCUIT_BARS.ALPHA,
    slots = 2,
    activatefn = maxhunger_activate,
    deactivatefn = maxhunger_deactivate,
}
table.insert(module_definitions, MAXHUNGER_MODULE_DATA)

AddCreatureScanDataDefinition("bearger", "maxhunger", 6)
AddCreatureScanDataDefinition("slurper", "maxhunger", 3)

---------------------------------------------------------------

local MAXHUNGER1_SKILL_BURNRATE_MODIFIERS = { TUNING.SKILLS.WX78.MAXHUNGER1_SLOWPERCENT_ALPHABUFF, TUNING.SKILLS.WX78.MAXHUNGER1_SLOWPERCENT_ALPHABUFF_2 }
local function maxhunger1_activate(inst, wx, isloading)
    inst._hunger_skill_burnrate_modifiers = MAXHUNGER1_SKILL_BURNRATE_MODIFIERS
    maxhunger_change(inst, wx, TUNING.WX78_MAXHUNGER1_BOOST, isloading)
    Circuit_SetUpSkillCb(inst, wx, HUNGER_BUFF_SKILLS, maxhunger_skill_refresh, maxhunger_skill_refresh, isloading)
end

local function maxhunger1_deactivate(inst, wx)
    maxhunger_change(inst, wx, -TUNING.WX78_MAXHUNGER1_BOOST)
    Circuit_DestroySkillCb(inst, wx)
end

local MAXHUNGER1_MODULE_DATA =
{
    name = "maxhunger1",
    type = CIRCUIT_BARS.ALPHA,
    slots = 1,
    activatefn = maxhunger1_activate,
    deactivatefn = maxhunger1_deactivate,
}
table.insert(module_definitions, MAXHUNGER1_MODULE_DATA)

AddCreatureScanDataDefinition("hound", "maxhunger1", 2)

---------------------------------------------------------------
local function music_sanityaura_fn(wx, observer)
    local num_modules = wx._music_modules or 1
    return TUNING.WX78_MUSIC_SANITYAURA * num_modules
end

local function music_getrange_fn(wx)
    return wx._music_modules * TUNING.WX78_MUSIC_RANGE
end

local function music_sanityfalloff_fn(inst, observer, distsq)
    return 1
end

local function music_spawn_fx(x, y, z)
    SpawnPrefab("wx78_musicbox_fx").Transform:SetPosition(x, y, z)
end

local MUSIC_TENDINGTAGS_MUST = {"farm_plant"}
local function music_update_fn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, music_getrange_fn(inst), MUSIC_TENDINGTAGS_MUST)
    for _, v in ipairs(ents) do
        if v.components.farmplanttendable then
            v.components.farmplanttendable:TendTo(inst)
        end
    end

    music_spawn_fx(x, y, z)
end

local function music_onrollcall_fn(wx)
    music_spawn_fx(wx.Transform:GetWorldPosition())
end

local function music_update_sound_parameter(inst, wx)
    local param = 0

    local has_skill = IsSkillActivated(wx, "wx78_circuitry_betabuffs_1")
    if wx._music_modules == 2 and has_skill then
        param = 0.9 -- ragtime + rhythm + new melody
    elseif wx._music_modules == 2 then
        param = 0.4 -- ragtime + rhythm
    elseif has_skill then
        param = 0.6 -- ragtime + new melody
    elseif wx._music_modules == 1 then
        param = 0.1 -- ragtime
    end

    if wx.SoundEmitter then
        wx.SoundEmitter:SetParameter("music_sound", "module_num", param)
    end
end

-- Leader roll call will take care of updating
local INIT_ROLLCALL_TIME = 1
local function music_skill_activate(inst, wx, isloading)
    if wx._tending_update ~= nil then
        wx._tending_update:Cancel()
        wx._tending_update = nil
    end

    if not wx.components.leaderrollcall then
        wx:AddComponent("leaderrollcall")
        wx.components.leaderrollcall:SetUpdateTime(TUNING.WX78_MUSIC_UPDATERATE) -- run before Enable
        wx.components.leaderrollcall:Enable(INIT_ROLLCALL_TIME)
        wx.components.leaderrollcall:SetCanTendFarmPlant(true)
        wx.components.leaderrollcall:SetOnRollCallFn(music_onrollcall_fn)
    end
    wx.components.leaderrollcall:SetRadius(music_getrange_fn(wx))
    wx.components.leaderrollcall:SetMaxFollowers(wx._music_modules * TUNING.SKILLS.WX78.MUSIC_MAXFOLLOWERS)

    music_update_sound_parameter(inst, wx)
end

local function music_skill_deactivate(inst, wx, isloading)
    if not IsSkillActivated(wx, "wx78_circuitry_betabuffs_1") or wx._music_modules == 0 then
        wx:RemoveComponent("leaderrollcall")
        if wx._tending_update == nil and wx._music_modules > 0 then
            wx._tending_update = wx:DoPeriodicTask(TUNING.WX78_MUSIC_UPDATERATE, music_update_fn, 1)
        end
    end

    music_update_sound_parameter(inst, wx)
end

local function music_activate(inst, wx, isloading)
    wx._music_modules = (wx._music_modules or 0) + 1

    if wx.components.sanity then
        -- Sanity auras don't affect their owner, so add dapperness to also give WX sanity regen.
        wx.components.sanity.dapperness = wx.components.sanity.dapperness + TUNING.WX78_MUSIC_DAPPERNESS
    end

    if wx._music_modules == 1 then
        if not wx.components.sanityaura then
            wx:AddComponent("sanityaura")
            wx.components.sanityaura.aurafn = music_sanityaura_fn
            wx.components.sanityaura.fallofffn = music_sanityfalloff_fn
        end

        if wx._tending_update == nil then
            wx._tending_update = wx:DoPeriodicTask(TUNING.WX78_MUSIC_UPDATERATE, music_update_fn, 1)
        end

        wx.SoundEmitter:PlaySound("WX_rework/module_tray/musicmodule_lp", "music_sound")
    end

    music_update_sound_parameter(inst, wx)

    local music_range = music_getrange_fn(wx)
    local music_range_sq = music_range * music_range
    if wx.components.sanityaura then
        wx.components.sanityaura.max_distsq = music_range_sq
    end

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_1", music_skill_activate, music_skill_deactivate, isloading)
end

local function music_deactivate(inst, wx)
    wx._music_modules = math.max(0, wx._music_modules - 1)

    if wx.components.sanity then
        wx.components.sanity.dapperness = wx.components.sanity.dapperness - TUNING.WX78_MUSIC_DAPPERNESS
    end

    local music_range = music_getrange_fn(wx)
    local music_range_sq = music_range * music_range
    if wx.components.sanityaura then
        wx.components.sanityaura.max_distsq = music_range_sq
    end

    if wx._music_modules == 0 then
        wx:RemoveComponent("sanityaura")

        if wx._tending_update ~= nil then
            wx._tending_update:Cancel()
            wx._tending_update = nil
        end

        if wx.SoundEmitter then
            wx.SoundEmitter:KillSound("music_sound")
        end
    end

    music_update_sound_parameter(inst, wx)

    Circuit_DestroySkillCb(inst, wx)
end

local MUSIC_MODULE_DATA =
{
    name = "music",
    type = CIRCUIT_BARS.BETA,
    slots = 3,
    activatefn = music_activate,
    deactivatefn = music_deactivate,

    scannable_prefabs = { "crabking", },
    extra_prefabs = {
        "wx78_musicbox_fx",
    }
}
table.insert(module_definitions, MUSIC_MODULE_DATA)

AddCreatureScanDataDefinition("crabking", "music", 8)
AddCreatureScanDataDefinition("hermitcrab", "music", 4)

---------------------------------------------------------------

-- Needs to listen for alphabuff_1 for the sanity modifier
local BEE_BUFF_SKILLS =
{
    ["wx78_circuitry_alphabuffs_1"] = true,
    ["wx78_circuitry_alphabuffs_2"] = true,
}
local function bee_getticktime(inst, wx)
    return TUNING.WX78_BEE_TICKPERIOD
end

local function bee_tick(wx, inst)
    if wx._bee_modcount and wx._bee_modcount > 0 and wx.components.health and wx.components.health:IsHurt() then
        local health_tick = wx._bee_modcount * TUNING.WX78_BEE_HEALTHPERTICK
        wx.components.health:DoDelta(health_tick, false, inst, true)
    end
end

local function bee_updateregen_task(inst, wx)
    if wx._bee_regentask == nil then
        wx._bee_regentask = wx:DoPeriodicTask(bee_getticktime(inst, wx), bee_tick, nil, inst)
    end

    if wx.components.wx78_shield then
        if IsSkillActivated(wx, "wx78_circuitry_alphabuffs_2") then
            wx.components.wx78_shield:AddChargeSource(wx, wx._bee_modcount * TUNING.SKILLS.WX78.BEE_SHIELD_REGEN_PER_SECOND, "BEE_CIRCUIT")
        else
            wx.components.wx78_shield:RemoveChargeSource(wx, "BEE_CIRCUIT")
        end
    end
end

local function bee_skill_updatemaxshield(inst, wx)
    if wx.components.wx78_shield and wx.components.health then
        if IsSkillActivated(wx, "wx78_circuitry_alphabuffs_2") then
            local maxhealth = wx.components.health.maxhealth
            local maxshield = wx._bee_modcount * TUNING.SKILLS.WX78.BEE_SHIELDPERCENT * maxhealth
            wx.components.wx78_shield:SetMax(math.max(1, maxshield))
        elseif wx._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
            wx.components.wx78_shield:SetMax(1)
            wx.components.wx78_shield:SetCurrent(0)
        end
    end
end

local function bee_skill_activate(inst, wx, isloading)
    bee_updateregen_task(inst, wx)
    bee_skill_updatemaxshield(inst, wx)
    sanity_skill_activate(inst, wx, isloading, TUNING.SKILLS.WX78.MAXSANITY_SANITY_MOD_ALPHABUFF)

    inst._bee_updatemaxshield = function()
        bee_skill_updatemaxshield(inst, wx)
        bee_updateregen_task(inst, wx)
    end
    inst:ListenForEvent("healthdelta", inst._bee_updatemaxshield, wx)
end

local function bee_skill_deactivate(inst, wx, isloading)
    bee_updateregen_task(inst, wx)
    bee_skill_updatemaxshield(inst, wx)
    sanity_skill_deactivate(inst, wx)

    if wx._bee_modcount == 0 then
        if wx.components.wx78_shield then
            wx.components.wx78_shield:SetCurrent(0)
            wx.components.wx78_shield:RemoveChargeSource(wx, "BEE_CIRCUIT")
        end
    end

    if inst._bee_updatemaxshield then
        inst:RemoveEventCallback("healthdelta", inst._bee_updatemaxshield, wx)
        inst._bee_updatemaxshield = nil
    end
end

local function bee_activate(inst, wx, isloading)
    wx._bee_modcount = (wx._bee_modcount or 0) + 1

    if wx._bee_modcount == 1 then
        bee_updateregen_task(inst, wx)
    end

    maxsanity_activate(inst, wx, isloading, true)
    Circuit_SetUpSkillCb(inst, wx, BEE_BUFF_SKILLS, bee_skill_activate, bee_skill_deactivate, isloading)
end

local function bee_deactivate(inst, wx)
    wx._bee_modcount = math.max(0, wx._bee_modcount - 1)

    if wx._bee_modcount == 0 then
        if wx._bee_regentask ~= nil then
            wx._bee_regentask:Cancel()
            wx._bee_regentask = nil
        end
    end

    maxsanity_deactivate(inst, wx, true)
    Circuit_DestroySkillCb(inst, wx)
end

local BEE_MODULE_DATA =
{
    name = "bee",
    type = CIRCUIT_BARS.ALPHA,
    slots = 3,
    activatefn = bee_activate,
    deactivatefn = bee_deactivate,

    extra_prefabs =
    {
        "wx78_shield_full",
        "wx78_shield_half",
        "wx78_shield_full_to_half",
        "wx78_shield_half_to_full",
        "wx78_shield_full_to_empty",
        "wx78_shield_half_to_empty",
    },
}
table.insert(module_definitions, BEE_MODULE_DATA)

AddCreatureScanDataDefinition("beequeen", "bee", 10)

---------------------------------------------------------------
-- We calculate the boost locally becuase it's slightly nicer
-- if mods want to change the tuning values.
local function maxhealth2_activate(inst, wx, isloading)
    local maxhealth2_boost = TUNING.WX78_MAXHEALTH_BOOST * TUNING.WX78_MAXHEALTH2_MULT
    inst._skill_health_armor_mult = TUNING.SKILLS.WX78.MAXHEALTH2_ARMOR_MULT
    maxhealth_change(inst, wx, maxhealth2_boost, isloading)
    Circuit_SetUpSkillCb(inst, wx, HEALTH_BUFF_SKILLS, maxhealth_skill_activate, maxhealth_skill_deactivate, isloading)
end

local function maxhealth2_deactivate(inst, wx)
    local maxhealth2_boost = TUNING.WX78_MAXHEALTH_BOOST * TUNING.WX78_MAXHEALTH2_MULT
    maxhealth_change(inst, wx, -maxhealth2_boost)
    Circuit_DestroySkillCb(inst, wx)
end

local MAXHEALTH2_MODULE_DATA =
{
    name = "maxhealth2",
    type = CIRCUIT_BARS.ALPHA,
    slots = 2,
    activatefn = maxhealth2_activate,
    deactivatefn = maxhealth2_deactivate,
}
table.insert(module_definitions, MAXHEALTH2_MODULE_DATA)

AddCreatureScanDataDefinition("spider_healer", "maxhealth2", 4)

---------------------------------------------------------------

local function radar_skill_update(inst, wx, isloading)
    wx:PushEvent("rangecircuitupdate") -- For drones
end

local function radar_activate(inst, wx, isloading)
    if wx.AddCameraExtraDistance then
        wx:AddCameraExtraDistance(inst, TUNING.WX78_RADAR_EXTRA_VIEW_DIST)
    end

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_betabuffs_1", radar_skill_update, radar_skill_update, isloading)
end

local function radar_deactivate(inst, wx)
    if wx.RemoveCameraExtraDistance then
        wx:RemoveCameraExtraDistance(inst)
    end

    Circuit_DestroySkillCb(inst, wx)
end

local RADAR_MODULE_DATA =
{
    name = "radar",
    type = CIRCUIT_BARS.BETA,
    slots = 1,
    activatefn = radar_activate,
    deactivatefn = radar_deactivate,
}
table.insert(module_definitions, RADAR_MODULE_DATA)

local function GetIsBirdFn(cage_or_trap, scanid)
    local birdprefab
    if cage_or_trap.components.occupiable ~= nil then
        local bird = cage_or_trap.components.occupiable:GetOccupant()
        birdprefab = bird ~= nil and bird.prefab or nil
    elseif cage_or_trap.components.trap ~= nil and cage_or_trap.components.trap.lootprefabs ~= nil then
        birdprefab = cage_or_trap.components.trap.lootprefabs[1]
    end

    return birdprefab == scanid
end

AddSpecialCreatureScanDataDefinition("crow", GetIsBirdFn, "radar", 2)
AddSpecialCreatureScanDataDefinition("robin", GetIsBirdFn, "radar", 2)
AddSpecialCreatureScanDataDefinition("robin_winter", GetIsBirdFn, "radar", 2)
AddSpecialCreatureScanDataDefinition("puffin", GetIsBirdFn, "radar", 2)
AddSpecialCreatureScanDataDefinition("canary", GetIsBirdFn, "radar", 4)

---------------------------------------------------------------

local function screech_activate(inst, wx, isloading)
    wx._screech_modules = (wx._screech_modules or 0) + 1
    if wx.wx78_classified ~= nil and wx._screech_modules == 1 then
        wx.wx78_classified:AddInherentAction(ACTIONS.TOGGLEWXSCREECH)
    end
end

local function screech_deactivate(inst, wx)
    wx._screech_modules = (wx._screech_modules or 1) - 1
    if wx.wx78_classified ~= nil and wx._screech_modules == 0 then
        wx.wx78_classified:RemoveInherentAction(ACTIONS.TOGGLEWXSCREECH)
    end
end

local SCREECH_MODULE_DATA =
{
    name = "screech",
    type = CIRCUIT_BARS.GAMMA,
    slots = 3,
    activatefn = screech_activate,
    deactivatefn = screech_deactivate,
}
table.insert(module_definitions, SCREECH_MODULE_DATA)

AddCreatureScanDataDefinition("molebat", "screech", 4)

---------------------------------------------------------------

local function stacksize_addedtoownerfn(inst, wx, isloading)
	local inventory = wx.components.inventory or wx.components.container
	if inventory then
        wx._stacksize_modules = (wx._stacksize_modules or 0) + 1

        if not isloading then
			local invslot = inventory:GetNumSlots() - (wx._stacksize_modules - 1)
			local itemtomove = inventory:GetItemInSlot(invslot)
			if itemtomove and itemtomove.components.inventoryitem.islockedinslot then
				--can't install slot, something locked in this slot already.
				if itemtomove.prefab == "wx78_inventorycontainer" then
					--V2C: -likely transferring to/from backupbody
					--     -deactivate fails during transfer, since inventory is moved before circuits
					--     -deactivate here instead
					itemtomove:SetPowered(false)
				end
				return
			end

			local chargelevel = wx.components.upgrademoduleowner:GetChargeLevel()
			if chargelevel < wx._stacksize_modules then
				if wx.components.inventory then
					wx.components.inventory:DropItem(itemtomove, true, true)
				else
					--container's DropItem() does not drop wholestack
					wx.components.container:DropItemBySlot(invslot)
				end
				itemtomove = nil
			else
				itemtomove = inventory:RemoveItem(itemtomove, true)
			end

			local containerinst = SpawnPrefab("wx78_inventorycontainer")
			inventory:GiveItem(containerinst, invslot)
			containerinst.components.inventoryitem.islockedinslot = true

			if itemtomove then
				containerinst.components.container:GiveItem(itemtomove)
			end
        end
    end
end

local function stacksize_removedfromownerfn(inst, wx)
	local inventory = wx.components.inventory or wx.components.container
	if inventory then
        wx._stacksize_modules = (wx._stacksize_modules or 1) - 1

		local invslot = inventory:GetNumSlots() - wx._stacksize_modules

		local containerinst = inventory:GetItemInSlot(invslot)
		if containerinst and containerinst.prefab == "wx78_inventorycontainer" and not containerinst._backupbody_transferring then
			containerinst.components.inventoryitem.islockedinslot = false
			--wx78_inventorycontainer is not stackable so we don't need to branch for container:DroptItemBySlot()
			inventory:DropItem(containerinst)
        end
    end
end

local function stacksize_activate(inst, wx, isloading)
	local inventory = wx.components.inventory or wx.components.container
	if inventory then
		wx._stacksize_active_modules = (wx._stacksize_active_modules or 0) + 1

		local invslot = inventory:GetNumSlots() - (wx._stacksize_active_modules - 1)

		local containerinst = inventory:GetItemInSlot(invslot)
		if containerinst and containerinst.prefab == "wx78_inventorycontainer" then
			containerinst:SetPowered(true)
		end
	end
end

local function stacksize_deactivate(inst, wx)
	local inventory = wx.components.inventory or wx.components.container
	if inventory then
		wx._stacksize_active_modules = (wx._stacksize_active_modules or 1) - 1

		local invslot = inventory:GetNumSlots() - wx._stacksize_active_modules

		local containerinst = inventory:GetItemInSlot(invslot)
		if containerinst and containerinst.prefab == "wx78_inventorycontainer" then
			containerinst:SetPowered(false)
		end
	end
end

local STACKSIZE_MODULE_DATA =
{
    name = "stacksize",
    type = CIRCUIT_BARS.BETA,
    slots = 1,
	addedtoownerfn = stacksize_addedtoownerfn,
	removedfromownerfn = stacksize_removedfromownerfn,
    activatefn = stacksize_activate,
    deactivatefn = stacksize_deactivate,

    extra_prefabs = { "wx78_inventorycontainer", },
}
table.insert(module_definitions, STACKSIZE_MODULE_DATA)

AddCreatureScanDataDefinition("krampus", "stacksize", 6)

---------------------------------------------------------------

local function light2_activate(inst, wx, isloading)
    light_change(inst, wx, TUNING.WX78_LIGHT_RADIUS_PER_MODULE)
    Circuit_SetUpSkillCb(inst, wx, LIGHT_BUFF_SKILLS, light_skill_update, light_skill_update, isloading)
end

local function light2_deactivate(inst, wx)
    light_change(inst, wx, -TUNING.WX78_LIGHT_RADIUS_PER_MODULE)
    Circuit_DestroySkillCb(inst, wx)
end

local LIGHT2_MODULE_DATA =
{
    name = "light2",
    type = CIRCUIT_BARS.BETA,
    slots = 1,
    activatefn = light2_activate,
    deactivatefn = light2_deactivate,
}
table.insert(module_definitions, LIGHT2_MODULE_DATA)

AddCreatureScanDataDefinition("squid", "light2", 6)
AddCreatureScanDataDefinition("worm", "light2", 6)
AddCreatureScanDataDefinition("lightflier", "light2", 6)

---------------------------------------------------------------

local function digestion_OnEaten(wx, data)
    if data ~= nil
        and data.food ~= nil
        and wx.components.eater:CanProcessSpoiledItem(data.food) then
        wx._num_spoiledfood_eaten = (wx._num_spoiledfood_eaten or 0) + 1
        if wx._num_spoiledfood_eaten >= (TUNING.WX78_DIGESTION_SPOILED_NEEDED - (wx._digestion_modules - 1)) then
            wx._num_spoiledfood_eaten = 0
            wx:PushEventImmediate("queue_post_eat_state", { post_eat_state = "wx_bake" })
        end
    end
end

local function digestion_skill_activate(inst, wx, isloading)
    if wx.components.eater ~= nil then
        wx.components.eater:SetSpoiledProcessor(true, true)
    end
end

local function digestion_skill_deactivate(inst, wx)
    wx.components.eater:SetSpoiledProcessor(wx._digestion_modules > 0, false)
end

local function digestion_activate(inst, wx, isloading)
    wx._digestion_modules = (wx._digestion_modules or 0) + 1
    if wx.components.eater ~= nil and wx._digestion_modules == 1 then
        wx.components.eater:SetSpoiledProcessor(true)
        wx:ListenForEvent("oneat", digestion_OnEaten)
    end

    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_gammabuffs_1", digestion_skill_activate, digestion_skill_deactivate, isloading)
end

local function digestion_deactivate(inst, wx)
    wx._digestion_modules = (wx._digestion_modules or 1) - 1
    if wx.components.eater ~= nil then
        if wx._digestion_modules == 0 then
            wx.components.eater:SetSpoiledProcessor(false)
            wx:RemoveEventCallback("oneat", digestion_OnEaten)
        end
    end

    Circuit_DestroySkillCb(inst, wx)
end

local DIGESTION_MODULE_DATA =
{
    name = "digestion",
    type = CIRCUIT_BARS.GAMMA,
    slots = 2,
    activatefn = digestion_activate,
    deactivatefn = digestion_deactivate,

    extra_prefabs = { "wx78_foodbrick" },
}
table.insert(module_definitions, DIGESTION_MODULE_DATA)

AddCreatureScanDataDefinition("catcoon", "digestion", 2)

---------------------------------------------------------------

local function spin_overriderange(wx, override)
    if wx.components.combat then
	    wx.components.combat:SetRange(override or TUNING.DEFAULT_ATTACK_RANGE, wx.components.combat.hitrange)
    end
end

local function spin_checktool(wx, data)
	if data == nil or data.eslot == EQUIPSLOTS.HANDS then
		local item = wx.components.inventory and wx.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		spin_overriderange(wx, WX78Common.CanSpinUsingItem(item) and TUNING.WX78_SPIN_START_RANGE or nil)
	end
end

local function spin_activate(inst, wx, isloading)
	wx._spin_modules = (wx._spin_modules or 0) + 1
	if wx.components.efficientuser == nil then
		wx:AddComponent("efficientuser")
	end
	if wx.components.aoediminishingreturns == nil then
		wx:AddComponent("aoediminishingreturns")
	end
	if wx._spin_modules == 1 then
		wx:ListenForEvent("equip", spin_checktool)
		wx:ListenForEvent("unequip", spin_checktool)
		spin_checktool(wx, nil)
	end
end

local function spin_deactivate(inst, wx)
	wx._spin_modules = (wx._spin_modules or 1) - 1
	if wx._spin_modules <= 0 then
		wx._spin_modules = nil
		--wx:RemoveComponent("efficientuser")
		wx:RemoveComponent("aoediminishingreturns")
		wx:RemoveEventCallback("equip", spin_checktool)
		wx:RemoveEventCallback("unequip", spin_checktool)
		spin_overriderange(wx, nil)
	end
end

local SPIN_MODULE_DATA =
{
    name = "spin",
    type = CIRCUIT_BARS.GAMMA,
    slots = 3,
    activatefn = spin_activate,
    deactivatefn = spin_deactivate,
}
table.insert(module_definitions, SPIN_MODULE_DATA)

AddCreatureScanDataDefinition("mossling", "spin", 6)

---------------------------------------------------------------

local function shielding_skill_update(inst, wx)
    inst:PushEvent("refreshwxshielddefense") -- Not needed anymore, but left in case things change.
end

local function shielding_activate(inst, wx, isloading)
    if wx.wx78_classified ~= nil then
        wx.wx78_classified:AddInherentAction(ACTIONS.TOGGLEWXSHIELDING)
    end
    Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_gammabuffs_2", shielding_skill_update, shielding_skill_update, isloading)
end

local function shielding_deactivate(inst, wx)
    if wx.wx78_classified ~= nil then
        wx.wx78_classified:RemoveInherentAction(ACTIONS.TOGGLEWXSHIELDING)
    end
    Circuit_DestroySkillCb(inst, wx)
end

local SHIELDING_MODULE_DATA =
{
    name = "shielding",
    type = CIRCUIT_BARS.GAMMA,
    slots = 4,
    activatefn = shielding_activate,
    deactivatefn = shielding_deactivate,
}
table.insert(module_definitions, SHIELDING_MODULE_DATA)

AddCreatureScanDataDefinition("rocky", "shielding", 4)
AddCreatureScanDataDefinition("rocky_boss", "shielding", 8)
AddCreatureScanDataDefinition("slurtle", "shielding", 4)
AddCreatureScanDataDefinition("snurtle", "shielding", 6)

---------------------------------------------------------------

local function chess_skill_activate(inst, wx, isloading)
	wx:AddTag("chessbff")
end

local function chess_skill_deactivate(inst, wx)
    if (wx._chess_modules == nil) or (wx._chess_modules == 0) or (not IsSkillActivated(wx, "wx78_circuitry_gammabuffs_1")) then
        wx:RemoveTag("chessbff")
    end
end

local function chess_activate(inst, wx, isloading)
	wx._chess_modules = (wx._chess_modules or 0) + 1
	if wx.components.clockworktracker == nil then
		wx:AddComponent("clockworktracker")
	end
	wx.components.clockworktracker:SetBonus(wx, wx._chess_modules, "wx78module_chess")
	Circuit_SetUpSkillCb(inst, wx, "wx78_circuitry_gammabuffs_1", chess_skill_activate, chess_skill_deactivate, isloading)
end

local function chess_deactivate(inst, wx)
	wx._chess_modules = (wx._chess_modules or 1) - 1
	if wx._chess_modules <= 0 then
		wx._chess_modules = nil
	end
	if wx.components.clockworktracker then
		wx.components.clockworktracker:SetBonus(wx, wx._chess_modules, "wx78module_chess")
	end
	Circuit_DestroySkillCb(inst, wx)
end

local CHESS_MODULE_DATA =
{
	name = "chess",
	type = CIRCUIT_BARS.GAMMA,
	slots = 1,
	activatefn = chess_activate,
	deactivatefn = chess_deactivate,
}
table.insert(module_definitions, CHESS_MODULE_DATA)

AddCreatureScanDataDefinition("knight", "chess", 3)
AddCreatureScanDataDefinition("knight_nightmare", "chess", 3)
AddCreatureScanDataDefinition("knight_yoth", "chess", 3)

---------------------------------------------------------------
local module_netid = 1
local module_netid_lookup = {}

-- Add a new module definition table, passing a table with the following properties:
--      name -          The type-name of the module (without the "wx78module_" prefix)
--      type -          The type of circuit, for which bar?
--      slots -         How many energy slots the module requires to be plugged in & activated
--      activatefn -    The function that runs whenever the module is activated [signature (module instance, owner instance)]. This can run during loading.
--      deactivatefn -  The function that runs whenever the module is deactivated [signature (module instance, owner instance)]
--      extra_prefabs - Additional prefabs to be imported alongside the module, such as fx prefabs
--
-- For mods!:
--      overridebank        - Override bank for the chip in-world
--      overridebuild       - Override build for the chip in-world
--      overrideminiuibuild - Override build for the ui mini chip on the status
--      overrideuibuild     - Override build for the ui chip when inspecting our chips.
--      returns a net id for the module, to send for UI purposes; also adds that net id (as module_netid) to the passed definition.
local function AddNewModuleDefinition(module_definition)
    assert(module_netid < 64, "To support additional WX modules, player_classified.upgrademodulebars must be updated")

    module_definition.module_netid = module_netid
    module_netid_lookup[module_netid] = module_definition
    module_netid = module_netid + 1

    return module_definition.module_netid
end

-- Given a module net id, get the definition table of that module.
local function GetModuleDefinitionFromNetID(netid)
    return (netid ~= nil and module_netid_lookup[netid])
        or nil
end

for _, definition in ipairs(module_definitions) do
    AddNewModuleDefinition(definition)
end

---------------------------------------------------------------

return {
    module_definitions = module_definitions,
    AddNewModuleDefinition = AddNewModuleDefinition,
    GetModuleDefinitionFromNetID = GetModuleDefinitionFromNetID,

    AddCreatureScanDataDefinition = AddCreatureScanDataDefinition,
    GetCreatureScanDataDefinition = GetCreatureScanDataDefinition,
    AddSpecialCreatureScanDataDefinition = AddSpecialCreatureScanDataDefinition,
}