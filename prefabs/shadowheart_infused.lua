local assets =
{
    Asset("ANIM", "anim/shadowheart_infused.zip"),
}


local brain = require("brains/shadowheart_infusedbrain")

----------------------------------------------------------------------------------------------------------------

local function DoBeat(inst)
    inst.SoundEmitter:PlaySound("dontstarve/sanity/shadow_heart")

    inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, DoBeat)
end

local function OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if inst.beattask ~= nil then
        inst.beattask:Cancel()
    end

    inst.beattask = inst:DoTaskInTime(.75 + math.random() * .75, DoBeat)
end

local function OnEntitySleep(inst)
    if inst.beattask ~= nil then
        inst.beattask:Cancel()
        inst.beattask = nil
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnDropped(inst)
    inst.sg:GoToState("stunned")
end

local function OnLanded(inst)
    if inst.components.drownable:ShouldDrown() then
        inst:PushEvent("onsink")
    end
end

----------------------------------------------------------------------------------------------------------------

local function CLIENT_AttachShadowFx(inst)
    local shadow_fx = CreateEntity("shadowheart_infused_dark_fx")

    --[[Non-networked entity]]
    shadow_fx.entity:SetCanSleep(false)
    shadow_fx.persists = false

    shadow_fx.entity:AddTransform()
    shadow_fx.entity:AddAnimState()
    shadow_fx.entity:AddFollower()

    shadow_fx.Transform:SetFourFaced()

    shadow_fx:AddTag("FX")

    shadow_fx.AnimState:SetBank("shadowheart_infused")
    shadow_fx.AnimState:SetBuild("shadowheart_infused")
    shadow_fx.AnimState:SetFinalOffset(-1)
    shadow_fx.AnimState:PlayAnimation("dark_loop", true)

    shadow_fx.entity:SetParent(inst.entity)

    shadow_fx:AddComponent("highlightchild")

    shadow_fx.Follower:FollowSymbol(inst.GUID, "follow_symbol", 0, 45, 0)

    return shadow_fx
end

----------------------------------------------------------------------------------------------------------------

local STARVED_ONTRAP_LOOT = { "shadowheart_infused" }

----------------------------------------------------------------------------------------------------------------

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

    inst.Transform:SetFourFaced()

    if not TheNet:IsDedicated() then
        CLIENT_AttachShadowFx(inst)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "scrapbook"

    inst:AddComponent("tradable")
    inst:AddComponent("drownable")

    inst:AddComponent("inspectable")
    inst.components.inspectable:SetNameOverride("shadowheart")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot(STARVED_ONTRAP_LOOT)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:SetOnDroppedFn(OnDropped)
    inventoryitem.canbepickedup = false
    inventoryitem.trappable = true

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.SHADOWHEART_HOP_SPEED

    inst:SetStateGraph("SGshadowheart_infused")
    inst:SetBrain(brain)

    inst.OnEntityWake  = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("exitlimbo", inst.OnEntityWake)
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)

    inst:ListenForEvent("on_landed", OnLanded)

    MakeHauntable(inst)

    return inst
end

return Prefab("shadowheart_infused", fn, assets)
