local MakeLighterFire = require("prefabs/lighterfire_common")

local ANIMSMOKE_TEXTURE = "fx/animsmoke.tex"

local REVEAL_SHADER = "shaders/vfx_particle_reveal.ksh"

local COLOUR_ENVELOPE_NAME = "lighterfirecolourenvelope_old"
local SCALE_ENVELOPE_NAME = "lighterfirescaleenvelope_old"

local assets =
{
    Asset("IMAGE", ANIMSMOKE_TEXTURE),
    Asset("SHADER", REVEAL_SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(187/2, 111/2, 111, 128) },
            { .49,  IntColour(187, 111, 60, 128) },
            { .5,   IntColour(255, 111, 0, 128) },
            { .51,  IntColour(255, 111, 56, 128) },
            { .75,  IntColour(255, 111, 56, 128) },
            { 1,    IntColour(255, 111, 28, 0) },
        }
    )

    local max_scale = 0.09
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { max_scale * 0.1, max_scale * 0.1 } },
            { 0.2,  { max_scale * 0.4, max_scale * 0.4 } },
            { 0.8,  { max_scale * 0.8, max_scale } },
            { 1,    { max_scale * 0.1, max_scale * 0.1 } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------

local MAX_LIFETIME = .5
local SMOKE_MAX_LIFETIME = 1.3

local function emit_fn(effect, sphere_emitter)
    local vx, vy, vz = .0025 * UnitRand(), .025, .00025 * UnitRand()
    local lifetime = MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()

    effect:AddRotatingParticleUV(
        0,
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
    effect:InitEmitters(1)

    effect:SetRenderResources(0, ANIMSMOKE_TEXTURE, REVEAL_SHADER)
    effect:SetMaxNumParticles(0, 64)
    effect:SetRotationStatus(0, true)
    effect:SetMaxLifetime(0, MAX_LIFETIME)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(0, BLENDMODE.AlphaAdditive)
    effect:EnableBloomPass(0, true)
    effect:SetUVFrameSize(0, 1, 1)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)
    effect:SetKillOnEntityDeath(0, true)
    effect:SetFollowEmitter(0, true)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()

    local particles_per_tick = 20 * tick_time
    local num_particles_to_emit = 1

    local sphere_emitter = CreateSphereEmitter(.025)

    EmitterManager:AddEmitter(inst, nil, function()
        while num_particles_to_emit > 1 do
            emit_fn(effect, sphere_emitter)
            num_particles_to_emit = num_particles_to_emit - 1
        end
        num_particles_to_emit = num_particles_to_emit + particles_per_tick
    end)
end

local function master_postinit(inst)
    inst.fx_offset_x = 52
    inst.fx_offset_y = -50
end


return MakeLighterFire("lighterfire_old", assets, nil, common_postinit, master_postinit)
