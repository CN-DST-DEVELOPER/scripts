local assets =
{
    Asset("ANIM", "anim/manrabbit_basic.zip"),
    Asset("ANIM", "anim/manrabbit_actions.zip"),
    Asset("ANIM", "anim/manrabbit_attacks.zip"),
    Asset("ANIM", "anim/manrabbit_build.zip"),
    Asset("ANIM", "anim/manrabbit_boat_jump.zip"),
    Asset("ANIM", "anim/manrabbit_parasite_death.zip"),

    Asset("ANIM", "anim/manrabbit_beard_build.zip"),
    Asset("ANIM", "anim/manrabbit_beard_basic.zip"),
    Asset("ANIM", "anim/manrabbit_beard_actions.zip"),
    Asset("SOUND", "sound/bunnyman.fsb"),

	Asset("ANIM", "anim/manrabbit_vampire_build.zip"),
	Asset("ANIM", "anim/manrabbit_halloween.zip"),
}

local prefabs =
{
    "meat",
    "monstermeat",
    "manrabbit_tail",
    "beardhair",
	"nightmarefuel",
    "carrot",
	"shadow_despawn",
	"statue_transition_2",

    "bunnymancorpse",

    "pumpkin_bomb",
    "halloween_ornament_9", -- frankenswine decoration
}

-- for vampire bunny
for i = 1, NUM_HALLOWEENCANDY do
    table.insert(prefabs, "halloweencandy_"..i)
end

local beardlordloot = { "beardhair", "beardhair", "monstermeat" }
local forced_beardlordloot = { "nightmarefuel", "beardhair", "beardhair", "monstermeat" }

local brain = require("brains/bunnymanbrain")

local MAX_TARGET_SHARES = 5
local SHARE_TARGET_DIST = 30

local function DoShadowFx(inst, isnightmare)
	local x, y, z = inst.Transform:GetWorldPosition()
	local fx = SpawnPrefab("statue_transition_2")
	fx.Transform:SetPosition(x, y, z)
	fx.Transform:SetScale(1.2, 1.2, 1.2)

	--When forcing into nightmare state, shadow_trap would've already spawned this fx
	if not isnightmare then
		fx = SpawnPrefab("shadow_despawn")
		local platform = inst:GetCurrentPlatform()
		if platform ~= nil then
			fx.entity:SetParent(platform.entity)
			fx.Transform:SetPosition(platform.entity:WorldToLocalSpace(x, y, z))
			fx:ListenForEvent("onremove", function()
				fx.Transform:SetPosition(fx.Transform:GetWorldPosition())
				fx.entity:SetParent(nil)
			end, platform)
		else
			fx.Transform:SetPosition(x, y, z)
		end
	end
end

local function IsCrazyGuy(guy)
    local sanity = guy ~= nil and guy.replica.sanity or nil
    return sanity ~= nil and sanity:IsInsanityMode() and sanity:GetPercentNetworked() <= (guy:HasTag("dappereffects") and TUNING.DAPPER_BEARDLING_SANITY or TUNING.BEARDLING_SANITY)
end

local function IsForcedNightmare(inst)
	return inst.components.timer:TimerExists("forcenightmare")
end

local function ontalk(inst)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/idle_med")
end

local function ClearObservedBeardlord(inst)
    inst.clearbeardlordtask = nil
	if not IsForcedNightmare(inst) then
		inst.beardlord = nil
	end
end

local function SetObserverdBeardLord(inst)
    inst.beardlord = true
    if inst.clearbeardlordtask ~= nil then
        inst.clearbeardlordtask:Cancel()
    end
	inst.clearbeardlordtask = inst:DoTaskInTime(5, ClearObservedBeardlord)
end

local function OnTimerDone(inst, data)
	if data ~= nil and data.name == "forcenightmare" then
		if not (inst:IsInLimbo() or inst:IsAsleep()) then
			if inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("sleeping") then
				inst.components.timer:StartTimer("forcenightmare", 1)
				return
			end
			DoShadowFx(inst, false)
		end
		inst:RemoveEventCallback("timerdone", OnTimerDone)
		inst.AnimState:SetBuild("manrabbit_build")
		if inst.clearbeardlordtask == nil then
			inst.beardlord = nil
		end
	end
end

local function SetForcedBeardLord(inst, duration)
	--duration nil is loading, so don't perform checks
	if duration ~= nil then
		if inst.components.health:IsDead() then
			return
		end
		local t = inst.components.timer:GetTimeLeft("forcenightmare")
		if t ~= nil then
			if t < duration then
				inst.components.timer:SetTimeLeft("forcenightmare", duration)
			end
			return
		end
		inst.components.timer:StartTimer("forcenightmare", duration)
	end
	inst.beardlord = true
	inst.AnimState:SetBuild("manrabbit_beard_build")
	inst:ListenForEvent("timerdone", OnTimerDone)
end

local function OnForceNightmareState(inst, data)
	if data ~= nil and data.duration ~= nil then
		DoShadowFx(inst, true)
		SetForcedBeardLord(inst, data.duration)
	end
end

local function CalcSanityAura(inst, observer)
    if IsCrazyGuy(observer) then
		SetObserverdBeardLord(inst)
        return -TUNING.SANITYAURA_MED
	elseif IsForcedNightmare(inst) then
		return -TUNING.SANITYAURA_MED
    end
    return inst.components.follower ~= nil
        and inst.components.follower:GetLeader() == observer
        and TUNING.SANITYAURA_SMALL
        or 0
end

local function ShouldAcceptItem(inst, item)
    return
        (   --accept all hats!
            item.components.equippable ~= nil and
            item.components.equippable.equipslot == EQUIPSLOTS.HEAD
        ) or
        (   --accept food, but not too many carrots for loyalty!
            inst.components.eater:CanEat(item) and
            (   (item.prefab ~= "carrot" and item.prefab ~= "carrot_cooked") or
                inst.components.follower:GetLeader() == nil or
                inst.components.follower:GetLoyaltyPercent() <= .9
            )
        )
end

local function OnGetItemFromPlayer(inst, giver, item)
    --I eat food
    if item.components.edible ~= nil then
        if (    item.prefab == "carrot" or
                item.prefab == "carrot_cooked"
            ) and
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
				if giver.components.minigame_participator == nil then
	                giver:PushEvent("makefriend")
		            giver.components.leader:AddFollower(inst)
				end
                inst.components.follower:AddLoyaltyTime(
                    giver:HasTag("polite")
                    and TUNING.RABBIT_CARROT_LOYALTY + TUNING.RABBIT_POLITENESS_LOYALTY_BONUS
                    or TUNING.RABBIT_CARROT_LOYALTY
                )
            end
        end
        if inst.components.sleeper:IsAsleep() then
            inst.components.sleeper:WakeUp()
        end
    end

    --I wear hats
    if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
        local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if current ~= nil then
            inst.components.inventory:DropItem(current)
        end
        inst.components.inventory:Equip(item)
        inst.AnimState:Show("hat")
    end
end

local function OnRefuseItem(inst, item)
    inst.sg:GoToState("refuse")
    if inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end
end

local function IsHost(dude)
    return dude:HasTag("shadowthrall_parasite_hosted")
end

local function IsBunnyMan(dude, inst)
	return dude.prefab == inst.prefab and not dude.vampire
end

local function IsVampire(dude, inst)
	return dude.vampire and dude.prefab == inst.prefab
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
	if inst.vampire then
		inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, IsVampire, MAX_TARGET_SHARES)
	elseif inst:HasTag("shadowthrall_parasite_hosted") then
        inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, IsHost, MAX_TARGET_SHARES)
    else
		inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, IsBunnyMan, MAX_TARGET_SHARES)
    end
end

local function OnNewTarget(inst, data)
	if inst.vampire then
		inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, IsVampire, MAX_TARGET_SHARES)
	elseif inst:HasTag("shadowthrall_parasite_hosted") then
        inst.components.combat:ShareTarget(data.target, SHARE_TARGET_DIST, IsHost, MAX_TARGET_SHARES)
    else
		inst.components.combat:ShareTarget(data.target, SHARE_TARGET_DIST, IsBunnyMan, MAX_TARGET_SHARES)
    end
end

local RETARGET_MUST_TAGS = { "_combat", "_health" }
local RETARGET_ONEOF_TAGS = { "monster", "player", "pirate"}
local function NormalRetargetFn(inst)
    return not inst:IsInLimbo()
        and FindEntity(
                inst,
                TUNING.PIG_TARGET_DIST,
                function(guy)
					return not IsVampire(guy, inst)
						and inst.components.combat:CanTarget(guy)
                        and (guy.components.inventory == nil or not guy.components.inventory:EquipHasTag("manrabbitscarer"))
                        and (guy:HasAnyTag("monster", "wonkey", "pirate")
                            or (guy.components.inventory ~= nil and
                                guy:IsNear(inst, TUNING.BUNNYMAN_SEE_MEAT_DIST) and
                                HasMeatInInventoryFor(guy)))
                end,
                RETARGET_MUST_TAGS, -- see entityreplica.lua
                nil,
                RETARGET_ONEOF_TAGS
            )
        or nil
end

local function NormalKeepTargetFn(inst, target)
    return not (target.sg ~= nil and target.sg:HasStateTag("hiding")) and inst.components.combat:CanTarget(target)
end

local function giveupstring()
    return "RABBIT_GIVEUP", math.random(#STRINGS["RABBIT_GIVEUP"])
end

local function battlecry(combatcmp, target)
    local strtbl =
        target ~= nil and
        HasMeatInInventoryFor(target) and
        "RABBIT_MEAT_BATTLECRY" or
        "RABBIT_BATTLECRY"
    return strtbl, math.random(#STRINGS[strtbl])
end

local function GetStatus(inst)
    return inst.components.follower:GetLeader() ~= nil and "FOLLOWER" or nil
end

local function LootSetupFunction(lootdropper)
    local guy = lootdropper.inst.causeofdeath
	if IsForcedNightmare(lootdropper.inst) then
		-- forced beard lord
		lootdropper:SetLoot(forced_beardlordloot)
	elseif IsCrazyGuy(guy ~= nil and guy.components.follower ~= nil and guy.components.follower:GetLeader() or guy) then
        -- beard lord
        lootdropper:SetLoot(beardlordloot)
    else
        -- regular loot
        lootdropper:AddRandomLoot("carrot", 3)
        lootdropper:AddRandomLoot("meat", 3)
        lootdropper:AddRandomLoot("manrabbit_tail", 2)
        lootdropper.numrandomloot = 1
    end
end

local function OnSave(inst, data)
	data.vampire = inst.vampire or inst.wasvampire
    data._vampireinitialized = inst._vampireinitialized
end

local function OnPreLoad(inst, data)--, ents)
	if data then
		inst._vampireinitialized = data._vampireinitialized
		if data.vampire then
			if IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) then
				inst:MakeVampireBunny()
			else
				inst.wasvampire = true
			end
		end
	end
end

local function OnLoad(inst, data)
	if not inst.vampire and IsForcedNightmare(inst) then
		SetForcedBeardLord(inst, nil)
	end
end

local function SwitchLeaderToRabbitKing(inst, rabbitking)
    local follower = inst.components.follower
    if follower then
        follower:SetLeader(rabbitking)
        follower:AddLoyaltyTime(TUNING.RABBITKING_STOLEN_MANRABBIT_LOYALTY_TIME)
        local target = rabbitking.components.combat.target
        if target then
            inst.components.combat:SuggestTarget(target)
        end
    end
end
local function TryToSwitchLeader(inst, target)
    if target.components.follower == nil then
        return
    end

    local leader = target.components.follower:GetLeader()
    if leader == nil then
        return
    end

    if leader:HasTag("rabbitking") then
        SwitchLeaderToRabbitKing(inst, leader)
    else
        TryToSwitchLeader(inst, leader)
    end
end
local function ShouldAggro(inst, target)
    if target:HasTag("rabbitking_manrabbit") then
        TryToSwitchLeader(inst, target)
        return false
	elseif target:HasTag("rabbitking") then
        SwitchLeaderToRabbitKing(inst, target)
        return false
    end
    return true
end

local vampirebunnybrain, vampirebunnyloot

local function VampireRetargetFn(inst)
	local player, dsq = inst:GetNearestPlayer(true)
	return dsq and dsq < TUNING.HN_MONSTER_TARGET_DIST * TUNING.HN_MONSTER_TARGET_DIST and player or nil
end

local function VampireKeepTargetFn(inst, target)
	return inst.components.combat:CanTarget(target)
end

local function VampireSleepTest(inst) return false end
local function VampireWakeTest(inst) return true end

local function VampireOnSetHome(inst, home)--, oldhome)
    if home and home.EnableVampireBunnyHouse then
        home:EnableVampireBunnyHouse(true)
    end
end

local function MakeVampireBunny(inst)
	vampirebunnybrain = vampirebunnybrain or require("brains/vampirebunnybrain")
	vampirebunnyloot = vampirebunnyloot or { "monstermeat", "monstermeat", "manrabbit_tail" }

	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:SetBrain(vampirebunnybrain)
	inst.AnimState:SetBuild("manrabbit_vampire_build")
	if inst.AnimState:IsCurrentAnimation("idle_loop") then
		local t = inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime()
		inst.AnimState:PlayAnimation("halloween_idle_loop", true)
		t = inst.AnimState:GetCurrentAnimationLength() - t
		if t > 0 then
			inst.AnimState:SetTime(t)
		end
	end
	inst.vampire = true
	inst.sg.mem.nocorpse = true
	inst.sg.mem.noparasitehost = true
	inst.sg.mem.vampire_idle_sound_delay = GetTime() + 0.1 + math.random()

	--V2C: -clients do this in normal_OnEntityReplicated using "monster" tag.
	--     -this is higher priority than "named", so we can use the halloween
	--      name without losing the saved name.
	inst:SetPrefabNameOverride("vampire_bunny")
	inst.components.inspectable.getstatus = nil

	inst.components.sleeper:SetResistance(math.huge)
	inst.components.sleeper:SetSleepTest(VampireSleepTest)
	inst.components.sleeper:SetWakeTest(VampireWakeTest)

	inst.components.health:SetMaxHealth(TUNING.HN_MONSTER_HEALTH)
	inst.components.health:StopRegen()
	inst.components.health:AddRegenSource(inst, TUNING.HN_MONSTER_HEALTH_REGEN_AMOUNT, TUNING.HN_MONSTER_HEALTH_REGEN_PERIOD, "hn_monster_regen")

	inst.components.combat:SetDefaultDamage(TUNING.HN_MONSTER_DAMAGE)
	inst.components.combat:SetAttackPeriod(TUNING.HN_MONSTER_ATTACK_PERIOD)
	inst.components.combat:SetRange(2.5, 3)
	inst.components.combat:SetRetargetFunction(3, VampireRetargetFn)
	inst.components.combat:SetKeepTargetFunction(VampireKeepTargetFn)
    inst.components.combat:SetShouldAggroFn(nil)
	inst.components.combat:SetTarget(nil)

	inst.components.sanityaura.aurafn = nil
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_LARGE

	inst.components.locomotor.runspeed = TUNING.HN_MONSTER_RUNSPEED
	inst.components.locomotor.walkspeed = TUNING.HN_MONSTER_WALKSPEED

	inst.components.lootdropper:SetLootSetupFn(nil)
	inst.components.lootdropper:SetLoot(vampirebunnyloot)
    inst.components.lootdropper:AddChanceLoot("halloweencandy_"..math.random(NUM_HALLOWEENCANDY), 1)
    inst.components.lootdropper:AddChanceLoot("halloweencandy_"..math.random(NUM_HALLOWEENCANDY), 1)
    inst.components.lootdropper:AddChanceLoot("halloweencandy_"..math.random(NUM_HALLOWEENCANDY), 1)
    inst.components.lootdropper:AddChanceLoot("pumpkin_bomb", 1)
    inst.components.lootdropper:AddChanceLoot("pumpkin_bomb", 0.15)
    inst.components.lootdropper:AddChanceLoot("halloween_ornament_9", 0.1)

	inst.has_nightmare_state = nil
	inst:RemoveEventCallback("ms_forcenightmarestate", OnForceNightmareState)

	inst.components.trader:Disable()
	inst.components.follower:SetLeader(nil)
	inst.components.talker:IgnoreAll("becamevampirebunny")

    inst.homeseeker_onsethome = VampireOnSetHome
    local parent = inst.entity:GetParent()
    if parent and parent.EnableVampireBunnyHouse then
        parent:EnableVampireBunnyHouse(true)
    elseif inst.components.homeseeker then
        VampireOnSetHome(inst, inst.components.homeseeker.home)
    end
end

local function OnEntityReplicated(inst)
	if inst:HasTag("monster") then
		inst:SetPrefabNameOverride("vampire_bunny")
	end
end

local function OnInitHallowedNights(inst)
	inst._inithallowednights = nil
    if not inst._vampireinitialized then
        inst._vampireinitialized = true
		if TheWorld:HasTag("cave") and math.random() <= TUNING.HN_MONSTER_CHANCE then
            inst:MakeVampireBunny()
        end
    end
end

local SCRAPBOOK_HIDE_LAYERS = { "hat", "ARM_carry", "HAIR_HAT" }

local DIET = { FOODTYPE.VEGGIE, FOODTYPE.RAW }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("manrabbit_build")

    MakeCharacterPhysics(inst, 50, .5)

    inst.DynamicShadow:SetSize(1.5, .75)
    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(1.25, 1.25, 1.25)

    inst:AddTag("cavedweller")
    inst:AddTag("character")
    inst:AddTag("pig")
    inst:AddTag("manrabbit")
    inst:AddTag("scarytoprey")
    inst:AddTag("regular_bunnyman")
    inst:AddTag("canwearhat")
    inst:AddTag("nightmarecorruptable")

    inst.AnimState:SetBank("manrabbit")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:Hide("hat")
    inst.AnimState:Hide("ARM_carry")
    inst.AnimState:Hide("HAIR_HAT")

    inst.AnimState:SetClientsideBuildOverride("insane", "manrabbit_build", "manrabbit_beard_build")

    --trader (from trader component) added to pristine state for optimization
    inst:AddTag("trader")

    --Sneak these into pristine state for optimization
    inst:AddTag("_named")

    inst:AddComponent("talker")
    inst.components.talker.fontsize = 24
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.offset = Vector3(0, -500, 0)
    inst.components.talker:MakeChatter()

    inst:AddComponent("spawnfader")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst.OnEntityReplicated = OnEntityReplicated

        return inst
    end

	inst.scrapbook_hide = SCRAPBOOK_HIDE_LAYERS

    --Remove these tags so that they can be added properly when replicating components below
    inst:RemoveTag("_named")

    inst.components.talker.ontalk = ontalk

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.runspeed = TUNING.PIG_RUN_SPEED * 2.2 -- account for them being stopped for part of their anim
    inst.components.locomotor.walkspeed = TUNING.PIG_WALK_SPEED * 1.9 -- account for them being stopped for part of their anim

    -- boat hopping setup
    inst.components.locomotor:SetAllowPlatformHopping(true)
    inst:AddComponent("embarker")
    inst:AddComponent("drownable")

    inst:AddComponent("bloomer")

    ------------------------------------------
    inst:AddComponent("eater")
    inst.components.eater:SetDiet(DIET, DIET)

    ------------------------------------------
    inst:AddComponent("combat")
	inst.components.combat:SetHitArc(TUNING.DEFAULT_HIT_ARC)
    inst.components.combat.hiteffectsymbol = "manrabbit_torso"
    inst.components.combat.panic_thresh = TUNING.BUNNYMAN_PANIC_THRESH

    inst.components.combat.GetBattleCryString = battlecry
    inst.components.combat.GetGiveUpString = giveupstring
    inst.components.combat:SetShouldAggroFn(ShouldAggro)

    MakeMediumBurnableCharacter(inst, "manrabbit_torso")

    inst:AddComponent("named")
    inst.components.named.possiblenames = STRINGS.BUNNYMANNAMES
    inst.components.named:PickNewName()

    ------------------------------------------
    inst:AddComponent("follower")
    inst.components.follower.maxfollowtime = TUNING.PIG_LOYALTY_MAXTIME
    ------------------------------------------
    inst:AddComponent("health")
    inst.components.health:StartRegen(TUNING.BUNNYMAN_HEALTH_REGEN_AMOUNT, TUNING.BUNNYMAN_HEALTH_REGEN_PERIOD)

    ------------------------------------------

    inst:AddComponent("inventory")

    ------------------------------------------

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLootSetupFn(LootSetupFunction)

    ------------------------------------------

    inst:AddComponent("knownlocations")
	inst:AddComponent("timer")

    ------------------------------------------

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(ShouldAcceptItem)
    inst.components.trader.onaccept = OnGetItemFromPlayer
    inst.components.trader.onrefuse = OnRefuseItem
    inst.components.trader.deleteitemonaccept = false

    ------------------------------------------

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aurafn = CalcSanityAura

    ------------------------------------------

    inst:AddComponent("sleeper")
    inst.components.sleeper.watchlight = true

    ------------------------------------------
    MakeMediumFreezableCharacter(inst, "pig_torso")

    ------------------------------------------

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus
    ------------------------------------------

    inst:AddComponent("acidinfusible")
    inst.components.acidinfusible:SetFXLevel(2)
    inst.components.acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.WEAKER)

    ------------------------------------------

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("newcombattarget", OnNewTarget)

    inst.components.sleeper:SetResistance(2)
    inst.components.sleeper.sleeptestfn = NocturnalSleepTest
    inst.components.sleeper.waketestfn = NocturnalWakeTest

    inst.components.combat:SetDefaultDamage(TUNING.BUNNYMAN_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.BUNNYMAN_ATTACK_PERIOD)
    inst.components.combat:SetKeepTargetFunction(NormalKeepTargetFn)
    inst.components.combat:SetRetargetFunction(3, NormalRetargetFn)

    inst.components.locomotor.runspeed = TUNING.BUNNYMAN_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.BUNNYMAN_WALK_SPEED

    inst.components.health:SetMaxHealth(TUNING.BUNNYMAN_HEALTH)

    MakeHauntablePanic(inst)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGbunnyman")

	--shadow_trap interaction
	inst.has_nightmare_state = true
	inst:ListenForEvent("ms_forcenightmarestate", OnForceNightmareState)

    if IsSpecialEventActive(SPECIAL_EVENTS.HALLOWED_NIGHTS) then
        inst._inithallowednights = inst:DoTaskInTime(0, OnInitHallowedNights)
    end

	inst.MakeVampireBunny = MakeVampireBunny
	inst.OnSave = OnSave
	inst.OnPreLoad = OnPreLoad
	inst.OnLoad = OnLoad

    return inst
end

return Prefab("bunnyman", fn, assets, prefabs)
