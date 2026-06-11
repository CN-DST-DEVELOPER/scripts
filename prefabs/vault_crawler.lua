local assets =
{
	Asset("ANIM", "anim/vault_crawler.zip"),
}

local brain = require("brains/vault_crawlerbrain")

local CRAWLER_TAGS

local function RetargetFn(inst)
	if inst.sg == nil then
		return
	end

	local x, y, z = inst.Transform:GetWorldPosition()
	local inroom = TheWorld.Map:IsPointInVaultRoom(x, y, z)
	local rangesq = math.huge
	local closestPlayer
	for _, v in ipairs(AllPlayers) do
		if not IsEntityDeadOrGhost(v) and v.entity:IsVisible() then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if inroom == TheWorld.Map:IsPointInVaultRoom(x1, y1, z1) then
				local distsq = math2d.DistSq(x, z, x1, z1)
				if distsq < rangesq then
					rangesq = distsq
					closestPlayer = v
				end
			end
		end
	end
	return closestPlayer
end

local function KeepTargetFn(inst, target)
	if inst.sg == nil then
		return false --socketed
	elseif not inst.components.combat:CanTarget(target) then
		return false
	end
	return TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition()) == TheWorld.Map:IsPointInVaultRoom(target.Transform:GetWorldPosition())
end

local function OnAttacked(inst, data)
	if data and data.attacker and data.attacker:IsValid() and
		TheWorld.Map:IsPointInVaultRoom(inst.Transform:GetWorldPosition()) == TheWorld.Map:IsPointInVaultRoom(data.attacker.Transform:GetWorldPosition())
	then
		if data.attacker.sg and data.attacker.sg:HasStateTag("vault_crawler_dropping") then
			--ignore crawler AOE when they fall from ceiling
			return
		end
		inst.components.combat:SetTarget(data.attacker)
		inst.components.combat:ShareTarget(data.attacker, 30, function(dude) return dude.sg ~= nil end, 4, CRAWLER_TAGS)
	end
end

local function teleport_override_fn(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsPointInVaultRoom(x, y, z) then
		return Vector3(x, y, z)
	end
end

local LIGHT_RADIUS = 4.5
local LIGHT_INTENSITY = 0.7
local LIGHT_FALLOFF = 0.8
local LIGHT_COLOUR = RGB(180, 240, 255)
local FADE_LEN = 0.5
local FADE_ANIM_START_T = 22 * FRAMES

local function OnUpdateFadeOut(inst, dt)
	inst._t = inst._t + dt
	if inst._t < FADE_LEN then
		local k = 1 - inst._t / FADE_LEN
		k = k * k
		inst.Light:SetIntensity(LIGHT_INTENSITY * k)
	else
		inst.Light:Enable(false)
		inst:RemoveComponent("updatelooper")
	end
end

local function OnFadeOut(inst)
	if inst.fadeout:value() then
		local t = inst.AnimState:IsCurrentAnimation("death") and inst.AnimState:GetCurrentAnimationTime() or 0
		if t < FADE_ANIM_START_T + FADE_LEN then
			inst:AddComponent("updatelooper")
			inst.components.updatelooper:AddOnUpdateFn(OnUpdateFadeOut)
			inst._t = math.max(0, t - FADE_ANIM_START_T)
		else
			inst.Light:Enable(true)
			inst:RemoveComponent("updatelooper")
		end
	else
		inst.Light:SetIntensity(LIGHT_INTENSITY)
		inst.Light:Enable(true)
		inst:RemoveComponent("updatelooper")
	end
end

local function SetSocketed(inst, socket)
	if socket then
		if inst.sg then
			if not inst.sg:HasStateTag("socketed") then
				inst.sg:GoToState("socketed", socket) --force cleanup state b4 removing sg
				return
			end
			inst:ClearStateGraph()
			inst:StopBrain("socketed")
			inst:AddTag("notarget")
			inst.components.health:SetInvincible(true)
			inst.components.combat:DropTarget()
			if POPULATING then
				inst.AnimState:PlayAnimation("plate_activated", true)
				inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
			else
				inst.AnimState:PlayAnimation("roll_activate_pst")
				inst.AnimState:PushAnimation("plate_activated")
			end
			inst.AnimState:SetFinalOffset(-1)
			inst.Physics:SetActive(false)
			inst.Physics:Teleport(socket.Transform:GetWorldPosition())
			inst.socket = socket
			socket:SetIsSocketed(true)
		end
	else
		if inst.socket then
			if inst.socket:IsValid() then
				inst.socket:SetIsSocketed(false)
			end
			inst.socket = nil
		end
		if inst.sg == nil then
			inst:RemoveTag("notarget")
			inst.components.health:SetInvincible(false)
			inst.AnimState:SetFinalOffset(0)
			inst.Physics:SetActive(true)
			inst:SetStateGraph("SGvault_crawler")
			inst:RestartBrain("socketed")
			inst.sg:GoToState("hide_idle")
		end
	end
end

local function OnRemoveEntity(inst)
	if inst.socket and inst.socket:IsValid() then
		inst.socket:SetIsSocketed(false)
	end
end

local SOCKET_TAGS

local function FindSocket(inst, r)
	if SOCKET_TAGS == nil then
		SOCKET_TAGS = { "vault_crawler_socket" }
	end
	return FindEntity(inst, r, nil, SOCKET_TAGS)
end

local function OnSave(inst, data)
	data.socketed = inst.sg == nil or nil
end

local function OnLoadPostPass(inst, ents, data)
	if data and data.socketed then
		local socket = FindSocket(inst, 0.2)
		if socket then
			inst:SetSocketed(socket)
		end
	end
end

local function GetStatus(inst)--, viewer)
	return inst.sg == nil and "SOCKETED" or nil
end

local HIGHLIGHT_OVERRIDE = { 0.09, 0.09, 0.09 }
local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddDynamicShadow()
	inst.entity:AddLight()
	inst.entity:AddNetwork()

	inst:AddTag("monster")
	inst:AddTag("hostile")
	inst:AddTag("soulless")
	inst:AddTag("mech")
	inst:AddTag("electricdamageimmune")
	inst:AddTag("vault_crawler")

	inst.DynamicShadow:SetSize(2.5, 1.5)

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("vault_crawler")
	inst.AnimState:SetBuild("vault_crawler")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

	inst.Light:SetRadius(LIGHT_RADIUS)
	inst.Light:SetIntensity(LIGHT_INTENSITY)
	inst.Light:SetFalloff(LIGHT_FALLOFF)
	inst.Light:SetColour(unpack(LIGHT_COLOUR))
	inst.Light:EnableClientModulation(true)

	inst.fadeout = net_bool(inst.GUID, "vault_crawler.fadeout", "onfadeoutdirty")
	inst:ListenForEvent("onfadeoutdirty", OnFadeOut)

	MakeCharacterPhysics(inst, 100, 0.8)
	inst.Physics:ClearCollidesWith(COLLISION.GIANTS)

	inst.highlightoverride = HIGHLIGHT_OVERRIDE
	inst.highlightflashaddoverride = .1

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("locomotor")
	inst.components.locomotor.walkspeed = TUNING.VAULT_CRAWLER_SPEED
	inst.components.locomotor.runspeed = TUNING.VAULT_CRAWLER_SPEED

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(TUNING.VAULT_CRAWLER_HEALTH)
	inst.components.health:SetMinHealth(1)
	inst.components.health.nofadeout = true

	inst:AddComponent("combat")
	inst.components.combat.hiteffectsymbol = "body"
	inst.components.combat:SetDefaultDamage(TUNING.VAULT_CRALWER_DAMAGE)
	inst.components.combat:SetRange(TUNING.VAULT_CRAWLER_ATTACK_RANGE, TUNING.VAULT_CRAWLER_HIT_RANGE)
	inst.components.combat:SetHitArc(TUNING.VAULT_CRAWLER_HIT_ARC)
	inst.components.combat:SetAttackPeriod(TUNING.VAULT_CRAWLER_ATTACK_PERIOD)
	inst.components.combat:SetRetargetFunction(3, RetargetFn)
	inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

	inst:AddComponent("drownable")

	inst:AddComponent("damagetypebonus")
	inst:AddComponent("damagetyperesist")

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)

	inst:AddComponent("knownlocations")
	inst:AddComponent("savedrotation")

	--MakeMediumFreezableCharacter(inst, "body")
	MakeHauntable(inst)

	if CRAWLER_TAGS == nil then
		CRAWLER_TAGS = { "vault_crawler" }
	end
	inst:ListenForEvent("attacked", OnAttacked)

	inst:SetStateGraph("SGvault_crawler")
	inst:SetBrain(brain)

	inst.FindSocket = FindSocket
	inst.SetSocketed = SetSocketed
	inst.OnRemoveEntity = OnRemoveEntity
	inst.OnSave = OnSave
	inst.OnLoadPostPass = OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

local function socket_CreateFront()
	local inst = CreateEntity()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("vault_crawler")
	inst.AnimState:SetBuild("vault_crawler")
	inst.AnimState:PlayAnimation("plate_open_activated_front", true)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	return inst
end

local function socket_OnUpdateCollisionRadius(inst)
	if inst._shrink then
		local r = math.max(0, inst.socket.socketphysrad:value() - inst._shrink)
		inst._shrink = nil
		inst._grow = nil
		inst.socket:SetSocketRadius(r)
	elseif inst._grow then
		local r = inst.socket.socketphysrad:value() + inst._grow
		if r < (inst.socket.issocketed:value() and 1.3 or 1) then
			inst.socket:SetSocketRadius(r)
			inst._grow = inst._grow * 1.3
		else
			inst.socket:SetSocketRadius(1) --revert to radius 1
			inst._task:Cancel()
			inst._task = nil
			inst._grow = nil
		end
	else
		inst._grow = 0.003
	end
end

local function socket_OnCollide(inst, other, x, y, z, x1, y1, z1, nx, ny, nz, lifetime_in_frames)
	local t = GetTick()
	if inst._last_t ~= t and
		(nx ~= 0 or nz ~= 0) and
		other and other.prefab == "vault_crawler" and other.sg and other.sg:HasStateTag("rolling") and
		other:IsValid() and inst:IsValid()
	then
		local rot = other.Transform:GetRotation()
		local rot1 = math.atan2(-nz, nx) * RADIANS
		local diff = DiffAngle(rot, rot1)
		if diff < 90 then
			inst._last_t = t
			inst._shrink = inst.socket.issocketed:value() and 0 or math.max(inst._delta or 0, Remap(DiffAngle(rot, rot1), 0, 90, 0.1, 0))
			if inst._task == nil then
				inst._task = inst:DoPeriodicTask(0, socket_OnUpdateCollisionRadius)
			end
		end
	end
end

local function CreateSocketPhysics()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false) --commented out; follow parent sleep instead
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddPhysics()

	inst.Physics:SetMass(0)
	inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
	inst.Physics:SetCollisionMask(COLLISION.CHARACTERS)

	if TheWorld.ismastersim then
		inst.Physics:SetCollisionCallback(socket_OnCollide)
	end

	return inst
end

local function socket_OnSocketPhysRadDirty(inst)
	if inst.socketphys then
		if inst.socketphysrad:value() > 0 then
			inst.socketphys.Physics:SetCapsule(inst.socketphysrad:value(), 2)
			inst.socketphys.Physics:SetActive(true)
		else
			inst.socketphys.Physics:SetActive(false)
		end
	end
end

local function socket_SetSocketRadius(inst, r)
	if inst.socketphysrad:value() ~= r then
		inst.socketphysrad:set(r)
		socket_OnSocketPhysRadDirty(inst)
	end
end

local function socket_OnOpenAnimOver(inst)
	inst:RemoveEventCallback("animover", socket_OnOpenAnimOver)
	inst.AnimState:PlayAnimation("plate_open_back")
	inst:AddTag("vault_crawler_socket")
end

local EPIC_TAGS

local function socket_DoOpenSocket(inst)
	if inst.opentask then
		inst.opentask:Cancel()
		inst.opentask = nil
	end
	if inst.AnimState:IsCurrentAnimation("plate_closed_idle") then
		if not inst.Physics:IsActive() then
			inst:SetSocketRadius(1)
			inst.Physics:SetActive(true)
		end
		if POPULATING then
			socket_OnOpenAnimOver(inst)
		else
			inst:ListenForEvent("animover", socket_OnOpenAnimOver)
			inst.AnimState:PlayAnimation("plate_open_pre")
			inst.SoundEmitter:PlaySound("rifts7/plate/open")
		end
		LaunchArea(inst, 1, 0.75, 0.5, 0.3, 0.75)
	end
end

local function socket_DoTryOpenSocket(inst)
	--socket radius 1 + pillar guard radius 1.6
	if FindEntity(inst, 2.6, nil, EPIC_TAGS) == nil then
		socket_DoOpenSocket(inst)
	end
end

local function socket_TryOpenSocket(inst)
	if inst.opentask == nil and inst.AnimState:IsCurrentAnimation("plate_closed_idle") then
		if EPIC_TAGS == nil then
			EPIC_TAGS = { "epic" }
		end
		inst.opentask = inst:DoPeriodicTask(1, socket_DoTryOpenSocket)
		if POPULATING then
			socket_DoTryOpenSocket(inst)
		end
	end
end

local function socket_IsSocketedDirty(inst)
	if not TheNet:IsDedicated() then
		if inst.issocketed:value() then
			if inst.front == nil then
				inst.front = socket_CreateFront()
				inst.front.entity:SetParent(inst.entity)
			end
		elseif inst.front then
			inst.front:Remove()
			inst.front = nil
		end
	end
end

local function socket_SetIsSocketed(inst, socketed)
	if socketed then
		if not inst.issocketed:value() then
			inst.issocketed:set(true)
			inst:RemoveEventCallback("animover", socket_OnOpenAnimOver)
			inst.AnimState:PlayAnimation("plate_open_back")
			inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
			if not POPULATING then
				inst.SoundEmitter:PlaySound("rifts7/plate/activate")
			end
			inst:RemoveTag("vault_crawler_socket")
			socket_IsSocketedDirty(inst)
			if not inst.Physics:IsActive() then
				inst:SetSocketRadius(1)
				inst.Physics:SetActive(true)
			end
			if inst.opentask then
				inst.opentask:Cancel()
				inst.opentask = nil
			end
			inst:PushEvent("ms_vaultsocketed_changed")
		end
	elseif inst.issocketed:value() then
		inst.issocketed:set(false)
		inst.AnimState:ClearBloomEffectHandle()
		inst:AddTag("vault_crawler_socket")
		socket_IsSocketedDirty(inst)
		inst:PushEvent("ms_vaultsocketed_changed")
	end
end

local function socket_IsSocketed(inst)
	return inst.issocketed:value()
end

local function socket_OnEntityWake(inst)
	inst.OnEntityWake = nil

	if inst._pfx == nil and inst:GetCurrentPlatform() == nil then
		local _
		inst._pfx, _, inst._pfz = inst.Transform:GetWorldPosition()
		for dx = -1, 1 do
			for dz = -1, 1 do
				TheWorld.Pathfinder:AddWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
	end
	if inst.socketphys == nil then
		inst.socketphys = CreateSocketPhysics()
		inst.socketphys.socket = inst
		inst.socketphys.Transform:SetPosition(inst.Transform:GetWorldPosition())
		socket_OnSocketPhysRadDirty(inst)
	end
end

local function socket_OnRemoveEntity(inst)
	if inst._pfx then
		for dx = -1, 1 do
			for dz = -1, 1 do
				TheWorld.Pathfinder:RemoveWall(inst._pfx + dx, 0, inst._pfz + dz)
			end
		end
		inst._pfx, inst._pfz = nil, nil
	end
	if inst.socketphys then
		inst.socketphys:Remove()
		inst.socketphys = nil
	end
end

local function socket_OnSave(inst, data)
	data.socketed = inst.issocketed:value() or nil
end

local function socket_OnLoad(inst, data)
	if data and data.socketed then
		socket_DoOpenSocket(inst)
	end
end

local function socket_OnLoadPostPass(inst, ents, data)
	if data and data.socketed and not inst.issocketed:value() then
		if CRAWLER_TAGS == nil then
			CRAWLER_TAGS = { "vault_crawler" }
		end
		local crawler = FindEntity(inst, 0.2, nil, CRAWLER_TAGS)
		if crawler then
			crawler:SetSocketed(inst)
		end
	end
end

local function socketfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(1.25)
	MakePondPhysics(inst, 1):SetCollisionGroup(COLLISION.BOAT_LIMITS)
	inst.Physics:SetActive(false)

	inst.AnimState:SetBank("vault_crawler")
	inst.AnimState:SetBuild("vault_crawler")
	inst.AnimState:PlayAnimation("plate_closed_idle")
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-2)

	--Not using NOCLICK because we do want to block mouse
	--Not using decor/FX because we do want to block placement
	--Some actions will highlight targets even if not a valid action:
	--  "nomagic" blocks SPELLCAST (e.g. reskin_tool)
	--  "nohighlight" blocks complexprojectile (e.g. bombs)
	inst:AddTag("nomagic")
	inst:AddTag("nohighlight")
	--inst:AddTag("vault_crawler_socket") --only tagged when open

	inst.socketphysrad = net_float(inst.GUID, "vault_crawler_socket.socketphysrad", "socketphysraddirty")
	inst.socketphysrad:set(0)

	inst.issocketed = net_bool(inst.GUID, "vault_crawler_socket.issocketed", "issocketeddirty")

	inst.OnEntityWake = socket_OnEntityWake
	inst.OnRemoveEntity = socket_OnRemoveEntity

    inst.scrapbook_inspectonseen = true

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		inst:ListenForEvent("socketphysraddirty", socket_OnSocketPhysRadDirty)
		inst:ListenForEvent("issocketeddirty", socket_IsSocketedDirty)

		return inst
	end

	inst.scrapbook_anim = "plate_open_back"

	inst.SetSocketRadius = socket_SetSocketRadius
	inst.SetIsSocketed = socket_SetIsSocketed
	inst.IsSocketed = socket_IsSocketed
	inst.TryOpenSocket = socket_TryOpenSocket
	inst.OnSave = socket_OnSave
	inst.OnLoad = socket_OnLoad
	inst.OnLoadPostPass = socket_OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

return Prefab("vault_crawler", fn, assets),
	Prefab("vault_crawler_socket", socketfn, assets)
