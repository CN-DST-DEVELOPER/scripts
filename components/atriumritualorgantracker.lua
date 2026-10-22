local function ForcePlanWormBossWave()
    TheWorld:PushEvent("hounded_forceplannewattack", { multtimetoattack = TUNING.WORM_BOSS_RITUAL_WAVE_TIME_MULT, choosemintime = true })
end

local function OnAtriumRitualEnabled(inst, gate)
    local state = gate:GetRitualState()
    if state >= gate.RITUAL_STATES.ENABLED then
        inst.components.atriumritualorgantracker:Enable(true)
    end
end

local function OnDefeatedShrouden(inst) -- vault being reset means shrouden was defeated, so also reset this tracker
    inst.components.atriumritualorgantracker:RefreshOrgansTable()
    if inst.components.atriumritualorgantracker.enabled then
        ForcePlanWormBossWave()
    end
end

local AtriumRitualOrganTracker = Class(function(self, inst)
    assert(TheWorld.ismastersim, "Atrium Ritual Organ Tracker should not exist on client!")

    self.inst = inst
    self.enabled = false
    self:RefreshOrgansTable()
    inst:ListenForEvent("ms_atriumgate_ritualstatechanged", OnAtriumRitualEnabled, TheWorld)
    inst:ListenForEvent("ms_defeated_shrouden", OnDefeatedShrouden, TheWorld)
end)

function AtriumRitualOrganTracker:Enable(enabled)
    if self.enabled ~= enabled then
        self.enabled = enabled
        if enabled and self:NeedsRitualOrgan("atrium_ritual_organ_worm") then
            ForcePlanWormBossWave()
        end
    end
end

function AtriumRitualOrganTracker:RefreshOrgansTable()
    self.organs = {}
end

function AtriumRitualOrganTracker:NeedsRitualOrgan(prefab)
    return self.enabled and not self.organs[prefab]
end

function AtriumRitualOrganTracker:SetRitualOrgan(prefab)
    self.organs[prefab] = true
end

function AtriumRitualOrganTracker:OnSave()
    local data = {}

    if self.enabled then
        data.enabled = self.enabled
    end

    if next(self.organs) ~= nil then
        data.organs = self.organs
    end

    return next(data) ~= nil and data or nil
end

function AtriumRitualOrganTracker:OnLoad(data)
    if data ~= nil then
        self.organs = data.organs or {}
        self.enabled = data.enabled or false
    end
end

function AtriumRitualOrganTracker:GetDebugString()
    local organnames = {}

    for name in pairs(self.organs) do
        table.insert(organnames, name)
    end

    return string.format("Organs: [ %s ]", table.concat(organnames, ", "))
end

return AtriumRitualOrganTracker
