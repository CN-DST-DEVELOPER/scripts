require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/fence_electric.zip"),
}

local prefabs =
{
    "fence_electric_field",
    "collapse_small",
}

local FENCE_LOOT = { "wagpunk_bits", "moonglass" }

-------------------------------------------------------------------------------

local function OnIsPathFindingDirty(inst)
    if inst._ispathfinding:value() then
        if inst._pfpos == nil and inst:GetCurrentPlatform() == nil then
            inst._pfpos = inst:GetPosition()
            TheWorld.Pathfinder:AddWall(inst._pfpos:Get())
        end
    elseif inst._pfpos ~= nil then
        TheWorld.Pathfinder:RemoveWall(inst._pfpos:Get())
        inst._pfpos = nil
    end
end

local function InitializePathFinding(inst)
    inst:ListenForEvent("onispathfindingdirty", OnIsPathFindingDirty)
    OnIsPathFindingDirty(inst)
end

local function MakeObstacle(inst)
    inst.Physics:SetActive(true)
    inst._ispathfinding:set(true)
end

local function ClearObstacle(inst) --(Omar): Unused but left in case the fence can be in a non-obstacle state
    inst.Physics:SetActive(false)
    inst._ispathfinding:set(false)
end

local function OnRemove(inst)
    inst._ispathfinding:set_local(false)
    OnIsPathFindingDirty(inst)
end

local function KeepTargetFn()
    return false
end

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()
    inst.components.electricconnector:Disconnect()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")

    inst:Remove()
end

local function OnWorked(inst)
    inst.sg:GoToState("hit")
end

local function OnHit(inst, data)
    if not data or not data.attacker or (data.damage and data.damage <= 0) then
        return
    end

    local attacker = data.attacker
    local has_connection = inst.components.electricconnector:HasConnection()
    local attacker_electric_immune = IsEntityElectricImmune(attacker) or not CanEntityBeElectrocuted(attacker)

    --anything without a shock state
    if not has_connection or attacker_electric_immune or attacker:HasTag("epic") or data.stimuli == "electric" then
        inst.components.workable:WorkedBy(attacker)
    end

    --(Omar): #TEMP TODO we want the electricution redirect mechanic to be implemented better
    if not IsEntityDead(attacker, true) and not attacker_electric_immune and has_connection and data.stimuli ~= "electric"
        and data.stimuli ~= "soul"
        and (data.weapon == nil or ((data.weapon.components.weapon == nil or data.weapon.components.weapon.projectile == nil) and data.weapon.components.projectile == nil)) then
		attacker:PushEventImmediate("electrocute", {duration=TUNING.ELECTROCUTE_SHORT_DURATION, noburn=true})
    end
end

local function OnElectricallyLinked(inst)
    inst.AnimState:Show("light")
    inst.AnimState:Show("electricity")
    inst.AnimState:SetSymbolLightOverride("swap_light", 1)
    inst.AnimState:OverrideSymbol("swap_light", "fence_electric", "light_on")
end

local function OnElectricallyUnlinked(inst)
    inst.AnimState:Hide("light")
    inst.AnimState:Hide("electricity")
    inst.AnimState:SetSymbolLightOverride("swap_light", 0)
    inst.AnimState:OverrideSymbol("swap_light", "fence_electric", "light_off")
end

------------------------------------------------------------------------------

local function GetStatus(inst)
    return inst.components.electricconnector:HasConnection() and "LINKED" or nil
end

---------------------------------------------------------------------------

local SCRAPBOOK_OVERRIDESYMBOLDATA =
{
    {"swap_light", "fence_electric", "light_off"}
}
local SCRAPBOOK_HIDEDATA = {
    "light",
    "electricity",
}
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:SetDeploySmartRadius(0.5) --DEPLOYMODE.WALL assumes spacing of 1

    MakeObstaclePhysics(inst, .5)
    inst.Physics:SetDontRemoveOnSleep(true)

    inst:AddTag("wall")
    inst:AddTag("fence") --(Omar) Note: This tag doesn't actually do anything yet
    inst:AddTag("fence_electric")
    inst:AddTag("noauradamage")
    inst:AddTag("electric_connector")

    inst.AnimState:SetBank("fence_electric")
    inst.AnimState:SetBuild("fence_electric")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:OverrideSymbol("swap_light", "fence_electric", "light_off")
    inst.AnimState:SetSymbolBloom("bolt_b")
    inst.AnimState:SetSymbolMultColour("bolt_b", 1, 1, 1, 0.4 + math.random() * 0.1)
    inst.AnimState:Hide("light")
    inst.AnimState:Hide("electricity")

    inst._pfpos = nil
    inst._ispathfinding = net_bool(inst.GUID, "_ispathfinding", "onispathfindingdirty")
    MakeObstacle(inst)
    --Delay this because MakeObstacle sets pathfinding on by default
    --but we don't to handle it until after our position is set
    inst:DoTaskInTime(0, InitializePathFinding)

    inst.OnRemoveEntity = OnRemove

    -----------------------------------------------------------------------
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim   = "idle"
    inst.scrapbook_build  = "fence_electric"
    inst.scrapbook_bank   = "fence_electric"
    inst.scrapbook_facing = FACING_DOWN
    inst.scrapbook_overridedata = SCRAPBOOK_OVERRIDESYMBOLDATA
    inst.scrapbook_hide = SCRAPBOOK_HIDEDATA

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot(FENCE_LOOT)

    inst:AddComponent("electricconnector")
    inst.components.electricconnector.max_links = TUNING.ELECTRIC_FENCE_MAX_LINKS
    inst.components.electricconnector.link_range = TUNING.ELECTRIC_FENCE_MAX_DIST
    inst.components.electricconnector.field_prefab = "fence_electric_field"
    inst.components.electricconnector.onlinkedfn = OnElectricallyLinked
    inst.components.electricconnector.onunlinkedfn = OnElectricallyUnlinked

    inst:SetStateGraph("SGfence_electric")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnWorked)

    inst:AddComponent("combat")
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    --inst.components.combat.onhitfn = OnHit

    inst:ListenForEvent("attacked", OnHit)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(1)
    inst.components.health:SetAbsorptionAmount(1)
    inst.components.health.fire_damage_scale = 0
    inst.components.health.canheal = false
    inst.components.health.nofadeout = true
    inst:ListenForEvent("death", OnHammered)

    MakeHauntableWork(inst)

    return inst
end

-------------------------------------------------------------------------------

local item_assets =
{
    Asset("ANIM", "anim/fence_electric.zip"),
}

local item_prefabs =
{
    "fence_electric",
}

local function OnDeployFence(inst, pt, deployer, rot)
    local wall = SpawnPrefab("fence_electric", inst.linked_skinname, inst.skin_id)
    if wall ~= nil then
        local x = math.floor(pt.x) + .5
        local z = math.floor(pt.z) + .5

        wall.Physics:SetCollides(false)
        wall.Physics:Teleport(x, 0, z)
        wall.Physics:SetCollides(true)
        inst.components.stackable:Get():Remove()

        wall.AnimState:PlayAnimation("place")
        wall.AnimState:PushAnimation("idle", false)
        wall.SoundEmitter:PlaySound("dontstarve/common/together/electric_fence/place")
    end
end

local function itemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("fencebuilder")

    inst.AnimState:SetBank("fence_electric")
    inst.AnimState:SetBuild("fence_electric")
    inst.AnimState:PlayAnimation("inventory")

    MakeInventoryFloatable(inst, "small", nil, 1.1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeployFence
    inst.components.deployable:SetDeployMode(DEPLOYMODE.WALL)

    MakeHauntableLaunch(inst)

    return inst
end

-------------------------------------------------------------------------------

local CIRCLE_RADIUS_SCALE = 1888 / 150 / 2 -- Source art size / anim_scale / 2 (halved to get radius).
local PLACER_SCALE = TUNING.ELECTRIC_FENCE_MAX_DIST / CIRCLE_RADIUS_SCALE -- Convert to rescaling for our desired range.

local function placer_postinit(inst)
    local placer2 = CreateEntity()

    --[[Non-networked entity]]
    placer2.entity:SetCanSleep(false)
    placer2.persists = false

    placer2.entity:AddTransform()
    placer2.entity:AddAnimState()

    placer2:AddTag("CLASSIFIED")
    placer2:AddTag("NOCLICK")
    placer2:AddTag("placer")

    placer2.AnimState:SetBank("firefighter_placement")
    placer2.AnimState:SetBuild("firefighter_placement")
    placer2.AnimState:PlayAnimation("idle")
    placer2.AnimState:SetLightOverride(1)
    placer2.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    placer2.AnimState:SetLayer(LAYER_BACKGROUND)
    placer2.AnimState:SetSortOrder(1)
    placer2.AnimState:SetScale(PLACER_SCALE, PLACER_SCALE)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)

    inst.AnimState:OverrideSymbol("swap_light", "fence_electric", "light_off")
    inst.AnimState:Hide("light")
    inst.AnimState:Hide("electricity")
end

return Prefab("fence_electric", fn, assets, prefabs),
    Prefab("fence_electric_item", itemfn, item_assets, item_prefabs),
    MakePlacer("fence_electric_item_placer", "fence_electric", "fence_electric", "idle", nil, nil, true, nil, 0, "eight", placer_postinit)