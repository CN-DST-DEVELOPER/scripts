require("worldsettingsutil")
require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/rabbit_house.zip"),
    Asset("MINIMAP_IMAGE", "rabbit_house"),
}

local prefabs =
{
    "bunnyman",
    "splash_sink",
}

local function IsVampireBunny(inst)
    local child = inst.components.spawner and inst.components.spawner.child
    return child and child.vampire
end

local function getstatus(inst)
    return inst:HasTag("burnt") and "BURNT"
        or nil
end

local function onvacate(inst, child)
    if not inst:HasTag("burnt") then
        if child then
            if child.components.health ~= nil then
                child.components.health:SetPercent(1)
            end
            child:PushEvent("onvacatehome")

            local drownable = child.components.drownable
            if drownable then
                drownable:CheckDrownable()
            end
        end
    end
end

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    if inst.doortask ~= nil then
        inst.doortask:Cancel()
        inst.doortask = nil
    end
    if inst.components.spawner ~= nil and inst.components.spawner:IsOccupied() then
        inst.components.spawner:ReleaseChild()
    end
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")

        if inst.glow_fx ~= nil then
            inst.glow_fx.AnimState:PlayAnimation("hit")
            inst.glow_fx.AnimState:PushAnimation("idle")
        end
    end
end

local function onstopcavedaydoortask(inst)
    inst.doortask = nil
    inst.components.spawner:ReleaseChild()
end

local function OnStopCaveDay(inst)
    if not inst:HasTag("burnt") and inst.components.spawner:IsOccupied() then
        if inst.doortask ~= nil then
            inst.doortask:Cancel()
        end
        inst.doortask = inst:DoTaskInTime(1 + math.random() * 2, onstopcavedaydoortask)
    end
end

local function OnStopCaveNight(inst)
    if not inst:HasTag("burnt") and inst.components.spawner:IsOccupied() then
        if inst.doortask ~= nil then
            inst.doortask:Cancel()
        end
        inst.doortask = inst:DoTaskInTime(2 + math.random() * 4, onstopcavedaydoortask)
    end
end

local function OnAcidRainingChanged(inst, isacidraining)
    if not isacidraining and not TheWorld.state.iscaveday then
        OnStopCaveDay(inst)
    end
end

local function SpawnCheckCaveDay(inst)
    inst.inittask = nil
    if IsVampireBunny(inst) then
        inst:WatchWorldState("stopcavenight", OnStopCaveNight)
        if inst.components.spawner ~= nil and inst.components.spawner:IsOccupied() then
            if TheWorld.state.iscaveday or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
                inst.components.spawner:ReleaseChild()
            end
        end
    else
        inst:WatchWorldState("stopcaveday", OnStopCaveDay)
        inst:WatchWorldState("isacidraining", OnAcidRainingChanged)
        if inst.components.spawner ~= nil and inst.components.spawner:IsOccupied() then
            if not TheWorld.state.iscaveday or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
                inst.components.spawner:ReleaseChild()
            end
        end
    end
end

local function EnableVampireBunnyHouse(inst, vampire)
    if vampire then
        if not inst.vampire then
            inst.vampire = true
            if inst.inittask == nil then
                inst:StopWatchingWorldState("isacidraining", OnAcidRainingChanged)
                inst:StopWatchingWorldState("stopcaveday", OnStopCaveDay)
                inst:WatchWorldState("stopcavenight", OnStopCaveNight)
            end
        end
    elseif inst.vampire then
        inst.vampire = nil
        if inst.inittask == nil then
            inst:WatchWorldState("isacidraining", OnAcidRainingChanged)
            inst:WatchWorldState("stopcaveday", OnStopCaveDay)
            inst:StopWatchingWorldState("stopcavenight", OnStopCaveNight)
        end
    end
end

local function onchildkilled(inst, child)
    EnableVampireBunnyHouse(inst, false)
end

local function oninit(inst)
    inst.inittask = inst:DoTaskInTime(math.random(), SpawnCheckCaveDay)
    if inst.components.spawner ~= nil and
            inst.components.spawner.child == nil and
            inst.components.spawner.childname ~= nil and
            not inst.components.spawner:IsSpawnPending() then
        local child = SpawnPrefab(inst.components.spawner.childname)
        if child ~= nil then
            inst.components.spawner:TakeOwnership(child)
            inst.components.spawner:GoHome(child)
        end
    end
end

local function onsave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function onload(inst, data)
    if data ~= nil and data.burnt then
        inst.components.burnable.onburnt(inst)
    end
end

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle")
    inst.SoundEmitter:PlaySound("dontstarve/common/rabbit_hutch_craft")
end

local function onburntup(inst)
    if inst.doortask ~= nil then
        inst.doortask:Cancel()
        inst.doortask = nil
    end
    if inst.inittask ~= nil then
        inst.inittask:Cancel()
        inst.inittask = nil
    end
    if inst.glow_fx ~= nil then
        inst.glow_fx:Remove()
        inst.glow_fx = nil
    end
end

local function onignite(inst)
    if inst.components.spawner ~= nil and inst.components.spawner:IsOccupied() then
        inst.components.spawner:ReleaseChild()
    end
end

local function OnPreLoad(inst, data)
    WorldSettings_Spawner_PreLoad(inst, data, TUNING.RABBITHOUSE_SPAWN_TIME)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    inst.MiniMapEntity:SetIcon("rabbit_house.png")

    inst.AnimState:SetBank("rabbithouse")
    inst.AnimState:SetBuild("rabbit_house")
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("cavedweller")
    inst:AddTag("structure")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent("spawner")
    WorldSettings_Spawner_SpawnDelay(inst, TUNING.RABBITHOUSE_SPAWN_TIME, TUNING.RABBITHOUSE_ENABLED)
    inst.components.spawner:Configure("bunnyman", TUNING.RABBITHOUSE_SPAWN_TIME)
    inst.components.spawner.onvacate = onvacate
    inst.components.spawner:SetOnKilledFn(onchildkilled)
    inst.components.spawner:CancelSpawning()

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = getstatus

    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountLarge(inst)

    MakeMediumBurnable(inst, nil, nil, true)
    MakeLargePropagator(inst)
    inst:ListenForEvent("burntup", onburntup)
    inst:ListenForEvent("onignite", onignite)

    inst.OnSave = onsave
    inst.OnLoad = onload

    inst:ListenForEvent("onbuilt", onbuilt)
    inst.inittask = inst:DoTaskInTime(0, oninit)

    MakeHauntableWork(inst)

    inst.OnPreLoad = OnPreLoad

    inst.EnableVampireBunnyHouse = EnableVampireBunnyHouse

    return inst
end

return Prefab("rabbithouse", fn, assets, prefabs),
    MakePlacer("rabbithouse_placer", "rabbithouse", "rabbit_house", "idle")
