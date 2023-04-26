--  Author: Edward Koltun
--  Date: April 21, 2023
--[[
$module Mixin Proxy

The library contains functions for creating various types of proxy methods for mixins.

Proxies can be chained together by passing the result from one creator function as the `func` argument to another creator function.
]]

local utils = require("library.utils")
local mixin_helper = require("library.mixin_helper")
local mixin_proxy = {}

local function resolve_func(func)
    if type(func) == "string" then
        return function(self, ...)
            return self[func](self, ...)
        end
    end

    return func
end

--[[
% fcstring_setter

Creates a proxy for a setter method that accepts an `FCString` argument.
The proxy will accept any value in place of the `FCString`, casting them to an `FCString` before calling the original method.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
@ argument_number (number) The real argument number of the `FCString` parameter (`self` is argument #1).
@ fcstr [FCString] Optional `FCString` object that can be reused for casting.
: (function) Mixin proxy method.
]]
function mixin_proxy.fcstring_setter(func, argument_number, fcstr)
    func = resolve_func(func)
    return function(self, ...)
        local args = {}
        table.pack(args, ...)
        args[argument_number - 1] = mixin_helper.to_fcstring(args[argument_number - 1], fcstr)
        return func(self, table.unpack(args))
    end
end

--[[
% fcstring_getter

Creates a proxy for a getter method that expects an `FCString` parameter in which to place the result. The returned proxy method has the following behaviour:
- The `FCString` parameter is optional, regardless of where it is in the signature.
- If an `FCString` is passed, the behaviour is that of the original method (ie fluid, in most cases).
- If the `FCString` is omitted, the result is returned as Lua string.
- This proxy is only designed to work with one optional parameter.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
@ argument_number (number) The real argument number of the `FCString` parameter (`self` is argument #1).
@ total_num_args (number) The total number of expected arguments, including the `FCString`.
@ fcstr [FCString] Optional `FCString` object to be reused as the inserted parameter.
: (function) Mixin proxy method.
]]
function mixin_proxy.fcstring_getter(func, argument_number, total_num_args, fcstr)
    func = resolve_func(func)
    local rethrow_opt = {
        level = 2,
        arg_num_rewriter = function(arg_num)
            return arg_num - (arg_num > argument_number and 1 or 0)
        end,
    }

    return function(self, ...)
        if select("#", ...) == total_num_args - 1 then
            return func(self, ...)
        end

        local args = {}
        table.pack(args, ...)
        local fcstring = fcstr or finale.FCString()
        table.insert(args, argument_number - 1, fcstring)
        utils.catch_and_rethrow(rethrow_opt, func, table.unpack(args))
        return fcstring.LuaString
    end
end

--[[
% boolean_to_error

Creates a proxy that takes a boolean status result and if false, throws an error. The proxy returns nothing, so the resulting method is fluid.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
: (function) Mixin proxy method.
]]
function mixin_proxy.boolean_to_error(func)
    func = resolve_func(func)
    return function(self, ...)
        if not utils.catch_and_rethrow(2, func, self, ...) then
            error(utils.rethrow_placeholder() .. " has encountered an error.", 2)
        end
    end
end

return mixin_proxy
