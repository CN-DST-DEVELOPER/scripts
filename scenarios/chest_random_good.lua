chestfunctions = require("scenarios/chestfunctions")


local function GetLoot()

	local items =
	{
		{
			item = "magic_blueprint",
		},
		{
			item = "cutgrass",
			count = math.random(10, 20),
		},
		{
			item = "log",
			count = math.random(10, 20),
		},
		{
			item = "twigs",
			count = math.random(10, 20),
		},
		{
			item = "rocks",
			count = math.random(10, 20),
		},
		{
			item = "goldnugget",
			count = math.random(10, 20),
		},
		{
			item = "tallbirdegg",
		},
		{
			item = "meat",
			count = math.random(6, 12),
		},
		{
			item = "goldenshovel",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.SHOVEL_USES * .25), TUNING.SHOVEL_USES)) end
		},
		{
			item = "goldenaxe",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.AXE_USES * .25), TUNING.AXE_USES)) end
		},
		{
			item = "hammer",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.HAMMER_USES * .25), TUNING.HAMMER_USES)) end
		},
		{
			item = "bugnet",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.BUGNET_USES * .25), TUNING.BUGNET_USES)) end
		},
		{
			item = "fishingrod",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.FISHINGROD_USES * .25), TUNING.FISHINGROD_USES)) end
		},

		{
			item = "beefalohat",
			initfn = function(inst) inst.components.fueled:InitializeFuelLevel(TUNING.BEEFALOHAT_PERISHTIME*(.5 + math.random()*.25)) end
		},
		{
			item = "trunkvest_summer",
			initfn = function(inst) inst.components.fueled:InitializeFuelLevel(TUNING.TRUNKVEST_PERISHTIME*(.5 + math.random()*.25)) end
		},
		{
			item = "tophat",
			initfn = function(inst) inst.components.fueled:InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME*(.5 + math.random()*.25)) end
		},
		{
			item = "spear",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.SPEAR_USES * .25), TUNING.SPEAR_USES)) end
		},
		{
			item = "tentaclespike",
			initfn = function(inst) inst.components.finiteuses:SetUses(math.random( math.floor(TUNING.SPIKE_USES * .25), TUNING.SPIKE_USES)) end
		},
		{
			item = "armorwood",
		},
		{
			item = "armorgrass",
		},
		{
			item = "houndstooth",
			count = math.random(10,20),
		},
		{
			item = "boomerang",
		},
	}

	local loottable = {}

	for k = 1, math.random(6,9) do
		local idx = math.random(#items)
		table.insert(loottable, items[idx])
		table.remove(items, idx)
	end

	return loottable
end

local function OnCreate(inst, scenariorunner)
	chestfunctions.AddChestItems(inst, GetLoot())
end

return
{
	OnCreate = OnCreate
}
