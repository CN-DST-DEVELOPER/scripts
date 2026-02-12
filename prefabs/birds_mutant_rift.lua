require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/bird_lunar.zip"),
    Asset("ANIM", "anim/bird_lunar_build.zip"),
    Asset("SOUND", "sound/lunarhail_event.fsb"),
}

local prefabs =
{
    "spoiled_food",
    "purebrilliance",
    --"lunarfeather",
}

local mutated_scrapbook_adddeps =
{
	"lunarthrall_plant_gestalt",
}

SetSharedLootTable('bird_mutant_rift',
{
    {'spoiled_food',       1.00},
})

local sounds =
{
    flyin = "dontstarve/birds/flyin",
    chirp = "lunarhail_event/creatures/lunar_crow/caw",
    takeoff = "lunarhail_event/creatures/lunar_crow/fly_out",
    attack = "lunarhail_event/creatures/lunar_crow/attack",
    eat = "lunarhail_event/creatures/lunar_crow/peck_shard",
    death = "lunarhail_event/creatures/lunar_crow/death",
}

local brain = require "brains/bird_mutant_rift_brain"
local easing = require "easing"

local BRILLIANCE_TIMER = "brilliancecooldown"

----------------------------------------------------------

local function OnTrapped(inst, data)
    if data and data.trapper and data.trapper.settrapsymbols then
        data.trapper.settrapsymbols(inst.trappedbuild)
    end
end

local function SetBirdTrapData(inst)
	local t = inst.components.timer:GetTimeLeft(BRILLIANCE_TIMER)
	return t ~= nil and {
		brilliance_cooldown = t,
	} or nil
end

local function RestoreBirdFromTrap(inst, data)
	if data ~= nil and data.brilliance_cooldown ~= nil then
		inst.components.timer:StartTimer(BRILLIANCE_TIMER, data.brilliance_cooldown)
        inst:UpdateBrillianceVisual()
	end
end

local function OnDropped(inst)
    inst.sg:GoToState("stunned")
end

local function IsOnBrillianceCooldown(inst)
    return inst.components.timer:TimerExists(BRILLIANCE_TIMER)
end

local function UpdateBrillianceVisual(inst, cage)
    local off_cd = not IsOnBrillianceCooldown(inst)

    local function UpdateInst(_inst)
        if off_cd then
            _inst.AnimState:SetSymbolBloom("bird_gem")
            _inst.AnimState:SetSymbolLightOverride("bird_gem", 1)
            _inst.AnimState:SetSymbolLightOverride("crow_beak", 0.3)
        else
            _inst.AnimState:ClearSymbolBloom("bird_gem")
            _inst.AnimState:SetSymbolLightOverride("bird_gem", 0)
            _inst.AnimState:SetSymbolLightOverride("crow_beak", 0)
        end
    end

    UpdateInst(inst)
    if cage then
        UpdateInst(cage)
    end
end

local function PutOnBrillianceCooldown(inst, cage)
    inst._infused_eaten = 0
    inst.components.timer:StartTimer(BRILLIANCE_TIMER, TUNING.RIFT_BIRD_BRILLIANCE_TIMER)
    UpdateBrillianceVisual(inst, cage)
end

local function OnTimerDone(inst, data)
    if data and data.name == BRILLIANCE_TIMER then
        UpdateBrillianceVisual(inst, inst.components.occupier:GetOwner())
    end
end

--

local function OnDeath(inst)
    inst.AnimState:ClearSymbolBloom("bird_gem")
    inst.AnimState:SetSymbolLightOverride("bird_gem", 0)
    inst.AnimState:SetSymbolLightOverride("crow_beak", 0)
end

local function OnSave(inst, data)
    data.infused_eaten = inst._infused_eaten
end

local function OnLoad(inst, data)
    if data then
        inst._infused_eaten = data._infused_eaten or 0
    end
end

local DIET = { FOODTYPE.LUNAR_SHARDS }
local function commonfn()
    local inst = CreateEntity()
    --Core components
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddPhysics()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    --Initialize physics
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.SMALLOBSTACLES
	)
    inst.Physics:SetMass(1)
    inst.Physics:SetSphere(0.25)

	inst:AddTag("soulless") -- no wortox souls
    inst:AddTag("bird")
    inst:AddTag("lunar_aligned")
    inst:AddTag("smallcreature")
    inst:AddTag("bird_mutant_rift")
    inst:AddTag("gestaltmutant")

    inst.Transform:SetTwoFaced()

    inst.DynamicShadow:SetSize(1, .75)
    inst.DynamicShadow:Enable(false)

    inst.AnimState:SetBank("crow")
    inst.AnimState:SetBuild("bird_lunar_build")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetSymbolBloom("bird_gem")
    inst.AnimState:SetSymbolLightOverride("bird_gem", 1)
    inst.AnimState:SetSymbolLightOverride("crow_beak", 0.3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.scrapbook_adddeps = mutated_scrapbook_adddeps

    inst.sounds = sounds
    inst.flyawaydistance = TUNING.BIRD_SEE_THREAT_DISTANCE

    inst:AddComponent("inspectable")

    inst:AddComponent("occupier")

    inst:AddComponent("eater")
    inst.components.eater:SetDiet(DIET, DIET)

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = TUNING.RIFT_BIRD_WALKSPEED
    inst.components.locomotor.runspeed = TUNING.RIFT_BIRD_RUNSPEED
    inst.components.locomotor:EnableGroundSpeedMultiplier(true)
    inst.components.locomotor:SetTriggersCreep(true)

	inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.RIFT_BIRD_HEALTH)
    inst.components.health.murdersound = "dontstarve/wilson/hit_animal"

    inst:AddComponent("entitytracker")

    inst:AddComponent("timer")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.RIFT_BIRD_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.RIFT_BIRD_ATTACK_RANGE)
	inst.components.combat:SetRange(TUNING.RIFT_BIRD_ATTACK_RANGE)
    --inst.components.combat:SetRetargetFunction(1, Retarget)

    inst:AddComponent("planarentity")

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.RIFT_BIRD_PLANAR_DAMAGE)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.nobounce = true
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.canbepickedupalive = true
    inst.components.inventoryitem:SetSinks(true)

    inst:ListenForEvent("ontrapped", OnTrapped)
    inst.settrapdata = SetBirdTrapData
	inst.restoredatafromtrap = RestoreBirdFromTrap

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('bird_mutant_rift')

	inst:AddComponent("knownlocations")
    MakeHauntablePanic(inst)
    MakeFeedableSmallLivestock(inst, TUNING.BIRD_PERISH_TIME, nil, OnDropped)
    MakeSmallBurnableCharacter(inst, "crow_body")
    MakeTinyFreezableCharacter(inst, "crow_body")

    local birdspawner = TheWorld.components.birdspawner
    if birdspawner ~= nil then
        inst:ListenForEvent("onremove", birdspawner.StopTrackingFn)
        inst:ListenForEvent("enterlimbo", birdspawner.StopTrackingFn)
        birdspawner:StartTracking(inst)
    end

    inst._infused_eaten = 0
    inst.clear_buildup_in_one = true

    inst:SetStateGraph("SGbird")
    inst:SetBrain(brain)
    inst.sg.mem.nocorpse = true

    inst.PutOnBrillianceCooldown = PutOnBrillianceCooldown
    inst.UpdateBrillianceVisual = UpdateBrillianceVisual
    inst.IsOnBrillianceCooldown = IsOnBrillianceCooldown
    inst:DoTaskInTime(0, inst.UpdateBrillianceVisual)

    inst:ListenForEvent("timerdone", OnTimerDone)
    inst:ListenForEvent("death", OnDeath)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

	return inst
end

local function crowfn()
	local inst = commonfn()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.trappedbuild = "bird_lunar_build"

	return inst
end

-- All birds currently mutate into this one
return Prefab("mutatedbird", crowfn, assets, prefabs)