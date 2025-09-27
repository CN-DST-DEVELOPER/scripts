local MakeTorchFire = require("prefabs/torchfire_common")

local assets =
{
    Asset("DYNAMIC_ANIM", "anim/dynamic/lantern_tesla.zip"),
    Asset("PKGREF", "anim/dynamic/torch_tesla.dyn"),
}

local function common_postinit(inst)
    inst.AnimState:SetBank("torch_tesla_fx")
	inst.AnimState:SetBuild("swap_torch")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetFinalOffset(1)
end

local function AssignSkinData(inst, parent)
	inst.AnimState:OverrideItemSkinSymbol("bolt_b", "torch_tesla", "bolt_b", parent.GUID, "torch")
	inst.AnimState:OverrideItemSkinSymbol("bolt_c", "torch_tesla", "bolt_c", parent.GUID, "torch")
	inst.AnimState:OverrideItemSkinSymbol("torch_overlay", "torch_tesla", "torch_overlay", parent.GUID, "torch")
end

local function master_postinit(inst)
	inst.AssignSkinData = AssignSkinData
    inst.fx_offset = -125
end

return MakeTorchFire("torchfire_tesla", assets, nil, common_postinit, master_postinit, { -- Overrides.
    hasanimstate = true,
    sfx_torchloop = "skin_sfx/common/torch_tesla",
})
