local Follower = Class(function(self, inst)
    self.inst = inst

    self._leader = net_entity(inst.GUID, "follower._leader")
    self._itemowner = net_entity(inst.GUID, "follower._itemowner")
end)

function Follower:SetLeader(leader)
    self._leader:set(leader)
end

function Follower:SetItemOwner(owner)
    self._itemowner:set(owner)
end

function Follower:GetLeader()
    return self._itemowner:value() or self._leader:value()
end

return Follower