require("stategraphs/commonstates")

local events = {
    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
			local is_moving = inst.sg:HasStateTag("moving")
			local wants_to_move = inst.components.locomotor:WantsToMoveForward()
			if is_moving ~= wants_to_move then
				if wants_to_move then
					inst.sg.statemem.wantstomove = true
				else
					inst.sg:GoToState("idle")
				end
			end
        end
    end),
    EventHandler("moonstormstaticcapturable_targeted", function(inst)
        inst.sg.mem.holdstill = true
        if inst.sg:HasStateTag("moving") then
            inst.sg:GoToState("idle")
        end
    end),
    EventHandler("moonstormstaticcapturable_untargeted", function(inst)
        inst.sg.mem.holdstill = nil
    end),
}


local states = {
    State{
        name = "moving",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
        end,
    },

    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.sg:SetTimeout(math.random() * 0.25 + 0.25)
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.wantstomove and not inst.sg.mem.holdstill then
                inst.sg:GoToState("moving")
            else
                inst.sg:GoToState("idle")
            end
        end,
    },
}

return StateGraph("moonstormstatic", states, events, "idle")
