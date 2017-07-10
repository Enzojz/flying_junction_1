local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"

local newModel = function(m, ...)
    return {
        id = m,
        transf = coor.mul(...)
    }
end

local function buildCoors(numTracks, groupSize)
    local function builder(xOffsets, uOffsets, baseX, nbTracks)
        local function caller(n)
            return builder(
                func.concat(xOffsets, func.seqMap({1, n}, function(n) return baseX - 0.5 * station.trackWidth + n * station.trackWidth end)),
                func.concat(uOffsets, {baseX + n * station.trackWidth + 0.25}),
                baseX + n * station.trackWidth + 0.5,
                nbTracks - n)
        end
        if (nbTracks == 0) then
            local offset = function(o) return o - baseX * 0.5 end
            return
                {
                    tracks = func.map(xOffsets, offset),
                    walls = func.map(uOffsets, offset)
                }
        elseif (nbTracks < groupSize) then
            return caller(nbTracks)
        else
            return caller(groupSize)
        end
    end
    return builder({}, {0.25}, 0.5, numTracks)
end

local function normalizeRad(rad)
    return (rad < math.pi * -0.5) and normalizeRad(rad + math.pi * 2) or rad
end

local generateArc = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local radSup = normalizeRad(arc.limits.sup)
    local radMid = normalizeRad(arc.limits.mid)
    local radInf = normalizeRad(arc.limits.inf)
    
    local sup = toXyz(arc.guideline:pt(radSup))
    local inf = toXyz(arc.guideline:pt(radInf))
    local mid = toXyz(arc.guideline:pt(radMid))
    
    local toVector = function(rad) return coor.xyz(0, (arc.limits.mid > math.pi * 0.5 or arc.limits.mid < -math.pi * 0.5) and -1 or 1, 0) .. coor.rotZ(rad) end
    
    local vecSup = toVector(radSup)
    local vecInf = toVector(radInf)
    local vecMid = toVector(radMid)
    
    local supExt = sup + vecSup * 5
    local infExt = inf - vecInf * 5
    
    return {
        {inf, mid, vecInf, vecMid},
        {mid, sup, vecMid, vecSup},
        {infExt, inf, vecInf, vecInf},
        {sup, supExt, vecSup, vecSup},
    }
end

local function average(op1, op2) return (op1 + op2) * 0.5, (op1 + op2) * 0.5 end

local generateTrackGroups = function(tracks1, tracks2, trans)
    trans = trans or {mpt = coor.I(), mvec = coor.I()}
    return {
        normal = pipe.new
        * func.map2(tracks1, tracks2,
            function(t1, t2)
                local seg = {generateArc(t1)[1], generateArc(t2)[2]}
                seg[1][2], seg[2][1] = average(seg[1][2], seg[2][1])
                seg[1][4], seg[2][3] = average(seg[1][4], seg[2][3])
                return pipe.new
                    * seg
                    * pipe.map(pipe.map(coor.vec2Tuple))
                    * pipe.zip({{false, false}, {false, false}}, {"edge", "snap"})
            end)
        * pipe.flatten()
        * station.prepareEdges
        * function(r) return func.with(r, {edges = coor.applyEdges(trans.mpt, trans.mvec)(r.edges)}) end,
        ext = pipe.new
        * func.map2(tracks1, tracks2,
            function(t1, t2)
                local seg = {generateArc(t1)[3], generateArc(t2)[4]}
                return pipe.new
                    * seg
                    * pipe.map(pipe.map(coor.vec2Tuple))
                    * pipe.zip({{true, false}, {false, true}}, {"edge", "snap"})
            end)
        * pipe.flatten()
        * station.prepareEdges
        * function(r) return func.with(r, {edges = coor.applyEdges(trans.mpt, trans.mvec)(r.edges)}) end
    }
end

local fArcs = function(offsets, rad, r)
    return func.map(offsets, function(x)
        return arc.byOR(
            coor.xyz(r, 0, 0) .. coor.rotZ(rad),
            math.abs(r - x)
    ) end
)
end


local minimalR = function(offsets, info)
    local offsetLower = {offsets.lower.walls[1], offsets.lower.walls[#offsets.lower.walls]}
    local offsetUpper = {offsets.upper.walls[1], offsets.upper.walls[#offsets.upper.walls]}
    
    local function incr(r)
        return r == 0 and 0 or (r > 0 and r + 1 or r - 1)
    end
    
    local function calculate(rLower, rUpper)
        
        local lowerGuideline = fArcs(offsetLower, info.lower.rad, rLower)
        local upperGuideline = fArcs(offsetUpper, info.upper.rad, rUpper)
        
        local resultTest = (
            #(lowerGuideline[1] - upperGuideline[1]) > 1 and
            #(lowerGuideline[1] - upperGuideline[2]) > 1 and
            #(lowerGuideline[2] - upperGuideline[1]) > 1 and
            #(lowerGuideline[2] - upperGuideline[2]) > 1
        )
        if (resultTest) then
            return rLower, rUpper
        else
            return calculate(incr(rLower), rLower == rUpper and rUpper or incr(rUpper))-- if else to prevent infinit loop
        end
    end
    return calculate(info.lower.r, info.upper.r)
end

local function makeFn(model, mPlace, m)
    m = m or coor.I()
    return function(obj)
        local coordsGen = arc.coords(obj.guideline, 5)
        local function makeModel(seq, scale)
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return newModel(model, m, coor.scaleY(0.5 * scale), mPlace(obj.guideline, rad1, rad2))
            end)
        end
        return {
            makeModel(coordsGen(normalizeRad(obj.limits.inf), normalizeRad(obj.limits.mid) - normalizeRad(obj.limits.inf))),
            makeModel(coordsGen(normalizeRad(obj.limits.mid), normalizeRad(obj.limits.sup) - normalizeRad(obj.limits.mid)))
        }
    end
end

local generatePolyArcEdge = function(group, from, to)
    return pipe.from(normalizeRad(group.limits[from]), normalizeRad(group.limits[to]) - normalizeRad(group.limits[from]))
        * arc.coords(group.guideline, 5)
        * pipe.map(function(rad) return func.with(group.guideline:pt(rad), {z = 0, rad = rad}) end)
end

local generatePolyArc = function(groups, from, to)
    local groupL, groupR = table.unpack(groups)
    return function(extLon, extLat)
        local limitsExtender = function(ext)
            return function(group)
                local extValue = (normalizeRad(group.limits.mid) > math.pi * 0.5 and -1 or 1) * ext / group.guideline.r
                return func.with(group,
                    {
                        limits = {
                            inf = group.limits.inf - extValue,
                            mid = group.limits.mid,
                            sup = group.limits.sup + extValue
                        }
                    }
            )
            end
        end
        
        local guidelineExtender = function(ext)
            local extValue = groupL.guideline.r > groupR.guideline.r and ext or -ext
            return {
                func.with(groupL, {guideline = groupL.guideline + extValue}),
                func.with(groupR, {guideline = groupR.guideline + (-extValue)})
            }
        end
        
        local nG = func.map(guidelineExtender(extLat), limitsExtender(extLon))
        
        return generatePolyArcEdge(nG[2], from, to)
            * function(ls) return ls * pipe.range(1, #ls - 1)
                * pipe.map2(ls * pipe.range(2, #ls),
                    function(f, t) return
                        {
                            f, t,
                            func.with(nG[1].guideline:pt(t.rad), {z = 0, rad = t.rad}),
                            func.with(nG[1].guideline:pt(f.rad), {z = 0, rad = f.rad}),
                        }
                    end)
            end
    end
end

return {
    fArcs = fArcs,
    buildCoors = buildCoors,
    minimalR = minimalR,
    generateTrackGroups = generateTrackGroups,
    generatePolyArc = generatePolyArc,
    generateArc = generateArc,
    makeFn = makeFn,
    normalizeRad = normalizeRad,
    newModel = newModel
}
