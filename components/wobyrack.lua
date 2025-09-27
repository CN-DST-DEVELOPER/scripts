local DryingRack = require("components/dryingrack")

local WobyRack = Class(DryingRack, function(self, inst)
	local container = SpawnPrefab("woby_rack_container").components.container
	container.inst.entity:SetParent(inst.entity)

	DryingRack._ctor(self, inst, container)
end)

function WobyRack:_dbg_print(...)
	print("WobyRack:", ...)
end

return WobyRack
