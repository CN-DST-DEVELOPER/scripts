require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/hermitcrab_teashop.zip"),
}

local prefabs =
{
    "collapse_small",
    "hermitcrab_teashop_front",
}

local TEA_RECIPES =
{
    "hermitcrabtea_petals",
    "hermitcrabtea_petals_evil",
    "hermitcrabtea_foliage",
    "hermitcrabtea_succulent_picked",
    "hermitcrabtea_moon_tree_blossom",
    "hermitcrabtea_firenettles",
    "hermitcrabtea_tillweed",
    "hermitcrabtea_forgetmelots",
}

for k, v in pairs(TEA_RECIPES) do
    table.insert(prefabs, v)
end

local function StartBrewing(inst, doer, recipe)
    if recipe.product ~= nil then
        inst.hermitcrab:PushEvent("hermitcrab_startbrewing", { product = recipe.product } )
        inst:RemoveComponent("prototyper")
    end
end

local function PlayAnimation(inst, anim, loop)
    inst.AnimState:PlayAnimation(anim, loop)
    inst.front.AnimState:PlayAnimation(anim, loop)
end

local function PushAnimation(inst, anim, loop)
    inst.AnimState:PushAnimation(anim, loop)
    inst.front.AnimState:PushAnimation(anim, loop)
end

local function OnTurnOn(inst)
    -- TODO should we play any animations, or play a line?
end

local function OnTurnOff(inst)
    -- TODO ?
end

local function PushHermitMusic(inst)
    inst._hermit_music:push()
end

-- Let's repeatedly push the music event, so long prototyper is active.
local function OnTurnOnForDoer(inst, doer)
    if doer._hermit_music then
        doer._hermit_music:push()
        doer.repeat_hermit_music_task = doer:DoPeriodicTask(10, PushHermitMusic, 0)
    end
end

local function OnTurnOffForDoer(inst, doer)
    if doer.repeat_hermit_music_task ~= nil then
        doer.repeat_hermit_music_task:Cancel()
        doer.repeat_hermit_music_task = nil
    end
end

local function UpdateRecipes(inst)
    local hermitcrabmanager = TheWorld.components.hermitcrab_relocation_manager
	local house = hermitcrabmanager and hermitcrabmanager:GetPearlsHouse()
    local pearldecorationscore = house and house.components.pearldecorationscore
    local score = pearldecorationscore and pearldecorationscore:GetScore()

    inst.components.craftingstation:ForgetAllItems()

    local level = score >= 75 and 3 or score >= 50 and 2 or 1

    for i, v in ipairs(TEA_RECIPES) do
        inst.components.craftingstation:LearnItem(v, v.."_"..level)
    end
end

local function MakePrototyper(inst)
    if not inst.components.prototyper then
        inst:AddComponent("prototyper")
        inst.components.prototyper.onturnon = OnTurnOn
        inst.components.prototyper.onturnoff = OnTurnOff
        inst.components.prototyper.onturnonfordoer = OnTurnOnForDoer
        inst.components.prototyper.onturnofffordoer = OnTurnOffForDoer
        inst.components.prototyper.onactivate = StartBrewing
        UpdateRecipes(inst)
    end
end

local function OnHammered(inst, worker)
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function GetHermitCrab(inst)
    -- Piggy backing off relocation manager as it caches a reference to Pearl for us
    local hermitcrabmanager = TheWorld.components.hermitcrab_relocation_manager
    return hermitcrabmanager and hermitcrabmanager.hermitcrab
end

local function UpdateLights(inst, isday)
    if isday or not inst:HasHermitCrab() then
        inst.AnimState:Hide("glow")
        inst.Light:Enable(false)
    elseif inst:HasHermitCrab() then
        inst.AnimState:Show("glow")
        inst.Light:Enable(true)
    end
end

local function OnIsDay(inst, isday)
    UpdateLights(inst, isday)
end

local function OnPlayerNear(inst)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        inst.components.playerprox.isclose = false
        return
    end

    local hermitcrab = GetHermitCrab(inst)
    if hermitcrab then
        -- No brain means she's likely in her home. Reset prox and try again
        if not hermitcrab.brain or not IsWithinHermitCrabArea(inst) then
            inst.components.playerprox.isclose = false
            return
        end

        local x, y, z = inst.Transform:GetWorldPosition()
        local hx, hy, hz = hermitcrab.Transform:GetWorldPosition()

        if TheWorld.Pathfinder:IsClear(hx, hy, hz, x, y, z) then
            hermitcrab.brain:AddActiveTeaShop(inst)
            hermitcrab.brain:ForceUpdate()
        else
            hermitcrab.sg.mem.tea_shop_teleport = inst
        end
    end
end

local function OnPlayerFar(inst)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        return
    end

    local hermitcrab = GetHermitCrab(inst)
    if hermitcrab then
        if hermitcrab.brain then
            hermitcrab.brain:RemoveActiveTeaShop(inst)
        end
        hermitcrab.sg.mem.tea_shop_teleport = nil
    end
    --
    inst:PushEvent("hermitcrab_left")
end

local function GetStatus(inst)
    return inst.sg:HasStateTag("brewing") and "BREWING"
        or inst:HasHermitCrab() and "ACTIVE"
        or nil
end

local function OnHermitCrabEnter(inst, data)
    MakePrototyper(inst)
    if data.hermitcrab then
        data.hermitcrab:OnHermitCrabEnterTeaShop()
        inst.hermitcrab = data.hermitcrab
        inst.hermitcrab.Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.hermitcrab.tea_shop = inst

        inst.hermitcrab.client_forward_target = inst
        inst.highlightchildren = inst.highlightchildren or {}
        table.insert(inst.highlightchildren, inst.hermitcrab)
        inst._hermitcrab:set(inst.hermitcrab)
    end
    UpdateLights(inst, TheWorld.state.isday)
end

local function OnHermitCrabLeave(inst, data)
    local instant = data and data.instant
    inst:RemoveComponent("prototyper")
    if inst.hermitcrab and inst.hermitcrab:IsValid() then
        table.removearrayvalue(inst.highlightchildren, inst.hermitcrab)
        inst.hermitcrab.client_forward_target = nil
        inst.hermitcrab.AnimState:SetHighlightColour()
        inst._hermitcrab:set(nil)
        if instant then
            inst.hermitcrab:OnHermitCrabLeaveTeaShop()
            inst.hermitcrab.tea_shop = nil
            inst.hermitcrab = nil
        else
            inst.hermitcrab:PushEventImmediate("leave_teashop")
        end
    end
    UpdateLights(inst, TheWorld.state.isday)
end

local function ShowHermitCrab(inst)
    if inst.hermitcrab and inst.hermitcrab:IsValid() then
        inst.hermitcrab:OnHermitCrabLeaveTeaShop()
        inst.hermitcrab.tea_shop = nil
        inst.hermitcrab = nil
    end
    UpdateLights(inst, TheWorld.state.isday)
end

local function OnRemove(inst)
    inst:PushEvent("hermitcrab_left", { instant = true }) -- Make sure she always shows up when this structure is removed in some way
end

local function OnIgnite(inst, data)
    -- doer could actually be source, yuck!
    local doer = data ~= nil and (data.doer or data.source) or nil
    local hermitcrab = inst.hermitcrab
    inst:PushEvent("hermitcrab_left")
    if hermitcrab and hermitcrab:IsValid() then
        local chatlines = (doer and doer.isplayer and "HERMITCRAB_TEASHOP_PLAYER_BURN") or "HERMITCRAB_TEASHOP_BURN"
        local strtbl = STRINGS[chatlines]
        local strid = math.random(#strtbl)
        hermitcrab.components.npc_talker:Chatter(chatlines, strid, CHATPRIORITIES.LOW, true)
        hermitcrab.components.npc_talker:donextline() -- hack, exiting out of limbo resets our queue
    end
end

local function HasHermitCrab(inst)
    return inst.hermitcrab ~= nil
end

local function DisplayNameFn(inst)
	return inst:HasTag("abandoned") and STRINGS.NAMES.HERMITCRAB_TEASHOP_ABANDONED or nil
end

local function MakeBroken(inst, on_load)
	inst:AddTag("abandoned")
	if not inst:HasTag("burnt") then
        inst:PlayAnimation("broken")
	end
	inst:RemoveComponent("playerprox")
    inst.abandoning_task = nil
end

local VAR_ABANDON_TIME = 30 * FRAMES
local FX_SYNC_TIME = 12 * FRAMES
local function WithinAreaChanged(inst, iswithin)
    if not iswithin and not inst:HasTag("abandoned") then
		local function WithinAreaChanged_Delay()
			SpawnPrefab("hermitcrab_fx_med").Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.abandoning_task = inst:DoTaskInTime(FX_SYNC_TIME, MakeBroken)
		end
		inst.abandoning_task = inst:DoTaskInTime(VAR_ABANDON_TIME * math.random(), WithinAreaChanged_Delay)
	end
end

local function OnHermitCrabDirty(inst)
    if inst._old_hermitcrab and inst._old_hermitcrab:IsValid() then
        inst._old_hermitcrab.AnimState:SetHighlightColour()
        inst._old_hermitcrab.client_forward_target = nil
        table.removearrayvalue(inst.highlightchildren, inst._old_hermitcrab)
    end

    inst._old_hermitcrab = nil

    local hermitcrab = inst._hermitcrab:value()
    if hermitcrab then
        hermitcrab.client_forward_target = inst
        inst.highlightchildren = inst.highlightchildren or {}
        table.insert(inst.highlightchildren, hermitcrab)

        inst._old_hermitcrab = hermitcrab
    end
end

local function OnSave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end

    if inst:HasTag("abandoned") or inst.abandoning_task ~= nil then
        data.abandoned = true
    end

    if inst.hermitcrab and inst.hermitcrab.sg:HasStateTag("brewing") then
        data.tea_product = inst.hermitcrab.sg.mem.tea_product
    end
end

local function OnLoad(inst, data)
    if data ~= nil then
        if data.burnt then
            inst.components.burnable.onburnt(inst)
        end

        if data.abandoned then
            MakeBroken(inst, true)
        end

        if data.tea_product then
            Launch2(SpawnPrefab(data.tea_product), inst, 1, 2, 2.5, 1)
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1.25) --recipe min_spacing/2
    MakeObstaclePhysics(inst, .8)

    inst.MiniMapEntity:SetIcon("hermitcrab_teashop.png")

    inst.Light:Enable(false)
    inst.Light:SetRadius(1)
    inst.Light:SetFalloff(1.5)
    inst.Light:SetIntensity(.4)
    inst.Light:SetColour(250/255,180/255,50/255)

    inst:AddTag("structure")

    inst.AnimState:SetBank("hermitcrab_teashop")
    inst.AnimState:SetBuild("hermitcrab_teashop")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:Hide("glow")
    inst.AnimState:SetSymbolLightOverride("glow", 1)

    inst.AnimState:Hide("teashop_front")
    inst.AnimState:Hide("teashop_straws")

    MakeSnowCoveredPristine(inst)

    inst.displaynamefn = DisplayNameFn

    local lightpostpartner = inst:AddComponent("lightpostpartner")
    lightpostpartner:SetType("hermitcrab_lightpost")

    inst._hermitcrab = net_entity(inst.GUID, "hermitcrab_teashop.hermitcrab", "onhermitcrabdirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("onhermitcrabdirty", OnHermitCrabDirty)
        return inst
    end

    inst.front = SpawnPrefab("hermitcrab_teashop_front")
    inst.front.entity:SetParent(inst.entity)
    inst.front.Transform:SetPosition(0, 0, 0)

    inst.highlightchildren = { inst.front }

    inst.PlayAnimation = PlayAnimation
    inst.PushAnimation = PushAnimation

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    --inst.components.workable:SetOnWorkCallback(OnHit) -- Hit anim is handled in SG

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(5, 6)
    inst.components.playerprox:SetOnPlayerNear(OnPlayerNear)
    inst.components.playerprox:SetOnPlayerFar(OnPlayerFar)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:AddComponent("craftingstation")

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeLargeBurnable(inst, nil, nil, true)
    MakeLargePropagator(inst)

    inst.MakePrototyper = MakePrototyper
    ------------
    inst.OnHermitCrabEnter = OnHermitCrabEnter
    inst.OnHermitCrabLeave = OnHermitCrabLeave
    inst.ShowHermitCrab = ShowHermitCrab

    inst.HasHermitCrab = HasHermitCrab

    inst:ListenForEvent("hermitcrab_entered", inst.OnHermitCrabEnter)
    inst:ListenForEvent("hermitcrab_left", inst.OnHermitCrabLeave)
    inst:ListenForEvent("onremove", OnRemove)
    inst:ListenForEvent("onignite", OnIgnite)

    local function UpdateRecipes_Bridge()
        if inst.components.prototyper then
            UpdateRecipes(inst)
        end
    end
    inst:ListenForEvent("pearldecorationscore_updatescore", UpdateRecipes_Bridge, TheWorld)
    ------------
    inst:WatchWorldState("isday", OnIsDay)
    OnIsDay(inst, TheWorld.state.isday)
    ------------
    inst:SetStateGraph("SGhermitcrab_teashop")

    MakeHermitCrabAreaListener(inst, WithinAreaChanged)
    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountLarge(inst)

    return inst
end

local function client_on_front_replicated(inst)
    local parent = inst.entity:GetParent()
    if parent ~= nil and parent.prefab == "hermitcrab_teashop" then
        parent.highlightchildren = parent.highlightchildren or {}
        table.insert(parent.highlightchildren, inst)
    end
end

local function fn_front()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("hermitcrab_teashop")
    inst.AnimState:SetBuild("hermitcrab_teashop")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetFinalOffset(3)

    inst.AnimState:Hide("snow")
    inst.AnimState:Hide("teashop_deco")
    inst.AnimState:Hide("teashop_wheel")
    inst.AnimState:Hide("teashop_shelf")
    inst.AnimState:Hide("teashop_main")
    inst.AnimState:Hide("teashop_mast")
    inst.AnimState:Hide("teashop_shadow")

    inst:AddTag("FX")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        -- To hook up highlightchildren on clients.
        inst.OnEntityReplicated = client_on_front_replicated

        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("hermitcrab_teashop", fn, assets, prefabs),
    MakePlacer("hermitcrab_teashop_placer", "hermitcrab_teashop", "hermitcrab_teashop", "idle"),
    Prefab("hermitcrab_teashop_front", fn_front, assets)