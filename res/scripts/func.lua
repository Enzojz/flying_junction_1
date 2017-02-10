--[[
Copyright (c) 2016 "Enzojz" from www.transportfever.net
(https://www.transportfever.net/index.php/User/27218-Enzojz/)

Github repository:
https://github.com/Enzojz/transportfever

Anyone is free to use the program below, however the auther do not guarantee:
* The correctness of program
* The invariance of program in future
=====!!!PLEASE  R_E_N_A_M_E  BEFORE USE IN YOUR OWN PROJECT!!!=====

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including the right to distribute and without limitation the rights to use, copy and/or modify
the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--]]
func = {}

function func.fold(ls, init, fun)
    for _, e in ipairs(ls) do
        init = fun(init, e)
    end
    return init
end

function func.forEach(ls, fun)
    for i, e in ipairs(ls) do fun(e) end
end

function func.map(ls, fun)
    local result = {}
    for i, e in ipairs(ls) do result[i] = fun(e) end
    return result
end


function func.mapValues(ls, fun)
    local result = {}
    for i, e in pairs(ls) do result[i] = fun(e) end
    return result
end

function func.mapPair(ls, fun)
    local result = {}
    for i, e in ipairs(ls) do
        local k, v = fun(e)
        result[k] = v
    end
    return result
end

function func.filter(ls, pre)
    local result = {}
    for _, e in ipairs(ls) do
        if pre(e) then result[#result + 1] = e end
    end
    return result
end

function func.concat(t1, t2)
    local res = {}
    for _, v in ipairs(t1) do
        table.insert(res, v)
    end
    for _, v in ipairs(t2) do
        table.insert(res, v)
    end
    return res
end

function func.flatten(ls)
    local result = {}
    for _, v in ipairs(ls) do
        result = func.concat(result, v)
    end
    return result
end

function func.mapFlatten(ls, fun)
    return func.flatten(func.map(ls, fun))
end

function func.bind(fun, ...)
    local rest = {...}
    return function(...)
        local param = {...}
        local args = {}
        for i = 1, #rest do
            if (rest[i] == nil and #param > 0) then
                table.insert(args, table.remove(param, 1))
            else
                table.insert(args, rest[i])
            end
        end
        return fun(table.unpack(func.concat(args, param)))
    end
end

function func.seq(from, to)
    local result = {}
    for i = from, to do
        table.insert(result, i)
    end
    return result
end

function func.seqMap(range, fun)
    return func.map(func.seq(table.unpack(range)), fun)
end

function func.pipe(op, f, ...)
    local rest = {...}
    if (#rest > 0) then
        return func.pipe(f(op), ...)
    else
        return f(op)
    end
end

function func.exec(...)
    local rest = {...}
    return function(p) return func.pipe(p, table.unpack(rest)) end
end

function func.map2(ls1, ls2, fun)
    local result = {}
    for i, e in ipairs(ls1) do result[i] = fun(e, ls2[i]) end
    return result
end

function func.range(ls, from, to)
    local result = {}
    for i = from, to do table.insert(result, ls[i]) end
    return result
end

function func.seqValue(n, value)
    return func.seqMap({1, n}, function(_) return value end)
end

function func.max(ls, less)
    return func.fold(ls, ls[1], function(l, r) return less(l, r) and r or l end)
end

function func.min(ls, less)
    return func.fold(ls, ls[1], function(l, r) return less(l, r) and l or r end)
end

function func.with(ls, newValues)
    local result = {}
    for i, e in pairs(ls) do result[i] = e end
    for i, e in pairs(newValues) do result[i] = e end
    return result
end

function func.sort(ls, fn)
    local result = func.with(ls, {})
    table.sort(result, fn)
    return result
end

local pipeMeta = {
    __mul = function(lhs, rhs)
        local result = {op = {rhs(lhs())}}
        setmetatable(result, getmetatable(lhs))
        return result
    end
    ,
    __call = function(r)
        return table.unpack(r.op)
    end
    ,
    __div = function(r, _)
        return table.unpack(r.op)
    end
}

func.p = {}
pMeta = {
    __mul = function(_, rhs)
        local result = {op = {rhs}}
        setmetatable(result, pipeMeta)
        return result
    end
}
setmetatable(func.p, pMeta)

func.b = func.bind


return func
