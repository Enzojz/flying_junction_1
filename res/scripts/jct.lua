local func = require "jct/func"
local coor = require "jct/coor"
local arc = require "jct/coorarc"
local general = require "jct/general"
local pipe = require "jct/pipe"

-- local dump = require "dump"

local jct = {}

local math = math
local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local sin = math.sin
local cos = math.cos
local unpack = table.unpack

local segmentLength = 20

jct.idTable = {
    [1] = "jct_track",
    [2] = "jct_wall",
    [3] = "jct_freenode",
    [4] = "jct_roof",
    -- [5] = "jct_replace",
    [6] = "jct_track",
    [7] = "jct_wall",
    [8] = "jct_freenode",
    -- [9] = "jct_replace"
}

jct.slotId = function(pos, typeId)
    return pos.z * 1000000 + pos.y * 1000 + pos.x * 10 + typeId
end

jct.slotInfo = function(slotId)
        -- Pos.x : track pos
        -- Pos.y : n module to the origin
        -- TypeId :
        --    1. Lower Track
        --    2. Lower Wall
        --    3. Lower Edge librator
        --    4. Roof for lower
        --    6. Upper Track
        --    7. Upper Wall
        --    8. Upper Edge librator
        -- Pos.z : additional function
        local typeId = slotId % 10
        local posZYX = (slotId - typeId) / 10
        local posX = posZYX % 100
        local posZY = (posZYX - posX) / 100
        local posY = posZY % 1000
        local posZ = (posZY - posY) / 1000
        if (posY >= 500) then posY = -(posY - 500) end
        local isUpper = typeId > 5
        return {
            pos = coor.xyz(posX, posY, posZ),
            typeId = typeId,
            isUpper = isUpper,
            slotId = slotId
        }
end

jct.arc2Edges = function(arc)
    local extLength = 2
    local extArc = arc:extendLimits(-extLength)
    local length = arc.r * abs(arc.sup - arc.inf)
    
    local sup = arc:pt(arc.sup)
    local inf = arc:pt(arc.inf)
    
    local supExt = arc:pt(extArc.sup)
    local vecSupExt = arc:tangent(extArc.sup)
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    return {
        {inf, vecInf * (length - extLength)},
        {supExt, vecSupExt * (length - extLength)},
        {supExt, vecSupExt * extLength},
        {sup, vecSup * extLength}
    }
end

jct.arcPacker = function(radius, rotRad, fz, fs)
    local rotCos = cos(rotRad)
    local rotSin = sin(rotRad)
    local vec = coor.xyz(rotCos, rotSin, 0)
    local o = vec * radius
    local initRad = (radius > 0 and pi or 0) + rotRad
    return function(dR)
        local radius = radius - dR
        return function(xDr)
            local dr = xDr or 0
            local ar = {
                arc.byOR(o, abs(radius + dr * 0.5)):withLimits({inf = initRad}),
                arc.byOR(o, abs(radius - dr * 0.5)):withLimits({inf = initRad})
            }
            return ar,
                initRad, 
                function(ptX, ptX2)
                    local finalRad = ar[1]:rad(ptX)
                    local initRad = ptX2 and ar[1]:rad(ptX2) or initRad
                    return function(xDr)
                        local dr = xDr or 0
                        local ar = arc.byOR(o, abs(radius - dr))
                        return ar:withLimits({
                            inf = initRad,
                            sup = finalRad,
                            fs = fs(initRad, finalRad),
                            fz = fz(initRad, finalRad)
                        })
                    end
                end
        end
    end
end

jct.biLatCoords = function(length, arc)
    local arcRef = arc()
    local nSeg = arcRef:length() / length
    nSeg = (nSeg < 1 or (nSeg % 1 > 0.5)) and ceil(nSeg) or floor(nSeg)
    local lRad = (arcRef.sup - arcRef.inf) / nSeg
    local listRad = func.seqMap({0, nSeg}, function(n) return arcRef.inf + n * lRad end)
    return function(...)
        return unpack(func.map({...}, function(o)
            local refArc = arc(o)
            return 
                func.map(listRad, function(rad) return refArc:pt(rad) end)
        end))
    end, nSeg, arcRef:length() / nSeg,
    function()
        local refArc = arc(0)
        return func.map(listRad, function(rad) return refArc:tangent(rad) end)
    end
end

jct.assembleSize = function(lc, rc)
    return {
        lb = lc.i,
        lt = lc.s,
        rb = rc.i,
        rt = rc.s
    }
end

local function mul(m1, m2)
    local m = function(line, col)
        local l = (line - 1) * 3
        return m1[l + 1] * m2[col + 0] + m1[l + 2] * m2[col + 3] + m1[l + 3] * m2[col + 6]
    end
    return {
        m(1, 1), m(1, 2), m(1, 3),
        m(2, 1), m(2, 2), m(2, 3),
        m(3, 1), m(3, 2), m(3, 3),
    }
end

jct.fitModel2D = function(w, h, zOffset, fitTop, fitLeft)
    local s = {
        {
            coor.xy(0, 0),
            coor.xy(fitLeft and w or -w, 0),
            coor.xy(0, fitTop and -h or h),
        },
        {
            coor.xy(0, 0),
            coor.xy(fitLeft and -w or w, 0),
            coor.xy(0, fitTop and h or -h),
        }
    }
    
    local mX = func.map(s,
        function(s) return {
            {s[1].x, s[1].y, 1},
            {s[2].x, s[2].y, 1},
            {s[3].x, s[3].y, 1},
        }
        end)
    
    local mXI = func.map(mX, coor.inv3)
    
    local fitTop = {fitTop, not fitTop}
    local fitLeft = {fitLeft, not fitLeft}

    return function(size, mode)
        local mXI = mXI[mode and 1 or 2]
        local fitTop = fitTop[mode and 1 or 2]
        local fitLeft = fitLeft[mode and 1 or 2]
        local t = fitTop and
            {
                fitLeft and size.lt or size.rt,
                fitLeft and size.rt or size.lt,
                fitLeft and size.lb or size.rb,
            } or {
                fitLeft and size.lb or size.rb,
                fitLeft and size.rb or size.lb,
                fitLeft and size.lt or size.rt,
            }
        
        local mU = {
            t[1].x, t[1].y, 1,
            t[2].x, t[2].y, 1,
            t[3].x, t[3].y, 1,
        }
        
        local mXi = mul(mXI, mU)
        
        return coor.I() * {
            mXi[1], mXi[2], 0, mXi[3],
            mXi[4], mXi[5], 0, mXi[6],
            0, 0, 1, 0,
            mXi[7], mXi[8], 0, mXi[9]
        } * coor.transZ(zOffset)
    end
end

jct.fitModel = function(w, h, d, fitTop, fitLeft)
    local s = {
        {
            coor.xyz(0, 0, 0),
            coor.xyz(fitLeft and w or -w, 0, 0),
            coor.xyz(0, fitTop and -h or h, 0),
            coor.xyz(0, 0, d)
        },
        {
            coor.xyz(0, 0, 0),
            coor.xyz(fitLeft and -w or w, 0, 0),
            coor.xyz(0, fitTop and h or -h, 0),
            coor.xyz(0, 0, d)
        },
    }
    
    local mX = func.map(s, function(s)
        return {
            {s[1].x, s[1].y, s[1].z, 1},
            {s[2].x, s[2].y, s[2].z, 1},
            {s[3].x, s[3].y, s[3].z, 1},
            {s[4].x, s[4].y, s[4].z, 1}
        }
    end)
    
    local mXI = func.map(mX, coor.inv)
    
    local fitTop = {fitTop, not fitTop}
    local fitLeft = {fitLeft, not fitLeft}
    
    return function(size, mode)
        local mXI = mXI[mode and 1 or 2]
        local fitTop = fitTop[mode and 1 or 2]
        local fitLeft = fitLeft[mode and 1 or 2]
        local t = fitTop and
            {
                fitLeft and size.lt or size.rt,
                fitLeft and size.rt or size.lt,
                fitLeft and size.lb or size.rb,
            } or {
                fitLeft and size.lb or size.rb,
                fitLeft and size.rb or size.lb,
                fitLeft and size.lt or size.rt,
            }
        local mU = {
            t[1].x, t[1].y, t[1].z, 1,
            t[2].x, t[2].y, t[2].z, 1,
            t[3].x, t[3].y, t[3].z, 1,
            t[1].x, t[1].y, t[1].z + d, 1
        }
        
        return mXI * mU
    end
end

jct.interlace = pipe.interlace({"s", "i"})

jct.buildSurface = function(fitModel, tZ)
    return function(fnSize)
        local fnSize = fnSize or function(_, lc, rc) return jct.assembleSize(lc, rc) end
        return function(i, s, ...)
            local sizeS = fnSize(i, ...)
            return s
                and pipe.new
                / general.newModel(s .. "_tl.mdl", tZ, fitModel(sizeS, true))
                / general.newModel(s .. "_br.mdl", tZ, fitModel(sizeS, false))
                or pipe.new * {}
        end
    end
end

jct.terrain = function(lc, rc)
    return pipe.mapn(lc, rc)(function(lc, rc)
        local size = jct.assembleSize(lc, rc)
        return func.map({size.lt, size.lb, size.rb, size.rt}, coor.vec2Tuple)
    end)
end

jct.safeBuild = function(params, updateFn)
    local defaultParams = jct.defaultParams(params)
    local paramsOnFail = params() *
        pipe.mapPair(function(i) return i.key, i.defaultIndex or 0 end)
    
    return function(param)
        local r, result = xpcall(
            updateFn,
            function(e)
                print("========================")
                print("Ultimate Station failure")
                print("Algorithm failure:", debug.traceback())
                print("Params:")
                func.forEach(
                    params() * pipe.filter(function(i) return param[i.key] ~= (i.defaultIndex or 0) end),
                    function(i)print(i.key .. ": " .. param[i.key]) end)
                print("End of Ultimate Station failure")
                print("========================")
            end,
            defaultParams(param)
        )
        return r and result or updateFn(defaultParams(paramsOnFail))
    -- return updateFn(defaultParams(param))
    end
end

return jct
