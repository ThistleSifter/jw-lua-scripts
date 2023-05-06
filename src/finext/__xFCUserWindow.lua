--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module __xFCUserWindow

## Summary of Modifications
- Setters that accept `FCString` will also accept a Lua `string`.
- `FCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

local class = {Methods = {}}
local methods = class.Methods

local temp_str = finext.xFCString()

--[[
% GetTitle

**[?Fluid] [Override]**

Override Changes:
- Passing an `FCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (__xFCUserWindow)
@ [title] (xFCString)
: (string) Returned if `title` is omitted.
]]
function methods:GetTitle(title)
    finext_helper.assert_argument_type(2, title, "nil", "xFCString")

    local do_return = false
    if not title then
        title = temp_str
        do_return = true
    end

    self.__:GetTitle(title.__)

    if do_return then
        return title.LuaString
    end
end

--[[
% SetTitle

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `FCString`.

@ self (__xFCMserWindow)
@ title (xFCString | string | number)
]]
function methods:SetTitle(title)
    finext_helper.assert_argument_type(2, title, "string", "number", "xFCString")

    self.__:SetTitle(finext.xFCString.ToxFCString(title, temp_str).__)
end

return class
