--------------------------------------------------------------------------
--Server interface
--------------------------------------------------------------------------

local function SetValue(inst, name, value)
	assert(value >= 0 and value <= 65535, "Pet "..tostring(name).." out of range: "..tostring(value))
	inst[name]:set(math.ceil(value))
end

local function SetDirty(netvar, val)
	--Forces a netvar to be dirty regardless of value
	netvar:set_local(val)
	netvar:set(val)
end

local function SetFlags(inst, value)
	if inst.flags:value() ~= value then
		inst.flags:set(value)
		if inst._parent then
			inst._parent:PushEvent("pet_hunger_flags", value)
		end
	end
end

local function SetFlagBit(inst, bitnum, value)
	SetFlags(inst, value and setbit(inst.flags:value(), bit.lshift(1, bitnum)) or clearbit(inst.flags:value(), bit.lshift(1, bitnum)))
end

local function SetBuild(inst, build)
	build = build or 0
	if build ~= inst.build:value() then
		inst.build:set(build)
		if inst._parent then
			--instant flag for newly spawned, since when replacing prefab during transformation,
			--the new prefab may go through several build change calls before the skin is setup.
			--NOTE: this problem does not occur on the client side since we will just be sending
			--      the final build over network.
			inst._parent:PushEvent("pet_hunger_build", { build = build, instant = inst._pet:GetTimeAlive() <= 0 })
		end
	end
end

local function OnHungerDelta(pet, data)
	if data.overtime then
		--V2C: Don't clear: it's redundant as pet_hunger_classified shouldn't
		--     get constructed remotely more than once, and this would've
		--     also resulted in lost pulses if network hasn't ticked yet.
		--pet.pet_hunger_classified.ishungerpulseup:set_local(false)
		--pet.pet_hunger_classified.ishungerpulsedown:set_local(false)
	elseif data.newpercent > data.oldpercent then
		--Force dirty, we just want to trigger an event on the client
		SetDirty(pet.pet_hunger_classified.ishungerpulseup, true)
	elseif data.newpercent < data.oldpercent then
		--Force dirty, we just want to trigger an event on the client
		SetDirty(pet.pet_hunger_classified.ishungerpulsedown, true)
	end

	local player = pet.pet_hunger_classified._parent
	if player and player == ThePlayer then
		player:PushEvent("pet_hungerdelta", data)
		if data.oldpercent > 0 then
			if data.newpercent <= 0 then
				player:PushEvent("pet_startstarving")
			end
		elseif data.newpercent > 0 then
			player:PushEvent("pet_stopstarving")
		end
	end
end

local function InitializePetInst(inst, pet)
	assert(pet and inst._pet == nil)
	inst._pet = pet
	local hunger = pet.replica.hunger
	if hunger.classified == nil then
		--V2C: Originally, classified on the server is guaranteed to exist before the
		--     corresponding replica component is instantiated.  This is a workarand.
		hunger.classified = inst
		inst.currenthunger:set(pet.components.hunger.current)
		inst.maxhunger:set(pet.components.hunger.max)
	else
		assert(hunger.classified == inst)
	end
	inst:ListenForEvent("hungerdelta", OnHungerDelta, pet)
	inst:ListenForEvent("onremove", inst._onremovepet, pet)
	--Already has parent when transfering to another prefab, ie. pets that switch prefabs when transforming
	if inst._parent == nil then
		inst.entity:SetParent(pet.entity)
		inst.Network:SetClassifiedTarget(inst)
	end
end

local function OnRemovePet(inst, pet)
	assert(pet == inst._pet)
	local player = inst._parent
	if player then
		assert(player.pet_hunger_classified == inst)
		inst:RemoveEventCallback("onremove", inst._onremoveplayer, player)
		player.pet_hunger_classified = nil
		inst._parent = nil
		inst:Remove()
		if player:IsValid() then
			player:PushEvent("show_pet_hunger", false)
		end
	end
end

local function AttachClassifiedToPetOwner(inst, player)
	assert(inst._pet)
	assert(inst._parent == nil)
	assert(player.pet_hunger_classified == nil)
	inst._parent = player
	player.pet_hunger_classified = inst
	inst.entity:SetParent(player.entity)
	inst.Network:SetClassifiedTarget(player)
	inst:ListenForEvent("onremove", inst._onremoveplayer, player)
end

--This is for transfering to another prefab, ie. pets that switch prefabs when transforming
local function DetachClassifiedFromPet(inst, pet)
	assert(pet and pet == inst._pet)
	inst._pet = nil
	inst:RemoveEventCallback("hungerdelta", OnHungerDelta, pet)
	inst:RemoveEventCallback("onremove", inst._onremovepet, pet)
	if inst._parent == nil then
		inst.entity:SetParent(nil)
	end
end

local function OnRemovePlayer(inst, player)
	if inst._parent == nil then
		--Already cleared, probably got here after OnRemovePet
		assert(not inst:IsValid())
		return
	end
	assert(player == inst._parent)
	assert(player.pet_hunger_classified == inst)
	player.pet_hunger_classified = nil
	inst._parent = nil
	inst.entity:SetParent(inst._pet.entity)
	inst.Network:SetClassifiedTarget(inst)
end

--------------------------------------------------------------------------
--Client interface
--------------------------------------------------------------------------

local function OnEntityReplicated(inst)
	--NOTE: parent is the player; pet inst may not actually be in view of client
	inst._parent = inst.entity:GetParent()
	if inst._parent == nil then
		print("Unable to initialize classified data for pet hunger")
	else
		assert(inst._parent.pet_hunger_classified == nil)
		inst._parent.pet_hunger_classified = inst
	end
end

local function OnHungerDirty(inst)
	if inst._parent then
		local oldpercent = inst._oldhungerpercent
		local percent = inst.currenthunger:value() / inst.maxhunger:value()
		local data =
		{
			oldpercent = oldpercent,
			newpercent = percent,
			overtime =
				not (inst.ishungerpulseup:value() and percent > oldpercent) and
				not (inst.ishungerpulsedown:value() and percent < oldpercent),
		}
		inst._oldhungerpercent = percent
		inst.ishungerpulseup:set_local(false)
		inst.ishungerpulsedown:set_local(false)
		inst._parent:PushEvent("pet_hungerdelta", data)
		if oldpercent > 0 then
			if percent <= 0 then
				inst._parent:PushEvent("pet_startstarving")
			end
		elseif percent > 0 then
			inst._parent:PushEvent("pet_stopstarving")
		end
	else
		inst._oldhungerpercent = 1
		inst.ishungerpulseup:set_local(false)
		inst.ishungerpulsedown:set_local(false)
	end
end

local function OnFlagsDirty(inst)
	if inst._parent then
		inst._parent:PushEvent("pet_hunger_flags", inst.flags:value())
	end
end

local function OnBuildDirty(inst)
	if inst._parent then
		inst._parent:PushEvent("pet_hunger_build", { build = inst.build:value() })
	end
end

--------------------------------------------------------------------------
--Common interface
--------------------------------------------------------------------------

local function Max(inst)
	if inst._pet then
		return inst._pet.components.hunger.max
	else
		return inst.maxhunger:value()
	end
end

local function GetPercent(inst)
	if inst._pet then
		return inst._pet.components.hunger:GetPercent()
	else
		return inst.currenthunger:value() / inst.maxhunger:value()
	end
end

local function GetCurrent(inst)
	if inst._pet then
		return inst._pet.components.hunger.current
	else
		return inst.currenthunger:value()
	end
end

local function IsStarving(inst)
	if inst._pet then
		return inst._pet.components.hunger:IsStarving()
	else
		return inst.currenthunger:value() <= 0
	end
end

local function GetFlags(inst)
	return inst.flags:value()
end

local function GetFlagBit(inst, bitnum)
	return checkbit(inst.flags:value(), bit.lshift(1, bitnum))
end

local function GetBuild(inst)
	return inst.build:value()
end

--------------------------------------------------------------------------

local function RegisterNetListeners(inst)
	if not TheWorld.ismastersim then
		inst.ishungerpulseup:set_local(false)
		inst.ishungerpulsedown:set_local(false)
		inst:ListenForEvent("hungerdirty", OnHungerDirty)
		inst:ListenForEvent("flagsdirty", OnFlagsDirty)
		inst:ListenForEvent("builddirty", OnBuildDirty)

		if inst._parent then
			inst._oldhungerpercent = inst.maxhunger:value() > 0 and inst.currenthunger:value() / inst.maxhunger:value() or 0
		end
	end

	if inst._parent then
		inst._parent:PushEvent("show_pet_hunger", true)
	end
end

local function OnRemoveEntity(inst)
	local player = inst._parent
	if player then
		if not TheWorld.ismastersim then
			assert(player.pet_hunger_classified == inst)
			player.pet_hunger_classified = nil
			inst._parent = nil
		end
		player:PushEvent("show_pet_hunger", false)
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	if TheWorld.ismastersim then
		inst.entity:AddTransform() --So we can follow parent's sleep state
	end
	inst.entity:AddNetwork()
	inst.entity:Hide()
	inst:AddTag("CLASSIFIED")

	--Hunger variables
	inst._oldhungerpercent = 1
	inst.currenthunger = net_ushortint(inst.GUID, "hunger.current", "hungerdirty")
	inst.maxhunger = net_ushortint(inst.GUID, "hunger.max", "hungerdirty")
	inst.ishungerpulseup = net_bool(inst.GUID, "hunger.dodeltaovertime(up)", "hungerdirty")
	inst.ishungerpulsedown = net_bool(inst.GUID, "hunger.dodeltaovertime(down)", "hungerdirty")
	inst.currenthunger:set(100)
	inst.maxhunger:set(100)

	--Custom pet specific data
	inst.flags = net_smallbyte(inst.GUID, "pet_hunger_classified.flags", "flagsdirty")

	inst.build = net_hash(inst.GUID, "pet_hunger_classified.build", "builddirty")

	--Delay net listeners until after initial values are deserialized
	inst:DoStaticTaskInTime(0, RegisterNetListeners)

	inst.Max = Max
	inst.GetPercent = GetPercent
	inst.GetCurrrent = GetCurrent
	inst.IsStarving = IsStarving
	inst.GetFlags = GetFlags
	inst.GetFlagBit = GetFlagBit
	inst.GetBuild = GetBuild
	inst.OnRemoveEntity = OnRemoveEntity

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		--Client interface
		inst.OnEntityReplicated = OnEntityReplicated

		return inst
	end

	--Server interface
	inst.InitializePetInst = InitializePetInst
	inst.AttachClassifiedToPetOwner = AttachClassifiedToPetOwner
	inst.DetachClassifiedFromPet = DetachClassifiedFromPet
	inst.SetValue = SetValue
	inst.SetFlags = SetFlags
	inst.SetFlagBit = SetFlagBit
	inst.SetBuild = SetBuild

	inst._onremovepet = function(pet) OnRemovePet(inst, pet) end
	inst._onremoveplayer = function(player) OnRemovePlayer(inst, player) end

	inst.persists = false

	return inst
end

return Prefab("pet_hunger_classified", fn)
