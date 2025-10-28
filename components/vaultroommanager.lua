local DEBUG_STATIC_LAYOUT = nil --BRANCH == "dev"

local obj_layout = require("map/object_layout")

local DIRECTIONS_INDEX = { -- If more directions are added the layout will change.
    "N",
    "E",
    "S",
    "W",
}
local SPECIAL_DIRECTIONS_INDEX = {
    ["lobby"] = "N",
}
local DIRECTIONS_INDEX_SIZE = #DIRECTIONS_INDEX
local DIRECTIONS = table.invert(DIRECTIONS_INDEX)
local DIRECTIONS_TO_MARKER = {
    [DIRECTIONS.N] = "vaultmarker_vault_north",
    [DIRECTIONS.E] = "vaultmarker_vault_east",
    [DIRECTIONS.S] = "vaultmarker_vault_south",
    [DIRECTIONS.W] = "vaultmarker_vault_west",
    ["lobby"] = "vaultmarker_lobby_to_vault",
    ["vault"] = "vaultmarker_vault_south",
}
local MARKER_TO_DIRECTION = table.invert(DIRECTIONS_TO_MARKER)
local LOBBY_TO_OR_FROM_VAULT = "lobby_or_vault"


local VaultRoomManager = Class(function(self, inst)

local _world = TheWorld
assert(_world.ismastersim, "Vault Room Manager should not exist on the client!")

local _map = _world.Map
self.inst = inst

self.rooms = {}
self.roomindex = 0
self.maxroomindex = 0

self.MARKERSTOREGISTER = {
    "vaultmarker_lobby_center",
    "vaultmarker_lobby_to_vault",
    "vaultmarker_lobby_to_archive",
    "vaultmarker_vault_center",
    "vaultmarker_vault_north",
    "vaultmarker_vault_east",
    "vaultmarker_vault_south",
    "vaultmarker_vault_west",
}
self.markers = {}
self.teleporters = {}
self.repairedlinks = {}

self.players = {}
self.playersinvault = 0
self.updateaccumulator = 0
self.UPDATE_TICK_TIME = 1
self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT = 10
self.updaterotatecooldownticks = self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT


function self:DeclareRoom(roomid, roomindex)
    self.maxroomindex = self.maxroomindex + 1
    assert(roomindex == self.maxroomindex, string.format("Vault Room Manager demands unique room indexes and room %s fails the ID %d", tostring(roomid), (tonumber(roomindex) or -1)))
    local roomdata = {
        --haslobby = false,
        roomid = roomid,
        roomindex = roomindex,
        links = {},
    }
    self.rooms[roomid] = roomdata
    self.rooms[roomindex] = roomdata
end
function self:LinkRooms(roomid, direction, linkedroom, linkeddirection)
    local roomdata = self.rooms[roomid]
    local link = roomdata.links[direction]
    if not link then
        link = {}
        roomdata.links[direction] = link
    end
    link.linkedroom = linkedroom
    link.linkeddirection = linkeddirection
    if linkedroom == "lobby" then
        roomdata.haslobby = true
        if not direction == DIRECTIONS.S then
            print("Vault Room Manager does not like a lobby to vault linking to a room not at the south.")
            assert(false, "You must fix this.")
        else
            self:MakeLinkRigid(roomid, DIRECTIONS.S)
        end
    end
    return link
end
function self:LinkRoomsBroken(roomid, direction, linkedroom, linkeddirection)
    local link = self:LinkRooms(roomid, direction, linkedroom, linkeddirection)
    link.broken = true
end
function self:MakeLinkRigid(roomid, direction)
    local roomdata = self.rooms[roomid]
    local link = roomdata.links[direction]
    link.rigid = true
end
function self:MakeLinkUnderConstruction(roomid, direction)
    local roomdata = self.rooms[roomid]
    local link = roomdata.links[direction]
    link.underconstruction = true
end

------------------
function self:CreateLayoutV1()
    -- NOTES(JBK): Always declare new rooms with a new roomindex!
    -- This is for PRNG use so you do not shift the layout after players have mapped out previous rooms.
    -- If a room is to be removed declare the room with an "_unused" suffix to the name but keep the index!
    self:DeclareRoom("mask1", 1) -- Root room always picked first on new world.
    self:DeclareRoom("teleport1", 2)
    self:DeclareRoom("hall3", 3)
    self:DeclareRoom("puzzle1", 4)
    self:DeclareRoom("lore3", 5)
    self:DeclareRoom("key1", 6)
    self:DeclareRoom("hall1", 7)
    self:DeclareRoom("lore1", 8)
    self:DeclareRoom("hall4", 9)
    self:DeclareRoom("hall6", 10)
    self:DeclareRoom("hall2", 11)
    self:DeclareRoom("lore2", 12)
    self:DeclareRoom("hall5", 13)
    self:DeclareRoom("hall7", 14)
    self:DeclareRoom("fountain2", 15)
    self:DeclareRoom("generator1", 16)
    self:DeclareRoom("playbill1", 17)
    self:DeclareRoom("fountain1", 18)
    ------------------
    self:LinkRooms("mask1", DIRECTIONS.N, "teleport1", DIRECTIONS.S)
    self:LinkRooms("mask1", DIRECTIONS.S, "lobby", nil)
    self:MakeLinkRigid("mask1", DIRECTIONS.N)
    self:MakeLinkRigid("mask1", DIRECTIONS.S)

    self:LinkRooms("teleport1", DIRECTIONS.N, "hall3", DIRECTIONS.S)
    self:LinkRooms("teleport1", DIRECTIONS.E, "hall2", DIRECTIONS.W)
    self:LinkRooms("teleport1", DIRECTIONS.S, "mask1", DIRECTIONS.N)
    self:LinkRooms("teleport1", DIRECTIONS.W, "hall1", DIRECTIONS.E)
    self:MakeLinkRigid("teleport1", DIRECTIONS.S)

    self:LinkRooms("hall3", DIRECTIONS.N, "puzzle1", DIRECTIONS.S)
    self:LinkRooms("hall3", DIRECTIONS.E, "lore2", DIRECTIONS.W)
    self:LinkRooms("hall3", DIRECTIONS.S, "teleport1", DIRECTIONS.N)
    self:LinkRooms("hall3", DIRECTIONS.W, "lore1", DIRECTIONS.E)

    self:LinkRooms("puzzle1", DIRECTIONS.N, "lore3", DIRECTIONS.S)
    self:LinkRooms("puzzle1", DIRECTIONS.E, "hall6", DIRECTIONS.W)
    self:LinkRooms("puzzle1", DIRECTIONS.S, "hall3", DIRECTIONS.N)
    self:LinkRooms("puzzle1", DIRECTIONS.W, "hall5", DIRECTIONS.E)
    self:MakeLinkRigid("puzzle1", DIRECTIONS.N)
    self:MakeLinkRigid("puzzle1", DIRECTIONS.S)

    self:LinkRooms("lore3", DIRECTIONS.N, "key1", DIRECTIONS.S)
    self:LinkRoomsBroken("lore3", DIRECTIONS.E, "generator1", DIRECTIONS.W)
    self:LinkRooms("lore3", DIRECTIONS.S, "puzzle1", DIRECTIONS.N)
    self:LinkRooms("lore3", DIRECTIONS.W, "fountain2", DIRECTIONS.E)
    self:MakeLinkRigid("lore3", DIRECTIONS.N)
    self:MakeLinkRigid("lore3", DIRECTIONS.S)
    self:MakeLinkUnderConstruction("lore3", DIRECTIONS.N) -- TODO(JBK): Remove this when no longer under construction.

    self:LinkRoomsBroken("key1", DIRECTIONS.S, "lore3", DIRECTIONS.N)

    self:LinkRooms("hall1", DIRECTIONS.N, "lore1", DIRECTIONS.S)
    self:LinkRooms("hall1", DIRECTIONS.E, "teleport1", DIRECTIONS.W)
    self:LinkRooms("hall1", DIRECTIONS.S, "fountain2", DIRECTIONS.N)
    self:LinkRooms("hall1", DIRECTIONS.W, "playbill1", DIRECTIONS.E)

    self:LinkRooms("lore1", DIRECTIONS.N, "hall5", DIRECTIONS.S)
    self:LinkRooms("lore1", DIRECTIONS.E, "hall3", DIRECTIONS.W)
    self:LinkRooms("lore1", DIRECTIONS.S, "hall1", DIRECTIONS.N)
    self:LinkRooms("lore1", DIRECTIONS.W, "hall4", DIRECTIONS.E)

    self:LinkRooms("hall5", DIRECTIONS.N, "fountain2", DIRECTIONS.S)
    self:LinkRooms("hall5", DIRECTIONS.E, "puzzle1", DIRECTIONS.W)
    self:LinkRooms("hall5", DIRECTIONS.S, "lore1", DIRECTIONS.N)
    self:LinkRooms("hall5", DIRECTIONS.W, "fountain1", DIRECTIONS.E)

    self:LinkRoomsBroken("fountain2", DIRECTIONS.N, "hall1", DIRECTIONS.S)
    self:LinkRooms("fountain2", DIRECTIONS.E, "lore3", DIRECTIONS.W)
    self:LinkRoomsBroken("fountain2", DIRECTIONS.S, "hall5", DIRECTIONS.N)
    self:LinkRoomsBroken("fountain2", DIRECTIONS.W, "hall7", DIRECTIONS.E)

    self:LinkRooms("hall2", DIRECTIONS.N, "lore2", DIRECTIONS.S)
    self:LinkRooms("hall2", DIRECTIONS.E, "playbill1", DIRECTIONS.W)
    self:LinkRooms("hall2", DIRECTIONS.S, "generator1", DIRECTIONS.N)
    self:LinkRooms("hall2", DIRECTIONS.W, "teleport1", DIRECTIONS.E)

    self:LinkRooms("lore2", DIRECTIONS.N, "hall6", DIRECTIONS.S)
    self:LinkRooms("lore2", DIRECTIONS.E, "hall4", DIRECTIONS.W)
    self:LinkRooms("lore2", DIRECTIONS.S, "hall2", DIRECTIONS.N)
    self:LinkRooms("lore2", DIRECTIONS.W, "hall3", DIRECTIONS.E)

    self:LinkRooms("hall6", DIRECTIONS.N, "generator1", DIRECTIONS.S)
    self:LinkRooms("hall6", DIRECTIONS.E, "fountain1", DIRECTIONS.W)
    self:LinkRooms("hall6", DIRECTIONS.S, "lore2", DIRECTIONS.N)
    self:LinkRooms("hall6", DIRECTIONS.W, "puzzle1", DIRECTIONS.E)

    self:LinkRooms("generator1", DIRECTIONS.N, "hall2", DIRECTIONS.S)
    self:LinkRooms("generator1", DIRECTIONS.E, "hall7", DIRECTIONS.W)
    self:LinkRooms("generator1", DIRECTIONS.S, "hall6", DIRECTIONS.N)
    self:LinkRooms("generator1", DIRECTIONS.W, "lore3", DIRECTIONS.E)

    self:LinkRooms("playbill1", DIRECTIONS.N, "hall4", DIRECTIONS.S)
    self:LinkRooms("playbill1", DIRECTIONS.E, "hall1", DIRECTIONS.W)
    self:LinkRooms("playbill1", DIRECTIONS.S, "hall7", DIRECTIONS.N)
    self:LinkRooms("playbill1", DIRECTIONS.W, "hall2", DIRECTIONS.E)

    self:LinkRooms("hall4", DIRECTIONS.N, "fountain1", DIRECTIONS.S)
    self:LinkRooms("hall4", DIRECTIONS.E, "lore1", DIRECTIONS.W)
    self:LinkRooms("hall4", DIRECTIONS.S, "playbill1", DIRECTIONS.N)
    self:LinkRooms("hall4", DIRECTIONS.W, "lore2", DIRECTIONS.E)

    self:LinkRooms("fountain1", DIRECTIONS.N, "hall7", DIRECTIONS.S)
    self:LinkRooms("fountain1", DIRECTIONS.E, "hall5", DIRECTIONS.W)
    self:LinkRooms("fountain1", DIRECTIONS.S, "hall4", DIRECTIONS.N)
    self:LinkRooms("fountain1", DIRECTIONS.W, "hall6", DIRECTIONS.E)

    self:LinkRooms("hall7", DIRECTIONS.N, "playbill1", DIRECTIONS.S)
    self:LinkRooms("hall7", DIRECTIONS.E, "fountain2", DIRECTIONS.W)
    self:LinkRooms("hall7", DIRECTIONS.S, "fountain1", DIRECTIONS.N)
    self:LinkRooms("hall7", DIRECTIONS.W, "generator1", DIRECTIONS.E)
end
function self:CreateLayoutV2()
    -- NOTES(JBK): Always declare new rooms with a new roomindex!
    -- This is for PRNG use so you do not shift the layout after players have mapped out previous rooms.
    -- If a room is to be removed declare the room with an "_unused" suffix to the name but keep the index!
    self:DeclareRoom("mask1", 1) -- Root room always picked first on new world.
    self:DeclareRoom("teleport1", 2)
    self:DeclareRoom("hall3", 3)
    self:DeclareRoom("puzzle1", 4)
    self:DeclareRoom("lore3", 5)
    self:DeclareRoom("key1", 6)
    self:DeclareRoom("hall1", 7)
    self:DeclareRoom("lore1", 8)
    self:DeclareRoom("puzzle2", 9)
    self:DeclareRoom("hall6", 10)
    self:DeclareRoom("hall2", 11)
    self:DeclareRoom("lore2", 12)
    self:DeclareRoom("hall5", 13)
    self:DeclareRoom("hall7", 14)
    self:DeclareRoom("fountain2", 15)
    self:DeclareRoom("generator1", 16)
    self:DeclareRoom("playbill1", 17)
    self:DeclareRoom("fountain1", 18)
    ------------------
    self:LinkRooms("mask1", DIRECTIONS.N, "teleport1", DIRECTIONS.S)
    self:LinkRooms("mask1", DIRECTIONS.S, "lobby", nil)
    self:MakeLinkRigid("mask1", DIRECTIONS.N)
    self:MakeLinkRigid("mask1", DIRECTIONS.S)

    self:LinkRooms("teleport1", DIRECTIONS.N, "hall3", DIRECTIONS.S)
    self:LinkRooms("teleport1", DIRECTIONS.E, "hall2", DIRECTIONS.W)
    self:LinkRooms("teleport1", DIRECTIONS.S, "mask1", DIRECTIONS.N)
    self:LinkRooms("teleport1", DIRECTIONS.W, "hall1", DIRECTIONS.E)
    self:MakeLinkRigid("teleport1", DIRECTIONS.S)

    self:LinkRooms("hall3", DIRECTIONS.N, "puzzle1", DIRECTIONS.S)
    self:LinkRooms("hall3", DIRECTIONS.E, "lore2", DIRECTIONS.W)
    self:LinkRooms("hall3", DIRECTIONS.S, "teleport1", DIRECTIONS.N)
    self:LinkRooms("hall3", DIRECTIONS.W, "lore1", DIRECTIONS.E)

    self:LinkRooms("puzzle1", DIRECTIONS.N, "lore3", DIRECTIONS.S)
    self:LinkRooms("puzzle1", DIRECTIONS.E, "hall6", DIRECTIONS.W)
    self:LinkRooms("puzzle1", DIRECTIONS.S, "hall3", DIRECTIONS.N)
    self:LinkRooms("puzzle1", DIRECTIONS.W, "hall5", DIRECTIONS.E)
    self:MakeLinkRigid("puzzle1", DIRECTIONS.N)
    self:MakeLinkRigid("puzzle1", DIRECTIONS.S)

    self:LinkRooms("lore3", DIRECTIONS.N, "key1", DIRECTIONS.S)
    self:LinkRoomsBroken("lore3", DIRECTIONS.E, "generator1", DIRECTIONS.W)
    self:LinkRooms("lore3", DIRECTIONS.S, "puzzle1", DIRECTIONS.N)
    self:LinkRooms("lore3", DIRECTIONS.W, "fountain2", DIRECTIONS.E)
    self:MakeLinkRigid("lore3", DIRECTIONS.N)
    self:MakeLinkRigid("lore3", DIRECTIONS.S)
    self:MakeLinkUnderConstruction("lore3", DIRECTIONS.N) -- TODO(JBK): Remove this when no longer under construction.

    self:LinkRoomsBroken("key1", DIRECTIONS.S, "lore3", DIRECTIONS.N)

    self:LinkRooms("hall1", DIRECTIONS.N, "lore1", DIRECTIONS.S)
    self:LinkRooms("hall1", DIRECTIONS.E, "teleport1", DIRECTIONS.W)
    self:LinkRooms("hall1", DIRECTIONS.S, "fountain2", DIRECTIONS.N)
    self:LinkRooms("hall1", DIRECTIONS.W, "playbill1", DIRECTIONS.E)

    self:LinkRooms("lore1", DIRECTIONS.N, "hall5", DIRECTIONS.S)
    self:LinkRooms("lore1", DIRECTIONS.E, "hall3", DIRECTIONS.W)
    self:LinkRooms("lore1", DIRECTIONS.S, "hall1", DIRECTIONS.N)
    self:LinkRooms("lore1", DIRECTIONS.W, "puzzle2", DIRECTIONS.E)

    self:LinkRooms("hall5", DIRECTIONS.N, "fountain2", DIRECTIONS.S)
    self:LinkRooms("hall5", DIRECTIONS.E, "puzzle1", DIRECTIONS.W)
    self:LinkRooms("hall5", DIRECTIONS.S, "lore1", DIRECTIONS.N)
    self:LinkRooms("hall5", DIRECTIONS.W, "fountain1", DIRECTIONS.E)

    self:LinkRoomsBroken("fountain2", DIRECTIONS.N, "hall1", DIRECTIONS.S)
    self:LinkRooms("fountain2", DIRECTIONS.E, "lore3", DIRECTIONS.W)
    self:LinkRoomsBroken("fountain2", DIRECTIONS.S, "hall5", DIRECTIONS.N)
    self:LinkRoomsBroken("fountain2", DIRECTIONS.W, "hall7", DIRECTIONS.E)

    self:LinkRooms("hall2", DIRECTIONS.N, "lore2", DIRECTIONS.S)
    self:LinkRooms("hall2", DIRECTIONS.E, "playbill1", DIRECTIONS.W)
    self:LinkRooms("hall2", DIRECTIONS.S, "generator1", DIRECTIONS.N)
    self:LinkRooms("hall2", DIRECTIONS.W, "teleport1", DIRECTIONS.E)

    self:LinkRooms("lore2", DIRECTIONS.N, "hall6", DIRECTIONS.S)
    self:LinkRooms("lore2", DIRECTIONS.E, "puzzle2", DIRECTIONS.W)
    self:LinkRooms("lore2", DIRECTIONS.S, "hall2", DIRECTIONS.N)
    self:LinkRooms("lore2", DIRECTIONS.W, "hall3", DIRECTIONS.E)

    self:LinkRooms("hall6", DIRECTIONS.N, "generator1", DIRECTIONS.S)
    self:LinkRooms("hall6", DIRECTIONS.E, "fountain1", DIRECTIONS.W)
    self:LinkRooms("hall6", DIRECTIONS.S, "lore2", DIRECTIONS.N)
    self:LinkRooms("hall6", DIRECTIONS.W, "puzzle1", DIRECTIONS.E)

    self:LinkRooms("generator1", DIRECTIONS.N, "hall2", DIRECTIONS.S)
    self:LinkRooms("generator1", DIRECTIONS.E, "hall7", DIRECTIONS.W)
    self:LinkRooms("generator1", DIRECTIONS.S, "hall6", DIRECTIONS.N)
    self:LinkRooms("generator1", DIRECTIONS.W, "lore3", DIRECTIONS.E)

    self:LinkRooms("playbill1", DIRECTIONS.N, "puzzle2", DIRECTIONS.S)
    self:LinkRooms("playbill1", DIRECTIONS.E, "hall1", DIRECTIONS.W)
    self:LinkRooms("playbill1", DIRECTIONS.S, "hall7", DIRECTIONS.N)
    self:LinkRooms("playbill1", DIRECTIONS.W, "hall2", DIRECTIONS.E)

    self:LinkRooms("puzzle2", DIRECTIONS.N, "fountain1", DIRECTIONS.S)
    self:LinkRooms("puzzle2", DIRECTIONS.E, "lore1", DIRECTIONS.W)
    self:LinkRooms("puzzle2", DIRECTIONS.S, "playbill1", DIRECTIONS.N)
    self:LinkRooms("puzzle2", DIRECTIONS.W, "lore2", DIRECTIONS.E)
    self:MakeLinkRigid("puzzle2", DIRECTIONS.S)

    self:LinkRoomsBroken("fountain1", DIRECTIONS.N, "hall7", DIRECTIONS.S)
    self:LinkRoomsBroken("fountain1", DIRECTIONS.E, "hall5", DIRECTIONS.W)
    self:LinkRooms("fountain1", DIRECTIONS.S, "puzzle2", DIRECTIONS.N)
    self:LinkRoomsBroken("fountain1", DIRECTIONS.W, "hall6", DIRECTIONS.E)

    self:LinkRooms("hall7", DIRECTIONS.N, "playbill1", DIRECTIONS.S)
    self:LinkRooms("hall7", DIRECTIONS.E, "fountain2", DIRECTIONS.W)
    self:LinkRooms("hall7", DIRECTIONS.S, "fountain1", DIRECTIONS.N)
    self:LinkRooms("hall7", DIRECTIONS.W, "generator1", DIRECTIONS.E)
end

function self:DeleteLayout()
    self.maxroomindex = 0
    self.rooms = {}
end
local CURRENT_VERSION = 2
self.version = CURRENT_VERSION
function self:CreateLayout(version)
    self:DeleteLayout()
    if version == 1 then
        self:CreateLayoutV1()
    else--if version == 2 then
        self:CreateLayoutV2()
    end
end
self:CreateLayout(self.version)
------------------


self.inst:ListenForEvent("ms_register_vault_marker", function(inst, ent) self:OnRegisterVaultMarker(ent) end, _world)
self.inst:ListenForEvent("ms_unregister_vault_marker", function(inst, ent) self:OnUnregisterVaultMarker(ent) end, _world)
self.inst:ListenForEvent("ms_vault_teleporter_channel_start", function(inst, data) self:OnVaultTeleporterChannelStart(data.inst, data.doer) end, _world)
self.inst:ListenForEvent("ms_vault_teleporter_channel_stop", function(inst, data) self:OnVaultTeleporterChannelStop(data.inst, data.doer) end, _world)
self.inst:ListenForEvent("ms_vault_teleporter_repair", function(inst, data) self:OnVaultTeleporterRepaired(data.inst, data.doer) end, _world)
self.inst:ListenForEvent("ms_vault_teleporter_break", function(inst, data) self:OnVaultTeleporterBroken(data.inst, data.doer) end, _world)
self.inst:ListenForEvent("ms_register_vault_lobby_exit", function(inst, ent) self:OnVaultLobbyExitCreated(ent) end, _world)
self.inst:ListenForEvent("ms_register_vault_lobby_exit_target", function(inst, ent) self:OnVaultLobbyExitTargetCreated(ent) end, _world)
self.inst:ListenForEvent("arhivepoweron", function(inst) self:OnArchivesPowered(true) end, _world)
self.inst:ListenForEvent("arhivepoweroff", function(inst) self:OnArchivesPowered(false) end, _world)
self.inst:ListenForEvent("resetruins", function(inst) self:ResetVault() end, _world) -- TODO(JBK): Move this event to the other when the other is there.

function self:OnArchivesPowered(powered)
    self.archivespowered = powered or nil
    local lobby_to_vault_teleporter = self.teleporters["lobby"] -- Intentionally not creating a teleport here.
    if lobby_to_vault_teleporter then
        lobby_to_vault_teleporter:SetPowered(powered)
    end
end

function self:TryToBreakLobbyExit()
    if self.lobbyexit then
        self.lobbyexit:SetExitTarget(nil)
    end
end
function self:TryToLinkLobbyExit()
    if self.lobbyexit and self.lobbyexittarget then
        self.lobbyexit:SetExitTarget(self.lobbyexittarget)
    end
end
function self:OnVaultLobbyExitCreated(ent)
    if self.lobbyexit then
        self.lobbyexit:Remove()
    end
    self.lobbyexit = ent
    ent:ListenForEvent("onremove", function()
        self.lobbyexit = nil
        self:TryToBreakLobbyExit()
    end)
    self:TryToLinkLobbyExit()
end
function self:OnVaultLobbyExitTargetCreated(ent)
    if self.lobbyexittarget then
        self.lobbyexittarget:Remove()
    end
    self.lobbyexittarget = ent
    ent:ListenForEvent("onremove", function()
        self.lobbyexittarget = nil
        self:TryToBreakLobbyExit()
    end)
    self:TryToLinkLobbyExit()
end


function self:GetVaultCenterMarker()
    return self.markers["vaultmarker_vault_center"]
end
function self:GetVaultLobbyCenterMarker()
    return self.markers["vaultmarker_lobby_center"]
end
function self:HideRoom()
	self:CancelPendingTeleport()
    self:ClearAllExits()

    if self.roomindex ~= 0 then
        local center = self:GetVaultCenterMarker()
        if center then
            local vaultroomdata, toteleportents = center.components.vaultroom:UnloadRoom(true)
            self._toteleportents = toteleportents
            local roomdata = self.rooms[self.roomindex]
            roomdata.vaultroomdata = vaultroomdata
        end
    end
end

function self:CreateTeleporter(shuffleddirection, direction, rigid)
    local marker = self.markers[DIRECTIONS_TO_MARKER[shuffleddirection]]
    local x, y, z = marker.Transform:GetWorldPosition()
    local cx, cy, cz = _map:GetTileCenterPoint(x, y, z)
    if shuffleddirection == DIRECTIONS.N then
        if _map:IsImpassableTileAtPoint(cx, cy, cz - TILE_SCALE) then
            z = z + 0.4
        end
    elseif shuffleddirection == DIRECTIONS.E then
        if _map:IsImpassableTileAtPoint(cx - TILE_SCALE, cy, cz) then
            x = x + 0.4
        end
    elseif shuffleddirection == DIRECTIONS.S then
        if _map:IsImpassableTileAtPoint(cx, cy, cz + TILE_SCALE) then
            z = z - 0.4
        end
    elseif shuffleddirection == DIRECTIONS.W then
        if _map:IsImpassableTileAtPoint(cx + TILE_SCALE, cy, cz) then
            x = x - 0.4
        end
    end

    local teleporter = SpawnPrefab("vault_teleporter")
    self.teleporters[shuffleddirection] = teleporter
    teleporter:ListenForEvent("onremove", function() self.teleporters[shuffleddirection] = nil end)
    teleporter.Transform:SetPosition(x, y, z)
    teleporter.components.vault_teleporter:SetUnshuffledDirectionName(DIRECTIONS_INDEX[direction] or SPECIAL_DIRECTIONS_INDEX[direction] or "N")
    teleporter.components.vault_teleporter:SetDirectionName(DIRECTIONS_INDEX[shuffleddirection] or SPECIAL_DIRECTIONS_INDEX[shuffleddirection] or "N")
    teleporter.components.vault_teleporter:SetRigid(rigid)
    if direction == "lobby" then
        local archivemanager = _world.components.archivemanager
        local powered = (archivemanager == nil) or archivemanager:GetPowerSetting()
        if not powered then
            teleporter:SetPowered(false)
        end
    end
    teleporter:OnPlaced()
    return teleporter
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
function self:GetToOrFromVaultTeleportTargetsFor(doer)
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

function self:PlayDestinationSFX(targetteleportmarkername)
    local direction = MARKER_TO_DIRECTION[targetteleportmarkername]
    if direction then
        local teleporter = self.teleporters[direction]
        if teleporter then
			teleporter:OnArriveFx()
        end
    end
end

function self:OnVaultTeleporterChannelStart(teleporter, doer)
    if doer.isplayer then
        teleporter.components.vault_teleporter:AddCounter()
        local roomid = teleporter.components.vault_teleporter:GetTargetRoomID()
        local targetteleportmarkername = teleporter.components.vault_teleporter:GetTargetMarkerName()
        if roomid == LOBBY_TO_OR_FROM_VAULT then
            if teleporter == self.teleporters["lobby"] and not self.haslobby then
                doer:PushEvent("vault_teleporter_does_nothing") -- Wisecracker.
                teleporter.components.channelable:StopChanneling(true)
            else
                doer:PushEventImmediate("vault_teleport", {
                    onplayerready = function(doer)
                        local entities = self:GetToOrFromVaultTeleportTargetsFor(doer)
                        for i, v in ipairs(entities) do
                            if not v.isplayer then
                                SpawnPrefab("vault_portal_fx").Transform:SetPosition(v.Transform:GetWorldPosition())
                            end
                        end
                        self:TeleportEntities(entities, targetteleportmarkername)
                        self:PlayDestinationSFX(targetteleportmarkername)
                    end,
                })
                teleporter:OnDepartFx()
            end
        else
            local direction = DIRECTIONS[teleporter.components.vault_teleporter:GetUnshuffledDirectionName()]

            local roomdata = self.rooms[self.roomindex]
            local link = roomdata.links[direction]

            local linkedroomdata = self.rooms[roomid]
            local linkedlink = link and linkedroomdata.links[link.linkeddirection] or nil
            if link and linkedlink and self:IsLinkBroken(linkedroomdata, link.linkeddirection, linkedlink) then
                doer:PushEvent("vault_teleporter_does_nothing") -- Wisecracker.
                teleporter.components.channelable:StopChanneling(true)
            elseif teleporter.components.vault_teleporter:GetCounter() >= self.playersinvault then
				self:TryStartTeleportSequence(teleporter, roomid, targetteleportmarkername)
            end
        end
    end
end

function self:TryStartTeleportSequence(teleporter, roomid, targetteleportmarkername)
	if self._pendingtp == nil then
		self._pendingtp = {}

		local function checkpending()
			if self._pendingtp and next(self._pendingtp) == nil then
				self._pendingtp = nil
				self._onremovependingtp = nil
				self._targetteleportmarkername = targetteleportmarkername
				self:SetRoom(roomid)
				if teleporter:IsValid() then
					teleporter.components.channelable:StopChanneling(true)
				end
			end
		end

		self._onremovependingtp = function(player)
			if self._pendingtp and self._pendingtp[player] then
				self._pendingtp[player] = nil
				self.inst:RemoveEventCallback("onremove", self._onremovependingtp, player)
				checkpending()
			end
		end

		if next(self.players) then
			for k in pairs(self.players) do
				k:PushEventImmediate("vault_teleport", {
					onplayerpending = function(player)
						if self._pendingtp and self._pendingtp[player] == nil then
							self._pendingtp[player] = true
							self.inst:ListenForEvent("onremove", self._onremovependingtp, player)
						end
					end,
					onplayerready = self._onremovependingtp,
				})
			end
			teleporter:OnDepartFx()
		end
		checkpending()
		return true
	end
	return false
end

function self:CancelPendingTeleport()
	if self._pendingtp then
		for k in pairs(self._pendingtp) do
			self.inst:RemoveEventCallback("onremove", self._onremovependingtp, k)
		end
		self._pendingtp = nil
		self._onremovependingtp = nil
	end
end

function self:OnVaultTeleporterChannelStop(teleporter, doer)
    if doer.isplayer then
        teleporter.components.vault_teleporter:RemoveCounter()
    end
end

function self:ConfigureVaultRoom(roomdata)
    local center = self:GetVaultCenterMarker()
    center.components.vaultroom:LoadRoom(roomdata.roomid, roomdata.vaultroomdata)
    -- Set roomdata.vaultroomdata = nil by the caller.
end
function self:BreakTeleporter(teleporter)
    teleporter:MakeBroken()
end
function self:RepairTeleporter(teleporter)
    teleporter:MakeFixed()
end
function self:BreakLink(teleporter)
    local direction = DIRECTIONS[teleporter.components.vault_teleporter:GetUnshuffledDirectionName()]
    self:BreakTeleporter(teleporter)

    local roomdata = self.rooms[self.roomindex]
    if not roomdata then
        return
    end

    local repairedlinks = self.repairedlinks[roomdata.roomid]
    if not repairedlinks then
        return
    end

    repairedlinks[direction] = nil
    if not next(repairedlinks) then
        self.repairedlinks[roomdata.roomid] = nil
    end
end
function self:RepairLink(teleporter)
    local direction = DIRECTIONS[teleporter.components.vault_teleporter:GetUnshuffledDirectionName()]
    self:RepairTeleporter(teleporter)

    local roomdata = self.rooms[self.roomindex]
    if not roomdata then
        return
    end

    local repairedlinks = self.repairedlinks[roomdata.roomid]
    if not repairedlinks then
        repairedlinks = {}
        self.repairedlinks[roomdata.roomid] = repairedlinks
    end
    repairedlinks[direction] = true
end
function self:OnVaultTeleporterRepaired(teleporter, doer)
    self:RepairLink(teleporter)
end
function self:OnVaultTeleporterBroken(teleporter, doer)
    self:BreakLink(teleporter)
end

function self:SetExit(roomdata, direction, link)
    local linkedroomdata = self.rooms[link.linkedroom]

    local shuffleddirection = DIRECTIONS[roomdata.shuffleddirections[direction]]
    local markerenter = self.markers[DIRECTIONS_TO_MARKER[shuffleddirection]]

    local markername
    local roomid
    if not linkedroomdata then
        markername = DIRECTIONS_TO_MARKER["lobby"]
        roomid = LOBBY_TO_OR_FROM_VAULT
    else
        local shuffledlinkeddirection = DIRECTIONS[linkedroomdata.shuffleddirections[link.linkeddirection]]
        markername = DIRECTIONS_TO_MARKER[shuffledlinkeddirection]
        roomid = link.linkedroom
    end

    local teleporter = self.teleporters[shuffleddirection]
    if not teleporter then
        teleporter = self:CreateTeleporter(shuffleddirection, direction, link.rigid)
    end
    teleporter.components.vault_teleporter:SetTargetMarkerName(markername)
    teleporter.components.vault_teleporter:SetTargetRoomID(roomid)
    return teleporter
end
function self:ClearAllExits(resettolobby)
    for direction = 1, DIRECTIONS_INDEX_SIZE do
        local teleporter = self.teleporters[direction]
        if teleporter then
            if resettolobby then
                teleporter.components.vault_teleporter:SetTargetMarkerName(DIRECTIONS_TO_MARKER["lobby"])
                teleporter.components.vault_teleporter:SetTargetRoomID(LOBBY_TO_OR_FROM_VAULT)
            else
                teleporter:Remove()
            end
        end
    end
    local roomdata = self.rooms[self.roomindex]
    if roomdata then
        self:UpdateLobbyToVaultTeleporter(roomdata)
    end
end
function self:IsLinkBroken(roomdata, direction, link)
    if not link.broken then
        return false
    end

    local repairedlinks = self.repairedlinks[roomdata.roomid]
    if not repairedlinks then
        return true
    end

    return not repairedlinks[direction]
end
function self:GetLobbyToVaultTeleporter()
    local lobby_to_vault_teleporter = self.teleporters["lobby"]
    if not lobby_to_vault_teleporter then
        lobby_to_vault_teleporter = self:CreateTeleporter("lobby", "lobby", true)
        lobby_to_vault_teleporter.components.vault_teleporter:SetTargetMarkerName(DIRECTIONS_TO_MARKER["vault"])
        lobby_to_vault_teleporter.components.vault_teleporter:SetTargetRoomID(LOBBY_TO_OR_FROM_VAULT)
    end
    return lobby_to_vault_teleporter
end
function self:UpdateLobbyToVaultTeleporter(roomdata)
    self.haslobby = roomdata.haslobby
    local lobby_to_vault_teleporter = self:GetLobbyToVaultTeleporter()
    lobby_to_vault_teleporter:SetPowered(self.archivespowered)
end
function self:SetAllExits(roomdata)
    for direction = 1, DIRECTIONS_INDEX_SIZE do
        local link = roomdata.links[direction]
        if link then
            local teleporter = self:SetExit(roomdata, direction, link)
            if link.underconstruction then
                teleporter:MakeUnderConstruction()
            elseif self:IsLinkBroken(roomdata, DIRECTIONS[teleporter.components.vault_teleporter:GetUnshuffledDirectionName()], link) then
                self:BreakTeleporter(teleporter)
                if not roomdata.vaultroomdata and not self.loadingroom then
                    teleporter:SpawnOrb()
                end
            else
                self:RepairTeleporter(teleporter)
            end
        else
            local shuffleddirection = DIRECTIONS[roomdata.shuffleddirections[direction]]
            if self.teleporters[shuffleddirection] then
                self.teleporters[shuffleddirection]:Remove()
            end
        end
    end
    self:UpdateLobbyToVaultTeleporter(roomdata)
end
function self:TeleportEntities(toteleportents, targetteleportmarkername)
    local marker = self.markers[targetteleportmarkername]
    local x, y, z = marker.Transform:GetWorldPosition()
    local entscount = #toteleportents
    local thetaoffset = math.random()
    for i = 1, entscount do
        local ent = toteleportents[i]
        local radius = math.random() * 0.5 + 1
        local theta = (((i - 1) / entscount) + thetaoffset) * PI2
		local x1 = x + math.cos(theta) * radius
		local z1 = z - math.sin(theta) * radius
		if ent.Physics then
			ent.Physics:Teleport(x1, 0, z1)
		else
			ent.Transform:SetPosition(x1, 0, z1)
		end
		SpawnPrefab("vault_portal_fx").Transform:SetPosition(x1, 0, z1)
        if ent.isplayer then
            self:TryToAdjustTrackingPlayer(ent)
            if ent.SnapCamera then
                ent:SnapCamera()
            end
            local drownable = ent.components.drownable
            if drownable then
                local invault = self.players[ent] -- Cached from TryToAdjustTrackingPlayer.
                if invault then
                    local pt = drownable:GetTeleportPtFor("VAULT")
                    if pt then
                        pt.x = x1
                        pt.z = z1
                    else
                        drownable:PushTeleportPt("VAULT", Vector3(x1, 0, z1))
                    end
                end
            end
        end
    end
end
function self:ShowRoom()
    local toteleportents = self._toteleportents
    local targetteleportmarkername = self._targetteleportmarkername or DIRECTIONS_TO_MARKER["vault"]
    self._toteleportents = nil
    self._targetteleportmarkername = nil

    local roomdata = self.rooms[self.roomindex]
    if not roomdata then
		local center = self:GetVaultCenterMarker()
		center.components.vaultroom:ResetRoom()
        self:ClearAllExits(true)
        return
    end

    if toteleportents then
        self:TeleportEntities(toteleportents, targetteleportmarkername)
    end
    self:ConfigureVaultRoom(roomdata)
    self:SetAllExits(roomdata)
    if toteleportents and #toteleportents > 0 then
        self:PlayDestinationSFX(targetteleportmarkername)
    end
    roomdata.vaultroomdata = nil
end

function self:SetRoom(roomindexorid)
    self:HideRoom()
    if not roomindexorid then
        self.roomindex = 0
    else
        self.roomindex = self.rooms[roomindexorid].roomindex
    end
    self:ShowRoom()
end

function self:ResetVault()
    self.resetting = true
end


function self:OnValidMarkers()
    local lobbycenter = self:GetVaultLobbyCenterMarker()
    if not lobbycenter.vaultcollision then
        local vaultcollision = SpawnPrefab("vaultcollision_lobby")
        lobbycenter.vaultcollision = vaultcollision
        local x, y, z = lobbycenter.Transform:GetWorldPosition()
        vaultcollision.Transform:SetPosition(x, y, z)
        vaultcollision:ListenForEvent("onremove", function() vaultcollision:Remove() end, lobbycenter)
    end
    local vaultcenter = self:GetVaultCenterMarker()
    if not vaultcenter.vaultcollision then
        local vaultcollision = SpawnPrefab("vaultcollision_vault")
        vaultcenter.vaultcollision = vaultcollision
        local x, y, z = vaultcenter.Transform:GetWorldPosition()
        vaultcollision.Transform:SetPosition(x, y, z)
        vaultcollision:ListenForEvent("onremove", function() vaultcollision:Remove() end, vaultcenter)
    end

    if self.roomindex == 0 then
        local center = self:GetVaultCenterMarker()
        self.loadingroom = self.rooms[center.components.vaultroom:GetCurrentRoomId()]
        if self.loadingroom then
            self.roomindex = self.loadingroom.roomindex
            self:SetAllExits(self.loadingroom)
            self.loadingroom = nil
        else
            center.components.vaultroom:UnloadRoom(false)
            self:SetRoom(1)
        end
    end
    self.inst:StartUpdatingComponent(self)
end
function self:OnInvalidMarkers()
    self.inst:StopUpdatingComponent(self)
    self:ClearAllExits(true)
    self:SetRoom(nil)
    for _, player in ipairs(AllPlayers) do
        self:StopTrackingPlayer(player)
        local drownable = player.components.drownable
        if drownable then
            drownable:PopTeleportPt("VAULT")
        end
    end
end
function self:ValidateMarkers_Internal()
    for _, markername in ipairs(self.MARKERSTOREGISTER) do
        if not self.markers[markername] then
            self:OnInvalidMarkers()
            return
        end
    end
    self:OnValidMarkers()
end
local function ValidateMarkers_Bridge(inst)
    self:ValidateMarkers_Internal()
end
function self:ValidateMarkers()
    if not self.validatetask then
        self.validatetask = self.inst:DoTaskInTime(0, ValidateMarkers_Bridge)
    end
end
function self:OnRegisterVaultMarker(ent)
    local oldent = self.markers[ent.prefab]
    if oldent then
        oldent:Remove()
    end
    self.markers[ent.prefab] = ent
    self:ValidateMarkers()
end
function self:OnUnregisterVaultMarker(ent)
    self.markers[ent.prefab] = nil
    self:ValidateMarkers()
end

function self:NumPlayersInVault()
	return self.playersinvault
end
function self:TryToAdjustTrackingPlayer(player)
    local x, y, z = player.Transform:GetWorldPosition()
    local drownable = player.components.drownable
    local invault = _map:IsPointInVaultRoom(x, 0, z)
    if invault then
        self:TrackPlayer(player)
    else
        self:StopTrackingPlayer(player)
        if drownable then
            drownable:PopTeleportPt("VAULT")
        end
    end
end
self.OnPlayerJoined = function(world, player)
    self:TryToAdjustTrackingPlayer(player)
end
self.OnPlayerRemove = function(player, data)
    self:StopTrackingPlayer(player)
end
function self:StopTrackingPlayer(player)
    if not self.players[player] then
        return
    end

    self.players[player] = nil
    self.playersinvault = self.playersinvault - 1
    player:RemoveEventCallback("onremove", self.OnPlayerRemove)
    _world:PushEvent("ms_vaultroom_vault_playerleft", player)
    if self.playersinvault == 0 then
        self._needsreloaded = true
    end
end
function self:TrackPlayer(player)
    if self.players[player] then
        return
    end

    self.players[player] = true
    self.playersinvault = self.playersinvault + 1
    player:ListenForEvent("onremove", self.OnPlayerRemove)
    _world:PushEvent("ms_vaultroom_vault_playerentered", player)
    self._needsreloaded = nil
end
for _, player in ipairs(AllPlayers) do
    self.OnPlayerJoined(_world, player)
end
self.inst:ListenForEvent("ms_playerjoined", self.OnPlayerJoined)

------------------

local INITIAL_SEED = hash(TheNet:GetSessionIdentifier())
self.PRNG = PRNG_Uniform()
function self:GetPRNGSeed()
    return self.seed
end
function self:SetPRNGSeed(seed)
    self.seed = seed
    self.PRNG:SetSeed(seed)
    self:SetupPRNG()
end
function self:SetupPRNG()
    -- NOTES(JBK): Always call the same number of PRNG random if a field does not exist so it is deterministic.
    for i = 1, self.maxroomindex do
        local roomdata = self.rooms[i]
        roomdata.shuffleddirections = shallowcopy(DIRECTIONS_INDEX)
        for i = DIRECTIONS_INDEX_SIZE, 2, -1 do
            local j = self.PRNG:RandInt(1, i)
            if not DEBUG_STATIC_LAYOUT then
                local link1 = roomdata.links[i]
                local link2 = roomdata.links[j]
                if (link1 == nil or not link1.rigid) and (link2 == nil or not link2.rigid) then
                    roomdata.shuffleddirections[i], roomdata.shuffleddirections[j] = roomdata.shuffleddirections[j], roomdata.shuffleddirections[i]
                end
            end
        end
    end
end
self:SetPRNGSeed(INITIAL_SEED)

------------------


function self:OnUpdate(dt)
    self.updateaccumulator = self.updateaccumulator + dt
    if self.updateaccumulator > self.UPDATE_TICK_TIME then
        self.updateaccumulator = 0

        local aplayerisonshard = false
        for _, player in ipairs(AllPlayers) do
            self:TryToAdjustTrackingPlayer(player)
            aplayerisonshard = true
            if self.players[player] then
                local drownable = player.components.drownable
                if drownable then
                    if not drownable:GetTeleportPtFor("VAULT") then
                        local x, y, z = player.Transform:GetWorldPosition()
                        if _map:IsVisualGroundAtPoint(x, 0, z) then
                            drownable:PushTeleportPt("VAULT", Vector3(x, 0, z))
                        end
                    end
                end
            end
        end

        if aplayerisonshard then
            self.cachedroomrotatesindex = nil
            self.cachedroomrotates = nil
        elseif self.cachedroomrotates == nil then
            self.cachedroomrotatesindex = 0
            self.cachedroomrotates = {
                [1] = 1,
            }
            for roomindex = 2, self.maxroomindex do
                if roomindex ~= 6 then -- FIXME(JBK): Rifts6.1 super hack room "key1" is not defined yet.
                    local roomdata = self.rooms[roomindex]
                    if roomdata and roomdata.vaultroomdata then
                        table.insert(self.cachedroomrotates, roomindex)
                    end
                end
            end
        end

        if self.playersinvault == 0 then
            local targetroom = nil
            if self.resetting then
                self:SetRoom(nil)
                for roomindex = 1, self.maxroomindex do
                    local roomdata = self.rooms[roomindex]
                    if roomdata.vaultroomdata then
                        roomdata.vaultroomdata = nil
                    end
                end
                if self.version ~= CURRENT_VERSION then
                    self.version = CURRENT_VERSION
                    self:CreateLayout(self.version)
                end
                self:SetPRNGSeed(self:GetPRNGSeed() + 1)
                targetroom = 1
            elseif self._needsreloaded then
                targetroom = self.roomindex
            elseif not aplayerisonshard then
                local cooldownticks = self.updaterotatecooldownticks - 1
                if cooldownticks <= 0 then
                    self.updaterotatecooldownticks = self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT

                    self.cachedroomrotatesindex = self.cachedroomrotatesindex + 1
                    if self.cachedroomrotatesindex > #self.cachedroomrotates then
                        self.cachedroomrotatesindex = 1
                    end
                    local newroomindex = self.cachedroomrotates[self.cachedroomrotatesindex]
                    if newroomindex ~= self.roomindex then
                        targetroom = newroomindex
                    end
                else
                    self.updaterotatecooldownticks = cooldownticks
                end
            elseif self.roomindex ~= 1 then
                targetroom = 1
            end
            if targetroom then
                self._targetteleportmarkername = DIRECTIONS_TO_MARKER["lobby"]
                self:SetRoom(targetroom)
            end
            self.resetting = nil
            self._needsreloaded = nil
        end
    end
end


function self:OnSave()
    local data = {
        spawnedlayouts = self.spawnedlayouts,
        resetting = self.resetting,
        version = self.version,
    }
    local vaultroomdata = {}
    for roomindex = 1, self.maxroomindex do
        local roomdata = self.rooms[roomindex]
        if roomdata.vaultroomdata then
            vaultroomdata[roomindex] = roomdata.vaultroomdata
        end
    end
    if next(vaultroomdata) then
        data.vaultroomdata = vaultroomdata
    end
    if next(self.repairedlinks) then
        data.repairedlinks = self.repairedlinks
    end
    if self.seed ~= INITIAL_SEED then
        data.seed = self.seed
    end
    return data
end

function self:OnLoad(data)
    if not data then
        return
    end

    if data.repairedlinks then
        self.repairedlinks = data.repairedlinks
    end

    self.spawnedlayouts = data.spawnedlayouts
    self.resetting = data.resetting
    if data.seed then
        self:SetPRNGSeed(data.seed)
    end
    self.version = data.version or 1
    if self.version ~= CURRENT_VERSION then
        self:CreateLayout(self.version)
        self:SetPRNGSeed(self:GetPRNGSeed())
    end

    if data.vaultroomdata then
        for roomindex, vaultroomdata in pairs(data.vaultroomdata) do
            local roomdata = self.rooms[roomindex]
            if roomdata then
                roomdata.vaultroomdata = vaultroomdata
            end
        end
    end
end

function self:PlaceStaticLayout(layout, tx, ty)
    local success = StaticLayoutPlacer.TryToPlaceStaticLayoutNear(layout, tx, ty, StaticLayoutPlacer.ScanForStaticLayoutPosition_Spiral, StaticLayoutPlacer.TileFilter_Impassable)
    assert(success, "Vault Room Manager demands layout " .. layout.name .. " be placed and it failed to do so. Please add your map to a bug report!")
end
function self:TryToSpawnStaticLayouts()
    if not self.lobbyexittarget then -- No basis to set this the world is missing the portal.
        print("Vault Room Manager is unable to place down an important set piece because the world is missing the Archive Portal!")
        return
    end

    local Vault_Lobby = obj_layout.LayoutForDefinition("Vault_Lobby")
    local Vault_Vault = obj_layout.LayoutForDefinition("Vault_Vault")
    if not Vault_Lobby or not Vault_Vault then
        print("Vault Room Manager is unable to place down an important set piece because the world is missing definitions for the static layouts!")
        return
    end

    local x, y, z = self.lobbyexittarget.Transform:GetWorldPosition()
    local tx, ty = _map:GetTileCoordsAtPoint(x, y, z)

    self:PlaceStaticLayout(Vault_Lobby, tx, ty)
    self:PlaceStaticLayout(Vault_Vault, tx, ty)
    return true
end
function self:OnPostInit()
    -- NOTES(JBK): This is for post world creation to create the set layouts for the Vault.
    -- This should only happen once per world even if it is being loaded from an old world.
    if self.spawnedlayouts then
        return
    end

    self.spawnedlayouts = self:TryToSpawnStaticLayouts()
end

function self:GetDebugString()
    local roomdata = self.rooms[self.roomindex]
    if not roomdata then
        return "NO ROOM SET"
    end
    return string.format("Room:%s/%d", roomdata.roomid, self.roomindex)
end

end)
return VaultRoomManager