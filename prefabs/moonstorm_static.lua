local assets = {
    Asset("ANIM", "anim/static_ball_contained.zip"),
    Asset("ANIM", "anim/static_ball_empty.zip"),
}
local assets_item = {
    Asset("ANIM", "anim/static_ball_contained.zip"),
    Asset("ANIM", "anim/static_ball_empty.zip"),
    Asset("INV_IMAGE", "moonstorm_static_catcher_item"),
}

local prefabs =
{
    "moonstorm_static_item",
}

local function onattackedfn(inst)
    if inst.AnimState:IsCurrentAnimation("idle") then
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/hit")
        inst.AnimState:PlayAnimation("hit", false)
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function ondeath(inst)
    if not inst.experimentcomplete then
        inst.SoundEmitter:KillSound("loop")
        inst.AnimState:PlayAnimation("explode", false)
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/explode")

        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function finished_callback(inst)
    local nowag = inst.prefab == "moonstorm_static_nowag"
    inst = ReplacePrefab(inst, "moonstorm_static_item")
    if nowag then
        inst:MakePlayerMade()
    end
end
local function finished(inst)
    inst.SoundEmitter:KillSound("loop")
    inst.AnimState:PlayAnimation("finish", false)
    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/finish")
    inst.experimentcomplete = true
    inst:ListenForEvent("animover", finished_callback)
end

local function stormstopped_callback(inst)
    if TheWorld.net.components.moonstorms and not TheWorld.net.components.moonstorms:IsInMoonstorm(inst) then
        inst.components.health:Kill()
    end
end
local function stormstopped(inst)
    inst:DoTaskInTime(1, stormstopped_callback)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, .2)

    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:SetBank("static_contained")
    inst.AnimState:PlayAnimation("idle", true)

    inst.scrapbook_specialinfo = "MOONSTORMSTATIC"

    inst.DynamicShadow:Enable(true)
    inst.DynamicShadow:SetSize(1, .5)

    inst.Light:SetColour(111/255, 111/255, 227/255)
    inst.Light:SetIntensity(0.75)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)

    inst:AddTag("moonstorm_static")
    inst:AddTag("soulless")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.persists = false

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    inst.finished = finished

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MOONSTORM_SPARK_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst:ListenForEvent("attacked", onattackedfn)
    inst:ListenForEvent("death", ondeath)

    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/idle_LP","loop")

    inst:ListenForEvent("ms_stormchanged", function(w, data)
        if data ~= nil and data.stormtype == STORM_TYPES.MOONSTORM then
            stormstopped(inst)
        end
    end, TheWorld)

    inst:AddComponent("inspectable")

    return inst
end

-- NOWAG
local WAG_TOOLS = {}
for i = 1, 5 do
    table.insert(WAG_TOOLS, "wagstaff_tool_"..i)
end
local function should_accept_item(inst, item)
    if not inst._needs_tool then
        return false
    end
    local item_prefab = item.prefab
    for _, tool_prefab in pairs(WAG_TOOLS) do
        if item_prefab == tool_prefab then
            return true
        end
    end
    return false
end

local function on_refuse_item(inst, giver, item)
    if giver.components.talker then
        giver.components.talker:Say(GetActionFailString(giver, "GIVE", "BUSY"))
    end
end

local function on_get_item_from_player(inst, giver, item)
    if TheWorld.components.moonstormmanager then
        TheWorld.components.moonstormmanager:foundWaglessTool()
    end
end

local function on_nowag_need_tool(inst)
    inst.AnimState:PlayAnimation("needtool_idle", true)
    inst._needs_tool = true
end
local function on_nowag_need_tool_over(inst)
    inst.AnimState:PlayAnimation("idle", true)
    inst._needs_tool = nil
end

local function PlayInitAnimation_pst(inst)
    inst:RemoveEventCallback("animover", PlayInitAnimation_pst)
    inst.Transform:SetTwoFaced()
    inst.AnimState:PlayAnimation("idle", true)
end
local function PlayInitAnimation(inst)
    inst.Transform:SetFourFaced()
    inst.AnimState:PlayAnimation("pre_newgame", false)
    inst:ListenForEvent("animover", PlayInitAnimation_pst)
end

local function nowag_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.Transform:SetTwoFaced()

    local object_radius = 0.2 -- NOTES(JBK): Make this the same size for SGwilson. Search string [NOWAGPRF]
    MakeObstaclePhysics(inst, object_radius)

    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:SetBank("static_contained")
    inst.AnimState:OverrideSymbol("sb_parts", "static_ball_empty", "sb_parts")
    inst.AnimState:OverrideSymbol("sb_fragment", "static_ball_empty", "sb_fragment")
    inst.AnimState:PlayAnimation("idle", true)

    inst.scrapbook_specialinfo = "MOONSTORMSTATIC"

    inst.DynamicShadow:Enable(true)
    inst.DynamicShadow:SetSize(1, .5)

    inst.Light:SetColour(111/255, 111/255, 227/255)
    inst.Light:SetIntensity(0.75)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)

    inst:AddTag("moonstorm_static")
    inst:AddTag("soulless")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst.finished = finished

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.MOONSTORM_SPARK_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("combat")
    inst:ListenForEvent("attacked", onattackedfn)
    inst:ListenForEvent("death", ondeath)

    inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/idle_LP","loop")

    inst:ListenForEvent("ms_stormchanged", function(w, data)
        if data ~= nil and data.stormtype == STORM_TYPES.MOONSTORM then
            stormstopped(inst)
        end
    end, TheWorld)

    inst:AddComponent("inspectable")
    inst.components.inspectable.nameoverride = "MOONSTORM_STATIC"

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(should_accept_item)
    inst.components.trader:SetOnRefuse(on_refuse_item)
    inst.components.trader.onaccept = on_get_item_from_player

    inst:ListenForEvent("need_tool", on_nowag_need_tool)
    inst:ListenForEvent("need_tool_over", on_nowag_need_tool_over)

    inst.PlayInitAnimation = PlayInitAnimation

    inst.persists = false

    return inst
end

-- ITEM
local IDLE_SOUND_LOOP_NAME = "loop"

local function OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if not inst.SoundEmitter:PlayingSound(IDLE_SOUND_LOOP_NAME) then
        inst.SoundEmitter:PlaySound("moonstorm/common/static_ball_contained/finished_idle_LP", IDLE_SOUND_LOOP_NAME)
    end
end

local function OnEntitySleep(inst)
    inst.SoundEmitter:KillSound(IDLE_SOUND_LOOP_NAME)
end

local function MakePlayerMade(inst)
    inst.playermade = true
    inst.AnimState:OverrideSymbol("sb_parts", "static_ball_empty", "sb_parts")
    inst.AnimState:OverrideSymbol("sb_fragment", "static_ball_empty", "sb_fragment")
    inst.components.inventoryitem:ChangeImageName("moonstorm_static_catcher_item")
end
local function OnSave_item(inst, data)
    data.playermade = inst.playermade
end
local function OnLoad_item(inst, data)
    if data then
        if data.playermade then
            inst:MakePlayerMade()
        end
    end
end

local function itemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("static_contained")
    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:PlayAnimation("finish_idle", true)

    inst:AddTag("moonstorm_static")

    MakeInventoryFloatable(inst, "med", 0.05, 0.68)

    inst.scrapbook_anim = "finish_idle"

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("tradable")
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("upgrader")
    inst.components.upgrader.upgradetype = UPGRADETYPES.SPEAR_LIGHTNING

    inst.OnEntityWake  = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("exitlimbo", inst.OnEntityWake)
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)

    inst.MakePlayerMade = MakePlayerMade
    inst.OnSave = OnSave_item
    inst.OnLoad = OnLoad_item

    return inst
end

---------------------------------------------------------
-- moonstorm_static_catcher

local assets_catcher = {
    Asset("ANIM", "anim/static_ball_contained.zip"),
    Asset("ANIM", "anim/static_ball_empty.zip"),
    Asset("ANIM", "anim/swap_moonstorm_static_catcher.zip"),
}

local prefabs_catcher = {
    "moonstorm_static_nowag",
}

local function OnEquip_catcher(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_moonstorm_static_catcher", "swap_moonstorm_static_catcher")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip_catcher(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function OnCaught_catcher(inst, doer)
    inst:Remove()
end

local function fn_catcher()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("static_contained")
    inst.AnimState:SetBuild("static_ball_contained")
    inst.AnimState:OverrideSymbol("sb_parts", "static_ball_empty", "sb_parts")
    inst.AnimState:OverrideSymbol("sb_fragment", "static_ball_empty", "sb_fragment")
    inst.AnimState:PlayAnimation("empty_idle")

    inst.pickupsound = "metal"

    MakeInventoryFloatable(inst, "med", 0.2, 0.75)

    inst:AddTag("moonstormstatic_catcher")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    -------------------------------------------------------
    inst:AddComponent("inspectable")

    -------------------------------------------------------
    inst:AddComponent("inventoryitem")

    local equippable = inst:AddComponent("equippable")
    equippable:SetOnEquip(OnEquip_catcher)
    equippable:SetOnUnequip(OnUnequip_catcher)

    local moonstormstaticcatcher = inst:AddComponent("moonstormstaticcatcher")
    moonstormstaticcatcher:SetOnCaughtFn(OnCaught_catcher)

    return inst
end

---------------------------------------------------------
-- moonstorm_static_roamer

local assets_roamer = {
    Asset("ANIM", "anim/static_ball.zip"),
}

local brain_roamer = require("brains/moonstormstaticbrain")

local function Decay(inst)
    if inst.zigzagtask then
        inst.zigzagtask:Cancel()
        inst.zigzagtask = nil
    end
    inst.AnimState:PlayAnimation("decay")
    inst:ListenForEvent("animover", inst.Remove)
end

local function StartDecay(inst)
    if not inst.roamerdecaytask then
        if inst:IsAsleep() then
            inst:Remove()
        else
            inst.roamerdecaytask = inst:DoTaskInTime(3 + math.random(), inst.Decay)
            inst.OnEntitySleep = inst.Remove
        end
    end
end

local function StopDecay(inst)
    if inst.roamerdecaytask then
        inst.roamerdecaytask:Cancel()
        inst.roamerdecaytask = nil
    end
    inst.OnEntitySleep = nil
end

local function OnZigZagUpdate(inst)
    inst.zigzagtask = inst:DoTaskInTime(math.random() * 0.25 + 0.25, inst.OnZigZagUpdate)

    local speedmult = math.random(1, 3) / 2 -- {0.5, 1, 1.5}
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "electriczig", speedmult)

    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = math.random() * PI2
    local radius = math.random() * 0.25 + 0.25
    x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    inst.Transform:SetPosition(x, y, z)

    local moonstorms = TheWorld.net and TheWorld.net.components.moonstorms or nil
    if not moonstorms then
        return
    end

    local shouldstay = moonstorms:IsXZInMoonstorm(x, z)
    if shouldstay then
        inst:StopDecay()
    else
        inst:StartDecay()
    end

    return 
end

local function OnCaught_roamer(inst, obj, doer)
    local rotation = doer and doer.Transform and doer.Transform:GetRotation() or 0
    local static_nowag = ReplacePrefab(inst, "moonstorm_static_nowag")
    static_nowag.Transform:SetRotation(rotation)
    static_nowag:PlayInitAnimation()
    TheWorld:PushEvent("ms_moonstormstatic_roamer_captured", static_nowag)
end

local max_range = TUNING.MAX_INDICATOR_RANGE * 1.5
local function ShouldTrackfn_roamer(inst, viewer)
    return inst:IsValid() and
        viewer:HasTag("moonstormevent_detector") and
        inst:IsNear(inst, max_range) and
        not inst.entity:FrustumCheck() and
        CanEntitySeeTarget(viewer, inst)
end

local function fn_roamer()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddPhysics()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 10, 0.5)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBuild("static_ball")
    inst.AnimState:SetBank("static_ball")
    inst.AnimState:PlayAnimation("appear", false)
    inst.AnimState:PushAnimation("idle", true)

    inst.Light:SetColour(111/255, 111/255, 227/255)
    inst.Light:SetIntensity(0.75)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)

    inst:AddTag("moonstormstaticcapturable") -- Sneak into pristine state.
    
    if not TheNet:IsDedicated() then
        inst:AddComponent("hudindicatable")
        inst.components.hudindicatable:SetShouldTrackFunction(ShouldTrackfn_roamer)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "idle"
    inst.scrapbook_animoffsety = 0
    inst.scrapbook_animpercent = 0.78

    inst:AddComponent("inspectable")

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor:EnableGroundSpeedMultiplier(false)
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.walkspeed = 8
    inst.components.locomotor.pathcaps = { allowocean = true } -- Needed for wander behaviour to properly use point filtering.

    local moonstormstaticcapturable = inst:AddComponent("moonstormstaticcapturable")
    moonstormstaticcapturable:SetOnCaughtFn(OnCaught_roamer)

    inst:SetStateGraph("SGmoonstormstatic")
    inst:SetBrain(brain_roamer)

    inst.OnZigZagUpdate = OnZigZagUpdate
    inst.StartDecay = StartDecay
    inst.StopDecay = StopDecay
    inst.Decay = Decay
    inst.zigzagtask = inst:DoTaskInTime(math.random() * 0.25 + 0.25, inst.OnZigZagUpdate)

    TheWorld:PushEvent("ms_moonstormstatic_roamer_spawned", inst)

    return inst
end

return Prefab("moonstorm_static", fn, assets, prefabs),
    Prefab("moonstorm_static_nowag", nowag_fn, assets, prefabs),
    Prefab("moonstorm_static_item", itemfn, assets_item),
    Prefab("moonstorm_static_catcher", fn_catcher, assets_catcher, prefabs_catcher),
    Prefab("moonstorm_static_roamer", fn_roamer, assets_roamer)
