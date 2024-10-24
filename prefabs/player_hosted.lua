local assets =
{
    Asset("ANIM", "anim/player_basic.zip"),
    Asset("ANIM", "anim/player_actions.zip"),
    Asset("ANIM", "anim/player_shadow_thrall_parasite.zip"),
}

--------------------------------------------------------------------------------------------------------------------------------

local brain = require("brains/hostedbrain")

local SHADOWTHRALL_PARASITE_RETARGET_CANT_TAGS = { "shadowthrall_parasite_hosted", "shadowthrall_parasite_mask" }

--------------------------------------------------------------------------------------------------------------------------------

local function RetargetFn(inst)
    return FindEntity(
        inst,
        TUNING.SHADOWTHRALL_PARASITE_TARGET_DIST,
        function(guy)
            return inst.components.combat:CanTarget(guy)
        end,
        nil,
        SHADOWTHRALL_PARASITE_RETARGET_CANT_TAGS
    )
end

local function KeepTarget(inst, target)
    return inst.components.combat:CanTarget(target) and not target:HasTag("shadowthrall_parasite_hosted")
end

--------------------------------------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.skeleton_prefab = inst.skeleton_prefab
    data.hosted_userid = inst.hosted_userid:value()
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.skeleton_prefab = data.skeleton_prefab
        inst.hosted_userid:set(data.hosted_userid)
    end
end

--------------------------------------------------------------------------

local function DisplayNameFn(inst)
    return ThePlayer ~= nil and ThePlayer.userid == inst.hosted_userid:value() and STRINGS.NAMES.PLAYER_HOSTED_ME or nil
end

local function GetStatus(inst, viewer)
    return viewer and viewer.userid == inst.hosted_userid:value() and "ME" or nil
end

--------------------------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst:SetPhysicsRadiusOverride(.75)
    MakeCharacterPhysics(inst, 50, inst.physicsradiusoverride)

    inst.DynamicShadow:SetSize(2, 1)
    inst.Transform:SetFourFaced()

    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("scarytoprey")
    inst:AddTag("shadowthrall")
    inst:AddTag("shadow_aligned")

    inst.AnimState:AddOverrideBuild("player_basic")
    inst.AnimState:AddOverrideBuild("player_actions")
    inst.AnimState:Hide("ARM_carry")

    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wilson")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.skeleton_prefab = "skeleton_player"

    inst.displaynamefn = DisplayNameFn

    inst.hosted_userid = net_string(inst.GUID, "player_hosted.hosted_userid")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("skinner")
    inst.components.skinner:SetupNonPlayerData()
    inst.components.skinner.useskintypeonload = true -- Hack.

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

    inst:AddComponent("locomotor")

    inst:AddComponent("inventory")

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.WILSON_HEALTH)

    inst:AddComponent("combat")
    inst.components.combat:SetKeepTargetFunction(KeepTarget)
    inst.components.combat:SetRetargetFunction(3, RetargetFn)
    inst.components.combat:SetDefaultDamage(TUNING.UNARMED_DAMAGE)

    MakeMediumBurnableCharacter(inst, "torso")

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst:SetStateGraph("SGplayer_hosted")
    inst:SetBrain(brain)

    return inst
end

return Prefab("player_hosted", fn, assets)
