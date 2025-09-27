local LunarHailBuildup = Class(function(self, inst)
    self.inst = inst

    self.buildupmax = 1
    self.buildupcurrent = 0
    self.workleft = 0
    self.totalworkamount = TUNING.LUNARHAIL_BUILDUP_TOTAL_WORK_AMOUNT_MEDIUM
    self.moonglassamount = TUNING.LUNARHAIL_BUILDUP_MOONGLASS_AMOUNT_MEDIUM
    --self.ignorelunarhailticks = nil

    self:WatchWorldState("islunarhailing", self.OnIsLunarHailing)
    self.inst:DoTaskInTime(0, function() -- NOTES(JBK): LoadPostPass without regard to save data.
        self:OnIsLunarHailing(TheWorld.state.islunarhailing)
    end)
end)


function LunarHailBuildup:OnRemoveFromEntity()
    self:StopTickTask()
    self.inst:RemoveTag("LunarBuildup")
    UpdateLunarHailBuildup(self.inst)
end


function LunarHailBuildup:SetOnStartIsLunarHailingFn(fn)
    self.onstartislunarhailingfn = fn
end

function LunarHailBuildup:SetOnStopIsLunarHailingFn(fn)
    self.onstopislunarhailingfn = fn
end

function LunarHailBuildup:IsBuildupWorkable()
    return self.workleft > 0
end

function LunarHailBuildup:SetTotalWorkAmount(totalworkamount)
    self.totalworkamount = totalworkamount
    self.workleft = math.min(self.workleft, totalworkamount)
end

function LunarHailBuildup:SetMoonGlassAmount(moonglassamount)
    self.moonglassamount = moonglassamount
end

function LunarHailBuildup:GetBuildupPercent()
    return self.buildupcurrent / self.buildupmax
end

function LunarHailBuildup:SetBuildupPercent(percent)
    self:DoBuildupDelta(self.buildupmax * percent - self.buildupcurrent)
end

function LunarHailBuildup:SetIgnoreLunarHailTicks(ignorelunarhailticks)
    if self.ignorelunarhailticks == ignorelunarhailticks then
        return
    end
    
    if self.lunarhailtick_task ~= nil then
        if ignorelunarhailticks then
            if self.onstopislunarhailingfn then
                self.onstopislunarhailingfn(self.inst)
            end
        else
            if self.onstartislunarhailingfn then
                self.onstartislunarhailingfn(self.inst)
            end
        end
    end
    self.ignorelunarhailticks = ignorelunarhailticks
end



function LunarHailBuildup:DoLunarHailTick(buildingup)
    if buildingup and (self.inst.components.rainimmunity ~= nil or self.ignorelunarhailticks) then
        return
    end

    local amount
    if buildingup then
        amount = TUNING.LUNARHAIL_BUILDUP_TICK_TIME * TUNING.LUNARHAIL_BUILDUP_RATE
    else
        amount = -(TUNING.LUNARHAIL_BUILDUP_DECAY_TICK_TIME * TUNING.LUNARHAIL_BUILDUP_DECAY_RATE)
    end

    self:DoBuildupDelta(amount)
end

local function DoLunarHailTick_Bridge(inst, self, buildingup)
    self:DoLunarHailTick(buildingup)
end

function LunarHailBuildup:StopTickTask()
    if self.lunarhailtick_task ~= nil then
        self.lunarhailtick_task:Cancel()
        self.lunarhailtick_task = nil
    end
end
function LunarHailBuildup:StartBuildupTask()
    self.lunarhailtick_task = self.inst:DoPeriodicTask(TUNING.LUNARHAIL_BUILDUP_TICK_TIME, DoLunarHailTick_Bridge, math.random() * TUNING.LUNARHAIL_BUILDUP_TICK_TIME, self, true)
end
function LunarHailBuildup:StartDecayTask()
    self.lunarhailtick_task = self.inst:DoPeriodicTask(TUNING.LUNARHAIL_BUILDUP_DECAY_TICK_TIME, DoLunarHailTick_Bridge, math.random() * TUNING.LUNARHAIL_BUILDUP_DECAY_TICK_TIME, self, false)
end


function LunarHailBuildup:OnIsLunarHailing(islunarhailing)
    self:StopTickTask()
    if islunarhailing then
        if self.buildupcurrent < self.buildupmax then
            self:StartBuildupTask()
        end
        if self.onstartislunarhailingfn then
            self.onstartislunarhailingfn(self.inst)
        end
    else
        if self.buildupcurrent > 0 then
            self:StartDecayTask()
        end
        if self.onstopislunarhailingfn then
            self.onstopislunarhailingfn(self.inst)
        end
    end
end



function LunarHailBuildup:DoWorkToRemoveBuildup(workcount, doer)
    self.workleft = math.clamp(self.workleft - workcount, 0, self.totalworkamount)
    if self.workleft == 0 then
        self:DropRewards()
        self:OnWorkFinished()
        self:StopTickTask()
        if TheWorld.state.islunarhailing then
            self:StartBuildupTask()
        end
    end
    self.inst:PushEvent("lunarhailbuildupworked", {doer = doer})
end

function LunarHailBuildup:DoAllRemainingWorkToRemoveBuildup(doer)
    if self.workleft > 0 then
        self:DoWorkToRemoveBuildup(self.workleft, doer)
    end
end



function LunarHailBuildup:DropRewards(mult)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local launchspeed = math.max(self.inst:GetPhysicsRadius(0), 2)
    local todropcount = math.floor(self.moonglassamount * (mult or 1))
    local upgradeodds = Lerp(TUNING.LUNARHAIL_BUILDUP_MOONGLASS_REWARDS_CHARGED_CHANCE_MIN, TUNING.LUNARHAIL_BUILDUP_MOONGLASS_REWARDS_CHARGED_CHANCE_MAX, self.buildupcurrent)
    for i = 1, todropcount do
        local moonglass_prefab = (math.random() < upgradeodds) and "moonglass_charged" or "moonglass"
        local moonglass = SpawnPrefab(moonglass_prefab)
        moonglass.Transform:SetPosition(x, y, z)
        Launch(moonglass, self.inst, launchspeed)
    end
end


LunarHailBuildup.OnWorked_Bridge = function(inst, data)
    if data and data.workleft and data.workleft == 0 then
        local lunarhailbuildup = inst.components.lunarhailbuildup
        if lunarhailbuildup then
            lunarhailbuildup:DropRewards(TUNING.LUNARHAIL_BUILDUP_MOONGLASS_REWARDS_DESTRUCTION_MULT)
            lunarhailbuildup:OnWorkFinished()
        end
    end
end


function LunarHailBuildup:OnWorkFinished()
    self.inst:RemoveEventCallback("worked", self.OnWorked_Bridge)
    self.workleft = 0
    self.inst:RemoveTag("LunarBuildup")
    if self.inst:IsValid() then
        self.inst:PushEvent("lunarhailbuildupworkablestatechanged")
        self:DoBuildupDelta(-self.buildupcurrent)
    end
end


function LunarHailBuildup:WorkInit()
    self.workleft = self.totalworkamount
    self.inst:AddTag("LunarBuildup")
    self.inst:ListenForEvent("worked", self.OnWorked_Bridge)
    self.inst:PushEvent("lunarhailbuildupworkablestatechanged")
end


function LunarHailBuildup:DoBuildupDelta(delta)
    local oldbuildup = self.buildupcurrent
    local buildupcurrent = math.clamp(self.buildupcurrent + delta, 0, self.buildupmax)

    if oldbuildup ~= buildupcurrent then
        self.buildupcurrent = buildupcurrent
        if buildupcurrent > oldbuildup then
            if buildupcurrent == self.buildupmax and self.workleft == 0 then
                self:StopTickTask()
                self:WorkInit()
            end
        else
            if buildupcurrent == 0 and self.workleft > 0 then
                self:StopTickTask()
                -- No rewards for passive buildup removal.
                self:OnWorkFinished()
            end
        end
        if self.inst:IsValid() then
            self.inst:PushEvent("lunarhailbuildupdelta", { oldpercent = oldbuildup / self.buildupmax, newpercent = self.buildupcurrent / self.buildupmax, })
        end
    else
        self:StopTickTask()
    end
end



function LunarHailBuildup:OnSave()
    local data = {}
    if self.workleft > 0 then
        data.workleft = self.workleft
    end
    if self.buildupcurrent > 0 then
        data.buildupcurrent = self.buildupcurrent
    end
    return data
end

function LunarHailBuildup:OnLoad(data)
    if data ~= nil then
        if data.workleft ~= nil then
            self:WorkInit()
            self.workleft = math.min(data.workleft, self.totalworkamount)
        end
        if data.buildupcurrent ~= nil and data.buildupcurrent ~= self.buildupcurrent then
            self:DoBuildupDelta(data.buildupcurrent - self.buildupcurrent)
        end
    end
end



function LunarHailBuildup:GetDebugString()
    return string.format("Buildup: %2.2f / %2.2f, Workleft: %d, NextTick: %.1f", self.buildupcurrent, self.buildupmax, self.workleft, GetTaskRemaining(self.lunarhailtick_task))
end

return LunarHailBuildup
