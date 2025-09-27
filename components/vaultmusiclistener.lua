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

local VaultMusicListener = Class(function(self, inst)
	self.inst = inst
	--self.delay = nil

	inst:ListenForEvent("changearea", OnChangeArea)
end)

function VaultMusicListener:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("changearea", OnChangeArea)
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
		self.inst:StopUpdatingComponent(self)
	end
end

function VaultMusicListener:OnUpdate(dt)
	if dt < self.delay then
		self.delay = self.delay - dt
	else
		self.delay = 1
		self.inst:PushEvent("triggeredevent", { name = "vault", duration = 5 })
	end
end

return VaultMusicListener
