local assets =
{
    Asset("ANIM", "anim/gravestones.zip"),
    Asset("MINIMAP_IMAGE", "gravestones"),
    Asset("INV_IMAGE", "dug_gravestone"),
    Asset("INV_IMAGE", "dug_gravestone2"),
    Asset("INV_IMAGE", "dug_gravestone3"),
    Asset("INV_IMAGE", "dug_gravestone4"),
}

local prefabs =
{
    "dug_gravestone",
    "dug_gravestone_placer",
    "mound",
    "smallghost",
}

local DECORATED_GRAVESTONE_EVILFLOWER_TIME = (TUNING.WENDYSKILL_GRAVESTONE_DECORATETIME / TUNING.WENDYSKILL_GRAVESTONE_EVILFLOWERCOUNT)

-- Ghosts on a quest (following someone) shouldn't block other ghost spawns!
local CANTHAVE_GHOST_TAGS = {"questing"}
local MUSTHAVE_GHOST_TAGS = {"ghostkid"}
local function on_day_change(inst)
    if #AllPlayers > 0 and (not inst.ghost or not inst.ghost:IsValid()) then
        local ghost_spawn_chance = TUNING.GHOST_GRAVESTONE_CHANCE
        for _, v in ipairs(AllPlayers) do
            if v:HasTag("ghostlyfriend") then
                ghost_spawn_chance = ghost_spawn_chance + TUNING.GHOST_GRAVESTONE_CHANCE

                if v.components.skilltreeupdater and v.components.skilltreeupdater:IsActivated("wendy_smallghost_1") then
                    ghost_spawn_chance = ghost_spawn_chance + TUNING.WENDYSKILL_SMALLGHOST_EXTRACHANCE
                end
            end
        end

        if math.random() < ghost_spawn_chance then
            local gx, gy, gz = inst.Transform:GetWorldPosition()
            local nearby_ghosts = TheSim:FindEntities(gx, gy, gz, TUNING.UNIQUE_SMALLGHOST_DISTANCE, MUSTHAVE_GHOST_TAGS, CANTHAVE_GHOST_TAGS)
            if #nearby_ghosts == 0 then
                inst.ghost = SpawnPrefab("smallghost")
                inst.ghost.Transform:SetPosition(gx + 0.3, gy, gz + 0.3)
                inst.ghost:LinkToHome(inst)
            end
        end
    end
end

local function OnHaunt(inst)
    if not inst.setepitaph and #STRINGS.EPITAPHS > 1 then
        --change epitaph (if not a set custom epitaph)
        --guarantee it's not the same as b4!
        local oldepitaph = inst.components.inspectable.description
        inst._epitaph_index = math.random(#STRINGS.EPITAPHS - 1)
        local newepitaph = STRINGS.EPITAPHS[inst._epitaph_index]
        if newepitaph == oldepitaph then
            newepitaph = STRINGS.EPITAPHS[#STRINGS.EPITAPHS]
        end
        inst.components.inspectable:SetDescription(newepitaph)
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_SMALL
    else
        inst.components.hauntable.hauntvalue = TUNING.HAUNT_TINY
    end
    return true
end

-- Dig Up
local function OnDugUp(inst, tool, worker)
    SpawnPrefab("attune_out_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())

    inst:RemoveComponent("gravediggable")

    inst.AnimState:PlayAnimation("grave"..inst.random_stone_choice.."_slide")

    local animlength = inst.AnimState:GetCurrentAnimationLength()

    inst.persists = false
    inst:DoTaskInTime(animlength, inst.Remove)

    if inst.mound ~= nil then
        ErodeAway(inst.mound, animlength)
    end

    return true
end

-- Upgrade (decorate)
local FLOWER_TAG = {"flower"}
local FLOWER_SPAWN_RADIUS = 1.5
local function try_evil_flower(inst)
    if TheWorld.state.iswinter then return end

    local ix, iy, iz = inst.Transform:GetWorldPosition()
    if TheSim:CountEntities(ix, iy, iz, 2 * FLOWER_SPAWN_RADIUS, FLOWER_TAG) < TUNING.WENDYSKILL_GRAVESTONE_EVILFLOWERCOUNT then
        local random_angle = PI2 * math.random()
        ix = ix + (FLOWER_SPAWN_RADIUS * math.cos(random_angle))
        iz = iz - (FLOWER_SPAWN_RADIUS * math.sin(random_angle))

        local evil_flower = SpawnPrefab("flower_evil")
        evil_flower.Transform:SetPosition(ix, iy, iz)
        SpawnPrefab("attune_out_fx").Transform:SetPosition(ix, iy, iz)
    end
end

local function initiate_flower_state(inst)
    inst.AnimState:Show("flower")

    -- We call this when loading, and our onload happens after the timer component,
    -- so we might have loaded a more correct one. It knows how to handle constructor-started
    -- timers, but not onload-started ones, sadly.
    if not inst.components.timer:TimerExists("petal_decay") then
        -- Currently just matching the perish rate of petals.
        inst.components.timer:StartTimer("petal_decay", TUNING.PERISH_FAST)
    end

    if not inst.components.timer:TimerExists("try_evil_flower") then
        inst.components.timer:StartTimer(
            "try_evil_flower", DECORATED_GRAVESTONE_EVILFLOWER_TIME * (1 + 0.5 * math.random())
        )
    end

    TheWorld.components.decoratedgrave_ghostmanager:RegisterDecoratedGrave(inst)
end

local function OnDecorated(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    SpawnPrefab("attune_out_fx").Transform:SetPosition(ix, iy, iz)

    initiate_flower_state(inst)
end

local function OnPetalAdded(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    SpawnPrefab("ghostflower_spirit1_fx").Transform:SetPosition(ix, iy, iz)
end

-- Timer
local function OnTimerDone(inst, data)
    if data.name == "petal_decay" then
        inst.AnimState:Hide("flower")
        inst.components.upgradeable:SetStage(1)
        inst.components.timer:StopTimer("try_evil_flower")
    elseif data.name == "try_evil_flower" then
        try_evil_flower(inst)
        inst.components.timer:StartTimer(
            "try_evil_flower", DECORATED_GRAVESTONE_EVILFLOWER_TIME * (1 + 0.5 * math.random())
        )
    end
end

-- Save/Load
local function onload(inst, data, newents)
    if data then
        if inst.mound and data.mounddata then
            if newents and data.mounddata.id then
                newents[data.mounddata.id] = {entity=inst.mound, data=data.mounddata}
            end
            inst.mound:SetPersistData(data.mounddata.data, newents)
        end

        if data.stone_index then
            if not inst:GetSkinBuild() then
                inst.AnimState:PlayAnimation("grave"..data.stone_index)
            end
            inst.random_stone_choice = tostring(data.stone_index)
        end

        if data.setepitaph then
            --this handles custom epitaphs set in the tile editor
            inst.components.inspectable:SetDescription("'"..data.setepitaph.."'")
            inst.setepitaph = data.setepitaph
        elseif data.epitaph_index then
            inst._epitaph_index = data.epitaph_index
            inst.components.inspectable:SetDescription(STRINGS.EPITAPHS[inst._epitaph_index])
        end

        if inst.components.upgradeable.stage > 1 then
            initiate_flower_state(inst)
        end
    end
end

local function onsave(inst, data)
    if inst.mound then
        data.mounddata = inst.mound:GetSaveRecord()
    end
    data.setepitaph = inst.setepitaph
    data.epitaph_index = (data.setepitaph == nil and inst._epitaph_index) or nil
    data.stone_index = inst.random_stone_choice

    local ents = {}
    if inst.ghost ~= nil and inst.ghost.persists then
        data.ghost_id = inst.ghost.GUID
        table.insert(ents, data.ghost_id)
    end

    return ents
end

local function onloadpostpass(inst, newents, savedata)
    inst.ghost = nil
    if savedata then
        if savedata.ghost_id and newents[savedata.ghost_id] then
            inst.ghost = newents[savedata.ghost_id].entity
            inst.ghost:LinkToHome(inst)
        end
    end
end

local GRAVESTONE_SCRAPBOOK_HIDE = { "flower" }

-- NOTES(DiogoW): This used to be TheCamera:GetDownVec()*.5, probably legacy code from DS,
-- since TheCamera:GetDownVec() would always return the values below.
local MOUND_POSITION_OFFSET = { 0.35355339059327, 0, 0.35355339059327 }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    inst.MiniMapEntity:SetIcon("gravestones.png")

    inst:AddTag("grave")
    inst:AddTag("gravediggable") -- from gravediggable, for optimization

    inst.AnimState:SetBank("gravestone")
    inst.AnimState:SetBuild("gravestones")
    inst.AnimState:Hide("flower")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "grave1"
    inst.scrapbook_hide = GRAVESTONE_SCRAPBOOK_HIDE

    inst.random_stone_choice = tostring(math.random(4))
    inst.AnimState:PlayAnimation("grave" .. inst.random_stone_choice)

    inst._epitaph_index = math.random(#STRINGS.EPITAPHS)

    --
    inst.mound = inst:SpawnChild("mound")
    inst.mound.ghost_of_a_chance = 0.0
    inst.mound.Transform:SetPosition(unpack(MOUND_POSITION_OFFSET))

    --
    local gravediggable = inst:AddComponent("gravediggable")
    gravediggable.ondug = OnDugUp

    --
    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetOnHauntFn(OnHaunt)

    --
    local inspectable = inst:AddComponent("inspectable")
    inspectable:SetDescription(STRINGS.EPITAPHS[inst._epitaph_index])

    --
    inst:AddComponent("timer")

    --
    local upgradeable = inst:AddComponent("upgradeable")
    upgradeable.numstages = 2
    upgradeable.upgradesperstage = TUNING.WENDYSKILL_GRAVESTONE_DECORATECOUNT
    upgradeable.upgradetype = UPGRADETYPES.GRAVESTONE
    upgradeable.onstageadvancefn = OnDecorated
    upgradeable:SetOnUpgradeFn(OnPetalAdded)

    --
    inst:ListenForEvent("timerdone", OnTimerDone)

    --
    inst:WatchWorldState("cycles", on_day_change)

    --
    inst.OnLoad = onload
    inst.OnSave = onsave
    inst.OnLoadPostPass = onloadpostpass

    return inst
end

--
local function SetStoneType(inst, stone_type)
    inst.random_stone_choice = tostring(stone_type or math.random(4))
    inst.AnimState:PlayAnimation("dug_grave" .. inst.random_stone_choice)
    if not inst:GetSkinBuild() then
        inst.components.inventoryitem:ChangeImageName("dug_gravestone" .. (inst.random_stone_choice == "1" and "" or inst.random_stone_choice))
    end
end

local function SetDugEpitaph(inst, index, setstring)
    if setstring then
        inst._epitaph = setstring
        inst.components.inspectable:SetDescription("'"..setstring.."'")
    elseif index then
        inst._epitaph = index
        inst.components.inspectable:SetDescription(STRINGS.EPITAPHS[index])
    else
        inst._epitaph = math.random(#STRINGS.EPITAPHS)
        inst.components.inspectable:SetDescription(STRINGS.EPITAPHS[inst._epitaph])
    end
end

local function OnDugDeployed(inst, pt, deployer)
    local skin_build = inst:GetSkinBuild()
    if skin_build then
        skin_build:gsub("dug_", "")
    end

    local gravestone = SpawnPrefab("gravestone", skin_build, inst.skin_id)
    gravestone.Transform:SetPosition(pt:Get())

    gravestone.random_stone_choice = tostring(inst.random_stone_choice)
    gravestone.AnimState:PlayAnimation("grave"..gravestone.random_stone_choice.."_place")
    gravestone.AnimState:PushAnimation("grave"..gravestone.random_stone_choice)

    if deployer.SoundEmitter then
        deployer.SoundEmitter:PlaySound("meta5/wendy/place_gravestone")
    end

    if inst._epitaph then
        local epitaph_type = type(inst._epitaph)
        if epitaph_type == "number" then
            gravestone._epitaph_index = inst._epitaph
            gravestone.components.inspectable:SetDescription(STRINGS.EPITAPHS[inst._epitaph])
        elseif epitaph_type == "string" then
            gravestone.setepitaph = inst._epitaph
            gravestone.components.inspectable:SetDescription("'"..inst._epitaph.."'")
        end
    end

    local mound = gravestone.mound
    if mound then
        if inst._mound_dug == nil then
            mound:Remove()
        elseif inst._mound_dug then
            mound.AnimState:PlayAnimation("dug")
            mound:RemoveComponent("workable")
        end
    end

    inst:Remove()
end

local function OnDugSave(inst, data)
    data.stone_index = inst.random_stone_choice
    data.mound_dug = inst._mound_dug
    data.epitaph = inst._epitaph
end

local function OnDugLoad(inst, data, newents)
    if not data then return end

    if data.stone_index then
        inst.random_stone_choice = tostring(data.stone_index)
        inst.AnimState:PlayAnimation("dug_grave"..data.stone_index)
        if not inst:GetSkinBuild() then
            inst.components.inventoryitem:ChangeImageName("dug_gravestone" .. (tostring(inst.random_stone_choice) == "1" and "" or inst.random_stone_choice))
        end
    end

    inst._mound_dug = data.mound_dug

    if data.epitaph then
        inst._epitaph = data.epitaph
        local epitaph_type = type(data.epitaph)
        if epitaph_type == "number" then
            inst.components.inspectable:SetDescription(STRINGS.EPITAPHS[data.epitaph])
        elseif epitaph_type == "string" then
            inst.components.inspectable:SetDescription("'"..data.epitaph.."'")
        end
    end
end

local function dug_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("gravestone")
    inst.AnimState:SetBuild("gravestones")
    inst.AnimState:Hide("flower")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.scrapbook_anim = "dug_grave1"
    inst.scrapbook_tex = "dug_gravestone"

    inst.random_stone_choice = tostring(math.random(4))
    inst.SetStoneType = SetStoneType
    inst.SetEpitaph = SetDugEpitaph

    local deployable = inst:AddComponent("deployable")
    deployable.ondeploy = OnDugDeployed

    inst._epitaph = math.random(#STRINGS.EPITAPHS)
    inst:AddComponent("inspectable")
    inst.components.inspectable:SetDescription(STRINGS.EPITAPHS[inst._epitaph])

    local inventoryitem = inst:AddComponent("inventoryitem")
    inventoryitem:SetSinks(true)

    inst.AnimState:PlayAnimation("dug_grave"..inst.random_stone_choice)
    inst.components.inventoryitem:ChangeImageName("dug_gravestone" .. (tostring(inst.random_stone_choice) == "1" and "" or inst.random_stone_choice))

    inst.OnSave = OnDugSave
    inst.OnLoad = OnDugLoad

    return inst
end

--
local function dug_placer_postinit(inst)
    inst.AnimState:Hide("flower")
end

return Prefab("gravestone", fn, assets, prefabs),
    Prefab("dug_gravestone", dug_fn, assets),
    MakePlacer(
        "dug_gravestone_placer", "gravestone", "gravestones", "grave1",
        nil, nil, nil, nil, nil, nil, dug_placer_postinit
    )
