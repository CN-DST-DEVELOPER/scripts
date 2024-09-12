local assets =
{
    Asset("ANIM", "anim/shadowheart_infused.zip"),
}

local function beat(inst)
    inst.SoundEmitter:PlaySound("dontstarve/sanity/shadow_heart")
    inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, beat)
end

local function ondropped(inst)
    if inst.beattask then
        inst.beattask:Cancel()
    end
    inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, beat)

    inst.sg:GoToState("stunned")
end

local function onpickup(inst)
    if inst.beattask then
        inst.beattask:Cancel()
        inst.beattask = nil
    end
end

-- CLIENT-SIDE --------
local function attach_shadow_fx(inst)
    local shadow_fx = CreateEntity("shadowheart_infused_dark_fx")

    --[[Non-networked entity]]
    shadow_fx.entity:SetCanSleep(false)
    shadow_fx.persists = false

    shadow_fx.entity:AddTransform()
    shadow_fx.entity:AddAnimState()
    shadow_fx.entity:AddFollower()

    shadow_fx:AddTag("FX")

    shadow_fx.AnimState:SetBank("shadowheart_infused")
    shadow_fx.AnimState:SetBuild("shadowheart_infused")
    shadow_fx.AnimState:SetFinalOffset(-1)
    shadow_fx.AnimState:PlayAnimation("dark_loop", true)

    shadow_fx.entity:SetParent(inst.entity)

    shadow_fx:AddComponent("highlightchild")

    shadow_fx.Follower:FollowSymbol(inst.GUID, "follow_symbol")

    return shadow_fx
end

--
local brain = require("brains/shadowheart_infusedbrain")
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 0.5)

    inst.AnimState:SetBank("shadowheart_infused")
    inst.AnimState:SetBuild("shadowheart_infused")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("canbetrapped")
    inst:AddTag("shadowheart")
    inst:AddTag("shoreonsink")

    inst.Transform:SetFourFaced()

    if not TheNet:IsDedicated() then
        attach_shadow_fx(inst)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "scrapbook"

    --inst.beattask = nil

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable:SetNameOverride("shadowheart")

    --
    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:SetOnDroppedFn(ondropped)
    inventoryitem:SetOnPutInInventoryFn(onpickup)
    inventoryitem:SetSinks(true)
    inventoryitem.canbepickedup = false

    --
    local locomotor = inst:AddComponent("locomotor")
    locomotor.walkspeed = TUNING.SHADOWHEART_HOP_SPEED

    --
    inst:AddComponent("tradable")

    --
    MakeHauntable(inst)

    --
    inst:SetStateGraph("SGshadowheart_infused")
    inst:SetBrain(brain)

    --
    ondropped(inst)

    return inst
end

return Prefab("shadowheart_infused", fn, assets)
