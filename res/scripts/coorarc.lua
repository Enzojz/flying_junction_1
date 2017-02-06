local coor = require "coor"
local vec2 = require "vec2"
local line = require "coorline"
local arc = {}

-- The circle in form of (x - a)² + (y - b)² = r²
function arc.new(a, b, r) return {o = {x = a; y = b}; r = r} end

function arc.byOR(o, r) return arc.new(o.x, o.y, r) end

function arc.byDR(arc, dr) return arc.byOR(arc.o, dr + arc.r) end

function arc.ptByRad(arc, rad)
    return
        {
            x = arc.o.x + arc.r * math.cos(rad),
            y = arc.o.y + arc.r * math.sin(rad)
        }
end

function arc.radByPt(arc, pt)
    local vec = vec2.normalize(vec2.sub(pt, arc.o))
    return vec.y > 0 and math.asin(vec.x) or -math.asin(vec.x)
end

function arc.ptByPt(arc, pt)
    local vec = vec2.normalize(vec2.sub(pt, arc.o))
    return vec2.add(arc.o, vec2.mul(arc.r, vec))
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
        local n = l + a
        -- (n + m.y)² + (y - b)² = r²
        -- n² + m.n.2.y + m².y² + y² - 2.b.y + b² = r²
        -- (m² + 1).y² + (m.n.2 - 2b).y + b² + n² = r²
        -- (m + 1).y² + 2(m.n - b).y + b² + n² - r²
        local o = m * m + 1;
        local p = 2 * (m * n - b);
        local q = b * b + n * n - arc.r * arc.r;
        -- oy² + p.y + q = 0;
        -- y = (-p ± Sqrt(p² - 4.o.q)) / 2.o
        local delta = p * p - 4 * o * q;
        if (delta < 0 and math.abs(delta) < 0.000001) then delta = 0 end
        if (delta >= 0) then
            local y0 = (-p + math.sqrt(delta)) / (2 * o)
            local y1 = (-p - math.sqrt(delta)) / (2 * o)
            local x0 = -l - m * y0
            local x1 = -l - m * y1
            return {{x = x0, y = y0}, {x = x1, y = y1}}
        else
            return {}
        end
    else
        -- (x - a)² + (y - b)² = r²
        -- (x - a)² = r² - (y - b)²
        local y = -line.c / line.b;
        local delta = arc.r * arc.r - (y - b) * (y - b);
        if (delta < 0 and math.abs(delta) < 0.000001) then delta = 0 end
        if (delta >= 0) then
            -- (x - a) = ± Sqrt(delta)
            -- x = ± Sqrt(delta) + a
            local x0 = math.sqrt(delta) + a;
            local x1 = -math.sqrt(delta) + a;
            return {{x = x0, y = y}, {x = x1, y = y}}
        else
            return {}
        end
    end
end


function arc.intersectionArc(arc1, arc2)
    local chord = line.new(
        2 * arc2.o.x - 2 * arc1.o.x,
        2 * arc2.o.y - 2 * arc1.o.y,
        arc1.o.x * arc1.o.x + arc1.o.y * arc1.o.y -
        arc2.o.x * arc2.o.x - arc2.o.y * arc2.o.y -
        arc1.r * arc1.r + arc2.r * arc2.r

    return arc.intersectionLine(arc1, chord)
)
end
return arc
