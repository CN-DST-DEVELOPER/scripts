require("stategraphs/commonstates")

local events =
{
	EventHandler("locomote", function(inst)
		if inst.components.locomotor:WantsToMoveForward() and not inst.components.gestaltcapturable:IsTargeted() then
			if inst.sg:HasStateTag("idle") then
				inst.sg:GoToState("walk_start")
			end
		elseif inst.sg:HasStateTag("moving") then
			inst.sg:GoToState("walk_stop")
		end
	end),
	EventHandler("gestaltcapturable_targeted", function(inst)
		if inst.sg:HasStateTag("moving") then
			inst.sg:GoToState("walk_stop")
		end
	end),

    EventHandler("death", function(inst)
		inst.sg:GoToState("death", "death")
	end),
    EventHandler("doattack", function(inst)
        if not (inst.sg:HasStateTag("busy")) then
            inst.sg:GoToState(inst.isguard and "guardattack"
								or "attack")
        end
    end),
	EventHandler("captured", function(inst)
		--can interrupt ANY state
		inst.sg:GoToState("captured")
	end),
}

local function FindBestAttackTarget(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
    local closestPlayer = nil
	local rangesq = TUNING.GESTALT_ATTACK_HIT_RANGE_SQ
    for i, v in ipairs(AllPlayers) do
        if not IsEntityDeadOrGhost(v) and
			not (v.sg:HasStateTag("knockout") or v.sg:HasStateTag("sleeping") or v.sg:HasStateTag("bedroll") or v.sg:HasStateTag("tent") or v.sg:HasStateTag("waking")) and
            v.entity:IsVisible() then
            local distsq = v:GetDistanceSqToPoint(x, y, z)
            if distsq < rangesq then
                rangesq = distsq
                closestPlayer = v
            end
        end
    end
    return closestPlayer
end

local function DoSpecialAttack(inst, target)
	if target.components.sanity ~= nil then
		target.components.sanity:DoDelta(TUNING.GESTALT_ATTACK_DAMAGE_SANITY)
	end
	local grogginess = target.components.grogginess
	if grogginess ~= nil then
		grogginess:AddGrogginess(TUNING.GESTALT_ATTACK_DAMAGE_GROGGINESS, TUNING.GESTALT_ATTACK_DAMAGE_KO_TIME)
		if grogginess.knockoutduration == 0 then
			target:PushEvent("attacked", {attacker = inst, damage = 0})
		else
			-- TODO: turn on special hud overlay while asleep in enlightened dream land
		end
	else
		target:PushEvent("attacked", {attacker = inst, damage = 0})
	end
end

local states=
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle")
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
        name = "emerge",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("emerge")
			inst.components.gestaltcapturable:SetEnabled(false)
        end,

		events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },

		onexit = function(inst)
			inst.components.gestaltcapturable:SetEnabled(true)
		end,
    },

    State{
        name = "death",
        tags = {"busy", "noattack"},

        onenter = function(inst)
			if inst:IsAsleep() then
				inst:Remove()
				return
			end
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("melt")
            inst.persists = false
			inst.components.gestaltcapturable:SetEnabled(false)
        end,

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
			end),
			EventHandler("entitysleep", function(inst)
				inst:Remove()
			end),
        },

		onexit = function(inst)
			--Shouldn't reach here
			inst.components.gestaltcapturable:SetEnabled(true)
		end,
    },

    State{
        name = "relocate",
        tags = {"busy", "noattack", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("melt")
			inst.components.gestaltcapturable:SetEnabled(false)
        end,

        events =
        {
            EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.relocating = true
					inst.sg:GoToState("relocating")
				end
			end),
        },

		onexit = function(inst)
			if not inst.sg.statemem.relocating then
				inst.components.gestaltcapturable:SetEnabled(true)
			end
		end,
    },

    State{
        name = "relocating",
		tags = { "busy", "noattack", "hidden", "invisible" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
			inst:Hide()
			inst.components.gestaltcapturable:SetEnabled(false)
            inst.sg:SetTimeout(math.random() * 0.5 + 0.25)
        end,

        ontimeout = function(inst)
			if inst._can_despawn then
				inst:Remove()
			else
				inst.sg.statemem.dest = inst:FindRelocatePoint()
				if inst.sg.statemem.dest ~= nil then
					inst.sg:GoToState("emerge")
				else
					inst:Remove()
				end
			end
		end,

		onexit = function(inst)
			inst:Show()
			if inst.sg.statemem.dest ~= nil then
				inst.Transform:SetPosition(inst.sg.statemem.dest:Get())
			else
				inst.components.gestaltcapturable:SetEnabled(true)
			end
		end
    },

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
		end,

        timeline=
        {
            TimeEvent(15*FRAMES, function(inst)
					inst.Physics:SetMotorVelOverride(20, 0, 0)
					inst.sg.statemem.enable_attack = true
				end ),
            TimeEvent(25*FRAMES, function(inst)
					inst.Physics:ClearMotorVelOverride()
					inst.components.locomotor:Stop()
					inst.sg.statemem.enable_attack = false
					inst.components.combat:DropTarget()
				end ),
        },

        onupdate = function(inst)
			if inst.sg.statemem.enable_attack then
				local target = FindBestAttackTarget(inst)
				if target ~= nil then
					DoSpecialAttack(inst, target)
					inst.sg.statemem.attack_landed = true
					inst.components.combat:DropTarget()
					inst.sg:GoToState("mutate_pre")
				end
			end
        end,

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },

        onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:Stop()
			if not inst.sg.statemem.attack_landed then
				inst.components.combat:DropTarget()
			end
		end,
    },

    State{
        name = "guardattack",
        tags = { "busy", "noattack", "attack", "jumping" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("attack")
			inst.components.locomotor:Stop()
			if inst.components.combat.target ~= nil then
				inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
			end
	        inst.components.combat:StartAttack()
		end,

        timeline=
        {
            TimeEvent(8*FRAMES, function(inst)
					if inst.components.combat.target ~= nil then
						inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
					end
					inst.Physics:SetMotorVelOverride(30, 0, 0)
					inst.sg.statemem.enable_attack = true
				end ),
            TimeEvent(19*FRAMES, function(inst)
					inst.Physics:ClearMotorVelOverride()
					inst.components.locomotor:Stop()
					inst.sg.statemem.enable_attack = false
					inst.components.combat:DropTarget()
				end ),
        },

        onupdate = function(inst)
			if inst.sg.statemem.enable_attack then
				local target = inst.components.combat.target
				if target ~= nil and target:IsValid() and inst:GetDistanceSqToInst(target) <= TUNING.GESTALT_ATTACK_HIT_RANGE_SQ then
                    if inst.components.combat:CanTarget(target) then
						inst.components.combat:DoAttack(target)
						inst.sg:GoToState("mutate_pre", 6)
					end
				end
			end
        end,

        events =
        {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
        },

        onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:Stop()
		end,
    },

    State{
        name = "mutate_pre",
        tags = {"busy", "noattack", "jumping"},

        onenter = function(inst, speed)
			inst.Physics:SetMotorVelOverride(speed or 2, 0, 0)
            inst.AnimState:PlayAnimation("mutate")
			inst.persists = false
        end,

        events =
        {
            EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst:Remove()
				end
			end),
        },
    },

	State{
		name = "captured",
		tags = { "busy", "noattack", "nointerrupt" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("melt")
			inst.AnimState:SetFrame(1)
			inst.AnimState:SetDeltaTimeMultiplier(2)
			inst:AddTag("NOCLICK")
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

local function SpawnTrail(inst)
	if not inst._notrail then
		local trail = SpawnPrefab("gestalt_trail")
		trail.Transform:SetPosition(inst.Transform:GetWorldPosition())
		trail.Transform:SetRotation(inst.Transform:GetRotation())
	end
end

CommonStates.AddWalkStates(states,
{
    starttimeline =
    {
    },
    walktimeline =
    {
        TimeEvent(0*FRAMES, SpawnTrail),
        --TimeEvent(5*FRAMES, SpawnTrail),
    },
    endtimeline =
    {
    },
}
, nil, nil, true)


return StateGraph("gestalt", states, events, "idle")
