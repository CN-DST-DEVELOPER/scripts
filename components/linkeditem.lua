-- See linkeditemmanager component for a description of the purpose for this component.
local LinkedItem = Class(function(self, inst)
    self.inst = inst
	self.ismastersim = TheWorld.ismastersim

    self.netowneruserid = net_string(inst.GUID, "linkeditem.netowneruserid")
    self.netownername = net_string(inst.GUID, "linkeditem.netownername")
    self.restrictequippabletoowner = net_bool(inst.GUID, "linkeditem.restrictequippabletoowner")

    if self.ismastersim then
        --self.owner_inst = nil
        self.OnRemoveCallback = function() self:LinkToOwnerUserID(nil) end
        self.inst:ListenForEvent("onremove", self.OnRemoveCallback)
    end
end)
-- OnRemoveFromEntity not supported with netvar use.
--function LinkedItem:OnRemoveFromEntity()
--    self:LinkToOwnerUserID(nil)
--    self.inst:RemoveEventCallback("onremove", self.OnRemoveCallback)
--end


--------------------------------------------------------------------------
-- Common interface

function LinkedItem:GetOwnerName()
    local netowneruserid = self.netowneruserid:value()
    if netowneruserid ~= "" then
        --Only re-check the client table once every 10 seconds
        local t = GetTime()
        if (self.lastclienttabletime or -999) + 10 < t then
            self.lastclienttabletime = t
            local client = TheNet:GetClientTableForUser(netowneruserid)
            if client and client.name then
                --set_local even on server, since clients will also be checking client table
                self.netownername:set_local(client.name)
                return client.name
            end
        end
    end
    local netownername = self.netownername:value()
    return netownername ~= "" and netownername or nil
end

function LinkedItem:GetOwnerUserID()
    local netowneruserid = self.netowneruserid:value()
    return netowneruserid ~= "" and netowneruserid or nil
end

function LinkedItem:IsEquippableRestrictedToOwner()
    return self.restrictequippabletoowner:value()
end

--------------------------------------------------------------------------
-- Server interface

function LinkedItem:GetOwnerInst()
    return self.owner_inst
end

function LinkedItem:LinkToOwnerUserID(owner_userid)
    local old_owner_userid = self:GetOwnerUserID()
    if old_owner_userid == owner_userid then
        return
    end

    if old_owner_userid ~= nil then
        TheWorld:PushEvent("ms_unregisterlinkeditem", {item = self.inst, owner_userid = old_owner_userid})
    end

    self.netowneruserid:set(owner_userid or "")

    if owner_userid then
        TheWorld:PushEvent("ms_registerlinkeditem", {item = self.inst, owner_userid = owner_userid})
    end
end

function LinkedItem:SetEquippableRestrictedToOwner(val)
    self.restrictequippabletoowner:set(val)
end

function LinkedItem:SetOnOwnerInstRemovedFn(fn)
    self.onownerinst_removedfn = fn
end

function LinkedItem:SetOnOwnerInstCreatedFn(fn)
    self.onownerinst_createdfn = fn
end

function LinkedItem:SetOnSkillTreeInitializedFn(fn)
    self.onownerinst_skilltreeinitializedfn = fn
end

function LinkedItem:SetOwnerInst(owner_inst) -- NOTES(JBK): This should be called by linkeditemmanager component only.
    if self.owner_inst == owner_inst then
        return
    end

    if self.owner_inst ~= nil then
        if self.onownerinst_removedfn ~= nil then
            self.onownerinst_removedfn(self.inst, owner_inst)
        end
    end

    self.owner_inst = owner_inst

    if owner_inst ~= nil then
        self.netownername:set(owner_inst.name or "")
        if self.onownerinst_createdfn ~= nil then
            self.onownerinst_createdfn(self.inst, owner_inst)
        end
    else
        self.netownername:set("")
    end
end

function LinkedItem:OnSkillTreeInitialized() -- NOTES(JBK): This should be called by linkeditemmanager component only.
    if self.onownerinst_skilltreeinitializedfn ~= nil then
        self.onownerinst_skilltreeinitializedfn(self.inst, self.owner_inst)
    end
end

function LinkedItem:OnSave()
    local netowneruserid = self.netowneruserid:value()
    local netownername = self.netownername:value()
    local data = {
        netowneruserid = netowneruserid ~= "" and netowneruserid or nil,
        netownername = netownername ~= "" and netownername or nil,
    }
    return next(data) and data or nil
end

function LinkedItem:OnLoad(data)
    if data == nil then
        return
    end

    local netowneruserid = data.netowneruserid or ""
    self.netowneruserid:set(netowneruserid)
    self.netownername:set(data.netownername or "")
    if netowneruserid ~= "" then
        TheWorld:PushEvent("ms_registerlinkeditem", {item = self.inst, owner_userid = netowneruserid})
    end
end

function LinkedItem:GetDebugString()
    if self.ismastersim then
        return string.format("Owner: %s <%s>, inst: %s", tostring(self:GetOwnerName()), tostring(self:GetOwnerUserID()), tostring(self:GetOwnerInst()))
    else
        return string.format("Owner: %s <%s>", tostring(self:GetOwnerName()), tostring(self:GetOwnerUserID()))
    end
end

return LinkedItem
