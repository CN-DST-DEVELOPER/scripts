local SlingshotMods = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	--self.isloading = nil
end)

--------------------------------------------------------------------------
--Common interface

function SlingshotMods:CanBeOpenedBy(doer)
	if not (doer.components.skilltreeupdater and doer.components.skilltreeupdater:IsActivated("walter_slingshot_modding")) then
		return false
	end
	--[[local equippable = self.inst.replica.equippable
	if equippable and equippable:IsEquipped() then
		return false
	end]]
	local inventoryitem = self.inst.replica.inventoryitem
	if not (inventoryitem and inventoryitem:IsGrandOwner(doer)) then
		return false
	end
	return true
end

--------------------------------------------------------------------------
--Server interface

function SlingshotMods:IsLoading()
	if not self.ismastersim then
		return
	end
	return self.isloading or false
end

function SlingshotMods:HasPartName(name)
	if not self.ismastersim then
		return
	elseif self.containerinst == nil then
		return false
	end
	local success, num_found = self.containerinst.components.container:Has(name, 1)
	return success
end

function SlingshotMods:HasAnyParts()
	if not self.ismastersim then
		return
	end
	return self.containerinst ~= nil and not self.containerinst.components.container:IsEmpty()
end

function SlingshotMods:GetPartBuildAndSymbol(slot)
	if not self.ismastersim then
		return
	elseif self.containerinst == nil then
		return
	end
	slot =
		(slot == "band" and 1) or
		(slot == "frame" and 2) or
		(slot == "handle" and 3) or
		nil
	if slot then
		local part = self.containerinst.components.container:GetItemInSlot(slot)
		if part then
			return part.prefab, part.swap_build, part.swap_symbol
		end
	end
end

function SlingshotMods:CheckRequiredSkillsForPlayer(player)
	if not self.ismastersim then
		return
	elseif self.containerinst then
		local skilltreeupdater = player.components.skilltreeupdater
		local container = self.containerinst.components.container
		for i = 1, container:GetNumSlots() do
			local part = container:GetItemInSlot(i)
			if part and part.REQUIRED_SKILL and not (skilltreeupdater and skilltreeupdater:IsActivated(part.REQUIRED_SKILL)) then
				return false
			end
		end
	end
	return true
end

local function doclose(inst)
	inst.components.slingshotmods:Close()
end

function SlingshotMods:CreateContainer_Internal()
	if not self.ismastersim then
		return
	elseif self.containerinst == nil then
		self.containerinst = SpawnPrefab("slingshotmodscontainer")
		self.containerinst.entity:SetParent(self.inst.entity)
		self.containerinst.Network:SetClassifiedTarget(self.containerinst)
		self.containerinst.install_target = self.inst

		--self.inst:ListenForEvent("equipped", doclose)
		self.inst:ListenForEvent("ondropped", doclose)

		self.opener = nil
	end
end

local function transferinstall(part, newslingshot)
	part.components.containerinstallableitem:OnInstalled(newslingshot)
end

function SlingshotMods:TransferPartsTo(other) --other is also a slingshotmod component
	if not self.ismastersim then
		return
	elseif self.containerinst and other.containerinst == nil then
		--self.inst:RemoveEventCallback("equipped", doclose)
		self.inst:RemoveEventCallback("ondropped", doclose)

		other.containerinst = self.containerinst
		other.containerinst.entity:SetParent(other.inst.entity)
		other.containerinst.install_target = other.inst
		self.containerinst = nil

		--other.inst:ListenForEvent("equipped", doclose)
		other.inst:ListenForEvent("ondropped", doclose)

		other.containerinst.components.container:ForEachItem(transferinstall, other.inst)

		if self.opener then
			self.inst:StopUpdatingComponent(self)
			other.inst:StartUpdatingComponent(other)
			other.opener = self.opener
			self.opener = nil
			other.containerinst.Network:SetClassifiedTarget(other.opener)
		end
	end
end

function SlingshotMods:Open(opener)
	if not self.ismastersim then
		return
	elseif opener then
		if self.containerinst == nil then
			self:CreateContainer_Internal()
		elseif self.containerinst.components.container:IsOpenedBy(opener) then
			return true --it's already open, just return success
		end

		if self.containerinst.components.container:CanOpen() and
			--[[not (	self.inst.components.equippable and
					self.inst.components.equippable:IsEquipped()
				) and]]
			self.inst.components.inventoryitem and
			self.inst.components.inventoryitem:GetGrandOwner() == opener
		then
			if self.opener == nil then
				self.inst:StartUpdatingComponent(self)
			end
			self.opener = opener
			self.containerinst.Network:SetClassifiedTarget(opener)
			self.containerinst.components.container:Open(opener)
			return true
		end
	end
	return false
end

function SlingshotMods:Close(opener)
	if not self.ismastersim then
		return
	elseif self.containerinst == nil or (opener and opener ~= self.opener) then
		return false
	end
	self.containerinst.components.container:Close(opener)
	self.containerinst.Network:SetClassifiedTarget(self.containerinst)
	if self.opener then
		self.inst:StopUpdatingComponent(self)
		opener = self.opener
		self.opener = nil
		opener:PushEvent("ms_slingshotmodsclosed")
	end
	return true
end

function SlingshotMods:OnUpdate(dt)
	if not (self.opener.sg and self.opener.sg:HasStateTag("moddingslingshot")) then
		self:Close()
	end
end

function SlingshotMods:DropAllPartsWithoutUninstalling()
	if not self.ismastersim then
		return
	elseif self.containerinst then
		local pos = self.inst:GetPosition()
		local container = self.containerinst.components.container
		for i = 1, container:GetNumSlots() do
			local part = container:GetItemInSlot(i)
			if part then
				part.components.containerinstallableitem.ignoreuninstall = true
				container:DropItemBySlot(i, pos)
				part.components.containerinstallableitem.ignoreuninstall = nil
			end
		end
	end
end

function SlingshotMods:OnSave()
	if self.containerinst and not self.containerinst.components.container:IsEmpty() then
		local data, refs = self.containerinst:GetPersistData()
		return { parts = data }, refs
	end
end

function SlingshotMods:OnLoad(data, newents)
	if data.parts then
		self:CreateContainer_Internal()
		self.isloading = true
		self.containerinst:SetPersistData(data.parts, newents)
		self.isloading = nil
	end
end

return SlingshotMods
