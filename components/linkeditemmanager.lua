-- NOTES(JBK): Linked items are items that needs to maintain links between an item and a specific player.
--     Player entities and inventoryitems cannot use entitytracker for this purpose.
--     Example use case is to remember who created an item and let the linkeditem component get the current owner inst if the player exists.

local LinkedItemManager = Class(function(self, inst)
    assert(TheWorld.ismastersim, "LinkedItemManager should not exist on client")
    self.inst = inst

    self.linkeditems = {}
    self.players = {}

    for _, player in ipairs(AllPlayers) do
        self:OnPlayerJoined(player)
    end
    self.inst:ListenForEvent("ms_playerjoined", function(src, player) self:OnPlayerJoined(player) end, TheWorld)
    self.inst:ListenForEvent("ms_playerleft", function(src, player) self:OnPlayerLeft(player) end, TheWorld)
    self.inst:ListenForEvent("ms_registerlinkeditem", function(src, data) self:OnRegisterLinkedItem(data) end, TheWorld)
    self.inst:ListenForEvent("ms_unregisterlinkeditem", function(src, data) self:OnUnregisterLinkedItem(data) end, TheWorld)

    self.waitingforinitialization = {}
    self.OnSkillTreeInitialized = function(player)
        if self.waitingforinitialization[player] then
            self.waitingforinitialization[player] = nil
            self.inst:RemoveEventCallback("ms_skilltreeinitialized", self.OnSkillTreeInitialized, player)
        end
        local items = self.linkeditems[player.userid]
        if items then
            for item, _ in pairs(items) do
                item.components.linkeditem:OnSkillTreeInitialized()
            end
        end
    end
end)

function LinkedItemManager:ForEachLinkedItemForPlayer(player, callback, ...)
    local items = shallowcopy(self.linkeditems[player.userid])
    if items then
        for item, _ in pairs(items) do
            callback(item, player, ...)
        end
    end
end

function LinkedItemManager:OnPlayerJoined(player)
    if player.is_snapshot_user_session then
        return
    end

    self.players[player.userid] = player
    local items = self.linkeditems[player.userid]
    if items then
        for item, _ in pairs(items) do
            item.components.linkeditem:SetOwnerInst(player)
        end
    end

    if player._PostActivateHandshakeState_Server == POSTACTIVATEHANDSHAKE.READY then
        if items then
            for item, _ in pairs(items) do
                item.components.linkeditem:OnSkillTreeInitialized()
            end
        end
    else
        self.waitingforinitialization[player] = true
        self.inst:ListenForEvent("ms_skilltreeinitialized", self.OnSkillTreeInitialized, player)
    end
end

function LinkedItemManager:OnPlayerLeft(player)
    if player.is_snapshot_user_session then
        return
    end

    local items = self.linkeditems[player.userid]
    if items then
        for item, _ in pairs(items) do
            item.components.linkeditem:SetOwnerInst(nil)
        end
    end
    self.players[player.userid] = nil

    if self.waitingforinitialization[player] then
        self.waitingforinitialization[player] = nil
        self.inst:RemoveEventCallback("ms_skilltreeinitialized", self.OnSkillTreeInitialized, player)
    end
end

function LinkedItemManager:OnRegisterLinkedItem(data)
    if self.linkeditems[data.owner_userid] == nil then
        self.linkeditems[data.owner_userid] = {}
    end
    self.linkeditems[data.owner_userid][data.item] = true
    if data.item.components.linkeditem and data.item:IsValid() then
        local player = self.players[data.owner_userid]
        if player then
            data.item.components.linkeditem:SetOwnerInst(player)
            if not self.waitingforinitialization[player] then
                data.item.components.linkeditem:OnSkillTreeInitialized()
            end
        end
    end
end

function LinkedItemManager:OnUnregisterLinkedItem(data)
    if self.linkeditems[data.owner_userid] == nil then
        return
    end

    self.linkeditems[data.owner_userid][data.item] = nil
    if next(self.linkeditems[data.owner_userid]) == nil then
        self.linkeditems[data.owner_userid] = nil
    end
    if data.item.components.linkeditem and data.item:IsValid() then
        data.item.components.linkeditem:SetOwnerInst(nil)
    end
end

return LinkedItemManager
