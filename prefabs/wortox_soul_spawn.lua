local wortox_soul_common = require("prefabs/wortox_soul_common")

local assets =
{
    Asset("ANIM", "anim/wortox_soul_ball.zip"),
    Asset("SCRIPT", "scripts/prefabs/wortox_soul_common.lua"),
}

local prefabs =
{
    "wortox_soul_in_fx",
    "wortox_soul",
    "wortox_soul_heal_fx",
}

local SCALE = .8
local SOUL_SPEAR_TICK_TIME = 0.1

local function CreateTail()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    MakeInventoryPhysics(inst)
    inst.Physics:ClearCollisionMask()

    inst.AnimState:SetBank("wortox_soul_ball")
    inst.AnimState:SetBuild("wortox_soul_ball")
    inst.AnimState:PlayAnimation("disappear")
    inst.AnimState:SetScale(SCALE, SCALE)
    inst.AnimState:SetFinalOffset(3)

    inst:ListenForEvent("animover", inst.Remove)

    return inst
end

local function OnUpdateProjectileTail(inst)--, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    for tail, _ in pairs(inst._tails) do
        tail:ForceFacePoint(x, y, z)
    end
    if inst.entity:IsVisible() then
        local tail = CreateTail()
        local rot = inst.Transform:GetRotation()
        tail.Transform:SetRotation(rot)
        rot = rot * DEGREES
        local offsangle = math.random() * TWOPI
        local offsradius = (math.random() * .2 + .2) * SCALE
        local hoffset = math.cos(offsangle) * offsradius
        local voffset = math.sin(offsangle) * offsradius
        tail.Transform:SetPosition(x + math.sin(rot) * hoffset, y + voffset, z + math.cos(rot) * hoffset)
        local speed = TUNING.WORTOX_SOUL_PROJECTILE_SPEED
        tail.Physics:SetMotorVel(speed * (.2 + math.random() * .3), 0, 0)
        inst._tails[tail] = true
        inst:ListenForEvent("onremove", function(tail) inst._tails[tail] = nil end, tail)
        tail:ListenForEvent("onremove", function(inst)
            tail.Transform:SetRotation(tail.Transform:GetRotation() + math.random() * 30 - 15)
        end, inst)
    end
end

local function OnHit(inst, attacker, target)
    if target ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("wortox_soul_in_fx")
        fx.Transform:SetPosition(x, y, z)
        fx:Setup(target)
        --ignore .isvisible, as long as it's .isopen
        if target.components.inventory ~= nil and target.components.inventory.isopen then
            target.components.inventory:GiveItem(SpawnPrefab("wortox_soul"), nil, target:GetPosition())
        else
            --reuse fx variable
            fx = SpawnPrefab("wortox_soul")
            fx.Transform:SetPosition(x, y, z)
            fx.components.inventoryitem:OnDropped(true)
        end
    end
    inst:Remove()
end

local function OnHasTailDirty(inst)
    if inst._hastail:value() and inst._tails == nil then
        inst._tails = {}
        if inst.components.updatelooper == nil then
            inst:AddComponent("updatelooper")
        end
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateProjectileTail)
    end
end

local function OnThrownTimeout(inst)
    inst._timeouttask = nil
    inst.components.projectile:Miss(inst.components.projectile.target)
end

local function OnThrown(inst, owner, target, attacker)
    if inst._timeouttask ~= nil then
        inst._timeouttask:Cancel()
        inst._timeouttask = nil
    end
    local duration = TUNING.WORTOX_SOUL_PROJECTILE_LIFETIME
    if target and target.components.skilltreeupdater then
        if target.components.skilltreeupdater:IsActivated("wortox_thief_2") then
            duration = duration + TUNING.SKILLS.WORTOX.SOUL_PROJECTILE_LIFETIME_BONUS
        end
    end
    inst._timeouttask = inst:DoTaskInTime(duration, OnThrownTimeout)
    if inst._seektask ~= nil then
        inst._seektask:Cancel()
        inst._seektask = nil
    end
    inst.AnimState:Hide("blob")
    inst._hastail:set(true)
    if not TheNet:IsDedicated() then
        OnHasTailDirty(inst)
    end
end

local function ThiefSort(a, b) -- Better than bogo!
    return a.distsq < b.distsq
end

local function RethrowProjectile(inst, speed, soulthiefreceiver)
    if soulthiefreceiver:IsValid() then
        inst.components.projectile:SetSpeed(speed)
        inst.components.projectile:SetHoming(true)

        local x, y, z = inst.Transform:GetWorldPosition()
        inst.components.projectile:SetBounced(true)
        inst.components.projectile.overridestartpos = Vector3(x, 0, z)
        inst.components.projectile:Throw(inst, soulthiefreceiver, soulthiefreceiver)
    end
end

local COMBAT_MUSTHAVE_TAGS = { "_combat", "_health" }
local COMBAT_CANTHAVE_TAGS = { "INLIMBO", "soul", "noauradamage", "companion" }
local function SoulSpearTick(inst, owner)
    if not owner:IsValid() then
        return
    end

    if inst.soul_spear_cooldown then
        inst.soul_spear_cooldown = inst.soul_spear_cooldown - 1
        if inst.soul_spear_cooldown <= 0 then
            inst.soul_spear_cooldown = nil
        else
            return
        end
    end

    local damage = TUNING.SKILLS.WORTOX.SOUL_SPEAR_DAMAGE
    if owner and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_souljar_3") then
        local souls_max = TUNING.SKILLS.WORTOX.SOUL_DAMAGE_MAX_SOULS
        local damage_percent = math.min(owner.soulcount or 0, souls_max) / souls_max
        damage = damage * (1 + (TUNING.SKILLS.WORTOX.SOUL_DAMAGE_SOULS_BONUS_MULT - 1) * damage_percent)
    end


    local hitsomething = false
    local r = inst:GetPhysicsRadius(0) + 0.5 -- Extra padding for visual ambiguity.
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, MAX_PHYSICS_RADIUS, COMBAT_MUSTHAVE_TAGS, COMBAT_CANTHAVE_TAGS)
    for _, ent in ipairs(ents) do
        if ent.components.combat then
            local r2 = ent:GetPhysicsRadius(0)
            local x2, y2, z2 = ent.Transform:GetWorldPosition()
            local dx, dz = x2 - x, z2 - z
            local dsq = dx * dx + dz * dz
            local dr = r2 + r
            if dsq < dr * dr and wortox_soul_common.SoulDamageTest(inst, ent, owner) then
                local damagetoent = damage
                local explosiveresist = ent.components.explosiveresist
                if explosiveresist then
                    damagetoent = damagetoent * (1 - explosiveresist:GetResistance())
                    explosiveresist:OnExplosiveDamage(damagetoent, owner)
                end
                ent.components.combat:GetAttacked(owner, damagetoent, nil, "soul")
                hitsomething = true
            end
        end
    end

    if hitsomething then
        inst.soul_spear_cooldown = TUNING.SKILLS.WORTOX.SOUL_SPEAR_HIT_COOLDOWN / SOUL_SPEAR_TICK_TIME
    end
end

local function SeekSoulStealer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local range_small = TUNING.WORTOX_SOULSTEALER_RANGE
    local range_large = range_small + TUNING.SKILLS.WORTOX.SOULSTEALER_RANGE_BONUS
    local rangesq_small = range_small * range_small
    local rangesq_large = range_large * range_large
    local soulthieves = {}
    local soulthiefreceiver = nil
    local hasthief = false
    for i, v in ipairs(AllPlayers) do
        if v:HasTag("soulstealer") and
            not (v.components.health:IsDead() or v:HasTag("playerghost")) and
            not (v.sg ~= nil and (v.sg:HasStateTag("nomorph") or v.sg:HasStateTag("silentmorph"))) and
            v.entity:IsVisible() then
            local distsq = v:GetDistanceSqToPoint(x, y, z)
            local rangesq = v.components.skilltreeupdater and v.components.skilltreeupdater:IsActivated("wortox_thief_1") and rangesq_large or rangesq_small
            if distsq < rangesq then
                hasthief = true
                if inst._soulsource == v then
                    soulthiefreceiver = v
                    break
                end
                table.insert(soulthieves, {thief = v, distsq = distsq,})
            end
        end
    end
    if hasthief then
        if soulthiefreceiver == nil then
            table.sort(soulthieves, ThiefSort)
            soulthiefreceiver = soulthieves[1].thief
        end
        local speed = TUNING.WORTOX_SOUL_PROJECTILE_SPEED
        local skilltreeupdater = soulthiefreceiver.components.skilltreeupdater
        if skilltreeupdater then
            if skilltreeupdater:IsActivated("wortox_thief_4") then
                inst.soul_control = true
            end
            if skilltreeupdater:IsActivated("wortox_thief_3") then
                inst.soul_spear_task = inst:DoPeriodicTask(SOUL_SPEAR_TICK_TIME, inst.SoulSpearTick, 0, soulthiefreceiver)
            end
        end
        if inst.soul_control then
            inst.components.projectile:SetSpeed(-speed)
            inst.components.projectile:SetHoming(false)
            inst:DoTaskInTime(TUNING.SKILLS.WORTOX.SOUL_PROJECTILE_REPEL_DURATION, RethrowProjectile, speed, soulthiefreceiver)
        else
            inst.components.projectile:SetSpeed(speed)
        end
        inst.components.projectile:Throw(inst, soulthiefreceiver, soulthiefreceiver)
    end
end

local function OnTimeout(inst)
    inst._timeouttask = nil
    if inst._seektask ~= nil then
        inst._seektask:Cancel()
        inst._seektask = nil
    end
    inst:ListenForEvent("animover", inst.Remove)
    inst.AnimState:PlayAnimation("idle_pst")
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)

    wortox_soul_common.DoHeal(inst)
end

local TINT = { r = 154 / 255, g = 23 / 255, b = 19 / 255 }

local function PushColour(inst, addval, multval)
    if inst.components.highlight == nil then
        inst.AnimState:SetHighlightColour(TINT.r * addval, TINT.g * addval, TINT.b * addval, 0)
        inst.AnimState:OverrideMultColour(multval, multval, multval, 1)
    else
        inst.AnimState:OverrideMultColour()
    end
end

local function PopColour(inst)
    if inst.components.highlight == nil then
        inst.AnimState:SetHighlightColour()
    end
    inst.AnimState:OverrideMultColour()
end

local function OnUpdateTargetTint(inst)--, dt)
    if inst._tinttarget:IsValid() then
		local curframe = inst.AnimState:GetCurrentAnimationFrame()
        if curframe < 15 then
            local k = curframe / 15
            k = k * k
            PushColour(inst._tinttarget, 1 - k, k)
        else
            inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateTargetTint)
            inst.OnRemoveEntity = nil
            PopColour(inst._tinttarget)
        end
    else
        inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateTargetTint)
        inst.OnRemoveEntity = nil
    end
end

local function OnRemoveEntity(inst)
    if inst._tinttarget:IsValid() then
        PopColour(inst._tinttarget)
    end
end

local function OnTargetDirty(inst)
    if inst._target:value() ~= nil and inst._tinttarget == nil then
        if inst.components.updatelooper == nil then
            inst:AddComponent("updatelooper")
        end
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateTargetTint)
        inst._tinttarget = inst._target:value()
        inst.OnRemoveEntity = OnRemoveEntity
    end
end

local function Setup(inst, target)
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    inst._target:set(target)
    if not TheNet:IsDedicated() then
        OnTargetDirty(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("wortox_soul_ball")
    inst.AnimState:SetBuild("wortox_soul_ball")
    inst.AnimState:PlayAnimation("idle_pre")
    inst.AnimState:SetScale(SCALE, SCALE)
    inst.AnimState:SetFinalOffset(3)

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    --projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst._target = net_entity(inst.GUID, "wortox_soul_spawn._target", "targetdirty")
    inst._hastail = net_bool(inst.GUID, "wortox_soul_spawn._hastail", "hastaildirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("targetdirty", OnTargetDirty)
        inst:ListenForEvent("hastaildirty", OnHasTailDirty)

        return inst
    end

    inst.SoulSpearTick = SoulSpearTick

    inst.AnimState:PushAnimation("idle_loop", true)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(0)

    inst:AddComponent("projectile")
    inst.components.projectile:SetHitDist(.5)
    inst.components.projectile:SetOnThrownFn(OnThrown)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)

    inst._seektask = inst:DoPeriodicTask(.5, SeekSoulStealer, 1)
    inst._timeouttask = inst:DoTaskInTime(TUNING.WORTOX_SOUL_TIMEOUT, OnTimeout)

    inst.persists = false
    inst.Setup = Setup

    return inst
end

return Prefab("wortox_soul_spawn", fn, assets, prefabs)
