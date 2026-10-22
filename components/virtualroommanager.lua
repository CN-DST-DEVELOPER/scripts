local VirtualRoomManager = Class(function(self, inst)

local _world = TheWorld
assert(_world.ismastersim, "VirtualRoomManager should not exist on the client!")

self.map = _world.Map

self.inst = inst

local CURRENT_VERSION = 1
self.version = CURRENT_VERSION

self.virtualroomsets = {}
self.numbervirtualroomsets = 0

-- NOTES(JBK): These entity references are not saved and are done here at the world component side instead of the virtualroomset component to ensure load order guarantees.
-- Entities populated are done after the world entity is created and register themselves with an event the world listens for.
self.virtualroomsetentities = {}

self.updateaccumulator = 0
self.UPDATE_TICK_TIME = 1
self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT = 10
self.updaterotatecooldownticks = self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT

self.inst:ListenForEvent("ms_virtualroomset_removed", function(inst, data)
    if data and data.roomsetname then
        self:DeleteVirtualRoomSet(data.roomsetname)
    end
end, _world)
self.inst:ListenForEvent("ms_virtualroomset_originset", function(inst, data)
    if data and data.roomsetname then
        self:CheckForBoundingBoxCollisions()
    end
end, _world)

self.inst:ListenForEvent("ms_register_virtualroom_entity", function(inst, data) self:OnRegisterVirtualRoomEntity(data) end, _world)
self.inst:ListenForEvent("ms_unregister_virtualroom_entity", function(inst, data) self:OnUnregisterVirtualRoomEntity(data) end, _world)

end)

function VirtualRoomManager:OnVirtualRoomEntitiesChanged(roomsetname)
    if self.ignoreonvirtualroomentitieschanged then
        return
    end

    if self.postinited then
        local virtualroomset = self:GetVirtualRoomSet(roomsetname)
        if virtualroomset then
            virtualroomset:OnVirtualRoomEntitiesChanged()
        end
    else
        if not self.pendingonvirtualroomentitieschanged then
            self.pendingonvirtualroomentitieschanged = {
                roomsetname,
            }
        elseif not table.contains(self.pendingonvirtualroomentitieschanged, roomsetname) then
            table.insert(self.pendingonvirtualroomentitieschanged, roomsetname)
        end
    end
end

function VirtualRoomManager:OnRegisterVirtualRoomEntity(data)
    local ent, roomsetname, context, onlyoneprefab = data.inst, data.roomsetname, data.context or VIRTUALROOMCONTEXT.NONE, data.onlyoneprefab

    local entitiesinroomset = self.virtualroomsetentities[roomsetname]
    if not entitiesinroomset then
        entitiesinroomset = {}
        self.virtualroomsetentities[roomsetname] = entitiesinroomset
    end

    local entitiesincontext = entitiesinroomset[context]
    if not entitiesincontext then
        entitiesincontext = {}
        entitiesinroomset[context] = entitiesincontext
    end

    if not table.contains(entitiesincontext, ent) then
        if onlyoneprefab then
            self.ignoreonvirtualroomentitieschanged = true -- Hack flag to prevent entity onremove events issuing a OnVirtualRoomEntitiesChanged call.
            for i = #entitiesincontext, 1, -1 do
                local tocheck = entitiesincontext[i]
                if tocheck and (tocheck.prefab == ent.prefab) then
                    tocheck:Remove()
                end
            end
            self.ignoreonvirtualroomentitieschanged = nil
            -- The table could have been removed from a callback of the tocheck:Remove() call above so let us set the tables back in case it was.
            self.virtualroomsetentities[roomsetname] = entitiesinroomset
            entitiesinroomset[context] = entitiesincontext
        end
        table.insert(entitiesincontext, ent)
    end

    self:OnVirtualRoomEntitiesChanged(roomsetname)
end

function VirtualRoomManager:OnUnregisterVirtualRoomEntity(data)
    local ent, roomsetname, context = data.inst, data.roomsetname, data.context or VIRTUALROOMCONTEXT.NONE

    local entitiesinroomset = self.virtualroomsetentities[roomsetname]
    if not entitiesinroomset then
        return
    end

    local entitiesincontext = entitiesinroomset[context]
    if not entitiesincontext then
        return
    end

    table.removearrayvalue(entitiesincontext, ent)
    if #entitiesincontext == 0 then
        entitiesinroomset[context] = nil
        if next(entitiesinroomset) == nil then
            self.virtualroomsetentities[roomsetname] = nil
        end
    end

    self:OnVirtualRoomEntitiesChanged(roomsetname)
end

function VirtualRoomManager:GetVirtualRoomEntities(roomsetname, context)
    local entitiesinroomset = self.virtualroomsetentities[roomsetname]
    return entitiesinroomset and entitiesinroomset[context] or nil
end

function VirtualRoomManager:GetVirtualRoomSet(roomsetname)
    return self.virtualroomsets[roomsetname]
end

function VirtualRoomManager:DeclareVirtualRoomSet(virtualroomset, roomsetname)
    if self:GetVirtualRoomSet(roomsetname) then
        assert(false, string.format("VirtualRoomManager: Duplicate RoomSet name %s is not allowed.", roomsetname))
    end

    local roomsetindex = self.numbervirtualroomsets + 1
    self.numbervirtualroomsets = roomsetindex
    if roomsetindex == 1 then
        self.inst:StartUpdatingComponent(self)
    elseif roomsetindex >= MAX_VIRTUALROOMSETS then
        assert(false, string.format("VirtualRoomManager: Cannot declare RoomSet name %s. Too many virtual rooms were declared. The current maximum is %d and is an engine defined constant.", roomsetname, MAX_VIRTUALROOMSETS))
    end

    self.virtualroomsets[roomsetname] = virtualroomset
    self.virtualroomsets[roomsetindex] = virtualroomset

    virtualroomset.roomsetindex = roomsetindex

    self.map:DeclareVirtualRoomSet(roomsetname)
end

function VirtualRoomManager:DeleteVirtualRoomSet(roomsetname)
    local virtualroomset = self:GetVirtualRoomSet(roomsetname)
    if not virtualroomset then
        return
    end

    virtualroomset:SetRoom(0)

    -- Remove it from the room set list.
    for i = virtualroomset.roomsetindex, self.numbervirtualroomsets - 1 do
        self.virtualroomsets[i] = self.virtualroomsets[i + 1]
    end
    self.virtualroomsets[self.numbervirtualroomsets] = nil
    self.numbervirtualroomsets = self.numbervirtualroomsets - 1
    self.virtualroomsets[roomsetname] = nil
    virtualroomset.roomsetindex = nil

    if self.numbervirtualroomsets == 0 then
        self.inst:StopUpdatingComponent(self)
    end

    self.map:DeleteVirtualRoomSet(roomsetname)
end

function VirtualRoomManager:CheckForBoundingBoxCollisions()
    for i = 1, self.numbervirtualroomsets do
        local virtualroomset_1 = self.virtualroomsets[i]
        local tx1, ty1 = virtualroomset_1:GetOriginInTiles()
        local minx1, miny1, maxx1, maxy1 = virtualroomset_1:GetBoundingBoxInTiles()
        if tx1 and minx1 then
            local b1_minx, b1_maxx = tx1 + minx1, tx1 + maxx1
            local b1_miny, b1_maxy = ty1 + miny1, ty1 + maxy1
            for j = i + 1, self.numbervirtualroomsets do
                local virtualroomset_2 = self.virtualroomsets[j]
                local tx2, ty2 = virtualroomset_2:GetOriginInTiles()
                local minx2, miny2, maxx2, maxy2 = virtualroomset_2:GetBoundingBoxInTiles()
                if tx2 and minx2 then
                    local b2_minx, b2_maxx = tx2 + minx2, tx2 + maxx2
                    local b2_miny, b2_maxy = ty2 + miny2, ty2 + maxy2
                    local colliding = b1_maxx >= b2_minx and b1_minx <= b2_maxx and b1_maxy >= b2_miny and b1_miny <= b2_maxy
                    if colliding then
                        -- We are colliding rectangles now do a fine pass check over the boundingbox.mask to see if they intersect which is more expensive.
                        print("FIXME(JBK): CheckForBoundingBoxCollisions: Check for boundingbox.mask here.")
                        assert(false, string.format("VirtualRoomManager: RoomSet %s is colliding with RoomSet %s.", virtualroomset_1.roomsetname, virtualroomset_2.roomsetname))
                    end
                end
            end
        end
    end
end

function VirtualRoomManager:WillBoundingBoxCollideAt(boundingbox, tx, ty)
    for i = 1, self.numbervirtualroomsets do
        local virtualroomset_1 = self.virtualroomsets[i]
        local tx1, ty1 = virtualroomset_1:GetOriginInTiles()
        local minx1, miny1, maxx1, maxy1 = virtualroomset_1:GetBoundingBoxInTiles()
        if tx1 and minx1 then
            local b1_minx, b1_maxx = tx1 + minx1, tx1 + maxx1
            local b1_miny, b1_maxy = ty1 + miny1, ty1 + maxy1

            local tx2, ty2 = tx, ty
            local minx2, miny2, maxx2, maxy2 = boundingbox.minx, boundingbox.miny, boundingbox.maxx, boundingbox.maxy
            if tx2 and minx2 then
                local b2_minx, b2_maxx = tx2 + minx2, tx2 + maxx2
                local b2_miny, b2_maxy = ty2 + miny2, ty2 + maxy2
                local colliding = b1_maxx >= b2_minx and b1_minx <= b2_maxx and b1_maxy >= b2_miny and b1_miny <= b2_maxy
                if colliding then
                    return true
                end
            end
        end
    end
    return false
end

function VirtualRoomManager:StartRoomVoteForRoomSetBy(player, roomsetname, virtualroomteleporter)
    local virtualroomset = self:GetVirtualRoomSet(roomsetname)
    if virtualroomset then
        virtualroomset:StartRoomVoteBy(player, virtualroomteleporter)
    end
end

function VirtualRoomManager:StopRoomVoteForRoomSetBy(player, roomsetname, virtualroomteleporter)
    local virtualroomset = self:GetVirtualRoomSet(roomsetname)
    if virtualroomset then
        virtualroomset:StopRoomVoteBy(player, virtualroomteleporter)
    end
end

function VirtualRoomManager:ForEachVirtualRoomSet(fn, ...)
    for i = 1, self.numbervirtualroomsets do
        local virtualroomset = self.virtualroomsets[i]
        if fn(virtualroomset, ...) then
            break
        end
    end
end

VirtualRoomManager.OnPostInit_VirtualRoomSet = function(virtualroomset)
    virtualroomset:OnPostInit()
end

function VirtualRoomManager:OnPostInit()
    self.postinited = true
    self:ForEachVirtualRoomSet(self.OnPostInit_VirtualRoomSet)
end

VirtualRoomManager.OnTick_VirtualRoomSet_UpdatePlayers = function(virtualroomset, playerpositions)
    virtualroomset:CheckForPlayers(playerpositions)
end
VirtualRoomManager.OnTick_VirtualRoomSet_HandleResets = function(virtualroomset)
    virtualroomset:HandleResets()
end
VirtualRoomManager.OnTick_VirtualRoomSet_RotateRooms = function(virtualroomset)
    virtualroomset:RotateRoomsTick()
end
VirtualRoomManager.OnTick_VirtualRoomSet_FinishRotatingRooms = function(virtualroomset)
    virtualroomset:FinishRotatingRooms()
end

function VirtualRoomManager:UpdatePlayerPositions()
    local playerpositions = {}
    for _, player in ipairs(AllPlayers) do
        playerpositions[player] = player:GetPosition()
    end
    self:ForEachVirtualRoomSet(self.OnTick_VirtualRoomSet_UpdatePlayers, playerpositions)
end

function VirtualRoomManager:OnTick()
    local playerpositions = {}
    for _, player in ipairs(AllPlayers) do
        playerpositions[player] = player:GetPosition()
    end
    self:ForEachVirtualRoomSet(self.OnTick_VirtualRoomSet_UpdatePlayers, playerpositions)
    self:ForEachVirtualRoomSet(self.OnTick_VirtualRoomSet_HandleResets)
    local cooldownticks
    if next(playerpositions) == nil then
        cooldownticks = self.updaterotatecooldownticks - 1
        if cooldownticks <= 0 then
            cooldownticks = self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT
            self:ForEachVirtualRoomSet(self.OnTick_VirtualRoomSet_RotateRooms)
        end
    else
        self:ForEachVirtualRoomSet(self.OnTick_VirtualRoomSet_FinishRotatingRooms)
        cooldownticks = self.UPDATE_ROTATE_ROOMS_COOLDOWN_TICKS_COUNT
    end
    self.updaterotatecooldownticks = cooldownticks
end

function VirtualRoomManager:OnUpdate(dt)
    if self.pendingonvirtualroomentitieschanged and self.postinited then
        for _, roomsetname in ipairs(self.pendingonvirtualroomentitieschanged) do
            local virtualroomset = self:GetVirtualRoomSet(roomsetname)
            if virtualroomset then
                virtualroomset:OnVirtualRoomEntitiesChanged()
            end
        end
        self.pendingonvirtualroomentitieschanged = nil
    end
    self.updateaccumulator = self.updateaccumulator + dt
    if self.updateaccumulator > self.UPDATE_TICK_TIME then
        self.updateaccumulator = 0
        self:OnTick()
    end
end

function VirtualRoomManager:GetDebugString()
    local str = {}
    for _, virtualroomset in ipairs(self.virtualroomsets) do
        local otx, oty = virtualroomset:GetOriginInTiles()
        if not otx then
            otx, oty = -1, -1
        end
        table.insert(str,
            string.format("  %s[%08X] Current Room %d[%s], Max Room %d, Players %d, Voters %d, origin %d_%d",
            virtualroomset.roomsetname, hash(virtualroomset.roomsetname),
            virtualroomset.currentroomindex, virtualroomset:GetCurrentRoomName(), virtualroomset.numberrooms,
            virtualroomset.numberplayers, virtualroomset.numbervoters,
            otx, oty))
    end
    return string.format("VirtualRoomSets: %d\n%s", self.numbervirtualroomsets, table.concat(str, "\n"))
end

return VirtualRoomManager