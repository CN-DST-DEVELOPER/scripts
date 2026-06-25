local assets =
{
    Asset("ANIM", "anim/carnivalgame_golf_tee.zip"),
}

local FIND_CHAIN_MUST_TAGS = {"carnivalcannon", "inactive"}
local function ActivateRandomCannon(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local cannons = TheSim:FindEntities(x, y, z, 12, FIND_CHAIN_MUST_TAGS)
	if #cannons > 0 then
		cannons[math.random(#cannons)]:FireCannon()
	end
end

local function enable_light(inst, turn_on)
	if inst:IsValid() then -- this has to be done to handle destroying the game
		if turn_on then
			inst.AnimState:Show("light_on")
		else
			inst.AnimState:Hide("light_on")
		end
		inst.Light:Enable(turn_on)
	end
end

-- Called by carnivalgame_golfgame
local function OnActivateGame(inst)
	inst:DoTaskInTime(5 * FRAMES, enable_light, true)
	inst.SoundEmitter:PlaySound("summerevent/lamp/turn_on")
end

local function OnDeactivateGame(inst)
	inst:DoTaskInTime(3 * FRAMES, enable_light, false)
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/hole/hole_deactivate")
end

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function OnHit(inst)
	inst.AnimState:PlayAnimation("hole_hit")
	inst.AnimState:PushAnimation("hole_idle", false)
end

local function SetIsCustomizable(inst)
	inst.customizable = true -- saving handled by carnivalgame_golfgame
	inst.components.lootdropper.droprecipeloot = true
end

local function OnBuilt(inst, data)
	if data and data.deployable and data.deployable.golfgame then
		data.deployable.golfgame:AddGolfProp(inst)
	end
	inst.AnimState:PlayAnimation("hole_place")
	inst.AnimState:PushAnimation("hole_idle", true)
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/hole/hole_place")
end

local function OnLootPrefabSpawned(inst, data)
	local loot = data and data.loot
	if loot and loot.prefab == "carnivalgame_golf_hole_kit" then
		local golfgame = inst.golfgame
		if golfgame then
			golfgame:AddGolfProp(loot)
		end
	end
end

local function FinishGame(inst)
	local golfgame = inst.golfgame
	if golfgame and golfgame._minigametask then
		golfgame:SetGameWon(true)
		golfgame:FlagGameComplete()
	end
end

local function OnScored(inst, ball)
	inst.AnimState:PlayAnimation("hole_hit")
	inst.AnimState:PushAnimation("hole_idle", false)
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/hole/hole_score")

	local golfgame = inst.golfgame
	if golfgame and golfgame._minigametask then
		golfgame.minigame_endtime = GetTime() + 1 -- just in case
	end
	inst:DoTaskInTime(7 * FRAMES, FinishGame)
end

local function hole_PostUpdate(inst)
	if inst.AnimState:IsCurrentAnimation("hole_place") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.decals) do
			v.AnimState:PlayAnimation("hole_place")
			v.AnimState:PushAnimation("hole_idle", false)
			v.AnimState:SetTime(t)
		end
	end
	inst:RemoveComponent("updatelooper")
end

local DECAL_LAYERS = { "hole_decal", "hole_decal_front", "star_decal" }

local function CreateHoleDecal(layername, orientation, layer, sortorder, finaloffset)
	local inst = CreateEntity()

	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetRotation(90)

	inst.AnimState:SetBank("carnivalgame_golf_hole")
	inst.AnimState:SetBuild("carnivalgame_golf_hole")
	inst.AnimState:PlayAnimation("hole_idle")
	inst.AnimState:Hide("light_on")
	inst.AnimState:Hide("flag")
	for _, v in ipairs(DECAL_LAYERS) do
		if v ~= layername then
			inst.AnimState:Hide(v)
		end
	end
	inst.AnimState:SetOrientation(orientation)
	if layer then
		inst.AnimState:SetLayer(layer)
	end
	if sortorder then
		inst.AnimState:SetSortOrder(sortorder)
	end
	if finaloffset then
		inst.AnimState:SetFinalOffset(finaloffset)
	end

	return inst
end

local function holefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.MEDIUM] / 2) --match kit item

    inst.AnimState:SetBank("carnivalgame_golf_hole")
    inst.AnimState:SetBuild("carnivalgame_golf_hole")
    inst.AnimState:PlayAnimation("hole_idle")
	inst.AnimState:Hide("light_on")
	for _, v in ipairs(DECAL_LAYERS) do
		inst.AnimState:Hide(v)
	end

    inst.Light:Enable(false)
    inst.Light:SetRadius(2)
    inst.Light:SetIntensity(0.55)
    inst.Light:SetFalloff(1.3)
    inst.Light:SetColour(251/255, 240/255, 218/255)

	inst:AddTag("structure")
	inst:AddTag("birdblocker")
	inst:AddTag("golfhole")
	inst.no_golfgame_rotation_inherit = true

	if not TheNet:IsDedicated() then
		inst.decals =
		{
			CreateHoleDecal("star_decal", ANIM_ORIENTATION.OnGround, LAYER_BACKGROUND, 3),
			CreateHoleDecal("hole_decal", ANIM_ORIENTATION.OnGroundFixed, LAYER_BACKGROUND, 3, 1),
			CreateHoleDecal("hole_decal_front", ANIM_ORIENTATION.OnGroundFixed, nil, nil, 1),
		}
		for _, v in ipairs(inst.decals) do
			v.entity:SetParent(inst.entity)
		end
		inst:AddComponent("updatelooper")
		inst.components.updatelooper:AddPostUpdateFn(hole_PostUpdate)
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")
	inst.components.lootdropper.droprecipeloot = false

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(1)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

	MakeHauntable(inst)

	inst.SetIsCustomizable = SetIsCustomizable

	inst.ActivateRandomCannon = ActivateRandomCannon
	inst.OnActivateGame = OnActivateGame
    inst.OnDeactivateGame = OnDeactivateGame

    inst:ListenForEvent("onbuilt", OnBuilt)
	inst:ListenForEvent("ms_ongolfscored", OnScored)
	inst:ListenForEvent("loot_prefab_spawned", OnLootPrefabSpawned)

    return inst
end

----------------------------------

-- keep same as recipes.lua::GOLFGAME_DEPLOY_IGNORE_TAGS
local GOLFGAME_DEPLOY_IGNORE_TAGS = { "NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "walkableplatform", "walkableperipheral", "isdead", "carnivalgame_part" }
local function GenericGolfCanPlace(pt, inst, rot, builder)
	local spacing = inst.replica.inventoryitem ~= nil and inst.replica.inventoryitem:DeploySpacingRadius() or DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT]
    return TheWorld.Map:IsDeployPointClear(pt, nil, spacing, nil, nil, nil, GOLFGAME_DEPLOY_IGNORE_TAGS)
end
local deployable_data =
{
	deploymode = DEPLOYMODE.CUSTOM,
	deployspacing = DEPLOYSPACING.MEDIUM,
	master_postinit = function(inst)
    	inst:AddComponent("golfpropitem")
	end,
	custom_candeploy_fn = function(inst, pt, mouseover, deployer, rot)
		local x, y, z = pt:Get()
		local golfgame = deployer.replica.builder ~= nil and deployer.replica.builder:GetCurrentPrototyper() or nil
		if not golfgame or golfgame.prefab ~= "carnivalgame_golfgame" or not golfgame:IsInGolfArea(x, z) then
			return false
		end

		return GenericGolfCanPlace(pt, inst, rot, deployer)
	end,
}

local function placer_postinit_fn(inst)
	inst.AnimState:Hide("light_on")
	for _, v in ipairs(DECAL_LAYERS) do
		inst.AnimState:Hide(v)
	end

	inst.decals =
	{
		CreateHoleDecal("star_decal", ANIM_ORIENTATION.OnGround, nil, nil, -2),
		CreateHoleDecal("hole_decal", ANIM_ORIENTATION.OnGroundFixed, nil, nil, -1),
		CreateHoleDecal("hole_decal_front", ANIM_ORIENTATION.OnGroundFixed, nil, nil, 1),
	}
	for _, v in ipairs(inst.decals) do
		v.entity:SetParent(inst.entity)
		inst.components.placer:LinkEntity(v)
	end
end

return Prefab("carnivalgame_golf_hole", holefn, assets),
	MakeDeployableKitItem("carnivalgame_golf_hole_kit", "carnivalgame_golf_hole", "carnivalgame_golf_hole", "carnivalgame_golf_hole", "hole_kit", assets, {size = "med", scale = 0.77}, { "irreplaceable" }, nil, deployable_data),
	MakePlacer("carnivalgame_golf_hole_kit_placer", "carnivalgame_golf_hole", "carnivalgame_golf_hole", "hole_idle", nil, nil, nil, nil, nil, nil, placer_postinit_fn)