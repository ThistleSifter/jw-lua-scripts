--  Author: Edward Koltun and Carl Vine
--  Date: 2023/02/07
--  Version: 0.07
--[[
$module xFCTextExpressionDef

## Summary of Modifications
- Setters that accept `xFCString` also accept a Lua `string`.
- `xFCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
- Methods that returned a boolean to indicate success/failure now throw an error instead.
]] --

local finext = require("library.finext")
local finext_proxy = require("library.finext_proxy")

local class = {Methods = {}}
local methods = class.Methods

local temp_str = finext.xFCString()


--[[
% SaveNewTextBlock

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.
- Accepts Lua `string` in addition to `xFCString`.

@ self (xFCTextExpressionDef)
@ str (string | xFCString) The initializing string
]]

methods.SaveNewTextBlock = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("SaveNewTextBlock"), 2, temp_str)

--[[
% AssignToCategory

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
@ cat_def (FCCategoryDef) the parent Category Definition
]]

methods.AssignToCategory = finext_proxy.boolean_to_error("AssignToCategory")

--[[
% SetUseCategoryPos

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
@ enable (boolean)
]]

methods.SetUseCategoryPos = finext_proxy.boolean_to_error("SetUseCategoryPos")

--[[
% SetUseCategoryFont

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
@ enable (boolean)
]]

methods.SetUseCategoryFont = finext_proxy.boolean_to_error("SetUseCategoryFont")

--[[
% MakeRehearsalMark

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.
- Passing an `xFCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCTextExpressionDef)
@ [str] (xFCString)
@ measure (integer)
: (string) If `xFCString` is omitted.
]]

methods.MakeRehearsalMark = finext_proxy.xfcstring_getter(finext_proxy.boolean_to_error("MakeRehearsalMark"), 2, 3, temp_str)

--[[
% SaveTextString

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.
- Accepts Lua `string` in addition to `xFCString`.

@ self (xFCTextExpressionDef)
@ str (string | xFCString) The initializing string
]]

methods.SaveTextString = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("SaveTextString"), 2, temp_str)

--[[
% DeleteTextBlock

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
]]

methods.DeleteTextBlock = finext_proxy.boolean_to_error("DeleteTextBlock")

--[[
% SetDescription

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.

@ self (xFCTextExpressionDef)
@ str (string | xFCString) The initializing string
]]

methods.SetDescription = finext_proxy.xfcstring_setter("SetDescription", 2, temp_str)

--[[
% GetDescription

**[?Fluid] [Override]**

Override Changes:
- Passing an `xFCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCTextExpressionDef)
@ [str] (xFCString)
: (string) Returned if `str` is omitted.
]]

methods.GetDescription = finext_proxy.xfcstring_getter("GetDescription", 2, 2, temp_str)

--[[
% DeepSaveAs

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
@ item_num (integer)
]]

methods.DeepSaveAs = finext_proxy.boolean_to_error("DeepSaveAs")

--[[
% DeepDeleteData

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCTextExpressionDef)
]]

methods.DeepDeleteData = finext_proxy.boolean_to_error("DeepDeleteData")


return class
