local assets =
{
	Asset("ANIM", "anim/abyss_pillar.zip"),
}

local prefabs =
{
	"abysspillar_fx",
}

--------------------------------------------------------------------------

local RADIUS = 0.6
local PLAYER_COLLISION_MESH
local ITEM_COLLISION_MESH

local function GetPlayerCollisionMesh()
	if PLAYER_COLLISION_MESH == nil then
		PLAYER_COLLISION_MESH = {}

		local segment_count = 8
		local segment_span = TWOPI / segment_count
		local y0 = 0
		local y1 = 3

		for segement_idx = 0, segment_count do
			local angle = segement_idx * segment_span
			local angle0 = angle - segment_span / 2
			local angle1 = angle + segment_span / 2

			local x0 = math.cos(angle0) * RADIUS
			local z0 = math.sin(angle0) * RADIUS

			local x1 = math.cos(angle1) * RADIUS
			local z1 = math.sin(angle1) * RADIUS

			table.insert(PLAYER_COLLISION_MESH, x0)
			table.insert(PLAYER_COLLISION_MESH, y0)
			table.insert(PLAYER_COLLISION_MESH, z0)

			table.insert(PLAYER_COLLISION_MESH, x0)
			table.insert(PLAYER_COLLISION_MESH, y1)
			table.insert(PLAYER_COLLISION_MESH, z0)

			table.insert(PLAYER_COLLISION_MESH, x1)
			table.insert(PLAYER_COLLISION_MESH, y0)
			table.insert(PLAYER_COLLISION_MESH, z1)

			table.insert(PLAYER_COLLISION_MESH, x1)
			table.insert(PLAYER_COLLISION_MESH, y0)
			table.insert(PLAYER_COLLISION_MESH, z1)

			table.insert(PLAYER_COLLISION_MESH, x0)
			table.insert(PLAYER_COLLISION_MESH, y1)
			table.insert(PLAYER_COLLISION_MESH, z0)

			table.insert(PLAYER_COLLISION_MESH, x1)
			table.insert(PLAYER_COLLISION_MESH, y1)
			table.insert(PLAYER_COLLISION_MESH, z1)
		end
	end
	return PLAYER_COLLISION_MESH
end

local function GetItemCollisionMesh()
	if ITEM_COLLISION_MESH == nil then
		ITEM_COLLISION_MESH = {}

		local segment_count = 8
		local segment_span = TWOPI / segment_count
		local y0 = 0
		local y1 = 0.5

		for segement_idx = 0, segment_count do
			local angle = segement_idx * segment_span
			local angle0 = angle - segment_span / 2
			local angle1 = angle + segment_span / 2

			local x0 = math.cos(angle0) * RADIUS
			local z0 = math.sin(angle0) * RADIUS

			local x1 = math.cos(angle1) * RADIUS
			local z1 = math.sin(angle1) * RADIUS

			table.insert(ITEM_COLLISION_MESH, x0)
			table.insert(ITEM_COLLISION_MESH, y0)
			table.insert(ITEM_COLLISION_MESH, z0)

			table.insert(ITEM_COLLISION_MESH, 0)
			table.insert(ITEM_COLLISION_MESH, y1)
			table.insert(ITEM_COLLISION_MESH, 0)

			table.insert(ITEM_COLLISION_MESH, x1)
			table.insert(ITEM_COLLISION_MESH, y0)
			table.insert(ITEM_COLLISION_MESH, z1)
		end
	end
	return ITEM_COLLISION_MESH
end

local function CreatePlayerCollision()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	--inst:AddTag("CLASSIFIED")
	inst:AddTag("blocker")
	--inst:AddTag("NOBLOCK")
	inst:AddTag("NOCLICK")
	inst:AddTag("ignorewalkableplatforms")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst:SetPhysicsRadiusOverride(RADIUS)
	inst:SetDeploySmartRadius(RADIUS)

	inst.entity:AddPhysics()
	inst.Physics:SetMass(0)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(5)
	inst.Physics:SetRestitution(0)
	inst.Physics:SetCollisionGroup(COLLISION.BOAT_LIMITS)
	inst.Physics:SetCollisionMask(COLLISION.CHARACTERS)
	inst.Physics:SetTriangleMesh(GetPlayerCollisionMesh())

	return inst
end

local function CreateItemCollision()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")
	--inst:AddTag("NOBLOCK")
	inst:AddTag("NOCLICK")
	inst:AddTag("ignorewalkableplatforms")
	--[[Non-networked entity]]
	inst.entity:SetCanSleep(TheWorld.ismastersim)
	inst.persists = false

	inst.entity:AddPhysics()
	inst.Physics:SetMass(0)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(0)
	inst.Physics:SetRestitution(1)
	inst.Physics:SetCollisionGroup(COLLISION.BOAT_LIMITS)
	inst.Physics:SetCollisionMask(COLLISION.ITEMS)
	inst.Physics:SetTriangleMesh(GetItemCollisionMesh())

	return inst
end

--used by fx prefab as well
local function AlignToWall(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
    local x1, z1 = math.floor(x) + 0.5, math.floor(z) + 0.5
	inst.Transform:SetPosition(x1, 0, z1)
	if inst.player_collision then
		inst.player_collision.Physics:Teleport(x1, 0, z1)
	end
	if inst.item_collision then
		inst.item_collision.Physics:Teleport(x1, 0, z1)
	end
end

--used by fx prefab as well
local function AlignToTile(inst)
	local x, _, z = inst.Transform:GetWorldPosition()
	local x1, _, z1 = TheWorld.Map:GetTileCenterPoint(x, 0, z)
	x1 = x > x1 and x1 + 2 or x1 - 2
	z1 = z > z1 and z1 + 2 or z1 - 2
	inst.Transform:SetPosition(x1, 0, z1)
	if inst.player_collision then
		inst.player_collision.Physics:Teleport(x1, 0, z1)
	end
	if inst.item_collision then
		inst.item_collision.Physics:Teleport(x1, 0, z1)
	end
end

--used by fx prefab as well
local function Flip(inst)
	inst.flipped = true
	inst.AnimState:SetScale(-1, 1)
	if inst.abovefx then
		inst.abovefx:Flip()
	end
end

--------------------------------------------------------------------------

local PillarStates =
{
	EMPTY =			0,
	OCCUPIED =		1,
	WARNING =		2,
	COLLAPSE =		3,
	FORMING =		4,
	FORMING_DELAY =	5,
	FORMING_ABOVE = 6,
}

local OCCUPIED_TO_WARNING_TIME = 4
local WARNING_TO_COLLAPSE_TIME = 2

local function SwitchIdleAnim(inst)
	if inst.AnimState:IsCurrentAnimation("idle_a") then
		inst.AnimState:PlayAnimation("transition_a_b")
		inst.AnimState:PushAnimation("idle_b", false)
	else
		inst.AnimState:PlayAnimation("transition_b_a")
		inst.AnimState:PushAnimation("idle_a", false)
	end
	inst.idletask = inst:DoTaskInTime(25 + math.random() * 10, SwitchIdleAnim)
end

local function RestartIdleTask(inst)
	inst.idletask = inst:DoTaskInTime(math.random() * 30, SwitchIdleAnim)
end

local function PreRestartIdleTask(inst)
	inst.SoundEmitter:KillSound("loop")
	RestartIdleTask(inst)
end

local function SetState(inst, state)
	if inst.state ~= state then
		if inst.state == PillarStates.OCCUPIED and not state == PillarStates.EMPTY then
			inst.SoundEmitter:KillSound("loop")
		end

		inst.state = state

		if inst.idletask then
			inst.idletask:Cancel()
			inst.idletask = nil
		end
		if inst.occupiedtask then
			inst.occupiedtask:Cancel()
			inst.occupiedtask = nil
		end

		if state == PillarStates.EMPTY then
			if inst.components.walkableplatform:IsFull() then
				inst.components.walkableplatform:SetIsFull(false)
				if not inst:IsAsleep() then
					local suffix = math.random() < 0.5 and "_a" or "_b"
					inst.AnimState:PlayAnimation("place"..suffix)
					inst.AnimState:SetFrame(34)
					inst.AnimState:PushAnimation("idle"..suffix)
					inst.idletask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() - 34 * FRAMES, PreRestartIdleTask)
				else
					inst.AnimState:PlayAnimation(math.random() < 0.5 and "idle_a" or "idle_b")
					inst.SoundEmitter:KillSound("loop")
				end
			else
				inst.AnimState:PlayAnimation(math.random() < 0.5 and "idle_a" or "idle_b")
				inst.SoundEmitter:KillSound("loop")
				if not inst:IsAsleep() then
					RestartIdleTask(inst)
				end
			end
		elseif state == PillarStates.OCCUPIED then
			if not inst:IsAsleep() then
				inst.AnimState:PlayAnimation("hit")
				inst.AnimState:PushAnimation("occupied")
				inst.SoundEmitter:PlaySound("rifts6/rock_pillar/land_jump")
				inst.SoundEmitter:PlaySound("rifts6/rock_pillar/wobble_lp", "loop", 0.3)
			else
				inst.AnimState:PlayAnimation("occupied", true)
				inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
			end
			inst.components.walkableplatform:SetIsFull(true)
		elseif state == PillarStates.COLLAPSE then
			if not (inst:IsAsleep() or POPULATING) and inst.entity:IsVisible() then
				local fx = SpawnPrefab("abysspillar_fx")
				fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
				fx.SoundEmitter:PlaySound("rifts6/rock_pillar/fall")
				if inst.flipped then
					fx:Flip()
				end
			end
			local teleport_pt
			local excluding = {}
			for k in pairs(inst.components.walkableplatform:GetEntitiesOnPlatform()) do
				if k.components.drownable then
					if teleport_pt == nil then
						if inst._abysspillargroup and inst._abysspillargroup.inst:IsValid() then
							if inst._abysspillargroup.inst.spawnx then
								teleport_pt = Vector3(inst._abysspillargroup.inst.spawnx, 0, inst._abysspillargroup.inst.spawnz)
							else
								teleport_pt = inst._abysspillargroup.inst:GetPosition()
							end
						else
							teleport_pt = Vector3(FindRandomPointOnShoreFromOcean(inst.Transform:GetWorldPosition()))
						end
					end
					if k.sg and k.sg:HasState("abyss_fall") then
						excluding[k] = true
					end
				end
				k:PushEvent("onfallinvoid", { teleport_pt = teleport_pt })
			end
			inst.components.walkableplatform:DestroyObjectsOnPlatform(excluding)
			inst:Remove()
		else
			assert(false)
		end
	end
end

local function DoPlayerCollapseImminent(inst)
	inst.AnimState:PlayAnimation("occupied_warning", true)
	if inst:IsAsleep() then
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	end
	if inst.SoundEmitter:PlayingSound("loop") then
		inst.SoundEmitter:SetVolume("loop", 1)
	end
	inst.occupiedtask = inst:DoTaskInTime(WARNING_TO_COLLAPSE_TIME, SetState, PillarStates.COLLAPSE)
end

local function ShouldChildTriggerCollapse(child)
	return child.components.locomotor ~= nil
		and child.components.locomotor.triggerscreep
		and not child:HasTag("flying")
end

local function OnAddPlatformFollower(inst, child)
	if ShouldChildTriggerCollapse(child) then
		if inst.state == PillarStates.EMPTY then
			SetState(inst, PillarStates.OCCUPIED)
			if child.isplayer then
				if inst.occupiedtask == nil and not inst.nocollapse then
					inst.occupiedtask = inst:DoTaskInTime(OCCUPIED_TO_WARNING_TIME, DoPlayerCollapseImminent)
				end
				inst:PushEvent("abysspillar_playeroccupied", child)
			end
		end
		child:PushEvent("startteetering")
	end
end

local function OnRemovePlatformFollower(inst, child)
	if ShouldChildTriggerCollapse(child) then
		if inst.state == PillarStates.OCCUPIED then
			if inst.occupiedtask then
				inst.occupiedtask:Cancel()
				inst.occupiedtask = nil
			end
			if inst.nocollapse then
				SetState(inst, PillarStates.EMPTY)
			else
				inst.occupiedtask = inst:DoTaskInTime(0, SetState, PillarStates.COLLAPSE)
			end
			if child.isplayer then
				inst:PushEvent("abysspillar_playervacated", child)
			end
		end
		child:PushEvent("stopteetering")
	end
end

local function DoPopTeleportPt(ent, trial)
	trial._fall_tp_overrides[ent] = nil
	if ent.components.drownable then
		ent.components.drownable:PopTeleportPt(trial)
	end
end

local function TryToReservePlatform(inst, ent)
	if inst.state == PillarStates.EMPTY and not inst.components.walkableplatform:IsFull() then
		inst.components.walkableplatform:SetIsFull(true)
		if ent and ent.components.drownable then
			local trial = inst._abysspillargroup and inst._abysspillargroup.inst
			if trial and trial:IsValid() then
				if trial._fall_tp_overrides == nil then
					trial._fall_tp_overrides = {}
				end
				if trial._fall_tp_overrides[ent] then
					trial._fall_tp_overrides[ent]:Cancel()
				else
					ent.components.drownable:PushTeleportPt(
						trial,
						trial.spawnx and
						Vector3(trial.spawnx, 0, trial.spawnz) or
						trial:GetPosition()
					)
				end
				trial._fall_tp_overrides[ent] = ent:DoTaskInTime(1, DoPopTeleportPt, trial)
			end
		end
		return true
	end
end

local function TryToClearReservedPlatform(inst, ent)
	if inst.state == PillarStates.EMPTY and inst.components.walkableplatform:IsFull() then
		inst.components.walkableplatform:SetIsFull(false)
		return true
	end
end

local function CollapsePillar(inst)
	SetState(inst, PillarStates.COLLAPSE)
end

local function MakeNonCollapsible(inst)
    inst:AlignToWall()
    if inst.abovefx then
        inst.abovefx:AlignToWall()
    end
	inst.nocollapse = true
    inst._ispathfinding:set(true)
end

--------------------------------------------------------------------------

local function OnEntityWake_Client(inst)
	if inst.player_collision == nil then
		inst.player_collision = CreatePlayerCollision()
		local x, y, z = inst.Transform:GetWorldPosition()
		inst.player_collision.Transform:SetPosition(x, 0, z)
	end
	inst.OnEntityWake = nil
end

local function OnEntityWake_Server(inst)
	if inst.player_collision == nil then
		inst.player_collision = CreatePlayerCollision()
		inst.item_collision = CreateItemCollision()
		local x, y, z = inst.Transform:GetWorldPosition()
		inst.player_collision.Transform:SetPosition(x, 0, z)
		inst.item_collision.Transform:SetPosition(x, 0, z)
	end
	if inst.sleeptask then
		inst.sleeptask:Cancel()
		inst.sleeptask = nil
	else
		inst.components.walkableplatform:StartUpdating()
		if inst.state == PillarStates.EMPTY and inst.idletask == nil then
			RestartIdleTask(inst)
		end
		if inst.state == PillarStates.OCCUPIED and not inst.SoundEmitter:PlayingSound("loop") then
			inst.SoundEmitter:PlaySound("rifts6/rock_pillar/wobble_lp", "loop", not inst.AnimState:IsCurrentAnimation("occupied_warning") and 0.3 or nil)
		end
	end
end

local function OnSleepTask_Server(inst)
	inst.sleeptask = nil
	inst.components.walkableplatform:StopUpdating()
	if inst.idletask then
		inst.idletask:Cancel()
		inst.idletask = nil
		--if going from Occupied -> Empty, we use part of the place anim as the transition back to idle
		if inst.AnimState:IsCurrentAnimation("place_a") then
			inst.AnimState:PlayAnimation("idle_a")
		elseif inst.AnimState:IsCurrentAnimation("place_b") then
			inst.AnimState:PlayAnimation("idle_b")
		end
	end
	inst.SoundEmitter:KillSound("loop")
end

local function OnEntitySleep_Server(inst)
	if inst.sleeptask == nil then
		inst.sleeptask = inst:DoTaskInTime(1, OnSleepTask_Server)
	end
end

--Server & client
local function AddPathfindingToTile(x1, z1, x2, z2)
    if TheWorld.Map:IsVisualGroundAtPoint(x2, 0, z2) then
        local points = BresenhamLineXZtoXZ(x1, z1, x2, z2)
        for i, point in ipairs(points) do
            TheWorld.Pathfinder:AddStaticHoppablePlatform(point.x, 0, point.z)
        end
    end
end
local function RemovePathfindingToTile(x1, z1, x2, z2)
    if TheWorld.Map:IsVisualGroundAtPoint(x2, 0, z2) then
        local points = BresenhamLineXZtoXZ(x1, z1, x2, z2)
        for i, point in ipairs(points) do
            TheWorld.Pathfinder:RemoveStaticHoppablePlatform(point.x, 0, point.z)
        end
    end
end
local PILLAR_MUST_TAGS = {"abysspillar"}
local function OnIsPathFindingDirty(inst)
    local HOP_DISTANCE = inst.components.walkableplatform.max_hop_distance
    if inst._ispathfinding:value() then
        if inst._pfpos == nil and inst:GetCurrentPlatform() == nil then
            inst.components.walkableplatform.player_only = false
            inst._pfpos = inst:GetPosition()
            local x, y, z = inst._pfpos:Get()
            local ents = TheSim:FindEntities(x, y, z, HOP_DISTANCE, PILLAR_MUST_TAGS)
            for _, v in ipairs(ents) do
                local ex, ey, ez = v.Transform:GetWorldPosition()
                if x == ex or ez == z then -- Only connect orthogonal connections!
                    local points = BresenhamLineXZtoXZ(x, z, ex, ez)
                    for _, point in ipairs(points) do
                        TheWorld.Pathfinder:AddStaticHoppablePlatform(point.x, 0, point.z)
                    end
                end
            end
            AddPathfindingToTile(x, z, x - HOP_DISTANCE, z)
            AddPathfindingToTile(x, z, x + HOP_DISTANCE, z)
            AddPathfindingToTile(x, z, x, z - HOP_DISTANCE)
            AddPathfindingToTile(x, z, x, z + HOP_DISTANCE)
        end
    elseif inst._pfpos ~= nil then
        inst.components.walkableplatform.player_only = true
        local x, y, z = inst._pfpos:Get()
        local ents = TheSim:FindEntities(x, y, z, HOP_DISTANCE, PILLAR_MUST_TAGS)
        for _, v in ipairs(ents) do
            local ex, ey, ez = v.Transform:GetWorldPosition()
            if x == ex or ez == z then -- Only connect orthogonal connections!
                local points = BresenhamLineXZtoXZExcludeCaps(x, z, ex, ez, false, true)
                for _, point in ipairs(points) do
                    TheWorld.Pathfinder:RemoveStaticHoppablePlatform(point.x, 0, point.z)
                end
            end
        end
        RemovePathfindingToTile(x, z, x - HOP_DISTANCE, z)
        RemovePathfindingToTile(x, z, x + HOP_DISTANCE, z)
        RemovePathfindingToTile(x, z, x, z - HOP_DISTANCE)
        RemovePathfindingToTile(x, z, x, z + HOP_DISTANCE)
        inst._pfpos = nil
    end
end
local function InitializePathFinding(inst)
    inst:ListenForEvent("onispathfindingdirty", OnIsPathFindingDirty)
    OnIsPathFindingDirty(inst)
end
local function OnRemoveEntity(inst)
	if inst.player_collision then
		inst.player_collision:Remove()
		inst.player_collision = nil
	end
	if inst.item_collision then
		inst.item_collision:Remove()
		inst.item_collision = nil
	end
	--V2C: If we had something on our platform at removal, then we may have started a new
	--     task again in OnRemovePlatformFollower.
	--     - inst still returns as Valid at that point.
	--     - It is past EntityScript's call to CancelAllPendingTasks().
	inst:CancelAllPendingTasks()
    inst._ispathfinding:set_local(false)
    OnIsPathFindingDirty(inst)
end

local function OnSave(inst, data)
	data.collapse = inst.state ~= PillarStates.EMPTY or nil
	data.nocollapse = inst.nocollapse or nil
end

local function OnLoad(inst, data)--, ents)
	if math.random() < 0.5 then
		inst:Flip()
	end
	if math.random() < 0.5 then
		inst.AnimState:PlayAnimation("idle_b")
	end
	if data then
		if data.collapse then
			inst:Hide()
			inst:DoTaskInTime(0, SetState, PillarStates.COLLAPSE)
		end
        if data.nocollapse then
            inst:MakeNonCollapsible()
        end
	end
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("abyss_pillar")
	inst.AnimState:SetBuild("abyss_pillar")
	inst.AnimState:PlayAnimation("idle_a")
	inst.AnimState:SetLayer(LAYER_BELOW_GROUND)

	inst:AddTag("NOCLICK")
	--inst:AddTag("blocker") --doesn't work since it's a platform; moved to the player collision entity
	inst:AddTag("ignorewalkableplatforms")
	inst:AddTag("abysspillar")
	inst:AddTag("teeteringplatform")

	inst.walksound = "dirt"

	inst:AddComponent("walkableplatform")
	inst.components.walkableplatform.platform_radius = RADIUS
	inst.components.walkableplatform.max_hop_distance = TUNING.PILLAR_HOP_DISTANCE
	inst.components.walkableplatform.player_only = true
	inst.components.walkableplatform.no_mounts = true

    inst._ispathfinding = net_bool(inst.GUID, "_ispathfinding", "onispathfindingdirty")
    inst:DoTaskInTime(0, InitializePathFinding)

	inst.entity:SetPristine()

	inst.OnRemoveEntity = OnRemoveEntity

	if not TheWorld.ismastersim then
		inst.OnEntityWake = OnEntityWake_Client

		return inst
	end

	inst.state = PillarStates.EMPTY
	--inst.nocollapse = nil

	inst.OnEntityWake = OnEntityWake_Server
	inst.OnEntitySleep = OnEntitySleep_Server
	inst.AlignToTile = AlignToTile
    inst.AlignToWall = AlignToWall
	inst.Flip = Flip
	inst.OnAddPlatformFollower = OnAddPlatformFollower
	inst.OnRemovePlatformFollower = OnRemovePlatformFollower
	inst.TryToReservePlatform = TryToReservePlatform
    inst.TryToClearReservedPlatform = TryToClearReservedPlatform
	inst.CollapsePillar = CollapsePillar
	inst.MakeNonCollapsible = MakeNonCollapsible
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	--V2C: don't randomize loop on construction because we may be spawned by FORMING fx

	return inst
end

--------------------------------------------------------------------------

local function fx_DoStackingPitch(inst, pitch)
	inst.SoundEmitter:SetParameter("stacking", "pitch", pitch)
end

local function fx_DoFinalStackingSound(inst)
	inst.stackingsoundtasks = nil
	inst.SoundEmitter:KillSound("stacking")
	inst.SoundEmitter:PlaySound("rifts6/rock_pillar/restack_last_rock")
end

local function fx_SetState(inst, state)
	if inst.state ~= state then
		if inst.state == PillarStates.FORMING_DELAY then
			inst:Show()
		elseif inst.state == PillarStates.FORMING_ABOVE then
			inst.AnimState:Show("below")
			inst.AnimState:SetLayer(LAYER_BELOW_GROUND)
		elseif inst.state == PillarStates.FORMING then
			if inst.stackingsoundtasks then
				for i, v in ipairs(inst.stackingsoundtasks) do
					v:Cancel()
				end
				inst.SoundEmitter:KillSound("stacking")
				inst.stackingsoundtasks = nil
			end
			inst.AnimState:Show("ABOVE")
		end

		if inst.state ~= PillarStates.FORMING_DELAY or state ~= PillarStates.FORMING then
			inst.group = nil
		end

		inst.state = state

		if inst.delaytask then
			inst.delaytask:Cancel()
			inst.delaytask = nil
		end

		if inst.abovefx then
			inst.abovefx:Remove()
			inst.abovefx = nil
		end

		if state == PillarStates.COLLAPSE then
			inst.persists = false
			inst.AnimState:PlayAnimation("collapse")
		elseif state == PillarStates.FORMING then
			inst.persists = true
			inst.AnimState:Hide("ABOVE")
			local anim = math.random() < 0.5 and "place_a" or "place_b"
			inst.AnimState:PlayAnimation(anim)
			inst.SoundEmitter:PlaySound("rifts6/rock_pillar/restack", "stacking")
			inst.stackingsoundtasks =
			{
				inst:DoTaskInTime(12 * FRAMES, fx_DoStackingPitch, 0.3),
				inst:DoTaskInTime(14 * FRAMES, fx_DoStackingPitch, 0.4),
				inst:DoTaskInTime(16 * FRAMES, fx_DoStackingPitch, 0.5),
				inst:DoTaskInTime(18 * FRAMES, fx_DoStackingPitch, 0.55),
				inst:DoTaskInTime(19 * FRAMES, fx_DoFinalStackingSound),
			}
			inst.abovefx = SpawnPrefab("abysspillar_fx")
			inst.abovefx.entity:SetParent(inst.entity)
			if inst.flipped then
				inst.abovefx:Flip()
			end
			fx_SetState(inst.abovefx, PillarStates.FORMING_ABOVE)
			inst.abovefx.AnimState:PlayAnimation(anim)
		elseif state == PillarStates.FORMING_ABOVE then
			inst.persists = false
			inst.AnimState:Hide("below")
			inst.AnimState:SetLayer(LAYER_WORLD)
		elseif state == PillarStates.FORMING_DELAY then
			inst.persists = true
			inst:Hide()
		else
			assert(false)
		end
	end
end

local function fx_StartForming(inst, group, delay)
	if delay then
		fx_SetState(inst, PillarStates.FORMING_DELAY)
		inst.delaytask = inst:DoTaskInTime(delay, fx_SetState, PillarStates.FORMING)
	else
		fx_SetState(inst, PillarStates.FORMING)
	end
	inst.group = group
end

local function fx_Finish(inst)
	if POPULATING then
		return
	elseif inst.state == PillarStates.COLLAPSE or inst.state == PillarStates.FORMING_ABOVE then
		inst:Remove()
		return
	elseif inst.state == PillarStates.FORMING_DELAY then
		if not inst:IsAsleep() then
			return
		end
	elseif inst.state ~= PillarStates.FORMING then
		assert(false)
		return
	end
	local pillar = SpawnPrefab("abysspillar")
	pillar.Transform:SetPosition(inst.Transform:GetWorldPosition())
	if inst.flipped then
		pillar:Flip()
	end
	if inst.AnimState:IsCurrentAnimation("place_b") then
		pillar.AnimState:PlayAnimation("idle_b", true)
	end
	if inst.group and inst.group:IsValid() then
		inst.group.components.abysspillargroup:StopTrackingPillar(inst)
		inst.group.components.abysspillargroup:StartTrackingPillar(pillar)
	end
	inst:Remove()
end

local function fx_OnSave(inst, data)
	if inst.group then
		data.group = inst.group.GUID
		return { inst.group.GUID }
	end
end

local function fx_OnLoadPostPass(inst, ents, data)
	local group = data and ents[data.group] or nil
	if group or not (data and data.group) then
		local pillar = SpawnPrefab("abysspillar")
		pillar.Transform:SetPosition(inst.Transform:GetWorldPosition())
		if math.random() < 0.5 then
			pillar:Flip()
		end
		if math.random() < 0.5 then
			pillar.AnimState:PlayAnimation("idle_b", true)
		end
		if group then
			group.entity.components.abysspillargroup:StopTrackingPillar(inst)
			group.entity.components.abysspillargroup:StartTrackingPillar(pillar)
		end
	end
	inst:Remove()
end

local function fxfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.AnimState:SetBank("abyss_pillar")
	inst.AnimState:SetBuild("abyss_pillar")
	inst.AnimState:PlayAnimation("collapse")
	inst.AnimState:SetLayer(LAYER_BELOW_GROUND)

	inst:AddTag("NOCLICK")
	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.persists = false
	inst.state = PillarStates.COLLAPSE

	inst:ListenForEvent("animover", fx_Finish)
	inst.StartForming = fx_StartForming
	inst.OnEntitySleep = fx_Finish
	inst.AlignToTile = AlignToTile
    inst.AlignToWall = AlignToWall
	inst.Flip = Flip
	inst.OnSave = fx_OnSave
	inst.OnLoadPostPass = fx_OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

return Prefab("abysspillar", fn, assets, prefabs),
	Prefab("abysspillar_fx", fxfn, assets)
