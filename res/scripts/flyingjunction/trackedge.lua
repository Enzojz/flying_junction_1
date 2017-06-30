local func = require "flyingjunction/func"
local trackEdge = {}


trackEdge.normal = function(c, t, aligned)
    return function(p)
        return func.with(p, {
            type = "TRACK",
            alignTerrain = aligned,
            params = {
                type = t,
                catenary = c,
            },
        })
    end
end


trackEdge.bridge = function(c, t, typeName)
    return function(p)
        return func.with(p, {
            type = "TRACK",
            edgeType = "BRIDGE",
            edgeTypeName = typeName,
            params = {
                type = t,
                catenary = c,
            }
        })
    end
end

trackEdge.tunnel = function(c, t)
    return function(p)
        return func.with(p, {
            type = "TRACK",
            edgeType = "TUNNEL",
            edgeTypeName = "railroad_old.lua",
            params = {
                type = t,
                catenary = c,
            }
        })
    end
end

trackEdge.builder = function(c, t)
    return {
        normal = func.bind(trackEdge.normal, c, t, true),
        nonAligned = func.bind(trackEdge.normal, c, t, false),
        bridge = func.bind(trackEdge.bridge, c, t),
        tunnel = func.bind(trackEdge.tunnel, c, t)
    }
end

return trackEdge
