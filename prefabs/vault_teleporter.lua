local assets = {
	Asset("ANIM", "anim/vault_portal.zip"),
	Asset("ANIM", "anim/vault_portal_ground.zip"),
}

local prefabs =
{
	"vault_orb",
	"vault_portal_fx",
}

--------------------------------------------------------------------------

local LOBBY_TO_OR_FROM_VAULT = "lobby_or_vault"

local DIRS =
{
	N = 0,
	E = 1,
	S = 2,
	W = 3,
}

local function SetCode(inst, pos, dir)
	for k in pairs(DIRS) do
		if k == dir then
			inst.AnimState:Show(pos..k)
		else
			inst.AnimState:Hide(pos..k)
		end
	end
end

local function ConfigureBaseCode(inst, dir)
	if dir == DIRS.W then
		SetCode(inst, "M", "E")
		SetCode(inst, "L", "S")
		SetCode(inst, "R", "N")
	elseif dir == DIRS.S then
		SetCode(inst, "M", "N")
		SetCode(inst, "L", "E")
		SetCode(inst, "R", "W")
	elseif dir == DIRS.E then
		SetCode(inst, "M", "W")
		SetCode(inst, "L", "N")
		SetCode(inst, "R", "S")
	else
		SetCode(inst, "M", "S")
		SetCode(inst, "L", "W")
		SetCode(inst, "R", "E")
	end
end

local function CreateBase()
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:SetCanSleep(TheWorld.ismastersim)

	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("vault_portal_ground")
	inst.AnimState:SetBuild("vault_portal_ground")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-3)

	ConfigureBaseCode(inst, DIRS.N)

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function OnStartChanneling(inst, channeler)
	if not (inst.AnimState:IsCurrentAnimation("idle_on_loop") or
			inst.AnimState:IsCurrentAnimation("turn_on"))
	then
		inst.AnimState:PlayAnimation("turn_on")
		inst.AnimState:PushAnimation("idle_on_loop")
	end
	if not inst.SoundEmitter:PlayingSound("loop") then
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/turn_on_powered_LP", "loop")
	end
    TheWorld:PushEvent("ms_vault_teleporter_channel_start", {inst = inst, doer = channeler})
end

local function OnStopChanneling(inst, aborted, channeler)
	if not (inst.components.channelable:IsChanneling() or
			inst.AnimState:IsCurrentAnimation("idle_off") or
			inst.AnimState:IsCurrentAnimation("turn_off"))
	then
		inst.AnimState:PlayAnimation("turn_off")
		inst.AnimState:PushAnimation("idle_off")
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/turn_off")
	end
	inst.SoundEmitter:KillSound("loop")
    TheWorld:PushEvent("ms_vault_teleporter_channel_stop", {inst = inst, doer = channeler})
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

local function OnHaunt_ToOrFromVault(inst, doer)
    inst.nearbyghost = doer
    OnStartChanneling(inst, inst.nearbyghost)
    return true
end

local function OnUnHaunt_ToOrFromVault(inst)
    if inst.nearbyghost then
        OnStopChanneling(inst, true, inst.nearbyghost)
        inst.nearbyghost = nil
    end
end

local function UpdateHauntable(inst)
    if not inst.components.hauntable then
        return
    end

    local roomid = inst.components.vault_teleporter:GetTargetRoomID()
    if roomid == LOBBY_TO_OR_FROM_VAULT then
        inst.components.hauntable.cooldown = 0.01
        inst.components.hauntable:SetOnHauntFn(OnHaunt_ToOrFromVault)
        inst.components.hauntable:SetOnUnHauntFn(OnUnHaunt_ToOrFromVault)
    else
        inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_HUGE
        inst.components.hauntable:SetOnHauntFn(OnHaunt)
        inst.components.hauntable:SetOnUnHauntFn(OnUnHaunt)
    end
end

local function OnNewVaultTeleporterRoomID(inst, data)
    inst:UpdateHauntable()
end

local function AddHauntable(inst)
    if not inst.components.hauntable then
        inst:AddComponent("hauntable")
        inst:UpdateHauntable()
    end
end

local function ItemTradeTest(inst, item)
	return item ~= nil and item.prefab == "vault_orb"
end

local function OnAnimOver(inst)
	inst:RemoveEventCallback("animover", OnAnimOver)
	inst.components.channelable:SetEnabled(true)
    inst:AddHauntable()
	inst.AnimState:PlayAnimation("idle_off", true)
end

local function OnRepair(inst, giver, item)
	inst:RemoveTag("trader_repair")
	inst:RemoveComponent("trader")

    TheWorld:PushEvent("ms_vault_teleporter_repair", {inst = inst, doer = giver,})

	if inst:IsAsleep() then
		OnAnimOver(inst)
	else
		inst.components.channelable:SetEnabled(false)
        inst:RemoveComponent("hauntable")
		inst.AnimState:PlayAnimation("repair")
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/repair")
		inst:ListenForEvent("animover", OnAnimOver)
	end
end

local function MakeFixed(inst)
	inst:RemoveTag("trader_repair")
	inst:RemoveComponent("trader")
    OnAnimOver(inst)
end

local function MakeBroken(inst)
	inst.AnimState:PlayAnimation("idle_broken")
	inst.SoundEmitter:KillSound("loop")

	inst.components.channelable:SetEnabled(false)
    inst:RemoveComponent("hauntable")

	if inst.components.trader == nil then
		inst:AddComponent("trader")
		inst.components.trader:SetAbleToAcceptTest(ItemTradeTest)
		inst.components.trader:SetOnAccept(OnRepair)
	end

	inst:AddTag("trader_repair") --for action string
end

local function MakeUnderConstruction(inst)
	inst.AnimState:PlayAnimation("unpowered_construction")
	inst.SoundEmitter:KillSound("loop")

	inst:RemoveTag("trader_repair")
	inst:RemoveComponent("trader")
	inst.components.channelable:SetEnabled(false)
    inst:RemoveComponent("hauntable")

	inst.components.inspectable:SetNameOverride("vault_teleporter_underconstruction")
	inst.components.inspectable.getstatus = nil
end

local function SpawnOrb(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = math.random() * 0.5 + 1
    local theta = math.random() * PI2
    x, z = x + math.cos(theta) * radius, z + math.sin(theta) * radius
    local orb = SpawnPrefab("vault_orb")
    orb.Transform:SetPosition(x, y, z)
end

local function OnDirCodeDirty(inst)
	ConfigureBaseCode(inst.base, inst.dircode:value())
end

local function OnPlaced(inst)
    local directionname = inst.components.vault_teleporter:GetDirectionName()
    local unshuffleddirectionname = inst.components.vault_teleporter:GetUnshuffledDirectionName()

	inst.Transform:SetRotation(
		(directionname == "E" and 90) or
		(directionname == "S" and 180) or
		(directionname == "W" and -90) or
		0)

	local dircode = DIRS[unshuffleddirectionname] or 0
	if dircode ~= inst.dircode:value() then
		inst.dircode:set(dircode)
		if inst.base then
			OnDirCodeDirty(inst)
		end
	end
end

local function DisplayNameFn(inst)
	return inst:HasTag("trader") and STRINGS.NAMES.VAULT_TELEPORTER_BROKEN or nil
end

local function GetStatus(inst, viewer)
	return (inst.components.trader and "BROKEN")
		or (not inst.components.channelable:GetEnabled() and "UNPOWERED")
		or nil
end

local function SetPowered(inst, powered)
    -- Assumes the device is not broken for now.
	inst.SoundEmitter:KillSound("loop")
    if powered then
		if not inst:IsAsleep() and (
			inst.AnimState:IsCurrentAnimation("unpowered") or
			inst.AnimState:IsCurrentAnimation("unpowered_pre")
		) then
			inst.AnimState:PlayAnimation("powered_pre")
			inst.AnimState:PushAnimation("idle_off")
		else
			inst.AnimState:PlayAnimation("idle_off", true)
		end
    elseif not inst:IsAsleep() then
		inst.AnimState:PlayAnimation("unpowered_pre")
		inst.AnimState:PushAnimation("unpowered", false)
	else
		inst.AnimState:PlayAnimation("unpowered")
	end
    inst.components.channelable:SetEnabled(powered)
    if powered then
        inst:AddHauntable()
    else
        inst:RemoveComponent("hauntable")
    end
end

--V2C: doing this instead of putting the sound on the fx, so we don't have so many sound instances.
local function OnDepartFx(inst)
	inst.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_fx")
end

local function OnArriveFx(inst)
	inst.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_arrive_FX")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("vault_teleporter.png")

    MakeObstaclePhysics(inst, 0.1)

	inst.AnimState:SetBank("vault_portal")
	inst.AnimState:SetBuild("vault_portal")
    inst.AnimState:PlayAnimation("idle_off", true)

    inst:AddTag("vault_teleporter")
    inst:AddTag("staysthroughvirtualrooms")

	inst.dircode = net_tinybyte(inst.GUID, "vault_teleporter.dircode", "dircodedirty")

	inst.displaynamefn = DisplayNameFn

	if not TheNet:IsDedicated() then
		inst.base = CreateBase()
		inst.base.entity:SetParent(inst.entity)
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst:ListenForEvent("dircodedirty", OnDirCodeDirty)

        return inst
    end

    inst.persists = false -- This prefab is designed to be created on the fly.

    inst:AddComponent("vault_teleporter")

    inst:AddComponent("channelable")
    inst.components.channelable:SetChannelingFn(OnStartChanneling, OnStopChanneling)
    inst.components.channelable:SetMultipleChannelersAllowed(true)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst.AddHauntable = AddHauntable
    inst.UpdateHauntable = UpdateHauntable
    inst:AddHauntable()

    inst.MakeFixed = MakeFixed
	inst.MakeBroken = MakeBroken
	inst.MakeUnderConstruction = MakeUnderConstruction
    inst.SpawnOrb = SpawnOrb
	inst.OnPlaced = OnPlaced
    inst.SetPowered = SetPowered
	inst.OnDepartFx = OnDepartFx
	inst.OnArriveFx = OnArriveFx
    inst.CheckForNearbyGhosts = CheckForNearbyGhosts

    inst.OnNewVaultTeleporterRoomID = OnNewVaultTeleporterRoomID
    inst:ListenForEvent("newvaultteleporterroomid", inst.OnNewVaultTeleporterRoomID)

    return inst
end

local function orbfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("vault_portal")
	inst.AnimState:SetBuild("vault_portal")
	inst.AnimState:PlayAnimation("idle_orb")

	MakeInventoryFloatable(inst, "small", 0.05, { 0.8, 0.75, 0.8 })

	inst:AddTag("donotautopick")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("tradable")
	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("vault_teleporter", fn, assets, prefabs),
	Prefab("vault_orb", orbfn, assets)
