local easing = require("easing")
local AOEUtil = require("aoeutil")

local assets =
{
	Asset("ANIM", "anim/shrouden_blast.zip"),
}

local BEAM_RADIUS = 2
local BEAM_RADIUS_WIDE = 5
local ALPHA = 0.8
local FALOFF_WIDE = 0.98

local function RecycleSmoke(smoke)
	if smoke.owner._smokepool then
		smoke:RemoveFromScene()
		table.insert(smoke.owner._smokepool, smoke)
	else
		smoke:Remove()
	end
end

local function CreateSmoke()
	local smoke = CreateEntity()

	--[[Non-networked entity]]
	smoke.entity:SetCanSleep(false)
	smoke.persists = false

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	smoke:AddTag("can_offset_sort_pos")

	smoke.entity:AddTransform()
	smoke.entity:AddAnimState()

	smoke:AddTag("FX")
	smoke:AddTag("NOCLICK")
	smoke:AddTag("nointerpolate")

	smoke.AnimState:SetBank("shrouden_blast")
	smoke.AnimState:SetBuild("shrouden_blast")
	smoke.AnimState:SetMultColour(1, 1, 1, ALPHA)
	smoke.AnimState:SetLightOverride(1)
	smoke.AnimState:SetSortWorldOffset(0, BEAM_RADIUS / 2, 0)

	smoke:ListenForEvent("animover", RecycleSmoke)

	return smoke
end

local function GetSmoke(inst)
	local smoke = table.remove(inst._smokepool)
	if smoke then
		smoke:ReturnToScene()
	else
		smoke = CreateSmoke()
		smoke.owner = inst
	end
	if inst.wide:value() then
		smoke.AnimState:SetSortWorldOffset(0, BEAM_RADIUS_WIDE / 2, 0)
	end
	smoke.AnimState:PlayAnimation("explosion_"..tostring(math.random(2)))
	local scale = 0.8 + 0.2 * math.random()
	smoke.AnimState:SetScale(math.random() < 0.5 and -scale or scale, scale)
	return smoke
end

--------------------------------------------------------------------------

local function OnRemoveEntity(inst)
	for _, v in ipairs(inst._smokepool) do
		v:Remove()
	end
	inst._smokepool = nil
end

local NUM_OFFSETS = 5
local NUM_OFFSETS_WIDE = 13

local function GetNextSmokeOffset(inst, offsets)
	if #offsets <= 0 then
		local theta = TWOPI * math.random()
		local num = inst.wide:value() and NUM_OFFSETS_WIDE or NUM_OFFSETS
		local delta = TWOPI / num
		for i = 1, num do
			theta = theta + delta
			table.insert(offsets, theta)
		end
	end
	return table.remove(offsets, math.random(#offsets))
end

local function DoSmoke(inst, offsets, num)
	if not inst:IsAsleep() then
		local x, _, z = inst.Transform:GetWorldPosition()
		local r = (inst.wide:value() and BEAM_RADIUS_WIDE or BEAM_RADIUS) - 0.5
		for i = 1, num do
			local theta = GetNextSmokeOffset(inst, offsets)
			local x1 = x + r * math.cos(theta)
			local z1 = z - r * math.sin(theta)
			GetSmoke(inst).Transform:SetPosition(x1, 0, z1)
		end
	end
end

local function OnSmokeDirty(inst)
	if inst.smoke:value() then
		if inst._smokepool == nil then
			inst._smokepool = {}
			inst.OnRemoveEntity = OnRemoveEntity
		end
		if inst._smoketask then
			inst._smoketask:Cancel()
		end
		local offsets = {}
		local num = inst.wide:value() and NUM_OFFSETS_WIDE or NUM_OFFSETS
		inst._smoketask = inst:DoPeriodicTask(0.15, DoSmoke, nil, offsets, math.ceil(num * 0.6))
		DoSmoke(inst, offsets, num)
	elseif inst._smoketask then
		inst._smoketask:Cancel()
		inst._smoketask = nil
	end
end

local function EnableSmoke(inst, enable)
	if inst.smoke:value() ~= enable then
		inst.smoke:set(enable)

		if not TheNet:IsDedicated() then
			OnSmokeDirty(inst)
		end
	end
end

--------------------------------------------------------------------------

local TOSS_PARAMS =
{
	radius = BEAM_RADIUS,
	basespeed = BEAM_RADIUS * 0.4,
	verticalspeed = (BEAM_RADIUS * 0.4 + 0.5) * 2.5,
	--startradius = BEAM_RADIUS,
	startheight = 0.5,
}

local TOSS_PARAMS_WIDE =
{
	radius = BEAM_RADIUS_WIDE,
	basespeed = BEAM_RADIUS_WIDE * 0.4,
	verticalspeed = (BEAM_RADIUS_WIDE * 0.4 + 0.5) * 2.5,
	--startradius = BEAM_RADIUS_WIDE,
	startheight = 0.5,
}

local function DoFlash(v, flashparams)
	if #flashparams > 0 then
		local c = table.remove(flashparams, 1)
		v.components.colouradder:PushColour("shrouden_hit", c, 0, 0, 0)
	else
		v.components.colouradder:PopColour("shrouden_hit")
		v._shrouden_hit_flash_task:Cancel()
		v._shrouden_hit_flash_task = nil
	end
end

local function ResetHitCount(v)
	v._shrouden_hit_count_task = nil
end

local function OnAttackOther(inst, v)
	if v:IsValid() then
		if v.components.colouradder == nil then
			v:AddComponent("colouradder")
		end
		if v._shrouden_hit_flash_task then
			v._shrouden_hit_flash_task:Cancel()
		end
		local flashparams = { 0.65, 0.6, 0.5, 0.3 }
		v._shrouden_hit_flash_task = v:DoPeriodicTask(0, DoFlash, nil, flashparams)
		DoFlash(v, flashparams)

		local numhits = 1
		if v._shrouden_hit_count_task then
			v._shrouden_hit_count_task:Cancel()
			numhits = v._shrouden_hit_count_task.numhits + 1
		end
		v._shrouden_hit_count_task = v:DoTaskInTime(2, ResetHitCount)
		v._shrouden_hit_count_task.numhits = math.max(v.sg and v.sg:HasStateTag("knockback") and 3 or 1, numhits)

		if numhits >= 3 then
			inst.targets[v] = GetTime() + 0.5
			if v.components.rider and v.components.rider.mount then
				inst.targets[v.components.rider.mount] = inst.targets[v]
			end
			v:PushEvent("knockback", { knocker = inst, radius = inst.wide:value() and BEAM_RADIUS_WIDE or BEAM_RADIUS })
		end
	end
end

local function UpdateBeamAOE(inst)--, dt)
	local r = inst.wide:value() and BEAM_RADIUS_WIDE or BEAM_RADIUS
	if inst.caster then
		if not inst.caster:IsValid() or inst.caster.components.health:IsDead() then
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamAOE)
			return
		end
		AOEUtil.Work(inst, r, inst.targets, inst.caster)
		AOEUtil.Attack(inst, r, inst.caster:GetAOEAttackTagSet(), inst.targets, 0.25, inst.caster, inst)
	else
		AOEUtil.Work(inst, r, inst.targets, inst)
	end
	AOEUtil.TossItems(inst, inst.wide:value() and TOSS_PARAMS_WIDE or TOSS_PARAMS, inst.targets)
end

local function StartBeamAOE(inst)
	inst:RemoveEventCallback("animover", StartBeamAOE)
	if not inst.AnimState:IsCurrentAnimation("beam_basic_loop") then
		return
	end

	if inst.caster and inst.caster:IsValid() and not inst.caster.components.health:IsDead() then
		inst._onattackother = function(caster, data)
			if data and data.target and data.weapon == inst then
				OnAttackOther(inst, data.target)
			end
		end
		inst:ListenForEvent("onattackother", inst._onattackother, inst.caster)
	end

	if inst.targets == nil then
		inst.targets = {}
	end

	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamAOE)
	EnableSmoke(inst, true)

	if not inst.SoundEmitter:PlayingSound("loop") then
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_LP", "loop")
	end
end

local function UpdateBeamLightPre(inst)--, dt)
	if inst.AnimState:IsCurrentAnimation("beam_pre") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame > 22 then
			local len = inst.AnimState:GetCurrentAnimationNumFrames()
			local r = easing.outQuad(frame - 22, 0, BEAM_RADIUS, len - 22)
			inst.Light:SetRadius(r)
			inst.Light:Enable(true)
		end
	elseif inst.AnimState:IsCurrentAnimation("beam_wide_pre") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame > 9 then
			local len = inst.AnimState:GetCurrentAnimationNumFrames()
			local r = easing.outQuad(frame - 9, 0, BEAM_RADIUS_WIDE, len - 9)
			inst.Light:SetRadius(r)
		else
			local r = easing.outQuad(frame, BEAM_RADIUS, -BEAM_RADIUS, 9)
			inst.Light:SetRadius(r)
			inst.Light:SetFalloff(FALOFF_WIDE)
		end
		inst.Light:Enable(true)
	else
		if inst.wide:value() then
			inst.Light:SetFalloff(FALOFF_WIDE)
			inst.Light:SetRadius(BEAM_RADIUS_WIDE)
		else
			inst.Light:SetRadius(BEAM_RADIUS)
		end
		inst.Light:Enable(true)
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPre)
	end
end

local function UpdateBeamLightPst(inst)--, dt)
	if inst.AnimState:IsCurrentAnimation("beam_basic_pst") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame < 5 then
			local r = easing.inQuad(frame, BEAM_RADIUS, -BEAM_RADIUS, 5)
			inst.Light:SetRadius(r)
			inst.Light:Enable(true)
		else
			inst.Light:Enable(false)
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
		end
	elseif inst.AnimState:IsCurrentAnimation("beam_wide_pst") then
		local frame = inst.AnimState:GetCurrentAnimationFrame()
		if frame < 5 then
			local r = easing.inQuad(frame, BEAM_RADIUS_WIDE, -BEAM_RADIUS_WIDE, 5)
			inst.Light:SetRadius(r)
			inst.Light:SetFalloff(FALOFF_WIDE)
			inst.Light:Enable(true)
		else
			inst.Light:Enable(false)
			inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
		end
	else
		inst.Light:Enable(false)
		inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
	end
end

local function KillFx(inst)
	if inst:IsAsleep() then
		inst:Remove()
		return
	end
	inst.AnimState:PlayAnimation(inst.wide:value() and "beam_wide_pst" or "beam_basic_pst")
	inst:ListenForEvent("animover", inst.Remove)
	inst.OnEntitySleep = inst.Remove
	inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamAOE)
	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPst)
	EnableSmoke(inst, false)

	if inst._loopsoundtask then
		inst._loopsoundtask:Cancel()
		inst._loopsoundtask = nil
	end
	inst.SoundEmitter:KillSound("loop")
	inst.SoundEmitter:KillSound("bigloop")
	inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_pst")
end

local function StartPreSound(inst)
	if inst.OnEntitySleep == StartPreSound then
		inst.OnEntitySleep = nil
		inst.OnEntityWake = nil
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_pre")
	end
end

local function StartLoopSound(inst)
	inst._loopsoundtask = nil
	if inst.AnimState:IsCurrentAnimation("beam_pre") and
		inst.AnimState:GetCurrentAnimationFrame() >= 21 and
		not inst.SoundEmitter:PlayingSound("loop")
	then
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_LP", "loop")
	end
end

local function StartWideLoopSound(inst)
	inst._loopsoundtask = nil
	if inst.AnimState:IsCurrentAnimation("beam_wide_pre") and
		inst.AnimState:GetCurrentAnimationFrame() >= 9 and
		not inst.SoundEmitter:PlayingSound("bigloop")
	then
		inst.SoundEmitter:KillSound("loop")
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_big_LP", "bigloop")
	end
end

local function InitBlast(inst, caster, targets)
	StartPreSound(inst)

	if caster and caster:IsValid() then
		inst:ListenForEvent("resetboss", function() inst:Remove() end, caster)

		if not caster.components.health:IsDead() then
			inst.caster = caster
		end

		inst.Follower:FollowSymbol(caster.GUID, "optic_blast_fx_follow")
	end

	inst.targets = targets
end

local function OnWideDirty(inst)
	inst.AnimState:SetSortWorldOffset(0, inst.wide:value() and BEAM_RADIUS_WIDE or BEAM_RADIUS, 0)
end

local function StartWideBeam(inst)
	inst:RemoveEventCallback("animover", StartWideBeam)
	if not inst.AnimState:IsCurrentAnimation("beam_wide_loop") then
		return
	end

	inst.wide:set(true)
	OnWideDirty(inst)

	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamAOE)
	EnableSmoke(inst, true)

	if not inst.SoundEmitter:PlayingSound("bigloop") then
		inst.SoundEmitter:KillSound("loop")
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_big_LP", "bigloop")
	end
end

local function MakeWide(inst)
	if inst.AnimState:IsCurrentAnimation("beam_basic_loop") then
		inst.AnimState:PlayAnimation("beam_wide_pre")
		inst.AnimState:PushAnimation("beam_wide_loop")
		inst.SoundEmitter:PlaySound("rifts8/shrouden/opticblast_transition")

		inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamAOE)
		inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPre)
		EnableSmoke(inst, false)

		if inst._loopsoundtask then
			inst._loopsoundtask:Cancel()
		end
		inst._loopsoundtask = inst:DoTaskInTime(10 * FRAMES, StartWideLoopSound)
		inst:ListenForEvent("animover", StartWideBeam)
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	--V2C: speecial =) must be the 1st tag added b4 AnimState component
	inst:AddTag("can_offset_sort_pos")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst.Light:SetIntensity(0.5)
	inst.Light:SetFalloff(0.95)
	inst.Light:SetColour(1, 0, 0)
	inst.Light:Enable(false)

	inst.AnimState:SetBank("shrouden_blast")
	inst.AnimState:SetBuild("shrouden_blast")
	inst.AnimState:PlayAnimation("beam_pre")
	inst.AnimState:SetMultColour(1, 1, 1, ALPHA)
	inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetSortWorldOffset(0, BEAM_RADIUS, 0)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	inst.smoke = net_bool(inst.GUID, "shrouden_optic_blast_fx.smoke", "smokedirty")
	inst.wide = net_bool(inst.GUID, "shrouden_optic_blast_fx.wide", "widedirty")

	inst:SetPrefabNameOverride("shrouden") --for death announce

	inst:AddComponent("updatelooper")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("smokedirty", OnSmokeDirty)
		inst:ListenForEvent("widedirty", OnWideDirty)

		return inst
	end

	inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPre)

	inst.AnimState:PushAnimation("beam_basic_loop")

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(0)

	--weapon planar damage stacks with boss
	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.SHROUDEN_OPTIC_BLAST_PLANAR_DAMAGE - TUNING.SHROUDEN_PLANAR_DAMAGE)

	inst._loopsoundtask = inst:DoTaskInTime(22 * FRAMES, StartLoopSound)
	inst:ListenForEvent("animover", StartBeamAOE)

	inst.InitBlast = InitBlast
	inst.MakeWide = MakeWide
	inst.KillFx = KillFx
	inst.OnEntityWake = StartPreSound
	inst.OnEntitySleep = StartPreSound

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

return Prefab("shrouden_optic_blast_fx", fn, assets)
