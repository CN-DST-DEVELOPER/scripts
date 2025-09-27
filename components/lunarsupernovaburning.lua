local WagBossUtil = require("prefabs/wagboss_util")

local LunarSupernovaBurning = Class(function(self, inst)
	self.inst = inst
	self.sources = {}
	self.firsttick = true
	self.wasdamaging = false
	self.inst:StartUpdatingComponent(self)
end)

function LunarSupernovaBurning:OnRemoveFromEntity()
	if self.inst.components.health then
		self.inst.components.health:UnregisterLunarBurnSource("lunarsupernovaburning")
	end
	if self.inst.components.colouradder then
		self.inst.components.colouradder:PopColour("lunarsupernovaburning")
	end
	for k, v in pairs(self.sources) do
		v:Remove()
	end
end

function LunarSupernovaBurning:GetFxSize()
	local sizeent = self.inst.components.rider and self.inst.components.rider:GetMount() or self.inst
	local physrad = sizeent:GetPhysicsRadius(0)
	if physrad >= 1.5 or sizeent:HasTag("epic") then
		return "large", math.max(1.5, physrad)
	elseif physrad >= 0.9 or sizeent:HasTag("largecreature") then
		return "med", math.max(1, physrad)
	else
		return "small", math.max(0.5, physrad)
	end
end

function LunarSupernovaBurning:AddSource(source)
	if self.sources[source] then
		return
	end
	local firstsource = next(self.sources) == nil
	local fx = SpawnPrefab("alterguardian_lunar_supernova_burn_fx")
	local size, rad = self:GetFxSize()
	fx:SetFxSize(size)
	self.sources[source] = fx
	if firstsource then
		self:OnUpdate(0)
	else
		fx:Hide()
	end
end

function LunarSupernovaBurning:OnUpdate(dt)
	local x, _, z = self.inst.Transform:GetWorldPosition()
	local map = TheWorld.Map
	local inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z)
	local blockers
	local numdots = 0
	local size, rad = self:GetFxSize()
	for k, v in pairs(self.sources) do
		if not (k:IsValid() and (k.sg and k.sg:HasStateTag("supernovaburning"))) then
			v:Remove()
			self.sources[k] = nil
		else
			local x1, _, z1 = k.Transform:GetWorldPosition()
			if inarena and not map:IsPointInWagPunkArena(x1, 0, z1) then
				v:Remove()
				self.sources[k] = nil
			elseif not inarena and distsq(x, z, x1, z1) > WagBossUtil.SupernovaNoArenaRangeSq then
				--NOTE: >, not >=, since we're just going with FindEntities range
				v:Remove()
				self.sources[k] = nil
			else
				if blockers == nil then
					blockers = WagBossUtil.FindSupernovaBlockersNearXZ(x, z)
				end
				local x1, _, z1 = k.Transform:GetWorldPosition()
				if WagBossUtil.IsSupernovaBlockedAtXZ(x1, z1, x, z, blockers) then
					v:Hide()
				else
					numdots = numdots + 1
					v:SetFxSize(size)
					v:Show()
					local dx = x1 - x
					local dz = z1 - z
					if dx == 0 and dz == 0 then
						v.Transform:SetPosition(x, 0, z)
					else
						local len = math.sqrt(dx * dx + dz * dz)
						len = rad / len
						v.Transform:SetPosition(x + dx * len, 0, z + dz * len)
					end
				end
			end
		end
	end
	if next(self.sources) == nil then
		self.inst:RemoveComponent("lunarsupernovaburning")
		return
	end

	if self.inst:IsInLimbo() or
		self.inst:HasTag("notarget") or
		(self.inst.sg and self.inst.sg:HasAnyStateTag("flight", "invisible", "noattack")) or
		self.inst.components.health == nil or
		self.inst.components.health:IsDead() or
		(self.inst.components.combat and not self.inst.components.combat:CanBeAttacked())
	then
		self.inst:RemoveComponent("lunarsupernovaburning")
		return
	end

	if numdots > 0 then
		if not self.wasdamaging or self.firsttick then
			self.wasdamaging = true
			self.firsttick = nil
			local mount = self.inst.components.rider and self.inst.components.rider:GetMount() or nil
			if mount and mount.components.health and not mount.components.health:IsDead() then
				local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.ALTERGUARDIAN_LUNAR_SUPERNOVA_LUNAR_BURN_DPS)
				mount.components.health:DoDelta(-dmg * numdots, false, "alterguardian_phase4_lunarrift")
			end
			local dmg = WagBossUtil.CalcLunarBurnTickDamage(self.inst, TUNING.ALTERGUARDIAN_LUNAR_SUPERNOVA_LUNAR_BURN_DPS)
			self.inst.components.health:DoDelta(-dmg * numdots, false, "alterguardian_phase4_lunarrift")
			self.inst.components.health.lastlunarburnpulsetick = GetTick()
			self.inst.components.health:RegisterLunarBurnSource("lunarsupernovaburning", bit.bor(WagBossUtil.LunarBurnFlags.NEAR_SUPERNOVA, WagBossUtil.LunarBurnFlags.SUPERNOVA))
			if self.inst.components.colouradder == nil then
				self.inst:AddComponent("colouradder")
			end
			self.inst.components.colouradder:PushColour("lunarsupernovaburning", 0.2, 0.2, 0.2, 0)
		else
			local tick = GetTick()
			local pulse = tick >= self.inst.components.health.lastlunarburnpulsetick + 12
			if pulse then
				self.inst.components.health.lastlunarburnpulsetick = tick
			end
			local mount = self.inst.components.rider and self.inst.components.rider:GetMount() or nil
			if mount and mount.components.health and not mount.components.health:IsDead() then
				local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.ALTERGUARDIAN_LUNAR_SUPERNOVA_LUNAR_BURN_DPS)
				mount.components.health:DoDelta(-dmg * numdots, not pulse, "alterguardian_phase4_lunarrift")
			end
			local dmg = WagBossUtil.CalcLunarBurnTickDamage(self.inst, TUNING.ALTERGUARDIAN_LUNAR_SUPERNOVA_LUNAR_BURN_DPS)
			self.inst.components.health:DoDelta(-dmg * numdots, not pulse, "alterguardian_phase4_lunarrift")
		end
		if self.inst.components.grogginess and not (self.inst.components.health and self.inst.components.health:IsDead()) then
			self.inst.components.grogginess:MaximizeGrogginess()
		end
	elseif self.wasdamaging or self.firsttick then
		if self.wasdamaging then
			self.wasdamaging = false
			self.inst.components.colouradder:PopColour("lunarsupernovaburning")
		end
		self.firsttick = nil
		self.inst.components.health:RegisterLunarBurnSource("lunarsupernovaburning", WagBossUtil.LunarBurnFlags.NEAR_SUPERNOVA)
	end
end

return LunarSupernovaBurning
