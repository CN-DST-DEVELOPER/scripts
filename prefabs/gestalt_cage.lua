local assets =
{
	Asset("ANIM", "anim/gestalt_cage.zip"),
}

local assets_filled1 = {
	Asset("ANIM", "anim/gestalt_cage.zip"),
    Asset("ANIM", "anim/wagdrone_rolling.zip"),
}
local assets_filled2 = {
	Asset("ANIM", "anim/gestalt_cage.zip"),
    Asset("ANIM", "anim/wagdrone_flying.zip"),
	Asset("INV_IMAGE", "gestalt_cage_filled2"),
}
local assets_filled3 = {
	Asset("ANIM", "anim/gestalt_cage.zip"),
	Asset("INV_IMAGE", "gestalt_cage_filled2"),
	Asset("INV_IMAGE", "gestalt_cage_filled3"),
}

local prefabs =
{
	"gestalt_cage_filled1",
	"gestalt_cage_filled2",
	"gestalt_cage_filled3",
	"gestalt_cage_swap_fx",
}

local function OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "gestalt_cage", "swap_object")
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")

	if inst.fx then
		inst.fx:Remove()
	end
	inst.fx = SpawnPrefab("gestalt_cage_swap_fx")
	inst.fx:AttachToOwner(owner)
end

local function OnUnequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")

	if inst.fx then
		inst.fx:Remove()
		inst.fx = nil
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("gestalt_cage")
	inst.AnimState:SetBuild("gestalt_cage")
	inst.AnimState:PlayAnimation("idle")

	--weapon (from weapon component) added to pristine state for optimization
	inst:AddTag("weapon")

	local swap_data = { sym_build = "gestalt_cage", sym_name = "swap_object" }
	MakeInventoryFloatable(inst, "med", 0.1, { 1.2, 0.7, 1.2 }, true, -18, swap_data)

    inst:AddTag("gestalt_cage")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

    inst:AddComponent("tradable")

	inst:AddComponent("inventoryitem")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnequip)

	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(TUNING.GESTALT_CAGE_DAMAGE)

	inst:AddComponent("gestaltcage")

	MakeHauntableLaunch(inst)

	return inst
end

--------------------------------------------------------------------------

local function fx_OnRemoveEntity(inst)
	table.removearrayvalue(inst.owner.highlightchildren, inst)
end

local function fx_SetHighlightOwner(inst, owner)
	if owner.highlightchildren then
		table.insert(owner.highlightchildren, inst)
	else
		owner.highlightchildren = { inst }
	end

	inst.owner = owner
	inst.OnRemoveEntity = fx_OnRemoveEntity
end

local function fx_OnEntityReplicated(inst)
	local owner = inst.entity:GetParent()
	if owner then
		fx_SetHighlightOwner(inst, owner)
	end
end

local function fx_AttachToOwner(inst, owner)
	inst.entity:SetParent(owner.entity)
	inst.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true, nil, 0, 2)
	if owner.components.colouradder then
		owner.components.colouradder:AttachChild(inst)
	end
	if owner.components.bloomer then
		owner.components.bloomer:AttachChild(inst)
	end
	if not TheNet:IsDedicated() then
		fx_SetHighlightOwner(inst, owner)
	end
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:AddNetwork()

	inst:AddTag("FX")

	--player can be 4-faced or 6-faced(mounted)
	--we use 8-faced model to cover all facings
	inst.Transform:SetEightFaced()

	inst.AnimState:SetBank("gestalt_cage")
	inst.AnimState:SetBuild("gestalt_cage")
	inst.AnimState:PlayAnimation("swap1")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = fx_OnEntityReplicated

		return inst
	end

	inst.AttachToOwner = fx_AttachToOwner
	inst.persists = false

	return inst
end

--------------------------------------------------------------------------

local FLICKER_LOW1 = 0.3
local FLICKER_HIGH1 = 0.45
local FLICKER_LOW2 = 0.45
local FLICKER_HIGH2 = 0.6

local function DoFlicker(inst, i)
	if bit.band(i, 1) == 1 then
		inst.AnimState:SetSymbolMultColour("light_on", 1, 1, 1, inst.level == 2 and FLICKER_LOW2 or FLICKER_HIGH1)
		inst._flickertask = inst:DoTaskInTime(math.random(2) * FRAMES, DoFlicker, i + 1)
	else
		inst.AnimState:SetSymbolMultColour("light_on", 1, 1, 1, inst.level == 2 and FLICKER_HIGH2 or FLICKER_LOW1)
		if i < 10 then
			inst._flickertask = inst:DoTaskInTime(math.random(3) * FRAMES, DoFlicker, i + 1)
		else
			inst._flickertask = inst:DoTaskInTime(1 + math.random() * 2, DoFlicker, 1)
		end
	end
end

local function SetLedStatusFlicker(inst)
	if inst._flickertask == nil then
		DoFlicker(inst, 10)
	end
end

local function Filled_StopFlicker(inst)
	if inst._flickertask then
		inst._flickertask:Cancel()
		inst._flickertask = nil
	end
end

local function Filled_StartSoundLoop(inst)
	inst._soundtask = nil

	local sound = "rifts5/gestalt_cage/caught"
	if inst.level > 1 then
		sound = sound.."_"..tostring(inst.level)
	end
	sound = sound.."_LP"
	inst.SoundEmitter:PlaySound(sound, "loop")
end

local function Filled_StopSound(inst)
	if inst._soundtask then
		inst._soundtask:Cancel()
		inst._soundtask = nil
	elseif inst.SoundEmitter:PlayingSound("loop") then
		inst.SoundEmitter:KillSound("loop")
	end
end

local function Filled_RestoreSound(inst)
	if inst._soundtask == nil and not inst.SoundEmitter:PlayingSound("loop") then
		if inst.AnimState:IsCurrentAnimation("catch") then
			inst._soundtask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() - inst.AnimState:GetCurrentAnimationTime(), Filled_StartSoundLoop)
		else
			Filled_StartSoundLoop(inst)
		end
	end
end

local function Filled_OnEntitySleep(inst)
	if inst.level < 3 then
		Filled_StopFlicker(inst)
	end
	Filled_StopSound(inst)
end

local function Filled_OnEntityWake(inst)
	if not inst.components.inventoryitem:IsHeld() then
		if inst.level < 3 then
			SetLedStatusFlicker(inst)
		end
		Filled_RestoreSound(inst)
	end
end

local function Filled_topocket(inst, owner)
	if inst.level < 3 then
		Filled_StopFlicker(inst)
	end
	Filled_StopSound(inst)
end

local function Filled_toground(inst)
	if not inst:IsAsleep() then
		if inst.level < 3 then
			SetLedStatusFlicker(inst)
		end
		Filled_RestoreSound(inst)
	end
end

--------------------------------------------------------------------------

local function Filled_ClearFacingModel(inst)
	inst.Transform:SetNoFaced()
	inst:RemoveEventCallback("onputininventory", Filled_ClearFacingModel)
end

local function Level3JiggleLoop(inst, loops)
	inst.AnimState:SetFrame(8)
	if loops > 1 then
		inst:DoTaskInTime(7 * FRAMES, Level3JiggleLoop, loops - 1)
	end
end

local function OnCaptureLevel3AnimQueueOver(inst)
	inst.AnimState:PlayAnimation("success_3_jiggle")
	for i = 1, math.random(2, 4) do
		inst.AnimState:PushAnimation("success_3_loop", false)
	end
	inst.SoundEmitter:PlaySound("rifts5/gestalt_cage/catch_3_wiggle")
end

local function StartCapture(inst)
	local level = inst.level

	local anim = "success_"..tostring(level)
	inst.Transform:SetFourFaced()
	inst.AnimState:PlayAnimation("catch")
	inst.AnimState:PushAnimation(anim)
	if level == 3 then
		for i = 1, math.random(1, 2) do
			inst.AnimState:PushAnimation(anim.."_loop", false)
		end
	else
		inst.AnimState:PushAnimation(anim.."_loop")
	end

	if not (inst.components.inventoryitem:IsHeld() or inst:IsAsleep()) then
		local sound = "rifts5/gestalt_cage/catch"
		if level > 1 then
			sound = sound.."_"..tostring(level)
		end
		inst.SoundEmitter:PlaySound(sound)

		if inst._soundtask then
			inst._soundtask:Cancel()
		elseif inst.SoundEmitter:PlayingSound("loop") then
			inst.SoundEmitter:KillSound("loop")
		end
		inst._soundtask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), Filled_StartSoundLoop)
	end

	inst:ListenForEvent("onputininventory", Filled_ClearFacingModel)
end

local function Filled_GetStatus(inst, viewer)
	return "FILLED"
end

local INDICATOR_MUST_TAGS = {"CLASSIFIED", "gestalt_cage_filled_placerindicator"}
local function on_deploy(inst, pt, deployer)
    local replacementinst = SpawnPrefab(inst.replacementprefab)
    replacementinst.Transform:SetPosition(pt:Get())
    local wagpunk_arena_manager = TheWorld.components.wagpunk_arena_manager
    if wagpunk_arena_manager then
        wagpunk_arena_manager:TrackWagdrone(replacementinst)
    end
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, TUNING.GESTALT_CAGE_FILLED_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS)
    if ents[1] then
        ents[1]:Remove()
    end
    inst:Remove()
    TheWorld:PushEvent("ms_wagpunk_constructrobot")
end

local function CLIENT_CanDeployGestaltCage(inst, pt, mouseover, deployer, rotation)
    return TheSim:CountEntities(pt.x, pt.y, pt.z, TUNING.GESTALT_CAGE_FILLED_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS) > 0
end

local function filledfn1()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("gestalt_cage")
	inst.AnimState:SetBuild("gestalt_cage")
	inst.AnimState:PlayAnimation("success_1_loop", true)
	inst.AnimState:SetSymbolLightOverride("head_fx", 0.3)
	inst.AnimState:SetSymbolLightOverride("backglowart", 0.3)
	inst.AnimState:SetSymbolLightOverride("light_on", 0.5)
	inst.AnimState:SetSymbolBloom("light_on")

	MakeInventoryFloatable(inst, "med", 0.3, 0.8)

	inst:SetPrefabNameOverride("gestalt_cage")

    inst:AddTag("gestalt_cage_filled")
    inst:AddTag("usedeploystring")

    inst.replacementprefab = "wagdrone_rolling"
    inst._custom_candeploy_fn = CLIENT_CanDeployGestaltCage -- for DEPLOYMODE.CUSTOM

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_proxy = "gestalt_cage"

	inst._soundtask = inst:DoTaskInTime(0, Filled_StartSoundLoop)

    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = Filled_GetStatus

    inst:AddComponent("tradable")

	inst:AddComponent("inventoryitem")
	inst:ListenForEvent("onputininventory", Filled_topocket)
	inst:ListenForEvent("ondropped", Filled_toground)

	if TheWorld.components.wagboss_tracker then
		if TheWorld.components.wagboss_tracker:IsWagbossDefeated() then
			inst:AddComponent("deployable")
			inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
			inst.components.deployable.ondeploy = on_deploy
		else
			local function _wagbossdefeated()
				inst:RemoveEventCallback("wagboss_defeated", _wagbossdefeated, TheWorld)
				inst:AddComponent("deployable")
				inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
				inst.components.deployable.ondeploy = on_deploy
			end
			inst:ListenForEvent("wagboss_defeated", _wagbossdefeated, TheWorld)
		end
	end

	MakeHauntableLaunch(inst)

	inst.level = 1
	SetLedStatusFlicker(inst)
	inst.StartCapture = StartCapture

	inst.OnEntitySleep = Filled_OnEntitySleep
	inst.OnEntityWake = Filled_OnEntityWake

	return inst
end

local function filledfn2()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("gestalt_cage")
	inst.AnimState:SetBuild("gestalt_cage")
	inst.AnimState:PlayAnimation("success_2_loop", true)
	inst.AnimState:SetSymbolLightOverride("head_fx", 0.5)
	inst.AnimState:SetSymbolLightOverride("backglowart", 0.3)
	inst.AnimState:SetSymbolLightOverride("light_on", 0.5)
	inst.AnimState:SetSymbolBloom("backglowart")
	inst.AnimState:SetSymbolBloom("light_on")
	inst.AnimState:SetSymbolMultColour("backglowart", 1, 1, 1, 0.6)
    inst.AnimState:SetLightOverride(0.13)

	MakeInventoryFloatable(inst, "med", 0.3, 0.8)

	inst:SetPrefabNameOverride("gestalt_cage")

    inst:AddTag("gestalt_cage_filled")
    inst:AddTag("usedeploystring")

    inst.replacementprefab = "wagdrone_flying"
    inst._custom_candeploy_fn = CLIENT_CanDeployGestaltCage -- for DEPLOYMODE.CUSTOM

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_proxy = "gestalt_cage"

	inst._soundtask = inst:DoTaskInTime(0, Filled_StartSoundLoop)

    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = Filled_GetStatus

    inst:AddComponent("tradable")

	inst:AddComponent("inventoryitem")
	inst:ListenForEvent("onputininventory", Filled_topocket)
	inst:ListenForEvent("ondropped", Filled_toground)

	if TheWorld.components.wagboss_tracker then
		if TheWorld.components.wagboss_tracker:IsWagbossDefeated() then
			inst:AddComponent("deployable")
			inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
			inst.components.deployable.ondeploy = on_deploy
		else
			local function _wagbossdefeated()
				inst:RemoveEventCallback("wagboss_defeated", _wagbossdefeated, TheWorld)
				inst:AddComponent("deployable")
				inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
				inst.components.deployable.ondeploy = on_deploy
			end
			inst:ListenForEvent("wagboss_defeated", _wagbossdefeated, TheWorld)
		end
	end

	MakeHauntableLaunch(inst)

	inst.level = 2
	SetLedStatusFlicker(inst)
	inst.StartCapture = StartCapture

	inst.OnEntitySleep = Filled_OnEntitySleep
	inst.OnEntityWake = Filled_OnEntityWake

	return inst
end

local function filledfn3()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("gestalt_cage")
	inst.AnimState:SetBuild("gestalt_cage")
	inst.AnimState:PlayAnimation("success_3_loop", false)
	inst.AnimState:SetSymbolLightOverride("head_fx", 1)
	inst.AnimState:SetSymbolLightOverride("backglowart", 0.3)
	inst.AnimState:SetSymbolLightOverride("light_on", 0.5)
    inst.AnimState:SetSymbolLightOverride("SparkleBit", 0.5)
    inst.AnimState:SetSymbolLightOverride("pb_ray", 0.5)
    inst.AnimState:SetSymbolLightOverride("pb_energy_loop", 0.5)
    inst.AnimState:SetLightOverride(0.13)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetSymbolMultColour("light_on", 1, 1, 1, 1)

	MakeInventoryFloatable(inst, "med", 0.3, 0.8)

	inst:SetPrefabNameOverride("gestalt_cage")

    inst:AddTag("gestalt_cage_filled")
    inst:AddTag("irreplaceable")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_proxy = "gestalt_cage"

	inst._soundtask = inst:DoTaskInTime(0, Filled_StartSoundLoop)

    inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = Filled_GetStatus

    inst:AddComponent("tradable")

	inst:AddComponent("inventoryitem")
	inst:ListenForEvent("onputininventory", Filled_topocket)
	inst:ListenForEvent("ondropped", Filled_toground)
    inst:ListenForEvent("animqueueover", OnCaptureLevel3AnimQueueOver)

	MakeHauntableLaunch(inst)

	inst.level = 3
	inst.StartCapture = StartCapture
	inst.OnEntitySleep = Filled_OnEntitySleep
	inst.OnEntityWake = Filled_OnEntityWake

	return inst
end


-------------------------------------------
-- gestalt_cage_placer

local function OnUpdateTransform_Placer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, TUNING.GESTALT_CAGE_FILLED_PLACEMENT_RADIUS, INDICATOR_MUST_TAGS)

    if ents[1] then
        local ex, ey, ez = ents[1].Transform:GetWorldPosition()
        inst.Transform:SetPosition(ex, 0, ez)
    end
end
local function OverrideBuildPoint_Placer(inst)
    -- Gamepad defaults to this behavior, but mouse input normally takes
    -- mouse position over placer position, ignoring the placer snapping
    -- to a nearby location
    return inst:GetPosition()
end
local function PlacerPostinit_1(inst)
    inst.deployhelper_key = "gestalt_cage_filled_placerindicator"
    inst.replacementprefab = "wagdrone_rolling"
    inst.components.placer.onupdatetransform = OnUpdateTransform_Placer
    inst.components.placer.override_build_point_fn = OverrideBuildPoint_Placer
end
local function PlacerPostinit_2(inst)
    inst.deployhelper_key = "gestalt_cage_filled_placerindicator"
    inst.replacementprefab = "wagdrone_flying"
    inst.components.placer.onupdatetransform = OnUpdateTransform_Placer
    inst.components.placer.override_build_point_fn = OverrideBuildPoint_Placer
end


-----------------------------------------------------------
-- gestalt_cage_filled_placerindicator

local assets_placerindicator = {
	Asset("ANIM", "anim/wagdrone_rolling.zip"),
	Asset("ANIM", "anim/wagdrone_flying.zip"),
}

local function SetupRollingDecal(inst)
    inst.AnimState:SetBuild("wagdrone_rolling")
    inst.AnimState:SetBank("wagdrone_rolling")
    inst.AnimState:PlayAnimation("off_idle")
    inst.AnimState:SetSymbolLightOverride("light_yellow_on", 0.5)
    inst.AnimState:SetSymbolBloom("light_yellow_on")
    inst.AnimState:Hide("LIGHT_ON")
end

local function SetupFlyingDecal(inst)
    inst.AnimState:SetBuild("wagdrone_flying")
    inst.AnimState:SetBank("wagdrone_flying")
    inst.AnimState:PlayAnimation("off_idle")
    inst.AnimState:OverrideSymbol("bolt_c", "wagdrone_projectile", "bolt_c")
    inst.AnimState:SetSymbolBloom("bolt_c")
    inst.AnimState:SetSymbolLightOverride("bolt_c", 1)
    inst.AnimState:SetSymbolLightOverride("fx_ray", 1)
    inst.AnimState:SetSymbolLightOverride("light_yellow_on", 0.5)
    inst.AnimState:SetSymbolBloom("light_yellow_on")
    inst.AnimState:Hide("LIGHT_ON")
end

local function CreateFloorDecal(kind)
    local inst = CreateEntity()

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    if kind == "wagdrone_rolling" then
        SetupRollingDecal(inst)
    else
        SetupFlyingDecal(inst)
    end
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetMultColour(0.4, 0.5, 0.6, 0.6)
    inst.AnimState:SetSortOrder(-1)

    return inst
end

local function OnEnableHelper(inst, enabled, recipename, placerinst)
    if enabled then
        inst.helper = CreateFloorDecal(placerinst and placerinst.replacementprefab or nil)
        inst.helper.entity:SetParent(inst.entity)

        inst.helper.placerinst = placerinst
    elseif inst.helper ~= nil then
        inst.helper:Remove()
        inst.helper = nil
    end
end

local function OnSave_placerindicator(inst, data)
    local rotation = inst.Transform:GetRotation()
    if rotation ~= 0 then
        data.rotation = rotation
    end
end
local function OnLoad_placerindicator(inst, data)
    if not data then
        return
    end

    if data.rotation then
        inst.Transform:SetRotation(data.rotation)
    end
end

local function fn_placerindicator()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("gestalt_cage_filled_placerindicator")

    --Dedicated server does not need deployhelper
    if not TheNet:IsDedicated() then
        local deployhelper = inst:AddComponent("deployhelper")
        deployhelper:AddKeyFilter("gestalt_cage_filled_placerindicator")
        deployhelper.onenablehelper = OnEnableHelper
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnSave = OnSave_placerindicator
    inst.OnLoad = OnLoad_placerindicator

    return inst
end

return Prefab("gestalt_cage", fn, assets, prefabs),
	Prefab("gestalt_cage_swap_fx", fxfn, assets),
	Prefab("gestalt_cage_filled1", filledfn1, assets_filled1),
	Prefab("gestalt_cage_filled2", filledfn2, assets_filled2),
	Prefab("gestalt_cage_filled3", filledfn3, assets_filled3),
	MakePlacer("gestalt_cage_filled1_placer", "wagdrone_rolling", "wagdrone_rolling", "off_idle", nil, nil, nil, nil, nil, nil, PlacerPostinit_1),
	MakePlacer("gestalt_cage_filled2_placer", "wagdrone_flying", "wagdrone_flying", "off_idle", nil, nil, nil, nil, nil, nil, PlacerPostinit_2),
    Prefab("gestalt_cage_filled_placerindicator", fn_placerindicator, assets_placerindicator)
