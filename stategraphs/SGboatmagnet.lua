local events =
{
}

--V2C: TERRIBLE, but not worth the effort to refactor.
--     plz DO NOT COPY or reuse ANY code from boatmagnet.

local states =
{
    State {
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            if inst.components.boatmagnet and inst.components.boatmagnet:PairedBeacon() ~= nil then
                inst.AnimState:PlayAnimation("idle_activated", true)
            else
				inst.AnimState:PlayAnimation("idle")
            end
        end,

		events =
		{
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
					if inst.components.boatmagnet ~= nil and inst.components.boatmagnet:PairedBeacon() ~= nil then
						inst.AnimState:PushAnimation("idle_activated")
					else
						inst.AnimState:PushAnimation("idle", false)
					end
				end
			end),
		},
    },

    State {
        name = "place",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("place")
        end,

		timeline =
		{
			TimeEvent(27 * FRAMES, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

        events =
        {
			EventHandler("worked", function(inst)
				if inst.sg:HasStateTag("caninterrupt") and not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "search_pre",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("search_pre")
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/magnet_search_pre") 
        end,

        events =
        {
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animover", function(inst)
				inst.sg:GoToState(inst.AnimState:IsCurrentAnimation("search_pre") and "search_loop" or "search_pre")
            end),
        },
    },

    State {
        name = "search_loop",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("search_loop")
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/beacon_search","search_loop")
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("search_loop")
        end,

        events =
        {
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animover", function(inst)
				if inst.AnimState:IsCurrentAnimation("search_loop") then
					local nearestbeacon = inst.components.boatmagnet ~= nil and inst.components.boatmagnet:FindNearestBeacon() or nil
					if nearestbeacon ~= nil then
						inst.components.boatmagnet:PairWithBeacon(nearestbeacon)
						inst.sg:GoToState("success")
					else
						inst.sg:GoToState("fail")
					end
				else
					inst.sg:GoToState("search_pre")
				end
            end),
        },
    },

    State {
        name = "success",
        tags = {},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("success")
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/paired")
        end,

        events =
        {
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("pull_pre")
            end),
        },
    },

    State {
        name = "fail",
        tags = {},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("fail")
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/pair_failed")
        end,

        events =
        {
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit_off") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State {
        name = "pull_pre",
        tags = { "busy", "pulling" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("pull_pre")
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/magnet_lp_start", "pull_loop_start")
            
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("pull_loop_start")
        end,        

        events =
        {
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit") then
					inst.AnimState:PlayAnimation("hit")
				end
			end),
            EventHandler("animover", function(inst)
                inst.sg:GoToState("pull")
            end),
        },
    },

    State {
        name = "pull",
        tags = { "pulling" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("pull", true)
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/magnet_lp","pull_loop")
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("pull_loop")
        end,

		events =
		{
			EventHandler("worked", function(inst)
				if not inst.AnimState:IsCurrentAnimation("hit") then
					inst.AnimState:PlayAnimation("hit")
					inst.AnimState:PushAnimation("pull")
				end
			end),
		},
    },

    State {
        name = "pull_pst",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("pull_pst", false)
            if inst.components.boatmagnet and inst.components.boatmagnet:PairedBeacon() == nil then
                inst.AnimState:PushAnimation("fail", false)
            end
            inst.SoundEmitter:PlaySound("monkeyisland/autopilot/magnet_lp_end")
        end,

        events =
        {
			EventHandler("worked", function(inst)
				if inst.AnimState:IsCurrentAnimation("pull_pst") then
					inst.AnimState:PlayAnimation("hit")
					if inst.components.boatmagnet ~= nil and inst.components.boatmagnet:PairedBeacon() == nil then
						inst.AnimState:PushAnimation("fail", false)
					end
				elseif inst.AnimState:IsCurrentAnimation("fail") then
					inst.AnimState:PlayAnimation("hit_off")
				end
			end),
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

	State {
		name = "burnt",
		tags = { "busy", "burnt" },
		--Dummy state don't do anything
		--V2C: Please don't copy this...
		--     The correct thing is to refactor boatmagnet, and remove the stategraph on burnt.

		onexit = function(inst)
			if BRANCH == "dev" then
				assert(false)
			end
		end,
	},
}

return StateGraph("boatmagnet", states, events, "idle")
