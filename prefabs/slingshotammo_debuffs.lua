local SpDamageUtil = require("components/spdamageutil")

local horrorfuel_assets =
{
    Asset("ANIM", "anim/slingshot_shadowcurse.zip"),
}

local slow_assets =
{
	Asset("ANIM", "anim/slingshotammo_slow_fx.zip"),
}

local brilliance_mark_prefabs =
{
    "slingshotammo_purebrilliance_debuff_fx",
    "purebrilliance_mark_hit_fx",
}

local brilliance_fx_assets =
{
    Asset("ANIM", "anim/slingshotammo_purebrilliance_mark_fx.zip"),
}

---------------------------------------------------------------------------------------------------------------------------------

-- Shared functions.

local function buff_Expire(inst)
    if inst.components.debuff ~= nil then
        inst.components.debuff:Stop()
    end
end

local function buff_OnLongUpdate(inst, dt)
    if inst._task == nil then
        return
    end

    local remaining = GetTaskRemaining(inst._task) - dt

    inst._task:Cancel()

    if remaining > 0 then
        inst._task = inst:DoTaskInTime(remaining, buff_Expire)
    else
        buff_Expire(inst)
    end
end

--------------------------------------------------------------------------

local function PushColour(inst, r, g, b)
    if inst.flashtarget.components.colouradder == nil then
        inst.flashtarget:AddComponent("colouradder")
    end
    inst.flashtarget.components.colouradder:PushColour(inst, r, g, b, 0)
end

local function PopColour(inst)
    if inst.flashtarget:IsValid() then
        inst.flashtarget.components.colouradder:PopColour(inst)
    end
end

local function UpdateFlash(inst)
    if inst.flashtarget:IsValid() then
        if inst.flashstep < 4 then
            local value = (inst.flashstep > 2 and 4 - inst.flashstep or inst.flashstep) * 0.05
            if inst.flashcolour then
                local r, g, b = unpack(inst.flashcolour)
                PushColour(inst, value * r, value * g, value * b)
            else
                PushColour(inst, value, value, value)
            end
            inst.flashstep = inst.flashstep + 1
            return
        else
            PopColour(inst)
        end
    end
    inst.OnRemoveEntity = nil
    inst.components.updatelooper:RemoveOnUpdateFn(UpdateFlash)
end

local function StartFlash(inst, target, flashcolour)
    inst.components.updatelooper:AddOnUpdateFn(UpdateFlash)
    inst.flashtarget = target
    inst.flashstep = 1
    inst.flashcolour = flashcolour
    inst.OnRemoveEntity = PopColour
    UpdateFlash(inst)
end

local function CancelFlash(inst)
    if inst.flashtarget then
        PopColour(inst)
        inst.components.updatelooper:RemoveOnUpdateFn(UpdateFlash)
        inst.flashtarget = nil
        inst.flashstep = nil
        inst.flashcolour = nil
        inst.OnRemoveEntity = nil
    end
end

---------------------------------------------------------------------------------------------------------------------------------

local function PureBrilliance_SpawnHitFx(inst, attacker)
    if inst._owner == nil or not inst._owner:IsValid() then
        return
    end

	local fx = SpawnPrefab("purebrilliance_mark_hit_fx")
	local radius = inst._owner:GetPhysicsRadius(0) + .1 + math.random() * .3
	local x, y, z = inst._owner.Transform:GetWorldPosition()
	local theta

	if attacker ~= nil then
		local x1, y1, z1 = attacker.Transform:GetWorldPosition()

		if x ~= x1 or z ~= z1 then
			theta = math.atan2(z - z1, x1 - x) + math.random() * 1 - .5
		end
	end

	if theta == nil then
		theta = math.random() * TWOPI
	end

	fx.Transform:SetPosition(
		x + radius * math.cos(theta),
		math.random(),
		z - radius * math.sin(theta)
	)

    return fx -- Mods
end

local PUREBRILLIANCE_FLASH_COLOUR = { 1, 1, 1, 0 }

local function PureBrilliance_OnOwnerAttacked(inst, owner, data)
    if data == nil or data.redirected then
        return
    end

    if data.attacker ~= nil and data.attacker:HasTag("attacktriggereddebuff") then
        return -- Don't trigger from another attacktriggereddebuff entity.
    end

    if data.attacker == inst then
        return -- Don't trigger itself!
    end

    local attacker_spdmg = data.attacker ~= nil and SpDamageUtil.CollectSpDamage(data.attacker) or 0
    local weapon_spdmg   = data.weapon ~= nil   and SpDamageUtil.CollectSpDamage(data.weapon)   or 0

    if attacker_spdmg == 0 and weapon_spdmg == 0 then
        return -- Only triggered by planar attacks.
    end

    if owner ~= nil and owner:IsValid() and
        not (owner.components.health and owner.components.health:IsDead()) and
        (owner.components.combat and owner.components.combat:CanBeAttacked())
    then
        local damagetypemult = inst.components.damagetypebonus:GetBonus(owner) or 1

        local spdmg = SpDamageUtil.CollectSpDamage(inst)

        if spdmg and damagetypemult ~= 1 then
            spdmg = SpDamageUtil.ApplyMult(spdmg, damagetypemult)
        end

        owner.components.combat:GetAttacked(inst, 0, nil, nil, spdmg)

        if data.attacker ~= nil then
            inst:SpawnHitFx(data.attacker)

            StartFlash(inst, owner, PUREBRILLIANCE_FLASH_COLOUR)
        end
    end
end

local function PureBrilliance_OnAttached(inst, target, followsymbol, followoffset, data)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0)

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)

    inst._owner = target
    inst._task  = inst:DoTaskInTime(TUNING.SLINGSHOT_BRILLIANCE_MARK_TIMEOUT, buff_Expire)

    if target:IsValid() then
        inst._fx = SpawnPrefab("slingshotammo_purebrilliance_debuff_fx")
        inst._fx:AttachTo(target)

        inst:ListenForEvent("attacked", inst._onattackedfn, target)
    end
end

local function PureBrilliance_OnDetached(inst, target)
    if inst._fx ~= nil then
        inst._fx.AnimState:PlayAnimation("fx_front_pst_"..inst._fx.size)
        inst._fx._back.AnimState:PushAnimation("fx_back_pst_"..inst._fx.size)

        inst._fx:ListenForEvent("animover", inst.Remove)

        inst._fx = nil
    end

    if inst._owner ~= nil and inst._owner:IsValid() then
        inst:RemoveEventCallback("attacked", inst._onattackedfn, inst._owner)
    end

    inst:Remove()
end

local function PureBrilliance_OnExtended(inst)
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = inst:DoTaskInTime(TUNING.SLINGSHOT_BRILLIANCE_MARK_TIMEOUT, buff_Expire)
    end
end

--------------------------------------------------------------------------------------------------------------------------------

local function PureBrillianceMarkFn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        -- Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)

        return inst
    end

    --[[Non-networked entity]]

    inst.entity:AddTransform()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("attacktriggereddebuff")

    inst._onattackedfn = function(owner, data) PureBrilliance_OnOwnerAttacked(inst, owner, data) end

    inst.SpawnHitFx = PureBrilliance_SpawnHitFx

    inst:AddComponent("updatelooper")

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.SLINGSHOT_BRILLIANCE_MARK_PLANAR_DAMAGE)

    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SLINGSHOT_AMMO_VS_SHADOW_BONUS)

    inst:AddComponent("debuff")
    inst.components.debuff.keepondespawn = true
    inst.components.debuff:SetAttachedFn(PureBrilliance_OnAttached)
    inst.components.debuff:SetDetachedFn(PureBrilliance_OnDetached)
    inst.components.debuff:SetExtendedFn(PureBrilliance_OnExtended)

    inst.persists = false

    inst.OnLongUpdate = buff_OnLongUpdate

    return inst
end

--------------------------------------------------------------------------------------------------------------------------------

local function PureBrillianceMarkFx_GetBestSymbolAndSize(inst, target)
    local burnable = target.components.burnable

    local fxdata1 = burnable ~= nil and burnable.fxdata ~= nil and burnable.fxdata[1] or nil

    if fxdata1 ~= nil and fxdata1.follow ~= nil then
        return fxdata1.follow, burnable.fxlevel
    end

    local freezable = target.components.freezable

    fxdata1 = freezable ~= nil and freezable.fxdata ~= nil and freezable.fxdata[1] or nil

    if fxdata1 ~= nil and fxdata1.follow ~= nil then
        return fxdata1.follow, freezable.fxlevel - 1
    end

    local combat = target.components.combat

    if combat ~= nil and combat.hiteffectsymbol ~= nil then
        return combat.hiteffectsymbol, (target:HasTag("smallcreature") and 1) or (target:HasAnyTag("largecreature", "epic") and 3) or 2
    end
end

local function PureBrillianceMarkFx_AttachTo(inst, target)
    inst._back = SpawnPrefab("slingshotammo_purebrilliance_debuff_fx")
    inst._back.AnimState:SetFinalOffset(-1)

    inst.entity:SetParent(target.entity)
    inst._back.entity:SetParent(target.entity)

    inst.Transform:SetPosition(0, 0, 0)
    inst._back.Transform:SetPosition(0, 0, 0)

    inst.SoundEmitter:PlaySound("meta5/walter/ammo_pstfx_purebrilliance_lp", "loop")

    local symbol, size = inst:GetBestSymbolAndSize(target)

    if symbol ~= nil then
        local x, y, z, success = target.AnimState:GetSymbolPosition(symbol)

        if success then
            inst.Follower:FollowSymbol(target.GUID, symbol)
            inst._back.Follower:FollowSymbol(target.GUID, symbol)
        end

        inst.size = math.clamp(size or 2, 1, 3)

        inst.AnimState:PlayAnimation("fx_front_pre_"..inst.size)
        inst.AnimState:PushAnimation("fx_front_loop_"..inst.size)

        inst._back.AnimState:PlayAnimation("fx_back_pre_"..inst.size)
        inst._back.AnimState:PushAnimation("fx_back_loop_"..inst.size)
    end
end

local function PureBrillianceMarkFx_OnRemoved(inst)
    if inst._back ~= nil then
        inst._back:Remove()
    end
end

local function PureBrillianceMarkFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.AnimState:SetBank("slingshotammo_purebrilliance_mark_fx")
    inst.AnimState:SetBuild("slingshotammo_purebrilliance_mark_fx")
    inst.AnimState:PlayAnimation("fx_front_pre_2")
    inst.AnimState:PushAnimation("fx_front_loop_2")

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst.AnimState:SetLightOverride(.3)
    inst.AnimState:SetFinalOffset(1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnRemoveEntity = PureBrillianceMarkFx_OnRemoved

    inst.AttachTo = PureBrillianceMarkFx_AttachTo
    inst.GetBestSymbolAndSize = PureBrillianceMarkFx_GetBestSymbolAndSize

    inst.persists = false

    return inst
end

--------------------------------------------------------------------------------------------------------------------------------

local HORROR_FLASH_COLOUR = { 1, 0, 0, 0 }

local function HorrorFuel_DoAttack(inst, attacker, target)
    inst._task1 = nil
    if target and target:IsValid() and
        not (target.components.health and target.components.health:IsDead()) and
        (target.components.combat and target.components.combat:CanBeAttacked())
    then
        local damagetypemult = inst.components.damagetypebonus:GetBonus(target) or 1
        local spdmg = SpDamageUtil.CollectSpDamage(inst)
        if spdmg and damagetypemult ~= 1 then
            spdmg = SpDamageUtil.ApplyMult(spdmg, damagetypemult)
        end

        target.components.combat:GetAttacked(inst, 0, nil, nil, spdmg)
        if target.components.combat and not target.components.combat:HasTarget() and attacker and attacker:IsValid() then
            target:PushEvent("attacked", { attacker = attacker, damage = 0 })
        end

        StartFlash(inst, target, HORROR_FLASH_COLOUR)
    end
end

local function HorrorFuel_AnimOver(inst, target)
    if inst._task1 then
        inst._task1:Cancel()
        inst._task1 = nil
    end
    inst._task2 = nil

    if inst._target then
        inst:RemoveEventCallback("onremove", inst._ontargetremoved, inst._target)
        inst._target = nil
        inst._ontargetremoved = nil
    end

    if inst.pool and inst.onrecyclefn and target and target._slingshot_horror and target._slingshot_horror.pool == inst.pool then
        CancelFlash(inst)
        inst.Follower:StopFollowing()
        inst:onrecyclefn(inst.pool)
    else
        inst:Remove()
    end
end

local function HorrorFuel_Restart(inst, attacker, target, variation, quick)
    inst.AnimState:PlayAnimation("idle"..tostring(variation))
    local hitframe = 28
    if quick then
        inst.AnimState:SetFrame(3)
        hitframe = hitframe - 3
    end

    if inst._task1 then
        inst._task1:Cancel()
    end
    if inst._task2 then
        inst._task2:Cancel()
    end
    inst._task1 = inst:DoTaskInTime(hitframe * FRAMES, HorrorFuel_DoAttack, attacker, target)
    inst._task2 = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), HorrorFuel_AnimOver, target)

    inst.Transform:SetPosition(0, 0, 0)

    if target and target:IsValid() then
        if target.components.combat and target.components.combat.hiteffectsymbol then
            local x, y, z, success = target.AnimState:GetSymbolPosition(target.components.combat.hiteffectsymbol)
            if success then
                inst.Follower:FollowSymbol(target.GUID, target.components.combat.hiteffectsymbol)
            end
            --otherwise stay parented at 0,0,0
        end
        inst._target = target
        inst._ontargetremoved = function(target)
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Follower:StopFollowing()
            inst.entity:SetParent(nil)
            inst.Transform:SetPosition(x, y, z)
            inst.pool = nil
            inst.onrecyclefn = nil
        end
        inst:ListenForEvent("onremove", inst._ontargetremoved, target)
    end

	inst.SoundEmitter:PlaySound("meta5/walter/ammo_pstfx_purehorror")
end

local function HorrorFuelFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")

    inst.AnimState:SetBank("slingshot_shadowcurse")
    inst.AnimState:SetBuild("slingshot_shadowcurse")
    inst.AnimState:SetFinalOffset(7)
    inst.AnimState:SetSymbolLightOverride("parts_red", 1)

	inst:SetPrefabNameOverride("slingshotammo_horrorfuel")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("updatelooper")

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.SLINGSHOT_HORROR_PLANAR_DAMAGE)

    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SLINGSHOT_AMMO_VS_LUNAR_BONUS)

    inst.Restart = HorrorFuel_Restart
    inst._task2 = inst:DoTaskInTime(0, HorrorFuel_AnimOver)
    inst.persists = false

    return inst
end

--------------------------------------------------------------------------------------------------------------------------------

local function Slow_AnimName(inst, anim, overridelevel)
	return string.format("slow_%s_%s_%d", anim, inst._size, overridelevel or inst._level)
end

local function Slow_StartFX(inst, target, delay)
	if inst._inittask and target and target:IsValid() then
		inst._inittask:Cancel()
		if delay then
			inst._inittask = inst:DoTaskInTime(delay, Slow_StartFX, target)
		else
			inst._inittask = nil

			--[[if target.components.combat and target.components.combat.hiteffectsymbol then
				local x, y, z, success = target.AnimState:GetSymbolPosition(target.components.combat.hiteffectsymbol)
				if success then
					inst.entity:AddFollower():FollowSymbol(target.GUID, target.components.combat.hiteffectsymbol)
				end
				--otherwise stay parented at 0,0,0
			end]]

			inst._size =
				(target:HasTag("smallcreature") and "small") or
				(target:HasAnyTag("largecreature") and "large") or
				"med"

			--NOTE: we might have leveled up during delay, but pre anim only has level 1
			inst.AnimState:PlayAnimation(Slow_AnimName(inst, "pre", 1))
			inst.AnimState:PushAnimation(Slow_AnimName(inst, "loop"))
		end
	end
end

local function Slow_SetFXLevel(inst, level)
	if not inst.killed and inst._level ~= level then
		inst._level = level
		if not inst._inittask then
			inst.AnimState:PlayAnimation(Slow_AnimName(inst, "loop"), true)
			inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
		end
	end
end

local function Slow_KillFX(inst)
	if inst._inittask then
		inst:Remove()
	elseif not inst.killed then
		inst.killed = true
		inst.AnimState:PlayAnimation(Slow_AnimName(inst, "pst"))
		--timer so it removes even when asleep
		inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), inst.Remove)
	end
end

local function SlowFn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	--inst.entity:AddFollower() --add when needed, this is not pooled
	inst.entity:AddNetwork()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("slingshotammo_slow_fx")
	inst.AnimState:SetBuild("slingshotammo_slow_fx")
	inst.AnimState:SetFinalOffset(7)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst._level = 1
	inst._inittask = inst:DoTaskInTime(0, inst.Remove)
	inst.StartFX = Slow_StartFX
	inst.SetFXLevel = Slow_SetFXLevel
	inst.KillFX = Slow_KillFX

	inst.persists = false

	return inst
end

--------------------------------------------------------------------------------------------------------------------------------

return
    Prefab("slingshotammo_purebrilliance_debuff",    PureBrillianceMarkFn,   nil,                 brilliance_mark_prefabs),
    Prefab("slingshotammo_purebrilliance_debuff_fx", PureBrillianceMarkFxFn, brilliance_fx_assets                        ),
    Prefab("slingshotammo_horrorfuel_debuff_fx",     HorrorFuelFxFn,         horrorfuel_assets                           ),
    Prefab("slingshotammo_slow_debuff_fx",           SlowFn,                 slow_assets                                 )
