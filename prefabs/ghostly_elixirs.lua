
--DSV uses 4 but ignores physics radius
local NO_TAGS_NO_PLAYERS =	{ "INLIMBO", "notarget", "noattack", "wall", "player", "companion", "playerghost" }
local COMBAT_TARGET_TAGS = { "_combat" }

local onattacked_shield = function(inst, data)
 	if data.redirected then
 		return
 	end

	local hat = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
	if hat and hat.components.rechargeable and hat.components.rechargeable:IsCharged() then

		local fx = SpawnPrefab("elixir_player_forcefield")
		inst:AddChild(fx)
		inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/on")

		inst.components.health.externalreductionmodifiers:RemoveModifier(inst, "forcefield")

		local debuff = inst:GetDebuff("elixir_buff")
		if not debuff then
			return
		end

		if debuff.potion_tunings.playerreatliate then
			local hitrange = 5
			local damage = TUNING.GHOSTLYELIXIR_RETALIATION_DAMAGE

				--local retaliation = SpawnPrefab("abigail_retaliation")
				--retaliation:SetRetaliationTarget(data.attacker)
		
			debuff.ignore = {}

		    local x, y, z = inst.Transform:GetWorldPosition()		    

			for i, v in ipairs(TheSim:FindEntities(x, y, z, hitrange, COMBAT_TARGET_TAGS, NO_TAGS_NO_PLAYERS)) do
				if not debuff.ignore[v] and
					v:IsValid() and
					v.entity:IsVisible() and
					v.components.combat ~= nil then
					local range = hitrange + v:GetPhysicsRadius(0)
					if v:GetDistanceSqToPoint(x, y, z) < range * range then
						if inst.owner ~= nil and not inst.owner:IsValid() then
							inst.owner = nil
						end
						if inst.owner ~= nil then
							if inst.owner.components.combat ~= nil and
								inst.owner.components.combat:CanTarget(v) and
								not inst.owner.components.combat:IsAlly(v)
							then
								debuff.ignore[v] = true
								local retaliation = SpawnPrefab("abigail_retaliation")
								retaliation:SetRetaliationTarget(v)
								--V2C: wisecracks make more sense for being pricked by picking
								--v:PushEvent("thorns")
							end
						elseif v.components.combat:CanBeAttacked() then
							-- NOTES(JBK): inst.owner is nil here so this is for non worn things like the bramble trap.
							local isally = false
							if not inst.canhitplayers then
								--non-pvp, so don't hit any player followers (unless they are targeting a player!)
								local leader = v.components.follower ~= nil and v.components.follower:GetLeader() or nil
								isally = leader ~= nil and leader:HasTag("player") and
									not (v.components.combat ~= nil and
										v.components.combat.target ~= nil and
										v.components.combat.target:HasTag("player"))
							end
							if not isally then
								debuff.ignore[v] = true
								v.components.combat:GetAttacked(inst, damage, nil, nil, inst.spdmg)
								local retaliation = SpawnPrefab("abigail_retaliation")
								retaliation:SetRetaliationTarget(v)
								--v:PushEvent("thorns")
							end
						end
					end
				end
			end
		
		end
		hat.components.rechargeable:Discharge(10)
	end

	--debuff.components.debuff:Stop()
end

local potion_tunings =
{
	ghostlyelixir_slowregen =
	{
		TICK_RATE = TUNING.GHOSTLYELIXIR_SLOWREGEN_TICK_TIME,
		ONAPPLY = function(inst, target)
			target:PushEvent("startsmallhealthregen", inst)
		end,
		TICK_FN = function(inst, target)
			local mult = 1
			if (target.components.follower and
				target.components.follower.leader and
				target.components.follower.leader.components.skilltreeupdater and
				target.components.follower.leader.components.skilltreeupdater:IsActivated("wendy_sisturn_3")) and
				(TheWorld.components.sisturnregistry and
				TheWorld.components.sisturnregistry:IsBlossom()) and 
				not target:HasTag("INLIMBO") then
					mult = 0.5
            end
			target.components.health:DoDelta(TUNING.GHOSTLYELIXIR_SLOWREGEN_HEALING*mult, true, inst.prefab)
		end,
		DURATION = TUNING.GHOSTLYELIXIR_SLOWREGEN_DURATION,
		FLOATER = {"small", 0.15, 0.55},
		fx = "ghostlyelixir_slowregen_fx",
		dripfx = "ghostlyelixir_slowregen_dripfx",
		skill_modifier_long_duration = true,

		-- PLAYER CONTENT
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_SLOWREGEN_DURATION,
		TICK_FN_PLAYER = function(inst, target)

			target.components.health:DoDelta(TUNING.GHOSTLYELIXIR_PLAYER_SLOWREGEN_HEALING, true, inst.prefab)
		end,
		fx_player = "ghostlyelixir_player_slowregen_fx",
		dripfx_player = "ghostlyelixir_player_slowregen_dripfx",
		ghostly_healing = true,
	},
	ghostlyelixir_fastregen =
	{
		TICK_RATE = TUNING.GHOSTLYELIXIR_FASTREGEN_TICK_TIME,
		ONAPPLY = function(inst, target)
			target:PushEvent("starthealthregen", inst)
		end,
		TICK_FN = function(inst, target)
			local mult = 1
			if (target.components.follower and
				target.components.follower.leader and
				target.components.follower.leader.components.skilltreeupdater and
				target.components.follower.leader.components.skilltreeupdater:IsActivated("wendy_sisturn_3")) and
				(TheWorld.components.sisturnregistry and
				TheWorld.components.sisturnregistry:IsBlossom()) and 
				not target:HasTag("INLIMBO") then
					mult = 0.5
            end
			target.components.health:DoDelta(TUNING.GHOSTLYELIXIR_FASTREGEN_HEALING*mult, true, inst.prefab)
		end,
		DURATION = TUNING.GHOSTLYELIXIR_FASTREGEN_DURATION,
		FLOATER = {"small", 0.15, 0.55},
		fx = "ghostlyelixir_fastregen_fx",
		dripfx = "ghostlyelixir_fastregen_dripfx",

		-- PLAYER CONTENT
		ONAPPLY_PLAYER = function(inst, target)
			target:PushEvent("starthealthregen", inst)
		end,
		TICK_FN_PLAYER = function(inst, target)
			target.components.health:DoDelta(TUNING.GHOSTLYELIXIR_PLAYER_FASTREGEN_HEALING, true, inst.prefab)
		end,
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_FASTREGEN_DURATION,
		fx_player = "ghostlyelixir_player_fastregen_fx",
		dripfx_player = "ghostlyelixir_player_fastregen_dripfx",
		ghostly_healing = true,
	},
	ghostlyelixir_attack =
	{
		ONAPPLY = function(inst, target)
			if target.UpdateDamage then
				target:UpdateDamage()
			end
		end,
		ONDETACH = function(inst, target)
			if target:IsValid() and target.UpdateDamage then
				target:UpdateDamage()
			end
		end,
		DURATION = TUNING.GHOSTLYELIXIR_DAMAGE_DURATION,
		FLOATER = {"small", 0.1, 0.5},
		fx = "ghostlyelixir_attack_fx",
		dripfx = "ghostlyelixir_attack_dripfx",
		skill_modifier_long_duration = true,

		-- PLAYER CONTENT
		ONAPPLY_PLAYER = function(inst, target)
			if not target:HasDebuff("ghostvision_buff") then
				target.components.talker:Say(GetString(target, "ANNOUNCE_ELIXIR_GHOSTVISION"))
			end
			target:AddDebuff("ghostvision_buff","ghostvision_buff")
		end,
		ONDETACH_PLAYER = function(inst, target)
			target:RemoveDebuff("ghostvision_buff")
		end,
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_DAMAGE_DURATION,
		fx_player = "ghostlyelixir_player_attack_fx",
		dripfx_player = "ghostlyelixir_player_attack_dripfx",
	},
	ghostlyelixir_speed =
	{
		DURATION = TUNING.GHOSTLYELIXIR_SPEED_DURATION,
		ONAPPLY = function(inst, target)
			target.components.locomotor:SetExternalSpeedMultiplier(
				inst,
				"ghostlyelixir",
				TUNING.GHOSTLYELIXIR_SPEED_LOCO_MULT
			)
		end,
        FLOATER = {"small", 0.2, 0.4},
		fx = "ghostlyelixir_speed_fx",
		dripfx = "ghostlyelixir_speed_dripfx",
		speed_hauntable = true,
		skill_modifier_long_duration = true,

		--PLAYER CONTENT
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_SPEED_DURATION,
		ONAPPLY_PLAYER = function(inst, target)
			target.components.talker:Say(GetString(target, "ANNOUNCE_ELIXIR_PLAYER_SPEED"))
			target:AddTag("vigorbuff")
			target.components.locomotor:EnableGroundSpeedMultiplier(false)
			target.components.locomotor:EnableGroundSpeedMultiplier(true)
		end,
		ONDETACH_PLAYER = function(inst, target)
			target:RemoveTag("vigorbuff")
		end,
		fx_player = "ghostlyelixir_player_speed_fx",
		dripfx_player = "ghostlyelixir_player_speed_dripfx",
	},
	ghostlyelixir_shield =
	{
		DURATION = TUNING.GHOSTLYELIXIR_SHIELD_DURATION,
        FLOATER = {"small", 0.15, 0.8},
		shield_prefab = "abigailforcefieldbuffed",
		fx = "ghostlyelixir_shield_fx",
		dripfx = "ghostlyelixir_shield_dripfx",
		skill_modifier_long_duration = true,

		--PLAYER CONTENT
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_DURATION,
		ONAPPLY_PLAYER = function(inst, target)
			if target.components.health ~= nil then
				target.components.health.externalreductionmodifiers:SetModifier(target, TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_REDUCTION, "forcefield")
			end			
		    target:ListenForEvent("attacked", onattacked_shield)
		    inst.recharge = function()
		    	if target.components.health ~= nil then
					target.components.health.externalreductionmodifiers:SetModifier(target, TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_REDUCTION, "forcefield")
				end			
			end
		end,
		ONDETACH_PLAYER = function(inst, target)
			target:RemoveEventCallback("attacked", onattacked_shield)
			if target.components.health ~= nil then
				target.components.health.externalreductionmodifiers:RemoveModifier(target, "forcefield")
			end
		end,
		fx_player = "ghostlyelixir_player_shield_fx",
		dripfx_player = "ghostlyelixir_player_shield_dripfx",
	},
	ghostlyelixir_retaliation =
	{
		DURATION = TUNING.GHOSTLYELIXIR_RETALIATION_DURATION,
        FLOATER = {"small", 0.2, 0.4},
		shield_prefab = "abigailforcefieldretaliation",
		fx = "ghostlyelixir_retaliation_fx",
		dripfx = "ghostlyelixir_retaliation_dripfx",
		skill_modifier_long_duration = true,

		--PLAYER CONTENT
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_DURATION,
		ONAPPLY_PLAYER = function(inst, target)
			if target.components.health ~= nil then
				target.components.health.externalreductionmodifiers:SetModifier(target, TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_REDUCTION, "forcefield")
			end
		    target:ListenForEvent("attacked", onattacked_shield)
		    inst.recharge = function()
		    	if target.components.health ~= nil then
					target.components.health.externalreductionmodifiers:SetModifier(target, TUNING.GHOSTLYELIXIR_PLAYER_SHIELD_REDUCTION, "forcefield")
				end			
			end		    
		end,
		ONDETACH_PLAYER = function(inst, target)
			target:RemoveEventCallback("attacked", onattacked_shield)
			if target.components.health ~= nil then
				target.components.health.externalreductionmodifiers:RemoveModifier(target, "forcefield")
			end
		end,
		playerreatliate=true,
		fx_player = "ghostlyelixir_player_retaliation_fx",
		dripfx_player = "ghostlyelixir_player_retaliation_dripfx",
	},
	ghostlyelixir_revive =
	{
		DURATION = TUNING.GHOSTLYELIXIR_REVIVE_DURATION,
        FLOATER = {"small", 0.1, 0.7},
		ONAPPLY = function(inst, target)
			if target.components.follower.leader and target.components.follower.leader.components.ghostlybond then
				target.components.follower.leader.components.ghostlybond:SetBondLevel(3)
			end
		end,
		fx = "ghostlyelixir_retaliation_fx",
		dripfx = "ghostlyelixir_retaliation_dripfx",
		skill_modifier_long_duration = true,

		--PLAYER CONTENT
		DURATION_PLAYER = TUNING.GHOSTLYELIXIR_PLAYER_REVIVE_DURATION,
		ONAPPLY_PLAYER = function(inst, target)
			target.components.talker:Say(GetString(target, "ANNOUNCE_ELIXIR_BOOSTED"))

			if target.components.sanity then
				target.components.sanity:DoDelta(TUNING.SANITY_TINY)
			end
			if target.components.hunger then
				target.components.hunger:DoDelta(TUNING.CALORIES_SMALL)
			end

			if target.components.health ~= nil then
				target.components.health:DeltaPenalty(TUNING.MAX_HEALING_NORMAL)
			end
		end,
		fx_player = "ghostlyelixir_player_retaliation_fx",
		dripfx_player = "ghostlyelixir_player_retaliation_dripfx",
	},

	ghostlyelixir_shadow =
	{
		DURATION = TUNING.SKILLS.WENDY.SHADOWELIXIR_DURATION,
        FLOATER = {"small", 0.2, 0.7},
		fx = "ghostlyelixir_shadow_fx",
		dripfx = "ghostlyelixir_shadow_dripfx",
		skill_modifier_long_duration = true,
		super_elixir = true,
	},
	ghostlyelixir_lunar =
	{
		DURATION = TUNING.SKILLS.WENDY.LUNARELIXIR_DURATION,
        FLOATER = {"small", 0.3, 0.8},
		fx = "ghostlyelixir_lunar_fx",
		dripfx = "ghostlyelixir_lunar_dripfx",
		ONAPPLY = function(inst, target)
			target.components.planardamage:RemoveBonus(inst, "ghostlyelixir_lunarbonus")
			local bonus_amount = (target:HasTag("gestalt") and TUNING.SKILLS.WENDY.LUNARELIXIR_DAMAGEBONUS_GESTALT)
				or TUNING.SKILLS.WENDY.LUNARELIXIR_DAMAGEBONUS
			target.components.planardamage:AddBonus(inst, bonus_amount, "ghostlyelixir_lunarbonus")
		end,
		ONDETACH = function(inst, target)
			target.components.planardamage:RemoveBonus(inst, "ghostlyelixir_lunarbonus")
		end,
		skill_modifier_long_duration = true,
		super_elixir = true,
	},
}

local function DoApplyElixir(inst, giver, target)
	local buff_type = "elixir_buff"

	if inst.potion_tunings.super_elixir then
		buff_type = "super_elixir_buff"
	end

	local buff = target:AddDebuff(buff_type, inst.buff_prefab, nil, nil, function()
		local cur_buff = target:GetDebuff(buff_type)
		if cur_buff ~= nil and cur_buff.prefab ~= inst.buff_prefab then
			target:RemoveDebuff(buff_type)
		end
	end)

	if buff then
		local new_buff = target:GetDebuff(buff_type)
		new_buff:buff_skill_modifier_fn(giver, target)
		return buff
	end
end

local SPEED_HAUNT_MULTIPLIER_NAME = "haunted_speedpot"
local function speed_potion_haunt_remove_buff(inst)
    if inst._haunted_speedpot_task ~= nil then
        inst._haunted_speedpot_task:Cancel()
        inst._haunted_speedpot_task = nil
    end
	inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, SPEED_HAUNT_MULTIPLIER_NAME)
	inst:RemoveEventCallback("ms_respawnedfromghost", speed_potion_haunt_remove_buff)
end

local function speed_potion_haunt(inst, haunter)
    Launch(inst, haunter, TUNING.LAUNCH_SPEED_SMALL)
    inst.components.hauntable.hauntvalue = TUNING.HAUNT_TINY
    if haunter:HasTag("playerghost") then
        haunter.components.locomotor:SetExternalSpeedMultiplier(haunter, SPEED_HAUNT_MULTIPLIER_NAME, TUNING.GHOSTLYELIXIR_SPEED_LOCO_MULT)
        if haunter._haunted_speedpot_task ~= nil then
            haunter._haunted_speedpot_task:Cancel()
            haunter._haunted_speedpot_task = nil
        end
		haunter:ListenForEvent("ms_respawnedfromghost", speed_potion_haunt_remove_buff)
        haunter._haunted_speedpot_task = haunter:DoTaskInTime(TUNING.GHOSTLYELIXIR_SPEED_PLAYER_GHOST_DURATION, speed_potion_haunt_remove_buff)
    end

    return true
end

local function potion_fn(anim, potion_tunings, buff_prefab)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("ghostly_elixirs")
    inst.AnimState:SetBuild("ghostly_elixirs")
    inst.AnimState:PlayAnimation(anim)
    inst.scrapbook_anim = anim
    inst.scrapbook_specialinfo = "GHOSTLYELIXER".. string.upper(anim)
    inst.elixir_buff_type = anim

    if potion_tunings.FLOATER ~= nil then
        MakeInventoryFloatable(inst, potion_tunings.FLOATER[1], potion_tunings.FLOATER[2], potion_tunings.FLOATER[3])
    else
        MakeInventoryFloatable(inst)
    end

	inst:AddTag("ghostlyelixir")

	if potion_tunings.super_elixir then
		inst:AddTag("super_elixir")
	end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

	inst.buff_prefab = buff_prefab
	inst.potion_tunings = potion_tunings

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst:AddComponent("stackable")

    inst:AddComponent("ghostlyelixir")
	inst.components.ghostlyelixir.doapplyelixerfn = DoApplyElixir

    -- Players can haunt the speed potion to get a temporary speed boost.
    -- Shh it's a secret.
    if potion_tunings.speed_hauntable then
        inst:AddComponent("hauntable")
        inst.components.hauntable.cooldown = TUNING.HAUNT_COOLDOWN_SMALL
        inst.components.hauntable:SetOnHauntFn(speed_potion_haunt)
    else
        MakeHauntableLaunch(inst)
    end

    inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

    return inst
end

local function buff_OnTick(inst, target)
    if target.components.health ~= nil and not target.components.health:IsDead() then
		if target:HasTag("player") then
			inst.potion_tunings.TICK_FN_PLAYER(inst, target)
		else
			inst.potion_tunings.TICK_FN(inst, target)
		end
    else
        inst.components.debuff:Stop()
    end
end

local function buff_DripFx(inst, target)
	local prefab = (target:HasTag("player") and inst.potion_tunings.dripfx_player) or inst.potion_tunings.dripfx

    if not target.inlimbo and not target.sg:HasStateTag("busy") then
		SpawnPrefab(prefab).Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

local function buff_OnAttached(inst, target)
	inst.entity:SetParent(target.entity)
	inst.Transform:SetPosition(0, 0, 0) --in case of loading

	if target:HasTag("player") then
		if inst.potion_tunings.ONAPPLY_PLAYER ~= nil then
			inst.potion_tunings.ONAPPLY_PLAYER(inst, target)
		end
	else
		if inst.potion_tunings.ONAPPLY ~= nil then
			inst.potion_tunings.ONAPPLY(inst, target)
		end
	end

	if inst.potion_tunings.TICK_RATE ~= nil then
	    inst.task = inst:DoPeriodicTask(inst.potion_tunings.TICK_RATE, buff_OnTick, nil, target)
	end

    inst.driptask = inst:DoPeriodicTask(TUNING.GHOSTLYELIXIR_DRIP_FX_DELAY, buff_DripFx, TUNING.GHOSTLYELIXIR_DRIP_FX_DELAY * 0.25, target)

    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)

	if inst.potion_tunings.fx ~= nil and not target.inlimbo then
		local fx = SpawnPrefab((target:HasTag("player") and inst.potion_tunings.fx_player) or inst.potion_tunings.fx)
	    fx.entity:SetParent(target.entity)
	end
end

local function buff_OnTimerDone(inst, data)
    if data.name == "decay" then
        inst.components.debuff:Stop()
    end
end

local function buff_OnExtended(inst, target)
	local duration = (target:HasTag("player") and inst.potion_tunings.DURATION_PLAYER) or inst.potion_tunings.DURATION

    if inst.duration_extended_by_skill then
		duration = duration * inst.duration_extended_by_skill
    end

	inst.components.timer:StopTimer("decay")
	inst.components.timer:StartTimer("decay", duration)

	if inst.task ~= nil then
		inst.task:Cancel()
		inst.task = inst:DoPeriodicTask(inst.potion_tunings.TICK_RATE, buff_OnTick, nil, target)
	end

	if inst.potion_tunings.fx ~= nil and not target.inlimbo and not target:HasTag("player") then
		local fx = SpawnPrefab(inst.potion_tunings.fx)
	    fx.entity:SetParent(target.entity)
	end

	inst.slowed = nil
end

local function buff_OnDetached(inst, target)
	if inst.task ~= nil then
		inst.task:Cancel()
		inst.task = nil
	end
	if inst.driptask ~= nil then
		inst.driptask:Cancel()
		inst.driptask = nil
	end

	if target:HasTag("player") then
		if inst.potion_tunings.ONDETACH_PLAYER ~= nil then
			inst.potion_tunings.ONDETACH_PLAYER(inst, target)
		end
	else
		if inst.potion_tunings.ONDETACH ~= nil then
			inst.potion_tunings.ONDETACH(inst, target)
		end
	end
	inst:Remove()
end

local function buff_skill_modifier_fn(inst,doer,target)
	local duration_mult = 1

	if inst.potion_tunings.skill_modifier_long_duration and doer.components.skilltreeupdater:IsActivated("wendy_potion_duration") then
		duration_mult = duration_mult + TUNING.SKILLS.WENDY.POTION_DURATION_MOD
		inst.duration_extended_by_skill = TUNING.SKILLS.WENDY.POTION_DURATION_MOD
	end

	local duration = (target:HasTag("player") and inst.potion_tunings.DURATION_PLAYER) or inst.potion_tunings.DURATION
    inst.components.timer:StopTimer("decay")
    inst.components.timer:StartTimer("decay", duration * duration_mult )

	if target:HasTag("ghost") then
		target:updatehealingbuffs()
	end
end

local function buff_fn(tunings, dodelta_fn)
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)

        return inst
    end

    inst.buff_skill_modifier_fn = buff_skill_modifier_fn
    inst.entity:AddTransform()

    --[[Non-networked entity]]
    --inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst.persists = false

	inst.potion_tunings = tunings

    inst:AddTag("CLASSIFIED")

    local debuff = inst:AddComponent("debuff")
    debuff:SetAttachedFn(buff_OnAttached)
    debuff:SetDetachedFn(buff_OnDetached)
    debuff:SetExtendedFn(buff_OnExtended)
    debuff.keepondespawn = true

    local timer = inst:AddComponent("timer")
    timer:StartTimer("decay", tunings.DURATION)
    inst:ListenForEvent("timerdone", buff_OnTimerDone)

    return inst
end

local function AddPotion(potions, name, anim, extra_assets)
	local potion_prefab = "ghostlyelixir_"..name
	local buff_prefab = potion_prefab.."_buff"

	local assets = 	{
		Asset("ANIM", "anim/ghostly_elixirs.zip"),
		Asset("ANIM", "anim/abigail_buff_drip.zip"),
		Asset("ANIM", "anim/player_elixir_buff_drip.zip"),
		Asset("ANIM", "anim/player_vial_fx.zip"),
	}
	if extra_assets then ConcatArrays(assets, extra_assets) end

	local prefabs = {
		buff_prefab,
		potion_tunings[potion_prefab].fx,
		potion_tunings[potion_prefab].dripfx,
		potion_tunings[potion_prefab].fx_player,
		potion_tunings[potion_prefab].dripfx_player,
		"ghostvision_buff",
	}
	if potion_tunings[potion_prefab].shield_prefab ~= nil then
		table.insert(prefabs, potion_tunings[potion_prefab].shield_prefab)
	end

	local function _buff_fn() return buff_fn(potion_tunings[potion_prefab]) end
	local function _potion_fn() return potion_fn(anim, potion_tunings[potion_prefab], buff_prefab) end

	table.insert(potions, Prefab(potion_prefab, _potion_fn, assets, prefabs))
	table.insert(potions, Prefab(buff_prefab, _buff_fn))
end

local potions = {}
AddPotion(potions, "slowregen", "regeneration")
AddPotion(potions, "fastregen", "healing")
AddPotion(potions, "shield", "shield")
AddPotion(potions, "attack", "attack")
AddPotion(potions, "speed", "speed")
AddPotion(potions, "retaliation", "retaliation")
AddPotion(potions, "shadow", "shadow")
AddPotion(potions, "lunar", "lunar")
AddPotion(potions, "revive", "revive")

return unpack(potions)
