--  Author: Edward Koltun
--  Date: 2023/02/07
--[[
$module FinExt Helper

A library of helper functions to improve code reuse in extensiona.
]]--
require("library.lua_compatibility")
local utils = require("library.utils")
local finext = require("library.finext")
local library = require("library.general_library")

local finext_helper = {}

local debug_enabled = finenv.DebugEnabled

--[[
% is_instance_of

Checks if a Finale object or an extension is an instance of at least one of the provided class names.

@ object (__FCBase | __xFCBase) A Finale object or an extension.
@ ... (strings) One or more class names to check. Can also be abstract parent class names.
: (boolean) `true` if there is a match for at least one of the provided class names. `false` if no matches.
]]
function finext_helper.is_instance_of(object, ...)
    local fc_class_names = {n = 0}
    local ext_class_names = {n = 0}
    local has_fc = false
    local has_ext = false

    for i = 1, select("#", ...) do
        local class_name = select(i, ...)
        -- Skip over anything that isn't a class name (for easy integration with `assert_argument_type`)
        if finext.IsFCClassName(class_name) then
            fc_class_names[class_name] = true
            has_fc = true
        elseif finext.IsxFCClassName(class_name) or finext.IsxFXClassName(class_name) then
            ext_class_names[class_name] = true
            has_ext = true
        end
    end

    if library.is_finale_object(object) then
        if not has_fc then
            return false
        end

        local class_name = library.get_class_name(object)
        while class_name do
            if fc_class_names[class_name] then
                return true
            end
            class_name = library.get_parent_class(class_name)
        end
    elseif finext.IsExtension(object) then
        if not has_ext then
            return false
        end

        local class_name = object.ExtClassName
        while class_name do
            if ext_class_names[class_name] then
                return true
            end
            class_name = finext[class_name].ExtParent
        end
    end

    return false
end

local function assert_argument_type(levels, argument_number, value, ...)
    local primary_type = type(value)
    local secondary_type
    if primary_type == "number" then
        secondary_type = math.type(value)
    end

    for i = 1, select("#", ...) do
        local t = select(i, ...)
        if t == primary_type or (secondary_type and t == secondary_type) then
            return
        end
    end

    if finext_helper.is_instance_of(value, ...) then
        return
    end

    -- Determine type for error message
    if library.is_finale_object(value) then
        secondary_type = value.ClassName
    elseif finext.IsExtension(value) then
        secondary_type = value.ExtClassName
    end

    error("bad argument #" .. tostring(argument_number) .. " to 'tryfunczzz' (" .. table.concat(table.pack(...), " or ") .. " expected, got " .. (secondary_type or primary_type) .. ")", levels)
end


--[[
% assert_argument_type

Asserts that an argument to an extension method is of the expected type(s). This should only be used within extension methods as the function name will be inserted automatically.

If not a valid type, will throw a bad argument error at the level above where this function is called.

The followimg types can be specified:
- Standard Lua types (`string`, `number`, `boolean`, `table`, `function`, `nil`, etc),
- Number types (`integer` or `float`).
- Finale classes, including parent classes (eg `FCString`, `FCMeasure`, `FCControl`, etc).
- Extension classes, including parent classes (eg `xFCString`, `xFCMeasure`, `xFCControl`, etc).

*NOTE: This function will only assert if in debug mode (ie `finenv.DebugEnabled == true`). If assertions are always required, use `force_assert_argument_type` instead.*

@ argument_number (number) The REAL argument number for the error message (self counts as argument #1).
@ value (any) The value to test.
@ ... (string) Valid types (as many as needed). Can be standard Lua types, Finale class names, or extension class names.
]]
function finext_helper.assert_argument_type(argument_number, value, ...)
    if debug_enabled then
        assert_argument_type(4, argument_number, value, ...)
    end
end

--[[
% force_assert_argument_type

The same as `assert_argument_type` except this function always asserts, regardless of whether debug mode is enabled.

@ argument_number (number) The REAL argument number for the error message (self counts as argument #1).
@ value (any) The value to test.
@ ... (string) Valid types (as many as needed). Can be standard Lua types, Finale class names, or extension class names.
]]
function finext_helper.force_assert_argument_type(argument_number, value, ...)
    assert_argument_type(4, argument_number, value, ...)
end

local function assert_func(condition, message, level)
    if type(condition) == 'function' then
        condition = condition()
    end

    if not condition then
        error(message, level)
    end
end

--[[
% assert

Asserts a condition in an Extension method. If the condition is false, an error is thrown one level above where this function is called.

*NOTE: This function will only assert if in debug mode (ie `finenv.DebugEnabled == true`). If assertions are always required, use `force_assert` instead.*

@ condition (any) Can be any value or expression. If a function, it will be called (with zero arguments) and the result will be tested.
@ message (string) The error message.
@ [level] (number) Optional level to throw the error message at (default is 2).
]]
function finext_helper.assert(condition, message, level)
    if debug_enabled then
        assert_func(condition, message, level == 0 and 0 or 2 + (level or 2))
    end
end

--[[
% force_assert

The same as `assert` except this function always asserts, regardless of whether debug mode is enabled.

@ condition (any) Can be any value or expression.
@ message (string) The error message.
@ [level] (number) Optional level to throw the error message at (default is 2).
]]
function finext_helper.force_assert(condition, message, level)
    assert_func(condition, message, level == 0 and 0 or 2 + (level or 2))
end

return finext_helper
