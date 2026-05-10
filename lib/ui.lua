---@class ui
local ui = {}

---Aligns a box on the screen relative to 9 anchors
---@param width   number  The width of the box to align 
---@param height  number  The height of the box to align 
---@param v_align integer The vertical alignment of thge label   (-1: top,  0: center, 1: bottom)
---@param h_align integer The horizontal alignment of thge label (-1: left, 0: center, 1: right )
---@param margin  number  (optional) The margin around the box
---@return rect   table   A rectangle, replresenting the positioned box
local function ui_get_box_pos(width, height, v_align, h_align, margin)
    local m = margin or 0

    local x = 0
    local y = 0
    local w = width + m*2
    local h = height + m*2

    if v_align == 0 then x = usagi.GAME_W/2 - w/2 end
    if v_align == 1 then x = usagi.GAME_W - w end

    if h_align == 0 then y = usagi.GAME_H/2 - h/2 end
    if h_align == 1 then y = usagi.GAME_H - h end

    x += m
    y += m

    return {
        x = x,
        y = y,
        w = width,
        h = height,
    }
end

---Aligns a box on the screen relative to 9 anchors, allows offsetting
---@param box         table   A box to align 
---@param v_align     integer The vertical alignment of thge label   (-1: top,  0: center, 1: bottom)
---@param h_align     integer The horizontal alignment of thge label (-1: left, 0: center, 1: right )
---@param offset_x    number  Offset of the box on the X axis (multiple of 1x + n the box width)
---@param offset_y    number  Offset of the box on the Y axis (multiple of 1x + n the box height)
local function ui_get_box_pos_repeat(box_in, v_align, h_align, offset_x, offset_y)
    local ox, oy = offset_x or 0, offset_y or 0
    local box = ui_get_box_pos(box_in.w, box_in.h, v_align, h_align, 0)

    box.x += box.w * ox
    box.y += box.h * oy

    return box

end

---Draws text onto the screen at the given position
---@param text        string  The text to draw 
---@param color       integer A palette index from the gfx.COLOR_* enum
---@param v_align     integer The vertical alignment of thge label   (-1: top,  0: center, 1: bottom)
---@param h_align     integer The horizontal alignment of thge label (-1: left, 0: center, 1: right )
---@param line_offset integer The offset of the text, in lines from the center
local function ui_draw_label(text, color, v_align, h_align, line_offset)
    local offset = line_offset or 0

    local mx = usagi.SPRITE_SIZE/4
    local my = 0

    local w, h = usagi.measure_text(text)
    local box = ui_get_box_pos(w, h, v_align, h_align, math.max(mx, my))

    gfx.text(text, box.x, box.y + offset * (h + my*2), color)
end

ui.get_box = ui_get_box_pos
ui.get_box_repeat = ui_get_box_pos_repeat
ui.draw_label = ui_draw_label

return ui