local function onenabled(self, enabled)
	self.inst:AddOrRemoveTag("vase", enabled)
end

local function UpdateLight(inst, self)
	local pct = GetTaskRemaining(self.wilttask) / TUNING.ENDTABLE_FLOWER_WILTTIME
	local radius = 1.5 + 1.5 * pct
	local intensity = 0.4 + 0.4 * pct
	local falloff = math.min(1, 0.8 + (1 - pct))
	self:PushLight(radius, intensity, falloff)
end

local function OnExitLimbo(inst)
	local self = inst.components.vase
	if not self.light then
		--V2C: need to do this because by default, exitlimbo re-enables Light.
		self:PushLight(0)
	elseif self.lighttask == nil then
		self.lighttask = self.inst:DoPeriodicTask(TUNING.ENDTABLE_LIGHT_UPDATE + math.random(), UpdateLight, nil, self)
		UpdateLight(self.inst, self)
	end
end

local function OnEnterLimbo(inst)
	local self = inst.components.vase
	if self.lighttask then
		self.lighttask:Cancel()
		self.lighttask = nil
		self:PushLight(0)
	end
end

local Vase = Class(function(self, inst)
    self.inst = inst
    self.deleteitemonaccept = true
    self.enabled = true
	self.fresh = false
	self.light = false
	self.flowerid = nil
	self.wilttask = nil
	self.lighttask = nil
	self.onupdateflowerfn = nil
	self.onupdatelightfn = nil
	self.ondecorate = nil --backward compatible name

	-- NOTE: Recommended to add to pristine state, for optimization.
	--self.inst:AddTag("vase")

	inst:ListenForEvent("exitlimbo", OnExitLimbo)
end,
nil,
{
    enabled = onenabled,
})

function Vase:OnRemoveFromEntity()
    self.inst:RemoveTag("vase")
	if self.wilttask then
		self.wilttask:Cancel()
	end
	if self.lighttask then
		self.lighttask:Cancel()
	end
	self.inst:RemoveEventCallback("exitlimbo", OnExitLimbo)
end

function Vase:SetOnUpdateFlowerFn(fn)
	self.onupdateflowerfn = fn
end

function Vase:SetOnUpdateLightFn(fn)
	self.onupdatelightfn = fn
end

function Vase:SetOnDecorateFn(fn)
	self.ondecorate = fn
end

function Vase:Enable()
    self.enabled = true
end

function Vase:Disable()
    self.enabled = false
end

function Vase:HasFlower()
	return self.flowerid ~= nil
end

function Vase:HasFreshFlower()
	return self.fresh
end

function Vase:GetTimeToWilt()
	return self.wilttask and GetTaskRemaining(self.wilttask) or nil
end

function Vase:PushLight(radius, intensity, falloff)
	if self.onupdatelightfn then
		self.onupdatelightfn(self.inst, radius, intensity, falloff)
	end
end

function Vase:PushFlower(flowerid, fresh)
	if self.onupdateflowerfn then
		self.onupdateflowerfn(self.inst, flowerid, fresh)
	end
end

local function OnWilt(inst, self)
	self.wilttask = nil
	self:WiltFlower()
end

--wilt_time 0 => wilted regardless of light or not
--  otherwise, -non-lightsource ignores wilt_time
--             -lightsource uses wilt_time or TUNING.ENDTABLE_FLOWER_WILTTIME if nil
function Vase:SetFlower(flowerid, wilt_time)
	self.flowerid = flowerid

	if self.wilttask then
		self.wilttask:Cancel()
		self.wilttask = nil
	end
	if self.lighttask then
		self.lighttask:Cancel()
		self.lighttask = nil
	end
	self.inst:RemoveEventCallback("enterlimbo", OnEnterLimbo)

	if wilt_time == 0 then
		self.fresh = false
		self.light = false
		self:PushLight(0)
	elseif not TUNING.VASE_FLOWER_SWAPS[flowerid].lightsource then
		self.fresh = true
		self.light = false
		self:PushLight(0)
	else
		self.fresh = true
		self.light = true
		self.inst:ListenForEvent("enterlimbo", OnEnterLimbo)
		self.wilttask = self.inst:DoTaskInTime(wilt_time or TUNING.ENDTABLE_FLOWER_WILTTIME, OnWilt, self)
		if self.inst:IsInLimbo() then
			self:PushLight(0)
		else
			self.lighttask = self.inst:DoPeriodicTask(TUNING.ENDTABLE_LIGHT_UPDATE + math.random(), UpdateLight, nil, self)
			UpdateLight(self.inst, self)
		end
	end

	self:PushFlower(flowerid, self.fresh)
end

function Vase:WiltFlower()
	if self.fresh then
		self.fresh = false
		self.light = false
		self.inst:RemoveEventCallback("enterlimbo", OnEnterLimbo)

		if self.wilttask then
			self.wilttask:Cancel()
			self.wilttask = nil
		end

		if self.lighttask then
			self.lighttask:Cancel()
			self.lighttask = nil
			self:PushLight(0)
		end

		self:PushFlower(self.flowerid, false)
	end
end

function Vase:ClearFlower()
	if self.flowerid then
		self.flowerid = nil
		self.fresh = false
		self.light = false
		self.inst:RemoveEventCallback("enterlimbo", OnEnterLimbo)

		if self.wilttask then
			self.wilttask:Cancel()
			self.wilttask = nil
		end
		if self.lighttask then
			self.lighttask:Cancel()
			self.lighttask = nil
			self:PushLight(0)
		end

		self:PushFlower(nil)
	end
end

function Vase:Decorate(giver, item)
	if item == nil or not self.enabled then
		return false
	end

	local flowerid = TUNING.VASE_FLOWER_MAP[item.prefab]
	if flowerid == nil then
		return false
	end
	flowerid = flowerid[math.random(#flowerid)]

	if item.components.stackable and item.components.stackable:IsStack() then
		item = item.components.stackable:Get()
    else
        item.components.inventoryitem:RemoveFromOwner(true)
    end

	local wilt_time = item.components.perishable and item.components.perishable:GetPercent() * TUNING.ENDTABLE_FLOWER_WILTTIME

    if self.deleteitemonaccept then
        item:Remove()
    end

	self:SetFlower(flowerid, wilt_time)

    if self.ondecorate ~= nil then
		self.ondecorate(self.inst, giver, item, flowerid)
    end

    return true
end

function Vase:OnSave()
	return self.flowerid and
	{
		flower = self.flowerid,
		wilt = (not self.fresh and 0)
			or (self.wilttask and math.floor(GetTaskRemaining(self.wilttask)))
			or nil,
	}
end

function Vase:OnLoad(data)--, ents)
	if data.flower then
		self:SetFlower(data.flower, data.wilt) --nil wilt_time supported
	end
end

function Vase:LongUpdate(dt)
	if self.wilttask then
		local t = GetTaskRemaining(self.wilttask)
		if t > dt then
			self.wilttask:Cancel()
			self.wilttask = self.inst:DoTaskInTime(t - dt, OnWilt, self)
			if self.lighttask then
				UpdateLight(self.inst, self)
			end
		else
			self:WiltFlower()
		end
	end
end

function Vase:GetDebugString()
    return "enabled: "..tostring(self.enabled)
end

return Vase
