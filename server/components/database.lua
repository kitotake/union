-- server/components/database.lua
-- FIX DB1 : Database.transaction() renommée en Database.batchExecute() pour indiquer
--            clairement qu'il n'y a PAS de rollback. Ajout de Database.transaction()
--            qui utilise oxmysql:transaction pour une vraie atomicité.
-- FIX DB2 : Database.insert() normalise le retour insertId (number ou table).

Database = {}
local logger = Logger:child("DATABASE")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS INTERNES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function safeCallback(cb, ...)
    if type(cb) == "function" then cb(...) end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXECUTE (INSERT / UPDATE / DELETE)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.execute(query, params, callback)
    if not query then
        logger:error("Empty query provided to execute()")
        safeCallback(callback, nil)
        return
    end
    exports.oxmysql:execute(query, params or {}, function(result)
        safeCallback(callback, result)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INSERT
-- FIX DB2 : oxmysql peut retourner un entier OU une table avec insertId
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.insert(query, params, callback)
    if not query then
        logger:error("Empty query provided to insert()")
        safeCallback(callback, nil)
        return
    end
    exports.oxmysql:insert(query, params or {}, function(result)
        if not callback then return end
        -- FIX DB2 : normalisation
        local id = nil
        if type(result) == "number" then
            id = result > 0 and result or nil
        elseif type(result) == "table" and result.insertId then
            id = result.insertId > 0 and result.insertId or nil
        end
        callback(id)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FETCH (SELECT multiple rows)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.fetch(query, params, callback)
    if not query then
        logger:error("Empty query provided to fetch()")
        safeCallback(callback, {})
        return
    end
    exports.oxmysql:fetch(query, params or {}, function(result)
        safeCallback(callback, result or {})
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FETCH ONE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.fetchOne(query, params, callback)
    Database.fetch(query, params, function(result)
        safeCallback(callback, result and result[1] or nil)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SCALAR (SELECT COUNT(*) etc.)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.scalar(query, params, callback)
    if not query then
        logger:error("Empty query provided to scalar()")
        safeCallback(callback, nil)
        return
    end
    exports.oxmysql:scalar(query, params or {}, function(result)
        safeCallback(callback, result)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TRANSACTION ATOMIQUE (oxmysql native)
-- FIX DB1 : vraie transaction SQL avec rollback automatique en cas d'erreur
-- queries = { { query = "...", values = {...} }, ... }
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.transaction(queries, callback)
    if not queries or #queries == 0 then
        safeCallback(callback, false)
        return
    end
    exports.oxmysql:transaction(queries, function(success)
        safeCallback(callback, success == true)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BATCH EXECUTE (ancienne "transaction" — PAS atomique)
-- Gardée pour compatibilité descendante, renommée pour clarté
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Database.batchExecute(queries, callback)
    if not queries or #queries == 0 then
        safeCallback(callback, {})
        return
    end

    local results   = {}
    local completed = 0
    local total     = #queries

    for i, q in ipairs(queries) do
        Database.execute(q.query, q.params, function(result)
            completed    = completed + 1
            results[i]   = result
            if completed == total then
                safeCallback(callback, results)
            end
        end)
    end
end

return Database