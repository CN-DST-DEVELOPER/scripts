local VaultOrbTeleportDestination = Class(function(self, inst)
    self.inst = inst

    self._onremoveicon = function()
        self.hiddenglobalicon:RemoveEventCallback("onremove", self._onremoveicon)
        self.hiddenglobalicon = nil
        self.inst:RemoveComponent("vaultorbteleportdestination")
    end
    local closeicon = SpawnPrefab("globalmapiconnoproxy")
    self.hiddenglobalicon = SpawnPrefab("globalmapicon")
    closeicon.entity:SetParent(self.hiddenglobalicon.entity)

    self.hiddenglobalicon:ListenForEvent("onremove", self._onremoveicon)
    self.hiddenglobalicon.MiniMapEntity:SetPriority(MINIMAP_DECORATION_PRIORITY)
    self.hiddenglobalicon:AddTag("vaultorbteleportdestinationtrackericon")
    self.hiddenglobalicon:TrackEntity(self.inst, "vaultorbteleportdestinationtracker", "vaultorbdestination_icon.png")

    closeicon.MiniMapEntity:SetPriority(MINIMAP_DECORATION_PRIORITY)
    closeicon.MiniMapEntity:SetRestriction("vaultorbteleportdestinationtracker")
    closeicon.MiniMapEntity:SetIcon("vaultorbdestination_icon.png")
end)

function VaultOrbTeleportDestination:OnRemoveEntity()
    if self.hiddenglobalicon then
        self.hiddenglobalicon:Remove()
    end
end
VaultOrbTeleportDestination.OnRemoveFromEntity = VaultOrbTeleportDestination.OnRemoveEntity


return VaultOrbTeleportDestination
