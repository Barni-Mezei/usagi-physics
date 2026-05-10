local shapes = require("lib.shapes")
local ui = require("lib.ui")
local v = require("lib.vector")

require("lib.misc")

--[[
TODO:

ball - ball collisions
- grid based optimisation

Tools:
- ball placer: left place, right delete (menu: ball radius?, mass?)
- select: [left drag select, if hovereda ball on start: set start XY to ball XY], right click to select all connected
- move: move selected
- pin: left clik to toggle pin state
- animate: left clik to add motion, like rotation (menu: motion mode selecti) right click to remove that motion mode
- constraint creator: click on start, click on end -> creates a new constraint (menu: power?, connect selected)

- blueprint library:
- save selected
- load to cursor (ghost preview?)

Other controls:
- camera controls [middle-click panning / zoom, focus selected balls into view]


Each mode gets a new function, functions get passed mouse position, clicks and releases

]]

function _config()
	return {
		name = "Physics",
		game_id = "com.barni-07.physics",
		icon = 1,

		-- game_width = 640,
		-- game_height = 360,
	}
end

-- Mouse position
local mx, my = 0, 0
local omx, omy = 0, 0

Settings = {
	global_strength = 1, -- Global spring strength
	iteration_count = 4, -- Global spring strength
}

selected_balls = {} -- Selected ball index
selection_reset = false -- Clear selection after action?

hovered_ball_index = -1 -- Hovered ball
hovered_constraint_index = -1 -- Hovered constraint

function _init()
	-- Keep between reloads
	pool = require("lib.pool")
	pool.init()
	pool.max_size = -1

	input.set_mouse_visible(false)

	State = {
		-- Stats
		ball_count = 0,
		constraint_count = 0,
		
		-- UI
		selected_menu = 1,
		is_paused = true,
		stat_selected = -1, -- Visualised ball index
	}
end

--
-- Object creation
--

-- Create a new physics ball
local function create_ball(x, y, radius, mass)
	local ball = shapes.create_ball(x, y, radius)
	shapes.add_physics(ball)

	ball.mass = mass or radius or 1
	ball.inv_mass = 1 / ball.mass
	
	ball.index = #pool.objects + 1

	-- ball.vx = rand_float(-8, 8)
	-- ball.vy = rand_float(-6, 1)

	ball.render = function (self, is_hovered, is_selected)
		--[[if usagi.IS_DEV then
			local t = tostring(self.index)
			local w, h = usagi.measure_text(t)
			gfx.text(t, self.x - w/2, self.y - self.r - h, gfx.COLOR_WHITE)
		end]]

		local color = self.color

		if self.pinned then color = gfx.COLOR_ORANGE end
		if is_hovered then color = gfx.COLOR_RED end
		
		gfx.circ_fill(self.x, self.y, self.r, color)

		if is_selected then
			gfx.circ(self.x, self.y, self.r, gfx.COLOR_BLUE)
		end
	end

	if ball ~= -1 then
		State.ball_count += 1
	end

	return ball
end

-- Create a new constraint
local function create_constraint(ball1_index, ball2_index)
	local b1 = pool.objects[ball1_index]
	local b2 = pool.objects[ball2_index]

	local constraint = shapes.create_line(b1.x, b1.y, b2.x, b2.y)

	constraint.index_1 = ball1_index
	constraint.index_2 = ball2_index
	constraint.length  = util.vec_dist(b1, b2)
	constraint.power   = 1--rand_float(0.25, 1)

	constraint.update = function (self, dt)
		-- Set line ends to the ball positions
		local b1 = pool.objects[self.index_1]
		local b2 = pool.objects[self.index_2]

		self.x1 = b1.x
		self.y1 = b1.y

		self.x2 = b2.x
		self.y2 = b2.y
	end

	constraint.push = function (self)
		-- Get the balls at the end of the line
		local b1 = pool.objects[self.index_1]
		local b2 = pool.objects[self.index_2]

		-- Calculate the positional difference of the balls
		local pos_diff = v.sub(b1, b2)
		local length_diff = (self.length - v.length(pos_diff)) * self.power * Settings.global_strength

		-- Calculate displacement (take mass into account)
		local offset = v.unit(pos_diff, length_diff / (1/b1.mass + 1/b2.mass))

		local b1_inv_mass = b1.inv_mass
		if b1.pinned then b1_inv_mass = 0 end

		local b2_inv_mass = b2.inv_mass
		if b2.pinned then b2_inv_mass = 0 end


		-- Update ball positions
		b1.x += offset.x * b1_inv_mass
		b1.y += offset.y * b1_inv_mass

		b2.x -= offset.x * b2_inv_mass
		b2.y -= offset.y * b2_inv_mass

		-- Update ball velocities
		b1.vx += offset.x * b1_inv_mass
		b1.vy += offset.y * b1_inv_mass

		b2.vx -= offset.x * b2_inv_mass
		b2.vy -= offset.y * b2_inv_mass
	end

    constraint.render = function (self)
		gfx.line(self.x1, self.y1, self.x2, self.y2, self.color)
	end

	if constraint ~= -1 then
		State.constraint_count += 1
	end

	return constraint
end

local function blueprint_create_rect(px, py)
	-- Corners
	local top_left     = pool.add_object(create_ball(px     , py     , 3))
	local top_right    = pool.add_object(create_ball(px + 32, py     , 3))
	local bottom_right = pool.add_object(create_ball(px + 32, py + 32, 3))
	local bottom_left  = pool.add_object(create_ball(px     , py + 32, 3))

	-- Sides
	local top    = pool.add_object(create_constraint(top_left    , top_right   ))
	local right  = pool.add_object(create_constraint(top_right   , bottom_right))
	local bottom = pool.add_object(create_constraint(bottom_right, bottom_left ))
	local left   = pool.add_object(create_constraint(bottom_left , top_left    ))

	-- Structural elements
	local s1 = pool.add_object(create_constraint(top_left , bottom_right))
	local s2 = pool.add_object(create_constraint(top_right, bottom_left ))
end

local function blueprint_create_poly(cx, cy, radius, sides)
	local center = pool.add_object(create_ball(cx, cy, 4))
	local corners = {} 

	-- Create corners
	for i = 1, sides do
		local corner_pos = util.vec_from_angle(math.rad(360 / sides) * i, radius)
		table.insert( corners, pool.add_object(create_ball(cx + corner_pos.x, cy + corner_pos.y, 3)) )
	end

	-- Create sides and prongs
	for i = 1, sides - 1 do
		pool.add_object(create_constraint(corners[i], corners[i + 1]))
		pool.add_object(create_constraint(center, corners[i]))
	end

	-- Connect last to the first and the last to the cenetr
	pool.add_object(create_constraint(corners[sides], corners[1]))
	pool.add_object(create_constraint(center, corners[sides]))
end

local function blueprint_create_rope(x1, y1, x2, y2, segments)
	local nodes = {} 

	local dx = (x2 - x1) / segments
	local dy = (y2 - y1) / segments

	-- Create nodes
	for i = 0, segments do
		local ball = create_ball(x1 + dx*i, y1 + dy*i, 3)

		if i == 0 or i == segments then
			ball.pinned = true
			ball.pin_x = ball.x
			ball.pin_y = ball.y
		end

		table.insert(nodes, pool.add_object(ball))
	end

	-- Create connections
	for i = 1, segments do
		pool.add_object(create_constraint(nodes[i], nodes[i + 1]))
	end
end

--
-- UI functions
--

local function get_menu_data(menu_id)
	local menu_index_lookup = {
		ball    = 1,
		select  = 2,
		move    = 3,
		pin     = 4,
		animate = 5,
		connect = 6,
	}

	return menu_items[menu_index_lookup[menu_id]].data
end

local function _update_menu_ball(left, right)
	if left == 1 then
		local ball = create_ball(mx, my, 3)
		local ball_index = pool.add_object(ball)
	end

	if right == 1 and hovered_ball_index ~= -1 then
		remove_ball_and_constraints(hovered_ball_index)
	end
end

local function _update_menu_select(left, right)
	if left == 1 then
		get_menu_data("select").active = true
		get_menu_data("select").x = mx
		get_menu_data("select").y = my
		selected_balls = {}
	end

	if left == -1 then
		get_menu_data("select").active = false
		selected_balls = get_balls_in_area(normalise_rect(get_menu_data("select")))
	end

	if input.pressed(input.BTN3) or input.key_pressed(input.KEY_DELETE) or input.key_pressed(input.KEY_BACKSPACE) then
		for obj_index, _ in pairs(selected_balls) do
			remove_ball_and_constraints(obj_index)
		end
	end

	-- Update selection area
	if get_menu_data("select").active then
		get_menu_data("select").w = mx - get_menu_data("select").x
		get_menu_data("select").h = my - get_menu_data("select").y
	end

end

local function _update_menu_move(left, right)
	-- Left clcik for smooth motion
	if left == 1 then
		get_menu_data("move").mode = "smooth"
		get_menu_data("move").x = mx
		get_menu_data("move").y = my
	end

	if left == -1 then
		get_menu_data("move").mode = ""
	end

	-- Right click for snapped motion
	if right == 1 then
		get_menu_data("move").mode = "snap"
		get_menu_data("move").x = mx
		get_menu_data("move").y = my
	end

	if right == -1 then
		-- Actually move the balls
		for obj_index, _ in pairs(selected_balls) do
			pool.objects[obj_index].x += get_menu_data("move").dx
			pool.objects[obj_index].y += get_menu_data("move").dy
			pool.objects[obj_index].pin_x += get_menu_data("move").dx
			pool.objects[obj_index].pin_y += get_menu_data("move").dy
		end

		get_menu_data("move").mode = ""
	end

	-- Update drag offset
	if get_menu_data("move").mode == "snap" then
		get_menu_data("move").dx = mx - get_menu_data("move").x
		get_menu_data("move").dy = my - get_menu_data("move").y
	end

	if get_menu_data("move").mode == "smooth" then
		get_menu_data("move").dx = mx - omx
		get_menu_data("move").dy = my - omy

		-- Move the balls smoothly
		for obj_index, _ in pairs(selected_balls) do
			if State.is_paused then
				pool.objects[obj_index].x += get_menu_data("move").dx
				pool.objects[obj_index].y += get_menu_data("move").dy
			end
			pool.objects[obj_index].vx = get_menu_data("move").dx
			pool.objects[obj_index].vy = get_menu_data("move").dy
			pool.objects[obj_index].pin_x += get_menu_data("move").dx
			pool.objects[obj_index].pin_y += get_menu_data("move").dy
		end
	end
end

local function _update_menu_pin(left, right)
	if left == 1 and hovered_ball_index ~= -1 then
		local i = hovered_ball_index

		pool.objects[i].pinned = true
		pool.objects[i].pin_x = pool.objects[i].x
		pool.objects[i].pin_y = pool.objects[i].y
	end

	if right == 1 and hovered_ball_index ~= -1 then
		pool.objects[hovered_ball_index].pinned = false
	end

	--[[
	PIn selected
		local needs_pinning = State.selected_balls

		-- Add hovered ball to the pinnables
		if State.hovered_ball_index ~= -1 then
			needs_pinning[State.hovered_ball_index] = true
		end

		for obj_index, _ in pairs(needs_pinning) do
			pool.objects[obj_index].pinned = not pool.objects[obj_index].pinned
			pool.objects[obj_index].pin_x = pool.objects[obj_index].x
			pool.objects[obj_index].pin_y = pool.objects[obj_index].y
		end

		State.selected_balls = {}
	]]

end

local function _update_menu_animate(left, right)
	if left == 1 then
		State.stat_selected = hovered_ball_index
	end
end

local function _update_menu_connect(left, right)
end

menu_items = {
	{
		title = "Place balls",
		sprite = 5,
		fn = _update_menu_ball,
	},
	{
		title = "Select",
		sprite = 6,
		fn = _update_menu_select,
		data = {
			active = false,
			x = 0,
			y = 0,
			w = 0,
			h = 0,
		},
	},
	{
		title = "Move",
		sprite = 7,
		fn = _update_menu_move,
		data = {
			active = false,
			x = 0,
			y = 0,
			dx = 0,
			dy = 0,

		},
	},
	{
		title = "Pin",
		sprite = 8,
		fn = _update_menu_pin,
	},
	{
		title = "Animate",
		sprite = 9,
		fn = _update_menu_animate,
	},
	{
		title = "Connect",
		sprite = 10,
		fn = _update_menu_connect,
		data = {
			first_ball_index = -1,
		},
	},
}

local function _update_ui()
	-- Single button controls
	if input.key_pressed(input.KEY_SPACE) then State.is_paused = not State.is_paused end

	if input.pressed(input.LEFT)  then State.selected_menu = util.clamp(State.selected_menu - 1, 1, #menu_items) end
	if input.pressed(input.RIGHT) then State.selected_menu = util.clamp(State.selected_menu + 1, 1, #menu_items) end

	-- Blueprints
	if input.key_pressed(input.KEY_1) then blueprint_create_rect(mx, my) end
	if input.key_pressed(input.KEY_2) then blueprint_create_poly(mx, my, 32, 36) end
	if input.key_pressed(input.KEY_3) then blueprint_create_rope(0, my, usagi.GAME_W, my, 64) end

	-- Controls for the selected menu mode
	local mouse_left = 0
	if input.mouse_pressed(input.MOUSE_LEFT) then mouse_left = 1 end
	if input.mouse_released(input.MOUSE_LEFT) then mouse_left = -1 end

	local mouse_right = 0
	if input.mouse_pressed(input.MOUSE_RIGHT) then mouse_right = 1 end
	if input.mouse_released(input.MOUSE_RIGHT) then mouse_right = -1 end

	-- Execute menu function
	if menu_items[State.selected_menu] ~= nil then
		menu_items[State.selected_menu].fn(mouse_left, mouse_right)
	end
	
	return nil

	-- Placing balls and selecting them
	--[[if input.mouse_pressed(input.MOUSE_LEFT) then
		if State.hovered_ball_index ~= -1 then
			State.selection_area = {}
			State.interaction_mode = "drag"
			State.selected_balls[State.hovered_ball_index] = 1
		elseif next(State.selected_balls) ~= nil then
			State.selected_balls = {}
			State.interaction_mode = nil
		elseif shift_pressed then

		else
			-- Placing balls
			if State.selected_menu == 0 then
				local ball = create_ball(mx, my, 3)
				local ball_index = pool.add_object(ball)
				State.selected_balls = {}
			end
	
			-- Placing constraints
			if State.selected_menu == 1 then
			end
		end
	end

	-- Confirm selection area
	if input.mouse_released(input.MOUSE_LEFT) then
		if State.interaction_mode ~= nil and State.selection_area.x ~= nil then
			State.interaction_mode = nil
			State.selected_balls = get_balls_in_area(normalise_rect(State.selection_area))
			State.selection_area = {}
		end

		if State.interaction_mode == "drag" then
			State.interaction_mode = nil
		end
	end

	-- Selecting for deletion
	if input.mouse_pressed(input.MOUSE_RIGHT) then
		if shift_pressed then
			State.selection_area = {x = mx, y = my, w = 0, h = 0}
			State.interaction_mode = "delete"
			State.selected_balls = {}
		else
			-- Delete hovered ball
			if State.hovered_ball_index ~= -1 then
				remove_ball_and_constraints(State.hovered_ball_index)
			end
		end
	end

	-- Confirm deletion area
	if input.mouse_released(input.MOUSE_RIGHT) then
		if State.interaction_mode ~= nil and State.selection_area.x ~= nil then
			State.interaction_mode = nil
			State.selected_balls = get_balls_in_area(normalise_rect(State.selection_area))

			for obj_index, _ in pairs(State.selected_balls) do
				remove_ball_and_constraints(obj_index)
			end

			State.selection_area = {}
			State.selected_balls = {}
		end
	end



	-- Cancel selection
	if shift_released then
		if State.interaction_mode ~= nil and State.selection_area.x ~= nil then
			State.interaction_mode = nil
			State.selection_area = {}
		end
	end]]
end

function _update(dt)
	mx, my = input.mouse()

	-- Update the UI if the cursor is on screen
	if util.point_in_rect({x = mx, y = my}, {x = 0, y = 0, w = usagi.GAME_W, h = usagi.GAME_H}) then
		_update_ui()
	else
		-- Cancel all UI actions
		get_menu_data("select").active = false
		get_menu_data("move").mode = ""
	end

	local step_simulation = input.pressed(input.BTN1)

	-- Update balls and find nearest to the cursor
	hovered_ball_index = -1

	-- Update lines only
	if not State.is_paused or step_simulation then
		for  i = 0, Settings.iteration_count do
			pool.foreach_type("line", function (obj, i)
				obj:push()
			end)
		end
	end

	pool.foreach_type("ball", function (obj, i)
		-- Check for cursor proximity
		if util.point_in_circ({x = mx, y = my}, obj) then
			hovered_ball_index = i
		end

		-- Resolve screen edge collision
		local coll = obj:is_colliding_screen()

		if coll.colliding then
			-- Wall collisions
			if coll.x ~= 0 then
				obj.vx = obj.vx * -0.8
				if coll.x == -1 then obj.x = obj.r end
				if coll.x == 1 then obj.x = usagi.GAME_W - obj.r end
			end

			-- Floor and ceiling collisions
			if coll.y ~= 0 then
				obj.vy = obj.vy * -0.7
				if coll.y == -1 then obj.y = obj.r end
				if coll.y == 1 then obj.y = usagi.GAME_H - obj.r end
			end
		end

		-- Re-position pinned balls
		if obj.pinned then
			obj.vx = 0
			obj.vy = 0

			obj.x = obj.pin_x
			obj.y = obj.pin_y
		end

		-- Update all objects
		if not State.is_paused or step_simulation then
			-- Magic ~sine~ floor
			--[[local wave = math.sin(math.rad(obj.x)*2) * usagi.SPRITE_SIZE * 2
			local der = math.cos(math.rad(obj.x)*2) * usagi.SPRITE_SIZE * 2
			local h = usagi.GAME_H * 0.75 + wave
	
			if obj.y > h then
				obj.vy -= (obj.y - h) * 1
				obj.vx += der * 0.01
			end]]
	
			obj:update(dt)
		end

		return obj
	end)

	-- Update line endings to match ball positions
	pool.foreach_type("line", function (obj, i) obj:update(dt) end)

	-- Update old mouse position
	omx, omy = mx, my
end

function _draw(dt)
	gfx.clear(gfx.COLOR_DARK_BLUE)

	-- Render objects
	pool.foreach(function (obj, i)
		if obj.render == nil then return end
		if obj.type == "ball" then return end
		obj:render()
	end)

	-- Render balls on top
	pool.foreach_type("ball", function (obj, i)
		if obj.render == nil then return end
		obj:render(hovered_ball_index == i, selected_balls[i])
	end)

	-- Render selection
	local area = get_menu_data("select")
	if area.active then
		gfx.rect(
			area.x,
			area.y,
			area.w,
			area.h,
			gfx.COLOR_BLUE
		)
	end

	-- Render move offset
	local move = get_menu_data("move")
	if move.mode == "snap" then
		for obj_index, _ in pairs(selected_balls) do
			gfx.circ_fill(
				pool.objects[obj_index].x + move.dx,
				pool.objects[obj_index].y + move.dy,
				2,
				gfx.COLOR_LIGHT_GRAY
			)
		end
	end


	-- Render info a bout the selected ball
	if State.stat_selected ~= -1 then
		local ball = pool.objects[State.stat_selected]

		ui.draw_label(f("Ball info:"),                                    gfx.COLOR_WHITE, -1, 1, -5)
		ui.draw_label(f("Index: %d", State.stat_selected),                gfx.COLOR_WHITE, -1, 1, -4)
		ui.draw_label(f("Pinned: %s", ball.pinned and "true" or "false"), gfx.COLOR_WHITE, -1, 1, -3)

		-- Draw velocity
		local scale = 4
		gfx.line(ball.x, ball.y, ball.x + ball.vx*scale, ball.y, gfx.COLOR_RED)
		gfx.line(ball.x, ball.y, ball.x, ball.y + ball.vy*scale, gfx.COLOR_GREEN)
		gfx.line(ball.x, ball.y, ball.x + ball.vx*scale, ball.y + ball.vy*scale, gfx.COLOR_LIGHT_GRAY)
	end




	-- Render UI
	ui.draw_label(f(
		"%db + %dc = %d",
		State.ball_count,
		State.constraint_count,
		State.ball_count+State.constraint_count
	), gfx.COLOR_WHITE, 0, -1)
	ui.draw_label(f("[ %s ]", menu_items[State.selected_menu].title), gfx.COLOR_WHITE, 0, -1, 1)
	if State.is_paused then
		ui.draw_label("PAUSED", gfx.COLOR_LIGHT_GRAY, 0, -1, 2)
	end

	-- Render toolbar
	local offset = #menu_items / 2

	for i, item in pairs(menu_items) do
		local box = ui.get_box_repeat({w = usagi.SPRITE_SIZE + 4, h = usagi.SPRITE_SIZE + 4}, 0, 1, -offset + i - 1)

		if State.selected_menu == i then
			gfx.spr(4, box.x, box.y)
		else
			gfx.spr(3, box.x, box.y)
		end

		gfx.spr(item.sprite, box.x, box.y)
	end

	-- Render debug stats
	if usagi.IS_DEV then
		ui.draw_label(f("Pool size: %d", #pool.objects), gfx.COLOR_LIGHT_GRAY, 1, -1)
		ui.draw_label(f("clr: %s", (selection_reset and "true" or "false")), gfx.COLOR_LIGHT_GRAY, 1, -1, 1)
		ui.draw_label(f("B: %d", hovered_ball_index), gfx.COLOR_LIGHT_GRAY, 1, -1, 2)
		ui.draw_label(f("C: %d", hovered_constraint_index), gfx.COLOR_LIGHT_GRAY, 1, -1, 3)

		local s = ""
		for obj_index, _ in pairs(selected_balls) do
			s = s..tostring(obj_index)..", "
		end

		local s, m, h = get_time(util.round(usagi.elapsed))

		ui.draw_label(f("Time: %02d:%02d:%02d", h, m, s), gfx.COLOR_LIGHT_GRAY, 1, 1, -1)
		ui.draw_label(f("Delta: %.5f", dt), gfx.COLOR_LIGHT_GRAY, 1, 1, 0)
	end

	-- Render the mouse cursor
	local mx, my = input.mouse()
	gfx.spr(2, mx - 8, my - 8)
end
