--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module xFCUI

## Summary of Modifications
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
-- Added numerous static methods for handling measurement units.
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

local measurementunits = {
    [finale.MEASUREMENTUNIT_DEFAULT] = true,
    [finale.MEASUREMENTUNIT_EVPUS] = true,
    [finale.MEASUREMENTUNIT_INCHES] = true,
    [finale.MEASUREMENTUNIT_CENTIMETERS] = true,
    [finale.MEASUREMENTUNIT_POINTS] = true,
    [finale.MEASUREMENTUNIT_PICAS] = true,
    [finale.MEASUREMENTUNIT_SPACES] = true,
    [finale.MEASUREMENTUNIT_MILLIMETERS] = true,
}

--[[
% IsMeasurementUnit

**[Static]**

Checks if the value is equal to one of the `finale.MEASUREMENTUNIT_*` constants.

@ measurementunit (number) The unit to check.
: (boolean) `true` if valid, `false` if not.
]]
function static.IsMeasurementUnit(measurementunit)
    return measurementunits[measurementunit] and true or false
end

--[[
% IsDisplayMeasurementUnit

**[Static]**

Checks if the value is equal to one of the `finale.MEASUREMENTUNIT_*` constants that appears in Finale's user interface.
Internal measurement units (ie`finale.MEASUREMENTUNIT_MILLIMETERS`) and `finale.MEASUREMENTUNIT_DEFAULT` are excluded and will return `false`.

@ measurementunit (number) The unit to check.
: (boolean) `true` if valid, `false` if not.
]]
function static.IsDisplayMeasurementUnit(measurementunit)
    return measurementunit ~= finale.MEASUREMENTUNIT_MILLIMETERS and measurementunits[measurementunit] and true or false
end

--[[
% GetDisplayMeasurementUnits

**[Static]**

Returns a list of measurement units that are available in Finale's user interface in the order that they appear.

*Note: `finale.MEASUREMENTUNIT_DEFAULT` is not included in this list*

]]
function static.GetDisplayMeasurementUnits()
    return {
        finale.MEASUREMENTUNIT_INCHES,
        finale.MEASUREMENTUNIT_CENTIMETERS,
        finale.MEASUREMENTUNIT_POINTS,
        finale.MEASUREMENTUNIT_PICAS,
        finale.MEASUREMENTUNIT_SPACES,
        finale.MEASUREMENTUNIT_EVPUS,
    }
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
