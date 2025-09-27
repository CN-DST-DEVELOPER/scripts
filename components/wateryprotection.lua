local WateryProtection = Class(function(self, inst)
    self.inst = inst

    self.witherprotectiontime = 0
    self.temperaturereduction = 0
    self.addcoldness = 0
    self.addwetness = 0
    self.applywetnesstoitems = false
    self.extinguish = true
    self.extinguishheatpercent = 0
	--self.protection_dist = nil

    self.ignoretags = { "FX", "DECOR", "INLIMBO", "burnt" }
end)

function WateryProtection:AddIgnoreTag(tag)
    if not table.contains(self.ignoretags, tag) then
        table.insert(self.ignoretags, tag)
    end
end

function WateryProtection:ApplyProtectionToEntity(ent, noextinguish)
    if ent.components.burnable ~= nil then
        if self.witherprotectiontime > 0 and ent.components.witherable ~= nil then
            ent.components.witherable:Protect(self.witherprotectiontime)
        end
        if not noextinguish and self.extinguish then
            if ent.components.burnable:IsBurning() or ent.components.burnable:IsSmoldering() then
                ent.components.burnable:Extinguish(true, self.extinguishheatpercent)
            end
        end
    end
    if self.addcoldness > 0 and ent.components.freezable ~= nil then
        ent.components.freezable:AddColdness(self.addcoldness)
    end
    if self.temperaturereduction > 0 and ent.components.temperature ~= nil then
        ent.components.temperature:SetTemperature(ent.components.temperature:GetCurrent() - self.temperaturereduction)
    end
    if self.addwetness > 0 then
        if ent.components.moisture ~= nil then
            local waterproofness = ent.components.moisture:GetWaterproofness()
            ent.components.moisture:DoDelta(self.addwetness * (1 - waterproofness))
        elseif self.applywetnesstoitems and ent.components.inventoryitem ~= nil then
            ent.components.inventoryitem:AddMoisture(self.addwetness)
        end
    end
end

function WateryProtection:SpreadProtectionAtPoint(x, y, z, dist, noextinguish)
    local ents = TheSim:FindEntities(x, y, z, dist or self.protection_dist or 4, nil, self.ignoretags)
    for _, ent in ipairs(ents) do
        self:ApplyProtectionToEntity(ent, noextinguish)
    end

	if self.addwetness and TheWorld.components.farming_manager ~= nil then
		TheWorld.components.farming_manager:AddSoilMoistureAtPoint(x, y, z, self.addwetness)
	end

	if self.onspreadprotectionfn ~= nil then
		self.onspreadprotectionfn(self.inst, x, y, z)
	end
end

function WateryProtection:SpreadProtection(inst, dist, noextinguish)
    local x, y, z = inst.Transform:GetWorldPosition()
    self:SpreadProtectionAtPoint(x, y, z, dist, noextinguish)
end

return WateryProtection
