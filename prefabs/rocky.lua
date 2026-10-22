local assets =
{
    Asset("ANIM", "anim/rocky.zip"),
    Asset("ANIM", "anim/rocky_acid_build.zip"),
    Asset("SOUND", "sound/rocklobster.fsb"),
}

local prefabs =
{
    "rocks",
    "meat",
    "flint",
    "rockycorpse",
}

local brain = require "brains/rockybrain"

local colours =
{
    { 1, 1, 1, 1 },
    --{ 174/255, 158/255, 151/255, 1 },
    { 167/255, 180/255, 180/255, 1 },
    { 159/255, 163/255, 146/255, 1 },
}

local SHADOW_SIZE = { 2, 1.5 }
local GROWTH_PERIOD = 60
local MASS = 200
local RADIUS = 0.65
local BOULDER_RADIUS = 1.2

local loot = { "rocks", "rocks", "meat", "flint", "flint" }
local nitreloot = { "nitre", "nitre", "rocks", "rocks", "meat", "flint", "flint" }

-- StandardSleepChecks instead of DefaultSleepTest so we can skip phase checks
local function ShouldSleep(inst)
    return StandardSleepChecks(inst) and inst.components.sleeper:GetTimeAwake() > (TUNING.TOTAL_DAY_TIME * 2)
end

local function ShouldWake(inst)
    return StandardWakeChecks(inst) and inst.components.sleeper:GetTimeAsleep() > (TUNING.TOTAL_DAY_TIME * .5)
end

local PARASITE_SHARE_TAGS = { "_combat", "shadowthrall_parasite_hosted" }
local ROCKY_SHARE_TAGS = { "_combat", "rocky" }
local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)

    if inst:HasTag("shadowthrall_parasite_hosted") then
		inst.components.combat:ShareTarget(data.attacker, 20, nil, 10, PARASITE_SHARE_TAGS)
    else
		inst.components.combat:ShareTarget(data.attacker, 20, nil, 2, ROCKY_SHARE_TAGS)
    end
end

local function grow(inst, dt)
    if inst.components.scaler.scale < TUNING.ROCKY_MAX_SCALE then
        local new_scale = math.min(
            inst.components.scaler.scale + TUNING.ROCKY_GROW_RATE * dt,
            TUNING.ROCKY_MAX_SCALE
        )
        inst.components.scaler:SetScale(new_scale)

        return true
    else
        return false
    end
end

--dt is nil from task, not nil from OnLongUpdate
local function on_size_update(inst, dt)
	if inst.sizeupdatetask then
		local taskdt = inst.sizeupdatetask.taskdt
		local steps = 1
		local remaining
		if dt then --dt is passed for LongUpdate
			remaining = GetTaskRemaining(inst.sizeupdatetask)
			if remaining > dt then
				remaining = remaining - dt
				steps = 0
			else
				remaining = dt - remaining
				steps = math.floor(remaining / taskdt)
				remaining = remaining - steps * taskdt
				steps = steps + 1
			end
		end

		if inst.components.rainimmunity == nil and TheWorld.state.isacidraining then
			if inst.components.scaler.scale > TUNING.ROCKY_MIN_SCALE then
				local new_scale = math.max(
					inst.components.scaler.scale - TUNING.ROCKY_ACIDRAIN_SHRINK_RATE * steps * taskdt,
					TUNING.ROCKY_MIN_SCALE
				)
				inst.components.scaler:SetScale(new_scale)
			else
				inst.sizeupdatetask:Cancel()
				inst.sizeupdatetask = nil
				return
			end
		elseif not grow(inst, steps * GROWTH_PERIOD) then
			inst.sizeupdatetask:Cancel()
			inst.sizeupdatetask = nil
			return
		end

		if remaining then --for LongUpdate, reset task to remaining time
			inst.sizeupdatetask:Cancel()
			inst.sizeupdatetask = inst:DoPeriodicTask(taskdt, on_size_update, remaining)
			inst.sizeupdatetask.taskdt = taskdt
		end
	end
end

local function applyscale(inst, scale)
    inst.components.combat:SetDefaultDamage(TUNING.ROCKY_DAMAGE * scale)
	inst.components.combat:SetRange(TUNING.ROCKY_ATTACK_RANGE * scale, TUNING.ROCKY_HIT_RANGE * scale)

    local percent = inst.components.health:GetPercent()
    inst.components.health:SetMaxHealth(TUNING.ROCKY_HEALTH * scale)
    inst.components.health:SetPercent(percent)

	inst.DynamicShadow:SetSize(SHADOW_SIZE[1] * scale, SHADOW_SIZE[2] * scale)

	inst.Physics:SetCapsule((inst.isboulder and BOULDER_RADIUS or RADIUS) * scale, 1)
end

local function OnGrowthStateDirty(inst)
    if not inst.sizeupdatetask then
        -- If acid rain starts or stops, queue up a check for whether
        -- we should start growing or shrinking again.
		local dt = GROWTH_PERIOD + math.random() * 10
		inst.sizeupdatetask = inst:DoPeriodicTask(dt, on_size_update)
		inst.sizeupdatetask.taskdt = dt
    end
end

local function OnInfuse(inst)
    OnGrowthStateDirty(inst)
end

local function OnUninfuse(inst)
    OnGrowthStateDirty(inst)
end

local function SetNitre(inst)
    inst.AnimState:SetBuild("rocky_acid_build")
    inst.components.lootdropper:SetLoot(nitreloot)
end

local function ClearNitre(inst)
    inst.AnimState:SetBuild("rocky")
    inst.components.lootdropper:SetLoot(loot)
end

local function OnAcidLevelDelta(inst, data)
    if not data then
        return
    end

    local oldacidic, newacidic = data.oldpercent, data.newpercent
    if newacidic > oldacidic then
        -- Grow nitre.
        if newacidic >= TUNING.ROCKY_ACIDRAIN_NITRE_STARTS_PERCENT then
            if not inst.nitregrowth then
                inst.nitregrowth = true
                inst.components.acidlevel:SetPercent(1) -- Make the extreme pop so when it flips state it has time to go backwards.
                SetNitre(inst)
            end
        end
    elseif newacidic < oldacidic then
        -- Dissolve nitre.
        if newacidic < TUNING.ROCKY_ACIDRAIN_NITRE_STARTS_PERCENT then
            if newacidic == 0 then
                if inst.nitregrowth then
                    inst.nitregrowth = nil
                    inst.components.acidlevel:SetPercent(0) -- Make the extreme pop so when it flips state it has time to go backwards.
                    ClearNitre(inst)
                end
            end
        end
    --else
        -- No change.
    end
end

local function OnStopIsAcidRaining(inst)
    if not inst.nitregrowth then -- Stop bubbling when idle even if slightly acidic.
        ClearNitre(inst)
    end
end

local function OnOverrideAcidRainTick(inst)
    return 0 -- no damage
end

local function ShouldAcceptItem(inst, item)
    return item.components.edible ~= nil and item.components.edible.foodtype == FOODTYPE.ELEMENTAL
end

local function OnGetItemFromPlayer(inst, giver, item)
    if item.components.edible ~= nil and
            item.components.edible.foodtype == FOODTYPE.ELEMENTAL and
            item.components.inventoryitem ~= nil and
            (   --make sure it didn't drop due to pockets full
                item.components.inventoryitem:GetGrandOwner() == inst or
                --could be merged into a stack
                (   not item:IsValid() and
                    inst.components.inventory:FindItem(function(obj)
                        return obj.prefab == item.prefab
                            and obj.components.stackable ~= nil
                            and obj.components.stackable:IsStack()
                    end) ~= nil)
            ) then
        if inst.components.combat:TargetIs(giver) then
            inst.components.combat:SetTarget(nil)
        elseif giver.components.leader ~= nil then
			if not giver.components.minigame_participator then
	            giver:PushEvent("makefriend")
		        giver.components.leader:AddFollower(inst)
			end
            inst.components.follower:AddLoyaltyTime(
                (giver:HasTag("polite")
                and TUNING.ROCKY_LOYALTY + TUNING.ROCKY_POLITENESS_LOYALTY_BONUS)
                or TUNING.ROCKY_LOYALTY
            )
            inst.sg:GoToState("rocklick")
        end
    end

    if inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end
end

local function OnRefuseItem(inst, item)
    if inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end
    inst:PushEvent("refuseitem")
end

local function onsave(inst, data)
    data.colour = inst.colour_idx
end

local function onload(inst, data)
    if not data then return end

    if data.colour ~= nil then
        local colour = colours[data.colour]
        if colour ~= nil then
            inst.colour_idx = data.colour
            inst.AnimState:SetMultColour(unpack(colour))
        end
    end
end

local function CustomOnHaunt(inst, haunter)
    if math.random() <= TUNING.HAUNT_CHANCE_OCCASIONAL then
		grow(inst, GROWTH_PERIOD)
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_MEDIUM
        if inst.sizeupdatetask then
            inst.sizeupdatetask:Cancel()
            inst.sizeupdatetask = nil
            OnGrowthStateDirty(inst)
        end
        return true
    else
        return false
    end
end

local function OnWork(inst, worker, workleft, numworks)
	if numworks > 0 and worker and
		worker.components.combat and
		not worker.components.explosive --explosives will do work + combat already
	then
		--convert work to attack damage; guard against double depletion on tool.

		local tool = worker.components.inventory and worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		local efficientuser
		if tool then
			efficientuser = worker.components.efficientuser
			if efficientuser == nil then
				worker:AddComponent("efficientuser")
			end
			worker.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, 0, inst, "rockyshieldmining")
		end

		inst.components.health:SetAbsorptionAmount(0)
		worker.components.combat:DoAttack(inst, tool)
		if inst.isboulder then
			inst.components.health:SetAbsorptionAmount(TUNING.ROCKY_ABSORB)
		end
		if inst.sg.currentstate.name == "shield" then
			inst.components.health:StartRegen(TUNING.ROCKY_REGEN_AMOUNT, TUNING.ROCKY_REGEN_PERIOD, true)
		end

		if tool then
			if efficientuser then
				efficientuser:RemoveMultiplier(ACTIONS.ATTACK, inst, "rockyshieldmining")
			else
				worker:RemoveComponent("efficientuser")
			end
		end
	end
end

local function OnWorkFinished(inst, worker)
	inst:PushEventImmediate("breakshield")
    if inst.nitregrowth then
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.lootdropper:SpawnLootPrefab("nitre")
        inst.components.acidlevel:SetPercent(0)
    end
end

local function SetBoulderState(inst, enable)
	if enable then
		if not inst.isboulder then
            inst:AddTag("nogelblob")
			inst.isboulder = true

            inst.components.trader:Disable()
			inst.components.health:SetAbsorptionAmount(TUNING.ROCKY_ABSORB)

			inst:AddComponent("workable")
			inst.components.workable:SetWorkAction(ACTIONS.MINE)
			inst.components.workable:SetWorkLeft(4)
			inst.components.workable:SetOnWorkCallback(OnWork)
			inst.components.workable:SetOnFinishCallback(OnWorkFinished)

			inst.Physics:SetMass(0)
			inst.Physics:SetCollisionMask(
				COLLISION.CHARACTERS,
				COLLISION.GIANTS
			)
			inst.Physics:SetCapsule(BOULDER_RADIUS * inst.components.scaler.scale, 1)
		end
	elseif inst.isboulder then
        inst:RemoveTag("nogelblob")
		inst.isboulder = false

        inst.components.trader:Enable()
		inst.components.health:SetAbsorptionAmount(0)

		inst:RemoveComponent("workable")

		inst.Physics:SetMass(MASS)
		inst.Physics:SetCollisionMask(
			COLLISION.WORLD,
			COLLISION.OBSTACLES,
			COLLISION.SMALLOBSTACLES,
			COLLISION.CHARACTERS,
			COLLISION.GIANTS
		)
		inst.Physics:SetCapsule(RADIUS * inst.components.scaler.scale, 1)
	end
end

local KEEP_TARGET_FIGHTING_BOSS_TIME = 6
local function IsTargetFightingBoss(inst)
    local target = inst.components.combat.target
    if target and target.components.combat then
        local targettarget = target.components.combat.target
        if targettarget then
            return targettarget.prefab == "rocky_boss"
        else
            local lasttargetguid = target.components.combat.lasttargetGUID
            local targetlasttarget = lasttargetguid and Ents[lasttargetguid]
            if targetlasttarget and targetlasttarget.prefab == "rocky_boss" and not IsEntityDead(targetlasttarget) then
                if GetTime() - (target.components.combat.laststartattacktime or 0) < KEEP_TARGET_FIGHTING_BOSS_TIME then
                    return true
                else
					local theirtarget = targetlasttarget.components.combat and targetlasttarget.components.combat.target
                    if theirtarget == target then
						return true
					end
                end
            end
        end
    end
end

local function IsMaxSize(inst)
    return inst.components.scaler.scale >= TUNING.ROCKY_MAX_SCALE
end

local function GetStatus(inst)--, viewer)
    return (inst.components.workable ~= nil and "BOULDER") or
        (inst.nitregrowth and "ACID") or
        nil
end

local function OnNewCombatTarget(inst, data)
    inst.components.timer:PauseTimer("bouldercd")
end

local function OnDroppedTarget(inst)
    if not inst:IsAsleep() then
        inst.components.timer:ResumeTimer("bouldercd")
        inst.components.timer:SetTimeLeft(math.max(10 + math.random() * 10, inst.components.timer:GetTimeLeft("bouldercd") or 0))
    end
end

local function OnEntityWake(inst)
    inst.components.timer:ResumeTimer("bouldercd")
end

local function OnEntitySleep(inst)
    inst.components.timer:PauseTimer("bouldercd")
end

local function DisplayNameFn(inst)
	return inst:HasTag("MINE_workable") and STRINGS.NAMES.ROCKY_BOULDER or nil
end

local EATER_FOODTYPES = { FOODTYPE.ELEMENTAL }
local PATHCAPS = { ignorecreep = false }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

	MakeCharacterPhysics(inst, MASS, RADIUS)

    inst.Transform:SetFourFaced()

	inst:AddTag("cavedweller")
    inst:AddTag("rocky")
    inst:AddTag("character")
    inst:AddTag("animal")
	inst:AddTag("electricdamageimmune")

    --trader (from trader component) added to pristine state for optimization
    inst:AddTag("trader")

    --herdmember (from herdmember component) added to pristine state for optimization
    inst:AddTag("herdmember")

    inst.AnimState:SetBank("rocky")
    inst.AnimState:SetBuild("rocky")
    inst.AnimState:PlayAnimation("idle_loop", true)

	inst.DynamicShadow:SetSize(unpack(SHADOW_SIZE))

    inst:AddComponent("spawnfader")

    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.colour_idx = math.random(#colours)
    inst.AnimState:SetMultColour(unpack(colours[inst.colour_idx]))

    --
    local acidinfusible = inst:AddComponent("acidinfusible")
    acidinfusible:SetFXLevel(3)
    acidinfusible:SetOnInfuseFn(OnInfuse)
    acidinfusible:SetOnUninfuseFn(OnUninfuse)

    --
    local combat = inst:AddComponent("combat")
    combat:SetAttackPeriod(3)
	combat:SetRange(TUNING.ROCKY_ATTACK_RANGE, TUNING.ROCKY_HIT_RANGE)
	combat:SetHitArc(TUNING.DEFAULT_HIT_ARC)
	combat:SetDefaultDamage(TUNING.ROCKY_DAMAGE)

    --
    local eater = inst:AddComponent("eater")
    eater:SetDiet(EATER_FOODTYPES, EATER_FOODTYPES)

    --
    local follower = inst:AddComponent("follower")
    follower.maxfollowtime = TUNING.PIG_LOYALTY_MAXTIME

    --
    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.ROCKY_HEALTH)

    --
    local herdmember = inst:AddComponent("herdmember")
    herdmember.herdprefab = "rockyherd"

    --
    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    --
    inst:AddComponent("inventory")

    --
    inst:AddComponent("knownlocations")

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor:SetSlowMultiplier( 1 )
    locomotor:SetTriggersCreep(false)
    locomotor.pathcaps = PATHCAPS
    locomotor.walkspeed = TUNING.ROCKY_WALK_SPEED
	locomotor.runspeed = TUNING.ROCKY_WALK_SPEED

    --
    local lootdropper = inst:AddComponent("lootdropper")
    lootdropper:SetLoot(loot)

    --
    local scaler = inst:AddComponent("scaler")
    scaler.OnApplyScale = applyscale

    --
    local sleeper = inst:AddComponent("sleeper")
    sleeper:SetResistance(3)
    sleeper:SetWakeTest(ShouldWake)
    sleeper:SetSleepTest(ShouldSleep)

    --
    local trader = inst:AddComponent("trader")
    trader:SetAcceptTest(ShouldAcceptItem)
    trader.onaccept = OnGetItemFromPlayer
    trader.onrefuse = OnRefuseItem
    trader.deleteitemonaccept = false

    local timer = inst:AddComponent("timer")
    if not POPULATING then
        timer:StartTimer("bouldercd", 15 + math.random() * 15)
    end

    local acidlevel = inst:AddComponent("acidlevel")
    inst:ListenForEvent("acidleveldelta", OnAcidLevelDelta)
    acidlevel:SetOnStopIsAcidRainingFn(OnStopIsAcidRaining)
	acidlevel:SetOnStopIsRainingFn(OnStopIsAcidRaining)
    acidlevel:SetOverrideAcidRainTickFn(OnOverrideAcidRainTick)
	inst:ListenForEvent("gainrainimmunity", OnStopIsAcidRaining)

    --
    MakeHauntablePanic(inst)
    AddHauntableCustomReaction(inst, CustomOnHaunt, true, false, true)

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    --
    inst:SetBrain(brain)
    inst:SetStateGraph("SGrocky")

    --
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("gainrainimmunity", OnGrowthStateDirty)
    inst:ListenForEvent("loserainimmunity", OnGrowthStateDirty)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)

    --
    OnGrowthStateDirty(inst)
    scaler:SetScale(TUNING.ROCKY_MIN_SCALE)

    --
    inst.OnLongUpdate = on_size_update
	inst.SetBoulderState = SetBoulderState
    inst.IsTargetFightingBoss = IsTargetFightingBoss
    inst.IsMaxSize = IsMaxSize

    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("rocky", fn, assets, prefabs)
