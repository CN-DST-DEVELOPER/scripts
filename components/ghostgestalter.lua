local function onstandingaction(self, standingaction)
    self.inst:AddOrRemoveTag("standingactivation", standingaction)
end

local function onquickaction(self, quickaction)
    self.inst:AddOrRemoveTag("quickactivation", quickaction)
end

local function onforcerightclickaction(self, forcerightclickaction)
    self.inst:AddOrRemoveTag("activatable_forceright", forcerightclickaction)
end

local function onforcenopickupaction(self, forcenopickupaction)
    self.inst:AddOrRemoveTag("activatable_forcenopickup", forcenopickupaction)
end

local Ghostgestalter = Class(function(self, inst, activcb)
    self.inst = inst
    self.OnActivate = activcb
    self.standingaction = false
    self.quickaction = false

    self.forcerightclickaction = false
    self.forcenopickupaction = false

    self.domutatefn = nil
end,
nil,
{
    standingaction = onstandingaction,
    quickaction = onquickaction,
    forcerightclickaction = onforcerightclickaction,
    forcenopickupaction = onforcenopickupaction,
})

function Ghostgestalter:OnRemoveFromEntity()
    self.inst:RemoveTag("quickactivation")
    self.inst:RemoveTag("standingactivation")
    self.inst:RemoveTag("activatable_forceright")
    self.inst:RemoveTag("activatable_forcenopickup")
end

function Ghostgestalter:DoMutate(doer)
    if self.domutatefn then
        return self.domutatefn(self.inst, doer)
    end
end

return Ghostgestalter
