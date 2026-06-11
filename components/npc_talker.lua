
local NPC_Talker = Class(function(self, inst)
    self.inst = inst
    self.queue = {}
    self.soundqueue = {}
    self.default_chatpriority = CHATPRIORITIES.NOCHAT

    --self.speaktime = nil

    --self.inst:ListenForEvent("done_npc_talk", function(inst) self:checknextline() end)
end)

function NPC_Talker:Say(lines, override, stompable, sound)
    -- override means it wipes out the old queue
    -- stompable means anything else will remove it. And if there's anything queued already it will be ignored


    if override or self.stompable then
       self.queue = {}
       self.soundqueue = {}
       self.stompable = false
    end

    if stompable and #self.queue > 0 then
        return
    end

    if lines then

        table.insert(self.soundqueue,sound or false)

        if type(lines) ~= "table" then
            table.insert(self.queue,lines)
        else
            for i,line in ipairs(lines) do
                if i > 1 then
                    table.insert(self.soundqueue, false)
                end
                table.insert(self.queue, line)
            end
        end
    end

    if stompable then
        self.stompable = true
    end

end

function NPC_Talker:Chatter(strtbl, index, chatpriority, override, stompable, sound)
    if override or self.stompable then
        self.queue = {}
        self.soundqueue = {}
        self.stompable = false
    end

    if stompable and #self.queue > 0 then
        return
    end

    if strtbl then
        local table_entries = strtbl:split(".")
        local string_data = STRINGS
        for _, entry in ipairs(table_entries) do
            string_data = string_data[entry]
            if string_data == nil then
                return
            end
        end

        chatpriority = chatpriority or self.default_chatpriority
        if index ~= nil or type(string_data) == "string" then
            -- If an index was given, or our entry only has one line, just queue up that one line.
            table.insert(self.queue, {strtbl, index or 0, chatpriority})
            table.insert(self.soundqueue, sound or false)
        else
            -- If no index was given, and we have multiple lines, queue up all of them
            -- to play in sequence.
            for i, _ in ipairs(string_data) do
                table.insert(self.queue, {strtbl, i, chatpriority})
                table.insert(self.soundqueue, (i == 1 and sound) or false)
            end
        end
    end

    if stompable then
        self.stompable = true
    end
end

function NPC_Talker:HasLines()
    return #self.queue > 0
end

function NPC_Talker:ResetQueue()
    self.queue = {}
    self.soundqueue = {}
end

function NPC_Talker:DoNextLine()
    if self:HasLines() then
        local queue_item = self.queue[1]

        if type(queue_item) == "table" then
            -- The Line object might get used with Say, so we need to filter those over too.
            if queue_item.message then
                self.inst.components.talker:Say({queue_item}, self.speaktime)
            else
                self.inst.components.talker:Chatter(queue_item[1], queue_item[2], self.speaktime, nil, queue_item[3])
            end
        else
            self.inst.components.talker:Say(queue_item)
        end

        if self.soundqueue[1] and type(self.soundqueue[1]) == "string" then
            self.inst.SoundEmitter:PlaySound(self.soundqueue[1])
        end
        table.remove(self.soundqueue, 1)
        table.remove(self.queue, 1)
    end
end

-- backwards compat, because these functions used to be lowercase :,)
NPC_Talker.haslines = NPC_Talker.HasLines
NPC_Talker.resetqueue = NPC_Talker.ResetQueue
NPC_Talker.donextline = NPC_Talker.DoNextLine

return NPC_Talker