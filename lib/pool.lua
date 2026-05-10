---@class pool
---@field max_size  integer The maximum number of allowed objects in memory (-1 for no limit)
---@field overwrite boolean Toggles new object creation permissions. If set to true,
---New objects use currently active objects places in the pool
---@field objects   table   The pool of objects
local M = {
    max_size = -1, -- Maximum number of allowed objects
    overwrite = false, -- Can a new object created above the limit, overwrite an  active one?

    objects = {}, -- Pool of objects
    inactive = {}, -- Pool of inactive object indexes
    object_index = 1, -- Current index of the next object
}

---Resets the pool manager
function M.init()
    M.objects = {}
    M.inactive = {}
    M.object_index = 1
end

---Appends an object into the object pool, or replaces an inactive one
---@param obj      table  The object to add to the pool
---@param obj_type string The type of the object
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
        M.object_index = #M.objects
    else
        -- TODO: this branch
        if #M.inactive == 0 then
            -- Max number is reached and no inactive objects found
        else
            -- Find the first inactive object
        end

        -- Search for the first inactive one
        if M.overwrite or ((not M.overwrite) and M.objects[M.object_index].active == false) then
            M.objects[M.object_index] = obj
            obj_index_out = M.object_index
        end

        -- Select the next object in the pool
        M.object_index %= M.max_size
        M.object_index += 1
    end

    -- Remove object from the inactive list
    if M.inactive[obj_index_out] ~= nil then M.inactive[obj_index_out] = nil end

    return obj_index_out
end

---Remove the object from the pool (marks it as inactive)
---@param obj_index number The ID of the object to remove
function M.remove_object(obj_index)
    if #M.objects[obj_index] == nil then return end

    M.objects[obj_index].active = false

    M.inactive[obj_index] = true
end

---Checks whether the provided object is of a certain type
---@param obj      table  The object to check
---@param obj_type string The type to check for
function M.is_type(obj, obj_type)
    return obj.type == obj_type
end

---Iterates over all objects and calls a function on each iteration
---@param callback function A function that gets called on every object.
---It has a single parameter: The current object in the iteration
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
---It has a single parameter: The current object in the iteration
function M.foreach_type(obj_type, callback)
    for i, obj in ipairs(M.objects) do
        if obj.active and obj.type == obj_type then
            obj = callback(obj, i) or obj
        end
    end
end

return M