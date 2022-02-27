local GroundTiles = require("worldtiledefs")

local FarmTiller = Class(function(self, inst)
    self.inst = inst
end)

function FarmTiller:Till(pt, doer)
    if TheWorld.Map:CanTillSoilAtPoint(pt.x, 0, pt.z, false) then
		TheWorld.Map:CollapseSoilAtPoint(pt.x, 0, pt.z)
        SpawnPrefab("farm_soil").Transform:SetPosition(pt:Get())
        return true
    end
    return false
end

return FarmTiller
