--  Author: Edward Koltun
--  Date: April 2, 2022
--[[
$module xFCCtrlCheckbox

## Summary of Modifications
- Added `CheckChange` custom control event.
- Added hooks into control state preservation.
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

local class = {Methods = {}}
local methods = class.Methods
local private = setmetatable({}, {__mode = "k"})

local check_change = finext.xFCCustomLuaWindow.CreateCustomControlChangeEvent(
    -- initial could be set to -1 to force the event to fire on InitWindow, but unlike other controls, -1 is not a valid checkstate.
    -- If it becomes necessary to force this event to fire when the window is created, change to -1
    {
        name = "last_check",
        get = function(ctrl)
            return finext.xFCCtrlCheckbox.GetCheck(ctrl)
        end,
        initial = 0,
    }
)

local function normalize_check(self, checked)
    if checked < 1 then
        return 0
    end

    if checked > 1 and self:GetThreeStatesMode() and (finenv.UI():IsOnMac() or finenv.MajorVersion > 0 or finenv.MinorVersion > 67) then
        return 2
    end

    return 1
end

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
% __StoreControlState

**[Fluid] [Internal] [Override]**

Override Changes:
- Store `xFCCtrlCheckbox`-specific properties.

*Do not disable this method. Override as needed but call the parent first.*

@ self (xFCCtrlCheckbox)
]]
function methods:__StoreControlState()
    finext.xFCControl.__StoreControlState(self)

    private[self].Check = self.__:GetCheck()
end

--[[
% __RestoreControlState

**[Fluid] [Internal] [Override]**

Override Changes:
- Restore `xFCCtrlCheckbox`-specific properties.

*Do not disable this method. Override as needed but call the parent first.*

@ self (xFCCtrlCheckbox)
]]
function methods:__RestoreControlState()
    finext.xFCControl.__RestoreControlState(self)

    self.__:SetCheck(private[self].Check)
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

    if finext.xFCControl.__UseStoredControlState(self) then
        private[self].Check = normalize_check(self, checked)
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
    if finext.xFCControl.__UseStoredControlState(self) then
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
