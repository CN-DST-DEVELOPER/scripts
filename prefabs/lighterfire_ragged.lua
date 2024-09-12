local MakeLighterFire = require("prefabs/lighterfire_common")

local ANIMSMOKE_TEXTURE = "fx/animsmoke.tex"
local SMOKE_TEXTURE = "fx/smoke.tex"

local SHADER = "shaders/vfx_particle.ksh"
local REVEAL_SHADER = "shaders/vfx_particle_reveal.ksh"

local COLOUR_ENVELOPE_NAME = "lighterfirecolourenvelope_ragged"
local SCALE_ENVELOPE_NAME = "lighterfirescaleenvelope_ragged"

local COLOUR_ENVELOPE_NAME_SMOKE = "lighterfirecolourenvelope_ragged_smoke"
local SCALE_ENVELOPE_NAME_SMOKE = "lighterfirescaleenvelope_ragged_smoke"

local assets =
{
    Asset("IMAGE", ANIMSMOKE_TEXTURE),
    Asset("SHADER", REVEAL_SHADER),
    Asset("IMAGE", SMOKE_TEXTURE),
    Asset("SHADER", SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
    -- SMOKE
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME_SMOKE,
        {
            { 0,    IntColour(40, 32, 25, 0) },
            { .3,   IntColour(30, 28, 25, 20) },
            { .52,  IntColour(25, 25, 25, 70) },
            { 1,    IntColour(25, 25, 25, 20) },
        }
    )

    local smoke_max_scale = 3
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_SMOKE,
        {
            { 0,    { smoke_max_scale * .15, smoke_max_scale * .2 } },
            { .50,  { smoke_max_scale * .25, smoke_max_scale * .4 } },
            { .65,  { smoke_max_scale * .25, smoke_max_scale * .6 } },
            { 1,    { smoke_max_scale * .25, smoke_max_scale * .4 } },
        }
    )

    -- FIRE
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(187, 111, 60, 128) },
            { .49,  IntColour(187, 111, 60, 128) },
            { .5,   IntColour(255, 255, 0, 128) },
            { .51,  IntColour(255, 150, 56, 128) },
            { .75,  IntColour(255, 120, 56, 128) },
            { 1,    IntColour(255, 30, 28, 0) },
        }
    )

    local max_scale = 0.07
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { max_scale * 0.1, max_scale * 0.1 } },
            { 0.2,  { max_scale * 0.4, max_scale * 0.4 } },
            { 1,    { max_scale * 0.8, max_scale } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------
local SMOKE_MAX_LIFETIME = 0.7
local function emit_smoke_fn(effect, sphere_emitter)
    local vx, vy, vz = .005 * UnitRand(), .08 + .02 * UnitRand(), .005 * UnitRand()
    local lifetime = SMOKE_MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()
    local uv_offset = math.random(0, 3) * .25

    effect:AddParticleUV(
        0,
        lifetime,           -- lifetime
        px, py + .2, pz,    -- position
        vx, vy, vz,         -- velocity
        uv_offset, 0        -- uv offset
   )
end

local MAX_LIFETIME = .5
local function emit_fn(effect, sphere_emitter)
    local vx, vy, vz = .001 * UnitRand(), .025, .00005 * UnitRand()
    local lifetime = MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()

    effect:AddRotatingParticleUV(
        1,
        lifetime,           -- lifetime
        px, py, pz,         -- position
        vx, vy, vz,         -- velocity
        math.random() * 360,-- angle
        UnitRand() * 2,     -- angle velocity
        0, 0                -- uv offset
    )
end

local function common_postinit(inst)
    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return
    elseif InitEnvelope ~= nil then
        InitEnvelope()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(2)

    --SMOKE
    effect:SetRenderResources(0, SMOKE_TEXTURE, SHADER)
    effect:SetMaxNumParticles(0, 128)
    effect:SetMaxLifetime(0, SMOKE_MAX_LIFETIME)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_SMOKE)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_SMOKE)
    effect:SetBlendMode(0, BLENDMODE.Premultiplied)
    effect:EnableBloomPass(0, true)
    effect:SetUVFrameSize(0, .25, 1)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)
    effect:SetRadius(0, 3) --only needed on a single emitter

    -- FIRE
    effect:SetRenderResources(1, ANIMSMOKE_TEXTURE, REVEAL_SHADER)
    effect:SetMaxNumParticles(1, 64)
    effect:SetRotationStatus(1, true)
    effect:SetMaxLifetime(1, MAX_LIFETIME)
    effect:SetColourEnvelope(1, COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(1, SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(1, BLENDMODE.AlphaAdditive)
    effect:EnableBloomPass(1, true)
    effect:SetUVFrameSize(1, 1, 1)
    effect:SetSortOrder(1, 0)
    effect:SetSortOffset(1, 1)
    effect:SetKillOnEntityDeath(1, true)
    effect:SetFollowEmitter(1, true)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    
    local smoke_desired_pps = 50
    local smoke_particles_per_tick = smoke_desired_pps * tick_time
    local smoke_num_particles_to_emit = -30 --start delay

    local particles_per_tick = 20 * tick_time
    local num_particles_to_emit = 1

    local sphere_emitter = CreateSphereEmitter(.05)

    EmitterManager:AddEmitter(inst, nil, function()
        --SMOKE
        while smoke_num_particles_to_emit > 1 do
            emit_smoke_fn(effect, sphere_emitter)
            smoke_num_particles_to_emit = smoke_num_particles_to_emit - 1
        end
        smoke_num_particles_to_emit = smoke_num_particles_to_emit + smoke_particles_per_tick

        --FIRE
        while num_particles_to_emit > 1 do
            emit_fn(effect, sphere_emitter)
            num_particles_to_emit = num_particles_to_emit - 1
        end
        num_particles_to_emit = num_particles_to_emit + particles_per_tick
    end)
end

local function master_postinit(inst)
    inst.fx_offset_x = 56
    inst.fx_offset_y = -55
end


return MakeLighterFire("lighterfire_ragged", assets, nil, common_postinit, master_postinit)
