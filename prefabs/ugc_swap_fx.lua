local PumpkinCarvable = require("components/pumpkincarvable")
local SnowmanDecoratable = require("components/snowmandecoratable")

local function ColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.pieces) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function OnRemoveEntity(inst)
	for i, v in ipairs(inst.pieces) do
		v:Remove()
	end
end

local function OnDataDirty(inst)
	inst.owner = inst.entity:GetParent()
	if inst.owner then
		local swapframe
		if inst.owner.isplayer then
			--player heavylifting
			inst.followsymbol = "swap_body"
			swapframe = 6
		elseif inst.owner:HasTag("gym") then
			--mightygym
			inst.followsymbol = inst.flag:value() and "swap_item2" or "swap_item"
			swapframe = 6
		else
			--trophyscale
			--winch
			inst.followsymbol = "swap_body"
			swapframe = 13
		end
		if not TheNet:IsDedicated() and inst:_applyfn(swapframe) then
			inst.components.colouraddersync:SetColourChangedFn(ColourChanged)
		end
	end
end

local function SetData(inst, data, flag)
	inst.data:set(data)
	inst.flag:set(flag or false)
	inst:_ondatadirtyfn()
end

local function MakeUgcSwapFx(name, applyfn, common_postinit, master_postinit)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddNetwork()

		inst:AddTag("CLASSIFIED")

		inst:AddComponent("colouraddersync")

		inst.pieces = {}
		inst.data = net_string(inst.GUID, name..".data", "datadirty")
		inst.flag = net_bool(inst.GUID, name..".flag") --flag can be used for custom data

		inst._applyfn = applyfn
		inst._ondatadirtyfn = OnDataDirty
		inst.OnRemoveEntity = OnRemoveEntity

		if common_postinit then
			common_postinit(inst)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			inst:ListenForEvent("datadirty", inst._ondatadirtyfn)

			return inst
		end

		inst.SetData = SetData
		inst.persists = false

		if master_postinit then
			master_postinit(inst)
		end

		return inst
	end

	return Prefab(name, fn)
end

--------------------------------------------------------------------------
--Pumpkin Carving

local function pumpkincarving_apply(inst, swapframe)
	return PumpkinCarvable.ApplyCuts(inst.data:value(), inst.pieces, inst.owner, inst.followsymbol, swapframe, 0, -145)
end

local function pumpkincarving_OnRemoveEntity_Server(inst)
	OnRemoveEntity(inst)
	if inst.owner and inst.owner:IsValid() then
		inst.owner.AnimState:SetSymbolLightOverride(inst.followsymbol, 0)
	end
end

local function pumpkincarving_OnIsDay_Server(inst, isday)
	if inst.owner:IsValid() then
		inst.owner.AnimState:SetSymbolLightOverride(inst.followsymbol, not isday and PumpkinCarvable.NIGHT_LIGHT_OVERRIDE or 0)
	end
end

local function pumpkincarving_OnDataDirty_Server(inst)
	OnDataDirty(inst)
	if inst.owner then
		inst:WatchWorldState("isday", pumpkincarving_OnIsDay_Server)
		pumpkincarving_OnIsDay_Server(inst, TheWorld.state.isday)
		inst.OnRemoveEntity = pumpkincarving_OnRemoveEntity_Server
	end
end

local function pumpkingcarving_master_postinit(inst)
	inst._ondatadirtyfn = pumpkincarving_OnDataDirty_Server
end

--------------------------------------------------------------------------
--Snowman Decorating

local function snowmandecorating_apply(inst, swapframe)
	return SnowmanDecoratable.ApplyDecor(inst.data:value(), inst.pieces, inst.size:value(), nil, nil, inst.owner, inst.followsymbol, swapframe, 0, 0)
end

local function snowmandecorating_common_postinit(inst)
	inst.size = net_tinybyte(inst.GUID, "snowmandecorating_swap_fx.size")
	inst.size:set(SnowmanDecoratable.STACK_IDS.large)
end

--------------------------------------------------------------------------

return MakeUgcSwapFx("pumpkincarving_swap_fx", pumpkincarving_apply, nil, pumpkingcarving_master_postinit),
	MakeUgcSwapFx("snowmandecorating_swap_fx", snowmandecorating_apply, snowmandecorating_common_postinit)
