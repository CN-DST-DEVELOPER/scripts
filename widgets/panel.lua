local Widget = require "widgets/widget"
--local UIHelpers = require "ui/uihelpers"

local assets =
{
	panel_bg = {atlas = "images/9slice", region = "roundbox.tex",30,30,70,70},
}


local Panel = Class( Widget, function(self, atlas, atlas_region, dw, dh, innerpw, innerph, name)
	Widget._ctor(self, name or "Panel")

	self.model = self.inst.entity:AddNineSlice()

	self.model:SetEffect("shaders/ui_ctransform.ksh")
	if innerpw and innerph then
		self.model:SetInteriorPercent(innerpw, innerph)
	end

	if atlas and atlas_region then
		self:SetTexture(atlas, atlas_region)
	else
		self:SetNineSlice(assets.panel_bg.atlas, assets.panel_bg.region)
	end

	if dw and dh then
		self:SetInnerSize(dw, dh)
	end
end)


function Panel:SetEffect(effect)
	self.model:SetEffect(effect)
end

function Panel:__tostring()
	if self.model then
		return string.format("Panel Widget (%2.2fx%2.2f)", self:GetSize())
	else
		return "Panel Widget (nil model)"
	end
end

function Panel:SetTexture(atlas, atlasregion)

	self.model:SetTexture(atlas, atlasregion)

	return self
end

function Panel:SetBloom(b)
	print("Not implemented: Panel:SetBloom")
	return self
end

function Panel:GetBoundingBox()
	return self.model:GetBoundingBox()
end

function Panel:ExpandToPoint( x, y )
	local w, h = self.model:GetInnerSize()
	local xmin = math.min( x, self.x - w/2 )
	local xmax = math.max( x, self.x + w/2 )
	local ymin = math.min( y, self.y - h/2 )
	local ymax = math.max( y, self.y + h/2 )
	if ymax > ymin then
		self:SetInnerSize( (xmax - xmin), (ymax - ymin) )
		self:SetPos( (xmin + xmax)/2, (ymin + ymax)/2 )
	end
end

-- Switch panel to Inner sizing mode and define its size to fit the input rect
-- the centre part of the panel. Good when outer areas of nine slice are
-- borders. See also SetSize.
function Panel:SetInnerSize(dw,dh)
	self.model:SetInnerSize(dw, dh)
	self:InvalidateBBox()
	return self
end

function Panel:GetInnerSize()
	return self.model:GetInnerSize()
end

function Panel:SetInnerUVs(minx, miny, maxx, maxy)
	-- print("Panel:SetInnerUVs()", minx, miny, maxx, maxy)
	self.model:SetInnerUVS(minx, miny, maxx, maxy)
	return self
end

-- really these pretty much always have to be set together
function Panel:SetNineSlice(asset)
	local tex, minx, miny, maxx, maxy = table.unpack(asset)
	local atlas, atlasregion = GetAtlasTex(tex)
	self.model:SetTexture(atlas, atlasregion)
	self:SetNineSliceCoords(minx, miny, maxx, maxy)
	self:InvalidateBBox()
	return self
end


-- ▼ in pixels from top left
-- ┌───┬─────────────┬───┐
-- │   │             │   │
-- ├───┼─────────────┼───┤
-- │   minx,miny     │   │
-- │   │             │   │
-- │   │             │   │
-- │   │             │   │
-- │   │     maxx,maxy   │
-- ├───┼─────────────┼───┤
-- │   │             │   │
-- └───┴─────────────┴───┘
function Panel:SetNineSliceCoords(minx, miny, maxx, maxy)
	local tx, ty = self.model:GetTextureSize()
	local uvminx = minx/tx
	local uvminy = miny/ty
	local uvmaxx = maxx/tx
	local uvmaxy = maxy/ty
	self:SetInnerUVs(uvminx, uvminy, uvmaxx, uvmaxy)
	return self
end

-- scale = 1 by default.
function Panel:SetNineSliceBorderScale(scale)
	self.model:SetBorderScale(scale)
	return self
end

function Panel:SetMask()
	self.model:SetColorWrite(false)
	self.model:SetEffect(global_shaders.UI_MASK)
	self:SetStencilWrite(STENCIL_MODES.SET)
	return self
end

function Panel:SetInnerPercents(dw,dh)
	self.model:SetInteriorPercent(dw, dh)
	return self
end

-- Switch panel to Outer sizing mode and define its size so the outer bounds
-- match the input rect. Good for fitting against other widgets. See also
-- SetInnerSize.
function Panel:SetSize(w, h)
	local current_w, current_h = self:GetSize()

	w = w or current_w
	h = h or current_h

	self.model:SetSize(w, h)

	return self
end

function Panel:Expand( dw, dh )
	local w, h = self:GetSize()
	self:SetSize( w + (dw or 0), h + (dh or 0) )
	return self
end

function Panel:GetSize()
	return self.model:GetOuterSize()
end

function Panel:GetBorderSize()
	return self.model:GetBorderSize()
end

function Panel:ApplyMultColour(r,g,b,a)
	self.tint = type(r) == "number" and { r, g, b, a } or r
	self.model:SetMultColour(unpack(self.tint))
	return self
end

function Panel:ApplyAddColour(r,g,b,a)
	self.addcolor = type(r) == "number" and { r, g, b, a } or r
	self.model:SetAddColour(unpack(self.addcolor))
	return self
end

function Panel:ApplyHue(hue)
	self.model:SetHue(hue)
	return self
end

function Panel:ApplyBrightness(brightness)
	self.model:SetBrightness(brightness)
	return self
end

function Panel:ApplySaturation(saturation)
	self.model:SetSaturation(saturation)
	return self
end

function Panel:SetMultColour(r,g,b,a)
	self:ApplyMultColour(r,g,b,a)
end

function Panel:SetTint(r,g,b,a)
	self:SetMultColour(r,g,b,a)
end

function Panel:SetAddColour(r,b,b,a)
	self:ApplyAddColour(r,g,b,a)
end

function Panel:SetBrightness(brightness)
	self:ApplyBrightness(brightness)
end

function Panel:SetSaturation(saturation)
	self:ApplySaturation(saturation)
end

return Panel
