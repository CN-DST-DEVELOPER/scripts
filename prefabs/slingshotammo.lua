local SpDamageUtil = require("components/spdamageutil")

local assets =
{
    Asset("ANIM", "anim/slingshotammo.zip"),
	Asset("ANIM", "anim/slingshot_streaks.zip"),
}

----------------------------------------------------------------------------------------------------------------------------------------

local AOE_TARGET_MUST_TAGS     = { "_combat", "_health" }
local AOE_TARGET_CANT_TAGS     = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "companion", "player", "wall" }
local AOE_TARGET_CANT_TAGS_PVP = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

local AOE_RADIUS_PADDING = 3

local function DoAOECallback(inst, x, z, radius, cb, attacker, target)
	local combat = attacker and attacker.components.combat or nil

	if combat == nil then
		return
	end

	for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + AOE_RADIUS_PADDING, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
		if v ~= target and
			combat:CanTarget(v) and
			v.components.combat:CanBeAttacked(attacker) and
			not combat:IsAlly(v)
		then
			local range = radius + v:GetPhysicsRadius(0)

			if v:GetDistanceSqToPoint(x, 0, z) < range * range then
				cb(inst, attacker, v)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------------------------------------------

local function UpdateFlash(target, data, id, r, g, b)
	if data.flashstep < 4 then
		local value = (data.flashstep > 2 and 4 - data.flashstep or data.flashstep) * 0.05
		if target.components.colouradder == nil then
			target:AddComponent("colouradder")
		end
		target.components.colouradder:PushColour(id, value * r, value * g, value * b, 0)
		data.flashstep = data.flashstep + 1
	else
		target.components.colouradder:PopColour(id)
		data.task:Cancel()
	end
end

local function StartFlash(inst, target, r, g, b)
	local data = { flashstep = 1 }
	local id = inst.prefab.."::"..tostring(inst.GUID)
	data.task = target:DoPeriodicTask(0, UpdateFlash, nil, data, id, r, g, b)
	UpdateFlash(target, data, id, r, g, b)
end

----------------------------------------------------------------------------------------------------------------------------------------

-- temp aggro system for the slingshots
local function no_aggro(attacker, target)
	local targets_target = target.components.combat ~= nil and target.components.combat.target or nil
	return targets_target ~= nil and targets_target:IsValid() and targets_target ~= attacker and attacker ~= nil and attacker:IsValid()
			and (GetTime() - target.components.combat.lastwasattackedbytargettime) < 4
			and (targets_target.components.health ~= nil and not targets_target.components.health:IsDead())
end

local function ImpactFx(inst, attacker, target)
    if not inst.noimpactfx and target ~= nil and target:IsValid() then
		local impactfx = SpawnPrefab(inst.ammo_def.impactfx)
		impactfx.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

local function OnAttack(inst, attacker, target)
	if target ~= nil and target:IsValid() and attacker ~= nil and attacker:IsValid() then
		if inst.ammo_def ~= nil and inst.ammo_def.onhit ~= nil then
			inst.ammo_def.onhit(inst, attacker, target)
		end
		ImpactFx(inst, attacker, target)
	end
end

local function OnPreHit(inst, attacker, target)
	if inst.ammo_def ~= nil and inst.ammo_def.onprehit ~= nil then
		inst.ammo_def.onprehit(inst, attacker, target)
	end

    if target ~= nil and target:IsValid() and target.components.combat ~= nil and no_aggro(attacker, target) then
        target.components.combat:SetShouldAvoidAggro(attacker)
	end
end

local function OnHit(inst, attacker, target)
    if target ~= nil and target:IsValid() and target.components.combat ~= nil then
		target.components.combat:RemoveShouldAvoidAggro(attacker)
	end
    inst:Remove()
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function SpawnShadowTentacle(inst, attacker, target, pt, starting_angle)
    local offset = FindWalkableOffset(pt, starting_angle, 2, 3, false, true, NoHoles, false, true)
    if offset ~= nil then
        local tentacle = SpawnPrefab("shadowtentacle")
        if tentacle ~= nil then
			tentacle.owner = attacker
            tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
            tentacle.components.combat:SetTarget(target)

			tentacle.SoundEmitter:PlaySound("dontstarve/characters/walter/slingshot/shadowTentacleAttack_1")
			tentacle.SoundEmitter:PlaySound("dontstarve/characters/walter/slingshot/shadowTentacleAttack_2")
        end
    end
end

local function DoHit_Thulecite(inst, attacker, target)
	local pt
	if target and target:IsValid() then
		pt = target:GetPosition()
	else
		pt = inst:GetPosition()
		target = nil
	end

	local theta = math.random() * TWOPI
	SpawnShadowTentacle(inst, attacker, target, pt, theta)
end

local function OnHit_Thulecite(inst, attacker, target)
	if target and target:IsValid() then
		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			local targets = {}
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE,
				function(inst, attacker, v)
					if v.components.combat and v.components.combat:CanBeAttacked() then
						table.insert(targets, v)
					end
				end,
				attacker, target)

			if #targets <= 0 then
				--No targets in range, treat same as single target
				if math.random() < 0.5 then
					DoHit_Thulecite(inst, attacker, target)
				end
			else
				--There are multiple targets in range
				--First, pick main target for one tentacle
				DoHit_Thulecite(inst, attacker, target)

				local numtospawn = math.floor(#targets / 2)
				if math.random() < 0.25 then
					numtospawn = numtospawn + 1
				end
				for i = 1, numtospawn do
					local v = table.remove(targets, math.random(#targets))
					DoHit_Thulecite(inst, attacker, v)
				end
			end

			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("shadow")
		elseif math.random() < 0.5 then
			DoHit_Thulecite(inst, attacker, target)
		end
	end
end

--------------------------------------------------------------------------

local MAX_HONEY_VARIATIONS = 7
local MAX_PICK_INDEX = 3
local HONEY_VAR_POOL = { 1 }
for i = 2, MAX_HONEY_VARIATIONS do
	table.insert(HONEY_VAR_POOL, math.random(i), i)
end

local function PickHoney()
	local rand = table.remove(HONEY_VAR_POOL, math.random(MAX_PICK_INDEX))
	table.insert(HONEY_VAR_POOL, rand)
	return rand
end

local function TrySpawnHoney(target, min_scale, max_scale, duration)
	local x, y, z = target.Transform:GetWorldPosition()
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local fx = SpawnPrefab("honey_trail")
		fx.Transform:SetPosition(x, 0, z) -- NOTES(JBK): This must be before SetVariation is called!
		fx:SetVariation(PickHoney(), GetRandomMinMax(min_scale, max_scale), duration + math.random() * .5)
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnUpdate_Honey(target, t0)
	local elapsed = GetTime() - t0
	if elapsed < TUNING.SLINGSHOT_AMMO_HONEY_DURATION then
		local k = 1 - elapsed / TUNING.SLINGSHOT_AMMO_HONEY_DURATION
		k = k * k * 0.6 + 0.3
		TrySpawnHoney(target, k, k + 0.2, 2)
	else
		target._slingshot_honeytask:Cancel()
		target._slingshot_honeytask = nil
		target:RemoveTag("honey_ammo_afflicted")
		if target.components.locomotor then
			target.components.locomotor:RemoveExternalSpeedMultiplier(target, "honey_ammo_afflicted")
		end
		target:PushEvent("stop_honey_ammo_afflicted")
	end
end

local function OnHit_Honey(inst, attacker, target)
	if target and target:IsValid() then
		local pushstartevent
		if target._slingshot_honeytask then
			target._slingshot_honeytask:Cancel()
		else
			target:AddTag("honey_ammo_afflicted")
			if target.components.locomotor and not target:HasAnyTag("flying", "playerghost") then
				target.components.locomotor:SetExternalSpeedMultiplier(target, "honey_ammo_afflicted", TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY)
			end
			pushstartevent = true
		end
		target._slingshot_honeytask = target:DoPeriodicTask(1, OnUpdate_Honey, 0.43, GetTime())

		if not no_aggro(attacker, target) and target.components.combat then
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
		end

		if pushstartevent then
			target:PushEvent("start_honey_ammo_afflicted")
		end
	end
end

--------------------------------------------------------------------------

local function onloadammo_ice(inst, data)
	if data ~= nil and data.slingshot then
		data.slingshot:AddTag("extinguisher")
	end
end

local function onunloadammo_ice(inst, data)
	if data ~= nil and data.slingshot then
		data.slingshot:RemoveTag("extinguisher")
	end
end

local function DoHit_Ice(inst, attacker, target)
    if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
        target.components.sleeper:WakeUp()
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.components.freezable ~= nil then
        target.components.freezable:AddColdness(TUNING.SLINGSHOT_AMMO_FREEZE_COLDNESS)
        target.components.freezable:SpawnShatterFX()
    else
        local fx = SpawnPrefab("shatter")
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.components.shatterfx:SetLevel(2)
    end

    if not no_aggro(attacker, target) and target.components.combat ~= nil then
        target.components.combat:SuggestTarget(attacker)
    end
end

local function OnHit_Ice(inst, attacker, target)
	if target and target:IsValid() then
		DoHit_Ice(inst, attacker, target)

		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE, DoHit_Ice, attacker, target)

			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("ice")
		end
	end
end

--------------------------------------------------------------------------

--NOTE: Slow & GelBlob don't stack with each other

local function SetSpeed_Slow(target, fx, numstacks)
	local mult = TUNING.SLINGSHOT_AMMO_MOVESPEED_MULT ^ numstacks
	if target._slingshot_gelblob then
		mult = math.min(1, mult / TUNING.CAREFUL_SPEED_MOD)
	end
	target.components.locomotor:SetExternalSpeedMultiplier(target, "slingshotammo_slow", mult)
	fx:SetFXLevel(numstacks)
end

local function OnGelblobChanged_Slow(target)
	local data = target._slingshot_slow
	if data and #data.tasks > 0 then
		SetSpeed_Slow(target, data.fx, #data.tasks)
	end
end

local function Refresh_Slow(target, data)
	table.remove(data.tasks, 1)
	if #data.tasks > 0 then
		SetSpeed_Slow(target, data.fx, #data.tasks)
	else
		data.fx:KillFX()
		target.components.locomotor:RemoveExternalSpeedMultiplier(target, "slingshotammo_slow")
		target._slingshot_slow = nil
	end
end

local function DoHit_Slow(inst, attacker, target, ismaintarget)
	if target.components.locomotor then
		local data = target._slingshot_slow
		local shouldrefresh
		if data == nil then
			data = { tasks = {}, fx = SpawnPrefab("slingshotammo_slow_debuff_fx") }
			data.fx.entity:SetParent(target.entity)
			data.fx:StartFX(target, not ismaintarget and math.random() * 0.3 or nil)
			target._slingshot_slow = data
			shouldrefresh = true
		elseif #data.tasks < TUNING.SLINGSHOT_AMMO_MOVESPEED_MAX_STACKS then
			shouldrefresh = true
		else
			table.remove(data.tasks, 1):Cancel()
		end

		table.insert(data.tasks, target:DoTaskInTime(TUNING.SLINGSHOT_AMMO_MOVESPEED_DURATION, Refresh_Slow, data))

		if shouldrefresh then
			SetSpeed_Slow(target, data.fx, #data.tasks)
		end

		if not (ismaintarget or no_aggro(attacker, target)) and target.components.combat and target.components.combat:CanBeAttacked() then
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
		end
	end
end

local function OnHit_Slow(inst, attacker, target)
	if target and target:IsValid() then
		DoHit_Slow(inst, attacker, target, true)

		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE, DoHit_Slow, attacker, target)

			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("slow")
		end
	end
end

--------------------------------------------------------------------------

local function OnHit_Distraction(inst, attacker, target)
	if target ~= nil and target:IsValid() and target.components.combat ~= nil then
		local targets_target = target.components.combat.target
		if targets_target == nil or targets_target == attacker then
            target.components.combat:SetShouldAvoidAggro(attacker)
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
            target.components.combat:RemoveShouldAvoidAggro(attacker)

			if not target:HasTag("epic") then
				target.components.combat:DropTarget()
			end
		end
	end
end

local function DoAOEDamage(inst, attacker, target, damage, radius)
    local combat = attacker ~= nil and attacker.components.combat or nil
	
    if combat == nil or not target:IsValid() then
        return
    end

	local x, y, z = target.Transform:GetWorldPosition()

    local _ignorehitrange = combat.ignorehitrange

    combat.ignorehitrange = true

    for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RADIUS_PADDING, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        if v ~= target and
            combat:CanTarget(v) and
            v.components.combat:CanBeAttacked(attacker) and
            not combat:IsAlly(v)
        then
            local range = radius + v:GetPhysicsRadius(0)

            if v:GetDistanceSqToPoint(x, y, z) < range * range then
                local spdmg = SpDamageUtil.CollectSpDamage(inst)

                v.components.combat:GetAttacked(attacker, damage, inst, inst.components.projectile.stimuli, spdmg)
            end
        end
    end

    combat.ignorehitrange = _ignorehitrange
end

local function OnHit_Stinger(inst, attacker, target)
    DoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_STINGER_AOE, TUNING.SLINGSHOT_AMMO_RANGE_STINGER_AOE)
end

local function OnHit_MoonGlass(inst, attacker, target)
    DoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS_AOE, TUNING.SLINGSHOT_AMMO_RANGE_MOONGLASS_AOE)
end

--------------------------------------------------------------------------

local NUM_HORROR_VARIATIONS = 6
local MAX_HORRORS = 4
local HORROR_PERIOD = 1
local INITIAL_RND_PERIOD = 0.35

local function RecycleHorrorDebuffFX(fx, pool)
	fx:RemoveFromScene()
	table.insert(pool, fx)
end

local function OnUpdate_HorrorFuel(target, attacker, data, endtime, first)
	if not (target.components.health and target.components.health:IsDead()) and
		target.components.combat and target.components.combat:CanBeAttacked()
	then
		local rnd = math.random(math.clamp(NUM_HORROR_VARIATIONS - #data.tasks, 2, NUM_HORROR_VARIATIONS / 2))
		local variation = data.variations[rnd]
		for i = rnd, NUM_HORROR_VARIATIONS - 1 do
			data.variations[i] = data.variations[i + 1]
		end
		data.variations[NUM_HORROR_VARIATIONS] = variation

		local fx
		if #data.pool > 0 then
			fx = table.remove(data.pool)
			fx:ReturnToScene()
		else
			fx = SpawnPrefab("slingshotammo_horrorfuel_debuff_fx")
			fx.pool = data.pool
			fx.onrecyclefn = RecycleHorrorDebuffFX
		end
		fx.entity:SetParent(target.entity)
		fx:Restart(attacker, target, variation, data.pool, first)
	end

	if GetTime() >= endtime then
		table.remove(data.tasks, 1):Cancel()
		if #data.tasks <= 0 then
			for i, v in ipairs(data.pool) do
				v:Remove()
			end
			target._slingshot_horror = nil
		end
	end
end

local function DoHit_HorrorFuel(inst, attacker, target, instant)
	if target and target:IsValid() then
		StartFlash(inst, target, 1, 0, 0)
		local data = target._slingshot_horror
		if data == nil then
			data = { tasks = {}, variations = {}, pool = {} }
			for i = 1, NUM_HORROR_VARIATIONS do
				table.insert(data.variations, math.random(i), i)
			end
			target._slingshot_horror = data
		elseif #data.tasks >= MAX_HORRORS then
			table.remove(data.tasks, 1):Cancel()
		end

		local numticks = inst.voidbonusenabled and TUNING.SLINGSHOT_HORROR_SETBONUS_TICKS or TUNING.SLINGSHOT_HORROR_TICKS
		local endtime = GetTime() + HORROR_PERIOD * (numticks - 1) - 0.001
		if instant then
			table.insert(data.tasks, target:DoPeriodicTask(HORROR_PERIOD, OnUpdate_HorrorFuel, nil, attacker, data, endtime))
			OnUpdate_HorrorFuel(target, attacker, data, endtime, true)
		else
			local initialdelay = math.random() * INITIAL_RND_PERIOD
			endtime = endtime + initialdelay
			table.insert(data.tasks, target:DoPeriodicTask(HORROR_PERIOD, OnUpdate_HorrorFuel, initialdelay, attacker, data, endtime))
		end
	end
end

local function OnHit_HorrorFuel(inst, attacker, target)
	if target and target:IsValid() then
		DoHit_HorrorFuel(inst, attacker, target, true)

		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE, DoHit_HorrorFuel, attacker, target)

			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("horror")
		end
	end
end

local function SetVoidBonus_HorrorFuel(inst)
	inst.voidbonusenabled = true
	inst.components.weapon:SetDamage(inst.components.weapon.damage * TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT)
	inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_VOIDCLOTH_SETBONUS_PLANAR_DAMAGE, "setbonus")
end

local _horror_player = nil
local _horror_AWAKELIST = {}

local function _horror_CalcTargetLightOverride(player)
	if player then
		local sanity = player.replica.sanity
		if sanity and sanity:IsInsanityMode() then
			local k = sanity:GetPercent()
			if k < 0.6 then
				k = 1 - k / 0.6
				return k * k
			end
		end
	end
	return 0
end

local function _horror_UpdateLightOverride(inst, instant)
	inst.targetlight = _horror_CalcTargetLightOverride(_horror_player)
	inst.currentlight = instant and inst.targetlight or inst.targetlight * 0.1 + inst.currentlight * 0.9
	inst.AnimState:SetLightOverride(inst.currentlight)
end

local function _horror_OnSanityDelta(player, data)
	if data and not data.overtime then
		for k in pairs(_horror_AWAKELIST) do
			_horror_UpdateLightOverride(k, true)
		end
	end
end

local function _horror_OnRemovePlayer(player)
	_horror_player = nil
end

local function _horror_StopWatchingPlayerSanity(world)
	if _horror_player then
		world:RemoveEventCallback("sanitydelta", _horror_OnSanityDelta, _horror_player)
		world:RemoveEventCallback("onremove", _horror_OnRemovePlayer, _horror_player)
		_horror_player = nil
	end
end

local function _horror_WatchPlayerSanity(world, player)
	world:ListenForEvent("sanitydelta", _horror_OnSanityDelta, player)
	world:ListenForEvent("onremove", _horror_OnRemovePlayer, player)
	_horror_player = player
end

local function _horror_OnPlayerActivated(world, player)
	if _horror_player ~= player then
		_horror_StopWatchingPlayerSanity(world)
		_horror_WatchPlayerSanity(world, player)
		for k in pairs(_horror_AWAKELIST) do
			_horror_UpdateLightOverride(k, true)
		end
	end
end

local function OnEntityWake_HorrorFuel(inst)
	if not _horror_AWAKELIST[inst] then
		if next(_horror_AWAKELIST) == nil then
			if _horror_player ~= ThePlayer then
				_horror_StopWatchingPlayerSanity(TheWorld)
				_horror_WatchPlayerSanity(TheWorld, ThePlayer)
			end
			TheWorld:ListenForEvent("playeractivated", _horror_OnPlayerActivated)
		end
		_horror_AWAKELIST[inst] = true
		inst._horror_task = inst:DoPeriodicTask(1, _horror_UpdateLightOverride, math.random())
		_horror_UpdateLightOverride(inst, true)
	end
end

local function OnEntitySleep_HorrorFuel(inst)
	if _horror_AWAKELIST[inst] then
		_horror_AWAKELIST[inst] = nil
		if next(_horror_AWAKELIST) == nil then
			_horror_StopWatchingPlayerSanity(TheWorld)
			TheWorld:RemoveEventCallback("playeractivated", _horror_OnPlayerActivated)
		end
		inst._horror_task:Cancel()
		inst._horror_task = nil
	end
end

local function CreateFX_HorrorFuel()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("slingshotammo")
	inst.AnimState:SetBuild("slingshotammo")
	inst.AnimState:PlayAnimation("idle_horrorfuel", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	inst.AnimState:SetFinalOffset(1)

	inst.currentlight = 0
	inst.targetlight = 0
	inst.OnEntityWake = OnEntityWake_HorrorFuel
	inst.OnEntitySleep = OnEntitySleep_HorrorFuel
	inst.OnRemoveEntity = OnEntitySleep_HorrorFuel

	return inst
end

--------------------------------------------------------------------------

local function TrySpawnGelBlob(target)
	local x, y, z = target.Transform:GetWorldPosition()
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local blob = SpawnPrefab("gelblob_small_fx")
		blob.Transform:SetPosition(x, 0, z)
		blob:SetLifespan(TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION)
		blob:ReleaseFromAmmoAfflicted()
		return blob
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnRemoveTarget_GelBlob(target)
	if target._slingshot_gelblob.blob and target._slingshot_gelblob.blob:IsValid() then
		target._slingshot_gelblob.blob:KillFX()
		target._slingshot_gelblob.blob = nil
	end
end

local function OnUpdate_GelBlob(target)
	local data = target._slingshot_gelblob
	local elapsed = GetTime() - data.t0
	if elapsed < TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION then
		if data.blob then
			if not data.blob:IsValid() then
				data.blob = nil
				data.wasafflicted = false
			elseif data.start or (data.wasafflicted and data.blob._targets[target] == nil) then
				data.blob:KillFX(true)
				data.blob = nil
				data.wasafflicted = false
			end
		end
		if data.blob == nil then
			data.blob = TrySpawnGelBlob(target)
		end
		if not data.wasafflicted and data.blob and data.blob._targets[target] then
			data.wasafflicted = true
		end
		data.start = nil
	else
		if data.blob then
			data.blob:KillFX(true)
			data.blob = nil
		end
		data.task:Cancel()
		target._slingshot_gelblob = nil
		target:RemoveTag("gelblob_ammo_afflicted")
		target:RemoveEventCallback("onremove", OnRemoveTarget_GelBlob)

		--NOTE: no stacking with Slow ammo
		OnGelblobChanged_Slow(target)

		target:PushEvent("stop_gelblob_ammo_afflicted")
	end
end

local function OnHit_GelBlob(inst, attacker, target)
	if target and target:IsValid() then
		local pushstartevent
		if target._slingshot_gelblob then
			target._slingshot_gelblob.task:Cancel()
		else
			target:AddTag("gelblob_ammo_afflicted")
			target:ListenForEvent("onremove", OnRemoveTarget_GelBlob)
			target._slingshot_gelblob = {}
			pushstartevent = true
		end
		target._slingshot_gelblob.start = true
		target._slingshot_gelblob.t0 = GetTime()
		target._slingshot_gelblob.task = target:DoPeriodicTask(0, OnUpdate_GelBlob, 0.43)

		if not no_aggro(attacker, target) and target.components.combat then
			target:PushEvent("attacked", { attacker = attacker, damage = 0, weapon = inst })
		end

		if pushstartevent and target:IsValid() then
			--NOTE: no stacking with Slow ammo
			OnGelblobChanged_Slow(target)

			target:PushEvent("start_gelblob_ammo_afflicted")
		end
	end
end

local function InvMasterPostInit_Gelblob(inst)
    MakeCraftingMaterialRecycler(inst, { gelblob_bottle = "messagebottleempty" })
end

--------------------------------------------------------------------------

local function OnHit_Scrapfeather(inst, attacker, target)
	SpawnElectricHitSparks(attacker and attacker:IsValid() and attacker or inst, target, true)
end

local function CommonPostInit_Scrapfeather(inst)
	inst.AnimState:SetSymbolBloom("electricity")
    inst.AnimState:SetSymbolLightOverride("electricity", .3)
    inst.AnimState:SetSymbolMultColour("electricity", 255 / 255, 255 / 255, 175 / 255, 1)
end

local function ProjMasterPostInit_Scrapfeather(inst, attacker, target)
	inst.components.weapon:SetElectric(TUNING.SLINGSHOT_AMMO_SCRAPFEATHER_DRY_DAMAGE_MULT, TUNING.SLINGSHOT_AMMO_SCRAPFEATHER_WET_DAMAGE_MULT)
end

--------------------------------------------------------------------------

local function GunpowderStaticTimeout(target)
    target._slingshot_gunpowder = nil
end

local function OnPreHit_Gunpowder(inst, attacker, target)
    inst._crithit = target._slingshot_gunpowder ~= nil and math.random() <= target._slingshot_gunpowder.chance

	if not inst._crithit then
		return
	end

	local dmg = inst.components.weapon.damage

	if dmg and dmg > 0 then
		inst.components.weapon:SetDamage(dmg * TUNING.SLINGSHOT_AMMO_GUNPOWDER_DUST_DAMAGE_MULTIPLIER)
	end
end

local function OnHit_Gunpowder(inst, attacker, target)
    if target._slingshot_gunpowder == nil then
        target._slingshot_gunpowder = {
            chance = TUNING.SLINGSHOT_AMMO_GUNPOWDER_DUST_TRIGGER_CHANCE_RATE,
            task = target:DoTaskInTime(TUNING.SLINGSHOT_AMMO_GUNPOWDER_DUST_TIMEOUT, GunpowderStaticTimeout),
        }
    else
        target._slingshot_gunpowder.chance = target._slingshot_gunpowder.chance + TUNING.SLINGSHOT_AMMO_GUNPOWDER_DUST_TRIGGER_CHANCE_RATE

        target._slingshot_gunpowder.task:Cancel()
        target._slingshot_gunpowder.task = target:DoTaskInTime(TUNING.SLINGSHOT_AMMO_GUNPOWDER_DUST_TIMEOUT, GunpowderStaticTimeout)
    end
	
	if inst._crithit then
		local fx = SpawnPrefab("slingshotammo_gunpowder_explode")

		if fx ~= nil then
			fx.Transform:SetPosition(target.Transform:GetWorldPosition())
		end

        for i, v in ipairs(AllPlayers) do
            local distSq = v:GetDistanceSqToInst(target)
            local k = math.max(0, math.min(1, distSq / 400))
            local intensity = k * 0.75 * (k - 2) + 0.75
            if intensity > 0 then
                v:ShakeCamera(CAMERASHAKE.FULL, 1.05, .03, intensity / 2)
            end
        end

        DoAOEDamage(inst, attacker, target, inst.components.weapon.damage, TUNING.SLINGSHOT_AMMO_RANGE_GUNPOWDER_DUST_AOE)

        target._slingshot_gunpowder.task:Cancel()
        target._slingshot_gunpowder = nil

		inst.noimpactfx = true -- Don't spawn the regular fx.
    end
end

local function OnLaunch_Gunpowder(inst, owner, target, attacker)
    inst.SoundEmitter:PlaySound("meta5/walter/ammo_gunpowder_shoot")
end

--------------------------------------------------------------------------

local function DoHit_PureBrilliance(inst, attacker, target, skipaggro)
	if target and target:IsValid() and
		target.components.combat and target.components.combat:CanBeAttacked()
	then
		target:AddDebuff("ammo_purebrilliance_mark", "slingshotammo_purebrilliance_debuff")

		if not (skipaggro or no_aggro(attacker, target)) then
			target.components.combat:SuggestTarget(attacker)
		end
	end
end

local function OnHit_PureBrilliance(inst, attacker, target)
	if target and target:IsValid() then
		StartFlash(inst, target, 1, 1, 1)

		if not (target.components.health and target.components.health:IsDead()) then
			DoHit_PureBrilliance(inst, attacker, target, true)
		end

		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE, DoHit_PureBrilliance, attacker, target)

			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("lunar")
		end
	end
end

local function CommonPostInit_PureBrilliance(inst)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetSymbolLightOverride("pb_energy_loop", .5)
    inst.AnimState:SetSymbolLightOverride("pb_ray", .5)
    inst.AnimState:SetSymbolLightOverride("SparkleBit", .5)
    inst.AnimState:SetLightOverride(.1)
end

--------------------------------------------------------------------------

local function Reset_LunarPlantHusk(target)
	target._slingshot_lunarplanthusk = nil
end

local function NoHoles_LunarPlantHusk(pt)
	return TheWorld and not TheWorld.Map:IsPointNearHole(pt)
end

local function OnHit_LunarPlantHusk(inst, attacker, target)
	if target and target:IsValid() then
		StartFlash(inst, target, 1, 1, 1)

		local data = target._slingshot_lunarplanthusk
		if data == nil then
			data = { counter = math.random(4) }
			target._slingshot_lunarplanthusk = data
		else
			data.task:Cancel()
		end

		data.task = target:DoTaskInTime(6, Reset_LunarPlantHusk)

		if data.counter > 1 then
			data.counter = data.counter - 1
		else
			data.counter = math.random(3, 5)

			local pt = target:GetPosition()
			local offset = FindWalkableOffset(pt, TWOPI * math.random(), 2, 3, false, true, NoHoles_LunarPlantHusk, false, true)
			if offset then
				local tentacle = SpawnPrefab("lunarplanttentacle")
				tentacle.owner = attacker
				tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
				tentacle.components.combat:SetTarget(target)
				tentacle.sg:GoToState("quickattack")
			end
		end
	end
end

--------------------------------------------------------------------------

local DREADSTONE_TAGS = { "dreadstoneammo" }
local DREADSTONE_NOTAGS = { "INLIMBO" }

local function FindStackableDreadstoneAmmo(inst, radius)
	local x, y, z = inst.Transform:GetWorldPosition()
	local num = inst.components.stackable:StackSize()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius, DREADSTONE_TAGS, DREADSTONE_NOTAGS)) do
		if v ~= inst and v.components.inventoryitem.is_landed and v.components.stackable:RoomLeft() >= num then
			return v
		end
	end
end

local function OnLanded2_Dreadstone(inst) --this is the inv item
	inst:RemoveEventCallback("on_landed", OnLanded2_Dreadstone)

	local other = FindStackableDreadstoneAmmo(inst, 0.25)
	if other then
		other.components.stackable:Put(inst)
	end
end

local function OnLanded_Dreadstone(inst) --this is the inv item
	inst:RemoveEventCallback("on_landed", OnLanded_Dreadstone)

	local other = FindStackableDreadstoneAmmo(inst, 0.5)
	if other then
		local vx, vy, vz = inst.Physics:GetVelocity()
		other.components.stackable:Put(inst)
		if vx ~= 0 or vz ~= 0 then
			local speed = math.sqrt(vx * vx + vz * vz)
			local dir = math.atan2(vz, -vx) * DEGREES
			Launch2(other, other, speed * 0.5, 0.1, 0, 0, 3, dir - 10 + math.random() * 20)
			other.components.inventoryitem:SetLanded(false, true)
			other:ListenForEvent("on_landed", OnLanded2_Dreadstone)
		end
	end
end

local function OnHit_Dreadstone(inst, attacker, target)
	if target and target:IsValid() then
		StartFlash(inst, target, 1, 0, 0)
		if math.random() < TUNING.SLINGSHOT_AMMO_DREADSTONE_RECOVER_CHANCE then
			local ammo = SpawnPrefab("slingshotammo_dreadstone")
			LaunchAt(ammo, target, attacker and attacker:IsValid() and attacker or nil, 1, 1, target:GetPhysicsRadius(0), 40)
			ammo.components.inventoryitem:SetLanded(false, true)
			ammo:ListenForEvent("on_landed", OnLanded_Dreadstone)
		end
	end
end

local function SetVoidBonus_Dreadstone(inst)
	inst.components.weapon:SetDamage(inst.components.weapon.damage * TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT)
	inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_VOIDCLOTH_SETBONUS_PLANAR_DAMAGE, "setbonus")
end

--------------------------------------------------------------------------

local function OnMiss(inst, owner, target)
    inst:Remove()
end

local tails =
{
	["tail_5_2"] = 0.15,
	["tail_5_3"] = 0.15,
	["tail_5_4"] = 0.2,
	["tail_5_5"] = 0.8,
	["tail_5_6"] = 1,
	["tail_5_7"] = 1,
}

local thintails =
{
	["tail_5_8"] = 1,
	["tail_5_9"] = 0.5,
}

local function CreateTail(thintail)
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("slingshot_streaks")
	inst.AnimState:SetBuild("slingshot_streaks")
	inst.AnimState:PlayAnimation(weighted_random_choice(thintail and thintails or tails))
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	if thintail then
		inst.AnimState:SetMultColour(1, 1, 1, 0.6)
	end

	inst.AnimState:SetSaturation(0)
	--[[if color then
		inst.AnimState:SetHue(color.h or 0)
		inst.AnimState:SetSaturation(color.s or 1)
		inst.AnimState:SetBrightness(color.v or 1)
		inst.AnimState:SetLightOverride(color.lo or 0)
	end]]

	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

--runs on client as well
local function OnUpdateProjectileTail(inst)
	--can go invalid from projectile onupdate on server.
	if not inst:IsValid() then
		return
	elseif inst.checkhightail then --mounted adjustment
		inst.checkhightail = nil

		if inst.AnimState:IsCurrentAnimation(inst.ammo_def.spinloopmounted or "spin_loop_mount") then
			inst.thintailcount = inst.thintailcount - 1
			inst.taildelay2 = inst.AnimState:GetCurrentAnimationNumFrames() - 2
			inst.taildelay1 = math.min(4, inst.taildelay2)

			local ff = math.max(0, inst.AnimState:GetCurrentAnimationFrame() - (TheWorld.ismastersim and 1 or 2))
			if ff > 0 then
				inst.taildelay2 = inst.taildelay2 > ff and inst.taildelay2 - ff or nil
				if inst.taildelay1 > ff then
					inst.taildelay1 = inst.taildelay1 - ff
				else
					--subtract remainder of fastforward frames off thintailcount
					inst.thintailcount = math.max(0, inst.thintailcount - (ff - inst.taildelay1))
					inst.taildelay1 = nil
				end
			end
		end
	end

	if inst.taildelay1 == nil then
		local x, y, z
		if inst.taildelay2 then
			x, y, z = inst.Transform:GetWorldPosition()
			y = y + 2
			inst.taildelay2 = inst.taildelay2 > 1 and inst.taildelay2 - 1 or nil
		else
			x, y, z = inst.AnimState:GetSymbolPosition(inst.ammo_def.spinsymbol or "rock")
		end
		if x and y and z then
			local tail = CreateTail(inst.thintailcount > 0)
			tail.Transform:SetPosition(x, y, z)
			tail.Transform:SetRotation(inst.Transform:GetRotation())
			if inst.thintailcount > 0 then
				inst.thintailcount = inst.thintailcount - 1
			end
		end
	else
		inst.taildelay1 = inst.taildelay1 > 1 and inst.taildelay1 - 1 or nil
		inst.taildelay2 = inst.taildelay2 > 1 and inst.taildelay2 - 1 or nil
	end
end

local function OnHasTail(inst)
	inst.thintailcount = math.random(2, 4)
	inst.checkhightail = true
	inst.components.updatelooper:AddOnUpdateFn(OnUpdateProjectileTail)
end

local function OnUpdateSkillshot(inst)
	--can go invalid from projectile onupdate. (doesn't get immediately cancelled onremove like tasks do.)
	if not (inst.components.projectile.owner and inst:IsValid()) then
        return
    end

    local attacker = inst._attacker

    if not (attacker ~= nil and attacker.components.combat ~= nil and attacker:IsValid()) then
        return
    end

	local x, y, z = inst.Transform:GetWorldPosition()

    for i, v in ipairs(TheSim:FindEntities(x, 0, z, 4, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        local range = v:GetPhysicsRadius(.5) + inst.components.projectile.hitdist

        if v:GetDistanceSqToPoint(x, y, z) < range * range and
            attacker.components.combat:CanTarget(v) and
            v.components.combat:CanBeAttacked(attacker) and
            not attacker.components.combat:IsAlly(v)
        then
            inst.components.projectile:Hit(v)

            break
        end
    end
end

local function OnThrown(inst, owner, target, attacker)
    if inst.ammo_def ~= nil and inst.ammo_def.onlaunch ~= nil then
        inst.ammo_def.onlaunch(inst, owner, target, attacker)
    end

    if not target:HasTag("CLASSIFIED") then
        return -- Not a fake target.
    end

    inst._attacker = attacker
    inst.components.projectile:SetHitDist(.7)
	inst.components.updatelooper:AddOnWallUpdateFn(OnUpdateSkillshot)
end

local function SetHighProjectile(inst)
	inst.AnimState:PlayAnimation(inst.ammo_def.spinloopmounted or "spin_loop_mount")
	inst.AnimState:PushAnimation(inst.ammo_def.spinloop or "spin_loop")
end

local function SetChargedMultiplier(inst, mult)
	local damagemult = 1 + (TUNING.SLINGSHOT_MAX_CHARGE_DAMAGE_MULT - 1) * mult
	local speedmult = 1 + (TUNING.SLINGSHOT_MAX_CHARGE_SPEED_MULT - 1) * mult

	local dmg = inst.components.weapon.damage
	if dmg and dmg > 0 then
		inst.components.weapon:SetDamage(dmg * damagemult)
	end
	if inst.components.planardamage then
		inst.components.planardamage:AddMultiplier(inst, damagemult, "chargedattack")
	end

	inst.components.projectile:SetSpeed(inst.components.projectile.speed * speedmult)

	inst.hastail:set(true)
	if not TheNet:IsDedicated() then
		OnHasTail(inst)
	end
end

local function SetMagicAmplified(inst)
	if inst.ammo_def.canmagicamp then
		inst.magicamplified = true
		inst.hastail:set(true)
		if not TheNet:IsDedicated() then
			OnHasTail(inst)
		end
	end
end

local function projectile_fn(ammo_def)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetFourFaced()

    MakeProjectilePhysics(inst)

    inst.AnimState:SetBank("slingshotammo")
    inst.AnimState:SetBuild("slingshotammo")

	if ammo_def.spinloop then
		inst.AnimState:PlayAnimation(ammo_def.spinloop, true)
	else
		inst.AnimState:PlayAnimation("spin_loop", true)
		if ammo_def.symbol then
			inst.AnimState:OverrideSymbol("rock", "slingshotammo", ammo_def.symbol)
		end
	end

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

	if ammo_def.tags then
		for _, tag in pairs(ammo_def.tags) do
			inst:AddTag(tag)
		end
	end

	if ammo_def.proj_common_postinit then
		ammo_def.proj_common_postinit(inst)
	end

	inst.hastail = net_bool(inst.GUID, ammo_def.name.."_proj.hastail", "hastaildirty")

	inst:AddComponent("updatelooper")

	inst.ammo_def = ammo_def

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst:ListenForEvent("hastaildirty", OnHasTail)

        return inst
    end

    inst.SetHighProjectile = SetHighProjectile
	inst.SetChargedMultiplier = SetChargedMultiplier
	inst.SetMagicAmplified = SetMagicAmplified
	inst.SetVoidBonus = ammo_def.setvoidbonus

    inst.persists = false

	if ammo_def.planar then
		inst:AddComponent("planardamage")
		inst.components.planardamage:SetBaseDamage(ammo_def.planar)
	end

	if ammo_def.damagetypebonus then
		inst:AddComponent("damagetypebonus")
		for k, v in pairs(ammo_def.damagetypebonus) do
			inst.components.damagetypebonus:AddBonus(k, inst, v)
		end
	end

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(ammo_def.damage)
	inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(25)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetHitDist(1.5)
    inst.components.projectile:SetOnPreHitFn(OnPreHit)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(OnMiss)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    inst.components.projectile.range = 30
	inst.components.projectile.has_damage_set = true

	if ammo_def.proj_master_postinit then
		ammo_def.proj_master_postinit(inst)
	end

    return inst
end

local FLOATER_SCALE = { .85, .9, .85 }

local function inv_fn(ammo_def)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetRayTestOnBB(true)
    inst.AnimState:SetBank("slingshotammo")
    inst.AnimState:SetBuild("slingshotammo")

	if ammo_def.idleanim then
		inst.AnimState:PlayAnimation(ammo_def.idleanim, ammo_def.idlelooping)
	else
		inst.AnimState:PlayAnimation("idle")
		if ammo_def.symbol then
			inst.AnimState:OverrideSymbol("rock", "slingshotammo", ammo_def.symbol)
		end
	end

	if ammo_def.symbol then
		inst.scrapbook_overridedata = { "rock", "slingshotammo", ammo_def.symbol }
	end

	inst:AddTag("slingshotammo")
	inst:AddTag("reloaditem_ammo")

	if ammo_def.elemental then
    	inst:AddTag("molebait")
	else
		MakeInventoryFloatable(inst, "small", .2, FLOATER_SCALE)
	end

	inst.REQUIRED_SKILL = ammo_def.skill

	if ammo_def.inv_common_postinit then
		ammo_def.inv_common_postinit(inst)
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.ammo_def = ammo_def

	if ammo_def.idlelooping then
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	end

	inst:AddComponent("reloaditem")
	inst:AddComponent("tradable")

	if ammo_def.elemental then
		inst:AddComponent("edible")
		inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
		inst.components.edible.hungervalue = 1
	end

    inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_PELLET

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(ammo_def.elemental)

	if ammo_def.elemental then
    	inst:AddComponent("bait")
	end

    MakeHauntableLaunch(inst)

	if ammo_def.fuelvalue ~= nil then
		inst:AddComponent("fuel")
		inst.components.fuel.fuelvalue = ammo_def.fuelvalue
	end

	if ammo_def.onloadammo ~= nil and ammo_def.onunloadammo ~= nil then
		inst:ListenForEvent("ammoloaded", ammo_def.onloadammo)
		inst:ListenForEvent("ammounloaded", ammo_def.onunloadammo)
		inst:ListenForEvent("onremove", ammo_def.onunloadammo)
	end

    if ammo_def.inv_master_postinit ~= nil then
        ammo_def.inv_master_postinit(inst, ammo_def)
    end

    return inst
end

-- NOTE(DiogoW): Add an entry to SCRAPBOOK_DEPS table in prefabs/slingshot.lua when adding a new ammo.
local ammo =
{
	{
		name = "slingshotammo_rock",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_ROCKS,
		elemental = true,
		--tailcolor = { s = 0 },
	},
    {
        name = "slingshotammo_gold",
		symbol = "gold",
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_GOLD,
		elemental = true,
		--tailcolor = { h = 0.09 },
    },
	{
		name = "slingshotammo_marble",
		symbol = "marble",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_MARBLE,
		elemental = true,
		--tailcolor = { s = 0 },
	},
	{
		name = "slingshotammo_thulecite", -- chance to spawn a Shadow Tentacle
		symbol = "thulecite",
		onhit = OnHit_Thulecite,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_THULECITE,
		elemental = true,
		--tailcolor = { h = 0.03, s = 0.8 },
		canmagicamp = true,
	},
	{
		name = "slingshotammo_honey",
		symbol = "honey",
		onhit = OnHit_Honey,
		damage = nil,
		skill = "walter_ammo_utility",
		--tailcolor = { h = 0.07 },
	},
    {
        name = "slingshotammo_freeze",
		symbol = "freeze",
        onhit = OnHit_Ice,
		tags = { "extinguisher" },
		onloadammo = onloadammo_ice,
		onunloadammo = onunloadammo_ice,
        damage = nil,
		elemental = true,
		prefabs = { "shatter", "slingshot_aoe_fx" },
		--tailcolor = { h = 0.55, s = 0.4, v = 0.8 },
		canmagicamp = true,
    },
    {
        name = "slingshotammo_slow",
		symbol = "slow",
		onhit = OnHit_Slow,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_SLOW,
		elemental = true,
		prefabs = { "slingshot_aoe_fx", "slingshotammo_slow_debuff_fx" },
		--tailcolor = { h = -0.2, s = 0.6, v = 0.5 },
		canmagicamp = true,
    },
    {
        name = "slingshotammo_poop", -- distraction (drop target, note: hostile creatures will probably retarget you very shortly after)
		symbol = "poop",
        onhit = OnHit_Distraction,
        damage = nil,
		fuelvalue = TUNING.MED_FUEL / 10, -- 1/10th the value of using poop
		--tailcolor = { h = 0.05, s = 0.8, v = 0.58 },
    },
    {
        name = "slingshotammo_moonglass",
		symbol = "moonglass",
        onhit = OnHit_MoonGlass,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS,
		skill = "walter_ammo_shattershots",
		--tailcolor = { h = 0.2, s = 0.6 },
    },
    {
        name = "slingshotammo_dreadstone",
		symbol = "dreadstone",
		inv_common_postinit = function(inst)
			inst:AddTag("dreadstoneammo")
			inst:AddTag("recoverableammo")
		end,
		onhit = OnHit_Dreadstone,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_DREADSTONE,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_DREADSTONE,
		damagetypebonus = { ["lunar_aligned"] = TUNING.SLINGSHOT_AMMO_VS_LUNAR_BONUS },
		setvoidbonus = SetVoidBonus_Dreadstone,
		skill = "walter_ammo_lucky",
		elemental = true,
		--tailcolor = { s = 0, v = 0.1 },
    },
    {
        name = "slingshotammo_gunpowder",
		symbol = "gunpowder",
        onlaunch = OnLaunch_Gunpowder,
        onprehit = OnPreHit_Gunpowder,
        onhit = OnHit_Gunpowder,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_GUNPOWDER,
		skill = "walter_ammo_lucky",
		prefabs = { "slingshotammo_gunpowder_explode" },
		--tailcolor = { s = 0, v = 0.8 },
    },
    {
        name = "slingshotammo_lunarplanthusk",
		symbol = "lunarplanthusk",
		onhit = OnHit_LunarPlantHusk,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_LUNARPLANTHUSK,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_LUNARPLANTHUSK,
		damagetypebonus = { ["shadow_aligned"] = TUNING.SLINGSHOT_AMMO_VS_SHADOW_BONUS },
		skill = "walter_ammo_lunar",
		prefabs = { "lunarplanttentacle" },
		--tailcolor = { h = 0.38, s = 0.3, v = 0.7 },
    },
    {
		name = "slingshotammo_purebrilliance",
		symbol = "purebrilliance",
		idleanim = "idle_purebrilliance",
		idlelooping = true,
		inv_common_postinit = CommonPostInit_PureBrilliance,
		proj_common_postinit = CommonPostInit_PureBrilliance,
		onhit = OnHit_PureBrilliance,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_PUREBLILLIANCE,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_PUREBLILLIANCE,
		damagetypebonus = { ["shadow_aligned"] = TUNING.SLINGSHOT_AMMO_VS_SHADOW_BONUS },
		skill = "walter_ammo_lunar",
		prefabs = { "slingshotammo_purebrilliance_debuff", "slingshot_aoe_fx" },
		--tailcolor = { h = 0.53, s = 0.7, v = 1.1, lo = 0.5 },
		canmagicamp = true,
    },
    {
        name = "slingshotammo_horrorfuel",
		symbol = "horrorfuel",
		idleanim = "idle_horrorfuel_rock",
		spinloop = "spin_loop_horrorfuel",
		spinloopmounted = "spin_loop_mount_horrorfuel",
		spinsymbol = "horrorfuel_stone",
		inv_common_postinit = function(inst)
			if not TheNet:IsDedicated() then
				inst.fx = CreateFX_HorrorFuel()
				inst.fx.entity:SetParent(inst.entity)
				inst.highlightchildren = { inst.fx }
			end

			inst.scrapbook_anim = "scrapbook_horrorfuel"
		end,
		proj_common_postinit = function(inst)
			inst.AnimState:SetSymbolLightOverride("horrorfuel", 1)
		end,
		onhit = OnHit_HorrorFuel,
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_HORRORFUEL,
		planar = TUNING.SLINGSHOT_AMMO_PLANAR_HORRORFUEL,
		damagetypebonus = { ["lunar_aligned"] = TUNING.SLINGSHOT_AMMO_VS_LUNAR_BONUS },
		setvoidbonus = SetVoidBonus_HorrorFuel,
		skill = "walter_ammo_shadow",
		prefabs = { "slingshotammo_horrorfuel_debuff_fx", "slingshot_aoe_fx" },
		--tailcolor = { h = -0.1, s = 1.45, v = 0.35, lo = 1 },
		canmagicamp = true,
    },
	{
		name = "slingshotammo_gelblob",
		symbol = "gelblob",
		onhit = OnHit_GelBlob,
        inv_master_postinit = InvMasterPostInit_Gelblob,
		damage = nil,
		skill = "walter_ammo_shadow",
		--tailcolor = { v = 0 },
	},
    {
        name = "slingshotammo_scrapfeather",
		symbol = "scrapfeather",
		idleanim = "idle_scrapfeather",
		idlelooping = true,
		spinloop = "spin_loop_scrapfeather",
		spinloopmounted = "spin_loop_mount_scrapfeather",
		spinsymbol = "scrapfeather",
        onhit = OnHit_Scrapfeather,
		inv_common_postinit = CommonPostInit_Scrapfeather,
		proj_common_postinit = CommonPostInit_Scrapfeather,
        proj_master_postinit = ProjMasterPostInit_Scrapfeather,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_SCRAPFEATHER,
		skill = "walter_ammo_utility",
		prefabs = { "electrichitsparks", "electrichitsparks_electricimmune", },
		--tailcolor = { h = 0.1, s = 0.5, v = 2, lo = 0.2 },
    },
    {
        name = "slingshotammo_stinger",
		symbol = "stinger",
        onhit = OnHit_Stinger,
        damage = TUNING.SLINGSHOT_AMMO_DAMAGE_STINGER,
		skill = "walter_ammo_shattershots",
		--tailcolor = { s = 0, v = 0.7 },
    },
    {
        name = "trinket_1",
		no_inv_item = true,
		symbol = "trinket_1",
		damage = TUNING.SLINGSHOT_AMMO_DAMAGE_TRINKET_1,
		elemental = true,
		--tailcolor = { h = -0.07, s = 0.23, v = 0.9 },
    },
}

local ammo_prefabs = {}

local function AddAmmoPrefab(name, data, fn, prefabs)
    table.insert(ammo_prefabs, Prefab(name, function() return fn(data) end, assets, prefabs))
end

for _, data in ipairs(ammo) do
    data.impactfx = "slingshotammo_hitfx_" .. (data.symbol or "rock")

    if not data.no_inv_item then
        AddAmmoPrefab(data.name, data, inv_fn, { data.name.."_proj" })
    end

	local prefabs = { data.impactfx }
	if data.prefabs then
		ConcatArrays(prefabs, data.prefabs)
	end
	AddAmmoPrefab(data.name.."_proj", data, projectile_fn, prefabs)
end

return unpack(ammo_prefabs)