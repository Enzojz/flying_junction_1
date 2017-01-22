--[[
Copyright (c) 2016 "Enzojz" from www.transportfever.net
(https://www.transportfever.net/index.php/User/27218-Enzojz/)

Github repository:
https://github.com/Enzojz/transportfever

Anyone is free to use the program below, however the auther do not guarantee:
* The correctness of program
* The invariance of program in future
=====!!!PLEASE  R_E_N_A_M_E  BEFORE USE IN YOUR OWN PROJECT!!!=====

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including the right to distribute and without limitation the rights to use, copy and/or modify
the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--]]
local laneutil = require "laneutil"
local vec4 = require "vec4"
local vec3 = require "vec3"
local transf = require "transf"

local coor = {}
coor.make = laneutil.makeLanes

coor.o = vec3.new(0, 0, 0)

function coor.tuple2Vec(tuple)
    return vec3.new(table.unpack(tuple))
end

function coor.vec2Tuple(vec)
    return {vec.x, vec.y, vec.z}
end

function coor.edge2Vec(edge)
    local pt, vec = table.unpack(edge)
    return coor.tuple2Vec(pt), coor.tuple2Vec(vec)
end

function coor.vec2Edge(pt, vec)
    return {coor.vec2Tuple(pt), coor.vec2Tuple(vec)}
end

function coor.I()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.rotZ(rotX)
    local sx = math.sin(rotX)
    local cx = math.cos(rotX)
    
    return {
        cx, sx, 0, 0,
        -sx, cx, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.rotY(rotX)
    local sx = math.sin(rotX)
    local cx = math.cos(rotX)
    
    return {
        cx, 0, sx, 0,
        0, 1, 0, 0,
        -sx, 0, cx, 0,
        0, 0, 0, 1
    }
end


function coor.rotX(rotX)
    local sx = math.sin(rotX)
    local cx = math.cos(rotX)
    
    return {
        1, 0, 0, 0,
        0, cx, sx, 0,
        0, -sx, cx, 0,
        0, 0, 0, 1
    }
end

function coor.xXY()
    return {
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.xXZ()
    return {
        0, 0, 1, 0,
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 1
    }
end

function coor.flipX()
    return {
        -1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end


function coor.flipY()
    return {
        1, 0, 0, 0,
        0, -1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.flipZ()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, -1, 0,
        0, 0, 0, 1
    }
end

function coor.trans(vec)
    return coor.mul(coor.transX(vec.x), coor.transY(vec.y), coor.transZ(vec.z))
end

function coor.transX(dx)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        dx, 0, 0, 1
    }
end

function coor.transY(dy)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, dy, 0, 1
    }
end

function coor.transZ(dz)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, dz, 1
    }
end


function coor.scaleX(sx)
    return {
       sx, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end


function coor.scaleY(sy)
    return {
        1, 0, 0, 0,
        0,sy, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.scaleZ(sz)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0,sz, 0,
        0, 0, 0, 1
    }
end

-- the original transf.mul is ill-formed. The matrix is in form of Y = X.A + b, but mul transposed the matrix for Y = A.X + b
local function mul(m1, m2)
    local m = function(line, col)
        local l = (line - 1) * 4
        return m1[l + 1] * m2[col + 0] + m1[l + 2] * m2[col + 4] + m1[l + 3] * m2[col + 8] + m1[l + 4] * m2[col + 12]
    end
    return {
        m(1, 1), m(1, 2), m(1, 3), m(1, 4),
        m(2, 1), m(2, 2), m(2, 3), m(2, 4),
        m(3, 1), m(3, 2), m(3, 3), m(3, 4),
        m(4, 1), m(4, 2), m(4, 3), m(4, 4)
    }
end

function coor.mul(...)
    local params = {...}
    local m = params[1]
    for i = 2, #params do
        m = mul(m, params[i])
    end
    return m
end

coor.sub = vec3.sub
coor.add = vec3.add
coor.normalize = vec3.normalize
coor.nmul = vec3.mul
coor.length = vec3.length
coor.distance = vec3.distance

function coor.apply(vec, trans)
    local applyVal = function(col)
        return vec.x * trans[0 + col] + vec.y * trans[4 + col] + vec.z * trans[8 + col] + trans[12 + col]
    end
    return vec3.new(applyVal(1), applyVal(2), applyVal(3))
end

function coor.applyM(vec, ...)
    return coor.apply(vec, coor.mul(...))
end

function coor.applyEdge(mpt, mvec)
    return function(edge)
        local pt, vec = coor.edge2Vec(edge)
        local newPt = coor.applyM(pt, mpt)
        local newVec = coor.applyM(vec, mvec)
        return coor.vec2Edge(newPt, newVec)
    end
end

function coor.applyEdges(mpt, mvec)
    return function(edges)
        return func.map(edges, coor.applyEdge(mpt, mvec))
    end
end

function coor.rotate(edge, mt0, mtr, mt1)
    return coor.applyEdge(coor.mul(mt0, mtr, mt1), mtr)(edge)
end

function coor.translateAndBack(center)
    return coor.trans(vec3.sub(coor.o, center)),
        coor.trans(center)
end


function coor.rotYCentered(rad, center)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotY(rad)
    return coor.mul(mt0, mtr, mt1)
end

function coor.rotXCentered(rad, center)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotX(rad)
    return coor.mul(mt0, mtr, mt1)
end

function coor.rotZCentered(rad, center)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotZ(rad)
    return coor.mul(mt0, mtr, mt1)
end

function coor.rotateEdgeByZ(degree, center, edge)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotZ(math.rad(degree))
    return coor.rotate(edge, mt0, mtr, mt1)
end

function coor.rotateEdgeByX(rad, center, edge)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotX(rad)
    return coor.rotate(edge, mt0, mtr, mt1)
end

function coor.setHeight(height, edge)
    local mz = coor.transZ(height)
    local pt, vec = coor.edge2Vec(edge)
    local newPt = coor.applyM(pt, mz)
    return coor.vec2Edge(newPt, vec)
end

return coor
