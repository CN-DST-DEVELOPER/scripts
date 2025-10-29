local assets =
{
	Asset("ANIM", "anim/warg_mutated_breath_fx.zip"),
}

local prefabs =
{
	"warg_mutated_ember_fx",
}

--------------------------------------------------------------------------

local AOE_RANGE = 0.9
local AOE_RANGE_PADDING = 3
local AOE_TARGET_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "playerghost", "lunar_aligned" }
local AOE_TARGET_CANT_TAGS_PVE = { "INLIMBO", "flight", "invisible", "player", "wall" }
local AOE_TARGET_CANT_TAGS_PVP = { "INLIMBO", "flight", "invisible", "playerghost", "wall" }
local MULTIHIT_FRAMES = 10

local function OnUpdateHitbox(inst)
	local combat = inst.attacker and inst.attacker:IsValid() and inst.attacker.components.combat or inst.components.combat

	local weapon
	if inst.owner ~= inst.attacker then
		if not (inst.owner and inst.owner:IsValid()) then
			return
		elseif inst.owner.components.weapon then
			weapon = inst.owner
		end
	end

	local notplayer = inst.attacker == nil or not inst.attacker.isplayer

	local cant_tags =
		(notplayer and AOE_TARGET_CANT_TAGS) or
		(TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP) or
		AOE_TARGET_CANT_TAGS_PVE

	combat.ignorehitrange = true
	combat.ignoredamagereflect = true

	local tick = GetTick()
	local x, y, z = inst.Transform:GetWorldPosition()
	local radius = AOE_RANGE * inst.scale
	local ents = TheSim:FindEntities(x, 0, z, radius + AOE_RANGE_PADDING, AOE_TARGET_TAGS, cant_tags)
	for i, v in ipairs(ents) do
		if v ~= inst.attacker and v:IsValid() and not v:IsInLimbo() and not (v.components.health and v.components.health:IsDead()) then
			if notplayer or not combat:IsAlly(v) then

				local range = radius + v:GetPhysicsRadius(0)
				if v:GetDistanceSqToPoint(x, 0, z) < range * range then
					local target_data = inst.targets[v]
					if target_data == nil then
						target_data = {}
						inst.targets[v] = target_data
					end
					if target_data.tick ~= tick then
						target_data.tick = tick
						--Supercool
						if v.components.temperature ~= nil then
							local newtemp = math.max(v.components.temperature.mintemp, TUNING.MUTATED_WARG_COLDFIRE_TEMPERATURE)
							if newtemp < v.components.temperature:GetCurrent() then
								v.components.temperature:SetTemperature(newtemp)
							end
						end
						--Hit
						if (target_data.hit_tick == nil or target_data.hit_tick + MULTIHIT_FRAMES < tick) and combat:CanTarget(v) then
							target_data.hit_tick = tick
							combat:DoAttack(v, weapon)
						end
					end
				end
			end
		end
	end

	combat.ignorehitrange = false
	combat.ignoredamagereflect = false
end

local function RefreshBrightness(inst)
	local k = math.min(1, inst.brightness:value() / 6)
	inst.AnimState:OverrideBrightness(1 + k * k * 0.5)
end

local function OnUpdateBrightness(inst)
	inst.brightness:set_local(inst.brightness:value() - 1)
	if inst.brightness:value() <= 0 then
		inst.updatingbrightness = false
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateBrightness)
	end
	RefreshBrightness(inst)
end

local function OnBrightnessDirty(inst)
	RefreshBrightness(inst)
	if inst.brightness:value() > 0 and inst.brightness:value() < 7 then
		if not inst.updatingbrightness then
			inst.updatingbrightness = true
			inst.components.updatelooper:AddOnUpdateFn(OnUpdateBrightness)
		end
	elseif inst.updatingbrightness then
		inst.updatingbrightness = false
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateBrightness)
	end
end

local function StartFade(inst)
	inst.brightness:set(6)
	OnBrightnessDirty(inst)
end

local function OnAnimQueueOver(inst)
	if inst.owner ~= nil and inst.owner.flame_pool ~= nil then
		inst.SoundEmitter:KillSound("fire_loop")
		inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateHitbox)
		inst.targets = nil
		inst.brightness:set(7)
		OnBrightnessDirty(inst)
		inst:RemoveFromScene()
		table.insert(inst.owner.flame_pool, inst)
	else
		inst:Remove()
	end
end

local function KillFX(inst, fadeoption)
	if fadeoption == "nofade" then
		StartFade(inst)
	end
	inst.AnimState:PlayAnimation("flame"..tostring(math.random(3)).."_pst")
	inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateHitbox)
	inst.targets = nil
	inst.fadeoption = nil

	if inst.embers ~= nil then
		if inst.embers:IsValid() then
			inst.embers:KillFX()
		end
		inst.embers = nil
	end

	inst.kill_fx_task = nil
end

local function SetFXOwner(inst, owner, attacker)
	inst.owner = owner
	inst.attacker = attacker or owner
end

local function SpawnEmbers(inst, scale, fadeoption)
	local x, y, z = inst.Transform:GetWorldPosition()
	if not TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		return
	elseif inst.embers ~= nil and inst.embers:IsValid() then
		inst.embers:KillFX()
	end

	inst.embers = inst.owner ~= nil and inst.owner.ember_pool ~= nil and table.remove(inst.owner.ember_pool) or nil
	if inst.embers == nil then
		inst.embers = SpawnPrefab("warg_mutated_ember_fx")
		inst.embers:SetFXOwner(inst.owner)
	end

	inst.embers.Transform:SetPosition(x, 0, z)
	inst.embers:RestartFX(scale, fadeoption)

	inst.spawn_embers_task = nil
end

local function ClearTasks(inst)
	if inst.spawn_embers_task then
		inst.spawn_embers_task:Cancel()
		inst.spawn_embers_task = nil
	end
	if inst.kill_fx_task then
		inst.kill_fx_task:Cancel()
		inst.kill_fx_task = nil
	end
end

local function GetFlameTime(tallflame)
	return (tallflame and TUNING.TALL_FLAMEWALL_BASE_TIME + math.random() * TUNING.TALL_FLAMEWALL_VAR_TIME)
		or math.random(18, 22) * FRAMES
end

local function RestartFX(inst, scale, fadeoption, targets, tallflame)
	if inst:IsInLimbo() then
		inst:ReturnToScene()
	end
	ClearTasks(inst)

	local suffix = (tallflame and "_tall" or "")
	local anim = "flame"..tostring(math.random(3))..suffix

	if tallflame then
		inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/fire_ground_LP", "fire_loop")
	end

	if not inst.AnimState:IsCurrentAnimation(anim.."_pre") then
		inst.AnimState:PlayAnimation(anim.."_pre")
		inst.AnimState:PushAnimation(anim.."_loop", true)
	end

	inst.tallflame = tallflame
	inst.scale = scale or 1
	inst.fadeoption = fadeoption
	inst.AnimState:SetScale(math.random() < 0.5 and -inst.scale or inst.scale, inst.scale)

	if fadeoption == "latefade" then
		inst:DoTaskInTime(10 * FRAMES, StartFade)
	elseif fadeoption ~= "nofade" then
		StartFade(inst)
	end
	inst.spawn_embers_task = inst:DoTaskInTime(2 * FRAMES, SpawnEmbers, inst.scale * 1.1, fadeoption)

	inst.kill_fx_task = inst:DoTaskInTime(GetFlameTime(tallflame), KillFX, fadeoption)

	if inst.embers ~= nil then
		if inst.embers:IsValid() then
			inst.embers:KillFX()
		end
		inst.embers = nil
	end

	if inst.owner ~= nil then
		inst.targets = targets or {}
		inst.components.updatelooper:AddOnUpdateFn(OnUpdateHitbox)
	end
end

local function ExtendFx(inst, time)
	ClearTasks(inst)

	inst.spawn_embers_task = inst:DoTaskInTime(2 * FRAMES, SpawnEmbers, inst.scale * 1.1, inst.fadeoption)
	inst.kill_fx_task = inst:DoTaskInTime(GetFlameTime(inst.tallflame), KillFX, inst.fadeoption)
end

local function ConfigureDamage(inst, default_damage, base_planar_damage)
	inst.components.combat:SetDefaultDamage(default_damage)
	inst.components.planardamage:SetBaseDamage(base_planar_damage)
end

local function KeepTargetFn()
	return false
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("warg_mutated_breath_fx")
	inst.AnimState:SetBuild("warg_mutated_breath_fx")
	inst.AnimState:PlayAnimation("flame1_pre")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(0.1)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.brightness = net_tinybyte(inst.GUID, "warg_mutated_breath_fx.brightness", "brightnessdirty")
	inst.brightness:set(7)
	--inst.updatingbrightness = false
	OnBrightnessDirty(inst)

	inst:AddComponent("updatelooper")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("brightnessdirty", OnBrightnessDirty)

		return inst
	end

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultDamage(TUNING.MUTATED_WARG_FLAMETHROWER_DAMAGE)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("planardamage")
	inst.components.planardamage:SetBaseDamage(TUNING.MUTATED_WARG_PLANAR_DAMAGE)

	inst:ListenForEvent("animqueueover", OnAnimQueueOver)
	inst.persists = false
	inst.SetFXOwner = SetFXOwner
	inst.RestartFX = RestartFX
	inst.ConfigureDamage = ConfigureDamage
	inst.ExtendFx = ExtendFx

	inst.AnimState:PushAnimation("flame1_loop", true)
	RestartFX(inst)

	return inst
end

--------------------------------------------------------------------------

local function ember_OnFizzle(inst, rnd)
	if rnd >= 56 then
		return
	end

	local fx = CreateEntity()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddAnimState()
	fx.entity:AddFollower()

	fx.AnimState:SetBank("warg_mutated_breath_fx")
	fx.AnimState:SetBuild("warg_mutated_breath_fx")

	--rnd [0, 56)
	local animvariation = rnd < 28 and "1" or "2"
	rnd = rnd % 28

	--rnd [0, 28)
	if rnd < 14 then
		fx.AnimState:PlayAnimation("ember"..animvariation.."_float")
		fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	else
		fx.AnimState:PlayAnimation("smoke"..animvariation.."_float")
	end
	rnd = rnd % 14

	--rnd [0, 14)
	local flip = rnd >= 7
	rnd = rnd % 7

	--rnd [0, 7)
	local scale = 0.25 + 0.75 * rnd / 6
	fx.AnimState:SetScale(flip and -scale or scale, scale)

	fx:ListenForEvent("animover", fx.Remove)

	fx.Follower:FollowSymbol(inst.GUID, "swap_fizzle")
end

local function ember_RefreshFade(inst)
	--Unfortunately there is no local "Override" version for SetSymbolMultColour
	local k = inst.fade:value()
	if k < 3 then
		local k1 = 1 - k / 3
		inst.AnimState:OverrideMultColour(1, 1, 1, k1)
		inst.AnimState:SetSymbolMultColour("track", 1, 1, 1, 0)
	else
		if k < 33 then
			inst.AnimState:OverrideMultColour(1, 1, 1, 1)
		else
			local k1 = (k - 33) / 30
			inst.AnimState:OverrideMultColour(1, 1, 1, 1 - k1 * k1)
		end
		if k < 8 then
			local k1 = 1 - (k - 2) / 6
			inst.AnimState:SetSymbolMultColour("track", 1, 1, 1, 1 - k1 * k1)
		elseif k < 18 then
			inst.AnimState:SetSymbolMultColour("track", 1, 1, 1, 1)
		elseif k < 38 then
			local k1 = (k - 18) / 20
			inst.AnimState:SetSymbolMultColour("track", 1, 1, 1, 1 - k1 * k1)
		else
			inst.AnimState:SetSymbolMultColour("track", 1, 1, 1, 0)
		end
	end
end

local function ember_OnUpdate(inst)
	if inst.fade:value() <= 1 then
		inst.fade:set(0)
		inst.updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(ember_OnUpdate)
	elseif inst.fade:value() < 3 then
		inst.fade:set_local(inst.fade:value() - 1)
	elseif inst.fade:value() < 63 then
		inst.fade:set_local(inst.fade:value() + 1)
		--Dedicated server does not need to spawn the local fx
		if inst.fade:value() == 8 and not TheNet:IsDedicated() then
			ember_OnFizzle(inst, inst.fizzle:value())
		end
	elseif not TheWorld.ismastersim then
		inst.updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(ember_OnUpdate)
	elseif inst.owner ~= nil and inst.owner.ember_pool ~= nil then
		inst.updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(ember_OnUpdate)
		inst:RemoveFromScene()
		table.insert(inst.owner.ember_pool, inst)
		return
	else
		inst:Remove()
		return
	end
	ember_RefreshFade(inst)
end

local function ember_OnFadeDirty(inst)
	ember_RefreshFade(inst)
	if inst.fade:value() > 0 then
		if not inst.updating then
			inst.updating = true
			inst.components.updatelooper:AddOnUpdateFn(ember_OnUpdate)
		end
	elseif inst.updating then
		inst.updating = false
		inst.components.updatelooper:RemoveOnUpdateFn(ember_OnUpdate)
	end
end

local function ember_SetFXOwner(inst, owner)
	inst.owner = owner
end

local function ember_RestartFX(inst, scale, fadeoption)
	if inst:IsInLimbo() then
		inst:ReturnToScene()
	end

	scale = scale or 1
	inst.AnimState:SetScale(math.random() < 0.5 and -scale or scale, scale)
	inst.Transform:SetRotation(math.random() * 360)
	if fadeoption == "nofade" then
		inst.AnimState:SetSymbolMultColour("hash", 1, 1, 1, .9 + math.random() * .1)
	elseif fadeoption == "latefade" then
		inst.AnimState:SetSymbolMultColour("hash", 1, 1, 1, .7 + math.random() * .15)
	else
		inst.AnimState:SetSymbolMultColour("hash", 1, 1, 1, .45 + math.random() * .15)
	end

	local anim = "ember"..tostring(math.random(4)).."_ground"
	if not inst.AnimState:IsCurrentAnimation(anim) then
		inst.AnimState:PlayAnimation(anim, true)
	end
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	local rnd = math.random(4)
	if rnd == 2 or rnd == 4 then
		inst.AnimState:Hide("ember1")
	else
		inst.AnimState:Show("ember1")
	end
	if rnd == 3 or rnd == 4 then
		inst.AnimState:Hide("ember2")
		inst.fizzle:set(63) --hidden
	else
		inst.AnimState:Show("ember2")
		if fadeoption == "nofade" then
			inst.fizzle:set(63) --no fizzles when close to the head
		else
			inst.fizzle:set(math.min(63, math.random(96) - 1))
		end
	end

	inst.fade:set(2)
	ember_OnFadeDirty(inst)
end

local function ember_KillFX(inst)
	if inst.fade:value() < 3 then
		inst.fade:set(3)
		ember_OnFadeDirty(inst)
	end
end

local function emberfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("warg_mutated_breath_fx")
	inst.AnimState:SetBuild("warg_mutated_breath_fx")
	inst.AnimState:PlayAnimation("ember1_ground", true)
	inst.AnimState:SetSymbolBloom("track")
	inst.AnimState:SetSymbolLightOverride("track", 0.1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.fade = net_smallbyte(inst.GUID, "warg_mutated_ember_fx.fade", "fadedirty")
	inst.fizzle = net_smallbyte(inst.GUID, "warg_mutated_ember_fx.fizzle")

	inst:AddComponent("updatelooper")
	--inst.updating = false

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("fadedirty", ember_OnFadeDirty)

		return inst
	end

	inst.persists = false
	inst.SetFXOwner = ember_SetFXOwner
	inst.RestartFX = ember_RestartFX
	inst.KillFX = ember_KillFX

	ember_RestartFX(inst)

	return inst
end

--------------------------------------------------------------------------

return Prefab("warg_mutated_breath_fx", fn, assets, prefabs),
	Prefab("warg_mutated_ember_fx", emberfn, assets)
