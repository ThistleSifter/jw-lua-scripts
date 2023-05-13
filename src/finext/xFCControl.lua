--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module xFCControl

## Summary of Modifications
- Setters that accept `xFCString` also accept a Lua `string` or `number`.
- `xFCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
- Ported `GetParent` from PDK to allow the parent window to be accessed from a control.
- Added methods to allow handlers for the `Command` event to be set directly on the control.
- Added methods for storing and restoring control state, allowing controls to preserve their values across multiple script executions (only works if parent is `xFCCustomLuaWindow`).
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

local class = {Methods = {}}
local methods = class.Methods
local private = setmetatable({}, {__mode = "k"})
-- So as not to prevent the window (and by extension the controls) from being garbage collected in the normal way, use weak keys and values for storing the parent window
local parent = setmetatable({}, {__mode = "kv"})

local handle_command = finext.xFCCustomLuaWindow.CreateStandardControlEvent("HandleCommand")
local temp_str = finext.xFCString()

--[[
% Init

**[Internal]**

@ self (xFCControl)
]]
function class:Init()
    if private[self] then
        return
    end

    private[self] = {}
end

--[[
% GetParent

**[PDK Port]**

Returns the control's parent window.

*Do not override or disable this method.*

@ self (xFCControl)
: (xFCCustomWindow)
]]
function methods:GetParent()
    return parent[self]
end

--[[
% __RegisterParent

**[Fluid] [Internal]**

Used to register the parent window when the control is created.

*Do not disable this method.*

@ self (xFCControl)
@ window (xFCCustomWindow)
]]
function methods:__RegisterParent(window)
    finext_helper.assert_argument_type(2, window, "xFCCustomWindow")

    if parent[self] then
        error("This method is for internal use only.", 2)
    end

    parent[self] = window
end

--[[
% GetEnable

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (boolean)
]]

--[[
% SetEnable

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ enable (boolean)
]]

--[[
% GetVisible

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (boolean)
]]

--[[
% SetVisible

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ visible (boolean)
]]

--[[
% GetLeft

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (number)
]]

--[[
% SetLeft

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ left (number)
]]

--[[
% GetTop

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (number)
]]

--[[
% SetTop

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ top (number)
]]

--[[
% GetHeight

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (number)
]]

--[[
% SetHeight

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ height (number)
]]

--[[
% GetWidth

**[Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
: (number)
]]

--[[
% SetWidth

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.

@ self (xFCControl)
@ width (number)
]]
for method, valid_types in pairs({
    Enable = {"boolean", "nil"},
    Visible = {"boolean", "nil"},
    Left = {"number"},
    Top = {"number"},
    Height = {"number"},
    Width = {"number"},
}) do
    methods["Get" .. method] = function(self)
        if finext.xFCControl.__UseStoredControlState(self) then
            return private[self][method]
        end

        return self.__["Get" .. method](self.__)
    end

    methods["Set" .. method] = function(self, value)
        finext_helper.assert_argument_type(2, value, table.unpack(valid_types))

        if finext.xFCControl.__UseStoredControlState(self) then
            private[self][method] = value
        else
            -- Fix bug with text box content being cleared on Mac when Enabled or Visible state is changed
            if (method == "Enable" or method == "Visible") and finenv.UI():IsOnMac() and finenv.MajorVersion == 0 and finenv.MinorVersion < 63 then
                self.__:GetText(temp_str.__)
                self.__:SetText(temp_str.__)
            end

            self.__["Set" .. method](self.__, value)
        end
    end
end

--[[
% GetText

**[?Fluid] [Override]**

Override Changes:
- Passing an `xFCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.
- Hooks into control state preservation.

@ self (xFCControl)
@ [str] (xFCString)
: (string) Returned if `str` is omitted.
]]
methods.GetText = finext_proxy.xfcstring_getter(function(self, str)
    if finext.xFCControl.__UseStoredControlState(self) then
        str.LuaString = private[self].Text
    else
        self.__:GetText(str.__)
    end
end, 2, 2, temp_str)

--[[
% SetText

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `xFCString`.
- Hooks into control state preservation.

@ self (xFCControl)
@ str (xFCString | string | number)
]]
methods.SetText = finext_proxy.xfcstring_setter(function(self, str)
    if finext.xFCControl.__UseStoredControlState(self) then
        private[self].Text = str.LuaString
    else
        self.__:SetText(str.__)
    end
end, 2, temp_str)

--[[
% MoveRelative

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.
- Polyfill for RGPLua < v0.61.
- Can be called when window is not showing.

@ self (xFCControl)
@ horizmove (number)
@ vertmove (number)
]]
function methods:MoveRelative(horizmove, vertmove)
    finext_helper.assert_argument_type(2, horizmove, "number")
    finext_helper.assert_argument_type(3, vertmove, "number")

    finext.xFCControl.SetLeft(self, finext.xFCControl.GetLeft(self) + horizmove)
    finext.xFCControl.SetTop(self, finext.xFCControl.GetTop(self) + vertmove)
end

--[[
% ResizeRelative

**[Fluid] [Override]**

Override Changes:
- Hooks into control state preservation.
- Polyfill for RGPLua < v0.63.
- Can be called when window is not showing.

@ self (xFCControl)
@ horizresize (number)
@ vertresize (number)
]]
function methods:ResizeRelative(horizresize, vertresize)
    finext_helper.assert_argument_type(2, horizresize, "number")
    finext_helper.assert_argument_type(3, vertresize, "number")

    finext.xFCControl.SetWidth(self, finext.xFCControl.GetWidth(self) + horizresize)
    finext.xFCControl.SetHeight(self, finext.xFCControl.GetHeight(self) + vertresize)
end

--[[
% __UseStoredControlState

**[Internal]**

Checks if this control should use its stored state instead of the live state from the control object.

*Do not override or disable this method.*

@ self (xFCControl)
: (boolean)
]]
function methods:__UseStoredControlState()
    local parent = self:GetParent()
    return finext_helper.is_instance_of(parent, "xFCCustomLuaWindow") and not parent:WindowExists() and parent:HasBeenShown()
end

--[[
% __StoreControlState

**[Fluid] [Internal]**

Stores the control's current state.

*Do not disable this method. Override as needed but call the parent first.*

@ self (xFCControl)
]]
function methods:__StoreControlState()
    self.__:GetText(temp_str.__)
    private[self].Text = temp_str.LuaString
    private[self].Enable = self.__:GetEnable()
    private[self].Visible = self.__:GetVisible()
    private[self].Left = self.__:GetLeft()
    private[self].Top = self.__:GetTop()
    private[self].Height = self.__:GetHeight()
    private[self].Width = self.__:GetWidth()
end

--[[
% __RestoreControlState

**[Fluid] [Internal]**

Restores the control's stored state.

*Do not disable this method. Override as needed but call the parent first.*

@ self (xFCControl)
]]
function methods:__RestoreControlState()
    self.__:SetEnable(private[self].Enable)
    self.__:SetVisible(private[self].Visible)
    self.__:SetLeft(private[self].Left)
    self.__:SetTop(private[self].Top)
    self.__:SetHeight(private[self].Height)
    self.__:SetWidth(private[self].Width)

    -- Call SetText last to work around the Mac text box issue described above with Enable and Visible
    temp_str.LuaString = private[self].Text
    self.__:SetText(temp_str.__)
end

--[[
% AddHandleCommand

**[Fluid]**

Adds a handler for command events.

@ self (xFCControl)
@ callback (function) See `FCCustomLuaWindow.HandleCommand` in the PDK for callback signature.
]]
methods.AddHandleCommand = handle_command.add

--[[
% RemoveHandleCommand

**[Fluid]**

Removes a handler added with `AddHandleCommand`.

@ self (xFCControl)
@ callback (function)
]]
methods.RemoveHandleCommand = handle_command.remove

return class
