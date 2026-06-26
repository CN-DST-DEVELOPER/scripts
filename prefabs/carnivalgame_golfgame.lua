local CARNIVALGAME_COMMON = require "prefabs/carnivalgame_common"

local assets =
{
    Asset("ANIM", "anim/carnivalgame_golfgame_turf.zip"),
    Asset("SCRIPT", "scripts/prefabs/carnivalgame_golf_meshdata.lua"),
}

local prefabs =
{
    "carnivalgame_golf_tee",
    "carnivalgame_golf_hole",
    "carnivalgame_golf_tee_kit",
    "carnivalgame_golf_hole_kit",
    "carnivalgame_golfprop_fence",
    "carnivalgame_golfprop_wallcorner",
    "carnivalgame_placementblocker_golfgame",
    -- Dropping kit loot from removing placed area.
	"carnivalgame_golfgame_kit_easy",
	"carnivalgame_golfgame_kit_medium",
	"carnivalgame_golfgame_kit_hard",
	"carnivalgame_golfgame_kit_diy",
}

local PREFABS_TO_TRACK = {
    ["carnivalgame_golf_tee"] = "golf_tee",
    ["carnivalgame_golf_hole"] = "golf_hole",
    ["carnivalgame_golf_tee_kit"] = "golf_tee_kit",
    ["carnivalgame_golf_hole_kit"] = "golf_hole_kit",
}

local COURSE_MESHES = require("prefabs/carnivalgame_golf_meshdata").COURSE_MESHES
local GOLFGAME_NEARESTANGLE = 90

local CURRENT_COURSE_VERSION = 1
local NUM_HEADER_VERSION1 = 2 -- version, par
local NUM_DATA_PER_PROP_VERSION1 = 4 -- prefab, rot, x, y

local BOUNDARY_MINX = -8
local BOUNDARY_MAXX = 8
local BOUNDARY_MINZ = -6
local BOUNDARY_MAXZ = 6

local BLOCKER_POINTS = {}
for x = BOUNDARY_MINX, BOUNDARY_MAXX, 1 do
    for z = BOUNDARY_MINZ, BOUNDARY_MAXZ, 1 do
        table.insert(BLOCKER_POINTS, {x, z})
    end
end

local function GetGolfBoundaries(inst)
    local rot = inst.Transform:GetRotation()
    if inst._cachedrot ~= rot then
        inst._cachedrot = rot
        local theta = rot * DEGREES
        local x1, z1 = VecUtil_RotateDir(BOUNDARY_MINX, BOUNDARY_MINZ, theta)
        local x2, z2 = VecUtil_RotateDir(BOUNDARY_MAXX, BOUNDARY_MAXZ, theta)
        inst._minx, inst._maxx, inst._minz, inst._maxz = math.min(x1, x2), math.max(x1, x2), math.min(z1, z2), math.max(z1, z2)
    end
    return inst._minx, inst._maxx, inst._minz, inst._maxz
end

local function GetWorldCoordBoundaries(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local minx, maxx, minz, maxz = GetGolfBoundaries(inst)
    return x + minx, x + maxx, z + minz, z + maxz
end

local function AddCoursePropData(tbl, prefabname, rot, x, z)
	local n = #tbl
	tbl[n + 1] = prefabname
	tbl[n + 2] = rot
	tbl[n + 3] = x
	tbl[n + 4] = z
end

local function OnRemoveGolfProp(inst)
    if inst.golfgame then
        table.removearrayvalue(inst.golfgame.courseparts, inst)

        local tracked_name = PREFABS_TO_TRACK[inst.prefab]
        if tracked_name then
            inst.golfgame.trackedcourseparts[tracked_name] = nil
        end

        for i = 1, #inst.golfgame.courseparts do
            inst.golfgame.courseparts[i]:PushEvent("updategolfgameprop")
        end

        -- a prop was removed on a course with difficulty, so convert it into a customize course, no more tickets
        if inst.golfgame.difficulty then
            inst.golfgame.difficulty = nil
            inst.golfgame:SetIsCustomizable()
        end
    end
    inst.golfgame = nil
end

local function AddGolfProp(inst, prop)
    prop.persists = false
    prop.golfgame = inst
    table.insert(inst.courseparts, prop)
    inst:ListenForEvent("onremove", OnRemoveGolfProp, prop)

    local tracked_name = PREFABS_TO_TRACK[prop.prefab]

    if prop.components.golfpropitem then
        local minx, maxx, minz, maxz = GetWorldCoordBoundaries(inst)
        prop.components.golfpropitem:SetXZBounding(minx, maxx, minz, maxz)

        local x, y, z = inst.Transform:GetWorldPosition()
        if tracked_name == "golf_tee_kit" then
            local tx, tz = VecUtil_RotateDir(BOUNDARY_MINX + 2.5, BOUNDARY_MINZ + 2, inst.Transform:GetRotation() * DEGREES)
            prop.components.golfpropitem:SetTeleportXZ(x + tx, z + tz)
        elseif tracked_name == "golf_hole_kit" then
            local tx, tz = VecUtil_RotateDir(BOUNDARY_MINX + 4, BOUNDARY_MINZ + 2, inst.Transform:GetRotation() * DEGREES)
            prop.components.golfpropitem:SetTeleportXZ(x + tx, z + tz)
        end
    end

    if tracked_name then
        if inst.trackedcourseparts[tracked_name] ~= nil then
            assert(BRANCH ~= "dev", tracked_name.." already exists in this golf game.")
        end
        inst.trackedcourseparts[tracked_name] = prop
        if inst.customizable and prop.SetIsCustomizable then
            prop:SetIsCustomizable()
        end

        for i = 1, #inst.courseparts do
            inst.courseparts[i]:PushEvent("updategolfgameprop")
        end
    end
end

local function IsInGolfArea(inst, x, z)
    local minx, maxx, minz, maxz = GetGolfBoundaries(inst)
    return x >= minx and x <= maxx and z >= minz and z <= maxz
end

local function IsWorldCoordsInGolfArea(inst, x, z)
    local ox, oy, oz = inst.Transform:GetWorldPosition()
    return IsInGolfArea(inst, x - ox, z - oz)
end

local function SpawnGolfProp(inst, prefab, rot, x, z, ox, oz, orot, isloading)
	if not (prefab and rot and x and z) then
		return
    end

	--NOTE: orot is UNUSED when loading, since savedata coords are already oriented to golf area
	if not isloading then
		orot = orot or inst.Transform:GetRotation()
		x, z = VecUtil_RotateDir(x, z, orot * DEGREES)
	end
	if not IsInGolfArea(inst, x, z) then
		print(string.format("carnivalgame_golfgame::SpawnGolfProp(\"%s\", %d, %d, %d) dropped out of range.", prefab, rot, x, z))
		return
	end

    if not ox then
        local y
        ox, y, oz = inst.Transform:GetWorldPosition()
    end

    local prop = SpawnPrefab(prefab)
    if not prop then
		print(string.format("carnivalgame_golfgame::SpawnGolfProp(\"%s\", %d, %d, %d) dropped for invalid prefab.", prefab, rot, x, z))
        return
    end
    prop.Transform:SetPosition(ox + x, 0, oz + z)
	if isloading then
		prop.Transform:SetRotation(rot)
    else
        prop.Transform:SetRotation(prop.no_golfgame_rotation_inherit and rot or (rot - orot))
    end
    inst:AddGolfProp(prop)
    prop:PushEvent("spawnedasgolfprop")

    if not POPULATING then
        prop:PushEvent("onbuilt")
    end

    return prop
end

local function LoadCourseDataVersion1(inst, coursedata, isloading)
    -- header
    local par = type(coursedata[2]) == "number" and coursedata[2] > 0 and coursedata[2] or nil
    --
    -- TODO more validation, don't allow any prefab placement or x, y, or inf rot :)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    for i = NUM_HEADER_VERSION1+1, #coursedata, NUM_DATA_PER_PROP_VERSION1 do
		SpawnGolfProp(inst, coursedata[i], coursedata[i + 1], coursedata[i + 2], coursedata[i + 3], x, z, rot, isloading)
    end
    -- objects have spawned, we can use header info
    local tee = inst.trackedcourseparts["golf_tee"]
    if tee and par ~= nil then
        tee:SetPar(par)
    end
end

local function LoadCourseData(inst, coursedata, isloading)
    inst.trackedcourseparts = {}
    for i = 1, #inst.courseparts do
        inst:RemoveEventCallback("onremove", OnRemoveGolfProp, inst.courseparts[i])
        inst.courseparts[i]:Remove()
    end
    inst.courseparts = {}

    coursedata = string.len(coursedata) > 0 and DecodeAndUnzipString(coursedata) or nil
    if coursedata ~= nil and #coursedata > 0 then
        local version = type(coursedata[1]) == "number" and coursedata[1] or nil
        if version == 1 then
			LoadCourseDataVersion1(inst, coursedata, isloading)
        end
        return true
    end
    return false
end

local function SaveCourseData(inst)
    local coursedata = {}
    --
    local tee = inst.trackedcourseparts["golf_tee"]
    coursedata[1] = CURRENT_COURSE_VERSION
    coursedata[2] = tee and tee:GetPar() or -1
    local ox, oy, oz = inst.Transform:GetWorldPosition()
    for i, v in ipairs(inst.courseparts) do
        local x, y, z = v.Transform:GetWorldPosition()
		local rot = math.floor(v.Transform:GetRotation() + 0.5)
		AddCoursePropData(coursedata, v.prefab, rot, x-ox, z-oz)
    end
    --
    coursedata = ZipAndEncodeString(coursedata)
    return string.len(coursedata) > 0 and coursedata or nil
end

local function CalculateMinigameScore(inst) -- 1 score = 1 ticket
    local tee = inst.trackedcourseparts["golf_tee"]
    if inst.customizable or not tee or not inst:IsGameWon() then -- No score on custom courses, and no score if we didnt actually win.
        return 0
    end

    local difficulty_score = TUNING.CARNIVALGAME_GOLF_GAME_DIFFICULTY_SCORES[inst.difficulty]
    local golf_score = inst:GetGolfScore()
    local par = tee:GetPar()

    if golf_score == 1 then -- Hole in one!
        return difficulty_score * TUNING.CARNIVALGAME_GOLFGAME_SCORE_MULT_HOLE_IN_ONE
    elseif golf_score == par then
        return difficulty_score
    elseif golf_score > par then
        local delta = golf_score - par
        return math.floor(difficulty_score ^ (0.80^delta))
    elseif golf_score < par then
        local mult = Remap(golf_score, par, 2, TUNING.CARNIVALGAME_GOLFGAME_SCORE_MINMULT_UNDER_PAR, TUNING.CARNIVALGAME_GOLFGAME_SCORE_MAXMULT_UNDER_PAR)
        return math.floor(difficulty_score * mult)
    end
end

local function CallFunctionOnCourseParts(inst, func_name, ...)
    for i = 1, #inst.courseparts do
        local coursepart = inst.courseparts[i]
        if coursepart[func_name] and coursepart ~= inst.trackedcourseparts["golf_tee"] then
            coursepart[func_name](coursepart, ...)
        end
    end
end

local function SetCameraFocusTarget(inst, target)
    if target ~= inst.camerafocus_redirecttarget:value() then
        inst.camerafocus_redirecttarget:set(target)
        if not TheNet:IsDedicated() then
            inst:OnCameraFocusDirty()
        end
    end
end

local function OnActivateGame(inst)
    inst:SetGameWon(false)
    inst:ResetGolfScore()
    inst:RemoveTag("prototyper") -- disable building
    for i = 1, #inst.courseparts do
        local coursepart = inst.courseparts[i]
        coursepart._had_noclick = coursepart:HasTag("NOCLICK")
        coursepart:AddTag("NOCLICK")
    end
    -- do something when the game activates (but hasnt started playing yet)
    -- like spawn clubs and balls.
    CallFunctionOnCourseParts(inst, "OnActivateGame")
    local tee = inst.trackedcourseparts["golf_tee"]
    if tee then
        tee:OnActivateGame()
        SetCameraFocusTarget(inst, tee)
    end
    inst:EnableCameraFocus(true)
end

local function OnStartPlaying(inst)
    -- do something when the game starts playing (game starts playing after a slight delay after activating)
    -- allow players to hit balls with their clubs now.
    inst:RemoveTerraformerRemoveable()
    CallFunctionOnCourseParts(inst, "OnStartPlaying")
    SetCameraFocusTarget(inst, nil)
end

local function OnUpdateGame(inst, dt)
    -- do things while game is updating
    CallFunctionOnCourseParts(inst, "OnUpdateGame", dt)
end

local function OnStopPlaying(inst)
    inst:AddTerraformerRemoveable()
    inst:EnableCameraFocus(true)
    CallFunctionOnCourseParts(inst, "OnStopPlaying")
    inst._minigame_score = CalculateMinigameScore(inst)
    local tee = inst.trackedcourseparts["golf_tee"]
    if tee then
        SetCameraFocusTarget(inst, tee)
        return tee:OnStopPlaying() -- delay before spawning rewards
    end
	return 0
end

local function SpawnRewards(inst)
    CallFunctionOnCourseParts(inst, "SpawnRewards")
    local tee = inst.trackedcourseparts["golf_tee"]
	return tee and tee:SpawnRewards(inst._minigame_score) or 0 -- delay before deactivating game
end

local function OnDeactivateGame(inst)
    inst:SetGameWon(false)
    inst:ResetGolfScore()
    inst:EnableCameraFocus(false)
    SetCameraFocusTarget(inst, nil)
    for i = 1, #inst.courseparts do
        local coursepart = inst.courseparts[i]
        if not coursepart._had_noclick then
            coursepart:RemoveTag("NOCLICK")
        else
            coursepart._had_noclick = nil
        end
    end
    if inst.components.prototyper then
        inst:AddTag("prototyper")
    end
    CallFunctionOnCourseParts(inst, "OnDeactivateGame")
    local tee = inst.trackedcourseparts["golf_tee"]
    if tee then
        tee:OnDeactivateGame()
    end
end

local function RemoveGameItems(inst)
    local tee = inst.trackedcourseparts["golf_tee"]
    if tee then
        tee:RemoveGameItems()
    end
end

local function OnRemoveGame(inst)
    for i = 1, #inst.courseparts do
        inst.courseparts[i]:Remove()
    end
    inst.courseparts = {}
end

local function CanStartGame(inst)
    return  inst.trackedcourseparts["golf_tee"] ~= nil
        and inst.trackedcourseparts["golf_hole"] ~= nil
end

local function UpdatePlayerInGolfArea(inst, player)
    if player:IsValid() then -- FIXME(JBK): golf: Change how player tracking is handled to deal with players leaving.
        local x, y, z = player.Transform:GetWorldPosition()
        if player.components.builder ~= nil then
            if IsWorldCoordsInGolfArea(inst, x, z) then
                player.components.builder:UsePrototyper(inst, true)
            elseif player.components.builder.override_current_prototyper == inst then
                player.components.builder.override_current_prototyper = nil
            end
        end
    else
        inst.tracking_players[player]:Cancel()
        inst.tracking_players[player] = nil
        if next(inst.tracking_players) == nil then
            inst.tracking_players = nil
        end
    end
end

local function OnPlayerNear(inst, player)
    inst.tracking_players = inst.tracking_players or {}
    if inst.tracking_players[player] == nil then
        inst.tracking_players[player] = inst:DoPeriodicTask(0.5, UpdatePlayerInGolfArea, 0, player)
    end
end

local function OnPlayerFar(inst, player)
    if inst.tracking_players[player] ~= nil then
        if player.components.builder ~= nil and player.components.builder.override_current_prototyper == inst then
            player.components.builder.override_current_prototyper = nil
        end
        inst.tracking_players[player]:Cancel()
        inst.tracking_players[player] = nil
        if next(inst.tracking_players) == nil then
            inst.tracking_players = nil
        end
    end
end

local function OverrideCanUsePrototyper(inst, doer)
    if doer ~= nil then
        local x, y, z = doer.Transform:GetWorldPosition()
        return IsWorldCoordsInGolfArea(inst, x, z)
    end
end

local function OnTurnOffForDoer(inst, doer)
    -- clear buffered recipes when we leave
    for k, v in pairs(AllRecipes) do
        if IsRecipeValid(v.name) and v.level == TECH.CARNIVAL_GOLFPROPS_ONE then
            doer.components.builder:SetBuildBuffered(v.name, false)
        end
    end
end

local function SetIsCustomizable(inst)
    inst.customizable = true

    for name, prop in pairs(inst.trackedcourseparts) do
        if prop.SetIsCustomizable then
            prop:SetIsCustomizable()
        end
    end

	inst:AddComponent("prototyper")
	inst.components.prototyper.onturnofffordoer = OnTurnOffForDoer
	inst.components.prototyper.overridecanuseprototyper = OverrideCanUsePrototyper
	inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.CARNIVALGAME_GOLFGAME
	inst.components.prototyper.dontopencraftingmenuonevaulatetechtrees = true -- hack flag :P

    local near_dist = math.max(BOUNDARY_MAXX, BOUNDARY_MAXZ) + 3 -- padding
    local playerprox = inst:AddComponent("playerprox")
    playerprox:SetDist(near_dist, near_dist + .25)
    playerprox:SetTargetMode(playerprox.TargetModes.AllPlayers)
    playerprox:SetOnPlayerNear(OnPlayerNear)
    playerprox:SetOnPlayerFar(OnPlayerFar)

    local isloading = POPULATING
    if not isloading then
        local x, y, z = inst.Transform:GetWorldPosition()
        if inst.trackedcourseparts["golf_tee"] == nil and inst.trackedcourseparts["golf_tee_kit"] == nil then
            SpawnGolfProp(inst, "carnivalgame_golf_tee_kit", 0, BOUNDARY_MINX + 2.5, BOUNDARY_MINZ + 2, x, z)
        end
        if inst.trackedcourseparts["golf_hole"] == nil and inst.trackedcourseparts["golf_hole_kit"] == nil then
            SpawnGolfProp(inst, "carnivalgame_golf_hole_kit", 0, BOUNDARY_MINX + 4, BOUNDARY_MINZ + 2, x, z)
        end
    end
end

local function IsGameWon(inst)
    return inst.golfgame_won
end

local function SetGameWon(inst, won)
    inst.golfgame_won = won or false
end

local function ResetGolfScore(inst)
	inst.golf_score = 0
end

local function AddGolfScore(inst)
	inst.golf_score = inst.golf_score + 1
end

local function GetGolfScore(inst)
    return inst.golf_score
end

local function SetDifficulty(inst, difficulty)
    if BRANCH == "dev" then
        -- assert(not inst.customizable, "carnivalgame_golfgame is already customizable, why are you trying to set a difficulty level?")
        assert(difficulty == "easy" or difficulty == "medium" or difficulty == "hard", "carnivalgame_golfgame::SetDifficulty was given an invalid difficulty")
    end
    inst.difficulty = difficulty
end

local function OnBuildStructure(inst, data)
    -- only add the prop if its an actual golf prop recipe :)
    if data.item ~= nil and data.recipe.level == TECH.CARNIVAL_GOLFPROPS_ONE then
		inst:AddGolfProp(data.item)
    end
end

local function TrackUnparentedVisual(inst, visual)
    if inst.visuals[visual] then
        return
    end

    visual.persists = false
    inst.visuals[visual] = function() inst:UntrackUnparentedVisual(visual) end
    visual:ListenForEvent("onremove", inst.visuals[visual])
end
local function UntrackUnparentedVisual(inst, visual)
    if not inst.visuals[visual] then
        return
    end

    if visual:IsValid() then
        visual.persists = true
        visual:RemoveEventCallback("onremove", inst.visuals[visual])
    end
    inst.visuals[visual] = nil
end
local function RemoveAllUnparentedVisuals(inst)
    for visual, _ in pairs(inst.visuals) do
        visual:Remove()
    end
end

local STEP_PER_FENCE_SPAWN = 3
local DELAY_PER_FENCE = 2 * FRAMES / STEP_PER_FENCE_SPAWN
local function PropFence_BuildDelay(inst)
    inst:Show()
    inst:PushEvent("onbuilt")
end
local function CreateUnparentedVisuals(inst, instant)
    inst.pendingvisualsinit = nil
    -- (OMAR) NOTE: the fences arent actual golf props, since they shouldnt be affected by the course code.
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    local theta = rot * DEGREES

    for off_x = BOUNDARY_MINX + 1, BOUNDARY_MAXX - 1, STEP_PER_FENCE_SPAWN do
        local delay = (off_x + math.abs(BOUNDARY_MINX)) * DELAY_PER_FENCE
        for i = 0, 2 do
            if off_x + i <= BOUNDARY_MAXX - 1 then
                local fx, fz = VecUtil_RotateDir(off_x + i, BOUNDARY_MINZ, theta)
                local fence = SpawnPrefab("carnivalgame_golfprop_fence")
                inst:TrackUnparentedVisual(fence)
                fence.Transform:SetPosition(x + fx, 0, z + fz)
                fence.Transform:SetRotation(rot + 90)
                if not instant then
                    fence:Hide()
                    fence:DoTaskInTime(delay, PropFence_BuildDelay)
                end

                fx, fz = VecUtil_RotateDir(off_x + i, BOUNDARY_MAXZ, theta)
                fence = SpawnPrefab("carnivalgame_golfprop_fence")
                inst:TrackUnparentedVisual(fence)
                fence.Transform:SetPosition(x + fx, 0, z + fz)
                fence.Transform:SetRotation(rot + 90)
                if not instant then
                    fence:Hide()
                    fence:DoTaskInTime((DELAY_PER_FENCE * BOUNDARY_MAXZ*2) + delay, PropFence_BuildDelay)
                end
            end
        end
    end

    for off_z = BOUNDARY_MINZ, BOUNDARY_MAXZ, STEP_PER_FENCE_SPAWN do
        local delay = (off_z + math.abs(BOUNDARY_MINZ)) * DELAY_PER_FENCE
        for i = 0, 2 do
            if off_z + i <= BOUNDARY_MAXZ then
                local prefab_to_spawn = (off_z + i == BOUNDARY_MINZ or off_z + i == BOUNDARY_MAXZ) and "carnivalgame_golfprop_wallcorner" or "carnivalgame_golfprop_fence"
                local fx, fz = VecUtil_RotateDir(BOUNDARY_MINX, off_z + i, theta)
                local fence = SpawnPrefab(prefab_to_spawn)
                inst:TrackUnparentedVisual(fence)
                fence.Transform:SetPosition(x + fx, 0, z + fz)
                fence.Transform:SetRotation(rot + 0)
                if not instant then
                    fence:Hide()
                    fence:DoTaskInTime(delay, PropFence_BuildDelay)
                end

                fx, fz = VecUtil_RotateDir(BOUNDARY_MAXX, off_z + i, theta)
                fence = SpawnPrefab(prefab_to_spawn)
                inst:TrackUnparentedVisual(fence)
                fence.Transform:SetPosition(x + fx, 0, z + fz)
                fence.Transform:SetRotation(rot + 0)
                if not instant then
                    fence:Hide()
                    fence:DoTaskInTime((DELAY_PER_FENCE * BOUNDARY_MAXX*2) + delay, PropFence_BuildDelay)
                end
            end
        end
    end
end
local function OnBuilt(inst)
    inst:CreateUnparentedVisuals(false)
end

local function IsLowPriorityAction(act)
    return act == nil or act.action ~= ACTIONS.TERRAFORM_REMOVE
end
local function CanMouseThrough(inst) -- Runs on clients
    if ThePlayer and ThePlayer.components.playeractionpicker then
        local lmb, rmb = ThePlayer.components.playeractionpicker:DoGetMouseActions(inst:GetPosition(), inst)
        return IsLowPriorityAction(rmb) and IsLowPriorityAction(lmb), true
    end
end

local function GetKitPrefab(inst)
    local kitprefab
    if inst.customizable then
        kitprefab = "carnivalgame_golfgame_kit_diy"
    elseif inst.difficulty then
        kitprefab = "carnivalgame_golfgame_kit_" .. inst.difficulty
    end
    return kitprefab
end
local function OnTerraformerRemoved(inst, doer)
    -- Drop the kit used to make the course.
    local kitprefab = inst:GetKitPrefab()
    if kitprefab then
        local kit = SpawnPrefab(kitprefab)
        if kit then
            Launch2(kit, inst, 1, 1, 0.2, 0, 4)
        end
    end
    -- Remove the inst and inst will handle removing of props and fences.
    inst:Remove()
end

local function AddTerraformerRemoveable(inst)
    local terraformerremoveable = inst.components.terraformerremoveable or inst:AddComponent("terraformerremoveable")
    terraformerremoveable:SetOnRemovedFn(OnTerraformerRemoved)
end

local function RemoveTerraformerRemoveable(inst)
    inst:RemoveComponent("terraformerremoveable")
end

local function RotatePoints_Mesh(points, angle)
    -- Rotates and returns the triangle mesh.
    local triangles = {}
    for _, point in ipairs(points) do
        local x, y, z = point[1], point[2], point[3]
        if angle == 90 then
            table.insert(triangles, -z)
            table.insert(triangles, y)
            table.insert(triangles, x)
        elseif angle == 180 then
            table.insert(triangles, -x)
            table.insert(triangles, y)
            table.insert(triangles, -z)
        elseif angle == 270 then
            table.insert(triangles, z)
            table.insert(triangles, y)
            table.insert(triangles, -x)
        else
            table.insert(triangles, x)
            table.insert(triangles, y)
            table.insert(triangles, z)
        end
    end
    return triangles
end

local function CreateGolfGamePhysics_Internal(angle)
    local angle_nearest_angle = math.floor((angle / GOLFGAME_NEARESTANGLE) + 0.5) * GOLFGAME_NEARESTANGLE

    local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()

    local phys = inst.entity:AddPhysics()
    phys:SetMass(0)
    phys:SetCollisionGroup(COLLISION.BOAT_LIMITS)
    phys:SetCollisionMask(
        COLLISION.ITEMS,
        COLLISION.WORLD
    )
    local mesh = COURSE_MESHES.GOLFGAME
    local rotated_mesh = RotatePoints_Mesh(mesh, angle_nearest_angle)
    phys:SetTriangleMesh(rotated_mesh)

    return inst
end
local function CreateGolfGamePhysics_Common(inst)
    local angle_transform = inst.Transform:GetRotation()
    local angle_worldspace = ReduceAngle(-angle_transform)
    if angle_worldspace < 0 then
        angle_worldspace = angle_worldspace + 360
    end
    local golfgamephysics = CreateGolfGamePhysics_Internal(angle_worldspace)
    local x, y, z = inst.Transform:GetWorldPosition()
    golfgamephysics.Transform:SetPosition(x, y, z)
    return golfgamephysics
end

local function RemoveGolfGamePhysics_Common(inst)
    if inst.golfgamephysics then
        if inst.golfgamephysics:IsValid() then
            inst.golfgamephysics:Remove()
        end
        inst.golfgamephysics = nil
    end
end

local function OnEntitySleep_Common(inst)
    inst:RemoveGolfGamePhysics_Common()
end

local function OnEntityWake_Common(inst)
    if not inst.golfgamephysics then
        inst.golfgamephysics = inst:CreateGolfGamePhysics_Common()
    end
end

local function OnSave(inst, data)
    data.coursedata = inst:SaveCourseData()
    data.customizable = inst.customizable
    data.difficulty = inst.difficulty
end

local function OnLoadPostPass(inst, ents, data)
    if data ~= nil then
        if type(data.coursedata) == "string" then
			inst:LoadCourseData(data.coursedata, true)
        end
        if data.customizable then
            inst:SetIsCustomizable()
        end
        if data.difficulty then
            inst:SetDifficulty(data.difficulty)
        end
    end
    if inst.pendingvisualsinit then
        inst:CreateUnparentedVisuals(true)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("carnivalgame_golfgame_turf")
    inst.AnimState:SetBuild("carnivalgame_golfgame_turf")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(-3)
    inst.AnimState:PlayAnimation("turf")

    inst:AddTag("NOBLOCK")
    inst:AddTag("hideprototyperaction")
    --terraformerremoveable (from terraformerremoveable component) added to pristine state for optimization
    inst:AddTag("terraformerremoveable")

    inst.CanMouseThrough = CanMouseThrough
    -- Blank string for controller action prompt.
    inst.name = " "

    CARNIVALGAME_COMMON.SetUpCameraFocus(inst)
	inst._camerafocus_dist_min = TUNING.CARNIVALGAME_GOLFGAME_CAMERA_FOCUS_MIN
	inst._camerafocus_dist_max = TUNING.CARNIVALGAME_GOLFGAME_CAMERA_FOCUS_MAX
    inst._camerafocus_offset = Vector3(0, 1, 0)
    inst._camerafocus_custom_handling = true
    CARNIVALGAME_COMMON.SetUpGameMusic(inst, true)

    inst.IsInGolfArea = IsWorldCoordsInGolfArea

    inst.camerafocus_redirecttarget = net_entity(inst.GUID, "carnivalgame_golfgame.camerafocus_target", "oncamerafocustargetdirty")

    inst.entity:SetPristine()

    inst.RemoveGolfGamePhysics_Common = RemoveGolfGamePhysics_Common
    inst.CreateGolfGamePhysics_Common = CreateGolfGamePhysics_Common
    inst.OnEntitySleep = OnEntitySleep_Common
    inst.OnEntityWake = OnEntityWake_Common
    inst:ListenForEvent("onremove", inst.RemoveGolfGamePhysics_Common)

    if not TheWorld.ismastersim then
        inst:ListenForEvent("oncamerafocustargetdirty", inst.OnCameraFocusDirty)
        return inst
    end

    inst.pendingvisualsinit = true

    inst.visuals = {}
    inst.TrackUnparentedVisual = TrackUnparentedVisual
    inst.UntrackUnparentedVisual = UntrackUnparentedVisual
    inst.RemoveAllUnparentedVisuals = RemoveAllUnparentedVisuals
    inst.CreateUnparentedVisuals = CreateUnparentedVisuals

    inst.GetKitPrefab = GetKitPrefab

    inst:AddComponent("savedrotation")

    inst.AddTerraformerRemoveable = AddTerraformerRemoveable
    inst.RemoveTerraformerRemoveable = RemoveTerraformerRemoveable
    inst:AddTerraformerRemoveable()

    CARNIVALGAME_COMMON.SetUpMinigameComponent(inst)
    inst._turnon_time = 3
	inst.components.minigame.spectator_dist =		TUNING.CARNIVALGAME_GOLFGAME_ARENA_RADIUS + 10
	inst.components.minigame.participator_dist =	TUNING.CARNIVALGAME_GOLFGAME_ARENA_RADIUS + 0
	inst.components.minigame.watchdist_min =		TUNING.CARNIVALGAME_GOLFGAME_ARENA_RADIUS + 1
	inst.components.minigame.watchdist_target =		TUNING.CARNIVALGAME_GOLFGAME_ARENA_RADIUS + 2
	inst.components.minigame.watchdist_max =		TUNING.CARNIVALGAME_GOLFGAME_ARENA_RADIUS + 4

	inst._game_duration = TUNING.CARNIVALGAME_GOLFGAME_DURATION

    inst.trackedcourseparts = {}
    inst.courseparts = {}

    inst.SaveCourseData = SaveCourseData
    inst.LoadCourseData = LoadCourseData -- string
    inst.AddGolfProp = AddGolfProp

    inst.golfgame_won = false
    inst.golf_score = 0
    inst.IsGameWon = IsGameWon
    inst.SetGameWon = SetGameWon
    inst.ResetGolfScore = ResetGolfScore
    inst.AddGolfScore = AddGolfScore -- golf score as in how many hits we've taken
    inst.GetGolfScore = GetGolfScore

    inst.SetIsCustomizable = SetIsCustomizable
    inst.SetDifficulty = SetDifficulty

    inst.GetWorldCoordBoundaries = GetWorldCoordBoundaries

    inst.CanStartGame = CanStartGame

    -- carnivalgame_common function defs
    inst.OnActivateGame = OnActivateGame
	inst.OnStartPlaying = OnStartPlaying
	inst.OnUpdateGame = OnUpdateGame
	inst.OnStopPlaying = OnStopPlaying
	inst.SpawnRewards = SpawnRewards
	inst.OnDeactivateGame = OnDeactivateGame
	inst.RemoveGameItems = RemoveGameItems
	inst.OnRemoveGame = OnRemoveGame

    for _, offsets in ipairs(BLOCKER_POINTS) do
        local dx, dz = offsets[1], offsets[2]
        local blocker = SpawnPrefab("carnivalgame_placementblocker_golfgame")
        blocker.entity:SetParent(inst.entity)
        blocker.Transform:SetPosition(dx, 0, dz)
    end

    inst:ListenForEvent("buildstructure", OnBuildStructure)
    inst:ListenForEvent("onbuilt", OnBuilt)
    inst:ListenForEvent("onremove", inst.RemoveAllUnparentedVisuals)

    inst.OnSave = OnSave
    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

-------------------------------------

local kit_assets =
{
    Asset("ANIM", "anim/carnivalgame_golfgame_kits.zip"),
}

local DEPLOY_IGNORE_TAGS = { "NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "walkableplatform", "walkableperipheral", "isdead" }
local GOLFGAME_DIAGONAL_LENGTH = 10.2
local DEPLOY_GAP = 1 -- Add a small boundary around the border to have clearance.
local deployable_data = {
    deploymode = DEPLOYMODE.CUSTOM,
    custom_candeploy_fn = function(inst, pt, mouseover, deployer, rot)
        local x, y, z = pt:Get()
        x, z = math.floor(x), math.floor(z)

        local theta = rot * DEGREES
        local x1, z1 = VecUtil_RotateDir(BOUNDARY_MINX - DEPLOY_GAP, BOUNDARY_MINZ - DEPLOY_GAP, theta)
        local x2, z2 = VecUtil_RotateDir(BOUNDARY_MAXX + DEPLOY_GAP, BOUNDARY_MAXZ + DEPLOY_GAP, theta)
        local minx, maxx, minz, maxz = math.min(x1, x2), math.max(x1, x2), math.min(z1, z2), math.max(z1, z2)

        local ents = TheSim:FindEntities(x, 0, z, GOLFGAME_DIAGONAL_LENGTH, nil, DEPLOY_IGNORE_TAGS)
        for _, ent in ipairs(ents) do
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            local dx, dz = ex - x, ez - z
            if dx >= minx and dx <= maxx and dz >= minz and dz <= maxz then
                return false
            end
        end

        for _, offsets in ipairs(BLOCKER_POINTS) do
            local dx, dz = offsets[1], offsets[2]
            local dx2, dz2 = VecUtil_RotateDir(dx, dz, theta)
            local x2, z2 = x + dx2, z + dz2
            if not TheWorld.Map:IsAboveGroundAtPoint(x2, 0, z2, false) then
                return false
            end
        end

        return TheWorld.Map:CanDeployAtPoint(pt, inst, mouseover)
    end,
}

local function MakeGolfCourseKit(name, coursecodes_or_customize)
    local function OnDeploy(inst, pt, deployer, rotation)
        rotation = math.floor((rotation / GOLFGAME_NEARESTANGLE) + 0.5) * GOLFGAME_NEARESTANGLE
        local x = math.floor(pt.x) + .5
        local z = math.floor(pt.z) + .5
        local golfgame = SpawnPrefab(inst._prefab_to_deploy, inst.linked_skinname, inst.skin_id)
        golfgame.Transform:SetPosition(x, 0, z)
        golfgame.Transform:SetRotation(rotation)
        if coursecodes_or_customize == "CUSTOMIZABLE" then
            golfgame:SetIsCustomizable()
        else
			golfgame:LoadCourseData(coursecodes_or_customize[math.random(#coursecodes_or_customize)], false)
            golfgame:SetDifficulty(name)
        end
        golfgame:PushEvent("onbuilt", { builder = deployer, pos = pt, rot = rotation, deployable = inst })
        if deployer ~= nil and deployer.SoundEmitter ~= nil then
            deployer.SoundEmitter:PlaySound("dontstarve/common/place_golfkit")
        end
        inst:Remove()
    end

    local deployable_data_custom = shallowcopy(deployable_data)
    deployable_data_custom.ondeploy = OnDeploy

    return MakeDeployableKitItem("carnivalgame_golfgame_kit_"..name, "carnivalgame_golfgame", "carnivalgame_golfgame_kits", "carnivalgame_golfgame_kits", name, kit_assets, {size = "med", scale = 0.77}, {"usedeploystring"}, {fuelvalue = TUNING.MED_FUEL}, deployable_data_custom)
end

------------------------------------

local function placer_postinit(inst)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-3)
end

-- pre made course codes

local EASY_COURSES =
{
    -- all the cut outs
    "AQAAABAAAACsAgAACgEAAHjahZHLasMwEEV/pWQti3k/viaE4KaFNA7Gyab03ys522BvhMSdOZo7dx6Xx3z7+MUi5XA+zbfv5+l6Of2Mx8t0/Twu43goUAZtxxv5a7qu+nv5Pk/34/mxTI9FVgpW0LQItUBUKgNXbBcnMjXSbUS8EHs/ZS/jQttVCL1MKoiRuARRZpQBqiYjoAKKScg2xFfrNTRA2BxMhctANcU4gqSxI7cR1hFWTd1aA7YupkKVUYAITAh2ANgBVFGFFCHDmKLPEMDJhJEpuGODXqtwYLIARRTX9mbiNpSt8fg2gTsBKrtKppNyc9KXi+HZLAXuZatrttzicEdo3Q5IhWuyJjJES8X17x+wr84B",
    -- pop ups + springboards
    "AQAAABAAAAA8BQAA3gAAAHjalZRNDsIgFAavYlyDAfn1NAQr1iYUGqS6MN7dppq40eq36YZ5ZPKYtIQ6lrS6cSLJuvEldRcfW98H1+Z4dDWENWGEqunz4fiU43yuCf00PpQ8uD5futRefYxuH8cZ54QKDN/+gZdweNESojlCM8gb0oasOeQhkKsVtL2vdDPWPFY+52MWuPNQpltdykffhIPLKdSuf1a3sJPFKShG8V8Bb5xBNFCXQHoRREAe2EoUIkIhbYp5o2/5o0f1/F3JZUrOIemN0cYyu+OSWzkNbSzjxmhr1c5qcX8A09ngSw==",
    -- all course walls
    "AQAAABAAAACUCgAATwEAAHjapZVbasMwEEW3UvIthZnRK1pNMEFNAm4cXCcESvdeyS20tGmtWxn8d+54JB2PxjRdxtPDCyuvVrtuPB2vXb/vntJ2P/SP2ymllYq0pvIEL9FEp0hpuQc/H7pz2vbHU+Ibl5jStHaK81tFQ7BmhIZggfpYpHeX8Zqk4LzJvMusNosBvslcfxn/2o2FaAPRAtEM0QTRGsSxXjS2UI3togaOaPbFF15AnkGeMB7EwW7Axdb8S5nX38fYHLZV3/qZdQ1Z25A1DVmpzpa9DZh3AdMuYNYFSLoAORcg5UK9caQaDGsQrMGvBr3k/1FukHox+3keHzce19HzfAH49+Ly32H0e/g8DuccnYbLJLNUefr8jdmClfFGnoxEa4I4X+ZOjOQCkd8YF+29Pg9Dn0o4d8fOkd2YQMazMbk3G8VRiMbmEqb+WnfQrZ7p1zeC+FYW",
    -- rose + wormhole + small hallway
    "AQAAABAAAAAUCAAAeQEAAHjapZXbbsIwDIZfZeI6VD7l9DSogg6QSou6wiZNe/c5wM0mDmnTi6pS/y92nN/O0IynoXv7RiNmsa6Hbn+u2219aFbbvn1fjU2zMGIr0AcjeJbgzNIavife9a2qwVizvPv/Y1cfm1W77xr8woVZRrisC95R5KgUVrfXHJhLYCqB5SW8Pg3nR7SdQGOAG0AluXJJibmkxHNhzIejlgjyS6RyKChoyik7UBLyTJ9gdqBkkqS+76nj0B81ztifRkrNygZznZcWhGcpbPb1tu/q9kJct7uEmScOBR0JE1rquq1cdbzJ6XFtP/vhkCah5nfYj81G80PnKgrMAmIFtQl1gVe4YuIrCNYjCVNwqKnmYCqvApFzxJYtGXd3sv+PZalCG2N0wOTxMpZ8ZNLQLB5dSJNDP2IkieS8DXmOl3zH670xyeLuocUfqWGS+rlz/1hi6ggvuapkuv04VBCjBcc+oBetsQenRx3RexKXlkMR9OqZINb//AIw+oAk",
}
local MEDIUM_COURSES =
{
    -- course walls + lots of pop ups + small shortcut
    "AQAAABAAAACHDQAA4AEAAHjalZfdbuMgEEZfZdVrUzHDz8DTWN6UppEcO3LttNJq330xRWovNgnfRaJIOXwZ4DAmS1q3Zfr1hzrfPR2GZTpdh/E4nFN/nMfXfk3pqYu6053i/33//jZcUj+epkSfVEiln11H+dVEQ7AihIZghup4SB+25Zp4xylk3mVWmYcD6JNL/mP8ZzUWog1EM0QTRGuIViCO1aKwiSpsFRWwRcUXv/MM8gTyGuNBHKwGnGzLWcq8ipW3TfEFdxhuMdxgODfj+9IIpo1g1ggmjUDOCKSMQMZIuzC6w2zBZMFcwVR5aMr3JGs2tdHlzAH8VzgDB/Q2f1nmS3+er6fp+DGMY7+kl7JHHTfAv8ct7bSDaNWG10rUnVIO2zpva6hSmWCFmCmyCXvXiIGFRTstgcz9CNJfP/VsxEUfojGknSshJn8QdjqK97dC3i9Lrrqfp7SezqleMEyMeagNOjrJG+adj17IGx1cBIJyt7SWQxSJPg+OJUrnKWojpKNtdYDblald8Qb9No9lGzW0iya/AYqY3DahdMVgvAH4RrxWAxaDTfXOOlZ5pvl1OKSXb4nKzU5zdih6Fh+ylJKfG0SOWJw3VrKbrRpRexOsV8T2lqnbnyKlZd7mf6xH/W/l/v4DCjRzXg==",
    -- sectioned zone + spinners + sick wormhole
    "AQAAABAAAADYDwAAqgIAAHjapVbbattAEP2VkmfJ7Nz28jXCddREoIuR7aRQ+u+dlUJSiGXvev2wYDhzOzNzRnN7vszjjz9QuerpsJ/H7m3fv+yHtnmZ+l/N6XV/bJu+G1v4DU9VHczOxJ+zGChIVctOH6PPI8ZcYkwlxqbAuMQWCmyxwLaErJIu3RiP4zwdm6F97i7D6diNYzs3h/enymg89h5J2JEl9MqZE7Y2gA8sBNtpHC7zm+aBW7zjrRoWY4xFgDcrnpJqjnC3W0OkozELTXczX+Cmsru1X/ddB7M0R1LBnAOmZPDVKefHl4sf32ku0BLeHvH3aR5epz66GLpz+6wuPO0YUcg7cYSsVLkQdOiNVadO2XOgg+9ISEBsSufD2vpH5bCA9Pou619ZxnGu0/P8hEMeHPPgicv1vXJbwJoU2HKBLRXYlhyg+tblO7dtFC8tzLJnVp1no3KvjbTGi7XoGVxwWxt2GvZ9/3lD1iOCGp5Y98ixAMSdEsLA5FDES0i8R6svzR2I9PiwFeNdUOeegw8BA+iDaXktrpQFLc+zoJPoSf+j42CJnA/Gbno6zt34ss6sdk9DW/FoCDB2UytFq2qiXAXecnG4nKfLmdYjEZDZoRp40iRiW0BCAAQTyGUoGaBmo8QIGG+ZKqsDljAdq1jVaXv6AaYcMKSt9Idq1lkXMx3NWWjKQmMWGrLQJgtdZ8LzcqnzCq3zWKzzWlTf7/+VY5fo/wtPmfjMe7exHf+pxLJIiiVWiSCVJ5UFHxvt0IIYAbTh+pf4KqLTm6rVu4pfM0eV0GnVoAnon/1lOQTmBnzN0K0aL+LYONUwzYojcQaArNNb4QXuqGkzje25G9bLA9qlaxxGuVsA+olGqo3WWA8gGGN5REvgSW5p5ncuarkukltkaGI15+BVhPHvPzVU71U=",
    -- a bunch of worm holes!
    "AQAAABAAAAA8DAAAagMAAHjapVZJbhtJEPzKwGeykfvyGoIjc2QBlCjQkmxg4L87qikfBG3dM31ogmRWVmRGRFadDw+P57u//uWNb75c7c93N0/74/X+9rC7Ph3/2X07HQ9fNrTZMl5v/P/92/7+sDve3B34J8+BNPnltTh6VfCW10SvCt7Kmui3g+/Pp/vd7enp5u76x/543J0PX8cK2iwJ/vv4eLhEbz8AcvV4fnqBRKdF0f2nTF1U5gjndeGyPrutSv5h9Neb/fXpbn+cV2ybJhpPhrT2My5dvJ6LLku2/2GN/E+YHwvxJaPyqSde6EXeNcUsxh+n8+3F8ltOxEVamoaLbrY2hTOzG6cVjSo5XBHgXt62IKXE5CXqrawdl2K9O1QklMswCTgsmAsfFLIEZsfUSKnkWcGAGZMGORk7aVOMkqOtorsBP+WznFDd7c3DsG31hCWUEi2VDFNOVFlsqkxuCbipJi4tHZW+PDOaG1OSq0uWyuitN7eEo52Ug1BUk14mUs6xoA9hqDuIxVPFZICN8WQrWi42vN/pSQWxFcsqtFwT6ehpUVMNuGaRieo1hysZXQipCGHqz8Gy1gT+R2dn2sGZBDergCOQN3yKTmDLMHPlFVDR10LnSK1ZmGeoIIgd6bGjza1miKHwI7EvaC0LlM6gBRqbq4cMkN2DqzqshoxVogwvmKZqOVxmSExAkaSC/dEIlAuSTA3vi+ka5TB2LILklqdO0AKtVpHmaEQMzgZAgcWAGhIjOEQjIbSsBRJz1Eky3KXIVJvY2HI8MlGYGJlDKWkQDfjFt3CDe3qMds1u07KMRbSkTA1bCmOmoFXQkBTMaExVlYOVxCeIoRjTZE3resKQg/W7QnVAA7YAJzPDs6YKUKHN2UxrnGQJmCqELoThzjVMi0qyCaNA5/ks1dgMnZLOJXPaIXm2EOrkwQoED7kksqhWj1kC6Y+RbeuGVE5lECcNk495D1t+DkdzYvDKwGLqDjSEc42zbIyihAzM8M+z6FY4myUnHJKCSgNKQuJEOYNZZZgZI0MoEnrAfvnZaSg/ZZyG8v6V4OFwuERAj/Jn0OF4MgNVYY0i3pTUq136ss0714hXJ6RPKErVeQhgiDpgGPRPvbQvs8fTjarR3ffnwesb6FbevMDP0VePD6fHB38O04/D+jlsq79+A8AxtNs=",
    -- diagonal shapes + spinners + springboards at corners
    "AQAAABAAAADfBAAAEwEAAHjapZPdjoMgFIRfZeM1NICi9WkIq9SS8GNQ2002++49aLNJu7Zi1gtu/GZy5jAENU7BfXxTVKGskcHpizSdtEp03pzEqFSGCMIcjpXfw1n2SrRadt5JQ79ohugRcHLgCDM40jS4JgcSv6pkdV7zuwFNNqgJmhUkWbEI0vnfWPSfqdjeUPnOTHhd0AffC+sv2nVXaYwIqo0KGu92m/4001IE4It9fLFnmNWoZ29mM7Zawtlr6AN4Ce/UqK1arouCYBeOX/JWtXqyQ6+dU0E0zTWOE1edKLjzL/HBwhae7Is3aR/wmS63dgMhcz73kXLGj1UND55vSTBogMPb4HPXywRR3Hr1pk+P3Cb2dwT+cwM7UKdu",
}
local HARD_COURSES =
{
    -- lots of winds and turns with some tight obstacles and tight timing
    "AQAAABAAAACCDQAACwIAAHjapZbdjuIwDIVfZTXXFNlO7NRPU3XZDoPUoahDmZVW++6btHDB8tOYgsQNx+6Xk+OkfXMc+v2PP7jS1dum7ve7U91u68+m2nbte/X1UR+aqt3tG/yNbyuFlV/zqnDxJ0vtTOrCKJ9n2Qz96QoG89RYnmkwuzvns6fukuRkk6NNDia5TW1DoTwXJxOdYYuMpk96MurRqAeb3ig30mRaXyisIX2CkDrlqdg2ij5XPSt+wuUeY310bZNClL63fx/67lB9dqfdfvtdt231sx1GdTCpi/vyO1EuHpOOzTfDsRuOlKR+HVBEAcT5IBIT4b2CigSVMsx0cKmDW5PnsnTqURh8yiAJO2EB4JLVP++BE4UDAgyEqOgx5d4zqyPBgLMY05r9mpgZBZjIy9hDHKlGDvZSls97+LNvEUA4lig60LQWBaG558MZwItSiMyOiX20EkFKklASRUdkZu/oMjuUf/bDOMEvz1luMU2D9hjs/8j2za/Rktg+X20SY9boXDjQNGip+9xe0dzF+wAlRBsN4A/kNyyzN9KxaRLxdQBSQiGgekYF71JxnBzyMbMcSnSZrx9jMDKvwvshzLznitsFzNVeX9oGUBijnnlhXzx4eRLRsJAz2YuWjS+u/FqtW1BLC2pxQW2xqHgJdbHEruLJPo2Hxdehj4dFte/e683laHH54niyuL//AKePTOc=",
    -- "Two Worlds"
    "AQAAABAAAADyCQAAqgIAAHjanVbZbhpBEPyViOdl1df08TUI4Y2NxCUMtqUo/56ehaDY4dj1CvFCdW1Nd3UN++5w3G9+/MJGmslivt8s3+ar5/m6mz1vVz9nry/zXTdbHPdvHX3QpEGHZlra0kw5vwYUeLSRj4sJEmIzlTvFh66bNNOAFupjSsGR6PzQ7XetlpsOP/CsTSs93dP2GU/fweNwvH4HD4PwcOrjQPRF/Ug4joPTMFtcGXIWDvQUnFx0Hb3bb3ez9+1+/bJdVYHr5aF7yhciYBuizmASBaur+Fb54njYHg90bnGwm3AJZHDNA4JgiSLF09Vyn0LOYsFCUFhNrXhOgDBCAL2UVORjvAHjrDTSeXS7pacDlf5A2iJa6kdiEI0UBahQiEQh2B5w4JkDjKKEZzoAcSqNkiySnYpsz4jJljaLIkxZ3M0aTforZ65V/Zvp6u89++tuv9w8n1FTHAS7iVp3T8vj+nW33Gy6/WzxXvHQchAgFwnvW5fZAEgBHlzNcPPcr+v5anXhOpHl5msOwVgA3DywjltDDTWtWkKGkfVcWQksaKFu1TaacQ3izI9NHqdGtEiKaXEL80LV9Vku5/E+4rCeI1+bq2aGiJ5WaJKC84B5d1Rf+X0KrRRyffb/JEhv+K+3Un+jycP0uSwLjsBDzz4Q/F8u4s3aT+swSZBlMAHm4FXJq3un/LhsGhmjRsxCHiVzMR2qwB4GIUZaA8/JyKCAOdIAJVMspU0TUFGiUiKDmtOWCMmR2upY2ZgU/u7AQ8a0QCV08uoHT8IMnzArHKDUj4KsOqeUtP0joyDUoXALTMIpULFk/lDLKDXWOJ0Hep/CKwO1cgn1bE2/AgNC8EssnNYvp+dpewMQDun/klBdbMXAVMMjNjmpcoshFxmw3japipO0XkC1Wb//AGJGDsE=",
    -- spider horde vs tentacles
    "AQAAABAAAACWDQAAFAMAAHjapVbbbhpLEPyVIz/vrvo+01+DiEMcSxgsbJxI0fn3U7M4yhHCZsLywNNUX6q7qveweT0edv/84kGGu/v1Yff4tt4+rJ82q4f99tvqdbO5G5Imar8Skpo++KCX3r58Xz9vVvfHw9tGfsrdUHNK/KoVY2EebPJhVPx9iN0+7jb8k++G8Txlg41+G1YWYHkBlhZgx0XgJVWPS+gal8xptCVgvwqeN3NGc6VhjOk95QXA9/0Wez8/Ujb3TA0XtTaX8ELckporXxLC82H/vHravz3uHn6st9vVYfO1xUI063j9ZXs8pbbL78+Z+NNLn7T+vJeL7+d6fuwPTycOxoJnURvTqeYFHH/Sx/9wTGViM5JSKDNQXheuojQhZIRthAPGfemwD8LOYVznKqULxlwmz1o0Q1Dq0JeMHWujpTILSBn6Uo0VFWZojcK1NEcLdvEioVy18QO3LEQJwtS0dozy3GD546leg9Lt0HEJdkHJJ6O6EasLsHYVe+Y0fnsy+Ytc59i/6LGVGTc8548t5P74uj++RrOymGqqcM00Noq2MagwpHLRin/9PAbT7IcyWanCZJaIVbHtysGJOJFw4q4YwMCMikUhY+gdIkQJXsOgxHolRn0vgxj+b0LhphCOuMMGHPHYQ3tCtCrMWUg0xedOVDE3Ld4Dp6lw81UjEALLw4dV4D4F7hSVq2z+LiFhQ8SltS3eQjB82tNgSLDdrjJgf6EJf5/zgkyLIHSi7hbZEwP846qyUvVs3YMJL6B1vq3iXTP1ieCXlFqLUIFiMufZwGxrH6GGQ6Ve2915b6RYcuDbAv1wFxkxMXtFWmxCzdp0a2L4Zmi3j7KnkbZbndsjOKwcTppNTZglpVWrodI5fgiQgqAmVxXS2cSzeFWi0z5cj0FTxQK2xSN1ni91G4QXnOBoUugcnmBhQqGopuK5u6gGjToGktY3PsFRNbgBmpLZlRLMlxP1Fy/phRiqkWaY4bwC7aiVrNdk+fJ8wHfbarf/tr4/feW1dXS4L4QBehQbnfAKI3wrQPTl80AnTQz+739b2RGn",
    -- windy and dragonfly + bearger attack, a little shortcut exists
    "AQAAABAAAADsDQAAhgIAAHjapVfbbtpAEP2VKs+2NTM7l92vQS5xCJLByIEkUtV/79hGapsAvhkheDhndq5n1m11vrTHH78wi9nTtmyP+/ey3pWHarNr6pfN22t5qjbbS/te4Sc+ZXmCArrHlFJIkuWhkIz8e5dc748DF7KcHYhzwDAHnM9Dz3IkfxhjnyDq4BhhwPaJGTf/PaGdW/2RS8iwgryGu8ZpGuU+78tdcyzrnh9TkfyJbIyEmIXRZP9H/3b8eHUfHi+jrfRgevR+157a5rR5O7X7427THKvz/lAN3SVFEP9VZVDqMk8BYgQLFoDtnqVD8+6WPsq63rTVc9fW7vp0MNwHby/n5nLWflI046mhdOiCGJIkVOMIXSNETf5fIykajY4bXcdNpo+bo2203t/QOAs9TYW+9tGgMryMG1ZwaQUXV3BhOXcFdYXHKxI1Xp+/IvGVqw+4r03dj5IWbAGDJsAo0vc3kQZlDGJMtMDlFe0o96n/KEa6Ou7qZQCiKBS8sslcGAOxgUHAqWqSe6BuDBMKe8gJAdULBlHdliQyCzzTlphGJGNGF1qvoIu2SAjMRqqzbEkBISViJZRI7haxMBgCc7pZm68i/LO+VINk8ww0jIrxsXkpt4PA55bJDOnmwhOqRsIaopp3S3AVN48RUrDJllj6fYjJ1xdH7aQcyTNDFIG6kgW3G4M8sjl0U+jdcnq3TpgpenpTJ1AGKUZW7wq5uR035+q6WB3s8+Ifwy4m6uXNUOPQT6JTpvd6+6Nps349duql+KaG4mIJxcUKisukjKZTIaPJLxa3PAyLsxKWlyLMu8l5jPfgH017GMQ9R5EiiV/xMEkEj24KK2ERKCU0nyxDlyAf2d9/AF6pTFI=",
}

local PLACER_FIXEDCAMERAOFFSET = {offset = 90, nearestangle = GOLFGAME_NEARESTANGLE}
return Prefab("carnivalgame_golfgame", fn, assets, prefabs),
    -- kits
    MakeGolfCourseKit("easy", EASY_COURSES),
    MakeGolfCourseKit("medium", MEDIUM_COURSES),
    MakeGolfCourseKit("hard", HARD_COURSES),
    MakeGolfCourseKit("diy", "CUSTOMIZABLE"),
    MakePlacer("carnivalgame_golfgame_kit_easy_placer", "carnivalgame_golfgame_turf", "carnivalgame_golfgame_turf", "turf", true, nil, true, nil, PLACER_FIXEDCAMERAOFFSET, nil, placer_postinit),
    MakePlacer("carnivalgame_golfgame_kit_medium_placer", "carnivalgame_golfgame_turf", "carnivalgame_golfgame_turf", "turf", true, nil, true, nil, PLACER_FIXEDCAMERAOFFSET, nil, placer_postinit),
    MakePlacer("carnivalgame_golfgame_kit_hard_placer", "carnivalgame_golfgame_turf", "carnivalgame_golfgame_turf", "turf", true, nil, true, nil, PLACER_FIXEDCAMERAOFFSET, nil, placer_postinit),
    MakePlacer("carnivalgame_golfgame_kit_diy_placer", "carnivalgame_golfgame_turf", "carnivalgame_golfgame_turf", "turf", true, nil, true, nil, PLACER_FIXEDCAMERAOFFSET, nil, placer_postinit)