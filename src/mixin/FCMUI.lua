--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module FCMUI

Summary of modifications:
- In getters with an `FCString` parameter, the parameter is now optional and a Lua `string` is returned.
- Other methods that accept an `FCString` now also accept a Lua `string`.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% GetDecimalSeparator

**[Override]**
Returns a Lua `string` and makes passing an `FCString` optional.

@ self (FCMUI)
@ [str] (FCString)
: (string)
]]
function props:GetDecimalSeparator(str)
    mixin.assert_argument(str, {"nil", "FCString"}, 2)

    if not str then
        str = temp_str
    end

    self:GetDecimalSeparator_(str)

    return str.LuaString
end

--[[
% DisplayShellFolder

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMUI)
@ folderstring (FCString|string)
: (boolean) `True` if successful.
]]
function props:DisplayShellFolder(folderstring)
    mixin.assert_argument(folderstring, {"string", "FCString"}, 2)

    if type(folderstring) ~= "userdata" then
        temp_str.LuaString = tostring(folderstring)
        folderstring = temp_str
    end

    return self:DisplayShellFolder_(folderstring)
end

--[[
% DisplayWebURL

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMUI)
@ urlstring (FCString|string)
: (boolean) `True` if successful.
]]
function props:DisplayWebURL(urlstring)
    mixin.assert_argument(urlstring, {"string", "FCString"}, 2)

    if type(urlstring) ~= "userdata" then
        temp_str.LuaString = tostring(urlstring)
        urlstring = temp_str
    end

    return self:DisplayWebURL_(urlstring)
end

--[[
% IsFontAvailable

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMUI)
@ fontname (FCString|string)
: (boolean)
]]
function props:IsFontAvailable(fontname)
    mixin.assert_argument(fontname, {"string", "FCString"}, 2)

    if type(fontname) ~= "userdata" then
        temp_str.LuaString = tostring(fontname)
        fontname = temp_str
    end

    return self:IsFontAvailable_(fontname)
end

return props
