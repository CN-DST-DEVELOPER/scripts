--Returns a sine wave based on game time. Mod will modify the period of the wave and abs is wether or not you want
-- the abs value of the wave
function GetSineVal(mod, abs, inst)
    local time = (inst and inst:GetTimeAlive() or GetTime()) * (mod or 1)
    local val = math.sin(PI * time)
    if abs then
        return math.abs(val)
    else
        return val
    end
end

--Lerp a number from a to b over t
function Lerp(a,b,t)
    return a + (b - a) * t
end

--Remap a value (i) from one range (a - b) to another (x - y)
function Remap(i, a, b, x, y)
    return (((i - a)/(b - a)) * (y - x)) + x
end

--Round a number to idp decimal points. 0.5-values are always rounded up.
function RoundBiasedUp(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

--Round a number to idp decimal points. 0.5-values are always rounded down.
function RoundBiasedDown(num, idp)
    local mult = 10^(idp or 0)
    return math.ceil(num * mult - 0.5) / mult
end

--Rounds numToRound to the nearest multiple of "mutliple"
function RoundToNearest(numToRound, multiple)
    local half = multiple/2
    return numToRound+half - (numToRound+half) % multiple
end

--Clamps a number between two values
function math.clamp(num, min, max)
    return num <= min and min or (num >= max and max or num)
end

function Clamp(num, min, max)
    return num <= min and min or (num >= max and max or num)
end

function IsNumberEven(num)
    return (num % 2) == 0
end

function DistXYSq(p1, p2)
	return (p1.x-p2.x)*(p1.x-p2.x) + (p1.y-p2.y)*(p1.y-p2.y)
end

function DistXZSq(p1, p2)
	return (p1.x-p2.x)*(p1.x-p2.x) + (p1.z-p2.z)*(p1.z-p2.z)
end

function math.range(start, stop, step)
    step = step or 1

    local out = {}
    for i = start, stop, step do
        table.insert(out, i)
    end
    return out
end

function math.diff(a, b)
    return math.abs(a - b)
end

function ReduceAngle(rot)
    while rot < -180 do
        rot = rot + 360
    end
    while rot > 180 do
        rot = rot - 360
    end
    return rot
end

function DiffAngle(rot1, rot2)
    return math.abs(ReduceAngle(rot2 - rot1))
end

function ReduceAngleRad(rot)
    while rot < -math.pi do
        rot = rot + 2 * math.pi
    end
    while rot > math.pi do
        rot = rot - 2 * math.pi
    end
    return rot
end

function DiffAngleRad(rot1, rot2)
    return math.abs(ReduceAngleRad(rot2 - rot1))
end

function BresenhamLineXZtoXZ(x1, z1, x2, z2) -- Orthogonal moves only for diagonals it will make a 2x2 block.

    local dx, dz = math.abs(x2 - x1), -math.abs(z2 - z1)
    local xstep, zstep = 1, 1
    if x2 <= x1 then
        xstep = -1
    end
    if z2 <= z1 then
        zstep = -1
    end

    local err = dx + dz
    local points = {}
    while true do
        table.insert(points, {x = x1, z = z1,})
        if x1 == x2 and z1 == z2 then
            break
        end
        local doubleerr = err * 2
        local recordpoint = false
        if doubleerr >= dz then
            err = err + dz
            x1 = x1 + xstep
            recordpoint = true
        end
        if doubleerr <= dx then
            if recordpoint then
                table.insert(points, {x = x1, z = z1,})
            end
            err = err + dx
            z1 = z1 + zstep
            if recordpoint then
                table.insert(points, {x = x1 - xstep, z = z1,})
            end
        end
    end

    return points
end

function BresenhamLineXZtoXZExcludeCaps(x1, z1, x2, z2, excludestart, excludeend)
    local points = BresenhamLineXZtoXZ(x1, z1, x2, z2)
    if excludestart then
        for i = 2, #points do
            points[i - 1] = points[i]
        end
        points[#points] = nil
    end
    if excludeend then
        points[#points] = nil
    end
    return points
end