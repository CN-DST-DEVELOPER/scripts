require("behaviours/wander")

-- This controller determines which head segment should reign control, and then lets their brain handle things.

local SWITCH_CHANCES = { -- Switch eventually if we have the same control priority, for variety!
    0,
    0.02,
    0.04,
    0.08,
    0.10,
    0.15,
    0.25,
}

local ShadowThrallCentipedeControllerBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)

    self.switch_chance_index = 1
end)

function ShadowThrallCentipedeControllerBrain:IncreaseSwitchChance()
    self.switch_chance_index = math.min(self.switch_chance_index + 1, #SWITCH_CHANCES)
end

function ShadowThrallCentipedeControllerBrain:ResetSwitchChance()
    self.switch_chance_index = 1
end

function ShadowThrallCentipedeControllerBrain:RollSwitchChance()
    if math.random() <= SWITCH_CHANCES[self.switch_chance_index] then
        self:ResetSwitchChance()
        self.inst.components.centipedebody:GiveControlToOtherHead()
    end
end

local UPDATE_RATE = 3
function ShadowThrallCentipedeControllerBrain:OnStart()
    local centipedebody = self.inst.components.centipedebody

	local root = PriorityNode({
        WhileNode(
			function()
				return not centipedebody.head_in_control or not centipedebody.head_in_control.sg:HasStateTag("struggling")
            end,
			"<busy state guard>",
            ConditionNode(function()
                local controller_head = nil
                local priority = self.inst.PRIORITY_BEHAVIOURS.WANDERING
                for i, head in ipairs(centipedebody.heads) do
                    if head.control_priority > priority then
                        priority = head.control_priority
                        controller_head = head
                    end
                end

                if controller_head
                    and controller_head ~= centipedebody.head_in_control then
                    centipedebody:GiveControlToHead(controller_head)
                    self:ResetSwitchChance()
                    return true
                elseif centipedebody.heads[1] and centipedebody.heads[2] and centipedebody.heads[1].control_priority == centipedebody.heads[2].control_priority then
                    self:IncreaseSwitchChance()
                    self:RollSwitchChance()
                end

                return false
		    end)
        )
	}, UPDATE_RATE)

	self.bt = BT(self.inst, root)
end

return ShadowThrallCentipedeControllerBrain