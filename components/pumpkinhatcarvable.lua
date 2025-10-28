local PARTS =
{
	"reye",
	"leye",
	"mouth",
}
local PART_IDS = table.invert(PARTS)
local VARS_PER_TOOL = 9

local function _ValidateFaceData(self, doer, facedata)
	if facedata and doer and doer.components.inventory then
		local hastool = {}
		for toolid = 1, 3 do
			local tool = "pumpkincarver"..tostring(toolid)
			if doer.components.inventory:Has(tool, 1, true) then
				hastool[toolid] = true
			end
		end

		--remove parts that you don't have tools for
		local olddata = self:GetFaceData()
		for partid, part in ipairs(PARTS) do
			local variation = facedata[part]
			if variation and variation ~= olddata[part] then
				local toolid = math.ceil(variation / VARS_PER_TOOL)
				if not hastool[toolid] then
					facedata[part] = nil
				end
			end
		end

		if next(facedata) then
			local blanktest --can only have full face, or no face at all
			for partid, part in ipairs(PARTS) do
				local variation = facedata[part] or olddata[part] or 0
				local blankval = variation == 0
				if blankval == blanktest then
					return false
				end
				blanktest = not blankval
			end
			return true
		end
	end
	return false
end

local function interruptcarving(inst)
	local self = inst.components.pumpkinhatcarvable
	self:EndCarving(self.carver)
end

local PumpkinHatCarvable = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim

	self.collectfacedatafn = nil

	if not self.ismastersim then
		return inst
	end

	self.carver = nil
	self.range = 3
	self.onchangefacedatafn = nil
	self.onopenfn = nil
	self.onclosefn = nil

	self.onclosepopup = function(doer, data)
		if data.popup == POPUPS.PUMPKINHATCARVING then
			local facedata
			if data and data.args and #data.args > 0 then
				facedata = {}
				for partid, part in ipairs(PARTS) do
					facedata[part] = data.args[partid]
				end
			end
			self.onclosepumpkin(doer, facedata)
		end
	end
	self.onclosepumpkin = function(doer, facedata)
		if _ValidateFaceData(self, doer, facedata) then
			if self.onchangefacedatafn then
				self.onchangefacedatafn(self.inst, facedata)
			end
			if not (inst.components.inventoryitem and inst.components.inventoryitem:IsHeld() or inst:IsAsleep()) then
				local x, y, z = inst.Transform:GetWorldPosition()
				SpawnPrefab("pumpkincarving_shatter_fx").Transform:SetPosition(x, 1, z)
			end
		end
		self:EndCarving(doer)
	end

	inst:ListenForEvent("onputininventory", interruptcarving)
	inst:ListenForEvent("floater_startfloating", interruptcarving)
end)

PumpkinHatCarvable.PARTS = PARTS
PumpkinHatCarvable.PART_IDS = PART_IDS
PumpkinHatCarvable.VARS_PER_TOOL = VARS_PER_TOOL

function PumpkinHatCarvable:OnRemoveFromEntity()
	if self.ismastersim then
		self:EndCarving(self.carver)
		self.inst:RemoveEventCallback("onputininventory", interruptcarving)
		self.inst:RemoveEventCallback("floater_startfloating", interruptcarving)
	end
end
PumpkinHatCarvable.OnRemoveEntity = PumpkinHatCarvable.OnRemoveFromEntity

function PumpkinHatCarvable:GetFaceData()
	local data = {}
	if self.collectfacedatafn then
		self.collectfacedatafn(self.inst, data)
	end
	return data
end

function PumpkinHatCarvable:CanBeginCarving(doer)
	if self.carver == doer or doer.sg == nil or doer.sg:HasStateTag("busy") then
		return false
	elseif self.inst.components.burnable and self.inst.components.burnable:IsBurning() then
		return false, "BURNING"
	elseif self.carver then
		return false, "INUSE"
	elseif self.inst.components.equippable and self.inst.components.equippable:IsEquipped() then
		return false
	elseif self.inst.components.floater and self.inst.components.floater:IsFloating() then
		return false
	end
	return true
end

function PumpkinHatCarvable:BeginCarving(doer)
	if not self.ismastersim then
		return
	elseif self.carver == nil then
		self.carver = doer

		if self.inst.components.inventoryitem then
			self.inst.components.inventoryitem.canbepickedup = false
		end

		self.inst:ListenForEvent("onremove", self.onclosepumpkin, doer)
		self.inst:ListenForEvent("ms_closepopup", self.onclosepopup, doer)

		doer.sg:GoToState("pumpkincarving", { popup = POPUPS.PUMPKINHATCARVING, target = self.inst })

		self.inst:StartUpdatingComponent(self)

		if self.onopenfn then
			self.onopenfn(self.inst)
		end
		return true
	end
	return false
end

function PumpkinHatCarvable:EndCarving(doer)
	if not self.ismastersim then
		return
	elseif self.carver == doer and doer then
		self.inst:RemoveEventCallback("onremove", self.onclosepumpkin, doer)
		self.inst:RemoveEventCallback("ms_closepopup", self.onclosepopup, doer)

		self.carver = nil

		if self.inst.components.inventoryitem then
			self.inst.components.inventoryitem.canbepickedup = true
		end

		doer:PushEventImmediate("ms_endpumpkincarving")

		self.inst:StopUpdatingComponent(self)

		if self.onclosefn then
			self.onclosefn(self.inst)
		end
	end
end

--------------------------------------------------------------------------
--Check for auto-closing conditions
--------------------------------------------------------------------------

function PumpkinHatCarvable:OnUpdate(dt)
	if self.carver == nil then
		self.inst:StopUpdatingComponent(self)
	elseif not (self.carver:IsNear(self.inst, self.range) and CanEntitySeeTarget(self.carver, self.inst)) then
		self:EndCarving(self.carver)
	end
end

return PumpkinHatCarvable
