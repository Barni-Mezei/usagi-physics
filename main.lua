---@diagnostic disable: param-type-mismatch

local shapes = require("lib.shapes")
local ui = require("lib.ui")
local v = require("lib.vector")

require("lib.misc")

--[[
TODO:

ball - ball collisions
- grid based optimisation

Tools:
- [x] ball placer: left place, right delete (menu: ball radius?, mass?)
- [x] select: [left drag select, [ ] if hovered a ball on start: set start XY to ball XY], [ ] right click to select all connected
- [x] move: move selected
- [x] pin: left clik to toggle pin state
- [ ] animate: left clik to add motion, like rotation (menu: motion mode selecti) right click to remove that motion mode
- [x] constraint creator: click on start, click on end -> creates a new constraint (menu: power?, connect selected)

[ ] Tool menu

- blueprint library:
- save selected
- load to cursor (ghost preview?)

Other controls:
- camera controls [middle-click panning / zoom, focus selected balls into view]

]]

function _config()
	return {
		name = "Physics",
		game_id = "com.barni-07.physics",
		icon = 1,

		-- game_width = 640,
		-- game_height = 360,
		--pause_menu = false,
	}
end

-- Mouse position
local mx, my = 0, 0
local omx, omy = 0, 0

Settings = {
	global_strength = 1, -- Global spring strength
	iteration_count = 10, -- Constraint solver iteration count
}

Selected_balls = {} -- Selected ball index
Selection_reset = false -- Clear selection after action?

Hovered_ball_index = -1 -- Hovered ball
Hovered_constraint_index = -1 -- Hovered constraint

function _init()
	ui.init()

	-- Keep between reloads
	Pool = require("lib.pool")
	Pool.init()
	Pool.max_size = -1

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

	-- Construct the UI

	-- Top info panel
	---@diagnostic disable-next-line: missing-fields
	Pause_label = ui.create_label({
		type = "label",
		value_hook = "paused",
		text = "PAUSED",
		visible = false,
	})

	---@diagnostic disable-next-line: missing-fields
	ui.add_panel({
		type = "list",
		axis = "y",
		children = {
			{
				type = "label",
				value_hook = "object_count",
			},
			{
				type = "label",
				value_hook = "tool",
			},
			Pause_label,
		},
	}, 0, -1)

	-- Bottom toolbar
	Tool_list = ui.create_list("x", 2)
	Tool_list.my = 1

	for k, tool in pairs(Menu_items) do
		---@diagnostic disable-next-line: missing-fields
		Menu_items[k].item = ui.create_box({
			fix_size = true,
			w = usagi.SPRITE_SIZE,
			h = usagi.SPRITE_SIZE,
			data = {
				i = k
			},
		})

		Tool_list.add_child(Menu_items[k].item)
	end

	ui.add_panel(Tool_list, 0, 1)

	-- Top right info panel (4 lines: d1, d2 ... d4)
	Debug_info = ui.create_list("y", 0, -1)

	for i = 1, 4 do
		local new_label = ui.create_label("", -1,0, f("d%d", i))
		new_label.style = {text_color = gfx.COLOR_LIGHT_GRAY}
		Debug_info.add_child(new_label)
	end

	ui.add_panel(Debug_info, 1, -1)

	-- Bottom right info panel
	Session_info = ui.create_list("y", 4, -1)
	local time_label = ui.create_label("", -1,0, "time")
	time_label.style = {text_color = gfx.COLOR_LIGHT_GRAY}
	Session_info.add_child(time_label)
	local delta_label = ui.create_label("", -1,0, "delta")
	delta_label.style = {text_color = gfx.COLOR_LIGHT_GRAY}
	Session_info.add_child(delta_label)

	ui.add_panel(Session_info, 1, 1)

	-- ui.update()
	-- dump(Session_info)
	-- os.exit()
end

-- Simple custom render function
function ui.render_item(item)
    if item.visible == false then return end

    if item.type == "label" then
		local color = gfx.COLOR_WHITE
		if item.style ~= nil then color = item.style.text_color or color end

        gfx.text(item.text, item.text_x, item.text_y, color)
    end

    if item.type == "box" and item.data ~= nil then
		if State.selected_menu == item.data.i then
			gfx.spr(4, item.x, item.y)
		else
			gfx.spr(3, item.x, item.y)
		end

		gfx.spr(Menu_items[item.data.i].sprite, item.x, item.y)
	end
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

	ball.index = #Pool.objects + 1

	-- ball.vx = rand_float(-8, 8)
	-- ball.vy = rand_float(-6, 1)

	ball.render = function (self, is_hovered, is_selected, is_connection)
		--[[if usagi.IS_DEV then
			local t = tostring(self.index)
			local w, h = usagi.measure_text(t)
			gfx.text(t, self.x - w/2, self.y - self.r - h, gfx.COLOR_WHITE)
		end]]

		local color = self.color

		if self.pinned then color = gfx.COLOR_ORANGE end
		if is_hovered then color = gfx.COLOR_RED end
		if is_connection then color = gfx.COLOR_DARK_GRAY end

		gfx.circ_fill(self.x, self.y, self.r, color)

		if is_selected then
			gfx.circ(self.x, self.y, self.r, gfx.COLOR_BLUE)
		end
	end

	if ball ~= -1 then
		State.ball_count = State.ball_count + 1
	end

	return ball
end

-- Create a new constraint
local function create_constraint(ball1_index, ball2_index)
	local b1 = Pool.objects[ball1_index]
	local b2 = Pool.objects[ball2_index]

	local constraint = shapes.create_line(b1.x, b1.y, b2.x, b2.y)

	constraint.index_1 = ball1_index
	constraint.index_2 = ball2_index
	constraint.length  = util.vec_dist(b1, b2)
	constraint.power   = 1--rand_float(0.25, 1)

	constraint.update = function (self, dt)
		-- Set line ends to the ball positions
		local b1 = Pool.objects[self.index_1]
		local b2 = Pool.objects[self.index_2]

		self.x1 = b1.x
		self.y1 = b1.y

		self.x2 = b2.x
		self.y2 = b2.y
	end

	constraint.push = function (self)
		-- Get the balls at the end of the line
		local b1 = Pool.objects[self.index_1]
		local b2 = Pool.objects[self.index_2]

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
	local top_left     = Pool.add_object(create_ball(px     , py     , 3))
	local top_right    = Pool.add_object(create_ball(px + 32, py     , 3))
	local bottom_right = Pool.add_object(create_ball(px + 32, py + 32, 3))
	local bottom_left  = Pool.add_object(create_ball(px     , py + 32, 3))

	-- Sides
	Pool.add_object(create_constraint(top_left    , top_right   ))
	Pool.add_object(create_constraint(top_right   , bottom_right))
	Pool.add_object(create_constraint(bottom_right, bottom_left ))
	Pool.add_object(create_constraint(bottom_left , top_left    ))

	-- Structural elements
	Pool.add_object(create_constraint(top_left , bottom_right))
	Pool.add_object(create_constraint(top_right, bottom_left ))
end

local function blueprint_create_poly(cx, cy, radius, sides)
	local center = Pool.add_object(create_ball(cx, cy, 4))
	local corners = {} 

	-- Create corners
	for i = 1, sides do
		local corner_pos = util.vec_from_angle(math.rad(360 / sides) * i, radius)
		table.insert( corners, Pool.add_object(create_ball(cx + corner_pos.x, cy + corner_pos.y, 3)) )
	end

	-- Create sides and prongs
	for i = 1, sides - 1 do
		Pool.add_object(create_constraint(corners[i], corners[i + 1]))
		Pool.add_object(create_constraint(center, corners[i]))
	end

	-- Connect last to the first and the last to the cenetr
	Pool.add_object(create_constraint(corners[sides], corners[1]))
	Pool.add_object(create_constraint(center, corners[sides]))
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

		table.insert(nodes, Pool.add_object(ball))
	end

	-- Create connections
	for i = 1, segments do
		Pool.add_object(create_constraint(nodes[i], nodes[i + 1]))
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

	return Menu_items[menu_index_lookup[menu_id]].data
end

local function _update_menu_ball(left, right)
	if left == 1 then
		local ball = create_ball(mx, my, 3)
		local ball_index = Pool.add_object(ball)
	end

	if right == 1 and Hovered_ball_index ~= -1 then
		remove_ball_and_constraints(Hovered_ball_index)
	end
end

local function _update_menu_select(left, right)
	if left == 1 then
		get_menu_data("select").active = true
		get_menu_data("select").x = mx
		get_menu_data("select").y = my
		Selected_balls = {}
	end

	if left == -1 then
		get_menu_data("select").active = false
		Selected_balls = get_balls_in_area(normalise_rect(get_menu_data("select")))
	end

	if input.pressed(input.BTN3) or input.key_pressed(input.KEY_DELETE) or input.key_pressed(input.KEY_BACKSPACE) then
		for obj_index, _ in pairs(Selected_balls) do
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
		for obj_index, _ in pairs(Selected_balls) do
			Pool.objects[obj_index].x += get_menu_data("move").dx
			Pool.objects[obj_index].y += get_menu_data("move").dy
			Pool.objects[obj_index].pin_x += get_menu_data("move").dx
			Pool.objects[obj_index].pin_y += get_menu_data("move").dy
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
		for obj_index, _ in pairs(Selected_balls) do
			if State.is_paused then
				Pool.objects[obj_index].x += get_menu_data("move").dx
				Pool.objects[obj_index].y += get_menu_data("move").dy
			end
			Pool.objects[obj_index].vx = get_menu_data("move").dx
			Pool.objects[obj_index].vy = get_menu_data("move").dy
			Pool.objects[obj_index].pin_x += get_menu_data("move").dx
			Pool.objects[obj_index].pin_y += get_menu_data("move").dy
		end
	end
end

local function _update_menu_pin(left, right)
	if left == 1 and Hovered_ball_index ~= -1 then
		local i = Hovered_ball_index

		Pool.objects[i].pinned = true
		Pool.objects[i].pin_x = Pool.objects[i].x
		Pool.objects[i].pin_y = Pool.objects[i].y
	end

	if right == 1 and Hovered_ball_index ~= -1 then
		Pool.objects[Hovered_ball_index].pinned = false
	end
end

local function _update_menu_animate(left, right)
	if left == 1 then
		State.stat_selected = Hovered_ball_index
	end
end

local function _update_menu_connect(left, right)
	if left == 1 and Hovered_ball_index ~= -1 then
		if get_menu_data("connect").first_ball_index == -1 then
			get_menu_data("connect").first_ball_index = Hovered_ball_index
		else
			-- Create new connection
			Pool.add_object(create_constraint(
				get_menu_data("connect").first_ball_index,
				Hovered_ball_index
			))

			-- Reset connection origin
			get_menu_data("connect").first_ball_index = -1
		end
	end
end

-- Toolbar (global)
Menu_items = {
	{
		title = "Place balls",
		sprite = 5,
		fn = _update_menu_ball,
		item = {},
	},
	{
		title = "Select",
		sprite = 6,
		fn = _update_menu_select,
		item = {},
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
		item = {},
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
		item = {},
	},
	{
		title = "Animate",
		sprite = 9,
		fn = _update_menu_animate,
		item = {},
	},
	{
		title = "Connect",
		sprite = 10,
		fn = _update_menu_connect,
		item = {},
		data = {
			first_ball_index = -1,
		},
	},
}

local function handle_controls()
	-- Single button controls
	if input.key_pressed(input.KEY_SPACE) then State.is_paused = not State.is_paused end

	if input.pressed(input.LEFT)  then State.selected_menu = util.clamp(State.selected_menu - 1, 1, #Menu_items) end
	if input.pressed(input.RIGHT) then State.selected_menu = util.clamp(State.selected_menu + 1, 1, #Menu_items) end

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
	if Menu_items[State.selected_menu] ~= nil then
		Menu_items[State.selected_menu].fn(mouse_left, mouse_right)
	end

	return nil
end

function _update(dt)
	mx, my = input.mouse()

	-- Update the UI if the cursor is on screen
	if util.point_in_rect({x = mx, y = my}, {x = 0, y = 0, w = usagi.GAME_W, h = usagi.GAME_H}) then
		handle_controls()
	else
		-- Cancel all UI actions
		get_menu_data("select").active = false
		get_menu_data("move").mode = ""
	end

	-- Update UI values
	ui.set_hook("object_count", f(
		"%db + %dc = %d",
		State.ball_count,
		State.constraint_count,
		State.ball_count + State.constraint_count
	))

	ui.set_hook("tool", f("[ %s ]", Menu_items[State.selected_menu].title))
	Pause_label.visible = State.is_paused

	-- Update debug and session info
	ui.set_hook("d1", f("Pool size: %d", #Pool.objects))
	ui.set_hook("d2", f("clr: %s", (Selection_reset and "true" or "false")))
	ui.set_hook("d3", f("B: %d", Hovered_ball_index))
	ui.set_hook("d4", f("C: %d", Hovered_constraint_index))

	local s, m, h = get_time(util.round(usagi.elapsed))
	ui.set_hook("time", f("Time: %02d:%02d:%02d", h, m, s))
	ui.set_hook("delta", f("Delta: %.5f", dt))

	Debug_info.visible = usagi.IS_DEV
	Session_info.visible = usagi.IS_DEV

	ui.update(mx, my)

	local step_simulation = input.pressed(input.BTN1)

	-- Update balls and find nearest to the cursor
	Hovered_ball_index = -1

	-- Update lines only
	if not State.is_paused or step_simulation then
		for  i = 0, Settings.iteration_count do
			Pool.foreach_type("line", function (obj, i)
				obj:push()
			end)
		end
	end

	Pool.foreach_type("ball", function (obj, i)
		-- Check for cursor proximity
		if util.point_in_circ({x = mx, y = my}, obj) then
			Hovered_ball_index = i
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
	Pool.foreach_type("line", function (obj, i) obj:update(dt) end)

	-- Update old mouse position
	omx, omy = mx, my
end

function _draw(dt)
	gfx.clear(gfx.COLOR_DARK_BLUE)

	-- Render objects
	Pool.foreach(function (obj, i)
		if obj.render == nil then return end
		if obj.type == "ball" then return end
		obj:render()
	end)

	-- Render balls on top
	Pool.foreach_type("ball", function (obj, i)
		if obj.render == nil then return end
		obj:render(Hovered_ball_index == i, Selected_balls[i], get_menu_data("connect").first_ball_index == i)
	end)

	-- Render selection
	local area = get_menu_data("select")
	if area.active then
		local r = normalise_rect(area)
		gfx.rect(
			r.x,
			r.y,
			r.w,
			r.h,
			gfx.COLOR_BLUE
		)
	end

	-- Render move offset
	local move = get_menu_data("move")
	if move.mode == "snap" then
		for obj_index, _ in pairs(Selected_balls) do
			gfx.circ_fill(
				Pool.objects[obj_index].x + move.dx,
				Pool.objects[obj_index].y + move.dy,
				2,
				gfx.COLOR_LIGHT_GRAY
			)
		end
	end

	ui.render(true)

	-- Render info a bout the selected ball
	if State.stat_selected ~= -1 then
		local ball = Pool.objects[State.stat_selected]

		-- Draw velocity
		local scale = 4
		gfx.line(ball.x, ball.y, ball.x + ball.vx*scale, ball.y, gfx.COLOR_RED)
		gfx.line(ball.x, ball.y, ball.x, ball.y + ball.vy*scale, gfx.COLOR_GREEN)
		gfx.line(ball.x, ball.y, ball.x + ball.vx*scale, ball.y + ball.vy*scale, gfx.COLOR_LIGHT_GRAY)
	end

	-- Render the mouse cursor
	gfx.spr(2, mx - 8, my - 8)
end
