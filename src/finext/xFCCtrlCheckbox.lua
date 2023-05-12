--  Author: Edward Koltun
--  Date: April 2, 2022
--[[
$module xFCCtrlCheckbox

## Summary of Modifications
- Added `CheckChange` custom control event.
- Added hooks into control state preservation.
]] --
local finext = require("library.finext")
local utils = require("library.utils")

local class = {Methods = {}}
local methods = class.Methods
local private = setmetatable({}, {__mode = "k"})

local check_change = finext.xFCCustomLuaWindow.CreateCustomControlChangeEvent(
    -- initial could be set to -1 to force the event to fire on InitWindow, but unlike other controls, -1 is not a valid checkstate.
    -- If it becomes necessary to force this event to fire when the window is created, change to -1
    {
        name = "last_check",
        get = "GetCheck",
        initial = 0,
    }
)

--[[
% Init

**[Internal]**

@ self (xFCCtrlCheckbox)
]]
function class:Init()
    if private[self] then
        return
    end

    private[self] = {}
end

--[[
% SetCheck

**[Fluid] [Override]**

Override Changes:
- Ensures that `CheckChange` event is triggered.
- Hooks into control state preservation.

@ self (xFCCtrlCheckbox)
@ checked (number)
]]
function methods:SetCheck(checked)
    finext_helper.assert_argument_type(2, checked, "number")

    if finext.xFCControl.UseStoredControlState(self) then
        private[self].Check = checked
    else
        self.__:SetCheck(checked)
    end

    check_change.trigger(self)
end

--[[
% GetCheck

Override Changes:
- Hooks into control state preservation.

@ self (xFCCtrlCheckbox)
]]
function methods:GetCheck()
    if finext.xFCControl.UseStoredControlState(self) then
        return private[self].Check
    end

    return self.__:GetCheck()
end

--[[
% HandleCheckChange

**[Callback Template]**

@ control (xFCCtrlCheckbox) The control that was changed.
@ last_check (number) The previous value of the control's check state..
]]

--[[
% AddHandleCheckChange

**[Fluid]**

Adds a handler for when the value of the control's check state changes.
The event will fire when:
- The window is created (if the check state is not `0`)
- The control is checked/unchecked by the user
- The control's check state is changed programmatically (if the check state is changed within a handler, that *same* handler will not be called again for that change.)

@ self (xFCCtrlCheckbox)
@ callback (function) See `HandleCheckChange` for callback signature.
]]
methods.AddHandleCheckChange = check_change.add

--[[
% RemoveHandleCheckChange

**[Fluid]**

Removes a handler added with `AddHandleCheckChange`.

@ self (xFCCtrlCheckbox)
@ callback (function)
]]
methods.RemoveHandleCheckChange = check_change.remove

return class
