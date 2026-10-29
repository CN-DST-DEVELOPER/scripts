local Sweeper = Class(function(self, inst)
    self.inst = inst

    self.sweepsound = nil -- yotr_2023/common/pillow_hit_petals
end)

function Sweeper:SetSweepSound(sweepsound)
    self.sweepsound = sweepsound
end

function Sweeper:OnSweep(sweepable, doer)
    if self.sweepsound then
        self.inst.SoundEmitter:PlaySound(self.sweepsound)
    end
end

return Sweeper
