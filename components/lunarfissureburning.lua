local WagBossUtil = require("prefabs/wagboss_util")

local LunarFissureBurning = Class(function(self, inst)
	self.inst = inst
	self.cleartime = 0
	--self.fx = nil

	inst:StartUpdatingComponent(self)
	self:OnUpdate(0)
end)

function LunarFissureBurning:OnRemoveFromEntity()
	if self.cleartime == nil and self.inst.components.health then
		self.inst.components.health:UnregisterLunarBurnSource("lunarfissureburning")
	end
	if self.fx then
		self.fx:Remove()
	end
end

function LunarFissureBurning:SetFxEnabled(enable)
	if enable then
		local sizeent
		if self.fx == nil or self.fx._hidden then
			if self.fx == nil then
				self.fx = SpawnPrefab("alterguardian_lunar_fissure_burn_fx")
				self.fx.entity:SetParent(self.inst.entity)
			else--if self.fx._hidden then
				self.fx._hidden = false
				self.fx:Show()
			end

			sizeent = self.inst.components.rider and self.inst.components.rider:GetMount() or self.inst

			if self.inst.components.colouradder == nil then
				self.inst:AddComponent("colouradder")
			end
			self.inst.components.colouradder:PushColour(self.fx, 0.15, 0.15, 0.15, 0)
		elseif self.inst.components.rider then
			--if we can mount, our size may change
			sizeent = self.inst.components.rider:GetMount() or self.inst
		end
		if sizeent then
			local physrad = sizeent:GetPhysicsRadius(0)
			self.fx:SetFxSize(
				((physrad >= 1.5 or sizeent:HasTag("epic")) and "large") or
				((physrad >= 0.9 or sizeent:HasTag("largecreature")) and "med") or
				"small"
			)
		end
	elseif self.fx and not self.fx._hidden then
		self.fx._hidden = true
		self.fx:Hide()
		self.inst.components.colouradder:PopColour(self.fx)
	end
end

function LunarFissureBurning:OnUpdate(dt)
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local id = WagBossUtil.TileCoordsToId(TheWorld.Map:GetTileCoordsAtPoint(x, y, z))
	if WagBossUtil.HasFissure(id) and
		not (	self.inst:IsInLimbo() or
				self.inst:HasTag("notarget") or
				(self.inst.sg and self.inst.sg:HasAnyStateTag("flight", "invisible", "noattack")) or
				(self.inst.components.health and self.inst.components.health:IsDead()) or
				(self.inst.components.combat and not self.inst.components.combat:CanBeAttacked())
			)
	then
		if self.cleartime then
			self.cleartime = nil
			if self.inst.components.health then
				local mount = self.inst.components.rider and self.inst.components.rider:GetMount() or nil
				if mount and mount.components.health and not mount.components.health:IsDead() then
					local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.ALTERGUARDIAN_LUNAR_FISSURE_LUNAR_BURN_DPS)
					mount.components.health:DoDelta(-dmg, false, "alterguardian_phase4_lunarrift")
				end
				local dmg = WagBossUtil.CalcLunarBurnTickDamage(self.inst, TUNING.ALTERGUARDIAN_LUNAR_FISSURE_LUNAR_BURN_DPS)
				self.inst.components.health:DoDelta(-dmg, false, "alterguardian_phase4_lunarrift")
				self.inst.components.health.lastlunarburnpulsetick = GetTick()
				self.inst.components.health:RegisterLunarBurnSource("lunarfissureburning", WagBossUtil.LunarBurnFlags.GENERIC)
			end
		elseif self.inst.components.health then
			local tick = GetTick()
			local pulse = tick >= self.inst.components.health.lastlunarburnpulsetick + 12
			if pulse then
				self.inst.components.health.lastlunarburnpulsetick = tick
			end
			local mount = self.inst.components.rider and self.inst.components.rider:GetMount() or nil
			if mount and mount.components.health and not mount.components.health:IsDead() then
				local dmg = WagBossUtil.CalcLunarBurnTickDamage(mount, TUNING.ALTERGUARDIAN_LUNAR_FISSURE_LUNAR_BURN_DPS)
				mount.components.health:DoDelta(-dmg, not pulse, "alterguardian_phase4_lunarrift")
			end
			local dmg = WagBossUtil.CalcLunarBurnTickDamage(self.inst, TUNING.ALTERGUARDIAN_LUNAR_FISSURE_LUNAR_BURN_DPS)
			self.inst.components.health:DoDelta(-dmg, not pulse, "alterguardian_phase4_lunarrift")
		end
		if self.inst.components.grogginess and not (self.inst.components.health and self.inst.components.health:IsDead()) then
			self.inst.components.grogginess:MaximizeGrogginess()
		end
		self:SetFxEnabled(true)
	elseif self.cleartime == nil then
		self.cleartime = dt
		if self.inst.components.health then
			self.inst.components.health:UnregisterLunarBurnSource("lunarfissureburning")
		end
		self:SetFxEnabled(false)
	else
		self.cleartime = self.cleartime + dt
		if self.cleartime > 1 then
			self.inst:RemoveComponent("lunarfissureburning")
		end
	end
end

return LunarFissureBurning
