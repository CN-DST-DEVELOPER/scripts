local MakeLighterFire = require("prefabs/lighterfire_common")

local ANIMSMOKE_TEXTURE = "fx/animsmoke.tex"
local EMBER_TEXTURE = "fx/snow.tex"

local REVEAL_SHADER = "shaders/vfx_particle_reveal.ksh"
local ADD_SHADER = "shaders/vfx_particle_add.ksh"

local COLOUR_ENVELOPE_NAME = "lighterfirecolourenvelope_heart"
local SCALE_ENVELOPE_NAME = "lighterfirescaleenvelope_heart"
local COLOUR_ENVELOPE_NAME_EMBER = "lighterfirecolourenvelope_heart_ember"
local SCALE_ENVELOPE_NAME_EMBER = "lighterfirescaleenvelope_heart_ember"

local assets =
{
    Asset("IMAGE", ANIMSMOKE_TEXTURE),
    Asset("SHADER", REVEAL_SHADER),
    Asset("IMAGE", EMBER_TEXTURE),
    Asset("SHADER", ADD_SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(187, 111/2, 60, 128) },
            { .49,  IntColour(187, 111/2, 60, 128) },
            { .5,   IntColour(255, 255/2, 0, 128) },
            { .51,  IntColour(255, 30/2, 56, 128) },
            { .75,  IntColour(255, 30/2, 56, 128) },
            { 1,    IntColour(255, 7/2, 28, 0) },
        }
    )

    local max_scale = 0.09
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { max_scale * 0.1, max_scale * 0.1 } },
            { 0.2,  { max_scale * 0.4, max_scale * 0.4 } },
            { 1,    { max_scale * 0.8, max_scale } },
        }
    )


    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME_EMBER,
        {
            { 0,    IntColour(200, 85, 60, 25) },
            { .2,   IntColour(230, 140, 90, 200) },
            { .3,   IntColour(255, 90, 70, 255) },
            { .6,   IntColour(255, 90, 70, 255) },
            { .9,   IntColour(255, 90, 70, 230) },
            { 1,    IntColour(255, 70, 70, 0) },
        }
    )

    local ember_max_scale = .25
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_EMBER,
        {
            { 0,    { ember_max_scale, ember_max_scale } },
            { 1,    { ember_max_scale, ember_max_scale } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------

local MAX_LIFETIME = .5
local function emit_fn(effect, sphere_emitter)
    local vx, vy, vz = .01 * UnitRand(), .0125, .0005 * UnitRand()
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

local EMBER_MAX_LIFETIME = 1.2

local function emit_ember_fn(effect, sphere_emitter)
    local vx, vy, vz = .07 * UnitRand(), .07 + .03 * UnitRand(), .07 * UnitRand()
    local lifetime = EMBER_MAX_LIFETIME * (0.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()

    effect:AddParticleUV(
        1,
        lifetime,           -- lifetime
        px * 0.1, py + .1, pz * 0.1,    -- position
        vx, vy, vz,         -- velocity
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


    --EMBER
    effect:SetRenderResources(1, EMBER_TEXTURE, ADD_SHADER)
    effect:SetMaxNumParticles(1, 128)
    effect:SetMaxLifetime(1, EMBER_MAX_LIFETIME)
    effect:SetColourEnvelope(1, COLOUR_ENVELOPE_NAME_EMBER)
    effect:SetScaleEnvelope(1, SCALE_ENVELOPE_NAME_EMBER)
    effect:SetBlendMode(1, BLENDMODE.Additive)
    effect:EnableBloomPass(1, true)
    effect:SetUVFrameSize(1, 1, 1)
    effect:SetSortOrder(1, 0)
    effect:SetSortOffset(1, 3)
    effect:SetDragCoefficient(1, .07)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()

    local particles_per_tick = 20 * tick_time
    local num_particles_to_emit = 1

    local ember_time_to_emit = -2
    local ember_num_particles_to_emit = 1

    local sphere_emitter = CreateSphereEmitter(.05)
    local ember_sphere_emitter = CreateSphereEmitter(.1)

    EmitterManager:AddEmitter(inst, nil, function()
        while num_particles_to_emit > 1 do
            emit_fn(effect, sphere_emitter)
            num_particles_to_emit = num_particles_to_emit - 1
        end
        num_particles_to_emit = num_particles_to_emit + particles_per_tick

        if ember_time_to_emit < 0 then
            for i = 1, ember_num_particles_to_emit do
                emit_ember_fn(effect, ember_sphere_emitter)
            end
            ember_num_particles_to_emit = 3 + 2 * math.random()
            ember_time_to_emit = .5
        end
        ember_time_to_emit = ember_time_to_emit - tick_time
    end)
end

local function master_postinit(inst)
    inst.fx_offset_x = 56
    inst.fx_offset_y = -55
end

return MakeLighterFire("lighterfire_heart", assets, nil, common_postinit, master_postinit)
