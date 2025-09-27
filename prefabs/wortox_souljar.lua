
local assets = {
    Asset("ANIM", "anim/wortox_souljar.zip"),
    Asset("ANIM", "anim/ui_wortox_souljar_1x1.zip"),
    Asset("INV_IMAGE", "wortox_souljar"),
    Asset("INV_IMAGE", "wortox_souljar_open"),
}

local prefabs = {
    "collapse_small",
    "wortox_soul",
}

local function IsSoul(item)
    return item.prefab == "wortox_soul"
end
local function LeakSouls(inst, count, fromhammered)
    local container = inst.components.container
    if container then
        local item = container:FindItem(IsSoul)
        if item then
            local x, y, z = inst.Transform:GetWorldPosition()
            for i = 1, count or 1 do
                local droppeditem = container:DropItemAt(item, x, y, z)
                if not fromhammered and droppeditem and droppeditem.MakeSmallVisual then
                    droppeditem:MakeSmallVisual()
                end
            end
        end
    end
    if not fromhammered and inst.components.container and not inst.components.container:IsOpen() then
        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
        if owner == nil then
            inst.AnimState:PlayAnimation("rattle")
            inst.AnimState:PushAnimation("idle")
            inst.SoundEmitter:PlaySound("meta5/wortox/souljar_leak")
        end
    end
end

local function UpdatePercent(inst)
    if inst.souljar_needsinit then
        return
    end
    if inst.leaksoulstaskstopper then
        return
    end

    if inst.components.container then
        local count, maxcount = 0, 0
        inst.components.container:ForEachItem(function(item)
            if item.components.stackable then
                count = count + item.components.stackable:StackSize()
                maxcount = maxcount + (item.components.stackable:IsOverStacked() and item.components.stackable.originalmaxsize or item.components.stackable.maxsize)
            else
                count = count + 1
                maxcount = maxcount + 1
            end
        end)
        inst.soulcount = count
        local percent = (maxcount == 0 and 0 or math.min(count / maxcount, 1))
        
        if inst.components.finiteuses then
            inst.components.finiteuses:SetPercent(percent)
        end

        local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
        local shouldleakfrombadowner = owner == nil or owner.components.skilltreeupdater == nil or not owner.components.skilltreeupdater:IsActivated("wortox_souljar_1") 
        if percent > 0 and shouldleakfrombadowner and not inst.components.container:IsOpen() then
            if inst.leaksoulstask == nil then
                inst.leaksoulstask = inst:DoPeriodicTask(TUNING.SKILLS.WORTOX.SOULJAR_LEAK_TIME, inst.LeakSouls, (math.random() * 0.5 + 0.5) * TUNING.SKILLS.WORTOX.SOULJAR_LEAK_TIME)
            end
        else
            if inst.leaksoulstask ~= nil then
                inst.leaksoulstask:Cancel()
                inst.leaksoulstask = nil
            end
            inst.souljar_oldpercent = percent
        end
    end
end

local function OnItemGet(inst, data)
    if data and data.item then
        data.item:ListenForEvent("stacksizechange", inst.UpdatePercent, inst)
    end
    inst:UpdatePercent()
end

local function OnItemLose(inst, data)
    if data and data.prev_item then
        data.prev_item:RemoveEventCallback("stacksizechange", inst.UpdatePercent, inst)
    end
    inst:UpdatePercent()
end

local function OnOpen(inst, data)
    inst.components.inventoryitem:ChangeImageName("wortox_souljar_open")
    if not inst.components.inventoryitem:IsHeld() then
        inst.AnimState:PlayAnimation("lidoff")
        inst.AnimState:PushAnimation("lidoff_idle")
        inst.SoundEmitter:PlaySound("meta5/wortox/souljar_open")
        inst:UpdatePercent()
    else
        inst.AnimState:PlayAnimation("lidoff_idle")
    end
    if data and data.doer and data.doer.finishportalhoptask ~= nil then
        data.doer:TryToPortalHop(1, true)
    end
end

local function OnClose(inst)
    inst.components.inventoryitem:ChangeImageName(nil)
    if not inst.components.inventoryitem:IsHeld() then
        inst.AnimState:PlayAnimation("lidon")
        inst.AnimState:PushAnimation("idle")
        inst.SoundEmitter:PlaySound("meta5/wortox/souljar_close")
        inst:UpdatePercent()
    else
        inst.AnimState:PlayAnimation("idle")
    end
end

local function OnFinishWork(inst, worker)
    if inst.components.lootdropper then
        if inst.components.finiteuses then
            inst.components.finiteuses:SetPercent(1) -- Hack for finiteuses being used as a display and not an actual use counter for durability.
        end
        inst.components.lootdropper:DropLoot()
    end
    inst.components.container:DropEverything()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function OnWorked(inst, worker)
    if inst.components.container and inst.components.container:IsOpen() then
        inst.AnimState:PlayAnimation("lidoff_hit")
        inst.AnimState:PushAnimation("lidoff_idle")
    else
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("idle")
    end
    inst:LeakSouls(math.random(4, 6), true)
end

local function StopTasks(inst)
    if inst.leaksoulstask ~= nil then
        inst.leaksoulstask:Cancel()
        inst.leaksoulstask = nil
    end
    inst.leaksoulstaskstopper = true -- Workaround for task being created the same frame the entity is deleting.
end

local function OnInit(inst)
    inst.souljar_needsinit = nil
    inst:UpdatePercent()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("wortox_souljar")
    inst.AnimState:SetBuild("wortox_souljar")
    inst.AnimState:PlayAnimation("idle")

    --waterproofer (from waterproofer component) added to pristine state for optimization
    inst:AddTag("waterproofer")

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "small", 0.05, 1, nil, nil, { bank = "wortox_souljar", anim = "idle" })

    inst:AddTag("portablestorage")
    inst:AddTag("souljar")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem.canonlygoinpocket = true

    local waterproofer = inst:AddComponent("waterproofer")
    waterproofer:SetEffectiveness(0)

    local container = inst:AddComponent("container")
    container:WidgetSetup("wortox_souljar")
    container.onopenfn = OnOpen
    container.onclosefn = OnClose
    container.droponopen = true

    local finiteuses = inst:AddComponent("finiteuses") -- Using as a display for how full the container contents are.
    finiteuses:SetUses(0)
    finiteuses:SetDoesNotStartFull(true)

    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(3)
    workable:SetOnFinishCallback(OnFinishWork)
    workable:SetOnWorkCallback(OnWorked)

    inst:AddComponent("lootdropper")

    inst.UpdatePercent = UpdatePercent
    inst.LeakSouls = LeakSouls

    inst:ListenForEvent("onputininventory", inst.UpdatePercent)
    inst:ListenForEvent("ondropped", inst.UpdatePercent)

    inst:ListenForEvent("itemget", OnItemGet)
    inst:ListenForEvent("itemlose", OnItemLose)

    inst:ListenForEvent("onremove", StopTasks)

    inst.souljar_needsinit = true
    inst.soulcount = 0
    inst:DoTaskInTime(0, OnInit)

    return inst
end

return Prefab("wortox_souljar", fn, assets, prefabs)