local func = require "func"
local coor = require "coor"
local trackEdge = require "trackedge"

local newModel = function(m, ...)
    return {
        id = m,
        transf = coor.mul(...)
    }
end


local stationlib = {
    platformWidth = 5,
    trackWidth = 5,
    segmentLength = 20
}


stationlib.generateTrackGroups = function(xOffsets, length, extra)
    local halfLength = length * 0.5
    extra = extra or { mpt = coor.I(), mvec = coor.I() }
    return func.flatten(
        func.map(xOffsets,
            function(xOffset)
                return coor.applyEdges(coor.mul(xOffset.parity, extra.mpt, xOffset.mpt), coor.mul(xOffset.parity, extra.mvec, xOffset.mvec))(
                    {
                        {{0, -halfLength, 0}, {0, halfLength, 0}},
                        {{0, 0, 0}, {0, halfLength, 0}},
                        {{0, 0, 0}, {0, halfLength, 0}},
                        {{0, halfLength, 0}, {0, halfLength, 0}},
                    })
            end
))
end

stationlib.preBuild = function(totalTracks, baseX, ignoreFst, ignoreLst)
    local groupWidth = stationlib.trackWidth + stationlib.platformWidth
    local function build(nbTracks, baseX, xOffsets, uOffsets)
        if (nbTracks == 0) then
            return xOffsets, uOffsets
        elseif ((nbTracks == 1 and ignoreLst) or (nbTracks == totalTracks and not ignoreFst)) then
            return build(nbTracks - 1, baseX + groupWidth,
                func.concat(xOffsets, {baseX + 0.5 * groupWidth}),
                func.concat(uOffsets, {baseX}))
        elseif (nbTracks == 1 and not ignoreLst) then
            return build(nbTracks - 1, baseX + groupWidth - 0.5 * stationlib.trackWidth,
                func.concat(xOffsets, {baseX}),
                func.concat(uOffsets, {baseX + 0.5 * groupWidth}))
        else return build(nbTracks - 2, baseX + groupWidth + stationlib.trackWidth,
            func.concat(xOffsets, {baseX, baseX + groupWidth}),
            func.concat(uOffsets, {baseX + 0.5 * groupWidth})
        )
        end
    end
    
    return build(totalTracks, baseX, {}, {})
end

stationlib.buildCoors = function(nSeg)
    local groupWidth = stationlib.trackWidth + stationlib.platformWidth
    
    local function buildUIndex(uOffset, ...) return {func.seq(uOffset * nSeg, (uOffset + 1) * nSeg - 1), {...}} end
    
    local function buildGroup(level, baseX, nbTracks, xOffsets, uOffsets, xuIndex)
        local project = function(x, p) return func.map2(x, p, function(offset, parity) return
            {
                mpt = coor.transX(offset) * level.mdr * level.mz,
                mvec = level.mr,
                parity = parity,
                id = level.id,
                x = offset
            }
        end) end
        
        local make = function(params)
            return
                nbTracks - #params.xOffset,
                func.concat(xOffsets, project(params.xOffset, params.xParity)),
                func.concat(uOffsets, project(params.uOffset, {coor.I()})),
                func.concat(xuIndex, {params.xuIndex})
        end
        
        if (nbTracks == 0) then
            return xOffsets, uOffsets, xuIndex
        elseif ((nbTracks == 1 and level.ignoreLst) or (nbTracks == level.nbTracks and not level.ignoreFst)) then
            return buildGroup(level, baseX + groupWidth,
                make({
                    xOffset = {baseX + 0.5 * groupWidth},
                    xParity = {coor.flipY()},
                    uOffset = {baseX},
                    xuIndex = buildUIndex(#uOffsets, {1, #xOffsets + 1})
                })
        )
        elseif (nbTracks == 1 and not level.ignoreLst) then
            return buildGroup(level, baseX + groupWidth - 0.5 * stationlib.trackWidth,
                make({
                    xOffset = {baseX},
                    xParity = {coor.I()},
                    uOffset = {baseX + 0.5 * groupWidth},
                    xuIndex = buildUIndex(#uOffsets, {0, #xOffsets + 1})
                })
        )
        else
            return buildGroup(level, baseX + groupWidth + stationlib.trackWidth,
                make({
                    xOffset = {baseX, baseX + groupWidth},
                    xParity = {coor.I(), coor.flipY()},
                    uOffset = {baseX + 0.5 * groupWidth},
                    xuIndex = buildUIndex(#uOffsets, {0, #xOffsets + 1}, {1, #xOffsets + 2})
                })
        )
        end
    end
    
    local function build(trackGroups, ...)
        if (#trackGroups == 1) then
            local group = table.unpack(trackGroups)
            return buildGroup(group, group.baseX, group.nbTracks, ...)
        else
            return build(func.range(trackGroups, 2, #trackGroups), build({trackGroups[1]}, ...))
        end
    end
    return build
end

stationlib.noSnap = function(e) return {} end

stationlib.makePlatforms = function(uOffsets, platforms, m)
    local length = #platforms * stationlib.segmentLength
    return func.mapFlatten(uOffsets,
        function(uOffset)
            return func.map2(func.seq(1, #platforms), platforms, function(i, p)
                return newModel(p, coor.transY(i * stationlib.segmentLength - 0.5 * (stationlib.segmentLength + length)), uOffset.mpt, m) end
        )
        end)
end

stationlib.makeTerminals = function(xuIndex)
    return func.mapFlatten(xuIndex, function(xu)
        local terminals, xIndices = table.unpack(xu)
        return func.map(xIndices, function(x)
            local side, track = table.unpack(x)
            return {
                terminals = func.map(terminals, function(t) return {t, side} end),
                vehicleNodeOverride = track * 4 - 2
            }
        end
    )
    end)
end

stationlib.setHeight = function(result, height)
    local mpt = coor.transZ(height)
    local mvec = coor.I()
    
    local mapEdgeList = function(edgeList)
        edgeList.edges = func.map(edgeList.edges, coor.applyEdge(mpt, mvec))
        return edgeList
    end
    
    result.edgeLists = func.map(result.edgeLists, mapEdgeList)
    
    local mapModel = function(model)
        model.transf = model.transf *  mpt
        return model
    end
    
    result.models = func.map(result.models, mapModel)
end

stationlib.faceMapper = function(m)
    return function(face)
        return func.map(face, function(pt) return (coor.tuple2Vec(pt) .. m):toTuple() end)
    end
end


return stationlib
