local assets =
{
	Asset("ANIM", "anim/reticulelong.zip"),
}

local prefabs =
{
	"reticulelongping",
}

local PAD_DURATION = .1
local SCALE = 1.5

local function SetChargeScale(inst, chargescale)
	inst.chargescale = chargescale
	inst.AnimState:SetScale(chargescale * SCALE, SCALE)
end

local function fn()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("reticulelong")
	inst.AnimState:SetBuild("reticulelong")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetScale(SCALE, SCALE)

	inst:AddComponent("chargingreticule")
	inst.components.chargingreticule.ease = true
	inst.components.chargingreticule.pingprefab = "reticulelongping"

	inst.chargescale = 1
	inst.SetChargeScale = SetChargeScale

	return inst
end

return Prefab("reticulecharging", fn, assets, prefabs)
