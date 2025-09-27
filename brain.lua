
BrainWrangler = Class(function(self)
        self.instances = {}
        self.updaters = {}
        self._safe_updaters = {} -- NOTES(JBK): Internal use for safely iterating over self.updaters.
        self.tickwaiters = {}
        self.hibernaters = {}
end)

BrainManager = BrainWrangler()

function BrainWrangler:OnRemoveEntity(inst)
    --print ("onremove", inst, debugstack())
    if inst.brain and self.instances[inst.brain] then
		self:RemoveInstance(inst.brain)
	end
end


function BrainWrangler:NameList(list)
    if not list then
        return "nil"
    elseif list == self.updaters then
        return "updaters"
    elseif list == self.hibernaters then
        return "hibernators"
    else
        for k,v in pairs(self.tickwaiters) do
            if list == v then
                return "tickwaiter "..tostring(k)
            end
        end
    end

    return "Unknown"

end

function BrainWrangler:SendToList(inst, list)

    local old_list = self.instances[inst]
--    print ("HI!", inst.inst, self:NameList(old_list), self:NameList(list))
    if old_list and old_list ~= list then
        if old_list then
            old_list[inst] = nil
        end

        self.instances[inst] = list

        if list then
            list[inst] = true
        end
    end
end

function BrainWrangler:Wake(inst)
    if self.instances[inst] then
        self:SendToList(inst, self.updaters)
    end
end

function BrainWrangler:Hibernate(inst)
    if self.instances[inst] then
        self:SendToList(inst, self.hibernaters)
    end
end

function BrainWrangler:Sleep(inst, time_to_wait)
    local sleep_ticks = time_to_wait/GetTickTime()
    if sleep_ticks == 0 then sleep_ticks = 1 end

    local target_tick = math.floor(GetTick() + sleep_ticks)

    if target_tick > GetTick() then
        local waiters = self.tickwaiters[target_tick]

        if not waiters then
            waiters = {}
            self.tickwaiters[target_tick] = waiters
        end

        --print ("BRAIN SLEEPS", inst.inst)
        self:SendToList(inst, waiters)

    end
end


function BrainWrangler:RemoveInstance(inst)
    self:SendToList(inst, nil)
    self.updaters[inst] = nil
    self.hibernaters[inst] = nil
    for k,v in pairs(self.tickwaiters) do
        v[inst] = nil
    end
    self.instances[inst] = nil

end

function BrainWrangler:AddInstance(inst)

    self.instances[inst] = self.updaters
    self.updaters[inst] = true
end

function BrainWrangler:Update(current_tick)

	--[[
	local num = 0;
	local types = {}
	for k,v in pairs(self.instances) do

		num = num + 1
		types[k.inst.prefab] = types[k.inst.prefab] and types[k.inst.prefab] + 1 or 1
	end
	print ("NUM BRAINS:", num)
	for k,v in pairs(types) do
		print ("    ",k,v)
	end
	--]]


    local waiters = self.tickwaiters[current_tick]
    if waiters then
        for k,v in pairs(waiters) do
            --print ("BRAIN COMES ONLINE", k.inst)
            self.updaters[k] = true
            self.instances[k] = self.updaters
        end
        self.tickwaiters[current_tick] = nil
    end


    -- NOTES(JBK): We need to make a copy of the keys to safely iterate over the table because brains will remove and add onto the self.updaters table during iteration.
    local count = 0
    for k, _ in pairs(self.updaters) do
        if k.inst.entity:IsValid() and not k.inst:IsAsleep() then
            count = count + 1
            self._safe_updaters[count] = k
        end
    end
    for i = 1, count do
        local k = self._safe_updaters[i]
        self._safe_updaters[i] = nil

        k:OnUpdate()
        local sleep_amount = k:GetSleepTime()
        if sleep_amount then
            if sleep_amount > GetTickTime() then
                self:Sleep(k, sleep_amount)
            else
            end
        else
            self:Hibernate(k)
        end
    end
end

Brain = Class(function(self)
    self.inst = nil
    self.currentbehaviour = nil
    self.behaviourqueue = {}
    self.events = {}
    self.thinkperiod = nil
    self.lastthinktime = nil
    self.paused = false
	self.stopped = true
end)

function Brain:ForceUpdate()
    if self.bt then
        self.bt:ForceUpdate()
    end

    BrainManager:Wake(self)
end

function Brain:__tostring()

    if self.bt then
        return string.format("--brain--\nsleep time: %2.2f\n%s", self:GetSleepTime(), tostring(self.bt))
    end
    return "--brain--"
end

function Brain:AddEventHandler(event, fn)
    self.events[event] = fn
end

function Brain:GetSleepTime()
    if self.bt then
        return self.bt:GetSleepTime()
    end

    return 0
end

--V2C: deprecated; use EntityScript:RestartBrain
function Brain:Start(reason)
	if self.inst then
		self.inst:RestartBrain(reason)
	end
end

--V2C: should only be called from EntityScript
function Brain:_Start_Internal()
	if not self.stopped then
		return
	elseif self.OnStart then
        self:OnStart()
    end
    self.stopped = false
	if not self.paused then
		BrainManager:AddInstance(self)
	end
	if self.OnInitializationComplete then
		self:OnInitializationComplete()
	end

	-- apply mods
	if self.modpostinitfns then
		for i,modfn in ipairs(self.modpostinitfns) do
			modfn(self)
		end
	end
end

function Brain:OnUpdate()
    if self.DoUpdate then
		self:DoUpdate()
    end

    if self.bt then
        self.bt:Update()
    end
end

--V2C: deprecated; use EntityScript:StopBrain
function Brain:Stop(reason)
	if self.inst then
		self.inst:StopBrain(reason)
	end
end

--V2C: should only be called from EntityScript
function Brain:_Stop_Internal()
	if self.stopped then
		return
	elseif self.OnStop then
        self:OnStop()
    end
    if self.bt then
        self.bt:Stop()
    end
    self.stopped = true
	if not self.paused then --already removed if paused
		BrainManager:RemoveInstance(self)
	end
end

function Brain:PushEvent(event, data)
    local handler = self.events[event]

    if handler then
        handler(data)
    end
end

function Brain:Pause()
	if not self.paused then
		self.paused = true
		if not self.stopped then
			BrainManager:RemoveInstance(self)
		end
	end
end

function Brain:Resume()
	if self.paused then
		self.paused = false
		if not self.stopped then
			BrainManager:AddInstance(self)
		end
	end
end
