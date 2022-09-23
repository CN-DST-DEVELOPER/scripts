local assets =
{
    Asset("ANIM", "anim/x_marks_spot.zip"),
    Asset("MINIMAP_IMAGE", "pirate_stash"),
}

local function fling_loot(loot)
    Launch(loot, loot, 2)
end

local MAX_LOOTFLING_DELAY = 0.8
local function stash_dug(inst)
    local inst_pos = inst:GetPosition()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst_pos:Get())

    inst:Hide()
    for i,loot in ipairs(inst.loot) do
        loot:ReturnToScene()
        loot.Transform:SetPosition(inst_pos:Get())
        loot:DoTaskInTime(MAX_LOOTFLING_DELAY * math.random(), fling_loot)

        if loot.components.perishable then
            loot.components.perishable:StartPerishing()
        end
        if loot.components.disappears then
            loot.components.disappears:PrepareDisappear()
        end
    end

    -- Ensure that the remove happens after all of our loot gets flung.
    inst:DoTaskInTime(MAX_LOOTFLING_DELAY + 0.2, function()
        inst:Remove()
    end)
end

local function stashloot(inst, item)
    item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    item:RemoveFromScene()
    table.insert(inst.loot,item)
    if item.components.perishable then
        item.components.perishable:StopPerishing()
    end
    if item.components.disappears then
        item.components.disappears:StopDisappear()
    end
    if inst.onstashed then
        inst:onstashed()
    end
end

local function OnSave(inst, data)
    data.loot = {}
    for i,k in ipairs(inst.loot)do
        table.insert(data.loot, k.GUID)
    end    
    return data.loot
end

local function OnLoadPostPass(inst, ents, data)
    inst.loot = {}
    if data and data.loot then
        for i,k in ipairs(data.loot) do
            if ents[k] and ents[k].entity then
                stashloot(inst, ents[k].entity)
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddMiniMapEntity()

    inst.MiniMapEntity:SetIcon("pirate_stash.png")

    inst.AnimState:SetBank("x_marks_spot")
    inst.AnimState:SetBuild("x_marks_spot")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.DIG)
    inst.components.workable:SetWorkLeft(1)
    inst.components.workable:SetOnWorkCallback(stash_dug)

    inst:ListenForEvent("onremove", function()
        if TheWorld.components.piratespawner then
            TheWorld.components.piratespawner:ClearCurrentStash()
        end
    end)

    inst.loot = {}
    inst.stashloot = stashloot
  
    inst.OnSave = OnSave
    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

return Prefab("pirate_stash", fn, assets)
