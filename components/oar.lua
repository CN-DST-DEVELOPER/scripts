local Oar = Class(function(self, inst)
    self.inst = inst
    self.fail_idx = 0
    self.fail_string_count = 3
	self.fail_wetness = 9

	self.max_velocity = TUNING.MAX_FORCE_VELOCITY
end)

function Oar:Row(doer, pos)
	local platform = doer:GetCurrentPlatform()
	if platform == nil or not platform:IsValid() then return end

	local boat_physics = platform.components.boatphysics
	if boat_physics == nil then return end

	local doer_x, doer_y, doer_z = doer.Transform:GetWorldPosition()
	local row_dir_x, row_dir_z = VecUtil_Normalize(pos.x - doer_x, pos.z - doer_z)

	if doer.components.playercontroller.isclientcontrollerattached then
		local boat_x, boat_y, boat_z = boat_physics.inst.Transform:GetWorldPosition()
		row_dir_x, row_dir_z = VecUtil_Normalize(doer_x - boat_x, doer_z - boat_z)
	end

	local character_force_mult = 1
	if doer.components.expertsailor and doer.components.expertsailor:HasRowForceMultiplier() then
		character_force_mult = doer.components.expertsailor:GetRowForceMultiplier()
	end

	boat_physics:ApplyRowForce(row_dir_x, row_dir_z, self.force * character_force_mult, self.max_velocity)
end

function Oar:RowFail(doer)
	self.fail_idx = (self.fail_idx + 1) % self.fail_string_count

	local doer_x, doer_y, doer_z = doer.Transform:GetWorldPosition()

    local ents = TheSim:FindEntities(doer_x, doer_y, doer_z, 2)
    for k, v in pairs(ents) do
        local moisture = v.components.moisture
        if moisture ~= nil then
            local waterproofness = (v.components.inventory and math.min(v.components.inventory:GetWaterproofness(),1)) or 0
            moisture:DoDelta(self.fail_wetness * (1 - waterproofness))
        end
    end

    return "BAD_TIMING" .. tostring(self.fail_idx)
end

return Oar