local paramsutil = require "paramsutil"
local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local trackEdge = require "flyingjunction/trackedge"
local line = require "flyingjunction/coorline"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"
local junction = require "junction"

local mSidePillar = "station/concrete_flying_junction/infra_junc_pillar_side.mdl"
local mRoofFenceS = "station/concrete_flying_junction/infra_junc_roof_fence_side.mdl"
local mRoof = "station/concrete_flying_junction/infra_junc_roof.mdl"

local rList = {1e5, 5, 3, 2, 1.5, 1, 0.75, 0.5, 2 / 3, 0.4, 1 / 3, 1 / 4, 1 / 5, 1 / 6, 1 / 7, 1 / 8, 1 / 9, 0.1}
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
    
    local function isDesc(a, b) return height > 0 and a or b end
    
    local nbTracks = params.nbTracks + 1
    local r = (params.isMir == 0 and 1 or -1) * rList[params.radius + 1] * 1000
    
    local slope = pipe.exec
        * function()
            local slope = sFactor * slopeList[params.slope + 1] * 0.001
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
                length = (height - 2 * trans.dz) / slope + 2 * trans.length,
                trans = trans
            }
        end
    
    local rad = slope.length / r
    local radT = slope.trans.length / slope.length * rad
    
    local slopeProfile = pipe.exec
        * function()
            local ref1 = sFactor * math.pi * 0.5
            local ref2 = -ref1
            local arc1 = arc.byOR(coor.xy(0, -sFactor * slope.trans.r + height), slope.trans.r)
            local arc2 = arc.byOR(coor.xy(slope.length, sFactor * slope.trans.r), slope.trans.r)
            local pTr1 = arc1:pt(ref1 - slope.rad)
            local pTr2 = arc2:pt(ref2 - slope.rad)
            local pTrM = coor.xy(slope.length * 0.5, height * 0.5)
            return {
                {
                    arc = arc.byOR(coor.xy(0, -sFactor * 1e5 + height), 1e5),
                    ref = height > 0 and func.max or func.min,
                    pred = function(x) return x < 0 end,
                },
                {
                    arc = arc1,
                    ref = height > 0 and func.max or func.min,
                    pred = function(x) return x >= 0 and x <= pTr1.x end,
                },
                {
                    arc = arc.byOR(arc.byDR(arc1, 1e5):pt(ref1 - slope.rad), 1e5),
                    ref = height < 0 and func.max or func.min,
                    pred = function(x) return x > pTr1.x and x < pTrM.x end,
                },
                {
                    arc = arc.byOR(arc.byDR(arc2, 1e5):pt(ref2 - slope.rad), 1e5),
                    ref = height > 0 and func.max or func.min,
                    pred = function(x) return x >= pTrM.x and x < pTr2.x end,
                },
                {
                    arc = arc2,
                    ref = height < 0 and func.max or func.min,
                    pred = function(x) return x >= pTr2.x and x <= slope.length end,
                },
                {
                    arc = arc.byOR(coor.xy(slope.length, sFactor * 1e5), 1e5),
                    ref = height < 0 and func.max or func.min,
                    pred = function(x) return x > slope.length end,
                },
            }
        end
    
    local radRef = r > 0 and math.pi or 0
    
    local function retriveZ(rx)
        local x = slope.length * (rx - radRef) / rad
        local pf = func.filter(slopeProfile, function(s) return s.pred(x) end)[1]
        return pf.ref(pf.arc / line.byVecPt(coor.xy(0, 1), coor.xy(x, 0)), function(p, q) return p.y < q.y end)
    end
    
    local function mPlaceA(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        local p1, p2 = retriveZ(rad1), retriveZ(rad2)
        return coor.shearZoY((r > 0 and 1 or -1) * (p2.y - p1.y) / (p2.x - p1.x)) * coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = ((p1 + p2) * 0.5).y - wallHeight}))
    end
    
    local function mPlaceD(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        return coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = -wallHeight}))
    end
    
    local offsets = junction.buildCoors(nbTracks, nbTracks)
    local generateGroup = function(o) return pipe.new
        * junction.fArcs(o, 0, r)
        * pipe.map(function(t) return
            {
                {
                    limits = {
                        inf = radRef + rad,
                        mid = radRef + rad - radT,
                        sup = radRef + 0.5 * rad,
                    },
                    guideline = t,
                },
                {
                    limits = {
                        inf = radRef + 0.5 * rad,
                        mid = radRef + radT,
                        sup = radRef,
                    },
                    guideline = t,
                }
            } end)
    end
    
    local groups = {
        tracks = generateGroup(offsets.tracks),
        walls = generateGroup(offsets.walls)
    }
    
    local makeStructure = function(group, fMake)
        return group
            * pipe.map(pipe.map(fMake))
            * pipe.flatten()
            * pipe.flatten()
            * pipe.flatten()
    end
    local walls =
        makeStructure(groups.walls, junction.makeFn(mSidePillar, isDesc(mPlaceA, mPlaceD), coor.scaleY(1.05)))
        + makeStructure(groups.walls, junction.makeFn(mRoofFenceS, isDesc(mPlaceA, mPlaceD), coor.scaleY(1.05)))
        + (height < 0 and {} or makeStructure(groups.tracks, junction.makeFn(mRoof, mPlaceA, coor.scaleY(1.05))))
    
    local edges = pipe.new
        * func.map(groups.tracks, pipe.map(junction.generateArc))
        * pipe.map(function(ar) return {ar[1][3], ar[1][1], ar[1][2], ar[2][1], ar[2][2], ar[2][4]} end)
        * pipe.map(function(ar) return pipe.new
            * {0, 0, slope.trans.dz, height * 0.5, height - slope.trans.dz, height, height}
            * pipe.zip({0, 0, slope.slope, slope.slope, slope.slope, 0, 0}, {"z", "s"})
            * function(lz) return
                lz * pipe.range(1, #lz - 1)
                * pipe.map2(lz * pipe.range(2, #lz), function(a, b) return func.map({a.z, b.z, a.s, b.s}, coor.transZ) end)
            end
            * pipe.map2(ar, function(nz, ar) return func.map2(ar, nz, coor.apply) end)
        end)
        * pipe.map(pipe.map(pipe.map(coor.vec2Tuple)))
        * pipe.map(pipe.zip({{true, false}, {false, false}, {false, false}, {false, false}, {false, false}, {false, true}}, {"edge", "snap"}))
        * pipe.flatten()
        * station.prepareEdges
        * trackBuilder.nonAligned()
    
    
    local polys = pipe.new
        + junction.generatePolyArc({groups.walls[1][1], groups.walls[2][1]}, "inf", "sup")(10, 1)
        + junction.generatePolyArc({groups.walls[1][2], groups.walls[2][2]}, "inf", "sup")(10, 1)
    
    local polyTracks = polys * pipe.map(pipe.map(function(c) return coor.transZ(retriveZ(c.rad).y)(c) end))
    
    return
        {
            edgeLists = {edges},
            models = walls,
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
                    slopeLow = isDesc(0.75, 0),
                    slopeHigh = isDesc(0.75, 0),
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


return {
    updateFn = updateFn,
    params = params
}