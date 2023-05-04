--  Author: Edward Koltun
--  Date: 2023/02/07
--[[
$module FinExt Helper

A library of helper functions to improve code reuse in extensiona.
]]--
require("library.lua_compatibility")
local utils = require("library.utils")
local mixin = require("library.finext")
local library = require("library.general_library")

local finext_helper = {}

local debug_enabled = finenv.DebugEnabled

function finext_helper.is_instance_of(object, ...)
    local fc_class_names = {n = 0}
    local ext_class_names = {n = 0}
    local has_fc = false
    local has_ext = false

    for i = 1, select("#", ...) do
        local class_name = select(i, ...)
        -- Skip over anything that isn't a class name (for easy integration with `assert_argument_type`)
        if finext.IsFCClassName(class_name) then
            fc_class_names[class_name] = true
            has_fc = true
        elseif finext.IsxFCClassName(class_name) or finext.IsxFXClassName(class_name) then
            ext_class_names[class_name] = true
            has_ext = true
        end
    end

    if library.is_finale_object(object) then
        if not has_fc then
            return false
        end

        local class_name = library.get_class_name(object)
        while class_name do
            if fc_class_names[class_name] then
                return true
            end
            class_name = library.get_parent_class(class_name)
        end
    elseif finext.IsExtension(object) then
        if not has_ext then
            return false
        end

        local class_name = object.ExtClassName
        while class_name do
            if ext_class_names[class_name] then
                return true
            end
            class_name = finext[class_name].ExtParent
        end
    end

    return false
end

return finext_helper
