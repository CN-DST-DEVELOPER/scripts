require("stategraphs/commonstates")

local actionhandlers = nil

local CHOOSE_AOE_RANGE = TUNING.ALTERGUARDIAN_PHASE1_AOERANGE / 2
local function ChooseAttack(inst, target)
    local ix, iy, iz = inst.Transform:GetWorldPosition()

    if inst.components.timer:TimerExists("roll_cooldown")
            or target == nil
            or not target:IsValid()
            or target:GetDistanceSqToPoint(ix, iy, iz) < CHOOSE_AOE_RANGE then
        inst.sg:GoToState("tantrum_pre")
    else
        inst.sg:GoToState("roll_start")
    end
end

local LUNAR_SPAWN_LIGHTMODULATION =
{
    [1] = 0.1,
    [2] = 0.133,
    [3] = 0.166,
    [4] = 0.2,
    [5] = 0.25,
    [6] = 0.3,
    [7] = 0.35,
    [8] = 0.4,
    [9] = 0.5,
    [10] = 0.6,
    [11] = 0.7,
    [12] = 0.8,
    [13] = 0.9,
    [14] = 0.91,
    [15] = 0.92,
    [16] = 0.925,
    [17] = 0.9375,
    [18] = 0.95,
    [19] = 0.9625,
    [20] = 0.975,
    [21] = 0.9875,
    [22] = 0.99,
    [23] = 0.95,
    [24] = 0.99,
    [25] = 0.99,
    [26] = 0.97,
    [27] = 0.95,
    [28] = 0.93,
    [29] = 0.91,
    [30] = 0.89,
    [31] = 0.87,
    [32] = 0.85,
    [33] = 0.87,
    [34] = 0.89,
    [35] = 0.91,
    [36] = 0.93,
    [37] = 0.95,
    [38] = 0.97,
    [39] = 0.98,
    [40] = 0.99,
    [41] = 1.0,
    [42] = 0.9375,
    [43] = 0.875,
    [44] = 0.8125,
    [45] = 0.75,
    [46] = 0.6875,
    [47] = 0.625,
    [48] = 0.5625,
    [49] = 0.5,
    [50] = 0.4375,
    [51] = 0.375,
    [52] = 0.3125,
    [53] = 0.25,
    [54] = 0.1875,
    [55] = 0.125,
    [56] = 0.0625,
}
local function lunarspawn_set_lightvalues(inst, frame)
    local val = LUNAR_SPAWN_LIGHTMODULATION[frame]
    if val then
        inst.Light:SetIntensity(0.6 * val * val)
        inst.Light:SetRadius(8 * val)
        inst.Light:SetFalloff(4 * val)

        inst.AnimState:SetLightOverride(val)
    end
end

local function IsntDead(inst)
    local health = inst.components.health
    return health ~= nil and health.currenthealth > health.minhealth
end

local function player_push_arrive_speech(player)
    if player.components.talker then
        player.components.talker:Say(GetString(player, "ANNOUNCE_LUNARGUARDIAN_INCOMING"))
    end
end

local events =
{
    CommonHandlers.OnDeath(),
    CommonHandlers.OnSink(),
    CommonHandlers.OnFallInVoid(),

    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("charge") then
            local should_move = inst.components.locomotor:WantsToMoveForward()

            if inst.sg:HasStateTag("moving") and not should_move then
                inst.sg:GoToState("walk_stop")
            elseif inst.sg:HasStateTag("idle") and should_move then
                inst.sg:GoToState("walk_start")
            end
        end
    end),

    EventHandler("doattack", function(inst)
        if IsntDead(inst) and (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit")) then
            ChooseAttack(inst, inst.components.combat.target)
        end
    end),

    EventHandler("attacked", function(inst)
        if IsntDead(inst) then
            if inst.sg:HasStateTag("shield") then
                inst.sg:GoToState("shield_hit")
			elseif not CommonHandlers.HitRecoveryDelay(inst, nil, math.huge) and --hit delay only for projectiles
					(not inst.sg:HasStateTag("busy") or
                    inst.sg:HasStateTag("caninterrupt") or
                    inst.sg:HasStateTag("frozen")) then
                inst.sg:GoToState("hit")
            end
        end
    end),

    EventHandler("entershield", function(inst)
        if IsntDead(inst) then
            inst.sg:GoToState("shield_pre")
        end
    end),
    EventHandler("exitshield", function(inst)
        if IsntDead(inst) then
            inst.sg:GoToState("shield_end")
        end
    end),
	EventHandler("minhealth", function(inst)
		if inst.components.health.minhealth > 0 and not inst.sg:HasStateTag("dead") then
			inst.sg:GoToState("death_lunar")
		end
	end),
}

local AOE_RANGE_PADDING = 3
local TARGET_MUSTHAVE_TAGS = { "_health", "_combat" }
local TARGET_CANT_TAGS = { "brightmareboss", "brightmare", "INLIMBO", "flight", "invisible", "notarget", "noattack" }
local TARGET_ONEOF_TAGS = { "animal", "character", "monster", "shadowminion", "smallcreature", "largecreature" }
local function DoAOEAttack(inst, range)
    local x,y,z = inst.Transform:GetWorldPosition()
    local targets = TheSim:FindEntities(
		x, y, z, range + AOE_RANGE_PADDING,
        TARGET_MUSTHAVE_TAGS, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS
    )

	if #targets > 0 then
		inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE1_AOEDAMAGE)
		for _, target in ipairs(targets) do
			if target:IsValid() and not (target.components.health ~= nil and target.components.health:IsDead()) then
				local range1 = range + target:GetPhysicsRadius(0)
				if target:GetDistanceSqToPoint(x, y, z) < range1 * range1 then
					inst.components.combat:DoAttack(target)
				end
			end
		end
		inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE1_ROLLDAMAGE)
	end
end

local ROLL_RANGE_OFFSET = .5
local ROLL_CANT_TAGS = shallowcopy(TARGET_CANT_TAGS)
table.insert(ROLL_CANT_TAGS, "wall")
table.insert(ROLL_CANT_TAGS, "structure")
local function OnUpdateRollAttack(inst)
	local hits = inst.sg.statemem.rollhits
	if hits == nil then
		return
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = inst.Transform:GetRotation() * DEGREES
	x = x + math.cos(theta) * ROLL_RANGE_OFFSET
	z = z - math.sin(theta) * ROLL_RANGE_OFFSET
	local targets = TheSim:FindEntities(x, y, z, TUNING.ALTERGUARDIAN_PHASE1_ROLLRANGE + AOE_RANGE_PADDING, TARGET_MUSTHAVE_TAGS, ROLL_CANT_TAGS, TARGET_ONEOF_TAGS)
	if #targets > 0 then
		local hit = false
		for _, target in ipairs(targets) do
			if not hits[target] and target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead() then
				local range = TUNING.ALTERGUARDIAN_PHASE1_ROLLRANGE + target:GetPhysicsRadius(0)
				if target:GetDistanceSqToPoint(x, y, z) < range * range then
					if target:HasTag("player") then
						inst.sg.statemem.hitplayer = true
					end
					inst.components.combat:DoAttack(target)
					hits[target] = true
					hit = true
				end
			end
		end
		if hit then
			ShakeAllCameras(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
			inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/onothercollide")
		end
	end
end

local function go_to_idle(inst)
    inst.sg:GoToState("idle")
end

local TANTRUM_SS_SPEED = 0.05
local TANTRUM_SS_SCALE = 0.075
local function tantrum_screenshake(inst)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, TANTRUM_SS_SPEED, TANTRUM_SS_SCALE, inst, 60)
end

local ROLL_SS_SPEED = 0.1
local ROLL_SS_SCALE = 0.1
local function roll_screenshake(inst)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, ROLL_SS_SPEED, ROLL_SS_SCALE, inst, 40)
end

local function spawn_land_screenshake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.8, 0.03, 0.6, inst, 40)
end

local function spawn_landfx(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    SpawnPrefab("alterguardian_spintrail_fx").Transform:SetPosition(ix, iy, iz)
    SpawnPrefab("mining_moonglass_fx").Transform:SetPosition(ix, iy, iz)
end

local states =
{
    State{
        name = "prespawn_idle",
        tags = { "busy", "noaoestun", "noattack", "nosleep", "nostun" },

        onenter = function(inst)
            inst.AnimState:SetBuild("alterguardian_spawn_death")
            inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "fall_bounce")
            inst.AnimState:PushAnimation("fall_idle", true)
            inst.components.health:SetInvincible(true)

            -- The timer should exist already if we were save/loaded during this time.
            -- If not, we're being put here on spawn, so start the timer!
            if not inst.components.timer:TimerExists("gotospawn") then
                inst.components.timer:StartTimer("gotospawn", 6)
            end

            inst:SetNoMusic(true)
        end,

        events =
        {
            EventHandler("startspawnanim", function(inst)
                inst.sg:GoToState("spawn")
            end),
        },

        onexit = function(inst)
            inst.components.health:SetInvincible(false)
            inst.AnimState:SetBuild("alterguardian_phase1")
            inst.AnimState:SetBankAndPlayAnimation("alterguardian_phase1", "idle")

            inst:SetNoMusic(false)
        end,
    },

    State{
        name = "spawn",
        tags = {"busy", "noaoestun", "noattack", "nosleep", "nostun" },

        onenter = function(inst)
            inst.AnimState:SetBuild("alterguardian_spawn_death")
            inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase1_spawn")
            inst.components.health:SetInvincible(true)
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/spawn")
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },

        onexit = function(inst)
            inst.components.health:SetInvincible(false)
            inst.AnimState:SetBuild("alterguardian_phase1")
            inst.AnimState:SetBankAndPlayAnimation("alterguardian_phase1", "idle")
        end,
    },

    State{
        name = "idle",
        tags = {"canroll", "canrotate", "idle"},

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle", true)
            else
                inst.AnimState:PlayAnimation("idle", true)
            end
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    State{
        name = "roll_start",
		tags = { "atk_pre", "busy", "canrotate", "charge" },

        onenter = function(inst)
            if inst.components.combat and inst.components.combat.target then
                local tx, ty, tz = inst.components.combat.target.Transform:GetWorldPosition()
                inst.Transform:SetRotation(inst:GetAngleToPoint(tx, ty, tz))
            end

            inst.components.combat:StartAttack()

            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(TUNING.ALTERGUARDIAN_PHASE1_WALK_SPEED, 0, 0)

            inst.AnimState:PlayAnimation("roll_pre")
        end,

        timeline =
        {

            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(17*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(29*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(39*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst:PushEvent("attackstart")
                inst.sg:GoToState("roll")
            end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
        end,
    },

    State{
        name = "roll",
		tags = { "attack", "busy", "charge" },

        onenter = function(inst)
            inst:EnableRollCollision(true)

            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(10, 0, 0)
			inst.sg.statemem.rollhits = {}

            inst.AnimState:PlayAnimation("roll_loop", true)

            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            if inst.sg.mem._num_rolls == nil then
                inst.sg.mem._num_rolls = TUNING.ALTERGUARDIAN_PHASE1_MINROLLCOUNT + (2*math.random())
            else
                inst.sg.mem._num_rolls = inst.sg.mem._num_rolls - 1
            end

            inst.components.combat:RestartCooldown()
        end,

		onupdate = OnUpdateRollAttack,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")

                roll_screenshake(inst)

                spawn_landfx(inst)
            end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()

            inst:EnableRollCollision(false)
        end,

        ontimeout = function(inst)
            if not inst.sg.statemem.hitplayer and inst.sg.mem._num_rolls > 0 then
                local final_rotation = nil
                if inst.components.combat.target ~= nil then
                    -- Retarget, and keep rolling!
                    local tx, ty, tz = inst.components.combat.target.Transform:GetWorldPosition()
                    local target_facing = inst:GetAngleToPoint(tx, ty, tz)

                    local current_facing = inst:GetRotation()

                    local target_angle_diff = ((target_facing - current_facing + 540) % 360) - 180

                    -- If our rotation is sufficiently "opposite" the direction of our target,
                    -- just straight up turn around.
                    if math.abs(target_angle_diff) > 120 and math.abs(target_angle_diff) < 240 then
                        final_rotation = target_facing + GetRandomWithVariance(0, -10)
                    elseif target_angle_diff < 0 then
                        final_rotation = (current_facing + math.max(target_angle_diff, -20)) % 360
                    else
                        final_rotation = (current_facing + math.min(target_angle_diff, 20)) % 360
                    end
                else
                    final_rotation = 360*math.random()
                end

                inst.Transform:SetRotation(final_rotation)

                inst.sg:GoToState("roll")
            else
                inst.sg.mem._num_rolls = nil
                inst.sg:GoToState("roll_stop")
            end
        end,
    },

    State{
        name = "roll_stop",
		tags = { "attack", "busy", "charge" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("roll_pst")

            roll_screenshake(inst)

			inst.components.timer:StopTimer("roll_cooldown")
            inst.components.timer:StartTimer("roll_cooldown", TUNING.ALTERGUARDIAN_PHASE1_ROLLCOOLDOWN)

            inst:EnableRollCollision(true)

            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(10, 0, 0)
			inst.sg.statemem.rollhits = {}
        end,

		onupdate = OnUpdateRollAttack,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")

                roll_screenshake(inst)

                spawn_landfx(inst)
            end),
            TimeEvent(18*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")
            end),
            TimeEvent(18*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                tantrum_screenshake(inst)

                spawn_landfx(inst)

                DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
            end),
            TimeEvent(22*FRAMES, function(inst)
                -- Velocity overrides are a stack, so we have to clear our 10 off first.
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:SetMotorVelOverride(3, 0, 0)
				inst.sg.statemem.rollhits = nil
            end),
            TimeEvent(35*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")

                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
                inst.Physics:ClearMotorVelOverride()

                inst:EnableRollCollision(false)

                inst.sg.statemem.roll_finished = true
            end),
            TimeEvent(43*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(48*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(52*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", go_to_idle),
        },

        onexit = function(inst)
            if not inst.sg.statemem.roll_finished then
                inst.components.locomotor:Stop()
                inst.components.locomotor:EnableGroundSpeedMultiplier(true)
                inst.Physics:ClearMotorVelOverride()

                inst:EnableRollCollision(false)
            end
        end,
    },

    State{
        name = "tantrum_pre",
        tags = {"attack", "busy", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.components.combat:StartAttack()

            inst.AnimState:PlayAnimation("tantrum_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("tantrum")
            end),
        },
    },

    State{
        name = "tantrum",
        tags = {"attack", "busy", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("tantrum_loop")

            if inst.sg.mem.aoes_remaining == nil or inst.sg.mem.aoes_remaining == 0 then
                inst.sg.mem.aoes_remaining = RoundBiasedUp(GetRandomMinMax(3, 5))
            end
        end,

        timeline =
        {

            TimeEvent(5*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
            end),
            TimeEvent(7*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                tantrum_screenshake(inst)

                spawn_landfx(inst)
            end),

            TimeEvent(8*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)

                inst.sg.mem.aoes_remaining = inst.sg.mem.aoes_remaining - 1
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState((inst.sg.mem.aoes_remaining > 0 and "tantrum") or "tantrum_pst")
            end),
        },
    },

    State{
        name = "tantrum_pst",
        tags = {"busy", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("tantrum_pst")
        end,

        timeline =
        {
            TimeEvent(5*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
            end),
            TimeEvent(7*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                tantrum_screenshake(inst)

                spawn_landfx(inst)
            end),
            TimeEvent(8*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
            end),
            TimeEvent(45*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(51*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(54*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    State{
        name = "shield_pre",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("shield_pre")
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield_pre")
            end),
            TimeEvent(15*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
            TimeEvent(26*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
            TimeEvent(30*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("shield")
            end),
        },
    },

    State{
        name = "shield",
        tags = {"busy", "shield"},

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("shield", true)

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/summon")

            inst:EnterShield()
        end,

        onexit = function(inst)
            inst:ExitShield()
        end,
    },

    State{
        name = "shield_hit",
        tags = {"busy", "hit", "shield"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("shield_hit")

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/hit")

            inst:EnterShield()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("shield")
            end),
        },

        onexit = function(inst)
            inst:ExitShield()
        end,
    },

    State{
        name = "shield_end",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("shield_pst")
        end,

        timeline =
        {
            TimeEvent(20*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(29*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(34*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    State{
        name = "death",
        tags = {"busy", "dead"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:SetBuild("alterguardian_spawn_death")
            inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase1_death")
            inst.AnimState:PushAnimation("phase1_death_idle", true)

            RemovePhysicsColliders(inst)

            inst.sg:SetTimeout(7)

            inst:SetNoMusic(true)
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/death")
            end),
            TimeEvent(5*FRAMES, function(inst)
                inst.SoundEmitter:KillSound("idle_LP")
            end),
            TimeEvent(26*FRAMES, function(inst)
                if not inst._loot_dropped then
                    inst._loot_dropped = true

                    inst.components.lootdropper:DropLoot(inst:GetPosition())
                end

                ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.1, 0.6, inst, 60)
            end),
        },

        ontimeout = function(inst)
            inst:PushEvent("phasetransition")
        end,
    },

    State {
        name = "death_lunar",
		tags = { "dead", "busy", "noattack", "nointerrupt", "temp_invincible" },

        onenter = function(inst)
			inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("collapse_pre")

            inst:SetNoMusic(true)

			inst.sg.statemem.gestalt = SpawnPrefab("alterguardian_phase1_lunarrift_gestalt")
			inst.sg.statemem.gestalt.entity:SetParent(inst.entity)
			inst.sg.statemem.gestalt.PARENT = inst
        end,

        timeline =
        {
            SoundTimeEvent(0, "moonstorm/creatures/boss/alterguardian1/death"),
            FrameEvent(5, function(inst)
                inst.SoundEmitter:KillSound("idle_LP")
            end),
            FrameEvent(38, function(inst)
                ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.1, 0.6, inst, 60)
				inst:AddTag("NOCLICK")
				inst.Physics:Stop()
				inst.Physics:SetActive(false)
				local x, y, z = inst.Transform:GetWorldPosition()
				local gestalt = inst.sg.statemem.gestalt
				gestalt.entity:SetParent(nil)
				gestalt.Transform:SetPosition(x, y, z)
				gestalt.Transform:SetRotation(inst.Transform:GetRotation())
				gestalt:RemoveTag("NOCLICK")
            end),
            FrameEvent(42, function(inst)
				inst.sg.statemem.gestalt.components.gestaltcapturable:SetEnabled(true)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.exited_correct = true
				inst.sg:GoToState("death_lunar_loop", inst.sg.statemem.gestalt)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.exited_correct then
				inst.sg.statemem.gestalt:Remove()
				inst:RemoveTag("NOCLICK")
				inst.Physics:SetActive(true)
				inst:SetNoMusic(false)
				if not inst.SoundEmitter:PlayingSound("idle_LP") then
					inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_wagboss_LP", "idle_LP")
				end
            end
        end,
    },

    State {
		name = "death_lunar_loop",
		tags = { "dead", "busy", "noattack", "nointerrupt", "temp_invincible" },

		onenter = function(inst, gestalt)
			if gestalt == nil then
				inst:SetNoMusic(true)

				gestalt = SpawnPrefab("alterguardian_phase1_lunarrift_gestalt")
				gestalt.PARENT = inst
				gestalt.Transform:SetPosition(inst.Transform:GetWorldPosition())
				gestalt.Transform:SetRotation(inst.Transform:GetRotation())
				gestalt:RemoveTag("NOCLICK")
				gestalt.components.gestaltcapturable:SetEnabled(true)
			end

			inst.components.locomotor:Stop()
			inst.Physics:Stop()
			inst.Physics:SetActive(false)
			inst:AddTag("NOCLICK")

			inst.AnimState:PlayAnimation("collapse_loop", true)

			inst.sg.statemem.gestalt = gestalt
			gestalt.AnimState:PlayAnimation("collapse_loop", true)

			inst.SoundEmitter:KillSound("idle_LP")

			inst.sg.mem.numrevives = (inst.sg.mem.numrevives or 0) + 1
			local timeout = TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REVIVE_TIME[inst.sg.mem.numrevives] or TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REVIVE_TIME[#TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REVIVE_TIME]
			local len = inst.AnimState:GetCurrentAnimationLength()
			local loops = math.floor(timeout / len + 0.5)
			timeout = loops * len
			inst.sg:SetTimeout(timeout)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				--delayed a frame in case we came from load
				TheWorld:PushEvent("ms_alterguardian_phase1_lunarrift_capturable", inst)
			end),
		},

        ontimeout = function(inst)
			inst.sg.statemem.exited_correct = true
			inst.sg:GoToState("regenerate_lunar", inst.sg.statemem.gestalt)
        end,

        onexit = function(inst)
			local gestalt = inst.sg.statemem.gestalt
			if inst.sg.statemem.exited_correct then
				gestalt.components.gestaltcapturable:SetEnabled(false)
				gestalt:AddTag("NOCLICK")
				gestalt.Transform:SetPosition(0, 0, 0)
				gestalt.Transform:SetRotation(0)
				gestalt.entity:SetParent(inst.entity)
			else
				gestalt:Remove()
				inst:SetNoMusic(false)
				inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_wagboss_LP", "idle_LP")
			end
			inst.Physics:SetActive(true)
			inst:RemoveTag("NOCLICK")
        end,
    },

    State {
        name = "regenerate_lunar",
		tags = {"busy", "noattack", "nointerrupt", "temp_invincible"},

		onenter = function(inst, gestalt)
			inst.components.health:SetPercent(math.max(inst.components.health:GetPercent(), TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REVIVE_HP))
			inst.components.health:AddRegenSource(inst, TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REGEN_AMOUNT, TUNING.ALTERGUARDIAN_PHASE1_LUNARRIFT_REGEN_PERIOD, "lunarriftregen")
			inst.AnimState:PlayAnimation("rebuild")
            inst:SetNoMusic(false)
            if not inst.SoundEmitter:PlayingSound("idle_LP") then
				inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_wagboss_LP", "idle_LP")
			end
			inst.sg.statemem.gestalt = gestalt
			gestalt.AnimState:PlayAnimation("rebuild")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("tantrum_pre")
            end),
        },

		onexit = function(inst)
			inst.sg.statemem.gestalt:Remove()
		end,
    },

	State {
		name = "captured",
		tags = { "busy", "nointerrupt", "noattack", "temp_invincible" },

		onenter = function(inst)
			inst:AddTag("NOCLICK")
			inst.persists = false--should already be set, but just in case
			inst.Physics:SetActive(false)
			inst.AnimState:PlayAnimation("collapse_empty_hit")
			inst.AnimState:PushAnimation("collapse_empty", false)
			inst.sg:SetTimeout(0.25)
		end,

		ontimeout = ErodeAway,
	},

    State {
        name = "spawn_lunar",
        tags = {"busy", "noaoestun", "noattack", "nosleep", "nostun", "spawn_lunar"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("spawn_lunar")
            inst.components.health:SetInvincible(true)

            inst.sg.statemem.frame = 0

			inst:EnableCameraFocus(true)
        end,

        onupdate = function(inst, dt)
            local frame_num = inst.AnimState:GetCurrentAnimationFrame() - 41
            if frame_num > inst.sg.statemem.frame then
                inst.sg.statemem.frame = frame_num
                lunarspawn_set_lightvalues(inst, frame_num)
            end
        end,

        timeline =
        {
            FrameEvent(6, function(inst)
                if TheWorld.components.wagpunk_arena_manager and TheWorld.components.wagpunk_arena_manager.wagstaff then
                    TheWorld.components.wagpunk_arena_manager.wagstaff:PushEvent("lunarguardianincoming")
                end
            end),
            FrameEvent(10, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
				spawn_land_screenshake(inst)
                spawn_landfx(inst)

                local ix, iy, iz = inst.Transform:GetWorldPosition()
                local players_in_speech_range = FindPlayersInRangeSq(ix, iy, iz, 625, true)
                for i, player in pairs(players_in_speech_range) do
                    player:DoTaskInTime(i * 8 * FRAMES, player_push_arrive_speech)
                end
            end),
            SoundFrameEvent(41, "moonstorm/creatures/boss/alterguardian1/spawn"),
        },

        events =
        {
            EventHandler("animover", go_to_idle),
        },

        onexit = function(inst)
            inst.components.health:SetInvincible(false)
			inst:EnableCameraFocus(false)
        end,
    },
}

local function play_foley(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/foley")
end

local function play_step(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
end

CommonStates.AddWalkStates(states,
{
    walktimeline = {
        TimeEvent(3*FRAMES, play_foley),
        TimeEvent(6*FRAMES, play_step),
        TimeEvent(6*FRAMES, PlayFootstep),
        TimeEvent(10*FRAMES, play_foley),
        TimeEvent(16*FRAMES, play_step),
        TimeEvent(16*FRAMES, PlayFootstep),
        TimeEvent(22*FRAMES, play_foley),
        TimeEvent(27*FRAMES, play_step),
        TimeEvent(27*FRAMES, PlayFootstep),
    },
    endtimeline = {
        TimeEvent(3*FRAMES, play_foley),
        TimeEvent(5*FRAMES, play_foley),
        TimeEvent(7*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step",nil,.50)
        end),
        TimeEvent(7*FRAMES, PlayFootstep),
        TimeEvent(8*FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step",nil,.25)
        end),
        TimeEvent(8*FRAMES, PlayFootstep),
    },
})

CommonStates.AddHitState(states)
CommonStates.AddSinkAndWashAshoreStates(states, {washashore = "shield_pst"})

return StateGraph("alterguardian_phase1", states, events, "idle", actionhandlers)
