local assets =
{
	Asset("ANIM", "anim/shadow_thrall_parasite.zip"),
}

local prefabs =
{
	"shadow_thrall_parasitehat",
	"player_hosted",
	"shadowthrall_parasite_fx",
	"mask_sagehat",
	"mask_halfwithat",
	"mask_toadyhat",
	"shadowthrall_parasite_attach_poof_fx",
}

local brain = require("brains/shadowthrall_parasite_brain")

SetSharedLootTable("shadowthrall_parasite",
{
	{ "horrorfuel",		0.50 },
	{ "nightmarefuel",	0.67 },
})

local function DisplayNameFn(inst)
	return ThePlayer ~= nil and ThePlayer:HasTag("player_shadow_aligned") and STRINGS.NAMES.SHADOWTHRALL_PARASITE_ALLEGIANCE or nil
end

--------------------------------------------------------------------------

local function CreateHairFx()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	if not TheWorld.ismastersim then
		inst.entity:SetCanSleep(false)
	end
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()

	inst.AnimState:SetBank("shadow_thrall_parasite")
	inst.AnimState:SetBuild("shadow_thrall_parasite")
	inst.AnimState:PlayAnimation("fx_1", true)
	--inst.AnimState:SetSymbolLightOverride("fx_flame_red", 1)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()))

	return inst
end

local function OnColourChanged(inst, r, g, b, a)
	for i, v in ipairs(inst.highlightchildren) do
		v.AnimState:SetAddColour(r, g, b, a)
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddNetwork()

	MakeGhostPhysics(inst, 1, .5)

	inst.DynamicShadow:SetSize(2, 1)
	inst.Transform:SetSixFaced()

	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("scarytoprey")
	inst:AddTag("shadowthrall")
	inst:AddTag("shadow_aligned")
	inst:AddTag("flying")

	inst.AnimState:SetBank("shadow_thrall_parasite")
	inst.AnimState:SetBuild("shadow_thrall_parasite")
	inst.AnimState:PlayAnimation("idle", true)

	inst.scrapbook_anim = "scrapbook"

	inst:AddComponent("colouraddersync")

	--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		local hair = CreateHairFx()
		hair.entity:SetParent(inst.entity)
		hair.Follower:FollowSymbol(inst.GUID, "follow_fx_swap", nil, nil, nil, true)

		inst.highlightchildren = { hair }
		inst.highlightchildren = {}
		inst.components.colouraddersync:SetColourChangedFn(OnColourChanged)
	end

	inst.displaynamefn = DisplayNameFn

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("sanityaura")
	inst.components.sanityaura.aura = -TUNING.SANITYAURA_MED

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.SHADOWTHRALL_PARASITE_WALKSPEED
	inst.components.locomotor.runspeed = TUNING.SHADOWTHRALL_PARASITE_RUNSPEED

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.SHADOWTHRALL_PARASITE_HEALTH)
	inst.components.health.invincible = true

	inst:AddComponent("combat")

	inst:AddComponent("planarentity")

	inst:AddComponent("colouradder")
	inst:AddComponent("knownlocations")
	inst:AddComponent("entitytracker")

	inst.persists = false

	inst:SetStateGraph("SGshadowthrall_parasite")
	inst:SetBrain(brain)

	inst.OnEntitySleep = inst.Remove

	return inst
end

local function fx_onanimover(inst)
	local target = inst.target

	inst:Remove()

	if target == nil or not target:IsValid() or target.components.inventory == nil or target.components.health == nil then
		return
	end

	local mask = SpawnPrefab("shadow_thrall_parasitehat")

	if mask == nil then
		return
	end

	target.components.inventory:GiveItem(mask)
	target.components.inventory:Equip(mask)

	if target.SoundEmitter ~= nil then
		target.SoundEmitter:PlaySound("hallowednights2024/thrall_parasite/possess_kill_monster")
	end

	target.components.health:SetPercent(1)
	target.sg:GoToState("parasite_revive")

	local fx = SpawnPrefab("shadowthrall_parasite_attach_poof_fx")
	fx.entity:AddFollower()
	fx.Follower:FollowSymbol(target.GUID, "swap_hat", 0, 0, 0)

	inst:Remove()
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:AddTag("fx")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("shadow_thrall_parasite")
	inst.AnimState:SetBuild("shadow_thrall_parasite")
	inst.AnimState:PlayAnimation("atk")

	inst.SoundEmitter:PlaySound("hallowednights2024/thrall_parasite/thrall_idle_LP", "idle_lp")

	if not TheNet:IsDedicated() then
		local hair = CreateHairFx()
		hair.entity:SetParent(inst.entity)
		hair.Follower:FollowSymbol(inst.GUID, "follow_fx_swap", nil, nil, nil, true)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst:ListenForEvent("animover", fx_onanimover)
	inst.persists = false

	return inst
end


return 	Prefab("shadowthrall_parasite", fn, assets, prefabs),
		Prefab("shadowthrall_parasite_fx", fxfn, assets, prefabs)
