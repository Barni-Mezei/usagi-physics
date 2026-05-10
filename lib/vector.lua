---@module vector

local M = {}

---@class Vector
---@field x number
---@field y number

--------------------
-- Normalisations --
--------------------

---Returns with the length of vector `v`
---@param v Vector
---@return number The length of the vector
function M.length(v)
	return math.sqrt(v.x*v.x + v.y*v.y);
end

---Returns with the unit vector version of vector `v`
---@param v Vector the vector to nomrlise
---@param n number (optional) The length to normlise to (default: 1)
---@return Vector The normlised vector
function M.unit(v, n)
	return M.mult_scalar(M.div_scalar(v, M.length(v)), n or 1);
end

-----------------
-- Simple math --
-----------------

---Adds `v2` to `v1`
---@param v1 Vector
---@param v2 Vector
---@return Vector A new vector (v1 + v2)
function M.add(v1, v2)
	return {
		x = v1.x + v2.x,
		y = v1.y + v2.y,
	}
end

---Subtracts `v2` from `v1`
---@param v1 Vector
---@param v2 Vector
---@return Vector A new vector (v1 - v2)
function M.sub(v1, v2)
	return {
		x = v1.x - v2.x,
		y = v1.y - v2.y,
	}
end

---Multiplies `v1` with `v2`
---@param v1 Vector
---@param v2 Vector
---@return Vector A new vector (v1 * v2)
function M.mult(v1, v2)
	return {
		x = v1.x * v2.x,
		y = v1.y * v2.y,
	}
end

---Multiplies `v` by `n`
---@param v Vector
---@param n number A number to multiply each component with
---@return number A new vector (v * n)
function M.mult_scalar(v, n)
	return {
		x = v.x * n,
		y = v.y * n,
	}
end

---Divides `v1` by `v2`
---@param v1 Vector
---@param v2 Vector
---@return Vector A new vector (v1 / v2)
function M.div(v1, v2)
	return {
		x = v1.x / v2.x,
		y = v1.y / v2.y,
	}
end

---Divides `v` by `n`
---@param v Vector
---@param n number A number to divide each component with
---@return Vector A new vector (v / n)
function M.div_scalar(v, n)
	return {
		x = v.x / n,
		y = v.y / n,
	}
end

---Flips `v` around the specified axis
---@param v Vector
---@param axis string (optional) The letters of the axis to
---flip around (default: "xy")
function M.flip(v, axis)
	local x = 1
	local y = 1

	if axis == nil or axis == "" then
		x = -1
		y = -1
	else
		if string.find(axis, "x") ~= nil then x = -1 end
		if string.find(axis, "y") ~= nil then y = -1 end
	end

	return {
		x = v.x * x,
		y = v.y * y,
	}
end

-------------------
-- Advanced math --
-------------------

---Returns with the normal vector of `v` (rotated 90 to the right)
---@param v Vector
---@return Vector The normal vector of v
function M.normal(v)
	return {
		x = v.y,
		y = -v.x,
	};
end

---Returns with the dot product of `v1` and `v2`
---@param v1 Vector
---@param v2 Vector
---@return number The dot product
function M.dot(v1, v2)
	return v1.x * v2.x + v1.y * v2.y;
end

---Returns with the cross product of `v1` and `v2`
---@param v1 Vector
---@param v2 Vector
---@return number The cross product
function M.cross(v1, v2)
	return v1.x * v2.y - v1.y * v2.x;
end

return M
