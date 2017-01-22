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
    for _,e in ipairs(ls) do
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
    return function (...)
        local param = {...}
        for i = 1, #rest do
            if (rest[i] == nil and #param > 0) then
                rest[i] = table.remove(param, 1)
            end
        end
        local args = func.concat(rest, param)
        return fun(table.unpack(args))
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

return func