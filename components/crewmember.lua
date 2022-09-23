local function onenabled(self, enabled)
    if enabled then
        self.inst:AddTag("crewmember")
    else
        self.inst:RemoveTag("crewmember")
    end
end

local CrewMember = Class(function(self, inst)
    self.inst = inst

    --V2C: Recommended to explicitly add tag to prefab pristine state
    self.enabled = true

    self.boat = nil

    self.max_velocity = 4
    self.force = 1
end,
nil,
{
    enabled = onenabled,
})


function CrewMember:OnRemoveFromEntity()
    self.inst:RemoveTag("crewmember")
end

function CrewMember:Shouldrow()

    local boat = self.inst:GetCurrentPlatform() == self.inst.components.crewmember.boat and self.inst:GetCurrentPlatform()
    if not boat then
        return nil
    end
    if not self.boat then
        return nil
    end

    if not self.boat.components.boatcrew or
        -- NO DIRECTION SET FOR THE BOAT
        (not self.boat.components.boatcrew.target and not self.boat.components.boatcrew.heading) then
        return nil
    end   

    if self.boat.components.boatcrew.status == "assault" and self.boat.components.boatcrew.target and  self.boat.components.boatcrew.target:IsValid() and  self.boat:GetDistanceSqToInst(self.boat.components.boatcrew.target) < 10*10  then
        -- BOAT IS CLOSE ENOUGH TO TARGET
        return nil
    end
    return true
end

function CrewMember:SetBoat(boat)
    self.boat = boat
end

function CrewMember:GetBoat()
    return self.boat
end

function CrewMember:Leave()
    if self.boat ~= nil and self.boat:IsValid() then
        self.boat.components.boatcrew:RemoveMember(self.inst)
	end
end

function CrewMember:Enable(enabled)
    if not enabled and self.boat ~= nil and self.boat:IsValid() then
        self.boat.components.boatcrew:RemoveMember(self.inst)
    end
    self.enabled = enabled
end

function CrewMember:Row()
    if self.boat and self.boat:IsValid() then
        local platform = self.boat
        local bc = self.boat.components.boatcrew
        if bc and platform == nil or not platform:IsValid() then return end    

        local boat_physics = platform.components.boatphysics
        if boat_physics == nil then return end

        local can_Stop = false
        if platform.components.boatcrew and platform.components.boatcrew.target then
            local target_boat_physics = platform.components.boatcrew.target.components.boatphysics
            local target_vector = Vector3(target_boat_physics.velocity_x,0,target_boat_physics.velocity_z)
            local local_vector = Vector3(boat_physics.velocity_x,0,boat_physics.velocity_z)

            local combo = target_vector + local_vector

            if combo:Length() <= local_vector:Length() then
                can_Stop = true
            end
        end

        local direction = "toward"
        if bc and bc.status == "retreat" then

            local allthere = true
            for member in pairs(self.boat.components.boatcrew.members) do
                if member:GetCurrentPlatform() ~= self.inst.components.crewmember.boat then
                    allthere = false
                end
            end
            if allthere then
               direction = "away"
            end

        elseif platform.components.boatcrew and platform.components.boatcrew.target and platform.components.boatcrew.target:IsValid() and platform:GetDistanceSqToInst(platform.components.boatcrew.target) < 10*10 and can_Stop then                        
            direction = "stop"
        end

        local row_dir_x, row_dir_z = nil, nil
        
        if self.boat.components.boatcrew then
            row_dir_x, row_dir_z = self.boat.components.boatcrew:GetHeadingNormal()
        end
            
        if not row_dir_x or not row_dir_z then
            local pos = Vector3(self.boat.Transform:GetWorldPosition())
            local doer_x, doer_y, doer_z = self.inst.Transform:GetWorldPosition()
            row_dir_x, row_dir_z = VecUtil_Normalize(pos.x - doer_x, pos.z - doer_z)
        end

        if direction == "stop" then
            row_dir_x = boat_physics.velocity_x * -1
            row_dir_z = boat_physics.velocity_z * -1
            row_dir_x, row_dir_z = VecUtil_Normalize(row_dir_x, row_dir_z)
        elseif direction == "away" then
            row_dir_x = row_dir_x  * -1
            row_dir_z = row_dir_z  * -1 
        end

        row_dir_x, row_dir_z = VecUtil_Normalize(row_dir_x, row_dir_z)

        boat_physics:ApplyRowForce(row_dir_x, row_dir_z, self.force , self.max_velocity)
    end
end

function CrewMember:GetDebugString()
    return string.format("herd:%s %s",tostring(self.boat), (not self.enabled) and "disabled" or "")
end

return CrewMember
