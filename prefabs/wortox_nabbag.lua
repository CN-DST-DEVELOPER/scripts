local assets = {
    Asset("ANIM", "anim/wortox_nabbag.zip"),
    Asset("ANIM", "anim/swap_wortox_nabbag.zip"),
    Asset("INV_IMAGE", "wortox_nabbag_medium"),
    Asset("INV_IMAGE", "wortox_nabbag_full"),
}
local prefabs = {
    "wortox_nabbag_body",
}
local prefabsbody = {
    "wortox_nabbag_body_fx",
    "wortox_nabbag_body_soulfx",
}

local BUCKET_NAMES = {
    "_empty",
    "_medium",
    "_full",
}
local BUCKET_SIZE = #BUCKET_NAMES

local function UpdateStats(inst, percent, souls)
    -- Make the sizes into buckets.
    local bucket = math.clamp(math.ceil(percent * BUCKET_SIZE), 1, BUCKET_SIZE)
    local old_size = inst.nabbag_size
    inst.nabbag_size = BUCKET_NAMES[bucket]
    -- Scale percent to be percent of bucket.
    percent = (bucket - 1) / (BUCKET_SIZE - 1)

    local vfx_level = 0
    local owner = inst.components.inventoryitem.owner
    if inst.components.weapon then
        local maxdamage = TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MAX
        local mindamage = TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MIN
        local damage = (maxdamage - mindamage) * percent + mindamage
        if owner and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("wortox_souljar_3") then
            local souls_max = TUNING.SKILLS.WORTOX.SOUL_DAMAGE_MAX_SOULS
            local souls_clamped = math.min(souls, souls_max)
            if souls_clamped == souls_max then -- NOTES(JBK): This is done like this to keep floating point precision out of the equation.
                vfx_level = 3
            elseif souls_clamped >= souls_max * 0.50 then
                vfx_level = 2
            elseif souls_clamped >= souls_max * 0.25 then
                vfx_level = 1
            end
            local damage_percent = souls_clamped / souls_max
            damage = damage * (1 + (TUNING.SKILLS.WORTOX.SOUL_DAMAGE_NABBAG_BONUS_MULT - 1) * damage_percent)
        end
        inst.components.weapon:SetDamage(damage)
        inst.components.weapon.attackwearmultipliers:SetModifier(inst, percent)
    end

    if inst.wortox_nabbag_body ~= nil then
        inst.wortox_nabbag_body.bodysize_netvar:set(bucket - 1)
        inst.wortox_nabbag_body.bodyvfx_souls:set(vfx_level)
        inst.wortox_nabbag_body:UpdateBodySize()
        if inst.wortox_nabbag_body.hiding then
            if owner then
                owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
            end
        end
    end
    if inst.nabbag_size == "_empty" then
        inst.components.inventoryitem:ChangeImageName(nil) -- Default image name is the prefab name itself as a network optimization.
    else
        inst.components.inventoryitem:ChangeImageName("wortox_nabbag" .. inst.nabbag_size)
    end
end

local function OnInventoryStateChanged_Internal(inst, owner)
    if owner.components.inventory == nil then
        inst:UpdateStats(0, 0)
        return
    end

    local souls = 0
    local count = 0
    owner.components.inventory:ForEachItemSlot(function(item)
        count = count + 1
        if item.prefab == "wortox_soul" then
            souls = souls + (item.components.stackable and item.components.stackable:StackSize() or 1)
        elseif item.prefab == "wortox_souljar" then
            souls = souls + item.soulcount
        end
    end)
    local activeitem = owner.components.inventory:GetActiveItem()
    if activeitem then
        if activeitem.prefab == "wortox_soul" then
            souls = souls + (activeitem.components.stackable and activeitem.components.stackable:StackSize() or 1)
        elseif activeitem.prefab == "wortox_souljar" then
            souls = souls + activeitem.soulcount
        end
    end
    local maxslots = owner.components.inventory:GetNumSlots()
    local percent = maxslots == 0 and 0 or count / maxslots
    inst:UpdateStats(percent, souls)
end

local function ToggleOverrideSymbols(inst, owner)
    if owner.sg == nil or (owner.sg:HasStateTag("nodangle")
            or (owner.components.rider ~= nil and owner.components.rider:IsRiding()
                and not owner.sg:HasStateTag("forcedangle"))) then
        owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
        inst.wortox_nabbag_body.hiding = true
        inst.wortox_nabbag_body:Hide()
    else
        owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag_rope")
        inst.wortox_nabbag_body.hiding = nil
        inst.wortox_nabbag_body:Show()
    end
end
local function OnRemove_Body(wortox_nabbag_body)
    wortox_nabbag_body.wortox_nabbag.wortox_nabbag_body = nil
end
local function OnEquip(inst, owner)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    if inst.wortox_nabbag_body ~= nil then
        inst.wortox_nabbag_body:Remove()
    end
    inst.wortox_nabbag_body = SpawnPrefab("wortox_nabbag_body")
    inst.wortox_nabbag_body.wortox_nabbag = inst
    inst:ListenForEvent("onremove", OnRemove_Body, inst.wortox_nabbag_body)

    inst.wortox_nabbag_body.entity:SetParent(owner.entity)
    inst.wortox_nabbag_body:ListenForEvent("newstate", function(owner, data)
        ToggleOverrideSymbols(inst, owner)
    end, owner)

    ToggleOverrideSymbols(inst, owner)

    inst:ListenForEvent("itemget", inst.OnInventoryStateChanged, owner)
    inst:ListenForEvent("itemlose", inst.OnInventoryStateChanged, owner)
    inst:ListenForEvent("stacksizechange", inst.OnInventoryStateChanged, owner)

    inst.OnInventoryStateChanged(owner)
end

local function OnUnequip(inst, owner)
    if inst.wortox_nabbag_body ~= nil then
        if inst.wortox_nabbag_body.entity:IsVisible() then
            -- For animating when the item is being put away.
            owner.AnimState:OverrideSymbol("swap_object", "swap_wortox_nabbag", "swap_wortox_nabbag" .. inst.nabbag_size)
        end
        inst.wortox_nabbag_body:Remove()
    end
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    inst:RemoveEventCallback("itemget", inst.OnInventoryStateChanged, owner)
    inst:RemoveEventCallback("itemlose", inst.OnInventoryStateChanged, owner)
    inst:RemoveEventCallback("stacksizechange", inst.OnInventoryStateChanged, owner)

    inst:UpdateStats(0, 0)
end

local function DoLoadCheckForPlayers(inst)
    if inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.equippable and inst.components.equippable:IsEquipped() then
        inst.OnInventoryStateChanged(inst.components.inventoryitem.owner)
    end
end

local function OnUsesFinished(inst)
    if inst.components.inventoryitem.owner ~= nil then
        inst.components.inventoryitem.owner:PushEvent("toolbroke", { tool = inst })
    end

    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wortox_nabbag")
    inst.AnimState:SetBuild("wortox_nabbag")
    inst.AnimState:PlayAnimation("idle_empty")

    --nabbag (from nabbag component) added to pristine state for optimization
    inst:AddTag("nabbag")
    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    local swap_data = {sym_build = "swap_wortox_nabbag_empty"}
    MakeInventoryFloatable(inst, "small", 0.1, 1, false, -14.5, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("nabbag")

    local weapon = inst:AddComponent("weapon")
    weapon:SetDamage(TUNING.SKILLS.WORTOX.NABBAG_DAMAGE_MIN)
    weapon.attackwearmultipliers:SetModifier(inst, 0)

    local tool = inst:AddComponent("tool")
    tool:SetAction(ACTIONS.NET)

    local maxuses = TUNING.SKILLS.WORTOX.NABBAG_USES
    local finiteuses = inst:AddComponent("finiteuses")
    finiteuses:SetMaxUses(maxuses)
    finiteuses:SetUses(maxuses)
    finiteuses:SetOnFinished(OnUsesFinished)
    finiteuses:SetConsumption(ACTIONS.NET, maxuses / TUNING.SKILLS.WORTOX.NABBAG_USES_AS_BUGNET)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    local equippable = inst:AddComponent("equippable")
    equippable:SetOnEquip(OnEquip)
    equippable:SetOnUnequip(OnUnequip)
    equippable.restrictedtag = "nabbaguser"

    local fuel = inst:AddComponent("fuel")
    fuel.fuelvalue = TUNING.SMALL_FUEL

    MakeHauntableLaunch(inst)

    inst.nabbag_size = "_empty"
    inst.OnInventoryStateChanged = function(owner)
        OnInventoryStateChanged_Internal(inst, owner)
    end
    inst.UpdateStats = UpdateStats

    inst:DoTaskInTime(0, DoLoadCheckForPlayers) -- Delay for player load unload load cycle.

    return inst
end


local function GetBodySize(inst)
    return BUCKET_NAMES[inst.bodysize_netvar:value() + 1] or "_empty"
end

local function OnSizeDirty_body(inst)
    local bodysize_new = GetBodySize(inst)
    if inst.bodyfx and inst.bodyfx:IsValid() then
        local currentframe = inst.bodyfx.AnimState:GetCurrentAnimationFrame() - 1
        if inst.bodyfx.AnimState:IsCurrentAnimation("idle_body" .. inst.bodysize_current) then
            inst.bodyfx.AnimState:PlayAnimation("idle_body" .. bodysize_new, true)
        elseif inst.bodyfx.AnimState:IsCurrentAnimation("loop_swing" .. inst.bodysize_current) then
            inst.bodyfx.AnimState:PlayAnimation("loop_swing" .. bodysize_new, true)
        elseif inst.bodyfx.AnimState:IsCurrentAnimation("pst_swing" .. inst.bodysize_current) then
            inst.bodyfx.AnimState:PlayAnimation("pst_swing" .. bodysize_new)
            inst.bodyfx.AnimState:PushAnimation("idle_body" .. bodysize_new, true)
        elseif inst.bodyfx.AnimState:IsCurrentAnimation("attack" .. inst.bodysize_current) then
            inst.bodyfx.AnimState:PlayAnimation("attack" .. bodysize_new)
            inst.bodyfx.AnimState:PushAnimation("idle_body" .. bodysize_new, true)
        end
        inst.bodyfx.AnimState:SetFrame(currentframe)
    end
    inst.bodysize_current = bodysize_new
end

local function OnUpdate_body(inst)--, dt)
    local parent = inst.entity:GetParent()
    if parent then
        local owner = inst.entity:GetParent()
        if inst.bodyfx == nil or not inst.bodyfx:IsValid() then
            inst.bodyfx = SpawnPrefab("wortox_nabbag_body_fx")
            inst.bodyfx.entity:SetParent(inst.entity)
            inst.bodyfx.Follower:FollowSymbol(owner.GUID, "swap_object", 54, -182, 0, nil, false)
            local sizename = GetBodySize(inst)
            inst.bodyfx.AnimState:PlayAnimation("idle_body" .. sizename, true)
            inst.bodyfx.vfx = SpawnPrefab("wortox_nabbag_body_soulfx")
            inst.bodyfx.vfx.entity:SetParent(inst.bodyfx.entity)
        end

        local moving, nopredict, attacking
        if owner then
            if owner.sg then
                moving = owner.sg:HasStateTag("moving")
            else
                moving = owner:HasTag("moving")
            end
            attacking = owner.AnimState:IsCurrentAnimation("atk")
            if moving then
                nopredict = false
            else
                if TheWorld.ismastersim and owner.sg then
                    nopredict = owner.sg:HasStateTag("nopredict") or owner.sg:HasStateTag("pausepredict")
                else
                    nopredict = owner:HasTag("nopredict") or owner:HasTag("pausepredict") or (owner.player_classified and owner.player_classified.pausepredictionframes:value() > 0)
                end
            end

            if attacking and not inst.wasattacking then
                local sizename = GetBodySize(inst)
                inst.bodyfx.AnimState:PlayAnimation("attack" .. sizename)
                inst.bodyfx.AnimState:PushAnimation("idle_body" .. sizename, true)
            elseif moving and not inst.wasmoving then
                local sizename = GetBodySize(inst)
                inst.bodyfx.AnimState:PlayAnimation("loop_swing" .. sizename, true)
            elseif (inst.wasmoving and not moving) --stopped walking
                or (nopredict and not inst.wasnopredict) --hit?
            then
                local sizename = GetBodySize(inst)
                inst.bodyfx.AnimState:PlayAnimation("pst_swing" .. sizename)
                inst.bodyfx.AnimState:PushAnimation("idle_body" .. sizename, true)
            end
        end

        inst.wasmoving = moving
        inst.wasnopredict = nopredict
        inst.wasattacking = attacking
    end
end

local function bodyfxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("wortox_nabbag")
    inst.AnimState:SetBuild("wortox_nabbag")
    inst.AnimState:PlayAnimation("idle_body_empty", true)
    inst.AnimState:SetFinalOffset(1)

    inst.entity:SetCanSleep(false)
    inst.persists = false

    return inst
end

local function UpdateBodySize(inst)
    if inst.bodyfx and inst.bodyfx:IsValid() then
        OnSizeDirty_body(inst)
    end
end

local function bodyfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst.bodyvfx_souls = net_tinybyte(inst.GUID, "wortox_nabbag_body.souls")
    inst.bodysize_netvar = net_tinybyte(inst.GUID, "wortox_nabbag_body.size", "sizedirty")
    inst.bodysize_current = "_empty"
    inst.UpdateBodySize = UpdateBodySize

    inst:AddTag("FX")

    if not TheNet:IsDedicated() then
        inst.wasmoving = false
        inst.wasnopredict = false
        inst.wasattacking = false
        local updatelooper = inst:AddComponent("updatelooper")
        updatelooper:AddOnUpdateFn(OnUpdate_body)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("sizedirty", OnSizeDirty_body)
        return inst
    end

    inst.persists = false

    return inst
end

local TEXTURE_bodysoulfx = "fx/soul.tex"
local SHADER_bodysoulfx = "shaders/vfx_particle.ksh"
local COLOUR_ENVELOPE_NAME_bodysoulfx = "colourenvelope_bodysoulfx"
local SCALE_ENVELOPE_NAME_bodysoulfx = "scaleenvelope_bodysoulfx"

local bodysoulfx_assets = {
    Asset("IMAGE", TEXTURE_bodysoulfx),
    Asset("SHADER", SHADER_bodysoulfx),
}

local function InitEnvelope_bodysoulfx()
    local function IntColour(r, g, b, a)
        return { r / 255, g / 255, b / 255, a / 255 }
    end

    EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME_bodysoulfx,
        {
            { 0, IntColour(255, 255, 255, 225) },
            { 1, IntColour(255, 255, 255, 0) },
        }
    )

    local max_scale = 0.4
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_bodysoulfx,
        {
            { 0,    { max_scale, max_scale } },
            { 1,    { max_scale * .5, max_scale * .5 } },
        }
    )

    InitEnvelope_bodysoulfx = nil
end

local MAX_LIFETIME_bodysoulfx = 1.0
local function soulecho_buff_fx_emit(effect, sphere_emitter, direction)
    local px, py, pz = sphere_emitter()
    local vx, vy, vz = px * 0.02, 0.1 + py * 0.01, pz * 0.02

    local uv_offset = math.random(0, 9) / 10

    effect:AddParticleUV(
        0,
        MAX_LIFETIME_bodysoulfx, -- lifetime
        0, 0, 0, -- position
        vx + direction.x * 0.05, vy, vz + direction.z * 0.05, -- velocity
        uv_offset, 0 -- uv offset
    )
end

local SOUL_EMIT_RATE = {
    [0] = 0,
    [1] = 0.2,
    [2] = 0.6,
    [3] = 1,
}

local function bodysoulfxfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.entity:SetPristine()

    inst.persists = false

    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return inst
    elseif InitEnvelope_bodysoulfx ~= nil then
        InitEnvelope_bodysoulfx()
    end

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(1)

    effect:SetRenderResources(0, TEXTURE_bodysoulfx, SHADER_bodysoulfx)
    effect:SetUVFrameSize(0, 1/10, 1)
    effect:SetMaxNumParticles(0, 200)
    effect:SetMaxLifetime(0, MAX_LIFETIME_bodysoulfx)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_bodysoulfx)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_bodysoulfx)
    effect:SetBlendMode(0, BLENDMODE.Premultiplied)
    effect:EnableBloomPass(0, true)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)

    effect:SetAcceleration(0, 0, 0, 0)
    effect:SetDragCoefficient(0, 0.1)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()
    local sphere_emitter = CreateSphereEmitter(.25)
    local num_to_emit = 0
    EmitterManager:AddEmitter(inst, nil, function()
        local parent = inst.entity:GetParent() -- Bag visual
        if parent then
            local cur_pos = parent:GetPosition()
            parent = parent.entity:GetParent() -- Bag networked entity.
            if parent then
                if inst.last_pos == nil then
                    inst.last_pos = cur_pos
                end
                local dist_moved = cur_pos - inst.last_pos
                dist_moved:Normalize() -- Convert to direction vector.
                local per_tick = (SOUL_EMIT_RATE[parent.bodyvfx_souls:value()] or 0) * tick_time
                num_to_emit = num_to_emit + per_tick
                while num_to_emit > 0 do
                    soulecho_buff_fx_emit(effect, sphere_emitter, dist_moved)
                    num_to_emit = num_to_emit - 1
                end
            end
            inst.last_pos = cur_pos
        end
    end)

    return inst
end

return Prefab("wortox_nabbag", fn, assets, prefabs),
    Prefab("wortox_nabbag_body", bodyfn, nil, prefabsbody),
    Prefab("wortox_nabbag_body_fx", bodyfxfn, assets),
    Prefab("wortox_nabbag_body_soulfx", bodysoulfxfn, bodysoulfx_assets)