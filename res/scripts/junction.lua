dump = require "inspect"
local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = {}

local math = math
local pi = math.pi
local abs = math.abs
local unpack = table.unpack

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

local normalizeSize = function(mirrored, size)
    return
    ((size.lt - size.lb):cross(size.rb - size.lb).z * (mirrored and -1 or 1) < 0)
        and size
        or {
            lt = size.rt,
            lb = size.rb,
            rt = size.lt,
            rb = size.lb
        }
end

junction.normalizeSize = normalizeSize

junction.fitModel2D = function(mirrored)
    return function(w, h)
        return function(fitTop, fitLeft)
            return function(size)
                local size = normalizeSize(mirrored, size)
                local s = {
                    coor.xyz(0, 0),
                    coor.xyz(fitLeft and w or -w, 0),
                    coor.xyz(0, fitTop and -h or h),
                }
                
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
                
                local mX = {
                    {s[1].x, s[1].y, 1},
                    {s[2].x, s[2].y, 1},
                    {s[3].x, s[3].y, 1},
                }
                
                local mU = {
                    t[1].x, t[1].y, 1,
                    t[2].x, t[2].y, 1,
                    t[3].x, t[3].y, 1,
                }
                
                local dX = coor.det(mX)
                
                local miX = coor.minor(mX)
                local mXI = func.mapFlatten(func.seq(1, 3),
                    function(l)
                        return func.seqMap({1, 3}, function(c)
                            return ((l + c) % 2 == 0 and 1 or -1) * coor.det(miX(c, l)) / dX
                        end)
                    end)
                
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
                
                local mXi = mul(mXI, mU)
                
                return coor.I() * {
                    mXi[1], mXi[2], 0, mXi[3],
                    mXi[4], mXi[5], 0, mXi[6],
                    0, 0, 1, 0,
                    mXi[7], mXi[8], 0, mXi[9]
                }
            end
        end
    end
end

junction.fitModel = function(mirrored)
    return function(w, h)
        return function(fitTop, fitLeft)
            return function(size)
                local size = normalizeSize(mirrored, size)
                local s = {
                    coor.xyz(0, 0, 0),
                    coor.xyz(fitLeft and w or -w, 0, 0),
                    coor.xyz(0, fitTop and -h or h, 0),
                    coor.xyz(0, 0, -1)
                }
                
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
                
                local mX = {
                    {s[1].x, s[1].y, s[1].z, 1},
                    {s[2].x, s[2].y, s[2].z, 1},
                    {s[3].x, s[3].y, s[3].z, 1},
                    {s[4].x, s[4].y, s[4].z, 1}
                }
                
                local mU = {
                    t[1].x, t[1].y, t[1].z, 1,
                    t[2].x, t[2].y, t[2].z, 1,
                    t[3].x, t[3].y, t[3].z, 1,
                    t[1].x, t[1].y, t[1].z - 1, 1
                }
                
                local dX = coor.det(mX)
                
                local miX = coor.minor(mX)
                local mXI = func.mapFlatten(func.seq(1, 4),
                    function(l)
                        return func.seqMap({1, 4}, function(c)
                            return ((l + c) % 2 == 0 and 1 or -1) * coor.det(miX(c, l)) / dX
                        end)
                    end)
                
                return coor.I() * mXI * mU
            end
        end
    end
end


junction.buildCoors = function(numTracks, groupSize, config)
    config = config or {
        trackWidth = station.trackWidth,
        wallWidth = 0.5,
        pavingWidth = 1,
    }
    local function builder(xOffsets, uOffsets, vOffsets, baseX, nbTracks)
        local function caller(n)
            return builder(
                xOffsets + func.seqMap({1, n}, function(n) return baseX - 0.5 * config.trackWidth + n * config.trackWidth end),
                uOffsets + {baseX + n * config.trackWidth + 0.5 * config.wallWidth},
                vOffsets + {baseX + 0.5 * config.wallWidth, baseX + n * config.trackWidth - 0.5 *  config.wallWidth},
                baseX + n * config.trackWidth + config.wallWidth,
                nbTracks - n)
        end
        if (nbTracks == 0) then
            local offset = function(o) return o - baseX * config.wallWidth end
            return
                {
                    tracks = xOffsets * pipe.map(offset),
                    walls = uOffsets * pipe.map(offset),
                    pavings = vOffsets * pipe.map(offset)
                }
        elseif (nbTracks < groupSize) then
            return caller(nbTracks)
        else
            return caller(groupSize)
        end
    end
    return builder(pipe.new, pipe.new * {0.5 * config.wallWidth}, pipe.new, config.wallWidth, numTracks)
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

junction.makeFn = function(model, fitModel, w, mPlace, length)
    m = m or coor.I()
    length = length or 5
    local fitTopLeft = fitModel(true, true)
    local fitBottomRight = fitModel(false, false)
    return function(obj)
        local coordsGen = arc.coords(obj, length)
        local inner = obj + (-w * 0.5)
        local outer = obj + (w * 0.5)
        local function makeModel(seq, scale)
            return pipe.new * func.map(func.interlace(seq, {"i", "s"}),
                function(rad)
                    return {
                        station.newModel(model .. "_tl.mdl",
                            mPlace(fitTopLeft, inner, outer, rad.i, rad.s)
                        ),
                        station.newModel(model .. "_br.mdl",
                            mPlace(fitBottomRight, inner, outer, rad.i, rad.s)
                    )
                    }
                end) * pipe.flatten()
        end
        return {
            makeModel(coordsGen(junction.normalizeRad(obj.inf), junction.normalizeRad(obj.mid))),
            makeModel(coordsGen(junction.normalizeRad(obj.mid), junction.normalizeRad(obj.sup)))
        }
    end
end

local generatePolyArcEdge = function(group, from, to, s)
    local s = s or 5
    return pipe.from(junction.normalizeRad(group[from]), junction.normalizeRad(group[to]))
        * arc.coords(group, s)
        * pipe.map(function(rad) return func.with(group:pt(rad):withZ(0), {rad = rad}) end)
end

local generatePolyArcEdgeN = function(group, from, to, n)
    local f, t = junction.normalizeRad(group[from]), junction.normalizeRad(group[to])
    local length = abs(t - f) * group.r
    local step = length / n
    return generatePolyArcEdge(group, from, to, step)
end

junction.trackLevel = function(fzL, fzR)
    return function(pts) return 
        {
            l = pts.l:withZ(fzL(pts.l.rad).y),
            r = pts.r:withZ(fzR(pts.r.rad).y)
        }
    end
end

junction.trackLeft = function(fz)
    return function(pts) 
        local vec = pts.l - pts.r
        local z = fz(pts.l.rad).y
        local w = (z < 0 and 0 or z / 0.75) + 1
        return { l = pts.l + vec:normalized() * w, r = pts.l:withZ(z) }
    end
end

junction.trackRight = function(fz)
    return function(pts) 
        local vec = pts.r - pts.l
        local z = fz(pts.r.rad).y
        local w = (z < 0 and 0 or z / 0.75) + 1
        return { l = pts.r:withZ(z), r = pts.r  + vec:normalized() * w }
    end
end


junction.generatePolyArc = function(groups, from, to)
    local groupI, groupO = (function(ls) return ls[1], ls[#ls] end)(func.sort(groups, function(p, q) return p.r < q.r end))
    return function(extLon, extLat, trans)
        local trans = pipe.new / (function(...) return ... end) + (trans or {})
        
        local groupO, groupI = (groupO + extLat):extendLimits(extLon), (groupI + (-extLat)):extendLimits(extLon)
        
        local ptsO = generatePolyArcEdge(groupO, from, to)
        local ptsI = generatePolyArcEdgeN(groupI, from, to, #ptsO - 1)
        
        local ptsL, ptsR, groupL, groupR = unpack(
            ((ptsO[1] - ptsO[#ptsO]):cross(ptsI[#ptsI] - ptsO[#ptsO])).z > 0
                and {ptsO, ptsI, groupO, groupI} or {ptsI, ptsO, groupI, groupO}
        )
        local pts = func.zip(ptsL, ptsR, {"l", "r"})
        return unpack(
            pipe.new
            * trans
            * pipe.map(function(t) return func.map(pts, t) end)
            * pipe.map(pipe.interlace({"f", "t"}))
            * pipe.map(pipe.map(function(p) return {p.f.r, p.t.r, p.t.l, p.f.l} end))
    )
    end
end

function junction.regularizeRad(rad)
    return rad > pi
        and junction.regularizeRad(rad - pi)
        or (rad < -pi and junction.regularizeRad(rad + pi) or rad)
end


return junction
