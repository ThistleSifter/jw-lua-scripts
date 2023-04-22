--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module __FCMUserWindow

## Summary of Modifications
- Setters that accept `FCString` will also accept a Lua `string`.
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
]] --
local mixin = require("library.mixin")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local public = {}

local temp_str = finale.FCString()

--[[
% GetTitle

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (__FCMUserWindow)
@ [title] (FCString)
: (string) Returned if `title` is omitted.
]]
public.GetTitle = mixin_proxy.fcstring_getter("GetTitle_", 2, 2)

--[[
% SetTitle

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (__FCMUserWindow)
@ title (FCString | string | number)
]]
public.SetTitle = mixin_proxy.fcstring_setter("SetTitle_", 2)

return {meta, public}
