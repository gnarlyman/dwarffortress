local dlg = require('gui.dialogs')
local gui = require('gui')
local plugin = require('plugins.autobutcher')
local widgets = require('gui.widgets')

local units = df.global.world.units.active

local column = {
    ID = "ID",
    Name = "Name",
    Age = "Age",
    Gender = "Gender",
    Profession = "Profession",
    Skills = "Skills",
    Squad = "Squad",
    Race = "Race",
    Type = "Type",
    Stress = "Stress",
}

local column_width = {
    ID = 5,
    Name = 20,
    Age = 8,
    Gender = 8,
    Profession = 15,
    Skills = 32,
    Squad = 10,
    Race = 7,
    Type = 10,
    Stress = 10,
}

local header_position = {}
header_position["ID"] = 0
header_position["Name"] = header_position["ID"] + column_width.ID
header_position["Age"] = header_position["Name"] + column_width.Name
header_position["Gender"] = header_position["Age"] + column_width.Age
header_position["Profession"] = header_position["Gender"] + column_width.Gender
header_position["Skills"] = header_position["Profession"] + column_width.Profession
header_position["Squad"] = header_position["Skills"] + column_width.Skills
header_position["Race"] = header_position["Squad"] + column_width.Squad
header_position["Type"] = header_position["Race"] + column_width.Race
header_position["Stress"] = header_position["Type"] + column_width.Type

local current_sort_column = column.ID  -- Default sort column
local ascending_sort = false  -- Default to descending sort

local filters = {
    show_residents = true,
    show_all_skills = false,
    show_squads = false,
    hide_children = false,
    search = '',
}

local function updateHeaderWidgets(self)
    -- Reset all header labels
    for _, field in ipairs(field_functions) do
        local column_name = field.name
        local header_widget = self.subviews["sort_" .. column_name:lower()]

        if header_widget then
            header_widget:setText(column_name)
        end
    end

    -- Update the currently sorted column with up/down arrow
    local sort_arrow = ascending_sort and CH_UP or CH_DN
    local current_header_widget = self.subviews["sort_" .. current_sort_column:lower()]

    if current_header_widget then
        current_header_widget:setText(current_sort_column .. sort_arrow)
    end
end

-- Table holding the field names and corresponding functions to retrieve the values
local field_functions = {
    {name = column.ID, func = function(unit) return unit.id end},
    {name = column.Name, func = function(unit) return dfhack.TranslateName(unit.name) end},
    {name = column.Age, func = function(unit) return dfhack.units.getAge(unit) end},
    {name = column.Gender, func = function(unit) return unit.sex == 1 and 'Male' or 'Female' end},
    {name = column.Profession, func = function(unit) return df.profession[unit.profession] or "Unknown" end},
    {name = column.Skills, func = function(unit) 
        local skills = {}
        
        -- Collect skills and their levels
        for _, skill in ipairs(unit.status.current_soul.skills) do
            local skill_name = df.job_skill[skill.id]
            local skill_level = skill.rating
            if skill_level >= 1 then
                table.insert(skills, {name = skill_name, level = skill_level})
            end
        end
        
        -- Sort skills by level in descending order
        table.sort(skills, function(a, b)
            return a.level > b.level
        end)
        
        -- Create a string with sorted skills
        local skill_strings = {}
        for _, skill in ipairs(skills) do
            table.insert(skill_strings, skill.name .. '(' .. skill.level .. ')')
        end
        
        return table.concat(skill_strings, ' ')
    end},    
    {name = column.Squad, func = function(unit)
        if unit.military.squad_id ~= -1 then
            local squad = df.squad.find(unit.military.squad_id)
            if squad then
                return dfhack.TranslateName(squad.name)
            end
        end
        return "No squad"
    end},
    {name = column.Race, func = function(unit) return dfhack.units.getRaceName(unit) end},
    {name = column.Type, func = function(unit)
        return dfhack.units.isCitizen(unit) and 'CITIZEN' or 'RESIDENT'
    end},
    {name = column.Stress, func = function(unit) return dfhack.units.getStressCategory(unit) end}
}

local function unit_row(unit)
    local row = {}
    for _, field in ipairs(field_functions) do
        local value = field.func(unit)
        table.insert(row, value)
    end
    return row
end

local function build_unit_table()
    local rows = {}
    for _, unit in ipairs(units) do
        if dfhack.units.isCitizen(unit) or dfhack.units.isResident(unit) then
            table.insert(rows, unit_row(unit))
        end
    end
    return rows
end

local CH_UP = string.char(30)
local CH_DN = string.char(31)

WatchList = defclass(WatchList, gui.ZScreen)
WatchList.ATTRS{
    focus_string='fortresspops',
}

-- Function to pop an item from a specific index
function popAtIndex(t, index)
    if index < 1 or index > #t then
        return nil  -- Return nil if the index is out of bounds
    end
    return table.remove(t, index)  -- Remove and return the item at the specified index
end

local function sortTableByField(data, field_idx, ascending)
    table.sort(data, function(a, b)
        local valA = a[field_idx]
        local valB = b[field_idx]

        if valA == valB then
            return false
        end
        
        -- Compare values and apply ascending/descending order
        if ascending then
            return valA < valB
        else
            return valA > valB
        end
    end)
end

function WatchList:update_filter(filter_name)
    filters[filter_name] = not filters[filter_name]
    self:refresh()
end


function WatchList:search(text, old)
    filters.search = text
    self:refresh()
end

function WatchList:init()
    local window = widgets.Window{
        frame_title = 'Fortress Pops',
        frame = {w = 128, h = 50},
        resizable = true,
        subviews = {
            widgets.ToggleHotkeyLabel{
                view_id='show_residents',
                frame={t=0, l=0, w=26},
                label='Show Residents',
                key='CUSTOM_ALT_R',
                on_change=self:callback('update_filter', 'show_residents'),
            },
            widgets.ToggleHotkeyLabel{
                view_id='show_all_skills',
                frame={t=0, l=28, w=26},
                label='Show All Skills',
                key='CUSTOM_ALT_K',
                on_change=self:callback('update_filter', 'show_all_skills'),
                options={
                    {value=false, label='Off'},
                    {value=true, label='On', pen=COLOR_GREEN},
                },
            },
            widgets.ToggleHotkeyLabel{
                view_id='show_squads',
                frame={t=0, l=58, w=26},
                label='Show Squads',
                key='CUSTOM_ALT_Q',
                on_change=self:callback('update_filter', 'show_squads'),
                options={
                    {value=false, label='Off'},
                    {value=true, label='On', pen=COLOR_GREEN},
                },
            },
            widgets.ToggleHotkeyLabel{
                view_id='hide_children',
                frame={t=0, l=84, w=26},
                label='Hide Children',
                key='CUSTOM_ALT_C',
                on_change=self:callback('update_filter', 'hide_children'),
                options={
                    {value=false, label='Off'},
                    {value=true, label='On', pen=COLOR_GREEN},
                },
            },
            widgets.Panel{
                view_id = 'list_panel',
                frame = {t=2, l=0, r=0, b=2},
                frame_style = gui.FRAME_INTERIOR,
                subviews = {
                    widgets.Label{
                        view_id = 'sort_id',
                        frame = {t = 0, l = header_position.ID, w = column_width.ID},
                        text = column.ID,
                        on_click = self:callback('sortByColumn', column.ID)
                    },
                    widgets.Label{
                        view_id = 'sort_name',
                        frame = {t = 0, l = header_position.Name, w = column_width.Name},
                        text = column.Name,
                        on_click = self:callback('sortByColumn', column.Name)
                    },
                    widgets.Label{
                        view_id = 'sort_age',
                        frame = {t = 0, l = header_position.Age, w = column_width.Age},
                        text = column.Age,
                        on_click = self:callback('sortByColumn', column.Age)
                    },
                    widgets.Label{
                        view_id = 'sort_gender',
                        frame = {t = 0, l = header_position.Gender, w = column_width.Gender},
                        text = column.Gender,
                        on_click = self:callback('sortByColumn', column.Gender)
                    },
                    widgets.Label{
                        view_id = 'sort_profession',
                        frame = {t = 0, l = header_position.Profession, w = column_width.Profession},
                        text = column.Profession,
                        on_click = self:callback('sortByColumn', column.Profession)
                    },
                    widgets.Label{
                        frame={t=0, l=header_position.Skills, w = column_width.Skills},
                        text=column.Skills
                    },
                    widgets.Label{
                        view_id = 'sort_squad',
                        frame = {t = 0, l = header_position.Squad, w = column_width.Squad},
                        text = column.Squad,
                        on_click = self:callback('sortByColumn', column.Squad)
                    },
                    widgets.Label{
                        view_id = 'sort_race',
                        frame = {t = 0, l = header_position.Race, w = column_width.Race},
                        text = column.Race,
                        on_click = self:callback('sortByColumn', column.Race)
                    },
                    widgets.Label{
                        view_id = 'sort_type',
                        frame = {t = 0, l = header_position.Type, w = column_width.Type},
                        text = column.Type,
                        on_click = self:callback('sortByColumn', column.Type)
                    },
                    widgets.Label{
                        view_id = 'sort_stress',
                        frame = {t = 0, l = header_position.Stress, w = column_width.Stress},
                        text = column.Stress,
                        on_click = self:callback('sortByColumn', column.Stress)
                    },
                    widgets.EditField{
                        view_id='search',
                        frame={l=1, t=2, r=1},
                        label_text="Search: ",
                        key='CUSTOM_ALT_S',
                        on_change=function(text, old) self:search(text, old) end,
                    },
                    widgets.List{
                        view_id = 'list',
                        frame = {t = 4, b = 0},
                        row_height=2,
                    },
                }
            },
        }
    }

    self:addviews{window}
    self:sortByColumn("ID", false)  -- Default sort on init
end

function WatchList:sortByColumn(column_name)
    -- Toggle ascending/descending if the same column is selected
    if current_sort_column == column_name then
        ascending_sort = not ascending_sort
    else
        -- If a new column is selected, reset to ascending order
        current_sort_column = column_name
        ascending_sort = true
    end

    -- Sort the data based on the selected column
    self:refresh()
end

function WatchList:updateHeaderWidgets()
    -- Reset all header labels
    for _, field in ipairs(field_functions) do
        local column_name = field.name
        local header_widget = self.subviews["sort_" .. column_name:lower()]

        if header_widget then
            header_widget:setText(column_name)
        end
    end

    -- Update the currently sorted column with up/down arrow
    local sort_arrow = ascending_sort and CH_UP or CH_DN
    local current_header_widget = self.subviews["sort_" .. current_sort_column:lower()]

    if current_header_widget then
        current_header_widget:setText(current_sort_column .. sort_arrow)
    end
end

-- Custom sort function
function sortKeys(a, b, column)
    -- Use the column index to compare values in that column
    local valA = a[column]
    local valB = b[column]

    -- Sort logic: compare the values in the column
    if valA == valB then
        return false  -- They are equal, don't change order
    else
        return valA < valB  -- Sort in ascending order (can reverse if needed)
    end
end

function WatchList:refresh()
    -- Build and sort the unit table
    local unit_table = build_unit_table()
    local field_idx = nil

    -- Find the index of the currently sorted column
    for i, field in ipairs(field_functions) do
        if field.name == current_sort_column then
            field_idx = i
            break
        end
    end

    if field_idx then
        sortTableByField(unit_table, field_idx, ascending_sort)
    end

    -- Update the header widgets to show the current sort state
    self:updateHeaderWidgets()

    -- Rebuild choices for the UI
    local choices = {}
    local SKILL_THRESHOLD = 30  -- Maximum combined length of two skills

    for _, unit_row in ipairs(unit_table) do
        -- Create the main entry for the unit
        local entry = {}
        local skill_list = {}
        local row_text = ""

        -- Build the main row for the unit
        for i, column_data in ipairs(unit_row) do
            local column_name = field_functions[i].name
            local width = column_width[column_name] or 10
            local color = COLOR_WHITE

            if column_name == column.Age then
                column_data = string.format("%.2f", column_data)
            elseif column_name == column.Gender then
                color = getGenderColor(column_data)
            elseif column_name == column.Stress then
                color = getStressColor(column_data)
            elseif column_name == column.Type then
                if not filters.show_residents and column_data == 'RESIDENT' then
                    goto continue
                end
                color = getTypeColor(column_data)
            elseif column_name == column.Squad then
                if filters.show_squads then
                    if column_data == "No squad" then
                        goto continue
                    end
                end
                color = getSquadColor(column_data)
            elseif column_name == column.Race then
                color = getRaceColor(column_data)
            elseif column_name == column.Profession then
                if filters.hide_children and column_data == "CHILD" then
                    goto continue
                end
            elseif column_name == column.Skills then
                -- Split skills by spaces and store them in skill_list
                for skill in column_data:gmatch("%S+") do
                    table.insert(skill_list, skill)
                end
                -- Apply length check for the main row (up to two skills)
                column_data = popAtIndex(skill_list, 1) or ""
                if #skill_list > 0 then
                    local next_skill = skill_list[1]
                    if (#column_data + #next_skill + 1) <= SKILL_THRESHOLD then
                        column_data = ("%s %s"):format(column_data, popAtIndex(skill_list, 1))
                    end
                end
            end

            -- Add the column data to the row text for searching purposes
            row_text = row_text .. tostring(column_data):lower() .. " "

            table.insert(entry, {text = column_data, width = width, pen=color})
        end

        -- Apply search filter **before** adding any rows
        if filters.search ~= "" and not row_text:find(filters.search) then
            -- Skip this unit entirely if the search doesn't match
            goto continue
        end

        -- Add main unit entry to the choices
        table.insert(choices, {entry})

        -- Handle additional skills if they exist
        if filters.show_all_skills then
            -- Add additional rows for remaining skills, applying the length check
            while #skill_list > 0 do
                local additional_row = {}
                local skill_data = popAtIndex(skill_list, 1) or ""

                -- Check if we can fit two skills in the row based on the length
                if #skill_list > 0 then
                    local next_skill = skill_list[1]
                    if (#skill_data + #next_skill + 1) <= SKILL_THRESHOLD then
                        skill_data = ("%s %s"):format(skill_data, popAtIndex(skill_list, 1))
                    end
                end

                -- Add empty text for all columns except the "Skills" column
                for j = 1, #field_functions do
                    local column_name = field_functions[j].name
                    local width = column_width[column_name] or 10
                    if column_name == "Skills" then
                        table.insert(additional_row, {text = skill_data, width = width, pen=COLOR_WHITE})
                    else
                        -- Insert empty text for non-skills columns
                        table.insert(additional_row, {text = "", width = width, pen=COLOR_WHITE})
                    end
                end

                -- Add additional row to the choices
                table.insert(choices, {additional_row})
            end
        end

        ::continue::
    end

    -- Update the list view with sorted choices
    self.subviews.list:setChoices(choices)
end

function getGenderColor(value)
    if value == 'Male' then
        return COLOR_BLUE
    else
        return COLOR_LIGHTMAGENTA
    end
end

function getSquadColor(value)
    if value == 'No squad' then
        return COLOR_WHITE
    else
        return COLOR_MAGENTA
    end
end

function getRaceColor(value)
    if value == 'DWARF' then
        return COLOR_LIGHTGREEN
    else
        return COLOR_YELLOW
    end
end

function getTypeColor(value)
    if value == 'CITIZEN' then
        return COLOR_LIGHTGREEN
    elseif value == 'RESIDENT' then
        return COLOR_YELLOW
    end
end

function getStressColor(value)
    if value == 6 then
        return COLOR_LIGHTGREEN
    elseif value == 5 then
        return COLOR_GREEN 
    elseif value == 4 then
        return COLOR_YELLOW
    elseif value == 3 then
        return COLOR_BLUE 
    elseif value == 2 then
        return COLOR_MAGENTA
    elseif value == 1 then
        return COLOR_LIGHTMAGENTA
    elseif value == 0 then
        return COLOR_RED 
    else
        return COLOR_WHITE
    end
end

function WatchList:onDismiss()
    view = nil
end

view = view and view:raise() or WatchList{}:show()