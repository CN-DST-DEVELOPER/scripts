require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/carpentry_station.zip"),
    Asset("MINIMAP_IMAGE", "carpentry_station"),
}

local prefabs =
{
    "ash",
    "collapse_small",
}

----
local function GetStatus(inst)
    return (inst:HasTag("burnt") and "BURNT") or nil
end

local function OnHammered(inst, worker)
    if inst.components.burnable and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end

    if inst:HasTag("burnt") then
        inst.components.lootdropper:SpawnLootPrefab("ash")
    else
        inst.components.lootdropper:DropLoot()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function OnHit(inst, worker)
    if inst:HasTag("burnt") then return end

    inst.AnimState:PlayAnimation("hit_open")
    inst.AnimState:PushAnimation(inst.components.prototyper.on and "proximity_loop" or "idle", inst.components.prototyper.on)
end

--
local function OnTurnOn(inst)
    if inst:HasTag("burnt") then return end

    if inst.AnimState:IsCurrentAnimation("proximity_loop") or inst.AnimState:IsCurrentAnimation("place") or inst.AnimState:IsCurrentAnimation("use") then
        inst.AnimState:PushAnimation("proximity_loop", true)
    else
        inst.AnimState:PlayAnimation("proximity_loop", true)
    end

    if not inst.SoundEmitter:PlayingSound("loop_sound") then
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/proximity_lp", "loop_sound")
    end
end

local function OnTurnOff(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PushAnimation("idle", false)
        inst.SoundEmitter:KillSound("loop_sound")
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/proximity_lp_pst")
    end
end

local function OnActivate(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("use")
        inst.AnimState:PushAnimation("proximity_loop", true)
        inst.SoundEmitter:PlaySound("rifts3/sawhorse/use")
    end
end

--
local function OnBuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("rifts3/sawhorse/place")
end

--
local function OnSave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function OnLoad(inst, data)
    if data and data.burnt then
        inst.components.burnable.onburnt(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:SetPhysicsRadiusOverride(0.5)
    MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.MiniMapEntity:SetIcon("carpentry_station.png")

    inst:AddTag("structure")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    inst.AnimState:SetBank("carpentry_station")
    inst.AnimState:SetBuild("carpentry_station")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = GetStatus

    --
    inst:AddComponent("lootdropper")

    --
    local prototyper = inst:AddComponent("prototyper")
    prototyper.onturnon = OnTurnOn
    prototyper.onturnoff = OnTurnOff
    prototyper.onactivate = OnActivate
    prototyper.trees = TUNING.PROTOTYPER_TREES.CARPENTRY_STATION

    --
    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(2)
    workable:SetOnFinishCallback(OnHammered)
    workable:SetOnWorkCallback(OnHit)

    --
    MakeMediumBurnable(inst, nil, nil, true, "station_parts")
    MakeSmallPropagator(inst)

    --
    inst:ListenForEvent("onbuilt", OnBuilt)

    --
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("carpentry_station", fn, assets, prefabs),
    MakePlacer("carpentry_station_placer", "carpentry_station", "carpentry_station", "idle")
