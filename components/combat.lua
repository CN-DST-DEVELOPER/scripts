local SourceModifierList = require("util/sourcemodifierlist")
local SpDamageUtil = require("components/spdamageutil")

local function onattackrange(self, attackrange)
    self.inst.replica.combat:SetAttackRange(attackrange)
end

local function onminattackperiod(self, minattackperiod)
    self.inst.replica.combat:SetMinAttackPeriod(minattackperiod)
end

local function oncanattack(self, canattack)
    self.inst.replica.combat:SetCanAttack(canattack)
end

local function ontarget(self, target)
    self.inst.replica.combat:SetTarget(target)
end

local function onpanicthresh(self, panicthresh)
    self.inst.replica.combat:SetIsPanic(panicthresh ~= nil and self.inst.components.health ~= nil and panicthresh > self.inst.components.health:GetPercent())
end

local Combat = Class(function(self, inst)
    self.inst = inst

    self.nextbattlecrytime = nil
    self.battlecryenabled = true
    self.attackrange = 3
    self.hitrange = 3
    self.areahitrange = nil
    self.temprange = nil
	--self.areahitcheck = nil
    self.areahitdamagepercent = nil
    --self.areahitdisabled = nil
    self.defaultdamage = 0
    --
    --use nil for defaults
    --self.playerdamagepercent = 1 --modifier for NPC dmg on players, only works with NO WEAPON
    --self.pvp_damagemod = 1
    --self.damagemultiplier = 1
    --self.damagebonus = 0
    --self.ignorehitrange = false
    --self.noimpactsound = false
    --

    -- NOTES(JBK): Aggro system for combat to help make things untargetable temporarily.
    -- None of this is saved in a restart and should be instantiated as things go.
    -- shouldaggrofn returns if the owner of this combat component should target the passed in target.
    -- shouldavoidaggro is a table that holds entity references as keys in it for temporary combat no target.
    -- forbiddenaggrotags is an ipairs table that holds tag strings as values in it to avoid targeting.
    self.shouldaggrofn = nil
    self.shouldavoidaggro = nil
    self.forbiddenaggrotags = nil
	self.lastwasattackedbytargettime = 0
	--self.lastattacker = nil
	--self.lastattacktype = nil
	--self.laststimuli = nil

    --self.tough = false
	--self.workmultiplierfn = nil
	--self.shouldrecoilfn = nil

	self.externaldamagemultipliers = SourceModifierList(self.inst) -- damage dealt to others multiplier

	self.externaldamagetakenmultipliers = SourceModifierList(self.inst) -- my damage taken multiplier (post armour reduction)

    self.min_attack_period = 4
    self.onhitfn = nil
    self.onhitotherfn = nil
    self.laststartattacktime = 0
    self.lastwasattackedtime = 0
    self.keeptargetfn = nil
    self.keeptargettimeout = 0
    self.hiteffectsymbol = "marker"
    self.canattack = true
    self.lasttargetGUID = nil
    self.target = nil
    self.panic_thresh = nil
    self.forcefacing = true
    self.bonusdamagefn = nil
    --self.playerstunlock = PLAYERSTUNLOCK.ALWAYS --nil for default

	self.losetargetcallback = function() self:DropTarget() end
	self.transfertargetcallback = function(target, newtarget)
		if newtarget ~= nil and self:CanTarget(newtarget) then
			self:SetTarget(newtarget)
			if self.target == target and self.target ~= newtarget then
				self:DropTarget()
			end
		else
			self:DropTarget()
		end
	end

	inst:ListenForEvent("knockback", CommonHandlers.ResetHitRecoveryDelay)
end,
nil,
{
    attackrange = onattackrange,
    min_attack_period = onminattackperiod,
    canattack = oncanattack,
    target = ontarget,
    panic_thresh = onpanicthresh,
})

local AREA_EXCLUDE_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

function Combat:SetLastTarget(target)
    self.lasttargetGUID = target ~= nil and target:IsValid() and target.GUID or nil
    self.inst.replica.combat:SetLastTarget(target ~= nil and target:IsValid() and target or nil)
end

function Combat:SetAttackPeriod(period)
    self.min_attack_period = period
end

function Combat:TargetIs(target)
    return target ~= nil and self.target == target
end

function Combat:InCooldown()
    return self.laststartattacktime ~= nil and self.laststartattacktime + self.min_attack_period > GetTime()
end

function Combat:GetCooldown()
    return self.laststartattacktime ~= nil and math.max(0, self.min_attack_period - GetTime() + self.laststartattacktime) or 0
end

function Combat:ResetCooldown()
    self.laststartattacktime = nil
end

function Combat:RestartCooldown()
    self.laststartattacktime = GetTime()
end

function Combat:OverrideCooldown(cd)
	self.laststartattacktime = GetTime() - self.min_attack_period + cd
end

function Combat:SetRange(attack, hit)
    self.attackrange = attack
    self.hitrange = (hit or self.attackrange)
end

function Combat:SetPlayerStunlock(stunlock)
    self.playerstunlock = stunlock
end

function Combat:SetAreaDamage(range, percent, areahitcheck)
    self.areahitrange = range
	self.areahitcheck = areahitcheck
    if self.areahitrange then
        self.areahitdamagepercent = percent or 1
    else
        self.areahitdamagepercent = nil
    end
end

function Combat:EnableAreaDamage(enable)
    self.areahitdisabled = enable == false
end

local function OnBlankOutOver(inst, self)
    self.blanktask = nil
    self.canattack = true
end

function Combat:BlankOutAttacks(fortime)
    self.canattack = false

    if self.blanktask ~= nil then
        self.blanktask:Cancel()
    end
    self.blanktask = self.inst:DoTaskInTime(fortime, OnBlankOutOver, self)
end

local DEFAULT_SHARE_TARGET_MUST_TAGS = { "_combat" }
function Combat:ShareTarget(target, range, fn, maxnum, musttags)
    --NOTE: true param ignores my own forbidden tags when sharing someone else's aggro
    if not self:ShouldAggro(target, true) then
        return
    end
    if maxnum <= 0 then
        return
    end

    --print("Combat:ShareTarget", self.inst, target)

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, SpringCombatMod(range), musttags or DEFAULT_SHARE_TARGET_MUST_TAGS)

    local num_helpers = 0
    for i, v in ipairs(ents) do
        if v ~= self.inst
            and not (v.components.health ~= nil and
                    v.components.health:IsDead())
            and (fn == nil or fn(v))
            and v.components.combat:SuggestTarget(target) then

            --print("    share with", v)
            num_helpers = num_helpers + 1

            if num_helpers >= maxnum then
                return
            end
        end
    end
end

function Combat:SetDefaultDamage(damage)
    self.defaultdamage = damage
end

function Combat:SetOnHit(fn)
    self.onhitfn = fn
end

function Combat:SuggestTarget(target)
    if self.target == nil and target ~= nil then
        --print("Combat:SuggestTarget", self.inst, target)
        self:SetTarget(target)
        return true
    end
end

function Combat:SetKeepTargetFunction(fn)
    self.keeptargetfn = fn
end

local function dotryretarget(inst, self)
    self:TryRetarget()
end

function Combat:TryRetarget()
    if self.targetfn ~= nil
        and not (self.inst.components.health ~= nil and
                self.inst.components.health:IsDead())
        and not (self.inst.components.sleeper ~= nil and
                self.inst.components.sleeper:IsInDeepSleep()) then

        local newtarget, forcechange = self.targetfn(self.inst)
        if newtarget ~= nil and newtarget ~= self.target and not newtarget:HasTag("notarget") then

            if forcechange then
                self:SetTarget(newtarget)
			    self.lastwasattackedbytargettime = GetTime()
            elseif self.target ~= nil and self.target:HasTag("structure") and not newtarget:HasTag("structure") then
                self:SetTarget(newtarget)
			    self.lastwasattackedbytargettime = GetTime()
            else
                if self:SuggestTarget(newtarget) then
					self.lastwasattackedbytargettime = GetTime()
				end
            end
        end
    end
end

function Combat:SetRetargetFunction(period, fn)
    self.targetfn = fn
    self.retargetperiod = period

    if self.retargettask ~= nil then
        self.retargettask:Cancel()
        self.retargettask = nil
    end

	if period and fn and not self.inst:IsAsleep() then
        self.retargettask = self.inst:DoPeriodicTask(period, dotryretarget, period*math.random(), self)
    end
end

function Combat:OnEntitySleep()
    if self.retargettask ~= nil then
        self.retargettask:Cancel()
        self.retargettask = nil
    end
end

function Combat:OnEntityWake()
    if self.retargettask ~= nil then
        self.retargettask:Cancel()
        self.retargettask = nil
    end

    if self.retargetperiod ~= nil then
        self.retargettask = self.inst:DoPeriodicTask(self.retargetperiod, dotryretarget, self.retargetperiod*math.random(), self)
    end

    if self.target ~= nil and self.keeptargetfn ~= nil then
        self.inst:StartUpdatingComponent(self)
    end
end

function Combat:OnUpdate(dt)
    if self.target == nil then
        self.inst:StopUpdatingComponent(self)
        return
    end

    if self.keeptargetfn ~= nil then
        self.keeptargettimeout = self.keeptargettimeout - dt
        if self.keeptargettimeout < 0 then
            if self.inst:IsAsleep() then
                self.inst:StopUpdatingComponent(self)
                return
            end
            self.keeptargettimeout = 1

			local drop
			if not self.target:IsValid() or self.target:IsInLimbo() then
				drop = true
			else
				local iframeskeepaggro_combat = self.target.sg and self.target.sg:HasStateTag("iframeskeepaggro") and self.inst.replica.combat or nil --V2C: intentionally using replica on server
				if iframeskeepaggro_combat then
					iframeskeepaggro_combat.temp_iframes_keep_aggro = true
				end
				drop = not (self.target.components.combat and self.keeptargetfn(self.inst, self.target) and self.target.components.combat:CanBeAttacked(self.inst))
				if iframeskeepaggro_combat then
					iframeskeepaggro_combat.temp_iframes_keep_aggro = nil
				end
			end

			if drop then
                self.inst:PushEvent("losttarget")
                self:DropTarget()
            end
        end
    end
end

function Combat:IsRecentTarget(target)
    return target ~= nil and (target == self.target or target.GUID == self.lasttargetGUID)
end

function Combat:StartTrackingTarget(target)
    if target then
        self.inst:ListenForEvent("enterlimbo", self.losetargetcallback, target)
        self.inst:ListenForEvent("onremove", self.losetargetcallback, target)
		self.inst:ListenForEvent("transfercombattarget", self.transfertargetcallback, target)
    end
end

function Combat:StopTrackingTarget(target)
	self.inst:RemoveEventCallback("transfercombattarget", self.transfertargetcallback, target)
    self.inst:RemoveEventCallback("enterlimbo", self.losetargetcallback, target)
    self.inst:RemoveEventCallback("onremove", self.losetargetcallback, target)
end

function Combat:DropTarget(hasnexttarget)
    if self.target then
        self:SetLastTarget(self.target)
        self:StopTrackingTarget(self.target)
        self.inst:StopUpdatingComponent(self)
        local oldtarget = self.target
        self.target = nil
        if not hasnexttarget then
            self.inst:PushEvent("droppedtarget", {target=oldtarget})
        end
		self.lastwasattackedbytargettime = 0
    end
end

function Combat:EngageTarget(target)
    if target then
		if not (self.inst.components.follower and self.inst.components.follower.leader == target and self.inst.components.follower.leader.components.leader ~= nil and self.inst.components.follower.keepleaderonattacked) then
	        local oldtarget = self.target
			self.target = target
			self.inst:PushEvent("newcombattarget", {target=target, oldtarget=oldtarget})
			self:StartTrackingTarget(target)
			if self.keeptargetfn then
				self.inst:StartUpdatingComponent(self)
			end
			if self.inst.components.follower and self.inst.components.follower.leader == target and self.inst.components.follower.leader.components.leader then
				self.inst.components.follower.leader.components.leader:RemoveFollower(self.inst)
			end
		end
    end
end

function Combat:SetShouldAggroFn(fn)
    self.shouldaggrofn = fn
end

function Combat:SetShouldAvoidAggro(target)
    self.shouldavoidaggro = self.shouldavoidaggro or {}
    self.shouldavoidaggro[target] = (self.shouldavoidaggro[target] or 0) + 1
end

function Combat:RemoveShouldAvoidAggro(target)
    if self.shouldavoidaggro == nil then
        return
    end
    self.shouldavoidaggro[target] = (self.shouldavoidaggro[target] or 1) - 1
    if self.shouldavoidaggro[target] == 0 then
        self.shouldavoidaggro[target] = nil
    end
    if next(self.shouldavoidaggro) == nil then
        self.shouldavoidaggro = nil
    end
end

function Combat:ShouldAggro(target, ignore_forbidden)
    if target ~= nil and
        (self.shouldaggrofn == nil or self.shouldaggrofn(self.inst, target)) and
        (self.shouldavoidaggro == nil or not self.shouldavoidaggro[target]) and
        (target.components.combat == nil or target.components.combat.shouldavoidaggrofn == nil or target.components.combat.shouldavoidaggrofn(self.inst, target))
        then
        if not ignore_forbidden and self.forbiddenaggrotags ~= nil then
            for _, tag in ipairs(self.forbiddenaggrotags) do
                if target:HasTag(tag) then
                    return false
                end
            end
        end
		if target:HasTag("stealth") then
			return false
		end
		if target.components.health ~= nil and (target.components.health.minhealth or 0) > 0 and not target:HasTag("hostile") then
			target = target.components.follower ~= nil and target.components.follower:GetLeader() or target
			if not target.isplayer then
				--npc should not aggro on things that can't be killed (unless hostile!)
				return false
			end
		end
        return true
    end
    return false
end

function Combat:AddNoAggroTag(tag)
    self.forbiddenaggrotags = self.forbiddenaggrotags or {}
    table.insert(self.forbiddenaggrotags, tag)
end

function Combat:RemoveNoAggroTag(tag)
    if self.forbiddenaggrotags == nil then
        return
    end
    table.removearrayvalue(self.forbiddenaggrotags, tag)
    if self.forbiddenaggrotags[1] == nil then
        self.forbiddenaggrotags = nil
    end
end

function Combat:SetNoAggroTags(tags) -- Wants a table in an ipairs table format.
    self.forbiddenaggrotags = tags
end

function Combat:SetTarget(target)
    if target ~= self.target and
        (target == nil or (self:IsValidTarget(target) and self:ShouldAggro(target))) and
		not (target and target.isplayer and target.sg and target.sg:HasStateTag("hiding"))
	then
        self:DropTarget(target ~= nil)
        self:EngageTarget(target)
    end
end

function Combat:IsValidTarget(target)
    return self.inst.replica.combat:IsValidTarget(target)
end

function Combat:ValidateTarget()
    if self.target then
        if self:IsValidTarget(self.target) then
            return true
        else
            self:DropTarget()
        end
    end
end

function Combat:GetDebugString()
    local str = string.format("target:%s, damage:%d", tostring(self.target), self.defaultdamage or 0 )
    if self.target then
        local dist = math.sqrt(self.inst:GetDistanceSqToInst(self.target)) or 0
        local atkrange = math.sqrt(self:CalcAttackRangeSq()) or 0
        str = str .. string.format(" dist/range: %2.2f/%2.2f", dist, atkrange)
        if self:InCooldown() then
            str = str .. " IN COOLDOWN"
        end
    end
    if self.targetfn and self.retargetperiod then
        str = str.. " Retarget set"
    end
    str = str..string.format(", can attack:%s", tostring(self:CanAttack(self.target)))
    str = str..string.format(", can be attacked: %s", tostring(self:CanBeAttacked()))

    return str
end

function Combat:GetGiveUpString(target)
    return nil
end

function Combat:GiveUp()
    if self.inst.components.talker ~= nil then
        local str, strid = self:GetGiveUpString(self.target)
        if str ~= nil then
            if strid ~= nil then
                self.inst.components.talker:Chatter(str, strid)
            else
                self.inst.components.talker:Say(str)
            end
        end
    end

    self.inst:PushEvent("giveuptarget", { target = self.target })
    self:DropTarget()
end

function Combat:GetBattleCryString(target)
    return nil
end

function Combat:ResetBattleCryCooldown(t)
    self.nextbattlecrytime = (t or GetTime()) + (self.battlecryinterval or 5) + math.random() * 3
end

function Combat:BattleCry()
    if self.battlecryenabled then
        local t = GetTime()
        if self.nextbattlecrytime == nil or t > self.nextbattlecrytime then
            self:ResetBattleCryCooldown(t)
            if self.inst.components.talker ~= nil then
                local cry, strid, echotochatpriority = self:GetBattleCryString(self.target)
                if cry ~= nil then
                    if strid ~= nil then
                        self.inst.components.talker:Chatter(cry, strid, 2, nil, echotochatpriority)
                    else
                        self.inst.components.talker:Say(cry, 2)
                    end
                end
            elseif self.inst.sg.sg.states.taunt and not self.inst.sg:HasStateTag("busy") then
                self.inst.sg:GoToState("taunt")
            end
        end
    end
end

function Combat:SetHurtSound(sound)
    self.hurtsound = sound
end

function Combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
    if self.inst.components.health and self.inst.components.health:IsDead() then
        return true
    end
    self.lastwasattackedtime = GetTime()

    --print ("ATTACKED", self.inst, attacker, damage)
    --V2C: redirectdamagefn is currently only used by either mounting or parrying,
    --     but not both at the same time.  If we use it more, then it really needs
    --     to be refactored.
    local blocked = false
    local damageredirecttarget = self.redirectdamagefn ~= nil and self.redirectdamagefn(self.inst, attacker, damage, weapon, stimuli, spdamage) or nil
    local damageresolved = 0
	local original_damage = damage

    self.lastattacker = attacker

	--can add more attacktypes as needed
	--currently just "projectile" or nil, used for hit stun calculation
	if (damage or 0) > 0 and
		weapon and
		(	weapon.components.projectile or
			(weapon.components.weapon and weapon.components.weapon.projectile)
		)
	then
		self.lastattacktype = "projectile"
	else
		self.lastattacktype = nil
	end
	self.laststimuli = stimuli

    local recoil
    recoil, damage = self:ShouldRecoil(attacker, weapon, damage)

    if recoil then
        blocked = true
    end

    if self.inst.components.health ~= nil and damage ~= nil and damageredirecttarget == nil then
        if self.inst.components.attackdodger ~= nil and self.inst.components.attackdodger:CanDodge(attacker) then
            self.inst.components.attackdodger:Dodge(attacker)
            damage, spdamage = 0, nil
        end

		if self.inst.components.inventory and not self.inst.components.inventory.ignorecombat then
			if attacker ~= nil and attacker.components.planarentity ~= nil and not self.inst.components.inventory:EquipHasSpDefenseForType("planar") then
				attacker.components.planarentity:OnPlanarAttackUndefended(self.inst)
			end
			damage, spdamage = self.inst.components.inventory:ApplyDamage(damage, attacker, weapon, spdamage)
        end
		local damagetypemult = 1
		if self.inst.components.rideable ~= nil then
			local saddle = self.inst.components.rideable.saddle
			if saddle ~= nil then
                if saddle.components.saddler ~= nil then
                    damage, spdamage = saddle.components.saddler:ApplyDamage(damage, attacker, weapon, spdamage)
                end
			end
		end
		if self.inst.components.damagetyperesist ~= nil then
			damagetypemult = damagetypemult * self.inst.components.damagetyperesist:GetResist(attacker, weapon)
		end
		damage = damage * damagetypemult * self.externaldamagetakenmultipliers:Get()
		if (damage > 0 or spdamage ~= nil) and not self.inst.components.health:IsInvincible() then
			if damage > 0 then
				--Bonus damage only applies after unabsorbed damage gets through your armor
				if attacker ~= nil and attacker.components.combat ~= nil and attacker.components.combat.bonusdamagefn ~= nil then
					damage = damage + damagetypemult * (attacker.components.combat.bonusdamagefn(attacker, self.inst, damage, weapon) or 0)
				end
				--Planar entities dampen regular damage
				if self.inst.components.planarentity ~= nil then
					damage, spdamage = self.inst.components.planarentity:AbsorbDamage(damage, attacker, weapon, spdamage)
				end
            end
			--Special damage after bonus damage
			if spdamage ~= nil then
				spdamage = SpDamageUtil.ApplySpDefense(self.inst, spdamage)
				damage = damage + damagetypemult * SpDamageUtil.CalcTotalDamage(spdamage)
			end

            local cause = attacker == self.inst and weapon or attacker
            --V2C: guess we should try not to crash old mods that overwrote the health component
            damageresolved = self.inst.components.health:DoDelta(-damage, nil, cause ~= nil and (cause.nameoverride or cause.prefab) or "NIL", nil, cause)
            damageresolved = damageresolved ~= nil and -damageresolved or damage
            if self.inst.components.health:IsDead() then
                if attacker ~= nil then
                    attacker:PushEvent("killed", { victim = self.inst, attacker = attacker })
                end
                if self.onkilledbyother ~= nil then
                    self.onkilledbyother(self.inst, attacker)
                end
            end
        else
            blocked = true
        end
    end

    local redirect_combat = damageredirecttarget ~= nil and damageredirecttarget.components.combat or nil
    if redirect_combat ~= nil then
        -- Small hack for centipede
        redirect_combat.redirected_from = self.inst
		redirect_combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
        redirect_combat.redirected_from = nil
    end

    if self.inst.SoundEmitter ~= nil and not self.inst:IsInLimbo() then
        local hitsound = self:GetImpactSound(damageredirecttarget or self.inst, weapon)
        if hitsound ~= nil then
            self.inst.SoundEmitter:PlaySound(hitsound)
        end
        if damageredirecttarget ~= nil then
            if redirect_combat ~= nil and redirect_combat.hurtsound ~= nil then
                self.inst.SoundEmitter:PlaySound(redirect_combat.hurtsound)
            end
        elseif self.hurtsound ~= nil then
            self.inst.SoundEmitter:PlaySound(self.hurtsound)
        end
    end

    if not blocked then
		self.inst:PushEvent("attacked", { attacker = attacker, damage = damage, damageresolved = damageresolved, original_damage = original_damage, weapon = weapon, stimuli = stimuli, spdamage = spdamage, redirected = damageredirecttarget, noimpactsound = self.noimpactsound })

        if self.onhitfn ~= nil then
			self.onhitfn(self.inst, attacker, damage, spdamage)
        end

        if attacker ~= nil then
			attacker:PushEvent("onhitother", { target = self.inst, damage = damage, damageresolved = damageresolved, stimuli = stimuli, spdamage = spdamage, weapon = weapon, redirected = damageredirecttarget })
            if attacker.components.combat ~= nil and attacker.components.combat.onhitotherfn ~= nil then
				attacker.components.combat.onhitotherfn(attacker, self.inst, damage, stimuli, weapon, damageresolved, spdamage, damageredirecttarget)
            end
        end
    else
        -- We blocked it, but we might still want to know how much they rattled us in damage value!
        self.inst:PushEvent("blocked", { attacker = attacker, damage = damage, spdamage = spdamage, original_damage = original_damage })
    end

	if self.target == nil or self.target == attacker then
		self.lastwasattackedbytargettime = self.lastwasattackedtime
	end

    return not blocked
end

function Combat:GetImpactSound(target, weapon)
    if target == nil or self.noimpactsound then
        return
    end

    --V2C: Considered creating a mapping for tags to strings, but we cannot really
    --     rely on these tags being properly mutually exclusive, so it's better to
    --     leave it like this as if explicitly ordered by priority.

    local hitsound = "dontstarve/impacts/impact_"
    local weaponmod = weapon ~= nil and weapon:HasTag("sharp") and "sharp" or "dull"
    local tgtinv = target.components.inventory
    if tgtinv ~= nil and tgtinv:IsWearingArmor() then
		--Order by priority
		local armormod =
			(tgtinv:ArmorHasTag("forcefield") and "forcefield_armour_") or
			(tgtinv:ArmorHasTag("sanity") and "sanity_armour_") or
			(tgtinv:ArmorHasTag("lunarplant") and "lunarplant_armour_") or
			(tgtinv:ArmorHasTag("dreadstone") and "dreadstone_armour_") or
			(tgtinv:ArmorHasTag("metal") and "metal_armour_") or
			(tgtinv:ArmorHasTag("marble") and "marble_armour_") or
			(tgtinv:ArmorHasTag("shell") and "shell_armour_") or
			(tgtinv:ArmorHasTag("wood") and "wood_armour_") or
			(tgtinv:ArmorHasTag("grass") and "straw_armour_") or
			(tgtinv:ArmorHasTag("fur") and "fur_armour_") or
			(tgtinv:ArmorHasTag("cloth") and "shadowcloth_armour_") or
			nil
		if armormod ~= nil then
			return hitsound..armormod..weaponmod
		end
	end
	if target:HasTag("wall") then
        return
            hitsound..(
                (target:HasTag("grass") and "straw_wall_") or
                (target:HasTag("stone") and "stone_wall_") or
                (target:HasTag("marble") and "marble_wall_") or
                (target:HasTag("fence_electric") and "metal_armour_") or
                "wood_wall_"
            )..weaponmod

    elseif target:HasTag("object") then
        return
            hitsound..(
                (target:HasTag("clay") and "clay_object_") or
                (target:HasTag("stone") and "stone_object_") or
                "object_"
            )..weaponmod

    else
        local tgttype =
			(target:HasAnyTag("hive", "eyeturret", "houndmound") and "hive_") or
            (target:HasTag("ghost") and "ghost_") or
			(target:HasAnyTag("insect", "spider") and "insect_") or
			(target:HasAnyTag("chess", "mech") and "mech_") or
			--V2C: "mech" higher priority over "brightmare(boss)"
			(target:HasAnyTag("brightmare", "brightmareboss") and "ghost_") or
            (target:HasTag("mound") and "mound_") or
			(target:HasAnyTag("shadow", "shadowminion", "shadowchesspiece") and "shadow_") or
			(target:HasAnyTag("tree", "wooden") and "tree_") or
            (target:HasTag("veggie") and "vegetable_") or
            (target:HasTag("shell") and "shell_") or
			(target:HasAnyTag("rocky", "fossil") and "stone_") or
            nil
        return
            hitsound..(
                tgttype or "flesh_"
            )..(
				(target:HasAnyTag("smallcreature", "small") and "sml_") or
				(target:HasAnyTag("largecreature", "epic", "large") and not target:HasAnyTag("shadowchesspiece", "fossil", "brightmareboss") and "lrg_") or
                (tgttype == nil and target:GetIsWet() and "wet_") or
                "med_"
            )..weaponmod
    end
end

function Combat:StartAttack()
    if self.forcefacing and self.target ~= nil and self.target:IsValid() then
        self.inst:ForceFacePoint(self.target:GetPosition())
    end
    self.laststartattacktime = GetTime()
end

function Combat:CancelAttack()
    self.laststartattacktime = nil
end

function Combat:CanTarget(target)
    return self.inst.replica.combat:CanTarget(target)
end

function Combat:HasTarget()
    return self.target ~= nil
end

function Combat:CanAttack(target)
    if not self:IsValidTarget(target) then
        return false, true
    end

    return self.canattack
        and not self:InCooldown()
        and (   self.inst.sg == nil or
                not self.inst.sg:HasStateTag("busy") or
                self.inst.sg:HasStateTag("hit")
            )
        and (   -- V2C: this is 3D distsq
                self.ignorehitrange or
                distsq(target:GetPosition(), self.inst:GetPosition()) <= self:CalcAttackRangeSq(target)
            )
        and not (   -- gjans: Some specific logic so the birchnutter doesn't attack it's spawn with it's AOE
                    -- This could possibly be made more generic so that "things" don't attack other things in their "group" or something
                    self.inst:HasTag("birchnutroot") and
					target:HasAnyTag("birchnutroot", "birchnut", "birchnutdrake")
                )
end

function Combat:LocomotorCanAttack(reached_dest, target)
    if not self:IsValidTarget(target) then
        return false, true, false
    end

	local attackrangesq = self:CalcAttackRangeSq(target)

    reached_dest = reached_dest or
		(self.ignorehitrange or distsq(target:GetPosition(), self.inst:GetPosition()) <= attackrangesq)

    local valid = self.canattack
        and (   self.inst.sg == nil or
                not self.inst.sg:HasStateTag("busy") or
                self.inst.sg:HasStateTag("hit")
            )
        and not (   -- gjans: Some specific logic so the birchnutter doesn't attack it's spawn with it's AOE
                    -- This could possibly be made more generic so that "things" don't attack other things in their "group" or something
                    self.inst:HasTag("birchnutroot") and
					target:HasAnyTag("birchnutroot", "birchnut", "birchnutdrake")
                )

	if attackrangesq > 4 and self.inst.isplayer then
        local weapon = self:GetWeapon()
		local is_ranged_weapon = weapon ~= nil and weapon:HasAnyTag("projectile", "rangedweapon")

        if not is_ranged_weapon then
            local currentpos = self.inst:GetPosition()
            local voidtest = currentpos + ((target:GetPosition() - currentpos):Normalize() * (self:GetAttackRange() / 2))
            if TheWorld.Map:IsNotValidGroundAtPoint(voidtest:Get()) and not TheWorld.Map:IsNotValidGroundAtPoint(target.Transform:GetWorldPosition()) then
                reached_dest = false
            end
        end
    end

    return reached_dest, not valid, self:InCooldown()
end

function Combat:TryAttack(target)
    local target = target or self.target

    local is_attacking = self.inst.sg:HasStateTag("attack")
    if is_attacking then
        return true
    end

    if self:CanAttack(target) then
        self.inst:PushEvent("doattack", {target = target})
        return true
    end

    return false
end

function Combat:ForceAttack()
    if self.target and self:TryAttack() then
        return true
    else
        self.inst:PushEvent("doattack")
    end
end

function Combat:GetWeapon()
    if self.inst.components.inventory ~= nil then
        local item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        return item ~= nil
            and item.components.weapon ~= nil
            and (item.components.projectile ~= nil or
                not (self.inst.components.rider ~= nil and
                    self.inst.components.rider:IsRiding()) or
                item:HasTag("rangedweapon"))
            and item
            or nil
    end
end

function Combat:GetLastAttackedTime()
    return self.lastwasattackedtime
end

function Combat:CalcDamage(target, weapon, multiplier)
    if target:HasTag("alwaysblock") then
        return 0
    end

    local basedamage
    local basemultiplier = self.damagemultiplier
    local externaldamagemultipliers = self.externaldamagemultipliers
	local damagetypemult = 1
    local bonus = self.damagebonus --not affected by multipliers
	local playermultiplier = target ~= nil and (target.isplayer or target:HasTag("player_damagescale"))
	local pvpmultiplier = playermultiplier and self.inst.isplayer and self.pvp_damagemod or 1
	local mount = nil
	local spdamage

    --NOTE: playermultiplier is for damage towards players
    --      generally only applies for NPCs attacking players

    if weapon ~= nil then
        --No playermultiplier when using weapons
		basedamage, spdamage = weapon.components.weapon:GetDamage(self.inst, target)
        playermultiplier = 1
		--#V2C: entity's own damagetypebonus stacks with weapon's damagetypebonus
		if self.inst.components.damagetypebonus ~= nil then
			damagetypemult = self.inst.components.damagetypebonus:GetBonus(target)
		end

        --#DiogoW: entity's own SpDamage stacks with weapon's SpDamage
        spdamage = SpDamageUtil.CollectSpDamage(self.inst, spdamage)
    else
        basedamage = self.defaultdamage
        playermultiplier = playermultiplier and self.playerdamagepercent or 1

        if self.inst.components.rider ~= nil and self.inst.components.rider:IsRiding() then
            mount = self.inst.components.rider:GetMount()
            if mount ~= nil and mount.components.combat ~= nil then
                basedamage = mount.components.combat.defaultdamage
                basemultiplier = mount.components.combat.damagemultiplier
                externaldamagemultipliers = mount.components.combat.externaldamagemultipliers
                bonus = mount.components.combat.damagebonus
				if mount.components.damagetypebonus ~= nil then
					damagetypemult = mount.components.damagetypebonus:GetBonus(target)
				end
				spdamage = SpDamageUtil.CollectSpDamage(mount, spdamage)
			else
				if self.inst.components.damagetypebonus ~= nil then
					damagetypemult = self.inst.components.damagetypebonus:GetBonus(target)
				end
				spdamage = SpDamageUtil.CollectSpDamage(self.inst, spdamage)
            end

            local saddle = self.inst.components.rider:GetSaddle()
            if saddle ~= nil and saddle.components.saddler ~= nil then
                basedamage = basedamage + saddle.components.saddler:GetBonusDamage()
				if saddle.components.damagetypebonus ~= nil then
					damagetypemult = damagetypemult * saddle.components.damagetypebonus:GetBonus(target)
				end
				spdamage = SpDamageUtil.CollectSpDamage(saddle, spdamage)
            end
		else
			if self.inst.components.damagetypebonus ~= nil then
				damagetypemult = self.inst.components.damagetypebonus:GetBonus(target)
			end
			spdamage = SpDamageUtil.CollectSpDamage(self.inst, spdamage)
        end
    end

	local damage = (basedamage or 0)
        * (basemultiplier or 1)
        * externaldamagemultipliers:Get()
		* damagetypemult
        * (multiplier or 1)
        * playermultiplier
        * pvpmultiplier
		* (self.customdamagemultfn ~= nil and self.customdamagemultfn(self.inst, target, weapon, multiplier, mount) or 1)
        + (bonus or 0)

	if spdamage ~= nil then
		local spmult =
			damagetypemult *
			--playermultiplier * --@V2C excluded to avoid tuning nightmare
			pvpmultiplier

        if self.customspdamagemultfn then
            spmult = spmult * (self.customspdamagemultfn(self.inst, target, weapon, multiplier, mount) or 1)
        end

		if spmult ~= 1 then
			spdamage = SpDamageUtil.ApplyMult(spdamage, spmult)
		end

	end
	return damage, spdamage
end

local function _CalcReflectedDamage(inst, attacker, dmg, weapon, stimuli, reflect_list, spdmg)
    if inst == nil then
        return 0
    end

	local reflected_dmg = 0
	local reflected_spdmg

    if inst.components.damagereflect ~= nil then
		local dmg1, spdmg1 = inst.components.damagereflect:GetReflectedDamage(attacker, dmg, weapon, stimuli, spdmg)
        if dmg1 > 0 or spdmg1 ~= nil then
			reflected_dmg = reflected_dmg + dmg1
			reflected_spdmg = SpDamageUtil.MergeSpDamage(reflected_spdmg, spdmg1)
			table.insert(reflect_list, { inst = inst, attacker = attacker, reflected_dmg = dmg1, reflected_spdmg = spdmg1 })
        end
    end

    if inst.components.inventory ~= nil then
        for k, v in pairs(EQUIPSLOTS) do
            local equip = inst.components.inventory:GetEquippedItem(v)
            if equip ~= nil and equip.components.damagereflect ~= nil then
				local dmg1, spdmg1 = equip.components.damagereflect:GetReflectedDamage(attacker, dmg, weapon, stimuli, spdmg)
				if dmg1 > 0 or spdmg1 ~= nil then
					reflected_dmg = reflected_dmg + dmg1
					reflected_spdmg = SpDamageUtil.MergeSpDamage(reflected_spdmg, spdmg1)
					table.insert(reflect_list, { inst = equip, attacker = attacker, reflected_dmg = dmg1, reflected_spdmg = spdmg1 })
                end
            end
        end
    end

	return reflected_dmg, reflected_spdmg
end

function Combat:CalcReflectedDamage(targ, dmg, weapon, stimuli, reflect_list, spdmg)
    if self.ignoredamagereflect then
        return 0, nil
    end

	if targ.components.rider ~= nil and targ.components.rider:IsRiding() then
		local dmg1, spdmg1 = _CalcReflectedDamage(targ.components.rider:GetMount(), self.inst, dmg, weapon, stimuli, reflect_list, spdmg)
		local dmg2, spdmg2 = _CalcReflectedDamage(targ.components.rider:GetSaddle(), self.inst, dmg, weapon, stimuli, reflect_list, spdmg)
		return dmg1 + dmg2, SpDamageUtil.MergeSpDamage(spdmg1, spdmg2)
	end

	return _CalcReflectedDamage(targ, self.inst, dmg, weapon, stimuli, reflect_list, spdmg)
end

function Combat:GetAttackRange()
    local weapon = self:GetWeapon()
    return weapon ~= nil
        and weapon.components.weapon.attackrange ~= nil
        and math.max(0, self.attackrange + weapon.components.weapon.attackrange)
        or self.attackrange
end

function Combat:CalcAttackRangeSq(target)
    local range = (target or self.target):GetPhysicsRadius(0) + self:GetAttackRange()
    return range * range
end

function Combat:GetHitRange()
    local weapon = self:GetWeapon()
    return self.temprange or weapon ~= nil and weapon.components.weapon.hitrange ~= nil and self.hitrange + weapon.components.weapon.hitrange or self.hitrange
end

function Combat:CalcHitRangeSq(target)
    local range = (target or self.target):GetPhysicsRadius(0) + self:GetHitRange()
    return range * range
end

function Combat:CanExtinguishTarget(target, weapon)
	local burnable = target.components.burnable
    return burnable ~= nil
        and (burnable:IsSmoldering() or burnable:IsBurning())
        and (weapon ~= nil and weapon:HasTag("extinguisher") or self.inst:HasTag("extinguisher"))
end

function Combat:CanLightTarget(target, weapon)
    return weapon ~= nil
        and weapon:HasTag("rangedlighter")
        and target.components.burnable ~= nil
        and target.components.burnable.canlight
        and not target.components.burnable:IsBurning()
        and not target:HasTag("burnt")
        --[[and (target.components.fueled == nil or
            not target.components.fueled.accepting or
            target.components.fueled.fueltype == FUELTYPE.BURNABLE or
            target.components.fueled.secondaryfueltype == FUELTYPE.BURNABLE)]]
        --V2C: fueled or fueltype should not really matter. if we can burn it, should still allow lighting.
end

function Combat:CanHitTarget(target, weapon)
    if self.inst ~= nil and
        self.inst:IsValid() and
        target ~= nil and
        target:IsValid() and
        not target:IsInLimbo() and
        (   self:CanExtinguishTarget(target, weapon) or
            self:CanLightTarget(target, weapon) or
            (   target.components.combat ~= nil and
                target.components.combat:CanBeAttacked(self.inst)
            )
        ) then

        local targetpos = target:GetPosition()
        -- V2C: this is 3D distsq
        local pos = self.temppos or self.inst:GetPosition()
        if self.ignorehitrange or distsq(targetpos, pos) <= self:CalcHitRangeSq(target) then
            return true
        elseif weapon ~= nil and weapon.components.projectile ~= nil then
            local range = target:GetPhysicsRadius(0) + weapon.components.projectile.hitdist
            -- V2C: this is 3D distsq
            return distsq(targetpos, weapon:GetPosition()) <= range * range
        end
    end
    return false
end

function Combat:ClearAttackTemps()
    self.temppos = nil
    self.temprange = nil
end

function Combat:DoAttack(targ, weapon, projectile, stimuli, instancemult, instrangeoverride, instpos)
    if instrangeoverride then
        self.temprange = instrangeoverride
    end
    if instpos then
        self.temppos = instpos
    end
    if targ == nil then
        targ = self.target
    end
    if weapon == nil then
        weapon = self:GetWeapon()
    end
    if stimuli == nil then
		if weapon and weapon.components.weapon then
			if weapon.components.weapon.overridestimulifn then
				stimuli = weapon.components.weapon.overridestimulifn(weapon, self.inst, targ)
			end
			if stimuli == nil and weapon.components.weapon.stimuli == "electric" then
				stimuli = "electric"
			end
        end
        if stimuli == nil and self.inst.components.electricattacks ~= nil then
            stimuli = "electric"
        end
    end

    if not self:CanHitTarget(targ, weapon) or self.AOEarc then
        self.inst:PushEvent("onmissother", { target = targ, weapon = weapon })
        if self.areahitrange ~= nil and not self.areahitdisabled then
            self:DoAreaAttack(projectile or self.inst, self.areahitrange, weapon, self.areahitcheck, stimuli, AREA_EXCLUDE_TAGS)
        end
        self:ClearAttackTemps()
        return
    end

    if targ.components.combat then
        local recoil, damage = targ.components.combat:ShouldRecoil(self.inst, weapon)
	    if recoil and self.inst.sg ~= nil and self.inst.sg.statemem.recoilstate ~= nil then
            self.inst:PushEventImmediate("recoil_off", { target = targ } )
	    	if damage == 0 or damage == nil then
	    		self.inst:PushEvent("weapontooweak")
	    	end
	    end
    end

    self.inst:PushEvent("onattackother", { target = targ, weapon = weapon, projectile = projectile, stimuli = stimuli })

    if weapon ~= nil and projectile == nil then
        if weapon.components.projectile ~= nil then
            local projectile = self.inst.components.inventory:DropItem(weapon, false)
            if projectile ~= nil then
                projectile.components.projectile:Throw(self.inst, targ)
            end
            self:ClearAttackTemps()
            return

        elseif weapon.components.complexprojectile ~= nil and not weapon.components.complexprojectile.ismeleeweapon then
            local projectile = self.inst.components.inventory:DropItem(weapon, false)
            if projectile ~= nil then
                projectile.components.complexprojectile:Launch(targ:GetPosition(), self.inst)
            end
            self:ClearAttackTemps()
            return

        elseif weapon.components.weapon:CanRangedAttack() then
            weapon.components.weapon:LaunchProjectile(self.inst, targ)
            self:ClearAttackTemps()
            return
        end
    end

    local reflected_dmg = 0
	local reflected_spdmg
    local reflect_list = {}
    if targ.components.combat ~= nil then
        local mult = 1

        local _weapon_cmp = weapon ~= nil and weapon.components.weapon or nil

        if  (
                stimuli == "electric" or
                (_weapon_cmp ~= nil and _weapon_cmp.stimuli == "electric")
            )
            and not IsEntityElectricImmune(targ)
        then
            local electric_damage_mult = _weapon_cmp ~= nil and _weapon_cmp.electric_damage_mult or TUNING.ELECTRIC_DAMAGE_MULT
            local electric_wet_damage_mult = _weapon_cmp ~= nil and _weapon_cmp.electric_wet_damage_mult or TUNING.ELECTRIC_WET_DAMAGE_MULT

            mult = electric_damage_mult + electric_wet_damage_mult * targ:GetWetMultiplier()
        end

		local dmg, spdmg = self:CalcDamage(targ, weapon, mult)
		dmg = dmg * (instancemult or 1)
        --Calculate reflect first, before GetAttacked destroys armor etc.
        if projectile == nil then
			reflected_dmg, reflected_spdmg = self:CalcReflectedDamage(targ, dmg, weapon, stimuli, reflect_list, spdmg)
        end
		targ.components.combat:GetAttacked(self.inst, dmg, weapon, stimuli, spdmg)
    elseif projectile == nil then
		reflected_dmg, reflected_spdmg = self:CalcReflectedDamage(targ, 0, weapon, stimuli, reflect_list)
    end

    if weapon ~= nil then
        weapon.components.weapon:OnAttack(self.inst, targ, projectile)
    end

    if self.areahitrange ~= nil and not self.areahitdisabled then
        self:DoAreaAttack(targ, self.areahitrange, weapon, self.areahitcheck, stimuli, AREA_EXCLUDE_TAGS)
    end
    self:ClearAttackTemps()
    self.lastdoattacktime = GetTime()

    --Apply reflected damage to self after our attack damage is completed
	if (reflected_dmg > 0 or reflected_spdmg ~= nil) and self.inst.components.health ~= nil and not self.inst.components.health:IsDead() then
		self:GetAttacked(targ, reflected_dmg, nil, nil, reflected_spdmg)
        for i, v in ipairs(reflect_list) do
            if v.inst:IsValid() then
                v.inst:PushEvent("onreflectdamage", v)
            end
        end
    end
end

function Combat:SetRequiresToughCombat(tough)
	self.tough = tough
end

function Combat:SetShouldRecoilFn(fn)
	self.shouldrecoilfn = fn
end

function Combat:ShouldRecoil(attacker, weapon, damage)
	if self.shouldrecoilfn ~= nil then
		local recoil, remaining_damage = self.shouldrecoilfn(self.inst, attacker, weapon, damage)
		if recoil ~= nil then
			if recoil then
				return true, remaining_damage or nil
			end
			return false, remaining_damage or damage
		end
	end

	if self.tough and
		not (attacker ~= nil and attacker:HasTag("toughfighter")) and --TODO reuse toughworker?
		not (weapon ~= nil and weapon.components.weapon ~= nil and weapon.components.weapon:CanDoToughFight())
		then
		return true, nil
	end

	return false, damage
end

--#V2C: what's this? not used?
function Combat:GetDamageReflect(target, damage, weapon, stimuli)
    if target.components.rider ~= nil and target.components.rider:IsRiding() then
        local mount = target.components.rider:GetMount()
        if mount ~= nil then
            if mount.components.damagereflect ~= nil then
                mount.components.damagereflect:OnAttacked(self.inst, damage, weapon, stimuli)
            end
            return
        end
    end
    if target.components.damagereflect ~= nil then
        target.components.damagereflect:OnAttacked(self.inst, damage, weapon, stimuli)
    end
end

local AREAATTACK_MUST_TAGS = { "_combat" }
function Combat:DoAreaAttack(target, range, weapon, validfn, stimuli, excludetags, onlyontarget)
    local hitcount = 0
    local x, y, z = target.Transform:GetWorldPosition()
    if onlyontarget then
        local ent = target
        if self:IsValidTarget(ent) and
            (validfn == nil or validfn(ent, self.inst)) then
            self.inst:PushEvent("onareaattackother", { target = ent, weapon = weapon, stimuli = stimuli })
            local dmg, spdmg = self:CalcDamage(ent, weapon, self.areahitdamagepercent)
            ent.components.combat:GetAttacked(self.inst, dmg, weapon, stimuli, spdmg)
            hitcount = hitcount + 1
        end
    else
        local ents = TheSim:FindEntities(x, y, z, range, AREAATTACK_MUST_TAGS, excludetags)
        for i, ent in ipairs(ents) do
            if ent ~= target and
                ent ~= self.inst and
                self:IsValidTarget(ent) and
                (validfn == nil or validfn(ent, self.inst)) then
                self.inst:PushEvent("onareaattackother", { target = ent, weapon = weapon, stimuli = stimuli })
                local dmg, spdmg = self:CalcDamage(ent, weapon, self.areahitdamagepercent)
                ent.components.combat:GetAttacked(self.inst, dmg, weapon, stimuli, spdmg)
                hitcount = hitcount + 1
            end
        end
    end

    return hitcount
end

function Combat:IsAlly(guy)
    return self.inst.replica.combat:IsAlly(guy)
end

function Combat:TargetHasFriendlyLeader(target)
    return self.inst.replica.combat:TargetHasFriendlyLeader(target)
end

function Combat:CanBeAttacked(attacker)
    return self.inst.replica.combat:CanBeAttacked(attacker)
end

function Combat:OnRemoveFromEntity()
    if self.target ~= nil then
        self:StopTrackingTarget(self.target)
    end
    if self.blanktask ~= nil then
        self.blanktask:Cancel()
        self.blanktask = nil
    end
    if self.retargettask ~= nil then
        self.retargettask:Cancel()
        self.retargettask = nil
    end
	self.inst:RemoveEventCallback("knockback", CommonHandlers.ResetHitRecoveryDelay)
end

return Combat
