local PlayerFloater = Class(function(self, inst)
	self.inst = inst
	self.onequipfn = nil
	self.onunequipfn = nil

	--V2C: Recommended to explicitly add tag to prefab pristine state
	inst:AddTag("playerfloater")
end)

function PlayerFloater:OnRemoveFromEntity()
	self.inst:RemoveTag("playerfloater")
end

function PlayerFloater:SetOnEquip(fn)
	self.onequipfn = fn
	if self.inst.components.equippable then
		self.inst.components.equippable:SetOnEquip(fn)
	end
end

function PlayerFloater:SetOnUnequip(fn)
	self.onunequipfn = fn
end

local function OnUnequip(inst, owner)
	local self = inst.components.playerfloater
	if self.onunequipfn then
		self.onunequipfn(inst, owner)
	end
	inst:RemoveComponent("equippable")
end

function PlayerFloater:MakeEquippable_Internal()
	self.inst:AddComponent("equippable")
	self.inst.components.equippable:SetOnEquip(self.onequipfn)
	self.inst.components.equippable:SetOnUnequip(OnUnequip)
	self.inst.components.equippable:SetPreventUnequipping(true)
end

function PlayerFloater:AutoDeploy(player)
	local item = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if item then
		player.components.inventory:DropItem(item, true, true)
	end

	--close backpacks
	item = player.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
	if item and item.components.container then
		item.components.container:Close(player)
	end

	self:MakeEquippable_Internal()
	player.components.inventory:Equip(self.inst)
end

function PlayerFloater:LetGo(player, randomdir, pos)
	self.inst.components.equippable:SetPreventUnequipping(false)
	player.components.inventory:DropItem(self.inst, true, randomdir, pos)
end

function PlayerFloater:Reset(player)
	self.inst.components.equippable:SetPreventUnequipping(false)
	player.components.inventory:Unequip(self.inst.components.equippable.equipslot)
	player.components.inventory:GiveItem(self.inst)
end

function PlayerFloater:OnSave()
	if self.inst.components.equippable then
		return { equipped = true }
	end
end

function PlayerFloater:OnLoad(data, ents)
	if data.equipped then
		self:MakeEquippable_Internal()
	end
end

--V2C: Won't get run if loading through inventory!
--     If it's not held, then make sure there's no equippable.
function PlayerFloater:LoadPostPass(ents, data)
	self.inst:RemoveComponent("equippable")
end

return PlayerFloater
