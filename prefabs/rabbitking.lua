local brain = require("brains/rabbitkingbrain")
local KING_SCALE = 1.4

-----------------------------------------------------------------
-- common
-----------------------------------------------------------------
local function CheckRabbitKingManager(inst)
    -- NOTES(JBK): This prefab should only have one in the world belonging to the rabbitkingmanager so we need to check if it is okay to have more.
    -- Reason this function exists is for debug spawning players and other debug tests.
    local rabbitkingmanager = TheWorld.components.rabbitkingmanager
    if rabbitkingmanager == nil then
        inst.sg:GoToState("burrowaway")
        return
    end

    rabbitkingmanager:TryForceRabbitKing_Internal(inst)
end
local function fn_common(rabbitking_kind, build_override)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 1, 0.5)

    inst.DynamicShadow:SetSize(1, .75)
    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("rabbit")
    inst.AnimState:SetBuild(build_override or "rabbit_build")
    inst.AnimState:AddOverrideBuild("rabbitking_action")
    inst.AnimState:OverrideSymbol("hill", "manrabbit_actions", "hill")
    inst.AnimState:OverrideSymbol("wormmovefx", "manrabbit_actions", "wormmovefx")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("animal")
    inst:AddTag("rabbit")
    inst:AddTag("rabbitking")
    inst:AddTag("stunnedbybomb")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.rabbitking_kind = rabbitking_kind

    inst:AddComponent("colouradder")

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.runspeed = TUNING.RABBITKING_RUN_SPEED
    inst:SetStateGraph("SGrabbitking")

    inst:SetBrain(brain)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })

    inst:AddComponent("knownlocations")
    inst:AddComponent("drownable")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.RABBITKING_HEALTH)

    inst:AddComponent("lootdropper")

    inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "chest"

    MakeSmallBurnableCharacter(inst, "chest")
    MakeTinyFreezableCharacter(inst, "chest")

    inst:AddComponent("inspectable")
    inst:AddComponent("sleeper")
    inst.components.sleeper.watchlight = true

    inst:DoTaskInTime(0, CheckRabbitKingManager)

    return inst
end

-----------------------------------------------------------------
-- PASSIVE
-----------------------------------------------------------------
local assets_passive = {
    Asset("ANIM", "anim/ds_rabbit_basic.zip"),
    Asset("ANIM", "anim/rabbitking_passive_build.zip"),
    Asset("ANIM", "anim/rabbitking_action.zip"),
    Asset("ANIM", "anim/manrabbit_actions.zip"),
    Asset("SOUND", "sound/rifts4.fsb"),
}
local prefabs_passive = {
    "smallmeat",
    -- shop
    "armor_carrotlure",
    "rabbitkinghorn",
    "rabbithat",
}
local loot_passive = {
    "smallmeat",
}

local function OnTurnOn_passive(inst)
    inst.rabbitking_trading = true
end
local function OnTurnOff_passive(inst)
    inst.rabbitking_trading = nil
end
local function OnActivate_passive(inst)
    inst:PushEvent("dotrade")
end
local function fn_passive()
    local inst = fn_common("passive", "rabbitking_passive_build")

    inst:AddTag("companion")

    inst.AnimState:SetScale(KING_SCALE, KING_SCALE)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    local sanityaura = inst:AddComponent("sanityaura")
    sanityaura.aura = TUNING.SANITYAURA_TINY

    inst.components.lootdropper:SetLoot(loot_passive)

    local prototyper = inst:AddComponent("prototyper")
    prototyper.onturnon = OnTurnOn_passive
    prototyper.onturnoff = OnTurnOff_passive
    prototyper.onactivate = OnActivate_passive
    prototyper.trees = TUNING.PROTOTYPER_TREES.RABBITKINGSHOP

    return inst
end

-----------------------------------------------------------------
-- AGGRESSIVE
-----------------------------------------------------------------
local assets_aggressive = {
    Asset("ANIM", "anim/ds_rabbit_basic.zip"),
    Asset("ANIM", "anim/rabbitking_aggressive_build.zip"),
    Asset("ANIM", "anim/rabbitking_action.zip"),
    Asset("ANIM", "anim/manrabbit_actions.zip"),
    Asset("SOUND", "sound/rifts4.fsb"),
}
local prefabs_aggressive = {
    "monstermeat",
    "beardhair",
    "rabbitkingminion_bunnyman",
    "rabbitkingspear",
}
local loot_aggressive = {
    "monstermeat",
    "beardhair",
    "beardhair",
    "rabbitkingspear",
}


local function RetargetFunction_Aggressive(inst)
    local rabbitkingmanager = TheWorld.components.rabbitkingmanager
    if rabbitkingmanager then
        return rabbitkingmanager:GetTargetPlayer()
    end

    return nil
end

local function KeepTargetFunction_Aggressive(inst, target)
    return RetargetFunction_Aggressive(inst) == target
end

local function OnLostFollower_Aggressive(inst, follower)
    if inst.components.leader:CountFollowers("rabbitking_manrabbit") == 0 then
        local delay = math.min(inst.components.timer:GetTimeLeft("dropkick_cd") or 1, 1)
        inst.components.timer:StopTimer("dropkick_cd")
        inst.components.timer:StartTimer("dropkick_cd", TUNING.RABBITKING_ABILITY_CD_POSTSTUN) -- Not post stun but same timing window here for reactions.
    end
end

local function CanSummonMinions_Aggressive(inst)
    if inst.components.timer:TimerExists("summon_cd") then
        return false
    end

    return inst.components.leader:CountFollowers("rabbitking_manrabbit") < TUNING.RABBITKING_ABILITY_SUMMON_COUNT
end
local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end
local function FindMinionSpawnPos_Aggressive(inst, pt)
    for r = 8, 2, -1 do
        local offset = FindWalkableOffset(pt, math.random() * TWOPI, r, 12, true, true, NoHoles)
        if offset ~= nil then
            offset.x = offset.x + pt.x
            offset.z = offset.z + pt.z
            return offset
        end
    end

    return nil
end
local function SummonMinions_Aggressive_Visualize(minion, target)
    minion:ReturnToScene()
    if target and target:IsValid() then
        minion.components.combat:SuggestTarget(target)
    end
    minion:PushEvent("burrowarrive")
end
local function SummonMinions_Aggressive(inst)
    if not inst:CanSummonMinions() then
        return nil
    end

    inst.components.timer:StartTimer("summon_cd", TUNING.RABBITKING_ABILITY_SUMMON_CD)
    local pt = inst:GetPosition()
    local target = RetargetFunction_Aggressive(inst)
    local summoncount = TUNING.RABBITKING_ABILITY_SUMMON_COUNT - inst.components.leader:CountFollowers("rabbitking_manrabbit")
    for i = 1, summoncount do
        local minion = SpawnPrefab("rabbitkingminion_bunnyman")
        local spawnpos = inst:FindMinionSpawnPos(pt) or pt
        minion.Transform:SetPosition(spawnpos:Get())
        minion.components.follower:SetLeader(inst)
        minion:RemoveFromScene()
        minion:DoTaskInTime(0.5 + math.random() * 0.5, SummonMinions_Aggressive_Visualize, target)
    end
end
local function BringMinions_Aggressive(inst, pt)
    local followers = inst.components.leader:GetFollowersByTag("rabbitking_manrabbit")
    for _, follower in ipairs(followers) do
        local spawnpos = inst:FindMinionSpawnPos(pt) or pt
        if follower:IsAsleep() then
            -- Stategraph is sleeping so we need to teleport it to the point manually and skip stategraph state.
            follower.Physics:Teleport(spawnpos:Get())
            follower:PushEvent("burrowarrive")
        else
            follower:PushEvent("burrowto", {destination = spawnpos,})
        end
    end
end

local function CanDropkick_Aggressive(inst)
    if inst.components.timer:TimerExists("dropkick_cd") then
        return false
    end

    return true
end

local function fn_aggressive()
    local inst = fn_common("aggressive", "rabbitking_aggressive_build")

    inst:AddTag("scarytoprey")

    inst.AnimState:SetScale(KING_SCALE, KING_SCALE)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    local leader = inst:AddComponent("leader")
    leader.onremovefollower = OnLostFollower_Aggressive

    local timer = inst:AddComponent("timer")
    timer:StartTimer("summon_cd", TUNING.RABBITKING_ABILITY_SUMMON_CD_START)
    timer:StartTimer("dropkick_cd", TUNING.RABBITKING_ABILITY_DROPKICK_CD_START)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    inst.components.lootdropper:SetLoot(loot_aggressive)

    local combat = inst.components.combat
    combat:SetDefaultDamage(TUNING.RABBITKING_DAMAGE)
    combat:SetRetargetFunction(3, RetargetFunction_Aggressive)
    combat:SetKeepTargetFunction(KeepTargetFunction_Aggressive)

    inst.CanSummonMinions = CanSummonMinions_Aggressive
    inst.SummonMinions = SummonMinions_Aggressive
    inst.FindMinionSpawnPos = FindMinionSpawnPos_Aggressive
    inst.BringMinions = BringMinions_Aggressive
    inst.CanDropkick = CanDropkick_Aggressive

    return inst
end

-----------------------------------------------------------------
-- MINION_BUNNYMAN
-----------------------------------------------------------------
local assets_bunnyman = {
    Asset("ANIM", "anim/manrabbit_attacks.zip"),

    Asset("ANIM", "anim/manrabbit_enforcer_build.zip"),
    Asset("ANIM", "anim/manrabbit_beard_build.zip"),
    Asset("ANIM", "anim/manrabbit_actions.zip"),
    Asset("SOUND", "sound/bunnyman.fsb"),
    Asset("SOUND", "sound/mole.fsb"),
}
local prefabs_bunnyman = {
    "beardhair",
    "monstermeat",
    "meat",
    "manrabbit_tail",
}
local bunnyman_brain = require("brains/rabbitking_bunnymanbrain")
local function OnTalk_Bunnyman(inst)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/bunnyman/idle_med")
end
local function NormalLeaderRetargetFn(inst)
    local leader = inst.components.follower and inst.components.follower.leader or nil
    return leader and leader.components.combat.target or nil
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
        target.components.inventory ~= nil and
        HasMeatInInventoryFor(target) and
        "RABBIT_MEAT_BATTLECRY" or
        "RABBIT_BATTLECRY"
    return strtbl, math.random(#STRINGS[strtbl])
end
local function ForceTeleport_Safe(inst)
    inst.sg.mem.forceteleporttask = nil
    if inst.sg.mem.queued_burrowto_data then
        inst.Physics:Teleport(inst.sg.mem.queued_burrowto_data.destination:Get())
        inst:PushEvent("burrowarrive")
    end
end
local function ForceTeleport(inst)
    if inst.sg.mem.queued_burrowto_data then
        inst.sg.mem.forceteleporttask = inst:DoTaskInTime(0, ForceTeleport_Safe)
    end
end
local function OnSave_bunnyman(inst, data)
    if inst.sg.mem.queued_burrowto_data then
        data.burrowto_x = inst.sg.mem.queued_burrowto_data.destination.x
        data.burrowto_z = inst.sg.mem.queued_burrowto_data.destination.z
    end
end
local function OnLoad_bunnyman(inst, data)
    if data then
        if inst.sg and data.burrowto_x and data.burrowto_z then
            inst.sg.mem.queued_burrowto_data = {
                destination = Vector3(data.burrowto_x, 0, data.burrowto_z),
            }
        end
    end
end

local BUNNYMAN_SCRAPBOOK_HIDE = { "hat", "ARM_carry", "HAIR_HAT" }
local function fn_bunnyman()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("manrabbit_enforcer_build")
    inst.AnimState:AddOverrideBuild("manrabbit_actions")
    inst.AnimState:OverrideSymbol("armblur", "manrabbit_beard_build", "armblur")

    MakeCharacterPhysics(inst, 50, .5)

    inst.DynamicShadow:SetSize(1.5, .75)
    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(1.25, 1.25, 1.25)

    inst:AddTag("character")
    inst:AddTag("pig")
    inst:AddTag("manrabbit")
    inst:AddTag("scarytoprey")
    inst:AddTag("rabbitking_manrabbit")

    inst.AnimState:SetBank("manrabbit")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:Hide("hat")
    inst.AnimState:Hide("ARM_carry")
    inst.AnimState:Hide("HAIR_HAT")

    --Sneak these into pristine state for optimization
    inst:AddTag("_named")

    local talker = inst:AddComponent("talker")
    talker.fontsize = 24
    talker.font = TALKINGFONT
    talker.offset = Vector3(0, -500, 0)
    talker:MakeChatter()

    inst:WatchWorldState("isfullmoon", function(inst, isfullmoon)
        if isfullmoon then
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        else
            inst.AnimState:ClearBloomEffectHandle()
        end
    end)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_hide = BUNNYMAN_SCRAPBOOK_HIDE

    --Remove these tags so that they can be added properly when replicating components below
    inst:RemoveTag("_named")

    talker.ontalk = OnTalk_Bunnyman

    local locomotor = inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    locomotor.runspeed = TUNING.BUNNYMAN_RUN_SPEED
    locomotor.walkspeed = TUNING.BUNNYMAN_WALK_SPEED
    -- NOTES(JBK): Do not allow boat hopping for these ones they stick to land only.

    inst:AddComponent("drownable")

    inst:AddComponent("bloomer")

    local combat = inst:AddComponent("combat")
    combat:SetDefaultDamage(TUNING.RABBITKING_ABILITY_SUMMON_DAMAGE)
    combat:SetAttackPeriod(TUNING.RABBITKING_ABILITY_SUMMON_ATTACK_PERIOD)
    combat:SetRetargetFunction(3, NormalLeaderRetargetFn)
    combat:SetKeepTargetFunction(NormalKeepTargetFn)
    combat.hiteffectsymbol = "manrabbit_torso"
    combat.GetBattleCryString = battlecry
    combat.GetGiveUpString = giveupstring

    MakeMediumBurnableCharacter(inst, "manrabbit_torso")

    local named = inst:AddComponent("named")
    named.possiblenames = STRINGS.BUNNYMANNAMES
    named:PickNewName()

    local follower = inst:AddComponent("follower")
    follower.neverexpire = true

    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.RABBITKING_ABILITY_SUMMON_HP)
    -- No health regen on these they get resummoned as replacements.

    local lootdropper = inst:AddComponent("lootdropper")
    lootdropper:AddRandomLoot("beardhair", 3)
    lootdropper:AddRandomLoot("monstermeat", 3)
    lootdropper:AddRandomLoot("carrot", 3)
    lootdropper:AddRandomLoot("meat", 3)
    lootdropper:AddRandomLoot("manrabbit_tail", 4) -- Maintain 25% odds.
    lootdropper.numrandomloot = 1

    local sanityaura = inst:AddComponent("sanityaura")
    sanityaura.aura = -TUNING.SANITYAURA_MED

    local sleeper = inst:AddComponent("sleeper")
    sleeper:SetResistance(2)

    MakeMediumFreezableCharacter(inst, "pig_torso")

    inst:AddComponent("inspectable")

    local acidinfusible = inst:AddComponent("acidinfusible")
    acidinfusible:SetFXLevel(2)
    acidinfusible:SetMultipliers(TUNING.ACID_INFUSION_MULT.WEAKER)

    MakeHauntablePanic(inst)

    inst:SetBrain(bunnyman_brain)
    inst:SetStateGraph("SGrabbitking_bunnyman")

    inst.OnEntitySleep = ForceTeleport
    inst.OnSave = OnSave_bunnyman
    inst.OnLoad = OnLoad_bunnyman

    return inst
end

-----------------------------------------------------------------
-- LUCKY
-----------------------------------------------------------------
local assets_lucky = {
    Asset("ANIM", "anim/ds_rabbit_basic.zip"),
    Asset("ANIM", "anim/rabbitking_lucky_build.zip"),
    Asset("ANIM", "anim/rabbitking_action.zip"),
    Asset("ANIM", "anim/manrabbit_actions.zip"),
    Asset("SOUND", "sound/rabbit.fsb"),
    Asset("INV_IMAGE", "rabbitking_lucky"),
}
local prefabs_lucky = {
    "smallmeat",
}
local loot_lucky = {
    "smallmeat",
}
local rabbitsounds_lucky = {
    scream = "dontstarve/rabbit/scream",
    run = "dontstarve/rabbit/scream",
    hurt = "dontstarve/rabbit/scream_short",
}

local function ConvertLuckyToRabbitKing(inst, data)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner then
        if owner.components.inventory then
            owner.components.inventory:DropItem(inst, true, true) -- In case the world does not have a manager we want it to drop back down.
        end
    else
        local player, distsq = inst:GetNearestPlayer(true)
        if distsq < TUNING.RABBITKING_TELEPORT_DISTANCE_SQ then
            owner = player
        end
    end
    if owner and owner:HasTag("player") then
        local rabbitkingmanager = TheWorld.components.rabbitkingmanager
        if rabbitkingmanager and rabbitkingmanager:GetRabbitKing() == inst then
            local pt = inst:GetPosition()
            inst:Remove()
            local jumpfrom = data and (data.trap or data.player) or nil
            if jumpfrom and not jumpfrom:IsValid() then
                jumpfrom = nil
            end
            rabbitkingmanager:CreateRabbitKingForPlayer(owner, pt, nil, {jumpfrominventory = true, jumpfrom = jumpfrom,})
            owner.components.talker:Say(GetString(owner, "ANNOUNCE_RABBITKING_LUCKYCAUGHT"))
        end
    end
end
local function ConvertLuckyToRabbitKing_Bridge(inst)
    inst.rabbitking_convert_task = nil
    inst:ConvertLuckyToRabbitKing()
end
local function OnPutInInventory_lucky(inst, owner)
    inst.OnEntitySleep = nil
    inst.rabbitking_convert_task = inst:DoTaskInTime(0, ConvertLuckyToRabbitKing_Bridge)
end
local function OnDropped_lucky(inst)
    if inst.rabbitking_convert_task ~= nil then
        inst.rabbitking_convert_task:Cancel()
        inst.rabbitking_convert_task = nil
    end
    inst.OnEntitySleep = inst.Remove
end
local function OnLoad_lucky(inst)
    if inst.components.inventoryitem then
        inst.components.inventoryitem.canbepickedup = true
        inst.components.inventoryitem.canbepickedupalive = true
    end
end
local function fn_lucky()
    local inst = fn_common("lucky", "rabbitking_lucky_build")
    inst:AddTag("prey")
    inst:AddTag("smallcreature")
    inst:AddTag("canbetrapped") -- Triggers traps but not trappable with trappable = false below.

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = rabbitsounds_lucky
    inst.ConvertLuckyToRabbitKing = ConvertLuckyToRabbitKing

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = TUNING.SANITYAURA_SMALL

    inst.components.locomotor.runspeed = TUNING.RABBITKING_RUN_SPEED * 0.75 -- Slow and plump.

    inst.components.lootdropper:SetLoot(loot_lucky)
    inst.components.lootdropper.trappable = false

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem.nobounce = true
    inventoryitem.canbepickedup = false
    inventoryitem.canbepickedupalive = false
    inventoryitem.trappable = false
    inventoryitem:SetSinks(true)
    inst:ListenForEvent("onputininventory", OnPutInInventory_lucky)
    inst:ListenForEvent("ondropped", OnDropped_lucky)

    inst.force_onwenthome_message = true
    inst:ListenForEvent("onwenthome", inst.Remove)

    inst:ListenForEvent("safelydisarmedtrap", inst.ConvertLuckyToRabbitKing)

    inst.OnLoad = OnLoad_lucky

    return inst
end

-- NOTES(JBK): For modders these prefabs are managed by rabbitkingmanager and rely on its logic to drive the feel of the creature.
return Prefab("rabbitking_passive", fn_passive, assets_passive, prefabs_passive),
Prefab("rabbitking_aggressive", fn_aggressive, assets_aggressive, prefabs_aggressive),
Prefab("rabbitkingminion_bunnyman", fn_bunnyman, assets_bunnyman, prefabs_bunnyman),
Prefab("rabbitking_lucky", fn_lucky, assets_lucky, prefabs_lucky)
