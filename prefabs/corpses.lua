local easing = require("easing")

--------------------------------------------------------------------------------------------------------
--V2C: We won't bother adding assets for corpses, since they are so tied
--     to the creatures themselves, which may come with alternate builds

local BUILDS =
{
    deerclops =
    {
        default = "deerclops_build",
        yule = "deerclops_yule",
    },

    warg =
    {
        default = "warg_build",
        gingerbread = "warg_gingerbread_build",
    },

    bearger =
    {
        default = "bearger_build",
        yule = "bearger_yule",
    },

    koalefant =
    {
        default = "koalefant_summer_build",
        winter = "koalefant_winter_build",
    },

    bird =
    {
        default = "crow_build",
        robin = "robin_build",
        robin_winter = "robin_winter_build",
        canary = "canary_build",
        quagmire_pigeon = "quagmire_pigeon_build",
        puffin = "puffin_build", --Puffins have a unique bank too
    },

    buzzard =
    {
        default = "buzzard_build",
    }
}

local BUILDS_TO_NAMES =
{
    bird = {
        crow_build = "crow",
        robin_build = "robin",
        robin_winter_build = "robin_winter",
        canary_build = "canary",
        quagmire_pigeon_build = "quagmire_pigeon",
        puffin_build = "puffin",
    }
}

local BANK_OVERRIDES = {
    bird =
    {
        default = "crow",
        puffin = "puffin",
    }
}

local FACES =
{
    FOUR = 1,
    SIX  = 2,
    TWO  = 3,
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

local function OnIgnited(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
	if gestalt ~= nil then
        gestalt:SetTarget(nil)
    end
end

local function OnExtinguish(inst)
    if not inst.sg:HasStateTag("mutating") then
		DefaultExtinguishCorpseFn(inst)
    end
end

local function GetStatus(inst)
    return
           (inst.sg:HasStateTag("mutating") and "REVIVING")
        or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) and "BURNING"
        or nil
end

local function DisplayNameFn(inst)
    local build_override = inst:IsValid() and inst.use_build_nameoverride and BUILDS_TO_NAMES[inst.creature] and BUILDS_TO_NAMES[inst.creature][inst.AnimState:GetBuild()] or nil --Client, don't use inst.build
    return inst.creature ~= nil and STRINGS.NAMES[string.upper(build_override or inst.displaynameoverride or inst.nameoverride or inst.creature)] or nil
end

--------------------------------------------------------------------------------------------------------

local function SetAltBuild(inst, buildid)
    inst.build = buildid
    local builds = BUILDS[inst.creature]
    inst.AnimState:SetBuild(buildid ~= nil and builds[buildid] or builds.default)
end

local function SetAltBank(inst, bankid)
    inst.bank = bankid
    local banks = BANK_OVERRIDES[inst.creature]
    inst.AnimState:SetBank(bankid ~= nil and banks[bankid] or banks.default)
end

local function OnSave(inst, data)
    data.ready = inst.sg and inst.sg:HasStateTag("mutating") or nil
    data.build = inst.build
    data.bank = inst.bank
end

local function OnLoad(inst, data)
    if data ~= nil then
        SetAltBuild(inst, data.build)
        SetAltBank(inst, data.bank)
        if data.ready then
            inst:StartMutation(true)
        end
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

local function StartMutation(inst, loading)
	inst.components.burnable:SetOnIgniteFn(nil)
	inst.components.burnable:SetOnExtinguishFn(nil)
	inst.components.burnable:SetOnBurntFn(nil)

    inst.sg:GoToState(loading and "corpse_mutate" or "corpse_mutate_pre", inst.mutantprefab)

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

local CORPSE_TIMERS = {
    ERODE = "erode_timer",
    SPAWNGESTALT = "spawn_gestalt",
}

local function StartFadeTimer(inst, time)
    inst.components.timer:StartTimer(CORPSE_TIMERS.ERODE, time)
end

local function StartGestaltTimer(inst, time)
    if inst.build == "puffin" then --FIXME: No mutation for puffins! For now.
        StartFadeTimer(inst, time)
        return
    end
    inst.components.timer:StartTimer(CORPSE_TIMERS.SPAWNGESTALT, time)
end

local function OnTimerDone(inst, data)
    if not data then
        return
    end

    if data.name == CORPSE_TIMERS.ERODE then
        ErodeAway(inst, 2)
    elseif data.name == CORPSE_TIMERS.SPAWNGESTALT then
        inst:SpawnGestalt()
    end
end

local function ImmediateMutate(inst)
    local gestalt = inst.components.entitytracker:GetEntity(GESTALT_TRACK_NAME)
    if gestalt then
        ReplacePrefab(inst, inst.mutantprefab)
        gestalt:Remove()
    else
        inst:Remove()
    end
end

--------------------------------------------------------------------------------------------------------

local function MakeCreatureCorpse(data)
    local creature = data.creature
    local nameoverride = data.nameoverride

    local mutantprefab = "mutated"..creature
    local prefabname = creature.."corpse"

    local prefabs = {mutantprefab, "corpse_gestalt"}

    local burntime = data.burntime or TUNING.MED_BURNTIME
    local sanity_aura = data.sanityaura or -TUNING.SANITYAURA_MED
    local sanity_aurafn = data.sanityaurafn or nil

    local scale = data.scale
    local faces = data.faces

    local OnEntitySleep
    if data.mutate_on_entity_sleep then
        OnEntitySleep = ImmediateMutate
    end

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

		if data.tag ~= nil then
			inst:AddTag(data.tag)
		end

        if data.tags then
            for _, v in pairs(data.tags) do
                inst:AddTag(v)
            end
        end

        inst:AddTag("deadcreature")

        inst.creature = creature
        inst.nameoverride = nameoverride
        inst.displaynamefn = DisplayNameFn
        inst.use_build_nameoverride = data.use_build_nameoverride

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.mutantprefab = mutantprefab

        inst.StartMutation = StartMutation
        inst.SpawnGestalt = SpawnGestalt
        inst.SetAltBuild = SetAltBuild
        inst.SetAltBank = SetAltBank
        inst.StartFadeTimer = StartFadeTimer
        inst.StartGestaltTimer = StartGestaltTimer

        inst:AddComponent("entitytracker")

        inst:AddComponent("inspectable")
        inst.components.inspectable.getstatus = GetStatus

        inst:AddComponent("sanityaura")
        inst.components.sanityaura.aura = sanity_aura
        inst.components.sanityaura.aurafn = sanity_aurafn --Can be nil

		data.makeburnablefn(inst, burntime, data.firesymbol)

        inst.components.burnable:SetOnIgniteFn(OnIgnited)
        inst.components.burnable:SetOnExtinguishFn(OnExtinguish)

        inst:SetStateGraph(data.sg)
		inst.sg.mem.noelectrocute = true

        -- One time spawn!
        if not POPULATING and not data.no_gestalt_spawn then
            inst:DoTaskInTime(0, inst.SpawnGestalt)
        end

        inst:AddComponent("timer")
        inst:ListenForEvent("timerdone", OnTimerDone)

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        inst.OnEntitySleep = OnEntitySleep or inst.Remove

        MakeHauntableIgnite(inst)

        return inst
    end

    return Prefab(prefabname, fn, nil, prefabs)
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

return  -- For search: deerclopscorpse
    MakeCreatureCorpse({
        creature = "deerclops",
        bank = "deerclops",
        sg = "SGdeerclops",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        physicsradius = .5,
        shadowsize = {6, 3.5},
        scale = 1.65,
        tag = "deerclops",

        sanityaura = -TUNING.SANITYAURA_LARGE,
    }),

    -- For search: wargcorpse
    MakeCreatureCorpse({
        creature = "warg",
        bank = "warg",
        sg = "SGwarg",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.SIX,
        physicsradius = 1,
        shadowsize = {2.5, 1.5},
    }),

    -- For search: beargercorpse
    MakeCreatureCorpse({
        creature = "bearger",
        bank = "bearger",
        sg = "SGbearger",
        firesymbol = "swap_fire",
        makeburnablefn = MakeLargeBurnableCorpse,
        faces = FACES.FOUR,
        physicsradius = 1.5,
        shadowsize = {6, 3.5},
        tag = "bearger_blocker",

        sanityaura = -TUNING.SANITYAURA_LARGE,
    }),

    -- For search: koalefantcorpse_prop
    MakeCreatureCorpse_Prop({
        creature = "koalefant",
        bank = "koalefant",
        nameoverride = "koalefant_carcass",
        displaynameoverride = "koalefant_summer",
        faces = FACES.SIX,
        shadowsize = {4.5, 2},
        onrevealfn = function(inst, revealer)
            inst.persists = false
            inst:AddTag("NOCLICK")
            inst:ListenForEvent("animover", inst.Remove)
            inst.AnimState:PlayAnimation("carcass_fake")
        end,

        sanityaura = -TUNING.SANITYAURA_SMALL,
    }),

    -- For search: birdcorpse
    MakeCreatureCorpse({
        creature = "bird",
        bank = "crow",
        sg = "SGbird",
        firesymbol = "crow_body",
        makeburnablefn = MakeSmallBurnableCorpse,
        burntime = TUNING.SMALL_BURNTIME,
        faces = FACES.TWO,
        tags = {"small_corpse", "birdcorpse"},
        no_gestalt_spawn = true,
        mutate_on_entity_sleep = true,
        use_build_nameoverride = true, --Use the build to get the name
        shadowsize = {1, .75},
        custom_physicsfn = function(inst)
            inst.entity:AddPhysics()
            inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
            inst.Physics:SetCollisionMask(COLLISION.WORLD)
            inst.Physics:SetMass(1)
            inst.Physics:SetSphere(1)
            inst.Physics:SetFriction(.3)
        end,

        sanityaura = -TUNING.SANITYAURA_SMALL,
    }),

    -- For search: buzzardcorpse
    MakeCreatureCorpse({
        creature = "buzzard",
        bank = "buzzard",
        sg = "SGbuzzard",
        firesymbol = "buzzard_body",
        makeburnablefn = MakeMediumBurnableCorpse,
        burntime = TUNING.MED_BURNTIME,
        faces = FACES.TWO,
        tags = {"small_corpse"},
        mutate_on_entity_sleep = true,
        shadowsize = {1.25, .75},
        physicsradius = .25,

        sanityaura = -TUNING.SANITYAURA_MED,
    })