--[[
Add this component to items that need a targetting reticule
during use with a controller. Creation of the reticule is handled by
playercontroller.lua equip and unequip events.
--]]

local Reticule = Class(function(self, inst)
    self.inst = inst
    self.targetpos = nil
    self.ease = false
    self.smoothing = 6.66
    self.targetfn = nil
    self.mousetargetfn = nil
    self.updatepositionfn = nil
    self.reticuleprefab = "reticule"
    self.reticule = nil
    self.validcolour = { 204 / 255, 131 / 255, 57 / 255, 1 }
    self.invalidcolour = { 1, 0, 0, 1 }
    self.currentcolour = self.invalidcolour
    self.mouseenabled = false
	self.twinstickmode = nil
	self.twinstickrange = nil
    self.followhandler = nil
    self.fadealpha = 1
    self.blipalpha = 1
    self.pingprefab = nil
    self._oncameraupdate = function(dt) self:OnCameraUpdate(dt) end
end)

function Reticule:CreateReticule()
    if self.reticule == nil then
        self.reticule = SpawnPrefab(self.reticuleprefab)
        if self.reticule == nil then
            return
        end
    end

    if self.mouseenabled and not TheInput:ControllerAttached() then
        if self.followhandler == nil then
            self.followhandler = TheInput:AddMoveHandler(function(x, y)
                local x1, y1, z1 = TheSim:ProjectScreenPos(x, y)
                local pos = x1 ~= nil and y1 ~= nil and z1 ~= nil and Vector3(x1, y1, z1) or nil
                if self.mousetargetfn ~= nil then
                    self.targetpos = self.mousetargetfn(self.inst, pos)
                else
                    self.targetpos = pos
                end
                self:UpdatePosition()
            end)
        end
        local pos = TheInput:GetWorldPosition()
        if self.mousetargetfn ~= nil then
            self.targetpos = self.mousetargetfn(self.inst, pos)
        else
            self.targetpos = pos
        end
        self.fadealpha = 1
    else
        if self.followhandler ~= nil then
            self.followhandler:Remove()
            self.followhandler = nil
        end
        if self.targetfn ~= nil then
            self.targetpos = self.targetfn(self.inst)
        end
        self.fadealpha = 1
    end

    self.currentcolour = self.invalidcolour
    self.blipalpha = 1
    self.inst:StopUpdatingComponent(self)
    self:UpdatePosition()
    TheCamera:AddListener(self, self._oncameraupdate)
end

function Reticule:DestroyReticule()
    if self.reticule ~= nil then
        self.reticule:Remove()
        self.reticule = nil
    end
    if self.followhandler ~= nil then
        self.followhandler:Remove()
        self.followhandler = nil
    end
    self.fadealpha = 1
    self.blipalpha = 1
    self.inst:StopUpdatingComponent(self)
    TheCamera:RemoveListener(self, self._oncameraupdate)
end

function Reticule:PingReticuleAt(pos)
    if self.pingprefab ~= nil and pos ~= nil then
		local platform
		if pos:is_a(DynamicPosition) then
			platform = pos.walkable_platform
			pos = pos:GetPosition()
		end
		if pos ~= nil then
			local ping = SpawnPrefab(self.pingprefab)
			if ping ~= nil then
				ping.AnimState:SetMultColour(unpack(self.validcolour))
				ping.AnimState:SetAddColour(.2, .2, .2, 0)
				if self.updatepositionfn ~= nil then
					self.updatepositionfn(self.inst, pos, ping)
				else
					ping.Transform:SetPosition(pos.x, 0, pos.z)
				end
				if platform ~= nil then
					--Assume valid otherwise pos would've been nil
					--assert(platform:IsValid())
					ping.Transform:SetPosition(platform.entity:WorldToLocalSpace(ping.Transform:GetWorldPosition()))
					ping.entity:SetParent(platform.entity)
					ping:ListenForEvent("onremove", function()
						ping.Transform:SetPosition(ping.Transform:GetWorldPosition())
						ping.entity:SetParent(nil)
					end, platform)
				end
			end
		end
    end
end

function Reticule:Blip()
    if self.reticule ~= nil then
        self.blipalpha = 0
        self.inst:StartUpdatingComponent(self)
        self:UpdateColour()
    end
end

function Reticule:OnUpdate(dt)
    self.blipalpha = self.blipalpha + dt * 5
    if self.blipalpha >= 1 then
        self.blipalpha = 1
        self.inst:StopUpdatingComponent(self)
    end
    if self.reticule then
        self:UpdateColour()
    end
end

function Reticule:UpdateColour()
    local a = self.targetpos ~= nil and self.fadealpha * self.blipalpha or self.blipalpha
    self.reticule.AnimState:SetMultColour(self.currentcolour[1], self.currentcolour[2], self.currentcolour[3], self.currentcolour[4] * a)
end

function Reticule:UpdatePosition(dt)
    if self.targetpos ~= nil then
        local x, y, z = self.targetpos:Get()
		local alwayspassable, allowwater, deployradius
		local aoetargeting = self.inst.components.aoetargeting
		if aoetargeting ~= nil then
			alwayspassable = aoetargeting.alwaysvalid
			allowwater = aoetargeting.allowwater
			deployradius = aoetargeting.deployradius
		end
		alwayspassable = alwayspassable or self.ispassableatallpoints
		if TheWorld.Map:CanCastAtPoint(self.targetpos, alwayspassable, allowwater, deployradius) then
            self.currentcolour = self.validcolour
            self.reticule.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        else
            self.currentcolour = self.invalidcolour
            self.reticule.AnimState:ClearBloomEffectHandle()
        end

        if self.ease and dt ~= nil then
            local x0, y0, z0 = self.reticule.Transform:GetWorldPosition()
            x = Lerp(x0, x, dt * self.smoothing)
            z = Lerp(z0, z, dt * self.smoothing)
        end
        if self.updatepositionfn ~= nil then
            self.updatepositionfn(self.inst, Vector3(x, 0, z), self.reticule, self.ease, self.smoothing, dt)
        else
            self.reticule.Transform:SetPosition(x, 0, z)
        end
    end
    self:UpdateColour()
end

function Reticule:OnCameraUpdate(dt)
    if self.followhandler ~= nil then
        self.fadealpha = TheInput:GetHUDEntityUnderMouse() ~= nil and math.max(.3, self.fadealpha - .2) or math.min(1, self.fadealpha + .2)
        local pos = TheInput:GetWorldPosition()
        if self.mousetargetfn ~= nil then
            self.targetpos = self.mousetargetfn(self.inst, pos)
        else
            self.targetpos = pos
        end
        self:UpdatePosition(nil)
	elseif self.targetfn ~= nil then
		if self.twinstickmode ~= nil and TheInput:ControllerAttached() then
			if self.twinstickmode == 1 then
				self:UpdateTwinStickMode1()
			elseif self.twinstickmode == 2 then
				self:UpdateTwinStickMode2()
			else
				self.targetpos = self.targetfn(self.inst)
			end
		else
			self:ClearTwinStickOverrides()
			self.targetpos = self.targetfn(self.inst)
		end
		self:UpdatePosition(dt) --always update for dt easing
	end
end

function Reticule:UpdateTwinStickMode1()
	local xdir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
	local ydir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_UP) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)
	local xmag = xdir * xdir + ydir * ydir

	if self.twinstickoverride then
		--update offset
		local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
		if xmag > deadzone * deadzone then
			xmag = math.sqrt(xmag)
			xmag = (xmag - deadzone) / xmag
			xmag = xmag * xmag * TUNING.CONTROLLER_RETICULE_RSTICK_SPEED
			self.twinstickx = self.twinstickx - ydir * xmag
			self.twinstickz = self.twinstickz + xdir * xmag
			local dsq = self.twinstickx * self.twinstickx + self.twinstickz * self.twinstickz
			local range = self.twinstickrange or 8
			if dsq > range * range then
				--clamp at range
				range = range / math.sqrt(dsq)
				self.twinstickx = self.twinstickx * range
				self.twinstickz = self.twinstickz * range
			end
		end
		--re-apply offset relative to screen
		local x, y, z = self.inst.Transform:GetWorldPosition()
		if self.twinstickx ~= 0 or self.twinstickz ~= 0 then
			local heading = TheCamera:GetHeadingTarget() * DEGREES
			local sin_heading = math.sin(heading)
			local cos_heading = math.cos(heading)
			self.targetpos.x = x + self.twinstickx * cos_heading - self.twinstickz * sin_heading
			self.targetpos.z = z + self.twinstickx * sin_heading + self.twinstickz * cos_heading
		else
			self.targetpos.x, self.targetpos.z = x, z
		end
		--
		if self.mousetargetfn ~= nil then
			self.targetpos = self.mousetargetfn(self.inst, self.targetpos)
		end
	else
		self.targetpos = self.targetfn(self.inst)

		local initial_deadzone = TUNING.CONTROLLER_RETICULE_INITIAL_DEADZONE_RADIUS
		if xmag >= initial_deadzone * initial_deadzone then
			self.twinstickoverride = true
			--determine initial offset relative to screen
			local x, y, z = self.inst.Transform:GetWorldPosition()
			x = self.targetpos.x - x
			z = self.targetpos.z - z
			if x ~= 0 or z ~= 0 then
				local heading = -TheCamera:GetHeadingTarget() * DEGREES
				local sin_heading = math.sin(heading)
				local cos_heading = math.cos(heading)
				self.twinstickx = x * cos_heading - z * sin_heading
				self.twinstickz = x * sin_heading + z * cos_heading
			else
				self.twinstickx, self.twinstickz = x, z
			end
		end
	end
end

function Reticule:UpdateTwinStickMode2()
	self.targetpos = self.targetfn(self.inst)

	local xdir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
	local ydir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_UP) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)
	local xmag = xdir * xdir + ydir * ydir
	local deadzone = TUNING.CONTROLLER_DEADZONE_RADIUS
	if not self.twinstickoverride then
		local initial_deadzone = TUNING.CONTROLLER_RETICULE_INITIAL_DEADZONE_RADIUS
		if xmag >= initial_deadzone * initial_deadzone then
			self.twinstickoverride = true
		end
	elseif xmag < deadzone * deadzone then
		self.twinstickoverride = false
	end

	if self.twinstickoverride then
		--normalize
		xmag = math.sqrt(xmag)
		xdir = xdir / xmag
		ydir = ydir / xmag
		--rotate to screen
		local heading = (TheCamera:GetHeadingTarget() + 90) * DEGREES
		local sin_heading = math.sin(heading)
		local cos_heading = math.cos(heading)
		local dx = xdir * cos_heading - ydir * sin_heading
		local dz = xdir * sin_heading + ydir * cos_heading
		--rescale xmag
		xmag = Remap(xmag, deadzone, math.max(1, xmag), 0, 1)
		xmag = xmag * xmag
		--find outer edge of range that we're aiming at
		local x, y, z = self.inst.Transform:GetWorldPosition()
		local range = self.twinstickrange or 8
		x = x + dx * range
		z = z + dz * range
		--lerp toward outer edge from the auto-target point instead of true center
		self.targetpos.x = self.targetpos.x * (1 - xmag) + x * xmag
		self.targetpos.z = self.targetpos.z * (1 - xmag) + z * xmag
		--
		if self.mousetargetfn ~= nil then
			self.targetpos = self.mousetargetfn(self.inst, self.targetpos)
		end
	end
end

function Reticule:ClearTwinStickOverrides()
	if self.twinstickoverride then
		self.twinstickoverride = nil
		self.twinstickx = nil
		self.twinstickz = nil
	end
end

function Reticule:ShouldHide()
	return self.shouldhidefn ~= nil and self.shouldhidefn(self.inst) or false
end

Reticule.OnRemoveFromEntity = Reticule.DestroyReticule
Reticule.OnRemoveEntity = Reticule.DestroyReticule

return Reticule
