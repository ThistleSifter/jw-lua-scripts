--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMSyllableBase

Summary of modifications:
- Methods that accept an `FCString` parameter now also accept a Lua `string`.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% SaveRawText

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMSyllableBase)
@ str (FCString|string)
: (boolean)
]]
function props:SaveRawText(str)
    mixin.assert_argument(str, {"string", "FCString"}, 2)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:SaveRawText_(str)
end

return props
