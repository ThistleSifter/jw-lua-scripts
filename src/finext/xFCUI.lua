--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module xFCUI

## Summary of Modifications
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
-- Added `CalcDefaultMeasurementUnit` for resolving `finale.MEASUREMENTUNIT_DEFAULT`
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

local class = {Methods = {}, StaticMethods = {}}
local methods = class.Methods
local static = class.StaticMethods

local temp_str = finext.xFCString()

--[[
% GetDecimalSeparator

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCUI)
@ [str] (xFCString)
: (string)
]]
function methods:GetDecimalSeparator(str)
    finext_helper.assert_argument_type(2, str, "nil", "xFCString")

    local do_return = false
    if not str then
        str = temp_str
        do_return = true
    end

    self.__:GetDecimalSeparator(str.__)

    if do_return then
        return str.LuaString
    end
end

--[[
% CalcDefaultMeasurementUnit

**[Static]**

Resolves `finale.MEASUREMENTUNIT_DEFAULT` to the value of one of the other `finale.MEASUREMENTUNIT_*` constants.

: (number)
]]
function static.CalcDefaultMeasurementUnit()
    local str = finale.FCString()
    finenv.UI():GetDecimalSeparator(str)
    local separator = str.LuaString
    str:SetMeasurement(72, finale.MEASUREMENTUNIT_DEFAULT)

    if str.LuaString == "72" then
        return finale.MEASUREMENTUNIT_EVPUS
    elseif str.LuaString == "0" .. separator .. "25" then
        return finale.MEASUREMENTUNIT_INCHES
    elseif str.LuaString == "0" .. separator .. "635" then
        return finale.MEASUREMENTUNIT_CENTIMETERS
    elseif str.LuaString == "18" then
        return finale.MEASUREMENTUNIT_POINTS
    elseif str.LuaString == "1p6" then
        return finale.MEASUREMENTUNIT_PICAS
    elseif str.LuaString == "3" then
        return finale.MEASUREMENTUNIT_SPACES
    end
end

return class
