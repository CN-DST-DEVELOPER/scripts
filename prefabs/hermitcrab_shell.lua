local assets = {
    Asset("ANIM", "anim/hermitcrab_shell.zip"),
    --Asset("SOUND", "sound/rifts4.fsb"),
}

local prefabs = {
    "hermitcrab_fx_med",
}

local TELEPORT_START_DELAY = 33 * FRAMES -- 1 less than SGWilson's play_horn sg state busy state remove.
local TELEPORT_TIME_FX_SYNC = 12 * FRAMES

local function ArrivedFromTeleport(musician)
    musician.hermitcrab_shell_arrivedtask = nil
    if musician.components.talker then
        musician.components.talker:Say(GetString(musician, "ANNOUNCE_HERMITCRAB_SHELL_ARRIVE"))
    end
end
local function EndTeleport(musician)
    if musician.components.inventory and musician.components.inventory:IsHeavyLifting() then
        musician.components.inventory:DropItem(
            musician.components.inventory:Unequip(EQUIPSLOTS.BODY),
            true,
            true
        )
    end

    if musician:HasTag("player") then
        musician.sg.statemem.teleport_task = nil
        musician.sg:GoToState(musician:HasTag("playerghost") and "appear" or "wakeup")
        musician.hermitcrab_shell_arrivedtask = musician:DoTaskInTime(1.5 + math.random() * 0.25, ArrivedFromTeleport)
    else
        musician:Show()
        if musician.DynamicShadow then
            musician.DynamicShadow:Enable(true)
        end
        if musician.components.health then
            musician.components.health:SetInvincible(false)
        end
        musician:PushEvent("teleported")
    end
end

local function ContinueTeleport(musician, x, y, z)
    SpawnPrefab("hermitcrab_fx_med").Transform:SetPosition(x, y, z)
    if musician.Physics then
        musician.Physics:Teleport(x, y, z)
    else
        musician.Transform:SetPosition(x, y, z)
    end
    musician:PushEvent("teleport_move")

    if musician.components.moisture then
        local waterproofness = musician.components.moisture:GetWaterproofness()
        musician.components.moisture:DoDelta(TUNING.HERMITCRAB_SHELL_ADD_WETNESS * (1 - waterproofness))
    end

    if musician:HasTag("player") then
        musician:SnapCamera()
        musician:ScreenFade(true, 1)
        musician.sg.statemem.teleport_task = musician:DoTaskInTime(TELEPORT_TIME_FX_SYNC, EndTeleport)
    else
        EndTeleport(musician)
    end
end

local function StartTeleport(musician, x, y, z)
    if musician.components.locomotor then
        musician.components.locomotor:StopMoving()
    end
    local ex, ey, ez = musician.Transform:GetWorldPosition()
    if musician:HasTag("player") then
        musician.sg:GoToState("forcetele")
        musician.sg.statemem.teleport_task = musician:DoTaskInTime(TELEPORT_TIME_FX_SYNC, ContinueTeleport, x, y, z)
    else
        if musician.components.health then
            musician.components.health:SetInvincible(true)
        end
        if musician.DynamicShadow then
            musician.DynamicShadow:Enable(false)
        end
        musician:Hide()
        ContinueTeleport(musician, x, y, z)
    end
end

local CANT_TAGS = {"INLIMBO", "NOCLICK", "FX"}
local function NoEnts(pt)
    local x, y, z = pt:Get()
    local ents = TheSim:FindEntities(x, y, z, MAX_PHYSICS_RADIUS, nil, CANT_TAGS)
    for _, ent in ipairs(ents) do
        local radius = ent:GetPhysicsRadius(0)
        if ent:GetDistanceSqToPoint(x, y, z) < radius * radius then
            return false
        end
    end
    return true
end

local function StartTeleportFX(musician, x, y, z)
    SpawnPrefab("hermitcrab_fx_med").Transform:SetPosition(x, y, z)
end

local function OnPlayed(inst, musician)
    inst.hermitcrab_shell_shouldfiniteuses_use = true
    local hermitcrab_relocation_manager = TheWorld.components.hermitcrab_relocation_manager
    local pearlshouse = hermitcrab_relocation_manager and hermitcrab_relocation_manager:GetPearlsHouse() or nil
    local x, y, z = musician.Transform:GetWorldPosition()
    local no_teleport = musician:HasTag("noteleport") or not IsTeleportLinkingPermittedFromPoint(x, y, z)
    if pearlshouse and not no_teleport then
        local destx, desty, destz = pearlshouse.Transform:GetWorldPosition()
        local minradius = musician:GetPhysicsRadius(0) + 2
        for r = 6, 1, -1 do
            local offset = FindWalkableOffset(Vector3(destx, desty, destz), math.random() * TWOPI, r + minradius + math.random(), 8, false, false, NoEnts, false, false)
            if offset then
                destx, destz = offset.x + destx, offset.z + destz
                break
            end
        end
        musician:DoTaskInTime(TELEPORT_START_DELAY - TELEPORT_TIME_FX_SYNC, StartTeleportFX, x, y, z)
        musician:DoTaskInTime(TELEPORT_START_DELAY, StartTeleport, destx, desty, destz)
    else
        inst.hermitcrab_shell_shouldfiniteuses_use = false
        inst.hermitcrab_shell_badteleportpoint = true
    end
end

local function OnHeard(inst, musician, instrument)
    if inst.components.farmplanttendable ~= nil then
        inst.components.farmplanttendable:TendTo(musician)
        instrument.hermitcrab_shell_shouldfiniteuses_use = true
    end
end

local function UtterFailToTeleport(doer)
    doer.hermitcrab_shell_failtask = nil
    if doer.components.talker then
        doer.components.talker:Say(GetString(doer, "ANNOUNCE_HERMITCRAB_SHELL_BADTELEPORTPOINT"))
    end
end

local function UseModifier(uses, action, doer, target, item)
    if item then
        if item.hermitcrab_shell_badteleportpoint then
            item.hermitcrab_shell_badteleportpoint = nil
            if doer.components.talker and doer:HasTag("player") then
                if doer.hermitcrab_shell_failtask ~= nil then
                    doer.hermitcrab_shell_failtask:Cancel()
                    doer.hermitcrab_shell_failtask = nil
                end
                doer.hermitcrab_shell_failtask = doer:DoTaskInTime(2 + math.random() * 0.25, UtterFailToTeleport)
            end
        end
        if item.hermitcrab_shell_shouldfiniteuses_use then
            item.hermitcrab_shell_shouldfiniteuses_use = nil
            return uses
        end
    end
    return 0
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("horn")

    inst.AnimState:SetBank("hermitcrab_shell")
    inst.AnimState:SetBuild("hermitcrab_shell")
    inst.AnimState:PlayAnimation("idle")

    --tool (from tool component) added to pristine state for optimization
    inst:AddTag("tool")

    MakeInventoryFloatable(inst, "small", 0.3, 1.3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local instrument = inst:AddComponent("instrument")
    instrument:SetRange(TUNING.HERMTICRAB_SHELL_RANGE)
    instrument:SetOnHeardFn(OnHeard)
    instrument:SetOnPlayedFn(OnPlayed)
    instrument:SetAssetOverrides("hermitcrab_shell", "hermitcrab_shell01", "hookline_2/hermitcrab_shell_teleport/use")

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.PLAY)

    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(TUNING.HERMITCRAB_SHELL_USES)
    finiteuses:SetUses(TUNING.HERMITCRAB_SHELL_USES)
    finiteuses:SetOnFinished(inst.Remove)
    finiteuses:SetConsumption(ACTIONS.PLAY, 1)
    finiteuses:SetModifyUseConsumption(UseModifier)

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("hermitcrab_shell", fn, assets, prefabs)
