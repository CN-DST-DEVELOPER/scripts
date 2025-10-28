local easing = require("easing")

--------------------------------------------------------------------------------------------------------

local corpse_defs = require("prefabs/corpses_defs")

local CORPSE_DEFS = corpse_defs.CORPSE_DEFS
local CORPSE_PROP_DEFS = corpse_defs.CORPSE_PROP_DEFS
local BUILDS = corpse_defs.BUILDS
local BUILDS_TO_NAMES = corpse_defs.BUILDS_TO_NAMES
local BANKS = corpse_defs.BANKS
local FACES = corpse_defs.FACES
corpse_defs = nil

local CORPSE_TIMERS = {
    ERODE = "erode_timer",
    SPAWN_GESTALT = "spawn_gestalt",
    REVIVE_MUTATE = "revive_timer", -- A non gestalt mutation. e.g. Horror Hound
}

local GESTALT_TRACK_NAME = "gestalt"

--------------------------------------------------------------------------------------------------------

local function SpawnGestalt(inst)
    if inst.components.burnable == nil or not inst.components.burnable:IsBurning() then
        local gestalt = SpawnPrefab("corpse_gestalt")

        inst.components.entitytracker:TrackEntity(GESTALT_TRACK_NAME, gestalt)

        gestalt:SetTarget(inst)
        gestalt:Spawn()

        return gestalt -- Mods
    end
end

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

local function OnExtinguish(inst)
    -- _skip_extinguish_fade is a hack to let buzzards extinguish the corpse without it being lost
    if not inst:IsMutating() and not inst._skip_extinguish_fade then
		DefaultExtinguishCorpseFn(inst)
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

local function SetAltBuild(inst, buildid)
    inst.build = buildid
    local builds = BUILDS[inst.creature]
    inst.AnimState:SetBuild(buildid ~= nil and builds[buildid] or builds.default)
end

local function SetAltBank(inst, bankid)
    inst.bank = bankid
    local banks = BANKS[inst.creature]
    inst.AnimState:SetBank(bankid ~= nil and banks[bankid] or banks.default)
end

local function OnSave(inst, data)
    data.is_reviving = inst.sg and inst.sg:HasStateTag("prerift_mutating") or nil
    data.is_gestalt_mutating = inst.sg and inst.sg:HasStateTag("lunarrift_mutating") or nil
    data.build = inst.build
    data.bank = inst.bank
    -- Extra data from the creature
    data.corpsedata = inst.corpsedata
    data.nolunarmutate = inst.sg and inst.sg.mem.nolunarmutate or nil
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.corpsedata = data.corpsedata
        SetAltBuild(inst, data.build)
        if data.bank then
            SetAltBank(inst, data.bank)
        end
        if data.nolunarmutate then
            inst.sg.mem.nolunarmutate = true
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

local function StartLunarMutation(inst, loading)
	DisableBurnable(inst)
    -- There's only one state, no need to do a loading skip
    inst.sg:GoToState("corpse_prerift_mutate", inst:GetMutantPrefab())
end

local function StartFadeTimer(inst, time)
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

local function DoFade(inst)
    inst:AddTag("NOCLICK")
    inst.persists = false
    inst.erode_task = inst:DoTaskInTime(2, ErodeAway)
end

local function OnTimerDone(inst, data)
    if not data then return end

    if data.name == CORPSE_TIMERS.ERODE then
        DoFade(inst)
    elseif data.name == CORPSE_TIMERS.SPAWN_GESTALT then
        inst:SpawnGestalt()
    elseif data.name == CORPSE_TIMERS.REVIVE_MUTATE then
        if inst:IsAsleep() then
            ReplacePrefab(inst, inst:GetMutantPrefab())
        else
            inst:StartLunarMutation()
        end
    end
end

local function ImmediateGestaltMutate(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
    local is_rift_mutant = gestalt ~= nil or inst.components.timer:TimerExists(CORPSE_TIMERS.SPAWN_GESTALT)
    if is_rift_mutant then
        if inst._override_immediate_gestalt_mutate_cb ~= nil then
            inst._override_immediate_gestalt_mutate_cb(inst, gestalt)
        else
            ReplacePrefab(inst, inst:GetRiftMutantPrefab())

            if gestalt then
                gestalt:Remove()
            end
        end
    else
        inst:Remove()
    end
end

local function ImmediateNonGestaltMutate(inst)
    ReplacePrefab(inst, inst:GetMutantPrefab())
end

local function OnEntitySleep(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
    if gestalt then -- Gestalt mutation
        local time = math.sqrt(inst:GetDistanceSqToInst(gestalt) / gestalt.components.locomotor.runspeed) -- Rough estimation
        inst.mutate_task = inst:DoTaskInTime(time, ImmediateGestaltMutate)
    elseif inst.components.timer:TimerExists(CORPSE_TIMERS.SPAWN_GESTALT) then
        inst.mutate_task = inst:DoTaskInTime(0, ImmediateGestaltMutate)
    elseif inst.sg:HasStateTag("prerift_mutating") then -- Regular mutation
        -- Timer is handled in timer finish.
        inst.mutate_task = inst:DoTaskInTime(0, ImmediateNonGestaltMutate) --Just do it instantly.
    end
end

local function OnEntityWake(inst)
    if inst.mutate_task ~= nil then
        inst.mutate_task:Cancel()
        inst.mutate_task = nil
    end
end

local function SetGestaltCorpse(inst)
    inst:SpawnGestalt()
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
    return inst._eroding_away or inst.components.timer:TimerExists(CORPSE_TIMERS.ERODE)
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
        DoFade(inst)
    end
end

local function SetPersistSource(inst, source, persists)
    inst.persist_sources:SetModifier(inst, persists, source)
end

local function RemovePersistSource(inst, source)
    inst.persist_sources:RemoveModifier(inst, source)
    CheckPersist(inst)
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

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        if data.custom_physicsfn then
            data.custom_physicsfn(inst)
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
        inst.AnimState:SetBuild(BUILDS[creature].default)
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

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

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

        inst:AddComponent("entitytracker")

        inst:AddComponent("inspectable")
        inst.components.inspectable.getstatus = GetStatus

        inst:AddComponent("sanityaura")
        inst.components.sanityaura.aura = sanity_aura
        inst.components.sanityaura.aurafn = sanity_aurafn --Can be nil

        inst:AddComponent("savedscale")

		data.makeburnablefn(inst, burntime, data.firesymbol, fireoffset)

        inst.components.burnable:SetOnIgniteFn(OnIgnited)
        inst.components.burnable:SetOnExtinguishFn(OnExtinguish)

        -- Don't need this after all?
        --[[
        inst:AddComponent("edible")
        inst.components.edible.foodtype = FOODTYPE.CORPSE
        inst.components.edible.healthvalue = 0
        inst.components.edible.hungervalue = TUNING.CALORIES_SUPERHUGE
        inst.components.edible.sanityvalue = -TUNING.SANITY_HUGE
        ]]

        inst:SetStateGraph(data.sg)
		inst.sg.mem.noelectrocute = true

        inst:AddComponent("timer")
        inst:ListenForEvent("timerdone", OnTimerDone)

        ----
        inst.persist_sources = SourceModifierList(inst, false, SourceModifierList.boolean)

        inst.SetPersistSource = SetPersistSource
        inst.RemovePersistSource = RemovePersistSource
        ----

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        inst._override_immediate_gestalt_mutate_cb = data.override_immediate_gestalt_mutate_cb

        inst._on_load_post_pass = data.onloadpostpass
        if inst._on_load_post_pass ~= nil then
            inst.OnLoadPostPass = OnLoadPostPass
        end

        inst.OnEntitySleep = OnEntitySleep
        inst.OnEntityWake = OnEntityWake

        MakeHauntableIgnite(inst)

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
        inst.AnimState:SetBuild(BUILDS[creature].default)
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