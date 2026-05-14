---@class shapes
local M = {
    physics = {
        gravity = 10,
        air_drag = 0.99,
    }
}

---Adds physics properties to a shape (velocity, mass and colllision management)
---@param shape table A shape to add physics to. Allowed shapes are: balls
function M.add_physics(shape)
    if shape.type ~= "ball" then return end

    shape.vx = 0
    shape.vy = 0

    shape.mass = 1
    shape.inv_mass = 1

    shape.pinned = false
    shape.pin_x = -1
    shape.pin_y = -1

    shape.update = function (self, dt)
        self.x += self.vx
        self.y += self.vy

        self.vx *= M.physics.air_drag
        self.vy *= M.physics.air_drag

        self.vy += M.physics.gravity * dt
    end

    return shape
end

---Creates a new BALL shape
---@param x number The X coordinate of the ball
---@param y number The Y coordinate of the ball
---@param r number The radius of the ball
function M.create_ball(x, y, r)
    return {
        type = "ball",

        x = x or 0,
        y = y or 0,
        r = r or 4,

        color = gfx.COLOR_YELLOW,

        is_colliding_screen = function (self)
            if self.x - self.r < 0 then            return {x = -1, y = 0 , colliding = true} end
            if self.x + self.r > usagi.GAME_W then return {x = 1 , y = 0 , colliding = true} end
            if self.y - self.r < 0 then            return {x = 0 , y = -1, colliding = true} end
            if self.y + self.r > usagi.GAME_H then return {x = 0 , y = 1 , colliding = true} end

            return {x = 0, y = 0, colliding = false}
        end,

        render = function (self)
            gfx.circ_fill(self.x, self.y, self.r, self.color)
        end,
    }
end

---Creates a new LINE shape
---@param x1 number The X coordinate of the first point
---@param y1 number The Y coordinate of the first point
---@param x2 number The X coordinate of the second point
---@param y2 number The Y coordinate of the second point
function M.create_line(x1, y1, x2, y2)
    return {
        type = "line",

        x1 = x1 or 0,
        y1 = y1 or 0,

        x2 = x2 or 10,
        y2 = y2 or 10,

        color = gfx.COLOR_DARK_GRAY,

        render = function (self)
            gfx.line(self.x1, self.y1, self.x2, self.y2, self.color)
        end,
    }
end

return M