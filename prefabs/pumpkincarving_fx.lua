local PumpkinCarvable = require("components/pumpkincarvable")

local assets_swap =
{
	Asset("ANIM", "anim/farm_plant_pumpkin.zip"),
}

local prefabs_swap =
{
	"pumpkincarving_shatter_fx"
}

local function Swap_ColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.cuts) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

local function Swap_OnRemoveEntity(inst)
	for i, v in ipairs(inst.cuts) do
		v:Remove()
	end
	if inst.owner and inst.owner:IsValid() then
		inst.owner.AnimState:SetSymbolLightOverride(inst.followsymbol, 0)
	end
end

local function Swap_OnIsDay(inst, isday)
	if inst.owner:IsValid() then
		inst.owner.AnimState:SetSymbolLightOverride(inst.followsymbol, not isday and PumpkinCarvable.NIGHT_LIGHT_OVERRIDE or 0)
	end
end

local function Swap_OnCutDataDirty(inst)
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
		if not TheNet:IsDedicated() and PumpkinCarvable.ApplyCuts(inst.cutdata:value(), inst.cuts, inst.owner, inst.followsymbol, swapframe, 0, -145) then
			inst.components.colouraddersync:SetColourChangedFn(Swap_ColourChanged)
		end
		inst.OnRemoveEntity = Swap_OnRemoveEntity
		inst:WatchWorldState("isday", Swap_OnIsDay)
		Swap_OnIsDay(inst, TheWorld.state.isday)
	end
end

local function Swap_SetCutData(inst, cutdata, flag)
	inst.cutdata:set(cutdata)
	inst.flag:set(flag or false)
	Swap_OnCutDataDirty(inst)
end

local function swapfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")

	inst:AddComponent("colouraddersync")

	inst.cuts = {}
	inst.cutdata = net_string(inst.GUID, "pumpkincarving_swap_fx.cutdata", "cutdatadirty")
	inst.flag = net_bool(inst.GUID, "pumpkincarving_swap_fx.flag") --flag can be used for custom data

	if not TheWorld.ismastersim then
		inst:ListenForEvent("cutdatadirty", Swap_OnCutDataDirty)

		return inst
	end

	inst.SetCutData = Swap_SetCutData
	inst.persists = false

	return inst
end

return Prefab("pumpkincarving_swap_fx", swapfn, assets_swap, prefabs_swap)
