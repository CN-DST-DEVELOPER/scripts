local HullHealth = Class(function(self, inst)
    self.inst = inst

	self.inst:ListenForEvent("on_collide", function(inst,data) self:OnCollide(data) end)

	self.leak_point_count = 6
	self.leak_radius = 2.5
	self.leak_radius_variance = 1
	self.leak_angle_variance = math.pi / 8

	self.leak_damage = {}
	self.leak_indicators = {}
	self.leak_indicators_dynamic = {}
	self.small_leak_dmg = 0.1
	self.med_leak_dmg = 0.75
	self.hull_dmg = 0
	self.selfdegradingtime = 0
	self.currentdegradetime = 0
	--self.degradefx = nil

	for leak_idx = 1, self.leak_point_count do
		self.leak_damage[leak_idx] = 0
		self.leak_indicators[leak_idx] = nil
	end

	self.inst:DoPeriodicTask(1, function(inst) self:UpdateHealth() end)
end)

function HullHealth:GetDamageMult(cat)
	-- This is a function to collect things that will protect the boat from various effects
	-- cat "degradedamage" sets teh multiplier on the time it takes to take a point of damage.
	-- cat "collide" sets mulitplier on colission damage
	local mult = 1

	--local ents = self.inst.components.WalkablePlatform and self.inst.components.WalkablePlatform:GetEntitiesOnPlatform() or nil

	local x,y,z = self.inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x,y,z, 4)

	-- look for the pirate hat
	if ents and #ents > 0 then
		for i,ent in ipairs(ents)do
			if ent:GetCurrentPlatform() and ent:GetCurrentPlatform() == self.inst then
				if ent:HasTag("boat_health_buffer") then
					if cat == "degradedamage" then
						mult = 2
						break
					elseif cat == "collide" then
						mult = 0.5
						break
					end
				end
			end
		end
	end
	return mult
end

function HullHealth:UpdateHealth()
    if self.inst.components.health:IsDead() then return end

	local hull_damage = 0
	for k,v in pairs(self.leak_indicators) do
		if v ~= nil and v:IsValid() then
			local state = v.components.boatleak.current_state
			if state == "small_leak" then
				hull_damage = hull_damage + 0.5
			elseif state == "med_leak" then
				hull_damage = hull_damage + 1
			end
		end
	end
	for _,v in pairs(self.leak_indicators_dynamic) do
		if v ~= nil and v:IsValid() then
			local state = v.components.boatleak.current_state
			if state == "small_leak" then
				hull_damage = hull_damage + 0.5
			elseif state == "med_leak" then
				hull_damage = hull_damage + 1
			end
		end
	end

	self.inst.components.health:DoDelta(-hull_damage)

	if hull_damage > 0 then
		self.inst:AddTag("is_leaking")
	else
		self.inst:RemoveTag("is_leaking")
	end
end

function HullHealth:GetLeakPosition(idx)
	local boat_x, _, boat_z = self.inst.Transform:GetWorldPosition()

	local angle = GetRandomWithVariance(self:GetLeakAngle(idx), self.leak_angle_variance)
	local leakradius = GetRandomWithVariance(self.leak_radius, self.leak_radius_variance)
	local pos_x, pos_z = math.cos(angle) * leakradius, math.sin(angle) * leakradius
	return pos_x + boat_x, pos_z + boat_z
end

function HullHealth:GetLeakAngle(idx)
	return idx * math.pi * 2 / self.leak_point_count
end

function HullHealth:RefreshLeakIndicator(leak_idx)
	if self.leakproof then
		return false
	end
	local leak_damage = self.leak_damage[leak_idx]
	if leak_damage < self.small_leak_dmg then
		return false
	end

	local leak_indicator = self.leak_indicators[leak_idx]
	if not leak_indicator then
		leak_indicator = SpawnPrefab("boat_leak")
		local leak_x, leak_z = self:GetLeakPosition(leak_idx)
		leak_indicator.Transform:SetPosition(leak_x, 0, leak_z)
		leak_indicator.components.boatleak:SetBoat(self.inst)

		self.leak_indicators[leak_idx] = leak_indicator
	end

	leak_indicator.components.boatleak:SetState((leak_damage >= self.med_leak_dmg and "med_leak") or "small_leak")
	return true
end

local THROAWAY_ALIGNMENT_VALUE = 0.258 -- math.cos(75 degrees)
function HullHealth:OnCollide(data)
	local boat_x, _, boat_z = self.inst.Transform:GetWorldPosition()
	local hit_pos_x, hit_pos_z = data.world_position_on_a_x, data.world_position_on_a_z
	local boat_to_hit_x, boat_to_hit_z = VecUtil_Normalize(hit_pos_x - boat_x, hit_pos_z - boat_z)
	local hit_angle = VecUtil_GetAngleInRads(boat_to_hit_x, boat_to_hit_z)

	local delta_angle = TWOPI
	local leak_idx = 1
	for possible_leak_idx = 1,6 do
		local leak_angle = self:GetLeakAngle(possible_leak_idx)
		local leak_delta_angle = math.abs(leak_angle - hit_angle)
		if leak_delta_angle > PI then
			leak_delta_angle = TWOPI - leak_delta_angle
		end

		if leak_delta_angle < delta_angle then
			leak_idx = possible_leak_idx
			delta_angle = leak_delta_angle
		end
	end

    local absolute_hit_normal_overlap_percentage = math.abs(data.hit_dot_velocity)

	local damage_alignment = absolute_hit_normal_overlap_percentage/(data.speed_damage_factor or 1)

    -- This functionally throws away every collision where the hit normal is
	-- about 60 degrees away from our velocity normal. Helps give the 'grazing' effect.
	if damage_alignment > THROAWAY_ALIGNMENT_VALUE then
        local hit_adjacent_speed = self.inst.components.boatphysics:GetVelocity() * absolute_hit_normal_overlap_percentage

		-- If an area was hit with a boat bumper, have it eat the collision damage and skip processing boat hull damage
		if hit_adjacent_speed > TUNING.BOAT.OARS.MALBATROSS.FORCE and self.inst.components.boatring then
			local collidedbumper = self.inst.components.boatring:GetBumperAtPoint(hit_pos_x, hit_pos_z)
			if collidedbumper then
				local velocity_damage_percent = math.min(hit_adjacent_speed / TUNING.BOAT.MAX_ALLOWED_VELOCITY, 1)
				collidedbumper:PushEvent("boatcollision")

				local damage = TUNING.BOAT.MAX_HULL_HEALTH_DAMAGE * velocity_damage_percent
				collidedbumper.components.health:DoDelta(-1 * math.floor(damage))
				return
			end
		end

		if hit_adjacent_speed > 2 then
			local leak_dmg = self.leak_damage[leak_idx]

			if leak_dmg < 1 then
				local damage_applied = math.min(hit_adjacent_speed - 2, 1 - leak_dmg)
				leak_dmg = leak_dmg + damage_applied
				self.leak_damage[leak_idx] = leak_dmg
			end

			if self:RefreshLeakIndicator(leak_idx) and self.inst.components.walkableplatform then
	            for player_on_platform in pairs(self.inst.components.walkableplatform:GetPlayersOnPlatform()) do
	                player_on_platform:PushEvent("on_standing_on_new_leak")
	            end
			end
		end

        if hit_adjacent_speed > TUNING.BOAT.OARS.MALBATROSS.FORCE then
            local velocity_damage_percent = math.min(hit_adjacent_speed / TUNING.BOAT.MAX_ALLOWED_VELOCITY, 1)

            velocity_damage_percent = velocity_damage_percent * self:GetDamageMult("collide")

			local damage = TUNING.BOAT.MAX_HULL_HEALTH_DAMAGE * velocity_damage_percent
		    self.inst.components.health:DoDelta(-1 * math.floor(damage))
        end
	end
end

function HullHealth:SetSelfDegrading(stat)
	self.selfdegradingtime = stat
	if 	self.selfdegradingtime > 0 then
		self.inst:StartUpdatingComponent(self)
	else
		self.inst:RemoveTag("is_leaking")
		self.inst:StopUpdatingComponent(self)
	end
end

function HullHealth:SpawnDegadeDebris()
	if not self.degradefx then
		return
	end

	local fx = SpawnPrefab(self.degradefx)
	local x,y,z = self.inst.Transform:GetWorldPosition()
	local radius = math.random() * 3
	local theta = math.random() * TWOPI
	local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
	fx.Transform:SetPosition(x+offset.x,0,z+offset.z)
end

function HullHealth:OnUpdate(dt)
	self.inst:AddTag("is_leaking")

	self.currentdegradetime = self.currentdegradetime + dt

	local degrade_damage_multiplier = self:GetDamageMult("degradedamage")
	if self.degradefx then
		local debris_chance = (1/30) / degrade_damage_multiplier
		if math.random() < debris_chance then
			self:SpawnDegadeDebris()
		end
	end

	if self.currentdegradetime >= self.selfdegradingtime * degrade_damage_multiplier then
		self.currentdegradetime = 0
		self.inst.components.health:DoDelta(-1)
	end
end

function HullHealth:OnSave()
    local leaks = {}
    for leak_point, leak in pairs(self.leak_indicators) do
        if leak and leak:IsValid() then
            table.insert(leaks, {
                leak_point = leak_point,
                leak_damage = self.leak_damage[leak_point],
                leak_state = leak.components.boatleak.current_state,
            })
        end
    end

    return (#leaks > 0 and { boat_leaks = leaks }) or nil
end

function HullHealth:LoadPostPass(newents, data)
	if not data then return end

    if data.boat_leaks then
        for _, leak_data in ipairs(data.boat_leaks) do
            self.leak_damage[leak_data.leak_point] = leak_data.leak_damage
            if self:RefreshLeakIndicator(leak_data.leak_point) then
                local leak_indicator = self.leak_indicators[leak_data.leak_point]
                leak_indicator.components.boatleak:SetState(leak_data.leak_state)
            end
        end
    end
end

return HullHealth
