---@class PoolManager
local M = {
    max_size = -1,
    overwrite = false,

    objects = {},
    inactive = {},
}

---@class PoolManager
---@field max_size  integer The maximum number of allowed objects in memory (-1 for no limit)
---@field overwrite boolean Toggles new object creation permissions. If set to true,
---new objects use currently active objects places in the pool
---@field objects   table   The pool of objects
---@field inactive  table   The pool of inactive object indexes


---Resets the pool manager
function M.init()
    M.objects = {}
    M.inactive = {}
end

---Appends an object into the object pool, or replaces an inactive one
---@param obj       table  The object to add to the pool
---@param obj_type? string The type of the object
---@return number index   Returns the index of the added object or -1 on error
function M.add_object(obj, obj_type)
    -- Set object type (if provided)
    if obj_type == nil then
        obj.type = obj.type or ""
    else
        obj.type = obj_type
    end

    -- Enable object
    obj.active = true

    local obj_index_out = -1

    if M.max_size == -1 or #M.objects < M.max_size then
        obj_index_out = #M.objects + 1
        table.insert(M.objects, obj)
    else
        -- TODO: this branch
        if #M.inactive == 0 then
            -- Max number is reached and no inactive objects found
        else
            -- Find the first inactive object
        end
    end

    -- Remove object from the inactive list
    if M.inactive[obj_index_out] ~= nil then M.inactive[obj_index_out] = nil end

    return obj_index_out
end

---Remove the object from the pool (and mark it as inactive)
---@param obj_index number The index of the object (in the pool) to remove
---@return boolean result  Was the operation successful?
function M.remove_object(obj_index)
    if #M.objects[obj_index] == nil then return false end

    M.objects[obj_index].active = false

    M.inactive[obj_index] = true

    return true
end

---Checks whether the provided object is of a certain type
---@param obj      table  The object to check
---@param obj_type string The type to check for
---@return boolean result Is the object the specified type?
function M.is_type(obj, obj_type)
    return obj.type == obj_type
end

---Iterates over all objects and calls a function on each iteration
---@param callback function A function that gets called on every object.
---Parameters:
--- - `i`   **number**: The index of the current object
--- - `obj` **table** : The current object in the iteration
---If the function returns something, the object gets overwritten with it
function M.foreach(callback)
    for i, obj in ipairs(M.objects) do
        if obj.active then
            obj = callback(obj, i) or obj
        end
    end
end

---Iterates over all objects of a certain type and calls a function on each iteration
---@param obj_type string   The type of the objects to iterate over
---@param callback function A function that gets called on every object.
---Parameters:
--- - `i`   **number**: The index of the current object
--- - `obj` **table** : The current object in the iteration
---If the function returns something, the object gets overwritten with it
function M.foreach_type(obj_type, callback)
    for i, obj in ipairs(M.objects) do
        if obj.active and obj.type == obj_type then
            obj = callback(obj, i) or obj
        end
    end
end

return M