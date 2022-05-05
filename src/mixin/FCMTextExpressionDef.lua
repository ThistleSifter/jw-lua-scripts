--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMTextExpressionDef

Summary of modifications:
- Methods that accept an `FCString` parameter now also accept a Lua `string`.
- In getters with an `FCString` parameter, the parameter is now optional and a Lua `string` is returned.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% GetDescription

**[Override]**
Returns a Lua `string` and makes passing an `FCString` optional.

@ self (FCMTextExpressionDef)
@ [descriptionstring] (FCString)
: (string)
]]
function props:GetDescription(descriptionstring)
    mixin.assert_argument(descriptionstring, {"nil", "FCString"}, 2)

    if not descriptionstring then
        descriptionstring = temp_str
    end

    self:GetDescription_(descriptionstring)

    return descriptionstring.LuaString
end

--[[
% MakeRehearsalMark

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (FCString|string)
@ measure (number)
: (boolean) `True` if successful.
]]
function props:MakeRehearsalMark(str, measure)
    mixin.assert_argument(str, {"string", "FCString"}, 2)
    mixin.assert_argument(measure, "number", 2)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:MakeRehearsalMark_(str, measure)
end

--[[
% SaveNewTextBlock

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (FCString|string)
: (boolean)
]]
function props:SaveNewTextBlock(str)
    mixin.assert_argument(str, {"string", "FCString"}, 2)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:SaveNewTextBlock_(str)
end

--[[
% SaveTextString

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (FCString|string)
: (boolean)
]]
function props:SaveTextString(str)
    mixin.assert_argument(str, {"string", "FCString"}, 2)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:SaveTextString_(str)
end

--[[
% SetDescription

**[Fluid] [Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ descriptionstring (FCString|string)
]]
function props:SetDescription(descriptionstring)
    mixin.assert_argument(descriptionstring, {"string", "FCString"}, 2)

    if type(descriptionstring) ~= "userdata" then
        temp_str.LuaString = tostring(descriptionstring)
        descriptionstring = temp_str
    end

    self:SetDescription_(descriptionstring)
end

return props
