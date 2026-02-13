--local easing = require("easing")

local CORPSE_MUST_TAGS = { "creaturecorpse" }
local CORPSE_NO_TAGS = { "NOCLICK" }

local function IsValidToEnterNode(inst)
    return not inst._killed and inst:IsValid()
end

local function IsValidCorpse(corpse)
    return not Buzzard_ShouldIgnoreCorpse(corpse)
        and not corpse:WillMutate()
        and not corpse:HasGestaltArriving()
end

local function GetCorpseRadius(corpse)
    local r, sz, ht = GetCombatFxSize(corpse)
    return math.max(r, corpse:GetPhysicsRadius(0))
end

local function OnRemove(inst)
    local mutatedbuzzardcircler = inst.components.mutatedbuzzardcircler
    if mutatedbuzzardcircler then
        mutatedbuzzardcircler:SetCircleTarget(nil)
    end
end

local function CreateFlareDetonatedListener(hit_num)
    return function(inst, data)
        data.hit_num_buzzards = data.hit_num_buzzards or 0
        if data.sourcept and inst:GetDistanceSqToPoint(data.sourcept) <= TUNING.BUZZARDSPAWNER_FLARE_HIT_DIST_SQ and data.hit_num_buzzards < hit_num then
            local sx, sy, sz = data.sourcept:Get()
            local x, y, z = inst.Transform:GetWorldPosition()
            y = 30 + math.random() * 15 - 7.5

            x = (sx + x) / 2
            z = (sz + z) / 2

            inst:DoTaskInTime(.2 + math.random() * .8, function()
                local buzzard = inst.buzzard
                if buzzard then
                    TheWorld.components.migrationmanager:RemoveEntityFromPopulationGroup(buzzard)
                    buzzard.Transform:SetPosition(x, y, z)
                    buzzard.sg:GoToState("fall")
                    buzzard.shouldGoAway = nil

                    inst:KillShadow()
                end
            end)

            data.hit_num_buzzards = data.hit_num_buzzards + 1
        end
    end
end

local OnMiniFlareDetonated = CreateFlareDetonatedListener(1)
local OnMegaFlareDetonated = CreateFlareDetonatedListener(5)

local MutatedBuzzardCircler = Class(function(self, inst)
    self.inst = inst

    -- Cache
    self._migrationmanager = TheWorld.components.migrationmanager
    self._mutatedbuzzardmanager = TheWorld.components.mutatedbuzzardmanager

    self.scale = 1
    self.speed = math.random(3)
    self.circle_target = nil

    self.min_speed = 5
    self.max_speed = 7

    self.min_dist = 8
    self.max_dist = 12

    self.min_scale = 8
    self.max_scale = 12

    self.sine_mod = (10 + math.random() * 20) * .001
    self.sine = 0

    self.update_target_pos_cooldown = 0
    self.last_valid_migration_node = nil

    self.miniflare_detonated_cb = function(src, data) OnMiniFlareDetonated(inst, data) end
    self.megaflare_detonated_cb = function(src, data) OnMegaFlareDetonated(inst, data) end
    inst:ListenForEvent("onremove", OnRemove)
    inst:ListenForEvent("miniflare_detonated", self.miniflare_detonated_cb, TheWorld)
    inst:ListenForEvent("megaflare_detonated", self.megaflare_detonated_cb, TheWorld)
end)

function MutatedBuzzardCircler:Start()
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:SetCircleTarget(nil)
        return
    end

    self.speed = math.random(self.min_speed, self.max_speed) * .01
    self.distance = math.random(self.min_dist, self.max_dist)
    self.angleRad = math.random() * TWOPI
    self.offset = Vector3(self.distance * math.cos(self.angleRad), 0, -self.distance * math.sin(self.angleRad))

    self.direction = (math.random() < .5 and .5 or -.5) * PI

    local x, y, z = self.circle_target.Transform:GetWorldPosition()
    self.inst.Transform:SetRotation(self.inst:GetAngleToPoint(self.circle_target:GetPosition()))
    self.inst.Transform:SetPosition(x + self.offset.x, 0, z + self.offset.z)
    self:UpdateMigrationNode()

    self.inst:StartUpdatingComponent(self)
end

function MutatedBuzzardCircler:Stop()
    self.inst:StopUpdatingComponent(self)
end

function MutatedBuzzardCircler:SetCircleTarget(tar)
    if self.circle_target then
        self.circle_target._num_circling_buzzards = self.circle_target._num_circling_buzzards - 1

		self.inst:RemoveEventCallback("onremove", self._ontargetremoved, self.circle_target)
		self.inst:RemoveEventCallback("death", self._ontargetremoved, self.circle_target)
		self._ontargetremoved = nil
	end

    self.circle_target = tar

    if self.circle_target then
        self.circle_target._num_circling_buzzards = (self.circle_target._num_circling_buzzards or 0) + 1

        self._ontargetremoved = function()
            if IsValidToEnterNode(self.inst) then
                self.inst:KillShadow()
            end
			self.circle_target = nil
		end
        self.inst:ListenForEvent("onremove", self._ontargetremoved, self.circle_target)
        self.inst:ListenForEvent("death", self._ontargetremoved, self.circle_target)
    end
end

function MutatedBuzzardCircler:GetSpeed()
    local speed = self.speed
    return (self.direction > 0 and -speed) or speed
end

function MutatedBuzzardCircler:GetMinSpeed()
    return self.min_speed
end

function MutatedBuzzardCircler:GetMaxSpeed()
    return self.max_speed
end

function MutatedBuzzardCircler:GetMinScale()
    return self.min_scale * .1
end

function MutatedBuzzardCircler:GetMaxScale()
    return self.max_scale * .1
end

function MutatedBuzzardCircler:GetDebugString()
    return string.format("Sine: %4.4f, Speed: %3.3f/%3.3f", self.sine, self.speed, self:GetMaxSpeed())
end

function MutatedBuzzardCircler:UpdateMigrationNode()
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:SetCircleTarget(nil)
        return
    end

    local migration_node = self._migrationmanager:GetMigrationNodeAtInst(self.circle_target)
    local dist_last_node_to_target = self._migrationmanager:GetDistanceNodeToNode(self.last_valid_migration_node, migration_node)
    if migration_node ~= nil and (self.last_valid_migration_node == nil or (dist_last_node_to_target and dist_last_node_to_target <= 1) ) then
        self.last_valid_migration_node = migration_node
    else
        self:StoreInMigrationNode() -- Migration node is invalid, either because it doesn't exist, or it's too far away. Return.
    end
end

function MutatedBuzzardCircler:FindCorpse(target)
    if not TheWorld.components.corpsepersistmanager:AnyCorpseExists() then
        return
    end

    local x, y, z = target.Transform:GetWorldPosition()
    local corpses = TheSim:FindEntities(x, y, z, 25, CORPSE_MUST_TAGS, CORPSE_NO_TAGS)

    for i, v in ipairs(corpses) do
        while v ~= nil and not IsValidCorpse(v) do
            table.remove(corpses, i)
            v = corpses[i]
        end
    end

    return #corpses > 0 and corpses[math.random(#corpses)] or nil
end

function MutatedBuzzardCircler:LandOnCorpse(corpse)
    local pos = corpse:GetPosition()
    local rad = GetCorpseRadius(corpse) + 1.5
    local offset = FindWalkableOffset(pos, math.random() * TWOPI, rad + math.random() * 2, 12, true) or Vector3(0, 0, 0)

    if offset ~= nil then
        local sx, sz = pos.x + offset.x, pos.z + offset.z
        if not TheWorld.Map:IsOceanAtPoint(sx, 0, sz) then
            local buzzard = self.inst.buzzard
            if buzzard then
                self._migrationmanager:RemoveEntityFromPopulationGroup(buzzard)
                buzzard.Transform:SetPosition(sx, 30, sz)
                buzzard:ForceFacePoint(pos.x, pos.y, pos.z)
                buzzard.sg:GoToState("glide")
                buzzard.shouldGoAway = nil

                buzzard:DoTaskInTime(0, buzzard.SetOwnCorpse, corpse) -- One tick delay for brain to initialize

                self.inst.SoundEmitter:PlaySound("lunarhail_event/creatures/lunar_buzzard/flock_squawk")
                self.inst:KillShadow()
                self:Stop()
                return true
            end
        end
    end

    return false
end

function MutatedBuzzardCircler:DropBuzzard()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    y = 30 + math.random() * 15 - 7.5

    if self.circle_target and self.circle_target:IsValid() then
        local sx, sy, sz = self.circle_target.Transform:GetWorldPosition()

        x = (sx + x) / 2
        z = (sz + z) / 2
    end

    local buzzard = self.inst.buzzard
    local corpse = SpawnPrefab("buzzardcorpse")
    corpse.Transform:SetPosition(x, y, z)
    corpse.sg:GoToState("corpse_fall")
    corpse:StartFadeTimer(10 + math.random() * 5)

    -- Bye bye!
    if buzzard then
        corpse.AnimState:SetBuild(buzzard.AnimState:GetBuild())
        TheWorld.components.migrationmanager:RemoveEntityFromPopulationGroup(buzzard)
        buzzard:Remove()
    end

    self.inst:KillShadow()
    self:Stop()
end

local MIN_DIST_SQ = 10 * 10
local MAX_DIST_SQ = 30 * 30
function MutatedBuzzardCircler:OnUpdate(dt)
    if self.circle_target == nil or not self.circle_target:IsValid() then
        self:Stop()
        self:SetCircleTarget(nil)
        return
    elseif self.update_target_pos_cooldown <= 0 then
        self.update_target_pos_cooldown = 0.5 + math.random() * 2
        self:UpdateMigrationNode()

        if not self.inst:IsValid() then -- Might become invalid from UpdateMigrationNode
            return
        end

        if self._mutatedbuzzardmanager and self._mutatedbuzzardmanager:GetDropBuzzards() then
            return
        end

        local corpse = self:FindCorpse(self.circle_target)
        if corpse ~= nil and self:LandOnCorpse(corpse) then
            return
        end
    end

    if self.target_pos then
		local x, _, z = self.circle_target.Transform:GetWorldPosition()
		local k = math.min(1, dt / 2)
		self.target_pos.x = x * k + self.target_pos.x * (1 - k)
		self.target_pos.z = z * k + self.target_pos.z * (1 - k)
	else
		self.target_pos = self.circle_target:GetPosition()
	end

    local reverse = self.direction > 0

    self.sine = GetSineVal(self.sine_mod, true, self.inst)

    self.speed = Lerp(self:GetMinSpeed() - .003, self:GetMaxSpeed() + .003, self.sine)
    self.speed = math.clamp(self.speed, self:GetMinSpeed(), self:GetMaxSpeed())

    self.scale = Lerp(self:GetMaxScale(), self:GetMinScale(), (self.speed - self:GetMinSpeed())/(self:GetMaxSpeed() - self:GetMinSpeed()))
    self.inst.Transform:SetScale(self.scale, self.scale, self.scale)

    local angle = reverse and -180 or 0
    local distsq = self.inst:GetDistanceSqToInst(self.circle_target)
    local accelerator_perc = math.clamp((distsq - MIN_DIST_SQ) / MAX_DIST_SQ, 0, 1)

    angle = reverse and angle - Lerp(0, 35, accelerator_perc)
        or angle + Lerp(0, 35, accelerator_perc)

    local pt = self.target_pos
    local rot1 = self.inst.Transform:GetRotation() + angle
    local rot2 = self.inst:GetAngleToPoint(pt)
    local diff = ReduceAngle(rot2 - rot1)
    rot2 = rot1 + diff * Lerp(.02, .1, self.sine)
    self.inst.Transform:SetRotation(rot2 - angle)

    local extra_speed = Lerp(0, 10, accelerator_perc)

    local vel_x = reverse
        and -Lerp(.5, 1, self.sine) - extra_speed * 0.5
        or Lerp(.5, 1, self.sine) + extra_speed * 0.5
    self.inst.Physics:SetMotorVelOverride(vel_x, 0, -self.speed - extra_speed)

    self.update_target_pos_cooldown = self.update_target_pos_cooldown - dt
end

function MutatedBuzzardCircler:StoreInMigrationNode()
    if IsValidToEnterNode(self.inst) then
        self.inst:KillShadow()
    end
end

function MutatedBuzzardCircler:OnEntitySleep()
    if self.circle_target and self.circle_target:IsValid() then
        local migration_node = self._migrationmanager:GetMigrationNodeAtInst(self.circle_target)
        local dist_last_node_to_target = self._migrationmanager:GetDistanceNodeToNode(self.last_valid_migration_node, migration_node)
        if migration_node ~= nil and (self.last_valid_migration_node == nil or (dist_last_node_to_target and dist_last_node_to_target <= 1) ) then
            self.last_valid_migration_node = migration_node
        end
        self:StoreInMigrationNode()
    elseif self.last_valid_migration_node ~= nil then
        self:StoreInMigrationNode()
    end
end

return MutatedBuzzardCircler
