local function ReEnablePickupSound(inst, original)
	inst.pickupsound = original
end

local function OnIgnoreNext(inst)
	if inst.pickupsound ~= "NONE" then
		if not inst.components.clientpickupsoundsuppressor._ignorenext:value() and inst:GetTimeAlive() <= 0 then
			--Entity just spawned on client, but it's not a new spawn on server
			--so ignore the event.  Normally, we would've just used a net_event
			--and registered the listener one frame late.  However that pattern
			--would always ignore events that are actually pushed on spawn.
			return
		end
		local original = inst.pickupsound
		inst.pickupsound = "NONE"
		inst:DoStaticTaskInTime(2 * FRAMES, ReEnablePickupSound, original)
	end
end

local ClientPickupSoundSuppressor = Class(function(self, inst)
	self.inst = inst

	--using net_bool instead of net_event because we're gonna use both true & false
	self._ignorenext = net_bool(inst.GUID, "clientpickupsoundsuppressor._ignorenext", "clientpickupsoundsuppressor._ignorenext")

	if not TheWorld.ismastersim then
		inst:ListenForEvent("clientpickupsoundsuppressor._ignorenext", OnIgnoreNext)
	end
end)

function ClientPickupSoundSuppressor:IgnoreNextPickupSound()
	local wasjustspawned = self.inst:GetTimeAlive() <= 0
	self._ignorenext:set_local(wasjustspawned)
	self._ignorenext:set(wasjustspawned)
end

return ClientPickupSoundSuppressor
