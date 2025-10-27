--V2C: component for adding generic onupdate loops to entities
--     since we found out that DoPeriodicTask(0) doesn't trigger precisely every frame

local _PostUpdates = {}

local UpdateLooper = Class(function(self, inst)
    self.inst = inst
    self.onupdatefns = {}
    self.longupdatefns = {}
	self.onwallupdatefns = {}
	self.postupdatefns = {}
end)

function UpdateLooper:OnRemoveFromEntity()
    self.inst:StopUpdatingComponent(self)
    self.inst:StopWallUpdatingComponent(self)
	_PostUpdates[self.inst] = nil
end

function UpdateLooper:OnRemoveEntity()
	_PostUpdates[self.inst] = nil
end

function UpdateLooper:AddOnUpdateFn(fn)
    if #self.onupdatefns <= 0 then
        self.inst:StartUpdatingComponent(self)
    end
    table.insert(self.onupdatefns, fn)
end

function UpdateLooper:RemoveOnUpdateFn(fn)
	if #self.onupdatefns > 0 then
		if not self.OnUpdatesToRemove then
			self.OnUpdatesToRemove = {}
		end
		table.insert(self.OnUpdatesToRemove,fn)
	end
end

function UpdateLooper:AddLongUpdateFn(fn)
    table.insert(self.longupdatefns, fn)
end

function UpdateLooper:RemoveLongUpdateFn(fn)
	if #self.longupdatefns > 0 then
		if not self.OnLongUpdatesToRemove then
			self.OnLongUpdatesToRemove = {}
		end
		table.insert(self.OnLongUpdatesToRemove,fn)
	end
end

function UpdateLooper:OnUpdate(dt)
    if self.OnUpdatesToRemove then
        for i = 1, #self.OnUpdatesToRemove do
            local fn = self.OnUpdatesToRemove[i]
            table.removearrayvalue(self.onupdatefns, fn)
        end
        if #self.onupdatefns <= 0 then
            self.inst:StopUpdatingComponent(self)
        end
        self.OnUpdatesToRemove = nil
    end

	for i = #self.onupdatefns, 1, -1 do
        self.onupdatefns[i](self.inst, dt)
    end
end

function UpdateLooper:LongUpdate(dt)
    if self.OnLongUpdatesToRemove then
        for i = 1, #self.OnLongUpdatesToRemove do
            local fn = self.OnLongUpdatesToRemove[i]
            table.removearrayvalue(self.longupdatefns, fn)
        end
        self.OnLongUpdatesToRemove = nil
    end

	for i = #self.longupdatefns, 1, -1 do
        self.longupdatefns[i](self.inst, dt)
    end
end

function UpdateLooper:AddOnWallUpdateFn(fn)
    if #self.onwallupdatefns <= 0 then
	    self.inst:StartWallUpdatingComponent(self)
    end
    table.insert(self.onwallupdatefns, fn)
end

function UpdateLooper:RemoveOnWallUpdateFn(fn)
	if #self.onwallupdatefns > 0 then
		if not self.OnWallUpdatesToRemove then
			self.OnWallUpdatesToRemove = {}
		end
		table.insert(self.OnWallUpdatesToRemove, fn)
	end
end

function UpdateLooper:OnWallUpdate(dt)
    if TheNet:IsServerPaused() then return end

    if self.OnWallUpdatesToRemove then
        for i = 1, #self.OnWallUpdatesToRemove do
            local fn = self.OnWallUpdatesToRemove[i]
            table.removearrayvalue(self.onwallupdatefns, fn)
        end
        if #self.onwallupdatefns <= 0 then
            self.inst:StopWallUpdatingComponent(self)
        end
        self.OnWallUpdatesToRemove = nil
    end

	for i = 1, #self.onwallupdatefns do
        self.onwallupdatefns[i](self.inst, dt)
    end
end

--------------------------------------------------------------------------
--#V2C: it is now safe to add or remove fns during UpdateLooper_PostUpdate.
local _IsPostUpdating = false

function UpdateLooper:AddPostUpdateFn(fn)
	if #self.postupdatefns <= 0 then
		_PostUpdates[self.inst] = self.postupdatefns
	end
	self.postupdatefns[#self.postupdatefns + 1] = fn
end

function UpdateLooper:RemovePostUpdateFn(fn)
	for i = 1, #self.postupdatefns do --don't use ipairs, table may contain nil entries
		if fn == self.postupdatefns[i] then
			if _IsPostUpdating then
				self.postupdatefns[i] = nil
			else
				--not post updating loop, so it's safe to remove now
				local j = i
				for i = i + 1, #self.postupdatefns do
					local fn = self.postupdatefns[i]
					if fn then
						self.postupdatefns[j] = fn
						j = j + 1
					end
				end
				for i = j, #self.postupdatefns do
					self.postupdatefns[i] = nil
				end
				if #self.postupdatefns <= 0 then
					_PostUpdates[self.inst] = nil
				end
			end
			break
		end
	end
end

function UpdateLooper_PostUpdate()
	_IsPostUpdating = true
	for inst, fns in pairs(_PostUpdates) do
		local pendingremoval = false
		local i = 1
		while i <= #fns do --while loop because #fns is allowed to change now
			local fn = fns[i]
			if fn then --nil means removed during post update loop
				fn(inst)
				pendingremoval = pendingremoval or fns[i] == nil --could've removed itself
			else
				pendingremoval = true
			end
			i = i + 1
		end
		if pendingremoval then
			local j = 1
			for i = 1, #fns do
				local fn = fns[i]
				if fn then
					fns[j] = fn
					j = j + 1
				end
			end
			for i = j, #fns do
				fns[i] = nil
			end
			if #fns <= 0 then
				_PostUpdates[inst] = nil
			end
		end
	end
	_IsPostUpdating = false
end

--------------------------------------------------------------------------

return UpdateLooper
