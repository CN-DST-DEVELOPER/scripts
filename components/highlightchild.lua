local function OnSyncOwnerDirty(inst)
	--Dedicated server does not need highlighting
	if not TheNet:IsDedicated() then
		local self = inst.components.highlightchild
		if self.owner ~= nil then
			table.removearrayvalue(self.owner.highlightchildren, inst)
		end
		self.owner = self.syncowner:value()
		if self.owner ~= nil then
			if self.owner.highlightchildren == nil then
				self.owner.highlightchildren = { inst }
			else
				table.insert(self.owner.highlightchildren, inst)
			end
		end
	end
end

local HighlightChild = Class(function(self, inst)
	self.inst = inst
	self.owner = nil
	self.syncowner = net_entity(inst.GUID, "highlightchild.syncowner", "syncownerdirty")
	if not TheWorld.ismastersim then
		inst:ListenForEvent("syncownerdirty", OnSyncOwnerDirty)
	end
end)

function HighlightChild:OnRemoveEntity()
	if self.owner ~= nil then
		table.removearrayvalue(self.owner.highlightchildren, self.inst)
	end
end

function HighlightChild:SetOwner(owner)
	self.syncowner:set(owner)
	OnSyncOwnerDirty(self.inst)
end

return HighlightChild
