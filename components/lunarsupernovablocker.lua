local easing = require("easing")
local WagBossUtil = require("prefabs/wagboss_util")

local LunarSupernovaBlocker = Class(function(self, inst)
	self.inst = inst
	self.sources = {}
	--self.onstartblockingfn = nil
	--self.onstopblockingfn = nil
	--self.flickerdelay = false

	--V2C: Recommended to explicitly add tag to prefab pristine state
	inst:AddTag("lunarsupernovablocker")
end)

function LunarSupernovaBlocker:OnRemoveFromEntity()
	self.inst:RemoveTag("lunarsupernovablocker")
end

function LunarSupernovaBlocker:SetOnStartBlockingFn(fn)
	self.onstartblockingfn = fn
end

function LunarSupernovaBlocker:SetOnStopBlockingFn(fn)
	self.onstopblockingfn = fn
end

function LunarSupernovaBlocker:AddSource(source)
	if self.sources[source] then
		return
	end
	local first = next(self.sources) == nil
	local fx = SpawnPrefab("wagboss_robot_leg_fx")
	fx.entity:SetParent(self.inst.entity)

	local x, y, z = self.inst.Transform:GetWorldPosition()
	local x1, y1, z1 = source.Transform:GetWorldPosition()
	if x == x1 and z == z1 then
		fx:Hide()
	else
		fx.Transform:SetRotation(math.atan2(z - z1, x1 - x) * RADIANS)
	end

	self.sources[source] = fx

	if first then
		self.inst:StartUpdatingComponent(self)

		self.flickerdelay = true
		self:UpdateFlicker()

		if self.onstartblockingfn then
			self.onstartblockingfn(self.inst)
		end
	end
end

function LunarSupernovaBlocker:RemoveSource(source)
	local fx = self.sources[source]
	if fx then
		fx:Remove()
		self.sources[source] = nil
		if next(self.sources) == nil then
			self.inst:StopUpdatingComponent(self)
			self.inst.components.colouradder:PopColour("lunarsupernovablocker")
			if self.onstopblockingfn then
				self.onstopblockingfn(self.inst)
			end
		end
	end
end

function LunarSupernovaBlocker:UpdateFlicker()
	self.flickerdelay = not self.flickerdelay
	if self.flickerdelay then
		return
	end
	local c = easing.inOutQuad(math.random(), 0.15, 0.1, 1)
	self.inst.components.colouradder:PushColour("lunarsupernovablocker", c, c, c, 0)
end

function LunarSupernovaBlocker:OnUpdate(dt)
	self:UpdateFlicker()

	local map = TheWorld.Map
	local x, _, z = self.inst.Transform:GetWorldPosition()
	local inarena = map:IsPointInWagPunkArenaAndBarrierIsUp(x, 0, z)

	for k, v in pairs(self.sources) do
		if not (k:IsValid() and (k.sg and k.sg:HasStateTag("supernovaburning"))) then
			self:RemoveSource(k)
		else
			local x1, _, z1 = k.Transform:GetWorldPosition()
			if inarena and not map:IsPointInWagPunkArena(x1, 0, z1) then
				self:RemoveSource(k)
			elseif not inarena and distsq(x, z, x1, z1) > WagBossUtil.SupernovaNoArenaRangeSq then
				--NOTE: >, not >=, since we're just going with FindEntities range
				self:RemoveSource(k)
			elseif x == x1 and z == z1 then
				v:Hide()
			else
				v.Transform:SetRotation(math.atan2(z - z1, x1 - x) * RADIANS)
				v:Show()
			end
		end
	end
end

return LunarSupernovaBlocker
