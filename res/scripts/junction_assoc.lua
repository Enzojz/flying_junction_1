local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local line = require "flyingjunction/coorline"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = require "junction"

local wallHeight = 11

local retriveGeometry = function(config, slope)
    local rad = config.radFactor * slope.length / config.r
    local radF = rad * config.frac
    local radT = slope.trans.length / slope.length * rad
    local radRef = junction.normalizeRad(config.initRad)
    local extRad = config.radFactor * 5 / config.r
    local radList = pipe.new
        * {-extRad, 0, radT, radF * 0.5, radF - radT, radF, radF + extRad}
        * (config.radFactor < 0 and pipe.noop() or pipe.rev())
        * pipe.map(pipe.plus(radRef))
    
    local limits = pipe.new * {func.range(radList, 2, 4), func.range(radList, 4, 6)}
        * pipe.map(function(s) local rs = {}
            rs.inf, rs.mid, rs.sup = table.unpack(s)
            return rs
        end)
    
    local retriveArc = function(guideline) return
        limits * pipe.map(function(l) return guideline:withLimits(l) end)
    end
    
    local retrivefZ = function(profile)
        local fz = function(rx)
            local x = slope.length * math.abs((rx - radRef) / rad)
            local pf = func.filter(profile, function(s) return s.pred(x) end)[1]
            return pf.pt(x), pf
        end
        
        local fs = function(rx)
            local pt, pf = fz(rx)
            return pf.slope(pt)
        end
        
        local zList = radList * pipe.map(fz) * pipe.map(function(p) return p.y end)
        local sList = radList * pipe.map(fs) * (config.radFactor < 0 and pipe.noop() or pipe.map(pipe.neg()))
        return fz, func.zip(zList, sList, {"z", "s"})
    end
    
    return retriveArc, retrivefZ
end

local function gmPlaceA(fz, r)
    return function(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        local p1, p2 = fz(rad1), fz(rad2)
        return coor.shearZoY((r > 0 and -1 or 1) * (p2.y - p1.y) / math.abs(p2.x - p1.x)) * coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = ((p1 + p2) * 0.5).y - wallHeight}))
    end
end

local function generateSlope(slope, height)
    local sFactor = slope > 0 and 1 or -1
    local rad = math.atan(slope)
    local rTrans = 300
    local trans = {
        r = rTrans,
        dz = sFactor * rTrans * (1 - math.cos(rad)),
        length = height == 0 and 10 or sFactor * rTrans * math.sin(rad)
    }
    return {
        slope = slope,
        rad = rad,
        factor = sFactor,
        length = math.abs(height == 0 and 40 or (height - 2 * trans.dz) / slope + 2 * trans.length),
        trans = trans,
        height = height
    }
end

local function solveSlope(refSlope, height)
    local function solver(slope)
        local x = generateSlope(slope, height)
        return math.abs(x.length - refSlope.length) < 0.25 and x or solver(slope * x.length / refSlope.length)
    end
    
    return height == 0 and func.with(generateSlope(-refSlope.slope, height), {length = refSlope.length}) or solver(-refSlope.slope)
end

local slopeProfile = function(slope)
    local flatProfile = function()
        return {
            {
                pt = function(x) return coor.xy(x, slope.height) end,
                slope = function(_) return 0 end,
                pred = function(_) return true end,
            },
        }
    end
    local normalProfile = function()
        local ref1 = slope.factor * math.pi * 0.5
        local ref2 = -ref1
        local arc1 = arc.byOR(coor.xy(0, -slope.factor * slope.trans.r + (slope.height)), slope.trans.r)
        local arc2 = arc.byOR(coor.xy(slope.length, slope.factor * slope.trans.r), slope.trans.r)
        local pTr1 = arc1:pt(ref1 - slope.rad)
        local pTr2 = arc2:pt(ref2 - slope.rad)
        local lineSlope = line.byPtPt(pTr1, pTr2)
        local intersection = function(ar, cond) return function(x) return cond(ar / line.byVecPt(coor.xy(0, 1), coor.xy(x, 0)), function(p, q) return p.y < q.y end) end end
        return {
            {
                pred = function(x) return x <= 0 end,
                slope = function(_) return 0 end,
                pt = function(x) return coor.xy(x, slope.height) end
            },
            {
                pred = function(x) return x > 0 and x < pTr1.x end,
                slope = function(pt) return math.tan(arc1:rad(pt) - math.pi * 0.5) end,
                pt = intersection(arc1, slope.height > 0 and func.max or func.min)
            },
            {
                pred = function(x) return x >= pTr1.x and x <= pTr2.x end,
                slope = function(_) return -lineSlope.a / lineSlope.b end,
                pt = function(x) return lineSlope - line.byVecPt(coor.xy(0, 1), coor.xy(x, 0)) end
            },
            {
                pred = function(x) return x > pTr2.x and x < slope.length end,
                slope = function(pt) return math.tan(arc2:rad(pt) - math.pi * 0.5) end,
                pt = intersection(arc2, slope.height < 0 and func.max or func.min)
            },
            {
                pred = function(x) return x >= slope.length end,
                slope = function(_) return 0 end,
                pt = function(x) return coor.xy(x, 0) end
            },
        }
    end
    return slope.height == 0 and flatProfile() or normalProfile()
end

local retriveFn = function(config)
    local retriveArc, retrivefZ = retriveGeometry(config, config.slope)
    local profile = config.slopeProfile or slopeProfile(config.slope)
    local fz, zsList = retrivefZ(profile)
    local mPlaceA = gmPlaceA(fz, config.r)
    
    return {
        retriveArc = retriveArc,
        fz = fz,
        zsList = func.map2(
            func.range(zsList, 1, #zsList - 1),
            func.range(zsList, 2, #zsList),
            function(a, b) return func.map({a.z, b.z, a.s, b.s}, coor.transZ) end
        ),
        mPlaceA = mPlaceA,
        mPlaceD = function(guideline, rad1, rad2)
            local radc = (rad1 + rad2) * 0.5
            return coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = -wallHeight}))
        end,
        isDesc = function(a, b) return config.height > 0 and a or b end
    }
end

local retriveTracks = function(tracks)
    return tracks
        * pipe.map(function(tr) return
            tr.guidelines
            * pipe.map(junction.generateArc)
            * function(ar) return {ar[1][3], ar[1][1], ar[1][2], ar[2][1], ar[2][2], ar[2][4]} end
            * pipe.map2(tr.fn.zsList, function(ar, nz) return func.map2(ar, nz, coor.apply) end)
            * function(edge) return {
                main = pipe.new
                * {{edge[2], edge[3]}, {edge[4], edge[5]}}
                * pipe.map(function(e) return {
                    edge = pipe.new * e,
                    snap = pipe.new / {false, false} / {false, false}
                } end)
                * station.joinEdges
                * station.mergeEdges,
                inf = {
                    edge = pipe.new * {edge[1]},
                    snap = pipe.new * {{true, false}}
                },
                sup = {
                    edge = pipe.new * {edge[#edge]},
                    snap = pipe.new * {{false, true}}
                },
            } end
        end)
        * function(ls) return {
            inf = ls * pipe.map(pipe.select("inf")),
            sup = ls * pipe.map(pipe.select("sup")),
            main = ls * pipe.map(pipe.select("main"))
        }
        end
end


local retrivePolys = function(extLat, extLon)
    extLat = extLat or 4
    extLon = extLon or 3.5
    
    return function(tracks)
        return tracks
            * pipe.map(function(tr)
                return (pipe.new
                    + junction.generatePolyArc({tr.guidelines[1], tr.guidelines[1]}, "inf", "sup")(extLat, extLon)
                    + junction.generatePolyArc({tr.guidelines[2], tr.guidelines[2]}, "inf", "sup")(extLat, extLon)
                    )
                    * pipe.map(pipe.map(function(c) return coor.transZ(tr.fn.fz(c.rad).y)(c) end))
            end)
            * function(ls) return
                {
                    trackPolys = ls * pipe.flatten(),
                    polys = pipe.new
                    + junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(1)), "inf", "sup")(extLat, extLon)
                    + junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(2)), "inf", "sup")(extLat, extLon)
                } end
    end
end

local retriveTrackSurfaces = function(tracks)
    return tracks
        * pipe.map(function(tr) return tr.guidelines * pipe.map(junction.makeFn(tr.config.models.mRoof, tr.fn.mPlaceA, coor.scaleY(1.05))) end)
        * pipe.flatten()
        * pipe.flatten()
        * pipe.flatten()
end

local retriveWalls = function(walls)
    return walls
        * pipe.map(function(w) return
            w.guidelines * pipe.map(junction.makeFn(w.config.models.mSidePillar, w.fn.isDesc(w.fn.mPlaceA, w.fn.mPlaceD), coor.scaleY(1.05)))
            + w.guidelines * pipe.map(junction.makeFn(w.config.models.mRoofFenceS, w.fn.isDesc(w.fn.mPlaceA, w.fn.mPlaceD), coor.scaleY(1.05)))
        end)
        * pipe.map(pipe.flatten())
        * pipe.map(pipe.flatten())
end

return {
    retriveFn = retriveFn,
    retriveTracks = retriveTracks,
    retriveTrackSurfaces = retriveTrackSurfaces,
    retrivePolys = retrivePolys,
    retriveWalls = retriveWalls,
    solveSlope = solveSlope,
    generateSlope = generateSlope
}
