local func = require "jct/func"
local pipe = require "jct/pipe"
local coor = require "jct/coor"
local line = require "jct/coorline"

local pi = math.pi
local unpack = table.unpack
local insert = table.insert
local remove = table.remove

local dump = require "luadump"
local jct = {}

---@param modules modules
---@param classedModules classified_modules
---@return grid
jct.octa = function(modules, classedModules)
    local grid = {}
    
    -- 8 1 2
    -- 7 x 3
    -- 6 5 4
    for id, info in pairs(classedModules) do
        local pos = modules[info.slotId].info.pos
        local x, y, z = pos.x, pos.y, pos.z
        if not grid[z] then grid[z] = {} end
        if not grid[z][y] then grid[z][y] = {} end
        grid[z][y][x] = info.slotId
    end
    
    for slotId, module in pairs(modules) do
        if module.metadata.isTrack or module.metadata.isStreet or module.metadata.isWall or module.metadata.isPlaceholder then
            local info = module.info
            local x, y, z = info.pos.x, info.pos.y, info.pos.z
            
            if grid[z][y][x - 1] then
                modules[grid[z][y][x - 1]].info.octa[3] = slotId
                module.info.octa[7] = grid[z][y][x - 1]
            end
            
            if grid[z][y][x + 1] then
                modules[grid[z][y][x + 1]].info.octa[7] = slotId
                module.info.octa[3] = grid[z][y][x + 1]
            end
            
            if grid[z][y - 1] and grid[z][y - 1][x] then
                modules[grid[z][y - 1][x]].info.octa[1] = slotId
                module.info.octa[5] = grid[z][y - 1][x]
            end
            
            if grid[z][y - 1] and grid[z][y - 1][x - 1] then
                modules[grid[z][y - 1][x - 1]].info.octa[2] = slotId
                module.info.octa[6] = grid[z][y - 1][x - 1]
            end
            
            if grid[z][y - 1] and grid[z][y - 1][x + 1] then
                modules[grid[z][y - 1][x + 1]].info.octa[8] = slotId
                module.info.octa[4] = grid[z][y - 1][x + 1]
            end
            
            if grid[z][y + 1] and grid[z][y + 1][x] then
                modules[grid[z][y + 1][x]].info.octa[5] = slotId
                module.info.octa[1] = grid[z][y + 1][x]
            end
            
            if grid[z][y + 1] and grid[z][y + 1][x - 1] then
                modules[grid[z][y + 1][x - 1]].info.octa[4] = slotId
                module.info.octa[8] = grid[z][y + 1][x - 1]
            end
            
            if grid[z][y + 1] and grid[z][y + 1][x + 1] then
                modules[grid[z][y + 1][x + 1]].info.octa[6] = slotId
                module.info.octa[2] = grid[z][y + 1][x + 1]
            end
        end
    end
    return grid
end

jct.refArc2Pts = function(refArc)
    return {
        {
            refArc.center:pt(refArc.center.inf),
            refArc.center:tangent(refArc.center.inf)
        },
        {
            refArc.center:pt(refArc.center.sup),
            refArc.center:tangent(refArc.center.sup)
        }
    }
end

---@param modules modules
---@param classedModules classified_modules
---@return table
---@return integer
jct.gridization = function(modules, classedModules)
    local grid = jct.octa(modules, classedModules)
    
    for z, g in pairs(grid) do
        local queue = pipe.new * {}
       
        local ySeq = func.sort(func.keys(g))
        
        for _, y in ipairs(ySeq) do
            if y >= 0 then
                local xSeq = func.sort(func.keys(g))
                for _, x in ipairs(xSeq) do
                    if x >= 0 then
                        insert(queue, g[y][x])
                    end
                end
                
                for _, x in ipairs(func.rev(xSeq)) do
                    if x < 0 then
                        insert(queue, g[y][x])
                    end
                end
            end
        end
        
        for _, y in ipairs(func.rev(ySeq)) do
            if y < 0 then
                local xSeq = func.sort(func.keys(g))
                for _, x in ipairs(xSeq) do
                    if x >= 0 then
                        insert(queue, g[y][x])
                    end
                end
                
                for _, x in ipairs(func.rev(xSeq)) do
                    if x < 0 then
                        insert(queue, g[y][x])
                    end
                end
            end
        end
        
        -- Collect X postion and width information
        -- Process in Y axis
        local processY = function(fn, x, y)
            return function()
                local data = {
                    modules = modules,
                    grid = grid,
                }
                
                fn(x, y, z, data)
            end
        end
        
        local cr = {}
        
        for _, slotId in ipairs(queue) do
            local m = modules[slotId]
            if (m.metadata.scriptName and game.res.script[m.metadata.scriptName]) then
                local fn = game.res.script[m.metadata.scriptName][m.metadata.gridization]
                if fn then
                    local pos = modules[slotId].info.pos
                    cr[slotId] = coroutine.create(processY(fn, pos.x, pos.y))
                end
            end
        end
        
        for _, slotId in ipairs(queue) do
            local result = coroutine.resume(cr[slotId])
            if not result then
                error(debug.traceback(cr[slotId]))
            end
        end
        
        for _, slotId in ipairs(queue) do
            local result = coroutine.resume(cr[slotId])
            if not result then
                error(debug.traceback(cr[slotId]))
            end
        end
        for _, slotId in ipairs(queue) do
            local result = coroutine.resume(cr[slotId])
            if not result then
                error(debug.traceback(cr[slotId]))
            end
        end
    end
    
    return grid
end

return jct
