--  Author: Edward Koltun
--  Date: April 2, 2022
--[[
$module xFCCtrlCheckbox

## Summary of Modifications
- Added `CheckChange` custom control event.
]] --
local finext = require("library.finext")
local utils = require("library.utils")

local class = {Methods = {}}
local methods = class.Methods

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
% SetCheck

**[Fluid] [Override]**

Override Changes:
- Ensures that `CheckChange` event is triggered.

@ self (xFCCtrlCheckbox)
@ checked (number)
]]
function methods:SetCheck(checked)
    utils.call_and_rethrow(2, self.__.SetCheck, self.__, checked)

    check_change.trigger(self)
end

--[[
% HandleCheckChange

**[Callback Template]**

@ control (xFCCtrlCheckbox) The control that was changed.
@ last_check (string) The previous value of the control's check state..
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
