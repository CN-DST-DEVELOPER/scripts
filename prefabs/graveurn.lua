local assets =
{
    Asset("ANIM", "anim/graveurn.zip"),

    Asset("INV_IMAGE", "graveurn"),
    Asset("INV_IMAGE", "graveurn_empty"),
}

---------------------------------------------------------------------------------------------------------

local function DoFunnyIdle(inst)
    local rand = math.random(3)

    if rand == 1 then
        inst.AnimState:PlayAnimation("idle_pre")
        inst.AnimState:PushAnimation("idle", false)
        inst.AnimState:PushAnimation("idle_pst", false)
        inst.AnimState:PushAnimation("idle_empty")

    elseif rand == 2 then
        inst.AnimState:PlayAnimation("idle_2_pre")
        inst.AnimState:PushAnimation("idle_2", false)
        inst.AnimState:PushAnimation("idle_2_pst", false)
        inst.AnimState:PushAnimation("idle_empty")

    elseif rand == 3 then
        inst.AnimState:PlayAnimation("idle_pre")
        inst.AnimState:PushAnimation("idle_3", false)
        inst.AnimState:PushAnimation("idle_pst", false)
        inst.AnimState:PushAnimation("idle_empty")
    end

    inst.funnyidletask = inst:DoTaskInTime(7 + 5 * math.random(), DoFunnyIdle)
end

local function OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if inst.funnyidletask ~= nil then
        inst.funnyidletask:Cancel()
        inst.funnyidletask = nil
    end

    inst.funnyidletask = inst:DoTaskInTime(7 + 5 * math.random(), DoFunnyIdle)
end

local function OnEntitySleep(inst)
    if inst.funnyidletask ~= nil then
        inst.funnyidletask:Cancel()
        inst.funnyidletask = nil

        inst.AnimState:PlayAnimation("idle_empty")
    end
end

---------------------------------------------------------------------------------------------------

local function OnDeployed(inst, pt, deployer)
    local gravestone = inst._grave_record ~= nil and SpawnSaveRecord(inst._grave_record) or SpawnPrefab("gravestone")

    gravestone.Transform:SetPosition(pt:Get())
    gravestone.AnimState:PlayAnimation("grave"..gravestone.random_stone_choice.."_place")
    gravestone.AnimState:PushAnimation("grave"..gravestone.random_stone_choice)

    if deployer.SoundEmitter ~= nil then
        deployer.SoundEmitter:PlaySound("meta5/wendy/place_gravestone")
    end

    inst:Remove()
end

---------------------------------------------------------------------------------------------------

local function SetPlacerNetVars(inst)
    local record = inst._grave_record

    if record == nil then
        return
    end

    if record.skinname ~= nil then
        inst._placer_netvars.graveskin:set(record.skinname)
    end

    if record.data ~= nil then
        if record.data.stone_index ~= nil then
            inst._placer_netvars.graveid:set(record.data.stone_index)
        end

        if record.data.mounddata ~= nil and record.data.mounddata.data ~= nil and record.data.mounddata.data.dug then
            inst._placer_netvars.ismounddug:set(true)
        end
    end
end

local function SetGraveSaveData(inst, savedata)
    inst._grave_record = savedata

    inst.components.inventoryitem:ChangeImageName("graveurn")

    inst:RemoveComponent("gravedigger")

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeployed

    SetPlacerNetVars(inst)

    -------

    inst.OnEntityWake  = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("exitlimbo",  inst.OnEntityWake )
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)
end

local function OnGraveDiggerUsed(inst, user, target)
    local x, y, z = target.Transform:GetWorldPosition()

    -- This is here instead of on gravestone.lua so that we don't save the upgradeable data.
    local upgradeable = target.components.upgradeable

    if upgradeable ~= nil and upgradeable:GetStage() > 1 then
        upgradeable:SetStage(1)

        for _ = 1, TUNING.WENDYSKILL_GRAVESTONE_DECORATECOUNT do
            if math.random() >= 0.5 then
                local petals = SpawnPrefab("petals")
                petals.Transform:SetPosition(x, 0, z)
                Launch(petals, target, 1.5)
            end
        end
    end

    -------

    SetGraveSaveData(inst, target:GetSaveRecord())
end

---------------------------------------------------------------------------------------------------

local function GetStatus(inst)
    return inst._grave_record ~= nil and "HAS_SPIRIT" or nil
end

---------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.grave_record = inst._grave_record
end

local function OnLoad(inst, data)
    if data == nil or data.grave_record == nil then
        return
    end

    SetGraveSaveData(inst, data.grave_record)
end

---------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "small", 0.2, 0.75)

    inst.AnimState:SetBank("graveurn")
    inst.AnimState:SetBuild("graveurn")
    inst.AnimState:PlayAnimation("idle_empty")

    inst:AddTag("graveplanter")

    inst._placer_netvars =
    {
        graveskin = net_hash(inst.GUID, "graveurn._placer_netvars.graveskin"),
        graveid = net_tinybyte(inst.GUID, "graveurn._placer_netvars.graveid"),
        ismounddug = net_bool(inst.GUID, "graveurn._placer_netvars.ismounddug"),
    }

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("gravedigger")
    inst.components.gravedigger.onused = OnGraveDiggerUsed

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("graveurn_empty")

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

---------------------------------------------------------------------------------------------------

local function Placer_OnSetBuilder(inst)
    local invobject = inst.components.placer.invobject

    if invobject == nil or invobject._placer_netvars == nil then
        return
    end

    local skinbuild  = invobject._placer_netvars.graveskin:value()
    local graveid    = invobject._placer_netvars.graveid:value()
    local ismounddug = invobject._placer_netvars.ismounddug:value()

    if skinbuild ~= nil and skinbuild ~= 0 then
        skinbuild = TheInventory:LookupSkinname(skinbuild) -- Because skinbuild is a hash!

        if skinbuild ~= nil then
            inst.AnimState:SetSkin(skinbuild, "gravestones")
        end
    end

    if graveid ~= nil and graveid ~= 0 then
        inst.AnimState:PlayAnimation("grave" ..tostring(graveid))
    end

    if ismounddug then
        inst._mound.AnimState:PlayAnimation("dug")
    end
end

-- NOTES(DiogoW): This used to be TheCamera:GetDownVec()*.5, probably legacy code from DS,
-- since TheCamera:GetDownVec() would always return the values below.
local MOUND_POSITION_OFFSET = { 0.35355339059327, 0, 0.35355339059327 }

local function CreateMoundPlacer()
    local mound = CreateEntity()

    --[[Non-networked entity]]
    mound.entity:SetCanSleep(false)
    mound.persists = false

    mound.entity:AddTransform()
    mound.entity:AddAnimState()

    mound:AddTag("CLASSIFIED")
    mound:AddTag("NOCLICK")
    mound:AddTag("placer")

    mound.AnimState:SetBank("gravestone")
    mound.AnimState:SetBuild("gravestones")
    mound.AnimState:PlayAnimation("gravedirt")

    mound.Transform:SetPosition(unpack(MOUND_POSITION_OFFSET))

    return mound
end

local function PlacerPostinit(inst)
    inst.AnimState:Hide("flower")

    if inst.components.placer ~= nil then
        inst.components.placer.onbuilderset = Placer_OnSetBuilder
    end

    inst._mound = CreateMoundPlacer()
    inst._mound.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(inst._mound)
end

---------------------------------------------------------------------------------------------------

return
    Prefab("graveurn", fn, assets),
    MakePlacer("graveurn_placer", "gravestone", "gravestones", "grave1", nil, nil, nil, nil, nil, nil, PlacerPostinit)