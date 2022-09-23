local BoatMagnet = Class(function(self, inst)
    self.inst = inst
	self.boat = nil
    self.beacon = nil
    self.magnet_guid = nil

    self.canpairwithfn = function(beacon)
            if beacon == nil or beacon.components.boatmagnetbeacon == nil then
                return false
            end
            local pairedmagnet = beacon.components.boatmagnetbeacon:PairedMagnet()
            return pairedmagnet == nil
        end

	self.OnBoatRemoved = function() self.boat = nil end
    self.OnBoatDeath = function() self:OnDeath() end

    self.OnBeaconRemoved = function()
        self:UnpairWithBeacon()
    end
    self.OnBeaconDeath = function()
        self:UnpairWithBeacon()
    end

    self.OnBeaconTurnedOn = function()
        if not self:IsBeaconOnSameBoat(self.beacon) then
            self.inst.sg:GoToState("pull")
        else
            self.inst.sg:GoToState("idle")
        end
    end

    self.OnBeaconTurnedOff = function()
        self.inst.sg:GoToState("pull_pst")
    end

    self.OnInventoryBeaconLoaded = function(inst, data)
        if data and data.guid == self.prev_guid then
            self:PairWithBeacon(data.inst)
        end
    end

	self._setup_boat_task = self.inst:DoTaskInTime(0, function()
        self:SetBoat(self.inst:GetCurrentPlatform())
		self._setup_boat_task = nil
    end)
end)

function BoatMagnet:OnSave()
    local data = {
        magnet_guid = self.inst.GUID,
    }
    return data
end

function BoatMagnet:OnLoad(data)
    if data == nil then
        return
    end

    self.magnet_guid = data.magnet_guid or data.prev_guid -- NOTES(JBK): 'prev_guid' is for beta worlds that might have this old vague name.
end

function BoatMagnet:OnRemoveFromEntity()
	if self._setup_boat_task ~= nil then
		self._setup_boat_task:Cancel()
        self._setup_boat_task = nil
	end
    self:UnpairWithBeacon() -- Handles event listeners.
end

function BoatMagnet:OnRemoveEntity()
    if self ~= nil then
        self:SetBoat(nil)
    end
end

function BoatMagnet:SetBoat(boat)
	if boat == self.boat then return end

	if self.boat ~= nil then
        self.boat.components.boatphysics:RemoveMagnet(self)
        self.inst:RemoveEventCallback("onremove", self.OnBoatRemoved, boat)
        self.inst:RemoveEventCallback("death", self.OnBoatDeath, boat)
    end

    self.boat = boat

    if boat ~= nil then
        self.boat.components.boatphysics:AddMagnet(self)
        self.inst:ListenForEvent("onremove", self.OnBoatRemoved, boat)
        self.inst:ListenForEvent("death", self.OnBoatDeath, boat)
    end
end

function BoatMagnet:OnDeath()
	if self.inst:IsValid() then
	    --self.inst.SoundEmitter:KillSound("boat_movement")
        self:SetBoat(nil)
	end
end

function BoatMagnet:IsActivated()
    return self.beacon ~= nil
end

function BoatMagnet:PairedBeacon()
    return self.beacon
end

function BoatMagnet:IsBeaconOnSameBoat(beacon)
    if beacon == nil then
        return false
    end
    local beaconcmp = beacon.components.boatmagnetbeacon
    return beaconcmp ~= nil and self.boat ~= beaconcmp:GetBoat()
end

local BEACON_MUST_TAGS = { "boatmagnetbeacon" }
function BoatMagnet:FindNearestBeacon()
    -- Pair with the closest beacon in range
    local nearestbeacon = FindClosestEntity(self.inst, TUNING.BOAT.BOAT_MAGNET.PAIR_RADIUS, true, BEACON_MUST_TAGS, nil, nil, self.canpairwithfn)
    if nearestbeacon ~= nil and nearestbeacon.components.boatmagnetbeacon ~= nil and nearestbeacon.components.boatmagnetbeacon:PairedMagnet() == nil then
        return nearestbeacon
    end

    return nil
end

function BoatMagnet:PairWithBeacon(beacon)
    if beacon == nil or beacon.components.boatmagnetbeacon == nil then
        return
    end

    self.beacon = beacon
    beacon.components.boatmagnetbeacon:PairWithMagnet(self.inst)

    self.inst:ListenForEvent("onremove", self.OnBeaconRemoved, beacon)
    self.inst:ListenForEvent("death", self.OnBeaconDeath, beacon)
    self.inst:ListenForEvent("onturnon", self.OnBeaconTurnedOn, beacon)
    self.inst:ListenForEvent("onturnoff", self.OnBeaconTurnedOff, beacon)

    self.inst:StartUpdatingComponent(self)

    if beacon.components.boatmagnetbeacon:IsTurnedOff() or self:IsBeaconOnSameBoat(beacon) then
        self.inst.sg:GoToState("idle")
    else
        self.inst.sg:GoToState("pull_pre")
    end

    self.inst:AddTag("paired")
end

function BoatMagnet:UnpairWithBeacon()
    if self.beacon == nil then
        return
    end

    self.inst:RemoveEventCallback("onremove", self.OnBeaconRemoved, self.beacon)
    self.inst:RemoveEventCallback("death", self.OnBeaconDeath, self.beacon)
    self.inst:RemoveEventCallback("onturnon", self.OnBeaconTurnedOn, self.beacon)
    self.inst:RemoveEventCallback("onturnoff", self.OnBeaconTurnedOff, self.beacon)

    if self.beacon.components.boatmagnetbeacon ~= nil then
        self.beacon.components.boatmagnetbeacon:UnpairWithMagnet()
    end

    self.beacon = nil

    self.inst:StopUpdatingComponent(self)

    if not self.inst.sg:HasStateTag("burnt") then
        self.inst.sg:GoToState("pull_pst")
    end

    self.inst:RemoveTag("paired")
end

function BoatMagnet:GetFollowTarget()
    if self.beacon == nil or self.beacon.components.boatmagnetbeacon == nil then
        return nil
    end

    local beacon = self.beacon.components.boatmagnetbeacon
    local beaconboat = beacon:GetBoat()
    local followtarget = beaconboat or (beacon:IsPickedUp() and beacon.inst.entity:GetParent()) or self.beacon

    return followtarget
end

function BoatMagnet:CalcMaxVelocity()
    if self.beacon == nil or self.beacon.components.boatmagnetbeacon == nil or self.boat == nil then
        return 0
    end

    -- Beyond a set distance, apply an exponential rate for catch-up speed, otherwise match the speed of the beacon its following
    local direction, distance = self:CalcMagnetDirection()

    local followtarget = self:GetFollowTarget()
    if followtarget == nil then
        return 0
    end

    local beaconboat = self.beacon.components.boatmagnetbeacon:GetBoat()

    local beaconspeed = beaconboat == nil and followtarget.components.locomotor and math.min(followtarget.components.locomotor:GetRunSpeed(), TUNING.BOAT.MAX_VELOCITY)
                        or (beaconboat ~= nil and math.min(beaconboat.components.boatphysics:GetVelocity(), TUNING.BOAT.MAX_FORCE_VELOCITY))
                        or 0

    local mindistance = self.boat.components.hull ~= nil and self.boat.components.hull:GetRadius() or 1
    if beaconboat ~= nil and beaconboat.components.hull ~= nil then
        mindistance = mindistance + beaconboat.components.hull:GetRadius()
    end

    -- If the beacon boat is turning, reduce max speed to prevent too much drifting while turning
    local magnetboatdirection = self.boat.components.boatphysics:GetMoveDirection()
    local beaconboatdirection = beaconboat == nil and followtarget.components.locomotor and Vector3(followtarget.Physics:GetVelocity())
                            or (beaconboat ~= nil and beaconboat.components.boatphysics:GetMoveDirection())
                            or Vector3(0, 0, 0)
    local boatspeed = self.boat.components.boatphysics:GetVelocity()

    local magnetdir_x, magnetdir_z = VecUtil_NormalizeNoNaN(magnetboatdirection.x, magnetboatdirection.z)
    local beacondir_x, beacondir_z = VecUtil_NormalizeNoNaN(beaconboatdirection.x, beaconboatdirection.z)

    local turnspeedmodifier = boatspeed > 0 and beaconspeed > 0 and math.max(VecUtil_Dot(magnetdir_x, magnetdir_z, beacondir_x, beacondir_z), 0) or 1
    local maxdistance = TUNING.BOAT.BOAT_MAGNET.MAX_DISTANCE / 2

    if not self.beacon.components.boatmagnetbeacon:IsTurnedOff() then
        if distance > mindistance then
            local base = math.pow(TUNING.BOAT.BOAT_MAGNET.MAX_VELOCITY + TUNING.BOAT.BOAT_MAGNET.CATCH_UP_SPEED, 1 / maxdistance)
            local maxspeed = beaconspeed + (math.pow(base, distance - mindistance) - 1) * turnspeedmodifier
            return math.min(maxspeed, TUNING.BOAT.BOAT_MAGNET.MAX_VELOCITY + TUNING.BOAT.BOAT_MAGNET.CATCH_UP_SPEED)
        else
            local maxspeed = beaconspeed * turnspeedmodifier
            return math.min(maxspeed, TUNING.BOAT.BOAT_MAGNET.MAX_VELOCITY)
        end
    end
    return 0
end

function BoatMagnet:CalcMagnetDirection()
    local followtarget = self:GetFollowTarget()
    if followtarget == nil then
        return Vector3(0, 0, 0)
    end

    -- Calculate distance between magnet & beacon.
    -- If we're carrying a beacon but walking on a boat, use the boat's position instead
    local boatpos = self.boat:GetPosition()
    local targetpos = followtarget:GetPosition()
    local vel_x, vel_z = VecUtil_NormalizeNoNaN(VecUtil_Sub(targetpos.x, targetpos.z, boatpos.x, boatpos.z))

    local direction = Vector3(vel_x, 0, vel_z)
    local distance = VecUtil_Dist(targetpos.x, targetpos.z, boatpos.x, boatpos.z)

    return direction, distance
end

function BoatMagnet:CalcMagnetForce()
    if self.beacon == nil or self.boat == nil then
        return 0
    end

    local beacon = self.beacon.components.boatmagnetbeacon
    local boatphysics = self.boat.components.boatphysics
    if beacon == nil or beacon:IsTurnedOff() or boatphysics == nil then
        return 0
    end

    -- If on a boat, follow the boat, otherwise follow the entity that's carrying the beacon in their inventory
    local beaconboat = beacon:GetBoat()
    local followtarget = self:GetFollowTarget()
    if followtarget == nil then
        return 0
    end

    local direction, distance  = self:CalcMagnetDirection()

    -- Calcuate the minimum distance a magnet can reach the beacon so boats don't ram into one another
    local mindistance = self.boat.components.hull ~= nil and self.boat.components.hull:GetRadius() + 1 or 1
    if beaconboat ~= nil and beaconboat.components.hull ~= nil then
        mindistance = mindistance + beaconboat.components.hull:GetRadius()
    end

    return distance > mindistance and TUNING.BOAT.BOAT_MAGNET.MAGNET_FORCE or 0
end

function BoatMagnet:OnUpdate(dt)
    if self.boat == nil or self.beacon == nil or self.beacon.components.boatmagnetbeacon == nil then
        return
    end

    local beaconboat = self.beacon.components.boatmagnetbeacon:GetBoat()

    -- Handle if the beacon is being carried on the same boat as the magnet
    if self.boat == beaconboat and self.inst.sg:HasStateTag("pulling") then
        self.inst.sg:GoToState("pull_pst")
        return
    elseif self.boat ~= beaconboat and self.inst.sg:HasStateTag("idle") and not self.beacon.components.boatmagnetbeacon:IsTurnedOff() then
        self.inst.sg:GoToState("pull_pre")
    end

    local followtarget = self:GetFollowTarget()
    if followtarget == nil then
        self:UnpairWithBeacon()
        return
    end

    local direction, distance = self:CalcMagnetDirection()

    -- Disengage if we're too far from the beacon
    if distance > TUNING.BOAT.BOAT_MAGNET.MAX_DISTANCE then
        self:UnpairWithBeacon()
        return
    end

    -- Rotate to face the target it's following. If on the same boat, set rotation to zero.
    if self.boat ~= beaconboat then
        self.inst.Transform:SetRotation(-VecUtil_GetAngleInDegrees(direction.x, direction.z))
    else
        self.inst.Transform:SetRotation(0)
    end
end

return BoatMagnet
