--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module FCMCtrlDataList

## Summary of Modifications
- Setters that accept `FCString` will also accept a Lua `string` or `number`.
- Added methods to allow handlers for the `DataListCheck` and `DataListSelect` events be set directly on the control.
]] --
local mixin = require("library.mixin")
local mixin_helper = require("library.mixin_helper")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local public = {}

local temp_str = finale.FCString()

--[[
% AddColumn

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (FCMCtrlDataList)
@ title (FCString | string | number)
@ columnwidth (number)
]]
public.AddColumn = mixin_proxy.fcstring_setter("AddColumn_", 2, temp_str)

--[[
% SetColumnTitle

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (FCMCtrlDataList)
@ columnindex (number)
@ title (FCString | string | number)
]]
public.SetColumnTitle = mixin_proxy.fcstring_setter("SetColumnTitle_", 3, temp_str)

--[[
% AddHandleCheck

**[Fluid]**

Adds a handler for DataListCheck events.

@ self (FCMCtrlDataList)
@ callback (function) See `FCCustomLuaWindow.HandleDataListCheck` in the PDK for callback signature.
]]

--[[
% RemoveHandleCheck

**[Fluid]**

Removes a handler added with `AddHandleCheck`.

@ self (FCMCtrlDataList)
@ callback (function)
]]
public.AddHandleCheck, public.RemoveHandleCheck = mixin_helper.create_standard_control_event("HandleDataListCheck")

--[[
% AddHandleSelect

**[Fluid]**

Adds a handler for `DataListSelect` events.

@ self (FCMCtrlDataList)
@ callback (function) See `FCCustomLuaWindow.HandleDataListSelect` in the PDK for callback signature.
]]

--[[
% RemoveHandleSelect

**[Fluid]**

Removes a handler added with `AddHandleSelect`.

@ self (FCMCtrlDataList)
@ callback (function)
]]
public.AddHandleSelect, public.RemoveHandleSelect = mixin_helper.create_standard_control_event("HandleDataListSelect")

return {meta, public}
