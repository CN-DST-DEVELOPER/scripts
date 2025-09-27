require("stategraphs/commonstates")


local function DoEquipmentFoleySounds(inst)
    for k, v in pairs(inst.components.inventory.equipslots) do
        if v.foleysound ~= nil then
            inst.SoundEmitter:PlaySound(v.foleysound, nil, nil, true)
        end
    end
end

local function DoFoleySounds(inst)
    DoEquipmentFoleySounds(inst)
    if inst.foleysound ~= nil then
        inst.SoundEmitter:PlaySound(inst.foleysound, nil, nil, true)
    end
end

local function DoMountedFoleySounds(inst)
    DoEquipmentFoleySounds(inst)
    local saddle = inst.components.rider:GetSaddle()
    if saddle ~= nil and saddle.mounted_foleysound ~= nil then
        inst.SoundEmitter:PlaySound(saddle.mounted_foleysound, nil, nil, true)
    end
end

local DoRunSounds = function(inst)
    PlayFootstep(inst, 1, true)
end

local function DoHurtSound(inst)
    if inst.hurtsoundoverride ~= nil then
        inst.SoundEmitter:PlaySound(inst.hurtsoundoverride, nil, inst.hurtsoundvolume)
    elseif not inst:HasTag("mime") then
        inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/hurt", nil, inst.hurtsoundvolume)
    end
end

local actionhandlers =
{

    ActionHandler(ACTIONS.EAT,
        function(inst, action)
            if inst.sg:HasStateTag("busy") then
                return "eat"
            end
        end),

}

local events =
{
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnLocomote(true, false),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),

    EventHandler("intro", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("intro")
        end
    end),

    EventHandler("attacked", function(inst, data)
        if not inst.components.health:IsDead() then
            inst.sg:GoToState("hit")
        end
    end),
}

local states =
{

    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,
    },

    State{
        name = "intro",
        tags = { "busy", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("parasite_death_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy", "dead", "nomorph" },

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            inst.SoundEmitter:PlaySound("dontstarve/wilson/death")

            inst.components.inventory:DropEverything(true)
            inst.AnimState:PlayAnimation("death")

            inst.AnimState:Hide("swap_arm_carry")

            inst.components.burnable:Extinguish()

            inst.persists = false

            inst.sg.statemem.data = data
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if not inst.AnimState:AnimDone() then
                    return
                end

                local x, y, z = inst.Transform:GetWorldPosition()
                local has_skeleton = TheWorld.Map:IsPassableAtPoint(x, y, z)

                if has_skeleton and inst.skeleton_prefab ~= nil then
                    local skel = TheSim:HasPlayerSkeletons() and SpawnPrefab(inst.skeleton_prefab) or SpawnPrefab("shallow_grave_player")

                    if skel ~= nil then
                        skel.Transform:SetPosition(x, y, z)
   
                        local host_userid = inst.hosted_userid:value()
                        local deathclientobj = TheNet:GetClientTableForUser(host_userid)

                        if deathclientobj ~= nil then
                            local deathcause = inst.sg.statemem.data ~= nil and inst.sg.statemem.data.cause or "unknown"
                            local afflicter = inst.sg.statemem.data ~= nil and inst.sg.statemem.data.afflicter or nil
                            local deathpkname = nil

                            if afflicter ~= nil then
                                if afflicter.overridepkname ~= nil then
                                    deathpkname = afflicter.overridepkname
                                else
                                    local killer = afflicter.components.follower ~= nil and afflicter.components.follower:GetLeader() or nil

                                    if not (killer ~= nil and
                                        killer.components.petleash ~= nil and
                                        killer.components.petleash:IsPet(afflicter)
                                    ) then
                                        killer = afflicter
                                    end

                                    deathpkname = killer:HasTag("player") and killer:GetDisplayName() or nil
                                end
                            end

                            skel:SetSkeletonDescription(deathclientobj.prefab, deathclientobj.name, deathcause, deathpkname, host_userid)
                            skel:SetSkeletonAvatarData(deathclientobj)
                        end
                    end
                end

                SpawnPrefab("die_fx").Transform:SetPosition(x, y, z)

                inst:Remove()
            end),
        },
    },

    State{
        name = "eat",
		tags = { "busy", "nodangle", "keep_pocket_rummage" },

        onenter = function(inst, foodinfo)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("eat_pre")
            inst.AnimState:PushAnimation("eat", false)
        end,

        timeline =
        {
            TimeEvent(70 * FRAMES, function(inst)
                inst.SoundEmitter:KillSound("eating")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
                end
            end),
        },

    },

    State{
        name = "dolongaction",
		tags = { "doing", "busy", "nodangle", "keep_pocket_rummage" },

        onenter = function(inst, timeout)
            if timeout == nil then
                timeout = 1
            elseif timeout > 1 then
                inst.sg:AddStateTag("slowaction")
            end
            inst.sg:SetTimeout(timeout)
            inst.components.locomotor:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
            inst.AnimState:PlayAnimation("build_pre")
            inst.AnimState:PushAnimation("build_loop", true)
            if inst.bufferedaction ~= nil then
                inst.sg.statemem.action = inst.bufferedaction
                if inst.bufferedaction.action.actionmeter then
                    inst.sg.statemem.actionmeter = true
                    StartActionMeter(inst, timeout)
                end
                if inst.bufferedaction.target ~= nil and inst.bufferedaction.target:IsValid() then
                    inst.bufferedaction.target:PushEvent("startlongaction", inst)
                end
            end
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
            end),
        },

        ontimeout = function(inst)
            inst.SoundEmitter:KillSound("make")
            inst.AnimState:PlayAnimation("build_pst")
            if inst.sg.statemem.actionmeter then
                inst.sg.statemem.actionmeter = nil
                StopActionMeter(inst, true)
            end
			inst.sg:RemoveStateTag("busy")
            inst:PerformBufferedAction()
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
                end
            end),
        },

    },

    State{
        name = "attack",
        tags = { "attack", "busy"},

        onenter = function(inst)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("punch")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh", nil, nil, true)
            inst.Physics:Stop()
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst)
                inst.components.combat:DoAttack()
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

    },

    State{
        name = "run_start",
        tags = { "moving", "running", "canrotate"},

        onenter = function(inst)

            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {

            TimeEvent(4 * FRAMES, function(inst)
                PlayFootstep(inst, nil, true)
                DoFoleySounds(inst)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate"},

        onenter = function(inst)

            inst.components.locomotor:RunForward()

            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end

            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
            --unmounted
            TimeEvent(7 * FRAMES, function(inst)
                DoRunSounds(inst)
                DoFoleySounds(inst)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                DoRunSounds(inst)
                DoFoleySounds(inst)
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = { "canrotate", "idle"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("run_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },


    State{
        name = "hit",
		tags = { "busy", "pausepredict"},

        onenter = function(inst, frozen)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("hit")

            if frozen == "noimpactsound" then
                frozen = nil
            else
                inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            end
            DoHurtSound(inst)

            --V2C: some of the woodie's were-transforms have shorter hit anims
			local stun_frames = math.min(inst.AnimState:GetCurrentAnimationNumFrames(), frozen and 10 or 6)

            inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        ontimeout = function(inst)
			--V2C: -removing the tag now, since this is actually a supported "channeling_item"
			--      state (i.e. has custom anim)
			--     -the state enters with the tag though, to cheat having to create a separate
			--      hit state for channeling items
            inst.sg:GoToState("idle", true)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },


	State{
		name = "abyss_fall",
		tags = { "busy", "nopredict", "nomorph", "noattack", "nointerrupt", "nodangle", "falling" },
		onenter = function(inst, teleport_pt)

			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()
			inst:ShowHUD(false)

			inst.AnimState:PlayAnimation("abyss_fall")
            if inst.components.drownable then
                local teleport_x, teleport_y, teleport_z
                if teleport_pt then
                    teleport_x, teleport_y, teleport_z = teleport_pt:Get()
                end
                inst.components.drownable:OnFallInVoid(teleport_x, teleport_y, teleport_z)
            end
			inst.DynamicShadow:Enable(false)
			ToggleOffPhysics(inst)

			inst.components.health:SetInvincible(true)
		end,

		timeline =
		{
			FrameEvent(22, function(inst)
				inst.AnimState:SetLayer(LAYER_BELOW_GROUND)
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("invisible")
				inst:Hide()
			end),
			TimeEvent(2.5, function(inst)
				inst.sg.statemem.falling = true
                if inst.components.drownable ~= nil then
                    inst.components.drownable:Teleport()
                else
                    inst:PutBackOnGround()
                end
				inst.sg:GoToState("abyss_drop")
			end),
		},

		onexit = function(inst)
			inst.AnimState:SetLayer(LAYER_WORLD)
			inst.DynamicShadow:Enable(true)
			inst:Show()

			if not inst.sg.statemem.falling then
				ToggleOnPhysics(inst)
				inst.components.health:SetInvincible(false)
			end
		end,
	},

	State{
		name = "abyss_drop",
		tags = { "busy", "nopredict", "nomorph", "noattack", "nointerrupt", "nodangle", "overridelocomote", "falling" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
			inst:ClearBufferedAction()

			inst.AnimState:PlayAnimation("fall_high")

			ToggleOffPhysics(inst)
			inst.components.health:SetInvincible(true)

			inst.sg:SetTimeout(2)
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
			end),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("nointerrupt")
				ToggleOnPhysics(inst)
				inst.components.health:SetInvincible(false)
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("abyss_drop_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("abyss_drop_pst")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.isphysicstoggle then
				ToggleOnPhysics(inst)
			end
			inst.components.health:SetInvincible(false)
		end,
	},

	State{
		name = "abyss_drop_pst",
		tags = { "busy", "nomorph", "nodangle", "falling" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("buck_pst")
		end,

		timeline =
		{
			TimeEvent(27 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:RemoveStateTag("nomorph")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},


    State{
        name = "jumpin_pre",
        tags = { "doing", "busy", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(inst.components.inventory:IsHeavyLifting() and "heavy_jump_pre" or "jump_pre", false)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.bufferedaction ~= nil then
                        inst:PerformBufferedAction()
                    else
                        inst.sg:GoToState("idle")
                    end
                end
            end),
        },
    },

    State{
        name = "jumpin",
        tags = { "doing", "busy", "canrotate", "nopredict", "nomorph" },

        onenter = function(inst, data)
            ToggleOffPhysics(inst)
            inst.components.locomotor:Stop()

            inst.sg.statemem.target = data.teleporter
            inst.sg.statemem.heavy = inst.components.inventory:IsHeavyLifting()

            local pos = nil
            if data.teleporter ~= nil and data.teleporter.components.teleporter ~= nil then
                data.teleporter.components.teleporter:RegisterTeleportee(inst)
                pos = data.teleporter:GetPosition()
            end
            inst.sg.statemem.teleporterexit = data.teleporterexit -- Can be nil.

            inst.AnimState:PlayAnimation(inst.sg.statemem.heavy and "heavy_jump" or "jump")

            local MAX_JUMPIN_DIST = 3
            local MAX_JUMPIN_DIST_SQ = MAX_JUMPIN_DIST * MAX_JUMPIN_DIST
            local MAX_JUMPIN_SPEED = 6

            local dist
            if pos ~= nil then
                inst:ForceFacePoint(pos:Get())
                local distsq = inst:GetDistanceSqToPoint(pos:Get())
                if distsq <= .25 * .25 then
                    dist = 0
                    inst.sg.statemem.speed = 0
                elseif distsq >= MAX_JUMPIN_DIST_SQ then
                    dist = MAX_JUMPIN_DIST
                    inst.sg.statemem.speed = MAX_JUMPIN_SPEED
                else
                    dist = math.sqrt(distsq)
                    inst.sg.statemem.speed = MAX_JUMPIN_SPEED * dist / MAX_JUMPIN_DIST
                end
            else
                inst.sg.statemem.speed = 0
                dist = 0
            end

            inst.Physics:SetMotorVel(inst.sg.statemem.speed * .5, 0, 0)

            inst.sg.statemem.teleportarrivestate = "jumpout" -- this can be overriden in the teleporter component
        end,

        timeline =
        {
            TimeEvent(.5 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(inst.sg.statemem.speed * (inst.sg.statemem.heavy and .55 or .75), 0, 0)
            end),
            TimeEvent(1 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(inst.sg.statemem.heavy and inst.sg.statemem.speed * .6 or inst.sg.statemem.speed, 0, 0)
            end),

            -- NORMAL WHOOSH SOUND GOES HERE
            TimeEvent(1 * FRAMES, function(inst)
                if not inst.sg.statemem.heavy then
                    --print ("START NORMAL JUMPING SOUND")
                    inst.SoundEmitter:PlaySound("wanda1/wanda/jump_whoosh")
                end
            end),

            -- HEAVY WHOOSH SOUND GOES HERE
            TimeEvent(5 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    --print ("START HEAVY JUMPING SOUND")
                    inst.SoundEmitter:PlaySound("wanda1/wanda/jump_whoosh")
                end
            end),

            --Heavy lifting
            TimeEvent(12 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(inst.sg.statemem.speed * .5, 0, 0)
                end
            end),
            TimeEvent(13 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(inst.sg.statemem.speed * .4, 0, 0)
                end
            end),
            TimeEvent(14 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(inst.sg.statemem.speed * .3, 0, 0)
                end
            end),

            --Normal
            TimeEvent(15 * FRAMES, function(inst)
                if not inst.sg.statemem.heavy then
                    inst.Physics:Stop()
                end

                -- this is just hacked in here to make the sound play BEFORE the player hits the wormhole
                if inst.sg.statemem.target ~= nil then
                    if inst.sg.statemem.target:IsValid() then
                        inst.sg.statemem.target:PushEvent("starttravelsound", inst)
                    else
                        inst.sg.statemem.target = nil
                    end
                end
            end),

            --Heavy lifting
            TimeEvent(20 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:Stop()
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local should_teleport = false
                    if inst.sg.statemem.target ~= nil and
                        inst.sg.statemem.target:IsValid() and
                        inst.sg.statemem.target.components.teleporter ~= nil then
                        --Unregister first before actually teleporting
                        inst.sg.statemem.target.components.teleporter:UnregisterTeleportee(inst)
                        local teleporterexit = inst.sg.statemem.teleporterexit
                        if teleporterexit then
                            if not teleporterexit:IsValid() then
								teleporterexit = teleporterexit.overtakenhole
								--this is just for an overtaken tentacle_pillar, otherwise nil
                            end
                            if inst.sg.statemem.target.components.teleporter:UseTemporaryExit(inst, teleporterexit) then
                                should_teleport = true
                            end
                        else
                            if inst.sg.statemem.target.components.teleporter:Activate(inst) then
                                should_teleport = true
                            end
                        end
                    end
                    if should_teleport then
                        inst.sg.statemem.isteleporting = true
                        inst.components.health:SetInvincible(true)
                        if inst.components.playercontroller ~= nil then
                            inst.components.playercontroller:Enable(false)
                        end
                        inst:Hide()
                        inst.DynamicShadow:Enable(false)
                        return
                    end
                    inst.sg:GoToState("jumpout")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
            inst.Physics:Stop()

            if inst.sg.statemem.isteleporting then
                inst.components.health:SetInvincible(false)
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:Enable(true)
                end
                inst:Show()
                inst.DynamicShadow:Enable(true)
            elseif inst.sg.statemem.target ~= nil
                and inst.sg.statemem.target:IsValid()
                and inst.sg.statemem.target.components.teleporter ~= nil then
                inst.sg.statemem.target.components.teleporter:UnregisterTeleportee(inst)
            end
        end,
    },

    State{
        name = "jumpout",
        tags = { "doing", "busy", "canrotate", "nopredict", "nomorph" },

        onenter = function(inst)
            ToggleOffPhysics(inst)
            inst.components.locomotor:Stop()

            inst.sg.statemem.heavy = inst.components.inventory:IsHeavyLifting()

            inst.AnimState:PlayAnimation(inst.sg.statemem.heavy and "heavy_jumpout" or "jumpout")

            inst.Physics:SetMotorVel(4, 0, 0)
        end,

        timeline =
        {
            --Heavy lifting
            TimeEvent(4 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(3, 0, 0)
                end
            end),
            TimeEvent(12 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(2, 0, 0)
                end
            end),
            TimeEvent(12.2 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    if inst.sg.statemem.isphysicstoggle then
                        ToggleOnPhysics(inst)
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
                end
            end),
            TimeEvent(16 * FRAMES, function(inst)
                if inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(1, 0, 0)
                end
            end),

            --Normal
            TimeEvent(10 * FRAMES, function(inst)
                if not inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(3, 0, 0)
                end
            end),
            TimeEvent(15 * FRAMES, function(inst)
                if not inst.sg.statemem.heavy then
                    inst.Physics:SetMotorVel(2, 0, 0)
                end
            end),
            TimeEvent(15.2 * FRAMES, function(inst)
                if not inst.sg.statemem.heavy then
                    if inst.sg.statemem.isphysicstoggle then
                        ToggleOnPhysics(inst)
                    end
                    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
                end
            end),

            TimeEvent(17 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(inst.sg.statemem.heavy and .5 or 1, 0, 0)
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst.Physics:Stop()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.isphysicstoggle then
                ToggleOnPhysics(inst)
            end
        end,
    },

    State{
        name = "frozen",
        tags = { "busy", "frozen", "nopredict", "nodangle" },

        onenter = function(inst)
            if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
                inst.components.pinnable:Unstick()
            end

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen")
            inst.SoundEmitter:PlaySound("dontstarve/common/freezecreature")

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(false)
                inst.components.playercontroller:Enable(false)
            end

            --V2C: cuz... freezable component and SG need to match state,
            --     but messages to SG are queued, so it is not great when
            --     when freezable component tries to change state several
            --     times within one frame...
            if inst.components.freezable == nil then
                inst.sg:GoToState("hit", true)
            elseif inst.components.freezable:IsThawing() then
                inst.sg.statemem.isstillfrozen = true
                inst.sg:GoToState("thaw")
            elseif not inst.components.freezable:IsFrozen() then
                inst.sg:GoToState("hit", true)
            end
        end,

        events =
        {
            EventHandler("onthaw", function(inst)
                inst.sg.statemem.isstillfrozen = true
                inst.sg:GoToState("thaw")
            end),
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("hit", true)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.isstillfrozen then
                inst.components.inventory:Show()
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:EnableMapControls(true)
                    inst.components.playercontroller:Enable(true)
                end
            end
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    },

    State{
        name = "thaw",
        tags = { "busy", "thawing", "nopredict", "nodangle" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen_loop_pst", true)
            inst.SoundEmitter:PlaySound("dontstarve/common/freezethaw", "thawing")

            inst.components.inventory:Hide()
            inst:PushEvent("ms_closepopups")
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(false)
                inst.components.playercontroller:Enable(false)
            end
        end,

        events =
        {
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("hit", true)
            end),
        },

        onexit = function(inst)
            inst.components.inventory:Show()
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(true)
                inst.components.playercontroller:Enable(true)
            end
            inst.SoundEmitter:KillSound("thawing")
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    },

}

local hop_timelines =
{
    hop_pre =
    {
        TimeEvent(0, function(inst)
            inst.components.embarker.embark_speed = math.clamp(inst.components.locomotor:RunSpeed() * inst.components.locomotor:GetSpeedMultiplier() + TUNING.WILSON_EMBARK_SPEED_BOOST, TUNING.WILSON_EMBARK_SPEED_MIN, TUNING.WILSON_EMBARK_SPEED_MAX)
        end),
    },
    hop_loop =
    {
        TimeEvent(0, function(inst)
            inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
        end),
    },
}

local function landed_in_falling_state(inst)
    if inst.components.drownable == nil then
        return nil
    end

    local fallingreason = inst.components.drownable:GetFallingReason()
    if fallingreason == nil then
        return nil
    end

    if fallingreason == FALLINGREASON.OCEAN then
        return "sink"
    elseif fallingreason == FALLINGREASON.VOID then
        return "abyss_fall"
    end

    return nil -- TODO(JBK): Fallback for unknown falling reason?
end

local hop_anims =
{
    pre = function(inst) return (inst.replica.inventory ~= nil and inst.replica.inventory:IsHeavyLifting() and (inst.replica.rider == nil or not inst.replica.rider:IsRiding())) and "boat_jumpheavy_pre" or "boat_jump_pre" end,
    loop = function(inst) return (inst.replica.inventory ~= nil and inst.replica.inventory:IsHeavyLifting() and (inst.replica.rider == nil or not inst.replica.rider:IsRiding())) and "boat_jumpheavy_loop" or "boat_jump_loop" end,
    pst = function(inst) return (inst.replica.inventory ~= nil and inst.replica.inventory:IsHeavyLifting() and (inst.replica.rider == nil or not inst.replica.rider:IsRiding())) and "boat_jumpheavy_pst" or "boat_jump_pst" end,
}

CommonStates.AddHopStates(states, true, hop_anims, hop_timelines, "turnoftides/common/together/boat/jump_on", landed_in_falling_state, {start_embarking_pre_frame = 4*FRAMES})

return StateGraph("player_hosted", states, events, "intro", actionhandlers)
