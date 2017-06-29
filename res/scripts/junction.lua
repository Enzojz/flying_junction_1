local func = require "flyingjunction/func"
local coor = require "flyingjunction/coor"
local arc = require "flyingjunction/coorarc"
local station = require "flyingjunction/stationlib"
local pipe = require "flyingjunction/pipe"

local mSidePillar = "station/concrete_flying_junction/infra_junc_pillar_side.mdl"
local mRoofFenceF = "station/concrete_flying_junction/infra_junc_roof_fence_front.mdl"
local mRoofFenceS = "station/concrete_flying_junction/infra_junc_roof_fence_side.mdl"
local mRoof = "station/concrete_flying_junction/infra_junc_roof.mdl"
local bridgeType = "z_concrete_flying_junction.lua"

local listDegree = {5, 10, 20, 30, 40, 50, 60, 70, 80}
local rList = {-0.1, -0.3, -0.5, -1, 1e5, 1, 0.5, 0.3, 0.1}
local rTxtList = {"●", "●", "•", "∙", "0", "∙", "•", "●", "●"}

local newModel = function(m, ...)
    return {
        id = m,
        transf = coor.mul(...)
    }
end

local ptXSelector = function(lhs, rhs) return lhs:length() < rhs:length() end

function buildCoors(numTracks, groupSize)
    local function builder(xOffsets, uOffsets, baseX, nbTracks)
        local function caller(n)
            return builder(
                func.concat(xOffsets, func.seqMap({1, n}, function(n) return baseX - 0.5 * station.trackWidth + n * station.trackWidth end)),
                func.concat(uOffsets, {baseX + n * station.trackWidth + 0.25}),
                baseX + n * station.trackWidth + 0.5,
                nbTracks - n)
        end
        if (nbTracks == 0) then
            local offset = function(o) return o - baseX * 0.5 end
            return
                {
                    tracks = func.map(xOffsets, offset),
                    walls = func.map(uOffsets, offset)
                }
        elseif (nbTracks < groupSize) then
            return caller(nbTracks)
        else
            return caller(groupSize)
        end
    end
    return builder({}, {0.25}, 0.5, numTracks)
end

local function normalizeRad(rad)
    return (rad > math.pi * -0.5) and rad or normalizeRad(rad + math.pi * 2)
end

local generateArc = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local radSup = normalizeRad(arc.limits.sup)
    local radMid = normalizeRad(arc.limits.mid)
    local radInf = normalizeRad(arc.limits.inf)
    
    local sup = toXyz(arc.guideline:pt(radSup))
    local inf = toXyz(arc.guideline:pt(radInf))
    local mid = toXyz(arc.guideline:pt(radMid))
    
    local toVector = function(rad) return coor.xyz(0, (arc.limits.mid > math.pi * 0.5 or arc.limits.mid < -math.pi * 0.5) and -1 or 1, 0) .. coor.rotZ(rad) end
    
    local vecSup = toVector(radSup)
    local vecInf = toVector(radInf)
    local vecMid = toVector(radMid)
    
    local supExt = sup + vecSup * 5
    local infExt = inf - vecInf * 5
    
    return {
        {inf, mid, vecInf, vecMid},
        {mid, sup, vecMid, vecSup},
        {infExt, inf, vecInf, vecInf},
        {sup, supExt, vecSup, vecSup},
    }
end

local function average(op1, op2) return (op1 + op2) * 0.5, (op1 + op2) * 0.5 end

local generateTrackGroups = function(tracks1, tracks2, trans)
    trans = trans or {mpt = coor.I(), mvec = coor.I()}
    return {
        normal = pipe.new
        * func.map2(tracks1, tracks2,
            function(t1, t2)
                local seg = {generateArc(t1)[1], generateArc(t2)[2]}
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
                local seg = {generateArc(t1)[3], generateArc(t2)[4]}
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

local fArcs = function(offsets, rad, r)
    return func.map(offsets, function(x)
        return arc.byOR(
            coor.xyz(r, 0, 0) .. coor.rotZ(rad),
            math.abs(r - x)
    ) end
)
end


local minimalR = function(offsets, info)
    local offsetLower = {offsets.lower.walls[1], offsets.lower.walls[#offsets.lower.walls]}
    local offsetUpper = {offsets.upper.walls[1], offsets.upper.walls[#offsets.upper.walls]}
    
    local function incr(r)
        return r == 0 and 0 or (r > 0 and r + 1 or r - 1)
    end
    
    local function calculate(rLower, rUpper)
        
        local lowerGuideline = fArcs(offsetLower, info.lower.rad, rLower)
        local upperGuideline = fArcs(offsetUpper, info.upper.rad, rUpper)
        
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

local function mPlace(guideline, rad)
    local pt = guideline:pt(rad)
    return coor.rotZ(rad) * coor.transX(pt.x) * coor.transY(pt.y)
end

local function makeFn(model, m)
    local m = m or coor.I()
    return function(obj)
        local coordsGen = arc.coords(obj.guideline, 5)
        local function makeModel(seq, scale)
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return newModel(model, m, coor.scaleY(0.5 * scale), mPlace(obj.guideline, (rad1 + rad2) * 0.5))
            end)
        end
        return {
            makeModel(coordsGen(normalizeRad(obj.limits.inf), normalizeRad(obj.limits.mid) - normalizeRad(obj.limits.inf))),
            makeModel(coordsGen(normalizeRad(obj.limits.mid), normalizeRad(obj.limits.sup) - normalizeRad(obj.limits.mid)))
        }
    end
end

local function generateStructure(lowerGroup, upperGroup)
    local makeWall = makeFn(mSidePillar, coor.scaleY(1.05))
    local makeRoof = makeFn(mRoof, coor.scaleY(1.05))
    local makeFence = makeFn(mRoofFenceF)
    local makeSideFence = makeFn(mRoofFenceS)
    
    local walls = lowerGroup.walls
    local trackSets = pipe.new
        * func.map2(func.range(walls, 1, #walls - 1), func.range(walls, 2, #walls),
            function(w1, w2) return pipe.new
                * lowerGroup.tracks
                * pipe.filter(function(t) return t.xOffset < w2.xOffset and t.xOffset > w1.xOffset end)
                * pipe.map(function(t)
                    return func.with(t,
                        {
                            limits = {
                                sup = w2.limits.sup,
                                mid = t.guideline:rad(coor.xy(0, 0)),
                                inf = w1.limits.inf,
                            }
                        }
                ) end)
            end)
        * func.flatten
    
    local upperFences = func.map(upperGroup.tracks, function(t)
        return {
            newModel(mSidePillar, coor.rotZ(math.pi * 0.5), coor.scaleX(0.55), coor.transY(-0.25), mPlace(t.guideline, t.limits.inf)),
            newModel(mSidePillar, coor.rotZ(math.pi * 0.5), coor.scaleX(0.55), coor.transY(0.25), mPlace(t.guideline, t.limits.sup)),
        }
    end)
    
    local fences = func.map(trackSets, function(t)
        local m = coor.scaleX(1.091) * coor.transY(0.18) * coor.transZ(-1) * coor.centered(coor.scaleZ, 3.5 / 1.5, coor.xyz(0, 0, 10.75))
        return {
            newModel(mRoofFenceF, m, mPlace(t.guideline, t.limits.inf)),
            newModel(mRoofFenceF, m, coor.flipY(), mPlace(t.guideline, t.limits.sup)),
        }
    end)
    
    local sideFencesL = func.map(func.range(lowerGroup.walls, 1, #lowerGroup.walls - 1), function(t)
        return func.with(t, {
            limits = {
                sup = t.guideline:rad(func.min(upperGroup.walls[1].guideline - t.guideline, ptXSelector)),
                mid = t.guideline:rad(func.min(upperGroup.walls[1].guideline - t.guideline, ptXSelector)),
                inf = t.limits.inf,
            }
        })
    end)
    
    local sideFencesR = func.map(func.range(lowerGroup.walls, 2, #lowerGroup.walls), function(t)
        return func.with(t, {
            limits = {
                inf = t.guideline:rad(func.min(upperGroup.walls[2].guideline - t.guideline, ptXSelector)),
                mid = t.guideline:rad(func.min(upperGroup.walls[2].guideline - t.guideline, ptXSelector)),
                sup = t.limits.sup,
            }
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

local generatePolyArcEdge = function(guideline, from, to)
    return func.map(
        arc.coords(guideline, 5)(normalizeRad(from), normalizeRad(to) - normalizeRad(from)),
        function(rad) return (function(p) return {p.x, p.y, 0} end)(guideline:pt(rad)) end)
end

return {
    fArcs = fArcs,
    buildCoors = buildCoors,
    minimalR = minimalR,
    generateTrackGroups = generateTrackGroups,
    generateStructure = generateStructure,
    generatePolyArcEdge = generatePolyArcEdge,
    generateArc = generateArc,
}
