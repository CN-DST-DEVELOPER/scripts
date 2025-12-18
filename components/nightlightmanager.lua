-- NightLightManager class definition
local NightLightManager = Class(function(self, inst)
    assert(TheWorld.ismastersim, "NightLightManager should not exist on client")
    self.inst = inst

    self.nightlights = {}
    self.inst:ListenForEvent("ms_registernightlight", self.OnRegisterNightLight_Bridge)
end)
function NightLightManager:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("ms_registernightlight", self.OnRegisterNightLight_Bridge)
    for nightlight, nightlightdata in pairs(self.nightlights) do
        self.inst:RemoveEventCallback("onremove", nightlightdata.onremove, nightlight)
    end
end

---------------------------------------------------------------------

function NightLightManager:IsNightLightDataInAnyTag(nightlightdata, tags)
    if nightlightdata.node_tags ~= nil then
        for _, tag in ipairs(tags) do
            if nightlightdata.node_tags[tag] ~= nil then
                return true
            end
        end
    end

    return false
end

NightLightManager.Filter_OnlyInTags = function(nightlightmanager, nightlight, nightlightdata, intags)
    return nightlightmanager:IsNightLightDataInAnyTag(nightlightdata, intags)
end

NightLightManager.Filter_OnlyOutTags = function(nightlightmanager, nightlight, nightlightdata, outtags)
    return not nightlightmanager:IsNightLightDataInAnyTag(nightlightdata, outtags)
end

NightLightManager.Filter_InTagsAndOutTags = function(nightlightmanager, nightlight, nightlightdata, intags, outtags)
    return nightlightmanager:IsNightLightDataInAnyTag(nightlightdata, intags) and not nightlightmanager:IsNightLightDataInAnyTag(nightlightdata, outtags)
end

function NightLightManager:GetNightLightsWithFilter(filterfn, ...)
    local returns = {}
    for nightlight, nightlightdata in pairs(self.nightlights) do
        if filterfn(self, nightlight, nightlightdata, ...) then
            table.insert(returns, nightlight)
        end
    end
    return returns
end

function NightLightManager:FindClosestNightLightFromListToInst(nightlights, inst)
    local closestnightlight = nil
    local smallestsqdist = nil
    for _, nightlight in ipairs(nightlights) do
        local dsq = nightlight:GetDistanceSqToInst(inst)
        if smallestsqdist == nil or dsq < smallestsqdist then
            smallestsqdist = dsq
            closestnightlight = nightlight
        end
    end

    return closestnightlight
end

---------------------------------------------------------------------

function NightLightManager:UpdateNightLightPosition(nightlight)
    local nightlightdata = self.nightlights[nightlight]
    if nightlightdata == nil then
        return
    end

    local x, y, z = nightlight.Transform:GetWorldPosition()
    nightlightdata.x, nightlightdata.y, nightlightdata.z = x, y, z

    local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(x, y, z)
    if node_index == nightlightdata.node_index then
        return
    end
    nightlightdata.node_index = node_index

    if node and node.tags then
        nightlightdata.node_tags = table.invert(node.tags)
    else
        nightlightdata.node_tags = nil
    end
end

NightLightManager.OnRegisterNightLight_Bridge = function(inst, nightlight)
    local self = inst.components.nightlightmanager
    self:OnRegisterNightLight(nightlight)
end
function NightLightManager:OnRegisterNightLight(nightlight)
    local haseventlisteners = true
    local function onbuilt()
        if haseventlisteners then
            haseventlisteners = nil
            self.inst:RemoveEventCallback("onbuilt", onbuilt, nightlight)
            self.inst:RemoveEventCallback("entitywake", onbuilt, nightlight)
            self.inst:RemoveEventCallback("entitysleep", onbuilt, nightlight)
        end

        if nightlight:GetCurrentPlatform() == nil then
            local function onremove()
                self.nightlights[nightlight] = nil
            end
            self.nightlights[nightlight] = {
                onremove = onremove,
            }
            self.inst:ListenForEvent("onremove", onremove, nightlight)
            self:UpdateNightLightPosition(nightlight)
        end
    end
    self.inst:ListenForEvent("onbuilt", onbuilt, nightlight)
    self.inst:ListenForEvent("entitywake", onbuilt, nightlight)
    self.inst:ListenForEvent("entitysleep", onbuilt, nightlight)
end

return NightLightManager
