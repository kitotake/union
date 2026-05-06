-- server/modules/character/database.lua (OPTIMIZED)

CharacterDB = {}
CharacterDB.logger = Logger:child("CHARACTER:DATABASE")

-- =====================================================
-- COUNT CHARACTERS (OPTIMIZED)
-- =====================================================
function CharacterDB.getCharacterCount(license, callback)
    if not license then
        if callback then callback(0) end
        return
    end

    Database.scalar([[
        SELECT COUNT(*)
        FROM user_character
        WHERE identifier = ?
    ]],
    { license },
    function(count)
        callback(count or 0)
    end)
end

-- =====================================================
-- GET CHARACTER BY ID
-- =====================================================
function CharacterDB.getCharacterByUniqueId(uniqueId, callback)
    if not uniqueId then
        if callback then callback(nil) end
        return
    end

    Database.fetchOne([[
        SELECT *
        FROM characters
        WHERE unique_id = ?
        LIMIT 1
    ]],
    { uniqueId },
    callback)
end

-- =====================================================
-- CHECK UNIQUE NAME (OPTIMIZED)
-- =====================================================
function CharacterDB.isUniqueName(firstname, lastname, excludeId, callback)
    firstname = firstname and firstname:lower() or ""
    lastname  = lastname and lastname:lower() or ""

    Database.scalar([[
        SELECT COUNT(*)
        FROM characters
        WHERE LOWER(firstname) = ?
        AND LOWER(lastname) = ?
        AND id != ?
    ]],
    {
        firstname,
        lastname,
        excludeId or 0
    },
    function(count)
        callback((count or 0) == 0)
    end)
end

-- =====================================================
-- LAST PLAYED CHARACTER (OPTIMIZED INDEX FRIENDLY)
-- =====================================================
function CharacterDB.getLastPlayedCharacter(license, callback)
    if not license then
        callback(nil)
        return
    end

    Database.fetchOne([[
        SELECT c.*
        FROM characters c
        INNER JOIN user_character uc
            ON uc.unique_id = c.unique_id
        WHERE uc.identifier = ?
        ORDER BY c.last_played DESC
        LIMIT 1
    ]],
    { license },
    callback)
end

-- =====================================================
-- CAN CREATE CHARACTER (FAST PATH)
-- =====================================================
function CharacterDB.canCreateCharacter(license, callback)
    local maxChars = Config.character.maxCharactersPerPlayer or 5

    CharacterDB.getCharacterCount(license, function(count)
        callback((count or 0) < maxChars)
    end)
end

return CharacterDB