local ItemStore = Class(function(self, inst)
    self.inst = inst

    self.storeditemdatas = {}
end)

function ItemStore:GetNumberOfItems()
    return #self.storeditemdatas
end

function ItemStore:GetFirstItems(count)
    local items = {}
    for i = 1, count do
        local itemdata = self.storeditemdatas[i]
        if itemdata then
            local creator = nil
            if itemdata.migrationdata then
                creator = { sessionid = itemdata.migrationdata.sessionid }
            end
            local item = SpawnPrefab(itemdata.item_record.prefab, itemdata.item_record.skinname, itemdata.item_record.skin_id, creator)
            item:SetPersistData(itemdata.item_record.data)
            table.insert(items, item)
        end
    end
    local storeditemdatascount = #self.storeditemdatas
    for i = count + 1, storeditemdatascount do
        self.storeditemdatas[i - count] = self.storeditemdatas[i]
    end
    for i = storeditemdatascount, math.max(storeditemdatascount - count + 1, 1), -1 do
        self.storeditemdatas[i] = nil
    end
    self.inst:PushEvent("itemstore_changedcount")
    return items
end

function ItemStore:AddItem(item)
    local item_record = item:GetSaveRecord()
    item:Remove()
    table.insert(self.storeditemdatas, {
        item_record = item_record,
    })
    self.inst:PushEvent("itemstore_changedcount")
end

function ItemStore:AddItemRecordAndMigrationData(item_record, migrationdata)
    table.insert(self.storeditemdatas, {
        item_record = item_record,
        migrationdata = migrationdata,
    })
    self.inst:PushEvent("itemstore_changedcount")
end

function ItemStore:OnSave()
    if next(self.storeditemdatas) == nil then
        return
    end

    return {
        itemdatas = self.storeditemdatas,
    }
end

function ItemStore:OnLoad(data)
    if not data then
        return
    end

    self.storeditemdatas = data.itemdatas or self.storeditemdatas
    if self:GetNumberOfItems() > 0 then
        self.inst:PushEvent("itemstore_changedcount")
    end
end

return ItemStore