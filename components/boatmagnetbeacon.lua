local function OnPickup(inst, data)
    local self = inst.components.boatmagnetbeacon
    self:SetIsPickedUp(true)
end

local function OnDropped(inst, data)
    local self = inst.components.boatmagnetbeacon
    self:SetIsPickedUp(false)
end

local MAGNET_MUST_TAGS = {"boatmagnet"}
local MAGNET_MUST_NOT_TAGS = {"paired"}
local function SetupBoatTask(inst)
    local self = inst.components.boatmagnetbeacon
    if self == nil then
        return
    end

    self:SetBoat(inst:GetCurrentPlatform())

    if self.magnet_guid then
        local x, y, z = inst.Transform:GetWorldPosition()
        local magnets = TheSim:FindEntities(x, y, z, TUNING.BOAT.BOAT_MAGNET.MAX_DISTANCE, MAGNET_MUST_TAGS, MAGNET_MUST_NOT_TAGS)
        local magnet = nil
        for _, v in ipairs(magnets) do
            if v.components.boatmagnet and v.components.boatmagnet.magnet_guid == self.magnet_guid then
                magnet = v
                break
            end
        end
        if magnet then -- Already know it has the component from above.
            magnet.components.boatmagnet:PairWithBeacon(inst)
            self.magnet = magnet
            self.magnet_guid = magnet.GUID
        else
            self.magnet = nil
            self.magnet_guid = nil
        end
    end

    self._setup_boat_task = nil
end

local BoatMagnetBeacon = Class(function(self, inst)
    self.inst = inst
	self.boat = nil
    self.magnet = nil
    self.magnet_guid = nil
    self.turnedoff = false
    self.ispickedup = false

    self.OnBoatRemoved = function() self.boat = nil end
    self.OnBoatDeath = function() self:OnDeath() end

    self.OnMagnetRemoved = function()
        self:UnpairWithMagnet()
    end

	self._setup_boat_task = self.inst:DoTaskInTime(0, SetupBoatTask)

    self.inst:ListenForEvent("onpickup", OnPickup)
    self.inst:ListenForEvent("ondropped", OnDropped)
end)

function BoatMagnetBeacon:OnSave()
    local data = {
        turnedoff = self.turnedoff,
        ispickedup = self.ispickedup,
        magnet_guid = self.magnet_guid,
    }
    return data
end

function BoatMagnetBeacon:OnLoad(data)
    if data == nil then
        return
    end

    self.turnedoff = data.turnedoff
    self.ispickedup = data.ispickedup
    self.magnet_guid = data.magnet_guid or data.prev_guid -- NOTES(JBK): 'prev_guid' is for beta worlds that might have this old vague name.

    if self.boat == nil then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
    elseif self.turnedoff then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
        self.inst:AddTag("turnedoff")
    else
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon_on")
    end
end

function BoatMagnetBeacon:OnRemoveFromEntity()
	if self._setup_boat_task ~= nil then
		self._setup_boat_task:Cancel()
        self._setup_boat_task = nil
	end
    self.inst:RemoveEventCallback("onpickup", OnPickup)
    self.inst:RemoveEventCallback("ondropped", OnDropped)
end

function BoatMagnetBeacon:OnRemoveEntity()
    if self ~= nil then
        self:SetBoat(nil)
    end
end

function BoatMagnetBeacon:GetBoat()
    -- Get the carrying thing first, or the owner entity instance if it is not carried.
    local boat = (self.inst.entity:GetParent() or self.inst):GetCurrentPlatform()
    if boat and boat:HasTag("boat") then
        self.boat = boat
    else
        self.boat = nil
    end
    return self.boat
end

function BoatMagnetBeacon:SetBoat(boat)
	if boat == self.boat then return end

	if self.boat ~= nil then
        self.inst:RemoveEventCallback("onremove", self.OnBoatRemoved, boat)
        self.inst:RemoveEventCallback("death", self.OnBoatDeath, boat)
    end

    self.boat = boat

    if boat ~= nil then
        self.inst:ListenForEvent("onremove", self.OnBoatRemoved, boat)
        self.inst:ListenForEvent("death", self.OnBoatDeath, boat)
    end
end

function BoatMagnetBeacon:OnDeath()
	if self.inst:IsValid() then
	    --self.inst.SoundEmitter:KillSound("boat_movement")
        self:SetBoat(nil)
	end
end

function BoatMagnetBeacon:PairedMagnet()
    return self.magnet
end

function BoatMagnetBeacon:PairWithMagnet(magnet)
    if self.magnet or not magnet then
        return
    end

    self.magnet = magnet
    self.magnet_guid = self.magnet.GUID

    self.inst:ListenForEvent("onremove", self.OnMagnetRemoved, self.magnet)
    self.inst:ListenForEvent("death", self.OnMagnetRemoved, self.magnet)

    self:TurnOnBeacon()
    self.inst:AddTag("paired")
end

function BoatMagnetBeacon:UnpairWithMagnet()
    if not self.magnet then
        return
    end

    self.inst:RemoveEventCallback("onremove", self.OnMagnetRemoved, self.magnet)
    self.inst:RemoveEventCallback("death", self.OnMagnetRemoved, self.magnet)

    self.magnet = nil
    self.magnet_guid = nil

    self:TurnOffBeacon()
    self.inst:RemoveTag("paired")
end

function BoatMagnetBeacon:IsTurnedOff()
    return self.turnedoff
end

function BoatMagnetBeacon:TurnOnBeacon()
    self.turnedoff = false

    if self.inst.components.inventoryitem then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon_on")
    end

    self.inst.sg:GoToState("activate")
    self.inst:PushEvent("onturnon")

    self.inst:RemoveTag("turnedoff")
end

function BoatMagnetBeacon:TurnOffBeacon()
    self.turnedoff = true

    if self.inst.components.inventoryitem then
        self.inst.components.inventoryitem:ChangeImageName("boat_magnet_beacon")
    end

    self.inst.sg:GoToState("deactivate")
    self.inst:PushEvent("onturnoff")

    self.inst:AddTag("turnedoff")
end

function BoatMagnetBeacon:IsPickedUp()
    return self.ispickedup
end

function BoatMagnetBeacon:SetIsPickedUp(pickedup)
    self.ispickedup = pickedup
    self.boat = not pickedup and self:GetBoat() or nil
end

return BoatMagnetBeacon
