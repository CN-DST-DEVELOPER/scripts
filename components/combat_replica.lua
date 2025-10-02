local Combat = Class(function(self, inst)
    self.inst = inst

    self._target = net_entity(inst.GUID, "combat._target")
    self._ispanic = net_bool(inst.GUID, "combat._ispanic")
    self._attackrange = net_float(inst.GUID, "combat._attackrange")
    self._laststartattacktime = nil

    if TheWorld.ismastersim then
        self.classified = inst.player_classified
		--self.temp_iframes_keep_aggro = nil --for targets that have i-frames, but don't want to deaggro
    elseif self.classified == nil and inst.player_classified ~= nil then
        self:AttachClassified(inst.player_classified)
    end
end)

--------------------------------------------------------------------------

--V2C: OnRemoveFromEntity not supported
--[[function Combat:OnRemoveFromEntity()
    if self.classified ~= nil then
        if TheWorld.ismastersim then
            self.classified = nil
        else
            self.inst:RemoveEventCallback("onremove", self.ondetachclassified, self.classified)
            self:DetachClassified()
        end
    end
end

Combat.OnRemoveEntity = Combat.OnRemoveFromEntity]]

function Combat:AttachClassified(classified)
    self.classified = classified
    self.ondetachclassified = function() self:DetachClassified() end
    self.inst:ListenForEvent("onremove", self.ondetachclassified, classified)
    self._laststartattacktime = nil
end

function Combat:DetachClassified()
    self.classified = nil
    self.ondetachclassified = nil
    self._laststartattacktime = nil
end

--------------------------------------------------------------------------

function Combat:SetTarget(target)
    self._target:set(target)
end

function Combat:GetTarget()
    return self._target:value()
end

function Combat:SetLastTarget(target)
    if self.classified ~= nil then
        self.classified.lastcombattarget:set(target)
    end
end

function Combat:IsRecentTarget(target)
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:IsRecentTarget(target)
    elseif target == nil then
        return false
    elseif self.classified ~= nil and target == self.classified.lastcombattarget:value() then
        return true
    else
        return target == self._target:value()
    end
end

function Combat:SetIsPanic(ispanic)
    self._ispanic:set(ispanic)
end

function Combat:SetAttackRange(attackrange)
    self._attackrange:set(attackrange)
end

function Combat:GetAttackRangeWithWeapon()
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:GetAttackRange()
    end
    local weapon = self:GetWeapon()
    return weapon ~= nil
        and math.max(0, self._attackrange:value() + weapon.replica.inventoryitem:AttackRange())
        or self._attackrange:value()
end

function Combat:GetWeapon()
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:GetWeapon()
    elseif self.inst.replica.inventory ~= nil then
        local item = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if item ~= nil and item:HasTag("weapon") then
			if (item:HasTag("projectile") and not item:HasTag("complexprojectile")) or
				item:HasTag("rangedweapon")
			then
                return item
            end
            local rider = self.inst.replica.rider
            return not (rider ~= nil and rider:IsRiding()) and item or nil
        end
    end
end

function Combat:SetMinAttackPeriod(minattackperiod)
    if self.classified ~= nil then
        self.classified.minattackperiod:set(minattackperiod)
    end
end

function Combat:MinAttackPeriod()
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat.min_attack_period
    elseif self.classified ~= nil then
        return self.classified.minattackperiod:value()
    else
        return 0
    end
end

function Combat:SetCanAttack(canattack)
    if self.classified ~= nil then
        self.classified.canattack:set(canattack)
    end
end

function Combat:StartAttack()
    if self.inst.components.combat ~= nil then
        self.inst.components.combat:StartAttack()
    elseif self.classified ~= nil then
        self._laststartattacktime = GetTime()
    end
end

function Combat:CancelAttack()
    if self.inst.components.combat ~= nil then
        self.inst.components.combat:CancelAttack()
    elseif self.classified ~= nil then
        self._laststartattacktime = nil
    end
end

function Combat:InCooldown()
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:InCooldown()
    elseif self.classified ~= nil then
        return self._laststartattacktime ~= nil and self._laststartattacktime + self.classified.minattackperiod:value() > GetTime()
    end
    return false
end

function Combat:CanAttack(target)
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:CanAttack(target)
    elseif self.classified ~= nil then
        if not self:IsValidTarget(target) then
            return false, true
        elseif not self.classified.canattack:value()
            or self:InCooldown()
            or (self.inst.sg ~= nil and
                self.inst.sg:HasStateTag("busy") or
                self.inst:HasTag("busy"))
            then
            -- V2C: client can't check "hit" state tag, but players don't need that anyway
            return false
        end

        --account for position error (-.5) due to prediction
        local range = math.max(0, target:GetPhysicsRadius(0) + self:GetAttackRangeWithWeapon() - .5)

        -- V2C: this is 3D distsq
        --      client does not support ignorehitrange for players
        return distsq(target:GetPosition(), self.inst:GetPosition()) <= range * range
    else
        return false
    end
end

function Combat:LocomotorCanAttack(reached_dest, target)
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:LocomotorCanAttack(reached_dest, target)
    elseif self.classified ~= nil then
        if not self:IsValidTarget(target) then
            return false, true, false
        end

        local range = math.max(0, target:GetPhysicsRadius(0) + self:GetAttackRangeWithWeapon() - .5)
        reached_dest = reached_dest or distsq(target:GetPosition(), self.inst:GetPosition()) <= range * range

        local valid = self.classified.canattack:value()
            and (   self.inst.sg == nil or
                    not self.inst.sg:HasStateTag("busy") or
                    self.inst.sg:HasStateTag("hit")
                )

		if range > 2 and self.inst.isplayer then
            local weapon = self:GetWeapon()
			local is_ranged_weapon = weapon ~= nil and weapon:HasAnyTag("projectile", "rangedweapon")

            if not is_ranged_weapon then
                local currentpos = self.inst:GetPosition()
                local voidtest = currentpos + ((target:GetPosition() - currentpos):Normalize() * (self:GetAttackRangeWithWeapon() / 2))
                if TheWorld.Map:IsNotValidGroundAtPoint(voidtest:Get()) and not TheWorld.Map:IsNotValidGroundAtPoint(target.Transform:GetWorldPosition()) then
                    reached_dest = false
                end
            end
        end

        return reached_dest, not valid, self:InCooldown()
    else
        return reached_dest, true, false
    end
end

function Combat:CanExtinguishTarget(target, weapon)
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:CanExtinguishTarget(target, weapon)
    end
    return (weapon ~= nil and weapon:HasTag("extinguisher") or self.inst:HasTag("extinguisher"))
		and (target:HasAnyTag("smolder", "fire"))
end

function Combat:CanLightTarget(target, weapon)
    --[[if self.inst.components.combat ~= nil then
        return self.inst.components.combat:CanLightTarget(target, weapon)
    elseif weapon == nil or
        not (weapon:HasTag("rangedlighter") and
            target:HasTag("canlight")) or
        target:HasTag("burnt") then
        return false
    elseif target:HasTag(FUELTYPE.BURNABLE.."_fueled") then
        return true
    end
    --Either it takes burnable fuel, or it's not fueled at all
    --(USAGE doesn't count as fueled)
    for k, v in pairs(FUELTYPE) do
        if v ~= FUELTYPE.USAGE and v ~= FUELTYPE.BURNABLE and target:HasTag(v.."_fueled") then
            return false
        end
    end
    --Generic burnable
    return true
    ]]
    --V2C: fueled or fueltype should not really matter. if we can burn it, should still allow lighting.
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:CanLightTarget(target, weapon)
    end
    return weapon ~= nil
        and weapon:HasTag("rangedlighter")
        and target:HasTag("canlight")
		and not target:HasAnyTag("fire", "burnt")
end

function Combat:CanHitTarget(target)
    if self.inst.components.combat ~= nil then
        return self.inst.components.combat:CanHitTarget(target)
    elseif self.classified ~= nil
        and target ~= nil
        and target:IsValid()
        and not target:HasTag("INLIMBO") then

        local weapon = self:GetWeapon()
        if self:CanExtinguishTarget(target, weapon) or
            self:CanLightTarget(target, weapon) or
            (target.replica.combat ~= nil and target.replica.combat:CanBeAttacked(self.inst)) then

            local range = target:GetPhysicsRadius(0) + self:GetAttackRangeWithWeapon()
            local error_threshold = .5
            --account for position error due to prediction
            range = math.max(range - error_threshold, 0)

            -- V2C: this is 3D distsq
            return distsq(target:GetPosition(), self.inst:GetPosition()) <= range * range
        end
    end
    return false
end

function Combat:IsValidTarget(target)
    if target == nil or
        target == self.inst or
        not (target.entity:IsValid() and target.entity:IsVisible()) then
        return false
    end

    local weapon = self:GetWeapon()
    return self:CanExtinguishTarget(target, weapon)
        or self:CanLightTarget(target, weapon)
        or (target.replica.combat ~= nil and
            not IsEntityDead(target, true) and
            not target:HasTag("spawnprotection") and
            not (target:HasTag("shadow") and self.inst.replica.sanity == nil and not self.inst:HasTag("crazy")) and
            not (target:HasTag("playerghost") and (self.inst.replica.sanity == nil or self.inst.replica.sanity:IsSane()) and not self.inst:HasTag("crazy")) and
			(TheNet:GetPVPEnabled() or not (self.inst.isplayer and target.isplayer) or (weapon and weapon:HasTag("propweapon"))) and
            target:GetPosition().y <= self._attackrange:value())
end

function Combat:CanTarget(target)
    local rider = self.inst.replica.rider
    local weapon = self:GetWeapon()
	local is_ranged_weapon = weapon ~= nil and weapon:HasAnyTag("projectile", "rangedweapon")

    return self:IsValidTarget(target)
		and not (	self._ispanic:value() or
					target:HasAnyTag("INLIMBO", "notarget", "debugnoattack")
				)
		and (self.temp_iframes_keep_aggro or not target:HasTag("invisible"))
        and (target.replica.combat == nil
            or target.replica.combat:CanBeAttacked(self.inst))
        and (rider == nil or (not rider:IsRiding() or (not rider:GetMount():HasTag("peacefulmount") or is_ranged_weapon)))
end

function Combat:IsAlly(guy)
    if guy == self.inst or
        (self.inst.replica.follower ~= nil and guy == self.inst.replica.follower:GetLeader()) then
        --It's me! or it's my leader
        return true
    end

    local follower = guy.replica.follower
    local leader = follower ~= nil and follower:GetLeader() or nil
    --It's my follower
    --or I'm a player and it's a companion (or following another player in non PVP)
    --unless it's attacking me
    return self.inst == leader
		or (    self.inst.isplayer and
                (   guy:HasTag("companion") or
                    (   leader ~= nil and
                        not TheNet:GetPVPEnabled() and
						leader.isplayer
                    )
                ) and
                (   guy.replica.combat == nil or
                    guy.replica.combat:GetTarget() ~= self.inst
                )
            )
end

function Combat:TargetHasFriendlyLeader(target)
    local leader = self.inst.replica.follower ~= nil and self.inst.replica.follower:GetLeader()
    if leader ~= nil then
        local target_leader = target.replica.follower ~= nil and target.replica.follower:GetLeader() or nil

        if target_leader and target_leader.replica.inventoryitem then
            target_leader = target_leader.entity:GetParent() --.replica.inventoryitem:GetGrandOwner()
            -- Don't attack followers if their follow object has no owner
            if target_leader == nil then
                return true
            end
        end

        local PVP_enabled = TheNet:GetPVPEnabled()

        return leader == target
				or (target_leader ~= nil and (target_leader == leader or (target_leader.isplayer and not PVP_enabled)))
				or (target:HasTag("domesticated") and not PVP_enabled)
    end

    return false
end


function Combat:CanBeAttacked(attacker)
	if self.inst:HasAnyTag("playerghost", "flight") or
		(	not self.temp_iframes_keep_aggro and
			self.inst:HasAnyTag("noattack", "invisible")
		)
	then
        --Can't be attacked by anyone
        return false
	end

	local sanity

	if attacker ~= nil then
        --Attacker checks
		if attacker.isplayer and self.inst:HasTag("noplayertarget") then
            --Can't be attacked by players
            return false
        elseif attacker ~= self.inst and self.inst.isplayer then
            --Player target check
			if attacker.isplayer and not TheNet:GetPVPEnabled() then
                --PVP check
                local combat = attacker.replica.combat
                local weapon = combat ~= nil and combat:GetWeapon() or nil
                if weapon == nil or not weapon:HasTag("propweapon") then
                    --Allow friendly fire with props
                    return false
                end
            end
            if self._target:value() ~= attacker then
                local follower = attacker.replica.follower
                if follower ~= nil then
                    local leader = follower:GetLeader()
                    if leader ~= nil and
                        leader ~= self._target:value() and
						leader.isplayer then
                        local combat = attacker.replica.combat
                        if combat ~= nil and combat:GetTarget() ~= self.inst then
                            --Follower check
                            return false
                        end
                    end
                end
            end
        end

		sanity = attacker.replica.sanity

        if sanity ~= nil and sanity:IsCrazy() or attacker:HasTag("crazy") then
            --Insane attacker can pretty much attack anything
            return true
        end
    end

	if self.inst:HasAnyTag("shadowcreature", "nightmarecreature") and
		(	self._target:value() == nil
			--[[or (--See if we're targeting someone else, and attacker isn't insane enough to help
				attacker ~= nil and
				sanity ~= nil and --set already in the above attacker ~= nil block
				self._target:value() ~= attacker and
				not (sanity:IsInsanityMode() and sanity:GetPercent() < .5)
				)]]
			--V2C: The above version is the correct design; we should never have
			--     allowed targeting invisible entities.
			--     TODO: Add/improve items for revealing shadow creatures so we
			--           can switch to that version.
			or (--See if we're targeting someone else, but not actually hostile to them
				attacker ~= nil and
				self._target:value() ~= attacker and
				(self.inst.HostileToPlayerTest ~= nil and not self.inst:HostileToPlayerTest(self._target:value()))
				)
		) and
        --Allow AOE damage on stationary shadows like Unseen Hands
        (attacker ~= nil or self.inst:HasTag("locomotor")) then
        --Not insane attacker cannot attack shadow creatures
		--(unless shadow creature is targeting attacker, or targeting
		-- someone else, and attacker is below 50% sanity to help out)
        return false
    end

    --Passed all checks, can be attacked by anyone
    return true
end

return Combat
