local paramsutil = require "paramsutil"
local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local trackEdge = require "flyingjunction/trackedge"
local pipe = require "flyingjunction/pipe"
local station = require "flyingjunction/stationlib"
local junction = require "junction"
local jA = require "junction_assoc"

local dump = require "datadumper"

local mSidePillar = "station/concrete_flying_junction/infra_junc_pillar_side.mdl"
local mRoofFenceF = "station/concrete_flying_junction/infra_junc_roof_fence_front.mdl"
local mRoofFenceS = "station/concrete_flying_junction/infra_junc_roof_fence_side.mdl"
local mRoof = "station/concrete_flying_junction/infra_junc_roof.mdl"
local bridgeType = "z_concrete_flying_junction.lua"

local listDegree = {5, 10, 20, 30, 40, 50, 60, 70, 80}
local rList = {junction.infi * 0.001, 1, 4 / 5, 2 / 3, 3 / 5, 1 / 2, 1 / 3, 1 / 4, 1 / 5, 1 / 6, 1 / 8, 1 / 10}

local trSlopeList = {15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70}
local slopeList = {0, 10, 20, 25, 30, 35, 40, 50, 60}
local heightList = {-11, -8.7, -5, -2.5, -0.5, 0, 0.5, 2.5, 5}
local tunnelHeightList = {11, 10, 9.5, 8.7}

local ptXSelector = function(lhs, rhs) return lhs:length() < rhs:length() end

local function average(op1, op2) return (op1 + op2) * 0.5, (op1 + op2) * 0.5 end

local generateTrackGroups = function(tracks1, tracks2, trans)
    trans = trans or {mpt = coor.I(), mvec = coor.I()}
    return {
        normal = pipe.new
        * func.map2(tracks1, tracks2,
            function(t1, t2)
                local seg = {junction.generateArc(t1)[1], junction.generateArc(t2)[2]}
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
                local seg = {junction.generateArc(t1)[3], junction.generateArc(t2)[4]}
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


local minimalR = function(offsets, info)
    local offsetLower = {offsets.lower.walls[1], offsets.lower.walls[#offsets.lower.walls]}
    local offsetUpper = {offsets.upper.walls[1], offsets.upper.walls[#offsets.upper.walls]}
    
    local function incr(r)
        return r == 0 and 0 or (r > 0 and r + 1 or r - 1)
    end
    
    local function calculate(rLower, rUpper)
        
        local lowerGuideline = junction.fArcs(offsetLower, info.lower.rad, rLower)
        local upperGuideline = junction.fArcs(offsetUpper, info.upper.rad, rUpper)
        
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


local function part(info, offsets)
    info.lower.r, info.upper.r = minimalR(offsets, info)
    
    local sort = pipe.sort(function(l, r) return l:pt(l:rad(coor.xy(0, 0))).x < r:pt(l:rad(coor.xy(0, 0))).x end)
    
    local gRef = {
        lower = {
            tracks = sort(junction.fArcs(offsets.lower.tracks, info.lower.rad, info.lower.r)),
            walls = sort(junction.fArcs(offsets.lower.walls, info.lower.rad, info.lower.r)),
        },
        upper = {
            tracks = sort(junction.fArcs(offsets.upper.tracks, info.upper.rad, info.upper.r)),
            walls = sort(junction.fArcs(offsets.upper.walls, info.upper.rad, info.upper.r)),
        }
    }
    
    local wallExt = {
        lower = {L = gRef.lower.walls[1], R = gRef.lower.walls[#gRef.lower.walls]},
        upper = {L = gRef.upper.walls[1], R = gRef.upper.walls[#gRef.upper.walls]}
    }
    
    dump.dump({
        func.min(wallExt.upper.R - wallExt.lower.L, ptXSelector),
        wallExt.upper.R,
        wallExt.lower.L,
    })
    
    local limitRads = {
        lower = {
            inf = wallExt.lower.R:rad(func.min(wallExt.lower.R - wallExt.upper.L, ptXSelector)),
            mid = wallExt.lower.R:rad(coor.xy(0, 0)),
            sup = wallExt.lower.L:rad(func.min(wallExt.lower.L - wallExt.upper.R, ptXSelector)),
        },
        upper = {
            sup = wallExt.upper.R:rad(func.min(wallExt.upper.R - wallExt.lower.L, ptXSelector)),
            mid = wallExt.upper.R:rad(coor.xy(0, 0)),
            inf = wallExt.upper.L:rad(func.min(wallExt.upper.L - wallExt.lower.R, ptXSelector)),
        }
    }
    
    local result = {
        lower = {
            tracks = func.map(gRef.lower.tracks, function(l) return l:withLimits(limitRads.lower) end),
            walls = pipe.new
            * func.map(gRef.lower.walls, function(l)
                return l:withLimits(
                    {
                        inf = l:rad(func.min(l - wallExt.upper.L, ptXSelector)),
                        mid = l:rad(coor.xy(0, 0)),
                        sup = l:rad(func.min(l - wallExt.upper.R, ptXSelector)),
                    }) end)
            * function(walls)
                for i = 1, #walls - 1 do walls[i].inf = walls[i + 1].inf end
                for i = #walls, 2, -1 do walls[i].sup = walls[i - 1].sup end
                return walls
            end
        },
        upper = {
            tracks = func.map(gRef.upper.tracks, function(l) return l:withLimits(limitRads.upper) end),
            walls = {
                wallExt.upper.L:withLimits({
                    inf = limitRads.upper.inf,
                    mid = wallExt.upper.L:rad(func.min(wallExt.upper.L - wallExt.lower.L, ptXSelector)),
                    sup = limitRads.upper.sup,
                }),
                wallExt.upper.R:withLimits({
                    inf = limitRads.upper.inf,
                    mid = wallExt.upper.R:rad(func.min(wallExt.upper.R - wallExt.lower.R, ptXSelector)),
                    sup = limitRads.upper.sup,
                })
            },
        }
    }
    
    local inferExt = function(level, type, pos)
        return func.map(result[level][type],
            function(g)
                local p = g:pt(g[pos])
                local guideline = arc.byOR(p + (g.o - p):normalized() * (junction.infi - g.xOffset), (junction.infi - g.xOffset))
                
                return {
                    guideline = guideline,
                    rad = guideline:rad(p),
                    pt = p
                }
            end)
    end
    
    local ext = {
        lower = {
            tracks = {
                inf = inferExt("lower", "tracks", "inf"),
                sup = inferExt("lower", "tracks", "sup")
            },
            walls = {
                inf = inferExt("lower", "walls", "inf"),
                sup = inferExt("lower", "walls", "sup")
            }
        },
        upper = {
            tracks = {
                inf = inferExt("upper", "tracks", "inf"),
                sup = inferExt("upper", "tracks", "sup")
            },
            walls = {
                inf = inferExt("upper", "walls", "inf"),
                sup = inferExt("upper", "walls", "sup")
            }
        }
    }
    
    return func.with(result, {ext = ext})
end

local function generateStructure(lowerGroup, upperGroup, mZ)
    
    local function mPlace(guideline, rad1, rad2)
        local rad = rad2 and (rad1 + rad2) * 0.5 or rad1
        local pt = guideline:pt(rad)
        return coor.rotZ(rad) * coor.transX(pt.x) * coor.transY(pt.y) * mZ * coor.transZ(-11)
    end
    
    local makeWall = junction.makeFn(mSidePillar, mPlace, coor.scaleY(1.05))
    local makeRoof = junction.makeFn(mRoof, mPlace, coor.scaleY(1.05))
    local makeSideFence = junction.makeFn(mRoofFenceS, mPlace)
    
    local walls = lowerGroup.walls
    
    local trackSets = pipe.new
        * func.map2(func.range(walls, 1, #walls - 1), func.range(walls, 2, #walls),
            function(w1, w2) return pipe.new
                * lowerGroup.tracks
                * pipe.filter(function(t) return (t.xOffset < w2.xOffset and t.xOffset > w1.xOffset) or (t.xOffset < w1.xOffset and t.xOffset > w2.xOffset) end)
                * pipe.map(function(t)
                    return t:withLimits({
                        sup = w2.sup,
                        mid = t:rad(coor.xy(0, 0)),
                        inf = w1.inf,
                    }) end)
            end)
        * func.flatten
    
    local upperFences = func.map(upperGroup.tracks, function(t)
        return {
            station.newModel(mSidePillar, coor.rotZ(math.pi * 0.5), coor.scaleX(0.55), coor.transY(-0.25), mPlace(t, t.inf)),
            station.newModel(mSidePillar, coor.rotZ(math.pi * 0.5), coor.scaleX(0.55), coor.transY(0.25), mPlace(t, t.sup)),
        }
    end)
    
    local fences = func.map(trackSets, function(t)
        local m = coor.scaleX(1.091) * coor.transY(0.18) * coor.transZ(-1) * coor.centered(coor.scaleZ, 3.5 / 1.5, coor.xyz(0, 0, 10.75))
        return {
            station.newModel(mRoofFenceF, m, mPlace(t, t.inf)),
            station.newModel(mRoofFenceF, m, coor.flipY(), mPlace(t, t.sup)),
        }
    end)
    
    local sideFencesL = func.map(func.range(lowerGroup.walls, 1, #lowerGroup.walls - 1), function(t)
        return t:withLimits({
            sup = t:rad(func.min(upperGroup.walls[1] - t, ptXSelector)),
            mid = t:rad(func.min(upperGroup.walls[1] - t, ptXSelector)),
            inf = t.inf,
        })
    end)
    
    local sideFencesR = func.map(func.range(lowerGroup.walls, 2, #lowerGroup.walls), function(t)
        return t:withLimits({
            inf = t:rad(func.min(upperGroup.walls[2] - t, ptXSelector)),
            mid = t:rad(func.min(upperGroup.walls[2] - t, ptXSelector)),
            sup = t.sup,
        })
    end)
    
    return {
        pipe.new
        + func.mapFlatten(walls, function(w) return makeWall(w)[1] end)
        + func.mapFlatten(trackSets, function(t) return makeRoof(t)[1] end)
        + func.map(fences, function(f) return f[1] end)
        + func.mapFlatten(sideFencesL, function(t) return makeSideFence(t)[1] end)
        + makeSideFence(upperGroup.walls[2])[1]
        + makeWall(upperGroup.walls[2])[1]
        + func.mapFlatten(upperGroup.tracks, function(t) return makeRoof(t)[1] end)
        + func.map(upperFences, function(f) return f[1] end)
        ,
        pipe.new
        + func.mapFlatten(walls, function(w) return makeWall(w)[2] end)
        + func.mapFlatten(trackSets, function(t) return makeRoof(t)[2] end)
        + func.map(fences, function(f) return f[2] end)
        + func.mapFlatten(sideFencesR, function(t) return makeSideFence(t)[2] end)
        + makeSideFence(upperGroup.walls[1])[2]
        + makeWall(upperGroup.walls[1])[2]
        + func.mapFlatten(upperGroup.tracks, function(t) return makeRoof(t)[2] end)
        + func.map(upperFences, function(f) return f[2] end)
    }
end

local function params(paramFilter)
    return pipe.new *
        {
            paramsutil.makeTrackTypeParam(),
            paramsutil.makeTrackCatenaryParam(),
            {
                key = "applyCatenary",
                name = _("Catenary applied for"),
                values = {_("Both"), _("Lower"), _("Upper")},
                defaultIndex = 0
            },
            {
                key = "nbLowerTracks",
                name = _("Number of lower tracks"),
                values = {_("1"), _("2"), _("3"), _("4"), _("5"), _("6"), },
                defaultIndex = 1
            },
            {
                key = "nbUpperTracks",
                name = _("Number of upper tracks"),
                values = {_("1"), _("2"), _("3"), _("4"), _("5"), _("6"), },
                defaultIndex = 1
            },
            {
                key = "nbPerGroup",
                name = _("Tracks per group"),
                values = {_("1"), _("2"), _("All")},
                defaultIndex = 1
            },
            {
                key = "heightTunnel",
                name = _("Tunnel Height") .. ("(m)"),
                values = func.map(tunnelHeightList, tostring),
                defaultIndex = 0
            },
            {
                key = "xDegDec",
                name = _("Crossing angles"),
                values = {_("5"), _("10"), _("20"), _("30"), _("40"), _("50"), _("60"), _("70"), _("80"), },
                defaultIndex = 2
            },
            {
                key = "xDegUni",
                name = "+",
                values = func.seqMap({0, 9}, tostring),
            },
            {
                key = "curvedLevel",
                name = _("Curved levels"),
                values = {_("Both"), _("Lower"), _("Upper")},
                defaultIndex = 0
            },
            {
                key = "rLower",
                name = _("Radius of lower tracks"),
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(math.floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "rUpper",
                name = _("Radius of upper tracks"),
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(math.floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "transitionA",
                name = _("Transition A"),
                values = {_("Both"), _("Lower"), _("Upper")},
                defaultIndex = 0
            },
            {
                key = "trSlopeA",
                name = _("Transition A Slope") .. "(‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList - 1
            },
            {
                key = "transitionB",
                name = _("Transition B"),
                values = {_("Both"), _("Lower"), _("Upper")},
                defaultIndex = 0
            },
            {
                key = "trSlopeB",
                name = _("Transition B Slope") .. "(‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList - 1
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
                defaultIndex = 0
            },
            {
                key = "height",
                name = _("Altitude Adjustment(m)"),
                values = func.map(heightList, tostring),
                defaultIndex = 2
            }
        }
        * pipe.filter(function(p) return not func.contains(paramFilter, p.key) end)

end

local function defaultParams(param, fParams)
    local function limiter(d, u)
        return function(v) return v and v < u and v or d end
    end
    
    func.forEach(params({}), function(i)param[i.key] = limiter(i.defaultIndex or 0, #i.values)(param[i.key]) end)
    
    fParams(param)
end

local updateFn = function(fParams)
    return function(params)
            
            defaultParams(params, fParams)
            
            local deg = listDegree[params.xDegDec + 1] + params.xDegUni
            local rad = math.rad(deg)
            
            local trackType = ({"standard.lua", "high_speed.lua"})[params.trackType + 1]
            local catenary = params.catenary == 1
            local catenaryLower = func.contains({0, 1}, params.applyCatenary) and catenary
            local catenaryUpper = func.contains({0, 2}, params.applyCatenary) and catenary
            local nbPerGroup = ({1, 2, params.nbLowerTracks + 1})[params.nbPerGroup + 1]
            local tunnelHeight = tunnelHeightList[params.heightTunnel + 1]
            local height = heightList[params.height + 1]
            local mZ = coor.transZ(height)
            local mTunnelZ = coor.transZ(tunnelHeight)
            
            local lowerTrackBuilder = trackEdge.builder(catenaryLower, trackType)
            local upperTrackBuilder = trackEdge.builder(catenaryUpper, trackType)
            local TLowerTracks = lowerTrackBuilder.nonAligned()
            local TUpperTracks = upperTrackBuilder.nonAligned()
            local TLowerExtTracks = lowerTrackBuilder.nonAligned()
            local TUpperExtTracks = upperTrackBuilder.bridge(bridgeType)
            
            local retriveR = function(param) return rList[param + 1] * 1000 end
            
            local info = {
                A = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerA,
                        rFactor = params.fRLowerA,
                        rad = -0.5 * rad,
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperA,
                        rFactor = params.fRUpperA,
                        rad = 0.5 * rad,
                    }
                },
                B = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerB,
                        rFactor = params.fRLowerB,
                        rad = -0.5 * rad,
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperB,
                        rFactor = params.fRUpperB,
                        rad = 0.5 * rad,
                    }
                }
            }
            
            local offsets = {
                lower = junction.buildCoors(info.A.lower.nbTracks, nbPerGroup),
                upper = junction.buildCoors(info.A.upper.nbTracks, info.A.upper.nbTracks)
            }
            
            local group = {
                A = part(info.A, offsets),
                B = part(info.B, offsets)
            }
            
            local radFactorList = {A = 1, B = -1}
            local extHeightList = {upper = tunnelHeight + height, lower = height}
            local extSlopeList = {upper = 1, lower = -1, A = trSlopeList[params.trSlopeA + 1] * 0.001, B = trSlopeList[params.trSlopeB + 1] * 0.001}
            local extEndList = {A = "inf", B = "sup"}
            
            local prepareArc = function(part, level)
                return function(g)
                    local config = {
                        initRad = g.rad,
                        slope = extSlopeList[level] * extSlopeList[part],
                        height = extHeightList[level],
                        radFactor = radFactorList[part],
                        r = info[part][level].rFactor * g.guideline.r,
                    }
                    local fn = jA.retriveFn(config)
                    return {
                        guidelines = fn.retriveArc(g.guideline),
                        fn = fn,
                        config = config,
                    }
                end
            end
            
            local prepareArcs = function(type, part, level)
                return pipe.new
                    * group[part].ext[level][type][extEndList[part]]
                    * pipe.map(prepareArc(part, level))
            end
            
            local function retrive(type, fn)
                return {
                    upper = {
                        fn(prepareArcs(type, "A", "upper")),
                        fn(prepareArcs(type, "B", "upper")),
                    },
                    lower = {
                        fn(prepareArcs(type, "A", "lower")),
                        fn(prepareArcs(type, "B", "lower")),
                    }
                }
            end
            
            local extEdges = retrive("tracks", jA.retriveTracks)
            local extPolys = retrive("tracks", jA.retrivePolys)
            local extSurface = retrive("tracks", jA.retriveTrackSurfaces)
            local extWalls = retrive("walls", jA.retriveWalls)
            
            local lowerTracks = generateTrackGroups(group.A.lower.tracks, group.B.lower.tracks, {mpt = mZ, mvec = coor.I()})
            local upperTracks = generateTrackGroups(group.A.upper.tracks, group.B.upper.tracks, {mpt = mTunnelZ * mZ, mvec = coor.I()})
            
            local upperPolys = pipe.new
                + junction.generatePolyArc(group.A.upper.walls, "inf", "mid")(0, 0)
                + junction.generatePolyArc(group.B.upper.walls, "mid", "sup")(0, 0)
            
            local lowerPolys = pipe.new
                + junction.generatePolyArc(group.A.lower.tracks, "inf", "mid")(10, 3.5)
                + junction.generatePolyArc(group.B.lower.tracks, "mid", "sup")(10, 3.5)
            
            local result = {
                edgeLists =
                {
                    TUpperTracks(upperTracks.normal),
                    TLowerTracks(lowerTracks.normal),
                    pipe.new * extEdges.lower * pipe.mapFlatten(pipe.select("edges")) * station.prepareEdges * TLowerTracks,
                    pipe.new * extEdges.upper * pipe.mapFlatten(pipe.select("edges")) * station.prepareEdges * TUpperTracks
                -- TLowerExtTracks(lowerTracks.ext),
                -- TUpperExtTracks(upperTracks.ext),
                },
                models = pipe.new
                + generateStructure(group.A.lower, group.A.upper, mTunnelZ * mZ)[1]
                + generateStructure(group.B.lower, group.B.upper, mTunnelZ * mZ)[2]
                + func.flatten(extWalls.lower)
                + func.flatten(extWalls.upper)
                + func.flatten(extSurface.lower)
                + func.flatten(extSurface.upper)
                ,
                terrainAlignmentLists = pipe.new
                + {
                    {
                        type = "GREATER",
                        faces = upperPolys * pipe.map(pipe.map(mZ)) * pipe.map(pipe.map(coor.vec2Tuple)),
                    },
                    {
                        type = "LESS",
                        faces = upperPolys * pipe.map(pipe.map(mTunnelZ * mZ)) * pipe.map(pipe.map(coor.vec2Tuple))
                    },
                    {
                        type = "LESS",
                        faces = lowerPolys * pipe.map(pipe.map(mZ)) * pipe.map(pipe.map(coor.vec2Tuple)),
                        slopeLow = junction.infi,
                    },
                    {
                        type = "GREATER",
                        faces = lowerPolys * pipe.map(pipe.map(mZ)) * pipe.map(pipe.map(coor.vec2Tuple)),
                    }
                }
                + func.flatten(extPolys.lower)
                + func.flatten(extPolys.upper)
            }
            
            -- End of generation
            -- Slope, Height, Mirror treatment
            return pipe.new
                * result
                * station.setMirror(params.isMir == 1)
                * station.setSlope(slopeList[params.slope + 1])
    end
end

return {
    updateFn = updateFn,
    params = params,
    rList = rList
}
