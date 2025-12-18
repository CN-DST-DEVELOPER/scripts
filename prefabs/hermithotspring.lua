require("prefabutil")

local assets =
{
	Asset("ANIM", "anim/hermithotspring.zip"),
	Asset("MINIMAP_IMAGE", "hermithotspring_empty"),
}

local prefabs =
{
	"collapse_big",
}

local prefabs_constr =
{
	"hermithotspring",
	"construction_container",
	"collapse_big",
}

local PHYS_RAD = 2.15
local DEPLOY_SMART_RAD = 2.65 --recipe min_spacing/2

local function PushOutPhysicsObjects(inst)
	local fx = CreateEntity()

	fx:AddTag("CLASSIFIED")
	--[[Non-networked entity]]
	fx.entity:SetCanSleep(false)
	fx.persists = false

	fx.entity:AddTransform()
	fx.entity:AddPhysics()
	fx.Physics:SetMass(999999)
	fx.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
	fx.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.ITEMS,
		COLLISION.CHARACTERS,
		COLLISION.GIANTS
	)
	fx.Physics:SetCapsule(PHYS_RAD, 2)

	fx:DoTaskInTime(0, fx.Remove)

	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end

local function EnableBubbles(inst, enable)
	if enable then
		if inst.bubbles == nil then
			inst.bubbles = CreateEntity()

			inst.bubbles:AddTag("FX")
			--[[Non-networked entity]]
			--inst.bubbles.entity:SetCanSleep(false)
			inst.bubbles.persists = false

			inst.bubbles.entity:AddTransform()
			inst.bubbles.entity:AddAnimState()

			inst.bubbles.AnimState:SetBank("hermithotspring")
			inst.bubbles.AnimState:SetBuild("hermithotspring")

			inst.bubbles.entity:SetParent(inst.entity)
			inst.bubbles:ListenForEvent("animqueueover", EnableBubbles)
		end
	elseif inst.bubbles then
		inst.bubbles:Remove()
		inst.bubbles = nil
	end
end

local function DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("place") then
		inst._rockripples = false
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.rocks) do
			v.Transform:SetNoFaced()
			v.AnimState:PlayAnimation("rock_place_nofaced")
			v.AnimState:SetTime(t)
			v.AnimState:PushAnimation("rock_nofaced", false)
		end
		EnableBubbles(inst, false)
		PushOutPhysicsObjects(inst)
	elseif inst.AnimState:IsCurrentAnimation("glow_pre") then
		EnableBubbles(inst, true)
		inst.bubbles.AnimState:PlayAnimation("splash")
		local t = inst.AnimState:GetCurrentAnimationTime()
		local t1 = inst.bubbles.AnimState:GetCurrentAnimationLength()
		if t < t1 then
			inst.bubbles.AnimState:SetTime(t)
			inst.bubbles.AnimState:PushAnimation("bubble_pre")
			inst.bubbles.AnimState:PushAnimation("bubble_loop")
		else
			inst.bubbles.AnimState:PlayAnimation("bubble_pre")
			t = t - t1
			t1 = inst.bubbles.AnimState:GetCurrentAnimationLength()
			if t < t1 then
				inst.bubbles.AnimState:SetTime(t)
				inst.bubbles.AnimState:PushAnimation("bubble_loop")
			else
				inst.bubbles.AnimState:PlayAnimation("bubble_loop", true)
				inst.bubbles.AnimState:SetTime(t - t1)
			end
		end
	elseif inst.AnimState:IsCurrentAnimation("glow_loop") then
		EnableBubbles(inst, true)
		inst.bubbles.AnimState:PlayAnimation("bubble_loop", true)
	elseif inst.AnimState:IsCurrentAnimation("glow_pst") then
		if inst.bubbles then
			inst.bubbles.AnimState:PlayAnimation("bubble_pst")
			local t = inst.AnimState:GetCurrentAnimationTime()
			local t1 = inst.bubbles.AnimState:GetCurrentAnimationLength()
			if t < t1 then
				inst.bubbles.AnimState:SetTime(t)
			else
				EnableBubbles(inst, false)
			end
		end
	else
		EnableBubbles(inst, false)
	end
	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(DoSyncAnim)
	end
end

local function OnSyncAnim(inst)
	if not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(DoSyncAnim)
	end
end

local function OnSyncHit(inst)
	if inst.rocks[1].AnimState:IsCurrentAnimation(inst._rockripples and "rock_hit" or "rock_hit_nofaced") or
		inst.rocks[1].AnimState:IsCurrentAnimation(inst._rockripples and "rock" or "rock_nofaced")
	then
		inst._rockripples = inst.rockripples:value()
		if inst._rockripples then
			for _, v in pairs(inst.rocks) do
				v.Transform:SetEightFaced()
				v.AnimState:PlayAnimation("rock_hit")
				v.AnimState:PushAnimation("rock")
			end
		else
			for _, v in pairs(inst.rocks) do
				v.Transform:SetNoFaced()
				v.AnimState:PlayAnimation("rock_hit_nofaced")
				v.AnimState:PushAnimation("rock_nofaced", false)
			end
		end
	end
end

local function PushSyncAnim(inst)
	inst.syncanim:push()
	if inst.rocks then
		DoSyncAnim(inst)
	end
end

local function PushSyncHit(inst)
	inst.synchit:push()
	if inst.rocks then
		OnSyncHit(inst)
	end
end

local function OnRockRipplesDirty(inst)
	if inst._rockripples ~= inst.rockripples:value() then
		inst._rockripples = inst.rockripples:value()

		local rock1 = inst.rocks[1]
		if inst._rockripples then
			if rock1.AnimState:IsCurrentAnimation("rock_hit_nofaced") then
				local t = rock1.AnimState:GetCurrentAnimationTime()
				for _, v in ipairs(inst.rocks) do
					v.Transform:SetEightFaced()
					v.AnimState:PlayAnimation("rock_hit")
					v.AnimState:SetTime(t)
					v.AnimState:PushAnimation("rock")
				end
			else
				for _, v in ipairs(inst.rocks) do
					v.Transform:SetEightFaced()
					v.AnimState:PlayAnimation("rock", true)
				end
			end
		elseif rock1.AnimState:IsCurrentAnimation("rock_hit") then
			local t = rock1.AnimState:GetCurrentAnimationTime()
			for _, v in ipairs(inst.rocks) do
				v.Transform:SetNoFaced()
				v.AnimState:PlayAnimation("rock_hit_nofaced")
				v.AnimState:SetTime(t)
				v.AnimState:PushAnimation("rock_nofaced", false)
			end
		else
			for _, v in ipairs(inst.rocks) do
				v.Transform:SetNoFaced()
				v.AnimState:PlayAnimation("rock_nofaced")
			end
		end
	end
end

local function PushRockRipples(inst, enable)
	inst.rockripples:set(enable)
	if inst.rocks then
		OnRockRipplesDirty(inst)
	end
end

local function CreateRock(ripples, loop)
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("hermithotspring")
	inst.AnimState:SetBuild("hermithotspring")

	if ripples then
		inst.Transform:SetEightFaced()
		if loop then
			inst.AnimState:PlayAnimation("rock", true)
			inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
		else
			inst.AnimState:SetPercent("rock", math.random())
		end
	else
		inst.Transform:SetNoFaced()
		inst.AnimState:PlayAnimation("rock_nofaced")
	end

	return inst
end

local function RefreshRockSymbols(inst, skin_build)
	skin_build = skin_build or 0
	local x, _, z = inst.Transform:GetWorldPosition()
	local prng = PRNG_Uniform(math.floor(x + 0.5) * math.floor(z + 0.5))
	local vars = { 1 }
	for i = 2, 6 do
		table.insert(vars, prng:RandInt(#vars + 1), i)
	end
	for i, rock in ipairs(inst.rocks) do
		local rnd = prng:Rand()
		rnd = 1 + math.floor(rnd * rnd * #vars * 0.75)
		rnd = table.remove(vars, rnd)
		table.insert(vars, rnd)
		if skin_build ~= 0 then
			rock.AnimState:OverrideItemSkinSymbol("rock_1", skin_build, "rock_"..tostring(rnd), inst.GUID, "hermithotspring")
		elseif rnd == 1 then
			rock.AnimState:ClearOverrideSymbol("rock_1")
		else
			rock.AnimState:OverrideSymbol("rock_1", "hermithotspring", "rock_"..tostring(rnd))
		end
	end
	return prng
end

local function DoSpawnRocks(inst)
	if inst.highlightchildren == nil then
		inst.highlightchildren = {}
	end
	if inst.rocks == nil then
		inst.rocks = {}
		inst._rockripples = inst.rockripples == nil or inst.rockripples:value()
	end

	local num = 20
	local radius = 2.1
	local delta = TWOPI / num
	local angle = 0
	for i = 1, num do
		local rock = inst.rocks[i]
		if rock == nil then
			rock = CreateRock(inst._rockripples, inst.rockripples ~= nil)
			rock.entity:SetParent(inst.entity)
			rock.Transform:SetPosition(radius * math.cos(angle), 0, -radius * math.sin(angle))
			rock.Transform:SetRotation(angle * RADIANS)
			inst.rocks[i] = rock
			table.insert(inst.highlightchildren, rock)
		end
		angle = angle + delta
	end

	--Use the prng from AFTER randomizing rock variations, since that runs again when skin changes, whereas this doesn't.
	local prng = RefreshRockSymbols(inst, inst.skinid and inst.skinid:value() or inst:GetSkinBuild())
	for _, rock in ipairs(inst.rocks) do
		if prng:Rand() < 0.5 then
			rock.AnimState:Show("rocks")
			rock.AnimState:Hide("rocks_flip")
		else
			rock.AnimState:Hide("rocks")
			rock.AnimState:Show("rocks_flip")
		end
	end
end

local function OnSkinIdDirty(inst)
	RefreshRockSymbols(inst, inst.skinid:value())
end

local function OnHermitHotSpringSkinChanged(inst, skin_build)
	inst.skinid:set(skin_build or 0)
	if inst.rocks then
		RefreshRockSymbols(inst, skin_build)
	end
end

local function OnEntityWake(inst)
	inst.OnEntityWake = nil
	DoSpawnRocks(inst)
	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("hermithotspring.synchit", OnSyncHit)
		inst:ListenForEvent("hermithotspring.syncanim", OnSyncAnim)
		inst:ListenForEvent("rockripplesdirty", OnRockRipplesDirty)
		inst:ListenForEvent("skiniddirty", OnSkinIdDirty)
	end
	DoSyncAnim(inst)
end

--------------------------------------------------------------------------

local function OnBathingPoolTick_PerOccupant(inst, occupant, dt)
    if occupant.components.health then
        occupant.components.health:DoDelta(TUNING.HERMITHOTSPRING_HEALTH_PER_SECOND * dt, true, inst.prefab, true)
    end
    if occupant.components.sanity then -- Update sanity rate in case it shifts.
        local rate = TUNING.HERMITHOTSPRING_SANITY_PER_SECOND
        if TheWorld.Map:IsInLunacyArea(occupant.Transform:GetWorldPosition()) then
            rate = -rate
        end
        occupant.components.sanity.externalmodifiers:SetModifier(inst, rate)
    end
end

local function OnBathingPoolTick(inst)
    local bathingpool = inst.components.bathingpool
    if bathingpool then
        bathingpool:ForEachOccupant(OnBathingPoolTick_PerOccupant, TUNING.HERMITHOTSPRING_TICK_PERIOD)
    end
end

local function OnStartBeingOccupiedBy(inst, ent)
    if not inst.bathingpoolents then
        inst.bathingpoolents = {
            [ent] = true,
        }
        inst.bathingpooltask = inst:DoPeriodicTask(TUNING.HERMITHOTSPRING_TICK_PERIOD, OnBathingPoolTick)
    else
        inst.bathingpoolents[ent] = true
    end
    if ent.components.sanity then
        local rate = TUNING.HERMITHOTSPRING_SANITY_PER_SECOND
        if TheWorld.Map:IsInLunacyArea(ent.Transform:GetWorldPosition()) then
            rate = -rate
        end
        ent.components.sanity.externalmodifiers:SetModifier(inst, rate)
    end
end

local function OnStopBeingOccupiedBy(inst, ent)
    if inst.bathingpoolents then
        inst.bathingpoolents[ent] = nil
        if ent.components.sanity then
            ent.components.sanity.externalmodifiers:RemoveModifier(inst)
        end
        if next(inst.bathingpoolents) == nil then
            if inst.bathingpooltask then
                inst.bathingpooltask:Cancel()
                inst.bathingpooltask = nil
            end
            inst.bathingpoolents = nil
        end
    end
end

local function EnableBathingPool(inst, enable)
	if not enable then
		inst:RemoveComponent("bathingpool")
	elseif inst.components.bathingpool == nil then
		inst:AddComponent("bathingpool")
		inst.components.bathingpool:SetRadius(2)
        inst.components.bathingpool:SetOnStartBeingOccupiedBy(OnStartBeingOccupiedBy)
        inst.components.bathingpool:SetOnStopBeingOccupiedBy(OnStopBeingOccupiedBy)
	end
end

local function MakeEmpty(inst, placing)
	if inst.filltask then
		inst.filltask:Cancel()
		inst.filltask = nil
	end
	inst.Light:Enable(false)
	inst.MiniMapEntity:SetIcon("hermithotspring_empty.png")
	inst.components.timer:StopTimer("bathbombed")
	inst.components.watersource.available = false
	inst.components.bathbombable:DisableBathBombing()
	EnableBathingPool(inst, false)
	PushRockRipples(inst, false)

	if POPULATING or inst:IsAsleep() then
		inst.AnimState:PlayAnimation("empty")
	elseif placing then
		inst._onsleepcheckanim = true
		inst.AnimState:PlayAnimation("place")
		PushOutPhysicsObjects(inst)
	else
		inst._onsleepcheckanim = true
		inst.AnimState:PlayAnimation("drain")
		inst.AnimState:PushAnimation("empty", false)
		inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/refill")
	end
	PushSyncAnim(inst)
end

local function OnFinishFill(inst, force)
	if inst.filltask then
		inst.filltask:Cancel()
		inst.filltask = nil
	end
	inst.Light:Enable(false)
	inst.MiniMapEntity:SetIcon("hermithotspring.png")
	inst.components.watersource.available = true
	inst.components.bathbombable:Reset()
	EnableBathingPool(inst, false)
	PushRockRipples(inst, true)
	if force or not (inst.AnimState:IsCurrentAnimation("refill") or inst.AnimState:IsCurrentAnimation("glow_pst")) then
		inst.AnimState:PlayAnimation("idle", true)
		PushSyncAnim(inst)
	end
end

local function MakeFilled(inst)
	inst.components.timer:StopTimer("bathbombed")

	if POPULATING or inst:IsAsleep() then
		OnFinishFill(inst, true)
	elseif not inst.components.watersource.available then
		if inst.filltask == nil then
			inst.AnimState:PlayAnimation("refill")
			inst.AnimState:PushAnimation("idle")
			PushSyncAnim(inst)
			inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/refill")
			inst.filltask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() - 3 * FRAMES, OnFinishFill)
		end
	elseif inst.components.bathbombable.is_bathbombed then
		inst._onsleepcheckanim = true
		inst.AnimState:PlayAnimation("glow_pst")
		inst.AnimState:PushAnimation("idle")
		PushSyncAnim(inst)
		if inst.filltask then
			inst.filltask:Cancel()
		end
		inst.filltask = inst:DoTaskInTime(20 * FRAMES, OnFinishFill)
	else
		OnFinishFill(inst, true)
	end
end

local function OnTimerDone(inst, data)
	if data and data.name == "bathbombed" then
		MakeFilled(inst)
	end
end

local function OnBathBombed(inst)
	if inst.filltask then
		inst.filltask:Cancel()
		inst.filltask = nil
	end
	inst.Light:Enable(true)
	inst.MiniMapEntity:SetIcon("hermithotspring.png")
	inst.components.watersource.available = true
	EnableBathingPool(inst, true)
	PushRockRipples(inst, true)

	if not inst.components.timer:TimerExists("bathbombed") then
		inst.components.timer:StartTimer("bathbombed", TUNING.HERMITHOTSPRING_BATHBOMB_DURATION)
	end

	if not (POPULATING or inst:IsAsleep()) then
		inst.AnimState:PlayAnimation("glow_pre")
		inst.AnimState:PushAnimation("glow_loop")
		inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/small_splash")
		inst.SoundEmitter:PlaySound("turnoftides/common/together/water/hotspring/bathbomb")
	else
		inst.AnimState:PlayAnimation("glow_loop", true)
	end
	PushSyncAnim(inst)
end

local function GetHeat(inst)
	if not inst.components.watersource.available then
		inst.components.heater:SetThermics(false, false)
		return 0
	end
	inst.components.heater:SetThermics(true, false)
	return inst.components.bathbombable.is_bathbombed and TUNING.HOTSPRING_HEAT.ACTIVE or TUNING.HOTSPRING_HEAT.PASSIVE
end

local function ForceJumpOut(inst, ent)
	inst.components.bathingpool:LeavePool(ent)
end

local function OnHit(inst)--, worker, workleft, numworks)
	if not inst:IsAsleep() then
		if inst.components.bathingpool then
			inst.components.bathingpool:ForEachOccupant(ForceJumpOut)
		end
		PushSyncHit(inst)
	end
end

local function OnHammered(inst)--, worker)
	if not inst:IsAsleep() then
		local fx = SpawnPrefab("collapse_big")
		fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
		fx:SetMaterial("stone")
	end
	if inst.components.lootdropper then
		inst.components.lootdropper:DropLoot()
	end
	if inst.components.constructionsite then
		inst.components.constructionsite:DropAllMaterials()
	end
	inst:Remove()
end

local function OnBuilt2(inst)
	inst.builttask = nil
	if IsWithinHermitCrabArea(inst) then
		MakeFilled(inst)
	end
end

local function OnBuilt(inst)--, data)
	if not inst:IsAsleep() then
		MakeEmpty(inst, true)
		inst.builttask = inst:DoTaskInTime(0.5, OnBuilt2)
	end
end

local function OnEntitySleep(inst)
	if inst.builttask then
		inst.builttask:Cancel()
		OnBuilt2(inst)
	end
	if inst.filltask then
		OnFinishFill(inst, true)
	end
	if inst._onsleepcheckanim then
		inst._onsleepcheckanim = nil
		if inst.AnimState:IsCurrentAnimation("drain") then
			inst.AnimState:PlayAnimation("empty")
			PushSyncAnim(inst)
		elseif inst.AnimState:IsCurrentAnimation("glow_pst") then
			inst.AnimState:PlayAnimation("idle", true)
			PushSyncAnim(inst)
		end
	end
end

local function WithinAreaChanged(inst, iswithin)
	if inst.builttask == nil then
		local isempty = not (inst.components.watersource.available or inst.filltask)
		if iswithin then
			if isempty then
				MakeFilled(inst)
			end
		elseif not isempty then
			MakeEmpty(inst)
		end
	end
end

--------------------------------------------------------------------------

local function OnSave(inst, data)
	data.isbathbombed = inst.components.bathbombable.is_bathbombed and inst.components.timer:TimerExists("bathbombed") or nil
end

local function OnLoad(inst, data)--, ents)
	if data and data.isbathbombed then
		inst.components.bathbombable:OnBathBombed()
	end
end

local function DisplayNameFn(inst)
	return not inst:HasTag("watersource") and STRINGS.NAMES.HERMITHOTSPRING_ABANDONED or nil
end

local function GetStatus(inst, viewer)
	return (not inst.components.watersource.available and "EMPTY")
		or (inst.components.bathbombable.is_bathbombed and "BOMBED")
		or nil
end

--------------------------------------------------------------------------

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOY_SMART_RAD)
	MakePondPhysics(inst, PHYS_RAD)

	inst.MiniMapEntity:SetIcon("hermithotspring.png")

	inst.Light:Enable(false)
	inst.Light:SetRadius(3)
	inst.Light:SetIntensity(TUNING.HOTSPRING_GLOW.INTENSITY)
	inst.Light:SetFalloff(TUNING.HOTSPRING_GLOW.FALLOFF)
	inst.Light:SetColour(0.1, 1.6, 2)

	inst.AnimState:SetBank("hermithotspring")
	inst.AnimState:SetBuild("hermithotspring")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	inst:AddTag("hermithotspring")
	inst:AddTag("antlion_sinkhole_blocker")
	inst:AddTag("birdblocker")
	inst:AddTag("groundhole")
	inst:AddTag("structure")

	--HASHEATER (from heater component) added to pristine state for optimization
	inst:AddTag("HASHEATER")

	--watersource (from watersource component) added to pristine state for optimization
	inst:AddTag("watersource")

	inst.synchit = net_event(inst.GUID, "hermithotspring.synchit")
	inst.syncanim = net_event(inst.GUID, "hermithotspring.syncanim")
	inst.rockripples = net_bool(inst.GUID, "hermithotspring.rockripples", "rockripplesdirty")
	inst.rockripples:set(true)
	inst.skinid = net_hash(inst.GUID, "hermithotspring.syncid", "skiniddirty")

	inst.displaynamefn = DisplayNameFn

	if not TheNet:IsDedicated() then
		inst.OnEntityWake = OnEntityWake
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst.scrapbook_anim = "scrapbook"

	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("lootdropper")

	inst:AddComponent("heater")
	inst.components.heater.heatfn = GetHeat

	inst:AddComponent("watersource")

	inst:AddComponent("bathbombable")
	inst.components.bathbombable:SetOnBathBombedFn(OnBathBombed)

	inst:AddComponent("timer")

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(4)
	inst.components.workable:SetOnWorkCallback(OnHit)
	inst.components.workable:SetOnFinishCallback(OnHammered)

	inst:AddComponent("hauntable")
	inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

	inst:ListenForEvent("timerdone", OnTimerDone)
	inst:ListenForEvent("onbuilt", OnBuilt)

	MakeHermitCrabAreaListener(inst, WithinAreaChanged)

	inst.OnHermitHotSpringSkinChanged = OnHermitHotSpringSkinChanged
	inst.OnEntitySleep = OnEntitySleep
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad

	return inst
end

--------------------------------------------------------------------------

local function constr_DoSyncAnim(inst)
	if inst.AnimState:IsCurrentAnimation("construction_place") then
		local t = inst.AnimState:GetCurrentAnimationTime()
		for _, v in ipairs(inst.pegs) do
			v.AnimState:PlayAnimation("peg_place")
			v.AnimState:SetTime(t)
			v.AnimState:PushAnimation("peg_idle", false)
		end

		inst.hole.AnimState:PlayAnimation("construction_hole_place")
		inst.hole.AnimState:SetTime(t)
		inst.hole.AnimState:PushAnimation("empty", false)
	else
		inst.hole.AnimState:PlayAnimation("empty")

		if inst.AnimState:IsCurrentAnimation("construction_reveal") then
			local t = inst.AnimState:GetCurrentAnimationTime()
			for _, v in ipairs(inst.pegs) do
				v.AnimState:PlayAnimation("peg_reveal")
				v.AnimState:SetTime(t)
			end
		elseif not inst.pegs[1].AnimState:IsCurrentAnimation("peg_hit") then
			for _, v in ipairs(inst.pegs) do
				v.AnimState:PlayAnimation("peg_idle")
			end
		end
	end
	if inst.postupdating then
		inst.postupdating = nil
		inst.components.updatelooper:RemovePostUpdateFn(constr_DoSyncAnim)
	end
end

local function constr_OnSyncAnimDirty(inst)
	--true: "hit" anim syncs instantly
	--false: non-"hit" anim syncs in post update
	if inst.syncanim:value() then
		if inst.pegs[1].AnimState:IsCurrentAnimation("peg_idle") or
			inst.pegs[1].AnimState:IsCurrentAnimation("peg_hit")
		then
			for _, v in ipairs(inst.pegs) do
				v.AnimState:PlayAnimation("peg_hit")
				v.AnimState:PushAnimation("peg_idle", false)
			end
			if inst.postupdating then
				inst.postupdating = nil
				inst.components.updatelooper:RemovePostUpdateFn(constr_DoSyncAnim)
			end
		end
	elseif TheWorld.ismastersim then
		constr_DoSyncAnim(inst)
	elseif not inst.postupdating then
		inst.postupdating = true
		inst.components.updatelooper:AddPostUpdateFn(constr_DoSyncAnim)
	end
end

local function constr_PushSyncAnim(inst, anim)
	inst.syncanim:set_local(false)
	inst.syncanim:set(anim == "hit")
	if inst.pegs then
		constr_OnSyncAnimDirty(inst)
	end
end

local function constr_CreateHole()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("hermithotspring")
	inst.AnimState:SetBuild("hermithotspring")
	inst.AnimState:PlayAnimation("empty")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	inst.AnimState:SetFinalOffset(-1)

	return inst
end

local function constr_CreatePeg()
	local inst = CreateEntity()

	inst:AddTag("FX")
	--[[Non-networked entity]]
	--inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("hermithotspring")
	inst.AnimState:SetBuild("hermithotspring")

	return inst
end

local PEGS =
{
	{ r = 1.95,	dir = 2		},
	{ r = 2,	dir = 62	},
	{ r = 1.9,	dir = 115	},
	{ r = 1.8,	dir = 177	},
	{ r = 1.75,	dir = 237	},
	{ r = 1.8,	dir = 298	},
}

local function constr_OnSkinIdDirty(inst)
	local skin_build = inst.skinid:value()
	local x, _, z = inst.Transform:GetWorldPosition()
	local prng = PRNG_Uniform(math.floor(x + 0.5) * math.floor(z + 0.5))
	local vars = { 1 }
	for i = 2, 3 do
		table.insert(vars, prng:RandInt(#vars + 1), i)
	end
	local rnd1
	for i, peg in ipairs(inst.pegs) do
		local rnd
		if i == 6 then
			rnd = vars[1]
			if rnd == rnd1 then
				rnd = vars[2]
			end
		else
			rnd = prng:RandInt(#vars - 1)
			rnd = table.remove(vars, rnd)
			table.insert(vars, rnd)
			if i == 1 then
				rnd1 = rnd
			end
		end
		if skin_build ~= 0 then
			peg.AnimState:OverrideItemSkinSymbol("peg_1", skin_build, "peg_"..tostring(rnd), inst.GUID, "hermithotspring")
		elseif rnd == 1 then
			peg.AnimState:ClearOverrideSymbol("peg_1")
		else
			peg.AnimState:OverrideSymbol("peg_1", "hermithotspring", "peg_"..tostring(rnd))
		end
	end
end

local function constr_OnEntityWake(inst)
	inst.OnEntityWake = nil

	if inst.highlightchildren == nil then
		inst.highlightchildren = {}
	end
	inst.pegs = {}

	for i, v in ipairs(PEGS) do
		local peg = constr_CreatePeg()
		peg.entity:SetParent(inst.entity)
		inst.pegs[i] = peg
		table.insert(inst.highlightchildren, peg)

		local theta = v.dir * DEGREES
		peg.Transform:SetPosition(v.r * math.cos(theta), 0, -v.r * math.sin(theta))
		peg.Transform:SetRotation(v.dir)
	end

	inst.hole = constr_CreateHole()
	inst.hole.entity:SetParent(inst.entity)
	--don't add hole to highlightchildren

	if not TheWorld.ismastersim then
		inst:AddComponent("updatelooper")
		inst:ListenForEvent("syncanimdirty", constr_OnSyncAnimDirty)
		inst:ListenForEvent("skiniddirty", constr_OnSkinIdDirty)
	end
	constr_OnSkinIdDirty(inst)
	constr_DoSyncAnim(inst)
end

local function FinishConstruction(inst, builder)
	local pos = inst:GetPosition()
	local hotspring = SpawnPrefab("hermithotspring", inst:GetSkinBuild(), inst.skin_id)
	inst:Remove()
	hotspring.Transform:SetPosition(pos:Get())
	hotspring:PushEvent("onbuilt", { builder = builder or inst.builder, pos = pos })
end

local function OnConstructed(inst, doer)
	if inst.components.constructionsite:IsComplete() then
		if not (POPULATING or inst:IsAsleep()) then
			inst.components.constructionsite:Disable()
			inst.components.workable:SetWorkable(false)
			inst.AnimState:PlayAnimation("construction_reveal")
			inst.SoundEmitter:PlaySound("hookline_2/common/hotspring/build")
			constr_PushSyncAnim(inst, "reveal")
			inst.builder = doer
			inst:ListenForEvent("animover", FinishConstruction)
			inst.OnEntitySleep = FinishConstruction
		else
			FinishConstruction(inst, doer)
		end
	end
end

local function constr_OnBuilt(inst)
	if not inst:IsAsleep() then
		inst.AnimState:PlayAnimation("construction_place")
		inst.AnimState:PushAnimation("construction_idle", false)
		inst.SoundEmitter:PlaySound("hookline_2/common/hotspring/construction_place")
		constr_PushSyncAnim(inst, "place")
	end
end

local function constr_OnHit(inst)--, worker, workleft, numworks)
	inst.components.constructionsite:ForceStopConstruction()
	if not inst:IsAsleep() then
		constr_PushSyncAnim(inst, "hit")
	end
end

local function constr_OnHermitHotSpringSkinChanged(inst, skin_build)
	inst.skinid:set(skin_build or 0)
	if inst.pegs then
		constr_OnSkinIdDirty(inst)
	end
end

local function constr_OnLoadPostPass(inst)--, ents, data)
	OnConstructed(inst, nil)
end

local function constrfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst:SetDeploySmartRadius(DEPLOY_SMART_RAD)
	inst:SetPhysicsRadiusOverride(PHYS_RAD)
	--MakeObstaclePhysics(inst, PHYS_RAD)
	inst:AddTag("blocker")

	inst.MiniMapEntity:SetIcon("hermithotspring_constr.png")

	inst.AnimState:SetBank("hermithotspring")
	inst.AnimState:SetBuild("hermithotspring")
	inst.AnimState:PlayAnimation("construction_idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	--constructionsite (from constructionsite component) added to pristine state for optimization
	inst:AddTag("constructionsite")

	inst.syncanim = net_bool(inst.GUID, "hermithotspring_constr.syncanim", "syncanimdirty")
	inst.skinid = net_hash(inst.GUID, "hermithotspring_constr.skinid", "skiniddirty")

	if not TheNet:IsDedicated() then
		inst.OnEntityWake = constr_OnEntityWake
	end

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	--inst:AddComponent("lootdropper")

	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_container")
	inst.components.constructionsite:SetOnConstructedFn(OnConstructed)

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(4)
	inst.components.workable:SetOnWorkCallback(constr_OnHit)
	inst.components.workable:SetOnFinishCallback(OnHammered)

	inst:ListenForEvent("onbuilt", constr_OnBuilt)

	MakeHauntableWork(inst)

	inst.OnHermitHotSpringSkinChanged = constr_OnHermitHotSpringSkinChanged
	inst.OnLoadPostPass = constr_OnLoadPostPass

	return inst
end

--------------------------------------------------------------------------

local function placer_postinit(inst)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)
	DoSpawnRocks(inst)
	inst.OnHermitHotSpringSkinChanged = RefreshRockSymbols
	for _, v in ipairs(inst.rocks) do
		inst.components.placer:LinkEntity(v)
	end
end

--------------------------------------------------------------------------

return Prefab("hermithotspring", fn, assets, prefabs),
	Prefab("hermithotspring_constr", constrfn, assets, prefabs_constr),
	MakePlacer("hermithotspring_constr_placer", "hermithotspring", "hermithotspring", "placer", true, nil, nil, nil, nil, nil, placer_postinit)
