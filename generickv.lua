-- NOTES(JBK): This is a wrapper for TheInventory synchronization steps please use other saving methods for mods it will not be safe here.

local GenericKV = Class(function(self)
    self.kvs = {}

    --self.save_enabled = nil
    --self.dirty = nil
    --self.synced = nil
    --self.loaded = nil
end)

function GenericKV:GetKV(key)
    return self.kvs[key]
end

function GenericKV:SetKV(key, value)
    --print("[GenericKV] SetKV", key, value)
    if self.kvs[key] == value then
        return true
    end

    assert(type(value) == "string")
    self.dirty = true
    if self.save_enabled then
        if not TheNet:IsDedicated() then
            TheInventory:SetGenericKVValue(key, value)
        end
        self.kvs[key] = value
        self:Save(true)

        return true
    end
    return false
end

function GenericKV:Save(force_save)
    --print("[GenericKV] Save")
    if force_save or (self.save_enabled and self.dirty) then
        local str = json.encode({kvs = self.kvs or self.kvs, })
        TheSim:SetPersistentString("generickv", str, false)
        self.dirty = false
    end
end

function GenericKV:Load()
    --print("[GenericKV] Load")
    self.kvs = {}
    TheSim:GetPersistentString("generickv", function(load_success, data)
        if load_success and data ~= nil then
            local status, generickv_data = pcall(function() return json.decode(data) end)
            if status and generickv_data then
                self.kvs = generickv_data.kvs
                self.loaded = true
            else
                print("Failed to load the data in generickv!", status, generickv_data)
            end
        end
    end)
end

function GenericKV:ApplyOnlineProfileData()
    --print("[GenericKV] ApplyOnlineProfileData")
    if not self.synced and
        (TheInventory:HasSupportForOfflineSkins() or not (TheFrontEnd ~= nil and TheFrontEnd:GetIsOfflineMode() or not TheNet:IsOnlineMode())) and
        TheInventory:HasDownloadedInventory() then
        local merged = false
        local storedkvs = TheInventory:GetLocalGenericKV()
        -- First merge online cache into local.
        for k, v in pairs(storedkvs) do
            local v2 = self.kvs[k]
            if v2 then
                if v2 ~= v then
                    merged = true
                    if stringidsorter(string.lower(v), string.lower(v2)) then
                        self.kvs[k] = v2
                        if not TheNet:IsDedicated() then
                            TheInventory:SetGenericKVValue(k, v2)
                        end
                    else
                        self.kvs[k] = v
                    end
                end
            else
                self.kvs[k] = v
            end
        end
        -- Then apply local to online cache.
        for k, v in pairs(self.kvs) do
            local v2 = storedkvs[k]
            if not v2 then
                -- Apply local value to online cache.
                if not TheNet:IsDedicated() then
                    TheInventory:SetGenericKVValue(k, v)
                end
            end
        end
        self.synced = true
        if not self.loaded or merged then -- We loaded a file from the player's profile but there is no save data on disk save it now or if we got new data from the online storage.
            self.loaded = true
            self:Save(true)
        end
    end
    return self.synced
end

return GenericKV
