local paramsutil = require "paramsutil"
local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local trackEdge = require "flyingjunction/trackedge"
local pipe = require "flyingjunction/pipe"
local station = require "flyingjunction/stationlib"
local junction = require "junction"
local jA = require "junction_assoc"

local abs = math.abs
local floor = math.floor
local ceil = math.ceil
local pi = math.pi

local listDegree = {5, 10, 20, 30, 40, 50, 60, 70, 80}
local rList = {junction.infi * 0.001, 5, 3.5, 2, 1, 4 / 5, 2 / 3, 3 / 5, 1 / 2, 1 / 3, 1 / 4, 1 / 5, 1 / 6, 1 / 8, 1 / 10, 1 / 20}

local trSlopeList = {15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 80, 90, 100}
local slopeList = {0, 10, 20, 25, 30, 35, 40, 50, 60}
local heightList = {0, 1 / 4, 1 / 3, 1 / 2, 2 / 3, 3 / 4, 1, 1.1, 1.2, 1.25, 1.5}
local tunnelHeightList = {11, 10, 9.5, 8.7}
local lengthPercentList = {1, 4 / 5, 3 / 4, 3 / 5, 1 / 2, 2 / 5, 1 / 4, 1 / 5}

local ptXSelector = function(lhs, rhs) return lhs:length2() < rhs:length2() end

local mPlaceSlopeWall = function(sw, arc, upperHeight)
    local heightVar = upperHeight * (arc.t - arc.f)
    local heightBase = upperHeight * (1 - arc.t)
    return function(guideline, rad1, rad2)
        local rad = rad2 and (rad1 + rad2) * 0.5 or rad1
        local t = heightVar / (arc[sw.from] - arc[sw.to]) / guideline.r
        local h = heightVar * (rad - arc[sw.to]) / (arc[sw.from] - arc[sw.to]) + heightBase
        local pt = guideline:pt(rad)
        return coor.shearZoY(t) * coor.rotZ(rad) * coor.trans(func.with(pt, {z = h - 11}))
    end
end

local function detectSlopeIntersection(lower, upper, fz, currentRad, s)
    local step = 0.25 / lower.r
    local ptL = lower:pt(currentRad)
    local ptRad = junction.normalizeRad(upper:rad(ptL))
    local ptR = upper:pt(ptRad)
    local z = fz(ptRad)
    local w = z.y / 0.75 + 3
    
    return ((ptL - ptR):length() > w)
        and currentRad
        or
        (currentRad > 1.5 * pi or currentRad < -0.5 * pi or ptL:length() > 100) and currentRad or
        detectSlopeIntersection(lower, upper, fz, currentRad + (s > 0 and step or -step), s)
end

local generateTrackGroups = function(tracks1, tracks2, trans)
    trans = trans or {mpt = coor.I(), mvec = coor.I()}
    local m = {trans.mpt, trans.mpt, trans.mvec, trans.mvec}
    return pipe.new
        * func.zip(tracks1, tracks2)
        * pipe.map(pipe.map(junction.generateArc))
        * pipe.map(pipe.map(pipe.map(pipe.map2(m, coor.apply))))
        * pipe.map(function(seg)
            return {
                main = pipe.new
                * {{seg[1][1]}, {seg[2][2]}}
                * pipe.map(function(e) return {
                    edge = pipe.new * e,
                    snap = pipe.new / {false, false}
                } end)
                * station.joinEdges
                * station.mergeEdges,
                inf = {
                    edge = pipe.new * {seg[1][3]},
                    snap = pipe.new / {true, false}
                },
                sup = {
                    edge = pipe.new * {seg[2][4]},
                    snap = pipe.new / {false, true}
                }
            }
        end)
        * function(ls) return {
            main = ls * pipe.map(pipe.select("main")),
            inf = ls * pipe.map(pipe.select("inf")),
            sup = ls * pipe.map(pipe.select("sup"))
        }
        end
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
            return (rLower > 0 and ceil or floor)(rLower), (rUpper > 0 and ceil or floor)(rUpper)
        else
            return calculate(incr(rLower), rLower == rUpper and rUpper or incr(rUpper))-- if else to prevent infinit loop
        end
    end
    return calculate(info.lower.r, info.upper.r)
end

local retriveExt = function(protos)
    local radFactorList = {A = 1, B = -1}
    local extHeightList = {upper = protos.info.tunnelHeight + protos.info.height, lower = protos.info.height}
    local extSlopeList = {upper = 1, lower = -1}
    local extSlope = protos.info.slope
    local extSlopeFactor = protos.info.slopeFactor or {upper = 1, lower = 1}
    local vRadius = protos.info.vRadius or {upper = 300, lower = 300}
    
    local prepareArc = function(proto, slope)
        return function(g)
            local config = {
                initRad = proto.radFn(g),
                slope = slope,
                height = extHeightList[proto.level],
                frac = protos.info.frac[proto.level][proto.part],
                radFactor = radFactorList[proto.part],
                r = proto.rFn(g),
                models = proto.models,
            }
            local fn = jA.retriveFn(config)
            return {
                guidelines = fn.retriveArc(proto.guidelineFn(g)),
                fn = fn,
                config = config,
            }
        end
    end
    
    local prepareArcs = function(proto)
        local oppositeHeight = {
            lower = extHeightList["upper"],
            upper = extHeightList["lower"],
        }
        
        local oppositeSlope = {
            lower = extSlopeList["upper"] * extSlope[proto.part] * extSlopeFactor[proto.level],
            upper = extSlopeList["lower"] * extSlope[proto.part] * extSlopeFactor[proto.level],
        }
        
        local opposite = {
            height = oppositeHeight[proto.level],
            slope = oppositeSlope[proto.level]
        }
        
        local height = extHeightList[proto.level]
        
        local slope = (abs(height) < abs(opposite.height) and proto.equalLength)
            and jA.solveSlope(jA.generateSlope(opposite.slope, opposite.height), height, vRadius[proto.level])
            or jA.generateSlope(extSlopeList[proto.level] * extSlope[proto.part] * extSlopeFactor[proto.level], height, vRadius[proto.level])
        
        return pipe.new
            * proto.group
            * pipe.map(prepareArc(proto, slope))
    end
    
    return {
        upper = {
            A = prepareArcs(protos.upper.A),
            B = prepareArcs(protos.upper.B)
        },
        lower = {
            A = prepareArcs(protos.lower.A),
            B = prepareArcs(protos.lower.B)
        }
    }
end

local function retriveX(fn, prepared)
    return {
        upper = {
            A = fn(prepared.upper.A),
            B = fn(prepared.upper.B)
        },
        lower = {
            A = fn(prepared.lower.A),
            B = fn(prepared.lower.B)
        }
    }
end

local function trackGroup(info, offsets)
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
    
    local limitRads = {
        lower = pipe.new * {
            inf = junction.normalizeRad(wallExt.lower.R:rad(func.min(wallExt.lower.R - wallExt.upper.L, ptXSelector))),
            mid = junction.normalizeRad(wallExt.lower.R:rad(coor.xy(0, 0))),
            sup = junction.normalizeRad(wallExt.lower.L:rad(func.min(wallExt.lower.L - wallExt.upper.R, ptXSelector))),
        },
        upper = pipe.new * {
            sup = junction.normalizeRad(wallExt.upper.R:rad(func.min(wallExt.upper.R - wallExt.lower.L, ptXSelector))),
            mid = junction.normalizeRad(wallExt.upper.R:rad(coor.xy(0, 0))),
            inf = junction.normalizeRad(wallExt.upper.L:rad(func.min(wallExt.upper.L - wallExt.lower.R, ptXSelector))),
        }
    }
    
    local result = {
        lower = pipe.new * {
            tracks = func.map(gRef.lower.tracks, function(l) return l:withLimits(limitRads.lower) end),
            simpleWalls = func.map(gRef.lower.walls, function(l)
                return l:withLimits(
                    {
                        inf = junction.normalizeRad(l:rad(func.min(l - wallExt.upper.L, ptXSelector))),
                        mid = junction.normalizeRad(l:rad(coor.xy(0, 0))),
                        sup = junction.normalizeRad(l:rad(func.min(l - wallExt.upper.R, ptXSelector))),
                    }) end),
            walls = pipe.new
            * func.map(gRef.lower.walls, function(l)
                return l:withLimits(
                    {
                        inf = junction.normalizeRad(l:rad(func.min(l - wallExt.upper.L, ptXSelector))),
                        mid = junction.normalizeRad(l:rad(coor.xy(0, 0))),
                        sup = junction.normalizeRad(l:rad(func.min(l - wallExt.upper.R, ptXSelector))),
                    }) end)
            * function(walls)
                for i = 1, #walls - 1 do walls[i].inf = walls[i + 1].inf end
                for i = #walls, 2, -1 do walls[i].sup = walls[i - 1].sup end
                return walls
            end
        }
        * function(ls) return func.with(ls,
            {
                extWalls = {
                    ls.walls[1]:withLimits(limitRads.lower *
                        pipe.with({mid = ls.walls[1].inf})),
                    ls.walls[#ls.walls]:withLimits(limitRads.lower *
                        pipe.with({mid = ls.walls[#ls.walls].sup})),
                },
                extSimpleWalls = {
                    ls.simpleWalls[1]:withLimits(limitRads.lower *
                        pipe.with({mid = ls.simpleWalls[1].inf})),
                    ls.simpleWalls[#ls.simpleWalls]:withLimits(limitRads.lower *
                        pipe.with({mid = ls.simpleWalls[#ls.simpleWalls].sup})),
                }
            }
        )
        end,
        upper = {
            tracks = func.map(gRef.upper.tracks, function(l) return l:withLimits(limitRads.upper) end),
            simpleWalls = func.map(gRef.upper.walls, function(l) return l:withLimits(limitRads.upper) end),
            walls = {
                wallExt.upper.L:withLimits(limitRads.upper
                    * pipe.with({mid = junction.normalizeRad(wallExt.upper.L:rad(func.min(wallExt.upper.L - wallExt.lower.L, ptXSelector)))})
                ),
                wallExt.upper.R:withLimits(limitRads.upper
                    * pipe.with({mid = junction.normalizeRad(wallExt.upper.R:rad(func.min(wallExt.upper.R - wallExt.lower.R, ptXSelector)))})
            )
            },
        }
    }
    
    local inferExt = function(guidelines, fnRad, r, rFactor)
        return pipe.new * func.map(guidelines,
            function(g)
                local p = g:pt(fnRad(g))
                local offset = r > 0 and g.xOffset or -g.xOffset
                local guideline = arc.byOR(p + (g.o - p):normalized() * (rFactor * (r - offset)), r - offset)
                return {
                    guideline = guideline,
                    rad = guideline:rad(p),
                    pt = p,
                    r = r
                }
            end)
    end
    
    local ext = {
        lower = {
            tracks = {
                inf = inferExt(result.lower.tracks, function(g) return g.inf end, info.lower.extR, info.lower.rFactor),
                sup = inferExt(result.lower.tracks, function(g) return g.sup end, info.lower.extR, info.lower.rFactor)
            },
            walls = {
                inf = inferExt(result.lower.walls, function(_) return limitRads.lower.inf end, info.lower.extR, info.lower.rFactor)
                * function(ls) return {ls[1], ls[#ls]} end
                ,
                sup = inferExt(result.lower.walls, function(_) return limitRads.lower.sup end, info.lower.extR, info.lower.rFactor)
                * function(ls) return {ls[1], ls[#ls]} end
            }
        },
        upper = {
            tracks = {
                inf = inferExt(result.upper.tracks, function(g) return g.inf end, info.upper.extR, info.upper.rFactor),
                sup = inferExt(result.upper.tracks, function(g) return g.sup end, info.upper.extR, info.upper.rFactor)
            },
            walls = {
                inf = inferExt(result.upper.walls, function(g) return g.inf end, info.upper.extR, info.upper.rFactor),
                sup = inferExt(result.upper.walls, function(g) return g.sup end, info.upper.extR, info.upper.rFactor)
            }
        }
    }
    
    return func.with(result, {ext = ext})
end

local function generateStructure(lowerGroup, upperGroup, mDepth, models)
    local function mPlace(guideline, rad1, rad2)
        local rad = rad2 and (rad1 + rad2) * 0.5 or rad1
        local pt = guideline:pt(rad)
        return coor.rotZ(rad) * coor.trans(func.with(pt, {z = -11})) * mDepth
    end
    local mPlaceD = function(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        return coor.rotZ(radc) * coor.trans(func.with(guideline:pt(radc), {z = -11}))
    end
    
    local makeExtWall = junction.makeFn(models.mSidePillar, mPlaceD, coor.scaleY(1.05))
    local makeExtWallFence = junction.makeFn(models.mRoofFenceS, mPlaceD, coor.scaleY(1.05))
    local makeWall = junction.makeFn(models.mSidePillar, mPlace, coor.scaleY(1.05))
    local makeRoof = junction.makeFn(models.mRoof, mPlace, coor.scaleY(1.05) * coor.transZ(0.05))
    local makeSideFence = junction.makeFn(models.mRoofFenceS, mPlace)
    
    
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
            station.newModel(models.mSidePillar, coor.rotZ(pi * 0.5), coor.scaleX(1.1), coor.transY(-0.25), mPlace(t, t.inf)),
            station.newModel(models.mSidePillar, coor.rotZ(pi * 0.5), coor.scaleX(1.1), coor.transY(0.25), mPlace(t, t.sup)),
        }
    end)
    
    local fences = func.map(trackSets, function(t)
        local m = coor.scaleX(1.091) * coor.transY(0.18)
        return {
            station.newModel(models.mRoofFenceF, m, mPlace(t, t.inf)),
            station.newModel(models.mRoofFenceF, m, coor.flipY(), mPlace(t, t.sup)),
        }
    end)
    
    local sideFencesL = func.map(lowerGroup.walls, function(t)
        return t:withLimits({
            sup = t:rad(func.min(upperGroup.walls[1] - t, ptXSelector)),
            mid = t:rad(func.min(upperGroup.walls[1] - t, ptXSelector)),
            inf = t.inf,
        })
    end)
    
    local sideFencesR = func.map(lowerGroup.walls, function(t)
        return t:withLimits({
            inf = t:rad(func.min(upperGroup.walls[2] - t, ptXSelector)),
            mid = t:rad(func.min(upperGroup.walls[2] - t, ptXSelector)),
            sup = t.sup,
        })
    end)
    
    return {
        {
            fixed = pipe.new
            + func.mapFlatten(walls, function(w) return makeWall(w)[1] end)
            + func.map(fences, function(f) return f[1] end)
            + func.mapFlatten(trackSets, function(t) return makeRoof(t)[1] end)
            + func.mapFlatten(upperGroup.tracks, function(t) return makeRoof(t)[1] end)
            + func.mapFlatten(sideFencesL, function(t) return makeSideFence(t)[1] end)
            + func.mapFlatten(sideFencesR, function(t) return makeSideFence(t)[1] end)
            ,
            upper = pipe.new
            + makeSideFence(upperGroup.walls[2])[1]
            + makeWall(upperGroup.walls[2])[1]
            + func.map(upperFences, pipe.select(1))
            ,
            lower = pipe.new
            + makeExtWall(lowerGroup.extWalls[1])[1]
            + makeExtWallFence(lowerGroup.extWalls[1])[1]
        }
        ,
        {
            fixed = pipe.new
            + func.mapFlatten(walls, function(w) return makeWall(w)[2] end)
            + func.map(fences, function(f) return f[2] end)
            + func.mapFlatten(trackSets, function(t) return makeRoof(t)[2] end)
            + func.mapFlatten(upperGroup.tracks, function(t) return makeRoof(t)[2] end)
            + func.mapFlatten(sideFencesL, function(t) return makeSideFence(t)[2] end)
            + func.mapFlatten(sideFencesR, function(t) return makeSideFence(t)[2] end)
            ,
            upper = pipe.new
            + makeSideFence(upperGroup.walls[1])[2]
            + makeWall(upperGroup.walls[1])[2]
            + func.map(upperFences, pipe.select(2))
            ,
            lower = pipe.new
            + makeExtWall(lowerGroup.extWalls[2])[2]
            + makeExtWallFence(lowerGroup.extWalls[2])[2]
        }
    }
end


local slopeWalls = function(
    info,
    models,
    tunnelHeight,
    extA, mainA,
    extB, mainB,
    upperL, upperR
    )
    local function retriveRef(result, arc, ...)
        return arc
            and retriveRef(result / (result[#result] + abs(arc.inf - arc.sup) * arc.r), ...)
            or result
    end
    
    return pipe.new
        / func.map2(info.A.upper.isTerra and extA or {}, mainA,
            function(w, cw)
                return {
                    guidelines = func.filter({
                        cw:withLimits({sup = cw.inf, inf = mainA[#mainA].inf}),
                        w.guidelines[2],
                        w.guidelines[1]
                    }, function(g) return abs(g.inf - g.sup) * g.r > 0.1 end),
                    lower = w.guidelines[2],
                    another = w.guidelines[1],
                    upper = upperL.guidelines[1],
                    fz = upperL.fn.fz,
                    from = "sup", to = "inf"
                }
            end)
        / func.map2(info.B.upper.isTerra and extB or {}, mainB,
            function(w, cw)
                return {
                    guidelines = func.filter({
                        cw:withLimits({inf = cw.sup, sup = mainB[1].sup}),
                        w.guidelines[1],
                        w.guidelines[2]
                    }, function(g) return abs(g.inf - g.sup) * g.r > 0.1 end),
                    lower = w.guidelines[1],
                    another = w.guidelines[2],
                    upper = upperR.guidelines[1],
                    fz = upperR.fn.fz,
                    from = "inf", to = "sup"
                }
            end)
        * pipe.map(function(ws) return {ws[1], ws[#ws]} end)
        * pipe.flatten()
        * pipe.mapFlatten(function(sw)
            local arcs = pipe.new
                * sw.guidelines
                * pipe.map(function(g)
                    local loc = detectSlopeIntersection(g, sw.upper, sw.fz, g[sw.from], g[sw.to] - g[sw.from])
                    local floc = abs(loc - g[sw.from]) < abs(g[sw.from] - g[sw.to]) and loc or g[sw.to]
                    return g:withLimits({
                        [sw.from] = g[sw.from],
                        [sw.to] = floc,
                        mid = (g[sw.from] + floc) * 0.5
                    })
                end
                )
                * pipe.filter(function(ar) return abs(ar.inf - ar.sup) * ar.r > 0.01 end)
            
            return retriveRef(pipe.new * {0}, table.unpack(arcs))
                * function(ls) return ls * pipe.map(pipe.mul(1 / ls[#ls])) end
                * function(ls) return func.zip(ls * pipe.range(1, #ls - 1), ls * pipe.range(2, #ls), {"f", "t"}) end
                * pipe.map2(arcs, function(r, ar) return func.with(ar, r) end)
                * pipe.mapFlatten(function(arc)
                    local mPlace = mPlaceSlopeWall(sw, arc, tunnelHeight)
                    return {
                        junction.makeFn(models.mSidePillar, mPlace, coor.scaleY(1.05))(arc),
                        junction.makeFn(models.mRoofFenceS, mPlace, coor.scaleY(1.05))(arc)
                    }
                end)
        end)
        * pipe.flatten()
        * pipe.flatten()
end

local function params(paramFilter)
    local sp = "·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·:·\n"
    return (junction.trackType
        + 
        {
            func.with(paramsutil.makeTrackCatenaryParam(),
                {
                    values = {_("None"), _("Both"), _("Lower"), _("Upper")},
                    defaultIndex = 0
                }),
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
                key = "sLower",
                name = sp,
                values = {"+", "-"},
                defaultIndex = 0
            },
            {
                key = "rLower",
                name = _("Radius of lower tracks"),
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "sUpper",
                name = sp,
                values = {"+", "-"},
                defaultIndex = 0
            },
            {
                key = "rUpper",
                name = _("Radius of upper tracks"),
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "transitionA",
                name = sp .. "\n" .. _("Transition A"),
                values = {_("Both"), _("Lower"), _("Upper"), _("None")},
                defaultIndex = 0
            },
            {
                key = "trSlopeA",
                name = _("Slope") .. " (‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList * 0.5
            },
            {
                key = "trSRadiusA",
                name = nil,
                values = {"+", "-"},
                defaultIndex = 0
            },
            {
                key = "trRadiusA",
                name = _("Radius") .. "(m)",
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "trLengthUpperA",
                name = _("Upper tracks length") .. " (%)",
                values = func.map(lengthPercentList, function(l) return tostring(l * 100) end),
                defaultIndex = 0
            },
            {
                key = "trLengthLowerA",
                name = _("Lower tracks length") .. " (%)",
                values = func.map(lengthPercentList, function(l) return tostring(l * 100) end),
                defaultIndex = 0
            },
            {
                key = "typeSlopeA",
                name = _("Form"),
                values = {_("Bridge"), _("Terra"), _("Solid")},
                defaultIndex = 1
            },
            {
                key = "transitionB",
                name = sp .. "\n" .. _("Transition B"),
                values = {_("Both"), _("Lower"), _("Upper"), _("None")},
                defaultIndex = 0
            },
            {
                key = "trSlopeB",
                name = _("Slope") .. " (‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList * 0.5
            },
            {
                key = "trSRadiusB",
                name = nil,
                values = {"+", "-"},
                defaultIndex = 0
            },
            {
                key = "trRadiusB",
                name = _("Radius") .. "(m)",
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(floor(r * 1000 + 0.5)) end),
                defaultIndex = 0
            },
            {
                key = "trLengthUpperB",
                name = _("Upper tracks length") .. " (%)",
                values = func.map(lengthPercentList, function(l) return tostring(l * 100) end),
                defaultIndex = 0
            },
            {
                key = "trLengthLowerB",
                name = _("Lower tracks length") .. " (%)",
                values = func.map(lengthPercentList, function(l) return tostring(l * 100) end),
                defaultIndex = 0
            },
            {
                key = "typeSlopeB",
                name = _("Form"),
                values = {_("Bridge"), _("Terra"), _("Solid")},
                defaultIndex = 1
            },
            {
                key = "isMir",
                name = sp .. "\n" .. _("Mirrored"),
                values = {_("No"), _("Yes")},
                defaultIndex = 0
            },
            {
                key = "slopeSign",
                name = sp,
                values = {"+", "-"},
                defaultIndex = 0
            },
            {
                key = "slope",
                name = _("General Slope") .. " (‰)",
                values = func.map(slopeList, tostring),
                defaultIndex = 0
            },
            {
                key = "slopeLevel",
                name = _("Axis"),
                values = {_("Lower"), _("Upper"), _("Common")},
                defaultIndex = 0
            },
            {
                key = "heightTunnel",
                name = sp .. "\n" .. _("Tunnel Height") .. " (m)",
                values = func.map(tunnelHeightList, tostring),
                defaultIndex = #tunnelHeightList - 2
            },
            {
                key = "height",
                name = _("Altitude Adjustment"),
                values = func.map(heightList, function(h) return tostring(ceil(h * 100)) .. "%" end),
                defaultIndex = 6
            }
        }
        )
        * pipe.filter(function(p) return not func.contains(paramFilter, p.key) end)
end

local function defaultParams(param, fParams)
    local function limiter(d, u)
        return function(v) return v and v < u and v or d end
    end
    
    func.forEach(params({}), function(i)param[i.key] = limiter(i.defaultIndex or 0, #i.values)(param[i.key]) end)
    
    fParams(param)
end

local updateFn = function(fParams, models)
    return function(params)
            
            defaultParams(params, fParams)
            
            local deg = listDegree[params.xDegDec + 1] + params.xDegUni
            local rad = math.rad(deg)
            
            local trackTypeLower = junction.trackList[params.trackType + 1]
            local trackTypeUpper = params.trackTypeUpper == 0 and trackTypeLower or junction.trackList[params.trackTypeUpper]
            local catenaryLower = func.contains({1, 2}, params.catenary)
            local catenaryUpper = func.contains({1, 3}, params.catenary)
            local nbPerGroup = ({1, 2, params.nbLowerTracks + 1})[params.nbPerGroup + 1]
            local tunnelHeight = tunnelHeightList[params.heightTunnel + 1]
            local heightFactor = heightList[params.height + 1]
            local depth = ((heightFactor > 1 and 1 or heightFactor) - 1) * tunnelHeight
            local mDepth = coor.transZ(depth)
            local extraZ = heightFactor > 1 and ((heightFactor - 1) * tunnelHeight) or 0
            local mTunnelZ = coor.transZ(tunnelHeight)
            
            local lowerTrackBuilder = trackEdge.builder(catenaryLower, trackTypeLower)
            local upperTrackBuilder = trackEdge.builder(catenaryUpper, trackTypeUpper)
            local buildLowerTracks = lowerTrackBuilder.nonAligned()
            local buildUpperTracks = upperTrackBuilder.nonAligned()
            local buildBridge = upperTrackBuilder.bridge(models.bridgeType)
            local retriveR = function(param) return rList[param + 1] * 1000 end
            
            local info = {
                A = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerA * (params.sLower == 1 and 1 or -1) * (params.type == 3 and -1 or 1),
                        rFactor = params.fRLowerA * (params.sLower == 1 and 1 or -1) * (params.type == 3 and -1 or 1),
                        rad = 0,
                        used = func.contains({0, 1}, params.transitionA),
                        isBridge = false,
                        isTerra = false,
                        extR = (params.trSRadiusA == 0 and 1 or -1) * retriveR(params.trRadiusA)
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperA * (params.sUpper == 0 and 1 or -1),
                        rFactor = params.fRUpperA * (params.sUpper == 0 and 1 or -1),
                        rad = rad,
                        used = func.contains({0, 2}, params.transitionA),
                        isBridge = params.typeSlopeA == 0 or not func.contains({0, 2}, params.transitionA),
                        isTerra = params.typeSlopeA == 1 and func.contains({0, 2}, params.transitionA) and params.type ~= 2,
                        extR = (params.trSRadiusA == 0 and 1 or -1) * retriveR(params.trRadiusA)
                    }
                },
                B = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerB * (params.sLower == 1 and 1 or -1) * (params.type == 3 and -1 or 1),
                        rFactor = params.fRLowerB * (params.sLower == 1 and 1 or -1) * (params.type == 3 and -1 or 1),
                        rad = 0,
                        used = func.contains({0, 1}, params.transitionB),
                        isBridge = false,
                        isTerra = false,
                        extR = (params.trSRadiusB == 0 and 1 or -1) * retriveR(params.trRadiusB)
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperB * (params.sUpper == 0 and 1 or -1),
                        rFactor = params.fRUpperB * (params.sUpper == 0 and 1 or -1),
                        rad = rad,
                        used = func.contains({0, 2}, params.transitionB),
                        isBridge = params.typeSlopeB == 0 or not func.contains({0, 2}, params.transitionB),
                        isTerra = params.typeSlopeB == 1 and func.contains({0, 2}, params.transitionB) and params.type ~= 2,
                        extR = (params.trSRadiusB == 0 and 1 or -1) * retriveR(params.trRadiusB)
                    }
                }
            }
            
            local offsets = {
                lower = junction.buildCoors(info.A.lower.nbTracks, nbPerGroup),
                upper = junction.buildCoors(info.A.upper.nbTracks, info.A.upper.nbTracks)
            }
            
            local group = {
                A = trackGroup(info.A, offsets),
                B = trackGroup(info.B, offsets)
            }
            
            local ext, preparedExt = (function()
                local extEndList = {A = "inf", B = "sup"}
                local extConfig = {
                    straight = function(equalLength)
                        return function(part, level, type)
                            return {
                                group = group[part].ext[level][type][extEndList[part]],
                                models = models,
                                radFn = function(g) return g.rad end,
                                rFn = function(g) return g.r end,
                                guidelineFn = function(g) return g.guideline end,
                                part = part,
                                level = level,
                                equalLength = equalLength or false,
                            } end
                    end,
                    curve = function(equalLength)
                        return function(part, level, type) return {
                            group = group[part][level][type],
                            models = models,
                            radFn = function(_) return group[part][level].tracks[1][extEndList[part]] end,
                            rFn = function(g) return info[part][level].rFactor * g.r end,
                            guidelineFn = function(g) return g end,
                            part = part,
                            level = level,
                            equalLength = equalLength or false,
                        } end
                    end
                }
                
                local extProtos = function(type) return {
                    upper = {
                        A = pipe.from("A", "upper", type) * (func.contains({3, 1}, params.type) and extConfig.curve() or extConfig.straight(true)),
                        B = pipe.from("B", "upper", type) * (func.contains({1}, params.type) and extConfig.curve() or extConfig.straight(true))
                    },
                    lower = {
                        A = pipe.from("A", "lower", type) * (func.contains({3, 1}, params.type) and extConfig.curve() or extConfig.straight(true)),
                        B = pipe.from("B", "lower", type) * (func.contains({1}, params.type) and extConfig.curve() or extConfig.straight(true))
                    },
                    info = {
                        height = depth,
                        tunnelHeight = tunnelHeight,
                        slope = {
                            A = trSlopeList[params.trSlopeA + 1] * 0.001,
                            B = trSlopeList[params.trSlopeB + 1] * 0.001
                        },
                        frac = {
                            lower = {
                                A = heightFactor >= 1 and 1 or lengthPercentList[params.trLengthLowerA + 1],
                                B = heightFactor >= 1 and 1 or lengthPercentList[params.trLengthLowerB + 1]
                            },
                            upper = {
                                A = heightFactor == 0 and 1 or lengthPercentList[params.trLengthUpperA + 1],
                                B = heightFactor == 0 and 1 or lengthPercentList[params.trLengthUpperB + 1]
                            }
                        }
                    }
                }
                end
                
                local preparedExt = {
                    tracks = retriveExt(extProtos("tracks")),
                    walls = retriveExt(extProtos("walls"))
                }
                
                return {
                    edges = retriveX(jA.retriveTracks, preparedExt.tracks),
                    polys = retriveX(jA.retrivePolys(), preparedExt.tracks),
                    surface = retriveX(jA.retriveTrackSurfaces, preparedExt.tracks),
                    walls = retriveX(jA.retriveWalls, preparedExt.walls)
                }, preparedExt
            end)()
            
            local trackEdges = {
                lower = generateTrackGroups(group.A.lower.tracks, group.B.lower.tracks, {mpt = mDepth, mvec = coor.I()}),
                upper = generateTrackGroups(group.A.upper.tracks, group.B.upper.tracks, {mpt = mTunnelZ * mDepth, mvec = coor.I()})
            }
            
            local upperPolys = {
                A = junction.generatePolyArc(group.A.upper.tracks, "inf", "mid")(0, 3.5),
                B = junction.generatePolyArc(group.B.upper.tracks, "mid", "sup")(0, 3.5)
            }
            
            local lowerPolys = {
                A = junction.generatePolyArc(group.A.lower.tracks, "inf", "mid")(4, 3.5),
                B = junction.generatePolyArc(group.B.lower.tracks, "mid", "sup")(4, 3.5)
            }
            
            local function selectEdge(level)
                return (pipe.new
                    + (
                    info.A[level].used
                    and {
                        ext.edges[level].A.inf,
                        ext.edges[level].A.main
                    }
                    or {trackEdges[level].inf}
                    )
                    + {trackEdges[level].main}
                    + (
                    info.B[level].used
                    and {
                        ext.edges[level].B.main,
                        ext.edges[level].B.sup
                    }
                    or {trackEdges[level].sup}
                    ))
                    * station.fusionEdges
                    ,
                    pipe.new
                    + (info.A[level].used and (info.A[level].isBridge and {true, true} or {false, false}) or {true})
                    + {false}
                    + (info.B[level].used and (info.B[level].isBridge and {true, true} or {false, false}) or {true})
            end
            
            local lowerEdges, _ = selectEdge("lower")
            local upperEdges, upperBridges = selectEdge("upper")
            
            local bridgeEdges = upperEdges
                * pipe.zip(upperBridges, {"e", "b"})
                * pipe.filter(function(e) return e.b end)
                * pipe.map(pipe.select("e"))
            
            local solidEdges = upperEdges
                * pipe.zip(upperBridges, {"e", "b"})
                * pipe.filter(function(e) return not e.b end)
                * pipe.map(pipe.select("e"))
            
            local edges = {
                lowerEdges * pipe.map(station.mergeEdges) * station.prepareEdges * buildLowerTracks,
                solidEdges * pipe.map(station.mergeEdges) * station.prepareEdges * buildUpperTracks,
                bridgeEdges * pipe.map(station.mergeEdges) * station.prepareEdges * buildBridge,
            }
            
            local structure = {
                A = generateStructure(group.A.lower, group.A.upper, mTunnelZ * mDepth, models)[1],
                B = generateStructure(group.B.lower, group.B.upper, mTunnelZ * mDepth, models)[2]
            }
            
            local slopeWallModels =
                slopeWalls(
                    info,
                    models,
                    tunnelHeight * heightFactor,
                    preparedExt.walls.lower.A, group.A.lower.walls,
                    preparedExt.walls.lower.B, group.B.lower.walls,
                    preparedExt.walls.upper.A[1],
                    preparedExt.walls.upper.B[#preparedExt.walls.upper.B]
            )
            
            local uPolys = function(part)
                local i = info[part].upper
                local polySet = ext.polys.upper[part]
                return (not i.used or i.isBridge)
                    and {}
                    or (
                    i.isTerra
                    and {
                        equal = station.projectPolys(coor.I())(polySet.trackPolys)
                    }
                    or {
                        greater = station.projectPolys(coor.I())(polySet.polys),
                        less = station.projectPolys(coor.I())(polySet.trackPolys)
                    }
            )
            end
            
            local slopeWallArcs = pipe.new
                / func.map(info.A.upper.isTerra and preparedExt.tracks.lower.A or {},
                    function(w)
                        return {
                            lower = w.guidelines[2]:withLimits({inf = w.guidelines[1]:extendLimits(4).inf}),
                            upper = preparedExt.walls.upper.A[1].guidelines[1],
                            fz = preparedExt.walls.upper.A[1].fn.fz,
                            from = "sup", to = "inf"
                        }
                    end)
                / func.map(info.B.upper.isTerra and preparedExt.tracks.lower.B or {},
                    function(w)
                        return {
                            lower = w.guidelines[1]:withLimits({sup = w.guidelines[2]:extendLimits(4).sup}),
                            upper = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].guidelines[1],
                            fz = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].fn.fz,
                            from = "inf", to = "sup"
                        }
                    end)
                * pipe.map(pipe.map(function(sw)
                    local loc = func.min(
                        func.map(
                            {sw.lower + 2.5, sw.lower + (-2.5)},
                            function(a) return detectSlopeIntersection(a, sw.upper, sw.fz, a[sw.from], a[sw.to] - a[sw.from]) end),
                        function(l, r) return abs(l - sw.lower[sw.to]) < abs(r - sw.lower[sw.to]) end)
                    
                    return sw.lower:withLimits({
                        [sw.from] = loc,
                        [sw.to] = sw[sw.to],
                    })
                end
                ))
                * pipe.map(pipe.map(function(ar) return junction.generatePolyArc({ar, ar}, "inf", "sup")(0, 2.5) end))
                * function(ls) return {A = func.flatten(ls[1]), B = func.flatten(ls[2])} end
            
            local lPolys = function(part)
                local i = info[part].lower
                local polySet = ext.polys.lower[part]
                return (not i.used)
                    and {}
                    or {
                        less = station.projectPolys(coor.I())(info[part].upper.isTerra and slopeWallArcs[part] or polySet.polys),
                        slot = station.projectPolys(coor.I())(polySet.trackPolys),
                        greater = station.projectPolys(coor.I())(polySet.trackPolys)
                    }
            end
            
            local uXPolys = {
                equal = pipe.new
                + ((info.A.upper.isTerra or heightFactor == 0) and station.projectPolys(mTunnelZ * mDepth)(upperPolys.A) or {})
                + ((info.B.upper.isTerra or heightFactor == 0) and station.projectPolys(mTunnelZ * mDepth)(upperPolys.B) or {})
                ,
                less = pipe.new
                + ((not info.A.upper.isTerra and heightFactor ~= 0) and station.projectPolys(mTunnelZ * mDepth)(upperPolys.A) or {})
                + ((not info.B.upper.isTerra and heightFactor ~= 0) and station.projectPolys(mTunnelZ * mDepth)(upperPolys.B) or {})
                ,
                greater = pipe.new + (info.A.upper.isTerra and {} or station.projectPolys(mDepth)(upperPolys.A))
                + (info.B.upper.isTerra and {} or station.projectPolys(mDepth)(upperPolys.B))
            }
            
            local lXPolys = {
                less = station.projectPolys(coor.I())(info.A.upper.isTerra and {} or lowerPolys.A, info.B.upper.isTerra and {} or lowerPolys.B),
                slot = station.projectPolys(mDepth * coor.transZ(-0.2))(lowerPolys.A, lowerPolys.B),
                greater = station.projectPolys(mDepth)(lowerPolys.A, lowerPolys.B)
            }

            local function withIfNotBridge(level, part)
                return function(c)
                    return (info[part][level].used and not info[part][level].isBridge) and c or {}
                end
            end
            
            local function withIfSolid(level, part)
                return function(c)
                    return (info[part][level].used and not info[part][level].isTerra and not info[part][level].isBridge) and c or {}
                end
            end

            local result = {
                edgeLists = edges,
                models = pipe.new
                + structure.A.fixed
                + structure.B.fixed
                + withIfSolid("upper", "A")(ext.surface.upper.A)
                + withIfSolid("upper", "B")(ext.surface.upper.B)
                + (heightFactor > 0
                and pipe.new
                + structure.A.upper
                + structure.B.upper
                + withIfSolid("upper", "A")(ext.walls.upper.A * pipe.flatten())
                + withIfSolid("upper", "B")(ext.walls.upper.B * pipe.flatten())
                or {}
                )
                + (heightFactor < 1
                and pipe.new
                + structure.A.lower
                + structure.B.lower
                + withIfNotBridge("lower", "A")(ext.walls.lower.A[1])
                + withIfNotBridge("lower", "A")(ext.walls.lower.A[#ext.walls.lower.A])
                + withIfNotBridge("lower", "B")(ext.walls.lower.B[1])
                + withIfNotBridge("lower", "B")(ext.walls.lower.B[#ext.walls.lower.B])
                or {})
                + slopeWallModels
                ,
                terrainAlignmentLists = station.mergePoly(uXPolys, uPolys("A"), uPolys("B"))() + station.mergePoly(lXPolys, lPolys("A"), lPolys("B"))()
                ,
                groundFaces = (pipe.new
                + upperPolys.A
                + upperPolys.B
                + lowerPolys.A
                + lowerPolys.B
                + ((info.A.lower.used and not info.A.lower.isBridge) and ext.polys.lower.A.polys or {})
                + ((info.B.lower.used and not info.B.lower.isBridge) and ext.polys.lower.B.polys or {})
                + ((info.A.upper.used and not info.A.upper.isBridge) and ext.polys.upper.A.polys or {})
                + ((info.B.upper.used and not info.B.upper.isBridge) and ext.polys.upper.B.polys or {})
                )
                * pipe.mapFlatten(function(p)
                    return {
                        {face = func.map(p, coor.vec2Tuple), modes = {{type = "FILL", key = "building_paving_fill"}}},
                        {face = func.map(p, coor.vec2Tuple), modes = {{type = "STROKE_OUTER", key = "building_paving"}}}
                    }
                end)
            }
            
            -- End of generation
            -- Slope, Height, Mirror treatment
            return pipe.new
                * result
                * station.setRotation(({0, 1, 0.5})[params.slopeLevel + 1] * rad)
                * station.setSlope((params.slopeSign == 0 and 1 or -1) * (slopeList[params.slope + 1]))
                * station.setRotation(({0, -1, -0.5})[params.slopeLevel + 1] * rad)
                * station.setHeight(extraZ)
                * station.setMirror(params.isMir == 1)
    end
end

return {
    updateFn = updateFn,
    params = params,
    rList = rList,
    generateTrackGroups = generateTrackGroups,
    detectSlopeIntersection = detectSlopeIntersection,
    mPlaceSlopeWall = mPlaceSlopeWall,
    generateStructure = generateStructure,
    retriveX = retriveX,
    retriveExt = retriveExt,
    trackGroup = trackGroup,
    slopeWalls = slopeWalls
}
