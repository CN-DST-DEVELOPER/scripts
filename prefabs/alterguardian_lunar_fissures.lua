local easing = require("easing")
local WagBossUtil = require("prefabs/wagboss_util")

local assets =
{
	Asset("ANIM", "anim/wagboss_fissure.zip", ALT_RENDERPATH),
}

local assets_burn_fx =
{
	Asset("ANIM", "anim/wagboss_lunar_blast.zip"),
}

local prefabs =
{
	"alterguardian_lunar_fissure_burn_fx",
}

local TRANSPARENCY = 0.5

--------------------------------------------------------------------------

local REGISTERED_AOE_TAGS
local AOE_RANGE_PADDING = 3
local TILE_SIZE = 4
local DIAG_TILE_SIZE = math.sqrt(2 * TILE_SIZE * TILE_SIZE)

--cx, cz, r: circle coords & radius
--sx, sz, hl: square coords & half length of one side
local function CircleTouchesSquare(cx, cz, r, sx, sz, hl)
	local sx1, sx2 = sx - hl, sx + hl
	local sz1, sz2 = sz - hl, sz + hl
	return cx > sx1 and cx < sx2 and cz > sz1 and cz < sz2
		or distsq(cx, cz, math.clamp(cx, sx1, sx2), math.clamp(cz, sz1, sz2)) < r * r
end

local function OnUpdate(inst)
	if inst:IsAsleep() then
		inst.task:Cancel()
		inst.task = nil
		return
	end

	if REGISTERED_AOE_TAGS == nil then
		REGISTERED_AOE_TAGS = TheSim:RegisterFindTags(
			{ "_health" },
			{ "FX", "DECOR", "INLIMBO", "flight", "noattack", "notarget", "invisible", "wall", "brightmare", "brightmareboss", "shadowcreature" }
		)
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	local radius = DIAG_TILE_SIZE / 2
	local boxrange = TILE_SIZE / 2
	for i, v in ipairs(TheSim:FindEntities_Registered(x, 0, z, radius + AOE_RANGE_PADDING, REGISTERED_AOE_TAGS)) do
		if v.components.lunarfissureburning == nil and v:IsValid() and not v:IsInLimbo() then
			local physrad = v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if CircleTouchesSquare(x1, z1, physrad, x, z, boxrange) then
				v:AddComponent("lunarfissureburning")
			end
		end
	end
end

local function StartUpdateTask(inst)
	if inst.task == nil then
		inst.task = inst:DoPeriodicTask(0.5, OnUpdate, math.random() * 0.5)
	end
end

--------------------------------------------------------------------------

local FADE_TIME = 1

local EndFadeIn --forward declare

local function UpdateFadeIn(inst, dt)
	if inst.pre then
		local t = inst.AnimState:GetCurrentAnimationTime()
		local len = inst.AnimState:GetCurrentAnimationLength()
		local a = easing.inQuad(t, 0, TRANSPARENCY / 2, len)
		inst.AnimState:SetMultColour(1, 1, 1, a)
	else
		inst._fadeint = inst._fadeint + dt

		if inst._fadeint < FADE_TIME then
			local a = easing.outQuad(inst._fadeint, 1, TRANSPARENCY - 1, FADE_TIME)
			inst.AnimState:SetMultColour(1, 1, 1, a)
		else
			EndFadeIn(inst)
		end
	end
end

EndFadeIn = function(inst)
	inst.components.updatelooper:RemoveOnUpdateFn(UpdateFadeIn)
	inst._fadeint = nil
	inst.AnimState:SetMultColour(1, 1, 1, TRANSPARENCY)
end

--------------------------------------------------------------------------

local function GetBaseAnim(variation)
	return "tile"..tostring(variation)
end

local function OnAnimOver(inst)
	inst:RemoveEventCallback("animover", OnAnimOver)
	inst.pre = nil
	inst.AnimState:PlayAnimation(GetBaseAnim(inst.variation).."_loop", true)

	inst.OnEntityWake = StartUpdateTask
	if not inst:IsAsleep() then
		StartUpdateTask(inst)
		if not POPULATING then
			OnUpdate(inst)
		end
	end
end

local function KillMe(inst)
	if inst.task then
		inst.task:Cancel()
		inst.task = nil
	end
	if inst.pre then
		inst:RemoveEventCallback("animover", OnAnimOver)
	end
	if inst._fadeint then
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateFadeIn)
	end
	inst.OnEntityWake = nil
	inst.OnEntitySleep = inst.Remove
	WagBossUtil.DespawnFissure(inst, GetBaseAnim(inst.variation))
end

local function StartTrackingBoss(inst, boss)
	local oldboss = inst.components.entitytracker:GetEntity("boss")
	if boss ~= oldboss then
		if oldboss then
			inst:RemoveEventCallback("onremove", inst._onremoveboss, oldboss)
			inst:RemoveEventCallback("death", inst._onremoveboss, oldboss)
			inst:RemoveEventCallback("resetboss", inst._onremoveboss, oldboss)
			inst.components.entitytracker:ForgetEntity("boss")
		end
		if boss and boss:IsValid() then
			inst.components.entitytracker:TrackEntity("boss", boss)
			inst:ListenForEvent("onremove", inst._onremoveboss, boss)
			inst:ListenForEvent("death", inst._onremoveboss, boss)
			inst:ListenForEvent("resetboss", inst._onremoveboss, boss)
		end
	end
end

local function OnSave(inst, data)
	data.variation = inst.variation ~= 1 and inst.variation or nil
end

local function OnLoad(inst, data)--, ents)
	if data and data.size then
		--backward compatibility: we used to support grid size 1, 2, 3, & 4
		if data.size > 1 then
			local x, y, z = inst.Transform:GetWorldPosition()
			local offs = TILE_SIZE * (data.size - 1) / 2
			inst.Transform:SetPosition(x - offs, 0, z - offs)
		end
		--keep random variation
	else
		inst.variation = data and data.variation or 1
	end

	OnAnimOver(inst)
	EndFadeIn(inst)
	WagBossUtil.OnLoadFissure(inst)
end

local function OnLoadPostPass(inst, ents, data)
	local boss = inst.components.entitytracker:GetEntity("boss")
	if boss then
		inst:ListenForEvent("onremove", inst._onremoveboss, boss)
		inst:ListenForEvent("death", inst._onremoveboss, boss)
		inst:ListenForEvent("resetboss", inst._onremoveboss, boss)
	else
		KillMe(inst)
	end

	if data and data.size and data.size > 1 and (inst.persists or (inst:IsValid() and not inst:IsAsleep())) then
		--backward compatibility: we used to support grid size 1, 2, 3, & 4
		local x0, _, z1 = inst.Transform:GetWorldPosition()
		for row = 1, data.size do
			local x1 = row > 1 and x0 or x0 + TILE_SIZE
			for col = row > 1 and 1 or 2, data.size do
				local newfissure = SpawnPrefab("alterguardian_lunar_fissures")
				newfissure.Transform:SetPosition(x1, 0, z1)
				OnAnimOver(newfissure)
				EndFadeIn(newfissure)
				WagBossUtil.OnLoadFissure(newfissure)
				if boss then
					StartTrackingBoss(newfissure, boss)
				else
					KillMe(newfissure)
				end
				x1 = x1 + TILE_SIZE
			end
			z1 = z1 + TILE_SIZE
		end
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("wagboss_fissure")
	inst.AnimState:SetBuild("wagboss_fissure")
	inst.AnimState:PlayAnimation("tile1_pre")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(2)
	inst.AnimState:SetMultColour(1, 1, 1, 0)
	inst.AnimState:SetForceSinglePass(true)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.pre = true
	inst:ListenForEvent("animover", OnAnimOver)

	inst:AddComponent("entitytracker")

	inst:AddComponent("updatelooper")
	inst.components.updatelooper:AddOnUpdateFn(UpdateFadeIn)
	inst._fadeint = 0

	inst._onremoveboss = function(boss)
		inst:RemoveEventCallback("onremove", inst._onremoveboss, boss)
		inst:RemoveEventCallback("death", inst._onremoveboss, boss)
		inst:RemoveEventCallback("resetboss", inst._onremoveboss, boss)
		KillMe(inst)
	end

	inst.variation = math.random(4)
	if inst.variation ~= 1 then
		inst.AnimState:PlayAnimation(GetBaseAnim(inst.variation).."_pre")
	end

	inst.StartTrackingBoss = StartTrackingBoss
	inst.KillFx = KillMe
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

local function fissure_SetFxSize(inst, size)
	local anim = "fissure_hit_"..size
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim, true)
	end
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("wagboss_lunar_blast")
	inst.AnimState:SetBuild("wagboss_lunar_blast")
	inst.AnimState:PlayAnimation("fissure_hit_small", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)
	inst.AnimState:SetFinalOffset(3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.SetFxSize = fissure_SetFxSize
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local function supernova_SetFxSize(inst, size)
	local anim = "supernova_hit_"..size
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim, true)
	end
end

local function supernovafxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("wagboss_lunar_blast")
	inst.AnimState:SetBuild("wagboss_lunar_blast")
	inst.AnimState:PlayAnimation("supernova_hit_small", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.3)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.SetFxSize = supernova_SetFxSize
	inst.persists = false

	return inst
end

return Prefab("alterguardian_lunar_fissures", fn, assets, prefabs),
	Prefab("alterguardian_lunar_fissure_burn_fx", fxfn, assets_burn_fx),
	Prefab("alterguardian_lunar_supernova_burn_fx", supernovafxfn, assets_burn_fx)
