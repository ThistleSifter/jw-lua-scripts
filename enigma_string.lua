-- A library of helpful JW Lua scripts for enigma strings
-- Ideally these would be available in the PDK Framework
-- Simply import this file to another Lua script to use any of these scripts
local enigma_string = {}

--This implements a hypothetical FCString::TrimFirstEnigmaFontTags() function that would
--preferably be in the PDK Framework. Trimming only first allows us to preserve
--style changes within the rest of the string, such as changes from plain to
--italic. Ultimately this seems more useful than trimming out all font tags.
--If the PDK Framework is ever changed, it might be even better to create replace font
--functions that can replace only font, only size, only style, or all three together.

local starts_with_font_command = function(string)
    local text_cmds = {"^font", "^Font", "^fontMus", "^fontTxt", "^fontNum", "^size", "^nfx"}
    for i, text_cmd in ipairs(text_cmds) do
        if string:StartsWith(text_cmd) then
            return true
        end
    end
    return false
end

--returns the first font info that was stripped or nil if none
function enigma_string.trim_first_enigma_font_tags(string)
    local font_info = finale.FCFontInfo()
    local found_tag = false
    while true do
        if not starts_with_font_command(string) then
            break
        end
        local end_of_tag = string:FindFirst(")")
        if end_of_tag < 0 then
            break
        end
        local font_tag = finale.FCString()
        if string:SplitAt(end_of_tag, font_tag, nil, true) then
            font_info:ParseEnigmaCommand(font_tag)
        end
        string:DeleteCharactersAt(0, end_of_tag+1)
        found_tag = true
    end
    if found_tag then
        return font_info
    end
    return nil
end

function enigma_string.change_first_string_font (string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    local current_font_info = enigma_string.trim_first_enigma_font_tags(string)
    if (current_font_info == nil) or not font_info:IsIdenticalTo(current_font_info) then
        final_text:AppendString(string)
        string:SetString (final_text)
        return true
    end
    return false
end

function enigma_string.change_first_text_block_font (text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    if enigma_string.change_first_string_font(new_text, font_info) then
        text_block:SaveRawTextString(new_text)
        return true
    end
    return false
end

--These implement a complete font replacement using the PDK Framework's
--built-in TrimEnigmaFontTags() function.
 
function enigma_string.change_string_font (string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    string:TrimEnigmaFontTags()
    final_text:AppendString(string)
    string:SetString (final_text)
end

function enigma_string.change_text_block_font (text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    enigma_string.change_string_font(new_text, font_info)
    text_block:SaveRawTextString(new_text)
end

return enigma_string
