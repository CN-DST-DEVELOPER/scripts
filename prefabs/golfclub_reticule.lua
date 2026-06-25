local assets =
{
	Asset("ANIM", "anim/golfclub_reticule.zip"),
}

local prefabs =
{
	"golfclub_reticuleping",
}

local PAD_DURATION = .1
local SCALE = 1.5
local FLASH_TIME = .3

local function UpdatePing(inst, s0, s1, t0, duration, multcolour, addcolour)
    if next(multcolour) == nil then
        multcolour[1], multcolour[2], multcolour[3], multcolour[4] = inst.AnimState:GetMultColour()
    end
    if next(addcolour) == nil then
        addcolour[1], addcolour[2], addcolour[3], addcolour[4] = inst.AnimState:GetAddColour()
    end
    local t = GetTime() - t0
    local k = 1 - math.max(0, t - PAD_DURATION) / duration
    k = 1 - k * k
    local c = Lerp(1, 0, k)
	inst.AnimState:SetScale(SCALE * Lerp(s0[1], s1[1], k), SCALE * Lerp(s0[2], s1[2], k))
    inst.AnimState:SetMultColour(multcolour[1], multcolour[2], multcolour[3], c * multcolour[4])

    k = math.min(FLASH_TIME, t) / FLASH_TIME
    c = math.max(0, 1 - k * k)
    inst.AnimState:SetAddColour(c * addcolour[1], c * addcolour[2], c * addcolour[3], c * addcolour[4])
end

local function SetChargeScale(inst, chargescale)
	inst.chargescale = chargescale
	if chargescale == 1 then
		if not inst.AnimState:IsCurrentAnimation("charged_loop") then
			inst.AnimState:PlayAnimation("charged_loop", true)
		end
	else
		inst.AnimState:SetPercent("charge_pre", chargescale)
	end

	if inst.chargingsfx and chargescale > 0 and not TheFocalPoint.SoundEmitter:PlayingSound("golfclub_reticule_windup") then
		TheFocalPoint.SoundEmitter:PlaySound("dontstarve/common/golf_windup_LP", "golfclub_reticule_windup")
	end
end

local function charging_OnRemoveEntity(inst)
	TheFocalPoint.SoundEmitter:KillSound("golfclub_reticule_windup")
end

local function MakeReticule(name, charging, ping, _prefabs)
    local function fn()
        local inst = CreateEntity()

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        --[[Non-networked entity]]
        inst.entity:SetCanSleep(false)
        inst.persists = false

        inst.entity:AddTransform()
        inst.entity:AddAnimState()

        inst.AnimState:SetBank("golfclub_reticule")
        inst.AnimState:SetBuild("golfclub_reticule")
        inst.AnimState:PlayAnimation("idle")
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
        inst.AnimState:SetScale(SCALE, SCALE)

        if ping then
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

            local duration = .4
            inst:DoPeriodicTask(0, UpdatePing, nil, { 1, 1 }, { 1.04, 1.3 }, GetTime(), duration, {}, {})
            inst:DoTaskInTime(duration, inst.Remove)

			inst.chargescale = 1
			inst.SetChargeScale = SetChargeScale
		elseif charging then
			inst:AddComponent("chargingreticule")
			inst.components.chargingreticule.ease = true
			inst.components.chargingreticule.pingprefab = "golfclub_reticuleping"

			inst.chargescale = 1
			inst.SetChargeScale = SetChargeScale
			inst.chargingsfx = true
			inst.OnRemoveEntity = charging_OnRemoveEntity
        end

        return inst
    end

    return Prefab(name, fn, assets, _prefabs)
end

----

return MakeReticule("golfclub_reticule_fx", false, false),
	MakeReticule("golfclub_reticulecharging", true, false, prefabs),
	MakeReticule("golfclub_reticuleping", true, true)