require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/wendy_resurrectiongrave.zip"),
    Asset("ANIM", "anim/wendy_resurrectiongrave.zip"),

    Asset("MINIMAP_IMAGE", "wendy_resurrectiongrave"),

}

local prefabs =
{
    "collapse_small",
    "collapse_big",
    "charcoal",
    "abigail_gravestone_rebirth_fx",
    "wendy_gravestone_rebirth_fx",
}

local ghostwendy_assets =
{
    Asset("DYNAMIC_ANIM", "anim/dynamic/ghost_wendy_build.zip"),
    Asset("PKGREF", "anim/dynamic/ghost_wendy_build.dyn"),
}

local FADE_MIN, FADE_MAX = 0, 0.5
local function set_lightvalues(val, inst)
    inst.Light:SetIntensity(0.60 + (0.39 * val * val))
    inst.Light:SetRadius(0.95 * val)
    inst.Light:SetFalloff(0.7)
end

local function onhammered(inst, worker)
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:DropLoot()
    end
    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    inst:Remove()
end

local function onhit(inst, worker)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("idle", true)
end

local function onattunecost(inst, player)
    --round up health to match UI display
    local amount_required = (player:HasTag("health_as_oldage")
            and math.ceil(TUNING.EFFIGY_HEALTH_PENALTY * TUNING.OLDAGE_HEALTH_SCALE))
        or TUNING.EFFIGY_HEALTH_PENALTY

    if not player.components.health or math.ceil(player.components.health.currenthealth) <= amount_required then
        -- Don't die from attunement!
        return false, "NOHEALTH"
    else
        player:PushEvent("consumehealthcost")
        player.components.health:DoDelta(-TUNING.EFFIGY_HEALTH_PENALTY, false, "statue_attune", true, inst, true)
        return true
    end
end

local function onlink(inst, player, isloading)
    inst.AnimState:Show("FIRE")
    inst.components.fader:Fade(FADE_MIN, FADE_MAX, 0.75, set_lightvalues)
    inst.components.named:SetName(subfmt(STRINGS.NAMES.WENDY_RESURRECTIONGRAVE_NAMED, { name = player.name }))
    if not isloading then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/meat_effigy_attune/on")
        inst.AnimState:PlayAnimation("attune_on")
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function onunlink(inst, player, isloading)
    inst.AnimState:Hide("FIRE")
    inst.components.fader:Fade(FADE_MAX, FADE_MIN, 0.75, set_lightvalues)
    inst.components.named:SetName(nil)
    if not (isloading or inst.AnimState:IsCurrentAnimation("attune_on")) then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/meat_effigy_attune/off")
        inst.AnimState:PlayAnimation("attune_off")
        inst.AnimState:PushAnimation("idle", true)
    end
end

local function PlayAttuneSound(inst)
    if inst.AnimState:IsCurrentAnimation("place") or inst.AnimState:IsCurrentAnimation("attune_on") then
        inst.SoundEmitter:PlaySound("meta5/wendy/perennial_altar_on")
    end
end

local function onbuilt(inst, data)
    local attunable = inst.components.attunable

    --Hack to auto-link without triggering fx or paying the cost again
    attunable:SetOnAttuneCostFn(nil)
    attunable:SetOnLinkFn(nil)
    attunable:SetOnUnlinkFn(nil)

    inst.SoundEmitter:PlaySound("meta5/wendy/perennial_altar_place")
    inst.AnimState:PlayAnimation("place")
    if attunable:LinkToPlayer(data.builder) then
        inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), PlayAttuneSound)
        inst.AnimState:Show("FIRE")
        inst.AnimState:PushAnimation("attune_on", false)
        inst.components.fader:Fade(FADE_MIN, FADE_MAX, 0.75, set_lightvalues)
        inst.components.named:SetName(subfmt(STRINGS.NAMES.WENDY_RESURRECTIONGRAVE_NAMED, { name = data.builder.name }))
    end
    inst.AnimState:PushAnimation("idle", true)

    --End hack
    attunable:SetOnAttuneCostFn(onattunecost)
    attunable:SetOnLinkFn(onlink)
    attunable:SetOnUnlinkFn(onunlink)
end

local function do_long_erode(inst) ErodeAway(inst, 4) end
local function start_slideout(inst)
    inst.AnimState:PlayAnimation("slide")

    inst:ListenForEvent("animover", do_long_erode)
end
local function onactivateresurrection(inst, resurrect_target)
    RemovePhysicsColliders(inst)
    inst:AddTag("DECOR")
    inst.persists = false

    inst:DoTaskInTime(67*FRAMES, start_slideout)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1) --recipe min_spacing/2
    MakeObstaclePhysics(inst, 0.95, 0.5)

    inst.MiniMapEntity:SetIcon("wendy_resurrectiongrave.png")

    inst.Light:SetIntensity(0)
    inst.Light:SetRadius(0)
    inst.Light:SetFalloff(0)
    inst.Light:SetColour(0.01, 0.35, 1)

    inst:AddTag("structure")
    inst:AddTag("resurrector")

    -- Pristine state optimization
    inst:AddTag("_named")

    inst.AnimState:SetBank("wendy_resurrectiongrave")
    inst.AnimState:SetBuild("wendy_resurrectiongrave")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:Hide("FIRE")
    inst.AnimState:OverrideSymbol("wormmovefx", "mole_build", "wormmovefx")
    inst.AnimState:SetFinalOffset(-1)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --Remove these tags so that they can be added properly when replicating components below
    inst:RemoveTag("_named")

    --
    local attunable = inst:AddComponent("attunable")
    attunable:SetAttunableTag("gravestoneresurrector")
    attunable:SetOnAttuneCostFn(onattunecost)
    attunable:SetOnLinkFn(onlink)
    attunable:SetOnUnlinkFn(onunlink)

    --
    inst:AddComponent("fader")

    --
    inst:AddComponent("inspectable")

    --
    inst:AddComponent("lootdropper")

    --
    inst:AddComponent("named")

    --
    local workable = inst:AddComponent("workable")
    workable:SetWorkAction(ACTIONS.HAMMER)
    workable:SetWorkLeft(4)
    workable:SetOnFinishCallback(onhammered)
    workable:SetOnWorkCallback(onhit)

    --
    inst:ListenForEvent("onbuilt", onbuilt)
    inst:ListenForEvent("activateresurrection", onactivateresurrection)

    return inst
end

--
local function placer_postinit(inst)
    inst.AnimState:Hide("FIRE")
end

local function abigailfx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("ghost")
    inst.AnimState:SetBuild("ghost_abigail_build")
    inst.AnimState:PlayAnimation("wendy_resurrect")

    inst.AnimState:SetFinalOffset(-2)
    inst:ListenForEvent("animover", function() inst:Remove() end)

    return inst
end

local function wendyfx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.AnimState:SetBank("ghost")
    inst.AnimState:SetBuild("ghost_wendy_build")
    inst.AnimState:PlayAnimation("wendy_ghost_resurrect")

    inst.AnimState:SetFinalOffset(-1)
    inst:ListenForEvent("animover", function() inst:Remove() end)

    return inst
end

return Prefab("wendy_resurrectiongrave", fn, assets, prefabs),
       Prefab("abigail_gravestone_rebirth_fx", abigailfx_fn),
       Prefab("wendy_gravestone_rebirth_fx", wendyfx_fn, ghostwendy_assets),
    MakePlacer("wendy_resurrectiongraveplacer", "wendy_resurrectiongrave", "wendy_resurrectiongrave", "idle", nil, nil, nil, nil, nil, nil, placer_postinit)
