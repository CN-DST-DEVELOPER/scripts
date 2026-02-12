local JoustSource = Class(function(self, inst)
    self.inst = inst

    self.speed = TUNING.WILSON_RUN_SPEED
    --self.length = nil
    self.collide_tags = { "_combat" }
    self.no_collide_tags = { "FX", "NOCLICK", "DECOR", "INLIMBO" }
    if not TheNet:GetPVPEnabled() then
        table.insert(self.no_collide_tags, "player")
    end
end)

--Registered actions in componentactions.lua

function JoustSource:SetSpeed(speed)
    self.speed = speed
end

function JoustSource:GetSpeed()
    return self.speed
end

function JoustSource:SetRunAnimLoopCount(loops)
    self.loops = loops
end

function JoustSource:GetRunAnimLoopCount()
    return self.loops
end

function JoustSource:SetLanceLength(length)
    self.length = length
end

function JoustSource:GetLanceLength()
    return self.length
end

function JoustSource:SetOnHitOtherFn(fn)
    self.onhitotherfn = fn
end

local LANCE_PADDING = 0.6
local JOUSTING_TAGS = { "jousting" }

local function should_collide(guy, inst)
    return DiffAngle(inst.Transform:GetRotation(), guy.Transform:GetRotation()) > 44
end

function JoustSource:CheckCollision(inst, targets)
    local x, y, z = inst.Transform:GetWorldPosition()

    --lance start and end points (NOTE: 2d vector using x,y,0)
    local p1 = Vector3(0, 0, 0) --base of lance
    local p2 = Vector3(self:GetLanceLength() - LANCE_PADDING, 0, 0) --tip of lance

    --rotate to match our facing
    local theta = -inst.Transform:GetRotation() * DEGREES
    local cos_theta = math.cos(theta)
    local sin_theta = math.sin(theta)
    local tempx = p1.x
    p1.x = x + tempx * cos_theta - p1.y * sin_theta
    p1.y = z + p1.y * cos_theta + tempx * sin_theta
    tempx = p2.x
    p2.x = x + tempx * cos_theta - p2.y * sin_theta
    p2.y = z + p2.y * cos_theta + tempx * sin_theta

    local cx = (p1.x + p2.x) * 0.5
    local cz = (p1.y + p2.y) * 0.5
    local radius = math.sqrt(distsq(p1.x, p1.y, cx, cz))
    local lsq = Dist2dSq(p1, p2)
    local t = GetTime()

    local function should_hit(guy, inst)
        local last_t = targets[guy]
        if last_t == nil or last_t + 0.75 < t then
            local p3 = guy:GetPosition()
            p3.y, p3.z = p3.z, 0 --convert x,0,z -> x,y,0
            local range = LANCE_PADDING + guy:GetPhysicsRadius(0)
            --if DistPointToSegmentXYSq(p3, p1, p2) < range * range then
            --V2C: modified becasue we don't want to hit anything behind the back point
            local dot = (p3.x - p1.x) * (p2.x - p1.x) + (p3.y - p1.y) * (p2.y - p1.y)
            if dot >= 0 then
                dot = dot / lsq
                local dsq =
                    dot >= 1 and
                    Dist2dSq(p3, p2) or
                    Dist2dSq(p3, Vector3(p1.x + dot * (p2.x - p1.x), p1.y + dot * (p2.y - p1.y), 0))
                if dsq < range * range then
                    targets[guy] = t
                    return true
                end
            end
        end
        return false
    end

    local collided = false
    local combat = inst.components.combat
    if combat then
        combat.ignorehitrange = true
    end
    for _, guy in ipairs(TheSim:FindEntities(x, 0, z, radius + LANCE_PADDING + 3, nil, self.no_collide_tags, self.collide_tags)) do
        if guy:IsValid()
            and (guy.components.health == nil or not guy.components.health:IsDead())
            and (combat == nil or combat:CanTarget(guy))
            and (inst.TargetForceAttackOnly == nil or not inst:TargetForceAttackOnly(guy))
        then
            if should_hit(guy, inst) then
                if guy:HasTag("jousting") and should_collide(guy, inst) then
                    guy:PushEventImmediate("joust_collide")
                    collided = true
                elseif combat == nil or not combat:IsAlly(guy) then
                    if self.onhitotherfn ~= nil then
                        self.onhitotherfn(self.inst, inst, guy)
                    end
                    if combat then
                        combat:DoAttack(guy)
                    end
                    guy:PushEvent("knockback", { knocker = inst, radius = 6.5, forcelanded = true })
                end
            end
        end
    end
    if combat then
        combat.ignorehitrange = false
    end

    return collided
end

return JoustSource
