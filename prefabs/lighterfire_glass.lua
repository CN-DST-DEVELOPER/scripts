local MakeLighterFire = require("prefabs/lighterfire_common")

local TEXTURE = "fx/torchfire.tex"
local SHADER = "shaders/vfx_particle.ksh"
local EMBER_TEXTURE = "fx/snow.tex"
local ADD_SHADER = "shaders/vfx_particle_add.ksh"

local COLOUR_ENVELOPE_NAME = "lighterfirecolourenvelope_glass"
local SCALE_ENVELOPE_NAME = "lighterfirescaleenvelope_glass"

local COLOUR_ENVELOPE_NAME_EMBER = "lighterfirecolourenvelope_glass_ember"
local SCALE_ENVELOPE_NAME_EMBER = "lighterfirescaleenvelope_glass_ember"

local assets =
{
    Asset("IMAGE", TEXTURE),
    Asset("SHADER", SHADER),
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
            { 0,    IntColour(100, 120, 100, 128) },
            { .49,  IntColour(80, 100, 80, 128) },
            { .5,   IntColour(255, 255, 0, 128) },
            { .51,  IntColour(80, 100, 80, 128) },
            { .75,  IntColour(120, 80, 80, 128) },
            { 1,    IntColour(20, 30, 20, 0) },
        }
    )

    local max_scale = 2
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { max_scale * .5, max_scale } },
            { 1,    { max_scale * .5, max_scale * .5 } },
        }
    )


    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME_EMBER,
        {
            { 0,    IntColour(100, 120, 100, 128) },
            { .49,  IntColour(80, 100, 80, 128) },
            { .5,   IntColour(255, 255, 0, 128) },
            { .51,  IntColour(80, 100, 80, 128) },
            { .75,  IntColour(120, 80, 80, 128) },
            { 1,    IntColour(20, 30, 20, 0) },
        }
    )

    local ember_max_scale = .6
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_EMBER,
        {
            { 0,    { ember_max_scale, ember_max_scale } },
            { 1,    { ember_max_scale * 0.5, ember_max_scale * 0.5 } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------

local MAX_LIFETIME = .1

local function emit_fn(effect, sphere_emitter)
    local vx, vy, vz = .01 * UnitRand(), 0, .01 * UnitRand()
    local lifetime = MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()
    local uv_offset = math.random(0, 3) * .25

    effect:AddParticleUV(
        0,
        lifetime,           -- lifetime
        px, py + .1, pz,         -- position
        vx, vy, vz,         -- velocity
        uv_offset, 0        -- uv offset
    )
end

local EMBER_MAX_LIFETIME = 1.0

local function emit_ember_fn(effect, sphere_emitter)
    local vx, vy, vz = .05 * UnitRand(), .15 + .03 * UnitRand(), .05 * UnitRand()
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
    effect:SetRenderResources(0, TEXTURE, SHADER)
    effect:SetMaxNumParticles(0, 64)
    effect:SetMaxLifetime(0, MAX_LIFETIME)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(0, BLENDMODE.Additive)
    effect:EnableBloomPass(0, true)
    effect:SetUVFrameSize(0, .25, 1)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)


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

    local desired_particles_per_second = 64
    local particles_per_tick = desired_particles_per_second * tick_time

    local num_particles_to_emit = 1
    
    local ember_num_particles_to_emit = 1
    local moving_ember_particles_per_tick = 20 * tick_time
    local idle_ember_particles_per_tick = 5 * tick_time

    local sphere_emitter = CreateSphereEmitter(.05)
    local ember_sphere_emitter = CreateSphereEmitter(.1)

    inst.last_fx_position = inst:GetPosition()

    EmitterManager:AddEmitter(inst, nil, function()
        while num_particles_to_emit > 1 do
            emit_fn(effect, sphere_emitter)
            num_particles_to_emit = num_particles_to_emit - 1
        end
        num_particles_to_emit = num_particles_to_emit + particles_per_tick

        while ember_num_particles_to_emit > 1 do
            emit_ember_fn(effect, ember_sphere_emitter)
            ember_num_particles_to_emit = ember_num_particles_to_emit - 1
        end
        --Movement speed based emission
        local move_mag = (inst:GetPosition() - inst.last_fx_position):LengthSq()
        if move_mag > 0.007 then
            ember_num_particles_to_emit = ember_num_particles_to_emit + moving_ember_particles_per_tick
        else
            ember_num_particles_to_emit = ember_num_particles_to_emit + idle_ember_particles_per_tick
        end
        inst.last_fx_position = inst:GetPosition()
    end)
end

local function master_postinit(inst)
    inst.fx_offset_x = 56
    inst.fx_offset_y = -40
end


return MakeLighterFire("lighterfire_glass", assets, nil, common_postinit, master_postinit)
