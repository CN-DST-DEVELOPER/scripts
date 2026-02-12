local assets =
{
    Asset("ANIM", "anim/campfire_fire.zip"),
    Asset("SOUND", "sound/yoth_2026.fsb"),
}

local prefabs =
{
    "firefx_light",
}

local LIGHT_COLOUR = RGB(255, 255, 192)

--------------------------------------------------------------------------

local firelevels =
{
	{anim="level1", sound="yoth_2026/floatinglantern/floating_LP", radius=1, intensity=.8, falloff=.4, colour=LIGHT_COLOUR, soundintensity=.1},
	{anim="level2", sound="yoth_2026/floatinglantern/floating_LP", radius=1.34, intensity=.8, falloff=.4, colour=LIGHT_COLOUR, soundintensity=.3},
	{anim="level3", sound="yoth_2026/floatinglantern/floating_LP", radius=1.67, intensity=.8, falloff=.4, colour=LIGHT_COLOUR, soundintensity=.6},
	{anim="level4", sound="yoth_2026/floatinglantern/floating_LP", radius=2, intensity=.8, falloff=.4, colour=LIGHT_COLOUR, soundintensity=1},
}

--------------------------------------------------------------------------

local function OnPostUpdate(inst)
	local parent = inst.entity:GetParent()
	local camerafade = parent and parent.components.camerafade
	if camerafade then
		inst.AnimState:OverrideMultColour(1, 1, 1, camerafade:GetCurrentAlpha())
	end
end

local function MakeFire(name, fxlevels, fxlight_offset)
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

        if not TheNet:IsDedicated() then
			inst:AddComponent("updatelooper")
			inst.components.updatelooper:AddPostUpdateFn(OnPostUpdate)
        end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst:AddComponent("firefx")
		inst.components.firefx.levels = fxlevels
		inst.components.firefx:SetLevel(1)
		inst.components.firefx:SetFxLightOffsetPosition(fxlight_offset)

		return inst
	end

	return Prefab(name, fn, assets, prefabs)
end

-- NOTE: (Omar)
--[[
The fire fx light can be culled since the lantern is so high up,
leading to the light potentially disappearing off screen
So, hack! Let's offset the position by... a guessed height to keep the light stay on screen
]]
return MakeFire("floatinglanternfire", firelevels, Vector3(0, -6, 0))