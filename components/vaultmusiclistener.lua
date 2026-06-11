local function OnChangeArea(inst, data)
	local self = inst.components.vaultmusiclistener
	if not self:IsMusicPlaying() then
		if data and data.id and data.id:find("Vault_Vault") then
			self:StartVaultMusic()
		end
	elseif data and data.id then
		if data.id:find("Vault") ~= 1 then
			self:StopVaultMusic()
		end
	elseif not TheWorld.Map:IsPointInAnyVault(inst.Transform:GetWorldPosition()) then
		--no data.id means we're over void
		--make sure we're not still in vault b4 stopping (e.g. puzzle room void)
		self:StopVaultMusic()
	end
end

local function OnPillarGuardAggro(inst)
	local self = inst.components.vaultmusiclistener
	self.lastaggrotime = GetTime()
	if self.delay and self.level == nil then
		self.delay = 0
	end
end

local VaultMusicListener = Class(function(self, inst)
	self.inst = inst
	--self.delay = nil
	--self.level = nil
	--self.lastaggrotime = nil

	inst:ListenForEvent("changearea", OnChangeArea)
	inst:ListenForEvent("vault_pillar_guard_aggro", OnPillarGuardAggro)
end)

function VaultMusicListener:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("changearea", OnChangeArea)
	self.inst:RemoveEventCallback("vault_pillar_guard_aggro", OnPillarGuardAggro)
end

function VaultMusicListener:IsMusicPlaying()
	return self.delay ~= nil
end

function VaultMusicListener:StartVaultMusic()
	if self.delay == nil then
		self.delay = 3.5
		self.inst:StartUpdatingComponent(self)
		self:OnUpdate(0)
	end
end

function VaultMusicListener:StopVaultMusic()
	if self.delay then
		self.delay = nil
		self.level = nil
		self.inst:StopUpdatingComponent(self)
	end
end

function VaultMusicListener:OnUpdate(dt)
	if dt < self.delay then
		self.delay = self.delay - dt
	else
		local isaggro = false
		if self.lastaggrotime then
			if self.lastaggrotime + 1.5 > GetTime() then
				isaggro = true
			else
				self.lastaggrotime = nil
			end
		end

		local duration
		if isaggro then
			if self.level == nil then
				--transition thru silence first
				self.level = 2
				self.delay = 1
			else
				self.level = 3
				self.delay = 1
			end
		else
			if self.level == 3 then
				--transition thru silence first
				self.level = 2
				self.delay = 3
				duration = 5
			else
				self.level = nil
				self.delay = 1
				duration = 5
			end
		end

		self.inst:PushEvent("triggeredevent", { name = "vault", level = self.level, duration = duration })
	end
end

return VaultMusicListener
