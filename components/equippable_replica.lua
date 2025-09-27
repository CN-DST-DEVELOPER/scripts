local EquipSlot = require("equipslotutil")

local Equippable = Class(function(self, inst)
    self.inst = inst

    self._equipslot =
        EquipSlot.Count() <= 7 and
        net_tinybyte(inst.GUID, "equippable._equipslot") or
        net_smallbyte(inst.GUID, "equippable._equipslot")
    
    self._preventunequipping = net_bool(inst.GUID, "equippable._preventunequipping")
end)

function Equippable:SetEquipSlot(eslot)
    self._equipslot:set(EquipSlot.ToID(eslot))
end

function Equippable:EquipSlot()
    return EquipSlot.FromID(self._equipslot:value())
end

function Equippable:IsEquipped()
    if self.inst.components.equippable ~= nil then
        return self.inst.components.equippable:IsEquipped()
    else
        return self.inst.replica.inventoryitem ~= nil and
            self.inst.replica.inventoryitem:IsHeld() and
            ThePlayer.replica.inventory:GetEquippedItem(self:EquipSlot()) == self.inst
    end
end

function Equippable:IsRestricted(target)
    --return true if restricted (can't equip)
	if not target:HasTag("player") then
		--restricted tags and links only apply to players
		return false
	end
    local linkeditem = self.inst.components.linkeditem
    if linkeditem and linkeditem:IsEquippableRestrictedToOwner() then
        local owneruserid = linkeditem:GetOwnerUserID()
        if owneruserid and owneruserid ~= target.userid then
            return true
        end
    end
	local inventoryitem = self.inst.replica.inventoryitem
	local restrictedtag = inventoryitem and inventoryitem:GetEquipRestrictedTag() or nil
    return restrictedtag ~= nil and not target:HasTag(restrictedtag)
end

function Equippable:ShouldPreventUnequipping()
    return self._preventunequipping:value()
end

function Equippable:SetPreventUnequipping(shouldprevent)
    self._preventunequipping:set(shouldprevent)
end

return Equippable
