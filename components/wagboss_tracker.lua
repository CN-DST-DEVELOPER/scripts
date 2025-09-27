return Class(function(self, inst)
self.inst = inst

local _world = TheWorld
self.wagboss_defeated = false

self.OnWagbossDefeated = function()
    self.wagboss_defeated = true
    _world:PushEvent("master_wagbossinfoupdate", {isdefeated = self.wagboss_defeated})
end

function self:IsWagbossDefeated()
    return self.wagboss_defeated
end

function self:OnSave()
    return {
        wagboss_defeated = self.wagboss_defeated,
    }
end

function self:OnLoad(data)
    if data then
        self.wagboss_defeated = data.wagboss_defeated
        _world:PushEvent("master_wagbossinfoupdate", {isdefeated = self.wagboss_defeated})
    end
end

inst:ListenForEvent("wagboss_defeated", self.OnWagbossDefeated)

end)