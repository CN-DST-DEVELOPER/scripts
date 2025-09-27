require("class")

StateGraphWrangler = Class(function(self)
        self.instances = {}
        self.updaters = {}
        self.tickwaiters = {}
        self.hibernaters = {}
        self.haveEvents = {}
end)

SGManager = StateGraphWrangler()

function StateGraphWrangler:SendToList(inst, list)
    local old_list = self.instances[inst]
    if old_list then
        old_list[inst] = nil
    end

    self.instances[inst] = list

    if list then
        list[inst] = true
    end

end

function SGManager:OnEnterNewState(inst)
    if self.instances[inst] then
        self:SendToList(inst, self.updaters)
    end
end

function StateGraphWrangler:OnSetTimeout(inst)
    if self.instances[inst] then
        self:SendToList(inst, self.updaters)
    end
end

function StateGraphWrangler:OnPushEvent(inst)
    if self.instances[inst] then
        self.haveEvents[inst] = true
		return true
    end
	return false
end

function StateGraphWrangler:Hibernate(inst)
    if self.instances[inst] then
        self:SendToList(inst, self.hibernaters)
    end
end

function StateGraphWrangler:Wake(inst)
    if self.instances[inst] then
       self:SendToList(inst, self.updaters)
    end
end

function StateGraphWrangler:Sleep(inst, time_to_wait)
    if self.instances[inst] then
        local sleep_ticks = time_to_wait/GetTickTime()
        if sleep_ticks == 0 then sleep_ticks = 1 end

        local target_tick = math.floor(GetTick() + sleep_ticks) + 1
        local waiters = self.tickwaiters[target_tick]

        if not waiters then
            waiters = {}
            self.tickwaiters[target_tick] = waiters
        end
        self:SendToList(inst, waiters)
    end
end


function StateGraphWrangler:OnRemoveEntity(inst)
    if self.instances[inst.sg] then
        SGManager:RemoveInstance(inst.sg)
    end
end

function StateGraphWrangler:RemoveInstance(inst)
    --V2C: #legacycode: inst is inst.sg, yo! Pretty much
    --     everywhere in this file except OnRemoveEntity
    local old_list = self.instances[inst]
    if old_list ~= nil then
        old_list[inst] = nil
    end

    --V2C: If the sg removes itself, or its entity, during our event
    --     handling loop, then we need to drop any remaining events.
    inst:ClearBufferedEvents()

    --V2C: looks like this file was not maintained correctly,
    --     and instances are not always being moved to lists
    --     via :SendToList(...)
    --     so we'll just clear ourselves from everywhere possible
    self.instances[inst] = nil
    self.updaters[inst] = nil
    self.tickwaiters[inst] = nil
    self.hibernaters[inst] = nil
    self.haveEvents[inst] = nil
end

function StateGraphWrangler:AddInstance(inst, hibernate)
	self:SendToList(inst, hibernate and self.hibernaters or self.updaters)
end

function StateGraphWrangler:Update(current_tick)
    local waiters = self.tickwaiters[current_tick]
    if waiters then
        for k,v in pairs(waiters) do
            self.updaters[k] = true
        end
        self.tickwaiters[current_tick] = nil
    end

    local updaters = self.updaters
    self.updaters = {}

    TheSim:ProfilerPush("updaters")
    for k,v in pairs(updaters) do
        if not k.stopped and k.inst:IsValid() then -- NOTES(JBK): The k.stopped check is for the condition of iterating the loop causes the stategraph of another stategraph to go invalid.
            local prefab = k.inst.prefab
            if prefab ~= nil then
			     TheSim:ProfilerPush(k.inst.prefab)
            end
            local sleep_amount = k:Update()
            if prefab ~= nil then
                TheSim:ProfilerPop()
            end
            if sleep_amount then
                if sleep_amount > 0 then
                  self:Sleep(k, sleep_amount)
                else
                    self.updaters[k] = true
                end
            else
                self:Hibernate(k)
            end
        end
    end
    TheSim:ProfilerPop()

    self:UpdateEvents()
end

function StateGraphWrangler:UpdateEvents()
    local evs = self.haveEvents
    self.haveEvents = {}

    TheSim:ProfilerPush("events")
    for k,v in pairs(evs) do
        k:HandleEvents()
    end
    TheSim:ProfilerPop()
end

ActionHandler = Class(
    function(self, action, state, condition)

        self.action = action

        if type(state) == "string" then
            self.deststate = function(_) return state end
        else
            self.deststate = state
        end

        self.condition = condition
    end)

EventHandler = Class(
    function(self, name, fn)
        local info = debug.getinfo(3, "Sl")
        self.defline = string.format("%s:%d", info.short_src, info.currentline)
        assert (type(name) == "string")
        assert (type(fn) == "function")
        self.name = string.lower(name)
        self.fn = fn
    end)

TimeEvent = Class(
    function(self, time, fn)
        local info = debug.getinfo(3, "Sl")
        self.defline = string.format("%s:%d", info.short_src, info.currentline)
        assert (type(time) == "number")
        assert (type(fn) == "function")
        self.time = time
        self.fn = fn
    end)

function FrameEvent(frame, fn)
	return TimeEvent(frame * FRAMES, fn)
end

function SoundTimeEvent(time, sound_event)
    return TimeEvent(time, function(inst)
        inst.SoundEmitter:PlaySound(sound_event)
    end)
end

function SoundFrameEvent(frame, sound_event)
    return TimeEvent(frame * FRAMES, function(inst)
        inst.SoundEmitter:PlaySound(sound_event)
    end)
end

local function Chronological(a, b)
	return a.time < b.time
end

State = Class(
    function(self, args)
        local info = debug.getinfo(3, "Sl")
        self.defline = string.format("%s:%d", info.short_src, info.currentline)

        assert(args.name, "State needs name")
        self.name = args.name
        self.onenter = args.onenter
        self.onexit = args.onexit
        self.onupdate = args.onupdate
        self.ontimeout = args.ontimeout

        self.tags = {}
        if args.tags then
            for k, v in ipairs(args.tags) do
                self.tags[v] = true
            end
        end

		--#V2C #client_prediction
		if args.server_states ~= nil then
			--client player only
			self.server_states = {}
			for _, v in ipairs(args.server_states) do
				self.server_states[hash(v)] = true
			end
			self.forward_server_states = args.forward_server_states
		else
			--server player only
			self.no_predict_fastforward = args.no_predict_fastforward
		end

        self.events = {}
        if args.events ~= nil then
            for k,v in pairs(args.events) do
                assert(v:is_a(EventHandler), "non-EventHandler in event list")
                self.events[v.name] = v
            end
        end

        self.timeline = {}
        if args.timeline ~= nil then
            for k,v in ipairs(args.timeline) do
                assert(v:is_a(TimeEvent), "non-TimeEvent in timeline")
                table.insert(self.timeline, v)
            end
        end

		table.sort(self.timeline, Chronological)
	end)

function State:HandleEvent(sg, eventname, data)
	if type(data) ~= "table" or data.state == nil or data.state == self.name then
        local handler = self.events[eventname]
        if handler ~= nil then
            return handler.fn(sg.inst, data)
        end
    end
    return false
end

StateGraph = Class( function(self, name, states, events, defaultstate, actionhandlers)
    assert(name and type(name) == "string", "You must specify a name for this stategraph")
    local info = debug.getinfo(3, "Sl")
    self.defline = string.format("%s:%d", info.short_src, info.currentline)
    self.name = name
    self.defaultstate = defaultstate

    --reindex the tables
    self.actionhandlers = {}
    if actionhandlers then
        for k,v in pairs(actionhandlers) do
            assert( v:is_a(ActionHandler),"Non-action handler added in actionhandler table!")
            self.actionhandlers[v.action] = v
        end
    end
	for k,modhandlers in pairs(ModManager:GetPostInitData("StategraphActionHandler", self.name)) do
		for i,v in ipairs(modhandlers) do
			assert( v:is_a(ActionHandler),"Non-action handler added in mod actionhandler table!")
			self.actionhandlers[v.action] = v
		end
	end

    self.events = {}
    for k,v in pairs(events) do
        assert( v:is_a(EventHandler),"Non-event added in events table!")
        self.events[v.name] = v
    end
	for k,modhandlers in pairs(ModManager:GetPostInitData("StategraphEvent", self.name)) do
		for i,v in ipairs(modhandlers) do
			assert( v:is_a(EventHandler),"Non-event added in mod events table!")
			self.events[v.name] = v
		end
    end

    self.states = {}
    for k,v in pairs(states) do
        assert( v:is_a(State),"Non-state added in state table!")
        self.states[v.name] = v
    end
	for k,modhandlers in pairs(ModManager:GetPostInitData("StategraphState", self.name)) do
		for i,v in ipairs(modhandlers) do
			assert( v:is_a(State),"Non-state added in mod state table!")
			self.states[v.name] = v
		end
    end

	-- apply mods
	local modfns = ModManager:GetPostInitFns("StategraphPostInit", self.name)
	for i,modfn in ipairs(modfns) do
		modfn(self)
	end
end)

function StateGraph:__tostring()
    return "Stategraph : "..self.name--.. " (currentstate="..self.currentstate.name..":"..self.timeinstate..")"
end


StateGraphInstance = Class( function (self, stategraph, inst)
    self.sg = stategraph
    self.currentstate = nil
    self.timeinstate = 0
    self.lastupdatetime = 0
    self.timelineindex = nil
    self.laststate = nil
    self.bufferedevents={}
    self.inst = inst
	self.tags = {}
    self.statemem = {}
    self.mem = {}
    self.statestarttime = 0
end)

function StateGraphInstance:RenderDebugUI(ui, panel)
	-- Don't have a specific stategraph debugger for DebugNodeName, but viewing
	-- our History is pretty useful.
	if ui:Button("Open History for: ".. tostring(self.inst)) then
		local DebugNodes = require "dbui_no_package/debug_nodes"
		SetDebugEntity(self.inst)
		panel:PushNode(DebugNodes.DebugHistory())
	end
end

function StateGraphInstance:GetDebugTable()
	TheSim:ProfilerPush("[SGI] GetDebugTable")

	local ret = {
		name = self.sg.name,
		current = self.currentstate and self.currentstate.name or "<None>",
		ticks = math.floor(self:GetTimeInState() / FRAMES),
		tags = shallowcopy(self.tags),
		statemem = shallowcopy(self.statemem),
	}

	TheSim:ProfilerPop()

	return ret
end

function StateGraphInstance:__tostring()
    local str =  string.format([[sg="%s", state="%s", time=%2.2f]], self.sg.name, self.currentstate.name, GetTime() - self.statestarttime)
    str = str..[[, tags = "]]
    for k,v in pairs(self.tags) do
        str = str..tostring(k)..","
    end
    str = str..[["]]
    return str
end

function StateGraphInstance:GetTimeInState()
    return GetTime() - self.statestarttime
end

function StateGraphInstance:PlayRandomAnim(anims, loop)
    local idx = math.floor(math.random() * #anims)
    self.inst.AnimState:PlayAnimation(anims[idx+1], loop)
end

function StateGraphInstance:PushEvent(event, data)
    if data then
        data.state = self.currentstate.name
    else
        data = {state = self.currentstate.name}
    end
    table.insert(self.bufferedevents, {name=event, data=data})
end

function StateGraphInstance:IsListeningForEvent(event)
    return self.currentstate.events[event] ~= nil or self.sg.events[event] ~= nil
end

function StateGraphInstance:PreviewAction(bufferedaction)
    if self.sg.actionhandlers ~= nil then
        local handler = self.sg.actionhandlers[bufferedaction.action]
        if handler ~= nil then
            if handler.condition ~= nil and not handler.condition(self.inst) then
                return
            elseif handler.deststate ~= nil then
                local state = handler.deststate(self.inst, bufferedaction)
                if state ~= nil then
                    self:GoToState(state)
                    return true
                else
                    return
                end
            end
        elseif not bufferedaction.action.instant then
            self:GoToState("previewaction")
            return true
        end
    end

    self.inst:PerformPreviewBufferedAction()
    return true
end

function StateGraphInstance:StartAction(bufferedaction)
    if self.sg.actionhandlers then
        local handler = self.sg.actionhandlers[bufferedaction.action]
        if handler then
            if not handler.condition or handler.condition(self.inst) then
                if handler.deststate then
                    local state = handler.deststate(self.inst, bufferedaction)
                    if state then
						self.statemem.is_going_to_action_state = true
                        self:GoToState(state)

						--V2C: (#HACK?) skip frames for predicted actions
						if not (self.statemem.no_predict_fastforward or bufferedaction.options.no_predict_fastforward) then
							local playercontroller = self.inst.components.playercontroller
							if playercontroller ~= nil and playercontroller.remote_predicting and playercontroller.remote_authority then
								local dt = GetTickTime()
								self.inst.AnimState:SetTime(self.inst.AnimState:GetCurrentAnimationTime() + dt)
								self:FastForward(dt)
							end
						end
                    else
                        return
                    end
                else
                    self.inst:PerformBufferedAction()
                end

                return true
            end
        end
    end
end

function StateGraphInstance:HandleEvent(eventname, data)
	data = data or {}
	if not self.currentstate:HandleEvent(self, eventname, data) then
		local handler = self.sg.events[eventname]
		if handler ~= nil then
			handler.fn(self.inst, data)
		end
	end
end

function StateGraphInstance:HandleEvents()
    assert(self.currentstate ~= nil, "we are not in a state!")

    if self.inst:IsValid() then
        local buff_events = self.bufferedevents
        for k, event in ipairs(buff_events) do
			self:HandleEvent(event.name, event.data)
            if buff_events ~= self.bufferedevents then
                --V2C: This happens if ClearBufferedEvents() is called in a state handler
                return
            end
        end
    end

    self:ClearBufferedEvents()
end

function StateGraphInstance:ClearBufferedEvents()
    if #self.bufferedevents > 0 then
        self.bufferedevents = {}
    end
end

function StateGraphInstance:InNewState()
	return self.laststate ~= self.currentstate
end

--List with the quotes so the code is more searchable as tags
local SGTagsToEntTags =
{
    ["attack"] = true,
    ["autopredict"] = true,
    ["busy"] = true,
    ["dirt"] = true,
    ["doing"] = true,
    ["fishing"] = true,
    ["flight"] = true,
    ["hiding"] = true,
    ["idle"] = true,
    ["invisible"] = true,
    ["lure"] = true,
    ["moving"] = true,
    ["nibble"] = true,
    ["noattack"] = true,
    ["nopredict"] = true,
    ["pausepredict"] = true,
    ["sleeping"] = true,
    ["working"] = true,
    ["boathopping"] = true,
	["shouldautopausecontrollerinventory"] = true, --autopause even if "doing", see "openslingshotmods" state
}

function StateGraphInstance:HasState(statename)
    return self.sg.states[statename] ~= nil
end

function StateGraphInstance:GoToState(statename, params)
    local state = self.sg.states[statename]

    if not state then
		print (self.inst, "TRIED TO GO TO INVALID STATE", statename)
		return
    end
    --assert(state ~= nil, "State not found: " ..tostring(self.sg.name).."."..tostring(statename) )

    if self.currentstate ~= nil and self.currentstate.onexit ~= nil then
        self.currentstate.onexit(self.inst, statename)
    end

    -- Record stats
-- KAJ: TODO: commented out for now, what are we going to do with metrics?
--    if METRICS_ENABLED and self.inst == ThePlayer and self.currentstate and not IsAwayFromKeyBoard() then
--        local dt = GetTime() - self.statestarttime
--        self.currentstate.totaltime = self.currentstate.totaltime and (self.currentstate.totaltime + dt) or dt  -- works even if currentstate.time is nil
--        --print(self.currentstate.name," time in state= ", self.currentstate.totaltime)
--    end

    self.statemem = {}
	self.lasttags = self.tags
    self.tags = {}
    if state.tags ~= nil then
        for k, v in pairs(state.tags) do
            self.tags[k] = true
        end
    end
    if TheWorld.ismastersim or self.inst.Network == nil then
        for k, v in pairs(SGTagsToEntTags) do
            if self.tags[k] then
                self.inst:AddTag(k)
            else
                self.inst:RemoveTag(k)
            end
        end
    end

	--#V2C #client_prediction
	if TheWorld.ismastersim then
		self.no_predict_fastforward = state.no_predict_fastforward
	else
		self.server_states =
			self.currentstate ~= nil and
			self.currentstate.forward_server_states and
			self.currentstate.server_states or
			state.server_states
	end

    self.timeout = nil
    self.laststate = self.currentstate
    self.currentstate = state
    self.timeinstate = 0

    if self.currentstate.timeline ~= nil then
        self.timelineindex = 1
    else
        self.timelineindex = nil
    end

    if self.currentstate.onenter ~= nil then
        self.currentstate.onenter(self.inst, params)
    end

    self.inst:PushEvent("newstate", {statename = statename})

	self.lasttags = nil
    self.lastupdatetime = GetTime()
    self.statestarttime = self.lastupdatetime
    SGManager:OnEnterNewState(self)
end

function StateGraphInstance:AddStateTag(tag)
    self.tags[tag] = true
    if SGTagsToEntTags[tag] and (TheWorld.ismastersim or self.inst.Network == nil) then
        self.inst:AddTag(tag)
    end
end

function StateGraphInstance:RemoveStateTag(tag)
    self.tags[tag] = nil
    if SGTagsToEntTags[tag] and (TheWorld.ismastersim or self.inst.Network == nil) then
        self.inst:RemoveTag(tag)
    end
end

function StateGraphInstance:HasStateTag(tag)
	return self.tags[tag] == true
end

function StateGraphInstance:HasAnyStateTag(...)
	local tags = select(1, ...)
	if type(tags) == "table" then
		for i, v in ipairs(tags) do
			if self.tags[v] then
				return true
			end
		end
	else
		if self.tags[tags] then
			return true
		end
		for i = 2, select("#", ...) do
			if self.tags[select(i, ...)] then
				return true
			end
		end
	end
    return false
end

function StateGraphInstance:SetTimeout(time)
    SGManager:OnSetTimeout(self)
    self.timeout = time
end

function StateGraphInstance:UpdateState(dt)
    if not self.currentstate then
        return
    end

    self.timeinstate = self.timeinstate + dt
    local startstate = self.currentstate


    if self.timeout then
        self.timeout = self.timeout - dt
        if self.timeout < 0.0001 then --epsilon for floating point error
            self.timeout = nil
            if self.currentstate.ontimeout then
                self.currentstate.ontimeout(self.inst)
                if startstate ~= self.currentstate then
                    return
                end
            end
        end
    end

    while self.timelineindex and self.currentstate.timeline[self.timelineindex] and self.currentstate.timeline[self.timelineindex].time <= self.timeinstate do

		local idx = self.timelineindex
        self.timelineindex = self.timelineindex + 1
        if self.timelineindex > #self.currentstate.timeline then
            self.timelineindex = nil
        end

        local old_time = self.timeinstate
        local extra_time = self.timeinstate - self.currentstate.timeline[idx].time
        self.currentstate.timeline[idx].fn(self.inst)


        if startstate ~= self.currentstate or old_time > self.timeinstate then
            self:Update(extra_time)
            return 0
        end
    end

    if self.currentstate.onupdate ~= nil then
        self.currentstate.onupdate(self.inst, dt)
    end
end

--@V2C: should only be called from EntityScript:ReturnToScene (legacy behaviour)
--      this means OnStart is only triggered when exiting limbo
function StateGraphInstance:Start(hibernate)
	if not self.stopped then
		return
	elseif self.OnStart then
        self:OnStart()
    end
	self.stopped = nil
	SGManager:AddInstance(self, hibernate)
end

--@V2C: should only be called from EntityScript:RemoveFromScene (legacy behaviour)
--      this means OnStop is only triggered when entering limbo
function StateGraphInstance:Stop()
	if self.stopped then
		return
	end
    self:HandleEvents()
    if self.OnStop then
        self:OnStop()
    end
    self.stopped = true
    SGManager:RemoveInstance(self)
end

function StateGraphInstance:Update()
    local dt = 0
    if self.lastupdatetime then
        dt = GetTime() - self.lastupdatetime --+ GetTickTime()
    end
    self.lastupdatetime = GetTime()

    self:UpdateState(dt)

    local time_to_sleep = nil
    if self.timelineindex and self.currentstate.timeline and self.currentstate.timeline[self.timelineindex] then
        time_to_sleep = self.currentstate.timeline[self.timelineindex].time - self.timeinstate
    end


    if self.timeout and (not time_to_sleep or time_to_sleep > self.timeout) then
        time_to_sleep = self.timeout
    end

    if self.currentstate.onupdate then
        return 0
    elseif time_to_sleep then
        return time_to_sleep
    else
        return nil
    end
end

--------------------------------------------------------------------------
--#V2C #client_prediction

function StateGraphInstance:ServerStateMatches()
	--V2C: don't nil check self.server_states; should catch all errors during dev
	return self.inst.player_classified ~= nil and self.server_states[self.inst.player_classified.currentstate:value()]
end

--#V2C #hack: use sparingly... ^^""
function StateGraphInstance:FastForward(time)
	self.lastupdatetime = self.lastupdatetime - time
end

--------------------------------------------------------------------------
