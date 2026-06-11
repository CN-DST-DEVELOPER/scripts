local TrapFumaroleUtil = require("prefabs/trap_fumarole_util")

local TrapFumaroleBurning = Class(function(self, inst)
	self.inst = inst
	self.cleartime = 0
	self.ignitetime = 0
	self._lasttrap = nil
	self.lastfiredamagetime = GetTime()
	--self.fx = nil

	inst:StartUpdatingComponent(self)
	self:OnUpdate(0)
end)

function TrapFumaroleBurning:OnRemoveFromEntity()
	if self._lasttrap then
		self._lasttrap:ClearIgnitingEntity(self.inst)
	end
	if self.fx then
		self.fx:Remove()
	end
end

function TrapFumaroleBurning:SetFxEnabled(enable)
	if enable then
		if self.fx == nil or self.fx._hidden then
			if self.fx == nil then
				self.fx = SpawnPrefab("trap_fumarole_burn_fx")
				self.fx.entity:SetParent(self.inst.entity)
			else--if self.fx._hidden then
				self.fx._hidden = false
				self.fx:Show()
			end

			if self.inst.components.colouradder == nil then
				self.inst:AddComponent("colouradder")
			end
			self.inst.components.colouradder:PushColour(self.fx, 0.1, 0, 0, 0)
		end

		local sizeent = self.inst.components.rider and self.inst.components.rider:GetMount() or self.inst
		if sizeent then
			local r, sz, ht = GetCombatFxSize(sizeent)
			self.fx:SetFxSize((sz == "tiny") and "small" or sz)
		end
	elseif self.fx and not self.fx._hidden then
		self.fx._hidden = true
		self.fx:Hide()
		self.inst.components.colouradder:PopColour(self.fx)
	end
end

-- NOTES: (OMAR) We need to be slightly quicker than usual fire(.5), because we accumulate and we might end up taking just a teeny bit longer than .5 which is the fire timeout in the health component
local FIRE_DAMAGE_DT = 14 * FRAMES

function TrapFumaroleBurning:OnUpdate(dt)
	local x, y, z = self.inst.Transform:GetWorldPosition()

	local tx, ty = TrapFumaroleUtil.GetTrapCoordsAtPoint(x, 0, z)
	local id = TrapFumaroleUtil.TileCoordsToId(tx, ty)
	local trap = TrapFumaroleUtil.GetTrap(id)
	if trap and not trap:IsActiveTrap() then
		trap = nil
	end
	if trap ~= self._lasttrap and self._lasttrap ~= nil then
		self._lasttrap:ClearIgnitingEntity(self.inst)
	end

	if trap ~= nil and
		not (	self.inst:IsInLimbo() or
				self.inst:HasAnyTag("notarget", "flying") or
				(self.inst.sg and self.inst.sg:HasAnyStateTag("flight", "invisible", "noattack")) or
				(self.inst.components.health and self.inst.components.health:IsDead()) or
				(self.inst.components.combat and not self.inst.components.combat:CanBeAttacked())
			)
	then
		local ignitemult = TUNING.TRAP_FUMAROLE_IGNITE_MULTS[trap._temperaturerange]
		dt = dt * ignitemult
		self.cleartime = nil

		local enable_fx = true
		if (self.inst.components.cookable ~= nil)
			or (self.inst.components.propagator ~= nil and self.inst.components.propagator:AcceptsHeat())
		then
			if trap:CanIgniteEntity(self.inst) then
				self.ignitetime = self.ignitetime + dt
				trap:SetIgnitingEntity(self.inst)
			else
				enable_fx = false
			end
		end

		local time = GetTime()
		local firedamagedt = time - self.lastfiredamagetime
		if firedamagedt >= FIRE_DAMAGE_DT then
			self.lastfiredamagetime = time
			if self.inst.components.health ~= nil then
				local mount = self.inst.components.rider and self.inst.components.rider:GetMount() or nil
				if mount and mount.components.health and not mount.components.health:IsDead() then
					mount.components.health:DoFireDamage(TUNING.TRAP_FUMAROLE_DAMAGE * ignitemult * firedamagedt, trap)
				else
					self.inst.components.health:DoFireDamage(TUNING.TRAP_FUMAROLE_DAMAGE * ignitemult * firedamagedt, trap)
				end
			end
		end

		if self.ignitetime > TUNING.TRAP_FUMAROLE_IGNITE_TIME then
			if self.inst.components.cookable ~= nil then
				local stacked = self.inst.components.stackable ~= nil and self.inst.components.stackable:IsStack()
        		local ingredient = stacked and self.inst.components.stackable:Get() or self.inst

				local newitem = ingredient.components.cookable:Cook(trap)
				newitem.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
				if stacked and newitem.Physics ~= nil then
                    local angle = math.random() * TWOPI
                    local speed = math.random() * 2
                    newitem.Physics:SetVel(speed * math.cos(angle), GetRandomWithVariance(8, 4), speed * math.sin(angle))
                end

				SpawnPrefab("fumarole_cook_fx").entity:SetParent(newitem.entity)

				if trap.SoundEmitter ~= nil then
        		    trap.SoundEmitter:PlaySound("dontstarve/wilson/cook")
        		end
				ingredient:Remove()
				self.ignitetime = 0
			elseif self.inst.components.propagator ~= nil and self.inst.components.propagator:AcceptsHeat() then
				self.inst.components.propagator:AddHeat(TUNING.TRAP_FUMAROLE_PROPAGATOR_RATE)
			end
		end

		self._lasttrap = trap
		DoDeltaTemperatureToEntity(self.inst, TUNING.TRAP_FUMAROLE_TEMPERATURE_RATE * dt)
		self:SetFxEnabled(enable_fx and not (self.inst.components.burnable ~= nil and self.inst.components.burnable:IsBurning()))
	elseif self.cleartime == nil then
		self.cleartime = dt
		-- self.lastfiredamagetime = GetTime()
		self.ignitetime = math.max(0, self.ignitetime - dt)
		self:SetFxEnabled(false)
	else
		self.cleartime = self.cleartime + dt
		self.ignitetime = math.max(0, self.ignitetime - dt)
		if self.cleartime > 1 then
			self.inst:RemoveComponent("trapfumaroleburning")
		end
	end
end

function TrapFumaroleBurning:GetDebugString()
	return string.format("cleartime: %.2f, ignitetime: %.2f, lastfiredamagetime: %2.f", self.cleartime or 0, self.ignitetime, self.lastfiredamagetime)
end

return TrapFumaroleBurning