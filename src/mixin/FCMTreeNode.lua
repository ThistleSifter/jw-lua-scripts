--  Author: Edward Koltun
--  Date: April 6, 2022
--[[
$module FCMTreeNode

## Summary of Modifications
- Setters that accept `FCString` also accept a Lua `string` or `number`.
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
]] --
local mixin = require("library.mixin")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local public = {}

local temp_str = finale.FCString()

--[[
% GetText

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (FCMTreeNode)
@ [str] (FCString)
: (string) Returned if `str` is omitted.
]]
public.GetText = mixin_proxy.fcstring_getter("GetText_", 2, 2, temp_str)

--[[
% SetText

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (FCMTreeNode)
@ str (FCString | string | number)
]]
public.SetText = mixin_proxy.fcstring_setter("SetText_", 2, temp_str)

return {meta, public}
