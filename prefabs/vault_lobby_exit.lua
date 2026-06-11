local assets = {
    Asset("ANIM", "anim/vault_lobby_exit.zip"),
    Asset("ANIM", "anim/vault_ladder.zip"),
}
local prefabs = {
    "ceiling_rope",
    "rope",
}

local function OnCameraFocusDirty(inst)
	local player = TheFocalPoint.entity:GetParent()
	if inst.camerafocus:value() and player and
		TheWorld.Map:IsPointInVaultRoom(player.Transform:GetWorldPosition()) and
		TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition())
	then
		TheFocalPoint.components.focalpoint:StartFocusSource(inst, nil, nil, 20, 200, 5)
	else
		TheFocalPoint.components.focalpoint:StopFocusSource(inst)
	end
end

local function EnableCameraFocus(inst, enable)
	if enable and inst.trial and inst.trial:IsPillarGuardAggro() then
		enable = false --don't use camera focus if pillar guards are still in combat
	end
	if inst.camerafocustask then
		inst.camerafocustask:Cancel()
		inst.camerafocustask = nil
	end
	if enable ~= inst.camerafocus:value() then
		inst.camerafocus:set(enable)

		--Dedicated server does not need to focus camera
		if not TheNet:IsDedicated() then
			OnCameraFocusDirty(inst)
		end
	end
end

local function StartTravelSound(inst, doer)
    inst.SoundEmitter:PlaySound("dontstarve/cave/tentapiller_hole_enter") -- FIXME(JBK): rifts6 sounds
    doer:PushEvent("wormholetravel", WORMHOLETYPE.VAULTLOBBYEXIT) --Event for playing local travel sound
end

local function OnActivate(inst, doer)
    if doer:HasTag("player") then
        if doer.components.talker ~= nil then
            doer.components.talker:ShutUp()
        end
        --Sounds are triggered in player's stategraph
    elseif inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/cave/tentapiller_hole_enter") -- FIXME(JBK): rifts6 sounds
    end
end

local function SetExitTarget(inst, targetinst)
    local oldtarget = inst.components.teleporter:GetTarget()
    if oldtarget then
        inst:RemoveEventCallback("onremove", inst._exittarget_onremove, targetinst)
    end

    inst.components.teleporter:Target(targetinst)
    if not targetinst then
        inst.components.teleporter:SetEnabled(false)
        return
    end

    if inst.hadrope_fromload then
        inst.hadrope_fromload = nil
        inst.hadrope_callback = function()
            inst:RemoveEventCallback("entitywake", inst.hadrope_callback, targetinst)
            inst:RemoveEventCallback("entitysleep", inst.hadrope_callback, targetinst)
            inst.hadrope_callback = nil
            inst:AddRope()
        end
        inst:ListenForEvent("entitywake", inst.hadrope_callback, targetinst)
        inst:ListenForEvent("entitysleep", inst.hadrope_callback, targetinst)
    end
    inst.components.teleporter:SetEnabled(true)
    inst:ListenForEvent("onremove", inst._exittarget_onremove, targetinst)
end

local function CreateVaultLadderVisualFor(parent)
    local inst = CreateEntity()

    inst:AddTag("FX")
    --[[Non-networked entity]]
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("vault_ladder")
    inst.AnimState:SetBuild("vault_ladder")
    inst.AnimState:PlayAnimation(parent.hasrope:value() and "idle_rope" or "idle_empty")

    inst.entity:SetParent(parent.entity)
    return inst
end

local function OnHasRopeDirty(inst)
    if inst.ropevfx then
        inst.ropevfx.AnimState:PlayAnimation(inst.hasrope:value() and "idle_rope" or "idle_empty")
    end
end

local ARCHIVE_PILLAR_FINDRADIUS = 15
local ARCHIVE_PILLAR_MUSTTAGS = { "archive_pillar" }
local ARCHIVE_PILLAR_MUST_NUM_FOUND = 2 -- There should be 2 pillars found
local function GetAngleAwayFromPillars(target)
    local x, y, z = target.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, ARCHIVE_PILLAR_FINDRADIUS, ARCHIVE_PILLAR_MUSTTAGS)
    if #ents ~= ARCHIVE_PILLAR_MUST_NUM_FOUND then
        return false
    end
    local xs, zs = 0, 0
    for i = 1, #ents do
        local ex, ey, ez = ents[i].Transform:GetWorldPosition()
		local angle = target:GetAngleToPoint(ex, 0, ez) * DEGREES
		xs, zs = xs - math.cos(angle), zs - math.sin(angle)
    end
    return math.atan2(zs, xs) % TWOPI
end

local function GetRopeOffset(target)
    local theta = GetAngleAwayFromPillars(target)
    if theta then
        return Vector3(math.cos(theta) * 5, 0, math.sin(theta) * -5)
    else
        -- If we don't have the two archive pillars nearby, just do a find walkable offset (means the rope will move around every reload)
        --  but that's fine if we're in this bad case somehow.
        return FindWalkableOffset(target:GetPosition(), math.random() * TWOPI, 5, 8, true, false)
            or Vector3(1, 0, 0) -- Fallback...
    end
end

local function AddRope(inst)
    if inst.hasrope:value() then
        return false
    end

    local target = inst.components.teleporter:GetTarget()
    if not target then
        return false
    end

    local x, y, z = target.Transform:GetWorldPosition()
    local rope_offset = GetRopeOffset(target)
    local rope = SpawnPrefab("ceiling_rope")
    inst.rope = rope
    rope:ListenForEvent("onremove", inst._onroperemoved)
    rope.Transform:SetPosition(x + rope_offset.x, y, z + rope_offset.z)
    rope.persists = false
    rope:SetExitTarget(inst)
    inst:SetExitTarget(rope)
    if not rope:IsAsleep() then
        rope.AnimState:PlayAnimation("down")
        rope.AnimState:PushAnimation("idle_loop", true)
    end

    inst.hasrope:set(true)
    inst:RemoveTag("canrope")
    return true
end

local function RemoveRope(inst)
    -- FIXME(JBK): rifts7: If a player is climbing the rope and it is removed they will get stuck in a teleport void.
    -- This removing of the rope is not used yet so this will not be a case hit but it is a danger spot.
    if not inst.hasrope:value() then
        return false
    end

    if inst.components.lootdropper then
        inst.components.lootdropper:DropLoot()
    end

    if inst.rope then
        inst.rope:RemoveEventCallback("onremove", inst._onroperemoved)
        inst.rope:ScheduleForDelete()
        inst.rope = nil
    end

    inst.hasrope:set(false)
    inst:AddTag("canrope")
    return true
end

local function OnUsedRope(inst, rope, doer)
    if inst:AddRope() then
        if rope.components.stackable and rope.components.stackable:IsStack() then
            rope.components.stackable:Get():Remove()
        else
            rope:Remove()
        end
        return true
    end
    return false
end

local function SetOpen(inst)
	if inst.opentask then
		inst.opentask:Cancel()
		inst.opentask = nil
	end
	inst:RemoveEventCallback("animover", SetOpen)
    inst.cracks = nil
    inst:RemoveTag("NOCLICK")
	inst.AnimState:PlayAnimation("idle")
	if inst.Light then
		inst.Light:Enable(true)
	end
    inst.Physics:SetActive(true)
    inst.components.teleporter:SetEnabled(true)
	if inst.camerafocustask == nil and inst.camerafocus then
		EnableCameraFocus(inst, false)
	end
end

local function IsInVault(v)
	return TheWorld.Map:IsPointInVaultRoom(v.Transform:GetWorldPosition())
end

local function DoOpenAnim(inst)
	if inst.Light then
		inst.Light:Enable(true)
	end
	inst.Physics:SetActive(true)
	inst.SoundEmitter:PlaySound("dontstarve/common/together/rocks/crack")
	inst.SoundEmitter:PlaySound("rifts4/worm_boss/dirt_emerge")
	inst.AnimState:PlayAnimation("open")
	LaunchArea(inst, 1.8, 1, 0.75, 0.5, 1.5)
	inst:RemoveEventCallback("animover", SetOpen)
	inst:ListenForEvent("animover", SetOpen)
	if inst.camerafocus and IsInVault(inst) then
		EnableCameraFocus(inst, true)
		inst.camerafocustask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 0.4, EnableCameraFocus, false)
		ShakeAllCamerasWithFilter(IsInVault, CAMERASHAKE.FULL, 0.9, 0.03, 0.22, inst, 1000)
	elseif inst.camerafocustask then
		inst.camerafocustask:Cancel()
		inst.camerafocustask = nil
	end
end

local function Open(inst)
	if POPULATING then
		SetOpen(inst)
	elseif inst.opentask == nil then
		inst.opentask = inst:DoTaskInTime(1, DoOpenAnim)
		if inst.camerafocus and IsInVault(inst) then
			EnableCameraFocus(inst, true)
			ShakeAllCamerasWithFilter(IsInVault, CAMERASHAKE.FULL, 2, 0.025, 0.1, inst, 1000)
		end
	end
end

-- for key room exit
local function SetCracks(inst)
	if inst.opentask then
		inst.opentask:Cancel()
		inst.opentask = nil
	end
	inst:RemoveEventCallback("animover", SetOpen)
	inst.cracks = true
	inst:AddTag("NOCLICK")
	inst.AnimState:PlayAnimation("idle_crack")
	inst.Physics:SetActive(false)
	if inst.Light then
		inst.Light:Enable(false)
	end
	inst.components.teleporter:SetEnabled(false)
	EnableCameraFocus(inst, false)
	return inst
end

local function OnSave(inst, data)
    if inst.hasrope then
        if inst.hasrope:value() then
            data.hasrope = true
        end
    end
    if inst.cracks then
        data.cracks = true
    end
end

local function OnLoad(inst, data, ents)
    if data then
        if data.hasrope then
            if not inst:AddRope() then
                -- This entity loaded before the exit teleporter so reschedule the rope creation.
                inst.hadrope_fromload = true
            end
        end
        if data.cracks then
            SetCracks(inst)
        end
    end
end

local function MakeChasm(name, canrope, lobbyexit, keyroomexit)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

		if keyroomexit then
			inst.entity:AddLight()
			inst.Light:SetRadius(1.5)
			inst.Light:SetIntensity(0.2)
			inst.Light:SetFalloff(0.7)
			inst.Light:SetColour(180/255, 240/255, 255/255)
			inst.Light:Enable(false)

			inst.AnimState:SetLightOverride(0.25)

			inst.camerafocus = net_bool(inst.GUID, name..".camerafocus", "camerafocusdirty")
		end

        inst:AddTag("groundhole")
        inst:AddTag("blocker")

        inst.entity:AddPhysics()
        inst.Physics:SetMass(0)
        inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
    	inst.Physics:SetCollisionMask(
    		COLLISION.ITEMS,
    		COLLISION.CHARACTERS,
    		COLLISION.GIANTS
    	)
        inst.Physics:SetCylinder(1.8, 6)

        inst.AnimState:SetBank("vault_lobby_exit")
        inst.AnimState:SetBuild("vault_lobby_exit")
        inst.AnimState:PlayAnimation("idle")
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
        inst.AnimState:SetSortOrder(2)
        --NOTE: Shadows are on WORLD_BACKGROUND sort order 1
        --      Hole goes above to hide shadows
        --      Surface goes below to reveal shadows

        inst.MiniMapEntity:SetIcon("vault_lobby_exit.png")

        inst.Transform:SetEightFaced()

    	inst:SetDeploySmartRadius(3)

        if canrope then
            inst.hasrope = net_bool(inst.GUID, "vault_lobby_exit.hasrope", "hasropedirty")
            inst:AddTag("canrope")
            --Dedicated server does not need to spawn the local fx
            if not TheNet:IsDedicated() then
                inst.ropevfx = CreateVaultLadderVisualFor(inst)
                inst:ListenForEvent("hasropedirty", OnHasRopeDirty)
                inst.highlightchildren = {inst.ropevfx}
            end
        end

        inst.scrapbook_proxy = "vault_lobby_exit"

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
        	if inst.camerafocus then
        		inst:ListenForEvent("camerafocusdirty", OnCameraFocusDirty)
        	end
            return inst
        end

        inst.scrapbook_facing = FACING_LEFT

        inst:AddComponent("inspectable")

        local lootdropper = inst:AddComponent("lootdropper")
        lootdropper:SetLoot({"rope"})

        local teleporter = inst:AddComponent("teleporter")
        teleporter.onActivate = OnActivate
        teleporter.overrideteleportarrivestate = "abyss_drop"
        teleporter.offset = 3
        teleporter:SetSelfManaged(lobbyexit)
        teleporter:SetEnabled(false)
        inst.StartTravelSound = StartTravelSound
        inst:ListenForEvent("starttravelsound", inst.StartTravelSound) -- triggered by player stategraph

        inst.SetExitTarget = SetExitTarget
        inst._exittarget_onremove = function()
            inst:SetExitTarget(nil)
        end

        inst._onroperemoved = function()
            inst.rope = nil
        end

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad
        inst.AddRope = AddRope
        inst.RemoveRope = RemoveRope
        inst.OnUsedRope = OnUsedRope
        inst.SetCracks = SetCracks
        inst.Open = Open

        if lobbyexit then
            TheWorld:PushEvent("ms_register_vault_lobby_exit", inst)
        elseif keyroomexit then
            TheWorld:PushEvent("ms_register_vault_key_exit", inst)
            inst.components.teleporter.saveenabled = false
        end

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

return MakeChasm("vault_lobby_exit", true, true),
    MakeChasm("vault_key_exit", false, false, true)