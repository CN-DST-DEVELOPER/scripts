local SourceModifierList = require("util/sourcemodifierlist")

local STATUS = {
    ACTIVE = 0,
    INACTIVE = 1,
    FULL = 2,
}

local FX_OVERRIDES = {
    ["oceanwhirlbigportal"] = "spawn_fx_ocean_static",
}

local function onstatus(self, val)
    if not self.hiddenaction and val == STATUS.ACTIVE then
        self.inst:AddTag("migrator")
    else
        self.inst:RemoveTag("migrator")
    end
end

local nextPortalID = 1 -- Start at 1
local function init(inst, self)
    if self.id == nil then
        self:SetID(nextPortalID)
    else
        for i, v in ipairs(ShardPortals) do
            local worldmigrator = v.components.worldmigrator
            if worldmigrator and (worldmigrator.id == self.id) then
                print(string.format("MIGRATION PORTAL FAILURE: worldmigrator has two portals(%s, %s) that have the same ID(%s)!", tostring(inst), tostring(v), tostring(self.id)))
                return
            end
        end
    end
    TheWorld:PushEvent("ms_registermigrationportal", inst)
    Shard_UpdatePortalState(inst)
end

local WorldMigrator = Class(function(self, inst)
    self.inst = inst

    self.auto = true
    self.enabled = true
    self.disabledsources = SourceModifierList(inst, false, SourceModifierList.boolean)
    self._status = -1

    self.id = nil

    self.linkedWorld = nil
    self.receivedPortal = nil

    self.FX_OVERRIDES = FX_OVERRIDES

    self.inst:DoTaskInTime(0, init, self)
end,
nil,
{
    _status = onstatus,
})

function WorldMigrator:SetHideActions(hidden)
    self.hiddenaction = hidden and true or nil
    if not self.hiddenaction and self._status == STATUS.ACTIVE then
        self.inst:AddTag("migrator")
    else
        self.inst:RemoveTag("migrator")
    end
end

function WorldMigrator:SetDestinationWorld(world, permanent)
    self.auto = true
    if permanent ~= nil then
        self.auto = not permanent
    end
    self.linkedWorld = world
    self:ValidateAndPushEvents()
end

function WorldMigrator:SetDisabledWithReason(reason)
    self.disabledsources:SetModifier(self.inst, true, reason)
end

function WorldMigrator:ClearDisabledWithReason(reason)
    self.disabledsources:RemoveModifier(self.inst, reason)
end

function WorldMigrator:SetEnabled(enabled) -- NOTES(JBK): Should only be called by the owning inst for visuals.
    self.enabled = enabled
    self:ValidateAndPushEvents()
end

function WorldMigrator:SetReceivedPortal(fromworld, fromportal)
    -- TODO: This needs to be part of a two-way process, so both ends of the portal link to each other
    -- (or IDs are handed down from the master or something, so that bi-directionality can be guaranteed)
    assert(self.linkedWorld == nil or self.linkedWorld == fromworld)
    self.linkedWorld = fromworld
    self.receivedPortal = fromportal
    self:ValidateAndPushEvents()
end

function WorldMigrator:GetStatusString()
    return string.lower(tostring(table.reverselookup(STATUS, self._status)))
end

function WorldMigrator:ValidateAndPushEvents()
    local enabled = self.enabled and not self.disabledsources:Get()
    if not enabled then
        self._status = STATUS.INACTIVE
        self.inst:PushEvent("migration_unavailable")
        if InGamePlay() and not self.disabledsources:HasModifier(self.inst, "MISSINGSHARD") then
            print(string.format("Validating portal[%s] <-> %s[%s] (%s)", tostring(self.id or -1), self.linkedWorld or "<nil>", tostring(self.receivedPortal or 0), self.linkedWorld ~= nil and Shard_IsWorldAvailable(self.linkedWorld) and "disabled" or "inactive"))
        end
        return
    end

    if self._status ~= STATUS.ACTIVE and self.linkedWorld ~= nil and Shard_IsWorldAvailable(self.linkedWorld) then
        self._status = STATUS.ACTIVE
        self.inst:PushEvent("migration_available")
    elseif self._status ~= STATUS.FULL and self.linkedWorld ~= nil and Shard_IsWorldFull(self.linkedWorld) then
        self._status = STATUS.FULL
        self.inst:PushEvent("migration_full")
    elseif self._status ~= STATUS.INACTIVE and (self.linkedWorld == nil or not Shard_IsWorldAvailable(self.linkedWorld)) then
        self._status = STATUS.INACTIVE
        self.inst:PushEvent("migration_unavailable")
    end
    if InGamePlay() and not self.disabledsources:HasModifier(self.inst, "MISSINGSHARD") then
        print(string.format("Validating portal[%s] <-> %s[%s] (%s)", tostring(self.id or -1), self.linkedWorld or "<nil>", tostring(self.receivedPortal or 0), self:GetStatusString()))
    end
end

function WorldMigrator:IsBound()
    return self.id ~= nil and self.linkedWorld ~= nil and self.receivedPortal ~= nil
end

function WorldMigrator:SetID(id)
    self.id = id

    -- TEMP HACK! the received portal should be negotiated between servers
    self.receivedPortal = id

    if type(id) == "number" and (id >= nextPortalID) then
        nextPortalID = id + 1
    end
end

function WorldMigrator:IsDestinationForPortal(otherWorld, otherPortal)
    return  self.linkedWorld == otherWorld and self.receivedPortal == otherPortal
end

function WorldMigrator:IsAvailableForLinking()
    return not self:IsLinked()
end

function WorldMigrator:IsLinked()
    return self.linkedWorld ~= nil and self.receivedPortal ~= nil
end

function WorldMigrator:IsActive()
    return self.enabled and self._status == STATUS.ACTIVE
end

function WorldMigrator:IsFull()
    return self._status == STATUS.FULL
end

function WorldMigrator:CanInventoryItemMigrate(item)
    if item:HasTag("irreplaceable") then
        return false
    end

    if item.components.migrationpetowner and item.components.migrationpetowner:GetPet() then
        return false
    end

    return true
end

function WorldMigrator:TryToMakeItemMigrateable(item)
    if item.components.migrationpetowner and item.components.migrationpetowner:GetPet() then
        if item.OnStopUsing then -- beef_bell unpairing.
            item:OnStopUsing()
        end
    end
end

function WorldMigrator:DropThingsThatShouldNotMigrate(doer)
    local filterfn = function(owner, item) -- Return true to drop.
        self:TryToMakeItemMigrateable(item)
        return not self:CanInventoryItemMigrate(item)
    end
    if doer.components.inventory then
        doer.components.inventory:DropEverythingByFilter(filterfn)
    end
    if doer.components.container then
        doer.components.container:DropEverythingByFilter(filterfn)
    end
end

function WorldMigrator:Activate(doer)
    if self.linkedWorld == nil then
        return false, "NODESTINATION"
    end

    if doer:HasTag("player") then
        if not doer._despawning then
            print("Activating portal["..self.id.."] to "..(self.linkedWorld or "<nil>").." by "..tostring(doer))
            self.inst:PushEvent("migration_activate", {doer = doer})
            local fxoverride = self.FX_OVERRIDES[self.id]
            TheWorld:PushEvent("ms_playerdespawnandmigrate", { player = doer, portalid = self.id, worldid = self.linkedWorld, fxoverride = fxoverride, })
        end
        return true
    end

    if doer.components.inventoryitem then
        self:TryToMakeItemMigrateable(doer)
        if self:CanInventoryItemMigrate(doer) then
            self:DropThingsThatShouldNotMigrate(doer)
            self.inst:PushEvent("migration_activate", {doer = doer})
            local shardid, item = self.linkedWorld, doer
            local migrationdata = {
                worldid = TheShard:GetShardId(), -- The world's own id.
                portalid = self.id,
                sessionid = TheWorld.meta.session_identifier,
                --dest_x = x,
                --dest_y = y,
                --dest_z = z,
            }
            Shard_CreateTransaction_TransferInventoryItem(shardid, item, migrationdata)
            return true
        end
    end

    return false, "NODESTINATION"
end

function WorldMigrator:ActivatedByOther()
    self.inst:PushEvent("migration_activate_other")
end

function WorldMigrator:OnSave()
    return {
        id = self.id,
        linkedWorld = self.linkedWorld,
        receivedPortal = self.receivedPortal,
        auto = self.auto,
    }
end

function WorldMigrator:OnLoad(data)
    if data.id ~= nil then
        self:SetID(data.id)
    end
    self.linkedWorld = data.linkedWorld
    self.receivedPortal = data.receivedPortal or data.recievedPortal --V2C: lol backward compatible
    self.auto = true
    if data.auto ~= nil then
        self.auto = data.auto
    end
end

function WorldMigrator:GetDebugString()
    return string.format("ID: %s world: %s (%s) available: %s receives: %s status: %s enabled: %s", tostring(self.id or "n/a"), self.linkedWorld or "<nil>", self.auto and "auto" or "manual", tostring(self.linkedWorld and Shard_IsWorldAvailable(self.linkedWorld) or false), tostring(self.receivedPortal or "n/a"), self:GetStatusString(), tostring(self.enabled))
end

return WorldMigrator
