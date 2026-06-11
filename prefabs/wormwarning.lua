local SPAWN_DIST = 30 --hounded.lua::SPAWN_DIST

local WARNING_LEVEL_DISTANCE =
{
    SPAWN_DIST + 30,
    SPAWN_DIST + 20,
    SPAWN_DIST + 10,
    SPAWN_DIST,
}

local function PlayWarningSound(inst, radius, soundoveride)

    inst.entity:SetParent(TheFocalPoint.entity)

    --Everyone gets their own hounds and therefore their own warnings
    local theta = math.random() * TWOPI

    inst.Transform:SetPosition(radius * math.cos(theta), 0, radius * math.sin(theta))
    local sound = soundoveride or "dontstarve/creatures/worm/distant"
    inst.SoundEmitter:PlaySound(sound)
    inst:Remove()
end

local function makewarning(distance, soundoveride)
    return function()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddSoundEmitter()

        inst:AddTag("FX")

        inst:DoTaskInTime(0, function()
            PlayWarningSound(inst, distance, soundoveride)
        end)

        inst.entity:SetCanSleep(false)
        inst.persists = false

        return inst
    end
end

local t = {}
for level, distance in ipairs(WARNING_LEVEL_DISTANCE) do
    table.insert(t, Prefab("wormwarning_lvl"..level, makewarning(distance)))
end

table.insert(t,Prefab("wormwarning_worm_boss", makewarning(SPAWN_DIST, "rifts4/worm_boss/distant")))

return unpack(t)
        