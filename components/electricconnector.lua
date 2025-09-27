local ElectricConnector = Class(function(self, inst)
    self.inst = inst

    self.fields = {}
    self.field_prefab = "fence_electric_field"
    self.max_links = TUNING.ELECTRIC_FENCE_MAX_LINKS
    self.link_range = TUNING.ELECTRIC_FENCE_MAX_DIST
    --
    self.onlinkedfn = nil
    self.onunlinkedfn = nil

    inst:AddTag("electric_connector")
end)

function ElectricConnector:StartLinking()
    self.inst:PushEvent("start_linking")
    return true
end

function ElectricConnector:EndLinking()
    self.inst:PushEvent("end_linking")
    return true
end

function ElectricConnector:IsLinking()
    return self.inst.sg:HasStateTag("linking")
end

function ElectricConnector:HasConnection()
    return next(self.fields) ~= nil
end

function ElectricConnector:CanLinkTo(guy, on_load)
    return guy.components.electricconnector and (on_load or guy.components.electricconnector:IsLinking()) --Other guy is linking (or we're loading), valid
        and not self.inst:GetCurrentPlatform() and not guy:GetCurrentPlatform() --FIXME (Omar): No boats. Sorry!
        and not self.fields[guy] --Make sure we're not already linked to this guy
end

function ElectricConnector:Disconnect()
    self.inst:PushEvent("disconnect_links")

    for other, fx in pairs(self.fields) do
		fx:Remove()
		self:UnregisterField(other)
		other.components.electricconnector:UnregisterField(self.inst)
        other:PushEvent("disconnect_links") --Have it play the animation.
	end

    return true
end

local ELECTRIC_CONNECTOR_MUST_TAGS = {"electric_connector"}
local ELECTRIC_CONNECTOR_CANT_TAGS = {"fully_electrically_linked"}
local function IsGuyConnecting(guy, inst)
    return inst.components.electricconnector:CanLinkTo(guy)
end

function ElectricConnector:FindAndLinkConnector()
    local connector = FindEntity(self.inst, self.link_range, IsGuyConnecting, ELECTRIC_CONNECTOR_MUST_TAGS, ELECTRIC_CONNECTOR_CANT_TAGS)
    return connector and self:ConnectTo(connector) or nil
end

function ElectricConnector:ConnectTo(connector)
    if GetTableSize(self.fields) >= self.max_links then
        return
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    local x1, y1, z1 = connector.Transform:GetWorldPosition()
	local dx = x1 - x
	local dz = z1 - z
	local dsq = dx * dx + dz * dz
	local fx = SpawnPrefab(self.field_prefab)
	fx.Transform:SetPosition((x + x1) / 2, 0, (z + z1) / 2)
	fx:SetBeam(math.sqrt(dsq), math.atan2(-dz, dx) * RADIANS)

    self:RegisterField(connector, fx)
    connector.components.electricconnector:RegisterField(self.inst, fx)

    connector:PushEvent("linked_to")

    return connector
end

function ElectricConnector:RegisterField(other, field)
    if self.onlinkedfn then
        self.onlinkedfn(self.inst, other, field)
    end

    self.fields[other] = field

    field.fences = {other, self.inst}

    self.inst:AddTag("is_electrically_linked")

    if GetTableSize(self.fields) >= self.max_links then
        self.inst:AddTag("fully_electrically_linked")
    end
end

function ElectricConnector:UnregisterField(other)
    self.fields[other] = nil

    self.inst:RemoveTag("fully_electrically_linked")

    if next(self.fields) == nil then
        if self.onunlinkedfn then
            self.onunlinkedfn(self.inst, other)
        end
        self.inst:RemoveTag("is_electrically_linked")
    end
end

function ElectricConnector:OnUpdate()

end

function ElectricConnector:OnSave()
    if next(self.fields) == nil then
        return
    end

    local data = {connectors={}}

    for connector in pairs(self.fields) do
        table.insert(data.connectors, connector.GUID)
    end

    return data, data.connectors
end

function ElectricConnector:LoadPostPass(newents, savedata)
    if savedata.connectors then
        for k, v in pairs(savedata.connectors) do
            local connector = newents[v]
            if connector ~= nil and self:CanLinkTo(connector.entity, true) then
                self:ConnectTo(connector.entity)
            end
        end
    end
end

function ElectricConnector:GetDebugString()
    return string.format("ElectricConnector: %s", "")
end

ElectricConnector.OnRemoveEntity = ElectricConnector.Disconnect
ElectricConnector.OnRemoveFromEntity = ElectricConnector.Disconnect

return ElectricConnector