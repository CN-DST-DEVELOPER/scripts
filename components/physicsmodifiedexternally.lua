-- NOTES(JBK): Only call SetMotorVelExternal in here for server and the client can predict it on the player.
-- No where else should this be called let the component manage the list of external vectors.
local PhysicsModifiedExternally = Class(function(self, inst)
    self.inst = inst
    self.sources = {}
    self.totalvelocityx = 0
    self.totalvelocityz = 0

    self._onremovesource = function(src)
        self.sources[src] = nil
        if next(self.sources) == nil then
            inst:RemoveComponent("physicsmodifiedexternally")
        end
    end

    -- NOTES(JBK): Using a component check in a callback to this event will not work;
    -- EntityScript does not add the component until after this initialization happens.
    -- Assume the entity has the component when this event fires.
    inst:PushEvent("gainphysicsmodifiedexternally")
end)

function PhysicsModifiedExternally:OnRemoveFromEntity()
    self.inst.Physics:SetMotorVelExternal(0, 0, 0)
    if self.inst.components.locomotor then
        self.inst.components.locomotor.externalvelocityvectorx = 0
        self.inst.components.locomotor.externalvelocityvectorz = 0
    end

    for src in pairs(self.sources) do
        if src ~= self.inst then
            self.inst:RemoveEventCallback("onremove", self._onremovesource, src)
        end
    end

    self.inst:PushEvent("losephysicsmodifiedexternally")
end

function PhysicsModifiedExternally:RecalculateExternalVelocity()
    local totalx, totalz = 0, 0
    for src, srcvel in pairs(self.sources) do
        totalx, totalz = totalx + srcvel.x, totalz + srcvel.z
    end
    local boatphysics = self.inst.components.boatphysics
    if boatphysics then
        local dist = math.sqrt(totalx * totalx + totalz * totalz) + 0.001
        local nx, nz = totalx / dist, totalz / dist
        local dragfactor = -0.5 * math.clamp(boatphysics:GetTotalAnchorDrag() / TUNING.BOAT.MAX_ALLOWED_VELOCITY, 0, 1)

        totalx = totalx + nx * dragfactor
        totalz = totalz + nz * dragfactor
    end
    self.totalvelocityx, self.totalvelocityz = totalx, totalz
    self.inst.Physics:SetMotorVelExternal(totalx, 0, totalz)
    if self.inst.components.locomotor then
        self.inst.components.locomotor.externalvelocityvectorx = totalx
        self.inst.components.locomotor.externalvelocityvectorz = totalz
    end
end

function PhysicsModifiedExternally:SetVelocityForSource(src, velx, velz)
    local vel = self.sources[src]
    vel.x, vel.z = velx, velz
    self:RecalculateExternalVelocity()
end

function PhysicsModifiedExternally:AddSource(src)
    if not self.sources[src] then
        self.sources[src] = {x = 0, z = 0}
        if src ~= self.inst then
            self.inst:ListenForEvent("onremove", self._onremovesource, src)
        end
    end
end

function PhysicsModifiedExternally:RemoveSource(src)
    if self.sources[src] then
        if src ~= self.inst then
            self.inst:RemoveEventCallback("onremove", self._onremovesource, src)
        end
        self._onremovesource(src)
    end
end

return PhysicsModifiedExternally
