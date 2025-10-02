local VaultTeleporter = Class(function(self, inst)
    self.inst = inst

    --self.markername = nil
    --self.roomid = nil
    --self.directionname = nil
    --self.unshuffleddirectionname = nil
    --self.rigid = nil

    self.counter = 0
end)

function VaultTeleporter:Reset()
    self.markername = nil
    self.roomid = nil
end

function VaultTeleporter:SetRigid(rigid)
    self.rigid = rigid
end

function VaultTeleporter:GetRigid()
    return self.rigid
end

function VaultTeleporter:SetTargetMarkerName(markername)
    self.markername = markername
end

function VaultTeleporter:GetTargetMarkerName()
    return self.markername
end

function VaultTeleporter:SetTargetRoomID(roomid)
    self.roomid = roomid
    self.inst:PushEvent("newvaultteleporterroomid", roomid)
end

function VaultTeleporter:GetTargetRoomID()
    return self.roomid
end

function VaultTeleporter:SetDirectionName(directionname)
    self.directionname = directionname
end

function VaultTeleporter:GetDirectionName()
    return self.directionname
end

function VaultTeleporter:SetUnshuffledDirectionName(unshuffleddirectionname)
    self.unshuffleddirectionname = unshuffleddirectionname
end

function VaultTeleporter:GetUnshuffledDirectionName()
    return self.unshuffleddirectionname
end

function VaultTeleporter:AddCounter()
    self.counter = self.counter + 1
end

function VaultTeleporter:RemoveCounter()
    self.counter = self.counter - 1
end

function VaultTeleporter:GetCounter()
    return self.counter
end

function VaultTeleporter:TeleportEntitiesToInst(ents, targetinst)
    local x, y, z = targetinst.Transform:GetWorldPosition()
    for _, ent in ipairs(ents) do
    end
end

return VaultTeleporter
