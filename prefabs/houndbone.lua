local assets =
{
    Asset("ANIM", "anim/hound_base.zip"),
}

local prefabs =
{
    "boneshard",
    "houndstooth",
    "collapse_small",
}

local names = { "piece1", "piece2", "piece3" }

SetSharedLootTable('houndbone',
{
    {'boneshard',  1.00},
})

local function SetBoneType(inst, bonetype)
    inst.bonetype = bonetype
    inst.animname = names[bonetype] -- not used for saving anymore, but left in case of MODS
    inst.AnimState:PlayAnimation(inst.animname)

    inst.components.lootdropper:ClearChanceLoot()
    if bonetype == 3 then
        inst.components.lootdropper:AddChanceLoot("houndstooth", .5)
    end
end

local function onsave(inst, data)
    data.bonetype = inst.bonetype
end

local function onload(inst, data)
    if data ~= nil then
        if data.anim ~= nil then -- backwards compat
            local bonetype = tonumber(string.sub(data.anim, -1)) or 1
            SetBoneType(inst, bonetype)
        elseif data.bonetype ~= nil then
            SetBoneType(inst, data.bonetype)
        end
    end
end

local function onhammered(inst, worker)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("rock")
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("hound_base")
    inst.AnimState:SetBank("houndbase")
    inst.AnimState:PlayAnimation("piece1")

    inst:AddTag("bone")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "piece1"

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(1)
    inst.components.workable:SetOnFinishCallback(onhammered)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('houndbone')

    SetBoneType(inst, math.random(#names))

    MakeHauntableLaunch(inst)

    -------------------
    inst:AddComponent("inspectable")

    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("houndbone", fn, assets, prefabs)