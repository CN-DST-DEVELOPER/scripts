require("stategraphs/commonstates")

local NUM_FX_VARIATIONS = 7
local MAX_RECENT_FX = 4
local MIN_FX_SCALE = .5
local MAX_FX_SCALE = 1.6

local function ToggleOffPhysics(inst)
    inst.sg.statemem.isphysicstoggle = true
	inst.Physics:SetCollisionMask(COLLISION.GROUND)
end

local function ToggleOnPhysics(inst)
    inst.sg.statemem.isphysicstoggle = nil
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.SMALLOBSTACLES,
		COLLISION.CHARACTERS,
		COLLISION.GIANTS
	)
end

local function ClearStatusAilments(inst)
    if inst.components.freezable ~= nil and inst.components.freezable:IsFrozen() then
        inst.components.freezable:Unfreeze()
    end
end

local function SpawnMoveFx(inst, scale)
    local fx = SpawnPrefab("hutch_move_fx")
    if fx ~= nil then
        if inst.sg.mem.recentfx == nil then
            inst.sg.mem.recentfx = {}
        end
        local recentcount = #inst.sg.mem.recentfx
        local rand = math.random(NUM_FX_VARIATIONS - recentcount)
        if recentcount > 0 then
            while table.contains(inst.sg.mem.recentfx, rand) do
                rand = rand + 1
            end
            if recentcount >= MAX_RECENT_FX then
                table.remove(inst.sg.mem.recentfx, 1)
            end
        end
        table.insert(inst.sg.mem.recentfx, rand)
        fx:SetVariation(rand, fx._min_scale + (fx._max_scale - fx._min_scale) * scale)
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end

local function SetContainerCanBeOpened(inst, canbeopened)
	if canbeopened then
		if inst.components.container ~= nil then
			inst.components.container.canbeopened = true
		elseif inst.components.container_proxy ~= nil and inst.components.container_proxy:GetMaster() ~= nil then
			inst.components.container_proxy:SetCanBeOpened(true)
		end
	elseif inst.components.container ~= nil then
		inst.components.container:Close()
		inst.components.container.canbeopened = false
	elseif inst.components.container_proxy ~= nil then
		inst.components.container_proxy:Close()
		inst.components.container_proxy:SetCanBeOpened(false)
	end
end

local events=
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnSleep(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnLocomote(false,true),
    CommonHandlers.OnHop(),
	CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),
	EventHandler("attacked", function(inst, data)
        if inst.components.health and not inst.components.health:IsDead() and not inst.sg:HasStateTag("devoured") then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				inst.SoundEmitter:PlaySound(inst.sounds.hurt)
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
				inst.SoundEmitter:PlaySound(inst.sounds.hurt)
			end
        end
    end),
    EventHandler("morph", function(inst, data)
        inst.sg:GoToState("morph", data.morphfn)
    end),

    EventHandler("knockback", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("knockbacklanded", data)
        end
    end),

    EventHandler("devoured", function(inst, data)
        if not inst.components.health:IsDead() and data ~= nil and data.attacker ~= nil and data.attacker:IsValid() then
            inst.sg:GoToState("devoured", data)
        end
    end),
    CommonHandlers.OnDeath(),

    -- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop")

            if not inst.sg.mem.pant_ducking or inst.sg:InNewState() then
				inst.sg.mem.pant_ducking = 1
			end
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline=
        {
            TimeEvent(7*FRAMES, function(inst)
				inst.sg.mem.pant_ducking = inst.sg.mem.pant_ducking or 1

				inst.SoundEmitter:PlaySound(inst.sounds.pant, nil, inst.sg.mem.pant_ducking)
				if inst.sg.mem.pant_ducking and inst.sg.mem.pant_ducking > .35 then
					inst.sg.mem.pant_ducking = inst.sg.mem.pant_ducking - .05
				end
			end),
        },
   },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
			SetContainerCanBeOpened(inst, false)
			if inst.components.container ~= nil then
				inst.components.container:DropEverything()
			end

            inst.SoundEmitter:PlaySound(inst.sounds.death)

            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
        end,

        events =
        {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },

    State{
        name = "open",
        tags = {"busy", "open"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.components.sleeper:WakeUp()
            inst.AnimState:PlayAnimation("open")
            if inst.SoundEmitter:PlayingSound("hutchMusic") then
                inst.SoundEmitter:SetParameter("hutchMusic", "intensity", 1)
            end
			if inst.sg.mem.isshadow then
				inst.sg.statemem.swirl = SpawnPrefab("shadow_chester_swirl_fx")
				inst.sg.statemem.swirl.entity:SetParent(inst.entity)
				inst.SoundEmitter:PlaySound("maxwell_rework/shadow_magic/storage_void_LP", "loop")
			end
        end,

        events=
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.open = true
					inst.sg:GoToState("open_idle", inst.sg.statemem.swirl)
				end
			end),
        },

        timeline=
        {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound( inst.sounds.open ) end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.open and inst.sg.statemem.swirl ~= nil then
				inst.sg.statemem.swirl:ReleaseSwirl()
				if not inst.sg.statemem.closing then
					inst.SoundEmitter:KillSound("loop")
				end
			end
		end,
    },

    State{
        name = "open_idle",
        tags = {"busy", "open"},

        onenter = function(inst, swirl)
			inst.AnimState:PlayAnimation("idle_loop_open")

            if not inst.sg.mem.pant_ducking or inst.sg:InNewState() then
				inst.sg.mem.pant_ducking = 1
			end

			inst.sg.statemem.swirl = swirl
        end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.open = true
					inst.sg:GoToState("open_idle", inst.sg.statemem.swirl)
				end
			end),
		},

        timeline=
        {
            TimeEvent(3*FRAMES, function(inst)
				inst.sg.mem.pant_ducking = inst.sg.mem.pant_ducking or 1
				inst.SoundEmitter:PlaySound( inst.sounds.pant , nil, inst.sg.mem.pant_ducking)
				if inst.sg.mem.pant_ducking and inst.sg.mem.pant_ducking > .35 then
					inst.sg.mem.pant_ducking = inst.sg.mem.pant_ducking - .05
				end
			end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.open and inst.sg.statemem.swirl ~= nil then
				inst.sg.statemem.swirl:ReleaseSwirl()
				if not inst.sg.statemem.closing then
					inst.SoundEmitter:KillSound("loop")
				end
			end
		end,
    },

    State{
        name = "close",

        onenter = function(inst)
            inst.AnimState:PlayAnimation("closed")
        end,

        onexit = function(inst)
            if not inst.sg.statemem.muffled and inst.SoundEmitter:PlayingSound("hutchMusic") then
                inst.SoundEmitter:SetParameter("hutchMusic", "intensity", 0)
            end
			inst.SoundEmitter:KillSound("loop")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },

        timeline=
        {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound( inst.sounds.close ) end),
            TimeEvent(4*FRAMES, function(inst)
                if inst.SoundEmitter:PlayingSound("hutchMusic") then
                    inst.sg.statemem.muffled = true
                    inst.SoundEmitter:SetParameter("hutchMusic", "intensity", 0)
                end
				inst.SoundEmitter:KillSound("loop")
			end),
        },
    },

    State{
        name = "transition",
		tags = { "busy", "noelectrocute" },
        onenter = function(inst)
            inst.Physics:Stop()

            --Remove ability to open chester for short time.
			SetContainerCanBeOpened(inst, false)

            --Create light shaft
            inst.sg.statemem.light = SpawnPrefab("chesterlight")
            inst.sg.statemem.light.Transform:SetPosition(inst:GetPosition():Get())
            inst.sg.statemem.light:TurnOn()

            inst.SoundEmitter:PlaySound("dontstarve/creatures/chester/raise")

            inst.AnimState:PlayAnimation("idle_loop")
            inst.AnimState:PushAnimation("idle_loop")
            inst.AnimState:PushAnimation("idle_loop")
            inst.AnimState:PushAnimation("transition", false)
        end,

        onexit = function(inst)
            --Add ability to open chester again.
			SetContainerCanBeOpened(inst, true)
            --Remove light shaft
            if inst.sg.statemem.light then
                inst.sg.statemem.light:TurnOff()
            end
        end,

        timeline =
        {
            TimeEvent(56*FRAMES, function(inst)
                local x, y, z = inst.Transform:GetWorldPosition()
                SpawnPrefab("chester_transform_fx").Transform:SetPosition(x, y + 1, z)
            end),
            TimeEvent(60*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound( inst.sounds.pop )
                if inst.MorphChester ~= nil then
                    inst:MorphChester()
					SetContainerCanBeOpened(inst, false)
                end
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },

    State{
        name = "morph",
		tags = { "busy", "noelectrocute" },
        onenter = function(inst, morphfn)
            inst.Physics:Stop()

            inst.SoundEmitter:PlaySound("dontstarve/creatures/chester/raise")
            inst.AnimState:PlayAnimation("transition", false)

            --Remove ability to open chester for short time.
			SetContainerCanBeOpened(inst, false)

            inst.sg.statemem.morphfn = morphfn
        end,

        timeline =
        {

            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/hutch/bounce")
            end),
            TimeEvent(22*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/hutch/clap")
            end),
            TimeEvent(27*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/hutch/clap")
            end),
            TimeEvent(32*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/hutch/clap")
            end),
            TimeEvent(36*FRAMES, function(inst)
                local x, y, z = inst.Transform:GetWorldPosition()
                SpawnPrefab("chester_transform_fx").Transform:SetPosition(x, y + 1, z)
            end),
            TimeEvent(37*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/hutch/clap")
            end),
            TimeEvent(40*FRAMES, function(inst)
                if inst.sg.statemem.morphfn ~= nil then
                    local morphfn = inst.sg.statemem.morphfn
                    inst.sg.statemem.morphfn = nil
                    morphfn(inst)
					SetContainerCanBeOpened(inst, false)
                end
                inst.SoundEmitter:PlaySound( inst.sounds.pop )
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },

        onexit = function(inst)
            if inst.sg.statemem.morphfn ~= nil then
                --In case state was interrupted
                local morphfn = inst.sg.statemem.morphfn
                inst.sg.statemem.morphfn = nil
                morphfn(inst)
            end
            --Add ability to open chester again.
			SetContainerCanBeOpened(inst, true)
        end,
    },


    State{
        name = "knockbacklanded",
		tags = { "knockback", "busy", "nopredict", "nomorph", "nointerrupt", "jumping", "noelectrocute" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("idle_loop")

            if data ~= nil then

                if data.radius ~= nil and data.knocker ~= nil and data.knocker:IsValid() then
                    local x, y, z = data.knocker.Transform:GetWorldPosition()
                    local distsq = inst:GetDistanceSqToPoint(x, y, z)
                    local rangesq = data.radius * data.radius
                    local rot = inst.Transform:GetRotation()
                    local rot1 = distsq > 0 and inst:GetAngleToPoint(x, y, z) or data.knocker.Transform:GetRotation() + 180
                    local drot = math.abs(rot - rot1)
                    while drot > 180 do
                        drot = math.abs(drot - 360)
                    end
                    local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
                    inst.sg.statemem.speed = (data.strengthmult or 1) * 8 * k
                    inst.sg.statemem.dspeed = 0
                    if drot > 90 then
                        inst.sg.statemem.reverse = true
                        inst.Transform:SetRotation(rot1 + 180)
                        inst.Physics:SetMotorVel(-inst.sg.statemem.speed, 0, 0)
                    else
                        inst.Transform:SetRotation(rot1)
                        inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                    end
                end
            end

            if inst:IsOnPassablePoint(true) then
                inst.sg.statemem.safepos = inst:GetPosition()
            elseif data ~= nil and data.knocker ~= nil and data.knocker:IsValid() and data.knocker:IsOnPassablePoint(true) then
                local x1, y1, z1 = data.knocker.Transform:GetWorldPosition()
                local radius = data.knocker:GetPhysicsRadius(0) - inst:GetPhysicsRadius(0)
                if radius > 0 then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local dx = x - x1
                    local dz = z - z1
                    local dist = radius / math.sqrt(dx * dx + dz * dz)
                    x = x1 + dx * dist
                    z = z1 + dz * dist
                    if TheWorld.Map:IsPassableAtPoint(x, 0, z, true) then
                        x1, z1 = x, z
                    end
                end
                inst.sg.statemem.safepos = Vector3(x1, 0, z1)
            end

            inst.sg:SetTimeout(11 * FRAMES)
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .075
                    inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -inst.sg.statemem.speed or inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
            local safepos = inst.sg.statemem.safepos
            if safepos ~= nil then
                if inst:IsOnPassablePoint(true) then
                    safepos.x, safepos.y, safepos.z = inst.Transform:GetWorldPosition()
                elseif inst.sg.statemem.landed then
                    local mass = inst.Physics:GetMass()
                    if mass > 0 then
                        inst.sg.statemem.restoremass = mass
                        inst.Physics:SetMass(99999)
                    end
                    inst.Physics:Teleport(safepos.x, 0, safepos.z)
                    inst.sg.statemem.safepos = nil
                end
            end
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
            FrameEvent(10, function(inst)
                inst.sg.statemem.landed = true
                inst.sg:RemoveStateTag("nointerrupt")
                inst.sg:RemoveStateTag("jumping")
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,

        onexit = function(inst)
            if inst.sg.statemem.restoremass ~= nil then
                inst.Physics:SetMass(inst.sg.statemem.restoremass)
            end
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    },

    State{
        name = "devoured",
		tags = { "devoured", "invisible", "noattack", "notalking", "nointerrupt", "busy", "silentmorph", "noelectrocute" },

        onenter = function(inst, data)
            local attacker = data.attacker
            ClearStatusAilments(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("empty")

			inst:StopBrain("SGchester_devoured")

            inst:Hide()
            inst.DynamicShadow:Enable(false)
            ToggleOffPhysics(inst)

            if attacker ~= nil and attacker:IsValid() then
                inst.sg.statemem.attacker = attacker
                inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
            end
        end,

        onupdate = function(inst)
            local attacker = inst.sg.statemem.attacker
            if attacker ~= nil and attacker:IsValid() then
                inst.Transform:SetPosition(attacker.Transform:GetWorldPosition())
                inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
            else
                inst.sg:GoToState("idle")
            end
        end,

        events =
        {
            EventHandler("spitout", function(inst, data)
                local attacker = data ~= nil and data.spitter or inst.sg.statemem.attacker
                if attacker ~= nil and attacker:IsValid() then
                    local rot = data.rot or attacker.Transform:GetRotation() + 180
                    inst.Transform:SetRotation(rot)
                    local physradius = attacker:GetPhysicsRadius(0)
                    if physradius > 0 then
                        local x, y, z = inst.Transform:GetWorldPosition()
                        rot = rot * DEGREES
                        x = x + math.cos(rot) * physradius
                        z = z - math.sin(rot) * physradius
                        inst.Physics:Teleport(x, 0, z)
                    end

					inst:PushEventImmediate("knockback", {
                        knocker = attacker,
                        radius = data ~= nil and data.radius or physradius + 1,
                        strengthmult = data ~= nil and data.strengthmult or nil,
                    })
                else
					inst:PushEventImmediate("knockback")
                end
            end),
        },

        onexit = function(inst)
            if inst.components.health:IsDead() then
                local attacker = inst.sg.statemem.attacker
                if attacker ~= nil and attacker:IsValid() then
                    local rot = attacker.Transform:GetRotation()
                    inst.Transform:SetRotation(rot + 180)
                    --use true physics radius if available
                    local radius = attacker.Physics ~= nil and attacker.Physics:GetRadius() or attacker:GetPhysicsRadius(0)
                    if radius > 0 then
                        local x, y, z = inst.Transform:GetWorldPosition()
                        rot = rot * DEGREES
                        x = x + math.cos(rot) * radius
                        z = z - math.sin(rot) * radius
                        if TheWorld.Map:IsPassableAtPoint(x, 0, z, true) then
                            inst.Physics:Teleport(x, 0, z)
                        end
                    end
                end
            end
			inst:RestartBrain("SGchester_devoured")
            inst:Show()
            inst.DynamicShadow:Enable(true)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
            inst.entity:SetParent(nil)
        end,
    },

}

CommonStates.AddWalkStates(states, {
    walktimeline =
    {
        --TimeEvent(0*FRAMES, function(inst)  end),

        TimeEvent(1*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound( inst.sounds.boing )

            inst.components.locomotor:RunForward()

            --Cave chester leaves slime as he bounces
            if inst.leave_slime then
                inst.sg.statemem.slimein = true
                if inst.sg.mem.lastspawnlandingmovefx ~= nil and inst.sg.mem.lastspawnlandingmovefx + 2 > GetTime() then
                    inst.sg.statemem.slimeout = true
                    SpawnMoveFx(inst, .45 + math.random() * .1)
                end
            end
        end),

        TimeEvent(2 * FRAMES, function(inst)
            if inst.sg.statemem.slimeout then
                SpawnMoveFx(inst, .2 + math.random() * .1)
            end
        end),

        TimeEvent(4 * FRAMES, function(inst)
            if inst.sg.statemem.slimeout and math.random() < .7 then
                SpawnMoveFx(inst, .1 + math.random() * .1)
            end
        end),

        TimeEvent(7 * FRAMES, function(inst)
            if inst.sg.statemem.slimeout and math.random() < .3 then
                SpawnMoveFx(inst, 0)
            end
        end),

        TimeEvent(10 * FRAMES, function(inst)
            if inst.sg.statemem.slimein and math.random() < .6 then
                SpawnMoveFx(inst, .05 + math.random() * .1)
            end
        end),

        TimeEvent(12 * FRAMES, function(inst)
            if inst.sg.statemem.slimein then
                SpawnMoveFx(inst, .25 + math.random() * .1)
            end
        end),

        TimeEvent(13*FRAMES, function(inst)
            if inst.sounds.land_hit ~= nil then
                inst.SoundEmitter:PlaySound(inst.sounds.land_hit)
            end
            if inst.sg.statemem.slimein then
                if inst.sounds.land ~= nil then
                    inst.SoundEmitter:PlaySound(inst.sounds.land)
                end
                SpawnMoveFx(inst, .8 + math.random() * .2)
                inst.sg.mem.lastspawnlandingmovefx = GetTime()
            end
        end),

        TimeEvent(14*FRAMES, function(inst)
            PlayFootstep(inst)
            inst.components.locomotor:WalkForward()
        end),
    },

    endtimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
--[[
            if inst.sounds.land_hit then
                inst.SoundEmitter:PlaySound( inst.sounds.land_hit )
            end
            ]]
            if inst.sg.statemem.slimein then
                if inst.sounds.land ~= nil then
                    inst.SoundEmitter:PlaySound(inst.sounds.land)
                end
                SpawnMoveFx(inst, .4 + math.random() * .2)
                inst.sg.mem.lastspawnlandingmovefx = GetTime()
            end
        end),
    },

}, nil, true)

CommonStates.AddHopStates(states, true, nil,
{
    hop_pre =
    {
        TimeEvent(0, function(inst)
            -- TODO(DANY):  This is when Chester starts jumping on the boat. There are a few other creatures that can jump on the boat
            --              but I thought it would make sense to just get chester working properly and then we can look at hooking up
            --              the other ones after.
            -- TODO(DANY):  This is when Chester lands on the boat.
            inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
        end),
    }
})

CommonStates.AddSleepStates(states,
{
    starttimeline =
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound( inst.sounds.close ) end)
    },

    sleeptimeline =
    {
        TimeEvent(1*FRAMES, function(inst)
            if inst.sounds.sleep then
                inst.SoundEmitter:PlaySound( inst.sounds.sleep )
            end
        end)
    },
    waketimeline =
    {
        TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound( inst.sounds.open ) end)
    },
})

CommonStates.AddSimpleState(states, "hit", "hit", {"busy"})
CommonStates.AddSinkAndWashAshoreStates(states)
CommonStates.AddVoidFallStates(states)
CommonStates.AddElectrocuteStates(states, nil, nil,
{
	loop_onenter = function(inst)
		SetContainerCanBeOpened(inst, false)
	end,
	loop_onexit = function(inst)
		if not inst.sg.statemem.not_interrupted then
			SetContainerCanBeOpened(inst, true)
		end
	end,
	pst_onexit = function(inst)
		SetContainerCanBeOpened(inst, true)
	end,
})

CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states)

return StateGraph("chester", states, events, "init")
