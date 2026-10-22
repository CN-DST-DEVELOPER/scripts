local vaultroom_defs = require("prefabs/vaultroom_defs")
local lobbyvaultroom_defs = require("prefabs/lobbyvaultroom_defs")

local assets_lobby =
{
	Asset("SCRIPT", "scripts/prefabs/lobbyvaultroom_defs.lua"),
}

local assets =
{
	Asset("SCRIPT", "scripts/prefabs/vaultroom_defs.lua"),
}

local prefabs =
{
	"abysspillar_minion",
	"abysspillar_trial",
	"ancient_husk",
	"archive_lockbox_dispencer",
	"lightsout_trial",
	"mask_ancient_architecthat",
	"mask_ancient_handmaidhat",
	"mask_ancient_masonhat",
	"playbill_the_vault",
    "vault_compass",
	"temp_beta_msg", --#TEMP_BETA
	"vault_chandelier",
	"vault_chandelier_broken",
	"vault_chandelier_decor",
	"vault_ground_pattern_fx",
	"vault_pillar",
	"vault_rune",
	"vault_statue",
	"vault_stool",
	"vault_switch_base",
	"vault_table_round",
    "vaultcollision_lobby",
    "vaultcollision_vault",
    -- rifts 7
    "vault_decon_switch",
    "vault_decon_switch_reset",
    "vault_decon_switch_reset2",
    "vault_decon_door",
    "vault_decon_door_collision",
    "vault_decon_mister",
    "vault_sanity_adjuster",
    "vault_sanity_adjuster_alwaysincreasing",
    "vault_sanity_adjuster_alwaysdecreasing",
    "vault_key",
	"vault_key_trial",
	"vault_security_desk",
    "vault_invalidtile",
}

local DEBUG_STATIC_LAYOUT = nil --BRANCH == "dev"

local function OnAdd(inst)
	inst.inittask = nil
    if not TheWorld.ismastersim then
        print("Any vault marker entity should not exist on clients!", inst)
        inst:Remove()
		return
    end
end

local function OnLoad(inst)
	if inst.inittask then
		inst.inittask:Cancel()
		OnAdd(inst)
	end
end

local function OnRemove(inst)
    TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER})
end

local function fn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]

    inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})

    return inst
end

local function OnShowRoom(inst, virtualroomset, roomname, teleportingentsdata)
    local teleporters = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.TELEPORTER)
    if teleporters then
        for _, teleporter in ipairs(teleporters) do
            teleporter:UpdateTeleporterPoweredState()
        end
        if teleportingentsdata then
            local x, z = teleportingentsdata.x, teleportingentsdata.z
            vaultroom_defs.internal.DoOnArriveTeleporters_HACK(virtualroomset, x, z)
        end
    end
end

local function SetRoomToOne(inst, virtualroomset)
    inst.setroomtask = nil
    local teleportingsuccess = false
    local markers = virtualroomset:GetVirtualRoomEntities(VIRTUALROOMCONTEXT.MARKER)
    local marker = FindFirstPrefabInArray(markers, "vaultmarker_lobby_to_vault")
    if marker then
        local x, y, z = marker.Transform:GetWorldPosition()
        local teleportingentsdata = {
            targetroomname = "mask1",
            x = x,
            z = z,
        }
        teleportingsuccess = virtualroomset:TryTeleportSequenceImmediatelyWithNoPlayers(teleportingentsdata)
    end
    if not teleportingsuccess then
        virtualroomset:SetRoom(1)
    end
end

local function OnPlayersChanged(inst, virtualroomset, players, numberplayers)
    if numberplayers == 0 and inst.validmarkers then
        if not inst.setroomtask then
            inst.setroomtask = inst:DoTaskInTime(0, SetRoomToOne, virtualroomset) -- Delay a tick for when a player disconnects inside the VRS.
        end
    else
        if inst.setroomtask then
            inst.setroomtask:Cancel()
            inst.setroomtask = nil
        end
    end
end

local function OnReset(inst, virtualroomset)
    vaultroom_defs.internal.ResetAllRepairedLinks(virtualroomset)
    inst:SetPRNGSeed(virtualroomset, virtualroomset.customdata.prngseed + 1)
    virtualroomset:SetRoom(1)
end

local function OnPostInit(inst, virtualroomset)
    inst:SetPRNGSeed(virtualroomset, virtualroomset.customdata.prngseed)
end

local function SetPRNGSeed(inst, virtualroomset, seed)
    virtualroomset.customdata.prngseed = seed
    virtualroomset.scratchpad.prng:SetSeed(seed)
    inst:ShuffleRooms(virtualroomset)
end

local function ShuffleRooms(inst, virtualroomset)
    local prng = virtualroomset.scratchpad.prng
    for i = 1, virtualroomset.numberrooms do
        local virtualroom = virtualroomset.rooms[i]
        virtualroom.shuffleddirections = shallowcopy(VIRTUALROOMDIRECTIONS_INDEX)
        for i = VIRTUALROOMDIRECTIONS_MAX_SHUFFLE_INDEX, 2, -1 do
            local j = prng:RandInt(1, i)
            if not DEBUG_STATIC_LAYOUT then
                local link1 = virtualroom.links[i]
                local link2 = virtualroom.links[j]
                if (link1 == nil or not link1.rigid) and (link2 == nil or not link2.rigid) then
                    virtualroom.shuffleddirections[i], virtualroom.shuffleddirections[j] = virtualroom.shuffleddirections[j], virtualroom.shuffleddirections[i]
                end
            end
        end
    end
end

local function FindSafePlayerPointFrom(inst, virtualroomset, x, y, z)
    local markers = TheWorld.components.virtualroommanager:GetVirtualRoomEntities(VIRTUALROOMSETS.VAULT, VIRTUALROOMCONTEXT.MARKER)
    local vault_lobby_center = FindFirstPrefabInArray(markers, "vaultmarker_lobby_center")
    if vault_lobby_center then
        x, y, z = vault_lobby_center.Transform:GetWorldPosition()
    end
    return x, y, z
end

local MANDATORY_MARKERS = {
    ["vaultmarker_lobby_center"] = true,
    ["vaultmarker_lobby_to_vault"] = true,
    ["vaultmarker_lobby_to_archive"] = true,
    ["vaultmarker_vault_center"] = true,
    ["vaultmarker_vault_north"] = true,
    ["vaultmarker_vault_east"] = true,
    ["vaultmarker_vault_south"] = true,
    ["vaultmarker_vault_west"] = true,
}
local function AreAllMarkersPresent(markers)
    if not markers then
        return false
    end

    for mandatorymarkerprefab, _ in pairs(MANDATORY_MARKERS) do
        if not FindFirstPrefabInArray(markers, mandatorymarkerprefab) then
            return false
        end
    end
    return true
end
local function ValidateMarkers(inst, virtualroomset)
    inst.validatemarkerstask = nil
    local markers = TheWorld.components.virtualroommanager:GetVirtualRoomEntities(VIRTUALROOMSETS.VAULT, VIRTUALROOMCONTEXT.MARKER)
    if AreAllMarkersPresent(markers) then
        inst:OnValidMarkers(virtualroomset, markers)
    else
        inst:OnInvalidMarkers(virtualroomset, markers)
    end

    local key1exit = FindFirstPrefabInArray(markers, "vault_key_exit")
    if key1exit then
        local key1exittarget = FindFirstPrefabInArray(markers, "archive_orchestrina_main")
        key1exit:SetExitTarget(key1exittarget)
    end
end
local function OnVirtualRoomEntitiesChanged(inst, virtualroomset)
    if not inst.validatemarkerstask then
        inst.validatemarkerstask = inst:DoTaskInTime(0, ValidateMarkers, virtualroomset)
    end
end

local function OnTeleportedEntity(inst, virtualroomset, ent, x, z)
    SpawnPrefab("vault_portal_fx").Transform:SetPosition(x, 0, z)
end

local function OnInvalidMarkers(inst, virtualroomset, markers)
    if not inst.validmarkers then
        return
    end

    inst.validmarkers = false
    virtualroomset:SetRoom(0)
end

local function OnValidMarkers(inst, virtualroomset, markers)
    if inst.validmarkers then
        return
    end

    inst.validmarkers = true
    local lobbycenter = FindFirstPrefabInArray(markers, "vaultmarker_lobby_center")
    local vaultcenter = inst
    if not inst.vaultcollision then
        local vaultcollision = SpawnPrefab("vaultcollision_lobby")
        lobbycenter.vaultcollision = vaultcollision
        local x, y, z = lobbycenter.Transform:GetWorldPosition()
        vaultcollision.Transform:SetPosition(x, y, z)
        vaultcollision:ListenForEvent("onremove", function() vaultcollision:Remove() end, lobbycenter)
    end
    if not vaultcenter.vaultcollision then
        local vaultcollision = SpawnPrefab("vaultcollision_vault")
        vaultcenter.vaultcollision = vaultcollision
        local x, y, z = vaultcenter.Transform:GetWorldPosition()
        vaultcollision.Transform:SetPosition(x, y, z)
        vaultcollision:ListenForEvent("onremove", function() vaultcollision:Remove() end, vaultcenter)
    end
    virtualroomset:SetRoom(1)
end


local function centerfn()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

    inst.OnInvalidMarkers = OnInvalidMarkers
    inst.OnValidMarkers = OnValidMarkers
    inst.SetPRNGSeed = SetPRNGSeed
    inst.ShuffleRooms = ShuffleRooms

    local virtualroomset = inst:AddComponent("virtualroomset")
    virtualroomset:DeclareVirtualRoomSetName(VIRTUALROOMSETS.VAULT)
    virtualroomset:SetOnShowRoom(OnShowRoom)
    virtualroomset:SetOnPlayersChanged(OnPlayersChanged)
    virtualroomset:SetOnReset(OnReset)
    virtualroomset:SetOnPostInit(OnPostInit)
    virtualroomset:SetFindSafePlayerPointFrom(FindSafePlayerPointFrom)
    virtualroomset:SetOnVirtualRoomEntitiesChanged(OnVirtualRoomEntitiesChanged)
    virtualroomset:SetOnTeleportedEntity(OnTeleportedEntity)
    virtualroomset:SetTeleportingIntoLobbyProhibited(true)
    virtualroomset:SetTeleportingOutProhibited(true)
    virtualroomset:SetRoomDefinitions(vaultroom_defs) -- Do last.
    local prngseed = hash(TheNet:GetSessionIdentifier())
    virtualroomset.customdata.prngseed = prngseed
    virtualroomset.scratchpad.prng = PRNG_Uniform(prngseed)

    inst:ListenForEvent("resetvault", function(_world) virtualroomset:FlagForReset() end, TheWorld)

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})

	return inst
end



local function OnRemove_lobby(inst)
    TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.LOBBYVAULT, context = VIRTUALROOMCONTEXT.MARKER})
    TheWorld:PushEvent("ms_unregister_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER})
end

local MANDATORY_MARKERS_lobby = {
    ["vault_lobby_exit"] = true,
    ["archive_portal"] = true,
}
local function AreAllMarkersPresent_lobby(markers)
    if not markers then
        return false
    end

    for mandatorymarkerprefab, _ in pairs(MANDATORY_MARKERS_lobby) do
        if not FindFirstPrefabInArray(markers, mandatorymarkerprefab) then
            return false
        end
    end
    return true
end
local function ValidateMarkers_lobby(inst, virtualroomset)
    inst.validatemarkerstask = nil
    local markers = TheWorld.components.virtualroommanager:GetVirtualRoomEntities(VIRTUALROOMSETS.LOBBYVAULT, VIRTUALROOMCONTEXT.MARKER)
    if AreAllMarkersPresent_lobby(markers) then
        inst:OnValidMarkers(virtualroomset, markers)
    else
        inst:OnInvalidMarkers(virtualroomset, markers)
    end
end
local function OnVirtualRoomEntitiesChanged_lobby(inst, virtualroomset)
    if not inst.validatemarkerstask then
        inst.validatemarkerstask = inst:DoTaskInTime(0, ValidateMarkers_lobby, virtualroomset)
    end
end
local function OnInvalidMarkers_lobby(inst, virtualroomset, markers)
    if not inst.validmarkers then
        return
    end

    inst.validmarkers = false
    local lobbyexit = FindFirstPrefabInArray(markers, "vault_lobby_exit")
    if lobbyexit then
        local lobbyexittarget = FindFirstPrefabInArray(markers, "archive_portal")
        lobbyexit:SetExitTarget(lobbyexittarget)
    end
end

local function OnValidMarkers_lobby(inst, virtualroomset, markers)
    if inst.validmarkers then
        return
    end

    inst.validmarkers = true
    local lobbyexit = FindFirstPrefabInArray(markers, "vault_lobby_exit")
    local lobbyexittarget = FindFirstPrefabInArray(markers, "archive_portal")
    lobbyexit:SetExitTarget(lobbyexittarget)
    if lobbyexit.hadrope_fromload then
        lobbyexit.hadrope_fromload = nil
        lobbyexit:AddRope()
    end
end

local function lobbycenterfn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]
    inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.
        return inst
    end
    inst.OnInvalidMarkers = OnInvalidMarkers_lobby
    inst.OnValidMarkers = OnValidMarkers_lobby

    local virtualroomset = inst:AddComponent("virtualroomset") -- NOTES(JBK): This is for marking out the region that constitutes this vault lobby.
    virtualroomset:DeclareVirtualRoomSetName(VIRTUALROOMSETS.LOBBYVAULT)
    virtualroomset:SetDoNotRotateRooms(true) -- No rooms to rotate to.
    virtualroomset:SetOnVirtualRoomEntitiesChanged(OnVirtualRoomEntitiesChanged_lobby)
    virtualroomset:SetRoomDefinitions(lobbyvaultroom_defs) -- Do last.

    inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
    inst.OnLoad = OnLoad
    inst:ListenForEvent("onremove", OnRemove_lobby)
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.LOBBYVAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})

    return inst
end

local function lobbyfn()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]

    inst.entity:AddTransform()

    if not TheWorld.ismastersim then
        inst:DoTaskInTime(0, inst.Remove) -- Not meant for clients.

        return inst
    end

	inst.inittask = inst:DoStaticTaskInTime(0, OnAdd)
	inst.OnLoad = OnLoad
	inst:ListenForEvent("onremove", OnRemove)
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.VAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})
    TheWorld:PushEvent("ms_register_virtualroom_entity", {inst = inst, roomsetname = VIRTUALROOMSETS.LOBBYVAULT, context = VIRTUALROOMCONTEXT.MARKER, onlyoneprefab = true})

    return inst
end

return Prefab("vaultmarker_lobby_center", lobbycenterfn, assets_lobby),
Prefab("vaultmarker_lobby_to_vault", lobbyfn),
Prefab("vaultmarker_lobby_to_archive", lobbyfn),
Prefab("vaultmarker_vault_center", centerfn, assets, prefabs),
Prefab("vaultmarker_vault_north", fn),
Prefab("vaultmarker_vault_east", fn),
Prefab("vaultmarker_vault_south", fn),
Prefab("vaultmarker_vault_west", fn)
