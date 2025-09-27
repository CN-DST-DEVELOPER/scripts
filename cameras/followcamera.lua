require("camerashake")

--When onupdatefn is set to nil, use dummyfn instead.
--This way we don't need to check for nil in the update loop.
--It's more optimized because there's always an actual onupdatefn
--when the world is live and performance does matter.
local function dummyfn()
end

local function onmaxdist(self, maxdist, old)
    if maxdist ~= nil and self.extramaxdist ~= nil then
        rawget(self, "_").maxdist[1] = maxdist + self.extramaxdist
    end
end

local function onextramaxdist(self, extramaxdist, old)
    old = old or 0

    self.maxdist = self.maxdist - old

    if extramaxdist ~= old and
        self:CanControl() and
        not self.cutscene and -- NOTES(DiogoW): self.cutscene seems unused.
        not self.paused       -- NOTES(DiogoW): self.paused seems unused.
    then
        self:MaximizeDistance()
    end
end

local FollowCamera = Class(function(self, inst)
    self.inst = inst
    self.target = nil
    self.currentpos = Vector3(0, 0, 0)
    self.currentscreenxoffset = 0
    self.distance = 30
    self.maxdist = 0
    self.extramaxdist = 0
    self.screenoffsetstack = {}
    self.updatelisteners = {}
    self.largeupdatelisteners = {}
    self:SetDefault()
    self:Snap()
    self.time_since_zoom = nil
    self.onupdatefn = dummyfn

    self.gamemode_defaultfn = GetGameModeProperty("cameraoverridefn")
end,
nil,
{
    maxdist = onmaxdist,
    extramaxdist = onextramaxdist,
})

function FollowCamera:SetDefaultOffset()
    self.targetoffset = Vector3(0, 1.5, 0)
end

function FollowCamera:SetDefault()
    self.targetpos = Vector3(0, 0, 0)
    --self.currentpos = Vector3(0, 0, 0)
    self:SetDefaultOffset()

    if self.headingtarget == nil then
        self.headingtarget = 45
    end

    self.fov = 35
    self.pangain = 4
    self.headinggain = 20
    self.distancegain = 1
	self.continuousdistancegain = 6

    self.zoomstep = 4
    self.distancetarget = 30
    --self.lockdistance = nil

    self.mindist = 15
    self.maxdist = 50 --40

    self.mindistpitch = 30
    self.maxdistpitch = 60--60
    self.paused = false
    self.shake = nil
    self.controllable = true
    self.cutscene = false

    if TheWorld ~= nil and TheWorld:HasTag("cave") then
        self.mindist = 15
        self.maxdist = 35
        self.mindistpitch = 25
        self.maxdistpitch = 40
        self.distancetarget = 25
    end

	if self.gamemode_defaultfn then
		self.gamemode_defaultfn(self)
	end

    if self.target ~= nil then
        self:SetTarget(self.target)
    end
end

function FollowCamera:GetRightVec()
    local right = (self.headingtarget + 90) * DEGREES
    return Vector3(math.cos(right), 0, math.sin(right))
end

function FollowCamera:GetDownVec()
    local heading = self.headingtarget * DEGREES
    return Vector3(math.cos(heading), 0, math.sin(heading))
end

function FollowCamera:GetPitchDownVec()
    local pitch = self.pitch * DEGREES
    local heading = self.heading * DEGREES
    local cos_pitch = -math.cos(pitch)
    local cos_heading = math.cos(heading)
    local sin_heading = math.sin(heading)
    return Vector3(cos_pitch * cos_heading, -math.sin(pitch), cos_pitch * sin_heading)
end

function FollowCamera:SetPaused(val)
	self.paused = val
end

function FollowCamera:SetMinDistance(distance)
    self.mindist = distance
end

function FollowCamera:SetMaxDistance(distance)
    self.maxdist = distance
end

function FollowCamera:SetExtraMaxDistance(distance)
    self.extramaxdist = distance
end

function FollowCamera:SetGains(pan, heading, distance)
    self.pangain = pan
    self.headinggain = heading
    self.distancegain = distance
end

function FollowCamera:GetGains(pan, heading, distance)
    return self.pangain, self.headinggain, self.distancegain
end

function FollowCamera:IsControllable()
    return self.controllable
end

function FollowCamera:SetControllable(val)
    self.controllable = val
end

function FollowCamera:CanControl()
    return self.controllable
end

function FollowCamera:SetOffset(offset)
    self.targetoffset.x, self.targetoffset.y, self.targetoffset.z = offset:Get()
end

function FollowCamera:PushScreenHOffset(ref, xoffset)
    self:PopScreenHOffset(ref)
    table.insert(self.screenoffsetstack, 1, { ref = ref, xoffset = xoffset })
end

function FollowCamera:PopScreenHOffset(ref)
    for i, v in ipairs(self.screenoffsetstack) do
        if v.ref == ref then
            table.remove(self.screenoffsetstack, i)
            return
        end
    end
end

function FollowCamera:LockDistance(lock)
    self.lockdistance = lock or nil
end

function FollowCamera:GetDistance()
    return self.distancetarget
end

function FollowCamera:SetDistance(dist)
    self.distancetarget = dist
end

function FollowCamera:Shake(type, duration, speed, scale)
    if Profile:IsScreenShakeEnabled() then
        self.shake = CameraShake(type, duration, speed, scale)
    end
end

function FollowCamera:SetTarget(inst)
    self.target = inst
    if inst ~= nil then
        self.targetpos.x, self.targetpos.y, self.targetpos.z = self.target.Transform:GetWorldPosition()
    else
        self.targetpos.x, self.targetpos.y, self.targetpos.z = 0, 0, 0
    end
end

function FollowCamera:MaximizeDistance()
    self.distancetarget = (self.maxdist - self.mindist) * 0.7 + self.mindist
end

local DELTA_DIST_SQ_UPDATE = 4
function FollowCamera:Apply()
    --dir
    local pitch = self.pitch * DEGREES
    local heading = self.heading * DEGREES
    local cos_pitch = math.cos(pitch)
    local cos_heading = math.cos(heading)
    local sin_heading = math.sin(heading)
    local dx = -cos_pitch * cos_heading
    local dy = -math.sin(pitch)
    local dz = -cos_pitch * sin_heading

    --screen horizontal offset
    local xoffs, zoffs = 0, 0
    if self.currentscreenxoffset ~= 0 then
        --FOV is relative to screen height
        --hoffs is in units of screen heights
        --convert hoffs to xoffs and zoffs in world space
        local hoffs = 2 * self.currentscreenxoffset / RESOLUTION_Y
        local magic_number = 1.03 -- plz... halp.. if u can figure out what this rly should be
        local screen_heights = math.tan(self.fov * .5 * DEGREES) * self.distance * magic_number
        xoffs = -hoffs * sin_heading * screen_heights
        zoffs = hoffs * cos_heading * screen_heights
    end



    --pos

    self.camera_pos = Vector3(
        self.currentpos.x - dx * self.distance + xoffs,
        self.currentpos.y - dy * self.distance,
        self.currentpos.z - dz * self.distance + zoffs
    )
    self.camera_dir = Vector3(dx, dy, dz)

    TheSim:SetCameraPos(self.camera_pos:Get())
    TheSim:SetCameraDir(self.camera_dir:Get())

    --right
    local right = (self.heading + 90) * DEGREES
    local rx = math.cos(right)
    local ry = 0
    local rz = math.sin(right)

    --up
    local ux = dy * rz - dz * ry
    local uy = dz * rx - dx * rz
    local uz = dx * ry - dy * rx

    self.camera_up = Vector3(ux, uy, uz)

    TheSim:SetCameraUp(self.camera_up:Get())
    TheSim:SetCameraFOV(self.fov)

    local old_camera_pos = self.last_update_camera_pos
    local old_camera_dir = self.last_update_camera_dir
    local old_camera_up = self.last_update_camera_up

    if old_camera_pos == nil or
        old_camera_pos:DistSq(self.camera_pos) >= DELTA_DIST_SQ_UPDATE or
        old_camera_dir:DistSq(self.camera_dir) >= DELTA_DIST_SQ_UPDATE or
        old_camera_up:DistSq(self.camera_up) >= DELTA_DIST_SQ_UPDATE
    then
        self.last_update_camera_pos = self.camera_pos
        self.last_update_camera_dir = self.camera_dir
        self.last_update_camera_up = self.camera_up

        self.large_dist_update = true
    end

    --listen dist
    local listendist = -.1 * self.distance
    TheSim:SetListener(
        dx * listendist + self.currentpos.x,
        dy * listendist + self.currentpos.y,
        dz * listendist + self.currentpos.z,
        dx, dy, dz,
        ux, uy, uz
    )
end

local function lerp(lower, upper, t)
    return t > 1 and upper
        or (t < 0 and lower
        or lower * (1 - t) + upper * t)
end

local function normalize(angle)
    while angle > 360 do
        angle = angle - 360
    end
    while angle < 0 do
        angle = angle + 360
    end
    return angle
end

function FollowCamera:GetHeading()
    return self.heading
end

function FollowCamera:GetHeadingTarget()
    return self.headingtarget
end

function FollowCamera:SetHeadingTarget(r)
	self.headingtarget = normalize(r)
	self.headingdelta = nil
	self.lastheadingdelta = nil
end

--V2C: Added for controller camera modifer rotation, where we rotate
--     smoothly instead of periodically snapping 45 degrees. "delta"
--     controls the speed of rotation based on analog control.
function FollowCamera:SetContinuousHeadingTarget(r, delta)
	self.headingtarget = normalize(r)

	if self.lastheadingdelta and (self.lastheadingdelta > 0) == (delta > 0) then
		self.headingdelta = (delta + self.lastheadingdelta) / 2
	else
		self.headingdelta = delta
	end
end

function FollowCamera:ContinuousZoomDelta(delta)
	if self.lastzoomdelta and (self.lastzoomdelta > 0) == (delta > 0) then
		delta = (delta + self.lastzoomdelta) / 2
	end
	self.distancetarget = math.clamp(self.distancetarget + delta, self.mindist, self.maxdist)
	self.lastzoomdelta = delta
	self.time_since_zoom = 0
end

function FollowCamera:ZoomIn(step)
    self.distancetarget = math.max(self.mindist, self.distancetarget - (step or self.zoomstep))
	self.lastzoomdelta = nil
    self.time_since_zoom = 0
end

function FollowCamera:ZoomOut(step)
    self.distancetarget = math.min(self.maxdist, self.distancetarget + (step or self.zoomstep))
	self.lastzoomdelta = nil
    self.time_since_zoom = 0
end

function FollowCamera:Snap()
    if self.target ~= nil then
        local x, y, z = self.target.Transform:GetWorldPosition()
        self.targetpos.x = x + self.targetoffset.x
        self.targetpos.y = y + self.targetoffset.y
        self.targetpos.z = z + self.targetoffset.z
    else
        self.targetpos.x, self.targetpos.y, self.targetpos.z = self.targetoffset:Get()
    end

    self.currentscreenxoffset = #self.screenoffsetstack > 0 and self.screenoffsetstack[1].xoffset or 0
    self.currentpos.x, self.currentpos.y, self.currentpos.z = self.targetpos:Get()
    self.heading = self.headingtarget
	self.headingdelta = nil
	self.lastheadingdelta = nil
    if not self.lockdistance then
        self.distance = self.distancetarget
		self.lastzoomdelta = nil
    end

    self.pitch = lerp(self.mindistpitch, self.maxdistpitch, (self.distance - self.mindist) / (self.maxdist - self.mindist))

    self:Apply()
    self:UpdateListeners(0)
end

function FollowCamera:CutsceneMode(b)
    self.cutscene = b
end

function FollowCamera:SetCustomLocation(loc)
    self.targetpos.x, self.targetpos.y, self.targetpos.z  = loc:Get()
end

function FollowCamera:Update(dt, dontupdatepos)
    if self.paused then
        return
    end

    local pangain = dt * self.pangain

    if not dontupdatepos then
        if self.cutscene then
            self.currentpos.x = lerp(self.currentpos.x, self.targetpos.x + self.targetoffset.x, pangain)
            self.currentpos.y = lerp(self.currentpos.y, self.targetpos.y + self.targetoffset.y, pangain)
            self.currentpos.z = lerp(self.currentpos.z, self.targetpos.z + self.targetoffset.z, pangain)
        else
            if self.time_since_zoom ~= nil and not self.cutscene then
                self.time_since_zoom = self.time_since_zoom + dt
                if self.should_push_down and self.time_since_zoom > 1.0 then
                    self.distancetarget = (self.maxdist - self.mindist) * 0.6 + self.mindist
                end
            end

            if self.target ~= nil then
                if self.target.components.focalpoint then
                    self.target.components.focalpoint:CameraUpdate(dt)
                end
                local x, y, z = self.target.Transform:GetWorldPosition()
                self.targetpos.x = x + self.targetoffset.x
                self.targetpos.y = y + self.targetoffset.y
                self.targetpos.z = z + self.targetoffset.z
            else
                self.targetpos.x, self.targetpos.y, self.targetpos.z = self.targetoffset:Get()
            end

            self.currentpos.x = lerp(self.currentpos.x, self.targetpos.x, pangain)
            self.currentpos.y = lerp(self.currentpos.y, self.targetpos.y, pangain)
            self.currentpos.z = lerp(self.currentpos.z, self.targetpos.z, pangain)
        end
    end

    local screenxoffset = 0
    while #self.screenoffsetstack > 0 do
        if self.screenoffsetstack[1].ref.inst:IsValid() then
            screenxoffset = self.screenoffsetstack[1].xoffset
            break
        end
        table.remove(self.screenoffsetstack, 1)
    end
    if screenxoffset ~= 0 then
        self.currentscreenxoffset = lerp(self.currentscreenxoffset, screenxoffset, pangain)
    elseif self.currentscreenxoffset ~= 0 then
        self.currentscreenxoffset = lerp(self.currentscreenxoffset, 0, pangain)
        if math.abs(self.currentscreenxoffset) < .01 then
            self.currentscreenxoffset = 0
        end
    end

    if self.shake ~= nil then
        local shakeOffset = self.shake:Update(dt)
        if shakeOffset ~= nil then
            local rightOffset = self:GetRightVec() * shakeOffset.x
            self.currentpos.x = self.currentpos.x + rightOffset.x
            self.currentpos.y = self.currentpos.y + rightOffset.y + shakeOffset.y
            self.currentpos.z = self.currentpos.z + rightOffset.z
        else
            self.shake = nil
        end
    end

	if self.headingdelta then
		--continuous rotation (no 45 degree snapping) using camera control modifier + analog
		self.heading = normalize(self.heading + self.headingdelta)
		self.lastheadingdelta = self.headingdelta
		self.headingdelta = nil
	else
		local diffheading = math.abs(self.heading - self.headingtarget)
		if diffheading <= 0.01 or diffheading >= 359.99 then
			self.heading = self.headingtarget
			self.lastheadingdelta = nil
		else
			local newheading =
				normalize(lerp(
					self.heading,
					diffheading <= 180 and
					self.headingtarget or
					self.headingtarget + (self.heading > self.headingtarget and 360 or -360),
					dt * self.headinggain
				))

			if self.lastheadingdelta then
				--continous rotation stopped; finish lerping to headingtarget at our last speed

				--DiffAngle is [0, 180], whereas normalize is [0, 360]
				diffheading = DiffAngle(newheading, self.heading)
				if math.abs(self.lastheadingdelta) < diffheading then 
					self.heading = self.heading + self.lastheadingdelta
					local min = self.lastheadingdelta < 0 and -0.1 or 0.1
					self.lastheadingdelta = min * 0.1 + self.lastheadingdelta * 0.95
				else
					self.heading = newheading
					self.lastheadingdelta = nil
				end
			else
				--default 45 degree step camera rotation; i.e. fixed lerp speed
				self.heading = newheading
			end
		end
	end

	if math.abs(self.distance - self.distancetarget) <= 0.01 then
		self.distance = self.distancetarget
		self.lastzoomdelta = nil
	else
		--lerp much faster when doing continuous zoom (using camera control modifier + analog)
		self.distance = lerp(self.distance, self.distancetarget, dt * (self.lastzoomdelta and self.continuousdistancegain or self.distancegain))
	end

    self.pitch = lerp(self.mindistpitch, self.maxdistpitch, (self.distance - self.mindist) / (self.maxdist - self.mindist))

    self:onupdatefn(dt)
    self:Apply()
    self:UpdateListeners(dt)
end

function FollowCamera:UpdateListeners(dt)
    for src, cbs in pairs(self.updatelisteners) do
        for _, fn in ipairs(cbs) do
            fn(dt)
        end
    end

    if self.large_dist_update then
        for src, cbs in pairs(self.largeupdatelisteners) do
            for _, fn in ipairs(cbs) do
                fn(dt)
            end
        end
    end

    self.large_dist_update = false
end

function FollowCamera:SetOnUpdateFn(fn)
    self.onupdatefn = fn or dummyfn
end

--NOTES:
-- 'regular listener' every Update of FollowCamera
-- 'large update listener' every Update of FollowCamera if pos, dir or up had a delta dist sq of 4 from their last change

function FollowCamera:AddListener(src, cb)
    if self.updatelisteners[src] ~= nil then
        table.insert(self.updatelisteners[src], cb)
    else
        self.updatelisteners[src] = { cb }
    end
end

function FollowCamera:RemoveListener(src, cb)
    if self.updatelisteners[src] ~= nil then
        if cb ~= nil then
            table.removearrayvalue(self.updatelisteners[src], cb)
            if #self.updatelisteners[src] > 0 then
                return
            end
        end
        self.updatelisteners[src] = nil
    end
end

function FollowCamera:AddLargeUpdateListener(src, cb)
    if self.largeupdatelisteners[src] ~= nil then
        table.insert(self.largeupdatelisteners[src], cb)
    else
        self.largeupdatelisteners[src] = { cb }
    end
end

function FollowCamera:RemoveLargeUpdateListener(src, cb)
    if self.largeupdatelisteners[src] ~= nil then
        if cb ~= nil then
            table.removearrayvalue(self.largeupdatelisteners[src], cb)
            if #self.largeupdatelisteners[src] > 0 then
                return
            end
        end
        self.largeupdatelisteners[src] = nil
    end
end

return FollowCamera
