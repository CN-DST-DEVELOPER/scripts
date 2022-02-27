--V2C: component for adding generic onupdate loops to entities
--     since we found out that DoPeriodicTask(0) doesn't trigger precisely every frame

local UpdateLooper = Class(function(self, inst)
    self.inst = inst
    self.onupdatefns = {}
    self.longupdatefns = {}
	self.onwallupdatefns = {}
end)

function UpdateLooper:OnRemoveFromEntity()
    self.inst:StopUpdatingComponent(self)
    self.inst:StopWallUpdatingComponent(self)
end

function UpdateLooper:AddOnUpdateFn(fn)
    if #self.onupdatefns <= 0 then
        self.inst:StartUpdatingComponent(self)
    end
    table.insert(self.onupdatefns, fn)
end

function UpdateLooper:RemoveOnUpdateFn(fn)
    table.removearrayvalue(self.onupdatefns, fn)
    if #self.onupdatefns <= 0 then
        self.inst:StopUpdatingComponent(self)
    end
end

function UpdateLooper:AddLongUpdateFn(fn)
    table.insert(self.longupdatefns, fn)
end

function UpdateLooper:RemoveLongUpdateFn(fn)
    table.removearrayvalue(self.longupdatefns, fn)
end

function UpdateLooper:OnUpdate(dt)
	for i = #self.onupdatefns, 1, -1 do
        self.onupdatefns[i](self.inst, dt)
    end
end

function UpdateLooper:LongUpdate(dt)
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
    table.removearrayvalue(self.onwallupdatefns, fn)
    if #self.onwallupdatefns <= 0 then
		self.inst:StopWallUpdatingComponent(self)
    end
end

function UpdateLooper:OnWallUpdate(dt)
    if TheNet:IsServerPaused() then return end

	for i = 1, #self.onwallupdatefns do
        self.onwallupdatefns[i](self.inst, dt)
    end
end

return UpdateLooper
