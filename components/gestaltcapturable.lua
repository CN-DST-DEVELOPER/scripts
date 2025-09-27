local function onenabled(self, enabled)
	--V2C: Recommended to explicitly add tag to prefab pristine state
	self.inst:AddOrRemoveTag("gestaltcapturable", enabled)
end

local GestaltCapturable = Class(function(self, inst)
	self.inst = inst
	self.level = 1
	self.enabled = true
	self.targeters = {}
	self.ontargetedfn = nil
	self.onuntargetedfn = nil
	self.oncapturedfn = nil

	self._onremovetargeter = function(obj) self:OnUntargeted(obj) end
end,
nil,
{
	enabled = onenabled,
})

function GestaltCapturable:OnRemoveFromEntity()
	self.inst:RemoveTag("gestaltcapturable")
end

function GestaltCapturable:SetEnabled(enabled)
	self.enabled = enabled
end

function GestaltCapturable:IsEnabled()
	return self.enabled
end

function GestaltCapturable:SetLevel(level)
	self.level = level
end

function GestaltCapturable:GetLevel()
	return self.level
end

function GestaltCapturable:SetOnCapturedFn(fn)
	self.oncapturedfn = fn
end

function GestaltCapturable:SetOnTargetedFn(fn)
	self.ontargetedfn = fn
end

function GestaltCapturable:SetOnUntargetedFn(fn)
	self.onuntargetedfn = fn
end

function GestaltCapturable:IsTargeted()
	return next(self.targeters) ~= nil
end

--called by gestaltcage component
function GestaltCapturable:OnTargeted(obj)
	if self.targeters[obj] == nil then
		local wastargeted = self:IsTargeted()
		self.targeters[obj] = true
		self.inst:ListenForEvent("onremove", self._onremovetargeter, obj)
		if not wastargeted then
			--print(string.format("[GestaltCapturable]: %s is now targeted.", tostring(self.inst)))
			if self.ontargetedfn then
				self.ontargetedfn(self.inst)
			end
			self.inst:PushEvent("gestaltcapturable_targeted")
		end
	end
end

--called by gestaltcage component
function GestaltCapturable:OnUntargeted(obj)
	if self.targeters[obj] then
		self.targeters[obj] = nil
		self.inst:RemoveEventCallback("onremove", self._onremovetargeter, obj)
		if not self:IsTargeted() then
			--print(string.format("[GestaltCapturable]: %s is no longer targeted.", tostring(self.inst)))
			if self.onuntargetedfn then
				self.onuntargetedfn(self.inst)
			end
			self.inst:PushEvent("gestaltcapturable_untargeted")
		end
	end
end

--called by gestaltcage component
function GestaltCapturable:OnCaptured(obj, doer)
	if doer then
		doer:PushEvent("gestaltcaptured", self.inst)
	end

	if self.oncapturedfn then
		self.oncapturedfn(self.inst, obj, doer)
	end
end

return GestaltCapturable
