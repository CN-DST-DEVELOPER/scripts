local function OnEntitySleep(inst)
    local prophider = inst.components.prophider
    if prophider == nil then
        return
    end

    prophider.sleepstate = true
end

local function OnEntityWake(inst)
    local prophider = inst.components.prophider
    if prophider == nil then
        return
    end

    prophider.sleepstate = nil
end


local PropHider = Class(function(self, inst)
    self.inst = inst

    self.hideupdate_duration = 6
    self.hideupdate_variance = 1

    --self.propcreationfn = nil
    --self.onvisiblefn = nil
    --self.willunhidefn = nil
    --self.onunhidefn = nil
    --self.onhidefn = nil

    --self.prop = nil
    --self.counter = nil
end)


function PropHider:SetPropCreationFn(fn)
    self.propcreationfn = fn
end

function PropHider:SetOnVisibleFn(fn)
    self.onvisiblefn = fn
end

function PropHider:SetWillUnhideFn(fn)
    self.willunhidefn = fn
end

function PropHider:SetOnUnhideFn(fn)
    self.onunhidefn = fn
end

function PropHider:SetOnHideFn(fn)
    self.onhidefn = fn
end

function PropHider:IsEntitySleepWithProp()
    return self.sleepstate
end

function PropHider:GenerateHideTime()
    return self.hideupdate_duration + self.hideupdate_variance * (math.random() * 2 - 1)
end

function PropHider:ClearHideTask()
    if self.hide_task ~= nil then
        self.hide_task:Cancel()
        self.hide_task = nil
    end
end

local function WillUnhide_Bridge(inst)
    local prophider = inst.components.prophider
    if prophider == nil then
        return
    end

    prophider:CheckWillUnhideFn()
end

function PropHider:CheckWillUnhideFn()
    if self.willunhidefn then
        local data = self.willunhidefn(self.inst)
        if data ~= nil then
            self:ShowFromProp()
            if self.onunhidefn then
                self.onunhidefn(self.inst, data)
            end
            return
        end
    end

    self:ClearHideTask()
    local reschedule = false
    if self.counter then
        if not self:IsEntitySleepWithProp() then
            self.counter = self.counter - 1
            if self.counter > 0 then
                reschedule = true
            else
                self.counter = nil
                self:ShowFromProp()
            end
        end
    else
        reschedule = true
    end
    if reschedule then
        self.hide_task = self.inst:DoTaskInTime(self:GenerateHideTime(), WillUnhide_Bridge)
    end
end

function PropHider:HideWithProp(duration, counter)
    if self.hiding then
        return
    end
    self.hiding = true

    if duration == nil then
        duration = self:GenerateHideTime()
    end

    self.inst:RemoveFromScene()
    self.inst:ListenForEvent("entitysleep", OnEntitySleep)
    self.inst:ListenForEvent("entitywake", OnEntityWake)

    self:ClearHideTask()
    self.hide_task = self.inst:DoTaskInTime(duration, WillUnhide_Bridge)
    self.counter = counter or 10

    if self.prop then
        if self.prop:IsValid() then
            self.prop:Remove()
        end
        self.prop = nil
    end

    if self.propcreationfn then
        local prop = self.propcreationfn(self.inst)
        if prop then
            self.prop = prop
            prop.persists = false -- Do not save props always generate them.
        end
    end

    if self.onhidefn then
        self.onhidefn(self.inst)
    end
end

function PropHider:ShowFromProp()
    if not self.hiding then
        return
    end
    self.hiding = nil

    self.inst:RemoveEventCallback("entitysleep", OnEntitySleep)
    self.inst:RemoveEventCallback("entitywake", OnEntityWake)
    self:ClearHideTask()

    self.inst:ReturnToScene()

    if self.onvisiblefn then
        self.onvisiblefn(self.inst)
    end

    if self.prop and self.prop:IsValid() then
		self.prop:PushEvent("propreveal", self.inst)
    end
    self.prop = nil
end

function PropHider:OnSave()
    if self.hide_task == nil then
        return nil
    end

    local hidetime = GetTaskRemaining(self.hide_task)
    if hidetime <= 0 then
        return nil
    end

    return {
        hidetime = hidetime,
        counter = self.counter, -- Safe to be nil for save and load.
    }
end

function PropHider:OnLoad(data)
    if data == nil or data.hidetime == nil then
        return
    end

    self:HideWithProp(data.hidetime, data.counter)
end

function PropHider:GetDebugString()
    return string.format("Counters: %d, Time for counter: %.1f", self.counter or 0, self.hide_task and GetTaskRemaining(self.hide_task) or 0)
end

return PropHider
