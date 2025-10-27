local MakePlayerCharacter = require("prefabs/player_common")
local wortox_soul_common = require("prefabs/wortox_soul_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("SCRIPT", "scripts/prefabs/wortox_soul_common.lua"),
    Asset("SOUND", "sound/wortox.fsb"),
    Asset("ANIM", "anim/player_idles_wortox.zip"),
    Asset("ANIM", "anim/player_idles_wortox_nice.zip"),
    Asset("ANIM", "anim/player_idles_wortox_naughty.zip"),
    Asset("ANIM", "anim/wortox_soul_ball.zip"), -- VFX for idle_naughty.
    Asset("ANIM", "anim/wortox_actions_nabbag.zip"),
    Asset("ANIM", "anim/wortox_portal.zip"),

    Asset("SCRIPT", "scripts/prefabs/skilltree_wortox.lua"),
}

local prefabs =
{
    "wortox_soul_spawn",
    "wortox_portal_jumpin_fx",
    "wortox_portal_jumpout_fx",
    "wortox_eat_soul_fx",
    "wortox_soulecho_buff",
    "wortox_forget_debuff",
    "wortox_panflute_buff",
    "wortox_decoy",
    "wortox_overloading_fx",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.WORTOX
end

prefabs = FlattenTree({ prefabs, start_inv }, true)

for k, v in pairs(start_inv) do
    for i1, v1 in ipairs(v) do
        if not table.contains(prefabs, v1) then
            table.insert(prefabs, v1)
        end
    end
end

--------------------------------------------------------------------------

local function IsValidVictim(victim, explosive)
    return wortox_soul_common.HasSoul(victim) and (victim.components.health:IsDead() or explosive)
end

local function OnRestoreSoul(victim)
    victim.nosoultask = nil
end

local function OnEntityDropLoot(inst, data)
    local victim = data.inst
    if not victim or victim.nosoultask or not victim:IsValid() then
        return
    end
    local shouldspawn = victim == inst
    if shouldspawn or (
        not inst.components.health:IsDead() and
        IsValidVictim(victim, data.explosive)
    ) then
        if not shouldspawn then
            local range = TUNING.WORTOX_SOULEXTRACT_RANGE
            if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_thief_1") then
                range = range + TUNING.SKILLS.WORTOX.SOULEXTRACT_RANGE_BONUS
            end
            shouldspawn = inst:IsNear(victim, range)
        end
        if shouldspawn then
            --V2C: prevents multiple Wortoxes in range from spawning multiple souls per corpse
            victim.nosoultask = victim:DoTaskInTime(5, OnRestoreSoul)
            wortox_soul_common.SpawnSoulsAt(victim, wortox_soul_common.GetNumSouls(victim))
        end
    end
end

local function OnEntityDeath(inst, data)
    if data.inst ~= nil then
        data.inst._soulsource = data.afflicter -- Mark the victim.
        if (data.inst.components.lootdropper == nil or data.inst.components.lootdropper.forcewortoxsouls or data.explosive) then -- NOTES(JBK): Explosive entities do not drop loot.
            OnEntityDropLoot(inst, data)
        end
    end
end

local function OnStarvedTrapSouls(inst, data)
    local trap = data.trap
    if not trap or trap.nosoultask or not trap:IsValid() then
        return
    end
    if (data and data.numsouls or 0) < 1 then
        return
    end
    local range = TUNING.WORTOX_SOULEXTRACT_RANGE
    if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_thief_1") then
        range = range + TUNING.SKILLS.WORTOX.SOULEXTRACT_RANGE_BONUS
    end
    if inst:IsNear(trap, range) then
        --V2C: prevents multiple Wortoxes in range from spawning multiple souls per trap
        trap.nosoultask = trap:DoTaskInTime(5, OnRestoreSoul)
        wortox_soul_common.SpawnSoulsAt(trap, data.numsouls)
    end
end

local function OnMurdered(inst, data)
    if data.incinerated then
        return -- NOTES(JBK): Do not give souls for this.
    end
    local victim = data.victim
    if victim ~= nil and
        victim.nosoultask == nil and
        victim:IsValid() and
        (   not inst.components.health:IsDead() and
            wortox_soul_common.HasSoul(victim)
        ) then
        --V2C: prevents multiple Wortoxes in range from spawning multiple souls per corpse
        victim.nosoultask = victim:DoTaskInTime(5, OnRestoreSoul)
        wortox_soul_common.GiveSouls(inst, wortox_soul_common.GetNumSouls(victim) * (data.stackmult or 1), inst:GetPosition())
    end
end

local function OnHarvestTrapSouls(inst, data)
    if (data.numsouls or 0) > 0 then
        wortox_soul_common.GiveSouls(inst, data.numsouls, data.pos or inst:GetPosition())
    end
end

local function OnRespawnedFromGhost(inst)
    if inst._onentitydroplootfn == nil then
        inst._onentitydroplootfn = function(src, data) OnEntityDropLoot(inst, data) end
        inst:ListenForEvent("entity_droploot", inst._onentitydroplootfn, TheWorld)
    end
    if inst._onentitydeathfn == nil then
        inst._onentitydeathfn = function(src, data) OnEntityDeath(inst, data) end
        inst:ListenForEvent("entity_death", inst._onentitydeathfn, TheWorld)
    end
    if inst._onstarvedtrapsoulsfn == nil then
        inst._onstarvedtrapsoulsfn = function(src, data) OnStarvedTrapSouls(inst, data) end
        inst:ListenForEvent("starvedtrapsouls", inst._onstarvedtrapsoulsfn, TheWorld)
    end
end

local function TryToOnRespawnedFromGhost(inst)
    if not inst.components.health:IsDead() and not inst:HasTag("playerghost") then
        OnRespawnedFromGhost(inst)
    end
end

local function OnBecameGhost(inst)
    if inst._onentitydroplootfn ~= nil then
        inst:RemoveEventCallback("entity_droploot", inst._onentitydroplootfn, TheWorld)
        inst._onentitydroplootfn = nil
    end
    if inst._onentitydeathfn ~= nil then
        inst:RemoveEventCallback("entity_death", inst._onentitydeathfn, TheWorld)
        inst._onentitydeathfn = nil
    end
    if inst._onstarvedtrapsoulsfn ~= nil then
        inst:RemoveEventCallback("starvedtrapsouls", inst._onstarvedtrapsoulsfn, TheWorld)
        inst._onstarvedtrapsoulsfn = nil
    end
end

local function IsSoul(item)
    return item.prefab == "wortox_soul"
end

local function IsSoulJar(item)
    return item.prefab == "wortox_souljar"
end

local function PutSoulOnCooldown(item, cooldowntime, overridepercent)
    if not IsSoul(item) then
        return
    end

    if item.components.rechargeable ~= nil then
        item.components.rechargeable:Discharge(cooldowntime)
        if overridepercent then
            item.components.rechargeable:SetPercent(overridepercent)
        end
    else
        item:AddTag("nosouljar")
    end
end

local function RemoveSoulCooldown(item)
    if not IsSoul(item) then
        return
    end

    if item.components.rechargeable ~= nil then
        item.components.rechargeable:SetPercent(1)
    else
        item:RemoveTag("nosouljar")
    end
end

local function GetStackSize(item)
    return item.components.stackable ~= nil and item.components.stackable:StackSize() or 1
end

local function SortByStackSize(l, r)
    return GetStackSize(l) < GetStackSize(r)
end

local function GetSouls(inst)
    local souls = inst.components.inventory:FindItems(IsSoul)
    local count = 0
    for i, v in ipairs(souls) do
        count = count + GetStackSize(v)
    end
    return souls, count
end

local function DropSouls(inst, souls, dropcount)
    if dropcount <= 0 then
        return
    end
    table.sort(souls, SortByStackSize)
    local pos = inst:GetPosition()
    for _, v in ipairs(souls) do
        local vcount = GetStackSize(v)
        if vcount < dropcount then
            inst.components.inventory:DropItem(v, true, true, pos)
            dropcount = dropcount - vcount
        else
            if vcount == dropcount then
                inst.components.inventory:DropItem(v, true, true, pos)
            else
                v = v.components.stackable:Get(dropcount)
                v.Transform:SetPosition(pos:Get())
                v.components.inventoryitem:OnDropped(true)
            end
            break
        end
    end
end

local function OnReroll(inst)
    local souls, count = inst:GetSouls()
    DropSouls(inst, souls, count)
end

local function RecalculateInclination(inst) -- Server and Client ran.
    local old_inclination = inst.wortox_inclination
    local new_inclination

    local skilltreeupdater = inst.components.skilltreeupdater
    if skilltreeupdater then
        local CUSTOM_FUNCTIONS = require("prefabs/skilltree_defs").CUSTOM_FUNCTIONS.wortox -- Keeping it here to only pull in skilltree_defs out of definition space.
        local nice = skilltreeupdater:CountSkillTag("nice")
        local naughty = skilltreeupdater:CountSkillTag("naughty")
        local affinitytype = skilltreeupdater:IsActivated("wortox_allegiance_lunar") and "lunar" or skilltreeupdater:IsActivated("wortox_allegiance_shadow") and "shadow" or nil
        new_inclination = CUSTOM_FUNCTIONS.CalculateInclination(nice, naughty, affinitytype)
    end

    if new_inclination ~= old_inclination then
        inst.wortox_inclination = new_inclination
        if new_inclination == "nice" then
            inst:RemoveTag("monster")
            inst:RemoveTag("playermonster")
        else
            inst:AddTag("monster")
            inst:AddTag("playermonster")
        end
        inst:PushEvent("wortox_inclination_changed", {old_inclination = old_inclination, new_inclination = new_inclination})
    end
end

local function ClearSoulOverloadTask(inst)
    inst._souloverloadtask = nil
end

local function OnSkillTreeInitialized(inst)
    inst.wortox_needstreeinit = nil
    require("prefabs/skilltree_defs").CUSTOM_FUNCTIONS.wortox.TryPanfluteTimerSetup(inst)
end
local function DestroyOverloadingFX(inst)
    if inst.wortox_souloverload_stoppertask then
        inst.wortox_souloverload_stoppertask:Cancel()
        inst.wortox_souloverload_stoppertask = nil
    end
    if inst.wortox_souloverload_fx then
        if inst.wortox_souloverload_fx:IsValid() then
            inst.wortox_souloverload_fx:Remove()
        end
        inst.wortox_souloverload_fx = nil
    end
end
local function ForceCheckOverload(inst)
    DestroyOverloadingFX(inst)
    inst.wortox_souloverload_forceoverloading = true
    local souls, count = inst:GetSouls()
    inst:CheckForOverload(souls, count)
    inst.wortox_souloverload_forceoverloading = nil
end
local function CreateOverloadingFX(inst)
    if inst.wortox_souloverload_stoppertask == nil then
        inst.wortox_souloverload_stoppertask = inst:DoTaskInTime(TUNING.SKILLS.WORTOX.NAUGHTY_OVERLOAD_STOP_TIME, ForceCheckOverload)
        inst.wortox_souloverload_fx = SpawnPrefab("wortox_overloading_fx")
        inst.wortox_souloverload_fx.entity:SetParent(inst.entity)
        inst.wortox_souloverload_fx.Follower:FollowSymbol(inst.GUID, inst.components.combat.hiteffectsymbol, 0, 0, 0)
        inst:PushEvent("souloverloadwarning") -- Wisecracker.
    end
end
local function CheckForOverload(inst, souls, count)
    local max_count = TUNING.WORTOX_MAX_SOULS -- NOTES(JBK): Keep this logic the same in counts in wortox_soul. [WSCCF]
    if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_souljar_2") then
        local souljars = 0
        inst.components.inventory:ForEachItemSlot(function(item)
            if item.prefab == "wortox_souljar" then
                souljars = souljars + 1
            end
        end)
        local activeitem = inst.components.inventory:GetActiveItem()
        if activeitem and activeitem.prefab == "wortox_souljar" then
            souljars = souljars + 1
        end
        max_count = max_count + souljars * TUNING.SKILLS.WORTOX.FILLED_SOULJAR_SOULCAP_INCREASE_PER
    end
    if count > max_count then
        local dooverload = true
        if inst.wortox_inclination == "naughty" and not inst.wortox_souloverload_forceoverloading then
            CreateOverloadingFX(inst)
            dooverload = false
        end
        if dooverload then
            if inst._souloverloadtask then
                inst._souloverloadtask:Cancel()
                inst._souloverloadtask = nil
            end
            inst._souloverloadtask = inst:DoTaskInTime(TUNING.WORTOX_SOUL_HEAL_DELAY + 0.1, ClearSoulOverloadTask) -- +pad to make it always bigger than the tuning value.
            local dropcount = count - math.floor(max_count / 2) + math.random(0, 2) - 1
            count = count - dropcount
            DropSouls(inst, souls, dropcount)
            local sanitydelta = -TUNING.SANITY_MEDLARGE * math.ceil(dropcount / max_count)
            inst.components.sanity:DoDelta(sanitydelta)
            inst:PushEvent("souloverload") -- Stategraph.
        end
    else
        if count > max_count * TUNING.WORTOX_WISECRACKER_TOOMANY then
            inst:PushEvent("soultoomany") -- This event is not used elsewhere outside of wisecracker.
        end
        if inst.wortox_souloverload_stoppertask then
            DestroyOverloadingFX(inst)
            inst:PushEvent("souloverloadavoided") -- Wisecracker.
        end
    end
    inst.components.inventory:ForEachItemSlot(function(item)
        if item.prefab == "wortox_souljar" then
            count = count + item.soulcount
        end
    end)
    local activeitem = inst.components.inventory:GetActiveItem()
    if activeitem then
        if activeitem.prefab == "wortox_souljar" then
            count = count + activeitem.soulcount
        end
    end

    inst.soulcount = count
end
local function HandleLeftoversShouldDropFn(inst, item)
    if item and item.prefab == "wortox_soul" then
        local souls, count = inst:GetSouls()
        inst:CheckForOverload(souls, count)
    end
    return true
end
local function CheckSoulsAdded(inst)
    inst._checksoulstask = nil
    if inst.wortox_needstreeinit then
        -- Reschedule.
        inst._checksoulstask = inst:DoTaskInTime(0, CheckSoulsAdded)
        return
    end
    local souls, count = inst:GetSouls()
    if inst.finishportalhoptask ~= nil then
        local percent = (inst.finishportalhoptaskmaxtime - GetTaskRemaining(inst.finishportalhoptask)) / inst.finishportalhoptaskmaxtime
        for i, soul in pairs(souls) do
            if soul.components.rechargeable and soul.components.rechargeable:IsCharged() then
                PutSoulOnCooldown(soul, inst.finishportalhoptaskmaxtime, percent)
            end
        end
    end
    inst:CheckForOverload(souls, count)
end

local function CheckSoulsRemoved(inst)
    inst._checksoulstask = nil
    if inst.wortox_needstreeinit then
        -- Reschedule.
        inst._checksoulstask = inst:DoTaskInTime(0, CheckSoulsRemoved)
        return
    end
    local souls, count = inst:GetSouls()
    local TOOFEW = TUNING.WORTOX_MAX_SOULS * TUNING.WORTOX_WISECRACKER_TOOFEW
    if count >= TOOFEW then
        -- Check for overload in case a soul jar left the inventory.
        inst:CheckForOverload(souls, count)
        return
    end
    if count == 0 then
        inst:FinishPortalHop()
    end
    if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wortox_souljar_1") then
        -- Also check the jars and their soul counts too for quieting wisecracker.
        for _, jar in ipairs(inst.components.inventory:FindItems(IsSoulJar)) do
            if jar.components.container then
                for _, soul in ipairs(jar.components.container:FindItems(IsSoul)) do
                    count = count + GetStackSize(soul)
                end
            end
        end
    end

    local should_wisecrack = inst.soulcount ~= count
    inst.soulcount = count
    if count >= TOOFEW then
        return
    end
    if should_wisecrack then
        inst:PushEvent(count > 0 and "soultoofew" or "soulempty") -- These events are not used elsewhere outside of wisecracker.
    end
end

local function CheckSoulsRemovedAfterAnim(inst, anim)
    if inst.AnimState:IsCurrentAnimation(anim) then
        inst._checksoulstask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime() + 2 * FRAMES, CheckSoulsRemoved)
    else
        CheckSoulsRemoved(inst)
    end
end

local function DoCheckSoulsAdded(inst)
    if inst._checksoulstask ~= nil then
        inst._checksoulstask:Cancel()
        inst._checksoulstask = nil
    end
    inst._checksoulstask = inst:DoTaskInTime(0, CheckSoulsAdded)
end

local DoCheckForThese = {
    ["wortox_soul"] = true,
    ["wortox_souljar"] = true,
}

local function OnGotNewItem(inst, data)
    if data.item and DoCheckForThese[data.item.prefab] then
        inst:DoCheckSoulsAdded()
    end
end

local function OnNewActiveItem(inst, data)
    if data.item and DoCheckForThese[data.item.prefab] then
        inst:DoCheckSoulsAdded()
    end
end

local function OnStackSizeChange(inst, data)
    if data.item and DoCheckForThese[data.item.prefab] then
        if (data.oldstacksize or 0) < (data.stacksize or 0) then
            inst:DoCheckSoulsAdded()
        end
    end
end

local function OnDropItem(inst, data)
    if data.item and DoCheckForThese[data.item.prefab] then
        if data.item.ModifyStats then
            data.item:ModifyStats(inst)
        end
        if inst.wortox_ignoresoulcounts then
            return
        end
        if inst.sg:HasStateTag("doing") then
            if inst._checksoulstask ~= nil then
                inst._checksoulstask:Cancel()
                inst._checksoulstask = nil
            end
            inst._checksoulstask = inst:DoTaskInTime(0, CheckSoulsRemovedAfterAnim, "pickup_pst")
        end
    end
end

--------------------------------------------------------------------------

local function IsNotBlocked(pt)
    return TheWorld.Map:IsPassableAtPoint(pt:Get()) and not TheWorld.Map:IsGroundTargetBlocked(pt)
end
local function CanBlinkTo(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsNotBlocked(pt) and IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z) -- NOTES(JBK): Keep in sync with blinkstaff. [BATELE]
end

local function CanBlinkFromWithMap(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

local function ReticuleTargetFn(inst)
    return ControllerReticle_Blink_GetPosition(inst, IsNotBlocked)
end

local function CanSoulhop(inst, souls)
    if inst.replica.inventory:Has("wortox_soul", souls or 1) then
        local rider = inst.replica.rider
        if rider == nil or not rider:IsRiding() then
            return true
        end
    end
    return false
end

local function GetPointSpecialActions(inst, pos, useitem, right)
    if right and useitem == nil then
        local canblink
        if inst.checkingmapactions then
            canblink = inst:CanBlinkFromWithMap(inst.checkingmapactions_pos or inst:GetPosition())
        else
            canblink = inst:CanBlinkTo(pos)
        end
        if canblink and inst.CanSoulhop and inst:CanSoulhop() then
            return { ACTIONS.BLINK }
        end
    end
    return {}
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
end

--------------------------------------------------------------------------

local function OnEatSoul(inst, soul)
    inst.components.hunger:DoDelta(TUNING.CALORIES_MED)
    if inst.wortox_inclination == "nice" then
        inst.components.sanity:DoDelta(-TUNING.SANITY_TINY * 2)
    elseif inst.wortox_inclination == "naughty" then
        -- Feel nothing.
    else
        inst.components.sanity:DoDelta(-TUNING.SANITY_TINY)
    end
    if inst._checksoulstask ~= nil then
        inst._checksoulstask:Cancel()
    end
    inst._checksoulstask = inst:DoTaskInTime(.2, CheckSoulsRemovedAfterAnim, "eat")
end

local function OnSoulHop(inst)
    if inst._checksoulstask ~= nil then
        inst._checksoulstask:Cancel()
    end
    inst._checksoulstask = inst:DoTaskInTime(.5, CheckSoulsRemovedAfterAnim, "wortox_portal_jumpout")
end

local function SetNetvar(inst)
    if inst.player_classified ~= nil then
        assert(inst._freesoulhop_counter >= 0 and inst._freesoulhop_counter <= 7, "Player _freesoulhop_counter out of range: "..tostring(inst._freesoulhop_counter))
        inst.player_classified.freesoulhops:set(inst._freesoulhop_counter)
    end
end

local function ClearSoulhopCounter(inst)
    inst._freesoulhop_counter = 0
    inst._soulhop_cost = 0
    SetNetvar(inst)
end

local function FinishPortalHop(inst)
    if inst.finishportalhoptask ~= nil then
        inst.finishportalhoptask:Cancel()
        inst.finishportalhoptask = nil
        inst.finishportalhoptaskmaxtime = nil
    end
    if inst._freesoulhop_counter > 0 then
        if inst.components.inventory ~= nil then
            inst.components.inventory:ConsumeByName("wortox_soul", math.max(math.ceil(inst._soulhop_cost), 1))
        end
        ClearSoulhopCounter(inst)
    end
    inst:RemoveDebuff("wortox_soulecho_buff")
    inst:DoCheckSoulsAdded()
end

local function GetHopsPerSoul(inst)
    local soulsperhop = TUNING.WORTOX_FREEHOP_HOPSPERSOUL
    local skilltreeupdater = inst.components.skilltreeupdater
    if skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_3") then
        soulsperhop = soulsperhop + TUNING.SKILLS.WORTOX.WORTOX_FREEHOP_HOPSPERSOUL_ADD
    end
    return soulsperhop
end

local function GetSoulEchoCooldownTime(inst)
    local cooldowntime = TUNING.WORTOX_FREEHOP_TIMELIMIT
    local skilltreeupdater = inst.components.skilltreeupdater
    if skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_2") then
        cooldowntime = cooldowntime * TUNING.SKILLS.WORTOX.WORTOX_FREEHOP_TIMELIMIT_MULT
    end
    return cooldowntime
end

local function TryToPortalHop(inst, souls, consumeall)
    local invcmp = inst.components.inventory
    if invcmp == nil then
        return false
    end

    souls = souls or 1
    local _, soulscount = inst:GetSouls()
    if soulscount < souls then
        return false
    end

    inst._freesoulhop_counter = inst._freesoulhop_counter + souls
    inst._soulhop_cost = inst._soulhop_cost + souls

    if not consumeall and inst._freesoulhop_counter < inst:GetHopsPerSoul() then
        inst._soulhop_cost = inst._soulhop_cost - souls -- Make it free.
        local cooldowntime = inst:GetSoulEchoCooldownTime()
        local skilltreeupdater = inst.components.skilltreeupdater
        if skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_1") then
            inst:AddDebuff("wortox_soulecho_buff", "wortox_soulecho_buff", {duration = cooldowntime,})
        end
        invcmp:ForEachItem(PutSoulOnCooldown, cooldowntime)
        if inst.finishportalhoptask ~= nil then
            inst.finishportalhoptask:Cancel()
            inst.finishportalhoptask = nil
            inst.finishportalhoptaskmaxtime = nil
        end
        inst.finishportalhoptask = inst:DoTaskInTime(cooldowntime, inst.FinishPortalHop)
        inst.finishportalhoptaskmaxtime = cooldowntime
    else
        invcmp:ForEachItem(RemoveSoulCooldown)
        inst:FinishPortalHop()
    end
    SetNetvar(inst)

    return true
end

local function OnFreesoulhopsChanged(inst, data)
    inst._freesoulhop_counter = data and data.current or 0
end

--------------------------------------------------------------------------

local function CLIENT_Wortox_HostileTest(inst, target)
	if target.HostileToPlayerTest ~= nil then
		return target:HostileToPlayerTest(inst)
	end

    if target:HasTag("hostile") then
        return true
    end

    return inst.wortox_inclination ~= "nice" and target:HasAnyTag("pig", "catcoon")
end

--------------------------------------------------------------------------

local soulfx_symbols = {
    "tail",
    "swirl3",
    "swirl2",
    "swirl1",
    "star01",
    "spiral_ripple",
    "spiral",
    "outer_fire",
    "moon_glow2",
    "moon_glow",
    "glow",
    "flame2",
    "blob",
}

local function common_postinit(inst)
    for _, v in ipairs(soulfx_symbols) do
        inst.AnimState:OverrideSymbol("soulfx_" .. v, "wortox_soul_ball", v)
    end

    inst:AddTag("playermonster")
    inst:AddTag("monster")
    inst:AddTag("soulstealer")

    --souleater (from souleater component) added to pristine state for optimization
    inst:AddTag("souleater")

    inst._freesoulhop_counter = 0
    inst.CanSoulhop = CanSoulhop
    inst.CanBlinkTo = CanBlinkTo
    inst.CanBlinkFromWithMap = CanBlinkFromWithMap
    inst.RecalculateInclination = RecalculateInclination
    inst:ListenForEvent("setowner", OnSetOwner)

    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = ReticuleTargetFn
    inst.components.reticule.ease = true
	inst.components.reticule.twinstickcheckscheme = true
	inst.components.reticule.twinstickmode = 1
	inst.components.reticule.twinstickrange = 15

    inst.HostileTest = CLIENT_Wortox_HostileTest
    if not TheWorld.ismastersim then
        inst:ListenForEvent("freesoulhopschanged", OnFreesoulhopsChanged)
        inst:ListenForEvent("onactivateskill_client", inst.RecalculateInclination)
        inst:ListenForEvent("ondeactivateskill_client", inst.RecalculateInclination)
    end
end

local function OnSave(inst, data)
    data.freehops = inst._freesoulhop_counter
    data.soulhopcost = inst._soulhop_cost
end

local function OnLoad(inst, data)
    if data == nil then
        return
    end

    inst._freesoulhop_counter = data.freehops or 0
    inst._soulhop_cost = data.soulhopcost or 0
    inst:DoTaskInTime(0, SetNetvar)
end

local function customidleanimfn(inst)
    if inst.wortox_inclination == "nice" then
        if inst.components.skinner == nil or inst.components.skinner:HasSpinnableTail() then
            return "idle_nice"
        end
    elseif inst.wortox_inclination == "naughty" and inst.soulcount > 0 then
        return "idle_naughty"
    end
    return "idle_wortox"
end

local function master_postinit(inst)
    ClearSoulhopCounter(inst)
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.TryToPortalHop = TryToPortalHop
    inst.FinishPortalHop = FinishPortalHop
    inst.GetHopsPerSoul = GetHopsPerSoul
    inst.GetSoulEchoCooldownTime = GetSoulEchoCooldownTime
    inst.DoCheckSoulsAdded = DoCheckSoulsAdded
    inst.GetSouls = GetSouls
    inst.CheckForOverload = CheckForOverload

    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    inst.customidleanim = customidleanimfn

    inst.components.health:SetMaxHealth(TUNING.WORTOX_HEALTH)
    inst.components.hunger:SetMax(TUNING.WORTOX_HUNGER)
    inst.components.sanity:SetMax(TUNING.WORTOX_SANITY)
    inst.components.sanity.neg_aura_mult = TUNING.WORTOX_SANITY_AURA_MULT

    if inst.components.eater ~= nil then
        inst.components.eater:SetAbsorptionModifiers(TUNING.WORTOX_FOOD_MULT, TUNING.WORTOX_FOOD_MULT, TUNING.WORTOX_FOOD_MULT)
    end

    inst.components.foodaffinity:AddPrefabAffinity("pomegranate", TUNING.AFFINITY_15_CALORIES_TINY)
    inst.components.foodaffinity:AddPrefabAffinity("pomegranate_cooked", TUNING.AFFINITY_15_CALORIES_SMALL)

    inst:AddComponent("souleater")
    inst.components.souleater:SetOnEatSoulFn(OnEatSoul)

    inst._checksoulstask = nil
    inst.soulcount = 0

    inst.components.inventory.HandleLeftoversShouldDropFn = HandleLeftoversShouldDropFn

    inst:ListenForEvent("stacksizechange", OnStackSizeChange)
    inst:ListenForEvent("gotnewitem", OnGotNewItem)
    inst:ListenForEvent("newactiveitem", OnNewActiveItem)
    inst:ListenForEvent("dropitem", OnDropItem)
    inst:ListenForEvent("soulhop", OnSoulHop)
    inst:ListenForEvent("murdered", OnMurdered)
    inst:ListenForEvent("harvesttrapsouls", OnHarvestTrapSouls)
    inst:ListenForEvent("ms_respawnedfromghost", OnRespawnedFromGhost)
    inst:ListenForEvent("ms_becameghost", OnBecameGhost)
    inst:ListenForEvent("ms_playerreroll", OnReroll)
    inst:ListenForEvent("onactivateskill_server", inst.RecalculateInclination)
    inst:ListenForEvent("ondeactivateskill_server", inst.RecalculateInclination)
    inst.wortox_needstreeinit = true
    inst:ListenForEvent("ms_skilltreeinitialized", OnSkillTreeInitialized)

    inst:DoTaskInTime(0, TryToOnRespawnedFromGhost) -- NOTES(JBK): Player loading in with zero health will still be alive here delay a frame to get loaded values.
end

-----------------------------------------------------------------------------
-- SOULECHO BUFF
-----------------------------------------------------------------------------

local soulecho_buff_prefabs = {
    "wortox_soulecho_buff_fx",
}

local TEXTURE_soulecho_fx = "fx/soul.tex"
local SHADER_soulecho_fx = "shaders/vfx_particle.ksh"
local COLOUR_ENVELOPE_NAME_soulecho_fx = "colourenvelope_soulecho_fx"
local SCALE_ENVELOPE_NAME_soulecho_fx = "scaleenvelope_soulecho_fx"

local soulecho_buff_fx_assets = {
    Asset("IMAGE", TEXTURE_soulecho_fx),
    Asset("SHADER", SHADER_soulecho_fx),
}

local function OnAttached_soulecho(inst, target, followsymbol, followoffset, data)
    local duration = data and data.duration or target and target.GetSoulEchoCooldownTime and target:GetSoulEchoCooldownTime() or TUNING.WORTOX_FREEHOP_TIMELIMIT
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    inst.components.timer:StartTimer("buffover", duration)
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
    if target ~= nil and target:IsValid() and target.components.locomotor ~= nil then
        target.components.locomotor:SetExternalSpeedMultiplier(target, "wortox_soulecho_buff", TUNING.SKILLS.WORTOX.WORTOX_SOULECHO_SPEEDMULT)
        local fx = SpawnPrefab("wortox_soulecho_buff_fx")
        inst.bufffx = fx
        fx.entity:SetParent(target.entity)
    end
end

local function OnDetached_soulecho(inst, target)
    if target ~= nil and target:IsValid() and target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(target, "wortox_soulecho_buff")
    end
    if inst.bufffx and inst.bufffx:IsValid() then
        inst.bufffx:Remove()
    end
    inst.bufffx = nil
    inst:Remove()
end

local function OnExtendedBuff_soulecho(inst, target, followsymbol, followoffset, data)
    local duration = data and data.duration or target and target.GetSoulEchoCooldownTime and target:GetSoulEchoCooldownTime() or TUNING.WORTOX_FREEHOP_TIMELIMIT
    local time_remaining = inst.components.timer:GetTimeLeft("buffover")
    if time_remaining == nil or duration > time_remaining then
        inst.components.timer:SetTimeLeft("buffover", duration)
    end
end

local function OnTimerDone_soulecho(inst, data)
    if data.name == "buffover" then
        inst.components.debuff:Stop()
    end
end

local function wortox_soulecho_fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached_soulecho)
    inst.components.debuff:SetDetachedFn(OnDetached_soulecho)
    inst.components.debuff:SetExtendedFn(OnExtendedBuff_soulecho)
    inst.components.debuff.keepondespawn = true

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone_soulecho)

    return inst
end


local function InitEnvelope_soulecho_fx()
    local function IntColour(r, g, b, a)
        return { r / 255, g / 255, b / 255, a / 255 }
    end

    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME_soulecho_fx,
        {
            { 0, IntColour(255, 255, 255, 225) },
            { 1, IntColour(255, 255, 255, 0) },
        }
    )

    local max_scale = 0.4
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_soulecho_fx,
        {
            { 0,    { max_scale, max_scale } },
            { 1,    { max_scale * .5, max_scale * .5 } },
        }
    )

    InitEnvelope_soulecho_fx = nil
end

local MAX_LIFETIME_soulecho_fx = 1.0
local function soulecho_buff_fx_emit(effect, sphere_emitter, direction)
    local px, py, pz = sphere_emitter()
    local vx, vy, vz = px * 0.02, 0.1 + py * 0.01, pz * 0.02

    local uv_offset = math.random(0, 9) / 10

    effect:AddParticleUV(
        0,
        MAX_LIFETIME_soulecho_fx, -- lifetime
        px * 2, 0, pz * 2, -- position
        vx + direction.x * 0.05, vy, vz + direction.z * 0.05, -- velocity
        uv_offset, 0 -- uv offset
    )
end

local function soulecho_buff_fx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.entity:SetPristine()

    inst.persists = false

    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return inst
    elseif InitEnvelope_soulecho_fx ~= nil then
        InitEnvelope_soulecho_fx()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(1)

    effect:SetRenderResources(0, TEXTURE_soulecho_fx, SHADER_soulecho_fx)
    effect:SetUVFrameSize(0, 1/10, 1)
    effect:SetMaxNumParticles(0, 200)
    effect:SetMaxLifetime(0, MAX_LIFETIME_soulecho_fx)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_soulecho_fx)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_soulecho_fx)
    effect:SetBlendMode(0, BLENDMODE.Premultiplied)
    effect:EnableBloomPass(0, true)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)

    effect:SetAcceleration(0, 0, 0, 0)
    effect:SetDragCoefficient(0, 0.1)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    local low_per_tick = 3 * tick_time
    local high_per_tick = 30 * tick_time
    local sphere_emitter = CreateSphereEmitter(.25)
    local num_to_emit = 0
    EmitterManager:AddEmitter(inst, nil, function()
        local parent = inst.entity:GetParent()
        if parent then
            local cur_pos = parent:GetPosition()
            if inst.last_pos == nil then
                inst.last_pos = cur_pos
            end
            local dist_moved = cur_pos - inst.last_pos
            local t = math.clamp(dist_moved:Length(), 0, 1)
            dist_moved:Normalize() -- Convert to direction vector.
            local per_tick = Lerp(low_per_tick, high_per_tick, t)
            num_to_emit = num_to_emit + per_tick
            while num_to_emit > 0 do
                soulecho_buff_fx_emit(effect, sphere_emitter, dist_moved)
                num_to_emit = num_to_emit - 1
            end
            inst.last_pos = cur_pos
        end
    end)

    return inst
end

-----------------------------------------------------------------------------
-- OVERLOADING FX
-----------------------------------------------------------------------------

local TEXTURE_overloading_fx = "fx/soul.tex"
local SHADER_overloading_fx = "shaders/vfx_particle.ksh"
local COLOUR_ENVELOPE_NAME_overloading_fx = "colourenvelope_overloading_fx"
local SCALE_ENVELOPE_NAME_overloading_fx = "scaleenvelope_overloading_fx"

local overloading_fx_assets = {
    Asset("IMAGE", TEXTURE_overloading_fx),
    Asset("SHADER", SHADER_overloading_fx),
}

local function InitEnvelope_overloading_fx()
    local function IntColour(r, g, b, a)
        return { r / 255, g / 255, b / 255, a / 255 }
    end

    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME_overloading_fx,
        {
            { 0, IntColour(255, 255, 255, 225) },
            { 1, IntColour(255, 255, 255, 0) },
        }
    )

    local max_scale = 1
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_overloading_fx,
        {
            { 0,    { max_scale * .5, max_scale * .5 } },
            { 1,    { max_scale, max_scale } },
        }
    )

    InitEnvelope_overloading_fx = nil
end

local MAX_LIFETIME_overloading_fx = 0.5
local function overloading_fx_emit(effect, sphere_emitter, direction)
    local px, py, pz = sphere_emitter()
    local vx, vy, vz = px, py * 0.01, pz

    local uv_offset = math.random(0, 9) / 10

    effect:AddParticleUV(
        0,
        MAX_LIFETIME_overloading_fx, -- lifetime
        px * 0.2, py + math.random(), pz * 0.2, -- position
        vx + direction.x * 0.05, vy + direction.y * 0.05, vz + direction.z * 0.05, -- velocity
        uv_offset, 0 -- uv offset
    )
end

local function overloading_fx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.entity:SetPristine()

    inst.persists = false

    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return inst
    elseif InitEnvelope_overloading_fx ~= nil then
        InitEnvelope_overloading_fx()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(1)

    effect:SetRenderResources(0, TEXTURE_overloading_fx, SHADER_overloading_fx)
    effect:SetUVFrameSize(0, 1/10, 1)
    effect:SetMaxNumParticles(0, 200)
    effect:SetMaxLifetime(0, MAX_LIFETIME_overloading_fx)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_overloading_fx)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_overloading_fx)
    effect:SetBlendMode(0, BLENDMODE.Premultiplied)
    effect:EnableBloomPass(0, true)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)

    effect:SetAcceleration(0, 0, 0, 0)
    effect:SetDragCoefficient(0, 0.1)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    local low_per_tick = 3 * tick_time
    local high_per_tick = 30 * tick_time
    local sphere_emitter = CreateSphereEmitter(.25)
    local num_to_emit = 0
    EmitterManager:AddEmitter(inst, nil, function()
        local parent = inst.entity:GetParent()
        if parent then
            local cur_pos = parent:GetPosition()
            if inst.last_pos == nil then
                inst.last_pos = cur_pos
            end
            local dist_moved = cur_pos - inst.last_pos
            local t = math.clamp(dist_moved:Length(), 0, 1)
            dist_moved:Normalize() -- Convert to direction vector.
            local per_tick = Lerp(low_per_tick, high_per_tick, t)
            num_to_emit = num_to_emit + per_tick
            while num_to_emit > 0 do
                overloading_fx_emit(effect, sphere_emitter, dist_moved)
                num_to_emit = num_to_emit - 1
            end
            inst.last_pos = cur_pos
        end
    end)

    return inst
end

-----------------------------------------------------------------------------
-- PANFLUTE FORGET BUFF
-----------------------------------------------------------------------------

local function OnKillBuff_forget(inst)
    inst.components.debuff:Stop()
end

local function OnAttached_forget(inst, target, followsymbol, followoffset, data)
    inst.toforget = data and data.toforget or nil
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    if inst.toforget and target.components.combat ~= nil then
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)
        target.components.combat:SetShouldAvoidAggro(inst.toforget)
        inst:ListenForEvent("onwakeup", function()
            inst.bufftask = inst:DoTaskInTime(TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_FORGET_DURATION, OnKillBuff_forget)
        end, target)
    else
        inst:DoTaskInTime(0, OnKillBuff_forget)
    end
end

local function OnDetached_forget(inst, target)
    if inst.toforget then
        if target ~= nil and target:IsValid() and target.components.combat ~= nil then
            target.components.combat:RemoveShouldAvoidAggro(inst.toforget)
        end
    end
    inst:Remove()
end

local function OnExtendedBuff_forget(inst, target, followsymbol, followoffset, data)
    if inst.bufftask ~= nil then
        inst.bufftask:Cancel()
        inst.bufftask = nil
        local duration = inst.toforget and TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_FORGET_DURATION or 0
        inst.bufftask = inst:DoTaskInTime(duration, OnKillBuff_forget)
    end
end

local function wortox_forget_debuff_fn()
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached_forget)
    inst.components.debuff:SetDetachedFn(OnDetached_forget)
    inst.components.debuff:SetExtendedFn(OnExtendedBuff_forget)
    -- Do not keep on despawn.

    return inst
end

-----------------------------------------------------------------------------
-- PANFLUTE FREE USE BUFF
-----------------------------------------------------------------------------

local function SetPanfluteBuffIconFX(target)
    if target.player_classified then
        target.player_classified.wortox_panflute_buff:set(true)
    end
end

local function ClearPanfluteBuffIconFX(target)
    if target.player_classified then
        target.player_classified.wortox_panflute_buff:set(false)
    end
end

local function OnAttached_panflute(inst, target, followsymbol, followoffset, data)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) --in case of loading
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)
    if target.wortox_panflute_buff_count == nil then
        target.wortox_panflute_buff_count = 0
        SetPanfluteBuffIconFX(target)
    end
    target.wortox_panflute_buff_count = target.wortox_panflute_buff_count + 1
    target:PushEvent("wortox_panflute_playing_active") -- Wisecracker.
end

local function OnDetached_panflute(inst, target)
    if target and target:IsValid() then
        if target.wortox_panflute_buff_count then
            target.wortox_panflute_buff_count = target.wortox_panflute_buff_count - 1
            if target.wortox_panflute_buff_count <= 0 then
                target.wortox_panflute_buff_count = nil
                ClearPanfluteBuffIconFX(target)
                require("prefabs/skilltree_defs").CUSTOM_FUNCTIONS.wortox.TryResetPanfluteTimer(target)
                target:PushEvent("wortox_panflute_playing_used") -- Wisecracker.
            end
        end
    end
    inst:Remove()
end

local function wortox_panflute_buff_fn() -- FIXME(JBK): VFX particle for musical inclination.
    local inst = CreateEntity()

    if not TheWorld.ismastersim then
        --Not meant for client!
        inst:DoTaskInTime(0, inst.Remove)
        return inst
    end

    inst.entity:AddTransform()
    --[[Non-networked entity]]

    inst.persists = false

    inst:AddTag("CLASSIFIED")

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached_panflute)
    inst.components.debuff:SetDetachedFn(OnDetached_panflute)
    inst.components.debuff.keepondespawn = true
    return inst
end

local function wortox_panflute_buff_fx_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("wortox_soul_heal_fx")
    inst.AnimState:SetBuild("wortox_soul_heal_fx")
    inst.AnimState:PlayAnimation("heal", true)
    inst.AnimState:SetFinalOffset(3)
    inst.AnimState:SetScale(1, 0.75)
    inst.AnimState:SetDeltaTimeMultiplier(0.5)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

-----------------------------------------------------------------------------
-- DECOY
-----------------------------------------------------------------------------

local wortox_decoy_assets = {
    Asset("ANIM", "anim/player_emote_extra.zip"),
    Asset("ANIM", "anim/player_emotes_dance2.zip"),
    Asset("ANIM", "anim/player_actions.zip"),
}

local wortox_decoy_prefabs = {
    "wortox_decoy_explode_fx",
    "wortox_decoy_fizzle_fx",
    "wortox_soul_spawn_fx",
}

local COMBAT_MUSTHAVE_TAGS = { "_combat", "_health" }
local COMBAT_CANTHAVE_TAGS = { "INLIMBO", "soul", "noauradamage", "companion" }

local function BreakDecoysFor(decoyowner)
    local wortox_decoy_inst = decoyowner.wortox_decoy_inst
    if wortox_decoy_inst then
        if wortox_decoy_inst:IsValid() then
            wortox_decoy_inst.decoyexpired = true
            wortox_decoy_inst.components.health:Kill()
        end
        decoyowner.wortox_decoy_inst = nil
    end
end

local function SetOwner_decoy(inst, decoyowner)
    if inst.decoyowner and inst.decoyowner ~= decoyowner then
        BreakDecoysFor(inst.decoyowner) -- Break old decoys from old owner.
    end

    inst.decoyowner = decoyowner
    if inst.components.follower then
        inst.components.follower:SetLeader(inst.decoyowner)
    end
    if inst.decoyowner == nil then
        inst._ownername:set("")
        return
    end
    inst._ownername:set(inst.decoyowner:GetDisplayName())
    BreakDecoysFor(inst.decoyowner) -- Break old decoys from new owner.

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SKILLS.WORTOX.SOULDECOY_TAUNT_RADIUS, COMBAT_MUSTHAVE_TAGS, COMBAT_CANTHAVE_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() and ent.entity:IsVisible() then
            if ent.components.combat and ent.components.combat:TargetIs(inst.decoyowner) and ent.components.combat:CanTarget(inst) then
                if wortox_soul_common.SoulDamageTest(inst, ent, decoyowner) then
                    ent.components.combat:SetTarget(inst)
                    if ent.components.combat:TargetIs(inst) then
                        inst.decoylured[ent] = true
                    end
                end
            end
        end
    end
    -- NOTES(JBK): This was making the decoy confusing in mechanic so commenting out for now.
    --if next(inst.decoylured) == nil then
    --    inst:Remove()
    --    return -- Failed to lure anything we should get rid of this.
    --end

    inst.decoyowner.wortox_decoy_inst = inst
    inst.Transform:SetRotation(inst.decoyowner.Transform:GetRotation())

    local duration = TUNING.SKILLS.WORTOX.SOULDECOY_DURATION
    inst.decoythorns = nil
    inst.decoyexplodes = nil
    if inst.decoyowner:HasTag("player") then
        inst.components.skinner:CopySkinsFromPlayer(inst.decoyowner)
        if inst.decoyowner.components.skilltreeupdater then
            if inst.decoyowner.components.skilltreeupdater:IsActivated("wortox_souldecoy_2") then
                duration = duration + TUNING.SKILLS.WORTOX.SOULDECOY_DURATION_BONUS
                inst.decoythorns = true
            end
            if inst.decoyowner.components.skilltreeupdater:IsActivated("wortox_souldecoy_3") then
                inst.decoyexplodes = true
            end
        end
    else
        inst.components.skinner:SetupNonPlayerData()
    end

    inst.sg:GoToState("idle", {deathtime = GetTime() + duration})

    if inst.failedtoinittask ~= nil then
        inst.failedtoinittask:Cancel()
        inst.failedtoinittask = nil
    end
end

local function OnDeath_decoy(inst)
    if inst.decoyowner and inst.decoyowner.wortox_decoy_inst == inst then
        inst.decoyowner.wortox_decoy_inst = nil
    end

    -- Add nearby things targeting the lure to the lured list.
    local decoyowner = inst.decoyowner and inst.decoyowner:IsValid() and inst.decoyowner or nil
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SKILLS.WORTOX.SOULDECOY_TAUNT_RADIUS, COMBAT_MUSTHAVE_TAGS, COMBAT_CANTHAVE_TAGS)
    for _, ent in ipairs(ents) do
        if ent.components.combat then
            if ent.components.combat:TargetIs(inst) or (decoyowner and ent.components.combat:TargetIs(decoyowner)) then
                if wortox_soul_common.SoulDamageTest(inst, ent, decoyowner) then
                    inst.decoylured[ent] = true
                end
            end
        end
    end

    -- Redirect focus back on the owner this inst is now dead and combat target will drop.
    if decoyowner then
        for ent, _ in pairs(inst.decoylured) do
            if ent:IsValid() and ent.entity:IsVisible() then
                if (ent.components.combat and ent.components.combat:TargetIs(inst)) or ent.components.combat:TargetIs(decoyowner) then
                    if ent:GetDistanceSqToInst(decoyowner) <= PLAYER_CAMERA_SEE_DISTANCE_SQ then
                        ent.components.combat:SetTarget(decoyowner)
                    end
                end
            end
        end
    end
end

local function OnAttacked_decoy(inst, data)
    local ent = data and data.attacker or nil
    if ent and ent:IsValid() then
        local decoyowner = inst.decoyowner and inst.decoyowner:IsValid() and inst.decoyowner or nil
        if wortox_soul_common.SoulDamageTest(inst, ent, decoyowner) then
            inst.decoythornstarget = ent
        end
    end
end

local function DoThorns_decoy(inst)
    local ent = inst.decoythornstarget
    if ent and ent:IsValid() and ent.entity:IsVisible() and
        ent:HasAllTags(COMBAT_MUSTHAVE_TAGS) and not ent:HasAnyTag(COMBAT_CANTHAVE_TAGS) and
        inst.components.combat:CanTarget(ent) then
        local initial_damage = inst.components.combat.defaultdamage

        local decoyowner = inst.decoyowner and inst.decoyowner:IsValid() and inst.decoyowner or nil
        local damage = initial_damage * TUNING.SKILLS.WORTOX.SOULDECOY_THORNS_DAMAGE_MULT
        if decoyowner and decoyowner.components.skilltreeupdater and decoyowner.components.skilltreeupdater:IsActivated("wortox_souljar_3") then
            local souls_max = TUNING.SKILLS.WORTOX.SOUL_DAMAGE_MAX_SOULS
            local damage_percent = math.min(decoyowner.soulcount or 0, souls_max) / souls_max
            damage = damage * (1 + (TUNING.SKILLS.WORTOX.SOUL_DAMAGE_SOULS_BONUS_MULT - 1) * damage_percent)
            inst.components.combat:SetDefaultDamage(damage)
        end
        if wortox_soul_common.SoulDamageTest(inst, ent, decoyowner) then
            local x, y, z = ent.Transform:GetWorldPosition()
            local fx = SpawnPrefab("wortox_soul_spawn_fx")
            fx.Transform:SetPosition(x, y, z)
            if decoyowner then
                local damagetoent = damage
                local explosiveresist = ent.components.explosiveresist
                if explosiveresist then
                    damagetoent = damagetoent * (1 - explosiveresist:GetResistance())
                    explosiveresist:OnExplosiveDamage(damagetoent, decoyowner)
                end
                ent.components.combat:GetAttacked(decoyowner, damagetoent, nil, "soul")
            else
                inst.components.combat:DoAttack(ent)
            end
        end

        inst.components.combat:SetDefaultDamage(initial_damage)
    end
end

local function DoExplosion_decoy(inst)
    if inst.decoythorns then
        inst:DoThorns()
    end
    local decoyowner = inst.decoyowner and inst.decoyowner:IsValid() and inst.decoyowner or nil
    local damage = inst.components.combat.defaultdamage
    if decoyowner and decoyowner.components.skilltreeupdater and decoyowner.components.skilltreeupdater:IsActivated("wortox_souljar_3") then
        local souls_max = TUNING.SKILLS.WORTOX.SOUL_DAMAGE_MAX_SOULS
        local damage_percent = math.min(decoyowner.soulcount or 0, souls_max) / souls_max
        damage = damage * (1 + (TUNING.SKILLS.WORTOX.SOUL_DAMAGE_SOULS_BONUS_MULT - 1) * damage_percent)
        inst.components.combat:SetDefaultDamage(damage)
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SKILLS.WORTOX.SOULDECOY_EXPLODE_RADIUS, COMBAT_MUSTHAVE_TAGS, COMBAT_CANTHAVE_TAGS)
    for _, ent in ipairs(ents) do
        if ent:IsValid() and ent.entity:IsVisible() then
            if inst.components.combat:CanTarget(ent) then
                local shouldharm = inst.decoylured[ent]
                if not shouldharm then
                    if ent.components.combat then
                        if ent.components.combat:TargetIs(inst) or decoyowner and ent.components.combat:TargetIs(decoyowner) then
                            if wortox_soul_common.SoulDamageTest(inst, ent, decoyowner) then
                                shouldharm = true
                            end
                        end
                    end
                end
                if shouldharm then
                    if decoyowner then
                        local damagetoent = damage
                        local explosiveresist = ent.components.explosiveresist
                        if explosiveresist then
                            damagetoent = damagetoent * (1 - explosiveresist:GetResistance())
                            explosiveresist:OnExplosiveDamage(damagetoent, decoyowner)
                        end
                        ent.components.combat:GetAttacked(decoyowner, damagetoent, nil, "soul")
                    else
                        inst.components.combat:DoAttack(ent)
                    end
                end
            end
        end
    end
end

local function DoFizzle_decoy(inst)
    if inst.decoythorns then
        inst:DoThorns()
    end
end

local function DisplayNameFn_decoy(inst)
    local ownername = inst._ownername:value()
    return ownername ~= "" and subfmt(STRINGS.NAMES.WORTOX_DECOY_FMT, { name = ownername }) or nil
end

local function GetSpecialDescription_decoy(inst, viewer)
    if not viewer:HasTag("playerghost") then
        local ownername = inst._ownername:value()
        if ownername ~= "" then
            local descriptions = GetString(viewer.prefab, "DESCRIBE", "WORTOX")
            local description = descriptions and descriptions.GENERIC or nil
            if description then
                return string.format(description, ownername) -- Bypass translations for player names.
            end
        end
    end
end

local function wortox_decoy_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst:SetPhysicsRadiusOverride(.75) -- Same as characters for hitting them but no physics because this is nothing more than a decoy.

    inst.DynamicShadow:SetSize(2, 1)
    inst.Transform:SetFourFaced()

    inst.AnimState:AddOverrideBuild("player_emote_extra")
    inst.AnimState:AddOverrideBuild("player_actions")
    -- NOTES(JBK): Keep these in sync with the player. [WSDCSC]
    inst.AnimState:Hide("ARM_carry")
    inst.AnimState:Hide("HAT")
    inst.AnimState:Hide("HAIR_HAT")
    inst.AnimState:Show("HAIR_NOHAT")
    inst.AnimState:Show("HAIR")
    inst.AnimState:Show("HEAD")
    inst.AnimState:Hide("HEAD_HAT")
    inst.AnimState:Hide("HEAD_HAT_NOHELM")
    inst.AnimState:Hide("HEAD_HAT_HELM")

    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wilson")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst:AddTag("decoy")
    inst:AddTag("soulless")
    inst:AddTag("scarytoprey")

    inst._ownername = net_string(inst.GUID, "wortox_decoy._ownername")
    inst.displaynamefn = DisplayNameFn_decoy

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.decoylured = {}

    local follower = inst:AddComponent("follower") -- For leader combat targets.
    follower.noleashing = true
    follower.keepdeadleader = true
    follower:KeepLeaderOnAttacked()
    follower.keepleaderduringminigame = true
    follower.neverexpire = true

    inst:AddComponent("colouradder")
    local skinner = inst:AddComponent("skinner")
    skinner:SetupNonPlayerData()

    local inspectable = inst:AddComponent("inspectable")
    inspectable.getspecialdescription = GetSpecialDescription_decoy

    local health = inst:AddComponent("health")
    health:SetMaxHealth(1)
    health.nofadeout = true

    local combat = inst:AddComponent("combat")
    combat:SetDefaultDamage(TUNING.SKILLS.WORTOX.SOULDECOY_EXPLODE_DAMAGE)
    inst:ListenForEvent("attacked", OnAttacked_decoy)

    inst.SetOwner = SetOwner_decoy
    inst.failedtoinittask = inst:DoTaskInTime(0, inst.Remove) -- Must use SetOwner for this or it will remove itself.

    inst.OnDeath = OnDeath_decoy
    inst.DoThorns = DoThorns_decoy
    inst.DoExplosion = DoExplosion_decoy
    inst.DoFizzle = DoFizzle_decoy

    inst:SetStateGraph("SGwortox_decoy")

    return inst
end

-----------------------------------------------------------------------------

return MakePlayerCharacter("wortox", prefabs, assets, common_postinit, master_postinit),
Prefab("wortox_soulecho_buff", wortox_soulecho_fn, nil, soulecho_buff_prefabs),
Prefab("wortox_soulecho_buff_fx", soulecho_buff_fx_fn, soulecho_buff_fx_assets),
Prefab("wortox_overloading_fx", overloading_fx_fn, overloading_fx_assets),
Prefab("wortox_forget_debuff", wortox_forget_debuff_fn),
Prefab("wortox_panflute_buff", wortox_panflute_buff_fn),
Prefab("wortox_decoy", wortox_decoy_fn, wortox_decoy_assets, wortox_decoy_prefabs)
