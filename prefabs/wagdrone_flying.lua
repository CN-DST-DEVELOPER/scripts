local assets =
{
	Asset("ANIM", "anim/wagdrone_flying.zip"),
	Asset("ANIM", "anim/wagdrone_projectile.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local prefabs =
{
	"wagdrone_projectile_fx",
	"wagdrone_parts",
	"gears",
	"transistor",
	"wagpunk_bits",
}

local easing = require("easing")
local WagdroneCommon = require("prefabs/wagdrone_common")

--------------------------------------------------------------------------

local function Target_OnUpdateFlicker(fx, dt)
	if dt > 0 then
		fx.flicker = (fx.flicker + 1) % 5
		if fx.flicker == 0 then
			fx.AnimState:SetMultColour(1, 1, 1, 0.2)
		elseif fx.flicker == 2 then
			fx.AnimState:SetMultColour(1, 1, 1, 0.3)
		end
	end
end

local function CreateTargetingFx()
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(TheWorld.ismastersim)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddSoundEmitter()

	fx.AnimState:SetBuild("wagdrone_projectile")
	fx.AnimState:SetBank("wagdrone_projectile")
	fx.AnimState:PlayAnimation("marker_pre")
	fx.AnimState:PushAnimation("marker_loop")
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)
	fx.AnimState:SetLightOverride(1)
	fx.AnimState:SetMultColour(1, 1, 1, 0.3)

	fx:AddComponent("updatelooper")
	fx.components.updatelooper:AddOnUpdateFn(Target_OnUpdateFlicker)
	fx.flicker = 0

	fx.persists = false

	return fx
end

local function Target_SyncMarkerAnim(inst, fx)
	if inst.AnimState:IsCurrentAnimation("atk_pre") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		local prelen = fx.AnimState:GetCurrentAnimationNumFrames()
		if frame < prelen then
			fx.AnimState:SetFrame(frame)
		else
			fx.AnimState:PlayAnimation("marker_loop", true)
			fx.AnimState:SetFrame(frame - prelen)
		end
		return true
	end
	return false
end

local function Target_OnPostUpdate(fx)
	local x, y, z = fx.parent.Transform:GetWorldPosition()
	fx.Transform:SetPosition(0, -y, 0)

	if fx.syncanim then
		fx.syncanim = false
		if not Target_SyncMarkerAnim(fx.parent, fx) then
			fx.AnimState:PlayAnimation("marker_loop", true)
			fx.AnimState:SetFrame(math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1)
		end
	end
end

local function Target_OnUpdateCancel(fx, dt)
	local duration = 0.2
	fx.t = fx.t + dt
	if fx.t < duration then
		local a = easing.outQuad(fx.t, 1, -1, duration)
		fx.AnimState:SetMultColour(1, 1, 1, a)
	else
		fx:Remove()
	end
end

local function OnTargetingDirty(inst)
	local fx = inst.targetingfx
	local state = inst.targeting:value()
	--2: show
	--1: commit (scale up + fade out)
	--0: cancel (quick fade out)
	if state == 2 then
		if fx == nil then
			fx = CreateTargetingFx()
			fx.entity:SetParent(inst.entity)
			fx.parent = inst
			inst.targetingfx = fx
			fx.syncanim = not (TheWorld.ismastersim or Target_SyncMarkerAnim(inst, fx))
			fx.components.updatelooper:AddPostUpdateFn(Target_OnPostUpdate)
			Target_OnPostUpdate(fx)
			fx.SoundEmitter:PlaySound("rifts5/wagdrone_flying/electro_ball_aim_LP", "loop")
		end
	elseif fx then
		inst.targetingfx = nil

		local x, y, z = fx.Transform:GetWorldPosition()
		fx.entity:SetParent(nil)
		fx.Transform:SetPosition(x, 0, z)
		if fx:IsAsleep() then
			fx:Remove()
		else
			fx.OnEntitySleep = fx.Remove
			fx.parent = nil
			fx.components.updatelooper:RemovePostUpdateFn(Target_OnPostUpdate)
			if state == 1 then
				fx.AnimState:PlayAnimation("marker_pst")
				fx:ListenForEvent("animover", fx.Remove)
			else
				fx.t = 0
				fx.components.updatelooper:AddOnUpdateFn(Target_OnUpdateCancel)
			end
		end
	end
end

local function ShowTargeting(inst, show, commit)
	if (show ~= false) ~= (inst.targeting:value() == 2) then
		inst.targeting:set((show and 2) or (commit and 1) or 0)
		if not TheNet:IsDedicated() then
			OnTargetingDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	data.on = not inst.sg.mem.turnoff and (inst.sg.mem.turnon or not inst.sg:HasStateTag("off")) or nil
	data.isloot = inst.components.workable ~= nil or nil
end

local function OnLoad(inst, data, ents)
	if data and data.on then
		inst.sg:GoToState("idle")
	elseif inst.sg:HasStateTag("off") then
		local x, y, z = inst.Transform:GetWorldPosition()
		if y ~= 0 then
			inst.Physics:Teleport(x, 0, z)
		end
	end
	if data and data.isloot then
		WagdroneCommon.ChangeToLoot(inst)
	end
end

local function PostUpdate(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	inst.AnimState:SetSortWorldOffset(0, -y, 0)
end

local function GetStatus(inst, viewer)
	return (inst.components.workable and "DAMAGED")
		or (inst.sg:HasStateTag("off") and "INACTIVE")
		or nil
end

local function fn()
	local inst = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	--Initial stategraph state "off_idle" will setup dynamic shadow
	--inst.Transform:SetFourFaced() --only use facing model during run states

	inst.AnimState:SetBuild("wagdrone_flying")
	inst.AnimState:SetBank("wagdrone_flying")
	inst.AnimState:PlayAnimation("off_idle")
	inst.AnimState:OverrideSymbol("bolt_c", "wagdrone_projectile", "bolt_c")
	inst.AnimState:SetSymbolBloom("bolt_c")
	inst.AnimState:SetSymbolLightOverride("bolt_c", 1)
	--inst.AnimState:SetSymbolBloom("fx_ray")
	inst.AnimState:SetSymbolLightOverride("fx_ray", 1)
	inst.AnimState:SetSymbolLightOverride("light_yellow_on", 0.5)
	inst.AnimState:SetSymbolBloom("light_yellow_on")
	inst.AnimState:Hide("LIGHT_ON")

	inst.Light:SetRadius(0.5)
	inst.Light:SetIntensity(0.8)
	inst.Light:SetFalloff(0.5)
	inst.Light:SetColour(255/255, 255/255, 236/255)
	inst.Light:Enable(false)

	MakeFlyingCharacterPhysics(inst, 50, 0.4)

	inst:AddTag("mech")
	inst:AddTag("electricdamageimmune")
	inst:AddTag("soulless")
	inst:AddTag("lunar_aligned")
	inst:AddTag("wagdrone")

	inst.targeting = net_tinybyte(inst.GUID, "wagdrone_flying.targeting", "targetingdirty")

	if not TheNet:IsDedicated() then
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(PostUpdate)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("targetingdirty", OnTargetingDirty)

		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("locomotor")
	inst.components.locomotor.runspeed = TUNING.WAGDRONE_FLYING_RUNSPEED
	--V2C: -using directdrive to bypass pathfinding
	--     -hack speed mult to prevent run_start from moving right away (see stategraph)
	inst.components.locomotor.directdrive = true
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, "run_start", 0)

	WagdroneCommon.MakeHackable(inst)
	WagdroneCommon.PreventTeleportFromArena(inst)

	inst:SetStateGraph("SGwagdrone_flying")

	inst.ShowTargeting = ShowTargeting
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	inst.OnLoadPostPass = WagdroneCommon.HackableLoadPostPass

	return inst
end

return Prefab("wagdrone_flying", fn, assets, prefabs)
