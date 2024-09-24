local assets =
{
    Asset("ANIM", "anim/nightmare_axe.zip"),
    Asset("INV_IMAGE", "shadow_battleaxe_l1"),
    Asset("INV_IMAGE", "shadow_battleaxe_l2"),
    Asset("INV_IMAGE", "shadow_battleaxe_l3"),
    Asset("INV_IMAGE", "shadow_battleaxe_l4"),
}

local prefabs =
{
    "shadow_battleaxe_fx",
    "shadow_battleaxe_classified",
}

local IDLE_SOUND_LOOP_NAME = "idle_sound_loop_name"

----------------------------------------------------------------------------------------------------------------

local function AttachClassified(inst, classified)
    inst._classified = classified
    inst.ondetachclassified = function() inst:DetachClassified() end
    inst:ListenForEvent("onremove", inst.ondetachclassified, classified)
end

local function DetachClassified(inst)
    inst._classified = nil
    inst.ondetachclassified = nil
end

local function OnRemoveEntity(inst)
    if inst._classified ~= nil then
        if TheWorld.ismastersim then
            inst._classified:Remove()
            inst._classified = nil
        else
            inst._classified._parent = nil
            inst:RemoveEventCallback("onremove", inst.ondetachclassified, inst._classified)
            inst:DetachClassified()
        end
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    inst:SetBuffOwner(owner)
    inst:SetFxOwner(owner)
    inst:ToggleTalking(inst.level > 1, owner)

    if owner.SoundEmitter ~= nil then
        owner.SoundEmitter:PlaySound("rifts4/nightmare_axe/lvl"..inst.level.."_idle", IDLE_SOUND_LOOP_NAME)
    end

    inst:ListenForEvent("working", inst._onownerworking, owner)

    owner.AnimState:ClearOverrideSymbol("swap_object")
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    inst:SetBuffOwner(nil)
    inst:SetFxOwner(nil)
    inst:ToggleTalking(false)

    if owner.SoundEmitter ~= nil then
        owner.SoundEmitter:KillSound(IDLE_SOUND_LOOP_NAME)
    end

    inst:RemoveEventCallback("working", inst._onownerworking, owner)

    inst:ForgetAllTargets()

    owner.AnimState:ClearOverrideSymbol("swap_object")
end

----------------------------------------------------------------------------------------------------------------

local function SetBuffEnabled(inst, enabled)
    if enabled then
        if not inst._bonusenabled then
            inst._bonusenabled = true

            if inst.components.weapon ~= nil then
                inst.components.weapon:SetDamage(TUNING.SHADOW_BATTLEAXE.DAMAGE * TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT)
            end

            inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_VOIDCLOTH_SETBONUS_PLANAR_DAMAGE, "setbonus")
        end

    elseif inst._bonusenabled then
        inst._bonusenabled = nil

        if inst.components.weapon ~= nil then
            inst.components.weapon:SetDamage(TUNING.SHADOW_BATTLEAXE.DAMAGE)
        end

        inst.components.planardamage:RemoveBonus(inst, "setbonus")
    end
end

local function SetBuffOwner(inst, owner)
    if inst._owner == owner then
        return
    end

    if inst._owner ~= nil then
        inst:RemoveEventCallback("equip", inst._onownerequip, inst._owner)
        inst:RemoveEventCallback("unequip", inst._onownerunequip, inst._owner)
        inst._onownerequip = nil
        inst._onownerunequip = nil

        inst:_SetBuffEnabled(false)
    end

    inst._owner = owner

    if owner == nil then
        return
    end

    inst._onownerequip = function(owner, data)
        if data ~= nil then
            if data.item ~= nil and data.item.prefab == "voidclothhat" then
                inst:_SetBuffEnabled(true)
            elseif data.eslot == EQUIPSLOTS.HEAD then
                inst:_SetBuffEnabled(false)
            end
        end
    end

    inst._onownerunequip  = function(owner, data)
        if data ~= nil and data.eslot == EQUIPSLOTS.HEAD then
            inst:_SetBuffEnabled(false)
        end
    end

    inst:ListenForEvent("equip", inst._onownerequip, owner)
    inst:ListenForEvent("unequip", inst._onownerunequip, owner)

    local hat = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)

    if hat ~= nil and hat.prefab == "voidclothhat" then
        inst:_SetBuffEnabled(true)
    end
end

----------------------------------------------------------------------------------------------------------------

local function SetFxOwner(inst, owner)
    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.fx)
    end

    inst._fxowner = owner

    if owner ~= nil then
        inst.fx.entity:SetParent(owner.entity)
        inst.fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 2)
        inst.fx.components.highlightchild:SetOwner(owner)
        inst.fx:ToggleEquipped(true)

        if owner.components.colouradder ~= nil then
            owner.components.colouradder:AttachChild(inst.fx)
        end
    else
        inst.fx.entity:SetParent(inst.entity)
        -- For floating.
        inst.fx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true, nil, 2)
        inst.fx.components.highlightchild:SetOwner(inst)
        inst.fx:ToggleEquipped(false)
    end
end

local function PushIdleLoop(inst)
    if inst.components.finiteuses:GetUses() > 0 then
        inst.AnimState:PlayAnimation("idle_level"..inst.level, true)
    else
        inst.AnimState:PlayAnimation("broken")
    end
end

local function OnStopFloating(inst)
    inst.fx.AnimState:SetFrame(0)
    inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues.
end

----------------------------------------------------------------------------------------------------------------

local function SetLevel(inst, level, loading)
    if inst.level == level or level < 1 or level > #TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS then
        return
    end

    inst.level = level

    inst.AnimState:PlayAnimation("idle_level"..inst.level, true)
    inst.components.inventoryitem:ChangeImageName("shadow_battleaxe_l"..inst.level)

    if inst.fx ~= nil then
        inst.fx:SetFxLevel(inst.level)
    end

    inst._lifesteal = TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].LIFE_STEAL

    inst.components.planardamage:SetBaseDamage(TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].PLANAR_DAMAGE)

    if inst.components.tool ~= nil then
        inst.components.tool:SetAction(ACTIONS.CHOP, TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].CHOPPING_EFFICIENCY)
    end

    if inst.components.hunger ~= nil then
        inst.components.hunger:SetRate(TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].HUNGER_RATE)

        if inst.level > 1 then
            inst.components.hunger:Resume()
        end
    end

    if inst._owner ~= nil then
        inst:ToggleTalking(inst.level > 1, inst._owner)
    end

    local soundowner = inst._owner ~= nil and inst._owner or inst

    if soundowner ~= nil and soundowner.SoundEmitter ~= nil and not (soundowner:IsInLimbo() or soundowner:IsAsleep()) then
        soundowner.SoundEmitter:KillSound(IDLE_SOUND_LOOP_NAME)
        soundowner.SoundEmitter:PlaySound("rifts4/nightmare_axe/lvl"..inst.level.."_idle", IDLE_SOUND_LOOP_NAME)

        soundowner.SoundEmitter:PlaySound("rifts4/nightmare_axe/levelup")
    end

    if not loading then -- Do NOT clamp epic_kill_count on load.
        inst.epic_kill_count = math.clamp(inst.epic_kill_count, 0, TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[inst.level])
    end
end

local function TryLevelingUp(inst)
    if TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[inst.level+1] ~= nil and inst.epic_kill_count >= TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[inst.level+1] then
        inst:SetLevel(inst.level + 1)

        return true
    end

    return false
end

----------------------------------------------------------------------------------------------------------------

local hitsparks_fx_colouroverride = {1, 0, 0}

local function DoAttackEffects(inst, owner, target)
    local spark = SpawnPrefab("hitsparks_fx")
    spark:Setup(owner, target, nil, hitsparks_fx_colouroverride)
    spark.black:set(true)

    return spark -- Mods.
end

local INVALID_EPIC_CREATURES =
{
    alterguardian_phase1 = true,
    alterguardian_phase2 = true,
}

local function IsEpicCreature(inst, target)
    return target:HasTag("epic") and not target:HasTag("smallepic") and not INVALID_EPIC_CREATURES[target.prefab]
end

local function CheckForEpicCreatureKilled(inst, target)
    if not inst:IsEpicCreature(target) then
        return false
    end

    if inst.epic_kill_count >= TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[#TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS] then
        inst:SayEpicKilledLine(false, true)

        return true
    end

    inst.epic_kill_count = inst.epic_kill_count + 1

    local levelup = inst:TryLevelingUp()

    inst:SayEpicKilledLine(levelup)

    return true
end

local function DoLifeSteal(inst, owner, target)
    if owner.components.health ~= nil and
        owner.components.health:IsHurt() and
        not target:HasOneOfTags(NON_LIFEFORM_TARGET_TAGS)
    then
        owner.components.health:DoDelta(inst._lifesteal, false, "shadow_battleaxe")

        if owner.components.sanity ~= nil then
            owner.components.sanity:DoDelta(-inst._lifesteal * TUNING.SHADOW_BATTLEAXE.LIFE_STEAL_SANITY_LOSS_SCALE)
        end
    end
end

local function OnAttack(inst, owner, target)
    if target ~= nil and target:IsValid() then
        inst:DoAttackEffects(owner, target)
    end

    if target.components.health ~= nil and target.components.health:IsDead() then
        inst.components.hunger:DoDelta(TUNING.SHADOW_BATTLEAXE.HUNGER_GAIN_ONKILL, false)

        if inst._trackedentities[target] == nil then -- The tracking will give us the kill stack.
            local is_epic = inst:CheckForEpicCreatureKilled(target)

            if owner ~= nil and not is_epic then
                inst:SayRegularChatLine("creature_killed", owner)
            end
        end

    elseif inst:IsEpicCreature(target) and
        inst.epic_kill_count < TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[#TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS]
    then
        inst:TrackTarget(target)
    end

    if inst._lifesteal == nil or inst._lifesteal <= 0 then
        return
    end

    inst:DoLifeSteal(owner, target)
end

local function TrackTarget(inst, target)
    if inst._trackedentities[target] then
        inst._trackedentities[target] = GetTime()

        return
    end

    if not target:IsValid() then
        return
    end

    inst._trackedentities[target] = GetTime()

    inst:ListenForEvent("death", inst._ontargetdeath, target)
    inst:ListenForEvent("onremove", inst._ontargetremoved, target)
end

local function ForgetTarget(inst, target)
    if inst._trackedentities[target] then
        inst:RemoveEventCallback("death", inst._ontargetdeath, target)
        inst:RemoveEventCallback("onremove", inst._ontargetremoved, target)

        inst._trackedentities[target] = nil
    end
end

local function ForgetAllTargets(inst)
    for target, time in pairs(inst._trackedentities) do
        inst:ForgetTarget(target)
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnStarving(inst, dt)
    if inst.components.finiteuses ~= nil then
        inst.components.finiteuses:Use(math.min(dt, inst.components.finiteuses:GetUses()))
    end

    inst:SayRegularChatLine("starving", inst._owner)
end

local function OnOwnerWorking(inst, owner, data)
    local iswoodie = owner ~= nil and owner:IsValid() and owner:HasTag("woodcutter")

    if iswoodie and owner.components.sanity ~= nil then
        owner.components.sanity:DoDelta(-TUNING.SANITY_MED)
    end

    inst:SayRegularChatLine(iswoodie and "chopping_woodie" or "chopping", owner)

    if owner.SoundEmitter ~= nil then
        owner.SoundEmitter:PlaySound("rifts4/nightmare_axe/chop")
    end
end

----------------------------------------------------------------------------------------------------------------

local function SetupComponents(inst)
    inst:AddComponent("equippable")
    inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
    inst.components.equippable.is_magic_dapperness = true
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(inst._bonusenabled and TUNING.SHADOW_BATTLEAXE.DAMAGE * TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT or TUNING.SHADOW_BATTLEAXE.DAMAGE)
    inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.CHOP, TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].CHOPPING_EFFICIENCY)
    inst.components.tool:EnableToughWork(true)

    inst:AddComponent("hunger")
    inst.components.hunger:SetMax(TUNING.SHADOW_BATTLEAXE.MAX_HUNGER)
    inst.components.hunger:SetRate(TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].HUNGER_RATE)
    inst.components.hunger:SetOverrideStarveFn(OnStarving)
    inst.components.hunger:Pause()
end

local function DisableComponents(inst)
    inst:RemoveComponent("equippable")
    inst:RemoveComponent("weapon")
    inst:RemoveComponent("tool")
    inst:RemoveComponent("hunger")
end

local FLOAT_SCALE_BROKEN = { .9, .7, .9 }
local FLOAT_SCALE = { .9, .45, .9 }

local function OnIsBrokenDirty(inst)
    if inst.isbroken:value() then
        inst.components.floater:SetSize("small")
        inst.components.floater:SetVerticalOffset(.2)
        inst.components.floater:SetScale(FLOAT_SCALE_BROKEN)
    else
        inst.components.floater:SetSize("med")
        inst.components.floater:SetVerticalOffset(.1)
        inst.components.floater:SetScale(FLOAT_SCALE)
    end

    -- NOTES(DiogoW): #HACK for breaking while floating!
    if inst.components.floater:IsFloating() then
        inst.components.floater:OnNoLongerLandedClient()
        inst.components.floater:OnLandedClient()
    end
end

local SWAP_DATA = { sym_build = "nightmare_axe", bank = "nightmare_axe", anim = "idle_level1" }

local function SetIsBroken(inst, isbroken)
    if isbroken then
        inst.components.floater:SetBankSwapOnFloat(false, 1, nil)

        if inst.components.floater:IsFloating() then
            -- NOTES(DiogoW): #HACK for breaking while floating!
            inst.AnimState:SetBankAndPlayAnimation("nightmare_axe", "broken")
            inst.AnimState:ClearOverrideSymbol("swap_spear")
        end

        if inst.fx ~= nil then
            inst.fx:Hide()
        end
    else
        inst.components.floater:SetBankSwapOnFloat(true, -20, SWAP_DATA)
        if inst.fx ~= nil then
            inst.fx:Show()
        end
    end
    inst.isbroken:set(isbroken)
    OnIsBrokenDirty(inst)
end

local function OnBroken(inst)
    if inst.components.equippable ~= nil then
        DisableComponents(inst)
        inst:SetLevel(1)
        inst.AnimState:PlayAnimation("broken")
        SetIsBroken(inst, true)
        inst:AddTag("broken")
        inst.components.inspectable.nameoverride = "BROKEN_FORGEDITEM"
    end
end

local function OnRepaired(inst)
    if inst.components.equippable == nil then
        SetupComponents(inst)
        inst.fx.AnimState:SetFrame(0)
        inst.AnimState:PlayAnimation("idle_level"..inst.level, true)
        SetIsBroken(inst, false)
        inst:RemoveTag("broken")
        inst.components.inspectable.nameoverride = nil
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    if inst.epic_kill_count > 0 then
        data.epic_kill_count = inst.epic_kill_count
    end
end

local function OnLoad(inst, data)
    if data == nil then
        return
    end

    inst.epic_kill_count = data.epic_kill_count or inst.epic_kill_count

    for level = #TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS, 1, -1 do
        if inst.epic_kill_count >= TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[level] then
            inst:SetLevel(level, true)

            break
        end
    end
end

----------------------------------------------------------------------------------------------------------------

local function GetDebugString(inst)
    local trackedentities = {}

    for target, time in pairs(inst._trackedentities) do
        table.insert(trackedentities, tostring(target))
    end

    return string.format(
        "Level: %d/%d | Defeated Bosses: %d/%d | Life Steal: %.2f | Tracked Bosses: [ %s ]",
        inst.level, #TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS,
        inst.epic_kill_count, TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[#TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS],
        inst._lifesteal,
        table.concat(trackedentities, ", ")
    )
end

----------------------------------------------------------------------------------------------------------------

local TALK_COLOUR = Vector3(204/255, 99/255, 78/255)
local TALK_OFFSET = Vector3(0, 60, 0)
local TALK_SOUNDNAME = "talk"

local TALK_SHAKE_INTERVAL = .05
local TALK_SHAKE_MAX_OFFSET = 20

local function ShakeTextLine(inst)
    if inst.components.talker.widget ~= nil then
        local x, y, z = TALK_OFFSET.z + math.random(TALK_SHAKE_MAX_OFFSET), TALK_OFFSET.y + math.random(TALK_SHAKE_MAX_OFFSET), TALK_OFFSET.z

        inst.components.talker.widget:SetOffset(Vector3(x, y, z))
    end
end

local function OnDoneTalking(inst)
    if inst.localsounds ~= nil then
        inst.localsounds.SoundEmitter:KillSound(TALK_SOUNDNAME)
    end

    if inst._shakelinetask ~= nil then
        inst._shakelinetask:Cancel()
        inst._shakelinetask = nil
    end
end

local function OnTalk(inst, data)
    local sound = inst._classified ~= nil and inst._classified:GetTalkSound() or nil

    if sound ~= nil and inst.localsounds ~= nil then
        inst.localsounds.SoundEmitter:KillSound(TALK_SOUNDNAME)
        inst.localsounds.SoundEmitter:PlaySound(sound, TALK_SOUNDNAME)
    end

    if inst._shakelinetask ~= nil then
        inst._shakelinetask:Cancel()
        inst._shakelinetask = nil
    end

    -- We're using the "noanim" field for this, but it's not related to animations at all XD
    if data ~= nil and data.noanim then
        inst._shakelinetask = inst:DoPeriodicTask(TALK_SHAKE_INTERVAL, ShakeTextLine)
    end
end

local function GetOvertimeChatLine(inst, owner)
    local list = "overtime"

    if inst.components.hunger ~= nil and inst.components.hunger:GetPercent() <= .5 then
        list = "hungry"

    elseif owner ~= nil and owner:HasTag("woodcutter") and  math.random() > 0.7 then
        list = "overtime_woodie"
    end

    return list
end

local function StartOvertimeChatTask(inst, owner)
    owner = owner or inst._owner

    if inst.talktask ~= nil then
        inst.talktask:Cancel()
    end

    inst.talktask = inst:DoTaskInTime(TUNING.SHADOW_BATTLEAXE.TALK_INTERVAL.OVERTIME, inst.SayRegularChatLine, nil, owner)
end

local function SayRegularChatLine(inst, list, owner)
    if inst._classified == nil then
        return
    end

    if list ~= nil then
        local cooldown = TUNING.SHADOW_BATTLEAXE.TALK_INTERVAL[string.upper(list)] or TUNING.SHADOW_BATTLEAXE.TALK_INTERVAL.OVERTIME

        if inst._talktime[list] == nil or (inst._talktime[list] + cooldown <= GetTime()) then
            inst._talktime[list] = GetTime()
        else
            return -- In cooldown!
        end
    end

    -- Level 3 lines are shared with level 4 for regular speech.
    local level = inst.level >= #TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS and math.random() >= .5 and (inst.level - 1) or inst.level

    list = list or GetOvertimeChatLine(inst, owner)
    list = STRINGS.SHADOW_BATTLEAXE_TALK[list.."_l"..level]

    if list ~= nil then
        inst._classified:Say(list, math.random(#list), "rifts4/nightmare_axe/lvl"..inst.level.."_talk_LP")
    end

    if owner ~= nil and inst.talktask ~= nil then
        inst:StartOvertimeChatTask(owner)
    end
end

local function SayEpicKilledLine(inst, levelup, random)
    if inst._classified == nil then
        return
    end

    random = random or levelup

    local list = STRINGS.SHADOW_BATTLEAXE_TALK[levelup and "level_up_l"..inst.level or "epic_killed_l"..inst.level]

    if list ~= nil then
        local choice = random and math.random(#list) or (inst.epic_kill_count - TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS[inst.level])

        inst._classified:Say(list, choice, "rifts4/nightmare_axe/lvl"..inst.level.."_talk_LP")

        inst:StartOvertimeChatTask()
    end
end

local function ToggleTalking(inst, turnon, owner)
    if turnon then
        inst:StartOvertimeChatTask(owner)

    elseif inst.talktask ~= nil then
        inst.talktask:Cancel()
        inst.talktask = nil
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnEntityWake(inst)
    if inst:IsInLimbo() or inst:IsAsleep() then
        return
    end

    if not inst.SoundEmitter:PlayingSound(IDLE_SOUND_LOOP_NAME) then
        inst.SoundEmitter:PlaySound("rifts4/nightmare_axe/lvl"..inst.level.."_idle", IDLE_SOUND_LOOP_NAME)
    end
end

local function OnEntitySleep(inst)
    inst.SoundEmitter:KillSound(IDLE_SOUND_LOOP_NAME)
end

----------------------------------------------------------------------------------------------------------------

local function OnDropped(inst)
    if inst._classified ~= nil then
        inst._classified:SetTarget(nil)
    end
end

local function OnPutInInventory(inst, owner)
    if inst._classified ~= nil then
        inst._classified:SetTarget(owner)
    end
end

----------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nightmare_axe")
    inst.AnimState:SetBuild("nightmare_axe")
    inst.AnimState:PlayAnimation("idle_level1", true)

    inst.AnimState:SetLightOverride(.1)
    inst.AnimState:SetSymbolLightOverride("red", .5)
    inst.AnimState:SetSymbolLightOverride("dread_red", .5)
    inst.AnimState:SetSymbolLightOverride("eye_inner", .5)

    inst:AddTag("sharp")
    inst:AddTag("show_broken_ui")

    -- Weapon (from weapon component) added to pristine state for optimization.
    inst:AddTag("weapon")

    -- Shadowlevel (from shadowlevel component) added to pristine state for optimization.
    inst:AddTag("shadowlevel")

    inst:AddTag("shadow_item")

    inst:AddComponent("floater")
    inst.isbroken = net_bool(inst.GUID, "shadow_battleaxe.isbroken", "isbrokendirty")
    SetIsBroken(inst, false)

    inst:AddComponent("talker")
    inst.components.talker.fontsize = 28
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.colour = TALK_COLOUR
    inst.components.talker.offset = TALK_OFFSET
    inst.components.talker.symbol = "swap_object"

    -- Dedicated server does not need to spawn the local sound fx.
    if not TheNet:IsDedicated() then
        inst.localsounds = CreateEntity()
        inst.localsounds:AddTag("FX")

        --[[Non-networked entity]]
        inst.localsounds.entity:AddTransform()
        inst.localsounds.entity:AddSoundEmitter()
        inst.localsounds.entity:SetParent(inst.entity)

        inst.localsounds:Hide()
        inst.localsounds.persists = false

        inst.OnTalk = OnTalk
        inst.OnDoneTalking = OnDoneTalking

        inst:ListenForEvent("ontalk",      inst.OnTalk       )
        inst:ListenForEvent("donetalking", inst.OnDoneTalking)
    end

    inst.AttachClassified = AttachClassified
    inst.DetachClassified = DetachClassified
    inst.OnRemoveEntity   = OnRemoveEntity

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("isbrokendirty", OnIsBrokenDirty)

        return inst
    end

    inst.scrapbook_planardamage = { TUNING.SHADOW_BATTLEAXE.LEVEL[1].PLANAR_DAMAGE, TUNING.SHADOW_BATTLEAXE.LEVEL[#TUNING.SHADOW_BATTLEAXE.LEVEL_THRESHOLDS].PLANAR_DAMAGE }

    inst.level = 1
    inst.epic_kill_count = 0
    inst._lifesteal = TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].LIFE_STEAL

    inst._classified = SpawnPrefab("shadow_battleaxe_classified")
    inst._classified.entity:SetParent(inst.entity)
    inst._classified._parent = inst
    inst._classified:SetTarget(nil)

    inst._talktime = {}
    inst._trackedentities = {}

    inst.SetLevel = SetLevel
    inst.TryLevelingUp = TryLevelingUp
    inst.SetBuffOwner = SetBuffOwner
    inst.SetFxOwner = SetFxOwner
    inst._SetBuffEnabled = SetBuffEnabled
    inst.IsEpicCreature = IsEpicCreature
    inst.DoAttackEffects = DoAttackEffects
    inst.CheckForEpicCreatureKilled = CheckForEpicCreatureKilled
    inst.DoLifeSteal = DoLifeSteal
    inst.SayRegularChatLine = SayRegularChatLine
    inst.SayEpicKilledLine = SayEpicKilledLine
    inst.StartOvertimeChatTask = StartOvertimeChatTask
    inst.ToggleTalking = ToggleTalking
    inst.TrackTarget = TrackTarget
    inst.ForgetTarget = ForgetTarget
    inst.ForgetAllTargets = ForgetAllTargets
    inst._onownerworking = function(owner, data) OnOwnerWorking(inst, owner, data) end
    inst._ontargetremoved = function(epic, data) inst:ForgetTarget(epic) end
    inst._ontargetdeath = function(epic, data)
        if inst._trackedentities[epic] ~= nil and
            (inst._trackedentities[epic] + TUNING.SHADOW_BATTLEAXE.RECENT_TARGET_TIME) >= GetTime()
        then
            inst:CheckForEpicCreatureKilled(epic)
        end
    end

    -----------------------------------------------------------

    -- Follow symbol FX initialization.
    local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
    inst.AnimState:SetFrame(frame)
    --V2C: one networked fx for frame 3 (needed for floating)
    --     all other frames will be spawned locally client-side by this fx.
    inst.fx = SpawnPrefab("shadow_battleaxe_fx")
    inst.fx.AnimState:SetFrame(frame)
    inst:SetFxOwner(nil)
    inst:ListenForEvent("floater_stopfloating", OnStopFloating)

    -----------------------------------------------------------

    SetupComponents(inst)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("shadow_battleaxe_l1")
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.SHADOW_BATTLEAXE.LEVEL[inst.level].PLANAR_DAMAGE)

    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.WEAPONS_NIGHTMARE_VS_LUNAR_BONUS)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.SHADOW_BATTLEAXE.USES)
    inst.components.finiteuses:SetUses(TUNING.SHADOW_BATTLEAXE.USES)
    inst.components.finiteuses:SetConsumption(ACTIONS.CHOP, 1)

    inst:AddComponent("shadowlevel")
    inst.components.shadowlevel:SetDefaultLevel(TUNING.SHADOW_BATTLEAXE_SHADOW_LEVEL)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.debugstringfn = GetDebugString

    inst.OnEntityWake  = OnEntityWake
    inst.OnEntitySleep = OnEntitySleep

    inst:ListenForEvent("exitlimbo", inst.OnEntityWake)
    inst:ListenForEvent("enterlimbo", inst.OnEntitySleep)

    MakeHauntableLaunch(inst)

    MakeForgeRepairable(inst, FORGEMATERIALS.VOIDCLOTH, OnBroken, OnRepaired)

    return inst
end

----------------------------------------------------------------------------------------------------------------

local FX_DEFS =
{
    { anim = "f1", frame_begin = 0, frame_end = 2  },
  --{ anim = "f3", frame_begin = 2                 },
    { anim = "f4", frame_begin = 3, forcelevel = 1 },
    { anim = "f6", frame_begin = 5                 },
    { anim = "f7", frame_begin = 6                 },
    { anim = "f8", frame_begin = 7                 },
}

local function CreateFxFollowFrame()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("nightmare_axe")
    inst.AnimState:SetBuild("nightmare_axe")

    inst.AnimState:SetLightOverride(.1)
    inst.AnimState:SetSymbolLightOverride("red", .5)
    inst.AnimState:SetSymbolLightOverride("dread_red", .5)
    inst.AnimState:SetSymbolLightOverride("eye_inner", .5)

    inst:AddComponent("highlightchild")

    inst.persists = false

    return inst
end

local function FxRemoveAll(inst)
    for i = 1, #inst.fx do
        inst.fx[i]:Remove()
        inst.fx[i] = nil
    end
end

local function FxColourChanged(inst, r, g, b, a)
    for i = 1, #inst.fx do
        inst.fx[i].AnimState:SetAddColour(r, g, b, a)
    end
end

local function FxOnEquipToggle(inst)
    local owner = inst.equiptoggle:value() and inst.entity:GetParent() or nil
    if owner ~= nil then
        if inst.fx == nil then
            inst.fx = {}
        end
        local frame = inst.AnimState:GetCurrentAnimationFrame()
        for i, v in ipairs(FX_DEFS) do
            local fx = inst.fx[i]
            if fx == nil then
                fx = CreateFxFollowFrame()
                fx.AnimState:PlayAnimation("swap_level"..(v.forcelevel or inst._level:value()).."_"..v.anim, true)
                inst.fx[i] = fx
            end
            fx.entity:SetParent(owner.entity)
            fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, v.frame_begin, v.frame_end)
            fx.AnimState:SetFrame(frame)
            fx.components.highlightchild:SetOwner(owner)
        end
        inst.components.colouraddersync:SetColourChangedFn(FxColourChanged)
        inst.OnRemoveEntity = FxRemoveAll
    elseif inst.OnRemoveEntity ~= nil then
        inst.OnRemoveEntity = nil
        inst.components.colouraddersync:SetColourChangedFn(nil)
        FxRemoveAll(inst)
    end
end

local function FxToggleEquipped(inst, equipped)
    if equipped ~= inst.equiptoggle:value() then
        inst.equiptoggle:set(equipped)
        -- Dedicated server does not need to spawn the local fx.
        if not TheNet:IsDedicated() then
            FxOnEquipToggle(inst)
        end

        local level = equipped and inst._level:value() or 1

        -- Disable movement (levels) while floating.
        inst.AnimState:PlayAnimation("swap_level"..level.."_f3", true) -- Frame 3 is used for floating.
    end
end

local function OnLevelDirty(inst)
    local level = inst._level:value()

    if inst.fx ~= nil then
        for i = 1, #inst.fx do
            local def = FX_DEFS[i]
            local level = def.forcelevel or inst._level:value()

            inst.fx[i].AnimState:PlayAnimation("swap_level"..level.."_"..def.anim, true)
        end
    end
end

local function SetFxLevel(inst, level)
    inst.AnimState:SetFrame(0)
    inst.AnimState:PlayAnimation("swap_level"..(inst.equiptoggle:value() and level or 1).."_f3", true) -- Frame 3 is used for floating.

    inst._level:set(level)

    if not TheNet:IsDedicated() then
        inst:OnLevelDirty()
    end
end

local function FollowSymbolFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.AnimState:SetBank("nightmare_axe")
    inst.AnimState:SetBuild("nightmare_axe")
    inst.AnimState:PlayAnimation("swap_level1_f3", true) -- Frame 3 is used for floating.

    inst.AnimState:SetLightOverride(.1)
    inst.AnimState:SetSymbolLightOverride("red", .5)
    inst.AnimState:SetSymbolLightOverride("dread_red", .5)
    inst.AnimState:SetSymbolLightOverride("eye_inner", .5)

    inst:AddComponent("highlightchild")
    inst:AddComponent("colouraddersync")

    inst.OnLevelDirty = OnLevelDirty

    inst._level = net_tinybyte(inst.GUID, "shadow_battleaxe_fx._level", "leveldirty")
    inst._level:set(1)

    inst.equiptoggle = net_bool(inst.GUID, "shadow_battleaxe_fx.equiptoggle", "equiptoggledirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("equiptoggledirty", FxOnEquipToggle)
        inst:ListenForEvent("leveldirty", inst.OnLevelDirty)

        return inst
    end

    inst.SetFxLevel = SetFxLevel
    inst.ToggleEquipped = FxToggleEquipped
    inst.persists = false

    return inst
end

----------------------------------------------------------------------------------------------------------------

return
    Prefab("shadow_battleaxe",    fn,               assets, prefabs),
    Prefab("shadow_battleaxe_fx", FollowSymbolFxFn                 )
