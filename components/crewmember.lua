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
        if bc and (not platform or not platform:IsValid()) then return end

        local platform_boatphysics = platform.components.boatphysics
        if not platform_boatphysics then return end

        local can_stop = false
        local platform_boatcrew = platform.components.boatcrew
        if platform_boatcrew and platform_boatcrew.target then
            local target_boatphysics = platform_boatcrew.target.components.boatphysics
            local target_vector = Vector3(target_boatphysics.velocity_x, 0, target_boatphysics.velocity_z)
            local local_vector = Vector3(platform_boatphysics.velocity_x, 0, platform_boatphysics.velocity_z)

            local combo = target_vector + local_vector
            if combo:Length() <= local_vector:Length() then
                can_stop = true
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

        elseif platform_boatcrew and platform_boatcrew.target
                and platform_boatcrew.target:IsValid()
                and platform:GetDistanceSqToInst(platform_boatcrew.target) < 100
                and can_stop then
            direction = "stop"
        end

        local row_dir_x, row_dir_z = nil, nil
        if self.boat.components.boatcrew then
            row_dir_x, row_dir_z = self.boat.components.boatcrew:GetHeadingNormal()
        end

        if not row_dir_x or not row_dir_z then
            local boat_x, boat_y, boat_z = self.boat.Transform:GetWorldPosition()
            local doer_x, doer_y, doer_z = self.inst.Transform:GetWorldPosition()
            row_dir_x, row_dir_z = VecUtil_Normalize(boat_x - doer_x, boat_z - doer_z)
        end

        if direction == "stop" then
            row_dir_x = platform_boatphysics.velocity_x * -1
            row_dir_z = platform_boatphysics.velocity_z * -1
            row_dir_x, row_dir_z = VecUtil_Normalize(row_dir_x, row_dir_z)
        elseif direction == "away" then
            row_dir_x = row_dir_x  * -1
            row_dir_z = row_dir_z  * -1
        end

        row_dir_x, row_dir_z = VecUtil_Normalize(row_dir_x, row_dir_z)

        platform_boatphysics:ApplyRowForce(row_dir_x, row_dir_z, self.force, self.max_velocity)
    end
end

function CrewMember:GetDebugString()
    return string.format("herd:%s %s",tostring(self.boat), (not self.enabled) and "disabled" or "")
end

return CrewMember
