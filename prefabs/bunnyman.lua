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
}

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
                inst.components.follower.leader == nil or
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

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    if inst:HasTag("shadowthrall_parasite_hosted") then
        inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, IsHost, MAX_TARGET_SHARES)
    else
        inst.components.combat:ShareTarget(data.attacker, SHARE_TARGET_DIST, function(dude) return dude.prefab == inst.prefab end, MAX_TARGET_SHARES)
    end
end

local function OnNewTarget(inst, data)
    if inst:HasTag("shadowthrall_parasite_hosted") then
        inst.components.combat:ShareTarget(data.target, SHARE_TARGET_DIST, IsHost, MAX_TARGET_SHARES)
    else
        inst.components.combat:ShareTarget(data.target, SHARE_TARGET_DIST, function(dude) return dude.prefab == inst.prefab end, MAX_TARGET_SHARES)
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
                    return inst.components.combat:CanTarget(guy)
                        and (guy.components.inventory == nil or not guy.components.inventory:EquipHasTag("manrabbitscarer"))
                        and (guy:HasTag("monster")
                            or guy:HasTag("wonkey")
                            or guy:HasTag("pirate")
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
    return inst.components.follower.leader ~= nil and "FOLLOWER" or nil
end

local function LootSetupFunction(lootdropper)
    local guy = lootdropper.inst.causeofdeath
	if IsForcedNightmare(lootdropper.inst) then
		-- forced beard lord
		lootdropper:SetLoot(forced_beardlordloot)
	elseif IsCrazyGuy(guy ~= nil and guy.components.follower ~= nil and guy.components.follower.leader or guy) then
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

local function OnLoad(inst)
	if IsForcedNightmare(inst) then
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
    end
    if target:HasAnyTag("rabbitking") then
        SwitchLeaderToRabbitKing(inst, target)
        return false
    end

    return true
end

local SCRAPBOOK_HIDE_SYMBOLS = { "hat", "ARM_carry", "HAIR_HAT" }

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
        return inst
    end

    inst.scrapbook_hide = SCRAPBOOK_HIDE_SYMBOLS

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
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })
    inst.components.eater:SetCanEatRaw()

    ------------------------------------------
    inst:AddComponent("combat")
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

	inst.OnLoad = OnLoad

    return inst
end

return Prefab("bunnyman", fn, assets, prefabs)
