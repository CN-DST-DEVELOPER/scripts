local SnowmanDecoratable = require("components/snowmandecoratable")

local assets =
{
	Asset("ANIM", "anim/snowball.zip"),
}

local prefabs =
{
	"snowmandecorating_swap_fx",
	"pumpkincarving_shatter_fx",
	"snowball_item",
	"snowmanhat_fx",
	"beeswax_spray_fx",
    "snowball_shatter_fx",
	"snowman_debris_fx",
	"snowball_rolling_fx",
}

local scrapbook_adddeps
if TheSim then -- Exporter guard.
    scrapbook_adddeps = SnowmanDecoratable.CollectScrapbookDeps()
end

local PHYSICS_RADIUS =
{
	["small"] = 0.1,
	["med"] = 0.3,
	["large"] = 0.5,
}

local ANIM_RADIUS = --art visual radius
{
	["small"] = 0.35,
	["med"] = 0.7,
	["large"] = 0.95,
}

local NUM_LOOT =
{
	["small"] = 1,
	["med"] = 3,
	["large"] = 5,
}

local SNOW_TO_GROW =
{
	["small"] = 3,
	["med"] = 5,
}

local function _GetNextSize(size)
	return size == "small" and "med" or "large"
end

local function _GetGrowAnim(size)
	return (size == "med" and "small_to_med")
		or (size == "large" and "med_to_large")
		or nil
end

local function TryHitAnim(inst)
	if not (inst.components.pushable and inst.components.pushable:IsPushing()) then
		local size = inst.components.snowmandecoratable:GetSize()
		inst.AnimState:PlayAnimation("hit_"..size)
		inst.AnimState:PushAnimation("ground_"..size, false)
		return true
	end
	return false
end

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "snowball", inst.components.symbolswapdata.symbol)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
end

local function OnStopPushing(inst)
	local size = inst.components.snowmandecoratable:GetSize()
	if size == "small" then
		local x, y, z = inst.Transform:GetWorldPosition()
		local snowball = SpawnPrefab("snowball_item")
		snowball.Transform:SetPosition(x, 0, z)
		snowball.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
		if inst.snowaccum > 0 then
			snowball.snowaccum = inst.snowaccum --transfer it, doesn't matter if it gets lost XD
		end
		inst:Remove()
		return
	end

	if inst._pushingtask then
		inst._pushingtask:Cancel()
		inst._pushingtask = nil
	end
	if inst._nosnowtask then
		inst._nosnowtask:Cancel()
		inst._nosnowtask = nil
	end
	if inst._rollingfx then
		inst._rollingfx:KillFx()
		inst._rollingfx = nil
	end
	inst.components.inventoryitem.canbepickedup = inst.components.pushable ~= nil
	inst.Transform:SetNoFaced()
	inst.Physics:Stop()
	inst.AnimState:PlayAnimation("ground_"..size)
end

local function _SnowballTooBigWarning(inst, doer)
	if doer and doer.components.talker and doer:IsValid() then
		doer.components.talker:Say(GetString(doer, "ANNOUNCE_SNOWBALL_TOO_BIG"))
	end
end

local function _NoSnowWarning(inst, doer)
	if doer and doer.components.talker and doer:IsValid() then
		doer.components.talker:Say(GetString(doer, "ANNOUNCE_SNOWBALL_NO_SNOW"))
	end
end

local function DetachRollingFx(inst)
	local fx = inst._rollingfx
	if fx and fx:IsValid() then
		local x, y, z = fx.Transform:GetWorldPosition()
		local rot = inst.Transform:GetRotation()
		fx.entity:SetParent(nil)
		fx.Transform:SetPosition(x, y, z)
		fx.Transform:SetRotation(rot)
		fx:KillFx()
	end
	inst._rollingfx = nil
end

local function _GrowSnowballSize(inst, doer)
	if TheWorld.state.issnowcovered and not GROUND_NOGROUNDOVERLAYS[TheWorld.Map:GetTileAtPoint(inst.Transform:GetWorldPosition())] then
		if inst._nosnowtask then
			inst._nosnowtask:Cancel()
			inst._nosnowtask = nil
		end

		local oldsize = inst.components.snowmandecoratable:GetSize()
		if oldsize == "large" then
			inst._pushingtask:Cancel()
			inst._pushingtask = inst:DoPeriodicTask(8, _SnowballTooBigWarning, 0.8, doer)
		else
			local snowlevel = TheWorld.state.snowlevel
			if snowlevel > 0 then
				inst.snowaccum = inst.snowaccum + math.sqrt(snowlevel)
			end

			if inst.snowaccum >= (SNOW_TO_GROW[oldsize] or 0) then
				local newsize = _GetNextSize(oldsize)
				if oldsize ~= newsize then
					inst:SetSize(newsize, true)
					inst.snowaccum = 0
				end
				if newsize == "large" then
					inst._pushingtask:Cancel()
					inst._pushingtask = inst:DoPeriodicTask(8, _SnowballTooBigWarning, 1.6, doer)
				end
			end
		end
		if inst._rollingfx == nil then
			inst._rollingfx = SpawnPrefab("snowball_rolling_fx")
			inst._rollingfx.entity:SetParent(inst.entity)
			inst._rollingfx.AnimState:MakeFacingDirty() -- Not needed for clients
			inst._rollingfx:ListenForEvent("onremove", DetachRollingFx, inst)
			inst._rollingfx:ListenForEvent("enterlimbo", DetachRollingFx, inst)
		end
	else
		if inst._nosnowtask == nil and doer and doer.components.talker and doer:IsValid() then
			inst._nosnowtask = inst:DoPeriodicTask(8, _NoSnowWarning, 0.8, doer)
		end
		inst.snowaccum = 0
		if inst._rollingfx then
			inst._rollingfx:KillFx()
			inst._rollingfx = nil
		end
	end
end

local function OnStartPushing(inst, doer)
	inst.Transform:SetFourFaced()
	inst.Transform:SetRotation(doer:GetAngleToPoint(inst.Transform:GetWorldPosition()))
	inst.AnimState:PlayAnimation("roll_"..inst.components.snowmandecoratable:GetSize().."_loop", true)
	inst.components.inventoryitem.canbepickedup = false
	if inst._pushingtask == nil then
		inst._pushingtask = inst:DoPeriodicTask(0.25, _GrowSnowballSize, nil, doer)
	end
end

local function OnPutInInventory(inst, owner)
	if inst.components.pushable then
		inst.components.pushable:StopPushing()
	end
end

local function ConfigurePushingDist(inst, size)
	local anim_r = ANIM_RADIUS[size] or 0
	local phys_r = PHYSICS_RADIUS[size] or 0
	inst.components.pushable:SetTargetDist(anim_r + 0.2)
	inst.components.pushable:SetMinDist(math.max(anim_r - 0.2, phys_r + 0.05))
	inst.components.pushable:SetMaxDist(anim_r + 1)
end

local function _AddPushableComponent(inst)
	if inst.components.pushable == nil then
		inst:AddComponent("pushable")
		inst.components.pushable:SetOnStartPushingFn(OnStartPushing)
		inst.components.pushable:SetOnStopPushingFn(OnStopPushing)
		inst.components.pushable:SetPushingSpeed(TUNING.SNOWBALL_ROLLING_SPEED)
		ConfigurePushingDist(inst, inst.components.snowmandecoratable:GetSize())
	end
end

local function CheckLiftAndPushable(inst)
	if inst.components.snowmandecoratable.doer == nil and
		not (	inst.components.snowmandecoratable:IsStacked() or
				inst.components.snowmandecoratable:HasDecor() or
				inst.components.snowmandecoratable:HasHat() or
				inst:HasTag("waxedplant")
			)
	then
		_AddPushableComponent(inst)
		inst.components.inventoryitem.canbepickedup = not inst.components.pushable:IsPushing()
	else
		inst.components.inventoryitem.canbepickedup = false
		inst:RemoveComponent("pushable")
	end
end

local function RefreshPhysicsSize(inst, basesize, stacks)
	basesize = basesize or inst.components.snowmandecoratable:GetSize()
	local stackingheight = basesize == "small" and 1 or 2
	local maxrad = PHYSICS_RADIUS[basesize] or 0
	if stacks == nil then
		--returns stacks, stackoffsets (but we don't need stackoffsets here)
		stacks = inst.components.snowmandecoratable:GetStacks()
	end
	for i, v in ipairs(stacks) do
		local stackdata = SnowmanDecoratable.STACK_DATA[v]
		if stackdata then
			maxrad = math.max(maxrad, PHYSICS_RADIUS[stackdata.name] or 0)
			stackingheight = stackingheight + (stackdata.name == "small" and 1 or 2)
			if stackingheight >= 3 then
				break
			end
		end
	end
	if maxrad ~= inst.physicsradiusoverride then
		inst:SetPhysicsRadiusOverride(maxrad)
		if TheWorld.ismastersim then
			inst.Physics:SetCapsule(maxrad, 2)
			inst.components.heavyobstaclephysics:SetRadius(maxrad)
		end
	end
end

local function OnHatChanged(inst, hat, isloading)
	CheckLiftAndPushable(inst)
	if hat and not isloading then
		inst.SoundEmitter:PlaySound("meta5/snowman/place_snow")
	end
end

local function ConfigureWaxed(inst)
	inst:RemoveComponent("waxable")
	inst:AddTag("waxedplant")
    inst.components.snowballmelting:StopMelting()
end

local function DoWaxFadeTint(inst, r, g, b, a)
	if inst.stacks then
		for i, v in ipairs(inst.stacks) do
			v.AnimState:SetMultColour(r, g, b, a)
		end
	end
	if inst.components.snowmandecoratable.decors then
		for i, v in ipairs(inst.components.snowmandecoratable.decors) do
			v.AnimState:SetMultColour(r, g, b, a)
		end
	end
end

local function WaxFadePostUpdate(inst)
	local r, g, b, a = inst.AnimState:GetMultColour()
	DoWaxFadeTint(inst, r, g, b, a)
end

local function StopWaxFadeClientUpdate(inst)
	if inst.components.updatelooper then
		inst:RemoveComponent("updatelooper")
		DoWaxFadeTint(inst, 1, 1, 1, 1)
	end
end

local function StartWaxFadeClientUpdate(inst)
	if inst.components.updatelooper == nil then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(WaxFadePostUpdate)
	end
end

local function OnIsWaxing(inst)
	if inst.iswaxing:value() then
		inst.OnEntitySleep = StopWaxFadeClientUpdate
		inst.OnEntityWake = StartWaxFadeClientUpdate
		if not inst:IsAsleep() then
			StartWaxFadeClientUpdate(inst)
		end
	else
		inst.OnEntitySleep = nil
		inst.OnEntityWake = nil
		StopWaxFadeClientUpdate(inst)
	end
end

local WAX_FADE_IN_TIME = 0.8
local WAX_FADE_DELAY = 0.7
local WAX_FADE_OUT_TIME = 1.5
local WAX_DARK_MULTCOLOR = { 0.2, 0.2, 0.2, 1 }

local function OnWaxed4(inst)
	inst:RemoveComponent("colourtweener")
	inst.iswaxing:set(false)
	if not TheNet:IsDedicated() then
		OnIsWaxing(inst)
	end
end

local function OnWaxed3(inst)
	inst.components.colourtweener:StartTween(WHITE, WAX_FADE_OUT_TIME, OnWaxed4)
end

local function OnWaxed2(inst)
	inst:DoTaskInTime(WAX_FADE_DELAY, OnWaxed3)
end

local function OnWaxed(inst, doer, waxitem)
	if (inst.components.pushable and inst.components.pushable:IsPushing()) or
		inst.components.inventoryitem:IsHeld() or
		(inst.components.snowmandecoratable:GetSize() == "small" and not inst.components.snowmandecoratable:IsStacked())
	then
		return false
	end

	inst.components.snowmandecoratable:EndDecorating()

	SpawnPrefab("beeswax_spray_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
	ConfigureWaxed(inst)
	CheckLiftAndPushable(inst)

	inst:AddComponent("colourtweener")
	inst.components.colourtweener:StartTween(WAX_DARK_MULTCOLOR, WAX_FADE_IN_TIME, OnWaxed2)

	inst.iswaxing:set(true)
	if not TheNet:IsDedicated() then
		OnIsWaxing(inst)
	end
	return true
end

local function _AddWaxableComponent(inst)
	if inst.components.waxable == nil then
		inst:AddComponent("waxable")
		inst.components.waxable:SetNeedsSpray(true)
		inst.components.waxable:SetWaxfn(OnWaxed)
	end
end

local function CheckWaxable(inst)
	if (	inst.components.snowmandecoratable:IsStacked() or
			inst.components.snowmandecoratable:GetSize() ~= "small"
		) and
		not inst:HasTag("waxedplant")
	then
		_AddWaxableComponent(inst)
	else
		inst:RemoveComponent("waxable")
	end
end

local function CreateStack()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("snowball")
	inst.AnimState:SetBuild("snowball")

	return inst
end

local function OnStacksChanged(inst, stacks, stackoffsets, reason)
	local basesize = inst.components.snowmandecoratable:GetSize()
	if TheWorld.ismastersim then
		CheckLiftAndPushable(inst)
		CheckWaxable(inst)
		if reason == "addstack" then
			local laststackid = SnowmanDecoratable.STACK_IDS[basesize]
			local laststackdata = SnowmanDecoratable.STACK_DATA[laststackid]
			if laststackdata then
				local height, offset = 0, 0
				for i, v in ipairs(stacks) do
					local stackdata = SnowmanDecoratable.STACK_DATA[v]
					if stackdata then
						height = height + laststackdata.heights[v]
						offset = SnowmanDecoratable.CalculateStackOffset(stackdata.r, stackoffsets[i])
						laststackid = v
						laststackdata = stackdata
					end
				end
				local fx = SpawnPrefab("snowman_debris_fx")
				fx.AnimState:PlayAnimation("debris_"..laststackdata.name)
				fx.Follower:FollowSymbol(inst.GUID, "snowman_ball", offset, -height, 0)
			end
			TryHitAnim(inst)
			inst.SoundEmitter:PlaySound("meta5/snowman/place_snow")
		end
	end
	if not TheNet:IsDedicated() then
		local laststackid = SnowmanDecoratable.STACK_IDS[basesize]
		local laststackdata = SnowmanDecoratable.STACK_DATA[laststackid]
		if laststackdata then
			if inst.stacks == nil then
				inst.stacks = {}
			end
			if inst.highlightchildren == nil then
				inst.highlightchildren = {}
			end
			local height = 0
			local n = 1
			for i, v in ipairs(stacks) do
				local stackdata = SnowmanDecoratable.STACK_DATA[v]
				if stackdata then
					height = height + laststackdata.heights[v]

					local ent = inst.stacks[n]
					if ent == nil then
						ent = CreateStack()
						ent.entity:SetParent(inst.entity)
						local offset = SnowmanDecoratable.CalculateStackOffset(stackdata.r, stackoffsets[i])
						ent.Follower:FollowSymbol(inst.GUID, "snowman_ball", offset, -height, 0, true)
						inst.stacks[n] = ent
						table.insert(inst.highlightchildren, ent)
					end
					ent.AnimState:PlayAnimation((v > laststackid and "stack_clean_" or "stack_")..stackdata.name)

					laststackid = v
					laststackdata = stackdata
					n = n + 1
				end
			end
			for i = n, #inst.stacks do
				local v = inst.stacks[i]
				table.removearrayvalue(inst.highlightchildren, v)
				v:Remove()
				inst.stacks[i] = nil
			end
		end
	end
	RefreshPhysicsSize(inst, basesize, stacks)
end

local function SetSize(inst, size, growanim)
	inst.components.snowmandecoratable:SetSize(size)

	--in case we tried to set an invalid size above
	size = inst.components.snowmandecoratable:GetSize()

	CheckWaxable(inst)

	local isrolling
	if inst.components.pushable then
		isrolling = inst.components.pushable:IsPushing()
		ConfigurePushingDist(inst, size)
	end

	if isrolling then
		growanim = growanim and _GetGrowAnim(size) or nil
		if growanim then
			inst.AnimState:PlayAnimation(growanim)
			inst.AnimState:PushAnimation("roll_"..size.."_loop")
		else
			local t = inst.AnimState:GetCurrentAnimationTime()
			inst.AnimState:PlayAnimation("roll_"..size.."_loop", true)
			inst.AnimState:SetTime(t)
		end
	else
		inst.AnimState:PlayAnimation("ground_"..size)
	end
	inst.components.symbolswapdata:SetData("snowball", "swap_body_"..size)
	RefreshPhysicsSize(inst, size, nil)
end

local function DoBreakApart(inst, isdestroyed)
    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("snowball_shatter_fx").Transform:SetPosition(x, y, z)
    if not inst.components.snowmandecoratable:IsMelting() then
        inst:AddComponent("lootdropper")
        local pt = inst:GetPosition()
        local num = NUM_LOOT[inst.components.snowmandecoratable:GetSize()] or 1 
        if num > 1 then
            if isdestroyed then
                --get less snowballs when destroyed (will also destroy the whole stack of snowman balls)
                if math.random() < 0.7 then
                    num = num - 1
                end
            elseif math.random() < 0.5 then
                --get more when manually hammering one ball
                num = num + 1
            end
        end
        for i = 1, num do
            inst.components.lootdropper:SpawnLootPrefab("snowball_item", pt)
        end
    end
    inst:Remove()
end

local function OnWork(inst, worker, workleft, numwork)
	if workleft <= 0 then
		--destroyed!
		inst.components.snowmandecoratable:UnequipHat()
		inst.components.snowmandecoratable:DropAllDecor()
		inst.components.snowmandecoratable:Unstack(true)
		DoBreakApart(inst, true)
		return
	elseif inst.components.snowmandecoratable:HasHat() then
		inst.components.snowmandecoratable:UnequipHat()
		TryHitAnim(inst)
	elseif inst.components.snowmandecoratable:HasDecor() then
		inst.components.snowmandecoratable:DropAllDecor()
		TryHitAnim(inst)
	elseif inst.components.snowmandecoratable:IsStacked() then
		inst.components.snowmandecoratable:Unstack(false)
		--if base was small sized, it will have prefab swapped to snowball_item
		if inst:IsValid() and inst:HasTag("waxedplant") then
			inst:RemoveTag("waxedplant")
			_AddWaxableComponent(inst)
			CheckLiftAndPushable(inst)
            inst.components.snowballmelting:AllowMelting()
		end
	else
		DoBreakApart(inst, false)
		return
	end

	--Reset work after each hit. Can't just use workmultiplier 0 because we want to allow Destroy()
	inst.components.workable:SetWorkLeft(99)
	inst.components.snowmandecoratable:EndDecorating()
end

local function OnPreLoad(inst, data)
	if data and data.size then
		SetSize(inst, data.size)
	end
end

local function OnSave(inst, data)
	local size = inst.components.snowmandecoratable:GetSize()
	if size ~= "large" then
		data.size = size
	end
	if inst:HasTag("waxedplant") then
		data.waxed = true
	end
end

local function OnLoad(inst, data)
	local size = inst.components.snowmandecoratable:GetSize()
	if size == "small" and not inst.components.snowmandecoratable:IsStacked() then
		--it was saved during rolling, never got bigger
		local x, y, z = inst.Transform:GetWorldPosition()
		local snowball = SpawnPrefab("snowball_item")
		snowball.Transform:SetPosition(x, 0, z)
		snowball.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
		inst:RemoveFromScene()
		inst:DoTaskInTime(0, inst.Remove)
		inst.persists = false
		return
	end

	if data and data.waxed then
		ConfigureWaxed(inst)
	end
	CheckLiftAndPushable(inst)
end

local function DisplayNameFn(inst)
	return not inst.components.snowmandecoratable:IsStacked()
		and (	inst.components.snowmandecoratable:GetSize() == "small" and
				STRINGS.NAMES.SNOWBALL_ITEM or
				STRINGS.NAMES.SNOWBALL_LARGE
			)
		or nil
end

local function GetStatus(inst)
	return not inst.components.snowmandecoratable:IsStacked() and "SNOWBALL" or nil
end

local function OnStartMelting(inst)
    inst.components.snowmandecoratable:SetMelting(true)
end

local function OnStopMelting(inst)
    inst.components.snowmandecoratable:SetMelting(false)
end

local function OnDoMeltAction(inst)
    if inst.components.workable then
        inst.components.workable:WorkedBy(inst, 1)
    end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("snowball")
	inst.AnimState:SetBuild("snowball")
	inst.AnimState:PlayAnimation("ground_large")

	inst:AddTag("heavy")
	inst:AddTag("heavylift_lmb") --allow LMB for heavylift since RMB is needed for pushing
	inst:AddTag("pushing_roll") --for START_PUSHING action string => "Roll"

	inst:SetPhysicsRadiusOverride(PHYSICS_RADIUS.large)
	MakeHeavyObstaclePhysics(inst, inst.physicsradiusoverride)

	inst.displaynamefn = DisplayNameFn

	inst:AddComponent("snowmandecoratable")
	inst.components.snowmandecoratable:SetOnStacksChangedFn(OnStacksChanged)

	inst.iswaxing = net_bool(inst.GUID, "snowman.iswaxing", "iswaxingdirty")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("basesizedirty", RefreshPhysicsSize)
		inst:ListenForEvent("iswaxingdirty", OnIsWaxing)

		return inst
	end

	inst.scrapbook_adddeps = scrapbook_adddeps

	_AddPushableComponent(inst)
	_AddWaxableComponent(inst)

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst.components.snowmandecoratable.onopenfn = CheckLiftAndPushable
	inst.components.snowmandecoratable.onclosefn = CheckLiftAndPushable
	inst.components.snowmandecoratable.onhatchangedfn = OnHatChanged

	inst:AddComponent("heavyobstaclephysics")
	inst.components.heavyobstaclephysics:SetRadius(inst.physicsradiusoverride)
	inst.components.heavyobstaclephysics:AddPushingStates()

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.cangoincontainer = false
	inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
	inst.components.inventoryitem:SetSinks(true)

	inst:AddComponent("submersible")
	inst:AddComponent("symbolswapdata")
	inst.components.symbolswapdata:SetData("snowball", "swap_body_large")

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.BODY
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnequip)
	inst.components.equippable.walkspeedmult = TUNING.HEAVY_SPEED_MULT

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(99)
	inst.components.workable:SetOnWorkCallback(OnWork)

    inst:AddComponent("snowballmelting")
    inst.components.snowballmelting:SetOnStartMelting(OnStartMelting)
    inst.components.snowballmelting:SetOnStopMelting(OnStopMelting)
    inst.components.snowballmelting:SetOnDoMeltAction(OnDoMeltAction)
    inst.components.snowballmelting:AllowMelting()

	--inst._pushingtask = nil
	--inst._nosnowtask = nil
	--inst._rollingfx = nil
	inst.snowaccum = 0

	inst.SetSize = SetSize
	inst.OnSave = OnSave
	inst.OnPreLoad = OnPreLoad
	inst.OnLoad = OnLoad
	--OnEntityWake/OnEntitySleep used by client wax fading

	return inst
end

--------------------------------------------------------------------------

local function hat_OnEntityReplicated(inst)
	local parent = inst.entity:GetParent()
	if parent then
		if parent.highlightchildren == nil then
			parent.highlightchildren = { inst }
		else
			table.insert(parent.highlightchildren, inst)
		end
	end
end

local function hat_OnRemoveEntity(inst)
	local parent = inst.entity:GetParent()
	if parent and parent.highlightchildren then
		table.removearrayvalue(parent.highlightchildren, inst)
	end
end

local function hatfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("snowball")
	inst.AnimState:SetBuild("snowball")
	inst.AnimState:PlayAnimation("hat_small")

	inst:AddTag("equipmentmodel")
	inst:AddTag("FX")

	if not TheNet:IsDedicated() then
		inst.OnRemoveEntity = hat_OnRemoveEntity
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = hat_OnEntityReplicated

		return inst
	end

	inst:AddComponent("inventory")
	inst.components.inventory.maxslots = 0

	return inst
end

--------------------------------------------------------------------------

local function debrisfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("snowball")
	inst.AnimState:SetBuild("snowball")
	inst.AnimState:PlayAnimation("debris_large")
	inst.AnimState:SetFinalOffset(2)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function rollingfx_OnAnimOver(inst)
	if inst.killed then
		inst:Remove()
	else
		inst.AnimState:PlayAnimation("fx_roll")
	end
end

local function rollingfx_KillFx(inst)
	inst.killed = true
end

local function rollingfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("decor") --we're parenting it, but don't want mouseover
	inst:AddTag("NOCLICK")

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("snowball")
	inst.AnimState:SetBuild("snowball")
	inst.AnimState:PlayAnimation("fx_roll")
	inst.AnimState:SetFinalOffset(2)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", rollingfx_OnAnimOver)

	inst.persists = false
	inst.KillFx = rollingfx_KillFx

	return inst
end

--------------------------------------------------------------------------

return Prefab("snowman", fn, assets, prefabs),
	Prefab("snowmanhat_fx", hatfxfn, assets),
	Prefab("snowman_debris_fx", debrisfxfn, assets),
	Prefab("snowball_rolling_fx", rollingfxfn, assets)
