local easing = require("easing")

local assets_aoe =
{
	Asset("ANIM", "anim/slingshotammo.zip"),
}

local assets_powerup =
{
	Asset("ANIM", "anim/player_actions_slingshot.zip"),
}

local assets_powerup_mounted =
{
	Asset("ANIM", "anim/player_actions_slingshot.zip"),
	Asset("ANIM", "anim/player_mount_slingshot.zip"),
}

local COLOR_NAMES =
{
	"ice",
	"slow",
	"shadow",
	"horror",
	"lunar",
}
local COLOR_IDS = table.invert(COLOR_NAMES)

local COLORS =
{
	[COLOR_IDS.ice] = RGB(163, 185, 203),
	[COLOR_IDS.slow] = RGB(73, 28, 85),
	[COLOR_IDS.shadow] = RGB(0, 0, 0),
	[COLOR_IDS.horror] = RGB(174, 37, 32),
	[COLOR_IDS.lunar] = RGB(255, 255, 255),
}

local DISC_COLORS = --override if different from COLORS
{
	[COLOR_IDS.horror] = RGB(0, 0, 0),
}

local function RefreshDiscColor(inst)
	local r, g, b = unpack(inst.color)
	local a =
		inst.delta > 0 and
		easing.outQuad(inst.alpha, 0, 1, 1) or
		easing.inQuad(inst.alpha, 0, 1, 1)

	inst.AnimState:SetMultColour(r, g, b, a)
end

local function OnUpdateDisc(inst)
	if inst.delta > 0 then
		if inst.alpha < 1 then
			inst.alpha = math.min(1, inst.alpha + inst.delta)
			RefreshDiscColor(inst)
			if inst.alpha >= 1 then
				inst.delta = -0.1
			end
		end
	elseif inst.alpha > 0 then
		inst.alpha = math.max(0, inst.alpha + inst.delta)
		RefreshDiscColor(inst)
		if inst.alpha <= 0 then
			inst:Hide()
		end
	end
end

local function CreateDisc()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("slingshotammo")
	inst.AnimState:SetBuild("slingshotammo")
	inst.AnimState:PlayAnimation("target_fx_ring")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetMultColour(1, 1, 1, 0)

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(OnUpdateDisc)

	inst.color = WHITE
	inst.alpha = 0.75
	inst.delta = 0.25
	RefreshDiscColor(inst)

	return inst
end

local function OnColorDirty(inst)
	local colorid = inst.color:value()
	inst.disc.color = DISC_COLORS[colorid] or COLORS[colorid] or WHITE
	RefreshDiscColor(inst.disc)

	if colorid == COLOR_IDS.lunar then
		inst.disc.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.disc.AnimState:SetLightOverride(0.5)
	else
		inst.disc.AnimState:ClearBloomEffectHandle()
		inst.disc.AnimState:SetLightOverride(0)
	end
end

local function SetColorType(inst, colorname)
	local colorid = COLOR_IDS[colorname] or 0
	local color = COLORS[colorid] or WHITE

	inst.AnimState:SetMultColour(unpack(color))

	if colorid == COLOR_IDS.lunar then
		inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		inst.AnimState:SetLightOverride(0.5)
	elseif colorid == COLOR_IDS.horror then
		inst.AnimState:ClearBloomEffectHandle()
		inst.AnimState:SetLightOverride(1)
	else
		inst.AnimState:ClearBloomEffectHandle()
		inst.AnimState:SetLightOverride(0)
	end

	inst.color:set(colorid)
	if inst.disc then
		OnColorDirty(inst)
	end
end

local function aoefn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("slingshotammo")
	inst.AnimState:SetBuild("slingshotammo")
	inst.AnimState:PlayAnimation("target_fx_pst")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetFinalOffset(1)

	inst.color = net_tinybyte(inst.GUID, "slingshot_aoe_fx.color", "colordirty")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		inst.disc = CreateDisc(inst)
		inst.disc.entity:SetParent(inst.entity)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("colordirty", OnColorDirty)

		return inst
	end

	inst:ListenForEvent("animover", inst.Remove)

	inst.SetColorType = SetColorType
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function powerup_CreateBack(mounted)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	if mounted then
		inst.Transform:SetSixFaced()
		inst.AnimState:SetBank("wilsonbeefalo")
	else
		inst.AnimState:SetBank("wilson")
	end

	inst.AnimState:SetBuild("player_actions_slingshot")
	inst.AnimState:PlayAnimation("slingshot_powerup")
	inst.AnimState:Hide("front")
	inst.AnimState:SetFinalOffset(-2)
	inst.AnimState:SetMultColour(1, 1, 1, 0.6)

	return inst
end

local function MakePowerup(name, mounted, assets)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")

		if mounted then
			inst.Transform:SetSixFaced()
			inst.AnimState:SetBank("wilsonbeefalo")
		else
			inst.AnimState:SetBank("wilson")
		end

		inst.AnimState:SetBuild("player_actions_slingshot")
		inst.AnimState:PlayAnimation("slingshot_powerup")
		inst.AnimState:Hide("back")
		inst.AnimState:SetFinalOffset(2)
		inst.AnimState:SetMultColour(1, 1, 1, 0.6)

		--Dedicated server does not need to spawn the local fx
		if not TheNet:IsDedicated() then
			powerup_CreateBack(mounted).entity:SetParent(inst.entity)
		end

		inst.entity:SetPristine()

		if not TheWorld.ismastersim then
			return inst
		end

		inst:ListenForEvent("animover", inst.Remove)

		inst.persists = false

		return inst
	end

	return Prefab(name, fn, assets)
end

--------------------------------------------------------------------------

return Prefab("slingshot_aoe_fx", aoefn, assets_aoe),
	MakePowerup("slingshot_powerup_fx", false, assets_powerup),
	MakePowerup("slingshot_powerup_mounted_fx", true, assets_powerup_mounted)
