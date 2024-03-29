local easing = require("easing")

DISAPPEAR_TIME = 2
DISAPPEAR_COLOR_MULT = 1.2

-------------------------------------------------------------------------------------------------

local function Configure(inst, data)
    if data.pos then
        inst.Transform:SetPosition(data.pos:Get())
    end

    if data.bank then
        inst.savedata.bank = data.bank

        inst.AnimState:SetBank(data.bank)
    end

    if data.build then
        inst.savedata.build = data.build

        inst.AnimState:SetBuild(data.build)
    end

    if data.scale then
        inst.savedata.scale = data.scale
        inst.Transform:SetScale(data.scale, data.scale, data.scale)
    end

    if data.anim and inst.animset[data.anim] then
        inst.savedata.anim = data.anim

        local animdata = inst.animset[data.anim]

        inst.AnimState:PlayAnimation(animdata.anim, true)

        local hidesymbols = animdata.hidesymbols
        local overridesymbol = animdata.overridesymbol
        local minimap = animdata.minimap
        local stump = animdata.stump

        if hidesymbols ~= nil then
            for i, symbol in ipairs(hidesymbols) do
                inst.AnimState:Hide(symbol)
            end
        end

        if overridesymbol ~= nil then
            inst.AnimState:OverrideSymbol(unpack(overridesymbol))
        end

        if minimap ~= nil then
            inst.MiniMapEntity:SetIcon(minimap)
        end

        if stump then
            RemovePhysicsColliders(inst)
            inst.components.workable:SetWorkAction(ACTIONS.DIG)
        end
    end

    if data.frame then
        inst.AnimState:SetFrame(data.frame)
    else
        inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
    end

    if data.multcolor then
        inst.AnimState:SetMultColour(unpack(data.multcolor))
    end

    if inst.onconfigure_fn ~= nil then
        inst.onconfigure_fn(inst)
    end
end

-------------------------------------------------------------------------------------------------

local function GetParentCurrentAnimation(inst, parent)
    local anim = inst.getanim_fn(parent)

    if not inst.animset[anim] then
        return
    end

    return anim
end

-------------------------------------------------------------------------------------------------

local function Disappear(inst)
    local ticktime = TheSim:GetTickTime()

    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:Enable(false)
    end

    inst.persists = false

    RemovePhysicsColliders(inst)

    local multcolor = inst.AnimState:GetMultColour()

    inst:StartThread(function()
        local ticks = 0

        while ticks * ticktime < DISAPPEAR_TIME do
            local n = ticks * ticktime / DISAPPEAR_TIME

            local alpha = easing.inQuad(1 - n, 0, 1, 1)
            local color = 1 - (n * DISAPPEAR_COLOR_MULT)

            local color = math.min(multcolor, color)

            inst.AnimState:SetErosionParams(0.2, 0.2, n)
            inst.AnimState:SetMultColour(color, color, color, alpha)

            if inst.children ~= nil then
                for _, child in inst.children do
                    if child.AnimState ~= nil then
                        child.AnimState:SetErosionParams(0.2, 0.2, n)
                        child.AnimState:SetMultColour(color, color, color, alpha)
                    end
                end
            end

            ticks = ticks + 1
            Yield()
        end

        inst:Remove()
    end)

    if inst.ondisappear_fn ~= nil then
        inst.ondisappear_fn(inst)
    end
end

local function SpawnDugWaxedPlant(inst)
    local plant = inst.components.lootdropper:SpawnLootPrefab("dug_"..inst.prefab)

    plant:CopySaveData(inst)

    inst:Remove()
end

local function OnWorked(inst)
    if inst.components.lootdropper ~= nil and Prefabs["dug_"..inst.prefab] ~= nil then
        inst:SpawnDugWaxedPlant()
    else
        inst:Disappear()
    end
end

-------------------------------------------------------------------------------------------------

local function GetDisplayNameFn(inst)
    return STRINGS.NAMES[inst.displayname]
end

-------------------------------------------------------------------------------------------------

local FADE_IN_TIME = 0.8
local FATE_TIME = 0.7
local FADE_OUT_TIME = 1.5

local DARK_MULTCOLOR = {0.2, 0.2, 0.2, 1}
local REGULAR_MULTCOLOR = {1, 1, 1, 1}

local function OnEndFade(inst)
    inst._multcolor = nil
    inst:RemoveComponent("colourtweener")
end

local function DoRevertMultColor(inst)
    inst.components.colourtweener:StartTween(inst._multcolor or REGULAR_MULTCOLOR, FADE_OUT_TIME, OnEndFade)
end

local function RevertMultColor(inst)
    inst:DoTaskInTime(FATE_TIME, DoRevertMultColor)
end

local function DoOnWaxedFade(inst)
    inst:AddComponent("colourtweener")
    inst._multcolor = {inst.AnimState:GetMultColour()}

    inst.components.colourtweener:StartTween(DARK_MULTCOLOR, FADE_IN_TIME, RevertMultColor)
end

local function SpawnWaxedFx(inst, pos)
    inst:DoOnWaxedFade()

    local fx = SpawnPrefab("beeswax_spray_fx")

    if fx ~= nil then
        fx.Transform:SetPosition(pos.x, 0, pos.z)
    end

    return fx -- Mods.
end

-------------------------------------------------------------------------------------------------

local function OnSave(inst, data)
    data.savedata = inst.savedata
end

local function OnLoad(inst, data)
    if data == nil or data.savedata == nil then
        return
    end

    inst:Configure(data.savedata)
end

-------------------------------------------------------------------------------------------------

--[[

Valid args:
    Required:
        - prefab (strings) - original plant prefab.
        - bank (hash)
        - build (string)
        - anim (string)
        - action (string) - workable action
        - animset (table) - anim data
        - getanim_fn (function) - Decides with animset entry will be chosen.

    Optional:
        - physics (table) - physics fn, rad, height, restitution
        - minimapicon (string) - without .png
        - nameoverride (string)
        - ondisappear_fn (function) - custom logic called at inst.Disappear
        - onconfigure_fn (function) - custom logic called at inst.Configure
        - multcolor (function) - arg in AnimState:SetMultColor(arg, arg, arg, 1)
        - common_postinit (function)
        - master_postinit (function)
]]

local function CreateWaxedPlant(data)
    local assets =
    {
        Asset("ANIM", "anim/"..data.build..".zip"),
    }

    local prefabs =
    {
        data.prefab,
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        if data.physics then
            local fn, rad, height, restitution = unpack(data.physics)

            fn(inst, rad, height, restitution)
        end

        if data.minimapicon then
            inst.MiniMapEntity:SetIcon(data.minimapicon..".png")
        end

        inst:AddTag("waxedplant")

        inst.AnimState:SetBank(data.bank)
        inst.AnimState:SetBuild(data.build)
        inst.AnimState:PlayAnimation(data.anim, true)

        MakeSnowCoveredPristine(inst)

        inst.plantprefab = data.prefab
        inst.scrapbook_proxy = data.prefab

        -- NOTES(DiogoW): Not using inst.nameoverride because we are using inspectable.nameoverride.
        inst.displayname = string.upper(data.nameoverride or data.prefab)
        inst.displaynamefn = GetDisplayNameFn

        if data.common_postinit then
            data.common_postinit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.savedata = {}
        inst.animset = data.animset
        inst.getanim_fn = data.getanim_fn
        inst.ondisappear_fn = data.ondisappear_fn
        inst.onconfigure_fn = data.onconfigure_fn

        inst.anim  = data.anim
        inst.build = data.build
        inst.bank  = data.bank

        if data.multcolor then
            local color = data.multcolor(inst)
            inst.AnimState:SetMultColour(color, color, color, 1)
        end

        inst:AddComponent("lootdropper")

        inst:AddComponent("inspectable")
        inst.components.inspectable:SetNameOverride("waxed_plant")

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS[data.action])
        inst.components.workable:SetWorkLeft(1)
        inst.components.workable:SetOnFinishCallback(OnWorked)

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        inst.Disappear = Disappear
        inst.SpawnDugWaxedPlant = SpawnDugWaxedPlant

        inst.Configure = Configure
        inst.SpawnWaxedFx = SpawnWaxedFx
        inst.DoOnWaxedFade = DoOnWaxedFade
        inst.GetParentCurrentAnimation = GetParentCurrentAnimation

        MakeSnowCovered(inst)
        MakeHauntable(inst)

        if data.master_postinit then
            data.master_postinit(inst)
        end

        return inst
    end

    return Prefab(data.prefab.."_waxed", fn, data.assets)
end

-------------------------------------------------------------------------------------------------

local function DugWaxedPlant_OnDeploy(inst, pt, deployer)
    local plant = SpawnPrefab(inst.plantprefab)

    if plant == nil then
        return
    end

    plant.Transform:SetPosition(pt:Get())

    plant:Configure(inst.savedata)

    inst:Remove()

    if deployer ~= nil and deployer.SoundEmitter ~= nil then
        deployer.SoundEmitter:PlaySound("dontstarve/common/plant")
    end
end

-------------------------------------------------------------------------------------------------

local function DugWaxedPlant_CopySaveData(inst, ent)
    inst.savedata = shallowcopy(ent.savedata)
end

local function DugWaxedPlant_OnSave(inst, data)
    data.savedata = inst.savedata
end

local function DugWaxedPlant_OnLoad(inst, data)
    inst.savedata = data ~= nil and data.savedata or inst.savedata
end

-------------------------------------------------------------------------------------------------

local function CreateDugWaxedPlant(data)
    local bank  = data.bank  or data.name
    local build = data.build or data.name

    local parentprefab = "dug_"..data.name

    local prefabs =
    {
        parentprefab,
    }

    local assets =
    {
        Asset("ANIM", "anim/"..bank..".zip"),
        Asset("INV_IMAGE", parentprefab)
    }

    if data.build ~= nil then
        table.insert(assets, Asset("ANIM", "anim/"..data.build..".zip"))
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("dropped")

        MakeInventoryFloatable(inst, unpack(data.floater or {}))

        inst:AddTag("waxedplant")

        inst.parentprefab = parentprefab
        inst.scrapbook_proxy = parentprefab

        inst.overridedeployplacername = parentprefab.."_placer"

        inst.plantprefab = data.name.."_waxed"

        -- NOTES(DiogoW): Not using inst.nameoverride because we are using inspectable.nameoverride.
        inst.displayname = string.upper(data.nameoverride or data.name)
        inst.displaynamefn = GetDisplayNameFn

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.savedata = {}

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = parentprefab

        -- NOTES(DiogoW): Being stackable won't let us save the plant's appearance.
        -- inst:AddComponent("stackable")
        -- inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

        inst:AddComponent("inspectable")
        inst.components.inspectable:SetNameOverride("waxed_plant")

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.LARGE_FUEL

        MakeHauntable(inst)

        inst:AddComponent("deployable")
        inst.components.deployable.ondeploy = DugWaxedPlant_OnDeploy
        inst.components.deployable:SetDeployMode(DEPLOYMODE.PLANT)

        if data.mediumspacing then
            inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.MEDIUM)
        end

        inst.OnSave = DugWaxedPlant_OnSave
        inst.OnLoad = DugWaxedPlant_OnLoad

        inst.CopySaveData = DugWaxedPlant_CopySaveData

        return inst
    end

    return Prefab(parentprefab.."_waxed", fn, assets, prefabs)
end

-------------------------------------------------------------------------------------------------

local function WaxPlant(plant, doer, waxitem)
    local prefab = plant.prefab.."_waxed"

    if not Prefabs[prefab] then
        return false
    end

    local waxed = SpawnPrefab(prefab)

    local bank  = plant.AnimState:GetBankHash()
    local build = plant.AnimState:GetBuild()
    local anim  = waxed:GetParentCurrentAnimation(plant)
    local scale = plant.Transform:GetScale() -- Note(DiogoW): This returns 3 values, but they are usually the same.

    if anim == nil then
        waxed:Remove()

        return false
    end

    local data = {
        pos   = plant:GetPosition(),
        frame = plant.AnimState:GetCurrentAnimationFrame(),
        anim  = anim, -- Saved
        bank  = waxed.bank ~= bank and bank or nil, -- Saved
        build = waxed.build ~= build and build or nil, -- Saved
        multcolor = {plant.AnimState:GetMultColour()},
        scale = scale ~= 1 and scale or nil,  -- Saved
    }

    waxed:Configure(data)
    waxed:SpawnWaxedFx(data.pos)

    plant:Remove()

    return true
end

return
        {
            CreateWaxedPlant    = CreateWaxedPlant,
            CreateDugWaxedPlant = CreateDugWaxedPlant,
            WaxPlant            = WaxPlant,
        }