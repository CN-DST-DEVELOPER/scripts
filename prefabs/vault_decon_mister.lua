local assets = {
    Asset("ANIM", "anim/vault_decon_mister.zip"),
}

local prefabs = {
    "vault_decon_mister_fx",
}

local MIST_TIME_PER_TICK = 0.5
local MIST_RADIUS = 5.1 -- The +0.1 is for an overlap optimization for vaultroom_defs decon1 layout.
local MIST_MUST_TAGS = {"_combat", "locomotor"}
local MIST_MUST_ONEOF_TAGS = {"shadowcreature", "player"}
local function OnApplyMist(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, MIST_RADIUS, MIST_MUST_TAGS, nil, MIST_MUST_ONEOF_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() then
            if ent.isplayer then
                ent:PushEvent("got_decon_misted") -- Wisecracker.
            else
                ent:PushEvent("dispelsanityshadowcreature")
            end
        end
    end
end

local function OnAnimOver_Misting(inst)
    inst.AnimState:PlayAnimation("misting_loop")
end

local function StartMisting(inst)
    if inst.misttask then
        inst.misttask:Cancel()
        inst.misttask = nil
    end
    inst.misttask = inst:DoPeriodicTask(MIST_TIME_PER_TICK, inst.OnApplyMist, math.random() * MIST_TIME_PER_TICK)
    inst:RemoveEventCallback("animover", OnAnimOver_Misting)
    inst:ListenForEvent("animover", OnAnimOver_Misting)
    inst.AnimState:PlayAnimation("misting_activate")
    inst.SoundEmitter:PlaySound("rifts7/mister/active_LP", "misting_lp")
    if not inst.mistfx then
        inst.mistfx = SpawnPrefab("vault_decon_mister_fx")
        inst.mistfx.entity:SetParent(inst.entity)
    end
end

local function StopMisting(inst)
    if inst.misttask then
        inst.misttask:Cancel()
        inst.misttask = nil
    end
    inst:RemoveEventCallback("animover", OnAnimOver_Misting)
    inst.SoundEmitter:KillSound("misting_lp")
    inst.SoundEmitter:PlaySound("rifts7/mister/close")
    if inst.AnimState:IsCurrentAnimation("misting_activate") or inst.AnimState:IsCurrentAnimation("misting_loop") then
        inst.AnimState:PushAnimation("misting_deactivated")
        inst.AnimState:PushAnimation("misting_closed", true)
    else
        inst.AnimState:PlayAnimation("misting_closed")
    end
    if inst.mistfx then
        if inst.mistfx:IsValid() then
            inst.mistfx:Remove()
        end
        inst.mistfx = nil
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeSmallObstaclePhysics(inst, 0.4)

    inst.AnimState:SetBank("vault_decon_mister")
    inst.AnimState:SetBuild("vault_decon_mister")
    inst.AnimState:PlayAnimation("misting_closed")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "misting_closed"

    inst:AddComponent("inspectable")

    inst.StartMisting = StartMisting
    inst.StopMisting = StopMisting
    inst.OnApplyMist = OnApplyMist

    return inst
end

---------------------------------------------------------

local TEXTURE_decon_mist_fx = "fx/animsmoke2.tex"
local SHADER_decon_mist_fx = "shaders/vfx_particle_reveal_withlight.ksh"
local COLOUR_ENVELOPE_NAME_decon_mist_fx = "colourenvelope_decon_mist_fx"
local SCALE_ENVELOPE_NAME_decon_mist_fx = "scaleenvelope_decon_mist_fx"

local decon_mist_fx_assets = {
    Asset("IMAGE", TEXTURE_decon_mist_fx),
    Asset("SHADER", SHADER_decon_mist_fx),
}

local function InitEnvelope_decon_mist_fx()
    local function IntColour(r, g, b, a)
        return { r / 255, g / 255, b / 255, a / 255 }
    end

    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME_decon_mist_fx,
        {
            { 0,    IntColour(83, 91, 36, 25) }, -- Colors grabbed from moon rock shading.
            { 0.25, IntColour(166, 187, 84, 50) },
            { 0.75, IntColour(166, 187, 84, 190) },
            { 1,    IntColour(83, 91, 36, 0) },
        }
    )

    local max_scale = 1
    EnvelopeManager:AddVector2Envelope(SCALE_ENVELOPE_NAME_decon_mist_fx,
        {
            { 0,    { max_scale * 0.15, max_scale * 0.15 } },
            { 0.3,  { max_scale, max_scale } },
            { 0.8,  { max_scale, max_scale } },
            { 1,    { max_scale * 0.3, max_scale * 0.3 } },
        }
    )

    InitEnvelope_decon_mist_fx = nil
end

local MAX_LIFETIME_decon_mist_fx = 1.2
local function decon_mist_fx_emit(effect, sphere_emitter, direction_angle)
    local px, py, pz = sphere_emitter()

    local direction_x, direction_z = math.cos(direction_angle), math.sin(direction_angle)
    local hspeed = 0.3 + math.random() * 0.5
    local vx = hspeed * direction_x
    local vy = 0.2 + math.random() * 0.4
    local vz = hspeed * direction_z

    local u_offset = math.random(0, 3) * .25
    local v_offset = math.random(0, 3) * .25

    effect:AddRotatingParticleUV(
        0,
        MAX_LIFETIME_decon_mist_fx, -- lifetime
        px, py, pz,                  -- position
        vx, vy, vz,                 -- velocity
        math.random() * 360,        -- angle
        UnitRand(),                 -- angle velocity
        u_offset, v_offset          -- uv offset
    )
end

local function decon_mist_fx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.entity:SetPristine()

    inst.persists = false

    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return inst
    elseif InitEnvelope_decon_mist_fx ~= nil then
        InitEnvelope_decon_mist_fx()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(1)

    effect:SetRenderResources(0, TEXTURE_decon_mist_fx, SHADER_decon_mist_fx)
    effect:SetMaxNumParticles(0, 128)
    effect:SetRotationStatus(0, true)
    effect:SetMaxLifetime(0, MAX_LIFETIME_decon_mist_fx)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_decon_mist_fx)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_decon_mist_fx)
    effect:SetBlendMode(0, BLENDMODE.AlphaBlended)
    effect:EnableBloomPass(0, true)
    effect:SetUVFrameSize(0, 0.25, 0.25)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)

    effect:SetAcceleration(0, 0, 0, 0)
    effect:SetDragCoefficient(0, 0.15)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    local low_per_tick = 8 * tick_time
    local high_per_tick = 50 * tick_time
    local sphere_emitter = CreateSphereEmitter(.2)
    local num_to_emit = 0
    local direction_angle = 0
    local angle_per_tick = PI2 / 16
    local time_created = GetTime()
    EmitterManager:AddEmitter(inst, nil, function()
        direction_angle = direction_angle + angle_per_tick + angle_per_tick * math.random()
        if direction_angle > PI2 then
            direction_angle = direction_angle - PI2
        end
        local time_alive = GetTime() - time_created
        local t = math.clamp(time_alive, 0, 1)
        local per_tick = Lerp(low_per_tick, high_per_tick, t)
        num_to_emit = num_to_emit + per_tick
        while num_to_emit > 0 do
            decon_mist_fx_emit(effect, sphere_emitter, direction_angle)
            num_to_emit = num_to_emit - 1
        end
    end)

    return inst
end


return Prefab("vault_decon_mister", fn, assets, prefabs),
Prefab("vault_decon_mister_fx", decon_mist_fx_fn, decon_mist_fx_assets)