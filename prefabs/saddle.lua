
local function OnDiscarded(inst)
    inst.components.finiteuses:Use()
end

local function OnUsedUp(inst)
    SpawnPrefab("ground_chunks_breaking").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

------------------------------------------------------------------------------------------------------------------

local BANK, SHADOW_SADDLE_BANK, IDLE_ANIM, BROKEN_ANIM = "saddlebasic", "saddle_shadow", "idle", "broken"

------------------------------------------------------------------------------------------------------------------

local function ShadowSaddle_OnBroken(inst)
    SpawnPrefab("slurper_respawn").Transform:SetPosition(inst.Transform:GetWorldPosition())

    if inst.components.saddler ~= nil then
        inst:RemoveComponent("saddler")
        inst.AnimState:PlayAnimation(BROKEN_ANIM)
        inst:AddTag("broken")
        inst.components.inspectable.nameoverride = "BROKEN_FORGEDITEM"
    end
end

local function ShadowSaddle_OnRepaired(inst)
    if inst.components.saddler == nil then
        inst:SetupSaddler()
        inst.AnimState:PlayAnimation(IDLE_ANIM, true)
        inst:RemoveTag("broken")
        inst.components.inspectable.nameoverride = nil
    end
end

------------------------------------------------------------------------------------------------------------------

local function ShadowSaddle_OnEquipped(inst, data)
    if inst.fx ~= nil then
        inst.fx:Remove()
    end

    inst.fx = SpawnPrefab("saddle_shadow_fx")
    inst.fx:SetOwner(data.owner)
end

local function ShadowSaddle_OnUnequipped(inst, data)
    if inst.fx ~= nil then
        inst.fx:Remove()
        inst.fx = nil
    end
end

------------------------------------------------------------------------------------------------------------------

local function CreateFxFollowFrame(i)
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()

    inst:AddTag("FX")

    inst.AnimState:SetBank("saddle_shadow")
    inst.AnimState:SetBuild("saddle_shadow")
    inst.AnimState:PlayAnimation("swap_loop_"..tostring(i), true)
    inst.AnimState:SetSymbolLightOverride("red", .5)
    inst.AnimState:SetLightOverride(.1)

    inst.AnimState:AddOverrideBuild("hat_voidcloth")

    inst:AddComponent("highlightchild")

    inst.persists = false

    return inst
end

local function ShadowSaddle_Fx_OnRemoveEntity(inst)
    for i, v in ipairs(inst.fx) do
        v:Remove()
    end

    if inst.footprint_pool ~= nil then
        for i, v in ipairs(inst.footprint_pool) do
            v:Remove()
        end

        inst.footprint_pool = nil
    end
end

local function ShadowSaddle_Fx_ColourChanged(inst, r, g, b, a)
    for i, v in ipairs(inst.fx) do
        v.AnimState:SetAddColour(r, g, b, a)
    end
end

local DIST_BETWEEN_FOOTPRINTS = 3.5

local function ShadowSaddle_Fx_OnUpdate(inst)
    if inst.owner == nil or not inst.owner:IsValid() then
        return
    end

    local moving = inst.owner:HasTag("moving")
    local dist = (inst.owner:GetPosition() - inst.prevfootprintpos):Length()

    if moving and dist >= DIST_BETWEEN_FOOTPRINTS then
        local currentrot = inst.owner.Transform:GetRotation() - 90
        local rotdiff = anglediff(inst.prevfootprintrot, currentrot)

        inst.prevfootprintrot = math.abs(rotdiff) > 135 and currentrot or (currentrot + (rotdiff * .3))

        inst.prevfootprintpos = inst.owner:GetPosition()

        local fx = table.remove(inst.footprint_pool)

        if fx == nil then
            fx = SpawnPrefab("saddle_shadow_footprint")
            fx:SetFXOwner(inst)
        end

        fx.Transform:SetPosition(inst.prevfootprintpos:Get())
        fx.Transform:SetRotation(inst.prevfootprintrot)

        fx:RestartFX()
    end
end

local function ShadowSaddle_Fx_SpawnFxForOwner(inst, owner)
    inst.owner = owner
    inst.prevfootprintpos = owner:GetPosition()
    inst.prevfootprintrot = owner.Transform:GetRotation() - 90

    if inst.fx == nil then
        inst.fx = {}
    end

    local frame

    for i = 1, 3 do
        local fx = inst.fx[i]
        if fx == nil or not fx:IsValid() then -- These get removed on the client when changing parenting from beefalo -> player and player -> beefalo.
            fx = CreateFxFollowFrame(i)
            inst.fx[i] = fx
        end
        frame = frame or math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
        fx.entity:SetParent(owner.entity)
        fx.Follower:FollowSymbol(owner.GUID, "swap_saddle", nil, nil, nil, true, nil, i - 1)
        fx.AnimState:SetFrame(frame)
        fx.components.highlightchild:SetOwner(owner)
    end

    inst.components.colouraddersync:SetColourChangedFn(ShadowSaddle_Fx_ColourChanged)
    inst.OnRemoveEntity = ShadowSaddle_Fx_OnRemoveEntity

    if owner:HasTag("player") then
        if inst.components.updatelooper == nil then
            inst.footprint_pool = {}

            inst:AddComponent("updatelooper")
            inst.components.updatelooper:AddOnUpdateFn(ShadowSaddle_Fx_OnUpdate)
        end
    else
        inst:RemoveComponent("updatelooper")

        if inst.footprint_pool ~= nil then
            for i, v in ipairs(inst.footprint_pool) do
                v:Remove()
            end
    
            inst.footprint_pool = nil
        end
    end
end

local function ShadowSaddle_Fx_SetOwner(inst, owner)
    if owner == inst._fxowner then
        return
    end

    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.fx)
    end

    inst._fxowner = owner

    inst.entity:SetParent(owner.entity)

    if owner.components.colouradder ~= nil then
        owner.components.colouradder:AttachChild(inst)
    end

    inst.ownerevent:push()

    -- Dedicated server does not need to spawn the local fx.
    if not TheNet:IsDedicated() then
        ShadowSaddle_Fx_SpawnFxForOwner(inst, owner)
    end
end

local function ShadowSaddle_Fx_OnOwnerDirty(inst)
    local owner = inst.entity:GetParent()

    if owner ~= nil then
        ShadowSaddle_Fx_SpawnFxForOwner(inst, owner)
    end
end

local function ShadowSaddleFx()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst:AddComponent("colouraddersync")

    inst.ownerevent = net_event(inst.GUID, "saddle_shadow_fx.ownerevent")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("saddle_shadow_fx.ownerevent", ShadowSaddle_Fx_OnOwnerDirty)

        return inst
    end

    inst.SetOwner = ShadowSaddle_Fx_SetOwner
    inst.persists = false

    return inst
end

------------------------------------------------------------------------------------------------------------------

local function SetupSaddler(inst)
    local build = inst.AnimState:GetBuild()

    inst:AddComponent("saddler")
    inst.components.saddler:SetBonusDamage(inst._data.bonusdamage)
    inst.components.saddler:SetBonusSpeedMult(inst._data.speedmult)
    inst.components.saddler:SetSwaps(build, "swap_saddle")
    inst.components.saddler:SetDiscardedCallback(OnDiscarded)

    if inst._data.absorption ~= nil then
        inst.components.saddler:SetAbsorption(inst._data.absorption)
    end
end

local function MakeSaddle(name, data)
    local assets = {
        Asset("ANIM", "anim/"..name..".zip"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(BANK)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation(IDLE_ANIM, data.forgerepairable)

        inst.mounted_foleysound = "dontstarve/beefalo/saddle/"..data.foley

        MakeInventoryFloatable(inst, data.floater[1], data.floater[2], data.floater[3])

        if data.extra_tags ~= nil then
            for _, tag in ipairs(data.extra_tags) do
                inst:AddTag(tag)
            end
        end

        if data.commoninit ~= nil then
            data.commoninit(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst._data = data

        inst.SetupSaddler = SetupSaddler

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:SetupSaddler()

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(data.uses)
        inst.components.finiteuses:SetUses(data.uses)

        if not data.forgerepairable then
            inst.components.finiteuses:SetOnFinished(OnUsedUp)
        end

        MakeHauntableLaunch(inst)

        if data.postinit ~= nil then
            data.postinit(inst)
        end

        return inst
    end

    return Prefab(name, fn, assets, data.prefabs)
end

local data = {
    basic = {
        bonusdamage = TUNING.SADDLE_BASIC_BONUS_DAMAGE,
        foley = "regular_foley",
        uses = TUNING.SADDLE_BASIC_USES,
        speedmult = TUNING.SADDLE_BASIC_SPEEDMULT,
        floater = {"med", 0.1, 1.0},
    },
    war = {
        bonusdamage = TUNING.SADDLE_WAR_BONUS_DAMAGE,
        foley = "war_foley",
        uses = TUNING.SADDLE_WAR_USES,
        speedmult = TUNING.SADDLE_WAR_SPEEDMULT,
        floater = {"small", 0.1, 0.7},
        extra_tags = {"combatmount"},
    },
    race = {
        bonusdamage = TUNING.SADDLE_RACE_BONUS_DAMAGE,
        foley = "race_foley",
        uses = TUNING.SADDLE_RACE_USES,
        speedmult = TUNING.SADDLE_RACE_SPEEDMULT,
        floater = {"large", 0.05, 0.68},
        postinit = function(inst)
            inst.scrapbook_animoffsetbgy = 20
        end
    },
    wathgrithr = {
        bonusdamage = TUNING.SADDLE_WATHGRITHR_BONUS_DAMAGE,
        foley = "wigfrid_foley",
        uses = TUNING.SADDLE_WATHGRITHR_USES,
        speedmult = TUNING.SADDLE_WATHGRITHR_SPEEDMULT,
        absorption = TUNING.SADDLE_WATHGRITHR_ABSORPTION,
        floater = {"med", 0.1, 1.2},
        extra_tags = {"combatmount"},
        postinit = function(inst)
            inst.scrapbook_scale = 0.7
            inst.scrapbook_animoffsety = -50
            inst.scrapbook_animoffsetbgy = 55
        end
    },

    shadow = {
        bonusdamage = TUNING.SADDLE_SHADOW_BONUS_DAMAGE,
        foley = "shadow_foley",
        uses = TUNING.SADDLE_SHADOW_USES,
        speedmult = TUNING.SADDLE_SHADOW_SPEEDMULT,
        absorption = TUNING.SADDLE_SHADOW_ABSORPTION,
        floater = {"med", 0.05, {.8, .6, .8}},
        extra_tags = {"combatmount", "show_broken_ui"},
        prefabs = {"saddle_shadow_fx", "saddle_shadow_footprint"},
        forgerepairable = true,
        commoninit = function(inst)
            inst.AnimState:SetBank(SHADOW_SADDLE_BANK)

            inst.AnimState:SetSymbolLightOverride("red", .5)
            inst.AnimState:SetLightOverride(.1)

            inst.AnimState:AddOverrideBuild("hat_voidcloth")
        end,
        postinit = function(inst)
            inst.OnEquipped   = ShadowSaddle_OnEquipped
            inst.OnUnequipped = ShadowSaddle_OnUnequipped

            inst:AddComponent("planardamage")
            inst.components.planardamage:SetBaseDamage(TUNING.SADDLE_SHADOW_PLANAR_DAMAGE)

            inst:AddComponent("planardefense")
            inst.components.planardefense:SetBaseDefense(TUNING.SADDLE_SHADOW_PLANAR_DEF)

            inst:AddComponent("damagetypebonus")
            inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.SADDLE_SHADOW_VS_LUNAR_BONUS)

            inst:AddComponent("damagetyperesist")
            inst.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.SADDLE_SHADOW_SHADOW_RESIST)

            inst:ListenForEvent("equipped",   inst.OnEquipped  )
            inst:ListenForEvent("unequipped", inst.OnUnequipped)

            MakeForgeRepairable(inst, FORGEMATERIALS.VOIDCLOTH, ShadowSaddle_OnBroken, ShadowSaddle_OnRepaired)
        end
    },
}

return
        MakeSaddle("saddle_basic",      data.basic      ),
        MakeSaddle("saddle_war",        data.war        ),
        MakeSaddle("saddle_race",       data.race       ),
        MakeSaddle("saddle_wathgrithr", data.wathgrithr ),
        MakeSaddle("saddle_shadow",     data.shadow     ),
            Prefab("saddle_shadow_fx",  ShadowSaddleFx  )
