local MakeLighterFire = require("prefabs/lighterfire_common")

local TEXTURE = "fx/animsmoke.tex"
local REVEAL_SHADER = "shaders/vfx_particle_reveal.ksh"

local TEXTURE_PETAL = "fx/petal.tex"
local SHADER = "shaders/vfx_particle.ksh"

local COLOUR_ENVELOPE_NAME = "lighterfirecolourenvelope_rose"
local SCALE_ENVELOPE_NAME = "lighterfirescaleenvelope_rose"

local COLOUR_ENVELOPE_NAME_PETAL = "lighterfirecolourenvelope_rose_petal"
local SCALE_ENVELOPE_NAME_PETAL = "lighterfirescaleenvelope_rose_petal"

local assets =
{
    Asset("IMAGE", TEXTURE),
    Asset("SHADER", REVEAL_SHADER),
    Asset("IMAGE", TEXTURE_PETAL),
    Asset("SHADER", SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(122, 30, 30, 255) },
            { .5,   IntColour(122, 20, 20, 255) },
            { .75,  IntColour(122, 10, 10, 255) },
            { 1,    IntColour(200, 5, 5, 255) },
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
        COLOUR_ENVELOPE_NAME_PETAL,
        {
            { 0,    IntColour(255, 255, 255, 255) },
            { .2,   IntColour(255, 255, 255, 200) },
            { 1,    IntColour(0, 0, 0, 0) },
        }
    )

    local petal_max_scale = 0.5
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_PETAL,
        {
            { 0,    { petal_max_scale * .2, petal_max_scale * .2} },
            { .40,  { petal_max_scale * .7, petal_max_scale * .7} },
            { .60,  { petal_max_scale * .8, petal_max_scale * .8} },
            { .75,  { petal_max_scale * .9, petal_max_scale * .9} },
            { 1,    { petal_max_scale, petal_max_scale } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------

local MAX_LIFETIME = .5
local function emit_fn(effect, sphere_emitter)
    local vx, vy, vz = .005 * UnitRand(), 0, .0005 * UnitRand()
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

local PETAL_MAX_LIFETIME = 1.3
local function emit_petal_fn(effect, sphere_emitter)
    local lifetime = PETAL_MAX_LIFETIME * (.5 + UnitRand() * .5)
    local px, py, pz = sphere_emitter()
    local vx, vy, vz = sphere_emitter()

    local angle = math.random() * 360
    local uv_offset = math.random(0, 7) / 8
    local ang_vel = (UnitRand() - 1) * 5

    effect:AddRotatingParticleUV(
        1,
        lifetime,           -- lifetime
        px, py, pz,         -- position
        vx, .1 + math.abs(vy)*3, vz,         -- velocity
        angle, ang_vel,     -- angle, angular_velocity
        uv_offset, 0        -- uv offset
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

    effect:SetRenderResources(0, TEXTURE, REVEAL_SHADER)
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

    --PETAL
    effect:SetRenderResources(1, TEXTURE_PETAL, SHADER)
    effect:SetMaxNumParticles(1, 64)
    effect:SetRotationStatus(1, true)
    effect:SetMaxLifetime(1, PETAL_MAX_LIFETIME)
    effect:SetColourEnvelope(1, COLOUR_ENVELOPE_NAME_PETAL)
    effect:SetScaleEnvelope(1, SCALE_ENVELOPE_NAME_PETAL)
    effect:SetBlendMode(1, BLENDMODE.Premultiplied)
    effect:EnableBloomPass(1, true)
    effect:SetUVFrameSize(1, 1/8, 1)
    effect:SetSortOrder(1, 0)
    effect:SetSortOffset(1, 0)
    effect:SetDragCoefficient(1, .1)
    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()

    local particles_per_tick = 20 * tick_time
    local num_particles_to_emit = 1


    local moving_petal_particles_per_tick = 10 * tick_time
    local idle_petal_particles_per_tick = 5 * tick_time
    local petal_num_particles_to_emit = -5 --start delay

    local sphere_emitter = CreateSphereEmitter(.05)

    inst.last_fx_position = inst:GetPosition()

    EmitterManager:AddEmitter(inst, nil, function()
        while num_particles_to_emit > 1 do
            emit_fn(effect, sphere_emitter)
            num_particles_to_emit = num_particles_to_emit - 1
        end
        num_particles_to_emit = num_particles_to_emit + particles_per_tick

        --PETAL
        while petal_num_particles_to_emit > 1 do
            emit_petal_fn(effect, sphere_emitter)
            petal_num_particles_to_emit = petal_num_particles_to_emit - 1
        end

        --Movement speed based emission
        local move_mag = (inst:GetPosition() - inst.last_fx_position):LengthSq()
        if move_mag > 0.007 then
            petal_num_particles_to_emit = petal_num_particles_to_emit + moving_petal_particles_per_tick
        else
            petal_num_particles_to_emit = petal_num_particles_to_emit + idle_petal_particles_per_tick
        end
        inst.last_fx_position = inst:GetPosition()
    end)
end

local function master_postinit(inst)
    inst.fx_offset_x = 56
    inst.fx_offset_y = -55
end


return MakeLighterFire("lighterfire_rose", assets, nil, common_postinit, master_postinit)
