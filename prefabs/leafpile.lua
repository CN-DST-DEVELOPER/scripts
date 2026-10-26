local assets = {
    Asset("ANIM", "anim/leafpile.zip"),
    Asset("ANIM", "anim/leafpile_red_build.zip"),
    Asset("ANIM", "anim/leafpile_yellow_build.zip"),
}

local BUILDS = {
    NONE = "none",
    RED = "red",
    YELLOW = "yellow",
}
local BUILDS_ENUM = {}
for _, v in orderedPairs(BUILDS) do
    table.insert(BUILDS_ENUM, v)
end

local SPOOK_PREFAB = "spooked_worms_fx"

local prefabs = {
    "leafpile_spawn_fx",
    "leafpile_shatter_fx",
    "leafpile_red_spawn_fx",
    "leafpile_red_shatter_fx",
    "leafpile_yellow_spawn_fx",
    "leafpile_yellow_shatter_fx",
    SPOOK_PREFAB,
    "pumpkin_bomb",
    "spider",
    "frog",
}

local prefabs_trinkets = {}
for i = HALLOWEDNIGHTS_TINKET_START, HALLOWEDNIGHTS_TINKET_END do -- "TINKET"
    local prefabname = "trinket_"..i
    table.insert(prefabs_trinkets, prefabname)
    table.insert(prefabs, prefabname)
end
prefabs = ConcatArrays(prefabs, prefabs_trinkets)

local prefabs_ornaments = {}
for i = 1, NUM_HALLOWEEN_ORNAMENTS do
    local prefabname = "halloween_ornament_"..i
    table.insert(prefabs_ornaments, prefabname)
    table.insert(prefabs, prefabname)
end

local prefabs_candies = {}
for i = 1, NUM_HALLOWEENCANDY do
    local prefabname = "halloweencandy_"..i
    table.insert(prefabs_candies, prefabname)
    table.insert(prefabs, prefabname)
end

local LEAFSIZES = {
    SMALL = "small",
    MEDIUM = "medium",
    LARGE = "large",
}
local LEAFSIZES_TO_INDEX = {
    [LEAFSIZES.SMALL] = 1,
    [LEAFSIZES.MEDIUM] = 2,
    [LEAFSIZES.LARGE] = 3,
}
local LARGEST_LEAFSIZE = LEAFSIZES.LARGE
local TRANSITION_ANIMS = { -- Keys are the "going to" leafsize.
    [LEAFSIZES.MEDIUM] = "small_to_medium",
    [LEAFSIZES.LARGE] = "medium_to_large",
}
local GROW_STAGES = { -- Keys are the "coming from" leafsize.
    [LEAFSIZES.SMALL] = LEAFSIZES.MEDIUM,
    [LEAFSIZES.MEDIUM] = LEAFSIZES.LARGE,
}

local TIMER_GROW_NAME = "grow"

local LEAVES_FALL_ANIM_SYNC = 59 * FRAMES -- Sync up to leaves_fall start for when spawn_to_small plays.

local has_spiders, has_frogs = false, false
local LOOTDATA = {
    TREAT = {
        --totalchance = 0,
        drops = {
            {chance = 0.15, candy = true,}, -- Random halloweencandy.
            {chance = 0.3, item = "pumpkin_bomb",},
            {chance = 0.4, trinket = true,}, -- Random Hallowed Nights trinket.
            {chance = 0.15, ornament = true,}, -- Random ornament.
        },
    },
    TRICK = {
        --totalchance = 0,
        drops = {
            {chance = 0.05, item = "poop",},
        }
    },
    DEBRIS = {
        --totalchance = 0,
        drops = {
            {chance = 0.2, item = "acorn",},
            {chance = 0.1, item = "twigs",},
            {chance = 0.1, item = "cutgrass",},
            {chance = 0.1, item = "feather_crow",},
            {chance = 0.1, item = "red_cap",},
            {chance = 0.1, item = "blue_cap",},
            {chance = 0.1, item = "green_cap",},
            {chance = 0.1, item = "petals",},
        },
    },
}

for _, loottable in orderedPairs(LOOTDATA) do
    local totalchance = 0
    for _, dropinfo in ipairs(loottable.drops) do
        totalchance = totalchance + dropinfo.chance
        if dropinfo.item then
            table.insert(prefabs, dropinfo.item)
        end
    end
    loottable.totalchance = totalchance
end

local function UpdatePotentialDrops()
    if has_spiders ~= TUNING.SPIDERDEN_ENABLED then
        has_spiders = TUNING.SPIDERDEN_ENABLED
        if has_spiders then
            table.insert(LOOTDATA.TRICK.drops, {chance = 0.1, item = "spider", aggro = true,})
        else
            for i = #LOOTDATA.TRICK.drops, 1, -1 do
                local v = LOOTDATA.TRICK.drops[i]
                if v.item == "spider" then
                    table.remove(LOOTDATA.TRICK.drops, i)
                end
            end
        end
    end
    if has_frogs ~= TUNING.FROG_POND_ENABLED then
        has_frogs = TUNING.FROG_POND_ENABLED
        if has_frogs then
            table.insert(LOOTDATA.TRICK.drops, {chance = 0.1, item = "frog", aggro = true,})
        else
            for i = #LOOTDATA.TRICK.drops, 1, -1 do
                local v = LOOTDATA.TRICK.drops[i]
                if v.item == "frog" then
                    table.remove(LOOTDATA.TRICK.drops, i)
                end
            end
        end
    end
    
    for _, loottable in orderedPairs(LOOTDATA) do
        local totalchance = 0
        for _, dropinfo in ipairs(loottable.drops) do
            totalchance = totalchance + dropinfo.chance
        end
        loottable.totalchance = totalchance
    end
end

local function RollLootFor(inst, doer)
    UpdatePotentialDrops()
    local loot = {
        --istrick = false,
        drops = {},
    }
    local loottable
    local num_loots
    local leafindex = LEAFSIZES_TO_INDEX[inst.leafsize]
    local trick_bias = TUNING.LEAFPILE_SIZE_ODDS_BIAS_PER_STAGE * (leafindex - 1)
    local trick_chance = math.max(TUNING.LEAFPILE_TRICK_CHANCE - trick_bias, 0)
    local roll = math.random()
    if roll < trick_chance then -- [0, trick)
        loottable = LOOTDATA.TRICK
        num_loots = 1 -- Tricks are bad so limit the number of bad in one loot pile.
        loot.istrick = true
    elseif roll < trick_chance + TUNING.LEAFPILE_TREAT_CHANCE then -- [trick, trick + treat)
        loottable = LOOTDATA.TREAT
    else -- [trick + treat, 1]
        loottable = LOOTDATA.DEBRIS
    end

    if not num_loots then
        num_loots = 1
        local upgradechance = TUNING.LEAFPILE_ADDITIONAL_LOOT_PER_STAGE_CHANCE
        for i = 2, leafindex do
            if math.random() < upgradechance then
                num_loots = num_loots + 1
            end
        end
    end

    if loottable.totalchance > 0 then
        local chosendropinfo, next_chance
        while num_loots > 0 do
            next_chance = math.random() * loottable.totalchance
            chosendropinfo = nil
            for _, dropinfo in ipairs(loottable.drops) do
                next_chance = next_chance - dropinfo.chance
                if next_chance <= 0 then
                    chosendropinfo = dropinfo
                    break
                end
            end
            if chosendropinfo then
                table.insert(loot.drops, chosendropinfo)
                num_loots = num_loots - 1
            end
        end
    end

    return loot
end

local function DropLootFor(inst, doer)
    local loot = inst:RollLootFor(doer)

    local leafindex = LEAFSIZES_TO_INDEX[inst.leafsize]
    local launchspeed = leafindex * 0.6
    local launchspeedvariance = launchspeed * 0.25
    local x, y, z = inst.Transform:GetWorldPosition()
    local didspook = false
    for _, dropinfo in ipairs(loot.drops) do
        local spookreplaceditem = false
        if not didspook and loot.istrick and doer and doer.components.spooked then
            if doer and doer.components.spooked then
                if math.random() < TUNING.LEAFPILE_TRICK_SPOOK_CHANCE then
                    if doer.components.spooked:TryForcingCustomSpook(inst, SPOOK_PREFAB) then
                        didspook = true
                        spookreplaceditem = true
                    end
                end
            end
        end
        if not spookreplaceditem then
            local itemprefab = dropinfo.item
            if not itemprefab then
                if dropinfo.candy then
                    itemprefab = prefabs_candies[math.random(#prefabs_candies)]
                elseif dropinfo.trinket then
                    itemprefab = prefabs_trinkets[math.random(#prefabs_trinkets)]
                elseif dropinfo.ornament then
                    itemprefab = prefabs_ornaments[math.random(#prefabs_ornaments)]
                end
            end
            local item = SpawnPrefab(itemprefab)
            if item then
                item.Transform:SetPosition(x, y, z)
                if item.components.inventoryitem and item.components.inventoryitem.ondropfn then
                    item.components.inventoryitem.ondropfn(item)
                end
    
                if dropinfo.aggro and item.components.combat and doer then
                    if not (
                        item:HasTag("spider") and (doer:HasTag("spiderwhisperer") or doer:HasTag("spiderdisguise") or (doer:HasTag("monster") and not doer:HasTag("player"))) or
                        item:HasTag("frog") and doer:HasTag("merm")
                    ) then
                        item.components.combat:SuggestTarget(doer)
                    end
                end
                if not item.components.combat then
                    Launch2(item, inst, launchspeed, launchspeedvariance, 0.2, 0, 4)
                end
            end
        end
    end
end

local function GetCachedTilePos(inst)
    local tx, ty
    if inst.cached_tx then
        tx, ty = inst.cached_tx, inst.cached_ty
    else
        local x, y, z = inst.Transform:GetWorldPosition()
        tx, ty = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
        inst.cached_tx, inst.cached_ty = tx, ty
    end
    return tx, ty
end

local function CheckCurrentTile(inst, tile)
    if not tile then
        local tx, ty = inst:GetCachedTilePos()
        tile = TheWorld.Map:GetTile(tx, ty)
    end
    if tile ~= WORLD_TILES.DECIDUOUS then
        inst:OnInvalidTile()
    end
end

local function RevealPile(inst)
    inst.revealtask = nil
    inst.components.sweepable:SetEnabled(true)
    inst:Show()
    inst.AnimState:PlayAnimation("spawn_to_small")
    inst.AnimState:PushAnimation("idle_small", true)
end

local function OnPlaced(inst)
    if not inst:IsAsleep() then
        inst.components.sweepable:SetEnabled(false)
        inst:Hide()
        if inst.revealtask then
            inst.revealtask:Cancel()
            inst.revealtask = nil
        end
        inst.revealtask = inst:DoTaskInTime(LEAVES_FALL_ANIM_SYNC, RevealPile)
        local x, y, z = inst.Transform:GetWorldPosition()
        local vfxprefab
        if inst.build == BUILDS.NONE then
            vfxprefab = "leafpile_spawn_fx"
        else
            vfxprefab = "leafpile_" .. inst.build .. "_spawn_fx"
        end
        local vfx = SpawnPrefab(vfxprefab)
        vfx.Transform:SetPosition(x, y, z)
    end
end

local function PlayShatter(inst)
    if not inst:IsAsleep() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local vfxprefab
        if inst.build == BUILDS.NONE then
            vfxprefab = "leafpile_shatter_fx"
        else
            vfxprefab = "leafpile_" .. inst.build .. "_shatter_fx"
        end
        local vfx = SpawnPrefab(vfxprefab)
        vfx.Transform:SetPosition(x, y, z)
    end
end

local function OnInvalidTile(inst)
    inst:PlayShatter()
    inst:Remove()
end

local function Decay(inst)
    if not inst:IsAsleep() then
        local leafpilemanager = TheWorld.components.leafpilemanager
        if leafpilemanager then
            leafpilemanager:UnregisterLeafpile(inst)
        end
        inst.persists = false
        inst.components.sweepable:SetEnabled(false)
        inst.AnimState:PlayAnimation("decay_" .. inst.leafsize)
        inst:ListenForEvent("animover", inst.Remove)
        inst:ListenForEvent("entitysleep", inst.Remove)
    else
        inst:Remove()
    end
end

local function GrowVisualPile(inst, endanimation, transitionanim)
    if transitionanim and not inst:IsAsleep() then
        inst.AnimState:PlayAnimation(transitionanim)
        inst.AnimState:PushAnimation(endanimation, true)
    else
        inst.AnimState:PlayAnimation(endanimation)
    end
end

local function SetLeafSize(inst, leafsize, instant)
    local oldleafsize = inst.leafsize
    if oldleafsize ~= leafsize then
        inst.leafsize = leafsize
        local endanimation = "idle_" .. leafsize
        if not instant then
            local x, y, z = inst.Transform:GetWorldPosition()
            local vfxprefab
            if inst.build == BUILDS.NONE then
                vfxprefab = "leafpile_spawn_fx"
            else
                vfxprefab = "leafpile_" .. inst.build .. "_spawn_fx"
            end
            local vfx = SpawnPrefab(vfxprefab)
            vfx.Transform:SetPosition(x, y, z)
            local transitionanim = TRANSITION_ANIMS[leafsize]
            if inst.leafgrowvisualtask then
                inst.leafgrowvisualtask:Cancel()
                inst.leafgrowvisualtask = nil
            end
            inst.leafgrowvisualtask = inst:DoTaskInTime(LEAVES_FALL_ANIM_SYNC, GrowVisualPile, endanimation, transitionanim)
        else
            GrowVisualPile(inst, endanimation, nil)
        end
        if leafsize ~= LARGEST_LEAFSIZE then
            inst:RescheduleGrow()
        else
            inst.components.timer:StopTimer(TIMER_GROW_NAME)
        end
    end
end

local function GrowLeafPile(inst)
    local leafsize = GROW_STAGES[inst.leafsize]
    if leafsize then
        inst:SetLeafSize(leafsize)
    end
end

local function RescheduleGrow(inst)
    if not inst.components.timer:TimerExists(TIMER_GROW_NAME) then
        inst.components.timer:StartTimer(TIMER_GROW_NAME, GetRandomWithVariance(TUNING.LEAFPILE_TIME_TO_GROW, TUNING.LEAFPILE_TIME_TO_GROW_VARIANCE))
    end
end

local function OnWorkFinished(inst, worker)
    inst:PlayShatter()
    inst:Remove()
end

local function OnSweepedFn(inst, doer, sweeper)
    inst:DropLootFor(doer)
    inst:PlayShatter()
    inst:Remove()
end

local function OnTimerDone(inst, data)
    if data and data.name == TIMER_GROW_NAME then
        inst:GrowLeafPile()
    end
end

local function OnEntity_Init(inst)
    -- Called once after the inst is initialized.
    inst.OnEntitySleep = nil
    inst.OnEntityWake = nil
    inst:CheckCurrentTile()
end

local function SetBuildType(inst, build)
    if build == nil then
        inst.build = BUILDS_ENUM[math.random(#BUILDS_ENUM)]
    else
        inst.build = build
    end

    if inst.build ~= BUILDS.NONE then
        inst.AnimState:SetBuild("leafpile_" .. inst.build .. "_build")
    end
end

local function OnSave(inst, data)
    if inst.leafsize ~= LEAFSIZES.SMALL then
        data.leafsize = inst.leafsize
    end
    data.build = inst.build
end

local function OnLoad(inst, data)
    if data then
        if data.leafsize then
            inst:SetLeafSize(data.leafsize, true)
        end
        SetBuildType(inst, data.build)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst:AddTag("NPC_workable")

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("leafpile")
    inst.AnimState:SetBuild("leafpile")
    inst.AnimState:PlayAnimation("idle_small")

    inst.MiniMapEntity:SetIcon("leafpile.png")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    if CREATING_SCRAPBOOK_DATA then
        SetBuildType(inst, BUILDS.NONE)
    elseif not POPULATING then
        SetBuildType(inst)
    end

    inst.scrapbook_anim = "idle_medium"

    inst.leafsize = LEAFSIZES.SMALL

    inst.RollLootFor = RollLootFor
    inst.DropLootFor = DropLootFor
    inst.GetCachedTilePos = GetCachedTilePos
    inst.CheckCurrentTile = CheckCurrentTile
    inst.OnInvalidTile = OnInvalidTile
    inst.OnPlaced = OnPlaced
    inst.PlayShatter = PlayShatter
    inst.Decay = Decay
    inst.SetLeafSize = SetLeafSize
    inst.GrowLeafPile = GrowLeafPile
    inst.RescheduleGrow = RescheduleGrow
    inst.OnEntitySleep = OnEntity_Init
    inst.OnEntityWake = OnEntity_Init
    inst.OnLoad = OnLoad
    inst.OnSave = OnSave

    inst:AddComponent("inspectable")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(nil)
    inst.components.workable:SetOnFinishCallback(OnWorkFinished)

    inst:AddComponent("sweepable")
    inst.components.sweepable:SetOnSweepedFn(OnSweepedFn)

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)
    inst:RescheduleGrow()

    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountSmall(inst)

    inst:ListenForEvent("onterraform", function(_world, data)
        local x, y = data.x, data.y
        local tx, ty = inst:GetCachedTilePos()
        if tx == x and ty == y then
            inst:CheckCurrentTile(data.tile)
        end
    end, TheWorld)

    return inst
end

return Prefab("leafpile", fn, assets, prefabs)
