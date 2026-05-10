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

function normalise_rect(r)
	if r.w < 0 then
		r.x += r.w
		r.w = math.abs(r.w)
	end

	if r.h < 0 then
		r.y += r.h
		r.h = math.abs(r.h)
	end

	return r
end

function get_balls_in_area(r)
	local out = {}

	local rect = 

	pool.foreach_type("ball", function (obj, i)
		if util.point_in_rect(obj, r) then out[i] = true end
	end)

	return out
end

function remove_ball_and_constraints(ball_index)
	-- Remove the ball
	pool.remove_object(ball_index)

	-- Remove all connected constraints
	pool.foreach_type("line", function (obj, i)
		if obj.index_1 == ball_index or obj.index_2 == ball_index then
			State.constraint_count -= 1
			pool.remove_object(i)
		end
	end)

	State.ball_count -= 1
end
