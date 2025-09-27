local assets =
{
	Asset("ANIM", "anim/hat_alterguardian_equipped.zip"),
}

local easing = require("easing")

local function OnActivated(inst, owner, is_front)
	inst.entity:SetParent(owner.entity)
	inst.entity:AddFollower()
	inst.Follower:FollowSymbol(owner.GUID, "hair", 0, 0, 0) -- "swap_hat"

	inst.AnimState:Hide(is_front and "back" or "front")
	inst.AnimState:SetFinalOffset(is_front and 1 or -1)

	inst.AnimState:PlayAnimation("activate_pre")
	inst.AnimState:PushAnimation("activate_loop", true)
end

local function OnDeactivated(inst)
	inst.AnimState:PlayAnimation("activate_pst")
	inst:ListenForEvent("animover", inst.Remove)
end

local function SetSkin(inst, skin_build, GUID)
    inst.AnimState:OverrideItemSkinSymbol("p4_piece", skin_build, "p4_piece", GUID, "hat_alterguardian_equipped")
    inst.AnimState:OverrideItemSkinSymbol("fx_glow", skin_build, "fx_glow", GUID, "hat_alterguardian_equipped")
end

local function OnSnowLevel(inst, snowlevel)
	inst.AnimState:SetSymbolMultColour("flame_outline_swap", 1, 1, 1, easing.outQuad(snowlevel, 0, 0.3, 1))
end

local function SetFlameLevel(inst, level, skin_build, parent_GUID)
	level = level ~= 0 and level or nil
	if level ~= inst.level then
		if level then
			local suffix = level >= 2 and "_loop" or "_loop_small"
			if skin_build then
				inst.AnimState:OverrideItemSkinSymbol("flame_swap", skin_build, "flame"..suffix, parent_GUID, "hat_alterguardian_equipped")
				inst.AnimState:OverrideItemSkinSymbol("flame_outline_swap", skin_build, "flame_outline"..suffix, parent_GUID, "hat_alterguardian_equipped")
			else
				inst.AnimState:OverrideSymbol("flame_swap", "hat_alterguardian_equipped", "flame"..suffix)
				inst.AnimState:OverrideSymbol("flame_outline_swap", "hat_alterguardian_equipped", "flame_outline"..suffix)
			end
			if inst.level == nil then
				inst:WatchWorldState("snowlevel", OnSnowLevel)
				OnSnowLevel(inst, TheWorld.state.snowlevel)
			end
		else
			inst.AnimState:ClearOverrideSymbol("flame_swap")
			inst.AnimState:ClearOverrideSymbol("flame_outline_swap")
			inst:StopWatchingWorldState("snowlevel", OnSnowLevel)
		end
		inst.level = level
	end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("hat_alterguardian_equipped")
    inst.AnimState:SetBuild("hat_alterguardian_equipped")
    inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFinalOffset(1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetSymbolMultColour("flame_swap", 1, 1, 1, 0.2)
	inst.AnimState:SetSymbolLightOverride("flame_swap", 0.5)

	inst.Transform:SetNoFaced()

    inst:AddTag("FX")
    inst:AddTag("DECOR")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	--inst.level = nil
    inst.persists = false

    inst.SetSkin = SetSkin
	inst.SetFlameLevel = SetFlameLevel
	inst.OnActivated = OnActivated
	inst.OnDeactivated = OnDeactivated

    return inst
end

return Prefab("alterguardian_hat_equipped", fn, assets)
