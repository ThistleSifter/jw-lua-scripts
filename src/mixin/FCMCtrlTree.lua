--  Author: Edward Koltun
--  Date: April 6, 2022
--[[
$module FCMCtrlTree

## Summary of Modifications
- Methods that accept `FCString` will also accept Lua `string` or `number`.
]] --
local mixin = require("library.mixin")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local props = {}

local temp_str = finale.FCString()

--[[
% AddNode

**[Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (FCMCtrlTree)
@ parentnode (FCTreeNode | nil)
@ iscontainer (boolean)
@ text (FCString | string | number)
: (FCMTreeNode)
]]
public.AddNode = mixin_proxy.fcstring_setter("AddNode_", 4, temp_str)

return {meta, public}
