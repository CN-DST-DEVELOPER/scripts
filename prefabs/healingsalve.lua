local assets = {
    Asset("ANIM", "anim/spider_gland_salve.zip"),
}

local assets_acid = {
    Asset("ANIM", "anim/healingsalve_acid.zip"),
}

local prefabs_acid = {
    "healingsalve_acidbuff",
}

local assets_fumarole = {
    Asset("ANIM", "anim/healingsalve_fumarole.zip"),
}

local prefabs_fumarole = {
    "healingsalve_fumarolebuff",
}

local function MakeHealingSalve(name, common_postinit, master_postinit, data, _assets, _prefabs)
    local bank = data ~= nil and data.bank or "spider_gland_salve"
    local build = data ~= nil and data.build or "spider_gland_salve"
    local anim = data ~= nil and data.anim or "idle"
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)

        MakeInventoryFloatable(inst, "small", 0.05, 0.95)

        if common_postinit ~= nil then
            common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("healer")
        inst.components.healer:SetHealthAmount(TUNING.HEALING_MED)

        MakeHauntableLaunch(inst)

        if master_postinit ~= nil then
            master_postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, _assets, _prefabs)
end

--------------------------------------------

local ACID_DATA =
{
    bank = "healingsalve_acid",
    build = "healingsalve_acid",
}

local function acid_OnHealFn(inst, target)
    target:AddDebuff("healingsalve_acidbuff", "healingsalve_acidbuff")
end

local function acid_common_postinit(inst)
    inst:AddTag("healerbuffs")
end

local function acid_master_postinit(inst)
    inst.components.healer:SetOnHealFn(acid_OnHealFn)
end

--------------------------------------------

local FUMAROLE_DATA =
{
    bank = "healingsalve_fumarole",
    build = "healingsalve_fumarole",
}

local function fumarole_OnHealFn(inst, target)
    target:AddDebuff("healingsalve_fumarolebuff", "healingsalve_fumarolebuff")
end

local function fumarole_common_postinit(inst)
    inst:AddTag("healerbuffs")
end

local function fumarole_master_postinit(inst)
    inst.components.healer:SetOnHealFn(fumarole_OnHealFn)
end

--------------------------------------------

local function buff_Expire(inst)
    if inst.components.debuff ~= nil then
        inst.components.debuff:Stop()
    end
end

local function buff_OnSave(inst, data)
    if inst.task ~= nil then
        data.remaining = GetTaskRemaining(inst.task)
    end
end

local function buff_OnLoad(inst, data)
    if data == nil then
        return
    end

    if data.remaining then
        if inst.task ~= nil then
            inst.task:Cancel()
            inst.task = nil
        end
        inst.task = inst:DoTaskInTime(data.remaining, buff_Expire)
    end
end

local function MakeHealingSalveBuff(name, data)
    local duration = data.duration
    local function buff_OnAttached(inst, target)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0)
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        if data.onattachedfn ~= nil then
            data.onattachedfn(inst, target)
        end
    end

    local function buff_OnDetached(inst, target)
        if data.ondetachedfn ~= nil then
            data.ondetachedfn(inst, target)
        end
        inst:Remove()
    end

    local function buff_OnExtended(inst, target)
        if inst.task ~= nil then
            inst.task:Cancel()
            inst.task = nil
        end
        inst.task = inst:DoTaskInTime(TUNING.HEALINGSALVE_ACIDBUFF_DURATION, buff_Expire)
        if data.onextendedfn ~= nil then
            data.onextendedfn(inst, target)
        end
    end

    local function bufffn()
        local inst = CreateEntity()

        if not TheWorld.ismastersim then
            --Not meant for client!
            inst:DoTaskInTime(0, inst.Remove)

            return inst
        end

        inst.entity:AddTransform()
        --[[Non-networked entity]]

        inst.entity:Hide()
        inst.persists = false

        inst:AddTag("CLASSIFIED")

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(buff_OnAttached)
        inst.components.debuff:SetDetachedFn(buff_OnDetached)
        inst.components.debuff:SetExtendedFn(buff_OnExtended)
        inst.components.debuff.keepondespawn = true

        buff_OnExtended(inst)

        inst.OnSave = buff_OnSave
        inst.OnLoad = buff_OnLoad

        return inst
    end

    return Prefab(name, bufffn)
end

--------------------------------------------

-- NOTES(JBK): Do not apply health over time for this item because of healerbuffs tag.
local function acidbuff_OnAttached(inst, target)
    target:AddTag("acidrainimmune")
end

local function acidbuff_OnDetached(inst, target)
    if target ~= nil and target:IsValid() then
        target:RemoveTag("acidrainimmune")

        if target.components.talker ~= nil and not IsEntityDead(target) then
            target.components.talker:Say(GetString(target, "ANNOUNCE_HEALINGSALVE_ACIDBUFF_DONE"))
        end
    end
end

local ACIDBUFF_DATA =
{
    duration = TUNING.HEALINGSALVE_ACIDBUFF_DURATION,
    onattachedfn = acidbuff_OnAttached,
    ondetachedfn = acidbuff_OnDetached,
}

--------------------------------------------

-- NOTES(JBK): Do not apply health over time for this item because of healerbuffs tag.
local function fumarolebuff_OnAttached(inst, target)
    if target.components.health ~= nil then
        target.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
    end
    if target.components.temperature ~= nil then
        target.components.temperature:SetInsulationModifier(SEASONS.SUMMER, inst, TUNING.INSULATION_SMALL)
    end
end

local function fumarolebuff_OnDetached(inst, target)
    if target ~= nil and target:IsValid() then
        -- Don't need to remove modifier since the entity will be deleted anyways, but just in case.
        if target.components.health ~= nil then
            target.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
        end

        if target.components.temperature ~= nil then
            target.components.temperature:RemoveInsulationModifier(SEASONS.SUMMER, inst)
        end

        if target.components.talker ~= nil and not IsEntityDead(target) then
            target.components.talker:Say(GetString(target, "ANNOUNCE_HEALINGSALVE_FUMAROLEBUFF_DONE"))
        end
    end
end

local FUMAROLEBUFF_DATA =
{
    duration = TUNING.HEALINGSALVE_FUMAROLEBUFF_DURATION,
    onattachedfn = fumarolebuff_OnAttached,
    ondetachedfn = fumarolebuff_OnDetached,
}

--------------------------------------------

return MakeHealingSalve("healingsalve", nil, nil, nil, assets),
    MakeHealingSalve("healingsalve_acid", acid_common_postinit, acid_master_postinit, ACID_DATA, assets_acid, prefabs_acid),
    MakeHealingSalve("healingsalve_fumarole", fumarole_common_postinit, fumarole_master_postinit, FUMAROLE_DATA, assets_fumarole, prefabs_fumarole),
    MakeHealingSalveBuff("healingsalve_acidbuff", ACIDBUFF_DATA),
    MakeHealingSalveBuff("healingsalve_fumarolebuff", FUMAROLEBUFF_DATA)