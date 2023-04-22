--  Author: Edward Koltun and Carl Vine
--  Date: 2023/02/07
--  Version: 0.06
--[[
$module FCMTextExpressionDef

## Summary of Modifications
- Setters that accept `FCString` also accept a Lua string.
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
- Methods that returned a boolean to indicate success/failure now throw an error instead.
]] --

local mixin = require("library.mixin")
local mixin_proxy = require("library.mixin_proxy")

local meta = {}
local public = {}

local temp_str = finale.FCString()


--[[
% SaveNewTextBlock

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.
- Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (string | FCString) The initializing string
]]
public.SaveNewTextBlock = mixin_proxy.fcstring_setter(mixin_proxy.boolean_to_error("SaveNewTextBlock_"), 2, temp_str)

--[[
% AssignToCategory

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
@ cat_def (FCCategoryDef) the parent Category Definition
]]
public.AssignToCategory = mixin_proxy.boolean_to_error("AssignToCategory_")

--[[
% SetUseCategoryPos

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
@ enable (boolean)
]]

public.SetUseCategoryPos = mixin_proxy.boolean_to_error("SetUseCategoryPos_")

--[[
% SetUseCategoryFont

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
@ enable (boolean)
]]
public.SetUseCategoryFont = mixin_proxy.boolean_to_error("SetUseCategoryFont_")

--[[
% MakeRehearsalMark

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (FCMTextExpressionDef)
@ [str] (FCString)
@ measure (integer)
: (string) If `FCString` is omitted.
]]
public.MakeRehearsalMark = mixin_proxy.fcstring_getter(mixin_proxy.boolean_to_error("MakeRehearsalMark_"), 2, 3, temp_str)

--[[
% SaveTextString

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.
- Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (string | FCString) The initializing string
]]
public.SaveTextString = mixin_proxy.fcstring_setter(mixin_proxy.boolean_to_error("SaveTextString_"), 2, temp_str)

--[[
% DeleteTextBlock

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
]]
public.DeleteTextBlock = mixin_proxy.boolean_to_error("DeleteTextBlock_")


--[[
% SetDescription

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `FCString`.

@ self (FCMTextExpressionDef)
@ str (string | FCString) The initializing string
]]
public.SetDescription = mixin_proxy.fcstring_setter("SetDescription_", 2, temp_str)

--[[
% GetDescription

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (FCMTextExpressionDef)
@ [str] (FCString)
: (string) Returned if `str` is omitted.
]]
public.GetDescription = mixin_proxy.fcstring_getter("GetDescription_", 2, 2, temp_str)

--[[
% DeepSaveAs

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
@ item_num (integer)
]]
public.DeepSaveAs = mixin_proxy.boolean_to_error("DeepSaveAs_")

--[[
% DeepDeleteData

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (FCMTextExpressionDef)
]]
public.DeepDeleteData = mixin_proxy.boolean_to_error("DeepDeleteData_")

return {meta, public}
