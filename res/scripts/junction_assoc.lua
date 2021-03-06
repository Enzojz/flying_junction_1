local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local line = require "flyingjunction/coorline"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = require "junction"

local wallHeight = 11

local math = math
local abs = math.abs
local atan = math.atan
local cos = math.cos
local sin = math.sin
local tan = math.tan
local pi = math.pi
local unpack = table.unpack

local retriveGeometry = function(config, slope)
    local rad = config.radFactor * slope.length / config.r
    local radF = rad * (config.frac < 1 and config.frac or 1)
    local radT = slope.trans.length / slope.length * rad
    local radRef = junction.normalizeRad(config.initRad)
    local extRad = config.radFactor * 5 / config.r
    
    local radList = pipe.new
        * {0, radT, rad * 0.5, rad - radT, rad}
        * pipe.filter(function(r) return abs(r) < abs(radF) end)
        * function(rawList) return pipe.new
            * {
                function() return {0, 0.25 * radF, 0.5 * radF, 0.75 * radF, radF} end,
                function() return {0, 0.5 * radT, radT, 0.5 * (radT + radF), radF} end,
                function() return {0, radT, rad * 0.25, rad * 0.5, radF} end,
                function() return {0, radT, rad * 0.5, rad - radT, radF} end,
                function() return {0, radT, rad * 0.5, rad - radT, rad} end,
            }
            * function(case) return case[#rawList]() end
        end
        * function(ls) return pipe.new + {-extRad} + ls + {ls[#ls] + extRad} end
        * (config.radFactor < 0 and pipe.noop() or pipe.rev())
        * pipe.map(pipe.plus(radRef))
    
    local limits = pipe.new * {func.range(radList, 2, 4), func.range(radList, 4, 6)}
        * pipe.map(function(s) local rs = {}
            rs.inf, rs.mid, rs.sup = unpack(s)
            return rs
        end)
    
    local retriveArc = function(guideline) return
        limits * pipe.map(function(l) return guideline:withLimits(l) end)
    end
    
    local retrivefZ = function(profile)
        local fz = function(rx)
            local x = slope.length * abs((rx - radRef) / rad)
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
    return function(fitModel, arcL, arcR, rad1, rad2)
        local p1, p2 = fz(rad1), fz(rad2)
        local size = {
            lt = arcL:pt(rad1):withZ(p1.y),
            lb = arcL:pt(rad2):withZ(p2.y),
            rt = arcR:pt(rad1):withZ(p1.y),
            rb = arcR:pt(rad2):withZ(p2.y)
        }
        return fitModel(size)
    end
end

local function generateSlope(slope, height, rTrans)
    rTrans = rTrans or 300
    local sFactor = slope > 0 and 1 or -1
    local rad = atan(slope)
    local trans = {
        r = rTrans,
        dz = sFactor * rTrans * (1 - cos(rad)),
        length = height == 0 and 10 or sFactor * rTrans * sin(rad)
    }
    return {
        slope = slope,
        rad = rad,
        factor = sFactor,
        length = abs(height == 0 and 40 or (height - 2 * trans.dz) / slope + 2 * trans.length),
        trans = trans,
        height = height
    }
end

local function solveSlope(refSlope, height, rTrans)
    local function solver(slope)
        local x = generateSlope(slope, height, rTrans)
        return abs(x.length - refSlope.length) < 0.25 and x or solver(slope * x.length / refSlope.length)
    end
    
    return height == 0 and func.with(generateSlope(-refSlope.slope, height, rTrans), {length = refSlope.length}) or solver(-refSlope.slope)
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
        local ref1 = slope.factor * pi * 0.5
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
                slope = function(pt) return tan(arc1:rad(pt) - pi * 0.5) end,
                pt = intersection(arc1, slope.height > 0 and func.max or func.min)
            },
            {
                pred = function(x) return x >= pTr1.x and x <= pTr2.x end,
                slope = function(_) return -lineSlope.a / lineSlope.b end,
                pt = function(x) return lineSlope - line.byVecPt(coor.xy(0, 1), coor.xy(x, 0)) end
            },
            {
                pred = function(x) return x > pTr2.x and x < slope.length end,
                slope = function(pt) return tan(arc2:rad(pt) - pi * 0.5) end,
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
        mPlaceD = function(fitModel, arcL, arcR, rad1, rad2)
            local size = {
                lt = arcL:pt(rad1):withZ(0),
                lb = arcL:pt(rad2):withZ(0),
                rt = arcR:pt(rad1):withZ(0),
                rb = arcR:pt(rad2):withZ(0)
            }
            return fitModel(size)
        end,
        isDesc = function(a, b) return config.height > 0 and a or b end
    }
end

local retriveTracks = function(tracks, ext)
    return tracks
        * pipe.map(function(tr) return
            tr.guidelines
            * pipe.map(junction.generateArc(ext))
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

local retrivePolys = function(extLon, extLat)
    extLon = extLon or 5
    extLat = extLat or 3
    
    return function(tracks)
        local arcL, arcR = tracks[1], tracks[#tracks]
        
        local tr = {
            junction.trackLevel(arcL.fn.fz, arcR.fn.fz),
            junction.trackLeft(arcL.fn.fz),
            junction.trackRight(arcR.fn.fz)
        }
        
        local polys = pipe.new
            / {
                junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(1)), "inf", "sup")
                (extLon, extLat, tr)
            }
            / {
                junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(2)), "inf", "sup")
                (extLon, extLat, tr)
            }
            
        local polysNoExt = pipe.new
        / {
            junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(1)), "inf", "mid")
            (-2, extLat, tr)
        }
        / {
            junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(1)), "mid", "sup")
            (2, extLat, tr)
        }
        / {
            junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(2)), "inf", "mid")
            (2, extLat, tr)
        }
        / {
            junction.generatePolyArc(tracks * pipe.map(pipe.select("guidelines")) * pipe.map(pipe.select(2)), "mid", "sup")
            (-2, extLat, tr)
        }
        
        return {
            polys = polys * pipe.map(pipe.select(1)) * pipe.flatten(),
            polysNoExt = polysNoExt * pipe.map(pipe.select(1)) * pipe.flatten(),
            trackPolys = polys * pipe.map(pipe.select(2)) * pipe.flatten(),
            leftPolys = polys * pipe.map(pipe.select(3)) * pipe.flatten(),
            rightPolys = polys * pipe.map(pipe.select(4)) * pipe.flatten()
        }
    end
end

local retriveTrackPavings = function(fitModel, models)
    return function(pavings)
        return pavings
            * pipe.interlace({"l", "r"})
            * pipe.map(function(p)
                return func.map2(
                    p.l.guidelines,
                    p.r.guidelines,
                    function(arcL, arcR)
                        local coordsL = junction.generatePolyArcEdge(arcL, "inf", "sup")
                        local coordsR = junction.generatePolyArcEdgeN(arcR, "inf", "sup", #coordsL - 1)
                        
                        return func.map2(
                            func.interlace(coordsL, {"i", "s"}),
                            func.interlace(coordsR, {"i", "s"}),
                            function(l, r)
                                local size = {
                                    lt = l.i:withZ(p.l.fn.fz(l.i.rad).y),
                                    rt = r.i:withZ(p.r.fn.fz(r.i.rad).y),
                                    lb = l.s:withZ(p.l.fn.fz(l.s.rad).y),
                                    rb = r.s:withZ(p.r.fn.fz(r.s.rad).y)
                                }
                                
                                return
                                    junction.subDivide(size, 5, 5, false, 1)
                                    * pipe.map(function(size)
                                        return {
                                            station.newModel(models.mRoof .. "_tl.mdl", fitModel(5, 5)(true, true)(size)),
                                            station.newModel(models.mRoof .. "_br.mdl", fitModel(5, 5)(false, false)(size))
                                        }
                                    end)
                                    * pipe.flatten()
                            end
                    )
                    end)
            end)
            * pipe.flatten()
            * pipe.flatten()
            * pipe.flatten()
    end
end

local retriveWalls = function(fitModel, fitModel2D)
    return function(walls)
        return walls
            * pipe.map(function(w) return
                w.guidelines * pipe.map(junction.makeFn(w.config.models.mSidePillar,
                    w.fn.isDesc(fitModel(0.5, 5), fitModel2D(0.5, 5)), 0.5,
                    w.fn.isDesc(w.fn.mPlaceA, w.fn.mPlaceD)))
                + w.guidelines * pipe.map(junction.makeFn(w.config.models.mRoofFenceS,
                    w.fn.isDesc(fitModel(0.5, 5), fitModel2D(0.5, 5)), 0.5,
                    w.fn.isDesc(w.fn.mPlaceA, w.fn.mPlaceD)))
            end)
            * pipe.map(pipe.flatten())
            * pipe.map(pipe.flatten())
    end
end

return {
    retriveFn = retriveFn,
    retriveTracks = retriveTracks,
    retrivePolys = retrivePolys,
    retriveWalls = retriveWalls,
    retriveTrackPavings = retriveTrackPavings,
    solveSlope = solveSlope,
    generateSlope = generateSlope
}
