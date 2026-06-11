local MapRevealable = Class(function(self, inst)
    self.inst = inst

    self.refreshperiod = 1.5
    self.iconname = nil
    self.iconpriority = nil
    self.iconprefab = "globalmapicon"
    self.icon = nil
    self.task = nil
    self.revealsources = {}
	self.privatesources = {}
	self._onremovesource = function(source) self:RemoveRevealSource(source) end
	self._onremoveprivatesource = function(source) self:RemovePrivateSource(source) end

    self:Start(math.random() * self.refreshperiod)
end)

function MapRevealable:SetIcon(iconname)
    if self.iconname ~= iconname then
        self.iconname = iconname
        if self.icon ~= nil then
            self.icon.MiniMapEntity:SetIcon(iconname)
        end
    end
end

function MapRevealable:SetIconPriority(priority)
    if self.iconpriority ~= priority then
        self.iconpriority = priority
        if self.icon ~= nil then
            self.icon.MiniMapEntity:SetPriority(priority)
        end
    end
end

function MapRevealable:SetIconPrefab(prefab)
    if self.iconprefab ~= prefab then
        self.iconprefab = prefab
        if self.icon ~= nil then
            self:StopRevealing()
            self:RefreshRevealSources()
        end
    end
end

function MapRevealable:SetIconTag(tag)
    if self.icontag ~= tag then
        if self.icontag ~= nil then
            if self.icon ~= nil then
                self.icon:RemoveTag(self.icontag)
            end
            self.icontag = nil
        end
        self.icontag = tag
        if self.icontag ~= nil then
            if self.icon ~= nil then
                self.icon:AddTag(self.icontag)
            end
        end
    end
end

function MapRevealable:SetOnIconCreatedFn(fn)
    self.oniconcreatedfn = fn
end

function MapRevealable:AddRevealSource(source, restriction)
    if self.revealsources[source] == nil then
        self.revealsources[source] = { restriction = restriction }
		if EntityScript.is_instance(source) then
            self.inst:ListenForEvent("onremove", self._onremovesource, source)
        end
        self:RefreshRevealSources()
    elseif self.revealsources[source].restriction ~= restriction then
        self.revealsources[source].restriction = restriction
        self:RefreshRevealSources()
    end
end

function MapRevealable:RemoveRevealSource(source)
    if self.revealsources[source] ~= nil then
		if EntityScript.is_instance(source) then
            self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
        end
        self.revealsources[source] = nil
        self:RefreshRevealSources()
    end
end

function MapRevealable:AddPrivateSource(source)
	if self.privatesources[source] == nil then
		self.privatesources[source] = {}
		self.inst:ListenForEvent("onremove", self._onremoveprivatesource, source)
		self:RefreshRevealSources()
	end
end

function MapRevealable:RemovePrivateSource(source)
	local v = self.privatesources[source]
	if v then
		self.inst:RemoveEventCallback("onremove", self._onremoveprivatesource, source)
		if v.icon then
			v.icon:Remove()
		end
		self.privatesources[source] = nil
		self:RefreshRevealSources()
	end
end

function MapRevealable:RefreshRevealSources()
    if next(self.revealsources) == nil then
        self:StopRevealing()
		if next(self.privatesources) then
			self:StartPrivateRevealing()
		else
			self:StopPrivateRevealing()
		end
        return
    end
	self:StopPrivateRevealing()
    local restriction
    for k, v in pairs(self.revealsources) do
        if v.restriction == nil then
            self:StartRevealing()
            return
        else
            restriction = v.restriction
        end
    end
    self:StartRevealing(restriction)
end

function MapRevealable:StartRevealing(restriction)
    if self.icon == nil then
        self.icon = SpawnPrefab(self.iconprefab)
        if self.icontag ~= nil then
            self.icon:AddTag(self.icontag)
        end
        if self.iconpriority ~= nil then
            self.icon.MiniMapEntity:SetPriority(self.iconpriority)
        end
        if self.oniconcreatedfn ~= nil then -- Keep before TrackEntity but after anything else used to setup the prefab.
            self.oniconcreatedfn(self.inst, self.icon)
        end
        self.icon:TrackEntity(self.inst, restriction, self.iconname)
    else
        self.icon.MiniMapEntity:SetRestriction(restriction or "")
    end
end

function MapRevealable:StopRevealing()
    if self.icon ~= nil then
        self.icon:Remove()
        self.icon = nil
    end
end

function MapRevealable:StartPrivateRevealing()
	for k, v in pairs(self.privatesources) do
		if v.icon == nil then
			v.icon = SpawnPrefab(self.iconprefab)
			if self.icontag then
				v.icon:AddTag(self.icontag)
			end
			if self.iconpriority then
				v.icon.MiniMapEntity:SetPriority(self.iconpriority)
			end
			if self.oniconcreatedfn then -- Keep before TrackEntity but after anything else used to setup the prefab.
				self.oniconcreatedfn(self.inst, v.icon)
			end
			--use userid tag as restriction so clients don't see unsharded hosts' icons, and vice versa
			v.icon:TrackEntity(self.inst, "player_"..k.userid, self.iconname)
			if v.icon.Network then
				v.icon.Network:SetClassifiedTarget(k)
			end
		end
	end
end

function MapRevealable:StopPrivateRevealing()
	for k, v in pairs(self.privatesources) do
		if v.icon then
			v.icon:Remove()
			v.icon = nil
		end
	end
end

local MAPREVEALER_TAGS = {"maprevealer"}
function MapRevealable:Refresh()
    if self.task ~= nil then
		local newps, ispublic
		local x, y, z = self.inst.Transform:GetWorldPosition()
		for _, v in ipairs(TheSim:FindEntities(x, y, z, PLAYER_REVEAL_RADIUS, MAPREVEALER_TAGS)) do
			if v ~= self.inst then
				--NOTE: nil checking maprevealer is WRONG and hides bugs (ie. maprevealer should be gauranteed.)
				--      but added the check due to mods incorrectly using "maprevealer" tag.
				local privateowner = v.components.maprevealer and v.components.maprevealer:GetPrivateOwner()
				if privateowner then
					if privateowner.isplayer and privateowner ~= self.inst and privateowner ~= v and privateowner:IsValid() then
						newps = newps or {}
						newps[privateowner] = true
					end
				else
					ispublic = true
					for k in pairs(self.privatesources) do
						self:RemovePrivateSource(k)
					end
					self:AddRevealSource("maprevealer")
					break
				end
			end
		end
		if not ispublic then
            self:RemoveRevealSource("maprevealer")
			if newps then
				for k in pairs(self.privatesources) do
					if newps[k] then
						newps[k] = nil
					else
						self:RemovePrivateSource(k)
					end
				end
				for k in pairs(newps) do
					self:AddPrivateSource(k)
				end
			else
				for k in pairs(self.privatesources) do
					self:RemovePrivateSource(k)
				end
            end
        end
    end
    if self.onrefreshfn ~= nil then
        self.onrefreshfn(self.inst)
    end
end

function MapRevealable:SetOnRefreshFn(onrefreshfn)
    self.onrefreshfn = onrefreshfn
end

local function Refresh(inst, self)
    self:Refresh()
end

function MapRevealable:Start(delay)
    if self.task == nil then
		self.task = self.inst:DoPeriodicTask(self.refreshperiod, Refresh, delay or 0, self)
    end
end

function MapRevealable:Stop()
	for k in pairs(self.privatesources) do
		self:RemovePrivateSource(k)
	end
    self:RemoveRevealSource("maprevealer")
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function MapRevealable:OnRemoveFromEntity()
    self:Stop()
	for k in pairs(self.revealsources) do
		self:RemoveRevealSource(k)
	end
end

MapRevealable.OnRemoveEntity = MapRevealable.OnRemoveFromEntity

return MapRevealable
