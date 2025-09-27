local function ConstrainToBody(body, last_body)
    if last_body:IsValid() then
        local diameter = body.Physics:GetRadius() * 2.0
        body.Physics:P2PConstrainTo(last_body.entity)
        body.Physics:SetP2PConstrainPivots(diameter, 0, 0, 0, 0, 0)
        body.controller.components.centipedebody:OnUpdate(nil, true)
        body.Physics:Stop()
    else
        print("ERROR ERROR CENTIPEDE IS PROBABLY GOING TO FAIL")
    end
end

local function OnBodySleep(body)
    local centipedebody = body.controller:IsValid() and body.controller.components.centipedebody
    if centipedebody then
        centipedebody:Halt()
    end
end

local function OnBodyAwake(body)
    local centipedebody = body.controller:IsValid() and body.controller.components.centipedebody
    if centipedebody then
        centipedebody:CheckUnhalt()
    end
end

local function OnBodyRemove(body)
    body:RemoveEventCallback("onremove", OnBodyRemove)
    if body.controller:IsValid() then
        body.controller:Remove()
    end
end

local function AddConstrainedBody(body, last_body)
    body:DoTaskInTime(0, ConstrainToBody, last_body)
end

local function OnDeath(inst)
    local centipedebody = inst.components.centipedebody
    if centipedebody then
        inst:StopUpdatingComponent(centipedebody)
    end
end

local CentipedeBody = Class(function(self, inst)
    self.inst = inst

    self.bodies = {}
    self.heads = {}

    self.headprefab = "shadowthrall_centipede_head"
    self.torsoprefab = "shadowthrall_centipede_body"
    self.num_torso = 5
    self.backwards_locomoting = false
    self.turnspeed = TUNING.SHADOWTHRALL_CENTIPEDE.TURNSPEED
    self.max_torso = TUNING.SHADOWTHRALL_CENTIPEDE.MAX_SEGMENTS

    self.halted = false

    self.inst:StartUpdatingComponent(self)
    self.inst:ListenForEvent("death", OnDeath)
end)

function CentipedeBody:Halt()
    if not self.halted then
        self.halted = true

        for k, head in pairs(self.heads) do
            head:StopBrain("centipedebody_halt")
        end
    end
end

function CentipedeBody:CheckUnhalt()
    if self.halted then
        local all_awake = true
        --
        for k, body in ipairs(self.bodies) do
            if body:IsAsleep() then
                all_awake = false
                break
            end
        end
        --
        if all_awake then
            self.halted = false

            for k, head in pairs(self.heads) do
                head:RestartBrain("centipedebody_halt")
            end
        end
    end
end

function CentipedeBody:IsHalted()
    return self.halted
end

function CentipedeBody:IsNonControllingHead(head)
    return head.prefab == self.headprefab and head ~= self.head_in_control
end

function CentipedeBody:GetControllingHead()
    return self.head_in_control
end

function CentipedeBody:CreateFullBody()
    self:SpawnHead()
    --
    for _ = 1, self.num_torso do
        self:SpawnTorso()
    end
    --
    self:SpawnHead()
    --
    self:GiveControlToHead(self.heads[1])
end

function CentipedeBody:SpawnHead()
    return self:SpawnSegment(self.headprefab)
end

function CentipedeBody:SpawnTorso()
    return self:SpawnSegment(self.torsoprefab)
end

function CentipedeBody:SetSegment(body, index)
    local lastbody = self.bodies[index] or self.bodies[#self.bodies]
    local nextbody = index and self.bodies[index + 1] or nil

    body.controller = self.inst
    if index then
        table.insert(self.bodies, index+1, body)
    else
        table.insert(self.bodies, body)
    end

    if lastbody then
        AddConstrainedBody(body, lastbody)
    end

    if nextbody then
        AddConstrainedBody(nextbody, body)
    end

    body:ListenForEvent("entitysleep", OnBodySleep)
    body:ListenForEvent("entitywake", OnBodyAwake)
    body:ListenForEvent("onremove", OnBodyRemove)

    if body.prefab == self.headprefab then
        body.has_brain_control = false
        body.flipped = #self.heads == 1 and true or nil
        table.insert(self.heads, body)
    end
end

function CentipedeBody:SpawnSegment(prefab, pos, index)
    local lastbody = self.bodies[index] or self.bodies[#self.bodies] or self.inst

    if not pos then
        local rot = lastbody.Transform:GetRotation() * DEGREES
        local diameter = lastbody:GetPhysicsRadius(0) * 2
        pos = lastbody:GetPosition() + Vector3(-math.cos(rot) * diameter, 0, math.sin(rot) * diameter)
    end

    local body = SpawnPrefab(prefab)
    body.Transform:SetPosition(pos.x, pos.y, pos.z)
    self:SetSegment(body, index)

    return body
end

function CentipedeBody:GrowNewSegment(index)
    if #self.bodies >= self.max_torso then
        return
    end
    --
    index = index or math.random(#self.bodies - 1) -- Don't add to the very end of the body
    local body = self:SpawnSegment(self.torsoprefab, nil, index)
    --
    body:PushEvent("grow_segment")
    --
    return body
end

function CentipedeBody:SegmentHasControl(segment)
    return self.head_in_control == segment
end

function CentipedeBody:GiveControlToRandomHead()
    if #self.heads > 0 then
        self:GiveControlToHead(self.heads[math.random(#self.heads)])
    end
end

function CentipedeBody:GiveControlToOtherHead()
    if #self.heads > 0 then
        for i, head in ipairs(self.heads) do
            if head ~= self.head_in_control then
                self:GiveControlToHead(head)
                break
            end
        end
    end
end

function CentipedeBody:GiveControlToHead(head)
    if self.head_in_control ~= head then
        for i = 1, #self.heads do
            self.heads[i].components.locomotor:Stop()
        end

        self.head_in_control = head

        for i = 1, #self.bodies do
            if not self.bodies[i]:HasTag("centipede_head") then --Don't do this for the heads!
                self.bodies[i].rot = ReduceAngle(self.bodies[i].rot - 180)
            end
        end

        local is_head_flipped = head:IsFlipped()
        self:ForEachSegment(function(body)
            body.components.locomotor:Stop()
            if is_head_flipped and head ~= body then
                body:SetBackwardsLocomotion(true)
            else
                body:SetBackwardsLocomotion(body:IsFlipped() and head ~= body)
            end
        end)
    end
end

function CentipedeBody:ForEachSegment(fn, ...)
    for k, body in pairs(self.bodies) do
        fn(body, ...)
    end
end

function CentipedeBody:ForEachSegmentControlled(fn, ...)
    for k, body in pairs(self.bodies) do
        if self.head_in_control ~= body then
            fn(body, ...)
        end
    end
end

function CentipedeBody:SetPivotsForBody(body, rot)
    local diameter = body.Physics:GetRadius() * 2.0 --TODO, or SQRT2?
    body.Physics:SetP2PConstrainPivots(math.cos(rot) * diameter, 0, -math.sin(rot) * diameter, 0, 0, 0)
end

function CentipedeBody:GetTurnSpeed()
    --Scale turnspeed with locomotor speed?
    return self.turnspeed
end

function CentipedeBody:OnUpdate(dt, force_pivot_update)
    if not self.head_in_control
        or (not self.head_in_control.sg:HasStateTag("moving") and not force_pivot_update) then
        return
    end

    local head_is_flipped = self.head_in_control:IsFlipped()
    local target_rot_offset = head_is_flipped and 180 or 0

    for i = 1, #self.bodies do
        local body = self.bodies[i]
        local nextbody = self.bodies[i+1]
        local lastbody = self.bodies[i-1]
        local target_rot = body.Transform:GetRotation()

        if self:IsNonControllingHead(body) then
            local body_to_use = body:IsFlipped() and lastbody or nextbody
            body.Transform:SetRotation(body:GetAngleToPoint(body_to_use:GetPosition()) - 180)
        elseif lastbody and body ~= self.head_in_control then
            body.Transform:SetRotation(body:GetAngleToPoint(lastbody:GetPosition()))

            if nextbody and head_is_flipped then
                target_rot = body:GetAngleToPoint(nextbody:GetPosition())
            end
        end

        local rot1 = body.rot
        local rot2 = target_rot
        local diff = ReduceAngle(rot2 - rot1)
        body.rot = (force_pivot_update and rot2) or rot1 + diff * (self:GetTurnSpeed() * dt)
        local rot = (body.rot - target_rot_offset) * DEGREES

        local check_for_body = head_is_flipped and lastbody or nextbody
        local pivot_body_to_use = head_is_flipped and body or nextbody
        if check_for_body then
            self:SetPivotsForBody(pivot_body_to_use, rot)
        end
    end

end

function CentipedeBody:OnRemoveEntity()
    for k, body in ipairs(self.bodies) do
        if body:IsValid() then
            body.Physics:P2PConstrainTo(nil)
            body:Remove()
        end
    end
end

CentipedeBody.OnRemoveFromEntity = CentipedeBody.OnRemoveEntity

function CentipedeBody:OnSave()
    if next(self.bodies) == nil then
        return
    end

    local data = {bodies={}}

    for i, body in ipairs(self.bodies) do
        table.insert(data.bodies, body.GUID)
    end

    return data, data.bodies
end

function CentipedeBody:OnLoad()

end

function CentipedeBody:LoadPostPass(newents, savedata)
    if savedata.bodies then
        for k, bodyguid in ipairs(savedata.bodies) do
            local body = newents[bodyguid].entity
            if body ~= nil then
                self:SetSegment(body)
            end
        end
    end

    self:GiveControlToRandomHead() --TODO
end

return CentipedeBody