local function _OnUpdate(inst, self)
    self:OnUpdate()
end

local function AddMemberListeners(self, member)
    self.inst:ListenForEvent("onremove", self._onmemberkilled, member)
    self.inst:ListenForEvent("death", self._onmemberkilled, member)
	self.inst:ListenForEvent("teleported", self._onmemberkilled, member)
end

local function RemoveMemberListeners(self, member)
    self.inst:RemoveEventCallback("onremove", self._onmemberkilled, member)
    self.inst:RemoveEventCallback("death", self._onmemberkilled, member)
	self.inst:RemoveEventCallback("teleported", self._onmemberkilled, member)
end

local Boatcrew = Class(function(self, inst)
    self.inst = inst
    self.members = {}
    self.membercount = 0
    self.membertag = nil
    self.captain = nil

    self.tinkertargets = {}

    self.gatherrange = nil
    self.updaterange = nil

    self.addmember = nil
    self.removemember = nil

    self.heading = nil
    self.target = nil
    self.flee = nil

    self.status = "hunting"
--math.random() * 2 + 6
    self.task = self.inst:DoPeriodicTask(2, _OnUpdate, nil, self)
    self.inst:ListenForEvent("onremove", function() 
        if TheWorld.components.piratespawner then
            TheWorld.components.piratespawner:RemoveShipData(self.inst)
        end
    end)
    self._onmemberkilled = function(member) self:RemoveMember(member) end
end)

function Boatcrew:TestForLootToSteal()
    local loot = false
    for member,bool in pairs(self.members) do
        if member ~= self.captain and not member.nothingtosteal then
            loot = true 
            break
        end
    end
    return loot
end

function Boatcrew:TestForVictory()
    if self:CountPirateLoot() > (self:CountCrew()*3) then
        return true
    end
    for member,bool in pairs(self.members)do 
        if member.victory then
            return true
        end
    end
end

function Boatcrew:CrewCheer()
    for member,bool in pairs(self.members) do
        if not member.victory then
            self.inst:DoTaskInTime((math.random()*0.4)+0.2, function() 
                member.victory = true
                member:PushEvent("cheer",{ say=STRINGS["MONKEY_BATTLECRY_VICTORY_CHEER"][math.random(1,#STRINGS["MONKEY_BATTLECRY_VICTORY_CHEER"])] })
            end)
        end
    end
end


function Boatcrew:CountPirateLoot()
    local loot = 0
    for member,bool in pairs(self.members)do
        for k,v in pairs(member.components.inventory.itemslots)do
            if not v:HasTag("personal_possession") then
                if v.components.stackable then
                    loot = loot + v.components.stackable.stacksize
                else
                    loot = loot + 1
                end
            end
        end
    end
    return loot
end

function Boatcrew:CountCrew()
    local crew = 0
    for member,bool in pairs(self.members)do
        crew = crew + 1
    end
    return crew
end

function Boatcrew:OnRemoveFromEntity()
    self.task:Cancel()
    for k, v in pairs(self.members) do
        RemoveMemberListeners(self, k)
    end
end

function Boatcrew:OnRemoveEntity()
    for k, v in pairs(self.members) do
        self:RemoveMember(k)
    end
end

function Boatcrew:GetDebugString()
    local str = ""
    return str
end

function Boatcrew:SetMemberTag(tag)
    self.membertag = tag
	if tag == nil then
		self.membersearchtags = nil
	else
		self.membersearchtags = { "crewmember", tag }
	end
end

function Boatcrew:areAllCrewOnBoat()
    local allthere = true
    for member in pairs(self.members)do
        if member:GetCurrentPlatform() ~= member.components.crewmember.boat then
            allthere = false
            break
        end
    end
    return allthere
end

function Boatcrew:GetHeadingNormal()

    local pt = nil
    local boatpt = Vector3(self.inst.Transform:GetWorldPosition())

    if self.target then     

        if self.status == "retreat" and self:areAllCrewOnBoat() then
            local x,y,z = self.target.Transform:GetWorldPosition()
            local heading = self.inst:GetAngleToPoint(x, 0, z)
            local offset = Vector3(1 * math.cos( heading*DEGREES ), 0, -1 * math.sin( heading*DEGREES ))
            pt = Vector3(boatpt.x +offset.x,0,boatpt.z + offset.z)
        else
            pt = Vector3(self.target.Transform:GetWorldPosition())

            local scaler = Remap(distsq(pt.x, pt.z, boatpt.x, boatpt.z),0,10*10, 0,1)

            if self.target.components.boatphysics then
                pt.x  = pt.x + (self.target.components.boatphysics.velocity_x * scaler)
                pt.z  = pt.z + (self.target.components.boatphysics.velocity_z * scaler)
            end
        end

    elseif self.heading then
        local offset = Vector3(1 * math.cos( self.heading*DEGREES ), 0, -1 * math.sin( self.heading*DEGREES ))
        pt = Vector3(boatpt.x +offset.x,0,boatpt.z + offset.z)
    end
    
    if pt then
        return VecUtil_Normalize(pt.x - boatpt.x  , pt.z - boatpt.z)
    end
end

function Boatcrew:SetHeading(heading)
    self.heading = heading
end

function Boatcrew:SetTarget(target)
    self.target = target
end

function Boatcrew:SetUpdateRange(range)
    self.updaterange = range
end

function Boatcrew:SetAddMemberFn(fn)
    self.addmember = fn
end

function Boatcrew:SetRemoveMemberFn(fn)
    self.removemember = fn
end

local function removecaptain(captain)
    local bc = captain.components.crewmember.boat and captain.components.crewmember.boat.components.boatcrew or nil
    if bc then
        TheWorld.components.piratespawner:RemoveShipData(bc.inst)
        bc.inst:RemoveComponent("vanish_on_sleep")
        bc.inst:RemoveComponent("boatcrew")
    end
end

function Boatcrew:SetCaptain(captain)
    if self.captain then
        self.captain:RemoveEventCallback("onremove",removecaptain)
    end
    self.captain = captain
    self.captain:ListenForEvent("onremove",removecaptain)
end

function Boatcrew:AddMember(inst, setcaptain)
    if not self.members[inst] then
        self.membercount = self.membercount + 1
        self.members[inst] = true

        AddMemberListeners(self, inst)

        if inst.components.crewmember ~= nil then
            inst.components.crewmember:SetBoat(self.inst)
        end
        if self.addmember ~= nil then
            self.addmember(self.inst, inst)
        end        
    end
    if setcaptain then
        self:SetCaptain(inst)
    end
end

function Boatcrew:RemoveMember(inst)
    if self.members[inst] then

        if inst.components.crewmember and inst.components.crewmember.leavecrewfn then
            inst.components.crewmember.leavecrewfn(inst)
        end

        if self.removemember ~= nil then
            self.removemember(self.inst, inst)
        end

        RemoveMemberListeners(self, inst)

        if inst.components.crewmember ~= nil then
            inst.components.crewmember:SetBoat(nil)
        end
        self.membercount = self.membercount - 1
        self.members[inst] = nil

        if self.membercount < 1 then
			inst:RemoveComponent("vanish_on_sleep")
            inst:RemoveComponent("boatcrew")
        end
    end
end

function Boatcrew:checktinkertarget(target)
    if self.tinkertargets[target.GUID] ~= nil then
        return true
    end
end

function Boatcrew:reserveinkertarget(target)
    self.tinkertargets[target.GUID] = true
end

function Boatcrew:removeinkertarget(target)
    if self.tinkertargets[target.GUID] ~= nil then
        self.tinkertargets[target.GUID] = nil
    end
end

function Boatcrew:IsCrewOnDeck()
    for member,bool in pairs(self.members) do
        if member:GetCurrentPlatform() ~= self.inst then
            return false
        end
    end
    return true
end

function Boatcrew:OnUpdate()

    if self.target and (self:TestForLootToSteal() ~= true or self:TestForVictory() or self.flee ) then 
        self.status = "retreat"
    elseif self.target then
        self.status = "assault"
    else
        self.status = "hunting"
    end
end

function Boatcrew:OnSave()
    local data = {}

    for k, v in pairs(self.members) do
        if data.members == nil then
            data.members = { k.GUID }
        else
            table.insert(data.members, k.GUID)
        end
    end

    return data, data.members
end

function Boatcrew:LoadPostPass(newents, savedata)
    if savedata.members ~= nil then
        for k, v in pairs(savedata.members) do
            local member = newents[v]
            if member ~= nil then
                self:AddMember(member.entity)
            end
        end
    end
end

return Boatcrew
