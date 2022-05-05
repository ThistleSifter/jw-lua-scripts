--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMTextMetrics

Summary of modifications:
- Methods that accept an `FCString` parameter now also accept a Lua `string`.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% LoadString

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextMetrics)
@ str (FCString|string)
@ enclosure (FCFontInfo)
@ percent (number)
: (boolean) `True` on success. `False` if an unallowed parameter has been passed to the method. On Finale versions lower than Finale 25, `false` will always be returned.
]]
function props:LoadString(str, font, percent)
    mixin.assert_argument(str, {"string", "FCString"}, 2)
    mixin.assert_argument(font, "FCFontInfo", 3)
    mixin.assert_argument(percent, "number", 4)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:LoadString_(str, font, percent)
end

return props
