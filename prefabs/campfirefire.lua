local assets =
{
    Asset("ANIM", "anim/campfire_fire.zip"),
    Asset("SOUND", "sound/common.fsb"),
}

local prefabs =
{
    "firefx_light",
}

local LIGHT_COLOUR = RGB(255, 255, 192)

--------------------------------------------------------------------------
local heats = { 70, 85, 100, 115 }

local firelevels =
{
	{anim="level1", sound="dontstarve/common/campfire", radius=2, intensity=.8, falloff=.33, colour=LIGHT_COLOUR, soundintensity=.1},
	{anim="level2", sound="dontstarve/common/campfire", radius=3, intensity=.8, falloff=.33, colour=LIGHT_COLOUR, soundintensity=.3},
	{anim="level3", sound="dontstarve/common/campfire", radius=4, intensity=.8, falloff=.33, colour=LIGHT_COLOUR, soundintensity=.6},
	{anim="level4", sound="dontstarve/common/campfire", radius=5, intensity=.8, falloff=.33, colour=LIGHT_COLOUR, soundintensity=1},
}

--------------------------------------------------------------------------
local portable_heats = { 70, 77.5, 85 }

local portable_firelevels =
{
	{anim="level1",		sound="dontstarve/common/campfire", radius=2.5,	intensity=0.8, falloff=0.33, colour=LIGHT_COLOUR, soundintensity=0.1},
	{anim="level1a",	sound="dontstarve/common/campfire", radius=3,	intensity=0.8, falloff=0.33, colour=LIGHT_COLOUR, soundintensity=0.2},
	{anim="level2",		sound="dontstarve/common/campfire", radius=3.5,	intensity=0.8, falloff=0.33, colour=LIGHT_COLOUR, soundintensity=0.3},
}

--------------------------------------------------------------------------

local function MakeFire(name, fxlevels, heatlevels)
	local function GetHeatFn(inst)
		return heatlevels[inst.components.firefx.level] or 20
	end

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst.entity:AddNetwork()

		inst.AnimState:SetBank("campfire_fire")
		inst.AnimState:SetBuild("campfire_fire")
		inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.AnimState:SetRayTestOnBB(true)
		inst.AnimState:SetFinalOffset(3)

		inst:AddTag("FX")

		--HASHEATER (from heater component) added to pristine state for optimization
		inst:AddTag("HASHEATER")

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("heater")
		inst.components.heater.heatfn = GetHeatFn

		inst:AddComponent("firefx")
		inst.components.firefx.levels = fxlevels
		if TheNet:GetServerGameMode() == "quagmire" then
			event_server_data("quagmire", "prefabs/campfirefire").master_postinit(inst)
		end
		inst.components.firefx:SetLevel(1)
		inst.components.firefx.usedayparamforsound = true

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

return MakeFire("campfirefire", firelevels, heats),
	MakeFire("portable_campfirefire", portable_firelevels, portable_heats)
