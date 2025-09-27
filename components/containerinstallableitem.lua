local function topocket(inst, owner)
	local self = inst.components.containerinstallableitem
	if self._owner ~= owner then
		local self = inst.components.containerinstallableitem
		if self._owner and self._owner:IsValid() and self:IsValidContainer(self._owner) and not self.ignoreuninstall then
			self:OnUninstalled(self._owner.install_target or self._owner)
		end
		self._owner = owner
		if owner:IsValid() and self:IsValidContainer(owner) then
			self:OnInstalled(owner.install_target or owner)
		end
	end
end

local function toground(inst)
	local self = inst.components.containerinstallableitem
	if self._owner then
		if self._owner:IsValid() and self:IsValidContainer(self._owner) and not self.ignoreuninstall then
			self:OnUninstalled(self._owner.install_target or self._owner)
		end
		self._owner = nil
	end
end

--This is the closest event we have for when an item is removed from a slot but not dropped,
--e.g. when moving/swapping items
local function onexitlimbo(inst)
	local self = inst.components.containerinstallableitem
	if self._owner and not inst.components.inventoryitem:IsHeldBy(self._owner) then
		if self._owner:IsValid() and self:IsValidContainer(self._owner) and not self.ignoreuninstall then
			self:OnUninstalled(self._owner.install_target or self._owner)
		end
		self._owner = nil
	end
end

local ContainerInstallableItem = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.validcontainerfn = nil

	if self.ismastersim then
		--self.oninstalledfn = nil
		--self.onuninstalledfn = nil
		--self._owner = nil

		inst:ListenForEvent("onputininventory", topocket)
		inst:ListenForEvent("ondropped", toground)
		inst:ListenForEvent("exitlimbo", onexitlimbo)

		--When swapping items in slot, "exitlimbo" lets us handle the old item "uninstall" first.

		--This flag lets us disable "exitlimbo" so that the old item "uninstall" happens AFTER
		--the new item "install".  Useful for checking if we're just swapping the same part.

		--self.usedeferreduninstall = nil

		--flag used for letting us drop without triggering uninstall
		--self.ignoreuninstall = nil
	end
end)

--------------------------------------------------------------------------
--Common interface

function ContainerInstallableItem:SetValidContainerFn(fn)
	self.validcontainerfn = fn
end

function ContainerInstallableItem:IsValidContainer(containerinst)
	return self.validcontainerfn == nil or self.validcontainerfn(self.inst, containerinst)
end

function ContainerInstallableItem:GetValidOpenContainer(doer)
	local inventory = doer.replica.inventory
	local containers = inventory and inventory:GetOpenContainers() or nil
	if containers then
		for k in pairs(containers) do
			if (k.replica.container == nil or not k.replica.container:IsReadOnlyContainer()) and self:IsValidContainer(k) then
				return k
			end
		end
	end
end

--------------------------------------------------------------------------
--Server interface

function ContainerInstallableItem:SetInstalledFn(fn)
	self.oninstalledfn = fn
end

function ContainerInstallableItem:SetUninstalledFn(fn)
	self.onuninstalledfn = fn
end

function ContainerInstallableItem:SetUseDeferredUninstall(enable)
	if enable then
		if not self.usedeferreduninstall then
			self.usedeferreduninstall = true
			self.inst:RemoveEventCallback("exitlimbo", onexitlimbo)
		end
	elseif self.usedeferreduninstall then
		self.usedeferreduninstall = nil
		self.inst:ListenForEvent("exitlimbo", onexitlimbo)
	end
end

function ContainerInstallableItem:OnInstalled(target)
	print(tostring(target)..": +Installed "..tostring(self.inst))
	if self.oninstalledfn then
		self.oninstalledfn(self.inst, target)
	end
	target:PushEvent("containerinstalleditem", self.inst)
end

function ContainerInstallableItem:OnUninstalled(target)
	print(tostring(target)..": -Uninstalled "..tostring(self.inst))
	if self.onuninstalledfn then
		self.onuninstalledfn(self.inst, target)
	end
	target:PushEvent("containeruninstalleditem", self.inst)
end

--------------------------------------------------------------------------

return ContainerInstallableItem
