--  Author: Edward Koltun
--  Date: March 3, 2022
--[[
$module xFCCustomWindow

## Summary of Modifications
- `Create*` methods have an additional optional parameter for specifying a control name. Named controls can be retrieved via `GetControl`.
- Cache original control objects to preserve extension data and override control getters to return the original objects.
- Setters that accept `xFCString` will also accept a Lua `string`.
- `xFCString` parameter in getters is optional and if omitted, the result will be returned as a Lua `string`.
]] --
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")
local finext_proxy = require("library.finext_proxy")

local class = {Methods = {}}
local methods = class.Methods
local private = setmetatable({}, {__mode = "k"})

local temp_str = finext.xFCString()

local function set_control_name(self, control, control_name, error_level)
    control_name = tostring(control_name)

    if private[self].NamedControls[control_name] then
        error("A control is already registered with the name '" .. control_name .. "'", error_level + 1)
    end

    private[self].NamedControls[control_name] = control
end

local function create_control(self, func, num_args, ...)
    local control = finext.__(self, "Create" .. func, ...)
    private[self].Controls[control:GetControlID()] = control
    control:RegisterParent(self)

    local control_name = select(num_args + 1, ...)
    if control_name then
        set_control_name(self, control, control_name, 2)
    end

    return control
end

--[[
% Init

**[Internal]**

@ self (xFCCustomWindow)
]]
function class:Init()
    if private[self] then
        return
    end

    private[self] = {
        Controls = {},
        NamedControls = {},
    }
end

--[[
% CreateCancelButton

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlButton)
]]

--[[
% CreateOkButton

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlButton)
]]

--[[
% CreateButton

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlButton)
]]

--[[
% CreateCheckbox

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlCheckbox)
]]

--[[
% CreateCloseButton

**[>= v0.56] [Override]**

Override Changes:
- Added optional `control_name` parameter.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlButton)
]]

--[[
% CreateDataList

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlDataList)
]]

--[[
% CreateEdit

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlEdit)
]]

--[[
% CreateListBox

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlListBox)
]]

--[[
% CreatePopup

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlPopup)
]]

--[[
% CreateSlider

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlSlider)
]]

--[[
% CreateStatic

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlStatic)
]]

--[[
% CreateSwitcher

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlSwitcher)
]]

--[[
% CreateTree

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlTree)
]]

--[[
% CreateUpDown

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlUpDown)
]]

--[[
% CreateHorizontalLine

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ length (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlLine)
]]

--[[
% CreateVerticalLine

**[Override]**

Override Changes:
- Added optional `control_name` parameter.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ length (number)
@ [control_name] (xFCString | string) Optional name to allow access from `GetControl` method.
: (xFCCtrlLine)
]]

-- Override Create* methods to store a reference to the original created object and its control ID
-- Also adds an optional parameter at the end for a control name
for num_args, ctrl_types in pairs({
    [0] = {"CancelButton", "OkButton",},
    [2] = {"Button", "Checkbox", "CloseButton", "DataList", "Edit",
        "ListBox", "Popup", "Slider", "Static", "Switcher", "Tree", "UpDown",
    },
    [3] = {"HorizontalLine", "VerticalLine",},
}) do
    for _, control_type in pairs(ctrl_types) do
        if not finale.FCCustomWindow.__class["Create" .. control_type] then
            goto continue
        end

        methods["Create" .. control_type] = function(self, ...)
            for i = 1, num_args do
                finext_helper.assert_argument_type(i + 1, select(i, ...), "number")
            end
            finext_helper.assert_argument_type(num_args + 2, select(num_args + 1, ...), "string", "nil", "xFCString")

            return create_control(self, control_type, num_args, ...)
        end

        :: continue ::
    end
end

--[[
% CreateRadioButtonGroup

**[Override]**

Override Changes:
- Added optional parameters for control name.
- Store reference to original control object.

@ self (xFCCustomWindow)
@ x (number)
@ y (number)
@ no_of_items (integer)
@ [control_name] (string | xFCString)
@ [...] (string | xFCString | nil) Control names for the radio buttons in the group.
: (xFCCtrlRadioButtonGroup)
]]
function method:CreateRadioButtonGroup(x, y, no_of_items, control_name, ...)
    finext_helper.assert_argument_type(2, x, "number")
    finext_helper.assert_argument_type(3, y, "number")
    finext_helper.assert_argument_type(4, no_of_items, "integer")

    -- TODO: find out if group counts as control and if control_name is needed
    local group = finext.__(self, "CreateRadioButtonGroup", x, y, no_of_items)
    local count = 0
    for control in each(group.__) do
        count = count + 1
        control = finext(control)
        control:RegisterParent(self)
        control:RegisterRadioButtonGroup(group)
        private[self].Controls[ctrl:GetControlID()] = ctrl
        local control_name = select(count, ...)
        if control_name then
            set_control_name(self, control, control_name, 2)
        end
    end
    group:RegisterParent(self)
    return group
end

--[[
% MoveAllControls

Override Changes:
- Hooks into control state preservation.

@ self (xFCCustomWindow)
@ horizoffset (number)
@ vertoffset (number)
]]
function methods:MoveAllControls(horizoffset, vertoffset)
    finext_helper.assert_argument_type(2, horizoffset, "number")
    finext_helper.assert_argument_type(3, vertoffset, "number")

    for ctrl in each(self) do
        ctrl:MoveRelative(horizoffset, vertoffset)
    end
end

--[[
% FindControl

**[PDK Port]**

Finds a control based on its ID.

Port Changes:
- Returns the original control object.

@ self (xFCCustomWindow)
@ control_id (number)
: (xFCControl | nil)
]]
function methods:FindControl(control_id)
    finext_helper.assert_argument_type(2, control_id, "number")

    return private[self].Controls[control_id]
end

--[[
% GetControl

Finds a control based on its name.

@ self (xFCCustomWindow)
@ control_name (xFCString | string)
: (xFCControl | nil)
]]
function methods:GetControl(control_name)
    finext_helper.assert_argument_type(2, control_name, "string", "xFCString")

    return private[self].NamedControls[tostring(control_name)]
end

--[[
% GetItemAt

**[Override]**

Override Changes:
- Returns the original control object.

@ self (xFCCustomWindow)
@ index (number)
: (xFCControl)
]]
function methods:GetItemAt(index)
    local item = self.__:GetItemAt(index)
    return item and private[self].Controls[item:GetControlID()] or nil
end

--[[
% GetParent

**[PDK Port]**

Returns the parent window. The parent will only be available while the window is showing.

@ self (xFCCustomWindow)
: (xFCCustomWindow | nil) `nil` if no parent
]]
function methods:GetParent()
    return private[self].Parent
end

--[[
% GetTitle

**[?Fluid] [Override]**

Override Changes:
- Passing an `xFCString` is optional. If omitted, the result is returned as a Lua `string`. If passed, nothing is returned and the method is fluid.

@ self (xFCCustomWindow)
@ [title] (xFCString)
: (string) Returned if `title` is omitted.
]]
methods.GetTitle = mixin_proxy.xcfstring_getter("GetTitle", 2, 2, temp_str)

--[[
% SetTitle

**[Fluid] [Override]**

Override Changes:
- Accepts Lua `string` or `number` in addition to `xFCString`.

@ self (xFCCustomWindow)
@ title (xFCString | string | number)
]]
methods.SetTitle = mixin_proxy.xfcstring_setter("SetTitle", 2, temp_str)

--[[
% ExecuteModal

**[Override]**

Override Changes:
- Stores the parent window to make it available via `GetParent`.

@ self (xFCCustomWindow)
@ parent (xFCCustomWindow | nil)
: (number)
]]
function methods:ExecuteModal(parent)
    private[self].Parent = parent
    local ret = self.__:ExecuteModal(parent and parent.__ or nil)
    private[self].Parent = nil
    return ret
end

return class
