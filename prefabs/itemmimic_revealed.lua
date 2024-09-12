local assets =
{
	Asset("ANIM", "anim/item_mimic_reveal.zip"),
    Asset("SCRIPT", "scripts/prefabs/itemmimic_data.lua"),
}

local prefabs =
{
    "itemmimic_puff",
    "itemmimic_revealed_shadow",
	"nightmarefuel",
}

local sg = "SGitemmimic_revealed"
local brain = require("brains/itemmimic_revealedbrain")
local LOOT = { "nightmarefuel" }

local function on_eye_up(inst)
    if not inst.components.health:IsDead() then
        inst.AnimState:PlayAnimation("eye_appear")
        inst.AnimState:PushAnimation("eye_idle")

        inst.SoundEmitter:PlaySound("rifts4/mimic/eye_peek")
    end
end

local function on_eye_down(inst)
    inst.AnimState:PlayAnimation("eye_disappear")
    inst.AnimState:PushAnimation("empty", false)
end

local function DisperseFromBeingSteppedOn(inst, player)
    inst.components.health:Kill()

    if player ~= nil then
        player:PushEvent("killed", {victim = inst, attacker = player})
    end
end

local function toggle_tail(inst)
    if inst._shadow_tail then
        inst._shadow_tail._disabled = not inst._shadow_tail._disabled
    end
end

local function on_death(inst, data)
    inst._toggle_tail_event:push()
end

local function on_jump_spawn(inst)
    if not inst.components.timer:TimerExists("recently_spawned") then
        inst.components.timer:StartTimer("recently_spawned", 5)
    end
end

local function on_timer_done(inst, data)
    if data.name == "stepping_delay" then
        inst.components.playerprox:SetOnPlayerNear(DisperseFromBeingSteppedOn)
    end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

    local Physics = inst.entity:AddPhysics()
    Physics:SetMass(10)
    Physics:SetFriction(0)
    Physics:SetDamping(5)
    Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    Physics:ClearCollisionMask()
    Physics:SetCollisionMask(COLLISION.WORLD, COLLISION.SANITY)
    Physics:SetCapsule(0.5, 1.0)

	inst:AddTag("shadowcreature")
	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("shadow")
	inst:AddTag("notraptrigger")
	inst:AddTag("shadow_aligned")

    inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("item_mimic_reveal")
	inst.AnimState:SetBuild("item_mimic_reveal")
	inst.AnimState:PlayAnimation("empty", true)
	inst.AnimState:SetMultColour(1, 1, 1, .75)
	inst.AnimState:UsePointFiltering(true)

    inst._toggle_tail_event = net_event(inst.GUID, "itemmimic_revealed.toggle_tail_event")

    if not TheNet:IsDedicated() then
        inst._shadow_tail = SpawnPrefab("itemmimic_revealed_shadow")
        inst:AddChild(inst._shadow_tail)
        inst._shadow_tail.Transform:SetPosition(0,0,0)
        inst._shadow_tail.Transform:SetRotation(0)
        inst._shadow_tail.entity:SetAABB(0.5, 2)

        inst:ListenForEvent("itemmimic_revealed.toggle_tail_event", toggle_tail)
    end

	inst.entity:SetPristine()
	if not TheWorld.ismastersim then
		return inst
	end

    inst.scrapbook_anim = "eye_idle"
    inst.scrapbook_inspectonseen = true

    --
    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.SHADOW_LEECH_HEALTH)

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor.runspeed = TUNING.SHADOW_LEECH_RUNSPEED
    locomotor:SetTriggersCreep(false)
    locomotor.pathcaps = { ignorecreep = true }

    --
    local lootdropper = inst:AddComponent("lootdropper")
    lootdropper:SetLoot(LOOT)

    --
    local playerprox = inst:AddComponent("playerprox")
    playerprox:SetDist(1.0, 2.5)

    --
    local sanityaura = inst:AddComponent("sanityaura")
    sanityaura.aura = -TUNING.SANITYAURA_SMALL

    --
    local timer = inst:AddComponent("timer")
    timer:StartTimer("mimic_blocker", 5)
    timer:StartTimer("stepping_delay", 35*FRAMES)

    --
    inst:ListenForEvent("eye_up", on_eye_up)
    inst:ListenForEvent("eye_down", on_eye_down)
    inst:ListenForEvent("death", on_death)
    inst:ListenForEvent("timerdone", on_timer_done)
    inst:ListenForEvent("jump", on_jump_spawn)

    --
    inst:SetStateGraph(sg)
    inst:SetBrain(brain)

    --
    return inst
end

-- VFX TAIL/SHADOW?
local SHADOW_TEXTURE = "images/shadow.tex" --"fx/pixel.tex"
local SHADOW_SHADER = "shaders/vfx_particle.ksh"

local SHADOW_COLOUR_ENVELOPE_NAME = "itemmimicshadowcolourenvelope"
local SHADOW_SCALE_ENVELOPE_NAME = "itemmimicshadowscaleenvelope"

local shadow_assets =
{
    Asset("IMAGE", SHADOW_TEXTURE),
    Asset("SHADER", SHADOW_SHADER),
}

local function InitializeShadowEnvelopes()
    EnvelopeManager:AddColourEnvelope(
        SHADOW_COLOUR_ENVELOPE_NAME,
        {
            { 0.00, { 1, 1, 1, 1.0 } },
            { 0.50, { 1, 1, 1, 0.9 } },
            { 1.00, { 1, 1, 1, 0.5 } },
        }
    )

    local max_scale = 1.5
    EnvelopeManager:AddVector2Envelope(
        SHADOW_SCALE_ENVELOPE_NAME,
        {
            { 0,    { max_scale, max_scale } },
            { 1,    { 0, 0 } },
        }
    )

    InitializeShadowEnvelopes = nil
end

local MAX_LIFETIME = 15
local EMITTER_RADIUS = 1.0

local function shadow_fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    --inst.entity:SetCanSleep(false)
    if TheNet:GetIsClient() then
        inst.entity:AddClientSleepable()
    end
    inst.persists = false

    inst.entity:AddTransform()

    -----------------------------------------------------

    if InitializeShadowEnvelopes then InitializeShadowEnvelopes() end

    local lifetime = (MAX_LIFETIME - 1) * FRAMES

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(1)
    effect:SetRenderResources(0, SHADOW_TEXTURE, SHADOW_SHADER)
    effect:SetMaxNumParticles(0, MAX_LIFETIME + 2)
    effect:SetMaxLifetime(0, lifetime)
    effect:SetSpawnVectors(0,
        -1, 0, 1,
        1, 0, 1
    )
    effect:SetSortOrder(0, -1)
    effect:SetColourEnvelope(0, SHADOW_COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(0, SHADOW_SCALE_ENVELOPE_NAME)
    effect:SetRadius(0, EMITTER_RADIUS)

    -----------------------------------------------------
    inst._disabled = false

    local particles_to_emit = 1
    local circle_emitter = CreateCircleEmitter(0.1)
    EmitterManager:AddEmitter(inst, nil, function()
        if inst._disabled then return end

        while particles_to_emit > 0 do
            local px, pz = circle_emitter()
            local py = 0
            inst.VFXEffect:AddParticle(
                0, lifetime,
                px, py, pz,
                0, 0, 0
            )
            particles_to_emit = particles_to_emit - 1
        end

        particles_to_emit = particles_to_emit + 1
    end)

    return inst
end

return Prefab("itemmimic_revealed", fn, assets, prefabs),
    Prefab("itemmimic_revealed_shadow", shadow_fn, shadow_assets)