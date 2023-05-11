--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module xFCStrings

## Summary of Modifications
- Setters that accept `FCString` also accept a Lua `string`.
- Methods that returned a boolean to indicate success/failure now throw an error instead.
- Added polyfill for `CopyFromStringTable`.
- Added `CreateStringTable` method.
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")
local finext_proxy = require("library.finext_proxy")
local utils = require("library.utils")

local class = {Methods = {}}
local methods = class.Methods

local temp_str = finext.xFCString()

--[[
% AddCopy

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` and `number` in addition to `FCString`.
- Throws an error instead of returning a boolean to indicate success/failure.

@ self (xFCStrings)
@ str (xFCString | string | number)
]]
methods.AddCopy = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("AddCopy"), 2, temp_str)

--[[
% AddCopies

Same as `AddCopy`, but accepts multiple arguments to allow multiple values to be added at a time.

@ self (xFCStrings)
@ ... (xFCStrings | xFCString | string | number) `number`s will be cast to `string`
]]
function methods:AddCopies(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        finext_helper.assert_argument_type(i + 1, v, "xFCStrings", "xFCString", "string", "number")
        if finext_helper.is_instance_of(v, "xFCStrings") then
            for str in each(v) do
                self:AddCopy(str)
            end
        else
            self:AddCopy(v)
        end
    end
end

--[[
% CopyFromStringTable

**[Fluid] [Polyfill]**

Polyfills `FCStrings.CopyFromStringTable` for earlier RGP/JWLua versions.

@ self (xFCStrings)
@ strings (table)
]]
if not finale.FCStrings.__class.CopyFromStringTable then
    function methods:CopyFromStringTable(strings)
        finext_helper.assert_argument_type(2, strings, "table")

        self:ClearAll()
        for _, v in pairs(strings) do
            self:AddCopy(v)
        end
    end
end

--[[
% CreateLuaString

The same as `CreateString` except a Lua `string` is returned instead of an `xFCString`.

@ self (xFCStrings)
@ separator (string | nil)
: (string)
]]
function methods:CreateLuaString(separator)
    return utils.call_and_rethrow(2, self.__.CreateString, self.__, separator).LuaString
end

--[[
% CreateRowsLuaString

The same as `CreateRowsString` except a Lua `string` is returned instead of an `xFCString`.

@ self (xFCStrings)
@ newlineatend (boolean)
: (string)
]]
function methods:CreateRowsLuaString(newlineatend)
    return utils.call_and_rethrow(2, self.__.CreateRowsString, self.__, newlineatend).LuaString
end

--[[
% Find

**[Override]**

Override Changes:
- Accepts Lua `string` and `number` in addition to `FCString`.

@ self (xFCStrings)
@ str (xFCString | string | number)
: (xFCString | nil)
]]
methods.Find = finext_proxy.xfcstring_setter("Find", 2, temp_str)

--[[
% FindLuaString

The same as `Find` except a Lua `string` is returned instead of an `xFCString`.

@ self (xFCStrings)
@ str (xFCString | string | number)
: (string | nil)
]]
function methods:FindLuaString(str)
    local result = utils.call_and_rethrow(2, self.Find, self, str)
    return result and result.LuaString or nil
end

--[[
% FindNocase

**[Override]**

Override Changes:
- Accepts Lua `string` and `number` in addition to `FCString`.

@ self (xFCStrings)
@ str (xFCString | string | number)
: (xFCString | nil)
]]
methods.FindNocase = finext_proxy.xfcstring_setter("FindNocase", 2, temp_str)

--[[
% FindNocaseLuaString

The same as `FindNocase` except a Lua `string` is returned instead of an `xFCString`.

@ self (xFCStrings)
@ str (xFCString | string | number)
: (string | nil)
]]
function methods:FindNocaseLuaString(str)
    local result = utils.call_and_rethrow(2, self.FindNocase, self, str)
    return result and result.LuaString or nil
end

--[[
% InsertStringAt

**[>= v0.59] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` and `number` in addition to `xFCString`.

@ self (xFCStrings)
@ newstring (xFCString | string | number)
@ index (integer)
]]
if finale.xFCStrings.__class.InsertStringAt then
    method.InsertStringAt = finext_proxy.xfcstring_setter("InsertStringAt", 2, temp_str)
end

--[[
% LoadFolderFiles

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCStrings)
@ folderstring (xFCString | string)
]]
methods.LoadFolderFiles = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("LoadFolderFiles"), 2, temp_str)

--[[
% LoadSubfolders

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Accepts Lua `string` in addition to `xFCString`.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCStrings)
@ folderstring (xFCString | string)
]]
methods.LoadSubfolders = finext_proxy.xfcstring_setter(finext_proxy.boolean_to_error("LoadSubfolders"), 2, temp_str)

--[[
% LoadSymbolFonts

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCStrings)
]]
methods.LoadSymbolFonts = finext_helper.boolean_to_error("LoadSymbolFonts")

--[[
% LoadSystemFontNames

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCStrings)
]]
methods.LoadSystemFontNames = finext_helper.boolean_to_error("LoadSystemFontNames")

--[[
% CreateStringTable

Creates a table of Lua `string`s from the `xFCString`s in this collection.

@ self (xFCStrings)
: (table)
]]
function methods:CreateStringTable()
    local t = {}
    for str in each(self) do
        table.insert(t, str.LuaString)
    end
    return t
end

return class
