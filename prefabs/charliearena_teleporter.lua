local assets = {
	Asset("ANIM", "anim/charliearena_teleporter.zip"),
	Asset("ANIM", "anim/charliearena_teleporter_ground.zip"),
}

local prefabs =
{
	"atrium_portal_fx",
}

--------------------------------------------------------------------------

local function CreateBase()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:SetCanSleep(TheWorld.ismastersim)

    inst.Transform:SetEightFaced()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("charliearena_teleporter_ground")
	inst.AnimState:SetBuild("charliearena_teleporter_ground")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-1)

	inst.persists = false

	return inst
end

local function DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("appear") then
		local t = inst.AnimState:GetCurrentAnimationTime()
        inst.base.AnimState:PlayAnimation("open")
        inst.base.AnimState:SetTime(t)
        inst.base.AnimState:PushAnimation("idle")
	end

	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(DoSyncAnim)
	end
end

local function OnSyncAnim(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(DoSyncAnim)
	end
end

local function PushSyncAnim(inst)
	inst.syncanim:push()
	if inst.base then
		DoSyncAnim(inst)
	end
end

--------------------------------------------------------------------------

local function OnCameraFocusDirty(inst)
	local player = TheFocalPoint.entity:GetParent()
	if inst.camerafocus:value() and player and
		TheWorld.Map:IsPointInCharlieBossArena(player.Transform:GetWorldPosition()) and
		TheWorld.Map:IsPointInCharlieBossArena(inst.Transform:GetWorldPosition())
	then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 20, 200, 5)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function EnableCameraFocus(inst, enable)
	if inst.camerafocustask then
		inst.camerafocustask:Cancel()
		inst.camerafocustask = nil
	end
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

local function IsInArena(v)
	return TheWorld.Map:IsPointInCharlieBossArena(v.Transform:GetWorldPosition())
end

local function TeleportDestinationPositionOverride(inst, ent)
    return nil, nil, nil
end

local function OnStartChanneling(inst, doer)
	if not (inst.AnimState:IsCurrentAnimation("idle_on_loop") or
			inst.AnimState:IsCurrentAnimation("turn_on"))
	then
		inst.AnimState:PlayAnimation("turn_on")
		inst.AnimState:PushAnimation("idle_on_loop")
	end
	if not inst.SoundEmitter:PlayingSound("loop") then
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/turn_on_powered_LP", "loop")
	end

    inst.components.virtualroomteleporter:StartRoomVote(doer)
end

local function OnStopChanneling(inst, aborted, doer)
	if not (inst.components.channelable:IsChanneling() or
			inst.AnimState:IsCurrentAnimation("idle_off") or
			inst.AnimState:IsCurrentAnimation("turn_off"))
	then
		inst.AnimState:PlayAnimation("turn_off")
		inst.AnimState:PushAnimation("idle_off", true)
	end
	inst.SoundEmitter:KillSound("loop")

    inst.components.virtualroomteleporter:StopRoomVote(doer)
end

local function CheckForNearbyGhosts(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, 12, false)
    for _, player in ipairs(players) do
        if not inst.nearbyghosts[player] then
            inst.nearbyghosts[player] = true
            OnStartChanneling(inst, player)
        end
    end
    for player, _ in pairs(inst.nearbyghosts) do
        if not table.contains(players, player) then
            inst.nearbyghosts[player] = nil
            OnStopChanneling(inst, true, player)
        end
    end
end

local function OnHaunt(inst, doer)
    if not inst.ghostcountstask then
        inst.nearbyghosts = {}
        inst.ghostcountstask = inst:DoPeriodicTask(0.25, inst.CheckForNearbyGhosts)
        inst:CheckForNearbyGhosts()
    end
    return true
end

local function OnUnHaunt(inst)
    if inst.ghostcountstask then
        inst.ghostcountstask:Cancel()
        inst.ghostcountstask = nil
    end
    if inst.nearbyghosts then
        for player, _ in pairs(inst.nearbyghosts) do
            inst.nearbyghosts[player] = nil
            OnStopChanneling(inst, true, player)
        end
        inst.nearbyghosts = nil
    end
end

local function AddHauntable(inst)
    if not inst.components.hauntable then
        inst:AddComponent("hauntable")
        inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_HUGE
        inst.components.hauntable:SetOnHauntFn(OnHaunt)
        inst.components.hauntable:SetOnUnHauntFn(OnUnHaunt)
    end
end

local function RemoveHauntable(inst)
	if inst.components.hauntable then
		if inst.components.hauntable.onunhaunt then
			inst.components.hauntable.onunhaunt(inst)
		end
		inst:RemoveComponent("hauntable")
	end
end

--V2C: doing this instead of putting the sound on the fx, so we don't have so many sound instances.
local function OnDepart(inst, virtualroomset)
	virtualroomset:FlagForReset() -- we only reset when teleporting out through the hole
end

local function SetOpen(inst)
	if inst.opentask then
		inst.opentask:Cancel()
		inst.opentask = nil
		inst.SoundEmitter:KillSound("rumble")
	end
	inst:RemoveEventCallback("animover", SetOpen)
    inst:RemoveTag("NOCLICK")
	inst.AnimState:PlayAnimation("idle_off", true)
	inst.Light:Enable(true)
    inst.Physics:SetActive(true)
    inst.components.channelable:SetEnabled(true)
	if inst.camerafocustask == nil then
		EnableCameraFocus(inst, false)
	end
end

local function DoOpenAnim(inst)
    inst.opentask = nil
	inst.SoundEmitter:KillSound("rumble")
    inst:Show()
	inst.Light:Enable(true)
	inst.Physics:SetActive(true)
	inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/glass_break")
	inst.AnimState:PlayAnimation("appear")
	LaunchArea(inst, 1.8, 1, 0.75, 0.5, 1.5)
	inst:RemoveEventCallback("animover", SetOpen)
	inst:ListenForEvent("animover", SetOpen)
	PushSyncAnim(inst)
	if IsInArena(inst) then
		EnableCameraFocus(inst, true)
		inst.camerafocustask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.4, EnableCameraFocus, false)
		ShakeAllCamerasWithFilter(IsInArena, CAMERASHAKE.FULL, 0.9, 0.03, 0.22, inst, 1000)
	elseif inst.camerafocustask then
		inst.camerafocustask:Cancel()
		inst.camerafocustask = nil
	end
end

local function Open(inst)
    if inst.opentask == nil then
        inst:Hide()
        inst.opentask = inst:DoTaskInTime(1, DoOpenAnim)
		inst.SoundEmitter:PlaySound("dontstarve/tentacle/tentacle_rumble_LP", "rumble")
        if IsInArena(inst) then
			EnableCameraFocus(inst, true)
			ShakeAllCamerasWithFilter(IsInArena, CAMERASHAKE.FULL, 2, 0.025, 0.1, inst, 1000)
		end
    end
end

local function OnEntityWake(inst)
    inst.OnEntityWake = nil
	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("charliearena_teleporter.syncanim", OnSyncAnim)
	end
	OnCameraFocusDirty(inst) -- position is set now
    DoSyncAnim(inst)
end

local function OnAdd(inst)
    inst.inittask = nil
	TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.ATRIUM, context = VIRTUALROOMCONTEXT.TELEPORTER})
end

local function OnForceRegisterEntity(inst)
    if inst.inittask then
        inst.inittask:Cancel()
        OnAdd(inst)
    end
end

local function OnLoad(inst, data)
    inst.components.virtualroomteleporter:OnForceRegisterEntity()
end

local function OnRemove(inst)
	TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.ATRIUM, context = VIRTUALROOMCONTEXT.TELEPORTER})
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("charliearena_teleporter.png")

    inst.Light:SetRadius(2.5)
    inst.Light:SetIntensity(.9)
    inst.Light:SetFalloff(.9)
    inst.Light:SetColour(255/255, 178/255, 184/255)
    inst.Light:Enable(true)

    MakeObstaclePhysics(inst, 1)
	inst.Physics:ClearCollidesWith(COLLISION.GIANTS)

	inst.AnimState:SetBank("charliearena_teleporter")
	inst.AnimState:SetBuild("charliearena_teleporter")
    inst.AnimState:PlayAnimation("idle_off", true)

    inst:AddTag("virtualroomteleporter")

    -- Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.base = CreateBase()
		inst.base.entity:SetParent(inst.entity)
		inst.highlightchildren = { inst.base }
        inst.OnEntityWake = OnEntityWake
	end

    inst.camerafocus = net_bool(inst.GUID, "charliearena_teleporter.camerafocus", "camerafocusdirty")
	inst.syncanim = net_event(inst.GUID, "charliearena_teleporter.syncanim")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)
        return inst
    end

    local virtualroomteleporter = inst:AddComponent("virtualroomteleporter")
    virtualroomteleporter:SetRoomSetName(VIRTUALROOMSETS.ATRIUM)
    virtualroomteleporter:SetDirection(VIRTUALROOMDIRECTIONS.OUT)
    virtualroomteleporter:SetTeleportFXPrefab("atrium_portal_fx")
    virtualroomteleporter:SetOnDepart(OnDepart)
    virtualroomteleporter:SetOnForceRegisterEntity(OnForceRegisterEntity)
    virtualroomteleporter:SetTeleportDestinationPositionOverride(TeleportDestinationPositionOverride)

    inst:AddComponent("channelable")
    inst.components.channelable:SetChannelingFn(OnStartChanneling, OnStopChanneling)
    inst.components.channelable:SetMultipleChannelersAllowed(true)

    inst:AddComponent("inspectable")

    inst.Open = Open
    inst.AddHauntable = AddHauntable
	inst.RemoveHauntable = RemoveHauntable
    inst:AddHauntable()

    inst.CheckForNearbyGhosts = CheckForNearbyGhosts

    inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
    inst.OnLoad = OnLoad
    inst:ListenForEvent("onremove", OnRemove)

    return inst
end

return Prefab("charliearena_teleporter", fn, assets, prefabs)
