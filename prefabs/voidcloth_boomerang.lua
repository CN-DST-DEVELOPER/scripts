local assets =
{
    Asset("ANIM", "anim/boomerang_voidcloth.zip"),
}

local prefabs =
{
    "voidcloth_boomerang_fx",
    "voidcloth_boomerang_proj",
    "voidcloth_boomerang_launch_fx",
    "voidcloth_boomerang_impact_fx",
}

----------------------------------------------------------------------------------------------------------------

local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    inst:SetFxOwner(owner)
    inst:SetBuffOwner(owner)
    
    owner.AnimState:ClearOverrideSymbol("swap_object")
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    
    inst:SetFxOwner(nil)
    inst:SetBuffOwner(nil)

    owner.AnimState:ClearOverrideSymbol("swap_object")
end

----------------------------------------------------------------------------------------------------------------

local function SetBuffEnabled(inst, enabled)
    if enabled == inst._bonusenabled then
        return
    end

    inst._bonusenabled = enabled
    inst.max_projectiles = enabled and TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.SETBONUS_MAX_ACTIVE or TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.MAX_ACTIVE

    inst:OnProjectileCountChanged()
end

local function SetBuffOwner(inst, owner)
    if inst._owner ~= owner then
        if inst._owner ~= nil then
            inst:RemoveEventCallback("equip", inst._onownerequip, inst._owner)
            inst:RemoveEventCallback("unequip", inst._onownerunequip, inst._owner)
            inst._onownerequip = nil
            inst._onownerunequip = nil

            inst:_SetBuffEnabled(false)
        end

        inst._owner = owner

        if owner ~= nil then
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
        inst.AnimState:PushAnimation("idle")
    else
        inst.AnimState:PlayAnimation("broken")
    end
end

local function OnStopFloating(inst)
    inst.fx.AnimState:SetFrame(0)
    inst:DoTaskInTime(0, PushIdleLoop) --#V2C: #HACK restore the looping anim, timing issues.
end

----------------------------------------------------------------------------------------------------------------

local function SetupComponents(inst)
    inst:AddComponent("equippable")
    inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
    inst.components.equippable.is_magic_dapperness = true
    inst.components.equippable.walkspeedmult = TUNING.VOIDCLOTH_BOOMERANG_SPEEDMULT
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
end

local function DisableComponents(inst)
    inst:RemoveComponent("equippable")
end

local FLOAT_SCALE_BROKEN = { .7, .6, .7 }
local FLOAT_SCALE = { .8, .9, .8 }

local function OnIsBrokenDirty(inst)
    if inst.isbroken:value() then
        inst.components.floater:SetSize("small")
        inst.components.floater:SetVerticalOffset(.05)
        inst.components.floater:SetScale(FLOAT_SCALE_BROKEN)
    else
        inst.components.floater:SetSize("small")
        inst.components.floater:SetVerticalOffset(.18)
        inst.components.floater:SetScale(FLOAT_SCALE)
    end
end

local SWAP_DATA = { sym_build = "boomerang_voidcloth", bank = "boomerang_voidcloth" }

local function SetIsBroken(inst, isbroken)
    if isbroken then
        inst.components.floater:SetBankSwapOnFloat(false, 1, nil)
        if inst.fx ~= nil then
            inst.fx:Hide()
        end
    else
        inst.components.floater:SetBankSwapOnFloat(true, -6, SWAP_DATA)
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
        inst.AnimState:PlayAnimation("idle", true)
        SetIsBroken(inst, false)
        inst:RemoveTag("broken")
        inst.components.inspectable.nameoverride = nil
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnDischarged(inst)
    inst.components.weapon:SetRange(nil)
    inst.components.weapon:SetProjectile(nil)
end

local function OnCharged(inst)
    inst.components.weapon:SetRange(TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST, TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST_MAX)
    inst.components.weapon:SetProjectile("voidcloth_boomerang_proj")
end

----------------------------------------------------------------------------------------------------------------

local function OnProjectileCountChanged(inst)
    if #inst._projectiles >= inst.max_projectiles then
        inst.components.rechargeable:Discharge(math.huge)
    else
        inst.components.rechargeable:SetPercent(1)
    end
end

----------------------------------------------------------------------------------------------------------------

local function OnPreLoad(inst, data, newents)
    if data ~= nil then
        -- NOTES(DiogoW): Clean up rechargeable save data, we are not using rechargeable in the regular way...
        data.rechargeable = nil
    end
end

----------------------------------------------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("boomerang_voidcloth")
    inst.AnimState:SetBuild("boomerang_voidcloth")
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("shadow_item")
    inst:AddTag("magicweapon")
    inst:AddTag("rangedweapon")
    inst:AddTag("show_broken_ui")

    -- Weapon (from weapon component) added to pristine state for optimization.
    inst:AddTag("weapon")

    -- Shadowlevel (from shadowlevel component) added to pristine state for optimization.
    inst:AddTag("shadowlevel")

    -- Rechargeable (from rechargeable component) added to pristine state for optimization.
    inst:AddTag("rechargeable")

    inst.projectiledelay = FRAMES

    inst:AddComponent("floater")
    inst.isbroken = net_bool(inst.GUID, "voidcloth_boomerang.isbroken", "isbrokendirty")
    SetIsBroken(inst, false)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("isbrokendirty", OnIsBrokenDirty)

        return inst
    end

    inst.scrapbook_weaponrange  = TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST_MAX
    inst.scrapbook_weapondamage = { TUNING.VOIDCLOTH_BOOMERANG_DAMAGE.min, TUNING.VOIDCLOTH_BOOMERANG_DAMAGE.max }
    inst.scrapbook_planardamage = { TUNING.VOIDCLOTH_BOOMERANG_PLANAR_DAMAGE.min, TUNING.VOIDCLOTH_BOOMERANG_PLANAR_DAMAGE.max }

    inst._projectiles = {}
    inst.max_projectiles = TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.MAX_ACTIVE

    inst.SetBuffOwner = SetBuffOwner
    inst.SetFxOwner = SetFxOwner
    inst._SetBuffEnabled = SetBuffEnabled
    inst.OnProjectileCountChanged = OnProjectileCountChanged

    -----------------------------------------------------------

    -- Follow symbol FX initialization.
    local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
    inst.AnimState:SetFrame(frame)
    --V2C: one networked fx for frame 3 (needed for floating)
    --     all other frames will be spawned locally client-side by this fx.
    inst.fx = SpawnPrefab("voidcloth_boomerang_fx")
    inst.fx.AnimState:SetFrame(frame)
    inst:SetFxOwner(nil)
    inst:ListenForEvent("floater_stopfloating", OnStopFloating)

    -----------------------------------------------------------

    SetupComponents(inst)

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.VOIDCLOTH_BOOMERANG_USES)
    inst.components.finiteuses:SetUses(TUNING.VOIDCLOTH_BOOMERANG_USES)

    inst:AddComponent("weapon")
    inst.components.weapon:SetRange(TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST, TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST_MAX)
    inst.components.weapon:SetProjectile("voidcloth_boomerang_proj")

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnDischargedFn(OnDischarged)
    inst.components.rechargeable:SetOnChargedFn(OnCharged)

    inst:AddComponent("shadowlevel")
    inst.components.shadowlevel:SetDefaultLevel(TUNING.VOIDCLOTH_BOOMERANG_SHADOW_LEVEL)

    inst.OnPreLoad = OnPreLoad

    MakeForgeRepairable(inst, FORGEMATERIALS.VOIDCLOTH, OnBroken, OnRepaired)

    MakeHauntableLaunch(inst)

    return inst
end

----------------------------------------------------------------------------------------------------------------

local PROJECTILE_COLLECT_DIST_SQ = 1*1

local PROJECTILE_MAX_SIZE = 1
local PROJECTILE_MIN_SIZE = .4

local PROJECTILE_RETURN_SPEED_ACCELERATION_RATE = 1/3

local function Projectile_OnRemoved(inst)
    if inst._boomerang ~= nil and inst._boomerang:IsValid() then
        table.removearrayvalue(inst._boomerang._projectiles, inst)

        inst._boomerang:OnProjectileCountChanged()
    end
end

local function Projectile_ReturnToThrower(inst, thrower)
    --inst.SoundEmitter:PlaySound("dontstarve/wilson/boomerang_return")

    inst.scalingdata = {
        start = inst.scale,
        finish = PROJECTILE_MIN_SIZE,
        totaltime = TUNING.BOOMERANG_DISTANCE / TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.RETURN_SPEED,
        currenttime = 0,
    }

    inst._returntarget = thrower

    inst.Physics:ClearCollidesWith(COLLISION.LIMITS)
    inst.Physics:SetMotorVel(TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.RETURN_SPEED, 0, 0)
end

local function Projectile_OnHit(inst, attacker, target)
    inst:ReturnToThrower(attacker)

    if target ~= nil and target:IsValid() then
        local fx = SpawnPrefab("voidcloth_boomerang_impact_fx")

        local radius = math.max(0, target:GetPhysicsRadius(0) - .5)
        local angle = (inst.Transform:GetRotation() + 180) * DEGREES
        local x, y, z = target.Transform:GetWorldPosition()

        x = x + math.cos(angle) * radius
        z = z - math.sin(angle) * radius

        fx.Transform:SetPosition(x, y, z)
    end
end

local function Projectile_OnMiss(inst, attacker, target)
    inst:ReturnToThrower(attacker)
end

local function Projectile_OnUpdateFn(inst, dt)
    local scalingdata = inst.scalingdata or {}

    if inst._returntarget == nil then
        -- Do nothing!

    elseif not inst._returntarget:IsValid() or inst._returntarget:IsInLimbo() then
        inst:Remove()

        return
    else
        local p_pos = inst:GetPosition()
        local t_pos = inst._returntarget:GetPosition()

        if distsq(p_pos, t_pos) < PROJECTILE_COLLECT_DIST_SQ then
            inst:Remove()

            return
        else
            local direction = (t_pos - p_pos):GetNormalized()
            local projected_speed = TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.RETURN_SPEED * TheSim:GetTickTime() * TheSim:GetTimeScale()
            local projected = p_pos + direction * projected_speed

            if direction:Dot(t_pos - projected) < 0 then
                inst:Remove()

                return
            end

            inst:FacePoint(t_pos)

            local speed_mult = math.max(1, scalingdata.currenttime * PROJECTILE_RETURN_SPEED_ACCELERATION_RATE)
            inst.Physics:SetMotorVel(TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.RETURN_SPEED * speed_mult, 0, 0)
        end
    end

    if scalingdata.totaltime == nil then
        return
    end

    scalingdata.currenttime = (scalingdata.currenttime or 0) + dt

    if scalingdata.currenttime >= scalingdata.totaltime then
        inst.scale = scalingdata.finish

    else
        inst.scale = Lerp(scalingdata.start, scalingdata.finish, scalingdata.currenttime / scalingdata.totaltime)
    end

    if inst.scale ~= nil then
        inst.AnimState:SetScale(inst.scale, inst.scale)

        local damage_scale = Remap(inst.scale, PROJECTILE_MIN_SIZE, PROJECTILE_MAX_SIZE, 0, 1)
        local bonus_mult = inst._bonusenabled and TUNING.WEAPONS_VOIDCLOTH_SETBONUS_DAMAGE_MULT or 1

        inst.components.weapon:SetDamage(bonus_mult * Lerp(TUNING.VOIDCLOTH_BOOMERANG_DAMAGE.min, TUNING.VOIDCLOTH_BOOMERANG_DAMAGE.max, damage_scale))
        inst.components.planardamage:SetBaseDamage(Lerp(TUNING.VOIDCLOTH_BOOMERANG_PLANAR_DAMAGE.min, TUNING.VOIDCLOTH_BOOMERANG_PLANAR_DAMAGE.max, damage_scale))
    end
end

local function Projectile_OnThrown(inst, owner, target, attacker)
    inst.SoundEmitter:PlaySound("rifts4/voidcloth_boomerang/throw_lp", "loop")

    inst._boomerang = owner
    inst._bonusenabled = owner ~= nil and owner._bonusenabled

    if inst._bonusenabled then
        inst.components.planardamage:AddBonus(inst, TUNING.WEAPONS_VOIDCLOTH_SETBONUS_PLANAR_DAMAGE, "setbonus")
    end

    if owner ~= nil and owner.components.weapon ~= nil then
        owner.components.weapon:OnAttack(attacker, target, inst)

        table.insert(owner._projectiles, inst)

        owner:OnProjectileCountChanged()
    end

    if attacker ~= nil and attacker:IsValid() then
        local fx = SpawnPrefab("voidcloth_boomerang_launch_fx")

        local pos = target:GetPositionAdjacentTo(attacker, .5)

        fx.Transform:SetPosition(pos:Get())
        fx.Transform:SetRotation(fx:GetAngleToPoint(target.Transform:GetWorldPosition()) - 90)
    end
end

local function OnEntitySleep(inst)
    inst.components.projectile:Stop()
    inst:Remove()
end

----------------------------------------------------------------------------------------------------------------

local function ProjectileFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeProjectilePhysics(inst)

    inst.AnimState:SetBank("boomerang_voidcloth")
    inst.AnimState:SetBuild("boomerang_voidcloth")
    inst.AnimState:PlayAnimation("projectile", true)

    inst.AnimState:SetScale(PROJECTILE_MIN_SIZE, PROJECTILE_MIN_SIZE)

    inst.AnimState:SetLightOverride(.1)
    inst.AnimState:SetSymbolLightOverride("lightning", .5)

    inst.AnimState:SetSymbolMultColour("blade", 1, 1, 1, .8)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    -- weapon (from weapon component) added to pristine state for optimization.
    inst:AddTag("weapon")

    -- projectile (from projectile component) added to pristine state for optimization.
    inst:AddTag("projectile")

    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("shadow_item")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scalingdata = {
        start = PROJECTILE_MIN_SIZE,
        finish = PROJECTILE_MAX_SIZE,
        totaltime = TUNING.VOIDCLOTH_BOOMERANG_ATTACK_DIST / TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.LAUNCH_SPEED,
        currenttime = 0,
    }

    inst.persists = false

    inst.ReturnToThrower = Projectile_ReturnToThrower

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.VOIDCLOTH_BOOMERANG_DAMAGE.min)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.VOIDCLOTH_BOOMERANG_PLANAR_DAMAGE.min)

    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.VOIDCLOTH_BOOMERANG_VS_LUNAR_BONUS)

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(Projectile_OnUpdateFn)

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(TUNING.VOIDCLOTH_BOOMERANG_PROJECTILE.LAUNCH_SPEED)
    inst.components.projectile:SetRange(20)
    inst.components.projectile:SetOnHitFn(Projectile_OnHit)
    inst.components.projectile:SetOnMissFn(Projectile_OnMiss)
    inst.components.projectile:SetOnThrownFn(Projectile_OnThrown)
    inst.components.projectile.has_damage_set = true

    inst.OnRemoveEntity = Projectile_OnRemoved
    inst.OnEntitySleep = OnEntitySleep

    return inst
end

----------------------------------------------------------------------------------------


local FX_DEFS =
{
    { anim = "f1", frame_begin = 0, frame_end = 2  },
  --{ anim = "f3", frame_begin = 2                 },
}

local function CreateFxFollowFrame()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("boomerang_voidcloth")
    inst.AnimState:SetBuild("boomerang_voidcloth")

    inst.AnimState:SetLightOverride(.1)

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
                fx.AnimState:PlayAnimation("swap_loop_"..v.anim, true)
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
    end
end

local function FollowSymbolFxFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.AnimState:SetBank("boomerang_voidcloth")
    inst.AnimState:SetBuild("boomerang_voidcloth")
    inst.AnimState:PlayAnimation("swap_loop_f3", true) -- Frame 3 is used for floating.

    inst.AnimState:SetLightOverride(.1)

    inst:AddComponent("highlightchild")
    inst:AddComponent("colouraddersync")

    inst.equiptoggle = net_bool(inst.GUID, "voidcloth_boomerang_fx.equiptoggle", "equiptoggledirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("equiptoggledirty", FxOnEquipToggle)
        return inst
    end

    inst.ToggleEquipped = FxToggleEquipped
    inst.persists = false

    return inst
end

----------------------------------------------------------------------------------------------------------------

return
    Prefab("voidcloth_boomerang",      fn, assets, prefabs),
    Prefab("voidcloth_boomerang_fx",   FollowSymbolFxFn, assets),
    Prefab("voidcloth_boomerang_proj", ProjectileFn, assets)
