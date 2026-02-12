local easing = require("easing")

--------------------------------------------------------------------------------------------------------

local corpse_defs = require("prefabs/corpses_defs")

local CORPSE_DEFS = corpse_defs.CORPSE_DEFS
local CORPSE_PROP_DEFS = corpse_defs.CORPSE_PROP_DEFS
local CORPSE_LOOT_OVERRIDES = corpse_defs.CORPSE_LOOT_OVERRIDES
local BUILDS_TO_NAMES = corpse_defs.BUILDS_TO_NAMES
local FACES = corpse_defs.FACES
corpse_defs = nil

local CORPSE_TIMERS = {
    ERODE = "erode_timer",
    SPAWN_GESTALT = "spawn_gestalt",
    REVIVE_MUTATE = "revive_timer", -- A non gestalt mutation. e.g. Horror Hound
}

local PERSIST_FADE_TIMER_SOURCE = "persist_fade_timer_source"
local GESTALT_TRACK_NAME = "gestalt"

--------------------------------------------------------------------------------------------------------

local function HasGestaltArriving(inst)
    return inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME) ~= nil
end

local function OnIgnited(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
	if gestalt ~= nil then
        gestalt:SetTarget(nil)
    end

    inst.components.timer:StopTimer(CORPSE_TIMERS.REVIVE_MUTATE)
end

local function OnBurnt(inst)
    if not inst.no_destroy_on_burn then
        DefaultBurntCorpseFn(inst)
        inst:DropCorpseLoot()
    end
end

local function OnExtinguish(inst)
    -- _skip_extinguish_fade is a hack to let buzzards extinguish the corpse without it being lost
    -- no_destroy_on_burn is for Willow corpses!
    if not inst:IsMutating() and not inst._skip_extinguish_fade and not inst.no_destroy_on_burn then
		DefaultExtinguishCorpseFn(inst)
        inst:DropCorpseLoot()
    end
end

local function GetStatus(inst)
    return (inst:IsMutating() and "REVIVING")
        or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) and "BURNING"
        or nil
end

local function DisplayNameFn(inst)
    local build_override = inst:IsValid() and BUILDS_TO_NAMES[inst.creature] and BUILDS_TO_NAMES[inst.creature][inst.AnimState:GetBuild()] or nil --Client, don't use inst.build
    return inst.creature ~= nil and STRINGS.NAMES[string.upper(build_override or inst.displaynameoverride or inst.nameoverride or inst.creature)] or nil
end

local function GetMutantPrefab(inst)
    return FunctionOrValue(inst.mutantprefab, inst)
end

local function GetRiftMutantPrefab(inst)
    return FunctionOrValue(inst.riftmutantprefab, inst)
end

--------------------------------------------------------------------------------------------------------

-- This is no longer needed for corpses spawned from dying mobs as we copy build and bank already and keep it saved.
-- For logic like birdspawner and wargs can just call AnimState:SetBuild but that may give the illusion it is not saved.
-- So SetAltBuild/SetAltBank is kept just to keep the idea of it being different from AnimState:SetBuild/SetBank
local function SetAltBuild(inst, build)
    inst.AnimState:SetBuild(build)
end

local function SetAltBank(inst, bank)
    inst.AnimState:SetBank(bank)
end

local function OnSave(inst, data)
    data.is_reviving = inst.sg and inst.sg:HasStateTag("prerift_mutating") or nil
    data.is_gestalt_mutating = inst.sg and inst.sg:HasStateTag("lunarrift_mutating") or nil
    data.build = inst.build
    data.bank = inst.bank
    data.meat = (inst.meat ~= nil and inst.meat < inst:GetMaxMeat() and math.floor(inst.meat * 10 + 0.5) * 0.1) or nil

    data.build_hash = inst.AnimState:GetBuild()
    data.bank_hash = inst.AnimState:GetBankHash()

    data.corpse_loot = inst.corpse_loot

    -- Extra data from the creature
    data.corpsedata = inst.corpsedata
    data.nolunarmutate = inst.sg and inst.sg.mem.nolunarmutate or nil
    data.no_destroy_on_burn = inst.no_destroy_on_burn or nil
    data.noburn = inst.noburn or nil
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.corpsedata = data.corpsedata
        ---- DEPRECATED -----
        if data.build then
            SetAltBuild(inst, data.build)
        end
        if data.bank then
            SetAltBank(inst, data.bank)
        end
        ---------------------
        if data.build_hash then
            inst.AnimState:SetBuild(data.build_hash)
        end
        if data.bank_hash then
            inst.AnimState:SetBank(data.bank_hash)
        end
        if data.meat ~= nil then
			inst:SetMeat(math.clamp(data.meat, 0, inst:GetMaxMeat()))
		end
        if data.nolunarmutate then
            inst.sg.mem.nolunarmutate = true
        end
        if data.no_destroy_on_burn then
            inst.no_destroy_on_burn = data.no_destroy_on_burn
        end
        if data.noburn then
            inst:RemoveComponent("burnable")
            inst.noburn = true
        end
        if data.corpse_loot ~= nil then
            inst.corpse_loot = data.corpse_loot
        end
        -- data.ready is deprecated, kept for backwards compat
        if data.ready or data.is_gestalt_mutating then
            inst:StartLunarRiftMutation(true)
        elseif data.is_reviving then
            inst:StartLunarMutation(true)
        end
    end
end

local function OnLoadPostPass(inst, newents, data)
    if inst._on_load_post_pass then
        inst._on_load_post_pass(inst, newents, data)
    end

    if inst.components.timer:TimerExists(CORPSE_TIMERS.ERODE) then
        inst:SetPersistSource(PERSIST_FADE_TIMER_SOURCE, true)
    end
end

--------------------------------------------------------------------------------------------------------
local function DoErode(inst)
    if inst.components.burnable then
        inst.components.burnable.fastextinguish = true
        inst:RemoveComponent("burnable")
    end
    inst:AddTag("NOCLICK")
    inst:DropCorpseLoot()
    inst:RemoveTag("creaturecorpse")
    inst.persists = false

    if inst.corpseerodefn then
        inst.corpseerodefn(inst)
    else
        inst.erode_task = inst:DoTaskInTime(inst.corpsedeathtime or 1, ErodeAway)
    end
end
--------------------------------------------------------------------------------------------------------

local NUM_MEAT_LEVELS = 3 -- NOTE: level 4 is "empty"

local function SetMeatLevel(inst, level)
	if inst.meat_level ~= level then
		if level > NUM_MEAT_LEVELS then
            DoErode(inst)
		end
		inst.meat_level = level
	end
end

local function GetMeatPerLevel(inst)
    local _, sz, _ = GetCombatFxSize(inst)
    return TUNING.CREATURE_CARCASS_MEAT_PER_LEVEL[sz]
end

local function GetMaxMeat(inst)
    return GetMeatPerLevel(inst) * NUM_MEAT_LEVELS
end

local function SetMeat(inst, meat)
	if inst.meat ~= meat then
		inst.meat = meat
		SetMeatLevel(inst, NUM_MEAT_LEVELS + 1 - math.ceil(meat / GetMeatPerLevel(inst)))
	end
end

local function SetMeatPercent(inst, pct)
    local maxmeat = GetMaxMeat(inst)
	SetMeat(inst, math.clamp(pct * maxmeat, 0, maxmeat))
end

local function GetMeatPercent(inst)
    return inst.meat / GetMaxMeat(inst)
end

local function OnChomped(inst, data)
	local amount = data ~= nil and data.amount or 1
	SetMeat(inst, math.max(0, inst.meat - amount))
	--inst.components.timer:SetTimeLeft("decay", TUNING.KOALEFANT_CARCASS_DECAY_TIME)
end

--------------------------------------------------------------------------------------------------------

local FLASH_INTENSITY = 0.5
local LIGHT_OVERRIDE_MOD = 0.1 / FLASH_INTENSITY

local function UpdateFlash(inst)
	if inst._flash > 1 then
		inst._flash = inst._flash - 1
		local c = easing.inQuad(inst._flash, 0, FLASH_INTENSITY, 20)
		inst.AnimState:SetAddColour(c, c, c, 0)
		inst.AnimState:SetLightOverride(c * LIGHT_OVERRIDE_MOD)
	else
		inst._flash = nil
		inst.AnimState:SetAddColour(0, 0, 0, 0)
		inst.AnimState:SetLightOverride(0)
		inst:RemoveComponent("updatelooper")
	end
end

local function DisableBurnable(inst)
    inst.components.burnable:SetOnIgniteFn(nil)
	inst.components.burnable:SetOnExtinguishFn(nil)
	inst.components.burnable:SetOnBurntFn(nil)
end

local function StartLunarRiftMutation(inst, loading)
    if not loading then
        TheWorld:PushEvent("ms_gestalt_possession", { corpse = inst })
    end
    --
    if inst.persists then
        if inst:IsAsleep() then
            ReplacePrefab(inst, inst:GetRiftMutantPrefab())
        else
            DisableBurnable(inst)

            inst.sg:GoToState(loading and "corpse_lunarrift_mutate" or "corpse_lunarrift_mutate_pre", inst:GetRiftMutantPrefab())

	        --Start flash
	        local c = FLASH_INTENSITY / 2
	        inst.AnimState:SetAddColour(c, c, c, 0)
	        inst.AnimState:SetLightOverride(c * LIGHT_OVERRIDE_MOD)
	        inst._flash = 21
	        if inst.components.updatelooper == nil then
	        	inst:AddComponent("updatelooper")
	        end
	        inst.components.updatelooper:AddOnUpdateFn(UpdateFlash)
        end
    end
end

local function StartLunarMutation(inst, loading)
    if inst.persists then
        if inst:IsAsleep() then
            ReplacePrefab(inst, inst:GetMutantPrefab())
        else
	        DisableBurnable(inst)
            -- There's only one state, no need to do a loading skip
            inst.sg:GoToState("corpse_prerift_mutate", inst:GetMutantPrefab())
        end
    end
end

local function StartFadeTimer(inst, time)
    inst:SetPersistSource(PERSIST_FADE_TIMER_SOURCE, true)
    inst.components.timer:StartTimer(CORPSE_TIMERS.ERODE, time)
end

local function StartGestaltTimer(inst, time)
    if inst.build == "puffin" then --FIXME: No mutation for puffins! For now.
        StartFadeTimer(inst, time)
        return
    end
    inst.components.timer:StartTimer(CORPSE_TIMERS.SPAWN_GESTALT, time)
end

local function StartReviveMutateTimer(inst, time)
    inst.components.timer:StartTimer(CORPSE_TIMERS.REVIVE_MUTATE, time)
end

local function ImmediateGestaltMutate(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
    local is_rift_mutant = gestalt ~= nil or inst.components.timer:TimerExists(CORPSE_TIMERS.SPAWN_GESTALT)
    if is_rift_mutant then
        if inst._override_immediate_gestalt_mutate_cb ~= nil then
            inst._override_immediate_gestalt_mutate_cb(inst, gestalt)
        else
            inst:StartLunarRiftMutation()

            if gestalt then
                gestalt:Remove()
            end
        end
    else
        inst:Remove()
    end
end

local function TryGestaltMutateTaskOnSleep(inst, gestalt)
    local time = 7 + math.random() * 3 + math.sqrt(inst:GetDistanceSqToInst(gestalt) / gestalt.components.locomotor.runspeed) -- Rough estimation
    inst.mutate_task = inst:DoTaskInTime(time, ImmediateGestaltMutate)
end

local function SpawnGestalt(inst)
    if inst.components.burnable == nil or not inst.components.burnable:IsBurning() then
        local gestalt = SpawnPrefab("corpse_gestalt")

        inst.components.entitytracker:TrackEntity(GESTALT_TRACK_NAME, gestalt)

        gestalt:SetTarget(inst)
        gestalt:Spawn()

        if inst:IsAsleep() then
            TryGestaltMutateTaskOnSleep(inst, gestalt)
        end

        return gestalt -- Mods
    end
end

local function OnEntitySleep(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
    if gestalt then -- Gestalt mutation
        TryGestaltMutateTaskOnSleep(inst, gestalt)
    elseif inst.sg:HasStateTag("prerift_mutating") then -- Regular mutation
        -- Timer is handled in timer finish.
        inst.mutate_task = inst:DoTaskInTime(0, inst.StartLunarMutation) --Just do it instantly.
    end
end

local function OnEntityWake(inst)
    if inst.mutate_task ~= nil then
        inst.mutate_task:Cancel()
        inst.mutate_task = nil
    end
end

local function OnTimerDone(inst, data)
    if not data then return end

    if data.name == CORPSE_TIMERS.ERODE then
        inst:RemovePersistSource(PERSIST_FADE_TIMER_SOURCE)
    elseif data.name == CORPSE_TIMERS.SPAWN_GESTALT then
        inst:SpawnGestalt()
    elseif data.name == CORPSE_TIMERS.REVIVE_MUTATE then
        inst:StartLunarMutation()
    end
end

local function SetGestaltCorpse(inst)
    inst:SpawnGestalt()

    if inst:HasTag("epiccorpse") or inst.prefab == "wargcorpse" then
        inst:DropCorpseLoot()
    end
end

local function SetNonGestaltCorpse(inst)
    local revive_time = TUNING.PRERIFT_MUTATION_SPAWN_DELAY_BASE + TUNING.PRERIFT_MUTATION_SPAWN_DELAY_VARIANCE * math.random()
    inst:StartReviveMutateTimer(revive_time)
end

local function SetCorpseData(inst, corpsedata)
    inst.corpsedata = corpsedata
end

local function WillMutate(inst)
    return inst.components.timer:TimerExists(CORPSE_TIMERS.REVIVE_MUTATE) or inst:IsMutating()
end

local function IsMutating(inst)
    return inst.sg:HasAnyStateTag("prerift_mutating", "lunarrift_mutating")
end

local function IsFading(inst)
    return inst._eroding_away
end

--------------------------------------------------------------------------------------------------------

local function CanErode(inst)
    return not inst.persist_sources:Get()
        and not inst:WillMutate()
        and not inst:HasGestaltArriving()
        and not inst.components.timer:TimerExists(CORPSE_TIMERS.SPAWN_GESTALT)
        and not inst:IsFading()
        and (inst.components.burnable == nil or not inst.components.burnable:IsBurning())
end

local function CheckPersist(inst)
    if CanErode(inst) then
        DoErode(inst)
    end
end

local function CancelPersistTask(inst)
    if inst.check_persist_task ~= nil then
        inst.check_persist_task:Cancel()
        inst.check_persist_task = nil
    end
end

local function SetPersistSource(inst, source, persists)
    inst.persist_sources:SetModifier(inst, persists, source)
    if inst.persist_sources:Get() then
        CancelPersistTask(inst)
    end
end

local function RemovePersistSource(inst, source)
    inst.persist_sources:RemoveModifier(inst, source)
    CancelPersistTask(inst)
    inst.check_persist_task = inst:DoTaskInTime(0, CheckPersist)
end

--------------------------------------------------------------------------------------------------------

--[[
Process the corpse loot based on the meat percent we have.
Only alter loot if past the first meat level (so no changes if player can defeat hounds/buzzards in time)
But afterward,
If there's one loot in the table, just roll, if over the meat percentage left, item is deleted.
If there's multiple loots, keep at least one of each, multiplying the number of each prefab by the meat percent rounded to ceiling.

It should be noted these are designed around Crystal-Crested Buzzards but other creatures could influence corpse meat level
]]

local function OverrideCorpseLoot(inst, lootprefab)
    local loot_override = CORPSE_LOOT_OVERRIDES[lootprefab]
    local overrideprefab, num
    if loot_override then
        if type(loot_override) == "function" then
            overrideprefab, num = FunctionOrValue(loot_override, inst, lootprefab)
        elseif type(loot_override) == "table" then
            overrideprefab, num = unpack(loot_override)
        else
            overrideprefab = loot_override
        end
    end

    return overrideprefab or lootprefab, num or 1
end

local function ProcessCorpseLoot(inst)
    local meat_perc = inst:GetMeatPercent()
    if inst.meat_level >= 2 then -- Multiple items, leave at least one of each at minimum
        if #inst.corpse_loot > 1 then
            local num_loot = {} --[prefab] = num
            --
            for i, prefab in ipairs(inst.corpse_loot) do
                local num = 1
                prefab, num = OverrideCorpseLoot(inst, prefab)
                num_loot[prefab] = (num_loot[prefab] or 0) + num
            end

            inst.corpse_loot = {}
            for prefab, num in pairs(num_loot) do
                for i = 1, math.max(1, math.ceil(num * meat_perc)) do
                    table.insert(inst.corpse_loot, prefab)
                end
            end
        elseif math.random() > meat_perc then -- Only one item, roll a chance to get rid of it.
            inst.corpse_loot = {} -- Flush it out.
        end
    end
end

local function DropCorpseLoot(inst)
    if inst.corpse_loot ~= nil then
        ProcessCorpseLoot(inst)
        --
        inst.components.lootdropper:DropLoot(inst:GetPosition(), inst.corpse_loot)
        inst.corpse_loot = nil
    end
end

local function OnSpawnedLoot(inst, data)
    local loot = data.loot
    -- If super ruined then do these effects!
    if inst.meat_level >= 2 then
        local meat_perc = inst.meat / (inst:GetMeatPerLevel() * 2) -- Only take into account two levels
        local perc_val = 0.1 + easing.outQuad(meat_perc, 0, 0.9, 1)

        if loot.components.armor then
            loot.components.armor:SetPercent(perc_val)
        elseif loot.components.perishable then
            loot.components.perishable:SetPercent(perc_val)
        elseif loot.components.fueled then
            loot.components.fueled:SetPercent(perc_val)
        elseif loot.components.finiteuses then
            loot.components.finiteuses:SetPercent(perc_val)
        end
    end
end

local ITEM_LAUNCHSPEED = 3
local ITEM_LAUNCHMULT = 1.5
local ITEM_STARTHEIGHT = 0.25
local ITEM_VERTICALSPEED = 4
local ITEM_VERTICALSPEED_VAR = 2
local function OnElectrocute(inst, data)
    -- Only launch for non-obstacles. Probably fine to run it anyways, but let's not if we don't have to.
    if checkbit(inst.Physics:GetCollisionMask(), COLLISION.OBSTACLES) then
        Launch2(inst, inst, ITEM_LAUNCHSPEED, ITEM_LAUNCHMULT, ITEM_STARTHEIGHT, 0, ITEM_VERTICALSPEED + math.random() * ITEM_VERTICALSPEED_VAR) -- Twitch and convulse!
    end
end
--------------------------------------------------------------------------------------------------------

local function GetDepMutantPrefab(mutant_data, fallback)
    return (mutant_data and mutant_data.overridemutantprefab)
        or fallback
end

local function MakeCreatureCorpse(data)
    local has_pre_rift_mutation = data.has_pre_rift_mutation
    local has_rift_mutation = data.has_rift_mutation

    local pre_rift_mutant_data = data.pre_rift_mutant_data
    local rift_mutant_data = data.rift_mutant_data

    local creature = data.creature
    local nameoverride = data.nameoverride

    local mutantprefab = has_pre_rift_mutation and GetDepMutantPrefab(pre_rift_mutant_data, "mutated"..creature)
    local riftmutantprefab = has_rift_mutation and GetDepMutantPrefab(rift_mutant_data, "mutated"..creature.."_gestalt")

    local lunar_mutated_tuning = pre_rift_mutant_data and pre_rift_mutant_data.enabled_tuning or nil
    local gestalt_mutated_tuning = rift_mutant_data and rift_mutant_data.enabled_tuning or nil

    local lunar_mutation_chance = pre_rift_mutant_data and pre_rift_mutant_data.mutation_chance or nil
    local gestalt_mutation_chance = rift_mutant_data and rift_mutant_data.mutation_chance or nil

    local assets =
    {
        Asset("SCRIPT", "scripts/prefabs/corpses_defs.lua"),
    }

    if data.override_build then
        table.insert(assets, Asset("ANIM", "anim/"..data.override_build..".zip"))
    end

    if data.assets then
        for i, asset in ipairs(data.assets) do
            table.insert(assets, asset)
        end
    end

    local prefabs = {}

    if type(mutantprefab) == "string" then
        table.insert(prefabs, mutantprefab)
    end

    if type(riftmutantprefab) == "string" then
        table.insert(prefabs, riftmutantprefab)
    end

    if has_rift_mutation then
        table.insert(prefabs, "corpse_gestalt")
    end

    if data.prefab_deps then
        for _, prefab in ipairs(data.prefab_deps) do
            table.insert(prefabs, prefab)
        end
    end

    local prefabname = creature.."corpse"

    local burntime = data.burntime or TUNING.MED_BURNTIME
    local fireoffset = data.fireoffset or Vector3(0, 0, 0)
    local sanity_aura = data.sanityaura or -TUNING.SANITYAURA_MED
    local sanity_aurafn = data.sanityaurafn or nil

    local scale = data.scale
    local faces = data.faces

    -- HACK (Omar): If we don't have a unique set of lines yet,
    -- just set to our generic set for now.
    local inspectable_nameoverride
    local desc_strings = STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(prefabname)]
    if desc_strings == nil or desc_strings.GENERIC == "TODO" then
        inspectable_nameoverride = "GENERIC_CORPSE"
    end

    local Corpse_OnSave = data.OnSave ~= nil and function(inst, savedata)
        data.OnSave(inst, savedata)
        OnSave(inst, savedata)
    end or OnSave

    local Corpse_OnLoad = data.OnLoad ~= nil and function(inst, savedata)
        data.OnLoad(inst, savedata)
        OnLoad(inst, savedata)
    end or OnLoad

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        if data.custom_physicsfn then
            data.custom_physicsfn(inst)
        elseif data.use_inventory_physics then
            MakeInventoryPhysics(inst, 1, data.physicsradius)
            inst:AddTag("blocker")
        else
            MakeObstaclePhysics(inst, data.physicsradius, 1)
        end

        inst.DynamicShadow:SetSize(unpack(data.shadowsize))

        if faces == FACES.FOUR then
            inst.Transform:SetFourFaced()
        elseif faces == FACES.SIX then
            inst.Transform:SetSixFaced()
        elseif faces == FACES.TWO then
            inst.Transform:SetTwoFaced()
        end

        if scale ~= nil then
            inst.Transform:SetScale(scale, scale, scale)
        end

        inst.AnimState:SetBank(data.bank)
        inst.AnimState:SetBuild(data.build)
        inst.AnimState:PlayAnimation("corpse")
		inst.AnimState:SetFinalOffset(1)

        if data.override_build ~= nil then
            inst.AnimState:AddOverrideBuild(data.override_build)
        end

		if data.tag ~= nil then
			inst:AddTag(data.tag)
		end

        if data.tags then
            for _, v in pairs(data.tags) do
                inst:AddTag(v)
            end
        end

        inst:AddTag("creaturecorpse")
        inst:AddTag("deadcreature")

        inst.creature = creature
        inst.nameoverride = nameoverride
        inst.displaynamefn = DisplayNameFn

        if data.common_postinit ~= nil then
            data.common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.is_corpse = true

        inst.mutantprefab = mutantprefab
        inst.riftmutantprefab = riftmutantprefab

        inst.spawn_lunar_mutated_tuning = lunar_mutated_tuning
        inst.spawn_gestalt_mutated_tuning = gestalt_mutated_tuning

        inst.StartLunarMutation = StartLunarMutation
        inst.StartLunarRiftMutation = StartLunarRiftMutation

        inst.WillMutate = WillMutate
        inst.IsMutating = IsMutating

        inst.IsFading = IsFading
        inst.HasGestaltArriving = HasGestaltArriving

        inst.GetMutantPrefab = GetMutantPrefab
        inst.GetRiftMutantPrefab = GetRiftMutantPrefab

        inst.SpawnGestalt = SpawnGestalt

        inst.SetAltBuild = SetAltBuild
        inst.SetAltBank = SetAltBank

        inst.StartFadeTimer = StartFadeTimer
        inst.StartGestaltTimer = StartGestaltTimer
        inst.StartReviveMutateTimer = StartReviveMutateTimer

        inst.SetGestaltCorpse = SetGestaltCorpse
        inst.SetNonGestaltCorpse = SetNonGestaltCorpse

        inst.SetCorpseData = SetCorpseData

        inst.DropCorpseLoot = DropCorpseLoot

        -----
        inst.meat_level = 1
	    inst.meat = GetMaxMeat(inst)

        inst.SetMeatPercent = SetMeatPercent
        inst.GetMeatPercent = GetMeatPercent
        inst.SetMeat = SetMeat
        inst.GetMaxMeat = GetMaxMeat
        inst.GetMeatPerLevel = GetMeatPerLevel

        inst:ListenForEvent("chomped", OnChomped)
        -----

        inst:AddComponent("inspectable")
        inst.components.inspectable.getstatus = GetStatus
        if inspectable_nameoverride then
            inst.components.inspectable:SetNameOverride(inspectable_nameoverride)
        end

        inst:AddComponent("sanityaura")
        inst.components.sanityaura.aura = sanity_aura
        inst.components.sanityaura.aurafn = sanity_aurafn --Can be nil

        inst:AddComponent("lootdropper")
        inst.components.lootdropper.overridewinterlootprefabname = creature

        inst:AddComponent("entitytracker")
        inst:AddComponent("savedscale")

        if data.makeburnablefn ~= nil then
		    data.makeburnablefn(inst, burntime, data.firesymbol, fireoffset)

            inst.components.burnable:SetOnIgniteFn(OnIgnited)
            inst.components.burnable:SetOnExtinguishFn(OnExtinguish)
            inst.components.burnable:SetOnBurntFn(OnBurnt)
        end

        -- Don't need this after all?
        --[[
        inst:AddComponent("edible")
        inst.components.edible.foodtype = FOODTYPE.CORPSE
        inst.components.edible.healthvalue = 0
        inst.components.edible.hungervalue = TUNING.CALORIES_SUPERHUGE
        inst.components.edible.sanityvalue = -TUNING.SANITY_HUGE
        ]]
        -------

        inst:SetStateGraph(data.sg)
        --inst:ListenForEvent("electrocute", OnElectrocute)
		inst.sg.mem.noelectrocute = true

        if lunar_mutation_chance then
            inst.lunar_mutation_chance = lunar_mutation_chance
        end
        if gestalt_mutation_chance then
            inst.gestalt_possession_chance = gestalt_mutation_chance
        end

        inst:AddComponent("timer")
        inst:ListenForEvent("timerdone", OnTimerDone)

        ----
        inst.persist_sources = SourceModifierList(inst, false, SourceModifierList.boolean)

        inst.SetPersistSource = SetPersistSource
        inst.RemovePersistSource = RemovePersistSource
        ----

        inst.OnSave = Corpse_OnSave
        inst.OnLoad = Corpse_OnLoad

        inst._override_immediate_gestalt_mutate_cb = data.override_immediate_gestalt_mutate_cb

        inst._on_load_post_pass = data.onloadpostpass
        inst.OnLoadPostPass = OnLoadPostPass

        inst.OnEntitySleep = OnEntitySleep
        inst.OnEntityWake = OnEntityWake

        MakeHauntableIgnite(inst)

        inst:ListenForEvent("loot_prefab_spawned", OnSpawnedLoot)

        if data.master_postinit ~= nil then
            data.master_postinit(inst)
        end

        -- Initialize
        TheWorld:PushEvent("ms_registercorpse", inst)

        return inst
    end

    return Prefab(prefabname, fn, assets, prefabs)
end

--------------------------------------------------------------------------------------------------------

local function MakeCreatureCorpse_Prop(data)
    local creature = data.creature
    local nameoverride = data.nameoverride
    local displaynameoverride = data.displaynameoverride --For the display name but NOT character examinations

    local prefabname = creature.."corpse_prop"

    local sanity_aura = data.sanityaura or -TUNING.SANITYAURA_MED
    local sanity_aurafn = data.sanityaurafn or nil

    local scale = data.scale
    local faces = data.faces

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        inst.DynamicShadow:SetSize(unpack(data.shadowsize))

        if faces == FACES.FOUR then
            inst.Transform:SetFourFaced()
        elseif faces == FACES.SIX then
            inst.Transform:SetSixFaced()
        elseif faces == FACES.TWO then
            inst.Transform:SetTwoFaced()
        end

        if scale ~= nil then
            inst.Transform:SetScale(scale, scale, scale)
        end

        inst.AnimState:SetBank(data.bank)
        inst.AnimState:SetBuild(data.build)
        inst.AnimState:PlayAnimation("corpse")

		if data.tag ~= nil then
			inst:AddTag(data.tag)
		end

        inst:AddTag("deadcreature")

        inst.creature = creature
        inst.nameoverride = nameoverride
        inst.displaynameoverride = displaynameoverride
        inst.displaynamefn = DisplayNameFn

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("sanityaura")
        inst.components.sanityaura.aura = sanity_aura
        inst.components.sanityaura.aurafn = sanity_aurafn --Can be nil

		if data.onrevealfn ~= nil then
			inst:ListenForEvent("propreveal", data.onrevealfn)
		end

        inst.SetAltBuild = SetAltBuild
        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        return inst
    end

    return Prefab(prefabname, fn)
end

local corpse_prefabs = {}

for _, corpse_data in ipairs(CORPSE_DEFS) do
    if not corpse_data.data_only then --allow mods to skip our prefab constructor.
        table.insert(corpse_prefabs, MakeCreatureCorpse(corpse_data))
    end
end

for _, corpse_data in ipairs(CORPSE_PROP_DEFS) do
    if not corpse_data.data_only then --allow mods to skip our prefab constructor.
        table.insert(corpse_prefabs, MakeCreatureCorpse_Prop(corpse_data))
    end
end

return unpack(corpse_prefabs)