local func = require "jct/func"
local pipe = require "jct/pipe"
local coor = require "jct/coor"
local arc = require "jct/coorarc"
local quat = require "jct/quaternion"
local jct = require "jct_gridization"
local livetext = require "jct/livetext"
local math = math
local abs = math.abs
local floor = math.floor
local unpack = table.unpack

local insert = table.insert

jct.infi = 1e8

---@alias id integer
---@alias slotid integer
---@alias slottype integer
---@alias slotbase integer
---
---@class slotinfo
---@field type slottype
---@field id id
---@field slotId slotid
---@field data integer
---@field pos coor3
---@field radius number
---@field straight boolean
---@field length number
---@field extraHeight number
---@field width number
---@field ref {left: boolean, right: boolean, prev:boolean, next: boolean}
---@field octa (boolean|integer)[]
---@field comp table<integer, boolean>
---@field compList table<integer, table<integer>>
---@field arcs {left: arc, right:arc, center:arc}
---@field pts {[1]: {[1]:coor3, [2]: coor3}, [2]: {[1]:coor3, [2]: coor3}}
---@field refPos coor3
---
---@class projection_size
---@field lb coor3
---@field lt coor3
---@field rb coor3
---@field rt coor3
---
---@class module
---@field name string
---@field variant integer
---@field info slotinfo
---@field metadata table
---@field makeData fun(type: slottype, data: integer): slotid
---
---@alias modules table<integer, module>
---
---@class classified
---@field slotId slotid
---@field type slottype
---@field id id
---@field data integer
---@field info any[]
---@field slot any[]
---@field metadata table
---
---@alias classified_modules table<integer, classified>
---@param id id
---@param type slottype
---@return slotbase
jct.base = function(id, type)
    return id * 100 + type
end

---@param base slotbase
---@param data integer
---@return slotid
jct.mixData = function(base, data)
    return (data < 0 and -base or base) + 1000000 * data
end

---@param info slotinfo
---@return slotbase
---@return { data_pos: slotid[], data_radius: slotid[], data_geometry: slotid[], data_ref: slotid[] }
jct.slotIds = function(info)
    local base = info.type + info.id * 100
    
    return base, {
        pos = {
            jct.mixData(jct.base(info.id, 51), info.pos.x),
            jct.mixData(jct.base(info.id, 52), info.pos.y),
            jct.mixData(jct.base(info.id, 53), info.pos.z)
        },
        radius = info.radius and {
            jct.mixData(jct.base(info.id, 54), info.radius > 0 and info.radius % 1000 or -(-info.radius % 1000)),
            jct.mixData(jct.base(info.id, 55), info.radius > 0 and math.floor(info.radius / 1000) or -(math.floor(-info.radius / 1000))),
        } or info.straight and {
            jct.mixData(jct.base(info.id, 56), 0)
        } or {},
        geometry = func.filter({
            jct.mixData(jct.base(info.id, 57), info.length),
            jct.mixData(jct.base(info.id, 59), math.floor((info.extraHeight or 0) * 10)),
            info.width and jct.mixData(jct.base(info.id, 58), info.width * 10) or false,
        -- info.gradient and jct.mixData(jct.base(info.id, 61), info.gradient * 1000) or false,
        }, pipe.noop()),
        ref = {
            info.ref and
            jct.mixData(jct.base(info.id, 60),
                (info.ref.left and 1 or 0) +
                (info.ref.right and 2 or 0) +
                (info.ref.next and 4 or 0) +
                (info.ref.prev and 8 or 0)
            ) or
            jct.base(info.id, 60)
        }
    }
end

---@param slotId slotid
---@return slottype
---@return id
---@return integer
jct.slotInfo = function(slotId)
        -- Platform/track
        -- 1 ~ 2 : 00 construction 01 track 02 streets 03 walls 04 placeholder
        -- 3 ~ 6 : id
        -- Component
        -- 1 ~ 2 : 20 reserved 24 fences/walls 27 catenary 28 roof
        --         40 general comp
        -- 3 ~ 6 : id
        -- Information
        -- 1 ~ 2 : 50 reserved 51 x 52 y 53 z 54 55 radius 56 is_straight 57 length 58 width 59 gradient 60 ref
        --       : 70 cross angle
        -- 3 ~ 6 : id
        -- > 6: data
        -- Modifier
        -- 1 ~ 2 : 80 81 82 radius 85 86 width 87 88 gradient 90 cross angle
        local slotIdAbs = math.abs(slotId)
        if slotIdAbs % 1 ~= 0 then -- trick for probably a bug from the game, slotId can be non interger
            slotIdAbs = floor(slotIdAbs + 0.5)
        end
        local type = slotIdAbs % 100
        local id = floor(slotIdAbs / 100) % 1000
        local data = slotId > 0 and floor(slotIdAbs / 1000000) or -floor(slotIdAbs / 1000000)
        
        return type, id, data
end

---@param pt coor
---@param vec coor
---@param length number
---@param radius number
---@param isRev boolean
---@return fun(...: number): arc, arc ...
jct.arcPacker = function(pt, vec, length, radius, isRev, fs, fz)
    local nVec = vec:withZ(0):normalized()
    local tVec = coor.xyz(-nVec.y, nVec.x, 0)
    local radius = isRev and -radius or radius
    local o = pt + tVec * radius
    
    local ar = arc.byOR(o, abs(radius))
    local inf = ar:rad(pt)
    local sup = inf + length / radius
    if isRev then
        inf, sup = sup, inf
    end
    ar = ar:withLimits({
        sup = sup,
        inf = inf,
        fs = fs(inf, sup),
        fz = fz(inf, sup)
    })
    ---@param ... number
    ---@return arc, arc ...
    return function(...)
        local result = func.map({...}, function(dr)
            local dr = isRev and -dr or dr
            return arc.byOR(o, abs(radius + dr), {
                sup = sup,
                inf = inf
            }):withLimits({
                fs = fs(inf, sup),
                fz = fz(inf, sup)
            })
        end)
        return ar, unpack(result)
    end
end

---@param w number
---@param h number
---@param d number
---@param fitTop boolean
---@param fitLeft boolean
---@return fun(size: projection_size, mode: boolean, z?: number): matrix
jct.fitModel = function(w, h, d, fitTop, fitLeft)
    local s = {
        {
            coor.xyz(0, 0, 0),
            coor.xyz(fitLeft and w or -w, 0, 0),
            coor.xyz(0, fitTop and -h or h, 0),
            coor.xyz(0, 0, d)
        },
        {
            coor.xyz(0, 0, 0),
            coor.xyz(fitLeft and -w or w, 0, 0),
            coor.xyz(0, fitTop and h or -h, 0),
            coor.xyz(0, 0, d)
        },
    }
    
    ---@type matrix[]
    local mX = func.map(s, function(s)
        return {
            {s[1].x, s[1].y, s[1].z, 1},
            {s[2].x, s[2].y, s[2].z, 1},
            {s[3].x, s[3].y, s[3].z, 1},
            {s[4].x, s[4].y, s[4].z, 1}
        }
    end)
    
    ---@type matrix[]
    local mXI = func.map(mX, coor.inv)
    
    local fitTop = {fitTop, not fitTop}
    local fitLeft = {fitLeft, not fitLeft}
    
    ---@param size projection_size
    ---@param mode boolean
    ---@param z? number
    ---@return matrix
    return function(size, mode, z)
        local z = z or d
        local mXI = mXI[mode and 1 or 2]
        local fitTop = fitTop[mode and 1 or 2]
        local fitLeft = fitLeft[mode and 1 or 2]
        local t = fitTop and
            {
                fitLeft and size.lt or size.rt,
                fitLeft and size.rt or size.lt,
                fitLeft and size.lb or size.rb,
            } or {
                fitLeft and size.lb or size.rb,
                fitLeft and size.rb or size.lb,
                fitLeft and size.lt or size.rt,
            }
        
        ---@type matrix
        local mU = {
            t[1].x, t[1].y, t[1].z, 1,
            t[2].x, t[2].y, t[2].z, 1,
            t[3].x, t[3].y, t[3].z, 1,
            t[1].x, t[1].y, t[1].z + z, 1
        }
        
        return mXI * mU
    end
end

jct.mRot = function(vec)
    return coor.scaleX(vec:length()) * quat.byVec(coor.xyz(1, 0, 0), vec):mRot()
end

---@class mdl
---@field id string
---@field tag string
---@field transf matrix
---@param m string
---@param tag string
---@param ... matrix
---@return mdl
jct.newModel = function(m, tag, ...)
    return {
        id = m,
        transf = coor.mul(...),
        tag = tag
    }
end

---@param arc arc
---@param n integer
---@return coor3[]
---@return coor3[]
jct.basePts = function(arc, n)
    if not arc.basePts[n] then
        local radDelta = (arc.sup - arc.inf) / n
        local rads = func.map(func.seq(0, n), function(i) return arc.inf + i * radDelta end)
        local pts = func.map(rads, function(rad) return arc:pt(rad) end)
        local vecs = func.map(rads, function(rad) return arc:tangent(rad) end)
        arc.basePts[n] = {pts, vecs}
    end
    local pts, vec = unpack(arc.basePts[n])
    return func.map(pts, function(pt) return coor.xyz(pt.x, pt.y, pt.z) end),
        func.map(vec, function(pt) return coor.xyz(pt.x, pt.y, pt.z) end)
end

---@param params any
---@param pos coor3
jct.initSlotGrid = function(params, pos)
    if not params.slotGrid[pos.z] then params.slotGrid[pos.z] = {} end
    if not params.slotGrid[pos.z][pos.x] then params.slotGrid[pos.z][pos.x] = {} end
    if not params.slotGrid[pos.z][pos.x][pos.y] then params.slotGrid[pos.z][pos.x][pos.y] = {} end
    if not params.slotGrid[pos.z][pos.x - 1] then params.slotGrid[pos.z][pos.x - 1] = {} end
    if not params.slotGrid[pos.z][pos.x + 1] then params.slotGrid[pos.z][pos.x + 1] = {} end
    if not params.slotGrid[pos.z][pos.x - 1][pos.y] then params.slotGrid[pos.z][pos.x - 1][pos.y] = {} end
    if not params.slotGrid[pos.z][pos.x + 1][pos.y] then params.slotGrid[pos.z][pos.x + 1][pos.y] = {} end
    if not params.slotGrid[pos.z][pos.x][pos.y - 1] then params.slotGrid[pos.z][pos.x][pos.y - 1] = {} end
    if not params.slotGrid[pos.z][pos.x][pos.y + 1] then params.slotGrid[pos.z][pos.x][pos.y + 1] = {} end
end

jct.newTopologySlots = function(params, makeData, pos)
    return function(x, y, transf, octa)
        params.slotGrid[pos.z][x][y].track = {
            id = makeData(1, octa),
            transf = transf,
            type = "jct_track",
            spacing = {0, 0, 0, 0}
        }
        params.slotGrid[pos.z][x][y].street = {
            id = makeData(2, octa),
            transf = transf,
            type = "jct_street",
            spacing = {0, 0, 0, 0}
        }
        params.slotGrid[pos.z][x][y].street = {
            id = makeData(3, octa),
            transf = transf,
            type = "jct_wall",
            spacing = {0, 0, 0, 0}
        }
        params.slotGrid[pos.z][x][y].placeholder = {
            id = makeData(4, octa),
            transf = transf,
            type = "jct_placeholder",
            spacing = {0, 0, 0, 0}
        }
    end
end

---@param modules table<slotid, module>
---@param classified classified_modules
---@param slotId slotid
---@return slottype
---@return slotid
---@return integer
jct.classifyComp = function(modules, classified, slotId)
    local type, id, data = jct.slotInfo(slotId)
    
    modules[slotId].info = {
        data = data,
        type = type,
        slotId = slotId,
        id = id
    }
    
    modules[classified[id].slotId].info.comp[type] = true
    
    if not modules[classified[id].slotId].info.compList[type] then
        modules[classified[id].slotId].info.compList[type] = {slotId}
    else
        insert(modules[classified[id].slotId].info.compList[type], slotId)
    end
    
    modules[slotId].makeData = function(type, data)
        return jct.mixData(jct.base(id, type), data)
    end
    
    return type, id, data
end

---@param modules table<slotid, module>
---@param classified classified_modules
---@param slotId slotid
---@return slottype
---@return slotid
---@return integer
jct.classifyData = function(modules, classified, slotId)
    local type, id, data = jct.slotInfo(slotId)
    
    classified[id].slot[type] = slotId
    classified[id].metadata[type] = modules[slotId].metadata
    
    modules[slotId].info = {
        data = data,
        type = type,
        slotId = slotId,
        id = id
    }
    
    return type, id, data
end

---@param modules table<slotid, module>
---@param classified classified_modules
---@param slotId slotid
---@return slottype
---@return slotid
---@return integer
jct.preClassify = function(modules, classified, slotId)
    local type, id, data = jct.slotInfo(slotId)
    
    classified[id] = {
        type = type,
        id = id,
        slotId = slotId,
        data = data,
        info = {},
        slot = {},
        metadata = {}
    }
    
    modules[slotId].info = {
        type = type,
        id = id,
        slotId = slotId,
        data = data,
        octa = {false, false, false, false, false, false, false, false},
        comp = {},
        compList = {},
        pos = coor.xyz(0, 0, 0),
        width = modules[slotId].metadata.width or 5,
        length = 20,
    }
    
    modules[slotId].makeData = function(type, data)
        return jct.mixData(jct.base(id, type), data)
    end
    
    return type, id, data
end

jct.marking = function(result, slotId, params)
    local id = params.modules[slotId].info.id
    local sId = params.classedModules[id].slotId
    local info = params.modules[sId].info
    
    local n = 10
    local ptsL, vecL = jct.basePts(info.arcs.left, n)
    local ptsR, vecR = jct.basePts(info.arcs.right, n)
    local ptsC, vecC = jct.basePts(info.arcs.center, n)
    
    local addText = function(label, transf, f)
        local nameModelsF, width = livetext(2)(label)
        for _, m in ipairs(nameModelsF(function() return (f or coor.I()) * coor.transZ(-0.85) * coor.rotX90N * transf end)) do
            table.insert(result.models, m)
        end
    end
    
    for i = 1, 11 do
        addText("⋮", quat.byVec(coor.xyz(0, 1, 0), vecL[i]):mRot() * coor.trans(ptsL[i]), coor.transX(-0.1))
        addText("⋮", quat.byVec(coor.xyz(0, 1, 0), vecR[i]):mRot() * coor.trans(ptsR[i]), coor.transX(-0.1))
    end
    
    for _, i in ipairs({1, 11}) do
        addText("⋯", quat.byVec(coor.xyz(0, 1, 0), vecL[i]):mRot() * coor.trans(ptsL[i]), coor.transX(-0.5))
        addText("⋯", quat.byVec(coor.xyz(0, 1, 0), vecR[i]):mRot() * coor.trans(ptsR[i]), coor.transX(-0.5))
        addText("⋯", quat.byVec(coor.xyz(0, 1, 0), vecC[i]):mRot() * coor.trans(ptsC[i]), coor.transX(-0.5))
    end
    
    if info.ref.left then
        local refPt = ptsL[6]
        local refVec = vecL[6]
        local transf = quat.byVec(coor.xyz(0, 1, 0), refVec):mRot() * coor.trans(refPt)
        addText("⋘", transf, coor.transX(0.2))
    end
    
    if info.ref.right then
        local refPt = ptsR[6]
        local refVec = vecR[6]
        local transf = quat.byVec(coor.xyz(0, -1, 0), refVec):mRot() * coor.trans(refPt)
        addText("⋘", transf, coor.transX(0.2))
    end
    
    if info.ref.next then
        local i = 11
        local refPt = ptsC[i]
        local refVec = vecC[i]
        local transf = quat.byVec(coor.xyz(-1, 0, 0), refVec):mRot() * coor.trans(refPt)
        addText("⋘", transf, coor.transX(0.2))
    end
    
    if info.ref.prev then
        local i = 1
        local refPt = ptsC[i]
        local refVec = vecC[i]
        local transf = quat.byVec(coor.xyz(1, 0, 0), refVec):mRot() * coor.trans(refPt)
        addText("⋘", transf, coor.transX(0.2))
    end
end

jct.initTerrainList = function(result, id)
    if not result.terrainLists[id] then
        result.terrainLists[id] = {
            equal = {},
            less = {},
            greater = {},
            equalOpt = {},
            lessOpt = {},
            greaterOpt = {},
        }
    end
end

return jct
