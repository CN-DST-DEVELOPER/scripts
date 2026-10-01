
local function onupgradetype(self, newtype, oldtype)
	if self:CanUpgrade() then
		if oldtype then
			self.inst:RemoveTag(oldtype.."_upgradeable")
		end
		if newtype then
			self.inst:AddTag(newtype.."_upgradeable")
		end
	end
end

local function onstage(self)
	self.inst:AddOrRemoveTag(self.upgradetype.."_upgradeable", self:CanUpgrade())
end

local Upgradeable = Class(function(self,inst)
	self.inst = inst
	self.onstageadvancefn = nil
	self.onupgradefn = nil
	self.upgradetype = UPGRADETYPES.DEFAULT

	self.stage = 1
	self.numstages = 3
	self.upgradesperstage = 5
	self.numupgrades = 0
end,
nil,
{
	upgradetype = onupgradetype,
	stage = onstage,
	numstages = onstage,
})

function Upgradeable:SetOnUpgradeFn(fn)
	self.onupgradefn = fn
end

function Upgradeable:SetCanUpgradeFn(fn)
	self.canupgradefn = fn
end

function Upgradeable:GetStage()
	return self.stage
end

function Upgradeable:SetStage(num)
	self.stage = num
end

function Upgradeable:AdvanceStage()
	self.stage = self.stage + 1
	self.numupgrades = 0

	if self.onstageadvancefn then
		return self.onstageadvancefn(self.inst)
	end
end

function Upgradeable:CanUpgrade()
	local not_at_max = self.stage and self.numstages and self.stage < self.numstages

	if self.canupgradefn then
		local can_upgrade, reason = self.canupgradefn(self.inst)
		if can_upgrade then
			return can_upgrade and not_at_max
		end

		return false, reason
	end

	return not_at_max
end

function Upgradeable:Upgrade(obj, upgrade_performer)
	self.numupgrades = self.numupgrades + obj.components.upgrader.upgradevalue

	if obj.components.stackable then
		obj.components.stackable:Get(1):Remove()
	else
		obj:Remove()
	end

	if self.onupgradefn then
		self.onupgradefn(self.inst, upgrade_performer, obj)
	end

	if self.numupgrades >= self.upgradesperstage then
		self:AdvanceStage()
	end

	return true
end

-- Save/Load
function Upgradeable:OnSave()
	local data = {}
	data.numupgrades = self.numupgrades
	data.stage = self.stage
	return data
end

function Upgradeable:OnLoad(data)
	self.numupgrades = data.numupgrades
	self.stage = data.stage
end

-- Debug
function Upgradeable:GetDebugString()
	local str = ""

	if self.upgradetype then
		str = str..string.format("Upgrade type: %s; ", self.upgradetype)
	end

	if self.stage then
		str = str..string.format("Current stage: %d", self.stage)
		if self.numstages then
			str = str..string.format(" / %d; ", self.numstages)
		else
			str = str.."; "
		end
	end

	if self.numupgrades and self.upgradesperstage then
		str = str..string.format("Upgrade Count: %d / %d", self.numupgrades, self.upgradesperstage)
	end

	return str
end

--
return Upgradeable