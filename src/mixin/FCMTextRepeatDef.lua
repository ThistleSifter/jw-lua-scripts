--  Author: Edward Koltun
--  Date: May 05, 2021
--[[
$module FCMTextRepeatDef

Summary of modifications:
- In getters with an `FCString` parameter, the parameter is now optional and a Lua `string` is returned.
]] --
local mixin = require("library.mixin")

local props = {}

local temp_str = finale.FCString()

--[[
% DeepSaveNew

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextRepeatDef)
@ str (FCString|string)
@ enclosure (FCEnclosure|nil)
: (boolean) `True` on success.
]]
function props:DeepSaveNew(str, enclosure)
    mixin.assert_argument(str, {"string", "FCString"}, 2)
    mixin.assert_argument(enclosure, {"FCEnclosure", "nil"}, 3)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:DeepSaveNew_(str, enclosure)
end

--[[
% SaveTextString

**[Override]**
Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextRepeatDef)
@ str (FCString|string)
: (boolean) `True` on success.
]]
function props:SaveTextString(str)
    mixin.assert_argument(str, {"string", "FCString"}, 2)

    if type(str) ~= "userdata" then
        temp_str.LuaString = tostring(str)
        str = temp_str
    end

    return self:SaveTextString_(str)
end

return props
