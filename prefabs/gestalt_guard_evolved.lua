require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/brightmare_gestalt_evolved.zip"),
}

local prefabs =
{
	"gestalt_head",
	"gestalt_guard_head",
    "purebrilliance",
    "moonglass_charged",
    "alterguardianhat_projectile",
    "gestalt_guard_projectile",
}

local prefabs_projectile = {
    "impact",
    "mining_moonglass_fx",
}

local brain = require "brains/gestalt_guard_evolvedbrain"

local shadow_tags = {"nightmarecreature", "shadowcreature", "shadow", "shadowminion", "stalker", "stalkerminion", "nightmare", "shadow_fire"}

local attack_any_tags = ConcatArrays({"player","gestalt_possessable"}, shadow_tags)
local attack_cant_tags = {"playerghost", "INLIMBO", "FX", "DECOR"}
local watch_must_tags = {"player"}
local SLEEPING_TAGS = {"bedroll", "knockout", "sleeping", "tent", "waking"}

SetSharedLootTable("gestalt_guard_evolved",
{
    {"purebrilliance", 1.0},
    {"purebrilliance", 0.2},
})
SetSharedLootTable("gestalt_guard_evolved_2",
{
    {"purebrilliance", 1.0},
    {"purebrilliance", 0.5},
    {"purebrilliance", 0.2},
})
SetSharedLootTable("gestalt_guard_evolved_3",
{
    {"purebrilliance", 1.0},
    {"purebrilliance", 0.8},
    {"purebrilliance", 0.5},
    {"purebrilliance", 0.2},
})

local function SetupKilledPetLoot(inst, petcount)
    if (inst._petcount or 0) < petcount then
        inst._petcount = petcount
        if inst.components.lootdropper then
            if petcount > 1 then
                inst.components.lootdropper:SetChanceLootTable("gestalt_guard_evolved_" .. math.min(petcount, 3))
            else
                inst.components.lootdropper:SetChanceLootTable("gestalt_guard_evolved")
            end
        end
    end
end

local function SetupDespawnPetLoot(inst)
    if inst.components.lootdropper then
        local hp_percent = inst.components.health and inst.components.health:GetPercent() or 1
        local rewardcount = math.floor(hp_percent * TUNING.GESTALT_EVOLVED_PLANTING_MOONGLASS_REQUIREMENT)
        local loot = {}
        for i = 1, rewardcount do
            table.insert(loot, "moonglass_charged")
        end
        inst.components.lootdropper:SetLoot(loot)
        inst.components.lootdropper:SetChanceLootTable(nil)
        inst.components.lootdropper:SetLootSetupFn(nil)
        inst.components.lootdropper:ClearRandomLoot()
    end
end

local function SetHeadAlpha(inst, a)
	if inst.blobhead then
		inst.blobhead.AnimState:OverrideMultColour(1, 1, 1, a)
	end
end

local function OnDespawn(inst)
    local owner = inst.components.follower and inst.components.follower.leader or nil
    if owner and owner.components.petleash then
        owner.components.petleash:DetachPet(inst)
    end
    inst:SetupDespawnPetLoot()
    inst.components.lootdropper:DropLoot(inst:GetPosition())
    inst:Remove()
end

local function OnEntitySleep(inst)
    inst._sleep_despawn_task = inst:DoTaskInTime(10, OnDespawn)
end
local function OnEntityWake(inst)
    if inst._sleep_despawn_task then
        inst._sleep_despawn_task:Cancel()
        inst._sleep_despawn_task = nil
    end
end

local function GetLevelForTarget(target)
	-- L1: 0.5 to 1.0 is ignore
	-- L2: 0.0 to 0.5 is look at behaviour
	-- L3: shadow target, attack it!

	if target ~= nil then
		if target:HasTag("gestalt_possessable") then
			return 3, 0
		end

		local inventory = target.replica.inventory
		if inventory ~= nil and inventory:EquipHasTag("shadow_item") then
			return 3, 0
		end

		local sanity_rep = target.replica.sanity
		if sanity_rep ~= nil then
			local sanity = sanity_rep:IsLunacyMode() and sanity_rep:GetPercentWithPenalty() or 0
			local level = (sanity < 0.33 and 1) or 3
			return level, sanity
		end

        if target:HasAnyTag(shadow_tags) then
            return 3, 0
        end
	end

	return 1, 1
end

local function Client_CalcTransparencyRating(inst, observer)
	-- Replica component might not exist yet when we run this :)
	if inst.replica.combat and inst.replica.combat:GetTarget() ~= nil then
		return TUNING.GESTALT_COMBAT_TRANSPERENCY -- 0.85
	end

	local level, sanity = GetLevelForTarget(observer)
	if level >= 3 then
		return TUNING.GESTALT_COMBAT_TRANSPERENCY -- 0.85
    else
        local x = (.7*sanity - .7)
        return math.min(x*x + .2, TUNING.GESTALT_COMBAT_TRANSPERENCY)
    end
end

local function KeepTarget(inst, target)
    if target == inst.components.follower.leader then
        return true
    end

    local t = GetTime()
    local LOSE_AGGRO_TIME = TUNING.GESTALT_EVOLVED_LOSE_AGGRO_TIME
    if inst.components.combat.lastwasattackedbytargettime + LOSE_AGGRO_TIME >= t or -- Has not hit us in time
        target.components.combat and target.components.combat:IsRecentTarget(inst) and (target.components.combat.laststartattacktime or 0) + LOSE_AGGRO_TIME >= t -- Has not tried hitting us in time
    then
        return false
    end

    return true
end

local function Retarget(inst)
    if inst.components.combat.target == nil then
        return inst.components.follower.leader
    end

    return nil
end

local function onattackother(inst, data)
	local target = data ~= nil and data.target or nil

	local burnable = target:IsValid() and target.components.burnable or nil
    if burnable ~= nil and burnable:IsBurning() and target:HasTag("shadow_fire") then
        burnable:Extinguish()
    end
end

local function CanShareTargetFn(dude)
    return dude:HasTag("brightmare_guard") and dude.components.health and not dude.components.health:IsDead()
end

local function OnAttacked(inst, data)
    inst._times_hit_since_last_teleport = inst._times_hit_since_last_teleport + 1
    if data.attacker and data.attacker ~= inst.components.follower.leader then
        inst.components.combat:SetTarget(data.attacker)
        inst.components.combat:ShareTarget(data.attacker, 30, CanShareTargetFn, 1)
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function TryAttack_Teleport_Do(inst)
    local target = inst.components.combat.target
    -- Target is assumed to be valid here called from brain tree where it does the validation.

    local x, y, z = inst.Transform:GetWorldPosition()
    local targetpos = target:GetPosition()

    local minrange = TUNING.GESTALT_EVOLVED_CLOSE_RANGE
    local maxrange = TUNING.GESTALT_EVOLVED_MID_RANGE
    local deltarange = maxrange - minrange

    local maxtries = 10
    while maxtries > 0 do
        maxtries = maxtries - 1
        local range = math.random() * deltarange + minrange
        local offset = FindWalkableOffset(targetpos, PI2 * math.random(), range, 12, true, false, NoHoles, true, true)
        if offset then
            targetpos.x = targetpos.x + offset.x
            targetpos.z = targetpos.z + offset.z
            inst._times_hit_since_last_teleport = 0
            inst:PushEventImmediate("teleport", {dest = targetpos})
            return true
        end
    end

    return true
end

local function TryAttack_Teleport_Evade(inst)
    if inst._times_hit_since_last_teleport < TUNING.GESTALT_EVOLVED_TELEPORT_HITS_NEEDED then
        return false
    end

    if inst.components.timer:TimerExists("teleport_cd") then
        return false
    end

    if not inst:TryAttack_Teleport_Do() then
        return false
    end

    inst.components.timer:StartTimer("teleport_cd", TUNING.GESTALT_EVOLVED_TELEPORT_COOLDOWN)
    return true
end

local function TryAttack_Teleport_GetCloser(inst)
    if not inst:TryAttack_Teleport_Do() then
        return false
    end

    return true
end

local function TryAttack_Close(inst)
    return inst.components.combat:TryAttack()
end

local function DoAttack_Mid(inst)
    local target = inst.components.combat.target
    if not (target and target:IsValid()) then
        return
    end

    local x, y, z = target.Transform:GetWorldPosition()
    local gestalt = SpawnPrefab("alterguardianhat_projectile")
    gestalt._focustarget = target
    gestalt.components.combat:SetDefaultDamage(TUNING.GESTALT_EVOLVED_MID_DAMAGE)
    gestalt:AddComponent("planardamage")
    gestalt.components.planardamage:SetBaseDamage(TUNING.GESTALT_EVOLVED_MID_PLANAR_DAMAGE)
    local r = GetRandomMinMax(3, 5)
    local delta_angle = GetRandomMinMax(-90, 90)
    local angle = (inst:GetAngleToPoint(x, y, z) + delta_angle + 180) * DEGREES
    gestalt.Transform:SetPosition(x + r * math.cos(angle), y, z + r * -math.sin(angle))
    gestalt:ForceFacePoint(x, y, z)
    gestalt:SetTargetPosition(Vector3(x, y, z))
    gestalt.components.follower:SetLeader(inst)
end

local function TryAttack_Mid(inst)
    if inst.components.timer:TimerExists("midattack_cd") then
        return false
    end

    inst:PushEventImmediate("doattack_mid")
    if inst.sg.currentstate.name ~= "attack_mid" then
        return false
    end

    inst.components.timer:StartTimer("midattack_cd", TUNING.GESTALT_EVOLVED_MID_COOLDOWN)
    return true
end

local function DoAttack_Far(inst)
    local target = inst.components.combat.target
    if not (target and target:IsValid()) then
        return
    end

    inst.SoundEmitter:PlaySound("turnoftides/common/together/moon_glass/break")
    local x, y, z = inst.Transform:GetWorldPosition()
    local baseangle = inst.Transform:GetRotation()
    local splitangle = TUNING.GESTALT_EVOLVED_FAR_SPLIT_ANGLE
    for i = -1, 1 do
        local deltaangle = i * splitangle
        local projectile = SpawnPrefab("gestalt_guard_projectile")
        projectile.Transform:SetPosition(x, y, z)
        projectile.components.projectile:SetLaunchAngle(baseangle + deltaangle)
        projectile.components.projectile:Throw(inst, target, inst)
    end
end

local function TryAttack_Far(inst)
    if inst.components.timer:TimerExists("farattack_cd") then
        return false
    end

    inst:PushEventImmediate("doattack_far")
    if inst.sg.currentstate.name ~= "attack_far" then
        return false
    end

    inst.components.timer:StartTimer("farattack_cd", TUNING.GESTALT_EVOLVED_FAR_COOLDOWN)
    return true
end


local function OnSave(inst, data)
    data.petcount = inst._petcount
end

local function OnLoad(inst, data)
    if data then
        if data.petcount then
            inst:SetupKilledPetLoot(data.petcount)
        end
    end
end

local function AddTransparentOnSanity(inst, most_alpha)
    local transparentonsanity = inst:AddComponent("transparentonsanity")
    transparentonsanity.most_alpha = most_alpha
    transparentonsanity.osc_amp = .05
    transparentonsanity.osc_speed = 5.25 + math.random() * 0.5
    transparentonsanity.calc_percent_fn = Client_CalcTransparencyRating
    transparentonsanity.onalphachangedfn = SetHeadAlpha
    transparentonsanity:ForceUpdate()
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    local physics = inst.entity:AddPhysics()
    physics:SetMass(1)
    physics:SetFriction(0)
    physics:SetDamping(5)
    physics:SetCollisionGroup(COLLISION.FLYERS)
    physics:SetCollisionMask(COLLISION.GROUND)
    physics:SetCapsule(0.5, 1)

    inst:AddTag("brightmare")
    inst:AddTag("brightmare_guard")
    inst:AddTag("crazy") -- so they can attack shadow creatures
    inst:AddTag("extinguisher") -- to put out nightlights
    inst:AddTag("lunar_aligned")
    inst:AddTag("NOBLOCK")
    inst:AddTag("scarytoprey")
    inst:AddTag("soulless") -- no wortox souls
    inst:AddTag("hostile")
    inst:AddTag("alwayshostile")

    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(0.8, 0.8, 0.8)

    inst.AnimState:SetBuild("brightmare_gestalt_evolved")
    inst.AnimState:SetBank("brightmare_gestalt_evolved")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:Hide("mouseover")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    if not TheNet:IsDedicated() then
        inst.blobhead = SpawnPrefab("gestalt_guard_head")
        inst.blobhead.entity:SetParent(inst.entity) --prevent 1st frame sleep on clients
        inst.blobhead.Follower:FollowSymbol(inst.GUID, "head_fx_big", 0, 0, 0, true)

        inst.blobhead.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        inst.blobhead.persists = false

        inst.highlightchildren = { inst.blobhead }

        -- this is purely view related
        AddTransparentOnSanity(inst, 0.4)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_overridedata = {"head_fx_big", "brightmare_gestalt_head_evolved", "head_fx_big"}

    inst.no_spawn_fx = true
    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst._times_hit_since_last_teleport = 0

    inst:AddComponent("timer")

    local combat = inst:AddComponent("combat")
    combat:SetDefaultDamage(TUNING.GESTALT_EVOLVED_CLOSE_DAMAGE)
    combat:SetRange(TUNING.GESTALT_EVOLVED_CLOSE_RANGE)
    combat:SetAttackPeriod(TUNING.GESTALT_EVOLVED_CLOSE_COOLDOWN)
    combat:SetRetargetFunction(1, Retarget)
    combat:SetKeepTargetFunction(KeepTarget)
    inst:ListenForEvent("onattackother", onattackother)

    inst.TryAttack_Teleport_Do = TryAttack_Teleport_Do
    inst.TryAttack_Teleport_Evade = TryAttack_Teleport_Evade
    inst.TryAttack_Teleport_GetCloser = TryAttack_Teleport_GetCloser
    inst.TryAttack_Close = TryAttack_Close
    inst.DoAttack_Mid = DoAttack_Mid
    inst.TryAttack_Mid = TryAttack_Mid
    inst.DoAttack_Far = DoAttack_Far
    inst.TryAttack_Far = TryAttack_Far

    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.GESTALT_EVOLVED_HEALTH)

    inst:AddComponent("inspectable")

    local locomotor = inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    locomotor.walkspeed = TUNING.GESTALTGUARD_WALK_SPEED
    locomotor.runspeed = TUNING.GESTALTGUARD_WALK_SPEED
    locomotor:EnableGroundSpeedMultiplier(false)
    locomotor:SetTriggersCreep(false)
    locomotor.pathcaps = { ignorecreep = true }

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("gestalt_guard_evolved")
    inst.SetupDespawnPetLoot = SetupDespawnPetLoot
    inst.SetupKilledPetLoot = SetupKilledPetLoot

    inst:AddComponent("planarentity")
    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.GESTALT_EVOLVED_CLOSE_PLANAR_DAMAGE)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = TUNING.SANITYAURA_MED

    local follower = inst:AddComponent("follower") -- For petleash ownership.
    follower.keepdeadleader = true
    follower:KeepLeaderOnAttacked()
    follower.keepleaderduringminigame = true
    follower.neverexpire = true

    inst:SetStateGraph("SGgestalt_guard_evolved")
    inst:SetBrain(brain)

    inst:ListenForEvent("attacked", OnAttacked)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

--------------------

local function onmiss(inst, owner, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("mining_moonglass_fx")
    fx.Transform:SetPosition(x, y, z)
    inst:Remove()
end

local function onhit(inst, attacker, target)
    if target.components.combat then
        local impactfx = SpawnPrefab("impact")
        local follower = impactfx.entity:AddFollower()
        follower:FollowSymbol(target.GUID, target.components.combat.hiteffectsymbol, 0, 0, 0)
        if attacker ~= nil and attacker:IsValid() then
            impactfx:FacePoint(attacker.Transform:GetWorldPosition())
        end
    end
    inst:Remove()
end

local function onthrown(inst)
    if inst._shouldbethrown_task then
        inst._shouldbethrown_task:Cancel()
        inst._shouldbethrown_task = nil
    end
end

local function fn_projectile() -- Intended to be created and thrown on the same frame.
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()

    MakeProjectilePhysics(inst)
    inst.DynamicShadow:SetSize(1.25, 1.25)

    inst.AnimState:SetBank("brightmare_gestalt_evolved")
    inst.AnimState:SetBuild("brightmare_gestalt_evolved")
    inst.AnimState:PlayAnimation("shard")

    inst:AddTag("sharp")
    inst:AddTag("NOCLICK")

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst._shouldbethrown_task = inst:DoTaskInTime(0, inst.Remove)

    local weapon = inst:AddComponent("weapon")
    weapon:SetDamage(TUNING.GESTALT_EVOLVED_FAR_DAMAGE)

    local planardamage = inst:AddComponent("planardamage")
    planardamage:SetBaseDamage(TUNING.GESTALT_EVOLVED_FAR_PLANAR_DAMAGE)

    local projectile = inst:AddComponent("projectile")
    projectile:SetRange(TUNING.GESTALT_EVOLVED_FAR_RANGE)
    projectile:SetSpeed(TUNING.GESTALT_EVOLVED_FAR_SPEED)
    projectile:SetHoming(false)
    projectile:SetHitDist(0.1)
    projectile:SetLaunchOffset(Vector3(0, 0.5, 0))
    projectile:SetOnHitFn(onhit)
    projectile:SetOnThrownFn(onthrown)
    projectile:SetOnMissFn(onmiss)

    return inst
end

return Prefab("gestalt_guard_evolved", fn, assets, prefabs),
    Prefab("gestalt_guard_projectile", fn_projectile, assets, prefabs_projectile)
