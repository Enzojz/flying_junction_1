local coor = require "coor"
local line = {}


-- line in form of
-- a.x + b.y + 1 = 0, if c != 0
-- if not
-- a.x + b.y + 0 = 0;
function line.new(a, b, c)
    local result = {a = a, b = b, c = c}
    result.vector = line.vec
    setmetatable(result, 
    {
        __sub = line.intersection
    })
    return result
end

function line.byVecPt(vec, pt)
    local a = vec.y
    local b = -vec.x
    local c = -(a * pt.x + b * pt.y)
    
    return (c ~= 0) and line.new(a / c, b / c, 1) or line.new(a, b, 0)
end

function line.byPtPt(pt1, pt2)
    return line.byVecPt(pt2 - pt1, pt2)
end

function line.byRadPt(rad, pt)
    return line.byVecPt({y = math.sin(rad), x = math.cos(rad)}, pt)
end

function line.vec(l)
    return coor.xy(-l.b, l.a):normalized()
end

function line.intersection(l1, l2)
    local a11 = l1.a
    local a12 = l1.b
    local a21 = l2.a
    local a22 = l2.b
    
    local b1 = -l1.c
    local b2 = -l2.c
    
    local idet = 1 / (a11 * a22 - a21 * a12)
    local c11 = a22 * idet
    local c12 = -a12 * idet
    local c21 = -a21 * idet
    local c22 = a11 * idet
    
    return coor.xy(c11 * b1 + c12 * b2, c21 * b1 + c22 * b2)
end

return line
