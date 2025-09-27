local Counter = Class(function(self, inst)
    self.inst = inst

    self.counters = {}
    self.donotsave = {}
end)

function Counter:GetCount(countername)
    return self.counters[countername] or 0
end

function Counter:Set(countername, value)
    self.counters[countername] = value
end

function Counter:Clear(countername)
    self.counters[countername] = nil
end

function Counter:DoDelta(countername, delta)
    local counter = self.counters[countername] or 0

    counter = counter + delta

    if counter == 0 then
        self.counters[countername] = nil
    else
        self.counters[countername] = counter
    end
end

function Counter:Increment(countername, magnitude)
    local delta = magnitude or 1
    self:DoDelta(countername, delta)
end

function Counter:Decrement(countername, magnitude)
    local delta = -(magnitude or 1)
    self:DoDelta(countername, delta)
end

function Counter:IncrementToZero(countername, magnitude)
    local count = self:GetCount(countername)
    if count < 0 then
        local delta = math.min(-count, magnitude or 1)
        self:DoDelta(countername, delta)
    end
end

function Counter:DecrementToZero(countername, magnitude)
    local count = self:GetCount(countername)
    if count > 0 then
        local delta = math.max(-count, -(magnitude or 1))
        self:DoDelta(countername, delta)
    end
end

function Counter:DoNotSave(countername) -- Should be a one way operation for a temporary counter.
    self.donotsave[countername] = true
end

function Counter:OnSave()
    if next(self.counters) == nil then
        return
    end

    local counters = {}
    for k, v in pairs(self.counters) do
        if not self.donotsave[k] then
            counters[k] = v
        end
    end

    return {
        counters = counters,
    }
end

function Counter:OnLoad(data)
    if not data then
        return
    end

    self.counters = data.counters or self.counters
end

function Counter:GetDebugString()
    if next(self.counters) == nil then
        return nil
    end

    local values = {}
    for countername, value in pairs(self.counters) do
        table.insert(values, {countername = countername, value = value})
    end
    table.sort(values, function(a, b) return a.countername < b.countername end)

    for i, v in ipairs(values) do
        values[i] = string.format("%s : %g", v.countername, v.value)
    end

    return string.format("%d total\n  %s", #values, table.concat(values, "\n  "))
end

return Counter
