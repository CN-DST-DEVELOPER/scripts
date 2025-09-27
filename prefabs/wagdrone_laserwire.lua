local assets =
{
	Asset("ANIM", "anim/wagdrone_laserwire_fx.zip"),
	Asset("SCRIPT", "scripts/prefabs/wagdrone_common.lua"),
}

local WagdroneCommon = require("prefabs/wagdrone_common")

local function CreateSegFxBase()
	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBuild("wagdrone_laserwire_fx")
	fx.AnimState:SetBank("wagdrone_laserwire_fx")
	fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

	fx.persists = false

	return fx
end

local function CreateSegFxShadow(seg, rot, scale, isend)
	local fx = CreateSegFxBase()

	fx.Transform:SetRotation(rot)

	fx.AnimState:SetScale(scale, 1)
	fx.AnimState:SetMultColour(1, 1, 1, isend and 0.03 or 0.04)
	fx.AnimState:SetLightOverride(1)
	fx.AnimState:SetLayer(LAYER_BACKGROUND)
	fx.AnimState:SetSortOrder(3)

	fx.entity:SetParent(seg.entity)

	return fx
end

local variations = { 1, 1, 1, 2, 3, 4, 4, 4 }

local function RandomizeAnim(fx)
	local variation = tostring(variations[math.random(#variations)])
	fx.AnimState:PlayAnimation("beam_"..variation)
	fx.shadow.AnimState:PlayAnimation("shadow_"..variation)
end

local function CreateSegFx(seg, rot, scale, isend)
	local fx = CreateSegFxBase()

	fx.Transform:SetRotation(rot)

	fx.AnimState:SetScale(scale, 1)
	fx.AnimState:SetLightOverride(1)

	fx.entity:SetParent(seg.entity)
	fx.Follower:FollowSymbol(seg.GUID, "marker")

	fx.shadow = CreateSegFxShadow(seg, rot, scale, isend)

	fx:ListenForEvent("animover", RandomizeAnim)
	RandomizeAnim(fx)

	local frame = math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
	fx.AnimState:SetFrame(frame)
	fx.shadow.AnimState:SetFrame(frame)

	fx.persists = false

	return fx
end

local function CreateSegAt(inst, x, z, rot, scale, isend, animoverride)
	local seg = CreateEntity()

	seg:AddTag("FX")
	seg:AddTag("NOCLICK")
	--[[Non-networked entity]]
	seg.entity:SetCanSleep(false)
	seg.persists = false

	seg.entity:AddTransform()
	seg.entity:AddAnimState()

	seg.entity:SetParent(inst.entity)
	seg.Transform:SetPosition(x, 0, z)

	seg.AnimState:SetBuild("wagdrone_laserwire_fx")
	seg.AnimState:SetBank("wagdrone_laserwire_fx")
	seg.AnimState:PlayAnimation(animoverride or "follow_marker")

	seg.persists = false

	--fx will be ground oriented, but raised by following the billboard "follow_marker" symbol
	CreateSegFx(seg, rot, scale, isend)

	return seg
end

local function ClearSegs(inst)
	if inst.segs then
		for i, v in ipairs(inst.segs) do
			v:Remove()
		end
		inst.segs = nil
	end

	--[[if not TheWorld.ismastersim then
		return
	end]] --it's fine to run the cleanup code on clients anyway

	if inst.targettask then
		inst.targettask:Cancel()
		inst.targettask = nil
	end
end
--local OnEntitySleep = ClearSegs --this is set in prefab constructor

local MAX_LEN = 15
local SEG_LEN = 2
local TARGET_SPACING = 4
local TARGET_RADIUS = TARGET_SPACING * 1.5
local TARGET_RANGE = 0.1 --distance from beam
local SLOW_PERIOD = 1
local FAST_PERIOD = 2 * FRAMES
local SHOCK_COOLDOWN = 1

local function UpdateTargets(inst, p1, p2, pv, targets)
	local t = GetTime()
	local nextperiod = SLOW_PERIOD
	for i, x in ipairs(inst.targetx) do
		local z = inst.targetz[i]
		for _, v in ipairs(WagdroneCommon.FindShockTargets(x, z, TARGET_RADIUS)) do
			if (targets[v] or -math.huge) < t and
				v:IsValid() and not v:IsInLimbo()
			then
				pv.x, _, pv.y = v.Transform:GetWorldPosition()
				local range = TARGET_RANGE + v:GetPhysicsRadius(0)
				if DistPointToSegmentXYSq(pv, p1, p2) < range * range then
					if not (v.components.health and v.components.health:IsDead()) and
						v.components.combat and inst.components.combat:CanTarget(v)
					then
						if IsEntityElectricImmune(v) then
							inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_LASERWIRE_DAMAGE * TUNING.WAGDRONE_LASERWIRE_INSULATED_DAMAGE_MULT)
							inst.components.combat:DoAttack(v, nil, nil, "electric")
							inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_LASERWIRE_DAMAGE)
						else
							inst.components.combat:DoAttack(v, nil, nil, "electric")
							v:PushEventImmediate("electrocute") -- (NOTE): Don't add electric tag to laserwire, or it counts as a fork attack! we dont want that!
						end
					end
					targets[v] = t + SHOCK_COOLDOWN
				end
			end
			nextperiod = FAST_PERIOD
		end
	end

	if inst.targettask then
		if inst.targettask.period == nextperiod then
			return
		end
		inst.targettask:Cancel()
	end
	local initialperiod = nextperiod ~= FAST_PERIOD and (0.5 + 0.5 * math.random()) * nextperiod or nil
	inst.targettask = inst:DoPeriodicTask(nextperiod, UpdateTargets, initialperiod, p1, p2, pv, targets)
end

local function RefreshSegs(inst, animoverride)
	local len = inst.len:value() / 255 * MAX_LEN
	local rot = inst.rot:value() / 255 * 360
	local theta = rot * DEGREES
	local costheta = math.cos(theta)
	local sintheta = math.sin(theta)

	if inst.segs == nil and not TheNet:IsDedicated() then
		inst.segs = {}
		local num = math.max(1, math.floor(len / SEG_LEN + 0.5))
		local scale = len / (num * SEG_LEN)
		local spacing = len / num
		local dx = spacing * costheta
		local dz = -spacing * sintheta
		local dstart = (1 - num) / 2
		local x = dx * dstart
		local z = dz * dstart
		for i = 1, num do
			inst.segs[i] = CreateSegAt(inst, x, z, rot, scale, i == 1 or i == num, animoverride)
			x = x + dx
			z = z + dz
		end
	end

	if not TheWorld.ismastersim then
		return
	end

	if inst.targetx == nil then
		inst.targetx = {}
		inst.targetz = {}
		local num = math.floor(len / TARGET_SPACING) + 1
		local dx = TARGET_SPACING * costheta
		local dz = -TARGET_SPACING * sintheta
		local dstart = (1 - num) / 2
		local x, y, z = inst.Transform:GetWorldPosition()
		local x = x + dx * dstart
		local z = z + dz * dstart
		for i = 1, num do
			inst.targetx[i] = x
			inst.targetz[i] = z
			x = x + dx
			z = z + dz
		end
	end

	if inst.targettask then
		if inst.targettask.period == FAST_PERIOD then
			return
		end
		inst.targettask:Cancel()
	end
	local p1 = { x = inst.targetx[1], y = inst.targetz[1] }
	local p2 = { x = inst.targetx[#inst.targetx], y = inst.targetz[#inst.targetz] }
	local pv = {}
	local targets = {}
	inst.targettask = inst:DoPeriodicTask(SLOW_PERIOD, UpdateTargets, math.random() * 0.3, p1, p2, pv, targets)
	inst.targettask.period = SLOW_PERIOD
end
--local OnEntityWake = RefreshSegs --this is set in prefab constructor

local function OnBeamDirty(inst)
	ClearSegs(inst)
	RefreshSegs(inst)
end

local function SetBeam(inst, len, rot)
	inst.len:set_local(0) --force dirty, because we might be calling this when moved
	inst.len:set(math.min(255, math.floor(len / MAX_LEN * 255 + 0.5)))
	inst.rot:set(math.floor((rot < 0 and rot + 360 or rot) / 360 * 255 + 0.5))

	if not inst:IsAsleep() then
		OnBeamDirty(inst)
	end
end

local function KeepTargetFn(inst)--, target)
	return false
end

local function CanMouseThrough() -- So that we don't block trying to select other entities.
	return true, false
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("notarget")

	inst.len = net_byte(inst.GUID, "wagdrone_laserwire_fx.len", "beamdirty")
	inst.rot = net_byte(inst.GUID, "wagdrone_laserwire_fx.rot", "beamdirty")

	inst:SetPrefabNameOverride("wagdrone_rolling") --for death announce
	inst.CanMouseThrough = CanMouseThrough

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("beamdirty", OnBeamDirty)

		return inst
	end

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_LASERWIRE_DAMAGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	inst.components.combat.ignorehitrange = true

	inst.targettask = nil
	inst.SetBeam = SetBeam
	inst.OnEntitySleep = ClearSegs
	inst.OnEntityWake = RefreshSegs

	inst.persists = false

	return inst
end

----------------------

local function RefreshSegs_CageWall(inst)
    RefreshSegs(inst, "follow_marker_cage")
end
local function OnBeamDirty_CageWall(inst)
	ClearSegs(inst)
	RefreshSegs_CageWall(inst)
end

local function SetBeam_CageWall(inst, len, rot)
	inst.len:set_local(0) --force dirty, because we might be calling this when moved
	inst.len:set(math.min(255, math.floor(len / MAX_LEN * 255 + 0.5)))
	inst.rot:set(math.floor((rot < 0 and rot + 360 or rot) / 360 * 255 + 0.5))

	if not inst:IsAsleep() then
		OnBeamDirty_CageWall(inst)
	end
end

local function fn_cagewall()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("notarget")

    inst.len = net_byte(inst.GUID, "wagdrone_laserwire_fx.len", "beamdirty")
    inst.rot = net_byte(inst.GUID, "wagdrone_laserwire_fx.rot", "beamdirty")

	inst:SetPrefabNameOverride("wagpunk_cagewall") --for death announce

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst:ListenForEvent("beamdirty", OnBeamDirty_CageWall)
        return inst
    end

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.WAGDRONE_LASERWIRE_DAMAGE)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat.ignorehitrange = true

    inst.targettask = nil
    inst.SetBeam = SetBeam_CageWall
    inst.OnEntitySleep = ClearSegs
    inst.OnEntityWake = RefreshSegs_CageWall

    inst.persists = false

    return inst
end

return Prefab("wagdrone_laserwire_fx", fn, assets),
    Prefab("wagpunk_cagewall_fx", fn_cagewall, assets)