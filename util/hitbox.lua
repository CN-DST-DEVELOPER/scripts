--Local coords match Physics:
--  +X => front
--  -X => back
--  +Z => left
--  -Z => right

local HitBox = Class(function(self, owner)
	self.bounds_r = -1 --very rough oversized bounding box that fits for any rotation
	self.tris = nil
	self.circs = nil
	self.x, self.z = 0, 0
	self.rot = 0
	self.cos_theta = 1
	self.sin_theta = 0
	self.cached = nil
	self.colour = RGB(255, 127, 0)
	self.owner = owner
end)

local function _len(x, z)
	return math.sqrt(x * x + z * z)
end

function HitBox:AddTriangle(x1, z1, x2, z2, x3, z3)
	self.tris = self.tris or {}
	table.insert(self.tris, { x1 = x1, z1 = z1, x2 = x2, z2 = z2, x3 = x3, z3 = z3 })
	self.bounds_r = math.max(self.bounds_r, math.max(math.max(_len(x1, z1), _len(x2, z2)), _len(x3, z3)))
end

function HitBox:AddCircle(x, z, r)
	self.circs = self.circs or {}
	table.insert(self.circs, { x = x, z = z, r = r })
	self.bounds_r = math.max(self.bounds_r, _len(x, z) + r)
end

function HitBox:Reset()
	self.bounds_r = -1
	self.tris = nil
	self.circs = nil
	self.cached = nil
end

function HitBox:SetWorldXZ(x, z)
	if self.x ~= x or self.z ~= z then
		self.x, self.z = x, z
		self.cached = nil
	end
end

function HitBox:SetWorldRot(rot)
	if self.rot ~= rot then
		self.rot = rot
		self.cos_theta = nil
		self.sin_theta = nil
		self.cached = nil
	end
end

function HitBox:SetWorldTransformFromEntity(ent)
	local x, _, z = ent.Transform:GetWorldPosition()
	self:SetWorldXZ(x, z)
	self:SetWorldRot(ent.Transform:GetRotation())
end

function HitBox:SetOwner(owner)
	self.owner = owner
end

function HitBox:LocalToWorldXZ(x, z)
	if self.cos_theta == nil then
		local theta = self.rot * DEGREES
		self.cos_theta = math.cos(theta)
		self.sin_theta = math.sin(theta)
	end
	return self.x + x * self.cos_theta + z * self.sin_theta, self.z + z * self.cos_theta - x * self.sin_theta
end

function HitBox:LocalToWorldCirc_Internal(circ)
	local ret = self.cached and self.cached[circ]
	if ret == nil then
		ret = { r = circ.r }
		ret.x, ret.z = self:LocalToWorldXZ(circ.x, circ.z)
		if self.cached then
			self.cached[circ] = ret
		else
			self.cached = { [circ] = ret }
		end
	end
	return ret
end

function HitBox:LocalToWorldTri_Internal(tri)
	local ret = self.cached and self.cached[tri]
	if ret == nil then
		ret = {}
		ret.x1, ret.z1 = self:LocalToWorldXZ(tri.x1, tri.z1)
		ret.x2, ret.z2 = self:LocalToWorldXZ(tri.x2, tri.z2)
		ret.x3, ret.z3 = self:LocalToWorldXZ(tri.x3, tri.z3)
		if self.cached then
			self.cached[tri] = ret
		else
			self.cached = { [tri] = ret }
		end
	end
	return ret
end

function HitBox:CollidesWithTestFns(circ_test_fn, tri_test_fn)
	if self.bounds_r < 0 then
		return false
	end

	if self.owner then
		self:SetWorldTransformFromEntity(self.owner)
	end

	if self.circs then
		for _, v in ipairs(self.circs) do
			v = self:LocalToWorldCirc_Internal(v)
			if circ_test_fn(v.x, v.z, v.r) then
				return true
			end
		end
	end
	if self.tris then
		for _, v in ipairs(self.tris) do
			v = self:LocalToWorldTri_Internal(v)
			if tri_test_fn(v.x1, v.z1, v.x2, v.z2, v.x3, v.z3) then
				return true
			end
		end
	end
	return false
end

function HitBox:CollidesWithPoint(x, z)
	return self:CollidesWithTestFns(
		function(...) return math2d.IsPointInCircle(x, z, ...) end,
		function(...) return math2d.IsPointInTriangle(x, z, ...) end)
end

function HitBox:CollidesWithLine(x1, z1, x2, z2)
	return self:CollidesWithTestFns(
		function(...) return math2d.LineIntersectsCircle(x1, z1, x2, z2, ...) end,
		function(...) return math2d.LineIntersectsTriangle(x1, z1, x2, z2, ...) end)
end

function HitBox:CollidesWithCircle(x, z, r)
	return self:CollidesWithTestFns(
		function(...) return math2d.CircleIntersectsCircle(x, z, r, ...) end,
		function(x1, z1, x2, z2, x3, z3) return math2d.TriangleIntersectsCircle(x1, z1, x2, z2, x3, z3, x, z, r) end)
end

function HitBox:CollidesWithTriangle(x1, z1, x2, z2, x3, z3)
	return self.CollidesWithTestFns(
		function(...) return math2d.TriangleIntersectsCircle(x1, z1, x2, z2, x3, z3, ...) end,
		function(...) return math2d.TriangleIntersectsTriangle(x1, z1, x2, z2, x3, z3, ...) end)
end

function HitBox:CollidesWithHitBox(other)
	if self.bounds_r < 0 or other.bounds_r < 0 then
		return false
	end

	if self.owner then
		self:SetWorldTransformFromEntity(self.owner)
	end
	if other.owner then
		other:SetWorldTransformFromEntity(other.owner)
	end
	if not math2d.RectIntersectsRect(self.x - self.bounds_r, self.z - self.bounds_r, self.x + self.bounds_r, self.z + self.bounds_r, other.x - other.bounds_r, other.z - other.bounds_r, other.x + other.bounds_r, other.z + other.bounds_r) then
		return false
	end

	if self.circs then
		for _, v in ipairs(self.circs) do
			v = self:LocalToWorldCirc_Internal(v)
			if other.circs then
				for _, v1 in ipairs(other.circs) do
					v1 = other:LocalToWorldCirc_Internal(v1)
					if math2d.CircleIntersectsCircle(v.x, v.z, v.r, v1.x, v1.z, v1.r) then
						return true
					end
				end
			end
			if other.tris then
				for _, v1 in ipairs(other.tris) do
					v1 = other:LocalToWorldTri_Internal(v1)
					if math2d.TriangleIntersectsCircle(v1.x1, v1.z1, v1.x2, v1.z2, v1.x3, v1.z3, v.x, v.z, v.r) then
						return true
					end
				end
			end
		end
	end
	if self.tris then
		for _, v in ipairs(self.tris) do
			v = self:LocalToWorldTri_Internal(v)
			if other.circs then
				for _, v1 in ipairs(other.circs) do
					v1 = other:LocalToWorldCirc_Internal(v1)
					if math2d.TriangleIntersectsCircle(v.x1, v.z1, v.x2, v.z2, v.x3, v.z3, v1.x, v1.z, v1.r) then
						return true
					end
				end
			end
			if other.tris then
				for _, v1 in ipairs(other.tris) do
					v1 = other:LocalToWorldTri_Internal(v1)
					if math2d.TriangleIntersectsTriangle(v.x1, v.z1, v.x2, v.z2, v.x3, v.z3, v1.x1, v1.z1, v1.x2, v1.z2, v1.x3, v1.z3) then
						return true
					end
				end
			end
		end
	end
	return false
end

function HitBox:SetColour(r, g, b, a)
	self.colour[1], self.colour[2], self.colour[3], self.colour[4] = r, g, b, a or 1
end

function HitBox:DebugDraw()
	if self.owner == nil then
		return
	end

	if self.bounds_r < 0 then
		if self.owner.DebugRender then
			self.owner.DebugRender:Flush()
		end
		return
	end

	local debugrender = self.owner.DebugRender or self.owner.entity:AddDebugRender()
	debugrender:Flush()

	self:SetWorldTransformFromEntity(self.owner)

	if self.circs then
		for _, v in ipairs(self.circs) do
			v = self:LocalToWorldCirc_Internal(v)
			debugrender:Circle(v.x, v.z, v.r, unpack(self.colour))
		end
	end
	if self.tris then
		for _, v in ipairs(self.tris) do
			v = self:LocalToWorldTri_Internal(v)
			debugrender:Triangle(v.x1, v.z1, v.x2, v.z2, v.x3, v.z3, unpack(self.colour))
		end
	end
end

return HitBox
