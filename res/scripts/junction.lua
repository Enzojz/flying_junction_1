local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = {}

local pi = math.pi
local abs = math.abs

junction.trackList = {"standard.lua", "high_speed.lua"}
junction.trackWidthList = {5, 5}
junction.trackType = pipe.exec * function()
    local list = {
        {
            key = "trackType",
            name = _("Track type"),
            values = {_("Standard"), _("High-speed")},
            yearFrom = 1925,
            yearTo = 0
        },
        {
            key = "catenary",
            name = _("Catenary"),
            values = {_("None"), _("Both"), _("Lower"), _("Upper")},
            defaultIndex = 1,
            yearFrom = 1910,
            yearTo = 0
        }
    }
    if (commonapi and commonapi.uiparameter) then
        commonapi.uiparameter.modifyTrackCatenary(list, {selectionlist = junction.trackList})
        junction.trackWidthList = func.map(junction.trackList, function(e) return commonapi.repos.track.getByName(e).data.trackDistance end)
    end
    
    local type = func.filter(list, function(i) return i.key == "trackType" end)
    local typeLower = func.map(type, function(i) return func.with(i, {name = _("Lower Track Type")}) end)
    local typeUpper = func.map(type, function(i) return func.with(i, {key = "trackTypeUpper", name = _("Upper Track Type"), values = func.concat({_("Sync")}, i.values)}) end)
    local catenary = func.map(func.filter(list, function(i) return i.key == "catenary" end), function(i) return func.with(i, {values = {_("None"), _("Both"), _("Lower"), _("Upper")}}) end)

    return pipe.new + type + typeUpper + catenary
end

junction.infi = 1e8
junction.buildCoors = function(numTracks, groupSize, config)
    config = config or {
        trackWidth = station.trackWidth,
        wallWidth = 0.5
    }
    local function builder(xOffsets, uOffsets, baseX, nbTracks)
        local function caller(n)
            return builder(
                xOffsets + func.seqMap({1, n}, function(n) return baseX - 0.5 * config.trackWidth + n * config.trackWidth end),
                uOffsets + {baseX + n * config.trackWidth + 0.5 * config.wallWidth},
                baseX + n * config.trackWidth + config.wallWidth,
                nbTracks - n)
        end
        if (nbTracks == 0) then
            local offset = function(o) return o - baseX * config.wallWidth end
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
    return builder(pipe.new, pipe.new * {0.5 * config.wallWidth}, config.wallWidth, numTracks)
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
    return pipe.new
        * offsets
        * function(o) return r > 0 and o or o * pipe.map(pipe.neg()) * pipe.rev() end
        * pipe.map(function(x) return
            func.with(
                arc.byOR(
                    coor.xyz(r, 0, 0) .. coor.rotZ(rad),
                    abs(r) - x
                ), {xOffset = r > 0 and x or -x})
        end)
        * function(a) return r > 0 and a or a * pipe.rev() end
end

junction.makeFn = function(model, mPlace, m, length)
    m = m or coor.I()
    length = length or 5
    return function(obj)
        local coordsGen = arc.coords(obj, length)
        local function makeModel(seq, scale)
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return station.newModel(model, m, coor.scaleY(scale), mPlace(obj, rad1, rad2))
            end)
        end
        return {
            makeModel(coordsGen(junction.normalizeRad(obj.inf), junction.normalizeRad(obj.mid))),
            makeModel(coordsGen(junction.normalizeRad(obj.mid), junction.normalizeRad(obj.sup)))
        }
    end
end

local generatePolyArcEdge = function(group, from, to)
    return pipe.from(junction.normalizeRad(group[from]), junction.normalizeRad(group[to]))
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
