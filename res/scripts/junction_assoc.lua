local paramsutil = require "paramsutil"
local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local trackEdge = require "flyingjunction/trackedge"
local line = require "flyingjunction/coorline"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = require "junction"
local dump = require "datadumper"

local mSidePillar = "station/concrete_flying_junction/infra_junc_pillar_side.mdl"
local mRoofFenceS = "station/concrete_flying_junction/infra_junc_roof_fence_side.mdl"
local mRoof = "station/concrete_flying_junction/infra_junc_roof.mdl"

local rList = {junction.infi * 0.001, 5, 3, 2, 1.5, 1, 0.75, 0.5, 2 / 3, 0.4, 1 / 3, 1 / 4, 1 / 5, 1 / 6, 1 / 7, 1 / 8, 1 / 9, 0.1}
local slopeList = {15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70}
local heightList = {11, 10, 9, 8, 7, 6, 5, 4, 3}
local wallHeight = 11

local function params()
    return {
        paramsutil.makeTrackTypeParam(),
        paramsutil.makeTrackCatenaryParam(),
        {
            key = "nbTracks",
            name = _("Number of tracks"),
            values = {_("1"), _("2"), _("3"), _("4"), _("5"), _("6"), },
            defaultIndex = 1
        },
        {
            key = "radius",
            name = _("Radius") .. ("(m)"),
            values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(math.floor(r * 1000 + 0.5)) end),
            defaultIndex = 0
        },
        {
            key = "isMir",
            name = _("Mirrored"),
            values = {_("No"), _("Yes")},
            defaultIndex = 0
        },
        {
            key = "slope",
            name = _("Slope(‰)"),
            values = func.map(slopeList, tostring),
            defaultIndex = #slopeList - 1
        },
        {
            key = "isDescding",
            name = _("Direction"),
            values = {"↗", "↘"},
            defaultIndex = 0
        },
        {
            key = "dz",
            name = _("ΔHeight") .. ("(m)"),
            values = func.map(heightList, tostring),
            defaultIndex = 3
        }
    }

end

local baseGuideline = function(initPt, initRad, r)
    return arc.byOR(
        coor.xyz(r, 0, 0) .. coor.rotZ(initRad) * coor.trans(initPt),
        math.abs(r)
)
end

local retriveGeometry = function(config, slope)
    local rad = config.radFactor * slope.length / config.r
    local radT = slope.trans.length / slope.length * rad
    local radRef = junction.normalizeRad(config.initRad)
    local limits = pipe.new * {{0, radT, 0.5 * rad}, {0.5 * rad, rad - radT, rad}}
        * function(ls) return config.radFactor < 0 and ls or ls * pipe.map(pipe.rev()) * pipe.rev() end
        * pipe.map(pipe.map(pipe.plus(radRef)))
        * pipe.map(function(s) local rs = {}
            rs.inf, rs.mid, rs.sup = table.unpack(s)
            return rs
        end)
    
    local resembleGroup = function(groups)
        return pipe.new
            * groups
            * pipe.map(function(g) return
                func.map(limits, function(l) return g.guideline:withLimits(l) end)
            end)
    end
    local retrivefZ = function(profile)
        return function(rx)
            local x = slope.length * math.abs((rx - radRef) / rad)
            local pf = func.filter(profile, function(s) return s.pred(x) end)[1]
            return pf.ref(pf.arc / line.byVecPt(coor.xy(0, 1), coor.xy(x, 0)), function(p, q) return p.y < q.y end)
        end
    end
    return resembleGroup, retrivefZ
end

local function gmPlaceA(fz, r)
    return function(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        local p1, p2 = fz(rad1), fz(rad2)
        return coor.shearZoY((r > 0 and -1 or 1) * (p2.y - p1.y) / math.abs(p2.x - p1.x)) * coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = ((p1 + p2) * 0.5).y - wallHeight}))
    end
end


local generateSlope = function(slope, height)
    local sFactor = slope > 0 and 1 or -1
    local rad = math.atan(slope)
    local rTrans = 300
    local trans = {
        r = rTrans,
        dz = sFactor * rTrans * (1 - math.cos(rad)),
        length = sFactor * rTrans * math.sin(rad)
    }
    return {
        slope = slope,
        rad = rad,
        factor = sFactor,
        length = (height - 2 * trans.dz) / slope + 2 * trans.length,
        trans = trans,
        height = height
    }
end

local slopeProfile = function(slope)
    local ref1 = slope.factor * math.pi * 0.5
    local ref2 = -ref1
    local arc1 = arc.byOR(coor.xy(0, -slope.factor * slope.trans.r + slope.height), slope.trans.r)
    local arc2 = arc.byOR(coor.xy(slope.length, slope.factor * slope.trans.r), slope.trans.r)
    local pTr1 = arc1:pt(ref1 - slope.rad)
    local pTr2 = arc2:pt(ref2 - slope.rad)
    local pTrM = coor.xy(slope.length * 0.5, slope.height * 0.5)
    return {
        {
            arc = arc.byOR(coor.xy(0, -slope.factor * junction.infi + slope.height), junction.infi),
            ref = slope.height > 0 and func.max or func.min,
            pred = function(x) return x < 0 end,
        },
        {
            arc = arc1,
            ref = slope.height > 0 and func.max or func.min,
            pred = function(x) return x >= 0 and x <= pTr1.x end,
        },
        {
            arc = arc.byOR(arc.byDR(arc1, junction.infi):pt(ref1 - slope.rad), junction.infi),
            ref = slope.height < 0 and func.max or func.min,
            pred = function(x) return x > pTr1.x and x < pTrM.x end,
        },
        {
            arc = arc.byOR(arc.byDR(arc2, junction.infi):pt(ref2 - slope.rad), junction.infi),
            ref = slope.height > 0 and func.max or func.min,
            pred = function(x) return x >= pTrM.x and x < pTr2.x end,
        },
        {
            arc = arc2,
            ref = slope.height < 0 and func.max or func.min,
            pred = function(x) return x >= pTr2.x and x <= slope.length end,
        },
        {
            arc = arc.byOR(coor.xy(slope.length, slope.factor * junction.infi), junction.infi),
            ref = slope.height < 0 and func.max or func.min,
            pred = function(x) return x > slope.length end,
        },
    }
end

local makeStructure = function(group, fMake)
    return group
        * pipe.map(pipe.map(fMake))
        * pipe.flatten()
        * pipe.flatten()
        * pipe.flatten()
end

local retriveFn = function(config)
    local slope = generateSlope(config.slope, config.height)
    
    local resembleGroup, retrivefZ = retriveGeometry(config, slope)
    local fz = retrivefZ(slopeProfile(slope))
    local mPlaceA = gmPlaceA(fz, config.r)
    
    local zsList = pipe.new
        * func.zip(
            pipe.new * {0, 0, slope.trans.dz, slope.height * 0.5, slope.height - slope.trans.dz, slope.height, slope.height} * function(ls) return config.radFactor > 0 and ls or func.rev(ls) end,
            pipe.new * {0, 0, slope.slope, slope.slope, slope.slope, 0, 0} * function(ls) return config.radFactor > 0 and ls or func.rev(ls * pipe.map(pipe.neg())) end,
            {"z", "s"})
        * function(hsList) return hsList
            * pipe.range(1, #hsList - 1)
            * pipe.map2(hsList * pipe.range(2, #hsList), function(a, b) return func.map({a.z, b.z, a.s, b.s}, coor.transZ) end)
        end
    
    return {
        resembleGroup = resembleGroup,
        fz = fz,
        slope = slope,
        zsList = zsList,
        mPlaceA = mPlaceA,
        mPlaceD = function(guideline, rad1, rad2)
            local radc = (rad1 + rad2) * 0.5
            return coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = -wallHeight}))
        end
    }
end

local retriveTracks = function(group, fn, config)
    local function isDesc(a, b) return config.height > 0 and a or b end
    local tracks = fn.resembleGroup(group)
    local edges = pipe.new
        * func.map(tracks, pipe.map(junction.generateArc))
        * pipe.map(function(ar) return {ar[1][3], ar[1][1], ar[1][2], ar[2][1], ar[2][2], ar[2][4]} end)
        * pipe.map(pipe.map2(fn.zsList, function(ar, nz) return func.map2(ar, nz, coor.apply) end))
        * pipe.map(pipe.map(pipe.map(coor.vec2Tuple)))
        * pipe.map(function(edge) return
            {
                a = pipe.new * func.range(edge, 2, #edge - 1) * pipe.zip(func.seqMap({1, 4}, function(_) return {false, false} end), {"edge", "snap"}),
                b = pipe.new * {edge[1], edge[#edge]} * pipe.zip({{true, false}, {false, true}}, {"edge", "snap"}),
            } end)
    
    local polys = pipe.new
        + junction.generatePolyArc({tracks[1][1], tracks[#tracks][1]}, "inf", "sup")(10, 3.5)
        + junction.generatePolyArc({tracks[1][2], tracks[#tracks][2]}, "inf", "sup")(10, 3.5)
    
    local polyTracks = polys * pipe.map(pipe.map(function(c) return coor.transZ(fn.fz(c.rad).y)(c) end))
    
    return {
        edges = edges * pipe.mapFlatten(pipe.select("a")),
        extEdges = edges * pipe.mapFlatten(pipe.select("b")),
        terrainAlignmentLists = {
            {
                type = isDesc("GREATER", "LESS"),
                faces = polys * pipe.map(pipe.map(coor.vec2Tuple)),
                slopeLow = 0.75,
                slopeHigh = 0.75,
            },
            {
                type = "LESS",
                faces = polyTracks * pipe.map(pipe.map(coor.vec2Tuple)),
                slopeLow = isDesc(0.75, junction.infi),
                slopeHigh = isDesc(0.75, junction.infi),
            },
            {
                type = "GREATER",
                faces = isDesc({}, polyTracks * pipe.map(pipe.map(coor.vec2Tuple))),
                slopeLow = 0.75,
                slopeHigh = 0.75,
            }
        }
    }
end

local retriveWalls = function(groupTr, groupWa, fn, config)
    local function isDesc(a, b) return config.height > 0 and a or b end
    local tracks = fn.resembleGroup(groupTr)
    local walls = fn.resembleGroup(groupWa)
    
    return {
        models = makeStructure(walls, junction.makeFn(mSidePillar, isDesc(fn.mPlaceA, fn.mPlaceD), coor.scaleY(1.05)))
        + makeStructure(walls, junction.makeFn(mRoofFenceS, isDesc(fn.mPlaceA, fn.mPlaceD), coor.scaleY(1.05)))
        + (fn.slope.height < 0 and {} or makeStructure(tracks, junction.makeFn(mRoof, fn.mPlaceA, coor.scaleY(1.05))))
    }
end

local comp = function(tracks, walls, config)
    local fn = retriveFn(config)
    
    return func.with(
        retriveTracks(tracks, fn, config),
        retriveWalls(tracks, walls, fn, config))
end

local composite = function(config)
    local offsets = junction.buildCoors(config.nbTracks, config.nbTracks)
    local guideline = baseGuideline(config.initPt, config.initRad, config.r)
    
    local groups = {
        tracks = offsets.tracks * pipe.map(function(o) return {guideline = guideline + o} end),
        walls = offsets.walls * pipe.map(function(o) return {guideline = guideline + o} end)
    }
    
    return comp(groups, config)
end

local function defaultParams(param)
    local function limiter(d, u)
        return function(v) return v and v < u and v or d end
    end
    
    func.forEach(params(), function(i)param[i.key] = limiter(i.defaultIndex or 0, #i.values)(param[i.key]) end)
end

local updateFn = function(params)
    defaultParams(params)
    
    local trackType = ({"standard.lua", "high_speed.lua"})[params.trackType + 1]
    local catenary = params.catenary == 1
    local trackBuilder = trackEdge.builder(catenary, trackType)
    local sFactor = params.isDescding == 1 and 1 or -1
    local height = sFactor * heightList[params.dz + 1]
    
    local nbTracks = params.nbTracks + 1
    local r = (params.isMir == 0 and 1 or -1) * rList[params.radius + 1] * 1000
    
    local c = composite({
        initPt = coor.xyz(30, 40, 0),
        initRad = math.pi / 12,
        slope = sFactor * slopeList[params.slope + 1] * 0.001,
        height = height,
        r = r,
        nbTracks = nbTracks,
        radFactor = 1
    })
    
    return
        {
            edgeLists = {(c.edges + c.extEdges) * station.prepareEdges * trackBuilder.nonAligned()},
            models = c.models,
            terrainAlignmentLists = c.terrainAlignmentLists
        }
end


return {
    updateFn = updateFn,
    params = params,
    comp = comp
}
