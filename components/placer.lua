require("components/deployhelper")

local Placer = Class(function(self, inst)
    self.inst = inst

    self.can_build = false
    self.mouse_blocked = nil
    self.testfn = nil
    self.radius = 1
    self.selected_pos = nil
    self.onupdatetransform = nil
    self.oncanbuild = nil
    self.oncannotbuild = nil
    self.onfailedplacement = nil
    self.axisalignedplacement = false
    self.axisalignedplacementtoggle = false
    self.axisalignedhelpers = nil
    self.linked = {}
    self.offset = 1

	self.hide_inv_icon = true

    self.override_build_point_fn = nil
    self.override_testfn = nil

    self.BOAT_MUST_TAGS = { "boat" } --probably don't want static, but still cached per placer at least
end)

function Placer:OnRemoveEntity()
    if self.builder ~= nil and self.hide_inv_icon then
        self.builder:PushEvent("onplacerhidden")
    end
    if self.axisalignedhelpers then
        if self.axisalignedhelpers.parent:IsValid() then
            self.axisalignedhelpers.parent:Remove()
        end
        self.axisalignedhelpers = nil
    end
end

Placer.OnRemoveFromEntity = Placer.OnRemoveEntity

local function Sort_SmallestRadiusFirst(a, b)
    if a.percenttoradius ~= b.percenttoradius then
        return a.percenttoradius < b.percenttoradius
    end

    if a.dx ~= b.dx then
        return a.dx < b.dx
    end

    return a.dz < b.dz
end
local goodscales = { -- Always ascending scale values.
    {scale = 0.5, anim = "halfunit"},
    {scale = 1.0, anim = "unit"},
    {scale = 2.0, anim = "doubleunit"},
    {scale = 4.0, anim = "tileunit"},
}
local function GetNearestAnimationAndFactorForScale(scale) -- NOTES(JBK): This is mainly for mods that adjust interval counts to get a best fit animation.
    local gooddiff
    local gooddata
    for _, data in ipairs(goodscales) do
        local diff = math.abs(scale - data.scale)
        if gooddiff == nil or diff < gooddiff then
            gooddiff = diff
            gooddata = data
        else
            break
        end
    end
    local anim = gooddata.anim
    local animscale = scale / gooddata.scale
    return anim, animscale
end
local function CreateFloorDecal(anim, animscale)
    local inst = SpawnPrefab("axisalignedplacement_outline")
    inst.floordecalanim = anim
    inst.floordecalanim_bad = anim .. "_x"
    inst.AnimState:PlayAnimation(anim)
    inst.AnimState:SetScale(animscale, animscale)
    inst.AnimState:SetMultColour(0, 0, 0, 0)
    return inst
end
local function CreateOffsetCache(intervals, totalradius)
    -- NOTES(JBK): This could be optimized to be more efficient than a circle allow pass in a square and then a sort.
    local cache = {}
    local grid = {}
    local scale = 1 / intervals
    local anim, animscale = GetNearestAnimationAndFactorForScale(scale)
    local r = math.floor(totalradius * intervals)
    local rsq = r * r
    local parent = CreateFloorDecal(anim, animscale)
    local parentvisual = CreateFloorDecal(anim, animscale)
    parentvisual.entity:SetParent(parent.entity)
    local parentvisualv = {dx = 0, dz = 0, percenttoradius = 0.0001, ent = parentvisual,}
    table.insert(cache, parentvisualv)
    for dx = -r, r do
        local grid_inner = grid[dx]
        if not grid_inner then
            grid_inner = {}
            grid[dx] = grid_inner
        end
        for dz = -r, r do
            local testrsq = dx * dx + dz * dz
            if testrsq <= rsq and testrsq > 0 then
                local pdx, pdz = dx * scale, dz * scale
                local ent = CreateFloorDecal(anim, animscale)
                ent.entity:SetParent(parent.entity)
                ent.Transform:SetPosition(pdx, 0, pdz)
                local percenttoradius = math.sqrt(testrsq) * scale / totalradius
                local v = {dx = pdx, dz = pdz, percenttoradius = percenttoradius, ent = ent,}
                table.insert(cache, v)
                grid_inner[dz] = v
            end
        end
    end
    grid[0][0] = parentvisualv
    table.sort(cache, Sort_SmallestRadiusFirst)
    cache.cache = cache
    cache.total = #cache
    cache.grid = grid
    cache.gridradius = r
    cache.intervals = intervals
    cache.parent = parent
    cache.visible = false
    cache.visiblity = 0
    cache.updateaccumulator = 0
    cache.updateindex = 1
    local offsetx, offsety, offsetz = TheWorld.Map:GetTileCenterPoint(0, 0, 0)
    cache.worldoffsetx = offsetx + TILE_SCALE * 0.5
    cache.worldoffsetz = offsetz + TILE_SCALE * 0.5
    return cache
end

function Placer:InitializeAxisAlignedHelpers() -- Should only be called from ThePlayer source.
    if self.axisalignedhelpers then
        if self.axisalignedhelpers.parent:IsValid() then
            self.axisalignedhelpers.parent:Remove()
        end
        self.axisalignedhelpers = nil
    end

    self.axisalignedhelpers = CreateOffsetCache(TUNING.AXISALIGNEDPLACEMENT_INTERVALS, TUNING.AXISALIGNEDPLACEMENT_CIRCLESIZE)
    self.axisalignedhelpers.parent:ListenForEvent("refreshaxisalignedplacementintervals", function()
        self:InitializeAxisAlignedHelpers()
    end, ThePlayer)
end

function Placer:CanStartAxisAlignedPlacementForItem(item)
    if HAS_AXISALIGNED_MOD_ENABLED == nil then
        for _, modname in ipairs(KNOWN_AXISALIGNED_MODS) do
            local enabled = KnownModIndex:IsModEnabled(modname)
            if enabled then
                HAS_AXISALIGNED_MOD_ENABLED = true
                return false
            end
        end
        HAS_AXISALIGNED_MOD_ENABLED = false
    end
    if HAS_AXISALIGNED_MOD_ENABLED then
        return false
    end

    if item == nil then
        return true -- Not an item but a structure so yes.
    end

    local inventoryitem = item.replica.inventoryitem
    local deploymode = inventoryitem and inventoryitem:GetDeployMode() or DEPLOYMODE.NONE
    if deploymode == DEPLOYMODE.NONE or
        deploymode == DEPLOYMODE.TURF or
        deploymode == DEPLOYMODE.WALL
    then
        return false
    end

    if not inventoryitem:IsDeployable(self.builder) then
        return false
    end

    if item:HasAnyTag("tile_deploy", "groundtile", "boatbuilder") then
        return false
    end

    return true
end

function Placer:SetBuilder(builder, recipe, invobject)
    self.builder = builder
    self.recipe = recipe
    self.invobject = invobject
    if self.builder and self.builder == ThePlayer then
        self.axisalignedplacementallowedbyitem = self:CanStartAxisAlignedPlacementForItem(self.invobject)
        self.axisalignedplacement = self.axisalignedplacementallowedbyitem and Profile:GetAxisAlignedPlacement() or false
        if self.axisalignedplacement or not TheInput:ControllerAttached() then
            self:InitializeAxisAlignedHelpers()
        end
    end

    if self.onbuilderset then
        self.onbuilderset(self.inst)
    end

    self.inst:StartWallUpdatingComponent(self)
end

function Placer:LinkEntity(ent, lightoverride)
    table.insert(self.linked, ent)
	if lightoverride == nil or lightoverride > 0 then
		ent.AnimState:SetLightOverride(lightoverride or 1)
	end
end

function Placer:GetDeployAction()
    if self.invobject ~= nil then
        self.selected_pos = self.inst:GetPosition()
		local action = ACTIONS.DEPLOY
		if self.invobject:HasTag("boatbuilder") then
			local inventory = ThePlayer and ThePlayer.replica.inventory
			if inventory and inventory:IsFloaterHeld() then
				action = ACTIONS.DEPLOY_FLOATING
			end
		end
		action = BufferedAction(self.builder, nil, action, self.invobject, self.selected_pos, nil, nil, nil, self.inst.Transform:GetRotation())
        table.insert(action.onsuccess, function() self.selected_pos = nil end)
        return action
    end
end

function Placer:TestCanBuild() -- NOTES(JBK): This component assumes the self.inst is at the location to test.
    local can_build, mouse_blocked
    if self.override_testfn ~= nil then
        can_build, mouse_blocked = self.override_testfn(self.inst)
    elseif self.testfn ~= nil then
        can_build, mouse_blocked = self.testfn(self.inst:GetPosition(), self.inst:GetRotation())
    else
        can_build = true
        mouse_blocked = false
    end
    return can_build, mouse_blocked
end

function Placer:ToggleHideInvIcon(hide)
	if hide then
		if not self.hide_inv_icon then
			self.hide_inv_icon = true
			if self.builder and not self.mouse_blocked then
				self.builder:PushEvent("onplacershown")
			end
		end
	elseif self.hide_inv_icon then
		self.hide_inv_icon = false
		if self.builder and not self.mouse_blocked then
			self.builder:PushEvent("onplacerhidden") --this event is what makes the icon show again
		end
	end
end

function Placer:IsAxisAlignedPlacement()
    return self.axisalignedplacement ~= self.axisalignedplacementtoggle
end

function Placer:GetAxisAlignedPlacementTransform(x, y, z, ignorescale)
    local intervals = self.axisalignedhelpers.intervals
    local worldoffsetx = self.axisalignedhelpers.worldoffsetx
    local worldoffsetz = self.axisalignedhelpers.worldoffsetz
    x, z = math.floor((x - worldoffsetx) * intervals) + 0.5, math.floor((z - worldoffsetx) * intervals) + 0.5
    if not ignorescale then
        x, z = x / intervals, z / intervals
    end
    return x + worldoffsetx, y, z + worldoffsetx
end

local function UpdateAxisAlignedHelper(self, v, newvisibility)
    local intensity = newvisibility >= v.percenttoradius and 1 or 0
    local r, g
    local addr, addg
    if v.canbuild then
        r, g = 0, 1
        addr, addg = 0.25, 0.75
        v.ent.AnimState:PlayAnimation(v.ent.floordecalanim)
    elseif v.canbuild == nil then
        r, g = 0, 0
        addr, addg = 0.25, 0.25
        v.ent.AnimState:PlayAnimation(v.ent.floordecalanim_bad)
    else
        r, g = 1, 0
        addr, addg = 0.75, 0.25
        v.ent.AnimState:PlayAnimation(v.ent.floordecalanim_bad)
    end
    v.ent.AnimState:SetMultColour(r, g, 0, intensity)
    v.ent.AnimState:SetAddColour(addr, addg, 0, 0)
end
local function UpdateCanBuild(self, v, x, y, z)
    self.inst.Transform:SetPosition(x + v.dx, y, z + v.dz)
    local can_build, mouse_blocked = self:TestCanBuild()
    v.canbuild = can_build
end
function Placer:UpdateAxisAlignedHelpers(dt)
    local px, py, pz = self.inst.Transform:GetWorldPosition()
    local oldvisibility = self.axisalignedhelpers.visiblity
    local newvisibility = oldvisibility
    if self.axisalignedhelpers.visible then
        local needstocheckthese = {}
        -- First update its position if it can.
        local oldx, oldy, oldz = self.axisalignedhelpers.parent.Transform:GetWorldPosition()
        if oldx ~= px or oldz ~= pz then
            local scale = self.axisalignedhelpers.intervals
            local dx, dy, dz = self:GetAxisAlignedPlacementTransform(px - oldx, 0, pz - oldz, true)
            self.axisalignedhelpers.parent.Transform:SetPosition(px, py, pz)
            -- We moved so slide known collision tests if they are available otherwise clear their collision test.
            local grid = self.axisalignedhelpers.grid
            local r = self.axisalignedhelpers.gridradius
            -- We should iterate over the grid in a safe copy direction since we are doing it in place.
            local xmin, xmax, xiter, zmin, zmax, ziter
            if dx > 0 then
                xmin, xmax, xiter = -r, r, 1
            else
                xmin, xmax, xiter = r, -r, -1
            end
            if dz > 0 then
                zmin, zmax, ziter = -r, r, 1
            else
                zmin, zmax, ziter = r, -r, -1
            end
            -- Then copy in place over the sections and recalculate for missing data.
            for x = xmin, xmax, xiter do
                local grid_inner = grid[x]
                for z = zmin, zmax, ziter do
                    local v = grid_inner[z]
                    if v then
                        local rx, rz = x + dx, z + dz
                        local readv = grid[rx] and grid[rx][rz] or nil
                        if readv then
                            v.canbuild = readv.canbuild
                            UpdateAxisAlignedHelper(self, v, newvisibility)
                        else
                            needstocheckthese[v] = true
                        end
                    end
                end
            end
        end
        -- Then handle any visuals.
        if oldvisibility < 1 then
            newvisibility = math.min(oldvisibility + (dt / TUNING.AXISALIGNEDPLACEMENT_HELPERS_TIMETOSHOW), 1)
            self.axisalignedhelpers.visiblity = newvisibility
            for _, v in ipairs(self.axisalignedhelpers.cache) do
                if oldvisibility <= v.percenttoradius then
                    if v.percenttoradius <= newvisibility then
                        -- These ones are now showing so calculate out their collision tests.
                        needstocheckthese[v] = true
                    else
                        break
                    end
                end
            end
        end
        self.axisalignedhelpers.updateaccumulator = self.axisalignedhelpers.updateaccumulator + dt
        if self.axisalignedhelpers.updateaccumulator >= TUNING.AXISALIGNEDPLACEMENT_HELPERS_UPDATEPERIOD then
            self.axisalignedhelpers.updateaccumulator = 0
            local cache = self.axisalignedhelpers.cache
            local updateindex = self.axisalignedhelpers.updateindex
            local total = self.axisalignedhelpers.total
            for i = 1, math.min(TUNING.AXISALIGNEDPLACEMENT_HELPERS_UPDATEAMOUNT, total) do
                local v = cache[updateindex]
                needstocheckthese[v] = true
                updateindex = updateindex + 1
                if updateindex > total then
                    updateindex = 1
                end
            end
            self.axisalignedhelpers.updateindex = updateindex
        end
        if next(needstocheckthese) then
            for v, _ in pairs(needstocheckthese) do
                UpdateCanBuild(self, v, px, py, pz)
                UpdateAxisAlignedHelper(self, v, newvisibility)
            end
            self.inst.Transform:SetPosition(px, py, pz)
        end
    else
        if oldvisibility > 0 then
            newvisibility = math.max(oldvisibility - (dt / TUNING.AXISALIGNEDPLACEMENT_HELPERS_TIMETOHIDE), 0)
            self.axisalignedhelpers.visiblity = newvisibility
            for _, v in ipairs(self.axisalignedhelpers.cache) do
                if newvisibility <= v.percenttoradius then
                    if v.percenttoradius <= oldvisibility then
                        UpdateAxisAlignedHelper(self, v, newvisibility)
                    else
                        break
                    end
                end
            end
        end
        self.axisalignedhelpers.updateaccumulator = 0
        self.axisalignedhelpers.updateindex = 1
    end
end

function Placer:OnUpdate(dt)
    local rotating_from_boat_center
    local hide_if_cannot_build

    local axisalignedhelpers_visible = false
    self.axisalignedplacementtoggle = false
    if ThePlayer == nil then
        return
    elseif not TheInput:ControllerAttached() then
        local pt = self.selected_pos or TheInput:GetWorldPosition()
        if self.snap_to_tile then
            self.inst.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(pt:Get()))
        elseif self.snap_to_meters then
            self.inst.Transform:SetPosition(math.floor(pt.x) + .5, 0, math.floor(pt.z) + .5)
		elseif self.snaptogrid then
			self.inst.Transform:SetPosition(math.floor(pt.x + .5), 0, math.floor(pt.z + .5))
        elseif self.snap_to_boat_edge then
            local boats = TheSim:FindEntities(pt.x, 0, pt.z, TUNING.MAX_WALKABLE_PLATFORM_RADIUS, self.BOAT_MUST_TAGS)
            local boat = GetClosest(self.inst, boats)

            if boat then
                SnapToBoatEdge(self.inst, boat, pt)
                if self.inst:GetDistanceSqToPoint(pt) > 1 then
                    hide_if_cannot_build = true
                end
            else
                self.inst.Transform:SetPosition(pt:Get())
                hide_if_cannot_build = true
            end
        else
            self.axisalignedplacementtoggle = self.axisalignedplacementallowedbyitem and TheInput:IsControlPressed(CONTROL_AXISALIGNEDPLACEMENT_TOGGLEMOD)
            if self:IsAxisAlignedPlacement() then
                axisalignedhelpers_visible = true
                self.inst.Transform:SetPosition(self:GetAxisAlignedPlacementTransform(pt.x, 0, pt.z))
            else
                self.inst.Transform:SetPosition(pt:Get())
            end
        end

        -- Set the placer's rotation to point away from the boat's center point
        if self.rotate_from_boat_center then
            local boat = TheWorld.Map:GetPlatformAtPoint(pt.x, pt.z)
            if boat ~= nil then
                local angle = GetAngleFromBoat(boat, pt.x, pt.z) / DEGREES
                self.inst.Transform:SetRotation(-angle)
                rotating_from_boat_center = true
            end
        end
    elseif self.snap_to_tile then
        --Using an offset in this causes a bug in the terraformer functionality while using a controller.
        self.inst.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(ThePlayer.entity:LocalToWorldSpace(0, 0, 0)))
    elseif self.snap_to_meters then
        local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
        self.inst.Transform:SetPosition(math.floor(x) + .5, 0, math.floor(z) + .5)
	elseif self.snaptogrid then
		local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
		self.inst.Transform:SetPosition(math.floor(x + .5), 0, math.floor(z + .5))
    elseif self.snap_to_boat_edge then
        local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
        local boat = ThePlayer:GetCurrentPlatform()
        if boat and boat:HasTag("boat") then
            SnapToBoatEdge(self.inst, boat, Vector3(x, 0, z))
        else
            self.inst.Transform:SetPosition(x, 0, z)
        end
    elseif self.onground then
        --V2C: this will keep ground orientation accurate and smooth,
        --     but unfortunately position will be choppy compared to parenting
        --V2C: switched to WallUpdate, so should be smooth now
        local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
        if self:IsAxisAlignedPlacement() then
            axisalignedhelpers_visible = true
            self.inst.Transform:SetPosition(self:GetAxisAlignedPlacementTransform(x, y, z))
        else
            self.inst.Transform:SetPosition(x, y, z)
            if self.controllergroundoverridefn then
                self.controllergroundoverridefn(self, ThePlayer, x, y, z)
            end
        end
    elseif self.inst.parent == nil then
--        ThePlayer:AddChild(self.inst)
--        self.inst.Transform:SetPosition(self.offset, 0, 0) -- this will cause the object to be rotated to face the same direction as the player, which is not what we want, rotate the camera if you want to rotate the object
        local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
        if self:IsAxisAlignedPlacement() then
            axisalignedhelpers_visible = true
            self.inst.Transform:SetPosition(self:GetAxisAlignedPlacementTransform(x, y, z))
        else
            self.inst.Transform:SetPosition(x, y, z)
        end

        -- Set the placer's rotation to point away from the boat's center point
        if self.rotate_from_boat_center then
            local boat = TheWorld.Map:GetPlatformAtPoint(x, z)
            if boat ~= nil then
                local angle = GetAngleFromBoat(boat, x, z) / DEGREES
                self.inst.Transform:SetRotation(-angle)
                rotating_from_boat_center = true
            end
        end
    end

    if self.fixedcameraoffset ~= nil and not rotating_from_boat_center then
        local rot = self.fixedcameraoffset - TheCamera:GetHeading() -- rotate against the camera
        local offset = self.rotationoffset ~= nil and self.rotationoffset or 0
        self.inst.Transform:SetRotation(rot + offset)
    end

    if self.onupdatetransform ~= nil then
        self.onupdatetransform(self.inst)
    end

	local was_mouse_blocked = self.mouse_blocked

    self.can_build, self.mouse_blocked = self:TestCanBuild()

    if hide_if_cannot_build and not self.can_build then
        self.mouse_blocked = true
    end

    if self.builder ~= nil and was_mouse_blocked ~= self.mouse_blocked and self.hide_inv_icon then
		self.builder:PushEvent(self.mouse_blocked and "onplacerhidden" or "onplacershown")
	end

	local x, y, z = self.inst.Transform:GetWorldPosition()
    TriggerDeployHelpers(x, y, z, 64, self.recipe, self.inst)

    if self.can_build then
        if self.oncanbuild ~= nil then
            self.oncanbuild(self.inst, self.mouse_blocked)
            return
        end

        if self.mouse_blocked then
            self.inst:Hide()
            for _, v in ipairs(self.linked) do
                v:Hide()
            end
        else
            self.inst.AnimState:SetAddColour(.25, .75, .25, 0)
            self.inst:Show()
            for _, v in ipairs(self.linked) do
                v.AnimState:SetAddColour(.25, .75, .25, 0)
                v:Show()
            end
        end
    else
        if self.oncannotbuild ~= nil then
            self.oncannotbuild(self.inst, self.mouse_blocked)
            return
        end

        if self.mouse_blocked then
            self.inst:Hide()
            for _, v in ipairs(self.linked) do
                v:Hide()
            end
        else
            self.inst.AnimState:SetAddColour(.75, .25, .25, 0)
            self.inst:Show()
            for _, v in ipairs(self.linked) do
                v.AnimState:SetAddColour(.75, .25, .25, 0)
                v:Show()
            end
        end
    end

    if self.axisalignedhelpers then
        self.axisalignedhelpers.visible = axisalignedhelpers_visible
        self:UpdateAxisAlignedHelpers(dt)
    end
end

--V2C: support old mods that were overwriting OnUpdate
function Placer:OnWallUpdate(dt)
    self:OnUpdate(dt)
end

return Placer
