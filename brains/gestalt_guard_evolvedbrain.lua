require("behaviours/standstill")

local GestaltGuardEvolvedBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetTarget(inst)
    return inst.components.combat.target
end

local function GetTargetPos(inst)
    local target = GetTarget(inst)
    return target and target:GetPosition() or nil
end

local function IsTarget(inst, target)
    return inst.components.combat:TargetIs(target)
end

function GestaltGuardEvolvedBrain:OnStart()
    local distancetotarget = nil
    local function hastarget()
        return distancetotarget ~= nil
    end
    local function calculatedistancetotarget()
        if not (self.inst.components.combat.target and self.inst.components.combat.target:IsValid()) then
            distancetotarget = nil
            return
        end

        distancetotarget = math.sqrt(self.inst:GetDistanceSqToInst(self.inst.components.combat.target))
    end
    local function startcombatphase()
        self.inst:FacePoint(self.inst.components.combat.target.Transform:GetWorldPosition()) -- Always do this.

        if self.inst._should_teleport then
            if self.inst:TryAttack_Teleport_GetCloser() then
                return true
            end
        end

        if self.inst:TryAttack_Teleport_Evade() then
            return true
        end

        return false
    end
    local root = PriorityNode({
        WhileNode(
            function()
                return not self.inst.sg:HasStateTag("busy")
            end,
            "<busy state guard>",
            PriorityNode({
                FailIfSuccessDecorator(ActionNode(calculatedistancetotarget)),
                IfNode(hastarget, "Combat",
                    PriorityNode({
                        ConditionNode(startcombatphase),
                        IfNode(function() return distancetotarget < TUNING.GESTALT_EVOLVED_CLOSE_RANGE end, "Range: Close",
                            ActionNode(function() return self.inst:TryAttack_Close() end)),
                        IfNode(function() return distancetotarget < TUNING.GESTALT_EVOLVED_MID_RANGE end, "Range: Mid",
                            ActionNode(function() return self.inst:TryAttack_Mid() end)),
                        IfNode(function() return distancetotarget < TUNING.GESTALT_EVOLVED_FAR_RANGE end, "Range: Far",
                            ActionNode(function() return self.inst:TryAttack_Far() end)),
                        ActionNode(function() return self.inst:TryAttack_Teleport_GetCloser() end),
                    }, 0.5)),
                StandStill(self.inst),
            }, 0.5)),
        -- Do nothing while in busy state guard.
    }, 0.5)

    self.bt = BT(self.inst, root)
end

return GestaltGuardEvolvedBrain