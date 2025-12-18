local assets = {
    Asset("ANIM", "anim/nonslipgrit.zip"),
    Asset("SOUND", "sound/winter2025.fsb"),
}

local prefabs = {
    "nonslipgrit_buff",
}

local prefabs_boosted = {
    "nonslipgritpool",
}

local MAX_FUEL_LEVEL = 100
local TOTAL_USE_TIME = TUNING.NONSLIPGRIT_TOTAL_USE_TIME

local function OnDelta(inst, dt)
    inst:AddDebuff("nonslipgrit_buff", "nonslipgrit_buff")
    inst.components.fueled:DoDelta(-(dt * MAX_FUEL_LEVEL) / TOTAL_USE_TIME)
end

local POOL_RADIUS = 3 -- Tied to art.
local NUMBER_OF_POOLS = TUNING.NONSLIPGRITBOOSTED_NUMBER_OF_POOLS
local function OnDelta_Boosted(inst, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    local pool = SpawnPrefab("nonslipgritpool")
    pool.Transform:SetPosition(x, y, z)
    pool.Transform:SetRotation(math.random() * 360)
    inst.components.fueled:DoDelta(-MAX_FUEL_LEVEL / NUMBER_OF_POOLS)
end

local function fn_common(boosted)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nonslipgrit")
    inst.AnimState:SetBuild("nonslipgrit")
    if boosted then
        inst.AnimState:PlayAnimation("idleboosted")
    else
        inst.AnimState:PlayAnimation("idle")
    end

    MakeInventoryFloatable(inst, "small", 0.08, {0.9, 0.7, 0.9}, true, -2, {sym_build = "nonslipgrit"})
    inst:AddTag("donotautopick")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    local fueled = inst:AddComponent("fueled")
    fueled.fueltype = FUELTYPE.MAGIC
    fueled.rate = 0
    fueled:InitializeFuelLevel(MAX_FUEL_LEVEL)
    fueled:SetDepletedFn(inst.Remove)

    local nonslipgritsource = inst:AddComponent("nonslipgritsource")
    if boosted then
        nonslipgritsource:SetOnDeltaFn(OnDelta_Boosted)
    else
        nonslipgritsource:SetOnDeltaFn(OnDelta)
    end

    return inst
end

local function fn()
    return fn_common(false)
end

local function fn_boosted()
    return fn_common(true)
end

local function OnTimerDone(inst, data)
    if data and data.name == "dissolve" then
        inst.persists = false
        inst.SoundEmitter:PlaySound("winter2025/nonslipgrit/grit_pool_pst")
        inst.AnimState:PlayAnimation("pool_pst")
        inst:ListenForEvent("animover", inst.Remove)
    end
end

local POOL_RADIUS_SQ = 3 * 3 -- Tied to art.
local function IsGritAtPoint(inst, x, y, z)
    local ex, ey, ez = inst.Transform:GetWorldPosition()
    return distsq(ex, ez, x, z) <= POOL_RADIUS_SQ
end

local function OnInit_pool(inst)
    if inst.oninitneeded then
        inst.oninitneeded = nil
        inst:RemoveEventCallback("entitywake", OnInit_pool)
        inst:RemoveEventCallback("entitysleep", OnInit_pool)
        inst.SoundEmitter:PlaySound("winter2025/nonslipgrit/grit_pool")
    end
end

local function fn_pool()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("nonslipgrit")
    inst.AnimState:SetBuild("nonslipgrit")
    inst.AnimState:PlayAnimation("pool_pre")
    inst.AnimState:PushAnimation("pool_idle", false)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(2)

    inst:AddTag("NOCLICK")

    --nonslipgritpool (from nonslipgritpool component) added to pristine state for optimization
    inst:AddTag("nonslipgritpool")

    if not TheWorld.ismastersim then
        return inst
    end

    local nonslipgritpool = inst:AddComponent("nonslipgritpool")
    nonslipgritpool:SetIsGritAtPoint(IsGritAtPoint)

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)
    inst.components.timer:StartTimer("dissolve", TUNING.NONSLIPGRITBOOSTED_POOL_TIME)

    inst.oninitneeded = true
    inst:ListenForEvent("entitywake", OnInit_pool)
    inst:ListenForEvent("entitysleep", OnInit_pool)

    return inst
end


----------------------------------------------------------------------------------------------------
-- nonslipgrit_buff + nonslipgrit_buff_fx
----------------------------------------------------------------------------------------------------


local prefabs_buff = {
    "nonslipgrit_buff_fx",
}

local BUFF_DURATION = 0.25 -- Must be small enough to be fast to remove but long enough to cover a few frames so a new entity is not being created constantly and the sounds are being interrupted.

local TEXTURE1_buff_fx = "fx/confetti.tex" -- Gray rocks
local TEXTURE2_buff_fx = "fx/snow.tex" -- White salt
local SHADER_buff_fx = "shaders/vfx_particle.ksh"
local COLOUR_ENVELOPE_NAME1_buff_fx = "colourenvelope_nonslipgrit_buff1_fx"
local COLOUR_ENVELOPE_NAME2_buff_fx = "colourenvelope_nonslipgrit_buff2_fx"
local SCALE_ENVELOPE_NAME_buff_fx = "scaleenvelope_nonslipgrit_buff_fx"

local assets_buff_fx = {
    Asset("IMAGE", TEXTURE1_buff_fx),
    Asset("IMAGE", TEXTURE2_buff_fx),
    Asset("SHADER", SHADER_buff_fx),
    Asset("SOUND", "sound/winter2025.fsb"),
}

local function OnAttached_buff(inst, target, followsymbol, followoffset, data)
    local duration = BUFF_DURATION
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    inst.components.timer:StartTimer("buffover", duration)
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
    if target ~= nil and target:IsValid() then
        local fx = SpawnPrefab("nonslipgrit_buff_fx")
        inst.bufffx = fx
        fx.entity:SetParent(target.entity)
    end
end

local function OnDetached_buff(inst, target)
    if inst.bufffx and inst.bufffx:IsValid() then
        inst.bufffx:Remove()
    end
    inst.bufffx = nil
    inst:Remove()
end

local function OnExtendedbuff(inst, target, followsymbol, followoffset, data)
    local duration = BUFF_DURATION
    local time_remaining = inst.components.timer:GetTimeLeft("buffover")
    if time_remaining == nil or duration > time_remaining then
        inst.components.timer:SetTimeLeft("buffover", duration)
    end
end

local function OnTimerDone_buff(inst, data)
    if data.name == "buffover" then
        inst.components.debuff:Stop()
    end
end

local function fn_buff()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached_buff)
    inst.components.debuff:SetDetachedFn(OnDetached_buff)
    inst.components.debuff:SetExtendedFn(OnExtendedbuff)

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone_buff)

    return inst
end


local function InitEnvelope_buff_fx()
    local function IntColour(r, g, b, a)
        return { r / 255, g / 255, b / 255, a / 255 }
    end

    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME1_buff_fx,
        {
            { 0, IntColour(127, 127, 127, 225) },
            { 0.5, IntColour(127, 127, 127, 225) },
            { 1, IntColour(100, 100, 100, 0) },
        }
    )
    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME2_buff_fx,
        {
            { 0, IntColour(255, 255, 255, 225) },
            { 0.5, IntColour(255, 255, 255, 225) },
            { 1, IntColour(220, 220, 220, 0) },
        }
    )

    local max_scale = 0.4
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_buff_fx,
        {
            { 0,    { max_scale, max_scale } },
            { 1,    { max_scale * .5, max_scale * .5 } },
        }
    )

    InitEnvelope_buff_fx = nil
end

local MAX_LIFETIME_buff_fx = 1.0
local function buff_fx_emit(effect, sphere_emitter, direction)
    local px, py, pz = sphere_emitter()
    local vx, vy, vz = px * 0.02, -0.1 + py * 0.01, pz * 0.02

    local uv_offset = math.random(0, 4) / 4
    local angle = math.random() * 360
    local ang_vel = (UnitRand() - 1) * 5

    py = 0.5 + py * 0.1

    effect:AddRotatingParticleUV(
        0,
        MAX_LIFETIME_buff_fx, -- lifetime
        px * 2, py, pz * 2, -- position
        vx + direction.x * 0.05, vy, vz + direction.z * 0.05, -- velocity
        angle, ang_vel, -- angle, angular_velocity
        uv_offset, 0 -- uv offset
    )

    px, py, pz = sphere_emitter()
    vx, vy, vz = px * 0.02, -0.1 + py * 0.01, pz * 0.02
    py = 0.5 + py * 0.1
    effect:AddParticle(
        1,
        MAX_LIFETIME_buff_fx, -- lifetime
        px * 2, py, pz * 2, -- position
        vx + direction.x * 0.05, vy, vz + direction.z * 0.05 -- velocity
    )
end

local function fn_buff_fx()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst.SoundEmitter:PlaySound("winter2025/nonslipgrit/grit_passive_LP", "loop")
    inst.persists = false

    inst.entity:SetPristine()
    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return inst
    elseif InitEnvelope_buff_fx ~= nil then
        InitEnvelope_buff_fx()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(2)

    effect:SetRenderResources(0, TEXTURE1_buff_fx, SHADER_buff_fx)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME1_buff_fx)
    effect:SetUVFrameSize(0, .25, 1)
    effect:SetRotationStatus(0, true)

    effect:SetRenderResources(1, TEXTURE2_buff_fx, SHADER_buff_fx)
    effect:SetColourEnvelope(1, COLOUR_ENVELOPE_NAME2_buff_fx)

    for i = 0, 1 do
        effect:SetMaxNumParticles(i, 50)
        effect:SetMaxLifetime(i, MAX_LIFETIME_buff_fx)
        effect:SetScaleEnvelope(i, SCALE_ENVELOPE_NAME_buff_fx)
        effect:SetBlendMode(i, BLENDMODE.Premultiplied)
        effect:SetSortOrder(i, 0)
        effect:SetSortOffset(i, 0)
        effect:SetGroundPhysics(i, true)

        effect:SetAcceleration(i, 0, -0.8, 0)
        effect:SetDragCoefficient(i, .05)
    end

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    local low_per_tick = 10 * tick_time
    local high_per_tick = 30 * tick_time
    local sphere_emitter = CreateSphereEmitter(.25)
    local num_to_emit = 0
    EmitterManager:AddEmitter(inst, nil, function()
        local parent = inst.entity:GetParent()
        if parent then
            local cur_pos = parent:GetPosition()
            if inst.last_pos == nil then
                inst.last_pos = cur_pos
            end
            local dist_moved = cur_pos - inst.last_pos
            local t = math.clamp(dist_moved:Length(), 0, 1)
            dist_moved:Normalize() -- Convert to direction vector.
            local per_tick = Lerp(low_per_tick, high_per_tick, t)
            num_to_emit = num_to_emit + per_tick
            while num_to_emit > 0 do
                buff_fx_emit(effect, sphere_emitter, dist_moved)
                num_to_emit = num_to_emit - 1
            end
            inst.last_pos = cur_pos
        end
    end)

    return inst
end

return Prefab("nonslipgrit", fn, assets, prefabs),
    Prefab("nonslipgritboosted", fn_boosted, assets, prefabs_boosted),
    Prefab("nonslipgritpool", fn_pool, assets),
    Prefab("nonslipgrit_buff", fn_buff, nil, prefabs_buff),
    Prefab("nonslipgrit_buff_fx", fn_buff_fx, assets_buff_fx)
