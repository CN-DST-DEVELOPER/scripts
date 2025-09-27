require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/brightmare_gestalt_evolved.zip"),
}

local prefabs =
{
	"gestalt_head",
	"gestalt_guard_head",
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

local function SetHeadAlpha(inst, a)
	if inst.blobhead then
		inst.blobhead.AnimState:OverrideMultColour(1, 1, 1, a)
	end
end

local function FindRelocatePoint(inst)
	-- if dist from home point is too far, then use home point
	local pt
	local home_pt = inst.components.knownlocations:GetLocation("spawnpoint")
	if home_pt ~= nil then
        pt = inst:GetPosition()
        if distsq(pt.x, pt.z, home_pt.x, home_pt.z) >= TUNING.GESTALT_EVOLVED_MAX_DISTSQ_RELOCATE then
		    pt = home_pt
        end
	end
    pt = pt or inst:GetPosition()

    local theta = math.random() * TWOPI
	local offset = FindWalkableOffset(pt, theta, 2+math.random()*1, 16, true, true)

	return offset ~= nil and (offset + pt) or pt
end

local function do_sleep_despawn(inst)
	inst:PushEvent("sleep_despawn")
	inst:Remove()
end
local function OnEntitySleep(inst)
	inst._sleep_despawn_task = inst:DoTaskInTime(10, do_sleep_despawn)
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
    if target.components.sanity == nil then
        --not player; could be bernie or other creature
        return true
    elseif target.components.sanity:IsEnlightened() then
        inst._deaggrotime = nil
        return true
    end

    -- Start a deaggro timer when the target becomes unenlightened
    local t = GetTime()
    if inst._deaggrotime == nil then
        inst._deaggrotime = t
        return true
    end

    --Deaggro if target has been unenlightened for 2.5s, hasn't hit us in 6s, and hasn't tried to attack us for 5s
	if inst._deaggrotime + 2.5 >= t or
    inst.components.combat.lastwasattackedbytargettime + 16 >= t or
    (	target.components.combat and
        target.components.combat:IsRecentTarget(inst) and
        (target.components.combat.laststartattacktime or 0) + 15 >= t
    )
    then
        return true
    end

    return false
end

local function Retarget(inst)
	if inst.tracking_target then
		if inst.components.combat:InCooldown()
				or not inst:IsNear(inst.tracking_target, TUNING.GESTALTGUARD_AGGRESSIVE_RANGE)
				or inst.tracking_target.sg:HasAnyStateTag(SLEEPING_TAGS) then
			return nil
		end

		-- If our potential target has a gestalt item, don't target them.
		local target_inventory = inst.tracking_target.components.inventory
		if target_inventory ~= nil and target_inventory:EquipHasTag("gestaltprotection") then
            return nil
		end

		return inst.tracking_target
	else
		local targets_level = 1
		local function attacktargetcheck(target)
			if (target.components.inventory == nil or not target.components.inventory:EquipHasTag("gestaltprotection")) then
				targets_level = GetLevelForTarget(target)
				return targets_level == 3
			else
				return false
			end
		end

		local target = FindEntity(inst, TUNING.GESTALTGUARD_AGGRESSIVE_RANGE, attacktargetcheck, nil, attack_cant_tags, attack_any_tags)

		if target == inst.components.combat.target then
			inst.behaviour_level = (target ~= nil and targets_level) or 1
		end

		return target, target ~= inst.components.combat.target
	end
end

local function OnNewCombatTarget(inst, data)
	inst.behaviour_level = GetLevelForTarget(data.target)
end

local function OnNoCombatTarget(inst)
	inst.components.combat:RestartCooldown()
	inst.behaviour_level = 0
end

local function onattackother(inst, data)
	local target = data ~= nil and data.target or nil

	local burnable = target:IsValid() and target.components.burnable or nil
    if burnable ~= nil and burnable:IsBurning() and target:HasTag("shadow_fire") then
        burnable:Extinguish()
    end
end

local function ShareTargetFn(dude)
    return dude:HasTag("brightmare_guard") and dude.components.health and not dude.components.health:IsDead()
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    inst.components.combat:ShareTarget(data.attacker, 30, ShareTargetFn, 1)

    if inst._deaggrotime ~= nil then
        inst._deaggrotime = GetTime()
        return true
    end

end

-- World component target tracking
local function SetTrackingTarget(inst, target, behaviour_level)
	local prev_target = inst.tracking_target
	inst.tracking_target = target
	inst.behaviour_level = behaviour_level
	if prev_target ~= inst.tracking_target then
		if inst.OnTrackingTargetRemoved ~= nil then
			inst:RemoveEventCallback("onremove", inst.OnTrackingTargetRemoved, prev_target)
			inst:RemoveEventCallback("death", inst.OnTrackingTargetRemoved, prev_target)
			inst.OnTrackingTargetRemoved = nil
		end
		if inst.tracking_target ~= nil then
			inst.OnTrackingTargetRemoved = function(_) inst.tracking_target = nil end
			inst:ListenForEvent("onremove", inst.OnTrackingTargetRemoved, inst.tracking_target)
			inst:ListenForEvent("death", inst.OnTrackingTargetRemoved, inst.tracking_target)
		end
	end
end

--
local function fn()
    local inst = CreateEntity()

    --Core components
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    --Initialize physics
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
		inst.blobhead.Follower:FollowSymbol(inst.GUID, "head_fx_big", 0, 0, 0)

		inst.blobhead.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.blobhead.persists = false

	    inst.highlightchildren = { inst.blobhead }

		-- this is purely view related
		local transparentonsanity = inst:AddComponent("transparentonsanity")
		transparentonsanity.most_alpha = .4
		transparentonsanity.osc_amp = .05
		transparentonsanity.osc_speed = 5.25 + math.random() * 0.5
		transparentonsanity.calc_percent_fn = Client_CalcTransparencyRating
		transparentonsanity.onalphachangedfn = SetHeadAlpha
		transparentonsanity:ForceUpdate()
	end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	--inst.scrapbook_inspectonseen = true --Can already be killed and inspected normally no need.
	inst.scrapbook_overridedata = {"head_fx_big", "brightmare_gestalt_head_evolved", "head_fx_big"}

    --
	inst.persists = false
	inst._notrail = true
	inst.FindRelocatePoint = FindRelocatePoint
	inst.OnEntitySleep = OnEntitySleep
	inst.OnEntityWake = OnEntityWake

    --
	local combat = inst:AddComponent("combat")
	combat:SetDefaultDamage(TUNING.GESTALT_EVOLVED_REAL_DAMAGE)
	combat:SetRange(TUNING.GESTALTGUARD_ATTACK_RANGE)
	combat:SetAttackPeriod(4)
    combat:SetRetargetFunction(1, Retarget)
    combat:SetKeepTargetFunction(KeepTarget)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnNoCombatTarget)
	inst:ListenForEvent("losttarget", OnNoCombatTarget)
	inst:ListenForEvent("onattackother", onattackother)

    --
	local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.GESTALT_EVOLVED_HEALTH)

	--
	inst:AddComponent("inspectable")

    --
	inst:AddComponent("knownlocations")

    --
    local locomotor = inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    locomotor.walkspeed = TUNING.GESTALTGUARD_WALK_SPEED
    locomotor.runspeed = TUNING.GESTALTGUARD_WALK_SPEED
    locomotor:EnableGroundSpeedMultiplier(false)
    locomotor:SetTriggersCreep(false)
    locomotor.pathcaps = { ignorecreep = true }

	--
	inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("gestalt_guard_evolved")

	--
	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.GESTALT_EVOLVED_PLANAR_DAMAGE)

    --
    inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = TUNING.SANITYAURA_MED

	--
	inst.SetTrackingTarget = SetTrackingTarget

	--
    inst:SetStateGraph("SGgestalt_guard_evolved")
    inst:SetBrain(brain)

	--
	inst:ListenForEvent("attacked", OnAttacked)

    return inst
end

return Prefab("gestalt_guard_evolved", fn, assets, prefabs)
