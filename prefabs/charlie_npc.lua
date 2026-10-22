local assets =
{
    Asset("ANIM", "anim/charlie_basic.zip"),
    Asset("ANIM", "anim/charlie_transform.zip"),
}

local function OnCameraFocusDirty(inst)
    if inst._camerafocus:value() then
        TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 10, 28, 5)
    else
        TheFocalPoint.components.focalpoint:StopFocusSource(inst)
    end
end

local function EnableCameraFocus(inst, enable)
    if enable ~= inst._camerafocus:value() then
        inst._camerafocus:set(enable)
        if not TheNet:IsDedicated() then
            OnCameraFocusDirty(inst)
        end
    end
end

local function OnTransformMusic(inst)
	if ThePlayer then
		local roomsetname = VIRTUALROOMSETS.ATRIUM
		local x, y, z = ThePlayer.Transform:GetWorldPosition()
		if TheWorld.Map:IsPointInVirtualRoomSet(roomsetname, x, y, z) and TheWorld.Map:IsVirtualRoomSetInLobby(roomsetname) then
			TheFocalPoint.SoundEmitter:PlaySound("dontstarve/music/music_epicfight_charlie_intro")
		end
	end
end

local function TriggerTransformMusic(inst)
	inst._transformmusic:push()
	if not TheNet:IsDedicated() then
		OnTransformMusic(inst)
	end
end

local function OnRemove(inst)
    -- Charliecutscene cmp save/load will handle this not running.
    if inst.atrium ~= nil and inst.atrium.components.charliecutscene ~= nil then
        if inst.socketing_key then
            inst.atrium.components.charliecutscene:FinishKeySocket()
        else
            inst.atrium.components.charliecutscene:Finish()
        end
    end
end

local function StartCastingWithDelay(inst, delay, cast_time, nodespawn)
    inst:PushEventInTime(delay, "casting")
    inst:PushEventInTime(delay + cast_time, "stop_casting", { despawn = not nodespawn })
end

local function StartCasting2WithDelay(inst, delay, cast_time)
    inst.components.npc_talker:Chatter("CHARLIE_NPC_SACRIFICE_REQUEST")
    inst:PushEventInTime(delay, "casting2")
    inst:PushEventInTime(delay + cast_time, "stop_casting")
end

local function GetStatus(inst)--, viewer)
    return (inst.socketing_key or inst.scene2) and "SCENE2"
        or nil
end

local function OnEntityWake(inst)
	inst.OnEntityWake = nil
    inst.SoundEmitter:PlaySound("rifts2/charlie/charlie_amb", "loop")
end

local function OnDoneTalking(inst)
    if inst.talktask ~= nil then
        inst.talktask:Cancel()
        inst.talktask = nil
    end
    inst.SoundEmitter:KillSound("talk")
end

local function OnTalk(inst)
    OnDoneTalking(inst)
    inst.SoundEmitter:PlaySound("dontstarve/charlie/talk_LP", "talk")
    local timeouttalk = (2 + math.random() * .5)
    inst.talktask = inst:DoTaskInTime(timeouttalk, OnDoneTalking)
end

local function DisplayNameFn(inst)
    return ThePlayer ~= nil and CHARACTER_KNOWS_CHARLIE[ThePlayer.prefab]
        and STRINGS.NAMES[string.upper(inst.prefab)]
        or STRINGS.NAMES[string.upper(inst.prefab.."_ALT")]
end

local CHARLIE_NAME_COLOUR = Vector3(234/255, 69/255, 75/255)
local CHARLIE_TEXT_COLOUR = Vector3(255/255, 103/255, 94/255)
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 0.5)

    inst.DynamicShadow:SetSize(3, 2)
    inst.DynamicShadow:Enable(true)

    inst.Transform:SetTwoFaced()

    inst.AnimState:SetBank("charlie_basic")
    inst.AnimState:SetBuild("charlie_basic")
    inst.AnimState:PlayAnimation("idle", true)

	inst:AddTag("character")
    inst:AddTag("charlie_npc")

    local talker = inst:AddComponent("talker")
    talker.fontsize = 50
    talker.font = TALKINGFONT_CHARLIE
    talker.offset = Vector3(0, -600, 0)
    talker.name_colour = CHARLIE_NAME_COLOUR
    talker.colour = CHARLIE_TEXT_COLOUR
    talker.chaticon = "npcchatflair_charlie"
    talker:MakeChatter()

    local npc_talker = inst:AddComponent("npc_talker")
    npc_talker.default_chatpriority = CHATPRIORITIES.HIGH
    npc_talker.speaktime = 3

    inst._camerafocus = net_bool(inst.GUID, "charlie_npc._camerafocus", "camerafocusdirty")
	inst._transformmusic = net_event(inst.GUID, "charlie_npc._transformmusic")

    inst.entity:SetPristine()

    inst.displaynamefn = DisplayNameFn

    if not TheWorld.ismastersim then
        inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)
		inst:DoTaskInTime(0, inst.ListenForEvent, "charlie_npc._transformmusic", OnTransformMusic)

        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus
    inst.persists = false
    inst.StartCastingWithDelay = StartCastingWithDelay
    inst.StartCasting2WithDelay = StartCasting2WithDelay
    inst.OnRemoveEntity = OnRemove
    inst.OnEntityWake = OnEntityWake

    inst.EnableCameraFocus = EnableCameraFocus
	inst.TriggerTransformMusic = TriggerTransformMusic

    inst:SetStateGraph("SGcharlie_npc")
    inst:ListenForEvent("ontalk", OnTalk)
    inst:ListenForEvent("donetalking", OnDoneTalking)

    return inst
end

return Prefab("charlie_npc", fn, assets)