require("stategraphs/commonstates")

local SPLAT_DAMAGE_MUST_TAGS = { "_combat" }
local SPLAT_DAMAGE_CANT_TAGS = { "insect", "INLIMBO", "playerghost", "invisible", "hidden" }

local WALK_SPEED = 5

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "action"),
    ActionHandler(ACTIONS.POLLINATE, function(inst)
		if inst.sg:HasStateTag("landed") then
			return "pollinate"
		else
			return "land"
		end
    end),
}

local events=
{
	EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("electrocute") then
				inst.sg:GoToState("hit")
			end
		end
	end),
    EventHandler("doattack", function(inst) if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then inst.sg:GoToState("attack") end end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),

    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
			local wants_to_move = inst.components.locomotor:WantsToMoveForward()
			if not inst.sg:HasStateTag("attack") then
				if wants_to_move then
					inst.sg:GoToState("moving")
				else
					inst.sg:GoToState("idle")
				end
			end
        end
    end),
}

local states=
{
    State{
        name = "splat",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("explode")
			inst.SoundEmitter:PlaySound(inst.sounds.explode)
        end,
        timeline=
        {
            TimeEvent(11*FRAMES, function(inst)
                inst.DynamicShadow:Enable(false)

				local x, y, z = inst.Transform:GetWorldPosition()
				local ents = TheSim:FindEntities(x, 0, z, TUNING.MOSQUITO_BURST_RANGE, SPLAT_DAMAGE_MUST_TAGS, SPLAT_DAMAGE_CANT_TAGS)

				for _, ent in ipairs(ents) do
                   -- print(ent, not ent:IsInLimbo(), ent.components.combat ~= nil,  inst.components.combat:IsAlly(ent), inst.lastleader  )
					if not ent:IsInLimbo() and ent.components.combat ~= nil and ent ~= inst.lastleader and  (not inst.lastleader or not ent.components.combat:IsAlly(inst.lastleader)) then
						ent.components.combat:GetAttacked(inst, TUNING.MOSQUITO_BURST_DAMAGE, nil)
					end
				end
			end),
        },
		events=
        {
            EventHandler("animover", function(inst) inst:Remove() end),
        },
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
			inst.SoundEmitter:KillSound("buzz")
			if not inst.toofat then
				inst.SoundEmitter:PlaySound(inst.sounds.death)
				inst.AnimState:PlayAnimation("death")
			else
				inst.SoundEmitter:PlaySound(inst.sounds.death)
				inst.AnimState:PlayAnimation("explode_pre")
			end
			inst.Physics:Stop()
			RemovePhysicsColliders(inst)
			if inst.components.lootdropper then
				inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()))
			end
        end,

		events=
        {
            EventHandler("animover", function(inst) if inst.toofat then inst.sg:GoToState("splat") end end),
        },

        timeline =
        {
            TimeEvent(10 * FRAMES, LandFlyingCreature),
        },
    },

    State{
        name = "action",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle", true)
            inst:PerformBufferedAction()
        end,
        events=
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("idle")
            end),
        }
    },

    State{
        name = "moving",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            if not inst.AnimState:IsCurrentAnimation("walk_loop") then
                inst.AnimState:PlayAnimation("walk_loop", true)
            end
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("moving")
        end,
    },

    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("walk_loop") then
                inst.AnimState:PlayAnimation("walk_loop", true)
            end
        end,
    },

    State{
        name = "attack",
        tags = {"attack"},

        onenter = function(inst, cb)
            inst.Physics:Stop()
            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk")
        end,

        timeline=
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.attack) end),
            TimeEvent(15*FRAMES, function(inst) inst.components.combat:DoAttack() end),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "hit",
        tags = {"busy"},

        onenter = function(inst)
            inst.SoundEmitter:PlaySound(inst.sounds.hit)
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end ),
        },
    },
}

CommonStates.AddSleepStates(states,
{
    starttimeline =
    {
        TimeEvent(23*FRAMES, function(inst)
            inst.SoundEmitter:KillSound("buzz")
            LandFlyingCreature(inst)
        end),
    },
    waketimeline =
    {
        TimeEvent(1*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.buzz, "buzz") end),
    },
},
{
    onsleep = LandFlyingCreature,
    onwake = RaiseFlyingCreature,
})
CommonStates.AddFrozenStates(states, LandFlyingCreature, RaiseFlyingCreature)
CommonStates.AddElectrocuteStates(states)

return StateGraph("mosquito", states, events, "idle", actionhandlers)

