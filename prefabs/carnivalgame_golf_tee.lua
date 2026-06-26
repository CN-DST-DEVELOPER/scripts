local assets =
{
    Asset("ANIM", "anim/carnivalgame_golf_mat.zip"),
	Asset("ANIM", "anim/carnivalgame_golf_hole.zip"),
}

local prefabs =
{
	"carnivalgame_golfclub",
	"carnivalgame_golfball",
}

local function CreateFloorPart(parent, bank, anim, deploy_anim)
	local inst = CreateEntity()

	--[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("NOCLICK")
	inst:AddTag("DECOR")

	inst.AnimState:SetBank(bank)
	inst.AnimState:SetBuild(bank)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-2)

	inst.AnimState:PlayAnimation(anim)

	inst.entity:SetParent(parent.entity)

	if parent.components.placer ~= nil then
		parent.components.placer:LinkEntity(inst, 0.25)
	end

	inst.anim = anim
	inst.deploy_anim = deploy_anim

	return inst
end

local function DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("place") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.floor_parts) do
			v.AnimState:PlayAnimation(v.deploy_anim)
			v.AnimState:SetTime(t)
			v.AnimState:PushAnimation(v.anim, false)
		end
	end
end

local function OnEntityWake(inst)
	inst.OnEntityWake = nil
	DoSyncAnim(inst)
end

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
		inst.Light:Enable(turn_on)
	end
end

local function ResetLootdropperConfig(inst)
	inst.components.lootdropper.min_speed = nil
	inst.components.lootdropper.max_speed = nil
	inst.components.lootdropper.y_offset = nil
	inst.components.lootdropper.spawn_loot_inside_prefab = nil
end

local function ConfigLootDropper(inst)
	inst.components.lootdropper.min_speed = 1
	inst.components.lootdropper.max_speed = 2
	inst.components.lootdropper.y_offset = 6
	inst.components.lootdropper.spawn_loot_inside_prefab = true
end

local function GolfClub_OnSwingHit(inst, data)
	local golfgame = data and data.golfable and data.golfable.inst and data.golfable.inst.golfgame
	if golfgame then
		golfgame.components.minigame:RecordExcitement()
		golfgame.minigame_endtime = GetTime() + TUNING.CARNIVALGAME_GOLFGAME_DURATION -- don't time out if we're actively playing
		golfgame:AddGolfScore()
	end
end

local function SetupGolfClub(inst)
	ResetLootdropperConfig(inst)
	inst.golfclub = SpawnPrefab("carnivalgame_golfclub")
	inst.golfclub.tee_owner = inst
	inst.golfclub.persists = false
	inst.golfclub:AddTag("irreplaceable")
	inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
	inst:ListenForEvent("golfclub_onswinghit", GolfClub_OnSwingHit, inst.golfclub)
	inst.components.lootdropper:FlingItem(inst.golfclub)
	ConfigLootDropper(inst)
end

local function SetupGolfBall(inst)
	-- just some guessed math to get it on the tee art!
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = inst.Transform:GetRotation() * DEGREES
	local vx, vz = math.cos(theta), -math.sin(theta)
	local speed = 1
	local yvel = -1
	local startradius = 0.3
	local startheight = .25
	inst.SoundEmitter:PlaySound("summerevent2022/carnivalgame_puckdrop/door_open")
	inst.golfball = SpawnPrefab("carnivalgame_golfball")
	inst.golfball.golfgame = inst.golfgame
	inst.golfball.persists = false
	inst.golfball:AddTag("irreplaceable")
	inst.golfball:AddComponent("golfpropitem")
	inst.golfball.components.golfpropitem:SetXZBounding(inst.golfgame:GetWorldCoordBoundaries())
	inst.golfball.components.golfpropitem:SetTeleportXZ(x + vx, z + vz)
	inst.golfball.components.golfpropitem:StopUpdating()
	inst.golfball.Transform:SetPosition(x + vx * startradius, startheight, z + vz * startradius)
	inst.golfball.Physics:SetVel(vx*speed, yvel, vz*speed)
	inst.golfball.components.golfable:OnExternalPhysics(inst, theta, speed)
end

local function ClearGolfClub(inst)
	if inst.spawn_club_task ~= nil then
		inst.spawn_club_task:Cancel()
		inst.spawn_club_task = nil
	end
	if inst.golfclub ~= nil then
		if inst.golfclub:IsValid() then
			if not inst.golfclub:IsInLimbo() then
				SpawnPrefab("dirt_puff").Transform:SetPosition(inst.golfclub.Transform:GetWorldPosition())
			end
			inst.golfclub:Remove()
		end

		inst.golfclub = nil
	end
end

local function ClearGolfBall(inst)
	if inst.spawn_ball_task ~= nil then
		inst.spawn_ball_task:Cancel()
		inst.spawn_ball_task = nil
	end
	if inst.golfball ~= nil then
		if inst.golfball:IsValid() then
			if not inst.golfball:IsInLimbo() and not inst.golfball._inhole then
				SpawnPrefab("dirt_puff").Transform:SetPosition(inst.golfball.Transform:GetWorldPosition())
			end
			if not inst.golfball._inhole then
				inst.golfball:Remove()
			end
		end

		inst.golfball = nil
	end
end

-- Called by carnivalgame_golfgame
local function OnActivateGame(inst)
	inst.spawn_club_task = inst:DoTaskInTime(0.5, SetupGolfClub)
	inst.spawn_ball_task = inst:DoTaskInTime(1.2, SetupGolfBall)

	inst.components.cyclable.cancycle = false
	inst.AnimState:PlayAnimation("on_pre")
	inst.AnimState:PushAnimation("idle_on", true)
	inst.AnimState:ClearOverrideSymbol("number_score_01")

	inst:DoTaskInTime(5 * FRAMES, enable_light, true)
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/tee/tee_on_pre")
end

local function spawnticket(inst)
	inst.components.lootdropper:SpawnLootPrefab("carnival_prizeticket")
	inst:ActivateRandomCannon()
end

local function spawntoken(inst)
	ResetLootdropperConfig(inst)
	inst.components.lootdropper.spawn_loot_inside_prefab = true
	inst.components.lootdropper.y_offset = 0.8
	inst.components.lootdropper:SpawnLootPrefab("carnival_gametoken")
	inst:ActivateRandomCannon()
	ConfigLootDropper(inst)
end

local function OnStopPlaying(inst)
	inst.AnimState:PlayAnimation("spawn_rewards_pre")
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/tee/tee_spawnrewards_LP", "rewards_loop")
	local pre_time = inst.AnimState:GetCurrentAnimationLength()
	inst.AnimState:PushAnimation("spawn_rewards_loop", true)
	local score = inst.golfgame and inst.golfgame:GetGolfScore()
	if score then
		local overridesymbol = inst.golfgame:IsGameWon() and string.format("number_score_%02d", math.min(10, score)) or "number_score_x"
		inst.AnimState:OverrideSymbol("number_score_01", "carnivalgame_golf_tee", overridesymbol)
	end
	local extra_delay = (inst.golfgame and inst.golfgame.customizable and 3 or 0)
	return pre_time + extra_delay -- delay before spawning rewards
end

local function SpawnRewards(inst, score)
	if inst.customizable then
		spawntoken(inst) -- refund the token
	end
	for i = 1, score do
		inst:DoTaskInTime(0.25 * i, spawnticket)
	end
	return 0.25 * score
end

local function RemoveGameItems(inst)
	ClearGolfClub(inst)
	ClearGolfBall(inst)
end

local function OnDeactivateGame(inst)
	if inst.customizable then
		inst.components.cyclable.cancycle = true
	end
	inst.SoundEmitter:KillSound("rewards_loop")
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/tee/tee_spawnrewards_pst")
	inst.AnimState:PlayAnimation("spawn_rewards_pst")
	inst.AnimState:PushAnimation("idle_active", true)

	inst:DoTaskInTime(8 * FRAMES, enable_light, false)

	-- inst.SoundEmitter:KillSound("loop")
	-- inst.SoundEmitter:PlaySound("summerevent/carnival_games/feedchicks/station/spawnrewards_pst")
end

local function Trader_AbleToAcceptTest(inst, item, giver)
	-- This will never happen in a regular game so no special string for it.
	local golfgame = inst.golfgame
	if golfgame == nil then
		return false
	end
	if not golfgame:CanStartGame() then
		return false, "CARNIVALGAME_GOLFGAME_NOTREADY"
	end
	if item.prefab == "carnival_gametoken" then
		return true
	end
	return false, "CARNIVALGAME_INVALID_ITEM"
end

local function OnAcceptItem(inst, doer)
	local golfgame = inst.golfgame
	if golfgame ~= nil then
		golfgame.components.minigame:Activate()
	end
end

local function OnHammered(inst)
	ResetLootdropperConfig(inst)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function OnHit(inst)
    if not inst:HasTag("burnt") then
		local canplay = inst.golfgame and inst.golfgame:CanStartGame() or nil
        inst.AnimState:PlayAnimation(canplay and "hit_active" or "hit_inactive")
        inst.AnimState:PushAnimation(canplay and "idle_active" or "idle_inactive", true)
    end
end

local function OnBuilt(inst, data)
	inst.AnimState:PlayAnimation("place")
	inst.AnimState:PushAnimation("idle_inactive", false)
	if data and data.rot then -- before we add it as a prop
		inst.Transform:SetRotation(data.rot)
	end
	local golfgame = data and data.deployable and data.deployable.golfgame
	if golfgame then
		golfgame:AddGolfProp(inst)
		if golfgame:CanStartGame() then
			inst.AnimState:PushAnimation("activate")
			inst.AnimState:PushAnimation("idle_active", false)
		end
	end
	inst.SoundEmitter:PlaySound("summerevent/golf_minigame/tee/tee_place")
	if inst.floor_parts then
		DoSyncAnim(inst)
	end
end

local function UpdateActiveState(inst) -- whether we can play or not.
	if inst.AnimState:IsCurrentAnimation("idle_inactive")
		or inst.AnimState:IsCurrentAnimation("deactivate") then
		if inst.golfgame:CanStartGame() then
			inst.AnimState:PlayAnimation("activate")
			inst.AnimState:PushAnimation("idle_active", false)
		end
	elseif inst.AnimState:IsCurrentAnimation("idle_active")
		or inst.AnimState:IsCurrentAnimation("activate") then
		if not inst.golfgame:CanStartGame() then
			inst.AnimState:PlayAnimation("deactivate")
			inst.AnimState:PushAnimation("idle_inactive", false)
		end
	end
end

local function OnLootPrefabSpawned(inst, data)
	local loot = data and data.loot
	if loot and loot.prefab == "carnivalgame_golf_tee_kit" then
		local golfgame = inst.golfgame
		if golfgame then
			golfgame:AddGolfProp(loot)
		end
	end
end

local function OnCycle(inst, step, doer)
	inst.AnimState:OverrideSymbol("number_par_01", "carnivalgame_golf_tee", string.format("number_par_%02d", step))

	if not POPULATING then
		local canplay = inst.golfgame and inst.golfgame:CanStartGame() or nil
		inst.AnimState:PlayAnimation(canplay and "active_par_cycle" or "inactive_par_cycle")
		inst.AnimState:PushAnimation(canplay and "idle_active" or "idle_inactive")
		inst.SoundEmitter:PlaySound("summerevent/carnival_games/feedchicks/station/hiton", nil, 0.5)
	end
end

local function SetPar(inst, par)
	inst.components.cyclable:SetStep(par)
end

local function GetPar(inst)
	return inst.components.cyclable.step
end

local function OverrideCanUsePrototyper(inst, doer)
	return false -- we don't actually want to use this structure as a prototyper
end

local function SetIsCustomizable(inst)
	inst.customizable = true -- saving handled by carnivalgame_golfgame

	inst.components.cyclable.cancycle = true
	inst.components.lootdropper.droprecipeloot = true

	inst:AddComponent("prototyper")
	inst.components.prototyper.redirect_to_prototyper = inst.golfgame
	inst.components.prototyper.overridecanuseprototyper = OverrideCanUsePrototyper
end

local function GetStatus(inst)
	local golfgame = inst.golfgame
	if golfgame then
		if golfgame._minigametask ~= nil then
			return "PLAYING"
		elseif golfgame:CanStartGame() then
			return nil -- generic
		end
	end
	return "INACTIVE"
end

local function teefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
	inst.entity:AddLight()
    inst.entity:AddNetwork()

	MakeGolfObstaclePhysics(inst, .25)
	inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.PLACER_DEFAULT] / 2) --match kit item

    inst.AnimState:SetBank("carnivalgame_golf_tee")
    inst.AnimState:SetBuild("carnivalgame_golf_tee")
    inst.AnimState:PlayAnimation("idle_active", true)

    inst.Light:Enable(false)
    inst.Light:SetRadius(5)
    inst.Light:SetIntensity(0.55)
    inst.Light:SetFalloff(1.3)
    inst.Light:SetColour(251/255, 240/255, 218/255)

	inst:AddTag("structure")
	inst:AddTag("birdblocker")
	inst:AddTag("golf_tee")

	inst.override_open_crafting_range = 1.5

	MakeSnowCoveredPristine(inst)

    -- Dedicated server doesn't need flooring.
	if not TheNet:IsDedicated() then
        inst.floor_parts = { CreateFloorPart(inst, "carnivalgame_golf_mat", "mat_idle", "mat_place") }
        inst.OnEntityWake = OnEntityWake
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(Trader_AbleToAcceptTest)
    inst.components.trader.onaccept = OnAcceptItem

    inst:AddComponent("lootdropper")
	inst.components.lootdropper.droprecipeloot = false
	ConfigLootDropper(inst)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

	inst:AddComponent("cyclable")
	inst.components.cyclable:SetNumSteps(10)
	inst.components.cyclable:SetStep(1)
	inst.components.cyclable:SetOnCycleFn(OnCycle)
	inst.components.cyclable.cancycle = false

	inst.SetIsCustomizable = SetIsCustomizable
	inst.SetPar = SetPar
	inst.GetPar = GetPar

	MakeHauntable(inst)
    MakeSnowCovered(inst)

	inst.ActivateRandomCannon = ActivateRandomCannon
	inst.OnActivateGame = OnActivateGame
	inst.OnStopPlaying = OnStopPlaying
    inst.SpawnRewards = SpawnRewards
	inst.RemoveGameItems = RemoveGameItems
    inst.OnDeactivateGame = OnDeactivateGame

    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("updategolfgameprop", UpdateActiveState)
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
	deployspacing = DEPLOYSPACING.PLACER_DEFAULT,
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
	CreateFloorPart(inst, "carnivalgame_golf_mat", "mat_idle", "mat_place")
end

return Prefab("carnivalgame_golf_tee", teefn, assets, prefabs),
	MakeDeployableKitItem("carnivalgame_golf_tee_kit", "carnivalgame_golf_tee", "carnivalgame_golf_tee", "carnivalgame_golf_tee", "tee_kit", assets, {size = "med", scale = 0.77}, { "irreplaceable" }, nil, deployable_data),
	MakePlacer("carnivalgame_golf_tee_kit_placer", "carnivalgame_golf_tee", "carnivalgame_golf_tee", "idle_inactive", nil, nil, nil, nil, 0, nil, placer_postinit_fn)