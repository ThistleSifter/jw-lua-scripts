--  Author: Edward Koltun
--  Date: November 3, 2021

--[[
$module FinExt

The FinExt (Finale extension) library allows Finale objects to be extended with modified or additional methods and properties to simplify the process of writing plugins. It provides two methods of formally defining extensions: `xFC` and `xFX` extensions. As an added convenience, the library also automatically applies a fluid interface to extension methods where possible.


## The tl;dr Version
Replace this:
```lua
finale.FCString()
```

With this:
```lua
finext.xFCString()
```

To get an extended Finale object with a fluid interface that can be modified.

If extensions exist in the `finext` folder (either for that class or a parent class), they will be loaded and the methods will be added / existing ones overridden.


## The `finext` Namespace
Extension-wrapped objects can be created from the `finext` namespace, which functions in the same way as the `finale` namespace. To create an extension-wrapped version of a Finale object, simply add an `x` to the class name before the `FC` and call it from the `finext` namespace.
```lua
-- Include the finext namespace as well as any additional functions
local finext = require("library.finext")

-- Create an extension-wrapped FCString
local str = finext.xFCString()

-- Create an extension-wrapped FCCustomLuaWindow
local dialog = finext.xFCCustomLuaWindow()
```

## Adding Methods or Properties to Finale Objects
The FinExt library allows methods and properties to be added to Finale objects in two ways:

1) Predefined `xFC` or `xFX` extensions which can be accessed from the `finext` namespace or returned from other extension methods. For example:
```lua
local finext = require("library.finext")

-- Creates an FCCustomLuaWindow object wrapped in an xFCCustomLuaWindow extension, applying any methods or properties from it and its parents
local dialog = finext.xFCCustomLuaWindow()

-- Creates an FCCustomLuaWindow object and wraps it in an xFXMyCustomDialog extension, which further extends xFCCustomLuaWindow
local mycustomdialog = finext.xFXMyCustomDialog()
```
*For more information about `xFC` and `xFX` extensions, see the next section and the extension templates further down the page*

2) Setting them on the extension the same as any other table. For example:

```lua
local finext = require("library.finext")
local str = finext.xFCString()

-- Add a new property
str.MyCustomProperty = "Hello World"

-- Add a new method
function str:AlertMyCustomProperty()
    finenv.UI():AlertInfo(self.MyCustomProperty, "My Custom Property")
end

-- Execute the new method
str:AlertMyCustomProperty()
```

Regardless of which approach is used, the following principles apply:
- New methods can be added or existing methods can be overridden.
- New properties can be added but existing properties will follow their defined behaviour (ie readability, writability, types, etc), either from the underlying `FC` object or as defined in any applicable extensions.
- Properties cannot override methods and vice versa
- The underlying `FC` object can always be directly accessed via the `__` property (eg `control.__` or for a method call, `control.__:GetWidth()`).
- Methods or properties beginning with `Ext` are reserved for internal use and cannot be set.
- The constructor cannot be overridden or changed in any way.


## `xFC` and `xFX` Extensions & Class Hierarchy

### `xFC` Extensions
`xFC` extensions are modified `FC` classes. The name of each `xFC` extension corresponds to the `FC` class that it extends. For example `__FCBase` -> `__xFCBase`, `FCControl` -> `xFCControl`, `FCCustomLuaWindow` -> `xFCCustomLuaWindow`, etc etc

`xFC` extensions are mainly intended to enhance core functionality, by fixing bugs, expanding method signatures (eg allowing a method to accept a regular Lua `string` as well as an `FCString`) and providing additional convenience methods to simplify the process of writing plugins.

To maximise compatibility and to simplify migration, `xFC` extensions retain as much backwards compatibility as possible with standard code using `FC` classes, but there may be a very small number of breaking changes. These will be marked in the documentation.

*Note that `xFC` extension definitions are optional. If an `xFC` extension does not exist in the `finext` folder, an extension-wrapped Finale object will still be created (ie able to be modified and with a fluid interface). It just won't have any new or overridden methods.*

### `xFX` Extensions
`xFX` extensions are customised `FC` objects. With no restrictions and no requirement for backwards compatibility, `xFX` extensions are intended to create highly specialised functionality that is built off an existing `xFC` extension.

The name of an `xFX` extension can be anythng, as long as it begins with `xFX` followed by an uppercase letter.

### Extension Class Hierarchy
With extensions applied, the new inheritance tree looks like this:

```
              ________
             /        \
 __FCBase    |    __xFCBase
     |       |        |
     V       |        V
 FCControl   |    xFCControl
     |       |        |
     V       |        V
FCCtrlEdit   |   xFCCtrlEdit
     |       |        |
     \_______/       ---
                      |
                      V
             xFXCtrlMeasurementEdit
```

`xFC` extensions share a parellel heirarchy with the `FC` classes they extend, but as they are applied on top of an existing `FC` object, they come afterwards in the tree. `xFX` extensions are applied on top of `xFC` classes and any subsequent `xFX` extensions continue the tree in a linear a fashion downwards.

## Wrapping and Unwrapping Finale Objects
The `finext` library provides a couple of ways of bridging between methods and functions that use extensions and those that use standard Finale objects.

### Wrapping an existing Finale object in an extension
```lua
local finext = require("library.finext")
local str = finext(finale.FCString())
```

### Calling a function that expects Finale object(s)
```lua
local finext = require("library.finext")
local note = finext.xFCNote()
...
-- Unwraps any extensions (in this case `note`), passes it to `library.duplicate_fcnote`
-- The function's return values are returned, with any Finale objects being wrapped in extensions
local note_copy = finext(library.duplicate_fcnote, note)
```

### Calling a method from the underlying object
```lua
-- xFCString.lua
local finext = require("library.finext")
...
function methods:SetLuaString(str)
    -- Unwraps any extensions, passes them to the `SetLuaString` of the underlying Finale object of `self`
    -- And returns any returned values from the method, with any Funale objects being wrapped in extensions
    finext.__(self, "SetLuaString", tostring(str))
end
```

### Directly accessing the underlying Finale object
```lua
-- xFCString.lua
local finext = require("library.finext")
...
function methods:SetLuaString(str)
    -- The __ property of an extension contains its underlying Finale object
    self.__:SetLuaString(tostring(str))
end
```


### Special Properties
All extensions have a number of special read-only properties:
- **`ExtClassName`** *`[string]`* - The extension class name.
- **`ExtParent`** *`[?string]`* - The name of the parent extension (for `__xFCBase` this will be `nil`).
- **`ExtBase`** *`[?string]`* - *xFX only.* The class name of the underlying `xFC` extension on which it is based.

Additionally, for reflection and testing, the following properties are available statically via the `finext` namespace:
- **`Init`** *`[?function]`* - *Optional.* The extension's initialiser or `nil` if it doesn't have one.
- **`__class`** *`[table <string, function>]`* - The extension's own methods (excluding inherited ones).
- **`__static`** *`[table <string, function>]`* - The extension's own static methods (excluding inherited ones).
- **`__propget`** *`[table <string, function>]`* - The extension's own property getters (excluding inherited ones).
- **`__propset`** *`[table <string, function>]`* - The extension's own property setters (excluding inherited ones).
- **`__disabled`** *`[table <string, true>]`* - The extension's own disabled methods/properties (excluding inherited ones).
- **`__metamethods`** *`[table <string, function>]`* - The extension's own metatable metamethods (excluding inherited ones).


## Accessing Extension Methods Statically
All methods from *defined* `xFC` and `xFX` extensions can be accessed statically through the `finext` namespace.
```lua
local finext = require("library.finext")
local str = finext.xFXString()

-- Standard instance method call
str:SetLuaString("hello world")

-- Accessing an instance method statically
finext.xFXString.PrintString(str, "goodbye world")

-- Accessing a static method
finext.xFXString.PrintHelloWorld()
```


## Fluid Interface (aka Method Chaining)
Any method on an extension-wrapped Finale object that returns zero values (returning `nil` still counts as a value) will have a fluid interface automatically applied by the library. This means that instead of returning nothing, the method will return `self`.

For example, this was the previous way of creating an edit control:
```lua
local dialog = finale.FCCustomLuaWindow()
dialog:SetWidth(100)
dialog:SetHeight(100)
local edit = dialog:CreateEdit(0, 0)
edit:SetWidth(25)
edit:SetMeasurement(12, finale.MEASUREMENTUNIT_DEFAULT)
```

With the fluid interface, the code above can be shortened to this:
```lua
local finext = require("library.finext")
local dialog = finext.xFCCustomLuaWindow():SetWidth(100):SetHeight(100)

local edit = dialog:CreateEdit(0, 0):SetWidth(25):SetMeasurementInteger(12, finale.MEASUREMENTUNIT_DEFAULT)
```

Alternatively, the example above can be indented in the following way:

```lua
local finext = require("library.finext")
local dialog = finext.xFCCustomLuaWindow()
    :SetWidth(100)
    :SetHeight(100)
local edit = dialog:CreateEdit(0, 0)
    :SetWidth(25)
    :SetMeasurementInteger(12, finale.MEASUREMENTUNIT_DEFAULT)
```


## Creating Extensions
General points for creating extensions:
- Place extension definitions in a Lua file named after the extension's class name in the `finext` or `personal_finext` folder (eg `__xFCBase.lua`, `xFXMyCustomDialog.lua`, etc). There can only be one extension per file.
- All extensions must return a table which contains the class definition (see below for a list of the properties it can contain and for some examples).
- The initialiser (`Init`) is called after the object has been constructed, so all public methods will be available.
- If you need to guarantee that a method call won't refer to an overridden method, use a static call (eg `finext.xFCControl.GetText(self)`).
- A name cannot be shared between a method, static method or a property.

### Class Table Properties
**All properties are optional except for `Parent`, which is required for `xFX` extensions).**

#### `class.Parent` **string** (xFX only)
The name of the parent extension class.

#### `class.Init` **function**
The initialiser function. Initialisers are called one after another from parent to child when creating extensions.

#### `class.Methods` **table <string, function>**
The class's public inatance methods.

#### `class.StaticMethods` **table <string, function>**
The class's public static methods.

#### `class.Properties` **table <string, table <string, function>>**
The class's public properties. Each property is a table which can have a `Get` and a `Set` property.
`Get` **function(self)** - A getter which returns the property value.
`Set` **function(self, value)** - A setter which sets the property value.

#### `class.Disabled` **table <string>**
A list of the class's disabled properties and methods. Disabling a method or property forces it to be `nil` and this cannot be overridden.

#### `class.MetaMethods` **table <string, function>**
Since extensions are tables, their netatables can have numerous metamethods. The `MetaMethods` property allows an extension class to add metamethods to its own metatable.

Not all metamethods are permitted to be added, for a current list, see the source code.

### Creating `xFC` Extensions
Points to remember when creating `xFC` extensions:
- The filename of an `xFC` extension must correspond exactly to the `FC` class that it extends (ie `__FCBase` -> `__xFCBase.lua`, `FCNote` -> `xFCNote.lua`). Since `xFC` extensions are optional, a misspelled filename will simply result in the extension not being loaded, without any errors.
- `xFC` extensions can be defined for any class in the PDK, including abstract parent classes that can't be directly accessed (eg `__FCBase`, `FCControl`). Use these classes if you need to add functionality that will be inherited by all child classes.

Below is a basic template for creating an `xFC` extension. Replace the example methods with concrete ones:
```lua
-- Include the finexr namespace and helper methods (include any additional libraries below)
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

-- Class definition
local class = {Methods = {}, StaticMethods = {}}

-- Table for storing private data for this extension (remove this if not used)
local private = setmetatable({}, {__mode = "k"})

-- Shorthand references, so we don't have to type as much later
local methods = class.Methods
local static = class.StaticMethods

-- Example initializer (remove this if not needed).
function class:Init()
    -- Prevent this from being run more than once per instance
    if private[self] then
        return
    end

    -- Create private storage and initialise private properties
    private[self] = {
        ExamplePrivateProperty = "hello world",
    }
end

-- Define all methods here (remove/replace examples as needed)

-- Example public instance method (use a colon)
function methods:SetExample(value)
    -- Ensure argument is the correct type for testing
    -- The argument number is 2 because when using a colon in the method signature, it will automatically be passed `self` as the first argument.
    finext_helper.assert_argument_type(2, value, "string")

    private[self].ExamplePrivateProperty = value
end

-- Example public static method (note the use of a dot instead of a colon)
function static.GetMagicNumber()
    return 7
end

-- Return class definition
return class
```

### Creating `xFX` Extensions
Points to remember when creating `xFX` extensions:
- The name of an `xFX` extension must be in Pascal case (just like the `FC` classes), beginning with `xFX`. For example `xFXMyCustomDialog`, `xFXCtrlMeasurementEdit`, `xFXCtrlPageSizePopup`, etc
- The parent class must be declared, which can be either an `xFC` or `xFX` class. If it is an `xFC` class, it must be a concrete class (ie one that can be instantiated, like `xFCCtrlEdit`) and not an abstract parent class (ie not `xFCjubileeControl`).


Below is a template for creating an `xFX` extension. It is almost identical to defining an `xFC` extension but there are a couple of important differences.
```lua
-- Include the finext namespace and helper methods (include any additional libraries below)
local finext = require("library.finext")
local finext_helper = require("library.finext_helper")

-- Class definition
-- xFX extensions must declare their parent class (change as needed)
local class = {Parent = "xFCString", Methods = {}, StaticMethods = {}}

-- Table for storing private data for this extension (remove this if not used)
local private = setmetatable({}, {__mode = "k"})

-- Shorthand references, so we don't have to type as much later
local methods = class.Methods
local static = class.StaticMethods

-- Example initializer (remove this if not needed).
function class:Init()
    -- Prevent this from being run more than once per instance
    if private[self] then
        return
    end

    -- Create private storage and initialise private properties
    private[self] = {
        Counter = 0,
    }
end

---
-- Define all methods here (remove/replace examples as needed)
---

-- Example public instance method (use a colon)
function methods:IncrementCounter()
    private[self].Counter = private[self].Counter + 1
end


-- Example public static method (use a dot)
function static.GetHighestCounter()
    local highest = 0

    for _, v in pairs(private) do
        if v.Counter < highest then
            highest = v.Counter
        end
    end

    return highest
end

-- Return class definition
return class
```


## Personal Extensions
If you've written extensions for your personal use and don't want to submit them to the Finale Lua repository, you can place them in a folder called `personal_finext`, next to the `finext` folder.

Personal extensions take precedence over public extensions, so if an extension with the same name exists in both folders, the one in the `personal_finext` folder will be used.


## Constants
The `finext` library also supports adding custom constants to the `finext` namespace. Constants should be defined in a file called `__CONSTANTS.lua` which can be placed in either the `finext` or `personal_finext` directory.
Constants are loaded automatically by the library.

The name of a constant can only contain uppercase letters and underscores and must start and end with a letter.

**Note that unlike extensions, constants cannot be overridden and if a constant is defined in more than one place, an error will be thrown.**

The `__CONSTANTS.lua` file should adhere to the followong format:
```lua
-- Return a table of constants
return {
    -- A constant group (all constants must go in groups)
    MEASUREMENTSUFFIX = {
        -- Individual constant values (names will be appended to the group name separated by an underscore)
        SHORT = 1, -- MEASUREMENTSUFFIX_SHORT
        FULL = 2, -- MEASUREMENTSUFFIX_FULL
    },
    -- Define as many constant groups as needed
}
```

Accessing constants:
```lua
local finext = require("library.finext")
...
...
ctrl:SetMeasurementSuffixStyle(finext.MEASUREMENTSUFFIX_FULL)
```
]]
local utils = require("library.utils")
local library = require("library.general_library")

-- Public methods and extension constructors, stored separately to keep the finext namespace read-only.
local public = {}
-- Private methods
local private = {}
-- FC and FX extension class definitions
local classes = {}
-- Fully resolved class definitions, optimised for run-time lookups
local lookups = {}
-- Extensions and the objects they're connected to
local extension_objects = setmetatable({}, {__mode = "k"})
local object_extensions = setmetatable({}, {__mode = "kv"})
-- Extension class metatables
local metatables = {}

local reserved_props = {
    ExtClassName = function(class_name) return class_name end,
    ExtParent = function(class_name) return classes[class_name].Parent end,
    ExtBase = function(class_name) return classes[class_name].Base end,
    Init = function(class_name) return classes[class_name].Init end,
    __ = function() end, -- Special case, handled separately
    __class = function(class_name) return private.create_method_reflection(class_name, "Methods") end,
    __static = function(class_name) return private.create_method_reflection(class_name, "StaticMethods") end,
    __propget = function(class_name) return private.create_property_reflection(class_name, "Get") end,
    __propset = function(class_name) return private.create_property_reflection(class_name, "Set") end,
    __disabled = function(class_name) return classes[class_name].Disabled and utils.copy_table(classes[class_name].Disabled) or {} end,
    __metamethods = function(class_name) return classes[class_name].MetaMethods and utils.copy_table(classes[class_name].MetaMethods) or {} end,
}

local instance_reserved_props = {
    ExtClassName = true,
    ExtParent = true,
    ExtBase = true,
}

local finext

function private.is_fc_class_name(class_name)
    return type(class_name) == "string" and (class_name:match("^FC%u") or class_name:match("^__FC%u")) and true or false
end

function private.is_xfc_class_name(class_name)
    return type(class_name) == "string" and (class_name:match("^xFC%u") or class_name:match("^__xFC%u")) and true or false
end

function private.is_xfx_class_name(class_name)
    return type(class_name) == "string" and class_name:match("^xFX%u") and true or false
end

function private.fc_to_xfc_class_name(class_name)
    return string.gsub(class_name, "FC", "xFC", 1)
end

function private.xfc_to_fc_class_name(class_name)
    return string.gsub(class_name, "xFC", "FC", 1)
end

function private.assert_valid_property_name(name, error_level, suffix)
    if type(name) ~= "string" then
        error("Extension method and property names must be strings" .. suffix, error_level)
    end

    suffix = suffix or ""

    if name:match("^Ext%u") then
        error("Extension methods and properties cannot begin with 'Ext'" .. suffix, error_level)
    elseif reserved_props[name] then
        error("'" .. name .. "' is a reserved name and cannot be used for propertiea or methods" .. suffix, error_level)
    end
end

-- Attempts to load a module
function private.try_load_module(name)
    local success, result = pcall(require, name)

    -- If the reason it failed to load was anything other than module not found, display the error
    if not success and not result:match("module '[^']-' not found") then
        error(result, 0)
    end

    return success, result
end

function private.find_ancestor_with_prop(class, attr, prop)
    if class[attr] and class[attr][prop] then
        return class.ClassName
    end
    if not class.Parent then
        return nil
    end
    return private.find_ancestor_with_prop(classes[class.Parent], attr, prop)
end

local allowed_metamethods = {
    __concat = "function",
    __tostring = "function",
}

-- Loads an xFC or xFX extension class
function private.load_extension_class(class_name)
    if classes[class_name] then return end

    local is_xfc = private.is_xfc_class_name(class_name)

    -- Only load xFC and xFX extensions
    if not is_xfc and not private.is_xfx_class_name(class_name) then
        return
    end

    local is_personal_extension = false
    local success
    local result

    -- Try personal extensions first (allows the library's extension to be overridden if desired)
    success, result = private.try_load_module("personal_extension." .. class_name)

    if success then
        is_personal_extension = true
    else
        success, result = private.try_load_module("extension." .. class_name)
    end

    if not success then
        -- xFC classes are optional, so if it's valid and not found, start with a blank slate
        if is_xfc and finale[class_name] then
            result = {}
        else
            return
        end
    end

    local error_prefix = (is_personal_extension and "personal_" or "") .. "extension." .. class_name

    -- Extensions must be a table
    if type(result) ~= "table" then
        error("Extensions must be a table, " .. type(result) .. " given (" .. error_prefix .. ")", 0)
    end

    local class = {ClassName = class_name}

    local function has_attr(attr, attr_type)
        if result[attr] == nil then
            return false
        end
        if type(result[attr]) ~= attr_type then
            error("Extension '" .. attr .. "' must be a " .. attr_type .. ", " .. type(result[attr]) .. " given (" .. error_prefix .. "." .. attr .. ")", 0)
        end
        return true
    end

    -- Check and assign or copy parent
    has_attr("Parent", "string")

    -- zFC specific
    if is_xfc then
        -- Store the parent xFC class name
        class.Parent = library.get_parent_class(private.xfc_to_fc_class_name(class_name))

        if class.Parent then
            class.Parent = private.fc_to_xfc_class_name(class.Parent)
            private.load_extension_class(class.Parent)
        end

    -- xFX specific
    else
        -- xFX classes must specify a parent
        if not result.Parent then
            error("Extensions must declare a parent class (" .. error_prefix .. ")", 0)
        end

        if not private.is_xfc_class_name(result.Parent) and not private.is_xfx_class_name(result.Parent) then
            error("Extension parent must be an xFC or xFX class name, '" .. result.Parent .. "' given (" .. error_prefix .. ".Parent)", 0)
        end

        private.load_extension_class(result.Parent)

        -- Check if xFX parent is missing
        if not classes[result.Parent] then
            error("Unable to load extension '" .. result.Parent .. "' as parent of '" .. error_prefix .. "'", 0)
        end

        class.Parent = result.Parent

        -- Get the base xFC class (all xFX classes must eventually arrive at an xFC parent)
        class.Base = classes[result.Parent].Base or result.Parent
    end

    -- Now that we have the parent, create a lookup base before we continue
    local lookup = class.Parent and utils.copy_table(lookups[class.Parent]) or {Methods = {}, Properties = {}, Disabled = {}, xFCInits = {}}

    -- Check and copy the remaining attributes
    if has_attr("Init", "function") and is_xfc then
        table.insert(lookup.xFCInits, result.Init)
    end
    class.Init = result.Init
    if not is_xfc then
        lookup.xFCInits = nil
    end

    -- Process Disabled before methods and properties because we need these for later checks
    if has_attr("Disabled", "table") then
        class.Disabled = {}
        for _, v in pairs(result.Disabled) do
            private.assert_valid_property_name(v, 0, " (" .. error_prefix .. ".Disabled." .. tostring(v) .. ")")
            class.Disabled[v] = true
            lookup.Disabled[v] = true
            lookup.Methods[v] = nil
            lookup.Properties[v] = nil
        end
    end

    local function find_property_name_clash(name, attr_to_check)
        for _, attr in pairs(attr_to_check) do
            if attr == "StaticMethods" or (lookup[attr] and lookup[attr][nane]) then
                local cl = find_ancestor_with_prop(class, attr, name)
                return cl and (cl .. "." .. attr .. "." .. name) or nil
            end
        end
    end

    if has_attr("Methods", "table") then
        class.Methods = {}
        for k, v in pairs(result.Methods) do
            private.assert_valid_property_name(k, 0, " (" .. error_prefix .. ".Methods." .. tostring(k) .. ")")
            if type(v) ~= "function" then
                error("An extension method must be a function, " .. type(v) .. " given (" .. error_prefix .. ".Methods." .. k .. ")", 0)
            end
            if lookup.Disabled[k] then
                error("Extension methods cannot be defined using disabled names (" .. error_prefix .. ".Methods." .. k .. ")", 0)
            end
            local clash = find_property_name_clash(k, {"StaticMethods", "Properties"})
            if clash then
                error("A method, static method or property cannot share the same name (" .. error_prefix .. ".Methods." .. k .. " & " .. clash .. ")", 0)
            end
            class.Methods[k] = v
            lookup.Methods[k] = v
        end
    end

    if has_attr("StaticMethods", "table") then
        class.StaticMethods = {}
        for k, v in pairs(result.StaticMethods) do
            private.assert_valid_property_name(k, 0, " (" .. error_prefix .. ".StaticMethods." .. tostring(k) .. ")")
            if type(v) ~= "function" then
                error("An extension method must be a function, " .. type(v) .. " given (" .. error_prefix .. ".StaticMethods." .. k .. ")", 0)
            end
            if lookup.Disabled[k] then
                error("Extension methods cannot be defined using disabled names (" .. error_prefix .. ".StaticMethods." .. k .. ")", 0)
            end
            local clash = find_property_name_clash(k, {"Methods", "Properties"})
            if clash then
                error("A method, static method or property cannot share the same name (" .. error_prefix .. ".StaticMethods." .. k .. " & " .. clash .. ")", 0)
            end
            class.Methods[k] = v
        end
    end

    if has_attr("MetaMethods", "table") then
        class.MetaMethods = {}
        for k, v in pairs(results.MetaMethods) do
            if not allowed_metamethods[k] then
                error("'" .. tostring(k) .. "' is not an allowed metamethod (" .. error_prefix .. ".Meta." .. tostring(k) .. ")")
            end
            if type(v) ~= allowed_metamethods[k] then
                error("Bad metamethod type (" .. allowed_metamethods[k] .. " expected, " .. type(v) .. " given) (" .. error_prefix .. ".Meta." .. k .. ")")
            end
            class.MetaMethods[k] = v
        end
    end

    if has_attr("Properties", "table") then
        class.Properties = {}
        for k, v in pairs(result.Properties) do
            private.assert_valid_property_name(k, 0, " (" .. error_prefix .. ".Properties." .. tostring(k) .. ")")
            if lookup.Disabled[k] then
                error("Extension properties cannot be defined using disabled names (" .. error_prefix .. ".Properties." .. k .. ")", 0)
            end
            local clash = find_property_name_clash(k, {"Methods", "StaticMethods"})
            if clash then
                error("A method, static method or property cannot share the same name (" .. error_prefix .. ".Properties." .. k .. " & " .. clash .. ")", 0)
            end
            if type(v) ~= "table" then
                error("An extension property descriptor must be a table, " .. type(v) .. " given (" .. error_prefix .. ".Properties." .. k .. ")", 0)
            end
            if not v.Get and not v.Set then
                error("An extension property descriptor must have at least a 'Get' or 'Set' attribute (" .. error_prefix .. ".Properties." .. k .. ")", 0)
            end

            class.Properties[k] = {}
            lookup.Properties[k] = lookup.Properties[k] or {}

            for kk, vv in pairs(v) do
                if kk ~= "Get" and kk ~= "Set" then
                    error("An extension property descriptor can only have 'Get' and 'Set' attributes (" .. error_prefix .. ".Properties." .. k .. ")", 0)
                end
                if type(vv) ~= "function" then
                    error("An extension property descriptor attribute must be a function, " .. type(vv) .. " given (" .. error_prefix .. ".Properties." .. k .. "." .. kk .. ")", 0)
                end
                class.Properties[k][kk] = vv
                lookup.Properties[k][kk] = vv
            end
        end
    end

    lookups[class_name] = lookup
    classes[class_name] = class
end

function private.create_method_reflection(class_name, attr)
    local t = {}
    if classes[class_name][attr] then
        for k, v in pairs(classes[class_name][attr]) do
            t[k] = v
        end
    end
    return t
end

function private.create_property_reflection(class_name, attr)
    local t = {}
    if classes[class_name].Properties then
        for k, v in pairs(classes[class_name].Properties) do
            if v[attr] then
                t[k] = v[attr]
            end
        end
    end
    return t
end

-- Handles the fluid interface
local function fluid_proxy(t, ...)
    -- If no return values, then apply the fluid interface
    if select("#", ...) == 0 then
        return t
    end

    return ...
end

-- Wraps all passed Finale objects in extensions
local function wrap_proxy(...)
    local t
    for i = 1, #t do
        if library.is_finale_object(t[i]) then
            t = t or table.pack(...)
            t[i] = private.create_extension(t[i])
        end
    end
    return t and table.unpack(t) or ...
end

-- Unwraps all passed extensions
local function unwrap_proxy(...)
    local t
    for i = 1, #t do
        if extension_objects[t[i]] then
            t = t or table.pack(...)
            t[i] = extension_objects[t[i]]
        end
    end
    return t and table.unpack(t) or ...
end

-- Returns a function that handles the fluid interface and error re-throwing
function private.create_fluid_proxy(func)
    return function(t, ...)
        return fluid_proxy(t, utils.call_and_rethrow(2, func, t, ...))
    end
end

function private.create_fluid_fc_proxy(func)
    return function(t, ...)
        return fluid_proxy(t, wrap_proxy(utils.call_and_rethrow(2, func, unwrap_proxy(t, ...))))
    end
end

-- Takes an FC object and wraps it in an extension
function private.create_extension(object, class_name)
    if object_extensions[object] then
        return object_extensions[object]
    end

    class_name = class_name or private.fc_to_xfc_class_name(library.get_class_name(object))
    private.load_extension_class(class_name)
    local extension = setmetatable({}, private.get_class_metatable(class_name))
    extension_objects[extension] = object
    object_extensions[object] = extension

    for _, v in ipairs(lookups[class_name].xFCInits) do
        v(extension)
    end

    return extension
end

function private.get_class_metatable(class_name)
    if not metatables[class_name] then
        local metatable = {}
        metatable.__index = function(t, k)
            -- Special property for accessing the underlying object
            if k == "__" then
                return extension_objects[t]
            -- Methods
            elseif lookups[class_name].Methods[k] then
                return private.create_fluid_proxy(lookups[class_name].Methods[k])
            -- Properties
            elseif lookups[class_name].Properties[k] then
                return lookups[class_name].Properties.Get(t)
            -- Reserved properties
            elseif instance_reserved_props[k] then
                return reserved_props[k](class_name)
            -- All extension and PDK keys are strings
            elseif type(k) ~= "string" then
                return nil
            end

            -- Original object
            local prop = extension_objects[t][k]
            if type(prop) == "function" then
                prop = private.create_fluid_fc_proxy(prop)
            end
            return prop
        end

        metatable.__newindex = function(t, k, v)
            -- If it's disabled or reserved, throw an error
            if lookups[class_name].Disabled[k] or reserved_props[k] then
                error("No writable member '" .. tostring(k) .. "'", 2)
            end

            -- If a property descriptor exists, use the setter if it has one
            -- Otherwise, use the original property (this prevents a read-only property from being overwritten by a custom property)
            if lookups[class_name].Properties[k] then
                if lookups[class_name].Properties[k].Set then
                    return lookups[class_name].Properties[k].Set(t, v)
                else
                    -- @TODO test this, find some other way of capturing the error
                    return utils.call_and_rethrow(2, function(tt, kk, vv) extension_objects[tt][kk] = vv end, t, k, v)
                end
            end

            -- If it's not a string key, it has to be a custom property
            if type(k) ~= "string" then
                rawset(t, k, v)
                return
            end

            private.assert_valid_property_name(k, 3)

            local type_v_original = type(extension_objects[t][k])
            local type_v = type(v)
            local is_ext_method = lookups[class_name].Methods[k] and true or false

            -- If it's a method or property that doesn't exist on the original object, store it
            if type_v_original == "nil" then

                if is_ext_method and not (type_v == "function" or type_v == "nil") then
                    error("An extension method cannot be overridden with a property.", 2)
                end

                rawset(t, k, v)
                return

            -- If it's a method, we can override it but only with another method
            elseif type_v_original == "function" then
                if not (type_v == "function" or type_v == "nil") then
                    error("A Finale PDK method cannot be overridden with a property.", 2)
                end

                rawset(t, k, v)
                return
            end

            -- Otherwise, try and store it on the original property. If it's read-only, it will fail and we show the error
            -- @TODO test this, find some other way of capturing the error
            return utils.call_and_rethrow(2, function(tt, kk, vv) extension_objects[tt][kk] = vv end, t, k, v)
        end

        -- Collect any defined metamethods1
        local parent = class_name
        while parent do
            if classes[parent].MetaMethods then
                for k, v in pairs(classes[parent].MetaMethods) do
                    if not metatable[k] then
                        metatable[k] = v
                    end
                end
            end
            parent = classes[parent].Parent
        end

        metatables[class_name] = metatable
    end

    return metatables[class_name]
end

function private.subclass(extension, class_name, func_name)
    func_name = func_name or "subclass"

    if not extension_objects[extension] then
        error("bad argument #1 to '" .. func_name .. "' (__xFCBase expected, " .. type(extension) .. " given)", 2)
    end

    if not private.is_xfx_class_name(class_name) then
        error("bad argument #2 to '".. func_name .. "' (xFX class name expected, " .. tostring(class_name) .. " given)", 2)
    end

    if extension.ExtClassName == class_name then
        return extension
    end

    private.load_extension_class(class_name)
    if not classes[class_name] then
        error("Extension class '" .. class_name .. "' not found.", 2)
    end

    local parents = {}
    local current = class_name
    while true do
        table.insert(parents, 1, current)
        current = classes[current].Parent
        if current == extension.ExtClassName then
            goto continue
        elseif private.is_xfc_class_name(current) then
            error("Extension class '" .. class_name .. "' is not a subclass of '" .. extension.ExtClassName .. "'", 2)
        end
    end
    :: continue ::

    for _, parent in ipairs(parents) do
        -- Change class metatable
        setmetatable(extension, private.get_class_metatable(parent))

        -- Remove any newly disabled methods or properties
        if classes[parent].Disabled then
            for k, _ in pairs(classes[parent].Disabled) do
                rawset(extension, k, nil)
            end
        end

        -- Run initialiser, if there is one
        if classes[parent].Init then
            utils.call_and_rethrow(2, classes[parent].Init, extension)
        end
    end

    return extension
end

--[[
% __

Bridging function between extensions and raw finale objects.

@ func (function) A function to call.
@ ... (any) Arguments to the function. Any extensions will be replaced with their underlying objects.
[any] Returned values from the function. Any returned Finale objects will be wrapped in extensions.
]]

--[[
% __

Bridging function between extensions and raw finale objects.

@ object (__FCBase | __xFCBase) Either a Finale object or an extension (which will be unwrapped for the method call).
@ method (string) The name of the method. It must be a method of the passed Finale object or the passed extension's underlying Finale object.
@ ... (any) Arguments to the function. Any extensions will be replaced with their underlying objects.
[any] Returned values from the method. Any returned Finale objects will be wrapped in extensions.
]]
function public.__(a, b, ...)
    if extension_objects[a] then
        a = extension_objects[a]
    end

    if library.is_finale_object(a) then
        if type(a[b]) ~= "function" then
            error("'" .. tostring(b) .. "' is not a method of argument #1.", 2)
        end
        b = a[b]
        b, a = a, b
    end

    if type(a) ~= "function" then
        error("bad argument #1 to '__' (function or __xFCBase or __FCBase expected, " .. type(a) .. " given)", 2)
    end

    return wrap_proxy(utils.call_and_rethrow(2, a, unwrap_proxy(b, ...)))
end

--[[
% UI

Returns an extension-wrapped UI object from `finenv.UI`

: (xFCUI)
]]
function public.UI()
    return private.create_extension(finenv.UI(), "xFCUI")
end

finext = setmetatable({}, {
    __newindex = function(t, k, v) end,
    __index = function(t, k)
        if not public[k] then
            private.load_extension_class(k)
            if not classes[k] then
                return nil
            end
            local metatable = {
                __newindex = function(tt, kk, vv) end,
                __index = function(tt, kk)
                    return (lookups[k].Methods[kk] and private.create_fluid_proxy(lookups[k].Methods[kk]))
                    or lookups[k].StaticMethods[kk]
                    or (lookups[k].Properties[kk] and utils.copy_table(lookups[k].Properties[kk]))
                    or (reserved_props[kk] and reserved_props[kk](k)) -- reserved_props handles calls to copy_table itself if needed
                    or nil
                end,
            }
            if private.is_xfc_class_name(class_name) then
                metatable.__call = function(tt, ...)
                    return private.create_extension(utils.call_and_rethrow(2, finale[private.xfc_to_fc_class_name(k)], ...), k)
                end
            else
                metatable.__call = function(tt, ...)
                    local extension = utils.call_and_rethrow(2, finext[classes[k].Base], ...)
                    if not extension then return nil end
                    return private.subclass(extension, k)
                end
            end
            public[k] = setmetatable({}, metatable)
        end
        return public[k]
    end,
    __call = function(t, object, class_name)
        if library.is_finale_object(object) then
            if object_extensions[object] then
                error("Object has already been extended.", 2)
            end
            local extension = private.create_extension(object)
            return class_name and private.subclass(extension, class_name, 'finext') or extension
        elseif extension_objects[object] then
            return private.subclass(object, class_name, 'finext')
        end
        error("bad argument #1 to 'finext' (__FCBase or __xFCBase expected, " .. type(object) .. " given)", 2)
    end,

    -- Stash these here so they can be added to finext_helper
    is_fc_class_name = private.is_fc_class_name,
    is_xfc_class_name = private.is_xfc_class_name,
    is_xfx_class_name = private.is_xfx_class_name,
    fc_to_xfc_class_name = private.fc_to_xfc_class_name,
    xfc_to_fc_class_name = private.xfc_to_fc_class_name,
    is_extension = function(value) return extension_objects[value] and true or false end,
})

local function load_constants(mod_name)
    local success
    local result
    success, result = try_load_module(mod_name)
    if not success then
        return
    end

    local function assert_valid_name(name, err_name, err_path)
        if not string.match(name, "^%u+") and not string.match(name, "^%u[%u_]-%u$") then
            error("Constant " .. err_name .. " can only contain uppercase letters and underscores and cannot start or end with an underscore, '" .. tostring(name) .. "' given (" .. mod_name .. (err_path or "")  .. ")", 0)
        end
    end

    for k, v in pairs(result) do
        assert_valid_name(kk, "group names")
        for kk, vv in pairs(v) do
            assert_valid_name(kk, "names", "." .. k)
            local const = k .. "_" .. kk
            if public[const] ~= nil then
                error("A constant named '" .. const .. "' already exists and cannot be overridden (" .. mod_name .. "." .. k .. "." .. kk .. ")" , 0)
            end
            public[const] = vv
        end
    end
end

load_constants("finext.__CONSTANTS")
load_constants("personal_finext.__CONSTANTS")

return finext
