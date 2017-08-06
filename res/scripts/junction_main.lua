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

local mSidePillar = "station/concrete_flying_junction/infra_junc_pillar_side.mdl"
local mRoofFenceF = "station/concrete_flying_junction/infra_junc_roof_fence_front.mdl"
local mRoofFenceS = "station/concrete_flying_junction/infra_junc_roof_fence_side.mdl"
local mRoof = "station/concrete_flying_junction/infra_junc_roof.mdl"
local bridgeType = "z_concrete_flying_junction.lua"

local listDegree = {5, 10, 20, 30, 40, 50, 60, 70, 80}
local rList = {junction.infi * 0.001, 1, 4 / 5, 2 / 3, 3 / 5, 1 / 2, 1 / 3, 1 / 4, 1 / 5, 1 / 6, 1 / 8, 1 / 10, 1 / 20}

local trSlopeList = {15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 80, 90, 100}
local slopeList = {0, 10, 20, 25, 30, 35, 40, 50, 60}
local heightList = {0, 1 / 4, 1 / 3, 1 / 2, 2 / 3, 3 / 4, 1, 1.1, 1.2, 1.25, 1.5}
local tunnelHeightList = {11, 10, 9.5, 8.7}

local ptXSelector = function(lhs, rhs) return lhs:length2() < rhs:length2() end

local projectPolys = function(mDepth)
    return function(...)
        return pipe.new * func.flatten({...}) * pipe.map(pipe.map(mDepth)) * pipe.map(pipe.map(coor.vec2Tuple))
    end
end

local mPlaceSlopeWall = function(sw, arc, upperHeight)
    return function(guideline, rad1, rad2)
        local rad = rad2 and (rad1 + rad2) * 0.5 or rad1
        local h1 = upperHeight * (rad2 - rad1) / (arc[sw.from] - arc[sw.to])
        local h = upperHeight * (rad - arc[sw.to]) / (arc[sw.from] - arc[sw.to])
        local pt = guideline:pt(rad)
        return coor.shearZoY(h1 / math.abs(rad2 - rad1) / guideline.r) * coor.rotZ(junction.regularizeRad(rad)) * coor.trans(func.with(pt, {z = h - 11}))
    end
end

local function detectSlopeIntersection(lower, upper, fz, currentRad, s)
    local step = 1 / lower.r
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
        return r == 0 and 0 or (r > 0 and r + 0.1 or r - 0.1)
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

local retriveExt = function(protos)
    local radFactorList = {A = 1, B = -1}
    local extHeightList = {upper = protos.info.tunnelHeight + protos.info.height, lower = protos.info.height}
    local extSlopeList = {upper = 1, lower = -1, A = protos.info.slopeA, B = protos.info.slopeB}
    
    
    local prepareArc = function(proto, slope)
        return function(g)
            local config = {
                initRad = proto.radFn(g),
                slope = slope,
                height = extHeightList[proto.level],
                radFactor = radFactorList[proto.part],
                r = proto.rFn(g),
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
            lower = extSlopeList["upper"] * extSlopeList[proto.part],
            upper = extSlopeList["lower"] * extSlopeList[proto.part],
        }
        
        local opposite = {
            height = oppositeHeight[proto.level],
            slope = oppositeSlope[proto.level]
        }
        
        local height = extHeightList[proto.level]
        
        local slope = (abs(height) < abs(opposite.height) and proto.equalLength)
            and jA.solveSlope(jA.generateSlope(opposite.slope, opposite.height), height)
            or jA.generateSlope(extSlopeList[proto.level] * extSlopeList[proto.part], height)
        
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
        lower = pipe.new * {
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
        }
        * function(ls) return func.with(ls,
            {
                extWalls = {
                    ls.walls[1]:withLimits({
                        inf = limitRads.lower.inf,
                        mid = ls.walls[1].inf,
                        sup = limitRads.lower.sup,
                    }),
                    ls.walls[#ls.walls]:withLimits({
                        inf = limitRads.lower.inf,
                        mid = ls.walls[#ls.walls].sup,
                        sup = limitRads.lower.sup,
                    }),
                }
            }
        )
        end,
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
    
    local inferExt = function(guidelines, fnRad)
        return pipe.new * func.map(guidelines,
            function(g)
                local p = g:pt(fnRad(g))
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
                inf = inferExt(result.lower.tracks, function(g) return g.inf end),
                sup = inferExt(result.lower.tracks, function(g) return g.sup end)
            },
            walls = {
                inf = inferExt(result.lower.walls, function(_) return limitRads.lower.inf end)
                * function(ls) return {ls[1], ls[#ls]} end
                ,
                sup = inferExt(result.lower.walls, function(_) return limitRads.lower.sup end)
                * function(ls) return {ls[1], ls[#ls]} end
            }
        },
        upper = {
            tracks = {
                inf = inferExt(result.upper.tracks, function(g) return g.inf end),
                sup = inferExt(result.upper.tracks, function(g) return g.sup end)
            },
            walls = {
                inf = inferExt(result.upper.walls, function(g) return g.inf end),
                sup = inferExt(result.upper.walls, function(g) return g.sup end)
            }
        }
    }
    
    return func.with(result, {ext = ext})
end

local function generateStructure(lowerGroup, upperGroup, mDepth)
    local function mPlace(guideline, rad1, rad2)
        local rad = rad2 and (rad1 + rad2) * 0.5 or rad1
        local pt = guideline:pt(rad)
        return coor.rotZ(junction.regularizeRad(rad)) * coor.trans(func.with(pt, {z = -11})) * mDepth
    end
    local mPlaceD = function(guideline, rad1, rad2)
        local radc = (rad1 + rad2) * 0.5
        return coor.rotZ(junction.regularizeRad(radc)) * coor.trans(func.with(guideline:pt(radc), {z = -11}))
    end
    
    local makeExtWall = junction.makeFn(mSidePillar, mPlaceD, coor.scaleY(1.05))
    local makeExtWallFence = junction.makeFn(mRoofFenceS, mPlaceD, coor.scaleY(1.05))
    local makeWall = junction.makeFn(mSidePillar, mPlace, coor.scaleY(1.05))
    local makeRoof = junction.makeFn(mRoof, mPlace, coor.scaleY(1.05) * coor.transZ(0.1))
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
            station.newModel(mSidePillar, coor.rotZ(pi * 0.5), coor.scaleX(0.55), coor.transY(-0.25), mPlace(t, t.inf)),
            station.newModel(mSidePillar, coor.rotZ(pi * 0.5), coor.scaleX(0.55), coor.transY(0.25), mPlace(t, t.sup)),
        }
    end)
    
    local fences = func.map(trackSets, function(t)
        local m = coor.scaleX(1.091) * coor.transY(0.18) * coor.transZ(-1) * coor.centered(coor.scaleZ, 3.5 / 1.5, coor.xyz(0, 0, 10.75))
        return {
            station.newModel(mRoofFenceF, m, mPlace(t, t.inf)),
            station.newModel(mRoofFenceF, m, coor.flipY(), mPlace(t, t.sup)),
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
            + makeSideFence(sideFencesL[1])[1]
            + makeSideFence(upperGroup.walls[2])[1]
            + makeWall(upperGroup.walls[2])[1]
            + func.map(upperFences, function(f) return f[1] end)
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
            ,
            upper = pipe.new
            + makeSideFence(sideFencesR[#sideFencesR])[2]
            + makeSideFence(upperGroup.walls[1])[2]
            + makeWall(upperGroup.walls[1])[2]
            + func.map(upperFences, function(f) return f[2] end)
            ,
            lower = pipe.new
            + makeExtWall(lowerGroup.extWalls[2])[2]
            + makeExtWallFence(lowerGroup.extWalls[2])[2]
        }
    }
end

local function mergePoly(...)
    local polys = pipe.new * {...}
    local p = {
        equal = polys * pipe.map(pipe.select("equal", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        less = polys * pipe.map(pipe.select("less", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        greater = polys * pipe.map(pipe.select("greater", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        slot = polys * pipe.map(pipe.select("slot", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
    }
    
    return pipe.new * {
        {
            type = "LESS",
            faces = p.less,
            slopeLow = 0.75,
            slopeHigh = 0.75,
        },
        {
            type = "GREATER",
            faces = p.greater,
            slopeLow = 0.75,
            slopeHigh = 0.75,
        },
        {
            type = "EQUAL",
            faces = p.equal,
            slopeLow = 0.75,
            slopeHigh = 0.75,
        },
        {
            type = "LESS",
            faces = p.slot,
            slopeLow = junction.infi,
            slopeHigh = junction.infi,
        },
    }
    * pipe.filter(function(e) return #e.faces > 0 end)
end

local function params(paramFilter, defaultValue)
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
                values = pipe.from("∞") + func.map(func.range(rList, 2, #rList), function(r) return tostring(floor(r * 1000 + 0.5)) end),
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
                name = _("Transition A"),
                values = {_("Both"), _("Lower"), _("Upper"), _("None")},
                defaultIndex = 0
            },
            {
                key = "trSlopeA",
                name = _("Transition A slope") .. "(‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList * 0.5
            },
            {
                key = "typeSlopeA",
                name = _("Form of asc. tr. A"),
                values = {_("Solid"), _("Bridge"), _("Terra")},
                defaultIndex = 0
            },
            {
                key = "transitionB",
                name = _("Transition B"),
                values = {_("Both"), _("Lower"), _("Upper"), _("None")},
                defaultIndex = 0
            },
            {
                key = "trSlopeB",
                name = _("Transition B slope") .. "(‰)",
                values = func.map(trSlopeList, tostring),
                defaultIndex = #trSlopeList * 0.5
            },
            {
                key = "typeSlopeB",
                name = _("Form of asc. tr. B"),
                values = {_("Solid"), _("Bridge"), _("Terra")},
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
                name = _("General Slope(‰)"),
                values = func.map(slopeList, tostring),
                defaultIndex = 0
            },
            {
                key = "height",
                name = _("Altitude Adjustment"),
                values = func.map(heightList, function(h) return tostring(ceil(h * 100)) .. "%" end),
                defaultIndex = 6
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
            local heightFactor = heightList[params.height + 1]
            local depth = ((heightFactor > 1 and 1 or heightFactor) - 1) * tunnelHeight
            local mDepth = coor.transZ(depth)
            local extraZ = heightFactor > 1 and ((heightFactor - 1) * tunnelHeight) or 0
            local mTunnelZ = coor.transZ(tunnelHeight)
            
            local lowerTrackBuilder = trackEdge.builder(catenaryLower, trackType)
            local upperTrackBuilder = trackEdge.builder(catenaryUpper, trackType)
            local TLowerTracks = lowerTrackBuilder.nonAligned()
            local TUpperTracks = upperTrackBuilder.nonAligned()
            -- local TLowerExtTracks = lowerTrackBuilder.nonAligned()
            local TUpperExtTracks = upperTrackBuilder.bridge(bridgeType)
            local retriveR = function(param) return rList[param + 1] * 1000 end
            
            local info = {
                A = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerA,
                        rFactor = params.fRLowerA,
                        rad = -0.5 * rad,
                        used = func.contains({0, 1}, params.transitionA),
                        isBridge = false,
                        isTerra = false,
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperA,
                        rFactor = params.fRUpperA,
                        rad = 0.5 * rad,
                        used = func.contains({0, 2}, params.transitionA),
                        isBridge = params.typeSlopeA == 1,
                        isTerra = params.typeSlopeA == 2
                    }
                },
                B = {
                    lower = {
                        nbTracks = params.nbLowerTracks + 1,
                        r = retriveR(params.rLower) * params.fRLowerB,
                        rFactor = params.fRLowerB,
                        rad = -0.5 * rad,
                        used = func.contains({0, 1}, params.transitionB),
                        isBridge = false,
                        isTerra = false,
                    },
                    upper = {
                        nbTracks = params.nbUpperTracks + 1,
                        r = retriveR(params.rUpper) * params.fRUpperB,
                        rFactor = params.fRUpperB,
                        rad = 0.5 * rad,
                        used = func.contains({0, 2}, params.transitionB),
                        isBridge = params.typeSlopeB == 1,
                        isTerra = params.typeSlopeB == 2
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
            
            local ext, preparedExt = (function()
                local extEndList = {A = "inf", B = "sup"}
                local extConfig = {
                    straight = function(equalLength)
                        return function(part, level, type)
                            return {
                                group = group[part].ext[level][type][extEndList[part]],
                                radFn = function(g) return g.rad end,
                                rFn = function(g) return info[part][level].rFactor * g.guideline.r end,
                                guidelineFn = function(g) return g.guideline end,
                                part = part,
                                level = level,
                                equalLength = equalLength or false
                            } end
                    end,
                    curve = function(equalLength)
                        return function(part, level, type) return {
                            group = group[part][level][type],
                            radFn = function(g) return group[part][level].tracks[1][extEndList[part]] end,
                            rFn = function(g) return info[part][level].rFactor * g.r end,
                            guidelineFn = function(g) return g end,
                            part = part,
                            level = level,
                            equalLength = equalLength or false
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
                        slopeA = trSlopeList[params.trSlopeA + 1] * 0.001,
                        slopeB = trSlopeList[params.trSlopeB + 1] * 0.001
                    }
                }
                end
                
                local preparedExt = {
                    tracks = retriveExt(extProtos("tracks")),
                    walls = retriveExt(extProtos("walls"))
                }
                
                return {
                    edges = retriveX(jA.retriveTracks, preparedExt.tracks),
                    polys = retriveX(jA.retrivePolys, preparedExt.tracks),
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
                A = junction.generatePolyArc(group.A.lower.tracks, "inf", "mid")(10, 3.5),
                B = junction.generatePolyArc(group.B.lower.tracks, "mid", "sup")(10, 3.5)
            }
            
            local function selectEdge(level)
                return station.fusionEdges(pipe.new
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
                )),
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
                lowerEdges * pipe.map(station.mergeEdges) * station.prepareEdges * TLowerTracks,
                solidEdges * pipe.map(station.mergeEdges) * station.prepareEdges * TUpperTracks,
                bridgeEdges * pipe.map(station.mergeEdges) * station.prepareEdges * TUpperExtTracks,
            }
            
            local structure = {
                A = generateStructure(group.A.lower, group.A.upper, mTunnelZ * mDepth)[1],
                B = generateStructure(group.B.lower, group.B.upper, mTunnelZ * mDepth)[2]
            }
            
            local slopeWalls = pipe.new
                / (info.A.upper.isTerra
                and {
                    {
                        lower = preparedExt.walls.lower.A[#preparedExt.walls.lower.A].guidelines[2],
                        another = preparedExt.walls.lower.A[#preparedExt.walls.lower.A].guidelines[1],
                        upper = preparedExt.walls.upper.A[1].guidelines[1],
                        fz = preparedExt.walls.upper.A[1].fn.fz,
                        from = "sup", to = "inf"
                    },
                    {
                        lower = preparedExt.walls.lower.A[1].guidelines[2],
                        another = preparedExt.walls.lower.A[1].guidelines[1],
                        upper = preparedExt.walls.upper.A[1].guidelines[1],
                        fz = preparedExt.walls.upper.A[1].fn.fz,
                        from = "sup", to = "inf"
                    }
                } or {})
                / (info.B.upper.isTerra
                and {
                    {
                        lower = preparedExt.walls.lower.B[1].guidelines[1],
                        another = preparedExt.walls.lower.B[1].guidelines[2],
                        upper = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].guidelines[1],
                        fz = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].fn.fz,
                        from = "inf", to = "sup"
                    },
                    {
                        lower = preparedExt.walls.lower.B[#preparedExt.walls.lower.B].guidelines[1],
                        another = preparedExt.walls.lower.B[#preparedExt.walls.lower.B].guidelines[2],
                        upper = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].guidelines[1],
                        fz = preparedExt.walls.upper.B[#preparedExt.walls.upper.B].fn.fz,
                        from = "inf", to = "sup"
                    },
                } or {}
            )
            local slopeWallModels = slopeWalls
                * pipe.flatten()
                * pipe.mapFlatten(function(sw)
                    local loc = detectSlopeIntersection(sw.lower, sw.upper, sw.fz, sw.lower[sw.from], sw.lower[sw.to] - sw.lower[sw.from])
                    local arc = sw.lower:withLimits({
                        [sw.from] = sw.lower[sw.from],
                        [sw.to] = loc,
                        mid = (sw.lower[sw.from] + loc) * 0.5
                    })
                    
                    local mPlace = mPlaceSlopeWall(sw, arc, tunnelHeight * heightFactor)
                    
                    return {
                        junction.makeFn(mSidePillar, mPlace, coor.scaleY(1.05))(arc),
                        junction.makeFn(mRoofFenceS, mPlace, coor.scaleY(1.05))(arc)
                    }
                end)
                * pipe.flatten()
                * pipe.flatten()
            
            
            
            local function withIf(level, part)
                return function(c)
                    return (info[part][level].used and not info[part][level].isBridge) and c or {}
                end
            end
            
            local function withIf2(level, part)
                return function(c)
                    return (info[part][level].used and not info[part][level].isTerra and not info[part][level].isBridge) and c or {}
                end
            end
            
            local uPolys = function(part)
                local i = info[part].upper
                local polySet = ext.polys.upper[part]
                return (not i.used or i.isBridge)
                    and {}
                    or (
                    i.isTerra
                    and {
                        equal = projectPolys(coor.I())(polySet.trackPolys)
                    }
                    or {
                        greater = projectPolys(coor.I())(polySet.polys),
                        less = projectPolys(coor.I())(polySet.trackPolys)
                    }
            )
            end
            
            local slopeWallArcs = slopeWalls
                * pipe.map(pipe.map(function(sw)
                    local loc = detectSlopeIntersection(sw.lower, sw.upper, sw.fz, sw.lower[sw.from], sw.lower[sw.to] - sw.lower[sw.from])
                    return {
                        sw.lower:withLimits({
                        [sw.from] = loc,
                        [sw.to] = sw.lower[sw.to],
                        mid = loc
                    }), 
                    sw.another}
                
                end))
                * pipe.map(pipe.map(pipe.map(function(ar) return junction.generatePolyArc({ar, ar}, "inf", "sup")(0, 2.5) end)))
                * pipe.map(pipe.map(pipe.flatten()))
                * function(ls) return {A = func.flatten(ls[1]), B = func.flatten(ls[2])} end
            
            
            local lPolys = function(part)
                local i = info[part].lower
                local polySet = ext.polys.lower[part]
                return (not i.used)
                    and {}
                    or {
                        less = projectPolys(coor.I())(info[part].upper.isTerra and slopeWallArcs[part] or polySet.polys),
                        slot = projectPolys(coor.I())(polySet.trackPolys),
                        greater = projectPolys(coor.I())(polySet.trackPolys)
                    }
            end
            
            local uXPolys = {
                equal = pipe.new
                + ((info.A.upper.isTerra or heightFactor == 0) and projectPolys(mTunnelZ * mDepth)(upperPolys.A) or {})
                + ((info.B.upper.isTerra or heightFactor == 0) and projectPolys(mTunnelZ * mDepth)(upperPolys.B) or {})
                ,
                less = pipe.new
                + ((not info.A.upper.isTerra and heightFactor ~= 0) and projectPolys(mTunnelZ * mDepth)(upperPolys.A) or {})
                + ((not info.B.upper.isTerra and heightFactor ~= 0) and projectPolys(mTunnelZ * mDepth)(upperPolys.B) or {})
                ,
                greater = pipe.new + (info.A.upper.isTerra and {} or projectPolys(mDepth)(upperPolys.A))
                + (info.B.upper.isTerra and {} or projectPolys(mDepth)(upperPolys.B))
            }
            
            local lXPolys = {
                less = projectPolys(coor.I())(info.A.upper.isTerra and {} or lowerPolys.A, info.B.upper.isTerra and {} or lowerPolys.B),
                slot = projectPolys(mDepth * coor.transZ(-0.1))(lowerPolys.A, lowerPolys.B),
                greater = projectPolys(mDepth)(lowerPolys.A, lowerPolys.B)
            }
            local result = {
                edgeLists = edges,
                models = pipe.new
                + structure.A.fixed
                + structure.B.fixed
                + withIf2("upper", "A")(ext.surface.upper.A)
                + withIf2("upper", "B")(ext.surface.upper.B)
                + (heightFactor > 0
                and pipe.new
                + structure.A.upper
                + structure.B.upper
                + withIf2("upper", "A")(ext.walls.upper.A * pipe.flatten())
                + withIf2("upper", "B")(ext.walls.upper.B * pipe.flatten())
                or {}
                )
                + (heightFactor < 1
                and pipe.new
                + structure.A.lower
                + structure.B.lower
                + withIf("lower", "A")(ext.walls.lower.A[1])
                + withIf("lower", "A")(ext.walls.lower.A[#ext.walls.lower.A])
                + withIf("lower", "B")(ext.walls.lower.B[1])
                + withIf("lower", "B")(ext.walls.lower.B[#ext.walls.lower.B])
                or {})
                + slopeWallModels
                ,
                terrainAlignmentLists = mergePoly(uXPolys, uPolys("A"), uPolys("B")) + mergePoly(lXPolys, lPolys("A"), lPolys("B"))
                ,
                groundFaces = pipe.new
                * {
                    upperPolys.A,
                    upperPolys.B,
                    lowerPolys.A,
                    lowerPolys.B,
                    ext.polys.lower.A.polys,
                    ext.polys.lower.B.polys,
                    ext.polys.upper.A.polys,
                    ext.polys.upper.B.polys
                }
                * pipe.flatten()
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
                * station.setMirror(params.isMir == 1)
                * station.setSlope(slopeList[params.slope + 1])
                * station.setHeight(extraZ)
    end
end

return {
    updateFn = updateFn,
    params = params,
    rList = rList
}
