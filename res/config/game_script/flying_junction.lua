-- local dump = require "dump"
local coor = require "jct/coor"
local pipe = require "jct/pipe"
-- local dbg = require("LuaPanda")

local function travel(node, edge)
    return edge.node0 == node and edge.node1 or edge.node1 == node and edge.node0 or nil
end

local script = {
    handleEvent = function(src, id, name, param)
        if (id == "__flyingjunction__") then
            if (name == "node") then
                -- dbg.start("127.0.0.1",8818)
                local nodes = pipe.new * param.nodes
                local edges = pipe.new * param.edges
                local noden = { {}, {}, {}, {} }
                for n, e in pairs(nodes) do
                    if (#e < 5) then
                        noden[#e][n] = e
                    end
                end
                local x = game.interface.getEntity(param.id)
                -- game.interface.bulldoze(param.id)
                local id = game.interface.buildConstruction(
                    "jct/tester.con",
                    {},
                    x.transf
                )
                game.interface.setPlayer(id, game.interface.getPlayer())

            end
        end
    end,
    guiHandleEvent = function(_, name, param)
        if name == "builder.apply" then
            local toRemove = param.proposal.toRemove
            local toAdd = param.proposal.toAdd

            if (toAdd and #toAdd == 1 and toRemove and #toRemove == 0) then
                local con = toAdd[1]
                if (con.fileName == "jct/localizer.con") then
                    local trans = coor.decomposite(con.transf)
                    local nodes = {}
                    local edges = {}
                    for _, e in ipairs(game.interface.getEntities({pos = {trans.x, trans.y, trans.z}, radius = 100}, {type = "BASE_EDGE"})) do
                        local e = game.interface.getEntity(e)
                        if e.track then
                            edges[e.id] = edges
                            nodes[e.node0] = (nodes[e.node0] or pipe.new) / e.id
                            nodes[e.node1] = (nodes[e.node1] or pipe.new) / e.id
                        end
                    end
                    game.interface.sendScriptEvent("__flyingjunction__", "node", {nodes = nodes, edges = edges, id = param.result[1]})
                end
            end
        end
    end
}

function data()
    return script
end
