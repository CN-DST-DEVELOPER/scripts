local function onsweepable(self, value)
    self.inst:AddOrRemoveTag("sweepable", value)
end

local Sweepable = Class(function(self, inst)
    self.inst = inst

    self.sweepable = true
    self.onsweepfn = nil
end,
nil,
{
    sweepable = onsweepable
})

function Sweepable:SetEnabled(sweepable)
    self.sweepable = sweepable
end

function Sweepable:SetOnSweepedFn(fn)
    self.onsweepfn = fn
end

function Sweepable:Sweep(doer, sweeper)
    if sweeper and sweeper.components.sweeper then
        sweeper.components.sweeper:OnSweep(self.inst, doer)
    end
    if self.onsweepfn ~= nil then
        self.onsweepfn(self.inst, doer, sweeper)
    end
    return true
end

return Sweepable
