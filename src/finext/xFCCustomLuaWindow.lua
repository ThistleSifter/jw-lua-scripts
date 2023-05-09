--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module xFCCustomLuaWindow

## Summary of Modifications
- Methods that returned a boolean to indicate success/failure now throw an error instead.
- Window is automatically registered with `finenv.RegisterModelessDialog` when `ShowModeless` is called.
- All `Register*` methods (apart from `RegisterHandleControlEvent`) have accompanying `Add*` and `Remove*` methods to enable multiple handlers to be added per event.
- Handlers for all window events (ie not control events) recieve the window object as the first argument.
- Control handlers are passed original object to preserve extension data.
- Added custom callback queue which can be used by custom events to add dispatchers that will run with the next control event.
- Added `HasBeenShown` method for checking if the window has been previously shown.
- All controls have their state stored upon closing and restored upon re-opening.
- Added methods for the automatic restoration of previous window position when showing (RGPLua > 0.60) for use with `finenv.RetainLuaState` and modeless windows.
- Added `DebugClose` option to assist with debugging (if ALT or SHIFT key is pressed when window is closed and debug mode is enabled, finenv.RetainLuaState will be set to false).
- Measurement unit can be set on the window or changed by the user through a `xFXCtrlMeasurementUnitPopup`.
- Windows also have the option of inheriting the parent window's measurement unit when opening.
- Introduced a `MeasurementUnitChange` event.
- All controls with an `UpdateMeasurementUnit` method will have that method called upon a measurement unit change to allow them to immediately update their displayed values without needing to wait for a `MeasurementUnitChange` event.
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")
local utils = require("library.utils")

local class = {Methods = {}, StaticMethods = {}}
local methods = class.Methods
local static = class.StaticMethods
local private = setmetatable({}, {__mode = "k"})

local trigger_measurement_unit_change
local each_last_measurement_unit_change


--[[
% CreateStandardControlEvent

**[Static]**

A helper function for creating a standard control event. Standard refers to the `Handle*` methods from `FCCustomLuaWindow` (not including `HandleControlEvent`).
For example usage, refer to the source for the `xFCControl` extension.

@ name (string) The full event name, case-sensitive (eg. `HandleCommand`, `HandleUpDownPressed`, etc)
: (function) A method for adding handlers.
: (function) A method for removing handlers.
]]
function static.CreateStandardControlEvent(name)
    local wrappers = {}

    local function add_method(control, callback)
        finext_helper.assert_argument_type(2, callback, "function")
        local window = control:GetParent()
        finext_helper.assert(window, "Cannot add handler to control with no parent window.")
        callbacks[control] = callbacks[control] or {}
        finext_helper.assert(not callbacks[control][callback], "Callback has already been registered on this control.")

        local function wrapper(ctrl, ...)
            if ctrl == control then
                callback(control, ...)
            end
        end
        window["Add" .. name](window, wrapper)
        wrappers[control][callback] = wrapper
    end

    local function remove_method(control, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        local wrapper = wrappers[control] and wrappers[control][callback]
        if wrapper then
            local window = control:GetParent()
            window["Remove" .. name](window, wrapper)
            wrappers[control][callback] = nil
        end
    end

    return add_method, remove_method
end


-- HandleTimer is omitted from this list because it is handled separately
local window_events = {"HandleCancelButtonPressed", "HandleOkButtonPressed", "InitWindow", "CloseWindow", "DarkModeIsChanging", "HandleActivate"}
local control_events = {"HandleCommand", "HandleDataListCheck", "HandleDataListSelect", "HandleUpDownPressed"}

local function flush_custom_queue(self)
    local queue = private[self].HandleCustomQueue
    private[self].HandleCustomQueue = {}

    for _, callback in ipairs(queue) do
        callback()
    end
end

local function restore_position(self)
    if private[self].HasBeenShown and private[self].EnableAutoRestorePosition and self.__.StorePosition then
        self:StorePosition(false)
        self.__:SetRestorePositionOnlyData(private[self].StoredX, private[self].StoredY)
        self:RestorePosition()
    end
end

-- A generic event dispatcher
local function dispatch_event_handlers(self, event, context, ...)
    local handlers = private[self][event]
    if handlers.Registered then
        handlers.Registered(context, ...)
    end

    for _, handler in ipairs(handlers.Added) do
        handler(context, ...)
    end
end

local function create_handle_methods(event)
    -- Check if methods are available
    if not finale.FCCustomLuaWindow.__class["Register" .. event] then
        return
    end

    methods["Register" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        private[self][event].Registered = callback
    end

    methods["Add" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        table.insert(private[self][event].Added, callback)
    end

    methods["Remove" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        utils.table_remove_first(private[self][event].Added, callback)
    end
end

--[[
% Init

**[Internal]**

@ self (xFCCustomLuaWindow)
]]
function class:Init()
    if private[self] then
        return
    end

    private[self] = {
        HandleTimer = {},
        HandleCustomQueue = {},
        HasBeenShown = false,
        EnableDebugClose = true,
        EnableAutoRestorePosition = 2, -- false = off, 1 = position only, 2 = position and size
        StoredX = nil,
        StoredY = nil,
        MeasurementUnit = finext.xFCUI.CalcDefaultMeasurementUnit(),
        UseParentMeasurementUnit = true,
    }

    -- Registers proxy functions up front to ensure that the handlers are passed the original object along with its extension data
    for _, event in ipairs(control_events) do
        if self.__["Register" .. event] then
            private[self][event] = {Added = {}}

            -- Handlers sometimes run twice, the second while the first is still running, so this flag prevents race conditions and concurrency issues.
            local is_running = false

            self.__["Register" .. event](self.__, function(control, ...)
                if is_running then
                    return
                end

                is_running = true

                -- Flush custom queue once
                flush_custom_queue(self)

                -- Execute handlers for main control
                local real_control = self:FindControl(control:GetControlID())

                if not real_control then
                    error("Control with ID #" .. tostring(control:GetControlID()) .. " not found in '" .. event .. "'")
                end

                dispatch_event_handlers(self, event, real_control, ...)

                -- Flush custom queue until empty
                while #private[self].HandleCustomQueue > 0 do
                    flush_custom_queue(self)
                end

                is_running = false
            end)
        end
    end

    -- Register proxies for window handlers
    for _, event in ipairs(window_events) do
        if not self.__["Register" .. event] then
            goto continue
        end

        private[self][event] = {Added = {}}

        if event == "InitWindow" then
           event.__["Register" .. event](self.__, function(...)
                if private[self].HasBeenShown then
                    for control in each(self) do
                        control:RestoreControlState()
                    end
                end

                dispatch_event_handlers(self, event, self, ...)
            end)
        elseif event == "CloseWindow" then
            self.__["Register" .. event](self.__, function(...)
                if private[self].EnableDebugClose and finenv.RetainLuaState ~= nil then
                    if finenv.DebugEnabled and (self:QueryLastCommandModifierKeys(finale.CMDMODKEY_ALT) or self:QueryLastCommandModifierKeys(finale.CMDMODKEY_SHIFT)) then
                        finenv.RetainLuaState = false
                    end
                end

                -- Catch any errors so they don't disrupt storing window position and control state
                local success, error_msg = pcall(dispatch_event_handlers, self, event, self, ...)

                if self.__.StorePosition then
                    self:StorePosition(false)
                    private[self].StoredX = self.StoredX
                    private[self].StoredY = self.StoredY
                end

                for control in each(self) do
                    control:StoreControlState()
                end

                private[self].HasBeenShown = true

                if not success then
                    error(error_msg, 0)
                end
            end)
        else
            self.__["Register" .. event](self.__, function(...)
                dispatch_event_handlers(self, event, self, ...)
            end)
        end

        :: continue ::
    end

    -- Register proxy for HandlerTimer if it's available in this RGPLua version.
    if self.__.RegisterHandleTimer then
        self.__:RegisterHandleTimer(function(timerid)
            -- Call registered handler if there is one
            if private[self].HandleTimer.Registered then
                -- Pass window as first parameter
                private[self].HandleTimer.Registered(self, timerid)
            end

            -- Call any added handlers for this timer
            if private[self].HandleTimer[timerid] then
                for _, callback in ipairs(private[self].HandleTimer[timerid]) do
                    -- Pass window as first parameter
                    callback(self, timerid)
                end
            end
        end)
    end
end

--[[
% RegisterHandleCommand

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleCommand` in the PDK for callback signature.
]]

--[[
% AddHandleCommand

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleCommand` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleCommand` in the PDK for callback signature.
]]

--[[
% RemoveHandleCommand

**[Fluid]**

Removes a handler added by `AddHandleCommand`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleDataListCheck

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListCheck` in the PDK for callback signature.
]]

--[[
% AddHandleDataListCheck

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleDataListCheck` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListCheck` in the PDK for callback signature.
]]

--[[
% RemoveHandleDataListCheck

**[Fluid]**

Removes a handler added by `AddHandleDataListCheck`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleDataListSelect

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListSelect` in the PDK for callback signature.
]]

--[[
% AddHandleDataListSelect

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleDataListSelect` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListSelect` in the PDK for callback signature.
]]

--[[
% RemoveHandleDataListSelect

**[Fluid]**

Removes a handler added by `AddHandleDataListSelect`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleUpDownPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleUpDownPressed` in the PDK for callback signature.
]]

--[[
% AddHandleUpDownPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleUpDownPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleUpDownPressed` in the PDK for callback signature.
]]

--[[
% RemoveHandleUpDownPressed

**[Fluid]**

Removes a handler added by `AddHandleUpDownPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
for _, event in ipairs(control_events) do
    create_handle_methods(event)
end

--[[
% CancelButtonPressed

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterHandleCancelButtonPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CancelButtonPressed` for callback signature.
]]

--[[
% AddHandleCancelButtonPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterCancelButtonPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CancelButtonPressed` for callback signature.
]]

--[[
% RemoveHandleCancelButtonPressed

**[Fluid]**

Removes a handler added by `AddHandleCancelButtonPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% OkButtonPressed

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterHandleOkButtonPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function)  See `OkButtonPressed` for callback signature.
]]

--[[
% AddHandleOkButtonPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterOkButtonPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `OkButtonPressed` for callback signature.
]]

--[[
% RemoveHandleOkButtonPressed

**[Fluid]**

Removes a handler added by `AddHandleOkButtonPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% InitWindow

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterInitWindow

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `InitWindow` for callback signature.
]]

--[[
% AddInitWindow

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterInitWindow` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `InitWindow` for callback signature.
]]

--[[
% RemoveInitWindow

**[Fluid]**

Removes a handler added by `AddInitWindow`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% CloseWindow

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterCloseWindow

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CloseWindow` for callback signature.
]]

--[[
% AddCloseWindow

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterCloseWindow` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CloseWindow` for callback signature.
]]

--[[
% RemoveCloseWindow

**[Fluid]**

Removes a handler added by `AddCloseWindow`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% DarkModeIsChanging

**[>= v0.64] [Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ isdarkmode (boolean)
]]

--[[
% RegisterDarkModeIsChanging

**[>= v0.64] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `DarkModeIsChanging` for callback signature.
]]

--[[
% AddDarkModeIsChanging

**[>= v0.64] [Fluid]**

Adds a handler. Similar to the equivalent `RegisterDarkModeIsChanging` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `DarkModeIsChanging` for callback signature.
]]

--[[
% RemoveDarkModeIsChanging

**[>= v0.64] [Fluid]**

Removes a handler added by `AddDarkModeIsChanging`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% HandleActivate

**[>= v0.66] [Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ activated (boolean)
]]

--[[
% RegisterHandleActivate

**[>= v0.66] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleActivate` for callback signature.
]]

--[[
% AddHandleActivate

**[>= v0.66] [Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleActivate` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleActivate` for callback signature.
]]

--[[
% RemoveHandleActivate

**[>= v0.66] [Fluid]**

Removes a handler added by `AddHandleActivate`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
for _, event in ipairs(window_events) do
    create_handle_methods(event)
end

--[[
% QueueHandleCustom

**[Fluid] [Internal]**
Adds a function to the queue which will be executed in the same context as an event handler at the next available opportunity.
Once called, the callback will be removed from tbe queue (i.e. it will only be called once). For multiple calls, the callback will need to be added to the queue again.
The callback will not be passed any arguments.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
function methods:QueueHandleCustom(callback)
    finext_helper.assert_argument_type(2, callback, "function")

    table.insert(private[self].HandleCustomQueue, callback)
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 56 then

--[[
% RegisterHandleControlEvent

**[>= v0.56] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ control (xFCControl)
@ callback (function) See `FCCustomLuaWindow.HandleControlEvent` in the PDK for callback signature.
]]
    methods.RegisterHandleControlEvent = finext_proxy.boolean_to_error(function(self, control, callback)
        return utils.call_and_rethrow(2, self.__.RegisterHandleControlEvent, self.__, control.__, function()
            callback(control)
        end)
    end)
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 56 then
--[[
% HandleTimer

**[Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ timerid (number)
]]

--[[
% RegisterHandleTimer

**[>= v0.56] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleTimer` for callback signature (note the change in arguments).
]]
    function methods:RegisterHandleTimer(callback)
        finext_helper.assert_argument_type(2, callback, "function")

        private[self].HandleTimer.Registered = callback
    end

--[[
% AddHandleTimer

**[>= v0.56] [Fluid]**

Adds a handler for a timer. Handlers added by this method will be called after the registered handler, if there is one.
If a handler is added for a timer that hasn't been set, the timer ID will no longer be available to `GetNextTimerID` and `SetNextTimer`.

@ self (xFCCustomLuaWindow)
@ timerid (number)
@ callback (function) See `HandleTimer` for callback signature.
]]
    function methods:AddHandleTimer(timerid, callback)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, callback, "function")

        private[self].HandleTimer[timerid] = private[self].HandleTimer[timerid] or {}

        table.insert(private[self].HandleTimer[timerid], callback)
    end

--[[
% RemoveHandleTimer

**[>= v0.56] [Fluid]**

Removes a handler added with `AddHandleTimer`.

@ self (xFCCustomLuaWindow)
@ timerid (number)
@ callback (function)
]]
    function methods:RemoveHandleTimer(timerid, callback)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, callback, "function")

        if not private[self].HandleTimer[timerid] then
            return
        end

        utils.table_remove_first(private[self].HandleTimer[timerid], callback)
    end

--[[
% SetTimer

**[>= v0.56] [Fluid] [Override]**

Override Changes:
- Add setup to allow multiple handlers to be added for a timer.

@ self (FCCustomLuaWindow)
@ timerid (number)
@ msinterval (number)
]]
    function methods:SetTimer(timerid, msinterval)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, msinterval, "number")

        self.__:SetTimer(timerid, msinterval)

        private[self].HandleTimer[timerid] = private[self].HandleTimer[timerid] or {}
    end

--[[
% GetNextTimerID

**[>= v0.56]**

Returns the next available timer ID.

@ self (xFCCustomLuaWindow)
: (number)
]]
    function methods:GetNextTimerID()
        while private[self].HandleTimer[private[self].NextTimerID] do
            private[self].NextTimerID = private[self].NextTimerID + 1
        end

        return private[self].NextTimerID
    end

--[[
% SetNextTimer

**[>= v0.56]**

Sets a timer using the next available ID (according to `GetNextTimerID`) and returns the ID.

@ self (xFCCustomLuaWindow)
@ msinterval (number)
: (number) The ID of the newly created timer.
]]
    function methods:SetNextTimer(msinterval)
        finext_helper.assert_argument_type(2, msinterval, "number")

        local timerid = finext.xFCCustomLuaWindow.GetNextTimerID(self)
        finext.xFCCustomLuaWindow.SetTimer(self, timerid, msinterval)

        return timerid
    end

    -- Note: StopTimer does not need to be overridden
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 60 then

--[[
% SetEnableAutoRestorePosition

**[>= v0.60] [Fluid]**

Enables/disables automatic restoration of the window's position on subsequent openings.
This is enabled by default.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
    function methods:SetEnableAutoRestorePosition(enabled)
        finext_helper.assert_argument_type(2, enabled, "boolean")

        private[self].EnableAutoRestorePosition = enabled and true or false
    end

--[[
% GetEnableAutoRestorePosition

**[>= v0.60]**

Returns whether automatic restoration of window position is enabled.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if enabled, `false` if disabled.
]]
    function methods:GetEnableAutoRestorePosition()
        return private[self].EnableAutoRestorePosition
    end

--[[
% SetRestorePositionData

**[>= v0.60] [Fluid] [Override]**

Override Changes:
- If this method is called while the window is closed, the new position data will be used in automatic position restoration when window is next shown.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ width (number)
@ height (number)
]]
    function methods:SetRestorePositionData(x, y, width, height)
        -- Let the original method take care of argument validation
        utils.call_and_rethrow(2, self.__.SetRestorePositionOnlyData, self.__, x, y, width, height)

        if private[self].HasBeenShown and not self:WindowExists() then
            private[self].StoredX = x
            private[self].StoredY = y
        end
    end

--[[
% SetRestorePositionOnlyData

**[>= v0.60] [Fluid] [Override]**

Override Changes:
- If this method is called while the window is closed, the new position data will be used in automatic position restoration when window is next shown.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
]]
    function methods:SetRestorePositionOnlyData(x, y)
        utils.call_and_rethrow(2, self.__.SetRestorePositionOnlyData, self.__, x, y)

        if private[self].HasBeenShown and not self:WindowExists() then
            private[self].StoredX = x
            private[self].StoredY = y
        end
    end
end

--[[
% SetEnableDebugClose

**[Fluid]**

If enabled and in debug mode, when the window is closed with either ALT or SHIFT key pressed, `finenv.RetainLuaState` will be set to `false`.
This is done before CloseWindow handlers are called.
This is enabled by default.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
function methods:SetEnableDebugClose(enabled)
    finext_helper.assert_argument_type(2, enabled, "boolean")

    private[self].EnableDebugClose = enabled and true or false
end

--[[
% GetEnableDebugClose

Returns the enabled state of the `DebugClose` option.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if enabled, `false` if disabled.
]]
function methods:GetEnableDebugClose()
    return private[self].EnableDebugClose
end

--[[
% HasBeenShown

Checks if the window has been shown at least once prior, either as a modal or modeless.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if it has been shown, `false` if not or if it is currently being shown for the first time.
]]
function methods:HasBeenShown()
    return private[self].HasBeenShown
end

--[[
% ExecuteModal

**[Override]**

Override Changes:
- If a parent window is passed and the `UseParentMeasurementUnit` setting is enabled, this window's measurement unit is automatically changed to match the parent window.
- Restores the previous position if `AutoRestorePosition` is enabled.

@ self (xFCCustomLuaWindow)
@ parent (FCCustomWindow | xFCCustomWindow | nil)
: (number)
]]
function methods:ExecuteModal(parent)
    if finext_helper.is_instance_of(parent, "xFCCustomLuaWindow") and private[self].UseParentMeasurementUnit then
        self:SetMeasurementUnit(parent:GetMeasurementUnit())
    end

    restore_position(self)
    return finext.xFCCustomWindow.ExecuteModal(self, parent)
end

--[[
% ShowModeless

**[Override]**

Override Changes:
- Automatically registers the dialog with `finenv.RegisterModelessDialog`.
- Restores the previous position if `AutoRestorePosition` is enabled.

@ self (xFCCustomLuaWindow)
: (boolean)
]]
function methods:ShowModeless()
    finenv.RegisterModelessDialog(self.__)
    restore_position(self)
    return self.__:ShowModeless()
end

--[[
% RunModeless

**[Fluid]**

Runs the window as a self-contained modeless plugin, performing the following steps:
- The first time the plugin is run, if ALT or SHIFT keys are pressed, sets `OkButtonCanClose` to true
- On subsequent runnings, if ALT or SHIFT keys are pressed the default action will be called without showing the window
- The default action defaults to the function registered with `RegisterHandleOkButtonPressed`
- If in JWLua, the window will be shown as a modal and it will check that a music region is currently selected

@ self (xFCCustomLuaWindow)
@ [selection_not_required] (boolean) If `true` and showing as a modal, will skip checking if a region is selected.
@ [default_action_override] (boolean | function) If `false`, there will be no default action. If a `function`, overrides the registered `OkButtonPressed` handler as the default action.
]]
function methods:RunModeless(selection_not_required, default_action_override)
    local modifier_keys_on_invoke = finenv.QueryInvokedModifierKeys and (finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_ALT) or finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_SHIFT))
    local default_action = default_action_override == nil and private[self].HandleOkButtonPressed.Registered or default_action_override

    if modifier_keys_on_invoke and self:HasBeenShown() and default_action then
        default_action(self)
        return
    end

    if finenv.IsRGPLua then
        -- OkButtonCanClose will be nil before RGPLua v0.56 and true (the default) after
        if self.OkButtonCanClose then
            self.OkButtonCanClose = modifier_keys_on_invoke
        end

        if self:ShowModeless() then
            finenv.RetainLuaState = true
        end
    else
        if not selection_not_required and finenv.Region():IsEmpty() then
            finenv.UI():AlertInfo("Please select a music region before running this script.", "Selection Required")
            return
        end

        self:ExecuteModal(nil)
    end
end

--[[
% GetMeasurementUnit

Returns the window's current measurement unit.

@ self (xFCCustomLuaWindow)
: (number) The value of one of the finale MEASUREMENTUNIT constants.
]]
function methods:GetMeasurementUnit()
    return private[self].MeasurementUnit
end

--[[
% SetMeasurementUnit

**[Fluid]**

Sets the window's current measurement unit. Millimeters are not supported.

All controls that have an `UpdateMeasurementUnit` method will have that method called to allow them to immediately update their displayed measurement unit immediately without needing to wait for a `MeasurementUnitChange` event.

@ self (xFCCustomLuaWindow)
@ measurementunit (number) One of the finale MEASUREMENTUNIT constants.
]]
function methods:SetMeasurementUnit(measurementunit)
    finext_helper.assert_argument_type(2, measurementunit, "number")

    if measurementunit == private[self].MeasurementUnit then
        return
    end

    if measurementunit == finale.MEASUREMENTUNIT_DEFAULT then
        measurementunit = finext.xFCUI.CalcDefaultMeasurementUnit()
    end

    finext_helper.force_assert(finext.xFCUI.IsDisplayMeasurementUnit(measurementunit), "Measurement unit is not valid.")

    private[self].MeasurementUnit = measurementunit

    -- Update all measurement controls
    for ctrl in each(self) do
        local func = ctrl.UpdateMeasurementUnit
        if func then
            func(ctrl)
        end
    end

    trigger_measurement_unit_change(self)
end

--[[
% GetUseParentMeasurementUnit

Returns a boolean indicating whether this window will use the measurement unit of its parent window when opened.

@ self (xFCCustomLuaWindow)
: (boolean)
]]
function methods:GetUseParentMeasurementUnit(enabled)
    return private[self].UseParentMeasurementUnit
end

--[[
% SetUseParentMeasurementUnit

**[Fluid]**

Sets whether to use the parent window's measurement unit when opening this window. Default is enabled.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
function methods:SetUseParentMeasurementUnit(enabled)
    finext_helper.assert_argument_type(2, enabled, "boolean")

    private[self].UseParentMeasurementUnit = enabled and true or false
end

--[[
% HandleMeasurementUnitChange

**[Callback Template]**

Template for MeasurementUnitChange handlers.

@ self (xFCCustomLuaWindow)
@ last_unit (number) The window's previous measurement unit.
]]

--[[
% AddHandleMeasurementUnitChange

**[Fluid]**

Adds a handler for a change in the window's measurement unit.
The even will fire when:
- The window is created (if the measurement unit is not `finale.MEASUREMENTUNIT_DEFAULT`)
- The measurement unit is changed by the user via a `xFXCtrlMeasurementUnitPopup`
- The measurement unit is changed programmatically (if the measurement unit is changed within a handler, that *same* handler will not be called again for that change.)

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleMeasurementUnitChange` for callback signature.
]]

--[[
% RemoveHandleMeasurementUnitChange

**[Fluid]**

Removes a handler added with `AddHandleMeasurementUnitChange`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
methods.AddHandleMeasurementUnitChange, methods.RemoveHandleMeasurementUnitChange, trigger_measurement_unit_change, each_last_measurement_unit_change = finext.xFCCustomLuaWindow.CreateCustomWindowChangeEvent(
    {
        name = "last_unit",
        get = function(window)
            return finext.xFCCustomLuaWindow.GetMeasurementUnit(window)
        end,
        initial = finext.xFCUI.CalcDefaultMeasurementUnit(),
    }
)

--[[
% CreateMeasurementEdit

Creates an `xFXCtrlMeasurementEdit` control.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ [control_name] (string)
: (xFXCtrlMeasurementEdit)
]]
function methods:CreateMeasurementEdit(x, y, control_name)
    finext_helper.assert_argument_type(2, x, "number")
    finext_helper.assert_argument_type(3, y, "number")
    finext_helper.assert_argument_type(4, control_name, "string", "nil")

    local edit = finext.xFCCustomWindow.CreateEdit(self, x, y, control_name)
    return finext(edit, "xFXCtrlMeasurementEdit")
end

--[[
% CreateMeasurementUnitPopup

Creates a popup which allows the user to change the window's measurement unit.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ [control_name] (string)
: (xFXCtrlMeasurementUnitPopup)
]]
function methods:CreateMeasurementUnitPopup(x, y, control_name)
    finext_helper.assert_argument_type(2, x, "number")
    finext_helper.assert_argument_type(3, y, "number")
    finext_helper.assert_argument_type(4, control_name, "string", "nil")

    local popup = finext.xFCCustomWindow.CreatePopup(self, x, y, control_name)
    return finext(popup, "xFXCtrlMeasurementUnitPopup")
end

return class


local trigger_measurement_unit_change
local each_last_measurement_unit_change

-- HandleTimer is omitted from this list because it is handled separately
local window_events = {"HandleCancelButtonPressed", "HandleOkButtonPressed", "InitWindow", "CloseWindow", "DarkModeIsChanging", "HandleActivate"}
local control_events = {"HandleCommand", "HandleDataListCheck", "HandleDataListSelect", "HandleUpDownPressed"}

local function flush_custom_queue(self)
    local queue = private[self].HandleCustomQueue
    private[self].HandleCustomQueue = {}

    for _, callback in ipairs(queue) do
        callback()
    end
end

local function restore_position(self)
    if private[self].HasBeenShown and private[self].EnableAutoRestorePosition and self.__.StorePosition then
        self:StorePosition(false)
        self.__:SetRestorePositionOnlyData(private[self].StoredX, private[self].StoredY)
        self:RestorePosition()
    end
end

-- A generic event dispatcher
local function dispatch_event_handlers(self, event, context, ...)
    local handlers = private[self][event]
    if handlers.Registered then
        handlers.Registered(context, ...)
    end

    for _, handler in ipairs(handlers.Added) do
        handler(context, ...)
    end
end

local function create_handle_methods(event)
    -- Check if methods are available
    if not finale.FCCustomLuaWindow.__class["Register" .. event] then
        return
    end

    methods["Register" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        private[self][event].Registered = callback
    end

    methods["Add" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        table.insert(private[self][event].Added, callback)
    end

    methods["Remove" .. event] = function(self, callback)
        finext_helper.assert_argument_type(2, callback, "function")

        utils.table_remove_first(private[self][event].Added, callback)
    end
end

--[[
% Init

**[Internal]**

@ self (xFCCustomLuaWindow)
]]
function class:Init()
    if private[self] then
        return
    end

    private[self] = {
        HandleTimer = {},
        HandleCustomQueue = {},
        HasBeenShown = false,
        EnableDebugClose = true,
        EnableAutoRestorePosition = 2, -- false = off, 1 = position only, 2 = position and size
        StoredX = nil,
        StoredY = nil,
        MeasurementUnit = finext.xFCUI.CalcDefaultMeasurementUnit(),
        UseParentMeasurementUnit = true,
    }

    -- Registers proxy functions up front to ensure that the handlers are passed the original object along with its extension data
    for _, event in ipairs(control_events) do
        if self.__["Register" .. event] then
            private[self][event] = {Added = {}}

            -- Handlers sometimes run twice, the second while the first is still running, so this flag prevents race conditions and concurrency issues.
            local is_running = false

            self.__["Register" .. event](self.__, function(control, ...)
                if is_running then
                    return
                end

                is_running = true

                -- Flush custom queue once
                flush_custom_queue(self)

                -- Execute handlers for main control
                local real_control = self:FindControl(control:GetControlID())

                if not real_control then
                    error("Control with ID #" .. tostring(control:GetControlID()) .. " not found in '" .. event .. "'")
                end

                dispatch_event_handlers(self, event, real_control, ...)

                -- Flush custom queue until empty
                while #private[self].HandleCustomQueue > 0 do
                    flush_custom_queue(self)
                end

                is_running = false
            end)
        end
    end

    -- Register proxies for window handlers
    for _, event in ipairs(window_events) do
        if not self.__["Register" .. event] then
            goto continue
        end

        private[self][event] = {Added = {}}

        if event == "InitWindow" then
           event.__["Register" .. event](self.__, function(...)
                if private[self].HasBeenShown then
                    for control in each(self) do
                        control:RestoreControlState()
                    end
                end

                dispatch_event_handlers(self, event, self, ...)
            end)
        elseif event == "CloseWindow" then
            self.__["Register" .. event](self.__, function(...)
                if private[self].EnableDebugClose and finenv.RetainLuaState ~= nil then
                    if finenv.DebugEnabled and (self:QueryLastCommandModifierKeys(finale.CMDMODKEY_ALT) or self:QueryLastCommandModifierKeys(finale.CMDMODKEY_SHIFT)) then
                        finenv.RetainLuaState = false
                    end
                end

                -- Catch any errors so they don't disrupt storing window position and control state
                local success, error_msg = pcall(dispatch_event_handlers, self, event, self, ...)

                if self.__.StorePosition then
                    self:StorePosition(false)
                    private[self].StoredX = self.StoredX
                    private[self].StoredY = self.StoredY
                end

                for control in each(self) do
                    control:StoreControlState()
                end

                private[self].HasBeenShown = true

                if not success then
                    error(error_msg, 0)
                end
            end)
        else
            self.__["Register" .. event](self.__, function(...)
                dispatch_event_handlers(self, event, self, ...)
            end)
        end

        :: continue ::
    end

    -- Register proxy for HandlerTimer if it's available in this RGPLua version.
    if self.__.RegisterHandleTimer then
        self.__:RegisterHandleTimer(function(timerid)
            -- Call registered handler if there is one
            if private[self].HandleTimer.Registered then
                -- Pass window as first parameter
                private[self].HandleTimer.Registered(self, timerid)
            end

            -- Call any added handlers for this timer
            if private[self].HandleTimer[timerid] then
                for _, callback in ipairs(private[self].HandleTimer[timerid]) do
                    -- Pass window as first parameter
                    callback(self, timerid)
                end
            end
        end)
    end
end

--[[
% RegisterHandleCommand

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleCommand` in the PDK for callback signature.
]]

--[[
% AddHandleCommand

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleCommand` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleCommand` in the PDK for callback signature.
]]

--[[
% RemoveHandleCommand

**[Fluid]**

Removes a handler added by `AddHandleCommand`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleDataListCheck

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListCheck` in the PDK for callback signature.
]]

--[[
% AddHandleDataListCheck

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleDataListCheck` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListCheck` in the PDK for callback signature.
]]

--[[
% RemoveHandleDataListCheck

**[Fluid]**

Removes a handler added by `AddHandleDataListCheck`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleDataListSelect

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListSelect` in the PDK for callback signature.
]]

--[[
% AddHandleDataListSelect

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleDataListSelect` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleDataListSelect` in the PDK for callback signature.
]]

--[[
% RemoveHandleDataListSelect

**[Fluid]**

Removes a handler added by `AddHandleDataListSelect`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% RegisterHandleUpDownPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleUpDownPressed` in the PDK for callback signature.
]]

--[[
% AddHandleUpDownPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleUpDownPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `FCCustomLuaWindow.HandleUpDownPressed` in the PDK for callback signature.
]]

--[[
% RemoveHandleUpDownPressed

**[Fluid]**

Removes a handler added by `AddHandleUpDownPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
for _, event in ipairs(control_events) do
    create_handle_methods(event)
end

--[[
% CancelButtonPressed

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterHandleCancelButtonPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CancelButtonPressed` for callback signature.
]]

--[[
% AddHandleCancelButtonPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterCancelButtonPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CancelButtonPressed` for callback signature.
]]

--[[
% RemoveHandleCancelButtonPressed

**[Fluid]**

Removes a handler added by `AddHandleCancelButtonPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% OkButtonPressed

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterHandleOkButtonPressed

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function)  See `OkButtonPressed` for callback signature.
]]

--[[
% AddHandleOkButtonPressed

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterOkButtonPressed` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `OkButtonPressed` for callback signature.
]]

--[[
% RemoveHandleOkButtonPressed

**[Fluid]**

Removes a handler added by `AddHandleOkButtonPressed`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% InitWindow

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterInitWindow

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `InitWindow` for callback signature.
]]

--[[
% AddInitWindow

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterInitWindow` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `InitWindow` for callback signature.
]]

--[[
% RemoveInitWindow

**[Fluid]**

Removes a handler added by `AddInitWindow`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% CloseWindow

**[Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
]]

--[[
% RegisterCloseWindow

**[Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CloseWindow` for callback signature.
]]

--[[
% AddCloseWindow

**[Fluid]**

Adds a handler. Similar to the equivalent `RegisterCloseWindow` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `CloseWindow` for callback signature.
]]

--[[
% RemoveCloseWindow

**[Fluid]**

Removes a handler added by `AddCloseWindow`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% DarkModeIsChanging

**[>= v0.64] [Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ isdarkmode (boolean)
]]

--[[
% RegisterDarkModeIsChanging

**[>= v0.64] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `DarkModeIsChanging` for callback signature.
]]

--[[
% AddDarkModeIsChanging

**[>= v0.64] [Fluid]**

Adds a handler. Similar to the equivalent `RegisterDarkModeIsChanging` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `DarkModeIsChanging` for callback signature.
]]

--[[
% RemoveDarkModeIsChanging

**[>= v0.64] [Fluid]**

Removes a handler added by `AddDarkModeIsChanging`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]

--[[
% HandleActivate

**[>= v0.66] [Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ activated (boolean)
]]

--[[
% RegisterHandleActivate

**[>= v0.66] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleActivate` for callback signature.
]]

--[[
% AddHandleActivate

**[>= v0.66] [Fluid]**

Adds a handler. Similar to the equivalent `RegisterHandleActivate` except there is no limit to the number of handlers that can be added.
Added handlers are called in the order they are added after the registered handler, if there is one.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleActivate` for callback signature.
]]

--[[
% RemoveHandleActivate

**[>= v0.66] [Fluid]**

Removes a handler added by `AddHandleActivate`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
for _, event in ipairs(window_events) do
    create_handle_methods(event)
end

--[[
% QueueHandleCustom

**[Fluid] [Internal]**
Adds a function to the queue which will be executed in the same context as an event handler at the next available opportunity.
Once called, the callback will be removed from tbe queue (i.e. it will only be called once). For multiple calls, the callback will need to be added to the queue again.
The callback will not be passed any arguments.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
function methods:QueueHandleCustom(callback)
    finext_helper.assert_argument_type(2, callback, "function")

    table.insert(private[self].HandleCustomQueue, callback)
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 56 then

--[[
% RegisterHandleControlEvent

**[>= v0.56] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Ensures that the handler is passed the original control object.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ control (xFCControl)
@ callback (function) See `FCCustomLuaWindow.HandleControlEvent` in the PDK for callback signature.
]]
    methods.RegisterHandleControlEvent = finext_proxy.boolean_to_error(function(self, control, callback)
        return utils.call_and_rethrow(2, self.__.RegisterHandleControlEvent, self.__, control.__, function()
            callback(control)
        end)
    end)
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 56 then
--[[
% HandleTimer

**[Breaking Change] [Callback Template] [Override]**

Override Changes:
- Receives the window object as the first parameter.

@ self (xFCCustomLuaWindow)
@ timerid (number)
]]

--[[
% RegisterHandleTimer

**[>= v0.56] [Breaking Change] [Fluid] [Override]**

Override Changes:
- Uses overridden callback signature.
- Throws an error instead of returning a boolean for success/failure.

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleTimer` for callback signature (note the change in arguments).
]]
    function methods:RegisterHandleTimer(callback)
        finext_helper.assert_argument_type(2, callback, "function")

        private[self].HandleTimer.Registered = callback
    end

--[[
% AddHandleTimer

**[>= v0.56] [Fluid]**

Adds a handler for a timer. Handlers added by this method will be called after the registered handler, if there is one.
If a handler is added for a timer that hasn't been set, the timer ID will no longer be available to `GetNextTimerID` and `SetNextTimer`.

@ self (xFCCustomLuaWindow)
@ timerid (number)
@ callback (function) See `HandleTimer` for callback signature.
]]
    function methods:AddHandleTimer(timerid, callback)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, callback, "function")

        private[self].HandleTimer[timerid] = private[self].HandleTimer[timerid] or {}

        table.insert(private[self].HandleTimer[timerid], callback)
    end

--[[
% RemoveHandleTimer

**[>= v0.56] [Fluid]**

Removes a handler added with `AddHandleTimer`.

@ self (xFCCustomLuaWindow)
@ timerid (number)
@ callback (function)
]]
    function methods:RemoveHandleTimer(timerid, callback)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, callback, "function")

        if not private[self].HandleTimer[timerid] then
            return
        end

        utils.table_remove_first(private[self].HandleTimer[timerid], callback)
    end

--[[
% SetTimer

**[>= v0.56] [Fluid] [Override]**

Override Changes:
- Add setup to allow multiple handlers to be added for a timer.

@ self (FCCustomLuaWindow)
@ timerid (number)
@ msinterval (number)
]]
    function methods:SetTimer(timerid, msinterval)
        finext_helper.assert_argument_type(2, timerid, "number")
        finext_helper.assert_argument_type(3, msinterval, "number")

        self.__:SetTimer(timerid, msinterval)

        private[self].HandleTimer[timerid] = private[self].HandleTimer[timerid] or {}
    end

--[[
% GetNextTimerID

**[>= v0.56]**

Returns the next available timer ID.

@ self (xFCCustomLuaWindow)
: (number)
]]
    function methods:GetNextTimerID()
        while private[self].HandleTimer[private[self].NextTimerID] do
            private[self].NextTimerID = private[self].NextTimerID + 1
        end

        return private[self].NextTimerID
    end

--[[
% SetNextTimer

**[>= v0.56]**

Sets a timer using the next available ID (according to `GetNextTimerID`) and returns the ID.

@ self (xFCCustomLuaWindow)
@ msinterval (number)
: (number) The ID of the newly created timer.
]]
    function methods:SetNextTimer(msinterval)
        finext_helper.assert_argument_type(2, msinterval, "number")

        local timerid = finext.xFCCustomLuaWindow.GetNextTimerID(self)
        finext.xFCCustomLuaWindow.SetTimer(self, timerid, msinterval)

        return timerid
    end

    -- Note: StopTimer does not need to be overridden
end

if finenv.MajorVersion > 0 or finenv.MinorVersion >= 60 then

--[[
% SetEnableAutoRestorePosition

**[>= v0.60] [Fluid]**

Enables/disables automatic restoration of the window's position on subsequent openings.
This is enabled by default.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
    function methods:SetEnableAutoRestorePosition(enabled)
        finext_helper.assert_argument_type(2, enabled, "boolean")

        private[self].EnableAutoRestorePosition = enabled and true or false
    end

--[[
% GetEnableAutoRestorePosition

**[>= v0.60]**

Returns whether automatic restoration of window position is enabled.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if enabled, `false` if disabled.
]]
    function methods:GetEnableAutoRestorePosition()
        return private[self].EnableAutoRestorePosition
    end

--[[
% SetRestorePositionData

**[>= v0.60] [Fluid] [Override]**

Override Changes:
- If this method is called while the window is closed, the new position data will be used in automatic position restoration when window is next shown.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ width (number)
@ height (number)
]]
    function methods:SetRestorePositionData(x, y, width, height)
        -- Let the original method take care of argument validation
        utils.call_and_rethrow(2, self.__.SetRestorePositionOnlyData, self.__, x, y, width, height)

        if private[self].HasBeenShown and not self:WindowExists() then
            private[self].StoredX = x
            private[self].StoredY = y
        end
    end

--[[
% SetRestorePositionOnlyData

**[>= v0.60] [Fluid] [Override]**

Override Changes:
- If this method is called while the window is closed, the new position data will be used in automatic position restoration when window is next shown.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
]]
    function methods:SetRestorePositionOnlyData(x, y)
        utils.call_and_rethrow(2, self.__.SetRestorePositionOnlyData, self.__, x, y)

        if private[self].HasBeenShown and not self:WindowExists() then
            private[self].StoredX = x
            private[self].StoredY = y
        end
    end
end

--[[
% SetEnableDebugClose

**[Fluid]**

If enabled and in debug mode, when the window is closed with either ALT or SHIFT key pressed, `finenv.RetainLuaState` will be set to `false`.
This is done before CloseWindow handlers are called.
This is enabled by default.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
function methods:SetEnableDebugClose(enabled)
    finext_helper.assert_argument_type(2, enabled, "boolean")

    private[self].EnableDebugClose = enabled and true or false
end

--[[
% GetEnableDebugClose

Returns the enabled state of the `DebugClose` option.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if enabled, `false` if disabled.
]]
function methods:GetEnableDebugClose()
    return private[self].EnableDebugClose
end

--[[
% HasBeenShown

Checks if the window has been shown at least once prior, either as a modal or modeless.

@ self (xFCCustomLuaWindow)
: (boolean) `true` if it has been shown, `false` if not or if it is currently being shown for the first time.
]]
function methods:HasBeenShown()
    return private[self].HasBeenShown
end

--[[
% ExecuteModal

**[Override]**

Override Changes:
- If a parent window is passed and the `UseParentMeasurementUnit` setting is enabled, this window's measurement unit is automatically changed to match the parent window.
- Restores the previous position if `AutoRestorePosition` is enabled.

@ self (xFCCustomLuaWindow)
@ parent (FCCustomWindow | xFCCustomWindow | nil)
: (number)
]]
function methods:ExecuteModal(parent)
    if finext_helper.is_instance_of(parent, "xFCCustomLuaWindow") and private[self].UseParentMeasurementUnit then
        self:SetMeasurementUnit(parent:GetMeasurementUnit())
    end

    restore_position(self)
    return finext.xFCCustomWindow.ExecuteModal(self, parent)
end

--[[
% ShowModeless

**[Override]**

Override Changes:
- Automatically registers the dialog with `finenv.RegisterModelessDialog`.
- Restores the previous position if `AutoRestorePosition` is enabled.

@ self (xFCCustomLuaWindow)
: (boolean)
]]
function methods:ShowModeless()
    finenv.RegisterModelessDialog(self.__)
    restore_position(self)
    return self.__:ShowModeless()
end

--[[
% RunModeless

**[Fluid]**

Runs the window as a self-contained modeless plugin, performing the following steps:
- The first time the plugin is run, if ALT or SHIFT keys are pressed, sets `OkButtonCanClose` to true
- On subsequent runnings, if ALT or SHIFT keys are pressed the default action will be called without showing the window
- The default action defaults to the function registered with `RegisterHandleOkButtonPressed`
- If in JWLua, the window will be shown as a modal and it will check that a music region is currently selected

@ self (xFCCustomLuaWindow)
@ [selection_not_required] (boolean) If `true` and showing as a modal, will skip checking if a region is selected.
@ [default_action_override] (boolean | function) If `false`, there will be no default action. If a `function`, overrides the registered `OkButtonPressed` handler as the default action.
]]
function methods:RunModeless(selection_not_required, default_action_override)
    local modifier_keys_on_invoke = finenv.QueryInvokedModifierKeys and (finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_ALT) or finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_SHIFT))
    local default_action = default_action_override == nil and private[self].HandleOkButtonPressed.Registered or default_action_override

    if modifier_keys_on_invoke and self:HasBeenShown() and default_action then
        default_action(self)
        return
    end

    if finenv.IsRGPLua then
        -- OkButtonCanClose will be nil before RGPLua v0.56 and true (the default) after
        if self.OkButtonCanClose then
            self.OkButtonCanClose = modifier_keys_on_invoke
        end

        if self:ShowModeless() then
            finenv.RetainLuaState = true
        end
    else
        if not selection_not_required and finenv.Region():IsEmpty() then
            finenv.UI():AlertInfo("Please select a music region before running this script.", "Selection Required")
            return
        end

        self:ExecuteModal(nil)
    end
end

--[[
% GetMeasurementUnit

Returns the window's current measurement unit.

@ self (xFCCustomLuaWindow)
: (number) The value of one of the finale MEASUREMENTUNIT constants.
]]
function methods:GetMeasurementUnit()
    return private[self].MeasurementUnit
end

--[[
% SetMeasurementUnit

**[Fluid]**

Sets the window's current measurement unit. Millimeters are not supported.

All controls that have an `UpdateMeasurementUnit` method will have that method called to allow them to immediately update their displayed measurement unit immediately without needing to wait for a `MeasurementUnitChange` event.

@ self (xFCCustomLuaWindow)
@ measurementunit (number) One of the finale MEASUREMENTUNIT constants.
]]
function methods:SetMeasurementUnit(measurementunit)
    finext_helper.assert_argument_type(2, measurementunit, "number")

    if measurementunit == private[self].MeasurementUnit then
        return
    end

    if measurementunit == finale.MEASUREMENTUNIT_DEFAULT then
        measurementunit = finext.xFCUI.CalcDefaultMeasurementUnit()
    end

    finext_helper.force_assert(finext.xFCUI.IsDisplayMeasurementUnit(measurementunit), "Measurement unit is not valid.")

    private[self].MeasurementUnit = measurementunit

    -- Update all measurement controls
    for ctrl in each(self) do
        local func = ctrl.UpdateMeasurementUnit
        if func then
            func(ctrl)
        end
    end

    trigger_measurement_unit_change(self)
end

--[[
% GetUseParentMeasurementUnit

Returns a boolean indicating whether this window will use the measurement unit of its parent window when opened.

@ self (xFCCustomLuaWindow)
: (boolean)
]]
function methods:GetUseParentMeasurementUnit(enabled)
    return private[self].UseParentMeasurementUnit
end

--[[
% SetUseParentMeasurementUnit

**[Fluid]**

Sets whether to use the parent window's measurement unit when opening this window. Default is enabled.

@ self (xFCCustomLuaWindow)
@ enabled (boolean)
]]
function methods:SetUseParentMeasurementUnit(enabled)
    finext_helper.assert_argument_type(2, enabled, "boolean")

    private[self].UseParentMeasurementUnit = enabled and true or false
end

--[[
% HandleMeasurementUnitChange

**[Callback Template]**

Template for MeasurementUnitChange handlers.

@ self (xFCCustomLuaWindow)
@ last_unit (number) The window's previous measurement unit.
]]

--[[
% AddHandleMeasurementUnitChange

**[Fluid]**

Adds a handler for a change in the window's measurement unit.
The even will fire when:
- The window is created (if the measurement unit is not `finale.MEASUREMENTUNIT_DEFAULT`)
- The measurement unit is changed by the user via a `xFXCtrlMeasurementUnitPopup`
- The measurement unit is changed programmatically (if the measurement unit is changed within a handler, that *same* handler will not be called again for that change.)

@ self (xFCCustomLuaWindow)
@ callback (function) See `HandleMeasurementUnitChange` for callback signature.
]]

--[[
% RemoveHandleMeasurementUnitChange

**[Fluid]**

Removes a handler added with `AddHandleMeasurementUnitChange`.

@ self (xFCCustomLuaWindow)
@ callback (function)
]]
methods.AddHandleMeasurementUnitChange, methods.RemoveHandleMeasurementUnitChange, trigger_measurement_unit_change, each_last_measurement_unit_change = finext.xFCCustomLuaWindow.CreateCustomWindowChangeEvent(
    {
        name = "last_unit",
        get = function(window)
            return finext.xFCCustomLuaWindow.GetMeasurementUnit(window)
        end,
        initial = finext.xFCUI.CalcDefaultMeasurementUnit(),
    }
)

--[[
% CreateMeasurementEdit

Creates an `xFXCtrlMeasurementEdit` control.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ [control_name] (string)
: (xFXCtrlMeasurementEdit)
]]
function methods:CreateMeasurementEdit(x, y, control_name)
    finext_helper.assert_argument_type(2, x, "number")
    finext_helper.assert_argument_type(3, y, "number")
    finext_helper.assert_argument_type(4, control_name, "string", "nil")

    local edit = finext.xFCCustomWindow.CreateEdit(self, x, y, control_name)
    return finext(edit, "xFXCtrlMeasurementEdit")
end

--[[
% CreateMeasurementUnitPopup

Creates a popup which allows the user to change the window's measurement unit.

@ self (xFCCustomLuaWindow)
@ x (number)
@ y (number)
@ [control_name] (string)
: (xFXCtrlMeasurementUnitPopup)
]]
function methods:CreateMeasurementUnitPopup(x, y, control_name)
    finext_helper.assert_argument_type(2, x, "number")
    finext_helper.assert_argument_type(3, y, "number")
    finext_helper.assert_argument_type(4, control_name, "string", "nil")

    local popup = finext.xFCCustomWindow.CreatePopup(self, x, y, control_name)
    return finext(popup, "xFXCtrlMeasurementUnitPopup")
end

return class
