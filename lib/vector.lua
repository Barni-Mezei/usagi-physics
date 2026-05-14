---@class Vector
local M = {}

---@class Vector.Vector
---@field x number The X componnet of the vector
---@field y number The Y componnet of the vector

--------------------
-- Normalisations --
--------------------

---Returns with the length of vector `v`
---@param v Vector.Vector
---@return number vector The length of the vector
function M.length(v)
	return math.sqrt(v.x*v.x + v.y*v.y);
end

---Returns with the unit vector version of vector `v`
---@param v  Vector.Vector The vector to normalise
---@param n? number        The length to normlise to (default: 1)
---@return Vector.Vector vector   The normlised vector
function M.unit(v, n)
	return M.mult_scalar(M.div_scalar(v, M.length(v)), n or 1);
end

-----------------
-- Simple math --
-----------------

---Adds `v2` to `v1`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return Vector.Vector vector A new vector (v1 + v2)
function M.add(v1, v2)
	return {
		x = v1.x + v2.x,
		y = v1.y + v2.y,
	}
end

---Subtracts `v2` from `v1`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return Vector.Vector vector A new vector (v1 - v2)
function M.sub(v1, v2)
	return {
		x = v1.x - v2.x,
		y = v1.y - v2.y,
	}
end

---Multiplies `v1` with `v2`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return Vector.Vector vector A new vector (v1 * v2)
function M.mult(v1, v2)
	return {
		x = v1.x * v2.x,
		y = v1.y * v2.y,
	}
end

---Multiplies `v` by `n`
---@param v Vector.Vector
---@param n number A number to multiply each component with
---@return Vector.Vector vector A new vector (v * n)
function M.mult_scalar(v, n)
	return {
		x = v.x * n,
		y = v.y * n,
	}
end

---Divides `v1` by `v2`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return Vector.Vector vector A new vector (v1 / v2)
function M.div(v1, v2)
	return {
		x = v1.x / v2.x,
		y = v1.y / v2.y,
	}
end

---Divides `v` by `n`
---@param v Vector.Vector
---@param n number A number to divide each component with
---@return Vector.Vector vector A new vector (v / n)
function M.div_scalar(v, n)
	return {
		x = v.x / n,
		y = v.y / n,
	}
end

---Flips `v` around the specified axis
---@param v     Vector.Vector
---@param axis? string The letters of the axis to flip around (default: "xy")
---@return Vector.Vector vector The flipped vector
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
---@param v Vector.Vector
---@return Vector.Vector vector The normal vector of v
function M.normal(v)
	return {
		x = v.y,
		y = -v.x,
	};
end

---Returns with the dot product of `v1` and `v2`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return number value The dot product
function M.dot(v1, v2)
	return v1.x * v2.x + v1.y * v2.y;
end

---Returns with the cross product of `v1` and `v2`
---@param v1 Vector.Vector
---@param v2 Vector.Vector
---@return number value The cross product
function M.cross(v1, v2)
	return v1.x * v2.y - v1.y * v2.x;
end

return M
