local CameraFade = Class(function(self, inst)
    self.inst = inst
	self.ismastersim = TheWorld.ismastersim

    --
    self.range = 25
    self.fadetodist = 5
    --
    self.center_symbol = nil
    self.center_min_dist_sq = nil
    self.center_dist_sq = nil
    self.center_min_fade = nil
    --
    self.lerp_to_height = nil
    --
    self.alpha = 1
	self.updating = false

	self:Enable(true)
end)

function CameraFade:OnRemoveFromEntity()
	self:Enable(false, true)
end

function CameraFade:Enable(enable, instant)
	if enable then
		self.enabled = true
		if not (self.updating or self.inst:IsAsleep()) then
			self.updating = true
			self.inst:StartWallUpdatingComponent(self)
		end
	else
		self.enabled = false
		if instant and self.updating then
			self.inst.AnimState:OverrideMultColour(1, 1, 1, 1)
			self.alpha = 1
			self.updating = false
			self.inst:StopWallUpdatingComponent(self)
		end
	end
end

function CameraFade:SetUp(range, fadetodist)
    self.range = range
    self.fadetodist = fadetodist
end

function CameraFade:SetUpCenterFade(symbol, min_dist_sq, dist_sq, min_fade)
    self.center_symbol = symbol
    self.center_min_dist_sq = min_dist_sq
    self.center_dist_sq = dist_sq
    self.center_min_fade = min_fade
end

function CameraFade:SetLerpToHeight(height)
    self.lerp_to_height = height
end

function CameraFade:GetCurrentAlpha()
    return self.alpha
end

function CameraFade:OnEntitySleep()
	if self.updating then
		self.updating = false
		self.inst:StopWallUpdatingComponent(self)
		if not self.enabled then
			self.inst.AnimState:OverrideMultColour(1, 1, 1, 1)
			self.alpha = 1
		end
	end
end

function CameraFade:OnEntityWake()
	if (self.enabled or self.alpha < 1) and not self.updating then
		self.updating = true
		self.inst:StartWallUpdatingComponent(self)
	end
end

function CameraFade:OnWallUpdate(dt)
	local x, y, z = self.inst.Transform:GetWorldPosition()

	if self.ismastersim and (ThePlayer == nil or ThePlayer:GetDistanceSqToPoint(x, y, z) >= 900) then
        self.inst.AnimState:OverrideMultColour(1, 1, 1, 1)
		self.alpha = 1
		if not self.enabled then
			self.updating = false
			self.inst:StopWallUpdatingComponent(self)
		end
        return
    end

    local camx, camy, camz = TheCamera.camera_pos:Get()
    local dx, dy, dz = camx - x, camy - y, camz - z

    local down = TheCamera:GetDownVec()
    local dot = dx * down.x + dy * down.y + dz * down.z
    local mody = dot - self.fadetodist

    local percent = 1

    if self.center_symbol ~= nil then
        local symbolx, symboly, symbolz, success = self.inst.AnimState:GetSymbolPosition(self.center_symbol)
        if success then
            local w, h = TheSim:GetScreenSize()
            local res_scale = math.max(w / RESOLUTION_X, h / RESOLUTION_Y)

            local cam_pos = TheCamera.targetpos - TheCamera.targetoffset
            local camsx, camsy = TheSim:GetScreenPos(cam_pos:Get())
            local sx, sy = TheSim:GetScreenPos(symbolx, symboly, symbolz)

            local dist_sq = distsq(camsx, camsy, sx, sy)
            local center_min_dist_sq = self.center_min_dist_sq * res_scale
            local center_dist_sq = self.center_dist_sq * res_scale
            percent = percent * math.clamp(math.max(0, dist_sq - center_min_dist_sq) / center_dist_sq, self.center_min_fade, 1)
        end
    end

    if mody <= self.range then
        percent = percent * (math.max(mody, 0) / self.range)
    end

    if self.lerp_to_height ~= nil then
        percent = Lerp(1, percent, math.clamp(y / self.lerp_to_height, 0, 1))
    end

	if math.abs(self.alpha - percent) < 1 / 255 then
		self.alpha = percent
	else
		self.alpha = self.alpha * 0.95 + percent * 0.05
	end
	self.inst.AnimState:OverrideMultColour(1, 1, 1, self.alpha)
	if not self.enabled and self.alpha >= 1 then
		self.updating = false
		self.inst:StopWallUpdatingComponent(self)
	end
end

return CameraFade