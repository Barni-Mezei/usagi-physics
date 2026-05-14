function rand_float(min, max)
	return min + math.random() * (max - min)
end

-- Returns the seconds, minutes and hours
function get_time(seconds)
	local s = seconds % 60
	local m = math.floor(seconds//60) % 60
	local h = math.floor(seconds//3600) % 24

	return s, m, h
end

-- Alias for formatting
f = string.format

---Prints the provided value to the console, using formatting
---@param value any The value to print to the console
---@param advanced? boolean if this flag is set, then functions, threads and user data wil be shown as well.
---@param max_depth? integer The maximum allowed depth
---@param depth? integer The current depth in the printing process
function dump(value, advanced, max_depth, depth)
	local a = advanced or false
	local d = depth or 1
	local md = max_depth or 10
	local t = tostring(value)

	if type(value) == "nil" then io.write("\27[90mnil\27[m") end
	if type(value) == "number" then io.write(f("\27[36m%d\27[m", t)) end
	if type(value) == "string" then io.write(f("\27[33m\"%s\"\27[m", t)) end
	if type(value) == "boolean" then io.write(f("%s\27[m", value and "\27[32mtrue" or "\27[31mfalse")) end
	if type(value) == "function" then io.write(f("\27[90m%s()\27[m", t)) end
	if type(value) == "userdata" then io.write(f("\27[90m%s()\27[m", t)) end
	if type(value) == "thread" then io.write(f("\27[90m%s()\27[m", t)) end
	if type(value) == "table" then
		-- Do not go deeper than the max allowed depth
		if d > md then
			io.write("{ \27[35m...\27[m }")
			return
		end

		local indent = string.rep("    ", d)
		local indent_small = string.rep("    ", d - 1)

		-- Empty table
		if next(value) == nil then
			io.write("{}")
		else
			io.write("{\n")
			for k, v in pairs(value) do
				-- Skip advanced data types if the advanced flag is set to false
				if (type(v) == "function" or type(v) == "userdata" or type(v) == "thread") and not a then
					goto continue_dump_loop
				end

				if type(k) == "number" then
					io.write(f("%s\27[36m#%s\27[m = ", indent, tostring(k)))
				else
					io.write(indent..tostring(k).." = ")
				end

				dump(v, a, md, d + 1)

				io.write(",\n")

				::continue_dump_loop::
			end
			io.write(indent_small.."}")
		end
	end

	if d == 1 then io.write("\n") end
end

---Normalises the rectangle. Thbis means that the top left corner
---will be at the specified coordinates and W and H will be both positive
---@param r Usagi.Rect A rectangle
---@return Usagi.Rect The normalised rectangle
function normalise_rect(r)
	local out = {
		x = r.x,
		y = r.y,
		w = r.w,
		h = r.h,
	}

	if r.w < 0 then
		out.x = r.x + r.w
		out.w = math.abs(r.w)
	end

	if r.h < 0 then
		out.y = r.y + r.h
		out.h = math.abs(r.h)
	end

	return out
end

function get_balls_in_area(r)
	local out = {}

	Pool.foreach_type("ball", function (obj, i)
		if util.point_in_rect(obj, r) then out[i] = true end
	end)

	return out
end

function remove_ball_and_constraints(ball_index)
	-- Remove the ball
	Pool.remove_object(ball_index)

	-- Remove all connected constraints
	Pool.foreach_type("line", function (obj, i)
		if obj.index_1 == ball_index or obj.index_2 == ball_index then
			State.constraint_count -= 1
			Pool.remove_object(i)
		end
	end)

	State.ball_count -= 1
end
