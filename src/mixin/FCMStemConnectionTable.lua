--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMStemConnectionTable

Summary of modifications:
- Methods that accept an `FCString` parameter now also accept a Lua `string`.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% FindIndex

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMStemConnectionTable)
@ fontname (FCString|string)
@ character (number)
: (number)
]]
function props:FindIndex(fontname, character)
    mixin.assert_argument(fontname, {"string", "FCString"}, 2)
    mixin.assert_argument(character, "number", 3)

    if type(fontname) ~= "userdata" then
        temp_str.LuaString = tostring(fontname)
        fontname = temp_str
    end

    return self:FindIndex_(fontname, character)
end

return props
