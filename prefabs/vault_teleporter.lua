local assets = {
	Asset("ANIM", "anim/vault_portal.zip"),
	Asset("ANIM", "anim/vault_portal_ground.zip"),
    Asset("SCRIPT", "scripts/prefabs/vaultroom_defs.lua"),
}

local prefabs =
{
	"vault_orb",
	"vault_portal_fx",
}

local vaultroom_defs = require("prefabs/vaultroom_defs")

--------------------------------------------------------------------------

local DIRS =
{
	[VIRTUALROOMDIRECTIONS.N] = 0,
	[VIRTUALROOMDIRECTIONS.E] = 1,
	[VIRTUALROOMDIRECTIONS.S] = 2,
	[VIRTUALROOMDIRECTIONS.W] = 3,
}
DIRS[VIRTUALROOMDIRECTIONS.IN] = DIRS[VIRTUALROOMDIRECTIONS.N]
DIRS[VIRTUALROOMDIRECTIONS.OUT] = DIRS[VIRTUALROOMDIRECTIONS.S]

local function SetCode(inst, pos, dir)
	for k in pairs(DIRS) do
        local name = VIRTUALROOMDIRECTIONS_INDEX[k]
		if k == dir then
			inst.AnimState:Show(pos..name)
		else
			inst.AnimState:Hide(pos..name)
		end
	end
end

local function ConfigureBaseCode(inst, dir)
	if dir == DIRS[VIRTUALROOMDIRECTIONS.W] then
		SetCode(inst, "M", VIRTUALROOMDIRECTIONS.E)
		SetCode(inst, "L", VIRTUALROOMDIRECTIONS.S)
		SetCode(inst, "R", VIRTUALROOMDIRECTIONS.N)
	elseif dir == DIRS[VIRTUALROOMDIRECTIONS.S] then
		SetCode(inst, "M", VIRTUALROOMDIRECTIONS.N)
		SetCode(inst, "L", VIRTUALROOMDIRECTIONS.E)
		SetCode(inst, "R", VIRTUALROOMDIRECTIONS.W)
	elseif dir == DIRS[VIRTUALROOMDIRECTIONS.E] then
		SetCode(inst, "M", VIRTUALROOMDIRECTIONS.W)
		SetCode(inst, "L", VIRTUALROOMDIRECTIONS.N)
		SetCode(inst, "R", VIRTUALROOMDIRECTIONS.S)
    elseif dir == DIRS[VIRTUALROOMDIRECTIONS.N] then
		SetCode(inst, "M", VIRTUALROOMDIRECTIONS.S)
		SetCode(inst, "L", VIRTUALROOMDIRECTIONS.W)
		SetCode(inst, "R", VIRTUALROOMDIRECTIONS.E)
    else
        SetCode(inst, "M", -1)
        SetCode(inst, "L", -1)
        SetCode(inst, "R", -1)
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

	ConfigureBaseCode(inst, DIRS[VIRTUALROOMDIRECTIONS.N])

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function TeleportDestinationPositionOverride(inst, ent)
    local virtualroomset = inst.components.virtualroomteleporter:GetVirtualRoomSet()
    if not virtualroomset then
        return nil, nil, nil
    end

    local direction = inst.components.virtualroomteleporter:GetDirection()
    if not direction then
        return nil, nil, nil
    end

    local markers = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.MARKER)
    local marker
    if direction == VIRTUALROOMDIRECTIONS.IN or direction == VIRTUALROOMDIRECTIONS.OUT then
        local markerprefab = vaultroom_defs.internal.DIRECTIONS_TO_MARKER_TELEPORTERUSE[direction]
        marker = FindFirstPrefabInArray(markers, markerprefab)
    else
        local virtualroom = virtualroomset.rooms[virtualroomset.currentroomindex] -- Do not use GetCurrentRoom here for clarity on the linked room handling.
        if virtualroom then
            local links = virtualroom.links
            if links then
                local link = links[direction]
                if link and link.linkedroom and link.linkeddirection then
                    local linkedvirtualroom = virtualroomset.rooms[link.linkedroom]
                    if linkedvirtualroom then
                        local linkedshuffleddirectionname = linkedvirtualroom.shuffleddirections[link.linkeddirection]
                        if linkedshuffleddirectionname then
                            local linkedshuffleddirection = VIRTUALROOMDIRECTIONS[linkedshuffleddirectionname]
                            local markerprefab = virtualroomset.defs.internal.DIRECTIONS_TO_MARKER[linkedshuffleddirection]
                            marker = FindFirstPrefabInArray(markers, markerprefab)
                        end
                    end
                end
            end
        end
    end
    if marker then
        return marker.Transform:GetWorldPosition()
    end

    return nil, nil, nil
end

local function ShouldTeleportFollower(follower)
    if follower.components.follower and follower.components.follower.noleashing then
        return false
    end

    if follower.components.inventoryitem and follower.components.inventoryitem:IsHeld() then
        return false
    end

    return true
end
local function GetToOrFromVaultTeleportTargetsFor(doer)
    local onecopycache = {[doer] = true}
    if doer.components.leader then
        for follower, _ in pairs(doer.components.leader.followers) do
            if ShouldTeleportFollower(follower) then
                onecopycache[follower] = true
            end
        end
    end

    if doer.components.inventory then
        doer.components.inventory:ForEachItem(function(item)
            if item.components.leader then
                for follower, _ in pairs(item.components.leader.followers) do
                    if ShouldTeleportFollower(follower) then
                        onecopycache[follower] = true
                    end
                end
            end
        end)
    end

    local entities = {}
    for entity, _ in pairs(onecopycache) do
        table.insert(entities, entity)
    end
    return entities
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
    local direction = inst.components.virtualroomteleporter:GetDirection()
    if direction == VIRTUALROOMDIRECTIONS.IN or direction == VIRTUALROOMDIRECTIONS.OUT then
        -- NOTES(JBK): Custom logic here to go in and out of the virtual room area reserved space for the vault.
        local virtualroomset = inst.components.virtualroomteleporter:GetVirtualRoomSet()
        local x, y, z = inst.components.virtualroomteleporter:GetTeleportDestinationPosition(doer)
        if not x or not virtualroomset then
            doer:PushEvent("vault_teleporter_does_nothing") -- Wisecracker.
            inst.components.channelable:StopChanneling(true)
        else
            doer:PushEventImmediate("vault_teleport", {
                onplayerready = function(doer)
                    local entities = GetToOrFromVaultTeleportTargetsFor(doer)
                    for i, v in ipairs(entities) do
                        if not v.isplayer then -- Player VFX is created in the stategraph.
                            SpawnPrefab("vault_portal_fx").Transform:SetPosition(v.Transform:GetWorldPosition())
                        end
                    end
                    virtualroomset:TeleportEntities(entities, x, y, z)
                    vaultroom_defs.internal.DoOnArriveTeleporters_HACK(virtualroomset, x, z)
                end,
            })
            inst.components.virtualroomteleporter:OnDepart()
        end
    else
        inst.components.virtualroomteleporter:StartRoomVote(doer)
    end
end

local function OnStopChanneling(inst, aborted, doer)
	if not (inst.components.channelable:IsChanneling() or
			inst.AnimState:IsCurrentAnimation("idle_off") or
			inst.AnimState:IsCurrentAnimation("turn_off"))
	then
		inst.AnimState:PlayAnimation("turn_off")
		inst.AnimState:PushAnimation("idle_off")
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/turn_off")
	end
	inst.SoundEmitter:KillSound("loop")
    local direction = inst.components.virtualroomteleporter:GetDirection()
    if direction == VIRTUALROOMDIRECTIONS.IN or direction == VIRTUALROOMDIRECTIONS.OUT then
        -- Do nothing.
    else
        inst.components.virtualroomteleporter:StopRoomVote(doer)
    end
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

    local direction = inst.components.virtualroomteleporter:GetDirection()
    if direction == VIRTUALROOMDIRECTIONS.IN or direction == VIRTUALROOMDIRECTIONS.OUT then
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

local function RemoveHauntable(inst)
	if inst.components.hauntable then
		if inst.components.hauntable.onunhaunt then
			inst.components.hauntable.onunhaunt(inst)
		end
		inst:RemoveComponent("hauntable")
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
    inst.broken = nil

    local direction = inst.components.virtualroomteleporter:GetDirection()
    local directionname = VIRTUALROOMDIRECTIONS_INDEX[direction]
    local virtualroomset = inst.components.virtualroomteleporter:GetVirtualRoomSet()
    virtualroomset:InvalidateClosestDirectionCache()
    local currentroomname = virtualroomset:GetCurrentRoomName()
    local repairedlinks = virtualroomset.customdata.repairedlinks[currentroomname]
    if not repairedlinks then
        repairedlinks = {}
        virtualroomset.customdata.repairedlinks[currentroomname] = repairedlinks
    end
    repairedlinks[directionname] = true

	if inst:IsAsleep() then
		OnAnimOver(inst)
	else
		inst.components.channelable:SetEnabled(false)
		inst:RemoveHauntable()
		inst.AnimState:PlayAnimation("repair")
		inst.SoundEmitter:PlaySound("rifts6/vault_portal/repair")
		inst:ListenForEvent("animover", OnAnimOver)
	end
end

local function MakeFixed(inst)
    inst.broken = nil
	inst:RemoveTag("trader_repair")
	inst:RemoveComponent("trader")
    OnAnimOver(inst)
end

local function MakeBroken(inst)
    inst.broken = true
	inst:RemoveEventCallback("animover", OnAnimOver) --cancel mid repair???
	inst.AnimState:PlayAnimation("idle_broken")
	inst.SoundEmitter:KillSound("loop")

	inst.components.channelable:SetEnabled(false)
	inst:RemoveHauntable()

	if inst.components.trader == nil then
		inst:AddComponent("trader")
		inst.components.trader:SetAbleToAcceptTest(ItemTradeTest)
		inst.components.trader:SetOnAccept(OnRepair)
	end

	inst:AddTag("trader_repair") --for action string
end

local function MakeUnderConstruction(inst)
	inst:RemoveEventCallback("animover", OnAnimOver) --cancel mid repair???
	inst.AnimState:PlayAnimation("unpowered_construction")
	inst.SoundEmitter:KillSound("loop")

	inst:RemoveTag("trader_repair")
	inst:RemoveComponent("trader")
	inst.components.channelable:SetEnabled(false)
	inst:RemoveHauntable()

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

local function OnPlaced(inst) -- NOTES(JBK): This should be safe to run multiple times to refresh.
    local direction = inst.components.virtualroomteleporter:GetShuffledDirection()
    local unshuffleddirection = inst.components.virtualroomteleporter:GetDirection()

	inst.Transform:SetRotation(
		(direction == VIRTUALROOMDIRECTIONS.E and 90) or
		((direction == VIRTUALROOMDIRECTIONS.S or direction == VIRTUALROOMDIRECTIONS.OUT) and 180) or
		(direction == VIRTUALROOMDIRECTIONS.W and -90) or
		0) -- VIRTUALROOMDIRECTIONS.N or VIRTUALROOMDIRECTIONS.IN

	local dircode = DIRS[unshuffleddirection] or 0
	if dircode ~= inst.dircode:value() then
		inst.dircode:set(dircode)
		if inst.base then
			OnDirCodeDirty(inst)
		end
	end
end

local function UpdateTeleporterPoweredState(inst)
    local virtualroomset = inst.components.virtualroomteleporter:GetVirtualRoomSet()
    local direction = inst.components.virtualroomteleporter:GetDirection()
    if direction == VIRTUALROOMDIRECTIONS.IN then
        local forcedpoweredstate = nil
        if virtualroomset.currentroomindex ~= 1 then
            forcedpoweredstate = false
        end
        if forcedpoweredstate ~= nil then
            inst:SetPowered(forcedpoweredstate)
        else
            local archivemanager = TheWorld.components.archivemanager
            local powered = archivemanager and archivemanager:GetPowerSetting() or false
            inst:SetPowered(powered)
        end
    else
        local powered = not vaultroom_defs.internal.IsOtherRoomLinkBroken(virtualroomset, virtualroomset:GetCurrentRoomName(), direction)
        inst:SetPowered(powered)
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
    if inst.powered == powered then
        return
    end
    inst.powered = powered

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
		inst:RemoveHauntable()
    end
end

--V2C: doing this instead of putting the sound on the fx, so we don't have so many sound instances.
local function OnDepart(inst)
	inst.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_fx")
end

local function OnArrive(inst)
	inst.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_arrive_FX")
end

local function OnAdd(inst)
    inst.inittask = nil
	TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.TELEPORTER})
    inst:OnPlaced()
end

local function OnForceRegisterEntity(inst)
    if inst.inittask then
        inst.inittask:Cancel()
        OnAdd(inst)
    end
end

local function OnLoad(inst, data)
    if data and data.broken then
        inst:MakeBroken()
    end
    inst.components.virtualroomteleporter:OnForceRegisterEntity()
end

local function OnSave(inst, data)
    data.broken = inst.broken
end

local function OnRemove(inst)
	TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.TELEPORTER})
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
	inst.Physics:ClearCollidesWith(COLLISION.GIANTS)

	inst.AnimState:SetBank("vault_portal")
	inst.AnimState:SetBuild("vault_portal")
    inst.AnimState:PlayAnimation("idle_off", true)

    inst:AddTag("virtualroomteleporter")

	inst.dircode = net_tinybyte(inst.GUID, "virtualroomteleporter.dircode", "dircodedirty")

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

    inst.powered = true

    local virtualroomteleporter = inst:AddComponent("virtualroomteleporter")
    virtualroomteleporter:SetRoomSetName(VIRTUALROOMSETS.VAULT)
    virtualroomteleporter:SetOnDepart(OnDepart)
    virtualroomteleporter:SetOnArrive(OnArrive)
    virtualroomteleporter:SetOnForceRegisterEntity(OnForceRegisterEntity)
    virtualroomteleporter:SetTeleportDestinationPositionOverride(TeleportDestinationPositionOverride)

    inst:AddComponent("channelable")
    inst.components.channelable:SetChannelingFn(OnStartChanneling, OnStopChanneling)
    inst.components.channelable:SetMultipleChannelersAllowed(true)

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst.AddHauntable = AddHauntable
	inst.RemoveHauntable = RemoveHauntable
    inst.UpdateHauntable = UpdateHauntable
    inst:AddHauntable()

    inst.MakeFixed = MakeFixed
	inst.MakeBroken = MakeBroken
	inst.MakeUnderConstruction = MakeUnderConstruction
    inst.SpawnOrb = SpawnOrb
	inst.OnPlaced = OnPlaced
    inst.SetPowered = SetPowered
    inst.CheckForNearbyGhosts = CheckForNearbyGhosts
    inst.UpdateTeleporterPoweredState = UpdateTeleporterPoweredState

    inst.OnNewVaultTeleporterRoomID = OnNewVaultTeleporterRoomID
    inst:ListenForEvent("newvaultteleporterroomid", inst.OnNewVaultTeleporterRoomID)

    inst:ListenForEvent("arhivepoweron", function(_world) inst:UpdateTeleporterPoweredState() end, TheWorld)
    inst:ListenForEvent("arhivepoweroff", function(_world) inst:UpdateTeleporterPoweredState() end, TheWorld)
    inst:ListenForEvent("ms_virtualroomset_originset", function(_world, data)
        if data and (data.roomsetname == virtualroomteleporter:GetRoomSetName()) then
            inst:UpdateTeleporterPoweredState()
        end
    end, TheWorld)

    inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
    inst.OnLoad = OnLoad
    inst.OnSave = OnSave
    inst:ListenForEvent("onremove", OnRemove)

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

    inst:AddTag("irreplaceable")
    inst:AddTag("forcedtosavethroughvirtualrooms")
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
