local assets =
{
	Asset("ANIM", "anim/bat_boss.zip"),
	Asset("ANIM", "anim/bat_boss_acid_build.zip"),
	Asset("ANIM", "anim/stalker_corrupt_fx_build.zip"),
	Asset("SOUND", "sound/bat.fsb"),
	Asset("INV_IMAGE", "bat_boss_acid"),
}

local assets_shadow =
{
	Asset("ANIM", "anim/bat_boss.zip"),
	Asset("ANIM", "anim/bat_boss_shadow_actions.zip"),
	Asset("ANIM", "anim/stalker_corrupt_fx_build.zip"),
	Asset("SOUND", "sound/bat.fsb"),
}

local assets_shadow_split_fx =
{
	Asset("ANIM", "anim/bat_boss_shadow_actions.zip"),
}

local prefabs =
{
	"bat",
	"bat_boss_shadow",
	"bat_bosscorpsehat",
	"bat_bosshat_fx",
	"monstermeat",
	"guano",
	"batwing",
	"splash",
}

local prefabs_shadow =
{
	"atrium_ritual_organ_bat",
	"horrorfuel",
	"nightmarefuel",
	"bat_bosshat_fx",
	"bat_boss_shadow_split_fx",
	"chesspiece_batboss_shadow_sketch",
}

local brain = require("brains/bat_bossbrain")

SetSharedLootTable("bat_boss",
{
	{ "bat_bosscorpsehat",	1.00 },
})

SetSharedLootTable("bat_boss_acidinfused",
{
	{ "bat_bosscorpsehat",	1.00 },
})

SetSharedLootTable("bat_boss_shadow",
{
	{ "atrium_ritual_organ_bat",	1.00 },
	{ "horrorfuel",					1.00 },
	{ "horrorfuel",					0.67 },
	{ "nightmarefuel",				1.00 },
	{ "nightmarefuel",				0.33 },
	{ "chesspiece_batboss_shadow_sketch",	1.00 },
})

local function ShouldSleep(inst) return false end
local function ShouldWake(inst) return true end

local MAX_TARGET_SHARES = 5
local SHARE_TARGET_DIST = 40

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "bat", "batdisguise" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }
local SHADOW_RETARGET_CANT_TAGS = { "INLIMBO", "bat", "shadowthrall", "shadowboss", "stalker" }
local CLONE_MAX_DIST = 12 --switches back to share target if separated this far

local function _cantargetfn(guy, inst)
	return inst.components.combat:CanTarget(guy)
end

local function RetargetFn(inst)
	if inst.components.equippable:IsEquipped() then
		return
	end
	return FindEntity(inst, TUNING.BAT_TARGET_DIST, _cantargetfn, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS)
end

local function shadow_RetargetFn(inst)
	if inst.components.equippable:IsEquipped() then
		return
	end
	local clone = inst.components.entitytracker:GetEntity("clone")
	if clone and not (inst.components.combat:HasTarget() and inst:IsNear(clone, CLONE_MAX_DIST)) then
		local target = clone.components.combat.target
		if target then
			return target, true
		end
	end
	return FindEntity(inst, TUNING.BAT_TARGET_DIST, _cantargetfn, RETARGET_MUST_TAGS, SHADOW_RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS)
end

local SHADOW_SHARE_TAGS = { "shadowthrall" }
local BAT_SHARE_TAGS = { "bat" }
local function ValidShareTarget(v, inst)
	return not v:IsInLimbo()
end
local function OnAttacked(inst, data)
	if data and data.attacker then
		local target = inst.components.combat.target
		if not (target and
				target:HasTag(data.attacker.isplayer and "player" or "character") and
				inst:IsNear(target, inst.components.combat.attackrange + target:GetPhysicsRadius(0)))
		then
			inst.components.combat:SetTarget(data.attacker)
		end

		if not inst:HasTag("shadowthrall") then
			inst.components.combat:ShareTarget(data.attacker, 20, ValidShareTarget, 4, BAT_SHARE_TAGS)
		end
	end
end

local EATER_FOODTYPES = { FOODTYPE.MEAT }
local EATER_FOODTYPES_ACID = { FOODTYPE.MEAT, FOODTYPE.NITRE }

local function OnAcidInfuse(inst)
    inst.AnimState:SetBuild("bat_boss_acid_build")
    inst.AnimState:SetSymbolLightOverride("bat_eye", .5)

    inst.components.lootdropper:SetChanceLootTable("bat_boss_acidinfused")

    inst.components.inventoryitem:ChangeImageName("bat_boss_acid")

	inst.components.combat:SetRetargetFunction(0.5, RetargetFn)

    inst.components.eater:SetDiet(EATER_FOODTYPES_ACID, EATER_FOODTYPES_ACID)
    inst.components.eater:ResetEdibleTagsCache()

    if inst.components.thief == nil then
        inst:AddComponent("thief")
    end
end

local function OnAcidUninfuse(inst)
    inst.AnimState:SetBuild("bat_boss")
    inst.AnimState:SetSymbolLightOverride("bat_eye", 0)

    inst.components.lootdropper:SetChanceLootTable("bat_boss")

    inst.components.inventoryitem:ChangeImageName()

    inst.components.combat:SetRetargetFunction(1.5, RetargetFn)

    inst.components.eater:SetDiet(EATER_FOODTYPES, EATER_FOODTYPES)
    inst.components.eater:ResetEdibleTagsCache()

    if inst.components.thief ~= nil then
        inst:RemoveComponent("thief")
    end
end

local function DoUnequip(inst, owner)
	if owner:IsValid() and owner.components.inventory and owner.components.inventory:IsItemEquipped(inst) then
		owner.components.inventory:DropItem(inst, true, true)
	end
	inst.unequiptask = nil
end

local function DoShadowRot(item)
	if item.components.perishable then
		item.components.perishable:ReducePercent(TUNING.BAT_BOSS_SHADOW_PERISH_PERCENT)
	end
end

local function DoChomp(inst, owner)
	if inst.fx then
		inst.fx:TriggerChompFx()
	end
	inst.components.combat:DoAttack(owner)
	if inst.components.acidinfusible then
		if inst.components.acidinfusible:IsInfused() and owner.components.acidlevel then
			owner.components.acidlevel:PerishInventoryTick(TUNING.BAT_BOSS_ACID_PERISH_INVENTORY_RATE)
		end
	elseif inst:HasTag("shadowthrall") then
		if owner.components.inventory then
			owner.components.inventory:ForEachWetableItem(DoShadowRot)
		end
	end
end

local function OnEquip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_hat")
	owner.AnimState:Show("HAT")
	owner.AnimState:Show("HAIR_HAT")
	owner.AnimState:Hide("HAIR_NOHAT")
	owner.AnimState:Hide("HAIR")

	if owner.isplayer then
		owner.AnimState:Hide("HEAD")
		owner.AnimState:Show("HEAD_HAT")
		owner.AnimState:Show("HEAD_HAT_NOHELM")
		owner.AnimState:Hide("HEAD_HAT_HELM")
	end

	if inst.fx then
		inst.fx:Remove()
	end
	inst.fx = SpawnPrefab("bat_bosshat_fx")
	if inst.components.acidinfusible and inst.components.acidinfusible:IsInfused() then
		inst.fx.AnimState:SetBuild("bat_boss_acid_build")
	elseif inst:HasTag("shadowthrall") then
		inst.fx.AnimState:SetBuild("bat_boss_shadow_actions")
	end
	inst.fx:AttachToOwner(owner)

	if inst.unequiptask then
		inst.unequiptask:Cancel()
		inst.unequiptask = nil
	end
	if owner.isplayer then
		if inst._onplayerdespawn == nil then
			inst._onplayerdespawn = function(owner)
				owner.components.inventory:DropItem(inst, true, true)
			end
		end
		inst:ListenForEvent("player_despawn", inst._onplayerdespawn, owner)
	elseif owner:HasTag("equipmentmodel") then
		inst.unequiptask = inst:DoTaskInTime(TUNING.BAT_BOSS_MANNEQUINTIME, DoUnequip, owner)
	else
		inst.unequiptask = inst:DoTaskInTime(GetRandomMinMax(unpack(TUNING.BAT_BOSS_NPCTIME)), DoUnequip, owner)
	end

	inst.components.combat.ignorehitrange = true
	inst.components.combat:SetDefaultDamage(TUNING.BAT_BOSS_CHOMP_DAMAGE)
	if inst.components.planardamage then
		inst.components.planardamage:SetBaseDamage(TUNING.BAT_BOSS_SHADOW_CHOMP_PLANAR_DAMAGE)
	end

	if inst.chomptask == nil then
		inst.chomptask = inst:DoPeriodicTask(0.6, DoChomp, nil, owner)
	end

	if inst._equip_t0 == nil then
		inst._equip_t0 = GetTime()
	end

	inst.sg.mem.chompfailcount = 0
end

local function OnUnequip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_hat")
	owner.AnimState:Hide("HAT")
	owner.AnimState:Hide("HAIR_HAT")
	owner.AnimState:Show("HAIR_NOHAT")
	owner.AnimState:Show("HAIR")

	if owner.isplayer then
		owner.AnimState:Show("HEAD")
		owner.AnimState:Hide("HEAD_HAT")
		owner.AnimState:Hide("HEAD_HAT_NOHELM")
		owner.AnimState:Hide("HEAD_HAT_HELM")
	end

	if inst.fx then
		inst.fx:Remove()
		inst.fx = nil
	end
	if inst.unequiptask then
		inst.unequiptask:Cancel()
		inst.unequiptask = nil
	end
	if inst._onplayerdespawn then
		inst:RemoveEventCallback("player_despawn", inst._onplayerdespawn, owner)
		inst._onplayerdespawn = nil
	end

	local x, _, z = owner.Transform:GetWorldPosition()
	inst.Physics:Teleport(x, 0, z)
	if owner.components.locomotor then
		inst.Transform:SetRotation(owner.Transform:GetRotation())
	end

	local elapsed = GetTime() - (inst._equip_t0 or 0)
	inst._equip_t0 = nil

	--set this b4 GoToState, since leaving chomp states will inc back to 0
	inst.sg.mem.chompfailcount = inst.sg:HasStateTag("chomp") and -1 or 0

	local cd = inst:HasTag("shadowthrall") and TUNING.BAT_BOSS_SHADOW_CHOMP_CD or TUNING.BAT_BOSS_CHOMP_CD
	if elapsed < TUNING.BAT_BOSS_FAST_UNEQUIP_TIME and inst:GetTimeAlive() > 0 and not (inst:HasTag("shadowthrall") or owner:HasTag("equipmentmodel")) then
		inst.sg:GoToState("stun_pre")
		cd = cd + TUNING.BAT_BOSS_STAGGER_TIME
	else
		inst.sg:GoToState("stun_pre", true)
	end

	local clone = inst.components.entitytracker and inst.components.entitytracker:GetEntity("clone")
	if clone and
		clone.components.combat:TargetIs(inst.components.combat.target) and
		not clone.components.equippable:IsEquipped()
	then
		local clonecd = cd * 0.667
		local remaining = clone.components.timer:GetTimeLeft("chompcd")
		if remaining == nil or remaining < clonecd then
			clone.components.timer:StopTimer("chompcd")
			clone.components.timer:StartTimer("chompcd", clonecd)
		end
		clone.sg.mem.chompfailcount = 0
		cd = cd * 1.333
	end
	inst.components.timer:StopTimer("chompcd")
	inst.components.timer:StartTimer("chompcd", cd)

	if inst.components.planardamage then
		inst.components.planardamage:SetBaseDamage(TUNING.BAT_BOSS_SHADOW_PLANAR_DAMAGE)
	end
	inst.components.combat:SetDefaultDamage(TUNING.BAT_BOSS_DAMAGE)
	inst.components.combat.ignorehitrange = false

	if inst.chomptask then
		inst.chomptask:Cancel()
		inst.chomptask = nil
	end
end

local function OnNewCombatTarget(inst, data)
	if inst._disengagetask then
		inst._disengagetask:Cancel()
		inst._disengagetask = nil
	elseif data and data.target and data.oldtarget == nil then
		local cd = (inst:HasTag("shadowthrall") and TUNING.BAT_BOSS_SHADOW_CHOMP_CD or TUNING.BAT_BOSS_CHOMP_CD) / 2
		local remaining = inst.components.timer:GetTimeLeft("chompcd")
		if remaining == nil or remaining < cd then
			inst.components.timer:StopTimer("chompcd")
			inst.components.timer:StartTimer("chompcd", cd)
		end
		inst.sg.mem.chompfailcount = 0
	end
end

local function Disengage(inst)
	inst._disengagetask = nil
end

local function OnDroppedTarget(inst)
	if inst._disengagetask == nil then
		inst._disengagetask = inst:DoTaskInTime(10, Disengage)
	end
end

local function OnHitOther(inst, data)
	if inst.components.health:IsDead() then -- can reach here if we died from redirect attack
		return
	end
	if data and data.target then
		local damage = data.damageresolved or data.damage
		if damage and damage > 0 and IsLifeDrainable(data.target) then
			inst.components.health:DoDelta(damage * TUNING.BAT_BOSS_DRAIN_MULT)
		end
	end
end

local function DropFromOwner(inst)
	local owner = inst.components.inventoryitem:GetGrandOwner()
	if owner and inst.components.equippable:IsEquipped() then
		owner.components.inventory:DropItem(inst)
	end
end

local function OnDeath(inst)
	DropFromOwner(inst)
	-- add rain immunity to uninfuse because acid build doesnt support unique death state
	--  (and even if it did, it'd look better to uninfuse here for when we transition to the hat on death)
	if inst.components.acidinfusible and inst.components.acidinfusible:IsInfused() then
		local rainimmunity = inst.components.rainimmunity or inst:AddComponent("rainimmunity")
		rainimmunity:AddSource(inst)
	end
end

local function CanJoinAcidBatWave(inst) -- for whether we're available to join a acid bat wave.
	if inst.components.health:IsDead() then
		return false
	end
	return inst:IsAsleep() or -- we can always join if we're asleep
		not (inst.components.combat:HasTarget() or
			inst.sg:HasAnyStateTag("sleeping", "frozen", "flight") or
			(inst:GetBufferedAction() ~= nil))
end

local BATCAVE_MUST_TAGS = { "batcave" }
local BAT_MUST_TAGS = { "bat" }
local BAT_CANT_TAGS = { "NOCLICK", "monsterhat"--[[don't count ourselves]] }
local function NumBatsToSpawn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local num_bats = TUNING.BAT_BOSS_BASE_NUM_SPAWN + TUNING.BAT_BOSS_NUM_SPAWN_PER_PLAYER * (#FindPlayersInRange(x, y, z, TUNING.BAT_BOSS_NEARBY_PLAYERS_DIST, true))

	local existing_num_bats = TheSim:CountEntities(x, y, z, TUNING.BAT_BOSS_SEE_BATS_DIST, BAT_MUST_TAGS, BAT_CANT_TAGS)
	for i, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.BAT_BOSS_SEE_BATS_DIST, BATCAVE_MUST_TAGS)) do
		if v.components.childspawner then
			num_bats = num_bats + v.components.childspawner.childreninside
		end
	end

    local num = math.min(existing_num_bats+num_bats/2, num_bats) -- only spawn half the hounds per howl
    num = RoundToNearest((math.log(num)/0.4)+1, 1) -- 0.4 is approx log(1.5)

    return num - existing_num_bats
end

local function CalcSanityAura(inst, observer)
    return inst.components.acidinfusible:IsInfused() and -TUNING.SANITYAURA_LARGE or -TUNING.SANITYAURA_MED
end

local function GetStatus(inst)--, viewer)
    return inst.components.acidinfusible:IsInfused() and "ACID"
        or nil
end

local function DoReturn(inst)
    local home = inst.components.homeseeker ~= nil and inst.components.homeseeker.home or nil
    if home ~= nil and home.components.childspawner ~= nil then
        home.components.childspawner:GoHome(inst)
    end
end

local function OnEntityWake(inst)
	if inst.go_home_task then
		inst.go_home_task:Cancel()
		inst.go_home_task = nil
	end
end

local function OnEntitySleep(inst)
	if TheWorld.components.acidbatwavemanager and TheWorld.components.acidbatwavemanager:IsTrackedAcidBat(inst) then
		local home = inst.components.homeseeker and inst.components.homeseeker.home
		if home  then
			if home:GetDistanceSqToInst(inst) > 30 * 30 then
				inst.go_home_task = inst:DoTaskInTime(10, DoReturn)
			else
				TheWorld.components.acidbatwavemanager.StopTrackingFn(inst)
			end
		end
	end
end

local PATHCAPS = { allowocean = true }

local function commonfn(build, common_postinit, master_postinit)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	inst:SetPhysicsRadiusOverride(0.7)
	MakeGhostPhysics(inst, 10, inst.physicsradiusoverride)

	inst.DynamicShadow:SetSize(2.4, 1.4) --keep in sync with SGbat.lua::ConfigSleepLanded

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("bat_boss")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("fly_loop", true)

	inst:AddTag("cavedweller")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("bat")
	inst:AddTag("scarytoprey")
	inst:AddTag("flying")
	inst:AddTag("ignorewalkableplatformdrowning")
	inst:AddTag("mufflehat")
	inst:AddTag("monsterhat")

	MakeInventoryFloatable(inst, "med")

	if common_postinit then
		common_postinit(inst)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_facing = FACING_DOWNRIGHT

	inst:AddComponent("locomotor")
	inst.components.locomotor:EnableGroundSpeedMultiplier(false)
	inst.components.locomotor:SetTriggersCreep(false)
	inst.components.locomotor.pathcaps = PATHCAPS
	inst.components.locomotor.walkspeed = TUNING.BAT_BOSS_WALK_SPEED
	inst.components.locomotor.runspeed = TUNING.BAT_BOSS_WALK_SPEED

	inst:AddComponent("combat")
	inst.components.combat.hiteffectsymbol = "bat_body"
	inst.components.combat:SetDefaultDamage(TUNING.BAT_BOSS_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.BAT_BOSS_ATTACK_PERIOD)
	inst.components.combat:SetRange(TUNING.BAT_BOSS_ATTACK_DIST, TUNING.BAT_BOSS_HIT_DIST)
	inst.components.combat:SetHitArc(TUNING.DEFAULT_HIT_ARC)

    inst:AddComponent("sanityaura")

	inst:AddComponent("timer")

	inst:AddComponent("health")
	inst.components.health.canmurder = false

	inst:AddComponent("lootdropper")

	inst:AddComponent("inspectable")

	inst:AddComponent("knownlocations")

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.canbepickedup = false
	inst.components.inventoryitem.cangoincontainer = false
	inst.components.inventoryitem.nobounce = true
	inst.components.inventoryitem.pushlandedevents = false

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnequip)
	inst.components.equippable.dapperness = -TUNING.SANITYAURA_MED -- sanityaura isn't enabled when boss is equipped

	inst:SetStateGraph("SGbat")
	inst.sg.mem.nocorpse = true -- we drop ourself as the corpse!

	inst:SetBrain(brain)

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
	inst:ListenForEvent("droppedtarget", OnDroppedTarget)

	if master_postinit then
		master_postinit(inst)
	end

	return inst
end

--------------------------------------------------------------------------

local function normal_common_postinit(inst)
    inst:AddTag("nightmarecorruptable")
end

local function normal_master_postinit(inst)
	inst:AddComponent("acidinfusible")
	inst.components.acidinfusible:SetFXLevel(3)
	inst.components.acidinfusible:SetDamageMultiplier(TUNING.ACIDRAIN_BAT_DAMAGE_MULT)
	inst.components.acidinfusible:SetSpeedMultiplier(TUNING.ACIDRAIN_BAT_SPEED_MULT)
	inst.components.acidinfusible:SetOnInfuseFn(OnAcidInfuse)
	inst.components.acidinfusible:SetOnUninfuseFn(OnAcidUninfuse)

	inst:AddComponent("eater")
	inst.components.eater:SetDiet(EATER_FOODTYPES, EATER_FOODTYPES)
	inst.components.eater:SetStrongStomach(true)

	inst:AddComponent("sleeper")
	inst.components.sleeper:SetResistance(4)
	inst.components.sleeper:SetWakeTest(ShouldWake)
	inst.components.sleeper:SetSleepTest(ShouldSleep)
	inst.components.sleeper.diminishingreturns = true

	inst.components.health:SetMaxHealth(TUNING.BAT_BOSS_HEALTH)
    inst.components.health.nofadeout = true

	inst.components.lootdropper:SetChanceLootTable("bat_boss")
	inst.components.lootdropper.nofling = true

	inst.components.combat:SetRetargetFunction(1.5, RetargetFn)
	--no KeepTargetFn, deaggro handled by ChaseAndAttack params

	inst:AddComponent("periodicspawner")
	inst.components.periodicspawner:SetPrefab("guano")
	inst.components.periodicspawner:SetRandomTimes(120, 240)
	inst.components.periodicspawner:SetDensityInRange(30, 2)
	inst.components.periodicspawner:SetMinimumSpacing(8)
	inst.components.periodicspawner:Start()

	inst.components.inspectable.getstatus = GetStatus

	inst.components.sanityaura.aurafn = CalcSanityAura

	inst.sg.mem.canstalkercorrupt = true

	MakeMediumBurnableCharacter(inst, "bat_body")
	MakeMediumFreezableCharacter(inst, "bat_body")
	MakeHauntable(inst)

	inst:ListenForEvent("onhitother", OnHitOther)
	inst:ListenForEvent("startelectrocute", DropFromOwner)
	inst:ListenForEvent("death", OnDeath)

	inst.NumBatsToSpawn = NumBatsToSpawn
	inst.CanJoinAcidBatWave = CanJoinAcidBatWave
	inst.OnEntityWake = OnEntityWake
	inst.OnEntitySleep = OnEntitySleep
end

local function normalfn() return commonfn("bat_boss", normal_common_postinit, normal_master_postinit) end

--------------------------------------------------------------------------

local function CreateFlameLoop()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("bat_boss")
	inst.AnimState:SetBuild("bat_boss_shadow_actions")
	inst.AnimState:PlayAnimation("brow_flame_loop", true)
	inst.AnimState:SetSymbolLightOverride("red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)

	return inst
end

local function shadow_OnColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function shadow_common_postinit(inst)
	inst:AddTag("shadowthrall")
	inst:AddTag("shadow_aligned")
	inst:AddTag("epic")

	inst.AnimState:SetSymbolLightOverride("red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_red", 1)
	inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)

	inst:AddComponent("colouraddersync")

	if not TheNet:IsDedicated() then
		local flame = CreateFlameLoop()
		flame.entity:SetParent(inst.entity)
		flame.Follower:FollowSymbol(inst.GUID, "follow_brow_L")
		local len = flame.AnimState:GetCurrentAnimationNumFrames()
		flame.AnimState:SetFrame(math.random(math.floor(len / 4)))

		inst.highlightchildren = { flame }

		flame = CreateFlameLoop()
		flame.entity:SetParent(inst.entity)
		flame.Follower:FollowSymbol(inst.GUID, "follow_brow_R")
		len = flame.AnimState:GetCurrentAnimationNumFrames()
		flame.AnimState:SetFrame(math.floor(len / 2) + math.random(math.floor(len / 4)))

		inst.highlightchildren[2] = flame

		inst.components.colouraddersync:SetColourChangedFn(shadow_OnColourChanged)
	end
end

local function shadow_LootSetupFn(lootdropper)
	local inst = lootdropper.inst
	if inst.cloneloot then
		lootdropper:SetChanceLootTable(nil)
		lootdropper:AddRandomLoot("horrorfuel", 2)
		lootdropper:AddRandomLoot("nightmarefuel", 1)
		lootdropper.numrandomloot = 1
	else
		lootdropper:ClearRandomLoot()
		lootdropper:SetChanceLootTable("bat_boss_shadow")
	end
end

local function shadow_WatchCloneDeath(inst, clone)
	inst.cloneloot = true

	if inst._onclonedeath == nil then
		inst._onclonedeath = function(_clone)
			inst:RemoveEventCallback("death", inst._onclonedeath, _clone)
			inst:RemoveEventCallback("onremove", inst._onclonedeath, _clone)
			_clone:RemoveEventCallback("death", _clone._onclonedeath, inst)
			_clone:RemoveEventCallback("onremove", _clone._onclonedeath, inst)

			local old = inst.components.entitytracker:GetEntity("clone")
			if old == nil then
				inst.cloneloot = nil
			elseif old == _clone then
				inst.components.entitytracker:ForgetEntity("clone")
				inst.cloneloot = nil
			end
		end
	end
	inst:ListenForEvent("death", inst._onclonedeath, clone)
	inst:ListenForEvent("onremove", inst._onclonedeath, clone)
end

local function shadow_StartTrackingClone(inst, clone)
	inst.components.entitytracker:TrackEntity("clone", clone)
	shadow_WatchCloneDeath(inst, clone)
end

local function shadow_OnLoadPostPass(inst)--, ents, data)
	local clone = inst.components.entitytracker:GetEntity("clone")
	if clone then
		shadow_WatchCloneDeath(inst, clone)
	end
end

local function shadow_master_postinit(inst)
	inst.scrapbook_anim = "scrapbook_shadow"

	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.BAT_BOSS_SHADOW_PLANAR_DAMAGE)

	inst.components.health:SetMaxHealth(TUNING.BAT_BOSS_SHADOW_HEALTH)

	inst.components.lootdropper:SetLootSetupFn(shadow_LootSetupFn)

	inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

	inst.components.combat:SetRetargetFunction(1.5, shadow_RetargetFn)
	--no KeepTargetFn, deaggro handled by ChaseAndAttack params

	inst:AddComponent("colouradder")
	inst:AddComponent("entitytracker")

	inst.sg.mem.noelectrocute = true

	inst.StartTrackingClone = shadow_StartTrackingClone
	inst.OnLoadPostPass = shadow_OnLoadPostPass
end

local function shadowfn() return commonfn("bat_boss_shadow_actions", shadow_common_postinit, shadow_master_postinit) end

--------------------------------------------------------------------------

local function FollowFx_ColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.fx) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function CreateFxFollowFrame(build, i)
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst:AddTag("FX")

	inst.AnimState:SetBank("bat_boss")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("idle"..tostring(i), true)

	inst:AddComponent("highlightchild")

	inst.persists = false

	if build == "bat_boss_shadow_actions" then
		inst.AnimState:SetSymbolLightOverride("red", 1)
		inst.AnimState:SetSymbolLightOverride("fx_red", 1)
		inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)
	end

	return inst
end

local function SpawnFollowFxForOwner(inst, owner)
	inst.fx = {}
	local build = inst.AnimState:GetBuild()
	local frame
	for i = 1, 3 do
		local fx = CreateFxFollowFrame(build, i)
		frame = frame or math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
		fx.entity:SetParent(owner.entity)
		fx.Follower:FollowSymbol(owner.GUID, "swap_hat", nil, nil, nil, true, nil, i - 1)
		fx.AnimState:SetFrame(frame)
		fx.components.highlightchild:SetOwner(owner)
		table.insert(inst.fx, fx)
	end
	inst.components.colouraddersync:SetColourChangedFn(FollowFx_ColourChanged)
end

local function fx_StartLocalChompSfx(inst)
	TheFocalPoint.SoundEmitter:PlaySound("dontstarve/creatures/bat/wolfbat/headbite_growl_LP", "bat_boss_chomp_loop")
	inst.localsfx = true
end

local function fx_PostUpdate(inst)
	inst.components.updatelooper:RemovePostUpdateFn(fx_PostUpdate)

	local owner = inst.entity:GetParent()
	if owner then
		SpawnFollowFxForOwner(inst, owner)
		if owner.HUD then
			fx_StartLocalChompSfx(inst)
		end
	end
end

local function fx_AttachToOwner(inst, owner)
	inst.entity:SetParent(owner.entity)
	inst.Follower:FollowSymbol(owner.GUID, "swap_hat")
	if owner.components.colouradder then
		owner.components.colouradder:AttachChild(inst)
	end
	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		SpawnFollowFxForOwner(inst, owner)
		if owner.HUD then
			fx_StartLocalChompSfx(inst)
		end
	end
end

local function fx_TriggerChompFx(inst)
	inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/wolfbat/headbite_bloodsuck")
	inst.AnimState:PlayAnimation("chomp_fx")
	inst.AnimState:SetScale(math.random() < 0.5 and -1 or 1, 1)
end

local function fx_OnRemoveEntity(inst)
	if inst.fx then
		for i, v in ipairs(inst.fx) do
			v:Remove()
		end
	end
	if inst.localsfx then
		TheFocalPoint.SoundEmitter:KillSound("bat_boss_chomp_loop")
	end
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("bat_boss")
	inst.AnimState:SetBuild("bat_boss")
	inst.AnimState:PlayAnimation("chomp_fx")

	inst:AddTag("DECOR") --don't use FX, so that we can use NOCLICK instead
	inst:AddTag("NOCLICK")

	inst:AddComponent("colouraddersync")

	inst.OnRemoveEntity = fx_OnRemoveEntity

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		--Can't use OnEntityReplicated because we need to wait for build to sync
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(fx_PostUpdate)

		return inst
	end

	inst.AttachToOwner = fx_AttachToOwner
	inst.TriggerChompFx = fx_TriggerChompFx
	inst.persists = false

	return inst
end

local function SplitFx_OnEntityWake(inst)
	inst.OnEntityWake = nil
	inst.SoundEmitter:PlaySound("dontstarve/creatures/bat/clone")
end

local function splitfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("bat_boss")
	inst.AnimState:SetBuild("bat_boss_shadow_actions")
	inst.AnimState:PlayAnimation("split_fx")

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false

	inst.OnEntityWake = SplitFx_OnEntityWake

	return inst
end

return Prefab("bat_boss", normalfn, assets, prefabs),
	Prefab("bat_bosshat_fx", fxfn, assets),
	Prefab("bat_boss_shadow", shadowfn, assets_shadow, prefabs_shadow),
	Prefab("bat_boss_shadow_split_fx", splitfxfn, assets_shadow_split_fx)
