local CharlieArenaWatcher = Class(function(self, inst)
	self.inst = inst

    self.ismastersim = TheWorld.ismastersim

	if self.ismastersim then
		self.playersinarena = {} -- e.g. [player] = true
		self.OnUpdate = self.OnUpdate_Master
		self.OnRemoveEntity = self.OnRemoveEntity_Master
	else
		self.inarena = false -- local player
		self.OnUpdate = self.OnUpdate_Client
		self.OnRemoveEntity = self.OnRemoveEntity_Client
	end

	self.inst:StartUpdatingComponent(self)
end)

-- CharlieArenaWatcher.IsInArena doesn't exist because you should check for Map:IsPointInCharlieBossArena, this component just handles telling things to update with changearea event push and other changes

function CharlieArenaWatcher:OnRemoveEntity_Master()
	-- has to be a tick delay, otherwise IsPointInCharlieBossArena still returns true :(
	TheWorld:DoTaskInTime(0, function()
		for i, v in ipairs(AllPlayers) do
			if self.playersinarena[v] then
				v:PushEvent("changearea", v.components.areaaware and v.components.areaaware:GetCurrentArea())
				if not TheNet:IsDedicated() then
					TheWorld.Map:SetUndergroundFadeHeight(5) -- revert to caves falloff
				end
			end
		end
	end)
end

function CharlieArenaWatcher:OnRemoveEntity_Client()
	if ThePlayer and self.inarena then
		ThePlayer:PushEvent("changearea", ThePlayer.components.areaaware and ThePlayer.components.areaaware:GetCurrentArea())
	end
end

function CharlieArenaWatcher:OnUpdate_Master(dt)
	for i, v in ipairs(AllPlayers) do
		local x, y, z = v.Transform:GetWorldPosition()
		if TheWorld.Map:IsPointInCharlieBossArena(x, y, z) then
			if not self.playersinarena[v] then
				self.playersinarena[v] = true
				v:PushEvent("changearea") -- push same event as areaaware component since a lot of stuff listens for this event
				if not TheNet:IsDedicated() then
					TheWorld.Map:SetUndergroundFadeHeight(0.001) -- disable falloff
				end
			end
		elseif self.playersinarena[v] then
			self.playersinarena[v] = false
			v:PushEvent("changearea", v.components.areaaware and v.components.areaaware:GetCurrentArea())
			if not TheNet:IsDedicated() then
				self.inst.VFXEffect:ClearAllParticles(0)
				self.inst.VFXEffect:ClearAllParticles(1)
				self.inst.VFXEffect:ClearAllParticles(2)
				TheWorld.Map:SetUndergroundFadeHeight(5) -- revert to caves falloff
			end
		end
	end
end

function CharlieArenaWatcher:OnUpdate_Client(dt)
	if ThePlayer then
		local x, y, z = ThePlayer.Transform:GetWorldPosition()
		if TheWorld.Map:IsPointInCharlieBossArena(x, y, z) then
			if not self.inarena then
				self.inarena = true
				ThePlayer:PushEvent("changearea") -- push same event as areaaware component since a lot of stuff listens for this event
				TheWorld.Map:SetUndergroundFadeHeight(0.001) -- disable falloff
			end
		elseif self.inarena then
			self.inarena = false
			ThePlayer:PushEvent("changearea", ThePlayer.components.areaaware and ThePlayer.components.areaaware:GetCurrentArea())
			self.inst.VFXEffect:ClearAllParticles(0)
			self.inst.VFXEffect:ClearAllParticles(1)
			self.inst.VFXEffect:ClearAllParticles(2)
			TheWorld.Map:SetUndergroundFadeHeight(5) -- revert to caves falloff
		end
	end
end

return CharlieArenaWatcher
