function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.NoStore = true
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "May 30, 2022"
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.63
    finaleplugin.Notes = [[
        This script encodes the current document to a utf-8 text file. The primary purpose is to find changes
        between one version of a document and another. One would then write each version out to a text file and then
        use a comparison tool like kdiff3 to find differences. The text files could also be used to track changes with a tool like Git.

        The specifics of the shorthand for how the music is represented may not be that important.
        The idea is to identify the measures and staves that are different and then look at the score to see the differences.

        The following are encoded in such a way that if they are different, a comparison tool will flag them.

        - notes and rhythms
        - articulations
        - expressions (both text and shape)
        - ties
        - smart shapes
        - lyric assignments

        Chord symbols are currently not encoded, due to the lack of a simple way to generate a string for them. This is a needed
        future enhancement.

        The goal of this script is to assist in finding *substantive* differences that would affect how a player would play the piece.
        The script encodes the items above but not small engraving differences such as placement coordinates. One hopes, for example,
        that if there were a printed score that were out of date, this tool would flag the minimum number of changes that needed to
        be hand-corrected in the older score.
    ]]
    return "Save Document As Text File...", "", "Write current document to text file."
end

local text_extension = ".txt"

--[[
$module Note Entry
]] --
local note_entry = {}

--[[
% get_music_region

Returns an intance of `FCMusicRegion` that corresponds to the metric location of the input note entry.

@ entry (FCNoteEntry)
: (FCMusicRegion)
]]
function note_entry.get_music_region(entry)
    local exp_region = finale.FCMusicRegion()
    exp_region:SetCurrentSelection() -- called to match the selected IU list (e.g., if using Staff Sets)
    exp_region.StartStaff = entry.Staff
    exp_region.EndStaff = entry.Staff
    exp_region.StartMeasure = entry.Measure
    exp_region.EndMeasure = entry.Measure
    exp_region.StartMeasurePos = entry.MeasurePos
    exp_region.EndMeasurePos = entry.MeasurePos
    return exp_region
end

-- entry_metrics can be omitted, in which case they are constructed and released here
-- return entry_metrics, loaded_here
local use_or_get_passed_in_entry_metrics = function(entry, entry_metrics)
    if entry_metrics then
        return entry_metrics, false
    end
    entry_metrics = finale.FCEntryMetrics()
    if entry_metrics:Load(entry) then
        return entry_metrics, true
    end
    return nil, false
end

--[[
% get_evpu_notehead_height

Returns the calculated height of the notehead rectangle.

@ entry (FCNoteEntry)

: (number) the EVPU height
]]
function note_entry.get_evpu_notehead_height(entry)
    local highest_note = entry:CalcHighestNote(nil)
    local lowest_note = entry:CalcLowestNote(nil)
    local evpu_height = (2 + highest_note:CalcStaffPosition() - lowest_note:CalcStaffPosition()) * 12 -- 12 evpu per staff step; add 2 staff steps to accommodate for notehead height at top and bottom
    return evpu_height
end

--[[
% get_top_note_position

Returns the vertical page coordinate of the top of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_top_note_position(entry, entry_metrics)
    local retval = -math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if not entry:CalcStemUp() then
        retval = entry_metrics.TopPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling * evpu_height) / 10000) + 0.5)
            retval = entry_metrics.BottomPosition + scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% get_bottom_note_position

Returns the vertical page coordinate of the bottom of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_bottom_note_position(entry, entry_metrics)
    local retval = math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if entry:CalcStemUp() then
        retval = entry_metrics.BottomPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling * evpu_height) / 10000) + 0.5)
            retval = entry_metrics.TopPosition - scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% calc_widths

Get the widest left-side notehead width and widest right-side notehead width.

@ entry (FCNoteEntry)
: (number, number) widest left-side notehead width and widest right-side notehead width
]]
function note_entry.calc_widths(entry)
    local left_width = 0
    local right_width = 0
    for note in each(entry) do
        local note_width = note:CalcNoteheadWidth()
        if note_width > 0 then
            if note:CalcRightsidePlacement() then
                if note_width > right_width then
                    right_width = note_width
                end
            else
                if note_width > left_width then
                    left_width = note_width
                end
            end
        end
    end
    return left_width, right_width
end

-- These functions return the offset for an expression handle.
-- Expression handles are vertical when they are left-aligned
-- with the primary notehead rectangle.

--[[
% calc_left_of_all_noteheads

Calculates the handle offset for an expression with "Left of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_all_noteheads(entry)
    if entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return -left
end

--[[
% calc_left_of_primary_notehead

Calculates the handle offset for an expression with "Left of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_primary_notehead(entry)
    return 0
end

--[[
% calc_center_of_all_noteheads

Calculates the handle offset for an expression with "Center of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    local width_centered = (left + right) / 2
    if not entry:CalcStemUp() then
        width_centered = width_centered - left
    end
    return width_centered
end

--[[
% calc_center_of_primary_notehead

Calculates the handle offset for an expression with "Center of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_primary_notehead(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left / 2
    end
    return right / 2
end

--[[
% calc_stem_offset

Calculates the offset of the stem from the left edge of the notehead rectangle. Eventually the PDK Framework may be able to provide this instead.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset of stem from the left edge of the notehead rectangle.
]]
function note_entry.calc_stem_offset(entry)
    if not entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return left
end

--[[
% calc_right_of_all_noteheads

Calculates the handle offset for an expression with "Right of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_right_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left + right
    end
    return right
end

--[[
% calc_note_at_index

This function assumes `for note in each(note_entry)` always iterates in the same direction.
(Knowing how the Finale PDK works, it probably iterates from bottom to top note.)
Currently the PDK Framework does not seem to offer a better option.

@ entry (FCNoteEntry)
@ note_index (number) the zero-based index
]]
function note_entry.calc_note_at_index(entry, note_index)
    local x = 0
    for note in each(entry) do
        if x == note_index then
            return note
        end
        x = x + 1
    end
    return nil
end

--[[
% stem_sign

This is useful for many x,y positioning fields in Finale that mirror +/-
based on stem direction.

@ entry (FCNoteEntry)
: (number) 1 if upstem, -1 otherwise
]]
function note_entry.stem_sign(entry)
    if entry:CalcStemUp() then
        return 1
    end
    return -1
end

--[[
% duplicate_note

@ note (FCNote)
: (FCNote | nil) reference to added FCNote or `nil` if not success
]]
function note_entry.duplicate_note(note)
    local new_note = note.Entry:AddNewNote()
    if nil ~= new_note then
        new_note.Displacement = note.Displacement
        new_note.RaiseLower = note.RaiseLower
        new_note.Tie = note.Tie
        new_note.TieBackwards = note.TieBackwards
    end
    return new_note
end

--[[
% delete_note

Removes the specified FCNote from its associated FCNoteEntry.

@ note (FCNote)
: (boolean) true if success
]]
function note_entry.delete_note(note)
    local entry = note.Entry
    if nil == entry then
        return false
    end

    -- attempt to delete all associated entry-detail mods, but ignore any failures
    finale.FCAccidentalMod():EraseAt(note)
    finale.FCCrossStaffMod():EraseAt(note)
    finale.FCDotMod():EraseAt(note)
    finale.FCNoteheadMod():EraseAt(note)
    finale.FCPercussionNoteMod():EraseAt(note)
    finale.FCTablatureNoteMod():EraseAt(note)
    if finale.FCTieMod then -- added in RGP Lua 0.62
        finale.FCTieMod(finale.TIEMODTYPE_TIESTART):EraseAt(note)
        finale.FCTieMod(finale.TIEMODTYPE_TIEEND):EraseAt(note)
    end

    return entry:DeleteNote(note)
end

--[[
% calc_pitch_string

Calculates the pitch string of a note for display purposes.

@ note (FCNote)
: (string) display string for note
]]

function note_entry.calc_pitch_string(note)
    local pitch_string = finale.FCString()
    local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
    local key_signature = cell:GetKeySignature()
    note:GetString(pitch_string, key_signature, false, false)
    return pitch_string
end

--[[
% calc_spans_number_of_octaves

Calculates the numer of octaves spanned by a chord (considering only staff positions, not accidentals).

@ entry (FCNoteEntry) the entry to calculate from
: (number) of octaves spanned
]]
function note_entry.calc_spans_number_of_octaves(entry)
    local top_note = entry:CalcHighestNote(nil)
    local bottom_note = entry:CalcLowestNote(nil)
    local displacement_diff = top_note.Displacement - bottom_note.Displacement
    local num_octaves = math.ceil(displacement_diff / 7)
    return num_octaves
end

--[[
% add_augmentation_dot

Adds an augentation dot to the entry. This works even if the entry already has one or more augmentation dots.

@ entry (FCNoteEntry) the entry to which to add the augmentation dot
]]
function note_entry.add_augmentation_dot(entry)
    -- entry.Duration = entry.Duration | (entry.Duration >> 1) -- For Lua 5.3 and higher
    entry.Duration = bit32.bor(entry.Duration, bit32.rshift(entry.Duration, 1))
end

--[[
% get_next_same_v

Returns the next entry in the same V1 or V2 as the input entry.
If the input entry is V2, only the current V2 launch is searched.
If the input entry is V1, only the current measure and layer is searched.

@ entry (FCNoteEntry) the entry to process
: (FCNoteEntry) the next entry or `nil` in none
]]
function note_entry.get_next_same_v(entry)
    local next_entry = entry:Next()
    if entry.Voice2 then
        if (nil ~= next_entry) and next_entry.Voice2 then
            return next_entry
        end
        return nil
    end
    if entry.Voice2Launch then
        while (nil ~= next_entry) and next_entry.Voice2 do
            next_entry = next_entry:Next()
        end
    end
    return next_entry
end

--[[
% hide_stem

Hides the stem of the entry by replacing it with Shape 0.

@ entry (FCNoteEntry) the entry to process
]]
function note_entry.hide_stem(entry)
    local stem = finale.FCCustomStemMod()
    stem:SetNoteEntry(entry)
    stem:UseUpStemData(entry:CalcStemUp())
    if stem:LoadFirst() then
        stem.ShapeID = 0
        stem:Save()
    else
        stem.ShapeID = 0
        stem:SaveNew()
    end
end



--[[
$module Expression
]] --
local expression = {}

--[[
$module Library
]] --
local library = {}

--[[
% finale_version

Returns a raw Finale version from major, minor, and (optional) build parameters. For 32-bit Finale
this is the internal major Finale version, not the year.

@ major (number) Major Finale version
@ minor (number) Minor Finale version
@ [build] (number) zero if omitted
: (number)
]]
function library.finale_version(major, minor, build)
    local retval = bit32.bor(bit32.lshift(math.floor(major), 24), bit32.lshift(math.floor(minor), 20))
    if build then
        retval = bit32.bor(retval, math.floor(build))
    end
    return retval
end

--[[
% group_overlaps_region

Returns true if the input staff group overlaps with the input music region, otherwise false.

@ staff_group (FCGroup)
@ region (FCMusicRegion)
: (boolean)
]]
function library.group_overlaps_region(staff_group, region)
    if region:IsFullDocumentSpan() then
        return true
    end
    local staff_exists = false
    local sys_staves = finale.FCSystemStaves()
    sys_staves:LoadAllForRegion(region)
    for sys_staff in each(sys_staves) do
        if staff_group:ContainsStaff(sys_staff:GetStaff()) then
            staff_exists = true
            break
        end
    end
    if not staff_exists then
        return false
    end
    if (staff_group.StartMeasure > region.EndMeasure) or (staff_group.EndMeasure < region.StartMeasure) then
        return false
    end
    return true
end

--[[
% group_is_contained_in_region

Returns true if the entire input staff group is contained within the input music region.
If the start or end staff are not visible in the region, it returns false.

@ staff_group (FCGroup)
@ region (FCMusicRegion)
: (boolean)
]]
function library.group_is_contained_in_region(staff_group, region)
    if not region:IsStaffIncluded(staff_group.StartStaff) then
        return false
    end
    if not region:IsStaffIncluded(staff_group.EndStaff) then
        return false
    end
    return true
end

--[[
% staff_group_is_multistaff_instrument

Returns true if the entire input staff group is a multistaff instrument.

@ staff_group (FCGroup)
: (boolean)
]]
function library.staff_group_is_multistaff_instrument(staff_group)
    local multistaff_instruments = finale.FCMultiStaffInstruments()
    multistaff_instruments:LoadAll()
    for inst in each(multistaff_instruments) do
        if inst:ContainsStaff(staff_group.StartStaff) and (inst.GroupID == staff_group:GetItemID()) then
            return true
        end
    end
    return false
end

--[[
% get_selected_region_or_whole_doc

Returns a region that contains the selected region if there is a selection or the whole document if there isn't.
SIDE-EFFECT WARNING: If there is no selected region, this function also changes finenv.Region() to the whole document.

: (FCMusicRegion)
]]
function library.get_selected_region_or_whole_doc()
    local sel_region = finenv.Region()
    if sel_region:IsEmpty() then
        sel_region:SetFullDocument()
    end
    return sel_region
end

--[[
% get_first_cell_on_or_after_page

Returns the first FCCell at the top of the input page. If the page is blank, it returns the first cell after the input page.

@ page_num (number)
: (FCCell)
]]
function library.get_first_cell_on_or_after_page(page_num)
    local curr_page_num = page_num
    local curr_page = finale.FCPage()
    local got1 = false
    -- skip over any blank pages
    while curr_page:Load(curr_page_num) do
        if curr_page:GetFirstSystem() > 0 then
            got1 = true
            break
        end
        curr_page_num = curr_page_num + 1
    end
    if got1 then
        local staff_sys = finale.FCStaffSystem()
        staff_sys:Load(curr_page:GetFirstSystem())
        return finale.FCCell(staff_sys.FirstMeasure, staff_sys.TopStaff)
    end
    -- if we got here there were nothing but blank pages left at the end
    local end_region = finale.FCMusicRegion()
    end_region:SetFullDocument()
    return finale.FCCell(end_region.EndMeasure, end_region.EndStaff)
end

--[[
% get_top_left_visible_cell

Returns the topmost, leftmost visible FCCell on the screen, or the closest possible estimate of it.

: (FCCell)
]]
function library.get_top_left_visible_cell()
    if not finenv.UI():IsPageView() then
        local all_region = finale.FCMusicRegion()
        all_region:SetFullDocument()
        return finale.FCCell(finenv.UI():GetCurrentMeasure(), all_region.StartStaff)
    end
    return library.get_first_cell_on_or_after_page(finenv.UI():GetCurrentPage())
end

--[[
% get_top_left_selected_or_visible_cell

If there is a selection, returns the topmost, leftmost cell in the selected region.
Otherwise returns the best estimate for the topmost, leftmost currently visible cell.

: (FCCell)
]]
function library.get_top_left_selected_or_visible_cell()
    local sel_region = finenv.Region()
    if not sel_region:IsEmpty() then
        return finale.FCCell(sel_region.StartMeasure, sel_region.StartStaff)
    end
    return library.get_top_left_visible_cell()
end

--[[
% is_default_measure_number_visible_on_cell

Returns true if measure numbers for the input region are visible on the input cell for the staff system.

@ meas_num_region (FCMeasureNumberRegion)
@ cell (FCCell)
@ staff_system (FCStaffSystem)
@ current_is_part (boolean) true if the current view is a linked part, otherwise false
: (boolean)
]]
function library.is_default_measure_number_visible_on_cell(meas_num_region, cell, staff_system, current_is_part)
    local staff = finale.FCCurrentStaffSpec()
    if not staff:LoadForCell(cell, 0) then
        return false
    end
    if meas_num_region:GetShowOnTopStaff() and (cell.Staff == staff_system.TopStaff) then
        return true
    end
    if meas_num_region:GetShowOnBottomStaff() and (cell.Staff == staff_system:CalcBottomStaff()) then
        return true
    end
    if staff.ShowMeasureNumbers then
        return not meas_num_region:GetExcludeOtherStaves(current_is_part)
    end
    return false
end

--[[
% is_default_number_visible_and_left_aligned

Returns true if measure number for the input cell is visible and left-aligned.

@ meas_num_region (FCMeasureNumberRegion)
@ cell (FCCell)
@ system (FCStaffSystem)
@ current_is_part (boolean) true if the current view is a linked part, otherwise false
@ is_for_multimeasure_rest (boolean) true if the current cell starts a multimeasure rest
: (boolean)
]]
function library.is_default_number_visible_and_left_aligned(meas_num_region, cell, system, current_is_part,
                                                            is_for_multimeasure_rest)
    if meas_num_region.UseScoreInfoForParts then
        current_is_part = false
    end
    if is_for_multimeasure_rest and meas_num_region:GetShowOnMultiMeasureRests(current_is_part) then
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetMultiMeasureAlignment(current_is_part)) then
            return false
        end
    elseif (cell.Measure == system.FirstMeasure) then
        if not meas_num_region:GetShowOnSystemStart() then
            return false
        end
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetStartAlignment(current_is_part)) then
            return false
        end
    else
        if not meas_num_region:GetShowMultiples(current_is_part) then
            return false
        end
        if (finale.MNALIGN_LEFT ~= meas_num_region:GetMultipleAlignment(current_is_part)) then
            return false
        end
    end
    return library.is_default_measure_number_visible_on_cell(meas_num_region, cell, system, current_is_part)
end

--[[
% update_layout

Updates the page layout.

@ [from_page] (number) page to update from, defaults to 1
@ [unfreeze_measures] (boolean) defaults to false
]]
function library.update_layout(from_page, unfreeze_measures)
    from_page = from_page or 1
    unfreeze_measures = unfreeze_measures or false
    local page = finale.FCPage()
    if page:Load(from_page) then
        page:UpdateLayout(unfreeze_measures)
    end
end

--[[
% get_current_part

Returns the currently selected part or score.

: (FCPart)
]]
function library.get_current_part()
    local part = finale.FCPart(finale.PARTID_CURRENT)
    part:Load(part.ID)
    return part
end

--[[
% get_page_format_prefs

Returns the default page format prefs for score or parts based on which is currently selected.

: (FCPageFormatPrefs)
]]
function library.get_page_format_prefs()
    local current_part = library.get_current_part()
    local page_format_prefs = finale.FCPageFormatPrefs()
    local success = false
    if current_part:IsScore() then
        success = page_format_prefs:LoadScore()
    else
        success = page_format_prefs:LoadParts()
    end
    return page_format_prefs, success
end

local calc_smufl_directory = function(for_user)
    local is_on_windows = finenv.UI():IsOnWindows()
    local do_getenv = function (win_var, mac_var)
        if finenv.UI():IsOnWindows() then
            return win_var and os.getenv(win_var) or ""
        else
            return mac_var and os.getenv(mac_var) or ""
        end
    end
    local smufl_directory = for_user and do_getenv("LOCALAPPDATA", "HOME") or do_getenv("COMMONPROGRAMFILES")
    if not is_on_windows then
        smufl_directory = smufl_directory .. "/Library/Application Support"
    end
    smufl_directory = smufl_directory .. "/SMuFL/Fonts/"
    return smufl_directory
end

--[[
% get_smufl_font_list

Returns table of installed SMuFL font names by searching the directory that contains
the .json files for each font. The table is in the format:

```lua
<font-name> = "user" | "system"
```

: (table) an table with SMuFL font names as keys and values "user" or "system"
]]

function library.get_smufl_font_list()
    local font_names = {}
    local add_to_table = function(for_user)
        local smufl_directory = calc_smufl_directory(for_user)
        local get_dirs = function()
            if finenv.UI():IsOnWindows() then
                return io.popen('dir "'..smufl_directory..'" /b /ad')
            else
                return io.popen('ls "'..smufl_directory..'"')
            end
        end
        local is_font_available = function(dir)
            local fc_dir = finale.FCString()
            fc_dir.LuaString = dir
            return finenv.UI():IsFontAvailable(fc_dir)
        end
        for dir in get_dirs():lines() do
            if not dir:find("%.") then
                dir = dir:gsub(" Bold", "")
                dir = dir:gsub(" Italic", "")
                local fc_dir = finale.FCString()
                fc_dir.LuaString = dir
                if font_names[dir] or is_font_available(dir) then
                    font_names[dir] = for_user and "user" or "system"
                end
            end
        end
    end
    add_to_table(true)
    add_to_table(false)
    return font_names
end

--[[
% get_smufl_metadata_file

@ [font_info] (FCFontInfo) if non-nil, the font to search for; if nil, search for the Default Music Font
: (file handle|nil)
]]
function library.get_smufl_metadata_file(font_info)
    if not font_info then
        font_info = finale.FCFontInfo()
        font_info:LoadFontPrefs(finale.FONTPREF_MUSIC)
    end

    local try_prefix = function(prefix, font_info)
        local file_path = prefix .. font_info.Name .. "/" .. font_info.Name .. ".json"
        return io.open(file_path, "r")
    end

    local user_file = try_prefix(calc_smufl_directory(true), font_info)
    if user_file then
        return user_file
    end

    return try_prefix(calc_smufl_directory(false), font_info)
end

--[[
% is_font_smufl_font

@ [font_info] (FCFontInfo) if non-nil, the font to check; if nil, check the Default Music Font
: (boolean)
]]
function library.is_font_smufl_font(font_info)
    if not font_info then
        font_info = finale.FCFontInfo()
        font_info:LoadFontPrefs(finale.FONTPREF_MUSIC)
    end

    if finenv.RawFinaleVersion >= library.finale_version(27, 1) then
        if nil ~= font_info.IsSMuFLFont then -- if this version of the lua interpreter has the IsSMuFLFont property (i.e., RGP Lua 0.59+)
            return font_info.IsSMuFLFont
        end
    end

    local smufl_metadata_file = library.get_smufl_metadata_file(font_info)
    if nil ~= smufl_metadata_file then
        io.close(smufl_metadata_file)
        return true
    end
    return false
end

--[[
% simple_input

Creates a simple dialog box with a single 'edit' field for entering values into a script, similar to the old UserValueInput command. Will automatically resize the width to accomodate longer strings.

@ [title] (string) the title of the input dialog box
@ [text] (string) descriptive text above the edit field
: string
]]
function library.simple_input(title, text)
    local return_value = finale.FCString()
    return_value.LuaString = ""
    local str = finale.FCString()
    local min_width = 160
    --
    function format_ctrl(ctrl, h, w, st)
        ctrl:SetHeight(h)
        ctrl:SetWidth(w)
        str.LuaString = st
        ctrl:SetText(str)
    end -- function format_ctrl
    --
    title_width = string.len(title) * 6 + 54
    if title_width > min_width then
        min_width = title_width
    end
    text_width = string.len(text) * 6
    if text_width > min_width then
        min_width = text_width
    end
    --
    str.LuaString = title
    local dialog = finale.FCCustomLuaWindow()
    dialog:SetTitle(str)
    local descr = dialog:CreateStatic(0, 0)
    format_ctrl(descr, 16, min_width, text)
    local input = dialog:CreateEdit(0, 20)
    format_ctrl(input, 20, min_width, "") -- edit "" for defualt value
    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    --
    function callback(ctrl)
    end -- callback
    --
    dialog:RegisterHandleCommand(callback)
    --
    if dialog:ExecuteModal(nil) == finale.EXECMODAL_OK then
        return_value.LuaString = input:GetText(return_value)
        -- print(return_value.LuaString)
        return return_value.LuaString
        -- OK button was pressed
    end
end -- function simple_input

--[[
% is_finale_object

Attempts to determine if an object is a Finale object through ducktyping

@ object (__FCBase)
: (bool)
]]
function library.is_finale_object(object)
    -- All finale objects implement __FCBase, so just check for the existence of __FCBase methods
    return object and type(object) == "userdata" and object.ClassName and object.GetClassID and true or false
end

--[[
% system_indent_set_to_prefs

Sets the system to match the indentation in the page preferences currently in effect. (For score or part.)
The page preferences may be provided optionally to avoid loading them for each call.

@ system (FCStaffSystem)
@ [page_format_prefs] (FCPageFormatPrefs) page format preferences to use, if supplied.
: (boolean) `true` if the system was successfully updated.
]]
function library.system_indent_set_to_prefs(system, page_format_prefs)
    page_format_prefs = page_format_prefs or library.get_page_format_prefs()
    local first_meas = finale.FCMeasure()
    local is_first_system = (system.FirstMeasure == 1)
    if (not is_first_system) and first_meas:Load(system.FirstMeasure) then
        if first_meas.ShowFullNames then
            is_first_system = true
        end
    end
    if is_first_system and page_format_prefs.UseFirstSystemMargins then
        system.LeftMargin = page_format_prefs.FirstSystemLeft
    else
        system.LeftMargin = page_format_prefs.SystemLeft
    end
    return system:Save()
end


--[[
% calc_script_name

Returns the running script name, with or without extension.

@ [include_extension] (boolean) Whether to include the file extension in the return value: `false` if omitted
: (string) The name of the current running script.
]]
function library.calc_script_name(include_extension)
    local fc_string = finale.FCString()
    if finenv.RunningLuaFilePath then
        -- Use finenv.RunningLuaFilePath() if available because it doesn't ever get overwritten when retaining state.
        fc_string.LuaString = finenv.RunningLuaFilePath()
    else
        -- This code path is only taken by JW Lua (and very early versions of RGP Lua).
        -- SetRunningLuaFilePath is not reliable when retaining state, so later versions use finenv.RunningLuaFilePath.
        fc_string:SetRunningLuaFilePath()
    end
    local filename_string = finale.FCString()
    fc_string:SplitToPathAndFile(nil, filename_string)
    local retval = filename_string.LuaString
    if not include_extension then
        retval = retval:match("(.+)%..+")
        if not retval or retval == "" then
            retval = filename_string.LuaString
        end
    end
    return retval
end




--[[
$module Note Entry
]] --
local note_entry = {}

--[[
% get_music_region

Returns an intance of `FCMusicRegion` that corresponds to the metric location of the input note entry.

@ entry (FCNoteEntry)
: (FCMusicRegion)
]]
function note_entry.get_music_region(entry)
    local exp_region = finale.FCMusicRegion()
    exp_region:SetCurrentSelection() -- called to match the selected IU list (e.g., if using Staff Sets)
    exp_region.StartStaff = entry.Staff
    exp_region.EndStaff = entry.Staff
    exp_region.StartMeasure = entry.Measure
    exp_region.EndMeasure = entry.Measure
    exp_region.StartMeasurePos = entry.MeasurePos
    exp_region.EndMeasurePos = entry.MeasurePos
    return exp_region
end

-- entry_metrics can be omitted, in which case they are constructed and released here
-- return entry_metrics, loaded_here
local use_or_get_passed_in_entry_metrics = function(entry, entry_metrics)
    if entry_metrics then
        return entry_metrics, false
    end
    entry_metrics = finale.FCEntryMetrics()
    if entry_metrics:Load(entry) then
        return entry_metrics, true
    end
    return nil, false
end

--[[
% get_evpu_notehead_height

Returns the calculated height of the notehead rectangle.

@ entry (FCNoteEntry)

: (number) the EVPU height
]]
function note_entry.get_evpu_notehead_height(entry)
    local highest_note = entry:CalcHighestNote(nil)
    local lowest_note = entry:CalcLowestNote(nil)
    local evpu_height = (2 + highest_note:CalcStaffPosition() - lowest_note:CalcStaffPosition()) * 12 -- 12 evpu per staff step; add 2 staff steps to accommodate for notehead height at top and bottom
    return evpu_height
end

--[[
% get_top_note_position

Returns the vertical page coordinate of the top of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_top_note_position(entry, entry_metrics)
    local retval = -math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if not entry:CalcStemUp() then
        retval = entry_metrics.TopPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling * evpu_height) / 10000) + 0.5)
            retval = entry_metrics.BottomPosition + scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% get_bottom_note_position

Returns the vertical page coordinate of the bottom of the notehead rectangle, not including the stem.

@ entry (FCNoteEntry)
@ [entry_metrics] (FCEntryMetrics) entry metrics may be supplied by the caller if they are already available
: (number)
]]
function note_entry.get_bottom_note_position(entry, entry_metrics)
    local retval = math.huge
    local loaded_here = false
    entry_metrics, loaded_here = use_or_get_passed_in_entry_metrics(entry, entry_metrics)
    if nil == entry_metrics then
        return retval
    end
    if entry:CalcStemUp() then
        retval = entry_metrics.BottomPosition
    else
        local cell_metrics = finale.FCCell(entry.Measure, entry.Staff):CreateCellMetrics()
        if nil ~= cell_metrics then
            local evpu_height = note_entry.get_evpu_notehead_height(entry)
            local scaled_height = math.floor(((cell_metrics.StaffScaling * evpu_height) / 10000) + 0.5)
            retval = entry_metrics.TopPosition - scaled_height
            cell_metrics:FreeMetrics()
        end
    end
    if loaded_here then
        entry_metrics:FreeMetrics()
    end
    return retval
end

--[[
% calc_widths

Get the widest left-side notehead width and widest right-side notehead width.

@ entry (FCNoteEntry)
: (number, number) widest left-side notehead width and widest right-side notehead width
]]
function note_entry.calc_widths(entry)
    local left_width = 0
    local right_width = 0
    for note in each(entry) do
        local note_width = note:CalcNoteheadWidth()
        if note_width > 0 then
            if note:CalcRightsidePlacement() then
                if note_width > right_width then
                    right_width = note_width
                end
            else
                if note_width > left_width then
                    left_width = note_width
                end
            end
        end
    end
    return left_width, right_width
end

-- These functions return the offset for an expression handle.
-- Expression handles are vertical when they are left-aligned
-- with the primary notehead rectangle.

--[[
% calc_left_of_all_noteheads

Calculates the handle offset for an expression with "Left of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_all_noteheads(entry)
    if entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return -left
end

--[[
% calc_left_of_primary_notehead

Calculates the handle offset for an expression with "Left of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_left_of_primary_notehead(entry)
    return 0
end

--[[
% calc_center_of_all_noteheads

Calculates the handle offset for an expression with "Center of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    local width_centered = (left + right) / 2
    if not entry:CalcStemUp() then
        width_centered = width_centered - left
    end
    return width_centered
end

--[[
% calc_center_of_primary_notehead

Calculates the handle offset for an expression with "Center of Primary Notehead" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_center_of_primary_notehead(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left / 2
    end
    return right / 2
end

--[[
% calc_stem_offset

Calculates the offset of the stem from the left edge of the notehead rectangle. Eventually the PDK Framework may be able to provide this instead.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset of stem from the left edge of the notehead rectangle.
]]
function note_entry.calc_stem_offset(entry)
    if not entry:CalcStemUp() then
        return 0
    end
    local left, right = note_entry.calc_widths(entry)
    return left
end

--[[
% calc_right_of_all_noteheads

Calculates the handle offset for an expression with "Right of All Noteheads" horizontal positioning.

@ entry (FCNoteEntry) the entry to calculate from
: (number) offset from left side of primary notehead rectangle
]]
function note_entry.calc_right_of_all_noteheads(entry)
    local left, right = note_entry.calc_widths(entry)
    if entry:CalcStemUp() then
        return left + right
    end
    return right
end

--[[
% calc_note_at_index

This function assumes `for note in each(note_entry)` always iterates in the same direction.
(Knowing how the Finale PDK works, it probably iterates from bottom to top note.)
Currently the PDK Framework does not seem to offer a better option.

@ entry (FCNoteEntry)
@ note_index (number) the zero-based index
]]
function note_entry.calc_note_at_index(entry, note_index)
    local x = 0
    for note in each(entry) do
        if x == note_index then
            return note
        end
        x = x + 1
    end
    return nil
end

--[[
% stem_sign

This is useful for many x,y positioning fields in Finale that mirror +/-
based on stem direction.

@ entry (FCNoteEntry)
: (number) 1 if upstem, -1 otherwise
]]
function note_entry.stem_sign(entry)
    if entry:CalcStemUp() then
        return 1
    end
    return -1
end

--[[
% duplicate_note

@ note (FCNote)
: (FCNote | nil) reference to added FCNote or `nil` if not success
]]
function note_entry.duplicate_note(note)
    local new_note = note.Entry:AddNewNote()
    if nil ~= new_note then
        new_note.Displacement = note.Displacement
        new_note.RaiseLower = note.RaiseLower
        new_note.Tie = note.Tie
        new_note.TieBackwards = note.TieBackwards
    end
    return new_note
end

--[[
% delete_note

Removes the specified FCNote from its associated FCNoteEntry.

@ note (FCNote)
: (boolean) true if success
]]
function note_entry.delete_note(note)
    local entry = note.Entry
    if nil == entry then
        return false
    end

    -- attempt to delete all associated entry-detail mods, but ignore any failures
    finale.FCAccidentalMod():EraseAt(note)
    finale.FCCrossStaffMod():EraseAt(note)
    finale.FCDotMod():EraseAt(note)
    finale.FCNoteheadMod():EraseAt(note)
    finale.FCPercussionNoteMod():EraseAt(note)
    finale.FCTablatureNoteMod():EraseAt(note)
    if finale.FCTieMod then -- added in RGP Lua 0.62
        finale.FCTieMod(finale.TIEMODTYPE_TIESTART):EraseAt(note)
        finale.FCTieMod(finale.TIEMODTYPE_TIEEND):EraseAt(note)
    end

    return entry:DeleteNote(note)
end

--[[
% calc_pitch_string

Calculates the pitch string of a note for display purposes.

@ note (FCNote)
: (string) display string for note
]]

function note_entry.calc_pitch_string(note)
    local pitch_string = finale.FCString()
    local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
    local key_signature = cell:GetKeySignature()
    note:GetString(pitch_string, key_signature, false, false)
    return pitch_string
end

--[[
% calc_spans_number_of_octaves

Calculates the numer of octaves spanned by a chord (considering only staff positions, not accidentals).

@ entry (FCNoteEntry) the entry to calculate from
: (number) of octaves spanned
]]
function note_entry.calc_spans_number_of_octaves(entry)
    local top_note = entry:CalcHighestNote(nil)
    local bottom_note = entry:CalcLowestNote(nil)
    local displacement_diff = top_note.Displacement - bottom_note.Displacement
    local num_octaves = math.ceil(displacement_diff / 7)
    return num_octaves
end

--[[
% add_augmentation_dot

Adds an augentation dot to the entry. This works even if the entry already has one or more augmentation dots.

@ entry (FCNoteEntry) the entry to which to add the augmentation dot
]]
function note_entry.add_augmentation_dot(entry)
    -- entry.Duration = entry.Duration | (entry.Duration >> 1) -- For Lua 5.3 and higher
    entry.Duration = bit32.bor(entry.Duration, bit32.rshift(entry.Duration, 1))
end

--[[
% get_next_same_v

Returns the next entry in the same V1 or V2 as the input entry.
If the input entry is V2, only the current V2 launch is searched.
If the input entry is V1, only the current measure and layer is searched.

@ entry (FCNoteEntry) the entry to process
: (FCNoteEntry) the next entry or `nil` in none
]]
function note_entry.get_next_same_v(entry)
    local next_entry = entry:Next()
    if entry.Voice2 then
        if (nil ~= next_entry) and next_entry.Voice2 then
            return next_entry
        end
        return nil
    end
    if entry.Voice2Launch then
        while (nil ~= next_entry) and next_entry.Voice2 do
            next_entry = next_entry:Next()
        end
    end
    return next_entry
end

--[[
% hide_stem

Hides the stem of the entry by replacing it with Shape 0.

@ entry (FCNoteEntry) the entry to process
]]
function note_entry.hide_stem(entry)
    local stem = finale.FCCustomStemMod()
    stem:SetNoteEntry(entry)
    stem:UseUpStemData(entry:CalcStemUp())
    if stem:LoadFirst() then
        stem.ShapeID = 0
        stem:Save()
    else
        stem.ShapeID = 0
        stem:SaveNew()
    end
end



--[[
$module Enigma String
]] --
local enigma_string = {}
local starts_with_font_command = function(string)
    local text_cmds = {"^font", "^Font", "^fontMus", "^fontTxt", "^fontNum", "^size", "^nfx"}
    for i, text_cmd in ipairs(text_cmds) do
        if string:StartsWith(text_cmd) then
            return true
        end
    end
    return false
end

--[[
The following implements a hypothetical FCString.TrimFirstEnigmaFontTags() function
that would preferably be in the PDK Framework. Trimming only first allows us to
preserve style changes within the rest of the string, such as changes from plain to
italic. Ultimately this seems more useful than trimming out all font tags.
If the PDK Framework is ever changed, it might be even better to create replace font
functions that can replace only font, only size, only style, or all three together.
]]

--[[
% trim_first_enigma_font_tags

Trims the first font tags and returns the result as an instance of FCFontInfo.

@ string (FCString) this is both the input and the trimmed output result
: (FCFontInfo | nil) the first font info that was stripped or `nil` if none
]]
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
        string:DeleteCharactersAt(0, end_of_tag + 1)
        found_tag = true
    end
    if found_tag then
        return font_info
    end
    return nil
end

--[[
% change_first_string_font

Replaces the first enigma font tags of the input enigma string.

@ string (FCString) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
: (boolean) true if success
]]
function enigma_string.change_first_string_font(string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    local current_font_info = enigma_string.trim_first_enigma_font_tags(string)
    if (current_font_info == nil) or not font_info:IsIdenticalTo(current_font_info) then
        final_text:AppendString(string)
        string:SetString(final_text)
        return true
    end
    return false
end

--[[
% change_first_text_block_font

Replaces the first enigma font tags of input text block.

@ text_block (FCTextBlock) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
: (boolean) true if success
]]
function enigma_string.change_first_text_block_font(text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    if enigma_string.change_first_string_font(new_text, font_info) then
        text_block:SaveRawTextString(new_text)
        return true
    end
    return false
end

-- These implement a complete font replacement using the PDK Framework's
-- built-in TrimEnigmaFontTags() function.

--[[
% change_string_font

Changes the entire enigma string to have the input font info.

@ string (FCString) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
]]
function enigma_string.change_string_font(string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    string:TrimEnigmaFontTags()
    final_text:AppendString(string)
    string:SetString(final_text)
end

--[[
% change_text_block_font

Changes the entire text block to have the input font info.

@ text_block (FCTextBlock) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
]]
function enigma_string.change_text_block_font(text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    enigma_string.change_string_font(new_text, font_info)
    text_block:SaveRawTextString(new_text)
end

--[[
% remove_inserts

Removes text inserts other than font commands and replaces them with

@ fcstring (FCString) this is both the input and the modified output result
@ replace_with_generic (boolean) if true, replace the insert with the text of the enigma command
]]
function enigma_string.remove_inserts(fcstring, replace_with_generic)
    -- so far this just supports page-level inserts. if this ever needs to work with expressions, we'll need to
    -- add the last three items in the (Finale 26) text insert menu, which are playback inserts not available to page text
    local text_cmds = {
        "^arranger", "^composer", "^copyright", "^date", "^description", "^fdate", "^filename", "^lyricist", "^page",
        "^partname", "^perftime", "^subtitle", "^time", "^title", "^totpages",
    }
    local lua_string = fcstring.LuaString
    for i, text_cmd in ipairs(text_cmds) do
        local starts_at = string.find(lua_string, text_cmd, 1, true) -- true: do a plain search
        while nil ~= starts_at do
            local replace_with = ""
            if replace_with_generic then
                replace_with = string.sub(text_cmd, 2)
            end
            local after_text_at = starts_at + string.len(text_cmd)
            local next_at = string.find(lua_string, ")", after_text_at, true)
            if nil ~= next_at then
                next_at = next_at + 1
            else
                next_at = starts_at
            end
            lua_string = string.sub(lua_string, 1, starts_at - 1) .. replace_with .. string.sub(lua_string, next_at)
            starts_at = string.find(lua_string, text_cmd, 1, true)
        end
    end
    fcstring.LuaString = lua_string
end

--[[
% expand_value_tag

Expands the value tag to the input value_num.

@ fcstring (FCString) this is both the input and the modified output result
@ value_num (number) the value number to replace the tag with
]]
function enigma_string.expand_value_tag(fcstring, value_num)
    value_num = math.floor(value_num + 0.5) -- in case value_num is not an integer
    fcstring.LuaString = fcstring.LuaString:gsub("%^value%(%)", tostring(value_num))
end

--[[
% calc_text_advance_width

Calculates the advance width of the input string taking into account all font and style changes within the string.

@ inp_string (FCString) this is an input-only value and is not modified
: (number) the width of the string
]]
function enigma_string.calc_text_advance_width(inp_string)
    local accumulated_string = ""
    local accumulated_width = 0
    local enigma_strings = inp_string:CreateEnigmaStrings(true) -- true: include non-commands
    for str in each(enigma_strings) do
        accumulated_string = accumulated_string .. str.LuaString
        if string.sub(str.LuaString, 1, 1) ~= "^" then -- if this string segment is not a command, calculate its width
            local fcstring = finale.FCString()
            local text_met = finale.FCTextMetrics()
            fcstring.LuaString = accumulated_string
            local font_info = fcstring:CreateLastFontInfo()
            fcstring.LuaString = str.LuaString
            fcstring:TrimEnigmaTags()
            text_met:LoadString(fcstring, font_info, 100)
            accumulated_width = accumulated_width + text_met:GetAdvanceWidthEVPUs()
        end
    end
    return accumulated_width
end




--[[
% get_music_region

Returns a music region corresponding to the input expression assignment.

@ exp_assign (FCExpression)
: (FCMusicRegion)
]]
function expression.get_music_region(exp_assign)
    if not exp_assign:IsSingleStaffAssigned() then
        return nil
    end
    local exp_region = finale.FCMusicRegion()
    exp_region:SetCurrentSelection() -- called to match the selected IU list (e.g., if using Staff Sets)
    exp_region.StartStaff = exp_assign.Staff
    exp_region.EndStaff = exp_assign.Staff
    exp_region.StartMeasure = exp_assign.Measure
    exp_region.EndMeasure = exp_assign.Measure
    exp_region.StartMeasurePos = exp_assign.MeasurePos
    exp_region.EndMeasurePos = exp_assign.MeasurePos
    return exp_region
end

--[[
% get_associated_entry

Returns the note entry associated with the input expression assignment, if any.

@ exp_assign (FCExpression)
: (FCNoteEntry) associated entry or nil if none
]]
function expression.get_associated_entry(exp_assign)
    local exp_region = expression.get_music_region(exp_assign)
    if nil == exp_region then
        return nil
    end
    for entry in eachentry(exp_region) do
        if (0 == exp_assign.LayerAssignment) or (entry.LayerNumber == exp_assign.LayerAssignment) then
            if not entry:GetGraceNote() then -- for now skip all grace notes: we can revisit this if need be
                return entry
            end
        end
    end
    return nil
end

--[[
% calc_handle_offset_for_smart_shape

Returns the horizontal EVPU offset for a smart shape endpoint to align exactly with the handle of the input expression, given that they both have the same EDU position.

@ exp_assign (FCExpression)
: (number)
]]
function expression.calc_handle_offset_for_smart_shape(exp_assign)
    local manual_horizontal = exp_assign.HorizontalPos
    local def_horizontal = 0
    local alignment_offset = 0
    local exp_def = exp_assign:CreateTextExpressionDef()
    if nil ~= exp_def then
        def_horizontal = exp_def.HorizontalOffset
    end
    local exp_entry = expression.get_associated_entry(exp_assign)
    if (nil ~= exp_entry) and (nil ~= exp_def) then
        if finale.ALIGNHORIZ_LEFTOFALLNOTEHEAD == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_left_of_all_noteheads(exp_entry)
        elseif finale.ALIGNHORIZ_LEFTOFPRIMARYNOTEHEAD == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_left_of_primary_notehead(exp_entry)
        elseif finale.ALIGNHORIZ_STEM == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_stem_offset(exp_entry)
        elseif finale.ALIGNHORIZ_CENTERPRIMARYNOTEHEAD == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_center_of_primary_notehead(exp_entry)
        elseif finale.ALIGNHORIZ_CENTERALLNOTEHEADS == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_center_of_all_noteheads(exp_entry)
        elseif finale.ALIGNHORIZ_RIGHTALLNOTEHEADS == exp_def.HorizontalAlignmentPoint then
            alignment_offset = note_entry.calc_right_of_all_noteheads(exp_entry)
        end
    end
    return (manual_horizontal + def_horizontal + alignment_offset)
end

--[[
% calc_text_width

Returns the text advance width of the input expression definition.

@ expression_def (FCTextExpessionDef)
@ [expand_tags] (boolean) defaults to false, currently only supports `^value()`
: (number)
]]
function expression.calc_text_width(expression_def, expand_tags)
    expand_tags = expand_tags or false
    local fcstring = expression_def:CreateTextString()
    if expand_tags then
        enigma_string.expand_value_tag(fcstring, expression_def:GetPlaybackTempoValue())
    end
    local retval = enigma_string.calc_text_advance_width(fcstring)
    return retval
end

--[[
% is_for_current_part

Returns true if the expression assignment is assigned to the current part or score.

@ exp_assign (FCExpression)
@ [current_part] (FCPart) defaults to current part, but it can be supplied if the caller has already calculated it.
: (boolean)
]]
function expression.is_for_current_part(exp_assign, current_part)
    current_part = current_part or library.get_current_part()
    if current_part:IsScore() and exp_assign.ScoreAssignment then
        return true
    elseif current_part:IsPart() and exp_assign.PartAssignment then
        return true
    end
    return false
end



--[[
$module Enigma String
]] --
local enigma_string = {}
local starts_with_font_command = function(string)
    local text_cmds = {"^font", "^Font", "^fontMus", "^fontTxt", "^fontNum", "^size", "^nfx"}
    for i, text_cmd in ipairs(text_cmds) do
        if string:StartsWith(text_cmd) then
            return true
        end
    end
    return false
end

--[[
The following implements a hypothetical FCString.TrimFirstEnigmaFontTags() function
that would preferably be in the PDK Framework. Trimming only first allows us to
preserve style changes within the rest of the string, such as changes from plain to
italic. Ultimately this seems more useful than trimming out all font tags.
If the PDK Framework is ever changed, it might be even better to create replace font
functions that can replace only font, only size, only style, or all three together.
]]

--[[
% trim_first_enigma_font_tags

Trims the first font tags and returns the result as an instance of FCFontInfo.

@ string (FCString) this is both the input and the trimmed output result
: (FCFontInfo | nil) the first font info that was stripped or `nil` if none
]]
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
        string:DeleteCharactersAt(0, end_of_tag + 1)
        found_tag = true
    end
    if found_tag then
        return font_info
    end
    return nil
end

--[[
% change_first_string_font

Replaces the first enigma font tags of the input enigma string.

@ string (FCString) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
: (boolean) true if success
]]
function enigma_string.change_first_string_font(string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    local current_font_info = enigma_string.trim_first_enigma_font_tags(string)
    if (current_font_info == nil) or not font_info:IsIdenticalTo(current_font_info) then
        final_text:AppendString(string)
        string:SetString(final_text)
        return true
    end
    return false
end

--[[
% change_first_text_block_font

Replaces the first enigma font tags of input text block.

@ text_block (FCTextBlock) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
: (boolean) true if success
]]
function enigma_string.change_first_text_block_font(text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    if enigma_string.change_first_string_font(new_text, font_info) then
        text_block:SaveRawTextString(new_text)
        return true
    end
    return false
end

-- These implement a complete font replacement using the PDK Framework's
-- built-in TrimEnigmaFontTags() function.

--[[
% change_string_font

Changes the entire enigma string to have the input font info.

@ string (FCString) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
]]
function enigma_string.change_string_font(string, font_info)
    local final_text = font_info:CreateEnigmaString(nil)
    string:TrimEnigmaFontTags()
    final_text:AppendString(string)
    string:SetString(final_text)
end

--[[
% change_text_block_font

Changes the entire text block to have the input font info.

@ text_block (FCTextBlock) this is both the input and the modified output result
@ font_info (FCFontInfo) replacement font info
]]
function enigma_string.change_text_block_font(text_block, font_info)
    local new_text = text_block:CreateRawTextString()
    enigma_string.change_string_font(new_text, font_info)
    text_block:SaveRawTextString(new_text)
end

--[[
% remove_inserts

Removes text inserts other than font commands and replaces them with

@ fcstring (FCString) this is both the input and the modified output result
@ replace_with_generic (boolean) if true, replace the insert with the text of the enigma command
]]
function enigma_string.remove_inserts(fcstring, replace_with_generic)
    -- so far this just supports page-level inserts. if this ever needs to work with expressions, we'll need to
    -- add the last three items in the (Finale 26) text insert menu, which are playback inserts not available to page text
    local text_cmds = {
        "^arranger", "^composer", "^copyright", "^date", "^description", "^fdate", "^filename", "^lyricist", "^page",
        "^partname", "^perftime", "^subtitle", "^time", "^title", "^totpages",
    }
    local lua_string = fcstring.LuaString
    for i, text_cmd in ipairs(text_cmds) do
        local starts_at = string.find(lua_string, text_cmd, 1, true) -- true: do a plain search
        while nil ~= starts_at do
            local replace_with = ""
            if replace_with_generic then
                replace_with = string.sub(text_cmd, 2)
            end
            local after_text_at = starts_at + string.len(text_cmd)
            local next_at = string.find(lua_string, ")", after_text_at, true)
            if nil ~= next_at then
                next_at = next_at + 1
            else
                next_at = starts_at
            end
            lua_string = string.sub(lua_string, 1, starts_at - 1) .. replace_with .. string.sub(lua_string, next_at)
            starts_at = string.find(lua_string, text_cmd, 1, true)
        end
    end
    fcstring.LuaString = lua_string
end

--[[
% expand_value_tag

Expands the value tag to the input value_num.

@ fcstring (FCString) this is both the input and the modified output result
@ value_num (number) the value number to replace the tag with
]]
function enigma_string.expand_value_tag(fcstring, value_num)
    value_num = math.floor(value_num + 0.5) -- in case value_num is not an integer
    fcstring.LuaString = fcstring.LuaString:gsub("%^value%(%)", tostring(value_num))
end

--[[
% calc_text_advance_width

Calculates the advance width of the input string taking into account all font and style changes within the string.

@ inp_string (FCString) this is an input-only value and is not modified
: (number) the width of the string
]]
function enigma_string.calc_text_advance_width(inp_string)
    local accumulated_string = ""
    local accumulated_width = 0
    local enigma_strings = inp_string:CreateEnigmaStrings(true) -- true: include non-commands
    for str in each(enigma_strings) do
        accumulated_string = accumulated_string .. str.LuaString
        if string.sub(str.LuaString, 1, 1) ~= "^" then -- if this string segment is not a command, calculate its width
            local fcstring = finale.FCString()
            local text_met = finale.FCTextMetrics()
            fcstring.LuaString = accumulated_string
            local font_info = fcstring:CreateLastFontInfo()
            fcstring.LuaString = str.LuaString
            fcstring:TrimEnigmaTags()
            text_met:LoadString(fcstring, font_info, 100)
            accumulated_width = accumulated_width + text_met:GetAdvanceWidthEVPUs()
        end
    end
    return accumulated_width
end




local fcstr = function(str)
    return mixin.FCMString():SetLuaString(str)
end

function do_save_as_dialog(document)
    local path_name = finale.FCString()
    local file_name = finale.FCString()
    local file_path = finale.FCString()
    document:GetPath(file_path)
    file_path:SplitToPathAndFile(path_name, file_name)
    local full_file_name = file_name.LuaString
    local extension = mixin.FCMString()
                            :SetLuaString(file_name.LuaString)
                            :ExtractFileExtension()
    if extension.Length > 0 then
        file_name:TruncateAt(file_name:FindLast("."..extension.LuaString))
    end
    file_name:AppendLuaString(text_extension)
    local save_dialog = mixin.FCMFileSaveAsDialog(finenv.UI())
            :SetWindowTitle(fcstr("Save "..full_file_name.." As"))
            :AddFilter(fcstr("*"..text_extension), fcstr("Text File"))
            :SetInitFolder(path_name)
            :SetFileName(file_name)
    save_dialog:AssureFileExtension(text_extension)
    if not save_dialog:Execute() then
        return nil
    end
    local selected_file_name = finale.FCString()
    save_dialog:GetFileName(selected_file_name)
    return selected_file_name.LuaString
end

local smart_shape_codes = {
    [finale.SMARTSHAPE_SLURDOWN] = "SU",
    [finale.SMARTSHAPE_DIMINUENDO] = "DM",
    [finale.SMARTSHAPE_CRESCENDO] = "CR",
    [finale.SMARTSHAPE_OCTAVEDOWN ] = "8B",
    [finale.SMARTSHAPE_OCTAVEUP] = "8V",
    [finale.SMARTSHAPE_DASHLINEUP] = "DU",
    [finale.SMARTSHAPE_DASHLINEDOWN] = "DD",
    [finale.SMARTSHAPE_DASHCURVEDOWN] = "DCU",
    [finale.SMARTSHAPE_DASHCURVEUP] = "DCU",
    [finale.SMARTSHAPE_DASHLINE ] = "DL",
    [finale.SMARTSHAPE_SOLIDLINE] = "SL",
    [finale.SMARTSHAPE_SOLIDLINEDOWN] = "SLD",
    [finale.SMARTSHAPE_SOLIDLINEUP] = "SLU",
    [finale.SMARTSHAPE_SLURAUTO] = "SS",
    [finale.SMARTSHAPE_DASHCURVEAUTO] = "DC",
    [finale.SMARTSHAPE_TRILLEXT] = "TE",
    [finale.SMARTSHAPE_SOLIDLINEDOWN2] = "SLD2",
    [finale.SMARTSHAPE_SOLIDLINEUP2] = "SLU2",
    [finale.SMARTSHAPE_TWOOCTAVEDOWN] = "15B",
    [finale.SMARTSHAPE_TWOOCTAVEUP] = "15V",
    [finale.SMARTSHAPE_DASHLINEDOWN2] = "DLD2",
    [finale.SMARTSHAPE_DASHLINEUP2] = "DLU2",
    [finale.SMARTSHAPE_GLISSANDO] = "GL",
    [finale.SMARTSHAPE_TABSLIDE] = "TS",
    [finale.SMARTSHAPE_BEND_HAT] = "BH",
    [finale.SMARTSHAPE_BEND_CURVE] = "BC",
    [finale.SMARTSHAPE_CUSTOM] = "CU",
    [finale.SMARTSHAPE_SOLIDLINEUPLEFT] = "SLUL",
    [finale.SMARTSHAPE_SOLIDLINEDOWNLEFT] = "SLDL",
    [finale.SMARTSHAPE_DASHLINEUPLEFT ] = "DLUL",
    [finale.SMARTSHAPE_DASHLINEDOWNLEFT ] = "DLDL",
    [finale.SMARTSHAPE_SOLIDLINEUPDOWN ] = "SLUD",
    [finale.SMARTSHAPE_SOLIDLINEDOWNUP] = "SLDU",
    [finale.SMARTSHAPE_DASHLINEUPDOWN] = "DLUD",
    [finale.SMARTSHAPE_DASHLINEDOWNUP] = "DLDU",
    [finale.SMARTSHAPE_HYPHEN] = "HY",
    [finale.SMARTSHAPE_WORD_EXT] = "WE",
    [finale.SMARTSHAPE_DASHEDSLURDOWN] = "DSD",
    [finale.SMARTSHAPE_DASHEDSLURUP] = "DSU",
    [finale.SMARTSHAPE_DASHEDSLURAUTO] = "DS"
}

function get_smartshape_string(smart_shape, beg_mark, end_mark)
    local desc = smart_shape_codes[smart_shape.ShapeType]
    if not desc then
        return "S"..tostring(smart_shape.ShapeType)
    end
    if smart_shape.ShapeType == finale.SMARTSHAPE_CUSTOM then
        desc = desc .. tostring(smart_shape.LineID)
    end
    if end_mark then
        desc = "<-" .. desc
    end
    if beg_mark then
        desc = desc .. "->"
    end
    return desc
end

-- known_chars includes SMuFL characters and other non-ASCII characters that are known
-- to represent common articulations and dynamics
local known_chars = {
    [0xe4a0] = ">",  
    [0xe4a2] = ".",
}

function get_char_string(char)
    if known_chars[char] then
        return known_chars[char]
    end
    if char < 32 then
        return " "
    end
    return utf8.char(char)
end

function entry_string(entry)
    local retval = ""
    -- ToDo: write entry-attached items (articulations, lyrics done)
    local articulations = entry:CreateArticulations()
    for articulation in each(articulations) do
        local articulation_def = articulation:CreateArticulationDef()
        if articulation_def.MainSymbolIsShape then
            retval = retval .. " sa" .. tostring(articulation_def.MainSymbolShapeID)
        else
            retval = retval .. " " .. get_char_string(articulation_def.MainSymbolChar)
        end
    end
    local smart_shape_marks = finale.FCSmartShapeEntryMarks(entry)
    local already_processed = {}
    if smart_shape_marks:LoadAll() then
        for mark in each(smart_shape_marks) do
            if not already_processed[mark.ShapeNumber] then
                already_processed[mark.ShapeNumber] = true
                local beg_mark = mark:CalcLeftMark()
                local end_mark = mark:CalcRightMark()
                if beg_mark or end_mark then
                    local smart_shape = mark:CreateSmartShape()
                    if not smart_shape:CalcLyricBased() then
                        retval = retval .. " " .. get_smartshape_string(smart_shape, beg_mark, end_mark)
                    end
                end
            end
        end
    end
    if entry:IsRest() then
        retval = retval .. " RR"
    else
        for note_index = 0,entry.Count-1 do
            local note = entry:GetItemAt(note_index)
            retval = retval .. " "
            if note.TieBackwards then
                retval = retval .. "<-"
            end
            retval = retval .. note_entry.calc_pitch_string(note).LuaString
            if note.Tie then
                retval = retval .. "->"
            end
        end
    end
    for _, syllables in ipairs({finale.FCVerseSyllables(entry), finale.FCChorusSyllables(entry), finale.FCSectionSyllables(entry)}) do
        if syllables:LoadAll() then
            for syllable in each(syllables) do
                local syllable_text = finale.FCString()
                if syllable:GetText(syllable_text) then
                    syllable_text:TrimEnigmaTags()
                    retval = retval .. " " .. syllable_text.LuaString
                end
            end
        end
    end
    return retval
end

local get_edupos_table = function(measure_table, staff_number, edupos)
    if not measure_table[staff_number] then
        measure_table[staff_number] = {}
    end
    local staff_table = measure_table[staff_number]
    if not staff_table[edupos] then
        staff_table[edupos] = {}
    end
    return staff_table[edupos]
end

function create_measure_table(measure_region, measure)
    local measure_table = {}
    -- ToDo: chords
    local expression_assignments = measure:CreateExpressions()
    for expression_assignment in each(expression_assignments) do
        local staff_num = expression_assignment:CalcStaffInPageView()
        if staff_num > 0 then
            if expression.is_for_current_part(expression_assignment) and expression_assignment.Visible then
                local edupos_table = get_edupos_table(measure_table, staff_num, expression_assignment.MeasurePos)
                if not edupos_table.expressions then
                    edupos_table.expressions = {}
                end
                if expression_assignment.Shape then
                    local shapeexp_def = expression_assignment:CreateShapeExpressionDef()
                    table.insert(edupos_table.expressions, " Shape "..tostring(shapeexp_def.ID))
                else
                    local textexp_def = expression_assignment:CreateTextExpressionDef()
                    local exp_text = textexp_def:CreateTextString()
                    enigma_string.expand_value_tag(exp_text, textexp_def:GetPlaybackTempoValue())
                    exp_text:TrimEnigmaTags()
                    table.insert(edupos_table.expressions, " " .. exp_text.LuaString)
                end
            end
        end
    end
    local smart_shape_marks = finale.FCSmartShapeMeasureMarks()
    local already_processed = {}
    if smart_shape_marks:LoadAllForRegion(measure_region) then
        for mark in each(smart_shape_marks) do
            local smart_shape = mark:CreateSmartShape()
            if not already_processed[smart_shape.ShapeNumber] and not smart_shape.EntryBased and not smart_shape:CalcLyricBased() then
                already_processed[mark.ShapeNumber] = true
                local lterm = smart_shape:GetTerminateSegmentLeft()
                local rterm = smart_shape:GetTerminateSegmentRight()
                local beg_mark = lterm.Measure == measure.ItemNo
                local end_mark = lterm.Measure == measure.ItemNo
                if beg_mark or end_mark then
                    if beg_mark then
                        local edupos_table = get_edupos_table(measure_table, lterm.Staff, lterm.MeasurePos)
                        if not edupos_table.smartshapes then
                            edupos_table.smartshapes = {}
                        end
                        local left_and_right = end_mark and rterm.Staff == lterm.Staff and rterm.Measure == lterm.Measure and rterm.MeasurePos == lterm.MeasurePos
                        local desc = get_smartshape_string(smart_shape, true, left_and_right)
                        if desc then
                            table.insert(edupos_table.smartshapes, " " .. desc)
                        end
                        if left_and_right then
                            end_mark = false
                        end
                    end
                    if end_mark then
                        -- if we get here, the shape has separate beg and end points, because of left_and_right check above
                        local edupos_table = get_edupos_table(measure_table, rterm.Staff, rterm.MeasurePos)
                        if not edupos_table.smartshapes then
                            edupos_table.smartshapes = {}
                        end
                        local desc = get_smartshape_string(smart_shape, false, true)
                        if desc then
                            table.insert(edupos_table.smartshapes, " " .. desc)
                        end
                    end
                end
            end
        end
    end
    for entry in eachentry(measure_region) do
        local edupos_table = get_edupos_table(measure_table, entry.Staff, entry.MeasurePos)
        if not edupos_table.entries then
            edupos_table.entries = {}
        end
        table.insert(edupos_table.entries, entry_string(entry))
    end
    return measure_table
end

function write_measure(file, measure, measure_number_regions)
    local display_text = finale.FCString()
    local region_number = measure_number_regions:CalcStringFromNumber(measure.ItemNo, display_text)
    if region_number < 0 then
        display_text.LuaString = "#"..tostring(measure.ItemNo)
    end
    file:write("\n")
    file:write("Measure ", measure.ItemNo, " [", display_text.LuaString, "]\n")
    local measure_region = finale.FCMusicRegion()
    measure_region:SetFullDocument()
    measure_region.StartMeasure = measure.ItemNo
    measure_region.EndMeasure = measure.ItemNo
    local measure_table = create_measure_table(measure_region, measure)
    for slot = 1, measure_region.EndSlot do
        local staff_number = measure_region:CalcStaffNumber(slot)
        local staff_table = measure_table[staff_number]
        if staff_table then
            local staff = finale.FCCurrentStaffSpec()
            local staff_name = ""
            if staff:LoadForCell(finale.FCCell(measure.ItemNo, staff_number), 0) then
                staff_name = staff:CreateDisplayFullNameString().LuaString
            end
            if staff_name == "" then
                staff_name = "Staff " .. staff_number
            end
            file:write("  ", staff_name, ":")
            for edupos, edupos_table in pairsbykeys(staff_table) do
                file:write(" ["..tostring(edupos).."]")
                -- ToDo: chords first
                if edupos_table.smartshapes then
                    for _, ss_string in ipairs(edupos_table.smartshapes) do
                        file:write(ss_string)
                    end
                end
                if edupos_table.expressions then
                    for _, exp_string in ipairs(edupos_table.expressions) do
                        file:write(exp_string)
                    end
                end
                if edupos_table.entries then
                    for _, entry_string in ipairs(edupos_table.entries) do
                        file:write(entry_string)
                    end
                end
            end
            file:write("\n")
        end
    end
end

function document_save_as_text()
    local documents = finale.FCDocuments()
    documents:LoadAll()
    local document = documents:FindCurrent()
    local file_to_write = do_save_as_dialog(document)
    if not file_to_write then
        return
    end
    local file = io.open(file_to_write, "w")
    if not file then
        finenv.UI():AlertError("Unable to open " .. file_to_write .. ". Please check folder permissions.", "")
        return
    end
    local document_path = finale.FCString()
    document:GetPath(document_path)
    file:write("Script document_save_as_text.lua version ", finaleplugin.Version, "\n")
    file:write(document_path.LuaString, "\n")
    file:write("Saving as ", file_to_write, "\n")
    local measure_number_regions = finale.FCMeasureNumberRegions()
    measure_number_regions:LoadAll()
    for measure in loadall(finale.FCMeasures()) do
        write_measure(file, measure, measure_number_regions)
    end
    file:close()
end

document_save_as_text()