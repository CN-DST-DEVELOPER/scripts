local WX78Common = require("prefabs/wx78_common")

local assets =
{
    Asset("ANIM", "anim/shadowheart.zip"),
}

local function beat(inst)
    inst.beattask = nil
    inst.AnimState:PlayAnimation("idle")
    inst.SoundEmitter:PlaySound("dontstarve/sanity/shadow_heart")
	if not inst:IsAsleep() then
        inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, beat)
    end
end

local function ondropped(inst)
    if inst.beattask ~= nil then
        inst.beattask:Cancel()
    end
    inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, beat)
end

local function onpickup(inst)
    if inst.beattask ~= nil then
        inst.beattask:Cancel()
        inst.beattask = nil
    end
end

local function OnEntityWake(inst)
	if inst.beattask == nil and not inst.components.inventoryitem:IsHeld() then
		inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, beat)
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("shadowheart")
    inst.AnimState:SetBuild("shadowheart")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "small", 0.05, 0.8)

    inst:AddTag("shadowheart")

    MakeItemSocketable_Client(inst, SOCKETNAMES.SHADOW)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    WX78Common.MakeItemSocketable(inst)
    inst.components.socketable:SetSocketQuality(SOCKETQUALITY.HIGH)

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnDroppedFn(ondropped)
    inst.components.inventoryitem:SetOnPutInInventoryFn(onpickup)

    inst:AddComponent("inspectable")
    inst:AddComponent("tradable")

    MakeHauntableLaunch(inst)

    inst.beattask = nil
    inst.OnEntityWake = OnEntityWake

    return inst
end

return Prefab("shadowheart", fn, assets)
