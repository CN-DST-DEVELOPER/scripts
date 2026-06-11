--NOTE: This is a client side component. No server
--      logic should be driven off this component!

local AllDrones = {}
local NumGroups = 0

local NearGroups = {}
local NumNearGroups = 0

local function CanMouseThrough(inst)
	local self = inst.components.transparentondrones
	return true, self.a < 0.5
end

local TransparentOnDrones = Class(function(self, inst)
	self.inst = inst
	self.fadealpha = 0.1
	self.a = 1
	self.isnear = false
	self.fadedist = 5
	self.unfadedist = 8
	self.leaderid = nil

	inst.CanMouseThrough = CanMouseThrough
end)

function TransparentOnDrones:PushAlpha(a)
	self.inst.AnimState:OverrideMultColour(1, 1, 1, a)
	if self.inst.fx then
		self.inst.fx.AnimState:OverrideMultColour(1, 1, 1, a * 0.5)
	end
end

function TransparentOnDrones:ResetAlpha()
	self.inst.AnimState:OverrideMultColour()
	if self.inst.fx then
		self.inst.fx.AnimState:OverrideMultColour()
	end
end

function TransparentOnDrones:RegisterDrone(leaderid)
	local group = AllDrones[leaderid]
	if group then
		group[self] = true
	else
		group = { [self] = true }
		AllDrones[leaderid] = group
		NumGroups = NumGroups + 1
	end
	self.leaderid = leaderid
end

function TransparentOnDrones:UnregisterDrone()
	if self.leaderid then
		local group = AllDrones[self.leaderid]
		if group then
			self:SetIsNear(false)
			group[self] = nil
			if next(group) == nil then
				AllDrones[self.leaderid] = nil
				NumGroups = NumGroups - 1
				assert(NumGroups >= 0)
				assert(NearGroups[self.leaderid] == nil)
			end
		end
		self.leaderid = nil
	end
end

function TransparentOnDrones:SetIsNear(near)
	if self.leaderid and self.isnear ~= near then
		self.isnear = near
		if near then
			if NearGroups[self.leaderid] == nil then
				NearGroups[self.leaderid] = true
				NumNearGroups = NumNearGroups + 1
			end
		else
			for k in pairs(AllDrones[self.leaderid]) do
				if k.isnear then
					return
				end
			end
			NearGroups[self.leaderid] = nil
			NumNearGroups = NumNearGroups - 1
			assert(NumNearGroups >= 0)
		end
	end
end

function TransparentOnDrones:IsGroupNear()
	return self.leaderid and NearGroups[self.leaderid] or false
end

function TransparentOnDrones:OnRemoveFromEntity()
	self.inst.CanMouseThrough = nil
	self:ResetAlpha()
	self:UnregisterDrone()
end

TransparentOnDrones.OnRemoveEntity = TransparentOnDrones.UnregisterDrone

function TransparentOnDrones:OnEntitySleep()
	self.inst:StopUpdatingComponent(self)
	if self.a ~= 1 then
		self.a = 1
		self:ResetAlpha()
	end
	self:UnregisterDrone()
end

function TransparentOnDrones:OnEntityWake()
	local me = ThePlayer
	if not (me and me.userid == self.leaderid) then
		self.inst:StartUpdatingComponent(self)
	end
end

function TransparentOnDrones:IsNearMe(range)
	local me = ThePlayer
	if me then
		local x, _, z = self.inst.Transform:GetWorldPosition()
		range = range * range

		if me:GetDistanceSqToPoint(x, 0, z) < range then
			return true
		end

		local mygroup = AllDrones[me.userid]
		if mygroup then
			for k in pairs(mygroup) do
				if k.inst:GetDistanceSqToPoint(x, 0, z) < range then
					return true
				end
			end
		end
	end
	return false
end

function TransparentOnDrones:OnUpdate(dt)
	if self.leaderid == nil then
		local follower = self.inst.replica.follower
		local leader = follower and follower:GetLeader()
		local leaderid = leader and (leader.components.linkeditem and leader.components.linkeditem:GetOwnerUserID() or leader.userid)
		if leaderid == nil then
			return
		end

		self:RegisterDrone(leaderid)

		local me = ThePlayer
		if me and me.userid == leaderid then
			self:SetIsNear(true)
			self.inst:StopUpdatingComponent(self)
			return
		end
	end

	self:SetIsNear(NumGroups > 1 and self:IsNearMe(self.isnear and self.unfadedist or self.fadedist))

	if NumNearGroups > 1 and self:IsGroupNear() then
		if self.a > self.fadealpha then
			self.a = math.max(self.fadealpha, self.a - 3 * dt)
			self:PushAlpha(self.a)
		end
	elseif self.a < 1 then
		self.a = math.min(1, self.a + 3 * dt)
		if self.a < 1 then
			self:PushAlpha(self.a)
		else
			self:ResetAlpha()
		end
	end
end

return TransparentOnDrones
