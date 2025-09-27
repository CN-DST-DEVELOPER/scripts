--Alive/ Annoying version.

--prefab transforms between different prefabs depending on state.
    --mandrake_planted --> mandrake_active (picked)
    --mandrake_planted <-- mandrake_active (replant)
    --mandrake_active --> mandrake_inactive (death)

local brain = require "brains/mandrakebrain"

local assets =
{
    Asset("ANIM", "anim/mandrake.zip"),
    Asset("SOUND", "sound/mandrake.fsb"),
}

local prefabs =
{
    "mandrake",
    "mandrake_planted",
	"cookedmandrake",
}

local function CheckDay(inst)
    if TheWorld.state.isday then
        if inst.components.freezable and inst.components.freezable:IsFrozen() then
            inst.components.freezable:Unfreeze() --So we can get the freeze fx
        end
        inst.components.health:Kill()
    end
end

local SLEEPTARGETS_CANT_TAGS = { "playerghost", "FX", "DECOR", "INLIMBO" }
local SLEEPTARGETS_ONEOF_TAGS = { "sleeper", "player" }

--NOTE: Keep this in sync with mandrake_inactive's implementation
local function doareasleep(inst, range, time)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, range, nil, SLEEPTARGETS_CANT_TAGS, SLEEPTARGETS_ONEOF_TAGS)
    local canpvp = not inst:HasTag("player") or TheNet:GetPVPEnabled()
    for i, v in ipairs(ents) do
        if (v == inst or canpvp or not v:HasTag("player")) and
            not (v.components.freezable ~= nil and v.components.freezable:IsFrozen()) and
            not (v.components.pinnable ~= nil and v.components.pinnable:IsStuck()) and
            not (v.components.fossilizable ~= nil and v.components.fossilizable:IsFossilized()) then
            local mount = v.components.rider ~= nil and v.components.rider:GetMount() or nil
            if mount ~= nil then
                mount:PushEvent("ridersleep", { sleepiness = 7, sleeptime = time + math.random() })
            end
            if v:HasTag("player") then
                v:PushEvent("yawn", { grogginess = 4, knockoutduration = time + math.random() })
            elseif v.components.sleeper ~= nil then
                v.components.sleeper:AddSleepiness(7, time + math.random())
            elseif v.components.grogginess ~= nil then
                v.components.grogginess:AddGrogginess(4, time + math.random())
            else
                v:PushEvent("knockedout")
            end
        end
    end
end

local function canplant(inst)
    return not inst.components.freezable:IsFrozen() and not inst.components.burnable:IsBurning()
end

local DEATH_TIMER = 5
local function replant(inst, retries)
    --turn into "mandrake_planted"
    retries = retries or 1

    if canplant(inst) then
        local planted = SpawnPrefab("mandrake_planted")
        planted.Transform:SetPosition(inst.Transform:GetWorldPosition())
        planted:replant(inst)

        inst:Remove()
    elseif retries > DEATH_TIMER then
        CheckDay(inst) --I'm sorry little one.
    else
        inst:DoTaskInTime(1, replant, retries+1) --Tick tock little buddy!
    end
end

local function ondeath(inst)
    --turn into "mandrake_inactive"
    local mandrake = SpawnPrefab("mandrake")
    mandrake.Transform:SetPosition(inst.Transform:GetWorldPosition())
    mandrake.AnimState:PlayAnimation("death")
	mandrake.AnimState:SetTime(mandrake.AnimState:GetCurrentAnimationLength())

    inst:Remove()
end

local function oncooked(inst)
	local mandrake = SpawnPrefab("cookedmandrake")
	Launch2(mandrake, inst, 1, 1, 0.2, 0, 4)

    --NOTE (Omar): We died while burning, thus we got cooked! Do a sleep!
    mandrake:DoTaskInTime(0.5, function()
        doareasleep(mandrake, TUNING.MANDRAKE_SLEEP_RANGE, TUNING.MANDRAKE_SLEEP_TIME)
    end)

	inst:Remove()
end

local function FindNewLeader(inst)
    local player = FindClosestPlayerToInst(inst, 5, true)
    if player ~= nil then
        inst.components.follower:SetLeader(player)
    end
end

local function StartFindLeaderTask(inst)
    if inst._findleadertask == nil then
        inst._findleadertask = inst:DoPeriodicTask(1, FindNewLeader)
    end
end

local function StopFindLeaderTask(inst)
    if inst._findleadertask ~= nil then
        inst._findleadertask:Cancel()
        inst._findleadertask = nil
    end
end

local function onpicked(inst)
    --Go to proper animation state
    inst.sg:GoToState("picked")

    FindNewLeader(inst)

    --(Die if it's day time)
    inst:DoTaskInTime(26 * FRAMES, CheckDay)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, 0.25)
    inst.Transform:SetFourFaced()
    inst.DynamicShadow:SetSize(1.75, 0.5)

    inst.AnimState:SetBank("mandrake")
    inst.AnimState:SetBuild("mandrake")
    inst.AnimState:PlayAnimation("idle_loop")

    inst:AddTag("character")
    inst:AddTag("small")
    inst:AddTag("smallcreature")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("combat")
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(20)
    inst.components.health.nofadeout = true
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 6
    inst:AddComponent("follower")

	MakeSmallBurnableCharacter(inst, "swap_fire")
	inst.components.burnable.nocharring = true

	MakeTinyFreezableCharacter(inst, "swap_fire")

    inst:SetStateGraph("SGMandrake")
	inst.sg.mem.burn_on_electrocute = true

    inst:SetBrain(brain)

    inst.onpicked = onpicked

    --Watch world state
    inst:WatchWorldState("startday", replant)
    inst:ListenForEvent("startfollowing", StopFindLeaderTask)
    inst:ListenForEvent("stopfollowing", StartFindLeaderTask)
    StartFindLeaderTask(inst)
    inst.ondeath = ondeath
	inst.oncooked = oncooked

    return inst
end

return Prefab("mandrake_active", fn, assets, prefabs)
