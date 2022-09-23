ChattyNode = Class(BehaviourNode, function(self, inst, chatlines, child, delay, rand_delay, enter_delay, enter_delay_rand)
    BehaviourNode._ctor(self, "ChattyNode", {child})

    self.inst = inst
    self.chatlines = chatlines
    self.nextchattime = 0
	self.delay = delay
	self.rand_delay = rand_delay

	self.enter_delay = enter_delay
	self.enter_delay_rand = enter_delay_rand
end)

function ChattyNode:Visit()
    local child = self.children[1]
    child:Visit()
	local prev_status = self.status
    self.status = child.status

    if self.status == RUNNING then
        local t = GetTime()

		if prev_status ~= RUNNING then
			-- allow for an initial delay when entering the node, use this for things like Wander where you stay in the state for a long time and frequently enter it
			self.nextchattime = t + (self.enter_delay or 0) + (self.enter_delay_rand ~= nil and math.random() * self.enter_delay_rand or 0) - FRAMES
		end

        if self.nextchattime == nil or t > self.nextchattime then
            if type(self.chatlines) == "function" then
                local str = self.chatlines(self.inst)
				if str ~= nil then
					if self.inst.components.npc_talker then
						self.inst.components.npc_talker:Say(str,nil,true)
					else
						self.inst.components.talker:Say(str)
					end
				end
            elseif type(self.chatlines) == "table" then
                --legacy, will only show on host
                local str = self.chatlines[math.random(#self.chatlines)]
                self.inst.components.talker:Say(str)
            else
                --Will be networked if talker:MakeChatter() was initialized
                local strtbl = STRINGS[self.chatlines]
                if strtbl ~= nil then
                    local strid = math.random(#strtbl)
                    self.inst.components.talker:Chatter(self.chatlines, strid)
                end
            end
            self.nextchattime = t + (self.delay or 10) + math.random() * (self.rand_delay or 10)
        end
        if self.nextchattime ~= nil then
            self:Sleep(self.nextchattime - t)
        end
    end
end

