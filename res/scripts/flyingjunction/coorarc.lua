local coor = require "flyingjunction/coor"
local line = require "flyingjunction/coorline"
local func = require "flyingjunction/func"
local arc = {}

local sin = math.sin
local cos = math.cos
local acos = math.acos
local pi = math.pi
local abs = math.abs
local sqrt = math.sqrt
local ceil = math.ceil
local floor = math.floor

-- The circle in form of (x - a)² + (y - b)² = r²
function arc.new(a, b, r, limits)
    local result = {
        o = coor.xy(a, b),
        r = abs(r),
        inf = limits and limits.inf or -0.5 * pi,
        mid = limits and limits.mid or 0.5 * pi,
        sup = limits and limits.sup or 1.5 * pi,
        rad = arc.radByPt,
        length = arc.length,
        pt = arc.ptByRad,
        limits = arc.limits,
        withLimits = arc.withLimits,
        extendLimitsRad = arc.extendLimitsRad,
        extendLimits = arc.extendLimits,
        extraRad = arc.extraRad,
        extra = arc.extra,
        tangent = arc.tangent
    }
    setmetatable(result, {
        __sub = arc.intersectionArc,
        __div = arc.intersectionLine,
        __mul = function(lhs, rhs) return arc.byOR(lhs.o, lhs.r * rhs, lhs:limits()) end,
        __add = function(lhs, rhs) return arc.byOR(lhs.o, lhs.r + rhs, lhs:limits()) end
    })
    return result
end

function arc.byOR(o, r, limits) return arc.new(o.x, o.y, r, limits) end

function arc.byXYR(x, y, r, limits) return arc.new(x, y, r, limits) end

function arc.byDR(ar, dr, limits) return arc.byOR(ar.o, dr + ar.r, limits) end

function arc.withLimits(a, limits)
    return func.with(a, limits)
end

function arc.extendLimitsRad(arc, dInf, dSup)
    dSup = dSup or dInf
    return arc:withLimits({
        inf = arc.inf + (arc.inf > arc.mid and dInf or -dInf),
        mid = arc.mid,
        sup = arc.sup + (arc.sup > arc.mid and dSup or -dSup)
    })
end

function arc.length(arc)
    return abs(arc.sup - arc.inf) * arc.r
end

function arc.extendLimits(arc, dInf, dSup)
    dSup = dSup or dInf
    return arc:extendLimitsRad(dInf / arc.r, dSup / arc.r)
end

function arc.extraRad(arc, dInf, dSup)
    dSup = dSup or dInf
    return {
        inf = arc:withLimits({
            inf = arc.inf + (arc.inf > arc.mid and dInf or -dInf),
            mid = arc.inf + 0.5 * (arc.inf > arc.mid and dInf or -dInf),
            sup = arc.inf
        }),
        sup = arc:withLimits({
            inf = arc.sup,
            mid = arc.sup + 0.5 * (arc.sup > arc.mid and dSup or -dSup),
            sup = arc.sup + (arc.sup > arc.mid and dSup or -dSup)
        })
    }
end

function arc.extra(arc, dInf, dSup)
    dSup = dSup or dInf
    return arc:extraRad(dInf / arc.r, dSup / arc.r)
end

function arc.limits(a)
    return {
        inf = a.inf,
        mid = a.mid,
        sup = a.sup
    }
end

function arc.ptByRad(arc, rad)
    return
        coor.xy(
            arc.o.x + arc.r * cos(rad),
            arc.o.y + arc.r * sin(rad))
end

function arc.radByPt(arc, pt)
    local vec = (pt - arc.o):normalized()
    return vec.y > 0 and acos(vec.x) or -acos(vec.x)
end

function arc.ptByPt(arc, pt)
    return (pt - arc.o):normalized() * arc.r + arc.o
end

function arc.tangent(arc, rad)
    return coor.xyz(0, (arc.mid < arc.inf) and -1 or 1, 0) .. coor.rotZ(rad)
end


function arc.intersectionLine(arc, line)
    if (line.a ~= 0) then
        
        -- a.x + b.y + c = 0
        -- x + m.y + c/a = 0
        -- x = - m.y - l
        local m = line.b / line.a
        local l = line.c / line.a
        
        -- (- l - m.y - a)² + (y - b)² = r²
        -- ( l + a + m.y)² + (y - b)² = r²
        local n = l + arc.o.x
        -- (n + m.y)² + (y - b)² = r²
        -- n² + m.n.2.y + m².y² + y² - 2.b.y + b² = r²
        -- (m² + 1).y² + (m.n.2 - 2b).y + b² + n² = r²
        -- (m + 1).y² + 2(m.n - b).y + b² + n² - r²
        local o = m * m + 1;
        local p = 2 * (m * n - arc.o.y);
        local q = arc.o.y * arc.o.y + n * n - arc.r * arc.r;
        -- oy² + p.y + q = 0;
        -- y = (-p ± Sqrt(p² - 4.o.q)) / 2.o
        local delta = p * p - 4 * o * q;
        if (abs(delta) < 1e-10) then
            local y = -p / (2 * o)
            local x = -l - m * y
            return {coor.xy(x, y)}
        elseif (delta > 0) then
            local y0 = (-p + sqrt(delta)) / (2 * o)
            local y1 = (-p - sqrt(delta)) / (2 * o)
            local x0 = -l - m * y0
            local x1 = -l - m * y1
            return {coor.xy(x0, y0), coor.xy(x1, y1)}
        else
            return {}
        end
    else
        -- (x - a)² + (y - b)² = r²
        -- (x - a)² = r² - (y - b)²
        local y = -line.c / line.b;
        local delta = arc.r * arc.r - (y - arc.o.y) * (y - arc.o.y);
        if (abs(delta) < 1e-10) then
            return {coor.xy(arc.o.x, y)}
        elseif (delta > 0) then
            -- (x - a) = ± Sqrt(delta)
            -- x = ± Sqrt(delta) + a
            local x0 = sqrt(delta) + arc.o.x;
            local x1 = -sqrt(delta) + arc.o.x;
            return {coor.xy(x0, y), coor.xy(x1, y)}
        else
            return {}
        end
    end
end

function arc.commonChord(arc1, arc2)
    return line.new(
        2 * arc2.o.x - 2 * arc1.o.x,
        2 * arc2.o.y - 2 * arc1.o.y,
        arc1.o.x * arc1.o.x + arc1.o.y * arc1.o.y -
        arc2.o.x * arc2.o.x - arc2.o.y * arc2.o.y -
        arc1.r * arc1.r + arc2.r * arc2.r
)
end

function arc.intersectionArc(arc1, arc2)
    local chord = arc.commonChord(arc1, arc2)
    return arc.intersectionLine(arc1, chord)
end

function arc.coords(a, baseLength)
    return function(inf, sup)
        local length = a.r * abs(sup - inf)
        local nSeg = (function(x) return (x < 1 or (x % 1 > 0.5)) and ceil(x) or floor(x) end)(length / baseLength)
        local scale = length / (nSeg * baseLength)
        local dRad = (sup - inf) / nSeg
        local seq = abs(scale) < 1e-5 and {} or func.seqMap({0, nSeg}, function(n) return inf + n * dRad end)
        return seq, scale
    end
end


return arc
