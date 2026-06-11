local assets = {
	Asset("ANIM", "anim/vault_switch.zip"),
	Asset("MINIMAP_IMAGE", "vault_switch"),
}

local STATES = {
    INACTIVE = 0,
    ACTIVE = 1,
}

local DOOR_WAIT_TIME_START = 1.5
local DOOR_WAIT_TIME_STOP = 0.75
local MIST_TIME_SECONDS = 4
-- TOTAL_WAIT_TIME == DOOR_WAIT_TIME_START + MIST_TIME_SECONDS + DOOR_WAIT_TIME_STOP

local function SetDoorStates(inst, instantly)
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
    local door1 = inst.components.entitytracker:GetEntity("door1")
    local door2 = inst.components.entitytracker:GetEntity("door2")
    local sanityadjuster = inst.components.entitytracker:GetEntity("sanityadjuster")
    if inst.state == inst.STATES.INACTIVE then
        if door1 then
            door1:RetractWall(instantly)
        end
        if door2 then
            door2:ExtendWall(instantly)
        end
        if sanityadjuster then
            sanityadjuster:TurnOff()
        end
    elseif inst.state == inst.STATES.ACTIVE then
        if door1 then
            door1:ExtendWall(instantly)
        end
        if door2 then
            door2:RetractWall(instantly)
        end
        if sanityadjuster then
            sanityadjuster:StartIncreasing()
        end
    end
    inst.components.activatable.inactive = true
end

local function TryToStopMisting(inst, mistname)
    local mist = inst.components.entitytracker:GetEntity(mistname)
    if mist then
        mist:StopMisting()
    end
end
local function StopMisting(inst)
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
    TryToStopMisting(inst, "mist1")
    TryToStopMisting(inst, "mist2")
    TryToStopMisting(inst, "mist3")
    TryToStopMisting(inst, "mist4")
    inst.task = inst:DoTaskInTime(DOOR_WAIT_TIME_STOP, inst.SetDoorStates)
end

local function TryToStartMisting(inst, mistname)
    local mist = inst.components.entitytracker:GetEntity(mistname)
    if mist then
        mist:StartMisting()
    end
end
local function StartMisting(inst)
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
    TryToStartMisting(inst, "mist1")
    TryToStartMisting(inst, "mist2")
    TryToStartMisting(inst, "mist3")
    TryToStartMisting(inst, "mist4")
    local sanityadjuster = inst.components.entitytracker:GetEntity("sanityadjuster")
    if sanityadjuster then
        sanityadjuster:StartIncreasing()
    end
    inst.task = inst:DoTaskInTime(MIST_TIME_SECONDS, inst.StopMisting)
end

local function OnActivate(inst, doer)
    inst.AnimState:PlayAnimation("activate")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("rifts6/lever/pull")

    inst:ToggleState()
    return true
end

local function ToggleState(inst)
    if inst.state == inst.STATES.INACTIVE then
        inst:SetState(inst.STATES.ACTIVE)
    elseif inst.state == inst.STATES.ACTIVE then
        inst:SetState(inst.STATES.INACTIVE)
    end
end

local function SetState(inst, state, instantly)
    if inst.state ~= state then
        inst.state = state
        if inst.state == inst.STATES.INACTIVE then
            local door1 = inst.components.entitytracker:GetEntity("door1")
            local door2 = inst.components.entitytracker:GetEntity("door2")
            if instantly then
                if door1 then
                    door1:RetractWall(true)
                end
                if door2 then
                    door2:ExtendWall(true)
                end
                local sanityadjuster = inst.components.entitytracker:GetEntity("sanityadjuster")
                if sanityadjuster then
                    sanityadjuster:TurnOff()
                end
            else
                if door1 then
                    door1:ExtendWall()
                end
                if door2 then
                    door2:ExtendWall()
                end
                if inst.task then
                    inst.task:Cancel()
                    inst.task = nil
                end
                inst.task = inst:DoTaskInTime(DOOR_WAIT_TIME_START, inst.StartMisting)
            end
        elseif inst.state == inst.STATES.ACTIVE then
            local door1 = inst.components.entitytracker:GetEntity("door1")
            local door2 = inst.components.entitytracker:GetEntity("door2")
            if instantly then
                if door1 then
                    door1:ExtendWall(true)
                end
                if door2 then
                    door2:RetractWall(true)
                end
                local sanityadjuster = inst.components.entitytracker:GetEntity("sanityadjuster")
                if sanityadjuster then
                    sanityadjuster:StartIncreasing()
                end
            else
                if door1 then
                    door1:ExtendWall()
                end
                if door2 then
                    door2:ExtendWall()
                end
                if inst.task then
                    inst.task:Cancel()
                    inst.task = nil
                end
                inst.task = inst:DoTaskInTime(DOOR_WAIT_TIME_START, inst.StartMisting)
            end
        end
    end
end

local function GetActivateVerb(inst, doer)
    return "PULL"
end

local function OnSave(inst, data)
    data.state = inst.state
end

local function OnLoad(inst, data, ents)
    if data then
        if data.state then
            inst:SetState(data.state, true)
        end
    end
end

local function OnLoadPostPass(inst, newents, savedata)
    inst:SetDoorStates(true)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeSmallObstaclePhysics(inst, 0.5)

    inst.MiniMapEntity:SetIcon("vault_switch.png")

    inst.Transform:SetTwoFaced()

    inst.AnimState:SetBank("vault_switch")
    inst.AnimState:SetBuild("vault_switch")
    inst.AnimState:PlayAnimation("idle")

    inst.GetActivateVerb = GetActivateVerb
    inst:SetPrefabNameOverride("abysspillar_trial")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_proxy = "abysspillar_trial"

    inst:AddComponent("inspectable")

    local activatable = inst:AddComponent("activatable")
    activatable.OnActivate = OnActivate
    activatable.standingaction = true

    inst:AddComponent("entitytracker")

    inst.STATES = STATES
    inst.state = inst.STATES.INACTIVE
    inst.SetState = SetState
    inst.ToggleState = ToggleState
    inst.StartMisting = StartMisting
    inst.StopMisting = StopMisting
    inst.SetDoorStates = SetDoorStates

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

-------------------------------------------------------------------

local function OnAnimQueueOver_Reset(inst)
    inst:RemoveEventCallback("animqueueover", OnAnimQueueOver_Reset)
    inst.components.activatable.inactive = true

    local switch = inst.components.entitytracker:GetEntity("switch")
    if switch then
        switch:SetState(switch.STATES.INACTIVE)
    end
end

local function OnActivate_Reset(inst)
    inst.AnimState:PlayAnimation("activate")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("rifts6/lever/pull")

    inst:ListenForEvent("animqueueover", OnAnimQueueOver_Reset)
    return true
end

local function fn_reset()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeSmallObstaclePhysics(inst, 0.5)

    inst.MiniMapEntity:SetIcon("vault_switch.png")

    inst.Transform:SetTwoFaced()

    inst.AnimState:SetBank("vault_switch")
    inst.AnimState:SetBuild("vault_switch")
    inst.AnimState:PlayAnimation("idle")

    inst.GetActivateVerb = GetActivateVerb
    inst:SetPrefabNameOverride("abysspillar_trial")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_proxy = "abysspillar_trial"

    inst:AddComponent("inspectable")

    local activatable = inst:AddComponent("activatable")
    activatable.OnActivate = OnActivate_Reset
    activatable.standingaction = true

    inst:AddComponent("entitytracker")

    return inst
end

-------------------------------------------------------------------

local function OnAnimQueueOver_Reset2(inst)
    inst:RemoveEventCallback("animqueueover", OnAnimQueueOver_Reset2)
    inst.components.activatable.inactive = true

    local switch = inst.components.entitytracker:GetEntity("switch")
    if switch then
        switch:SetState(switch.STATES.ACTIVE)
    end
end

local function OnActivate_Reset2(inst)
    inst.AnimState:PlayAnimation("activate")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound("rifts6/lever/pull")

    inst:ListenForEvent("animqueueover", OnAnimQueueOver_Reset2)
    return true
end

local function fn_reset2()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeSmallObstaclePhysics(inst, 0.5)

    inst.MiniMapEntity:SetIcon("vault_switch.png")

    inst.Transform:SetTwoFaced()

    inst.AnimState:SetBank("vault_switch")
    inst.AnimState:SetBuild("vault_switch")
    inst.AnimState:PlayAnimation("idle")

    inst.GetActivateVerb = GetActivateVerb
    inst:SetPrefabNameOverride("abysspillar_trial")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_proxy = "abysspillar_trial"

    inst:AddComponent("inspectable")

    local activatable = inst:AddComponent("activatable")
    activatable.OnActivate = OnActivate_Reset2
    activatable.standingaction = true

    inst:AddComponent("entitytracker")

    return inst
end

return Prefab("vault_decon_switch", fn, assets),
    Prefab("vault_decon_switch_reset", fn_reset, assets),
    Prefab("vault_decon_switch_reset2", fn_reset2, assets)