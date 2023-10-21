local assets =
{
    Asset("ANIM", "anim/wagstaff_setpieces.zip"),
}

local prefabs =
{
    "cutstone",
    "wagpunk_bits",
    "collapse_small",
    "wagstaff_mutations_note",
}

------------------------------------------------------------------------------------------------

SetSharedLootTable("wagstaff_machinery",
{
    {'cutstone',          0.75},
    {'wagpunk_bits',      1.00},
    {'wagpunk_bits',      0.75},
    {'transistor',        0.10},
    {'trinket_6',         0.15},
    {'trinket_10',        0.01},
})

------------------------------------------------------------------------------------------------

local MAX_NUMBER = 3 --5

------------------------------------------------------------------------------------------------

local function OnHammered(inst, worker)
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")

    inst:Remove()
end

local function OnHit(inst, worker)
    inst.AnimState:PlayAnimation("hit"  .. inst.debris_id)
    inst.AnimState:PushAnimation("idle" .. inst.debris_id)
end

------------------------------------------------------------------------------------------------

local function SetDebrisType(inst, index)
    if inst.debris_id == nil or (index ~= nil and inst.debris_id ~= index) then
        inst.debris_id = index or tostring(math.random(MAX_NUMBER))
        inst.AnimState:PlayAnimation("idle"..inst.debris_id, true)
    end
end

------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.debris_id = inst.debris_id
end

local function OnLoad(inst, data)
    inst:SetDebrisType(data ~= nil and data.debris_id or nil)
end

------------------------------------------------------------------------------------------------

local function OnSpawned(inst)
    TheWorld:PushEvent("wagstaff_machine_added", inst.GUID)
end

local function OnRemoved(inst)
    TheWorld:PushEvent("wagstaff_machine_destroyed", inst.GUID)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .5)

    inst.MiniMapEntity:SetIcon("wagstaff_machinery.png")
    inst.MiniMapEntity:SetPriority(5)

    inst.AnimState:SetBank("wagstaff_setpieces")
    inst.AnimState:SetBuild("wagstaff_setpieces")

    inst:AddTag("structure")
    inst:AddTag("wagstaff_machine")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "idle3"

    inst.SetDebrisType = SetDebrisType
    inst.OnSpawned = OnSpawned

    inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("wagstaff_machinery")

    inst.components.lootdropper.numrandomloot = TUNING.WAGSTAFF_MACHINERY_NUM_BLUEPRINTS
    inst.components.lootdropper.chancerandomloot = TUNING.WAGSTAFF_MACHINERY_BLUEPRINT_CHANCE
    inst.components.lootdropper:AddRandomLoot("wagpunkhat_blueprint",      1)
    inst.components.lootdropper:AddRandomLoot("armorwagpunk_blueprint",    1)
    inst.components.lootdropper:AddRandomLoot("wagpunkbits_kit_blueprint", 1)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnRemoveEntity = OnRemoved

    if not POPULATING then
        inst:SetDebrisType()
    end

    inst:DoTaskInTime(0, inst.OnSpawned)

    MakeSnowCovered(inst)

    return inst
end

------------------------------------------------------------------------------------------------

return Prefab("wagstaff_machinery", fn, assets, prefabs)