local assets =
{
    Asset("ANIM", "anim/scythe_voidcloth.zip"),
}

local prefabs =
{
    "voidcloth_scythe_fx",
    "hitsparks_fx",

    "voidcloth_scythe_classified",
}

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

--------------------------------------------------------------------------

local function ondonetalking(inst)
    inst.localsounds.SoundEmitter:KillSound("talk")
end

local function ontalk(inst)
    local sound = inst._classified ~= nil and inst._classified:GetTalkSound() or nil
    if sound ~= nil then
        inst.localsounds.SoundEmitter:KillSound("talk")
        inst.localsounds.SoundEmitter:PlaySound(sound)
    end
end

--------------------------------------------------------------------------

local function OnEnabledSetBonus(inst)
    inst.components.weapon:SetDamage(TUNING.VOIDCLOTH_SCYTHE_DAMAGE * TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT)
    inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_VOIDCLOTH_SETBONUS_PLANAR_DAMAGE, "setbonus")
end

local function OnDisabledSetBonus(inst)
    inst.components.weapon:SetDamage(TUNING.VOIDCLOTH_SCYTHE_DAMAGE)
    inst.components.planardamage:RemoveBonus(inst, "setbonus")
end

local function SetFxOwner(inst, owner)
    if owner ~= nil then
        inst.fx.entity:SetParent(owner.entity)
        inst.fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 2)
        inst.fx.components.highlightchild:SetOwner(owner)
        inst.fx:ToggleEquipped(true)
    else
        inst.fx.entity:SetParent(inst.entity)
        --For floating
        inst.fx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true, nil, 2)
        inst.fx.components.highlightchild:SetOwner(inst)
        inst.fx:ToggleEquipped(false)
    end
end

local function PushIdleLoop(inst)
    inst.AnimState:PushAnimation("idle")
end

local function OnStopFloating(inst)
    inst.fx.AnimState:SetFrame(0)
    inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues
end

local function SayRandomLine(inst, str_list, owner)
    if owner:HasTag("player_shadow_aligned") and inst._classified ~= nil then
        inst._classified:Say(str_list, math.random(#str_list))

        if inst.talktask ~= nil then
            inst.talktask:Cancel()
            inst.talktask = nil
        end

        local iswoodie = owner ~= nil and owner:HasTag("woodcutter")
        local str_list = iswoodie and math.random() > 0.7 and STRINGS.VOIDCLOTH_SCYTHE_TALK.lucy or STRINGS.VOIDCLOTH_SCYTHE_TALK.overtime

        inst.talktask = inst:DoTaskInTime(TUNING.VOIDCLOTH_SCYTHE_TALK_INTERVAL, inst.SayRandomLine, str_list, owner)
    end
end

local function ToggleTalking(inst, turnon, owner)
    if inst.talktask ~= nil then
        inst.talktask:Cancel()
        inst.talktask = nil
    end

    if turnon and owner:HasTag("player_shadow_aligned") then
        inst._classified:SetTarget(owner)
        inst.talktask = inst:DoTaskInTime(TUNING.VOIDCLOTH_SCYTHE_TALK_INITIAL_INTERVAL, inst.SayRandomLine, STRINGS.VOIDCLOTH_SCYTHE_TALK.overtime, owner)
    end
end

local function OnEquip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_scythe", inst.GUID, "scythe_voidcloth")
    else
        owner.AnimState:OverrideSymbol("swap_object", "scythe_voidcloth", "swap_scythe")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    SetFxOwner(inst, owner)

    inst:ToggleTalking(true, owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
    SetFxOwner(inst, nil)

    inst:ToggleTalking(false, owner)
end

local function HarvestPickable(inst, ent, doer)
    if ent.components.pickable.picksound ~= nil then
        doer.SoundEmitter:PlaySound(ent.components.pickable.picksound)
    end

    local success, loot = ent.components.pickable:Pick(TheWorld)

    if loot ~= nil then
        for i, item in ipairs(loot) do
            Launch(item, doer, 1.5)
        end
    end
end

local function IsEntityInFront(inst, entity, doer_rotation, doer_pos)
    local facing = Vector3(math.cos(-doer_rotation / RADIANS), 0 , math.sin(-doer_rotation / RADIANS))

    return IsWithinAngle(doer_pos, facing, TUNING.VOIDCLOTH_SCYTHE_HARVEST_ANGLE_WIDTH, entity:GetPosition())
end

local HARVEST_MUSTTAGS  = {"pickable"}
local HARVEST_CANTTAGS  = {"INLIMBO", "FX"}
local HARVEST_ONEOFTAGS = {"plant", "lichen", "oceanvine", "kelp"}

local function DoScythe(inst, target, doer)
    inst:SayRandomLine(STRINGS.VOIDCLOTH_SCYTHE_TALK.onharvest, doer)

    if target.components.pickable ~= nil then
        local doer_pos = doer:GetPosition()
        local x, y, z = doer_pos:Get()

        local doer_rotation = doer.Transform:GetRotation()

        local ents = TheSim:FindEntities(x, y, z, TUNING.VOIDCLOTH_SCYTHE_HARVEST_RADIUS, HARVEST_MUSTTAGS, HARVEST_CANTTAGS, HARVEST_ONEOFTAGS)
        for _, ent in pairs(ents) do
            if ent:IsValid() and ent.components.pickable ~= nil then
                if inst:IsEntityInFront(ent, doer_rotation, doer_pos) then
                    inst:HarvestPickable(ent, doer)
                end
            end
        end
    end
end

local hitsparks_fx_colouroverride = {1, 0, 0}
local function OnAttack(inst, attacker, target)
    if target ~= nil and target:IsValid() then
        local spark = SpawnPrefab("hitsparks_fx")
        spark:Setup(attacker, target, nil, hitsparks_fx_colouroverride)
        spark.black:set(true)
    end
end

local function ScytheFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("scythe_voidcloth")
    inst.AnimState:SetBuild("scythe_voidcloth")
    inst.AnimState:PlayAnimation("idle", true)

    inst.AttachClassified = AttachClassified
    inst.DetachClassified = DetachClassified
    inst.OnRemoveEntity   = OnRemoveEntity

    inst:AddTag("sharp")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    --shadowlevel (from shadowlevel component) added to pristine state for optimization
    inst:AddTag("shadowlevel")

    inst:AddTag("shadow_item")

    MakeInventoryFloatable(inst, "med", 0.05, {1.5, 0.4, 1.5})

    local talker = inst:AddComponent("talker")
    talker.fontsize = 28
    talker.font = TALKINGFONT
    talker.colour = Vector3(143/255, 41/255, 41/255)
    talker.offset = Vector3(0, 0, 0)
    talker.symbol = "swap_object"

    --Dedicated server does not need to spawn the local sound fx
    if not TheNet:IsDedicated() then
        inst.localsounds = CreateEntity()
        inst.localsounds:AddTag("FX")

        --[[Non-networked entity]]
        inst.localsounds.entity:AddTransform()
        inst.localsounds.entity:AddSoundEmitter()
        inst.localsounds.entity:SetParent(inst.entity)
        inst.localsounds:Hide()
        inst.localsounds.persists = false
        inst:ListenForEvent("ontalk", ontalk)
        inst:ListenForEvent("donetalking", ondonetalking)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._classified = SpawnPrefab("voidcloth_scythe_classified")
    inst._classified.entity:SetParent(inst.entity)
    inst._classified._parent = inst
    inst._classified:SetTarget(nil)


    local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
    inst.AnimState:SetFrame(frame)
    --V2C: one networked fx for frame 3 (needed for floating)
    --     all other frames will be spawned locally client-side by this fx
    inst.fx = SpawnPrefab("voidcloth_scythe_fx")
    inst.fx.AnimState:SetFrame(frame)
    SetFxOwner(inst, nil)
    inst:ListenForEvent("floater_stopfloating", OnStopFloating)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    local tool = inst:AddComponent("tool")
    tool:SetAction(ACTIONS.SCYTHE)

    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(TUNING.VOIDCLOTH_SCYTHE_USES)
    finiteuses:SetUses(TUNING.VOIDCLOTH_SCYTHE_USES)
    finiteuses:SetOnFinished(inst.Remove)
    finiteuses:SetConsumption(ACTIONS.SCYTHE, 1)

    local weapon = inst:AddComponent("weapon")
    weapon:SetDamage(TUNING.VOIDCLOTH_SCYTHE_DAMAGE)
    weapon:SetOnAttack(OnAttack)

    local planardamage = inst:AddComponent("planardamage")
    planardamage:SetBaseDamage(TUNING.VOIDCLOTH_SCYTHE_PLANAR_DAMAGE)

    local damagetypebonus = inst:AddComponent("damagetypebonus")
    damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.WEAPONS_VOIDCLOTH_VS_LUNAR_BONUS)

    local equippable = inst:AddComponent("equippable")
    equippable.dapperness = -TUNING.DAPPERNESS_MED
    equippable.is_magic_dapperness = true
    equippable:SetOnEquip(OnEquip)
    equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("shadowlevel")
    inst.components.shadowlevel:SetDefaultLevel(TUNING.VOIDCLOTH_SCYTHE_SHADOW_LEVEL)

    local setbonus = inst:AddComponent("setbonus")
    setbonus:SetSetName(EQUIPMENTSETNAMES.VOIDCLOTH)
    setbonus:SetOnEnabledFn(OnEnabledSetBonus)
    setbonus:SetOnDisabledFn(OnDisabledSetBonus)

    MakeHauntableLaunch(inst)

    inst.components.floater:SetBankSwapOnFloat(true, -11, {sym_name = "swap_scythe", sym_build = "scythe_voidcloth", bank = "scythe_voidcloth"})

    inst.SayRandomLine = SayRandomLine
    inst.ToggleTalking = ToggleTalking
    inst.DoScythe = DoScythe
    inst.IsEntityInFront = IsEntityInFront
    inst.HarvestPickable = HarvestPickable

    return inst
end

--------------------------------------------------------------------------

local FX_DEFS =
{
    { anim = "swap_loop_1", frame_begin = 0, frame_end = 2 },
    --{ anim = "swap_loop_3", frame_begin = 2 },
    { anim = "swap_loop_6", frame_begin = 5 },
    { anim = "swap_loop_7", frame_begin = 6 },
    { anim = "swap_loop_8", frame_begin = 7 },
}

local function CreateFxFollowFrame()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("scythe_voidcloth")
    inst.AnimState:SetBuild("scythe_voidcloth")

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
                fx.AnimState:PlayAnimation(v.anim, true)
                inst.fx[i] = fx
            end
            fx.entity:SetParent(owner.entity)
            fx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, v.frame_begin, v.frame_end)
            fx.AnimState:SetFrame(frame)
            fx.components.highlightchild:SetOwner(owner)
        end
        inst.OnRemoveEntity = FxRemoveAll
    elseif inst.OnRemoveEntity ~= nil then
        inst.OnRemoveEntity = nil
        FxRemoveAll(inst)
    end
end

local function FxToggleEquipped(inst, equipped)
    if equipped ~= inst.equiptoggle:value() then
        inst.equiptoggle:set(equipped)
        --Dedicated server does not need to spawn the local fx
        if not TheNet:IsDedicated() then
            FxOnEquipToggle(inst)
        end
    end
end

local function FollowSymbolFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.AnimState:SetBank("scythe_voidcloth")
    inst.AnimState:SetBuild("scythe_voidcloth")
    inst.AnimState:PlayAnimation("swap_loop_3", true) --frame 3 is used for floating

    inst:AddComponent("highlightchild")

    inst.equiptoggle = net_bool(inst.GUID, "voidcloth_scythe_fx.equiptoggle", "equiptoggledirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("equiptoggledirty", FxOnEquipToggle)
        return inst
    end

    inst.ToggleEquipped = FxToggleEquipped
    inst.persists = false

    return inst
end

return
        Prefab("voidcloth_scythe",    ScytheFn,         assets, prefabs),
        Prefab("voidcloth_scythe_fx", FollowSymbolFxFn, assets)