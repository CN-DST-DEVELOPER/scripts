local GolfPropItem = Class(function(self, inst)
    self.inst = inst
    self.minx = nil
    self.maxx = nil
    self.minz = nil
    self.maxz = nil
    self.teleportx = nil
    self.teleportz = nil
    self.droppedspeedmult = 0.25

    self.update_time_accumulator = math.random(15) * FRAMES

    self.inst:StartUpdatingComponent(self)
end)

function GolfPropItem:SetXZBounding(minx, maxx, minz, maxz)
    self.minx = minx
    self.maxx = maxx
    self.minz = minz
    self.maxz = maxz
end

function GolfPropItem:SetTeleportXZ(x, z)
    self.teleportx = x
    self.teleportz = z
end

function GolfPropItem:StopUpdating()
    self.inst:StopUpdatingComponent(self)
end

function GolfPropItem:DropItem(x, z)
    if self.inst.components.inventoryitem then
        self.inst.components.inventoryitem:RemoveFromOwner(true)
        self.inst.Transform:SetPosition(x, 0, z)
        self.inst.components.inventoryitem:OnDropped(true, self.droppedspeedmult)

        self.inst.prevcontainer = nil
        self.inst.prevslot = nil
    else
        self.inst.Transform:SetPosition(x, 0, z)
    end
end

function GolfPropItem:Erode(x, z)
    self:DropItem(x, z)
    self.inst:DoTaskInTime(0.5, ErodeAway, 1.5)
    self.inst:StopUpdatingComponent(self)
    self.inst.persists = false
    self.inst.components.inventoryitem.canbepickedup = false
end

function GolfPropItem:TeleportBack()
    local newx, newz = self.teleportx or ((self.minx + self.maxx) / 2), self.teleportz or ((self.minz + self.maxz) / 2)
    SpawnPrefab("carnival_confetti_fx").Transform:SetPosition(newx, 0, newz)
    self:DropItem(newx, newz)
end

function GolfPropItem:CheckTeleport()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    if x < self.minx or x > self.maxx or z < self.minz or z > self.maxz then
        self:TeleportBack()
    end
end

function GolfPropItem:OnUpdate(dt)
    self.update_time_accumulator = self.update_time_accumulator + dt
    if self.update_time_accumulator < 0.5 then
        return
    end

    if not self.minx then
        return
    end

    self:CheckTeleport()
end

return GolfPropItem