UseShield = Class(BehaviourNode, function(self, inst, damageforshield, shieldtime, hidefromprojectiles, hidewhenscared, data)
    BehaviourNode._ctor(self, "UseShield")
    self.inst = inst
    self.damageforshield = damageforshield or 100
    self.hidefromprojectiles = hidefromprojectiles or false
    self.scareendtime = 0
    self.damagetaken = 0
    self.timelastattacked = 1
    self.shieldtime = shieldtime or 2
    self.projectileincoming = false

    if data then
        self.dontupdatetimeonattack = data.dontupdatetimeonattack
        self.usecustomanims = data.usecustomanims
        self.dontshieldforfire = data.dontshieldforfire
        self.checkstategraph = data.checkstategraph
        self.shouldshieldfn = data.shouldshieldfn -- shouldshieldfn CAN optionally return a time to shield for.
    end

    if hidewhenscared then
        self.onepicscarefn = function(inst, data) self.scareendtime = math.max(self.scareendtime, data.duration + GetTime() + math.random()) end
        self.inst:ListenForEvent("epicscare", self.onepicscarefn)
    end

    self.onattackedfn = function(inst, data) self:OnAttacked(data.attacker, data.damage) end
    self.onhostileprojectilefn = function() self:OnAttacked(nil, 0, true) end
    self.onfiredamagefn = function() self:OnAttacked() end
	self.onelectrocutefn = function() self.inst.brain:ForceUpdate() end

    self.inst:ListenForEvent("attacked", self.onattackedfn)
    self.inst:ListenForEvent("hostileprojectile", self.onhostileprojectilefn)
    self.inst:ListenForEvent("firedamage", self.onfiredamagefn)
    self.inst:ListenForEvent("startfiredamage", self.onfiredamagefn)
	self.inst:ListenForEvent("startelectrocute", self.onelectrocutefn)
end)

function UseShield:OnStop()
    if self.onepicscarefn ~= nil then
        self.inst:RemoveEventCallback("epicscare", self.onepicscarefn)
    end
    self.inst:RemoveEventCallback("attacked", self.onattackedfn)
    self.inst:RemoveEventCallback("hostileprojectile", self.onhostileprojectilefn)
    self.inst:RemoveEventCallback("firedamage", self.onfiredamagefn)
    self.inst:RemoveEventCallback("startfiredamage", self.onfiredamagefn)
	self.inst:RemoveEventCallback("startelectrocute", self.onelectrocutefn)
end

function UseShield:TimeToEmerge()
    local t = GetTime()
    return t - self.timelastattacked > self.shieldtime
        and t >= self.scareendtime
        and (self.shieldendtime == nil or t >= self.shieldendtime)
end

function UseShield:ShouldShield()
    if self.inst.components.health:IsDead() then
        return false
    end

    if self.checkstategraph and (self.inst.sg:HasStateTag("busy") and not self.inst.sg:HasStateTag("caninterrupt")) then
        return false
    end

    if self.shouldshieldfn then
        local should_shield, time_to_shield = self.shouldshieldfn(self.inst)
        if should_shield then
            return should_shield, time_to_shield or nil
        end
    end

    return (self.damagetaken > self.damageforshield or
            (not self.dontshieldforfire and self.inst.components.health.takingfiredamage) or
            self.projectileincoming or
            GetTime() < self.scareendtime)
end

function UseShield:OnAttacked(attacker, damage, projectile)
    if not self.inst.sg:HasStateTag("frozen") then
        if not self.dontupdatetimeonattack then
            self.timelastattacked = GetTime()
            self.shieldendtime = nil -- If we we had a custom shield end time, clear it and rely on time last attacked now.
        end

        if not self.usecustomanims and
                self.inst.sg.currentstate.name == "shield" and not projectile then
            self.inst.AnimState:PlayAnimation("hit_shield")
            self.inst.AnimState:PushAnimation("hide_loop")
            return
        end

        if damage then
            self.damagetaken = self.damagetaken + damage
        end

        if projectile and self.hidefromprojectiles then
            self.projectileincoming = true
            return
        end
    end
end

function UseShield:Visit()
    if self.status == READY  then
        local should_shield, time_to_shield = self:ShouldShield()
		if (should_shield or self.inst.sg:HasStateTag("shield")) and not self.inst.sg:HasAnyStateTag("electrocute", "shield_end") then
            self.damagetaken = 0
            self.projectileincoming = false

            if time_to_shield then
                self.shieldendtime = GetTime() + time_to_shield
            end

            if self.dontupdatetimeonattack then
                -- If we're not updating on attack, we have to update when we
                -- start running the node instead.
                self.timelastattacked = GetTime()
                if not self.inst.sg:HasStateTag("shield") then
                    self.inst:PushEvent("entershield")
                end
            else
                self.inst:PushEvent("entershield")
            end

            self.status = RUNNING
        else
            self.status = FAILED
        end
    end

    if self.status == RUNNING then
		if self.inst.sg:HasStateTag("electrocute") then
			self.status = FAILED
		elseif not self:TimeToEmerge() or
                (not self.dontshieldforfire and self.inst.components.health.takingfiredamage) then
            self.status = RUNNING
        else
            self.inst:PushEvent("exitshield")
            self.status = SUCCESS
        end
    end
end
