--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module xFCUI

## Summary of Modifications
-- Added `CalcDefaultMeasurementUnit` for resolving `finale.MEASUREMENTUNIT_DEFAULT`
]] --
local finext = require("library.finext")

local class = {StaticMethods = {}}
local static = class.StaticMethods

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
