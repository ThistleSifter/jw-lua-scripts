--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module xFCUI

## Summary of Modifications
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
- Methods that returned a boolean to indicate success/failure now throw an error instead.
- Added numerous static methods for handling measurement units.
]] --
local finext = require("library.finext")
local finext_proxy = require("library.finext_proxy")

local class = {Methods = {}, StaticMethods = {}}
local methods = class.Methods
local static = class.StaticMethods

local temp_str = finext.xFCString()

--[[
% ActivateDocumentWindow

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
]]
methods.ActivateDocumentWindow = finext_proxy.boolean_to_error("ActivateDocumentWindow")

--[[
% DisplayShellFolder

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ folderstring (string | xFCString)
]]
methods.DisplayShellFolder = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("DisplayShellFolder"), 2, temp_str)

--[[
% DisplayWebURL

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ urlstring (string | xFCString)
]]
methods.DisplayWebURL = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("DisplayWebURL"), 2, temp_str)

--[[
% ExecuteOSMenuCommand

**[>= v0.58] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ osmenucmd (integer)
]]
if finale.FCUI._class.ExecuteOSMenuCommand then
    methods.ExecuteOSMenuCommand = finext_proxy.boolean_to_error("ExecuteOSMenuCommand")
end

--[[
% GetDecimalSeparator

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCUI)
@ [str] (xFCString)
: (string) Returned if `str` is omitted.
]]
methods.GetDecimalSeparator = finext_proxy.xfcstring_getter("GetDecimalSeparator", 2, 2, temp_str)

--[[
% GetUserLocaleName

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCUI)
@ [str] (xFCString)
: (string) Returned if `str` is omitted.
]]
if finale.FCUI.__class.GetUserLocaleName then
    methods.GetUserLocaleName = finext_proxy.xfcstring_getter("GetUserLocaleName", 2, 2, temp_str)
end

--[[
% IsFontAvailable

**[Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.

@ self (xFCUI)
@ fontname (string | xFCString)
: (boolean)
]]
methods.IsFontAvailable = finext_proxy.xfcstring_setter("IsFontAvailable", 2, temp_str)

--[[
% MenuCommand

**[Breaking Change] [Deprecated] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ menucmd (integer)
]]
methods.MenuCommand = finext_proxy.boolean_to_error("MenuCommand")

--[[
% MenuPositionCommand

**[Breaking Change] [Deprecated] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ mainmenuidx (integer)
@ dropdownidx (integer)
@ submenuidx (integer)
]]
methods.MenuPositionCommand = finext_proxy.boolean_to_error("MenuPositionCommand")

--[[
% TextToClipboard

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCUI)
@ text (string)
]]
methods.TextToClipboard = finext_proxy.boolean_to_error("TextToClipboard")


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
