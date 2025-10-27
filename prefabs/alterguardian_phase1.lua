local assets =
{
    Asset("ANIM", "anim/alterguardian_phase1.zip"),
    Asset("ANIM", "anim/alterguardian_spawn_death.zip"),
}

local assets_rift =
{
	Asset("ANIM", "anim/alterguardian_phase1.zip"),
	Asset("ANIM", "anim/alterguardian_spawn_death.zip"),
	Asset("ANIM", "anim/alterguardian_phase1_lunar.zip"), -- New death anims
	Asset("ANIM", "anim/alterguardian_phase1_lunarrift.zip"), -- New build w/ lunar crystals
}

local assets_riftgestalt =
{
	Asset("ANIM", "anim/alterguardian_phase1_lunar.zip"), -- New death anims
	Asset("ANIM", "anim/wagboss_lunar.zip"),
}

local prefabs =
{
    "alterguardian_phase2",
    "alterguardian_summon_fx",
    "gestalt_alterguardian_projectile",
    "mining_moonglass_fx",
    "moonrocknugget",
}

local prefabs_rift =
{
	"mining_moonglass_fx",
	"moonrocknugget",
	"alterguardian_phase1_lunarrift_gestalt",
}

SetSharedLootTable("alterguardian_phase1",
{
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      1.00},
    {"moonrocknugget",      0.66},
    {"moonrocknugget",      0.66},
})

local brain = require "brains/alterguardian_phase1brain"

--MUSIC------------------------------------------------------------------------
local function PushMusic(inst)
    if ThePlayer == nil or inst:HasTag("nomusic") then
        inst._playingmusic = false
    elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
        inst._playingmusic = true
        ThePlayer:PushEvent("triggeredevent", { name = "alterguardian_phase1", duration = 2 })
    elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
        inst._playingmusic = false
    end
end

local function OnMusicDirty(inst)
    if not TheNet:IsDedicated() then
        if inst._musictask ~= nil then
            inst._musictask:Cancel()
        end
        inst._musictask = inst:DoPeriodicTask(1, PushMusic)
        PushMusic(inst)
    end
end

local function SetNoMusic(inst, val)
    inst:AddOrRemoveTag("nomusic", val)
    inst._musicdirty:push()
    OnMusicDirty(inst)
end
--MUSIC------------------------------------------------------------------------

local function play_custom_hit(inst)
    if not inst.components.timer:TimerExists("hitsound_cd") then
        if inst._is_shielding then
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/hit")
        else
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/onothercollide")
        end

        inst.components.timer:StartTimer("hitsound_cd", 5*FRAMES)
    end
end

local TARGET_DIST = TUNING.ALTERGUARDIAN_PHASE1_TARGET_DIST
local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "playerghost" }
local RETARGET_ONEOF_TAGS = { "character", "monster", "shadowminion" }
local function Retarget(inst)
    local gx, gy, gz = inst.Transform:GetWorldPosition()
    local potential_targets = TheSim:FindEntities(
        gx, gy, gz, TARGET_DIST,
        RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS
    )

    local newtarget = nil
    for _, target in ipairs(potential_targets) do
        if target ~= inst and target.entity:IsVisible()
                and inst.components.combat:CanTarget(target)
                and target:IsOnValidGround() then
            newtarget = target
            break
        end
    end

    if newtarget ~= nil and newtarget ~= inst.components.combat.target then
        return newtarget, true
    else
        return nil
    end
end

local MAX_CHASEAWAY_DIST_SQ = 625 --25 * 25
local function KeepTarget(inst, target)
    return inst.components.combat:CanTarget(target) and target:IsOnValidGround()
            and target:GetDistanceSqToPoint(inst.Transform:GetWorldPosition()) < MAX_CHASEAWAY_DIST_SQ
end

local function teleport_override_fn(inst)
    local ipos = inst:GetPosition()
    local offset = FindWalkableOffset(ipos, TWOPI*math.random(), 10, 8, true, false)
        or FindWalkableOffset(ipos, TWOPI*math.random(), 14, 8, true, false)

    return (offset ~= nil and ipos + offset) or ipos
end

local function OnAttacked(inst, data)
	inst.components.health:RemoveRegenSource(inst, "lunarriftregen")
    inst.components.combat:SuggestTarget(data.attacker)
    play_custom_hit(inst)
end

local function OnPhaseTransition(inst)
    local px, py, pz = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    local target = inst.components.combat.target

    inst:Remove()

    local phase2 = SpawnPrefab("alterguardian_phase2")
    phase2.Transform:SetPosition(px, py, pz)
    phase2.Transform:SetRotation(rot)
    phase2.AnimState:MakeFacingDirty() --not needed for clients
    phase2.components.combat:SuggestTarget(target)
    phase2.sg:GoToState("spawn")
end

local function onothercollide(inst, other)
    if not other:IsValid() then
        return

    elseif other:HasTag("smashable") and other.components.health ~= nil then
        other.components.health:Kill()

    elseif other.components.workable ~= nil
            and other.components.workable:CanBeWorked()
            and other.components.workable.action ~= ACTIONS.NET then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)

	elseif other.components.combat ~= nil
		and other.components.health ~= nil and not other.components.health:IsDead()
		and (other:HasTag("wall") or other:HasTag("structure"))
		then
        inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/onothercollide")
        inst.components.combat:DoAttack(other)
    end
end

local COLLISION_DSQ = 42
local function oncollide(inst, other)
    if inst._collisions[other] == nil and other ~= nil and other:IsValid()
            and Vector3(inst.Physics:GetVelocity()):LengthSq() > COLLISION_DSQ then
        ShakeAllCameras(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
        inst:DoTaskInTime(2 * FRAMES, onothercollide, other)
        inst._collisions[other] = true
    end
end

local function EnableRollCollision(inst, enable)
    if enable then
        inst.Physics:SetCollisionCallback(oncollide)
        inst._collisions = {}
    else
        inst.Physics:SetCollisionCallback(nil)
        inst._collisions = nil
    end
end

local function find_gestalt_target(gestalt)
    local gx, gy, gz = gestalt.Transform:GetWorldPosition()
    local target = nil
    local rangesq = 36
    for _, v in ipairs(AllPlayers) do
        if not IsEntityDeadOrGhost(v) and
                not (v.sg:HasStateTag("knockout") or
                    v.sg:HasStateTag("sleeping") or
                    v.sg:HasStateTag("bedroll") or
                    v.sg:HasStateTag("tent") or
                    v.sg:HasStateTag("waking")) and
                v.entity:IsVisible() then

            local distsq = v:GetDistanceSqToPoint(gx, 0, gz)
            if distsq < rangesq then
                rangesq = distsq
                target = v
            end
        end
    end

    return target
end

local MIN_GESTALTS, MAX_GESTALTS = 6, 10
local EXTRA_GESTALTS_BYHEALTH = 12
local MIN_SUMMON_RANGE, MAX_SUMMON_RANGE = 5, 7
local function DoGestaltSummon(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()

    local spawn_warning = SpawnPrefab("alterguardian_summon_fx")
    spawn_warning.Transform:SetScale(1.2, 1.2, 1.2)
    spawn_warning.Transform:SetPosition(ix, iy, iz)

    -- A random amount of spawns plus a base amount based on missing health.
    local num_gestalts = GetRandomMinMax(MIN_GESTALTS, MAX_GESTALTS) + math.ceil((1 - inst.components.health:GetPercent()) * EXTRA_GESTALTS_BYHEALTH)

    local angle_increment = 3.75*PI / num_gestalts -- almost 2pi twice; loop 2 times, but slightly offset
    local initial_angle = TWOPI*math.random()

    for i = 1, num_gestalts do
        -- Spawn a collection of gestalts in a haphazard ring around the boss.
        -- The gestalts are undirected, but will target somebody if they're nearby.

        inst:DoTaskInTime(2.0 + (i*4*FRAMES), function(inst2)
            local gestalt = SpawnPrefab("gestalt_alterguardian_projectile")
            if gestalt ~= nil then
                -- NOTE: Deliberately not square rooting this radius;
                -- clustering closer to the boss is fine behaviour.
                local r = GetRandomMinMax(MIN_SUMMON_RANGE, MAX_SUMMON_RANGE)
                local angle = initial_angle + GetRandomWithVariance((i - 1) * angle_increment, PI/8)
                local x, z = r * math.cos(angle), r * math.sin(angle)

                gestalt.Transform:SetPosition(ix + x, iy + 0, iz + z)

                local target = find_gestalt_target(gestalt)
                if target ~= nil then
                    gestalt:ForceFacePoint(target:GetPosition())
                    gestalt:SetTargetPosition(target:GetPosition())
                end
            end
        end)
    end

    inst:DoTaskInTime(2.0 + (num_gestalts*4*FRAMES) + 1.0, function(inst2)
        spawn_warning:PushEvent("endloop")
    end)

    inst.components.timer:StartTimer("summon_cooldown", TUNING.ALTERGUARDIAN_PHASE1_SUMMONCOOLDOWN)
end

local function EnterShield(inst)
    inst._is_shielding = true

    inst.components.health:SetAbsorptionAmount(TUNING.ALTERGUARDIAN_PHASE1_SHIELDABSORB)

    if not inst.components.timer:TimerExists("summon_cooldown") then
        DoGestaltSummon(inst)
    end
end

local function ExitShield(inst)
    inst._is_shielding = nil

    inst.components.health:SetAbsorptionAmount(0)
end

local function CalcSanityAura(inst, observer)
    return (inst.components.combat.target ~= nil and TUNING.SANITYAURA_HUGE) or TUNING.SANITYAURA_LARGE
end

local function OnSave(inst, data)
    data.loot_dropped = inst._loot_dropped
    local current_state_name = inst.sg.currentstate.name
    data.prespawn_idling = (current_state_name == "prespawn_idle")
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst._loot_dropped = data.loot_dropped
        if data.prespawn_idling then
            inst.sg:GoToState("prespawn_idle")
        end
    end
end

local function OnEntitySleep(inst)
    if inst.components.health:IsDead() then
        return
    end

    -- If we're hurt, set a time so that, when we wake up, we can regain health.
    if inst.components.health:IsHurt() then
        inst._start_sleep_time = GetTime()
    end
end

local HEALTH_GAIN_RATE = TUNING.ALTERGUARDIAN_PHASE1_HEALTH / (TUNING.TOTAL_DAY_TIME * 5)
local function gain_sleep_health(inst)
    local time_diff = GetTime() - inst._start_sleep_time
    if time_diff > 0.0001 then
        inst.components.health:DoDelta(HEALTH_GAIN_RATE * time_diff)
    end
end

local function OnEntityWake(inst)
    -- If a sleep time was set, gain health as appropriate.
    if inst._start_sleep_time ~= nil then
        gain_sleep_health(inst)

        inst._start_sleep_time = nil
    end
end

local function inspect_boss(inst)
    return (inst.sg:HasStateTag("dead") and "DEAD") or nil
end

local function on_timer_finished(inst, data)
    if data.name == "summon_cooldown" then
        if inst._is_shielding then
            DoGestaltSummon(inst)
        end
    elseif data.name == "gotospawn" then
        inst:PushEvent("startspawnanim")
    end
end

local scrapbook_adddeps = {
    "moonglass",
    "moonglass_charged",
    "alterguardianhat",
    "alterguardianhatshard",
}

local BURN_OFFSET = Vector3(0, 1.5, 0)
local function commonfn(common_postinit, server_postinit)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.Transform:SetFourFaced()

    inst.DynamicShadow:SetSize(5.00, 1.50)

    inst.AnimState:SetBank("alterguardian_phase1")

    MakeGiantCharacterPhysics(inst, 500, 1.25)

    inst:AddTag("brightmareboss")
    inst:AddTag("epic")
    inst:AddTag("hostile")
    inst:AddTag("largecreature")
    inst:AddTag("mech")
    inst:AddTag("monster")
    inst:AddTag("noepicmusic")
    inst:AddTag("scarytoprey")
    inst:AddTag("soulless")
    inst:AddTag("lunar_aligned")

    inst._musicdirty = net_event(inst.GUID, "alterguardian_phase1._musicdirty", "musicdirty")
    inst._playingmusic = false
    --inst._musictask = nil
    OnMusicDirty(inst)

	if common_postinit then
		common_postinit(inst)
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("musicdirty", OnMusicDirty)

        return inst
    end

    WORLDSTATETAGS.SetTagEnabled("CELESTIAL_ORB_FOUND", true) -- Will drop when the boss is fully defeated.

    inst.scrapbook_adddeps = scrapbook_adddeps

    inst.scrapbook_damage = { TUNING.ALTERGUARDIAN_PHASE1_ROLLDAMAGE, TUNING.ALTERGUARDIAN_PHASE3_DAMAGE }
    inst.scrapbook_maxhealth = TUNING.ALTERGUARDIAN_PHASE1_HEALTH + TUNING.ALTERGUARDIAN_PHASE2_STARTHEALTH + TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH

    --inst._loot_dropped = nil      -- For handling save/loads during death; see SGalterguardian_phase1

    inst.EnableRollCollision = EnableRollCollision
    inst.EnterShield = EnterShield
    inst.ExitShield = ExitShield
    inst.SetNoMusic = SetNoMusic

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.ALTERGUARDIAN_PHASE1_WALK_SPEED

    inst:SetStateGraph("SGalterguardian_phase1")
    inst:SetBrain(brain)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.ALTERGUARDIAN_PHASE1_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE1_ROLLDAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.ALTERGUARDIAN_PHASE1_ATTACK_PERIOD)
    inst.components.combat:SetRange(15, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
    inst.components.combat:SetRetargetFunction(3, Retarget)
    inst.components.combat:SetKeepTargetFunction(KeepTarget)
    inst.components.combat.playerdamagepercent = TUNING.ALTERGUARDIAN_PLAYERDAMAGEPERCENT
    inst.components.combat.noimpactsound = true
    inst:ListenForEvent("blocked", play_custom_hit)

    inst:AddComponent("explosiveresist")

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aurafn = CalcSanityAura
    inst.components.sanityaura.max_distsq = 225

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("alterguardian_phase1")
    inst.components.lootdropper.min_speed = 4.0
    inst.components.lootdropper.max_speed = 6.0
    inst.components.lootdropper.y_speed = 14
    inst.components.lootdropper.y_speed_variance = 2

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = inspect_boss

    inst:AddComponent("knownlocations")

    inst:AddComponent("timer")
    inst.components.timer:StartTimer("roll_cooldown", TUNING.ALTERGUARDIAN_PHASE1_ROLLCOOLDOWN)
    --inst.components.timer:StartTimer("summon_cooldown", TUNING.ALTERGUARDIAN_PHASE1_SUMMONCOOLDOWN)
    --inst.components.timer:StartTimer("gotospawn", N_A)
    inst:ListenForEvent("timerdone", on_timer_finished)

    inst:AddComponent("teleportedoverride")
    inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

    inst:AddComponent("drownable")

	inst:AddComponent("hauntable")
	inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("phasetransition", OnPhaseTransition)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

	if server_postinit then
		server_postinit(inst)
	end

    return inst
end

--------------------------------------------------------------------------

local function common_postinit_basic(inst)
	inst.AnimState:SetBuild("alterguardian_phase1")
end

local function server_postinit_basic(inst)
	inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_LP", "idle_LP")
end

local function fn()
	return commonfn(common_postinit_basic, server_postinit_basic)
end

--------------------------------------------------------------------------

local function CreatePlanarFx()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("alterguardian_phase1")
	inst.AnimState:SetBuild("alterguardian_phase1_lunarrift")
	inst.AnimState:PlayAnimation("planar_loop", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.5)

	return inst
end

local function rift_OnAddColourChanged(inst, r, g, b, a)
	inst.fx.AnimState:SetAddColour(r, g, b, a)
end

local function rift_OnCameraFocusDirty(inst)
	if inst.camerafocus:value() then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 3, 20, 3)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function rift_EnableCameraFocus(inst, enable)
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			rift_OnCameraFocusDirty(inst)
		end
	end
end

local function common_postinit_rift(inst)
    inst.entity:AddLight()
    inst.Light:SetIntensity(0)
    inst.Light:SetRadius(0)
    inst.Light:SetFalloff(0)
    inst.Light:SetColour(0, 0.35, 1)

	inst.AnimState:SetBuild("alterguardian_phase1_lunarrift")
	inst.AnimState:SetSymbolBloom("fx_white")
	inst.AnimState:SetSymbolLightOverride("fx_white", 0.5)
	inst.AnimState:SetSymbolLightOverride("moonglass_parts", 0.1)
	inst.AnimState:SetSymbolLightOverride("moonglass_parts2", 0.1)
    inst.AnimState:SetLightOverride(0)

	inst.camerafocus = net_bool(inst.GUID, "alterguardian_phase1_lunarrift.camerafocus", "camerafocusdirty")

	inst:AddComponent("colouraddersync")

	if not TheNet:IsDedicated() then
		--NOTE: this one fx, will render at multiple follow symbols in sync, which is ok.
		inst.fx = CreatePlanarFx()
		inst.fx.entity:SetParent(inst.entity)
		inst.fx.Follower:FollowSymbol(inst.GUID, "fx_planar_follow", nil, nil, nil, true)

		inst.highlightchildren = { inst.fx }

		inst.components.colouraddersync:SetColourChangedFn(rift_OnAddColourChanged)
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("camerafocusdirty", rift_OnCameraFocusDirty)
	end
end

local function rift_OnSave(inst, data)
    data.is_spawning = inst.sg:HasStateTag("spawn_lunar")
end

local function rift_OnLoad(inst, data)
	OnLoad(inst, data)
	if inst.components.health.currenthealth <= inst.components.health.minhealth and not inst.sg:HasStateTag("dead") then
		inst.sg:GoToState("death_lunar_loop")
    elseif data.is_spawning then
        inst.sg:GoToState("spawn_lunar")
	end
end

local function rift_OnRemoveEntity(inst)
	if inst.sg.statemem.gestalt then
		inst.sg.statemem.gestalt:Remove()
	end
end

local function server_postinit_rift(inst)
	inst:AddComponent("planarentity")
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_PLANAR_DAMAGE)

	inst.components.health:SetMaxHealth(TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_HEALTH)
    -- We regenerate from death, so...
	inst.components.health:SetMinHealth(1)

	inst:AddComponent("colouradder")

	inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_wagboss_LP", "idle_LP")

	inst.EnableCameraFocus = rift_EnableCameraFocus
    inst.OnSave = rift_OnSave
	inst.OnLoad = rift_OnLoad
	inst.OnRemoveEntity = rift_OnRemoveEntity
end

local function riftfn()
	return commonfn(common_postinit_rift, server_postinit_rift)
end

--------------------------------------------------------------------------

local function riftgestalt_OnCaptured(inst)
	if inst.PARENT then
		inst.PARENT.perists = false
		inst.PARENT.sg:GoToState("captured")
	end
end

local function riftgestalt_OnRemoveEntity(fx)
	table.removearrayvalue(fx.highlightparent.highlightchildren, fx)
end

local function riftgestalt_AddFollowFx(inst, anim, symbol)
	local fx = CreateEntity()

	fx:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("wagboss_lunar")
	fx.AnimState:SetBuild("wagboss_lunar")
	fx.AnimState:PlayAnimation(anim, true)
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	fx.AnimState:SetMultColour(1, 1, 1, 0.5)
	fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
	fx.AnimState:SetLightOverride(0.5)

	fx.entity:SetParent(inst.entity)
	fx.Follower:FollowSymbol(inst.GUID, symbol, nil, nil, nil, true)

	table.insert(inst.highlightchildren, fx)
	fx.highlightparent = inst
	fx.OnRemoveEntity = riftgestalt_OnRemoveEntity
end

local SCRAPBOOK_OVERRIDEBUILDS = {"alterguardian_phase1_lunar", "wagboss_lunar"}
local SCRAPBOOK_SYMBOLCOLOURS = { 
    {"lb_glow", 1, 1, 1, 0.375},
    {"scrapbook_art", 1, 1, 1, 0.75},
    {"lb_flame_loop", 1, 1, 1, 0.75}, 
}
local function riftgestaltfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.Transform:SetFourFaced()
	inst.AnimState:SetBank("alterguardian_phase1")
	inst.AnimState:SetBuild("wagboss_lunar")
	inst.AnimState:PlayAnimation("collapse_pre")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetMultColour(1, 1, 1, 0.5)
	inst.AnimState:SetLightOverride(0.5)
	inst.AnimState:UsePointFiltering(true)

	inst:AddTag("brightmare")
	inst:AddTag("lunar_aligned")
	inst:AddTag("NOCLICK")
	inst:AddTag("nointerpolate")

	inst.no_wet_prefix = true

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.highlightchildren = {}

		--from alterguardian_phase4_lunarrift
		riftgestalt_AddFollowFx(inst, "flame_loop", "lb_flame_loop_follow_1")
		riftgestalt_AddFollowFx(inst, "body_loop", "lb_head_loop_follow_2")
		riftgestalt_AddFollowFx(inst, "body_loop", "lb_head_loop_follow_3")
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_bank = "alterguardian_phase1"
	inst.scrapbook_build = "alterguardian_phase1_lunarrift"
    inst.scrapbook_overridebuild = SCRAPBOOK_OVERRIDEBUILDS
    inst.scrapbook_symbolcolours = SCRAPBOOK_SYMBOLCOLOURS
    inst.scrapbook_anim = "scrapbook"

	inst:AddComponent("inspectable")

	inst:AddComponent("gestaltcapturable")
	inst.components.gestaltcapturable:SetLevel(3)
	inst.components.gestaltcapturable:SetOnCapturedFn(riftgestalt_OnCaptured)
	inst.components.gestaltcapturable:SetEnabled(false)

	--inst.PARENT --set by SGalterguardian_phase1.lua
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("alterguardian_phase1", fn, assets, prefabs),
	Prefab("alterguardian_phase1_lunarrift", riftfn, assets_rift, prefabs_rift),
	Prefab("alterguardian_phase1_lunarrift_gestalt", riftgestaltfn, assets_riftgestalt)
