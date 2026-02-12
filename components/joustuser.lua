local JoustUser = Class(function(self, inst)
    self.inst = inst
    --edge
    self.edgedistance = 2
end)

function JoustUser:SetCanJoustFn(fn)
    -- This function should return a fail reason to stop a joust from going because the action target becoming invalid is still a valid joust action.
    self.canjoustfn = fn
end

function JoustUser:CanJoust()
    if self.canjoustfn == nil then
        return true
    end

    return self.canjoustfn(self.inst)
end

function JoustUser:SetOnStartJoustFn(fn)
    self.onstartjoustfn = fn
end

function JoustUser:StartJoust()
    if self.onstartjoustfn ~= nil then
        self.onstartjoustfn(self.inst)
    end
end

function JoustUser:SetOnEndJoustFn(fn)
    self.onendjoustfn = fn
end

function JoustUser:EndJoust()
    if self.onendjoustfn ~= nil then
        self.onendjoustfn(self.inst)
    end
end

local function _CheckEdge(x, z, dist, rot)
    rot = rot * DEGREES
    x = x + math.cos(rot) * dist
    z = z - math.sin(rot) * dist
    return not TheWorld.Map:IsAboveGroundAtPoint(x, 0, z) or TheWorld.Map:IsGroundTargetBlocked(Vector3(x, 0, z))
end

function JoustUser:CheckEdge()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local rot = self.inst.Transform:GetRotation()
    --only return true if it detects edge at all 3 angles
    return _CheckEdge(x, z, self.edgedistance, rot)
        and _CheckEdge(x, z, self.edgedistance, rot + 30)
        and _CheckEdge(x, z, self.edgedistance, rot - 30)
end

function JoustUser:SetEdgeDistance(distance)
    self.edgedistance = distance
end

return JoustUser
