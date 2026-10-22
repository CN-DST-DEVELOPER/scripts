local AutoJiggle = Class(function(self, inst)
	self.inst = inst
	self.ismastersim = TheWorld.ismastersim
	self.owner = nil
	self.onjiggleloopfn = nil
	self.onjiggleoneshotfn = nil
	self.updating = false
	self.runanims = { "run_pre", "run_loop" }
	self.frozenanims = { "frozen", "frozen_loop_pst" }
	self.hitanims = { "hit", "shock_loop" }
	self.electrocuteanims = { "shock", "shock_loop" }
end)

function AutoJiggle:SetOwner(owner)
	self.owner = owner
	if owner == nil then
		self:OnEntitySleep()
	elseif not (self.inst.sleepstatepending or self.inst:IsAsleep()) then
		self:OnEntityWake()
	end
end

function AutoJiggle:SetOnJiggleLoopFn(fn)
	self.onjiggleloopfn = fn
end

function AutoJiggle:SetOnJiggleOneShotFn(fn)
	self.onjiggleoneshotfn = fn
end

function AutoJiggle:OverrideRunAnims(anims)
	self.runanims = anims
end

function AutoJiggle:OverrideFrozenAnims(anims)
	self.frozenanims = anims
end

function AutoJiggle:OverrideHitAnims(anims)
	self.hitanims = anims
end

function AutoJiggle:OverrideElectrocuteAnims(anims)
	self.electrocuteanims = anims
end

function AutoJiggle:OnEntitySleep()
	if self.updating then
		self.updating = false
		self._wasmoving = nil
		self._wasrunning = nil
		self._wasnopredict = nil
		self.inst:StopUpdatingComponent(self)
	end
end

function AutoJiggle:OnEntityWake()
	if not self.updating and self.owner then
		self.updating = true
		self._wasmoving = false
		self._wasrunning = false
		self._wasnopredict = false
		self.inst:StartUpdatingComponent(self)
		self:OnUpdate(0)
	end
end

function AutoJiggle:OwnerMatchesAnimSet(anims)
	for _, v in ipairs(anims) do
		if self.owner.AnimState:IsCurrentAnimation(v) then
			return true
		end
	end
	return false
end

function AutoJiggle:OnUpdate(dt)
	local moving, running, nopredict
	if self.owner.sg then
		moving = self.owner.sg:HasStateTag("moving")
	else
		moving = self.owner:HasTag("moving")
	end
	if moving then
		--only check for walk vs run if it's a "character" or "companion"
		--players always running
		running = self.inst.isplayer or not self.inst:HasAnyTag("character", "companion") or self:OwnerMatchesAnimSet(self.runanims)
		nopredict = false
	elseif self:OwnerMatchesAnimSet(self.electrocuteanims) then
		--use running loop when electrocuted
		running = true
		nopredict = true
	else
		running = false
		if not self:OwnerMatchesAnimSet(self.frozenanims) then
			if self.ismastersim and self.owner.sg then
				nopredict = self.owner.sg:HasAnyStateTag("nopredict", "pausepredict")
			else
				nopredict = self.owner:HasAnyTag("nopredict", "pausepredict") or (self.owner.player_classified and self.owner.player_classified.pausepredictionframes:value() > 0)
			end
			nopredict = nopredict or self:OwnerMatchesAnimSet(self.hitanims)
		end
	end

	if running then
		if not self._wasrunning then
			if self.onjiggleloopfn then
				self.onjiggleloopfn(self.inst)
			end
		end
	elseif self._wasrunning or --stopped running
		(self._wasmoving and not moving) or --stopped walking
		(nopredict and not self._wasnopredict) --hit?
	then
		if self.onjiggleoneshotfn then
			self.onjiggleoneshotfn(self.inst)
		end
	end

	self._wasmoving = moving
	self._wasrunning = running
	self._wasnopredict = nopredict
end

return AutoJiggle
