require("prefabutil")

local assets = {
    Asset("ANIM", "anim/shellweaver.zip"),
    Asset("SOUND", "sound/together.fsb"),
    Asset("SOUND", "sound/winter2025.fsb"),
}

local prefabs = {
    "collapse_small",
}

local sounds = {
    loop = "winter2025/combriner/proximity_LP",
    place = "winter2025/combriner/place",
    hit = "winter2025/combriner/hit",
    cook_pre = "winter2025/combriner/cook_pre",
    cook_loop = "winter2025/combriner/cook_LP",
    cook_pst = "winter2025/combriner/cook_pst",
}

local SCIENCE_STAGES = {
    {time = TUNING.SHELLWEAVER_COOK_TIME, anim = "cook_loop", pre_anim = "cook_pre", sound = sounds.cook_pre},
}

local function OnTurnOn(inst)
    if inst.components.madsciencelab ~= nil and not inst:HasTag("burnt") and not inst.components.madsciencelab:IsMakingScience() then
        if not (inst.AnimState:IsCurrentAnimation("hit_open") or inst.AnimState:IsCurrentAnimation("hit_close") or inst.AnimState:IsCurrentAnimation("place")) then
            inst.AnimState:PlayAnimation("proximity_loop", true)
        else
            inst.AnimState:PushAnimation("proximity_loop", true)
        end

        inst.SoundEmitter:KillSound("loop")
        inst.SoundEmitter:PlaySound(sounds.loop, "loop")
    end
end

local function OnTurnOff(inst)
    if inst.components.madsciencelab ~= nil and not inst:HasTag("burnt") and not inst.components.madsciencelab:IsMakingScience() then
        inst.AnimState:PushAnimation("idle", false)
        inst.SoundEmitter:KillSound("loop")
    end
end

local function OnBuilt(inst, data)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", false)
    inst.SoundEmitter:PlaySound(sounds.place)
end

local function OnHammered(inst, worker)
    if inst.components.madsciencelab ~= nil and inst.components.madsciencelab:IsMakingScience() then
        local name = inst.components.madsciencelab.name
        if name then
            local recipe = AllRecipes[name]
            if recipe then
                local loot = inst.components.lootdropper:GetFullRecipeLoot(recipe)
                inst.components.lootdropper:SetLoot(loot)
            end
        end
    end
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    inst:Remove()
end

local function OnWorked(inst, worker)
    if inst.components.madsciencelab ~= nil and inst.components.madsciencelab:IsMakingScience() then
        inst.AnimState:PlayAnimation("hit_close")
        inst.AnimState:PushAnimation(SCIENCE_STAGES[inst.components.madsciencelab.stage].anim, true)
    elseif inst.components.prototyper ~= nil and inst.components.prototyper.on then
        inst.SoundEmitter:PlaySound(sounds.hit)
        inst.AnimState:PlayAnimation("hit_open")
        OnTurnOn(inst)
    else
        inst.SoundEmitter:PlaySound(sounds.hit)
        inst.AnimState:PlayAnimation("hit_open")
        inst.AnimState:PushAnimation("idle", false)
    end
end

local function StartMakingScience(inst, doer, recipe)
    if recipe.product ~= nil then
        inst.components.madsciencelab:StartMakingScience(recipe.product, recipe.name)
    end
end
local function OnStageStarted(inst, stage)
    inst:RemoveComponent("prototyper")

    local stagedata = SCIENCE_STAGES[stage]

    if stagedata.pre_anim then
        inst.AnimState:PlayAnimation(stagedata.pre_anim)
    end
    inst.AnimState:PushAnimation(stagedata.anim, true)

    if stagedata.sound then
        inst.SoundEmitter:PlaySound(stagedata.sound)
    end
    inst.SoundEmitter:KillSound("loop")
    inst.SoundEmitter:PlaySound(sounds.cook_loop, "loop")
end

local function OnInactive(inst)
    if not inst:HasTag("burnt") then
        inst:RemoveEventCallback("animover", OnInactive)
        inst.AnimState:PlayAnimation("idle", true)
        inst:AddPrototyper()
    end
end

local function OnScienceWasMade(inst, product)
    if product then
        local x, y, z = inst.Transform:GetWorldPosition()
        LaunchAt(SpawnPrefab(product), inst, FindClosestPlayer(x, y, z, true), 1, 2.5, 1)
    end

    inst.AnimState:PlayAnimation("cook_pst")
    inst.SoundEmitter:KillSound("loop")
    inst.SoundEmitter:PlaySound(sounds.cook_pst)
    inst:ListenForEvent("animover", OnInactive)
end

local UNLOCKABLE_SECOND_TIER = { minscore = 30, maxscore = 40 }
local function GetDecorScore()
    local hermitcrabmanager = TheWorld.components.hermitcrab_relocation_manager
    local home = hermitcrabmanager and hermitcrabmanager:GetPearlsHouse()
    local pearldecorationscore = home and home.components.pearldecorationscore
    return pearldecorationscore and pearldecorationscore:GetScore()
end

local function UpdatePrototyperTree(inst)
    if inst.shellweaver_withinarea and inst.istier2 then
        inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.SHELLWEAVER_L2
    else
        inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.SHELLWEAVER_L1
    end
end

-- prototyper gets removed and added so save tier 2 seperately.
local function UpdateScore(inst)
    if inst.components.prototyper then
        local istier2 = inst.components.prototyper.trees == TUNING.PROTOTYPER_TREES.SHELLWEAVER_L2
        local score = GetDecorScore()
        if score and score >= (istier2 and UNLOCKABLE_SECOND_TIER.minscore or UNLOCKABLE_SECOND_TIER.maxscore) then
            inst.istier2 = true
        else
            inst.istier2 = nil
        end
        UpdatePrototyperTree(inst)
    end
end

local function AddPrototyper(inst)
    inst:AddComponent("prototyper")
    inst.components.prototyper.onturnon = OnTurnOn
    inst.components.prototyper.onturnoff = OnTurnOff
    inst.components.prototyper.onactivate = StartMakingScience
    UpdateScore(inst)
end

local function UpdateAbandonedStatus(inst, within_area)
    inst.shellweaver_withinarea = within_area
    if inst.components.prototyper then
        UpdatePrototyperTree(inst)
    end
end

local function OnSave(inst, data)
    data.istier2 = inst.istier2
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.istier2 then
            inst.istier2 = data.istier2
            -- We don't need to update prototyper tree here, abandoned status updaters handle it.
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2) --match kit item
    MakeObstaclePhysics(inst, .4)

    inst.MiniMapEntity:SetPriority(5)
    inst.MiniMapEntity:SetIcon("shellweaver.png")

    inst.AnimState:SetBank("shellweaver")
    inst.AnimState:SetBuild("shellweaver")
    inst.AnimState:PlayAnimation("idle")

	inst:AddTag("structure")

    --prototyper (from prototyper component) added to pristine state for optimization
    inst:AddTag("prototyper")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst.AddPrototyper = AddPrototyper
    inst:AddPrototyper()

    inst:ListenForEvent("onbuilt", OnBuilt)

    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnWorked)

    inst:AddComponent("madsciencelab")
    inst.components.madsciencelab.OnStageStarted = OnStageStarted
    inst.components.madsciencelab.OnScienceWasMade = OnScienceWasMade
    inst.components.madsciencelab.stages = SCIENCE_STAGES

    MakeSnowCovered(inst)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHermitCrabAreaListener(inst, UpdateAbandonedStatus)
    local function UpdateScore_Bridge()
        UpdateScore(inst)
    end
    inst:ListenForEvent("pearldecorationscore_updatescore", UpdateScore_Bridge, TheWorld)
    -- No need to init. pearldecorationscore_updatescore is pushed on LoadPostPass

    return inst
end

return Prefab("shellweaver", fn, assets, prefabs),
    MakePlacer("shellweaver_placer", "shellweaver", "shellweaver", "idle")
