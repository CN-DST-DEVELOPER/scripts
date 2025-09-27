local assets =
{
    Asset("ANIM", "anim/cave_exit_lightsource.zip"),
}

local function OnEntityWake(inst)
    -- Don't play any sound. This is a 'fake' opening.
    --inst.SoundEmitter:PlaySound("dontstarve/AMB/caves/forest_spot", "loop")
end

local function OnEntitySleep(inst)
    inst.SoundEmitter:KillSound("loop")
end

local function SetDuration(inst, duration)
    inst.duration = duration
    inst.kill_task = inst:DoTaskInTime(duration, inst.FadeOut)
end

local function FadeOut(inst)
    if inst:IsAsleep() then
        inst:Remove()
    else
        local radius = 3
        local intensity = 0.85
        local falloff = 0.3

        inst.AnimState:PlayAnimation("off")
        inst.persists = false

        inst:DoPeriodicTask(FRAMES, function()
            radius = radius - (3/7)
            intensity = intensity - (0.85/7)
            falloff = falloff + (0.3/7)
            inst.Light:SetRadius(radius)
            inst.Light:SetIntensity(intensity)
            inst.Light:SetFalloff(falloff)
        end)

        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function onsave(inst, data)
    data.time_remaining = GetTaskRemaining(inst.kill_task)
end

local function onload(inst, data)
    if data and data.time_remaining then
        inst:SetDuration(data.time_remaining)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    
    inst.entity:AddLight()
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(0.3)
    inst.Light:SetIntensity(0.85)
    inst.Light:EnableClientModulation(true)
    inst.Light:SetColour(180/255, 195/255, 150/255)

    inst.AnimState:SetBank("cavelight")
    inst.AnimState:SetBuild("cave_exit_lightsource")
    inst.AnimState:PlayAnimation("idle_loop", false) -- the looping is annoying
    inst.AnimState:SetLightOverride(1)

    inst.Transform:SetScale(2, 2, 2) -- Art is made small coz of flash weirdness, the giant stage was exporting strangely

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst:AddTag("daylight")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst.OnSave = onsave
    inst.OnLoad = onload

    inst.SetDuration = SetDuration
    inst.FadeOut = FadeOut

    return inst
end

return Prefab("booklight", fn, assets)