local PlayerCommonExtensions = require("prefabs/player_common_extensions")
local WX78Common = require("prefabs/wx78_common")

local assets = JoinArrays({
    Asset("SCRIPT", "scripts/prefabs/wx78_common.lua"),
    Asset("ANIM", "anim/wx_chassis.zip"),
	Asset("ANIM", "anim/wx78_map_marker.zip"),
	Asset("ANIM", "anim/wx78_lunar_affinity_fx.zip"),
	Asset("ANIM", "anim/brightmare_gestalt_head_evolved.zip"),
	Asset("ANIM", "anim/lunarthrall_plant_front.zip"),
}, WX78Common.DEPENDENCIES.assets)

local prefabs = JoinArrays({
    "explode_reskin",
    "collapse_small",
	"globalmapiconunderfog",
}, WX78Common.DEPENDENCIES.prefabs)

local brain = require("brains/wx78_possessedbodybrain")

local function SpawnBigSpark(inst)
    SpawnPrefab("wx78_big_spark"):AlignToTarget(inst)
end

local function DisplayNameFn(inst)
    local ownername = inst.components.linkeditem:GetOwnerName()
    return ownername and subfmt(STRINGS.NAMES.WX78_POSSESSEDBODY_FMT, { name = ownername }) or nil
end

local function CheckCircuitSlotStatesFrom(inst, owner)
    inst._maxcharge = owner ~= nil and owner.components.upgrademoduleowner ~= nil and owner.components.upgrademoduleowner:GetMaxChargeLevel()
        or TUNING.WX78_INITIAL_MAXCHARGELEVEL
    inst.components.upgrademoduleowner:SetMaxCharge(inst._maxcharge)
    inst.components.upgrademoduleowner:SetChargeLevel(inst._maxcharge) -- We're a gestalt, always full charge.
end

local function CheckZapUserStatesFrom(inst, owner)
    if owner ~= nil and owner.components.skilltreeupdater ~= nil and owner.components.skilltreeupdater:IsActivated("wx78_zapdrone_1") then
        inst:AddTag("drone_zap_user")
    else
        inst:RemoveTag("drone_zap_user")
    end
end

local function TryToAttachToOwner(inst, owner)
    if owner == nil or owner.is_snapshot_user_session then
        return false
    end
    local linkeditem = inst.components.linkeditem
    if linkeditem == nil or linkeditem:GetOwnerUserID() ~= nil then
        return false
    end

    local isbuildbuffered = owner.components.builder and owner.components.builder:IsBuildBuffered("wx78_backupbody")
    local numfreeneeded = isbuildbuffered and 1 or 0

    if owner.wx78_classified and (owner.wx78_classified:GetNumFreeBackupBodies() > numfreeneeded) then
        linkeditem:LinkToOwnerUserID(owner.userid)
        if owner.isplayer then
            if not inst._hide_body_skinfx then
                local x, y, z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("explode_reskin")
                fx.Transform:SetPosition(x, y, z)
            else
                inst._hide_body_skinfx = nil
            end
        else
            inst.components.skinner:SetupNonPlayerData()
        end
        inst:CheckCircuitSlotStatesFrom(owner)
        inst:CheckZapUserStatesFrom(owner)
        return true
    end

    return false
end

local function TryToAttachToLeader(inst)
    local leader = inst.components.follower:GetLeader()
    if inst.ms_skilltree_initializecb ~= nil then
        inst:RemoveEventCallback("ms_skilltreeinitialized", inst.ms_skilltree_initializecb, leader)
        inst.ms_skilltree_initializecb = nil
    end
    if not inst:TryToAttachToOwner(leader) then
        inst.components.health:Kill() -- Kill ourselves if we couldn't attach?
    end
end

local function OnLeaderEmote(inst, data)
    inst._brain_emotedata = nil
    if data ~= nil and data.loop then
        inst._brain_emotedata = data
        inst.sg:RemoveStateTag("emoting")
        if inst.brain then
            inst.brain:ForceUpdate()
        end
    else
        inst:PushEvent("emote", data)
    end
end

local function OnChangedLeader(inst, new_leader, prev_leader)
    local linkeditem = inst.components.linkeditem
    if linkeditem and new_leader ~= nil then
        linkeditem:LinkToOwnerUserID(nil)
    end
    if inst.ms_emotecb ~= nil then
        inst:RemoveEventCallback("emote", inst.ms_emotecb, prev_leader)
        inst.ms_emotecb = nil
    end
    if inst.ms_skilltree_initializecb ~= nil then
        inst:RemoveEventCallback("ms_skilltreeinitialized", inst.ms_skilltree_initializecb, prev_leader)
        inst.ms_skilltree_initializecb = nil
    end

    if new_leader ~= nil then
        inst.ms_emotecb = function(_, data) OnLeaderEmote(inst, data) end
        inst:ListenForEvent("emote", inst.ms_emotecb, new_leader)
        if new_leader._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
            TryToAttachToLeader(inst)
        else
            inst.ms_skilltree_initializecb = function() TryToAttachToLeader(inst) end
            inst:ListenForEvent("ms_skilltreeinitialized", inst.ms_skilltree_initializecb, new_leader)
        end
    else
        -- Our previous leader died, so we should die too.
        if prev_leader.components.health ~= nil and prev_leader.components.health:IsDead() then
            inst.components.health:Kill()
        else
            inst:PushEventImmediate("become_dormant")
        end
    end
end

local function AttachClassified_wx78(inst, classified)
    inst.wx78_classified = classified
    inst.ondetach_wx78_classified = function() inst:DetachClassified_wx78() end
    inst:ListenForEvent("onremove", inst.ondetach_wx78_classified, classified)
end

local function DetachClassified_wx78(inst)
    inst.wx78_classified = nil
    inst.ondetach_wx78_classified = nil
end

local function OnSkillTreeInitializedFn(inst, owner)
    if owner.wx78_classified == nil or not owner.wx78_classified:TryToAddBackupBody(inst) then
        if not table.contains(SEAMLESSSWAP_CHARACTERLIST, owner.prefab) then
            local linkeditem = inst.components.linkeditem
            if linkeditem then
                linkeditem:LinkToOwnerUserID(nil)
            end
        end
    else
        inst:CheckCircuitSlotStatesFrom(owner)
        inst:CheckZapUserStatesFrom(owner)
    end
end
local function OnOwnerInstCreatedFn(inst, owner)
	-- inst.components.globaltrackingicon:StartTracking(owner)
end
local function OnOwnerInstRemovedFn(inst, owner)
    if owner.wx78_classified then
        owner.wx78_classified:TryToRemoveBackupBody(inst)
    end
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        if data.attacker.components.leader ~= nil and
            data.attacker.components.leader:IsFollower(inst) then
            inst:DoSanityDeath()
        end
    end
end

local function OnDeath(inst, data)
    WX78Common.DropEatenGears(inst)
end

local function TryToReplaceWithBackupBody(inst, gestaltalive) -- This always removes the possessed body.
    local x, y, z = inst.Transform:GetWorldPosition()
    local body = SpawnPrefab("wx78_backupbody")
    body._hide_body_skinfx = true
    local stats = body:GetDoerSavedStats(inst) -- Save stats here before messing with upgrademoduleowner, otherwise we get incorrect stats
    body.components.upgrademoduleowner:SetChargeLevel(0)
    if inst.components.upgrademoduleowner then
        inst.components.upgrademoduleowner:SetChargeLevel(0)
    end
    body.Transform:SetPosition(x, y, z)
    local owner = inst.components.linkeditem:GetOwnerInst()
    if owner ~= nil then
        if owner.wx78_classified then
            owner.wx78_classified:TryToRemoveBackupBody(inst)
        end
        body:TryToAttachToOwner(owner)
    else
        body.components.linkeditem:LinkToOwnerUserID(inst.components.linkeditem:GetOwnerUserID())
    end
    if not body.components.activatable:DoActivate(inst) then
        body:Remove()
        return false
    end
    if gestaltalive then
        body:ConfigurePossessed(true, inst:GetIsPlanar())
    end
    body:ConfigureStats(stats)
    inst.wx78_backupbody_save_inst = body
    -- body._Light_value = body.Light:IsEnabled() -- HACK flag for default behaviour with Remove and Return to Scene modifying light states.
    -- body:RemoveFromScene()
    inst:Remove()
    return true
end

local function SetIsPlanar(inst, planar)
	if inst:GetIsPlanar() == not planar then
		if planar then
			if inst.components.planarentity == nil then
				inst:AddComponent("planarentity")
			end
			inst.components.sanity.neg_aura_modifiers:SetModifier(inst, TUNING.SKILLS.WX78.PLANARPOSSESSEDBODY_NEGATIVE_SANITY_AURA_MODIFIER, "gestalt_possessedbody")
		else
			inst:RemoveComponent("planarentity")
			inst.components.sanity.neg_aura_modifiers:SetModifier(inst, TUNING.SKILLS.WX78.POSSESSEDBODY_NEGATIVE_SANITY_AURA_MODIFIER, "gestalt_possessedbody")
		end
		inst:SetGestaltFxPlanar(planar)
	end
end

--[[local function GetIsPlanar(inst)
	return inst:IsGestaltFxPlanar()
end]]

----------------------------------------------------------------------------------------

local function WeaponPercentChanged(inst, data)
    if data.percent ~= nil and
        data.percent <= 0 and
        inst.components.rechargeable == nil and
        inst.components.inventoryitem ~= nil and
        inst.components.inventoryitem.owner ~= nil then
        inst.components.inventoryitem.owner:PushEvent("toolbroke", { tool = inst })
    end
end

local function OnEquip(inst, data)
    if data ~= nil and data.item ~= nil then
        data.item:ListenForEvent("percentusedchange", WeaponPercentChanged)
    end
end

local function OnUnequip(inst, data)
    if data ~= nil and data.item ~= nil then
        data.item:RemoveEventCallback("percentusedchange", WeaponPercentChanged)
    end
end

local function OnLeaderFailedFurl(inst)
    local leader = inst.components.follower and inst.components.follower:GetLeader()
    if leader ~= nil then
        if inst.sg.mem.furl_target == leader.sg.mem.furl_target then
            inst:PushBufferedAction(BufferedAction(inst, inst.sg.mem.furl_target, ACTIONS.LOWER_SAIL_FAIL))
        end
    end
end

local function OnLeaderFailedRow(inst)
    local leader = inst.components.follower and inst.components.follower:GetLeader()
    if leader ~= nil then
        local tool = inst.components.inventory ~= nil and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        if tool ~= nil and tool.components.oar ~= nil and inst:HasTag("is_rowing") then
            inst:PushBufferedAction(BufferedAction(inst, nil, ACTIONS.ROW_FAIL, tool))
        end
    end
end

-- We equip stuff from EQUIPONBODY action, not here.
local function ShouldAcceptItem(inst, item, giver, count)
    return item.components.inventoryitem ~= nil
end

local function OnGetItem(inst, giver, item, count)
    -- Nothing to do here!
end

local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
    if mount == nil then
        if weapon ~= nil and weapon:HasTag("shadow_item") then
			return TUNING.SKILLS.WX78.POSSESSEDBODY_PLANAR_SHADOW_DAMAGE_MULT
        end
    end

    return inst:GetIsPlanar() and TUNING.SKILLS.WX78.PLANARPOSSESSEDBODY_DAMAGE_MULT
        or TUNING.SKILLS.WX78.POSSESSEDBODY_DAMAGE_MULT
end

local function CustomSPCombatDamage(inst, target, weapon, multiplier, mount)
    local isplanar = inst:GetIsPlanar()
    if mount == nil then
        if weapon ~= nil and weapon:HasTag("shadow_item") then
			return isplanar and TUNING.SKILLS.WX78.PLANARPOSSESSEDBODY_PLANAR_SHADOW_DAMAGE_MULT
                or TUNING.SKILLS.WX78.PLANARPOSSESSEDBODY_PLANAR_SHADOW_DAMAGE_MULT
        end
    end

    return isplanar and TUNING.SKILLS.WX78.PLANARPOSSESSEDBODY_PLANAR_DAMAGE_MULT
        or TUNING.SKILLS.WX78.POSSESSEDBODY_PLANAR_DAMAGE_MULT
end

local function OnSanityDelta(inst, data)
    -- #HACK _ignore_sanity_death is a hack flag to give us time to apply upgrade modules before we apply fresh spawn stats, otherwise
    -- sanity delta runs and we die on a 0 sanity chassis
    if data.newpercent == 0 and not inst.components.health:IsDead() and not inst._ignore_sanity_death then
        inst:DoSanityDeath()
    end
end

local function DoSanityDeath(inst)
    inst._saved_health_on_sanity_death = inst.components.health.currenthealth
    inst.components.health:Kill()
end

local function ArmorBroke(inst, data)
    if data.armor ~= nil then
        -- Prioritize the same type of armor
        -- and then just choose the next available armor.
        local nextArmor = inst.components.inventory:FindItem(function(item) return item.prefab == data.armor.prefab and item.components.equippable ~= nil end) 
            or inst.components.inventory:FindItem(function(item) return item.components.equippable ~= nil and item.components.armor ~= nil end)
        if nextArmor ~= nil then
			local force_ui_anim = data.armor.components.armor.keeponfinished
			inst.components.inventory:Equip(nextArmor, nil, nil, force_ui_anim)
        end
    end
end

----------------------------------------------------------------------------------------

-- TODO can we pop and unpop modules?

local function OnUpgradeModuleAdded(inst, moduleent)
    local moduletype = moduleent.components.upgrademodule:GetType()

    -- inst:PushEvent("upgrademodulesdirty", inst:GetModulesData())
    if inst.wx78_classified ~= nil then
        local newmodule_index = inst.components.upgrademoduleowner:GetNumModules(moduletype)
        inst.wx78_classified.upgrademodulebars[moduletype][newmodule_index]:set(moduleent._netid or 0)
    end
end

local function OnUpgradeModuleRemoved(inst, moduleent)
    -- TODO?
end

local function OnOneUpgradeModulePopped(inst, moduleent, was_activated)
    -- If the module we just popped was charged, use that charge
    -- as the cost of this removal.
    local moduletype = moduleent.components.upgrademodule:GetType()
    local moduleslotcount = moduleent.components.upgrademodule:GetSlots()
    if was_activated then
        local charge_cost = -moduleslotcount
        local owner = inst.components.linkeditem:GetOwnerInst()
        local skilltreeupdater = owner ~= nil and owner.components.skilltreeupdater or nil
        if skilltreeupdater and skilltreeupdater:IsActivated("wx78_circuitry_bettercharge") then
            charge_cost = math.min(charge_cost + 1, -1)
        end
        inst.components.upgrademoduleowner:DoDeltaCharge(charge_cost)
    end

    -- inst:PushEvent("upgrademodulesdirty", inst:GetModulesData())
    if inst.wx78_classified ~= nil then
        -- This is a callback of the remove, so our current NumModules should be
        -- 1 lower than the index of the module that was just removed.
        local top_module_index = inst.components.upgrademoduleowner:GetNumModules(moduletype) + 1
        inst.wx78_classified.upgrademodulebars[moduletype][top_module_index]:set(0)
    end
end

local function OnAllUpgradeModulesRemoved(inst)
    if inst.components.workable == nil or inst.components.workable:GetWorkLeft() > 0 then
        SpawnBigSpark(inst)
    end

    inst:PushEvent("upgrademoduleowner_popallmodules")

    if inst.wx78_classified ~= nil then
        for i, modules in pairs(inst.wx78_classified.upgrademodulebars) do
            for j, netvar in ipairs(modules) do
                netvar:set(0)
            end
        end
    end
end

----------------------------------------------------------------------------------------

local function CanTransformToContainer(inst, doer)
    if doer ~= nil then
        if not doer.wx78_classified then
            return false, "NOTAROBOT"
        end
        local linkeditem = inst.components.linkeditem
        if not linkeditem then
            return false, "NOTMYBACKUP"
        end
        local owneruserid = linkeditem:GetOwnerUserID()
        if owneruserid and owneruserid ~= doer.userid then
            return false, "NOTMYBACKUP"
        end
    end

    return not inst.sg:HasStateTag("busy")
end

local function TransformToContainer(inst)
    inst:TryToReplaceWithBackupBody(true)
    if inst.wx78_backupbody_save_inst ~= nil then
        inst.wx78_backupbody_save_inst.wx78_backupbody_inventory.AnimState:PlayAnimation("wx_chassis_poweroff")
        inst.wx78_backupbody_save_inst.wx78_backupbody_inventory.AnimState:PushAnimation("wx_chassis_idle", true)
        inst.wx78_backupbody_save_inst:SetPossessedContainerState()
        return inst.wx78_backupbody_save_inst
    end

    return nil
end

----------------------------------------------------------------------------------------

local function RedirectToWxShield(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
	return inst.components.wx78_shield ~= nil and inst.components.wx78_shield:OnTakeDamage(amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
end

----------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.maxcharge = inst._maxcharge or nil
	data.isplanar = inst:GetIsPlanar() or nil
    data.gears_eaten = inst._gears_eaten

    -- WX-78 needs to manually save/load health, hunger, and sanity, in case their maxes
    -- were modified by upgrade circuits, because those components only save current,
    -- and that gets overridden by the default max values during construction.
    -- So, if we wait to re-apply them in our OnLoad, we will have them properly
    -- (as entity OnLoad runs after component OnLoads)
    data._wx78_health = inst.components.health.currenthealth
    data._wx78_sanity = inst.components.sanity.current
    data._wx78_hunger = inst.components.hunger.current
    data._wx78_shield = inst.components.wx78_shield.currentshield
    data._saved_health_on_sanity_death = inst._saved_health_on_sanity_death
end

local function OnLoad(inst, data, newents)
    if data then
        if data.maxcharge ~= nil then
            inst.components.upgrademoduleowner:SetMaxCharge(data.maxcharge)
        end

		if data.isplanar then
            inst:SetIsPlanar(true)
        end

        if data.gears_eaten ~= nil then
            inst._gears_eaten = data.gears_eaten
        end
        -- WX-78 needs to manually save/load health, hunger, and sanity, in case their maxes
        -- were modified by upgrade circuits, because those components only save current,
        -- and that gets overridden by the default max values during construction.
        -- So, if we wait to re-apply them in our OnLoad, we will have them properly
        -- (as entity OnLoad runs after component OnLoads)
        if data._wx78_health then
            inst.components.health:SetCurrentHealth(data._wx78_health)
        end

        if data._wx78_sanity then
            inst.components.sanity.current = data._wx78_sanity
        end

        if data._wx78_hunger then
            inst.components.hunger.current = data._wx78_hunger
        end

        if data._wx78_shield then
            inst.components.wx78_shield.currentshield = data._wx78_shield
        end

        if data._saved_health_on_sanity_death then
            inst._saved_health_on_sanity_death = data._saved_health_on_sanity_death
        end
    end
end

local function OnLoadPostPass(inst, owner)
    inst:TryToReplaceWithBackupBody(true)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddDynamicShadow()
	inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("wx78_possessedbody.png")
	inst.MiniMapEntity:SetCanUseCache(false)

    inst.Transform:SetFourFaced()
    inst.DynamicShadow:SetSize(1.3, .6)

    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wx78")
    inst.AnimState:AddOverrideBuild("wx_chassis")
    inst.AnimState:PlayAnimation("wx_chassis_idle")
    PlayerCommonExtensions.SetupBaseSymbolVisibility(inst)
    PlayerCommonExtensions.SetupOverrideSymbols(inst)
    PlayerCommonExtensions.SetupOverrideBuilds(inst)
    inst.AnimState:AddOverrideBuild("player_wx78_actions")
	inst.AnimState:SetSymbolBloom("fx_puff2_parts")
	inst.AnimState:SetSymbolBloom("gestalts_parts")
	inst.AnimState:SetSymbolLightOverride("fx_puff2_parts", 0.1)
	inst.AnimState:SetSymbolLightOverride("gestalts_parts", 0.1)

    --Default to electrocute light values
    inst.Light:SetIntensity(.8)
    inst.Light:SetRadius(.5)
    inst.Light:SetFalloff(.65)
    inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
    inst.Light:Enable(false)

    MakeCharacterPhysics(inst, 75, .5)

    WX78Common.SetupUpgradeModuleOwnerInstanceFunctions(inst)

    inst:AddTag("NOBLOCK")
    inst:AddTag("scarytoprey")
    inst:AddTag("character")
    inst:AddTag("possessedbody")
    inst:AddTag("player_damagescale")
    inst:AddTag("gestalt")
    --upgrademoduleowner (from upgrademoduleowner component) added to pristine state for optimization
    inst:AddTag("upgrademoduleowner")
    inst:AddTag("wx78_shield")          -- from wx78_shield component
    inst:AddTag("trader")
    inst:AddTag("alltrader")
    inst:AddTag("canseeindark")
    inst:AddTag("lunar_aligned")
    inst:AddTag("electricdamageimmune")
    --electricdamageimmune is for combat and not lightning strikes
    inst:AddTag("devourable")

	inst.footstepoverridefn = PlayerCommonExtensions.FootstepOverrideFn
	inst.foleyoverridefn = PlayerCommonExtensions.FoleyOverrideFn

    local linkeditem = inst:AddComponent("linkeditem")
    inst.displaynamefn = DisplayNameFn

    inst.AttachClassified_wx78 = AttachClassified_wx78
    inst.DetachClassified_wx78 = DetachClassified_wx78

	WX78Common.AddGestaltFx_Common(inst, false, true)
	WX78Common.AddHeatSteamFx_Common(inst)
	WX78Common.AddDizzyFx_Common(inst)
	WX78Common.Initialize_Common(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.wx78_classified = SpawnPrefab("wx78_classified")
    inst.wx78_classified.entity:SetParent(inst.entity)
    inst.wx78_classified.Network:SetClassifiedTarget(inst)

    inst:AddComponent("inspectable")

	inst:AddComponent("maprevealable")
	inst.components.maprevealable:SetIconPrefab("globalmapiconunderfog")

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = TUNING.WILSON_RUN_SPEED

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    PlayerCommonExtensions.ConfigurePlayerLocomotor(inst)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.WX78_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.WX78_HUNGER)
    inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE)
    inst.components.hunger:SetKillRate(TUNING.WILSON_HEALTH / TUNING.STARVE_KILL_TIME)

    inst:AddComponent("sanity")
    inst.components.sanity:SetMax(TUNING.WX78_SANITY)
    inst.components.sanity.neg_aura_modifiers:SetModifier(inst, TUNING.SKILLS.WX78.POSSESSEDBODY_NEGATIVE_SANITY_AURA_MODIFIER, "gestalt_possessedbody")

    inst:AddComponent("eater")
    inst.components.eater:SetIgnoresSpoilage(true)
    inst.components.eater:SetCanEatGears()
    inst.components.eater:SetOnEatFn(WX78Common.OnEat)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.UNARMED_DAMAGE)
    inst.components.combat.hiteffectsymbol = "torso"
    inst.components.combat.pvp_damagemod = TUNING.PVP_DAMAGE_MOD -- players shouldn't hurt other players very much
    inst.components.combat:SetAttackPeriod(TUNING.WILSON_ATTACK_PERIOD)
    inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
    inst.components.combat.customdamagemultfn = CustomCombatDamage
    inst.components.combat.customspdamagemultfn = CustomSPCombatDamage

    inst:AddComponent("leader") -- For one-man band
    inst:AddComponent("drownable")

    inst:AddComponent("follower")
    inst.components.follower:KeepLeaderOnAttacked()
    inst.components.follower.OnChangedLeader = OnChangedLeader

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(ShouldAcceptItem)
    inst.components.trader.onaccept = OnGetItem
    inst.components.trader.acceptnontradable = true
    inst.components.trader.deleteitemonaccept = false
    inst.components.trader.acceptsmimics = true

    inst:AddComponent("wx78_shield")
    inst.components.wx78_shield:SetMax(1)
    inst.components.wx78_shield:SetCurrent(0)
    inst.components.health.deltamodifierfn = RedirectToWxShield

    inst:SetStateGraph("SGwx78_possessedbody")
    inst:SetBrain(brain)

	inst:AddComponent("efficientuser")
	inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, TUNING.SKILLS.WX78.POSSESSEDBODY_DAMAGE_MULT, inst)

    -- local activatable = inst:AddComponent("activatable")
    -- activatable.CanActivateFn = CanDoerActivate
    -- activatable.OnActivate = OnActivateFn
    -- activatable.quickaction = true
    -- activatable.forcerightclickaction = true

    inst:AddComponent("areaaware") -- needed for slipperyfeet
	inst.components.areaaware:StartWatchingTile(WORLD_TILES.OCEAN_ICE)

    inst:AddComponent("lootdropper")
    inst:AddComponent("timer")
    inst:AddComponent("damagetyperesist")
    inst:AddComponent("damagetypebonus")
    inst:AddComponent("planardamage")
    inst:AddComponent("planardefense")
    inst:AddComponent("sheltered")
    inst:AddComponent("wx78_abilitycooldowns")
    inst:AddComponent("luckuser")
    inst:AddComponent("bloomer")
    inst:AddComponent("colouradder")
    inst:AddComponent("pinnable")
    inst:AddComponent("slipperyfeet")

    inst.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.SKILLS.WX78.POSSESSEDBODY_LUNAR_RESIST, "lunaraligned")
    inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.SKILLS.WX78.POSSESSEDBODY_VS_SHADOW_BONUS, "lunaraligned")

    inst:AddComponent("debuffable")
    inst.components.debuffable:SetFollowSymbol("headbase", 0, -200, 0)

    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_SMALL)

    inst:AddComponent("inventory")
    --possessed bodies handle inventory dropping manually in their stategraph
    inst.components.inventory:DisableDropOnDeath()
    inst.components.inventory:Open()

    local skinner = inst:AddComponent("skinner")
    skinner:SetupNonPlayerData()
    skinner.useskintypeonload = true -- Hack.

    local upgrademoduleowner = inst:AddComponent("upgrademoduleowner")
    upgrademoduleowner.onmoduleadded = OnUpgradeModuleAdded
    upgrademoduleowner.onmoduleremoved = OnUpgradeModuleRemoved
    upgrademoduleowner.ononemodulepopped = OnOneUpgradeModulePopped
    upgrademoduleowner.onallmodulespopped = OnAllUpgradeModulesRemoved
    upgrademoduleowner:SetChargeLevel(6)
    upgrademoduleowner:SetOverrideFullCharge(true)

    linkeditem:SetOnSkillTreeInitializedFn(OnSkillTreeInitializedFn)
    linkeditem:SetOnOwnerInstCreatedFn(OnOwnerInstCreatedFn)
    linkeditem:SetOnOwnerInstRemovedFn(OnOwnerInstRemovedFn)

    inst:AddComponent("container_transform")
    inst.components.container_transform:SetCanTransform(CanTransformToContainer)
    inst.components.container_transform:SetOnTransform(TransformToContainer)

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("sanitydelta", OnSanityDelta)
    inst:ListenForEvent("armorbroke", ArmorBroke)
    inst:ListenForEvent("equip", OnEquip)
    inst:ListenForEvent("unequip", OnUnequip)
    inst:ListenForEvent("leader_failed_furl", OnLeaderFailedFurl)
    inst:ListenForEvent("leader_failed_row", OnLeaderFailedRow)

    inst.SetIsPlanar = SetIsPlanar
	inst.GetIsPlanar = inst.IsGestaltFxPlanar--GetIsPlanar
    inst.TryToAttachToOwner = TryToAttachToOwner
    inst.TryToReplaceWithBackupBody = TryToReplaceWithBackupBody
    inst.CheckCircuitSlotStatesFrom = CheckCircuitSlotStatesFrom
    inst.CheckZapUserStatesFrom = CheckZapUserStatesFrom
    inst.AddTemperatureModuleLeaning = WX78Common.AddTemperatureModuleLeaning
    inst.DoSanityDeath = DoSanityDeath
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    MakeMediumBurnableCharacter(inst, "torso")
    inst.components.burnable:SetBurnTime(TUNING.PLAYER_BURN_TIME)
    inst.components.burnable.nocharring = true

    MakeLargeFreezableCharacter(inst, "torso")
    inst.components.freezable:SetResistance(4)
    inst.components.freezable:SetDefaultWearOffTime(TUNING.PLAYER_FREEZE_WEAR_OFF_TIME)

    WX78Common.Initialize_Master(inst)

    return inst
end

return Prefab("wx78_possessedbody", fn, assets, prefabs)