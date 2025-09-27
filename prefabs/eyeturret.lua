require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/eyeball_turret.zip"),
    Asset("ANIM", "anim/eyeball_turret_object.zip"),
	Asset("MINIMAP_IMAGE", "eyeball_turret"),
}

local prefabs =
{
    "eye_charge",
    "eyeturret_base",
}

SetSharedLootTable("eyeturret",
{
    {'thulecite',         1.00},
    {'thulecite',         0.75},
    {'thulecite_pieces',  1.00},
    {'thulecite_pieces',  0.75},
    {'thulecite_pieces',  0.50},
    {'thulecite_pieces',  0.25},
})

local brain = require "brains/eyeturretbrain"

local MAX_LIGHT_FRAME = 24

local function OnUpdateLight(inst, dframes)
    local frame = inst._lightframe:value() + dframes
    if frame >= MAX_LIGHT_FRAME then
        inst._lightframe:set_local(MAX_LIGHT_FRAME)
        inst._lighttask:Cancel()
        inst._lighttask = nil
    else
        inst._lightframe:set_local(frame)
    end

    if frame <= 20 then
        local k = frame / 20
        --radius:    0   -> 3.5
        --intensity: .65 -> .9
        --falloff:   .7  -> .9
        inst.Light:SetRadius(3.5 * k)
        inst.Light:SetIntensity(.9 * k + .65 * (1 - k))
        inst.Light:SetFalloff(.9 * k + .7 * (1 - k))
    else
        local k = (frame - 20) / (MAX_LIGHT_FRAME - 20)
        --radius:    3.5 -> 0
        --intensity: .9  -> .65
        --falloff:   .9  -> .7
        inst.Light:SetRadius(3.5 * (1 - k))
        inst.Light:SetIntensity(.65 * k + .9 * (1 - k))
        inst.Light:SetFalloff(.7 * k + .9 * (1 - k))
    end

    if TheWorld.ismastersim then
        inst.Light:Enable(frame < MAX_LIGHT_FRAME)
    end
end

local function OnLightDirty(inst)
    if inst._lighttask == nil then
        inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, 1)
    end
    OnUpdateLight(inst, 0)
end

local function triggerlight(inst)
    inst._lightframe:set(0)
    OnLightDirty(inst)
end

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "INLIMBO", "player", "eyeturret", "engineering" }
local function retargetfn(inst)
    local target = inst.components.combat.target
    if target ~= nil and
        target:IsValid() and
        inst:IsNear(target, TUNING.EYETURRET_RANGE + 3) then
        --keep current target
        return
    end

    local playertargets = {}
    for i, v in ipairs(AllPlayers) do
        if v.components.combat.target ~= nil then
            playertargets[v.components.combat.target] = true
        end
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.EYETURRET_RANGE + 3, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and
            v ~= target and
            v.entity:IsVisible() and
            inst.components.combat:CanTarget(v) and
            (   playertargets[v] or
                v.components.combat:TargetIs(inst) or
                (v.components.combat.target ~= nil and v.components.combat.target:HasTag("player"))
            ) then
                return v
        end
    end
    return nil
end

local function shouldKeepTarget(inst, target)
	return inst.components.combat:CanTarget(target)
        and inst:IsNear(target, TUNING.EYETURRET_RANGE + 3)
end

local function ShareTargetFn(dude)
    return dude:HasTag("eyeturret")
end

local function ShouldAggro(combat, target)
    if target:HasTag("player") then
        return TheNet:GetPVPEnabled()
    end
    return true
end

local function OnAttacked(inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if attacker ~= nil and not PreventTargetingOnAttacked(inst, attacker, "player") then
        inst.components.combat:SetTarget(attacker)
        inst.components.combat:ShareTarget(attacker, 15, ShareTargetFn, 10)
    end
end

local function EquipWeapon(inst)
    if inst.components.inventory and not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
        local weapon = CreateEntity()
        --[[Non-networked entity]]
        weapon.entity:AddTransform()
        weapon:AddComponent("weapon")
        weapon.components.weapon:SetDamage(inst.components.combat.defaultdamage)
        weapon.components.weapon:SetRange(inst.components.combat.attackrange, inst.components.combat.attackrange+4)
        weapon.components.weapon:SetProjectile("eye_charge")
        weapon:AddComponent("inventoryitem")
        weapon.persists = false
        weapon.components.inventoryitem:SetOnDroppedFn(weapon.Remove)
        weapon:AddComponent("equippable")

        inst.components.inventory:Equip(weapon)
    end
end

local function ondeploy(inst, pt, deployer)
    local turret = SpawnPrefab("eyeturret", inst.linked_skinname, inst.skin_id)
    if turret ~= nil then
        turret.Physics:SetCollides(false)
        turret.Physics:Teleport(pt.x, 0, pt.z)
        turret.Physics:SetCollides(true)
		PreventCharacterCollisionsWithPlacedObjects(turret)
        turret:syncanim("place")
        turret:syncanimpush("idle_loop", true)
        turret.SoundEmitter:PlaySound("dontstarve/common/place_structure_stone")
        inst:Remove()
    end
end

local function syncanim(inst, animname, loop)
    inst.AnimState:PlayAnimation(animname, loop)
    inst.base.AnimState:PlayAnimation(animname, loop)
end

local function syncanimpush(inst, animname, loop)
    inst.AnimState:PushAnimation(animname, loop)
    inst.base.AnimState:PushAnimation(animname, loop)
end

local function itemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("eyeball_turret_object")
    inst.AnimState:SetBuild("eyeball_turret_object")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("eyeturret")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)

    MakeHauntableLaunch(inst)

    --Tag to make proper sound effects play on hit.
    inst:AddTag("largecreature")

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = ondeploy
    --inst.components.deployable:SetDeployMode(DEPLOYMODE.ANYWHERE)
    --inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.NONE)

    return inst
end

local function FixupSkins(inst)
    local parent = inst.entity:GetParent()
    local skinbuild = parent and parent:GetSkinBuild() or nil
    if skinbuild then
        inst.AnimState:OverrideItemSkinSymbol("horn", skinbuild, "horn", parent.GUID, "eyeball_turret")
    else
        inst.AnimState:OverrideSymbol("horn", "eyeball_turret_base", "horn")
    end
end
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2) --eyeturret_item deployspacing/2
	inst:SetPhysicsRadiusOverride(1)
	MakeObstaclePhysics(inst, inst.physicsradiusoverride)

    inst.Transform:SetFourFaced()

    inst.MiniMapEntity:SetIcon("eyeball_turret.png")

    inst:AddTag("eyeturret")
    inst:AddTag("companion")

    inst.AnimState:SetBank("eyeball_turret")
    inst.AnimState:SetBuild("eyeball_turret")
    inst.AnimState:PlayAnimation("idle_loop")

    inst.Light:SetRadius(0)
    inst.Light:SetIntensity(.65)
    inst.Light:SetFalloff(.7)
    inst.Light:SetColour(251/255, 234/255, 234/255)
    inst.Light:Enable(false)
    inst.Light:EnableClientModulation(true)

    inst._lightframe = net_smallbyte(inst.GUID, "eyeturret._lightframe", "lightdirty")
    inst._lighttask = nil

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("lightdirty", OnLightDirty)

        return inst
    end

	inst.override_combat_fx_height = "low"
    inst.scrapbook_anim = "scrapbook"
    inst.scrapbook_overridedata = {"horn", "eyeball_turret_base", "horn"}

    inst.base = SpawnPrefab("eyeturret_base")
    inst.base.entity:SetParent(inst.entity)
    inst.highlightchildren = { inst.base }
    inst.base.FixupSkins = FixupSkins
    inst.base:DoTaskInTime(0, FixupSkins)
    inst.base.reskin_tool_target_redirect = inst

    inst.syncanim = syncanim
    inst.syncanimpush = syncanimpush

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.EYETURRET_HEALTH)
    inst.components.health:StartRegen(TUNING.EYETURRET_REGEN, 1)

    inst:AddComponent("combat")
    inst.components.combat:SetRange(TUNING.EYETURRET_RANGE)
    inst.components.combat:SetDefaultDamage(TUNING.EYETURRET_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.EYETURRET_ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(1, retargetfn)
    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)
    inst.components.combat:SetShouldAggroFn(ShouldAggro)

    inst.triggerlight = triggerlight

    MakeLargeFreezableCharacter(inst)

    MakeHauntableFreeze(inst)

    inst:AddComponent("inventory")
    inst:DoTaskInTime(1, EquipWeapon)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -TUNING.SANITYAURA_TINY

    inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("eyeturret")
    inst.components.lootdropper.droprecipeloot = false

    inst:ListenForEvent("attacked", OnAttacked)

    inst:SetStateGraph("SGeyeturret")
    inst:SetBrain(brain)

    return inst
end

local baseassets =
{
    Asset("ANIM", "anim/eyeball_turret_base.zip"),
}

local function OnEntityReplicated(inst)
    local parent = inst.entity:GetParent()
    if parent ~= nil and parent.prefab == "eyeturret" then
        parent.highlightchildren = { inst }
    end
end

local function basefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("eyeball_turret_base")
    inst.AnimState:SetBuild("eyeball_turret_base")
    inst.AnimState:PlayAnimation("idle_loop")

	inst:AddTag("DECOR")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = OnEntityReplicated
        return inst
    end

    return inst
end

local function PlacerPostInit(inst)
    inst.AnimState:OverrideSymbol("horn", "eyeball_turret_base", "horn")
end

return Prefab("eyeturret", fn, assets, prefabs),
    Prefab("eyeturret_item", itemfn, assets, prefabs),
    MakePlacer("eyeturret_item_placer", "eyeball_turret", "eyeball_turret", "idle_place", nil, nil, nil, nil, nil, nil, PlacerPostInit),
    Prefab("eyeturret_base", basefn, baseassets)
