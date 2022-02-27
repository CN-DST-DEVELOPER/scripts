local STATE_DATA = 
{
    ["wimpy"] = { 
        skin_data = { skin_mode = "wimpy_skin", default_build = "wolfgang_skinny" },
        
        announce = "ANNOUNCE_NORMALTOWIMPY",
        event = "powerdown",
        sound = "wolfgang2/characters/wolfgang/wimpy",

        externaldamagemultiplier = 0.75,
        externaldamagetakenmultiplier = 1.2,
        talksoundoverride = "dontstarve/characters/wolfgang/talk_small_LP", 
        hurtsoundoverride = "dontstarve/characters/wolfgang/hurt_small",
        customidle = "idle_wolfgang_skinny",
        tag = "mightiness_wimpy",

        scale = 0.9,
        insulation = -TUNING.INSULATION_SMALL,
    },
    
    ["normal"] = { 
        skin_data = { skin_mode = "normal_skin", default_build = "wolfgang" },
        
        announce = {wimpy = "ANNOUNCE_WIMPYTONORMAL", mighty = "ANNOUNCE_MIGHTYTONORMAL"},
        event =    {wimpy = "powerup", mighty = "powerdown"},
        sound =    {wimpy = "wolfgang2/characters/wolfgang/mighty", mighty = "wolfgang2/characters/wolfgang/wimpy"},

        externaldamagemultiplier = nil,
        externaldamagetakenmultiplier = nil,
        talksoundoverride = nil,
        hurtsoundoverride = nil,
        customidle = "idle_wolfgang",
        tag = "mightiness_normal",

        scale = 1,
    },
    
    ["mighty"] = { 
        skin_data = { skin_mode = "mighty_skin", default_build = "wolfgang_mighty" },
        
        announce = "ANNOUNCE_NORMALTOMIGHTY",
        event = "powerup",
        sound = "wolfgang2/characters/wolfgang/mighty",

        externaldamagemultiplier = 2,
        externaldamagetakenmultiplier = nil,
        talksoundoverride = "dontstarve/characters/wolfgang/talk_large_LP", 
        hurtsoundoverride = "dontstarve/characters/wolfgang/hurt_large",
        customidle = "idle_wolfgang_mighty",
        tag = "mightiness_mighty",

        row_force_mult = TUNING.MIGHTY_ROWER_MULT,
        anchor_raise_speed = TUNING.MIGHTY_ANCHOR_SPEED,
        lower_sail_strength = TUNING.MIGHTY_SAIL_STRENGTH,

        scale = 1.2,
        insulation = TUNING.INSULATION_SMALL,
        work_effectiveness = TUNING.MIGHTY_WORK_EFFECTIVENESS,
    },
}

local function oncurrent(self, current)
    local percent = math.ceil(100 * current / self.max) -- convert it to a percent between 0 and 100
    if self.inst.player_classified ~= nil then
        assert(percent >= 0 and percent <= 255, "Player currentmightiness out of range: "..tostring(percent))
        self.inst.player_classified.currentmightiness:set(percent)
    end
end

local function onratescale(self, ratescale)
    if self.inst.player_classified ~= nil then
        self.inst.player_classified.mightinessratescale:set(ratescale)
    end
end

local function OnTaskTick(inst, self, period)
    self:DoDec(period)
end

local Mightiness = Class(function(self, inst)
    self.inst = inst
    self.max = TUNING.MIGHTINESS_MAX
    self.current = self.max/2

    self.wimpy_threshold = 30 
    self.mighty_threshold = 60

    self.rate = TUNING.MIGHTINESS_DRAIN_RATE
    self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_NORMAL
    self.ratescale = RATE_SCALE.NEUTRAL

    self.draining = true
    self.ratemodifiers = SourceModifierList(self.inst)

    self.state = "normal"

    local period = 1
    self.inst:DoPeriodicTask(period, OnTaskTick, nil, self, period)

    self.inst:ListenForEvent("hungerdelta", function(_, data) self:OnHungerDelta(data) end)
    self.inst:ListenForEvent("invincibletoggle", function(_, data) self:OnSetInvincible(data) end)
end,
nil,
{
    current = oncurrent,
    ratescale = onratescale
})

function Mightiness:OnSetInvincible(data)
    if data and data.invincible then
        self:Pause()
    else
        self:Resume()
    end
end

function Mightiness:OnSave()
    return self.current ~= self.max and { mightiness = self.current } or nil
end

function Mightiness:OnLoad(data)
    if data.mightiness ~= nil and self.current ~= data.mightiness then
        self.current = data.mightiness
        self:DoDelta(0, true)
    end
end

function Mightiness:GetState()
    return self.state
end

function Mightiness:GetScale()
    return STATE_DATA[self:GetState()].scale
end

function Mightiness:LongUpdate(dt)
    self:DoDec(dt, true)
end

function Mightiness:Pause()
    self.draining = false
end

function Mightiness:Resume()
    self.draining = true
end

function Mightiness:IsPaused()
    return not self.draining
end

function Mightiness:GetDebugString()
    return string.format("%2.2f / %2.2f, rate: (%2.2f * %2.2f)", self.current, self.max, self.rate, self.ratemodifiers:Get())
end

function Mightiness:SetMax(amount)
    self.max = amount
    self.current = amount
end

function Mightiness:DoDelta(delta, force_update, delay_skin, forcesound)

    local old = self.current
    self.current = math.clamp(self.current + delta, 0, self.max)

    self.inst:PushEvent("mightinessdelta", { oldpercent = old / self.max, newpercent = self.current / self.max, delta = self.current-old })

    if self.current >= TUNING.MIGHTY_THRESHOLD then
        if self.state ~= "mighty" or force_update then
            self:BecomeState("mighty", force_update, delay_skin, forcesound)
        end
    elseif self.current >= TUNING.WIMPY_THRESHOLD then
        if self.state ~= "normal" or force_update then
            self:BecomeState("normal", force_update, delay_skin, forcesound)
        end
    else
        if self.state ~= "wimpy" or force_update then
            self:BecomeState("wimpy", force_update, delay_skin, forcesound)
        end
    end
end

function Mightiness:GetPercent()
    return self.current / self.max
end

function Mightiness:SetPercent(percent, force_update, delay_skin, forcesound)
    local dt = (percent * self.max) - self.current
    self:DoDelta(dt, force_update, delay_skin, forcesound)
end

function Mightiness:DoDec(dt, ignore_damage)
    if self.draining then
        self:DoDelta(-self.rate * dt * self.drain_multiplier * self.ratemodifiers:Get())
    end
end

function Mightiness:SetRate(rate)
    self.rate = rate
end

function Mightiness:CanTransform(state)
    return not (self.inst.sg:HasStateTag("nomorph") or
                self.inst:HasTag("playerghost") or
                self.inst.components.health:IsDead() or
                self.state == state)
end


function Mightiness:UpdateSkinMode(skin_data, delay)
	if self.inst.queued_skindata_task ~= nil then
		self.inst.updateskindatatask:Cancel()
		self.inst.updateskindatatask = nil
	end

	if delay then
		if self.inst.queued_skindata ~= nil then
		    self.inst.components.skinner:SetSkinMode(self.inst.queued_skindata[1], self.inst.queued_skindata[2])
		end
		self.inst.queued_skindata = skin_data
		self.inst.updateskindatatask = self.inst:DoTaskInTime(FRAMES * 88, function() self:UpdateSkinMode(skin_data) end)
	else
	    self.inst.components.skinner:SetSkinMode(skin_data.skin_mode, skin_data.default_build)
		self.inst.queued_skindata = nil
	end
end

function Mightiness:BecomeState(state, silent, delay_skin, forcesound)
    if not self:CanTransform(state) then
        return
    end

    silent = silent or self.inst.sg:HasStateTag("silentmorph") or not self.inst.entity:IsVisible()

    local state_data = STATE_DATA[state]
    self:UpdateSkinMode(state_data.skin_data, delay_skin)

    local gym = self.inst.components.strongman.gym
    if gym then
        gym.components.mightygym:SetSkinModeOnGym(self.inst, state_data.skin_data.skin_mode)
    end

    if not silent then
        if state == "normal" then
            self.inst.sg:PushEvent(state_data.event[self.state])
            self.inst.components.talker:Say(GetString(self.inst, state_data.announce[self.state]))
        else
            self.inst.sg:PushEvent(state_data.event)
            self.inst.components.talker:Say(GetString(self.inst, state_data.announce))
        end
    end

    if not silent or forcesound then
        if state == "normal" then
            self.inst.SoundEmitter:PlaySound(state_data.sound[self.state])
        else
            self.inst.SoundEmitter:PlaySound(state_data.sound)
        end
    end

    if state_data.externaldamagemultiplier ~= nil then
        self.inst.components.combat.externaldamagemultipliers:SetModifier(self.inst, state_data.externaldamagemultiplier)
    else
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst)
    end
    
    if state_data.externaldamagetakenmultiplier ~= nil then
        self.inst.components.combat.externaldamagetakenmultipliers:SetModifier(self.inst, state_data.externaldamagetakenmultiplier)
    else
        self.inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(self.inst)
    end

    if state_data.insulation then
        self.inst.components.temperature.inherentinsulation =  state_data.insulation
        self.inst.components.temperature.inherentsummerinsulation =  state_data.insulation
    else
        self.inst.components.temperature.inherentinsulation = 0
        self.inst.components.temperature.inherentsummerinsulation = 0
    end

    self.inst.components.expertsailor:SetRowForceMultiplier(state_data.row_force_mult)
    self.inst.components.expertsailor:SetAnchorRaisingSpeed(state_data.anchor_raise_speed)
    self.inst.components.expertsailor:SetLowerSailStrength(state_data.lower_sail_strength)

    if state_data.work_effectiveness then
        self.inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP,   state_data.work_effectiveness, self.inst)
        self.inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE,   state_data.work_effectiveness, self.inst)
        self.inst.components.workmultiplier:AddMultiplier(ACTIONS.HAMMER, state_data.work_effectiveness, self.inst)
        
        self.inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP,    state_data.work_effectiveness, self.inst)
        self.inst.components.efficientuser:AddMultiplier(ACTIONS.MINE,    state_data.work_effectiveness, self.inst)
        self.inst.components.efficientuser:AddMultiplier(ACTIONS.HAMMER,  state_data.work_effectiveness, self.inst)
    else
        self.inst.components.workmultiplier:RemoveMultiplier(ACTIONS.CHOP,   self.inst)
        self.inst.components.workmultiplier:RemoveMultiplier(ACTIONS.MINE,   self.inst)
        self.inst.components.workmultiplier:RemoveMultiplier(ACTIONS.HAMMER, self.inst)

        self.inst.components.efficientuser:RemoveMultiplier(ACTIONS.CHOP,    self.inst)
        self.inst.components.efficientuser:RemoveMultiplier(ACTIONS.MINE,    self.inst)
        self.inst.components.efficientuser:RemoveMultiplier(ACTIONS.HAMMER,  self.inst)
    end

    if not self.inst:HasTag("ingym") then
        self.inst:ApplyScale("mightiness", state_data.scale)
    end
    
    self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "mightiness", 1/state_data.scale)

    self.inst:RemoveTag(STATE_DATA[self.state].tag)
    self.inst:AddTag(state_data.tag)    

    self.inst.talksoundoverride = state_data.talksoundoverride
    self.inst.hurtsoundoverride = state_data.hurtsoundoverride
    self.inst.customidleanim = state_data.customidle
    
    local previous_state = self.state
    self.state = state

    self.inst:PushEvent("mightiness_statechange", {previous_state = previous_state, state = state})
end

function Mightiness:OnHungerDelta(data)
    local percent = data ~= nil and data.newpercent or nil
    if percent then
        if percent >= 0.75 then
            self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_SLOW
        elseif percent >= 0.5 then
            self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_NORMAL
        elseif percent >= 0.25 then
            self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_FAST
        elseif percent > 0 then
            self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_FASTEST
        else
            self.drain_multiplier = TUNING.MIGHTINESS_DRAIN_MULT_STARVING
        end
    end
end

function Mightiness:GetRateScale()
    return self.ratescale
end

function Mightiness:SetRateScale(ratescale)
    self.ratescale = ratescale or RATE_SCALE.NEUTRAL
end

function Mightiness:GetSkinMode()
    return STATE_DATA[self.state].skin_data.skin_mode
end

return Mightiness