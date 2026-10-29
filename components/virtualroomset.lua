local TILE_SCALE = TILE_SCALE
local VIRTUALROOM_DONOTCARE_TILE = VIRTUALROOM_DONOTCARE_TILE
local EMPTYLAYOUT = {}

---------------------------------------------------------------

local VirtualRoom = Class(function(self, roomname, roomindex)
    self.roomname = roomname
    self.roomindex = roomindex

    self.links = {}
end)

---------------------------------------------------------------

local VirtualRoomSet = Class(function(self, inst)
    self.world = TheWorld

    assert(self.world.ismastersim, "VirtualRoomSet should not exist on the client!")
    self.map = self.world.Map

    self.virtualroommanager = self.world.components.virtualroommanager
    assert(self.virtualroommanager, "VirtualRoomSet demands virtualroommanager to exist on the world!")

    self.inst = inst


    --self.roomsetname = nil
    --self.roomsetindex = nil
    self.config = {}

    self.rooms = {}
    self.numberrooms = 0
    self.roomsavedata = {}
    self.customdata = {} -- Data for use by entities using this component to store save-serializeable data about the VirtualRoomSet.
    self.scratchpad = {} -- Data for use by entities using this component to store non-serialized data about the VirtualRoomSet.

    self.currentroomindex = 0

    self.players = {}
    self.numberplayers = 0

    self.voters = {}
    self.numbervoters = 0

    self.closestdirectioncache = {} -- self.closestdirectioncache[fromroom][toroom] = { dist = dist, direction = direction, },

    local function OnPlayerJoined_Bridge(_world, player)
        self:OnPlayerJoined(player)
    end
    local function OnPlayerLeft_Bridge(_world, player)
        self:OnPlayerLeft(player)
    end
    self.inst:ListenForEvent("ms_playerjoined", OnPlayerJoined_Bridge, self.world)
    self.inst:ListenForEvent("ms_playerleft", OnPlayerLeft_Bridge, self.world)
    -- Do not iterate AllPlayers here to do an OnPlayerJoined test because this component needs to setup its roomsetname first.

    self.initfn = function()
        self.inittask = nil
        self.initfn = nil

        self:SetOrigin(self.inst.Transform:GetWorldPosition())
        if not POPULATING then
            self:OnPostInit()
        end
    end
    self.inittask = self.inst:DoTaskInTime(0, self.initfn)
end)

function VirtualRoomSet:OnRemoveEntity()
    self.world:PushEvent("ms_virtualroomset_removed", {
        roomsetname = self.roomsetname,
        owner = self.inst,
    })
end

function VirtualRoomSet:DoInit()
    if self.initfn then
        if self.inittask then
            self.inittask:Cancel()
            self.inittask = nil
        end
        self.initfn()
        self.initfn = nil
    end
end

function VirtualRoomSet:DeclareVirtualRoomSetName(roomsetname)
    local boundingbox = VIRTUALROOM_BOUNDINGBOXES[roomsetname]
    if not boundingbox then
        assert(false, string.format("VRS: Declare a boundingbox in VIRTUALROOM_BOUNDINGBOXES for this roomsetname %s!", roomsetname))
    end

    self.virtualroommanager:DeclareVirtualRoomSet(self, roomsetname) -- self.roomsetindex is set here.
    self.roomsetname = roomsetname

    if boundingbox.mask then
        local expectedmasksize = (boundingbox.maxx - boundingbox.minx + 1) * (boundingbox.maxy - boundingbox.miny + 1)
        if #boundingbox.mask ~= expectedmasksize then
            assert(false, string.format("VRS: Declare needs to have the mask size for roomsetname \"%s\" equal to the dimension of the boundingbox.", roomsetname))
        end
    end
    self:SetBoundingBox(boundingbox)
    self.map:SetVirtualRoomSetBoundingBox(roomsetname, boundingbox.minx, boundingbox.miny, boundingbox.maxx, boundingbox.maxy)
    self.map:SetVirtualRoomSetBoundingBoxMask(roomsetname, boundingbox.mask)
end

function VirtualRoomSet:LinkVirtualRooms(from_roomname, from_direction, to_roomname, to_direction)
    local from_links = self:GetRoomLinks(from_roomname)
    local link = from_links[from_direction]
    if not link then
        link = {}
        from_links[from_direction] = link
    end
    link.linkedroom = to_roomname
    link.linkeddirection = to_direction
    return link
end

function VirtualRoomSet:LinkVirtualRoomsBroken(from_roomname, from_direction, to_roomname, to_direction)
    local link = self:LinkVirtualRooms(from_roomname, from_direction, to_roomname, to_direction)
    link.broken = true
    return link
end

function VirtualRoomSet:MakeLinkRigid(roomname, direction)
    local links = self:GetRoomLinks(roomname)
    local link = links[direction]
    link.rigid = true
end

function VirtualRoomSet:IsLinkRigid(roomname, direction)
    local links = self:GetRoomLinks(roomname)
    local link = links[direction]
    return link.rigid
end

function VirtualRoomSet:MakeRoomGrueImmuneArea(roomname)
    self.rooms[roomname].grueimmunearea = true
end

function VirtualRoomSet:GetCurrentRoom()
    if self.currentroomindex == 0 then
        return nil
    end
    return self.rooms[self.currentroomindex]
end

function VirtualRoomSet:InvalidateClosestDirectionCache()
    self.closestdirectioncache = {}
end

function VirtualRoomSet:CacheClosestDirectionFromRoom_Internal(cache, fromvirtualroom, dist, directionbefore)
    local fromlinks = fromvirtualroom.links
    if fromlinks then
        local nextdist = dist + 1
        for direction, roomlink in pairs(fromlinks) do
            local originaldirection = directionbefore or direction
            if (dist < ((cache[roomlink.linkedroom] and cache[roomlink.linkedroom].dist) or math.huge)) then
                local validlink = true
                if self.defs.internal.IsOtherRoomLinkBroken then
                    validlink = not self.defs.internal.IsOtherRoomLinkBroken(self, fromvirtualroom.roomname, direction)
                end
                if validlink then
                    local cachedvalue = cache[roomlink.linkedroom]
                    if cachedvalue then
                        cachedvalue.dist = dist
                        cachedvalue.direction = originaldirection
                    else
                        cache[roomlink.linkedroom] = {
                            dist = dist,
                            direction = originaldirection,
                        }
                    end

                    local nextroom = self.rooms[roomlink.linkedroom]
                    if nextroom then
                        self:CacheClosestDirectionFromRoom_Internal(cache, nextroom, nextdist, originaldirection)
                    end
                end
            end
        end
    end
end

function VirtualRoomSet:CacheClosestDirectionFromRoom(fromroom)
    local virtualroom = self.rooms[fromroom]
    if virtualroom and self.closestdirectioncache[fromroom] == nil then
        local cache = {}
        self.closestdirectioncache[fromroom] = cache

        self:CacheClosestDirectionFromRoom_Internal(cache, virtualroom, 1, nil)
    end
end

function VirtualRoomSet:GetClosestDirectionFromRoomToRoom(fromroom, toroom)
    if fromroom == toroom then
        return nil
    end

    self:CacheClosestDirectionFromRoom(fromroom)
    local cache = self.closestdirectioncache[fromroom]
    return cache and cache[toroom] and cache[toroom].direction or nil
end

function VirtualRoomSet:GetCurrentRoomName()
    local virtualroom = self:GetCurrentRoom()
    if not virtualroom then
        return VIRTUALROOMLOBBY
    end
    return virtualroom.roomname
end

function VirtualRoomSet:IsCurrentRoomLobby()
    return self:GetCurrentRoomName() == VIRTUALROOMLOBBY
end

function VirtualRoomSet:CheckRoomVotes()
    if self.teleportingentsdata then
        return -- Already in a teleport sequence.
    end

    local players, numberplayers = self:GetPlayersInfo()
    if self.numbervoters >= numberplayers then
        local validvote = true
        local virtualroomteleporter = nil
        for voter, choice in pairs(self.voters) do
            if not virtualroomteleporter then
                virtualroomteleporter = choice
            end
            if choice ~= virtualroomteleporter then
                validvote = false
                break
            end
        end
        if validvote and virtualroomteleporter then
            local direction = virtualroomteleporter:GetDirection()
            local x, y, z = virtualroomteleporter:GetTeleportDestinationPosition()
            local fxprefab = virtualroomteleporter:GetTeleportFXPrefab()
            if direction and x then
                local virtualroom = self:GetCurrentRoom()
                local teleportingentsdata = {
                    virtualroomteleporter = virtualroomteleporter,
                    targetroomname = virtualroom.links[direction].linkedroom,
                    x = x,
                    z = z,
                    fxprefab = fxprefab,
                }
                self:TryStartTeleportSequence(teleportingentsdata)
            end
        end
    end
end

function VirtualRoomSet:TryTeleportSequenceImmediatelyWithNoPlayers(teleportingentsdata)
    if self.teleportingentsdata then
        return false
    end

    local players, numberplayers = self:GetPlayersInfo()
    if numberplayers > 0 then
        return false
    end

    if teleportingentsdata.virtualroomteleporter then
        teleportingentsdata.virtualroomteleporter:OnDepart()
    end
    self.teleportingentsdata = teleportingentsdata
    if self.teleportingentsdata.onteleportcb then
        self.teleportingentsdata.onteleportcb()
    end
    self:SetRoom(self.teleportingentsdata.targetroomname)
    self.teleportingentsdata = nil
    return true
end

function VirtualRoomSet:TryStartTeleportSequence(teleportingentsdata)
    if self.teleportingentsdata then
        return false
    end

    local players, numberplayers = self:GetPlayersInfo()
    if numberplayers == 0 then
        return false
    end

    self.teleportingentsdata = teleportingentsdata
    self.teleportingentsdata.pendingtps = {}

    local function checkpending()
        if self.teleportingentsdata then
            if self.teleportingentsdata.pendingtps and (next(self.teleportingentsdata.pendingtps) == nil) then
                self.teleportingentsdata.pendingtps = nil
                self.teleportingentsdata.onremovependingtp = nil
                if self.teleportingentsdata.onteleportcb then
                    self.teleportingentsdata.onteleportcb()
                end
                self:SetRoom(self.teleportingentsdata.targetroomname)
                self.teleportingentsdata = nil
            end
        end
    end

    self.teleportingentsdata.onremovependingtp = function(player)
        if self.teleportingentsdata then
            if self.teleportingentsdata.pendingtps and self.teleportingentsdata.pendingtps[player] then
                self.teleportingentsdata.pendingtps[player] = nil
                self.world:RemoveEventCallback("onremove", self.teleportingentsdata.onremovependingtp, player)
                checkpending()
            end
        end
    end

    if teleportingentsdata.virtualroomteleporter then
        teleportingentsdata.virtualroomteleporter:OnDepart(self)
    end
    for player, _ in pairs(players) do
        player:PushEventImmediate("vault_teleport", {
            onplayerpending = function(player)
                if self.teleportingentsdata then
                    if self.teleportingentsdata.pendingtps and (self.teleportingentsdata.pendingtps[player] == nil) then
                        self.teleportingentsdata.pendingtps[player] = true
                        self.world:ListenForEvent("onremove", self.teleportingentsdata.onremovependingtp, player)
                    end
                end
            end,
            onplayerready = self.teleportingentsdata.onremovependingtp,
            state = teleportingentsdata.state or nil,
            fxprefab = teleportingentsdata.fxprefab or nil,
        })
    end
    checkpending()
    return true
end

function VirtualRoomSet:CancelPendingTeleport()
    if self.teleportingentsdata then
        if self.teleportingentsdata.pendingtps then
            for player, _ in pairs(self.teleportingentsdata.pendingtps) do
                self.world:RemoveEventCallback("onremove", self.teleportingentsdata.onremovependingtp, player)
            end
            self.teleportingentsdata.pendingtps = nil
            self.teleportingentsdata.onremovependingtp = nil
        end
    end
end

function VirtualRoomSet:StartRoomVoteBy(player, virtualroomteleporter)
    if self.voters[player] ~= virtualroomteleporter then
        if not self.voters[player] then
            self.numbervoters = self.numbervoters + 1
        end
        self.voters[player] = virtualroomteleporter
        self:CheckRoomVotes()
    end
end

function VirtualRoomSet:StopRoomVoteBy(player, virtualroomteleporter)
    if self.voters[player] then
        self.voters[player] = nil
        self.numbervoters = self.numbervoters - 1
        self:CheckRoomVotes()
    end
end

function VirtualRoomSet:GetRoomLinks(roomname)
    return self.rooms[roomname].links
end

function VirtualRoomSet:SetRoomDefinitions(defs)
    self.defs = defs
    self.defs.DeleteLayout(self) -- Mandatory definition.
    self.defs.InitializeLayout(self) -- Mandatory definition.
end

function VirtualRoomSet:ScanOriginalFloorTiles()
    local minx, miny, maxx, maxy = self:GetBoundingBoxInTiles()
    local width = maxx - minx + 1
    self.originalfloortiles = {}
    local otx, oty = self:GetOriginInTiles()

    local index = 1
    for dty = miny, maxy do
        local ty = oty + dty
        for dtx = minx, maxx do
            local tx = otx + dtx
            if self.map:IsTileInVirtualRoomSet(self.roomsetname, tx, ty) then
                local tile = self.map:GetTile(tx, ty)
                self.originalfloortiles[index] = tile
            else
                self.originalfloortiles[index] = VIRTUALROOM_DONOTCARE_TILE
            end
            index = index + 1
        end
    end
end

function VirtualRoomSet:DebugPrintBatch(nameoverride)
    local minx, miny, maxx, maxy = self:GetBoundingBoxInTiles()

    local index = 1
    local dbgstr = {string.format("DebugPrintBatch for roomsetname %s room %s:", self.roomsetname, nameoverride or self:GetCurrentRoomName())}
    for dty = miny, maxy do
        local dbgstr2 = {}
        for dtx = minx, maxx do
            table.insert(dbgstr2, string.format("%4s", tostring(self.floortilesbatch[index])))
            index = index + 1
        end
        table.insert(dbgstr, table.concat(dbgstr2, ", "))
    end

    -- Flip vertical so it prints to the console world aligned and skip first line.
    local lines = #dbgstr
    for i = 2, math.floor((lines + 1) / 2) do
        local j = lines - i + 2
        dbgstr[i], dbgstr[j] = dbgstr[j], dbgstr[i]
    end

    print(table.concat(dbgstr, "\n"))
end

function VirtualRoomSet:NewFloorTileBatch()
    local tilestouse = (self:GetCurrentRoomName() ~= VIRTUALROOMLOBBY and self.defs.defaultfloortiles) or self.originalfloortiles
    if not tilestouse then
        self:ScanOriginalFloorTiles()
        tilestouse = self.originalfloortiles
    end
    self.floortilesbatch = shallowcopy(tilestouse)
end

function VirtualRoomSet:SetFloorTileInBatch(dtx, dty, tile)
    local minx, miny, maxx, maxy = self:GetBoundingBoxInTiles()
    if not (minx <= dtx and dtx <= maxx and miny <= dty and dty <= maxy) then
        assert(false, string.format("SetFloorTileInBatch failed for roomsetname %s room %s at %d %d by being out of bounds", self.roomsetname, self:GetCurrentRoomName(), dtx, dty))
    end

    local ltx, lty = dtx - minx, dty - miny
    local width = maxx - minx + 1
    local index = lty * width + ltx + 1
    if self.floortilesbatch[index] == VIRTUALROOM_DONOTCARE_TILE then
        assert(false, string.format("SetFloorTileInBatch failed for roomsetname %s room %s at %d %d by trying to set in a VIRTUALROOM_DONOTCARE_TILE", self.roomsetname, self:GetCurrentRoomName(), ltx, lty))
    end
    self.floortilesbatch[index] = tile
end

function VirtualRoomSet:ApplyFloorTileBatch()
    local otx, oty = self:GetOriginInTiles()
    local minx, miny, maxx, maxy = self:GetBoundingBoxInTiles()

    -- Defer the collision rebuild to once per batch, as Map Fill/Replace do. Per tile it
    -- rebuilt the same regions dozens of times and cost ~1 ms each.
    local instantphysicsrebuild = self.map:GetInstantPhysicsRebuild()
    self.map:SetInstantPhysicsRebuild(false)

    local index = 1
    for dty = miny, maxy do
        local ty = oty + dty
        for dtx = minx, maxx do
            local tx = otx + dtx
            local tile = self.floortilesbatch[index]
            if tile ~= VIRTUALROOM_DONOTCARE_TILE then
                local oldtile = self.map:GetTile(tx, ty)
                if oldtile ~= tile then
                    self.map:SetTile(tx, ty, tile)
                    local x1, y1, z1 = self.map:GetTileCenterPoint(tx, ty)
                    TempTile_HandleTileChange(x1, y1, z1, oldtile)
                end
            end
            index = index + 1
        end
    end

    self.map:SetInstantPhysicsRebuild(instantphysicsrebuild)
    self.floortilesbatch = nil
end

function VirtualRoomSet:SetVersion(version)
    self.version = version
end

function VirtualRoomSet:FlagForReset()
    self.resetting = true
end

function VirtualRoomSet:IsResetting()
    return self.resetting
end

function VirtualRoomSet:SetVersionAndTryToReset(version)
    if self.version ~= version then
        self:FlagForReset()
    end
    self.version = version
end

function VirtualRoomSet:RecalculateSaveRadius()
    if not self.boundingbox then
        self.saveradius = nil
        return
    end

    -- This needs to find the longest distance to any corner to the bounding box as the radius to save.
    -- The inputs are all in tile coordinates.
    local dxtomin = self.boundingbox.minx
    local dxtomax = self.boundingbox.maxx
    local dytomin = self.boundingbox.miny
    local dytomax = self.boundingbox.maxy
    local dxtominsq = dxtomin * dxtomin
    local dxtomaxsq = dxtomax * dxtomax
    local dytominsq = dytomin * dytomin
    local dytomaxsq = dytomax * dytomax
    local dsqtobl = dxtominsq + dytominsq -- Bottom left corner.
    local dsqtobr = dxtomaxsq + dytominsq -- Bottom right corner.
    local dsqtotr = dxtomaxsq + dytomaxsq -- Top right corner.
    local dsqtotl = dxtominsq + dytomaxsq -- Top left corner.
    local maxdsq = math.max(dsqtobl, dsqtobr, dsqtotr, dsqtotl)

    -- Amplify by the scaling and add the square corner and a small epsilon for floating point precision.
    self.saveradius = math.sqrt(maxdsq) * TILE_SCALE + TILE_SCALE * 0.5 * SQRT2 + 0.1
end

function VirtualRoomSet:GetSaveRadius()
    return self.saveradius
end

function VirtualRoomSet:SetBoundingBox(boundingbox)
    if boundingbox then
        if not (boundingbox.minx <= boundingbox.maxx and boundingbox.miny <= boundingbox.maxy) then
            assert(false, string.format("VirtualRoomSet: RoomSet %s bounding boxes must have the minimum point be smaller than or equal to the maximum.", self.roomsetname))
        end
    end
    self.boundingbox = boundingbox
    self:RecalculateSaveRadius()
end

function VirtualRoomSet:GetBoundingBoxInTiles()
    if not self.boundingbox then
        return nil, nil, nil, nil
    end

    return self.boundingbox.minx, self.boundingbox.miny, self.boundingbox.maxx, self.boundingbox.maxy
end

function VirtualRoomSet:IsDeltaTileInBoundingBoxMask(dtx, dty)
    local minx, miny, maxx, maxy = self:GetBoundingBoxInTiles()
    if dtx < minx or dty < miny or dtx > maxx or dty > maxy then
        return false
    end

    local width = maxx - minx + 1
    local tx, ty = dtx - minx, dty - miny
    local index = ty * width + tx + 1
    local maskvalue = self.boundingbox.mask[index]
    return maskvalue and maskvalue ~= 0 or false
end

function VirtualRoomSet:IsTileInBoundingBoxMask(tx, ty)
    local otx, oty = self:GetOriginInTiles()
    local dtx, dty = tx - otx, ty - oty
    return self:IsDeltaTileInBoundingBoxMask(dtx, dty)
end

function VirtualRoomSet:SetOriginInTiles(tx, ty)
    if self.origin then
        self:SetRoom()
    end
    self.map:SetVirtualRoomSetOriginInTiles(self.roomsetname, tx, ty)
    if tx then
        local x, _, z = self.map:GetTileCenterPoint(tx, ty)
        self.origin = {
            x = x,
            z = z,
            tx = tx,
            ty = ty,
        }
        self.world:PushEvent("ms_virtualroomset_originset", {
            roomsetname = self.roomsetname,
            owner = self.inst,
        })
    else
        self.origin = nil
    end
end

function VirtualRoomSet:SetOrigin(x, y, z)
    local tx, ty = self.map:GetTileCoordsAtPoint(x, 0, z)
    self:SetOriginInTiles(tx, ty)
end

function VirtualRoomSet:GetOriginInTiles()
    if not self.origin then
        return nil, nil
    end

    return self.origin.tx, self.origin.ty
end

function VirtualRoomSet:GetOrigin()
    if not self.origin then
        return nil, nil, nil
    end

    return self.origin.x, 0, self.origin.z
end

function VirtualRoomSet:SetOnHideRoom(OnHideRoom)
    self.config.OnHideRoom = OnHideRoom
end

function VirtualRoomSet:SetOnShowRoom(OnShowRoom)
    self.config.OnShowRoom = OnShowRoom
end

function VirtualRoomSet:SetOnPlayerAdded(OnPlayerAdded)
    self.config.OnPlayerAdded = OnPlayerAdded
end

function VirtualRoomSet:SetOnPlayerRemoved(OnPlayerRemoved)
    self.config.OnPlayerRemoved = OnPlayerRemoved
end

function VirtualRoomSet:SetOnPlayersChanged(OnPlayersChanged)
    self.config.OnPlayersChanged = OnPlayersChanged
end

function VirtualRoomSet:SetOnPostInit(OnPostInit)
    self.config.OnPostInit = OnPostInit
end

function VirtualRoomSet:SetOnVirtualRoomEntitiesChanged(OnVirtualRoomEntitiesChanged)
    self.config.OnVirtualRoomEntitiesChanged = OnVirtualRoomEntitiesChanged
end

function VirtualRoomSet:OnVirtualRoomEntitiesChanged(markers, context)
    if self.config.OnVirtualRoomEntitiesChanged then
        self.config.OnVirtualRoomEntitiesChanged(self.inst, self, markers, context)
    end
end

function VirtualRoomSet:OnPostInit()
    if self.config.OnPostInit then
        self.config.OnPostInit(self.inst, self)
    end
end

local RESERVED_ROOM_NAMES = {
    [VIRTUALROOMLOBBY] = true,
}
function VirtualRoomSet:DeclareVirtualRoom(roomname)
    if RESERVED_ROOM_NAMES[roomname] then
        assert(false, string.format("VirtualRoomSet: RoomName %s is reserved for internal use. Please use another name.", roomname))
    end
    if self.rooms[roomname] then
        assert(false, string.format("VirtualRoomSet: RoomName %s is already in use. Please use another name.", roomname))
    end
    local roomindex = self.numberrooms + 1
    self.numberrooms = roomindex

    local virtualroom = VirtualRoom(roomname, roomindex)

    self.rooms[roomname] = virtualroom
    self.rooms[roomindex] = virtualroom
end

function VirtualRoomSet:GetVirtualRoomEntities(context)
    return self.virtualroommanager:GetVirtualRoomEntities(self.roomsetname, context)
end

function VirtualRoomSet:HideRoom(preventsaving)
    self:CancelPendingTeleport()
    local saveroomdata, toteleportents = self:UnloadRoom(not preventsaving)
    if self.teleportingentsdata then
        self.teleportingentsdata.toteleportents = toteleportents
    end
    self.roomsavedata[self:GetCurrentRoomName()] = saveroomdata
    if self.config.OnHideRoom then
        self.config.OnHideRoom(self.inst, self, toteleportents, self:GetCurrentRoomName())
    end
end

function VirtualRoomSet:ShowRoom()
    local currentroomname = self:GetCurrentRoomName()
    local saveroomdata = self.roomsavedata[currentroomname]
    self.roomsavedata[currentroomname] = nil

    self:LoadRoom(currentroomname, saveroomdata)
    if self.config.OnShowRoom then
        self.config.OnShowRoom(self.inst, self, currentroomname, self.teleportingentsdata)
    end
    if self.teleportingentsdata then
        self:TeleportEntities(self.teleportingentsdata.toteleportents, self.teleportingentsdata.x, self.teleportingentsdata.y, self.teleportingentsdata.z, self.teleportingentsdata.radius)
    end
end

function VirtualRoomSet:SetCurrentRoomIndex(roomindex)
    self.currentroomindex = roomindex
    self.map:SetVirtualRoomSetIsInLobby(self.roomsetname, self:IsCurrentRoomLobby())
end

function VirtualRoomSet:SetRoom(roomnameorroomindex)
    local roomindex = 0
    if roomnameorroomindex then
        local room = self.rooms[roomnameorroomindex]
        roomindex = room and room.roomindex or 0
    end

    if self.currentroomindex ~= roomindex then
        if self:GetCurrentRoomName() == VIRTUALROOMLOBBY then
            self:ScanOriginalFloorTiles()
        end
        self:HideRoom()
        self:SetCurrentRoomIndex(roomindex)
        self:ShowRoom()
        if self:GetCurrentRoomName() == VIRTUALROOMLOBBY then
            self.originalfloortiles = nil
        end
    end
end

function VirtualRoomSet:TeleportEntities(toteleportents, x, y, z, r)
    local entscount = #toteleportents
    local thetaoffset = math.random()
    for i = 1, entscount do
        local ent = toteleportents[i]
        local radius = FunctionOrValue(r, ent) or (math.random() * 0.5 + 1)
        local theta = (((i - 1) / entscount) + thetaoffset) * PI2
        local x1 = x + math.cos(theta) * radius
        local z1 = z - math.sin(theta) * radius
        if ent.Physics then
            ent.Physics:Teleport(x1, 0, z1)
        else
            ent.Transform:SetPosition(x1, 0, z1)
        end
        
        if ent.SnapCamera then
            ent:SnapCamera()
        end
        if self.config.OnTeleportedEntity then
            self.config.OnTeleportedEntity(self.inst, self, ent, x1, z1)
        end
    end
    if self.config.OnTeleportedAllEntities then
        self.config.OnTeleportedAllEntities(self.inst, self, toteleportents, x, z)
    end
    self.virtualroommanager:UpdatePlayerPositions()
    return true
end

function VirtualRoomSet:SetOnTeleportedEntity(OnTeleportedEntity)
    self.config.OnTeleportedEntity = OnTeleportedEntity
end

function VirtualRoomSet:SetOnTeleportedAllEntities(OnTeleportedAllEntities)
    self.config.OnTeleportedAllEntities = OnTeleportedAllEntities
end

function VirtualRoomSet:SetOnPlayerTick(OnPlayerTick)
    self.config.OnPlayerTick = OnPlayerTick
end

function VirtualRoomSet:OnPlayerTick(player, x, y, z)
    local drownable = player.components.drownable
    if drownable then
        if self.map:IsVisualGroundAtPoint(x, y, z) then
            local pt = drownable:GetTeleportPtFor(self.roomsetname)
            if pt then
                pt.x = x
                pt.z = z
            else
                drownable:PushTeleportPt(self.roomsetname, Vector3(x, 0, z))
            end
        end
    end
    if self.config.OnPlayerTick then
        self.config.OnPlayerTick(self.inst, self, player, x, y, z)
    end
end

function VirtualRoomSet:OnPlayerAdded(player, x, y, z)
    local drownable = player.components.drownable
    if drownable then
        if not drownable:GetTeleportPtFor(self.roomsetname) then
            if self.map:IsVisualGroundAtPoint(x, y, z) then
                drownable:PushTeleportPt(self.roomsetname, Vector3(x, 0, z))
            end
        end
    end
    local virtualroom = self:GetCurrentRoom()
    local grueimmunearea_data = {
        name = self.roomsetname,
        isimmune = virtualroom and virtualroom.grueimmunearea or false,
    }
    player:PushEvent("grueimmunearea", grueimmunearea_data)
    if self.config.OnPlayerAdded then
        self.config.OnPlayerAdded(self.inst, self, player)
    end
    self.world:PushEvent("ms_virtualroomset_playeradded", {
        roomsetname = self.roomsetname,
        player = player,
    })
end

function VirtualRoomSet:OnPlayerRemoved(player)
    local drownable = player.components.drownable
    if drownable then
        drownable:PopTeleportPt(self.roomsetname)
    end
    local grueimmunearea_data = {
        name = self.roomsetname,
        isimmune = false,
    }
    player:PushEvent("grueimmunearea", grueimmunearea_data)
    if self.config.OnPlayerRemoved then
        self.config.OnPlayerRemoved(self.inst, self, player)
    end
    self.world:PushEvent("ms_virtualroomset_playerremoved", {
        roomsetname = self.roomsetname,
        player = player,
    })
end

function VirtualRoomSet:OnPlayerJoined(player)
    if not self.players[player] then
        local x, y, z = player.Transform:GetWorldPosition()
        local isplayerinvirtualroomset = self.map:IsPointInVirtualRoomSet(self.roomsetname, x, y, z)
        if isplayerinvirtualroomset then
            self.players[player] = true
            self.numberplayers = self.numberplayers + 1
            self:OnPlayerAdded(player, x, y, z)
            self:OnPlayersChanged()
        end
    end
end

function VirtualRoomSet:OnPlayerLeft(player)
    if self.players[player] then
        self.players[player] = nil
        self.numberplayers = self.numberplayers - 1
        self:OnPlayerRemoved(player)
        self:OnPlayersChanged()
    end
end

function VirtualRoomSet:OnPlayersChanged()
    if self.config.OnPlayersChanged then
        self.config.OnPlayersChanged(self.inst, self, self.players, self.numberplayers)
    end
    self.world:PushEvent("ms_virtualroomset_playerschanged", {
        roomsetname = self.roomsetname,
        players = self.players,
        numberplayers = self.numberplayers,
    })
end

function VirtualRoomSet:CheckForPlayers(playerpositions)
    local playerschanged = false
    local currentplayers = {}
    local numberplayers = 0
    for player, playerpos in pairs(playerpositions) do
        local x, y, z = playerpos:Get()
        local isplayerinvirtualroomset = self.map:IsPointInVirtualRoomSet(self.roomsetname, x, y, z)
        if isplayerinvirtualroomset then
            currentplayers[player] = true
            numberplayers = numberplayers + 1
            if not self.players[player] then
                playerschanged = true
                self:OnPlayerAdded(player, x, y, z)
            else
                self:OnPlayerTick(player, x, y, z)
            end
        end
    end
    for player, _ in pairs(self.players) do
        if not currentplayers[player] then
            playerschanged = true
            self:OnPlayerRemoved(player)
        end
    end
    self.players = currentplayers
    self.numberplayers = numberplayers
    if playerschanged then
        self:OnPlayersChanged()
    end
end

function VirtualRoomSet:HandleResets()
    if self.numberplayers > 0 then
        return
    end

    self:TryToReset()
end

function VirtualRoomSet:TryToReset()
    if not self:IsResetting() then
        return false
    end

    self:SetRoom()
    for k, _ in pairs(self.roomsavedata) do
        self.roomsavedata[k] = nil
    end
    self.resetting = nil
    if self.config.OnReset then
        self.config.OnReset(self.inst, self)
    end
    return true
end

function VirtualRoomSet:SetOnReset(OnReset)
    self.config.OnReset = OnReset
end

function VirtualRoomSet:GetPlayersInfo()
    return self.players, self.numberplayers
end

function VirtualRoomSet:SetDoNotRotateRooms(donotrotaterooms) -- For use with virtual rooms that are more for dynamic terrain set pieces.
    self.donotrotaterooms = donotrotaterooms or nil
end

function VirtualRoomSet:SetKeepInventoryItemsthroughReset(keepinventoryitemsthroughreset)
    self.keepinventoryitemsthroughreset = keepinventoryitemsthroughreset or nil
end

function VirtualRoomSet:SetTeleportingIntoLobbyProhibited(prohibited)
    self.map:SetVirtualRoomSetTeleportingInLobbyProhibited(self.roomsetname, prohibited)
end

function VirtualRoomSet:SetTeleportingOutProhibited(prohibited)
    self.map:SetVirtualRoomSetTeleportingOutProhibited(self.roomsetname, prohibited)
end

function VirtualRoomSet:RotateRoomsTick()
    if self.donotrotaterooms then
        return
    end

    if not self.roomindexbeforerotate then
        self.roomindexbeforerotate = self.currentroomindex
    end
    local roomindex = self.currentroomindex + 1
    if roomindex > self.numberrooms then
        roomindex = 0
    end
    self:SetRoom(roomindex)
end

function VirtualRoomSet:FinishRotatingRooms()
    if self.roomindexbeforerotate then
        self:SetRoom(self.roomindexbeforerotate)
        self.roomindexbeforerotate = nil
    end
end

function VirtualRoomSet:IsEntInVirtualRoom(ent)
    local x, y, z = ent.Transform:GetWorldPosition()
    return self.map:IsPointInVirtualRoomSet(self.roomsetname, x, y, z)
end

function VirtualRoomSet:FindSafePlayerPointFrom(x, y, z)
    if self.config.FindSafePlayerPointFrom then
        local x1, y1, z1 = self.config.FindSafePlayerPointFrom(self.inst, self, x, y, z)
        if x1 then
            return x1, y1, z1
        end
    end
    return x, y, z
end
function VirtualRoomSet:SetFindSafePlayerPointFrom(FindSafePlayerPointFrom)
    self.config.FindSafePlayerPointFrom = FindSafePlayerPointFrom
end

local SAVE_CLASSIFIED_TAGS = {"CLASSIFIED"}
local SAVE_NO_TAGS = { "INLIMBO" }
local SAVE_CONTAINER_TAGS = { "_inventory", "_container" }

local _SKIP = 1
local _SAVE = 2
local _KEEP = 3

local function _GetEntUnloadAction(self, ent)
    if not ent:IsValid() or ent.entity:GetParent() or ent:HasTag("staysthroughvirtualrooms") then
        return _SKIP
    end

    local owner = ent
    while true do
        local nextowner =
            (owner.components.spell and owner.components.spell.target) or
            (owner.components.formationleader and owner.components.formationleader.target) or
            (owner.components.follower and owner.components.follower:GetLeader()) or
            (owner.components.inventoryitem and owner.components.inventoryitem.owner)
        --NOTE: inventoryitem.owner check only applies after we've found spell target
        --      or leader, since we already did a GetParent() check on ourself above.

        if nextowner and nextowner:IsValid() then
            owner = nextowner
        else
            break
        end
    end

    if owner ~= ent and owner.entity:GetParent() or not self:IsEntInVirtualRoom(owner) then
        return _SKIP
    elseif owner.isplayer or (
            owner:HasAnyTag("irreplaceable", "followsthroughvirtualrooms") or
            (owner.components.migrationpetowner and owner.components.migrationpetowner:GetPet()) or
            (owner.components.inventoryitem and self.keepinventoryitemsthroughreset and self.resetting)
        ) and not owner:HasTag("forcedtosavethroughvirtualrooms") then
        return _KEEP
    end
    return _SAVE
end

local function ShouldContainerInstDropItemOnRoomUnload(inst, item)
    return item:HasTag("irreplaceable") or (item.components.migrationpetowner and item.components.migrationpetowner:GetPet())
end
function VirtualRoomSet:UnloadRoom(save)
    local saveradius = self:GetSaveRadius()
    if not saveradius then
        return nil, nil
    end

    local recbyguid, refs, toremove
    if save then
        save = { ents = {} }
        recbyguid = {}
        refs = {}
        toremove = {}
    end

    local x, _, z = self.inst.Transform:GetWorldPosition()
    for _, v in ipairs(TheSim:FindEntities(x, 0, z, saveradius, nil, SAVE_NO_TAGS, SAVE_CONTAINER_TAGS)) do
        if _GetEntUnloadAction(self, v) == _SAVE then
            local container = v.components.inventory or v.components.container
            if container then
                container:DropEverythingByFilter(ShouldContainerInstDropItemOnRoomUnload)
            end
        end
    end

    POPULATING = true --@V2C: hope this is safe XD

    local ents = TheSim:FindEntities(x, 0, z, saveradius, nil, SAVE_NO_TAGS)
    local keepidx = 0
    for i = 1, #ents do
        local v = ents[i]
        ents[i] = nil

        local unloadaction = _GetEntUnloadAction(self, v)
        if unloadaction == _SKIP then
            --Do nothing.
        elseif unloadaction == _SAVE then
            if save then
                table.insert(toremove, v) --defer removal so we can save references
                if v.persists and v.prefab --[[and v.Transform and v.entity:GetParent() == nil redundant checks]] then
                    local record, new_refs = v:GetSaveRecord()
                    record.prefab = nil

                    if new_refs then
                        refs[v.GUID] = v
                        for _, guid in pairs(new_refs) do
                            refs[guid] = v
                        end
                    end

                    recbyguid[v.GUID] = record

                    if save.ents[v.prefab] == nil then
                        save.ents[v.prefab] = {}
                    end
                    table.insert(save.ents[v.prefab], record)
                end
            else
                v:Remove()
            end
        else--if unloadaction == _KEEP then
            --Don't remove entities that aren't saved by the room
            keepidx = keepidx + 1
            ents[keepidx] = v
        end
    end
    
    -- NOTES(JBK): Some entities are CLASSIFIED and must be handled on a case by case basis if it should save too.
    for _, v in ipairs(TheSim:FindEntities(x, 0, z, saveradius, SAVE_CLASSIFIED_TAGS)) do
        if v:HasTag("forcedtosavethroughvirtualrooms") then
            -- unloadaction is always _SAVE for this case
            if save then
                table.insert(toremove, v) --defer removal so we can save references
                if v.persists and v.prefab --[[and v.Transform and v.entity:GetParent() == nil redundant checks]] then
                    local record, new_refs = v:GetSaveRecord()
                    record.prefab = nil

                    if new_refs then
                        refs[v.GUID] = v
                        for _, guid in pairs(new_refs) do
                            refs[guid] = v
                        end
                    end

                    recbyguid[v.GUID] = record

                    if save.ents[v.prefab] == nil then
                        save.ents[v.prefab] = {}
                    end
                    table.insert(save.ents[v.prefab], record)
                end
            else
                v:Remove()
            end
        end
    end

    if refs then
        for guid, v in pairs(refs) do
            local record = recbyguid[guid]
            if record then
                record.id = guid
            else
                print("Missing reference:", v, "->", guid, Ents[guid])
            end
        end
    end

    if toremove then
        for i, v in ipairs(toremove) do
            v:Remove()
        end
    end

    POPULATING = false

    if save and next(save.ents) then
        save.world_time = math.floor((self.world.state.cycles + self.world.state.time) * 100 + 0.5) * 0.01
    else
        save = nil
    end

    return save, ents --remaining entities that weren't saved/removed
end

function VirtualRoomSet:LayoutNewRoom(roomname)
    local layout = self.defs.layouts[roomname]
    if roomname == VIRTUALROOMLOBBY then
        layout = EMPTYLAYOUT
    elseif layout == nil then
        assert(false, string.format("VirtualRoomSet: RoomSet %s tried to LayoutNewRoom an unknown roomname %s!", self.roomsetname, roomname))
    end

    self:NewFloorTileBatch()
    if layout.ApplyFloorTiles then
        layout.ApplyFloorTiles(self.inst, self)
    end
    self:ApplyFloorTileBatch()
    if layout.CreateRoomEntities then
        POPULATING = true --@V2C: hope this is safe XD
        layout.CreateRoomEntities(self.inst, self)
        POPULATING = false
    end
end

function VirtualRoomSet:LoadRoom(roomname, roomsavedata)
    if roomsavedata == nil then
        self:LayoutNewRoom(roomname)
        return
    end

    local layout = self.defs.layouts[roomname]
    if roomname == VIRTUALROOMLOBBY then
        layout = EMPTYLAYOUT
    elseif layout == nil then
        assert(false, string.format("VirtualRoomSet: RoomSet %s tried to LoadRoom an unknown roomname %s!", self.roomsetname, roomname))
    end

    local x, _, z = self.inst.Transform:GetWorldPosition()
    self:NewFloorTileBatch()
    if layout.ApplyFloorTiles then
        layout.ApplyFloorTiles(self.inst, self)
    end
    self:ApplyFloorTileBatch()

    POPULATING = true --@V2C: hope this is safe XD
    local newents = {}
    for prefab, ents in pairs(roomsavedata.ents) do
        for i, v in ipairs(ents) do
            v.prefab = v.prefab or prefab -- prefab field is stripped out when entities are saved in global entity collections, so put it back
            SpawnSaveRecord(v, newents)
        end
    end
    --post pass in neccessary to hook up references
    for _, v in pairs(newents) do
        v.entity:LoadPostPass(newents, v.data)
    end
    POPULATING = false

    if roomsavedata.world_time then
        local dt = (self.world.state.cycles + self.world.state.time - roomsavedata.world_time) * TUNING.TOTAL_DAY_TIME
        if dt > 0 then
            for _, v in pairs(newents) do
                if v.entity:IsValid() then
                    v.entity:LongUpdate(dt)
                end
            end
        end
    end
end

function VirtualRoomSet:OnSave()
    local data = {
        version = self.version,
        resetting = self.resetting,
        currentroomname = self:GetCurrentRoomName(),
        roomsavedata = self.roomsavedata,
        originalfloortiles = self.originalfloortiles,
        roomindexbeforerotate = self.roomindexbeforerotate,
    }
    return data
end

function VirtualRoomSet:OnLoad(data)--, ents)
    self.resetting = data.resetting
    self.roomindexbeforerotate = data.roomindexbeforerotate
    self:SetVersionAndTryToReset(data.version)
    if data.currentroomname and (data.currentroomname ~= VIRTUALROOMLOBBY) then
        local roomdata = self.rooms[data.currentroomname]
        if roomdata and roomdata.roomindex then
            self:SetCurrentRoomIndex(roomdata.roomindex)
        else
            self:SetCurrentRoomIndex(0)
            self:FlagForReset()
        end
    end
    if data.roomsavedata then
        self.roomsavedata = data.roomsavedata
    end
    if data.customdata then
        self.customdata = data.customdata
    end
    if data.originalfloortiles then
        local tile_id_conversion_map = self.world.tile_id_conversion_map
        self.originalfloortiles = data.originalfloortiles
        for i, tile in ipairs(self.originalfloortiles) do
            if tile ~= VIRTUALROOM_DONOTCARE_TILE then
                self.originalfloortiles[i] = tile_id_conversion_map[tile] or tile
            end
        end
    end
    self:DoInit()
end

return VirtualRoomSet
