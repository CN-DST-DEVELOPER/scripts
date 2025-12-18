local function OnShowIconDirty(inst)
	local self = inst.components.driedsalticon
	if self.showicon:value() then
		if self.showiconfn then
			self.showiconfn(inst)
		else
			inst.inv_image_bg = { image = inst.prefab..".tex" }
            inst.inv_image_bg.atlas = GetInventoryItemAtlas(inst.inv_image_bg.image)
            if self.ismastersim then
            	inst.components.inventoryitem:ChangeImageName("salt_dried_overlay")
			else
				inst:PushEvent("imagechange")
            end
		end
	elseif self.hideiconfn then
		self.hideiconfn(inst)
	else
		inst.inv_image_bg = nil
		if self.ismastersim then
			inst.components.inventoryitem:ChangeImageName(nil)
		else
			inst:PushEvent("imagechange")
		end
	end
end

local DriedSaltIcon = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.showiconfn = nil
	self.hideiconfn = nil

	self.showicon = net_bool(inst.GUID, "driedsalticon.showicon", "showicondirty")

	if self.ismastersim then
		self.collects = false
	else
		inst:ListenForEvent("showicondirty", OnShowIconDirty)
	end
end)

function DriedSaltIcon:OverrideShowIconFn(fn)
	self.showiconfn = fn
end

function DriedSaltIcon:OverrideHideIconFn(fn)
	self.hideiconfn = fn
end

function DriedSaltIcon:SetCollectsOnDried(collects)
	if not self.ismastersim then
		return
	end
	self.collects = collects
end

function DriedSaltIcon:ShowSaltIcon()
	if not self.ismastersim then
		return
	elseif not self.showicon:value() then
		self.showicon:set(true)
		OnShowIconDirty(self.inst)
	end
end

function DriedSaltIcon:HideSaltIcon()
	if not self.ismastersim then
		return
	elseif self.showicon:value() then
		self.showicon:set(false)
		OnShowIconDirty(self.inst)
	end
end

return DriedSaltIcon
