local function OnOpenSpellWheel(inst)
	local self = inst.components.spellbook
	if self.onopenfn ~= nil then
		self.onopenfn(inst)
	end
end

local function OnCloseSpellWheel(inst)
	local self = inst.components.spellbook
	if self.onclosefn ~= nil then
		self.onclosefn(inst)
	end
end

local SpellBook = Class(function(self, inst)
	self.inst = inst
	self.tag = nil
	self.items = nil
	self.bgdata = nil
	self.radius = 175
	self.focus_radius = 178
	self.spell_id = nil
	self.spellname = nil
	self.spellaction = nil
	self.spellfn = nil
	self.onopenfn = nil
	self.onclosefn = nil
	self.canusefn = nil
	self.opensound = nil
	self.closesound = nil
	self.executesound = nil
	self.closeonexecute = true

	inst:ListenForEvent("openspellwheel", OnOpenSpellWheel)
	inst:ListenForEvent("closespellwheel", OnCloseSpellWheel)
end)

function SpellBook:SetRequiredTag(tag)
	self.tag = tag
end

function SpellBook:SetRadius(radius)
	self.radius = radius
end

function SpellBook:SetFocusRadius(radius)
	self.focus_radius = radius
end

function SpellBook:SetBgData(bgdata)
	self.bgdata = bgdata
end

function SpellBook:SetItems(items)
	self.items = items
end

function SpellBook:SetOnOpenFn(fn)
	self.onopenfn = fn
end

function SpellBook:SetOnCloseFn(fn)
	self.onclosefn = fn
end

function SpellBook:SetCanUseFn(fn)
	self.canusefn = fn
end

--V2C: Spellbook is valid, but should we actually open it?
--     Useful for silently blocking it from opening when classified commands are in a busy preview state
function SpellBook:SetShouldOpenFn(fn)
	self.shouldopenfn = fn
end

function SpellBook:ShouldOpen(user)
	return self.shouldopenfn == nil or self.shouldopenfn(self.inst, user)
end

function SpellBook:CanBeUsedBy(user)
	return (self.tag == nil or user:HasTag(self.tag))
		and (self.canusefn == nil or self.canusefn(self.inst, user))
		and self.items ~= nil
		and #self.items > 0
		and (not self.inst.isplayer or self.inst == user)
end

function SpellBook:OpenSpellBook(user)
	if user.HUD ~= nil then
		if user.components.playercontroller ~= nil then
			user.components.playercontroller:CancelAOETargeting()
		end
		user.HUD:OpenSpellWheel(self.inst, self.items, self.radius, self.focus_radius, self.bgdata)
	end
end

function SpellBook:SelectSpell(id)
	self.spell_id = id
	local item = self.items[id]
	if item == nil then
		return false
	elseif item.onselect ~= nil then
		item.onselect(self.inst)
	end
	return true
end

function SpellBook:GetSelectedSpell()
	return self.spell_id
end

function SpellBook:SetSpellName(name)
	self.spellname = name
end

function SpellBook:GetSpellName()
	return self.spellname
end

--------------------------------------------------------------------------
--Use this to directly push specific actions
--These functions are used on client and server

function SpellBook:SetSpellAction(action)
	self.spellaction = action
end

function SpellBook:GetSpellAction()
	return self.spellaction
end

--------------------------------------------------------------------------
--Use these for spells that go through stategraph CAST_SPELLBOOK action
--These functions are used on server only

function SpellBook:SetSpellFn(fn)
	self.spellfn = fn
end

function SpellBook:HasSpellFn()
	return self.spellfn ~= nil
end

function SpellBook:CastSpell(user)
	if self.spellfn then
		return self.spellfn(self.inst, user)
	else
		return false
	end
end

--------------------------------------------------------------------------

return SpellBook
