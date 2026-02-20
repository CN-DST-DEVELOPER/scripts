--Overrides locomotor.runspeed to achieve a speed mult that doesn't stack with mount speed.
--Assumes players do not set locomotor.runspeed dynamically otherwise.
--Supports predicted speed mults.

local SourceModifierList = require("util/sourcemodifierlist")

local function OnInit(inst, self)
	self.inittask = nil
	self:TryRecacheBaseSpeed_Internal()
end

local function OnDirty(inst)
	inst.components.playerspeedmult:ApplyRunSpeed_Internal()
end

local PlayerSpeedMult = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.multcap = nil
	self._predictedmults = SourceModifierList(inst, nil, nil, OnDirty)
	self._cappedpredictedmults = SourceModifierList(inst, nil, nil, OnDirty)

	if self.ismastersim then
		self._mults = SourceModifierList(inst, nil, nil, OnDirty)
		self._cappedmults = SourceModifierList(inst, nil, nil, OnDirty)
		self.inittask = inst:DoStaticTaskInTime(0, OnInit, self)
	end
end)

--------------------------------------------------------------------------

function PlayerSpeedMult:AttachClassified(classified)
	self.classified = classified
	self.ondetachclassified = function() self:DetachClassified() end
	self.inst:ListenForEvent("onremove", self.ondetachclassified, classified)
end

function PlayerSpeedMult:DetachClassified()
	self.classified = nil
	self.ondetachclassified = nil
end

function PlayerSpeedMult:SetClassified(classified)
	assert(self.ismastersim)
	self.classified = classified
end

--------------------------------------------------------------------------

function PlayerSpeedMult:OnRemoveFromEntity()
	self._predictedmults:Reset()
	self._cappedpredictedmults:Reset()

	if self.ismastersim then
		self._mults:Reset()
		self._cappedmults:Reset()

		if self.inittask then
			self.inittask:Cancel()
			self.inittask = nil
		end
	end
end

function PlayerSpeedMult:SetSpeedMultCap(cap)
	assert(cap == nil or cap >= 0)
	self.multcap = cap
end

--------------------------------------------------------------------------
--Helper fns

local function _set_speed_mult(self, list, source, m)
	if EntityScript.is_instance(source) then
		list:SetModifier(source, m)
	else
		list:SetModifier(self.inst, m, source)
	end
end

local function _remove_speed_mult(self, list, source)
	if EntityScript.is_instance(source) then
		list:RemoveModifier(source)
	else
		list:RemoveModifier(self.inst, source)
	end
end

local function _basespeed(self)
	return self.classified and self.classified.psm_basespeed:value() or TUNING.WILSON_RUN_SPEED
end

local function _servermult(self)
	return (self._mults and self._mults:Get())
		or (self.classified and self.classified.psm_servermult:value())
		or 1
end

local function _cappedservermult(self)
	return (self._cappedmults and self._cappedmults:Get())
		or (self.classified and self.classified.psm_cappedservermult:value())
		or 1
end

local function _predictedmult(self)
	return self._predictedmults:Get()
end

local function _cappedpredictedmult(self)
	return self._cappedpredictedmults:Get()
end

--------------------------------------------------------------------------

--V2C: call this often to somewhat support legacy mods that might still be dynamically setting locomotor.runspeed
function PlayerSpeedMult:TryRecacheBaseSpeed_Internal()
	if self.ismastersim and not (
		self._mults:HasAnyModifiers() or
		self._cappedmults:HasAnyModifiers() or
		self._predictedmults:HasAnyModifiers() or
		self._cappedpredictedmults:HasAnyModifiers()
	) then
		self.classified.psm_basespeed:set(self.inst.components.locomotor.runspeed)
	end
end

function PlayerSpeedMult:SetSpeedMult(source, m)
	if self.ismastersim then
		self:TryRecacheBaseSpeed_Internal()
		_set_speed_mult(self, self._mults, source, m)
		--NOTE: dirty callbacks trigger b4 we set netvar; use helper fn to get value safely
		self.classified.psm_servermult:set(self._mults:Get())
	end
end

function PlayerSpeedMult:RemoveSpeedMult(source)
	if self.ismastersim then
		_remove_speed_mult(self, self._mults, source)
		--NOTE: dirty callbacks trigger b4 we set netvar; use helper fn to get value safely
		self.classified.psm_servermult:set(self._mults:Get())
	end
end

function PlayerSpeedMult:SetCappedSpeedMult(source, m)
	if self.ismastersim then
		self:TryRecacheBaseSpeed_Internal()
		_set_speed_mult(self, self._cappedmults, source, m)
		--NOTE: dirty callbacks trigger b4 we set netvar; use helper fn to get value safely
		self.classified.psm_cappedservermult:set(self._cappedmults:Get())
	end
end

function PlayerSpeedMult:RemoveCappedSpeedMult(source)
	if self.ismastersim then
		_remove_speed_mult(self, self._cappedmults, source)
		--NOTE: dirty callbacks trigger b4 we set netvar; use helper fn to get value safely
		self.classified.psm_cappedservermult:set(self._cappedmults:Get())
	end
end

function PlayerSpeedMult:SetPredictedSpeedMult(source, m)
	_set_speed_mult(self, self._predictedmults, source, m)
end

function PlayerSpeedMult:RemovePredictedSpeedMult(source)
	_remove_speed_mult(self, self._predictedmults, source)
end

function PlayerSpeedMult:SetCappedPredictedSpeedMult(source, m)
	_set_speed_mult(self, self._cappedpredictedmults, source, m)
end

function PlayerSpeedMult:RemoveCappedPredictedSpeedMult(source)
	_remove_speed_mult(self, self._cappedpredictedmults, source)
end

--Also called on clients via player_classified when netvars are dirty
function PlayerSpeedMult:ApplyRunSpeed_Internal()
	local locomotor = self.inst.components.locomotor
	if locomotor then
		if self.ismastersim or self._predictedmults:HasAnyModifiers() or self._cappedpredictedmults:HasAnyModifiers() then
			local mult = _servermult(self) * _predictedmult(self)
			local cappedmult = _cappedservermult(self) * _cappedpredictedmult(self)
			local totalmult = mult * cappedmult
			local effectivemult = totalmult * locomotor:GetSpeedMultiplier()
			local capped = self.multcap ~= nil and effectivemult > self.multcap
			--NOTE: there won't be division by zero since we assert that multcap is not less than 0
			local adjustedmult = capped and mult * math.max(1, cappedmult * self.multcap / effectivemult) or totalmult
			local basespeed = _basespeed(self)
			local speed = basespeed * adjustedmult
			local propname = self.ismastersim and "runspeed" or "predictrunspeed"
			locomotor[propname] = speed --for searching: locomotor.runspeed = speed; locomotor.predictrunspeed = speed;
			self:_dbg_print(string.format("%s = %.2f <== %.2f x %.2f%s", propname, speed, basespeed, totalmult, capped and string.format(" (capped @ %.2f)", adjustedmult) or ""))
		else
			locomotor.predictrunspeed = nil
			self:_dbg_print("predictrunspeed = nil")
		end
	end
end

--------------------------------------------------------------------------

function PlayerSpeedMult:_dbg_print(...)
	if BRANCH == "dev" then
		print("[PlayerSpeedMult]:", ...)
	end
end

function PlayerSpeedMult:GetDebugString()
	return string.format("server=%.2f, predicted=%.2f, cappedserver=%.2f, cappedpredicted=%.2f, cap=%s, basespeed=%.2f",
		_servermult(self),
		_predictedmult(self),
		_cappedservermult(self),
		_cappedpredictedmult(self),
		self.multcap and string.format("%.2f", self.multcap) or "<none>",
		_basespeed(self))
end

return PlayerSpeedMult
