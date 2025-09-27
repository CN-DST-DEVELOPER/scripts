local assets =
{
    Asset("ANIM", "anim/redlantern.zip"),
    Asset("ANIM", "anim/yots_redlantern.zip"),

    Asset("ANIM", "anim/worm.zip"),
    Asset("ANIM", "anim/yots_worm_build.zip"),
}

local prefabs =
{
    "yots_worm",
    "yots_worm_lantern_light",
}

local spawner_prefabs =
{
    "yots_worm_lantern",
}

local YOTS_SPAWN_RANGE = 7.5

local function do_activate(inst, doer)
    local is_burning = inst.components.burnable:IsBurning()
    local real_worm = ReplacePrefab(inst, "yots_worm")
    real_worm.sg:GoToState("lure_exit")
    if is_burning then
        real_worm.components.burnable:Ignite(true, doer)
    end
end

local YOTS_WORM_MUST_TAGS = {"yots_worm"}
local function on_activated(inst, doer)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local nearby_worm_lanterns = TheSim:FindEntities(ix, iy, iz, (2*YOTS_SPAWN_RANGE) + 0.01, YOTS_WORM_MUST_TAGS)
    for _, worm_lantern in pairs(nearby_worm_lanterns) do
        if worm_lantern ~= inst then
            worm_lantern:PushActivate(inst, doer)
        end
    end

    do_activate(inst, doer)

    return false
end

local function push_an_activation(inst, doer)
    if inst.components.activatable.inactive then
        inst.components.activatable.inactive = false
        inst:DoTaskInTime(2 + 3 * math.random(), do_activate, doer)
    end
end

local function on_remove_light(light)
    light._lantern._light = nil
end

local function on_lantern_ignited(inst, source, doer)
    inst.components.inactive = false
    inst:DoTaskInTime(2 + math.random(), on_activated, doer)
end

-- CLIENT
local function activate_verb()
    return "FAKE_PICKUP"
end

local function worm_lantern_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("worm")
    inst.AnimState:SetBuild("yots_worm_build")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.GetActivateVerb = activate_verb

    inst:AddTag("yots_worm")

    inst:SetPrefabNameOverride("redlantern")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst._light = SpawnPrefab("yots_worm_lantern_light")
    inst._light._lantern = inst
    inst:ListenForEvent("onremove", on_remove_light, inst._light)
    inst._light.entity:SetParent(inst.entity)

    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

    --
    local activatable = inst:AddComponent("activatable")
    activatable.OnActivate = on_activated
    activatable.quickaction = true

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable:SetNameOverride("redlantern")

    --
    local burnable = MakeSmallBurnable(inst)
    burnable:SetOnIgniteFn(on_lantern_ignited)

    --
    inst.PushActivate = push_an_activation

    return inst
end

--------------------------------------------------------------------------------------------
local function spawner_do_spawn(inst)
    if inst._spawned then return end

    inst._spawned = {}
    local ipos = inst:GetPosition()
    local random = math.random
    local offset
    for _ = 1, TUNING.YOTS_WORM_COUNT do
        offset = FindWalkableOffset(ipos, TWOPI * random(), 1 + ((YOTS_SPAWN_RANGE - 1) * random()))
        if offset then
            local lantern = SpawnPrefab("yots_worm_lantern")
            lantern.Transform:SetPosition((ipos + offset):Get())
            lantern.AnimState:PlayAnimation("lure_enter")
            lantern.AnimState:PushAnimation("idle_loop", true)
            lantern.SoundEmitter:PlaySound("summerevent/lamp/place1")

            inst._spawned[lantern] = true
            inst:ListenForEvent("onremove", inst._OnLanternRemoved, lantern)
        end
    end
end

-- Player proximity reactions
local function player_near_finished(inst, player)
    -- Abort if we're asleep when we try to wake up.
    -- We should try again later if someone comes close.
    if inst:IsAsleep() then return end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local nearby_worm_lanterns = TheSim:FindEntities(ix, iy, iz, YOTS_SPAWN_RANGE + 2.5001, YOTS_WORM_MUST_TAGS)
    for _, worm_lantern in pairs(nearby_worm_lanterns) do
        worm_lantern:PushActivate(inst, player)
    end
end

local function player_near(inst, player)
    if not inst._player_nearby_task then
        inst._player_nearby_task = inst:DoTaskInTime(8 + 4 * math.random(), player_near_finished, player)
    end
end

local function spawner_onsave(inst, data)
    local ents = {}

	if inst._spawned and next(inst._spawned) ~= nil then
        data.lanterns = {}

        for lantern in pairs(inst._spawned) do
            if lantern:IsValid() then
                table.insert(data.lanterns, lantern.GUID)
                table.insert(ents, lantern.GUID)
            end
        end
    end

    return ents
end

local function spawner_onload(inst, data)
	if data and data.lanterns then
        inst._spawned = {}
    end
end

local function spawner_onloadpostpass(inst, newents, data)
	if not (data and data.lanterns) then
        return
    end

    for _, lantern_GUID in pairs(data.lanterns) do
        local lantern = newents[lantern_GUID]

        if lantern ~= nil then
            inst._spawned[lantern.entity] = true -- The OnLoad should have initialized this table.
            inst:ListenForEvent("onremove", inst._OnLanternRemoved, lantern.entity)
        end
    end
end

local function worm_lantern_spawner_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst._OnLanternRemoved = function(lantern)
        inst._spawned[lantern] = nil
        if next(inst._spawned) == nil then
            -- We don't need to exist when our lanterns are all gone/wormed.
            inst:Remove()
        end
    end

    inst._spawned = false
    inst:DoTaskInTime(FRAMES, spawner_do_spawn)

    --
    local playerprox = inst:AddComponent("playerprox")
    playerprox:SetDist(YOTS_SPAWN_RANGE, YOTS_SPAWN_RANGE + 2)
    playerprox:SetOnPlayerNear(player_near)

    --
    inst.OnSave = spawner_onsave
    inst.OnLoad = spawner_onload
    inst.OnLoadPostPass = spawner_onloadpostpass

    return inst
end

-- Worm lantern light
local FLICKER_COLOUR_MOD = (2 / 255)
local LIGHT_RADIUS = 1.2
local LIGHT_COLOUR = Vector3(200 / 255, 100 / 255, 100 / 255)
local LIGHT_INTENSITY = 0.8
local LIGHT_FALLOFF = 0.5
local function worm_light_on_update_flicker(inst, starttime)
    local time = (starttime ~= nil and ((GetTime() - starttime) * 15)) or 0

    local flicker = 0.25 * (math.sin(time) + math.sin(time + 2) + math.sin(time + 0.7777)) + 0.5
    inst.Light:SetRadius(LIGHT_RADIUS + .1 * flicker)

    flicker = flicker * FLICKER_COLOUR_MOD
    inst.Light:SetColour(LIGHT_COLOUR.x + flicker, LIGHT_COLOUR.y + flicker, LIGHT_COLOUR.z + flicker)
end

local function worm_lantern_light_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.Light:SetIntensity(LIGHT_INTENSITY)
    inst.Light:SetFalloff(LIGHT_FALLOFF)
    --inst.Light:SetColour(LIGHT_COLOUR.x, LIGHT_COLOUR.y, LIGHT_COLOUR.z)
    --inst.Light:SetRadius(LIGHT_RADIUS)
    inst.Light:EnableClientModulation(true)

    inst:DoPeriodicTask(0.1, worm_light_on_update_flicker, nil, GetTime())
    worm_light_on_update_flicker(inst)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("yots_worm_lantern", worm_lantern_fn, assets, prefabs),
    Prefab("yots_worm_lantern_spawner", worm_lantern_spawner_fn, nil, spawner_prefabs),
    Prefab("yots_worm_lantern_light", worm_lantern_light_fn)