local assets = {
    Asset("ANIM", "anim/shadow_thrall_centipede_head.zip"),
    Asset("ANIM", "anim/shadow_thrall_centipede_body.zip"),
}

local common_prefabs = {
    "dreadstone",
    "horrorfuel",
    "nightmarefuel",
}

local controller_prefabs = {
    "shadowthrall_centipede_head",
    "shadowthrall_centipede_body",
    --#DELETEME
    "shadowthrall_centipede_spawner",
}
local head_prefabs = ConcatArrays(common_prefabs, {"shadowthrall_centipede_body"})
local torso_prefabs = ConcatArrays(common_prefabs, {})

local head_brain = require("brains/shadowthrall_centipede_brain")

SetSharedLootTable("shadowthrall_centipede_head", {
    { "dreadstone",  1.00 },
    { "dreadstone",  0.66 },
    { "dreadstone",  0.34 },

    { "horrorfuel",  1.00 },
    { "horrorfuel",  1.00 },
    { "horrorfuel",  0.25 },

    { "nightmarefuel",  1.00 },
    { "nightmarefuel",  1.00 },
    { "nightmarefuel",  0.50 },
    { "nightmarefuel",  0.25 },
    { "nightmarefuel",  0.25 },
})

local RECENTLY_CHARGED = {}

local function ClearRecentlyCharged(inst, other)
    RECENTLY_CHARGED[other] = nil
end

local MOVING_DELAY = 10 * FRAMES --Time we need to start moving to do collide
local CLEAR_DELAY = 15 * FRAMES
local function OnOtherCollide(inst, other)
    if not other:IsValid() or RECENTLY_CHARGED[other] then
        return
    elseif other:HasTag("smashable") and other.components.health ~= nil then
        other.components.health:Kill()
    elseif other.components.workable ~= nil
            and other.components.workable:CanBeWorked()
            and other.components.workable.action ~= ACTIONS.NET then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)
        if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
            local r, size, height = GetCombatFxSize(other)
            RECENTLY_CHARGED[other] = true
            ShakeAllCameras(CAMERASHAKE.SIDE, 0.5, .01, r, inst, 40)
            inst:DoTaskInTime(CLEAR_DELAY, ClearRecentlyCharged, other)
        end
    elseif other.components.health ~= nil and not other.components.health:IsDead() then
        local r, size, height = GetCombatFxSize(other)
        RECENTLY_CHARGED[other] = true
        ShakeAllCameras(CAMERASHAKE.SIDE, 0.5, .01, r, inst, 40)
        inst:DoTaskInTime(CLEAR_DELAY, ClearRecentlyCharged, other)
        --inst.SoundEmitter:PlaySound("dontstarve/creatures/rook/explo")
        inst.components.combat:DoAttack(other)
        other:PushEvent("knockback", { knocker = inst, radius = 1.5, strengthmult = 1.5, forcelanded = true })
    end
end

local NO_COLLIDE_TAGS = {"shadow", "shadowminion", "shadowchesspiece", "stalker", "stalkerminion", "shadowthrall"}
local COLLAPSE_DELAY = 2 * FRAMES
local function OnCollide(inst, other)
    if other ~= nil and
        other:IsValid() and
        not RECENTLY_CHARGED[other] and
        not other:HasAnyTag(NO_COLLIDE_TAGS) and
        inst.components.locomotor:GetTimeMoving() >= MOVING_DELAY and
        Vec3Util_LengthSq(inst.Physics:GetVelocity()) >= 4 then

        inst:DoTaskInTime(COLLAPSE_DELAY, OnOtherCollide, other)
    end
end

local function DisplayNameFn(inst)
	return ThePlayer ~= nil and ThePlayer:HasTag("player_shadow_aligned") and STRINGS.NAMES.SHADOWTHRALL_CENTIPEDE_ALLEGIANCE or nil
end

local function SetBackwardsLocomotion(inst, bool)
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "backwards_locomote", bool and -1 or 1)
end

local function IsBackwardsLocomoting(inst)
    return inst.components.locomotor:GetExternalSpeedMultiplier(inst, "backwards_locomote") == -1
end

local function DamageRedirectFn(inst, attacker, damage, weapon, stimuli)
    if inst.controller and inst.controller.head ~= nil then
        inst.controller.head:PushEvent("attacked")
    end

    return inst.controller ~= nil and inst.controller:IsValid() and inst.controller or nil
end

local function TeleportOverrideFn(inst) --Sorry! No teleporting! We're not dealing with that.
	return inst:GetPosition()
end

local function OnBlocked(inst, data)
    inst.SoundEmitter:PlaySound("daywalker/pillar/pickaxe_hit_unbreakable")

    if data.spdamage then
        --inst.SoundEmitter:PlaySound("daywalker/pillar/chain_rattle_1", "vibrate_loop") --TODO KILL THIS SOUND IF WE DO USE IT
        --inst.test_task = inst:DoTaskInTime(1, function() inst.SoundEmitter:KillSound("vibrate_loop") end)
    elseif data.damage then

    end

end

local function OnBrokeRockTree(inst)
    local controlling_head = inst.controller and inst.controller.components.centipedebody:GetControllingHead()
    if controlling_head then
        controlling_head:PushEvent("start_struggle")
    end
end

local function IsFlipped(inst) -- For second head
    return inst.flipped
end

local SPIKE_SYMBOLS = {
    "spikeA",
    "spikeB",
    "spikeC",
}
local function SetSpikeVariation(inst, variation)
    variation = variation or math.random(#SPIKE_SYMBOLS)
    inst.spike_variation = variation

    for i = 1, #SPIKE_SYMBOLS do
        local layer = SPIKE_SYMBOLS[i]
        if i ~= inst.spike_variation then
            inst.AnimState:Hide(layer)
        else
            inst.AnimState:Show(layer)
        end
    end
end

local function OnSave(inst, data)
    if inst.spike_variation then
        data.spike_variation = inst.spike_variation
    end
end

local function OnLoad(inst, data)
    if data then
        if data.spike_variation then
            SetSpikeVariation(inst, data.spike_variation)
        end
    end
end

local function GetStatus(inst)
    return inst.sg:HasStateTag("struggling") and "FLIPPED"
        or inst:HasTag("centipede_head") and "HEAD"
        or "BODY"
end

local PRIORITY_BEHAVIOURS = {
    RUN_AWAY    = 3,
    CHARGING    = 2,
    EATING      = 1,
    WANDERING   = 0,
    STUCK       = -1, --For when we can't even find a good spot to wander to, set ourselves lower and pray the other head can find a way out
}
--TODO heal on eating
local S = 1.0
local DIET = { FOODTYPE.MIASMA }
local RECOIL_EFFECT_OFFSET = Vector3(0, 1.5, 0)
local function commonfn(data)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeGiantCharacterPhysics(inst, data.MASS, 1.5)
    inst.Physics:SetDontRemoveOnSleep(true) --It's a massive obstacle!

    inst.Transform:SetEightFaced()
    inst.Transform:SetScale(S, S, S)
    inst.DynamicShadow:SetSize(4, 2.5)

    inst.AnimState:SetBank(data.BANK)
    inst.AnimState:SetBuild("shadow_thrall_centipede_head")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetSymbolLightOverride("RED_head", 1)
	inst.AnimState:SetSymbolLightOverride("RED_head_horns", 1)
	inst.AnimState:SetSymbolLightOverride("RED_shell_part", 1)
	inst.AnimState:SetSymbolLightOverride("RED_spikes", 1)

    inst:AddTag("shadow_aligned")
    inst:AddTag("shadowthrall")
    inst:AddTag("scarytoprey")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("largecreature")
    inst:AddTag("shadowthrall_centipede")
    inst:AddTag("quakeimmune")
    inst:AddTag("groundpound_immune")
    inst:AddTag("quakebreaker")
    inst:AddTag("toughworker")
    inst:AddTag("tree_rock_breaker")
    if data.TAG then
        inst:AddTag(data.TAG)
    end

    inst:SetPrefabNameOverride("shadowthrall_centipede")

    inst.displaynamefn = DisplayNameFn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        --inst.Physics:SetCollides(false)
        return inst
    end

    inst.Physics:SetCollisionCallback(OnCollide)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("health")
    inst.components.health:SetInvincible(true)

    inst:AddComponent("combat")
    inst.components.combat:SetRequiresToughCombat(true)
    inst.components.combat:SetHurtSound("rifts6/creatures/centipede/vocalization")
    inst.components.combat:SetDefaultDamage(TUNING.SHADOWTHRALL_CENTIPEDE.DAMAGE)
    inst.components.combat.playerdamagepercent = TUNING.SHADOWTHRALL_CENTIPEDE.PLAYERDAMAGEPERCENT --NOTE: This does not apply to special damage! (e.g. planar)
    inst.components.combat.redirectdamagefn = DamageRedirectFn
    inst.components.combat.noimpactsound = true
    --inst.components.combat:SetRetargetFunction(1, RetargetFn)
    --inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet(DIET, DIET)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("shadowthrall_centipede_head")

    inst:AddComponent("planarentity")

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.SHADOWTHRALL_CENTIPEDE.PLANAR_DAMAGE)

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.SHADOWTHRALL_CENTIPEDE.MOVESPEED
    inst.components.locomotor.runspeed = TUNING.SHADOWTHRALL_CENTIPEDE.RUNSPEED

    inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(TeleportOverrideFn)

    inst:AddComponent("sanityaura") --TODO we might want the entire centipede to be treated as one sanity aura, so it's not super multiplicative if many segments are close?
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    inst:AddComponent("drownable")
    inst:AddComponent("timer")

    inst:SetStateGraph("SGshadowthrall_centipede")

    inst.SetBackwardsLocomotion = SetBackwardsLocomotion
    inst.IsBackwardsLocomoting = IsBackwardsLocomoting
    inst.IsFlipped = IsFlipped
    inst.rot = 0 --TODO

    inst.recoil_effect_offset = RECOIL_EFFECT_OFFSET

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    SetSpikeVariation(inst)

    inst:ListenForEvent("blocked", OnBlocked)
    inst:ListenForEvent("broke_tree_rock", OnBrokeRockTree)

    MakeHauntable(inst)

    return inst
end

local HEAD_DATA = {
    MASS = 10000,
    BANK = "shadow_thrall_centipede_head",
    TAG = "centipede_head",
}

local function PlayIdleSound(inst)
    inst.SoundEmitter:PlaySound("rifts6/creatures/centipede/idle_LP", "centipede_idle")
end
local function headfn()
    local inst = commonfn(HEAD_DATA)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "scrapbook"

    --TODO do sleep and create a number of segments when waking as simulation of how much miasma we've eaten
    inst:SetBrain(head_brain)

    inst.miasma_counter = 0 --Resets after slurping up 3
    inst.PRIORITY_BEHAVIOURS = PRIORITY_BEHAVIOURS
    inst.control_priority = PRIORITY_BEHAVIOURS.WANDERING

    inst.PlayHeadIdleSound = PlayIdleSound
    inst:DoTaskInTime(0, inst.PlayHeadIdleSound)

    return inst
end

local BODY_DATA = {
    MASS = 1000,
    BANK = "shadow_thrall_centipede_body",
    TAG = "centipede_body",
}
local function torsofn()
    local inst = commonfn(BODY_DATA)
    inst.scrapbook_proxy = "shadowthrall_centipede_head"

    return inst
end

-------------- The controller --------------------

local controller_brain = require("brains/shadowthrall_centipede_controller_brain")

local function SpawnSegments(inst)
    inst.components.centipedebody:CreateFullBody()
    inst.spawn_segments_task = nil
end

local function SpawnPlanarEffectOn(inst, attacker) -- Because our controller is the thing that gets attacked technically, but we want the planar effect on the segment the player actually attacked
    return inst.components.combat.redirected_from -- Set in combat:GetAttacked
end

local function OnDeath(inst)
    local function OnBodyDeath(body)
        body.components.health:ForceKill() --To bypass invincible
    end
    inst.components.centipedebody:ForEachSegment(OnBodyDeath)
end

local function controller_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    --inst.persists = false

    inst:AddTag("NOCLICK")
    inst:AddTag("INLIMBO")
    inst:AddTag("NOBLOCK")
    inst:AddTag("groundpound_immune")
    inst:AddTag("shadow_aligned")
    inst:AddTag("shadowthrall")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("shadowthrall_centipede_controller")

    inst:AddComponent("knownlocations")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.SHADOWTHRALL_CENTIPEDE.HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst.components.combat:SetRequiresToughCombat(true)
    inst.components.combat.noimpactsound = true
    --inst.components.combat:SetDefaultDamage(TUNING.WORM_BOSS_DAMAGE) --Not needed?
    --inst.components.combat:SetRetargetFunction(1, RetargetFn)
    --inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst:AddComponent("planarentity")
    inst.components.planarentity.spawn_effect_on = SpawnPlanarEffectOn

    inst:AddComponent("centipedebody")
    inst.components.centipedebody.turnspeed = TUNING.SHADOWTHRALL_CENTIPEDE.TURNSPEED
    inst.components.centipedebody.max_torso = TUNING.SHADOWTHRALL_CENTIPEDE.MAX_SEGMENTS

    inst:SetBrain(controller_brain)

    inst:ListenForEvent("death", OnDeath)

    inst.PRIORITY_BEHAVIOURS = PRIORITY_BEHAVIOURS

    if not POPULATING then
        inst.spawn_segments_task = inst:DoTaskInTime(0, SpawnSegments)
    end

    return inst
end

--

--TODO THIS IS TEMPORARY
--#DELETEME
local function temp_spawnerfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst:AddTag("NOBLOCK")
    inst:AddTag("NOCLICK")
    inst:AddTag("TEMP_centipede_spawner")
    inst:AddTag("ignorewalkableplatforms")
	inst:AddTag("ignorewalkableplatformdrowning")

    local function CheckSpawnStatus()
        if inst:IsAsleep() then
            if inst.ready_to_spawn then
                SpawnAt("shadowthrall_centipede_controller", inst:GetPosition())
                inst.ready_to_spawn = nil
            elseif inst.ready_to_despawn then
                local centipede_controller = TheSim:FindFirstEntityWithTag("shadowthrall_centipede_controller")
                if centipede_controller then
                    centipede_controller:Remove()
                end
                inst.ready_to_despawn = nil
            end
        end
    end

    local function OnSpawnSave(inst, data)
        data.ready_to_spawn = inst.ready_to_spawn
        data.ready_to_despawn = inst.ready_to_despawn
    end

    local function OnSpawnLoad(inst, data)
        if data then
            inst.ready_to_spawn = data.ready_to_spawn
            inst.ready_to_despawn = data.ready_to_despawn
        end
    end

    local riftspawner = TheWorld.components.riftspawner

    local function OnRift()
        local centipede_controller = TheSim:FindFirstEntityWithTag("shadowthrall_centipede_controller")
		if riftspawner:IsShadowPortalActive() then
			if not centipede_controller then
                inst.ready_to_spawn = true
                CheckSpawnStatus()
            end
		elseif centipede_controller then
			inst.ready_to_despawn = true
            CheckSpawnStatus()
		end
    end

    inst.OnEntitySleep = CheckSpawnStatus

    inst.OnSave = OnSpawnSave
    inst.OnLoad = OnSpawnLoad

    if riftspawner then
        inst:ListenForEvent("ms_riftaddedtopool", OnRift, TheWorld)
	    inst:ListenForEvent("ms_riftremovedfrompool", OnRift, TheWorld)
    end

    return inst
end

return Prefab("shadowthrall_centipede_controller", controller_fn, nil, controller_prefabs),
    Prefab("shadowthrall_centipede_head", headfn, assets, head_prefabs),
    Prefab("shadowthrall_centipede_body", torsofn, assets, torso_prefabs),
    --#DELETEME
    Prefab("shadowthrall_centipede_spawner", temp_spawnerfn)