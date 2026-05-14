--[[
TODO:

- implement fix_size setting for every element

- add images
- add mouse intersection test

- add element event callbacks (2 params: left -1, 0, 1, right, -1, 0, 1)

]]

--- The next line is only needed for some of the functions, like `create_label()`. !! Remove while developing !!
---@diagnostic disable: param-type-mismatch, assign-type-mismatch, return-type-mismatch

---@class UI
---@field screen_box  UI.Box A box covering the whole screen
---@field panels      table  A table containing the top level UI items
---@field value_hooks table  A table that contains all value hooks and their current value
local M = {
    screen_box = {}, ---@diagnostic disable-line: missing-fields
    panels = {},
    value_hooks = {},
}

--
--  UI Item classes
--

---@class UI.Style
---This table holds all styling for a ui item. If a field is not specified or set to -1, then that part of the item should not be rendered
---@field outline_color? integer The color of the outline of this item. Must be a palette index (`gfx.COLOR_*`)
---@field fill_color?    integer The color of the background of this item. Must be a palette index (`gfx.COLOR_*`)
---@field text_color?    integer The color of the text inside this item. Must be a palette index (`gfx.COLOR_*`)
---@field dotted_line?   boolean Whenever to use dotted rendering for the rect outline

---@class UI.Box
--- This is the basis of ALL other ui items! **Every item has these properties**
---@field type     string   The type of this item: "box"
---@field visible  boolean  Whenever to render this item or not. Hidden items will be consideren non existing
---@field data?    table    Any custom data, that the user might want to assign to this box
---@field style?   UI.Style A UI style table
---@field children table    A list containing child items
---@field x        number   The X coordinate of the top-left corner of the box
---@field y        number   The Y coordinate of the top-left corner of the box
---@field fix_size boolean  Toggles whenever to update the size of this item, relative to it's children
---@field w        number   The width of the box
---@field h        number   The height of the box
---@field min_w    number   The minimum allowed width of the box
---@field min_h    number   The minimum allowed height of the box
---@field max_w    number   The maximum allowed width of the box
---@field max_h    number   The maximum allowed height of the box
---@field mx       number   The outside margin of the box on the X axis
---@field my       number   The outside margin of the box on the Y axis

---@class UI.Label:UI.Box
--- Same as UI.Box, but has some additional parameters for text rendering
---@field type       string  The type of this item: "label"
---@field text       string  The text of the label
---@field text_x     number  The X coordinate of the top left corner of the text inside the label
---@field text_y     number  The Y coordinate of the top left corner of the text inside the label
---@field value_hook string  A reference to an entry in the `value_hooks` table
---@field h_align    integer The horizontal alignment of the text inside the box (-1: left, 0: center, 1: right )
---@field v_align    integer The vertical alignment of the text inside the box   (-1: top,  0: center, 1: bottom)

---@class UI.List:UI.Box
--- Same as UI.Box, but has some additional parameters for aligning child items
---@field type    string  The type of this item: "list"
---@field axis    string  The axis to align items along (can be "x" or "y")
---@field gap     number  The gap between the items in this list
---@field h_align integer The horizontal alignment of the items inside the box (-1: left, 0: center, 1: right )
---@field v_align integer The vertical alignment of the items inside the box   (-1: top,  0: center, 1: bottom)



--
--  Item manager methods
--

---Creates a new item style
---@param outline_color?   integer|UI.Style The color of the outline of an item or a partially populated table.
---If this is a color tehn it must be a palette index (`gfx.COLOR_*`)
---@param fill_color?      integer The color of the background of an item. Must be a palette index (`gfx.COLOR_*`)
---@param text_color?      integer The color of the text inside an item. Must be a palette index (`gfx.COLOR_*`)
---@param has_dotted_line? boolean Whenever to use dotted rendering for the rect outline
---@return UI.Style style          A new item style with all of the necessary fields populated
function M.create_style(outline_color, fill_color, text_color, has_dotted_line)
    ---@class UI.Style
    local new_style = {}

    if type(outline_color) == "table" then
        new_style.outline_color = outline_color.outline_color or -1
        new_style.fill_color = outline_color.fill_color or -1
        new_style.text_color = outline_color.text_color or gfx.COLOR_WHITE
        new_style.dotted_line = outline_color.dotted_line or false
    else
        new_style.outline_color = outline_color or -1
        new_style.fill_color = fill_color or -1
        new_style.text_color = text_color or gfx.COLOR_WHITE
        new_style.dotted_line = has_dotted_line or false
    end

    return new_style
end

---Creates a box with the given parameters
---You can either supply a single partially completed table to this function,
---or fill in all of the the arguments (every one of the is optional except
---for the last one)
---@param x   number|UI.Box The X coordinate of the top-left corner of the box or
---a partially populated table
---@param y?  number       The Y coordinate of the top-left corner of the box
---@param w?  number       The width of the box
---@param h?  number       The height of the box
---@param mx? number       The outside margin of the box on the X axis
---@param my? number       The outside margin of the box on the Y axis
---@return UI.Box box      A new box with all of the necessary fields populated
function M.create_box(x, y, w, h, mx, my)
    ---@class UI.Box
    local new_box = {}

    ---Appends a child item as a child of the current item
    ---@param item UI.Box|UI.Label|UI.List The item to append
    function new_box.add_child(item)
        -- Prevent `item:add_child()` calls
        if item == new_box then
            error("Could not append itself as a child! ( Call like a simple function: item.add_child() )")
        end

        table.insert(new_box.children, item)
    end

    if type(x) == "table" then
        new_box.visible = x.visible or true
        new_box.data = x.data
        new_box.style = M.create_style(x.style)
        new_box.children = x.children or {}
        new_box.x = x.x or 0
        new_box.y = x.y or 0
        new_box.fix_size = x.fix_size or false
        new_box.w = x.w or 0
        new_box.h = x.h or 0
        new_box.min_w = x.min_w or 0
        new_box.min_h = x.min_h or 0
        new_box.max_w = x.max_w or 1000
        new_box.max_h = x.max_h or 1000
        new_box.mx = x.mx or 0
        new_box.my = x.my or 0
    else
        new_box.visible = true
        new_box.children = {}
        new_box.x = x or 0
        new_box.y = y or 0
        new_box.fix_size = false
        new_box.w = w or 0
        new_box.h = h or 0
        new_box.min_w = 0
        new_box.min_h = 0
        new_box.max_w = 1000
        new_box.max_h = 1000
        new_box.mx = mx or 0
        new_box.my = my or 0
    end

    new_box.type = "box"

    return new_box
end

---Creates a new label from the provided string
---@param text     string|UI.Label The text to create a boundary around or a partially populated table
---@param h_align? integer The horizontal alignment of the text inside the box (-1: left, 0: center, 1: right )
---@param v_align? integer The vertical alignment of the text inside the box   (-1: top,  0: center, 1: bottom)
---@param value_hook? string The hook on which you can modify this label's text
---@return UI.Label label  A new box with the size of the provided text
function M.create_label(text, h_align, v_align, value_hook)
    ---@class UI.Label
    local new_label = {}

    if type(text) == "table" then
        new_label = M.create_box(text)
        new_label.text = text.text or ""
        new_label.text_x = text.text_x or 0
        new_label.text_y = text.text_y or 0
        new_label.v_align = text.v_align or 0
        new_label.h_align = text.h_align or 0
        new_label.value_hook = text.value_hook
    else
        local w, h = usagi.measure_text(text)
        new_label = M.create_box(0, 0, w, h)
        new_label.text = text or ""
        new_label.v_align = v_align or 0
        new_label.h_align = h_align or 0
        new_label.value_hook = value_hook
    end

    new_label.type = "label"

    -- Create hook endpoint for this label
    if new_label.value_hook ~= nil then
        M.value_hooks[new_label.value_hook] = new_label.text
    end

    return new_label
end

---Creates a new list box
---@param axis     string|UI.List The axis to align items along (can be "x" or "y") or
---a partially popupated table
---@param gap?     number  The gap between the items in this list
---@param h_align? integer The horizontal alignment of the items in the list (-1: left, 0: center, 1: right )
---@param v_align? integer The vertical alignment of the items in the list   (-1: top,  0: center, 1: bottom)
---@return UI.List list    A new list container
function M.create_list(axis, gap, h_align, v_align)
    ---@class UI.List
    local new_list = {}

    if type(axis) == "table" then
        new_list = M.create_box(axis)
        new_list.axis = axis.axis or "x"
        new_list.gap = axis.gap or 0
        new_list.v_align = axis.v_align or 0
        new_list.h_align = axis.h_align or 0
    else
        new_list = M.create_box({}) ---@diagnostic disable-line: missing-fields
        new_list.axis = axis or "x"
        new_list.gap = gap or 0
        new_list.v_align = v_align or 0
        new_list.h_align = h_align or 0
    end

    new_list.type = "list"
    return new_list
end

---Appends a new panel into the UI
---@param item UI.Box|UI.Label|UI.List A tree of UI items, which can be partially filled
---@param h_align? integer The horizontal alignment of this panel rin the screen (-1: left, 0: center, 1: right )
---@param v_align? integer The vertical alignment of this panel rin the screen   (-1: top,  0: center, 1: bottom)
function M.add_panel(item, h_align, v_align)
    local new_panel = {
        type = "panel",
        h_align = h_align or -1,
        v_align = v_align or -1,
        children = {item},
    }

    table.insert(M.panels, M.initialise(new_panel))
end

---Updates the value of a hook
---@param value_hook string The ID of a value hook
---@param new_value  string The value to write into the hook
function M.set_hook(value_hook, new_value)
    M.value_hooks[value_hook] = new_value
end

---Returns with a value in a value hook
---@param value_hook string The ID of a value hook
---@return string|nil value The value stored at the specified value hook
function M.get_hook(value_hook)
    return M.value_hooks[value_hook]
end

---Shows an item on the screen (sets the visibility to true)
---@param item UI.Box|UI.Label|UI.List The item to show
---@return UI.Box|UI.Label|UI.List item The modified item
function M.show_item(item)
    item.visible = true
    return item
end

---Hides an items (sets the visibility to false)
---@param item UI.Box|UI.Label|UI.List The item to hide
---@return UI.Box|UI.Label|UI.List item The modified item
function M.hide_item(item)
    item.visible = false
    return item
end

---Updates a label. Should be called after changing the label's text
---@param item UI.Label  The label to update
---@return UI.Label label The updated label
local function _update_label(item)
    if item.type ~= "label" then return item end

    -- Update text from the hook
    if item.value_hook ~= nil then
        item.text = tostring( M.value_hooks[item.value_hook] )
    end

    -- Update size
    local w, h = usagi.measure_text(item.text)

    item.min_w = w
    item.min_h = h

    if not item.fix_size then
        item.w = w
        item.h = h
    end

    return item
end

---Merges the data from `new` into `original`, but  keeps the children and the type
---@param original UI.Box|UI.Label|UI.List The original item to merge into
---@param new      UI.Box|UI.Label|UI.List The item to merge the data from
---@return UI.Box|UI.Label|UI.List item    The merged item 
local function _merge_item(original, new)
    for k, v in pairs(new) do
        if original[k] == nil then
            original[k] = v
        end

        if k ~= "children" and k ~= "type" then
            original[k] = v
        end
    end

    return original
end

---Fills in the default values in the provided item
---@param item UI.Box|UI.Label|UI.List  The item to initialise
---@return UI.Box|UI.Label|UI.List item The initialised item
function M.initialise(item)
    if item.type == "panel" then
        local p = M.create_box(item)
        p.type = "panel"
        item = _merge_item(item, p)
    end
    if item.type == "box" then
        local b = M.create_box(item)
        item = _merge_item(item, b)
    end
    if item.type == "label" then
        item = _merge_item(item, M.create_label(item))
        item = _update_label(item)
    end
    if item.type == "list" then
        item = _merge_item(item, M.create_list(item))
    end

    -- Iterate over all children
    if item.children ~= nil then
        for i, child in ipairs(item.children) do
            item.children[i] = M.initialise(child)
        end
    end

    return item
end

---Aligns a box inside a container box along 2 axis
---@param box    UI.Box The box to align inside the parent 
---@param parent UI.Box The container for the box 
---@param h_align? integer The horizontal alignment of the box (-1: left, 0: center, 1: right )
---@param v_align? integer The vertical alignment of the box   (-1: top,  0: center, 1: bottom)
---@return UI.Box box The box, aligned inside the parent 
function M.align_item(box, parent, h_align, v_align)
    local mx = box.mx or 0
    local my = box.my or 0

    local x = 0
    local y = 0
    local w = box.w + mx*2
    local h = box.h + my*2

    if h_align == 0 then x = parent.w/2 - w/2 end
    if h_align == 1 then x = parent.w - w end

    if v_align == 0 then y = parent.h/2 - h/2 end
    if v_align == 1 then y = parent.h - h end

    x = x + mx
    y = y + my

    local out = {
        x = parent.x + x,
        y = parent.y + y,
        w = box.w,
        h = box.h,
    }

    return out
end



--
--  Helper functions
--

local function _render_loop(item, debug_mode)
    local d = debug_mode or false

    -- Iterate over all children
    if item.children ~= nil then
        for _, child in ipairs(item.children) do
            _render_loop(child, d)
        end
    end

    M.render_item(item, d)
end

local function _size_update_loop(item)
    -- Iterate over all children and update them
    for i, child in ipairs(item.children) do
        item.children[i] = _size_update_loop(child)
    end

    if item.type == "box" or item.type == "panel" then
        if item.fix_size then
            -- Do not change size
        else
            -- Shrink to the smallest possible size
            item.w = item.min_w
            item.h = item.min_h

            for _, child in pairs(item.children) do
                item.w = math.max(item.w, child.w + child.mx * 2)
                item.h = math.max(item.h, child.h + child.my * 2)
            end
        end
    end

    if item.type == "label" then
        item = _update_label(item)
    end

    if item.type == "list" then
        item.w, item.h = 0, 0

        if item.axis == "x" then
            for _, child in pairs(item.children) do
                item.w = item.w + child.w + child.mx*2 + item.gap
                item.h = math.max(item.h, child.h + child.my*2)
            end

            item.w = item.w - item.gap
        end

        if item.axis == "y" then
            for _, child in pairs(item.children) do
                item.w = math.max(item.w, child.w + child.mx*2)
                item.h = item.h + child.h + child.my*2 + item.gap
            end

            item.h = item.h - item.gap
        end
    end

    -- Constrain item sizes
    item.w = math.min(math.max(item.w, item.min_w), item.max_w)
    item.h = math.min(math.max(item.h, item.min_h), item.max_h)

    -- Reset item size if it is not visible
    if item.visible == false then
        item.w = 0
        item.h = 0
    end

    return item
end

local function _position_update_loop(item, parent_x, parent_y)
    local px = parent_x or 0
    local py = parent_y or 0

    -- Apply margin offset
    item.x = px + item.mx
    item.y = py + item.my

    -- Iterate over all children and update them
    local dpx = px + item.mx
    local dpy = py + item.my

    for i, child in ipairs(item.children) do
        if item.type == "list" then
            if item.axis == "x" then
                if item.v_align == -1 then dpy = item.y end
                if item.v_align == 0  then dpy = item.y + item.h/2 - child.h/2 - child.my end
                if item.v_align == 1  then dpy = item.y + item.h - child.h - child.my*2 end
            end

            if item.axis == "y" then
                if item.h_align == -1 then dpx = item.x end
                if item.h_align == 0  then dpx = item.x + item.w/2 - child.w/2 - child.mx end
                if item.h_align == 1  then dpx = item.x + item.w - child.w - child.mx*2 end
            end
        end

        item.children[i] = _position_update_loop(child, dpx, dpy)

        if item.type == "list" then
            if item.axis == "x" then
                dpx = dpx + child.w + child.mx*2 + item.gap
            end

            if item.axis == "y" then
                dpy = dpy + child.h + child.my*2 + item.gap
            end
        end
    end

    -- Update label text position
    if item.type == "label" then
        local w, h = usagi.measure_text(item.text)
        local tmp_textbox = M.create_box({w = w, h = h}) ---@diagnostic disable-line: missing-fields
        tmp_textbox = _merge_item(tmp_textbox, M.align_item(tmp_textbox, item, item.h_align, item.v_align))

        item.text_x = tmp_textbox.x
        item.text_y = tmp_textbox.y
    end

    return item
end



--
--  Main methods
--

---Same as `gfx.rect()` but it draws the rectangle with a dotted line
local function _rect_dot(x, y, w, h, color)
    for dx = x, x + w - 1, 2 do
        gfx.pixel(dx, y, color)
        gfx.pixel(dx, y + h - 1, color)
    end

    for dy = y, y + h - 1, 2 do
        gfx.pixel(x, dy, color)
        gfx.pixel(x + w - 1, dy, color)
    end
end

---Renders a ui item on the screen
---@param item        UI.Box|UI.Label|UI.List The UI item to render (can be a box or a label) 
---@param debug_mode? boolean                 Render box outlines?
function M.render_item(item, debug_mode)
    if item.visible == false then return end

    local render_outline = false
    local outline_color = gfx.COLOR_RED
    local render_fill = false
    local fill_color = gfx.COLOR_LIGHT_GRAY
    local text_color = gfx.COLOR_WHITE
    local render_dotted = false

    -- Setup the UI item color
    if item.style ~= nil then
        if item.style.outline_color ~= nil and item.style.outline_color ~= -1 then
            render_outline = true
            outline_color = item.style.outline_color
        end

        if item.style.fill_color ~= nil and item.style.fill_color ~= -1 then
            render_fill = true
            fill_color = item.style.fill_color
        end

        if item.style.text_color ~= nil and item.style.text_color ~= -1 then
            text_color = item.style.text_color
        end

        render_dotted = item.style.dotted_line or false
    end

    -- Override when debug mode is active
    if debug_mode then
        render_outline = true
        outline_color = gfx.COLOR_RED
        render_fill = false

        if item.type == "panel" then render_dotted = false end
        if item.type == "list" then outline_color = gfx.COLOR_YELLOW end
    end

    -- Render the UI item
    if render_fill then
        gfx.rect(item.x, item.y, item.w, item.h, fill_color)
    end

    if render_outline then
        if render_dotted then
            _rect_dot(item.x, item.y, item.w, item.h, outline_color)
        else
            gfx.rect(item.x, item.y, item.w, item.h, outline_color)
        end
    end

    if item.type == "label" then
        local w, h = usagi.measure_text(item.text)

        if debug_mode then
            gfx.rect(item.text_x, item.text_y, w, h, gfx.COLOR_BLUE)
        end

        gfx.text(item.text, item.text_x, item.text_y, text_color)
    end
end

---Initialises the UI library. Must be called in `_init()`
function M.init()
    -- Create screen box
    M.screen_box = M.create_box(0, 0, usagi.GAME_W, usagi.GAME_H)
    M.screen_box.mx = 0
    M.screen_box.my = 0
    M.screen_box.min_w = usagi.SPRITE_SIZE
    M.screen_box.min_h = usagi.SPRITE_SIZE
    M.screen_box.max_w = usagi.GAME_W
    M.screen_box.max_h = usagi.GAME_H

    -- Panel continer
    M.panels = {}
end

---Renders the UI to the screen. Must be called in `_draw()`
---@param debug_mode? boolean if this flag is set then the box outlines will be
---rendered as well. here are the outline colors:
--- - `red`: The border of the box
--- - `gray`: The border of the box, including the margin
--- - `blue`: The border of the text inside of a label
function M.render(debug_mode)
    for _, panel in pairs(M.panels) do
        _render_loop(panel, debug_mode)
    end

    --M.render_item(M.screen_box, debug_mode)
end

---Updates their UI elements and handles ui events. Must be called in `_update()`
---@param mouse_x? number The X position of the mouse cursor
---@param mouse_y? number The You position of the mouse cursor
---**Example:**
---```lua
---local mx, my = input.mouse()
---ui.update(mx, my)
---```
function M.update(mouse_x, mouse_y)
    -- Calculate element sizes
    for i, panel in pairs(M.panels) do
        _size_update_loop(panel)

        -- Align panel on the screen
        M.panels[i] = _merge_item(panel, M.align_item(panel, M.screen_box, panel.h_align, panel.v_align))
    end

    -- Calculate item positions
    for _, panel in pairs(M.panels) do
        _position_update_loop(panel, panel.x, panel.y)
    end
end

return M
