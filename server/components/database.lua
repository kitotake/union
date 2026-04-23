-- server/components/database.lua
Database = {}
local logger = Logger:child("DATABASE")

-- Helper function for queries
function Database.execute(query, params, callback)
    if not query then
        logger:error("Empty query provided")
        if callback then callback(nil) end
        return
    end
    
    exports.oxmysql:execute(query, params or {}, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- Helper function for insert
function Database.insert(query, params, callback)
    Database.execute(query, params, function(result)
        if callback then
            if result and result.insertId then
                callback(result.insertId)
            else
                callback(nil)
            end
        end
    end)
end

-- Helper function for queries (read-only)
function Database.fetch(query, params, callback)
    if not query then
        logger:error("Empty query provided")
        if callback then callback({}) end
        return
    end
    
    exports.oxmysql:fetch(query, params or {}, function(result)
        if callback then
            callback(result or {})
        end
    end)
end

-- Helper function for single result
function Database.fetchOne(query, params, callback)
    Database.fetch(query, params, function(result)
        if callback then
            callback(result and result[1] or nil)
        end
    end)
end

-- Helper function for scalar result
function Database.scalar(query, params, callback)
    exports.oxmysql:scalar(query, params or {}, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- Transaction helper
function Database.transaction(queries, callback)
    local results = {}
    local completed = 0
    
    for i, q in ipairs(queries) do
        Database.execute(q.query, q.params, function(result)
            completed = completed + 1
            results[i] = result
            
            if completed == #queries then
                if callback then callback(results) end
            end
        end)
    end
end

return Database