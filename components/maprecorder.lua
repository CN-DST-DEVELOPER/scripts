local MapRecorder = Class(function(self, inst)
    self.inst = inst

    self.mapdata = nil
    self.mapsession = nil
    self.maplocation = TheWorld.worldprefab
    self.mapauthor = nil
    self.mapday = nil
    self.onteachfn = nil
    self.ondatachangedfn = nil
end)

local function GetMapExplorer(target)
    --Only supports players
    return target ~= nil and target.player_classified ~= nil and target.player_classified.MapExplorer or nil
end

function MapRecorder:SetOnTeachFn(fn)
    self.onteachfn = fn
end

function MapRecorder:SetOnDataChangedFn(fn)
    self.ondatachangedfn = fn
end

function MapRecorder:HasData()
    return self.mapdata ~= nil and self.mapdata:len() > 0
end

function MapRecorder:IsCurrentWorld()
    return self.mapsession == TheWorld.meta.session_identifier
end

function MapRecorder:ClearMap()
    self.mapdata = nil
    self.mapsession = nil
    self.mapauthor = nil
    self.mapday = nil

    if self.ondatachangedfn ~= nil then
        self.ondatachangedfn(self.inst)
    end
end

function MapRecorder:RecordMap(target)
    local MapExplorer = GetMapExplorer(target)
    if MapExplorer == nil then
        return false, "NOEXPLORER"
    end

    self.mapdata = MapExplorer:RecordMap()
    self.mapsession = TheWorld.meta.session_identifier
    self.maplocation = TheWorld.worldprefab
    self.mapauthor = target.name
    self.mapday = TheWorld.state.cycles + 1
    if self:HasData() then
        if self.ondatachangedfn ~= nil then
            self.ondatachangedfn(self.inst)
        end
        return true
    end

    --Something went wrong, invalid data, so just clear it
    self:ClearMap()
    return false, "BLANK"
end

function MapRecorder:TeachMap(target)
    if not self:HasData() then
        self.inst:Remove()
        return false, "BLANK"
    elseif not self:IsCurrentWorld() then
        return false, "WRONGWORLD"
    end

    local MapExplorer = GetMapExplorer(target)
    if MapExplorer == nil then
        return false, "NOEXPLORER"
    end

    if not MapExplorer:LearnRecordedMap(self.mapdata) then
        return false
    end

    if self.onteachfn ~= nil then
        self.onteachfn(self.inst, target)
    end
    self.inst:Remove()
    return true
end

function MapRecorder:IsTileSeeableInRecordedMap(target, tx, ty)
    if not self:HasData() then
        return false
    end

    local MapExplorer = GetMapExplorer(target)
    if MapExplorer == nil then
        return false
    end

    -- NOTES(JBK): This function is expensive and if multiple points are needed to be checked refactor into a table of points.
    return MapExplorer:IsTileSeeableInRecordedMap(self.mapdata, tx, ty)
end

function MapRecorder:TransferComponent(newinst)
    local maprecorder = newinst.components.maprecorder
    maprecorder.mapdata = self.mapdata
    maprecorder.mapsession = self.mapsession
    maprecorder.maplocation = self.maplocation
    maprecorder.mapauthor = self.mapauthor
    maprecorder.mapday = self.mapday
    if maprecorder:HasData() then
        if maprecorder.ondatachangedfn ~= nil then
            maprecorder.ondatachangedfn(newinst)
        end
    end
end

function MapRecorder:OnSave()
    return {
        mapdata = self.mapdata,
        mapsession = self.mapsession,
        maplocation = self.maplocation,
        mapauthor = self.mapauthor,
        mapday = self.mapday,
    }
end

function MapRecorder:OnLoad(data)
    if data ~= nil then
        local dirty = false
        if data.mapdata ~= nil and data.mapsession ~= nil then
            self.mapdata = data.mapdata
            self.mapsession = data.mapsession
            self.maplocation = data.maplocation
            self.mapauthor = data.mapauthor
            self.mapday = data.mapday
            dirty = true
        elseif data.maplocation ~= nil and data.maplocation ~= self.maplocation then
            self.maplocation = data.maplocation
            dirty = true
        end
        if dirty and self.ondatachangedfn ~= nil then
            self.ondatachangedfn(self.inst)
        end
    end
end

return MapRecorder
