--  Author: Edward Koltun
--  Date: April 21, 2023
--[[
$module FinExt Proxy

The library contains functions for creating various types of proxy methods for extensions.

Proxies can be chained together by passing the result from one creator function as the `func` argument to another creator function.
]]

local finext = require("library.finext")
local utils = require("library.utils")
local finext_proxy = {}

local function resolve_func(func)
    if type(func) == "string" then
        return function(self, ...)
            return finext.__(self, func, ...)
        end
    end

    return func
end

--[[
% xfcstring_setter

Creates a proxy for a setter method that accepts an `xFCString` argument.
The proxy will accept any value in place of the `xFCString`, casting them to an `xFCString` before calling the original method.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
@ argument_number (number) The real argument number of the `xFCString` parameter (`self` is argument #1).
@ [xfcstr] (xFCString) Optional `xFCString` object that can be reused for casting.
: (function) Extension proxy method.
]]
function finext_proxy.xfcstring_setter(func, argument_number, xfcstr)
    func = resolve_func(func)
    return function(self, ...)
        local args = {}
        table.pack(args, ...)
        args[argument_number - 1] = finext.xFCString.ToxFCString(args[argument_number - 1], xfcstr)
        return func(self, table.unpack(args))
    end
end

--[[
% xfcstring_getter

Creates a proxy for a getter method that expects an `xFCString` parameter in which to place the result. The returned proxy method has the following behaviour:
- The `xFCString` parameter is optional, regardless of where it is in the signature.
- If an `xFCString` is passed, the behaviour is that of the original method (ie fluid, in most cases).
- If the `xFCString` is omitted, the result is returned as Lua string.
- This proxy is only designed to work with one optional parameter.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
@ argument_number (number) The real argument number of the `xFCString` parameter (`self` is argument #1).
@ total_num_args (number) The total number of expected arguments, including the `xFCString` argument.
@ [xfcstr] (FCString) Optional `xFCString` object to be reused as the inserted parameter.
: (function) Extension proxy method.
]]
function finext_proxy.xfcstring_getter(func, argument_number, total_num_args, xfcstr)
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
        local xfcstring = xfcstr or finext.xFCString()
        table.insert(args, argument_number - 1, xfcstring)
        utils.catch_and_rethrow(rethrow_opt, func, table.unpack(args))
        return xfcstring.LuaString
    end
end

--[[
% boolean_to_error

Creates a proxy that takes a boolean status result and if false, throws an error. The proxy returns nothing, so the resulting method is fluid.

@ func (string | function) The function to proxy. Can be either the name of the original method to be called on the `self` object or a function.
: (function) Extension proxy method.
]]
function finext_proxy.boolean_to_error(func)
    func = resolve_func(func)
    return function(self, ...)
        if not utils.catch_and_rethrow(2, func, self, ...) then
            error(utils.rethrow_placeholder() .. " has encountered an error.", 2)
        end
    end
end

return finext_proxy
