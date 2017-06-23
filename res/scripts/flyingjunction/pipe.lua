--[[
Copyright (c) 2017 "Enzojz" from www.transportfever.net
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
local pipe = {}

function pipe.fold(init, fun)
    return function(ls)
        for _, e in ipairs(ls) do
            init = fun(init, e)
        end
        return init
    end
end

function pipe.forEach(fun)
    return function(ls)
        for i, e in ipairs(ls) do fun(e) end
    end
end

function pipe.map(fun)
    return function(ls)
        local result = {}
        for i, e in ipairs(ls) do result[i] = fun(e) end
        return result
    end
end


function pipe.mapValues(fun)
    return function(ls)
        local result = {}
        for i, e in pairs(ls) do result[i] = fun(e) end
        return result
    end
end

function pipe.mapPair(fun)
    return function(ls)
        local result = {}
        for i, e in ipairs(ls) do
            local k, v = fun(e)
            result[k] = v
        end
        return result
    end
end

function pipe.filter(pre)
    return function(ls)
        local result = {}
        for _, e in ipairs(ls) do
            if pre(e) then result[#result + 1] = e end
        end
        return result
    end
end

function pipe.concat(t2)
    return function(t1)
        local res = {}
        for _, v in ipairs(t1) do
            table.insert(res, v)
        end
        for _, v in ipairs(t2) do
            table.insert(res, v)
        end
        return res
    end
end

function pipe.flatten()
    return function(ls)
        local result = {}
        for _, v in ipairs(ls) do
            result = pipe.concat(v)(result)
        end
        return result
    end
end

function pipe.mapFlatten(fun)
    return function(ls)
        return pipe.flatten()(pipe.map(fun)(ls))
    end
end

function pipe.map2(ls2, fun)
    return function(ls1)
        local result = {}
        for i, e in ipairs(ls1) do result[i] = fun(e, ls2[i]) end
        return result
    end
end


function pipe.range(from, to)
    return function(ls)
        local result = {}
        for i = from, to do table.insert(result, ls[i]) end
        return result
    end
end

function pipe.contains(e)
    return function(ls)
        for _, x in ipairs(ls) do
            if (x == e) then return true end
        end
        return false
    end
end

function pipe.max(less)
    return function(ls)
        return pipe.fold(ls[1], function(l, r) return less(l, r) and r or l end)(ls)
    end
end

function pipe.min(less)
    return function(ls)
        return pipe.fold(ls[1], function(l, r) return less(l, r) and l or r end)(ls)
    end
end

function pipe.with(newValues)
    return function(ls)
        local result = {}
        for i, e in pairs(ls) do result[i] = e end
        for i, e in pairs(newValues) do result[i] = e end
        return result
    end
end

function pipe.sort(fn)
    return function(ls)
        local result = pipe.with({})(ls)
        table.sort(result, fn)
        return result
    end
end

function pipe.rev()
    return function(ls)
        local result = {}
        for i = #ls, 1, -1 do
            table.insert(result, ls[i])
        end
        return result
    end
end

function pipe.select(name)
    return function(el)
        return el[name]
    end
end

function pipe.exec(...)
    local params = {...}
    return function(fn)
        return fn(table.unpack(params))
    end
end


local pipeMeta = {
    __mul = function(lhs, rhs)
        local result = rhs(lhs)
        setmetatable(result, getmetatable(lhs))
        return result
    end
    ,
    __add = function(lhs, rhs)
        local result = pipe.concat(rhs)(lhs)
        setmetatable(result, getmetatable(lhs))
        return result
    end,
    __div = function(lhs, rhs)
        local result = pipe.concat({rhs})(lhs)
        setmetatable(result, getmetatable(lhs))
        return result
    end
    ,
    __call = function(r)
        return setmetatable(r, nil)
    end
}

pipe.new = {}
setmetatable(pipe.new,
    {
        __mul = function(_, rhs)
            setmetatable(rhs, pipeMeta)
            return rhs
        end,
        __add = function(_, rhs)
            setmetatable(rhs, pipeMeta)
            return rhs
        end,
        __div = function(_, rhs)
            local result = {rhs}
            setmetatable(result, pipeMeta)
            return result
        end
    }
)
pipe.from = function(...)
    local retVal = {...}
    setmetatable(retVal,
        {
            __mul = function(lhs, rhs)
                local result = rhs(table.unpack(lhs))
                setmetatable(result, pipeMeta)
                return result
            end
        })
    return retVal
end

return pipe
