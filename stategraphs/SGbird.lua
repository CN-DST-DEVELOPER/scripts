require("stategraphs/commonstates")

local easing = require("easing")

local actionhandlers =
{
    --Will this affect regular birds?
    ActionHandler(ACTIONS.EAT, "lunar_eat"),
    ActionHandler(ACTIONS.REMOVELUNARBUILDUP, "peck"), --glide_clearhail
    --ActionHandler(ACTIONS.GOHOME, "flyaway"),
}

local function IsStuck(inst)
	return inst:HasAnyTag("honey_ammo_afflicted", "gelblob_ammo_afflicted") and TheWorld.Map:IsPassableAtPoint(inst.Transform:GetWorldPosition())
end

local function PlayShardFx(inst, target)
    if target ~= nil and target:IsValid() then
        local fx = SpawnPrefab("mining_moonglass_fx")
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
        fx.Transform:SetScale(0.5, 0.5, 0.5)
        --sound?
    end
end

local function FlyAwayToSky(inst)
    local mutatedbirdmanager = TheWorld.components.mutatedbirdmanager
    if inst:HasTag("bird_mutant_rift") and mutatedbirdmanager then
        mutatedbirdmanager:FillMigrationTaskAtInst("mutatedbird", inst, 1)
    end
    --
    inst:Remove()
end

local events =
{
    EventHandler("gotosleep", function(inst)
        if not inst.components.health:IsDead() then
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.sg:GoToState(
                (y > 1 and "fall") or --special bird behaviour
                (inst.sg:HasStateTag("sleeping") and "sleeping") or
                "sleep"
            )
        end
    end),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnDeath(),
	EventHandler("attacked", function(inst, data)
        --V2C: health check since corpse shares this SG
        if inst.components.health and not inst.components.health:IsDead() then
			if not IsStuck(inst) and CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
			end
        end
    end),
    EventHandler("flyaway", function(inst)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("flyaway")
        end
    end),
    EventHandler("onignite", function(inst)
		if inst.components.health and not (inst.components.health:IsDead() or inst.sg:HasStateTag("electrocute")) then
            inst.sg:GoToState("distress_pre")
        end
    end),
    EventHandler("trapped", function(inst)
        inst.sg:GoToState("trapped")
    end),
    EventHandler("stunbomb", function(inst)
        inst.sg:GoToState("stunned")
    end),
    EventHandler("swoop_at_target", function(inst, data)
        inst.sg:GoToState("swoop_attack_in", data.target)
    end),

    --FIXME probably no more locomotion when new behaviour of bird is in
    EventHandler("locomote", function(inst)
        --NOTE: Locomote behaviour for the mutated bird, it's probably fine to have this event listener for all, but just in case.
        if inst:HasTag("bird_mutant_rift") and not inst.sg:HasAnyStateTag("sleeping", "busy", "flight") then
            local is_moving = inst.sg:HasStateTag("moving")
            local wants_to_move = inst.components.locomotor:WantsToMoveForward()
            if is_moving ~= wants_to_move then
                inst.sg:GoToState(wants_to_move and "hop" or "idle")
            end

            --[[
            local is_idling = inst.sg:HasStateTag("idle")

            local should_move = inst.components.locomotor:WantsToMoveForward()

            if is_moving and not should_move then
                inst.sg:GoToState("mutated_glide_pst")
            elseif (is_idling and should_move) or (is_moving and should_move ) then
                inst.sg:GoToState("mutated_glide_pre")
            end
            ]]
        end
    end),

	-- Corpse handlers
	CommonHandlers.OnCorpseChomped(),
}

local states =
{
    State{
		name = "init",
		onenter = function(inst)
			inst.sg:GoToState(inst.components.locomotor ~= nil and "glide" or "corpse_idle")
		end,
	},

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            if pushanim then
                if type(pushanim) == "string" then
                    inst.AnimState:PlayAnimation(pushanim)
                end
                inst.AnimState:PushAnimation("idle", true)
            elseif not inst.AnimState:IsCurrentAnimation("idle") then
                inst.AnimState:PlayAnimation("idle", true)
            end
            inst.sg:SetTimeout(1 + math.random())
        end,

        ontimeout = function(inst)
            if inst.bufferedaction ~= nil and inst.bufferedaction.action == ACTIONS.EAT then
                inst.sg:GoToState("peck")
            else
                local r = math.random()
                inst.sg:GoToState(
                    (r < .5 and "idle") or
                    (r < .6 and "switch") or
                    (r < .7 and "peck") or
                    (r < .8 and "hop") or
                    (r < .9 and "flyaway") or
                    "caw"
                )
            end
        end,
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
            inst:SetDeathLootLevel(1)
            if inst.sounds.death then
                inst.SoundEmitter:PlaySound(inst.sounds.death)
            end
        end,

        events =
		{
			CommonHandlers.OnCorpseDeathAnimOver(),
		},
    },

    State{
        name = "caw",
        tags = { "idle" },

        onenter = function(inst)
            if not inst.AnimState:IsCurrentAnimation("caw") then
                inst.AnimState:PlayAnimation("caw", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
            inst.SoundEmitter:PlaySound(inst.sounds.chirp)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState(math.random() < .5 and "caw" or "idle")
        end,
    },

    State{
        name = "distress_pre",
        tags = { "busy" },
        onenter = function(inst)
            inst.AnimState:PlayAnimation("flap_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("distress")
            end),
        },
    },

    State{
        name = "distress",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("flap_loop")
            inst.SoundEmitter:PlaySound("dontstarve/birds/wingflap_cage")
            inst.SoundEmitter:PlaySound(inst.sounds.chirp)
        end,

        events =
        {
			EventHandler("stop_honey_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
			EventHandler("stop_gelblob_ammo_afflicted", function(inst)
				if not (inst.components.health:IsDead() or (inst.components.burnable and inst.components.burnable:IsBurning()) or IsStuck(inst)) then
					inst.sg:GoToState("flyaway")
				end
			end),
            EventHandler("onextinguish", function(inst)
				if not (inst.components.health:IsDead() or IsStuck(inst)) then
                    inst.sg:GoToState("idle", "flap_post")
                end
            end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("distress")
            end),
        },
    },

    State{
        name = "delay_glide",
		tags = { "busy", "notarget", "noelectrocute" },

        onenter = function(inst, delay)
            inst:AddTag("NOCLICK")
			inst:AddTag("NOBLOCK")
            inst:Hide()
            inst.Physics:SetActive(false)
            inst.sg:SetTimeout(delay)
            inst.DynamicShadow:Enable(false)
        end,

        ontimeout = function(inst)
            inst.sg.statemem.gliding = true
            inst.sg:GoToState("glide")
        end,

        onexit = function(inst)
            if not inst.sg.statemem.gliding then
                inst:RemoveTag("NOCLICK")
                inst:RemoveTag("NOBLOCK")
                inst.DynamicShadow:Enable(true)
            end
            inst:Show()
            inst.Physics:SetActive(true)
        end,
    },

    State{
        name = "glide",
		tags = { "idle", "flight", "notarget", "noelectrocute" },

        onenter = function(inst)
			inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            if not inst.AnimState:IsCurrentAnimation("glide") then
                inst.AnimState:PlayAnimation("glide", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            inst.Physics:SetMotorVel(0, math.random() * 10 - 20, 0)
			inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
            TimeEvent(1 * FRAMES, function(inst)
                if inst.components.inventoryitem == nil or not inst.components.inventoryitem:IsHeld() then
                    inst.SoundEmitter:PlaySound(inst.sounds.flyin)
                end
            end),
        },

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y < 2 then
                inst.Physics:SetMotorVel(0, 0, 0)
            end
            if y <= 0.1 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.AnimState:PlayAnimation("land")
                inst.DynamicShadow:Enable(true)
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("glide")
        end,

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "switch",
        tags = { "idle" },

        onenter = function(inst)
            inst.Transform:SetRotation(inst.Transform:GetRotation() + 180)
            inst.AnimState:PlayAnimation("switch")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "peck",

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("peck") then
                inst.AnimState:PlayAnimation("peck", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline = {
            FrameEvent(4, function(inst)
                local buffaction = inst:GetBufferedAction()
                if inst:HasTag("bird_mutant_rift") and buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
			FrameEvent(9, function(inst)
                local buffaction = inst:GetBufferedAction()
                if inst:HasTag("bird_mutant_rift") and buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
        },

        ontimeout = function(inst)
            if math.random() < .3 then
                inst:PerformBufferedAction()
                inst.sg:GoToState("idle")
            else
                inst.sg:GoToState("peck")
            end
        end,
    },

    State{
        name = "flyaway",
		tags = { "flight", "busy", "notarget", "noelectrocute" },

        onenter = function(inst)
			if IsStuck(inst) then
				inst.sg:GoToState("distress_pre")
				return
			end

            --For Mutated bird
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

            local x, y, z = inst.Transform:GetWorldPosition()
            inst.sg.statemem.noescape = TheWorld.Map:IsPointInWagPunkArenaAndBarrierIsUp(x, y, z)

			inst:AddTag("NOCLICK")
			inst:AddTag("NOBLOCK")

            if inst.components.floater ~= nil then
                inst:PushEvent("on_no_longer_landed")
            end
            inst.Physics:Stop()
            inst.sg:SetTimeout(.1 + math.random() * .2)
            inst.sg.statemem.vert = math.random() < .5
            if inst.sg.statemem.noescape then
                inst.sg.statemem.vert = true
            end

            inst.SoundEmitter:PlaySound(inst.sounds.takeoff)

            if not inst.sg.statemem.noescape and inst.components.periodicspawner ~= nil and math.random() <= TUNING.BIRD_LEAVINGS_CHANCE then
                inst.components.periodicspawner:TrySpawn()
            end

            inst.AnimState:PlayAnimation(inst.sg.statemem.vert and "takeoff_vertical_pre" or "takeoff_diagonal_pre")
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.vert then
                inst.AnimState:PushAnimation("takeoff_vertical_loop", true)
                local horix, horiz = math.random() * 4 - 2, math.random() * 4 - 2
                if inst.sg.statemem.noescape then
                    horix, horiz = horix * 0.1, horiz * 0.1
                end
                inst.Physics:SetMotorVel(horix, math.random() * 5 + 15, horiz)
            else
                inst.AnimState:PushAnimation("takeoff_diagonal_loop", true)
                inst.Physics:SetMotorVel(math.random() * 8 + 8, math.random() * 5 + 15,math.random() * 4 - 2)
            end
			inst.DynamicShadow:Enable(false)
        end,

        timeline =
        {
			FrameEvent(5, function(inst)
				inst.DynamicShadow:SetSize(.6, .5)
			end),
            TimeEvent(2, function(inst)
                if inst.sg.statemem.noescape then
                    inst.sg:GoToState("fall")
                else
                    FlyAwayToSky(inst)
                end
            end),
        },

		onexit = function(inst)
			inst:RemoveTag("NOCLICK")
			inst:RemoveTag("NOBLOCK")
			inst.DynamicShadow:SetSize(1, .75)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "hop",
        tags = { "moving", "canrotate", "hopping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hop")
            inst.Physics:SetMotorVel(5, 0, 0)
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                inst.Physics:Stop()
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                elseif inst.components.inventoryitem ~= nil then
                    inst.components.inventoryitem:TryToSink()
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y > 1 then
                inst.sg:GoToState("fall")
                return
            end
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState(inst.components.burnable ~= nil and inst.components.burnable:IsBurning() and "distress_pre" or "flyaway")
            end),
        },
    },

    State{
        name = "fall",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("fall_loop", true)
			inst.DynamicShadow:Enable(false)
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y <= .2 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.DynamicShadow:Enable(true)
                inst.sg:GoToState("stunned")
                if inst.components.floater ~= nil then
                    inst:PushEvent("on_landed")
                end
            end
        end,

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "trapped",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(1)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("flyaway")
        end,
    },

    State{
        name = "stunned",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("stunned_loop", true)
            inst.sg:SetTimeout(GetRandomWithVariance(6, 2))
            if inst.components.inventoryitem ~= nil then
                inst.components.inventoryitem.canbepickedup = true
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("flyaway")
        end,

        onexit = function(inst)
            if inst.components.inventoryitem ~= nil then
                inst.components.inventoryitem.canbepickedup = false
            end
        end,
    },

    --------------------------------------------------------------------------
	--Used by "birdcorpse"

    State{
        name = "corpse_fall",
		tags = { "corpse", "busy", "noelectrocute" },

        onenter = function(inst)
            inst.Physics:Stop()
			inst.DynamicShadow:Enable(false)

            inst.sg.statemem.vert = math.random() < .5
            inst.Transform:SetRotation(math.random(360))

            inst.AnimState:PlayAnimation(inst.sg.statemem.vert and "fall_corpse_spiral" or "fall_corpse", true)

            local rot = inst.Transform:GetRotation() * DEGREES
            if inst.sg.statemem.vert then
                inst.Physics:SetVel(math.random() * 4 - 2, 0, math.random() * 4 - 2)
            else
                inst.Physics:SetVel(10 * math.cos(rot), 0, 10 * -math.sin(rot))
            end
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            if y <= .2 then
                inst.Physics:Stop()
                inst.Physics:Teleport(x, 0, z)
                inst.DynamicShadow:Enable(true)

                --Slide a lil if we were going diagonally
                if not inst.sg.statemem.vert then
                    local rot = inst.Transform:GetRotation() * DEGREES
                    inst.Physics:SetVel(math.random(6, 10) * math.cos(rot), 0, math.random(6, 10) * -math.sin(rot))
                end

                inst.sg:GoToState("corpse_idle", "fall_corpse_to_idle")
                inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/body_land")

                --Can't use inventoryitem:TryToSink, not an item!
                if ShouldEntitySink(inst, true) then
                    inst:DoTaskInTime(0, SinkEntity)
                end
            end
        end,

		onexit = function(inst)
			inst.DynamicShadow:Enable(true)
		end,
    },

    State{
        name = "lunar_eat",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("lunar_eat") then
                inst.AnimState:PlayAnimation("lunar_eat", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
		{
            FrameEvent(12, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
            end),
			FrameEvent(26, function(inst)
                local buffaction = inst:GetBufferedAction()
                if buffaction and buffaction.target then
                    PlayShardFx(inst, buffaction.target)
                    inst.SoundEmitter:PlaySound(inst.sounds.eat)
                end
                inst:PerformBufferedAction()
            end),
		},

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    -- Mutated states

    State{
        name = "swoop_attack_in",
        tags = { "flight", "notarget", },

        onenter = function(inst, target)
            inst.Transform:SetFourFaced()

            inst.AnimState:PlayAnimation("mutated_attack_pre")
            inst.AnimState:PushAnimation("mutated_attack_loop", true)

            local x, y, z = inst.Transform:GetWorldPosition()
            local dist = math.sqrt(inst:GetDistanceSqToInst(target))

            inst.sg.statemem.target = target
            inst.sg.statemem.velocity = Vector3(dist / 2, -(y - 4) / 2, 0)
            
            inst:FacePoint(target:GetPosition())

            local vel = inst.sg.statemem.velocity
            inst.Physics:SetMotorVel(vel.x, vel.y, vel.z)
        end,

        onupdate = function(inst, dt)
            local target = inst.sg.statemem.target
            local x, y, z = inst.Transform:GetWorldPosition()
            local vx, vy, vz = inst.Physics:GetMotorVel()

            if target and target:IsValid() then
                local time_to_ground = (y - 2.5) / math.abs(vy)
                --print(time_to_ground)

                if y < 2.5 then
                    inst.sg:GoToState("swoop_attack", target)
                elseif y > 3 then
                    local tx, ty, tz = target.Transform:GetWorldPosition()
                    local dx = tx - x
		            local dz = tz - z

                    if dx ~= 0 and dz ~= 0 then
                        local dir = inst.Transform:GetRotation() * DEGREES
                        local dir1 = math.atan2(-dz, dx)
                        local diff = ReduceAngleRad(dir1 - dir)

                        local turnmult = y <= 15 and easing.outQuad(y, 0, 1, 15) or 1
                        --Allow minor change in direction
			            local maxdiff = 10 * DEGREES * turnmult
			            dir = dir + math.clamp(diff, -maxdiff, maxdiff)

                        --TODO update velocity too?
                        --inst.sg.statemem.velocity.x
                        inst.Transform:SetRotation(dir * RADIANS)
                    end
                end
            end
        end,

        onexit = function(inst)
            inst.Transform:SetTwoFaced()
        end,
    },

    State{
        name = "swoop_attack",
        tags = { "flight", },

        onenter = function(inst, target)
            inst.sg.statemem.target = target
            inst.Transform:SetFourFaced()
            inst.AnimState:PlayAnimation("mutated_attack")
            inst.SoundEmitter:PlaySound(inst.sounds.attack)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("swoop_attack_out")
                end
            end)
        },

        timeline =
        {
            FrameEvent(1, function(inst)
                local target = inst.sg.statemem.target
                if target and target:IsValid() then
                    inst.components.combat:DoAttack(target)
                end
                inst.Physics:SetMotorVel(15, 3 + math.random() * 3 + math.random() * 3, 0)
            end),
        },

		onexit = function(inst)
			inst.Transform:SetTwoFaced()
		end,
    },

    State{
        name = "swoop_attack_out",
        tags = { "flight", },

        onenter = function(inst)
            inst.Transform:SetFourFaced()
            inst.AnimState:PlayAnimation("mutated_flap", true)
        end,

        timeline =
        {
            FrameEvent(3, function(inst) inst.sg:AddStateTag("notarget") end),
            FrameEvent(60, FlyAwayToSky),
        },

		onexit = function(inst)
			inst.Transform:SetTwoFaced()
		end,
    },

    State{
        name = "mutated_glide_pre",
        tags = { "flight", "moving", "canrotate" },

        onenter = function(inst)
            --inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            inst.Transform:SetEightFaced()
            inst.AnimState:PlayAnimation("mutated_flap_pre")
			inst.DynamicShadow:Enable(false)

            inst.components.locomotor:RunForward()
        end,

        onexit = function(inst)
            --inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
            inst.Transform:SetTwoFaced()
			inst.DynamicShadow:Enable(true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("mutated_glide_loop")
                end
            end)
        },
    },

    State{
        name = "mutated_glide_loop",
        tags = { "flight", "moving", "canrotate" },

        onenter = function(inst)
            --inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            inst.Transform:SetEightFaced()
            inst.AnimState:PlayAnimation("mutated_flap")
			inst.DynamicShadow:Enable(false)

            inst.components.locomotor:RunForward()
        end,

        onexit = function(inst)
            --inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
            inst.Transform:SetTwoFaced()
			inst.DynamicShadow:Enable(true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("mutated_glide_loop")
                end
            end)
        }
    },

    State{
        name = "mutated_glide_pst",
        tags = { "flight", "moving", "canrotate" },

        onenter = function(inst)
            --inst:AddTag("NOCLICK")
            inst:AddTag("NOBLOCK")
            inst.Transform:SetEightFaced()
            inst.AnimState:PlayAnimation("mutated_flap_pst")
			inst.DynamicShadow:Enable(false)
        end,

        onexit = function(inst)
            --inst:RemoveTag("NOCLICK")
            inst:RemoveTag("NOBLOCK")
            inst.Transform:SetTwoFaced()
			inst.DynamicShadow:Enable(true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end)
        }
    },
}

--[[
ANGLE = 90
-- adjust angle based on distance to player
	pt.x, pt.y, pt.z = target.Transform:GetWorldPosition()
	local rot1 = inst.Transform:GetRotation() + ANGLE
	local rot2 = inst:GetAngleToPoint(pt)
	local diff = ReduceAngle(rot2 - rot1)
	local absdiff = math.abs(diff)
	rot2 = rot1 + diff * 0.5
	inst.Transform:SetRotation(rot2 - ANGLE)
]]

CommonStates.AddSleepStates(states)
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states, nil, nil,
{
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			if inst.components.burnable and inst.components.burnable:IsBurning() then
				inst.sg:GoToState("distress_pre")
			else
				inst.sg:GoToState("flyaway")
			end
		end
	end,
})

CommonStates.AddCorpseStates(states, nil,
{
    corpseoncreate = function(inst, corpse)
        corpse:SetAltBuild(inst.prefab)
    end,
}, "birdcorpse")
-- Mutant birds use a different sg, so we do not actually use the _pst here!
CommonStates.AddLunarPreRiftMutationStates(states,
{
    mutate_timeline = {

    },
},
{
    mutate = "mutated_bird_reviving",
},
{
    mutate_onenter = function(inst)

    end,
},
{
    mutated_spawn_timing = 88 * FRAMES,
})

CommonStates.AddLunarRiftMutationStates(states, nil, nil,
{ -- fns
    mutate_onenter = function(inst)
        inst.AnimState:OverrideSymbol("lunar_parts", "bird_lunar_build", "lunar_parts")
		inst.AnimState:OverrideSymbol("fx_puff_hi", "bird_lunar_build", "fx_puff_hi")
		inst.AnimState:OverrideSymbol("fx_puff2", "bird_lunar_build", "fx_puff2")
        inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/mutate_pre")
    end,

    mutatepst_onenter = function(inst)
        inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_crow/mutate")
    end,
},
{
    twitch_lp = "lunarhail_event/creatures/lunar_crow/twitch_LP",
    post_mutate_state = "caw",
})

return StateGraph("bird", states, events, "init", actionhandlers)