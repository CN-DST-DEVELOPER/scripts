local function oninactive(self, inactive)
    self.inst:AddOrRemoveTag("inactive", inactive)
end

local function onforcerightclickaction(self, forcerightclickaction)
    self.inst:AddOrRemoveTag("activatable_forceright", forcerightclickaction)
end

local function onremoved(inst)
    if inst.components.ghostbabysitter then
        for ghost, i in pairs(inst.components.ghostbabysitter.babysitting)do
            ghost.ghost_babysitter = nil
            if ghost.components.follower and ghost.components.follower.leader then
                ghost.components.follower.leader:RemoveTag("ghost_is_babysat")
            end
        end
    end
end

local Ghostbabysitter = Class(function(self, inst, activcb)
    self.inst = inst
    self.inactive = true
    self.forcerightclickaction = false
    self.babysitting = {}

    self.inst:ListenForEvent("onremove",onremoved)
    self.inst:ListenForEvent("onburnt",onremoved)
end,
nil,
{
    inactive = oninactive,
})

function Ghostbabysitter:OnRemoveFromEntity()
    self.inst:RemoveTag("inactive")
    self.inst:RemoveTag("activatable_forceright")
end

function Ghostbabysitter:IsBabysittingGhost(ghost)
    if self.babysitting[ghost] then
        return true
    end
end

function Ghostbabysitter:AddGhost(ghost)
    self.babysitting[ghost] = true
    self.inst:StartUpdatingComponent(self)
end

function Ghostbabysitter:RemoveGhost(ghost)
    self.babysitting[ghost] = nil
    if not next(self.babysitting) then
        self.inst:StopUpdatingComponent(self)
    end
end

function Ghostbabysitter:GetDebugString()    
	return tostring(self.inactive)
end

function Ghostbabysitter:OnUpdate(dt)
    if self.updatefn then
        self.updatefn(self.inst,self, dt)
    end
end

function Ghostbabysitter:LoadPostPass(newents, savedata)
   if savedata.babysitting then
        for _, ghostguid in ipairs(savedata.babysitting) do
            if newents[ghostguid] then
                local ghost = newents[ghostguid].entity
                ghost:PushEvent("set_babysitter", self.inst)
            end
        end
    end 
end

function Ghostbabysitter:OnSave()
    local data, ents = {}, {}

    if next(self.babysitting) then
        data.babysitting = {}
        for ghost, i in pairs(self.babysitting) do
            table.insert(data.babysitting, ghost.GUID)
            table.insert(ents, ghost.GUID)
        end
    end
    return data, ents
end

function Ghostbabysitter:OnLoad(data)
    if data then
    end
end

return Ghostbabysitter
