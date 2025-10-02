local Sheltered = Class(function(self, inst)
    self.inst = inst

    self.stoptime = GetTime()
    self.presheltered = false
    self.sheltered = false
    self.announcecooldown = 0
    self.sheltered_level = 1
    self.mounted = false
    self.waterproofness = TUNING.WATERPROOFNESS_SMALLMED

    self:Start()
end)

function Sheltered:OnRemoveFromEntity()
    self:SetSheltered(false)
end

function Sheltered:Start()
    if self.stoptime ~= nil then
        self.announcecooldown = math.max(0, self.announcecooldown + self.stoptime - GetTime())
        self.stoptime = nil
        self.inst:StartUpdatingComponent(self)
    end
end

function Sheltered:Stop()
    if self.stoptime == nil then
        self.stoptime = GetTime()
        self.inst:StopUpdatingComponent(self)
        self:SetSheltered(false)
    end
end

function Sheltered:SetSheltered(issheltered, level)
    if self.mounted and level < 2 then
        issheltered = false
    end
    self.sheltered_level = level
    if not issheltered then
        if self.presheltered then
            self.presheltered = false
            self.inst.replica.sheltered:StopSheltered()
        end
        if self.sheltered then
            self.sheltered = false
            self.inst:PushEvent("sheltered", { sheltered=false, level=self.sheltered_level })
        end
    elseif not self.presheltered then
        self.presheltered = true
        self.inst.replica.sheltered:StartSheltered()
    elseif not self.sheltered and self.inst.replica.sheltered:IsSheltered() then
        self.sheltered = true
        self.inst:PushEvent("sheltered", { sheltered=true, level=self.sheltered_level })
		if self.announcecooldown <= 0 and (TheWorld.state.israining and self.inst.components.rainimmunity == nil or GetLocalTemperature(self.inst) >= TUNING.OVERHEAT_TEMP - 5) then
            self.inst.components.talker:Say(GetString(self.inst, "ANNOUNCE_SHELTER"))
            self.announcecooldown = TUNING.TOTAL_DAY_TIME
        end
    end
end

local SHELTERED_MUST_TAGS = { "shelter" }
local SHELTERED_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "stump", "burnt" }
function Sheltered:OnUpdate(dt)
    self.announcecooldown = math.max(0, self.announcecooldown - dt)

    local sheltered = false
    local level = 1

    --NOTE: canopytrees is player specific, which is ok for now because sheltered is a player specific component too
    if self.inst.canopytrees and self.inst.canopytrees > 0 then
        sheltered = true
        level = 2
    else
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local num_sheltered = TheSim:CountEntities(x, y, z, 2, SHELTERED_MUST_TAGS, SHELTERED_CANT_TAGS)
        sheltered = num_sheltered > 0
    end

    self:SetSheltered(sheltered, level)
end

function Sheltered:GetDebugString()
    return string.format("%s, sheltered: %s, presheltered: %s", self.stoptime == nil and "STARTED" or "STOPPED", tostring(self.sheltered), tostring(self.presheltered))
end

return Sheltered