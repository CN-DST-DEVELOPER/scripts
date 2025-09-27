local function OnAvengeTimeDirty(inst)
    inst:PushEvent("clientavengetimedirty", { val = inst.components.avengingghost._avengetime:value() })
end

local MAX_TIME = 15
local TICKTIME = 1.1
local SLOWRATE = 0.5

local AvengingGhost = Class(function(self, inst)
    self.inst = inst
    self.ismastersim = TheWorld.ismastersim

    self._avengetime = net_float(inst.GUID, "avengingghost._avengetime", "avengetimedirty")
    self._maxtime = net_float(inst.GUID, "avengingghost._maxtime", "avengetimemaxdirty")
    self._symbol = net_hash(inst.GUID, "avengingghost._symbol", "avengingghostsymboldirty")

    self._maxtime:set(MAX_TIME)

    inst:ListenForEvent("avengetimedirty", OnAvengeTimeDirty)

	if not self.ismastersim then
		return
	end

	local onbecameghost = function()
		if self:ShouldAvenge() then
			self:StartAvenging()
		end
	end

	local onrespawnfromghost = function()
		self:StopAvenging()
	end

	local setattacktimer = function()
		if self.inst.components.timer:TimerExists("avenging_ghost_attack") then
			self.inst.components.timer:SetTimeLeft("avenging_ghost_attack",TICKTIME)
		else
			self.inst.components.timer:StartTimer("avenging_ghost_attack",TICKTIME)
		end
	end

    self.inst:ListenForEvent("ms_becameghost", onbecameghost )
    self.inst:ListenForEvent("ms_respawnedfromghost", onrespawnfromghost )
	self.inst:ListenForEvent("onareaattackother", setattacktimer )

    self.inst:DoTaskInTime(0,function()
		if self.load_avengetime and self.inst:HasTag("playerghost") then
			self:StartAvenging(self.load_avengetime)
			self.load_avengetime = nil
	    end
	end)

end)

-- Common Interface 
function AvengingGhost:GetSymbol()
    return self._symbol:value()
end

function AvengingGhost:GetTime()
    return self._avengetime:value()
end

function AvengingGhost:GetMaxTime()
    return self._maxtime:value()
end

-- Server Interface

local PLAYERMUST = {"player"}
function AvengingGhost:ShouldAvenge()
	if not self.ismastersim then
		return
	end

	local avenge = nil
	local x,y,z = self.inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, PLAYER_CAMERA_SEE_DISTANCE, PLAYERMUST)
	for _, ent in ipairs(ents) do
		if ent.components.skilltreeupdater and ent.components.skilltreeupdater:IsActivated("wendy_avenging_ghost") then
			avenge = true
			break
		end
	end

	return avenge
end

local function SetGhostDamage(inst, push)
	local attack_anim = "attack1"
	if TheWorld.state.isday then
		inst.components.combat.defaultdamage = TUNING.ABIGAIL_DAMAGE.day
		attack_anim = "attack1"
	elseif TheWorld.state.isdusk then
		inst.components.combat.defaultdamage = TUNING.ABIGAIL_DAMAGE.dusk
		attack_anim = "attack2"
	elseif TheWorld.state.isnight then
		inst.components.combat.defaultdamage = TUNING.ABIGAIL_DAMAGE.night
		attack_anim = "attack3"
	end
	if push then
		inst.ghost_attack_fx.AnimState:PlayAnimation(attack_anim .. "_pre")
		inst.ghost_attack_fx.AnimState:PushAnimation(attack_anim .. "_loop", true)
	else
		inst.ghost_attack_fx.AnimState:PlayAnimation(attack_anim .. "_loop", true)
	end
end

function AvengingGhost:StartAvenging(time)
	if not self.ismastersim then
		return
	end

	local set = time or MAX_TIME
	self._avengetime:set(set)

    self.olddamage = self.inst.components.combat.defaultdamage
    self.inst:WatchWorldState("isnight", SetGhostDamage)
    self.inst:WatchWorldState("isday", SetGhostDamage)
    self.inst:WatchWorldState("isdusk", SetGhostDamage)

    self.inst.ghost_attack_fx = SpawnPrefab("abigail_attack_fx")
    self.inst:AddChild(self.inst.ghost_attack_fx)

    SetGhostDamage(self.inst, true)

    self.inst.SoundEmitter:PlaySound("dontstarve/characters/wendy/abigail/attack_LP", "angry")
    self.inst.AnimState:SetMultColour(207/255, 92/255, 92/255, 1)

	self.inst.components.aura:Enable(true)
	self.inst:StartUpdatingComponent(self)
end

function AvengingGhost:StopAvenging()
	if not self.ismastersim then
		return
	end

	if self.olddamage then
		self._avengetime:set(0)

	    self.inst:StopWatchingWorldState("isnight", SetGhostDamage)
	    self.inst:StopWatchingWorldState("isday", SetGhostDamage)
	    self.inst:StopWatchingWorldState("isdusk", SetGhostDamage)
		self.inst.components.combat.defaultdamage = self.olddamage

	    self.inst.SoundEmitter:KillSound("angry")
	    self.inst.AnimState:SetMultColour(1, 1, 1, 1)

	    if self.inst.ghost_attack_fx then
	        self.inst.ghost_attack_fx:Remove()
	    end

		self.inst.components.aura:Enable(false)
		self.olddamage = nil
	end
	self.inst:StopUpdatingComponent(self)
end

function AvengingGhost:OnUpdate(dt)
	if not self.ismastersim then
		return
	end
	local time = dt

	if self.inst.components.timer:TimerExists("avenging_ghost_attack") then
		time = dt * SLOWRATE
	end
	self._avengetime:set( self._avengetime:value() - time )

	if self._avengetime:value() <= 0 then
		self:StopAvenging()
	end
end

function AvengingGhost:OnSave()
	local data = {}
	data.avengetime = self.load_avengetime or self._avengetime:value()
    return data
end

function AvengingGhost:OnLoad(data, newents)
	if data and data.avengetime then
		self.load_avengetime = data.avengetime
	end
end

return AvengingGhost
