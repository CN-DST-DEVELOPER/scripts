local SpDamageUtil = require("components/spdamageutil")

local assets =
{
    Asset("ANIM", "anim/player_ghost_withhat.zip"),
    Asset("ANIM", "anim/ghost_abigail_build.zip"),

    Asset("ANIM", "anim/ghost_abigail.zip"),
    Asset("ANIM", "anim/ghost_abigail_gestalt.zip"),

    Asset("ANIM", "anim/lunarthrall_plant_front.zip"),
    Asset("ANIM", "anim/brightmare_gestalt_evolved.zip"),
    Asset("ANIM", "anim/ghost_abigail_commands.zip"),
    Asset("ANIM", "anim/ghost_abigail_gestalt_build.zip"),
    Asset("ANIM", "anim/ghost_abigail_shadow_build.zip"),
    Asset("ANIM", "anim/ghost_abigail_resurrect.zip"),
    Asset("ANIM", "anim/ghost_wendy_resurrect.zip"),

    Asset("ANIM", "anim/ghost_abigail_human.zip"),

    Asset("SOUND", "sound/ghost.fsb"),
}

local prefabs =
{
    "abigail_attack_fx",
    "abigail_attack_fx_ground",
	"abigail_retaliation",
	"abigailforcefield",
	"abigaillevelupfx",
	"abigail_vex_debuff",
    "abigail_vex_shadow_debuff",
    "abigail_attack_shadow_fx",
    "abigail_gestalt_hit_fx",
    "abigail_rising_twinkles_fx",
    "abigail_shadow_buff_fx",
}

local brain = require("brains/abigailbrain")

local function do_transparency(transparency_level, inst)
    inst.AnimState:OverrideMultColour(1.0, 1.0, 1.0, transparency_level)
end

local function UndoTransparency(inst)

   -- inst.components.fader:Fade(0.3, 1.0, 0.75, do_transparency)
    inst.fade_toggle:set(false)

    if not inst:HasTag("gestalt") then inst.components.aura:Enable(true) end

    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "transparency")
    inst:RemoveTag("notarget")
    inst._is_transparent = false

    inst.sg:GoToState("escape_end")
end

local function SetMaxHealth(inst)
    local health = inst.components.health
    if health then
        if health:IsDead() then
            health.maxhealth = inst.base_max_health + inst.bonus_max_health
        else
            local health_percent = health:GetPercent()
            health:SetMaxHealth( inst.base_max_health + inst.bonus_max_health )
            health:SetPercent(health_percent, true)
        end

        if inst._playerlink ~= nil and inst._playerlink.components.pethealthbar ~= nil then
            inst._playerlink.components.pethealthbar:SetMaxHealth(health.maxhealth)
        end
    end
end

local function UpdateGhostlyBondLevel(inst, level)
	local max_health = level == 3 and TUNING.ABIGAIL_HEALTH_LEVEL3
					or level == 2 and TUNING.ABIGAIL_HEALTH_LEVEL2
					or TUNING.ABIGAIL_HEALTH_LEVEL1

    inst.base_max_health = max_health

	SetMaxHealth(inst)

	local light_vals = TUNING.ABIGAIL_LIGHTING[level] or TUNING.ABIGAIL_LIGHTING[1]
	if light_vals.r ~= 0 then
		inst.Light:Enable(not inst.inlimbo)
		inst.Light:SetRadius(light_vals.r)
		inst.Light:SetIntensity(light_vals.i)
		inst.Light:SetFalloff(light_vals.f)
	else
		inst.Light:Enable(false)
	end
    inst.AnimState:SetLightOverride(light_vals.l)
end

local ABIGAIL_DEFENSIVE_MAX_FOLLOW_DSQ = TUNING.ABIGAIL_DEFENSIVE_MAX_FOLLOW * TUNING.ABIGAIL_DEFENSIVE_MAX_FOLLOW
local ABIGAIL_GESTALT_DEFENSIVE_MAX_FOLLOW_DSQ = TUNING.ABIGAIL_GESTALT_DEFENSIVE_MAX_FOLLOW * TUNING.ABIGAIL_GESTALT_DEFENSIVE_MAX_FOLLOW
local function IsWithinDefensiveRange(inst)
    local range = ABIGAIL_DEFENSIVE_MAX_FOLLOW_DSQ
    if inst:HasTag("gestalt") and inst.components.combat.target then
        range = ABIGAIL_GESTALT_DEFENSIVE_MAX_FOLLOW_DSQ
    end
    return (inst._playerlink ~= nil) and inst:GetDistanceSqToInst(inst._playerlink) < range
end

local function SetTransparentPhysics(inst, on)
	if on then
		inst.Physics:SetCollisionMask(TheWorld:CanFlyingCrossBarriers() and COLLISION.GROUND or COLLISION.WORLD)
	else
		inst.Physics:SetCollisionMask(
			TheWorld:CanFlyingCrossBarriers() and COLLISION.GROUND or COLLISION.WORLD,
			COLLISION.CHARACTERS,
			COLLISION.GIANTS
		)
	end
end

local COMBAT_MUSHAVE_TAGS = { "_combat", "_health" }
local COMBAT_CANTHAVE_TAGS = { "INLIMBO", "noauradamage", "companion" }

local COMBAT_MUSTONEOF_TAGS_AGGRESSIVE = { "monster", "prey", "insect", "hostile", "character", "animal" }
local COMBAT_MUSTONEOF_TAGS_DEFENSIVE = { "monster", "prey" }

local COMBAT_TARGET_DSQ = TUNING.ABIGAIL_COMBAT_TARGET_DISTANCE * TUNING.ABIGAIL_COMBAT_TARGET_DISTANCE

local function HasFriendlyLeader(inst, target, PVP_enabled)
    local leader = (inst.components.follower ~= nil and inst.components.follower.leader) or nil
    if not leader then
        return false
    end

    local target_leader = (target.components.follower ~= nil) and target.components.follower.leader or nil

    if target_leader and target_leader.components.inventoryitem then
        target_leader = target_leader.components.inventoryitem:GetGrandOwner()
        -- Don't attack followers if their follow object has no owner
        if not target_leader then
            return true
        end
    end

    if PVP_enabled == nil then
        PVP_enabled = TheNet:GetPVPEnabled()
    end

    return leader == target
        or (
            target_leader ~= nil
            and (
                target_leader == leader or (not PVP_enabled and target_leader.isplayer)
            )
        ) or (
            not PVP_enabled
            and target.components.domesticatable ~= nil
            and target.components.domesticatable:IsDomesticated()
        ) or (
            not PVP_enabled
            and target.components.saltlicker ~= nil
            and target.components.saltlicker.salted
        )
end

local function CommonRetarget(inst, v)
    return v ~= inst and v ~= inst._playerlink and v.entity:IsVisible()
            and v:GetDistanceSqToInst(inst._playerlink) < COMBAT_TARGET_DSQ
            and inst.components.combat:CanTarget(v)
            and v.components.minigame_participator == nil
            and not HasFriendlyLeader(inst, v)
            and not inst.components.timer:TimerExists("block_retargets")
end

local function DefensiveRetarget(inst)
    if not inst._playerlink or not IsWithinDefensiveRange(inst) then
        return nil
    else
        local ix, iy, iz = inst.Transform:GetWorldPosition()
        local entities_near_me = TheSim:FindEntities(
            ix, iy, iz, TUNING.ABIGAIL_DEFENSIVE_MAX_FOLLOW,
            COMBAT_MUSHAVE_TAGS, COMBAT_CANTHAVE_TAGS, COMBAT_MUSTONEOF_TAGS_DEFENSIVE
        )

        for _, v in ipairs(entities_near_me) do
            if CommonRetarget(inst, v)
                    and (v.components.combat.target == inst._playerlink or
                        inst._playerlink.components.combat.target == v or
                        v.components.combat.target == inst) then

                return v
            end
        end

        return nil
    end
end

local function AggressiveRetarget(inst)
    if inst._playerlink == nil then
        return nil
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local entities_near_me = TheSim:FindEntities(
        ix, iy, iz, TUNING.ABIGAIL_COMBAT_TARGET_DISTANCE,
        COMBAT_MUSHAVE_TAGS, COMBAT_CANTHAVE_TAGS, COMBAT_MUSTONEOF_TAGS_AGGRESSIVE
    )

    for _, entity_near_me in ipairs(entities_near_me) do
        if CommonRetarget(inst, entity_near_me) then
            return entity_near_me
        end
    end

    return nil
end

local function StartForceField(inst)
	if not inst.sg:HasStateTag("dissipate") and not inst:HasDebuff("forcefield") and (inst.components.health == nil or not inst.components.health:IsDead()) then
		local elixir_buff = inst:GetDebuff("elixir_buff")
		inst:AddDebuff("forcefield", elixir_buff ~= nil and elixir_buff.potion_tunings.shield_prefab or "abigailforcefield")
	end
end

local function OnAttacked(inst, data)
    local combat = inst.components.combat
    if data.attacker == nil then
        combat:SetTarget(nil)
    elseif not data.attacker:HasTag("noauradamage") then
        -- If we're blocking targets and our target is still valid, don't switch away automatically.
        local is_blocking_retargets = inst.components.timer:TimerExists("block_retargets")
        if not is_blocking_retargets or not combat:IsValidTarget(combat.target) then
            if not inst.is_defensive then
                combat:SetTarget(data.attacker)
            elseif inst:IsWithinDefensiveRange() and inst._playerlink:GetDistanceSqToInst(data.attacker) < ABIGAIL_DEFENSIVE_MAX_FOLLOW_DSQ then
                -- Basically, we avoid targetting the attacker if they're far enough away that we wouldn't reach them anyway.
                combat:SetTarget(data.attacker)
            end
        end
    end

	if inst:HasDebuff("forcefield") then
		if data.attacker ~= nil and data.attacker ~= inst._playerlink and data.attacker.components.combat ~= nil then
			local elixir_buff = inst:GetDebuff("elixir_buff")
			if elixir_buff ~= nil and elixir_buff.prefab == "ghostlyelixir_retaliation_buff" then
				local retaliation = SpawnPrefab("abigail_retaliation")
				retaliation:SetRetaliationTarget(data.attacker)
			end

            inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/on")
		end
    end

    StartForceField(inst)
end

local function OnBlocked(inst, data)
    if data ~= nil and inst._playerlink ~= nil and data.attacker == inst._playerlink then
		if inst.components.health ~= nil and not inst.components.health:IsDead() then
			inst._playerlink.components.ghostlybond:Recall()
		end
	end
end

local function OnDeath(inst)
    inst.components.aura:Enable(false)
	inst:RemoveDebuff("ghostlyelixir")
	inst:RemoveDebuff("forcefield")
end

local function OnRemoved(inst)
    inst:BecomeDefensive()
end

local function auratest(inst, target, can_initiate)
    if target == inst._playerlink then
        return false
    end

	if target.components.minigame_participator ~= nil then
		return false
	end

    if (target:HasTag("player") and not TheNet:GetPVPEnabled()) or target:HasTag("ghost") or target:HasTag("noauradamage") then
        return false
    end

    local leader = inst.components.follower.leader
    if leader ~= nil
        and (leader == target
            or (target.components.follower ~= nil and
                target.components.follower.leader == leader)) then
        return false
    end

    if inst.is_defensive and not can_initiate and not IsWithinDefensiveRange(inst) then
        return false
    end

    if inst.components.combat.target == target then
        return true
    end

    if target.components.combat.target ~= nil
        and (target.components.combat.target == inst or
            target.components.combat.target == leader) then
        return true
    end

    local ismonster = target:HasTag("monster")
    if ismonster and not TheNet:GetPVPEnabled() and
       ((target.components.follower and target.components.follower.leader ~= nil and
         target.components.follower.leader:HasTag("player")) or target.bedazzled) then
        return false
    end

    return not target:HasTag("companion") and
        (can_initiate or ismonster or target:HasTag("prey"))
end

local function UpdateDamage(inst)
    local buff = inst:GetDebuff("elixir_buff")
    local murderbuff = inst:GetDebuff("abigail_murder_buff")
	local phase = (buff ~= nil and buff.prefab == "ghostlyelixir_attack_buff") and "night" or TheWorld.state.phase
    local modified_damage = (TUNING.ABIGAIL_DAMAGE[phase] or TUNING.ABIGAIL_DAMAGE.day)
	inst.components.combat.defaultdamage = modified_damage --/ (murderbuff and TUNING.ABIGAIL_SHADOW_VEX_DAMAGE_MOD or TUNING.ABIGAIL_VEX_DAMAGE_MOD) -- so abigail does her intended damage defined in tunings.lua --

    inst.attack_level = (phase == "day" and 1)
						or (phase == "dusk" and 2)
						or 3

   
    if murderbuff then
        inst.components.planardamage:AddBonus(inst, TUNING.ABIGAIL_SHADOW_PLANAR_DAMAGE, "shadow_murder_planar")
    else
        inst.components.planardamage:AddBonus(inst, 0, "shadow_murder_planar")
    end

    -- If the animation fx was already playing we update its animation
    local level_str = tostring(inst.attack_level)
    if inst.attack_fx and not inst.attack_fx.AnimState:IsCurrentAnimation("attack" .. level_str .. "_loop") then
        inst.attack_fx.AnimState:PlayAnimation("attack" .. level_str .. "_loop", true)
    end
end

local function CustomCombatDamage(inst, target)
    local vex_debuff = target:GetDebuff("abigail_vex_debuff")
    return (vex_debuff ~= nil and (vex_debuff.prefab == "abigail_vex_debuff" or vex_debuff.prefab == "abigail_vex_shadow_debuff" ) and 1/TUNING.ABIGAIL_VEX_DAMAGE_MOD)
        or 1
end

local function AbigailHealthDelta(inst, data)
    if not inst._playerlink then return end

    if data.oldpercent > data.newpercent and data.newpercent <= 0.25 and not inst.issued_health_warning then
        inst._playerlink.components.talker:Say(GetString(inst._playerlink, "ANNOUNCE_ABIGAIL_LOW_HEALTH"))
        inst.issued_health_warning = true
    elseif data.oldpercent < data.newpercent and data.newpercent > 0.33 then
        inst.issued_health_warning = false
    end
end

local function DoAppear(sg)
	sg:GoToState("appear")
end

local function AbleToAcceptTest(inst, item)
    return false, (item:HasTag("reviver") and "ABIGAILHEART") or nil
end

local function OnDebuffAdded(inst, name, debuff)
    if inst._playerlink ~= nil and inst._playerlink.components.pethealthbar ~= nil then
        if name == "super_elixir_buff" then
            inst._playerlink.components.pethealthbar:SetSymbol2(debuff.prefab)
        elseif name == "elixir_buff" then
            inst._playerlink.components.pethealthbar:SetSymbol(debuff.prefab)
        end
    end
end

local function OnDebuffRemoved(inst, name, debuff)
    if inst._playerlink ~= nil and inst._playerlink.components.pethealthbar ~= nil then
        if name == "super_elixir_buff" then
            inst._playerlink.components.pethealthbar:SetSymbol2(0)
        elseif name == "elixir_buff" then
            inst._playerlink.components.pethealthbar:SetSymbol(0)
        end
	end
end

local function on_ghostlybond_level_change(inst, player, data)
	if not inst.inlimbo and data.level > 1 and not inst.sg:HasStateTag("busy") and (inst.components.health == nil or not inst.components.health:IsDead()) then
		inst.sg:GoToState("ghostlybond_levelup", {level = data.level})
	end

	UpdateGhostlyBondLevel(inst, data.level)
end

local function BecomeAggressive(inst)
    inst.AnimState:OverrideSymbol("ghost_eyes", "ghost_abigail_build", "angry_ghost_eyes")
    inst.is_defensive = false
    inst._playerlink:AddTag("has_aggressive_follower")
    inst.components.combat:SetRetargetFunction(0.5, AggressiveRetarget)
end

local function BecomeDefensive(inst)
    inst.AnimState:ClearOverrideSymbol("ghost_eyes")
    inst.is_defensive = true
	if inst._playerlink ~= nil then
	    inst._playerlink:RemoveTag("has_aggressive_follower")
	end
    inst.components.combat:SetRetargetFunction(0.5, DefensiveRetarget)
end

local function onlostplayerlink(inst)
	inst._playerlink = nil
end

local function ApplyDebuff(inst, data)
	local target = data ~= nil and data.target
	if target ~= nil then
        local buff = "abigail_vex_debuff"

        if inst:GetDebuff("super_elixir_buff") and inst:GetDebuff("super_elixir_buff").prefab == "ghostlyelixir_shadow_buff" then
            buff = "abigail_vex_shadow_debuff"
        end

        local olddebuff = target:GetDebuff("abigail_vex_debuff")
        if olddebuff and olddebuff.prefab ~= buff then
            target:RemoveDebuff("abigail_vex_debuff")
        end

        target:AddDebuff("abigail_vex_debuff", buff, nil, nil, nil, inst)

        local debuff = target:GetDebuff("abigail_vex_debuff")

        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil and debuff ~= nil then
            debuff.AnimState:OverrideItemSkinSymbol("flower", skin_build, "flower", inst.GUID, "abigail_attack_fx" )
        end
	end
end

local function linktoplayer(inst, player)
    inst.persists = false
    inst._playerlink = player

    BecomeDefensive(inst)

    inst:ListenForEvent("healthdelta", AbigailHealthDelta)
    inst:ListenForEvent("onareaattackother", ApplyDebuff)

    player.components.leader:AddFollower(inst)
    if player.components.pethealthbar ~= nil then
        player.components.pethealthbar:SetPet(inst, "", TUNING.ABIGAIL_HEALTH_LEVEL1)

        local elixir_buff = inst:GetDebuff("elixir_buff")
        if elixir_buff then
            player.components.pethealthbar:SetSymbol(elixir_buff.prefab)
        end
        local elixir_buff2 = inst:GetDebuff("super_elixir_buff")
        if elixir_buff2 then
            player.components.pethealthbar:SetSymbol2(elixir_buff2.prefab)
        end
    end

    if player:HasTag("player_shadow_aligned") then
        inst:AddTag("shadow_aligned")
        local damagetyperesist = inst.components.damagetyperesist
        if damagetyperesist then
             damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SKILLS.WENDY.ALLEGIANCE_SHADOW_RESIST, "allegiance_shadow")
        end
        local damagetypebonus = inst.components.damagetypebonus
        if damagetypebonus then
            damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_LUNAR_BONUS, "allegiance_shadow")
        end
        inst.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
    end

    if player:HasTag("player_lunar_aligned") then        
        inst:AddTag("lunar_aligned")
        local damagetyperesist = inst.components.damagetyperesist
        if damagetyperesist then
             damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WENDY.ALLEGIANCE_LUNAR_RESIST, "allegiance_lunar")
        end
        local damagetypebonus = inst.components.damagetypebonus
        if damagetypebonus then
            damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WENDY.ALLEGIANCE_VS_SHADOW_BONUS, "allegiance_lunar")
        end
        inst.components.planardefense:SetBaseDefense(TUNING.SKILLS.WENDY.GHOST_PLANARDEFENSE)
    end

    UpdateGhostlyBondLevel(inst, player.components.ghostlybond.bondlevel)
    inst:ListenForEvent("ghostlybond_level_change", inst._on_ghostlybond_level_change, player)
    inst:ListenForEvent("onremove", inst._onlostplayerlink, player)
end

local function OnExitLimbo(inst)
	local level = (inst._playerlink ~= nil and inst._playerlink.components.ghostlybond ~= nil) and inst._playerlink.components.ghostlybond.bondlevel or 1
	local light_vals = TUNING.ABIGAIL_LIGHTING[level] or TUNING.ABIGAIL_LIGHTING[1]
	inst.Light:Enable(light_vals.r ~= 0)
end

-- Ghost Command helpers
local function DoGhostEscape(inst)
    if (inst.sg and inst.sg:HasStateTag("nocommand"))
            or (inst.components.health and inst.components.health:IsDead()) then
        return
    end

    inst.components.aura:Enable(false)

    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "transparency", 1.25)
    inst:AddTag("notarget")
    inst._is_transparent = true

    inst._undo_transparency_task = inst:DoTaskInTime(TUNING.WENDYSKILL_ESCAPE_TIME, UndoTransparency)
    inst.fade_toggle:set(true)
    -- Pushing a nil target should cause anybody targetting Abigail to drop her.
	inst:PushEvent("transfercombattarget", nil)
    inst.components.combat:SetTarget(nil)
	inst.sg:GoToState("escape")
end

local function apply_panic_fx(target, fx_prefab)
	local fx = SpawnPrefab(fx_prefab)
	if fx then
		fx.Transform:SetPosition(target.Transform:GetWorldPosition())
	end
	return fx
end

local SCARE_RADIUS = 10
local SCARE_MUST_HAVE_TAGS = {"_combat", "_health"}
local SCARE_CANT_HAVE_TAGS = { "balloon", "butterfly", "companion", "epic", "groundspike", "INLIMBO", "smashable", "structure", "wall"}
local function DoGhostScare(inst)
    if (inst.sg and inst.sg:HasStateTag("nocommand"))
            or (inst.components.health and inst.components.health:IsDead()) then
        return
    end

    local PVP_enabled = TheNet:GetPVPEnabled()
    local doer = inst._playerlink

	local x, y, z = inst.Transform:GetWorldPosition()
	local targets_near_me = TheSim:FindEntities(x, y, z, SCARE_RADIUS, SCARE_MUST_HAVE_TAGS, SCARE_CANT_HAVE_TAGS)
	for _, target in ipairs(targets_near_me) do
		if inst.components.combat:CanTarget(target)
				and not HasFriendlyLeader(doer, target, PVP_enabled)
				and (not target:HasTag("prey") or target:HasTag("hostile")) then

			if target.components.hauntable and target.components.hauntable.panicable then
                target.components.hauntable:Panic(7)
				target:DoTaskInTime(0.25 * math.random(), apply_panic_fx, "battlesong_instant_panic_fx")
			end
		end
	end
end

local ATTACK_MUST_TAGS = {"_health", "_combat"}
local ATTACK_NO_TAGS = {"DECOR", "FX", "INLIMBO", "NOCLICK"}
local function DoGhostAttackAt(inst, pos)
    if (inst.sg and inst.sg:HasStateTag("nocommand"))
            or (inst.components.health and inst.components.health:IsDead()) then
        return
    end

    local px, py, pz = pos:Get()
    local targets_near_position = TheSim:FindEntities(px, py, pz, 2, ATTACK_MUST_TAGS, ATTACK_NO_TAGS)
    if #targets_near_position > 0 then
        inst.components.combat:SetTarget(targets_near_position[1])

        local timer = inst.components.timer
        if timer:TimerExists("block_retargets") then
            timer:SetTimeLeft("block_retargets", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
        else
            timer:StartTimer("block_retargets", TUNING.WENDYSKILL_COMMAND_COOLDOWN)
        end
    else
        inst.components.combat:SetTarget(nil)
    end

    inst.components.aura:Enable(false)

    if inst:HasTag("gestalt") then
        inst.sg:GoToState("gestalt_attack", pos)

        if inst._playerlink ~= nil and inst._playerlink.components.spellbookcooldowns ~= nil then
            inst._playerlink.components.spellbookcooldowns:RestartSpellCooldown("do_ghost_attackat", TUNING.WENDYSKILL_GESTALT_ATTACKAT_COMMAND_COOLDOWN)
        end
    else
	    inst.sg:GoToState("abigail_attack_start", pos)
    end
end

local HAUNT_CANT_TAGS = {"catchable", "DECOR", "FX", "haunted", "INLIMBO", "NOCLICK"}
local function DoGhostHauntAt(inst, pos)
    if (inst.sg and inst.sg:HasStateTag("nocommand"))
            or (inst.components.health and inst.components.health:IsDead()) then
        return
    end

	local px, py, pz = pos:Get()
	local targets_near_position = TheSim:FindEntities(px, py, pz, 2, nil, HAUNT_CANT_TAGS)
	if #targets_near_position > 0 then
        inst._haunt_target = targets_near_position[1]
        inst:ListenForEvent("onremove", inst._OnHauntTargetRemoved, inst._haunt_target)
	end
end

local function OnDroppedTarget(inst, data)
    -- If we're blocking retargets but our target went away/died,
    -- allow ourselves to go back to target grabbing again.
    inst.components.timer:StopTimer("block_retargets")
end

--
local function getstatus(inst)
	local bondlevel = (inst._playerlink ~= nil and inst._playerlink.components.ghostlybond ~= nil) and inst._playerlink.components.ghostlybond.bondlevel or 0
	return bondlevel == 3 and "LEVEL3"
		or bondlevel == 2 and "LEVEL2"
		or "LEVEL1"
end

local function DoShadowBurstBuff(inst, stack)
    local x,y,z = inst.Transform:GetWorldPosition()
    SpawnPrefab("abigail_attack_shadow_fx").Transform:SetPosition(x,y,z)
    local fx = SpawnPrefab("abigail_shadow_buff_fx")
    inst:AddChild(fx)

    if not inst:HasDebuff("abigail_murder_buff") then
        inst:AddDebuff("abigail_murder_buff", "abigail_murder_buff")
        stack = stack-1
    end

    local murder_buff = inst:GetDebuff("abigail_murder_buff")
    local time = GetTaskRemaining(murder_buff.decaytimer)
    murder_buff:murder_buff_OnExtended(math.min( time + stack*TUNING.SKILLS.WENDY.MURDER_BUFF_DURATION,  20*TUNING.SKILLS.WENDY.MURDER_BUFF_DURATION )  )
end

local function calcabigailmaxhealthbonus(inst)
    local follower = inst.components.follower

    return (follower ~= nil and follower.leader ~= nil
        and follower.leader.components.skilltreeupdater ~= nil
        and follower.leader.components.skilltreeupdater:IsActivated("wendy_sisturn_4")
        and TUNING.SKILLS.WENDY.SISTURN_3_MAX_HEALTH_BOOST + TUNING.SKILLS.WENDY.SISTURN_3_MAX_HEALTH_BOOST
    ) or TUNING.SKILLS.WENDY.SISTURN_3_MAX_HEALTH_BOOST
end

local function UpdateBonusHealth(inst, newbonus)
    local max = nil
    local calculated_max_health_bonus = calcabigailmaxhealthbonus(inst)

    if inst.bonus_max_health == 0 and newbonus > 0 then
        max = calculated_max_health_bonus
    elseif inst.bonus_max_health > 0 and newbonus <= 0 then
        max = 0
    end

    inst.bonus_max_health = newbonus
    inst:PushEvent("pethealthbar_bonuschange", {
        max = max,
        oldpercent = inst.bonus_max_health/calculated_max_health_bonus,
        newpercent = newbonus/calculated_max_health_bonus,
    })
end

local function AddBonusHealth(inst,val)
    if inst.bonus_max_health < calcabigailmaxhealthbonus(inst) then
        local newmax = math.min(calcabigailmaxhealthbonus(inst), inst.bonus_max_health + val )
        inst:UpdateBonusHealth(newmax)
        local fx = SpawnPrefab("abigail_rising_twinkles_fx")
        inst:AddChild(fx)
    end
    SetMaxHealth(inst)
end

local function OnHealthChanged(inst, data)
    local oldbonus = inst.bonus_max_health

    -- Bonus should only go down through this process. Raising it is handled in AddBonusHealth
    if data.val > inst.base_max_health then
        inst.bonus_max_health = math.min(data.val - inst.base_max_health, oldbonus)
    else
        inst.bonus_max_health = 0
    end

    if inst.bonus_max_health ~= oldbonus then
        UpdateBonusHealth(inst, math.max(0, inst.bonus_max_health ))
    end

    inst.components.health.maxhealth = inst.base_max_health + inst.bonus_max_health
end

local function SetToGestalt(inst)
    inst:AddTag("gestalt")
    inst.components.aura:Enable(false)
    inst.AnimState:SetBuild( "ghost_abigail_gestalt_build" )

    inst.AnimState:OverrideSymbol("fx_puff2",       "lunarthrall_plant_front",      "fx_puff2")
    inst.AnimState:OverrideSymbol("v1_ball_loop",   "brightmare_gestalt_evolved",   "v1_ball_loop")
    inst.AnimState:OverrideSymbol("v1_embers",      "brightmare_gestalt_evolved",   "v1_embers")
    inst.AnimState:OverrideSymbol("v1_melt2",       "brightmare_gestalt_evolved",   "v1_melt2")

    inst.components.combat:SetAttackPeriod(3)
    inst.components.combat.attackrange = 6

    local buff = inst.components.debuffable:GetDebuff("super_elixir_buff")

    if buff ~= nil and buff.prefab == "ghostlyelixir_lunar_buff" then
        inst.components.planardamage:RemoveBonus(buff, "ghostlyelixir_lunarbonus")
        inst.components.planardamage:AddBonus(buff, TUNING.SKILLS.WENDY.LUNARELIXIR_DAMAGEBONUS_GESTALT, "ghostlyelixir_lunarbonus")
    end

end
local function SetToNormal(inst)
    inst:RemoveTag("gestalt")
    inst.components.aura:Enable(true)
    inst.AnimState:SetBuild( "ghost_abigail_build" )

    inst.AnimState:ClearOverrideSymbol("fx_puff2")
    inst.AnimState:ClearOverrideSymbol("v1_ball_loop")
    inst.AnimState:ClearOverrideSymbol("v1_embers")
    inst.AnimState:ClearOverrideSymbol("v1_melt2")

    inst.components.combat:SetAttackPeriod(4)
    inst.components.combat.attackrange = 3

    local buff = inst.components.debuffable:GetDebuff("super_elixir_buff")

    if buff ~= nil and buff.prefab == "ghostlyelixir_lunar_buff" then
        inst.components.planardamage:RemoveBonus(buff, "ghostlyelixir_lunarbonus")
        inst.components.planardamage:AddBonus(buff, TUNING.SKILLS.WENDY.LUNARELIXIR_DAMAGEBONUS, "ghostlyelixir_lunarbonus")
    end
end

local function OnSave(inst, data)
    data.bonus_max_health = inst.bonus_max_health
    data.gestalt = inst:HasTag("gestalt")
end

local function onload_bonushealth_task(inst, new_bonus_max_health)
    inst.bonus_max_health = 0
    inst:UpdateBonusHealth(new_bonus_max_health)
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.gestalt then
            SetToGestalt(inst)
        end

        if data.bonus_max_health then
            inst.bonus_max_health = data.bonus_max_health
            inst:DoTaskInTime(1, onload_bonushealth_task, data.bonus_max_health)
        end
    end
end

local function ChangeToGestalt(inst, togestalt)
    if togestalt then
        if not inst:HasTag("gestalt") then
            inst:PushEvent("gestalt_mutate",{gestalt=true})
        end
    else
        if inst:HasTag("gestalt") then
            inst:PushEvent("gestalt_mutate",{gestalt=false})
        end
    end
end
local function OnFadeToggleDirty(inst)
    inst.AnimState:UsePointFiltering(inst.fade_toggle:value())
    if inst.fade_toggle:value() then
        inst.components.fader:Fade(1.0, 0.3, 0.75, do_transparency)
    else
        inst.components.fader:Fade(1.0, 1.0, 1.0, do_transparency)
    end
end

local function updatehealingbuffs(inst)
    local buff = inst:GetDebuff("elixir_buff")
    if buff and buff.potion_tunings.ghostly_healing then

        local blossoms = TheWorld.components.sisturnregistry and 
                         TheWorld.components.sisturnregistry:IsBlossom() or nil
        local skilled = inst.components.follower and 
                        inst.components.follower.leader and 
                        inst.components.follower.leader.components.skilltreeupdater and 
                        inst.components.follower.leader.components.skilltreeupdater:IsActivated("wendy_sisturn_3") or nil

        local inworld = not inst:HasTag("INLIMBO") and (inst.sg and not inst.sg:HasStateTag("dissipate") ) or nil

        local setslow = nil
        local setnormal = nil


        if not buff.slowed and blossoms and skilled and inworld then
            setslow = true
        elseif buff.slowed and (not inworld or not blossoms or not skilled ) then
            setnormal = true
        end

        local time = buff.components.timer and buff.components.timer:GetTimeLeft("decay") or nil
        if time then
            if setslow == true then
                buff.components.timer:StopTimer("decay")
                buff.components.timer:StartTimer("decay", time*2)
                buff.slowed = true
            elseif setnormal then
                buff.components.timer:StopTimer("decay")
                buff.components.timer:StartTimer("decay", time/2)
                buff.slowed = nil
            end            
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("ghost")
    inst.AnimState:SetBuild("ghost_abigail_build")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim_bloom_ghost.ksh")

    inst.AnimState:AddOverrideBuild("ghost_abigail_gestalt")
    inst.AnimState:AddOverrideBuild("ghost_abigail_human")

    inst:AddTag("abigail")
    inst:AddTag("character")
    inst:AddTag("flying")
    inst:AddTag("ghost")
    inst:AddTag("girl")
    inst:AddTag("noauradamage")
    inst:AddTag("NOBLOCK")
    inst:AddTag("notraptrigger")
    inst:AddTag("scarytoprey")

    inst:AddTag("trader") --trader (from trader component) added to pristine state for optimization
	inst:AddTag("ghostlyelixirable") -- for ghostlyelixirable component

    MakeGhostPhysics(inst, 1, .5)

    inst.Light:SetIntensity(.6)
    inst.Light:SetRadius(.5)
    inst.Light:SetFalloff(.6)
    inst.Light:Enable(false)
    inst.Light:SetColour(180 / 255, 195 / 255, 225 / 255)

    --It's a loop that's always on, so we can start this in our pristine state
    -- inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_girl_howl_LP", "howl")



    inst.fade_toggle = net_bool(inst.GUID, "abigail.fade_toggle", "fade_toggledirty")
    inst.fade_toggle:set(false)

    if not TheNet:IsDedicated() then    
        inst:AddComponent("fader")    
        inst:ListenForEvent("fade_toggledirty", OnFadeToggleDirty)
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    --
    inst.scrapbook_damage = { TUNING.ABIGAIL_DAMAGE.day, TUNING.ABIGAIL_DAMAGE.night }
    inst.scrapbook_ignoreplayerdamagemod = true

    inst.is_defensive = true
    inst.issued_health_warning = false
    --inst._playerlink = nil

    --inst._haunt_target = nil
    inst._OnHauntTargetRemoved = function()
        if inst._haunt_target then
            inst:RemoveEventCallback("onremove", inst._OnHauntTargetRemoved, inst._haunt_target)
            inst._haunt_target = nil
        end
    end

    --
    inst.auratest = auratest
    inst.BecomeDefensive = BecomeDefensive
    inst.BecomeAggressive = BecomeAggressive
    inst.IsWithinDefensiveRange = IsWithinDefensiveRange
    inst.LinkToPlayer = linktoplayer
    inst.SetTransparentPhysics = SetTransparentPhysics
    inst.ApplyDebuff = ApplyDebuff

    --
    local aura = inst:AddComponent("aura")
    aura.radius = 4
    aura.tickperiod = 1
    aura.ignoreallies = true
    aura.auratestfn = auratest

    --
    local combat = inst:AddComponent("combat")
    combat.playerdamagepercent = TUNING.ABIGAIL_DMG_PLAYER_PERCENT
    combat:SetKeepTargetFunction(auratest)
    combat.customdamagemultfn = CustomCombatDamage

    --
    local debuffable = inst:AddComponent("debuffable")
    debuffable.ondebuffadded = OnDebuffAdded
    debuffable.ondebuffremoved = OnDebuffRemoved

    --
    local follower = inst:AddComponent("follower")
    follower:KeepLeaderOnAttacked()
    follower.keepdeadleader = true
    follower.keepleaderduringminigame = true

    --
    inst:AddComponent("ghostlyelixirable")

    --
    inst.base_max_health = TUNING.ABIGAIL_HEALTH_LEVEL1
    inst.bonus_max_health = 0

    local health = inst:AddComponent("health")
    health:SetMaxHealth(TUNING.ABIGAIL_HEALTH_LEVEL1)
    health:StartRegen(1, 1)
    health.nofadeout = true
    health.save_maxhealth = true

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable.getstatus = getstatus

    --
    local locomotor = inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    locomotor.walkspeed = TUNING.ABIGAIL_SPEED*.5
    locomotor.runspeed = TUNING.ABIGAIL_SPEED
    locomotor.pathcaps = { allowocean = true, ignorecreep = true }
    locomotor:SetTriggersCreep(false)

    --
    inst:AddComponent("planardamage")

    --
    inst:AddComponent("damagetyperesist")
    inst:AddComponent("damagetypebonus")

    --
    inst:AddComponent("planardefense")

    --
    inst:AddComponent("timer")

    -- Added so you can attempt to give hearts to trigger flavour text when the action fails
    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest)
    --
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("blocked", OnBlocked)
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("onremove", OnRemoved)
	inst:ListenForEvent("exitlimbo", OnExitLimbo)
    inst:ListenForEvent("do_ghost_escape", DoGhostEscape)
    inst:ListenForEvent("do_ghost_scare", DoGhostScare)
    inst:ListenForEvent("do_ghost_attackat", DoGhostAttackAt)
    inst:ListenForEvent("do_ghost_hauntat", DoGhostHauntAt)
    inst:ListenForEvent("pre_health_setval", OnHealthChanged)
    inst:ListenForEvent("droppedtarget", OnDroppedTarget)

    --
    inst:WatchWorldState("phase", UpdateDamage)
	UpdateDamage(inst, TheWorld.state.phase)
	inst.UpdateDamage = UpdateDamage
    inst.DoShadowBurstBuff = DoShadowBurstBuff
    inst.UpdateBonusHealth = UpdateBonusHealth
    inst.ChangeToGestalt = ChangeToGestalt
    inst.SetToGestalt = SetToGestalt
    inst.SetToNormal = SetToNormal
    inst.AddBonusHealth = AddBonusHealth
    inst.updatehealingbuffs = updatehealingbuffs

    --

    inst:SetBrain(brain)
    inst:SetStateGraph("SGabigail")
    inst.sg.OnStart = DoAppear

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    --
	inst._on_ghostlybond_level_change = function(player, data) on_ghostlybond_level_change(inst, player, data) end
	inst._onlostplayerlink = function(player) onlostplayerlink(inst, player) end

    --
    return inst
end

-------------------------------------------------------------------------------

local function SetRetaliationTarget(inst, target)
	inst._RetaliationTarget = target
	inst.entity:SetParent(target.entity)
	local s = (1 / target.Transform:GetScale()) * (target:HasTag("largecreature") and 1.1 or .8)
	if s ~= 1 and s ~= 0 then
		inst.Transform:SetScale(s, s, s)
	end

	inst.detachretaliationattack = function(t)
		if inst._RetaliationTarget ~= nil and inst._RetaliationTarget == t then
			inst.entity:SetParent(nil)
			inst.Transform:SetPosition(t.Transform:GetWorldPosition())
		end
	end

	inst:ListenForEvent("onremove", inst.detachretaliationattack, target)
	inst:ListenForEvent("death", inst.detachretaliationattack, target)
end

local function DoRetaliationDamage(inst)
	local target = inst._RetaliationTarget
	if target ~= nil and target:IsValid() and not target.inlimbo and target.components.combat ~= nil then
		target.components.combat:GetAttacked(inst, TUNING.GHOSTLYELIXIR_RETALIATION_DAMAGE)
		inst:detachretaliationattack(target)
        inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/shield/retaliation_fx")
	end
end

local function retaliationattack_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("abigail_shield")
    inst.AnimState:SetBuild("abigail_shield")
    inst.AnimState:PlayAnimation("retaliation_fx")
    inst.AnimState:SetBloomEffectHandle("shaders/anim_bloom_ghost.ksh")
    inst.AnimState:SetLightOverride(.1)
	inst.AnimState:SetFinalOffset(3)

    --It's a loop that's always on, so we can start this in our pristine state
    -- inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_girl_howl_LP", "howl")

	inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst._RetaliationTarget = nil
	inst.SetRetaliationTarget = SetRetaliationTarget
	inst:DoTaskInTime(12*FRAMES, DoRetaliationDamage)
	inst:DoTaskInTime(30*FRAMES, inst.Remove)

	return inst
end

-------------------------------------------------------------------------------
local function CreateDebuff(name)

    local function do_hit_fx(inst)
        local fx = SpawnPrefab("abigail_vex_hit")
        if name == "abigail_vex_shadow_debuff" then
            fx.AnimState:SetMultColour(0,0,0,1)
            --fx.AnimState:PlayAnimation("vex_lunar_hit_"..math.random(3))
        end
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end

    local function on_target_attacked(inst, target, data)
        if data ~= nil and data.attacker ~= nil and data.attacker:HasTag("ghostlyfriend") then
            inst.hitevent:push()
        end
    end

    local function buff_OnExtended(inst, target, followsymbol, followoffset, data, buffer)
        if inst.decaytimer ~= nil then
            inst.decaytimer:Cancel()
        end            
        local duration = TUNING.ABIGAIL_VEX_DURATION
        if buffer and buffer:HasTag("gestalt") then
            duration = TUNING.ABIGAIL_VEX_DURATION * TUNING.SKILLS.WENDY.ABIGAIL_GESTALT_VEX_DURATION_MULT
        end

        inst.decaytimer = inst:DoTaskInTime(duration, function() inst.components.debuff:Stop() end)
    end

    local function addshadowvexplanardamge(inst, owner, data)
        if data == nil or data.redirected then
            return
        end

        if data.attacker ~= nil and data.attacker:HasTag("attacktriggereddebuff") then
            return -- Don't trigger from another attacktriggereddebuff entity.
        end

        if data.attacker == inst or data.attacker:HasTag("abigail") then
            return -- Don't trigger itself!
        end

        local attacker_spdmg = data.attacker ~= nil and SpDamageUtil.CollectSpDamage(data.attacker) or 0
        local weapon_spdmg   = data.weapon ~= nil   and SpDamageUtil.CollectSpDamage(data.weapon)   or 0

        if owner ~= nil and owner:IsValid() and
            not (owner.components.health and owner.components.health:IsDead()) and
            (owner.components.combat and owner.components.combat:CanBeAttacked())
        then
            local spdmg = SpDamageUtil.CollectSpDamage(inst)

            owner.components.combat:GetAttacked(inst, 0, nil, nil, spdmg)
        end
    end

    local function buff_OnAttached(inst, target, followsymbol, followoffset, data, buffer)
        if target ~= nil and target:IsValid() and not target.inlimbo and target.components.combat ~= nil and target.components.health ~= nil and not target.components.health:IsDead() then
           
            if name == "abigail_vex_shadow_debuff" then
                inst:AddComponent("planardamage")
                inst.components.planardamage:SetBaseDamage(TUNING.ABIGAIL_SHADOW_VEX_PLANAR_DAMAGE)
                inst._onattackedfn =function(owner, data)  addshadowvexplanardamge(inst, owner, data) end 
                inst._owner = target

                inst:AddTag("attacktriggereddebuff")

                inst:AddComponent("damagetypebonus")
                inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SLINGSHOT_AMMO_VS_SHADOW_BONUS)

                inst:ListenForEvent("attacked", inst._onattackedfn, target)
            end

            target.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.ABIGAIL_VEX_DAMAGE_MOD)

            inst.entity:SetParent(target.entity)
            inst.Transform:SetPosition(0, 0, 0)
            local s = (1 / target.Transform:GetScale()) * (target:HasTag("largecreature") and 1.6 or 1.2)
            if s ~= 1 and s ~= 0 then
                inst.Transform:SetScale(s, s, s)
            end

            inst:ListenForEvent("attacked", inst._on_target_attacked, target)
        end

        buff_OnExtended(inst, target, nil, nil, nil, buffer)

        inst:ListenForEvent("death", function() inst.components.debuff:Stop() end, target)
    end

    local function buff_OnDetached(inst, target)
        if inst.decaytimer ~= nil then
            inst.decaytimer:Cancel()
            inst.decaytimer = nil

            if target ~= nil and target:IsValid() and target.components.combat ~= nil then
                target.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst)
            end

            inst:RemoveTag("attacktriggereddebuff")

            if inst._owner ~= nil and inst._owner:IsValid() then
                inst:RemoveEventCallback("attacked", inst._onattackedfn, inst._owner)
            end

            inst.AnimState:PushAnimation("vex_debuff_pst", false)
            inst:ListenForEvent("animqueueover", inst.Remove)
        end
    end

    local function abigail_vex_debuff_fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst.AnimState:SetBank("abigail_debuff_fx")
        inst.AnimState:SetBuild("abigail_debuff_fx")

        inst.AnimState:PlayAnimation("vex_debuff_pre")
        inst.AnimState:PushAnimation("vex_debuff_loop", true)
        inst.AnimState:SetFinalOffset(3)

        inst:AddTag("FX")

        inst.hitevent = net_event(inst.GUID, "abigail_vex_debuff.hitevent")

        if not TheNet:IsDedicated() then
            inst:ListenForEvent("abigail_vex_debuff.hitevent", do_hit_fx)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        inst._on_target_attacked = function(target, data) on_target_attacked(inst, target, data) end

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(buff_OnAttached)
        inst.components.debuff:SetDetachedFn(buff_OnDetached)
        inst.components.debuff:SetExtendedFn(buff_OnExtended)
        inst.buff_OnExtended = buff_OnExtended

        return inst
    end

    return Prefab(name, abigail_vex_debuff_fn, {Asset("ANIM", "anim/abigail_debuff_fx.zip")}, {"abigail_vex_hit"} )
end


-------------------------------------------------------------------------------

local function abigail_vex_hit_fn()
    local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()

	inst.AnimState:SetBank("abigail_debuff_fx")
	inst.AnimState:SetBuild("abigail_debuff_fx")

	inst.AnimState:PlayAnimation("vex_hit")
	inst.AnimState:SetFinalOffset(3)

	inst:AddTag("FX")

    inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)

	return inst
end

--------------------------------------------------------------------------------

local function murder_buff_OnExtended(inst, duration)
    if inst.decaytimer ~= nil then
        inst.decaytimer:Cancel()
    end
    inst.decaytimer = inst:DoTaskInTime(duration or TUNING.SKILLS.WENDY.MURDER_BUFF_DURATION , function() inst.components.debuff:Stop() end)
end

local function murder_buff_OnAttached(inst, target)
    murder_buff_OnExtended(inst)
    if target and target:IsValid() then

        UpdateDamage(target)

        target.AnimState:SetBuild( "ghost_abigail_shadow_build" )

        if target.components.aura and target.components.aura.applying then
            target:PushEvent("stopaura")
            target:PushEvent("startaura")
        end

        local fx = SpawnPrefab("shadow_puff_large_front")
        fx.Transform:SetScale(1.2,1.2,1.2)
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())

        target.components.planardefense:AddBonus(inst, TUNING.SKILLS.WENDY.MURDER_DEFENSE_BUFF, "wendymurderbuff")

        inst:ListenForEvent("death", function() inst.components.debuff:Stop() end, target)
    end
end

local function murder_buff_OnDetached(inst, target)
    if inst.decaytimer then
        inst.decaytimer:Cancel()
        inst.decaytimer = nil

        if target and target:IsValid() then

            UpdateDamage(target)

            target.AnimState:SetBuild( "ghost_abigail_build" )

            if target.components.aura and target.components.aura.applying then
                target:PushEvent("stopaura")
                target:PushEvent("startaura")
            end

            local fx = SpawnPrefab("shadow_puff_large_front")
            fx.Transform:SetScale(1.2,1.2,1.2)
            fx.Transform:SetPosition(target.Transform:GetWorldPosition())

            target.components.planardefense:RemoveBonus(inst, "wendymurderbuff")
        end
    end
end

local function abigail_murder_buff_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(murder_buff_OnAttached)
    inst.components.debuff:SetDetachedFn(murder_buff_OnDetached)
    inst.components.debuff:SetExtendedFn(murder_buff_OnExtended)

    inst.murder_buff_OnExtended = murder_buff_OnExtended

    return inst
end

return Prefab("abigail", fn, assets, prefabs),
	   Prefab("abigail_retaliation", retaliationattack_fn, {Asset("ANIM", "anim/abigail_shield.zip")} ),
       CreateDebuff("abigail_vex_debuff"),
       CreateDebuff("abigail_vex_shadow_debuff"),
	   Prefab("abigail_vex_hit", abigail_vex_hit_fn, {Asset("ANIM", "anim/abigail_debuff_fx.zip")} ),
       Prefab("abigail_murder_buff", abigail_murder_buff_fn)
