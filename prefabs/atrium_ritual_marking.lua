require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/atrium_ritual.zip"),
}

local prefabs =
{
    "collapse_small",
}

local UPDATE_SACRIFICE_PERIOD = 15 * FRAMES
local CIRCLE_RADIUS = 1.7

--------------------------------------------------------------------------

local REVERT_COLOUR_TIME = 1.4
local function OnFinishColourTweening(inst)
    inst:RemoveComponent("colourtweener")
end

local function TweenToNormalColour(inst)
    inst.components.colourtweener:StartTween({1, 1, 1, 1}, REVERT_COLOUR_TIME, OnFinishColourTweening)
end

local function RevertToNormalColour(inst)
    inst:DoTaskInTime(0.4, TweenToNormalColour)
end

local function OnBuilt(inst)
    inst.AnimState:PlayAnimation("appear")
    inst.AnimState:PushAnimation("idle", true)

    local colourtweener = inst.components.colourtweener or inst:AddComponent("colourtweener")
    colourtweener:StartTween({0, 0, 0, 1}, 2 * FRAMES, RevertToNormalColour)
end

local function SelectRitualItem(inst, item)
    local soundparam = { item_sequence = 0.1 }
    if inst.gate then
        for i = 1, 3 do
            local marking = inst.gate.components.entitytracker:GetEntity("ritualmarking"..tostring(i))
            if marking and marking.item and marking ~= inst then
                soundparam.item_sequence = soundparam.item_sequence + 0.1
            end
        end
    end

    inst.item = item
    item:SetInRitual(inst)
    inst.AnimState:PlayAnimation("idle_active", true)
    inst.SoundEmitter:PlaySoundWithParams("rifts8/charlie_ritual/summon_item_place", soundparam)
    LaunchToInst(item, inst)
    inst:PushEvent("updateselectedritualitem")

    if inst.ritual_item_task then
        inst.ritual_item_task:Cancel()
        inst.ritual_item_task = nil
    end
end

local RITUAL_ITEM_TAGS, RITUAL_ITEM_NO_TAGS
local function IsValidRitualItem(guy)
    local x, y, z = guy.Transform:GetWorldPosition()
    return y < .1 and not guy.marking -- in case this ritual item was somehow pushed to another marking
end

local function TestForRitualItem(inst)
    if inst.gate then
        if not inst.gate:IsVaultKeySocketed() or
            inst.gate.components.entitytracker:GetEntity("stalker") or
            inst.gate.components.worldsettingstimer:ActiveTimerExists("destabilizedelay") then
            return false
        end
    end
    local sacrifical_item = FindEntity(inst, CIRCLE_RADIUS, IsValidRitualItem, RITUAL_ITEM_TAGS, RITUAL_ITEM_NO_TAGS)
    if sacrifical_item then
        SelectRitualItem(inst, sacrifical_item)
    end
end

local function StartRitualItemTask(inst, initialtime)
    if inst.ritual_item_task then
        inst.ritual_item_task:Cancel()
    end
    inst.ritual_item_task = inst:DoPeriodicTask(UPDATE_SACRIFICE_PERIOD, TestForRitualItem, initialtime or math.random() * UPDATE_SACRIFICE_PERIOD)
end

local function OnRitualItemDetached(inst)
    inst.item = nil
    inst.AnimState:PlayAnimation("idle", true)
    inst:PushEvent("updateselectedritualitem")
    if inst.enabled then
        StartRitualItemTask(inst, 1)
    end
end

local function ConsumeRitualItem(inst)
    if inst.item then
        inst.item:Consume()
        inst.AnimState:PlayAnimation("idle_active", true)
        inst:Enable(false)
    end
end

local function Enable(inst, enabled)
    if inst.enabled ~= enabled then
        inst.enabled = enabled
        if enabled then
            if RITUAL_ITEM_TAGS == nil then
                RITUAL_ITEM_TAGS = { "ritualitem" }
                RITUAL_ITEM_NO_TAGS = { "INLIMBO" }
            end
            if not inst:IsAsleep() then
                StartRitualItemTask(inst)
            end
        else
            if inst.ritual_item_task then
                inst.ritual_item_task:Cancel()
                inst.ritual_item_task = nil
            end
            if inst.item then
                inst.item:SetItem()
            end
        end
    end
end

local function OnAtriumPowered(inst, atriumpowered)
    inst:Enable(atriumpowered)
    if atriumpowered and inst.item == nil then
        TestForRitualItem(inst)
    end
end

local function OnEntitySleep(inst)
    if inst.ritual_item_task then
        inst.ritual_item_task:Cancel()
        inst.ritual_item_task = nil
    end
end

local function OnEntityWake(inst)
    if inst.item == nil and inst.enabled then
        StartRitualItemTask(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("DECOR")

    inst.AnimState:SetBank("atrium_ritual")
    inst.AnimState:SetBuild("atrium_ritual")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(-2)

    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.LARGE] / 2)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("savedrotation")

    inst.Enable = Enable
    inst.RitualItemDetached = OnRitualItemDetached
    inst.ConsumeRitualItem = ConsumeRitualItem
    inst.OnEntityWake = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("atriumpowered", function(_, ispowered) OnAtriumPowered(inst, ispowered) end, TheWorld)

    return inst
end

return Prefab("atrium_ritual_marking", fn, assets, prefabs)