local wortox_soul_common = require("prefabs/wortox_soul_common")

local assets =
{
    Asset("ANIM", "anim/wortox_soul_ball.zip"),
    Asset("SCRIPT", "scripts/prefabs/wortox_soul_common.lua"),
}

local prefabs =
{
    "wortox_soul_heal_fx",
}

local SCALE = .8
local SCALE_SMALL = 0.4
local TAIL_SPEED_MIN = 4

local function topocket(inst)
    inst.persists = true
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = nil
    end
end

local function KillSoul_FromPocket_Bursted(inst)
    inst.soul_heal_mult = (inst.soul_heal_mult or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_3_MULT
    inst.soul_bursting = true
    inst.soulhealfinishing = true
    inst.AnimState:PlayAnimation("idle_small_pst")
    inst:ListenForEvent("animover", inst.Remove)
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    wortox_soul_common.DoHeal(inst)
end
local function KillSoul_FromPocket(inst)
    if inst.soul_doburst then
        inst._issmall:set(true)
        inst.AnimState:PlayAnimation("burst")
        inst.AnimState:PushAnimation("idle_small_loop", true)
        local delay = TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_3_DELAY
        if inst.soul_doburst_faster then
            delay = delay + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_4_DELAY
        end
        inst:DoTaskInTime(delay, KillSoul_FromPocket_Bursted)
    else
        inst.soulhealfinishing = true
        inst.AnimState:PlayAnimation("idle_pst")
        inst:ListenForEvent("animover", inst.Remove)
    end
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    wortox_soul_common.DoHeal(inst)
end

local function toground(inst)
    inst.persists = false
    if inst._task == nil then
        inst._task = inst:DoTaskInTime(TUNING.WORTOX_SOUL_HEAL_DELAY, KillSoul_FromPocket)
    end
    if inst.AnimState:IsCurrentAnimation("idle_loop") then
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
    end
end

local function MakeSmallVisual(inst)
    inst.persists = false
    if inst._task ~= nil then
        inst._task:Cancel()
        inst._task = nil
    end
    inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    inst.soulhealfinishing = true
    inst.AnimState:PlayAnimation("idle_small_pst")
    inst:ListenForEvent("animover", inst.Remove)
end

local SOUL_TAGS = { "soul" }
local function OnDropped(inst)
    if inst.components.stackable ~= nil and inst.components.stackable:IsStack() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local num = 10 - #TheSim:FindEntities(x, y, z, 4, SOUL_TAGS)
        if num > 0 then
            for i = 1, math.min(num, inst.components.stackable:StackSize()) do
                local soul = inst.components.stackable:Get()
                soul.Physics:Teleport(x, y, z)
                soul.components.inventoryitem:OnDropped(true)
            end
        end
    end
end

local function OnCharged(inst)
    inst:RemoveTag("nosouljar")
end

local function OnDischarged(inst)
    inst:AddTag("nosouljar")
end


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
    inst.AnimState:SetFinalOffset(3)

    inst:ListenForEvent("animover", inst.Remove)

    return inst
end

local function OnUpdateProjectileTail(inst, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    for tail, _ in pairs(inst._tails) do
        tail:ForceFacePoint(x, y, z)
    end
    local currentpos = inst:GetPosition()
    local dist = (currentpos - inst._soulpos):Length()
    local speed = dist / math.max(dt, 0.001)
    inst._soulpos = currentpos
    if inst.entity:IsVisible() and speed > TAIL_SPEED_MIN then
        local scale = inst._issmall:value() and SCALE_SMALL or SCALE
        local tail = CreateTail()
        tail.AnimState:SetScale(scale, scale)
        local rot = inst.Transform:GetRotation()
        tail.Transform:SetRotation(rot)
        rot = rot * DEGREES
        local offsangle = math.random() * TWOPI
        local offsradius = (math.random() * .2 + .2) * scale
        local hoffset = math.cos(offsangle) * offsradius
        local voffset = math.sin(offsangle) * offsradius
        if inst._issmall:value() then
            voffset = voffset + 1
        end
        tail.Transform:SetPosition(x + math.sin(rot) * hoffset, y + voffset, z + math.cos(rot) * hoffset)
        tail.Physics:SetMotorVel(speed * (.2 + math.random() * .3), 0, 0)
        inst._tails[tail] = true
        inst:ListenForEvent("onremove", function(tail) inst._tails[tail] = nil end, tail)
        tail:ListenForEvent("onremove", function(inst)
            tail.Transform:SetRotation(tail.Transform:GetRotation() + math.random() * 30 - 15)
        end, inst)
    end
    if not inst._hastail:value() and next(inst._tails) == nil then
        if inst.components.updatelooper then
            inst.components.updatelooper:RemoveOnUpdateFn(OnUpdateProjectileTail)
        end
    end
end

local function OnHasTailDirty(inst)
    if inst._hastail:value() then
        if inst._tails == nil then
            inst._soulpos = inst:GetPosition()
            inst._tails = {}
        end
        if inst.components.updatelooper == nil then
            inst:AddComponent("updatelooper")
        end
        inst.components.updatelooper:AddOnUpdateFn(OnUpdateProjectileTail)
    end
end

local function HideTail(inst)
    if inst._hastail:value() then
        inst.AnimState:Show("blob")
        inst._hastail:set(false)
        if not TheNet:IsDedicated() then
            OnHasTailDirty(inst)
        end
    end
end
local function ShowTail(inst)
    if not inst._hastail:value() then
        inst.AnimState:Hide("blob")
        inst._hastail:set(true)
        if not TheNet:IsDedicated() then
            OnHasTailDirty(inst)
        end
    end
end

local SOULPROTECTOR_TICK_TIME = 0.1
local function SoulProtectorTick(inst)
    local distsqmaxrange = TUNING.WORTOX_SOULHEAL_RANGE + (inst.soul_heal_range_modifier or 0)
    distsqmaxrange = distsqmaxrange * distsqmaxrange

    local x, y, z = inst.Transform:GetWorldPosition()

    local mosthurtplayer
    local mosthurtplayerdistsq

    if not inst.soulhealfinishing then
        local mosthurtplayerpercent
        for _, v in ipairs(AllPlayers) do
            if v.entity:IsVisible() and not IsEntityDeadOrGhost(v) and v.components.health and not v:HasTag("health_as_oldage") then -- Wanda tag.
                local dsq = v:GetDistanceSqToPoint(x, y, z)
                if dsq <= distsqmaxrange then
                    local percent = v.components.health:GetPercent()
                    if percent < 1 then
                        if not mosthurtplayerpercent or percent <= mosthurtplayerpercent then
                            mosthurtplayerdistsq = dsq
                            mosthurtplayerpercent = percent
                            mosthurtplayer = v
                        end
                    end
                end
            end
        end
    end
    if mosthurtplayer then
        local dist = math.sqrt(mosthurtplayerdistsq)
        local speed = inst.soul_follow_speed
        if dist < 4 then
            speed = math.min(dist, speed)
        end
        inst.Physics:SetMotorVel(speed, 0, 0)
        local px, py, pz = mosthurtplayer.Transform:GetWorldPosition()
        inst:ForceFacePoint(px, py, pz)
        if speed > TAIL_SPEED_MIN then
            ShowTail(inst)
        else
            HideTail(inst)
        end
    else
        inst.Physics:SetMotorVel(0, 0, 0)
        HideTail(inst)
    end
end
local function ModifyStats(inst, owner)
    local skilltreeupdater = owner.components.skilltreeupdater
    if skilltreeupdater then
        if skilltreeupdater:IsActivated("wortox_soulprotector_1") then
            inst.soul_heal_range_modifier = (inst.soul_heal_range_modifier or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_1_RANGE
        end
        if skilltreeupdater:IsActivated("wortox_soulprotector_2") then
            inst.soul_heal_range_modifier = (inst.soul_heal_range_modifier or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_2_RANGE
            inst.soul_follow_speed = (inst.soul_follow_speed or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_2_SPEED
            inst.soulprotector_task = inst:DoPeriodicTask(SOULPROTECTOR_TICK_TIME, inst.SoulProtectorTick, 0.3)
        end
        if skilltreeupdater:IsActivated("wortox_soulprotector_3") then
            inst.soul_doburst = true
        end
        if skilltreeupdater:IsActivated("wortox_soulprotector_4") then
            inst.soul_follow_speed = (inst.soul_follow_speed or 0) + TUNING.SKILLS.WORTOX.WORTOX_SOULPROTECTOR_4_SPEED
            inst.soul_doburst_faster = true
            inst.soul_heal_player_efficient = true
        end
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
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetScale(SCALE, SCALE)

    inst:AddTag("nosteal")
	inst:AddTag("sloweat")
    inst:AddTag("NOCLICK")

    --souleater (from soul component) added to pristine state for optimization
    inst:AddTag("soul")

    -- Tag rechargeable (from rechargeable component) added to pristine state for optimization.
    inst:AddTag("rechargeable")
    -- Optional tag to control if the item is not a "cooldown until" meter but a "bonus while" meter.
    inst:AddTag("rechargeable_bonus")
	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

    inst._hastail = net_bool(inst.GUID, "wortox_soul._hastail", "hastaildirty")
    inst._issmall = net_bool(inst.GUID, "wortox_soul._issmall")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("hastaildirty", OnHasTailDirty)
        return inst
    end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.canbepickedup = false
    inst.components.inventoryitem.canonlygoinpocketorpocketcontainers = true
    inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
    inst.components.stackable.forcedropsingle = true

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnChargedFn(OnCharged)
    inst.components.rechargeable:SetOnDischargedFn(OnDischarged)

    inst:AddComponent("inspectable")
    inst:AddComponent("soul")

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)
    inst._task = nil
    toground(inst)

    inst.ModifyStats = ModifyStats
    inst.MakeSmallVisual = MakeSmallVisual
    inst.SoulProtectorTick = SoulProtectorTick

    return inst
end

if TheSim then -- updateprefabs guard
    SetDesiredMaxTakeCountFunction("wortox_soul", function(player, inventory, container_item, container)
        local max_count = TUNING.WORTOX_MAX_SOULS -- NOTES(JBK): Keep this logic the same in counts in wortox. [WSCCF]
        if player and player.components.skilltreeupdater and player.components.skilltreeupdater:IsActivated("wortox_souljar_2") and player.replica.inventory then
            local souljars = 0
            for slot = 1, player.replica.inventory:GetNumSlots() do
                local item = player.replica.inventory:GetItemInSlot(slot)
                if item and item.prefab == "wortox_souljar" then
                    souljars = souljars + 1
                end
            end
            local activeitem = player.replica.inventory:GetActiveItem()
            if activeitem and activeitem.prefab == "wortox_souljar" then
                souljars = souljars + 1
            end
            max_count = max_count + souljars * TUNING.SKILLS.WORTOX.FILLED_SOULJAR_SOULCAP_INCREASE_PER
        end
        local has, count = inventory:Has("wortox_soul", 0, false)
        return math.max(max_count - count, 0)
    end)
end

return Prefab("wortox_soul", fn, assets, prefabs)
