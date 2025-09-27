local easing = require("easing")

local temp =
{
	["ash"] =					{	bank = "ashes",					build = "ash",					anim = "snowman_decor"								},
	["asparagus"] =				{	bank = "asparagus",				build = "asparagus",			anim = "snowman_decor",				canflip = true	},
	["batwing"] =				{	bank = "batwing",				build = "batwing",				anim = "snowman_decor",				canflip = true	},
	["beardhair"] =				{	bank = "beardhair",				build = "beardhair",			anim = "snowman_decor",				canflip = true	},
	["berries"] =				{	bank = "berries",				build = "berries",				anim = "snowman_decor"								},
	["berries_juicy"] =			{	bank = "berries_juicy",			build = "berries_juicy",		anim = "snowman_decor"								},
	["blue_cap"] =				{	bank = "mushrooms",				build = "mushrooms",			anim = "snowman_decor_blue",		canflip = true	},
	["boneshard"] =				{	bank = "bone_shards",			build = "bone_shards",			anim = "snowman_decor",				canflip = true	},
	["carrot"] =				{	bank = "carrot",				build = "carrot",				anim = "snowman_decor",				canflip = true	},
	["charcoal"] =				{	bank = "charcoal",				build = "charcoal",				anim = "snowman_decor"								},
	["cutgrass"] =				{	bank = "grass",					build = "grass1",				anim = "snowman_decor",				canflip = true	},
	["deerclops_eyeball"] =		{	bank = "deerclops_eyeball",		build = "deerclops_eyeball",	anim = "snowman_decor",				canflip = true	},
	["eggplant"] =				{	bank = "eggplant",				build = "eggplant",				anim = "snowman_decor",				canflip = true	},
	["feather_canary"] =		{	bank = "feather_canary",		build = "feather_canary",		anim = "snowman_decor",				canflip = true	},
	["feather_crow"] =			{	bank = "feather_crow",			build = "feather_crow",			anim = "snowman_decor",				canflip = true	},
	["featherpencil"] =			{	bank = "feather_pencil",		build = "feather_pencil",		anim = "snowman_decor",				canflip = true	},
	["feather_robin"] =			{	bank = "feather_robin",			build = "feather_robin",		anim = "snowman_decor",				canflip = true	},
	["feather_robin_winter"] =	{	bank = "feather_robin_winter",	build = "feather_robin_winter",	anim = "snowman_decor",				canflip = true	},
	["flint"] =					{	bank = "flint",					build = "flint",				anim = "snowman_decor",				canflip = true	},
	["gears"] =					{	bank = "gears",					build = "gears",				anim = "snowman_decor"								},
	["goldnugget"] =			{	bank = "goldnugget",			build = "gold_nugget",			anim = "snowman_decor"								},
	["goose_feather"] =			{	bank = "goose_feather",			build = "goose_feather",		anim = "snowman_decor",				canflip = true	},
	["green_cap"] =				{	bank = "mushrooms",				build = "mushrooms",			anim = "snowman_decor_green",		canflip = true	},
	["houndstooth"] =			{	bank = "houndstooth",			build = "hounds_tooth",			anim = "snowman_decor",				canflip = true	},
	["ice"] =					{	bank = "ice",					build = "ice",					anim = "snowman_decor",				canflip = true	},
	["malbatross_feather"] =	{	bank = "malbatross_feather",	build = "malbatross_feather",	anim = "snowman_decor",				canflip = true	},
	["marble"] =				{	bank = "marble",				build = "marble",				anim = "snowman_decor",				canflip = true	},
	["moonglass"] =				{	bank = "moonglass",				build = "moonglass",			anim = "snowman_decor",				canflip = true	},
	["moonrocknugget"] =		{	bank = "moonrocknugget",		build = "moonrock_nugget",		anim = "snowman_decor",				canflip = true	},
	["nitre"] =					{	bank = "nitre",					build = "nitre",				anim = "snowman_decor",				canflip = true	},
	["pepper"] =				{	bank = "pepper",				build = "pepper",				anim = "snowman_decor",				canflip = true	},
	["petals"] =				{	bank = "petals",				build = "flower_petals",		anim = "snowman_decor",				canflip = true	},
	["petals_evil"] =			{	bank = "flower_petals_evil",	build = "flower_petals_evil",	anim = "snowman_decor",				canflip = true	},
	["red_cap"] =				{	bank = "mushrooms",				build = "mushrooms",			anim = "snowman_decor_red",			canflip = true	},
	["rocks"] =					{	bank = "rocks",					build = "rocks",				anim = "snowman_decor"								},
	["seeds"] =					{	bank = "seeds",					build = "seeds",				anim = "snowman_decor_seed"							},
	["seeds_cooked"] =			{	bank = "seeds",					build = "seeds",				anim = "snowman_decor_seedcooked"					},
	["twigs"] =					{	bank = "twigs",					build = "twigs",				anim = "snowman_decor",				canflip = true	},
}
local ITEM_DATA = {}
for k, v in pairs(temp) do
	ITEM_DATA[hash(k)] = v
	v.name = k
end
temp = nil

local STACK_DATA =
{
	{
		name = "small",
		heights =
		{
			small = 78,
			med = 84,
			large = 82,
		},
		r = 54,
		ycenter = 34,
		yscale = 0.944,
		stackheight = 1,
	},
	{
		name = "med",
		heights =
		{
			small = 178,
			med = 164,
			large = 168,
		},
		r = 108,
		ycenter = 90,
		yscale = 0.935,
		stackheight = 2,
	},
	{
		name = "large",
		heights =
		{
			small = 256,
			med = 234,
			large = 224,
		},
		r = 145,
		ycenter = 124,
		yscale = 0.986,
		stackheight = 3,
	},
}
local STACK_IDS = {}
for i, v in ipairs(STACK_DATA) do
	STACK_IDS[v.name] = i

	--make the heights key by id as well
	for i1, v1 in ipairs(STACK_DATA) do
		v.heights[i1] = v.heights[v1.name]
	end
end

local MAX_STACK_HEIGHT = 6

local function CollectScrapbookDeps(tbl)
	tbl = tbl or {}
	for k, v in pairs(ITEM_DATA) do
		table.insert(tbl, v.name)
	end
	return tbl
end

--------------------------------------------------------------------------

local function Decor_OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()
	if parent and parent.highlightchildren then
		table.removearrayvalue(parent.highlightchildren, inst)
	end
end

local function CreateDecor(itemdata, rot, flip)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank(itemdata.bank)
	inst.AnimState:SetBuild(itemdata.build)
	inst.AnimState:PlayAnimation(itemdata.anim..(flip and itemdata.canflip and "_flip" or ""))
	inst.AnimState:SetFrame(rot - 1)
	inst.AnimState:Pause()

	inst.OnRemoveEntity = Decor_OnRemoveEntity

	return inst
end

--------------------------------------------------------------------------

local function GetItemData(itemhash)
	return ITEM_DATA[itemhash]
end

local function AddDecorData(tbl, itemhash, rot, flip, x, y)
	local n = #tbl
	tbl[n + 1] = itemhash
	tbl[n + 2] = rot
	tbl[n + 3] = flip and 1 or 0
	tbl[n + 4] = x
	tbl[n + 5] = y
end

local function CalculateStackOffset(radius, rnd)
	return rnd and radius * 0.2 * (rnd - 31.5) / 31.5 or 0
end

local PADDING = 1
--keep in sync @snowmandecoratingscreen.lua
local function _IsOnSnowball(stackdata, x0, y0, x, y, isbase)
	local x1 = x0
	local y1 = -(y0 + stackdata.ycenter) --y-axis inverted compared to snowmandecoratingscreen.lua
	local r = stackdata.r + PADDING
	local dx = x - x1
	local dy = (y - y1) / stackdata.yscale
	return dx * dx + dy * dy < r * r and not (isbase and y > 0)
end

--keep in sync @snowmandecoratable.lua
local function _IsOnSnowman(x, y, basesize, stacks, stackoffsets)
	local laststackdata = STACK_DATA[basesize]
	if laststackdata then
		if _IsOnSnowball(laststackdata, 0, 0, x, y, true) then
			return true
		end
		if stacks then
			local x0, y0 = 0, 0
			for i, v in ipairs(stacks) do
				local stackdata = STACK_DATA[v]
				if stackdata then
					x0 = CalculateStackOffset(stackdata.r, stackoffsets and stackoffsets[i] or nil)
					y0 = y0 + laststackdata.heights[v]
					if _IsOnSnowball(stackdata, x0, y0, x, y) then
						return true
					end
					laststackdata = stackdata
				end
			end
		end
	end
	return false
end

local function _DoDecor(itemdata, rot, flip, x, y, tbl, basesize, stacks, stackoffsets, owner, swapsymbol, swapframe, offsetx, offsety)
	if not (itemdata and rot and x and y) then
		return
	elseif not _IsOnSnowman(x, y, basesize, stacks, stackoffsets) then
		print(string.format("SnowmanDecoratable::_DoDecor(\"%s\", %d%s, %d, %d) dropped out of range.", itemdata.name, rot, flip and "(flipped)" or "", x, y))
		return
	end

	x = x + offsetx
	y = y + offsety

	local decor = CreateDecor(itemdata, rot, flip)
	decor.entity:SetParent(owner.entity)
	decor.Follower:FollowSymbol(owner.GUID, swapsymbol, x, y, 0, true, nil, swapframe)
	table.insert(tbl, decor)

	if owner.highlightchildren == nil then
		owner.highlightchildren = { decor }
	else
		table.insert(owner.highlightchildren, decor)
	end
end

local function ApplyDecor(decordata, decors, basesize, stacks, stackoffsets, owner, swapsymbol, swapframe, offsetx, offsety)
	for i = 1, #decors do
		decors[i]:Remove()
		decors[i] = nil
	end
	decordata = string.len(decordata) > 0 and DecodeAndUnzipString(decordata) or nil
	if type(decordata) == "table" and #decordata > 0 then
		offsetx = offsetx or 0
		offsety = offsety or 0
		for i = 1, #decordata, 5 do
			local itemhash = decordata[i]
			local itemdata = ITEM_DATA[itemhash]
			if itemdata then
				_DoDecor(itemdata, decordata[i + 1], decordata[i + 2] == 1, decordata[i + 3], decordata[i + 4], decors, basesize, stacks, stackoffsets, owner, swapsymbol, swapframe, offsetx, offsety)
			end
		end
		return true
	end
	return false
end

local function _ValidateAndAppendDecorData(doer, olddecordata, newdecordata, basesize, stacks, invobj)
	if not doer and doer.components.inventory and doer:IsValid() then
		return olddecordata
	end
	local valid_decordata = string.len(olddecordata) > 0 and DecodeAndUnzipString(olddecordata) or nil
	newdecordata = string.len(newdecordata) > 0 and DecodeAndUnzipString(newdecordata) or nil
	if type(newdecordata) == "table" and #newdecordata > 0 then
		local maxdecor = TUNING.SNOWMAN_MAX_DECOR[basesize] or 0
		for i, v in ipairs(stacks) do
			maxdecor = maxdecor + math.max(5, (TUNING.SNOWMAN_MAX_DECOR[v] or 0) - 5 * i)
		end
		valid_decordata = valid_decordata or {}
		local valid_idx = #valid_decordata + 1
		local max_idx = maxdecor * 5 - #valid_decordata
		local toconsume = {}
		for i = 1, math.min(max_idx, #newdecordata), 5 do
			local itemdata = ITEM_DATA[newdecordata[i]]
			if itemdata then
				local num = (toconsume[itemdata.name] or 0) + 1
				if doer.components.inventory:Has(itemdata.name, num) then
					toconsume[itemdata.name] = num
					for j = 0, 4 do
						valid_decordata[valid_idx + j] = newdecordata[i + j]
					end
					valid_idx = valid_idx + 5
				end
			end
		end

		--Try depleting the obj we initiated the decorating screen with first
		if invobj and invobj:IsValid() and invobj.components.inventoryitem and invobj.components.inventoryitem:GetGrandOwner() == doer then
			local num = toconsume[invobj.prefab] or 0
			if num > 0 then
				local stacksize = invobj.components.stackable and invobj.components.stackable:StackSize() or 1
				if stacksize > num then
					invobj.components.stackable:SetStackSize(stacksize - num)
					toconsume[invobj.prefab] = nil
				else
					invobj:Remove()
					toconsume[invobj.prefab] = num > stacksize and num - stacksize or nil
				end
			end
		end

		--Deplete the rest from inventory
		for k, v in pairs(toconsume) do
			doer.components.inventory:ConsumeByName(k, v)
		end
	end
	if valid_decordata and #valid_decordata > 0 then
		return ZipAndEncodeString(valid_decordata)
	end
	return ""
end

--------------------------------------------------------------------------

local function OnDecorDataDirty_Client(inst)
	inst.components.snowmandecoratable:DoRefreshDecorData()
end

local function OnStacksDirty_Client(inst)
	inst.components.snowmandecoratable:OnStacksChanged("clientsync")
end

local function OnEquipped_Server(inst, data)
	local self = inst.components.snowmandecoratable
	if data and data.owner then
		if self.swapinst then
			self.swapinst:Remove()
			self.swapinst = nil
		end
		local decordata = self.decordata:value()
		if string.len(decordata) > 0 then
			self.swapinst = SpawnPrefab("snowmandecorating_swap_fx")
			self.swapinst.entity:SetParent(data.owner.entity)
			self.swapinst.size:set(inst.components.snowmandecoratable.basesize:value())
			self.swapinst:SetData(decordata)
		end
	end
end

local function OnUnequipped_Server(inst, data)
	local self = inst.components.snowmandecoratable
	if self.swapinst then
		self.swapinst:Remove()
		self.swapinst = nil
	end
end

local function OnEnterLimbo_Server(inst)
	local self = inst.components.snowmandecoratable
	self:EndDecorating(self.doer)
end

local SnowmanDecoratable = Class(function(self, inst)
	self.inst = inst

	self.ismastersim = TheWorld.ismastersim
	self.isdedicated = TheNet:IsDedicated()

	if not self.isdedicated then
		self.decors = {}
	end
	self.decordata = net_string(inst.GUID, "snowmandecoratable.decordata", "decordatadirty")

	self.basesize = net_tinybyte(inst.GUID, "snowmandecoratable.basesize", "basesizedirty")
	self.basesize:set(STACK_IDS.large)

	self.stacks = net_smallbytearray(inst.GUID, "snowmandecoratable.stacks", "stacksdirty")
	self.stackoffsets = net_smallbytearray(inst.GUID, "snowmandecoratable.stackoffsets", "stacksdirty")
	self.onstackschangedfn = nil

	if not self.ismastersim then
		inst:ListenForEvent("decordatadirty", OnDecorDataDirty_Client)
		inst:ListenForEvent("stacksdirty", OnStacksDirty_Client)

		return
	end

	self.swapinst = nil
	self.hatinst = nil
	self.hatrnd = nil
	self.onhatchangedfn = nil
	self.doer = nil
	self.range = 3
	self.onopenfn = nil
	self.onclosefn = nil

	self.onclosepopup = function(doer, data)
		if data.popup == POPUPS.SNOWMANDECORATING then
			if data and data.args then
				self.onclosesnowman(doer, data.args[1], data.args[2])
			else
				self.onclosesnowman(doer)
			end
		end
	end
	self.onclosesnowman = function(doer, decordata, obj)
		if type(decordata) == "string" then
			self.decordata:set(_ValidateAndAppendDecorData(doer, self.decordata:value(), decordata, self.basesize:value(), self.stacks:value(), obj))
			if not self.isdedicated and self:DoRefreshDecorData() then
				--If we do an fx here, would have to consider the snowball stacks
				--local x, y, z = inst.Transform:GetWorldPosition()
				--SpawnPrefab("pumpkincarving_shatter_fx").Transform:SetPosition(x, 1, z)
			end
		end
		self:EndDecorating(doer)
	end

	inst:ListenForEvent("equipped", OnEquipped_Server)
	inst:ListenForEvent("unequipped", OnUnequipped_Server)
	inst:ListenForEvent("enterlimbo", OnEnterLimbo_Server)
end)

SnowmanDecoratable.CollectScrapbookDeps = CollectScrapbookDeps
SnowmanDecoratable.AddDecorData = AddDecorData
SnowmanDecoratable.ApplyDecor = ApplyDecor
SnowmanDecoratable.CalculateStackOffset = CalculateStackOffset
SnowmanDecoratable.GetItemData = GetItemData
SnowmanDecoratable.STACK_IDS = STACK_IDS
SnowmanDecoratable.STACK_DATA = STACK_DATA

function SnowmanDecoratable:OnRemoveFromEntity()
	if self.ismastersim then
		self:EndDecorating(self.doer)
		self.inst:RemoveEventCallback("equipped", OnEquipped_Server)
		self.inst:RemoveEventCallback("unequipped", OnUnequipped_Server)
		self.inst:RemoveEventCallback("enterlimbo", OnEnterLimbo_Server)
	else
		self.inst:RemoveEventCallback("decordatadirty", OnDecorDataDirty_Client)
		self.inst:RemoveEventCallback("stacksdirty", OnStacksDirty_Client)
	end
	if self.decors then
		for i, v in ipairs(self.decors) do
			v:Remove()
		end
	end
	if self.swapinst then
		self.swapinst:Remove()
		self.swapinst = nil
	end
end
SnowmanDecoratable.OnRemoveEntity = SnowmanDecoratable.OnRemoveFromEntity

function SnowmanDecoratable:GetDecorData()
	return self.decordata:value()
end

function SnowmanDecoratable:HasDecor()
	return string.len(self.decordata:value()) > 0
end

function SnowmanDecoratable:GetSize()
	return STACK_DATA[self.basesize:value()].name
end

function SnowmanDecoratable:SetSize(size)
	self.basesize:set(STACK_IDS[size] or self.basesize:value())
end

function SnowmanDecoratable:SetOnStacksChangedFn(fn)
	self.onstackschangedfn = fn
end

function SnowmanDecoratable:IsStacked()
	return #self.stacks:value() > 0
end

function SnowmanDecoratable:GetStacks()
	return self.stacks:value(), self.stackoffsets:value()
end

function SnowmanDecoratable:CanStack(doer, obj)
	if not self.ismastersim then
		return
	elseif obj.components.snowmandecoratable == nil or self.inst:HasTag("waxedplant") then
		return false
	elseif self:HasHat() then
		return false, "HASHAT"
	end

	local stackdata = STACK_DATA[obj.components.snowmandecoratable.basesize:value()]
	if stackdata == nil then
		return false
	end
	local stackheight = stackdata.stackheight
	stackdata = STACK_DATA[self.basesize:value()]
	if stackdata == nil then
		return false
	end
	stackheight = stackheight + stackdata.stackheight
	for i, v in ipairs(self.stacks:value()) do
		stackdata = STACK_DATA[v]
		if stackdata then
			stackheight = stackheight + stackdata.stackheight
		end
	end
	if stackheight > MAX_STACK_HEIGHT then
		return false, "STACKEDTOOHIGH"
	elseif self.doer then
		return false, "INUSE"
	end
	return true
end

function SnowmanDecoratable:Stack(doer, obj)
	if not self.ismastersim then
		return
	elseif obj.components.snowmandecoratable then
		--currently doesn't transfer decor, assuming you can't decorate ones that you can pickup
		local stackid = obj.components.snowmandecoratable.basesize:value()
		local stackdata = STACK_DATA[stackid]

		if obj.components.stackable then
			obj.components.stackable:Get():Remove()
		else
			obj:Remove()
		end

		if stackdata then
			local stacks = self.stacks:value()
			local stackoffsets = self.stackoffsets:value()
			table.insert(stacks, stackid)
			table.insert(stackoffsets, math.random(0, 63))
			self.stacks:set(stacks)
			self.stackoffsets:set(stackoffsets)
			self:OnStacksChanged("addstack")
		end
	end
end

function SnowmanDecoratable:DoDropItem(prefab, x, z, size)
	local item = SpawnPrefab(prefab)
	if item then
		if size and item.SetSize then
			item:SetSize(size) --this resets physics, so do it before drop physics
		end
		if item.components.inventoryitem then
			item.components.inventoryitem:InheritWorldWetnessAtTarget(self.inst)
			if item.components.heavyobstaclephysics then
				item.components.heavyobstaclephysics:ForceDropPhysics()
				item.components.inventoryitem:DoDropPhysics(x, 0, z, true, 1.3)
			else
				item.components.inventoryitem:DoDropPhysics(x, 0, z, true)
			end
		end
		return item
	end
end

function SnowmanDecoratable:Unstack(isdestroyed)
	if not self.ismastersim then
		return
	end
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local pt = self.inst:GetPosition()
	for i, v in ipairs(self.stacks:value()) do
		if v == STACK_IDS.small then
			self:DoDropItem("snowball_item", x, z)
		else
			local stackdata = STACK_DATA[v]
			if stackdata then
				if isdestroyed then
					local snowman = SpawnPrefab("snowman")
					snowman:SetSize(stackdata.name)
					snowman.Transform:SetPosition(x, 0, z)
					snowman.components.workable:Destroy(self.inst)
				else
					self:DoDropItem("snowman", x, z, stackdata.name)
				end
			end
		end
	end
	if self.basesize:value() == STACK_IDS.small then
		self:DoDropItem("snowball_item", x, z)
		self.inst:Remove()
	else
		local empty = {}
		self.stacks:set(empty)
		self.stackoffsets:set(empty)
		self:OnStacksChanged("unstack")
		if self.inst.components.inventoryitem then
			if self.inst.components.heavyobstaclephysics then
				self.inst.components.heavyobstaclephysics:ForceDropPhysics()
			end
			self.inst.components.inventoryitem:DoDropPhysics(x, 0, z, true, 0.5)
		end
	end
end

function SnowmanDecoratable:OnStacksChanged(reason)
	if self.onstackschangedfn then
		self.onstackschangedfn(self.inst, self.stacks:value(), self.stackoffsets:value(), reason)
	end
end

function SnowmanDecoratable:HasHat()
	if not self.ismastersim then
		return
	end
	return self.hatinst ~= nil and self.hatinst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) ~= nil
end

function SnowmanDecoratable:EquipHat(hat)
	self:EquipHat_Internal(hat)
end

function SnowmanDecoratable:EquipHat_Internal(hat, overridernd)
	if not self.ismastersim then
		return
	elseif hat and hat.components.equippable and hat.components.equippable.equipslot == EQUIPSLOTS.HEAD and not hat.components.equippable:IsEquipped() then
		if self.hatinst == nil then
			self.hatinst = SpawnPrefab("snowmanhat_fx")
			self.hatinst.entity:SetParent(self.inst.entity)

			if not self.isdedicated then
				if self.inst.highlightchildren == nil then
					self.inst.highlightchildren = { self.hatinst }
				else
					table.insert(self.inst.highlightchildren, self.hatinst)
				end
			end

			local x0, y0 = 0, 0
			local laststackdata = STACK_DATA[self.basesize:value()]
			if laststackdata then
				local stacks = self.stacks:value()
				if #stacks > 0 then
					local stackoffsets = self.stackoffsets:value()
					for i, v in ipairs(self.stacks:value()) do
						local stackdata = STACK_DATA[v]
						if stackdata then
							x0 = CalculateStackOffset(stackdata.r, stackoffsets[i])
							y0 = y0 + laststackdata.heights[v]
							laststackdata = stackdata
						end
					end
				end
				self.hatinst.AnimState:PlayAnimation("hat_"..laststackdata.name)
				self.hatinst.AnimState:Pause()
			end
			self.hatinst.Follower:FollowSymbol(self.inst.GUID, "follow_hat", x0, -y0, 0, true)
		else
			local oldhat = self.hatinst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
			if oldhat then
				self.hatinst.components.inventory:DropItem(oldhat, true, true)
			end
		end
		self.hatrnd = overridernd or math.random(self.hatinst.AnimState:GetCurrentAnimationNumFrames()) - 1
		self.hatinst.AnimState:SetFrame(self.hatrnd)
		self.hatinst.components.inventory:Equip(hat)
		if self.onhatchangedfn then
			self.onhatchangedfn(self.inst, hat, overridernd ~= nil)
		end
	end
end

function SnowmanDecoratable:UnequipHat()
	if not self.ismastersim then
		return
	elseif self.hatinst then
		self.hatinst.components.inventory:DropEverything()
		self.hatinst:Remove()
		self.hatinst = nil
		self.hatrnd = nil
		if self.onhatchangedfn then
			self.onhatchangedfn(self.inst, nil)
		end
	end
end

function SnowmanDecoratable:SetMelting(melting)
    self.melting = melting and true or nil
end

function SnowmanDecoratable:IsMelting()
    return self.melting
end

function SnowmanDecoratable:CanBeginDecorating(doer)
	if not self.ismastersim then
		return
	elseif self.doer == doer or doer.sg == nil or doer.sg:HasStateTag("busy") then
		return false
	elseif doer.components.inventory and doer.components.inventory:IsHeavyLifting() then
		return false
	elseif self.inst.components.pushable and self.inst.components.pushable:IsPushing() then
		return false
	elseif self.doer then
		return false, "INUSE"
    elseif self:IsMelting() then
        return false, "MELTING"
	end
	return true
end

function SnowmanDecoratable:BeginDecorating(doer, obj)
	if not self.ismastersim then
		return
	elseif self.doer == nil then
		self.doer = doer

		self.inst:ListenForEvent("onremove", self.onclosesnowman, doer)
		self.inst:ListenForEvent("ms_closepopup", self.onclosepopup, doer)

		doer.sg:GoToState("snowmandecorating", { target = self.inst, obj = obj })

		self.inst:StartUpdatingComponent(self)

		if self.onopenfn then
			self.onopenfn(self.inst)
		end
		return true
	end
	return false
end

function SnowmanDecoratable:EndDecorating(doer)
	if not self.ismastersim then
		return
	elseif self.doer and (doer == nil or self.doer == doer) then
		doer = self.doer --since we support nil doer
		self.doer = nil

		self.inst:RemoveEventCallback("onremove", self.onclosesnowman, doer)
		self.inst:RemoveEventCallback("ms_closepopup", self.onclosepopup, doer)

		doer:PushEventImmediate("ms_endsnowmandecorating")

		self.inst:StopUpdatingComponent(self)

		if self.onclosefn then
			self.onclosefn(self.inst)
		end
	end
end

function SnowmanDecoratable:DropAllDecor()
	if not self.ismastersim then
		return
	end
	local decordata = self.decordata:value()
	decordata = string.len(decordata) > 0 and DecodeAndUnzipString(decordata) or nil
	if type(decordata) == "table" and #decordata > 0 then
		local loots = {}
		for i = 1, #decordata, 5 do
			local itemdata = ITEM_DATA[decordata[i]]
			if itemdata then
				loots[itemdata.name] = (loots[itemdata.name] or 0) + 1
			end
		end
		local x, y, z = self.inst.Transform:GetWorldPosition()
		for prefab, num in pairs(loots) do
			while num > 0 do
				local loot = self:DoDropItem(prefab, x, z)
				if loot == nil then
					break --invalid loot? just in case, but shouldn't happend
				elseif loot.components.stackable then
					local rndnum = math.random(math.min(num, 6))
					loot.components.stackable:SetStackSize(rndnum)
					num = num - rndnum
				else
					num = num - 1
				end
			end
		end
		self.decordata:set("")
		if not self.isdedicated then
			self:DoRefreshDecorData()
		end
	end
end

function SnowmanDecoratable:DoRefreshDecorData()
	return ApplyDecor(self.decordata:value(), self.decors, self.basesize:value(), self.stacks:value(), self.stackoffsets:value(), self.inst, "follow_decor")
end

function SnowmanDecoratable:LoadDecorData(decordata)
	self.decordata:set(decordata)
	if not self.isdedicated then
		self:DoRefreshDecorData()
	end
end

function SnowmanDecoratable:OnSave()
	local data = {}

	local decordata = self.decordata:value()
	if string.len(decordata) > 0 then
		data.decor = decordata
	end

	local stacks = self.stacks:value()
	if #stacks > 0 then
		data.stacks = stacks
		data.stackoffsets = self.stackoffsets:value()
	end

	local references
	if self.hatinst then
		local hat = self.hatinst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		if hat then
			local hatdata, refs = hat:GetSaveRecord()
			data.hat = hatdata
			data.hatrnd = self.hatrnd ~= 0 and self.hatrnd or nil
			if refs then
				references = {}
				for k, v in pairs(refs) do
					table.insert(references, v)
				end
			end
		end
	end

	if next(data) then
		return data, references
	end
end

function SnowmanDecoratable:OnLoad(data, newents)
	if data then
		if data.stacks then
			self.stacks:set(data.stacks)
			if data.stackoffsets then
				self.stackoffsets:set(data.stackoffsets)
			end
			self:OnStacksChanged("load")
		end

		if type(data.decor) == "string" then
			self:LoadDecorData(data.decor)
		end

		if data.hat then
			local hat = SpawnSaveRecord(data.hat, newents)
			if hat then
				self:EquipHat_Internal(hat, data.hatrnd or 0)
			end
		end
	end
end

function SnowmanDecoratable:TransferComponent(newinst)
	if not self.ismastersim then
		return
	end
	local snowmandecoratable = newinst.components.snowmandecoratable
	if snowmandecoratable then
		snowmandecoratable.basesize:set(self.basesize:value())
		snowmandecoratable.stacks:set(self.stacks:value())
		snowmandecoratable.stackoffsets:set(self.stackoffsets:value())
		snowmandecoratable:OnStacksChanged("load")
		snowmandecoratable:LoadDecorData(self.decordata:value())
	end
end

--------------------------------------------------------------------------
--Check for auto-closing conditions
--------------------------------------------------------------------------

function SnowmanDecoratable:OnUpdate(dt)
	if self.doer == nil then
		self.inst:StopUpdatingComponent(self)
	elseif not (self.doer:IsNear(self.inst, self.range) and CanEntitySeeTarget(self.doer, self.inst)) then
		self:EndDecorating(self.doer)
    end
end

return SnowmanDecoratable
