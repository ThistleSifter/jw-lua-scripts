--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMTimeSignature

Summary of modifications:
- In getters with an `FCString` parameter, the parameter is now optional and a Lua `string` is returned.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% MakeString

**[Override]**
Returns a Lua `string` and makes passing an `FCString` optional.

@ self (FCMTimeSignature)
@ [str] (FCString)
: (string)
]]
function props:MakeString(str)
    mixin.assert_argument(str, {"nil", "FCString"}, 2)

    str = str or temp_str

    self:MakeString_(str)

    return str.LuaString
end

return props
