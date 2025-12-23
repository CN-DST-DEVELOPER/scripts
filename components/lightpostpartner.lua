-- NOTE: for searching: this file is used with "lantern_post"
-- Note: This is a common component
local function RemoveChainLights(inst) -- Server callback
    local lightpostpartner = inst.components.lightpostpartner
    lightpostpartner:UnshackleAll()
    if inst.neighbour_lights then
		for light in pairs(inst.neighbour_lights) do
            -- For the chain to know where to break off of, let's set the partner to nil.
            for i, partner in ipairs(light.partners) do
                if partner:value() == inst then
                    partner:set(nil)
                    break
                end
            end
			light:Remove()
		end
        inst.neighbour_lights = nil
	end
end

local LightPostPartner = Class(function(self, inst)
    self.inst = inst
    self.ismastersim = TheWorld.ismastersim

    --
    self.shackled_entities = nil
    self.post_type = nil

    inst:AddTag("lightpostpartner")

	if self.ismastersim then
        inst:ListenForEvent("teleported", RemoveChainLights)
        inst:ListenForEvent("teleport_move", RemoveChainLights)
        inst:ListenForEvent("onremove", RemoveChainLights)
		inst:ListenForEvent("onburnt", RemoveChainLights)
    end
end)

-- OnRemoveFromEntity is not supported.
--LightPostPartner.OnRemoveFromEntity

-- Common

function LightPostPartner:GetShackleIdForPartner(partner)
    for i = 1, #self.shackled_entities do
        local ent = self.shackled_entities[i]:value()
        if ent and ent == partner then
            return i
        end
    end
end

function LightPostPartner:IsMultiShackled() -- Supports more than one shackle
    return self.shackled_entities
end

function LightPostPartner:InitializeNumShackles(num_entities)
    self.shackled_entities = {}
    for i = 1, num_entities do
        self.shackled_entities[i] = net_entity(self.inst.GUID, "shackled_entities.entity"..i, "shackledentitydirty")
    end
end

function LightPostPartner:SetType(prefab)
    self.post_type = prefab
end

function LightPostPartner:GetNextAvailableShackleID()
    if self.shackled_entities then
        for i = 1, #self.shackled_entities do
            if self.shackled_entities[i]:value() == nil then
                return i
            end
        end
    end
end

-- Server

function LightPostPartner:ShacklePartnerToID(partner, id)
	if not self.ismastersim then
		return
	end
    self.shackled_entities[id]:set(partner)
    partner.shackle_id = id
end

function LightPostPartner:ShacklePartnerToNextID(partner)
	if not self.ismastersim then
		return
	end
    local id = self:GetNextAvailableShackleID()
    if id then
        self:ShacklePartnerToID(partner, id)
    end
end

function LightPostPartner:UnshackleAll()
	if not self.ismastersim then
		return
	elseif self.shackled_entities then
        for i = 1, #self.shackled_entities do
            local ent = self.shackled_entities[i]:value()
            if ent then
                ent.shackle_id = nil
            end
            self.shackled_entities[i]:set(nil)
        end
    end
end

-- Server

function LightPostPartner:OnSave()
    if self.shackled_entities then
		local ents, refs = {}, {}
        for k, v in pairs(self.shackled_entities) do
            local ent = v:value()
            if ent then
                table.insert(ents, { id = k, GUID = ent.GUID })
                table.insert(refs, ent.GUID)
            end
        end
		if #ents > 0 then
			return { entities = ents }, refs
		end
    end
end

function LightPostPartner:LoadPostPass(ents, data)
	if data.entities and not self.inst:HasTag("burnt") then
        for i, v in ipairs(data.entities) do
            local ent = ents[v.GUID]
            if ent ~= nil then
                self:ShacklePartnerToID(ent.entity, v.id)
            end
        end
    end
end

return LightPostPartner