require("stategraphs/commonstates")

local function GetHitState(inst)
	return (not inst.sg:HasStateTag("hiding") and "hitout")
		or (inst.sg:HasStateTag("vine") and "hitin")
		or "hithibernate"
end

local events =
{
	CommonHandlers.OnElectrocute(),

    EventHandler("death", function(inst)
        inst.sg:GoToState(inst.sg:HasStateTag("vine") and "deathvine" or "death")
    end),

	EventHandler("attacked", function(inst, data)
        if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			else
				inst.sg:GoToState(GetHitState(inst))
			end
        end
    end),

	EventHandler("worked", function(inst)
		if not inst.components.health:IsDead() then
			inst.sg:GoToState(GetHitState(inst))
		end
	end),
}

local states =
{
    State{
        name = "idleout",
        tags = { "idle" },

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle_out", true)
            else
                inst.AnimState:PlayAnimation("idle_out", true)
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(math.random() < .1 and "taunt" or "idleout")
                end
            end),
        },
    },

    State{
        name = "idlein",
        tags = { "idle", "hiding", "vine" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle", true)
        end,
    },

    State{
        name = "emerge",
		tags = { "idle", "hiding", "vine" },

        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("idle_trans")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/vine_emerge")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idlein")
                end
            end),
        },
    },

    State{
        name = "hibernate",
        tags = { "idle", "hiding" },

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            if playanim then
                inst.AnimState:PlayAnimation(playanim)
                inst.AnimState:PushAnimation("idle_hidden", true)
            else
                inst.AnimState:PlayAnimation("idle_hidden", true)
            end
        end,
    },

    State{
        name = "taunt",
        tags = { "idle" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt", true)
            inst.sg:SetTimeout(math.random() * 4 + 2)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idleout")
        end,
    },

    State{
        name = "hidebait",
		tags = { "busy", "hiding", "vine", "noelectrocute" },

        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hide")
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/lure_close") end),
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idlein")
                end
            end),
        },
    },

    State{
        name = "showbait",
		tags = { "busy", "noelectrocute" },

        onenter = function(inst, playanim)
            if inst.lure then
                inst.AnimState:OverrideSymbol("swap_dried", "meat_rack_food", inst.lure.prefab)
                inst.Physics:Stop()
                inst.AnimState:PlayAnimation("emerge")
            else
                inst.sg:GoToState("idlein")
            end
        end,

        timeline =
        {
            TimeEvent(FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/lure_open") end),
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("taunt")
                end
            end),
        },
    },

    State{
        name = "hitin",
		tags = { "busy", "hit", "hiding", "vine" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idlein")
                end
            end),
        },
    },

    State{
        name = "hithibernate",
        tags = { "busy", "hit", "hiding" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit_hidden")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("hibernate")
                end
            end),
        },
    },

    State{
        name = "hitout",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("hit_out")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:PushEvent("hidebait")
                end
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death_hidden")
            RemovePhysicsColliders(inst)
            --Task starts from PreventCharacterCollisionsWithPlacedObjects called by lureplant_bulb
            if inst._physicstask ~= nil then
                inst._physicstask:Cancel()
                inst._physicstask = nil
            end
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/lure_die")
        end,
    },

    State{
        name = "deathvine",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")
            RemovePhysicsColliders(inst)
            --Task starts from PreventCharacterCollisionsWithPlacedObjects called by lureplant_bulb
            if inst._physicstask ~= nil then
                inst._physicstask:Cancel()
                inst._physicstask = nil
            end
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/lure_die")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/vine_retract")
        end,
    },

    State{
        name = "picked",
		tags = { "busy", "hiding", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("pick")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/lure_close")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/eyeplant/vine_retract")
        end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
			end),
		},

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("hibernate")
                end
            end),
        },
    },

    State{
        name = "spawn",
		tags = { "busy", "hiding", "noelectrocute" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("grow")
        end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
			end),
		},

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("hibernate")
                end
            end),
        },

        onexit = function(inst)
            inst:PushEvent("freshspawn")
        end,
    },
}

CommonStates.AddElectrocuteStates(states,
nil, --timeline
{	--anims
	loop = function(inst)
		if not inst.sg.lasttags["hiding"] then
			return "shock_out_loop"
		end
		inst.sg:AddStateTag("hiding")
		if inst.sg.lasttags["vine"] then
			inst.sg:AddStateTag("vine")
			return "shock_loop"
		end
		return "shock_hidden_loop"
	end,
	pst = function(inst)
		if not inst.sg.lasttags["hiding"] then
			return "shock_out_pst"
		end
		inst.sg:AddStateTag("hiding")
		if inst.sg.lasttags["vine"] then
			inst.sg:AddStateTag("vine")
			return "shock_pst"
		end
		return "shock_hidden_pst"
	end,
},
{	--fns
	onanimover = function(inst)
		if inst.AnimState:AnimDone() then
			if not inst.sg:HasStateTag("hiding") then
				inst:PushEvent("hidebait")
			else
				inst.sg:GoToState(inst.sg:HasStateTag("vine") and "idlein" or "hibernate")
			end
		end
	end,
})

return StateGraph("lureplant", states, events, "idlein")
