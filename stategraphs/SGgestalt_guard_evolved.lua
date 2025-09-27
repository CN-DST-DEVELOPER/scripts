require("stategraphs/commonstates")

local actionhandlers =
{
}

local events =
{
    CommonHandlers.OnLocomote(false, true),

    EventHandler("death", function(inst)
		inst.sg:GoToState("death", "death")
	end),

    EventHandler("doattack", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("attack")
        end
    end),

	EventHandler("captured", function(inst)
		--can interrupt ANY state
		inst.sg:GoToState("captured")
	end),

    EventHandler("spawned", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState("spawned")
        end
    end),

    EventHandler("attacked", function(inst)
        if not inst.components.health:IsDead() and inst.sg:HasStateTag("idle") then
            inst.sg:GoToState("hit")
        end
    end),

    EventHandler("relocate", function(inst)
        if (inst.sg.mem.missed_dashes or 0) > 3 or math.random() < TUNING.GESTALT_EVOLVED_EXPLODE_CHANCE then
            inst.sg.mem.missed_dashes = nil
            inst.sg:GoToState("attack_explode")
        else
            inst.sg:GoToState("relocate")
        end
    end),
}

--NOTE: these are stategraph tags!
local INVALID_ATTACK_STATE_TAGS = {"bedroll", "knockout", "sleeping", "tent", "waking"}
local function IsValidAttackTarget(inst, target, x, z, rangesq)
	local dsq = target:GetDistanceSqToPoint(x, 0, z)
	return dsq < rangesq
		and not (target.components.health and target.components.health:IsDead())
		and not (target.sg and target.sg:HasAnyStateTag(INVALID_ATTACK_STATE_TAGS))
		and not target:HasAnyTag("brightmare", "brightmareboss")
		and inst.components.combat:CanTarget(target)
		, dsq
end

--These tags and testfn are used with DoAreaAttack below,
--and should give the same result as IsValidAttackTarget.
local AREAATTACK_EXCLUDETAGS = { "INLIMBO", "notarget", "invisible", "noattack", "flight", "playerghost", "brightmare", "brightmareboss" }
local function AreaAttackTestFn(target, inst)
	return not (target.components.health and target.components.health:IsDead())
		and not (target.sg and target.sg:HasAnyStateTag(INVALID_ATTACK_STATE_TAGS))
		and inst.components.combat:CanTarget(target)
end

local function FindBestAttackTarget(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	local rangesq = TUNING.GESTALT_ATTACK_HIT_RANGE_SQ

	local target = inst.components.combat.target
	if target and IsValidAttackTarget(inst, target, x, z, rangesq) then
		return target
    end

	target = nil
    for _, player in pairs(AllPlayers) do
		local isvalid, dsq = IsValidAttackTarget(inst, player, x, z, rangesq)
		if isvalid then
			rangesq = dsq
			target = player
        end
    end
	return target
end

local function DoSpecialAttack(inst, target)
	if target.components.sanity ~= nil then
		target.components.sanity:DoDelta(TUNING.GESTALT_ATTACK_DAMAGE_SANITY)
	end

    inst.components.combat:DoAttack(target)
    if not (target.components.health ~= nil and target.components.health:IsDead()) then
        local grogginess = target.components.grogginess
        if grogginess ~= nil then
            grogginess:AddGrogginess(TUNING.GESTALT_EVOLVED_ATTACK_DAMAGE_GROGGINESS, TUNING.GESTALT_EVOLVED_ATTACK_DAMAGE_KO_TIME)
        end
    end
end

local function go_to_idle(inst) inst.sg:GoToState("idle") end

local states =
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/idle_LP", "idle_lp")

            if inst._do_despawn then
                inst.sg:GoToState("relocate")
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState((inst._do_despawn and "relocate") or "idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("idle_lp")
        end,
    },

    State{
        name = "spawned",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("emerge2")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/emerge_vocals")
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    State{
        name = "emerge",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("emerge")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/emerge_vocals")
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    State{
        name = "death",
        tags = {"busy", "noattack"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("melt")
            inst.persists = false

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/melt")

            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,

        events =
        {
            EventHandler("animover", function(inst) inst:Remove() end),
        },

        onexit = function(inst) inst:Remove() end,
    },

    -- Relocation
    State{
        name = "relocate",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("melt")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/melt")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst._do_despawn then
                    inst:Remove()
                else
				    inst.sg:GoToState("relocating")
                end
			end),
        },
    },

    State{
        name = "relocating",
		tags = { "busy", "noattack", "hidden", "invisible" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			inst:Hide()
            inst.sg:SetTimeout(
                (math.random() * TUNING.GESTALT_EVOLVED_RELOCATE_TIME_RAND) + TUNING.GESTALT_EVOLVED_RELOCATE_TIME_BASE
            )
        end,

        ontimeout = function(inst)
			inst.sg.statemem.dest = inst:FindRelocatePoint()
			if inst.sg.statemem.dest ~= nil then
				inst.sg:GoToState("emerge")
			else
				inst:Remove()
			end
		end,

		onexit = function(inst)
			if inst.sg.statemem.dest ~= nil then
				inst.Transform:SetPosition(inst.sg.statemem.dest:Get())
				inst:Show()
			else
				inst:Remove()
			end
		end
    },

    -- Attacks
    State{
        name = "attack",
        tags = { "busy", "noattack", "attack", "jumping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("attack")

			inst.components.locomotor:Stop()
			if inst.components.combat.target ~= nil then
				inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
			end
	        inst.components.combat:StartAttack()

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
		end,

        timeline =
        {
            FrameEvent(15, function(inst)
                inst.Physics:SetMotorVelOverride(20, 0, 0)
                inst.sg.statemem.enable_attack = true
            end),
            FrameEvent(25, function(inst)
                if inst.sg.statemem.enable_attack then
                    -- We didn't hit anything... count it as a miss.
                    inst.sg.statemem.enable_attack = false
                    inst.sg.mem.missed_dashes = (inst.sg.mem.missed_dashes or 0) + 1
                end
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
            end),
            FrameEvent(30, function(inst)
                inst.sg:RemoveStateTag("noattack")
            end),
        },

        onupdate = function(inst)
			if inst.sg.statemem.enable_attack then
				local target = FindBestAttackTarget(inst)
				if target ~= nil then
					DoSpecialAttack(inst, target)
                    inst.sg.statemem.enable_attack = false
				end
			end
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },

        onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:Stop()
		end,
    },

    State{
        name = "attack_explode",
        tags = { "busy", "noattack", "attack", "jumping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("explode")

			inst.components.locomotor:Stop()
			if inst.components.combat.target ~= nil then
				inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
			end
	        inst.components.combat:StartAttack()

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/attack_vocals")
		end,

        timeline =
        {
            FrameEvent(28, function(inst)
				inst.components.combat:DoAreaAttack(inst, 4, nil, AreaAttackTestFn, nil, AREAATTACK_EXCLUDETAGS)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("relocate")
            end),
        },

        onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:Stop()
		end,
    },

    State{
        name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
        end,

        events =
        {
            EventHandler("animover", go_to_idle),
        },
    },

    --
	State{
		name = "captured",
		tags = { "busy", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("melt")
			inst.AnimState:SetFrame(1)
			inst.AnimState:SetDeltaTimeMultiplier(2)
			inst:AddTag("NOCLICK")

            inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/melt")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					--shouldn't reach here
					inst.sg:GoToState("emerge")
				end
			end),
		},

		onexit = function(inst)
			--shouldn't reach here
			inst.AnimState:SetDeltaTimeMultiplier(1)
			inst:RemoveTag("NOCLICK")
		end,
	},
}

CommonStates.AddWalkStates(states,
nil, nil, nil, true,
{
    walkonenter = function(inst)
        inst.SoundEmitter:PlaySound("rifts5/gestalt_evolved/walk_LP", "walk_lp")
    end,
    walkonexit = function(inst)
        inst.SoundEmitter:KillSound("walk_lp")
    end,
})


return StateGraph("gestalt_guard_evolved", states, events, "idle", actionhandlers)
