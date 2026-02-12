-- This component is for overriding some behaviour in playerspawner for the inst.migrationpets handling.
local MigrationPetsOverrider = Class(function(self, inst)
    self.inst = inst

    --self.getoffsetfromfn = nil
    --self.onsetpositionfn = nil
end)

function MigrationPetsOverrider:SetOffsetFromFn(fn)
    self.getoffsetfromfn = fn
end

function MigrationPetsOverrider:GetOffsetFrom(x, y, z)
    local ox, oy, oz = 0, 0, 0
    if self.getoffsetfromfn then
        ox, oy, oz = self.getoffsetfromfn(self.inst, x, y, z)
    end
    return ox, oy, oz
end

return MigrationPetsOverrider
