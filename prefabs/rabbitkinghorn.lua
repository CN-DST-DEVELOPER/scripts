local assets = {
    Asset("ANIM", "anim/rabbitkinghorn.zip"),
    Asset("SOUND", "sound/rifts4.fsb"),
}

local prefabs = {
    "rabbitkinghorn_chest",
}

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
local function NoHolesNoInvisibleTiles(pt)
    local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
    if GROUND_INVISIBLETILES[tile] then
        return false
    end

    return not TheWorld.Map:IsPointNearHole(pt)
end

local function ChestReturnPresentation(rabbitkinghorn_chest)
    rabbitkinghorn_chest:ReturnToScene()
end
local function OnPlayed(inst, musician)
    inst.rabbitkinghorn_shouldfiniteuses_use = true
    if musician:IsOnValidGround() then
        local x, y, z = musician.Transform:GetWorldPosition()
        local minradius = musician:GetPhysicsRadius(0) + 2
        for r = 4, 1, -1 do
            local offset = FindWalkableOffset(Vector3(x, y, z), math.random() * TWOPI, r + minradius + math.random(), 8, false, false, NoEnts, false, false)
            if offset then
                x, z = offset.x + x, offset.z + z
                break
            end
        end
        local rabbitkinghorn_chest = SpawnPrefab("rabbitkinghorn_chest")
        rabbitkinghorn_chest.Transform:SetPosition(x, y, z)
        rabbitkinghorn_chest:RemoveFromScene()
        rabbitkinghorn_chest:DoTaskInTime(1.3, ChestReturnPresentation)
    else
        inst.rabbitkinghorn_shouldfiniteuses_use = false
        inst.rabbitkinghorn_badspawnpoint = true
    end
end

local function OnHeard(inst, musician, instrument)
    if inst.components.farmplanttendable ~= nil then
        inst.components.farmplanttendable:TendTo(musician)
        inst.rabbitkinghorn_shouldfiniteuses_use = true
    end
end

local function UtterFailToSpawn(doer)
    doer.rabbitkinghorn_failtask = nil
    if doer.components.talker then
        doer.components.talker:Say(GetString(doer, "ANNOUNCE_RABBITKINGHORN_BADSPAWNPOINT"))
    end
end

local function UseModifier(uses, action, doer, target, item)
    if item then
        if item.rabbitkinghorn_badspawnpoint then
            item.rabbitkinghorn_badspawnpoint = nil
            if doer.components.talker and doer:HasTag("player") then
                if doer.rabbitkinghorn_failtask ~= nil then
                    doer.rabbitkinghorn_failtask:Cancel()
                    doer.rabbitkinghorn_failtask = nil
                end
                doer.rabbitkinghorn_failtask = doer:DoTaskInTime(2 + math.random() * 0.25, UtterFailToSpawn)
            end
        end
        if item.rabbitkinghorn_shouldfiniteuses_use then
            item.rabbitkinghorn_shouldfiniteuses_use = nil
            return 1
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

    inst.AnimState:SetBank("rabbitkinghorn")
    inst.AnimState:SetBuild("rabbitkinghorn")
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
    instrument:SetRange(TUNING.RABBITKINGHORN_RANGE)
    instrument:SetOnHeardFn(OnHeard)
    instrument:SetOnPlayedFn(OnPlayed)
    instrument:SetAssetOverrides("rabbitkinghorn", "rabbitkinghorn01", "rifts4/rabbit_horn/call")

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.PLAY)

    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(TUNING.RABBITKINGHORN_USES)
    finiteuses:SetUses(TUNING.RABBITKINGHORN_USES)
    finiteuses:SetOnFinished(inst.Remove)
    finiteuses:SetConsumption(ACTIONS.PLAY, 1)
    finiteuses:SetModifyUseConsumption(UseModifier)

    inst:AddComponent("inventoryitem")

    MakeHauntableLaunch(inst)

    --inst:ListenForEvent("floater_startfloating", function(inst) inst.AnimState:PlayAnimation("float") end)
    --inst:ListenForEvent("floater_stopfloating", function(inst) inst.AnimState:PlayAnimation("idle") end)

    return inst
end

return Prefab("rabbitkinghorn", fn, assets, prefabs)
