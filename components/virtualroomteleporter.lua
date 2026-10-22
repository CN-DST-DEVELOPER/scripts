local VirtualRoomTeleporter = Class(function(self, inst)
    self.inst = inst

    self.world = TheWorld
    assert(self.world.ismastersim, "VirtualRoomTeleporter should not exist on client!")
    self.virtualroommanager = self.world.components.virtualroommanager
    assert(self.virtualroommanager, "VirtualRoomTeleporter demands virtualroommanager to exist on TheWorld.")

    --self.roomsetname = nil
    self.voters = {}

    -- Recommended to explicitly add tag to prefab pristine state
    self.inst:AddTag("virtualroomteleporter")
end)

function VirtualRoomTeleporter:ClearAllVoters()
    for player, _ in pairs(self.voters) do
        self:StopRoomVote(player)
    end
end

function VirtualRoomTeleporter:OnRemoveFromEntity()
    self.inst:RemoveTag("virtualroomteleporter")
    self:ClearAllVoters()
end

function VirtualRoomTeleporter:OnRemoveEntity()
    self:ClearAllVoters()
end

function VirtualRoomTeleporter:SetOnDepart(OnDepart)
    self.ondepart = OnDepart
end

function VirtualRoomTeleporter:SetOnArrive(OnArrive)
    self.onarrive = OnArrive
end

function VirtualRoomTeleporter:OnDepart(virtualroomset)
    if self.ondepart then
        self.ondepart(self.inst, virtualroomset)
    end
end

function VirtualRoomTeleporter:OnArrive()
    if self.onarrive then
        self.onarrive(self.inst)
    end
end

function VirtualRoomTeleporter:SetOnForceRegisterEntity(OnForceRegisterEntity)
    self.onforceregisterentity = OnForceRegisterEntity
end

function VirtualRoomTeleporter:OnForceRegisterEntity()
    if self.onforceregisterentity then
        self.onforceregisterentity(self.inst)
    end
end

function VirtualRoomTeleporter:SetDirection(virtualroomdirection)
    self.direction = virtualroomdirection
end

function VirtualRoomTeleporter:GetDirection()
    return self.direction
end

function VirtualRoomTeleporter:SetShuffledDirection(virtualroomdirection)
    self.shuffleddirection = virtualroomdirection
end

function VirtualRoomTeleporter:GetShuffledDirection()
    return self.shuffleddirection
end

function VirtualRoomTeleporter:SetRoomSetName(roomsetname)
    self.roomsetname = roomsetname
end

function VirtualRoomTeleporter:GetRoomSetName()
    return self.roomsetname
end

function VirtualRoomTeleporter:SetTeleportFXPrefab(tpfxprefab)
    self.tpfxprefab = tpfxprefab
end

function VirtualRoomTeleporter:GetTeleportFXPrefab()
    return self.tpfxprefab
end

function VirtualRoomTeleporter:SetTemporaryTargetRoomName(temporarytargetroomname)
    self.temporarytargetroomname = temporarytargetroomname
end

function VirtualRoomTeleporter:GetVirtualRoomSet()
    return self.virtualroommanager:GetVirtualRoomSet(self.roomsetname)
end

function VirtualRoomTeleporter:GetTargetRoomName()
    local virtualroomset = self:GetVirtualRoomSet()
    if not virtualroomset then
        return VIRTUALROOMLOBBY
    end

    if self.temporarytargetroomname then
        return self.temporarytargetroomname
    end

    local virtualroom = virtualroomset:GetCurrentRoom()
    if not virtualroom then
        return VIRTUALROOMLOBBY
    end

    local links = virtualroom.links
    local direction = self:GetDirection()
    if not direction then
        return VIRTUALROOMLOBBY
    end

    return links[direction].linkedroom
end

function VirtualRoomTeleporter:GetTeleportDestinationPosition(ent)
    local virtualroomset = self:GetVirtualRoomSet()
    if not virtualroomset then
        return nil, nil, nil
    end

    if self.destinationoverridefn then
        local x, y, z = self.destinationoverridefn(self.inst, ent)
        if x then
            return x, y, z
        end
    end

    return self.inst.Transform:GetWorldPosition()
end

function VirtualRoomTeleporter:SetTeleportDestinationPositionOverride(fn)
    self.destinationoverridefn = fn
end

function VirtualRoomTeleporter:StartRoomVote(player)
    self.voters[player] = true
    self.virtualroommanager:StartRoomVoteForRoomSetBy(player, self.roomsetname, self)
end

function VirtualRoomTeleporter:StopRoomVote(player)
    self.voters[player] = nil
    self.virtualroommanager:StopRoomVoteForRoomSetBy(player, self.roomsetname, self)
end

function VirtualRoomTeleporter:OnSave()
    local data = {
        direction = VIRTUALROOMDIRECTIONS_INDEX[self.direction],
        shuffleddirection = VIRTUALROOMDIRECTIONS_INDEX[self.shuffleddirection],
        roomsetname = self.roomsetname,
    }
    return data
end

function VirtualRoomTeleporter:OnLoad(data)
    if data then
        if data.direction then
            self:SetDirection(VIRTUALROOMDIRECTIONS[data.direction])
        end
        if data.shuffleddirection then
            self:SetShuffledDirection(VIRTUALROOMDIRECTIONS[data.shuffleddirection])
        end
        if data.roomsetname then
            self:SetRoomSetName(data.roomsetname)
        end
    end
end

function VirtualRoomTeleporter:GetDebugString()
    return string.format("Direction: %s, ShuffledDirection: %s", self.direction or "N/A", self.shuffleddirection or "N/A")
end

return VirtualRoomTeleporter
