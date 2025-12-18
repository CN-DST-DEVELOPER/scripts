local BathingPool = Class(function(self, inst)
	self.inst = inst
	self.maxoccupants = nil
	self.radius = nil
	self.occupants = {}

	self.onoccupantremoved = function(ent) self:RemoveOccupant(ent) end
	self.onoccupantnewstate = function(ent)
		if not self:CheckOccupant(ent) then
			self:RemoveOccupant(ent)
		end
	end
end)

function BathingPool:OnRemoveFromEntity()
	for i = 1, #self.occupants do
		local ent = self.occupants[i]
        self.occupants[i] = nil
		self.inst:RemoveEventCallback("onremove", self.onoccupantremoved, ent)
		self.inst:RemoveEventCallback("newstate", self.onoccupantnewstate, ent)
		ent:PushEventImmediate("ms_leavebathingpool", self.inst)
        if self.onstopbeingoccupiedby then
            self.onstopbeingoccupiedby(self.inst, ent)
        end
	end
end

--BathingPool.OnRemoveEntity = BathingPool.OnRemoveFromEntity

function BathingPool:SetRadius(r)
	self.radius = r
end

function BathingPool:GetRadius()
	return self.radius or self.inst:GetPhysicsRadius(0)
end

function BathingPool:SetMaxOccupants(max)
	self.maxoccupants = max
	if max then
		for i = max + 1, #self.occupants do
			local ent = self.occupants[i]
			self.occupants[i] = nil
			self.inst:RemoveEventCallback("onremove", self.onoccupantremoved, ent)
			self.inst:RemoveEventCallback("newstate", self.onoccupantnewstate, ent)
			ent:PushEventImmediate("ms_leavebathingpool", self.inst)
            if self.onstopbeingoccupiedby then
                self.onstopbeingoccupiedby(self.inst, ent)
            end
		end
	end
end

function BathingPool:SetOnStartBeingOccupiedBy(fn)
    self.onstartbeingoccupiedby = fn
end

function BathingPool:SetOnStopBeingOccupiedBy(fn)
    self.onstopbeingoccupiedby = fn
end

function BathingPool:IsOccupant(ent)
	for i = 1, #self.occupants do
		if ent == self.occupants[i] then
			return true
		end
	end
	return false
end

function BathingPool:AddOccupant(ent)
	if not self:IsOccupant(ent) then
		self.inst:ListenForEvent("onremove", self.onoccupantremoved, ent)
		self.inst:ListenForEvent("newstate", self.onoccupantnewstate, ent)
		self.occupants[#self.occupants + 1] = ent
        if self.onstartbeingoccupiedby then
            self.onstartbeingoccupiedby(self.inst, ent)
        end
	end
end

function BathingPool:RemoveOccupant(ent)
	for i = 1, #self.occupants do
		if ent == self.occupants[i] then
			self.inst:RemoveEventCallback("onremove", self.onoccupantremoved, ent)
			self.inst:RemoveEventCallback("newstate", self.onoccupantnewstate, ent)
			for i = i, #self.occupants do
				self.occupants[i] = self.occupants[i + 1]
			end
            if self.onstopbeingoccupiedby then
                self.onstopbeingoccupiedby(self.inst, ent)
            end
		end
	end
end

function BathingPool:ForEachOccupant(fn, ...)
	for i = #self.occupants, 1, -1 do
		if fn(self.inst, self.occupants[i], ...) then
			return
		end
	end
end

function BathingPool:CheckOccupant(ent)
	--Make sure this is set in stategraphs
	return ent.sg and ent.sg.statemem.occupying_bathingpool == self.inst
end

function BathingPool:CheckAvailableSpot(x, z, r)
	for i = 1, #self.occupants do
		local v = self.occupants[i]
		local range = r + v:GetPhysicsRadius(0)
		if v:GetDistanceSqToPoint(x, 0, z) < range * range then
			return false, v
		end
	end
	return true
end

function BathingPool:EnterPool(ent)
	if self.maxoccupants and #self.occupants >= self.maxoccupants then
		return false, "NOSPACE"
	end

	local x, y, z = self.inst.Transform:GetWorldPosition()
	local r = self:GetRadius()

	local entx, _, entz = ent.Transform:GetWorldPosition()
	local entr = ent:GetPhysicsRadius(0)

	local success = false
	local destx, destz
	local destr = math.max(0, r - entr)
	if destr > 0 then
		local angle = x == entx and z == entz and (ent.Transform:GetRotation() + 180) * DEGREES or math.atan2(z - entz, entx - x)
		destx = x + destr * math.cos(angle)
		destz = z - destr * math.sin(angle)
		local blocker
		success, blocker = self:CheckAvailableSpot(destx, destz, entr)
		if not success then
			local blockerx, _, blockerz = blocker.Transform:GetWorldPosition()
			--no hope if blocker was occupying the center already
			if x ~= blockerx or z ~= blockerz then
				local blocker1
				local blockerangle = math.atan2(z - blockerz, blockerx - x)
				local offsetmult = ReduceAngleRad(angle - blockerangle) > 0 and DEGREES or -DEGREES
				for offset = 5, 45, 5 do
					local angle1 = angle + offset * offsetmult
					destx = x + destr * math.cos(angle1)
					destz = z - destr * math.sin(angle1)
					success, blocker1 = self:CheckAvailableSpot(destx, destz, entr)
					if success or blocker1 ~= blocker then
						for offset = offset - 5, offset do
							angle1 = angle + offset * offsetmult
							destx = x + destr * math.cos(angle1)
							destz = z - destr * math.sin(angle1)
							success, blocker1 = self:CheckAvailableSpot(destx, destz, entr)
							if success or blocker1 ~= blocker then
								break
							end
						end
						break
					end
				end
			end
		end
	else
		destx, destz = x, z
		success = self:CheckAvailableSpot(destx, destz, entr)
	end

	if not success then
		return false, "NOSPACE"
	end

	ent:PushEventImmediate("ms_enterbathingpool", {
		target = self.inst,
		dest = Vector3(destx, y, destz),
	})

	if not self:CheckOccupant(ent) then
		return false
	end

	self:AddOccupant(ent)
	return true
end

function BathingPool:LeavePool(ent)
	if not self:IsOccupant(ent) then
		return false
	elseif not self:CheckOccupant(ent) then
		--shouldn't be here!
		if BRANCH == "dev" then
			assert(false)
		end
		self:RemoveOccupant(ent)
		return false
	end
	ent:PushEventImmediate("ms_leavebathingpool", self.inst)
	return not self:CheckOccupant(ent)
end

function BathingPool:GetDebugString()
	local str = self.maxoccupants and
		string.format("%d/%d occupants", #self.occupants, self.maxoccupants) or
		string.format("%d occupants", #self.occupants)
	--[[for i = 1, #self.occupants do
		str = string.format("%s\n  [%d]  %s", str, i, tostring(self.occupants[i]))
	end]]
	return str
end

return BathingPool
