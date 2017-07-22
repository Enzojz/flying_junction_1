local coor = require "flyingjunction/coor"
local line = require "flyingjunction/coorline"
local func = require "flyingjunction/func"
local arc = {}

-- The circle in form of (x - a)² + (y - b)² = r²
function arc.new(a, b, r)
    local result = {
        o = coor.xy(a, b),
        r = r,
        inf = -0.5 * math.pi,
        mid = 0.5 * math.pi,
        sup = 1.5 * math.pi,
        rad = arc.radByPt,
        pt = arc.ptByRad,
        setLimits = arc.setLimits
    }
    setmetatable(result, {
        __sub = arc.intersectionArc,
        __div = arc.intersectionLine,
        __mul = function(lhs, rhs) return arc.byOR(lhs.o, lhs.r * rhs) end,
        __add = function(lhs, rhs) return arc.byOR(lhs.o, lhs.r + rhs) end
    })
    return result
end

function arc.byOR(o, r) return arc.new(o.x, o.y, r) end

function arc.byXYR(x, y, r) return arc.new(x, y, r) end

function arc.byDR(ar, dr) return arc.byOR(ar.o, dr + ar.r) end

function arc.setLimits(a, limits)
    local newArc = arc.byOR(a.o, a.r)
    newArc.inf = limits.inf
    newArc.sup = limits.sup
    newArc.mid = limits.mid
    return newArc
end

function arc.ptByRad(arc, rad)
    return
        coor.xy(
            arc.o.x + arc.r * math.cos(rad),
            arc.o.y + arc.r * math.sin(rad)
)
end

function arc.radByPt(arc, pt)
    local vec = (pt - arc.o):normalized()
    return vec.y > 0 and math.acos(vec.x) or -math.acos(vec.x)
end

function arc.ptByPt(arc, pt)
    return (pt - arc.o):normalized() * arc.r + arc.o
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
        if (math.abs(delta) < 1e-10) then
            local y = -p / (2 * o)
            local x = -l - m * y
            return {coor.xy(x, y)}
        elseif (delta > 0) then
            local y0 = (-p + math.sqrt(delta)) / (2 * o)
            local y1 = (-p - math.sqrt(delta)) / (2 * o)
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
        if (math.abs(delta) < 1e-10) then
            return {coor.xy(arc.o.x, y)}
        elseif (delta > 0) then
            -- (x - a) = ± Sqrt(delta)
            -- x = ± Sqrt(delta) + a
            local x0 = math.sqrt(delta) + arc.o.x;
            local x1 = -math.sqrt(delta) + arc.o.x;
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
    return function(from, rad)
        local length = a.r * math.abs(rad)
        local nSeg = (function(x) return (x < 1 or (x % 1 > 0.5)) and math.ceil(x) or math.floor(x) end)(length / baseLength)
        local scale = length / (nSeg * baseLength)
        local dRad = rad / nSeg
        local seq = math.abs(scale) < 1e-5 and {} or func.seqMap({0, nSeg}, function(n) return from + n * dRad end)
        return seq, scale
    end
end

return arc
