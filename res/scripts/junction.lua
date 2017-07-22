local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"

local junction = {}

junction.buildCoors = function(numTracks, groupSize)
    local function builder(xOffsets, uOffsets, baseX, nbTracks)
        local function caller(n)
            return builder(
                xOffsets + func.seqMap({1, n}, function(n) return baseX - 0.5 * station.trackWidth + n * station.trackWidth end),
                uOffsets + {baseX + n * station.trackWidth + 0.25},
                baseX + n * station.trackWidth + 0.5,
                nbTracks - n)
        end
        if (nbTracks == 0) then
            local offset = function(o) return o - baseX * 0.5 end
            return
                {
                    tracks = xOffsets * pipe.map(offset),
                    walls = uOffsets * pipe.map(offset)
                }
        elseif (nbTracks < groupSize) then
            return caller(nbTracks)
        else
            return caller(groupSize)
        end
    end
    return builder(pipe.new, pipe.new * {0.25}, 0.5, numTracks)
end

junction.normalizeRad = function(rad)
    return (rad < math.pi * -0.5) and junction.normalizeRad(rad + math.pi * 2) or rad
end

junction.generateArc = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local sup = toXyz(arc:pt(arc.sup))
    local inf = toXyz(arc:pt(arc.inf))
    local mid = toXyz(arc:pt(arc.mid))
    
    local toVector = function(rad) return coor.xyz(0, (arc.mid > math.pi * 0.5 or arc.mid < -math.pi * 0.5) and -1 or 1, 0) .. coor.rotZ(rad) end
    
    local vecSup = toVector(arc.sup)
    local vecInf = toVector(arc.inf)
    local vecMid = toVector(arc.mid)
    
    local supExt = sup + vecSup * 5
    local infExt = inf - vecInf * 5
    
    return {
        {inf, mid, vecInf, vecMid},
        {mid, sup, vecMid, vecSup},
        {infExt, inf, vecInf, vecInf},
        {sup, supExt, vecSup, vecSup},
    }
end


junction.fArcs = function(offsets, rad, r)
    return func.map(offsets, function(x)
        return arc.byOR(
            coor.xyz(r, 0, 0) .. coor.rotZ(rad),
            math.abs(r - x)
    ) end
)
end

junction.makeFn = function(model, mPlace, m)
    m = m or coor.I()
    return function(obj)
        local coordsGen = arc.coords(obj, 5)
        local function makeModel(seq, scale)
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return station.newModel(model, m, coor.scaleY(0.5 * scale), mPlace(obj, rad1, rad2))
            end)
        end
        return {
            makeModel(coordsGen(junction.normalizeRad(obj.inf), junction.normalizeRad(obj.mid) - junction.normalizeRad(obj.inf))),
            makeModel(coordsGen(junction.normalizeRad(obj.mid), junction.normalizeRad(obj.sup) - junction.normalizeRad(obj.mid)))
        }
    end
end

local generatePolyArcEdge = function(group, from, to)
    return pipe.from(junction.normalizeRad(group[from]), junction.normalizeRad(group[to]) - junction.normalizeRad(group[from]))
        * arc.coords(group, 5)
        * pipe.map(function(rad) return func.with(group:pt(rad), {z = 0, rad = rad}) end)
end

junction.generatePolyArc = function(groups, from, to)
    local groupI, groupO = (function(ls) return ls[1], ls[#ls] end)(func.sort(groups, function(p, q) return p.r < q.r end))
    return function(extLon, extLat)
        local limitsExtender = function(ext)
            return function(group)
                local extValue = (junction.normalizeRad(group.mid) > math.pi * 0.5 and -1 or 1) * ext / group.r
                return group:setLimits(
                    {
                        inf = group.inf - extValue,
                        mid = group.mid,
                        sup = group.sup + extValue
                    }
            )
            end
        end
        
        local groupL, groupR = table.unpack(
            pipe.new
            / func.with(groupO, {guideline = groupO + extLat})
            / func.with(groupI, {guideline = groupI + (-extLat)})
            * pipe.map(limitsExtender(extLon))
            * pipe.sort(function(p, q) return p.o.x < q.o.y end)
        )
        return generatePolyArcEdge(groupR, from, to)
            * function(ls) return ls * pipe.range(1, #ls - 1)
                * pipe.map2(ls * pipe.range(2, #ls),
                    function(f, t) return
                        {
                            f, t,
                            func.with(groupL:pt(t.rad), {z = 0, rad = t.rad}),
                            func.with(groupL:pt(f.rad), {z = 0, rad = f.rad}),
                        }
                    end)
            end
    end
end

return junction
