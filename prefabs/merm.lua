local assets =
{
    Asset("ANIM", "anim/merm_build.zip"),
    Asset("ANIM", "anim/merm_guard_build.zip"),
    Asset("ANIM", "anim/merm_guard_small_build.zip"),
    Asset("ANIM", "anim/merm_actions.zip"),
    Asset("ANIM", "anim/merm_guard_transformation.zip"),
    Asset("ANIM", "anim/ds_pig_boat_jump.zip"),
    Asset("ANIM", "anim/pigman_yotb.zip"),
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    Asset("SOUND", "sound/merm.fsb"),
}

local prefabs =
{
    "pondfish",
    "froglegs",
    "mermking",
    "merm_splash",
    "merm_spawn_fx",
}

local merm_loot =
{
    "pondfish",
    "froglegs",
}

local merm_guard_loot =
{
    "pondfish",
    "froglegs",
}

local sounds = {
    attack = "dontstarve/creatures/merm/attack",
    hit = "dontstarve/creatures/merm/hurt",
    death = "dontstarve/creatures/merm/death",
    talk = "dontstarve/characters/wurt/merm/warrior/talk",
    buff = "dontstarve/characters/wurt/merm/warrior/yell",
    --debuff = "dontstarve/characters/wurt/merm/warrior/yell",
}

local sounds_guard = {
    attack = "dontstarve/characters/wurt/merm/warrior/attack",
    hit = "dontstarve/characters/wurt/merm/warrior/hit",
    death = "dontstarve/characters/wurt/merm/warrior/death",
    talk = "dontstarve/characters/wurt/merm/warrior/talk",
    buff = "dontstarve/characters/wurt/merm/warrior/yell",
    --debuff = ,
}

local merm_brain = require "brains/mermbrain"
local merm_guard_brain = require "brains/mermguardbrain"

local MAX_TARGET_SHARES = 5
local SHARE_TARGET_DIST = 40

local function FindInvaderFn(guy, inst)
    if guy:HasTag("NPC_contestant") then
        return nil
    end

    local function test_disguise(test_guy)
        return test_guy.components.inventory and test_guy.components.inventory:EquipHasTag("merm")
    end

    local leader = inst.components.follower and inst.components.follower.leader

    local leader_guy = guy.components.follower and guy.components.follower.leader
    if leader_guy and leader_guy.components.inventoryitem then
        leader_guy = leader_guy.components.inventoryitem:GetGrandOwner()
    end

    return (guy:HasTag("character") and not (guy:HasTag("merm"))) and
           not ((TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing())) and
           not (leader and leader:HasTag("player")) and
           not (leader_guy and (leader_guy:HasTag("merm")) and
           not guy:HasTag("pig"))
end

local function RetargetFn(inst)

    if inst:HasTag("NPC_contestant") then
        return nil
    end

    local defend_dist = inst:HasTag("mermguard") and TUNING.MERM_GUARD_DEFEND_DIST or TUNING.MERM_DEFEND_DIST
    local defenseTarget = inst
    local home = inst.components.homeseeker and inst.components.homeseeker.home

    if home and inst:GetDistanceSqToInst(home) < defend_dist * defend_dist then
        defenseTarget = home
    end

    return FindEntity(defenseTarget or inst, SpringCombatMod(TUNING.MERM_TARGET_DIST), FindInvaderFn)
end

local function KeepTargetFn(inst, target)

    local defend_dist = inst:HasTag("mermguard") and TUNING.MERM_GUARD_DEFEND_DIST or TUNING.MERM_DEFEND_DIST
    local home = inst.components.homeseeker and inst.components.homeseeker.home
    local follower = inst.components.follower and inst.components.follower.leader

    if home and not follower then
        return home:GetDistanceSqToInst(target) < defend_dist*defend_dist
               and home:GetDistanceSqToInst(inst) < defend_dist*defend_dist
    end

    return inst.components.combat:CanTarget(target)
end

local DECIDROOTTARGET_MUST_TAGS = { "_combat", "_health", "merm" }
local DECIDROOTTARGET_CANT_TAGS = { "INLIMBO" }

local function OnAttackedByDecidRoot(inst, attacker)
    local share_target_dist = inst:HasTag("mermguard") and TUNING.MERM_GUARD_SHARE_TARGET_DIST or TUNING.MERM_SHARE_TARGET_DIST
    local max_target_shares = inst:HasTag("mermguard") and TUNING.MERM_GUARD_MAX_TARGET_SHARES or TUNING.MERM_MAX_TARGET_SHARES

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SpringCombatMod(share_target_dist) * .5, DECIDROOTTARGET_MUST_TAGS, DECIDROOTTARGET_CANT_TAGS)
    local num_helpers = 0

    for i, v in ipairs(ents) do
        if v ~= inst and not v.components.health:IsDead() then
            v:PushEvent("suggest_tree_target", { tree = attacker })
            num_helpers = num_helpers + 1
            if num_helpers >= max_target_shares then
                break
            end
        end
    end
end

local function OnAttacked(inst, data)

    local attacker = data and data.attacker
    if attacker and attacker.prefab == "deciduous_root" and attacker.owner ~= nil then
        OnAttackedByDecidRoot(inst, attacker.owner)

    elseif attacker and inst.components.combat:CanTarget(attacker) and attacker.prefab ~= "deciduous_root" then

        local share_target_dist = inst:HasTag("mermguard") and TUNING.MERM_GUARD_SHARE_TARGET_DIST or TUNING.MERM_SHARE_TARGET_DIST
        local max_target_shares = inst:HasTag("mermguard") and TUNING.MERM_GUARD_MAX_TARGET_SHARES or TUNING.MERM_MAX_TARGET_SHARES

        inst.components.combat:SetTarget(attacker)

        if inst.components.homeseeker and inst.components.homeseeker.home then
            local home = inst.components.homeseeker.home

            if home and home.components.childspawner and inst:GetDistanceSqToInst(home) <= share_target_dist*share_target_dist then
                max_target_shares = max_target_shares - home.components.childspawner.childreninside
                home.components.childspawner:ReleaseAllChildren(attacker)
            end

            inst.components.combat:ShareTarget(attacker, share_target_dist, function(dude)
                return (dude.components.homeseeker and dude.components.homeseeker.home and dude.components.homeseeker.home == home) or
                        (dude:HasTag("merm") and not dude:HasTag("player") and not
                        (dude.components.follower and dude.components.follower.leader and dude.components.follower.leader:HasTag("player")))
            end, max_target_shares)
        end
    end
end

local function IsAbleToAccept(inst, item, giver)
    if inst.components.health ~= nil and inst.components.health:IsDead() then
        return false, "DEAD"
    elseif inst.sg ~= nil and inst.sg:HasStateTag("busy") then
        if inst.sg:HasStateTag("sleeping") then
            return true
        end
        return false, "BUSY"
    end
    return true
end

local function ShouldAcceptItem(inst, item, giver)
    if inst:HasTag("mermguard") and inst.king ~= nil then
        return false
    end

    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end

    return (giver:HasTag("merm") and not (inst:HasTag("mermguard") and giver:HasTag("mermdisguise"))) and
           ((item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD) or
           (item.components.edible and inst.components.eater:CanEat(item)) or
           (item:HasTag("fish") and not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst))))
end

local function OnGetItemFromPlayer(inst, giver, item)

    local loyalty_max = inst:HasTag("mermguard") and TUNING.MERM_GUARD_LOYALTY_MAXTIME or TUNING.MERM_LOYALTY_MAXTIME
    local loyalty_per_hunger = inst:HasTag("mermguard") and TUNING.MERM_GUARD_LOYALTY_PER_HUNGER or TUNING.MERM_LOYALTY_PER_HUNGER

    if item.components.edible ~= nil then
        if inst.components.combat:TargetIs(giver) then
            inst.components.combat:SetTarget(nil)
        elseif giver.components.leader ~= nil and not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst)) then
            giver:PushEvent("makefriend")
            giver.components.leader:AddFollower(inst)

            inst.components.follower:AddLoyaltyTime(item.components.edible:GetHunger() * loyalty_per_hunger)
            inst.components.follower.maxfollowtime = loyalty_max
        end
    end

    -- I also wear hats
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

    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
        inst.components.sleeper:WakeUp()
    end
end

local function SuggestTreeTarget(inst, data)
    local ba = inst:GetBufferedAction()
    if data ~= nil and data.tree ~= nil and (ba == nil or ba.action ~= ACTIONS.CHOP) then
        inst.tree_target = data.tree
    end
end

local function RoyalUpgrade(inst)

    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH_KINGBONUS)
    inst.components.combat:SetDefaultDamage(TUNING.MERM_DAMAGE_KINGBONUS)
    inst.Transform:SetScale(1.05, 1.05, 1.05)
end

local function RoyalDowngrade(inst)

    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(TUNING.MERM_DAMAGE)
    inst.Transform:SetScale(1, 1, 1)
end

local function RoyalGuardDowngrade(inst)

    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.PUNY_MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(TUNING.PUNY_MERM_DAMAGE)
    inst.AnimState:SetBuild("merm_guard_small_build")
    inst.Transform:SetScale(0.9, 0.9, 0.9)
end

local function RoyalGuardUpgrade(inst)

    if inst.components.health:IsDead() then
        return
    end

    inst.components.health:SetMaxHealth(TUNING.MERM_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(TUNING.MERM_GUARD_DAMAGE)
    inst.AnimState:SetBuild("merm_guard_build")
    inst.Transform:SetScale(1, 1, 1)
    --inst.Transform:SetScale(1.15, 1.15, 1.15)
end

local function ResolveMermChatter(inst, strid, strtbl)

    local stringtable = STRINGS[strtbl:value()]
    if stringtable then
        if stringtable[strid:value()] ~= nil then
            if ThePlayer and ThePlayer:HasTag("mermfluent") then
                return stringtable[strid:value()][1] -- First value is always the translated one
            else
                return stringtable[strid:value()][2]
            end
        end
    end

end

local function ShouldGuardSleep(inst)
    return false
end

local function ShouldGuardWakeUp(inst)
    return true
end

local function ShouldSleep(inst)
    return NocturnalSleepTest(inst)
        and ((inst.components.follower == nil or inst.components.follower.leader) == nil and
        not TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst))
end

local function ShouldWakeUp(inst)
    return NocturnalWakeTest(inst) or (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst))
end

local function OnTimerDone(inst, data)
    if data.name == "facetime" then
        inst.components.timer:StartTimer("dontfacetime", 10)
    end
end

local function battlecry(combatcmp, target)
    local strtbl =
        combatcmp.inst:HasTag("guard") and
        "MERM_BATTLECRY" or
        "MERM_BATTLECRY"
    return strtbl, math.random(#STRINGS[strtbl])
end

local function MakeMerm(name, assets, prefabs, common_postinit, master_postinit)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        MakeCharacterPhysics(inst, 50, .5)

        inst.DynamicShadow:SetSize(1.5, .75)
        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("pigman")
        inst.AnimState:Hide("hat")

        if IsSpecialEventActive(SPECIAL_EVENTS.YOTB) then
            inst.AnimState:AddOverrideBuild("pigman_yotb")
        end

        inst:AddTag("character")
        inst:AddTag("merm")
        inst:AddTag("wet")

        inst:AddComponent("talker")
        inst.components.talker.fontsize = 35
        inst.components.talker.font = TALKINGFONT
        inst.components.talker.offset = Vector3(0, -400, 0)
        inst.components.talker.resolvechatterfn = ResolveMermChatter
        inst.components.talker:MakeChatter()

        if common_postinit ~= nil then
            common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("locomotor")
        -- boat hopping setup
        inst.components.locomotor:SetAllowPlatformHopping(true)
        inst:AddComponent("embarker")
	    inst:AddComponent("drownable")

        inst:AddComponent("eater")
        inst.components.eater:SetDiet({ FOODGROUP.VEGETARIAN }, { FOODGROUP.VEGETARIAN })

        inst:AddComponent("health")
        inst:AddComponent("combat")
        inst.components.combat.GetBattleCryString = battlecry
        inst.components.combat.hiteffectsymbol = "pig_torso"

        inst:AddComponent("lootdropper")
        inst:AddComponent("inventory")
        inst:AddComponent("inspectable")
        inst:AddComponent("knownlocations")
        inst:AddComponent("follower")
        inst:AddComponent("sleeper")
        inst:AddComponent("mermcandidate")

        inst:AddComponent("timer")

        inst:AddComponent("trader")
        inst.components.trader:SetAcceptTest(ShouldAcceptItem)
        inst.components.trader:SetAbleToAcceptTest(IsAbleToAccept)
        inst.components.trader.onaccept = OnGetItemFromPlayer
        inst.components.trader.onrefuse = OnRefuseItem
        inst.components.trader.deleteitemonaccept = false

        MakeMediumBurnableCharacter(inst, "pig_torso")
        MakeMediumFreezableCharacter(inst, "pig_torso")

        inst:ListenForEvent("timerdone", OnTimerDone)
        inst:ListenForEvent("attacked", OnAttacked)
        inst:ListenForEvent("suggest_tree_target", SuggestTreeTarget)

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local SLIGHTDELAY = 1

local function guard_common(inst)
    inst.AnimState:SetBuild("merm_guard_build")
    inst:AddTag("mermguard")
    inst.Transform:SetScale(1, 1, 1)
    inst:AddTag("guard")

    inst.sounds = sounds_guard
end

local function guard_master(inst)

    inst.components.locomotor.runspeed =  TUNING.MERM_GUARD_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.MERM_GUARD_WALK_SPEED

    inst:SetStateGraph("SGmerm")
    inst:SetBrain(merm_guard_brain)

    inst.components.sleeper:SetSleepTest(ShouldGuardSleep)
    inst.components.sleeper:SetWakeTest(ShouldGuardWakeUp)

    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_GUARD_HEALTH)
    inst.components.combat:SetDefaultDamage(TUNING.MERM_GUARD_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.MERM_GUARD_ATTACK_PERIOD)

    inst.components.lootdropper:SetLoot(merm_guard_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_GUARD_LOYALTY_MAXTIME

    inst:ListenForEvent("onmermkingcreated",   function()
        inst:DoTaskInTime(math.random()*SLIGHTDELAY,function()
            RoyalGuardUpgrade(inst)
            inst:PushEvent("onmermkingcreated")
        end)
    end, TheWorld)
    inst:ListenForEvent("onmermkingdestroyed", function()
        inst:DoTaskInTime(math.random()*SLIGHTDELAY,function()
            RoyalGuardDowngrade(inst)
            inst:PushEvent("onmermkingdestroyed")
        end)
    end, TheWorld)

    inst:DoTaskInTime(0,function()
        if not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing()) then
            RoyalGuardDowngrade(inst)
        end
    end)
end

local function common_displaynamefn(inst)
    return (inst:HasTag("mermprince") and STRINGS.NAMES.MERM_PRINCE) or nil
end

local function common_common(inst)
    inst.sounds = sounds
    inst.AnimState:SetBuild("merm_build")

    inst.displaynamefn = common_displaynamefn
end

local function OnEat(inst, data)
    if TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:IsCandidate(inst) then
        if data.food and data.food.components.edible then
            inst.components.mermcandidate:AddCalories(data.food)
        end
    end
end

local function common_master(inst)
    inst.components.locomotor.runspeed = TUNING.MERM_RUN_SPEED
    inst.components.locomotor.walkspeed = TUNING.MERM_WALK_SPEED

    inst:SetStateGraph("SGmerm")
    inst:SetBrain(merm_brain)

    inst.components.sleeper:SetNocturnal(true)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWakeUp)

    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.components.health:SetMaxHealth(TUNING.MERM_HEALTH)
    inst.components.combat:SetDefaultDamage(TUNING.MERM_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.MERM_ATTACK_PERIOD)

    MakeHauntablePanic(inst)

    inst.components.lootdropper:SetLoot(merm_loot)

    inst.components.follower.maxfollowtime = TUNING.MERM_LOYALTY_MAXTIME

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("suggest_tree_target", SuggestTreeTarget)

    inst:ListenForEvent("onmermkingcreated",   function()
        inst:DoTaskInTime(math.random()*SLIGHTDELAY,function()
            RoyalUpgrade(inst)
            inst:PushEvent("onmermkingcreated")
        end)
    end, TheWorld)
    inst:ListenForEvent("onmermkingdestroyed", function()
        inst:DoTaskInTime(math.random()*SLIGHTDELAY,function()
            RoyalDowngrade(inst)
            inst:PushEvent("onmermkingdestroyed")
        end)
    end, TheWorld)

    inst:ListenForEvent("oneat", OnEat)

    if TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing() then
        RoyalUpgrade(inst)
    end
end

return MakeMerm("merm", assets, prefabs, common_common, common_master),
       MakeMerm("mermguard", assets, prefabs, guard_common, guard_master)