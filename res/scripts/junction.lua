local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = {}

local pi = math.pi
local abs = math.abs

junction.infi = 1e8
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
    return (rad < pi * -0.5) and junction.normalizeRad(rad + pi * 2) or rad
end

junction.generateArc = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local extArc = arc:extendLimits(5)

    local sup = toXyz(arc:pt(arc.sup))
    local inf = toXyz(arc:pt(arc.inf))
    local mid = toXyz(arc:pt(arc.mid))
    
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    local vecMid = arc:tangent(arc.mid)
    
    local supExt = toXyz(extArc:pt(extArc.sup))
    local infExt = toXyz(extArc:pt(extArc.inf))
    
    return {
        {inf, mid, vecInf, vecMid},
        {mid, sup, vecMid, vecSup},
        {infExt, inf, extArc:tangent(extArc.inf), vecInf},
        {sup, supExt, vecSup, extArc:tangent(extArc.sup)},
    }
end


junction.fArcs = function(offsets, rad, r)
    return func.map(offsets, function(x)
        local newArc = arc.byOR(
            coor.xyz(r, 0, 0) .. coor.rotZ(rad),
            abs(r) - x
        )
        newArc.xOffset = x
        return newArc
    end
)
end

junction.makeFn = function(model, mPlace, m)
    m = m or coor.I()
    return function(obj)
        local coordsGen = arc.coords(obj, 5)
        local function makeModel(seq, scale)
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return station.newModel(model, m, coor.scaleY(scale), mPlace(obj, rad1, rad2))
            end)
        end
        return {
            makeModel(coordsGen(obj.inf, obj.mid)),
            makeModel(coordsGen(obj.mid, obj.sup))
        }
    end
end

local generatePolyArcEdge = function(group, from, to)
    return pipe.from(group[from], group[to])
        * arc.coords(group, 5)
        * pipe.map(function(rad) return func.with(group:pt(rad), {z = 0, rad = rad}) end)
end

junction.generatePolyArc = function(groups, from, to)
    local groupI, groupO = (function(ls) return ls[1], ls[#ls] end)(func.sort(groups, function(p, q) return p.r < q.r end))
    return function(extLon, extLat)
            
            local groupL, groupR = table.unpack(
                pipe.new
                / (groupO + extLat):extendLimits(extLon)
                / (groupI + (-extLat)):extendLimits(extLon)
                * pipe.sort(function(p, q) return p:pt(p.mid).x < q:pt(p.mid).x end)
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

function junction.regularizeRad(rad)
    return rad > pi
        and junction.regularizeRad(rad - pi)
        or (rad < -pi and junction.regularizeRad(rad + pi) or rad)
end

return junction
