local easing = require("easing")

local SHAPE_NAMES =
{
	"arc",
	"circle",
	"crescent",
	"diamond",
	"heart",
	"hexagon",
	"square",
	"star",
	"triangle",	
}
local SHAPE_IDS = table.invert(SHAPE_NAMES)

local TOOL_SHAPES =
{
	pumpkincarver1 =
	{
		"circle",
		"arc",
		"heart",
	},
	pumpkincarver2 =
	{
		"square",
		"triangle",
		"diamond",
	},
	pumpkincarver3 =
	{
		"hexagon",
		"crescent",
		"star",
	},
}

local NIGHT_LIGHT_OVERRIDE = 0.12

--------------------------------------------------------------------------

local function Fill_OnUpdate(inst, dt)
	if inst._lightdelta > 0 then
		if inst._light <= 0 then
			local parent = inst.entity:GetParent()
			if parent and parent.highlightchildren then
				table.removearrayvalue(parent.highlightchildren, inst)
			end
			inst.AnimState:SetHighlightColour()
			--inst.AnimState:SetLightOverride(0.5)
			inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		end
		inst._light = math.min(1, inst._light + inst._lightdelta * dt)
	else--if inst._lightdelta < 0 then
		inst._light = math.max(0, inst._light + inst._lightdelta * dt)
		if inst._light <= 0 then
			local parent = inst.entity:GetParent()
			if parent and parent.highlightchildren and not table.contains(parent.highlightchildren, inst) then
				table.insert(parent.highlightchildren, inst)
			end
			inst._light = nil
			inst._lightdelta = nil
			inst.AnimState:SetAddColour(0, 0, 0, 0)
			inst.AnimState:SetMultColour(1, 1, 1, 1)
			inst.AnimState:SetLightOverride(0)
			inst.AnimState:ClearBloomEffectHandle()
			inst.components.updatelooper:RemoveOnUpdateFn(Fill_OnUpdate)
			return
		end
	end

	inst._s = inst._s + dt * 8
	local s = 6.5 + math.sin(inst._s) * 14
	inst._t = inst._t + dt * s
	inst._a = inst._a + dt * s * 0.7
	local a = 0.7 + math.sin(inst._a) * 0.1
	local add = a + (math.sin(inst._t) + 1) / 2 * 0.2
	local mult = (1 - add) / 2
	local fade = easing.inOutQuad(inst._light, 0, 1, 1)
	add = add * fade
	mult = 1 - (1 - mult) * fade
	inst.AnimState:SetAddColour(add, add, 0.6 * add, 0)
	inst.AnimState:SetMultColour(mult, mult, mult, 1)
	inst.AnimState:SetLightOverride(0.5 * fade)
end

local function Cut_OnIsDay(inst, isday, instant)
	if isday then
		if inst.isfill then
			if inst._light then
				inst._lightdelta = -1
				if instant then
					inst._lightdelta = -math.huge
					Fill_OnUpdate(inst, 0)
				else
					inst._lightdelta = -1
				end
			end
		else
			inst.AnimState:ClearBloomEffectHandle()
			inst.AnimState:SetLightOverride(0)
			inst.AnimState:SetAddColour(0, 0, 0, 0)
		end
	elseif inst.isfill then
		if inst._light == nil then
			inst._light = 0
			inst.components.updatelooper:AddOnUpdateFn(Fill_OnUpdate)
		end
		if instant then
			inst._lightdelta = math.huge
			Fill_OnUpdate(inst, 0)
		else
			inst._lightdelta = 1
		end
	else
		inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.AnimState:SetLightOverride(0.3)
		inst.AnimState:SetAddColour(0.2, 0.1, 0, 0)
	end
end

local function Cut_OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()
	if parent and parent.highlightchildren then
		table.removearrayvalue(parent.highlightchildren, inst)
	end
end

local function CreateCut(owner, shape, rot, isfill, rnd1, rnd2, rnd3)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("farm_plant_pumpkin")
	inst.AnimState:SetBuild("farm_plant_pumpkin")

	inst.entity:SetParent(owner.entity)

	if isfill then
		inst.isfill = true
		inst._t = rnd1 * TWOPI
		inst._s = rnd2 * TWOPI
		inst._a = rnd2 * TWOPI
		inst:AddComponent("updatelooper")
		inst.AnimState:PlayAnimation(string.format("cut_fill_%s_%d", shape, rot))
		--highlightchildren managed by Cut_OnIsDay
	else
		inst.AnimState:PlayAnimation(string.format("cut_%s_%d", shape, rot))
		table.insert(owner.highlightchildren, inst)
	end

	inst:WatchWorldState("isday", Cut_OnIsDay)
	Cut_OnIsDay(inst, TheWorld.state.isday, true)

	inst.OnRemoveEntity = Cut_OnRemoveEntity

	return inst
end

--------------------------------------------------------------------------

local function AddCutData(tbl, shape, rot, x, y)
	local n = #tbl
	tbl[n + 1] = SHAPE_IDS[shape]
	tbl[n + 2] = rot
	tbl[n + 3] = x
	tbl[n + 4] = y
end

local BOUNDARY_X1 = -50
local BOUNDARY_X2 = 40
local BOUNDARY_Y = -55
local BOUNDARY_R = 65
local PADDING = 1
--keep in sync @pumpkincarvingscreen.lua
local function _IsOnPumpkin(x, y)
	local x1 = BOUNDARY_X1
	local x2 = BOUNDARY_X2
	local y1 = -BOUNDARY_Y --y-axis inverted compared to pumpkincarvingscreen.lua
	local r = BOUNDARY_R + PADDING
	if x > x1 - PADDING and x < x2 + PADDING and y > y1 - r and y < y1 + r then
		return true
	end
	r = r * r
	return distsq(x, y, x1, y1) < r
		or distsq(x, y, x2, y1) < r
end

local function _DoCut(shape, rot, x, y, pass, tbl, owner, swapsymbol, swapframe, offsetx, offsety, rnd1, rnd2, rnd3)
	if not _IsOnPumpkin(x, y) then
		print(string.format("PumpkinCarvable::_DoCut(\"%s\", %d, %d, %d) dropped out of range.", shape, rot, x, y))
		return
	end

	x = x + offsetx
	y = y + offsety

	if owner.highlightchildren == nil then
		owner.highlightchildren = {}
	end

	local cut = CreateCut(owner, shape, rot, pass > 1, rnd1, rnd2, rnd3)
	--parenting and highlightchildren done in CreateCut
	cut.Follower:FollowSymbol(owner.GUID, swapsymbol, x, y, 0, true, nil, swapframe)
	table.insert(tbl, cut)
end

local function ApplyCuts(cutdata, cuts, owner, swapsymbol, swapframe, offsetx, offsety)
	for i = 1, #cuts do
		cuts[i]:Remove()
		cuts[i] = nil
	end
	cutdata = string.len(cutdata) > 0 and DecodeAndUnzipString(cutdata) or nil
	if type(cutdata) == "table" and #cutdata > 0 then
		offsetx = offsetx or 0
		offsety = offsety or 0
		local rnd1, rnd2, rnd3 = math.random(), math.random(), math.random()
		for pass = 1, 2 do
			for i = 1, #cutdata, 4 do
				_DoCut(SHAPE_NAMES[cutdata[i]], cutdata[i + 1], cutdata[i + 2], cutdata[i + 3], pass, cuts, owner, swapsymbol, swapframe, offsetx, offsety, rnd1, rnd2, rnd3)
			end
		end
		return true
	end
	return false
end

local function _ValidateCutData(doer, cutdata)
	if doer and doer.components.inventory then
		cutdata = string.len(cutdata) > 0 and DecodeAndUnzipString(cutdata) or nil
		if type(cutdata) == "table" and #cutdata > 0 then
			local supported_shapes = {}
			for i = 1, 3 do
				local tool = "pumpkincarver"..tostring(i)
				if doer.components.inventory:Has(tool, 1, true) then
					for _, v in ipairs(TOOL_SHAPES[tool]) do
						supported_shapes[SHAPE_IDS[v]] = true
					end
				end
			end
			local valid_cutdata = {}
			local valid_idx = 1
			local max_idx = TUNING.HALLOWEEN_PUMPKINCARVER_MAX_CUTS * 4
			for i = 1, math.min(max_idx, #cutdata), 4 do
				if supported_shapes[cutdata[i]] then
					for j = 0, 3 do
						valid_cutdata[valid_idx + j] = cutdata[i + j]
					end
					valid_idx = valid_idx + 4
				end
			end
			if #valid_cutdata > 0 then
				return ZipAndEncodeString(valid_cutdata)
			end
		end
	end
	return ""
end

--------------------------------------------------------------------------

local function OnCutDataDirty_Client(inst)
	inst.components.pumpkincarvable:DoRefreshCutData()
end

local function OnEquipped_Server(inst, data)
	local self = inst.components.pumpkincarvable
	if data and data.owner then
		if self.swapinst then
			self.swapinst:Remove()
			self.swapinst = nil
		end
		local cutdata = self.cutdata:value()
		if string.len(cutdata) > 0 then
			self.swapinst = SpawnPrefab("pumpkincarving_swap_fx")
			self.swapinst.entity:SetParent(data.owner.entity)
			self.swapinst:SetCutData(cutdata)
		end
	end
end

local function OnUnequipped_Server(inst, data)
	local self = inst.components.pumpkincarvable
	if self.swapinst then
		self.swapinst:Remove()
		self.swapinst = nil
	end
end

local function OnIsDay_Server(self, isday)
	self.inst.AnimState:SetLightOverride(not isday and string.len(self.cutdata:value()) > 0 and NIGHT_LIGHT_OVERRIDE or 0)
end

local PumpkinCarvable = Class(function(self, inst)
	self.inst = inst

	self.ismastersim = TheWorld.ismastersim
	self.cuts = {}
	self.cutdata = net_string(inst.GUID, "pumpkincarvable.cutdata", "cutdatadirty")

	if not self.ismastersim then
		inst:ListenForEvent("cutdatadirty", OnCutDataDirty_Client)

		return
	end

	self.swapinst = nil
	self.carver = nil
	self.range = 3
	self.onopenfn = nil
	self.onclosefn = nil

	self.onclosepopup = function(doer, data)
		if data.popup == POPUPS.PUMPKINCARVING then
			self.onclosepumpkin(doer, data and data.args and data.args[1] or nil)
		end
	end
	self.onclosepumpkin = function(doer, cutdata)
		if type(cutdata) == "string" then
			self.cutdata:set(_ValidateCutData(doer, cutdata))
			if not TheNet:IsDedicated() and self:DoRefreshCutData() then
				local x, y, z = inst.Transform:GetWorldPosition()
				SpawnPrefab("pumpkincarving_shatter_fx").Transform:SetPosition(x, 1, z)
			end
			if self.ismastersim then
				OnIsDay_Server(self, TheWorld.state.isday)
			end
		end
		self:EndCarving(doer)
	end

	inst:ListenForEvent("equipped", OnEquipped_Server)
	inst:ListenForEvent("unequipped", OnUnequipped_Server)
	self:WatchWorldState("isday", OnIsDay_Server)
	OnIsDay_Server(self, TheWorld.state.isday)
end)

PumpkinCarvable.AddCutData = AddCutData
PumpkinCarvable.ApplyCuts = ApplyCuts
PumpkinCarvable.SHAPE_NAMES = SHAPE_NAMES
PumpkinCarvable.SHAPE_IDS = SHAPE_IDS
PumpkinCarvable.TOOL_SHAPES = TOOL_SHAPES
PumpkinCarvable.NIGHT_LIGHT_OVERRIDE = NIGHT_LIGHT_OVERRIDE

function PumpkinCarvable:OnRemoveFromEntity()
	if self.ismastersim then
		self:EndCarving(self.carver)
		self.inst:RemoveEventCallback("equipped", OnEquipped_Server)
		self.inst:RemoveEventCallback("unequipped", OnUnequipped_Server)
		self:StopWatchingWorldState("isday", OnIsDay_Server)
	else
		self.inst:RemoveEventCallback("cutdatadirty", OnCutDataDirty_Client)
	end
	for i, v in ipairs(self.cuts) do
		v:Remove()
	end
	if self.swapinst then
		self.swapinst:Remove()
		self.swapinst = nil
	end
end
PumpkinCarvable.OnRemoveEntity = PumpkinCarvable.OnRemoveFromEntity

function PumpkinCarvable:GetCutData()
	return self.cutdata:value()
end

function PumpkinCarvable:CanBeginCarving(doer)
	if self.carver == doer or doer.sg == nil or doer.sg:HasStateTag("busy") then
		return false
	elseif self.inst.components.burnable and self.inst.components.burnable:IsBurning() then
		return false, "BURNING"
	elseif self.carver then
		return false, "INUSE"
	end
	return true
end

function PumpkinCarvable:BeginCarving(doer)
	if not self.ismastersim then
		return
	elseif self.carver == nil then
		self.carver = doer

		self.inst:ListenForEvent("onremove", self.onclosepumpkin, doer)
		self.inst:ListenForEvent("ms_closepopup", self.onclosepopup, doer)

		doer.sg:GoToState("pumpkincarving", { target = self.inst })

		self.inst:StartUpdatingComponent(self)

		if self.onopenfn then
			self.onopenfn(self.inst)
		end
		return true
	end
	return false
end

function PumpkinCarvable:EndCarving(doer)
	if not self.ismastersim then
		return
	elseif self.carver == doer and doer then
		self.inst:RemoveEventCallback("onremove", self.onclosepumpkin, doer)
		self.inst:RemoveEventCallback("ms_closepopup", self.onclosepopup, doer)

		self.carver = nil

		doer.sg:HandleEvent("ms_endpumpkincarving")

		self.inst:StopUpdatingComponent(self)

		if self.onclosefn then
			self.onclosefn(self.inst)
		end
	end
end

function PumpkinCarvable:DoRefreshCutData()
	return ApplyCuts(self.cutdata:value(), self.cuts, self.inst, "follow_cut")
end

function PumpkinCarvable:LoadCutData(cutdata)
	self.cutdata:set(cutdata)
	if not TheNet:IsDedicated() then
		self:DoRefreshCutData()
	end
	if self.ismastersim then
		OnIsDay_Server(self, TheWorld.state.isday)
	end
end

function PumpkinCarvable:OnSave()
	local cutdata = self.cutdata:value()
	return string.len(cutdata) > 0 and { cuts = cutdata } or nil
end

function PumpkinCarvable:OnLoad(data, newents)
	if data and type(data.cuts) == "string" then
		self:LoadCutData(data.cuts)
	end
end

function PumpkinCarvable:TransferComponent(newinst)
	if not self.ismastersim then
		return
	end
	local pumpkincarvable = newinst.components.pumpkincarvable
	if pumpkincarvable then
		pumpkincarvable.cutdata:set(self.cutdata:value())
		if not TheNet:IsDedicated() then
			pumpkincarvable:DoRefreshCutData()
		end
		if pumpkincarvable.ismastersim then
			OnIsDay_Server(pumpkincarvable, TheWorld.state.isday)
		end
	end
end

--------------------------------------------------------------------------
--Check for auto-closing conditions
--------------------------------------------------------------------------

function PumpkinCarvable:OnUpdate(dt)
	if self.carver == nil then
		self.inst:StopUpdatingComponent(self)
	elseif not (self.carver:IsNear(self.inst, self.range) and CanEntitySeeTarget(self.carver, self.inst)) then
		self:EndCarving(self.carver)
    end
end

return PumpkinCarvable
