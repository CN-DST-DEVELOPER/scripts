require("worldsettingsutil")

local assets =
{
	Asset("ANIM", "anim/batbosscave.zip"),
}

local prefabs =
{
	"bat_boss"
}

local function OnPlayerNear(inst, player)
    if inst.components.childspawner.childreninside >= 1 then
        local tries = 10
        while inst.components.childspawner:CanSpawn() and tries > 0 do
            inst.components.childspawner:SpawnChild(player)
            tries = tries - 1
        end
        inst.SoundEmitter:PlaySound("dontstarve/cave/bat_cave_explosion")
        inst.SoundEmitter:PlaySoundWithParams("dontstarve/creatures/bat/taunt", { bat_type = 0.5 })
    end
end

local function OnAddChild(inst)--, count)
    if inst.components.childspawner.childreninside >= 1 then
        inst:AddTag("nightmarecorruptable")
        if not inst.AnimState:IsCurrentAnimation("eyes") then
            inst.AnimState:PlayAnimation("eyes", true)
        end
        if not inst.SoundEmitter:PlayingSound("full") then
            inst.SoundEmitter:PlaySound("dontstarve/cave/bat_cave_warning", "full")
        end

        if inst.components.playerprox:IsPlayerClose() then
            OnPlayerNear(inst)
        end
    end
end

local function OnSpawnChild( inst, child )
    inst:RemoveTag("nightmarecorruptable")
    inst.AnimState:PlayAnimation("idle")
    inst.SoundEmitter:KillSound("full")
    inst.SoundEmitter:PlaySound("dontstarve/cave/bat_cave_bat_spawn")
end

local function OnEntityWake(inst)
    if inst.components.childspawner.childreninside >= 1 then
        inst:AddTag("nightmarecorruptable")
        if not inst.AnimState:IsCurrentAnimation("eyes") then
            inst.AnimState:PlayAnimation("eyes", true)
        end
        if not inst.SoundEmitter:PlayingSound("full") then
            inst.SoundEmitter:PlaySound("dontstarve/cave/bat_cave_warning", "full")
        end
    end
end

local function OnEntitySleep(inst)
    inst.SoundEmitter:KillSound("full")
end

local function OnIsDay(inst, isday)
    if isday then
        inst.components.childspawner:StopSpawning()
    else
        inst.components.childspawner:StartSpawning()
    end
end

local function CanStalkerCorrupt(inst)--, stalker)
    return inst.components.childspawner:CanSpawn()
end

local function RedirectStalkerCorruption(inst, stalker)
    return inst.components.childspawner:SpawnChild(stalker)
end

local function OnPreLoad(inst, data)
    WorldSettings_ChildSpawner_PreLoad(inst, data, TUNING.BATBOSSCAVE_SPAWN_PERIOD, TUNING.BATBOSSCAVE_REGEN_PERIOD)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("batbosscave.png")

    inst.AnimState:SetBuild("batbosscave")
    inst.AnimState:SetBank("batbosscave")
    inst.AnimState:PlayAnimation("idle")

    MakeObstaclePhysics(inst, 2.2)

    if not TheNet:IsDedicated() then
        inst:AddComponent("pointofinterest")
        inst.components.pointofinterest:SetHeight(50)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("childspawner")
	inst.components.childspawner:SetRegenPeriod(TUNING.BATBOSSCAVE_REGEN_PERIOD)
	inst.components.childspawner:SetSpawnPeriod(TUNING.BATBOSSCAVE_SPAWN_PERIOD)
	inst.components.childspawner:SetMaxChildren(TUNING.BATBOSSCAVE_MAX_CHILDREN)
    WorldSettings_ChildSpawner_SpawnPeriod(inst, TUNING.BATBOSSCAVE_SPAWN_PERIOD, TUNING.BATBOSSCAVE_ENABLED)
    WorldSettings_ChildSpawner_RegenPeriod(inst, TUNING.BATBOSSCAVE_REGEN_PERIOD, TUNING.BATBOSSCAVE_ENABLED)
    if not TUNING.BATBOSSCAVE_ENABLED then
        inst.components.childspawner.childreninside = 0
    end
	inst.components.childspawner.childname = "bat_boss"
    inst.components.childspawner:StartSpawning()
    inst.components.childspawner:StartRegen()
    inst.components.childspawner:SetOnAddChildFn( OnAddChild )
    inst.components.childspawner:SetSpawnedFn( OnSpawnChild )
    -- initialize with one child
    inst.components.childspawner.childreninside = 1

    inst:AddComponent("inspectable")

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetOnPlayerNear(OnPlayerNear)
    inst.components.playerprox:SetDist(6, 8)

    OnIsDay(inst, TheWorld.state.iscaveday)
    inst:WatchWorldState("iscaveday", OnIsDay)

    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep
    inst.OnPreLoad = OnPreLoad

    inst.CanStalkerCorrupt = CanStalkerCorrupt
    inst.RedirectStalkerCorruption = RedirectStalkerCorruption

    TheWorld:PushEvent("ms_registerbatbosscave", inst)

	return inst
end

return Prefab("batbosscave", fn, assets, prefabs)