local FollowerMemory = Class(function(self, inst)
	self.inst = inst
	self.reuniterange = 40
	self.onreuniteleaderfn = nil
	self.onleaderlostfn = nil
	self.leaderid = nil
	self.leaderchar = nil
	self.watching = nil
	self.task = nil
end)

--------------------------------------------------------------------------
--Public

function FollowerMemory:SetReuniteRange(dist)
	self.reuniterange = dist
end

--It's up to the fn whether to actually set the leader or not.
--There is no assumption that the call must succeed or do anything at all.
function FollowerMemory:SetOnReuniteLeaderFn(fn)
	self.onreuniteleaderfn = fn
end

--Triggered when leader is lost during play, or on load.
--If leader was already lost when saving, then it will not trigger again on load.
function FollowerMemory:SetOnLeaderLostFn(fn)
	self.onleaderlostfn = fn
end

function FollowerMemory:RememberAndSetLeader(player)
	self:SetLeaderMem(player.userid, player.prefab)
	if self.inst.components.follower then
		self.inst.components.follower:SetLeader(player)
	elseif self.leaderid then
		self:StartWatchingForLeader()
	else
		self:StopWatchingForLeader()
	end
end

function FollowerMemory:RememberLeaderDetails(id, prefab)
	local leader = self.inst.components.follower and self.inst.components.follower:GetLeader()
	if leader == nil then
		self:SetLeaderMem(id, prefab)
		if self.leaderid then
			self:StartWatchingForLeader()
		else
			self:StopWatchingForLeader()
		end
	elseif leader.userid == id and leader.prefab == prefab then
		self:SetLeaderMem(id, prefab)
	end
end

function FollowerMemory:ForgetLeader()
	self:SetLeaderMem(nil)
	self:StopWatchingForLeader()
end

function FollowerMemory:HasRememberedLeader()
	return self.leaderid ~= nil
end

function FollowerMemory:IsRememberedLeader(target)
	return self.leaderid ~= nil and target.userid == self.leaderid and target.prefab == self.leaderchar
end

--V2C: Purposely not adding a GetRememberedLeader(), because that can be misleading
--     to people who don't understand that it can return nil when the leader is not
--     available on the shard.

--------------------------------------------------------------------------
--Everything below this should be internal

FollowerMemory.OnRemoveFromEntity = FollowerMemory.ForgetLeader

local function OnAttacked(inst, data)
	local attackerid = data and data.attacker and data.attacker.userid
	if attackerid then
		local self = inst.components.followermemory
		if attackerid == self.leaderid then
			self:ForgetLeader()
		end
	end
end

function FollowerMemory:SetLeaderMem(id, prefab)
	if id then
		if self.leaderid == nil then
			self.inst:ListenForEvent("attacked", OnAttacked)
		end
		self.leaderid = id
		self.leaderchar = prefab
	elseif self.leaderid then
		self.leaderid = nil
		self.leaderchar = nil
		self.inst:RemoveEventCallback("attacked", OnAttacked)
	end
end

local function CheckPlayer(inst, self, player)
	if player.prefab ~= self.leaderchar then
		self:ForgetLeader()
	elseif not player:IsValid() then
		self:StopTrackingPlayer()
	elseif self.onreuniteleaderfn and self.inst:IsNear(player, self.reuniterange) then
		self.onreuniteleaderfn(self.inst, player)
	end
end

function FollowerMemory:StartTrackingPlayer(player)
	if self.task then
		if self.task.player == player then
			return
		end
		self.task:Cancel()
	end
	self.task = self.inst:DoPeriodicTask(3, CheckPlayer, 0, self, player)
	self.task.player = player
end

function FollowerMemory:StopTrackingPlayer()
	if self.task then
		self.task:Cancel()
		self.task = nil
	end
end

function FollowerMemory:StartWatchingForLeader()
	if self.watching == nil then
		self.watching = function(_, player)
			if player.userid == self.leaderid then
				if player.prefab ~= self.leaderchar then
					self:ForgetLeader()
				elseif not self.inst:IsAsleep() then
					self:StartTrackingPlayer(player)
				end
			end
		end
		self.inst:ListenForEvent("ms_playerjoined", self.watching, TheWorld)
	end
	if not self.inst:IsAsleep() then
		self:OnEntityWake()
	end
end

function FollowerMemory:StopWatchingForLeader()
	if self.watching then
		self:StopTrackingPlayer()
		self.inst:RemoveEventCallback("ms_playerjoined", self.watching, TheWorld)
		self.watching = nil
	end
end

FollowerMemory.OnEntitySleep = FollowerMemory.StopTrackingPlayer

function FollowerMemory:OnEntityWake()
	if self.watching then
		for i, v in ipairs(AllPlayers) do
			if v.userid == self.leaderid then
				if v.prefab == self.leaderchar then
					self:StartTrackingPlayer(v)
				else
					self:ForgetLeader()
				end
				break
			end
		end
	end
end

--Called by follower component as well
function FollowerMemory:OnChangedLeader(leader)
	if leader then
		if leader.userid ~= self.leaderid or leader.prefab ~= self.leaderchar then
			self:SetLeaderMem(nil)
		end
		self:StopWatchingForLeader()
	elseif self.leaderid then
		if self.onleaderlostfn and (not POPULATING or self._loading_lost_leader) then
			self.onleaderlostfn(self.inst)
		end
		self:StartWatchingForLeader()
	else
		self:StopWatchingForLeader()
	end
end

function FollowerMemory:OnSave()
	return self.leaderid and
	{
		id = self.leaderid,
		char = self.leaderchar,
		--leader will be lost when we reload
		lost = self.inst.components.follower and self.inst.components.follower:GetLeader() ~= nil or nil,
	}
end

function FollowerMemory:OnLoad(data)--, ents)
	self:SetLeaderMem(data.id, data.char)

	self._loading_lost_leader = data.lost
	self:OnChangedLeader(self.inst.components.follower and self.inst.components.follower:GetLeader())
	self._loading_lost_leader = nil
end

function FollowerMemory:GetDebugString()
	return string.format("leaderid=%s leaderchar=%s", tostring(self.leaderid), tostring(self.leaderchar))
end

return FollowerMemory
