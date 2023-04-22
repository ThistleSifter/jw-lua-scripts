--  Author: Edward Koltun
--  Date: April 13, 2021
--[[
$module FCMUI

## Summary of Modifications
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
]] --
local mixin = require("library.mixin")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local public = {}

local temp_str = finale.FCString()

--[[
% GetDecimalSeparator

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (FCMUI)
@ [str] (FCString)
: (string)
]]
public.GetDecimalSeparator = mixin_proxy.fcstring_getter("GetDecimalSeparator_", 2, 2)

return {meta, public}
