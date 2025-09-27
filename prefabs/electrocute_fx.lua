local assets =
{
	Asset("ANIM", "anim/shock_fx.zip"),
}

require("stategraphs/commonstates")

local SHORT_SOUNDS =
{
	["tiny"] =	"dontstarve/common/together/electricity/electrocute_sml",
	["small"] =	"dontstarve/common/together/electricity/electrocute_med",
	["med"] =	"dontstarve/common/together/electricity/electrocute_med",
	["large"] =	"dontstarve/common/together/electricity/electrocute_big",
}

local SOUNDS =
{
	["tiny"] =	"dontstarve/common/together/electricity/electrocute_sml_longer",
	["small"] =	"dontstarve/common/together/electricity/electrocute_med_longer",
	["med"] =	"dontstarve/common/together/electricity/electrocute_med_longer",
	["large"] =	"dontstarve/common/together/electricity/electrocute_big_longer",
}

--------------------------------------------------------------------------

local PADDING = 3
local REGISTERED_TARGET_TAGS, REGISTERED_NOPVP_TARGET_TAGS

local function DoFork(inst, target, x, y, z, r, data)
	if target:IsValid() then
		x, y, z = target.Transform:GetWorldPosition()
	end
	data.numforks = data.numforks or 2
	if data.numforks > 0 then
		local attacker = data.attackdata.attacker
		local tags
		if not TheNet:GetPVPEnabled() and
			attacker and (
				attacker.isplayer or
				(	attacker.components.follower and
					attacker.components.follower:GetLeader() and
					attacker.components.follower:GetLeader().isplayer
				)
			)
		then
			if REGISTERED_NOPVP_TARGET_TAGS == nil then
				REGISTERED_NOPVP_TARGET_TAGS = TheSim:RegisterFindTags(nil,
					{ "INLIMBO", "flight", "invisible", "notarget", "noattack", "electricdamageimmune", "FX", "player" })
			end
			tags = REGISTERED_NOPVP_TARGET_TAGS
		else
			if REGISTERED_TARGET_TAGS == nil then
				REGISTERED_TARGET_TAGS = TheSim:RegisterFindTags(nil,
					{ "INLIMBO", "flight", "invisible", "notarget", "noattack", "electricdamageimmune", "FX" })
			end
			tags = REGISTERED_TARGET_TAGS
		end
		local attacker_combat = attacker and attacker.replica.combat
		local targetsremaining = TUNING.ELECTROCUTE_FORK_TARGETS
		local range = TUNING.ELECTROCUTE_FORK_RANGE + r
		for i, v in ipairs(TheSim:FindEntities_Registered(x, y, z, range + PADDING, tags)) do
			if v ~= attacker and not data.targets[v] and
				CanEntityBeElectrocuted(v) and
				v:IsValid() and
				not (	v.sg:HasStateTag("noelectrocute") or
						v:IsInLimbo() or
						IsEntityDead(inst) or
						(attacker_combat and attacker_combat:IsAlly(v)) or
						CommonHandlers.ElectrocuteRecoveryDelay(v)
					)
			then
				local fxradius, _, _ = GetCombatFxSize(v)
				local range1 = range + fxradius
				if v:GetDistanceSqToPoint(x, y, z) < range1 * range1 then
					local px, py, pz = v.Transform:GetWorldPosition()
					local arc = SpawnPrefab("shock_arc_fx")
					arc.Transform:SetPosition((px+x)/2, y, (pz+z)/2)
					arc:ForceFacePoint(v.Transform:GetWorldPosition())
					--
					v:PushEventImmediate("electrocute", data)
					if v.sg:HasStateTag("electrocute") then
						data.targets[v] = true
						if targetsremaining <= 1 then
							return
						end
						targetsremaining = targetsremaining - 1
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------

local function OnUpdate(inst, dt)
	local delta = dt
	if inst.flash > delta then
		inst.flash = inst.flash - delta
		if dt > 0 then
			inst.blink = (inst.blink % 4) + 1
		end
		local c = math.min(1, inst.flash * (inst.blink > 2 and 0.2 or 1))
		inst.target.components.colouradder:PushColour(inst, c, c, c / 2, 0)
	else
		inst.flash = 0
		inst.target.components.colouradder:PopColour(inst)
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
	end
end

local function OnAnimOver(inst)
	local anim = GetElectrocuteFxAnim(inst.size, inst.height).."_pst"
	if inst.AnimState:IsCurrentAnimation(anim) then
		inst:Remove()
	elseif inst.target == nil then--never set target
		inst.AnimState:PlayAnimation(anim)
	end
end

local function PlayPst(inst)
	local anim = GetElectrocuteFxAnim(inst.size, inst.height).."_pst"
	inst.AnimState:PlayAnimation(anim)
end

local function StartFork(inst, target, x, y, z, r, data)
	if data.targets == nil then
		data.targets = { [target] = true }
	else
		data.targets[target] = true
	end
	inst:DoTaskInTime(TUNING.ELECTROCUTE_FORK_DELAY, DoFork, target, x, y, z, r, data)
end

local function SetFxTarget(inst, target, duration, data)
	inst.target = target
	inst.duration = duration or TUNING.ELECTROCUTE_DEFAULT_DURATION

	local r
	r, inst.size, inst.height = GetCombatFxSize(target)

	local anim = GetElectrocuteFxAnim(inst.size, inst.height)

	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim, true)
	end
	if math.random() < 0.5 then
		inst.AnimState:SetScale(-1, 1)
	end
	inst.entity:SetParent(target.entity)
	local scalex, scaley, scalez = target.Transform:GetScale()
	inst.Transform:SetScale(1 / scalex, 1 / scaley, 1 / scalez)

	local sounds_to_use = duration <= TUNING.ELECTROCUTE_SHORT_DURATION and SHORT_SOUNDS or SOUNDS
	inst.SoundEmitter:PlaySound(sounds_to_use[inst.size])

	inst:DoTaskInTime(math.max(0, inst.duration - 0.1 + math.random() * 0.2), PlayPst)

	if target.components.colouradder == nil then
		target:AddComponent("colouradder")
	end
	inst.flash = inst.duration + math.random() * 0.4
	inst.blink = math.random(4)
	inst.components.updatelooper:AddOnUpdateFn(OnUpdate)
	OnUpdate(inst, 0)

	if data and data.attackdata then
		local x, y, z = target.Transform:GetWorldPosition()
		StartFork(inst, target, x, y, z, r, data)
	end
end

--Global, so legacy player shock fx can call this to fork
function StartElectrocuteForkOnTarget(target, data)
	local x, y, z = target.Transform:GetWorldPosition()
	local r, _, _ = GetCombatFxSize(target)
	StartFork(target, target, x, y, z, r, data)
end

local function CancelFlash(inst)
	if inst.flash and inst.flash > 0 then
		inst.flash = 0
		inst.target.components.colouradder:PopColour(inst)
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdate)
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("shock_fx")
	inst.AnimState:SetBuild("shock_fx")
	inst.AnimState:PlayAnimation("shock_small", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetFinalOffset(1)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("animover", OnAnimOver)

	inst:AddComponent("updatelooper")

	inst.persists = false

	inst.SetFxTarget = SetFxTarget
	inst.CancelFlash = CancelFlash

	return inst
end

return Prefab("electrocute_fx", fn, assets)
