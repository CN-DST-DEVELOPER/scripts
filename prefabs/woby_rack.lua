local assets =
{
	Asset("ANIM", "anim/woby_rack.zip"),
}

local assets_container =
{
	Asset("ANIM", "anim/ui_meatrack_3x1.zip"),
}

--------------------------------------------------------------------------

local _rnd1, _rnd2 = {}, {}

local function _ResetRandomizer(tbl)
	for i = 1, 3 do
		tbl[i] = i
	end
end

local function _GetNextRandomizer(tbl)
	return table.remove(tbl, math.random(#tbl))
end

local function CreateSlotFx()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("woby_rack")
	inst.AnimState:SetBuild("woby_rack")

	inst:AddComponent("highlightchild")

	return inst
end

local function SetFadeColour(inst, r, g, b, a)
	inst.AnimState:SetMultColour(r, g, b, a)
	for i, v in ipairs(inst.slots) do
		v.fx.AnimState:SetMultColour(r, g, b, a)
	end
end

local function OnPostUpdateFading(inst)
	if inst.owner:IsValid() and inst.owner:HasAnyTag("woby_dash_fade", "woby_align_fade") then
		inst._fading = true
		SetFadeColour(inst, inst.owner.AnimState:GetMultColour())
	elseif inst._fading then
		inst._fading = false
		SetFadeColour(inst, 1, 1, 1, 1)
	end
end

local function OnUpdate(inst)--, dt)
	local moving, running, nopredict
	if inst.owner.sg then
		moving = inst.owner.sg:HasStateTag("moving")
	else
		moving = inst.owner:HasTag("moving")
	end
	if moving then
		running =
			inst.owner.AnimState:IsCurrentAnimation("run_woby_loop") or
			inst.owner.AnimState:IsCurrentAnimation("sprint_woby_loop") or
			inst.owner.AnimState:IsCurrentAnimation("run_woby_pre")
		nopredict = false
	else
		running = false
		if inst.ismastersim and inst.owner.sg then
			nopredict = inst.owner.sg:HasStateTag("nopredict") or inst.owner.sg:HasStateTag("pausepredict")
		else
			nopredict = inst.owner:HasTag("nopredict") or inst.owner:HasTag("pausepredict") or (inst.owner.player_classified and inst.owner.player_classified.pausepredictionframes:value() > 0)
		end
	end

	if running then
		if not inst.wasrunning then
			_ResetRandomizer(_rnd1)
			for i, v in ipairs(inst.slots) do
				v.fx.AnimState:PlayAnimation("loop_swing_run"..tostring(_GetNextRandomizer(_rnd1)), true)
			end
		end
	elseif inst.wasrunning --stopped running
		or (inst.wasmoving and not moving) --stopped walking
		or (nopredict and not inst.wasnopredict) --hit?
	then
		_ResetRandomizer(_rnd1)
		_ResetRandomizer(_rnd2)
		for i, v in ipairs(inst.slots) do
			v.fx.AnimState:PlayAnimation("pst_swing_settle"..tostring(_GetNextRandomizer(_rnd1)))
			v.fx.AnimState:PushAnimation("idle_sway"..tostring(_GetNextRandomizer(_rnd2)))
		end
	end

	inst.wasmoving = moving
	inst.wasrunning = running
	inst.wasnopredict = nopredict
end

local function OnEntitySleep(inst)
	if inst._updating then
		inst._updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
		inst.components.updatelooper:RemovePostUpdateFn(OnPostUpdateFading)
		SetFadeColour(inst, 1, 1, 1, 1)
	end
end

local function OnEntityWake(inst)
	if not inst._updating then
		inst._updating = true
		inst._fading = false
		inst.wasmoving = false
		inst.wasrunning = false
		inst.wasnopredict = false
		inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
		inst.components.updatelooper:AddPostUpdateFn(OnPostUpdateFading)
		OnUpdate(inst, 0)
	end
end

local function OnOwnerChanged(inst, owner)
	for i, v in ipairs(inst.slots) do
		v.fx.components.highlightchild:SetOwner(owner)
	end
	inst.owner = owner
	if owner == nil then
		if inst._fading then
			SetFadeColour(inst, 1, 1, 1, 1)
		end
		inst:RemoveComponent("updatelooper")
		inst.OnEntitySleep = nil
		inst.OnEntityWake = nil
		inst._updating = nil
		inst._fading = nil
		inst.wasmoving = nil
		inst.wasrunning = nil
		inst.wasnopredict = nil
	elseif inst.components.updatelooper == nil then
		inst:AddComponent("updatelooper")
		if TheWorld.ismastersim then
			inst.ismastersim = true
			inst.OnEntitySleep = OnEntitySleep
			inst.OnEntityWake = OnEntityWake
			if not inst:IsAsleep() then
				OnEntityWake(inst)
			end
		else
			OnEntityWake(inst)
		end
	end
end

local function OnColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.slots) do
		v.fx.AnimState:SetAddColour(r, g, b, a)
	end
end

local function _OnSlotDirty(inst, v)
	if v.name:value() == 0 then
		v.fx.AnimState:ClearOverrideSymbol("swap_dried")
		v.fx.AnimState:OverrideSymbol("rope", "woby_rack", "rope_empty")
	else
		v.fx.AnimState:ClearOverrideSymbol("rope")
		v.fx.AnimState:OverrideSymbol("swap_dried", v.build:value(), v.name:value())
	end
	if not inst.wasmoving and inst:GetTimeAlive() > 0 and not inst:IsAsleep() then
		v.fx.AnimState:PlayAnimation("bounce_change"..tostring(math.random(3)))
		v.fx.AnimState:PushAnimation("idle_sway"..tostring(math.random(3)))
	end
end

local OnSlotDirty = {}
for i = 1, 3 do
	OnSlotDirty[i] = function(inst) _OnSlotDirty(inst, inst.slots[i]) end
end

local function ShowRackItem(inst, slot, name, build)
	local v = inst.slots[slot]
	v.name:set(name)
	v.build:set(build)
	if not TheNet:IsDedicated() then
		_OnSlotDirty(inst, v)
	end
end

local function HideRackItem(inst, slot)
	local v = inst.slots[slot]
	v.name:set(0)
	if not TheNet:IsDedicated() then
		_OnSlotDirty(inst, v)
	end
end

local function swapfxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("decor")
	inst:AddTag("NOCLICK")

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("woby_rack")
	inst.AnimState:SetBuild("woby_rack")
	inst.AnimState:PlayAnimation("swap_1")

	inst:AddComponent("highlightchild")
	inst:AddComponent("colouraddersync")

	inst.slots = {}
	for i = 1, 3 do
		local slotid = "["..tostring(i).."]"
		local id = "woby_rack_swap_fx"..slotid
		local event = "slotdirty"..slotid
		local v =
		{
			build = net_hash(inst.GUID, "woby_rack_swap_fx.build"..slotid, event),
			name = net_hash(inst.GUID, "woby_rack_swap_fx.name"..slotid, event),
		}
		v.build:set("meat_rack_food")
		inst.slots[i] = v
	end

	if not TheNet:IsDedicated() then
		for i, v in ipairs(inst.slots) do
			v.fx = CreateSlotFx()
			v.fx.entity:SetParent(inst.entity)
			v.fx.Follower:FollowSymbol(inst.GUID, "swap_slot"..tostring(i), 0, 0, 0, true)
			v.fx.AnimState:PlayAnimation("idle_sway"..tostring(i), true)
			v.fx.AnimState:OverrideSymbol("rope", "woby_rack", "rope_empty")
			if i == 2 then
				v.fx.AnimState:SetFrame(31)
			end
		end
		inst.components.highlightchild:SetOnChangeOwnerFn(OnOwnerChanged)
		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		for i = 1, 3 do
			inst:ListenForEvent("slotdirty["..tostring(i).."]", OnSlotDirty[i])
		end
		return inst
	end

	inst.ShowRackItem = ShowRackItem
	inst.HideRackItem = HideRackItem

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function containerfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("container")
	inst.components.container:WidgetSetup("woby_rack_container")
	inst.components.container.skipautoclose = true

	--wobyrack component will further configure these:
	-- container.isexposed
	-- adding preserver component

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("woby_rack_swap_fx", swapfxfn, assets),
	Prefab("woby_rack_container", containerfn, assets_container)
