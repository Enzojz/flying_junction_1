local func = require "func"
trackEdge = {}


function trackEdge.normal(c, t, aligned, snapNodeRule)
    return function(edges)
        return {
            type = "TRACK",
            alignTerrain = aligned,
            params = {
                type = t,
                catenary = c,
            },
            edges = edges,
            snapNodes = snapNodeRule(edges),
        }
    end
end


function trackEdge.bridge(c, t, typeName, snapNodeRule)
    return function(edges)
        return {
            type = "TRACK",
            edgeType = "BRIDGE",
            edgeTypeName = typeName,
            params = {
                type = t,
                catenary = c,
            },
            edges = edges,
            snapNodes = snapNodeRule(edges),
        }
    end
end

function trackEdge.tunnel(c, t, snapNodeRule)
    return function(edges)
        return {
            type = "TRACK",
            edgeType = "TUNNEL",
            edgeTypeName = "railroad_old.lua",
            params = {
                type = t,
                catenary = c,
            },
            edges = edges,
            snapNodes = snapNodeRule(edges),
        }
    end
end

function trackEdge.builder(c, t)
    return {
        normal = func.bind(trackEdge.normal, c, t, true),
        nonAligned = func.bind(trackEdge.normal, c, t, false),
        bridge = func.bind(trackEdge.bridge, c, t),
        tunnel = func.bind(trackEdge.tunnel, c, t)
    }
end

return trackEdge
