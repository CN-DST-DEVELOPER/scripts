--math2d
--V2C: -use for hitbox detection etc.
--     -touching counts as intersecting
--     -fully inside counts as intersecting
--     -intersection tests use no sqrt, trig, or division

local function DistSq(Ax, Ay, Bx, By)
	local ABx, ABy = Bx - Ax, By - Ay
	return ABx * ABx + ABy * ABy
end

local function DistSqPointToLine(Px, Py, Ax, Ay, Bx, By)
	local ABx, ABy = Bx - Ax, By - Ay
	local APx, APy = Px - Ax, Py - Ay
	local dotABP = ABx * APx + ABy * APy
	if dotABP <= 0 then
		return APx * APx + APy * APy
	end
	local lensqAB = ABx * ABx + ABy * ABy
	if dotABP >= lensqAB then
		return DistSq(Px, Py, Bx, By)
	end
	local sideABP = APx * ABy - APy * ABx
	--local dist = math.abs(sideABP) / lensqAB * math.sqrt(lensqAB)
	return sideABP * sideABP / lensqAB
end

local function IsPointOnLine(Px, Py, Ax, Ay, Bx, By)
	local ABx, ABy = Bx - Ax, By - Ay
	local APx, APy = Px - Ax, Py - Ay
	if APx * ABy - APy * ABx ~= 0 then
		return false
	elseif Ax == Bx and Ay == By then
		return Px == Ax and Py == Ay
	end

	local dotABP = ABx * APx + ABy * APy
	return dotABP >= 0 and dotABP <= ABx * ABx + ABy * ABy
end

local function IsPointInCircle(Px, Py, Cx, Cy, Cr)
	local CPx, CPy = Px - Cx, Py - Cy
	return CPx * CPx + CPy * CPy <= Cr * Cr
end

--Assumes only calling this if they are in a line
local function _triangle_to_line(Ax, Ay, Bx, By, Cx, Cy)
	local minx, miny = Ax, Ay
	local maxx, maxy = Cx, Cy
	if Ax ~= Bx or Ax ~= Cx then
		if Bx < minx then minx, miny = Bx, By end
		if Cx < minx then minx, miny = Cx, Cy end
		if Bx > maxx then maxx, maxy = Bx, By end
		if Ax > maxx then maxx, maxy = Ax, Ay end
	else
		if By < miny then minx, miny = Bx, By end
		if Cy < miny then minx, miny = Cx, Cy end
		if By > maxy then maxx, maxy = Bx, By end
		if Ay > maxy then maxx, maxy = Ax, Ay end
	end
	return minx, miny, maxx, maxy
end

local function IsPointInTriangle(Px, Py, Ax, Ay, Bx, By, Cx, Cy)
	local ABx, ABy = Bx - Ax, By - Ay
	local ACx, ACy = Cx - Ax, Cy - Ay
	local sideABC = ACx * ABy - ACy * ABx
	if sideABC == 0 then
		Ax, Ay, Bx, By = _triangle_to_line(Ax, Ay, Bx, By, Cx, Cy)
		return IsPointOnLine(Px, Py, Ax, Ay, Bx, By)
	end

	--P must be on the same side of all sides of the triangle.
	local APx, APy = Px - Ax, Py - Ay
	local BCx, BCy = Cx - Bx, Cy - By
	local BPx, BPy = Px - Bx, Py - By
	--local sideABP = APx * ABy - APy * ABx
	--local sideBCP = BPx * BCy - BPy * BCx
	--local sideCAP = APy * ACx - APx * ACy
	if sideABC > 0 then
		--return sideABP >= 0 and sideBCP >= 0 and sideCAP >= 0
		return APx * ABy - APy * ABx >= 0
			and BPx * BCy - BPy * BCx >= 0
			and APy * ACx - APx * ACy >= 0
	end
	--return sideABP <= 0 and sideBCP <= 0 and sideCAP <= 0
	return APx * ABy - APy * ABx <= 0
		and BPx * BCy - BPy * BCx <= 0
		and APy * ACx - APx * ACy <= 0
end

local function LineIntersectsLine(Ax, Ay, Bx, By, Cx, Cy, Dx, Dy)
	--Points of one line must be different sides of the other line.
	local ABx, ABy = Bx - Ax, By - Ay
	local ACx, ACy = Cx - Ax, Cy - Ay
	local ADx, ADy = Dx - Ax, Dy - Ay
	local sideABC = ACx * ABy - ACy * ABx
	local sideABD = ADx * ABy - ADy * ABx
	if (sideABC > 0) == (sideABD > 0) and sideABC ~= 0 and sideABD ~= 0 then
		return false
	end
	local CDx, CDy = Dx - Cx, Dy - Cy
	local CBx, CBy = Bx - Cx, By - Cy
	local sideCDA = ACy * CDx - ACx * CDy
	local sideCDB = CBx * CDy - CBy * CDx
	return (sideCDA > 0) == (sideCDB < 0) or sideCDA == 0 or sideCDB == 0
end

local function LineIntersectsCircle(Ax, Ay, Bx, By, Cx, Cy, Cr)
	local ABx, ABy = Bx - Ax, By - Ay
	local ACx, ACy = Cx - Ax, Cy - Ay

	local dotABC = ABx * ACx + ABy * ACy
	if dotABC <= 0 then
		--return IsPointInCircle(Ax, Ay, Cx, Cy, Cr)
		return ACx * ACx + ACy * ACy <= Cr * Cr
	end

	local lensqAB = ABx * ABx + ABy * ABy
	if dotABC >= lensqAB then
		return IsPointInCircle(Bx, By, Cx, Cy, Cr)
	end

	local sideABC = ACx * ABy - ACy * ABx
	--return math.abs(sideABC) / lensqAB * math.sqrt(lensqAB) <= Cr
	return sideABC * sideABC <= Cr * Cr * lensqAB
end

local function LineIntersectsTriangle(Ax, Ay, Bx, By, Dx, Dy, Ex, Ey, Fx, Fy)
	local DEx, DEy = Ex - Dx, Ey - Dy
	local DFx, DFy = Fx - Dx, Fy - Dy
	local sideDEF = DFx * DEy - DFy * DEx
	if sideDEF == 0 then
		Dx, Dy, Ex, Ey = _triangle_to_line(Dx, Dy, Ex, Ey, Fx, Fy)
		return LineIntersectsLine(Ax, Ay, Bx, By, Dx, Dy, Ex, Ey)
	end

	local ABx, ABy = Bx - Ax, By - Ay
	local ADx, ADy = Dx - Ax, Dy - Ay
	local AEx, AEy = Ex - Ax, Ey - Ay
	local AFx, AFy = Fx - Ax, Fy - Ay
	local sideABD = ADx * ABy - ADy * ABx
	local sideABE = AEx * ABy - AEy * ABx
	local sideABF = AFx * ABy - AFy * ABx

	--All points of triangle on same side of line
	if (sideABD > 0 and sideABE > 0 and sideABF > 0) or (sideABD < 0 and sideABE < 0 and sideABF < 0) then
		return false
	end

	--[[--Line and F on different sides of DE
	local DBx, DBy = Bx - Dx, By - Dy
	local sideDEA = ADy * DEx - ADx * DEy
	local sideDEB = DBx * DEy - DBy * DEx
	if sideDEF > 0 then
		if sideDEA < 0 and sideDEB < 0 then
			return false
		end
	elseif sideDEA > 0 and sideDEB > 0 then
		return false
	end

	--Line and D on different sides of EF
	local EFx, EFy = Fx - Ex, Fy - Ey
	local EBx, EBy = Bx - Ex, By - Ey
	local sideEFA = AEy * EFx - AEx * EFy
	local sideEFB = EBx * EFy - EBy * EFx
	if sideDEF > 0 then
		if sideEFA < 0 and sideEFB < 0 then
			return false
		end
	elseif sideEFA > 0 and sideEFB > 0 then
		return false
	end

	--Line and E on different sides of FD
	local sideFDA = AFx * DFy - AFy * DFx
	local sideFDB = DBy * DFx - DBx * DFy
	if sideDEF > 0 then
		if sideFDA < 0 and sideFDB < 0 then
			return false
		end
	elseif sideFDA > 0 and sideFDB > 0 then
		return false
	end

	return true]]

	local DBx, DBy = Bx - Dx, By - Dy
	local EFx, EFy = Fx - Ex, Fy - Ey
	--local EBx, EBy = Bx - Ex, By - Ey
	if sideDEF > 0 then
		return (ADy * DEx - ADx * DEy >= 0 or DBx * DEy - DBy * DEx >= 0)
			and (AEy * EFx - AEx * EFy >= 0 or (Bx - Ex) * EFy + (Ey - By) * EFx >= 0)
			and (AFx * DFy - AFy * DFx >= 0 or DBy * DFx - DBx * DFy >= 0)
	end
	return (ADy * DEx - ADx * DEy <= 0 or DBx * DEy - DBy * DEx <= 0)
		and (AEy * EFx - AEx * EFy <= 0 or (Bx - Ex) * EFy + (Ey - By) * EFx <= 0)
		and (AFx * DFy - AFy * DFx <= 0 or DBy * DFx - DBx * DFy <= 0)
end

local function CircleIntersectsCircle(Ax, Ay, Ar, Bx, By, Br)
	local ABx, ABy = Bx - Ax, By - Ay
	local r = Ar + Br
	return ABx * ABx + ABy * ABy <= r * r
end

local function TriangleIntersectsCircle(Ax, Ay, Bx, By, Cx, Cy, Ex, Ey, Er)
	local ABx, ABy = Bx - Ax, By - Ay
	local ACx, ACy = Cx - Ax, Cy - Ay
	local sideABC = ACx * ABy - ACy * ABx
	if sideABC == 0 then
		Ax, Ay, Bx, By = _triangle_to_line(Ax, Ay, Bx, By, Cx, Cy)
		return LineIntersectsCircle(Ax, Ay, Bx, By, Ex, Ey, Er)
	end

	local AEx, AEy = Ex - Ax, Ey - Ay
	local BEx, BEy = Ex - Bx, Ey - By
	local CEx, CEy = Ex - Cx, Ey - Cy
	local rsq = Er * Er

	--Any triangle vertex inside circle
	if AEx * AEx + AEy * AEy <= rsq or
		BEx * BEx + BEy * BEy <= rsq or
		CEx * CEx + CEy * CEy <= rsq
	then
		return true
	end

	--Circle inside triangle
	local BCx, BCy = Cx - Bx, Cy - By
	local sideABE = AEx * ABy - AEy * ABx
	local sideBCE = BEx * BCy - BEy * BCx
	local sideCAE = CEy * ACx - CEx * ACy
	if sideABC > 0 then
		if sideABE >= 0 and sideBCE >= 0 and sideCAE >= 0 then
			return true
		end
	elseif sideABE <= 0 and sideBCE <= 0 and sideCAE <= 0 then
		return true
	end

	--Circle intersects AB
	local dotABE = ABx * AEx + ABy * AEy
	if dotABE > 0 then
		local lensqAB = ABx * ABx + ABy * ABy
		--if dotABE < lensqAB and math.abs(sideABE) / lensqAB * math.sqrt(lensqAB) <= Er then
		if dotABE < lensqAB and sideABE * sideABE <= rsq * lensqAB then
			return true
		end
	end

	--Circle intersects BC
	local dotBCE = BCx * BEx + BCy * BEy
	if dotBCE > 0 then
		local lensqBC = BCx * BCx + BCy * BCy
		--if dotBCE < lensqBC and math.abs(sideBCE) / lensqBC * math.sqrt(lensqBC) <= Er then
		if dotBCE < lensqBC and sideBCE * sideBCE <= rsq * lensqBC then
			return true
		end
	end

	--Circle intersects CA
	local dotCAE = -ACx * CEx - ACy * CEy
	if dotCAE <= 0 then
		return false
	end
	local lensqCA = ACx * ACx + ACy * ACy
	--return dotCAE < lensqCA and math.abs(sideCAE) / lensqCA * math.sqrt(lensqCA) <= Er
	return dotCAE < lensqCA and sideCAE * sideCAE <= rsq * lensqCA
end

local function TriangleIntersectsTriangle(Ax, Ay, Bx, By, Cx, Cy, Ex, Ey, Fx, Fy, Gx, Gy)
	local ABx, ABy = Bx - Ax, By - Ay
	local ACx, ACy = Cx - Ax, Cy - Ay
	local sideABC = ACx * ABy - ACy * ABx
	if sideABC == 0 then
		Ax, Ay, Bx, By = _triangle_to_line(Ax, Ay, Bx, By, Cx, Cy)
		return LineIntersectsTriangle(Ax, Ay, Bx, By, Ex, Ey, Fx, Fy, Gx, Gy)
	end

	--[[--EFG and C on different sides of AB
	local AEx, AEy = Ex - Ax, Ey - Ay
	local AFx, AFy = Fx - Ax, Fy - Ay
	local AGx, AGy = Gx - Ax, Gy - Ay
	local sideABE = AEx * ABy - AEy * ABx
	local sideABF = AFx * ABy - AFy * ABx
	local sideABG = AGx * ABy - AGy * ABx
	if sideABC > 0 then
		if sideABE < 0 and sideABF < 0 and sideABG < 0 then
			return false
		end
	elseif sideABE > 0 and sideABF > 0 and sideABG > 0 then
		return false
	end

	--EFG and A on different sides of BC
	local BCx, BCy = Cx - Bx, Cy - By
	local BEx, BEy = Ex - Bx, Ey - By
	local BFx, BFy = Fx - Bx, Fy - By
	local BGx, BGy = Gx - Bx, Gy - By
	local sideBCE = BEx * BCy - BEy * BCx
	local sideBCF = BFx * BCy - BFy * BCx
	local sideBCG = BGx * BCy - BGy * BCx
	if sideABC > 0 then
		if sideBCE < 0 and sideBCF < 0 and sideBCG < 0 then
			return false
		end
	elseif sideBCE > 0 and sideBCF > 0 and sideBCG > 0 then
		return false
	end

	--EFG and B on different sides of CA
	local sideCAE = AEy * ACx - AEx * ACy
	local sideCAF = AFy * ACx - AFx * ACy
	local sideCAG = AGy * ACx - AGx * ACy
	if sideABC > 0 then
		if sideCAE < 0 and sideCAF < 0 and sideCAG < 0 then
			return false
		end
	elseif sideCAE > 0 and sideCAF > 0 and sideCAG > 0 then
		return false
	end]]

	local AEx, AEy = Ex - Ax, Ey - Ay
	local AFx, AFy = Fx - Ax, Fy - Ay
	local AGx, AGy = Gx - Ax, Gy - Ay
	local BCx, BCy = Cx - Bx, Cy - By
	local BEx, BEy = Ex - Bx, Ey - By
	local BFx, BFy = Fx - Bx, Fy - By
	local BGx, BGy = Gx - Bx, Gy - By
	if sideABC > 0 then
		if (AEx * ABy - AEy * ABx < 0 and AFx * ABy - AFy * ABx < 0 and AGx * ABy - AGy * ABx < 0) or
			(BEx * BCy - BEy * BCx < 0 and BFx * BCy - BFy * BCx < 0 and BGx * BCy - BGy * BCx < 0) or
			(AEy * ACx - AEx * ACy < 0 and AFy * ACx - AFx * ACy < 0 and AGy * ACx - AGx * ACy < 0)
		then
			return false
		end
	elseif (AEx * ABy - AEy * ABx > 0 and AFx * ABy - AFy * ABx > 0 and AGx * ABy - AGy * ABx > 0) or
		(BEx * BCy - BEy * BCx > 0 and BFx * BCy - BFy * BCx > 0 and BGx * BCy - BGy * BCx > 0) or
		(AEy * ACx - AEx * ACy > 0 and AFy * ACx - AFx * ACy > 0 and AGy * ACx - AGx * ACy > 0)
	then
		return false
	end

	local EFx, EFy = Fx - Ex, Fy - Ey
	local EGx, EGy = Gx - Ex, Gy - Ey
	local sideEFG = EGx * EFy - EGy * EFx
	if sideEFG == 0 then
		Ex, Ey, Fx, Fy = _triangle_to_line(Ex, Ey, Fx, Fy, Gx, Gy)
		return LineIntersectsTriangle(Ex, Ey, Ax, Ay, Bx, By, Cx, Cy)
	end

	--[[--ABC and G on different sides of EF
	local ECx, ECy = Cx - Ex, Cy - Ey
	local sideEFA = AEy * EFx - AEx * EFy
	local sideEFB = BEy * EFx - BEx * EFy
	local sideEFC = ECx * EFy - ECy * EFx
	if sideEFG > 0 then
		if sideEFA < 0 and sideEFB < 0 and sideEFC < 0 then
			return false
		end
	elseif sideEFA > 0 and sideEFB > 0 and sideEFC > 0 then
		return false
	end

	--ABC and E on different sides of FG
	local FGx, FGy = Gx - Fx, Gy - Fy
	local FCx, FCy = Cx - Fx, Cy - Fy
	local sideFGA = AFy * FGx - AFx * FGy
	local sideFGB = BFy * FGx - BFx * FGy
	local sideFGC = FCx * FGy - FCy * FGx
	if sideEFG > 0 then
		if sideFGA < 0 and sideFGB < 0 and sideFGC < 0 then
			return false
		end
	elseif sideFGA > 0 and sideFGB > 0 and sideFGC > 0 then
		return false
	end

	--ABC and F on different sides of GE
	local sideGEA = AGx * EGy - AGy * EGx
	local sideGEB = BGx * EGy - BGy * EGx
	local sideGEC = ECy * EGx - ECx * EGy
	if sideEFG > 0 then
		if sideGEA < 0 and sideGEB < 0 and sideGEC < 0 then
			return false
		end
	elseif sideGEA > 0 and sideGEB > 0 and sideGEC > 0 then
		return false
	end

	return true]]

	local ECx, ECy = Cx - Ex, Cy - Ey
	local FGx, FGy = Gx - Fx, Gy - Fy
	--local FCx, FCy = Cx - Fx, Cy - Fy
	if sideEFG > 0 then
		return (AEy * EFx - AEx * EFy >= 0 or BEy * EFx - BEx * EFy >= 0 or ECx * EFy - ECy * EFx >= 0)
			and (AFy * FGx - AFx * FGy >= 0 or BFy * FGx - BFx * FGy >= 0 or (Cx - Fx) * FGy + (Fy - Cy) * FGx >= 0)
			and (AGx * EGy - AGy * EGx >= 0 or BGx * EGy - BGy * EGx >= 0 or ECy * EGx - ECx * EGy >= 0)
	end
	return (AEy * EFx - AEx * EFy <= 0 or BEy * EFx - BEx * EFy <= 0 or ECx * EFy - ECy * EFx <= 0)
		and (AFy * FGx - AFx * FGy <= 0 or BFy * FGx - BFx * FGy <= 0 or (Cx - Fx) * FGy + (Fy - Cy) * FGx <= 0)
		and (AGx * EGy - AGy * EGx <= 0 or BGx * EGy - BGy * EGx <= 0 or ECy * EGx - ECx * EGy <= 0)
end

--Aligned rects only; use for quick bounding box test.
local function RectIntersectsRect(Al, At, Ar, Ab, Bl, Bt, Br, Bb)
	return Al <= Br and Ar >= Bl and At <= Bb and Ab >= Bt
end

math2d =
{
	DistSq = DistSq,
	DistSqPointToLine = DistSqPointToLine,
	IsPointOnLine = IsPointOnLine,
	IsPointInCircle = IsPointInCircle,
	IsPointInTriangle = IsPointInTriangle,
	LineIntersectsLine = LineIntersectsLine,
	LineIntersectsCircle = LineIntersectsCircle,
	LineIntersectsTriangle = LineIntersectsTriangle,
	CircleIntersectsCircle = CircleIntersectsCircle,
	TriangleIntersectsCircle = TriangleIntersectsCircle,
	TriangleIntersectsTriangle = TriangleIntersectsTriangle,
	RectIntersectsRect = RectIntersectsRect,
}
